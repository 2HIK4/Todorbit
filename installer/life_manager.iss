#ifndef AppVersion
  #error AppVersion must be passed by build-installer.ps1
#endif
#define BundleDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8C3E7B4A-17A4-42D7-8C45-EBB4C79B6941}
AppName=TodoPilot
AppVersion={#AppVersion}
VersionInfoVersion={#AppVersion}
AppPublisher=Hussam Alkhatib
DefaultDirName={localappdata}\Programs\Life Manager
DefaultGroupName=TodoPilot
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
OutputDir=..\release
OutputBaseFilename=TodoPilot-{#AppVersion}-win-x64-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\TodoPilot.exe
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion; Excludes: "life_manager.exe,life_manager_widget.exe,*.pdb,*.ilk,*.sqlite,*.sqlite-wal,*.sqlite-shm,*.db,*.db-wal,*.db-shm"
Source: "..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\TodoPilot"; Filename: "{app}\TodoPilot.exe"
Name: "{autodesktop}\TodoPilot"; Filename: "{app}\TodoPilot.exe"; Tasks: desktopicon

[Tasks]
Name: desktopicon; Description: "Create a desktop shortcut"; Flags: unchecked

[Run]
Filename: "{app}\TodoPilot.exe"; Description: "Launch TodoPilot"; Flags: nowait postinstall skipifsilent

[Code]
// A previous installed TodoPilot used the legacy Life Manager profile. A
// fresh install never opts into it merely because the old database exists.
var WasTodoPilotUpgrade: Boolean;

function IsInstalledTodoPilotUpgrade: Boolean;
var
  InstallDir: String;
  DisplayName: String;
  UninstallKey: String;
begin
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
    '{8C3E7B4A-17A4-42D7-8C45-EBB4C79B6941}_is1';
  Result := RegQueryStringValue(HKCU, UninstallKey, 'InstallLocation', InstallDir) and
    RegQueryStringValue(HKCU, UninstallKey, 'DisplayName', DisplayName) and
    (Pos('TodoPilot', DisplayName) = 1) and
    (CompareText(AddBackslash(InstallDir),
      AddBackslash(ExpandConstant('{app}'))) = 0) and
    FileExists(ExpandConstant('{app}\TodoPilot.exe'));
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ProfileDir: String;
  Marker: String;
begin
  if CurStep = ssInstall then
  begin
    ProfileDir := ExpandConstant('{%APPDATA}\TodoPilot');
    Marker := ProfileDir + '\legacy-profile.json';
    WasTodoPilotUpgrade := IsInstalledTodoPilotUpgrade and
      FileExists(ExpandConstant('{%APPDATA}\Life Manager\life_manager.sqlite')) and
      not FileExists(ProfileDir + '\life_manager.sqlite') and
      not FileExists(Marker);
  end;
  if (CurStep = ssPostInstall) and WasTodoPilotUpgrade then
  begin
    if not ForceDirectories(ProfileDir) or
      not SaveStringToFile(Marker,
        '{"profile":"todopilot-upgrade-v1"}', False) then
      MsgBox('TodoPilot could not select the previous TodoPilot profile. ' +
        'Your data is unchanged. Open Backups and import the old database ' +
        'explicitly before adding new data.', mbError, MB_OK);
  end;
end;

// User data is never part of the installer or removed on uninstall.
// Remove only a sign-in entry owned by the executable being uninstalled.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Value: String;
  Expected: String;
begin
  if CurUninstallStep <> usUninstall then exit;
  Expected := '"' + ExpandConstant('{app}\TodoPilotWidget.exe') + '" --widget';
  if RegQueryStringValue(HKCU,
    'Software\Microsoft\Windows\CurrentVersion\Run',
    'Life Manager Widget', Value) and (CompareText(Value, Expected) = 0) then
    RegDeleteValue(HKCU,
      'Software\Microsoft\Windows\CurrentVersion\Run',
      'Life Manager Widget');
end;
