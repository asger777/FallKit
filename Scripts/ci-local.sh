#!/bin/bash
# The local gate: run before every push. There is no GitHub workflow, by
# decision (2026-09-26); this script is the gate. Exit 0 means push is allowed.
#
#   Scripts/ci-local.sh           the full gate
#   Scripts/ci-local.sh --quick   lint, tests, boundary and hygiene only (no simulator builds)
set -euo pipefail
cd "$(dirname "$0")/.."

quick=0
[ "${1:-}" = "--quick" ] && quick=1
derived=build/dd
log=build/ci-local
mkdir -p "$log"
started=$(date +%s)
step=0

run() { # run <name> <command...>: quiet on success, the log on failure
  step=$((step + 1))
  local name=$1; shift
  local file="$log/$step.log"
  printf '%2d. %-52s ' "$step" "$name"
  local begin; begin=$(date +%s)
  if "$@" > "$file" 2>&1; then
    printf 'ok  (%ss)\n' $(( $(date +%s) - begin ))
  else
    printf 'FAILED\n\n'
    tail -40 "$file"
    echo
    echo "ci-local: step $step failed; full log in $file"
    exit 1
  fi
}

build() { # build <scheme> <destination>
  xcodebuild -scheme "$1" -destination "generic/platform=$2" -derivedDataPath "$derived" build -quiet
}

hygiene() { # public repo: nothing that identifies an account, a key or a secret
  local files; files=$(git ls-files --cached --others --exclude-standard)
  local bad=0
  if echo "$files" | grep -E '(^|/)GoogleService-Info\.plist$|\.p8$|\.mobileprovision$' ; then bad=1; fi
  # Patterns only: this script must not itself name a real identifier.
  local patterns=(
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'   # email addresses
    'AIza[0-9A-Za-z_-]{35}'                             # Google API keys
    'BEGIN (EC |RSA |OPENSSH )?PRIVATE KEY'              # private keys
    'apps\.apple\.com/[a-z/]*app/[^ ]*id[0-9]{6,}'       # App Store app ids
    'ca-app-pub-[0-9]{10,}'                             # AdMob app / unit ids
  )
  for pattern in "${patterns[@]}"; do
    # shellcheck disable=SC2086
    if echo "$files" | grep -v '^Scripts/ci-local.sh$' | xargs grep -nIE "$pattern" -- 2>/dev/null; then bad=1; fi
  done
  return $bad
}

echo "FallKit local gate$([ $quick -eq 1 ] && echo ' (quick)')"
run "SwiftLint --strict" swiftlint --strict --quiet
run "swift test (macOS)" swift test
run "boundary check self-test" Scripts/check-boundary-selftest.sh
run "public repo hygiene" hygiene
run "OpenSpec validate --strict" openspec validate --all --strict
if command -v shellcheck > /dev/null; then
  run "shellcheck Scripts/*.sh" shellcheck -S warning Scripts/*.sh
fi
if [ $quick -eq 0 ]; then
  run "LiveOpsCore · iOS Simulator" build LiveOpsCore "iOS Simulator"
  run "LiveOpsCore · watchOS Simulator" build LiveOpsCore "watchOS Simulator"
  run "LiveOpsStore · iOS Simulator" build LiveOpsStore "iOS Simulator"
  run "LiveOpsStore · watchOS Simulator" build LiveOpsStore "watchOS Simulator"
  run "LiveOpsTesting · iOS Simulator" build LiveOpsTesting "iOS Simulator"
  run "LiveOpsFirebase · iOS Simulator (compiles Firebase)" build LiveOpsFirebase "iOS Simulator"
  run "LiveOpsFirebase · watchOS Simulator (no Firebase)" build LiveOpsFirebase "watchOS Simulator"
fi
echo "OK in $(( $(date +%s) - started ))s: push allowed"
