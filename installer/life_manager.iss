#define AppVersion "1.0.0"
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
OutputBaseFilename=TodoPilot-1.0.0-win-x64-setup
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
// User data under %APPDATA%\Life Manager is never part of the installer.
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
