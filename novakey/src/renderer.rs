//! OLED driver for the runtime-selectable NovaKey simulations.

use embedded_graphics::pixelcolor::BinaryColor;
use embedded_graphics::prelude::*;
use rmk::display::DisplayDriver;
use rmk::macros::processor;

use crate::animations::{AnimationEngine, HEIGHT, WIDTH};
use crate::output::EmitKeyEvent;
use crate::state::with_state;

const SLEEP_MS: u64 = 60_000;

#[processor(subscribe = [EmitKeyEvent], poll_interval = 40)]
pub struct OledDisplay<D: DisplayDriver<Color = BinaryColor>> {
    display: D,
    engine: AnimationEngine,
    initialized: bool,
    last_seq: u32,
    blanked: bool,
}

impl<D: DisplayDriver<Color = BinaryColor>> OledDisplay<D> {
    pub fn new(display: D) -> Self {
        Self {
            display,
            engine: AnimationEngine::new(),
            initialized: false,
            last_seq: 0,
            blanked: false,
        }
    }

    async fn on_emit_key_event(&mut self, _event: EmitKeyEvent) {}

    async fn poll(&mut self) {
        if !self.initialized {
            self.display.init().await;
            self.initialized = true;
        }

        let (mode, seed, last_activity, seq) = with_state(|state| {
            (
                state.animation_mode,
                state.seed,
                state.last_activity,
                state.activity_seq,
            )
        });
        self.engine.set_mode(mode);
        if seq != self.last_seq {
            self.last_seq = seq;
            self.engine.input(seed);
        }
        self.engine.step();

        if last_activity.elapsed().as_millis() >= SLEEP_MS {
            if !self.blanked {
                self.display.clear(BinaryColor::Off).ok();
                self.display.flush().await;
                self.blanked = true;
            }
            return;
        }
        self.blanked = false;
        self.draw();
        self.display.flush().await;
    }

    fn draw(&mut self) {
        self.display.clear(BinaryColor::Off).ok();
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                if self.engine.pixels()[y][x] {
                    Pixel(Point::new(x as i32, y as i32), BinaryColor::On)
                        .draw(&mut self.display)
                        .ok();
                }
            }
        }
    }
}
