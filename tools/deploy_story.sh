#!/usr/bin/env bash
# Copy our own story-goal files from the repo into Data/Mods/<Module>/Story/.
#
# Two candidate places for loose Osiris goals (docs/spawn-chains.md sec.3):
#   1. Data/Public/<Module>/Story/RawFiles/Goals/   <- this repo, live like stat overrides
#   2. Data/Mods/<Module>/Story/RawFiles/Goals/     <- where the decompiled vanilla goals are
# The repo copy (1) is the master. If an in-game test shows the goal is not picked up
# from (1), this script puts a copy in (2) as well.
#
#   tools/deploy_story.sh --dry-run    show what would be copied (default)
#   tools/deploy_story.sh --copy       copy them
#   tools/deploy_story.sh --remove     delete the copies in Data/Mods/
#
# Only files whose name starts with PREFIX are ever touched, so vanilla goals in
# Data/Mods/ are never overwritten or deleted.
set -euo pipefail

PREFIX="MARTIN_"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DST="$(cd "$REPO/.." && pwd)/Mods"      # Data/Mods, sibling of Data/Public (repo = Data/Public)

mode=dry
case "${1:-}" in
  "") ;;
  --dry-run) mode=dry ;;
  --copy)  mode=copy ;;
  --remove) mode=remove ;;
  *) echo "usage: $0 [--dry-run|--copy|--remove]" >&2; exit 2 ;;
esac

shopt -s globstar nullglob
if [ "$mode" = copy ] && [ -d "$DST" ] && ! touch "$DST/.deploy_story_wtest" 2>/dev/null; then
  echo "error: $DST is not writable (read-only mount). Remount rw, then re-run." >&2
  exit 1
fi
rm -f "$DST/.deploy_story_wtest" 2>/dev/null || true

count=0
for f in "$REPO"/*/Story/RawFiles/Goals/"$PREFIX"*.txt; do
  rel="${f#"$REPO"/}"          # <Module>/Story/RawFiles/Goals/<name>.txt
  target="$DST/$rel"
  count=$((count + 1))
  case "$mode" in
    dry)
      echo "would copy: $rel -> $target"
      [ -f "$target" ] && echo "            (overwrites existing copy)"
      ;;
    copy)
      mkdir -p "$(dirname "$target")"
      cp "$f" "$target"        # bytes verbatim: goal files are CRLF
      echo "deployed: $target"
      ;;
    remove)
      if [ -f "$target" ]; then rm "$target"; echo "removed: $target"; fi
      ;;
  esac
done

echo "$mode: $count file(s) matching $PREFIX*.txt in the repo"
if [ "$mode" = dry ] && [ "$count" -gt 0 ]; then
  echo "note: Data/Mods is currently on a read-only mount; remount rw before --copy."
fi
