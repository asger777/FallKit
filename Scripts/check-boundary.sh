#!/bin/bash
# SDK boundary check (Docs/live-ops-rule.md, rule #8). Fails when any Swift file
# under the given directories imports a module the kit owns. For an app that
# adopted LiveOpsKit the expected count is zero: the kit is the importer.
#
#   Scripts/check-boundary.sh [--module <name>]... [--allow <file>]... <dir>...
#
# --module defaults to FirebaseRemoteConfig. --allow exempts one file (the kit's
# own transport). Every import form counts: `@testable`, `@_exported`, access
# modifiers and `import struct Module.Type`. Exit: 0 clean · 1 violation · 2 usage.
set -euo pipefail

modules=() allowed=() dirs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --module) modules+=("${2:?--module needs a name}"); shift 2 ;;
    --allow) allowed+=("$(cd "$(dirname "${2:?--allow needs a file}")" && pwd)/$(basename "$2")"); shift 2 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    -*) echo "check-boundary: unknown option $1" >&2; exit 2 ;;
    *) dirs+=("$1"); shift ;;
  esac
done
[ ${#dirs[@]} -gt 0 ] || { echo "usage: $0 [--module <name>]... [--allow <file>]... <dir>..." >&2; exit 2; }
[ ${#modules[@]} -gt 0 ] || modules=(FirebaseRemoteConfig)
for dir in "${dirs[@]}"; do
  [ -d "$dir" ] || { echo "check-boundary: no directory $dir" >&2; exit 2; }
done

violations=0
for module in "${modules[@]}"; do
  pattern="^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*((public|package|internal|fileprivate|private)[[:space:]]+)?import[[:space:]]+([a-z]+[[:space:]]+)?${module}([.[:space:]]|$)"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    absolute="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
    skip=0
    for allow in ${allowed[@]+"${allowed[@]}"}; do [ "$absolute" = "$allow" ] && skip=1; done
    [ $skip -eq 1 ] && continue
    echo "✗ $file imports $module"
    violations=$((violations + 1))
  done < <(for dir in "${dirs[@]}"; do
             find "$dir" -name '*.swift' -not -path '*/.build/*' -not -path '*/build/*' -print0 \
               | xargs -0 grep -lE "$pattern" 2>/dev/null || true
           done | sort -u)
done

if [ $violations -eq 0 ]; then
  echo "✓ no file imports ${modules[*]}"
  exit 0
fi
echo "$violations violation(s)"
exit 1
