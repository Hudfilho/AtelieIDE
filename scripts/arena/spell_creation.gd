extends Control

## Cena temporária de criação de feitiços (modo jogo). O editor de runas fica
## em pixel_hud: só a mesa. Por cima, a HUD pixel art: paleta de runas no topo,
## mana sobrando embaixo à esquerda, intensidade da runa selecionada embaixo à
## direita e Confirmar no centro. A cada mudança no desenho o ritual roda de
## novo (prévia): quantas explosões sairão e quanta mana vão custar.
## Confirmar compila, roda a VM e transforma a
## pilha mágica num feitiço. Runas mágicas são limitadas: cada uma no desenho
## usa uma da bolsa, e confirmar as gasta (as linhas ficam). Runas de lógica
## liberadas (valor negativo na bolsa) são infinitas.

## Modo ware (microjogos): sem mana nem orbes. Paleta, limites, intensidade
## inicial e nomes vêm do microjogo; laço infinito é permitido (o microjogo
## para quando o objetivo é cumprido) e o desenho fica depois de confirmar,
## para tentar de novo.
signal program_confirmed(actions: Array, output: Array)
signal close_requested
## runes: kind -> quantidade gasta (as runas vão para dentro da orbe).
signal spell_confirmed(spell: Dictionary, cost: int, runes: Dictionary)

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")
const RuneIcons = preload("res://scripts/arena/rune_icons.gd")
const SpellRules = preload("res://scripts/arena/spell_rules.gd")
const Rarity = preload("res://scripts/arena/rarity.gd")
const PX := ArenaPixelArt.PIXEL
const MARGIN := 24.0
const PLACED_INTENSITY := 20
const VM_STEP_LIMIT := 2000
## O que _available devolve para runa infinita (a paleta não mostra número).
const UNLIMITED_DISPLAY := 9999

## Todas as runas do jogo, na ordem da paleta (a paleta mostra as que o
## jogador já tem ou já teve).
const GAME_RUNES := [
	"FIRE", "ICE", "LIGHTNING", "PROJECTILE", "EXPLOSION", "DUPLICATE",
	"ORB", "TWIN", "CUP", "KNOT", "DIAMOND", "MOON", "PLUS", "SLASH", "SPIRAL", "DASH",
	"INT_APPLY", "SQUARE", "FORK", "EQ", "NEQ", "LT", "GT", "LTE", "GTE", "NOT", "AND", "OR",
	"WARP_FRAGILE", "WARP_ENDPOINT", "JUMP_IF_TRUE", "CROSS",
]
## "Nome: descrição". Só caracteres que a fonte pixel tem (sem travessão, ";", "=", "<" ou ">").
const RUNE_NAMES := {
	"FIRE": "Fogo: explosões depois dela viram fogo, a intensidade soma dano",
	"ICE": "Gelo: explosões depois dela congelam, a intensidade soma tempo e dano",
	"LIGHTNING": "Raio: explosões depois dela atordoam e crescem, a intensidade soma raio e dano",
	"PROJECTILE": "Projétil: a orbe rola até o inimigo mais próximo, a intensidade é a distância",
	"EXPLOSION": "Explosão: explode onde a orbe está, a intensidade é o raio e o dano",
	"DUPLICATE": "Duplicar: a próxima runa executa duas vezes",
	"ORB": "Número: empilha a intensidade",
	"TWIN": "Copiar: duplica o valor do topo da pilha",
	"CUP": "Descartar: remove o topo da pilha",
	"KNOT": "Trocar: troca os dois valores do topo",
	"DIAMOND": "Somar: soma os dois valores do topo",
	"MOON": "Subtrair: o de baixo menos o topo",
	"PLUS": "Multiplicar: multiplica os dois valores do topo",
	"SLASH": "Dividir: o de baixo dividido pelo topo",
	"SPIRAL": "Resto: resto da divisão do de baixo pelo topo",
	"DASH": "Negativo: inverte o sinal do topo",
	"INT_APPLY": "Aplicar: o topo da pilha vira a intensidade da próxima runa",
	"SQUARE": "Guardar: guarda o topo no endereço da intensidade",
	"FORK": "Carregar: empilha o valor guardado no endereço da intensidade",
	"EQ": "Igual: 1 se os dois do topo são iguais, senão 0",
	"NEQ": "Diferente: 1 se os dois do topo são diferentes, senão 0",
	"LT": "Menor: 1 se o de baixo é menor que o topo",
	"GT": "Maior: 1 se o de baixo é maior que o topo",
	"LTE": "Menor ou igual: 1 se o de baixo não passa do topo",
	"GTE": "Maior ou igual: 1 se o de baixo não fica abaixo do topo",
	"NOT": "Não: troca 0 por 1 e 1 por 0",
	"AND": "E: 1 se os dois do topo são 1",
	"OR": "Ou: 1 se algum dos dois do topo é 1",
	"WARP": "Portal: salta para o fim de portal de mesma intensidade",
	"WARP_FRAGILE": "Portal frágil: salta para o fim de portal de mesma intensidade e quebra depois de 2 saltos (mais com raridade)",
	"WARP_ENDPOINT": "Fim de portal: destino do portal de mesma intensidade",
	"JUMP_IF_TRUE": "Saltar se 1: se o topo é 1, salta para o fim de portal de mesma intensidade",
	"CROSS": "Parar: encerra o ritual aqui",
	"TRIANGLE": "Entregar: entrega o valor do topo da pilha",
	"MOVE_UP": "Cima: anda para cima, a intensidade é o número de casas",
	"MOVE_DOWN": "Baixo: anda para baixo, a intensidade é o número de casas",
	"MOVE_LEFT": "Esquerda: anda para a esquerda, a intensidade é o número de casas",
	"MOVE_RIGHT": "Direita: anda para a direita, a intensidade é o número de casas",
	"JUMP": "Pular: a intensidade é o ângulo, 90 é reto para cima e menos de 90 vai para a direita",
	"PAINT": "Pintar: pinta a casa onde está",
	"BELL": "Sino: toca o sino com o número da intensidade",
	"TURN": "Girar: gira no sentido horário, a intensidade é o ângulo",
	"SHOOT": "Disparar: dispara, a intensidade é a força",
	"AIM": "Mirar: aponta para cima, a intensidade é o ângulo",
}
## Teto de ações de um programa no modo ware (laços infinitos param aqui).
const WARE_MAX_ACTIONS := 300
## Zoom do editor no modo ware: runas maiores, fáceis de ler.
const WARE_ZOOM := 1.5

