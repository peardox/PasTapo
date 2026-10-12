unit Tapo.Devices;

{
  Tapo plugs, lights, light strips and power strips. Authentication and
  sessions are handled by TTapoDevice / TTapoClient in Tapo.Client.

    TTapoDevice (abstract, Tapo.Client)
    |-- TTapoSwitchableDevice (abstract)    on/off, device usage
    |   |-- TTapoPlug (abstract)            plug info, timer, schedules
    |   |   |-- TTapoP100                   P100, P105, P125, P125M
    |   |   `-- TTapoP110                   P110, P110M, P115 (+ energy monitoring)
    |   `-- TTapoLight (abstract)           brightness
    |       |-- TTapoL510                   L510, L510B, L520, L610
    |       `-- TTapoColorLight (abstract)  colour, colour temperature
    |           |-- TTapoL530               L530, L530B, L535, L630
    |           `-- TTapoL900               L900 light strip
    |               `-- TTapoL920           L920, L930 (+ lighting/segment effects)
    `-- TTapoPowerStrip (abstract)          sockets
        |-- TTapoP300                       P300, P306
        `-- TTapoP304M                      P304M, P316M (sockets with energy monitoring)

    TTapoChildDevice (abstract, Tapo.Client)
    `-- TTapoPowerStripOutlet               socket: on/off, info
        `-- TTapoEnergyOutlet               + usage and energy monitoring

  Capabilities follow the feature matrix of https://github.com/mihai-dinculescu/tapo.
}

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.DateUtils,
  System.Generics.Collections, System.Generics.Defaults, Tapo.Crypto, Tapo.Client,
  Tapo.LightEffects;

type
  { --- usage, energy and power ------------------------------------------- }

  (***
    A value for today, the past 7 days and the past 30 days.

    A value the device does not report is -1.
  *)
  /// <summary>A value for today, the past 7 days and the past 30 days.</summary>
  /// <remarks>A value the device does not report is -1.</remarks>
  TTapoUsageByPeriod = record
    (*** Today's value. *)
    /// <summary>Today's value.</summary>
    Today: Int64;
    (*** The value over the past 7 days. *)
    /// <summary>The value over the past 7 days.</summary>
    Past7Days: Int64;
    (*** The value over the past 30 days. *)
    /// <summary>The value over the past 30 days.</summary>
    Past30Days: Int64;
  end;

  (*** How long a device has been on, and the energy it used and saved (get_device_usage). *)
  /// <summary>How long a device has been on, and the energy it used and saved (get_device_usage).</summary>
  TTapoDeviceUsage = record
    (*** Minutes switched on. *)
    /// <summary>Minutes switched on.</summary>
    TimeUsage: TTapoUsageByPeriod;
    (*** Energy used in Wh (energy-monitoring devices and lights). *)
    /// <summary>Energy used in Wh (energy-monitoring devices and lights).</summary>
    PowerUsage: TTapoUsageByPeriod;
    (*** Energy saved in Wh, as the Tapo app reports it. *)
    /// <summary>Energy saved in Wh, as the Tapo app reports it.</summary>
    SavedPower: TTapoUsageByPeriod;
    (*** The whole reply as formatted JSON. *)
    /// <summary>The whole reply as formatted JSON.</summary>
    Raw: string;
  end;

  (*** Energy used today and this month, and the current power (get_energy_usage). *)
  /// <summary>Energy used today and this month, and the current power (get_energy_usage).</summary>
  TTapoEnergyUsage = record
    (*** Minutes switched on today. *)
    /// <summary>Minutes switched on today.</summary>
    TodayRuntimeMin: Int64;
    (*** Minutes switched on this month. *)
    /// <summary>Minutes switched on this month.</summary>
    MonthRuntimeMin: Int64;
    (*** Energy used today in Wh. *)
    /// <summary>Energy used today in Wh.</summary>
    TodayEnergyWh: Int64;
    (*** Energy used this month in Wh. *)
    /// <summary>Energy used this month in Wh.</summary>
    MonthEnergyWh: Int64;
    (*** True if the reply includes the current power. *)
    /// <summary>True if the reply includes the current power.</summary>
    HasCurrentPower: Boolean;
    (***
      The current power in milliwatts.

      @seealso(CurrentPowerW)
    *)
    /// <summary>The current power in milliwatts.</summary>
    /// <seealso cref="CurrentPowerW"/>
    CurrentPowerMW: Int64;
    (*** The device's local time, 'yyyy-mm-dd hh:nn:ss'. *)
    /// <summary>The device's local time, 'yyyy-mm-dd hh:nn:ss'.</summary>
    LocalTime: string;
    (***
      Cost data using the tariff set in the Tapo app. Element 2 is this month's total; the meaning
      of elements 0 and 1 is not documented.
    *)
    /// <summary>
    ///   Cost data using the tariff set in the Tapo app. Element 2 is this
    ///   month's total; the meaning of elements 0 and 1 is not documented.
    /// </summary>
    ElectricityCharge: TArray<Int64>;
    (*** The whole reply as formatted JSON. *)
    /// <summary>The whole reply as formatted JSON.</summary>
    Raw: string;
    (*** The current power in watts. *)
    /// <summary>The current power in watts.</summary>
    function CurrentPowerW: Double;
    (*** Energy used today in kWh. *)
    /// <summary>Energy used today in kWh.</summary>
    function TodayEnergyKWh: Double;
    (*** Energy used this month in kWh. *)
    /// <summary>Energy used this month in kWh.</summary>
    function MonthEnergyKWh: Double;
  end;

  (*** One interval of energy data. *)
  /// <summary>One interval of energy data.</summary>
  TTapoEnergyDataEntry = record
    (*** The start of the interval, local time. *)
    /// <summary>The start of the interval, local time.</summary>
    StartTime: TDateTime;
    (*** Energy used in the interval, in Wh. *)
    /// <summary>Energy used in the interval, in Wh.</summary>
    EnergyWh: Int64;
  end;

  (*** Energy used per hour, day or month (get_energy_data). *)
  /// <summary>Energy used per hour, day or month (get_energy_data).</summary>
  TTapoEnergyData = record
    (*** The device's local time when it answered. *)
    /// <summary>The device's local time when it answered.</summary>
    LocalTime: string;
    (*** The start of the first interval, local time. *)
    /// <summary>The start of the first interval, local time.</summary>
    StartTime: TDateTime;
    (*** The interval length in minutes: 60 (hour), 1440 (day) or 43200 (month). *)
    /// <summary>The interval length in minutes: 60 (hour), 1440 (day) or 43200 (month).</summary>
    IntervalMinutes: Integer;
    (*** One entry per interval, oldest first. *)
    /// <summary>One entry per interval, oldest first.</summary>
    Entries: TArray<TTapoEnergyDataEntry>;
  end;

  (*** One interval of power data. *)
  /// <summary>One interval of power data.</summary>
  TTapoPowerDataEntry = record
    (*** The start of the interval, local time. *)
    /// <summary>The start of the interval, local time.</summary>
    StartTime: TDateTime;
    (*** False when the device has no reading for the interval. *)
    /// <summary>False when the device has no reading for the interval.</summary>
    HasValue: Boolean;
    (*** The power in watts, when @link(HasValue) is True. *)
    /// <summary>The power in watts, when <see cref="HasValue"/> is True.</summary>
    PowerW: Int64;
  end;

  (*** Power every 5 minutes or every hour (get_power_data). *)
  /// <summary>Power every 5 minutes or every hour (get_power_data).</summary>
  TTapoPowerData = record
    (*** The start of the first interval, local time. *)
    /// <summary>The start of the first interval, local time.</summary>
    StartTime: TDateTime;
    (*** The end of the data, local time. *)
    /// <summary>The end of the data, local time.</summary>
    EndTime: TDateTime;
    (*** The interval length in minutes: 5 or 60. *)
    /// <summary>The interval length in minutes: 5 or 60.</summary>
    IntervalMinutes: Integer;
    (*** One entry per interval, oldest first. *)
    /// <summary>One entry per interval, oldest first.</summary>
    Entries: TArray<TTapoPowerDataEntry>;
  end;

  { --- timers and schedules (plugs) ---------------------------------------- }

  (***
    A countdown timer. A plug holds at most one.

    @seealso(TTapoPlug.SetTimer)
  *)
  /// <summary>A countdown timer. A plug holds at most one.</summary>
  /// <seealso cref="TTapoPlug.SetTimer"/>
  TTapoTimer = record
    (*** The id the device assigned. *)
    /// <summary>The id the device assigned.</summary>
    Id: string;
    (*** The countdown length in seconds. *)
    /// <summary>The countdown length in seconds.</summary>
    DelaySeconds: Integer;
    (*** Seconds left until the timer fires. *)
    /// <summary>Seconds left until the timer fires.</summary>
    RemainingSeconds: Integer;
    (*** The state the plug switches to when the timer fires. *)
    /// <summary>The state the plug switches to when the timer fires.</summary>
    DesiredOn: Boolean;
  end;

  (*** A day of the week, for schedule rules. *)
  /// <summary>A day of the week, for schedule rules.</summary>
  TTapoWeekDay = (wdSun, wdMon, wdTue, wdWed, wdThu, wdFri, wdSat);
  (***
    A set of days of the week.

    @seealso(TapoWeekdays)
  *)
  /// <summary>A set of days of the week.</summary>
  /// <seealso cref="TapoWeekdays"/>
  TTapoWeekDays = set of TTapoWeekDay;

  (*** What a schedule rule's time is measured from. *)
  /// <summary>What a schedule rule's time is measured from.</summary>
  TTapoScheduleTimeKind = (
    (*** A clock time (Hour, Minute). *)
    /// <summary>A clock time (Hour, Minute).</summary>
    stkClock,
    (*** An offset from sunrise (OffsetMinutes). *)
    /// <summary>An offset from sunrise (OffsetMinutes).</summary>
    stkSunrise,
    (*** An offset from sunset (OffsetMinutes). *)
    /// <summary>An offset from sunset (OffsetMinutes).</summary>
    stkSunset);

  (***
    A rule that switches a plug on or off at a set time.

    Build rules with the class functions, which validate them. Sunrise and sunset times use the
    location set in the Tapo app.

    Example:
    @longCode(#
    Rule := Plug.AddScheduleRule(TTapoScheduleRule.ClockWeekly(7, 30, TapoWeekdays, True));
    Plug.AddScheduleRule(TTapoScheduleRule.SunsetOnce(-15, False));
    #)
  *)
  /// <summary>A rule that switches a plug on or off at a set time.</summary>
  /// <remarks>
  ///   Build rules with the class functions, which validate them. Sunrise and
  ///   sunset times use the location set in the Tapo app.
  /// </remarks>
  /// <example>
  ///   <code>
  ///   Rule := Plug.AddScheduleRule(TTapoScheduleRule.ClockWeekly(7, 30, TapoWeekdays, True));
  ///   Plug.AddScheduleRule(TTapoScheduleRule.SunsetOnce(-15, False));
  ///   </code>
  /// </example>
  TTapoScheduleRule = record
    (*** The id the device assigned; empty for a rule not yet added. *)
    /// <summary>The id the device assigned; empty for a rule not yet added.</summary>
    Id: string;
    (*** False if the rule is switched off in the app. *)
    /// <summary>False if the rule is switched off in the app.</summary>
    Enabled: Boolean;
    (*** What the time is measured from. *)
    /// <summary>What the time is measured from.</summary>
    TimeKind: TTapoScheduleTimeKind;
    (*** The hour, 0 to 23, for stkClock. *)
    /// <summary>The hour, 0 to 23, for stkClock.</summary>
    Hour: Integer;
    (*** The minute, 0 to 59, for stkClock. *)
    /// <summary>The minute, 0 to 59, for stkClock.</summary>
    Minute: Integer;
    (*** Minutes from sunrise or sunset, -360 to 360 (negative = before). *)
    /// <summary>Minutes from sunrise or sunset, -360 to 360 (negative = before).</summary>
    OffsetMinutes: Integer;
    (*** True for a weekly rule; False for a rule that fires once. *)
    /// <summary>True for a weekly rule; False for a rule that fires once.</summary>
    Repeating: Boolean;
    (*** The days a weekly rule fires on. *)
    /// <summary>The days a weekly rule fires on.</summary>
    Days: TTapoWeekDays;
    (*** The state the plug switches to. *)
    /// <summary>The state the plug switches to.</summary>
    DesiredOn: Boolean;
    (***
      A rule that fires at a clock time on the given days.

      @param(AHour 0 to 23.)

      @param(AMinute 0 to 59.)

      @param(ADays At least one day.)

      @param(ADesiredOn True to switch on, False to switch off.)

      @raises(ETapoError A value is out of range.)
    *)
    /// <summary>A rule that fires at a clock time on the given days.</summary>
    /// <param name="AHour">0 to 23.</param>
    /// <param name="AMinute">0 to 59.</param>
    /// <param name="ADays">At least one day.</param>
    /// <param name="ADesiredOn">True to switch on, False to switch off.</param>
    /// <exception cref="ETapoError">A value is out of range.</exception>
    class function ClockWeekly(AHour, AMinute: Integer; ADays: TTapoWeekDays;
      ADesiredOn: Boolean): TTapoScheduleRule; static;
    (***
      A rule that fires once, at the next occurrence of a clock time.

      @param(AHour 0 to 23.)

      @param(AMinute 0 to 59.)

      @param(ADesiredOn True to switch on, False to switch off.)

      @raises(ETapoError A value is out of range.)
    *)
    /// <summary>A rule that fires once, at the next occurrence of a clock time.</summary>
    /// <param name="AHour">0 to 23.</param>
    /// <param name="AMinute">0 to 59.</param>
    /// <param name="ADesiredOn">True to switch on, False to switch off.</param>
    /// <exception cref="ETapoError">A value is out of range.</exception>
    class function ClockOnce(AHour, AMinute: Integer; ADesiredOn: Boolean): TTapoScheduleRule; static;
    (***
      A rule that fires at an offset from sunrise on the given days.

      @param(AOffsetMinutes -360 to 360; negative is before sunrise.)

      @param(ADays At least one day.)

      @param(ADesiredOn True to switch on, False to switch off.)

      @raises(ETapoError A value is out of range.)
    *)
    /// <summary>A rule that fires at an offset from sunrise on the given days.</summary>
    /// <param name="AOffsetMinutes">-360 to 360; negative is before sunrise.</param>
    /// <param name="ADays">At least one day.</param>
    /// <param name="ADesiredOn">True to switch on, False to switch off.</param>
    /// <exception cref="ETapoError">A value is out of range.</exception>
    class function SunriseWeekly(AOffsetMinutes: Integer; ADays: TTapoWeekDays;
      ADesiredOn: Boolean): TTapoScheduleRule; static;
    (***
      A rule that fires once, at an offset from the next sunrise.

      @param(AOffsetMinutes -360 to 360; negative is before sunrise.)

      @param(ADesiredOn True to switch on, False to switch off.)

      @raises(ETapoError A value is out of range.)
    *)
    /// <summary>A rule that fires once, at an offset from the next sunrise.</summary>
    /// <param name="AOffsetMinutes">-360 to 360; negative is before sunrise.</param>
    /// <param name="ADesiredOn">True to switch on, False to switch off.</param>
    /// <exception cref="ETapoError">A value is out of range.</exception>
    class function SunriseOnce(AOffsetMinutes: Integer; ADesiredOn: Boolean): TTapoScheduleRule; static;
    (***
      A rule that fires at an offset from sunset on the given days.

      @param(AOffsetMinutes -360 to 360; negative is before sunset.)

      @param(ADays At least one day.)

      @param(ADesiredOn True to switch on, False to switch off.)

      @raises(ETapoError A value is out of range.)
    *)
    /// <summary>A rule that fires at an offset from sunset on the given days.</summary>
    /// <param name="AOffsetMinutes">-360 to 360; negative is before sunset.</param>
    /// <param name="ADays">At least one day.</param>
    /// <param name="ADesiredOn">True to switch on, False to switch off.</param>
    /// <exception cref="ETapoError">A value is out of range.</exception>
    class function SunsetWeekly(AOffsetMinutes: Integer; ADays: TTapoWeekDays;
      ADesiredOn: Boolean): TTapoScheduleRule; static;
    (***
      A rule that fires once, at an offset from the next sunset.

      @param(AOffsetMinutes -360 to 360; negative is before sunset.)

      @param(ADesiredOn True to switch on, False to switch off.)

      @raises(ETapoError A value is out of range.)
    *)
    /// <summary>A rule that fires once, at an offset from the next sunset.</summary>
    /// <param name="AOffsetMinutes">-360 to 360; negative is before sunset.</param>
    /// <param name="ADesiredOn">True to switch on, False to switch off.</param>
    /// <exception cref="ETapoError">A value is out of range.</exception>
    class function SunsetOnce(AOffsetMinutes: Integer; ADesiredOn: Boolean): TTapoScheduleRule; static;
    (*** Returns a copy of the rule, switched on or off. *)
    /// <summary>Returns a copy of the rule, switched on or off.</summary>
    function WithEnabled(AEnabled: Boolean): TTapoScheduleRule;
    (***
      Checks the rule's values.

      @raises(ETapoError A value is out of range, or a weekly rule has no days.)
    *)
    /// <summary>Checks the rule's values.</summary>
    /// <exception cref="ETapoError">A value is out of range, or a weekly rule has no days.</exception>
    procedure Validate;
  end;

  { --- lights ------------------------------------------------------------- }

  (***
    The colour presets of the Tapo app.

    The whites set a colour temperature; the colours set a hue and saturation.
    @link(TapoColorValues) gives the values.
  *)
  /// <summary>The colour presets of the Tapo app.</summary>
  /// <remarks>
  ///   The whites set a colour temperature; the colours set a hue and
  ///   saturation. <see cref="TapoColorValues"/> gives the values.
  /// </remarks>
  TTapoColor = (tcCoolWhite, tcDaylight, tcIvory, tcWarmWhite, tcIncandescent,
    tcCandlelight, tcSnow, tcGhostWhite, tcAliceBlue, tcLightGoldenrod,
    tcLemonChiffon, tcAntiqueWhite, tcGold, tcPeru, tcChocolate, tcSandyBrown,
    tcCoral, tcPumpkin, tcTomato, tcVermilion, tcOrangeRed, tcPink, tcCrimson,
    tcDarkRed, tcHotPink, tcSmitten, tcMediumPurple, tcBlueViolet, tcIndigo,
    tcLightSkyBlue, tcCornflowerBlue, tcUltramarine, tcDeepSkyBlue, tcAzure,
    tcNavyBlue, tcLightTurquoise, tcAquamarine, tcTurquoise, tcLightGreen,
    tcLime, tcForestGreen);

  (***
    Several light settings to send in one request.

    Start from @link(New) and chain the With... functions; each returns a modified copy. Pass the
    result to @link(TTapoColorLight.Apply).

    Example:
    @longCode(#
    Bulb.Apply(TTapoLightState.New.TurnOn.WithBrightness(40).WithColor(tcCoral));
    #)
  *)
  /// <summary>Several light settings to send in one request.</summary>
  /// <remarks>
  ///   Start from <see cref="New"/> and chain the With... functions; each
  ///   returns a modified copy. Pass the result to <see cref="TTapoColorLight.Apply"/>.
  /// </remarks>
  /// <example>
  ///   <code>Bulb.Apply(TTapoLightState.New.TurnOn.WithBrightness(40).WithColor(tcCoral));</code>
  /// </example>
  TTapoLightState = record
    (*** True if the power state is to be set. *)
    /// <summary>True if the power state is to be set.</summary>
    HasOn: Boolean;
    (*** The power state to set. *)
    /// <summary>The power state to set.</summary>
    DeviceOn: Boolean;
    (*** True if the brightness is to be set. *)
    /// <summary>True if the brightness is to be set.</summary>
    HasBrightness: Boolean;
    (*** The brightness, 1 to 100. *)
    /// <summary>The brightness, 1 to 100.</summary>
    Brightness: Integer;
    (*** True if a hue and saturation are to be set. *)
    /// <summary>True if a hue and saturation are to be set.</summary>
    HasHueSaturation: Boolean;
    (*** The hue, 0 to 360. *)
    /// <summary>The hue, 0 to 360.</summary>
    Hue: Integer;
    (*** The saturation, 1 to 100. *)
    /// <summary>The saturation, 1 to 100.</summary>
    Saturation: Integer;
    (*** True if a colour temperature is to be set. *)
    /// <summary>True if a colour temperature is to be set.</summary>
    HasColorTemp: Boolean;
    (***
      The colour temperature in kelvin, 2500 to 6500; 0 together with a hue and saturation.
    *)
    /// <summary>The colour temperature in kelvin, 2500 to 6500; 0 together with a hue and saturation.</summary>
    ColorTemp: Integer;
    (*** An empty state, to chain the With... functions from. *)
    /// <summary>An empty state, to chain the With... functions from.</summary>
    class function New: TTapoLightState; static;
    (*** Also switches the light on. *)
    /// <summary>Also switches the light on.</summary>
    function TurnOn: TTapoLightState;
    (*** Also switches the light off. *)
    /// <summary>Also switches the light off.</summary>
    function TurnOff: TTapoLightState;
    (***
      Also sets the brightness.

      @param(AValue 1 to 100.)
    *)
    /// <summary>Also sets the brightness.</summary>
    /// <param name="AValue">1 to 100.</param>
    function WithBrightness(AValue: Integer): TTapoLightState;
    (*** Also sets a colour preset. *)
    /// <summary>Also sets a colour preset.</summary>
    function WithColor(AColor: TTapoColor): TTapoLightState;
    (***
      Also sets a colour by hue and saturation.

      @param(AHue 0 to 360.)

      @param(ASaturation 1 to 100.)
    *)
    /// <summary>Also sets a colour by hue and saturation.</summary>
    /// <param name="AHue">0 to 360.</param>
    /// <param name="ASaturation">1 to 100.</param>
    function WithHueSaturation(AHue, ASaturation: Integer): TTapoLightState;
    (***
      Also sets a white by colour temperature (and clears any hue and saturation).

      @param(AKelvin 2500 to 6500.)
    *)
    /// <summary>Also sets a white by colour temperature (and clears any hue and saturation).</summary>
    /// <param name="AKelvin">2500 to 6500.</param>
    function WithColorTemperature(AKelvin: Integer): TTapoLightState;
    (***
      Checks the values.

      @raises(ETapoError Nothing is set, or a value is out of range.)
    *)
    /// <summary>Checks the values.</summary>
    /// <exception cref="ETapoError">Nothing is set, or a value is out of range.</exception>
    procedure Validate;
    (***
      Validates the state and returns the set_device_info fields.

      @returns(A new object; the caller frees it or passes it on.)
    *)
    /// <summary>Validates the state and returns the set_device_info fields.</summary>
    /// <returns>A new object; the caller frees it or passes it on.</returns>
    function ToJSON: TJSONObject;
  end;

  (***
    A colour as hue, saturation and brightness, for light effects.

    @seealso(HSB)
  *)
  /// <summary>A colour as hue, saturation and brightness, for light effects.</summary>
  /// <seealso cref="HSB"/>
  TTapoHSB = record
    (*** Hue 0 to 360, saturation 0 to 100, brightness 0 to 100. *)
    /// <summary>Hue 0 to 360, saturation 0 to 100, brightness 0 to 100.</summary>
    Hue, Saturation, Brightness: Integer;
  end;

  (***
    A segment colour as hue, saturation, brightness and colour temperature.

    @seealso(HSBK)
  *)
  /// <summary>A segment colour as hue, saturation, brightness and colour temperature.</summary>
  /// <seealso cref="HSBK"/>
  TTapoHSBK = record
    (***
      Hue 0 to 360, saturation 0 to 100, brightness 0 to 100, colour temperature in kelvin (0 for
      a colour).
    *)
    /// <summary>Hue 0 to 360, saturation 0 to 100, brightness 0 to 100, colour temperature in kelvin (0 for a colour).</summary>
    Hue, Saturation, Brightness, Kelvin: Integer;
  end;

  (*** How a lighting effect moves through its colours. *)
  /// <summary>How a lighting effect moves through its colours.</summary>
  TTapoLightingEffectType = (letSequence, letRandom, letPulse, letStatic);

  (***
    A lighting effect for the L920 and L930 light strips.

    Start from a preset (@link(Preset)), from scratch (@link(New)) or from JSON, then adjust with
    the With... functions; each returns a modified copy. The field names and meanings are those of
    the Tapo app.

    @seealso(TTapoL920.SetLightingEffect)

    Example:
    @longCode(#
    Strip.SetLightingEffect(TTapoLightingEffect.Preset(lepAurora).WithBrightness(60));
    #)
  *)
  /// <summary>A lighting effect for the L920 and L930 light strips.</summary>
  /// <remarks>
  ///   Start from a preset (<see cref="Preset"/>), from scratch (<see cref="New"/>)
  ///   or from JSON, then adjust with the With... functions; each returns a
  ///   modified copy. The field names and meanings are those of the Tapo app.
  /// </remarks>
  /// <example>
  ///   <code>Strip.SetLightingEffect(TTapoLightingEffect.Preset(lepAurora).WithBrightness(60));</code>
  /// </example>
  /// <seealso cref="TTapoL920.SetLightingEffect"/>
  TTapoLightingEffect = record
  private
    FJson: string;
    function Patch(const AKey: string; AValue: TJSONValue): TTapoLightingEffect;
  public
    (***
      A new effect.

      The effect gets a new random id.

      @param(AName The name shown in the Tapo app.)

      @param(AType How the effect moves through its colours.)

      @param(AIsCustom True for an effect of your own.)

      @param(AEnabled True to run the effect.)

      @param(ABrightness 0 to 100.)

      @param(ADisplayColors The colours shown for the effect in the app.)
    *)
    /// <summary>A new effect.</summary>
    /// <param name="AName">The name shown in the Tapo app.</param>
    /// <param name="AType">How the effect moves through its colours.</param>
    /// <param name="AIsCustom">True for an effect of your own.</param>
    /// <param name="AEnabled">True to run the effect.</param>
    /// <param name="ABrightness">0 to 100.</param>
    /// <param name="ADisplayColors">The colours shown for the effect in the app.</param>
    /// <remarks>The effect gets a new random id.</remarks>
    class function New(const AName: string; AType: TTapoLightingEffectType;
      AIsCustom, AEnabled: Boolean; ABrightness: Integer;
      const ADisplayColors: array of TTapoHSB): TTapoLightingEffect; static;
    (*** One of the Tapo app's lighting-effect presets. *)
    /// <summary>One of the Tapo app's lighting-effect presets.</summary>
    class function Preset(APreset: TTapoLightingEffectPreset): TTapoLightingEffect; static;
    (*** An effect from its JSON, for example from a device's default state. *)
    /// <summary>An effect from its JSON, for example from a device's default state.</summary>
    class function FromJSON(const AJson: string): TTapoLightingEffect; static;
    (*** Sets the brightness, 0 to 100. *)
    /// <summary>Sets the brightness, 0 to 100.</summary>
    function WithBrightness(AValue: Integer): TTapoLightingEffect;
    (*** Marks the effect as custom or preset. *)
    /// <summary>Marks the effect as custom or preset.</summary>
    function WithIsCustom(AValue: Boolean): TTapoLightingEffect;
    (*** Runs or stops the effect. *)
    /// <summary>Runs or stops the effect.</summary>
    function WithEnabled(AValue: Boolean): TTapoLightingEffect;
    (*** Sets the id. *)
    /// <summary>Sets the id.</summary>
    function WithId(const AValue: string): TTapoLightingEffect;
    (*** Sets the name shown in the app. *)
    /// <summary>Sets the name shown in the app.</summary>
    function WithName(const AValue: string): TTapoLightingEffect;
    (*** Sets how the effect moves through its colours. *)
    /// <summary>Sets how the effect moves through its colours.</summary>
    function WithType(AValue: TTapoLightingEffectType): TTapoLightingEffect;
    (*** Sets the colours shown for the effect in the app. *)
    /// <summary>Sets the colours shown for the effect in the app.</summary>
    function WithDisplayColors(const AValue: array of TTapoHSB): TTapoLightingEffect;
    (*** Sets the background colours (random effects). *)
    /// <summary>Sets the background colours (random effects).</summary>
    function WithBackgrounds(const AValue: array of TTapoHSB): TTapoLightingEffect;
    (*** Sets the brightness range (random effects). *)
    /// <summary>Sets the brightness range (random effects).</summary>
    function WithBrightnessRange(AMin, AMax: Integer): TTapoLightingEffect;
    (*** Sets the direction of movement (sequence effects). *)
    /// <summary>Sets the direction of movement (sequence effects).</summary>
    function WithDirection(AValue: Integer): TTapoLightingEffect;
    (*** Sets the duration in milliseconds. *)
    /// <summary>Sets the duration in milliseconds.</summary>
    function WithDuration(AValue: Int64): TTapoLightingEffect;
    (*** Sets the expansion strategy. *)
    /// <summary>Sets the expansion strategy.</summary>
    function WithExpansionStrategy(AValue: Integer): TTapoLightingEffect;
    (*** Sets the fade-off time in milliseconds. *)
    /// <summary>Sets the fade-off time in milliseconds.</summary>
    function WithFadeOff(AValue: Integer): TTapoLightingEffect;
    (*** Sets the hue range (random effects). *)
    /// <summary>Sets the hue range (random effects).</summary>
    function WithHueRange(AMin, AMax: Integer): TTapoLightingEffect;
    (*** Sets the initial states (random effects). *)
    /// <summary>Sets the initial states (random effects).</summary>
    function WithInitStates(const AValue: array of TTapoHSB): TTapoLightingEffect;
    (*** Sets the random seed (random effects). *)
    /// <summary>Sets the random seed (random effects).</summary>
    function WithRandomSeed(AValue: Int64): TTapoLightingEffect;
    (*** Sets how many times the effect repeats; 0 repeats for ever. *)
    /// <summary>Sets how many times the effect repeats; 0 repeats for ever.</summary>
    function WithRepeatTimes(AValue: Integer): TTapoLightingEffect;
    (*** Sets the run time. *)
    /// <summary>Sets the run time.</summary>
    function WithRunTime(AValue: Int64): TTapoLightingEffect;
    (*** Sets the saturation range (random effects). *)
    /// <summary>Sets the saturation range (random effects).</summary>
    function WithSaturationRange(AMin, AMax: Integer): TTapoLightingEffect;
    (*** Sets the segment length. *)
    /// <summary>Sets the segment length.</summary>
    function WithSegmentLength(AValue: Integer): TTapoLightingEffect;
    (*** Sets the segments the effect runs on. *)
    /// <summary>Sets the segments the effect runs on.</summary>
    function WithSegments(const AValue: array of Integer): TTapoLightingEffect;
    (*** Sets the colour sequence (sequence effects). *)
    /// <summary>Sets the colour sequence (sequence effects).</summary>
    function WithSequence(const AValue: array of TTapoHSB): TTapoLightingEffect;
    (*** Sets the spread. *)
    /// <summary>Sets the spread.</summary>
    function WithSpread(AValue: Integer): TTapoLightingEffect;
    (*** Sets the transition time in milliseconds. *)
    /// <summary>Sets the transition time in milliseconds.</summary>
    function WithTransition(AValue: Integer): TTapoLightingEffect;
    (*** Sets the transition time range (random effects). *)
    /// <summary>Sets the transition time range (random effects).</summary>
    function WithTransitionRange(AMin, AMax: Integer): TTapoLightingEffect;
    (*** Sets the transition time for each step of the sequence. *)
    /// <summary>Sets the transition time for each step of the sequence.</summary>
    function WithTransitionSequence(const AValue: array of Integer): TTapoLightingEffect;
    (***
      The effect as the JSON the strip takes.

      @raises(ETapoError The effect is empty.)
    *)
    /// <summary>The effect as the JSON the strip takes.</summary>
    /// <exception cref="ETapoError">The effect is empty.</exception>
    function ToJSON: string;
  end;

  (*** How a segment effect animates. *)
  /// <summary>How a segment effect animates.</summary>
  TTapoSegmentEffectType = (setCirculating, setBreathe, setChasing, setFlicker,
    setBloom, setStacking, setNone);

  (***
    A segment effect for the L920 and L930 light strips.

    Start from a preset (@link(Preset)), from scratch (@link(New)) or from JSON, then adjust with
    the With... functions. A custom effect needs segments, states and a type.

    @seealso(TTapoL920.SetSegmentEffect)

    Example:
    @longCode(#
    Strip.SetSegmentEffect(sepSunny);
    #)
  *)
  /// <summary>A segment effect for the L920 and L930 light strips.</summary>
  /// <remarks>
  ///   Start from a preset (<see cref="Preset"/>), from scratch (<see cref="New"/>)
  ///   or from JSON, then adjust with the With... functions. A custom effect
  ///   needs segments, states and a type.
  /// </remarks>
  /// <example>
  ///   <code>Strip.SetSegmentEffect(sepSunny);</code>
  /// </example>
  /// <seealso cref="TTapoL920.SetSegmentEffect"/>
  TTapoSegmentEffect = record
  private
    FJson: string;
    function Patch(const AKey: string; AValue: TJSONValue): TTapoSegmentEffect;
  public
    (***
      A new segment effect.

      @param(AName The name shown in the Tapo app.)

      @param(AType How the effect animates.)

      @param(AIsCustom True for an effect of your own @(device type 'strip' is set@).)

      @param(AEnabled True to run the effect.)

      @param(ABrightness 0 to 100.)

      @param(ADisplayColors The colours shown for the effect in the app.)
    *)
    /// <summary>A new segment effect.</summary>
    /// <param name="AName">The name shown in the Tapo app.</param>
    /// <param name="AType">How the effect animates.</param>
    /// <param name="AIsCustom">True for an effect of your own (device type 'strip' is set).</param>
    /// <param name="AEnabled">True to run the effect.</param>
    /// <param name="ABrightness">0 to 100.</param>
    /// <param name="ADisplayColors">The colours shown for the effect in the app.</param>
    class function New(const AName: string; AType: TTapoSegmentEffectType;
      AIsCustom, AEnabled: Boolean; ABrightness: Integer;
      const ADisplayColors: array of TTapoHSBK): TTapoSegmentEffect; static;
    (*** One of the Tapo app's segment-effect presets. *)
    /// <summary>One of the Tapo app's segment-effect presets.</summary>
    class function Preset(APreset: TTapoSegmentEffectPreset): TTapoSegmentEffect; static;
    (*** An effect from its JSON. *)
    /// <summary>An effect from its JSON.</summary>
    class function FromJSON(const AJson: string): TTapoSegmentEffect; static;
    (*** Sets the brightness, 0 to 100. *)
    /// <summary>Sets the brightness, 0 to 100.</summary>
    function WithBrightness(AValue: Integer): TTapoSegmentEffect;
    (*** Marks the effect as custom or preset. *)
    /// <summary>Marks the effect as custom or preset.</summary>
    function WithIsCustom(AValue: Boolean): TTapoSegmentEffect;
    (*** Runs or stops the effect. *)
    /// <summary>Runs or stops the effect.</summary>
    function WithEnabled(AValue: Boolean): TTapoSegmentEffect;
    (*** Sets the id. *)
    /// <summary>Sets the id.</summary>
    function WithId(const AValue: string): TTapoSegmentEffect;
    (*** Sets the name shown in the app. *)
    /// <summary>Sets the name shown in the app.</summary>
    function WithName(const AValue: string): TTapoSegmentEffect;
    (*** Sets how the effect animates. *)
    /// <summary>Sets how the effect animates.</summary>
    function WithType(AValue: TTapoSegmentEffectType): TTapoSegmentEffect;
    (*** Sets the device type, 'strip' for custom effects. *)
    /// <summary>Sets the device type, 'strip' for custom effects.</summary>
    function WithDeviceType(const AValue: string): TTapoSegmentEffect;
    (*** Sets the colours shown for the effect in the app. *)
    /// <summary>Sets the colours shown for the effect in the app.</summary>
    function WithDisplayColors(const AValue: array of TTapoHSBK): TTapoSegmentEffect;
    (*** Sets the segments the states apply to. *)
    /// <summary>Sets the segments the states apply to.</summary>
    function WithSegments(const AValue: array of Integer): TTapoSegmentEffect;
    (*** Sets the colour of each segment. *)
    /// <summary>Sets the colour of each segment.</summary>
    function WithStates(const AValue: array of TTapoHSBK): TTapoSegmentEffect;
    (***
      Checks that a custom effect has segments, states and a type.

      @raises(ETapoError Something required is missing.)
    *)
    /// <summary>Checks that a custom effect has segments, states and a type.</summary>
    /// <exception cref="ETapoError">Something required is missing.</exception>
    procedure Validate;
    (*** Validates the effect and returns the JSON the strip takes. *)
    /// <summary>Validates the effect and returns the JSON the strip takes.</summary>
    function ToJSON: string;
  end;

  { --- device info records ------------------------------------------------- }

  (*** Device info of a plug. *)
  /// <summary>Device info of a plug.</summary>
  TTapoPlugInfo = record
    (*** The fields every device reports. *)
    /// <summary>The fields every device reports.</summary>
    Info: TTapoDeviceInfo;
    (*** True if the plug is on. *)
    /// <summary>True if the plug is on.</summary>
    DeviceOn: Boolean;
    (*** Seconds since the plug was switched on. *)
    /// <summary>Seconds since the plug was switched on.</summary>
    OnTime: Int64;
    (*** 'normal' or 'lifted' (energy-monitoring plugs). *)
    /// <summary>'normal' or 'lifted' (energy-monitoring plugs).</summary>
    OvercurrentStatus: string;
    (*** 'normal', 'cool_down' or 'overheated'; empty if not reported. *)
    /// <summary>'normal', 'cool_down' or 'overheated'; empty if not reported.</summary>
    OverheatStatus: string;
    (*** 'normal' or 'overloaded' (energy-monitoring plugs). *)
    /// <summary>'normal' or 'overloaded' (energy-monitoring plugs).</summary>
    PowerProtectionStatus: string;
    (*** 'normal' or 'finished' (energy-monitoring plugs). *)
    /// <summary>'normal' or 'finished' (energy-monitoring plugs).</summary>
    ChargingStatus: string;
    (*** The state after a power cut: 'custom' (see @link(DefaultOn)) or 'last_states'. *)
    /// <summary>The state after a power cut: 'custom' (see <see cref="DefaultOn"/>) or 'last_states'.</summary>
    DefaultStateType: string;
    (*** The state after a power cut when DefaultStateType is 'custom'. *)
    /// <summary>The state after a power cut when DefaultStateType is 'custom'.</summary>
    DefaultOn: Boolean;
  end;

  (*** Device info of a light. *)
  /// <summary>Device info of a light.</summary>
  TTapoLightInfo = record
    (*** The fields every device reports. *)
    /// <summary>The fields every device reports.</summary>
    Info: TTapoDeviceInfo;
    (*** True if the light is on. *)
    /// <summary>True if the light is on.</summary>
    DeviceOn: Boolean;
    (*** Seconds since the light was switched on. *)
    /// <summary>Seconds since the light was switched on.</summary>
    OnTime: Int64;
    (*** The brightness, 1 to 100. *)
    /// <summary>The brightness, 1 to 100.</summary>
    Brightness: Integer;
    (*** True if the light has overheated. *)
    /// <summary>True if the light has overheated.</summary>
    Overheated: Boolean;
    (*** The brightness after a power cut: 'custom' or 'last_states' (L510 family). *)
    /// <summary>The brightness after a power cut: 'custom' or 'last_states' (L510 family).</summary>
    DefaultBrightnessType: string;
    (***
      The brightness after a power cut when DefaultBrightnessType is 'custom' (L510 family).
    *)
    /// <summary>The brightness after a power cut when DefaultBrightnessType is 'custom' (L510 family).</summary>
    DefaultBrightness: Integer;
    (*** 'always_on' or 'last_states' (L510 family). *)
    /// <summary>'always_on' or 'last_states' (L510 family).</summary>
    RePowerType: string;
  end;

  (*** Device info of a colour light or light strip. *)
  /// <summary>Device info of a colour light or light strip.</summary>
  TTapoColorLightInfo = record
    (*** The fields common to lights. *)
    /// <summary>The fields common to lights.</summary>
    Light: TTapoLightInfo;
    (*** True if the light reports a hue and saturation. *)
    /// <summary>True if the light reports a hue and saturation.</summary>
    HasHueSaturation: Boolean;
    (*** The hue, 0 to 360. *)
    /// <summary>The hue, 0 to 360.</summary>
    Hue: Integer;
    (*** The saturation, 0 to 100. *)
    /// <summary>The saturation, 0 to 100.</summary>
    Saturation: Integer;
    (*** The colour temperature in kelvin; 0 while a colour (hue and saturation) is shown. *)
    /// <summary>The colour temperature in kelvin; 0 while a colour (hue and saturation) is shown.</summary>
    ColorTemp: Integer;
    (*** The lowest colour temperature the light supports. *)
    /// <summary>The lowest colour temperature the light supports.</summary>
    ColorTempMin: Integer;
    (*** The highest colour temperature the light supports. *)
    /// <summary>The highest colour temperature the light supports.</summary>
    ColorTempMax: Integer;
    (*** True while a dynamic effect runs. *)
    /// <summary>True while a dynamic effect runs.</summary>
    DynamicLightEffectEnable: Boolean;
    (*** The id of the running dynamic effect. *)
    /// <summary>The id of the running dynamic effect.</summary>
    DynamicLightEffectId: string;
    (*** The state after a power cut: 'custom' or 'last_states'. *)
    /// <summary>The state after a power cut: 'custom' or 'last_states'.</summary>
    DefaultStateType: string;
    (*** The brightness after a power cut. *)
    /// <summary>The brightness after a power cut.</summary>
    DefaultBrightness: Integer;
    (*** The hue after a power cut. *)
    /// <summary>The hue after a power cut.</summary>
    DefaultHue: Integer;
    (*** The saturation after a power cut. *)
    /// <summary>The saturation after a power cut.</summary>
    DefaultSaturation: Integer;
    (*** The colour temperature after a power cut. *)
    /// <summary>The colour temperature after a power cut.</summary>
    DefaultColorTemp: Integer;
    (***
      The lighting effect after a power cut, as JSON (L920, L930); empty if none.

      @seealso(TTapoLightingEffect.FromJSON)
    *)
    /// <summary>The lighting effect after a power cut, as JSON (L920, L930); empty if none.</summary>
    /// <seealso cref="TTapoLightingEffect.FromJSON"/>
    DefaultLightingEffectJSON: string;
  end;

  (*** Device info of a power-strip socket. *)
  /// <summary>Device info of a power-strip socket.</summary>
  TTapoOutletInfo = record
    (*** The socket's device id. *)
    /// <summary>The socket's device id.</summary>
    DeviceId: string;
    (*** The device id the socket had originally. *)
    /// <summary>The device id the socket had originally.</summary>
    OriginalDeviceId: string;
    (*** The name given in the Tapo app. *)
    /// <summary>The name given in the Tapo app.</summary>
    Nickname: string;
    (*** The strip's model. *)
    /// <summary>The strip's model.</summary>
    Model: string;
    (*** The device type. *)
    /// <summary>The device type.</summary>
    DeviceType: string;
    (*** The device category. *)
    /// <summary>The device category.</summary>
    Category: string;
    (*** The firmware version. *)
    /// <summary>The firmware version.</summary>
    FirmwareVersion: string;
    (*** The hardware version. *)
    /// <summary>The hardware version.</summary>
    HardwareVersion: string;
    (*** The MAC address. *)
    /// <summary>The MAC address.</summary>
    Mac: string;
    (*** The socket's position on the strip, 1 for the first. *)
    /// <summary>The socket's position on the strip, 1 for the first.</summary>
    Position: Integer;
    (*** The number of sockets on the strip. *)
    /// <summary>The number of sockets on the strip.</summary>
    SlotNumber: Integer;
    (*** True for the USB ports. *)
    /// <summary>True for the USB ports.</summary>
    IsUsb: Boolean;
    (*** True if the socket is on. *)
    /// <summary>True if the socket is on.</summary>
    DeviceOn: Boolean;
    (*** Seconds since the socket was switched on. *)
    /// <summary>Seconds since the socket was switched on.</summary>
    OnTime: Int64;
    (*** 'on' or 'off': whether the auto-off timer is set. *)
    /// <summary>'on' or 'off': whether the auto-off timer is set.</summary>
    AutoOffStatus: string;
    (*** Seconds left on the auto-off timer. *)
    /// <summary>Seconds left on the auto-off timer.</summary>
    AutoOffRemainTime: Int64;
    (*** The bind count. *)
    /// <summary>The bind count.</summary>
    BindCount: Integer;
    (*** The status-follow-edge setting. *)
    /// <summary>The status-follow-edge setting.</summary>
    StatusFollowEdge: Boolean;
    (*** 'normal' or 'lifted' (energy-monitoring strips). *)
    /// <summary>'normal' or 'lifted' (energy-monitoring strips).</summary>
    OvercurrentStatus: string;
    (*** 'normal', 'cool_down' or 'overheated'; empty if not reported. *)
    /// <summary>'normal', 'cool_down' or 'overheated'; empty if not reported.</summary>
    OverheatStatus: string;
    (*** 'normal' or 'overloaded' (energy-monitoring strips). *)
    /// <summary>'normal' or 'overloaded' (energy-monitoring strips).</summary>
    PowerProtectionStatus: string;
    (*** 'normal' or 'finished' (energy-monitoring strips). *)
    /// <summary>'normal' or 'finished' (energy-monitoring strips).</summary>
    ChargingStatus: string;
    (*** The state after a power cut: 'custom' or 'last_states'. *)
    /// <summary>The state after a power cut: 'custom' or 'last_states'.</summary>
    DefaultStateType: string;
    (*** The state after a power cut when DefaultStateType is 'custom'. *)
    /// <summary>The state after a power cut when DefaultStateType is 'custom'.</summary>
    DefaultOn: Boolean;
    (*** The whole reply as formatted JSON. *)
    /// <summary>The whole reply as formatted JSON.</summary>
    Raw: string;
  end;

  { --- devices ------------------------------------------------------------- }

  (*** A device with a power state and usage statistics: the plugs and lights. *)
  /// <summary>A device with a power state and usage statistics: the plugs and lights.</summary>
  TTapoSwitchableDevice = class abstract(TTapoDevice)
  public
    (*** Switches the device on. *)
    /// <summary>Switches the device on.</summary>
    procedure TurnOn;
    (*** Switches the device off. *)
    /// <summary>Switches the device off.</summary>
    procedure TurnOff;
    (***
      Switches the device on or off.

      @param(AOn True for on.)
    *)
    /// <summary>Switches the device on or off.</summary>
    /// <param name="AOn">True for on.</param>
    procedure SetOn(AOn: Boolean);
    (***
      Reads the power state from the device.

      @returns(True if the device is on.)
    *)
    /// <summary>Reads the power state from the device.</summary>
    /// <returns>True if the device is on.</returns>
    function IsOn: Boolean;
    (*** Reads how long the device has been on, and the energy it used. *)
    /// <summary>Reads how long the device has been on, and the energy it used.</summary>
    function GetDeviceUsage: TTapoDeviceUsage;
  end;

  (*** The features common to all plugs: plug info, countdown timer and schedule rules. *)
  /// <summary>The features common to all plugs: plug info, countdown timer and schedule rules.</summary>
  TTapoPlug = class abstract(TTapoSwitchableDevice)
  public
    (*** Reads the plug's device info. *)
    /// <summary>Reads the plug's device info.</summary>
    function GetPlugInfo: TTapoPlugInfo;

    (***
      Sets the countdown timer, replacing any existing one.

      @param(ADelaySeconds 1 to 86400 @(24 hours@).)

      @param(ADesiredOn The state to switch to when the timer fires.)

      @returns(The timer, with the id the device assigned.)

      @raises(ETapoError ADelaySeconds is out of range.)
    *)
    /// <summary>Sets the countdown timer, replacing any existing one.</summary>
    /// <param name="ADelaySeconds">1 to 86400 (24 hours).</param>
    /// <param name="ADesiredOn">The state to switch to when the timer fires.</param>
    /// <returns>The timer, with the id the device assigned.</returns>
    /// <exception cref="ETapoError">ADelaySeconds is out of range.</exception>
    function SetTimer(ADelaySeconds: Integer; ADesiredOn: Boolean): TTapoTimer;
    (***
      Reads the countdown timer.

      @param(ATimer Receives the timer, if one is set.)

      @returns(False if no timer is set.)
    *)
    /// <summary>Reads the countdown timer.</summary>
    /// <param name="ATimer">Receives the timer, if one is set.</param>
    /// <returns>False if no timer is set.</returns>
    function GetTimer(out ATimer: TTapoTimer): Boolean;
    (*** Removes the countdown timer, if any. *)
    /// <summary>Removes the countdown timer, if any.</summary>
    procedure ClearTimer;

    (***
      Adds a schedule rule.

      @param(ARule The rule, built with the TTapoScheduleRule class functions.)

      @returns(The rule with the id the device assigned.)

      @raises(ETapoError The rule is invalid, the device's rule list is full @(-1802@), or the
      rule conflicts with another @(-1803@).)
    *)
    /// <summary>Adds a schedule rule.</summary>
    /// <param name="ARule">The rule, built with the TTapoScheduleRule class functions.</param>
    /// <returns>The rule with the id the device assigned.</returns>
    /// <exception cref="ETapoError">
    ///   The rule is invalid, the device's rule list is full (-1802), or the
    ///   rule conflicts with another (-1803).
    /// </exception>
    function AddScheduleRule(const ARule: TTapoScheduleRule): TTapoScheduleRule;
    (***
      Changes an existing schedule rule.

      @param(ARule The changed rule, with its Id set @(for example from
      @link(GetScheduleRules)@).)

      @raises(ETapoError The rule has no id or is invalid.)
    *)
    /// <summary>Changes an existing schedule rule.</summary>
    /// <param name="ARule">The changed rule, with its Id set (for example from <see cref="GetScheduleRules"/>).</param>
    /// <exception cref="ETapoError">The rule has no id or is invalid.</exception>
    procedure EditScheduleRule(const ARule: TTapoScheduleRule);
    (***
      Reads every schedule rule.

      A rule of a kind this class cannot represent is skipped.
    *)
    /// <summary>Reads every schedule rule.</summary>
    /// <remarks>A rule of a kind this class cannot represent is skipped.</remarks>
    function GetScheduleRules: TArray<TTapoScheduleRule>;
    (*** Reads the largest number of schedule rules the plug can hold. *)
    /// <summary>Reads the largest number of schedule rules the plug can hold.</summary>
    function GetMaxScheduleRules: Integer;
    (***
      Removes one schedule rule.

      @param(AId The rule's id.)
    *)
    /// <summary>Removes one schedule rule.</summary>
    /// <param name="AId">The rule's id.</param>
    procedure RemoveScheduleRule(const AId: string);
    (*** Removes every schedule rule. *)
    /// <summary>Removes every schedule rule.</summary>
    procedure RemoveAllScheduleRules;
  end;

  (*** Tapo P100, P105, P125 and P125M smart plug. *)
  /// <summary>Tapo P100, P105, P125 and P125M smart plug.</summary>
  TTapoP100 = class(TTapoPlug);

  (***
    Tapo P110, P110M and P115 energy-monitoring smart plug.

    Example:
    @longCode(#
    Plug := Client.Add(P110, '192.168.1.50');
    Usage := Plug.GetEnergyUsage;
    Label1.Text := Format('%.1f W, today %.3f kWh', [Usage.CurrentPowerW, Usage.TodayEnergyKWh]);
    #)
  *)
  /// <summary>Tapo P110, P110M and P115 energy-monitoring smart plug.</summary>
  /// <example>
  ///   <code>
  ///   Plug := Client.Add(P110, '192.168.1.50');
  ///   Usage := Plug.GetEnergyUsage;
  ///   Label1.Text := Format('%.1f W, today %.3f kWh', [Usage.CurrentPowerW, Usage.TodayEnergyKWh]);
  ///   </code>
  /// </example>
  TTapoP110 = class(TTapoPlug)
  public
    (***
      Reads the power being drawn now.

      @returns(The power in watts.)
    *)
    /// <summary>Reads the power being drawn now.</summary>
    /// <returns>The power in watts.</returns>
    function GetCurrentPower: Double;
    (*** Reads today's and this month's energy use and the current power. *)
    /// <summary>Reads today's and this month's energy use and the current power.</summary>
    function GetEnergyUsage: TTapoEnergyUsage;
    (***
      Reads energy use per hour.

      @param(AStartDate The first day.)

      @param(AEndDate The last day, at most 8 days after AStartDate.)

      @raises(ETapoError The dates are out of order or too far apart.)
    *)
    /// <summary>Reads energy use per hour.</summary>
    /// <param name="AStartDate">The first day.</param>
    /// <param name="AEndDate">The last day, at most 8 days after AStartDate.</param>
    /// <exception cref="ETapoError">The dates are out of order or too far apart.</exception>
    function GetEnergyDataHourly(AStartDate, AEndDate: TDate): TTapoEnergyData;
    (***
      Reads energy use per day for a quarter.

      @param(AQuarterStart The first day of a quarter: 1 January, 1 April, 1 July or 1 October.)

      @raises(ETapoError AQuarterStart is not the first day of a quarter.)
    *)
    /// <summary>Reads energy use per day for a quarter.</summary>
    /// <param name="AQuarterStart">The first day of a quarter: 1 January, 1 April, 1 July or 1 October.</param>
    /// <exception cref="ETapoError">AQuarterStart is not the first day of a quarter.</exception>
    function GetEnergyDataDaily(AQuarterStart: TDate): TTapoEnergyData;
    (***
      Reads energy use per month for a year.

      @param(AYearStart 1 January of the year.)

      @raises(ETapoError AYearStart is not 1 January.)
    *)
    /// <summary>Reads energy use per month for a year.</summary>
    /// <param name="AYearStart">1 January of the year.</param>
    /// <exception cref="ETapoError">AYearStart is not 1 January.</exception>
    function GetEnergyDataMonthly(AYearStart: TDate): TTapoEnergyData;
    (***
      Reads the power every 5 minutes.

      @param(AStart The start, local time; rounded up to the next 5-minute mark.)

      @param(AEnd The end, local time. The device returns at most 12 hours.)
    *)
    /// <summary>Reads the power every 5 minutes.</summary>
    /// <param name="AStart">The start, local time; rounded up to the next 5-minute mark.</param>
    /// <param name="AEnd">The end, local time. The device returns at most 12 hours.</param>
    function GetPowerData5Min(AStart, AEnd: TDateTime): TTapoPowerData;
    (***
      Reads the power every hour.

      @param(AStart The start, local time; rounded up to the next hour.)

      @param(AEnd The end, local time. The device returns at most 6 days.)
    *)
    /// <summary>Reads the power every hour.</summary>
    /// <param name="AStart">The start, local time; rounded up to the next hour.</param>
    /// <param name="AEnd">The end, local time. The device returns at most 6 days.</param>
    function GetPowerDataHourly(AStart, AEnd: TDateTime): TTapoPowerData;
  end;

  (*** The features common to all lights: brightness. *)
  /// <summary>The features common to all lights: brightness.</summary>
  TTapoLight = class abstract(TTapoSwitchableDevice)
  public
    (***
      Sets the brightness.

      @param(ABrightness 1 to 100.)

      @raises(ETapoError ABrightness is out of range.)
    *)
    /// <summary>Sets the brightness.</summary>
    /// <param name="ABrightness">1 to 100.</param>
    /// <exception cref="ETapoError">ABrightness is out of range.</exception>
    procedure SetBrightness(ABrightness: Integer);
    (*** Reads the light's device info. *)
    /// <summary>Reads the light's device info.</summary>
    function GetLightInfo: TTapoLightInfo;
  end;

  (*** Tapo L510, L510B, L520 and L610 dimmable white light. *)
  /// <summary>Tapo L510, L510B, L520 and L610 dimmable white light.</summary>
  TTapoL510 = class(TTapoLight);

  (*** The features common to the colour lights and light strips. *)
  /// <summary>The features common to the colour lights and light strips.</summary>
  TTapoColorLight = class abstract(TTapoLight)
  public
    (*** Shows a colour preset. *)
    /// <summary>Shows a colour preset.</summary>
    procedure SetColor(AColor: TTapoColor);
    (***
      Shows a colour by hue and saturation.

      @param(AHue 0 to 360.)

      @param(ASaturation 1 to 100.)

      @raises(ETapoError A value is out of range.)
    *)
    /// <summary>Shows a colour by hue and saturation.</summary>
    /// <param name="AHue">0 to 360.</param>
    /// <param name="ASaturation">1 to 100.</param>
    /// <exception cref="ETapoError">A value is out of range.</exception>
    procedure SetHueSaturation(AHue, ASaturation: Integer);
    (***
      Shows a white by colour temperature.

      @param(AKelvin 2500 to 6500.)

      @raises(ETapoError AKelvin is out of range.)
    *)
    /// <summary>Shows a white by colour temperature.</summary>
    /// <param name="AKelvin">2500 to 6500.</param>
    /// <exception cref="ETapoError">AKelvin is out of range.</exception>
    procedure SetColorTemperature(AKelvin: Integer);
    (***
      Sends several settings in one request.

      @seealso(TTapoLightState)
    *)
    /// <summary>Sends several settings in one request.</summary>
    /// <seealso cref="TTapoLightState"/>
    procedure Apply(const AState: TTapoLightState);
    (*** Reads the light's device info, including its colour. *)
    /// <summary>Reads the light's device info, including its colour.</summary>
    function GetColorLightInfo: TTapoColorLightInfo;
  end;

  (*** Tapo L530, L530B, L535 and L630 multicolour light. *)
  /// <summary>Tapo L530, L530B, L535 and L630 multicolour light.</summary>
  TTapoL530 = class(TTapoColorLight);

  (*** Tapo L900 RGB light strip. *)
  /// <summary>Tapo L900 RGB light strip.</summary>
  TTapoL900 = class(TTapoColorLight);

  (*** Tapo L920 and L930 RGBIC light strip, whose segments can show different colours. *)
  /// <summary>Tapo L920 and L930 RGBIC light strip, whose segments can show different colours.</summary>
  TTapoL920 = class(TTapoL900)
  public
    (*** Runs a lighting-effect preset. *)
    /// <summary>Runs a lighting-effect preset.</summary>
    procedure SetLightingEffect(APreset: TTapoLightingEffectPreset); overload;
    (***
      Runs a lighting effect.

      @seealso(TTapoLightingEffect)
    *)
    /// <summary>Runs a lighting effect.</summary>
    /// <seealso cref="TTapoLightingEffect"/>
    procedure SetLightingEffect(const AEffect: TTapoLightingEffect); overload;
    (*** Applies a segment-effect preset. *)
    /// <summary>Applies a segment-effect preset.</summary>
    procedure SetSegmentEffect(APreset: TTapoSegmentEffectPreset); overload;
    (***
      Applies a segment effect.

      @raises(ETapoError A custom effect lacks segments, states or a type.)

      @seealso(TTapoSegmentEffect)
    *)
    /// <summary>Applies a segment effect.</summary>
    /// <exception cref="ETapoError">A custom effect lacks segments, states or a type.</exception>
    /// <seealso cref="TTapoSegmentEffect"/>
    procedure SetSegmentEffect(const AEffect: TTapoSegmentEffect); overload;
  end;

  // Model names that share a class

  (*** Tapo P105: the same as @link(TTapoP100). *)
  /// <summary>Tapo P105: the same as <see cref="TTapoP100"/>.</summary>
  TTapoP105 = TTapoP100;
  (*** Tapo P125: the same as @link(TTapoP100). *)
  /// <summary>Tapo P125: the same as <see cref="TTapoP100"/>.</summary>
  TTapoP125 = TTapoP100;
  (*** Tapo P125M: the same as @link(TTapoP100). *)
  /// <summary>Tapo P125M: the same as <see cref="TTapoP100"/>.</summary>
  TTapoP125M = TTapoP100;
  (*** Tapo P110M: the same as @link(TTapoP110). *)
  /// <summary>Tapo P110M: the same as <see cref="TTapoP110"/>.</summary>
  TTapoP110M = TTapoP110;
  (*** Tapo P115: the same as @link(TTapoP110). *)
  /// <summary>Tapo P115: the same as <see cref="TTapoP110"/>.</summary>
  TTapoP115 = TTapoP110;
  (*** Tapo L510B: the same as @link(TTapoL510). *)
  /// <summary>Tapo L510B: the same as <see cref="TTapoL510"/>.</summary>
  TTapoL510B = TTapoL510;
  (*** Tapo L520: the same as @link(TTapoL510). *)
  /// <summary>Tapo L520: the same as <see cref="TTapoL510"/>.</summary>
  TTapoL520 = TTapoL510;
  (*** Tapo L610: the same as @link(TTapoL510). *)
  /// <summary>Tapo L610: the same as <see cref="TTapoL510"/>.</summary>
  TTapoL610 = TTapoL510;
  (*** Tapo L530B: the same as @link(TTapoL530). *)
  /// <summary>Tapo L530B: the same as <see cref="TTapoL530"/>.</summary>
  TTapoL530B = TTapoL530;
  (*** Tapo L535: the same as @link(TTapoL530). *)
  /// <summary>Tapo L535: the same as <see cref="TTapoL530"/>.</summary>
  TTapoL535 = TTapoL530;
  (*** Tapo L630: the same as @link(TTapoL530). *)
  /// <summary>Tapo L630: the same as <see cref="TTapoL530"/>.</summary>
  TTapoL630 = TTapoL530;
  (*** Tapo L930: the same as @link(TTapoL920). *)
  /// <summary>Tapo L930: the same as <see cref="TTapoL920"/>.</summary>
  TTapoL930 = TTapoL920;

  { --- power strips -------------------------------------------------------- }

  (***
    One socket of a power strip.

    Obtain sockets from the strip (@link(TTapoPowerStrip.Outlet)), which owns them.
  *)
  /// <summary>One socket of a power strip.</summary>
  /// <remarks>Obtain sockets from the strip (<see cref="TTapoPowerStrip.Outlet"/>), which owns them.</remarks>
  TTapoPowerStripOutlet = class(TTapoChildDevice)
  public
    (*** Switches the socket on. *)
    /// <summary>Switches the socket on.</summary>
    procedure TurnOn;
    (*** Switches the socket off. *)
    /// <summary>Switches the socket off.</summary>
    procedure TurnOff;
    (***
      Switches the socket on or off.

      @param(AOn True for on.)
    *)
    /// <summary>Switches the socket on or off.</summary>
    /// <param name="AOn">True for on.</param>
    procedure SetOn(AOn: Boolean);
    (***
      Reads the socket's power state.

      @returns(True if the socket is on.)
    *)
    /// <summary>Reads the socket's power state.</summary>
    /// <returns>True if the socket is on.</returns>
    function IsOn: Boolean;
    (*** Reads the socket's device info. *)
    /// <summary>Reads the socket's device info.</summary>
    function GetOutletInfo: TTapoOutletInfo;
  end;

  (*** A socket of an energy-monitoring power strip (P304M, P316M). *)
  /// <summary>A socket of an energy-monitoring power strip (P304M, P316M).</summary>
  TTapoEnergyOutlet = class(TTapoPowerStripOutlet)
  public
    (*** Reads how long the socket has been on, and the energy it used. *)
    /// <summary>Reads how long the socket has been on, and the energy it used.</summary>
    function GetDeviceUsage: TTapoDeviceUsage;
    (*** Reads the power being drawn now, in watts. *)
    /// <summary>Reads the power being drawn now, in watts.</summary>
    function GetCurrentPower: Double;
    (*** Reads today's and this month's energy use and the current power. *)
    /// <summary>Reads today's and this month's energy use and the current power.</summary>
    function GetEnergyUsage: TTapoEnergyUsage;
    (*** Reads energy use per hour; see @link(TTapoP110.GetEnergyDataHourly). *)
    /// <summary>Reads energy use per hour; see <see cref="TTapoP110.GetEnergyDataHourly"/>.</summary>
    function GetEnergyDataHourly(AStartDate, AEndDate: TDate): TTapoEnergyData;
    (*** Reads energy use per day for a quarter; see @link(TTapoP110.GetEnergyDataDaily). *)
    /// <summary>Reads energy use per day for a quarter; see <see cref="TTapoP110.GetEnergyDataDaily"/>.</summary>
    function GetEnergyDataDaily(AQuarterStart: TDate): TTapoEnergyData;
    (*** Reads energy use per month for a year; see @link(TTapoP110.GetEnergyDataMonthly). *)
    /// <summary>Reads energy use per month for a year; see <see cref="TTapoP110.GetEnergyDataMonthly"/>.</summary>
    function GetEnergyDataMonthly(AYearStart: TDate): TTapoEnergyData;
    (*** Reads the power every 5 minutes; see @link(TTapoP110.GetPowerData5Min). *)
    /// <summary>Reads the power every 5 minutes; see <see cref="TTapoP110.GetPowerData5Min"/>.</summary>
    function GetPowerData5Min(AStart, AEnd: TDateTime): TTapoPowerData;
    (*** Reads the power every hour; see @link(TTapoP110.GetPowerDataHourly). *)
    /// <summary>Reads the power every hour; see <see cref="TTapoP110.GetPowerDataHourly"/>.</summary>
    function GetPowerDataHourly(AStart, AEnd: TDateTime): TTapoPowerData;
  end;

  (***
    The features common to the power strips: their sockets.

    The strip itself has no power state; switch the sockets.
  *)
  /// <summary>The features common to the power strips: their sockets.</summary>
  /// <remarks>The strip itself has no power state; switch the sockets.</remarks>
  TTapoPowerStrip = class abstract(TTapoDevice)
  protected
    (*** The class of the strip's socket objects. *)
    /// <summary>The class of the strip's socket objects.</summary>
    class function OutletClass: TTapoChildDeviceClass; virtual;
  public
    (*** Reads every socket and its state, in position order. *)
    /// <summary>Reads every socket and its state, in position order.</summary>
    function GetChildDeviceList: TArray<TTapoOutletInfo>;
    (*** Reads the first page of the socket list as formatted JSON. *)
    /// <summary>Reads the first page of the socket list as formatted JSON.</summary>
    function GetChildDeviceListJSON: string;
    (*** Reads the sockets' components as formatted JSON. *)
    /// <summary>Reads the sockets' components as formatted JSON.</summary>
    function GetChildDeviceComponentListJSON: string;

    (***
      A socket by its position.

      @param(APosition 1 for the first socket.)

      @returns(The socket, owned by the strip.)

      @raises(ETapoError There is no socket at APosition.)
    *)
    /// <summary>A socket by its position.</summary>
    /// <param name="APosition">1 for the first socket.</param>
    /// <returns>The socket, owned by the strip.</returns>
    /// <exception cref="ETapoError">There is no socket at APosition.</exception>
    function Outlet(APosition: Integer): TTapoPowerStripOutlet;
    (***
      A socket by the name given in the Tapo app (case-insensitive).

      @raises(ETapoError No socket has that name.)
    *)
    /// <summary>A socket by the name given in the Tapo app (case-insensitive).</summary>
    /// <exception cref="ETapoError">No socket has that name.</exception>
    function OutletByNickname(const ANickname: string): TTapoPowerStripOutlet;
    (***
      A socket by its device id.

      @raises(ETapoError No socket has that id.)
    *)
    /// <summary>A socket by its device id.</summary>
    /// <exception cref="ETapoError">No socket has that id.</exception>
    function OutletById(const ADeviceId: string): TTapoPowerStripOutlet;
    (*** Every socket, in position order, owned by the strip. *)
    /// <summary>Every socket, in position order, owned by the strip.</summary>
    function Outlets: TArray<TTapoPowerStripOutlet>;
  end;

  (*** Tapo P300 and P306 power strip. *)
  /// <summary>Tapo P300 and P306 power strip.</summary>
  TTapoP300 = class(TTapoPowerStrip);

  (***
    Tapo P304M and P316M energy-monitoring power strip.

    Example:
    @longCode(#
    Strip := Client.Add(P304M, '192.168.1.52');
    for Socket in Strip.Outlets do
      Memo1.Lines.Add(Format('%s: %.1f W', [Socket.GetOutletInfo.Nickname, Socket.GetCurrentPower]));
    #)
  *)
  /// <summary>Tapo P304M and P316M energy-monitoring power strip.</summary>
  /// <example>
  ///   <code>
  ///   Strip := Client.Add(P304M, '192.168.1.52');
  ///   for Socket in Strip.Outlets do
  ///     Memo1.Lines.Add(Format('%s: %.1f W', [Socket.GetOutletInfo.Nickname, Socket.GetCurrentPower]));
  ///   </code>
  /// </example>
  TTapoP304M = class(TTapoPowerStrip)
  protected
    (*** Returns @link(TTapoEnergyOutlet). *)
    /// <summary>Returns <see cref="TTapoEnergyOutlet"/>.</summary>
    class function OutletClass: TTapoChildDeviceClass; override;
  public
    (*** A socket by its position (1 for the first), with energy monitoring. *)
    /// <summary>A socket by its position (1 for the first), with energy monitoring.</summary>
    function Outlet(APosition: Integer): TTapoEnergyOutlet; reintroduce;
    (*** A socket by the name given in the Tapo app, with energy monitoring. *)
    /// <summary>A socket by the name given in the Tapo app, with energy monitoring.</summary>
    function OutletByNickname(const ANickname: string): TTapoEnergyOutlet; reintroduce;
    (*** A socket by its device id, with energy monitoring. *)
    /// <summary>A socket by its device id, with energy monitoring.</summary>
    function OutletById(const ADeviceId: string): TTapoEnergyOutlet; reintroduce;
    (*** Every socket, in position order, with energy monitoring. *)
    /// <summary>Every socket, in position order, with energy monitoring.</summary>
    function Outlets: TArray<TTapoEnergyOutlet>; reintroduce;
  end;

  (*** Tapo P306: the same as @link(TTapoP300). *)
  /// <summary>Tapo P306: the same as <see cref="TTapoP300"/>.</summary>
  TTapoP306 = TTapoP300;
  (*** Tapo P316M: the same as @link(TTapoP304M). *)
  /// <summary>Tapo P316M: the same as <see cref="TTapoP304M"/>.</summary>
  TTapoP316M = TTapoP304M;

const
  (*** Monday to Friday. *)
  /// <summary>Monday to Friday.</summary>
  TapoWeekdays: TTapoWeekDays = [wdMon, wdTue, wdWed, wdThu, wdFri];
  (*** Saturday and Sunday. *)
  /// <summary>Saturday and Sunday.</summary>
  TapoWeekend: TTapoWeekDays = [wdSat, wdSun];
  (*** Every day of the week. *)
  /// <summary>Every day of the week.</summary>
  TapoEveryDay: TTapoWeekDays = [wdSun, wdMon, wdTue, wdWed, wdThu, wdFri, wdSat];

(***
  Gives the hue, saturation and colour temperature of a colour preset.

  @param(AColor The preset.)

  @param(AHue Receives the hue, 0 to 360.)

  @param(ASaturation Receives the saturation.)

  @param(AColorTemp Receives the colour temperature; 0 for a colour.)
*)
/// <summary>Gives the hue, saturation and colour temperature of a colour preset.</summary>
/// <param name="AColor">The preset.</param>
/// <param name="AHue">Receives the hue, 0 to 360.</param>
/// <param name="ASaturation">Receives the saturation.</param>
/// <param name="AColorTemp">Receives the colour temperature; 0 for a colour.</param>
procedure TapoColorValues(AColor: TTapoColor; out AHue, ASaturation, AColorTemp: Integer);
(*** Makes a @link(TTapoHSB). *)
/// <summary>Makes a <see cref="TTapoHSB"/>.</summary>
function HSB(AHue, ASaturation, ABrightness: Integer): TTapoHSB;
(*** Makes a @link(TTapoHSBK). *)
/// <summary>Makes a <see cref="TTapoHSBK"/>.</summary>
function HSBK(AHue, ASaturation, ABrightness, AKelvin: Integer): TTapoHSBK;

implementation

type
  TColorConfig = record
    Hue, Saturation, ColorTemp: Integer;
  end;

const
  ColorTable: array[TTapoColor] of TColorConfig = (
    (Hue: 0;   Saturation: 100; ColorTemp: 4000),   // CoolWhite
    (Hue: 0;   Saturation: 100; ColorTemp: 5000),   // Daylight
    (Hue: 0;   Saturation: 100; ColorTemp: 6000),   // Ivory
    (Hue: 0;   Saturation: 100; ColorTemp: 3000),   // WarmWhite
    (Hue: 0;   Saturation: 100; ColorTemp: 2700),   // Incandescent
    (Hue: 0;   Saturation: 100; ColorTemp: 2500),   // Candlelight
    (Hue: 0;   Saturation: 100; ColorTemp: 6500),   // Snow
    (Hue: 0;   Saturation: 100; ColorTemp: 6500),   // GhostWhite
    (Hue: 208; Saturation: 5;   ColorTemp: 0),      // AliceBlue
    (Hue: 54;  Saturation: 28;  ColorTemp: 0),      // LightGoldenrod
    (Hue: 54;  Saturation: 19;  ColorTemp: 0),      // LemonChiffon
    (Hue: 0;   Saturation: 100; ColorTemp: 5500),   // AntiqueWhite
    (Hue: 50;  Saturation: 100; ColorTemp: 0),      // Gold
    (Hue: 29;  Saturation: 69;  ColorTemp: 0),      // Peru
    (Hue: 30;  Saturation: 100; ColorTemp: 0),      // Chocolate
    (Hue: 27;  Saturation: 60;  ColorTemp: 0),      // SandyBrown
    (Hue: 16;  Saturation: 68;  ColorTemp: 0),      // Coral
    (Hue: 24;  Saturation: 90;  ColorTemp: 0),      // Pumpkin
    (Hue: 9;   Saturation: 72;  ColorTemp: 0),      // Tomato
    (Hue: 4;   Saturation: 77;  ColorTemp: 0),      // Vermilion
    (Hue: 16;  Saturation: 100; ColorTemp: 0),      // OrangeRed
    (Hue: 349; Saturation: 24;  ColorTemp: 0),      // Pink
    (Hue: 348; Saturation: 90;  ColorTemp: 0),      // Crimson
    (Hue: 0;   Saturation: 100; ColorTemp: 0),      // DarkRed
    (Hue: 330; Saturation: 58;  ColorTemp: 0),      // HotPink
    (Hue: 329; Saturation: 67;  ColorTemp: 0),      // Smitten
    (Hue: 259; Saturation: 48;  ColorTemp: 0),      // MediumPurple
    (Hue: 271; Saturation: 80;  ColorTemp: 0),      // BlueViolet
    (Hue: 274; Saturation: 100; ColorTemp: 0),      // Indigo
    (Hue: 202; Saturation: 46;  ColorTemp: 0),      // LightSkyBlue
    (Hue: 218; Saturation: 57;  ColorTemp: 0),      // CornflowerBlue
    (Hue: 254; Saturation: 100; ColorTemp: 0),      // Ultramarine
    (Hue: 195; Saturation: 100; ColorTemp: 0),      // DeepSkyBlue
    (Hue: 210; Saturation: 100; ColorTemp: 0),      // Azure
    (Hue: 240; Saturation: 100; ColorTemp: 0),      // NavyBlue
    (Hue: 180; Saturation: 26;  ColorTemp: 0),      // LightTurquoise
    (Hue: 159; Saturation: 50;  ColorTemp: 0),      // Aquamarine
    (Hue: 174; Saturation: 71;  ColorTemp: 0),      // Turquoise
    (Hue: 120; Saturation: 39;  ColorTemp: 0),      // LightGreen
    (Hue: 75;  Saturation: 100; ColorTemp: 0),      // Lime
    (Hue: 120; Saturation: 75;  ColorTemp: 0));     // ForestGreen

  MAX_TIMER_SECONDS = 24 * 60 * 60;
  MAX_SCHEDULE_OFFSET = 360;
  MAX_SCHEDULE_PAGES = 16;
  MAX_CHILD_PAGES = 16;

procedure TapoColorValues(AColor: TTapoColor; out AHue, ASaturation, AColorTemp: Integer);
begin
  AHue := ColorTable[AColor].Hue;
  ASaturation := ColorTable[AColor].Saturation;
  AColorTemp := ColorTable[AColor].ColorTemp;
end;

procedure ValidationError(const AField, AMessage: string);
begin
  raise ETapoError.CreateCode(-1, AField + ': ' + AMessage);
end;

{ ============================================================================ }
{ Shared capability helpers (work on any endpoint: device or strip socket)      }
{ ============================================================================ }

procedure EPSetOn(E: TTapoEndpoint; AOn: Boolean);
begin
  E.SetDeviceInfo(JObject(['device_on', AOn]));
end;

function EPIsOn(E: TTapoEndpoint): Boolean;
var
  R: TJSONObject;
begin
  R := E.GetDeviceInfoObject;
  try
    Result := JBool(R, 'device_on');
  finally
    R.Free;
  end;
end;

function UsagePeriod(Obj: TJSONObject): TTapoUsageByPeriod;
begin
  Result.Today := JInt64(Obj, 'today', -1);
  Result.Past7Days := JInt64(Obj, 'past7', -1);
  Result.Past30Days := JInt64(Obj, 'past30', -1);
end;

function EPDeviceUsage(E: TTapoEndpoint): TTapoDeviceUsage;
var
  R: TJSONObject;
begin
  R := E.Execute('get_device_usage');
  try
    Result.TimeUsage := UsagePeriod(JObj(R, 'time_usage'));
    Result.PowerUsage := UsagePeriod(JObj(R, 'power_usage'));
    Result.SavedPower := UsagePeriod(JObj(R, 'saved_power'));
    Result.Raw := R.Format;
  finally
    R.Free;
  end;
end;

function EPCurrentPower(E: TTapoEndpoint): Double;
var
  R: TJSONObject;
begin
  R := E.Execute('get_current_power');
  try
    Result := JFloat(R, 'current_power');   // W
  finally
    R.Free;
  end;
end;

function EPEnergyUsage(E: TTapoEndpoint): TTapoEnergyUsage;
var
  R: TJSONObject;
  A: TJSONArray;
  I: Integer;
begin
  R := E.Execute('get_energy_usage');
  try
    Result.TodayRuntimeMin := JInt64(R, 'today_runtime');
    Result.MonthRuntimeMin := JInt64(R, 'month_runtime');
    Result.TodayEnergyWh := JInt64(R, 'today_energy');
    Result.MonthEnergyWh := JInt64(R, 'month_energy');
    Result.HasCurrentPower := JHas(R, 'current_power');
    Result.CurrentPowerMW := JInt64(R, 'current_power');
    Result.LocalTime := JStr(R, 'local_time');
    Result.ElectricityCharge := nil;
    A := JArr(R, 'electricity_charge');
    if A <> nil then
    begin
      SetLength(Result.ElectricityCharge, A.Count);
      for I := 0 to A.Count - 1 do
        if A.Items[I] is TJSONNumber then
          Result.ElectricityCharge[I] := TJSONNumber(A.Items[I]).AsInt64
        else
          Result.ElectricityCharge[I] := 0;
    end;
    Result.Raw := R.Format;
  finally
    R.Free;
  end;
end;

function LocalMidnightUnix(ADate: TDate): Int64;
begin
  Result := DateTimeToUnix(DateOf(ADate), False);
end;

function EPEnergyData(E: TTapoEndpoint; AStart, AEnd: Int64; AInterval: Integer): TTapoEnergyData;
var
  R: TJSONObject;
  A: TJSONArray;
  I, Interval: Integer;
  T: TDateTime;
begin
  R := E.Execute('get_energy_data', JObject(['start_timestamp', AStart,
    'end_timestamp', AEnd, 'interval', AInterval]));
  try
    Result.LocalTime := JStr(R, 'local_time');
    Interval := Integer(JInt64(R, 'interval', AInterval));
    Result.IntervalMinutes := Interval;
    T := UnixToDateTime(JInt64(R, 'start_timestamp', AStart), False);
    Result.StartTime := T;
    Result.Entries := nil;
    A := JArr(R, 'data');
    if A <> nil then
    begin
      SetLength(Result.Entries, A.Count);
      for I := 0 to A.Count - 1 do
      begin
        Result.Entries[I].StartTime := T;
        if A.Items[I] is TJSONNumber then
          Result.Entries[I].EnergyWh := TJSONNumber(A.Items[I]).AsInt64
        else
          Result.Entries[I].EnergyWh := 0;
        case Interval of
          60:    T := IncHour(T);
          1440:  T := IncDay(T);
          43200: T := IncMonth(T);
        else
          raise ETapoError.CreateCode(-1, Format('Unsupported energy data interval: %d minutes', [Interval]));
        end;
      end;
    end;
  finally
    R.Free;
  end;
end;

// Rounds a Unix time up to the next multiple of AStep seconds.
function RoundUpTo(AUnix: Int64; AStep: Integer): Int64;
begin
  Result := AUnix;
  if Result mod AStep <> 0 then
    Result := Result + AStep - (Result mod AStep);
end;

function EPPowerData(E: TTapoEndpoint; AStart, AEnd: TDateTime; AInterval: Integer): TTapoPowerData;
var
  R: TJSONObject;
  A: TJSONArray;
  I, Interval: Integer;
  S, En: Int64;
  T: TDateTime;
  V: TJSONValue;
begin
  if AInterval = 5 then
  begin
    S := RoundUpTo(DateTimeToUnix(AStart, False), 300);
    En := RoundUpTo(DateTimeToUnix(AEnd, False), 300);
  end
  else
  begin
    S := RoundUpTo(DateTimeToUnix(AStart, False), 3600);
    En := RoundUpTo(DateTimeToUnix(AEnd, False), 3600);
  end;
  R := E.Execute('get_power_data', JObject(['start_timestamp', S,
    'end_timestamp', En, 'interval', AInterval]));
  try
    Interval := Integer(JInt64(R, 'interval', AInterval));
    Result.IntervalMinutes := Interval;
    T := UnixToDateTime(JInt64(R, 'start_timestamp', S), False);
    Result.StartTime := T;
    Result.EndTime := UnixToDateTime(JInt64(R, 'end_timestamp', En), False);
    Result.Entries := nil;
    A := JArr(R, 'data');
    if A <> nil then
    begin
      SetLength(Result.Entries, A.Count);
      for I := 0 to A.Count - 1 do
      begin
        Result.Entries[I].StartTime := T;
        V := A.Items[I];
        Result.Entries[I].HasValue := (V is TJSONNumber) and (TJSONNumber(V).AsInt64 >= 0);
        if Result.Entries[I].HasValue then
          Result.Entries[I].PowerW := TJSONNumber(V).AsInt64
        else
          Result.Entries[I].PowerW := 0;
        T := IncMinute(T, Interval);
      end;
    end;
  finally
    R.Free;
  end;
end;

procedure HourlyRange(AStartDate, AEndDate: TDate; out AStart, AEnd: Int64);
begin
  if DateOf(AEndDate) < DateOf(AStartDate) then
    ValidationError('end_date', 'must not be before the start date');
  if DaysBetween(DateOf(AEndDate), DateOf(AStartDate)) > 8 then
    ValidationError('end_date', 'must be at most 8 days after the start date');
  AStart := LocalMidnightUnix(AStartDate);
  AEnd := DateTimeToUnix(RecodeTime(DateOf(AEndDate), 23, 59, 59, 0), False);
end;

function EPEnergyHourly(E: TTapoEndpoint; AStartDate, AEndDate: TDate): TTapoEnergyData;
var
  S, En: Int64;
begin
  HourlyRange(AStartDate, AEndDate, S, En);
  Result := EPEnergyData(E, S, En, 60);
end;

function EPEnergyDaily(E: TTapoEndpoint; AQuarterStart: TDate): TTapoEnergyData;
var
  S: Int64;
begin
  if (DayOf(AQuarterStart) <> 1) or not (MonthOf(AQuarterStart) in [1, 4, 7, 10]) then
    ValidationError('start_date', 'must be the first day of a quarter');
  S := LocalMidnightUnix(AQuarterStart);
  Result := EPEnergyData(E, S, S, 1440);
end;

function EPEnergyMonthly(E: TTapoEndpoint; AYearStart: TDate): TTapoEnergyData;
var
  S: Int64;
begin
  if (DayOf(AYearStart) <> 1) or (MonthOf(AYearStart) <> 1) then
    ValidationError('start_date', 'must be the first day of a year');
  S := LocalMidnightUnix(AYearStart);
  Result := EPEnergyData(E, S, S, 43200);
end;

function StatusStr(Obj: TJSONObject; const Name: string): string;
begin
  Result := JStr(Obj, Name);
end;

procedure PlugDefaultState(Obj: TJSONObject; out AType: string; out AOn: Boolean);
var
  D: TJSONObject;
begin
  D := JObj(Obj, 'default_states');
  AType := JStr(D, 'type');
  AOn := JBool(JObj(D, 'state'), 'on');
end;

{ ============================================================================ }
{ Records                                                                      }
{ ============================================================================ }

function TTapoEnergyUsage.CurrentPowerW: Double;
begin
  Result := CurrentPowerMW / 1000;
end;

function TTapoEnergyUsage.TodayEnergyKWh: Double;
begin
  Result := TodayEnergyWh / 1000;
end;

function TTapoEnergyUsage.MonthEnergyKWh: Double;
begin
  Result := MonthEnergyWh / 1000;
end;

{ TTapoScheduleRule }

function MakeRule(AKind: TTapoScheduleTimeKind; AHour, AMinute, AOffset: Integer;
  ARepeating: Boolean; ADays: TTapoWeekDays; ADesiredOn: Boolean): TTapoScheduleRule;
begin
  Result.Id := '';
  Result.Enabled := True;
  Result.TimeKind := AKind;
  Result.Hour := AHour;
  Result.Minute := AMinute;
  Result.OffsetMinutes := AOffset;
  Result.Repeating := ARepeating;
  Result.Days := ADays;
  Result.DesiredOn := ADesiredOn;
  Result.Validate;
end;

class function TTapoScheduleRule.ClockWeekly(AHour, AMinute: Integer; ADays: TTapoWeekDays;
  ADesiredOn: Boolean): TTapoScheduleRule;
begin
  Result := MakeRule(stkClock, AHour, AMinute, 0, True, ADays, ADesiredOn);
end;

class function TTapoScheduleRule.ClockOnce(AHour, AMinute: Integer; ADesiredOn: Boolean): TTapoScheduleRule;
begin
  Result := MakeRule(stkClock, AHour, AMinute, 0, False, [], ADesiredOn);
end;

class function TTapoScheduleRule.SunriseWeekly(AOffsetMinutes: Integer; ADays: TTapoWeekDays;
  ADesiredOn: Boolean): TTapoScheduleRule;
begin
  Result := MakeRule(stkSunrise, 0, 0, AOffsetMinutes, True, ADays, ADesiredOn);
end;

class function TTapoScheduleRule.SunriseOnce(AOffsetMinutes: Integer; ADesiredOn: Boolean): TTapoScheduleRule;
begin
  Result := MakeRule(stkSunrise, 0, 0, AOffsetMinutes, False, [], ADesiredOn);
end;

class function TTapoScheduleRule.SunsetWeekly(AOffsetMinutes: Integer; ADays: TTapoWeekDays;
  ADesiredOn: Boolean): TTapoScheduleRule;
begin
  Result := MakeRule(stkSunset, 0, 0, AOffsetMinutes, True, ADays, ADesiredOn);
end;

class function TTapoScheduleRule.SunsetOnce(AOffsetMinutes: Integer; ADesiredOn: Boolean): TTapoScheduleRule;
begin
  Result := MakeRule(stkSunset, 0, 0, AOffsetMinutes, False, [], ADesiredOn);
end;

function TTapoScheduleRule.WithEnabled(AEnabled: Boolean): TTapoScheduleRule;
begin
  Result := Self;
  Result.Enabled := AEnabled;
end;

procedure TTapoScheduleRule.Validate;
begin
  if TimeKind = stkClock then
  begin
    if (Hour < 0) or (Hour > 23) then
      ValidationError('hour', 'must be 0..23');
    if (Minute < 0) or (Minute > 59) then
      ValidationError('minute', 'must be 0..59');
  end
  else if Abs(OffsetMinutes) > MAX_SCHEDULE_OFFSET then
    ValidationError('offset_minutes', 'must be within -360..360 minutes');
  if Repeating and (Days = []) then
    ValidationError('days', 'a repeating rule must fire on at least one day');
end;

function DaysToBits(ADays: TTapoWeekDays): Integer;
var
  D: TTapoWeekDay;
begin
  Result := 0;
  for D := Low(TTapoWeekDay) to High(TTapoWeekDay) do
    if D in ADays then
      Result := Result or (1 shl Ord(D));   // Sun = bit 0 ... Sat = bit 6
end;

function BitsToDays(ABits: Integer): TTapoWeekDays;
var
  D: TTapoWeekDay;
begin
  Result := [];
  for D := Low(TTapoWeekDay) to High(TTapoWeekDay) do
    if (ABits and (1 shl Ord(D))) <> 0 then
      Include(Result, D);
end;

function ScheduleRuleToJSON(const ARule: TTapoScheduleRule; AIncludeId: Boolean): TJSONObject;
var
  SType, Mode: string;
  TimeOffset, SMin, WeekDay: Integer;
begin
  case ARule.TimeKind of
    stkClock:   begin SType := 'normal';  TimeOffset := 0; SMin := ARule.Hour * 60 + ARule.Minute; end;
    stkSunrise: begin SType := 'sunrise'; TimeOffset := ARule.OffsetMinutes; SMin := 0; end;
  else
    SType := 'sunset'; TimeOffset := ARule.OffsetMinutes; SMin := 0;
  end;
  if ARule.Repeating then
  begin
    Mode := 'repeat';
    WeekDay := DaysToBits(ARule.Days);
  end
  else
  begin
    Mode := 'once';
    WeekDay := 0;
  end;
  Result := TJSONObject.Create;
  if AIncludeId then
    Result.AddPair('id', ARule.Id);
  Result.AddPair('enable', TJSONBool.Create(ARule.Enabled));
  Result.AddPair('year', TJSONNumber.Create(1970));
  Result.AddPair('month', TJSONNumber.Create(1));
  Result.AddPair('day', TJSONNumber.Create(1));
  Result.AddPair('time_offset', TJSONNumber.Create(TimeOffset));
  Result.AddPair('week_day', TJSONNumber.Create(WeekDay));
  Result.AddPair('s_min', TJSONNumber.Create(SMin));
  Result.AddPair('e_min', TJSONNumber.Create(0));
  Result.AddPair('s_type', SType);
  Result.AddPair('e_type', 'normal');
  Result.AddPair('e_action', 'none');
  Result.AddPair('mode', Mode);
  Result.AddPair('desired_states', JObject(['on', ARule.DesiredOn]));
end;

// Reads desired_states.on, or the older s_action / action field.
function DesiredOnFrom(Obj: TJSONObject; const ALegacyField: string; out AOn: Boolean): Boolean;
var
  D: TJSONObject;
  Action: string;
begin
  D := JObj(Obj, 'desired_states');
  if JHas(D, 'on') then
  begin
    AOn := JBool(D, 'on');
    Exit(True);
  end;
  Action := JStr(Obj, ALegacyField);
  Result := (Action = 'on') or (Action = 'off');
  AOn := Action = 'on';
end;

function ScheduleRuleFromJSON(Obj: TJSONObject; out ARule: TTapoScheduleRule): Boolean;
var
  SType, Mode: string;
  SMin: Integer;
begin
  Result := False;
  ARule.Id := JStr(Obj, 'id');
  ARule.Enabled := JBool(Obj, 'enable');
  ARule.Hour := 0;
  ARule.Minute := 0;
  ARule.OffsetMinutes := 0;
  SType := JStr(Obj, 's_type');
  if SType = 'normal' then
  begin
    SMin := Integer(JInt64(Obj, 's_min'));
    if (SMin < 0) or (SMin >= 24 * 60) then
      Exit;
    ARule.TimeKind := stkClock;
    ARule.Hour := SMin div 60;
    ARule.Minute := SMin mod 60;
  end
  else if (SType = 'sunrise') or (SType = 'sunset') then
  begin
    if SType = 'sunrise' then
      ARule.TimeKind := stkSunrise
    else
      ARule.TimeKind := stkSunset;
    ARule.OffsetMinutes := Integer(JInt64(Obj, 'time_offset'));
  end
  else
    Exit;
  Mode := JStr(Obj, 'mode');
  if Mode = 'once' then
  begin
    ARule.Repeating := False;
    ARule.Days := [];
  end
  else if Mode = 'repeat' then
  begin
    ARule.Repeating := True;
    ARule.Days := BitsToDays(Integer(JInt64(Obj, 'week_day')));
  end
  else
    Exit;
  Result := (ARule.Id <> '') and DesiredOnFrom(Obj, 's_action', ARule.DesiredOn);
end;

{ TTapoLightState }

class function TTapoLightState.New: TTapoLightState;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function TTapoLightState.TurnOn: TTapoLightState;
begin
  Result := Self;
  Result.HasOn := True;
  Result.DeviceOn := True;
end;

function TTapoLightState.TurnOff: TTapoLightState;
begin
  Result := Self;
  Result.HasOn := True;
  Result.DeviceOn := False;
end;

function TTapoLightState.WithBrightness(AValue: Integer): TTapoLightState;
begin
  Result := Self;
  Result.HasBrightness := True;
  Result.Brightness := AValue;
end;

function TTapoLightState.WithColor(AColor: TTapoColor): TTapoLightState;
begin
  Result := Self;
  Result.HasHueSaturation := True;
  Result.HasColorTemp := True;
  TapoColorValues(AColor, Result.Hue, Result.Saturation, Result.ColorTemp);
end;

function TTapoLightState.WithHueSaturation(AHue, ASaturation: Integer): TTapoLightState;
begin
  Result := Self;
  Result.HasHueSaturation := True;
  Result.Hue := AHue;
  Result.Saturation := ASaturation;
  Result.HasColorTemp := True;     // a colour needs colour temperature 0
  Result.ColorTemp := 0;
end;

function TTapoLightState.WithColorTemperature(AKelvin: Integer): TTapoLightState;
begin
  Result := Self;
  Result.HasHueSaturation := False;
  Result.HasColorTemp := True;
  Result.ColorTemp := AKelvin;
end;

procedure TTapoLightState.Validate;
begin
  if not (HasOn or HasBrightness or HasHueSaturation or HasColorTemp) then
    ValidationError('light state', 'requires at least one property');
  if HasBrightness and ((Brightness < 1) or (Brightness > 100)) then
    ValidationError('brightness', 'must be between 1 and 100');
  if HasHueSaturation then
  begin
    if (Hue < 0) or (Hue > 360) then
      ValidationError('hue', 'must be between 0 and 360');
    if (Saturation < 1) or (Saturation > 100) then
      ValidationError('saturation', 'must be between 1 and 100');
  end;
  if HasColorTemp and not HasHueSaturation and ((ColorTemp < 2500) or (ColorTemp > 6500)) then
    ValidationError('color_temperature', 'must be between 2500 and 6500');
end;

function TTapoLightState.ToJSON: TJSONObject;
begin
  Validate;
  Result := TJSONObject.Create;
  if HasOn then
    Result.AddPair('device_on', TJSONBool.Create(DeviceOn));
  if HasBrightness then
    Result.AddPair('brightness', TJSONNumber.Create(Brightness));
  if HasHueSaturation then
  begin
    Result.AddPair('hue', TJSONNumber.Create(Hue));
    Result.AddPair('saturation', TJSONNumber.Create(Saturation));
  end;
  if HasColorTemp then
    Result.AddPair('color_temp', TJSONNumber.Create(ColorTemp));
end;


{ ============================================================================ }
{ TTapoSwitchableDevice                                                        }
{ ============================================================================ }

procedure TTapoSwitchableDevice.TurnOn;
begin
  EPSetOn(Self, True);
end;

procedure TTapoSwitchableDevice.TurnOff;
begin
  EPSetOn(Self, False);
end;

procedure TTapoSwitchableDevice.SetOn(AOn: Boolean);
begin
  EPSetOn(Self, AOn);
end;

function TTapoSwitchableDevice.IsOn: Boolean;
begin
  Result := EPIsOn(Self);
end;

function TTapoSwitchableDevice.GetDeviceUsage: TTapoDeviceUsage;
begin
  Result := EPDeviceUsage(Self);
end;

{ ============================================================================ }
{ TTapoPlug                                                                    }
{ ============================================================================ }

function TTapoPlug.GetPlugInfo: TTapoPlugInfo;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result.Info := TTapoDeviceInfo.FromJSON(R);
    Result.DeviceOn := JBool(R, 'device_on');
    Result.OnTime := JInt64(R, 'on_time');
    Result.OvercurrentStatus := StatusStr(R, 'overcurrent_status');
    Result.OverheatStatus := StatusStr(R, 'overheat_status');
    Result.PowerProtectionStatus := StatusStr(R, 'power_protection_status');
    Result.ChargingStatus := StatusStr(R, 'charging_status');
    PlugDefaultState(R, Result.DefaultStateType, Result.DefaultOn);
  finally
    R.Free;
  end;
end;

function TTapoPlug.SetTimer(ADelaySeconds: Integer; ADesiredOn: Boolean): TTapoTimer;
var
  R: TJSONObject;
begin
  if (ADelaySeconds < 1) or (ADelaySeconds > MAX_TIMER_SECONDS) then
    ValidationError('delay', 'must be between 1 second and 24 hours (86400 seconds)');
  // The plug holds one timer and rejects a second, so clear first.
  ClearTimer;
  R := Execute('add_countdown_rule', JObject(['enable', True, 'delay', ADelaySeconds,
    'desired_states', JObject(['on', ADesiredOn])]));
  try
    Result.Id := JStr(R, 'id');
  finally
    R.Free;
  end;
  Result.DelaySeconds := ADelaySeconds;
  Result.RemainingSeconds := ADelaySeconds;
  Result.DesiredOn := ADesiredOn;
end;

function TTapoPlug.GetTimer(out ATimer: TTapoTimer): Boolean;
var
  R, Rule: TJSONObject;
  A: TJSONArray;
begin
  Result := False;
  R := Execute('get_countdown_rules', TJSONObject.Create);
  try
    A := JArr(R, 'rule_list');
    if (A = nil) or (A.Count = 0) or not (A.Items[0] is TJSONObject) then
      Exit;
    Rule := TJSONObject(A.Items[0]);
    ATimer.Id := JStr(Rule, 'id');
    ATimer.DelaySeconds := Integer(JInt64(Rule, 'delay'));
    ATimer.RemainingSeconds := Integer(JInt64(Rule, 'remain'));
    if not DesiredOnFrom(Rule, 'action', ATimer.DesiredOn) then
      raise ETapoError.CreateCode(-1, 'Timer ' + ATimer.Id +
        ' reports neither desired_states.on nor a recognised action');
    Result := True;
  finally
    R.Free;
  end;
end;

procedure TTapoPlug.ClearTimer;
begin
  Execute('remove_countdown_rules', JObject(['remove_all', True])).Free;
end;

function TTapoPlug.AddScheduleRule(const ARule: TTapoScheduleRule): TTapoScheduleRule;
var
  R: TJSONObject;
begin
  ARule.Validate;
  R := Execute('add_schedule_rule', ScheduleRuleToJSON(ARule, False));   // the device assigns the id
  try
    Result := ARule;
    Result.Id := JStr(R, 'id');
  finally
    R.Free;
  end;
end;

procedure TTapoPlug.EditScheduleRule(const ARule: TTapoScheduleRule);
begin
  if ARule.Id = '' then
    ValidationError('rule.id', 'EditScheduleRule needs the rule''s Id');
  ARule.Validate;
  Execute('edit_schedule_rule', ScheduleRuleToJSON(ARule, True)).Free;
end;

function TTapoPlug.GetScheduleRules: TArray<TTapoScheduleRule>;
var
  R: TJSONObject;
  A: TJSONArray;
  List: TList<TTapoScheduleRule>;
  Page, I, StartIndex, Fetched, Sum: Integer;
  Rule: TTapoScheduleRule;
begin
  List := TList<TTapoScheduleRule>.Create;
  try
    StartIndex := 0;
    Fetched := 0;
    for Page := 1 to MAX_SCHEDULE_PAGES do
    begin
      R := Execute('get_schedule_rules', JObject(['start_index', StartIndex]));
      try
        A := JArr(R, 'rule_list');
        if (A = nil) or (A.Count = 0) then
          Break;
        for I := 0 to A.Count - 1 do
          // a rule this class cannot represent is skipped, not fatal
          if (A.Items[I] is TJSONObject) and
             ScheduleRuleFromJSON(TJSONObject(A.Items[I]), Rule) then
            List.Add(Rule);
        Inc(Fetched, A.Count);
        Sum := Integer(JInt64(R, 'sum', 0));
        if Fetched >= Sum then
          Break;
        Inc(StartIndex, A.Count);
      finally
        R.Free;
      end;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TTapoPlug.GetMaxScheduleRules: Integer;
var
  R: TJSONObject;
begin
  R := Execute('get_schedule_rules', JObject(['start_index', 0]));
  try
    Result := Integer(JInt64(R, 'schedule_rule_max_count'));
  finally
    R.Free;
  end;
end;

procedure TTapoPlug.RemoveScheduleRule(const AId: string);
var
  List: TJSONArray;
begin
  List := TJSONArray.Create;
  List.AddElement(JObject(['id', AId]));
  Execute('remove_schedule_rules', JObject(['remove_all', False, 'rule_list', List])).Free;
end;

procedure TTapoPlug.RemoveAllScheduleRules;
begin
  Execute('remove_schedule_rules', JObject(['remove_all', True])).Free;
end;

{ ============================================================================ }
{ TTapoP110                                                                    }
{ ============================================================================ }

function TTapoP110.GetCurrentPower: Double;
begin
  Result := EPCurrentPower(Self);
end;

function TTapoP110.GetEnergyUsage: TTapoEnergyUsage;
begin
  Result := EPEnergyUsage(Self);
end;

function TTapoP110.GetEnergyDataHourly(AStartDate, AEndDate: TDate): TTapoEnergyData;
begin
  Result := EPEnergyHourly(Self, AStartDate, AEndDate);
end;

function TTapoP110.GetEnergyDataDaily(AQuarterStart: TDate): TTapoEnergyData;
begin
  Result := EPEnergyDaily(Self, AQuarterStart);
end;

function TTapoP110.GetEnergyDataMonthly(AYearStart: TDate): TTapoEnergyData;
begin
  Result := EPEnergyMonthly(Self, AYearStart);
end;

function TTapoP110.GetPowerData5Min(AStart, AEnd: TDateTime): TTapoPowerData;
begin
  Result := EPPowerData(Self, AStart, AEnd, 5);
end;

function TTapoP110.GetPowerDataHourly(AStart, AEnd: TDateTime): TTapoPowerData;
begin
  Result := EPPowerData(Self, AStart, AEnd, 60);
end;

{ ============================================================================ }
{ Lights                                                                       }
{ ============================================================================ }

procedure FillLightInfo(R: TJSONObject; out AInfo: TTapoLightInfo);
var
  D, B: TJSONObject;
begin
  AInfo.Info := TTapoDeviceInfo.FromJSON(R);
  AInfo.DeviceOn := JBool(R, 'device_on');
  AInfo.OnTime := JInt64(R, 'on_time');
  AInfo.Brightness := Integer(JInt64(R, 'brightness'));
  AInfo.Overheated := JBool(R, 'overheated');
  D := JObj(R, 'default_states');
  B := JObj(D, 'brightness');          // L510 layout
  AInfo.DefaultBrightnessType := JStr(B, 'type');
  AInfo.DefaultBrightness := Integer(JInt64(B, 'value'));
  AInfo.RePowerType := JStr(D, 're_power_type');
end;

procedure TTapoLight.SetBrightness(ABrightness: Integer);
begin
  if (ABrightness < 1) or (ABrightness > 100) then
    ValidationError('brightness', 'must be between 1 and 100');
  SetDeviceInfo(JObject(['brightness', ABrightness]));
end;

function TTapoLight.GetLightInfo: TTapoLightInfo;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    FillLightInfo(R, Result);
  finally
    R.Free;
  end;
end;

procedure TTapoColorLight.Apply(const AState: TTapoLightState);
begin
  SetDeviceInfo(AState.ToJSON);
end;

procedure TTapoColorLight.SetColor(AColor: TTapoColor);
begin
  Apply(TTapoLightState.New.WithColor(AColor));
end;

procedure TTapoColorLight.SetHueSaturation(AHue, ASaturation: Integer);
begin
  Apply(TTapoLightState.New.WithHueSaturation(AHue, ASaturation));
end;

procedure TTapoColorLight.SetColorTemperature(AKelvin: Integer);
begin
  Apply(TTapoLightState.New.WithColorTemperature(AKelvin));
end;

function TTapoColorLight.GetColorLightInfo: TTapoColorLightInfo;
var
  R, D, S, E: TJSONObject;
  Range: TJSONArray;
begin
  R := GetDeviceInfoObject;
  try
    FillLightInfo(R, Result.Light);
    Result.HasHueSaturation := JHas(R, 'hue') and JHas(R, 'saturation');
    Result.Hue := Integer(JInt64(R, 'hue'));
    Result.Saturation := Integer(JInt64(R, 'saturation'));
    Result.ColorTemp := Integer(JInt64(R, 'color_temp'));
    Range := JArr(R, 'color_temp_range');
    if (Range <> nil) and (Range.Count = 2) and (Range.Items[0] is TJSONNumber) and
       (Range.Items[1] is TJSONNumber) then
    begin
      Result.ColorTempMin := TJSONNumber(Range.Items[0]).AsInt;
      Result.ColorTempMax := TJSONNumber(Range.Items[1]).AsInt;
    end
    else
    begin
      Result.ColorTempMin := 2500;
      Result.ColorTempMax := 6500;
    end;
    Result.DynamicLightEffectEnable := JBool(R, 'dynamic_light_effect_enable');
    Result.DynamicLightEffectId := JStr(R, 'dynamic_light_effect_id');
    D := JObj(R, 'default_states');      // L530 / strip layout
    S := JObj(D, 'state');
    Result.DefaultStateType := JStr(D, 'type');
    Result.DefaultBrightness := Integer(JInt64(S, 'brightness'));
    Result.DefaultHue := Integer(JInt64(S, 'hue'));
    Result.DefaultSaturation := Integer(JInt64(S, 'saturation'));
    Result.DefaultColorTemp := Integer(JInt64(S, 'color_temp'));
    E := JObj(S, 'lighting_effect');
    if E <> nil then
      Result.DefaultLightingEffectJSON := E.ToJSON
    else
      Result.DefaultLightingEffectJSON := '';
  finally
    R.Free;
  end;
end;

{ ============================================================================ }
{ Light effects (L920 / L930)                                                  }
{ ============================================================================ }

function HSB(AHue, ASaturation, ABrightness: Integer): TTapoHSB;
begin
  Result.Hue := AHue;
  Result.Saturation := ASaturation;
  Result.Brightness := ABrightness;
end;

function HSBK(AHue, ASaturation, ABrightness, AKelvin: Integer): TTapoHSBK;
begin
  Result.Hue := AHue;
  Result.Saturation := ASaturation;
  Result.Brightness := ABrightness;
  Result.Kelvin := AKelvin;
end;

function IntArray(const A: array of Integer): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := Low(A) to High(A) do
    Result.Add(A[I]);
end;

function HSBArray(const A: array of TTapoHSB): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := Low(A) to High(A) do
    Result.AddElement(IntArray([A[I].Hue, A[I].Saturation, A[I].Brightness]));
end;

function HSBKArray(const A: array of TTapoHSBK): TJSONArray;
var
  I: Integer;
begin
  Result := TJSONArray.Create;
  for I := Low(A) to High(A) do
    Result.AddElement(IntArray([A[I].Hue, A[I].Saturation, A[I].Brightness, A[I].Kelvin]));
end;

// Replaces (or adds) AKey in a JSON object text. Takes ownership of AValue.
function PatchJSON(const AJson, AKey: string; AValue: TJSONValue): string;
var
  V: TJSONValue;
  O: TJSONObject;
begin
  V := TJSONObject.ParseJSONValue(AJson);
  if not (V is TJSONObject) then
  begin
    V.Free;
    AValue.Free;
    raise ETapoError.CreateCode(-1, 'Effect JSON is not an object');
  end;
  O := TJSONObject(V);
  try
    O.RemovePair(AKey).Free;
    O.AddPair(AKey, AValue);
    Result := O.ToJSON;
  finally
    O.Free;
  end;
end;

function NewEffectId: string;
begin
  Result := BytesToHex(SecureRandomBytes(16));   // like a UUID in simple form
end;

const
  LightingEffectTypeNames: array[TTapoLightingEffectType] of string =
    ('sequence', 'random', 'pulse', 'static');
  SegmentEffectTypeNames: array[TTapoSegmentEffectType] of string =
    ('circulating', 'breathe', 'chasing', 'flicker', 'bloom', 'stacking', 'none');

{ TTapoLightingEffect }

function TTapoLightingEffect.Patch(const AKey: string; AValue: TJSONValue): TTapoLightingEffect;
begin
  Result.FJson := PatchJSON(FJson, AKey, AValue);
end;

class function TTapoLightingEffect.New(const AName: string; AType: TTapoLightingEffectType;
  AIsCustom, AEnabled: Boolean; ABrightness: Integer;
  const ADisplayColors: array of TTapoHSB): TTapoLightingEffect;
var
  O: TJSONObject;
begin
  O := JObject(['brightness', ABrightness, 'custom', Ord(AIsCustom),
    'display_colors', HSBArray(ADisplayColors), 'enable', Ord(AEnabled),
    'id', NewEffectId, 'name', AName, 'type', LightingEffectTypeNames[AType]]);
  try
    Result.FJson := O.ToJSON;
  finally
    O.Free;
  end;
end;

class function TTapoLightingEffect.Preset(APreset: TTapoLightingEffectPreset): TTapoLightingEffect;
begin
  Result.FJson := LightingEffectPresetJSON(APreset);
end;

class function TTapoLightingEffect.FromJSON(const AJson: string): TTapoLightingEffect;
begin
  Result.FJson := AJson;
end;

function TTapoLightingEffect.WithBrightness(AValue: Integer): TTapoLightingEffect;
begin Result := Patch('brightness', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithIsCustom(AValue: Boolean): TTapoLightingEffect;
begin Result := Patch('custom', TJSONNumber.Create(Ord(AValue))); end;
function TTapoLightingEffect.WithEnabled(AValue: Boolean): TTapoLightingEffect;
begin Result := Patch('enable', TJSONNumber.Create(Ord(AValue))); end;
function TTapoLightingEffect.WithId(const AValue: string): TTapoLightingEffect;
begin Result := Patch('id', TJSONString.Create(AValue)); end;
function TTapoLightingEffect.WithName(const AValue: string): TTapoLightingEffect;
begin Result := Patch('name', TJSONString.Create(AValue)); end;
function TTapoLightingEffect.WithType(AValue: TTapoLightingEffectType): TTapoLightingEffect;
begin Result := Patch('type', TJSONString.Create(LightingEffectTypeNames[AValue])); end;
function TTapoLightingEffect.WithDisplayColors(const AValue: array of TTapoHSB): TTapoLightingEffect;
begin Result := Patch('display_colors', HSBArray(AValue)); end;
function TTapoLightingEffect.WithBackgrounds(const AValue: array of TTapoHSB): TTapoLightingEffect;
begin Result := Patch('backgrounds', HSBArray(AValue)); end;
function TTapoLightingEffect.WithBrightnessRange(AMin, AMax: Integer): TTapoLightingEffect;
begin Result := Patch('brightness_range', IntArray([AMin, AMax])); end;
function TTapoLightingEffect.WithDirection(AValue: Integer): TTapoLightingEffect;
begin Result := Patch('direction', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithDuration(AValue: Int64): TTapoLightingEffect;
begin Result := Patch('duration', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithExpansionStrategy(AValue: Integer): TTapoLightingEffect;
begin Result := Patch('expansion_strategy', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithFadeOff(AValue: Integer): TTapoLightingEffect;
begin Result := Patch('fadeoff', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithHueRange(AMin, AMax: Integer): TTapoLightingEffect;
begin Result := Patch('hue_range', IntArray([AMin, AMax])); end;
function TTapoLightingEffect.WithInitStates(const AValue: array of TTapoHSB): TTapoLightingEffect;
begin Result := Patch('init_states', HSBArray(AValue)); end;
function TTapoLightingEffect.WithRandomSeed(AValue: Int64): TTapoLightingEffect;
begin Result := Patch('random_seed', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithRepeatTimes(AValue: Integer): TTapoLightingEffect;
begin Result := Patch('repeat_times', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithRunTime(AValue: Int64): TTapoLightingEffect;
begin Result := Patch('run_time', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithSaturationRange(AMin, AMax: Integer): TTapoLightingEffect;
begin Result := Patch('saturation_range', IntArray([AMin, AMax])); end;
function TTapoLightingEffect.WithSegmentLength(AValue: Integer): TTapoLightingEffect;
begin Result := Patch('segment_length', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithSegments(const AValue: array of Integer): TTapoLightingEffect;
begin Result := Patch('segments', IntArray(AValue)); end;
function TTapoLightingEffect.WithSequence(const AValue: array of TTapoHSB): TTapoLightingEffect;
begin Result := Patch('sequence', HSBArray(AValue)); end;
function TTapoLightingEffect.WithSpread(AValue: Integer): TTapoLightingEffect;
begin Result := Patch('spread', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithTransition(AValue: Integer): TTapoLightingEffect;
begin Result := Patch('transition', TJSONNumber.Create(AValue)); end;
function TTapoLightingEffect.WithTransitionRange(AMin, AMax: Integer): TTapoLightingEffect;
begin Result := Patch('transition_range', IntArray([AMin, AMax])); end;
function TTapoLightingEffect.WithTransitionSequence(const AValue: array of Integer): TTapoLightingEffect;
begin Result := Patch('trans_sequence', IntArray(AValue)); end;

function TTapoLightingEffect.ToJSON: string;
begin
  if FJson = '' then
    ValidationError('lighting effect', 'empty - start from New, Preset or FromJSON');
  Result := FJson;
end;

{ TTapoSegmentEffect }

function TTapoSegmentEffect.Patch(const AKey: string; AValue: TJSONValue): TTapoSegmentEffect;
begin
  Result.FJson := PatchJSON(FJson, AKey, AValue);
end;

class function TTapoSegmentEffect.New(const AName: string; AType: TTapoSegmentEffectType;
  AIsCustom, AEnabled: Boolean; ABrightness: Integer;
  const ADisplayColors: array of TTapoHSBK): TTapoSegmentEffect;
var
  O: TJSONObject;
begin
  O := JObject(['brightness', ABrightness, 'custom', Ord(AIsCustom),
    'display_colors', HSBKArray(ADisplayColors), 'enable', Ord(AEnabled),
    'id', NewEffectId, 'name', AName, 'type', SegmentEffectTypeNames[AType]]);
  try
    if AIsCustom then
      O.AddPair('deviceType', 'strip');
    Result.FJson := O.ToJSON;
  finally
    O.Free;
  end;
end;

class function TTapoSegmentEffect.Preset(APreset: TTapoSegmentEffectPreset): TTapoSegmentEffect;
begin
  Result.FJson := SegmentEffectPresetJSON(APreset);
end;

class function TTapoSegmentEffect.FromJSON(const AJson: string): TTapoSegmentEffect;
begin
  Result.FJson := AJson;
end;

function TTapoSegmentEffect.WithBrightness(AValue: Integer): TTapoSegmentEffect;
begin Result := Patch('brightness', TJSONNumber.Create(AValue)); end;
function TTapoSegmentEffect.WithIsCustom(AValue: Boolean): TTapoSegmentEffect;
begin Result := Patch('custom', TJSONNumber.Create(Ord(AValue))); end;
function TTapoSegmentEffect.WithEnabled(AValue: Boolean): TTapoSegmentEffect;
begin Result := Patch('enable', TJSONNumber.Create(Ord(AValue))); end;
function TTapoSegmentEffect.WithId(const AValue: string): TTapoSegmentEffect;
begin Result := Patch('id', TJSONString.Create(AValue)); end;
function TTapoSegmentEffect.WithName(const AValue: string): TTapoSegmentEffect;
begin Result := Patch('name', TJSONString.Create(AValue)); end;
function TTapoSegmentEffect.WithType(AValue: TTapoSegmentEffectType): TTapoSegmentEffect;
begin Result := Patch('type', TJSONString.Create(SegmentEffectTypeNames[AValue])); end;
function TTapoSegmentEffect.WithDeviceType(const AValue: string): TTapoSegmentEffect;
begin Result := Patch('deviceType', TJSONString.Create(AValue)); end;
function TTapoSegmentEffect.WithDisplayColors(const AValue: array of TTapoHSBK): TTapoSegmentEffect;
begin Result := Patch('display_colors', HSBKArray(AValue)); end;
function TTapoSegmentEffect.WithSegments(const AValue: array of Integer): TTapoSegmentEffect;
begin Result := Patch('segments', IntArray(AValue)); end;
function TTapoSegmentEffect.WithStates(const AValue: array of TTapoHSBK): TTapoSegmentEffect;
begin Result := Patch('states', HSBKArray(AValue)); end;

procedure TTapoSegmentEffect.Validate;
var
  V: TJSONValue;
  O: TJSONObject;
  A: TJSONArray;
begin
  if FJson = '' then
    ValidationError('segment effect', 'empty - start from New, Preset or FromJSON');
  V := TJSONObject.ParseJSONValue(FJson);
  try
    if not (V is TJSONObject) then
      ValidationError('segment effect', 'not a JSON object');
    O := TJSONObject(V);
    if JBool(O, 'custom') then
    begin
      A := JArr(O, 'segments');
      if (A = nil) or (A.Count = 0) then
        ValidationError('segments', 'required for custom segment effects');
      A := JArr(O, 'states');
      if (A = nil) or (A.Count = 0) then
        ValidationError('states', 'required for custom segment effects');
      if not JHas(O, 'type') then
        ValidationError('type', 'required for custom segment effects');
    end;
  finally
    V.Free;
  end;
end;

function TTapoSegmentEffect.ToJSON: string;
begin
  Validate;
  Result := FJson;
end;

function ParseEffect(const AJson: string): TJSONObject;
var
  V: TJSONValue;
begin
  V := TJSONObject.ParseJSONValue(AJson);
  if not (V is TJSONObject) then
  begin
    V.Free;
    raise ETapoError.CreateCode(-1, 'Effect JSON is not an object');
  end;
  Result := TJSONObject(V);
end;

procedure TTapoL920.SetLightingEffect(APreset: TTapoLightingEffectPreset);
begin
  SetLightingEffect(TTapoLightingEffect.Preset(APreset));
end;

procedure TTapoL920.SetLightingEffect(const AEffect: TTapoLightingEffect);
begin
  ExecuteStamped('set_lighting_effect', ParseEffect(AEffect.ToJSON)).Free;
end;

procedure TTapoL920.SetSegmentEffect(APreset: TTapoSegmentEffectPreset);
begin
  SetSegmentEffect(TTapoSegmentEffect.Preset(APreset));
end;

procedure TTapoL920.SetSegmentEffect(const AEffect: TTapoSegmentEffect);
begin
  ExecuteStamped('apply_segment_effect_rule', ParseEffect(AEffect.ToJSON)).Free;
end;

{ ============================================================================ }
{ Power strips                                                                 }
{ ============================================================================ }

function OutletInfoFromJSON(Obj: TJSONObject): TTapoOutletInfo;
begin
  Result.DeviceId := JStr(Obj, 'device_id');
  Result.OriginalDeviceId := JStr(Obj, 'original_device_id');
  Result.Nickname := JBase64Str(Obj, 'nickname');
  Result.Model := JStr(Obj, 'model');
  Result.DeviceType := JStr(Obj, 'type');
  Result.Category := JStr(Obj, 'category');
  Result.FirmwareVersion := JStr(Obj, 'fw_ver');
  Result.HardwareVersion := JStr(Obj, 'hw_ver');
  Result.Mac := JStr(Obj, 'mac');
  Result.Position := Integer(JInt64(Obj, 'position'));
  Result.SlotNumber := Integer(JInt64(Obj, 'slot_number'));
  Result.IsUsb := JBool(Obj, 'is_usb');
  Result.DeviceOn := JBool(Obj, 'device_on');
  Result.OnTime := JInt64(Obj, 'on_time');
  Result.AutoOffStatus := JStr(Obj, 'auto_off_status');
  Result.AutoOffRemainTime := JInt64(Obj, 'auto_off_remain_time');
  Result.BindCount := Integer(JInt64(Obj, 'bind_count'));
  Result.StatusFollowEdge := JBool(Obj, 'status_follow_edge');
  Result.OvercurrentStatus := StatusStr(Obj, 'overcurrent_status');
  Result.OverheatStatus := StatusStr(Obj, 'overheat_status');
  Result.PowerProtectionStatus := StatusStr(Obj, 'power_protection_status');
  Result.ChargingStatus := StatusStr(Obj, 'charging_status');
  PlugDefaultState(Obj, Result.DefaultStateType, Result.DefaultOn);
  if Obj <> nil then
    Result.Raw := Obj.Format
  else
    Result.Raw := '';
end;

{ TTapoPowerStripOutlet }

procedure TTapoPowerStripOutlet.TurnOn;
begin
  EPSetOn(Self, True);
end;

procedure TTapoPowerStripOutlet.TurnOff;
begin
  EPSetOn(Self, False);
end;

procedure TTapoPowerStripOutlet.SetOn(AOn: Boolean);
begin
  EPSetOn(Self, AOn);
end;

function TTapoPowerStripOutlet.IsOn: Boolean;
begin
  Result := EPIsOn(Self);
end;

function TTapoPowerStripOutlet.GetOutletInfo: TTapoOutletInfo;
var
  R: TJSONObject;
begin
  R := GetDeviceInfoObject;
  try
    Result := OutletInfoFromJSON(R);
  finally
    R.Free;
  end;
end;

{ TTapoEnergyOutlet }

function TTapoEnergyOutlet.GetDeviceUsage: TTapoDeviceUsage;
begin
  Result := EPDeviceUsage(Self);
end;

function TTapoEnergyOutlet.GetCurrentPower: Double;
begin
  Result := EPCurrentPower(Self);
end;

function TTapoEnergyOutlet.GetEnergyUsage: TTapoEnergyUsage;
begin
  Result := EPEnergyUsage(Self);
end;

function TTapoEnergyOutlet.GetEnergyDataHourly(AStartDate, AEndDate: TDate): TTapoEnergyData;
begin
  Result := EPEnergyHourly(Self, AStartDate, AEndDate);
end;

function TTapoEnergyOutlet.GetEnergyDataDaily(AQuarterStart: TDate): TTapoEnergyData;
begin
  Result := EPEnergyDaily(Self, AQuarterStart);
end;

function TTapoEnergyOutlet.GetEnergyDataMonthly(AYearStart: TDate): TTapoEnergyData;
begin
  Result := EPEnergyMonthly(Self, AYearStart);
end;

function TTapoEnergyOutlet.GetPowerData5Min(AStart, AEnd: TDateTime): TTapoPowerData;
begin
  Result := EPPowerData(Self, AStart, AEnd, 5);
end;

function TTapoEnergyOutlet.GetPowerDataHourly(AStart, AEnd: TDateTime): TTapoPowerData;
begin
  Result := EPPowerData(Self, AStart, AEnd, 60);
end;

{ TTapoPowerStrip }

class function TTapoPowerStrip.OutletClass: TTapoChildDeviceClass;
begin
  Result := TTapoPowerStripOutlet;
end;

function TTapoPowerStrip.GetChildDeviceList: TArray<TTapoOutletInfo>;
var
  R: TJSONObject;
  A: TJSONArray;
  List: TList<TTapoOutletInfo>;
  Page, I, StartIndex, Sum: Integer;
begin
  List := TList<TTapoOutletInfo>.Create;
  try
    StartIndex := 0;
    for Page := 1 to MAX_CHILD_PAGES do
    begin
      R := Execute('get_child_device_list', JObject(['start_index', StartIndex]));
      try
        A := JArr(R, 'child_device_list');
        if (A = nil) or (A.Count = 0) then
          Break;
        for I := 0 to A.Count - 1 do
          if A.Items[I] is TJSONObject then
            List.Add(OutletInfoFromJSON(TJSONObject(A.Items[I])));
        Inc(StartIndex, A.Count);
        Sum := Integer(JInt64(R, 'sum', 0));
        if StartIndex >= Sum then
          Break;
      finally
        R.Free;
      end;
    end;
    List.Sort(TComparer<TTapoOutletInfo>.Construct(
      function(const Left, Right: TTapoOutletInfo): Integer
      begin
        Result := Left.Position - Right.Position;
      end));
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TTapoPowerStrip.GetChildDeviceListJSON: string;
var
  R: TJSONObject;
begin
  R := Execute('get_child_device_list', JObject(['start_index', 0]));
  try
    Result := R.Format;
  finally
    R.Free;
  end;
end;

function TTapoPowerStrip.GetChildDeviceComponentListJSON: string;
var
  R: TJSONObject;
begin
  R := Execute('get_child_device_component_list');
  try
    Result := R.Format;
  finally
    R.Free;
  end;
end;

function TTapoPowerStrip.Outlet(APosition: Integer): TTapoPowerStripOutlet;
var
  Info: TTapoOutletInfo;
begin
  for Info in GetChildDeviceList do
    if Info.Position = APosition then
      Exit(ChildFor(Info.DeviceId, OutletClass) as TTapoPowerStripOutlet);
  raise ETapoError.CreateCode(-1, Format('%s has no socket at position %d', [Host, APosition]));
end;

function TTapoPowerStrip.OutletByNickname(const ANickname: string): TTapoPowerStripOutlet;
var
  Info: TTapoOutletInfo;
begin
  for Info in GetChildDeviceList do
    if SameText(Info.Nickname, ANickname) then
      Exit(ChildFor(Info.DeviceId, OutletClass) as TTapoPowerStripOutlet);
  raise ETapoError.CreateCode(-1, Format('%s has no socket named "%s"', [Host, ANickname]));
end;

function TTapoPowerStrip.OutletById(const ADeviceId: string): TTapoPowerStripOutlet;
var
  Info: TTapoOutletInfo;
begin
  for Info in GetChildDeviceList do
    if Info.DeviceId = ADeviceId then
      Exit(ChildFor(Info.DeviceId, OutletClass) as TTapoPowerStripOutlet);
  raise ETapoError.CreateCode(-1, Format('%s has no socket with id %s', [Host, ADeviceId]));
end;

function TTapoPowerStrip.Outlets: TArray<TTapoPowerStripOutlet>;
var
  Infos: TArray<TTapoOutletInfo>;
  I: Integer;
begin
  Infos := GetChildDeviceList;
  SetLength(Result, Length(Infos));
  for I := 0 to High(Infos) do
    Result[I] := ChildFor(Infos[I].DeviceId, OutletClass) as TTapoPowerStripOutlet;
end;

{ TTapoP304M }

class function TTapoP304M.OutletClass: TTapoChildDeviceClass;
begin
  Result := TTapoEnergyOutlet;
end;

function TTapoP304M.Outlet(APosition: Integer): TTapoEnergyOutlet;
begin
  Result := inherited Outlet(APosition) as TTapoEnergyOutlet;
end;

function TTapoP304M.OutletByNickname(const ANickname: string): TTapoEnergyOutlet;
begin
  Result := inherited OutletByNickname(ANickname) as TTapoEnergyOutlet;
end;

function TTapoP304M.OutletById(const ADeviceId: string): TTapoEnergyOutlet;
begin
  Result := inherited OutletById(ADeviceId) as TTapoEnergyOutlet;
end;

function TTapoP304M.Outlets: TArray<TTapoEnergyOutlet>;
var
  Base: TArray<TTapoPowerStripOutlet>;
  I: Integer;
begin
  Base := inherited Outlets;
  SetLength(Result, Length(Base));
  for I := 0 to High(Base) do
    Result[I] := Base[I] as TTapoEnergyOutlet;
end;

end.
