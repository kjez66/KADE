# KADE — fork with a modern flashing workflow

A fork of [kadevice/KADE](https://github.com/kadevice/KADE), the open-source
arcade encoder. Upstream stopped in 2014; see [`README.txt`](README.txt) for the
original project's own words.

This fork adds what is needed to program a Kickstarter-era KADE from a current
Windows machine, without the original loader.

## The problem

The stock KADE Loader cannot program a board on 64-bit Windows 10 or 11:

- It bundles an Atmel DFU driver dated `08/28/2009` (`atmel_usb_dfu.inf`,
  libusb-win32 `0.1.12.1`). Kernel drivers of that vintage cannot load on x64
  Windows since 10 1607. The installer runs `dpinst64 /F /LM` and reports
  success; the device still lands on **Code 28, `CM_PROB_FAILED_INSTALL`**.
- The loader itself is a Python 2.6 / wxPython application, frozen with py2exe
  and last built in April 2014.
- Its firmware images are not files. They live in a SQLite database
  (`open software/loader/sources/data`), so there is nothing to flash by hand.

None of this affects a board that is *already* programmed. KADE mappings are
compiled into the firmware and flashed over USB DFU; nothing runs on the host at
runtime, and a programmed board enumerates as a standard USB HID device on any
modern OS. The 2014 software is only in the way when you want to *change* a
mapping.

## What this fork adds

| Path | Contents |
|---|---|
| [`firmware/at90usb162/`](firmware/at90usb162/) | All 25 `minimus`-family firmware images as `.hex`, extracted from the loader database and checksum-verified, plus a ready-made pinball EEPROM mapping |
| [`tools/`](tools/) | PowerShell scripts to query the loader database and to generate EEPROM mapping images |

The tools drive `winsqlite3.dll`, which ships with Windows, so there is nothing
to install — no Python, no SQLite.

> **Gotcha worth knowing:** the loader database stores text as **UTF-16LE**
> (header offset 56 = `0x02`). Searching the file for ASCII strings finds
> nothing, which makes it look encrypted or scrubbed. It is neither.

## Flashing a board

Verified end to end on a Kickstarter KADE miniArcade (AT90USB162) under Windows
11 Pro 26200.

**1. Bind a driver.** In DFU mode the board enumerates as
`USB\VID_03EB&PID_2FFA`. Use [Zadig](https://zadig.akeo.ie/):
*Options → List All Devices*, select `AT90USB162 DFU`, confirm the USB ID reads
`03EB 2FFA`, choose **WinUSB**, install.

WinUSB specifically: [dfu-programmer](https://dfu-programmer.github.io/) 1.1.0
links libusb-1.0, whose Windows backend expects it.

**2. Check it worked.** This one command is the whole fix:

```sh
dfu-programmer at90usb162 get bootloader-version
# before Zadig: "dfu-programmer: no device present."
# after:        "Bootloader Version: 0x05 (5)"
```

**3. Flash.**

```sh
dfu-programmer at90usb162 erase
dfu-programmer at90usb162 flash firmware/at90usb162/kade-mame.hex
dfu-programmer at90usb162 launch
```

Then **unplug and replug the board**. After `launch` the DFU device disappears,
but the application device does not appear until a physical power cycle.

The DFU bootloader sits in a write-protected boot section that `dfu-programmer`
cannot erase, so this is not a brickable operation — re-enter DFU (hold HWB, tap
RESET, release HWB) and flash something else.

### Custom mappings

The `*-custom` and `-extended` firmwares also read a 40-byte input map from
EEPROM. Generate it instead of using the GUI:

```powershell
.\tools\make-eep.ps1 -Database "open software\loader\sources\data" `
                     -System kade-pin-custom -Preset 0 `
                     -Out firmware\at90usb162\kade-pin-custom-preset0.eep
```

```sh
dfu-programmer at90usb162 flash-eeprom --force <file>.eep
```

`--force` is needed whenever the EEPROM is not blank. **Read the old contents
first** (`dfu-programmer at90usb162 read --eeprom`) if the board has a
configuration worth keeping.

Note that `read` fails on a programmed chip ("Memory read error") because the
bootloader's security bit blocks it. Reads only succeed after an `erase`, so
flash cannot be backed up, only EEPROM.

## Hardware notes

The Kickstarter KADE is **two boards**. The KADE PCB is entirely passive — its
whole BOM is two 12-pin headers and ten screw terminals, with no USB connector
and no active components. All the intelligence, and the USB plug, are on a
socketed [Minimus AVR](http://minimususb.com/) daughterboard (AT90USB162 or
ATmega32U2).

Consequences:

- **Program the Minimus alone.** The PCB plays no part; it need not be attached.
- **The brain is replaceable.** The daughterboard lifts out of its sockets.
- **Mount it so HWB and RESET stay reachable**, or changing a mapping means
  dismantling the cabinet.

Firmware sets all pins to input with internal pull-ups on (`DDRx=0x00`,
`PORTx=0xFF`), so disconnected inputs read high and never produce phantom
presses.

**Inputs:** 20, in two banks — `A1`–`A10` and `B1`–`B10`. The shift button has
its own pin (`PIND & 0x80`) and is *not* one of the 20, so the shift layer is
free capacity: up to 40 functions, with double-click shift-lock.

## Pinball cabinets

`kade-pin` is marked `Removed` upstream. **`kade-pin-custom`** is the pinball
firmware to use; its 61-function library targets Visual Pinball and Future
Pinball. See [`firmware/at90usb162/README.md`](firmware/at90usb162/README.md)
for the terminal-by-terminal preset 0 layout.

Two limits to plan around before wiring a cabinet:

- **No analog plunger.** The plunger is a digital Enter keypress.
- **No accelerometer nudge.** Nudge is three digital buttons.

Both are common in pinball builds and need supplementary hardware — typically a
second USB board alongside the KADE, which is a normal arrangement.

## Is the old hardware still worth using?

For a cabinet's digital buttons, yes. An AT90USB162 running LUFA and an RP2040
running GP2040-CE both sit at the 1 ms full-speed USB HID polling floor; there is
no latency to win by replacing the board.

Replace it if you want what the 2014 firmware genuinely cannot do — PS4/PS5/
Switch/Xbox One support, SOCD cleaning, or reconfiguration without reflashing.
"It is from 2012" is not by itself a reason.

## Licence

Unchanged from upstream: software GPLv3, hardware CC BY-SA 3.0. The firmware
images here are extracted from GPLv3 software and carry the same terms.
