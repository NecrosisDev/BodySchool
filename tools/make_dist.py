"""Builds the ready-to-ship mod into dist/mods/com.necrosis.stoneskin from source.

Stone Skin is a Body-school power. The game's spell book has a Body page that loads
Resource.rpk:pwr_body.pwr and the icon sheet thmbdyico1.rfi; it ships neither, so
neither replaces a game file. This writes:
- pwr_body.pwr: the Body page (POWERS below), written with the ExaniMate power-tree
  writer. Only the file format's fixed header fields are constants; every node and
  string is new.
- thmbdyico1.rfi: the original icon sheet painted by icon.py, encoded in the texture
  format of the install's Energy sheet (thmnrgico1.rfi: RGB with mipmaps). Only that
  sheet's header is read for its format, never its pixels.
The install is only read. Files already in the dist folder are overwritten; nothing
else is touched.

    python -X utf8 -B tools/make_dist.py [--game <Exanima folder>] [--exanimate <ExaniMate service folder>]
"""
import argparse
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD_ID = 'com.necrosis.stoneskin'
SOURCE_SCRIPTS = ('main.lua', 'config.lua', 'effect.lua', 'body.lua', 'petrify.lua', 'companions.lua', 'regenerate.lua')
# (power id, name, description, x, y, parent node 1-based or 0, Insight technique or None).
# Ids must match scripts/config.lua: domain byte 3 (Body), mode in bits 16-17 (Stone Skin is
# sustained, which the spell book lets any character study; only continuous powers need
# Continuity I, 0x1dc2b0), the low byte - 1 is the icon cell. The first node is the root.
POWERS = [
    (0x10301, 'Stone Skin',
     'Harden your skin into craggy plates of stone. Edges skate off it and points find few cracks, '
     'but blunt blows strike harder against stone. Cast again to let it crumble; drains focus while '
     'it lasts, less with Sustain.', 0.0, 0.0, 0, None),
    (0x10302, 'Might',
     'Drive your muscles past their limits. Heavy weapons come round faster and your pushes land '
     'harder, for as long as you hold it. It strengthens the body, not the blow. Cast again to release; '
     'drains focus while it lasts, less with Sustain.', -58.0, -40.0, 1, None),
    (0x10303, 'Quicken',
     'Lighten your whole body so that every swing, recovery and step comes quicker. Cast again to '
     'release; drains focus faster than Might, less with Sustain.', 58.0, -40.0, 1, None),
    # The inversions: each does to the foes around you, for a few seconds, the opposite of its parent.
    (0x00304, 'Petrify',
     'Turn every foe around you to stone for a few moments. They stand all but frozen, blades glance '
     'off them and blunt blows shatter; then the stone falls away. Costs nothing if no one is close '
     'enough.', 0.0, -62.0, 1, 'Inversion'),
    (0x00305, 'Weaken',
     'Drain the strength from the foes around you for a while: their weapons drag and their blows land '
     'softer. Costs nothing if no one is close enough.', -74.0, -100.0, 2, 'Inversion'),
    (0x00306, 'Slow',
     'Weigh down the bodies of the foes around you for a while: every swing, recovery and step of '
     'theirs lags. Costs nothing if no one is close enough.', 74.0, -100.0, 3, 'Inversion'),
    (0x10307, 'Regenerate',
     'Will your body to knit itself back together: wounds close and broken limbs mend, a little each '
     'moment, worst first, for as long as you hold it. Drains focus faster than any other Body power, '
     'less with Sustain.', -120.0, -58.0, 2, 'Coherence'),
    (0x10308, 'Mend',
     'Lay your hand on an ally and will their body to knit: the wounds and broken limbs of the nearest '
     'companion within arm\'s reach mend a little each moment for as long as you hold it. Drains focus '
     'faster than Regenerate, less with Sustain.', -150.0, -112.0, 7, 'Expansion'),
]
MODES = {0: 'immediate', 1: 'sustained', 2: 'continuous'}
# A link's two floats are where its line meets each ring, as angles in turns: first at the node that owns
# the link, then at its parent. The game measures them from +y, signed by x (0x1db920 / 0x1db9e0).
LINK_CURVE = 0.03   # the shipped links bend slightly; this keeps ours from looking ruled


def ring_angle(dx: float, dy: float) -> float:
    import math
    length = math.hypot(dx, dy)
    angle = math.acos(max(-1.0, min(1.0, dy / length))) / (2 * math.pi)
    return -angle if dx < 0 else angle


