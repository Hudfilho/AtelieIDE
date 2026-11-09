extends Node2D

## Arena de combate: o loop da run.
##  1. Sala com esqueletos (nascem da terra). A mana enche no começo da sala.
##  2. "+" -> a orbe cresce até cobrir a tela e abre a criação de feitiços.
##     Runas mágicas (Fogo, Gelo, Raio, Projétil, Explosão, Duplicar) são
##     gastas: confirmar as tira da bolsa e as guarda na orbe. Runas de lógica
##     (Número, Somar, Aplicar, Portal...) são ferramentas: liberou, é infinita.
##  3. Arrastar a orbe para o mapa: vira uma bolinha que rola e, depois de 1 s,
##     ativa os efeitos na ordem da pilha mágica.
##     A mana é cobrada por execução (metade da intensidade de cada runa mágica
##     que executa): laços com Portal frágil, Duplicar e Saltar se 1 fazem
##     várias explosões com poucas runas, e a mana decide quantas.
##  4. Sala limpa: volta metade das runas mágicas lançadas, +1 Explosão, e o
##     jogador escolhe 1 de 3 (runa mágica em quantidade, com raridade
##     sorteada, ou runa de lógica nova). A próxima sala é mais difícil.
## Na bolsa, cada raridade é uma pilha própria: "EXPLOSION#2" = Explosão épica.
##  5. Sem orbe na estande, sem bolinha rolando e sem Explosão ou mana: fim.

const Skeleton = preload("res://scripts/arena/skeleton.gd")
const OrbTransition = preload("res://scripts/arena/orb_transition.gd")
const Explosion = preload("res://scripts/arena/explosion.gd")
const SpellBall = preload("res://scripts/arena/spell_ball.gd")
const RewardScreen = preload("res://scripts/arena/reward_screen.gd")
const GameOver = preload("res://scripts/arena/game_over.gd")
const RuneIcons = preload("res://scripts/arena/rune_icons.gd")
const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const SpellCreationScene = preload("res://scenes/arena/SpellCreation.tscn")
const SpellRules = preload("res://scripts/arena/spell_rules.gd")
const Rarity = preload("res://scripts/arena/rarity.gd")
const PX := ArenaPixelArt.PIXEL
const WALK_MARGIN := 56.0
## Faixa inferior reservada ao HUD; os esqueletos não andam por baixo dela.
const HUD_RESERVE := 150.0
## Raio do aro da orbe na tela (7 pixels do sprite).
const ORB_RADIUS := 7.0 * PX
const ORB_SPEED := 420.0
## Folga do acerto: o esqueleto tem uns 12 px de meia-largura na tela.
const HIT_SLACK := 24.0

## Na bolsa, runa de lógica liberada vale UNLIMITED.
const UNLIMITED := -1
const START_INVENTORY := {
	"EXPLOSION": 4, "PROJECTILE": 3, "FIRE": 2, "WARP_FRAGILE": 2, "DUPLICATE": 2,
	"WARP_ENDPOINT": UNLIMITED, "ORB": UNLIMITED, "TWIN": UNLIMITED, "DIAMOND": UNLIMITED,
	"MOON": UNLIMITED, "PLUS": UNLIMITED, "INT_APPLY": UNLIMITED,
}
## Orbe que já começa na estande: o que sai da corrente de exemplo
## Fim de portal -> Projétil -> Explosão -> Portal frágil (3 explosões pulando
## de esqueleto em esqueleto).
const STARTER_SPELL := [
	{"kind": "PROJECTILE", "intensity": 30}, {"kind": "EXPLOSION", "intensity": 20},
	{"kind": "PROJECTILE", "intensity": 30}, {"kind": "EXPLOSION", "intensity": 20},
	{"kind": "PROJECTILE", "intensity": 30}, {"kind": "EXPLOSION", "intensity": 20},
]
## Ferramentas de laço saem mais nas recompensas.
const LOOP_TOOLS := ["WARP_FRAGILE", "DUPLICATE", "JUMP_IF_TRUE", "GT", "LT", "NEQ", "EQ", "CUP", "KNOT"]
## Recompensa que não é runa: mais mana máxima pelo resto da run.
const MANA_OFFER := "MANA"
const MANA_OFFER_AMOUNT := 30
const MANA_ICON := [
	"................",
	".......#........",
	"......###.......",
	"......###.......",
	".....#####......",
	".....#####......",
	"....###.###.....",
	"...###.#####....",
	"...##.######....",
	"...##.######....",
	"...##..#####....",
	"....##..###.....",
	".....######.....",
	"......####......",
	"................",
	"................",
]
const CONSUMABLE_EXTRA := ["DUPLICATE", "WARP_FRAGILE"]
const BASE_MANA := 150
const MANA_PER_ROOM := 15
## Esqueletos nascem em grupinhos deste raio (para valer a área da explosão).
const CLUSTER_RADIUS := 56.0
## Pausa entre efeitos de um feitiço (correntes longas não ficam arrastadas).
const EFFECT_GAP := 0.12
const REFUND_RATE := 0.5
const OFFER_COUNT := 3

