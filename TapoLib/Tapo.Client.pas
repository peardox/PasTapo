//** @abstract(Tapo local-network client: account credentials, device registry and the abstract
//** device base class that handles authentication.)
//**
//** @preformatted(
//** TTapoClient       - holds the Tapo account e-mail and password @(given once@)
//**                     and owns the devices created from it.
//** TTapoEndpoint     - anything that accepts Tapo requests.
//** TTapoDevice       - abstract device reached by IP address. Picks the
//**                     protocol, logs in on first use, keeps the session and
//**                     logs in again only when the device ends it.
//** TTapoChildDevice  - abstract device reached through a parent device: a
//**                     power-strip socket or a hub sensor/switch.
//** )
//**
//** @preformatted(
//** Protocols @(chosen per device family, as the Rust crate does@):
//**   plugs, bulbs, strips, H100  - TPAP if the device announces it, else KLAP
//**   cameras                     - TPAP over HTTPS, else AES SSL
//**   camera hubs @(H200, H500@)    - AES SSL, as the local "admin" account
//** )
//**
//** Concrete device classes are in Tapo.Devices, Tapo.Hubs and Tapo.Cameras; Tapo.Models adds
//** Client.Add(P110, '192.168.1.50').
//**
//** Protocol code ported from https://github.com/mihai-dinculescu/tapo. All calls are blocking
//** network I/O; call them from a background thread (TTask.Run) in an FMX app. Each device
//** serialises its own requests, so one device object may be shared between threads.
unit Tapo.Client;

{
  Tapo local-network client: account credentials, device registry and the
  abstract device base class that handles authentication.

    TTapoClient       - holds the Tapo account e-mail and password (given once)
                        and owns the devices created from it.
    TTapoEndpoint     - anything that accepts Tapo requests.
    TTapoDevice       - abstract device reached by IP address. Picks the
                        protocol, logs in on first use, keeps the session and
                        logs in again only when the device ends it.
    TTapoChildDevice  - abstract device reached through a parent device: a
                        power-strip socket or a hub sensor/switch.

  Protocols (chosen per device family, as the Rust crate does):
    plugs, bulbs, strips, H100  - TPAP if the device announces it, else KLAP
    cameras                     - TPAP over HTTPS, else AES SSL
    camera hubs (H200, H500)    - AES SSL, as the local "admin" account

  Concrete device classes are in Tapo.Devices, Tapo.Hubs and Tapo.Cameras;
  Tapo.Models adds Client.Add(P110, '192.168.1.50').

  Protocol code ported from https://github.com/mihai-dinculescu/tapo.
  All calls are blocking network I/O; call them from a background thread
  (TTask.Run) in an FMX app. Each device serialises its own requests, so one
  device object may be shared between threads.
}

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.JSON, System.DateUtils,
  System.TypInfo, System.Generics.Collections, System.Net.URLClient,
  System.Net.HttpClient, Tapo.Crypto;

