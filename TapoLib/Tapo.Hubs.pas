//** @abstract(Tapo hubs and the devices paired to them.)
//**
//** @preformatted(
//** TTapoDevice @(abstract, Tapo.Client@)
//** `-- TTapoHub @(abstract@)             child list and child lookup
//**     |-- TTapoH100                   H100 @(+ alarm@)
//**     `-- TTapoCameraHub              H200, H500 @(+ paired cameras, recordings@)
//** )
//**
//** @preformatted(
//** TTapoChildDevice @(abstract, Tapo.Client@)
//** `-- TTapoHubChild @(abstract@)        common child info
//**     |-- TTapoKE100                  radiator valve @(TRV@)
//**     |-- TTapoS210                   light switch @(on/off, usage@)
//**     |-- TTapoT31x                   T310, T315 temperature/humidity sensor
//**     `-- TTapoTriggerSensor @(abstract@)   trigger logs
//**         |-- TTapoS200               S200B, S200D button / dimmer
//**         |-- TTapoT100               motion sensor
//**         |-- TTapoT110               contact sensor
//**         `-- TTapoT300               water leak sensor
//** )
//**
//** Children are obtained from the hub (Hub.T31x('Kitchen')) and owned by it. Capabilities follow
//** the feature matrix of https://github.com/mihai-dinculescu/tapo. Recording download from camera
//** hubs is not included (it uses a separate encrypted media stream, not the control API).
unit Tapo.Hubs;

