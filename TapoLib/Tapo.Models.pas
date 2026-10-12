unit Tapo.Models;

{
  Model tags for TTapoClient.Add, so a device is added by its model name:

    Plug  := Client.Add(P110, '192.168.1.50');    // TTapoP110
    Bulb  := Client.Add(L530B, '192.168.1.51');   // TTapoL530
    Strip := Client.Add(P304M, '192.168.1.52');   // TTapoP304M
    Hub   := Client.Add(H100, '192.168.1.53');    // TTapoH100
    Cam   := Client.Add(C210, '192.168.1.54');    // TTapoCamera

  Each tag is a typed constant of its own record type, so the compiler picks
  the overload that returns the right class. If a tag name clashes with an
  identifier of your own, qualify it: Tapo.Models.P110.

  Add(AModelName: string, ...) does the same at run time, from a model name
  such as one read from a configuration file.

  AddDetected(AHost) needs no model at all: it logs in, reads the device
  info and adds the device as the matching class - for network scanning:

    if Client.TryAddDetected('192.168.1.60', Dev, Err) then
      if Dev is TTapoP110 then ...

  Generated from the model list of the Rust crate; one entry per model.
}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.URLClient,
  Tapo.Client, Tapo.Devices, Tapo.Hubs, Tapo.Cameras;

type
  (*** The tag type of the @link(L510) model constant. *)
  /// <summary>The tag type of the <see cref="L510"/> model constant.</summary>
  TTapoModelL510 = record Name: string; end;
  (*** The tag type of the @link(L510B) model constant. *)
  /// <summary>The tag type of the <see cref="L510B"/> model constant.</summary>
  TTapoModelL510B = record Name: string; end;
  (*** The tag type of the @link(L520) model constant. *)
  /// <summary>The tag type of the <see cref="L520"/> model constant.</summary>
  TTapoModelL520 = record Name: string; end;
  (*** The tag type of the @link(L610) model constant. *)
  /// <summary>The tag type of the <see cref="L610"/> model constant.</summary>
  TTapoModelL610 = record Name: string; end;
  (*** The tag type of the @link(L530) model constant. *)
  /// <summary>The tag type of the <see cref="L530"/> model constant.</summary>
  TTapoModelL530 = record Name: string; end;
  (*** The tag type of the @link(L530B) model constant. *)
  /// <summary>The tag type of the <see cref="L530B"/> model constant.</summary>
  TTapoModelL530B = record Name: string; end;
  (*** The tag type of the @link(L535) model constant. *)
  /// <summary>The tag type of the <see cref="L535"/> model constant.</summary>
  TTapoModelL535 = record Name: string; end;
  (*** The tag type of the @link(L630) model constant. *)
  /// <summary>The tag type of the <see cref="L630"/> model constant.</summary>
  TTapoModelL630 = record Name: string; end;
  (*** The tag type of the @link(L900) model constant. *)
  /// <summary>The tag type of the <see cref="L900"/> model constant.</summary>
  TTapoModelL900 = record Name: string; end;
  (*** The tag type of the @link(L920) model constant. *)
  /// <summary>The tag type of the <see cref="L920"/> model constant.</summary>
  TTapoModelL920 = record Name: string; end;
  (*** The tag type of the @link(L930) model constant. *)
  /// <summary>The tag type of the <see cref="L930"/> model constant.</summary>
  TTapoModelL930 = record Name: string; end;
  (*** The tag type of the @link(P100) model constant. *)
  /// <summary>The tag type of the <see cref="P100"/> model constant.</summary>
  TTapoModelP100 = record Name: string; end;
  (*** The tag type of the @link(P105) model constant. *)
  /// <summary>The tag type of the <see cref="P105"/> model constant.</summary>
  TTapoModelP105 = record Name: string; end;
  (*** The tag type of the @link(P125) model constant. *)
  /// <summary>The tag type of the <see cref="P125"/> model constant.</summary>
  TTapoModelP125 = record Name: string; end;
  (*** The tag type of the @link(P125M) model constant. *)
  /// <summary>The tag type of the <see cref="P125M"/> model constant.</summary>
  TTapoModelP125M = record Name: string; end;
  (*** The tag type of the @link(P110) model constant. *)
  /// <summary>The tag type of the <see cref="P110"/> model constant.</summary>
  TTapoModelP110 = record Name: string; end;
  (*** The tag type of the @link(P110M) model constant. *)
  /// <summary>The tag type of the <see cref="P110M"/> model constant.</summary>
  TTapoModelP110M = record Name: string; end;
  (*** The tag type of the @link(P115) model constant. *)
  /// <summary>The tag type of the <see cref="P115"/> model constant.</summary>
  TTapoModelP115 = record Name: string; end;
  (*** The tag type of the @link(P300) model constant. *)
  /// <summary>The tag type of the <see cref="P300"/> model constant.</summary>
  TTapoModelP300 = record Name: string; end;
  (*** The tag type of the @link(P306) model constant. *)
  /// <summary>The tag type of the <see cref="P306"/> model constant.</summary>
  TTapoModelP306 = record Name: string; end;
  (*** The tag type of the @link(P304M) model constant. *)
  /// <summary>The tag type of the <see cref="P304M"/> model constant.</summary>
  TTapoModelP304M = record Name: string; end;
  (*** The tag type of the @link(P316M) model constant. *)
  /// <summary>The tag type of the <see cref="P316M"/> model constant.</summary>
  TTapoModelP316M = record Name: string; end;
  (*** The tag type of the @link(H100) model constant. *)
  /// <summary>The tag type of the <see cref="H100"/> model constant.</summary>
  TTapoModelH100 = record Name: string; end;
  (*** The tag type of the @link(H200) model constant. *)
  /// <summary>The tag type of the <see cref="H200"/> model constant.</summary>
  TTapoModelH200 = record Name: string; end;
  (*** The tag type of the @link(H500) model constant. *)
  /// <summary>The tag type of the <see cref="H500"/> model constant.</summary>
  TTapoModelH500 = record Name: string; end;
  (*** The tag type of the @link(C210) model constant. *)
  /// <summary>The tag type of the <see cref="C210"/> model constant.</summary>
  TTapoModelC210 = record Name: string; end;
  (*** The tag type of the @link(C220) model constant. *)
  /// <summary>The tag type of the <see cref="C220"/> model constant.</summary>
  TTapoModelC220 = record Name: string; end;
  (*** The tag type of the @link(C225) model constant. *)
  /// <summary>The tag type of the <see cref="C225"/> model constant.</summary>
  TTapoModelC225 = record Name: string; end;
  (*** The tag type of the @link(C325WB) model constant. *)
  /// <summary>The tag type of the <see cref="C325WB"/> model constant.</summary>
  TTapoModelC325WB = record Name: string; end;
  (*** The tag type of the @link(C520WS) model constant. *)
  /// <summary>The tag type of the <see cref="C520WS"/> model constant.</summary>
  TTapoModelC520WS = record Name: string; end;
  (*** The tag type of the @link(TC40) model constant. *)
  /// <summary>The tag type of the <see cref="TC40"/> model constant.</summary>
  TTapoModelTC40 = record Name: string; end;
  (*** The tag type of the @link(TC70) model constant. *)
  /// <summary>The tag type of the <see cref="TC70"/> model constant.</summary>
  TTapoModelTC70 = record Name: string; end;