type
  //** @abstract(Raised for every failure reported by a Tapo device or found while talking to one.)
  //**
  //** @link(ErrorCode) identifies the failure. Network failures (no route, refused connection,
  //** time-out) are raised by the RTL as @code(ENetHTTPClientException) instead.
  /// <summary>
  ///   Raised for every failure reported by a Tapo device or found while
  ///   talking to one.
  /// </summary>
  /// <remarks>
  ///   <see cref="ErrorCode"/> identifies the failure. Network failures (no
  ///   route, refused connection, time-out) are raised by the RTL as
  ///   <c>ENetHTTPClientException</c> instead.
  /// </remarks>
  ETapoError = class(Exception)
  private
    FErrorCode: Integer;
  public
    //** @abstract(Creates the exception with an error code.)
    //**
    //** @param(ACode The device error_code, an HTTP status, or -1.)
    //**
    //** @param(AMsg The message.)
    /// <summary>Creates the exception with an error code.</summary>
    /// <param name="ACode">The device error_code, an HTTP status, or -1.</param>
    /// <param name="AMsg">The message.</param>
    constructor CreateCode(ACode: Integer; const AMsg: string);
    //** @abstract(The device's error_code @(negative, for example -1501 for a login failure or -2101
    //** for a device locked after failed logins@), an HTTP status @(positive, for example 403@), or
    //** -1 for a failure found locally.)
    //**
    //** @seealso(TapoErrorName)
    /// <summary>
    ///   The device's error_code (negative, for example -1501 for a login
    ///   failure or -2101 for a device locked after failed logins), an HTTP
    ///   status (positive, for example 403), or -1 for a failure found locally.
    /// </summary>
    /// <seealso cref="TapoErrorName"/>
    property ErrorCode: Integer read FErrorCode;
  end;

  //** @abstract(Raised internally when a device no longer knows the session.)
  //**
  //** The request is retried once after a fresh login, so this exception only reaches your code if
  //** the second attempt fails as well.
  /// <summary>
  ///   Raised internally when a device no longer knows the session.
  /// </summary>
  /// <remarks>
  ///   The request is retried once after a fresh login, so this exception
  ///   only reaches your code if the second attempt fails as well.
  /// </remarks>
  ETapoSessionExpired = class(ETapoError);

  //** @abstract(Raised when a device rejects the Tapo account e-mail or password.)
  //**
  //** Raised by every login type (KLAP, TPAP, AES SSL). Do not retry in a loop: devices lock
  //** themselves after too many failed logins.
  /// <summary>Raised when a device rejects the Tapo account e-mail or password.</summary>
  /// <remarks>
  ///   Raised by every login type (KLAP, TPAP, AES SSL). Do not retry in a
  ///   loop: devices lock themselves after too many failed logins.
  /// </remarks>
  ETapoAuthError = class(ETapoError);

  //** @abstract(The local protocol a device is spoken to with.)
  /// <summary>The local protocol a device is spoken to with.</summary>
  TTapoProtocol = (
    //** @abstract(Pick the protocol for each device @(the default@).)
    /// <summary>Pick the protocol for each device (the default).</summary>
    tpAuto,
    //** @abstract(KLAP: older firmware, or any firmware with Third-Party Compatibility on.)
    /// <summary>KLAP: older firmware, or any firmware with Third-Party Compatibility on.</summary>
    tpKlap,
    //** @abstract(TPAP: SPAKE2+ login and AES-CCM session; current firmware with Third-Party
    //** Compatibility off.)
    /// <summary>TPAP: SPAKE2+ login and AES-CCM session; current firmware with Third-Party Compatibility off.</summary>
    tpTpap,
    //** @abstract(AES SSL: cameras and camera hubs.)
    /// <summary>AES SSL: cameras and camera hubs.</summary>
    tpAesSsl);

  //** @abstract(The request format a device family uses.)
  /// <summary>The request format a device family uses.</summary>
  TTapoDeviceFamily = (
    //** @abstract(Plugs, lights, light strips, power strips and the H100 hub.)
    /// <summary>Plugs, lights, light strips, power strips and the H100 hub.</summary>
    dfSmart,
    //** @abstract(Cameras and camera hubs @(H200, H500@): every request is wrapped in a
    //** multipleRequest.)
    /// <summary>Cameras and camera hubs (H200, H500): every request is wrapped in a multipleRequest.</summary>
    dfSmartCam);

  //** @abstract(How a device class logs in.)
  /// <summary>How a device class logs in.</summary>
  TTapoAuthMode = (
    //** @abstract(Ask the device: TPAP if it announces it, otherwise KLAP.)
    /// <summary>Ask the device: TPAP if it announces it, otherwise KLAP.</summary>
    amNegotiate,
    //** @abstract(TPAP over HTTPS, otherwise AES SSL @(cameras@).)
    /// <summary>TPAP over HTTPS, otherwise AES SSL (cameras).</summary>
    amCamera,
    //** @abstract(AES SSL as the hub's local "admin" account @(H200, H500@).)
    /// <summary>AES SSL as the hub's local "admin" account (H200, H500).</summary>
    amCameraHub);

  //** @abstract(The fields every Tapo device reports in its device info.)
  //**
  //** Nickname and SSID are decoded from the Base64 the device sends. Cameras report some fields
  //** under other names (dev_id, sw_version, device_model, device_alias); @link(FromJSON) reads
  //** either. Fields a device does not report are empty or 0. @link(Raw) holds the whole reply for
  //** anything else.
  /// <summary>
  ///   The fields every Tapo device reports in its device info.
  /// </summary>
  /// <remarks>
  ///   Nickname and SSID are decoded from the Base64 the device sends.
  ///   Cameras report some fields under other names (dev_id, sw_version,
  ///   device_model, device_alias); <see cref="FromJSON"/> reads either.
  ///   Fields a device does not report are empty or 0. <see cref="Raw"/> holds
  ///   the whole reply for anything else.
  /// </remarks>
  TTapoDeviceInfo = record
    //** @abstract(The device id, unique per device.)
    /// <summary>The device id, unique per device.</summary>
    DeviceId: string;
    //** @abstract(The model as the device reports it, for example 'P110'.)
    /// <summary>The model as the device reports it, for example 'P110'.</summary>
    Model: string;
    //** @abstract(The device type, for example 'SMART.TAPOPLUG'.)
    /// <summary>The device type, for example 'SMART.TAPOPLUG'.</summary>
    DeviceType: string;
    //** @abstract(The name given in the Tapo app.)
    /// <summary>The name given in the Tapo app.</summary>
    Nickname: string;
    //** @abstract(The device name @(cameras and camera hubs@).)
    /// <summary>The device name (cameras and camera hubs).</summary>
    DeviceName: string;
    //** @abstract(The firmware version.)
    /// <summary>The firmware version.</summary>
    FirmwareVersion: string;
    //** @abstract(The hardware version.)
    /// <summary>The hardware version.</summary>
    HardwareVersion: string;
    //** @abstract(The firmware id.)
    /// <summary>The firmware id.</summary>
    FirmwareId: string;
    //** @abstract(The hardware id.)
    /// <summary>The hardware id.</summary>
    HardwareId: string;
    //** @abstract(The OEM id.)
    /// <summary>The OEM id.</summary>
    OemId: string;
    //** @abstract(The MAC address.)
    /// <summary>The MAC address.</summary>
    Mac: string;
    //** @abstract(The IP address the device reports for itself.)
    /// <summary>The IP address the device reports for itself.</summary>
    IP: string;
    //** @abstract(The Wi-Fi network the device is on.)
    /// <summary>The Wi-Fi network the device is on.</summary>
    SSID: string;
    //** @abstract(The Wi-Fi signal strength in dBm.)
    /// <summary>The Wi-Fi signal strength in dBm.</summary>
    RSSI: Integer;
    //** @abstract(The Wi-Fi signal level, 0 to 3.)
    /// <summary>The Wi-Fi signal level, 0 to 3.</summary>
    SignalLevel: Integer;
    //** @abstract(The region code.)
    /// <summary>The region code.</summary>
    Region: string;
    //** @abstract(The language code.)
    /// <summary>The language code.</summary>
    Lang: string;
    //** @abstract(The hardware specification code.)
    /// <summary>The hardware specification code.</summary>
    Specs: string;
    //** @abstract(The icon chosen in the Tapo app.)
    /// <summary>The icon chosen in the Tapo app.</summary>
    Avatar: string;
    //** @abstract(The device's offset from UTC in minutes.)
    /// <summary>The device's offset from UTC in minutes.</summary>
    TimeDiff: Int64;
    //** @abstract(The latitude set in the Tapo app, in units of 1/10000 degree.)
    /// <summary>The latitude set in the Tapo app, in units of 1/10000 degree.</summary>
    Latitude: Int64;
    //** @abstract(The longitude set in the Tapo app, in units of 1/10000 degree.)
    /// <summary>The longitude set in the Tapo app, in units of 1/10000 degree.</summary>
    Longitude: Int64;
    //** @abstract(True if a location has been set in the Tapo app.)
    /// <summary>True if a location has been set in the Tapo app.</summary>
    HasSetLocationInfo: Boolean;
    //** @abstract(True if the device reports a power state @(False for hubs and power strips@).)
    /// <summary>True if the device reports a power state (False for hubs and power strips).</summary>
    HasDeviceOn: Boolean;
    //** @abstract(The power state, when @link(HasDeviceOn) is True.)
    /// <summary>The power state, when <see cref="HasDeviceOn"/> is True.</summary>
    DeviceOn: Boolean;
    //** @abstract(Seconds since the device was switched on.)
    /// <summary>Seconds since the device was switched on.</summary>
    OnTime: Int64;
    //** @abstract(The whole device info reply as formatted JSON.)
    /// <summary>The whole device info reply as formatted JSON.</summary>
    Raw: string;
    //** @abstract(Reads device info from a get_device_info / getDeviceInfo reply.)
    //**
    //** @param(Obj The reply's result object. May be nil.)
    //**
    //** @returns(The decoded fields.)
    /// <summary>Reads device info from a get_device_info / getDeviceInfo reply.</summary>
    /// <param name="Obj">The reply's result object. May be nil.</param>
    /// <returns>The decoded fields.</returns>
    class function FromJSON(Obj: TJSONObject): TTapoDeviceInfo; static;
  end;

  TTapoClient = class;
  TTapoDevice = class;

  //** @abstract(Anything that accepts Tapo requests: a device reached by IP address
  //** @(@link(TTapoDevice)@) or a device reached through another one @(@link(TTapoChildDevice)@).)
  //**
  //** The typed methods of the device classes cover everything the devices are known to support.
  //** @link(Execute) gives raw access to any other method.
  /// <summary>
  ///   Anything that accepts Tapo requests: a device reached by IP address
  ///   (<see cref="TTapoDevice"/>) or a device reached through another one
  ///   (<see cref="TTapoChildDevice"/>).
  /// </summary>
  /// <remarks>
  ///   The typed methods of the device classes cover everything the devices
  ///   are known to support. <see cref="Execute"/> gives raw access to any
  ///   other method.
  /// </remarks>
  TTapoEndpoint = class abstract
  protected
    //** @abstract(Sends one request and returns its result.)
    //**
    //** @param(AMethod The method name, for example 'get_device_info'.)
    //**
    //** @param(AParams The params object. Ownership passes to this method. May be nil.)
    //**
    //** @param(AStamp Adds requestTimeMilis and terminalUUID, as the Tapo app does for
    //** set_device_info and the light effects.)
    //**
    //** @returns(The reply's result object, owned by the caller; an empty object if there was none.)
    /// <summary>Sends one request and returns its result.</summary>
    /// <param name="AMethod">The method name, for example 'get_device_info'.</param>
    /// <param name="AParams">The params object. Ownership passes to this method. May be nil.</param>
    /// <param name="AStamp">Adds requestTimeMilis and terminalUUID, as the Tapo app does for set_device_info and the light effects.</param>
    /// <returns>The reply's result object, owned by the caller; an empty object if there was none.</returns>
    function DoRequest(const AMethod: string; AParams: TJSONValue;
      AStamp: Boolean): TJSONObject; virtual; abstract;
  public
    //** @abstract(Calls any device method.)
    //**
    //** @param(AMethod The method name, for example 'get_device_usage'.)
    //**
    //** @param(AParams The params object. Ownership passes to this method; do not free it. May be
    //** nil.)
    //**
    //** @returns(The result object. The caller frees it.)
    //**
    //** @raises(ETapoError The device returned an error.)
    //**
    //** @seealso(ExecuteRequest)
    //**
    //** @seealso(ExecuteStamped)
    //**
    //** Example:
    //** @longCode(#
    //** R := Plug.Execute('get_device_usage');
    //** try
    //**   Memo1.Lines.Add(R.Format);
    //** finally
    //**   R.Free;
    //** end;
    //** #)
    /// <summary>Calls any device method.</summary>
    /// <param name="AMethod">The method name, for example 'get_device_usage'.</param>
    /// <param name="AParams">The params object. Ownership passes to this method; do not free it. May be nil.</param>
    /// <returns>The result object. The caller frees it.</returns>
    /// <exception cref="ETapoError">The device returned an error.</exception>
    /// <example>
    ///   <code>
    ///   R := Plug.Execute('get_device_usage');
    ///   try
    ///     Memo1.Lines.Add(R.Format);
    ///   finally
    ///     R.Free;
    ///   end;
    ///   </code>
    /// </example>
    /// <seealso cref="ExecuteRequest"/>
    /// <seealso cref="ExecuteStamped"/>
    function Execute(const AMethod: string; AParams: TJSONValue = nil): TJSONObject;
    //** @abstract(Same as @link(Execute), but adds requestTimeMilis and terminalUUID to the request
    //** as set_device_info does.)
    //**
    //** @param(AMethod The method name.)
    //**
    //** @param(AParams The params object. Ownership passes to this method. May be nil.)
    //**
    //** @returns(The result object. The caller frees it.)
    /// <summary>
    ///   Same as <see cref="Execute"/>, but adds requestTimeMilis and
    ///   terminalUUID to the request as set_device_info does.
    /// </summary>
    /// <param name="AMethod">The method name.</param>
    /// <param name="AParams">The params object. Ownership passes to this method. May be nil.</param>
    /// <returns>The result object. The caller frees it.</returns>
    function ExecuteStamped(const AMethod: string; AParams: TJSONValue = nil): TJSONObject;
    //** @abstract(Same as @link(Execute), but AParams stays with the caller @(a copy is sent@).)
    //**
    //** @param(AMethod The method name.)
    //**
    //** @param(AParams The params object, still owned by the caller. May be nil.)
    //**
    //** @returns(The result object. The caller frees it.)
    /// <summary>
    ///   Same as <see cref="Execute"/>, but AParams stays with the caller
    ///   (a copy is sent).
    /// </summary>
    /// <param name="AMethod">The method name.</param>
    /// <param name="AParams">The params object, still owned by the caller. May be nil.</param>
    /// <returns>The result object. The caller frees it.</returns>
    function ExecuteRequest(const AMethod: string; AParams: TJSONObject = nil): TJSONObject;
    //** @abstract(Changes device settings with set_device_info.)
    //**
    //** @param(AParams The fields to set, for example {"device_on": true}. Ownership passes to this
    //** method.)
    //**
    //** @raises(ETapoError The device rejected a field.)
    /// <summary>Changes device settings with set_device_info.</summary>
    /// <param name="AParams">The fields to set, for example {"device_on": true}. Ownership passes to this method.</param>
    /// <exception cref="ETapoError">The device rejected a field.</exception>
    procedure SetDeviceInfo(AParams: TJSONObject);
    //** @abstract(Reads the device info.)
    //**
    //** @returns(The device info object. The caller frees it.)
    //**
    //** @seealso(GetDeviceInfoJSON)
    /// <summary>Reads the device info.</summary>
    /// <returns>The device info object. The caller frees it.</returns>
    /// <seealso cref="GetDeviceInfoJSON"/>
    function GetDeviceInfoObject: TJSONObject; virtual;
    //** @abstract(Reads the device info as formatted JSON text.)
    //**
    //** Nickname and SSID are still Base64 encoded, as the device sends them.
    /// <summary>Reads the device info as formatted JSON text.</summary>
    /// <remarks>Nickname and SSID are still Base64 encoded, as the device sends them.</remarks>
    function GetDeviceInfoJSON: string;
    //** @abstract(Reads the list of components @(features and their versions@) the device reports.)
    //**
    //** @returns(Formatted JSON text.)
    /// <summary>Reads the list of components (features and their versions) the device reports.</summary>
    /// <returns>Formatted JSON text.</returns>
    function GetComponentListJSON: string; virtual;
  end;

  //** @abstract(A device reached through a parent device: a power-strip socket or a sensor or switch
  //** paired to a hub.)
  //**
  //** Requests travel inside the parent's session, so a child device never logs in on its own.
  //** Obtain children from the parent (for example @code(Strip.Outlet@(1@)) or
  //** @code(Hub.T31x@('Kitchen'@))); the parent owns them.
  /// <summary>
  ///   A device reached through a parent device: a power-strip socket or a
  ///   sensor or switch paired to a hub.
  /// </summary>
  /// <remarks>
  ///   Requests travel inside the parent's session, so a child device never
  ///   logs in on its own. Obtain children from the parent (for example
  ///   <c>Strip.Outlet(1)</c> or <c>Hub.T31x('Kitchen')</c>); the parent owns
  ///   them.
  /// </remarks>
  TTapoChildDevice = class abstract(TTapoEndpoint)
  private
    FParent: TTapoDevice;
    FDeviceId: string;
  protected
    //** @abstract(Sends the request to the parent, which forwards it to this child.)
    /// <summary>Sends the request to the parent, which forwards it to this child.</summary>
    function DoRequest(const AMethod: string; AParams: TJSONValue;
      AStamp: Boolean): TJSONObject; override;
  public
    //** @abstract(Creates a child device object.)
    //**
    //** Normally called by the parent device, which owns the object.
    //**
    //** @param(AParent The device the child is reached through.)
    //**
    //** @param(ADeviceId The child's device id.)
    /// <summary>Creates a child device object.</summary>
    /// <param name="AParent">The device the child is reached through.</param>
    /// <param name="ADeviceId">The child's device id.</param>
    /// <remarks>Normally called by the parent device, which owns the object.</remarks>
    constructor Create(AParent: TTapoDevice; const ADeviceId: string); virtual;
    //** @abstract(The device this child is reached through.)
    /// <summary>The device this child is reached through.</summary>
    property Parent: TTapoDevice read FParent;
    //** @abstract(The child's device id.)
    /// <summary>The child's device id.</summary>
    property DeviceId: string read FDeviceId;
  end;

  //** @abstract(A child device class, for @link(TTapoDevice.ChildFor).)
  /// <summary>A child device class, for <see cref="TTapoDevice.ChildFor"/>.</summary>
  TTapoChildDeviceClass = class of TTapoChildDevice;

  //** @abstract(A Tapo device reached by IP address: the base class of every device class. It picks
  //** the protocol, logs in, and keeps the session.)
  //**
  //** The device logs in on its first request and keeps the session. If the device ends the session,
  //** the next request logs in again once and is retried. A login rejected for wrong credentials is
  //** never retried, because TPAP devices lock themselves after repeated failures.
  //**
  //** Requests to one device are serialised, so a device object may be shared between threads. All
  //** calls are blocking network I/O; call them from a background thread in an FMX application.
  //**
  //** Create devices through the client (@code(Client.Add@(P110, ...@)), @code(Client.AddDevice) or
  //** @code(Client.AddDetected)), which owns them.
  /// <summary>
  ///   A Tapo device reached by IP address: the base class of every device
  ///   class. It picks the protocol, logs in, and keeps the session.
  /// </summary>
  /// <remarks>
  ///   <para>
  ///     The device logs in on its first request and keeps the session. If
  ///     the device ends the session, the next request logs in again once and
  ///     is retried. A login rejected for wrong credentials is never retried,
  ///     because TPAP devices lock themselves after repeated failures.
  ///   </para>
  ///   <para>
  ///     Requests to one device are serialised, so a device object may be
  ///     shared between threads. All calls are blocking network I/O; call
  ///     them from a background thread in an FMX application.
  ///   </para>
  ///   <para>
  ///     Create devices through the client (<c>Client.Add(P110, ...)</c>,
  ///     <c>Client.AddDevice</c> or <c>Client.AddDetected</c>), which owns them.
  ///   </para>
  /// </remarks>
  TTapoDevice = class abstract(TTapoEndpoint)
  private
    FClient: TTapoClient;
    FHost: string;
    FActive: TTapoProtocol;      // what the current session uses
    FHttp: THTTPClient;
    FLock: TCriticalSection;
    FLoggedIn: Boolean;
    FLastHeaders: string;        // response headers of the last call (diagnostics)
    FAcceptAnyCert: Boolean;     // TPAP over TLS without certificate checks
    FCloseConnection: Boolean;   // send Connection: close (during a TPAP login)
    FChildren: TObjectList<TTapoChildDevice>;
    // KLAP session
    FCookie: string;
    FSessionExpires: TDateTime;
    FKlapKey: TBytes;
    FKlapIV: TBytes;
    FKlapSig: TBytes;
    FKlapSeq: Integer;
    // TPAP device info (from discovery) and session
    FTpapTls: Integer;
    FTpapPort: Integer;
    FTpapPake: TArray<Integer>;
    FTpapUrl: string;
    FTpapDataUrl: string;
    FTpapKey: TBytes;
    FTpapNonce: TBytes;
    FTpapSeq: Integer;
    // AES SSL session
    FAesDataUrl: string;
    FAesKey: TBytes;
    FAesIV: TBytes;
    FAesTagPrefix: string;
    FAesSeq: Integer;

    procedure ValidateCert(const Sender: TObject; const ARequest: TURLRequest;
      const Certificate: TCertificate; var Accepted: Boolean);
    function HttpPost(const AURL, AContentType: string; const ABody: TBytes;
      const ACookie: string; ACaptureCookies: Boolean;
      out AStatus: Integer; out ASetCookie: string;
      const AExtraHeaders: TNetHeaders = nil): TBytes;
    function PostJSON(const AURL: string; ABody: TJSONObject; out AStatus: Integer): TJSONObject;
    function Discover: Boolean;
    procedure KlapHandshake;
    function KlapSend(const AJson: string): string;
    procedure TpapHandshake;
    procedure TpapHandshakeSteps;
    function TpapLoginRequest(const ASubMethod: string; AParams: TJSONObject): TJSONObject;
    function TpapSend(const AJson: string): string;
    function AesHandshake: Boolean;
    function AesSend(const AJson: string): string;
    procedure CameraLogin;
    procedure DoLogin;
    procedure EnsureLoggedIn;
    function ParseResponse(const AMethod, AText: string; out ARetry: Boolean): TJSONObject;
  protected
    //** @abstract(Sends one request over the session, logging in first if needed.)
    /// <summary>Sends one request over the session, logging in first if needed.</summary>
    function DoRequest(const AMethod: string; AParams: TJSONValue;
      AStamp: Boolean): TJSONObject; override;
    //** @abstract(The account name sent in an AES SSL login.)
    //**
    //** @returns('admin' for camera hubs, otherwise the client's user name.)
    /// <summary>The account name sent in an AES SSL login.</summary>
    /// <returns>'admin' for camera hubs, otherwise the client's user name.</returns>
    function LoginUsername: string; virtual;
    //** @abstract(Returns the cached child device object, creating it if needed.)
    //**
    //** @param(ADeviceId The child's device id.)
    //**
    //** @param(AClass The class to create. A cached object of another class is replaced.)
    //**
    //** @returns(The child object, owned by this device.)
    /// <summary>Returns the cached child device object, creating it if needed.</summary>
    /// <param name="ADeviceId">The child's device id.</param>
    /// <param name="AClass">The class to create. A cached object of another class is replaced.</param>
    /// <returns>The child object, owned by this device.</returns>
    function ChildFor(const ADeviceId: string; AClass: TTapoChildDeviceClass): TTapoChildDevice;
  public
    //** @abstract(Creates a device object for the device at AHost.)
    //**
    //** No network request is made until the first call. Usually created through
    //** @link(TTapoClient.AddDevice) or the Tapo.Models helpers.
    //**
    //** @param(AClient The client that holds the account details and owns the device.)
    //**
    //** @param(AHost The IP address, host name, or host:port.)
    //**
    //** @raises(ETapoError AClient is nil.)
    /// <summary>Creates a device object for the device at AHost.</summary>
    /// <param name="AClient">The client that holds the account details and owns the device.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <remarks>
    ///   No network request is made until the first call. Usually created
    ///   through <see cref="TTapoClient.AddDevice"/> or the Tapo.Models helpers.
    /// </remarks>
    /// <exception cref="ETapoError">AClient is nil.</exception>
    constructor Create(AClient: TTapoClient; const AHost: string); virtual;
    //** @abstract(Frees the device and its child objects, and removes it from the client.)
    /// <summary>Frees the device and its child objects, and removes it from the client.</summary>
    destructor Destroy; override;

    //** @abstract(The request format the class uses.)
    /// <summary>The request format the class uses.</summary>
    class function Family: TTapoDeviceFamily; virtual;
    //** @abstract(How the class logs in.)
    /// <summary>How the class logs in.</summary>
    class function AuthMode: TTapoAuthMode; virtual;

    //** @abstract(Picks the protocol and logs in now.)
    //**
    //** Optional: the first request logs in if this has not been called.
    //**
    //** @raises(ETapoError The login failed. ErrorCode -2101 means the device has locked itself
    //** after too many failed logins.)
    /// <summary>Picks the protocol and logs in now.</summary>
    /// <remarks>Optional: the first request logs in if this has not been called.</remarks>
    /// <exception cref="ETapoError">The login failed. ErrorCode -2101 means the device has locked itself after too many failed logins.</exception>
    procedure Login;
    //** @abstract(Forgets the session, so the next request logs in again.)
    //**
    //** The protocol is detected again too, in case a firmware update changed it.
    /// <summary>Forgets the session, so the next request logs in again.</summary>
    /// <remarks>The protocol is detected again too, in case a firmware update changed it.</remarks>
    procedure Logout;
    //** @abstract(Takes over the logged-in session of another object for the same device.)
    //**
    //** Device detection uses this so a detected device does not log in twice.
    //**
    //** @param(ASource An object for the same host, family and auth mode. It is logged out.)
    //**
    //** @raises(ETapoError ASource is for another host or protocol family.)
    /// <summary>Takes over the logged-in session of another object for the same device.</summary>
    /// <param name="ASource">An object for the same host, family and auth mode. It is logged out.</param>
    /// <remarks>Device detection uses this so a detected device does not log in twice.</remarks>
    /// <exception cref="ETapoError">ASource is for another host or protocol family.</exception>
    procedure TakeSession(ASource: TTapoDevice);

    //** @abstract(Reads the device info; cameras and camera hubs return their basic_info section.)
    //**
    //** @returns(The device info object. The caller frees it.)
    /// <summary>Reads the device info; cameras and camera hubs return their basic_info section.</summary>
    /// <returns>The device info object. The caller frees it.</returns>
    function GetDeviceInfoObject: TJSONObject; override;
    //** @abstract(Reads the list of components the device reports.)
    /// <summary>Reads the list of components the device reports.</summary>
    function GetComponentListJSON: string; override;
    //** @abstract(Reads the fields every device reports.)
    //**
    //** @seealso(TTapoDeviceInfo)
    /// <summary>Reads the fields every device reports.</summary>
    /// <seealso cref="TTapoDeviceInfo"/>
    function GetDeviceInfo: TTapoDeviceInfo;
    //** @abstract(Restarts the device.)
    //**
    //** The session ends; the next request logs in again.
    //**
    //** @param(ADelaySeconds Seconds to wait before restarting.)
    /// <summary>Restarts the device.</summary>
    /// <param name="ADelaySeconds">Seconds to wait before restarting.</param>
    /// <remarks>The session ends; the next request logs in again.</remarks>
    procedure Reboot(ADelaySeconds: Integer = 1);
    //** @abstract(Restores the device's factory settings.)
    //**
    //** The device leaves your Tapo account and Wi-Fi network and must be set up again in the Tapo
    //** app.
    /// <summary>Restores the device's factory settings.</summary>
    /// <remarks>
    ///   The device leaves your Tapo account and Wi-Fi network and must be
    ///   set up again in the Tapo app.
    /// </remarks>
    procedure FactoryReset;

    //** @abstract(Sends a request to a child device through this device.)
    //**
    //** Low-level: the child device classes call this for you.
    //**
    //** @param(ADeviceId The child's device id.)
    //**
    //** @param(AMethod The child's method, for example 'get_device_info'.)
    //**
    //** @param(AParams The params object. Ownership passes to this method. May be nil.)
    //**
    //** @returns(The child's result object. The caller frees it.)
    /// <summary>Sends a request to a child device through this device.</summary>
    /// <param name="ADeviceId">The child's device id.</param>
    /// <param name="AMethod">The child's method, for example 'get_device_info'.</param>
    /// <param name="AParams">The params object. Ownership passes to this method. May be nil.</param>
    /// <returns>The child's result object. The caller frees it.</returns>
    /// <remarks>Low-level: the child device classes call this for you.</remarks>
    function ChildRequest(const ADeviceId, AMethod: string; AParams: TJSONValue): TJSONObject;

    //** @abstract(The client that owns this device.)
    /// <summary>The client that owns this device.</summary>
    property Client: TTapoClient read FClient;
    //** @abstract(The address given when the device was added.)
    /// <summary>The address given when the device was added.</summary>
    property Host: string read FHost;
    //** @abstract(True while a session is open.)
    /// <summary>True while a session is open.</summary>
    property LoggedIn: Boolean read FLoggedIn;
    //** @abstract(The protocol of the current session: tpKlap, tpTpap or tpAesSsl; tpAuto before the
    //** first login.)
    /// <summary>The protocol of the current session: tpKlap, tpTpap or tpAesSsl; tpAuto before the first login.</summary>
    property ActiveProtocol: TTapoProtocol read FActive;
  end;

  //** @abstract(A device class, for @link(TTapoClient.AddDevice).)
  /// <summary>A device class, for <see cref="TTapoClient.AddDevice"/>.</summary>
  TTapoDeviceClass = class of TTapoDevice;

  //** @abstract(Your Tapo account, and the devices reached with it.)
  //**
  //** Give the account details once, then add each device by IP address. The client owns the devices
  //** and frees them when it is freed.
  //**
  //** The user name and password are those of the Tapo app. TPAP devices use only the password;
  //** camera hubs use the password with their local "admin" account.
  //**
  //** Example:
  //** @longCode(#
  //** uses Tapo.Client, Tapo.Models, Tapo.Devices;
  //**
  //** Client := TTapoClient.Create('you@example.com', 'password');
  //** try
  //**   Plug := Client.Add(P110, '192.168.1.50');
  //**   ShowMessage(Format('%.1f W', [Plug.GetCurrentPower]));
  //** finally
  //**   Client.Free;
  //** end;
  //** #)
  /// <summary>
  ///   Your Tapo account, and the devices reached with it.
  /// </summary>
  /// <remarks>
  ///   <para>
  ///     Give the account details once, then add each device by IP address.
  ///     The client owns the devices and frees them when it is freed.
  ///   </para>
  ///   <para>
  ///     The user name and password are those of the Tapo app. TPAP devices
  ///     use only the password; camera hubs use the password with their local
  ///     "admin" account.
  ///   </para>
  /// </remarks>
  /// <example>
  ///   <code>
  ///   uses Tapo.Client, Tapo.Models, Tapo.Devices;
  ///
  ///   Client := TTapoClient.Create('you@example.com', 'password');
  ///   try
  ///     Plug := Client.Add(P110, '192.168.1.50');
  ///     ShowMessage(Format('%.1f W', [Plug.GetCurrentPower]));
  ///   finally
  ///     Client.Free;
  ///   end;
  ///   </code>
  /// </example>
  TTapoClient = class
  private
    FUsername: string;
    FPassword: string;
    FProtocol: TTapoProtocol;
    FDevices: TList<TTapoDevice>;
    FListLock: TCriticalSection;
    FConnectionTimeout: Integer;
    FResponseTimeout: Integer;
    procedure RegisterDevice(ADevice: TTapoDevice);
    procedure UnregisterDevice(ADevice: TTapoDevice);
    function GetCount: Integer;
    function GetDevice(AIndex: Integer): TTapoDevice;
  public
    //** @abstract(Creates a client for a Tapo account.)
    //**
    //** @param(AUsername The Tapo app account e-mail.)
    //**
    //** @param(APassword The Tapo app account password @(case-sensitive@).)
    //**
    //** @param(AProtocol Forces one protocol for every device. tpAuto, the default, picks it per
    //** device.)
    /// <summary>Creates a client for a Tapo account.</summary>
    /// <param name="AUsername">The Tapo app account e-mail.</param>
    /// <param name="APassword">The Tapo app account password (case-sensitive).</param>
    /// <param name="AProtocol">Forces one protocol for every device. tpAuto, the default, picks it per device.</param>
    constructor Create(const AUsername, APassword: string; AProtocol: TTapoProtocol = tpAuto);
    //** @abstract(Frees the client and every device it owns.)
    /// <summary>Frees the client and every device it owns.</summary>
    destructor Destroy; override;

    //** @abstract(Adds the device of class T at AHost, or returns the one already added there.)
    //**
    //** No network request is made until the device is first used.
    //**
    //** @param(AHost The IP address, host name, or host:port.)
    //**
    //** @returns(The device, owned by the client.)
    //**
    //** @raises(ETapoError AHost is already registered as another class.)
    //**
    //** Example:
    //** @longCode(#
    //** Plug := Client.AddDevice<TTapoP110>('192.168.1.50');
    //** #)
    /// <summary>Adds the device of class T at AHost, or returns the one already added there.</summary>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client.</returns>
    /// <exception cref="ETapoError">AHost is already registered as another class.</exception>
    /// <remarks>No network request is made until the device is first used.</remarks>
    /// <example>
    ///   <code>Plug := Client.AddDevice&lt;TTapoP110&gt;('192.168.1.50');</code>
    /// </example>
    function AddDevice<T: TTapoDevice>(const AHost: string): T; overload;
    //** @abstract(Adds the device of class AClass at AHost, or returns the one already added there.)
    //**
    //** @param(AClass The device class, for example TTapoP110.)
    //**
    //** @param(AHost The IP address, host name, or host:port.)
    //**
    //** @returns(The device, owned by the client.)
    //**
    //** @raises(ETapoError AHost is already registered as another class.)
    /// <summary>Adds the device of class AClass at AHost, or returns the one already added there.</summary>
    /// <param name="AClass">The device class, for example TTapoP110.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client.</returns>
    /// <exception cref="ETapoError">AHost is already registered as another class.</exception>
    function AddDevice(AClass: TTapoDeviceClass; const AHost: string): TTapoDevice; overload;
    //** @abstract(Finds a device by address.)
    //**
    //** @param(AHost The address the device was added with @(case-insensitive@).)
    //**
    //** @returns(The device, or nil if none was added at AHost.)
    /// <summary>Finds a device by address.</summary>
    /// <param name="AHost">The address the device was added with (case-insensitive).</param>
    /// <returns>The device, or nil if none was added at AHost.</returns>
    function Find(const AHost: string): TTapoDevice;
    //** @abstract(Changes the account details.)
    //**
    //** Every device logs in again on its next request.
    //**
    //** @param(AUsername The Tapo app account e-mail.)
    //**
    //** @param(APassword The Tapo app account password.)
    /// <summary>Changes the account details.</summary>
    /// <param name="AUsername">The Tapo app account e-mail.</param>
    /// <param name="APassword">The Tapo app account password.</param>
    /// <remarks>Every device logs in again on its next request.</remarks>
    procedure SetCredentials(const AUsername, APassword: string);
    //** @abstract(Creates a new client with the same account, protocol and timeouts, and no
    //** devices.)
    //**
    //** Use it for short-lived work that must not touch this client's devices, for example probing
    //** addresses with shorter timeouts during a network scan. A device found that way can be added
    //** to this client and given the probe's login with @link(TTapoDevice.TakeSession).
    //**
    //** @returns(The new client. The caller owns it and must free it.)
    /// <summary>Creates a new client with the same account, protocol and timeouts, and no devices.</summary>
    /// <returns>The new client. The caller owns it and must free it.</returns>
    /// <remarks>
    ///   Use it for short-lived work that must not touch this client's devices,
    ///   for example probing addresses with shorter timeouts during a network
    ///   scan. A device found that way can be added to this client and given
    ///   the probe's login with <see cref="TTapoDevice.TakeSession"/>.
    /// </remarks>
    function CloneEmpty: TTapoClient;

    //** @abstract(Runs known-answer tests of the built-in cryptography. No network access.)
    //**
    //** @param(AReport Receives one line per check, each starting OK or FAIL.)
    //**
    //** @returns(True if every check passed.)
    //**
    //** @seealso(Tapo.Crypto.TapoCryptoSelfTest)
    /// <summary>Runs known-answer tests of the built-in cryptography. No network access.</summary>
    /// <param name="AReport">Receives one line per check, each starting OK or FAIL.</param>
    /// <returns>True if every check passed.</returns>
    /// <seealso cref="Tapo.Crypto.TapoCryptoSelfTest"/>
    class function SelfTest(out AReport: string): Boolean;

    //** @abstract(The Tapo app account e-mail.)
    /// <summary>The Tapo app account e-mail.</summary>
    property Username: string read FUsername;
    //** @abstract(The protocol forced for every device, or tpAuto.)
    /// <summary>The protocol forced for every device, or tpAuto.</summary>
    property Protocol: TTapoProtocol read FProtocol;
    //** @abstract(Connection time-out in milliseconds for devices added from now on @(default
    //** 5000@).)
    //**
    //** Set a short value, such as 500, before scanning a network.
    /// <summary>Connection time-out in milliseconds for devices added from now on (default 5000).</summary>
    /// <remarks>Set a short value, such as 500, before scanning a network.</remarks>
    property ConnectionTimeout: Integer read FConnectionTimeout write FConnectionTimeout;
    //** @abstract(Response time-out in milliseconds for devices added from now on @(default
    //** 10000@).)
    /// <summary>Response time-out in milliseconds for devices added from now on (default 10000).</summary>
    property ResponseTimeout: Integer read FResponseTimeout write FResponseTimeout;
    //** @abstract(The number of devices added.)
    /// <summary>The number of devices added.</summary>
    property Count: Integer read GetCount;
    //** @abstract(The devices added, by index 0 to Count - 1.)
    /// <summary>The devices added, by index 0 to Count - 1.</summary>
    property Devices[AIndex: Integer]: TTapoDevice read GetDevice; default;
  end;

