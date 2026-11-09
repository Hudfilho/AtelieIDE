extends RefCounted

## Raridade das runas mágicas (e do Portal frágil). Na bolsa, cada raridade é
## uma pilha própria: "EXPLOSION" é comum, "EXPLOSION#2" é épica.
## Multiplica a intensidade das mágicas; no Portal frágil, dá mais saltos.

const NAMES := ["Comum", "Rara", "Épica", "Lendária"]
const COLORS := ArenaPixelArt.RARITY_COLORS
const MULTIPLIER := [1.0, 1.5, 2.0, 3.0]
## Runas que têm raridade (Projétil e as de lógica não têm).
const KINDS := ["EXPLOSION", "FIRE", "ICE", "LIGHTNING", "WARP_FRAGILE"]
## Chance de cada raridade numa recompensa: [comum, rara, épica, lendária],
## melhorando um pouco a cada sala.
const BASE_WEIGHTS := [60.0, 27.0, 10.0, 3.0]
const WEIGHT_SHIFT_PER_ROOM := [-5.0, 2.0, 2.0, 1.0]


static func key(kind: String, rarity: int) -> String:
	return kind if rarity <= 0 else "%s#%d" % [kind, rarity]


static func kind_of(rune_key: String) -> String:
	return rune_key.get_slice("#", 0)


static func rarity_of(rune_key: String) -> int:
	return int(rune_key.get_slice("#", 1)) if rune_key.contains("#") else 0


static func has_rarity(kind: String) -> bool:
	return kind in KINDS


static func multiplier(rarity: int) -> float:
	return float(MULTIPLIER[clampi(rarity, 0, MULTIPLIER.size() - 1)])


static func color(rarity: int) -> Color:
	return COLORS[clampi(rarity, 0, COLORS.size() - 1)]


## "Explosão" / "Explosão (Rara)".
static func label(base_name: String, rarity: int) -> String:
	return base_name if rarity <= 0 else "%s (%s)" % [base_name, NAMES[clampi(rarity, 0, NAMES.size() - 1)]]


static func roll(room: int) -> int:
	var weights: Array = []
	var total := 0.0
	for index in range(BASE_WEIGHTS.size()):
		var weight := maxf(float(BASE_WEIGHTS[index]) + float(WEIGHT_SHIFT_PER_ROOM[index]) * float(room - 1), 1.0)
		weights.append(weight)
		total += weight
	var pick := randf() * total
	for index in range(weights.size()):
		pick -= float(weights[index])
		if pick <= 0.0:
			return index
	return 0
