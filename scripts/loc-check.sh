#!/usr/bin/env bash
# Standalone localization integrity check — the same rules the app-hosted unit suite runs as part
# of the full gate (VillainArcTests/LocalizationIntegrityTests.swift), filtered to just that suite
# so a locale pass can be verified without paying for the rest. The checks live once, in Swift,
# next to the catalogs they validate; this script is only the CLI entry point.
#
# Env: SIM_NAME  simulator device name (default "iPhone 17 Pro").
set -uo pipefail
cd "$(dirname "$0")/.."

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app}"
SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
LOG=/tmp/villainarc-loc-check.log

xcodebuild -project VillainArc.xcodeproj -scheme VillainArc \
  -destination "platform=iOS Simulator,name=${SIM_NAME}" \
  -only-testing:VillainArcTests/LocalizationIntegrityTests \
  -derivedDataPath /tmp/villainarc-loc-dd -parallel-testing-enabled NO \
  -allowProvisioningUpdates test \
  > "${LOG}" 2>&1
STATUS=$?

if [ "${STATUS}" -eq 0 ]; then
  echo "LOCALIZATION CHECK GREEN"
else
  echo "LOCALIZATION CHECK FAILED — see ${LOG}"
  grep -E '✘|error:|localization issue' "${LOG}" | head -40
fi
exit "${STATUS}"
