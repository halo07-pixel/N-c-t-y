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