## Mana atual e máxima (a arena define antes de abrir).
var mana := 200
var max_mana := 200
var has_free_slot := true
var ware_mode := false
var ware_runes: Array = []
## kind -> nome "Nome: descrição" próprio do microjogo (sobrepõe RUNE_NAMES).
var ware_names: Dictionary = {}
## kind -> intensidade com que a runa nasce (ex.: setas nascem com 1).
var ware_default_intensity: Dictionary = {}
## kind -> intensidade máxima permitida (ex.: Número só até 9).
var ware_max_intensity: Dictionary = {}
## Objetivo e tempo, no quadro de baixo à esquerda.
var ware_objective := ""
var ware_status := ""
## Callable(actions: Array, output: Array) -> String para a prévia.
var ware_preview: Callable
## Foto do desafio (o editor cobre o mundo): miniatura no canto, grande ao
## passar o mouse ou segurar TAB.
var ware_map: Texture2D
var _map_open := false
## Pouco tempo: o quadro do tempo fica vermelho.
var _ware_urgent := false
## chave -> runas na bolsa (a arena é dona; inclui as que estão no desenho).
## Chave = kind para comum, "kind#raridade" para as raras (ver rarity.gd).
var inventory: Dictionary = {}

@onready var canvas = %Canvas

var _icons: Dictionary = {}
var _overlay: Control
var _palette: PaletteBar
var _intensity: IntensityPanel
var _confirm: Button
var _back: Button
## Modo ware: LIMPAR volta para a linha vazia.
var _clear: Button
var _ware_starter := 0
var _typed_value := 0
var _typed_index := -1
var _typed_at := 0
var _message := ""
var _hover_name := ""
var _cost := 0
var _selected := -1
var _drag_kind := ""
var _drag_position := Vector2.ZERO
var _intensity_edit_started := false
## chave -> quantas estão no desenho agora.
var _used: Dictionary = {}
## Resultado da última simulação: {ok, spell, cost, error}.
var _preview: Dictionary = {}
var _preview_signature := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icons = RuneIcons.icons_for(GAME_RUNES)
	canvas.placed_rune_intensity = PLACED_INTENSITY
	canvas.extra_rune_textures = _icons
	canvas.rarity_colors = Rarity.COLORS
	# Soltar no quadradinho do ícone também vale (não só em cima do traço).
	canvas.snap_drops_to_slots = true

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_palette = PaletteBar.new()
	_palette.icons = _icons
	_palette.rune_pressed.connect(_begin_rune_drag)
	_palette.hovered_changed.connect(_on_palette_hover)
	add_child(_palette)

	_intensity = IntensityPanel.new()
	_intensity.visible = false
	_intensity.value_changed.connect(_on_intensity_changed)
	add_child(_intensity)

	_confirm = _pixel_button("CONFIRMAR", ArenaPixelArt.FONT, ArenaPixelArt.FONT_SIZE)
	_confirm.pressed.connect(_on_confirm)
	add_child(_confirm)

	_clear = _pixel_button("LIMPAR", ArenaPixelArt.FONT_TINY, ArenaPixelArt.FONT_TINY_SIZE)
	_clear.pressed.connect(_load_starter_line.bind(true))
	_clear.visible = false
	add_child(_clear)

	_back = _pixel_button("VOLTAR", ArenaPixelArt.FONT_TINY, ArenaPixelArt.FONT_TINY_SIZE)
	_back.pressed.connect(func() -> void: close_requested.emit())
	add_child(_back)

	resized.connect(_layout)
	_layout()
	# A camada de desenho por cima de tudo (mapa ampliado cobre a paleta).
	move_child(_overlay, -1)


## Prepara o editor para um microjogo: paleta, limites (kind -> quantidade;
## ausente = infinita) e desenho limpo.
## `starter_cells` > 0 já deixa uma linha reta desse tamanho desenhada (vazia),
## para o jogador só soltar runas: no ritmo do WarioWare não dá tempo de
## desenhar tudo do zero.
func configure_ware(runes: Array, limits: Dictionary, names: Dictionary, default_intensity: Dictionary, max_intensity: Dictionary, objective: String, preview: Callable, starter_cells := 0) -> void:
	ware_mode = true
	ware_runes = runes.duplicate()
	ware_names = names
	ware_default_intensity = default_intensity
	ware_max_intensity = max_intensity
	ware_objective = objective
	ware_preview = preview
	_drag_kind = ""
	_hover_name = ""
	inventory = {}
	for kind in runes:
		inventory[kind] = int(limits.get(kind, -1))
	_icons = RuneIcons.icons_for(runes)
	_palette.icons = _icons
	canvas.extra_rune_textures = _icons
	_ware_starter = starter_cells
	_intensity.show_steps = true
	_load_starter_line()
	_clear.visible = true


