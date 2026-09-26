#!/bin/bash
# Self-test for check-boundary.sh: a clean tree passes, every import form fails,
# look-alike modules pass, and --allow exempts exactly one file.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
check="$here/check-boundary.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/clean" "$work/bad"
printf 'import Foundation\nimport FirebaseRemoteConfigInterop\nimport LiveOpsStore\n// import FirebaseRemoteConfig\n' > "$work/clean/A.swift"
printf 'let text = "import FirebaseRemoteConfig"\n' > "$work/clean/B.swift"

forms=("import FirebaseRemoteConfig" "@testable import FirebaseRemoteConfig" "@_exported import FirebaseRemoteConfig"
       "public import FirebaseRemoteConfig" "import struct FirebaseRemoteConfig.RemoteConfig" "  import FirebaseRemoteConfig")
failures=0
expect() { # expect <status> <description> <command...>
  local want=$1 what=$2; shift 2
  set +e; "$@" > "$work/out" 2>&1; local got=$?; set -e
  if [ "$got" -eq "$want" ]; then echo "  ✓ $what"; else echo "  ✗ $what (exit $got, wanted $want)"; cat "$work/out"; failures=$((failures + 1)); fi
}

echo "check-boundary self-test"
expect 0 "a clean tree passes (look-alike module, comment, string)" "$check" "$work/clean"
for index in "${!forms[@]}"; do
  rm -f "$work/bad/"*.swift
  printf '%s\n' "${forms[$index]}" > "$work/bad/Bad$index.swift"
  expect 1 "\"${forms[$index]}\" is a violation" "$check" "$work/bad"
done
printf 'import FirebaseRemoteConfig\n' > "$work/bad/Transport.swift"
printf 'import FirebaseRemoteConfig\n' > "$work/bad/Other.swift"
rm -f "$work/bad/Bad"*.swift
expect 1 "--allow exempts only the named file" "$check" --allow "$work/bad/Transport.swift" "$work/bad"
rm "$work/bad/Other.swift"
expect 0 "--allow passes when the transport is the only importer" "$check" --allow "$work/bad/Transport.swift" "$work/bad"
printf 'import GoogleMobileAds\n' > "$work/clean/Ads.swift"
expect 1 "--module checks another SDK" "$check" --module GoogleMobileAds "$work/clean"
expect 2 "a missing directory is a usage error" "$check" "$work/none"
expect 2 "no directory is a usage error" "$check"
expect 0 "this repo: only the kit's transport imports Remote Config" \
  "$check" --allow "$here/../Sources/LiveOps/Firebase/FirebaseLiveOpsProvider.swift" "$here/../Sources" "$here/../Tests"

[ $failures -eq 0 ] && echo "OK" || { echo "$failures failure(s)"; exit 1; }
