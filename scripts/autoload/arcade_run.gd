extends Node
## The state of one Arcade run: four CPU fights of rising difficulty, the last
## against the boss. Menus and the match ask it what comes next; it never
## changes screens itself, it only names the next one.

const BOSS_PATH := "res://resources/characters/emperor.tres"
const FIGHT_COUNT := 4
## CPU level of each fight. Level 4 is boss-only (the menus stop at 3).
const FIGHT_LEVELS: Array[int] = [1, 2, 3, 4]
const SCREEN_STORY := &"arcade_story"
const SCREEN_CONTINUE := &"arcade_continue"
const SCREEN_CLEAR := &"arcade_clear"

## Original story text. %s is the opponent's name, %p the player's fighter.
const INTRO_LINES: Array[Array] = [
	[
		"A quiet night over the ruined city.",
		"%s steps out of the shadows to test you.",
		"Show that you belong on this battlefield.",
	],
	[
		"The air grows heavy with spiritual pressure.",
		"%s blocks the road and will not step aside.",
		"Every fight pushes you closer to the throne.",
	],
	[
		"A rival waits ahead, wearing your own face.",
		"%s fights with everything you have learned.",
		"To go forward, you must beat yourself.",
	],
	[
		"The sky turns black. The final gate opens.",
		"%s, the king of the Quincy, rises from the throne.",
		"Hold nothing back. This is the last fight.",
	],
]
const ENDING_LINES: Array[String] = [
	"The throne falls silent and the black sky begins to clear.",
	"%p stands alone in the light of a new dawn.",
	"The war is over, but the road ahead is still long.",
]

var active: bool = false
var fight_index: int = 0
var continues_used: int = 0
var player_index: int = 0


func start(chosen_player_index: int) -> void:
	active = true
	fight_index = 0
	continues_used = 0
	player_index = chosen_player_index
	_apply_fight()


## Leaves Arcade and clears everything it set in MatchConfig.
func quit_run() -> void:
	active = false
	MatchConfig.arcade = false
	MatchConfig.opponent_override = null
	MatchConfig.cpu_level = MatchConfig.CPU_OFF


func is_boss_fight() -> bool:
	return fight_index == FIGHT_COUNT - 1


## The opponent's data for a fight: the two other fighters, then a rival with
## the player's own fighter, then the boss.
func opponent_for(fight: int) -> CharacterData:
	if fight >= FIGHT_COUNT - 1:
		return load(BOSS_PATH) as CharacterData
	var others: Array[int] = []
	for index in MatchConfig.roster_size():
		if index != player_index:
			others.append(index)
	var chosen := player_index if fight >= others.size() else others[fight]
	return load(MatchConfig.ROSTER_PATHS[chosen]) as CharacterData


func opponent_name(fight: int = fight_index) -> String:
	return opponent_for(fight).display_name


func player_name() -> String:
	return (load(MatchConfig.ROSTER_PATHS[player_index]) as CharacterData).display_name


func cpu_level_for(fight: int = fight_index) -> int:
	return FIGHT_LEVELS[clampi(fight, 0, FIGHT_COUNT - 1)]


func intro_lines(fight: int = fight_index) -> Array[String]:
	var lines: Array[String] = []
	for line: String in INTRO_LINES[clampi(fight, 0, FIGHT_COUNT - 1)]:
		lines.append(line.replace("%s", opponent_name(fight)).replace("%p", player_name()))
	return lines


func ending_lines() -> Array[String]:
	var lines: Array[String] = []
	for line in ENDING_LINES:
		lines.append(line.replace("%p", player_name()))
	return lines


## Records the result of a fight and names the screen that comes next.
func finish_match(player_won: bool) -> StringName:
	if not player_won:
		continues_used += 1
		return SCREEN_CONTINUE
	fight_index += 1
	if fight_index >= FIGHT_COUNT:
		fight_index = FIGHT_COUNT - 1
		return SCREEN_CLEAR
	_apply_fight()
	return SCREEN_STORY


func _apply_fight() -> void:
	MatchConfig.arcade = true
	MatchConfig.p1_index = player_index
	MatchConfig.opponent_override = opponent_for(fight_index)
	MatchConfig.cpu_level = cpu_level_for(fight_index)
