# KrkrPatch compatibility modification

Base source: <https://github.com/crskycode/KrkrPatch/tree/587261001bf95feab4f0f1cbcbd22cfdadb97e31>

Modification date: 2026-08-26

`KrkrPatch-DetourRestoreAfterWith.patch` adds the Detours helper-process guard and restores the target process's original in-memory import table before KrkrPatch installs its hooks. This follows Microsoft's `DetourCreateProcessWithDlls` requirements and is intended to prevent SteamStub from starting against Detours' temporary import table.

The modified KrkrPatch source and binaries remain licensed under GNU GPL version 3. Release source archives contain the complete patched source and this patch.
