Kugayama Shiori no Shinizama Techou — Russian localization

Supported Steam app: 4141950
Supported game archive: patch.xp3 version 1.05
Supported patch.xp3 SHA-256: fc489edde26256c5505b9e8d9777ddb070330bfabf16e47d3184cdf11c128035

Installation with LocalizationSetup.exe
1. Install or update the Steam game, then close it.
2. Download and run LocalizationSetup.exe. The installer can be run from any folder.
3. Approve the Windows administrator prompt.
4. Confirm the detected game folder. If detection fails, select the folder containing KugayamaShiorisDeathDiary.exe; do not select or create a subfolder.
5. Optionally enable the desktop-shortcut task, then select Install.
6. Launch through the installed Russian Localization shortcut or KrkrPatchLoader.exe in the game folder. Launching KugayamaShiorisDeathDiary.exe directly bypasses the localization.

The installed game folder receives exactly these four files:
KrkrPatchLoader.exe
KrkrPatch.dll
KrkrPatch.json
localization.xp3

The original game archives are not modified. The patch replaces the game's English scenario-text slot with Russian. Character and speaker names remain exactly as in the English localization.

Uninstall
Open Windows Installed Apps, find Kugayama Shiori Russian Localization, and select Uninstall. Uninstallation removes only the four localization files and installed shortcuts.

Troubleshooting
- Verify that KugayamaShiorisDeathDiary.exe exists in the selected directory.
- Launch KrkrPatchLoader.exe, not KugayamaShiorisDeathDiary.exe.
- Antivirus software may inspect the runtime patch DLL because it hooks the game's file-loading functions.
- Unsigned releases can show Windows Unknown publisher or SmartScreen warnings. Verify LocalizationSetup.exe using the matching SHA256SUMS.txt; removing the publisher warning requires a publicly trusted Authenticode signature.
- Restore the original game state by uninstalling or deleting the four files listed above.

The Russian text was translated manually. English localization JSON is not distributed; development scripts extract it from the user's installed game into ignored generated output.

KrkrPatchLoader.exe and KrkrPatch.dll are GPL-3.0-covered KrkrPatch binaries built from upstream revision 587261001bf95feab4f0f1cbcbd22cfdadb97e31. The matching release provides KrkrPatch-source-587261001bf95feab4f0f1cbcbd22cfdadb97e31.zip beside LocalizationSetup.exe. The build recipe and licence notices are in the repository source archive for the same release tag.

The matching release also provides ThirdPartyLicenses.zip and SHA256SUMS.txt. Verify LocalizationSetup.exe against SHA256SUMS.txt before running it.

msg-tool is used only during development. Scripts download the pinned upstream release on demand and verify it using third-party.lock.json. It is not included in this repository, installer, installed game folder, or release assets.

See Distribution/LICENSES in the repository source archive and ThirdPartyLicenses.zip in the matching release for third-party notices and dependency licence material.
