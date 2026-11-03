# Console command reference (ChaosReinforcements)

In-game Script Extender console: press **~** (tilde) during a game session.
Commands below are ours; anything **without** a `!` is executed as raw Lua in the
server's global context (advanced escape hatch, see §4).

**Where output goes:** every command logs through our `log()` into the profile file

```
…/AppData/Local/Larian Studios/Baldur's Gate 3/Script Extender/ChaosReinforcements.log
```

not into the console window — watch it live with

```bash
tail -f "/home/martin/.local/share/Steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3/Script Extender/ChaosReinforcements.log"
```

Every command works without re-packing; force overrides are memory-only (cleared on
game restart, nothing persisted).

## 1. At a glance

| Command | What it does | Skips which gates? |
|---|---|---|
| `!chaos` | Force a **reinforcement wave** into the current fight right now | skips the ~30%+stack trigger roll only |
| `!chaos_status` | One-shot snapshot of both engines (see §3.2) | nothing, read-only |
| `!chaos_wolf` | Spawn one vanilla wolf at the host (spawn-primitive smoke test) | n/a (direct spawn) |
| `!chaos_root` | Count our CHAOST_* root templates registered in the live game (**expect 1958**) | n/a, read-only |
| `!chaos_toggle wilds\|reinforce` | Flip an engine on/off (same as the two self-shouts on the action bar) | n/a |
| `!chaos_force …` | Targeted wild-mode test overrides: spawn chance, creature type, tier (§3.6) | chance roll + region theme + faction roll only |
| `!chaos_rename <text>` | Rename the host character (flavor escape hatch) | n/a |

## 2. Non-console equivalent

Two **self-shouts** on every character's action bar (granted automatically):
`Chaos Wilds` and `Chaos Reinforce` toggle the wandering-groups / combat-reinforcement
engines. Same state as `!chaos_toggle`.

## 3. Commands in detail

### 3.1 `!chaos` — force a reinforcement wave
Runs the reinforcement engine against the CURRENT combat immediately:
`wave: type … budget …` lines follow, waves spawn ~1.5 s after the command.
Use mid-fight to test composition (TEAM mode, leaders, gear). Bypasses only the
per-combat chance roll; if no fight is active, `discover(nil, …)` classifies nothing —
it acts like a no-fight call (pool fallback), so call it DURING a fight.

### 3.2 `!chaos_status` — pipeline snapshot
Two lines:
```
status: misses N combats seen M | toggles: wilds ON reinforce ON
wild: lvl WLD_Main_A | groups 2/3 | backoff 4min | campers 0 - | crime WLD_Main_A_FAR | fight pending | misses 3 (next 36-54%) | force - | gate clear
```
- `misses` = combat rolls without a wave (each adds +10-30% to the next roll)
- `groups n/3` = live wild groups vs cap; `backoff` = minutes left of the post-fight cooldown
- `campers N` = characters with a camp latch (0 when out of camp; summons/pets count and
  never clear — the `camp-quiet Xs` part is the real wake/sleep signal)
- `misses N (next lo-hi%)` = the wild heartbeat stack (each miss adds +2-8%)
- `force …` = active `!chaos_force` overrides; `gate` = why the last heartbeat was blocked

### 3.3 `!chaos_wolf`
Spawns `Wolf_41da0eff-…` at the host. Proves the create→faction→position primitive chain
still works (e.g. after an engine or game update). It is NOT hostile — just visible.

### 3.4 `!chaos_root` — template registration check
Prints `chaos_root: 1958/32xxx CHAOST_*` — our generated team templates as loaded by the
engine. **Anything but 1958 means the pak's RootTemplates .lsf didn't load** (lsx-only paks
register ZERO — pack_mod.sh converts automatically). Run it after every fresh install.

### 3.5 `!chaos_toggle wilds|reinforce`
Same flip as the shouts; argument-less call prints usage.

### 3.6 `!chaos_force` — targeted test overrides (v3.35)
```
!chaos_force                # show what's currently forced
!chaos_force off            # clear ALL overrides
!chaos_force spawn on       # every 90s heartbeat passes the chance roll (off to restore)
!chaos_force type Humanoid  # force group flavor: Beast | Monstrosity | Humanoid | Undead | Fiend
!chaos_force tier 2         # force squad tier 1 (pack) / 2 (warband+leader) / 3 (horde+boss)
```
- `type Humanoid` guarantees **TEAM-mode squads** (class roles, one donor race,
  donor-race leader) and forces evil packs (no neutral travelers), and it beats the
  region theme (goblin-camp themed pools are skipped).
- **Sanity gates still apply in force mode**: camp guard/quiet window, host-in-combat,
  safe havens (grove/camp/cinematics + safe crime regions), post-fight backoff, and the
  3-group cap. (That's deliberate — camp must stay spawn-free.)
- Typical iteration session: `!chaos_force spawn on` + `!chaos_force type Humanoid` →
  one humanoid squad per heartbeat; `!chaos_force off` when satisfied.

### 3.7 `!chaos_rename <text>`
Sets the host's story display name (was the escape hatch for the nameless-mob bug —
kept as flavor/debug tool). Spaces work; empty name is rejected.

## 4. Raw Lua (not a command, but powerful)

Anything typed WITHOUT `!` runs as server Lua in global context, e.g.:

```lua
_P(Osi.GetLevel(GetHostCharacter()))          -- _P prints to the console window itself
Osi.SetLevel(...)                             -- NEVER: hard-crashes bg3.exe (v3.3 lesson)
```
Useful for one-off `Osi.*` calls; our `log()` is callable too, so
`log("x", something)` writes into our log file. Beware: mistakes can crash the game —
no call in our Lua uses a crash-prone API for a reason.

## 5. Not (yet) commands — candidates when a need shows up

Things people try first that DON'T exist as commands (say the word and we'll add):
- `!chaos_wild` — trigger a wild heartbeat roll NOW instead of waiting ≤90 s
- `!chaos_despawn` — despawn all tracked wild groups (clean slate between test waves)
- `!chaos_reset` — clear backoff + miss stacks (skip the 8-10 min post-fight cooldown while iterating)
- `!chaos_force race <key>` — pin the TEAM donor race (human/elf/halfelf/halfling/dwarf/tiefling/gith/goblin/halforc) instead of random-per-wave
- `!chaos_force leader on` — force the 10% leader roll (removed with TEST_MODE in v3.33)

Maintenance: when you add/remove an `Ext.RegisterConsoleCommand`, update this file —
this table is the single reference point.
