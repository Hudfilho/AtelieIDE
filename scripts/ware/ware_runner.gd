extends Node2D

## ATELIER WARE: microjogos em sequência, no estilo WarioWare. Cada um mostra
## a ordem ("PULE ATÉ A BANDEIRA!"), o cronômetro corre e o jogador abre o
## editor de runas (a orbe cobre a tela), desenha o ritual e confirma: a
## pilha mágica vira ações que o microjogo anima. Errou, o mundo volta ao
## começo e dá para tentar de novo enquanto houver tempo; o tempo acabou,
## perde uma vida. A cada 3 vitórias o nível sobe (desafios maiores,
## animações mais rápidas, menos tempo).
##
## Treino (practice_game): um jogo só, sem cronômetro nem vidas; cada vitória
## sobe o nível daquele jogo.

const WareUI = preload("res://scripts/ware/ware_ui.gd")
const WareSfx = preload("res://scripts/ware/ware_sfx.gd")
const RuneIcons = preload("res://scripts/arena/rune_icons.gd")
const OrbTransition = preload("res://scripts/arena/orb_transition.gd")
const SpellCreationScene = preload("res://scenes/arena/SpellCreation.tscn")
const HUB_SCENE := "res://scenes/ware/Hub.tscn"
const PX := ArenaPixelArt.PIXEL

const GAMES := [
	"res://scripts/ware/games/maze.gd",
	"res://scripts/ware/games/jump_knight.gd",
	"res://scripts/ware/games/boxes.gd",
	"res://scripts/ware/games/coins.gd",
	"res://scripts/ware/games/cannon.gd",
	"res://scripts/ware/games/bells.gd",
	"res://scripts/ware/games/painter.gd",
	"res://scripts/ware/games/turret.gd",
	"res://scripts/ware/games/number.gd",
	"res://scripts/ware/games/defense.gd",
	"res://scripts/ware/games/torches.gd",
	"res://scripts/ware/games/frog.gd",
]
const START_LIVES := 4
## A cada 10 microjogos vem um CHEFÃO: um nível acima, mais tempo, e vencer
## devolve uma vida.
const BOSS_EVERY := 10
const RUN_GRACE := 6.0
const MAX_LEVEL := 5
const WINS_PER_LEVEL := 3
const INTRO_SECONDS := 1.8
## Recorde e progresso do treino. Os testes trocam por um arquivo próprio
## para não mexer no recorde de quem joga.
static var save_path := "user://atelier_ware.cfg"
const TOP_BAR := 92.0
const BOTTOM_BAR := 104.0
const CONFETTI_COLORS := [Color("ffcf4a"), Color("7be08a"), Color("ff7a6a"), Color("7fd7ff"), Color("f3ead7"), Color("b48cff")]

## Caminho do jogo do treino; vazio = sequência WarioWare.
static var practice_game := ""
static var practice_level := 1

var lives := START_LIVES
var score := 0
var level := 1
var best := 0
var time_left := 0.0
var time_total := 0.0
var game: Node2D
var state := "intro"

var _hud_layer: CanvasLayer
var _hud: Control
var _program_button: Button
var _creation_layer: CanvasLayer
var _creation
## Jogo para o qual o editor foi preparado (caminho#nível#semente): reiniciar
## o mesmo desafio mantém o desenho.
var _configured_key := ""
var _game_path := ""
var _game_level := 1
var _game_seed := 0
## Segundos do ritual rodando: depois de RUN_GRACE o relógio volta a andar
## (laço sem fim não trava a partida) e ESPAÇO/PARAR interrompe.
var _running_time := 0.0
var _overlay_layer: CanvasLayer
var _transition
var _busy := false
var _intro_left := 0.0
var _banner := ""
var _banner_color := Color.WHITE
var _last_fail := ""
var _last_index := -1
var _bag: Array = []
var _icons: Dictionary = {}
var _confetti: Array = []
var _banner_age := 0.0
var _heart_break := -1.0
var _last_tick := -1
## Resultado de cada microjogo da partida: {"title", "won"}.
var _history: Array = []
var _played := 0
var boss := false
var _exit_armed := 0.0
## Segundos de jogo desde que a ordem saiu (a dica do objetivo some aos 7 s).
var _play_time := 0.0
var _new_record := false
var _over_screen: Control


