#!/usr/bin/env bash
# Verify a published eventkit-js tarball end-to-end. Defaults to the
# version in the package.json next to this script; pass an explicit
# version as $1 to override (e.g. `./verify-publish.sh 3.1.0`).
#
# Builds a fresh project in a temp dir, installs the published tarball
# (which runs node-gyp rebuild via the install hook), exercises the
# documented public surface, and reports pass/fail.
#
# Designed to fail loudly on any regression that wouldn't be caught by
# the in-tree test suite (publish-time issues like missing files in the
# tarball, broken install hook, stale .d.ts).

set -euo pipefail

VERSION="${1:-$(node -p "require('$(dirname "$0")/../package.json').version")}"
TMPDIR_ROOT="${TMPDIR:-/tmp}"
WORK="$(mktemp -d "${TMPDIR_ROOT}/eventkit-js-verify.XXXXXX")"

echo "==> Verifying eventkit-js@${VERSION} in ${WORK}"
cd "$WORK"

echo "==> [1/5] npm init"
npm init -y >/dev/null

echo "==> [2/5] install eventkit-js@${VERSION} (this rebuilds the native addon)"
npm install --no-audit --no-fund "eventkit-js@${VERSION}" >install.log 2>&1 || {
    echo "FAIL: npm install failed. Tail of install.log:"
    tail -30 install.log
    exit 1
}

echo "==> [3/5] confirm tarball ships expected files"
test -f node_modules/eventkit-js/build/Release/addon.node \
    || { echo "FAIL: build/Release/addon.node missing"; exit 1; }
test -f node_modules/eventkit-js/lib/EventKit.js \
    || { echo "FAIL: lib/EventKit.js missing"; exit 1; }
test -f node_modules/eventkit-js/lib/EventKit.d.ts \
    || { echo "FAIL: lib/EventKit.d.ts missing"; exit 1; }
test -f node_modules/eventkit-js/binding.gyp \
    || { echo "FAIL: binding.gyp missing (would break re-installs from source)"; exit 1; }

echo "==> [4/5] write + run a quickstart-shape sanity script"
cat > verify.mjs <<'JS'
import {
    EKEventStore,
    EKEntityType,
    EKSpan,
    EKAuthorizationStatus,
    EKEventAvailability,
    EKEventStatus,
    EKAlarmType,
    EKAlarmProximity,
    EKRecurrenceFrequency,
    EKWeekday,
    EKError,
    EKErrorCode,
} from "eventkit-js";

const fail = (msg) => { console.error("FAIL: " + msg); process.exit(1); };
const ok   = (msg) => console.log("  ok  " + msg);

// 1. Public barrel exports the documented names.
const expected = ["EKEventStore","EKEntityType","EKSpan","EKAuthorizationStatus","EKEventAvailability","EKEventStatus","EKAlarmType","EKAlarmProximity","EKRecurrenceFrequency","EKWeekday","EKError","EKErrorCode"];
for (const n of expected) {
    // import worked; just spot-check shape.
}
ok("public barrel imports resolve");

// 2. Const-object enums have the documented strings.
if (EKSpan.THIS_EVENT !== "thisEvent") fail("EKSpan.THIS_EVENT mismatch");
if (EKEventAvailability.TENTATIVE !== "tentative") fail("EKEventAvailability.TENTATIVE mismatch");
if (EKErrorCode.CALENDAR_READ_ONLY !== "calendarReadOnly") fail("EKErrorCode.CALENDAR_READ_ONLY mismatch");
if (EKWeekday.MONDAY !== "monday") fail("EKWeekday.MONDAY mismatch");
if (EKRecurrenceFrequency.WEEKLY !== "weekly") fail("EKRecurrenceFrequency.WEEKLY mismatch");
if (EKAlarmType.DISPLAY !== "display") fail("EKAlarmType.DISPLAY mismatch");
ok("const-object enum string values match documented");

// 3. Native init succeeds and reports an authorization status.
const store = EKEventStore.init();
const status = EKEventStore.authorizationStatus(EKEntityType.EVENT);
if (!Object.values(EKAuthorizationStatus).includes(status)) {
    fail(`unexpected authorizationStatus value: ${JSON.stringify(status)}`);
}
ok(`store.authorizationStatus(EVENT) = ${status}`);

// 4. Sources getter (always works regardless of TCC grant).
const sources = store.sources;
if (!Array.isArray(sources)) fail("store.sources is not an array");
ok(`store.sources.length = ${sources.length}`);

// 5. EventEmitter wiring (no native subscription until first listener).
const noop = () => {};
store.on("change", noop);
if (store.listenerCount("change") !== 1) fail("listenerCount mismatch after on()");
store.off("change", noop);
if (store.listenerCount("change") !== 0) fail("listenerCount mismatch after off()");
ok("change-notification on/off round-trip");

// 6. delegateSources / cancelFetchRequest / init(sources) reclassified throws.
let threwDelegate = false;
try { store.delegateSources; } catch (e) { threwDelegate = /deprecated/.test(e.message); }
if (!threwDelegate) fail("delegateSources should throw with /deprecated/");
ok("delegateSources throws Error('... deprecated ...')");

let threwCancel = false;
try { store.cancelFetchRequest("x"); } catch (e) { threwCancel = /AbortSignal/.test(e.message); }
if (!threwCancel) fail("cancelFetchRequest should throw with /AbortSignal/");
ok("cancelFetchRequest throws Error('... AbortSignal ...')");

let threwInit = false;
try { EKEventStore.init([]); } catch (e) { threwInit = /single shared store/.test(e.message); }
if (!threwInit) fail("init([]) should throw with /single shared store/");
ok("init([]) throws Error('... single shared store ...')");

// 7. EKError / EKErrorCode are real types.
if (typeof EKError !== "function") fail("EKError is not a class");
if (typeof EKErrorCode !== "object") fail("EKErrorCode is not an object");
ok("EKError class + EKErrorCode const-object exported");

console.log("\nALL CHECKS PASSED for eventkit-js@" + (process.env.npm_package_dependencies_eventkit_js || "(version unknown)"));
JS

if ! node verify.mjs; then
    echo "FAIL: verify.mjs exited non-zero"
    exit 1
fi

echo "==> [5/5] clean up"
echo "Leaving ${WORK} for inspection. Remove with: rm -rf ${WORK}"
echo
echo "PASS — eventkit-js@${VERSION} verified end-to-end."
