# Kugayama Shiori no Shinizama Techou — Russian localization

Unofficial manual Russian localization for Steam app `4141950`, game archive `patch.xp3` version `1.05`.

Download `LocalizationSetup.exe` from the matching GitHub release. The installer verifies the game folder and installs exactly four files:

- `KrkrPatchLoader.exe`
- `KrkrPatch.dll`
- `KrkrPatch.json`
- `localization.xp3`

Launch the game through `KrkrPatchLoader.exe` or the installer-created shortcut. The original game archives are not modified. Character and speaker names remain identical to the English localization.

See [Distribution/README.txt](Distribution/README.txt) for installation and removal instructions.

## Source and releases

Russian JSON, build scripts, the installer definition, and the compiled `localization.xp3` are kept in `Distribution/`. English localization JSON is extracted from the user's installed game into ignored `Distribution/source/generated/` output and is not distributed.

The localization scripts download pinned `msg-tool` `v0.4.0-alpha.3` on demand using `third-party.lock.json`, verify its SHA-256, and cache it outside the repository under the user's local application-data directory. Neither `msg-tool` nor its source is committed, installed, or attached to releases.

Release CI fetches unmodified KrkrPatch revision `587261001bf95feab4f0f1cbcbd22cfdadb97e31`, builds its x86 loader and DLL, and attaches `KrkrPatch-source-587261001bf95feab4f0f1cbcbd22cfdadb97e31.zip` beside `LocalizationSetup.exe` as corresponding source.

Each release also provides `ThirdPartyLicenses.zip` and `SHA256SUMS.txt`. Verify the installer checksum before running it.

Releases remain unsigned until a public Authenticode signing identity is configured. Windows can therefore show `Unknown publisher`; checksum files provide integrity verification but do not replace Windows code signing.

See [Distribution/source/README.md](Distribution/source/README.md) for reproduction instructions and [third-party notices](Distribution/LICENSES/THIRD-PARTY-NOTICES.txt) for provenance.

## Licence

Repository-owned work is 0BSD. KrkrPatch and its binaries are GPL-3.0. Game-owned material remains the property of its respective owners. See [LICENSE](LICENSE).
