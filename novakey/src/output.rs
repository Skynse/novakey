//! Host-key output.
//!
//! Dynamic mapping output and host output injection both publish an
//! [`EmitKeyEvent`] carrying a QMK-style `keycode | (modifiers << 8)` value.
//! [`Emitter`] turns those into RMK `KeyboardEvent`s at the virtual
//! HID-usage positions defined in [`crate::keymap`], mirroring QMK's
//! reference-counted `key_output()`.

use rmk::event::{KeyboardEvent, publish_event};
use rmk::macros::{event, processor};

use crate::keymap::usage_pos;

/// Request to emit (or release) a keycode with modifiers.
#[event(channel_size = 64, subs = 2, pubs = 8)]
#[derive(Clone, Copy, Debug)]
pub struct EmitKeyEvent {
    pub code: u16,
    pub down: bool,
}

/// Force-release every key the firmware is currently holding.
#[event(channel_size = 8, subs = 1, pubs = 4)]
#[derive(Clone, Copy, Debug)]
pub struct ReleaseAllEvent;

/// Publish a synthetic key press/release at `code`'s virtual position.
pub fn emit(code: u16, down: bool) {
    publish_event(EmitKeyEvent { code, down });
}

/// Force-release all held host keys.
pub fn release_all() {
    publish_event(ReleaseAllEvent);
}

#[processor(subscribe = [EmitKeyEvent, ReleaseAllEvent])]
pub struct Emitter {
    /// Reference count of each held HID usage (0..=255).
    host_keys: [u8; 256],
}

impl Emitter {
    pub fn new() -> Self {
        Self {
            host_keys: [0; 256],
        }
    }

    async fn on_emit_key_event(&mut self, event: EmitKeyEvent) {
        self.emit(event.code, event.down);
    }

    async fn on_release_all_event(&mut self, _event: ReleaseAllEvent) {
        self.release_all();
    }
}

impl Emitter {
    fn set_usage(&mut self, usage: u8, down: bool) {
        let index = usage as usize;
        if down {
            if self.host_keys[index] == 0 {
                let (row, col) = usage_pos(usage);
                publish_event(KeyboardEvent::key(row, col, true));
            }
            self.host_keys[index] = self.host_keys[index].saturating_add(1);
        } else if self.host_keys[index] > 0 {
            self.host_keys[index] -= 1;
            if self.host_keys[index] == 0 {
                let (row, col) = usage_pos(usage);
                publish_event(KeyboardEvent::key(row, col, false));
            }
        }
    }

    fn emit(&mut self, code: u16, down: bool) {
        let keycode = (code & 0xff) as u8;
        let modifiers = ((code >> 8) & 0x0f) as u8;

        if down {
            for bit in 0..4 {
                if modifiers & (1 << bit) != 0 {
                    self.set_usage(0xE0 + bit, true);
                }
            }
            if keycode != 0 {
                self.set_usage(keycode, true);
            }
        } else {
            if keycode != 0 {
                self.set_usage(keycode, false);
            }
            for bit in 0..4 {
                if modifiers & (1 << bit) != 0 {
                    self.set_usage(0xE0 + bit, false);
                }
            }
        }
    }

    fn release_all(&mut self) {
        for usage in 0..256u16 {
            if self.host_keys[usage as usize] > 0 {
                let (row, col) = usage_pos(usage as u8);
                publish_event(KeyboardEvent::key(row, col, false));
                self.host_keys[usage as usize] = 0;
            }
        }
    }
}
