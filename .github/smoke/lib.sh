# Helpers for driving the simulator with AXe. Sourced by run.sh.
set -u
BUNDLE=joel.scripture-memory
APP="build/Debug-iphonesimulator/Scripture Memory.app"
mkdir -p results
STEP=0

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a results/log.txt; }

boot_simulator() {
  UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
for rt in sorted(d, reverse=True):
    if "iOS" not in rt: continue
    for dev in d[rt]:
        if dev["name"].startswith("iPhone") and "Pro" in dev["name"] and "Max" not in dev["name"]:
            print(dev["udid"]); sys.exit()
for rt in sorted(d, reverse=True):
    if "iOS" in rt:
        for dev in d[rt]:
            if dev["name"].startswith("iPhone"): print(dev["udid"]); sys.exit()')
  export UDID
  log "Booting $UDID: $(xcrun simctl list devices | grep $UDID)"
  xcrun simctl boot "$UDID" || true
  xcrun simctl bootstatus "$UDID" -b > /dev/null
  xcrun simctl install "$UDID" "$APP"
}

# defaults write into the app's preferences before launch
pref() { xcrun simctl spawn "$UDID" defaults write "$BUNDLE" "$@"; }

launch() { xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true; xcrun simctl launch "$UDID" "$BUNDLE" > /dev/null; sleep "${1:-6}"; }
openurl() { xcrun simctl openurl "$UDID" "$1"; sleep "${2:-4}"; }

shot() {
  STEP=$((STEP+1)); local name=$(printf "%02d-%s" "$STEP" "$1")
  sleep "${2:-1}"
  xcrun simctl io "$UDID" screenshot "results/$name.png" > /dev/null 2>&1
  axe describe-ui --udid "$UDID" > "results/$name.ui.json" 2>/dev/null || true
  python3 .github/smoke/labels.py "results/$name.ui.json" > "results/$name.labels.txt" 2>/dev/null || true
  log "shot $name"
}

# Tap the first element whose label contains $1 (case-insensitive). Returns 1 if absent.
tap_label() {
  local xy
  xy=$(axe describe-ui --udid "$UDID" 2>/dev/null | python3 .github/smoke/find.py "$1" "${2:-}") || { log "no element labelled '$1'"; return 1; }
  axe tap -x "${xy% *}" -y "${xy#* }" --udid "$UDID" > /dev/null
  log "tap '$1' at $xy"
  sleep "${3:-1}"
}

tap_xy() { axe tap -x "$1" -y "$2" --udid "$UDID" > /dev/null; log "tap $1,$2"; sleep "${3:-1}"; }
swipe() { axe swipe --start-x "$1" --start-y "$2" --end-x "$3" --end-y "$4" --udid "$UDID" > /dev/null; log "swipe $*"; sleep "${5:-1.5}"; }

# Screen recording: record_start NAME ... record_stop
record_start() {
  REC_NAME=$(printf "%02d-%s" "$((STEP+1))" "$1"); STEP=$((STEP+1))
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "results/$REC_NAME.mov" > /dev/null 2>&1 &
  REC_PID=$!; sleep 1.5; log "recording $REC_NAME"
}
record_stop() { sleep 1; kill -INT "$REC_PID" 2>/dev/null; wait "$REC_PID" 2>/dev/null; log "stopped $REC_NAME"; }
