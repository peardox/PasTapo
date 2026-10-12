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
  System.SysUtils, System.Classes, System.JSON, System.NetEncoding,
  System.Generics.Collections, Tapo.Client;

type
  (*** Device info of a camera. *)
  /// <summary>Device info of a camera.</summary>
  TTapoCameraInfo = record
    (*** The fields every device reports. *)
    /// <summary>The fields every device reports.</summary>
    Info: TTapoDeviceInfo;
    (*** A free-text description of the model. *)
    /// <summary>A free-text description of the model.</summary>
    DeviceInfo: string;
    (*** True if the camera reports the no_rtsp_constrain setting. *)
    /// <summary>True if the camera reports the no_rtsp_constrain setting.</summary>
    HasNoRtspConstrain: Boolean;
    (*** The no_rtsp_constrain setting, when reported. *)
    /// <summary>The no_rtsp_constrain setting, when reported.</summary>
    NoRtspConstrain: Boolean;
  end;

  (*** A pan/tilt position saved on the camera. *)
  /// <summary>A pan/tilt position saved on the camera.</summary>
  TTapoCameraPreset = record
    (*** The id, for @link(TTapoCamera.GotoPreset) and @link(TTapoCamera.DeletePreset). *)
    /// <summary>The id, for <see cref="TTapoCamera.GotoPreset"/> and <see cref="TTapoCamera.DeletePreset"/>.</summary>
    Id: string;
    (*** The name. *)
    /// <summary>The name.</summary>
    Name: string;
    (*** The pan position. *)
    /// <summary>The pan position.</summary>
    Pan: Double;
    (*** The tilt position. *)
    /// <summary>The tilt position.</summary>
    Tilt: Double;
    (*** True for a preset that cannot be deleted. *)
    /// <summary>True for a preset that cannot be deleted.</summary>
    IsReadOnly: Boolean;
  end;

  (*** The RTSP addresses of a camera's video streams. *)
  /// <summary>The RTSP addresses of a camera's video streams.</summary>
  TTapoRtspStreamUrl = record
    (*** The high-definition stream (stream1). *)
    /// <summary>The high-definition stream (stream1).</summary>
    HD: string;
    (*** The standard-definition stream (stream2). *)
    /// <summary>The standard-definition stream (stream2).</summary>
    SD: string;
    (*** The MJPEG stream (stream8), for still images. *)
    /// <summary>The MJPEG stream (stream8), for still images.</summary>
    MJPEG: string;
  end;

  (***
    Tapo pan/tilt camera: C210, C220, C225, C325WB, C520WS, TC40 and TC70.

    Logs in over TPAP (HTTPS), or over AES SSL if Third-Party Compatibility is on. The camera's
    self-signed certificate is accepted.

    Taking a snapshot is not supported here: open the MJPEG address from @link(GetRtspStreamUrl)
    with any RTSP-capable player or library.

    Example:
    @longCode(#
    Cam := Client.Add(C210, '192.168.1.54');
    Cam.PanTilt(10, 0);
    for Preset in Cam.GetPresets do
      ListBox1.Items.Add(Preset.Name);
    #)
  *)
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
    (*** Returns dfSmartCam. *)
    /// <summary>Returns dfSmartCam.</summary>
    class function Family: TTapoDeviceFamily; override;
    (*** Returns amCamera. *)
    /// <summary>Returns amCamera.</summary>
    class function AuthMode: TTapoAuthMode; override;

    (*** Reads the camera's device info. *)
    /// <summary>Reads the camera's device info.</summary>
    function GetCameraInfo: TTapoCameraInfo;
    (***
      Builds the RTSP addresses of the camera's streams.

      No request is made.

      @param(ACameraUsername The camera account user name @(Tapo app > camera > Advanced Settings
      > Camera Account@), not the Tapo account.)

      @param(ACameraPassword The camera account password.)

      @returns(rtsp://user:password@@host:554/streamN addresses, with the user name and password
      URL-encoded.)
    *)
    /// <summary>Builds the RTSP addresses of the camera's streams.</summary>
    /// <param name="ACameraUsername">The camera account user name (Tapo app &gt; camera &gt; Advanced Settings &gt; Camera Account), not the Tapo account.</param>
    /// <param name="ACameraPassword">The camera account password.</param>
    /// <returns>rtsp://user:password@host:554/streamN addresses, with the user name and password URL-encoded.</returns>
    /// <remarks>No request is made.</remarks>
    function GetRtspStreamUrl(const ACameraUsername, ACameraPassword: string): TTapoRtspStreamUrl;
    (***
      Moves the lens.

      @param(APan Steps to pan; negative is left.)

      @param(ATilt Steps to tilt; negative is down.)
    *)
    /// <summary>Moves the lens.</summary>
    /// <param name="APan">Steps to pan; negative is left.</param>
    /// <param name="ATilt">Steps to tilt; negative is down.</param>
    procedure PanTilt(APan, ATilt: Integer);
    (***
      Saves the current position as a preset.

      @param(AName The preset's name.)
    *)
    /// <summary>Saves the current position as a preset.</summary>
    /// <param name="AName">The preset's name.</param>
    procedure SavePreset(const AName: string);
    (***
      Moves to a saved preset.

      @param(AId The preset's id, from @link(GetPresets).)
    *)
    /// <summary>Moves to a saved preset.</summary>
    /// <param name="AId">The preset's id, from <see cref="GetPresets"/>.</param>
    procedure GotoPreset(const AId: string);
    (***
      Deletes a saved preset.

      @param(AId The preset's id, from @link(GetPresets).)
    *)
    /// <summary>Deletes a saved preset.</summary>
    /// <param name="AId">The preset's id, from <see cref="GetPresets"/>.</param>
    procedure DeletePreset(const AId: string);
    (*** Reads the saved presets. *)
    /// <summary>Reads the saved presets.</summary>
    function GetPresets: TArray<TTapoCameraPreset>;
  end;

  (*** Tapo C210: the same as @link(TTapoCamera). *)
  /// <summary>Tapo C210: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC210 = TTapoCamera;
  (*** Tapo C220: the same as @link(TTapoCamera). *)
  /// <summary>Tapo C220: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC220 = TTapoCamera;
  (*** Tapo C225: the same as @link(TTapoCamera). *)
  /// <summary>Tapo C225: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC225 = TTapoCamera;
  (*** Tapo C325WB: the same as @link(TTapoCamera). *)
  /// <summary>Tapo C325WB: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC325WB = TTapoCamera;
  (*** Tapo C520WS: the same as @link(TTapoCamera). *)
  /// <summary>Tapo C520WS: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoC520WS = TTapoCamera;
  (*** Tapo TC40: the same as @link(TTapoCamera). *)
  /// <summary>Tapo TC40: the same as <see cref="TTapoCamera"/>.</summary>
  TTapoTC40 = TTapoCamera;
  (*** Tapo TC70: the same as @link(TTapoCamera). *)
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

function TTapoCamera.GetRtspStreamUrl(const ACameraUsername,
  ACameraPassword: string): TTapoRtspStreamUrl;
var
  Base: string;
begin
  // user info is percent-encoded, as reqwest::Url does
  Base := 'rtsp://' + TNetEncoding.URL.Encode(ACameraUsername) + ':' +
    TNetEncoding.URL.Encode(ACameraPassword) + '@' + Host + ':554/';
  Result.HD := Base + 'stream1';
  Result.SD := Base + 'stream2';
  Result.MJPEG := Base + 'stream8';
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
