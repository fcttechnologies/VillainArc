#!/usr/bin/env bash
# Build Villain Arc for iOS (Release) and install it on Fernando's paired iPhone.
# Run: scripts/install-ios.sh [device-udid]
#
# The mechanism — device resolution, signing, the dSYM archive, the install — is FCTFoundation's;
# this passes Villain Arc's facts. The shortcut count and catalog are the TWIN of scripts/gate.sh,
# checked here against the artifact that ships to the phone rather than a simulator build.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/../FCTFoundation/scripts/install-ios.sh" \
  --project "$ROOT/VillainArc.xcodeproj" --scheme VillainArc \
  --expect 10 --catalog VillainArc/AppShortcuts.xcstrings "$@"