{ JSON helpers shared with the device units }

//** @abstract(Reads an integer field.)
//**
//** Booleans read as 0 or 1 and numeric strings are converted.
//**
//** @param(Obj The object to read from. May be nil.)
//**
//** @param(Name The field name.)
//**
//** @param(Default Returned if the field is missing or not a number.)
/// <summary>Reads an integer field.</summary>
/// <param name="Obj">The object to read from. May be nil.</param>
/// <param name="Name">The field name.</param>
/// <param name="Default">Returned if the field is missing or not a number.</param>
/// <remarks>Booleans read as 0 or 1 and numeric strings are converted.</remarks>
function JInt64(Obj: TJSONObject; const Name: string; Default: Int64 = 0): Int64;
//** @abstract(Reads a floating-point field.)
//**
//** @param(Obj The object to read from. May be nil.)
//**
//** @param(Name The field name.)
//**
//** @param(Default Returned if the field is missing or not a number.)
/// <summary>Reads a floating-point field.</summary>
/// <param name="Obj">The object to read from. May be nil.</param>
/// <param name="Name">The field name.</param>
/// <param name="Default">Returned if the field is missing or not a number.</param>
function JFloat(Obj: TJSONObject; const Name: string; Default: Double = 0): Double;
//** @abstract(Reads a field as text.)
//**
//** @param(Obj The object to read from. May be nil.)
//**
//** @param(Name The field name.)
//**
//** @returns(The value, or an empty string if the field is missing or null.)
/// <summary>Reads a field as text.</summary>
/// <param name="Obj">The object to read from. May be nil.</param>
/// <param name="Name">The field name.</param>
/// <returns>The value, or an empty string if the field is missing or null.</returns>
function JStr(Obj: TJSONObject; const Name: string): string;
//** @abstract(Reads a Boolean field.)
//**
//** Numbers read as True when not 0; the strings '1', 'true' and 'on' read as True.
//**
//** @param(Obj The object to read from. May be nil.)
//**
//** @param(Name The field name.)
//**
//** @param(Default Returned if the field is missing.)
/// <summary>Reads a Boolean field.</summary>
/// <param name="Obj">The object to read from. May be nil.</param>
/// <param name="Name">The field name.</param>
/// <param name="Default">Returned if the field is missing.</param>
/// <remarks>Numbers read as True when not 0; the strings '1', 'true' and 'on' read as True.</remarks>
function JBool(Obj: TJSONObject; const Name: string; Default: Boolean = False): Boolean;
//** @abstract(Reads an object field.)
//**
//** @returns(The object, still owned by Obj, or nil.)
/// <summary>Reads an object field.</summary>
/// <returns>The object, still owned by Obj, or nil.</returns>
function JObj(Obj: TJSONObject; const Name: string): TJSONObject;
//** @abstract(Reads an array field.)
//**
//** @returns(The array, still owned by Obj, or nil.)
/// <summary>Reads an array field.</summary>
/// <returns>The array, still owned by Obj, or nil.</returns>
function JArr(Obj: TJSONObject; const Name: string): TJSONArray;
//** @abstract(Tells whether a field is present and not null.)
/// <summary>Tells whether a field is present and not null.</summary>
function JHas(Obj: TJSONObject; const Name: string): Boolean;
//** @abstract(Reads a Base64 text field, such as nickname or ssid, and decodes it.)
//**
//** @returns(The decoded text; the raw value if it is not valid Base64.)
/// <summary>Reads a Base64 text field, such as nickname or ssid, and decodes it.</summary>
/// <returns>The decoded text; the raw value if it is not valid Base64.</returns>
function JBase64Str(Obj: TJSONObject; const Name: string): string;
//** @abstract(Builds a JSON object from name/value pairs.)
//**
//** @param(Pairs Alternating names and values. Values may be Integer, Int64, Boolean, string,
//** Extended or a TJSONValue, which the new object takes ownership of.)
//**
//** @returns(The new object. The caller frees it, or passes it on to a method that takes ownership.)
//**
//** @raises(ETapoError A name is not a string, or a value has an unsupported type.)
//**
//** Example:
//** @longCode(#
//** Plug.Execute('device_reboot', JObject(['delay', 5])).Free;
//** #)
/// <summary>Builds a JSON object from name/value pairs.</summary>
/// <param name="Pairs">
///   Alternating names and values. Values may be Integer, Int64, Boolean,
///   string, Extended or a TJSONValue, which the new object takes ownership of.
/// </param>
/// <returns>The new object. The caller frees it, or passes it on to a method that takes ownership.</returns>
/// <exception cref="ETapoError">A name is not a string, or a value has an unsupported type.</exception>
/// <example>
///   <code>Plug.Execute('device_reboot', JObject(['delay', 5])).Free;</code>
/// </example>
function JObject(const Pairs: array of const): TJSONObject;
//** @abstract(Builds the SmartCam "section names" parameter, {"name": [ASection]}.)
/// <summary>Builds the SmartCam "section names" parameter, {"name": [ASection]}.</summary>
function JSectionNames(const ASection: string): TJSONObject;
//** @abstract(Reads the error code of a reply.)
//**
//** @returns(error_code, else err_code, else 0 @(SmartCam replies may omit it@).)
/// <summary>Reads the error code of a reply.</summary>
/// <returns>error_code, else err_code, else 0 (SmartCam replies may omit it).</returns>
function TapoErrorCode(Obj: TJSONObject): Integer;
//** @abstract(Finds the data in a SmartCam "get" reply, which nests it as {"section": {"leaf":
//** {...}}}.)
//**
//** @param(AResult The reply's result object.)
//**
//** @returns(The leaf object, still owned by AResult, or nil.)
/// <summary>Finds the data in a SmartCam "get" reply, which nests it as {"section": {"leaf": {...}}}.</summary>
/// <param name="AResult">The reply's result object.</param>
/// <returns>The leaf object, still owned by AResult, or nil.</returns>
function TapoSectionLeaf(AResult: TJSONObject): TJSONObject;
//** @abstract(Names a Tapo error code.)
//**
//** @param(Code An @link(ETapoError.ErrorCode).)
//**
//** @returns(The name used by the Tapo API, for example 'SESSION_EXPIRED', or 'UNKNOWN'.)
/// <summary>Names a Tapo error code.</summary>
/// <param name="Code">An <see cref="ETapoError.ErrorCode"/>.</param>
/// <returns>The name used by the Tapo API, for example 'SESSION_EXPIRED', or 'UNKNOWN'.</returns>
function TapoErrorName(Code: Integer): string;

