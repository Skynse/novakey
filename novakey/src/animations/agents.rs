use super::{AnimationEngine, HEIGHT, WIDTH};

pub fn boids(engine: &mut AnimationEngine, input: Option<u8>) {
    let attractor = input.map(AnimationEngine::control_x);
    for index in 0..engine.particles.len() {
        let particle = engine.particles[index];
        let mut center_x = 0i32;
        let mut center_y = 0i32;
        let mut count = 0i32;
        for other in &engine.particles {
            let dx = other.x as i32 - particle.x as i32;
            let dy = other.y as i32 - particle.y as i32;
            if dx * dx + dy * dy < 300 * 300 {
                center_x += other.x as i32;
                center_y += other.y as i32;
                count += 1;
            }
        }
        let p = &mut engine.particles[index];
        if count > 0 {
            p.vx += ((center_x / count - p.x as i32) / 80) as i16;
            p.vy += ((center_y / count - p.y as i32) / 80) as i16;
        }
        if let Some(x) = attractor {
            p.vx += ((x as i32 * 16 - p.x as i32) / 100) as i16;
        }
        p.vx = p.vx.clamp(-24, 24);
        p.vy = p.vy.clamp(-14, 14);
        p.x = (p.x + p.vx).rem_euclid((WIDTH * 16) as i16);
        p.y = (p.y + p.vy).rem_euclid((HEIGHT * 16) as i16);
    }
    engine.clear();
    for particle in &engine.particles {
        let x = (particle.x / 16) as usize;
        let y = (particle.y / 16) as usize;
        engine.pixels[y][x] = true;
        engine.pixels[y][(x + WIDTH - 1) % WIDTH] = true;
    }
}
