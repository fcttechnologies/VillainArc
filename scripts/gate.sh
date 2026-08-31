#!/usr/bin/env bash
#
# Villain Arc's full gate. Nothing is done until this is green.
#
# VA ships ONE app target to iOS/iPadOS, with three further bundles riding inside the built app:
# the widget extension, the SiriKit intents extension, and the watch app. Every check that reads a
# built artifact therefore reads all four — a privacy manifest, like an Info.plist key, is produced
# per bundle, and the app's green says nothing about the appex beside it.
#
# Release is gated here, not left to a pre-ship ritual: a `#if DEBUG` path that release code still
# calls compiles clean in Debug and breaks only in the archive, and the archive dry-run is the
# device-slice compile that catches what a simulator build hides.
#
# The unit suite is app-hosted (`@testable import VillainArc`) and runs on the simulator, reusing
# wave 1's build. `-parallel-testing-enabled NO` is not a preference: without it xcodebuild spawns
# a per-suite simulator clone, the clones fail to boot under host pressure on this machine, and the
# death reads as a test failure ("Invalid device state", "Lost pending connection to the test
# runner") rather than as the environment refusing.
#
# Every leg runs even after one fails, and each writes its own log — one run tells you the state of
# the whole gate rather than the first thing that went wrong. Read the failures from the logs it
# names.
#
# Usage:  scripts/gate.sh
# Env:    SIM_NAME  simulator device name (default "iPhone 17 Pro"). A concurrent lane points
#                   this at its own simulator; two lanes on one device collide on boot and install.

set -uo pipefail

cd "$(dirname "$0")/.."

source "../FCTFoundation/scripts/gate-lib.sh"
phase_init

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app}"
SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
SHORTCUT_COUNT=10
PHRASE_CATALOG="VillainArc/AppShortcuts.xcstrings"
MIN_TESTS=523
VERIFY_SHORTCUTS="../FCTFoundation/scripts/verify-app-shortcuts.py"
VERIFY_ICONS="../FCTFoundation/scripts/verify-app-icons.py"
DD="$(mktemp -d -t villainarc-gate)" || exit 1
LOGS="/tmp/villainarc-gate-logs"
rm -rf "${LOGS}" && mkdir -p "${LOGS}"
trap 'rm -rf "${DD}"' EXIT
STATUS=0

fail() { echo "==> FAIL: $*"; STATUS=1; }

# Every leg gets its own -derivedDataPath, which is what lets them run concurrently: two
# xcodebuilds against one DerivedData contend on the same build database.
#
# The Release SIMULATOR leg is pinned to arm64. Release defaults ONLY_ACTIVE_ARCH to NO, so the
# stock settings compile the app AND all of FCTFoundation twice — once arm64, once x86_64 — for a
# slice this fleet never runs and where the cross-import overlays this app uses fail to resolve
# anyway. Debug already pins arm64 on its own; the archive is a device build, single-slice already.
#
# The destination is always a CONCRETE device. `generic/platform=iOS Simulator` resolves x86_64
# here and fails on the cross-import overlay in AskVillainArcAssistant.swift.
start_build() {
  local label="$1" action="$2" configuration="$3" destination="$4"; shift 4
  echo "==> ${label}: ${action} (${configuration}) — started"
  leg_start "${label}" "${LOGS}/${label}.log" \
    xcodebuild -project VillainArc.xcodeproj -scheme VillainArc \
      -configuration "${configuration}" -destination "${destination}" \
      -derivedDataPath "${DD}/${label}" \
      -allowProvisioningUpdates "$@" "${action}"
}

# Never exits: this gate runs every leg even after one fails, so one run reports the state of the
# whole gate rather than the first thing that went wrong.
collect_build() {
  local label="$1" log="${LOGS}/${1}.log"
  if ! leg_wait "${label}"; then
    tail -40 "${log}"
    fail "${label} failed (log: ${log})"
    return
  fi
  check_warnings "${log}" "${label}"
}

# WAVE 1 — the Debug build the suite runs against. `build-for-testing`, not `build`: it produces
# the same app artifact AND compiles the test bundles, so the test leg has nothing left to build.
start_build ios build-for-testing Debug "platform=iOS Simulator,name=${SIM_NAME}"
collect_build ios
mark "Debug build"

