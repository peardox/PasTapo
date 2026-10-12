unit Tapo.LightEffects;

{
  Lighting-effect (L920/L930) and segment-effect presets of the Tapo app,
  as the JSON that set_lighting_effect / apply_segment_effect_rule take.

  GENERATED from tapo/src/requests/set_device_info/lighting_effect.rs and
  segment_effect.rs of https://github.com/mihai-dinculescu/tapo - do not edit.
}

interface

type
  (***
    The lighting-effect presets of the Tapo app, for the L920 and L930 light strips.

    @seealso(TTapoL920.SetLightingEffect)
  *)
  /// <summary>The lighting-effect presets of the Tapo app, for the L920 and L930 light strips.</summary>
  /// <seealso cref="Tapo.Devices|TTapoL920.SetLightingEffect"/>
  TTapoLightingEffectPreset = (
    (*** The 'Aurora' preset. *)
    /// <summary>The 'Aurora' preset.</summary>
    lepAurora,
    (*** The 'Bubbling Cauldron' preset. *)
    /// <summary>The 'Bubbling Cauldron' preset.</summary>
    lepBubblingCauldron,
    (*** The 'Candy Cane' preset. *)
    /// <summary>The 'Candy Cane' preset.</summary>
    lepCandyCane,
    (*** The 'Christmas' preset. *)
    /// <summary>The 'Christmas' preset.</summary>
    lepChristmas,
    (*** The 'Flicker' preset. *)
    /// <summary>The 'Flicker' preset.</summary>
    lepFlicker,
    (*** The 'Grandma's Christmas Lights' preset. *)
    /// <summary>The 'Grandma's Christmas Lights' preset.</summary>
    lepGrandmasChristmasLights,
    (*** The 'Hanukkah' preset. *)
    /// <summary>The 'Hanukkah' preset.</summary>
    lepHanukkah,
    (*** The 'Haunted Mansion' preset. *)
    /// <summary>The 'Haunted Mansion' preset.</summary>
    lepHauntedMansion,
    (*** The 'Icicle' preset. *)
    /// <summary>The 'Icicle' preset.</summary>
    lepIcicle,
    (*** The 'Lightning' preset. *)
    /// <summary>The 'Lightning' preset.</summary>
    lepLightning,
    (*** The 'Ocean' preset. *)
    /// <summary>The 'Ocean' preset.</summary>
    lepOcean,
    (*** The 'Rainbow' preset. *)
    /// <summary>The 'Rainbow' preset.</summary>
    lepRainbow,
    (*** The 'Raindrop' preset. *)
    /// <summary>The 'Raindrop' preset.</summary>
    lepRaindrop,
    (*** The 'Spring' preset. *)
    /// <summary>The 'Spring' preset.</summary>
    lepSpring,
    (*** The 'Sunrise' preset. *)
    /// <summary>The 'Sunrise' preset.</summary>
    lepSunrise,
    (*** The 'Sunset' preset. *)
    /// <summary>The 'Sunset' preset.</summary>
    lepSunset,
    (*** The 'Valentines' preset. *)
    /// <summary>The 'Valentines' preset.</summary>
    lepValentines);

  (***
    The segment-effect presets of the Tapo app, for the L920 and L930 light strips.

    @seealso(TTapoL920.SetSegmentEffect)
  *)
  /// <summary>The segment-effect presets of the Tapo app, for the L920 and L930 light strips.</summary>
  /// <seealso cref="Tapo.Devices|TTapoL920.SetSegmentEffect"/>
  TTapoSegmentEffectPreset = (
    (*** The 'birthday' preset. *)
    /// <summary>The 'birthday' preset.</summary>
    sepBirthday,
    (*** The 'blue' preset. *)
    /// <summary>The 'blue' preset.</summary>
    sepBlue,
    (*** The 'bonfire' preset. *)
    /// <summary>The 'bonfire' preset.</summary>
    sepBonfire,
    (*** The 'candlelight' preset. *)
    /// <summary>The 'candlelight' preset.</summary>
    sepCandlelight,
    (*** The 'carnival' preset. *)
    /// <summary>The 'carnival' preset.</summary>
    sepCarnival,
    (*** The 'cyan' preset. *)
    /// <summary>The 'cyan' preset.</summary>
    sepCyan,
    (*** The 'dancing' preset. *)
    /// <summary>The 'dancing' preset.</summary>
    sepDancing,
    (*** The 'dating' preset. *)
    /// <summary>The 'dating' preset.</summary>
    sepDating,
    (*** The 'disco' preset. *)
    /// <summary>The 'disco' preset.</summary>
    sepDisco,
    (*** The 'dreamland' preset. *)
    /// <summary>The 'dreamland' preset.</summary>
    sepDreamland,
    (*** The 'electro_dance' preset. *)
    /// <summary>The 'electro_dance' preset.</summary>
    sepElectroDance,
    (*** The 'energetic' preset. *)
    /// <summary>The 'energetic' preset.</summary>
    sepEnergetic,
    (*** The 'excited' preset. *)
    /// <summary>The 'excited' preset.</summary>
    sepExcited,
    (*** The 'fall' preset. *)
    /// <summary>The 'fall' preset.</summary>
    sepFall,
    (*** The 'family' preset. *)
    /// <summary>The 'family' preset.</summary>
    sepFamily,
    (*** The 'fireworks' preset. *)
    /// <summary>The 'fireworks' preset.</summary>
    sepFireworks,
    (*** The 'flower_field' preset. *)
    /// <summary>The 'flower_field' preset.</summary>
    sepFlowerField,
    (*** The 'forest' preset. *)
    /// <summary>The 'forest' preset.</summary>
    sepForest,
    (*** The 'game' preset. *)
    /// <summary>The 'game' preset.</summary>
    sepGame,
    (*** The 'green' preset. *)
    /// <summary>The 'green' preset.</summary>
    sepGreen,
    (*** The 'halloween' preset. *)
    /// <summary>The 'halloween' preset.</summary>
    sepHalloween,
    (*** The 'happy' preset. *)
    /// <summary>The 'happy' preset.</summary>
    sepHappy,
    (*** The 'jazz' preset. *)
    /// <summary>The 'jazz' preset.</summary>
    sepJazz,
    (*** The 'lake' preset. *)
    /// <summary>The 'lake' preset.</summary>
    sepLake,
    (*** The 'light_green' preset. *)
    /// <summary>The 'light_green' preset.</summary>
    sepLightGreen,
    (*** The 'lyric' preset. *)
    /// <summary>The 'lyric' preset.</summary>
    sepLyric,
    (*** The 'moonlight' preset. *)
    /// <summary>The 'moonlight' preset.</summary>
    sepMoonlight,
    (*** The 'morning' preset. *)
    /// <summary>The 'morning' preset.</summary>
    sepMorning,
    (*** The 'movie' preset. *)
    /// <summary>The 'movie' preset.</summary>
    sepMovie,
    (*** The 'new_year' preset. *)
    /// <summary>The 'new_year' preset.</summary>
    sepNewYear,
    (*** The 'night' preset. *)
    /// <summary>The 'night' preset.</summary>
    sepNight,
    (*** The 'orange' preset. *)
    /// <summary>The 'orange' preset.</summary>
    sepOrange,
    (*** The 'pink' preset. *)
    /// <summary>The 'pink' preset.</summary>
    sepPink,
    (*** The 'purple' preset. *)
    /// <summary>The 'purple' preset.</summary>
    sepPurple,
    (*** The 'quiet' preset. *)
    /// <summary>The 'quiet' preset.</summary>
    sepQuiet,
    (*** The 'red' preset. *)
    /// <summary>The 'red' preset.</summary>
    sepRed,
    (*** The 'relaxed' preset. *)
    /// <summary>The 'relaxed' preset.</summary>
    sepRelaxed,
    (*** The 'rock' preset. *)
    /// <summary>The 'rock' preset.</summary>
    sepRock,
    (*** The 'siren' preset. *)
    /// <summary>The 'siren' preset.</summary>
    sepSiren,
    (*** The 'sleep' preset. *)
    /// <summary>The 'sleep' preset.</summary>
    sepSleep,
    (*** The 'snow' preset. *)
    /// <summary>The 'snow' preset.</summary>
    sepSnow,
    (*** The 'star' preset. *)
    /// <summary>The 'star' preset.</summary>
    sepStar,
    (*** The 'study' preset. *)
    /// <summary>The 'study' preset.</summary>
    sepStudy,
    (*** The 'summer' preset. *)
    /// <summary>The 'summer' preset.</summary>
    sepSummer,
    (*** The 'sunny' preset. *)
    /// <summary>The 'sunny' preset.</summary>
    sepSunny,
    (*** The 'sweet' preset. *)
    /// <summary>The 'sweet' preset.</summary>
    sepSweet,
    (*** The 'tense' preset. *)
    /// <summary>The 'tense' preset.</summary>
    sepTense,
    (*** The 'thinking' preset. *)
    /// <summary>The 'thinking' preset.</summary>
    sepThinking,
    (*** The 'universe' preset. *)
    /// <summary>The 'universe' preset.</summary>
    sepUniverse,
    (*** The 'volcano' preset. *)
    /// <summary>The 'volcano' preset.</summary>
    sepVolcano,
    (*** The 'warm' preset. *)
    /// <summary>The 'warm' preset.</summary>
    sepWarm,
    (*** The 'white' preset. *)
    /// <summary>The 'white' preset.</summary>
    sepWhite,
    (*** The 'winter' preset. *)
    /// <summary>The 'winter' preset.</summary>
    sepWinter,
    (*** The 'work' preset. *)
    /// <summary>The 'work' preset.</summary>
    sepWork,
    (*** The 'yellow' preset. *)
    /// <summary>The 'yellow' preset.</summary>
    sepYellow);

(***
  The JSON the strip takes for a lighting-effect preset.

  @param(APreset The preset.)

  @returns(A JSON object as text, for set_lighting_effect.)
*)
/// <summary>The JSON the strip takes for a lighting-effect preset.</summary>
/// <param name="APreset">The preset.</param>
/// <returns>A JSON object as text, for set_lighting_effect.</returns>
function LightingEffectPresetJSON(APreset: TTapoLightingEffectPreset): string;
(***
  The JSON the strip takes for a segment-effect preset.

  @param(APreset The preset.)

  @returns(A JSON object as text, for apply_segment_effect_rule.)
*)
/// <summary>The JSON the strip takes for a segment-effect preset.</summary>
/// <param name="APreset">The preset.</param>
/// <returns>A JSON object as text, for apply_segment_effect_rule.</returns>
function SegmentEffectPresetJSON(APreset: TTapoSegmentEffectPreset): string;

implementation

const
  LightingEffectPresets: array[TTapoLightingEffectPreset] of string = (
    // Aurora
    '{"brightness":100,"custom":0,"display_colors":[[120,100,100],[240,100,100],[260,100,100],[280,100,100]],"enable":1,"id":"TapoStrip_1MClvV18i15Jq3bvJVf0eP","name":"Aurora","type":"sequence","direction"' +
      ':4,"duration":0,"expansion_strategy":1,"repeat_times":0,"segments":[0],"sequence":[[120,100,100],[240,100,100],[260,100,100],[280,100,100]],"spread":7,"transition":1500}',
    // BubblingCauldron
    '{"brightness":100,"custom":0,"display_colors":[[100,100,100],[270,100,100]],"enable":1,"id":"TapoStrip_6DlumDwO2NdfHppy50vJtu","name":"Bubbling Cauldron","type":"random","backgrounds":[[270,40,50]],"b' +
      'rightness_range":[50,100],"init_states":[[270,100,100]],"duration":0,"expansion_strategy":1,"fadeoff":1000,"hue_range":[100,270],"random_seed":24,"saturation_range":[80,100],"segments":[0],"transition' +
      '":200}',
    // CandyCane
    '{"brightness":100,"custom":0,"display_colors":[[0,0,100],[360,81,100]],"enable":1,"id":"TapoStrip_6Dy0Nc45vlhFPEzG021Pe9","name":"Candy Cane","type":"sequence","direction":1,"duration":700,"expansion_' +
      'strategy":1,"repeat_times":0,"segments":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],"sequence":[[0,0,100],[0,0,100],[360,81,100],[0,0,100],[0,0,100],[360,81,100],[360,81,100],[0,0,100],[0,0,100],[360,81,1' +
      '00],[360,81,100],[360,81,100],[360,81,100],[0,0,100],[0,0,100],[360,81,100]],"spread":1,"transition":500}',
    // Christmas
    '{"brightness":100,"custom":0,"display_colors":[[136,98,100],[350,97,100]],"enable":1,"id":"TapoStrip_5zkiG6avJ1IbhjiZbRlWvh","name":"Christmas","type":"random","backgrounds":[[136,98,75],[136,0,0],[35' +
      '0,0,100],[350,97,94]],"brightness_range":[50,100],"init_states":[[136,0,100]],"duration":5000,"expansion_strategy":1,"fadeoff":2000,"hue_range":[136,146],"random_seed":100,"saturation_range":[90,100],' +
      '"segments":[0],"transition":0}',
    // Flicker
    '{"brightness":100,"custom":0,"display_colors":[[30,81,100],[40,100,100]],"enable":1,"id":"TapoStrip_4HVKmMc6vEzjm36jXaGwMs","name":"Flicker","type":"random","brightness_range":[50,100],"init_states":[' +
      '[30,81,80]],"duration":0,"expansion_strategy":1,"hue_range":[30,40],"saturation_range":[100,100],"segments":[1],"transition":0,"transition_range":[375,500]}',
    // GrandmasChristmasLights
    '{"brightness":100,"custom":0,"display_colors":[[30,100,100],[240,100,100],[130,100,100],[0,100,100]],"enable":1,"id":"TapoStrip_3Gk6CmXOXbjCiwz9iD543C","name":"Grandma''s Christmas Lights","type":"sequ' +
      'ence","direction":1,"duration":5000,"expansion_strategy":1,"repeat_times":0,"segments":[0],"sequence":[[30,100,100],[30,0,0],[30,0,0],[240,100,100],[240,0,0],[240,0,0],[240,0,100],[240,0,0],[240,0,0],' +
      '[130,100,100],[130,0,0],[130,0,0],[0,100,100],[0,0,0],[0,0,0]],"spread":1,"transition":100}',
    // Hanukkah
    '{"brightness":100,"custom":0,"display_colors":[[200,100,100]],"enable":1,"id":"TapoStrip_2YTk4wramLKv5XZ9KFDVYm","name":"Hanukkah","type":"random","brightness_range":[50,100],"init_states":[[35,81,80]' +
      '],"duration":1500,"expansion_strategy":1,"hue_range":[200,210],"saturation_range":[0,100],"segments":[1],"transition":0,"transition_range":[400,500]}',
    // HauntedMansion
    '{"brightness":100,"custom":0,"display_colors":[[45,10,100]],"enable":1,"id":"TapoStrip_4rJ6JwC7I9st3tQ8j4lwlI","name":"Haunted Mansion","type":"random","backgrounds":[[45,10,100]],"brightness_range":[' +
      '0,80],"init_states":[[45,10,100]],"duration":0,"expansion_strategy":2,"fadeoff":200,"hue_range":[45,45],"random_seed":1,"saturation_range":[10,10],"segments":[80],"transition":0,"transition_range":[50' +
      ',1500]}',
    // Icicle
    '{"brightness":100,"custom":0,"display_colors":[[190,100,100]],"enable":1,"id":"TapoStrip_7UcYLeJbiaxVIXCxr21tpx","name":"Icicle","type":"sequence","direction":4,"duration":0,"expansion_strategy":1,"re' +
      'peat_times":0,"segments":[0],"sequence":[[190,100,70],[190,100,70],[190,30,50],[190,100,70],[190,100,70]],"spread":3,"transition":400}',
    // Lightning
    '{"brightness":100,"custom":0,"display_colors":[[210,10,100],[200,50,100],[200,100,100]],"enable":1,"id":"TapoStrip_7OGzfSfnOdhoO2ri4gOHWn","name":"Lightning","type":"random","backgrounds":[[200,100,10' +
      '0],[200,50,10],[210,10,50],[240,10,0]],"brightness_range":[90,100],"init_states":[[240,30,100]],"duration":0,"expansion_strategy":1,"fadeoff":150,"hue_range":[240,240],"random_seed":600,"saturation_ra' +
      'nge":[10,11],"segments":[7,20,23,32,34,35,49,65,66,74,80],"transition":50}',
    // Ocean
    '{"brightness":100,"custom":0,"display_colors":[[198,84,100]],"enable":1,"id":"TapoStrip_0fOleCdwSgR0nfjkReeYfw","name":"Ocean","type":"sequence","direction":3,"duration":0,"expansion_strategy":1,"repe' +
      'at_times":0,"segments":[0],"sequence":[[198,84,30],[198,70,30],[198,10,30]],"spread":16,"transition":2000}',
    // Rainbow
    '{"brightness":100,"custom":0,"display_colors":[[0,100,100],[100,100,100],[200,100,100],[300,100,100]],"enable":1,"id":"TapoStrip_7CC5y4lsL8pETYvmz7UOpQ","name":"Rainbow","type":"sequence","direction":' +
      '1,"duration":0,"expansion_strategy":1,"repeat_times":0,"segments":[0],"sequence":[[0,100,100],[100,100,100],[200,100,100],[300,100,100]],"spread":12,"transition":1500}',
    // Raindrop
    '{"brightness":100,"custom":0,"display_colors":[[200,10,100],[200,20,100]],"enable":1,"id":"TapoStrip_1t2nWlTBkV8KXBZ0TWvBjs","name":"Raindrop","type":"random","backgrounds":[[200,40,0]],"brightness_ra' +
      'nge":[10,30],"init_states":[[200,40,100]],"duration":0,"expansion_strategy":1,"fadeoff":1000,"hue_range":[200,200],"random_seed":24,"saturation_range":[10,20],"segments":[0],"transition":1000}',
    // Spring
    '{"brightness":100,"custom":0,"display_colors":[[0,30,100],[130,100,100]],"enable":1,"id":"TapoStrip_1nL6GqZ5soOxj71YDJOlZL","name":"Spring","type":"random","backgrounds":[[130,100,40]],"brightness_ran' +
      'ge":[90,100],"init_states":[[80,30,100]],"duration":600,"expansion_strategy":1,"fadeoff":1000,"hue_range":[0,90],"random_seed":20,"saturation_range":[30,100],"segments":[0],"transition":0,"transition_' +
      'range":[2000,6000]}',
    // Sunrise
    '{"brightness":100,"custom":0,"display_colors":[[30,0,100],[30,95,100],[0,100,100]],"enable":1,"id":"TapoStrip_1OVSyXIsDxrt4j7OxyRvqi","name":"Sunrise","type":"pulse","direction":1,"duration":600,"expa' +
      'nsion_strategy":2,"repeat_times":1,"segments":[0],"sequence":[[0,100,5],[0,100,5],[10,100,6],[15,100,7],[20,100,8],[20,100,10],[30,100,12],[30,95,15],[30,90,20],[30,80,25],[30,75,30],[30,70,40],[30,60' +
      ',50],[30,50,60],[30,20,70],[30,0,100]],"spread":1,"transition":60000,"run_time":0}',
    // Sunset
    '{"brightness":100,"custom":0,"display_colors":[[0,100,100],[30,95,100],[30,0,100]],"enable":1,"id":"TapoStrip_5NiN0Y8GAUD78p4neKk9EL","name":"Sunset","type":"pulse","direction":1,"duration":600,"expan' +
      'sion_strategy":2,"repeat_times":1,"segments":[0],"sequence":[[30,0,100],[30,20,100],[30,50,99],[30,60,98],[30,70,97],[30,75,95],[30,80,93],[30,90,90],[30,95,85],[30,100,80],[20,100,70],[20,100,60],[15' +
      ',100,50],[10,100,40],[0,100,30],[0,100,0]],"spread":1,"transition":60000,"run_time":0}',
    // Valentines
    '{"brightness":100,"custom":0,"display_colors":[[340,20,100],[20,50,100],[0,100,100],[340,40,100]],"enable":1,"id":"TapoStrip_2q1Vio9sSjHmaC7JS9d30l","name":"Valentines","type":"random","backgrounds":[' +
      '[340,20,50],[20,50,50],[0,100,50]],"brightness_range":[90,100],"init_states":[[340,30,100]],"duration":600,"expansion_strategy":1,"fadeoff":3000,"hue_range":[340,340],"random_seed":100,"saturation_ran' +
      'ge":[30,40],"segments":[0],"transition":2000}'
  );

  SegmentEffectPresets: array[TTapoSegmentEffectPreset] of string = (
    // Birthday
    '{"brightness":50,"custom":0,"display_colors":[[0,87,100,0],[298,58,100,0],[182,94,100,0],[135,80,100,0]],"enable":1,"id":"TapoStrip_6UV91PSxvC1LRPXIibdcuJ","name":"birthday"}',
    // Blue
    '{"brightness":50,"custom":0,"display_colors":[[202,42,100,0]],"enable":1,"id":"TapoStrip_3d5ofcJ90anniQnMTjzUqb","name":"blue"}',
    // Bonfire
    '{"brightness":50,"custom":0,"display_colors":[[39,86,100,0],[30,14,100,0],[20,87,100,0]],"enable":1,"id":"TapoStrip_4Gwp1kPB6EKSuf8YL9PxJT","name":"bonfire"}',
    // Candlelight
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[20,87,100,0]],"enable":1,"id":"TapoStrip_5MD0lPVZ6rf7B0gezimR3s","name":"candlelight"}',
    // Carnival
    '{"brightness":50,"custom":0,"display_colors":[[0,87,100,0],[0,0,100,0],[135,80,100,0]],"enable":1,"id":"TapoStrip_3NbAjdKvkZdD9FGvsTJ6MJ","name":"carnival"}',
    // Cyan
    '{"brightness":50,"custom":0,"display_colors":[[186,50,100,0]],"enable":1,"id":"TapoStrip_2vKcyzPtr3aizuRMuYdAMW","name":"cyan"}',
    // Dancing
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[20,87,100,0],[48,87,100,0],[192,78,100,0]],"enable":1,"id":"TapoStrip_5Tt1eZzXRdj4YWGgGdqK3y","name":"dancing"}',
    // Dating
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[298,58,100,0]],"enable":1,"id":"TapoStrip_2tkyPdByKhKe4eVqE5XphX","name":"dating"}',
    // Disco
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[35,8,100,0],[298,58,100,0],[192,78,100,0]],"enable":1,"id":"TapoStrip_5pAN2kMxzsh8HpsBpfwRXP","name":"disco"}',
    // Dreamland
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[48,87,100,0],[216,49,100,0],[182,94,100,0]],"enable":1,"id":"TapoStrip_4wHSAFyVTCtgxSw0wUeXGV","name":"dreamland"}',
    // ElectroDance
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[132,67,100,0],[298,58,100,0],[51,58,100,0]],"enable":1,"id":"TapoStrip_2s22PUbeRbRROnSuJTw8uN","name":"electro_dance"}',
    // Energetic
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[0,0,100,0],[182,94,100,0]],"enable":1,"id":"TapoStrip_4EPVg5TXRM5OW8fkRq4uMy","name":"energetic"}',
    // Excited
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[48,87,100,0],[182,94,100,0],[135,80,100,0]],"enable":1,"id":"TapoStrip_4CVvw7fPwbDgpjdyTdwSir","name":"excited"}',
    // Fall
    '{"brightness":50,"custom":0,"display_colors":[[44,86,100,0],[20,87,100,0],[20,87,100,0],[307,64,100,0]],"enable":1,"id":"TapoStrip_4g6E1iZQyB2HGa8kIPULRk","name":"fall"}',
    // Family
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[298,58,100,0],[298,58,100,0],[216,46,100,0]],"enable":1,"id":"TapoStrip_4mCB0GdvVxYQUK6rK3Ny0w","name":"family"}',
    // Fireworks
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[192,78,100,0],[298,58,100,0],[216,46,100,0]],"enable":1,"id":"TapoStrip_0xZnAlXp2sYlXpPGsfOguo","name":"fireworks"}',
    // FlowerField
    '{"brightness":50,"custom":0,"display_colors":[[48,87,100,0],[306,72,100,0],[306,72,100,0],[0,87,100,0]],"enable":1,"id":"TapoStrip_5PNM7bkM9AsT8RTjxQrpPs","name":"flower_field"}',
    // Forest
    '{"brightness":50,"custom":0,"display_colors":[[182,96,100,0],[135,100,100,0],[135,100,100,0],[48,87,100,0]],"enable":1,"id":"TapoStrip_4Q8f2MgkLJOUCVYs4C3S6m","name":"forest"}',
    // Game
    '{"brightness":50,"custom":0,"display_colors":[[135,80,100,0],[48,87,100,0],[48,87,100,0],[199,94,100,0]],"enable":1,"id":"TapoStrip_4RVTMKq1uKlB3pexBaHgNE","name":"game"}',
    // Green
    '{"brightness":50,"custom":0,"display_colors":[[137,57,100,0]],"enable":1,"id":"TapoStrip_7597pq6KQwsfV4HVf2vsor","name":"green"}',
    // Halloween
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[20,87,100,0],[20,87,100,0]],"enable":1,"id":"TapoStrip_3DSdleFU3ty3QP4Ud3ZXMD","name":"halloween"}',
    // Happy
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[216,49,100,0],[182,94,100,0]],"enable":1,"id":"TapoStrip_73Svjln3dFbgu75rL1UrKh","name":"happy"}',
    // Jazz
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[298,58,100,0],[34,20,100,0],[48,87,100,0]],"enable":1,"id":"TapoStrip_47WNHiq9BbSNpE822vU6RP","name":"jazz"}',
    // Lake
    '{"brightness":50,"custom":0,"display_colors":[[188,100,100,0],[188,100,100,0],[49,61,100,0]],"enable":1,"id":"TapoStrip_03Dhq9acJ7TeK5p55zNPlO","name":"lake"}',
    // LightGreen
    '{"brightness":50,"custom":0,"display_colors":[[92,49,100,0]],"enable":1,"id":"TapoStrip_1IgXu8L5zqIRbFqhcEwk5V","name":"light_green"}',
    // Lyric
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[35,8,100,0],[298,58,100,0],[192,78,100,0]],"enable":1,"id":"TapoStrip_7L4YEbUn65YY8Lex6wHj52","name":"lyric"}',
    // Moonlight
    '{"brightness":25,"custom":0,"display_colors":[[260,68,100,0],[0,0,100,0],[260,68,100,0]],"enable":1,"id":"TapoStrip_2ufTEngo3cOhJvSZrvSKdV","name":"moonlight"}',
    // Morning
    '{"brightness":50,"custom":0,"display_colors":[[182,94,100,0],[182,94,100,0],[182,94,100,0]],"enable":1,"id":"TapoStrip_7B11L46nAjBGWSOQ2O2VLv","name":"morning"}',
    // Movie
    '{"brightness":50,"custom":0,"display_colors":[[183,56,100,0]],"enable":1,"id":"TapoStrip_2I5ccWSquBU8j3Vnq8lAyd","name":"movie"}',
    // NewYear
    '{"brightness":50,"custom":0,"display_colors":[[0,87,100,0],[298,58,100,0],[182,94,100,0],[135,80,100,0]],"enable":1,"id":"TapoStrip_0SPC7sLfhBFFpjPin9EjWi","name":"new_year"}',
    // Night
    '{"brightness":50,"custom":0,"display_colors":[[285,58,100,0],[216,49,100,0]],"enable":1,"id":"TapoStrip_0je4XrPck2GUabCqqqtgjV","name":"night"}',
    // Orange
    '{"brightness":50,"custom":0,"display_colors":[[39,52,100,0]],"enable":1,"id":"TapoStrip_7fld2P3UXtjklt0zeOkybx","name":"orange"}',
    // Pink
    '{"brightness":50,"custom":0,"display_colors":[[329,30,100,0]],"enable":1,"id":"TapoStrip_0ns4qSp5U0iw23YDakyR3I","name":"pink"}',
    // Purple
    '{"brightness":50,"custom":0,"display_colors":[[281,51,100,0]],"enable":1,"id":"TapoStrip_29591QOxwUNV20Pqfx720l","name":"purple"}',
    // Quiet
    '{"brightness":50,"custom":0,"display_colors":[[48,87,100,0],[135,53,100,0]],"enable":1,"id":"TapoStrip_1wCEVdKuooI1CJofw25Axw","name":"quiet"}',
    // Red
    '{"brightness":50,"custom":0,"display_colors":[[0,51,100,0]],"enable":1,"id":"TapoStrip_4BL9bCCMh2g1zYysCl9hlJ","name":"red"}',
    // Relaxed
    '{"brightness":50,"custom":0,"display_colors":[[48,87,100,0],[135,80,100,0],[182,94,100,0]],"enable":1,"id":"TapoStrip_4CMF6Zyq33hi0dVCw4DEZk","name":"relaxed"}',
    // Rock
    '{"brightness":50,"custom":0,"display_colors":[[12,87,100,0],[49,10,100,0],[192,78,100,0]],"enable":1,"id":"TapoStrip_09nXMfB9vlqMRnaZtUNvNv","name":"rock"}',
    // Siren
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[20,87,100,0],[182,94,100,0]],"enable":1,"id":"TapoStrip_45PsgBVIPAS8eAeejFKLaq","name":"siren"}',
    // Sleep
    '{"brightness":50,"custom":0,"display_colors":[[48,67,100,0],[20,63,100,0],[48,67,100,0]],"enable":1,"id":"TapoStrip_5EcqkgKhof7H4VZHv6GF8W","name":"sleep"}',
    // Snow
    '{"brightness":50,"custom":0,"display_colors":[[0,0,100,0],[0,0,100,0],[0,0,100,0],[0,0,100,0]],"enable":1,"id":"TapoStrip_6J1Wz1BcYAIZ0Hr0hrLtHz","name":"snow"}',
    // Star
    '{"brightness":50,"custom":0,"display_colors":[[0,0,100,0],[188,61,100,0],[0,0,100,0],[188,61,100,0]],"enable":1,"id":"TapoStrip_5BUE2IZxWBlvTyndwlGWxZ","name":"star"}',
    // Study
    '{"brightness":50,"custom":0,"display_colors":[[0,0,100,0]],"enable":1,"id":"TapoStrip_1LMVpsdYvcqOvj7B49Zgsv","name":"study"}',
    // Summer
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[182,94,100,0],[182,94,100,0],[298,58,100,0]],"enable":1,"id":"TapoStrip_3EpKcvOXOg7JOzI2CEGHfV","name":"summer"}',
    // Sunny
    '{"brightness":50,"custom":0,"display_colors":[[0,0,100,0],[182,94,100,0],[221,65,100,0]],"enable":1,"id":"TapoStrip_7iphEteHrkOB6RxyaHB7lq","name":"sunny"}',
    // Sweet
    '{"brightness":50,"custom":0,"display_colors":[[298,58,100,0],[298,58,100,0]],"enable":1,"id":"TapoStrip_6HWuKPlEFY5Tu8iZECj8Cu","name":"sweet"}',
    // Tense
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[20,87,100,0],[20,87,100,0]],"enable":1,"id":"TapoStrip_6lFm0gKWSdV0EZkMBrEdbs","name":"tense"}',
    // Thinking
    '{"brightness":50,"custom":0,"display_colors":[[182,94,100,0],[182,94,100,0],[182,94,100,0]],"enable":1,"id":"TapoStrip_0X0JpxWy3bXrg9UYIjOOHE","name":"thinking"}',
    // Universe
    '{"brightness":50,"custom":0,"display_colors":[[182,100,100,0],[225,87,100,0]],"enable":1,"id":"TapoStrip_0VS5wowo18K0pg5eVlQJjo","name":"universe"}',
    // Volcano
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[20,87,100,0],[20,87,100,0]],"enable":1,"id":"TapoStrip_6dJUyTqdQb69WMTtYfmhXp","name":"volcano"}',
    // Warm
    '{"brightness":50,"custom":0,"display_colors":[[20,87,100,0],[20,87,100,0]],"enable":1,"id":"TapoStrip_6lcSZhR1fFfEK67cU35bgk","name":"warm"}',
    // White
    '{"brightness":50,"custom":0,"display_colors":[[0,0,100,0]],"enable":1,"id":"TapoStrip_3WQHPF6iH8vT8ZUVnTymzr","name":"white"}',
    // Winter
    '{"brightness":50,"custom":0,"display_colors":[[182,94,100,0],[0,0,100,0],[0,0,100,0],[182,94,100,0]],"enable":1,"id":"TapoStrip_0PpgOmXVg0WWdF3710KxbA","name":"winter"}',
    // Work
    '{"brightness":50,"custom":0,"display_colors":[[187,41,100,0],[0,0,100,0],[0,0,100,0],[187,41,100,0]],"enable":1,"id":"TapoStrip_2Xeosp9nHkJIPL2491cbtQ","name":"work"}',
    // Yellow
    '{"brightness":50,"custom":0,"display_colors":[[55,75,100,0]],"enable":1,"id":"TapoStrip_0m6KyfHdw3GK3ge199nxJC","name":"yellow"}'
  );

function LightingEffectPresetJSON(APreset: TTapoLightingEffectPreset): string;
begin
  Result := LightingEffectPresets[APreset];
end;

function SegmentEffectPresetJSON(APreset: TTapoSegmentEffectPreset): string;
begin
  Result := SegmentEffectPresets[APreset];
end;

end.
