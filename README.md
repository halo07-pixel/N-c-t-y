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
- Phase 4b — Arcade (done): 4 fights, story text, continues, ending, the boss Yhwach.
- Phase 5a — `feature/sprite-art` (this branch): real sprites for the four fighters,
  effect art for projectiles, screen drawn at 720x405.
- Phase 5b — `feature/visual-polish-1` (this branch): ground shadows, hit flash, screen shake, KO burst and
  slow-mo on the final KO (all behind the Settings switch "Screen effects"), vignette,
  additive Reiatsu/Bankai glow, ultimate cut-in band.
- Phase 5c — rigs: every fighter is a RigBody, a jointed box skeleton drawn in code with one shared
  pose library (`scripts/rig/`, data in `resources/rigs/*.tres`). Smooth pose blending, planted feet,
  hair and cape lag, squash and stretch, a slash trail, and hitboxes aligned to the weapon reach.
  The sprite bodies stay as a fallback for a character without a rig.
- Next: original art for Ichigo and Uryu, music and sound, balance and polish.

## Run it

1. Open the folder in Godot 4.7 (`project.godot`).
2. Press F5. Title screen, then the main menu: Arcade, Versus 2 Players, Versus CPU, Combo Trial, Settings.
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
| Skill | `K` | `Numpad 2` |
| Guard / Parry / Throw | `L` | `Numpad 3` |
| Dash | double-tap `A` / `D` | double-tap `←` / `→` |
| Charge Reiatsu / Bankai / Ultimate | `I` | `Numpad 5` |

**Attack** and **Skill** change with the direction you hold (none, forward, up, down),
on the ground and in the air. The up skill is each character's recovery.

**Combo chain:** tap Attack again after a ground neutral attack (jab) connects to continue it:
a second hit, then a heavier finisher. Hold Up or Down with the second press for a launcher or a sweep
instead. A press during the active frames is buffered. Chains need a connected hit; data lives in
`MoveData.next_in_chain / chain_up / chain_down`.

**Throw:** hold Guard and press Attack next to an opponent to grab them. A throw goes through a
normal guard (14+ frames of startup, so it is easy to see coming); neither a guard nor a parry stops it.
2 second cooldown. Each fighter has their own throw (`MoveSet.throw_move`, `MoveData.is_throw`).

**Skills** (`K` / `Numpad 2`): four per fighter, picked by the direction held: none = zone, forward = rush,
up = recover (up, launch, back to the stage), down = defend (counter, trap, wall). The HUD shows one row of four
pips. Dashes, lunges and teleports hurt everything along their path (`Hitbox.cover_path`), not only at the end.

**Cancels:** after a normal attack hits (or is blocked), press the skill key within 12 frames to cancel its
recovery into a zone or rush skill (not defend or recover; a whiffed attack cannot cancel). A press made during
the hitlag is remembered. **Gauge Cancel:** press `I` while one of your attacks is hitting to pay 40 Combat
Gauge and be free at once. Numbers in `CombatGauge` (`CANCEL_WINDOW_FRAMES`, `CANCEL_ROLES`, `GAUGE_CANCEL_COST`).

**Skill strip and move list:** beside each player panel, one row of four cells shows the skills (K / N2). The symbol is the direction to hold (dot = none, triangles = forward, up, down). A
ready skill is lit; a cooling one is dark with the seconds left; a red frame means the skill needs Reiatsu you
lack. **F3** opens the full move list of both fighters (buttons, combos, throw, skills with cooldowns, form, ultimate).

**Canon:** the skills and effects follow the series as closely as we can draw them ourselves (see `docs/CANON.md`).
Ichigo is done: Getsuga Tenshō (pale blue; black with a red rim in Bankai), Shunpo Strike, Rising Cut, Ground Slam,
Final Getsuga Tenshō. A projectile with a `rim` color is drawn dark and solid with a glowing edge; the `beam` style draws a Cero.

**Signature mechanics** (`CharacterData.mechanic`):
- Ichigo, Hollow points: three hits in a row charge the next special (+25% damage).
- Uryu, Heartless: the third arrow hit in a row pops the target up with extra knockback.
- Byakuya, petal zone: near his own petals they fade at half speed and he runs 25% faster.
- Yhwach, The Almighty: a successful counter steals one Reiatsu block from the attacker.

**Reiatsu** (the bar under the stocks, 0 to 300, notch at 200): hit and get hit to fill
it, or stand still and hold the charge key. Press the charge key on the ground:
- at 300: a cinematic **ultimate** (everyone else freezes, the camera zooms in);
- at 200 or more: **Bankai** (20 seconds: 25% more damage, 15% faster, a stronger
  special set; costs 200);
- otherwise it starts charging (hold it). Charging leaves you open to hits.