func _ready() -> void:
	randomize()
	best = _load_best()
	add_child(WareSfx.new())
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.draw.connect(_draw_hud)
	_program_button = WareUI.button("PROGRAMAR")
	_program_button.pressed.connect(_on_program_button)
	_hud.add_child(_program_button)

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

	get_viewport().size_changed.connect(_layout)
	_layout()
	if not practice_game.is_empty():
		level = clampi(practice_level, 1, MAX_LEVEL)
	next_game()


func _layout() -> void:
	var view := get_viewport_rect().size
	_program_button.size = Vector2(260.0, 60.0)
	_program_button.position = Vector2(snappedf((view.x - 260.0) * 0.5, PX), view.y - BOTTOM_BAR + 22.0)
	_hud.queue_redraw()


func world_area() -> Rect2:
	var view := get_viewport_rect().size
	var width := minf(view.x - 80.0, 1200.0)
	return Rect2(snappedf((view.x - width) * 0.5, PX), TOP_BAR + 8.0, width, view.y - TOP_BAR - BOTTOM_BAR - 16.0)


func is_practice() -> bool:
	return not practice_game.is_empty()


## ======================== SEQUÊNCIA ========================

func next_game() -> void:
	if game != null:
		game.queue_free()
	var path := practice_game
	if path.is_empty():
		# Saco embaralhado: todos os jogos aparecem antes de repetir.
		if _bag.is_empty():
			_bag = range(GAMES.size())
			_bag.shuffle()
			if _bag[0] == _last_index and _bag.size() > 1:
				_bag.push_back(_bag.pop_front())
		_last_index = _bag.pop_front()
		path = GAMES[_last_index]
	_played += 1
	boss = not is_practice() and _played % BOSS_EVERY == 0
	_game_path = path
	_game_level = mini(level + 1, MAX_LEVEL) if boss else level
	_game_seed = randi()
	_spawn_game()
	# Tempo pelo nível, com um bônus para desafios que pedem muitas runas.
	var runes_needed: int = game.solution_program().size()
	time_total = 0.0 if is_practice() else maxf(40.0, 90.0 - 10.0 * (level - 1)) + maxi(runes_needed - 6, 0) * 3.0
	if boss:
		time_total *= 1.5
	time_left = time_total
	_last_fail = ""
	_banner = ""
	_intro_left = INTRO_SECONDS
	_icons = RuneIcons.icons_for(game.runes)
	_last_tick = -1
	_play_time = 0.0
	state = "intro"
	_program_button.disabled = true
	WareSfx.play("levelup" if boss else "intro")
	WareSfx.music(1.0 + 0.05 * (level - 1) + (0.08 if boss else 0.0))
	_hud.queue_redraw()


func _process(delta: float) -> void:
	_update_effects(delta)
	if state == "intro":
		_intro_left -= delta
		if _intro_left <= 0.0:
			state = "play"
			_program_button.disabled = false
			game.start_round()
		_hud.queue_redraw()
		return
	_program_button.text = "PARAR" if state == "running" else "PROGRAMAR"
	_program_button.disabled = _busy or not (state == "play" or state == "running")
	if state == "running":
		_running_time += delta
	var ticking := state == "play" or state == "editor" or (state == "running" and _running_time > RUN_GRACE)
	if is_practice() or not ticking:
		return
	time_left = maxf(time_left - delta, 0.0)
	var whole := ceili(time_left)
	if whole <= 10 and whole != _last_tick and time_left > 0.0:
		_last_tick = whole
		WareSfx.play("tick" if whole % 2 == 0 else "tock")
	if _creation != null and state == "editor":
		_creation.set_ware_status("TEMPO %d" % ceili(time_left), time_left <= 10.0)
	_hud.queue_redraw()
	if time_left <= 0.0 and not _busy:
		_timeout()


