# Bleach: Blood War Fighters (working title)

A 2D pixel-art platform fighter in the spirit of Super Smash Bros., themed on
*Bleach: Thousand-Year Blood War*. Built with **Godot 4.7** and GDScript.

This is a non-commercial fan project. It ships **no official artwork or audio**:
fighters are original placeholders drawn in code until real sprites are supplied.

## Status

- Phase 1 — foundation (done): movement, jumps, drop-through platforms, stage, camera.
- Phase 2 — combat core (done): attacks, damage percent, knockback, hitlag, blast-zone
  KOs, stocks, respawn, timer, sudden death, HUD, 2-player versus.
- Phase 3 — specials (done): Reiatsu meter, 4 specials per character, Bankai, cinematic
  ultimates, projectiles, 3 characters, CPU opponent.
- Phase 4a — menus (done): title, main menu, character select, settings screen.
- Phase 4b — `feature/arcade-and-boss` (this branch): Arcade mode (4 fights, story text,
  continues, ending) and the boss Yhwach.
- Next: music and sound, balance and polish.

## Run it

1. Open the folder in Godot 4.7 (`project.godot`).
2. Press F5. Title screen, then the main menu: Arcade, Versus 2 Players, Versus CPU, Settings.
3. Pick fighters (Left/Right, Attack to confirm, Guard to go back).
4. In a match, **Esc** returns to the menu; when it ends, **Enter** plays again.

Menus use the game keys of either player (Attack confirms, Guard goes back) or
Arrows/Enter/Esc.

## Controls

| Action | Player 1 | Player 2 |
|---|---|---|
| Move | `A` `D` | `←` `→` |
| Jump / air jump | `W` | `↑` |
| Drop through platform / fast-fall | `S` | `↓` |
| Attack | `J` | `Numpad 1` |
| Special | `K` | `Numpad 2` |
| Guard / Shunpo | `L` | `Numpad 3` |
| Charge Reiatsu / Bankai / Ultimate | `I` | `Numpad 5` |

**Attack** and **Special** change with the direction you hold (none, forward, up, down),
on the ground and in the air. The up special is each character's recovery.
Guard / Shunpo is wired to input but does nothing yet.

**Reiatsu** (the bar under the stocks, 0 to 300, notch at 200): hit and get hit to fill
it, or stand still and hold the charge key. Press the charge key on the ground:
- at 300: a cinematic **ultimate** (everyone else freezes, the camera zooms in);
- at 200 or more: **Bankai** (20 seconds: 25% more damage, 15% faster, a stronger
  special set; costs 200);
- otherwise it starts charging (hold it). Charging leaves you open to hits.

**Characters:** Ichigo (balanced swordsman, wave and dash), Uryu (light archer, arrows and a
sky step), Byakuya (fast, teleports, petal traps). In Versus CPU, player 1 picks their
fighter, then the opponent and the CPU level (Up/Down, 1 to 3).

**Arcade:** pick a fighter, then win four CPU fights of rising difficulty: the two other
fighters, a rival with your own fighter, and the boss Yhwach (CPU level 4). Each fight
starts with a short story screen. If you lose you can continue the same fight (the
ending shows how many continues you used). Esc quits the run. Match rules (stocks,
time) come from the Settings screen.

`F1` hides the debug overlay, `F2` shows hitboxes.

## Rules (Smash-style)

Damage is a percentage; the higher it is, the farther a hit launches you. Leave
the blast zone around the stage and you lose a stock, then respawn above the
stage with a short invincibility. Lose your last stock and you lose the match.
If time runs out: most stocks wins, then the lowest percent; a full tie goes to
sudden death (one stock each, 300%).

Settings screen: stocks 1–10 (default 3), time limit 1–20 minutes or unlimited
(default 5), music and SFX volume (used once audio is added), and a list of the keys.
Values are saved to `user://settings.cfg`.

## Tuning the feel

Everything is data, no code changes needed:

- `resources/movesets/*_moveset.tres`: damage, knockback, angle, frame timing and
  hitbox shape of the 8 normal attacks of each character.
- `resources/specials/*.tres`: the 4 specials, the Bankai set and the ultimate
  (projectiles, dashes, teleports, damage).
- `resources/characters/*.tres`: speed, jump, gravity, weight, look.
- `scripts/combat/knockback.gd` and `scripts/combat/reiatsu.gd`: launch, hitstun,
  hitlag and Reiatsu/Bankai tuning.
- `scripts/ai/ai_input.gd`: CPU levels (reaction time, aggression, mistakes).

## Project layout

```
scripts/autoload/   Events (signal bus), InputBindings, GameSettings, MatchConfig,
                    ScreenRouter, ArcadeRun (Arcade state and story text)
scripts/fighter/    Fighter, state machine, states, input sources
scripts/ai/         CPU opponent (AIInput)
scripts/combat/     Hitbox, Hurtbox, Projectile, HitInfo, Knockback, Reiatsu
scripts/match/      MatchManager (rules) and the versus match scene script
scripts/menu/       Menu screens (title, main menu, character select, settings, Arcade)
scripts/ui/         Match HUD
scripts/stage/      Stage rules and backdrop
scripts/camera/     Dynamic two-fighter camera
scripts/data/       CharacterData, MoveSet/MoveData, SpecialSet/SpecialData, ProjectileData
scenes/ resources/  Fighter, stage and match scenes; character and move data
tests/              Headless test suite
tools/              Dev tools (screenshot capture)
```

Design rule: *call down, signal up*. Nodes talk through signals (the `Events`
bus); physics lives in `_physics_process`, UI and audio only listen.

## Tests

```
godot --headless --path . --import                 # once, on a fresh checkout
godot --headless --path . -s tests/run_tests.gd
```

## Screenshots (needs a display, e.g. `xvfb-run` on a server)

```
godot --path . --rendering-driver opengl3 -s tools/capture_screenshot.gd -- \
    out.png [idle|hit|ko|end|special|bankai|ultimate|title|menu|select|select_cpu|settings|controls]
    [p1_character] [p2_character]
```
