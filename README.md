# Kugayama Shiori no Shinizama Techou — Russian localization

An unofficial Russian translation for the Steam version of the game.

## What is translated

- Story dialogue is translated into Russian.
- Character and speaker names stay the same as in the English version.
- Menus and some other parts of the game remain in English.

## Installation

1. Install the game from Steam and let Steam finish all updates.
2. Close the game.
3. Download `LocalizationSetup.exe` from the [latest project release](https://github.com/dkalchenko/KugayamaShiorisDeathDiary-Localization/releases/latest).
4. Run `LocalizationSetup.exe`. If Windows asks for permission, select **Yes**.
5. Check the game folder shown by the installer. It should normally find the Steam folder automatically.
6. Select **Install**.
7. Start the game normally with the **Play** button in Steam.

You do not need to start a separate translation program. The translation loads automatically when the game starts.

## Removing the translation

1. Open Windows **Settings**.
2. Go to **Apps** → **Installed apps**.
3. Find **Kugayama Shiori Russian Localization**.
4. Select **Uninstall**.

Steam's **Verify integrity of game files** option does not remove the translation. Use the steps above when you want to remove it.

## Troubleshooting

### The installer cannot find the game

Select the game folder yourself. The usual folder is:

```text
C:\Program Files (x86)\Steam\steamapps\common\久我山栞の死様手帖
```

Do not select a new folder or a folder inside the game folder.

### The installer says the game version is not supported

1. Open your Steam Library.
2. Right-click the game and select **Properties**.
3. Open **Installed Files**.
4. Select **Verify integrity of game files**.
5. Wait for Steam to finish, then run the translation installer again.

If the message still appears after a new game update, wait for a translation release that supports that update.

### The installer says `WINMM.dll` already exists

Another game modification may already use that file. The installer will not replace it because doing so could break the other modification. Remove the other modification by following its own removal instructions, then run this installer again.

### The game starts, but it is still in English

Check a story scene first. Menus are not translated and will remain in English.

If story dialogue is also in English:

1. Close the game.
2. Download and install the latest translation release again.
3. Start the game from Steam.

After an unsupported game update, the translation stays off so that the original game can still start.

### The game does not start

1. Remove the translation through Windows **Installed apps**.
2. Verify the game files in Steam.
3. Try starting the game again.

If the original game works after removal, report the problem on the project's [Issues page](https://github.com/dkalchenko/KugayamaShiorisDeathDiary-Localization/issues). Attach `LocalizationBootstrap.log` and `KrkrPatch.log` from the game folder if those files exist.

### Windows shows an unknown publisher warning

Only run the installer downloaded from this project's official release page. Current releases may show this warning because they are not yet signed for Windows.

## For developers

Build and source information is available in [Distribution/source/README.md](Distribution/source/README.md). More detailed installation notes are available in [Distribution/README.txt](Distribution/README.txt).

## Licence

Project-owned work uses the 0BSD licence. KrkrPatch uses GPL-3.0. The game and its files belong to their respective owners. See [LICENSE](LICENSE).
