"""Smoke-test the actual installed APK; widget tests cannot exercise R8/Startup.

Requires an explicit QA device serial. Installs with -r, preserves app data, and
restarts only Forest Star. Never uninstalls the app or clears its data.
"""
import argparse
import json
import subprocess
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--serial', required=True)
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('build/verification/android-startup.json'))
    args = parser.parse_args()
    package = 'com.foreststar.forest_star'

    def adb(*parts, check=True):
        return subprocess.run([args.adb, '-s', args.serial, *parts],
                              text=True, capture_output=True, check=check,
                              timeout=90)

    adb('install', '-r', str(args.apk.resolve()))
    report = {'apk': str(args.apk.resolve()), 'serial': args.serial,
              'android': adb('shell', 'getprop', 'ro.build.version.release').stdout.strip(),
              'launches': []}
    for attempt in range(3):
        adb('shell', 'am', 'force-stop', package)
        adb('shell', 'am', 'start', '-W', '-n', f'{package}/.MainActivity')
        time.sleep(2)
        pid = adb('shell', 'pidof', package, check=False).stdout.strip()
        if not pid:
            raise RuntimeError(f'Launch {attempt + 1}: app exited before startup completed')
        for _ in range(10):
            time.sleep(.5)
            current = adb('shell', 'pidof', package, check=False).stdout.strip()
            if current != pid:
                raise RuntimeError(f'Launch {attempt + 1}: process {pid} exited/restarted')
        report['launches'].append({'attempt': attempt + 1, 'pid': pid, 'alive': True})
        print(f'Launch {attempt + 1}: process {pid} survived startup', flush=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'PASS: {args.output}')


if __name__ == '__main__':
    main()
