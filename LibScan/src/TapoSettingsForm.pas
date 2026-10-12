unit TapoSettingsForm;

{
  The Tapo account and network form. Built in code, so it has no .fmx file:
  call TTapoSettingsForm.Execute.

  Order, top to bottom: e-mail (user name), password, network, subnet.
  An empty network or subnet is filled in from this computer's LAN, or
  192.168.0.0 / 255.255.255.0 if it is not on one.
}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Edit,
  FMX.Layouts, FMX.Controls.Presentation,
  Tapo.Settings;

type
  (*** Asks for the Tapo account and the network to scan. *)
  /// <summary>Asks for the Tapo account and the network to scan.</summary>
  TTapoSettingsForm = class(TForm)
  private
    FNote: TLabel;
    FUserEdit, FPasswordEdit, FNetworkEdit, FSubnetEdit: TEdit;
    FError: TLabel;
    procedure BuildUI(const ANote: string);
    function AddField(const ACaption, APrompt: string): TEdit;
    procedure OkClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure DetectClick(Sender: TObject);
  public
    (***
      Shows the form modally in front of AOwner, filled in from ASettings.

      If the e-mail or password changed, the credential state is reset to csUnknown until they
      have been tried.

      @param(AOwner The form it belongs to @(the main form@): it is centred on it, kept in front
      of it, and the application is blocked until it closes.)

      @param(ASettings The settings to show and, on OK, to update.)

      @param(ANote Optional text shown above the fields, for example why the form is shown.)

      @returns(True if the user pressed OK; ASettings then holds the new values @(not yet
      saved@).)
    *)
    /// <summary>Shows the form modally in front of AOwner, filled in from ASettings.</summary>
    /// <param name="AOwner">The form it belongs to (the main form): it is centred on it, kept in front of it, and the application is blocked until it closes.</param>
    /// <param name="ASettings">The settings to show and, on OK, to update.</param>
    /// <param name="ANote">Optional text shown above the fields, for example why the form is shown.</param>
    /// <returns>True if the user pressed OK; ASettings then holds the new values (not yet saved).</returns>
    /// <remarks>
    ///   If the e-mail or password changed, the credential state is reset to
    ///   csUnknown until they have been tried.
    /// </remarks>
    class function Execute(AOwner: TCommonCustomForm; ASettings: TTapoSettings;
      const ANote: string = ''): Boolean;
  end;

implementation

uses
  NetMacScan;

function TTapoSettingsForm.AddField(const ACaption, APrompt: string): TEdit;
var
  Row: TLayout;
  Lbl: TLabel;
begin
  // rows are top-aligned, so each new one goes below the last
  Row := TLayout.Create(Self);
  Row.Parent := Self;
  Row.Align := TAlignLayout.Top;
  Row.Height := 54;
  Row.Margins.Rect := TRectF.Create(12, 4, 12, 0);
  Row.Position.Y := 10000;

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Row;
  Lbl.Align := TAlignLayout.Top;
  Lbl.Height := 20;
  Lbl.Text := ACaption;

  Result := TEdit.Create(Self);
  Result.Parent := Row;
  Result.Align := TAlignLayout.Top;
  Result.Position.Y := 100;
  Result.TextPrompt := APrompt;
end;

procedure TTapoSettingsForm.BuildUI(const ANote: string);
var
  Buttons: TLayout;
  OkButton, CancelButton, DetectButton: TButton;
