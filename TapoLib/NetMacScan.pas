unit NetMacScan;

{
  Cross-platform LAN MAC address scanner for Delphi (FMX).

  How it works per platform:
    Windows       : SendARP (iphlpapi.dll) for every host, run in parallel.
                    SendARP issues a real ARP request, so devices that ignore
                    ping are still found.
    macOS / Linux : Sends a 1-byte UDP datagram to every host. This forces the
                    OS to ARP-resolve each address. Then reads the kernel ARP
                    table (macOS: "arp -an", Linux: /proc/net/arp).
                    Hosts are processed in batches of 256 so large subnets
                    don't overflow the kernel neighbour table.
    Android / iOS : NOT POSSIBLE. Android 10+ and iOS 11+ block apps from
                    reading the ARP table. ScanNetworkMacs raises
                    ENotSupportedException there. Call MacScanSupported first.

  ANetwork : any address inside the network, e.g. '192.168.1.0' or '192.168.1.42'
  ASubnet  : '255.255.255.0', '/24' or '24'

  Notes:
    - The scanning machine's own MAC is not included on macOS/Linux
      (the OS doesn't keep an ARP entry for itself).
    - Phones and laptops often use randomised "private" MACs per WiFi network.
    - macOS 15+: add NSLocalNetworkUsageDescription to the app's Info.plist
      (Project Options > Version Info), or local network traffic is blocked.
    - Linux FMX requires FMXLinux. macOS/Linux use Indy (ships with Delphi).
}

interface

uses
  System.SysUtils;

type
  TMacEntry = record
    IP: string;
    MAC: string;   // normalised as 'AA:BB:CC:DD:EE:FF'
  end;
  TMacEntries = TArray<TMacEntry>;

  TMacScanCompleteProc = reference to procedure(const Entries: TMacEntries;
    const ErrorMsg: string);

  /// TNotifyEvent-style progress event, always fired on the main (UI) thread.
  ///   Processed : IPs checked so far (0..Total)
  ///   Found     : matching devices found so far (all devices, or only Tapo
  ///               devices when using ScanTapoDevicesAsync)
  ///   Total     : number of IPs under consideration (e.g. 254 for a /24)
  /// The first call is (0, 0, Total), so you can set ProgressBar.Max there.
  /// The last call before AOnComplete is (Total, Found, Total).
  TMacScanProgressEvent = procedure(Sender: TObject;
    Processed, Found, Total: Integer) of object;

/// True on platforms where MAC scanning is possible (Windows, macOS, Linux).
function MacScanSupported: Boolean;

/// Reports what the low-level calls the scan relies on actually return on
/// this machine (popen, the ARP sysctl, arp -an, /proc/net/arp), and whether
/// a TCP connection to AProbeHost succeeds (on macOS the default gateway when
/// AProbeHost is empty), for tracking down a scan that finds nothing.
/// Takes up to a few seconds; safe on any thread.
function MacScanDiagnostics(const AProbeHost: string = ''): string;

/// The host addresses of a subnet, in order, without the network and
/// broadcast addresses: ('192.168.1.0', '/24') gives 192.168.1.1..254.
/// Raises EArgumentException for an invalid network or mask.
function SubnetHosts(const ANetwork, ASubnet: string): TArray<string>;

/// Blocking scan. Don't call from the UI thread; use ScanNetworkMacsAsync.
/// Typical /24 WiFi network: ~5-15 seconds.
function ScanNetworkMacs(const ANetwork, ASubnet: string): TMacEntries;

/// Runs the scan on a background thread. AOnComplete and AOnProgress are
/// called on the main (UI) thread. ErrorMsg is empty on success.
/// ASender is passed through as the Sender of AOnProgress.
procedure ScanNetworkMacsAsync(const ANetwork, ASubnet: string;
  const AOnComplete: TMacScanCompleteProc;
  const AOnProgress: TMacScanProgressEvent = nil; ASender: TObject = nil);

{ ---------------------------------------------------------------------------
  Tapo filtering

  Tapo is TP-Link's smart-home brand, and Tapo devices use TP-Link's
  IEEE-registered MAC prefixes (OUIs). The built-in table holds all 269 OUIs
  registered to "TP-LINK TECHNOLOGIES CO.,LTD." and "TP-Link Corporation
  Limited" (IEEE MA-L registry, October 2026).

  Caveat: TP-Link routers, range extenders and Deco mesh units share these
  prefixes, so a match means "TP-Link device", which on a typical home WiFi
  network is almost always a Tapo/Kasa smart device -- but not guaranteed.
  --------------------------------------------------------------------------- }

/// True if the MAC's first 3 bytes are a TP-Link/Tapo OUI.
/// Accepts 'AA:BB:CC:DD:EE:FF', 'aa-bb-cc-dd-ee-ff', etc.
function IsTapoMac(const AMac: string): Boolean;

/// Returns only the entries whose MAC is a TP-Link/Tapo OUI.
function FilterTapoDevices(const AEntries: TMacEntries): TMacEntries;

/// ScanNetworkMacs + FilterTapoDevices.
function ScanTapoDevices(const ANetwork, ASubnet: string): TMacEntries;

/// Async version; AOnComplete and AOnProgress run on the main (UI) thread.
/// The progress event's Found counts Tapo devices only.
procedure ScanTapoDevicesAsync(const ANetwork, ASubnet: string;
  const AOnComplete: TMacScanCompleteProc;
  const AOnProgress: TMacScanProgressEvent = nil; ASender: TObject = nil);

/// Adds an extra OUI (e.g. 'AABBCC' or 'AA:BB:CC') if IEEE registers a new
/// TP-Link prefix. Call before scanning, not while a scan is running.
procedure AddTapoOui(const AOui: string);

implementation

{$IF DEFINED(MSWINDOWS)}
  {$DEFINE MACSCAN_WINDOWS}
{$ELSEIF (DEFINED(MACOS) and not DEFINED(IOS)) or (DEFINED(LINUX) and not DEFINED(ANDROID))}
  {$DEFINE MACSCAN_POSIX}
{$ENDIF}

uses
  System.Classes, System.Threading, System.Math, System.SyncObjs,
  System.Generics.Collections
  {$IFDEF MACSCAN_WINDOWS}, Winapi.Windows{$ENDIF}
  {$IFDEF MACSCAN_POSIX}, Posix.Base, IdGlobal, IdUDPClient, IdTCPClient{$ENDIF};

const
  MaxScanHosts = 65534;   // up to a /16
{$IFDEF MACSCAN_WINDOWS}
  MaxThreads    = 64;     // SendARP blocks ~1-3 s on an empty address
  ProgressSteps = 200;    // max progress events per scan (keeps UI responsive)
{$ENDIF}
{$IFDEF MACSCAN_POSIX}
  BatchSize  = 256;
  ArpWaitMs  = 1500;      // time allowed for ARP replies per pass
  SliceMs    = 250;       // ARP table is re-read this often for live progress
  ProbePort  = 9;         // UDP "discard"; any port works, ARP happens first
{$ENDIF}

{ ---------------------------------------------------------------------------
  Common helpers
  --------------------------------------------------------------------------- }

function TryParseIPv4(const S: string; out Addr: Cardinal): Boolean;
var
  Parts: TArray<string>;
  I, Octet: Integer;
begin
  Result := False;
  Addr := 0;
  Parts := S.Trim.Split(['.']);
  if Length(Parts) <> 4 then
    Exit;
  for I := 0 to 3 do
  begin
    if not TryStrToInt(Parts[I], Octet) or (Octet < 0) or (Octet > 255) then
      Exit;
    Addr := (Addr shl 8) or Cardinal(Octet);
  end;
  Result := True;
end;

function ParseIPv4(const S: string): Cardinal;
begin
  if not TryParseIPv4(S, Result) then
    raise EArgumentException.CreateFmt('Invalid IPv4 address: "%s"', [S]);
end;

function IPv4ToStr(A: Cardinal): string;
begin
  Result := Format('%d.%d.%d.%d',
    [(A shr 24) and $FF, (A shr 16) and $FF, (A shr 8) and $FF, A and $FF]);
end;

function ParseMask(const S: string): Cardinal;
var
  T: string;
  Prefix: Integer;
  Inv: Cardinal;
begin
  T := S.Trim;
  if T.StartsWith('/') then
    T := T.Substring(1);

  if TryStrToInt(T, Prefix) then
  begin
    if (Prefix < 1) or (Prefix > 32) then
      raise EArgumentException.CreateFmt('Invalid prefix length: "%s"', [S]);
    if Prefix = 32 then
      Result := $FFFFFFFF
    else
      Result := not (Cardinal($FFFFFFFF) shr Prefix);
  end
  else
  begin
    if not TryParseIPv4(T, Result) or (Result = 0) then
      raise EArgumentException.CreateFmt('Invalid subnet mask: "%s"', [S]);
    Inv := not Result;
    if (Inv and (Inv + 1)) <> 0 then   // mask bits must be contiguous
      raise EArgumentException.CreateFmt('Non-contiguous subnet mask: "%s"', [S]);
  end;
end;

procedure GetHostRange(const ANetwork, ASubnet: string; out First: Cardinal;
  out Count: Integer);
var
  Addr, Mask, Net, Bcast: Cardinal;
begin
  Addr  := ParseIPv4(ANetwork);
  Mask  := ParseMask(ASubnet);
  Net   := Addr and Mask;
  Bcast := Net or not Mask;

  if Mask >= $FFFFFFFE then   // /31 and /32: every address is a host
  begin
    First := Net;
    Count := Integer(Bcast - Net) + 1;
  end
  else                        // skip network and broadcast addresses
  begin
    First := Net + 1;
    Count := Integer(Bcast - Net) - 1;
  end;

  if Count > MaxScanHosts then
    raise EArgumentException.CreateFmt(
      'Subnet too large (%d hosts). Maximum supported is a /16.', [Count]);
end;

/// Accepts 'a4:2b:b0:1:2:3', 'A4-2B-B0-01-02-03' etc. Returns
/// 'A4:2B:B0:01:02:03', or '' for invalid, all-zero or broadcast MACs.
function NormalizeMac(const S: string): string;
var
  Parts: TArray<string>;
  I, B: Integer;
  AllZero, AllFF: Boolean;
begin
  Result := '';
  Parts := S.Trim.Split([':', '-']);
  if Length(Parts) <> 6 then
    Exit;
  AllZero := True;
  AllFF := True;
  for I := 0 to 5 do
  begin
    if (Parts[I].Length < 1) or (Parts[I].Length > 2) or
       not TryStrToInt('$' + Parts[I], B) then
      Exit('');
    if B <> 0 then AllZero := False;
    if B <> $FF then AllFF := False;
    Parts[I] := IntToHex(B, 2);
  end;
  if AllZero or AllFF then
    Exit('');
  Result := string.Join(':', Parts);
end;

function CollectResults(First: Cardinal; const Macs: TArray<string>): TMacEntries;
var
  I, N: Integer;
begin
  SetLength(Result, Length(Macs));
  N := 0;
  for I := 0 to High(Macs) do
    if Macs[I] <> '' then
    begin
      Result[N].IP  := IPv4ToStr(First + Cardinal(I));
      Result[N].MAC := Macs[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

type
  /// nil = accept every MAC
  TMacFilter = reference to function(const AMac: string): Boolean;
  /// Called from worker threads; RunScanAsync marshals it to the UI thread.
  TScanProgressProc = reference to procedure(Processed, Found, Total: Integer);

function MacMatches(const AMac: string; const AFilter: TMacFilter): Boolean;
begin
  Result := (AMac <> '') and (not Assigned(AFilter) or AFilter(AMac));
end;

function FilterEntries(const AEntries: TMacEntries;
  const AFilter: TMacFilter): TMacEntries;
var
  I, N: Integer;
begin
  if not Assigned(AFilter) then
    Exit(AEntries);
  SetLength(Result, Length(AEntries));
  N := 0;
  for I := 0 to High(AEntries) do
    if AFilter(AEntries[I].MAC) then
    begin
      Result[N] := AEntries[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

{ ---------------------------------------------------------------------------
  Windows: SendARP
  --------------------------------------------------------------------------- }

{$IFDEF MACSCAN_WINDOWS}

function SendARP(DestIP, SrcIP: Cardinal; pMacAddr: Pointer;
  var PhyAddrLen: Cardinal): DWORD; stdcall; external 'iphlpapi.dll' name 'SendARP';

/// Host byte order (a.b.c.d = a shl 24 ...) to network byte order.
function HostToNet(A: Cardinal): Cardinal;
begin
  Result := ((A and $000000FF) shl 24) or ((A and $0000FF00) shl 8) or
            ((A and $00FF0000) shr 8)  or ((A and $FF000000) shr 24);
end;

function ArpLookup(IP: Cardinal): string;
var
  Mac: array[0..7] of Byte;
  Len: Cardinal;
  I: Integer;
  S: string;
begin
  Result := '';
  FillChar(Mac, SizeOf(Mac), 0);
  Len := SizeOf(Mac);
  if (SendARP(HostToNet(IP), 0, @Mac[0], Len) = NO_ERROR) and (Len = 6) then
  begin
    S := '';
    for I := 0 to 5 do
    begin
      if I > 0 then
        S := S + ':';
      S := S + IntToHex(Mac[I], 2);
    end;
    Result := NormalizeMac(S);
  end;
end;

function PlatformScan(First: Cardinal; Count: Integer;
  const AFilter: TMacFilter; const AProgress: TScanProgressProc): TMacEntries;
var
  Macs: TArray<string>;
  Pool: TThreadPool;
  Processed, Found, Step: Integer;
  Body: TProc<Integer>;
begin
  SetLength(Macs, Count);
  Processed := 0;
  Found := 0;
  Step := Max(1, Count div ProgressSteps);

  Pool := TThreadPool.Create;
  try
    Pool.SetMaxWorkerThreads(MaxThreads);
    Pool.SetMinWorkerThreads(MaxThreads);
    Body :=
      procedure(Idx: Integer)
      var
        Mac: string;
        P: Integer;
      begin
        Mac := ArpLookup(First + Cardinal(Idx));
        Macs[Idx] := Mac;                       // each task owns its slot
        if MacMatches(Mac, AFilter) then
          TInterlocked.Increment(Found);        // before Processed, so the
        P := TInterlocked.Increment(Processed); // final count is exact
        if Assigned(AProgress) and (P mod Step = 0) then
          AProgress(P, TInterlocked.CompareExchange(Found, 0, 0), Count);
      end;
    TParallel.For(0, Count - 1, Body, Pool);
  finally
    Pool.Free;
  end;

  // SendARP resolves at least the router on any working LAN, so finding no
  // host at all means it is not working here (blocked, or no usable adapter).
  if Length(CollectResults(First, Macs)) = 0 then
    raise EOSError.Create('SendARP did not resolve any address on the network, ' +
      'so the ARP table could not be used here.');

  if Assigned(AProgress) then
    AProgress(Count, Found, Count);
  Result := FilterEntries(CollectResults(First, Macs), AFilter);
end;

{$ENDIF}

{ ---------------------------------------------------------------------------
  macOS / Linux: UDP probe + read ARP table
  --------------------------------------------------------------------------- }

{$IFDEF MACSCAN_POSIX}

// The C stdio calls used to read the ARP table, imported straight from libc:
// Delphi's Posix.Stdio does not declare popen/pclose/fgets or PFILE under
// these names on every POSIX target (macOS ARM64 in particular).
type
  PFILE = Pointer;

function fopen(filename, mode: PAnsiChar): PFILE; cdecl;
  external libc name _PU + 'fopen';
function fclose(stream: PFILE): Integer; cdecl;
  external libc name _PU + 'fclose';
function popen(command, mode: PAnsiChar): PFILE; cdecl;
  external libc name _PU + 'popen';
function pclose(stream: PFILE): Integer; cdecl;
  external libc name _PU + 'pclose';
function fgets(s: PAnsiChar; n: Integer; stream: PFILE): PAnsiChar; cdecl;
  external libc name _PU + 'fgets';

procedure ProbeHosts(First: Cardinal; Count: Integer);
var
  UDP: TIdUDPClient;
  Payload: TIdBytes;
  I: Integer;
begin
  UDP := TIdUDPClient.Create(nil);
  try
    SetLength(Payload, 1);
    Payload[0] := 0;
    for I := 0 to Count - 1 do
      try
        UDP.SendBuffer(IPv4ToStr(First + Cardinal(I)), ProbePort, Payload);
      except
        // EHOSTDOWN / EHOSTUNREACH are expected for unused addresses
      end;
  finally
    UDP.Free;
  end;
end;

{$IFDEF MACOS}
// macOS: the ARP table is read from the kernel with sysctl, exactly as
// /usr/sbin/arp does, so no child process is needed. Running "arp -an" stays
// as a fallback.

function sysctl(name: PInteger; namelen: Cardinal; oldp: Pointer;
  oldlenp: PNativeUInt; newp: Pointer; newlen: NativeUInt): Integer; cdecl;
  external libc name _PU + 'sysctl';

const
  CTL_NET        = 4;
  PF_ROUTE       = 17;
  AF_INET_       = 2;
  AF_LINK_       = 18;
  NET_RT_FLAGS   = 2;
  RTF_LLINFO     = $400;
  RT_MSGHDR_SIZE = 92;   // sizeof(struct rt_msghdr) on macOS

/// Adds the kernel's ARP entries to ATable. False if sysctl failed.
/// AHidden counts entries whose MAC the system replaced with the privacy
/// placeholder 02:00:00:00:00:00; those are left out.
function ReadArpTableSysctl(ATable: TDictionary<Cardinal, string>;
  out AHidden: Integer): Boolean;
var
  Mib: array[0..5] of Integer;
  Needed: NativeUInt;
  Buf: TBytes;
  Attempt, P, MsgLen, Sin, SinLen, Sdl, NLen, ALen, I: Integer;
  IP: Cardinal;
  Mac: string;
  Got: Boolean;
begin
  Result := False;
  AHidden := 0;
  Mib[0] := CTL_NET;
  Mib[1] := PF_ROUTE;
  Mib[2] := 0;
  Mib[3] := AF_INET_;
  Mib[4] := NET_RT_FLAGS;
  Mib[5] := RTF_LLINFO;

  // The table can grow between asking for its size and reading it.
  Buf := nil;
  Got := False;
  for Attempt := 1 to 3 do
  begin
    Needed := 0;
    if sysctl(@Mib[0], 6, nil, @Needed, nil, 0) <> 0 then
      Exit;
    if Needed = 0 then
      Exit(True);                         // empty table
    Needed := Needed + Needed div 2 + 1024;
    SetLength(Buf, Needed);
    if sysctl(@Mib[0], 6, @Buf[0], @Needed, nil, 0) = 0 then
    begin
      SetLength(Buf, Needed);
      Got := True;
      Break;
    end;
  end;
  if not Got then
    Exit;

  // A run of: rt_msghdr, sockaddr_inarp (the IP), sockaddr_dl (the MAC).
  P := 0;
  while P + RT_MSGHDR_SIZE <= Length(Buf) do
  begin
    MsgLen := PWord(@Buf[P])^;           // rtm_msglen, native byte order
    if (MsgLen < RT_MSGHDR_SIZE) or (P + MsgLen > Length(Buf)) then
      Break;
    Sin := P + RT_MSGHDR_SIZE;
    SinLen := Buf[Sin];
    if (SinLen >= 8) and (Buf[Sin + 1] = AF_INET_) then
    begin
      IP := (Cardinal(Buf[Sin + 4]) shl 24) or (Cardinal(Buf[Sin + 5]) shl 16) or
            (Cardinal(Buf[Sin + 6]) shl 8) or Cardinal(Buf[Sin + 7]);
      Sdl := Sin + ((SinLen + 3) and not 3);   // sockaddrs are 4-byte aligned
      if (Sdl + 8 <= P + MsgLen) and (Buf[Sdl + 1] = AF_LINK_) then
      begin
        NLen := Buf[Sdl + 5];            // interface name length
        ALen := Buf[Sdl + 6];            // address length; 0 = incomplete
        if (ALen = 6) and (Sdl + 8 + NLen + 6 <= P + MsgLen) then
        begin
          Mac := '';
          for I := 0 to 5 do
          begin
            if I > 0 then
              Mac := Mac + ':';
            Mac := Mac + IntToHex(Buf[Sdl + 8 + NLen + I], 2);
          end;
          Mac := NormalizeMac(Mac);
          if Mac = '02:00:00:00:00:00' then
            Inc(AHidden)
          else if Mac <> '' then
            ATable.AddOrSetValue(IP, Mac);
        end;
      end;
    end;
    Inc(P, MsgLen);
  end;
  Result := True;
end;
{$ENDIF}

/// Adds the entries of a text ARP listing to ATable: "arp -an" output on
/// macOS, /proc/net/arp on Linux. False if the source could not be opened.
function ReadArpTableText(ATable: TDictionary<Cardinal, string>;
  out ALines: Integer): Boolean;
var
  F: PFILE;
  Buf: array[0..1023] of AnsiChar;
  Parts: TArray<string>;
  IP: Cardinal;
  Mac: string;
  Src: UTF8String;
{$IFNDEF MACOS}
  Flags: Integer;
{$ENDIF}
begin
{$IFDEF MACOS}
  Src := '/usr/sbin/arp -an';
  F := popen(PAnsiChar(Src), 'r');
{$ELSE}
  Src := '/proc/net/arp';
  F := fopen(PAnsiChar(Src), 'r');
{$ENDIF}
  ALines := 0;
  Result := F <> nil;
  if not Result then
    Exit;

  try
    while fgets(@Buf[0], Length(Buf), F) <> nil do
    begin
      Inc(ALines);
      Parts := UTF8ToString(PAnsiChar(@Buf[0])).Split([' ', #9, #10, #13],
        TStringSplitOptions.ExcludeEmpty);
{$IFDEF MACOS}
      // ? (192.168.1.1) at a4:2b:b0:1:2:3 on en0 ifscope [ethernet]
      // ? (192.168.1.7) at (incomplete) on en0 ifscope [ethernet]
      if (Length(Parts) >= 4) and (Parts[2] = 'at') and
         TryParseIPv4(Parts[1].Trim(['(', ')']), IP) then
      begin
        Mac := NormalizeMac(Parts[3]);
        if Mac <> '' then
          ATable.AddOrSetValue(IP, Mac);
      end;
{$ELSE}
      // IP address  HW type  Flags  HW address         Mask  Device
      // 192.168.1.1 0x1      0x2    a4:2b:b0:11:22:33  *     wlan0
      if (Length(Parts) >= 4) and TryParseIPv4(Parts[0], IP) and
         TryStrToInt('$' + Parts[2].Replace('0x', ''), Flags) and
         ((Flags and $2) <> 0) then   // ATF_COM = entry complete
      begin
        Mac := NormalizeMac(Parts[3]);
        if Mac <> '' then
          ATable.AddOrSetValue(IP, Mac);
      end;
{$ENDIF}
    end;
  finally
{$IFDEF MACOS}
    pclose(F);
{$ELSE}
    fclose(F);
{$ENDIF}
  end;
end;

var
  // What the last ReadArpTable saw, for error messages.
  ArpReadInfo: string;

/// Returns IP (host order) -> normalised MAC for all complete ARP entries.
function ReadArpTable: TDictionary<Cardinal, string>;
var
  OK: Boolean;
  Lines: Integer;
{$IFDEF MACOS}
  TextOK: Boolean;
  Hidden: Integer;
{$ENDIF}
begin
  Result := TDictionary<Cardinal, string>.Create;
  try
{$IFDEF MACOS}
    OK := ReadArpTableSysctl(Result, Hidden);
    if OK then
      ArpReadInfo := Format('sysctl: %d entries, %d hidden', [Result.Count, Hidden])
    else
      ArpReadInfo := Format('sysctl: failed (errno %d)', [GetLastError]);
    if Result.Count = 0 then
    begin
      TextOK := ReadArpTableText(Result, Lines);
      if TextOK then
        ArpReadInfo := ArpReadInfo + Format('; arp -an: %d lines, %d entries',
          [Lines, Result.Count])
      else
        ArpReadInfo := ArpReadInfo + '; arp -an: could not be run';
      OK := OK or TextOK;
    end;
{$ELSE}
    OK := ReadArpTableText(Result, Lines);
    if OK then
      ArpReadInfo := Format('/proc/net/arp: %d lines, %d entries', [Lines, Result.Count])
    else
      ArpReadInfo := '/proc/net/arp: could not be opened';
{$ENDIF}
    if not OK then
      raise EOSError.Create('Could not read the ARP table (' + ArpReadInfo + ')');
  except
    Result.Free;
    raise;
  end;
end;

/// Copies the current ARP table into Macs[Start..Start+N-1] and returns how
/// many of those match the filter.
function ApplyArpTable(First: Cardinal; Start, N: Integer;
  var Macs: TArray<string>; const AFilter: TMacFilter;
  var ATableSeen: Boolean): Integer;
var
  Table: TDictionary<Cardinal, string>;
  I: Integer;
begin
  Result := 0;
  Table := ReadArpTable;
  try
    if Table.Count > 0 then
      ATableSeen := True;
    for I := Start to Start + N - 1 do
    begin
      if not Table.TryGetValue(First + Cardinal(I), Macs[I]) then
        Macs[I] := '';
      if MacMatches(Macs[I], AFilter) then
        Inc(Result);
    end;
  finally
    Table.Free;
  end;
end;

function PlatformScan(First: Cardinal; Count: Integer;
  const AFilter: TMacFilter; const AProgress: TScanProgressProc): TMacEntries;
var
  Macs: TArray<string>;
  Start, N, Pass, Waited, FoundBefore, FoundNow, Processed: Integer;
  TableSeen: Boolean;
begin
  SetLength(Macs, Count);
  Start := 0;
  FoundBefore := 0;
  TableSeen := False;
  while Start < Count do
  begin
    N := Min(BatchSize, Count - Start);
    FoundNow := 0;

    // Two passes: the second catches WiFi clients in power-save mode that
    // missed the first ARP request. The ARP table is re-read every SliceMs
    // so Found updates live while replies arrive.
    for Pass := 0 to 1 do
    begin
      ProbeHosts(First + Cardinal(Start), N);
      Waited := 0;
      while Waited < ArpWaitMs do
      begin
        Sleep(SliceMs);
        Inc(Waited, SliceMs);
        FoundNow := ApplyArpTable(First, Start, N, Macs, AFilter, TableSeen);
        if Assigned(AProgress) then
        begin
          // All IPs in the batch are queried together, so Processed advances
          // through the batch with the wait time; exact at each batch end.
          Processed := Start + Integer(Int64(N) * (Pass * ArpWaitMs + Waited)
            div (2 * ArpWaitMs));
          AProgress(Processed, FoundBefore + FoundNow, Count);
        end;
      end;
    end;

    Inc(FoundBefore, FoundNow);
    Inc(Start, N);
  end;

  // A LAN always has at least the router in its ARP table once probed, so an
  // empty table means it could not be read, not that nothing is there.
  if not TableSeen then
{$IFDEF MACOS}
  begin
    // macOS sets this variable in every process running in the App Sandbox.
    if GetEnvironmentVariable('APP_SANDBOX_CONTAINER_ID') <> '' then
      raise EOSError.Create('The ARP table came back empty after probing every ' +
        'address (' + ArpReadInfo + '). This app runs in the macOS App Sandbox, ' +
        'which hides the routing table and the local network from it and from ' +
        'programs it starts. Turn off App Sandbox in Project Options > ' +
        'Application > Entitlement List and rebuild.');
    raise EOSError.Create('The ARP table came back empty after probing every ' +
      'address (' + ArpReadInfo + '). Recent macOS versions hide the ARP table ' +
      'from apps even when they may use the local network, so the MAC stage ' +
      'cannot run here. Find devices another way, for example by TCP (Tapo.Discovery ' +
      'does this automatically).');
  end;
{$ELSE}
    raise EOSError.Create('The ARP table came back empty after probing every ' +
      'address, so it could not be read (' + ArpReadInfo + ').');
{$ENDIF}

  if Assigned(AProgress) then
    AProgress(Count, FoundBefore, Count);
  Result := FilterEntries(CollectResults(First, Macs), AFilter);
end;

{$ENDIF}

{ ---------------------------------------------------------------------------
  Public API
  --------------------------------------------------------------------------- }

function MacScanSupported: Boolean;
begin
{$IF DEFINED(MACSCAN_WINDOWS) or DEFINED(MACSCAN_POSIX)}
  Result := True;
{$ELSE}
  Result := False;
{$ENDIF}
end;

function SubnetHosts(const ANetwork, ASubnet: string): TArray<string>;
var
  First: Cardinal;
  Count, I: Integer;
begin
  GetHostRange(ANetwork, ASubnet, First, Count);
  SetLength(Result, Count);
  for I := 0 to Count - 1 do
    Result[I] := IPv4ToStr(First + Cardinal(I));
end;

function MacScanDiagnostics(const AProbeHost: string): string;
{$IFDEF MACSCAN_POSIX}
var
  L: TStringList;
  Gateway: string;

  // A TCP connection to a local address needs local network access on
  // macOS 15+; when it is denied the connect fails at once.
  procedure TcpCheck(const AHost: string; APort: Integer);
  var
    C: TIdTCPClient;
  begin
    C := TIdTCPClient.Create(nil);
    try
      C.Host := AHost;
      C.Port := APort;
      C.ConnectTimeout := 2000;
      try
        C.Connect;
        L.Add(Format('TCP connect %s:%d: OK', [AHost, APort]));
        C.Disconnect;
      except
        on E: Exception do
          L.Add(Format('TCP connect %s:%d: %s: %s', [AHost, APort, E.ClassName, E.Message]));
      end;
    finally
      C.Free;
    end;
  end;

  function HexBytes(const B: TBytes; AStart, ACount: Integer): string;
  var
    I: Integer;
  begin
    Result := '';
    for I := AStart to Min(AStart + ACount, Length(B)) - 1 do
      Result := Result + IntToHex(B[I], 2) + ' ';
  end;

  procedure RunCmd(const ACmd: string; AMaxLines: Integer);
  var
    F: PFILE;
    Buf: array[0..1023] of AnsiChar;
    Cmd: UTF8String;
    N, RC: Integer;
  begin
    Cmd := UTF8String(ACmd);
    F := popen(PAnsiChar(Cmd), 'r');
    if F = nil then
    begin
      L.Add(Format('popen(%s): nil, errno %d', [ACmd, GetLastError]));
      Exit;
    end;
    N := 0;
    while fgets(@Buf[0], Length(Buf), F) <> nil do
    begin
      Inc(N);
      if N <= AMaxLines then
        L.Add('  | ' + TrimRight(UTF8ToString(PAnsiChar(@Buf[0]))));
    end;
    RC := pclose(F);
    L.Add(Format('popen(%s): %d line(s), pclose=%d', [ACmd, N, RC]));
  end;

{$IFDEF MACOS}
  // The gateway of the first IPv4 default route in a NET_RT_DUMP buffer.
  procedure FindGateway(const Buf: TBytes; ALen: Integer);
  var
    P, MsgLen, Dst, DstLen, Gw: Integer;
  begin
    P := 0;
    while (Gateway = '') and (P + RT_MSGHDR_SIZE + 16 <= ALen) do
    begin
      MsgLen := PWord(@Buf[P])^;
      if (MsgLen < RT_MSGHDR_SIZE) or (P + MsgLen > ALen) then
        Break;
      Dst := P + RT_MSGHDR_SIZE;
      DstLen := Buf[Dst];
      // RTA_DST and RTA_GATEWAY present, RTF_GATEWAY set, dst 0.0.0.0
      if ((PInteger(@Buf[P + 12])^ and 3) = 3) and ((PInteger(@Buf[P + 8])^ and 2) <> 0) and
         (DstLen >= 8) and (Buf[Dst + 1] = AF_INET_) and
         (Buf[Dst + 4] or Buf[Dst + 5] or Buf[Dst + 6] or Buf[Dst + 7] = 0) then
      begin
        Gw := Dst + ((DstLen + 3) and not 3);
        if (Gw + 8 <= P + MsgLen) and (Buf[Gw + 1] = AF_INET_) then
          Gateway := Format('%d.%d.%d.%d', [Buf[Gw + 4], Buf[Gw + 5], Buf[Gw + 6], Buf[Gw + 7]]);
      end;
      Inc(P, MsgLen);
    end;
  end;

  procedure SysctlCheck(const AName: string; AOp, AArg: Integer);
  var
    Mib: array[0..5] of Integer;
    Needed, Got: NativeUInt;
    RC, Err: Integer;
    Buf: TBytes;
  begin
    Mib[0] := CTL_NET;
    Mib[1] := PF_ROUTE;
    Mib[2] := 0;
    Mib[3] := AF_INET_;
    Mib[4] := AOp;
    Mib[5] := AArg;
    Needed := 0;
    RC := sysctl(@Mib[0], 6, nil, @Needed, nil, 0);
    Err := GetLastError;
    L.Add(Format('sysctl %s size: rc=%d errno=%d needed=%d',
      [AName, RC, Err, Int64(Needed)]));
    if (RC <> 0) or (Needed = 0) then
      Exit;
    Got := Needed * 2;
    SetLength(Buf, Got);
    RC := sysctl(@Mib[0], 6, @Buf[0], @Got, nil, 0);
    Err := GetLastError;
    L.Add(Format('sysctl %s read: rc=%d errno=%d bytes=%d',
      [AName, RC, Err, Int64(Got)]));
    if (RC = 0) and (Got >= RT_MSGHDR_SIZE + 8) then
    begin
      L.Add(Format('  record 1: msglen=%d version=%d type=%d flags=$%x addrs=$%x',
        [PWord(@Buf[0])^, Buf[2], Buf[3], PInteger(@Buf[8])^, PInteger(@Buf[12])^]));
      L.Add('  after header: ' + HexBytes(Buf, RT_MSGHDR_SIZE, 32));
      FindGateway(Buf, Integer(Got));
    end;
  end;
{$ENDIF}

begin
  Gateway := '';
  L := TStringList.Create;
  try
{$IFDEF MACOS}
    L.Add('Platform: macOS');
{$ELSE}
    L.Add('Platform: Linux');
{$ENDIF}
    L.Add('Sandbox container: "' + GetEnvironmentVariable('APP_SANDBOX_CONTAINER_ID') + '"');
    RunCmd('/bin/echo popen works', 2);
{$IFDEF MACOS}
    SysctlCheck('ARP (NET_RT_FLAGS, RTF_LLINFO)', NET_RT_FLAGS, RTF_LLINFO);
    SysctlCheck('all routes (NET_RT_DUMP)', 1, 0);
    RunCmd('/usr/sbin/arp -an 2>&1; echo "exit status $?"', 4);
    RunCmd('/usr/sbin/netstat -rn -f inet 2>&1', 4);
{$ELSE}
    RunCmd('/bin/cat /proc/net/arp 2>&1', 4);
{$ENDIF}
    if AProbeHost <> '' then
      Gateway := AProbeHost;
    if Gateway <> '' then
    begin
      TcpCheck(Gateway, 80);
      TcpCheck(Gateway, 53);
    end
    else
      L.Add('TCP connect: no host to try (pass one to MacScanDiagnostics)');
    Result := L.Text;
  finally
    L.Free;
  end;
end;
{$ELSE}
begin
  Result := 'Windows: the scan uses SendARP; there is nothing to diagnose here.';
end;
{$ENDIF}

function DoScan(const ANetwork, ASubnet: string; const AFilter: TMacFilter;
  const AProgress: TScanProgressProc): TMacEntries;
{$IF DEFINED(MACSCAN_WINDOWS) or DEFINED(MACSCAN_POSIX)}
var
  First: Cardinal;
  Count: Integer;
begin
  GetHostRange(ANetwork, ASubnet, First, Count);
  if Assigned(AProgress) then
    AProgress(0, 0, Count);
  Result := PlatformScan(First, Count, AFilter, AProgress);
end;
{$ELSE}
begin
  raise ENotSupportedException.Create(
    'Reading other devices'' MAC addresses is blocked by the operating system ' +
    'on this platform (Android 10+ / iOS 11+).');
end;
{$ENDIF}

/// Separate routine so each queued call captures its own copy of the values.
procedure QueueProgress(const AEvent: TMacScanProgressEvent; ASender: TObject;
  AProcessed, AFound, ATotal: Integer);
var
  Proc: TThreadProcedure;
begin
  // assigned to a typed variable first, so Queue has no overload to resolve
  Proc :=
    procedure
    begin
      AEvent(ASender, AProcessed, AFound, ATotal);
    end;
  TThread.Queue(nil, Proc);
end;

/// Queues the completion callback (separate routine, own copies of the values).
procedure QueueComplete(const AOnComplete: TMacScanCompleteProc;
  const AEntries: TMacEntries; const AErrorMsg: string);
var
  Proc: TThreadProcedure;
begin
  Proc :=
    procedure
    begin
      AOnComplete(AEntries, AErrorMsg);
    end;
  TThread.Queue(nil, Proc);
end;

procedure RunScanAsync(const ANetwork, ASubnet: string;
  const AFilter: TMacFilter; const AOnComplete: TMacScanCompleteProc;
  const AOnProgress: TMacScanProgressEvent; ASender: TObject);
var
  Work: TProc;
begin
  Work :=
    procedure
    var
      Entries: TMacEntries;
      Err: string;
      Lock: TObject;
      LastProcessed, LastFound: Integer;
      Progress: TScanProgressProc;
    begin
      Err := '';
      LastProcessed := -1;
      LastFound := 0;
      Lock := TObject.Create;
      try
        Progress := nil;
        if Assigned(AOnProgress) then
          Progress :=
            procedure(Processed, Found, Total: Integer)
            begin
              // Worker threads report out of order; only ever move forward,
              // so the progress bar never jumps backwards.
              TMonitor.Enter(Lock);
              try
                Found := Max(Found, LastFound);
                if (Processed > LastProcessed) or
                   ((Processed = LastProcessed) and (Found > LastFound)) then
                begin
                  LastProcessed := Processed;
                  LastFound := Found;
                  QueueProgress(AOnProgress, ASender, Processed, Found, Total);
                end;
              finally
                TMonitor.Exit(Lock);
              end;
            end;

        try
          Entries := DoScan(ANetwork, ASubnet, AFilter, Progress);
        except
          on E: Exception do
            Err := E.Message;
        end;
      finally
        Lock.Free;
      end;

      if Assigned(AOnComplete) then
        QueueComplete(AOnComplete, Entries, Err);
    end;
  TTask.Run(Work);
end;

function ScanNetworkMacs(const ANetwork, ASubnet: string): TMacEntries;
begin
  Result := DoScan(ANetwork, ASubnet, nil, nil);
end;

procedure ScanNetworkMacsAsync(const ANetwork, ASubnet: string;
  const AOnComplete: TMacScanCompleteProc;
  const AOnProgress: TMacScanProgressEvent; ASender: TObject);
begin
  RunScanAsync(ANetwork, ASubnet, nil, AOnComplete, AOnProgress, ASender);
end;

{ ---------------------------------------------------------------------------
  Tapo filtering
  --------------------------------------------------------------------------- }

const
  // TP-Link OUIs from the IEEE MA-L registry (October 2026), uppercase, no
  // separators. "TP-LINK TECHNOLOGIES CO.,LTD." + "TP-Link Corporation Limited".
  TpLinkOuis: array[0..268] of string = (
    '000AEB', '001478', '0019E0', '001D0F', '002127', '0023CD', '002586', '002719', '003192', '005F67',
    '040F66', '04C845', '04F9F8', '081F71', '085700', '0C4B54', '0C722C', '0C8063', '0C8268', '0CEF15',
    '1027F5', '105A95', '10FEED', '147590', '148692', '14CC20', '14CF92', '14D864', '14E6E4', '14EBB6',
    '186945', '18A6F7', '18D6C7', '18F22C', '1C3BF3', '1C4419', '1C61B4', '1CFA68', '202351', '203626',
    '206BE7', '20DCE6', '20E15D', '242FD0', '245A5F', '246968', '282CB2', '2887BA', '289104', '28EE52',
    '2C79BE', '306893', '30B49E', '30B5C2', '30DE4B', '30FC68', '3460F9', '349672', '34B126', '34E894',
    '34F716', '388345', '3C06A7', '3C46D8', '3C52A1', '3C64CF', '3C6A48', '3C6AD2', '3C7895', '3C846A',
    '40169F', '403F8C', '409595', '40AE30', '40ED00', '446690', '44B32D', '480EEC', '482254', '485F08',
    '487D2E', '48C381', '4C10D5', '503DD1', '503EAA', '5091E3', '50BD5F', '50C7BF', '50D4F7', '50FA84',
    '547595', '54A703', '54AF97', '54C80F', '54D299', '54E6FC', '58044F', '584120', '58D812', '5C628B',
    '5C63BF', '5C899A', '5CA64F', '5CA6E6', '5CE931', '60156F', '60292B', '6032B1', '603A7C', '6083E7',
    '60A3E3', '60A4B7', '60E327', '645601', '6466B3', '646E97', '647002', '687724', '687FF0', '68DDB7',
    '68FF7B', '6C4CBC', '6C5AB0', '6CB158', '6CE873', '704F57', '7405A5', '743989', '74DA88', '74EA3A',
    '74FECE', '782051', '7844FD', '78605B', '788CB5', '78A106', '78C05A', '7C8BCA', '7CB59B', '7CC2C6',
    '7CF17E', '803C04', '808917', '808F1D', '80AE54', '80EA07', '8416F9', '84B890', '84D81B', '882593',
    '889986', '8C210A', '8C86DD', '8C902D', '8CA6DF', '901F94', '909A4A', '90AE1B', '90F652', '940C6D',
    '94D9B3', '94EF50', '98038E', '98254A', '984827', '9897CC', '98BA5F', '98DAC4', '98DED0', '9C216A',
    '9C4782', '9C5322', '9CA2F4', '9CA615', 'A0F3C1', 'A41A3A', 'A42BB0', 'A8154D', 'A82948', 'A829DC',
    'A842A1', 'A8574E', 'A86E84', 'AC15A2', 'AC84C6', 'ACA7F1', 'B01921', 'B0487A', 'B04E26', 'B09575',
    'B0958E', 'B0A7B9', 'B0BE76', 'B45BD1', 'B4B024', 'B4C0C3', 'B8F883', 'B8FBB3', 'BC071D', 'BC4699',
    'BCD177', 'BCD849', 'C006C3', 'C025E9', 'C03A55', 'C04A00', 'C06118', 'C0C9E3', 'C0E42D', 'C46E1F',
    'C47154', 'C4E984', 'CC08FB', 'CC32E5', 'CC3429', 'CC68B6', 'CCBABD', 'D02791', 'D03745', 'D05D01',
    'D076E7', 'D0C7C0', 'D4016D', 'D46E0E', 'D4D6DF', 'D807B6', 'D80D17', 'D8150D', 'D84489', 'D84732',
    'D85D4C', 'D8F12E', 'DC0077', 'DC6279', 'DCFE18', 'E005C5', 'E0280A', 'E0D362', 'E443CF', 'E4C32A',
    'E4D332', 'E4FAC4', 'E848B8', 'E894F6', 'E8DE27', 'EC086B', 'EC172F', 'EC26CA', 'EC6073', 'EC750C',
    'EC888F', 'ECB931', 'F0090D', 'F0A731', 'F0F336', 'F42A7D', 'F46D2F', 'F483CD', 'F4848D', 'F4EC38',
    'F4F26D', 'F4F50B', 'F81A67', 'F86FB0', 'F88C21', 'F8C903', 'F8CE21', 'F8D111', 'FCD733');

var
  TapoOuiSet: TDictionary<string, Boolean>;

/// 'AA:BB:CC...', 'aa-bb-cc', 'AABBCC' -> 'AABBCC' (or '' if invalid).
function OuiKey(const S: string): string;
var
  C: Char;
begin
  Result := '';
  for C in S do
  begin
    if CharInSet(C, ['0'..'9', 'A'..'F', 'a'..'f']) then
      Result := Result + UpCase(C)
    else if not CharInSet(C, [':', '-', '.', ' ']) then
      Exit('');
    if Length(Result) = 6 then
      Exit;
  end;
  if Length(Result) <> 6 then
    Result := '';
end;

function IsTapoMac(const AMac: string): Boolean;
var
  Key: string;
begin
  Key := OuiKey(AMac);
  Result := (Key <> '') and TapoOuiSet.ContainsKey(Key);
end;

function FilterTapoDevices(const AEntries: TMacEntries): TMacEntries;
var
  I, N: Integer;
begin
  SetLength(Result, Length(AEntries));
  N := 0;
  for I := 0 to High(AEntries) do
    if IsTapoMac(AEntries[I].MAC) then
    begin
      Result[N] := AEntries[I];
      Inc(N);
    end;
  SetLength(Result, N);
end;

function ScanTapoDevices(const ANetwork, ASubnet: string): TMacEntries;
begin
  Result := DoScan(ANetwork, ASubnet, IsTapoMac, nil);
end;

procedure ScanTapoDevicesAsync(const ANetwork, ASubnet: string;
  const AOnComplete: TMacScanCompleteProc;
  const AOnProgress: TMacScanProgressEvent; ASender: TObject);
begin
  RunScanAsync(ANetwork, ASubnet, IsTapoMac, AOnComplete, AOnProgress, ASender);
end;

procedure AddTapoOui(const AOui: string);
var
  Key: string;
begin
  Key := OuiKey(AOui);
  if Key = '' then
    raise EArgumentException.CreateFmt('Invalid OUI: "%s"', [AOui]);
  TapoOuiSet.AddOrSetValue(Key, True);
end;

procedure InitTapoOuis;
var
  S: string;
begin
  TapoOuiSet := TDictionary<string, Boolean>.Create(Length(TpLinkOuis));
  for S in TpLinkOuis do
    TapoOuiSet.AddOrSetValue(S, True);
end;

initialization
  InitTapoOuis;

finalization
  TapoOuiSet.Free;

end.
