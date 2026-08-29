# Kugayama Shiori no Shinizama Techou — Russian localization

An unofficial Russian translation for the Steam version of the game.

## What is translated

- Story dialogue is translated into Russian.
- Menus, settings, and game messages are translated into Russian.
- Character and speaker names stay the same as in the English version.
- Text that is part of a picture, including parts of the title screen, remains in English.

## Installation

1. Install or update the game in Steam, then close it.
2. Download `LocalizationSetup.exe` from the [latest project release](https://github.com/dkalchenko/KugayamaShiorisDeathDiary-Localization/releases/latest).
3. Run the installer and approve the Windows permission request.
4. Check the selected game folder. The usual folder is:

   ```text
   C:\Program Files (x86)\Steam\steamapps\common\久我山栞の死様手帖
   ```

5. Choose how the game should start:

   - Leave **Запускать перевод кнопкой «Играть» в Steam** selected to use the normal **Play** button in Steam. The installer replaces `steam_api.dll` after keeping a checked copy of the original file.
   - Clear that option to keep Steam files unchanged. Start the translation from the installed Russian Localization shortcut instead.

6. Select **Install**.

The game-folder page is always shown, including when updating the translation.

## Removing the translation

Open Windows **Settings** → **Apps** → **Installed apps**, find **Kugayama Shiori Russian Localization**, and select **Uninstall**.

When Steam startup was selected, the uninstaller restores the saved original Steam file. If that file was changed by another program after installation, the uninstaller leaves it alone.

## Steam file verification

Steam does not tell the translation installer before verification starts. When Steam startup is selected, verification replaces the translation startup file with the original Steam file. The game then starts normally without the translation. Run `LocalizationSetup.exe` again to enable it.

## Troubleshooting

### The installer cannot find the game

Select the folder containing `KugayamaShiorisDeathDiary.exe`. Do not select a new folder or a folder inside the game folder.

### The installer says the game version is not supported

Verify the game files in Steam, wait for Steam to finish, and run the installer again. After a new game update, a new translation release may be required.

### The installer will not change a Steam file

Another program or game modification may already use that file. The installer will not overwrite an unknown file. Remove the other modification using its own instructions, or clear the Steam-startup option and use the separate localization launcher.

### The installer reports `WINMM.dll`

This game cannot start with that file in its folder. Remove the modification that installed it, then try again. The installer removes only an older copy that it knows belongs to this localization.

### The game starts in English

Some text in pictures remains in English. If story dialogue is also English, close the game and run the latest installer again.

If the game was updated or a required translation file cannot load, the translation stays off and the original game starts. Report the problem on the project's [Issues page](https://github.com/dkalchenko/KugayamaShiorisDeathDiary-Localization/issues) and attach `LocalizationBootstrap.log` and `KrkrPatch.log` from the game folder if they exist.

### The game does not start

1. Remove the translation through Windows **Installed apps**.
2. Verify the game files in Steam.
3. Start the game again.

### Windows shows an unknown publisher warning

Only run the installer downloaded from this project's official release page. Current releases may show this warning because they are not yet signed for Windows.

## For developers

Build and source information is in [Distribution/source/README.md](Distribution/source/README.md).

## Licence

Project-owned work uses the 0BSD licence. KrkrPatch uses GPL-3.0. The game and its files belong to their respective owners. See [LICENSE](LICENSE).
