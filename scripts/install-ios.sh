#!/usr/bin/env bash
# Build Villain Arc for iOS (Release) and install it on a paired physical iPhone.
# Run: scripts/install-ios.sh [device-udid]
#
# No Xcode GUI and no human step: the project signs automatically against
# DEVELOPMENT_TEAM X26SC78YDG, and -allowProvisioningUpdates lets the toolchain
# create/refresh the team provisioning profiles for the app + its extensions on
# its own. Xcode's build phases produce the real signed .app, so there is no
# hand-rolled bundle assembly here.
#
# The one part that stays human: LAUNCHING it. A running app keeps its old code
# until it next launches, and this installs over the app Fernando is using.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # repo root
cd "$HERE"

DERIVED=".build-ios"
APP_NAME="VillainArc.app"
# TWIN of scripts/gate.sh — the promoted-shortcut count and the phrase catalog are the same
# contract here as there, and a build that registers fewer is one Siri answers nothing for.
SHORTCUT_COUNT=10
PHRASE_CATALOG="VillainArc/AppShortcuts.xcstrings"

# Resolve the target device: an explicit UDID, else the sole paired physical iPhone.
# Refuse rather than guess when several are present — installing on the wrong phone is
# not something to recover from politely.
#
# Do NOT filter on the list's connection column. A device reachable over a localNetwork
# tunnel reads `available (paired)` there while `devicectl device info details` reports
# `Device State: connected` — so filtering on the word `connected` excludes exactly the
# wireless case this script exists to serve. Reachability is proved by the install itself,
# which fails loudly on an unreachable device.
DEVICE="${1:-}"
if [[ -z "$DEVICE" ]]; then
  # Match the UDID by SHAPE, never by column index: the Name and Model columns both contain
  # spaces ("iPhone 17 Pro Max (iPhone18,2)") and the Hostname column is often empty, so a
  # field offset silently resolves to a fragment of the model name. Two shapes: a PHYSICAL
  # device UDID is 8-16; a simulator's is the 8-4-4-4-12 UUID.
  FOUND=()
  while IFS= read -r _u; do [ -n "$_u" ] && FOUND+=("$_u"); done < <(
    xcrun devicectl list devices 2>/dev/null \
    | grep -E 'iPhone.*physical' \
    | grep -oE '[0-9A-F]{8}-([0-9A-F]{16}|[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})')
  case "${#FOUND[@]}" in
    0) echo "✗ No paired iPhone. Pair/unlock it, then: xcrun devicectl list devices" >&2; exit 1 ;;
    1) DEVICE="${FOUND[0]}" ;;
    *) echo "✗ ${#FOUND[@]} connected iPhones — name one: install-ios.sh <udid>" >&2
       printf '   %s\n' "${FOUND[@]}" >&2; exit 1 ;;
  esac
fi
echo "› Target device: $DEVICE"

echo "› Building Release for device…"
# Exit 3 on a BUILD failure, so a caller can tell a code defect from an unreachable phone. An
# install failure is routine (a locked or sleeping phone); a compile error is not, and swallowing
# it reports a successful install for an app that does not build.
xcodebuild -project VillainArc.xcodeproj -scheme VillainArc \
  -configuration Release -destination "platform=iOS,id=$DEVICE" \
  -allowProvisioningUpdates -derivedDataPath "$DERIVED" \
  DEBUG_INFORMATION_FORMAT=dwarf-with-dsym build || exit 3

BUILT="$DERIVED/Build/Products/Release-iphoneos/$APP_NAME"
[[ -d "$BUILT" ]] || { echo "✗ Built app not found: $BUILT" >&2; exit 1; }

# Retain this build's dSYM, keyed by the UUID a crash report names.
#
# MetricKit delivers a crash up to ~24 HOURS after it happened, and by then the build that
# crashed is gone: `$DERIVED` is scratch the next run overwrites, and reading raw offsets without
# symbols is invention rather than diagnosis. Keyed by UUID because that is the only thing a
# payload and a binary share.
DSYM="$DERIVED/Build/Products/Release-iphoneos/$APP_NAME.dSYM"
if [[ -d "$DSYM" ]]; then
  DSYM_UUID="$(dwarfdump --uuid "$DSYM" 2>/dev/null | awk '/UUID:/ {print $2; exit}')"
  if [[ -n "$DSYM_UUID" ]]; then
    mkdir -p "$HOME/.jarvis/dsyms"
    KEEP="$HOME/.jarvis/dsyms/$DSYM_UUID.dSYM"
    [[ -d "$KEEP" ]] || cp -R "$DSYM" "$KEEP"
    echo "› dSYM retained for crash reports: $DSYM_UUID"
    # Bounded at the newest 20 across every app that retains here — a crash older than twenty
    # device builds is one nobody is still chasing, and keeping every build is a slow disk leak.
    ls -dt "$HOME/.jarvis/dsyms"/*.dSYM 2>/dev/null | tail -n +21 | while read -r old; do
      rm -rf "$old"
    done
  fi
else
  echo "⚠ no dSYM produced — a crash from this build could not be symbolicated" >&2
fi

# App Shortcuts extract per BUILT ARTIFACT, not per source tree, so the gate's green reading on a
# simulator build says nothing about this one. Same verifier and same contract as the gate: a null
# mangled provider name means Siri registers no phrase at install, silently and with no build error.
"$HERE/../FCTFoundation/scripts/verify-app-shortcuts.py" \
  --expect "$SHORTCUT_COUNT" --catalog "$PHRASE_CATALOG" --quiet "$BUILT" || {
  echo "✗ App Shortcuts did not register in the built iOS app — see the message above." >&2
  exit 1
}

echo "› Installing…"
xcrun devicectl device install app --device "$DEVICE" "$BUILT"

echo "✓ Installed $APP_NAME on $DEVICE — it runs the OLD code until it is next launched."