func _unhandled_input(event: InputEvent) -> void:
	if state == "running" and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_abort_run()
		return
	if event.is_action_pressed("ui_cancel") and state != "editor" and not _busy:
		get_viewport().set_input_as_handled()
		# Na sequência, sair perde a partida: pede o ESC duas vezes.
		if is_practice() or state == "over" or _exit_armed > 0.0:
			get_tree().change_scene_to_file(HUB_SCENE)
		else:
			_exit_armed = 1.6
			WareSfx.play("click")
	elif event.is_action_pressed("ui_accept") and state == "play":
		get_viewport().set_input_as_handled()
		open_editor()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_M and state != "editor" and state != "over":
		get_viewport().set_input_as_handled()
		WareSfx.toggle_music()


func _spawn_game() -> void:
	game = (load(_game_path) as GDScript).new()
	game.area = world_area()
	game.speed = 1.0 + 0.15 * (level - 1)
	add_child(game)
	game.setup(_game_level, _game_seed)


## ======================== EDITOR ========================

func _on_program_button() -> void:
	if state == "running":
		_abort_run()
	else:
		open_editor()


func open_editor() -> void:
	if state != "play" or _busy:
		return
	_busy = true
	if _play_time < 7.0 and DisplayServer.get_name() != "headless":
		# A faixa da dica sai antes da foto do mapa.
		_play_time = 7.0
		_hud.queue_redraw()
		await RenderingServer.frame_post_draw
	var world_map := _capture_world()
	WareSfx.play("open")
	await _transition.cover_from(_program_button.get_global_rect().get_center(), 20.0)
	if not is_practice() and time_left <= 0.0:
		# O tempo acabou durante a transição: não abre o editor.
		await _transition.reveal()
		_busy = false
		return
	if _creation == null:
		_creation = SpellCreationScene.instantiate()
		_creation.close_requested.connect(close_editor)
		_creation.program_confirmed.connect(_on_program)
		_creation_layer.add_child(_creation)
	var key := "%s#%d#%d" % [_game_path, _game_level, _game_seed]
	if _configured_key != key:
		var starter: int = clampi(game.solution_program().size() + 3, 6, 15)
		_creation.configure_ware(game.runes, game.limits, game.names, game.default_intensity, game.max_intensity, game.objective, game.preview_text, starter)
		_configured_key = key
	else:
		# Mesmo desafio reiniciado (PARAR): o nó do jogo é novo.
		_creation.ware_preview = game.preview_text
	_creation.ware_status = "TREINO" if is_practice() else "TEMPO %d" % ceili(time_left)
	_creation.set_ware_map(world_map)
	_creation.open()
	_hud_layer.visible = false
	state = "editor"
	await _transition.reveal()
	_busy = false


func close_editor() -> void:
	if state != "editor" or _busy:
		return
	_busy = true
	WareSfx.play("close")
	await _transition.cover()
	_creation.hide()
	_hud_layer.visible = true
	state = "play"
	await _transition.shrink_to(_program_button.get_global_rect().get_center(), 20.0)
	_busy = false


func _on_program(actions: Array, output: Array) -> void:
	if state != "editor" or _busy:
		return
	await close_editor()
	if state != "play":
		return
	state = "running"
	_running_time = 0.0
	var playing := game
	var ok: bool = await game.execute(actions, output)
	if playing != game or state != "running":
		return
	if ok:
		_win()
	else:
		_fail()


## ======================== RESULTADOS ========================

