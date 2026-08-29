Kugayama Shiori no Shinizama Techou — Russian localization

Supported Steam app: 4141950
Supported game archive: patch.xp3 version 1.05
Supported game EXE SHA-256: 2224d4b10114aaea3cd8c7c144dae9c6ab3aff224db1e137dd4afa0ba5491696
Supported patch.xp3 SHA-256: fc489edde26256c5505b9e8d9777ddb070330bfabf16e47d3184cdf11c128035

Installation with LocalizationSetup.exe
1. Install or update the Steam game, then close it.
2. Download and run LocalizationSetup.exe. The installer can be run from any folder.
3. Approve the Windows administrator prompt.
4. Confirm the detected game folder. If detection fails, select the folder containing KugayamaShiorisDeathDiary.exe; do not select or create a subfolder.
5. Optionally enable the desktop-shortcut task, then select Install.
6. Launch the game normally from Steam. The original game executable now loads the localization automatically.

The installed game folder receives exactly these four files:
KrkrPatch.dll
KrkrPatch.json
localization.xp3
WINMM.dll

The original game archives and executable are not modified. WINMM.dll forwards the game's multimedia timer calls to the real Windows DLL, verifies the supported game EXE and patch.xp3 hashes, and initializes KrkrPatch. If validation or localization initialization fails, it logs the reason to LocalizationBootstrap.log and starts the original game without localization. The patch replaces the game's English scenario-text slot with Russian and translates menus, settings, and game messages. Character and speaker names remain exactly as in the English localization. Text that is part of a picture, including parts of the title screen, remains in English.

If another mod already installed WINMM.dll, Setup stops and does not overwrite it. A prior proxy installed and recorded by this localization can be upgraded. Steam file verification is not an uninstall mechanism and provides no supported pre-verification callback for this installer. If Steam changes the game EXE or patch.xp3, the runtime hash check skips localization and starts vanilla. Remove the localization through Windows Installed Apps when desired.

Uninstall
Open Windows Installed Apps, find Kugayama Shiori Russian Localization, and select Uninstall. Uninstallation removes the four installed localization files, generated logs, and installed shortcuts. If WINMM.dll was replaced after installation, the uninstaller preserves it instead of deleting an unknown mod file.

Troubleshooting
- Verify that the supported KugayamaShiorisDeathDiary.exe and patch.xp3 versions are installed.
- Launch normally from Steam.
- Check story dialogue or the menu at the top of the game window. Some words that are part of pictures remain in English.
- If localization is skipped, attach LocalizationBootstrap.log and KrkrPatch.log from the game folder to the issue report.
- Antivirus software may inspect the runtime patch DLL because it hooks the game's file-loading functions.
- Unsigned releases can show Windows Unknown publisher or SmartScreen warnings. Verify LocalizationSetup.exe using the matching SHA256SUMS.txt; removing the publisher warning requires a publicly trusted Authenticode signature.
- Restore the original game state through the localization uninstaller.

The Russian text was translated manually. English localization JSON is not distributed; development scripts extract it from the user's installed game into ignored generated output.

KrkrPatch.dll is a GPL-3.0-covered KrkrPatch binary built from upstream revision 587261001bf95feab4f0f1cbcbd22cfdadb97e31 with the documented compatibility modification. The matching release provides KrkrPatch-source-587261001bf95feab4f0f1cbcbd22cfdadb97e31-localization-patched.zip beside LocalizationSetup.exe. The build recipe and licence notices are in the repository source archive for the same release tag.

The matching release also provides ThirdPartyLicenses.zip and SHA256SUMS.txt. Verify LocalizationSetup.exe against SHA256SUMS.txt before running it.

msg-tool is used only during development. Scripts download the pinned upstream release on demand and verify it using third-party.lock.json. It is not included in this repository, installer, installed game folder, or release assets.

See Distribution/LICENSES in the repository source archive and ThirdPartyLicenses.zip in the matching release for third-party notices and dependency licence material.