implementation

const
  TPAP_CIPHER_SUITE = 1;
  TPAP_ENCRYPTION = 'aes_128_ccm';
  TPAP_MAX_ITERATIONS = 100000;
  TERMINAL_UUID = '00-00-00-00-00-00';
  CAMERA_HUB_USERNAME = 'admin';

{ ============================================================================ }
{ JSON helpers                                                                 }
{ ============================================================================ }

function JInt64(Obj: TJSONObject; const Name: string; Default: Int64): Int64;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then
    Exit;
  V := Obj.GetValue(Name);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsInt64
  else if V is TJSONTrue then
    Result := 1
  else if V is TJSONFalse then
    Result := 0
  else if V is TJSONString then
    Result := StrToInt64Def(TJSONString(V).Value, Default);
end;

function JFloat(Obj: TJSONObject; const Name: string; Default: Double): Double;
var
  V: TJSONValue;
  FS: TFormatSettings;
begin
  Result := Default;
  if Obj = nil then
    Exit;
  V := Obj.GetValue(Name);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsDouble
  else if V is TJSONString then
  begin
    FS := TFormatSettings.Invariant;
    Result := StrToFloatDef(TJSONString(V).Value, Default, FS);
  end;
end;

function JStr(Obj: TJSONObject; const Name: string): string;
var
  V: TJSONValue;
begin
  Result := '';
  if Obj = nil then
    Exit;
  V := Obj.GetValue(Name);
  if (V <> nil) and not (V is TJSONNull) then
    Result := V.Value;
end;

function JBool(Obj: TJSONObject; const Name: string; Default: Boolean): Boolean;
var
  V: TJSONValue;
begin
  Result := Default;
  if Obj = nil then
    Exit;
  V := Obj.GetValue(Name);
  if V is TJSONTrue then
    Result := True
  else if V is TJSONFalse then
    Result := False
  else if V is TJSONNumber then
    Result := TJSONNumber(V).AsInt64 <> 0
  else if V is TJSONString then
    Result := (TJSONString(V).Value = '1') or SameText(TJSONString(V).Value, 'true') or
      SameText(TJSONString(V).Value, 'on');
end;

function JObj(Obj: TJSONObject; const Name: string): TJSONObject;
var
  V: TJSONValue;
begin
  Result := nil;
  if Obj = nil then
    Exit;
  V := Obj.GetValue(Name);
  if V is TJSONObject then
    Result := TJSONObject(V);
end;

function JArr(Obj: TJSONObject; const Name: string): TJSONArray;
var
  V: TJSONValue;
begin
  Result := nil;
  if Obj = nil then
    Exit;
  V := Obj.GetValue(Name);
  if V is TJSONArray then
    Result := TJSONArray(V);
end;

function JHas(Obj: TJSONObject; const Name: string): Boolean;
begin
  Result := (Obj <> nil) and (Obj.GetValue(Name) <> nil) and not (Obj.GetValue(Name) is TJSONNull);
end;

function JBase64Str(Obj: TJSONObject; const Name: string): string;
var
  S: string;
begin
  S := JStr(Obj, Name);
  Result := S;
  if S = '' then
    Exit;
  try
    Result := TEncoding.UTF8.GetString(Base64Decode(S));
  except
    Result := S;
  end;
end;

function JObject(const Pairs: array of const): TJSONObject;
var
  I: Integer;
  Key: string;
begin
  Result := TJSONObject.Create;
  I := 0;
  while I + 1 <= High(Pairs) do
  begin
    case Pairs[I].VType of
      vtUnicodeString: Key := string(Pairs[I].VUnicodeString);
      vtString: Key := string(Pairs[I].VString^);
      vtAnsiString: Key := string(AnsiString(Pairs[I].VAnsiString));
      vtWideString: Key := WideString(Pairs[I].VWideString);
      vtChar: Key := string(Pairs[I].VChar);
      vtWideChar: Key := Pairs[I].VWideChar;
      vtPChar: Key := string(Pairs[I].VPChar);
      vtPWideChar: Key := Pairs[I].VPWideChar;
    else
      raise ETapoError.Create('JObject: key must be a string');
    end;
    case Pairs[I + 1].VType of
      vtInteger: Result.AddPair(Key, TJSONNumber.Create(Pairs[I + 1].VInteger));
      vtInt64: Result.AddPair(Key, TJSONNumber.Create(Pairs[I + 1].VInt64^));
      vtBoolean: Result.AddPair(Key, TJSONBool.Create(Pairs[I + 1].VBoolean));
      vtExtended: Result.AddPair(Key, TJSONNumber.Create(Pairs[I + 1].VExtended^));
      vtUnicodeString: Result.AddPair(Key, string(Pairs[I + 1].VUnicodeString));
      vtString: Result.AddPair(Key, string(Pairs[I + 1].VString^));
      vtAnsiString: Result.AddPair(Key, string(AnsiString(Pairs[I + 1].VAnsiString)));
      vtWideString: Result.AddPair(Key, string(WideString(Pairs[I + 1].VWideString)));
      vtChar: Result.AddPair(Key, string(Pairs[I + 1].VChar));
      vtWideChar: Result.AddPair(Key, string(Pairs[I + 1].VWideChar));
      vtPWideChar: Result.AddPair(Key, string(Pairs[I + 1].VPWideChar));
      vtObject:
        if Pairs[I + 1].VObject is TJSONValue then
          Result.AddPair(Key, TJSONValue(Pairs[I + 1].VObject))
        else
          raise ETapoError.Create('JObject: unsupported object value for "' + Key + '"');
    else
      raise ETapoError.Create('JObject: unsupported value type for "' + Key + '"');
    end;
    Inc(I, 2);
  end;
end;

function JSectionNames(const ASection: string): TJSONObject;
var
  A: TJSONArray;
begin
  A := TJSONArray.Create;
  A.Add(ASection);
  Result := JObject(['name', A]);
end;

function TapoErrorCode(Obj: TJSONObject): Integer;
begin
  if JHas(Obj, 'error_code') then
    Result := Integer(JInt64(Obj, 'error_code'))
  else
    Result := Integer(JInt64(Obj, 'err_code', 0));
end;

function TapoSectionLeaf(AResult: TJSONObject): TJSONObject;
var
  Section: TJSONObject;
begin
  Result := nil;
  if (AResult = nil) or (AResult.Count = 0) or not (AResult.Pairs[0].JsonValue is TJSONObject) then
    Exit;
  Section := TJSONObject(AResult.Pairs[0].JsonValue);
  if (Section.Count > 0) and (Section.Pairs[0].JsonValue is TJSONObject) then
    Result := TJSONObject(Section.Pairs[0].JsonValue);