**Characters:** Ichigo (balanced swordsman, wave and dash), Uryu (light archer, arrows and a
sky step), Byakuya (fast, teleports, petal traps). In Versus CPU, player 1 picks their
fighter, then the opponent and the CPU level (Up/Down, 1 to 3).

**Combo Trial** (main menu): practice on a dummy that does not fight back. Pick a fighter and one of four exercises:
the jab string, a cancel into a skill, a dash attack into a skill, and a Gauge Cancel that restarts the string.
The HUD on the right lists the steps (the current one is lit); a wrong move, or more than 1.5 seconds between
steps, shows RETRY and resets; finishing shows COMPLETE and ticks the exercise in the menu (saved in
`user://settings.cfg`). `R` retries at once, `Esc` goes back. The dummy takes 35% knockback so combos stay in
reach. Exercises are built from each fighter's own data (`scripts/trial/trial_library.gd`), the steps are tracked
from `Events` only (`TrialTracker`), and `tests/test_trials.gd` plays every exercise with scripted input to prove
it can be done. Yhwach is the Arcade boss and is not selectable, so he has no exercises.

**Arcade:** pick a fighter, then win four CPU fights of rising difficulty: the two other
fighters, a rival with your own fighter, and the boss Yhwach (CPU level 4). Each fight
starts with a short story screen. If you lose you can continue the same fight (the
ending shows how many continues you used). Esc quits the run. Match rules (stocks,
time) come from the Settings screen.

`F1` hides the debug overlay, `F2` shows hitboxes.

## Art

Fighters are drawn from sprite sets (`<id>_atlas.png` + `<id>_frames.json`). A fighter
without its files falls back to the code-drawn placeholder, so the game always runs.

| Fighter | Art folder | Origin |
|---|---|---|
| Byakuya slot ("noble") | `assets/original/noble/` | original design |
| Yhwach slot ("sovereign") | `assets/original/sovereign/` | original design |

All four fighters are stick figures drawn in code by their rigs (`resources/rigs/`); the sprite sets above are only a fallback for characters without a rig.

The world is simulated at 480x270 units and drawn at 720x405 pixels (`RenderScale`), so one
unit is 1.5 screen pixels and a 1:1 sprite fits a 30-unit-tall body. Physics, move data and
stages did not change. The camera still zooms with the fighters' distance, so sprites are
only pixel-perfect at the camera's base zoom.

## Rules (Smash-style)

Damage is a percentage; the higher it is, the farther a hit launches you. Leave
the blast zone around the stage and you lose a stock, then respawn above the
stage with a short invincibility. Lose your last stock and you lose the match.
If time runs out: most stocks wins, then the lowest percent; a full tie goes to
sudden death (one stock each, 300%).

Settings screen: stocks 1–10 (default 3), time limit 1–20 minutes or unlimited
(default 5), music and SFX volume (used once audio is added), the Screen effects switch, and a list of the keys.
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
- `resources/rigs/*.tres`: proportions, colors, hair, weapon and cape of each body; poses live in
  `scripts/rig/rig_poses.gd`. After changing a weapon length or a strike pose run
  `godot --headless --path . -s tools/rig_reach.gd | python3 tools/align_hitboxes.py --write`.
- `scripts/ai/ai_input.gd`: CPU levels (reaction time, aggression, mistakes).

## Project layout

```
scripts/autoload/   Events (signal bus), InputBindings, GameSettings, MatchConfig,
                    ScreenRouter, ArcadeRun (Arcade state and story text)
scripts/fighter/    Fighter, state machine, states, input sources, bodies (SpriteBody, PlaceholderBody)
scripts/ai/         CPU opponent (AIInput)
scripts/combat/     Hitbox, Hurtbox, Projectile, HitInfo, Knockback, Reiatsu
scripts/match/      MatchManager (rules) and the versus match scene script
scripts/menu/       Menu screens (title, main menu, character select, settings, Arcade, trial select)
scripts/trial/      Combo trial data, library, tracker and HUD (scenes/match/trial_match.tscn is the practice scene)
scripts/ui/         Match HUD
scripts/stage/      Stage rules and backdrop
scripts/camera/     Dynamic two-fighter camera, RenderScale
scripts/sprites/    Sprite set loader and the body factory (sprites or placeholder)
scripts/data/       CharacterData, MoveSet/MoveData, SpecialSet/SpecialData, ProjectileData
scenes/ resources/  Fighter, stage and match scenes; character and move data
tests/              Headless test suite
tools/              Dev tools: screenshot capture (also `film` frame runs), rig_sheet.gd (every pose
                    on one sheet), rig_reach.gd + align_hitboxes.py (check/pull hitboxes to weapon reach)
```