const
  (*** Tapo L510: @code(Client.Add@(L510, Host@)) returns a @link(TTapoL510). *)
  /// <summary>Tapo L510: <c>Client.Add(L510, Host)</c> returns a <see cref="Tapo.Devices|TTapoL510"/>.</summary>
  L510: TTapoModelL510 = (Name: 'L510');
  (*** Tapo L510B: @code(Client.Add@(L510B, Host@)) returns a @link(TTapoL510). *)
  /// <summary>Tapo L510B: <c>Client.Add(L510B, Host)</c> returns a <see cref="Tapo.Devices|TTapoL510"/>.</summary>
  L510B: TTapoModelL510B = (Name: 'L510B');
  (*** Tapo L520: @code(Client.Add@(L520, Host@)) returns a @link(TTapoL510). *)
  /// <summary>Tapo L520: <c>Client.Add(L520, Host)</c> returns a <see cref="Tapo.Devices|TTapoL510"/>.</summary>
  L520: TTapoModelL520 = (Name: 'L520');
  (*** Tapo L610: @code(Client.Add@(L610, Host@)) returns a @link(TTapoL510). *)
  /// <summary>Tapo L610: <c>Client.Add(L610, Host)</c> returns a <see cref="Tapo.Devices|TTapoL510"/>.</summary>
  L610: TTapoModelL610 = (Name: 'L610');
  (*** Tapo L530: @code(Client.Add@(L530, Host@)) returns a @link(TTapoL530). *)
  /// <summary>Tapo L530: <c>Client.Add(L530, Host)</c> returns a <see cref="Tapo.Devices|TTapoL530"/>.</summary>
  L530: TTapoModelL530 = (Name: 'L530');
  (*** Tapo L530B: @code(Client.Add@(L530B, Host@)) returns a @link(TTapoL530). *)
  /// <summary>Tapo L530B: <c>Client.Add(L530B, Host)</c> returns a <see cref="Tapo.Devices|TTapoL530"/>.</summary>
  L530B: TTapoModelL530B = (Name: 'L530B');
  (*** Tapo L535: @code(Client.Add@(L535, Host@)) returns a @link(TTapoL530). *)
  /// <summary>Tapo L535: <c>Client.Add(L535, Host)</c> returns a <see cref="Tapo.Devices|TTapoL530"/>.</summary>
  L535: TTapoModelL535 = (Name: 'L535');
  (*** Tapo L630: @code(Client.Add@(L630, Host@)) returns a @link(TTapoL530). *)
  /// <summary>Tapo L630: <c>Client.Add(L630, Host)</c> returns a <see cref="Tapo.Devices|TTapoL530"/>.</summary>
  L630: TTapoModelL630 = (Name: 'L630');
  (*** Tapo L900: @code(Client.Add@(L900, Host@)) returns a @link(TTapoL900). *)
  /// <summary>Tapo L900: <c>Client.Add(L900, Host)</c> returns a <see cref="Tapo.Devices|TTapoL900"/>.</summary>
  L900: TTapoModelL900 = (Name: 'L900');
  (*** Tapo L920: @code(Client.Add@(L920, Host@)) returns a @link(TTapoL920). *)
  /// <summary>Tapo L920: <c>Client.Add(L920, Host)</c> returns a <see cref="Tapo.Devices|TTapoL920"/>.</summary>
  L920: TTapoModelL920 = (Name: 'L920');
  (*** Tapo L930: @code(Client.Add@(L930, Host@)) returns a @link(TTapoL920). *)
  /// <summary>Tapo L930: <c>Client.Add(L930, Host)</c> returns a <see cref="Tapo.Devices|TTapoL920"/>.</summary>
  L930: TTapoModelL930 = (Name: 'L930');
  (*** Tapo P100: @code(Client.Add@(P100, Host@)) returns a @link(TTapoP100). *)
  /// <summary>Tapo P100: <c>Client.Add(P100, Host)</c> returns a <see cref="Tapo.Devices|TTapoP100"/>.</summary>
  P100: TTapoModelP100 = (Name: 'P100');
  (*** Tapo P105: @code(Client.Add@(P105, Host@)) returns a @link(TTapoP100). *)
  /// <summary>Tapo P105: <c>Client.Add(P105, Host)</c> returns a <see cref="Tapo.Devices|TTapoP100"/>.</summary>
  P105: TTapoModelP105 = (Name: 'P105');
  (*** Tapo P125: @code(Client.Add@(P125, Host@)) returns a @link(TTapoP100). *)
  /// <summary>Tapo P125: <c>Client.Add(P125, Host)</c> returns a <see cref="Tapo.Devices|TTapoP100"/>.</summary>
  P125: TTapoModelP125 = (Name: 'P125');
  (*** Tapo P125M: @code(Client.Add@(P125M, Host@)) returns a @link(TTapoP100). *)
  /// <summary>Tapo P125M: <c>Client.Add(P125M, Host)</c> returns a <see cref="Tapo.Devices|TTapoP100"/>.</summary>
  P125M: TTapoModelP125M = (Name: 'P125M');
  (*** Tapo P110: @code(Client.Add@(P110, Host@)) returns a @link(TTapoP110). *)
  /// <summary>Tapo P110: <c>Client.Add(P110, Host)</c> returns a <see cref="Tapo.Devices|TTapoP110"/>.</summary>
  P110: TTapoModelP110 = (Name: 'P110');
  (*** Tapo P110M: @code(Client.Add@(P110M, Host@)) returns a @link(TTapoP110). *)
  /// <summary>Tapo P110M: <c>Client.Add(P110M, Host)</c> returns a <see cref="Tapo.Devices|TTapoP110"/>.</summary>
  P110M: TTapoModelP110M = (Name: 'P110M');
  (*** Tapo P115: @code(Client.Add@(P115, Host@)) returns a @link(TTapoP110). *)
  /// <summary>Tapo P115: <c>Client.Add(P115, Host)</c> returns a <see cref="Tapo.Devices|TTapoP110"/>.</summary>
  P115: TTapoModelP115 = (Name: 'P115');
  (*** Tapo P300: @code(Client.Add@(P300, Host@)) returns a @link(TTapoP300). *)
  /// <summary>Tapo P300: <c>Client.Add(P300, Host)</c> returns a <see cref="Tapo.Devices|TTapoP300"/>.</summary>
  P300: TTapoModelP300 = (Name: 'P300');
  (*** Tapo P306: @code(Client.Add@(P306, Host@)) returns a @link(TTapoP300). *)
  /// <summary>Tapo P306: <c>Client.Add(P306, Host)</c> returns a <see cref="Tapo.Devices|TTapoP300"/>.</summary>
  P306: TTapoModelP306 = (Name: 'P306');
  (*** Tapo P304M: @code(Client.Add@(P304M, Host@)) returns a @link(TTapoP304M). *)
  /// <summary>Tapo P304M: <c>Client.Add(P304M, Host)</c> returns a <see cref="Tapo.Devices|TTapoP304M"/>.</summary>
  P304M: TTapoModelP304M = (Name: 'P304M');
  (*** Tapo P316M: @code(Client.Add@(P316M, Host@)) returns a @link(TTapoP304M). *)
  /// <summary>Tapo P316M: <c>Client.Add(P316M, Host)</c> returns a <see cref="Tapo.Devices|TTapoP304M"/>.</summary>
  P316M: TTapoModelP316M = (Name: 'P316M');
  (*** Tapo H100: @code(Client.Add@(H100, Host@)) returns a @link(TTapoH100). *)
  /// <summary>Tapo H100: <c>Client.Add(H100, Host)</c> returns a <see cref="Tapo.Hubs|TTapoH100"/>.</summary>
  H100: TTapoModelH100 = (Name: 'H100');
  (*** Tapo H200: @code(Client.Add@(H200, Host@)) returns a @link(TTapoCameraHub). *)
  /// <summary>Tapo H200: <c>Client.Add(H200, Host)</c> returns a <see cref="Tapo.Hubs|TTapoCameraHub"/>.</summary>
  H200: TTapoModelH200 = (Name: 'H200');
  (*** Tapo H500: @code(Client.Add@(H500, Host@)) returns a @link(TTapoCameraHub). *)
  /// <summary>Tapo H500: <c>Client.Add(H500, Host)</c> returns a <see cref="Tapo.Hubs|TTapoCameraHub"/>.</summary>
  H500: TTapoModelH500 = (Name: 'H500');
  (*** Tapo C210: @code(Client.Add@(C210, Host@)) returns a @link(TTapoCamera). *)
  /// <summary>Tapo C210: <c>Client.Add(C210, Host)</c> returns a <see cref="Tapo.Cameras|TTapoCamera"/>.</summary>
  C210: TTapoModelC210 = (Name: 'C210');
  (*** Tapo C220: @code(Client.Add@(C220, Host@)) returns a @link(TTapoCamera). *)
  /// <summary>Tapo C220: <c>Client.Add(C220, Host)</c> returns a <see cref="Tapo.Cameras|TTapoCamera"/>.</summary>
  C220: TTapoModelC220 = (Name: 'C220');
  (*** Tapo C225: @code(Client.Add@(C225, Host@)) returns a @link(TTapoCamera). *)
  /// <summary>Tapo C225: <c>Client.Add(C225, Host)</c> returns a <see cref="Tapo.Cameras|TTapoCamera"/>.</summary>
  C225: TTapoModelC225 = (Name: 'C225');
  (*** Tapo C325WB: @code(Client.Add@(C325WB, Host@)) returns a @link(TTapoCamera). *)
  /// <summary>Tapo C325WB: <c>Client.Add(C325WB, Host)</c> returns a <see cref="Tapo.Cameras|TTapoCamera"/>.</summary>
  C325WB: TTapoModelC325WB = (Name: 'C325WB');
  (*** Tapo C520WS: @code(Client.Add@(C520WS, Host@)) returns a @link(TTapoCamera). *)
  /// <summary>Tapo C520WS: <c>Client.Add(C520WS, Host)</c> returns a <see cref="Tapo.Cameras|TTapoCamera"/>.</summary>
  C520WS: TTapoModelC520WS = (Name: 'C520WS');
  (*** Tapo TC40: @code(Client.Add@(TC40, Host@)) returns a @link(TTapoCamera). *)
  /// <summary>Tapo TC40: <c>Client.Add(TC40, Host)</c> returns a <see cref="Tapo.Cameras|TTapoCamera"/>.</summary>
  TC40: TTapoModelTC40 = (Name: 'TC40');
  (*** Tapo TC70: @code(Client.Add@(TC70, Host@)) returns a @link(TTapoCamera). *)
  /// <summary>Tapo TC70: <c>Client.Add(TC70, Host)</c> returns a <see cref="Tapo.Cameras|TTapoCamera"/>.</summary>
  TC70: TTapoModelTC70 = (Name: 'TC70');

