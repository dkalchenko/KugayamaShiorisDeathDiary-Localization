#ifndef MyAppVersion
#define MyAppVersion "0.1.0"
#endif
#ifndef WinmmProxySha256
#error WinmmProxySha256 must be supplied by the release build
#endif

#define GameExe "KugayamaShiorisDeathDiary.exe"
#define GameDirectory "久我山栞の死様手帖"
#define GameExeSha256 "2224D4B10114AAEA3CD8C7C144DAE9C6AB3AFF224DB1E137DD4AFA0BA5491696"
#define PatchArchiveSha256 "FC489EDDE26256C5505B9E8D9777DDB070330BFABF16E47D3184CDF11C128035"
#define ProxyRegistrySubkey "Software\Kugayama Shiori Russian Localization"

[Setup]
AppId={{F89DDFF3-EF3C-4D28-A849-41AF41E1FE57}
AppName=Kugayama Shiori Russian Localization
AppVersion={#MyAppVersion}
AppPublisher=Kugayama Shiori Russian Localization Project
AppPublisherURL=https://github.com/dkalchenko/KugayamaShiorisDeathDiary-Localization
AppSupportURL=https://github.com/dkalchenko/KugayamaShiorisDeathDiary-Localization/issues
AppUpdatesURL=https://github.com/dkalchenko/KugayamaShiorisDeathDiary-Localization/releases
DefaultDirName={code:GetDefaultDir}
DisableProgramGroupPage=yes
OutputBaseFilename=LocalizationSetup
Compression=lzma2/max
SolidCompression=yes
PrivilegesRequired=admin
Uninstallable=yes
UninstallFilesDir={commonappdata}\Kugayama Shiori Russian Localization\Uninstall
UninstallDisplayName=Kugayama Shiori Russian Localization
UninstallDisplayIcon={app}\{#GameExe}
InfoBeforeFile=..\..\README.txt
InfoAfterFile=..\..\LICENSES\THIRD-PARTY-NOTICES.txt
LicenseFile=..\..\LICENSES\KrkrPatch-GPL-3.0.txt
WizardStyle=modern
ArchitecturesAllowed=x86compatible x64compatible

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "..\..\payload\KrkrPatch.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\payload\KrkrPatch.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\payload\localization.xp3"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\payload\WINMM.dll"; DestDir: "{app}"; Flags: ignoreversion uninsneveruninstall

[Registry]
Root: HKLM; Subkey: "{#ProxyRegistrySubkey}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "{#ProxyRegistrySubkey}"; ValueType: string; ValueName: "ProxySha256"; ValueData: "{#WinmmProxySha256}"; Flags: uninsdeletekey

[Icons]
Name: "{autoprograms}\Kugayama Shiori Russian Localization"; Filename: "{app}\{#GameExe}"; WorkingDir: "{app}"
Name: "{autodesktop}\Kugayama Shiori Russian Localization"; Filename: "{app}\{#GameExe}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#GameExe}"; Description: "Launch the game"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[InstallDelete]
Type: files; Name: "{app}\KrkrPatchLoader.exe"

[UninstallDelete]
Type: files; Name: "{app}\KrkrPatchLoader.exe"
Type: files; Name: "{app}\KrkrPatch.log"
Type: files; Name: "{app}\LocalizationBootstrap.log"

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

function TryGetSha256(FileName: String; var Hash: String): Boolean;
begin
  Result := False;
  try
    Hash := GetSHA256OfFile(FileName);
    Result := True;
  except
    Log('Unable to hash ' + FileName + ': ' + GetExceptionMessage);
  end;
end;

function PathsEqual(FirstPath: String; SecondPath: String): Boolean;
begin
  Result := CompareText(AddBackslash(ExpandFileName(FirstPath)),
    AddBackslash(ExpandFileName(SecondPath))) = 0;
end;

function IsKnownProxy(Directory: String; ProxyPath: String): Boolean;
var
  ActualHash: String;
  InstalledHash: String;
  InstalledPath: String;
begin
  Result := False;
  if not TryGetSha256(ProxyPath, ActualHash) then
    Exit;

  if CompareText(ActualHash, '{#WinmmProxySha256}') = 0 then
  begin
    Result := True;
    Exit;
  end;

  if RegQueryStringValue(HKLM, '{#ProxyRegistrySubkey}', 'InstallPath', InstalledPath) and
    RegQueryStringValue(HKLM, '{#ProxyRegistrySubkey}', 'ProxySha256', InstalledHash) and
    PathsEqual(Directory, InstalledPath) and
    (CompareText(ActualHash, InstalledHash) = 0) then
    Result := True;
end;

function GetGameDirectoryError(Directory: String): String;
var
  ActualHash: String;
  FileName: String;
begin
  Result := '';
  FileName := AddBackslash(Directory) + '{#GameExe}';
  if not FileExists(FileName) then
  begin
    Result := 'The selected folder does not contain {#GameExe}.';
    Exit;
  end;
  if not TryGetSha256(FileName, ActualHash) then
  begin
    Result := 'The installer could not verify {#GameExe}.';
    Exit;
  end;
  if CompareText(ActualHash, '{#GameExeSha256}') <> 0 then
  begin
    Result := 'This version of {#GameExe} is not supported. Update or restore the supported game version in Steam.';
    Exit;
  end;

  FileName := AddBackslash(Directory) + 'patch.xp3';
  if not FileExists(FileName) then
  begin
    Result := 'The selected folder does not contain patch.xp3.';
    Exit;
  end;
  if not TryGetSha256(FileName, ActualHash) then
  begin
    Result := 'The installer could not verify patch.xp3.';
    Exit;
  end;
  if CompareText(ActualHash, '{#PatchArchiveSha256}') <> 0 then
  begin
    Result := 'This version of patch.xp3 is not supported. Update or restore the supported game version in Steam.';
    Exit;
  end;

  FileName := AddBackslash(Directory) + 'WINMM.dll';
  if FileExists(FileName) and not IsKnownProxy(Directory, FileName) then
    Result := 'WINMM.dll already exists and is not owned by this localization. Setup will not overwrite a proxy from another mod.';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  ValidationError: String;
begin
  Result := True;
  if CurPageID = wpSelectDir then
  begin
    ValidationError := GetGameDirectoryError(WizardDirValue);
    if ValidationError <> '' then
    begin
      MsgBox(ValidationError, mbError, MB_OK);
      Result := False;
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := GetGameDirectoryError(WizardDirValue);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ProxyPath: String;
begin
  if CurUninstallStep <> usUninstall then
    Exit;

  ProxyPath := AddBackslash(ExpandConstant('{app}')) + 'WINMM.dll';
  if not FileExists(ProxyPath) then
    Exit;

  if IsKnownProxy(ExpandConstant('{app}'), ProxyPath) then
  begin
    if not DeleteFile(ProxyPath) then
      Log('Unable to remove owned proxy: ' + ProxyPath);
  end
  else
    Log('Preserved WINMM.dll because it no longer matches the localization-owned proxy.');
end;