func _win() -> void:
	state = "result"
	score += 1
	if score > best and not is_practice():
		best = score
		_new_record = true
		_save_best()
	WareSfx.play("win")
	_history.append({"title": game.title, "won": true})
	if is_practice():
		_save_practice(practice_game, level)
	_spawn_confetti()
	_show_banner("CHEFÃO DERROTADO!" if boss else "BOA!", Color("7be08a"))
	await get_tree().create_timer(1.2).timeout
	if boss and lives < START_LIVES:
		lives += 1
		WareSfx.play("levelup")
		_show_banner("VIDA EXTRA!", Color("ff9a8a"))
		await get_tree().create_timer(1.1).timeout
	var old_level := level
	if is_practice():
		level = mini(level + 1, MAX_LEVEL)
		practice_level = level
	else:
		level = mini(1 + score / WINS_PER_LEVEL, MAX_LEVEL)
	if level > old_level:
		WareSfx.play("levelup")
		_show_banner("NÍVEL %d: MAIS RÁPIDO!" % level if not is_practice() else "NÍVEL %d" % level, Color("ffcf4a"))
		await get_tree().create_timer(1.3).timeout
	await _swap_game()


func _fail() -> void:
	state = "result"
	_last_fail = game.fail_reason
	WareSfx.play("fail")
	_show_banner(game.fail_reason.to_upper() if not game.fail_reason.is_empty() else "NÃO DEU!", Color("ff7a6a"))
	await get_tree().create_timer(1.3).timeout
	if state != "result":
		return
	_banner = ""
	game.reset_world()
	state = "play"
	_program_button.disabled = false
	_hud.queue_redraw()


## ESPAÇO, ESC ou PARAR durante o ritual: o desafio recomeça igual (mesma
## semente) e o desenho continua no editor.
func _abort_run() -> void:
	if state != "running":
		return
	state = "result"
	_last_fail = "Você parou o ritual"
	WareSfx.play("fail")
	_show_banner("PAROU!", Color("ff7a6a"))
	game.queue_free()
	_spawn_game()
	await get_tree().create_timer(0.8).timeout
	if state != "result":
		return
	_banner = ""
	state = "play"
	game.start_round()


func _timeout() -> void:
	if state == "running" and game != null:
		# O ritual congela embaixo do "ACABOU O TEMPO!".
		game.process_mode = Node.PROCESS_MODE_DISABLED
	state = "result"
	if _creation != null and _creation.visible:
		_creation.hide()
		_hud_layer.visible = true
	lives -= 1
	_history.append({"title": game.title, "won": false})
	_heart_break = 1.0
	WareSfx.play("life")
	_show_banner("ACABOU O TEMPO!", Color("ff7a6a"))
	_program_button.disabled = true
	await get_tree().create_timer(1.4).timeout
	if lives <= 0:
		_game_over()
	else:
		await _swap_game()


## Troca de microjogo com a orbe cobrindo a tela (como abrir o editor).
func _swap_game() -> void:
	_busy = true
	var view := get_viewport_rect().size
	await _transition.cover_from(view * 0.5, 8.0)
	_banner = ""
	next_game()
	await _transition.reveal()
	_busy = false


func _show_banner(text: String, color: Color) -> void:
	_banner = text
	_banner_color = color
	_banner_age = 0.0
	_hud.queue_redraw()


## ======================== EFEITOS ========================

func _spawn_confetti() -> void:
	var view := get_viewport_rect().size
	for index in range(90):
		_confetti.append({
			"pos": Vector2(randf_range(0.0, view.x), randf_range(-80.0, -10.0)),
			"vel": Vector2(randf_range(-80.0, 80.0), randf_range(80.0, 260.0)),
			"color": CONFETTI_COLORS[index % CONFETTI_COLORS.size()],
			"size": PX * (1.0 if index % 3 else 2.0),
			"wobble": randf() * TAU,
		})


func _update_effects(delta: float) -> void:
	_banner_age += delta
	_hud.queue_redraw()
	if _exit_armed > 0.0:
		_exit_armed = maxf(_exit_armed - delta, 0.0)
		_hud.queue_redraw()
	if state == "play":
		_play_time += delta
	if _heart_break > 0.0:
		_heart_break = maxf(_heart_break - delta, 0.0)
	if _confetti.is_empty():
		return
	var view := get_viewport_rect().size
	for piece in _confetti:
		piece["wobble"] = float(piece["wobble"]) + delta * 6.0
		piece["vel"] = (piece["vel"] as Vector2) + Vector2(sin(float(piece["wobble"])) * 40.0, 60.0) * delta
		piece["pos"] = (piece["pos"] as Vector2) + (piece["vel"] as Vector2) * delta
	_confetti = _confetti.filter(func(piece: Dictionary) -> bool: return (piece["pos"] as Vector2).y < view.y + 20.0)
	_hud.queue_redraw()
	if _over_screen != null:
		_over_screen.queue_redraw()


