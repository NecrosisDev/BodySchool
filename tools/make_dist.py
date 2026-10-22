"""Builds the ready-to-ship mod into dist/mods/com.necrosis.stoneskin from source:
manifest.toml and scripts/*.lua, overwriting only those files.

    python -B tools/make_dist.py
"""
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD_ID = 'com.necrosis.stoneskin'
SCRIPTS = ('main.lua', 'config.lua', 'pick.lua')


def main() -> int:
    dist = ROOT / 'dist' / 'mods' / MOD_ID
    (dist / 'scripts').mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / 'manifest.toml', dist / 'manifest.toml')
    for name in SCRIPTS:
        shutil.copyfile(ROOT / 'scripts' / name, dist / 'scripts' / name)
    print(f'dist ready: {dist}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
