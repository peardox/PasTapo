//** @abstract(On-demand discovery of Tapo devices on the local network.)
//**
//** @preformatted(
//** The scan has two stages:
//**   1. ARP stage: NetMacScan @(https://github.com/peardox/NetScan@) lists the
//**      hosts that answer on the subnet with their MAC addresses. By default
//**      only TP-Link MAC prefixes are kept; that list still holds routers,
//**      range extenders, Deco units and other TP-Link kit.
//**   2. Probe stage: each candidate is checked with AddDetected on a private
//**      client with short timeouts. A real Tapo device is then added to your
//**      client as the right class, already logged in. Anything else is
//**      reported with the reason and left out.
//** )
//**
//** If the ARP table cannot be read (macOS can hide it from an app), stage 1 is replaced by a TCP
//** sweep: every address is tried on port 80 (plugs, lights, hubs) and, if something answers there
//** with a refusal, on 443 (cameras). See TcpSweepFallback and LastArpError.
//**
//** A scan is slow (seconds for the ARP stage, plus a login per Tapo device), so it only runs when
//** you ask for one. The devices it adds stay in the client, so later code uses Client.Find,
//** Client.Devices[] or Scanner.Devices without scanning again.
//**
//** @preformatted(
//** Scanner := TTapoScanner.Create@(Client@);
//** Scanner.ScanAsync@('192.168.1.0', '/24',
//**   procedure@(const R: TTapoScanResult; const Err: string@)
//**   begin
//**     for Dev in Scanner.Devices do
//**       Memo1.Lines.Add@(Dev.Host + '  ' + Dev.ClassName@);
//**   end@);
//** )
//**
//** Devices are added by IP address. Give them DHCP reservations in the router so the addresses do
//** not change between scans.
//**
//** Needs NetMacScan.pas from the NetScan repository on the search path. Windows, macOS and Linux
//** only: Android and iOS do not let apps read the ARP table (CheckCandidates and CheckHosts work
//** everywhere).
unit Tapo.Discovery;