## Foto do mundo (só a área do microjogo) para o mapa dentro do editor.
func _capture_world() -> Texture2D:
	if DisplayServer.get_name() == "headless" or game == null:
		return null
	var texture := get_viewport().get_texture()
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	var scale := Vector2(image.get_size()) / get_viewport_rect().size
	var area: Rect2 = game.content_rect().intersection(game.area)
	var region := Rect2i(Vector2i(area.position * scale), Vector2i(area.size * scale)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if region.size.x <= 0 or region.size.y <= 0:
		return null
	var cropped := image.get_region(region)
	# Sem alfa: o fundo do mundo vem transparente na textura da viewport.
	cropped.convert(Image.FORMAT_RGB8)
	return ImageTexture.create_from_image(cropped)


func _game_over() -> void:
	state = "over"
	WareSfx.stop_music()
	WareSfx.play("over")
	_banner = ""
	_program_button.visible = false
	var screen := Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.draw.connect(_draw_game_over.bind(screen))
	_over_screen = screen
	var again := WareUI.button("JOGAR DE NOVO")
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	var menu := WareUI.button("MENU")
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file(HUB_SCENE))
	var view := get_viewport_rect().size
	for index in range(2):
		var node: Button = [again, menu][index]
		node.size = Vector2(280.0, 60.0)
		node.position = Vector2(snappedf(view.x * 0.5 - 300.0 + index * 320.0, PX), view.y - 150.0)
		screen.add_child(node)
	if _new_record:
		_spawn_confetti()


func _draw_game_over(screen: Control) -> void:
	var size := screen.size
	screen.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.88))
	screen.draw_string(ArenaPixelArt.FONT, Vector2(0.0, 120.0), "FIM DE JOGO", HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, Color("ff9a8a"))
	screen.draw_string(ArenaPixelArt.FONT, Vector2(0.0, 176.0), "%d %s  :  NÍVEL %d" % [score, "microjogo" if score == 1 else "microjogos", level], HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_SIZE, ArenaPixelArt.tint(1.0))
	var record := "NOVO RECORDE!" if _new_record else "Recorde: %d" % best
	screen.draw_string(ArenaPixelArt.FONT if _new_record else ArenaPixelArt.FONT_TINY, Vector2(0.0, 210.0), record, HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_SIZE if _new_record else ArenaPixelArt.FONT_TINY_SIZE, Color("ffcf4a") if _new_record else ArenaPixelArt.tint(0.7))
	# A partida em cartõezinhos: verde venceu, vermelho o tempo acabou.
	var shown := _history.slice(maxi(_history.size() - 16, 0))
	var columns := 4
	var card := Vector2(220.0, 34.0)
	var width := columns * (card.x + 12.0) - 12.0
	var top := 250.0
	for index in range(shown.size()):
		var entry: Dictionary = shown[index]
		var at := Vector2(snappedf((size.x - width) * 0.5, PX) + (index % columns) * (card.x + 12.0), top + (index / columns) * (card.y + 10.0))
		var color := Color("7be08a") if entry["won"] else Color("ff7a6a")
		screen.draw_rect(Rect2(at, card), Color(0.02, 0.04, 0.09, 0.95))
		screen.draw_rect(Rect2(at, Vector2(PX, card.y)), color)
		screen.draw_string(ArenaPixelArt.FONT_TINY, at + Vector2(14.0, 23.0), str(entry["title"]), HORIZONTAL_ALIGNMENT_LEFT, card.x - 20.0, ArenaPixelArt.FONT_TINY_SIZE, color)
	for piece in _confetti:
		var piece_size: float = piece["size"]
		screen.draw_rect(Rect2((piece["pos"] as Vector2).snapped(Vector2(2.0, 2.0)), Vector2(piece_size, maxf(piece_size * absf(sin(float(piece["wobble"]))), 2.0))), piece["color"])


