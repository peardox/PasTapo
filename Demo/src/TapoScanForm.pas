//** @abstract(Network-scan demo for Tapo.Discovery, with state kept between sessions
//** @(Tapo.Settings: settings.json and devices.json, written with Neon@).)
//**
//** @preformatted(
//** Start-up:
//**   - no settings.json, details incomplete, or the account was rejected last
//**     session: the account form opens @(TapoSettingsForm@);
//**   - devices.json is loaded into the client and each device gets a quick
//**     check: does it answer, and is it still the same device?
//** Scan @(only when the button is pressed@):
//**   1. ARP stage @(or TCP sweep where the ARP table is hidden@) finds candidates;
//**   2. probe stage logs in to each; Tapo devices are added to the client.
//**   A scan that finds a Tapo device marks the account good and adds what it
//**   found to devices.json; one where Tapo devices only reject the account
//**   marks it bad, so the form opens at the next start.
//** Settings > Account and network... changes the details at any time.
//** )
//**
//** "Read devices" reads every device the client holds, using the existing logins. Nothing on any
//** device is changed. Needs NetMacScan.pas from https://github.com/peardox/NetScan and the Neon
//** units (https://github.com/paolo-rossi/delphi-neon) on the search path.
unit TapoScanForm;

{
  Network-scan demo for Tapo.Discovery, with state kept between sessions
  (Tapo.Settings: settings.json and devices.json, written with Neon).

  Start-up:
    - no settings.json, details incomplete, or the account was rejected last
      session: the account form opens (TapoSettingsForm);
    - devices.json is loaded into the client and each device gets a quick
      check: does it answer, and is it still the same device?
  Scan (only when the button is pressed):
    1. ARP stage (or TCP sweep where the ARP table is hidden) finds candidates;
    2. probe stage logs in to each; Tapo devices are added to the client.
    A scan that finds a Tapo device marks the account good and adds what it
    found to devices.json; one where Tapo devices only reject the account
    marks it bad, so the form opens at the next start.
  Settings > Account and network... changes the details at any time.

  "Read devices" reads every device the client holds, using the existing
  logins. Nothing on any device is changed. Needs NetMacScan.pas from
  https://github.com/peardox/NetScan and the Neon units
  (https://github.com/paolo-rossi/delphi-neon) on the search path.
}

interface

uses
  System.SysUtils, System.StrUtils, System.Math, System.Types, System.UITypes,
  System.Classes, System.Threading, System.SyncObjs,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit, FMX.Memo,
  FMX.Layouts, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Menus,
  NetMacScan, Tapo.Client, Tapo.Models, Tapo.Devices, Tapo.Discovery,
  Tapo.Settings, TapoSettingsForm;

type
  TTapoScanMainForm = class(TForm)
    // designed in TapoScanForm.fmx
    MainMenu: TMainMenu;
    SettingsMenu: TMenuItem;
    AccountItem: TMenuItem;
    ShowFolderItem: TMenuItem;
    ResetCredentialsItem: TMenuItem;
    ButtonBar: TLayout;
    ScanButton: TButton;
    CancelButton: TButton;
    ReadButton: TButton;
    DiagButton: TButton;
    ProgressBar: TProgressBar;
    StatusLabel: TLabel;
    LogMemo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure SettingsClick(Sender: TObject);
    procedure ShowFolderClick(Sender: TObject);
    procedure ResetCredentialsClick(Sender: TObject);
    procedure ScanClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure ReadClick(Sender: TObject);
    procedure DiagnoseClick(Sender: TObject);
  private
    FClient: TTapoClient;
    FScanner: TTapoScanner;
    FSettings: TTapoSettings;
    FStore: TTapoDeviceStore;
    FLoaded: TArray<TTapoDevice>;   // devices.json entries, by store index
    FCheckTask: ITask;
    FClosing: Boolean;
    FResetOnExit: Boolean;          // Settings > Reset Credentials
    FStarted: Boolean;              // start-up has run
    function SettingsNote: string;
    procedure StartUp;
    function AskSettings(const ANote: string): Boolean;
    procedure ApplySettings;
    procedure SaveSettings;
    procedure LoadStoredDevices;
    procedure CheckStoredDevices;
    procedure LogCheck(AIndex: Integer; AStatus: TTapoCheckStatus; const AMsg: string);
    procedure ChecksDone(AOk, ABadLogin, AUnreachable, AOther: Integer);
    procedure UpdateStatus;
    procedure ScanProgress(Sender: TObject; AStage: TTapoScanStage;
      ADone, ATotal, AFound: Integer);
    procedure DeviceFound(Sender: TObject; const AEntry: TTapoScanEntry);
    procedure ScanDone(const AResult: TTapoScanResult; const AError: string);
    procedure Log(const S: string);
    procedure SetRunning(ARunning: Boolean);
    procedure QueueStopped;
    procedure LogPowerStrip(AStrip: TTapoPowerStrip);
  end;

var
  TapoScanMainForm: TTapoScanMainForm;

implementation

{$R *.fmx}

// A monospaced font that exists on each desktop platform.
function MonoFontFamily: string;
begin
{$IF Defined(MSWINDOWS)}
  Result := 'Consolas';
{$ELSEIF Defined(MACOS)}
  Result := 'Menlo';
{$ELSE}
  Result := 'Monospace';     // fontconfig alias, present on every Linux desktop
{$ENDIF}
end;

procedure TTapoScanMainForm.FormCreate(Sender: TObject);
begin
  // The controls come from TapoScanForm.fmx. Set here: what depends on the
  // platform, and the state while start-up runs.
  LogMemo.TextSettings.Font.Family := MonoFontFamily;

  FSettings := TTapoSettings.Create;
  FStore := TTapoDeviceStore.Create;
  SetRunning(True);              // until start-up is done
  CancelButton.Enabled := False;
  // start-up runs once the main form is on screen (FormShow, wired in the
  // .fmx), so the account form opens in front of it
end;

procedure TTapoScanMainForm.FormShow(Sender: TObject);
begin
  if FStarted then
    Exit;
  FStarted := True;
  // queued: OnShow fires before the window is fully shown and active
  TThread.ForceQueue(nil, StartUp);
end;

procedure TTapoScanMainForm.FormDestroy(Sender: TObject);
begin
  FClosing := True;
  if FCheckTask <> nil then
    FCheckTask.Wait;   // the start-up check uses the client and the store

  // Settings > Reset Credentials: forget the account, keep network and devices
  if FResetOnExit and TTapoSettings.Exists then
    try
      FSettings.Username := '';
      FSettings.Password := '';
      FSettings.CameraUsername := '';
      FSettings.CameraPassword := '';
      FSettings.CredentialState := csUnknown;
      FSettings.Save;
    except
      // closing: nowhere left to report it
    end;

  FScanner.Free;       // waits for a probe stage under way to stop
  FClient.Free;        // frees the devices too
  FStore.Free;
  FSettings.Free;
end;

procedure TTapoScanMainForm.ResetCredentialsClick(Sender: TObject);
begin
  FResetOnExit := not FResetOnExit;
  ResetCredentialsItem.IsChecked := FResetOnExit;
  if FResetOnExit then
    Log('The Tapo account and camera account details will be deleted when the app closes ' +
      '(choose Reset Credentials again to cancel).')
  else
    Log('Reset Credentials cancelled: the account details will be kept.');
end;

{ --- start-up and settings -------------------------------------------------- }

// Why the account form is needed, or '' if the saved details are complete
// and were not rejected. Missing details are not called wrong.
function TTapoScanMainForm.SettingsNote: string;
const
  NeedDetails = 'To locate and talk to your Tapo devices, this app needs the e-mail ' +
    'and password of your Tapo account, and the network your devices are on.';
begin
  if not FSettings.HasLogin then
    Result := NeedDetails
  else if FSettings.CredentialState = csBad then
    Result := 'Tapo devices rejected this account the last time it was used. ' +
      'Check the e-mail and password.'
  else if not FSettings.HasValidNetwork then
    Result := 'The saved network or subnet mask is not a usable address range. ' +
      'Check them, or press Detect network.'
  else
    Result := '';
end;

procedure TTapoScanMainForm.StartUp;
var
  Note: string;
begin
  Log('Data folder: ' + TapoDataFolder);

  FSettings.Load;            // first run: nothing to load, the fields stay empty
  Note := SettingsNote;

  if Note <> '' then
    AskSettings(Note);

  if not FSettings.HasLogin then
  begin
    Log('No Tapo account yet: use Settings > Account and network.');
    SetRunning(False);
    ScanButton.Enabled := False;
    ReadButton.Enabled := False;
    UpdateStatus;
    Exit;
  end;

  ApplySettings;
  LoadStoredDevices;        // starts the quick check, or re-enables the buttons
end;

// Shows the account form; on OK saves settings.json and applies the details.
function TTapoScanMainForm.AskSettings(const ANote: string): Boolean;
begin
  Result := TTapoSettingsDialog.Execute(Self, FSettings, ANote);
  if Result then
  begin
    SaveSettings;
    if FClient <> nil then
      ApplySettings;
  end;
end;

// Creates the client and scanner, or gives an existing client new details.
procedure TTapoScanMainForm.ApplySettings;
begin
  if FClient = nil then
  begin
    // the client uses the settings object as its account: changes made in
    // the settings dialog reach it, and every device, with nothing to copy
    FClient := TTapoClient.Create(FSettings);
    FClient.ConnectionTimeout := 3000;
    FClient.ResponseTimeout := 10000;
    FScanner := TTapoScanner.Create(FClient);
    FScanner.OnProgress := ScanProgress;
    FScanner.OnDeviceFound := DeviceFound;
  end;
  // a new e-mail or password needs nothing here: each device sees the
  // account's new login revision and logs in again on its next request
  UpdateStatus;
end;

procedure TTapoScanMainForm.SaveSettings;
begin
  try
    FSettings.Save;
  except
    on E: Exception do
      Log('Could not save settings.json: ' + E.Message);
  end;
end;

procedure TTapoScanMainForm.UpdateStatus;
const
  StateText: array[TTapoCredentialState] of string = ('not tried yet', 'good', 'rejected');
begin
  StatusLabel.Text := Format('Network %s / %s - account %s - %d device(s) stored',
    [FSettings.Network, FSettings.Subnet, StateText[FSettings.CredentialState],
     Length(FStore.Devices)]);
end;

procedure TTapoScanMainForm.SettingsClick(Sender: TObject);
begin
  if (FScanner <> nil) and FScanner.Busy then
  begin
    Log('Wait for the scan to finish before changing the settings.');
    Exit;
  end;
  if AskSettings('') and (FClient = nil) and FSettings.HasLogin then
  begin
    // the first details of this session
    ApplySettings;
    LoadStoredDevices;
  end;
end;

procedure TTapoScanMainForm.ShowFolderClick(Sender: TObject);
begin
  Log('Data folder: ' + TapoDataFolder);
  Log('  ' + TTapoSettings.FileName + IfThen(TTapoSettings.Exists, '', ' (not written yet)'));
  Log('  ' + TTapoDeviceStore.FileName + IfThen(TTapoDeviceStore.Exists, '', ' (not written yet)'));
end;

{ --- stored devices -------------------------------------------------------- }

procedure TTapoScanMainForm.LoadStoredDevices;
var
  Skipped: TArray<string>;
  S: string;
begin
  if not FStore.Load or (Length(FStore.Devices) = 0) then
  begin
    Log('No stored devices yet: press Scan to find them.');
    SetRunning(False);
    UpdateStatus;
    Exit;
  end;

  FLoaded := FStore.AddToClient(FClient, Skipped);
  for S in Skipped do
    Log('  not loaded: ' + S);
  UpdateStatus;
  CheckStoredDevices;
end;

// The quick start-up check: is each stored device still there, and still the
// same device? A few devices at a time, off the UI thread.
procedure TTapoScanMainForm.CheckStoredDevices;
var
  Work: TProc;
  Count: Integer;
begin
  Count := Length(FStore.Devices);
  LogMemo.Lines.Add('');
  Log(Format('==== Checking %d stored device(s) ====', [Count]));
  SetRunning(True);
  CancelButton.Enabled := False;

  Work :=
    procedure
    var
      Ok, BadLogin, Unreachable, Other: Integer;
      Retry: TArray<Integer>;
      RetryLock: TObject;
      Body: TProc<Integer>;
      Finish: TThreadProcedure;
      Tally: TProc<TTapoCheckStatus>;
      I: Integer;
      Status: TTapoCheckStatus;
      Msg: string;
    begin
      Tally :=
        procedure(AStatus: TTapoCheckStatus)
        begin
          case AStatus of
            tcsOk: TInterlocked.Increment(Ok);
            tcsBadCredentials: TInterlocked.Increment(BadLogin);
            tcsUnreachable: TInterlocked.Increment(Unreachable);
          else
            TInterlocked.Increment(Other);
          end;
        end;
      Ok := 0;
      BadLogin := 0;
      Unreachable := 0;
      Other := 0;
      Retry := nil;
      RetryLock := TObject.Create;
      try
        Body :=
          procedure(AIndex: Integer)
          var
            Status: TTapoCheckStatus;
            Msg: string;
          begin
            if FClosing then
              Exit;
            Status := FStore.CheckDevice(AIndex, FLoaded[AIndex], Msg);
            if Status = tcsUnreachable then
            begin
              // bulbs in particular drop connections when many devices are
              // checked at once: try again below, one at a time
              TMonitor.Enter(RetryLock);
              try
                Retry := Retry + [AIndex];
              finally
                TMonitor.Exit(RetryLock);
              end;
              Exit;
            end;
            Tally(Status);
            LogCheck(AIndex, Status, Msg);
          end;
        try
          TParallel.For(0, Count - 1, Body);
        except
          on E: Exception do
            Log('Check failed: ' + E.Message);
        end;
      finally
        RetryLock.Free;
      end;

      // second chance, one device at a time, on a fresh connection
      for I in Retry do
      begin
        if FClosing then
          Break;
        FLoaded[I].Logout;           // log in again from scratch
        Sleep(500);
        Status := FStore.CheckDevice(I, FLoaded[I], Msg);
        Tally(Status);
        LogCheck(I, Status, Msg);
      end;

      Finish :=
        procedure
        begin
          if not FClosing then
            ChecksDone(Ok, BadLogin, Unreachable, Other);
        end;
      TThread.Queue(nil, Finish);
    end;
  FCheckTask := TTask.Run(Work);
end;

// One line of the stored-device check (any thread: Log queues).
procedure TTapoScanMainForm.LogCheck(AIndex: Integer; AStatus: TTapoCheckStatus; const AMsg: string);
var
  D: TTapoStoredDevice;
begin
  D := FStore.Devices[AIndex];
  Log(Format('  %-17s %-15s %-10s %-20s %s', [TapoCheckStatusName(AStatus),
    D.Host, D.Model, '"' + D.Nickname + '"', IfThen(AStatus = tcsOk, '', AMsg)]));
end;

procedure TTapoScanMainForm.ChecksDone(AOk, ABadLogin, AUnreachable, AOther: Integer);
begin
  FCheckTask := nil;
  SetRunning(False);
  Log(Format('Check done: %d ok, %d rejected the account, %d did not answer, ' +
    '%d not as stored.', [AOk, ABadLogin, AUnreachable, AOther]));
  if AUnreachable > 0 then
    Log('  A device that did not answer may be switched off (a bulb at the wall switch) or ' +
      'have a new address; Scan finds it again when it is back.');
  try
    FStore.Save;              // last-seen times and check results
  except
    on E: Exception do
      Log('Could not save devices.json: ' + E.Message);
  end;

  if AOk > 0 then
  begin
    if FSettings.CredentialState <> csGood then
    begin
      FSettings.MarkCredentials(csGood);
      SaveSettings;
    end;
  end
  else if ABadLogin > 0 then
  begin
    // devices answered but none took the account: ask now
    FSettings.MarkCredentials(csBad);
    SaveSettings;
    AskSettings('Your devices rejected this Tapo account. Check the e-mail and password.');
  end;
  UpdateStatus;
end;

procedure TTapoScanMainForm.Log(const S: string);
var
  Line: string;
  Proc: TThreadProcedure;
begin
  Line := FormatDateTime('hh:nn:ss  ', Now) + S;
  Proc :=
    procedure
    begin
      LogMemo.Lines.Add(Line);
      LogMemo.GoToTextEnd;
    end;
  TThread.Queue(nil, Proc);
end;

procedure TTapoScanMainForm.SetRunning(ARunning: Boolean);
begin
  ScanButton.Enabled := not ARunning;
  ReadButton.Enabled := not ARunning;
  CancelButton.Enabled := ARunning;
end;

// Re-enables the buttons from a background thread.
procedure TTapoScanMainForm.QueueStopped;
var
  Proc: TThreadProcedure;
begin
  Proc :=
    procedure
    begin
      SetRunning(False);
    end;
  TThread.Queue(nil, Proc);
end;

procedure TTapoScanMainForm.ScanClick(Sender: TObject);
begin
  // invalid or missing details: collect them first
  if not FSettings.HasLogin or not FSettings.HasValidNetwork then
  begin
    if not AskSettings(SettingsNote) then
      Exit;
    if FClient = nil then
      ApplySettings;
  end;

  LogMemo.Lines.Add('');
  Log(Format('==== Scan of %s %s ====', [FSettings.Network, FSettings.Subnet]));
  ProgressBar.Value := 0;
  SetRunning(True);
  try
    FScanner.ScanAsync(FSettings.Network, FSettings.Subnet, ScanDone);
  except
    SetRunning(False);
    raise;
  end;
end;

// Network diagnostics for the ARP and sweep stages, on a background thread.
procedure TTapoScanMainForm.DiagnoseClick(Sender: TObject);
var
  Work: TProc;
begin
  LogMemo.Lines.Add('');
  Log('==== Scan diagnostics ====');
  SetRunning(True);
  CancelButton.Enabled := False;
  // a few seconds of network checks, so off the UI thread
  Work :=
    procedure
    var
      Report: string;
    begin
      try
        Report := MacScanDiagnostics;
      except
        on E: Exception do
          Report := E.ClassName + ': ' + E.Message;
      end;
      Log(sLineBreak + Report);
      QueueStopped;
    end;
  TTask.Run(Work);
end;

procedure TTapoScanMainForm.CancelClick(Sender: TObject);
begin
  if FScanner <> nil then
  begin
    FScanner.Cancel;
    StatusLabel.Text := 'Cancelling...';
  end;
end;

procedure TTapoScanMainForm.ScanProgress(Sender: TObject; AStage: TTapoScanStage;
  ADone, ATotal, AFound: Integer);
begin
  ProgressBar.Max := Max(ATotal, 1);
  ProgressBar.Value := ADone;
  case AStage of
    tsgArp:
      StatusLabel.Text := Format('ARP: checked %d of %d addresses - %d candidate(s)',
        [ADone, ATotal, AFound]);
    tsgSweep:
      StatusLabel.Text := Format('TCP sweep: checked %d of %d addresses - %d candidate(s)',
        [ADone, ATotal, AFound]);
    tsgProbe:
      StatusLabel.Text := Format('Probing: %d of %d candidates - %d Tapo device(s)',
        [ADone, ATotal, AFound]);
  end;
end;

procedure TTapoScanMainForm.DeviceFound(Sender: TObject; const AEntry: TTapoScanEntry);
begin
  if AEntry.Status = tssAdded then
    Log(Format('  found %-15s %-10s %-14s "%s" (%s)', [AEntry.IP, AEntry.Model,
      AEntry.Device.ClassName, AEntry.Nickname, AEntry.MAC]))
  else
    Log(Format('  known %-15s %-25s (%s)', [AEntry.IP, AEntry.Device.ClassName, AEntry.MAC]));
end;

procedure TTapoScanMainForm.ScanDone(const AResult: TTapoScanResult; const AError: string);
var
  E: TTapoScanEntry;
  Tapo, BadLogin, Added: Integer;
begin
  SetRunning(False);
  if FScanner.LastArpError <> '' then
    Log('ARP table unavailable, so a TCP sweep found the candidates instead. ' +
      'ARP error: ' + FScanner.LastArpError);
  if AError <> '' then
    Log('Scan ended: ' + AError);

  Tapo := 0;
  Log('Candidates:');
  for E in AResult do
  begin
    if E.IsTapo then
      Inc(Tapo);
    if E.IsTapo then
      Log(Format('  %-15s %-17s %s: %s', [E.IP, E.MAC, TapoScanStatusName(E.Status),
        E.Device.ClassName]))
    else
      Log(Format('  %-15s %-17s %s  %s', [E.IP, E.MAC, TapoScanStatusName(E.Status), E.Error]));
  end;
  StatusLabel.Text := Format('Done - %d candidate(s), %d Tapo device(s); the client now holds %d',
    [Length(AResult), Tapo, FClient.Count]);

  // what the scan says about the account
  BadLogin := 0;
  for E in AResult do
    if E.Status = tssBadCredentials then
      Inc(BadLogin);

  if Tapo > 0 then
  begin
    if FSettings.CredentialState <> csGood then
    begin
      FSettings.MarkCredentials(csGood);
      SaveSettings;
    end;
    // scans only add: devices not found this time stay in the file
    Added := FStore.Merge(AResult);
    try
      FStore.Save;
      Log(Format('devices.json: %d new, %d stored in all.', [Added, Length(FStore.Devices)]));
    except
      on Ex: Exception do
        Log('Could not save devices.json: ' + Ex.Message);
    end;
  end
  else if BadLogin > 0 then
  begin
    FSettings.MarkCredentials(csBad);
    SaveSettings;
    Log('Tapo devices rejected the account, and none accepted it. The account form ' +
      'will open at the next start; use Settings > Account and network to fix it now.');
  end
  else
    Log('No Tapo device answered, so the account could not be checked.');
  UpdateStatus;
end;

function DurationText(ASeconds: Int64): string;
begin
  if ASeconds <= 0 then
    Result := '-'
  else if ASeconds < 3600 then
    Result := Format('%dm%.2ds', [ASeconds div 60, ASeconds mod 60])
  else if ASeconds < 86400 then
    Result := Format('%dh%.2dm', [ASeconds div 3600, (ASeconds mod 3600) div 60])
  else
    Result := Format('%dd%.2dh', [ASeconds div 86400, (ASeconds mod 86400) div 3600]);
end;

// Runs on a background thread; only Log touches the UI.
procedure TTapoScanMainForm.LogPowerStrip(AStrip: TTapoPowerStrip);
var
  Infos: TArray<TTapoOutletInfo>;
  O: TTapoOutletInfo;
  Outlet: TTapoEnergyOutlet;
  Energy: TTapoEnergyUsage;
  Line, Flags: string;
begin
  Infos := AStrip.GetChildDeviceList;      // one request for all outlets
  Log(Format('    %d outlet(s):', [Length(Infos)]));
  for O in Infos do
  begin
    Line := Format('    #%d %-22s %-3s  on for %-7s', [O.Position,
      '"' + O.Nickname + '"', IfThen(O.DeviceOn, 'on', 'off'), DurationText(O.OnTime)]);
    if O.AutoOffStatus = 'on' then
      Line := Line + '  auto-off in ' + DurationText(O.AutoOffRemainTime);
    if O.IsUsb then
      Line := Line + '  USB';

    // anything other than 'normal' is worth seeing
    Flags := '';
    if (O.OvercurrentStatus <> '') and (O.OvercurrentStatus <> 'normal') then
      Flags := Flags + ' overcurrent=' + O.OvercurrentStatus;
    if (O.OverheatStatus <> '') and (O.OverheatStatus <> 'normal') then
      Flags := Flags + ' overheat=' + O.OverheatStatus;
    if (O.PowerProtectionStatus <> '') and (O.PowerProtectionStatus <> 'normal') then
      Flags := Flags + ' protection=' + O.PowerProtectionStatus;
    if Flags <> '' then
      Line := Line + '  !' + Flags;

    // P304M / P316M outlets measure energy
    if AStrip is TTapoP304M then
      try
        Outlet := TTapoP304M(AStrip).OutletById(O.DeviceId);
        Energy := Outlet.GetEnergyUsage;
        Line := Line + Format('  %.1f W, today %.3f kWh, month %.3f kWh',
          [Outlet.GetCurrentPower, Energy.TodayEnergyKWh, Energy.MonthEnergyKWh]);
      except
        on E: Exception do
          Line := Line + '  energy: ' + E.Message;
      end;
    Log(Line);
    Log(Format('       model %s, firmware %s, hardware %s, id %s',
      [O.Model, O.FirmwareVersion, O.HardwareVersion, O.DeviceId]));
  end;
end;

procedure TTapoScanMainForm.ReadClick(Sender: TObject);
var
  Devices: TArray<TTapoDevice>;
  I: Integer;
  Work: TProc;
begin
  if (FClient = nil) or (FClient.Count = 0) then
  begin
    Log('No devices yet - press Scan first.');
    Exit;
  end;

  // snapshot on the main thread; the devices belong to the client
  SetLength(Devices, FClient.Count);
  for I := 0 to High(Devices) do
    Devices[I] := FClient.Devices[I];

  LogMemo.Lines.Add('');
  Log(Format('==== Reading %d device(s) ====', [Length(Devices)]));
  SetRunning(True);
  CancelButton.Enabled := False;
  Work :=
    procedure
    var
      D: TTapoDevice;
      Info: TTapoDeviceInfo;
      Line: string;
    begin
      try
        for D in Devices do
          try
            Info := D.GetDeviceInfo;   // reuses the scan's login
            Line := Format('%-15s %-10s "%s"', [D.Host, Info.Model, Info.Nickname]);
            if Info.HasDeviceOn then
              Line := Line + IfThen(Info.DeviceOn, '  on', '  off');
            if D is TTapoP110 then
              Line := Line + Format('  %.1f W', [TTapoP110(D).GetCurrentPower]);
            Log(Line);
            // a power strip has no state of its own: show its outlets
            if D is TTapoPowerStrip then
              LogPowerStrip(TTapoPowerStrip(D));
          except
            on E: Exception do
              Log(Format('%-15s FAILED: %s: %s', [D.Host, E.ClassName, E.Message]));
          end;
      finally
        QueueStopped;
      end;
    end;
  TTask.Run(Work);
end;

end.