end;

function TapoErrorName(Code: Integer): string;
begin
  case Code of
    -1002: Result := 'UNKNOWN_METHOD';
    -1003: Result := 'JSON_DECODE_FAIL';
    -1004: Result := 'JSON_ENCODE_FAIL';
    -1008: Result := 'PARAMS';
    -1010: Result := 'PUBLIC_KEY';
    -1501: Result := 'LOGIN (check the account e-mail and password)';
    9999:  Result := 'SESSION_TIMEOUT';
    -1802: Result := 'SCHEDULE_FULL';
    -1803: Result := 'SCHEDULE_CONFLICT';
    -1805: Result := 'SCHEDULE_INDEX';
    -2101: Result := 'TPAP_AUTH_ATTEMPTS_LIMIT (device locked after too many failed logins - wait before retrying)';
    -2201: Result := 'TPAP_CIPHER_SUITES_UNSUPPORTED';
    -2202: Result := 'TPAP_PASSCODE_TYPE_UNSUPPORTED';
    -2203: Result := 'TPAP_CREDENTIALS (wrong password - the device locks after too many failures)';
    -2402: Result := 'TPAP_SESSION_INVALID';
    -40106: Result := 'UNSUPPORTED_METHOD';
    -40109: Result := 'ONE_SECOND_REPEAT_REQUEST';
    -40203: Result := 'BIND_SENSOR_EXISTS';
    -40210, 40210: Result := 'PROTOCOL_FORMAT_ERROR';
    -40211: Result := 'MISSING_NECESSARY_PARAMS';
    -40321: Result := 'IP_CONFLICT';
    -40401: Result := 'SESSION_EXPIRED';
    -40404: Result := 'DEVICE_BLOCKED';
    -40405: Result := 'DEVICE_FACTORY';
    -40406: Result := 'OUT_OF_LIMIT';
    -40407: Result := 'OTHER_ERROR';
    -40408: Result := 'SYSTEM_BLOCKED';
    -40409: Result := 'NONCE_EXPIRED';
    -40412: Result := 'HOMEKIT_LOGIN_FAIL';
    -40413: Result := 'INVALID_NONCE';
    -40414: Result := 'NEED_LOGIN_BY_LOCAL_PASSWORD';
    40108: Result := 'TIMEOUT_ERROR';
  else
    Result := 'UNKNOWN';
  end;
end;

// Kept under the name the protocol code below uses.
function ErrorCodeName(Code: Integer): string;
begin
  Result := TapoErrorName(Code);
end;

function IsSessionExpiredCode(Code: Integer): Boolean;
begin
  Result := (Code = 9999) or (Code = -1012) or (Code = -2402) or (Code = -40401);
end;

function UpperHex(const B: TBytes): string;
begin
  Result := UpperCase(BytesToHex(B));
end;

function SHA256HexUpper(const S: string): string;
begin
  Result := UpperHex(SHA256Of(Utf8(S)));
end;

{ ============================================================================ }
{ ETapoError / TTapoDeviceInfo                                                 }
{ ============================================================================ }

constructor ETapoError.CreateCode(ACode: Integer; const AMsg: string);
begin
  inherited Create(AMsg);
  FErrorCode := ACode;
end;

function JStrAlt(Obj: TJSONObject; const AName, AAlias: string): string;
begin
  if JHas(Obj, AName) then
    Result := JStr(Obj, AName)
  else
    Result := JStr(Obj, AAlias);
end;

class function TTapoDeviceInfo.FromJSON(Obj: TJSONObject): TTapoDeviceInfo;
begin
  Result.DeviceId := JStrAlt(Obj, 'device_id', 'dev_id');
  Result.Model := JStrAlt(Obj, 'model', 'device_model');
  Result.DeviceType := JStrAlt(Obj, 'type', 'device_type');
  if JHas(Obj, 'nickname') then
    Result.Nickname := JBase64Str(Obj, 'nickname')       // base64 on Smart devices
  else
    Result.Nickname := JStr(Obj, 'device_alias');        // plain on cameras
  Result.DeviceName := JStr(Obj, 'device_name');
  Result.FirmwareVersion := JStrAlt(Obj, 'fw_ver', 'sw_version');
  Result.HardwareVersion := JStrAlt(Obj, 'hw_ver', 'hw_version');
  Result.FirmwareId := JStr(Obj, 'fw_id');
  Result.HardwareId := JStr(Obj, 'hw_id');
  Result.OemId := JStr(Obj, 'oem_id');
  Result.Mac := JStr(Obj, 'mac');
  Result.IP := JStrAlt(Obj, 'ip', 'local_ip');
  Result.SSID := JBase64Str(Obj, 'ssid');
  Result.RSSI := Integer(JInt64(Obj, 'rssi'));
  Result.SignalLevel := Integer(JInt64(Obj, 'signal_level'));
  Result.Region := JStr(Obj, 'region');
  Result.Lang := JStr(Obj, 'lang');
  Result.Specs := JStr(Obj, 'specs');
  Result.Avatar := JStr(Obj, 'avatar');
  Result.TimeDiff := JInt64(Obj, 'time_diff');
  Result.Latitude := JInt64(Obj, 'latitude');
  Result.Longitude := JInt64(Obj, 'longitude');
  Result.HasSetLocationInfo := JBool(Obj, 'has_set_location_info');
  Result.HasDeviceOn := JHas(Obj, 'device_on');
  Result.DeviceOn := JBool(Obj, 'device_on');
  Result.OnTime := JInt64(Obj, 'on_time');
  if Obj <> nil then
    Result.Raw := Obj.Format
  else
    Result.Raw := '';
end;

{ ============================================================================ }
{ TTapoEndpoint                                                                }
{ ============================================================================ }

function TTapoEndpoint.Execute(const AMethod: string; AParams: TJSONValue): TJSONObject;
begin
  Result := DoRequest(AMethod, AParams, False);
end;

function TTapoEndpoint.ExecuteStamped(const AMethod: string; AParams: TJSONValue): TJSONObject;
begin
  Result := DoRequest(AMethod, AParams, True);
end;

function TTapoEndpoint.ExecuteRequest(const AMethod: string; AParams: TJSONObject): TJSONObject;
begin
  if AParams <> nil then
    Result := DoRequest(AMethod, TJSONObject(AParams.Clone), False)
  else
    Result := DoRequest(AMethod, nil, False);
end;

procedure TTapoEndpoint.SetDeviceInfo(AParams: TJSONObject);
begin
  DoRequest('set_device_info', AParams, True).Free;
end;

function TTapoEndpoint.GetDeviceInfoObject: TJSONObject;
begin
  Result := Execute('get_device_info');
end;

function TTapoEndpoint.GetDeviceInfoJSON: string;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result := R.Format;
  finally
    R.Free;
  end;
end;

function TTapoEndpoint.GetComponentListJSON: string;
var
  R: TJSONObject;
begin
  R := Execute('component_nego');
  try
    Result := R.Format;
  finally
    R.Free;
  end;
end;

{ ============================================================================ }
{ TTapoChildDevice                                                             }
{ ============================================================================ }

constructor TTapoChildDevice.Create(AParent: TTapoDevice; const ADeviceId: string);
begin
  inherited Create;
  FParent := AParent;
  FDeviceId := ADeviceId;
end;

function TTapoChildDevice.DoRequest(const AMethod: string; AParams: TJSONValue;
  AStamp: Boolean): TJSONObject;
begin
  // The app does not stamp requests to a child device.
  Result := FParent.ChildRequest(FDeviceId, AMethod, AParams);
end;

{ ============================================================================ }
{ TTapoDevice                                                                  }
{ ============================================================================ }

constructor TTapoDevice.Create(AClient: TTapoClient; const AHost: string);
begin
  inherited Create;
  if AClient = nil then
    raise ETapoError.Create('A TTapoClient is required');
  FClient := AClient;
  FHost := Trim(AHost);
  FActive := tpAuto;
  FLock := TCriticalSection.Create;
  FChildren := TObjectList<TTapoChildDevice>.Create(True);
  FHttp := THTTPClient.Create;
  FHttp.AllowCookies := False;       // switched per request in HttpPost
  FHttp.HandleRedirects := False;
  FHttp.ConnectionTimeout := AClient.ConnectionTimeout;
  FHttp.ResponseTimeout := AClient.ResponseTimeout;
  FHttp.OnValidateServerCertificate := ValidateCert;
  AClient.RegisterDevice(Self);
end;

destructor TTapoDevice.Destroy;
begin
  if FClient <> nil then
    FClient.UnregisterDevice(Self);
  FChildren.Free;
  FHttp.Free;
  FLock.Free;
  inherited;
end;

class function TTapoDevice.Family: TTapoDeviceFamily;
begin
  Result := dfSmart;
end;

class function TTapoDevice.AuthMode: TTapoAuthMode;
begin
  Result := amNegotiate;
end;

function TTapoDevice.LoginUsername: string;
begin
  if AuthMode = amCameraHub then
    Result := CAMERA_HUB_USERNAME
  else
    Result := FClient.FUsername;
end;

procedure TTapoDevice.Login;
begin
  FLock.Enter;
  try
    DoLogin;
  finally
    FLock.Leave;
  end;
end;

procedure TTapoDevice.Logout;
begin
  FLock.Enter;
  try
    FLoggedIn := False;
    FActive := tpAuto;   // detect again: firmware updates can change the protocol
  finally
    FLock.Leave;
  end;
end;

procedure TTapoDevice.TakeSession(ASource: TTapoDevice);
begin
  if (ASource = nil) or (ASource = Self) then
    Exit;
  if not SameText(ASource.FHost, FHost) or (ASource.Family <> Family) or
     (ASource.AuthMode <> AuthMode) then
    raise ETapoError.CreateCode(-1, 'TakeSession: the source device is for another host or protocol family');
  FLock.Enter;
  ASource.FLock.Enter;
  try
    FActive := ASource.FActive;
    FLoggedIn := ASource.FLoggedIn;
    FAcceptAnyCert := ASource.FAcceptAnyCert;
    FCookie := ASource.FCookie;
    FSessionExpires := ASource.FSessionExpires;
    FKlapKey := ASource.FKlapKey;
    FKlapIV := ASource.FKlapIV;
    FKlapSig := ASource.FKlapSig;
    FKlapSeq := ASource.FKlapSeq;
    FTpapTls := ASource.FTpapTls;
    FTpapPort := ASource.FTpapPort;
    FTpapPake := ASource.FTpapPake;
    FTpapUrl := ASource.FTpapUrl;
    FTpapDataUrl := ASource.FTpapDataUrl;
    FTpapKey := ASource.FTpapKey;
    FTpapNonce := ASource.FTpapNonce;
    FTpapSeq := ASource.FTpapSeq;
    FAesDataUrl := ASource.FAesDataUrl;
    FAesKey := ASource.FAesKey;
    FAesIV := ASource.FAesIV;
    FAesTagPrefix := ASource.FAesTagPrefix;
    FAesSeq := ASource.FAesSeq;
    // the sequence numbers now belong to this device only
    ASource.FLoggedIn := False;
  finally
    ASource.FLock.Leave;
    FLock.Leave;
  end;
end;

function TTapoDevice.ChildFor(const ADeviceId: string; AClass: TTapoChildDeviceClass): TTapoChildDevice;
var
  I: Integer;
begin
  TMonitor.Enter(FChildren);
  try
    for I := 0 to FChildren.Count - 1 do
      if FChildren[I].DeviceId = ADeviceId then
      begin
        if FChildren[I] is AClass then
          Exit(FChildren[I]);
        FChildren.Delete(I);    // asked for as another class: replace it
        Break;
      end;
    Result := AClass.Create(Self, ADeviceId);
    FChildren.Add(Result);
  finally
    TMonitor.Exit(FChildren);
  end;
end;

// Builds the request text, sends it over the session (logging in, and once
// again if the device has ended the session) and returns the result object.
function TTapoDevice.DoRequest(const AMethod: string; AParams: TJSONValue;
  AStamp: Boolean): TJSONObject;
var
  Req, Multi: TJSONObject;
  Requests: TJSONArray;
  Json, RespText: string;
  Attempt: Integer;
  Expired, Retry: Boolean;
begin
  // {"method": ..., "params": ... | null [, "requestTimeMilis": ..., "terminalUUID": ...]}
  Req := TJSONObject.Create;
  try
    Req.AddPair('method', AMethod);
    if AParams <> nil then
      Req.AddPair('params', AParams)
    else
      Req.AddPair('params', TJSONNull.Create);
    AParams := nil;   // owned by Req now
    if AStamp then
    begin
      Req.AddPair('requestTimeMilis', TJSONNumber.Create(DateTimeToUnix(Now, False) * 1000));
      Req.AddPair('terminalUUID', TERMINAL_UUID);
    end;
    if Family = dfSmartCam then
    begin
      // Cameras and camera hubs take a request only inside a multipleRequest.
      Requests := TJSONArray.Create;
      Requests.AddElement(Req);
      Req := nil;
      Multi := TJSONObject.Create;
      try
        Multi.AddPair('method', 'multipleRequest');
        Multi.AddPair('params', JObject(['requests', Requests]));
        Json := Multi.ToJSON;
      finally
        Multi.Free;
      end;
    end
    else
      Json := Req.ToJSON;
  finally
    Req.Free;
    AParams.Free;     // only if AddPair was never reached
  end;

  FLock.Enter;   // sequence numbers must stay in step, so serialise requests
  try
    for Attempt := 1 to 2 do
    begin
      EnsureLoggedIn;
      Expired := False;
      try
        case FActive of
          tpTpap:   RespText := TpapSend(Json);
          tpAesSsl: RespText := AesSend(Json);
        else
          RespText := KlapSend(Json);
        end;
      except
        on ETapoSessionExpired do
        begin
          FLoggedIn := False;
          if Attempt = 2 then
            raise;
          Expired := True;
        end;
      end;
      if Expired then
        Continue;   // log in again and retry once

      Result := ParseResponse(AMethod, RespText, Retry);
      if Retry and (Attempt = 1) then
      begin
        FLoggedIn := False;
        Continue;
      end;
      if Result <> nil then
        Exit;
    end;
  finally
    FLock.Leave;
  end;
  raise ETapoError.CreateCode(-1, FHost + ': request failed after re-authentication');
