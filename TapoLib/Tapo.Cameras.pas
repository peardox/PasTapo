//** @abstract(Tapo cameras: C210, C220, C225, C325WB, C520WS, TC40, TC70.)
//**
//** @preformatted(
//** TTapoDevice @(abstract, Tapo.Client@)
//** `-- TTapoCamera                 device info, pan/tilt, presets, RTSP URLs
//** )
//**
//** Cameras log in over TPAP (HTTPS), or AES SSL if Third-Party Compatibility is on; Tapo.Client
//** picks the protocol.
//**
//** The RTSP URLs need the camera account (Tapo app > camera > Advanced Settings > Camera
//** Account), which is separate from the Tapo cloud account. Snapshot capture is not included: it
//** needs an RTSP/MJPEG client, which is outside the Tapo control API (open the MJPEG URL with any
//** RTSP-capable player or library instead).
unit Tapo.Cameras;

{
  Tapo cameras: C210, C220, C225, C325WB, C520WS, TC40, TC70.

    TTapoDevice (abstract, Tapo.Client)
    `-- TTapoCamera                 device info, pan/tilt, presets, RTSP URLs

  Cameras log in over TPAP (HTTPS), or AES SSL if Third-Party Compatibility
  is on; Tapo.Client picks the protocol.

  The RTSP URLs need the camera account (Tapo app > camera > Advanced
  Settings > Camera Account), which is separate from the Tapo cloud account.
  Snapshot capture is not included: it needs an RTSP/MJPEG client, which is
  outside the Tapo control API (open the MJPEG URL with any RTSP-capable
  player or library instead).
}

interface

uses
  System.SysUtils, System.Classes, System.JSON,
  System.Generics.Collections, Tapo.Client;

type
  //** @abstract(Device info of a camera.)
  /// <summary>Device info of a camera.</summary>
  TTapoCameraInfo = record
    //** @abstract(The fields every device reports.)
    /// <summary>The fields every device reports.</summary>
    Info: TTapoDeviceInfo;
    //** @abstract(A free-text description of the model.)
    /// <summary>A free-text description of the model.</summary>
    DeviceInfo: string;
    //** @abstract(True if the camera reports the no_rtsp_constrain setting.)
    /// <summary>True if the camera reports the no_rtsp_constrain setting.</summary>
    HasNoRtspConstrain: Boolean;
    //** @abstract(The no_rtsp_constrain setting, when reported.)
    /// <summary>The no_rtsp_constrain setting, when reported.</summary>
    NoRtspConstrain: Boolean;
  end;

  //** @abstract(A pan/tilt position saved on the camera.)
  /// <summary>A pan/tilt position saved on the camera.</summary>
  TTapoCameraPreset = record
    //** @abstract(The id, for @link(TTapoCamera.GotoPreset) and @link(TTapoCamera.DeletePreset).)
    /// <summary>The id, for <see cref="TTapoCamera.GotoPreset"/> and <see cref="TTapoCamera.DeletePreset"/>.</summary>
    Id: string;
    //** @abstract(The name.)
    /// <summary>The name.</summary>
    Name: string;
    //** @abstract(The pan position.)
    /// <summary>The pan position.</summary>
    Pan: Double;
    //** @abstract(The tilt position.)
    /// <summary>The tilt position.</summary>
    Tilt: Double;
    //** @abstract(True for a preset that cannot be deleted.)
    /// <summary>True for a preset that cannot be deleted.</summary>
    IsReadOnly: Boolean;
  end;

  //** @abstract(One of a camera's RTSP video streams.)
  /// <summary>One of a camera's RTSP video streams.</summary>
  TTapoRtspStream = (
    //** @abstract(Full quality @(stream1; 1080p on a C210@).)
    /// <summary>Full quality (stream1; 1080p on a C210).</summary>
    rsHD,
    //** @abstract(Low quality @(stream2; 360p on a C210@).)
    /// <summary>Low quality (stream2; 360p on a C210).</summary>
    rsSD,
    //** @abstract(MJPEG @(stream8@), for still images.)
    /// <summary>MJPEG (stream8), for still images.</summary>
    rsMJPEG);

  //** @abstract(The RTSP addresses of a camera's video streams.)
  /// <summary>The RTSP addresses of a camera's video streams.</summary>
  TTapoRtspStreamUrl = record
    //** @abstract(The high-definition stream @(stream1@).)
    /// <summary>The high-definition stream (stream1).</summary>
    HD: string;
    //** @abstract(The standard-definition stream @(stream2@).)
    /// <summary>The standard-definition stream (stream2).</summary>
    SD: string;
    //** @abstract(The MJPEG stream @(stream8@), for still images.)
    /// <summary>The MJPEG stream (stream8), for still images.</summary>
    MJPEG: string;
  end;

  //** @abstract(Tapo pan/tilt camera: C210, C220, C225, C325WB, C520WS, TC40 and TC70.)
  //**
  //** Logs in over TPAP (HTTPS), or over AES SSL if Third-Party Compatibility is on. The camera's
  //** self-signed certificate is accepted.
  //**
  //** Taking a snapshot is not supported here: open the MJPEG address from @link(GetRtspStreamUrl)
  //** with any RTSP-capable player or library.
  //**
  //** Example:
  //** @longCode(#
  //** Cam := Client.Add(C210, '192.168.1.54');
  //** Cam.PanTilt(10, 0);
  //** for Preset in Cam.GetPresets do
  //**   ListBox1.Items.Add(Preset.Name);
  //** #)
  /// <summary>Tapo pan/tilt camera: C210, C220, C225, C325WB, C520WS, TC40 and TC70.</summary>
  /// <remarks>
  ///   <para>
  ///     Logs in over TPAP (HTTPS), or over AES SSL if Third-Party
  ///     Compatibility is on. The camera's self-signed certificate is accepted.
  ///   </para>
  ///   <para>
  ///     Taking a snapshot is not supported here: open the MJPEG address from
  ///     <see cref="GetRtspStreamUrl"/> with any RTSP-capable player or library.
  ///   </para>
  /// </remarks>
  /// <example>
  ///   <code>
  ///   Cam := Client.Add(C210, '192.168.1.54');
  ///   Cam.PanTilt(10, 0);
  ///   for Preset in Cam.GetPresets do
  ///     ListBox1.Items.Add(Preset.Name);
  ///   </code>
  /// </example>
  TTapoCamera = class(TTapoDevice)
  public
    //** @abstract(Returns dfSmartCam.)
    /// <summary>Returns dfSmartCam.</summary>
    class function Family: TTapoDeviceFamily; override;
    //** @abstract(Returns amCamera.)
    /// <summary>Returns amCamera.</summary>
    class function AuthMode: TTapoAuthMode; override;

    //** @abstract(Reads the camera's device info.)
    /// <summary>Reads the camera's device info.</summary>
    function GetCameraInfo: TTapoCameraInfo;
    //** @abstract(Builds the RTSP addresses of the camera's streams.)
    //**
    //** No request is made.
    //**
    //** @param(ACameraUsername The camera account user name @(Tapo app > camera > Advanced Settings
    //** > Camera Account@), not the Tapo account.)
    //**
    //** @param(ACameraPassword The camera account password.)
    //**
    //** @param(AEncode True @(the default@) to percent-encode the user name and password, as any
    //** other program needs; False to put them in as they are, for a viewer in the application
    //** that splits the address itself. See @link(RtspUrl).)
    //**
    //** @returns(rtsp://user:password@@host:554/streamN addresses.)
    /// <summary>Builds the RTSP addresses of the camera's streams.</summary>
    /// <param name="ACameraUsername">The camera account user name (Tapo app &gt; camera &gt; Advanced Settings &gt; Camera Account), not the Tapo account.</param>
    /// <param name="ACameraPassword">The camera account password.</param>
    /// <param name="AEncode">True (the default) to percent-encode the user name and password, as any other program needs; False to put them in as they are, for a viewer in the application that splits the address itself. See <see cref="RtspUrl"/>.</param>
    /// <returns>rtsp://user:password@host:554/streamN addresses.</returns>
    /// <remarks>No request is made.</remarks>
    function GetRtspStreamUrl(const ACameraUsername, ACameraPassword: string;
      AEncode: Boolean = True): TTapoRtspStreamUrl; overload;
    //** @abstract(Builds the RTSP addresses of the camera's streams, with the client's camera account
    //** in them.)
    //**
    //** No request is made. Uses the client's Account.CameraUsername and CameraPassword.
    //**
    //** @param(AEncode True @(the default@) to percent-encode the user name and password; False to
    //** put them in as they are. See @link(RtspUrl).)
    /// <summary>Builds the RTSP addresses of the camera's streams, with the client's camera account in them.</summary>
    /// <param name="AEncode">True (the default) to percent-encode the user name and password; False to put them in as they are. See <see cref="RtspUrl"/>.</param>
    /// <remarks>No request is made. Uses the client's Account.CameraUsername and CameraPassword.</remarks>
    function GetRtspStreamUrl(AEncode: Boolean = True): TTapoRtspStreamUrl; overload;
    //** @abstract(Builds the RTSP address of one of the camera's streams.)
    //**
    //** No request is made. With an empty user name the address has no login part, and the player
    //** asks for it.
    //**
    //** Encoded @(AEncode True@), characters such as @@ : / $ ! in the user name and password are
    //** percent-encoded, so VLC, ffplay, FFmpeg, libVLC and the like read the address correctly. Not
    //** encoded, they go in as typed: only for a viewer of your own that takes the login from the
    //** address itself, splitting at the last @@ before the host, since a standard URL parser
    //** misreads an e-mail address as the user name. A viewer that takes the user name and
    //** password separately is better served by the address without a login: pass empty strings.
    //**
    //** @param(ACameraUsername The camera account user name @(Tapo app > camera > Advanced Settings
    //** > Camera Account@), not the Tapo account.)
    //**
    //** @param(ACameraPassword The camera account password.)
    //**
    //** @param(AStream Which stream; full quality by default.)
    //**
    //** @param(AEncode True @(the default@) to percent-encode the user name and password.)
    //**
    //** @returns(For example 'rtsp://user:pass@@192.168.1.155:554/stream1'.)
    //**
    //** Example:
    //** @longCode(#
    //** Url := Camera.RtspUrl(Settings.CameraUsername, Settings.CameraPassword, rsSD);
    //** #)
    /// <summary>Builds the RTSP address of one of the camera's streams.</summary>
    /// <param name="ACameraUsername">The camera account user name (Tapo app &gt; camera &gt; Advanced Settings &gt; Camera Account), not the Tapo account.</param>
    /// <param name="ACameraPassword">The camera account password.</param>
    /// <param name="AStream">Which stream; full quality by default.</param>
    /// <param name="AEncode">True (the default) to percent-encode the user name and password.</param>
    /// <returns>For example 'rtsp://user:pass@192.168.1.155:554/stream1'.</returns>
    /// <remarks>
    ///   No request is made. With an empty user name the address has no login
    ///   part, and the player asks for it.
    ///   <para>Encoded (AEncode True), characters such as @ : / $ ! in the user
    ///   name and password are percent-encoded, so VLC, ffplay, FFmpeg, libVLC
    ///   and the like read the address correctly. Not encoded, they go in as
    ///   typed: only for a viewer of your own that takes the login from the
    ///   address itself, splitting at the last @ before the host, since a
    ///   standard URL parser misreads an e-mail address as the user name. A
    ///   viewer that takes the user name and password separately is better
    ///   served by the address without a login: pass empty strings.</para>
    /// </remarks>
    /// <example>
    ///   <code>Url := Camera.RtspUrl(Settings.CameraUsername, Settings.CameraPassword, rsSD);</code>
    /// </example>
    function RtspUrl(const ACameraUsername, ACameraPassword: string;
      AStream: TTapoRtspStream = rsHD; AEncode: Boolean = True): string; overload;
    //** @abstract(Builds the RTSP address of one of the camera's streams, with the client's camera
    //** account in it.)
    //**
    //** No request is made. Uses the client's Account.CameraUsername and CameraPassword; with no camera
    //** account set there, the address has no login part and the player asks for it.
    //**
    //** @param(AStream Which stream; full quality by default.)
    //**
    //** @param(AEncode True @(the default@) to percent-encode the user name and password; False to
    //** put them in as they are @(see the other overload@).)
    //**
    //** @returns(For example 'rtsp://user:pass@@192.168.1.155:554/stream1'.)
    //**
    //** Example:
    //** @longCode(#
    //** Client.Account.CameraUsername := 'cam';
    //** Client.Account.CameraPassword := 'secret';
    //** Url := Camera.RtspUrl(rsSD);
    //** #)
    /// <summary>Builds the RTSP address of one of the camera's streams, with the client's camera account in it.</summary>
    /// <param name="AStream">Which stream; full quality by default.</param>
    /// <param name="AEncode">True (the default) to percent-encode the user name and password; False to put them in as they are (see the other overload).</param>
    /// <returns>For example 'rtsp://user:pass@192.168.1.155:554/stream1'.</returns>
    /// <remarks>
    ///   No request is made. Uses the client's Account.CameraUsername and CameraPassword;
    ///   with no camera account set there, the address has no login part and
    ///   the player asks for it.
    /// </remarks>
    /// <example>
    ///   <code>
    ///   Client.Account.CameraUsername := 'cam';
    ///   Client.Account.CameraPassword := 'secret';
    ///   Url := Camera.RtspUrl(rsSD);
    ///   </code>
    /// </example>
    function RtspUrl(AStream: TTapoRtspStream = rsHD; AEncode: Boolean = True): string; overload;
    //** @abstract(Moves the lens.)
    //**
    //** @param(APan Steps to pan; negative is left.)
    //**
    //** @param(ATilt Steps to tilt; negative is down.)
    /// <summary>Moves the lens.</summary>
    /// <param name="APan">Steps to pan; negative is left.</param>
    /// <param name="ATilt">Steps to tilt; negative is down.</param>
    procedure PanTilt(APan, ATilt: Integer);
    //** @abstract(Saves the current position as a preset.)
    //**
    //** @param(AName The preset's name.)
    /// <summary>Saves the current position as a preset.</summary>
    /// <param name="AName">The preset's name.</param>
    procedure SavePreset(const AName: string);
    //** @abstract(Moves to a saved preset.)
    //**
    //** @param(AId The preset's id, from @link(GetPresets).)
    /// <summary>Moves to a saved preset.</summary>
    /// <param name="AId">The preset's id, from <see cref="GetPresets"/>.</param>
    procedure GotoPreset(const AId: string);
    //** @abstract(Deletes a saved preset.)
    //**
    //** @param(AId The preset's id, from @link(GetPresets).)
    /// <summary>Deletes a saved preset.</summary>
    /// <param name="AId">The preset's id, from <see cref="GetPresets"/>.</param>
    procedure DeletePreset(const AId: string);
    //** @abstract(Reads the saved presets.)
    /// <summary>Reads the saved presets.</summary>
    function GetPresets: TArray<TTapoCameraPreset>;
  end;

  //** @abstract(Tapo C210: the same as @link(TTapoCamera).)
  /// <summary>Tapo C210: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC210 = TTapoCamera;
  //** @abstract(Tapo C220: the same as @link(TTapoCamera).)
  /// <summary>Tapo C220: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC220 = TTapoCamera;
  //** @abstract(Tapo C225: the same as @link(TTapoCamera).)
  /// <summary>Tapo C225: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC225 = TTapoCamera;
  //** @abstract(Tapo C325WB: the same as @link(TTapoCamera).)
  /// <summary>Tapo C325WB: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC325WB = TTapoCamera;
  //** @abstract(Tapo C520WS: the same as @link(TTapoCamera).)
  /// <summary>Tapo C520WS: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC520WS = TTapoCamera;
  //** @abstract(Tapo TC40: the same as @link(TTapoCamera).)
  /// <summary>Tapo TC40: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoTC40 = TTapoCamera;
  //** @abstract(Tapo TC70: the same as @link(TTapoCamera).)
  /// <summary>Tapo TC70: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoTC70 = TTapoCamera;

implementation

class function TTapoCamera.Family: TTapoDeviceFamily;
begin
  Result := dfSmartCam;
end;

class function TTapoCamera.AuthMode: TTapoAuthMode;
begin
  Result := amCamera;
end;

function TTapoCamera.GetCameraInfo: TTapoCameraInfo;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result.Info := TTapoDeviceInfo.FromJSON(R);
    Result.DeviceInfo := JStr(R, 'device_info');
    Result.HasNoRtspConstrain := JHas(R, 'no_rtsp_constrain');
    Result.NoRtspConstrain := JBool(R, 'no_rtsp_constrain');
  finally
    R.Free;
  end;
end;

// Percent-encodes everything but the RFC 3986 unreserved characters, as the
// user and password of a URL need. (TNetEncoding.URL is form encoding: it
// turns a space into '+', which a URL's user info reads as a plus sign.)
function UserInfoEncode(const S: string): string;
var
  B: Byte;
begin
  Result := '';
  for B in TEncoding.UTF8.GetBytes(S) do
    if CharInSet(Char(B), ['A'..'Z', 'a'..'z', '0'..'9', '-', '.', '_', '~']) then
      Result := Result + Char(B)
    else
      Result := Result + '%' + IntToHex(B, 2);
end;

function TTapoCamera.RtspUrl(const ACameraUsername, ACameraPassword: string;
  AStream: TTapoRtspStream; AEncode: Boolean): string;
const
  Paths: array[TTapoRtspStream] of string = ('stream1', 'stream2', 'stream8');
var
  Login: string;
begin
  Login := '';
  if ACameraUsername <> '' then
    if AEncode then
      Login := UserInfoEncode(ACameraUsername) + ':' + UserInfoEncode(ACameraPassword) + '@'
    else
      Login := ACameraUsername + ':' + ACameraPassword + '@';
  Result := 'rtsp://' + Login + Host + ':554/' + Paths[AStream];
end;

function TTapoCamera.RtspUrl(AStream: TTapoRtspStream; AEncode: Boolean): string;
begin
  Result := RtspUrl(Client.Account.CameraUsername, Client.Account.CameraPassword, AStream, AEncode);
end;

function TTapoCamera.GetRtspStreamUrl(AEncode: Boolean): TTapoRtspStreamUrl;
begin
  Result := GetRtspStreamUrl(Client.Account.CameraUsername, Client.Account.CameraPassword, AEncode);
end;

function TTapoCamera.GetRtspStreamUrl(const ACameraUsername,
  ACameraPassword: string; AEncode: Boolean): TTapoRtspStreamUrl;
begin
  Result.HD := RtspUrl(ACameraUsername, ACameraPassword, rsHD, AEncode);
  Result.SD := RtspUrl(ACameraUsername, ACameraPassword, rsSD, AEncode);
  Result.MJPEG := RtspUrl(ACameraUsername, ACameraPassword, rsMJPEG, AEncode);
end;

procedure TTapoCamera.PanTilt(APan, ATilt: Integer);
begin
  // coordinates travel as strings
  Execute('motorMove', JObject(['motor', JObject(['move',
    JObject(['x_coord', IntToStr(APan), 'y_coord', IntToStr(ATilt)])])])).Free;
end;

procedure TTapoCamera.SavePreset(const AName: string);
begin
  // "addMotorPostion" - the misspelling is the device's
  Execute('addMotorPostion', JObject(['preset', JObject(['set_preset',
    JObject(['name', AName])])])).Free;
end;

procedure TTapoCamera.GotoPreset(const AId: string);
begin
  Execute('motorMoveToPreset', JObject(['preset', JObject(['goto_preset',
    JObject(['id', AId])])])).Free;
end;

procedure TTapoCamera.DeletePreset(const AId: string);
var
  Ids: TJSONArray;
begin
  Ids := TJSONArray.Create;
  Ids.Add(AId);
  Execute('deletePreset', JObject(['preset', JObject(['remove_preset',
    JObject(['id', Ids])])])).Free;
end;

function StrAt(A: TJSONArray; I: Integer): string;
begin
  if (A <> nil) and (I < A.Count) then
    Result := A.Items[I].Value
  else
    Result := '';
end;

// {"preset": {"preset": {"id": [...], "name": [...], "position_pan": [...],
//  "position_tilt": [...], "read_only": [...]}}} - parallel arrays of strings
function TTapoCamera.GetPresets: TArray<TTapoCameraPreset>;
var
  R, Leaf: TJSONObject;
  Ids, Names, Pans, Tilts, ReadOnlys: TJSONArray;
  I, N, Count: Integer;
  FS: TFormatSettings;
  Pan, Tilt: Double;
begin
  FS := TFormatSettings.Invariant;
  R := Execute('getPresetConfig', JObject(['preset', JSectionNames('preset')]));
  try
    Leaf := TapoSectionLeaf(R);
    Ids := JArr(Leaf, 'id');
    Names := JArr(Leaf, 'name');
    Pans := JArr(Leaf, 'position_pan');
    Tilts := JArr(Leaf, 'position_tilt');
    ReadOnlys := JArr(Leaf, 'read_only');
    Result := nil;
    if (Ids = nil) or (Names = nil) or (Pans = nil) or (Tilts = nil) or (ReadOnlys = nil) then
      Exit;
    N := Ids.Count;
    if Names.Count < N then N := Names.Count;
    if Pans.Count < N then N := Pans.Count;
    if Tilts.Count < N then N := Tilts.Count;
    if ReadOnlys.Count < N then N := ReadOnlys.Count;
    SetLength(Result, N);
    Count := 0;
    for I := 0 to N - 1 do
      // an entry whose position does not parse is skipped
      if TryStrToFloat(StrAt(Pans, I), Pan, FS) and TryStrToFloat(StrAt(Tilts, I), Tilt, FS) then
      begin
        Result[Count].Id := StrAt(Ids, I);
        Result[Count].Name := StrAt(Names, I);
        Result[Count].Pan := Pan;
        Result[Count].Tilt := Tilt;
        Result[Count].IsReadOnly := StrAt(ReadOnlys, I) <> '0';
        Inc(Count);
      end;
    SetLength(Result, Count);
  finally
    R.Free;
  end;
end;

end.
