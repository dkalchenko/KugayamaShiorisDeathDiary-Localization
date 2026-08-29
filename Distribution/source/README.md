# Russian localization source

This directory contains the checked-in Russian localization JSON, scenario manifest, build scripts, and installer definition. English localization JSON and all intermediate archives are generated locally under ignored `generated/` output.

## Requirements

- PowerShell 7
- The installed Steam game, updated to supported `patch.xp3` version `1.05`
- Internet access for the first pinned `msg-tool` download

The scripts resolve `msg-tool` from the repository's `third-party.lock.json`. They download upstream `v0.4.0-alpha.3`, revision `dcc8a29512a7025577f395d93b89e6666b23f8e6`, verify the locked SHA-256, and cache the executable outside the repository under `%LOCALAPPDATA%\KugayamaShioriLocalization\dependencies` (or the system temporary directory when local application data is unavailable). The program and its source are never shipped by this project.

## Export English text

```powershell
./scripts/localizationDecompile.ps1
```

The default input is:

```text
C:\Program Files (x86)\Steam\steamapps\common\久我山栞の死様手帖\patch.xp3
```

The script writes extracted English JSON and the original UI text to `generated/`. Pass an explicit archive or output path when needed; generated English files are disposable and must not be committed.

## Compile Russian localization

```powershell
./scripts/localizationCompile.ps1 -OutputPath ../payload/localization.xp3
```

The compiler reads the installed game archive as the authoritative English source, imports the checked-in Russian messages into language index `1`, and adds the Russian UI text. It verifies that every story `name` field remains unchanged and that all UI keys and placeholders match the game. It checks the supported archive SHA-256 and reopens the generated XP3 to compare every message and the UI text after packing.

## Release build

Release CI fetches KrkrPatch revision `587261001bf95feab4f0f1cbcbd22cfdadb97e31`, applies `patches/KrkrPatch-DetourRestoreAfterWith.patch`, and builds its x86 DLL. CI also builds the checked-in x86 `WINMM.dll` proxy and packages all runtime files in `LocalizationSetup.exe`. Steam still launches the original game executable; Windows loads the proxy, which forwards the game's four imported multimedia timer functions to the system `winmm.dll`.

Before initializing KrkrPatch, the proxy verifies the exact supported game EXE and `patch.xp3` SHA-256 hashes. Missing files, hash mismatches, DLL load failures, invalid KrkrPatch configuration, and hook-installation failures are logged and fall back to the unlocalized game. `patchNoProtocol` remains enabled because this game can request scenario files by bare storage name. Release configuration uses `logLevel` `1`.

Upstream KrkrPatch source is not committed here. Each release attaches `KrkrPatch-source-587261001bf95feab4f0f1cbcbd22cfdadb97e31-localization-patched.zip` beside the installer. It contains the complete patched source used for the binaries, the compatibility patch, its modification notice, and the exact KrkrPatch build-support files. The workflow in `.github/workflows/release.yml` is the corresponding build recipe.

The release also contains `ThirdPartyLicenses.zip` with collected vcpkg, NuGet, KrkrPatch, Inno Setup, and repository notices, plus `SHA256SUMS.txt` covering every release asset.

## Windows code signing

The current workflow produces an unsigned installer. Changing Inno Setup's `AppPublisher` value or using a self-signed certificate cannot remove the public Windows `Unknown publisher` warning.

Official releases need a publicly trusted Authenticode identity. After selecting a signing provider, configure signing only in a protected GitHub release environment: sign and RFC 3161 timestamp `KrkrPatch.dll` and `WINMM.dll`, verify them, compile the installer, then sign and verify `LocalizationSetup.exe`. Generate checksums only after signing. Inno Setup's generated uninstaller requires `SignedUninstaller=yes` and signing access during compilation if it must also carry the publisher signature.

Microsoft's current signing options are documented at <https://learn.microsoft.com/windows/apps/package-and-deploy/code-signing-options>. SmartScreen reputation is separate from certificate validity and can take time to accumulate even after signing: <https://learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation>.
