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
Name: "chinese-simplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\stroom.exe"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\stroom.exe"; Tasks: desktopicon

[CustomMessages]
english.CreateDesktopIcon=Create a desktop shortcut
chinese-simplified.CreateDesktopIcon=创建桌面快捷方式
english.ShortcutsGroup=Shortcuts:
chinese-simplified.ShortcutsGroup=快捷方式：
english.LaunchStroom=Launch Stroom
chinese-simplified.LaunchStroom=运行 Stroom

[Tasks]
Name: desktopicon; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:ShortcutsGroup}"

[Run]
Filename: "{app}\stroom.exe"; Description: "{cm:LaunchStroom}"; Flags: postinstall nowait skipifsilent
