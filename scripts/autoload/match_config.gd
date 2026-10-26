extends Node
## Who is playing whom: the two chosen characters and the CPU level for player 2.
## A temporary stand-in for the character-select menu that comes in phase 4.

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


func roster_size() -> int:
	return ROSTER_PATHS.size()


func character_for(player_id: int) -> CharacterData:
	var index := p1_index if player_id == 1 else p2_index
	return load(ROSTER_PATHS[index]) as CharacterData


func cycle_character(player_id: int) -> void:
	if player_id == 1:
		p1_index = (p1_index + 1) % roster_size()
	else:
		p2_index = (p2_index + 1) % roster_size()


func cycle_cpu() -> void:
	cpu_level = (cpu_level + 1) % (CPU_MAX_LEVEL + 1)


func describe() -> String:
	var p2_label := character_for(2).display_name
	if cpu_level > CPU_OFF:
		p2_label += " (CPU %d)" % cpu_level
	return "P1 %s   P2 %s" % [character_for(1).display_name, p2_label]
