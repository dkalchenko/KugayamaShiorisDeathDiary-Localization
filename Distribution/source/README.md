# Russian localization source

This directory contains the reproducible localization data, build scripts, installer definition, and the corresponding KrkrPatch source.

Requirements:

- PowerShell 7
- The installed Steam game
- Inno Setup 7 for the final installer
- Visual Studio 2022 C++ build tools and vcpkg for KrkrPatch

The repository includes the pinned `msg-tool` v0.4.0-alpha.3 executable at `../../tools/msg-tool/msg_tool.exe` with SHA-256 `62FE396780468200CB50F287FE213E697A903F0A85A91153FA3692598AE8AB5D`. Its corresponding GPL source is at `../../tools/msg-tool-src`, exported from tag `v0.4.0-alpha.3`, revision `dcc8a29512a7025577f395d93b89e6666b23f8e6`. Both localization scripts discover this executable automatically; `-MsgToolPath` or `MSG_TOOL_PATH` can override it.

Export the authoritative English text:

```powershell
./scripts/localizationDecompile.ps1
```

Compile the checked-in Russian JSON files into the runtime archive:

```powershell
./scripts/localizationCompile.ps1 -OutputPath ../payload/localization.xp3
```

Both commands accept explicit input and output paths. The default game archive is:

```text
C:\Program Files (x86)\Steam\steamapps\common\久我山栞の死様手帖\patch.xp3
```

The compiler replaces language index `1`, the English slot. It validates that every `name` field is unchanged before importing the Russian `message` fields.
It also verifies the supported game-archive hash and compares every message after packing and reopening the generated XP3.

`generated/` contains disposable extraction and build output and is ignored by Git.