type
  (***
    Raised by @link(TTapoClientModels.AddDetected) when nothing at the address answered as a Tapo
    device: no connection on port 80 or 443.

    A network scan treats this address as "not a Tapo device".
  *)
  /// <summary>
  ///   Raised by <see cref="TTapoClientModels.AddDetected"/> when nothing at
  ///   the address answered as a Tapo device: no connection on port 80 or 443.
  /// </summary>
  /// <remarks>A network scan treats this address as "not a Tapo device".</remarks>
  ETapoNoResponse = class(ETapoError);

  (***
    Raised by @link(TTapoClientModels.AddDetected) when the address is a Tapo device that logged
    in, but its model is not supported.

    The Model and DeviceType it reported are in the message.
  *)
  /// <summary>
  ///   Raised by <see cref="TTapoClientModels.AddDetected"/> when the address
  ///   is a Tapo device that logged in, but its model is not supported.
  /// </summary>
  /// <remarks>The Model and DeviceType it reported are in the message.</remarks>
  ETapoUnsupportedModel = class(ETapoError);

  (*** What @link(TTapoClientModels.AddDetected) found at an address. *)
  /// <summary>What <see cref="TTapoClientModels.AddDetected"/> found at an address.</summary>
  TTapoDetection = record
    (*** The address probed. *)
    /// <summary>The address probed.</summary>
    Host: string;
    (*** The model as the device reports it. *)
    /// <summary>The model as the device reports it.</summary>
    Model: string;
    (*** The device type, for example 'SMART.TAPOPLUG'. *)
    /// <summary>The device type, for example 'SMART.TAPOPLUG'.</summary>
    DeviceType: string;
    (*** The name given in the Tapo app. *)
    /// <summary>The name given in the Tapo app.</summary>
    Nickname: string;
    (*** The request format the device answered in. *)
    /// <summary>The request format the device answered in.</summary>
    Family: TTapoDeviceFamily;
    (*** The class the device was added as. *)
    /// <summary>The class the device was added as.</summary>
    DeviceClass: TTapoDeviceClass;
    (***
      How the class was chosen: 'model' (an exact match), 'model prefix' (for example P110 for a
      reported 'P110(EU)'), 'device type' (an unknown model, placed by its type and the fields it
      reports), or 'registered' (the address had already been added).
    *)
    /// <summary>
    ///   How the class was chosen: 'model' (an exact match), 'model prefix'
    ///   (for example P110 for a reported 'P110(EU)'), 'device type' (an
    ///   unknown model, placed by its type and the fields it reports), or
    ///   'registered' (the address had already been added).
    /// </summary>
    MatchedBy: string;
    (*** The device info the device reported. *)
    /// <summary>The device info the device reported.</summary>
    Info: TTapoDeviceInfo;
  end;

  (***
    Adds @code(Add@(Model, Host@)) and device detection to @link(TTapoClient).

    Each model constant has its own type, so the compiler picks the overload of Add that returns
    the right class: @code(Client.Add@(P110, ...@)) returns a TTapoP110 with no cast.
  *)
  /// <summary>
  ///   Adds <c>Add(Model, Host)</c> and device detection to <see cref="Tapo.Client|TTapoClient"/>.
  /// </summary>
  /// <remarks>
  ///   Each model constant has its own type, so the compiler picks the
  ///   overload of Add that returns the right class: <c>Client.Add(P110, ...)</c>
  ///   returns a TTapoP110 with no cast.
  /// </remarks>
  TTapoClientModels = class helper for TTapoClient
  public
    (***
      Adds the Tapo L510 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L510).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L510 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L510"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL510; const AHost: string): TTapoL510; overload;
    (***
      Adds the Tapo L510B at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L510B).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L510B at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L510B"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL510B; const AHost: string): TTapoL510; overload;
    (***
      Adds the Tapo L520 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L520).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L520 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L520"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL520; const AHost: string): TTapoL510; overload;
    (***
      Adds the Tapo L610 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L610).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L610 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L610"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL610; const AHost: string): TTapoL510; overload;
    (***
      Adds the Tapo L530 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L530).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L530 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L530"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL530; const AHost: string): TTapoL530; overload;
    (***
      Adds the Tapo L530B at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L530B).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L530B at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L530B"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL530B; const AHost: string): TTapoL530; overload;
    (***
      Adds the Tapo L535 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L535).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L535 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L535"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL535; const AHost: string): TTapoL530; overload;
    (***
      Adds the Tapo L630 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L630).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L630 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L630"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL630; const AHost: string): TTapoL530; overload;
    (***
      Adds the Tapo L900 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L900).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L900 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L900"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL900; const AHost: string): TTapoL900; overload;
    (***
      Adds the Tapo L920 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L920).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L920 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L920"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL920; const AHost: string): TTapoL920; overload;
    (***
      Adds the Tapo L930 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(L930).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo L930 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="L930"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelL930; const AHost: string): TTapoL920; overload;
    (***
      Adds the Tapo P100 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P100).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P100 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P100"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP100; const AHost: string): TTapoP100; overload;
    (***
      Adds the Tapo P105 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P105).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P105 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P105"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP105; const AHost: string): TTapoP100; overload;
    (***
      Adds the Tapo P125 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P125).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P125 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P125"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP125; const AHost: string): TTapoP100; overload;
    (***
      Adds the Tapo P125M at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P125M).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P125M at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P125M"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP125M; const AHost: string): TTapoP100; overload;
    (***
      Adds the Tapo P110 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P110).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P110 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P110"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP110; const AHost: string): TTapoP110; overload;
    (***
      Adds the Tapo P110M at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P110M).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P110M at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P110M"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP110M; const AHost: string): TTapoP110; overload;
    (***
      Adds the Tapo P115 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P115).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P115 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P115"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP115; const AHost: string): TTapoP110; overload;
    (***
      Adds the Tapo P300 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P300).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P300 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P300"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP300; const AHost: string): TTapoP300; overload;
    (***
      Adds the Tapo P306 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P306).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P306 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P306"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP306; const AHost: string): TTapoP300; overload;
    (***
      Adds the Tapo P304M at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P304M).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P304M at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P304M"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP304M; const AHost: string): TTapoP304M; overload;
    (***
      Adds the Tapo P316M at AHost, or returns the device already added there.

      @param(AModel The model constant @link(P316M).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo P316M at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="P316M"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelP316M; const AHost: string): TTapoP304M; overload;
    (***
      Adds the Tapo H100 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(H100).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo H100 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="H100"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelH100; const AHost: string): TTapoH100; overload;
    (***
      Adds the Tapo H200 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(H200).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo H200 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="H200"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelH200; const AHost: string): TTapoCameraHub; overload;
    (***
      Adds the Tapo H500 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(H500).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo H500 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="H500"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelH500; const AHost: string): TTapoCameraHub; overload;
    (***
      Adds the Tapo C210 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(C210).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo C210 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="C210"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelC210; const AHost: string): TTapoCamera; overload;
    (***
      Adds the Tapo C220 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(C220).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo C220 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="C220"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelC220; const AHost: string): TTapoCamera; overload;
    (***
      Adds the Tapo C225 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(C225).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo C225 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="C225"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelC225; const AHost: string): TTapoCamera; overload;
    (***
      Adds the Tapo C325WB at AHost, or returns the device already added there.

      @param(AModel The model constant @link(C325WB).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo C325WB at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="C325WB"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelC325WB; const AHost: string): TTapoCamera; overload;
    (***
      Adds the Tapo C520WS at AHost, or returns the device already added there.

      @param(AModel The model constant @link(C520WS).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo C520WS at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="C520WS"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelC520WS; const AHost: string): TTapoCamera; overload;
    (***
      Adds the Tapo TC40 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(TC40).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo TC40 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="TC40"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelTC40; const AHost: string): TTapoCamera; overload;
    (***
      Adds the Tapo TC70 at AHost, or returns the device already added there.

      @param(AModel The model constant @link(TC70).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client. No request is made until it is first used.)

      @raises(ETapoError AHost is already registered as another class.)
    *)
    /// <summary>Adds the Tapo TC70 at AHost, or returns the device already added there.</summary>
    /// <param name="AModel">The model constant <see cref="TC70"/>.</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client. No request is made until it is first used.</returns>
    /// <exception cref="Tapo.Client|ETapoError">AHost is already registered as another class.</exception>
    function Add(const AModel: TTapoModelTC70; const AHost: string): TTapoCamera; overload;
    (***
      Logs in to AHost, reads its device info and adds it as the matching class.

      Port 80 is tried first (plugs, lights, strips, H100), then port 443 as a camera and then as
      a camera hub. The probe's login is handed to the new device, so each device is logged in to
      once.

      A camera hub may count one failed login when it is tried as a camera first. Do not rescan
      the same addresses in a tight loop.

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client and already logged in; the existing device if AHost
      was already added.)

      @raises(ETapoError AHost is not a Tapo device these credentials can log in to. ErrorCode
      -2101 means the device has locked itself after too many failed logins.)

      @raises(ETapoAuthError A Tapo device rejected the account e-mail or password.)

      @raises(ETapoNoResponse Nothing answered on port 80 or 443.)

      @raises(ETapoUnsupportedModel A Tapo device of a model that is not supported.)

      @seealso(TryAddDetected)
    *)
    /// <summary>Logs in to AHost, reads its device info and adds it as the matching class.</summary>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client and already logged in; the existing device if AHost was already added.</returns>
    /// <exception cref="Tapo.Client|ETapoError">
    ///   AHost is not a Tapo device these credentials can log in to. ErrorCode
    ///   -2101 means the device has locked itself after too many failed logins.
    /// </exception>
    /// <exception cref="Tapo.Client|ETapoAuthError">A Tapo device rejected the account e-mail or password.</exception>
    /// <exception cref="ETapoNoResponse">Nothing answered on port 80 or 443.</exception>
    /// <exception cref="ETapoUnsupportedModel">A Tapo device of a model that is not supported.</exception>
    /// <remarks>
    ///   <para>
    ///     Port 80 is tried first (plugs, lights, strips, H100), then port 443
    ///     as a camera and then as a camera hub. The probe's login is handed to
    ///     the new device, so each device is logged in to once.
    ///   </para>
    ///   <para>
    ///     A camera hub may count one failed login when it is tried as a camera
    ///     first. Do not rescan the same addresses in a tight loop.
    ///   </para>
    /// </remarks>
    /// <seealso cref="TryAddDetected"/>
    function AddDetected(const AHost: string): TTapoDevice; overload;
    (***
      Same as AddDetected(AHost), and reports what was found.

      @param(AHost The IP address, host name, or host:port.)

      @param(ADetection Receives the reported model, type and nickname, and how the class was
      chosen.)
    *)
    /// <summary>Same as AddDetected(AHost), and reports what was found.</summary>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <param name="ADetection">Receives the reported model, type and nickname, and how the class was chosen.</param>
    function AddDetected(const AHost: string; out ADetection: TTapoDetection): TTapoDevice; overload;
    (***
      Same as @link(AddDetected), without exceptions, for scanning a network.

      @param(AHost The IP address, host name, or host:port.)

      @param(ADevice Receives the device, or nil.)

      @param(AError Receives the reason when the result is False.)

      @returns(True if a supported Tapo device was found and added.)

      Example:
      @longCode(#
      Client.ConnectionTimeout := 500;
      for I := 1 to 254 do
        if Client.TryAddDetected('192.168.1.' + IntToStr(I), Dev, Err) then
          Memo1.Lines.Add(Dev.Host + ': ' + Dev.ClassName);
      #)
    *)
    /// <summary>Same as <see cref="AddDetected"/>, without exceptions, for scanning a network.</summary>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <param name="ADevice">Receives the device, or nil.</param>
    /// <param name="AError">Receives the reason when the result is False.</param>
    /// <returns>True if a supported Tapo device was found and added.</returns>
    /// <example>
    ///   <code>
    ///   Client.ConnectionTimeout := 500;
    ///   for I := 1 to 254 do
    ///     if Client.TryAddDetected('192.168.1.' + IntToStr(I), Dev, Err) then
    ///       Memo1.Lines.Add(Dev.Host + ': ' + Dev.ClassName);
    ///   </code>
    /// </example>
    function TryAddDetected(const AHost: string; out ADevice: TTapoDevice;
      out AError: string): Boolean;
    (***
      Adds a device by model name given at run time.

      @param(AModelName A model name, for example 'P110' @(case-insensitive@).)

      @param(AHost The IP address, host name, or host:port.)

      @returns(The device, owned by the client.)

      @raises(ETapoError The model is not supported.)

      @seealso(TapoSupportedModels)
    *)
    /// <summary>Adds a device by model name given at run time.</summary>
    /// <param name="AModelName">A model name, for example 'P110' (case-insensitive).</param>
    /// <param name="AHost">The IP address, host name, or host:port.</param>
    /// <returns>The device, owned by the client.</returns>
    /// <exception cref="Tapo.Client|ETapoError">The model is not supported.</exception>
    /// <seealso cref="TapoSupportedModels"/>
    function Add(const AModelName: string; const AHost: string): TTapoDevice; overload;
  end;

(***
  Finds the device class for a model name.

  @param(AModelName A model name, for example 'L530B' @(case-insensitive@).)

  @returns(The class, or nil if the model is not supported.)
*)
/// <summary>Finds the device class for a model name.</summary>
/// <param name="AModelName">A model name, for example 'L530B' (case-insensitive).</param>
/// <returns>The class, or nil if the model is not supported.</returns>
function TapoDeviceClassForModel(const AModelName: string): TTapoDeviceClass;
(*** Lists every supported model name. *)
/// <summary>Lists every supported model name.</summary>
function TapoSupportedModels: TArray<string>;
(***
  Finds the device class for reported device info.

  @param(AInfo The device info, from @link(TTapoDevice.GetDeviceInfo).)

  @param(AFamily The request format the device answered in.)

  @param(AMatchedBy Receives 'model', 'model prefix' or 'device type'; empty if no class was
  found.)

  @returns(The class: by model, by model prefix, or failing those by device type and the fields
  reported; nil if unknown.)
*)
/// <summary>Finds the device class for reported device info.</summary>
/// <param name="AInfo">The device info, from <see cref="Tapo.Client|TTapoDevice.GetDeviceInfo"/>.</param>
/// <param name="AFamily">The request format the device answered in.</param>
/// <param name="AMatchedBy">Receives 'model', 'model prefix' or 'device type'; empty if no class was found.</param>
/// <returns>The class: by model, by model prefix, or failing those by device type and the fields reported; nil if unknown.</returns>
function TapoDeviceClassForInfo(const AInfo: TTapoDeviceInfo; AFamily: TTapoDeviceFamily;
  out AMatchedBy: string): TTapoDeviceClass;

implementation

type
  TModelEntry = record
    Name: string;
    DeviceClass: TTapoDeviceClass;
  end;

const
  ModelTable: array[0..31] of TModelEntry = (
    (Name: 'L510'; DeviceClass: TTapoL510),
    (Name: 'L510B'; DeviceClass: TTapoL510),
    (Name: 'L520'; DeviceClass: TTapoL510),
    (Name: 'L610'; DeviceClass: TTapoL510),
    (Name: 'L530'; DeviceClass: TTapoL530),
    (Name: 'L530B'; DeviceClass: TTapoL530),
    (Name: 'L535'; DeviceClass: TTapoL530),
    (Name: 'L630'; DeviceClass: TTapoL530),
    (Name: 'L900'; DeviceClass: TTapoL900),
    (Name: 'L920'; DeviceClass: TTapoL920),
    (Name: 'L930'; DeviceClass: TTapoL920),
    (Name: 'P100'; DeviceClass: TTapoP100),
    (Name: 'P105'; DeviceClass: TTapoP100),
    (Name: 'P125'; DeviceClass: TTapoP100),
    (Name: 'P125M'; DeviceClass: TTapoP100),
    (Name: 'P110'; DeviceClass: TTapoP110),
    (Name: 'P110M'; DeviceClass: TTapoP110),
    (Name: 'P115'; DeviceClass: TTapoP110),
    (Name: 'P300'; DeviceClass: TTapoP300),
    (Name: 'P306'; DeviceClass: TTapoP300),
    (Name: 'P304M'; DeviceClass: TTapoP304M),
    (Name: 'P316M'; DeviceClass: TTapoP304M),
    (Name: 'H100'; DeviceClass: TTapoH100),
    (Name: 'H200'; DeviceClass: TTapoCameraHub),
    (Name: 'H500'; DeviceClass: TTapoCameraHub),
    (Name: 'C210'; DeviceClass: TTapoCamera),
    (Name: 'C220'; DeviceClass: TTapoCamera),
    (Name: 'C225'; DeviceClass: TTapoCamera),
    (Name: 'C325WB'; DeviceClass: TTapoCamera),
    (Name: 'C520WS'; DeviceClass: TTapoCamera),
    (Name: 'TC40'; DeviceClass: TTapoCamera),
    (Name: 'TC70'; DeviceClass: TTapoCamera));

function TapoDeviceClassForModel(const AModelName: string): TTapoDeviceClass;
var
  I: Integer;
begin
  for I := Low(ModelTable) to High(ModelTable) do
    if SameText(ModelTable[I].Name, Trim(AModelName)) then
      Exit(ModelTable[I].DeviceClass);
  Result := nil;
end;

function TapoSupportedModels: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, Length(ModelTable));
  for I := Low(ModelTable) to High(ModelTable) do
    Result[I] := ModelTable[I].Name;
end;

{ ============================================================================ }
{ Detection                                                                    }
{ ============================================================================ }

type
  // Throw-away devices that log in to find out what is at an address.
  TProbeSmart = class(TTapoDevice);

  TProbeCamera = class(TTapoDevice)
  public
    class function Family: TTapoDeviceFamily; override;
    class function AuthMode: TTapoAuthMode; override;
  end;

  TProbeCameraHub = class(TTapoDevice)
  public
    class function Family: TTapoDeviceFamily; override;
    class function AuthMode: TTapoAuthMode; override;
  end;

class function TProbeCamera.Family: TTapoDeviceFamily;
begin
  Result := dfSmartCam;
end;

class function TProbeCamera.AuthMode: TTapoAuthMode;
begin
  Result := amCamera;
end;

class function TProbeCameraHub.Family: TTapoDeviceFamily;
begin
  Result := dfSmartCam;
end;

class function TProbeCameraHub.AuthMode: TTapoAuthMode;
begin
  Result := amCameraHub;
end;

// 'P110(EU)' -> 'P110', ' l530b ' -> 'L530B'
function NormaliseModel(const AModel: string): string;
var
  S: string;
  I: Integer;
begin
  S := UpperCase(Trim(AModel));
  I := 1;
  while (I <= Length(S)) and CharInSet(S[I], ['A'..'Z', '0'..'9']) do
    Inc(I);
  Result := Copy(S, 1, I - 1);
end;

function TapoDeviceClassForInfo(const AInfo: TTapoDeviceInfo; AFamily: TTapoDeviceFamily;
  out AMatchedBy: string): TTapoDeviceClass;
var
  M, T: string;
  I, Best: Integer;
  V: TJSONValue;
  O: TJSONObject;
begin
  M := NormaliseModel(AInfo.Model);
  AMatchedBy := 'model';
  Result := TapoDeviceClassForModel(M);
  if Result <> nil then
    Exit;

  // A longer model name that starts with a known one (a regional variant).
  Best := -1;
  for I := Low(ModelTable) to High(ModelTable) do
    if (M <> '') and M.StartsWith(ModelTable[I].Name) and
       ((Best < 0) or (Length(ModelTable[I].Name) > Length(ModelTable[Best].Name))) then
      Best := I;
  if Best >= 0 then
  begin
    AMatchedBy := 'model prefix';
    Exit(ModelTable[Best].DeviceClass);
  end;

  // Unknown model: go by the device type and the fields it reports.
  AMatchedBy := 'device type';
  T := UpperCase(AInfo.DeviceType);
  V := TJSONObject.ParseJSONValue(AInfo.Raw);
  try
    if V is TJSONObject then
      O := TJSONObject(V)
    else
      O := nil;
    if T.Contains('CAMERA') then
      Result := TTapoCamera
    else if T.Contains('HUB') then
    begin
      if AFamily = dfSmartCam then
        Result := TTapoCameraHub
      else
        Result := TTapoH100;
    end
    else if T.Contains('BULB') or T.Contains('LIGHT') then
    begin
      if JHas(O, 'color_temp_range') then
        Result := TTapoL900
      else if JHas(O, 'hue') or JHas(O, 'color_temp') then
        Result := TTapoL530
      else
        Result := TTapoL510;
    end
    else if T.Contains('PLUG') then
    begin
      // a power strip reports no power state of its own
      if JHas(O, 'device_on') then
        Result := TTapoP100
      else
        Result := TTapoP300;
    end
    else
      Result := nil;
  finally
    V.Free;
  end;
  if Result = nil then
    AMatchedBy := '';
end;

function IsConnectionError(E: Exception): Boolean;
begin
  Result := E is ENetException;    // refused, unreachable, timed out, TLS
end;

function IsLockout(E: Exception): Boolean;
begin
  Result := (E is ETapoError) and (ETapoError(E).ErrorCode = -2101);
end;

function TTapoClientModels.AddDetected(const AHost: string): TTapoDevice;
var
  Detection: TTapoDetection;
begin
  Result := AddDetected(AHost, Detection);
end;

function TTapoClientModels.AddDetected(const AHost: string;
  out ADetection: TTapoDetection): TTapoDevice;
const
  CameraProbes: array[0..1] of TTapoDeviceClass = (TProbeCamera, TProbeCameraHub);
var
  Probe: TTapoDevice;
  Cls: TTapoDeviceClass;
  R: TJSONObject;
  Errors, NetErrors, AuthErrors, MatchedBy: string;
  I: Integer;
begin
  ADetection.Host := Trim(AHost);
  Result := Find(AHost);
  if Result <> nil then
  begin
    ADetection.Info := Result.GetDeviceInfo;
    ADetection.Model := ADetection.Info.Model;
    ADetection.DeviceType := ADetection.Info.DeviceType;
    ADetection.Nickname := ADetection.Info.Nickname;
    ADetection.Family := Result.Family;
    ADetection.DeviceClass := TTapoDeviceClass(Result.ClassType);
    ADetection.MatchedBy := 'registered';
    Exit;
  end;

  Probe := nil;
  Errors := '';
  NetErrors := '';      // connection failures, reported if nothing else is
  AuthErrors := '';     // the device rejected the account e-mail or password

  // 1. Plugs, lights, strips and the H100 answer on port 80 (TPAP or KLAP).
  try
    Probe := TProbeSmart.Create(Self, AHost);
    Probe.Login;
  except
    on E: Exception do
    begin
      FreeAndNil(Probe);
      if IsLockout(E) then
        raise;
      if IsConnectionError(E) then
        NetErrors := 'port 80: ' + E.Message
      else
        Errors := E.Message;
      if E is ETapoAuthError then
        AuthErrors := E.Message;
    end;
  end;

  // 2. Cameras and camera hubs answer on port 443. A camera is tried first,
  //    then a camera hub (which logs in as the local "admin" account).
  if Probe = nil then
    for I := Low(CameraProbes) to High(CameraProbes) do
    begin
      try
        Probe := CameraProbes[I].Create(Self, AHost);
        Probe.Login;
        Break;
      except
        on E: Exception do
        begin
          FreeAndNil(Probe);
          if IsLockout(E) then
            raise;
          if IsConnectionError(E) then
          begin
            if NetErrors <> '' then
              NetErrors := NetErrors + '; ';
            NetErrors := NetErrors + 'port 443: ' + E.Message;
            Break;            // nothing on port 443: not a camera or hub either
          end;
          if Errors <> '' then
            Errors := Errors + '; ';
          Errors := Errors + E.Message;
          if (E is ETapoAuthError) and (AuthErrors = '') then
            AuthErrors := E.Message;
        end;
      end;
    end;

  if Probe = nil then
  begin
    // a Tapo device that turned the account down says more than the rest
    if AuthErrors <> '' then
      raise ETapoAuthError.CreateCode(-1, Format('%s did not accept the Tapo account e-mail or password (%s)',
        [AHost, AuthErrors]));
    if Errors = '' then
      raise ETapoNoResponse.CreateCode(-1, Format('%s is not a Tapo device these credentials can log in to (no response: %s)',
        [AHost, NetErrors]));
    raise ETapoError.CreateCode(-1, Format('%s is not a Tapo device these credentials can log in to (%s)',
      [AHost, Errors]));
  end;

  try
    R := Probe.GetDeviceInfoObject;
    try
      ADetection.Info := TTapoDeviceInfo.FromJSON(R);
    finally
      R.Free;
    end;
    ADetection.Model := ADetection.Info.Model;
    ADetection.DeviceType := ADetection.Info.DeviceType;
    ADetection.Nickname := ADetection.Info.Nickname;
    ADetection.Family := Probe.Family;

    Cls := TapoDeviceClassForInfo(ADetection.Info, Probe.Family, MatchedBy);
    if Cls = nil then
      raise ETapoUnsupportedModel.CreateCode(-1, Format('%s is a Tapo device of an unsupported model: %s (%s)',
        [AHost, ADetection.Model, ADetection.DeviceType]));
    // an unknown plug that measures energy gets the energy-monitoring class
    if (Cls = TTapoP100) and (MatchedBy = 'device type') and
       Probe.GetComponentListJSON.Contains('"energy_monitoring"') then
      Cls := TTapoP110;
    ADetection.DeviceClass := Cls;
    ADetection.MatchedBy := MatchedBy;

    Result := Cls.Create(Self, AHost);
    // reuse the probe's login when the class logs in the same way
    if (Cls.Family = Probe.Family) and (Cls.AuthMode = Probe.AuthMode) then
      Result.TakeSession(Probe);
  finally
    Probe.Free;
  end;
end;

function TTapoClientModels.TryAddDetected(const AHost: string; out ADevice: TTapoDevice;
  out AError: string): Boolean;
begin
  AError := '';
  try
    ADevice := AddDetected(AHost);
    Result := True;
  except
    on E: Exception do
    begin
      ADevice := nil;
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL510; const AHost: string): TTapoL510;
begin
  Result := AddDevice(TTapoL510, AHost) as TTapoL510;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL510B; const AHost: string): TTapoL510;
