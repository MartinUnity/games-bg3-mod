# Toolchain & regeneration recipes

Everything the mod pipeline needs, and how to rebuild the pieces that live in
`/tmp` (lost on reboot). Commands below are **tested**, not from memory.
All `divine.sh` paths must be absolute.

## What lives where

| Piece | Location | Survives reboot? |
|---|---|---|
| Divine CLI (lslib, net8.0 build) | `tools/divine-cli/` (repo, in git) | ✅ |
| Mod workspace + Lua | `mods/chaos-reinforcements/` (repo) | ✅ |
| Generated DB / teams | `mods/.../Server/CreatureDB.lua`, `CHAOS_Teams.txt`, `ChaosTeams.lsx` (repo) | ✅ |
| Root-template extracts | `/tmp/opencode/rt/*.lsx` (~93 MB) | ❌ — recipe 1 |
| Live Progressions extracts | `/tmp/opencode/prog/` | ❌ — recipe 2 |
| Third-party mod extracts | `/tmp/opencode/mine*` | ❌ — recipe 3 |
| Lua syntax-check venv | `/tmp/opencode/luachk/` | ❌ — recipe 4 |
| Vanilla data unpack (2023, reference only) | `/home/martin/Documents/mods/bg3-new/bg3-vanilla-data` (16 GB) | ❌ if wiped — big extract-package, see recipe 5 |

`tools/divine.sh` resolves the CLI relative to itself; the old hard-coded
`/tmp/opencode/pak/...` path is gone. Divine CLI flags: `-g bg3 -a <action> -s <src> -d <dst> -f <file-in-pak> -i/-o <fmt> -x <glob>`.

Gotchas (all hit and verified):
- `extract-single-file` needs `-d` as a **full file path**, not a directory.
- `convert-resource` takes `-i lsf -o lsx` and no name flag — output keeps the
  source filename, so name the intermediate file what you want the output named.
- No `xml` support in `convert-resource` (loca uses `-a convert-loca`).

## Recipe 1 — root-template extracts (`/tmp/opencode/rt`)

Needed by `build_creature_db.py` (CreatureDB regen). Sources — all six
`_merged.lsf` live in just three paks:

| lsx name (expected by build_creature_db.py) | pak | packaged path |
|---|---|---|
| `merged.lsx` | Shared.pak | `Public/Shared/RootTemplates/_merged.lsf` |
| `shareddev.lsx` | Shared.pak | `Public/SharedDev/RootTemplates/_merged.lsf` |
| `gustav.lsx` | Gustav.pak | `Public/Gustav/RootTemplates/_merged.lsf` |
| `gustavdev.lsx` | Gustav.pak | `Public/GustavDev/RootTemplates/_merged.lsf` |
| `honour.lsx` | Gustav.pak | `Public/Honour/RootTemplates/_merged.lsf` |
| `gustavx.lsx` | GustavX.pak | `Public/GustavX/RootTemplates/_merged.lsf` |

```bash
GAME="/home/martin/.local/share/Steam/steamapps/common/Baldurs Gate 3/Data"
mkdir -p /tmp/opencode/rt
extract() {  # $1 pak, $2 packaged path, $3 out name
  ./tools/divine.sh -g bg3 -a extract-single-file -s "$GAME/$1" -f "$2" -d "/tmp/opencode/rt/$3.lsf"
  ./tools/divine.sh -g bg3 -a convert-resource -i lsf -o lsx \
      -s "/tmp/opencode/rt/$3.lsf" -d "/tmp/opencode/rt/$3.lsx"
  rm "/tmp/opencode/rt/$3.lsf"
}
extract Shared.pak  Public/Shared/RootTemplates/_merged.lsf  merged
extract Shared.pak  Public/SharedDev/RootTemplates/_merged.lsf shareddev
extract Gustav.pak  Public/Gustav/RootTemplates/_merged.lsf  gustav
extract Gustav.pak  Public/GustavDev/RootTemplates/_merged.lsf gustavdev
extract Gustav.pak  Public/Honour/RootTemplates/_merged.lsf  honour
extract GustavX.pak Public/GustavX/RootTemplates/_merged.lsf gustavx
```

Then regenerate the DB: `python3 tools/build_creature_db.py`
(uses the blocklist `tools/db_blocklist.txt`; user review workflow:
`tools/CreatureDB.review.lua` — user deletes lines, diff folds into the blocklist, rebuild).

## Recipe 2 — live Progressions extracts (`/tmp/opencode/prog`)

Needed by `role_catalog.py` / `team_composer.py` (paper-review tools). The live
tables beat the 2023 vanilla unpack — installed rework mods reference
post-patch GUIDs.

```bash
GAME="/home/martin/.local/share/Steam/steamapps/common/Baldurs Gate 3/Data"
mkdir -p /tmp/opencode/prog
./tools/divine.sh -g bg3 -a extract-package -s "$GAME/Shared.pak" -d /tmp/opencode/prog -x "*Progressions.lsx"
./tools/divine.sh -g bg3 -a extract-package -s "$GAME/Gustav.pak" -d /tmp/opencode/prog -x "*Progressions.lsx"
```

## Recipe 3 — third-party mod extracts (`/tmp/opencode/mine*`)

Reference material only (API patterns, UCL progression tables, EO template
shape). Extract from installed paks in the profile Mods folder:

```bash
MODS="/home/martin/.local/share/Steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3/Mods"
./tools/divine.sh -g bg3 -a extract-package -s "$MODS/UtutsCoreLibrary.pak" -d /tmp/opencode/mine3
# (mine2 = EncountersOverhaul, mine3 = UtutsCoreLibrary/ManyMoreMonsters/Goon's Squad Combat)
```

`gen_teams.py` hard-codes the verified UCL table GUIDs, so team generation does
NOT need this — only the paper-review tools do.

## Recipe 4 — Lua syntax-check venv (`/tmp/opencode/luachk`)

```bash
python3 -m venv /tmp/opencode/luachk
/tmp/opencode/luachk/bin/pip install lupa
# usage:
/tmp/opencode/luachk/bin/python -c "import lupa; rt=lupa.LuaRuntime(); \
  print('compile OK' if rt.eval('load')(open('FILE.lua').read()) else 'SYNTAX ERROR')"
```

## Recipe 5 — vanilla unpack (reference baseline)

`/home/martin/Documents/mods/bg3-new/bg3-vanilla-data` (16 GB, 2023-era,
**predates Patch 7+ nodes** — prefer live extracts where they exist).
If lost, rebuild the needed subtree only, e.g. stats:

```bash
GAME="/home/martin/.local/share/Steam/steamapps/common/Baldurs Gate 3/Data"
./tools/divine.sh -g bg3 -a extract-package -s "$GAME/Shared.pak" -d <DEST> -x "*Stats/*"
```

## Pack & install

```bash
./tools/pack_mod.sh mods/chaos-reinforcements --install
```

Stages the workspace into a space-free temp dir (Divine silently makes an
EMPTY pak when the source path contains spaces), packs with
`--package-version=V3`, installs into the profile Mods folder. `--remove`
uninstalls. After installing, the mod must be enabled in
`PlayerProfiles/Public/modsettings.lsx` (already done on this install).