@onready var creatures: Node2D = %Creatures
@onready var hud = %Hud

var room := 1
var max_mana := BASE_MANA
var mana := BASE_MANA
## kind -> runas na bolsa (fora das orbes).
var inventory: Dictionary = {}
## kind -> runas lançadas nesta sala (base do reembolso).
var spent_this_room: Dictionary = {}
## Mana máxima ganha nas recompensas.
var bonus_mana := 0

var _effects: Node2D
var _overlay_layer: CanvasLayer
var _creation_layer: CanvasLayer
var _creation
var _transition
var _banner: Label
var _busy := false
var _creating := false
var _origin_slot := 0
var _clearing := false
var _game_over := false
var _active_casts := 0
var _shake_tween: Tween


func _ready() -> void:
	randomize()
	inventory = START_INVENTORY.duplicate()
	creatures.y_sort_enabled = true
	get_viewport().size_changed.connect(_update_bounds)
	_effects = Node2D.new()
	add_child(_effects)

	var banner_layer := CanvasLayer.new()
	banner_layer.layer = 15
	add_child(banner_layer)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 60.0
	_banner.offset_bottom = 92.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_override("font", ArenaPixelArt.FONT)
	_banner.add_theme_font_size_override("font_size", ArenaPixelArt.FONT_SIZE)
	_banner.add_theme_color_override("font_color", ArenaPixelArt.tint(0.9))
	_banner.modulate.a = 0.0
	banner_layer.add_child(_banner)

	_creation_layer = CanvasLayer.new()
	_creation_layer.layer = 20
	add_child(_creation_layer)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 25
	add_child(_overlay_layer)

	var transition_layer := CanvasLayer.new()
	transition_layer.layer = 30
	add_child(transition_layer)
	_transition = OrbTransition.new()
	transition_layer.add_child(_transition)

	hud.plus_pressed.connect(func(orb_center: Vector2) -> void: open_creation(0, orb_center))
	hud.cast_requested.connect(_cast)
	_start_room()
	var starter := SpellRules.build(STARTER_SPELL)
	starter["runes"] = {}
	hud.set_spell(1, starter)


## ======================== SALAS ========================

func _start_room() -> void:
	mana = max_mana
	spent_this_room.clear()
	_spawn_wave()
	_refresh_status()
	_show_banner("SALA %d" % room)


## Esqueletos em grupinhos de 2 a 3, cada grupo num canto da sala.
func _spawn_wave() -> void:
	var bounds := _walk_bounds()
	var inner := bounds.grow(-CLUSTER_RADIUS)
	var remaining := skeleton_count(room)
	while remaining > 0:
		var group := mini(remaining, randi_range(2, 3))
		remaining -= group
		var center := Vector2(randf_range(inner.position.x, inner.end.x), randf_range(inner.position.y, inner.end.y))
		for _index in range(group):
			var skeleton := Skeleton.new()
			skeleton.bounds = bounds
			skeleton.max_hp = skeleton_hp(room)
			var offset := Vector2.from_angle(randf() * TAU) * randf_range(8.0, CLUSTER_RADIUS)
			skeleton.position = (center + offset).clamp(bounds.position, bounds.end)
			creatures.add_child(skeleton)


