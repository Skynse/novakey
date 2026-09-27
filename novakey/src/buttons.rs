//! Encoder push-buttons.
//!
//! The three rotary encoders each have a push switch wired directly to ground
//! (GP18, GP21, GP27) with the MCU's internal pull-up enabled. RMK has no
//! built-in "encoder button", so this small input device exposes them as
//! keyboard events at row 0, columns 4..=6 — positions the keymap leaves as
//! `No` so [`crate::control`] handles them as controls 16/19/22 instead.

use embassy_rp::gpio::Input;
use embassy_time::{Duration, Timer};
use rmk::event::KeyboardEvent;
use rmk::macros::input_device;

const BUTTON_COL_BASE: u8 = 4;

#[input_device(publish = KeyboardEvent)]
pub struct EncoderButtons {
    pins: [Input<'static>; 3],
    stable: [bool; 3],
    counters: [u8; 3],
}

impl EncoderButtons {
    pub fn new(pins: [Input<'static>; 3]) -> Self {
        Self {
            pins,
            stable: [false; 3],
            counters: [0; 3],
        }
    }

    async fn read_keyboard_event(&mut self) -> KeyboardEvent {
        loop {
            for index in 0..self.pins.len() {
                let raw = self.pins[index].is_low();
                if raw == self.stable[index] {
                    self.counters[index] = 0;
                } else {
                    self.counters[index] += 1;
                    if self.counters[index] >= 2 {
                        self.counters[index] = 0;
                        self.stable[index] = raw;
                        return KeyboardEvent::key(0, BUTTON_COL_BASE + index as u8, raw);
                    }
                }
            }
            Timer::after(Duration::from_millis(1)).await;
        }
    }
}
