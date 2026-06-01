#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/InOfficeDerivedData}"
PROJECT_PATH="${PROJECT_PATH:-InOffice.xcodeproj}"
SCHEME="${SCHEME:-InOffice}"

if [[ ! -d "$PROJECT_PATH" ]]; then
  cat >&2 <<EOF
error: Xcode project not found at $PROJECT_PATH

This repository treats the checked-in .xcodeproj as the source of truth.
Restore the project directory or point PROJECT_PATH at an existing project.
EOF
  exit 1
fi

pick_ios_simulator_udid() {
  if ! command -v xcrun >/dev/null 2>&1; then
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    local udid=""
    udid="$(
      python3 - <<'PY' 2>/dev/null || true
import json
import re
import subprocess
import sys

def _run(args):
    try:
        return subprocess.check_output(args, stderr=subprocess.DEVNULL).decode("utf-8")
    except Exception:
        return ""

def _runtime_sort_key(runtime_key: str):
    # Prefer newer iOS runtimes when multiple are present.
    # Examples: "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
    nums = [int(x) for x in re.findall(r"(\\d+)", runtime_key)]
    return nums

def _collect_devices(json_text: str):
    try:
        data = json.loads(json_text)
    except Exception:
        return []
    devices = data.get("devices", {}) or {}
    all_devices = []
    for runtime_key, devs in devices.items():
        for d in (devs or []):
            d = dict(d)
            d["_runtime_key"] = runtime_key
            all_devices.append(d)
    return all_devices

booted = _collect_devices(_run(["xcrun", "simctl", "list", "devices", "booted", "-j"]))
for d in booted:
    if d.get("state") == "Booted" and d.get("udid"):
        sys.stdout.write(d["udid"])
        sys.exit(0)

available = _collect_devices(_run(["xcrun", "simctl", "list", "devices", "available", "-j"]))
if not available:
    sys.exit(0)

def pri(d):
    name = d.get("name", "") or ""
    # Prefer iPhone > iPad > anything else.
    if "iPhone" in name:
        device_pri = 0
    elif "iPad" in name:
        device_pri = 1
    else:
        device_pri = 2

    # Prefer newer runtimes when names tie.
    runtime_key = d.get("_runtime_key", "")
    runtime_nums = _runtime_sort_key(runtime_key)
    # Sort wants ascending; invert by negating each component.
    runtime_inv = tuple([-n for n in runtime_nums])

    return (device_pri, runtime_inv, name)

for d in sorted(available, key=pri):
    if not d.get("udid"):
        continue
    # Some JSON variants use `isAvailable` (bool) and/or `availabilityError` (string).
    if d.get("isAvailable") is False:
        continue
    if d.get("availabilityError"):
        continue
    sys.stdout.write(d["udid"])
    sys.exit(0)
PY
    )"
    if [[ -n "${udid}" ]]; then
      printf '%s' "${udid}"
      return 0
    fi
  fi

  # Fallback without JSON parsing: pick the first available iPhone-like device.
  # Example line:
  #   iPhone 17 (E23EDC89-A2B7-4FFD-8043-B827D009E538) (Shutdown)
  xcrun simctl list devices available 2>/dev/null | \
    awk '/iPhone/ && $0 ~ /\\([0-9A-Fa-f-]+\\)/ { match($0,/\\(([0-9A-Fa-f-]+)\\)/,m); print m[1]; exit }' || true
}

if [[ -z "${DESTINATION:-}" ]]; then
  SIMULATOR_UDID="$(pick_ios_simulator_udid)"
  if [[ -n "${SIMULATOR_UDID}" ]]; then
    DESTINATION="platform=iOS Simulator,id=${SIMULATOR_UDID}"
  fi
fi

if [[ -z "${DESTINATION:-}" ]]; then
  cat >&2 <<'EOF'
error: No iOS Simulator devices were discovered.

Fix:
- Xcode -> Settings -> Platforms: install an iOS Simulator runtime
- Xcode -> Window -> Devices and Simulators: create an iPhone simulator

Workaround:
- Run tests on a connected physical device by setting DESTINATION, e.g.
  DESTINATION="platform=iOS,id=<DEVICE_UDID>" ./scripts/verify.sh
EOF
  exit 1
fi

echo "Running unit tests..."
echo "Using destination: $DESTINATION"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallel-testing-enabled NO \
  test

echo "OK"
