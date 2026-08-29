#ifndef MyAppVersion
#define MyAppVersion "0.1.0"
#endif
#ifndef SteamApiProxySha256
#error SteamApiProxySha256 must be supplied by the release build
#endif

#define GameExe "KugayamaShiorisDeathDiary.exe"
#define GameDirectory "久我山栞の死様手帖"
#define GameExeSha256 "2224D4B10114AAEA3CD8C7C144DAE9C6AB3AFF224DB1E137DD4AFA0BA5491696"
#define PatchArchiveSha256 "FC489EDDE26256C5505B9E8D9777DDB070330BFABF16E47D3184CDF11C128035"
#define OriginalSteamApiSha256 "DF431862608823F54DF423428296273E1CA65C9928FA93633B882FE1C3D7D153"
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
DisableDirPage=no
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

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "steamintegration"; Description: "Запускать перевод кнопкой «Играть» в Steam (оригинальный файл Steam будет сохранён)"; GroupDescription: "Способ запуска:"
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Ярлыки:"; Flags: unchecked

[Files]
Source: "..\..\payload\KrkrPatchLoader.exe"; DestDir: "{app}"; Flags: ignoreversion; Check: not IsSteamIntegrationSelected
Source: "..\..\payload\KrkrPatch.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\payload\KrkrPatch.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\payload\localization.xp3"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\payload\steam_api.dll"; Flags: dontcopy

