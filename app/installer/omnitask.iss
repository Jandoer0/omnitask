; Установщик Omnitask Local для Windows (Inno Setup 6).
; Скомпилировать после сборки приложения:
;   iscc installer\omnitask.iss
; Результат: installer\Output\omnitask-local-setup.exe

#define AppName "Omnitask Local"
#define AppVersion "0.1.0"
#define AppExe "omnitask_local.exe"
; Путь к собранной папке Release (относительно корня проекта app/)
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{8E0D4A21-4C4C-4E9F-9E3B-6A1F2C7D8B10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Jandoer0
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}
OutputDir=Output
OutputBaseFilename=omnitask-local-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные якоря:"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Удалить {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Запустить {#AppName}"; Flags: nowait postinstall skipifsilent