def link(child, parent_node, parent_index):
    _, _, _, cx, cy, *_ = child
    _, _, _, px, py, *_ = parent_node
    def wrap(turns):
        return (turns + 0.5) % 1.0 - 0.5
    return (wrap(ring_angle(px - cx, py - cy) + LINK_CURVE), wrap(ring_angle(cx - px, cy - py) - LINK_CURVE), parent_index, 0)
# The tree file's fixed fields, as every shipped tree has them (0x1de110 skips the header; the game
# picks the icon sheet by school, not by the name in it): 8 zero bytes, a 16-byte icon sheet name,
# zero padding; the 'en' language tag; the string table head (its count is rewritten on pack).
TREE_HEAD = bytes(8) + b'thmmndico1'.ljust(16, b'\0') + bytes(16)
TREE_LANGUAGE = b'en\0\0'
TREE_STRING_HEAD = bytes.fromhex('656e0000e4040100000000002e000000')


def body_tree(pwr) -> bytes:
    """The Body page. Like the shipped tables, the string blob starts with an empty string that the
    last offset points at."""
    techniques = {name: number for number, name in pwr.INSIGHT.items()}
    tree = pwr.Tree(TREE_HEAD, [], TREE_LANGUAGE, TREE_STRING_HEAD, [0], b'\0\0\0\0')
    for power, name, description, x, y, parent, needs in POWERS:
        links = [link((power, name, description, x, y), POWERS[parent - 1], parent)] if parent else []
        stored = power | (techniques[needs] << 28 if needs else 0)
        tree.nodes.append(pwr.Node(stored, tree.set_text(None, name), tree.set_text(None, description), x, y, links))
    data = pwr.pack(tree)
    for node, (power, name, _d, _x, _y, parent, needs) in zip(pwr.view(data)['nodes'], POWERS):
        if (int(node['id'], 16) & 0x3FFFF != power or node['name'] != name or node['mode'] != MODES[(power >> 16) & 3]
                or node['requires'] != ([needs] if needs else []) or node['parents'] != ([parent] if parent else [])):
            raise SystemExit(f'pwr_body.pwr did not read back as written: {node}')
    return data


def body_icons(rfi, like: bytes) -> bytes:
    """The painted sheet as an .rfi in the Energy sheet's format. .rfi rows are stored bottom row first
    (the exporter flips them back), so the image is flipped before encoding."""
    sys.path.insert(0, str(ROOT))
    import icon
    from PIL import Image
    image = icon.draw().convert('RGBA').transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    return rfi.encode(image.tobytes(), image.width, image.height, like)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--game', type=Path, default=Path(r'D:\SteamLibrary\steamapps\common\Exanima'))
    parser.add_argument('--exanimate', type=Path, default=Path(os.environ.get(
        'EXANIMATE_SERVICE', r'C:\Users\hunte\Documents\ChatGPT\Exanimate\work\r20-pose-studio-codex-20261020\service')))
    args = parser.parse_args()
    for needed in (args.exanimate / 'exanimate', args.game / 'Resource.rpk'):
        if not needed.exists():
            parser.error(f'missing {needed}')
    sys.path.insert(0, str(args.exanimate))
    from exanimate import pwr, rfi, rpk

    tree = body_tree(pwr)
    icons = body_icons(rfi, rpk.read(args.game / 'Resource.rpk', 'thmnrgico1.rfi'))
    dist = ROOT / 'dist' / 'mods' / MOD_ID
    packages = dist / 'assets' / 'packages' / 'Resource'
    packages.mkdir(parents=True, exist_ok=True)
    (dist / 'scripts').mkdir(exist_ok=True)
    (packages / 'pwr_body.pwr').write_bytes(tree)
    (packages / 'thmbdyico1.rfi').write_bytes(icons)
    for name in SOURCE_SCRIPTS:
        shutil.copyfile(ROOT / 'scripts' / name, dist / 'scripts' / name)
    shutil.copyfile(ROOT / 'manifest.toml', dist / 'manifest.toml')
    print(f'STONE_SKIN_BUILT={dist} pwr_body.pwr={len(tree)} bytes thmbdyico1.rfi={len(icons)} bytes')
    return 0


if __name__ == '__main__':
    sys.exit(main())