## Desenho do começo do modo ware: a linha vazia (ou nada).
func _load_starter_line(undoable := false) -> void:
	var cells: Array = []
	var spacing: float = canvas.GRID_SPACING
	for index in range(_ware_starter):
		cells.append({"from": Vector2(index, 0) * spacing, "to": Vector2(index + 1, 0) * spacing, "symbol": "", "intensity": 0})
	var view := get_viewport_rect().size if is_inside_tree() else Vector2(1280.0, 720.0)
	var zoom := WARE_ZOOM if _ware_starter > 0 else 1.0
	var pan := Vector2(snappedf(view.x * 0.5 - _ware_starter * spacing * zoom * 0.5, spacing * zoom * 0.5), snappedf(view.y * 0.5, spacing * zoom * 0.5))
	if undoable:
		# LIMPAR: Ctrl+Z traz o ritual de volta.
		canvas.replace_connections(cells)
		canvas.pan = pan if _ware_starter > 0 else Vector2.ZERO
		canvas.zoom = zoom
		canvas.queue_redraw()
	else:
		canvas.load_connections(cells, pan if _ware_starter > 0 else Vector2.ZERO, zoom)
	_preview = {}
	_message = ""
	_overlay.queue_redraw()


func set_ware_map(texture: Texture2D) -> void:
	ware_map = texture
	_map_open = false
	_overlay.queue_redraw()


func _ware_map_rect() -> Rect2:
	if ware_map == null:
		return Rect2()
	var aspect := ware_map.get_width() / maxf(ware_map.get_height(), 1.0)
	var width := 300.0
	var height := width / aspect
	if height > 200.0:
		height = 200.0
		width = height * aspect
	return Rect2(MARGIN, MARGIN + 22.0, snappedf(width, 2.0), snappedf(height, 2.0))


## Modo ware: texto do quadro de baixo (tempo que sobra).
func set_ware_status(text: String, urgent := false) -> void:
	if ware_status == text and _ware_urgent == urgent:
		return
	ware_status = text
	_ware_urgent = urgent
	_overlay.queue_redraw()


func open() -> void:
	show()
	# Um arrasto interrompido (tempo acabou com a runa na mão) não volta junto.
	_drag_kind = ""
	_hover_name = ""
	_message = ""
	_palette.kinds = palette_keys(inventory) if not ware_mode else ware_runes.filter(func(kind: String) -> bool: return inventory.has(kind))
	_refresh_counts()
	_layout()
	canvas.grab_focus()


func _layout() -> void:
	var palette_size: Vector2 = _palette.preferred_size()
	_palette.size = palette_size
	_palette.position = Vector2(snappedf((size.x - palette_size.x) * 0.5, PX), MARGIN)
	_back.size = Vector2(116.0, 44.0)
	_back.position = Vector2(size.x - MARGIN - _back.size.x, MARGIN)
	_clear.size = Vector2(116.0, 44.0)
	_clear.position = _back.position + Vector2(0.0, _back.size.y + 12.0)
	_confirm.size = Vector2(240.0, 60.0)
	_confirm.position = Vector2(snappedf((size.x - _confirm.size.x) * 0.5, PX), size.y - MARGIN - _confirm.size.y)
	_intensity.size = IntensityPanel.PANEL_SIZE
	_intensity.position = Vector2(size.x - MARGIN - _intensity.size.x, size.y - MARGIN - _intensity.size.y)
	_overlay.queue_redraw()


func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh_counts()
	if ware_mode:
		# Os números de intensidade acompanham o desenho (arrastar, zoom).
		_overlay.queue_redraw()
		_map_open = ware_map != null and (_ware_map_rect().has_point(get_local_mouse_position()) or Input.is_key_pressed(KEY_TAB))
	var signature := hash(canvas.connections)
	if signature != _preview_signature or _preview.is_empty():
		_preview_signature = signature
		_preview = simulate()
		_overlay.queue_redraw()
	var cost := int(_preview.get("cost", 0))
	var selected: int = canvas.selected_rune()
	if selected >= 0 and not _uses_intensity(str(canvas.connections[selected].get("symbol", ""))):
		selected = -1 # Somar, Copiar, Aplicar...: a intensidade não faz nada
	var changed := cost != _cost or selected != _selected
	_cost = cost
	_selected = selected
	_intensity.visible = _selected >= 0
	if _selected >= 0:
		var kind := str(canvas.connections[_selected].get("symbol", ""))
		var title := display_name(Rarity.key(kind, canvas.rune_rarity(_selected))) if not ware_mode else _name_entry(kind).get_slice(":", 0)
		_intensity.max_value = int(ware_max_intensity.get(kind, 255)) if ware_mode else 255
		_intensity.set_rune(_icons.get(kind), title, canvas.rune_intensity(_selected))
	if ware_mode:
		_confirm.disabled = not bool(_preview.get("ok", false))
		_overlay.queue_redraw() # o tempo corre
	else:
		_confirm.disabled = not has_free_slot or not bool(_preview.get("ok", false)) or _cost > mana
	if changed:
		_overlay.queue_redraw()


## Chaves da bolsa na ordem da paleta: tipo na ordem de GAME_RUNES, raridade crescente.
static func palette_keys(bag: Dictionary) -> Array:
	var keys: Array = []
	for kind in GAME_RUNES:
		for rarity in range(Rarity.NAMES.size()):
			var rune_key := Rarity.key(kind, rarity)
			if bag.has(rune_key):
				keys.append(rune_key)
	return keys


func _name_entry(kind: String) -> String:
	return str(ware_names.get(kind, RUNE_NAMES.get(kind, kind)))


## Nome com raridade: "Explosão (Rara)".
static func display_name(rune_key: String) -> String:
	var kind := Rarity.kind_of(rune_key)
	return Rarity.label(str(RUNE_NAMES.get(kind, kind)).get_slice(":", 0), Rarity.rarity_of(rune_key))


## Quantas runas de cada chave estão no desenho e quantas sobram na bolsa.
func _refresh_counts() -> void:
	var used := {}
	for connection in canvas.connections:
		var kind := str(connection.get("symbol", ""))
		if not kind.is_empty():
			var rune_key := Rarity.key(kind, int(connection.get("rarity", 0)))
			used[rune_key] = int(used.get(rune_key, 0)) + 1
	_used = used
	var counts := {}
	for kind in _palette.kinds:
		counts[kind] = _available(kind)
	_palette.set_counts(counts)


