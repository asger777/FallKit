#!/bin/bash
# Builds ConsumerCheck against FallKit by URL + tag, once per Firebase pin.
#   Examples/ConsumerCheck/check.sh [fallkit-version]   (default: the latest tag)
set -euo pipefail
cd "$(dirname "$0")"
version=${1:-$(git describe --tags --abbrev=0)}
readme=../../README.md

# The app must compile the README quick start exactly as written.
quick=$(awk '/^## Quick start/{f=1;next} f&&/^```swift/{c=1;next} c&&/^```/{exit} c' "$readme")
grep -qF "$(printf '%s' "$quick" | head -1)" App/ConsumerCheckApp.swift || { echo "README quick start and App/ConsumerCheckApp.swift differ" >&2; exit 1; }
while IFS= read -r line; do
  grep -qF -- "$line" App/ConsumerCheckApp.swift || { echo "README line missing from the app: $line" >&2; exit 1; }
done <<< "$quick"

for firebase in 12.18.0 12.17.0; do
  echo "== FallKit $version · Firebase exactly $firebase"
  sed -e "s/__FALLKIT_VERSION__/$version/" -e "s/__FIREBASE_VERSION__/$firebase/" project.template.yml > project.yml
  rm -rf ConsumerCheck.xcodeproj build
  xcodegen generate --quiet
  mkdir -p build
  for scheme in "ConsumerCheck|iOS Simulator" "ConsumerCheckWatch|watchOS Simulator"; do
    log="build/${scheme%%|*}.log"
    if ! xcodebuild -project ConsumerCheck.xcodeproj -scheme "${scheme%%|*}" -destination "generic/platform=${scheme##*|}" \
         -derivedDataPath build -clonedSourcePackagesDirPath build/spm build -quiet > "$log" 2>&1; then
      grep -E "error" "$log" | head -20 >&2
      echo "build failed: ${scheme%%|*} (log: $log)" >&2
      exit 1
    fi
    if grep -E "warning: .*/FallKit/Sources/" "$log" > /dev/null; then
      grep -E "warning: .*/FallKit/Sources/" "$log" >&2
      echo "FallKit sources produced warnings in a consumer build" >&2
      exit 1
    fi
    echo "   ✓ ${scheme%%|*} (${scheme##*|})"
  done
  resolved=$(find ConsumerCheck.xcodeproj -name Package.resolved | head -1)
  python3 - "$resolved" "$firebase" "$version" <<'PY'
import json, sys
pins = {p["identity"]: p["state"].get("version") for p in json.load(open(sys.argv[1]))["pins"]}
assert pins.get("firebase-ios-sdk") == sys.argv[2], pins.get("firebase-ios-sdk")
assert pins.get("fallkit") == sys.argv[3], pins.get("fallkit")
print(f"   ✓ resolved fallkit {pins['fallkit']} with firebase-ios-sdk {pins['firebase-ios-sdk']}")
PY
done
rm -f project.yml
echo "OK"