## ======================== HUD ========================

func _draw_hud() -> void:
	var view := _hud.size
	_hud.draw_rect(Rect2(Vector2.ZERO, Vector2(view.x, TOP_BAR)), Color(0.02, 0.04, 0.09, 0.9))
	_hud.draw_rect(Rect2(Vector2(0.0, TOP_BAR - PX), Vector2(view.x, PX)), ArenaPixelArt.tint(0.5))
	_hud.draw_rect(Rect2(Vector2(0.0, view.y - BOTTOM_BAR), Vector2(view.x, BOTTOM_BAR)), Color(0.02, 0.04, 0.09, 0.9))
	_hud.draw_rect(Rect2(Vector2(0.0, view.y - BOTTOM_BAR), Vector2(view.x, PX)), ArenaPixelArt.tint(0.5))
	if game == null:
		return
	var font := ArenaPixelArt.FONT
	var tiny := ArenaPixelArt.FONT_TINY
	# Esquerda: vidas (a que acabou de ir embora treme e pisca).
	if is_practice():
		_hud.draw_string(font, Vector2(32.0, 40.0), "TREINO", HORIZONTAL_ALIGNMENT_LEFT, -1, ArenaPixelArt.FONT_SIZE, ArenaPixelArt.tint(0.9))
		_hud.draw_string(tiny, Vector2(32.0, 66.0), "cada vitória sobe o nível", HORIZONTAL_ALIGNMENT_LEFT, -1, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.5))
	else:
		for index in range(START_LIVES):
			var at := Vector2(32.0 + index * 40.0, 30.0)
			var full := index < lives
			if index == lives and _heart_break > 0.0:
				at += Vector2(randf_range(-PX, PX), randf_range(-PX, PX))
				full = int(_heart_break * 12.0) % 2 == 0
			WareUI.draw_heart(_hud, at, full)
	# Centro: jogo, nível e cronômetro.
	var center_width := 460.0
	var left := snappedf((view.x - center_width) * 0.5, PX)
	var heading := "CHEFÃO: %s" % game.title if boss else "%s  NÍVEL %d" % [game.title, level]
	_hud.draw_string(font, Vector2(left, 36.0), heading, HORIZONTAL_ALIGNMENT_CENTER, center_width, ArenaPixelArt.FONT_SIZE, Color("ffcf4a") if boss else ArenaPixelArt.tint(1.0))
	if not is_practice():
		var bar := Rect2(Vector2(left, 52.0), Vector2(center_width, PX * 5.0))
		var urgent := time_left <= 10.0 and state != "intro"
		var blink := urgent and fmod(time_left, 1.0) > 0.5
		ArenaPixelArt.draw_pixel_frame(_hud, bar)
		var fill := (bar.size.x - PX * 2.0) * (time_left / maxf(time_total, 0.01))
		var color := Color("ff7a6a") if urgent else ArenaPixelArt.tint(0.9)
		if blink:
			color = Color("ffd0c8")
		_hud.draw_rect(Rect2(bar.position + Vector2(PX, PX), Vector2(snappedf(fill, PX), bar.size.y - PX * 2.0)), color)
		_hud.draw_string(font if urgent else tiny, Vector2(bar.end.x + 12.0, bar.end.y + (2.0 if urgent else -2.0)), str(ceili(time_left)), HORIZONTAL_ALIGNMENT_LEFT, -1, ArenaPixelArt.FONT_SIZE if urgent else ArenaPixelArt.FONT_TINY_SIZE, color)
	# Direita: pontos.
	if not is_practice():
		_hud.draw_string(font, Vector2(view.x - 232.0, 40.0), "PONTOS %d" % score, HORIZONTAL_ALIGNMENT_RIGHT, 200.0, ArenaPixelArt.FONT_SIZE, ArenaPixelArt.tint(1.0))
		_hud.draw_string(tiny, Vector2(view.x - 232.0, 66.0), "recorde %d" % best, HORIZONTAL_ALIGNMENT_RIGHT, 200.0, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.5))
	else:
		_hud.draw_string(tiny, Vector2(view.x - 232.0, 40.0), "ESC volta ao menu", HORIZONTAL_ALIGNMENT_RIGHT, 200.0, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.5))
	# Baixo à esquerda: as runas deste microjogo (com limite) e a última falha.
	var bottom := view.y - BOTTOM_BAR
	_hud.draw_string(tiny, Vector2(32.0, bottom + 26.0), "RUNAS", HORIZONTAL_ALIGNMENT_LEFT, -1, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.45))
	_draw_rune_row(Vector2(96.0, bottom + 10.0), 32.0, ArenaPixelArt.tint(0.85))
	if not _last_fail.is_empty():
		_hud.draw_string(tiny, Vector2(32.0, bottom + 78.0), "Última tentativa: " + _last_fail, HORIZONTAL_ALIGNMENT_LEFT, (view.x - 260.0) * 0.5 - 48.0, ArenaPixelArt.FONT_TINY_SIZE, Color("ff9a8a"))
	var right := _program_button.position.x + _program_button.size.x + 32.0
	_hud.draw_string(tiny, Vector2(right, bottom + 46.0), "ESPAÇO interrompe o ritual" if state == "running" else "ESPAÇO abre o editor", HORIZONTAL_ALIGNMENT_LEFT, view.x - right - 32.0, ArenaPixelArt.FONT_TINY_SIZE, Color("ffcf4a") if state == "running" else ArenaPixelArt.tint(0.45))
	_hud.draw_string(tiny, Vector2(right, bottom + 68.0), "ESC também interrompe" if state == "running" else "ESC volta ao menu   M música", HORIZONTAL_ALIGNMENT_LEFT, view.x - right - 32.0, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.3))
	# Dica: o objetivo do microjogo no alto do mundo, nos primeiros segundos.
	if state == "play" and _play_time < 7.0 and not game.objective.is_empty():
		var fade := clampf(7.0 - _play_time, 0.0, 1.0)
		var lines := 1 if tiny.get_string_size(game.objective, HORIZONTAL_ALIGNMENT_LEFT, -1, ArenaPixelArt.FONT_TINY_SIZE).x < view.x - 80.0 else 2
		var strip := Rect2(Vector2(0.0, TOP_BAR), Vector2(view.x, 16.0 + lines * 18.0))
		_hud.draw_rect(strip, Color(0.02, 0.04, 0.09, 0.8 * fade))
		_hud.draw_multiline_string(tiny, Vector2(40.0, TOP_BAR + 23.0), game.objective, HORIZONTAL_ALIGNMENT_CENTER, view.x - 80.0, ArenaPixelArt.FONT_TINY_SIZE, 2, Color(ArenaPixelArt.tint(0.85), fade))
	if _exit_armed > 0.0:
		var strip := Rect2(Vector2(0.0, view.y - BOTTOM_BAR - 40.0), Vector2(view.x, 36.0))
		_hud.draw_rect(strip, Color(0.02, 0.04, 0.09, 0.9))
		_hud.draw_string(font, Vector2(0.0, strip.end.y - 10.0), "ESC de novo para sair (a partida acaba)", HORIZONTAL_ALIGNMENT_CENTER, view.x, ArenaPixelArt.FONT_SIZE, Color("ff9a8a"))
	# Cartão da ordem (intro) e faixa de resultado.
	if state == "intro":
		_draw_intro_card(view)
	elif not _banner.is_empty():
		var strip := Rect2(Vector2(0.0, view.y * 0.5 - 50.0), Vector2(view.x, 100.0))
		_hud.draw_rect(strip, Color(0.02, 0.04, 0.09, 0.85))
		_hud.draw_rect(Rect2(strip.position, Vector2(strip.size.x, PX)), _banner_color)
		_hud.draw_rect(Rect2(strip.position + Vector2(0.0, strip.size.y - PX), Vector2(strip.size.x, PX)), _banner_color)
		# Pop: começa grande e assenta (tamanhos inteiros da fonte pixel).
		var font_size := 66 if _banner_age < 0.12 else 44
		_hud.draw_string(font, Vector2(0.0, strip.get_center().y + (24.0 if font_size == 66 else 16.0)), _banner, HORIZONTAL_ALIGNMENT_CENTER, view.x, font_size, _banner_color)
	for piece in _confetti:
		var size: float = piece["size"]
		var squash := absf(sin(float(piece["wobble"])))
		_hud.draw_rect(Rect2((piece["pos"] as Vector2).snapped(Vector2(2.0, 2.0)), Vector2(size, maxf(size * squash, 2.0))), piece["color"])


