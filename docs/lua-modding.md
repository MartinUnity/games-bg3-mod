# Lua / Script Extender channel — fundamentals and the state on this box

Distilled from the codedex tutorial *Make a Baldur's Gate 3 Mod with Lua*
(<https://www.codedex.io/projects/make-a-bg3-mod-with-lua>, Julien Kris, 2025-09-03) and from
Norbyte's Script Extender API doc, vendored at `docs/vendor/bg3se-Lua-API.md` (fetched
2026-10-31, "Lua API v30" text, SE v33 installed). Everything marked ✅ was checked on this
install; ⚠️ still needs an in-game test.

## 0. Why this channel, and what it costs

- **Cost:** mods disable Steam achievements in BG3 (Patch 7+ in-game manager and third-party
  managers alike; community consensus, ⚠️ not re-tested here). Our whole `Data/Public` overlay
  workflow exists to dodge that — it is a *basegame override*, not a mod, so the game never
  flags the save as modded. Lua/SE gives up that property.
- **Gain:** logging. Lua runs *after* the story compiler, so we can prove whether a rule runs,
  see which templates exist, and iterate without a new game. That is exactly what the story
  channel cannot tell us (docs/spawn-chains.md §3.1.1).
- **Recommended shape:** use Lua as the lab (probe + template dump + spawn mechanics), then
  port whatever works back into `MARTIN_*.txt` goals if achievements matter for the run.
  Lua and Osiris use the *same* primitives (`Osi.CreateAtObject(...)` ≡ `CreateAtObject(...)`),
  so a working Lua rule ports almost line for line.

## 1. Script Extender on this install ✅

