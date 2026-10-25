extends Node
## Global signal bus.
## Nodes announce what happened here; UI, audio and managers listen.
## Nothing in this file calls into other nodes ("call down, signal up").

@warning_ignore("unused_signal")
signal fighter_state_changed(player_id: int, state_name: StringName)
@warning_ignore("unused_signal")
signal fighter_jumped(player_id: int, is_air_jump: bool)
@warning_ignore("unused_signal")
signal fighter_landed(player_id: int)
@warning_ignore("unused_signal")
signal fighter_dropped_through(player_id: int)
@warning_ignore("unused_signal")
signal fighter_left_blast_zone(player_id: int)
@warning_ignore("unused_signal")
signal settings_changed
