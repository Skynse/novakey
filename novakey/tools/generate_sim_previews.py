#!/usr/bin/env python3
"""Generate animated 128x32 monochrome OLED simulation previews."""

from pathlib import Path
import math
import random

import numpy as np
from PIL import Image

W, H, FRAMES, SCALE = 128, 32, 64, 4
OUT = Path(__file__).resolve().parents[1] / "simulation_previews"
RNG = random.Random(2409)


def display(bits):
    rgb = np.zeros((H, W, 3), dtype=np.uint8)
    rgb[:] = (3, 9, 12)
    rgb[bits] = (210, 245, 255)
    return Image.fromarray(rgb).resize((W * SCALE, H * SCALE), Image.Resampling.NEAREST)


def save(name, frames):
    images = [display(frame.astype(bool)) for frame in frames]
    images[0].save(
        OUT / f"{name}.gif",
        save_all=True,
        append_images=images[1:],
        duration=55,
        loop=0,
        optimize=True,
    )


def wave_tank():
    u = np.zeros((H, W), np.float32)
    previous = u.copy()
    yy, xx = np.mgrid[:H, :W]
    out = []
    for frame in range(FRAMES):
        if frame % 11 == 0:
            x = [18, 45, 76, 108][(frame // 11) % 4]
            impulse = np.exp(-((xx - x) ** 2 + (yy - H // 2) ** 2) / 15)
            u += impulse * 1.8
        lap = np.roll(u, 1, 0) + np.roll(u, -1, 0) + np.roll(u, 1, 1) + np.roll(u, -1, 1) - 4 * u
        nxt = (2 * u - previous + 0.23 * lap) * 0.986
        previous, u = u, nxt
        out.append((np.abs(u) > 0.09) ^ (np.abs(u) > 0.25))
    return out


def flow_field():
    particles = np.array([[RNG.randrange(W), RNG.randrange(H)] for _ in range(95)], np.float32)
    trails = np.zeros((H, W), np.float32)
    out = []
    for frame in range(FRAMES):
        x, y = particles[:, 0], particles[:, 1]
        angle = np.sin(y * 0.19 + frame * 0.05) * 1.8 + np.cos(x * 0.07 - frame * 0.03)
        particles[:, 0] = (x + np.cos(angle) * 1.35) % W
        particles[:, 1] = (y + np.sin(angle) * 0.75) % H
        trails *= 0.77
        trails[particles[:, 1].astype(int), particles[:, 0].astype(int)] = 1
        out.append(trails > 0.16)
    return out


def reaction_diffusion():
    a = np.ones((H, W), np.float32)
    b = np.zeros((H, W), np.float32)
    b[12:20, 60:68] = 1
    b[7:11, 22:28] = 0.8
    out = []
    for frame in range(FRAMES):
        if frame in (20, 40):
            x = 20 + frame * 2
            b[13:19, x:x + 5] = 1
        for _ in range(6):
            la = (np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1) - 4 * a)
            lb = (np.roll(b, 1, 0) + np.roll(b, -1, 0) + np.roll(b, 1, 1) + np.roll(b, -1, 1) - 4 * b)
            reaction = a * b * b
            a += 0.18 * la - reaction + 0.0367 * (1 - a)
            b += 0.09 * lb + reaction - (0.0367 + 0.0649) * b
            np.clip(a, 0, 1, out=a)
            np.clip(b, 0, 1, out=b)
        out.append((b > 0.18) & (b < 0.55))
    return out


def boids():
    count = 34
    pos = np.array([[RNG.random() * W, RNG.random() * H] for _ in range(count)], np.float32)
    vel = np.array([[RNG.uniform(-1, 1), RNG.uniform(-.4, .4)] for _ in range(count)], np.float32)
    out = []
    for frame in range(FRAMES):
        for i in range(count):
            delta = pos - pos[i]
            delta[:, 0] = (delta[:, 0] + W / 2) % W - W / 2
            delta[:, 1] = (delta[:, 1] + H / 2) % H - H / 2
            dist = np.sqrt((delta * delta).sum(1))
            near = (dist > 0) & (dist < 17)
            close = (dist > 0) & (dist < 5)
            if near.any():
                vel[i] += (vel[near].mean(0) - vel[i]) * .035 + delta[near].mean(0) * .002
            if close.any():
                vel[i] -= delta[close].mean(0) * .025
        speed = np.linalg.norm(vel, axis=1)
        vel *= (np.minimum(speed, 1.8) / np.maximum(speed, .01))[:, None]
        pos = (pos + vel) % (W, H)
        bits = np.zeros((H, W), bool)
        for (x, y), (vx, vy) in zip(pos, vel):
            xi, yi = int(x), int(y)
            bits[yi % H, xi % W] = 1
            bits[(yi - int(np.sign(vy))) % H, (xi - int(np.sign(vx))) % W] = 1
        out.append(bits)
    return out


def ink_flow():
    density = np.zeros((H, W), np.float32)
    yy, xx = np.mgrid[:H, :W]
    out = []
    for frame in range(FRAMES):
        if frame % 8 == 0:
            x = [15, 48, 82, 114][(frame // 8) % 4]
            density += np.exp(-((xx - x) ** 2 + (yy - 16) ** 2) / 10)
        shift = np.rint(np.sin(np.arange(H) * .38 + frame * .12) * 2).astype(int)
        advected = np.empty_like(density)
        for y in range(H):
            advected[y] = np.roll(density[y], 1 + shift[y])
        density = (advected + np.roll(advected, 1, 0) + np.roll(advected, -1, 0)) / 3 * .94
        threshold = ((xx + yy * 3) & 7) / 9 + .08
        out.append(density > threshold)
    return out


def metaballs():
    yy, xx = np.mgrid[:H, :W]
    out = []
    for frame in range(FRAMES):
        field = np.zeros((H, W), np.float32)
        for i in range(6):
            x = W / 2 + math.sin(frame * (.035 + i * .003) + i) * (48 - i * 3)
            y = H / 2 + math.cos(frame * (.055 - i * .002) + i * 1.7) * (11 - i * .7)
            field += (32 + i * 5) / ((xx - x) ** 2 + (yy - y) ** 2 + 4)
        out.append((field > .62) ^ (field > 1.25))
    return out


def plasma():
    yy, xx = np.mgrid[:H, :W]
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16
    dither = np.tile(bayer, (H // 4, W // 4))
    out = []
    for frame in range(FRAMES):
        value = (
            np.sin(xx * .095 + frame * .11)
            + np.sin(yy * .31 - frame * .08)
            + np.sin(np.hypot(xx - 64 + math.sin(frame * .05) * 20, yy - 16) * .19 - frame * .13)
        ) / 6 + .5
        out.append(value > dither)
    return out


def cellular_automaton():
    screen = np.zeros((H, W), bool)
    row = np.zeros(W, bool)
    row[W // 2] = 1
    out = []
    for frame in range(FRAMES):
        for _ in range(2):
            screen[:-1] = screen[1:]
            screen[-1] = row
            left, right = np.roll(row, 1), np.roll(row, -1)
            row = left ^ (row | right)  # Rule 30
        out.append(screen.copy())
    return out


def langtons_ants():
    grid = np.zeros((H, W), bool)
    ants = [[W // 2, H // 2, 0], [W // 3, H // 2, 1], [W * 2 // 3, H // 2, 3]]
    out = []
    for frame in range(FRAMES):
        for _ in range(45):
            for ant in ants:
                x, y, direction = ant
                direction = (direction + (1 if not grid[y, x] else -1)) % 4
                grid[y, x] = ~grid[y, x]
                dx, dy = ((1, 0), (0, 1), (-1, 0), (0, -1))[direction]
                ant[:] = [(x + dx) % W, (y + dy) % H, direction]
        bits = grid.copy()
        for x, y, _ in ants:
            bits[y, x] = 1
        out.append(bits)
    return out


def membrane():
    u = np.zeros((H, W), np.float32)
    velocity = np.zeros_like(u)
    yy, xx = np.mgrid[:H, :W]
    out = []
    for frame in range(FRAMES):
        if frame % 13 == 0:
            x = [10, 39, 71, 102][(frame // 13) % 4]
            u += np.exp(-((xx - x) ** 2 + (yy - 16) ** 2) / 18) * 2.5
        lap = np.roll(u, 1, 0) + np.roll(u, -1, 0) + np.roll(u, 1, 1) + np.roll(u, -1, 1) - 4 * u
        velocity = (velocity + lap * .16) * .975
        u += velocity
        gx = np.roll(u, -1, 1) - np.roll(u, 1, 1)
        gy = np.roll(u, -1, 0) - np.roll(u, 1, 0)
        light = gx * -.7 + gy * -.4
        checker = ((xx ^ yy) & 3) / 9 - .12
        out.append(light > checker)
    return out


SIMS = [
    ("01_wave_tank", "Wave tank", wave_tank),
    ("02_flow_field", "Particle flow field", flow_field),
    ("03_reaction_diffusion", "Reaction–diffusion", reaction_diffusion),
    ("04_boids", "Boids", boids),
    ("05_ink_flow", "Fluid-like ink", ink_flow),
    ("06_metaballs", "Metaballs", metaballs),
    ("07_plasma", "Dithered plasma", plasma),
    ("08_rule_30", "Rule 30", cellular_automaton),
    ("09_langtons_ants", "Langton’s ants", langtons_ants),
    ("10_membrane", "Damped membrane", membrane),
]


def main():
    OUT.mkdir(exist_ok=True)
    for filename, title, simulation in SIMS:
        print(f"Rendering {title}…")
        save(filename, simulation())
    cards = "\n".join(
        f'<figure><img src="{filename}.gif"><figcaption>{index}. {title}</figcaption></figure>'
        for index, (filename, title, _) in enumerate(SIMS, 1)
    )
    (OUT / "index.html").write_text(f"""<!doctype html>
<meta charset="utf-8"><title>NovaKey OLED simulations</title>
<style>
body{{margin:32px;background:#070b0d;color:#d2f5ff;font:15px system-ui}}
h1{{font-size:22px}}main{{display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:22px}}
figure{{margin:0;padding:14px;background:#10181c;border:1px solid #26383f;border-radius:10px}}
img{{display:block;width:512px;max-width:100%;image-rendering:pixelated}}figcaption{{margin-top:10px}}
</style><h1>NovaKey OLED simulation studies · 128×32</h1><main>{cards}</main>""")
    print(f"Wrote {len(SIMS)} previews to {OUT}")


if __name__ == "__main__":
    main()
