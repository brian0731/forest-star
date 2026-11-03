"""Keep the iOS native AdMob App ID in sync with the Dart release config."""
import argparse
import json
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]


def load_config(path):
    config = json.loads(Path(path).read_text(encoding='utf-8'))
    app = re.fullmatch(r'ca-app-pub-(\d{16})~\d{10}', config.get('ADMOB_APP_ID', ''))
    unit = re.fullmatch(r'ca-app-pub-(\d{16})/\d{10}', config.get('ADMOB_REWARDED_ID', ''))
    if (config.get('ADMOB_PRODUCTION') is not True or not app or not unit
            or app[1] != unit[1] or app[1] == '3940256099942544'
            or config.get('ADMOB_AUDIENCE') not in ('children', 'general')):
        raise ValueError('Invalid production AdMob configuration or publisher mismatch')
    return config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=ROOT / 'config/admob.ios.production.json')
    parser.add_argument('--info-plist', type=Path, default=ROOT / 'ios/Runner/Info.plist')
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    config = load_config(args.config)
    info = plistlib.loads(args.info_plist.read_bytes())
    if args.verify_only:
        if info.get('GADApplicationIdentifier') != config['ADMOB_APP_ID']:
            raise ValueError('Built iOS AdMob App ID does not match the release config')
        print('Verified built iOS AdMob App ID matches the Dart release config')
    else:
        info['GADApplicationIdentifier'] = config['ADMOB_APP_ID']
        args.info_plist.write_bytes(plistlib.dumps(info, sort_keys=False))
        print('Configured iOS production AdMob App ID; audience:', config['ADMOB_AUDIENCE'])


if __name__ == '__main__':
    main()