Design rule: *call down, signal up*. Nodes talk through signals (the `Events`
bus); physics lives in `_physics_process`, UI and audio only listen.

## Tests

```
godot --headless --path . --import                 # once, on a fresh checkout
godot --headless --path . -s tests/run_tests.gd
```

## Display

- Stretch mode `canvas_items` with a 16:9 play area (`keep`): text and vector art stay sharp at any window size; other aspect ratios get bars.
- **F11** or **Alt+Enter** toggles fullscreen. Settings > WINDOW cycles Window / Fullscreen / Exclusive and is saved in `user://settings.cfg`.
- All text uses `assets/fonts/ui_font.ttf` (DejaVu Sans Condensed Bold, free license in `ui_font_LICENSE.txt`). Replace that file to change the font everywhere.
- The debug overlay is hidden by default: **F1** shows it, **F2** shows hitboxes.

## Screenshots (needs a display, e.g. `xvfb-run` on a server)

```
godot --path . --rendering-driver opengl3 -s tools/capture_screenshot.gd -- \
    out.png [idle|hit|ko|end|special|bankai|ultimate|title|menu|select|select_cpu|settings|controls]
    [p1_character] [p2_character]
```

## Combat effects

Drawn in code (no art files): `scripts/fx/projectile_art.gd` gives projectiles a look through
`ProjectileData.style` (crescent, arrow, petal, orb, blast) with a fading trail; `HitSpark`
(ring, rays, speed lines on heavy hits) and `DustPuff` are spawned by `CombatFx` from the
`Events.hit_impact` / `Events.dust_puff` signals. All of it follows the "screen effects" setting.

## Combat Gauge and transformation

Each fighter has a Combat Gauge (0-100, `scripts/combat/combat_gauge.gd`, all numbers tunable):
it fills from damage dealt (more in a combo), damage taken, KOs and lost stocks, and fades after
about 6 s without combat. At 100 the charge key transforms (camera zoom, opponents frozen, title
from `CharacterData.transform_title`). The form lasts 15 s, +0.5 s per hit (cap 30 s), gives
+25% damage / +15% speed and the Bankai special set, then the gauge restarts from 0. The
ultimate is usable only while transformed and costs all three Reiatsu blocks (see below).
Yhwach starts with half a gauge. The CPU transforms on its own.

## Transformed look

`scripts/rig/form_fx.gd` draws the form by code while a fighter is transformed (set per rig with
`form_style` / `form_color`): Ichigo a hollow mask, long hair and a red aura; Uryu light wings
and a halo; Byakuya orbiting blades; Yhwach large dark wings with a halo.

## Guard, parry and dash

Hold guard (P1 `L`, P2 `Numpad 3`) on the ground: hits do 20% damage and 40% knockback while the
guard energy drains (empty = guard break, a long stun). The first 10 frames of a guard are a **parry**:
a hit that lands then does nothing to you (no damage, no knockback, no guard energy), freezes the
attacker for about 30 frames, gives +15 Combat Gauge, and you can attack at once. A normal projectile
is sent back at whoever fired it (traps and ultimates are not). Throws go through both guard and parry.
Tapping guard and letting go inside the parry window with nothing hit locks the guard for 20 frames.

Dash: double-tap a direction, on the ground or in the air (once per time in the air). About 64 units in
14 frames, no invincibility, cannot turn around, short cooldown. Attack from the 8th frame of a dash is a
dash attack (the forward attack, keeping part of the speed). CPU level 2+ guards and parries, and dashes in.
All numbers are in `scripts/combat/guard_rules.gd`.

## Balance

`tools/balance_sim.gd` plays CPU against CPU headlessly and reports win rates and how fast the
Combat Gauge fills; the latest numbers and the changes they led to are in `docs/BALANCE.md`.

## Reiatsu and the skill framework

Reiatsu is three blocks (`scripts/combat/reiatsu.gd`) that refill by themselves (a block every 8 s,
twice as fast while transformed; dealing, taking and perfect guards add a little). They pay for the
powerful parts of special moves, which are pure data on `SpecialData`:

- **Charge:** hold the special button at the end of the wind-up (`charge_max_frames`); the longer,
  the bigger, faster and stronger the projectile. A full charge pierces and costs `charge_cost`;
  without the Reiatsu a charge stops at 60%.
- **Follow-up:** press special again after the active frames begin to play `follow_up` for
  `follow_up_cost` (`flip_facing` turns the fighter around for a slash back).

Ichigo is the first character with the new kit: a chargeable Getsuga, Dash Slash + Return Slash,
Rising Cut + Dive Slash and a Ground Slam shockwave. In the form the costs are zero and the Getsuga
fires two waves.

