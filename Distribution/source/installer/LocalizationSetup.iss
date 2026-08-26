#ifndef MyAppVersion
#define MyAppVersion "0.1.0"
#endif

#define GameExe "KugayamaShiorisDeathDiary.exe"
#define GameDirectory "久我山栞の死様手帖"

[Setup]
AppId={{F89DDFF3-EF3C-4D28-A849-41AF41E1FE57}
AppName=Kugayama Shiori Russian Localization
AppVersion={#MyAppVersion}
AppPublisher=Kugayama Shiori Russian Localization Project
DefaultDirName={code:GetDefaultDir}
DisableProgramGroupPage=yes
OutputBaseFilename=LocalizationSetup
Compression=lzma2/max
SolidCompression=yes
PrivilegesRequired=admin
Uninstallable=yes
UninstallFilesDir={commonappdata}\Kugayama Shiori Russian Localization\Uninstall
UninstallDisplayName=Kugayama Shiori Russian Localization
UninstallDisplayIcon={app}\KrkrPatchLoader.exe
InfoBeforeFile=..\..\README.txt
LicenseFile=..\..\LICENSES\KrkrPatch-GPL-3.0.txt
WizardStyle=modern
ArchitecturesAllowed=x86compatible x64compatible

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "..\..\payload\KrkrPatchLoader.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\payload\KrkrPatch.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\payload\KrkrPatch.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\payload\localization.xp3"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Kugayama Shiori Russian Localization"; Filename: "{app}\KrkrPatchLoader.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Kugayama Shiori Russian Localization"; Filename: "{app}\KrkrPatchLoader.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\KrkrPatchLoader.exe"; Description: "Launch the Russian localization"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[Code]
function UnescapeVdfPath(Value: String): String;
begin
  Result := Value;
  StringChangeEx(Result, '\\', '\', True);
end;

function ReadVdfPath(Line: String): String;
var
  KeyEnd: Integer;
  ValueStart: Integer;
  ValueEnd: Integer;
begin
  Result := '';
  KeyEnd := Pos('"path"', Line);
  if KeyEnd = 0 then
    Exit;
  Line := Copy(Line, KeyEnd + 6, Length(Line));
  ValueStart := Pos('"', Line);
  if ValueStart = 0 then
    Exit;
  Line := Copy(Line, ValueStart + 1, Length(Line));
  ValueEnd := Pos('"', Line);
  if ValueEnd = 0 then
    Exit;
  Result := UnescapeVdfPath(Copy(Line, 1, ValueEnd - 1));
end;

function FindInSteamRoot(SteamRoot: String): String;
var
  Candidate: String;
  LibraryFile: String;
  Lines: TArrayOfString;
  Index: Integer;
  LibraryPath: String;
begin
  Result := '';
  Candidate := AddBackslash(SteamRoot) + 'steamapps\common\{#GameDirectory}';
  if FileExists(AddBackslash(Candidate) + '{#GameExe}') then
  begin
    Result := Candidate;
    Exit;
  end;

  LibraryFile := AddBackslash(SteamRoot) + 'steamapps\libraryfolders.vdf';
  if not LoadStringsFromFile(LibraryFile, Lines) then
    Exit;

  for Index := 0 to GetArrayLength(Lines) - 1 do
  begin
    LibraryPath := ReadVdfPath(Lines[Index]);
    if LibraryPath <> '' then
    begin
      Candidate := AddBackslash(LibraryPath) + 'steamapps\common\{#GameDirectory}';
      if FileExists(AddBackslash(Candidate) + '{#GameExe}') then
      begin
        Result := Candidate;
        Exit;
      end;
    end;
  end;
end;

function GetDefaultDir(Param: String): String;
var
  SteamPath: String;
begin
  Result := '';
  if RegQueryStringValue(HKCU, 'Software\Valve\Steam', 'SteamPath', SteamPath) then
    Result := FindInSteamRoot(SteamPath);
  if Result = '' then
    Result := FindInSteamRoot(ExpandConstant('{pf32}\Steam'));
  if Result = '' then
    Result := ExpandConstant('{pf32}\Steam\steamapps\common\{#GameDirectory}');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpSelectDir then
  begin
    if not FileExists(AddBackslash(WizardDirValue) + '{#GameExe}') then
    begin
      MsgBox('The selected folder does not contain {#GameExe}.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;
