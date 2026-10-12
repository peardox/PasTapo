//** @abstract(Read-only test of the Tapo units against a known working plug.)
//**
//** Enter the plug's IP address and your Tapo account e-mail and password, then press "Run test".
//** Nothing on the plug is changed: it is only read.
//**
//** @preformatted(
//** The test:
//**   1. runs the crypto self-test @(no network@);
//**   2. finds out what is at the address @(TryAddDetected@) and logs in;
//**   3. reads plug info, current power, energy usage, device usage and timer;
//**   4. reads energy usage again, to show the session is reused @(no new login@).
//** )
//**
//** Pressing the button again uses the same client, so step 2 then reports the device as already
//** registered.
unit TapoTestForm;

{
  Read-only test of the Tapo units against a known working plug.

  Enter the plug's IP address and your Tapo account e-mail and password,
  then press "Run test". Nothing on the plug is changed: it is only read.

  The test:
    1. runs the crypto self-test (no network);
    2. finds out what is at the address (TryAddDetected) and logs in;
    3. reads plug info, current power, energy usage, device usage and timer;
    4. reads energy usage again, to show the session is reused (no new login).

  Pressing the button again uses the same client, so step 2 then reports the
  device as already registered.
}

interface

uses
  System.SysUtils, System.StrUtils, System.Types, System.UITypes, System.Classes, System.Diagnostics,
  System.Threading, FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Memo, FMX.Layouts, FMX.Controls.Presentation, FMX.ScrollBox,
  Tapo.Client, Tapo.Models, Tapo.Devices;

type
  TTapoTestForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FHostEdit, FUserEdit, FPasswordEdit: TEdit;
    FRunButton: TButton;
    FMemo: TMemo;
    FClient: TTapoClient;
    FPassword: string;
    procedure RunClick(Sender: TObject);
    procedure RunTest(const AHost: string);
    procedure Log(const S: string);
    procedure Done;
  end;

var
  TapoTestForm1: TTapoTestForm;

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

function ProtocolName(P: TTapoProtocol): string;
begin
  case P of
    tpKlap:   Result := 'KLAP';
    tpTpap:   Result := 'TPAP';
    tpAesSsl: Result := 'AES SSL';
  else
    Result := 'not logged in';
  end;
end;

function YesNo(B: Boolean): string;
begin
  if B then
    Result := 'yes'
  else
    Result := 'no';
end;

procedure TTapoTestForm.FormCreate(Sender: TObject);
var
  Bar: TLayout;

  function AddEdit(const APrompt: string; AWidth: Single): TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := Bar;
    Result.Align := TAlignLayout.Left;
    Result.Width := AWidth;
    Result.Margins.Rect := TRectF.Create(4, 4, 4, 4);
    Result.TextPrompt := APrompt;
  end;

begin
  Caption := 'Tapo test';
  Width := 820;
  Height := 560;

  Bar := TLayout.Create(Self);
  Bar.Parent := Self;
  Bar.Align := TAlignLayout.Top;
  Bar.Height := 40;

  FHostEdit := AddEdit('Plug IP address', 150);
  FUserEdit := AddEdit('Tapo account e-mail', 220);
  FPasswordEdit := AddEdit('Tapo account password', 180);
  FPasswordEdit.Password := True;

  FRunButton := TButton.Create(Self);
  FRunButton.Parent := Bar;
  FRunButton.Align := TAlignLayout.Left;
  FRunButton.Width := 100;
  FRunButton.Margins.Rect := TRectF.Create(4, 4, 4, 4);
  FRunButton.Text := 'Run test';
  FRunButton.OnClick := RunClick;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := TAlignLayout.Client;
  FMemo.Margins.Rect := TRectF.Create(4, 0, 4, 4);
  FMemo.ReadOnly := True;
  FMemo.TextSettings.Font.Family := MonoFontFamily;
end;

procedure TTapoTestForm.FormDestroy(Sender: TObject);
begin
  FClient.Free;   // frees the devices too
end;

procedure TTapoTestForm.Log(const S: string);
var
  Line: string;
begin
  Line := FormatDateTime('hh:nn:ss.zzz  ', Now) + S;
  TThread.Queue(nil,
    procedure
    begin
      FMemo.Lines.Add(Line);
      FMemo.GoToTextEnd;
    end);
end;

procedure TTapoTestForm.Done;
begin
  TThread.Queue(nil,
    procedure
    begin
      FRunButton.Enabled := True;
    end);
end;

procedure TTapoTestForm.RunClick(Sender: TObject);
var
  Host: string;
begin
  Host := Trim(FHostEdit.Text);
  if (Host = '') or (FUserEdit.Text = '') or (FPasswordEdit.Text = '') then
  begin
    FMemo.Lines.Add('Enter the IP address, e-mail and password first.');
    Exit;
  end;

  // one client for the life of the form; credentials given once
  if FClient = nil then
  begin
    FClient := TTapoClient.Create(Trim(FUserEdit.Text), FPasswordEdit.Text);
    FClient.ConnectionTimeout := 3000;
    FClient.ResponseTimeout := 10000;
  end
  else if (FClient.Username <> Trim(FUserEdit.Text)) or (FPassword <> FPasswordEdit.Text) then
    FClient.SetCredentials(Trim(FUserEdit.Text), FPasswordEdit.Text);
  FPassword := FPasswordEdit.Text;

  FRunButton.Enabled := False;
  FMemo.Lines.Add('');
  FMemo.Lines.Add('==== Test of ' + Host + ' ====');
  TTask.Run(
    procedure
    begin
      try
        try
          RunTest(Host);
        except
          on E: ETapoError do
            Log(Format('FAILED: %s: %s (code %d)', [E.ClassName, E.Message, E.ErrorCode]));
          on E: Exception do
            Log(Format('FAILED: %s: %s', [E.ClassName, E.Message]));
        end;
      finally
        Done;
      end;
    end);