# WAVE 2 — the suite beside the Release builds. The suite is app-hosted and its wall is mostly
# SwiftData settles and async work rather than CPU, so overlapping it with the Release compiles is
# close to free.
#
# `test-without-building` reuses wave 1's products: a plain `test` re-walks and re-links the whole
# graph it just built. The count is asserted, not just the exit status — a target that stops
# compiling its test sources reports success having executed nothing. Only a floor is pinned:
# adding tests must never fail the gate, losing them always must.
echo "==> Unit suite + Release builds"
TEST_LOG="${LOGS}/unit-suite.log"
leg_start unit-suite "${TEST_LOG}" \
  xcodebuild -project VillainArc.xcodeproj -scheme VillainArc \
    -destination "platform=iOS Simulator,name=${SIM_NAME}" \
    -derivedDataPath "${DD}/ios" -parallel-testing-enabled NO \
    -allowProvisioningUpdates test-without-building
start_build ios-release build   Release "platform=iOS Simulator,name=${SIM_NAME}" \
  ONLY_ACTIVE_ARCH=YES ARCHS=arm64
start_build archive     archive Release "generic/platform=iOS" \
  -archivePath "${DD}/VillainArc.xcarchive" CODE_SIGNING_ALLOWED=NO

if ! leg_wait unit-suite; then
  grep -E '✘|error:' "${TEST_LOG}" | head -40
  fail "unit suite failed (log: ${TEST_LOG})"
fi
check_warnings "${TEST_LOG}" "unit suite"
TEST_COUNT="$(sed -n 's/.*Test run with \([0-9]*\) tests.*/\1/p' "${TEST_LOG}" | tail -1)"
[ -n "${TEST_COUNT}" ] || fail "could not read a test count from ${TEST_LOG} — the suite may not have run"
[ -n "${TEST_COUNT}" ] && { [ "${TEST_COUNT}" -ge "${MIN_TESTS}" ] \
  || fail "only ${TEST_COUNT} tests ran, expected at least ${MIN_TESTS} — tests stopped being compiled or listed"; }
collect_build ios-release
collect_build archive
mark "suite + Release builds (concurrent)"

DEBUG_APP="${DD}/ios/Build/Products/Debug-iphonesimulator/VillainArc.app"
RELEASE_APP="${DD}/ios-release/Build/Products/Release-iphonesimulator/VillainArc.app"

# The App Shortcuts provider must compile into the app target. It builds, links, and registers
# NOTHING anywhere else — silently, at every other layer. Only the built app bundle's mangled
# provider name tells the truth. This is also where the promoted count is pinned against Apple's
# 10-slot cap: VA sits exactly at the cap, so a new shortcut has to displace one.
#
# `--catalog` is where phrase LOCALIZATION is checked, and it has to be here rather than in the
# drift leg below: swiftc extracts only each shortcut's FIRST phrase, so the extraction set is
# blind to most of what the bundle registers. This compares the registered set — every phrase
# template and its alternatives — against the one catalog App Shortcut metadata can read. Only the
# fixed `AppShortcuts` table resolves a phrase: the same key sitting in Localizable.xcstrings
# serves it never, and ships English in every locale.
#
# A shortTitle is the mirror image and belongs in Localizable, where swiftc extracts it and the
# drift leg already covers it. One added to AppShortcuts.xcstrings sits in a table nothing reads it
# from, and `appintentsmetadataprocessor` says so once per title per non-source language.
echo "==> App Shortcuts registered, counted, and phrase-covered"
"${VERIFY_SHORTCUTS}" --expect "${SHORTCUT_COUNT}" --catalog "${PHRASE_CATALOG}" --quiet \
  "${DEBUG_APP}" \
  || fail "App Shortcuts did not register — see the message above."

# One merged asset catalog serves iPhone and iPad. An AppIcon set declaring only one idiom
# compiles clean and ships the other with no icon at all: actool reports it in output the
# Swift-warning filter above does not catch, and nothing else fails.
echo "==> App icon in the built artifact"
"${VERIFY_ICONS}" "${DEBUG_APP}" \
  || fail "App icon missing — see the message above."