[Registry]
Root: HKLM; Subkey: "{#ProxyRegistrySubkey}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "{#ProxyRegistrySubkey}"; ValueType: string; ValueName: "ProxySha256"; ValueData: "{#SteamApiProxySha256}"; Flags: uninsdeletekey
Root: HKLM; Subkey: "{#ProxyRegistrySubkey}"; ValueType: string; ValueName: "OriginalSteamApiSha256"; ValueData: "{#OriginalSteamApiSha256}"; Flags: uninsdeletekey

[Icons]
Name: "{autoprograms}\Kugayama Shiori Russian Localization"; Filename: "{code:GetSteamExecutable}"; Parameters: "-applaunch 4141950"; IconFilename: "{app}\{#GameExe}"; Check: IsSteamIntegrationSelected
Name: "{autoprograms}\Kugayama Shiori Russian Localization"; Filename: "{app}\KrkrPatchLoader.exe"; WorkingDir: "{app}"; Check: not IsSteamIntegrationSelected
Name: "{autodesktop}\Kugayama Shiori Russian Localization"; Filename: "{code:GetSteamExecutable}"; Parameters: "-applaunch 4141950"; IconFilename: "{app}\{#GameExe}"; Tasks: desktopicon; Check: IsSteamIntegrationSelected
Name: "{autodesktop}\Kugayama Shiori Russian Localization"; Filename: "{app}\KrkrPatchLoader.exe"; WorkingDir: "{app}"; Tasks: desktopicon; Check: not IsSteamIntegrationSelected

[Run]
Filename: "{code:GetSteamExecutable}"; Parameters: "-applaunch 4141950"; Description: "Запустить игру через Steam"; Flags: nowait postinstall skipifsilent runasoriginaluser; Check: IsSteamIntegrationSelected
Filename: "{app}\KrkrPatchLoader.exe"; Description: "Запустить игру с русским переводом"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent runasoriginaluser; Check: not IsSteamIntegrationSelected

[InstallDelete]
Type: files; Name: "{app}\KrkrPatchLoader.exe"; Check: IsSteamIntegrationSelected

[UninstallDelete]
Type: files; Name: "{app}\KrkrPatchLoader.exe"
Type: files; Name: "{app}\KrkrPatch.log"
Type: files; Name: "{app}\LocalizationBootstrap.log"

[Code]
function IsSteamIntegrationSelected: Boolean;
begin
  Result := WizardIsTaskSelected('steamintegration');
end;

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

function GetSteamExecutable(Param: String): String;
var
  SteamPath: String;
begin
  if RegQueryStringValue(HKCU, 'Software\Valve\Steam', 'SteamPath', SteamPath) then
    Result := AddBackslash(SteamPath) + 'steam.exe'
  else
    Result := ExpandConstant('{pf32}\Steam\steam.exe');
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

  if CompareText(ActualHash, '{#SteamApiProxySha256}') = 0 then
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

function HasHash(FileName: String; ExpectedHash: String): Boolean;
var
  ActualHash: String;
begin
  Result := TryGetSha256(FileName, ActualHash) and
    (CompareText(ActualHash, ExpectedHash) = 0);
end;

function IsOriginalSteamApi(FileName: String): Boolean;
begin
  Result := HasHash(FileName, '{#OriginalSteamApiSha256}');
end;

function IsKnownOriginalBackup(Directory: String; BackupPath: String): Boolean;
var
  ActualHash: String;
  InstalledHash: String;
  InstalledPath: String;
begin
  Result := False;
  if IsOriginalSteamApi(BackupPath) then
  begin
    Result := True;
    Exit;
  end;
  if not TryGetSha256(BackupPath, ActualHash) then
    Exit;

  if RegQueryStringValue(HKLM, '{#ProxyRegistrySubkey}', 'InstallPath', InstalledPath) and
    RegQueryStringValue(HKLM, '{#ProxyRegistrySubkey}', 'OriginalSteamApiSha256', InstalledHash) and
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
    Result := 'В выбранной папке нет файла {#GameExe}.';
    Exit;
  end;
  if not TryGetSha256(FileName, ActualHash) then
  begin
    Result := 'Установщик не смог проверить файл {#GameExe}.';
    Exit;
  end;
  if CompareText(ActualHash, '{#GameExeSha256}') <> 0 then
  begin
    Result := 'Эта версия игры не поддерживается. Обновите или восстановите файлы игры в Steam.';
    Exit;
  end;

  FileName := AddBackslash(Directory) + 'patch.xp3';
  if not FileExists(FileName) then
  begin
    Result := 'В выбранной папке нет файла patch.xp3.';
    Exit;
  end;
  if not TryGetSha256(FileName, ActualHash) then
  begin
    Result := 'Установщик не смог проверить файл patch.xp3.';
    Exit;
  end;
  if CompareText(ActualHash, '{#PatchArchiveSha256}') <> 0 then
  begin
    Result := 'Эта версия файла patch.xp3 не поддерживается. Обновите или восстановите файлы игры в Steam.';
    Exit;
  end;
end;

function GetStartupMethodError(Directory: String): String;
var
  BackupFileName: String;
  FileName: String;
  WinmmPath: String;
begin
  Result := '';

  WinmmPath := AddBackslash(Directory) + 'WINMM.dll';
  if FileExists(WinmmPath) and not IsKnownProxy(Directory, WinmmPath) then
  begin
    Result := 'Файл WINMM.dll установлен другой программой или модификацией и мешает запуску игры. Удалите установившую его модификацию перед установкой перевода.';
    Exit;
  end;

  FileName := AddBackslash(Directory) + 'steam_api.dll';
  BackupFileName := AddBackslash(Directory) + 'steam_api_original.dll';

  if not IsSteamIntegrationSelected then
  begin
    if FileExists(FileName) and IsKnownProxy(Directory, FileName) and
      (not FileExists(BackupFileName) or not IsOriginalSteamApi(BackupFileName)) then
      Result := 'Не найдена проверенная копия оригинального файла Steam. Восстановите файлы игры в Steam перед сменой способа запуска.';
    Exit;
  end;

  if not FileExists(FileName) then
  begin
    Result := 'В выбранной папке нет оригинального файла Steam. Восстановите файлы игры в Steam и повторите попытку.';
    Exit;
  end;

  if FileExists(BackupFileName) and not IsKnownOriginalBackup(Directory, BackupFileName) then
  begin
    Result := 'Файл steam_api_original.dll уже существует, но не является поддерживаемым оригинальным файлом. Установщик не будет его заменять.';
    Exit;
  end;

  if not IsOriginalSteamApi(FileName) then
  begin
    if not IsKnownProxy(Directory, FileName) then
    begin
      Result := 'Файл steam_api.dll изменён другой программой или модификацией. Установщик не будет его заменять.';
      Exit;
    end;
    if not FileExists(BackupFileName) or not IsOriginalSteamApi(BackupFileName) then
    begin
      Result := 'Не найдена копия поддерживаемого оригинального файла Steam. Восстановите файлы игры в Steam и повторите попытку.';
      Exit;
    end;
  end;
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

function InstallSteamApiProxy(Directory: String): String;
var
  BackupPath: String;
  CurrentPath: String;
  SourcePath: String;
  StagedPath: String;
  WinmmPath: String;
begin
  Result := '';
  try
    ExtractTemporaryFile('steam_api.dll');
  except
    Result := 'Установщик не смог подготовить файл для запуска через Steam: ' + GetExceptionMessage;
    Exit;
  end;

  SourcePath := ExpandConstant('{tmp}\steam_api.dll');
  if not HasHash(SourcePath, '{#SteamApiProxySha256}') then
  begin
    Result := 'Файл установщика для запуска через Steam не прошёл проверку.';
    Exit;
  end;

  CurrentPath := AddBackslash(Directory) + 'steam_api.dll';
  BackupPath := AddBackslash(Directory) + 'steam_api_original.dll';
  if FileExists(BackupPath) and not IsOriginalSteamApi(BackupPath) then
  begin
    if not IsKnownOriginalBackup(Directory, BackupPath) or
      not IsOriginalSteamApi(CurrentPath) or not DeleteFile(BackupPath) then
    begin
      Result := 'Установщик не может заменить прежнюю копию оригинального файла Steam. Проверьте файлы игры в Steam и повторите попытку.';
      Exit;
    end;
  end;
  if not FileExists(BackupPath) then
  begin
    if not IsOriginalSteamApi(CurrentPath) then
    begin
      Result := 'Установщик не может сохранить оригинальный файл Steam.';
      Exit;
    end;
    if not CopyFile(CurrentPath, BackupPath, True) or not IsOriginalSteamApi(BackupPath) then
    begin
      DeleteFile(BackupPath);
      Result := 'Установщик не смог создать проверенную копию оригинального файла Steam.';
      Exit;
    end;
  end;

  WinmmPath := AddBackslash(Directory) + 'WINMM.dll';
  if FileExists(WinmmPath) then
  begin
    if not IsKnownProxy(Directory, WinmmPath) then
    begin
      Result := 'Установщик не будет удалять неизвестный файл WINMM.dll.';
      Exit;
    end;
    if not DeleteFile(WinmmPath) then
    begin
      Result := 'Закройте игру и программы, использующие WINMM.dll, затем повторите попытку.';
      Exit;
    end;
  end;

  StagedPath := AddBackslash(Directory) + 'steam_api_localization.new';
  if FileExists(StagedPath) and not DeleteFile(StagedPath) then
  begin
    Result := 'Установщик не смог удалить остатки незавершённой установки перевода.';
    Exit;
  end;
  if not CopyFile(SourcePath, StagedPath, True) or
    not HasHash(StagedPath, '{#SteamApiProxySha256}') then
  begin
    DeleteFile(StagedPath);
    Result := 'Установщик не смог скопировать и проверить новый файл для запуска через Steam.';
    Exit;
  end;

  if not CopyFile(StagedPath, CurrentPath, False) or
    not HasHash(CurrentPath, '{#SteamApiProxySha256}') then
  begin
    CopyFile(BackupPath, CurrentPath, False);
    DeleteFile(StagedPath);
    Result := 'Установщик не смог включить запуск перевода через Steam. Оригинальный файл восстановлен.';
    Exit;
  end;
  DeleteFile(StagedPath);
  RegWriteStringValue(HKLM, '{#ProxyRegistrySubkey}', 'InstallPath', Directory);
  RegWriteStringValue(HKLM, '{#ProxyRegistrySubkey}', 'ProxySha256', '{#SteamApiProxySha256}');
  RegWriteStringValue(HKLM, '{#ProxyRegistrySubkey}', 'OriginalSteamApiSha256', '{#OriginalSteamApiSha256}');
end;

function InstallLauncherStartup(Directory: String): String;
var
  BackupPath: String;
  CurrentPath: String;
  WinmmPath: String;
begin
  Result := '';

  WinmmPath := AddBackslash(Directory) + 'WINMM.dll';
  if FileExists(WinmmPath) then
  begin
    if not IsKnownProxy(Directory, WinmmPath) then
    begin
      Result := 'Установщик не будет удалять неизвестный файл WINMM.dll.';
      Exit;
    end;
    if not DeleteFile(WinmmPath) then
    begin
      Result := 'Закройте игру и программы, использующие WINMM.dll, затем повторите попытку.';
      Exit;
    end;
  end;

  CurrentPath := AddBackslash(Directory) + 'steam_api.dll';
  BackupPath := AddBackslash(Directory) + 'steam_api_original.dll';
  if not FileExists(CurrentPath) or not IsKnownProxy(Directory, CurrentPath) then
  begin
    if FileExists(CurrentPath) and IsOriginalSteamApi(CurrentPath) and
      FileExists(BackupPath) and IsKnownOriginalBackup(Directory, BackupPath) then
      if not DeleteFile(BackupPath) then
        Log('Unable to remove the no-longer-needed original Steam file backup.');
    Exit;
  end;

  if not FileExists(BackupPath) or not IsOriginalSteamApi(BackupPath) then
  begin
    Result := 'Установщик не может восстановить оригинальный файл Steam. Восстановите файлы игры в Steam и повторите попытку.';
    Exit;
  end;

  if not CopyFile(BackupPath, CurrentPath, False) or not IsOriginalSteamApi(CurrentPath) then
  begin
    Result := 'Установщик не смог восстановить оригинальный файл Steam. Закройте игру и повторите попытку.';
    Exit;
  end;
  if not DeleteFile(BackupPath) then
    Log('Unable to remove the no-longer-needed original Steam file backup.');
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := GetGameDirectoryError(WizardDirValue);
  if Result = '' then
    Result := GetStartupMethodError(WizardDirValue);
  if Result = '' then
  begin
    if IsSteamIntegrationSelected then
      Result := InstallSteamApiProxy(WizardDirValue)
    else
      Result := InstallLauncherStartup(WizardDirValue);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  BackupPath: String;
  Directory: String;
  ProxyPath: String;
begin
  if CurUninstallStep <> usUninstall then
    Exit;

  Directory := ExpandConstant('{app}');
  ProxyPath := AddBackslash(Directory) + 'steam_api.dll';
  BackupPath := AddBackslash(Directory) + 'steam_api_original.dll';

  if not FileExists(BackupPath) or not IsOriginalSteamApi(BackupPath) then
  begin
    Log('Preserved Steam startup files because the verified original backup is unavailable. Steam file verification can restore the game.');
    Exit;
  end;

  if not FileExists(ProxyPath) or IsKnownProxy(Directory, ProxyPath) then
  begin
    if CopyFile(BackupPath, ProxyPath, False) and IsOriginalSteamApi(ProxyPath) then
    begin
      if not DeleteFile(BackupPath) then
        Log('Unable to remove the no-longer-needed original Steam file backup.');
    end
    else
      Log('Unable to restore the original Steam file. Steam file verification can restore the game.');
  end
  else if IsOriginalSteamApi(ProxyPath) then
  begin
    if not DeleteFile(BackupPath) then
      Log('Unable to remove the no-longer-needed original Steam file backup.');
  end
  else
    Log('Preserved steam_api.dll and its backup because steam_api.dll was changed by another program or mod.');
end;