begin
  Result := AddDevice(TTapoL510, AHost) as TTapoL510;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL520; const AHost: string): TTapoL510;
begin
  Result := AddDevice(TTapoL510, AHost) as TTapoL510;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL610; const AHost: string): TTapoL510;
begin
  Result := AddDevice(TTapoL510, AHost) as TTapoL510;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL530; const AHost: string): TTapoL530;
begin
  Result := AddDevice(TTapoL530, AHost) as TTapoL530;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL530B; const AHost: string): TTapoL530;
begin
  Result := AddDevice(TTapoL530, AHost) as TTapoL530;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL535; const AHost: string): TTapoL530;
begin
  Result := AddDevice(TTapoL530, AHost) as TTapoL530;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL630; const AHost: string): TTapoL530;
begin
  Result := AddDevice(TTapoL530, AHost) as TTapoL530;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL900; const AHost: string): TTapoL900;
begin
  Result := AddDevice(TTapoL900, AHost) as TTapoL900;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL920; const AHost: string): TTapoL920;
begin
  Result := AddDevice(TTapoL920, AHost) as TTapoL920;
end;

function TTapoClientModels.Add(const AModel: TTapoModelL930; const AHost: string): TTapoL920;
begin
  Result := AddDevice(TTapoL920, AHost) as TTapoL920;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP100; const AHost: string): TTapoP100;
