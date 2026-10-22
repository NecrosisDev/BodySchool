"""Paints the Body school's icon sheet (thmbdyico1): cell 1 Stone Skin, 2 Might, 3 Quicken; original,
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


def draw_stone() -> Image.Image:
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


def stone_cell() -> Image.Image:
    return draw_stone()


def might_cell() -> Image.Image:
    """A raised, clenched forearm and fist, its muscle lit by a warm glow from within."""
    rng = random.Random(SEED + 1)
    image = Image.new('RGB', (CELL, CELL))
    px = image.load()
    for y in range(CELL):
        for x in range(CELL):
            r = math.hypot(x - 256, y - 256)
            if r > 250:
                px[x, y] = (0, 0, 0)
                continue
            v = 22 + 14 * (1 - r / 250)
            col = (v, v * 0.95, v * 0.9)
            # The forearm rises from the lower right toward a fist at the top centre.
            ax, ay, bx, by = 360, 470, 250, 190
            ex, ey = bx - ax, by - ay
            t = max(0.0, min(1.0, ((x - ax) * ex + (y - ay) * ey) / (ex * ex + ey * ey)))
            d = math.hypot(x - ax - t * ex, y - ay - t * ey)
            width = 52 + 26 * math.sin(math.pi * min(1.0, t * 1.4))       # the muscle swells mid-arm
            fist = ((x - 240) / 78) ** 2 + ((y - 165) / 66) ** 2 < 1
            if d < width or fist:
                edge = 1 - (d / width if d < width else 0.4)
                heat = math.exp(-((x - 285) ** 2 + (y - 290) ** 2) / 9000) * 1.6
                base = 70 + 90 * edge
                col = (base * (0.9 + heat * 0.9), base * (0.62 + heat * 0.45), base * (0.45 + heat * 0.1))
                if fist and abs((x - 240) % 38 - 19) < 2 and y < 175:
                    col = tuple(c * 0.5 for c in col)                       # knuckle creases
            grain = rng.uniform(0.92, 1.08)
            px[x, y] = tuple(int(max(0, min(255, c * grain))) for c in col)
    return image.filter(ImageFilter.SMOOTH)


def quicken_cell() -> Image.Image:
    """A running figure trailing pale after-images and speed streaks."""
    rng = random.Random(SEED + 2)
    image = Image.new('RGB', (CELL, CELL))
    px = image.load()

    def runner(x, y, cx):
        u, v = x - cx, y - 110
        head = (u / 30) ** 2 + ((v - 30) / 34) ** 2 < 1
        torso = abs(u - 0.25 * (v - 70)) < 40 and 62 < v < 200                 # leaning forward
        leg1 = abs(u - 0.55 * (v - 200)) < 18 and 195 < v < 330
        leg2 = abs(u + 0.45 * (v - 200)) < 18 and 195 < v < 320
        arm = abs(v - 100 + 0.6 * (u - 20)) < 14 and -60 < u < 90
        return head or torso or leg1 or leg2 or arm

    streaks = [(rng.uniform(150, 360), rng.uniform(60, 250), rng.uniform(0.3, 1.0)) for _ in range(18)]
    for y in range(CELL):
        for x in range(CELL):
            r = math.hypot(x - 256, y - 256)
            if r > 250:
                px[x, y] = (0, 0, 0)
                continue
            v = 22 + 14 * (1 - r / 250)
            for sy, length, b in streaks:
                if abs(y - sy) < 2 and 70 < x < 70 + length:
                    v += 90 * b * (x - 70) / length
            if runner(x, y, 300):
                v = 150
            else:
                for k, fade in ((1, 0.45), (2, 0.25), (3, 0.12)):
                    if runner(x, y, 300 - 55 * k):
                        v = max(v, 40 + 150 * fade)
                        break
            v = max(0, min(255, v * rng.uniform(0.95, 1.05)))
            px[x, y] = (int(v * 0.9), int(v * 0.97), int(v))
    return image.filter(ImageFilter.SMOOTH)


def tinted(image: Image.Image, tint) -> Image.Image:
    """The image toned toward `tint` (an RGB triple 0..1) by its own brightness."""
    from PIL import ImageOps
    gray = ImageOps.grayscale(image)
    return ImageOps.colorize(gray, (0, 0, 0), tuple(int(255 * c) for c in tint))


def petrify_cell() -> Image.Image:
    """A whole standing figure of stone plates, as a foe caught by Petrify."""
    plates = draw_stone()
    mask = Image.new('L', (CELL, CELL))
    m = mask.load()
    for y in range(CELL):
        for x in range(CELL):
            u, v = x - 256, y - 60
            head = (u / 40) ** 2 + ((v - 46) / 48) ** 2 < 1
            torso = abs(u) < 66 - 0.06 * max(v - 110, 0) and 100 < v < 280
            arms = 66 <= abs(u) < 86 and 110 < v < 260
            legs = 270 < v < 420 and 8 < abs(u) < 44 - 0.03 * (v - 270)
            m[x, y] = 255 if head or torso or arms or legs else 0
    back = Image.new('RGB', (CELL, CELL), (24, 24, 27))
    disc = Image.new('L', (CELL, CELL))
    from PIL import ImageDraw
    ImageDraw.Draw(disc).ellipse([6, 6, CELL - 6, CELL - 6], fill=255)
    return Image.composite(Image.composite(plates, back, mask), Image.new('RGB', (CELL, CELL)), disc)


def weaken_cell() -> Image.Image:
    """Might's arm turned down and gone cold: the strength drained out of it."""
    return tinted(might_cell().transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0.55, 0.62, 0.8))


def slow_cell() -> Image.Image:
    """Quicken's runner turned back on itself and dragged down in cold, heavy blue."""
    return tinted(quicken_cell().transpose(Image.Transpose.FLIP_LEFT_RIGHT), (0.45, 0.55, 0.85))


def regenerate_cell() -> Image.Image:
    """Might's arm bathed in a pale green glow: flesh knitting back together."""
    return tinted(might_cell(), (0.55, 0.95, 0.6))


def mend_cell() -> Image.Image:
    """Regenerate's glowing arm turned outward, reaching across to someone else, in warmer gold-green."""
    return tinted(might_cell().transpose(Image.Transpose.FLIP_LEFT_RIGHT), (0.8, 0.95, 0.5))


CELLS = (stone_cell, might_cell, quicken_cell, petrify_cell, weaken_cell, slow_cell, regenerate_cell, mend_cell)   # power numbers 1..8
COLUMNS = 4                                       # a 2048 sheet, as Light School's


def draw() -> Image.Image:
    """The whole sheet: cells in power-number order, unused cells black."""
    sheet = Image.new('RGB', (CELL * COLUMNS, CELL * COLUMNS))
    for index, paint in enumerate(CELLS):
        sheet.paste(paint(), ((index % COLUMNS) * CELL, (index // COLUMNS) * CELL))
    return sheet


if __name__ == '__main__':
    draw().save(sys.argv[1])
