# KrkrPatch compatibility modification

Base source: <https://github.com/crskycode/KrkrPatch/tree/587261001bf95feab4f0f1cbcbd22cfdadb97e31>

Modification date: 2026-08-26

`KrkrPatch-DetourRestoreAfterWith.patch` changes two upstream files. The DLL adds the Detours helper-process guard and restores the target process's original in-memory import table before KrkrPatch installs its hooks. The loader reads `steamAppId` from `KrkrPatch.json` and sets `SteamAppId` and `SteamGameId` before launch, preventing Steam from replacing the injected process with an unpatched one.

The modified KrkrPatch source and binaries remain licensed under GNU GPL version 3. Release source archives contain the complete patched source and this patch.
