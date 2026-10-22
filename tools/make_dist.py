"""Builds the ready-to-ship mod into dist/mods/com.necrosis.stoneskin from source.

Reads the installed game's own objdb.rdb/objstrings.rdb, runs assets.py (the
Stoneskin Elixir record), then the Lua runtime's records_delta.py to cut that
down to this mod's [script.records] range, and assembles manifest, scripts and
records. Files already in the dist folder are overwritten; nothing else is touched.

    python -B tools/make_dist.py [--game <Exanima folder>] [--workspace <Exanimate workspace>]
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD_ID = 'com.necrosis.stoneskin'
ID_RANGE = ('0x5a0', '0x5a3')      # after Keyring 0x590 and Grindstone 0x591..0x59f
STRING_RANGE = ('1249', '1256')    # after Keyring 1201..1216 and Grindstone 1217..1248
SOURCE_SCRIPTS = ('main.lua', 'config.lua', 'effect.lua')


def run(*args, env=None):
    subprocess.run([sys.executable, '-X', 'utf8', '-B', *map(str, args)], check=True, env=env)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--game', type=Path, default=Path(r'D:\SteamLibrary\steamapps\common\Exanima'))
    parser.add_argument('--workspace', type=Path,
                        default=Path(os.environ.get('EXANIMATE_WORKSPACE', r'C:\Users\hunte\Documents\ChatGPT\Exanimate')))
    args = parser.parse_args()
    tools = args.workspace / 'tools' / 'exanimate'
    delta_tool = args.workspace / 'mods' / 'script-runtime' / 'records_delta.py'
    for needed in (tools, delta_tool, args.game / 'Resource.rpk'):
        if not needed.exists():
            parser.error(f'missing {needed}')
    env = dict(os.environ, EXANIMATE_TOOLS=str(tools))
    sys.path.insert(0, str(tools))
    from exanimate import rpk

    stage = Path(tempfile.mkdtemp(prefix='stoneskin-dist-'))
    inputs = stage / 'inputs'
    inputs.mkdir()
    for member in ('objdb.rdb', 'objstrings.rdb'):
        (inputs / member).write_bytes(rpk.read(args.game / 'Resource.rpk', member))
    run(ROOT / 'assets.py', '--inputs', inputs, '--out', stage / 'full', env=env)
    run(delta_tool, '--game', args.game, '--full', stage / 'full', '--ids', *ID_RANGE,
        '--strings', *STRING_RANGE, '--out', stage / 'delta', '--map-lua', stage / 'full' / 'elixir.lua')

    dist = ROOT / 'dist' / 'mods' / MOD_ID
    (dist / 'scripts').mkdir(parents=True, exist_ok=True)
    (dist / 'records').mkdir(exist_ok=True)
    for name in SOURCE_SCRIPTS:
        shutil.copyfile(ROOT / 'scripts' / name, dist / 'scripts' / name)
    stale = dist / 'scripts' / 'pick.lua'
    if stale.exists():
        stale.unlink()  # 0.1.0's NPC picker, retired
    shutil.copyfile(stage / 'delta' / 'elixir.lua', dist / 'scripts' / 'elixir.lua')
    for name in ('objdb.rdb', 'objstrings.rdb'):
        shutil.copyfile(stage / 'delta' / 'records' / name, dist / 'records' / name)
    manifest = (ROOT / 'manifest.toml').read_text(encoding='utf-8').rstrip('\n')
    block = (stage / 'delta' / 'manifest-records.toml').read_text(encoding='utf-8').strip('\n')
    (dist / 'manifest.toml').write_text(f'{manifest}\n\n{block}\n', encoding='utf-8')
    print(f'dist ready: {dist} (staging kept at {stage})')
    return 0


if __name__ == '__main__':
    sys.exit(main())