Uryu's kit: a chargeable Heilig Pfeil (a full charge pierces and costs a block), Path Control,
Reishi Platform + Sky Shot (press special again for an arrow diagonally downward, half a block) and
Reishi Mine, a stationary trap (`ProjectileData.trap`) that explodes on the first enemy. He keeps at
most two live traps (`limit_active`): a second one costs half a block (`repeat_cost`), otherwise
the oldest is replaced. In the wing form the arrow is a fan of three and charge, Sky Shot and
extra traps are free. The CPU lays traps at mid range.

Byakuya's kit: Senbonzakura (a slow cloud of petals; press special again to command it at the
enemy, half a block), Flash Step + Behind Slash (teleports past the enemy and slashes back),
Sky Flash + Blade Drop and Petal Wall (a standing column that destroys enemy projectiles, one at a
time; `ProjectileData.absorbs`). In the form there are more petals and every follow-up and the wall
are free.

Yhwach's kit: a Reishi Absorption that swallows enemy projectiles (chargeable), Hirenkyaku Rush + Blut Strike,
Hirenkyaku Ascent + Zenith Fall and Foresight (down special, one block): a hit that lands during
its active frames is negated and answered with The Almighty, facing the attacker
(`SpecialData.counter_move`, `cost`). Without a block the down special is a normal attack.
In the form everything is free and the stance lasts longer.

## Recovery rules

An up special (Reishi Platform, Sky Flash, Rising Cut, Hirenkyaku Ascent) can be used on the ground or once per
time in the air; landing or being hit gives it back (`Fighter.air_up_special_used`). A teleport
upward cancels the fall. The CPU recovers around the edge of the main platform instead of steering
under its middle, so nobody can hover under the stage forever.

## Effects foundation

- **Effects level** (Settings): OFF, LOW, NORMAL, HIGH (`GameSettings.effects_level`). It scales
  spark size and the `FxBudget` cap (0 / 10 / 24 / 40 live sparks, dust and streaks).
- **FxProfile** (`resources/fx/*_fx.tres`, `CharacterData.fx_profile`): palette, impact style
  (slash / shards / petals / ink) and spark scale per character. Hit sparks already use it; later
  stages (trails, auras, transform presentation) read the same profile.

## Combat effects (stage 2)

- **Hit bursts** follow the attacker's `FxProfile.impact_style`: slash (crossing cuts), shards,
  petals, or ink (the dark pulls in, then bursts). Light, solid and heavy hits (`HitSpark.tier_for`)
  add more layers.
- **Weapon trail** has a soft edge and a bright core, scales with the effects level, and now also
  follows specials with a blade (not bows).
- **Projectiles** flash when they appear and when they fade out (`Events.projectile_flash`).
- **KO burst** uses the victim's colours with a second accent ring; the final-KO slow motion is
  stronger and longer on higher effect levels.

## Aura (stage 3)

Every fighter carries an `AuraFx` (`scripts/fx/aura_fx.gd`): an unevenly pulsing glow, particles
orbiting the body and ripples on the ground. Its pressure (`AuraFx.intensity_for`) is 15% Combat
Gauge, 30% Reiatsu blocks, 45% form active and 15% charge, so a transformed fighter at full
Reiatsu is clearly the most dangerous one. It uses the character's `FxProfile` colours, scales
with the effects level and stays hidden below a calm threshold.

## Transformation and ultimate presentation (stage 4)

`PresentationFx` (`scripts/fx/presentation_fx.gd`, a layer above the world and below the HUD)
listens for `transform_started` and `ultimate_started`: the world dims, a motif grows around the
fighter, holds, and releases in a flash (`PresentationFx.sequence`). The motif is the character's
`FxProfile.motif`: Ichigo black cuts with red edges, Uryu a Quincy glyph, Byakuya a ring of
petals, Yhwach the dark closing in from the sides with a shadow spreading along the ground.

## Effects polish (stage 5)

`docs/EFFECTS.md` lists the layering and budget rules and a measurement made with
`tools/fx_stress.gd` (a CPU-vs-CPU match at each effects level). Tests check that a flood of
hits never exceeds the `FxBudget` cap, that everything cleans itself up, and that the transform
dimming stays below the HUD.

## Cooldowns and air mobility

- Every special slot (neutral, forward, up, down) has `SpecialData.cooldown_frames`; the HUD shows
  four pips under the Reiatsu bar (full = ready). Follow-ups and normal attacks have none. The form
  shortens cooldowns to 60%; an up special used on the ground has 40% of the air cooldown.
- A Reiatsu block refreshes a cooling-down **up** special (a comeback tool). A respawn clears all
  cooldowns, and 
- Air jumps have no limit, only a half-second wait; after the free jumps each one is 20% weaker
  (never below 40%), and landing or being hit resets that. The air dash can be used once per time in the air.
