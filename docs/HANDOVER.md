# HANDOVER — state of play (2026-11-11)

Rotation rule: fresh sessions append a dated entry HERE, newest on top; when an entry is
fully superseded, cut it — the archive is git (`git log --grep=v3.NN`; commit messages are
full changelog entries). Durable API/engine findings go to `docs/GOTCHAS.md`, not here.
The previous full snapshot (2026-10-31: E1/E7/E8 forensics, pak-toolchain hunt, v3.1–v3.21
playtest detail, ranked next-moves at the time) is preserved verbatim in git:
`git show 1c35216:docs/HANDOVER.md`.

## Open right now

- **v3.44 in-game verdicts pending** (class-build roster shipped offline): barb thrower AI
  (3-8 javelins), druid Wild Shape, monk flurry, paladin smites, warlock blast.
  Owner ✅ so far: hexblade (CHA melee), cleric shields. **Dual-wield re-verdict pending**
  (v3.45 fix: `style2_twf` + `UnlockPassive(FightingStyle_TwoWeaponFighting)`).
- **Owner owes**: warlock/hexblade refs (v3.44); full/half/1-3-caster spell lists to widen
  the rolled kits beyond cleric+druid (v3.46, `docs/spells-categories.md`).
- **Scrolls / arrows / grenades AI unverified** — healing-potion use ✅ in-game
  (2026-11-01), the other support-slot items still need a playtest verdict.
- **HP re-verdict**: v3.39 shipped the double-count fix (CHAOST Vitality = level-1 pool,
  engine rolls real hit dice per level); no explicit in-game re-verdict logged yet.
- **Black-screen hangs**: diagnosed as Proton/Vulkan swapchain thrash from alt-tabbing
  (zero mod errors, `game-logs/` evidence); owner PERM fix = Borderless window.
  Verdict = watch for recurrence with borderless on.
- Backlog taste items: goblin Tier2 bodies + tiefling body choice (RACE_VISUALS);
  leader visual distinction; equipment phase 2 (own ItemDB). See `docs/backlog.md`.
- Optional big win (older, still open): lslib **StoryCompiler** offline-compiles
  `MARTIN_*.txt` — gplex/gppg already work on this box (`docs/lua-modding.md` §4); it
  would catch the silent per-rule drops that whole-file errors don't.

## Shipped recently (one line each — full entry in git)

- **v3.47b**: bg3.wiki class-spell pages as ground truth (`docs/wiki-dumps/`,
  `tools/parse_wiki_spells.py --check`); registry class sets rebuilt (BG3 ≠ 5e PHB).
- **v3.47**: spell registry gate (`tools/spell_registry.py`, hard-validated by gen_teams).
- **v3.46**: rolled known-spell kits for cleric+druid (priority groups + Pri weights, CHAOS_SEED).
- **v3.45**: playtest fixes (TWF grants, kit-aware magicGear, cleric kit).
- **v3.44**: class-build roster — BUILDS/SLOT_VARIANTS → 178 entries × 11 donors =
  **1958 CHAOST templates (`!chaos_root` expects 1958)**; pickBuild lvl5+ gates.

## Pointers

- Engine internals: read the code — `mods/chaos-reinforcements/Server/{Common,CreatureDB,Equip,Chaos}.lua`.
- Repo map + landmines: `AGENTS.md`; findings: `docs/GOTCHAS.md`; commands:
  `docs/console-commands.md`; routes to add encounters: `docs/encounters.md`.
- Regeneration needs external inputs: vanilla unpack at
  `/home/martin/Documents/mods/bg3-new/bg3-vanilla-data` (stats only) + live dumps
  (profile `Script Extender/Chaos_root_templates.txt`, 32017 entries); `/tmp` files may be wiped.
