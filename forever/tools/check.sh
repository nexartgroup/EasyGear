#!/usr/bin/env bash
# Static checks against the WoW Forever UI source.
#
#   tools/check.sh <Interface/AddOns of the Forever UI source>
#
# Needs luacheck (luarocks install luacheck) and python3. The UI source is the "forever" branch of
# Gethe/wow-ui-source; only Interface/AddOns is read. Builds .cache/ (not committed).
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:?usage: tools/check.sh <path to Interface/AddOns of the Forever UI source>}"

mkdir -p .cache
python3 tools/forever_std.py "$SRC" .cache
luacheck EasyGear
python3 tools/check_api.py .cache
