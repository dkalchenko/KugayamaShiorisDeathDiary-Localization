# KrkrPatch compatibility modification

Base source: <https://github.com/crskycode/KrkrPatch/tree/587261001bf95feab4f0f1cbcbd22cfdadb97e31>

Modification date: 2026-08-26

`KrkrPatch-DetourRestoreAfterWith.patch` changes `KrkrPatch/dllmain.cpp`. The DLL adds the Detours helper-process guard, restores the target process's original in-memory import table, exports an idempotent `InitializeKrkrPatch` entry point, and reports hook/configuration failures instead of terminating the game. `KRKRPATCH_DEFER_STARTUP=1` lets the `WINMM.dll` proxy load the DLL under the Windows loader lock and initialize it safely afterward.

The modified KrkrPatch source and binary remain licensed under GNU GPL version 3. Release source archives contain the complete patched source and this patch.