begin
  Result := AddDevice(TTapoP100, AHost) as TTapoP100;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP105; const AHost: string): TTapoP100;
begin
  Result := AddDevice(TTapoP100, AHost) as TTapoP100;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP125; const AHost: string): TTapoP100;
begin
  Result := AddDevice(TTapoP100, AHost) as TTapoP100;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP125M; const AHost: string): TTapoP100;
begin
  Result := AddDevice(TTapoP100, AHost) as TTapoP100;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP110; const AHost: string): TTapoP110;
begin
  Result := AddDevice(TTapoP110, AHost) as TTapoP110;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP110M; const AHost: string): TTapoP110;
begin
  Result := AddDevice(TTapoP110, AHost) as TTapoP110;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP115; const AHost: string): TTapoP110;
begin
  Result := AddDevice(TTapoP110, AHost) as TTapoP110;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP300; const AHost: string): TTapoP300;
begin
  Result := AddDevice(TTapoP300, AHost) as TTapoP300;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP306; const AHost: string): TTapoP300;
begin
  Result := AddDevice(TTapoP300, AHost) as TTapoP300;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP304M; const AHost: string): TTapoP304M;
begin
  Result := AddDevice(TTapoP304M, AHost) as TTapoP304M;
end;

function TTapoClientModels.Add(const AModel: TTapoModelP316M; const AHost: string): TTapoP304M;
begin
  Result := AddDevice(TTapoP304M, AHost) as TTapoP304M;
