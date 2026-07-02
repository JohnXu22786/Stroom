; Stroom Windows 安装包配置
; 使用 Inno Setup 编译: ISCC.exe installer.iss

#define MyAppName "Stroom"
#define MyAppVersion "0.2.14"
#define MyAppPublisher "JohnTsui"
#define MyAppURL "https://github.com/JohnXu22786/Stroom"
#define SourceDir "..\build\windows\x64\runner\Release"
#define OutputDir "..\artifacts"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=stroom-windows-x64-installer-{#MyAppVersion}
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\stroom.exe
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\stroom.exe"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\stroom.exe"; Tasks: desktopicon

[Tasks]
Name: desktopicon; Description: "创建桌面快捷方式"; GroupDescription: "快捷方式："

[Run]
Filename: "{app}\stroom.exe"; Description: "运行 Stroom"; Flags: postinstall nowait skipifsilent
