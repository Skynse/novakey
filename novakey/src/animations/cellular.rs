use super::{AnimationEngine, HEIGHT, WIDTH};

pub fn reaction(engine: &mut AnimationEngine, input: Option<u8>) {
    if engine.frame == 0 {
        for y in 13..19 {
            for x in 61..67 {
                engine.pixels[y][x] = true;
            }
        }
    }
    if let Some(control) = input {
        let center = AnimationEngine::control_x(control);
        for y in 13..19 {
            for x in center.saturating_sub(3)..=(center + 3).min(WIDTH - 1) {
                engine.pixels[y][x] = true;
            }
        }
    }
    for y in 0..HEIGHT {
        for x in 0..WIDTH {
            let mut neighbors = 0;
            for dy in [-1isize, 0, 1] {
                for dx in [-1isize, 0, 1] {
                    if dx == 0 && dy == 0 {
                        continue;
                    }
                    let nx = (x as isize + dx).rem_euclid(WIDTH as isize) as usize;
                    let ny = (y as isize + dy).rem_euclid(HEIGHT as isize) as usize;
                    neighbors += engine.pixels[ny][nx] as u8;
                }
            }
            let alive = engine.pixels[y][x];
            engine.scratch[y][x] = if alive {
                (2..=5).contains(&neighbors)
            } else {
                neighbors == 3
            };
        }
    }
    core::mem::swap(&mut engine.pixels, &mut engine.scratch);
}

pub fn ink(engine: &mut AnimationEngine, input: Option<u8>) {
    if let Some(control) = input {
        let x = AnimationEngine::control_x(control);
        for y in 12..20 {
            engine.pixels[y][x] = true;
        }
    }
    engine.scratch.fill([false; WIDTH]);
    for y in 0..HEIGHT {
        let drift = ((y as i32 * 3 + engine.frame as i32) % 7) - 2;
        for x in 0..WIDTH {
            if engine.pixels[y][x] {
                let nx = (x as i32 + drift).rem_euclid(WIDTH as i32) as usize;
                let ny = (y + 1).min(HEIGHT - 1);
                engine.scratch[ny][nx] = true;
                if (x + y + engine.frame as usize) & 3 == 0 {
                    engine.scratch[y][nx] = true;
                }
            }
        }
    }
    core::mem::swap(&mut engine.pixels, &mut engine.scratch);
}

pub fn rule_30(engine: &mut AnimationEngine, input: Option<u8>) {
    if engine.frame == 0 {
        engine.wave[WIDTH / 2] = 1;
    }
    if let Some(control) = input {
        engine.wave[AnimationEngine::control_x(control)] ^= 1;
    }
    for y in 0..HEIGHT - 1 {
        engine.pixels[y] = engine.pixels[y + 1];
    }
    for x in 0..WIDTH {
        engine.pixels[HEIGHT - 1][x] = engine.wave[x] != 0;
    }
    let old = engine.wave;
    for x in 0..WIDTH {
        let left = old[(x + WIDTH - 1) % WIDTH] != 0;
        let center = old[x] != 0;
        let right = old[(x + 1) % WIDTH] != 0;
        engine.wave[x] = (left ^ (center || right)) as i16;
    }
}

pub fn langtons_ants(engine: &mut AnimationEngine, input: Option<u8>) {
    if let Some(control) = input {
        let ant = control as usize % engine.ants.len();
        engine.ants[ant].x = AnimationEngine::control_x(control) as u8;
        engine.ants[ant].y = 16;
    }
    for _ in 0..12 {
        for ant in &mut engine.ants {
            let cell = &mut engine.pixels[ant.y as usize][ant.x as usize];
            ant.direction = (ant.direction + if *cell { 3 } else { 1 }) & 3;
            *cell = !*cell;
            match ant.direction {
                0 => ant.x = ant.x.wrapping_add(1) % WIDTH as u8,
                1 => ant.y = ant.y.wrapping_add(1) % HEIGHT as u8,
                2 => ant.x = ant.x.wrapping_add(WIDTH as u8 - 1) % WIDTH as u8,
                _ => ant.y = ant.y.wrapping_add(HEIGHT as u8 - 1) % HEIGHT as u8,
            }
        }
    }
}