{
  Tapo hubs and the devices paired to them.

    TTapoDevice (abstract, Tapo.Client)
    `-- TTapoHub (abstract)             child list and child lookup
        |-- TTapoH100                   H100 (+ alarm)
        `-- TTapoCameraHub              H200, H500 (+ paired cameras, recordings)

    TTapoChildDevice (abstract, Tapo.Client)
    `-- TTapoHubChild (abstract)        common child info
        |-- TTapoKE100                  radiator valve (TRV)
        |-- TTapoS210                   light switch (on/off, usage)
        |-- TTapoT31x                   T310, T315 temperature/humidity sensor
        `-- TTapoTriggerSensor (abstract)   trigger logs
            |-- TTapoS200               S200B, S200D button / dimmer
            |-- TTapoT100               motion sensor
            |-- TTapoT110               contact sensor
            `-- TTapoT300               water leak sensor

  Children are obtained from the hub (Hub.T31x('Kitchen')) and owned by it.
  Capabilities follow the feature matrix of https://github.com/mihai-dinculescu/tapo.
  Recording download from camera hubs is not included (it uses a separate
  encrypted media stream, not the control API).
}

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.DateUtils,
  System.Generics.Collections, Tapo.Client, Tapo.Devices;

type
  //** @abstract(The fields every device paired to a hub reports.)
  //**
  //** Fields a device does not report are empty or 0. @link(Raw) holds the whole reply.
  /// <summary>The fields every device paired to a hub reports.</summary>
  /// <remarks>Fields a device does not report are empty or 0. <see cref="Raw"/> holds the whole reply.</remarks>
  TTapoHubChildInfo = record
    //** @abstract(The device id.)
    /// <summary>The device id.</summary>
    DeviceId: string;
    //** @abstract(The device id of the hub it is paired to.)
    /// <summary>The device id of the hub it is paired to.</summary>
    ParentDeviceId: string;
    //** @abstract(The model, for example 'T310'.)
    /// <summary>The model, for example 'T310'.</summary>
    Model: string;
    //** @abstract(The name given in the Tapo app.)
    /// <summary>The name given in the Tapo app.</summary>
    Nickname: string;
    //** @abstract(The device type.)
    /// <summary>The device type.</summary>
    DeviceType: string;
    //** @abstract(The device category.)
    /// <summary>The device category.</summary>
    Category: string;
    //** @abstract(The firmware version.)
    /// <summary>The firmware version.</summary>
    FirmwareVersion: string;
    //** @abstract(The hardware version.)
    /// <summary>The hardware version.</summary>
    HardwareVersion: string;
    //** @abstract(The hardware id.)
    /// <summary>The hardware id.</summary>
    HardwareId: string;
    //** @abstract(The OEM id.)
    /// <summary>The OEM id.</summary>
    OemId: string;
    //** @abstract(The MAC address.)
    /// <summary>The MAC address.</summary>
    Mac: string;
    //** @abstract(The region code.)
    /// <summary>The region code.</summary>
    Region: string;
    //** @abstract(The hardware specification code.)
    /// <summary>The hardware specification code.</summary>
    Specs: string;
    //** @abstract(The icon chosen in the Tapo app.)
    /// <summary>The icon chosen in the Tapo app.</summary>
    Avatar: string;
    //** @abstract('online' or 'offline'.)
    /// <summary>'online' or 'offline'.</summary>
    Status: string;
    //** @abstract(True when the battery is low.)
    /// <summary>True when the battery is low.</summary>
    AtLowBattery: Boolean;
    //** @abstract(The battery level in percent; -1 if the device does not report it @(the S210
    //** does@).)
    /// <summary>The battery level in percent; -1 if the device does not report it (the S210 does).</summary>
    BatteryPercentage: Integer;
    //** @abstract(The radio signal strength to the hub, in dBm.)
    /// <summary>The radio signal strength to the hub, in dBm.</summary>
    RSSI: Integer;
    //** @abstract(The radio signal level, 0 to 3.)
    /// <summary>The radio signal level, 0 to 3.</summary>
    SignalLevel: Integer;
    //** @abstract(The strength of radio interference, in dBm.)
    /// <summary>The strength of radio interference, in dBm.</summary>
    JammingRSSI: Integer;
    //** @abstract(The level of radio interference.)
    /// <summary>The level of radio interference.</summary>
    JammingSignalLevel: Integer;
    //** @abstract(The bind count.)
    /// <summary>The bind count.</summary>
    BindCount: Integer;
    //** @abstract(How often the device reports to the hub, in seconds.)
    /// <summary>How often the device reports to the hub, in seconds.</summary>
    ReportInterval: Integer;
    //** @abstract(When the device was paired, as a Unix time.)
    /// <summary>When the device was paired, as a Unix time.</summary>
    LastOnboardingTimestamp: Int64;
    //** @abstract(The status-follow-edge setting.)
    /// <summary>The status-follow-edge setting.</summary>
    StatusFollowEdge: Boolean;
    //** @abstract(The whole reply as formatted JSON.)
    /// <summary>The whole reply as formatted JSON.</summary>
    Raw: string;
    //** @abstract(Reads the fields from a child's device info or child-list entry.)
    //**
    //** @param(Obj The object to read. May be nil.)
    /// <summary>Reads the fields from a child's device info or child-list entry.</summary>
    /// <param name="Obj">The object to read. May be nil.</param>
    class function FromJSON(Obj: TJSONObject): TTapoHubChildInfo; static;
  end;

  //** @abstract(Device info of a KE100 radiator valve.)
  /// <summary>Device info of a KE100 radiator valve.</summary>
  TTapoKE100Info = record
    //** @abstract(The fields every hub child reports.)
    /// <summary>The fields every hub child reports.</summary>
    Child: TTapoHubChildInfo;
    //** @abstract(True if the child lock is on.)
    /// <summary>True if the child lock is on.</summary>
    ChildProtection: Boolean;
    //** @abstract(True if frost protection is on.)
    /// <summary>True if frost protection is on.</summary>
    FrostProtection: Boolean;
    //** @abstract(The measured temperature.)
    /// <summary>The measured temperature.</summary>
    CurrentTemperature: Double;
    //** @abstract(The temperature the valve aims for.)
    /// <summary>The temperature the valve aims for.</summary>
    TargetTemperature: Double;
    //** @abstract(The lowest target temperature allowed.)
    /// <summary>The lowest target temperature allowed.</summary>
    MinControlTemperature: Integer;
    //** @abstract(The highest target temperature allowed.)
    /// <summary>The highest target temperature allowed.</summary>
    MaxControlTemperature: Integer;
    //** @abstract(The correction added to the measured temperature, -10 to 10.)
    /// <summary>The correction added to the measured temperature, -10 to 10.</summary>
    TemperatureOffset: Integer;
    //** @abstract(The temperature unit, 'celsius'.)
    /// <summary>The temperature unit, 'celsius'.</summary>
    TemperatureUnit: string;
    //** @abstract(The room set in the Tapo app.)
    /// <summary>The room set in the Tapo app.</summary>
    Location: string;
  end;

  //** @abstract(Device info of an S210 light switch.)
  /// <summary>Device info of an S210 light switch.</summary>
  TTapoS210Info = record
    //** @abstract(The fields every hub child reports.)
    /// <summary>The fields every hub child reports.</summary>
    Child: TTapoHubChildInfo;
    //** @abstract(True if the switch is on.)
    /// <summary>True if the switch is on.</summary>
    DeviceOn: Boolean;
    //** @abstract(The switch's position on a multi-gang unit.)
    /// <summary>The switch's position on a multi-gang unit.</summary>
    Position: Integer;
    //** @abstract(The number of switches on the unit.)
    /// <summary>The number of switches on the unit.</summary>
    SlotNumber: Integer;
  end;

  //** @abstract(Device info of a T100 motion sensor.)
  /// <summary>Device info of a T100 motion sensor.</summary>
  TTapoT100Info = record
    //** @abstract(The fields every hub child reports.)
    /// <summary>The fields every hub child reports.</summary>
    Child: TTapoHubChildInfo;
    //** @abstract(True while motion is detected.)
    /// <summary>True while motion is detected.</summary>
    Detected: Boolean;
  end;

  //** @abstract(Device info of a T110 contact sensor.)
  /// <summary>Device info of a T110 contact sensor.</summary>
  TTapoT110Info = record
    //** @abstract(The fields every hub child reports.)
    /// <summary>The fields every hub child reports.</summary>
    Child: TTapoHubChildInfo;
    //** @abstract(True while the door or window is open.)
    /// <summary>True while the door or window is open.</summary>
    Open: Boolean;
  end;

  //** @abstract(Device info of a T300 water leak sensor.)
  /// <summary>Device info of a T300 water leak sensor.</summary>
  TTapoT300Info = record
    //** @abstract(The fields every hub child reports.)
    /// <summary>The fields every hub child reports.</summary>
    Child: TTapoHubChildInfo;
    //** @abstract(True while the alarm sounds.)
    /// <summary>True while the alarm sounds.</summary>
    InAlarm: Boolean;
    //** @abstract('normal', 'water_dry' or 'water_leak'.)
    /// <summary>'normal', 'water_dry' or 'water_leak'.</summary>
    WaterLeakStatus: string;
  end;

  //** @abstract(Device info of a T310 or T315 temperature and humidity sensor.)
  /// <summary>Device info of a T310 or T315 temperature and humidity sensor.</summary>
  TTapoT31xInfo = record
    //** @abstract(The fields every hub child reports.)
    /// <summary>The fields every hub child reports.</summary>
    Child: TTapoHubChildInfo;
    //** @abstract(The temperature, in @link(TemperatureUnit).)
    /// <summary>The temperature, in <see cref="TemperatureUnit"/>.</summary>
    CurrentTemperature: Double;
    //** @abstract(The relative humidity in percent.)
    /// <summary>The relative humidity in percent.</summary>
    CurrentHumidity: Integer;
    //** @abstract(How far the temperature is outside the comfort range set in the app; 0 inside it.)
    /// <summary>How far the temperature is outside the comfort range set in the app; 0 inside it.</summary>
    TemperatureException: Double;
    //** @abstract(How far the humidity is outside the comfort range set in the app; 0 inside it.)
    /// <summary>How far the humidity is outside the comfort range set in the app; 0 inside it.</summary>
    HumidityException: Integer;
    //** @abstract('celsius' or 'fahrenheit'.)
    /// <summary>'celsius' or 'fahrenheit'.</summary>
    TemperatureUnit: string;
  end;

  //** @abstract(One entry of a sensor's trigger log.)
  /// <summary>One entry of a sensor's trigger log.</summary>
  TTapoTriggerLog = record
    //** @abstract(The entry's id; pass it as AStartId to read older entries.)
    /// <summary>The entry's id; pass it as AStartId to read older entries.</summary>
    Id: Int64;
    //** @abstract(When it happened, local time.)
    /// <summary>When it happened, local time.</summary>
    Time: TDateTime;
    //** @abstract(What happened, for example 'motion' @(T100@); 'open', 'close' or 'keepOpen'
    //** @(T110@); 'waterLeak' or 'waterDry' @(T300@); 'singleClick', 'doubleClick', 'rotation' or
    //** 'lowBattery' @(S200@).)
    /// <summary>
    ///   What happened, for example 'motion' (T100); 'open', 'close' or
    ///   'keepOpen' (T110); 'waterLeak' or 'waterDry' (T300); 'singleClick',
    ///   'doubleClick', 'rotation' or 'lowBattery' (S200).
    /// </summary>
    Event: string;
    //** @abstract(The rotation in degrees, for an S200 'rotation' event.)
    /// <summary>The rotation in degrees, for an S200 'rotation' event.</summary>
    RotationDegrees: Integer;
    //** @abstract(The whole entry as JSON.)
    /// <summary>The whole entry as JSON.</summary>
    Raw: string;
  end;

  //** @abstract(A page of a sensor's trigger log.)
  /// <summary>A page of a sensor's trigger log.</summary>
  TTapoTriggerLogs = record
    //** @abstract(The id the page starts at.)
    /// <summary>The id the page starts at.</summary>
    StartId: Int64;
    //** @abstract(The total number of entries the device holds.)
    /// <summary>The total number of entries the device holds.</summary>
    Sum: Int64;
    //** @abstract(The entries, newest first.)
    /// <summary>The entries, newest first.</summary>
    Logs: TArray<TTapoTriggerLog>;
  end;

  //** @abstract(One 15-minute reading of a T310 or T315.)
  /// <summary>One 15-minute reading of a T310 or T315.</summary>
  TTapoTempHumidityRecord = record
    //** @abstract(The time of the reading, local time.)
    /// <summary>The time of the reading, local time.</summary>
    Time: TDateTime;
    //** @abstract(The temperature.)
    /// <summary>The temperature.</summary>
    Temperature: Double;
    //** @abstract(How far the temperature was outside the comfort range.)
    /// <summary>How far the temperature was outside the comfort range.</summary>
    TemperatureException: Double;
    //** @abstract(The relative humidity in percent.)
    /// <summary>The relative humidity in percent.</summary>
    Humidity: Integer;
    //** @abstract(How far the humidity was outside the comfort range.)
    /// <summary>How far the humidity was outside the comfort range.</summary>
    HumidityException: Integer;
  end;

  //** @abstract(The last 24 hours of a T310 or T315, one reading every 15 minutes.)
  /// <summary>The last 24 hours of a T310 or T315, one reading every 15 minutes.</summary>
  TTapoTempHumidityRecords = record
    //** @abstract(When the device answered, local time.)
    /// <summary>When the device answered, local time.</summary>
    RetrievedAt: TDateTime;
    //** @abstract('celsius' or 'fahrenheit'.)
    /// <summary>'celsius' or 'fahrenheit'.</summary>
    TemperatureUnit: string;
    //** @abstract(The readings, oldest first. Intervals without a reading are left out.)
    /// <summary>The readings, oldest first. Intervals without a reading are left out.</summary>
    Records: TArray<TTapoTempHumidityRecord>;
  end;

  { --- hub children -------------------------------------------------------- }

  //** @abstract(A sensor or switch paired to a hub.)
  //**
  //** Obtain children from the hub (for example @code(Hub.T31x@('Kitchen'@))), which owns them.
  /// <summary>A sensor or switch paired to a hub.</summary>
  /// <remarks>Obtain children from the hub (for example <c>Hub.T31x('Kitchen')</c>), which owns them.</remarks>
  TTapoHubChild = class abstract(TTapoChildDevice)
  public
    //** @abstract(Reads the fields every hub child reports.)
    /// <summary>Reads the fields every hub child reports.</summary>
    function GetChildInfo: TTapoHubChildInfo;
  end;

  //** @abstract(A sensor that keeps a log of what triggered it.)
  /// <summary>A sensor that keeps a log of what triggered it.</summary>
  TTapoTriggerSensor = class abstract(TTapoHubChild)
  public
    //** @abstract(Reads a page of the trigger log.)
    //**
    //** @param(APageSize The number of entries to read.)
    //**
    //** @param(AStartId 0 for the newest entries; otherwise the id to continue from.)
    /// <summary>Reads a page of the trigger log.</summary>
    /// <param name="APageSize">The number of entries to read.</param>
    /// <param name="AStartId">0 for the newest entries; otherwise the id to continue from.</param>
    function GetTriggerLogs(APageSize: Integer; AStartId: Int64 = 0): TTapoTriggerLogs;
  end;

  //** @abstract(Tapo KE100 smart radiator valve.)
  /// <summary>Tapo KE100 smart radiator valve.</summary>
  TTapoKE100 = class(TTapoHubChild)
  public
    //** @abstract(Reads the valve's device info.)
    /// <summary>Reads the valve's device info.</summary>
    function GetKE100Info: TTapoKE100Info;
    //** @abstract(Switches the child lock on or off.)
    /// <summary>Switches the child lock on or off.</summary>
    procedure SetChildProtection(AOn: Boolean);
    //** @abstract(Switches frost protection on or off.)
    /// <summary>Switches frost protection on or off.</summary>
    procedure SetFrostProtection(AOn: Boolean);
    //** @abstract(Sets the highest target temperature allowed, in degrees Celsius.)
    /// <summary>Sets the highest target temperature allowed, in degrees Celsius.</summary>
    procedure SetMaxControlTemperature(AValue: Integer);
    //** @abstract(Sets the lowest target temperature allowed, in degrees Celsius.)
    /// <summary>Sets the lowest target temperature allowed, in degrees Celsius.</summary>
    procedure SetMinControlTemperature(AValue: Integer);
    //** @abstract(Sets the temperature the valve aims for, in degrees Celsius.)
    //**
    //** @param(AValue Between the minimum and maximum control temperatures.)
    //**
    //** @raises(ETapoError AValue is outside the allowed range.)
    /// <summary>Sets the temperature the valve aims for, in degrees Celsius.</summary>
    /// <param name="AValue">Between the minimum and maximum control temperatures.</param>
    /// <exception cref="ETapoError">AValue is outside the allowed range.</exception>
    procedure SetTargetTemperature(AValue: Integer);
    //** @abstract(Sets the correction added to the measured temperature.)
    //**
    //** @param(AValue -10 to 10 degrees.)
    //**
    //** @raises(ETapoError AValue is out of range.)
    /// <summary>Sets the correction added to the measured temperature.</summary>
    /// <param name="AValue">-10 to 10 degrees.</param>
    /// <exception cref="ETapoError">AValue is out of range.</exception>
    procedure SetTemperatureOffset(AValue: Integer);
  end;

  //** @abstract(Tapo S200B smart button and S200D remote dimmer.)
  /// <summary>Tapo S200B smart button and S200D remote dimmer.</summary>
  TTapoS200 = class(TTapoTriggerSensor)
  public
    //** @abstract(Reads the device info.)
    /// <summary>Reads the device info.</summary>
    function GetS200Info: TTapoHubChildInfo;
  end;

  //** @abstract(Tapo S210 smart light switch.)
  /// <summary>Tapo S210 smart light switch.</summary>
  TTapoS210 = class(TTapoHubChild)
  public
    //** @abstract(Switches the switch on.)
    /// <summary>Switches the switch on.</summary>
    procedure TurnOn;
    //** @abstract(Switches the switch off.)
    /// <summary>Switches the switch off.</summary>
    procedure TurnOff;
    //** @abstract(Switches the switch on or off.)
    /// <summary>Switches the switch on or off.</summary>
    procedure SetOn(AOn: Boolean);
    //** @abstract(Reads the power state.)
    /// <summary>Reads the power state.</summary>
    function IsOn: Boolean;
    //** @abstract(Reads the switch's device info.)
    /// <summary>Reads the switch's device info.</summary>
    function GetS210Info: TTapoS210Info;
    //** @abstract(Reads how long the switch has been on.)
    //**
    //** Only TimeUsage is reported; PowerUsage and SavedPower are -1.
    /// <summary>Reads how long the switch has been on.</summary>
    /// <remarks>Only TimeUsage is reported; PowerUsage and SavedPower are -1.</remarks>
    function GetDeviceUsage: TTapoDeviceUsage;
  end;

  //** @abstract(Tapo T100 motion sensor.)
  /// <summary>Tapo T100 motion sensor.</summary>
  TTapoT100 = class(TTapoTriggerSensor)
  public
    //** @abstract(Reads the sensor's device info.)
    /// <summary>Reads the sensor's device info.</summary>
    function GetT100Info: TTapoT100Info;
  end;

  //** @abstract(Tapo T110 contact sensor.)
  /// <summary>Tapo T110 contact sensor.</summary>
  TTapoT110 = class(TTapoTriggerSensor)
  public
    //** @abstract(Reads the sensor's device info.)
    /// <summary>Reads the sensor's device info.</summary>
    function GetT110Info: TTapoT110Info;
  end;

  //** @abstract(Tapo T300 water leak sensor.)
  /// <summary>Tapo T300 water leak sensor.</summary>
  TTapoT300 = class(TTapoTriggerSensor)
  public
    //** @abstract(Reads the sensor's device info.)
    /// <summary>Reads the sensor's device info.</summary>
    function GetT300Info: TTapoT300Info;
  end;

  //** @abstract(Tapo T310 and T315 temperature and humidity sensor.)
  /// <summary>Tapo T310 and T315 temperature and humidity sensor.</summary>
  TTapoT31x = class(TTapoHubChild)
  public
    //** @abstract(Reads the sensor's device info, including the current readings.)
    /// <summary>Reads the sensor's device info, including the current readings.</summary>
    function GetT31xInfo: TTapoT31xInfo;
    //** @abstract(Reads the last 24 hours of readings.)
    /// <summary>Reads the last 24 hours of readings.</summary>
    function GetTemperatureHumidityRecords: TTapoTempHumidityRecords;
  end;

  //** @abstract(Tapo S200B: the same as @link(TTapoS200).)
  /// <summary>Tapo S200B: the same as <see cref="TTapoS200"/>.</summary>
  TTapoS200B = TTapoS200;
  //** @abstract(Tapo S200D: the same as @link(TTapoS200).)
  /// <summary>Tapo S200D: the same as <see cref="TTapoS200"/>.</summary>
  TTapoS200D = TTapoS200;
  //** @abstract(Tapo T310: the same as @link(TTapoT31x).)
  /// <summary>Tapo T310: the same as <see cref="TTapoT31x"/>.</summary>
  TTapoT310 = TTapoT31x;
  //** @abstract(Tapo T315: the same as @link(TTapoT31x).)
  /// <summary>Tapo T315: the same as <see cref="TTapoT31x"/>.</summary>
  TTapoT315 = TTapoT31x;

  { --- hubs ---------------------------------------------------------------- }

  //** @abstract(The features common to the hubs: the sensors and switches paired to them.)
  //**
  //** Example:
  //** @longCode(#
  //** Hub := Client.Add(H100, '192.168.1.53');
  //** Info := Hub.T31x('Kitchen').GetT31xInfo;
  //** Label1.Text := Format('%.1f C, %d%%', [Info.CurrentTemperature, Info.CurrentHumidity]);
  //** #)
  /// <summary>The features common to the hubs: the sensors and switches paired to them.</summary>
  /// <example>
  ///   <code>
  ///   Hub := Client.Add(H100, '192.168.1.53');
  ///   Info := Hub.T31x('Kitchen').GetT31xInfo;
  ///   Label1.Text := Format('%.1f C, %d%%', [Info.CurrentTemperature, Info.CurrentHumidity]);
  ///   </code>
  /// </example>
  TTapoHub = class abstract(TTapoDevice)
  private
    function FindChild(const AModels: array of string; const AIdOrNickname: string;
      AClass: TTapoChildDeviceClass): TTapoChildDevice;
  public
    //** @abstract(Reads every paired sensor and switch.)
    //**
    //** Cameras paired to an H200 or H500 are listed by @link(TTapoCameraHub.GetGeneralDeviceList)
    //** instead.
    /// <summary>Reads every paired sensor and switch.</summary>
    /// <remarks>Cameras paired to an H200 or H500 are listed by <see cref="TTapoCameraHub.GetGeneralDeviceList"/> instead.</remarks>
    function GetChildDeviceList: TArray<TTapoHubChildInfo>;
    //** @abstract(Reads one page @(10 entries@) of the child list as formatted JSON.)
    //**
    //** @param(AStartIndex The index to start from.)
    /// <summary>Reads one page (10 entries) of the child list as formatted JSON.</summary>
    /// <param name="AStartIndex">The index to start from.</param>
    function GetChildDeviceListJSON(AStartIndex: Integer = 0): string;
    //** @abstract(Reads the children's components as formatted JSON.)
    /// <summary>Reads the children's components as formatted JSON.</summary>
    function GetChildDeviceComponentListJSON: string;

    //** @abstract(A KE100 radiator valve by device id or nickname.)
    //**
    //** @returns(The valve, owned by the hub.)
    //**
    //** @raises(ETapoError No KE100 with that id or nickname is paired.)
    /// <summary>A KE100 radiator valve by device id or nickname.</summary>
    /// <returns>The valve, owned by the hub.</returns>
    /// <exception cref="ETapoError">No KE100 with that id or nickname is paired.</exception>
    function KE100(const AIdOrNickname: string): TTapoKE100;
    //** @abstract(An S200B or S200D by device id or nickname.)
    //**
    //** @raises(ETapoError No such device is paired.)
    /// <summary>An S200B or S200D by device id or nickname.</summary>
    /// <exception cref="ETapoError">No such device is paired.</exception>
    function S200(const AIdOrNickname: string): TTapoS200;
    //** @abstract(An S210 light switch by device id or nickname.)
    //**
    //** @raises(ETapoError No such device is paired.)
    /// <summary>An S210 light switch by device id or nickname.</summary>
    /// <exception cref="ETapoError">No such device is paired.</exception>
    function S210(const AIdOrNickname: string): TTapoS210;
    //** @abstract(A T100 motion sensor by device id or nickname.)
    //**
    //** @raises(ETapoError No such device is paired.)
    /// <summary>A T100 motion sensor by device id or nickname.</summary>
    /// <exception cref="ETapoError">No such device is paired.</exception>
    function T100(const AIdOrNickname: string): TTapoT100;
    //** @abstract(A T110 contact sensor by device id or nickname.)
    //**
    //** @raises(ETapoError No such device is paired.)
    /// <summary>A T110 contact sensor by device id or nickname.</summary>
    /// <exception cref="ETapoError">No such device is paired.</exception>
    function T110(const AIdOrNickname: string): TTapoT110;
    //** @abstract(A T300 water leak sensor by device id or nickname.)
    //**
    //** @raises(ETapoError No such device is paired.)
    /// <summary>A T300 water leak sensor by device id or nickname.</summary>
    /// <exception cref="ETapoError">No such device is paired.</exception>
    function T300(const AIdOrNickname: string): TTapoT300;
    //** @abstract(A T310 or T315 temperature and humidity sensor by device id or nickname.)
    //**
    //** @raises(ETapoError No such device is paired.)
    /// <summary>A T310 or T315 temperature and humidity sensor by device id or nickname.</summary>
    /// <exception cref="ETapoError">No such device is paired.</exception>
    function T31x(const AIdOrNickname: string): TTapoT31x;
    //** @abstract(Every paired device, each as its own class.)
    //**
    //** Use @code(is) to tell them apart (for example @code(if C is TTapoT31x)). A model this unit
    //** does not know comes back as a plain TTapoHubChild.
    /// <summary>Every paired device, each as its own class.</summary>
    /// <remarks>
    ///   Use <c>is</c> to tell them apart (for example <c>if C is TTapoT31x</c>).
    ///   A model this unit does not know comes back as a plain TTapoHubChild.
    /// </remarks>
    function Children: TArray<TTapoHubChild>;
    //** @abstract(A child by device id, without checking that it exists.)
    //**
    //** @param(ADeviceId The child's device id, for example from @link(GetChildDeviceList).)
    //**
    //** @param(AClass The class to use for it.)
    //**
    //** @returns(The child, owned by the hub. No request is made.)
    /// <summary>A child by device id, without checking that it exists.</summary>
    /// <param name="ADeviceId">The child's device id, for example from <see cref="GetChildDeviceList"/>.</param>
    /// <param name="AClass">The class to use for it.</param>
    /// <returns>The child, owned by the hub. No request is made.</returns>
    function Child(const ADeviceId: string; AClass: TTapoChildDeviceClass): TTapoChildDevice;
  end;

  //** @abstract(The sounds an H100 can play.)
  //**
  //** arDefault leaves the choice to the hub's settings.
  /// <summary>The sounds an H100 can play.</summary>
  /// <remarks>arDefault leaves the choice to the hub's settings.</remarks>
  TTapoAlarmRingtone = (arDefault, arAlarm1, arAlarm2, arAlarm3, arAlarm4, arAlarm5,
    arConnection1, arConnection2, arDoorbellRing1, arDoorbellRing2, arDoorbellRing3,
    arDoorbellRing4, arDoorbellRing5, arDoorbellRing6, arDoorbellRing7, arDoorbellRing8,
    arDoorbellRing9, arDoorbellRing10, arDrippingTap, arPhoneRing);

  //** @abstract(The volume of an H100 alarm. avDefault leaves it to the hub's settings.)
  /// <summary>The volume of an H100 alarm. avDefault leaves it to the hub's settings.</summary>
  TTapoAlarmVolume = (avDefault, avMute, avLow, avNormal, avHigh);

  //** @abstract(Tapo H100 hub.)
  /// <summary>Tapo H100 hub.</summary>
  TTapoH100 = class(TTapoHub)
  public
    //** @abstract(Sounds the hub's alarm.)
    //**
    //** @param(ARingtone The sound.)
    //**
    //** @param(AVolume The volume.)
    //**
    //** @param(ADurationSeconds @link(TapoAlarmContinuous) @(until @link(StopAlarm)@),
    //** @link(TapoAlarmOnce), or a number of seconds.)
    //**
    //** @raises(ETapoError ADurationSeconds is invalid.)
    /// <summary>Sounds the hub's alarm.</summary>
    /// <param name="ARingtone">The sound.</param>
    /// <param name="AVolume">The volume.</param>
    /// <param name="ADurationSeconds">
    ///   <see cref="TapoAlarmContinuous"/> (until <see cref="StopAlarm"/>),
    ///   <see cref="TapoAlarmOnce"/>, or a number of seconds.
    /// </param>
    /// <exception cref="ETapoError">ADurationSeconds is invalid.</exception>
    procedure PlayAlarm(ARingtone: TTapoAlarmRingtone = arDefault;
      AVolume: TTapoAlarmVolume = avDefault; ADurationSeconds: Integer = -1);
    //** @abstract(Silences the alarm.)
    /// <summary>Silences the alarm.</summary>
    procedure StopAlarm;
    //** @abstract(Reads the names of the sounds the hub can play.)
    /// <summary>Reads the names of the sounds the hub can play.</summary>
    function GetSupportedRingtoneList: TArray<string>;
  end;

  //** @abstract(A camera paired to an H200 or H500.)
  /// <summary>A camera paired to an H200 or H500.</summary>
  TTapoHubCameraInfo = record
    //** @abstract(The camera's device id, used by the recording functions.)
    /// <summary>The camera's device id, used by the recording functions.</summary>
    DeviceId: string;
    //** @abstract(The hub's device id.)
    /// <summary>The hub's device id.</summary>
    ParentDeviceId: string;
    //** @abstract(The name given in the Tapo app.)
    /// <summary>The name given in the Tapo app.</summary>
    Alias: string;
    //** @abstract(The camera model.)
    /// <summary>The camera model.</summary>
    DeviceModel: string;
    //** @abstract(The device type.)
    /// <summary>The device type.</summary>
    DeviceType: string;
    //** @abstract(The device category.)
    /// <summary>The device category.</summary>
    Category: string;
    //** @abstract(The MAC address.)
    /// <summary>The MAC address.</summary>
    Mac: string;
    //** @abstract(How the camera connects.)
    /// <summary>How the camera connects.</summary>
    NetworkMode: string;
    //** @abstract(The backup Wi-Fi: 'auto', empty for none, or an SSID.)
    /// <summary>The backup Wi-Fi: 'auto', empty for none, or an SSID.</summary>
    BackupWifi: string;
    //** @abstract(True if the backup Wi-Fi is enabled.)
    /// <summary>True if the backup Wi-Fi is enabled.</summary>
    WifiBackupEnabled: Boolean;
    //** @abstract(True if the camera records to the hub.)
    /// <summary>True if the camera records to the hub.</summary>
    HubStorageEnabled: Boolean;
    //** @abstract(True if the camera records continuously.)
    /// <summary>True if the camera records continuously.</summary>
    Plan24hRecord: Boolean;
    //** @abstract(What the camera can recognise, as bits: 1 person, 2 pet, 4 vehicle, 8 face.)
    /// <summary>What the camera can recognise, as bits: 1 person, 2 pet, 4 vehicle, 8 face.</summary>
    AiCameraSupport: Int64;
    //** @abstract(The whole entry as formatted JSON.)
    /// <summary>The whole entry as formatted JSON.</summary>
    Raw: string;
    //** @abstract(True if the camera can recognise people.)
    /// <summary>True if the camera can recognise people.</summary>
    function SupportsPerson: Boolean;
    //** @abstract(True if the camera can recognise pets.)
    /// <summary>True if the camera can recognise pets.</summary>
    function SupportsPet: Boolean;
    //** @abstract(True if the camera can recognise vehicles.)
    /// <summary>True if the camera can recognise vehicles.</summary>
    function SupportsVehicle: Boolean;
    //** @abstract(True if the camera can recognise faces.)
    /// <summary>True if the camera can recognise faces.</summary>
    function SupportsFace: Boolean;
  end;

  //** @abstract(A camera hub's time zone.)
  /// <summary>A camera hub's time zone.</summary>
  TTapoHubTimezone = record
    //** @abstract(The offset, for example 'UTC+01:00'.)
    /// <summary>The offset, for example 'UTC+01:00'.</summary>
    Timezone: string;
    //** @abstract(The IANA time zone name, for example 'Europe/London'.)
    /// <summary>The IANA time zone name, for example 'Europe/London'.</summary>
    ZoneId: string;
  end;

  //** @abstract(A recording stored on a camera hub.)
  /// <summary>A recording stored on a camera hub.</summary>
  TTapoRecording = record
    //** @abstract(The start, local time.)
    /// <summary>The start, local time.</summary>
    StartTime: TDateTime;
    //** @abstract(The end, local time.)
    /// <summary>The end, local time.</summary>
    EndTime: TDateTime;
    //** @abstract(What triggered the recording, as the hub reports it @(1 continuous, 2 motion, 6
    //** person ...@).)
    //**
    //** @seealso(VideoTypeName)
    /// <summary>What triggered the recording, as the hub reports it (1 continuous, 2 motion, 6 person ...).</summary>
    /// <seealso cref="VideoTypeName"/>
    VideoType: Integer;
    //** @abstract(The name of @link(VideoType), for example 'Motion' or 'Person'.)
    /// <summary>The name of <see cref="VideoType"/>, for example 'Motion' or 'Person'.</summary>
    function VideoTypeName: string;
  end;

  //** @abstract(Tapo H200 and H500 camera hub.)
  //**
  //** Logs in over AES SSL as the hub's local "admin" account with your Tapo password. Reboot and
  //** FactoryReset are not supported by these hubs.
  /// <summary>Tapo H200 and H500 camera hub.</summary>
  /// <remarks>
  ///   Logs in over AES SSL as the hub's local "admin" account with your
  ///   Tapo password. Reboot and FactoryReset are not supported by these hubs.
  /// </remarks>
  TTapoCameraHub = class(TTapoHub)
  private
    FPlayerId: string;
  public
    //** @abstract(Creates the hub object; see @link(TTapoDevice.Create).)
    /// <summary>Creates the hub object; see <see cref="TTapoDevice.Create"/>.</summary>
    constructor Create(AClient: TTapoClient; const AHost: string); override;
    //** @abstract(Returns dfSmartCam.)
    /// <summary>Returns dfSmartCam.</summary>
    class function Family: TTapoDeviceFamily; override;
    //** @abstract(Returns amCameraHub.)
    /// <summary>Returns amCameraHub.</summary>
    class function AuthMode: TTapoAuthMode; override;

    //** @abstract(Reads the cameras paired to the hub.)
    /// <summary>Reads the cameras paired to the hub.</summary>
    function GetGeneralDeviceList: TArray<TTapoHubCameraInfo>;
    //** @abstract(Reads the paired cameras as formatted JSON.)
    /// <summary>Reads the paired cameras as formatted JSON.</summary>
    function GetGeneralDeviceListJSON: string;
    //** @abstract(Reads the hub's time zone.)
    /// <summary>Reads the hub's time zone.</summary>
    function GetTimezone: TTapoHubTimezone;
    //** @abstract(Reads the days that have recordings of a camera.)
    //**
    //** @param(AChildDeviceId The camera's device id, from @link(GetGeneralDeviceList).)
    //**
    //** @param(AStartDate The first day, on the hub's calendar.)
    //**
    //** @param(AEndDate The last day, on the hub's calendar.)
    //**
    //** @raises(ETapoError AEndDate is before AStartDate.)
    /// <summary>Reads the days that have recordings of a camera.</summary>
    /// <param name="AChildDeviceId">The camera's device id, from <see cref="GetGeneralDeviceList"/>.</param>
    /// <param name="AStartDate">The first day, on the hub's calendar.</param>
    /// <param name="AEndDate">The last day, on the hub's calendar.</param>
    /// <exception cref="ETapoError">AEndDate is before AStartDate.</exception>
    function GetRecordingDates(const AChildDeviceId: string; AStartDate, AEndDate: TDate): TArray<TDate>;
    //** @abstract(Reads the recordings of a camera between two times.)
    //**
    //** Downloading a recording is not supported.
    //**
    //** @param(AChildDeviceId The camera's device id, from @link(GetGeneralDeviceList).)
    //**
    //** @param(AStart The start, local time.)
    //**
    //** @param(AEnd The end, local time.)
    //**
    //** @raises(ETapoError AEnd is before AStart.)
    /// <summary>Reads the recordings of a camera between two times.</summary>
    /// <param name="AChildDeviceId">The camera's device id, from <see cref="GetGeneralDeviceList"/>.</param>
    /// <param name="AStart">The start, local time.</param>
    /// <param name="AEnd">The end, local time.</param>
    /// <exception cref="ETapoError">AEnd is before AStart.</exception>
    /// <remarks>Downloading a recording is not supported.</remarks>
    function GetRecordings(const AChildDeviceId: string; AStart, AEnd: TDateTime): TArray<TTapoRecording>;
  end;

  //** @abstract(Tapo H200: the same as @link(TTapoCameraHub).)
  /// <summary>Tapo H200: the same as <see cref="TTapoCameraHub"/>.</summary>
  TTapoH200 = TTapoCameraHub;
  //** @abstract(Tapo H500: the same as @link(TTapoCameraHub).)
  /// <summary>Tapo H500: the same as <see cref="TTapoCameraHub"/>.</summary>
  TTapoH500 = TTapoCameraHub;

const
  //** @abstract(Alarm duration: until @link(TTapoH100.StopAlarm) is called.)
  /// <summary>Alarm duration: until <see cref="TTapoH100.StopAlarm"/> is called.</summary>
  TapoAlarmContinuous = -1;
  //** @abstract(Alarm duration: play the sound once.)
  /// <summary>Alarm duration: play the sound once.</summary>
  TapoAlarmOnce = 0;

implementation

const
  ChildPageSize = 10;
  MAX_CHILD_PAGES = 64;
  RecordingPageSize = 100;
  RecordingMaxStartIndex = 12288;

  RingtoneNames: array[TTapoAlarmRingtone] of string = ('', 'Alarm 1', 'Alarm 2',
    'Alarm 3', 'Alarm 4', 'Alarm 5', 'Connection 1', 'Connection 2', 'Doorbell Ring 1',
    'Doorbell Ring 2', 'Doorbell Ring 3', 'Doorbell Ring 4', 'Doorbell Ring 5',
    'Doorbell Ring 6', 'Doorbell Ring 7', 'Doorbell Ring 8', 'Doorbell Ring 9',
    'Doorbell Ring 10', 'Dripping Tap', 'Phone Ring');
  VolumeNames: array[TTapoAlarmVolume] of string = ('', 'mute', 'low', 'normal', 'high');

procedure ValidationError(const AField, AMessage: string);
begin
  raise ETapoError.CreateCode(-1, AField + ': ' + AMessage);
end;

function FormatJSON(R: TJSONObject): string;
begin
  try
    Result := R.Format;
  finally
    R.Free;
  end;
end;

{ ============================================================================ }
{ Records                                                                      }
{ ============================================================================ }

class function TTapoHubChildInfo.FromJSON(Obj: TJSONObject): TTapoHubChildInfo;
begin
  Result.DeviceId := JStr(Obj, 'device_id');
  Result.ParentDeviceId := JStr(Obj, 'parent_device_id');
  Result.Model := JStr(Obj, 'model');
  Result.Nickname := JBase64Str(Obj, 'nickname');
  Result.DeviceType := JStr(Obj, 'type');
  Result.Category := JStr(Obj, 'category');
  Result.FirmwareVersion := JStr(Obj, 'fw_ver');
  Result.HardwareVersion := JStr(Obj, 'hw_ver');
  Result.HardwareId := JStr(Obj, 'hw_id');
  Result.OemId := JStr(Obj, 'oem_id');
  Result.Mac := JStr(Obj, 'mac');
  Result.Region := JStr(Obj, 'region');
  Result.Specs := JStr(Obj, 'specs');
  Result.Avatar := JStr(Obj, 'avatar');
  Result.Status := JStr(Obj, 'status');
  if JHas(Obj, 'at_low_battery') then
    Result.AtLowBattery := JBool(Obj, 'at_low_battery')
  else
    Result.AtLowBattery := JBool(Obj, 'is_low');           // S210
  Result.BatteryPercentage := Integer(JInt64(Obj, 'battery_percentage', -1));
  Result.RSSI := Integer(JInt64(Obj, 'rssi'));
  Result.SignalLevel := Integer(JInt64(Obj, 'signal_level'));
  Result.JammingRSSI := Integer(JInt64(Obj, 'jamming_rssi'));
  Result.JammingSignalLevel := Integer(JInt64(Obj, 'jamming_signal_level'));
  Result.BindCount := Integer(JInt64(Obj, 'bind_count'));
  Result.ReportInterval := Integer(JInt64(Obj, 'report_interval'));
  Result.LastOnboardingTimestamp := JInt64(Obj, 'lastOnboardingTimestamp');
  Result.StatusFollowEdge := JBool(Obj, 'status_follow_edge');
  if Obj <> nil then
    Result.Raw := Obj.Format
  else
    Result.Raw := '';
end;

function TTapoHubCameraInfo.SupportsPerson: Boolean;
begin
  Result := (AiCameraSupport and 1) <> 0;
end;

function TTapoHubCameraInfo.SupportsPet: Boolean;
begin
  Result := (AiCameraSupport and 2) <> 0;
end;

function TTapoHubCameraInfo.SupportsVehicle: Boolean;
begin
  Result := (AiCameraSupport and 4) <> 0;
end;

function TTapoHubCameraInfo.SupportsFace: Boolean;
begin
  Result := (AiCameraSupport and 8) <> 0;
end;

function TTapoRecording.VideoTypeName: string;
begin
  case VideoType of
    1: Result := 'Timing';
    2: Result := 'Motion';
    3: Result := 'Tamper';
    4: Result := 'LineCrossing';
    5: Result := 'AreaIntrusion';
    6: Result := 'Person';
    7: Result := 'BabyCry';
    8: Result := 'Vehicle';
    9: Result := 'Pet';
    10: Result := 'RingAlarm';
    11: Result := 'Bark';
    12: Result := 'Meow';
    13: Result := 'GlassBreaking';
    14: Result := 'Smoke';
    15: Result := 'PackageDelivered';
    16: Result := 'PackagePickedUp';
    17: Result := 'MissedDoorbellRing';
    18: Result := 'AnsweredDoorbellRing';
    19: Result := 'AntiTheft';
    20: Result := 'Face';
    21: Result := 'UnfamiliarFace';
    22: Result := 'UnfamiliarPerson';
    23: Result := 'BabyLeave';
    24: Result := 'BabyCaregiver';
    25: Result := 'BabyAsleep';
    26: Result := 'BabyAwake';
    27: Result := 'FaceCover';
    28: Result := 'SafeFenceOut';
    30: Result := 'BabyMotion';
    31: Result := 'PanoramicVideo';
    33: Result := 'Animal';
  else
    Result := 'Other(' + IntToStr(VideoType) + ')';
  end;
end;

{ ============================================================================ }
{ Hub children                                                                 }
{ ============================================================================ }

function TTapoHubChild.GetChildInfo: TTapoHubChildInfo;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result := TTapoHubChildInfo.FromJSON(R);
  finally
    R.Free;
  end;
end;

function TTapoTriggerSensor.GetTriggerLogs(APageSize: Integer; AStartId: Int64): TTapoTriggerLogs;
var
  R, L: TJSONObject;
  A: TJSONArray;
  I: Integer;
begin
  R := Execute('get_trigger_logs', JObject(['page_size', APageSize, 'start_id', AStartId]));
  try
    Result.StartId := JInt64(R, 'start_id');
    Result.Sum := JInt64(R, 'sum');
    Result.Logs := nil;
    A := JArr(R, 'logs');
    if A <> nil then
    begin
      SetLength(Result.Logs, A.Count);
      for I := 0 to A.Count - 1 do
      begin
        L := nil;
        if A.Items[I] is TJSONObject then
          L := TJSONObject(A.Items[I]);
        Result.Logs[I].Id := JInt64(L, 'id');
        Result.Logs[I].Time := UnixToDateTime(JInt64(L, 'timestamp'), False);
        Result.Logs[I].Event := JStr(L, 'event');
        Result.Logs[I].RotationDegrees := Integer(JInt64(JObj(L, 'params'), 'rotate_deg'));
        if L <> nil then
          Result.Logs[I].Raw := L.ToJSON
        else
          Result.Logs[I].Raw := '';
      end;
    end;
  finally
    R.Free;
  end;
end;

{ TTapoKE100 }

function TTapoKE100.GetKE100Info: TTapoKE100Info;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result.Child := TTapoHubChildInfo.FromJSON(R);
    Result.ChildProtection := JBool(R, 'child_protection');
    Result.FrostProtection := JBool(R, 'frost_protection_on');
    Result.CurrentTemperature := JFloat(R, 'current_temp');
    Result.TargetTemperature := JFloat(R, 'target_temp');
    Result.MinControlTemperature := Integer(JInt64(R, 'min_control_temp'));
    Result.MaxControlTemperature := Integer(JInt64(R, 'max_control_temp'));
    Result.TemperatureOffset := Integer(JInt64(R, 'temp_offset'));
    Result.TemperatureUnit := JStr(R, 'temp_unit');
    Result.Location := JStr(R, 'location');
  finally
    R.Free;
  end;
end;

procedure TTapoKE100.SetChildProtection(AOn: Boolean);
begin
  SetDeviceInfo(JObject(['child_protection', AOn]));
end;

procedure TTapoKE100.SetFrostProtection(AOn: Boolean);
begin
  SetDeviceInfo(JObject(['frost_protection_on', AOn]));
end;

procedure TTapoKE100.SetMaxControlTemperature(AValue: Integer);
begin
  SetDeviceInfo(JObject(['max_control_temp', AValue, 'temp_unit', 'celsius']));
end;

procedure TTapoKE100.SetMinControlTemperature(AValue: Integer);
begin
  SetDeviceInfo(JObject(['min_control_temp', AValue, 'temp_unit', 'celsius']));
end;

procedure TTapoKE100.SetTargetTemperature(AValue: Integer);
var
  Info: TTapoKE100Info;
begin
  Info := GetKE100Info;
  if (AValue < Info.MinControlTemperature) or (AValue > Info.MaxControlTemperature) then
    ValidationError('target_temperature', Format('must be between %d (min_control_temperature) ' +
      'and %d (max_control_temperature)', [Info.MinControlTemperature, Info.MaxControlTemperature]));
  SetDeviceInfo(JObject(['target_temp', AValue, 'temp_unit', 'celsius']));
end;

procedure TTapoKE100.SetTemperatureOffset(AValue: Integer);
begin
  if (AValue < -10) or (AValue > 10) then
    ValidationError('temperature_offset', 'must be between -10 and 10');
  SetDeviceInfo(JObject(['temp_offset', AValue, 'temp_unit', 'celsius']));
end;

{ TTapoS200 }

function TTapoS200.GetS200Info: TTapoHubChildInfo;
begin
  Result := GetChildInfo;
end;

{ TTapoS210 }

procedure TTapoS210.TurnOn;
begin
  SetOn(True);
end;

procedure TTapoS210.TurnOff;
begin
  SetOn(False);
end;

procedure TTapoS210.SetOn(AOn: Boolean);
begin
  SetDeviceInfo(JObject(['device_on', AOn]));
end;

function TTapoS210.IsOn: Boolean;
begin
  Result := GetS210Info.DeviceOn;
end;

function TTapoS210.GetS210Info: TTapoS210Info;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result.Child := TTapoHubChildInfo.FromJSON(R);
    Result.DeviceOn := JBool(R, 'device_on');
    Result.Position := Integer(JInt64(R, 'position'));
    Result.SlotNumber := Integer(JInt64(R, 'slot_number'));
  finally
    R.Free;
  end;
end;

function UsagePeriodOf(Obj: TJSONObject): TTapoUsageByPeriod;
begin
  Result.Today := JInt64(Obj, 'today', -1);
  Result.Past7Days := JInt64(Obj, 'past7', -1);
  Result.Past30Days := JInt64(Obj, 'past30', -1);
end;

function TTapoS210.GetDeviceUsage: TTapoDeviceUsage;
var
  R: TJSONObject;
begin
  R := Execute('get_device_usage');
  try
    Result.TimeUsage := UsagePeriodOf(JObj(R, 'time_usage'));
    Result.PowerUsage := UsagePeriodOf(JObj(R, 'power_usage'));
    Result.SavedPower := UsagePeriodOf(JObj(R, 'saved_power'));
    Result.Raw := R.Format;
  finally
    R.Free;
  end;
end;

{ TTapoT100 / T110 / T300 }

function TTapoT100.GetT100Info: TTapoT100Info;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result.Child := TTapoHubChildInfo.FromJSON(R);
    Result.Detected := JBool(R, 'detected');
  finally
    R.Free;
  end;
end;

function TTapoT110.GetT110Info: TTapoT110Info;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result.Child := TTapoHubChildInfo.FromJSON(R);
    Result.Open := JBool(R, 'open');
  finally
    R.Free;
  end;
end;

function TTapoT300.GetT300Info: TTapoT300Info;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result.Child := TTapoHubChildInfo.FromJSON(R);
    Result.InAlarm := JBool(R, 'in_alarm');
    Result.WaterLeakStatus := JStr(R, 'water_leak_status');
  finally
    R.Free;
  end;
end;

{ TTapoT31x }

function TTapoT31x.GetT31xInfo: TTapoT31xInfo;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result.Child := TTapoHubChildInfo.FromJSON(R);
    Result.CurrentTemperature := JFloat(R, 'current_temp');
    Result.CurrentHumidity := Integer(JInt64(R, 'current_humidity'));
    Result.TemperatureException := JFloat(R, 'current_temp_exception');
    Result.HumidityException := Integer(JInt64(R, 'current_humidity_exception'));
    Result.TemperatureUnit := JStr(R, 'temp_unit');
  finally
    R.Free;
  end;
end;

function IntAt(A: TJSONArray; I: Integer): Int64;
begin
  if (A <> nil) and (I < A.Count) and (A.Items[I] is TJSONNumber) then
    Result := TJSONNumber(A.Items[I]).AsInt64
  else
    Result := -1000;
end;

// Records run oldest first, one every 15 minutes, the newest at the 15-minute
// mark at or before local_time; -1000 marks a missing reading.
function TTapoT31x.GetTemperatureHumidityRecords: TTapoTempHumidityRecords;
var
  R: TJSONObject;
  Hum, HumEx, Temp, TempEx: TJSONArray;
  N, I, Count: Integer;
  LocalUnix, SlotUnix: Int64;
  List: TList<TTapoTempHumidityRecord>;
  Rec: TTapoTempHumidityRecord;
begin
  R := Execute('get_temp_humidity_records');
  List := TList<TTapoTempHumidityRecord>.Create;
  try
    LocalUnix := JInt64(R, 'local_time');
    Result.RetrievedAt := UnixToDateTime(LocalUnix, False);
    Result.TemperatureUnit := JStr(R, 'temp_unit');
    Hum := JArr(R, 'past24h_humidity');
    HumEx := JArr(R, 'past24h_humidity_exception');
    Temp := JArr(R, 'past24h_temp');
    TempEx := JArr(R, 'past24h_temp_exception');
    N := 0;
    if Temp <> nil then
      N := Temp.Count;
    // the four arrays are zipped, so the shortest decides
    if (Hum = nil) or (HumEx = nil) or (TempEx = nil) then
      N := 0
    else
    begin
      if Hum.Count < N then N := Hum.Count;
      if HumEx.Count < N then N := HumEx.Count;
      if TempEx.Count < N then N := TempEx.Count;
    end;
    SlotUnix := LocalUnix - (LocalUnix mod (15 * 60));
    Count := 0;
    for I := N - 1 downto 0 do      // newest first
    begin
      if (IntAt(Temp, I) <> -1000) and (IntAt(TempEx, I) <> -1000) and
         (IntAt(Hum, I) <> -1000) and (IntAt(HumEx, I) <> -1000) then
      begin
        Rec.Time := UnixToDateTime(SlotUnix - Int64(Count) * 15 * 60, False);
        Rec.Temperature := IntAt(Temp, I) / 10;
        Rec.TemperatureException := IntAt(TempEx, I) / 10;
        Rec.Humidity := Integer(IntAt(Hum, I));
        Rec.HumidityException := Integer(IntAt(HumEx, I));
        List.Insert(0, Rec);
      end;
      Inc(Count);
    end;
    Result.Records := List.ToArray;
  finally
    List.Free;
    R.Free;
  end;
end;

{ ============================================================================ }
{ TTapoHub                                                                     }
{ ============================================================================ }

function TTapoHub.GetChildDeviceList: TArray<TTapoHubChildInfo>;
var
  R: TJSONObject;
  A: TJSONArray;
  List: TList<TTapoHubChildInfo>;
  Page, I, StartIndex: Integer;
begin
  List := TList<TTapoHubChildInfo>.Create;
  try
    StartIndex := 0;
    for Page := 1 to MAX_CHILD_PAGES do
    begin
      if Family = dfSmartCam then
        R := Execute('getChildDeviceList', JObject(['childControl',
          JObject(['start_index', StartIndex])]))
      else
        R := Execute('get_child_device_list', JObject(['start_index', StartIndex]));
      try
        A := JArr(R, 'child_device_list');
        if A = nil then
          Break;
        for I := 0 to A.Count - 1 do
          if A.Items[I] is TJSONObject then
            List.Add(TTapoHubChildInfo.FromJSON(TJSONObject(A.Items[I])));
        // a full page of 10 means another may follow
        if A.Count < ChildPageSize then
          Break;
        Inc(StartIndex, ChildPageSize);
      finally
        R.Free;
      end;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TTapoHub.GetChildDeviceListJSON(AStartIndex: Integer): string;
begin
  if Family = dfSmartCam then
    Result := FormatJSON(Execute('getChildDeviceList', JObject(['childControl',
      JObject(['start_index', AStartIndex])])))
  else
    Result := FormatJSON(Execute('get_child_device_list', JObject(['start_index', AStartIndex])));
end;

function TTapoHub.GetChildDeviceComponentListJSON: string;
begin
  if Family = dfSmartCam then
    Result := FormatJSON(Execute('getChildDeviceComponentList', JObject(['childControl',
      JObject(['start_index', 0])])))
  else
    Result := FormatJSON(Execute('get_child_device_component_list'));
end;

function TTapoHub.FindChild(const AModels: array of string; const AIdOrNickname: string;
  AClass: TTapoChildDeviceClass): TTapoChildDevice;
var
  Info: TTapoHubChildInfo;
  I: Integer;
  Wanted: string;
begin
  Wanted := '';
  for I := Low(AModels) to High(AModels) do
    Wanted := Wanted + '/' + AModels[I];
  for Info in GetChildDeviceList do
    for I := Low(AModels) to High(AModels) do
      if SameText(Info.Model, AModels[I]) and
         ((Info.DeviceId = AIdOrNickname) or (Info.Nickname = AIdOrNickname)) then
        Exit(ChildFor(Info.DeviceId, AClass));
  raise ETapoError.CreateCode(-1, Format('%s has no %s with id or nickname "%s"',
    [Host, Copy(Wanted, 2, MaxInt), AIdOrNickname]));
end;

function TTapoHub.KE100(const AIdOrNickname: string): TTapoKE100;
begin
  Result := FindChild(['KE100'], AIdOrNickname, TTapoKE100) as TTapoKE100;
end;

function TTapoHub.S200(const AIdOrNickname: string): TTapoS200;
begin
  Result := FindChild(['S200B', 'S200D'], AIdOrNickname, TTapoS200) as TTapoS200;
end;

function TTapoHub.S210(const AIdOrNickname: string): TTapoS210;
begin
  Result := FindChild(['S210'], AIdOrNickname, TTapoS210) as TTapoS210;
end;

function TTapoHub.T100(const AIdOrNickname: string): TTapoT100;
begin
  Result := FindChild(['T100'], AIdOrNickname, TTapoT100) as TTapoT100;
end;

function TTapoHub.T110(const AIdOrNickname: string): TTapoT110;
begin
  Result := FindChild(['T110'], AIdOrNickname, TTapoT110) as TTapoT110;
end;

function TTapoHub.T300(const AIdOrNickname: string): TTapoT300;
begin
  Result := FindChild(['T300'], AIdOrNickname, TTapoT300) as TTapoT300;
end;

function TTapoHub.T31x(const AIdOrNickname: string): TTapoT31x;
begin
  Result := FindChild(['T310', 'T315'], AIdOrNickname, TTapoT31x) as TTapoT31x;
end;

function ChildClassForModel(const AModel: string): TTapoChildDeviceClass;
var
  M: string;
begin
  M := UpperCase(AModel);
  if M = 'KE100' then
    Result := TTapoKE100
  else if (M = 'S200B') or (M = 'S200D') then
    Result := TTapoS200
  else if M = 'S210' then
    Result := TTapoS210
  else if M = 'T100' then
    Result := TTapoT100
  else if M = 'T110' then
    Result := TTapoT110
  else if M = 'T300' then
    Result := TTapoT300
  else if (M = 'T310') or (M = 'T315') then
    Result := TTapoT31x
  else
    Result := nil;
end;

type
  // A child of a model this unit does not know: info only.
  TTapoGenericHubChild = class(TTapoHubChild);

function TTapoHub.Children: TArray<TTapoHubChild>;
var
  Infos: TArray<TTapoHubChildInfo>;
  I: Integer;
  Cls: TTapoChildDeviceClass;
begin
  Infos := GetChildDeviceList;
  SetLength(Result, Length(Infos));
  for I := 0 to High(Infos) do
  begin
    Cls := ChildClassForModel(Infos[I].Model);
    if Cls = nil then
      Cls := TTapoGenericHubChild;
    Result[I] := ChildFor(Infos[I].DeviceId, Cls) as TTapoHubChild;
  end;
end;

function TTapoHub.Child(const ADeviceId: string; AClass: TTapoChildDeviceClass): TTapoChildDevice;
begin
  Result := ChildFor(ADeviceId, AClass);
end;

{ ============================================================================ }
{ TTapoH100                                                                    }
{ ============================================================================ }

procedure TTapoH100.PlayAlarm(ARingtone: TTapoAlarmRingtone; AVolume: TTapoAlarmVolume;
  ADurationSeconds: Integer);
var
  P: TJSONObject;
begin
  if ADurationSeconds < TapoAlarmContinuous then
    ValidationError('duration', 'use TapoAlarmContinuous, TapoAlarmOnce or a number of seconds');
  P := TJSONObject.Create;
  if ARingtone <> arDefault then
    P.AddPair('alarm_type', RingtoneNames[ARingtone]);
  if AVolume <> avDefault then
    P.AddPair('alarm_volume', VolumeNames[AVolume]);
  if ADurationSeconds <> TapoAlarmContinuous then
    P.AddPair('alarm_duration', TJSONNumber.Create(ADurationSeconds));
  Execute('play_alarm', P).Free;
end;

procedure TTapoH100.StopAlarm;
begin
  Execute('stop_alarm').Free;
end;

function TTapoH100.GetSupportedRingtoneList: TArray<string>;
var
  R: TJSONObject;
  A: TJSONArray;
  I: Integer;
begin
  R := Execute('get_support_alarm_type_list');
  try
    A := JArr(R, 'alarm_type_list');
    Result := nil;
    if A <> nil then
    begin
      SetLength(Result, A.Count);
      for I := 0 to A.Count - 1 do
        Result[I] := A.Items[I].Value;
    end;
  finally
    R.Free;
  end;
end;

{ ============================================================================ }
{ TTapoCameraHub                                                               }
{ ============================================================================ }

constructor TTapoCameraHub.Create(AClient: TTapoClient; const AHost: string);
begin
  inherited Create(AClient, AHost);
  // identifies this client to the hub's playback search
  FPlayerId := LowerCase(TGUID.NewGuid.ToString);
  FPlayerId := Copy(FPlayerId, 2, Length(FPlayerId) - 2);   // strip the braces
end;

class function TTapoCameraHub.Family: TTapoDeviceFamily;
begin
  Result := dfSmartCam;
end;

class function TTapoCameraHub.AuthMode: TTapoAuthMode;
begin
  Result := amCameraHub;
end;

function GeneralDeviceListParams: TJSONObject;
begin
  Result := JObject(['general_camera_manage',
    JObject(['paired_general_device_list', TJSONObject.Create])]);
end;

function TTapoCameraHub.GetGeneralDeviceList: TArray<TTapoHubCameraInfo>;
var
  R, D: TJSONObject;
  A: TJSONArray;
  I: Integer;
begin
  R := Execute('getGeneralDeviceList', GeneralDeviceListParams);
  try
    A := JArr(JObj(R, 'general_camera_manage'), 'paired_general_device_list');
    Result := nil;
    if A = nil then
      Exit;
    SetLength(Result, A.Count);
    for I := 0 to A.Count - 1 do
    begin
      D := nil;
      if A.Items[I] is TJSONObject then
        D := TJSONObject(A.Items[I]);
      Result[I].DeviceId := JStr(D, 'device_id');
      Result[I].ParentDeviceId := JStr(D, 'parent_device_id');
      Result[I].Alias := JStr(D, 'alias');
      Result[I].DeviceModel := JStr(D, 'device_model');
      Result[I].DeviceType := JStr(D, 'device_type');
      Result[I].Category := JStr(D, 'category');
      Result[I].Mac := JStr(D, 'mac');
      Result[I].NetworkMode := JStr(D, 'network_mode');
      Result[I].BackupWifi := JStr(D, 'backup_wifi');
      Result[I].WifiBackupEnabled := JBool(D, 'wifi_backup_enabled');
      Result[I].HubStorageEnabled := JBool(D, 'hub_storage_enabled');
      Result[I].Plan24hRecord := JBool(D, 'plan_24h_record');
      Result[I].AiCameraSupport := JInt64(D, 'ai_camera_support');
      if D <> nil then
        Result[I].Raw := D.Format
      else
        Result[I].Raw := '';
    end;
  finally
    R.Free;
  end;
end;

function TTapoCameraHub.GetGeneralDeviceListJSON: string;
begin
  Result := FormatJSON(Execute('getGeneralDeviceList', GeneralDeviceListParams));
end;

function TTapoCameraHub.GetTimezone: TTapoHubTimezone;
var
  R, B: TJSONObject;
begin
  R := Execute('getTimezone', JObject(['system', JObject(['name', 'basic'])]));
  try
    B := JObj(JObj(R, 'system'), 'basic');
    Result.Timezone := JStr(B, 'timezone');
    Result.ZoneId := JStr(B, 'zone_id');
  finally
    R.Free;
  end;
end;

function TTapoCameraHub.GetRecordingDates(const AChildDeviceId: string;
  AStartDate, AEndDate: TDate): TArray<TDate>;
var
  R, Entry, D: TJSONObject;
  A, Channel: TJSONArray;
  I: Integer;
  S: string;
  List: TList<TDate>;
begin
  if DateOf(AEndDate) < DateOf(AStartDate) then
    ValidationError('end_date', 'must not be before the start date');
  Channel := TJSONArray.Create;
  Channel.Add(0);
  R := Execute('searchDateWithVideo', JObject(['playback', JObject(['search_year_utility',
    JObject(['channel', Channel, 'start_date', FormatDateTime('yyyymmdd', AStartDate),
      'end_date', FormatDateTime('yyyymmdd', AEndDate), 'child_device_id', AChildDeviceId])])]));
  List := TList<TDate>.Create;
  try
    // {"playback": {"search_results": [{"search_results_1": {"date": "20260906"}}, ...]}}
    A := JArr(JObj(R, 'playback'), 'search_results');
    if A <> nil then
      for I := 0 to A.Count - 1 do
        if (A.Items[I] is TJSONObject) and (TJSONObject(A.Items[I]).Count > 0) and
           (TJSONObject(A.Items[I]).Pairs[0].JsonValue is TJSONObject) then
        begin
          Entry := TJSONObject(A.Items[I]);
          D := TJSONObject(Entry.Pairs[0].JsonValue);
          S := JStr(D, 'date');
          if Length(S) = 8 then
            List.Add(EncodeDate(StrToInt(Copy(S, 1, 4)), StrToInt(Copy(S, 5, 2)),
              StrToInt(Copy(S, 7, 2))));
        end;
    Result := List.ToArray;
  finally
    List.Free;
    R.Free;
  end;
end;

// "startTime"/"endTime" (or start_time/end_time) as Unix seconds, a numeric
// string or an RFC 3339 string.
function RecordingTime(Obj: TJSONObject; const AName, AAlias: string): TDateTime;
var
  V: TJSONValue;
  S: string;
  N: Int64;
begin
  V := Obj.GetValue(AName);
  if V = nil then
    V := Obj.GetValue(AAlias);
  if V is TJSONNumber then
    Exit(UnixToDateTime(TJSONNumber(V).AsInt64, False));
  if V = nil then
    Exit(0);
  S := V.Value;
  if TryStrToInt64(S, N) then
    Result := UnixToDateTime(N, False)
  else
    Result := ISO8601ToDate(S, False);
end;

function TTapoCameraHub.GetRecordings(const AChildDeviceId: string;
  AStart, AEnd: TDateTime): TArray<TTapoRecording>;
var
  R, Entry, Rec: TJSONObject;
  A: TJSONArray;
  StartIndex, I, PageCount: Integer;
  S, E: Int64;
  List: TList<TTapoRecording>;
  Item: TTapoRecording;
begin
  if AEnd < AStart then
    ValidationError('end_time', 'must not be before the start time');
  S := DateTimeToUnix(AStart, False);
  E := DateTimeToUnix(AEnd, False);
  List := TList<TTapoRecording>.Create;
  try
    StartIndex := 0;
    while StartIndex <= RecordingMaxStartIndex do
    begin
      R := Execute('searchVideoWithUTC', JObject(['playback', JObject(['search_video_with_utc',
        JObject(['channel', 0, 'start_time', S, 'end_time', E, 'start_index', StartIndex,
          'end_index', StartIndex + RecordingPageSize - 1, 'child_device_id', AChildDeviceId,
          'player_id', FPlayerId])])]));
      try
        PageCount := 0;
        // {"playback": {"search_video_results": [{"search_video_results_1": {...}}, ...]}}
        A := JArr(JObj(R, 'playback'), 'search_video_results');
        if A <> nil then
          for I := 0 to A.Count - 1 do
            if (A.Items[I] is TJSONObject) and (TJSONObject(A.Items[I]).Count > 0) and
               (TJSONObject(A.Items[I]).Pairs[0].JsonValue is TJSONObject) then
            begin
              Entry := TJSONObject(A.Items[I]);
              Rec := TJSONObject(Entry.Pairs[0].JsonValue);
              Item.StartTime := RecordingTime(Rec, 'startTime', 'start_time');
              Item.EndTime := RecordingTime(Rec, 'endTime', 'end_time');
              Item.VideoType := Integer(JInt64(Rec, 'video_type', 0));
              List.Add(Item);
              Inc(PageCount);
            end;
      finally
        R.Free;
      end;
      // the H200 sends no "continued" flag: a full page means another may follow
      if PageCount < RecordingPageSize then
        Break;
      Inc(StartIndex, RecordingPageSize);
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

end.
