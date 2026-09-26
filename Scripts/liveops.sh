#!/bin/bash
# FallKit live-ops tooling (Docs/live-ops-rule.md, rule #11). READ-ONLY: it
# reads a Remote Config template (`firebase remoteconfig:get`, needs
# `firebase login`) and App Store Connect In-App Events (GET appEvents, token
# from ~/.appstoreconnect/asc_token.rb), then runs the `liveops` CLI.
#
#   Scripts/liveops.sh --manifest <file> [--project <firebase-project>] [--app-id <asc-app-id>] <command>
#
# Commands: values · check-inapp-events · validate
# LIVEOPS_TEMPLATE=<file> and LIVEOPS_APP_EVENTS=<file> use saved JSON instead
# of fetching. Project and app IDs are arguments, never part of this repo.
set -euo pipefail

usage() {
  echo "usage: $0 --manifest <file> [--project <firebase-project>] [--app-id <asc-app-id>] values|check-inapp-events|validate" >&2
  exit 2
}

kit=$(cd "$(dirname "$0")/.." && pwd)
manifest="" project="" app_id="" command=""
while [ $# -gt 0 ]; do
  case "$1" in
    --manifest) manifest=${2:-}; shift 2 ;;
    --project) project=${2:-}; shift 2 ;;
    --app-id) app_id=${2:-}; shift 2 ;;
    -h|--help) usage ;;
    values|check-inapp-events|validate) command=$1; shift ;;
    *) echo "liveops: unknown argument $1" >&2; usage ;;
  esac
done
[ -n "$manifest" ] && [ -n "$command" ] || usage
[ -f "$manifest" ] || { echo "liveops: no manifest at $manifest" >&2; exit 2; }

out="${TMPDIR:-/tmp}/fallkit-liveops/${project:-local}"
mkdir -p "$out"

swift build -c release --package-path "$kit" --product liveops > "$out/build.log" 2>&1 \
  || { cat "$out/build.log" >&2; echo "liveops: build failed" >&2; exit 2; }
cli="$kit/.build/release/liveops"

if [ "$command" = "validate" ]; then
  exec "$cli" validate --manifest "$manifest"
fi

template=${LIVEOPS_TEMPLATE:-}
if [ -z "$template" ]; then
  [ -n "$project" ] || { echo "liveops: --project is required unless LIVEOPS_TEMPLATE is set" >&2; exit 2; }
  template="$out/template.json"
  firebase remoteconfig:get --project "$project" -o "$template" > /dev/null 2> "$out/firebase.log" \
    || { cat "$out/firebase.log" >&2; echo "liveops: firebase remoteconfig:get failed (firebase login?)" >&2; exit 2; }
fi

if [ "$command" = "values" ]; then
  exec "$cli" values --manifest "$manifest" --template "$template"
fi

events=${LIVEOPS_APP_EVENTS:-}
if [ -z "$events" ]; then
  [ -n "$app_id" ] || { echo "liveops: --app-id is required unless LIVEOPS_APP_EVENTS is set" >&2; exit 2; }
  events="$out/appEvents.json"
  token=$(ruby "$HOME/.appstoreconnect/asc_token.rb")
  curl -sS -f -H "Authorization: Bearer $token" \
    "https://api.appstoreconnect.apple.com/v1/apps/$app_id/appEvents?limit=200" -o "$events" \
    || { echo "liveops: App Store Connect appEvents request failed" >&2; exit 2; }
fi
exec "$cli" check-inapp-events --manifest "$manifest" --template "$template" --app-events "$events"
