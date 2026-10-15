//** @abstract(The Tapo account, network and camera account dialog.)
//**
//** The controls are in TapoSettingsForm.fmx. Call TTapoSettingsDialog.Execute; the form is not
//** auto-created.
//**
//** Order, top to bottom: Tapo account @(e-mail, password@), network to scan @(network, subnet@),
//** camera account @(user name, password; optional@). An empty network or subnet is filled in
//** from this computer's LAN, or 192.168.0.0 / 255.255.255.0 if it is not on one.
unit TapoSettingsForm;

{
  The Tapo account, network and camera account dialog. The controls are in
  TapoSettingsForm.fmx. Call TTapoSettingsDialog.Execute; the form is not
  auto-created.

  Order, top to bottom: Tapo account (e-mail, password), network to scan
  (network, subnet), camera account (user name, password; optional).
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
  //** @abstract(Asks for the Tapo account, the network to scan and the camera account.)
  /// <summary>Asks for the Tapo account, the network to scan and the camera account.</summary>
  TTapoSettingsDialog = class(TForm)
    // designed in TapoSettingsForm.fmx
    NoteLabel: TLabel;
    AccountGroup: TGroupBox;
    UserRow: TLayout;
    UserLabel: TLabel;
    UserEdit: TEdit;
    PasswordRow: TLayout;
    PasswordLabel: TLabel;
    PasswordEdit: TEdit;
    NetworkGroup: TGroupBox;
    NetworkRow: TLayout;
    NetworkLabel: TLabel;
    NetworkEdit: TEdit;
    SubnetRow: TLayout;
    SubnetLabel: TLabel;
    SubnetEdit: TEdit;
    CameraGroup: TGroupBox;
    CameraNoteLabel: TLabel;
    CameraUserRow: TLayout;
    CameraUserLabel: TLabel;
    CameraUserEdit: TEdit;
    CameraPasswordRow: TLayout;
    CameraPasswordLabel: TLabel;
    CameraPasswordEdit: TEdit;
    ErrorLabel: TLabel;
    ButtonBar: TLayout;
    DetectButton: TButton;
    OkButton: TButton;
    CancelButton: TButton;
    procedure OkClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure DetectClick(Sender: TObject);
  public
    //** @abstract(Shows the dialog modally in front of AOwner, filled in from ASettings.)
    //**
    //** If the e-mail or password changed, the credential state is reset to csUnknown until they
    //** have been tried. The camera account is optional: both fields or neither.
    //**
    //** @param(AOwner The form it belongs to @(the main form@): it is centred on it, kept in front
    //** of it, and the application is blocked until it closes.)
    //**
    //** @param(ASettings The settings to show and, on OK, to update.)
    //**
    //** @param(ANote Optional text shown above the fields, for example why the dialog is shown.)
    //**
    //** @returns(True if the user pressed OK; ASettings then holds the new values @(not yet
    //** saved@).)
    /// <summary>Shows the dialog modally in front of AOwner, filled in from ASettings.</summary>
    /// <param name="AOwner">The form it belongs to (the main form): it is centred on it, kept in front of it, and the application is blocked until it closes.</param>
    /// <param name="ASettings">The settings to show and, on OK, to update.</param>
    /// <param name="ANote">Optional text shown above the fields, for example why the dialog is shown.</param>
    /// <returns>True if the user pressed OK; ASettings then holds the new values (not yet saved).</returns>
    /// <remarks>
    ///   If the e-mail or password changed, the credential state is reset to
    ///   csUnknown until they have been tried. The camera account is
    ///   optional: both fields or neither.
    /// </remarks>
    class function Execute(AOwner: TCommonCustomForm; ASettings: TTapoSettings;
      const ANote: string = ''): Boolean;
  end;

var
  //** @abstract(Unused: the dialog is created by @link(TTapoSettingsDialog.Execute).)
  /// <summary>Unused: the dialog is created by <see cref="TTapoSettingsDialog.Execute"/>.</summary>
  TapoSettingsDialog: TTapoSettingsDialog;

implementation

uses
  NetMacScan;

{$R *.fmx}

// Refills network and subnet from this computer's LAN.
procedure TTapoSettingsDialog.DetectClick(Sender: TObject);
var
  Net, Mask: string;
begin
  if TapoLocalNetwork(Net, Mask) then
    ErrorLabel.Text := ''
  else
    ErrorLabel.Text := 'No LAN found: showing the default network.';
  NetworkEdit.Text := Net;
  SubnetEdit.Text := Mask;
end;

procedure TTapoSettingsDialog.OkClick(Sender: TObject);
begin
  ErrorLabel.Text := '';
  if Trim(UserEdit.Text) = '' then
    ErrorLabel.Text := 'Enter the e-mail of your Tapo account.'
  else if PasswordEdit.Text = '' then
    ErrorLabel.Text := 'Enter the password of your Tapo account.'
  else if (Trim(CameraUserEdit.Text) = '') <> (CameraPasswordEdit.Text = '') then
    ErrorLabel.Text := 'Enter both the camera account user name and password, or neither.'
  else
    try
      if Length(SubnetHosts(Trim(NetworkEdit.Text), Trim(SubnetEdit.Text))) = 0 then
        ErrorLabel.Text := 'That network and subnet contain no addresses.';
    except
      on E: Exception do
        ErrorLabel.Text := E.Message;
    end;

  if ErrorLabel.Text = '' then
    ModalResult := mrOk;
end;

procedure TTapoSettingsDialog.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

class function TTapoSettingsDialog.Execute(AOwner: TCommonCustomForm; ASettings: TTapoSettings;
  const ANote: string): Boolean;
var
  F: TTapoSettingsDialog;
  Net, Mask: string;
begin
  // owned by the main form, so it is centred on it and stays in front of it
  F := TTapoSettingsDialog.Create(AOwner);
  try
    if AOwner <> nil then
    begin
      F.Position := TFormPosition.OwnerFormCenter;
      if not AOwner.Visible then
        AOwner.Show;                    // a modal form needs its owner on screen
    end;
    // in front of every other window of the app while it is open; ShowModal
    // blocks the rest of the app on Windows, macOS and Linux alike
    F.FormStyle := TFormStyle.StayOnTop;

    F.NoteLabel.Text := ANote;
    F.NoteLabel.Visible := ANote <> '';
    F.ErrorLabel.Text := '';
    F.UserEdit.Text := ASettings.Username;
    F.PasswordEdit.Text := ASettings.Password;
    F.NetworkEdit.Text := ASettings.Network;
    F.SubnetEdit.Text := ASettings.Subnet;
    F.CameraUserEdit.Text := ASettings.CameraUsername;
    F.CameraPasswordEdit.Text := ASettings.CameraPassword;
    if (ASettings.Network = '') or (ASettings.Subnet = '') then
    begin
      TapoLocalNetwork(Net, Mask);      // the LAN, or 192.168.0.0 / 255.255.255.0
      if ASettings.Network = '' then
        F.NetworkEdit.Text := Net;
      if ASettings.Subnet = '' then
        F.SubnetEdit.Text := Mask;
    end;

    Result := F.ShowModal = mrOk;
    if Result then
    begin
      if (Trim(F.UserEdit.Text) <> ASettings.Username) or
         (F.PasswordEdit.Text <> ASettings.Password) then
        ASettings.CredentialState := csUnknown;      // not tried yet
      ASettings.Username := Trim(F.UserEdit.Text);
      ASettings.Password := F.PasswordEdit.Text;
      ASettings.Network := Trim(F.NetworkEdit.Text);
      ASettings.Subnet := Trim(F.SubnetEdit.Text);
      ASettings.CameraUsername := Trim(F.CameraUserEdit.Text);
      ASettings.CameraPassword := F.CameraPasswordEdit.Text;
    end;
  finally
    F.Free;
  end;
end;

end.