{
  On-demand discovery of Tapo devices on the local network.

  The scan has two stages:
    1. ARP stage: NetMacScan (https://github.com/peardox/NetScan) lists the
       hosts that answer on the subnet with their MAC addresses. By default
       only TP-Link MAC prefixes are kept; that list still holds routers,
       range extenders, Deco units and other TP-Link kit.
    2. Probe stage: each candidate is checked with AddDetected on a private
       client with short timeouts. A real Tapo device is then added to your
       client as the right class, already logged in. Anything else is
       reported with the reason and left out.

  If the ARP table cannot be read (macOS can hide it from an app), stage 1
  is replaced by a TCP sweep: every address is tried on port 80 (plugs,
  lights, hubs) and, if something answers there with a refusal, on 443
  (cameras). See TcpSweepFallback and LastArpError.

  A scan is slow (seconds for the ARP stage, plus a login per Tapo device),
  so it only runs when you ask for one. The devices it adds stay in the
  client, so later code uses Client.Find, Client.Devices[] or
  Scanner.Devices without scanning again.

    Scanner := TTapoScanner.Create(Client);
    Scanner.ScanAsync('192.168.1.0', '/24',
      procedure(const R: TTapoScanResult; const Err: string)
      begin
        for Dev in Scanner.Devices do
          Memo1.Lines.Add(Dev.Host + '  ' + Dev.ClassName);
      end);

  Devices are added by IP address. Give them DHCP reservations in the
  router so the addresses do not change between scans.

  Needs NetMacScan.pas from the NetScan repository on the search path.
  Windows, macOS and Linux only: Android and iOS do not let apps read the
  ARP table (CheckCandidates and CheckHosts work everywhere).
}

interface

uses
  System.SysUtils, System.Classes, System.Math, System.SyncObjs, System.Threading,
  NetMacScan, Tapo.Client, Tapo.Models;

type
  TTapoScanner = class;

  //** @abstract(What a scan found at one address.)
  /// <summary>What a scan found at one address.</summary>
  TTapoScanStatus = (
    //** @abstract(A Tapo device, added to the client by this scan.)
    /// <summary>A Tapo device, added to the client by this scan.</summary>
    tssAdded,
    //** @abstract(A device the client already had at this address. It was not probed again.)
    /// <summary>A device the client already had at this address. It was not probed again.</summary>
    tssKnown,
    //** @abstract(Nothing answered on port 80 or 443: not a Tapo device.)
    /// <summary>Nothing answered on port 80 or 443: not a Tapo device.</summary>
    tssNoResponse,
    //** @abstract(Something answered but did not log in as a Tapo device. Either it is not one @(a
    //** router, say@), or it is one these credentials do not open. The reason is in
    //** @link(TTapoScanEntry.Error).)
    /// <summary>
    ///   Something answered but did not log in as a Tapo device. Either it is
    ///   not one (a router, say), or it is one these credentials do not open.
    ///   The reason is in <see cref="TTapoScanEntry.Error"/>.
    /// </summary>
    tssRejected,
    //** @abstract(A Tapo device that rejected the account e-mail or password. If no device of the
    //** scan accepted them either, the credentials are wrong.)
    /// <summary>
    ///   A Tapo device that rejected the account e-mail or password. If no
    ///   device of the scan accepted them either, the credentials are wrong.
    /// </summary>
    tssBadCredentials,
    //** @abstract(A Tapo device that logged in, of a model that is not supported.)
    /// <summary>A Tapo device that logged in, of a model that is not supported.</summary>
    tssUnsupported,
    //** @abstract(A Tapo device that is refusing every login for now, after too many failed ones
    //** @(error -2101, or -40401 from a camera@).)
    //**
    //** Nothing is known about the credentials: wait or power-cycle the device, then scan again.
    /// <summary>A Tapo device that is refusing every login for now, after too many failed ones (error -2101, or -40401 from a camera).</summary>
    /// <remarks>Nothing is known about the credentials: wait or power-cycle the device, then scan again.</remarks>
    tssLockedOut,
    //** @abstract(Not probed, because the scan was cancelled first.)
    /// <summary>Not probed, because the scan was cancelled first.</summary>
    tssCancelled);

  //** @abstract(One candidate address and what the scan found there.)
  /// <summary>One candidate address and what the scan found there.</summary>
  TTapoScanEntry = record
    //** @abstract(The IPv4 address.)
    /// <summary>The IPv4 address.</summary>
    IP: string;
    //** @abstract(The MAC address as 'AA:BB:CC:DD:EE:FF': from the ARP stage, or else the one a Tapo
    //** device reports when it is added. Empty for other candidates found by the TCP sweep or
    //** CheckHosts.)
    /// <summary>
    ///   The MAC address as 'AA:BB:CC:DD:EE:FF': from the ARP stage, or else
    ///   the one a Tapo device reports when it is added. Empty for other
    ///   candidates found by the TCP sweep or CheckHosts.
    /// </summary>
    MAC: string;
    //** @abstract(What was found.)
    /// <summary>What was found.</summary>
    Status: TTapoScanStatus;
    //** @abstract(The device, owned by the client, when Status is tssAdded or tssKnown; otherwise
    //** nil.)
    /// <summary>The device, owned by the client, when Status is tssAdded or tssKnown; otherwise nil.</summary>
    Device: TTapoDevice;
    //** @abstract(The model the device reported, when Status is tssAdded or tssUnsupported.)
    /// <summary>The model the device reported, when Status is tssAdded or tssUnsupported.</summary>
    Model: string;
    //** @abstract(The device type the device reported, for example 'SMART.TAPOPLUG'.)
    /// <summary>The device type the device reported, for example 'SMART.TAPOPLUG'.</summary>
    DeviceType: string;
    //** @abstract(The name given in the Tapo app.)
    /// <summary>The name given in the Tapo app.</summary>
    Nickname: string;
    //** @abstract(The device's own ID, when Status is tssAdded; stable across address changes.)
    /// <summary>The device's own ID, when Status is tssAdded; stable across address changes.</summary>
    DeviceId: string;
    //** @abstract(Why the address was not added; empty for tssAdded and tssKnown.)
    /// <summary>Why the address was not added; empty for tssAdded and tssKnown.</summary>
    Error: string;
    //** @abstract(True if the address holds a usable Tapo device @(tssAdded or tssKnown@).)
    //**
    //** @returns(True when @link(Device) is set.)
    /// <summary>True if the address holds a usable Tapo device (tssAdded or tssKnown).</summary>
    /// <returns>True when <see cref="Device"/> is set.</returns>
    function IsTapo: Boolean;
  end;

  //** @abstract(The result of a scan: one entry per candidate, in address order.)
  /// <summary>The result of a scan: one entry per candidate, in address order.</summary>
  TTapoScanResult = TArray<TTapoScanEntry>;

  //** @abstract(The stage a progress report is about.)
  /// <summary>The stage a progress report is about.</summary>
  TTapoScanStage = (
    //** @abstract(Finding hosts and their MAC addresses @(NetMacScan@).)
    /// <summary>Finding hosts and their MAC addresses (NetMacScan).</summary>
    tsgArp,
    //** @abstract(Only when the ARP table cannot be read: finding hosts that accept a TCP connection
    //** on port 80 or 443.)
    /// <summary>
    ///   Only when the ARP table cannot be read: finding hosts that accept a
    ///   TCP connection on port 80 or 443.
    /// </summary>
    tsgSweep,
    //** @abstract(Checking each candidate for a Tapo device.)
    /// <summary>Checking each candidate for a Tapo device.</summary>
    tsgProbe);

  //** @abstract(Progress of a scan. Always called on the main @(UI@) thread.)
  //**
  //** Each stage starts with ADone = 0 and ends with ADone = ATotal, so a progress bar can take its
  //** Max from the first call of each stage.
  //**
  //** @param(Sender The scanner.)
  //**
  //** @param(AStage The stage being reported.)
  //**
  //** @param(ADone tsgArp and tsgSweep: addresses checked so far. tsgProbe: candidates checked so
  //** far.)
  //**
  //** @param(ATotal tsgArp and tsgSweep: addresses in the subnet. tsgProbe: candidates from the ARP
  //** stage or the sweep.)
  //**
  //** @param(AFound tsgArp and tsgSweep: candidates found so far. tsgProbe: Tapo devices found so
  //** far.)
  /// <summary>Progress of a scan. Always called on the main (UI) thread.</summary>
  /// <param name="Sender">The scanner.</param>
  /// <param name="AStage">The stage being reported.</param>
  /// <param name="ADone">
  ///   tsgArp and tsgSweep: addresses checked so far. tsgProbe: candidates checked so far.
  /// </param>
  /// <param name="ATotal">
  ///   tsgArp and tsgSweep: addresses in the subnet. tsgProbe: candidates from the ARP stage or the sweep.
  /// </param>
  /// <param name="AFound">
  ///   tsgArp and tsgSweep: candidates found so far. tsgProbe: Tapo devices found so far.
  /// </param>
  /// <remarks>
  ///   Each stage starts with ADone = 0 and ends with ADone = ATotal, so a
  ///   progress bar can take its Max from the first call of each stage.
  /// </remarks>
  TTapoScanProgressEvent = procedure(Sender: TObject; AStage: TTapoScanStage;
    ADone, ATotal, AFound: Integer) of object;

  //** @abstract(A Tapo device was found. Always called on the main @(UI@) thread.)
  //**
  //** @param(Sender The scanner.)
  //**
  //** @param(AEntry The device's entry; Status is tssAdded or tssKnown.)
  /// <summary>A Tapo device was found. Always called on the main (UI) thread.</summary>
  /// <param name="Sender">The scanner.</param>
  /// <param name="AEntry">The device's entry; Status is tssAdded or tssKnown.</param>
  TTapoScanDeviceEvent = procedure(Sender: TObject; const AEntry: TTapoScanEntry) of object;

  //** @abstract(Called on the main @(UI@) thread when an asynchronous scan ends.)
  //**
  //** @param(AResult The entries; partial if the scan was cancelled.)
  //**
  //** @param(AError Empty on success; otherwise why the scan stopped.)
  /// <summary>Called on the main (UI) thread when an asynchronous scan ends.</summary>
  /// <param name="AResult">The entries; partial if the scan was cancelled.</param>
  /// <param name="AError">Empty on success; otherwise why the scan stopped.</param>
  TTapoScanCompleteProc = reference to procedure(const AResult: TTapoScanResult;
    const AError: string);

  //** @abstract(Internal: shared between a scanner and the work it started.)
  //**
  //** Queued callbacks hold this, not the scanner, so a scanner freed while a scan is under way is
  //** never called back.
  /// <summary>Internal: shared between a scanner and the work it started.</summary>
  /// <remarks>
  ///   Queued callbacks hold this, not the scanner, so a scanner freed while a
  ///   scan is under way is never called back.
  /// </remarks>
  ITapoScanState = interface
    ['{BE24AA16-F637-4D83-9114-8FC8DC3D5739}']
    //** @abstract(The scanner, valid only while @link(Alive) is True.)
    //**
    //** @returns(The scanner.)
    /// <summary>The scanner, valid only while <see cref="Alive"/> is True.</summary>
    /// <returns>The scanner.</returns>
    function Owner: TTapoScanner;
    //** @abstract(False once the scanner has been freed.)
    //**
    //** @returns(True while the scanner exists.)
    /// <summary>False once the scanner has been freed.</summary>
    /// <returns>True while the scanner exists.</returns>
    function Alive: Boolean;
    //** @abstract(True once the scan has been cancelled.)
    //**
    //** @returns(True after @link(Cancel).)
    /// <summary>True once the scan has been cancelled.</summary>
    /// <returns>True after <see cref="Cancel"/>.</returns>
    function Cancelled: Boolean;
    //** @abstract(Asks the scan to stop.)
    /// <summary>Asks the scan to stop.</summary>
    procedure Cancel;
    //** @abstract(Marks the scanner as freed.)
    /// <summary>Marks the scanner as freed.</summary>
    procedure Kill;
  end;

  //** @abstract(Finds Tapo devices on the local network and adds them to a @link(TTapoClient).)
  //**
  //** Nothing happens until @link(ScanAsync) or @link(Scan) is called. Devices found are added to
  //** the client and stay there, so the scan is needed only when devices are first set up or when
  //** one has been added to the network.
  //**
  //** Addresses the client already has are reported as tssKnown and not probed again, so rescanning
  //** is cheap for devices already found.
  //**
  //** One scan at a time per scanner. The scanner must be freed on the main thread; freeing it waits
  //** for a probe stage under way to stop.
  //**
  //** Example:
  //** @longCode(#
  //** FScanner := TTapoScanner.Create(FClient);
  //** FScanner.OnProgress := ScanProgress;
  //** FScanner.ScanAsync('192.168.1.0', '255.255.255.0',
  //**   procedure(const R: TTapoScanResult; const Err: string)
  //**   var
  //**     E: TTapoScanEntry;
  //**   begin
  //**     for E in R do
  //**       if E.IsTapo then
  //**         Memo1.Lines.Add(E.IP + '  ' + E.Device.ClassName + '  ' + E.Nickname);
  //**   end);
  //** #)
  /// <summary>
  ///   Finds Tapo devices on the local network and adds them to a
  ///   <see cref="Tapo.Client|TTapoClient"/>.
  /// </summary>
  /// <remarks>
  ///   <para>
  ///     Nothing happens until <see cref="ScanAsync"/> or <see cref="Scan"/>
  ///     is called. Devices found are added to the client and stay there, so
  ///     the scan is needed only when devices are first set up or when one
  ///     has been added to the network.
  ///   </para>
  ///   <para>
  ///     Addresses the client already has are reported as tssKnown and not
  ///     probed again, so rescanning is cheap for devices already found.
  ///   </para>
  ///   <para>
  ///     One scan at a time per scanner. The scanner must be freed on the
  ///     main thread; freeing it waits for a probe stage under way to stop.
  ///   </para>
  /// </remarks>
  /// <example>
  ///   <code>
  ///   FScanner := TTapoScanner.Create(FClient);
  ///   FScanner.OnProgress := ScanProgress;
  ///   FScanner.ScanAsync('192.168.1.0', '255.255.255.0',
  ///     procedure(const R: TTapoScanResult; const Err: string)
  ///     var
  ///       E: TTapoScanEntry;
  ///     begin
  ///       for E in R do
  ///         if E.IsTapo then
  ///           Memo1.Lines.Add(E.IP + '  ' + E.Device.ClassName + '  ' + E.Nickname);
  ///     end);
  ///   </code>
  /// </example>
  TTapoScanner = class
  private
    FClient: TTapoClient;
    FLock: TCriticalSection;
    FState: ITapoScanState;      // the work under way, or nil
    FTask: ITask;                // the probe stage of an asynchronous scan
    FBusy: Integer;              // 1 while a scan runs (interlocked)
    FLastResult: TTapoScanResult;
    FTpLinkOnly: Boolean;
    FTcpSweepFallback: Boolean;
    FSweepTimeout: Integer;
    FLastArpError: string;
    FMaxParallel: Integer;
    FProbeConnectionTimeout: Integer;
    FProbeResponseTimeout: Integer;
    FRetryConnectionTimeout: Integer;
    FOnProgress: TTapoScanProgressEvent;
    FOnDeviceFound: TTapoScanDeviceEvent;
    function GetBusy: Boolean;
    function GetLastResult: TTapoScanResult;
    procedure SetLastResult(const AResult: TTapoScanResult);
    function BeginWork: ITapoScanState;
    procedure EndWork(const AState: ITapoScanState);
    function ArpScan(const ANetwork, ASubnet: string): TMacEntries;
    function TcpSweep(const ANetwork, ASubnet: string; const AState: ITapoScanState): TMacEntries;
    procedure StartSweepStage(const ANetwork, ASubnet: string; const AState: ITapoScanState;
      const AOnComplete: TTapoScanCompleteProc);
    function GetLastArpError: string;
    procedure SetLastArpError(const AError: string);
    function ProbeAll(const ACandidates: TMacEntries; const AState: ITapoScanState): TTapoScanResult;
    procedure ProbeOne(AProbe: TTapoClient; var AEntry: TTapoScanEntry);
    procedure StartProbeStage(const ACandidates: TMacEntries; const AState: ITapoScanState;
      const AOnComplete: TTapoScanCompleteProc);
    procedure FinishAsync(const AState: ITapoScanState; const AResult: TTapoScanResult;
      const AError: string; const AOnComplete: TTapoScanCompleteProc);
  public
    //** @abstract(Creates a scanner that adds the devices it finds to AClient.)
    //**
    //** @param(AClient The client; it must outlive the scanner.)
    //**
    //** @raises(ETapoError AClient is nil.)
    /// <summary>Creates a scanner that adds the devices it finds to AClient.</summary>
    /// <param name="AClient">The client; it must outlive the scanner.</param>
    /// <exception cref="Tapo.Client|ETapoError">AClient is nil.</exception>
    constructor Create(AClient: TTapoClient);
    //** @abstract(Cancels a scan under way and waits for its probe stage to stop.)
    //**
    //** Devices already added stay in the client. No callback runs after the scanner has been freed.
    /// <summary>Cancels a scan under way and waits for its probe stage to stop.</summary>
    /// <remarks>
    ///   Devices already added stay in the client. No callback runs after
    ///   the scanner has been freed.
    /// </remarks>
    destructor Destroy; override;

    //** @abstract(True on platforms where the ARP stage can run @(Windows, macOS, Linux@).)
    //**
    //** @returns(False on Android and iOS, where only CheckHosts and CheckCandidates work.)
    /// <summary>True on platforms where the ARP stage can run (Windows, macOS, Linux).</summary>
    /// <returns>False on Android and iOS, where only CheckHosts and CheckCandidates work.</returns>
    class function Supported: Boolean;

    //** @abstract(Scans a subnet in the background and adds the Tapo devices found to the client.)
    //**
    //** Call it from the main thread. Progress, OnDeviceFound and AOnComplete all run on the main
    //** thread. Errors (a bad subnet, an unsupported platform) arrive in AOnComplete's AError.
    //**
    //** @link(LastResult) is set before AOnComplete is called.
    //**
    //** @param(ANetwork Any address in the network, for example '192.168.1.0'.)
    //**
    //** @param(ASubnet The mask: '255.255.255.0', '/24' or '24'.)
    //**
    //** @param(AOnComplete Optional; called on the main thread when the scan ends.)
    //**
    //** @raises(ETapoError A scan is already running.)
    //**
    //** @seealso(Scan)
    //**
    //** @seealso(Cancel)
    /// <summary>Scans a subnet in the background and adds the Tapo devices found to the client.</summary>
    /// <param name="ANetwork">Any address in the network, for example '192.168.1.0'.</param>
    /// <param name="ASubnet">The mask: '255.255.255.0', '/24' or '24'.</param>
    /// <param name="AOnComplete">Optional; called on the main thread when the scan ends.</param>
    /// <exception cref="Tapo.Client|ETapoError">A scan is already running.</exception>
    /// <remarks>
    ///   <para>
    ///     Call it from the main thread. Progress, OnDeviceFound and
    ///     AOnComplete all run on the main thread. Errors (a bad subnet, an
    ///     unsupported platform) arrive in AOnComplete's AError.
    ///   </para>
    ///   <para>
    ///     <see cref="LastResult"/> is set before AOnComplete is called.
    ///   </para>
    /// </remarks>
    /// <seealso cref="Scan"/>
    /// <seealso cref="Cancel"/>
    procedure ScanAsync(const ANetwork, ASubnet: string;
      const AOnComplete: TTapoScanCompleteProc = nil);

    //** @abstract(Scans a subnet and waits for the result. Do not call it on the main thread.)
    //**
    //** The events are still queued to the main thread. The ARP stage is reported only at its start
    //** and end; ScanAsync reports it as it goes.
    //**
    //** @param(ANetwork Any address in the network, for example '192.168.1.0'.)
    //**
    //** @param(ASubnet The mask: '255.255.255.0', '/24' or '24'.)
    //**
    //** @returns(One entry per candidate. Also stored in @link(LastResult).)
    //**
    //** @raises(ETapoError A scan is already running.)
    //**
    //** @raises(EArgumentException ANetwork or ASubnet is not valid.)
    //**
    //** @raises(ENotSupportedException The platform cannot read the ARP table.)
    /// <summary>Scans a subnet and waits for the result. Do not call it on the main thread.</summary>
    /// <param name="ANetwork">Any address in the network, for example '192.168.1.0'.</param>
    /// <param name="ASubnet">The mask: '255.255.255.0', '/24' or '24'.</param>
    /// <returns>One entry per candidate. Also stored in <see cref="LastResult"/>.</returns>
    /// <exception cref="Tapo.Client|ETapoError">A scan is already running.</exception>
    /// <exception cref="EArgumentException">ANetwork or ASubnet is not valid.</exception>
    /// <exception cref="ENotSupportedException">The platform cannot read the ARP table.</exception>
    /// <remarks>
    ///   The events are still queued to the main thread. The ARP stage is
    ///   reported only at its start and end; ScanAsync reports it as it goes.
    /// </remarks>
    function Scan(const ANetwork, ASubnet: string): TTapoScanResult;

    //** @abstract(Probes a list of candidates found by other means, in the background.)
    //**
    //** Only the probe stage runs, so it works on every platform.
    //**
    //** @param(ACandidates Addresses @(and MACs@) to check, for example from NetMacScan.)
    //**
    //** @param(AOnComplete Optional; called on the main thread when the checks end.)
    //**
    //** @raises(ETapoError A scan is already running.)
    /// <summary>Probes a list of candidates found by other means, in the background.</summary>
    /// <param name="ACandidates">Addresses (and MACs) to check, for example from NetMacScan.</param>
    /// <param name="AOnComplete">Optional; called on the main thread when the checks end.</param>
    /// <exception cref="Tapo.Client|ETapoError">A scan is already running.</exception>
    /// <remarks>Only the probe stage runs, so it works on every platform.</remarks>
    procedure CheckCandidatesAsync(const ACandidates: TMacEntries;
      const AOnComplete: TTapoScanCompleteProc = nil);

    //** @abstract(Probes a list of candidates and waits for the result. Do not call it on the main
    //** thread.)
    //**
    //** @param(ACandidates Addresses @(and MACs@) to check.)
    //**
    //** @returns(One entry per candidate. Also stored in @link(LastResult).)
    //**
    //** @raises(ETapoError A scan is already running.)
    /// <summary>Probes a list of candidates and waits for the result. Do not call it on the main thread.</summary>
    /// <param name="ACandidates">Addresses (and MACs) to check.</param>
    /// <returns>One entry per candidate. Also stored in <see cref="LastResult"/>.</returns>
    /// <exception cref="Tapo.Client|ETapoError">A scan is already running.</exception>
    function CheckCandidates(const ACandidates: TMacEntries): TTapoScanResult;

    //** @abstract(Probes a list of addresses and waits for the result. Do not call it on the main
    //** thread.)
    //**
    //** @param(AHosts IP addresses or host names to check.)
    //**
    //** @returns(One entry per address. Also stored in @link(LastResult).)
    //**
    //** @raises(ETapoError A scan is already running.)
    //**
    //** Example:
    //** @longCode(#
    //** R := Scanner.CheckHosts(['192.168.1.50', '192.168.1.51']);
    //** #)
    /// <summary>Probes a list of addresses and waits for the result. Do not call it on the main thread.</summary>
    /// <param name="AHosts">IP addresses or host names to check.</param>
    /// <returns>One entry per address. Also stored in <see cref="LastResult"/>.</returns>
    /// <exception cref="Tapo.Client|ETapoError">A scan is already running.</exception>
    /// <example>
    ///   <code>
    ///   R := Scanner.CheckHosts(['192.168.1.50', '192.168.1.51']);
    ///   </code>
    /// </example>
    function CheckHosts(const AHosts: array of string): TTapoScanResult;

    //** @abstract(Asks the scan under way to stop.)
    //**
    //** The ARP stage cannot be interrupted, so a scan cancelled during it stops when that stage
    //** ends, before any probing. During the probe stage, logins already started finish and the rest
    //** are skipped (tssCancelled). The scan then ends with AError 'Scan cancelled'.
    /// <summary>Asks the scan under way to stop.</summary>
    /// <remarks>
    ///   The ARP stage cannot be interrupted, so a scan cancelled during it
    ///   stops when that stage ends, before any probing. During the probe
    ///   stage, logins already started finish and the rest are skipped
    ///   (tssCancelled). The scan then ends with AError 'Scan cancelled'.
    /// </remarks>
    procedure Cancel;

    //** @abstract(The Tapo devices in @link(LastResult) @(tssAdded and tssKnown@).)
    //**
    //** A device freed since the scan is still listed until the next scan. @code(Client.Devices[])
    //** always reflects the current set.
    //**
    //** @returns(The devices, owned by the client, in address order.)
    /// <summary>The Tapo devices in <see cref="LastResult"/> (tssAdded and tssKnown).</summary>
    /// <returns>The devices, owned by the client, in address order.</returns>
    /// <remarks>
    ///   A device freed since the scan is still listed until the next scan.
    ///   <c>Client.Devices[]</c> always reflects the current set.
    /// </remarks>
    function Devices: TArray<TTapoDevice>;

    //** @abstract(The client devices are added to.)
    /// <summary>The client devices are added to.</summary>
    property Client: TTapoClient read FClient;
    //** @abstract(True while a scan runs.)
    /// <summary>True while a scan runs.</summary>
    property Busy: Boolean read GetBusy;
    //** @abstract(The entries of the last scan that reached the probe stage, including one cancelled
    //** during probing. Empty until then.)
    /// <summary>
    ///   The entries of the last scan that reached the probe stage, including
    ///   one cancelled during probing. Empty until then.
    /// </summary>
    property LastResult: TTapoScanResult read GetLastResult;
    //** @abstract(True @(the default@) keeps only TP-Link MAC prefixes after the ARP stage. False
    //** probes every host found, which is slower but also finds a device with a MAC prefix missing
    //** from NetMacScan's table.)
    /// <summary>
    ///   True (the default) keeps only TP-Link MAC prefixes after the ARP
    ///   stage. False probes every host found, which is slower but also
    ///   finds a device with a MAC prefix missing from NetMacScan's table.
    /// </summary>
    property TpLinkOnly: Boolean read FTpLinkOnly write FTpLinkOnly;
    //** @abstract(True @(the default@): when the ARP table cannot be read, find candidates by trying
    //** TCP ports 80 and 443 on every address instead. Slower, and candidates then have no MAC, but
    //** every one is still checked by logging in.)
    //**
    //** macOS can hide the ARP table from an app even when it may use the local network. The reason
    //** the ARP stage failed is in @link(LastArpError).
    /// <summary>
    ///   True (the default): when the ARP table cannot be read, find
    ///   candidates by trying TCP ports 80 and 443 on every address instead.
    ///   Slower, and candidates then have no MAC, but every one is still
    ///   checked by logging in.
    /// </summary>
    /// <remarks>
    ///   macOS can hide the ARP table from an app even when it may use the
    ///   local network. The reason the ARP stage failed is in <see cref="LastArpError"/>.
    /// </remarks>
    property TcpSweepFallback: Boolean read FTcpSweepFallback write FTcpSweepFallback;
    //** @abstract(How long the TCP sweep waits for each connection, in ms; the default is 1500.)
    /// <summary>How long the TCP sweep waits for each connection, in ms; the default is 1500.</summary>
    property SweepTimeout: Integer read FSweepTimeout write FSweepTimeout;
    //** @abstract(Why the ARP stage of the last scan failed, when the TCP sweep was used instead;
    //** empty when the ARP stage worked.)
    /// <summary>
    ///   Why the ARP stage of the last scan failed, when the TCP sweep was
    ///   used instead; empty when the ARP stage worked.
    /// </summary>
    property LastArpError: string read GetLastArpError;
    //** @abstract(How many candidates are probed at once, 1 to 32. The default is 8.)
    /// <summary>How many candidates are probed at once, 1 to 32. The default is 8.</summary>
    property MaxParallel: Integer read FMaxParallel write FMaxParallel;
    //** @abstract(The connection timeout while probing, in ms; the default is 2000. Only the probes
    //** use it: devices added keep the client's own timeouts.)
    /// <summary>
    ///   The connection timeout while probing, in ms; the default is 2000. Only
    ///   the probes use it: devices added keep the client's own timeouts.
    /// </summary>
    property ProbeConnectionTimeout: Integer read FProbeConnectionTimeout write FProbeConnectionTimeout;
    //** @abstract(The response timeout while probing, in ms; the default is 8000. A TPAP login on a
    //** bulb can take a few seconds, so do not set it too low.)
    /// <summary>
    ///   The response timeout while probing, in ms; the default is 8000. A
    ///   TPAP login on a bulb can take a few seconds, so do not set it too low.
    /// </summary>
    property ProbeResponseTimeout: Integer read FProbeResponseTimeout write FProbeResponseTimeout;
    //** @abstract(The connection timeout, in ms, of one more try for each candidate that gave no
    //** response at first; the default is 6000. 0 turns the retry off.)
    //**
    //** Wi-Fi bulbs in power save can answer the ARP stage and still miss the short
    //** @link(ProbeConnectionTimeout). The retry runs after all candidates have had their first try,
    //** so it costs time only when something did not answer.
    /// <summary>
    ///   The connection timeout, in ms, of one more try for each candidate
    ///   that gave no response at first; the default is 6000. 0 turns the
    ///   retry off.
    /// </summary>
    /// <remarks>
    ///   Wi-Fi bulbs in power save can answer the ARP stage and still miss
    ///   the short <see cref="ProbeConnectionTimeout"/>. The retry runs after
    ///   all candidates have had their first try, so it costs time only when
    ///   something did not answer.
    /// </remarks>
    property RetryConnectionTimeout: Integer read FRetryConnectionTimeout write FRetryConnectionTimeout;
    //** @abstract(Progress of both stages, on the main thread.)
    /// <summary>Progress of both stages, on the main thread.</summary>
    property OnProgress: TTapoScanProgressEvent read FOnProgress write FOnProgress;
    //** @abstract(Called on the main thread for each Tapo device as soon as it is found.)
    /// <summary>Called on the main thread for each Tapo device as soon as it is found.</summary>
    property OnDeviceFound: TTapoScanDeviceEvent read FOnDeviceFound write FOnDeviceFound;
  end;

//** @abstract(A short English description of a scan status, for logs and lists.)
//**
//** @param(AStatus The status.)
//**
//** @returns(For example 'added' or 'no response'.)
/// <summary>A short English description of a scan status, for logs and lists.</summary>
/// <param name="AStatus">The status.</param>
/// <returns>For example 'added' or 'no response'.</returns>
function TapoScanStatusName(AStatus: TTapoScanStatus): string;

implementation

uses
  IdTCPClient, IdExceptionCore, IdStack, IdStackConsts;

const
  SScanCancelled = 'Scan cancelled';
  TPAP_LOCKOUT = -2101;

type
  TTapoScanState = class(TInterfacedObject, ITapoScanState)
  private
    FOwner: TTapoScanner;
    FAlive: Boolean;
    FCancelled: Boolean;
  public
    constructor Create(AOwner: TTapoScanner);
    function Owner: TTapoScanner;
    function Alive: Boolean;
    function Cancelled: Boolean;
    procedure Cancel;
    procedure Kill;
  end;

  // Receives NetMacScan's progress events (which need a method of an object)
  // and passes them on while the scanner exists. Freed by the completion
  // callback, which NetMacScan queues after the last progress event.
  TArpRelay = class
  private
    FState: ITapoScanState;
  public
    constructor Create(const AState: ITapoScanState);
    procedure Progress(Sender: TObject; Processed, Found, Total: Integer);
  end;

function TapoScanStatusName(AStatus: TTapoScanStatus): string;
begin
  case AStatus of
    tssAdded:       Result := 'added';
    tssKnown:       Result := 'already added';
    tssNoResponse:  Result := 'no response';
    tssRejected:    Result := 'not a Tapo device these credentials open';
    tssBadCredentials: Result := 'Tapo device that rejected the e-mail or password';
    tssUnsupported: Result := 'unsupported Tapo model';
    tssLockedOut:   Result := 'Tapo device refusing logins for now (too many failed attempts)';
    tssCancelled:   Result := 'not checked (cancelled)';
  else
    Result := '?';
  end;
end;

{ TTapoScanEntry }

function TTapoScanEntry.IsTapo: Boolean;
begin
  Result := (Status in [tssAdded, tssKnown]) and (Device <> nil);
end;

{ TTapoScanState }

constructor TTapoScanState.Create(AOwner: TTapoScanner);
begin
  inherited Create;
  FOwner := AOwner;
  FAlive := True;
end;

function TTapoScanState.Owner: TTapoScanner;
begin
  Result := FOwner;
end;

function TTapoScanState.Alive: Boolean;
begin
  Result := FAlive;
end;

function TTapoScanState.Cancelled: Boolean;
begin
  Result := FCancelled;
end;

procedure TTapoScanState.Cancel;
begin
  FCancelled := True;
end;

procedure TTapoScanState.Kill;
begin
  FCancelled := True;
  FAlive := False;
end;

{ TArpRelay }

constructor TArpRelay.Create(const AState: ITapoScanState);
begin
  inherited Create;
  FState := AState;
end;

procedure TArpRelay.Progress(Sender: TObject; Processed, Found, Total: Integer);
var
  Owner: TTapoScanner;
begin
  // NetMacScan calls this on the main thread
  if not FState.Alive then
    Exit;
  Owner := FState.Owner;
  if Assigned(Owner.FOnProgress) then
    Owner.FOnProgress(Owner, tsgArp, Processed, Total, Found);
end;

{ Queued notifications. Separate routines, so each queued call keeps its own
  copy of the values. They run on the main thread, where the scanner is also
  freed, so checking Alive there is enough. }

{ Every anonymous method is assigned to a typed variable before it is passed
  on, so TThread.Queue / TTask.Run / TParallel.For have no overload to work
  out from an inline anonymous method (dccosxarm64 rejects some of those). }

procedure QueueProgress(const AState: ITapoScanState; AStage: TTapoScanStage;
  ADone, ATotal, AFound: Integer);
var
  Proc: TThreadProcedure;
begin
  Proc :=
    procedure
    var
      Owner: TTapoScanner;
    begin
      if not AState.Alive then
        Exit;
      Owner := AState.Owner;
      if Assigned(Owner.FOnProgress) then
        Owner.FOnProgress(Owner, AStage, ADone, ATotal, AFound);
    end;
  TThread.Queue(nil, Proc);
end;

procedure QueueDeviceFound(const AState: ITapoScanState; const AEntry: TTapoScanEntry);
var
  Proc: TThreadProcedure;
begin
  Proc :=
    procedure
    var
      Owner: TTapoScanner;
    begin
      if not AState.Alive then
        Exit;
      Owner := AState.Owner;
      if Assigned(Owner.FOnDeviceFound) then
        Owner.FOnDeviceFound(Owner, AEntry);
    end;
  TThread.Queue(nil, Proc);
end;

procedure QueueFinish(const AState: ITapoScanState; const AResult: TTapoScanResult;
  const AError: string; const AOnComplete: TTapoScanCompleteProc);
var
  Proc: TThreadProcedure;
begin
  Proc :=
    procedure
    begin
      if AState.Alive then
        AState.Owner.FinishAsync(AState, AResult, AError, AOnComplete);
    end;
  TThread.Queue(nil, Proc);
end;

{ TCP sweep, used when the ARP table cannot be read }

type
  TPortResult = (prOpen, prRefused, prTimeout, prUnreachable, prOther);

function TryConnect(const AHost: string; APort, ATimeout: Integer): TPortResult;
var
  C: TIdTCPClient;
  Code: Integer;
begin
  C := TIdTCPClient.Create(nil);
  try
    C.Host := AHost;
    C.Port := APort;
    C.ConnectTimeout := ATimeout;
    try
      C.Connect;
      Result := prOpen;
      try
        C.Disconnect;
      except
        // the connection was what mattered
      end;
    except
      on E: EIdConnectTimeout do
        Result := prTimeout;
      on E: EIdSocketError do
      begin
        Code := E.LastError;
        if Code = Id_WSAECONNREFUSED then
          Result := prRefused             // something is there, port closed
        else if (Code = Id_WSAEHOSTUNREACH) or (Code = Id_WSAENETUNREACH) then
          Result := prUnreachable
        else
          Result := prOther;              // includes host down / timed out
      end;
      on E: Exception do
        Result := prOther;
    end;
  finally
    C.Free;
  end;
end;

{ TTapoScanner }

constructor TTapoScanner.Create(AClient: TTapoClient);
begin
  inherited Create;
  if AClient = nil then
    raise ETapoError.Create('A TTapoClient is required');
  FClient := AClient;
  FLock := TCriticalSection.Create;
  FTpLinkOnly := True;
  FTcpSweepFallback := True;
  FSweepTimeout := 1500;
  FMaxParallel := 8;
  FProbeConnectionTimeout := 2000;
  FProbeResponseTimeout := 8000;
  FRetryConnectionTimeout := 6000;
end;

destructor TTapoScanner.Destroy;
var
  Task: ITask;
begin
  FLock.Enter;
  try
    if FState <> nil then
      FState.Kill;
    FState := nil;
  finally
    FLock.Leave;
  end;
  // the probe stage uses this scanner and the client: let it stop first
  Task := FTask;
  FTask := nil;
  if Task <> nil then
    try
      Task.Wait;
    except
      // its errors were for the callback, which will not run now
    end;
  FLock.Free;
  inherited;
end;

class function TTapoScanner.Supported: Boolean;
begin
  Result := MacScanSupported;
end;

function TTapoScanner.GetBusy: Boolean;
begin
  Result := TInterlocked.CompareExchange(FBusy, 0, 0) <> 0;
end;

function TTapoScanner.GetLastResult: TTapoScanResult;
begin
  FLock.Enter;
  try
    Result := Copy(FLastResult);
  finally
    FLock.Leave;
  end;
end;

procedure TTapoScanner.SetLastResult(const AResult: TTapoScanResult);
begin
  FLock.Enter;
  try
    FLastResult := Copy(AResult);
  finally
    FLock.Leave;
  end;
end;

function TTapoScanner.BeginWork: ITapoScanState;
begin
  if TInterlocked.CompareExchange(FBusy, 1, 0) <> 0 then
    raise ETapoError.CreateCode(-1, 'A scan is already running');
  Result := TTapoScanState.Create(Self);
  FLock.Enter;
  try
    FState := Result;
  finally
    FLock.Leave;
  end;
end;

procedure TTapoScanner.EndWork(const AState: ITapoScanState);
begin
  FLock.Enter;
  try
    if FState = AState then
      FState := nil;
  finally
    FLock.Leave;
  end;
  TInterlocked.Exchange(FBusy, 0);
end;

procedure TTapoScanner.Cancel;
begin
  FLock.Enter;
  try
    if FState <> nil then
      FState.Cancel;
  finally
    FLock.Leave;
  end;
end;

function TTapoScanner.Devices: TArray<TTapoDevice>;
var
  R: TTapoScanResult;
  I, N: Integer;
begin
  R := GetLastResult;
  SetLength(Result, Length(R));
  N := 0;
  for I := 0 to High(R) do
    if R[I].IsTapo then
    begin
      Result[N] := R[I].Device;
      Inc(N);
    end;
  SetLength(Result, N);
end;

function TTapoScanner.GetLastArpError: string;
begin
  FLock.Enter;
  try
    Result := FLastArpError;
  finally
    FLock.Leave;
  end;
end;

procedure TTapoScanner.SetLastArpError(const AError: string);
begin
  FLock.Enter;
  try
    FLastArpError := AError;
  finally
    FLock.Leave;
  end;
end;

// Finds hosts with TCP port 80 (plugs, lights, hubs) or 443 (cameras) open.
// Runs on a background thread.
function TTapoScanner.TcpSweep(const ANetwork, ASubnet: string;
  const AState: ITapoScanState): TMacEntries;
var
  Hosts: TArray<string>;
  Hits: TArray<Boolean>;
  Total, Done, Found, Unreachable, Workers, Timeout, I, N: Integer;
  Pool: TThreadPool;
  Body: TProc<Integer>;
begin
  Hosts := SubnetHosts(ANetwork, ASubnet);
  Total := Length(Hosts);
  SetLength(Hits, Total);
  Done := 0;
  Found := 0;
  Unreachable := 0;
  Timeout := Max(200, FSweepTimeout);
  QueueProgress(AState, tsgSweep, 0, Total, 0);

  if Total > 0 then
  begin
    Workers := 32;
    Pool := TThreadPool.Create;
    try
      Pool.SetMinWorkerThreads(Workers);
      Pool.SetMaxWorkerThreads(Workers);
      Pool.SetMinWorkerThreads(Workers);
      Body :=
        procedure(Idx: Integer)
        var
          R: TPortResult;
          D, F: Integer;
        begin
          if not AState.Cancelled then
          begin
            R := TryConnect(Hosts[Idx], 80, Timeout);
            if R = prRefused then          // a host, but not on 80: a camera?
              R := TryConnect(Hosts[Idx], 443, Timeout);
            if R = prOpen then
            begin
              Hits[Idx] := True;
              TInterlocked.Increment(Found);
            end
            else if R = prUnreachable then
              TInterlocked.Increment(Unreachable);
          end;
          F := TInterlocked.CompareExchange(Found, 0, 0);
          D := TInterlocked.Increment(Done);
          QueueProgress(AState, tsgSweep, D, Total, F);
        end;
      TParallel.For(0, Total - 1, Body, Pool);
    finally
      Pool.Free;
    end;
  end;

  // Nearly every address failing at once with "no route to host" is what an
  // app sees when the OS blocks it from the local network.
  if (Total > 0) and (Found = 0) and (Unreachable * 10 >= Total * 9) then
    raise ETapoError.CreateCode(-1, 'Every address on the network failed with "no ' +
      'route to host": the operating system is blocking this app from the local ' +
      'network. On macOS, allow it in System Settings > Privacy & Security > ' +
      'Local Network (sign the app with an Apple certificate so the setting sticks).');

  SetLength(Result, Total);
  N := 0;
  for I := 0 to Total - 1 do
    if Hits[I] then
    begin
      Result[N].IP := Hosts[I];
      Result[N].MAC := '';
      Inc(N);
    end;
  SetLength(Result, N);
end;

function TTapoScanner.ArpScan(const ANetwork, ASubnet: string): TMacEntries;
begin
  if FTpLinkOnly then
    Result := ScanTapoDevices(ANetwork, ASubnet)
  else
    Result := ScanNetworkMacs(ANetwork, ASubnet);
end;

// Runs on a pool thread, one call per candidate; each call owns its entry.
procedure TTapoScanner.ProbeOne(AProbe: TTapoClient; var AEntry: TTapoScanEntry);
var
  Existing, Found, Dev: TTapoDevice;
  Detection: TTapoDetection;
begin
  Existing := FClient.Find(AEntry.IP);
  if Existing <> nil then
  begin
    AEntry.Status := tssKnown;
    AEntry.Device := Existing;
    Exit;
  end;

  try
    // log in on the probe client, with its short timeouts ...
    Found := AProbe.AddDetected(AEntry.IP, Detection);
    try
      AEntry.Model := Detection.Model;
      AEntry.DeviceType := Detection.DeviceType;
      AEntry.Nickname := Detection.Nickname;
      AEntry.DeviceId := Detection.Info.DeviceId;
      // a TCP-sweep candidate has no MAC: take the one the device reports
      // ('0C-EF-15-6C-6E-31'), in the ARP stage's form
      if AEntry.MAC = '' then
        AEntry.MAC := UpperCase(StringReplace(Detection.Info.Mac, '-', ':', [rfReplaceAll]));
      // ... then add the device to the real client and hand it the login
      Dev := FClient.AddDevice(Detection.DeviceClass, AEntry.IP);
      Dev.TakeSession(Found);
      AEntry.Device := Dev;
      AEntry.Status := tssAdded;
    finally
      Found.Free;
    end;
  except
    on E: ETapoNoResponse do
    begin
      AEntry.Status := tssNoResponse;
      AEntry.Error := E.Message;
    end;
    on E: ETapoAuthError do
    begin
      AEntry.Status := tssBadCredentials;
      AEntry.Error := E.Message;
    end;
    on E: ETapoUnsupportedModel do
    begin
      AEntry.Status := tssUnsupported;
      AEntry.Error := E.Message;
    end;
    on E: ETapoError do
    begin
      if (E is ETapoLockedError) or (E.ErrorCode = TPAP_LOCKOUT) then
        AEntry.Status := tssLockedOut
      else
        AEntry.Status := tssRejected;
      AEntry.Error := E.Message;
    end;
    on E: Exception do
    begin
      AEntry.Status := tssRejected;
      AEntry.Error := E.ClassName + ': ' + E.Message;
    end;
  end;
end;

// The probe stage. Runs on a background thread.
function TTapoScanner.ProbeAll(const ACandidates: TMacEntries;
  const AState: ITapoScanState): TTapoScanResult;
var
  Entries: TTapoScanResult;
  Probe: TTapoClient;
  Pool: TThreadPool;
  Total, Done, Found, Workers, I: Integer;
  Body, RetryBody: TProc<Integer>;
  Retry: TArray<Integer>;
  SlowProbe: TTapoClient;
begin
  Total := Length(ACandidates);
  SetLength(Entries, Total);
  for I := 0 to Total - 1 do
  begin
    Entries[I].IP := Trim(ACandidates[I].IP);
    Entries[I].MAC := ACandidates[I].MAC;
    Entries[I].Status := tssCancelled;   // until probed
  end;
  Done := 0;
  Found := 0;
  QueueProgress(AState, tsgProbe, 0, Total, 0);

  if Total > 0 then
  begin
    // a private client: short timeouts, and probes never show up in FClient
    Probe := FClient.CloneEmpty;
    try
      Probe.ConnectionTimeout := FProbeConnectionTimeout;
      Probe.ResponseTimeout := FProbeResponseTimeout;
      Workers := EnsureRange(FMaxParallel, 1, 32);
      Pool := TThreadPool.Create;
      try
        // min first (it may not exceed max), then max, then min again in case
        // the first call was refused
        Pool.SetMinWorkerThreads(Workers);
        Pool.SetMaxWorkerThreads(Workers);
        Pool.SetMinWorkerThreads(Workers);
        Body :=
          procedure(Idx: Integer)
          var
            D, F: Integer;
          begin
            if not AState.Cancelled then
            begin
              ProbeOne(Probe, Entries[Idx]);
              if Entries[Idx].IsTapo then
              begin
                TInterlocked.Increment(Found);
                QueueDeviceFound(AState, Entries[Idx]);
              end;
            end;
            F := TInterlocked.CompareExchange(Found, 0, 0);
            D := TInterlocked.Increment(Done);
            QueueProgress(AState, tsgProbe, D, Total, F);
          end;
        TParallel.For(0, Total - 1, Body, Pool);

        // Wi-Fi bulbs in power save can answer ARP yet miss a short connect
        // timeout. Give each candidate that did not answer one slower try.
        Retry := nil;
        for I := 0 to Total - 1 do
          if Entries[I].Status = tssNoResponse then
            Retry := Retry + [I];
        if (Length(Retry) > 0) and (FRetryConnectionTimeout > 0) and
           not AState.Cancelled then
        begin
          SlowProbe := FClient.CloneEmpty;
          try
            SlowProbe.ConnectionTimeout := Max(FRetryConnectionTimeout, FProbeConnectionTimeout);
            SlowProbe.ResponseTimeout := 2 * FProbeResponseTimeout;
            RetryBody :=
              procedure(K: Integer)
              var
                Idx: Integer;
              begin
                Idx := Retry[K];
                if AState.Cancelled then
                  Exit;
                Entries[Idx].Error := '';
                ProbeOne(SlowProbe, Entries[Idx]);
                if Entries[Idx].IsTapo then
                begin
                  QueueDeviceFound(AState, Entries[Idx]);
                  QueueProgress(AState, tsgProbe, Total, Total,
                    TInterlocked.Increment(Found));
                end;
              end;
            TParallel.For(0, High(Retry), RetryBody, Pool);
          finally
            SlowProbe.Free;
          end;
        end;
      finally
        Pool.Free;
      end;
    finally
      Probe.Free;     // frees any probe device still in it
    end;
  end;
  Result := Entries;
end;

procedure TTapoScanner.FinishAsync(const AState: ITapoScanState;
  const AResult: TTapoScanResult; const AError: string;
  const AOnComplete: TTapoScanCompleteProc);
begin
  // main thread, scanner alive
  FTask := nil;
  if AResult <> nil then
    SetLastResult(AResult);
  EndWork(AState);
  if Assigned(AOnComplete) then
    AOnComplete(AResult, AError);
end;

procedure TTapoScanner.StartProbeStage(const ACandidates: TMacEntries;
  const AState: ITapoScanState; const AOnComplete: TTapoScanCompleteProc);
var
  Work: TProc;
begin
  // main thread
  Work :=
    procedure
    var
      R: TTapoScanResult;
      Err: string;
    begin
      Err := '';
      try
        R := ProbeAll(ACandidates, AState);
        if AState.Cancelled then
          Err := SScanCancelled;
      except
        on E: Exception do
          Err := E.Message;
      end;
      QueueFinish(AState, R, Err, AOnComplete);
    end;
  FTask := TTask.Run(Work);
end;

procedure TTapoScanner.StartSweepStage(const ANetwork, ASubnet: string;
  const AState: ITapoScanState; const AOnComplete: TTapoScanCompleteProc);
var
  Work: TProc;
begin
  // main thread
  Work :=
    procedure
    var
      R: TTapoScanResult;
      Candidates: TMacEntries;
      Err: string;
    begin
      Err := '';
      try
        Candidates := TcpSweep(ANetwork, ASubnet, AState);
        R := ProbeAll(Candidates, AState);
        if AState.Cancelled then
          Err := SScanCancelled;
      except
        on E: Exception do
          Err := E.Message;
      end;
      QueueFinish(AState, R, Err, AOnComplete);
    end;
  FTask := TTask.Run(Work);
end;

procedure TTapoScanner.ScanAsync(const ANetwork, ASubnet: string;
  const AOnComplete: TTapoScanCompleteProc);
var
  State: ITapoScanState;
  Relay: TArpRelay;
  Done: TMacScanCompleteProc;
begin
  State := BeginWork;
  SetLastArpError('');
  Relay := TArpRelay.Create(State);
  try
    Done :=
      procedure(const Entries: TMacEntries; const ErrorMsg: string)
      begin
        // main thread, after NetMacScan's last progress event
        Relay.Free;
        if not State.Alive then
          Exit;
        if State.Cancelled then
          State.Owner.FinishAsync(State, nil, SScanCancelled, AOnComplete)
        else if (ErrorMsg <> '') and State.Owner.FTcpSweepFallback then
        begin
          // the ARP table could not be read: find candidates by TCP instead
          State.Owner.SetLastArpError(ErrorMsg);
          State.Owner.StartSweepStage(ANetwork, ASubnet, State, AOnComplete);
        end
        else if ErrorMsg <> '' then
          State.Owner.FinishAsync(State, nil, ErrorMsg, AOnComplete)
        else
          State.Owner.StartProbeStage(Entries, State, AOnComplete);
      end;

    if FTpLinkOnly then
      ScanTapoDevicesAsync(ANetwork, ASubnet, Done, Relay.Progress, Self)
    else
      ScanNetworkMacsAsync(ANetwork, ASubnet, Done, Relay.Progress, Self);
  except
    Relay.Free;
    EndWork(State);
    raise;
  end;
end;

function TTapoScanner.Scan(const ANetwork, ASubnet: string): TTapoScanResult;
var
  State: ITapoScanState;
  Candidates: TMacEntries;
begin
  State := BeginWork;
  try
    SetLastArpError('');
    QueueProgress(State, tsgArp, 0, 0, 0);
    try
      Candidates := ArpScan(ANetwork, ASubnet);
      QueueProgress(State, tsgArp, 1, 1, Length(Candidates));
    except
      on E: Exception do
      begin
        // a bad network or mask is not something a TCP sweep can fix
        if not FTcpSweepFallback or (E is EArgumentException) then
          raise;
        SetLastArpError(E.Message);
        Candidates := TcpSweep(ANetwork, ASubnet, State);
      end;
    end;
    Result := ProbeAll(Candidates, State);
    SetLastResult(Result);
  finally
    EndWork(State);
  end;
end;

procedure TTapoScanner.CheckCandidatesAsync(const ACandidates: TMacEntries;
  const AOnComplete: TTapoScanCompleteProc);
begin
  StartProbeStage(Copy(ACandidates), BeginWork, AOnComplete);
end;

function TTapoScanner.CheckCandidates(const ACandidates: TMacEntries): TTapoScanResult;
var
  State: ITapoScanState;
begin
  State := BeginWork;
  try
    Result := ProbeAll(ACandidates, State);
    SetLastResult(Result);
  finally
    EndWork(State);
  end;
end;

function TTapoScanner.CheckHosts(const AHosts: array of string): TTapoScanResult;
var
  Candidates: TMacEntries;
  I: Integer;
begin
  SetLength(Candidates, Length(AHosts));
  for I := 0 to High(AHosts) do
  begin
    Candidates[I].IP := AHosts[I];
    Candidates[I].MAC := '';
  end;
  Result := CheckCandidates(Candidates);
end;

end.
