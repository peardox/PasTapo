//** @abstract(State that lasts between sessions, stored as JSON with Neon
//** @(https://github.com/paolo-rossi/delphi-neon@).)
//**
//** @preformatted(
//** settings.json  the Tapo account, the network to scan, and whether the
//**                account worked the last time it was used
//** devices.json   every Tapo device a scan has found
//** )
//**
//** Both live in the per-user application data folder of the platform:
//**
//** @preformatted(
//** Windows  %LOCALAPPDATA%\TapoScan
//** macOS    ~/Library/Application Support/TapoScan
//** Linux    $XDG_CONFIG_HOME/TapoScan, or ~/.config/TapoScan
//** )
//**
//** (set TapoAppFolderName before first use to change "TapoScan").
//**
//** Files are written to a temporary file first and then renamed, so a crash never leaves half a
//** file. On macOS and Linux they are readable by the owner only. The password is stored as plain
//** text for now.
//**
//** Scans only ever add to devices.json: a device that is not found again is kept. A device found
//** at a new address (same device ID) has its address updated.
unit Tapo.Settings;

{
  State that lasts between sessions, stored as JSON with Neon
  (https://github.com/paolo-rossi/delphi-neon):

    settings.json  the Tapo account, the network to scan, and whether the
                   account worked the last time it was used
    devices.json   every Tapo device a scan has found

  Both live in the per-user application data folder of the platform:

    Windows  %LOCALAPPDATA%\TapoScan
    macOS    ~/Library/Application Support/TapoScan
    Linux    $XDG_CONFIG_HOME/TapoScan, or ~/.config/TapoScan

  (set TapoAppFolderName before first use to change "TapoScan").

  Files are written to a temporary file first and then renamed, so a crash
  never leaves half a file. On macOS and Linux they are readable by the
  owner only. The password is stored as plain text for now.

  Scans only ever add to devices.json: a device that is not found again is
  kept. A device found at a new address (same device ID) has its address
  updated.
}

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Rtti,
  System.Generics.Collections,
  Neon.Core.Types, Neon.Core.Persistence, Neon.Core.Persistence.JSON,
  Tapo.Client, Tapo.Discovery;

type
  //** @abstract(Whether the stored Tapo account details have been shown to work.)
  /// <summary>Whether the stored Tapo account details have been shown to work.</summary>
  TTapoCredentialState = (
    //** @abstract(Not tried yet: no scan has finished since they were entered.)
    /// <summary>Not tried yet: no scan has finished since they were entered.</summary>
    csUnknown,
    //** @abstract(A Tapo device accepted them.)
    /// <summary>A Tapo device accepted them.</summary>
    csGood,
    //** @abstract(Tapo devices rejected them and none accepted them.)
    /// <summary>Tapo devices rejected them and none accepted them.</summary>
    csBad);

  //** @abstract(The contents of settings.json.)
  //**
  //** Every public property is written to the file by Neon. Use @link(Load) and @link(Save);
  //** @link(FileName) says where it lives.
  /// <summary>The contents of settings.json.</summary>
  /// <remarks>
  ///   Every public property is written to the file by Neon. Use
  ///   <see cref="Load"/> and <see cref="Save"/>; <see cref="FileName"/> says
  ///   where it lives.
  /// </remarks>
  TTapoSettings = class
  private
    FVersion: Integer;
    FUsername: string;
    FPassword: string;
    FNetwork: string;
    FSubnet: string;
    FCredentialState: TTapoCredentialState;
    FCredentialsCheckedAt: TDateTime;
  public
    //** @abstract(Creates empty settings: no account, network and subnet blank, state csUnknown.)
    /// <summary>Creates empty settings: no account, network and subnet blank, state csUnknown.</summary>
    constructor Create;
    //** @abstract(The full path of settings.json.)
    //**
    //** @returns(A path in the platform's per-user application data folder.)
    /// <summary>The full path of settings.json.</summary>
    /// <returns>A path in the platform's per-user application data folder.</returns>
    class function FileName: string;
    //** @abstract(True if settings.json exists.)
    //**
    //** @returns(False on first run.)
    /// <summary>True if settings.json exists.</summary>
    /// <returns>False on first run.</returns>
    class function Exists: Boolean;
    //** @abstract(Reads settings.json into this object.)
    //**
    //** @returns(False if the file does not exist or cannot be read; the object then keeps its
    //** values.)
    /// <summary>Reads settings.json into this object.</summary>
    /// <returns>False if the file does not exist or cannot be read; the object then keeps its values.</returns>
    function Load: Boolean;
    //** @abstract(Writes this object to settings.json, creating the folder if needed.)
    //**
    //** @raises(EInOutError The file could not be written.)
    /// <summary>Writes this object to settings.json, creating the folder if needed.</summary>
    /// <exception cref="EInOutError">The file could not be written.</exception>
    procedure Save;
    //** @abstract(True if a user name and password are set.)
    //**
    //** @returns(False if either is empty.)
    /// <summary>True if a user name and password are set.</summary>
    /// <returns>False if either is empty.</returns>
    function HasLogin: Boolean;
    //** @abstract(True if the network and subnet describe a usable range.)
    //**
    //** @returns(False if either is empty or invalid.)
    /// <summary>True if the network and subnet describe a usable range.</summary>
    /// <returns>False if either is empty or invalid.</returns>
    function HasValidNetwork: Boolean;
    //** @abstract(Records whether the account worked, and when.)
    //**
    //** @param(AState The new state.)
    /// <summary>Records whether the account worked, and when.</summary>
    /// <param name="AState">The new state.</param>
    procedure MarkCredentials(AState: TTapoCredentialState);

    //** @abstract(The file format version; 1.)
    /// <summary>The file format version; 1.</summary>
    property Version: Integer read FVersion write FVersion;
    //** @abstract(The Tapo app account e-mail.)
    /// <summary>The Tapo app account e-mail.</summary>
    property Username: string read FUsername write FUsername;
    //** @abstract(The Tapo app account password @(plain text for now@).)
    /// <summary>The Tapo app account password (plain text for now).</summary>
    property Password: string read FPassword write FPassword;
    //** @abstract(Any address in the network to scan, for example '192.168.1.0'.)
    /// <summary>Any address in the network to scan, for example '192.168.1.0'.</summary>
    property Network: string read FNetwork write FNetwork;
    //** @abstract(The subnet mask, for example '255.255.255.0'.)
    /// <summary>The subnet mask, for example '255.255.255.0'.</summary>
    property Subnet: string read FSubnet write FSubnet;
    //** @abstract(Whether the account worked the last time it was used.)
    /// <summary>Whether the account worked the last time it was used.</summary>
    property CredentialState: TTapoCredentialState read FCredentialState write FCredentialState;
    //** @abstract(When @link(CredentialState) was last set from a result; 0 if never.)
    /// <summary>When <see cref="CredentialState"/> was last set from a result; 0 if never.</summary>
    property CredentialsCheckedAt: TDateTime read FCredentialsCheckedAt write FCredentialsCheckedAt;
  end;

  //** @abstract(One device in devices.json.)
  /// <summary>One device in devices.json.</summary>
  TTapoStoredDevice = record
    //** @abstract(The device's own ID; empty if it was only ever seen as already added.)
    /// <summary>The device's own ID; empty if it was only ever seen as already added.</summary>
    DeviceId: string;
    //** @abstract(The IP address it was last found at.)
    /// <summary>The IP address it was last found at.</summary>
    Host: string;
    //** @abstract(The MAC address, as 'AA:BB:CC:DD:EE:FF'.)
    /// <summary>The MAC address, as 'AA:BB:CC:DD:EE:FF'.</summary>
    MAC: string;
    //** @abstract(The model it reports, for example 'P110'.)
    /// <summary>The model it reports, for example 'P110'.</summary>
    Model: string;
    //** @abstract(The device type it reports, for example 'SMART.TAPOPLUG'.)
    /// <summary>The device type it reports, for example 'SMART.TAPOPLUG'.</summary>
    DeviceType: string;
    //** @abstract(The name given in the Tapo app.)
    /// <summary>The name given in the Tapo app.</summary>
    Nickname: string;
    //** @abstract(The qualified name of the class it was added as, for example
    //** 'Tapo.Devices.TTapoP110'.)
    /// <summary>The qualified name of the class it was added as, for example 'Tapo.Devices.TTapoP110'.</summary>
    DeviceClass: string;
    //** @abstract(When a scan first found it.)
    /// <summary>When a scan first found it.</summary>
    FirstSeen: TDateTime;
    //** @abstract(When a scan or a check last reached it.)
    /// <summary>When a scan or a check last reached it.</summary>
    LastSeen: TDateTime;
    //** @abstract(Whether the last check of it succeeded.)
    /// <summary>Whether the last check of it succeeded.</summary>
    LastCheckOk: Boolean;
    //** @abstract(What the last check found, in words.)
    /// <summary>What the last check found, in words.</summary>
    LastCheckResult: string;
  end;

  //** @abstract(The result of checking one stored device at startup.)
  /// <summary>The result of checking one stored device at startup.</summary>
  TTapoCheckStatus = (
    //** @abstract(It answered, and it is the device that was stored.)
    /// <summary>It answered, and it is the device that was stored.</summary>
    tcsOk,
    //** @abstract(It answered, but with another device ID: something else has that address now.)
    /// <summary>It answered, but with another device ID: something else has that address now.</summary>
    tcsDifferentDevice,
    //** @abstract(It answered but rejected the Tapo account.)
    /// <summary>It answered but rejected the Tapo account.</summary>
    tcsBadCredentials,
    //** @abstract(Nothing answered, or it could not be logged in to.)
    /// <summary>Nothing answered, or it could not be logged in to.</summary>
    tcsUnreachable,
    //** @abstract(Its class could not be found, so it was not added.)
    /// <summary>Its class could not be found, so it was not added.</summary>
    tcsNotLoaded);

  //** @abstract(The contents of devices.json, and the means to load them into a client.)
  /// <summary>The contents of devices.json, and the means to load them into a client.</summary>
  TTapoDeviceStore = class
  private
    FVersion: Integer;
    FDevices: TArray<TTapoStoredDevice>;
  public
    //** @abstract(Creates an empty store.)
    /// <summary>Creates an empty store.</summary>
    constructor Create;
    //** @abstract(The full path of devices.json.)
    //**
    //** @returns(A path in the platform's per-user application data folder.)
    /// <summary>The full path of devices.json.</summary>
    /// <returns>A path in the platform's per-user application data folder.</returns>
    class function FileName: string;
    //** @abstract(True if devices.json exists.)
    //**
    //** @returns(False until a scan has found something.)
    /// <summary>True if devices.json exists.</summary>
    /// <returns>False until a scan has found something.</returns>
    class function Exists: Boolean;
    //** @abstract(Reads devices.json into this object.)
    //**
    //** @returns(False if the file does not exist or cannot be read; the store then stays as it
    //** was.)
    /// <summary>Reads devices.json into this object.</summary>
    /// <returns>False if the file does not exist or cannot be read; the store then stays as it was.</returns>
    function Load: Boolean;
    //** @abstract(Writes this object to devices.json, creating the folder if needed.)
    //**
    //** @raises(EInOutError The file could not be written.)
    /// <summary>Writes this object to devices.json, creating the folder if needed.</summary>
    /// <exception cref="EInOutError">The file could not be written.</exception>
    procedure Save;

    //** @abstract(The position of the device with an ID.)
    //**
    //** @param(ADeviceId The device ID.)
    //**
    //** @returns(The index, or -1.)
    /// <summary>The position of the device with an ID.</summary>
    /// <param name="ADeviceId">The device ID.</param>
    /// <returns>The index, or -1.</returns>
    function IndexOfId(const ADeviceId: string): Integer;
    //** @abstract(The position of the device stored at an address.)
    //**
    //** @param(AHost The address.)
    //**
    //** @returns(The index, or -1.)
    /// <summary>The position of the device stored at an address.</summary>
    /// <param name="AHost">The address.</param>
    /// <returns>The index, or -1.</returns>
    function IndexOfHost(const AHost: string): Integer;

    //** @abstract(Adds the Tapo devices of a scan; never removes any.)
    //**
    //** A device is matched by its ID first, then by address. A match has its address, MAC, model,
    //** name and class refreshed; anything else is added. Devices the scan did not find are kept as
    //** they are.
    //**
    //** @param(AResult A scan result.)
    //**
    //** @returns(How many devices were new.)
    /// <summary>Adds the Tapo devices of a scan; never removes any.</summary>
    /// <param name="AResult">A scan result.</param>
    /// <returns>How many devices were new.</returns>
    /// <remarks>
    ///   A device is matched by its ID first, then by address. A match has
    ///   its address, MAC, model, name and class refreshed; anything else is
    ///   added. Devices the scan did not find are kept as they are.
    /// </remarks>
    function Merge(const AResult: TTapoScanResult): Integer;

    //** @abstract(Adds every stored device to a client, as its stored class.)
    //**
    //** Nothing is sent to the devices: each one logs in on its first request. @link(CheckDevice) is
    //** the quick check of one.
    //**
    //** @param(AClient The client.)
    //**
    //** @param(ASkipped Receives one line per device that could not be added.)
    //**
    //** @returns(The devices, in store order; nil where a device could not be added.)
    /// <summary>Adds every stored device to a client, as its stored class.</summary>
    /// <param name="AClient">The client.</param>
    /// <param name="ASkipped">Receives one line per device that could not be added.</param>
    /// <returns>The devices, in store order; nil where a device could not be added.</returns>
    /// <remarks>
    ///   Nothing is sent to the devices: each one logs in on its first
    ///   request. <see cref="CheckDevice"/> is the quick check of one.
    /// </remarks>
    function AddToClient(AClient: TTapoClient; out ASkipped: TArray<string>): TArray<TTapoDevice>;

    //** @abstract(Checks that a stored device is still where it was. Do not call it on the main
    //** thread.)
    //**
    //** Logs in if needed and reads the device info: one or two requests. Records the result, the
    //** time and any new name in the store, but does not save it. Safe to call for several indexes
    //** from different threads at once.
    //**
    //** @param(AIndex The device's position in @link(Devices).)
    //**
    //** @param(ADevice The device object for it, from @link(AddToClient); may be nil.)
    //**
    //** @param(AMessage Receives a short description of the result.)
    //**
    //** @returns(What was found.)
    /// <summary>Checks that a stored device is still where it was. Do not call it on the main thread.</summary>
    /// <param name="AIndex">The device's position in <see cref="Devices"/>.</param>
    /// <param name="ADevice">The device object for it, from <see cref="AddToClient"/>; may be nil.</param>
    /// <param name="AMessage">Receives a short description of the result.</param>
    /// <returns>What was found.</returns>
    /// <remarks>
    ///   Logs in if needed and reads the device info: one or two requests.
    ///   Records the result, the time and any new name in the store, but does
    ///   not save it. Safe to call for several indexes from different
    ///   threads at once.
    /// </remarks>
    function CheckDevice(AIndex: Integer; ADevice: TTapoDevice; out AMessage: string): TTapoCheckStatus;

    //** @abstract(The file format version; 1.)
    /// <summary>The file format version; 1.</summary>
    property Version: Integer read FVersion write FVersion;
    //** @abstract(The stored devices.)
    /// <summary>The stored devices.</summary>
    property Devices: TArray<TTapoStoredDevice> read FDevices write FDevices;
  end;

var
  //** @abstract(The name of the folder, inside the platform's application data folder, that holds
  //** settings.json and devices.json. Set it before first use.)
  /// <summary>
  ///   The name of the folder, inside the platform's application data
  ///   folder, that holds settings.json and devices.json. Set it before
  ///   first use.
  /// </summary>
  TapoAppFolderName: string = 'TapoScan';

//** @abstract(The folder that holds settings.json and devices.json, created if missing.)
//**
//** @returns(The full path.)
/// <summary>The folder that holds settings.json and devices.json, created if missing.</summary>
/// <returns>The full path.</returns>
function TapoDataFolder: string;

//** @abstract(Finds this computer's local IPv4 network.)
//**
//** Asks the system which local address it would use to reach the internet (a UDP socket is pointed
//** at a public address; nothing is sent) and takes that adapter's mask. Without a route it falls
//** back to the adapter list, preferring 192.168.x.x over 10.x.x.x over 172.16-31.x.x and skipping
//** recognisable virtual adapters.
//**
//** @param(ANetwork Receives the network address, for example '192.168.1.0'.)
//**
//** @param(AMask Receives the subnet mask, for example '255.255.255.0'.)
//**
//** @returns(True if a private @(LAN@) IPv4 address was found; otherwise False and '192.168.0.0' /
//** '255.255.255.0'.)
/// <summary>Finds this computer's local IPv4 network.</summary>
/// <param name="ANetwork">Receives the network address, for example '192.168.1.0'.</param>
/// <param name="AMask">Receives the subnet mask, for example '255.255.255.0'.</param>
/// <returns>True if a private (LAN) IPv4 address was found; otherwise False and '192.168.0.0' / '255.255.255.0'.</returns>
/// <remarks>
///   Asks the system which local address it would use to reach the
///   internet (a UDP socket is pointed at a public address; nothing is
///   sent) and takes that adapter's mask. Without a route it falls back to
///   the adapter list, preferring 192.168.x.x over 10.x.x.x over
///   172.16-31.x.x and skipping recognisable virtual adapters.
/// </remarks>
function TapoLocalNetwork(out ANetwork, AMask: string): Boolean;

//** @abstract(A short English name for a check result.)
//**
//** @param(AStatus The result.)
//**
//** @returns(For example 'ok' or 'unreachable'.)
/// <summary>A short English name for a check result.</summary>
/// <param name="AStatus">The result.</param>
/// <returns>For example 'ok' or 'unreachable'.</returns>
function TapoCheckStatusName(AStatus: TTapoCheckStatus): string;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
{$IFDEF POSIX}
  Posix.Base,
{$ENDIF}
  System.SyncObjs, Tapo.Models, NetMacScan;

const
  SETTINGS_FILE = 'settings.json';
  DEVICES_FILE = 'devices.json';
  FILE_VERSION = 1;

var
  StoreLock: TCriticalSection;   // guards the device arrays during checks

{ ---------------------------------------------------------------------------
  Files
  --------------------------------------------------------------------------- }

function TapoDataFolder: string;
var
  Base: string;
begin
{$IF Defined(MSWINDOWS)}
  Base := GetEnvironmentVariable('LOCALAPPDATA');
  if Base = '' then
    Base := TPath.GetHomePath;                 // %APPDATA%
{$ELSEIF Defined(MACOS)}
  Base := TPath.Combine(TPath.GetHomePath, 'Library/Application Support');
{$ELSE}
  Base := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if Base = '' then
    Base := TPath.Combine(TPath.GetHomePath, '.config');
{$ENDIF}
  Result := TPath.Combine(Base, TapoAppFolderName);
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
end;

function NeonConfig: INeonConfiguration;
begin
  // names exactly as declared (enums too: "csGood"), ISO 8601 UTC dates,
  // indented so the files are easy to read
  Result := TNeonConfiguration.Create.SetPrettyPrint(True);
end;

// Writes a temporary file, then renames it over the old one.
procedure WriteFileSafely(const AFileName, AText: string);
var
  Temp: string;
begin
  Temp := AFileName + '.tmp';
  TFile.WriteAllBytes(Temp, TEncoding.UTF8.GetBytes(AText));   // no BOM
{$IFDEF POSIX}
  // owner read/write only: the file holds the account password
  try
    TFile.SetAttributes(Temp, [TFileAttribute.faOwnerRead, TFileAttribute.faOwnerWrite]);
  except
    // not fatal: the file is still in the user's own folder
  end;
{$ENDIF}
{$IFDEF MSWINDOWS}
  if TFile.Exists(AFileName) then
    TFile.Delete(AFileName);                  // rename does not replace on Windows
{$ENDIF}
  if not RenameFile(Temp, AFileName) then     // atomic replace on POSIX
    raise EInOutError.CreateFmt('Could not write %s', [AFileName]);
end;

function ReadFileText(const AFileName: string; out AText: string): Boolean;
begin
  Result := TFile.Exists(AFileName);
  if Result then
    AText := TFile.ReadAllText(AFileName, TEncoding.UTF8);
end;

{ ---------------------------------------------------------------------------
  TTapoSettings
  --------------------------------------------------------------------------- }

constructor TTapoSettings.Create;
begin
  inherited Create;
  FVersion := FILE_VERSION;
  FCredentialState := csUnknown;
end;

class function TTapoSettings.FileName: string;
begin
  Result := TPath.Combine(TapoDataFolder, SETTINGS_FILE);
end;

class function TTapoSettings.Exists: Boolean;
begin
  Result := TFile.Exists(FileName);
end;

function TTapoSettings.Load: Boolean;
var
  Text: string;
begin
  Result := False;
  try
    if ReadFileText(FileName, Text) then
    begin
      TNeon.JSONToObject(Self, Text, NeonConfig);
      Result := True;
    end;
  except
    Result := False;    // unreadable: treat as missing, so the form asks again
  end;
end;

procedure TTapoSettings.Save;
begin
  FVersion := FILE_VERSION;
  WriteFileSafely(FileName, TNeon.ObjectToJSONString(Self, NeonConfig));
end;

function TTapoSettings.HasLogin: Boolean;
begin
  Result := (Trim(FUsername) <> '') and (FPassword <> '');
end;

function TTapoSettings.HasValidNetwork: Boolean;
begin
  try
    Result := Length(SubnetHosts(FNetwork, FSubnet)) > 0;
  except
    Result := False;
  end;
end;

procedure TTapoSettings.MarkCredentials(AState: TTapoCredentialState);
begin
  FCredentialState := AState;
  FCredentialsCheckedAt := Now;
end;

{ ---------------------------------------------------------------------------
  TTapoDeviceStore
  --------------------------------------------------------------------------- }

constructor TTapoDeviceStore.Create;
begin
  inherited Create;
  FVersion := FILE_VERSION;
end;

class function TTapoDeviceStore.FileName: string;
begin
  Result := TPath.Combine(TapoDataFolder, DEVICES_FILE);
end;

class function TTapoDeviceStore.Exists: Boolean;
begin
  Result := TFile.Exists(FileName);
end;

function TTapoDeviceStore.Load: Boolean;
var
  Text: string;
begin
  Result := False;
  try
    if ReadFileText(FileName, Text) then
    begin
      TNeon.JSONToObject(Self, Text, NeonConfig);
      Result := True;
    end;
  except
    Result := False;
  end;
end;

procedure TTapoDeviceStore.Save;
var
  Json: string;
begin
  FVersion := FILE_VERSION;
  StoreLock.Enter;
  try
    Json := TNeon.ObjectToJSONString(Self, NeonConfig);
  finally
    StoreLock.Leave;
  end;
  WriteFileSafely(FileName, Json);
end;

function TTapoDeviceStore.IndexOfId(const ADeviceId: string): Integer;
var
  I: Integer;
begin
  if ADeviceId <> '' then
    for I := 0 to High(FDevices) do
      if SameText(FDevices[I].DeviceId, ADeviceId) then
        Exit(I);
  Result := -1;
end;

function TTapoDeviceStore.IndexOfHost(const AHost: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FDevices) do
    if SameText(FDevices[I].Host, Trim(AHost)) then
      Exit(I);
  Result := -1;
end;

function TTapoDeviceStore.Merge(const AResult: TTapoScanResult): Integer;
var
  E: TTapoScanEntry;
  I: Integer;
  D: TTapoStoredDevice;
begin
  Result := 0;
  StoreLock.Enter;
  try
    for E in AResult do
    begin
      if not E.IsTapo then
        Continue;

      I := IndexOfId(E.DeviceId);
      if I < 0 then
      begin
        I := IndexOfHost(E.IP);
        // another device now holds that address: keep the old record
        if (I >= 0) and (E.DeviceId <> '') and (FDevices[I].DeviceId <> '') and
           not SameText(FDevices[I].DeviceId, E.DeviceId) then
          I := -1;
      end;

      if I < 0 then
      begin
        D := Default(TTapoStoredDevice);
        D.FirstSeen := Now;
        FDevices := FDevices + [D];
        I := High(FDevices);
        Inc(Result);
      end;

      // refresh what the scan knows; keep what it does not
      if E.DeviceId <> '' then
        FDevices[I].DeviceId := E.DeviceId;
      FDevices[I].Host := E.IP;
      if E.MAC <> '' then
        FDevices[I].MAC := E.MAC;
      if E.Model <> '' then
        FDevices[I].Model := E.Model;
      if E.DeviceType <> '' then
        FDevices[I].DeviceType := E.DeviceType;
      if E.Status = tssAdded then
        FDevices[I].Nickname := E.Nickname;
      if E.Device <> nil then
        FDevices[I].DeviceClass := E.Device.QualifiedClassName;
      FDevices[I].LastSeen := Now;
      FDevices[I].LastCheckOk := True;
      FDevices[I].LastCheckResult := 'found by a scan';
    end;
  finally
    StoreLock.Leave;
  end;
end;

// The class stored for a device: by its qualified name, else by its model.
function ResolveDeviceClass(const D: TTapoStoredDevice): TTapoDeviceClass;
var
  Ctx: TRttiContext;
  T: TRttiType;
begin
  Result := nil;
  if D.DeviceClass <> '' then
  begin
    Ctx := TRttiContext.Create;
    T := Ctx.FindType(D.DeviceClass);
    if (T <> nil) and T.IsInstance and
       T.AsInstance.MetaclassType.InheritsFrom(TTapoDevice) then
      Exit(TTapoDeviceClass(T.AsInstance.MetaclassType));
  end;
  if D.Model <> '' then
    Result := TapoDeviceClassForModel(D.Model);
end;

function TTapoDeviceStore.AddToClient(AClient: TTapoClient;
  out ASkipped: TArray<string>): TArray<TTapoDevice>;
var
  I: Integer;
  Cls: TTapoDeviceClass;
begin
  ASkipped := nil;
  SetLength(Result, Length(FDevices));
  for I := 0 to High(FDevices) do
  begin
    Result[I] := nil;
    Cls := ResolveDeviceClass(FDevices[I]);
    if Cls = nil then
    begin
      ASkipped := ASkipped + [Format('%s (%s): unknown class %s',
        [FDevices[I].Host, FDevices[I].Model, FDevices[I].DeviceClass])];
      Continue;
    end;
    try
      Result[I] := AClient.AddDevice(Cls, FDevices[I].Host);
    except
      on E: Exception do
        ASkipped := ASkipped + [Format('%s (%s): %s', [FDevices[I].Host, FDevices[I].Model, E.Message])];
    end;
  end;
end;

function TTapoDeviceStore.CheckDevice(AIndex: Integer; ADevice: TTapoDevice;
  out AMessage: string): TTapoCheckStatus;
var
  Stored: TTapoStoredDevice;
  Info: TTapoDeviceInfo;
begin
  StoreLock.Enter;
  try
    Stored := FDevices[AIndex];
  finally
    StoreLock.Leave;
  end;

  if ADevice = nil then
  begin
    Result := tcsNotLoaded;
    AMessage := 'not loaded (unknown device class)';
  end
  else
    try
      Info := ADevice.GetDeviceInfo;            // logs in first if needed
      if (Stored.DeviceId <> '') and (Info.DeviceId <> '') and
         not SameText(Stored.DeviceId, Info.DeviceId) then
      begin
        Result := tcsDifferentDevice;
        AMessage := Format('another device answers there now (%s "%s")', [Info.Model, Info.Nickname]);
      end
      else
      begin
        Result := tcsOk;
        AMessage := 'ok';
        Stored.Nickname := Info.Nickname;
        if Stored.DeviceId = '' then
          Stored.DeviceId := Info.DeviceId;
        Stored.LastSeen := Now;
      end;
    except
      on E: ETapoAuthError do
      begin
        Result := tcsBadCredentials;
        AMessage := E.Message;
      end;
      on E: Exception do
      begin
        Result := tcsUnreachable;
        AMessage := E.Message;
      end;
    end;

  Stored.LastCheckOk := Result = tcsOk;
  Stored.LastCheckResult := AMessage;
  StoreLock.Enter;
  try
    // the array is not resized during checks, so the index still holds
    FDevices[AIndex] := Stored;
  finally
    StoreLock.Leave;
  end;
end;

function TapoCheckStatusName(AStatus: TTapoCheckStatus): string;
begin
  case AStatus of
    tcsOk:              Result := 'ok';
    tcsDifferentDevice: Result := 'different device';
    tcsBadCredentials:  Result := 'account rejected';
    tcsUnreachable:     Result := 'unreachable';
    tcsNotLoaded:       Result := 'not loaded';
  else
    Result := '?';
  end;
end;

{ ---------------------------------------------------------------------------
  Local network
  --------------------------------------------------------------------------- }

type
  TLocalAddress = record
    IP, Mask: Cardinal;
    Name: string;
  end;

function IPv4Text(A: Cardinal): string;
begin
  Result := Format('%d.%d.%d.%d', [(A shr 24) and $FF, (A shr 16) and $FF,
    (A shr 8) and $FF, A and $FF]);
end;

function ParseIPv4(const S: string; out A: Cardinal): Boolean;
var
  Parts: TArray<string>;
  I, B: Integer;
begin
  A := 0;
  Parts := S.Trim.Split(['.']);
  Result := Length(Parts) = 4;
  if Result then
    for I := 0 to 3 do
    begin
      if not TryStrToInt(Parts[I], B) or (B < 0) or (B > 255) then
        Exit(False);
      A := (A shl 8) or Cardinal(B);
    end;
end;

// Lower is better; 0 = not a private LAN address.
function PrivateRank(IP: Cardinal): Integer;
begin
  if (IP shr 16) = $C0A8 then          // 192.168/16
    Result := 1
  else if (IP shr 24) = 10 then        // 10/8
    Result := 2
  else if (IP shr 20) = $AC1 then      // 172.16/12
    Result := 3
  else
    Result := 0;
end;

function IsVirtualName(const AName: string): Boolean;
const
  Prefixes: array[0..11] of string = ('docker', 'br-', 'veth', 'virbr', 'vmnet',
    'vboxnet', 'utun', 'tun', 'tap', 'bridge', 'awdl', 'llw');
var
  P: string;
  L: string;
begin
  L := LowerCase(AName);
  for P in Prefixes do
    if L.StartsWith(P) then
      Exit(True);
  Result := L.Contains('virtual') or L.Contains('vmware') or L.Contains('hyper-v') or
    L.Contains('vpn') or L.Contains('loopback');
end;

{$IFDEF MSWINDOWS}
// IP_ADAPTER_INFO and IP_ADDR_STRING (iptypes.h), declared here so that only
// the fields read below matter; the buffer size comes from the API.
type
  PIPAddrString = ^TIPAddrString;
  TIPAddrString = record
    Next: PIPAddrString;
    IpAddress: array[0..15] of AnsiChar;
    IpMask: array[0..15] of AnsiChar;
    Context: DWORD;
  end;

  PIPAdapterInfo = ^TIPAdapterInfo;
  TIPAdapterInfo = record
    Next: PIPAdapterInfo;
    ComboIndex: DWORD;
    AdapterName: array[0..259] of AnsiChar;
    Description: array[0..131] of AnsiChar;
    AddressLength: UINT;
    Address: array[0..7] of Byte;
    Index: DWORD;
    AdapterType: UINT;
    DhcpEnabled: UINT;
    CurrentIpAddress: PIPAddrString;
    IpAddressList: TIPAddrString;
    GatewayList: TIPAddrString;
    DhcpServer: TIPAddrString;
    HaveWins: BOOL;
    PrimaryWinsServer: TIPAddrString;
    SecondaryWinsServer: TIPAddrString;
    LeaseObtained: Int64;
    LeaseExpires: Int64;
  end;

function GetAdaptersInfo(pAdapterInfo: PIPAdapterInfo; var pOutBufLen: ULONG): DWORD; stdcall;
  external 'iphlpapi.dll' name 'GetAdaptersInfo';

function LocalAddresses: TArray<TLocalAddress>;
var
  Size: ULONG;
  Buf: TBytes;
  Adapter: PIPAdapterInfo;
  Addr: PIPAddrString;
  L: TLocalAddress;
  Gateway: string;
begin
  Result := nil;
  Size := 0;
  if GetAdaptersInfo(nil, Size) <> ERROR_BUFFER_OVERFLOW then
    Exit;
  SetLength(Buf, Size);
  Adapter := PIPAdapterInfo(@Buf[0]);
  if GetAdaptersInfo(Adapter, Size) <> NO_ERROR then
    Exit;
  while Adapter <> nil do
  begin
    // an adapter with a default gateway is the one that reaches the LAN
    Gateway := string(PAnsiChar(@Adapter^.GatewayList.IpAddress[0]));
    Addr := @Adapter^.IpAddressList;
    while Addr <> nil do
    begin
      L.Name := string(PAnsiChar(@Adapter^.Description[0]));
      if (Gateway = '') or (Gateway = '0.0.0.0') then
        L.Name := 'virtual (no gateway) ' + L.Name;
      if ParseIPv4(string(PAnsiChar(@Addr^.IpAddress[0])), L.IP) and
         ParseIPv4(string(PAnsiChar(@Addr^.IpMask[0])), L.Mask) and (L.IP <> 0) then
        Result := Result + [L];
      Addr := Addr^.Next;
    end;
    Adapter := Adapter^.Next;
  end;
end;
{$ENDIF}

{$IFDEF POSIX}
type
  PIfAddrs = ^TIfAddrs;
  TIfAddrs = record               // struct ifaddrs (same layout on macOS and Linux)
    ifa_next: PIfAddrs;
    ifa_name: PAnsiChar;
    ifa_flags: Cardinal;
    ifa_addr: PByte;
    ifa_netmask: PByte;
    ifa_dstaddr: Pointer;
    ifa_data: Pointer;
  end;

const
  IFF_UP = $1;
  IFF_LOOPBACK = $8;
  AF_INET_ = 2;

function getifaddrs(var ifap: PIfAddrs): Integer; cdecl;
  external libc name _PU + 'getifaddrs';
procedure freeifaddrs(ifa: PIfAddrs); cdecl;
  external libc name _PU + 'freeifaddrs';

// sockaddr family: a byte after sa_len on macOS, a 16-bit field on Linux
function IsInet(P: PByte): Boolean;
begin
  if P = nil then
    Exit(False);
{$IFDEF MACOS}
  Result := P[1] = AF_INET_;
{$ELSE}
  Result := PWord(P)^ = AF_INET_;
{$ENDIF}
end;

function InetAddr(P: PByte): Cardinal;
begin
  Result := (Cardinal(P[4]) shl 24) or (Cardinal(P[5]) shl 16) or
            (Cardinal(P[6]) shl 8) or Cardinal(P[7]);
end;

function LocalAddresses: TArray<TLocalAddress>;
var
  List, P: PIfAddrs;
  L: TLocalAddress;
begin
  Result := nil;
  if getifaddrs(List) <> 0 then
    Exit;
  try
    P := List;
    while P <> nil do
    begin
      if ((P^.ifa_flags and IFF_UP) <> 0) and ((P^.ifa_flags and IFF_LOOPBACK) = 0) and
         IsInet(P^.ifa_addr) and (P^.ifa_netmask <> nil) then
      begin
        L.Name := string(P^.ifa_name);
        L.IP := InetAddr(P^.ifa_addr);
        L.Mask := InetAddr(P^.ifa_netmask);
        Result := Result + [L];
      end;
      P := P^.ifa_next;
    end;
  finally
    freeifaddrs(List);
  end;
end;
{$ENDIF}

{ The local address the system would use to reach the internet: a UDP socket
  "connected" to a public address picks the route without sending anything.
  sockaddr_in is built by hand (16 bytes) because its first field differs:
  sin_len + 8-bit family on macOS, 16-bit family on Windows and Linux. }

{$IFDEF MSWINDOWS}
function WSAStartup(wVersionRequired: Word; lpWSAData: Pointer): Integer; stdcall;
  external 'ws2_32.dll' name 'WSAStartup';
function WSACleanup: Integer; stdcall;
  external 'ws2_32.dll' name 'WSACleanup';
function sock_socket(af, stype, protocol: Integer): NativeUInt; stdcall;
  external 'ws2_32.dll' name 'socket';
function sock_connect(s: NativeUInt; name: Pointer; namelen: Integer): Integer; stdcall;
  external 'ws2_32.dll' name 'connect';
function sock_getsockname(s: NativeUInt; name: Pointer; var namelen: Integer): Integer; stdcall;
  external 'ws2_32.dll' name 'getsockname';
function sock_close(s: NativeUInt): Integer; stdcall;
  external 'ws2_32.dll' name 'closesocket';

function RouteLocalIP(out AIP: Cardinal): Boolean;
var
  WsaData: array[0..1023] of Byte;
  S: NativeUInt;
  Remote, Local: array[0..15] of Byte;
  Len: Integer;
begin
  Result := False;
  AIP := 0;
  if WSAStartup($0202, @WsaData[0]) <> 0 then
    Exit;
  try
    S := sock_socket(2 {AF_INET}, 2 {SOCK_DGRAM}, 17 {IPPROTO_UDP});
    if S = NativeUInt(-1) then
      Exit;
    try
      FillChar(Remote, SizeOf(Remote), 0);
      PWord(@Remote[0])^ := 2;                 // AF_INET
      Remote[3] := 53;                         // port 53, big-endian
      Remote[4] := 8; Remote[5] := 8; Remote[6] := 8; Remote[7] := 8;
      if sock_connect(S, @Remote[0], SizeOf(Remote)) <> 0 then
        Exit;
      FillChar(Local, SizeOf(Local), 0);
      Len := SizeOf(Local);
      if sock_getsockname(S, @Local[0], Len) <> 0 then
        Exit;
      AIP := (Cardinal(Local[4]) shl 24) or (Cardinal(Local[5]) shl 16) or
             (Cardinal(Local[6]) shl 8) or Cardinal(Local[7]);
      Result := AIP <> 0;
    finally
      sock_close(S);
    end;
  finally
    WSACleanup;
  end;
end;
{$ENDIF}

{$IFDEF POSIX}
function sock_socket(domain, stype, protocol: Integer): Integer; cdecl;
  external libc name _PU + 'socket';
function sock_connect(fd: Integer; addr: Pointer; len: Cardinal): Integer; cdecl;
  external libc name _PU + 'connect';
function sock_getsockname(fd: Integer; addr: Pointer; var len: Cardinal): Integer; cdecl;
  external libc name _PU + 'getsockname';
function sock_close(fd: Integer): Integer; cdecl;
  external libc name _PU + 'close';

function RouteLocalIP(out AIP: Cardinal): Boolean;
var
  S: Integer;
  Remote, Local: array[0..15] of Byte;
  Len: Cardinal;
begin
  Result := False;
  AIP := 0;
  S := sock_socket(2 {AF_INET}, 2 {SOCK_DGRAM}, 0);
  if S < 0 then
    Exit;
  try
    FillChar(Remote, SizeOf(Remote), 0);
{$IFDEF MACOS}
    Remote[0] := 16;                           // sin_len
    Remote[1] := 2;                            // AF_INET
{$ELSE}
    PWord(@Remote[0])^ := 2;                   // AF_INET
{$ENDIF}
    Remote[3] := 53;                           // port 53, big-endian
    Remote[4] := 8; Remote[5] := 8; Remote[6] := 8; Remote[7] := 8;
    if sock_connect(S, @Remote[0], SizeOf(Remote)) <> 0 then
      Exit;
    FillChar(Local, SizeOf(Local), 0);
    Len := SizeOf(Local);
    if sock_getsockname(S, @Local[0], Len) <> 0 then
      Exit;
    AIP := (Cardinal(Local[4]) shl 24) or (Cardinal(Local[5]) shl 16) or
           (Cardinal(Local[6]) shl 8) or Cardinal(Local[7]);
    Result := AIP <> 0;
  finally
    sock_close(S);
  end;
end;
{$ENDIF}

function TapoLocalNetwork(out ANetwork, AMask: string): Boolean;
var
  All: TArray<TLocalAddress>;
  Best: TLocalAddress;
  BestScore, Score, I: Integer;
  RouteIP, Mask: Cardinal;
begin
  ANetwork := '192.168.0.0';
  AMask := '255.255.255.0';
  Result := False;
  try
    All := LocalAddresses;
  except
    All := nil;          // no interface list
  end;

  // 1. The address the system routes through, with its own adapter's mask.
  try
    if RouteLocalIP(RouteIP) and (PrivateRank(RouteIP) > 0) then
    begin
      Mask := $FFFFFF00;                       // if the adapter is not listed
      for I := 0 to High(All) do
        if (All[I].IP = RouteIP) and (All[I].Mask <> 0) then
        begin
          Mask := All[I].Mask;
          Break;
        end;
      ANetwork := IPv4Text(RouteIP and Mask);
      AMask := IPv4Text(Mask);
      Exit(True);
    end;
  except
    // no route (offline): fall back to the adapter list
  end;

  // 2. Otherwise the best-looking private address of the adapters.
  BestScore := MaxInt;
  for I := 0 to High(All) do
  begin
    Score := PrivateRank(All[I].IP);
    if (Score = 0) or (All[I].Mask = 0) then
      Continue;
    if IsVirtualName(All[I].Name) then
      Inc(Score, 10);    // only if nothing better
    if Score < BestScore then
    begin
      BestScore := Score;
      Best := All[I];
    end;
  end;

  if BestScore < MaxInt then
  begin
    ANetwork := IPv4Text(Best.IP and Best.Mask);
    AMask := IPv4Text(Best.Mask);
    Result := True;
  end;
end;

initialization
  StoreLock := TCriticalSection.Create;

finalization
  StoreLock.Free;

end.
