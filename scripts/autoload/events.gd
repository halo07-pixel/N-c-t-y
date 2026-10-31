extends Node
## Global signal bus.
## Nodes announce what happened here; UI, audio and managers listen.
## Nothing in this file calls into other nodes ("call down, signal up").

# --- Fighters ---------------------------------------------------------------
@warning_ignore("unused_signal")
signal fighter_state_changed(player_id: int, state_name: StringName)
@warning_ignore("unused_signal")
signal fighter_jumped(player_id: int, is_air_jump: bool)
@warning_ignore("unused_signal")
signal fighter_landed(player_id: int)
@warning_ignore("unused_signal")
signal fighter_dropped_through(player_id: int)
@warning_ignore("unused_signal")
signal fighter_percent_changed(player_id: int, percent: float)
@warning_ignore("unused_signal")
signal fighter_hit(attacker_id: int, victim_id: int, damage: float)
@warning_ignore("unused_signal")
signal fighter_left_blast_zone(player_id: int)
## A fighter was sent flying: launch speed in pixels per second and the unit direction.
@warning_ignore("unused_signal")
signal fighter_launched(victim_id: int, speed: float, direction: Vector2)
## A hit connected: where, which way the victim flies, how hard (for sparks and speed lines).
@warning_ignore("unused_signal")
signal hit_impact(position: Vector2, direction: Vector2, damage: float, launch_speed: float, attacker_id: int)
## Dust kicked up by a landing or a jump; strength 0..1.
## A character mechanic fired: &"hollow" (empowered), &"heartless" (bounce), &"steal" (Reiatsu taken).
@warning_ignore("unused_signal")
signal mechanic_triggered(player_id: int, kind: StringName, spot: Vector2)
@warning_ignore("unused_signal")
signal fighter_cooldowns_changed(player_id: int, fractions: PackedFloat32Array)

@warning_ignore("unused_signal")
signal projectile_flash(position: Vector2, direction: Vector2, color: Color, dissolve: bool)

@warning_ignore("unused_signal")
signal dust_puff(position: Vector2, strength: float)
## The Combat Gauge (0..CombatGauge.MAX) of a fighter changed.
@warning_ignore("unused_signal")
signal fighter_gauge_changed(player_id: int, gauge: float)
## A fighter begins its transformation: the title to show and how many frames it lasts.
@warning_ignore("unused_signal")
signal transform_started(player_id: int, title: String, frames: int)
## A fighter lost a stock; attacker_id is who hit it last (0 when nobody did).
@warning_ignore("unused_signal")
signal fighter_defeated(victim_id: int, attacker_id: int)
## A hit was absorbed by a guard (perfect = no damage at all) at `position`.
@warning_ignore("unused_signal")
signal fighter_guarded(victim_id: int, attacker_id: int, perfect: bool, position: Vector2)
## The guard ran out and broke.
@warning_ignore("unused_signal")
signal fighter_guard_broken(player_id: int)
## A hit missed because of a Shunpo (a perfect dodge).
@warning_ignore("unused_signal")
signal fighter_dodged(victim_id: int, attacker_id: int, position: Vector2)
## A Shunpo step started from `position`, direction -1 or 1.
@warning_ignore("unused_signal")
signal fighter_shunpo(player_id: int, position: Vector2, direction: int)
## Where a KO happened (world position where the fighter left the blast zone).
@warning_ignore("unused_signal")
signal fighter_ko(player_id: int, position: Vector2)
@warning_ignore("unused_signal")
signal fighter_respawn_due(player_id: int)
@warning_ignore("unused_signal")
signal fighter_reiatsu_changed(player_id: int, reiatsu: float)
@warning_ignore("unused_signal")
signal fighter_bankai_changed(player_id: int, active: bool)
## An ultimate begins: everyone else freezes for freeze_frames and the camera zooms in.
@warning_ignore("unused_signal")
signal ultimate_started(player_id: int, freeze_frames: int, title: String)

# --- Match ------------------------------------------------------------------
@warning_ignore("unused_signal")
signal match_started
@warning_ignore("unused_signal")
signal stocks_changed(player_id: int, stocks: int)
## Seconds left, or -1 when the match has no time limit.
@warning_ignore("unused_signal")
signal match_time_changed(seconds_left: int)
@warning_ignore("unused_signal")
signal sudden_death_started
## winner_id is 0 when nobody won.
@warning_ignore("unused_signal")
signal match_ended(winner_id: int)

# --- Screens ----------------------------------------------------------------
## A menu or match asks to move to another screen (see ScreenRouter for the names).
@warning_ignore("unused_signal")
signal screen_requested(screen: StringName)

# --- Settings ---------------------------------------------------------------
@warning_ignore("unused_signal")
signal settings_changed