func _available(kind: String) -> int:
	var owned := int(inventory.get(kind, 0))
	if owned < 0:
		return UNLIMITED_DISPLAY
	return owned - int(_used.get(kind, 0))


## Roda o ritual desenhado e devolve {ok, spell, cost, error}. Pelas
## instruções compiladas: cada propriedade mágica sabe sua célula
## (connection_index) e, por ela, a raridade da runa.
func simulate() -> Dictionary:
	if ware_mode:
		return _simulate_ware()
	if _used.is_empty():
		return {"ok": false, "cost": 0, "error": ""}
	var compiled: Dictionary = RuneCompiler.new().compile(canvas.connections)
	if not bool(compiled.get("ok", false)):
		var errors: Array = compiled.get("errors", [])
		return {"ok": false, "cost": 0, "error": str(errors[0]) if not errors.is_empty() else "O ritual não compila."}
	var run: Dictionary = RuneVM.new().run_program(compiled["instructions"], {}, VM_STEP_LIMIT)
	if not bool(run.get("ok", false)):
		var run_errors: Array = run.get("errors", [])
		return {"ok": false, "cost": 0, "error": str(run_errors[0]) if not run_errors.is_empty() else "O ritual falhou."}
	var magic: Array = run.get("magic", [])
	for entry in magic:
		var cell := int(entry.get("connection_index", -1))
		if cell >= 0 and cell < canvas.connections.size():
			entry["rarity"] = int(canvas.connections[cell].get("rarity", 0))
	if magic.is_empty():
		return {"ok": false, "cost": 0, "error": "Nenhuma runa mágica foi executada."}
	var spell := SpellRules.build(magic)
	if spell["effects"].size() > SpellRules.MAX_EFFECTS:
		return {"ok": false, "cost": int(spell["cost"]), "error": "Feitiço grande demais: no máximo %d efeitos." % SpellRules.MAX_EFFECTS}
	return {"ok": true, "spell": spell, "cost": int(spell["cost"]), "error": ""}


## Modo ware: a pilha mágica vira a lista de ações. Laço infinito não é erro:
## as ações param no teto e o microjogo decide quando o objetivo foi cumprido.
func _simulate_ware() -> Dictionary:
	if _used.is_empty():
		return {"ok": false, "cost": 0, "error": ""}
	for kind in _used:
		if not inventory.has(kind):
			return {"ok": false, "cost": 0, "error": "%s não vale neste desafio." % _name_entry(kind).get_slice(":", 0)}
	for connection in canvas.connections:
		var kind := str(connection.get("symbol", ""))
		if ware_max_intensity.has(kind) and int(connection.get("intensity", 0)) > int(ware_max_intensity[kind]):
			return {"ok": false, "cost": 0, "error": "%s só vai até %d." % [_name_entry(kind).get_slice(":", 0), int(ware_max_intensity[kind])]}
	var compiled: Dictionary = RuneCompiler.new().compile(canvas.connections)
	if not bool(compiled.get("ok", false)):
		var errors: Array = compiled.get("errors", [])
		return {"ok": false, "cost": 0, "error": str(errors[0]) if not errors.is_empty() else "O ritual não compila."}
	var run: Dictionary = RuneVM.new().run_program(compiled["instructions"], {}, VM_STEP_LIMIT)
	var timed_out := bool(run.get("timed_out", false))
	if not bool(run.get("ok", false)) and not timed_out:
		var run_errors: Array = run.get("errors", [])
		return {"ok": false, "cost": 0, "error": str(run_errors[0]) if not run_errors.is_empty() else "O ritual falhou."}
	var actions: Array = run.get("magic", [])
	if actions.size() > WARE_MAX_ACTIONS:
		actions = actions.slice(0, WARE_MAX_ACTIONS)
	var output: Array = run.get("output", [])
	if actions.is_empty() and output.is_empty():
		return {"ok": false, "cost": 0, "error": "O ritual não termina e não faz nada." if timed_out else "Nenhuma ação foi executada."}
	var summary := "%d ações" % actions.size()
	if ware_preview.is_valid():
		summary = str(ware_preview.call(actions, output))
	if timed_out:
		summary += " (laço sem fim)"
	return {"ok": true, "actions": actions, "output": output, "summary": summary, "cost": 0, "error": ""}


static func _uses_intensity(kind: String) -> bool:
	if kind.is_empty():
		return false
	var opcode := RuneCatalog.opcode_for_kind(kind)
	return RuneCatalog.takes_operand(opcode) or RuneCatalog.is_magic(opcode)


## ======================== ARRASTAR RUNAS DA PALETA ========================

func _on_palette_hover(rune_key: String) -> void:
	if rune_key.is_empty():
		_hover_name = ""
	else:
		var description := _name_entry(Rarity.kind_of(rune_key)).get_slice(":", 1).strip_edges()
		var rarity := Rarity.rarity_of(rune_key)
		if rarity > 0:
			description += ", intensidade x%s" % str(Rarity.multiplier(rarity)).replace(".", ",") if Rarity.kind_of(rune_key) != "WARP_FRAGILE" else ", %d saltos" % RuneVM.FRAGILE_WARP_USES[rarity]
		_hover_name = "%s: %s" % [display_name(rune_key) if not ware_mode else _name_entry(rune_key).get_slice(":", 0), description]
	_overlay.queue_redraw()


