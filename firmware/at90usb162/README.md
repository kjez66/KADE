# KADE miniArcade (AT90USB162) — extracted firmware images

Ready-to-flash Intel HEX images for the Kickstarter KADE miniArcade, so the
board can be programmed **without the 2014 KADE Loader GUI**.

## Why these exist

The original loader stores its compiled firmware inside a SQLite database
(`open software/loader/sources/data`, table `firmwares`, column `hex`), not as
files on disk. The loader is a Python 2.6 / wxPython app whose bundled Atmel DFU
driver (`atmel_usb_dfu.inf`, `DriverVer = 08/28/2009`) cannot load on 64-bit
Windows 10/11 — it fails with Code 28, `CM_PROB_FAILED_INSTALL`.

These images were extracted straight from that database with `tools/extract.ps1`.

> Note: the database stores text as **UTF-16LE** (header offset 56 = `0x02`).
> Searching it for ASCII strings finds nothing and makes it look encrypted.
> It isn't.

## Provenance and verification

Extracted from the loader database at KADE Loader **v1.1.2.0** (15 May 2014),
family `minimus`. Every image was validated on extraction:

- Intel HEX checksums verified on every record — **0 bad checksums**
- EOF record (`:00000001FF`) present in all 25 files
- All images fit the AT90USB162's 16 KB flash (largest: `kade-xbox-custom`, 8328 bytes)

## Flashing

The board's DFU bootloader enumerates as `USB\VID_03EB&PID_2FFA`.

1. Bind a usable driver with [Zadig](https://zadig.akeo.ie/) — WinUSB or
   libusb-win32 — to that device. The bundled 2009 driver will not work.
2. Flash with [dfu-programmer](https://dfu-programmer.github.io/):

```sh
dfu-programmer at90usb162 erase
dfu-programmer at90usb162 flash kade-mame.hex
dfu-programmer at90usb162 launch
```

The DFU bootloader lives in a write-protected boot section and cannot be erased
by `dfu-programmer`, so a bad flash is always recoverable — re-enter DFU and
flash again.

## Fixed vs. custom firmwares

**Fixed mapping** — flash and go, nothing else needed:
`kade-mame`, `kade-mame-2p`, `kade-gen`, `kade-icade`, `kade-pin`, `kade-key`,
`kade-joy`, `kade-4x4`, `kade-led-demo`, `kade-test-minimus`, and the other
non-`custom` images.

**Custom mapping** (`*-custom`, `kade-mame-extended`) — these additionally read a
40-byte mapping from EEPROM and need a `.eep` flashed alongside:

```sh
dfu-programmer at90usb162 flash-eeprom mapping.eep
```

Per `kade-pin-custom/main.c` (`uint8_t ass[40], state[20]`), the layout is
**20 physical inputs, each with a normal and a shifted function**:

| EEPROM address | Meaning |
|---|---|
| `0x00`–`0x13` | function number for inputs 1–20, unshifted |
| `0x14`–`0x27` | function number for inputs 1–20, shifted |

Function numbers come from the loader database's `library` table, keyed by
`system` (e.g. `system='kade-pin-custom'`). The `presets` table holds the stock
layouts. Query them with `tools/sqlq.ps1`.

## Not included

`kade-led` is listed in the database but stores a zero-length image, so there is
nothing to extract. 25 of the 26 listed `minimus` firmwares are here.

Licensing follows the upstream project: GPLv3 (see `LICENSE.txt`).

## Pinball cabinet setup (`kade-pin-custom`)

`kade-pin` is marked `Removed` (deprecated) in the loader database;
`kade-pin-custom` is the maintained pinball firmware and is the one to use. Its
61-function library targets Visual Pinball and Future Pinball.

The board exposes 20 inputs in two banks (`A1`-`A10`, `B1`-`B10`). The shift
button sits on its own pin (`PIND & 0x80`) and is *not* one of the 20, so the
shift layer is free capacity: up to 40 functions total, with double-click
shift-lock.

`kade-pin-custom-preset0.eep` in this directory is the stock preset 0 layout,
generated with `tools/make-eep.ps1` and verified byte-for-byte against the
database:

| Terminal | Function | Terminal | Function |
|---|---|---|---|
| A1 | Start (1) | B1 | Left Nudge (Z) |
| A2 | Coin (5) | B2 | Right Nudge (/) |
| A3 | Up | B3 | Fwd Nudge (Space) |
| A4 | Down | B4 | Left Upper Flipper (A) |
| A5 | Left | B5 | Right Upper Flipper (') |
| A6 | Right | B6 | Left Magnasave (L/Ctrl) |
| A7 | Left Flipper (L/Shift) | B7 | Right Magnasave (R/Ctrl) |
| A8 | Right Flipper (R/Shift) | B8 | View Backglass (Tab) |
| A9 | Plunger (Enter) | B9 | Pause (Break) |
| A10 | Exit (ESC) | B10 | Quit VP (Q) |

The stock preset leaves the **shift layer entirely unassigned** (EEPROM
`0x14`-`0x27` are all zero), so the shift button does nothing until functions are
assigned there. Tilt (function 27) and the Williams coin-door keys (53-58) are
the obvious candidates.

Flash both images:

```sh
dfu-programmer at90usb162 erase
dfu-programmer at90usb162 flash kade-pin-custom.hex
dfu-programmer at90usb162 flash-eeprom kade-pin-custom-preset0.eep
dfu-programmer at90usb162 launch
```

### What this firmware cannot do

- **No analog plunger.** The plunger is a digital Enter keypress (function 18).
- **No accelerometer nudge.** Nudge is three digital buttons only.

Both are common in pinball cabinets and need supplementary hardware.