# A privacy manifest is a plain resource: a file left out of a target's sources, or renamed, ships
# a bundle App Store Connect rejects and no build reports it. Each of the four bundles answers for
# its OWN required-reason API use — an appex cannot ride the app's manifest — so each is read at
# its own path inside the built app.
echo "==> Privacy manifest in all four built bundles"
for manifest in \
  "${DEBUG_APP}/PrivacyInfo.xcprivacy" \
  "${DEBUG_APP}/PlugIns/VillainArcWidgetExtensionExtension.appex/PrivacyInfo.xcprivacy" \
  "${DEBUG_APP}/PlugIns/VillainArcIntentsExtension.appex/PrivacyInfo.xcprivacy" \
  "${DEBUG_APP}/Watch/VillainArcWatchApp.app/PrivacyInfo.xcprivacy"
do
  [ -f "${manifest}" ] || { fail "missing ${manifest#${DD}/ios/Build/Products/}"; continue; }
  plutil -lint "${manifest}" >/dev/null || fail "${manifest} is not a valid property list"
  [ "$(plutil -extract NSPrivacyTracking raw -o - "${manifest}" 2>/dev/null)" = "false" ] \
    || fail "${manifest} does not declare NSPrivacyTracking = false"
done

# A `Text("…")` added in source reaches the String Catalog only when Xcode's IDE extracts it; a
# command-line xcodebuild never does, so the catalog silently stops covering the UI and every
# non-English locale ships the raw English key. This compares against the compiler's own
# extraction set in a build that already ran, and costs no build of its own. Checked table by
# table: the Siri phrases live in their own catalog, and a key sitting in the wrong one is just as
# undelivered as a missing one.
#
# Read from the RELEASE tree, not the Debug one: drift is a question about what ships, and the
# Debug extraction set also carries the `#if DEBUG` surfaces (Screenshot Studio, the debug menu)
# whose strings no user ever sees and which have no business in a shipping catalog.
#
# Two scoped passes, and the scoping is load-bearing. A catalog's table name is its filename stem,
# so the app's and the watch's `Localizable.xcstrings` collide on one table: run together, the last
# one wins and the 28-key watch catalog gets measured against the app's ~2,200 strings.
# `--source-root` splits them by which sources the strings came from.
#
# FCTFoundation is deliberately NOT a third pass. The rule that a package's strings count against
# the app's catalog holds only for a package that resolves against the MAIN bundle; every
# `String(localized:)` in FCTFoundation passes `bundle: .module` and each module ships its own
# `Resources/Localizable.xcstrings`, complete in all ten locales. Scoping a pass at its sources
# would report every one of those strings as missing from VA's catalog and be wrong.
echo "==> Localization drift"
check_loc_drift "${DD}/ios-release" --source-root "${PWD}/VillainArc" \
  VillainArc/Localizable.xcstrings \
  VillainArc/AppShortcuts.xcstrings
check_loc_drift "${DD}/ios-release" --source-root "${PWD}/VillainArcWatchApp" \
  VillainArcWatchApp/Localizable.xcstrings

# Locale COMPLETENESS — the half the drift check cannot see — is asserted by the unit suite that
# already ran above (`LocalizationIntegrityTests`), straight from the catalog JSON: every declared
# locale present, `translated`, not a copy of the English, and format-specifier-compatible.
# `scripts/loc-check.sh` runs that suite alone when only a locale pass needs verifying.
mark "artifact checks (Debug)"

# The provider is re-read from the Release artifact: metadata extraction is a per-configuration
# build step, so a Debug reading is not evidence about the build that ships.
echo "==> App Shortcuts registered in the Release artifact"
"${VERIFY_SHORTCUTS}" --expect "${SHORTCUT_COUNT}" --catalog "${PHRASE_CATALOG}" --quiet \
  "${RELEASE_APP}" \
  || fail "App Shortcuts did not register in Release — see the message above."
mark "artifact checks (Release)"

phase_table
if [ "${STATUS}" -eq 0 ]; then
  echo "==> PASS: ${TEST_COUNT} tests green, Debug and Release build warning-free, the archive
     compiles, shortcuts registered and phrase-covered, a privacy manifest in every bundle, and
     every declared locale fully translated."
else
  echo "==> GATE FAILED — see the FAIL lines above and the logs in ${LOGS}."
fi
exit "${STATUS}"