func _draw_intro_card(view: Vector2) -> void:
	var font := ArenaPixelArt.FONT
	var tiny := ArenaPixelArt.FONT_TINY
	var card := Rect2(Vector2(view.x * 0.5 - 400.0, view.y * 0.5 - 120.0), Vector2(800.0, 230.0))
	var pop := clampf((INTRO_SECONDS - _intro_left) / 0.2, 0.0, 1.0)
	card = card.grow(-(1.0 - pop) * 60.0)
	WareUI.draw_box(_hud, card)
	if pop < 1.0:
		return
	if boss:
		_hud.draw_rect(Rect2(card.position, Vector2(card.size.x, PX)), Color("ffcf4a"))
		_hud.draw_rect(Rect2(card.position + Vector2(0.0, card.size.y - PX), Vector2(card.size.x, PX)), Color("ffcf4a"))
		_hud.draw_string(font, card.position + Vector2(0.0, 44.0), "CHEFÃO!  %s" % game.title, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, ArenaPixelArt.FONT_SIZE, Color("ffcf4a"))
	else:
		_hud.draw_string(tiny, card.position + Vector2(0.0, 40.0), "%s   NÍVEL %d" % [game.title, level], HORIZONTAL_ALIGNMENT_CENTER, card.size.x, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.6))
	var shake := Vector2(0.0, -absf(sin((INTRO_SECONDS - _intro_left) * 9.0)) * PX) if _intro_left > INTRO_SECONDS - 0.6 else Vector2.ZERO
	_hud.draw_string(font, card.position + Vector2(0.0, 106.0) + shake, game.instruction, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 44, ArenaPixelArt.tint(1.0))
	var row_width := _icons.size() * 52.0
	_draw_rune_row(Vector2(card.get_center().x - row_width * 0.5 + 6.0, card.position.y + 140.0), 40.0, ArenaPixelArt.tint(0.9))