| Fact | Evidence |
|---|---|
| Windows build under Proton; prefix `steamapps/compatdata/1086940` | `C:/users/steamuser/...` paths in `bin/gold.*.log` |
| `bin/DWrite.dll` is the **SE auto-updater**, not the game's DWrite | `strings -el` → "BG3 Script Extender Auto-Updater DLL", "(c) Norbyte" |
| Loaded only because Steam launch options force it native: `WINEDLLOVERRIDES="DWrite.dll=n,b" %command%` | user-reported; required because Wine would otherwise satisfy DWrite itself |
| **Lua mods were silently failing for other reasons (2026-10-31 forensics):** no SE runtime log was ever configured (`LogEnabled` is not a real v33 key) and `bg3-print.log` is obsolete in v33, so Lua errors were invisible. The extender itself *is* present — v33 is staged under `AppData/Local/BG3ScriptExtender/ScriptExtender/` (pkg mtime Oct 30) and **loads** (evidence: our probe's template dump was written on `SessionLoaded` 2026-10-31 09:56). | prefix forensics + `Ext.IO.SaveFile` dump present |
| Re-installed the official v33 updater (Oct-12) to `bin/DWrite.dll` to be safe (old kept as `bin/DWrite.dll.bak-2024`) | GitHub release + deployed file |
| SE settings live in `bin/ScriptExtenderSettings.json` (v33 keys: `LogRuntime`/`LogCompile`/`EnableLogging`/`LogDirectory`/`CreateConsole`) | `strings` of the staged v33 DLL |
| SE per-mod config/state under `…/AppData/Local/Larian Studios/Baldur's Gate 3/Script Extender/` | `5eSpells/`, `Expansion/` jsons from old SE mods |
| Installed mod `.pak`s live in `…/AppData/Local/Larian Studios/Baldur's Gate 3/Mods/` | 20 paks there (EncountersOverhaul, ManyMoreMonsters, `extra_enemies_honour`, …) |
| Load order lives in `…/Baldur's Gate 3/PlayerProfiles/Public/modsettings.lsx` (live; base module **GustavX**, several mods enabled). The root-level `…/Baldur's Gate 3/modsettings.lsx` (2024) is legacy | mtime forensics |
| `Data/Mods/` and `Data/Public/` are both writable as of 2026-10-31 | `touch` probe |

Logging on this SE v33 (verified against the DLL's strings, 2026-10-31): the settings keys are
`LogRuntime` (Lua `Ext.Print`/errors — the one we want), `LogCompile` (story compile),
`EnableLogging` (very verbose Osiris runtime), `LogDirectory`, `CreateConsole`. The old
`LogEnabled` key and `bg3-print.log` filename are obsolete — nothing is written unless
`LogRuntime:true`. Default log dir is under the *Proton prefix*:
`compatdata/1086940/pfx/drive_c/users/steamuser/Script Extender Logs/Extender Runtime.log`
(readable natively; `LogDirectory` can redirect, e.g. `"Z:\\home\\martin\\..."`).
`CreateConsole:true` opens the SE Lua console but renders unreliably under Proton; the file
route is the reliable one. `Ext.IO.SaveFile` writes into the profile's `Script Extender/`
folder and was proven to work — probe v2 mirrors all its logging there too
(`MARTIN_probe.log`) as a belt-and-braces channel. SE itself stages into
`AppData/Local/BG3ScriptExtender/ScriptExtender/<version>_<hash>/BG3ScriptExtender.dll` (not
`bin/`) — check there, not bin, for "is SE installed".

## 2. Anatomy of a mod ✅ (layout is not optional)

A mod is a **workspace folder** with two roots; a pak is just this tree compressed:

```
mods/<workspace>/
  Mods/<Folder>/meta.lsx                      <- manifest: the game's mod list reads this
  Mods/<Folder>/ScriptExtender/Config.json    <- SE feature switch (FeatureFlags: ["Lua"])
  Mods/<Folder>/ScriptExtender/Lua/BootstrapServer.lua   <- server state (Osiris lives here)
  Mods/<Folder>/ScriptExtender/Lua/BootstrapClient.lua   <- client state (UI, formulas)
  Mods/<Folder>/ScriptExtender/Lua/Server/<yours>.lua    <- loaded via Ext.Require("Server/<yours>.lua")
  Public/<Folder>/Stats/Generated/Data/*.txt  <- optional stats overrides (same grammar as ours)
  Public/<Folder>/RootTemplates/, Localization/English/  <- templates and loca, if needed
```

`Config.json` keys (API doc "Getting Started"): `RequiredVersion` (SE version you developed
against — use 33 here), `ModTable` (unique global Lua table name, unrelated to `Folder`),
`FeatureFlags` (`["Lua"]`).

`meta.lsx` (bg3.wiki *Modding:Meta.lsx* template, vendored shape in
`mods/more-mobs/Mods/MARTIN_MoreMobs/meta.lsx`): `ModuleInfo` with `UUID` (must be unique),
`Folder` (**must equal the `Mods/<Folder>` directory name or the mod breaks**), `Name`,
`Author`, `Description`, `Version64` (int64; `36028797018963968` = 1.0.0.0), `PublishVersion`,
`TargetModes/Object = Story`. Two gotchas from the wiki: no `meta.lsx` is needed only for
"basegame overrides" (the orange/Overrides entries — that is what our `Data/Public` edits are),
and a `Name` starting with `-b` reportedly stops the mod loading.

Bootstrap rules: `Ext.Require` only at module startup, paths relative to the Lua folder; server
and client are **separate Lua states**, and Osiris/`Osi.*` only exists on the server side.

## 3. Post-mortem: why `HealthBoostLocal`/`HPChaos` never appeared ⚠️ → ✅

They sat at `Data/Mods/HealthBoostLocal/{Mod.json, ScriptExtender/Lua/…}` (and in the game
root's `Mods/`). Against the layout above, four defects, in order of severity:

1. **No `meta.lsx`** — `Mod.json` is not a BG3 manifest. Without it the game never lists the
   mod, so it is never *loaded*, so SE never sees its `ScriptExtender/` folder.
2. **Not in the load order** — nothing in `modsettings.lsx` referenced it; the game loads mods
   from the list, not by scanning folders.
3. **No `ScriptExtender/Config.json`** — even a loaded mod needs `FeatureFlags:["Lua"]` before
   SE will run its bootstrap.
4. **The Lua used APIs that do not exist** in SE: `Ext.RegisterListener("CharacterCreated", …)`,
   `Ext.GetDifficulty`, `Ext.StatusAdd`, `Ext.Debug`, `Ext.Random(1,100)`. The real ones are
   `Ext.Osiris.RegisterListener(name, arity, when, fn)`, `Ext.Events.<Name>:Subscribe(fn)`,
   `Ext.RandomInteger`, `Osi.StatusApply(...)` / `_C().Vars.*`. With no runtime logging enabled
   (v33 needs `LogRuntime:true`; `LogEnabled` is not a real key), every load error was silently
   invisible.

So nothing about the SE install was broken; the mod was never registered and the script was
hallucinated. Both fixable, and `mods/more-mobs/` is the corrected skeleton.

## 4. Getting the game to load it

- **Known-good route (needs a pak tool):** build a `.pak` from the workspace and drop it in
  `…/AppData/Local/Larian Studios/Baldur's Gate 3/Mods/`, then enable it in the in-game Mods
  screen. Tooling is Windows-first (BG3 Modder's Multitool, BG3 Mod Manager, BG3 Mini Tool);
  ⚠️ no Linux CLI packer verified on this box yet. BG3 Mod Manager reportedly runs under
  Proton/Wine for this game (Nexus guide, Oct 2025).
- **No-tooling route (⚠️ unverified):** `tools/deploy_lua_mod.sh --copy` mirrors the workspace
  into `Data/Mods/<Folder>/` (module mount) and `Data/Public/<Folder>/` (stats), then register
  the `meta.lsx` UUID in `modsettings.lsx`. This is the "basegame override"/loose-folder idea
  and may simply not be scanned; the test is whether the boot print shows in `bg3-print.log`.
- **Pak CLI ✅ BUILT AND ROUND-TRIP-PROVEN 2026-10-31.** `tools/divine.sh` wraps a native Linux
  build of lslib v1.20.4 `Divine` (source at `/tmp/opencode/pak/lslib` — rebuild there if lost):
  `tools/divine.sh -g bg3 -a list-package|extract-package|create-package -s SRC -d DST`.
  Build recipe on this box (dotnet 8.0.424), all deviations from stock lslib recorded:
  1. `dotnet tool install --global Springcomp.GPLEX` + `Springcomp.GPPG` (tool IDs are *not*
     `gplex`/`gppg`); generate `Goal.lex.cs`/`Goal.yy.cs` + `StoryHeader.lex.cs`/`StoryHeader.yy.cs`
     (repo does not commit them; their PreBuildEvent binaries are Windows-only). Run with cwd =
     repo root, then `sed` the relative `#line` paths in the .yy.cs to absolute, or C# errors.
  2. Their generated code says `using StarodubOleg.GPPG.Runtime;` — swap to `using QUT.Gppg;`
     (lslib vendors that runtime in `LSLib/LS/Stats/ShiftReduceParser.cs`; the NuGet fork's
     generics constraints don't fit).
  3. Drop the `LSLibNative.vcxproj` ProjectReference (C++/CLI, Windows-only, no P/Invoke in
     C#); exclude `Granny/**/*.cs` from LSLib and `CLI/CommandLineGR2Processor.cs` from Divine
     (only users of the native types); add `LSLib/NativeShims.cs` (K4os-based LZ4 frame
     decompress; FastLZ stubs — VT-only, BG3 paks don't hit them).
  4. Patched `TryToValidatePath` upstream bug: paths with spaces crashed (`uri.IsFile` on a
     relative URI).
  Build: `dotnet build Divine/Divine.csproj -c Release -p:PreBuildEvent=`.
- **Divine CLI gotchas (all bit us):** `create-package` **silently produces an empty 48-byte pak
  if the source path contains spaces** → always stage to a space-free temp dir first. The pak
  root must be the workspace dir (containing `Mods/<Folder>/`); vanilla paks carry `meta.lsx`
  only under `Mods/<Folder>/`, never at the pak root. `meta.lsx` must use vanilla types —
  `Type` is `type="int32" value="1"` (the bg3.wiki template's `FixedString "Add-on"` form is
  stale). Hash column 0 in `list-package` is normal.
- **Deploy helper:** `tools/pack_mod.sh [workspace] [--install|--remove]` stages the workspace
  to /tmp, packs via divine.sh, verifies entry count, and installs
  `MARTIN_MoreMobs.pak` into the profile `Mods/` dir. Then enable in-game.
- **Native alternative (⚠️ unexplored):** `lenonk/bg3le` is a Script Extender for the *native
  Linux* build ("SE mods load straight out of their .paks or from loose directories via
  `BG3LE_MOD_PATH`"). Our install is the Windows build under Proton, so it does not apply
  unless we switch builds — but it would remove the Wine/DWrite override entirely.

## 5. The bits of the API that matter for "more mobs"

All from `docs/vendor/bg3se-Lua-API.md`; Osiris signatures from
`Data/Mods/GustavDev/Story/RawFiles/story_header.div`.

| Need | Lua | Notes |
|---|---|---|
| react to combat starting | `Ext.Osiris.RegisterListener("CombatStarted", 1, "after", fn)` | arity = column count; also captures DBs, PROCs, QRYs; `"before"` can veto/observe first |
| spawn a body anchored on a character | `local h = Osi.CreateAtObject(tpl, anchor, 1, 1, "", 1)` | header:508 `CreateAtObject(TemplateId, Anchor, Temporary, PlaySpawn, SpawnFinishEvent, MatchOrientation, out)` |
| spawn at coordinates | `Osi.CreateAt(tpl, x, y, z, 1, 0, "")` | header:507 `(TemplateId, X, Y, Z, Temporary, PlaySpawn, SpawnFinishEvent, out)`; vanilla example `Gustav/…/Test.txt:353` |
| find a legal position | `Osi.FindValidPosition(sx,sy,sz,radius,obj,avoidDangerous,outX,outY,outZ)` | header:573 |
| ground height at a point | `Ext.Level.GetHeightsAt(x, z)` | `Ext.Level` also has `GetEntitiesOnTile`, raycasts, pathfinding — better than anything in the goal grammar |
| make it hostile and join the fight | `Osi.SetFaction(h, "Evil_4be9261a-…"); Osi.SetHostileAndEnterCombat("Evil_…","Hero_…", h, host)` | header:933 / :921 |
| **list every template name** | `Ext.Template.GetAllRootTemplates()` | the answer to our "does this template exist here" problem; dump with `Ext.IO.SaveFile` |
| read/write story state | `Osi.DB_Fact:Get(nil, …)`, `Osi.DB_Fact(...)`, `Osi.DB_Fact:Delete(…)` | `nil` = `_` wildcard; also `Osi.Qry_*`, `Osi.Proc_*` |
| survive reloads | `Ext.Vars.RegisterModVariable(ModuleUUID, "Done")` | Lua state is wiped on reload; `PersistentVars` is deprecated |
| delay a spawn | `Ext.Timer` / `Ext.OnNextTick` | avoids the "spawn during combat init" edge cases |

Lifetime rule that bites: engine objects handed to Lua expire at the end of the game loop —
don't stash an `Ext.Entity`/component in a closure and use it on a later tick (API doc
"Object Scopes"). Re-fetch by handle instead.

## 6. Skeleton in this repo

`mods/more-mobs/Mods/MARTIN_MoreMobs/` = `meta.lsx` + `Config.json` + `BootstrapServer.lua` +
`Server/Probe.lua`. The probe logs on `SessionLoaded`, dumps every root template to
`MARTIN_root_templates.txt`, spawns one imp (level-native template) and one wolf (foreign
template) at the host on every `CombatStarted`, and registers `!martin_spawn` for the console.
Expected first-run reading: if the boot line appears, the channel is live and the log tells us
which of the two templates fails; if nothing appears, it is a loading/registration problem
(§4), not a Lua problem.
