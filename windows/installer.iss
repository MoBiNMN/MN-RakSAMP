; Inno Setup script for MN-RakSAMP.
;
; Built by .github/workflows/release.yml:
;   ISCC.exe /DMyAppVersion=<ver> /DMySourceDir=<...>\Release /DMyOutputDir=<...>\dist windows\installer.iss
;
; The defaults below let it also be compiled by hand from the repo root.

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#ifndef MySourceDir
  #define MySourceDir "..\build\windows\x64\runner\Release"
#endif

#ifndef MyOutputDir
  #define MyOutputDir "..\build\installer"
#endif

#define MyAppName "MN-RakSAMP"
#define MyAppPublisher "MoBiN"
#define MyAppURL "https://t.me/NighTBlouD"
#define MyAppExeName "MN-RakSAMP.exe"

[Setup]
; A stable AppId is what makes upgrades replace the previous install and lets
; the uninstaller be found again.  Do not change it between releases.
AppId={{7C4A1E52-9F3B-4D8A-9B2E-1A6C5D4F8E71}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Let the user pick "install for me only" (no admin prompt) if they want.
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#MyOutputDir}
OutputBaseFilename=MN-RakSAMP-{#MyAppVersion}-windows-setup
SetupIconFile=..\assets\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
VersionInfoVersion={#MyAppVersion}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoDescription={#MyAppName} Setup
VersionInfoCompany={#MyAppPublisher}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole Flutter release folder: exe, flutter_windows.dll, MNRakSAMPCore.dll,
; plugin DLLs and the data\ directory.
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure KillApp();
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM {#MyAppExeName}',
       '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  KillApp();
  Result := '';
end;

function InitializeUninstall(): Boolean;
begin
  KillApp();
  Result := True;
end;
