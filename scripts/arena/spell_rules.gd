extends RefCounted

## Transforma a pilha mágica (o que executou, na ordem) num feitiço.
## Linha do tempo: os efeitos acontecem na ordem da pilha.
##  - FOGO / GELO / RAIO: escolhem o elemento das explosões DEPOIS deles e
##    somam sua intensidade ao poder daquele elemento.
##      fogo: + poder no dano.
##      gelo: + metade do poder no dano e congela por 1 s + poder/60.
##      raio: + metade do poder no dano, raio maior e atordoa por 0,6 s.
##  - PROJÉTIL: a orbe rola até o inimigo mais próximo; intensidade = distância.
##  - EXPLOSÃO: explode onde a orbe está; intensidade = raio e dano base.
## Raridade (entrada "rarity" da pilha) multiplica a intensidade de Explosão,
## Fogo, Gelo e Raio: Rara x1,5, Épica x2, Lendária x3.
## Custo: cada execução de runa mágica gasta metade da intensidade com que
## executou (mínimo 1), antes da raridade. Laços (Portal frágil, Duplicar,
## Saltar se 1) transformam poucas runas em várias explosões, e a mana é o limite.

const COLOR_ARCANE := Color("b08cff")
const COLOR_FIRE := Color("e8452c")
const COLOR_ICE := Color("8fe6ff")
const COLOR_LIGHTNING := Color("ffd23a")
const ELEMENT_COLORS := {"": COLOR_ARCANE, "fire": COLOR_FIRE, "ice": COLOR_ICE, "lightning": COLOR_LIGHTNING}
const ELEMENT_RUNES := {"FIRE": "fire", "ICE": "ice", "LIGHTNING": "lightning"}
const MOVE_PER_INTENSITY := 2.5
const MOVE_BASE := 24.0
const RADIUS_PER_INTENSITY := 1.0
const RADIUS_BASE := 24.0
const COST_RATE := 0.5
## Teto de efeitos de um feitiço (laços muito longos ficam ilegíveis e lentos).
const MAX_EFFECTS := 64
const STUN_SECONDS := 0.6
const Rarity = preload("res://scripts/arena/rarity.gd")


static func build(magic: Array) -> Dictionary:
	var effects: Array = []
	var element := ""
	var power := {"fire": 0, "ice": 0, "lightning": 0}
	var first_explosion_element = null
	for entry in magic:
		var kind := str(entry.get("kind", ""))
		var intensity := int(entry.get("intensity", 0))
		if Rarity.has_rarity(kind):
			intensity = roundi(intensity * Rarity.multiplier(int(entry.get("rarity", 0))))
		if ELEMENT_RUNES.has(kind):
			element = ELEMENT_RUNES[kind]
			power[element] += intensity
			continue
		match kind:
			"PROJECTILE":
				effects.append({"type": "move", "distance": MOVE_BASE + intensity * MOVE_PER_INTENSITY})
			"EXPLOSION":
				var explosion := {
					"type": "explode", "element": element,
					"radius": RADIUS_BASE + intensity * RADIUS_PER_INTENSITY,
					"damage": intensity, "freeze": 0.0, "stun": 0.0,
					"color": ELEMENT_COLORS[element],
				}
				match element:
					"fire":
						explosion["damage"] = intensity + int(power["fire"])
					"ice":
						explosion["damage"] = intensity + int(power["ice"]) / 2
						explosion["freeze"] = 1.0 + float(power["ice"]) / 60.0
					"lightning":
						explosion["damage"] = intensity + int(power["lightning"]) / 2
						explosion["radius"] = float(explosion["radius"]) * (1.0 + float(power["lightning"]) / 200.0)
						explosion["stun"] = STUN_SECONDS
				effects.append(explosion)
				if first_explosion_element == null:
					first_explosion_element = element
	var orb_element: String = first_explosion_element if first_explosion_element != null else element
	return {"effects": effects, "color": ELEMENT_COLORS[orb_element], "magic": magic.duplicate(true), "cost": cost(magic)}


## Mana gasta pelo feitiço: metade da intensidade de cada execução mágica.
static func cost(magic: Array) -> int:
	var total := 0
	for entry in magic:
		total += maxi(1, int(ceil(int(entry.get("intensity", 0)) * COST_RATE)))
	return total


static func count_effects(spell: Dictionary, effect_type: String) -> int:
	var total := 0
	for effect in spell.get("effects", []):
		if str(effect["type"]) == effect_type:
			total += 1
	return total


## "3 explosões, 3 projéteis" para a prévia da criação.
static func summary(spell: Dictionary) -> String:
	var explosions := count_effects(spell, "explode")
	var moves := count_effects(spell, "move")
	var parts := PackedStringArray()
	if explosions > 0:
		parts.append("%d %s" % [explosions, "explosão" if explosions == 1 else "explosões"])
	if moves > 0:
		parts.append("%d %s" % [moves, "projétil" if moves == 1 else "projéteis"])
	return ", ".join(parts) if not parts.is_empty() else "nenhum efeito"