begin
  Caption := 'Tapo account and network';
  BorderStyle := TFmxFormBorderStyle.Single;
  Position := TFormPosition.ScreenCenter;
  Width := 400;
  Height := 400;

  FNote := TLabel.Create(Self);
  FNote.Parent := Self;
  FNote.Align := TAlignLayout.Top;
  FNote.Margins.Rect := TRectF.Create(12, 10, 12, 0);
  FNote.WordWrap := True;
  FNote.AutoSize := True;
  FNote.Text := ANote;
  FNote.Visible := ANote <> '';

  FUserEdit := AddField('Tapo account e-mail', 'name@example.com');
  FPasswordEdit := AddField('Tapo account password', '');
  FPasswordEdit.Password := True;
  FNetworkEdit := AddField('Network to scan', 'e.g. 192.168.1.0');
  FSubnetEdit := AddField('Subnet mask', 'e.g. 255.255.255.0 or /24');

  FError := TLabel.Create(Self);
  FError.Parent := Self;
  FError.Align := TAlignLayout.Top;
  FError.Position.Y := 20000;
  FError.Margins.Rect := TRectF.Create(12, 6, 12, 0);
  FError.WordWrap := True;
  FError.AutoSize := True;
  FError.StyledSettings := FError.StyledSettings - [TStyledSetting.FontColor];
  FError.TextSettings.FontColor := TAlphaColors.Red;
  FError.Text := '';

  Buttons := TLayout.Create(Self);
  Buttons.Parent := Self;
  Buttons.Align := TAlignLayout.Bottom;
  Buttons.Height := 48;
  Buttons.Margins.Rect := TRectF.Create(12, 0, 12, 8);

  CancelButton := TButton.Create(Self);
  CancelButton.Parent := Buttons;
  CancelButton.Align := TAlignLayout.Right;
  CancelButton.Width := 90;
  CancelButton.Margins.Rect := TRectF.Create(6, 8, 0, 8);
  CancelButton.Text := 'Cancel';
  CancelButton.OnClick := CancelClick;

  OkButton := TButton.Create(Self);
  OkButton.Parent := Buttons;
  OkButton.Align := TAlignLayout.Right;
  OkButton.Width := 90;
  OkButton.Margins.Rect := TRectF.Create(6, 8, 0, 8);
  OkButton.Text := 'OK';
  OkButton.OnClick := OkClick;

  DetectButton := TButton.Create(Self);
  DetectButton.Parent := Buttons;
  DetectButton.Align := TAlignLayout.Left;
  DetectButton.Width := 130;
  DetectButton.Margins.Rect := TRectF.Create(0, 8, 6, 8);
  DetectButton.Text := 'Detect network';
  DetectButton.OnClick := DetectClick;
end;

// Refills network and subnet from this computer's LAN.
procedure TTapoSettingsForm.DetectClick(Sender: TObject);
var
  Net, Mask: string;
begin
  if TapoLocalNetwork(Net, Mask) then
    FError.Text := ''
  else
    FError.Text := 'No LAN found: showing the default network.';
  FNetworkEdit.Text := Net;
  FSubnetEdit.Text := Mask;
end;

procedure TTapoSettingsForm.OkClick(Sender: TObject);
begin
  FError.Text := '';
  if Trim(FUserEdit.Text) = '' then
    FError.Text := 'Enter the e-mail of your Tapo account.'
  else if FPasswordEdit.Text = '' then
    FError.Text := 'Enter the password of your Tapo account.'
  else
    try
      if Length(SubnetHosts(Trim(FNetworkEdit.Text), Trim(FSubnetEdit.Text))) = 0 then
        FError.Text := 'That network and subnet contain no addresses.';
    except
      on E: Exception do
        FError.Text := E.Message;
    end;

  if FError.Text = '' then
    ModalResult := mrOk;
end;

procedure TTapoSettingsForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

class function TTapoSettingsForm.Execute(AOwner: TCommonCustomForm; ASettings: TTapoSettings;
  const ANote: string): Boolean;
var
  F: TTapoSettingsForm;
  Net, Mask: string;
begin
  // owned by the main form, so it is centred on it and stays in front of it
  F := TTapoSettingsForm.CreateNew(AOwner);
  try
    F.BuildUI(ANote);
    if AOwner <> nil then
    begin
      F.Position := TFormPosition.OwnerFormCenter;
      if not AOwner.Visible then
        AOwner.Show;                    // a modal form needs its owner on screen
    end;
    // in front of every other window of the app while it is open; ShowModal
    // blocks the rest of the app on Windows, macOS and Linux alike
    F.FormStyle := TFormStyle.StayOnTop;
    F.FUserEdit.Text := ASettings.Username;
    F.FPasswordEdit.Text := ASettings.Password;
    F.FNetworkEdit.Text := ASettings.Network;
    F.FSubnetEdit.Text := ASettings.Subnet;
    if (ASettings.Network = '') or (ASettings.Subnet = '') then
    begin
      TapoLocalNetwork(Net, Mask);      // the LAN, or 192.168.0.0 / 255.255.255.0
      if ASettings.Network = '' then
        F.FNetworkEdit.Text := Net;
      if ASettings.Subnet = '' then
        F.FSubnetEdit.Text := Mask;
    end;

    Result := F.ShowModal = mrOk;
    if Result then
    begin
      if (Trim(F.FUserEdit.Text) <> ASettings.Username) or
         (F.FPasswordEdit.Text <> ASettings.Password) then
        ASettings.CredentialState := csUnknown;      // not tried yet
      ASettings.Username := Trim(F.FUserEdit.Text);
      ASettings.Password := F.FPasswordEdit.Text;
      ASettings.Network := Trim(F.FNetworkEdit.Text);
      ASettings.Subnet := Trim(F.FSubnetEdit.Text);
    end;
  finally
    F.Free;
  end;
end;

end.
