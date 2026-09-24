class_name AtelierFlagCondition
extends Resource

## Compara uma flag do GameState com um valor. Flags ausentes valem 0.

enum Comparison { AT_LEAST, BELOW, EQUALS }

@export var flag := ""
@export var comparison := Comparison.AT_LEAST
@export var value := 1


func is_met(flags: Dictionary) -> bool:
	var current := int(flags.get(flag, 0))
	match comparison:
		Comparison.AT_LEAST:
			return current >= value
		Comparison.BELOW:
			return current < value
		_:
			return current == value
