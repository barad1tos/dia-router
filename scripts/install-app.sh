#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
source_app="$project_root/build/Dia Router.app"
install_dir="/Applications"
installed_app="$install_dir/Dia Router.app"
legacy_app="$HOME/Applications/Dia Router.app"
legacy_router_app="/Applications/Router.app"
staged_app="$install_dir/.Dia Router.app.installing.$$"
launch_services_register="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
legacy_router_identifier=""

if [[ -d "$legacy_router_app" ]]; then
    legacy_router_identifier="$(
        plutil -extract CFBundleIdentifier raw "$legacy_router_app/Contents/Info.plist" 2>/dev/null || true
    )"
fi

is_known_legacy_router=false
if [[ "$legacy_router_identifier" == "com.example.SafariProfileRouter" || \
      "$legacy_router_identifier" == "com.jdsimcoe.SafariProfileRouter" ]]; then
    is_known_legacy_router=true
fi

cleanup() {
    if [[ -d "$staged_app" ]]; then
        rm -rf "$staged_app"
    fi
}
trap cleanup EXIT INT TERM

"$project_root/scripts/build-app.sh"

if [[ ! -w "$install_dir" ]]; then
    echo "Dia Router cannot write to $install_dir." >&2
    echo "Run the installer from an administrator account." >&2
    exit 1
fi

ditto "$source_app" "$staged_app"
codesign --verify --deep --strict "$staged_app"
"$launch_services_register" \
    -u "$source_app/Contents/Library/LoginItems/Dia Router.app" \
    >/dev/null 2>&1 || true
"$launch_services_register" -u "$source_app" >/dev/null 2>&1 || true
"$launch_services_register" \
    -u "$staged_app/Contents/Library/LoginItems/Dia Router.app" \
    >/dev/null 2>&1 || true
"$launch_services_register" -u "$staged_app" >/dev/null 2>&1 || true

# Stop every old copy before changing the registered bundle on disk.
/usr/bin/killall "Dia Router Login Item" 2>/dev/null || true
/usr/bin/killall "Dia Router" 2>/dev/null || true
if [[ "$is_known_legacy_router" == true ]]; then
    /usr/bin/killall "Router" 2>/dev/null || true
fi

if [[ -d "$installed_app" ]]; then
    rm -rf "$installed_app"
fi
mv "$staged_app" "$installed_app"
"$launch_services_register" -f "$installed_app"

if [[ "$is_known_legacy_router" == true ]]; then
    "$installed_app/Contents/MacOS/Dia Router" --migrate-legacy-default-and-quit

    mkdir -p "$HOME/.Trash"
    legacy_router_backup="$HOME/.Trash/Router (legacy $(date +%Y%m%d-%H%M%S)).zip"
    ditto -c -k --keepParent "$legacy_router_app" "$legacy_router_backup"
    unzip -tq "$legacy_router_backup"
    rm -rf "$legacy_router_app"
    echo "Archived the legacy Router app at: $legacy_router_backup"
fi

# This was the install location used by releases before the canonical path
# moved to /Applications. Keeping both copies lets Launch Services choose the
# wrong one for URL handling, so retire it after the canonical copy is ready.
if [[ "$legacy_app" != "$installed_app" && -d "$legacy_app" ]]; then
    rm -rf "$legacy_app"
fi

# Purge records for the retired Router bundle IDs and every Dia Router copy
# except the canonical app and its embedded login item. This also clears old
# DerivedData and /tmp builds that no longer exist on disk.
"$launch_services_register" -dump 2>/dev/null | awk \
    -v canonical_app="$installed_app" \
    -v canonical_login="$installed_app/Contents/Library/LoginItems/Dia Router.app" '
    /^bundle id:/ {
        bundle_path = ""
    }
    /^path:/ {
        bundle_path = $0
        sub(/^path:[[:space:]]*/, "", bundle_path)
        sub(/[[:space:]]+\(0x[[:xdigit:]]+\)$/, "", bundle_path)
    }
    /^identifier:/ {
        identifier = $0
        sub(/^identifier:[[:space:]]*/, "", identifier)

        is_legacy = identifier == "com.example.SafariProfileRouter" || \
            identifier == "com.jdsimcoe.SafariProfileRouter"
        is_extra_main = identifier == "com.diarouter.DiaRouter" && \
            bundle_path != canonical_app
        is_extra_login = identifier == "com.diarouter.DiaRouter.LoginItem" && \
            bundle_path != canonical_login

        if (bundle_path != "" && (is_legacy || is_extra_main || is_extra_login)) {
            print bundle_path
        }
    }
' | while IFS= read -r stale_bundle; do
    "$launch_services_register" -u "$stale_bundle" >/dev/null 2>&1 || true
done

"$launch_services_register" -f "$installed_app"

"$project_root/scripts/install-login-item.sh" "$installed_app"

echo "$installed_app"
