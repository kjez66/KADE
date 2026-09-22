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