static func skeleton_count(room_number: int) -> int:
	return mini(3 + 2 * room_number, 18)


static func skeleton_hp(room_number: int) -> int:
	return 20 + 8 * (room_number - 1)


## Runas que são gastas (mágicas, Duplicar e Portal frágil); as outras são
## ferramentas. Aceita chave com raridade ("EXPLOSION#1").
static func is_consumable(rune_key: String) -> bool:
	var kind := Rarity.kind_of(rune_key)
	return RuneCatalog.is_magic(RuneCatalog.opcode_for_kind(kind)) or kind in CONSUMABLE_EXTRA


## Quantas runas de um tipo, somando todas as raridades.
func count_kind(kind: String) -> int:
	var total := 0
	for rune_key in inventory:
		if Rarity.kind_of(rune_key) == kind and int(inventory[rune_key]) > 0:
			total += int(inventory[rune_key])
	return total


func _owns_kind(kind: String) -> bool:
	for rune_key in inventory:
		if Rarity.kind_of(rune_key) == kind:
			return true
	return false


func _alive_enemies() -> Array:
	return creatures.get_children().filter(func(node: Node) -> bool: return node.get("alive") == true)


func _check_room_cleared() -> void:
	if _clearing or _game_over or not _alive_enemies().is_empty():
		return
	_clearing = true
	_show_banner("SALA %d LIMPA" % room)
	await get_tree().create_timer(1.4).timeout
	var refund := _grant_room_rewards()
	_show_rewards(refund)


## Reembolso de metade do que foi lançado na sala, mais uma Explosão.
## Devolve a soma para mostrar na tela de recompensa.
func _grant_room_rewards() -> Dictionary:
	var given := {}
	for kind in spent_this_room:
		var back := int(floor(int(spent_this_room[kind]) * REFUND_RATE))
		if back > 0:
			given[kind] = back
	given["EXPLOSION"] = int(given.get("EXPLOSION", 0)) + 1
	for kind in given:
		inventory[kind] = int(inventory.get(kind, 0)) + int(given[kind])
	return given


func _show_rewards(given: Dictionary) -> void:
	var screen := RewardScreen.new()
	screen.title = "SALA %d LIMPA" % room
	var parts := PackedStringArray()
	for kind in given:
		parts.append("%s +%d" % [rune_name(kind), int(given[kind])])
	screen.summary = "Voltou para a bolsa: " + ", ".join(parts)
	screen.offers = roll_offers()
	screen.picked.connect(_on_reward_picked.bind(screen))
	_overlay_layer.add_child(screen)


## 3 ofertas diferentes: runas mágicas em quantidade (Explosão mais vezes) ou
## runas de lógica que o jogador ainda não liberou. As novas saem 3x mais.
func roll_offers() -> Array:
	var pool: Array = []
	for kind in _game_runes():
		var weight := 0
		if is_consumable(kind):
			weight = 3 if kind == "EXPLOSION" or not _owns_kind(kind) else 2
		elif not _owns_kind(kind):
			weight = 3
		if kind in LOOP_TOOLS and weight > 0:
			weight += 2
		for _copy in range(weight):
			pool.append(kind)
	pool.shuffle()
	var offers: Array = []
	var chosen := {}
	# Mais mana máxima: uma das 3 ofertas em mais ou menos 1 de cada 3 salas.
	if randf() < 0.35:
		chosen[MANA_OFFER] = true
		offers.append({
			"kind": MANA_OFFER, "amount": MANA_OFFER_AMOUNT,
			"icon": ArenaPixelArt.texture("mana_icon", MANA_ICON, {"#": Color.WHITE}),
			"name": "Mana", "description": "Mais %d de mana máxima pelo resto da run" % MANA_OFFER_AMOUNT,
			"rarity": 0,
		})
	for kind in pool:
		if chosen.has(kind):
			continue
		chosen[kind] = true
		var amount := UNLIMITED
		var rarity := 0
		if is_consumable(kind):
			amount = 3 if kind == "EXPLOSION" else 2
			if Rarity.has_rarity(kind):
				rarity = Rarity.roll(room)
		var rune_key := Rarity.key(kind, rarity)
		offers.append({
			"kind": rune_key, "amount": amount, "icon": RuneIcons.icon(kind),
			"name": rune_name(rune_key), "description": rune_description(rune_key),
			"rarity": rarity,
		})
		if offers.size() >= OFFER_COUNT:
			break
	return offers