func _begin_rune_drag(kind: String) -> void:
	if _available(kind) <= 0:
		_say("Acabaram as runas de %s." % display_name(kind))
		return
	_drag_kind = kind
	_drag_position = get_global_mouse_position()
	_overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if ware_mode and visible and _selected >= 0 and event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed:
		if _type_intensity_digit(event as InputEventKey):
			get_viewport().set_input_as_handled()
			return
	if _drag_kind.is_empty() or not visible:
		return
	if event is InputEventMouseMotion:
		_drag_position = event.position
		_overlay.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var kind := _drag_kind
		_drag_kind = ""
		if not _palette.get_global_rect().has_point(event.position):
			var local: Vector2 = canvas.get_global_transform_with_canvas().affine_inverse() * event.position
			canvas.placed_rune_intensity = int(ware_default_intensity.get(kind, PLACED_INTENSITY)) if ware_mode else PLACED_INTENSITY
			if not canvas.drop_symbol_at(local, Rarity.kind_of(kind), Rarity.rarity_of(kind)):
				_say("Solte a runa num quadradinho da linha." if ware_mode else "Solte a runa perto de uma linha desenhada.")
		_overlay.queue_redraw()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()


## ======================== INTENSIDADE E CONFIRMAR ========================

## Modo ware: com uma runa selecionada, digitar números muda a intensidade
## (dois dígitos seguidos formam 10 a 99; o terceiro, até 255).
func _type_intensity_digit(event: InputEventKey) -> bool:
	var code := event.keycode
	var digit := -1
	if code >= KEY_0 and code <= KEY_9:
		digit = code - KEY_0
	elif code >= KEY_KP_0 and code <= KEY_KP_9:
		digit = code - KEY_KP_0
	if digit < 0:
		return false
	var now := Time.get_ticks_msec()
	if _typed_index != _selected or now - _typed_at > 900:
		_typed_value = 0
	_typed_index = _selected
	_typed_at = now
	_typed_value = _typed_value * 10 + digit
	if _typed_value > _intensity.max_value:
		_typed_value = mini(digit, _intensity.max_value)
	_intensity.value = _typed_value
	_on_intensity_changed(_typed_value, true)
	_intensity.queue_redraw()
	return true


func _on_intensity_changed(value: int, first_change: bool) -> void:
	if _selected < 0:
		return
	canvas.set_rune_intensity(_selected, value, first_change)
	_overlay.queue_redraw()


func _on_confirm() -> void:
	if ware_mode:
		for kind in _used:
			var limit := int(inventory.get(kind, -1))
			if limit >= 0 and int(_used[kind]) > limit:
				_say("Runas demais: %s." % _name_entry(kind).get_slice(":", 0))
				return
		_preview = simulate()
		if not bool(_preview.get("ok", false)):
			_say(str(_preview.get("error", "")) if not str(_preview.get("error", "")).is_empty() else "Desenhe um ritual com runas de ação.")
			return
		_message = ""
		program_confirmed.emit(_preview["actions"], _preview["output"])
		return
	if not has_free_slot:
		_say("Não há orbe livre na estande.")
		return
	for kind in _used:
		var owned := int(inventory.get(kind, 0))
		if owned >= 0 and int(_used[kind]) > owned:
			_say("Runas insuficientes: %s." % display_name(kind))
			return
	_preview = simulate()
	if not bool(_preview.get("ok", false)):
		_say(str(_preview.get("error", "")) if not str(_preview.get("error", "")).is_empty() else "Desenhe um ritual com runas mágicas.")
		return
	if int(_preview["cost"]) > mana:
		_say("Mana insuficiente: o feitiço custa %d." % int(_preview["cost"]))
		return
	_message = ""
	var spent := _used.duplicate()
	# As runas vão para a orbe: o desenho fica só com as linhas.
	var lines: Array = []
	for connection in canvas.connections:
		var bare: Dictionary = connection.duplicate()
		bare["symbol"] = ""
		bare.erase("rarity")
		lines.append(bare)
	canvas.load_connections(lines, canvas.pan, canvas.zoom)
	spell_confirmed.emit(_preview["spell"], int(_preview["cost"]), spent)


func _say(text: String) -> void:
	_message = text
	_overlay.queue_redraw()


## ======================== DESENHO DA HUD ========================

func _draw_overlay() -> void:
	var font := ArenaPixelArt.FONT_TINY
	# Nome da runa sob o cursor, logo abaixo da paleta.
	if not _hover_name.is_empty():
		var y := _palette.position.y + _palette.size.y + 22.0
		_overlay.draw_string(font, Vector2(0.0, y), _hover_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.85))
	if ware_mode:
		_draw_intensity_labels()
		_draw_ware_box()
	else:
		_draw_mana_bar(font)
	_draw_drop_target()
	# Prévia do feitiço logo acima do Confirmar (um erro tem prioridade).
	var preview_line := ""
	if ware_mode and bool(_preview.get("ok", false)):
		preview_line = str(_preview.get("summary", ""))
	elif bool(_preview.get("ok", false)):
		preview_line = "%s   custo %d" % [SpellRules.summary(_preview["spell"]), int(_preview["cost"])]
	elif not str(_preview.get("error", "")).is_empty():
		preview_line = str(_preview["error"])
	if _message.is_empty() and not preview_line.is_empty():
		var preview_color := ArenaPixelArt.tint(0.9) if bool(_preview.get("ok", false)) else Color("ff9a8a", 0.8)
		_overlay.draw_string(ArenaPixelArt.FONT, Vector2(0.0, _confirm.position.y - 14.0), preview_line, HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_SIZE, preview_color)
	if not _message.is_empty():
		# Fonte normal: erros do compilador podem ter "_" e outros símbolos.
		_overlay.draw_string(ArenaPixelArt.FONT, Vector2(0.0, _confirm.position.y - 14.0), _message, HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_SIZE, Color("ff9a8a"))
	if not _drag_kind.is_empty() and _icons.has(_drag_kind):
		var icon_size := Vector2(48.0, 48.0)
		var at := Vector2(snappedf(_drag_position.x, PX), snappedf(_drag_position.y, PX)) - icon_size * 0.5
		_overlay.draw_texture_rect(_icons[_drag_kind], Rect2(at, icon_size), false, ArenaPixelArt.tint(1.0))
	if ware_mode and ware_map != null:
		_draw_ware_map()


