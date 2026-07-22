#!/bin/bash

set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 <DiskMeerkat.app>" >&2
    exit 64
fi

release_app="$1"
info_plist="$release_app/Contents/Info.plist"
executable="$release_app/Contents/MacOS/DiskMeerkat"

if [[ ! -d "$release_app" ]]; then
    echo "Release app is missing: $release_app" >&2
    exit 1
fi

if [[ ! -f "$info_plist" ]]; then
    echo "Release Info.plist is missing: $info_plist" >&2
    exit 1
fi

if [[ ! -x "$executable" ]]; then
    echo "Release executable is missing or not executable: $executable" >&2
    exit 1
fi

minimum_system_version="$(/usr/bin/plutil -extract LSMinimumSystemVersion raw -o - "$info_plist")"
if [[ "$minimum_system_version" != "15.0" ]]; then
    echo "Release app must require macOS 15.0; found: $minimum_system_version" >&2
    exit 1
fi

lsui_element="$(/usr/bin/plutil -extract LSUIElement raw -o - "$info_plist")"
if [[ "$lsui_element" != "true" ]]; then
    echo "Release app must set LSUIElement to true; found: $lsui_element" >&2
    exit 1
fi

temporary_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
if [[ ! -d "$temporary_root" ]]; then
    echo "Temporary directory is missing: $temporary_root" >&2
    exit 1
fi

release_strings="$(/usr/bin/mktemp "$temporary_root/DiskMeerkat-release-strings.XXXXXX")"
cleanup() {
    /bin/rm -f "$release_strings"
}
trap cleanup EXIT

/usr/bin/strings "$executable" > "$release_strings"

fixture_keys=(
    DISK_MEERKAT_UI_TEST_FIXTURE
    DISK_MEERKAT_UI_TEST_SESSION
    DISK_MEERKAT_UI_TEST_ACTIVATE_DURING_LAUNCH
)
for fixture_key in "${fixture_keys[@]}"; do
    if /usr/bin/grep -Fq "$fixture_key" "$release_strings"; then
        echo "Release executable contains UI-test fixture key: $fixture_key" >&2
        exit 1
    fi
done

echo "Verified release app boundary: $release_app"