end;

// Smart:    {"error_code": 0, "result": {...}}
// SmartCam: {"error_code"/"err_code": 0, "result": {"responses": [{"method", "result", "error_code"}]}}
// Returns nil with ARetry = True when the device has ended the session.
function TTapoDevice.ParseResponse(const AMethod, AText: string; out ARetry: Boolean): TJSONObject;
var
  RespValue, ResultValue: TJSONValue;
  Resp, Inner: TJSONObject;
  Responses: TJSONArray;
  Code: Integer;
begin
  Result := nil;
  ARetry := False;
  RespValue := TJSONObject.ParseJSONValue(AText);
  if not (RespValue is TJSONObject) then
  begin
    RespValue.Free;
    raise ETapoError.CreateCode(-1, FHost + ': device returned invalid JSON: ' + AText);
  end;
  Resp := TJSONObject(RespValue);
  try
    if Family = dfSmart then
    begin
      Code := Integer(JInt64(Resp, 'error_code', -1));
      Inner := Resp;
    end
    else
    begin
      Code := TapoErrorCode(Resp);
      Inner := nil;
      if Code = 0 then
      begin
        Responses := JArr(JObj(Resp, 'result'), 'responses');
        if (Responses = nil) or (Responses.Count = 0) or not (Responses.Items[0] is TJSONObject) then
          raise ETapoError.CreateCode(-1, Format('%s: empty response for "%s"', [FHost, AMethod]));
        Inner := TJSONObject(Responses.Items[0]);
        Code := TapoErrorCode(Inner);
      end;
    end;

    if Code <> 0 then
    begin
      if IsSessionExpiredCode(Code) then
      begin
        ARetry := True;
        Exit;
      end;
      raise ETapoError.CreateCode(Code, Format('%s: device returned error_code %d (%s) for "%s"',
        [FHost, Code, TapoErrorName(Code), AMethod]));
    end;

    ResultValue := Inner.GetValue('result');
    if ResultValue is TJSONObject then
      Result := TJSONObject(ResultValue.Clone)
    else
      Result := TJSONObject.Create;
  finally
    Resp.Free;
  end;
end;

function TTapoDevice.ChildRequest(const ADeviceId, AMethod: string;
  AParams: TJSONValue): TJSONObject;
var
  Inner, Multi, R, ResponseData, MultiResult, First: TJSONObject;
  Requests, Responses: TJSONArray;
  Code: Integer;
  V: TJSONValue;
begin
  Inner := TJSONObject.Create;
  Inner.AddPair('method', AMethod);
  if AParams <> nil then
    Inner.AddPair('params', AParams)
  else
    Inner.AddPair('params', TJSONNull.Create);

  if Family = dfSmartCam then
  begin
    // {"childControl": {"device_id": ..., "request_data": {...}}}
    R := Execute('controlChild', JObject(['childControl',
      JObject(['device_id', ADeviceId, 'request_data', Inner])]));
    try
      Code := Integer(JInt64(R, 'err_code', 0));
      if Code <> 0 then
        raise ETapoError.CreateCode(Code, Format('%s: child %s refused "%s": error_code %d (%s)',
          [FHost, ADeviceId, AMethod, Code, TapoErrorName(Code)]));
      First := JObj(R, 'response_data');
      if First = nil then
        raise ETapoError.CreateCode(-1, Format('%s: empty response from child %s for "%s"',
          [FHost, ADeviceId, AMethod]));
      Code := Integer(JInt64(First, 'error_code', 0));
      if Code <> 0 then
        raise ETapoError.CreateCode(Code, Format('%s: child returned error_code %d (%s) for "%s"',
          [FHost, Code, TapoErrorName(Code), AMethod]));
      V := First.GetValue('result');
      if V is TJSONObject then
        Result := TJSONObject(V.Clone)
      else
        Result := TJSONObject.Create;
    finally
      R.Free;
    end;
    Exit;
  end;

  // control_child -> multipleRequest -> the child's own request
  Requests := TJSONArray.Create;
  Requests.AddElement(Inner);
  Multi := TJSONObject.Create;
  Multi.AddPair('method', 'multipleRequest');
  Multi.AddPair('params', JObject(['requests', Requests]));
  R := Execute('control_child', JObject(['device_id', ADeviceId, 'requestData', Multi]));
  try
    ResponseData := JObj(R, 'responseData');
    MultiResult := JObj(ResponseData, 'result');
    Responses := JArr(MultiResult, 'responses');
    if (Responses = nil) or (Responses.Count = 0) or not (Responses.Items[0] is TJSONObject) then
      raise ETapoError.CreateCode(-1, Format('%s: empty response from child %s for "%s"',
        [FHost, ADeviceId, AMethod]));
    First := TJSONObject(Responses.Items[0]);
    Code := Integer(JInt64(First, 'error_code', -1));
    if Code <> 0 then
      raise ETapoError.CreateCode(Code, Format('%s: child returned error_code %d (%s) for "%s"',
        [FHost, Code, TapoErrorName(Code), AMethod]));
    V := First.GetValue('result');
    if V is TJSONObject then
      Result := TJSONObject(V.Clone)
    else
      Result := TJSONObject.Create;
  finally
    R.Free;
  end;
end;

function TTapoDevice.GetDeviceInfoObject: TJSONObject;
var
  R, Leaf: TJSONObject;
begin
  if Family = dfSmart then
    Exit(inherited GetDeviceInfoObject);
  // {"device_info": {"name": ["basic_info"]}} -> {"device_info": {"basic_info": {...}}}
  R := Execute('getDeviceInfo', JObject(['device_info', JSectionNames('basic_info')]));
  try
    Leaf := TapoSectionLeaf(R);
    if Leaf = nil then
      raise ETapoError.CreateCode(-1, FHost + ': getDeviceInfo returned no basic_info');
    Result := TJSONObject(Leaf.Clone);
  finally
    R.Free;
  end;
end;

function TTapoDevice.GetComponentListJSON: string;
var
  R: TJSONObject;
begin
  if Family = dfSmart then
    Exit(inherited GetComponentListJSON);
  R := Execute('getAppComponentList', JObject(['app_component', JSectionNames('app_component_list')]));
  try
    Result := R.Format;
  finally
    R.Free;
  end;
end;

function TTapoDevice.GetDeviceInfo: TTapoDeviceInfo;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result := TTapoDeviceInfo.FromJSON(R);
  finally
    R.Free;
  end;
end;

procedure TTapoDevice.Reboot(ADelaySeconds: Integer);
begin
  Execute('device_reboot', JObject(['delay', ADelaySeconds])).Free;
  Logout;
end;

procedure TTapoDevice.FactoryReset;
begin
  Execute('device_reset').Free;
  Logout;
end;

{ ============================================================================ }
{ TTapoDevice - HTTP, protocol detection, KLAP and TPAP                        }
{ ============================================================================ }

procedure TTapoDevice.ValidateCert(const Sender: TObject; const ARequest: TURLRequest;
  const Certificate: TCertificate; var Accepted: Boolean);
begin
  // Devices announcing TPAP "tls": 1 use a self-signed certificate that the
  // Tapo app does not verify either.
  // Cameras and camera hubs use a self-signed certificate too.
  if FAcceptAnyCert or (Family = dfSmartCam) then
    Accepted := True;
end;

function TTapoDevice.HttpPost(const AURL, AContentType: string; const ABody: TBytes;
  const ACookie: string; ACaptureCookies: Boolean;
  out AStatus: Integer; out ASetCookie: string;
  const AExtraHeaders: TNetHeaders): TBytes;
var
  Src: TBytesStream;
  Dst: TMemoryStream;
  Resp: IHTTPResponse;
  Headers: TNetHeaders;
  H: TNameValuePair;
  C: TCookie;
begin
  SetLength(Headers, 1);
  Headers[0] := TNameValuePair.Create('Content-Type', AContentType);
  if ACookie <> '' then
  begin
    SetLength(Headers, 2);
    Headers[1] := TNameValuePair.Create('Cookie', ACookie);
  end;
  if Length(AExtraHeaders) > 0 then
    Headers := Headers + AExtraHeaders;
  // A camera or camera hub gets a connection per request: hubs close the
  // connection after a login, and cameras refuse a TPAP login on a connection
  // that has carried a session request. A TPAP login does the same (see
  // TpapHandshake).
  if (Family = dfSmartCam) or FCloseConnection then
  begin
    SetLength(Headers, Length(Headers) + 1);
    Headers[High(Headers)] := TNameValuePair.Create('Connection', 'close');
  end;

  // THTTPClient moves Set-Cookie lines out of the header list into its cookie
  // store and drops them entirely when AllowCookies is False, so cookies are
  // only enabled when a session cookie has to be captured (KLAP handshake1).
  FHttp.AllowCookies := ACaptureCookies;

  Src := TBytesStream.Create(ABody);
  Dst := TMemoryStream.Create;
  try
    Resp := FHttp.Post(AURL, Src, Dst, Headers);
    AStatus := Resp.StatusCode;

    ASetCookie := '';
    FLastHeaders := '';
    for H in Resp.Headers do
    begin
      FLastHeaders := FLastHeaders + H.Name + ': ' + H.Value + sLineBreak;
      if SameText(Trim(H.Name), 'Set-Cookie') then
        ASetCookie := ASetCookie + ';' + H.Value;
    end;
    if ACaptureCookies then
    begin
      for C in Resp.Cookies do
        ASetCookie := ASetCookie + ';' + C.Name + '=' + C.Value;
      if FHttp.CookieManager <> nil then
        for C in FHttp.CookieManager.Cookies do
          ASetCookie := ASetCookie + ';' + C.Name + '=' + C.Value;
    end;

    SetLength(Result, Dst.Size);
    if Dst.Size > 0 then
    begin
      Dst.Position := 0;
      Dst.ReadBuffer(Result[0], Dst.Size);
    end;
  finally
    Dst.Free;
    Src.Free;
  end;
end;

function TTapoDevice.PostJSON(const AURL: string; ABody: TJSONObject;
  out AStatus: Integer): TJSONObject;
var
  Body: TBytes;
  Dummy: string;
  V: TJSONValue;
begin
  Result := nil;
  Body := HttpPost(AURL, 'application/json', Utf8(ABody.ToJSON), '', False, AStatus, Dummy);
  if AStatus <> 200 then
    Exit;
  V := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(Body));
  if V is TJSONObject then
    Result := TJSONObject(V)
  else
    V.Free;
end;

{ ============================================================================ }
{ Protocol detection                                                           }
{ ============================================================================ }

// Returns True (and fills FTpap*) when the device announces TPAP.
function TTapoDevice.Discover: Boolean;
var
  Req, Params, Resp, ResultObj, Tpap: TJSONObject;
  Status, Code, I: Integer;
  V: TJSONValue;
  Arr: TJSONArray;
begin
  Result := False;
  Req := TJSONObject.Create;
  try
    Params := TJSONObject.Create;
    Params.AddPair('sub_method', 'discover');
    Req.AddPair('method', 'login');
    Req.AddPair('params', Params);
    // A connection failure propagates: KLAP uses the same address and port.
    Resp := PostJSON('http://' + FHost + '/', Req, Status);
  finally
    Req.Free;
  end;
  if Resp = nil then
    Exit;
  try
    V := Resp.GetValue('error_code');
    if not (V is TJSONNumber) then
      Exit;
    Code := TJSONNumber(V).AsInt;
    if Code = -2101 then
      raise ETapoError.CreateCode(Code, 'Device is locked after too many failed logins (-2101). ' +
        'Wait a while before trying again.');
    if Code <> 0 then
      Exit;
    ResultObj := JObj(Resp, 'result');
    Tpap := JObj(ResultObj, 'tpap');
    if Tpap = nil then
      Exit;

    FTpapTls := Integer(JInt64(Tpap, 'tls', 0));
    FTpapPort := Integer(JInt64(Tpap, 'port', 0));
    FTpapPake := nil;
    V := Tpap.GetValue('pake');
    if V is TJSONArray then
    begin
      Arr := TJSONArray(V);
      SetLength(FTpapPake, Arr.Count);
      for I := 0 to Arr.Count - 1 do
        if Arr.Items[I] is TJSONNumber then
          FTpapPake[I] := TJSONNumber(Arr.Items[I]).AsInt
        else
          FTpapPake[I] := -1;
    end;
    Result := True;
  finally
    Resp.Free;
  end;
end;

{ ============================================================================ }
{ KLAP                                                                         }
{ ============================================================================ }

procedure TTapoDevice.KlapHandshake;
var
  AuthHash, LocalSeed, RemoteSeed, ServerHash, Body, Base, H: TBytes;
  Status, P, TimeoutSec: Integer;
  SetCookie, Part: string;
