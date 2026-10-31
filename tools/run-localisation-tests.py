"""统一执行本地化扫描、契约与集成回归，原生字体检查需显式启用。"""
import argparse
import os
from pathlib import Path
import subprocess
import sys


def main() -> None:
    """在固定目录执行测试，并原样传播首个失败的退出码。"""
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-fonts', action='store_true', help='使用 Windows 生成的真实图集')
    parser.add_argument('--lua', help='LuaJIT 或 LuaRunner 可执行文件')
    args = parser.parse_args()
    runner = args.lua or (str(root / 'tools/LuaRunner.exe') if os.name == 'nt' else 'luajit')
    env = os.environ.copy()
    env['POB_LOCALISATION_NATIVE_FONTS'] = '1' if args.native_fonts else '0'
    run = root / 'src/Tests/Run'
    run.mkdir(parents=True, exist_ok=True)
    (run / '.ready').touch()
    commands = [([sys.executable, str(root / 'tools/check-localisation-font-metrics.py')], root),
                (['node', str(root / 'tools/check-localisation-display.cjs')], root)]
    commands.extend(([runner, 'Tests/' + script], root / 'src') for script in (
        'Localisation.lua', 'LocalisationIntegration.lua'))
    for command, cwd in commands:
        print('+', ' '.join(command), flush=True)
        result = subprocess.run(command, cwd=cwd, env=env)
        if result.returncode:
            sys.exit(result.returncode)


if __name__ == '__main__':
    main()
