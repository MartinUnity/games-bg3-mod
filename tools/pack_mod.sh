#!/usr/bin/env bash
# Pack the mod workspace (mods/<name>/) into a .pak and install it into the game's
# Mods directory (the profile under the Proton prefix). This is the known-good route:
# the game's mod manager only lists .pak mods (docs/lua-modding.md sec.2/4).
#
#   tools/pack_mod.sh                 pack into /tmp and list contents (default)
#   tools/pack_mod.sh --install       pack + copy into .../Baldur's Gate 3/Mods/
#   tools/pack_mod.sh --remove        delete the installed .pak
#
# Notes (verified 2026-10-31 with the native Divine build, tools/divine.sh):
# - The workspace root (containing Mods/<Folder>/...) is the package root; do NOT add
#   a second meta.lsx at the very root (vanilla paks have meta only under Mods/<Folder>/).
# - meta.lsx must use the vanilla serialization (e.g. Type as type="int32" value="1").
# - Divine silently produces an EMPTY pak when the source path contains spaces: always
#   stage the tree into a space-free temp dir first (done below).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # Data/Public
DIVINE="$REPO/tools/divine.sh"
WORKSPACE="${1:-mods/chaos-reinforcements}"
case "$WORKSPACE" in /*) ;; *) WORKSPACE="$REPO/$WORKSPACE" ;; esac

mode=pack
case "${2:-}" in
  "")         mode=pack ;;
  --install)  mode=install ;;
  --remove)   mode=remove ;;
  *) echo "usage: $0 [workspace] [--install|--remove]" >&2; exit 2 ;; esac

[ -x "$DIVINE" ] || { echo "error: $DIVINE missing/executable" >&2; exit 1; }
[ -d "$WORKSPACE/Mods" ] || { echo "error: no Mods/ dir in $WORKSPACE" >&2; exit 1; }

folder="$(find "$WORKSPACE/Mods" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -1)"
[ -f "$WORKSPACE/Mods/$folder/meta.lsx" ] || { echo "error: $WORKSPACE/Mods/$folder/meta.lsx missing" >&2; exit 1; }

GAME_MODS="/home/martin/.local/share/Steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3/Mods"
PAK="$GAME_MODS/$folder.pak"

if [ "$mode" = remove ]; then
  if [ -f "$PAK" ]; then rm "$PAK" && echo "removed: $PAK"; else echo "not installed: $PAK"; fi
  exit 0
fi

stage="$(mktemp -d /tmp/opencode/pakbuild.XXXX)"
cp -r "$WORKSPACE/Mods" "$stage/"
# mods can also ship game data (e.g. Public/<Module>/Stats/... for custom stat entries)
# and localization (top-level Localization/English/*.loca, built from the .xml source
# via tools/divine.sh -a convert-loca - proven route: third-party paks on this install
# ship exactly that layout)
srccount="$(find "$stage/Mods" -type f | wc -l)"
if [ -d "$WORKSPACE/Public" ]; then
    cp -r "$WORKSPACE/Public" "$stage/"
    srccount="$((srccount + $(find "$WORKSPACE/Public" -type f | wc -l)))"
fi
if [ -d "$WORKSPACE/Localization" ]; then
    cp -r "$WORKSPACE/Localization" "$stage/"
    srccount="$((srccount + $(find "$WORKSPACE/Localization" -type f | wc -l)))"
fi
"$DIVINE" -g bg3 -a create-package -s "$stage" -d "$stage/$folder.pak" >/dev/null
# guard: Divine can silently emit a header-only pak
if [ "$srccount" != "$("$DIVINE" -g bg3 -a list-package -s "$stage/$folder.pak" | wc -l)" ]; then
  echo "error: pak entry count does not match source file count" >&2
  "$DIVINE" -g bg3 -a list-package -s "$stage/$folder.pak" >&2 || true
  rm -rf "$stage"; exit 1
fi

echo "packed: $folder.pak ($(stat -c%s "$stage/$folder.pak") bytes)"
"$DIVINE" -g bg3 -a list-package -s "$stage/$folder.pak"

if [ "$mode" = install ]; then
  cp "$stage/$folder.pak" "$PAK"
  echo "installed: $PAK"
  echo "next: start game -> Mods screen -> enable '$folder' (first run with the new DWrite.dll lets the SE auto-updater fetch v33)"
fi
rm -rf "$stage"
