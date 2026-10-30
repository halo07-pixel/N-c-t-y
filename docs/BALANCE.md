# Balance report

Measured with `tools/balance_sim.gd`: CPU level 3 against CPU level 3, 2 stocks, 90 s limit, every
ordered pairing played several times with fixed seeds (the same fighters, states, hits, guard and
gauge as the real game; only the match rules are simplified). The CPU is not a human, so these
numbers are a reference, not a verdict.

Run it with:

    godot --headless --fixed-fps 60 --path . -s tools/balance_sim.gd -- report.json matches=8

## Win rate per character (all pairings combined)

| Character | Before | After | Avg. time to a full Combat Gauge |
|---|---|---|---|
| Ichigo | 58% | 42% | 29 s |
| Uryu | 31% | 50% | 29 s |
| Byakuya | 33% | 48% | 30 s |
| Yhwach | 78% | 60% | 26 s |

"Before" is 6 matches per ordered pairing, "after" is 8 (48 games per character, roughly +-7%).

## Pairings after the pass (wins of the first named character, then the second)

| Pairing | Result |
|---|---|
| Uryu vs Yhwach | 4 - 4 |
| Uryu vs Byakuya | 5 - 3 |
| Uryu vs Ichigo | 2 - 6 |
| Yhwach vs Uryu | 5 - 3 |
| Yhwach vs Byakuya | 4 - 4 |
| Yhwach vs Ichigo | 5 - 3 |
| Byakuya vs Uryu | 4 - 4 |
| Byakuya vs Yhwach | 2 - 6 |
| Byakuya vs Ichigo | 5 - 3 |
| Ichigo vs Uryu | 2 - 6 |
| Ichigo vs Yhwach | 3 - 5 |
| Ichigo vs Byakuya | 3 - 5 |

## What changed

- Yhwach: melee x0.88, specials x0.85, ultimate x0.92, weight 118 to 100, starting gauge 50 to 10,
  Void Sphere 40 to 32 wide.
- Uryu: melee x1.08, specials x1.12, weight 90 to 95.
- Byakuya: melee x1.17, specials x1.12, weight 85 to 95.
- Ichigo is unchanged.


## After the skill rework (8 matches per pair, CPU level 3)

Ichigo 31%, Uryu 40%, Byakuya 56%, Yhwach 73% (before the last tuning: 38 / 29 / 56 / 77).
Tuned: Uryu's arrows hit a little harder, Yhwach's counter strike was weakened and the CPU
counters less often. Yhwach is still the strongest; the next knobs are his weight and the
form's damage multiplier. 8 matches per pair is noisy, so read these as a rough guide.

## After the cooldown rework (8 matches per pair, CPU level 3)

Ichigo 50%, Uryu 42%, Byakuya 54%, Yhwach 54% (before: 31 / 40 / 56 / 73). Per-skill cooldowns
slowed the strongest repeatable pressure, which mostly lowered Yhwach. Uryu is still the lowest;
his Spirit Arrow (24 frames) and Triple Shot cooldowns are the first knobs. Noisy, so a rough guide.