func _on_reward_picked(kind: String, amount: int, screen: Control) -> void:
	if kind == MANA_OFFER:
		bonus_mana += amount
	elif amount == UNLIMITED:
		inventory[kind] = UNLIMITED
	else:
		inventory[kind] = int(inventory.get(kind, 0)) + amount
	screen.queue_free()
	room += 1
	max_mana = BASE_MANA + MANA_PER_ROOM * (room - 1) + bonus_mana
	_clearing = false
	_start_room()


## Sem orbe na estande, nada rolando e sem como fazer outra explosão.
func _check_out_of_magic() -> void:
	if _game_over or _clearing or _creating or _busy or _active_casts > 0:
		return
	if _alive_enemies().is_empty() or hud.has_any_spell():
		return
	if count_kind("EXPLOSION") > 0 and mana > 0:
		return
	_game_over = true
	var screen := GameOver.new()
	screen.room = room
	screen.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	_overlay_layer.add_child(screen)


## Esc volta ao menu (fora do editor, que usa o Esc para fechar).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _creating and not _busy:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/ware/Hub.tscn")


## ======================== CRIAÇÃO ========================

func open_creation(slot_index: int, orb_center: Vector2) -> void:
	if _busy or _creating or _game_over or _clearing:
		return
	_busy = true
	_origin_slot = slot_index
	creatures.process_mode = Node.PROCESS_MODE_DISABLED
	await _transition.cover_from(orb_center, ORB_RADIUS)
	hud.visible = false
	if _creation == null:
		# Instancia só agora, já visível: o editor pega o foco no _ready.
		_creation = SpellCreationScene.instantiate()
		_creation.close_requested.connect(close_creation)
		_creation.spell_confirmed.connect(_on_spell_confirmed)
		_creation_layer.add_child(_creation)
	_creation.mana = mana
	_creation.max_mana = max_mana
	_creation.inventory = inventory
	_creation.has_free_slot = hud.free_spell_slot() >= 0
	_creation.open()
	_creating = true
	await _transition.reveal()
	_busy = false


func close_creation() -> void:
	if _busy or not _creating:
		return
	_busy = true
	await _transition.cover()
	_creation.hide()
	_creating = false
	hud.visible = true
	await _transition.shrink_to(hud.orb_center(_origin_slot), ORB_RADIUS)
	creatures.process_mode = Node.PROCESS_MODE_INHERIT
	_busy = false
	_check_out_of_magic()


func _on_spell_confirmed(spell: Dictionary, cost: int, runes: Dictionary) -> void:
	var slot: int = hud.free_spell_slot()
	if slot < 0:
		return
	mana -= cost
	# Só as mágicas saem da bolsa; as de lógica continuam lá.
	var spent := {}
	for kind in runes:
		if is_consumable(kind) and int(inventory.get(kind, 0)) != UNLIMITED:
			spent[kind] = int(runes[kind])
			inventory[kind] = int(inventory.get(kind, 0)) - int(runes[kind])
	spell["runes"] = spent
	hud.set_spell(slot, spell)
	_refresh_status()
	# O vidro volta para a orbe nova, não para o "+".
	_origin_slot = slot
	close_creation()


## ======================== LANÇAR ========================