func _draw_ware_map() -> void:
	var rect := _ware_map_rect()
	_overlay.draw_string(ArenaPixelArt.FONT_TINY, rect.position + Vector2(0.0, -8.0), "MAPA (mouse em cima ou TAB amplia)", HORIZONTAL_ALIGNMENT_LEFT, -1.0, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.55))
	_overlay.draw_texture_rect(ware_map, rect, false, Color(1.0, 1.0, 1.0, 0.9))
	_frame_only(rect.grow(PX))
	if not _map_open:
		return
	var width := minf(size.x - 120.0, 1100.0)
	var height := width * ware_map.get_height() / maxf(ware_map.get_width(), 1.0)
	if height > size.y - 160.0:
		height = size.y - 160.0
		width = height * ware_map.get_width() / maxf(ware_map.get_height(), 1.0)
	var big := Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height))
	_overlay.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, 0.75))
	_overlay.draw_rect(big.grow(PX * 2.0), Color(0.02, 0.04, 0.09, 1.0))
	_overlay.draw_texture_rect(ware_map, big, false)
	_frame_only(big.grow(PX * 2.0))


## Só a moldura (draw_pixel_frame também escurece o miolo).
func _frame_only(rect: Rect2) -> void:
	var line := ArenaPixelArt.tint(0.75)
	_overlay.draw_rect(Rect2(rect.position + Vector2(PX, 0.0), Vector2(rect.size.x - PX * 2.0, PX)), line)
	_overlay.draw_rect(Rect2(rect.position + Vector2(PX, rect.size.y - PX), Vector2(rect.size.x - PX * 2.0, PX)), line)
	_overlay.draw_rect(Rect2(rect.position + Vector2(0.0, PX), Vector2(PX, rect.size.y - PX * 2.0)), line)
	_overlay.draw_rect(Rect2(rect.position + Vector2(rect.size.x - PX, PX), Vector2(PX, rect.size.y - PX * 2.0)), line)


## Casa que vai receber a runa arrastada (da paleta ou movida na mesa), ou -1.
func drop_target() -> int:
	var local := Vector2.INF
	if not _drag_kind.is_empty():
		local = canvas.get_global_transform_with_canvas().affine_inverse() * _drag_position
		if _palette.get_global_rect().has_point(_drag_position):
			return -1
	elif canvas.drag_mode == "symbol":
		local = canvas.pointer_screen
	else:
		return -1
	if not canvas._is_canvas_position(local):
		return -1
	return canvas.drop_target_at(local)


## Enquanto arrasta, o quadradinho de destino acende: dá para ver onde a runa
## vai cair antes de soltar.
func _draw_drop_target() -> void:
	var target := drop_target()
	if target < 0 or target >= canvas.connections.size():
		return
	var slot: Vector2 = canvas.position + canvas._symbol_position(canvas.connections[target], target)
	var half: float = snappedf(14.0 * float(canvas.zoom), 2.0)
	var box := Rect2((slot - Vector2(half, half)).snapped(Vector2(2.0, 2.0)), Vector2(half, half) * 2.0)
	_overlay.draw_rect(box, ArenaPixelArt.tint(0.12))
	_slot_corners(box, ArenaPixelArt.tint(1.0), 8.0)


func _slot_corners(box: Rect2, color: Color, arm: float) -> void:
	var thick := 2.0
	for corner in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
		var inward_x := 1.0 if corner.x == box.position.x else -1.0
		var inward_y := 1.0 if corner.y == box.position.y else -1.0
		_overlay.draw_rect(Rect2(Vector2(corner.x if inward_x > 0.0 else corner.x - arm, corner.y if inward_y > 0.0 else corner.y - thick), Vector2(arm, thick)), color)
		_overlay.draw_rect(Rect2(Vector2(corner.x if inward_x > 0.0 else corner.x - thick, corner.y if inward_y > 0.0 else corner.y - arm), Vector2(thick, arm)), color)