end;

function TTapoClientModels.Add(const AModel: TTapoModelH100; const AHost: string): TTapoH100;
begin
  Result := AddDevice(TTapoH100, AHost) as TTapoH100;
end;

function TTapoClientModels.Add(const AModel: TTapoModelH200; const AHost: string): TTapoCameraHub;
begin
  Result := AddDevice(TTapoCameraHub, AHost) as TTapoCameraHub;
end;

function TTapoClientModels.Add(const AModel: TTapoModelH500; const AHost: string): TTapoCameraHub;
begin
  Result := AddDevice(TTapoCameraHub, AHost) as TTapoCameraHub;
end;

function TTapoClientModels.Add(const AModel: TTapoModelC210; const AHost: string): TTapoCamera;
begin
  Result := AddDevice(TTapoCamera, AHost) as TTapoCamera;
end;

function TTapoClientModels.Add(const AModel: TTapoModelC220; const AHost: string): TTapoCamera;
begin
  Result := AddDevice(TTapoCamera, AHost) as TTapoCamera;
end;

function TTapoClientModels.Add(const AModel: TTapoModelC225; const AHost: string): TTapoCamera;
begin
  Result := AddDevice(TTapoCamera, AHost) as TTapoCamera;
end;

function TTapoClientModels.Add(const AModel: TTapoModelC325WB; const AHost: string): TTapoCamera;
begin
  Result := AddDevice(TTapoCamera, AHost) as TTapoCamera;
end;

function TTapoClientModels.Add(const AModel: TTapoModelC520WS; const AHost: string): TTapoCamera;
begin
  Result := AddDevice(TTapoCamera, AHost) as TTapoCamera;
end;

function TTapoClientModels.Add(const AModel: TTapoModelTC40; const AHost: string): TTapoCamera;
begin
  Result := AddDevice(TTapoCamera, AHost) as TTapoCamera;
end;

function TTapoClientModels.Add(const AModel: TTapoModelTC70; const AHost: string): TTapoCamera;
begin
  Result := AddDevice(TTapoCamera, AHost) as TTapoCamera;
end;

function TTapoClientModels.Add(const AModelName: string; const AHost: string): TTapoDevice;
var
  Cls: TTapoDeviceClass;
begin
  Cls := TapoDeviceClassForModel(AModelName);
  if Cls = nil then
    raise ETapoError.CreateCode(-1, 'Unsupported Tapo model: ' + AModelName);
  Result := AddDevice(Cls, AHost);
end;

end.
