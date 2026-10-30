"""Validate an App Store profile and configure Runner for a disposable CI build."""

import argparse
import datetime
import json
import plistlib
import re
import shutil
from pathlib import Path


def configure(profile_path, project_path, export_path, team, bundle):
    with profile_path.open("rb") as source:
        profile = plistlib.load(source)
    entitlements = profile["Entitlements"]
    if team not in profile.get("TeamIdentifier", []):
        raise ValueError("Provisioning profile Team ID does not match APPLE_TEAM_ID")
    if entitlements.get("application-identifier", "").partition(".")[2] != bundle:
        raise ValueError("Provisioning profile Bundle ID does not match IOS_BUNDLE_ID")
    if (
        entitlements.get("get-task-allow", False)
        or "ProvisionedDevices" in profile
        or profile.get("ProvisionsAllDevices", False)
    ):
        raise ValueError("An App Store Connect distribution profile is required")
    expiry = profile["ExpirationDate"]
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=datetime.timezone.utc)
    if expiry <= datetime.datetime.now(datetime.timezone.utc):
        raise ValueError("Provisioning profile has expired")
    uuid = profile["UUID"]
    if not re.fullmatch(r"[A-Za-z0-9-]+", uuid):
        raise ValueError("Invalid provisioning profile UUID")
    if not profile.get("DeveloperCertificates"):
        raise ValueError("Provisioning profile has no signing certificate")

    project = project_path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"(isa = XCBuildConfiguration;\n.*?buildSettings = \{\n)"
        r"(.*?)(\n\t\t\t\};\n\t\t\tname = (Debug|Release|Profile);)",
        re.DOTALL,
    )
    changed = []

    def update(match):
        settings, config = match[2], match[4]
        if not re.search(
            r"PRODUCT_BUNDLE_IDENTIFIER = " + re.escape(bundle) + r";", settings
        ):
            return match[0]
        values = {"DEVELOPMENT_TEAM": team}
        if config in ("Release", "Profile"):
            values.update(
                CODE_SIGN_STYLE="Manual",
                CODE_SIGN_IDENTITY="Apple Distribution",
                PROVISIONING_PROFILE_SPECIFIER=uuid,
            )
        for key, value in values.items():
            # Remove SDK-qualified variants too, so Xcode cannot override CI signing.
            settings = re.sub(
                r'\n\s*(?:"' + key + r'\[[^\]]+\]"|' + key + r") = [^;]*;",
                "",
                settings,
            )
            settings += f"\n\t\t\t\t{key} = {json.dumps(value)};"
        changed.append(config)
        return match[1] + settings + match[3]

    updated = pattern.sub(update, project)
    if sorted(changed) != ["Debug", "Profile", "Release"]:
        raise ValueError("Expected exactly three Runner build configurations")
    project_path.write_text(updated, encoding="utf-8", newline="\n")
    options = {
        "method": "app-store-connect",
        "destination": "export",
        "teamID": team,
        "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "provisioningProfiles": {bundle: uuid},
        "manageAppVersionAndBuildNumber": False,
        "uploadSymbols": True,
    }
    export_path.write_bytes(plistlib.dumps(options))
    return uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile-plist", type=Path, required=True)
    parser.add_argument("--profile-file", type=Path, required=True)
    parser.add_argument("--team", required=True)
    parser.add_argument("--bundle", required=True)
    parser.add_argument("--export-plist", type=Path, required=True)
    args = parser.parse_args()
    uuid = configure(
        args.profile_plist,
        Path("ios/Runner.xcodeproj/project.pbxproj"),
        args.export_plist,
        args.team,
        args.bundle,
    )
    for directory in (
        Path.home() / "Library/MobileDevice/Provisioning Profiles",
        Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles",
    ):
        directory.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(args.profile_file, directory / f"{uuid}.mobileprovision")
    print("App Store profile validated; Runner and IPA export signing configured.")


if __name__ == "__main__":
    main()
