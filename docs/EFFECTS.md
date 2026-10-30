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
