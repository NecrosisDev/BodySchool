"""Paints the Body school's icon sheet (thmbdyico1) cell 1, Stone Skin: an original,
procedural image. A head and shoulders of grey stone plates, lit from the upper left,
inside the black disc the game's power icons sit in. Nothing is copied from the game.
Needs only Pillow.

    python -X utf8 -B icon.py out.png
"""
import math
import random
import sys

from PIL import Image, ImageFilter

CELL = 512
SEED = 0x10301


def draw() -> Image.Image:
    rng = random.Random(SEED)
    # Plate centres over the cell (a jittered grid), for a Voronoi of rock plates.
    step = 46
    points = [(x * step + rng.uniform(6, step - 6), y * step + rng.uniform(6, step - 6), rng.uniform(.75, 1.1))
              for y in range(CELL // step + 2) for x in range(CELL // step + 2)]
    grid = {}
    for i, (px, py, _) in enumerate(points):
        grid.setdefault((int(px // step), int(py // step)), []).append(i)

    def plates(x: float, y: float):
        """(distance to the nearest plate edge, shade of that plate)."""
        cx, cy = int(x // step), int(y // step)
        near = [i for gx in range(cx - 1, cx + 2) for gy in range(cy - 1, cy + 2) for i in grid.get((gx, gy), [])]
        near.sort(key=lambda i: (points[i][0] - x) ** 2 + (points[i][1] - y) ** 2)
        a, b = points[near[0]], points[near[1]]
        ex, ey = b[0] - a[0], b[1] - a[1]
        length = math.hypot(ex, ey) or 1
        edge = ((a[0] + b[0]) / 2 - x) * ex / length + ((a[1] + b[1]) / 2 - y) * ey / length
        return edge, a[2], a[0], a[1]

    # The silhouette: a head and shoulders, the body the power turns to stone.
    def inside(x: float, y: float) -> float:
        head = ((x - 256) / 74) ** 2 + ((y - 196) / 92) ** 2 < 1
        neck = abs(x - 256) < 44 and 260 < y < 340
        shoulders = ((x - 256) / 206) ** 2 + ((y - 470) / 150) ** 2 < 1
        return 1.0 if head or neck or shoulders else 0.0

    image = Image.new('RGB', (CELL, CELL))
    pixels = image.load()
    for y in range(CELL):
        for x in range(CELL):
            r = math.hypot(x - 256, y - 256)
            if r > 250:
                pixels[x, y] = (0, 0, 0)
                continue
            back = int(26 + 14 * (1 - r / 250))
            if not inside(x, y):
                pixels[x, y] = (back, back, back + 3)
                continue
            edge, shade, cx, cy = plates(x, y)
            # Rounded slabs: dark crevice, a dome lit from the upper left, grit over all.
            t = min(1.0, max(0.0, (edge - 2.0) / 12.0))
            dome = math.sqrt(1 - (1 - t) ** 2)
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy) or 1
            facing = (-dx - dy) / (dist * 1.414) * (1 - t)  # the bevel faces away from the plate centre
            v = (95 * shade * (.55 + .45 * dome) + 70 * facing) * rng.uniform(.86, 1.14)
            if edge < 2.0:
                v = 18
            v = max(0, min(255, v))
            pixels[x, y] = (int(v * 1.02), int(v), int(v * .96))
    return image.filter(ImageFilter.SMOOTH)


if __name__ == '__main__':
    draw().save(sys.argv[1])
