mod agents;
mod cellular;
mod procedural;

pub const MODE_COUNT: u8 = 11;
pub const WIDTH: usize = 128;
pub const HEIGHT: usize = 32;

#[derive(Clone, Copy)]
pub(super) struct Particle {
    pub x: i16,
    pub y: i16,
    pub vx: i16,
    pub vy: i16,
}

#[derive(Clone, Copy)]
pub(super) struct Ant {
    pub x: u8,
    pub y: u8,
    pub direction: u8,
}

pub struct AnimationEngine {
    mode: u8,
    pub(super) frame: u32,
    pub(super) pixels: [[bool; WIDTH]; HEIGHT],
    pub(super) scratch: [[bool; WIDTH]; HEIGHT],
    pub(super) wave: [i16; WIDTH],
    pub(super) velocity: [i16; WIDTH],
    pub(super) particles: [Particle; 32],
    pub(super) ants: [Ant; 3],
    pub(super) rng: u32,
    pending_input: Option<u8>,
}

impl AnimationEngine {
    pub fn new() -> Self {
        let mut engine = Self {
            mode: 0,
            frame: 0,
            pixels: [[false; WIDTH]; HEIGHT],
            scratch: [[false; WIDTH]; HEIGHT],
            wave: [0; WIDTH],
            velocity: [0; WIDTH],
            particles: [Particle {
                x: 0,
                y: 0,
                vx: 0,
                vy: 0,
            }; 32],
            ants: [
                Ant {
                    x: 64,
                    y: 16,
                    direction: 0,
                },
                Ant {
                    x: 42,
                    y: 16,
                    direction: 1,
                },
                Ant {
                    x: 85,
                    y: 16,
                    direction: 3,
                },
            ],
            rng: 0x1234_5678,
            pending_input: None,
        };
        engine.reset(0);
        engine
    }

    pub fn set_mode(&mut self, mode: u8) {
        if mode < MODE_COUNT && mode != self.mode {
            self.reset(mode);
        }
    }

    pub fn input(&mut self, control: u8) {
        self.pending_input = Some(control);
    }

    pub fn pixels(&self) -> &[[bool; WIDTH]; HEIGHT] {
        &self.pixels
    }

    pub fn step(&mut self) {
        let input = self.pending_input.take();
        match self.mode {
            0 => procedural::wave_tank(self, input),
            1 => procedural::flow_field(self, input),
            2 => cellular::reaction(self, input),
            3 => agents::boids(self, input),
            4 => cellular::ink(self, input),
            5 => procedural::metaballs(self, input),
            6 => procedural::plasma(self, input),
            7 => cellular::rule_30(self, input),
            8 => cellular::langtons_ants(self, input),
            9 => procedural::membrane(self, input),
            _ => procedural::diagnostic(self, input),
        }
        self.frame = self.frame.wrapping_add(1);
    }

    pub(super) fn clear(&mut self) {
        self.pixels.fill([false; WIDTH]);
    }

    pub(super) fn random(&mut self) -> u32 {
        let mut x = self.rng;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.rng = x;
        x
    }

    pub(super) fn control_x(control: u8) -> usize {
        if control < 16 {
            control as usize * 8 + 4
        } else {
            116
        }
    }

    fn reset(&mut self, mode: u8) {
        self.mode = mode;
        self.frame = 0;
        self.clear();
        self.scratch.fill([false; WIDTH]);
        self.wave.fill(0);
        self.velocity.fill(0);
        for index in 0..self.particles.len() {
            let random = self.random();
            self.particles[index] = Particle {
                x: (random as usize % WIDTH) as i16 * 16,
                y: ((random >> 8) as usize % HEIGHT) as i16 * 16,
                vx: ((random >> 16) as i16 & 15) - 7,
                vy: ((random >> 24) as i16 & 7) - 3,
            };
        }
        self.ants = [
            Ant {
                x: 64,
                y: 16,
                direction: 0,
            },
            Ant {
                x: 42,
                y: 16,
                direction: 1,
            },
            Ant {
                x: 85,
                y: 16,
                direction: 3,
            },
        ];
    }
}