## Ícones das runas do microjogo; as limitadas mostram quantas há.
func _draw_rune_row(start: Vector2, icon_size: float, tint: Color) -> void:
	var tiny := ArenaPixelArt.FONT_TINY
	var step := icon_size + 12.0
	var index := 0
	for kind in game.runes:
		if not _icons.has(kind):
			continue
		var at := start + Vector2(index * step, 0.0)
		_hud.draw_texture_rect(_icons[kind], Rect2(at, Vector2(icon_size, icon_size)), false, tint)
		if game.limits.has(kind):
			_hud.draw_string(tiny, at + Vector2(icon_size - 4.0, icon_size + 6.0), "x%d" % int(game.limits[kind]), HORIZONTAL_ALIGNMENT_LEFT, -1, ArenaPixelArt.FONT_TINY_SIZE, Color("ffcf4a"))
		index += 1


## ======================== RECORDE ========================

func _load_best() -> int:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return 0
	return int(config.get_value("ware", "best", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.load(save_path)
	config.set_value("ware", "best", best)
	config.save(save_path)


## Treino: o maior nível vencido de cada microjogo (o menu mostra).
func _save_practice(path: String, won_level: int) -> void:
	var config := ConfigFile.new()
	config.load(save_path)
	var key := path.get_file().get_basename()
	if won_level > int(config.get_value("practice", key, 0)):
		config.set_value("practice", key, won_level)
		config.save(save_path)
