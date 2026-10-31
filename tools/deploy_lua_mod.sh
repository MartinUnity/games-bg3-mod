#!/usr/bin/env bash
# Deploy the Script Extender Lua mod workspace (mods/<name>/) as a *loose* mod.
#
# Workspace layout mirrors what a .pak would contain (docs/lua-modding.md sec.2):
#   mods/<name>/Mods/<Folder>/meta.lsx                  module manifest (game/SE need this)
#   mods/<name>/Mods/<Folder>/ScriptExtender/...        Config.json + Lua bootstrap
#   mods/<name>/Public/<Folder>/Stats/...               optional stats overrides
#
# Loose deploy maps that onto the two mounts we already know about:
#   Mods/<Folder>/**    ->  Data/Mods/<Folder>/**     (the module mount; SE reads
#                                                        ScriptExtender/Lua from here)
#   Public/<Folder>/**  ->  Data/Public/<Folder>/**   (same path our stat overrides use)
#
# ⚠️ Loose-mod loading is UNVERIFIED on this install: the documented, known-good route is to
# build a .pak and enable it in the in-game mod manager. This script is the no-tooling path.
#
#   tools/deploy_lua_mod.sh --dry-run    show what would be copied (default)
#   tools/deploy_lua_mod.sh --copy       copy it
#   tools/deploy_lua_mod.sh --remove     delete the deployed copy
set -euo pipefail

WORKSPACE="${1:-mods/more-mobs}"
case "$WORKSPACE" in /*) ;; *) WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/$WORKSPACE" ;; esac
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # Data/Public
DATA="$(cd "$REPO/.." && pwd)"                            # Data

mode=dry
case "${2:-}" in
  "") ;;
  --dry-run) mode=dry ;;
  --copy)  mode=copy ;;
  --remove) mode=remove ;;
  *) echo "usage: $0 [workspace] [--dry-run|--copy|--remove]" >&2; exit 2 ;;
esac

[ -d "$WORKSPACE" ] || { echo "error: no workspace at $WORKSPACE" >&2; exit 1; }

# Folder name comes from the manifest folder, so it cannot drift from meta.lsx.
folder="$(find "$WORKSPACE/Mods" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -1)"
[ -n "$folder" ] || { echo "error: $WORKSPACE/Mods/<Folder> missing" >&2; exit 1; }
[ -f "$WORKSPACE/Mods/$folder/meta.lsx" ] || echo "warning: no meta.lsx for $folder - the game will not list this mod" >&2

if [ "$mode" = copy ] && [ ! -w "$DATA/Mods" ]; then
  echo "error: $DATA/Mods is not writable. Remount rw, then re-run." >&2
  exit 1
fi

copy_tree() { # src dst
  local src="$1" dst="$2" rel
  ( cd "$src" && find . -type f -print ) | while read -r rel; do
    case "$mode" in
      dry)   echo "would copy: $src/${rel#./} -> $dst/${rel#./}" ;;
      copy)  mkdir -p "$dst/$(dirname "$rel")"; cp "$src/$rel" "$dst/$rel"; echo "deployed: $dst/${rel#./}" ;;
      remove) if [ -f "$dst/$rel" ]; then rm "$dst/$rel"; echo "removed: $dst/${rel#./}"; fi ;;
    esac
  done
}

echo "mod folder: $folder   mode: $mode"
[ -d "$WORKSPACE/Mods/$folder" ]   && copy_tree "$WORKSPACE/Mods/$folder" "$DATA/Mods/$folder"
[ -d "$WORKSPACE/Public/$folder" ] && copy_tree "$WORKSPACE/Public/$folder" "$DATA/Public/$folder"

if [ "$mode" != remove ]; then
  cat <<EOF

Next step (load order). The game only loads mods it is told about. Two options:
  a) in-game: Mods screen -> enable '$folder'  (only lists .pak mods; see docs/lua-modding.md sec.4)
  b) by hand: add this UUID to ModOrder and Mods in
     steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/
       Larian Studios/Baldur's Gate 3/modsettings.lsx
     <node id="Module"><attribute id="UUID" value="$(grep -oE 'UUID" type="FixedString" value="[0-9a-f-]+"' "$WORKSPACE/Mods/$folder/meta.lsx" 2>/dev/null | grep -oE '[0-9a-f-]{36}' || echo '<from meta.lsx>')" type="FixedString" /></node>
Then check bin/bg3-print.log (needs LogEnabled=true in bin/ScriptExtenderSettings.json).
EOF
fi