func _cast(spell: Dictionary, screen_position: Vector2, throw_velocity := Vector2.ZERO) -> void:
	_active_casts += 1
	var runes: Dictionary = spell.get("runes", {})
	for kind in runes:
		spent_this_room[kind] = int(spent_this_room.get(kind, 0)) + int(runes[kind])
	var orb := SpellBall.new()
	orb.color = spell["color"]
	orb.bounds = _walk_bounds().grow(WALK_MARGIN * 0.5)
	orb.position = screen_position
	# Na mesma camada dos esqueletos: o y-sort decide quem fica na frente.
	creatures.add_child(orb)
	await orb.land(throw_velocity)
	for effect in spell["effects"]:
		match str(effect["type"]):
			"move":
				var target = _nearest_enemy(orb.position)
				if target == null:
					continue
				var to_target: Vector2 = target.position - orb.position
				var distance := minf(float(effect["distance"]), to_target.length())
				if distance < 1.0:
					continue
				var destination: Vector2 = orb.position + to_target.normalized() * distance
				var move := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				move.tween_property(orb, "position", destination, maxf(distance / ORB_SPEED, 0.1))
				await move.finished
			"explode":
				_explode(orb.position, effect)
				await get_tree().create_timer(EFFECT_GAP).timeout
	orb.vanish()
	_active_casts -= 1
	_check_room_cleared()
	_check_out_of_magic()


func _explode(at: Vector2, effect: Dictionary) -> void:
	var radius := float(effect["radius"])
	var blast := Explosion.new()
	blast.radius = radius
	blast.element = str(effect.get("element", ""))
	blast.freeze = float(effect.get("freeze", 0.0))
	blast.position = at
	_effects.add_child(blast)
	shake(clampf(radius / 16.0, 2.0, 8.0))
	var reach := radius + HIT_SLACK
	for creature in _alive_enemies():
		if creature.position.distance_to(at) <= reach:
			creature.take_damage(int(effect["damage"]), at)
			creature.freeze(float(effect.get("freeze", 0.0)))
			creature.stun(float(effect.get("stun", 0.0)))


func _nearest_enemy(from: Vector2):
	var best = null
	var best_distance := INF
	for creature in _alive_enemies():
		var distance := from.distance_to(creature.position)
		if distance < best_distance:
			best_distance = distance
			best = creature
	return best


## Tremor da tela: move o mundo (a HUD fica em CanvasLayers e não treme).
func shake(strength: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for step in range(6):
		var falloff := 1.0 - float(step) / 6.0
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		_shake_tween.tween_property(self, "position", Vector2(snappedf(offset.x, PX), snappedf(offset.y, PX)), 0.035)
	_shake_tween.tween_property(self, "position", Vector2.ZERO, 0.035)


## ======================== TEXTOS ========================

const CreationRules = preload("res://scripts/arena/spell_creation.gd")


func _game_runes() -> Array:
	return CreationRules.GAME_RUNES


func rune_name(rune_key: String) -> String:
	return CreationRules.display_name(rune_key)


func rune_description(rune_key: String) -> String:
	var kind := Rarity.kind_of(rune_key)
	var full := str(CreationRules.RUNE_NAMES.get(kind, kind))
	return full.get_slice(": ", 1) if full.contains(": ") else ""


func _refresh_status() -> void:
	hud.set_status("SALA %d   MANA %d/%d   EXPLOSÕES %d" % [room, mana, max_mana, count_kind("EXPLOSION")])


func _show_banner(text: String) -> void:
	_banner.text = text
	var fade := create_tween()
	fade.tween_property(_banner, "modulate:a", 1.0, 0.2)
	fade.tween_interval(1.2)
	fade.tween_property(_banner, "modulate:a", 0.0, 0.4)


func _walk_bounds() -> Rect2:
	var size := get_viewport_rect().size
	# A origem do esqueleto fica nos pés: o topo precisa de folga para a cabeça.
	return Rect2(WALK_MARGIN, WALK_MARGIN + 60.0, size.x - WALK_MARGIN * 2.0, size.y - WALK_MARGIN * 2.0 - HUD_RESERVE - 30.0)


func _update_bounds() -> void:
	var bounds := _walk_bounds()
	for child in creatures.get_children():
		if "bounds" in child:
			child.bounds = bounds
