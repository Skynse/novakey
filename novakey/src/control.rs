//! The NovaKey control engine.
//!
//! Subscribes to every raw `KeyboardEvent`, recognises the 25 physical
//! controls, and drives output. In onboard mode it emits the control's mapped
//! keycode/modifiers through [`crate::output`]; in host-capture mode it
//! forwards press/release events to NovaKey Studio and lets the host decide.
//! Encoder rotations are taps (press, then release ~10 ms later), matching
//! QMK's `ENCODER_MAP_KEY_DELAY`.

use embassy_time::{Duration, Instant};
use rmk::event::{KeyPos, KeyboardEvent, KeyboardEventPos, RotaryEncoderPos};
use rmk::macros::processor;

use crate::keymap;
use crate::output;
use crate::protocol;
use crate::state::{self, with_state};

/// Delay between the press and release of an encoder tap (QMK
/// `ENCODER_MAP_KEY_DELAY`).
const ENCODER_TAP: Duration = Duration::from_millis(10);
const PENDING_CAPACITY: usize = 8;

#[processor(subscribe = [KeyboardEvent], poll_interval = 5)]
pub struct ControlProcessor {
    /// Pending encoder releases: control id and the time to release at.
    pending: [(u8, Instant); PENDING_CAPACITY],
    pending_len: usize,
}

impl ControlProcessor {
    pub fn new() -> Self {
        Self {
            pending: [(0, Instant::from_ticks(0)); PENDING_CAPACITY],
            pending_len: 0,
        }
    }

    async fn on_keyboard_event(&mut self, event: KeyboardEvent) {
        match event.pos {
            KeyboardEventPos::Key(KeyPos { row, col }) => {
                if (row as usize) < keymap::PHYSICAL_ROWS && (col as usize) < 4 {
                    // Operating orientation: OLED/USB toward the user.
                    // Rotate matrix identity once, at the firmware boundary.
                    self.handle(15 - (row * 4 + col), event.pressed);
                } else if row == 0 && (4..=6).contains(&col) {
                    // Encoder buttons sit at row 0, columns 4..=6.
                    self.handle(16 + (col - 4) * 3, event.pressed);
                }
                // Positions in the virtual usage block are our own output.
            }
            KeyboardEventPos::RotaryEncoder(RotaryEncoderPos { id, direction }) => {
                if event.pressed {
                    let clockwise =
                        direction == rmk::input_device::rotary_encoder::Direction::Clockwise;
                    let control = 17 + id * 3 + if clockwise { 1 } else { 0 };
                    self.tap(control);
                }
            }
        }
    }

    async fn poll(&mut self) {
        let now = Instant::now();
        let mut index = 0;
        while index < self.pending_len {
            if now >= self.pending[index].1 {
                let id = self.pending[index].0;
                self.pending.copy_within(index + 1..self.pending_len, index);
                self.pending_len -= 1;
                self.handle(id, false);
            } else {
                index += 1;
            }
        }
    }

    fn tap(&mut self, id: u8) {
        self.handle(id, true);
        if self.pending_len < PENDING_CAPACITY {
            let deadline = Instant::now() + ENCODER_TAP;
            self.pending[self.pending_len] = (id, deadline);
            self.pending_len += 1;
        }
    }

    fn handle(&mut self, id: u8, pressed: bool) {
        let now = Instant::now();
        with_state(|state| {
            if pressed {
                state.seed = id;
                state.last_activity = now;
                state.activity_seq = state.activity_seq.wrapping_add(1);
            }

            if state.captured {
                let doubled = pressed
                    && state::encoder_button_for(id)
                        .is_some_and(|button| state.held[button as usize]);
                let event = protocol::control_event(id, pressed, if doubled { 2 } else { 1 });
                let _ = protocol::HID_TX.try_send(event);
                state.held[id as usize] = pressed;
                return;
            }

            if pressed {
                if state.held[id as usize] {
                    return;
                }
                state.held[id as usize] = true;
                let code = state.mapping[id as usize];
                output::emit(code, true);
                if state::encoder_button_for(id).is_some_and(|button| state.held[button as usize]) {
                    output::emit(code, false);
                    output::emit(code, true);
                }
            } else if state.held[id as usize] {
                state.held[id as usize] = false;
                let code = state.mapping[id as usize];
                output::emit(code, false);
            }
        });
    }
}