## Modo ware: a intensidade de cada runa fica escrita no canto do ícone
## (casas a andar, ângulo, nota, cor...).
func _draw_intensity_labels() -> void:
	var font := ArenaPixelArt.FONT_TINY
	for index in range(canvas.connections.size()):
		var connection: Dictionary = canvas.connections[index]
		var kind := str(connection.get("symbol", ""))
		if kind.is_empty():
			# Casa vazia: um quadradinho tracejado mostra onde soltar a runa.
			var slot: Vector2 = canvas.position + canvas._symbol_position(connection, index)
			var half: float = snappedf(12.0 * float(canvas.zoom), 2.0)
			var box := Rect2((slot - Vector2(half, half)).snapped(Vector2(2.0, 2.0)), Vector2(half, half) * 2.0)
			_slot_corners(box, ArenaPixelArt.tint(0.35), 6.0)
			continue
		if not _uses_intensity(kind):
			continue
		var label := str(int(connection.get("intensity", 0)))
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ArenaPixelArt.FONT_TINY_SIZE)
		var corner: Vector2 = canvas.position + canvas._symbol_position(connection, index) + Vector2(12.0, 10.0) * canvas.zoom
		var box := Rect2(corner.snapped(Vector2(2.0, 2.0)), text_size + Vector2(8.0, 2.0))
		_overlay.draw_rect(box, Color(0.02, 0.04, 0.09, 0.9))
		_overlay.draw_rect(Rect2(box.position, Vector2(box.size.x, 2.0)), ArenaPixelArt.tint(0.5))
		_overlay.draw_string(font, box.position + Vector2(4.0, text_size.y - 3.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(1.0))


## Modo ware: objetivo e tempo no quadro de baixo à esquerda.
func _draw_ware_box() -> void:
	var rect := Rect2(MARGIN, size.y - MARGIN - 116.0, 380.0, 116.0)
	ArenaPixelArt.draw_pixel_frame(_overlay, rect)
	var status_color := Color("ff7a6a") if _ware_urgent else ArenaPixelArt.tint(1.0)
	if _ware_urgent:
		_overlay.draw_rect(Rect2(rect.position, Vector2(rect.size.x, PX)), status_color)
	_overlay.draw_string(ArenaPixelArt.FONT, rect.position + Vector2(16.0, 30.0), ware_status, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32.0, ArenaPixelArt.FONT_SIZE, status_color)
	_overlay.draw_multiline_string(ArenaPixelArt.FONT_TINY, rect.position + Vector2(16.0, 54.0), ware_objective, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 32.0, ArenaPixelArt.FONT_TINY_SIZE, 4, ArenaPixelArt.tint(0.75))


func _draw_mana_bar(font: Font) -> void:
	var rect := Rect2(MARGIN, size.y - MARGIN - 60.0, 300.0, 60.0)
	ArenaPixelArt.draw_pixel_frame(_overlay, rect)
	var remaining := mana - _cost
	var label_color := ArenaPixelArt.tint(0.85) if remaining >= 0 else Color("ff9a8a")
	_overlay.draw_string(font, rect.position + Vector2(16.0, 24.0), "MANA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.6))
	_overlay.draw_string(font, rect.position + Vector2(0.0, 24.0), "%d / %d" % [maxi(remaining, 0), max_mana], HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 16.0, ArenaPixelArt.FONT_TINY_SIZE, label_color)
	# Blocos: cheios = sobra, apagados = o que este feitiço vai gastar.
	var blocks := 34
	var bar := Rect2(rect.position + Vector2(16.0, 34.0), Vector2(blocks * 2.0 * PX - PX, 3.0 * PX))
	for index in range(blocks):
		var start := float(index) / float(blocks) * float(max_mana)
		var color := ArenaPixelArt.tint(0.08)
		if start < float(remaining):
			color = ArenaPixelArt.tint(0.85)
		elif start < float(mana):
			color = Color("ff9a8a", 0.55) if remaining < 0 else ArenaPixelArt.tint(0.3)
		_overlay.draw_rect(Rect2(bar.position + Vector2(index * 2.0 * PX, 0.0), Vector2(PX, bar.size.y)), color)


func _pixel_button(text: String, font: Font, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", ArenaPixelArt.tint(0.9))
	button.add_theme_color_override("font_hover_color", ArenaPixelArt.tint(1.0))
	button.add_theme_color_override("font_pressed_color", ArenaPixelArt.tint(1.0))
	button.add_theme_color_override("font_disabled_color", ArenaPixelArt.tint(0.3))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.02, 0.04, 0.09, 0.9 if state == "hover" or state == "pressed" else 0.7)
		var alpha := 1.0 if state == "hover" else (0.25 if state == "disabled" else 0.75)
		box.border_color = ArenaPixelArt.tint(alpha)
		box.set_border_width_all(int(PX))
		box.set_corner_radius_all(0)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


## ======================== PEÇAS DA HUD ========================

## Barra de runas no topo: cada ladrilho é um ícone pixel. Pressionar começa o
## arraste (quem acompanha o mouse é a criação).
class PaletteBar extends Control:
	signal rune_pressed(kind: String)
	signal hovered_changed(kind: String)

	const TILE := 56.0
	const GAP := 8.0
	const MAX_COLUMNS := 14
	const UNLIMITED_COUNT := 9999
	var kinds: Array = []
	var icons: Dictionary = {}
	var counts: Dictionary = {}
	var hovered := -1

	func set_counts(new_counts: Dictionary) -> void:
		if new_counts == counts:
			return
		counts = new_counts
		queue_redraw()

	func _columns() -> int:
		return clampi(kinds.size(), 1, MAX_COLUMNS)

	func _rows() -> int:
		return maxi(1, int(ceil(float(kinds.size()) / float(MAX_COLUMNS))))

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_exited.connect(func() -> void: _set_hovered(-1))

	func preferred_size() -> Vector2:
		return Vector2(GAP + _columns() * (TILE + GAP) + GAP, _rows() * (TILE + GAP) + GAP * 3.0)

	func _tile_rect(index: int) -> Rect2:
		var column := index % MAX_COLUMNS
		var row := index / MAX_COLUMNS
		return Rect2(GAP * 2.0 + column * (TILE + GAP), GAP * 2.0 + row * (TILE + GAP), TILE, TILE)

	func _index_at(point: Vector2) -> int:
		for index in range(kinds.size()):
			if _tile_rect(index).has_point(point):
				return index
		return -1

	func _set_hovered(index: int) -> void:
		if index == hovered:
			return
		hovered = index
		hovered_changed.emit(str(kinds[index]) if index >= 0 else "")
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_set_hovered(_index_at(event.position))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var index := _index_at(event.position)
			if index >= 0:
				rune_pressed.emit(str(kinds[index]))
				accept_event()

	func _draw() -> void:
		ArenaPixelArt.draw_pixel_frame(self, Rect2(Vector2.ZERO, size))
		var px := ArenaPixelArt.PIXEL
		for index in range(kinds.size()):
			var tile := _tile_rect(index)
			var count := int(counts.get(kinds[index], 0))
			var dim := 0.35 if count <= 0 else 1.0
			var line := ArenaPixelArt.tint((0.85 if index == hovered else 0.25) * dim)
			draw_rect(Rect2(tile.position, Vector2(tile.size.x, px)), line)
			draw_rect(Rect2(tile.position + Vector2(0.0, tile.size.y - px), Vector2(tile.size.x, px)), line)
			draw_rect(Rect2(tile.position, Vector2(px, tile.size.y)), line)
			draw_rect(Rect2(tile.position + Vector2(tile.size.x - px, 0.0), Vector2(px, tile.size.y)), line)
			var rune_key := str(kinds[index])
			var rarity := int(rune_key.get_slice("#", 1)) if rune_key.contains("#") else 0
			if rarity > 0:
				# Moldura na cor da raridade e um pontinho por nível.
				var rarity_color: Color = ArenaPixelArt.RARITY_COLORS[rarity]
				rarity_color.a *= dim
				draw_rect(Rect2(tile.position, Vector2(tile.size.x, px)), rarity_color)
				draw_rect(Rect2(tile.position + Vector2(0.0, tile.size.y - px), Vector2(tile.size.x, px)), rarity_color)
				draw_rect(Rect2(tile.position, Vector2(px, tile.size.y)), rarity_color)
				draw_rect(Rect2(tile.position + Vector2(tile.size.x - px, 0.0), Vector2(px, tile.size.y)), rarity_color)
				for pip in range(rarity):
					draw_rect(Rect2(tile.position + Vector2(px * 2.0 + pip * px * 2.0, px * 2.0), Vector2(px, px)), rarity_color)
			var icon = icons.get(rune_key.get_slice("#", 0))
			if icon != null:
				var icon_rect := Rect2(tile.position + Vector2(4.0, 4.0), Vector2(48.0, 48.0))
				draw_texture_rect(icon, icon_rect, false, ArenaPixelArt.tint((1.0 if index == hovered else 0.75) * dim))
			# Quantas sobram, no canto de baixo à direita (infinitas não mostram).
			if count < UNLIMITED_COUNT:
				draw_string(ArenaPixelArt.FONT_TINY, tile.position + Vector2(0.0, tile.size.y - 6.0), str(count), HORIZONTAL_ALIGNMENT_RIGHT, tile.size.x - 6.0, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.9 * dim) if count > 0 else Color("ff9a8a", 0.8))


## Intensidade da runa selecionada: blocos clicáveis/arrastáveis, roda do
## mouse ajusta de 1 em 1 (Shift: de 10 em 10).
class IntensityPanel extends Control:
	signal value_changed(value: int, first_change: bool)

	const PANEL_SIZE := Vector2(360.0, 84.0)
	const BLOCKS := 32
	var value := 0
	var max_value := 255
	## Botões − e + (modo ware); no arena o título usa a largura toda.
	var show_steps := false
	var icon: Texture2D
	var title := ""
	var _dragging := false

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_rune(new_icon: Texture2D, new_title: String, new_value: int) -> void:
		if new_icon == icon and new_title == title and new_value == value:
			return
		icon = new_icon
		title = new_title
		value = new_value
		queue_redraw()

	func _slider_rect() -> Rect2:
		var px := ArenaPixelArt.PIXEL
		return Rect2(16.0, 52.0, BLOCKS * 2.0 * px - px, 4.0 * px)

	## Botões − e + ao lado do número (passo 1; com Shift, 10).
	func _minus_rect() -> Rect2:
		return Rect2(size.x - 140.0, 12.0, 28.0, 28.0)

	func _plus_rect() -> Rect2:
		return Rect2(size.x - 106.0, 12.0, 28.0, 28.0)

	func _value_at(x: float) -> int:
		var slider := _slider_rect()
		return clampi(roundi((x - slider.position.x) / slider.size.x * float(max_value)), 0, max_value)

	func _emit(new_value: int, first_change: bool) -> void:
		new_value = clampi(new_value, 0, max_value)
		if new_value == value:
			return
		value = new_value
		value_changed.emit(value, first_change)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			var step := 10 if event.shift_pressed else 1
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_emit(value + step, true)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_emit(value - step, true)
				accept_event()
			elif show_steps and event.button_index == MOUSE_BUTTON_LEFT and _minus_rect().grow(2.0).has_point(event.position):
				_emit(value - step, true)
				accept_event()
			elif show_steps and event.button_index == MOUSE_BUTTON_LEFT and _plus_rect().grow(2.0).has_point(event.position):
				_emit(value + step, true)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_LEFT and _slider_rect().grow(8.0).has_point(event.position):
				_dragging = true
				_emit(_value_at(event.position.x), true)
				accept_event()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
		elif event is InputEventMouseMotion and _dragging:
			_emit(_value_at(event.position.x), false)
			accept_event()

	func _draw() -> void:
		var px := ArenaPixelArt.PIXEL
		ArenaPixelArt.draw_pixel_frame(self, Rect2(Vector2.ZERO, size))
		if icon != null:
			draw_texture_rect(icon, Rect2(Vector2(14.0, 10.0), Vector2(32.0, 32.0)), false, ArenaPixelArt.tint(1.0))
		draw_string(ArenaPixelArt.FONT_TINY, Vector2(56.0, 32.0), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - (204.0 if show_steps else 130.0), ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.85))
		for pair in ([[_minus_rect(), "-"], [_plus_rect(), "+"]] if show_steps else []):
			var box: Rect2 = pair[0]
			draw_rect(box, Color(0.02, 0.04, 0.09, 0.9))
			ArenaPixelArt.draw_pixel_frame(self, box)
			draw_string(ArenaPixelArt.FONT, box.position + Vector2(0.0, 21.0), str(pair[1]), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, ArenaPixelArt.FONT_SIZE, ArenaPixelArt.tint(1.0))
		draw_string(ArenaPixelArt.FONT, Vector2(0.0, 34.0), "%03d" % value, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16.0, ArenaPixelArt.FONT_SIZE, ArenaPixelArt.tint(1.0))
		var slider := _slider_rect()
		for index in range(BLOCKS):
			var lit := float(index) < float(value) / float(maxi(max_value, 1)) * float(BLOCKS)
			draw_rect(Rect2(slider.position + Vector2(index * 2.0 * px, 0.0), Vector2(px, slider.size.y)), ArenaPixelArt.tint(0.85 if lit else 0.12))
