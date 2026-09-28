//! Non-blocking quadrature decoder for NovaKey's three rotary encoders.
//!
//! RMK's generic encoder emits keyboard-style press/release pairs and pauses
//! GPIO sampling while it delays the release. NovaKey schedules tap releases
//! in `ControlProcessor`, so this input device only decodes A/B transitions
//! and publishes direction presses. Sampling therefore continues immediately
//! after every event.

use embassy_rp::gpio::Input;
use embassy_time::{Duration, Timer};
use rmk::event::KeyboardEvent;
use rmk::input_device::rotary_encoder::Direction;
use rmk::macros::input_device;

const ENCODER_COUNT: usize = 3;
// Transitions per physical detent. Encoder 2 produces a full four-edge
// cycle; half-cycle decoding emitted two taps for each click. Keep the
// existing calibration for encoders 1 and 3 until measured independently.
const RESOLUTION: [i8; ENCODER_COUNT] = [2, 4, 2];
const STABLE_SAMPLES: u8 = 2;
const TRANSITION: [i8; 16] = [0, -1, 1, 0, 1, 0, 0, -1, -1, 0, 0, 1, 0, 1, -1, 0];

#[input_device(publish = KeyboardEvent)]
pub struct Encoders {
    pins: [(Input<'static>, Input<'static>); ENCODER_COUNT],
    stable: [u8; ENCODER_COUNT],
    candidate: [u8; ENCODER_COUNT],
    candidate_count: [u8; ENCODER_COUNT],
    pulses: [i8; ENCODER_COUNT],
}

impl Encoders {
    pub fn new(pins: [(Input<'static>, Input<'static>); ENCODER_COUNT]) -> Self {
        let mut encoders = Self {
            pins,
            stable: [0; ENCODER_COUNT],
            candidate: [0; ENCODER_COUNT],
            candidate_count: [0; ENCODER_COUNT],
            pulses: [0; ENCODER_COUNT],
        };
        for index in 0..ENCODER_COUNT {
            let state = encoders.read_state(index);
            encoders.stable[index] = state;
            encoders.candidate[index] = state;
        }
        encoders
    }

    fn read_state(&self, index: usize) -> u8 {
        let (a, b) = &self.pins[index];
        u8::from(a.is_low()) | (u8::from(b.is_low()) << 1)
    }

    fn update(&mut self, index: usize) -> Direction {
        let sample = self.read_state(index);
        if sample != self.candidate[index] {
            self.candidate[index] = sample;
            self.candidate_count[index] = 1;
            return Direction::None;
        }
        if self.candidate_count[index] < STABLE_SAMPLES {
            self.candidate_count[index] += 1;
        }
        if self.candidate_count[index] < STABLE_SAMPLES || sample == self.stable[index] {
            return Direction::None;
        }

        let previous = self.stable[index];
        self.stable[index] = sample;
        let transition = previous | (sample << 2);
        let pulse = TRANSITION[transition as usize];
        if pulse == 0 {
            // A diagonal jump skipped an edge, so discard the incomplete path
            // instead of carrying uncertainty into the next detent.
            self.pulses[index] = 0;
            return Direction::None;
        }

        self.pulses[index] += pulse;
        if self.pulses[index] >= RESOLUTION[index] {
            self.pulses[index] = 0;
            Direction::CounterClockwise
        } else if self.pulses[index] <= -RESOLUTION[index] {
            self.pulses[index] = 0;
            Direction::Clockwise
        } else {
            Direction::None
        }
    }

    async fn read_keyboard_event(&mut self) -> KeyboardEvent {
        loop {
            for index in 0..ENCODER_COUNT {
                let direction = self.update(index);
                if direction != Direction::None {
                    return KeyboardEvent::rotary_encoder(index as u8, direction, true);
                }
            }
            Timer::after(Duration::from_millis(1)).await;
        }
    }
}