end;

// Runs on a background thread; only Log touches the UI.
procedure TTapoTestForm.RunTest(const AHost: string);
var
  Report, Err: string;
  Dev: TTapoDevice;
  Plug: TTapoPlug;
  P110: TTapoP110;
  Detection: TTapoDetection;
  PlugInfo: TTapoPlugInfo;
  Energy: TTapoEnergyUsage;
  Usage: TTapoDeviceUsage;
  Timer: TTapoTimer;
  SW: TStopwatch;
begin
  // 1. Crypto self-test (no network)
  SW := TStopwatch.StartNew;
  if TTapoClient.SelfTest(Report) then
    Log(Format('1. Crypto self-test passed (%d ms)', [SW.ElapsedMilliseconds]))
  else
  begin
    Log('1. Crypto self-test FAILED:' + sLineBreak + Report);
    Exit;
  end;

  // 2. Detect and log in
  SW := TStopwatch.StartNew;
  if not FClient.TryAddDetected(AHost, Dev, Err) then
  begin
    Log('2. Detection failed: ' + Err);
    Exit;
  end;
  Log(Format('2. Detected in %d ms', [SW.ElapsedMilliseconds]));
  // details of what was found (the device is already registered, so this
  // returns it without logging in again)
  FClient.AddDetected(AHost, Detection);
  Log(Format('   class:     %s (matched by %s)', [Dev.ClassName, Detection.MatchedBy]));
  Log(Format('   model:     %s   type: %s', [Detection.Model, Detection.DeviceType]));
  Log(Format('   nickname:  %s', [Detection.Nickname]));
  Log(Format('   firmware:  %s   hardware: %s', [Detection.Info.FirmwareVersion,
    Detection.Info.HardwareVersion]));
  Log(Format('   protocol:  %s   logged in: %s', [ProtocolName(Dev.ActiveProtocol),
    YesNo(Dev.LoggedIn)]));

  if not (Dev is TTapoPlug) then
  begin
    Log('   This is not a plug, so the plug tests are skipped.');
    Exit;
  end;
  Plug := TTapoPlug(Dev);

  // 3. Read-only plug calls
  SW := TStopwatch.StartNew;
  PlugInfo := Plug.GetPlugInfo;
  Log(Format('3. Plug info (%d ms): on=%s  on for %d s  default=%s  overheat=%s',
    [SW.ElapsedMilliseconds, YesNo(PlugInfo.DeviceOn), PlugInfo.OnTime,
     PlugInfo.DefaultStateType, PlugInfo.OverheatStatus]));

  if Plug is TTapoP110 then
  begin
    P110 := TTapoP110(Plug);

    SW := TStopwatch.StartNew;
    Log(Format('   Current power (%d ms): %.1f W', [SW.ElapsedMilliseconds,
      P110.GetCurrentPower]));

    SW := TStopwatch.StartNew;
    Energy := P110.GetEnergyUsage;
    Log(Format('   Energy usage (%d ms): now %.1f W, today %.3f kWh (%d min), ' +
      'month %.3f kWh (%d min), device time %s',
      [SW.ElapsedMilliseconds, Energy.CurrentPowerW, Energy.TodayEnergyKWh,
       Energy.TodayRuntimeMin, Energy.MonthEnergyKWh, Energy.MonthRuntimeMin,
       Energy.LocalTime]));
  end
  else
    Log('   Not an energy-monitoring plug, so the energy tests are skipped.');

  SW := TStopwatch.StartNew;
  Usage := Plug.GetDeviceUsage;
  Log(Format('   Device usage (%d ms): on today %d min, 7 days %d min, 30 days %d min',
    [SW.ElapsedMilliseconds, Usage.TimeUsage.Today, Usage.TimeUsage.Past7Days,
     Usage.TimeUsage.Past30Days]));

  SW := TStopwatch.StartNew;
  if Plug.GetTimer(Timer) then
    Log(Format('   Timer (%d ms): %d s left, then switches %s', [SW.ElapsedMilliseconds,
      Timer.RemainingSeconds, IfThen(Timer.DesiredOn, 'on', 'off')]))
  else
    Log(Format('   Timer (%d ms): none set', [SW.ElapsedMilliseconds]));

  // 4. Session reuse: this should be as quick as the calls above (no login)
  if Plug is TTapoP110 then
  begin
    SW := TStopwatch.StartNew;
    Energy := TTapoP110(Plug).GetEnergyUsage;
    Log(Format('4. Energy usage again (%d ms, same session): %.1f W', [SW.ElapsedMilliseconds,
      Energy.CurrentPowerW]));
  end;

  Log('All tests passed.');
end;

end.
