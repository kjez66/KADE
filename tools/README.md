# Tools

Helpers for reading the KADE Loader's SQLite database
(`open software/loader/sources/data`) without Python 2.6 or the loader GUI.

Both scripts drive `winsqlite3.dll`, which ships with Windows, so there is
nothing to install.

## `sqlq.ps1` — run a query

```powershell
.\tools\sqlq.ps1 -Db "open software\loader\sources\data" `
                 -Sql "SELECT name, desc FROM firmwares WHERE family='minimus'"
```

Useful tables: `firmwares` (name, desc, family, `hex`), `boards` (chip `product`
per board), `library` (function number -> keycode, per `system`), `presets`
(stock input layouts), `parameters`.

## `extract.ps1` — dump firmware images

Writes every firmware for a family to `.hex` files and validates each one
(Intel HEX checksums, EOF record, flash size).

```powershell
.\tools\extract.ps1 -Db "open software\loader\sources\data" `
                    -OutDir firmware\at90usb162 -Family minimus
```

Families: `minimus` (miniArcade), `maxarcade`, `arduino`, `dualstrike`, `ps360`.

## Gotcha

The database stores text as UTF-16LE. Searching the file for ASCII strings
returns nothing, which makes it look encrypted or corrupt — it is neither.

## `make-eep.ps1` — build a custom-mapping EEPROM image

The `*-custom` firmwares read a 40-byte mapping from EEPROM. This generates that
image from a stock preset, so the loader GUI is not needed.

```powershell
.\tools\make-eep.ps1 -Database "open software\loader\sources\data" `
                     -System kade-pin-custom -Preset 0 `
                     -Out firmware\at90usb162\kade-pin-custom-preset0.eep
```

Layout: bytes `0x00`-`0x13` are the unshifted functions for inputs A1-A10 and
B1-B10; bytes `0x14`-`0x27` are the same inputs on the shift layer. `0` is
unassigned. Presets populate the unshifted layer only.

Note the parameter is `-Database`, not `-Db` — PowerShell reserves `Db` as an
alias for the common `-Debug` parameter.
