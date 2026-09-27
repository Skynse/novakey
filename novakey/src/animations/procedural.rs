use super::{AnimationEngine, HEIGHT, WIDTH};

fn triangle(value: i32, period: i32, amplitude: i32) -> i32 {
    let phase = value.rem_euclid(period);
    let half = period / 2;
    ((half - (phase - half).abs()) * amplitude * 2 / half) - amplitude
}

pub fn wave_tank(engine: &mut AnimationEngine, input: Option<u8>) {
    if let Some(control) = input {
        let x = AnimationEngine::control_x(control);
        engine.velocity[x] = if control & 1 == 0 { 150 } else { -150 };
    }
    let mut next_velocity = [0i16; WIDTH];
    for x in 1..WIDTH - 1 {
        let curvature = engine.wave[x - 1] + engine.wave[x + 1] - 2 * engine.wave[x];
        next_velocity[x] = ((engine.velocity[x] as i32 * 242 + curvature as i32 * 42) / 256) as i16;
    }
    engine.velocity = next_velocity;
    for x in 0..WIDTH {
        engine.wave[x] = (engine.wave[x] + engine.velocity[x]).clamp(-240, 240);
    }
    engine.clear();
    for x in 0..WIDTH {
        let y = (HEIGHT as i16 / 2 + engine.wave[x] / 18).clamp(1, HEIGHT as i16 - 2) as usize;
        engine.pixels[y][x] = true;
        if x > 0 && (engine.wave[x] - engine.wave[x - 1]).abs() > 20 {
            engine.pixels[(y + 1).min(HEIGHT - 1)][x] = true;
        }
    }
}

pub fn flow_field(engine: &mut AnimationEngine, input: Option<u8>) {
    if let Some(control) = input {
        let base = control as usize % engine.particles.len();
        for offset in 0..5 {
            let random = engine.random();
            engine.particles[(base + offset) % 32].x =
                AnimationEngine::control_x(control) as i16 * 16;
            engine.particles[(base + offset) % 32].y = (random as usize % HEIGHT) as i16 * 16;
        }
    }
    for row in &mut engine.pixels {
        for pixel in row {
            *pixel = false;
        }
    }
    for particle in &mut engine.particles {
        let x = particle.x / 16;
        let y = particle.y / 16;
        let curl = triangle(x as i32 + engine.frame as i32, 31, 5)
            + triangle(y as i32 * 3 - engine.frame as i32, 23, 4);
        particle.vx = (particle.vx + curl as i16).clamp(-24, 24);
        particle.vy = (particle.vy + triangle(x as i32, 19, 3) as i16).clamp(-13, 13);
        particle.x = (particle.x + particle.vx).rem_euclid((WIDTH * 16) as i16);
        particle.y = (particle.y + particle.vy).rem_euclid((HEIGHT * 16) as i16);
        engine.pixels[(particle.y / 16) as usize][(particle.x / 16) as usize] = true;
    }
}

pub fn metaballs(engine: &mut AnimationEngine, input: Option<u8>) {
    let impulse = input.map(AnimationEngine::control_x).unwrap_or(WIDTH / 2) as i32;
    for y in 0..HEIGHT {
        for x in 0..WIDTH {
            let mut field = 0i32;
            for index in 0..4 {
                let cx = 64
                    + triangle(
                        engine.frame as i32 * (index + 2) + index * 19,
                        113 - index * 7,
                        50,
                    );
                let cy = 16
                    + triangle(
                        engine.frame as i32 * (index + 3) + index * 11,
                        47 - index * 3,
                        12,
                    );
                let dx = x as i32
                    - if input.is_some() && index == 0 {
                        impulse
                    } else {
                        cx
                    };
                let dy = y as i32 - cy;
                field += 900 / (dx * dx + dy * dy + 12);
            }
            engine.pixels[y][x] = (45..115).contains(&field);
        }
    }
}

pub fn plasma(engine: &mut AnimationEngine, input: Option<u8>) {
    let phase = engine.frame as i32 * 2 + input.unwrap_or(0) as i32 * 9;
    const BAYER: [[i32; 4]; 4] = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
    for y in 0..HEIGHT {
        for x in 0..WIDTH {
            let value = triangle(x as i32 + phase, 37, 6)
                + triangle(y as i32 * 3 - phase, 29, 5)
                + triangle(x as i32 + y as i32 * 2 + phase, 53, 5)
                + 8;
            engine.pixels[y][x] = value > BAYER[y & 3][x & 3];
        }
    }
}

pub fn membrane(engine: &mut AnimationEngine, input: Option<u8>) {
    if let Some(control) = input {
        engine.velocity[AnimationEngine::control_x(control)] = 180;
    }
    let mut next = [0i16; WIDTH];
    for x in 1..WIDTH - 1 {
        let curvature = engine.wave[x - 1] + engine.wave[x + 1] - 2 * engine.wave[x];
        next[x] = ((engine.velocity[x] as i32 * 246 + curvature as i32 * 34) / 256) as i16;
    }
    engine.velocity = next;
    for x in 0..WIDTH {
        engine.wave[x] = (engine.wave[x] + engine.velocity[x]).clamp(-256, 256);
    }
    for y in 0..HEIGHT {
        for x in 0..WIDTH {
            let surface = 16 + engine.wave[x] as i32 / 20;
            let shade = ((x ^ y) & 3) as i32;
            engine.pixels[y][x] = y as i32 >= surface && ((y as i32 - surface + shade) & 3) < 2;
        }
    }
}

pub fn diagnostic(engine: &mut AnimationEngine, _input: Option<u8>) {
    engine.clear();
    // Four simple two-second phases. These isolate panel addressing without
    // aliasing, motion blur, or a pattern that can itself look corrupted.
    match (engine.frame / 50) & 3 {
        0 => engine.pixels.fill([true; WIDTH]),
        1 => engine.pixels[..HEIGHT / 2].fill([true; WIDTH]),
        2 => engine.pixels[HEIGHT / 2..].fill([true; WIDTH]),
        _ => {
            for x in 0..WIDTH {
                engine.pixels[0][x] = true;
                engine.pixels[HEIGHT - 1][x] = true;
            }
            for y in 0..HEIGHT {
                engine.pixels[y][0] = true;
                engine.pixels[y][WIDTH - 1] = true;
            }
        }
    }
}
