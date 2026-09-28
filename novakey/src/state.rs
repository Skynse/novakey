//! Shared firmware state for the NovaKey control-mapping engine.
//!
//! The QMK firmware kept a 25-entry `mapping` table (keycode + modifier bits)
//! in EEPROM and reference-counted host keys. RMK's keymap is static, so the
//! dynamic table lives here and [`crate::output::Emitter`] turns mapping
//! entries into synthetic HID events through the virtual keymap block.

use core::cell::RefCell;

use embassy_sync::blocking_mutex::Mutex;
use embassy_sync::blocking_mutex::raw::CriticalSectionRawMutex;
use embassy_time::Instant;

/// Number of physical controls: 16 keys + 9 encoder controls.
pub const NUM_CONTROLS: usize = 25;

/// Size of the onboard profile in bytes (matches QMK's
/// `EECONFIG_USER_DATA_SIZE 50`).
pub const MAPPING_BYTES: usize = NUM_CONTROLS * 2;

/// Flash offset used to persist the onboard mapping (last sector of the 2 MiB
/// part, well clear of the firmware image at the start of flash).
pub const MAPPING_FLASH_OFFSET: u32 = 0x1F_0000;
/// Flash sector size on the RP2040.
pub const FLASH_SECTOR_SIZE: u32 = 4096;
/// Flash page size on the RP2040.
pub const FLASH_PAGE_SIZE: usize = 256;

/// First two bytes of the stored profile, used to detect a written record.
pub const MAPPING_MAGIC: [u8; 2] = [b'N', b'3'];

/// QMK's default onboard profile.
pub const DEFAULTS: [u16; NUM_CONTROLS] = rotated_defaults();

const fn rotated_defaults() -> [u16; NUM_CONTROLS] {
    let mut result = LEGACY_DEFAULTS;
    let mut i = 0;
    while i < 16 {
        result[i] = LEGACY_DEFAULTS[15 - i];
        i += 1;
    }
    result
}

const LEGACY_DEFAULTS: [u16; NUM_CONTROLS] = [
    0x011D, // Ctrl+Z
    0x031D, // Ctrl+Shift+Z
    0x0005, // B
    0x0008, // E
    0x000C, // I
    0x002C, // Space
    0x0116, // Ctrl+S
    0x0316, // Ctrl+Shift+S
    0x002F, // [
    0x0030, // ]
    0x0127, // Ctrl+0
    0x002B, // Tab
    0x0029, // Esc
    0x002A, // Backspace
    0x0028, // Enter
    0x0104, // Ctrl+A
    0x0005, // Encoder 1 button: B
    0x002F, // Encoder 1 CCW: [
    0x0030, // Encoder 1 CW: ]
    0x0015, // Encoder 2 button: R
    0x0050, // Encoder 2 CCW: Left
    0x004F, // Encoder 2 CW: Right
    0x002C, // Encoder 3 button: Space
    0x004B, // Encoder 3 CCW: PageUp
    0x004E, // Encoder 3 CW: PageDown
];

/// The encoder button associated with a rotation control.
pub const fn encoder_button_for(id: u8) -> Option<u8> {
    match id {
        17 | 18 => Some(16),
        20 | 21 => Some(19),
        23 | 24 => Some(22),
        _ => None,
    }
}

pub struct ControlState {
    /// Active onboard profile, one `keycode | (modifiers << 8)` per control.
    pub mapping: [u16; NUM_CONTROLS],
    /// Staging buffer for an atomic upload (commands 0x20/0x21/0x22).
    pub staged: [u16; NUM_CONTROLS],
    pub staged_mask: u32,
    /// Whether each control is currently held.
    pub held: [bool; NUM_CONTROLS],
    /// Host capture lease state.
    pub captured: bool,
    pub heartbeat: Instant,
    /// OLED animation inputs: last control that was pressed and when.
    pub seed: u8,
    pub last_activity: Instant,
    /// Increments on every physical control press so the renderer can seed
    /// only for real presses, not for host-injected output.
    pub activity_seq: u32,
    /// Active OLED simulation. Runtime-only by design.
    pub animation_mode: u8,
}

impl ControlState {
    pub const fn new() -> Self {
        Self {
            mapping: DEFAULTS,
            staged: [0; NUM_CONTROLS],
            staged_mask: 0,
            held: [false; NUM_CONTROLS],
            captured: false,
            heartbeat: Instant::from_ticks(0),
            seed: 0,
            last_activity: Instant::from_ticks(0),
            activity_seq: 0,
            animation_mode: 0,
        }
    }

    /// Reset the held flags (used when keys are force-released).
    pub fn clear_held(&mut self) {
        self.held = [false; NUM_CONTROLS];
    }
}

pub static STATE: Mutex<CriticalSectionRawMutex, RefCell<ControlState>> =
    Mutex::new(RefCell::new(ControlState::new()));

/// Run a closure with mutable access to the shared state.
pub fn with_state<R>(f: impl FnOnce(&mut ControlState) -> R) -> R {
    STATE.lock(|state| f(&mut state.borrow_mut()))
}

/// Encode a mapping table into the 50-byte flash layout.
pub fn encode_mapping(mapping: &[u16; NUM_CONTROLS], out: &mut [u8; MAPPING_BYTES]) {
    for (i, value) in mapping.iter().enumerate() {
        out[i * 2] = *value as u8;
        out[i * 2 + 1] = (*value >> 8) as u8;
    }
}

/// Decode a persisted profile. Returns `None` if the magic does not match.
pub fn decode_mapping(bytes: &[u8]) -> Option<[u16; NUM_CONTROLS]> {
    if bytes.len() < MAPPING_BYTES + 2
        || (bytes[0..2] != MAPPING_MAGIC && bytes[0..2] != [b'N', b'K'])
    {
        return None;
    }
    let mut mapping = [0u16; NUM_CONTROLS];
    for (i, slot) in mapping.iter_mut().enumerate() {
        *slot = (bytes[2 + i * 2] as u16) | ((bytes[3 + i * 2] as u16) << 8);
    }
    // Legacy records retain PCB order. New records store canonical IDs.
    if bytes[0..2] == [b'N', b'K'] {
        mapping[..16].reverse();
    }
    Some(mapping)
}
