# Effects: budget, performance and readability

## Rules the effects follow
- Effects only listen to the `Events` bus (or read a fighter); they never change gameplay.
- Short-lived nodes (sparks, dust, streaks, flashes) go through `FxBudget`: 10 / 24 / 40 at LOW /
  NORMAL / HIGH, nothing at OFF. Over the cap an effect is dropped, never queued.
- Layers: world effects < vignette (10) < presentation dim and motifs (11) < KO burst (12) < HUD (50).
  The dimming of a transformation never covers the HUD.
- The aura stays hidden below a calm threshold, and its alpha is low enough to keep the silhouette
  readable (checked in screenshots of every character in form).
- OFF turns off shake, flashes, sparks, auras, motifs and slow motion. LOW halves amounts and
  flash strength, HIGH raises them by half.

## Measured with `tools/fx_stress.gd`
CPU vs CPU, level 3, gauge and Reiatsu full at the start so the heaviest presentation plays,
600 frames per level, software GL (llvmpipe, so only the ratios mean anything and the numbers
are noisy):

| Level | avg ms | worst ms | peak live effects | peak nodes |
|---|---|---|---|---|
| OFF | 20.0 | 88 | 0 | 148 |
| LOW | 27.6 | 254 | 10 | 158 |
| NORMAL | 28.9 | 200 | 11 | 159 |
| HIGH | 23.8 | 103 | 11 | 159 |

Reading: the live effect count stays far below the caps, and the node count is flat (no leaks).
The frame-time differences are inside the noise of software rendering; a real GPU run is still
worth doing on the target PC. If it ever drops frames, lower `FxBudget.CAPS` first.

## Character mechanics (stage 6)

- `MechanicAura` (child of every fighter, reads the fighter): red-black flames while Ichigo's Hollow boost is
  charged, Quincy crosses over Uryu's head for a 2-arrow streak (pulsing ring at the last step before the
  bounce), and a ring of drifting petals plus wind streaks while Byakuya stands in his petal zone.
- `MechanicBurst` (spawned by `CombatFx` from `Events.mechanic_triggered`): a Hollow flare, the Quincy cross that
  bounces up, and a Reiatsu beam from the victim to Yhwach. They count against `FxBudget` and follow the
  effects level (nothing at Off, fewer spikes and beads at Low).
- Screenshots: `tools/capture_screenshot.gd` scenarios `mech_hollow`, `mech_heartless`, `mech_petals`, `mech_steal`.