begin
  FCookie := '';
  AuthHash := SHA256Of(Cat([SHA1Of(Utf8(FClient.FUsername)), SHA1Of(Utf8(FClient.FPassword))]));
  LocalSeed := SecureRandomBytes(16);

  Body := HttpPost('http://' + FHost + '/app/handshake1', 'application/octet-stream',
    LocalSeed, '', True, Status, SetCookie);
  if Status = 403 then
    raise ETapoError.CreateCode(Status, 'KLAP handshake1 forbidden (HTTP 403): turn on ' +
      'Third-Party Compatibility in the Tapo app (Me > Third-Party Services), or use tpAuto ' +
      'so the TPAP protocol is used.');
  if Status <> 200 then
    raise ETapoError.CreateCode(Status, Format('KLAP handshake1 failed (HTTP %d)', [Status]));
  if Length(Body) < 48 then
    raise ETapoError.CreateCode(-1, Format('KLAP handshake1 response too short (%d bytes)',
      [Length(Body)]));

  RemoteSeed := Copy(Body, 0, 16);
  ServerHash := Copy(Body, 16, 32);
  if not BytesEqual(SHA256Of(Cat([LocalSeed, RemoteSeed, AuthHash])), ServerHash) then
    raise ETapoAuthError.CreateCode(-1, 'KLAP handshake1 hash mismatch - check the Tapo account ' +
      'e-mail and password');

  TimeoutSec := 86400;
  for Part in SetCookie.Split([';', ',']) do
  begin
    P := Pos('=', Part);
    if P = 0 then
      Continue;
    if SameText(Trim(Copy(Part, 1, P - 1)), 'TP_SESSIONID') then
      FCookie := Trim(Part)
    else if SameText(Trim(Copy(Part, 1, P - 1)), 'TIMEOUT') then
      TimeoutSec := StrToIntDef(Trim(Copy(Part, P + 1, MaxInt)), TimeoutSec);
  end;
  if FCookie = '' then
    raise ETapoError.CreateCode(-1, 'KLAP handshake1 did not return a TP_SESSIONID cookie. ' +
      'Response headers were:' + sLineBreak + FLastHeaders);

  HttpPost('http://' + FHost + '/app/handshake2', 'application/octet-stream',
    SHA256Of(Cat([RemoteSeed, LocalSeed, AuthHash])), FCookie, False, Status, SetCookie);
  if Status <> 200 then
    raise ETapoError.CreateCode(Status, Format('KLAP handshake2 failed (HTTP %d)', [Status]));

  Base := Cat([LocalSeed, RemoteSeed, AuthHash]);
  FKlapKey := Copy(SHA256Of(Cat([Utf8('lsk'), Base])), 0, 16);
  H := SHA256Of(Cat([Utf8('iv'), Base]));
  FKlapIV := Copy(H, 0, 12);
  FKlapSeq := ReadInt32BE(H, 28);
  FKlapSig := Copy(SHA256Of(Cat([Utf8('ldk'), Base])), 0, 28);
  FSessionExpires := IncSecond(Now, TimeoutSec - 60);
end;

function TTapoDevice.KlapSend(const AJson: string): string;
var
  Seq, Status: Integer;
  IV, CipherBytes, Signature, Body: TBytes;
  SetCookie: string;
begin
  if Now >= FSessionExpires then
    raise ETapoSessionExpired.CreateCode(-1, 'KLAP session timed out');
  FKlapSeq := FKlapSeq + 1;   // wraps (overflow checks are off)
  Seq := FKlapSeq;
  IV := Cat([FKlapIV, Int32BE(Seq)]);

  CipherBytes := AES128CBCEncrypt(FKlapKey, IV, Utf8(AJson));
  Signature := SHA256Of(Cat([FKlapSig, Int32BE(Seq), CipherBytes]));

  Body := HttpPost('http://' + FHost + '/app/request?seq=' + IntToStr(Seq),
    'application/octet-stream', Cat([Signature, CipherBytes]), FCookie, False, Status, SetCookie);
  if (Status = 401) or (Status = 403) then
    raise ETapoSessionExpired.CreateCode(Status, Format('KLAP request rejected (HTTP %d)', [Status]));
  if Status <> 200 then
    raise ETapoError.CreateCode(Status, Format('KLAP request failed (HTTP %d)', [Status]));
  if Length(Body) <= 32 then
    raise ETapoError.CreateCode(-1, Format('KLAP response too short (%d bytes)', [Length(Body)]));

  Result := TEncoding.UTF8.GetString(
    AES128CBCDecrypt(FKlapKey, IV, Copy(Body, 32, Length(Body) - 32)));
end;

{ ============================================================================ }
{ TPAP                                                                         }
{ ============================================================================ }

function TTapoDevice.TpapLoginRequest(const ASubMethod: string; AParams: TJSONObject): TJSONObject;
var
  Req, Resp, R: TJSONObject;
  Status, Code: Integer;
begin
  // AParams is owned by the request from here on.
  Req := TJSONObject.Create;
  try
    AParams.AddPair('sub_method', ASubMethod);
    Req.AddPair('method', 'login');
    Req.AddPair('params', AParams);
    Resp := PostJSON(FTpapUrl + '/', Req, Status);
  finally
    Req.Free;
  end;
  if Status <> 200 then
    raise ETapoError.CreateCode(Status, Format('TPAP %s failed (HTTP %d)', [ASubMethod, Status]));
  if Resp = nil then
    raise ETapoError.CreateCode(-1, Format('TPAP %s: device did not return JSON', [ASubMethod]));
  try
    Code := Integer(JInt64(Resp, 'error_code', -1));
    if Code <> 0 then
    begin
      // -40401 after pake_share means a wrong password, not an expired session
      if (ASubMethod = 'pake_share') and ((Code = -40401) or (Code = -2203)) then
        raise ETapoAuthError.CreateCode(Code, 'TPAP login rejected: wrong password. The password is ' +
          'case-sensitive, and the device locks itself after too many failed logins, so do not ' +
          'retry in a loop.');
      raise ETapoError.CreateCode(Code, Format('TPAP %s failed: error_code %d (%s)',
        [ASubMethod, Code, ErrorCodeName(Code)]));
    end;
    R := JObj(Resp, 'result');
    if R = nil then
      raise ETapoError.CreateCode(-1, Format('TPAP %s returned no result', [ASubMethod]));
    Result := TJSONObject(R.Clone);
  finally
    Resp.Free;
  end;
end;

// Each TPAP login request goes on a new connection. Between pake_register and
// pake_share the client computes the SPAKE2+ proof; a device that closes an
// idle keep-alive connection meanwhile would otherwise make pake_share fail
// with a connection error.
procedure TTapoDevice.TpapHandshake;
begin
  FCloseConnection := True;
  try
    TpapHandshakeSteps;
  finally
    FCloseConnection := False;
  end;
end;

procedure TTapoDevice.TpapHandshakeSteps;
var
  HasUserPw, HasDefault: Boolean;
  I, Iterations: Integer;
  Iter64: Int64;
  Scheme, Credential, Kind: string;
  Port: Integer;
  UserRandom, DeviceRandom, Salt, DeviceShare, DeviceConfirm: TBytes;
  Params, Reg, Share, Extra, ExtraParams: TJSONObject;
  Proof: TSpakeProof;
  Token: string;
  StartSeq: Integer;
begin
  FLoggedIn := False;

  // --- which passcode and URL the device wants
  HasUserPw := False;
  HasDefault := False;
  for I := 0 to High(FTpapPake) do
  begin
    if FTpapPake[I] = 2 then HasUserPw := True;
    if FTpapPake[I] = 0 then HasDefault := True;
  end;
  if not HasUserPw or HasDefault then
    raise ETapoError.CreateCode(-1, 'TPAP: the device asks for a passcode type that is not ' +
      'supported (only the account password, pake [2], is)');

  case FTpapTls of
    0: begin Scheme := 'http'; Port := 80; end;
    1: begin Scheme := 'https'; Port := 443; end;
  else
    raise ETapoError.CreateCode(-1, Format('TPAP over verified TLS (tls %d) is not supported',
      [FTpapTls]));
  end;
  FAcceptAnyCert := FTpapTls = 1;
  if FTpapPort > 0 then
    Port := FTpapPort;
  if (Pos(':', FHost) > 0) and (Pos('[', FHost) = 0) then
    FTpapUrl := Scheme + '://' + FHost                     // caller gave host:port
  else
    FTpapUrl := Format('%s://%s:%d', [Scheme, FHost, Port]);

  // --- pake_register
  UserRandom := SecureRandomBytes(32);
  Params := TJSONObject.Create;
  Params.AddPair('username', BytesToHex(MD5Of(Utf8('admin'))));   // always "admin"
  Params.AddPair('user_random', Base64Encode(UserRandom));
  Params.AddPair('cipher_suites', TJSONArray.Create.Add(TPAP_CIPHER_SUITE));
  Params.AddPair('encryption', TJSONArray.Create.Add(TPAP_ENCRYPTION));
  Params.AddPair('passcode_type', 'userpw');
  Reg := TpapLoginRequest('pake_register', Params);
  try
    if JInt64(Reg, 'cipher_suites', -1) <> TPAP_CIPHER_SUITE then
      raise ETapoError.CreateCode(-1, Format('TPAP: device picked cipher suite %d, which is not supported',
        [JInt64(Reg, 'cipher_suites', -1)]));
    if JStr(Reg, 'encryption') <> TPAP_ENCRYPTION then
      raise ETapoError.CreateCode(-1, 'TPAP: device picked encryption "' + JStr(Reg, 'encryption') +
        '", which is not supported');
    Iter64 := JInt64(Reg, 'iterations', 0);
    if (Iter64 < 1) or (Iter64 > TPAP_MAX_ITERATIONS) then
      raise ETapoError.CreateCode(-1, Format('TPAP: device asks for %d PBKDF2 iterations', [Iter64]));
    Iterations := Integer(Iter64);
    DeviceRandom := Base64Decode(JStr(Reg, 'dev_random'));
    if Length(DeviceRandom) <> 32 then
      raise ETapoError.CreateCode(-1, 'TPAP: dev_random is not 32 bytes');
    Salt := Base64Decode(JStr(Reg, 'dev_salt'));
    DeviceShare := Base64Decode(JStr(Reg, 'dev_share'));

    // Password transform: password_shadow / passwd_id 2 = SHA-1 hex of the password
    Extra := JObj(Reg, 'extra_crypt');
    if Extra = nil then
    begin
      // A camera names no transform and takes the MD5 of the password.
      if Family <> dfSmartCam then
        raise ETapoError.CreateCode(-1, 'TPAP: device names no password transform (extra_crypt), ' +
          'which is not supported');
      Credential := BytesToHex(MD5Of(Utf8(FClient.FPassword)));
      Kind := '';
    end
    else
      Kind := JStr(Extra, 'type');
    ExtraParams := JObj(Extra, 'params');
    if Extra = nil then
      // credential set above
    else if (Kind = 'password_shadow') and (JInt64(ExtraParams, 'passwd_id', -1) = 2) then
      Credential := BytesToHex(SHA1Of(Utf8(FClient.FPassword)))
    else
      raise ETapoError.CreateCode(-1, 'TPAP: unsupported password transform: ' + Extra.ToJSON);
  finally
    Reg.Free;
  end;

  // --- SPAKE2+
  try
    Proof := SpakeProve(Credential, Salt, Iterations, UserRandom, DeviceRandom, DeviceShare);
  except
    on E: ETapoCryptoError do
      raise ETapoError.CreateCode(-1, 'TPAP: ' + E.Message);
  end;

  // --- pake_share
  Params := TJSONObject.Create;
  Params.AddPair('user_share', Base64Encode(Proof.Share));
  Params.AddPair('user_confirm', Base64Encode(Proof.Confirm));
  Share := TpapLoginRequest('pake_share', Params);
  try
    DeviceConfirm := Base64Decode(JStr(Share, 'dev_confirm'));
    Token := JStr(Share, 'stok');
    StartSeq := Integer(JInt64(Share, 'start_seq', 0));
  finally
    Share.Free;
  end;
  if not BytesEqual(HMACSHA256(Proof.VerifierConfirmKey, Proof.Share), DeviceConfirm) then
    raise ETapoError.CreateCode(-1, 'TPAP: the device''s confirmation did not match, so it could ' +
      'not prove that it knows the password');
  if Token = '' then
    raise ETapoError.CreateCode(-1, 'TPAP: pake_share returned no session token (stok)');

  // --- session cipher
  FTpapDataUrl := FTpapUrl + '/stok=' + Token + '/ds';
  FTpapKey := HKDFSHA256(Proof.SharedKey, Utf8('tp-kdf-salt-aes128-key'),
    Utf8('tp-kdf-info-aes128-key'), 16);
  FTpapNonce := HKDFSHA256(Proof.SharedKey, Utf8('tp-kdf-salt-aes128-iv'),
    Utf8('tp-kdf-info-aes128-iv'), 12);
  FTpapSeq := StartSeq;
end;

function TTapoDevice.TpapSend(const AJson: string): string;
var
  Seq, Status, Code: Integer;
  Nonce, Body, Plain: TBytes;
  Dummy: string;
  V: TJSONValue;
begin
  Seq := FTpapSeq;
  FTpapSeq := FTpapSeq + 1;   // wraps (overflow checks are off)
  Nonce := Cat([Copy(FTpapNonce, 0, 8), Int32BE(Seq)]);

  Body := HttpPost(FTpapDataUrl, 'application/octet-stream',
    Cat([Int32BE(Seq), AES128CCMEncrypt(FTpapKey, Nonce, Utf8(AJson))]),
    '', False, Status, Dummy);
  if (Status = 401) or (Status = 403) then
    raise ETapoSessionExpired.CreateCode(Status, Format('TPAP request rejected (HTTP %d)', [Status]));
  if Status <> 200 then
    raise ETapoError.CreateCode(Status, Format('TPAP request failed (HTTP %d)', [Status]));

  // body = 4-byte sequence number || ciphertext || 16-byte tag
  if (Length(Body) >= 20) and (ReadInt32BE(Body, 0) = Seq) and
     AES128CCMDecrypt(FTpapKey, Nonce, Copy(Body, 4, Length(Body) - 4), Plain) then
    Exit(TEncoding.UTF8.GetString(Plain));

  // A device that no longer knows the session answers with plain JSON.
  Code := 0;
  V := nil;
  try
    V := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(Body));
    if V is TJSONObject then
      Code := Integer(JInt64(TJSONObject(V), 'error_code', 0));
  except
    Code := 0;
  end;
  V.Free;
  if Code <> 0 then
    raise ETapoSessionExpired.CreateCode(Code, Format('TPAP session no longer valid (error_code %d)', [Code]));
  raise ETapoError.CreateCode(-1, Format('TPAP response (%d bytes) could not be decrypted', [Length(Body)]));
