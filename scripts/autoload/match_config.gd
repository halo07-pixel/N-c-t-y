extends Node
## Who is playing whom: the two chosen characters and the CPU level for player 2.
## Filled in by the character-select screen and read by the match.

const ROSTER_PATHS: PackedStringArray = [
	"res://resources/characters/swordsman.tres",
	"res://resources/characters/archer.tres",
	"res://resources/characters/noble.tres",
]
const CPU_OFF := 0
const CPU_MAX_LEVEL := 3

var p1_index: int = 0
var p2_index: int = 1
## 0 = player 2 is human, 1 to 3 = CPU difficulty.
var cpu_level: int = CPU_OFF
## True during an Arcade run (see ArcadeRun).
var arcade: bool = false
## Replaces player 2's roster pick, e.g. the Arcade boss, who is not in the roster.
var opponent_override: CharacterData


func roster_size() -> int:
	return ROSTER_PATHS.size()


func character_for(player_id: int) -> CharacterData:
	if player_id == 2 and opponent_override != null:
		return opponent_override
	var index := p1_index if player_id == 1 else p2_index
	return load(ROSTER_PATHS[index]) as CharacterData


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
		p2_label += " (CPU %d)" % cpu_level
	return "P1 %s   P2 %s" % [character_for(1).display_name, p2_label]
