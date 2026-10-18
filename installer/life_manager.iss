#define AppVersion "1.0.0"
#define BundleDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8C3E7B4A-17A4-42D7-8C45-EBB4C79B6941}
AppName=Life Manager
AppVersion={#AppVersion}
VersionInfoVersion={#AppVersion}
AppPublisher=Life Manager
DefaultDirName={localappdata}\Programs\Life Manager
DefaultGroupName=Life Manager
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
OutputDir=..\release
OutputBaseFilename=LifeManager-1.0.0-win-x64-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\life_manager.exe
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion; Excludes: "*.pdb,*.ilk,*.sqlite,*.sqlite-wal,*.sqlite-shm,*.db,*.db-wal,*.db-shm"

[Icons]
Name: "{group}\Life Manager"; Filename: "{app}\life_manager.exe"
Name: "{autodesktop}\Life Manager"; Filename: "{app}\life_manager.exe"; Tasks: desktopicon

[Tasks]
Name: desktopicon; Description: "Create a desktop shortcut"; Flags: unchecked

[Run]
Filename: "{app}\life_manager.exe"; Description: "Launch Life Manager"; Flags: nowait postinstall skipifsilent

[Code]
// User data under %APPDATA%\Life Manager is never part of the installer.
// Remove only a sign-in entry owned by the executable being uninstalled.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Value: String;
  Expected: String;
begin
  if CurUninstallStep <> usUninstall then exit;
  Expected := '"' + ExpandConstant('{app}\life_manager_widget.exe') + '" --widget';
  if RegQueryStringValue(HKCU,
    'Software\Microsoft\Windows\CurrentVersion\Run',
    'Life Manager Widget', Value) and (CompareText(Value, Expected) = 0) then
    RegDeleteValue(HKCU,
      'Software\Microsoft\Windows\CurrentVersion\Run',
      'Life Manager Widget');
end;
