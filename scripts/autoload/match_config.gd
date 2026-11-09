extends Node
## Who is playing whom: the two chosen characters and the CPU level for player 2.
## Filled in by the character-select screen and read by the match.

const ROSTER_PATHS: PackedStringArray = [
	"res://resources/characters/swordsman.tres",
	"res://resources/characters/archer.tres",
	"res://resources/characters/noble.tres",
	"res://resources/characters/lieutenant.tres",
	"res://resources/characters/ice.tres",
	"res://resources/characters/brute.tres",
]
## A pick that stays undecided until the player locks in: the Random slot of the select screen.
const RANDOM_PICK := -1
const CPU_OFF := 0
const CPU_MAX_LEVEL := 3
const LEVEL_NAMES := {1: "KHÁ", 2: "GIỎI", 3: "BẬC THẦY", 4: "BOSS"}


static func cpu_level_name(level: int) -> String:
	return LEVEL_NAMES.get(level, "CPU %d" % level)


var p1_index: int = 0
var p2_index: int = 1
## 0 = player 2 is human, 1 to 3 = CPU difficulty.
var cpu_level: int = CPU_OFF
## True during an Arcade run (see ArcadeRun).
var arcade: bool = false
## Training mode: the select screen leads to the training room, not to a match.
var training: bool = false
## Replaces player 2's roster pick, e.g. the Arcade boss, who is not in the roster.
var opponent_override: CharacterData
## The combo trial being practised: roster index of the character and index of the exercise.
var trial_character: int = 0
var trial_index: int = 0


func roster_size() -> int:
	return ROSTER_PATHS.size()


func character_for(player_id: int) -> CharacterData:
	if player_id == 2 and opponent_override != null:
		return opponent_override
	var index := p1_index if player_id == 1 else p2_index
	if index == RANDOM_PICK: # never leave a match with an undecided pick
		index = lock_in(player_id)
	return load(ROSTER_PATHS[index]) as CharacterData


func is_random(player_id: int) -> bool:
	return (p1_index if player_id == 1 else p2_index) == RANDOM_PICK


## Settles a player's pick: a Random pick becomes a real roster index (chosen with `rng`, or the
## global one). Returns the final index.
func lock_in(player_id: int, rng: RandomNumberGenerator = null) -> int:
	var index := p1_index if player_id == 1 else p2_index
	if index == RANDOM_PICK:
		index = rng.randi_range(0, roster_size() - 1) if rng != null else randi_range(0, roster_size() - 1)
		if player_id == 1:
			p1_index = index
		else:
			p2_index = index
	return index


## The roster's characters in select-screen order.
func roster() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for path in ROSTER_PATHS:
		result.append(load(path) as CharacterData)
	return result


func cycle_character(player_id: int) -> void:
	if player_id == 1:
		p1_index = (p1_index + 1) % roster_size()
	else:
		p2_index = (p2_index + 1) % roster_size()


## Moves a player's pick through the roster (direction -1 or +1), wrapping around.
func step_character(player_id: int, direction: int) -> void:
	if player_id == 1:
		p1_index = posmod(p1_index + direction, roster_size())
	else:
		p2_index = posmod(p2_index + direction, roster_size())


func step_cpu(direction: int) -> void:
	cpu_level = clampi(cpu_level + direction, 1, CPU_MAX_LEVEL)


func cycle_cpu() -> void:
	cpu_level = (cpu_level + 1) % (CPU_MAX_LEVEL + 1)


func describe() -> String:
	var p2_label := character_for(2).display_name
	if cpu_level > CPU_OFF:
		p2_label += " (CPU %s)" % cpu_level_name(cpu_level)
	return "P1 %s   P2 %s" % [character_for(1).display_name, p2_label]
