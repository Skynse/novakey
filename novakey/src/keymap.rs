//! Keymap layout for the NovaKey macropad.
//!
//! RMK's keyboard core resolves every `KeyboardEvent` position through this
//! keymap. The NovaKey firmware keeps its *dynamic* per-control mapping in
//! `state`, so this keymap is a fixed translation table rather than the user's
//! configuration:
//!
//! * rows 0..=3, cols 0..=3 — the 16 physical matrix keys. Left as
//!   [`KeyAction::No`] so the keyboard core emits nothing; [`crate::control`]
//!   handles them and drives output itself.
//! * row 0, cols 4..=6 — the three encoder push-buttons. Also `No`.
//! * rows 4..=35, cols 0..=7 — a "virtual" block where position `u` emits HID
//!   usage `u` (0..=255). Dynamic mapping output and host output injection
//!   publish synthetic `KeyboardEvent`s here, so all 8-bit HID usages
//!   (including the `0xE0..=0xE7` modifiers) can be emitted at runtime.
//!
//! Encoder rotation goes through RMK's encoder map, which is all `No`; the
//! rotation directions are handled as controls 17/18, 20/21 and 23/24.

use rmk::types::action::{EncoderAction, KeyAction};
use rmk::types::keycode::{HidKeyCode, KeyCode};

pub const ROW: usize = 36;
pub const COL: usize = 8;
pub const NUM_LAYER: usize = 1;
pub const NUM_ENCODER: usize = 3;

/// First keymap row used by the virtual HID-usage translation block.
pub const USAGE_ROW_BASE: usize = 4;
/// Number of physical matrix rows.
pub const PHYSICAL_ROWS: usize = 4;

/// Map a HID usage byte to its virtual keymap position.
pub const fn usage_pos(usage: u8) -> (u8, u8) {
    let u = usage as usize;
    ((USAGE_ROW_BASE + u / COL) as u8, (u % COL) as u8)
}

/// Build the fixed translation keymap.
pub fn default_keymap() -> [[[KeyAction; COL]; ROW]; NUM_LAYER] {
    let mut keymap = [[[KeyAction::No; COL]; ROW]; NUM_LAYER];
    let mut usage = 0usize;
    while usage < 256 {
        keymap[0][USAGE_ROW_BASE + usage / COL][usage % COL] = KeyAction::Single(
            rmk::types::action::Action::Key(KeyCode::Hid(HidKeyCode::from(usage as u8))),
        );
        usage += 1;
    }
    keymap
}

/// Encoder actions are handled as controls, so the RMK encoder map is empty.
pub fn default_encoder_map() -> [[EncoderAction; NUM_ENCODER]; NUM_LAYER] {
    [[EncoderAction::default(); NUM_ENCODER]; NUM_LAYER]
}
