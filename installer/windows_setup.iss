; Inno Setup script - Academic Inquiry System (Windows installer)
; Build: ISCC.exe installer\windows_setup.iss   (after: flutter build windows --release)

#define AppName "الاستعلامات الاكاديمية"
#define AppNameEn "Academic Inquiry"
#define AppVersion "2.0.0"
#define AppPublisher "Mohammed Al-Salehi"
#define AppExe "AcademicInquiry.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{7E0B2E9C-4C1A-4B4A-9D5B-ACADEMICINQ01}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\AcademicInquiry
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=Output
OutputBaseFilename=AcademicInquiry-Setup-{#AppVersion}-win64
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppNameEn}}"; Flags: nowait postinstall skipifsilent
