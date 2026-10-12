program Scan;

uses
  System.StartUpCopy,
  FMX.Forms,
  Tapo.Cameras in '..\TapoLib\Tapo.Cameras.pas',
  Tapo.Client in '..\TapoLib\Tapo.Client.pas',
  Tapo.Crypto in '..\TapoLib\Tapo.Crypto.pas',
  Tapo.Devices in '..\TapoLib\Tapo.Devices.pas',
  Tapo.Discovery in '..\TapoLib\Tapo.Discovery.pas',
  Tapo.Hubs in '..\TapoLib\Tapo.Hubs.pas',
  Tapo.LightEffects in '..\TapoLib\Tapo.LightEffects.pas',
  Tapo.Models in '..\TapoLib\Tapo.Models.pas',
  NetMacScan in '..\TapoLib\NetMacScan.pas',
  TapoScanForm in 'src\TapoScanForm.pas' {TapoScanMainForm},
  TapoSettingsForm in 'src\TapoSettingsForm.pas',
  Neon.Core.Attributes in '..\delphi-neon\Source\Neon.Core.Attributes.pas',
  Neon.Core.DynamicTypes in '..\delphi-neon\Source\Neon.Core.DynamicTypes.pas',
  Neon.Core.Generator in '..\delphi-neon\Source\Neon.Core.Generator.pas',
  Neon.Core.Nullables in '..\delphi-neon\Source\Neon.Core.Nullables.pas',
  Neon.Core.Persistence.JSON in '..\delphi-neon\Source\Neon.Core.Persistence.JSON.pas',
  Neon.Core.Persistence.JSON.Schema in '..\delphi-neon\Source\Neon.Core.Persistence.JSON.Schema.pas',
  Neon.Core.Persistence in '..\delphi-neon\Source\Neon.Core.Persistence.pas',
  Neon.Core.Serializers.DB in '..\delphi-neon\Source\Neon.Core.Serializers.DB.pas',
  Neon.Core.Serializers.Nullables in '..\delphi-neon\Source\Neon.Core.Serializers.Nullables.pas',
  Neon.Core.Serializers.RTL in '..\delphi-neon\Source\Neon.Core.Serializers.RTL.pas',
  Neon.Core.Tags in '..\delphi-neon\Source\Neon.Core.Tags.pas',
  Neon.Core.TypeInfo in '..\delphi-neon\Source\Neon.Core.TypeInfo.pas',
  Neon.Core.Types in '..\delphi-neon\Source\Neon.Core.Types.pas',
  Neon.Core.Utils in '..\delphi-neon\Source\Neon.Core.Utils.pas',
  Tapo.Settings in '..\TapoLib\Tapo.Settings.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TTapoScanMainForm, TapoScanMainForm);
  Application.Run;
end.