end;

{ ============================================================================ }
{ AES SSL (cameras, camera hubs)                                               }
{ ============================================================================ }

// Returns False when the device does not take the AES SSL login at all
// (-40211, e.g. a camera with Third-Party Compatibility off).
function TTapoDevice.AesHandshake: Boolean;
var
  Url, LocalNonce, ServerNonce, DeviceConfirm, PwHash, Candidate, Username: string;
  Req, Resp, Data, R: TJSONObject;
  Status, Code: Integer;
  Candidates: array[0..1] of string;
  I: Integer;
  HashedKey, Token: string;
begin
  Result := True;
  FAcceptAnyCert := True;     // self-signed certificate
  Url := 'https://' + FHost;
  Username := LoginUsername;
  LocalNonce := UpperHex(SecureRandomBytes(8));

  // --- handshake 1: the device answers INVALID_NONCE (-40413) with its nonce
  Req := JObject(['method', 'login', 'params',
    JObject(['cnonce', LocalNonce, 'encrypt_type', '3', 'username', Username])]);
  try
    Resp := PostJSON(Url, Req, Status);
  finally
    Req.Free;
  end;
  if Status <> 200 then
    raise ETapoError.CreateCode(Status, Format('%s: AES SSL handshake1 failed (HTTP %d)', [FHost, Status]));
  if Resp = nil then
    raise ETapoError.CreateCode(-1, FHost + ': AES SSL handshake1 did not return JSON');
  try
    Code := Integer(JInt64(Resp, 'error_code', 0));
    if Code = -40211 then
      Exit(False);
    if Code <> -40413 then
      raise ETapoError.CreateCode(Code, Format('%s: AES SSL handshake1 expected INVALID_NONCE (-40413), got %d (%s)',
        [FHost, Code, TapoErrorName(Code)]));
    Data := JObj(JObj(Resp, 'result'), 'data');
    ServerNonce := JStr(Data, 'nonce');
    DeviceConfirm := JStr(Data, 'device_confirm');
  finally
    Resp.Free;
  end;

  // The password hash is SHA-256, or MD5 on older firmware; the device
  // confirm says which.
  Candidates[0] := SHA256HexUpper(FClient.FPassword);
  Candidates[1] := UpperHex(MD5Of(Utf8(FClient.FPassword)));
  PwHash := '';
  for I := 0 to 1 do
  begin
    Candidate := Candidates[I];
    if SHA256HexUpper(LocalNonce + Candidate + ServerNonce) + ServerNonce + LocalNonce = DeviceConfirm then
    begin
      PwHash := Candidate;
      Break;
    end;
  end;
  if PwHash = '' then
    raise ETapoAuthError.CreateCode(-1, FHost + ': AES SSL device confirm did not match - check the password');

  // --- handshake 2
  Req := JObject(['method', 'login', 'params',
    JObject(['cnonce', LocalNonce, 'encrypt_type', '3',
      'digest_passwd', SHA256HexUpper(PwHash + LocalNonce + ServerNonce) + LocalNonce + ServerNonce,
      'username', Username])]);
  try
    Resp := PostJSON(Url, Req, Status);
  finally
    Req.Free;
  end;
  if Status <> 200 then
    raise ETapoError.CreateCode(Status, Format('%s: AES SSL handshake2 failed (HTTP %d)', [FHost, Status]));
  if Resp = nil then
    raise ETapoError.CreateCode(-1, FHost + ': AES SSL handshake2 did not return JSON');
  try
    Code := Integer(JInt64(Resp, 'error_code', -1));
    if Code <> 0 then
      raise ETapoError.CreateCode(Code, Format('%s: AES SSL login failed: error_code %d (%s)',
        [FHost, Code, TapoErrorName(Code)]));
    R := JObj(Resp, 'result');
    Token := JStr(R, 'stok');
    FAesSeq := Integer(JInt64(R, 'start_seq', 0));
  finally
    Resp.Free;
  end;
  if Token = '' then
    raise ETapoError.CreateCode(-1, FHost + ': AES SSL login returned no session token');

  // --- session cipher
  HashedKey := SHA256HexUpper(LocalNonce + PwHash + ServerNonce);
  FAesKey := Copy(SHA256Of(Utf8('lsk' + LocalNonce + ServerNonce + HashedKey)), 0, 16);
  FAesIV := Copy(SHA256Of(Utf8('ivb' + LocalNonce + ServerNonce + HashedKey)), 0, 16);
  FAesTagPrefix := SHA256HexUpper(PwHash + LocalNonce);
  FAesDataUrl := Url + '/stok=' + Token + '/ds';
end;

function TTapoDevice.AesSend(const AJson: string): string;
var
  Wrapper, Tag, Dummy, Encrypted: string;
  Seq, Status, Code: Integer;
  W, Body: TJSONObject;
  Headers: TNetHeaders;
  RespBytes: TBytes;
  V: TJSONValue;
begin
  W := JObject(['method', 'securePassthrough', 'params',
    JObject(['request', Base64Encode(AES128CBCEncrypt(FAesKey, FAesIV, Utf8(AJson)))])]);
  try
    Wrapper := W.ToJSON;
  finally
    W.Free;
  end;
  Seq := FAesSeq;
  FAesSeq := FAesSeq + 1;
  Tag := SHA256HexUpper(FAesTagPrefix + Wrapper + IntToStr(Seq));

  SetLength(Headers, 2);
  Headers[0] := TNameValuePair.Create('Seq', IntToStr(Seq));
  Headers[1] := TNameValuePair.Create('Tapo_tag', Tag);
  RespBytes := HttpPost(FAesDataUrl, 'application/json', Utf8(Wrapper), '', False,
    Status, Dummy, Headers);
  if (Status = 401) or (Status = 403) then
    raise ETapoSessionExpired.CreateCode(Status, Format('AES SSL request rejected (HTTP %d)', [Status]));
  if Status <> 200 then
    raise ETapoError.CreateCode(Status, Format('%s: AES SSL request failed (HTTP %d)', [FHost, Status]));

  Result := TEncoding.UTF8.GetString(RespBytes);
  V := TJSONObject.ParseJSONValue(Result);
  if not (V is TJSONObject) then
  begin
    V.Free;
    raise ETapoError.CreateCode(-1, FHost + ': AES SSL response is not JSON: ' + Result);
  end;
  Body := TJSONObject(V);
  try
    Code := TapoErrorCode(Body);
    if IsSessionExpiredCode(Code) then
      raise ETapoSessionExpired.CreateCode(Code, Format('AES SSL session ended (error_code %d)', [Code]));
    if Code <> 0 then
      raise ETapoError.CreateCode(Code, Format('%s: device returned error_code %d (%s)',
        [FHost, Code, TapoErrorName(Code)]));
    // Camera hubs encrypt the reply inside the envelope; cameras answer in plain text.
    Encrypted := JStr(JObj(Body, 'result'), 'response');
    if Encrypted <> '' then
      Result := TEncoding.UTF8.GetString(AES128CBCDecrypt(FAesKey, FAesIV, Base64Decode(Encrypted)));
  finally
    Body.Free;
  end;
end;

// Cameras: TPAP over HTTPS first; AES SSL if the camera does not take that
// login (unless it cannot be reached at all or has locked itself).
procedure TTapoDevice.CameraLogin;
var
  TpapMsg: string;
  TpapCode: Integer;
  TpapAuth: Boolean;
begin
  TpapMsg := '';
  TpapCode := 0;
  TpapAuth := False;
  if FClient.FProtocol <> tpAesSsl then
  begin
    FTpapTls := 1;
    FTpapPort := 0;
    FTpapPake := [2];
    try
      TpapHandshake;
      FActive := tpTpap;
      Exit;
    except
      on E: ENetHTTPClientException do
        raise;
      on E: ETapoError do
      begin
        if (E.ErrorCode = -2101) or (FClient.FProtocol = tpTpap) then
          raise;
        TpapMsg := E.Message;
        TpapCode := E.ErrorCode;
        TpapAuth := E is ETapoAuthError;
      end;
    end;
  end;

  if AesHandshake then
    FActive := tpAesSsl
  else if TpapAuth then
    raise ETapoAuthError.CreateCode(TpapCode, TpapMsg)
  else if TpapMsg <> '' then
    raise ETapoError.CreateCode(TpapCode, TpapMsg)
  else
    raise ETapoError.CreateCode(-40211, FHost + ': the camera does not take the AES SSL login. ' +
      'Turn on Third-Party Compatibility in the Tapo app, or use tpAuto.');
end;

{ ============================================================================ }
{ Login                                                                        }
{ ============================================================================ }

procedure TTapoDevice.DoLogin;
begin
  FLoggedIn := False;
  case AuthMode of
    amCameraHub:
      begin
        if not AesHandshake then
          raise ETapoError.CreateCode(-40211, FHost + ': the hub does not take the AES SSL login');
        FActive := tpAesSsl;
      end;
    amCamera:
      CameraLogin;
  else
    if FActive = tpAuto then
    begin
      case FClient.FProtocol of
        tpKlap:
          FActive := tpKlap;
        tpTpap:
          if Discover then
            FActive := tpTpap
          else
            raise ETapoError.CreateCode(-1, FHost + ': the device does not announce TPAP (it is in KLAP mode)');
        tpAesSsl:
          FActive := tpAesSsl;
      else
        if Discover then
          FActive := tpTpap
        else
          FActive := tpKlap;
      end;
    end;
    case FActive of
      tpTpap: TpapHandshake;
      tpAesSsl:
        if not AesHandshake then
          raise ETapoError.CreateCode(-40211, FHost + ': the device does not take the AES SSL login');
    else
      KlapHandshake;
    end;
  end;
  FLoggedIn := True;
end;

procedure TTapoDevice.EnsureLoggedIn;
begin
  if not FLoggedIn then
    DoLogin;
end;

{ ============================================================================ }
{ TTapoClient                                                                  }
{ ============================================================================ }

constructor TTapoClient.Create(const AUsername, APassword: string; AProtocol: TTapoProtocol);
begin
  inherited Create;
  FUsername := AUsername;
  FPassword := APassword;
  FProtocol := AProtocol;
  FDevices := TList<TTapoDevice>.Create;
  FListLock := TCriticalSection.Create;
  FConnectionTimeout := 5000;
  FResponseTimeout := 10000;
end;

destructor TTapoClient.Destroy;
begin
  if FDevices <> nil then
    while FDevices.Count > 0 do
      FDevices.Last.Free;     // a device removes itself from the list
  FDevices.Free;
  FListLock.Free;
  inherited;
end;

procedure TTapoClient.RegisterDevice(ADevice: TTapoDevice);
begin
  FListLock.Enter;
  try
    FDevices.Add(ADevice);
  finally
    FListLock.Leave;
  end;
end;

procedure TTapoClient.UnregisterDevice(ADevice: TTapoDevice);
begin
  FListLock.Enter;
  try
    FDevices.Remove(ADevice);
  finally
    FListLock.Leave;
  end;
end;

function TTapoClient.GetCount: Integer;
begin
  FListLock.Enter;
  try
    Result := FDevices.Count;
  finally
    FListLock.Leave;
  end;
end;

function TTapoClient.GetDevice(AIndex: Integer): TTapoDevice;
begin
  FListLock.Enter;
  try
    Result := FDevices[AIndex];
  finally
    FListLock.Leave;
  end;
end;

function TTapoClient.Find(const AHost: string): TTapoDevice;
var
  D: TTapoDevice;
begin
  Result := nil;
  FListLock.Enter;
  try
    for D in FDevices do
      if SameText(D.Host, Trim(AHost)) then
        Exit(D);
  finally
    FListLock.Leave;
  end;
end;

function TTapoClient.AddDevice(AClass: TTapoDeviceClass; const AHost: string): TTapoDevice;
begin
  Result := Find(AHost);
  if Result <> nil then
  begin
    if Result.ClassType <> AClass then
      raise ETapoError.CreateCode(-1, Format('%s is already registered as a %s',
        [AHost, Result.ClassName]));
    Exit;
  end;
  Result := AClass.Create(Self, AHost);
end;

function TTapoClient.AddDevice<T>(const AHost: string): T;
begin
  Result := AddDevice(TTapoDeviceClass(GetTypeData(TypeInfo(T))^.ClassType), AHost) as T;
end;

function TTapoClient.CloneEmpty: TTapoClient;
begin
  Result := TTapoClient.Create(FUsername, FPassword, FProtocol);
  Result.FConnectionTimeout := FConnectionTimeout;
  Result.FResponseTimeout := FResponseTimeout;
end;

procedure TTapoClient.SetCredentials(const AUsername, APassword: string);
var
  I: Integer;
begin
  FUsername := AUsername;
  FPassword := APassword;
  for I := 0 to Count - 1 do
    Devices[I].Logout;
end;

class function TTapoClient.SelfTest(out AReport: string): Boolean;
begin
  Result := TapoCryptoSelfTest(AReport);
end;

end.
