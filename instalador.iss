[Setup]
AppName=Logistica Barraca
AppVersion=1.0
DefaultDirName={autopf}\Logistica Barraca
DefaultGroupName=Logistica Barraca
OutputDir=output
OutputBaseFilename=LogisticaBarracaInstaller
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; GroupDescription: "Opciones adicionales:"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Logistica Barraca"; Filename: "{app}\logistica_barraca_mvp.exe"
Name: "{autodesktop}\Logistica Barraca"; Filename: "{app}\logistica_barraca_mvp.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\logistica_barraca_mvp.exe"; Description: "Abrir Logistica Barraca"; Flags: nowait postinstall skipifsilent