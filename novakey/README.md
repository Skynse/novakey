# NovaKey firmware (RMK)

This is NovaKey's RMK firmware for the RP2040 macropad.

## Hardware map

| Function           | Pins                          |
| ------------------ | ----------------------------- |
| Matrix rows (read) | GP5, GP6, GP7, GP8            |
| Matrix cols (drive)| GP1, GP2, GP3, GP4            |
| Encoder 1          | GP16 / GP17, button GP18      |
| Encoder 2          | GP19 / GP20, button GP21      |
| Encoder 3          | GP22 / GP26, button GP27      |
| OLED SSD1306       | I2C1, SDA GP10, SCL GP11, 0x3C |

The matrix is diode `COL2ROW`, matching QMK. Encoder buttons are wired
directly to ground with the internal pull-up enabled.

Controls are numbered exactly as QMK's `mapping[25]` table:

| Ids    | Control                                        |
| ------ | ---------------------------------------------- |
| 0..15  | Matrix keys, row-major                         |
| 16     | Encoder 1 button                               |
| 17, 18 | Encoder 1 counter-clockwise / clockwise        |
| 19     | Encoder 2 button                               |
| 20, 21 | Encoder 2 counter-clockwise / clockwise        |
| 22     | Encoder 3 button                               |
| 23, 24 | Encoder 3 counter-clockwise / clockwise        |

## Host protocol

The firmware exposes a raw-HID interface with usage page `0xFF60`, usage
`0x4B`, and 32-byte unnumbered IN/OUT reports byte-for-byte the same report
descriptor as QMK. Supported commands:

- `0x01` ping / heartbeat
- `0x02` device information (protocol 2, 16 keys, 3 encoders, 25 controls)
- `0x10` host-capture lease; `0x11` output a keycode+modifiers; `0x12` release all
- `0x20`/`0x21`/`0x22` atomic onboard-profile upload
- `0x30` reboot to the RP2040 USB bootloader (requires payload `BOOT`)
- `0x31` get/set the SRAM-backed OLED simulation (`0xFF` queries, `0..9` sets)
- `0x40` device→host control events (press/release, with a combination flag)

The onboard profile is stored in the last flash sector (`0x1F0000`) as a
50-byte table with an `NK` magic, equivalent to QMK's EEPROM user datablock.

## Build

```sh
./build.sh
```

This builds the release binary and writes `build/novakey.uf2` (using
`tools/uf2.py`, since `elf2uf2`/`picotool` are not assumed to be installed).
For the first installation, hold BOOTSEL while connecting the Pico, then copy
the UF2 onto the `RPI-RP2` drive. Once this firmware is installed, later builds
and flashes need no physical button:

```sh
./flash.sh
```

`flash.sh` builds the firmware, tells the running NovaKey to enter its ROM USB
bootloader, mounts `RPI-RP2` through `udisksctl` when necessary, and copies the
UF2. Pass an existing UF2 path to skip the build: `./flash.sh file.uf2`.

To flash over SWD instead:

```sh
cargo run --release    # probe-rs, chip RP2040
```

Requires the `thumbv6m-none-eabi` target.

## Architecture

RMK's keymap is static, while NovaKey's mapping is dynamic, so the firmware
splits responsibilities:

- **`keymap.rs`** — a fixed translation table. The 16 physical keys and 3
  encoder buttons resolve to `No`; a virtual block (rows 4..=35) maps each
  position to HID usage `0..=255`, so any basic keycode (including the
  `0xE0..=0xE7` modifiers) can be emitted at runtime.
- **`state.rs`** — the shared `mapping[25]`, staging buffer, held flags and
  capture-lease state, plus flash encode/decode helpers.
- **`control.rs`** — subscribes to raw `KeyboardEvent`s, recognises the 25
  controls, and either emits the onboard mapping or forwards to the host.
  Encoder rotations are taps (press, release 10 ms later). Holding an encoder
  button doubles its turn action.
- **`encoders.rs`** — continuously samples all three quadrature encoders without
  pausing for synthetic key releases. It uses two stable samples per state and
  two valid transitions per physical detent, while allowing immediate direction
  changes.
- **`output.rs`** — reference-counted host-key emitter (QMK's `key_output`),
  turning `keycode | (modifiers << 8)` into synthetic HID events.
- **`protocol.rs`** — the raw-HID command handler, control-event stream,
  capture-lease timeout and profile persistence.
- **`buttons.rs`** — the encoder push-buttons, which RMK has no built-in
  support for, exposed as `KeyboardEvent`s.
- **`renderer.rs`** — owns the OLED and draws the active animation frame; the
  panel blanks after 60 s idle.
- **`animations/`** — ten input-reactive 128×32 simulations: wave tank, flow
  field, reaction–diffusion, boids, ink, metaballs, plasma, Rule 30, Langton’s
  ants, a damped membrane, and a full-panel diagnostic. The selected mode lives
  only in SRAM and resets to wave tank after restart or power loss.
