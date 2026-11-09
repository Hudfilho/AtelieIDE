extends Control

## Menu inicial: Atelier Ware (sequência WarioWare), Treino (um microjogo por
## vez, com o maior nível vencido de cada um), a Arena das bolinhas e o
## Editor livre (o Sandbox, intocado).

const WareUI = preload("res://scripts/ware/ware_ui.gd")
const WareRunner = preload("res://scripts/ware/ware_runner.gd")
const WareSfx = preload("res://scripts/ware/ware_sfx.gd")
const RuneIcons = preload("res://scripts/arena/rune_icons.gd")
const Skeleton = preload("res://scripts/arena/skeleton.gd")
const WARE_SCENE := "res://scenes/ware/Ware.tscn"
const ARENA_SCENE := "res://scenes/arena/Arena.tscn"
const SANDBOX_SCENE := "res://scenes/Main.tscn"
const PX := ArenaPixelArt.PIXEL
const DECOR := ["MOVE_UP", "MOVE_RIGHT", "JUMP", "BELL", "PAINT", "TURN", "SHOOT", "AIM", "FIRE", "EXPLOSION"]

var _main: Array = []
var _practice: Array = []
## Para cada botão do treino: [ícone da runa principal, maior nível vencido].
var _practice_info: Array = []
var _icons: Dictionary = {}
var _clock := 0.0
var _picking := false
var _help := false
var _best := 0
var _help_back: Button
const HELP := [
	["1", "Leia a ordem do microjogo e olhe o desafio."],
	["2", "PROGRAMAR (ou ESPAÇO) abre o editor. Arraste runas da barra de cima para as casas da linha."],
	["3", "Clique numa runa e mude a intensidade (barra, botões - e +, ou digite o número): casas, ângulo, nota, cor..."],
	["4", "Fim de portal e Portal de mesma intensidade repetem um trecho. Duplicar repete a próxima runa."],
	["5", "CONFIRMAR roda o ritual. Errou? O mundo volta e o desenho fica: ajuste e tente de novo."],
	["6", "O tempo corre até com o editor aberto. Acabou o tempo, perde uma vida. A cada 10 vem um chefão."],
	["TAB", "No editor, segure TAB (ou ponha o mouse no mapa) para ver o desafio grande."],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(WareSfx.new())
	_icons = RuneIcons.icons_for(DECOR)
	var config := ConfigFile.new()
	config.load(WareRunner.save_path)
	_best = int(config.get_value("ware", "best", 0))
	var entries := [
		["JOGAR", func() -> void: _start_ware("", 1)],
		["TREINAR", func() -> void: _show_practice(true)],
		["COMO JOGAR", func() -> void: _show_help(true)],
		["ARENA DAS BOLINHAS", func() -> void: _go(ARENA_SCENE)],
		["EDITOR LIVRE", func() -> void: _go(SANDBOX_SCENE)],
	]
	for entry in entries:
		var button := WareUI.button(str(entry[0]))
		button.pressed.connect(entry[1])
		button.mouse_entered.connect(func() -> void: WareSfx.play("click", 1.2, -6.0))
		add_child(button)
		_main.append(button)
	for path in WareRunner.GAMES:
		var probe = (load(path) as GDScript).new()
		var title := str(probe.title)
		var main_rune := str(probe.runes[0]) if not probe.runes.is_empty() else ""
		probe.free()
		var won := int(config.get_value("practice", str(path).get_file().get_basename(), 0))
		var button := WareUI.button(title if won <= 0 else "%s   %d/%d" % [title, won, WareRunner.MAX_LEVEL], false)
		button.pressed.connect(_start_ware.bind(path, clampi(won, 1, WareRunner.MAX_LEVEL)))
		button.mouse_entered.connect(func() -> void: WareSfx.play("click", 1.2, -6.0))
		add_child(button)
		_practice.append(button)
		_practice_info.append([RuneIcons.icon(main_rune), won])
	var back := WareUI.button("VOLTAR", false)
	back.pressed.connect(func() -> void: _show_practice(false))
	add_child(back)
	_practice.append(back)
	_help_back = WareUI.button("VOLTAR", false)
	_help_back.pressed.connect(func() -> void: _show_help(false))
	add_child(_help_back)
	resized.connect(_layout)
	_show_practice(false)
	WareSfx.music(0.9, -3.0)


func _show_help(show: bool) -> void:
	_help = show
	WareSfx.play("click")
	for button in _main:
		button.visible = not show
	_help_back.visible = show
	_layout()


func _show_practice(show: bool) -> void:
	_picking = show
	WareSfx.play("click")
	for button in _main:
		button.visible = not show
	for button in _practice:
		button.visible = show
	if _help_back != null:
		_help_back.visible = false
	_layout()


func _layout() -> void:
	var middle := size.x * 0.5
	for index in range(_main.size()):
		var button: Button = _main[index]
		button.size = Vector2(360.0, 56.0)
		button.position = Vector2(snappedf(middle - 180.0, PX), snappedf(size.y * 0.5 - 40.0 + index * 64.0, PX))
	var columns := 2
	for index in range(_practice.size() - 1):
		var button: Button = _practice[index]
		button.size = Vector2(280.0, 44.0)
		var column := index % columns
		var row := index / columns
		button.position = Vector2(snappedf(middle - 300.0 + column * 340.0, PX), snappedf(size.y * 0.5 - 100.0 + row * 50.0, PX))
	if _help_back != null:
		_help_back.size = Vector2(160.0, 44.0)
		_help_back.position = Vector2(snappedf(middle - 80.0, PX), snappedf(size.y - 110.0, PX))
	var back: Button = _practice[-1]
	var game_rows := int(ceil((_practice.size() - 1) / float(columns)))
	back.size = Vector2(160.0, 44.0)
	back.position = Vector2(snappedf(middle - 80.0, PX), snappedf(size.y * 0.5 - 100.0 + game_rows * 50.0 + 10.0, PX))
	queue_redraw()


func _start_ware(path: String, start_level: int) -> void:
	WareRunner.practice_game = path
	WareRunner.practice_level = start_level
	_go(WARE_SCENE)


func _go(scene: String) -> void:
	WareSfx.play("open")
	get_tree().change_scene_to_file(scene)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_M:
		get_viewport().set_input_as_handled()
		WareSfx.toggle_music()
		return
	if _picking and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_practice(false)
	elif _help and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_help(false)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.09, 0.19))
	# Runas flutuando no fundo.
	var keys := _icons.keys()
	for index in range(keys.size()):
		var texture: Texture2D = _icons[keys[index]]
		var x := fmod(index * 137.0 + _clock * (14.0 + index % 3 * 6.0), size.x + 120.0) - 60.0
		var y := size.y * (0.12 + 0.7 * fmod(index * 0.37, 1.0)) + sin(_clock + index) * 10.0
		draw_texture_rect(texture, Rect2(Vector2(x, y).snapped(Vector2(PX, PX)), Vector2(48.0, 48.0)), false, ArenaPixelArt.tint(0.12))
	# Chão com esqueletos passeando.
	var ground := size.y - 36.0
	draw_rect(Rect2(Vector2(0.0, ground), Vector2(size.x, PX)), ArenaPixelArt.tint(0.25))
	Skeleton._ensure_frames()
	for index in range(3):
		var speed := 40.0 + index * 17.0
		var x := fmod(_clock * speed + index * 420.0, size.x + 160.0) - 80.0
		var frame: Texture2D = Skeleton._walk_frames[int(_clock * 8.0 + index) % Skeleton._walk_frames.size()]
		var sprite := Vector2(Skeleton.W, Skeleton.H) * 3.0
		draw_texture_rect(frame, Rect2(Vector2(x - sprite.x * 0.5, ground - Skeleton.FEET_ROW * 3.0).snapped(Vector2(3.0, 3.0)), sprite), false, Color(1.0, 1.0, 1.0, 0.55))
	var title_y := size.y * 0.5 - 150.0
	var bob := floorf(sin(_clock * 2.0) * 2.0) * PX * 0.5
	draw_string(ArenaPixelArt.FONT, Vector2(0.0, title_y + bob), "ATELIER WARE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 66, ArenaPixelArt.tint(1.0))
	var subtitle := "Escolha um microjogo para treinar (começa no maior nível que você já venceu)" if _picking else "Programe feitiços de runas para vencer microjogos"
	if _help:
		subtitle = "Como jogar"
		var top := title_y + 60.0
		var panel := Rect2(Vector2(snappedf(size.x * 0.5 - 460.0, PX), top), Vector2(920.0, HELP.size() * 40.0 + 24.0))
		WareUI.draw_box(self, panel)
		for index in range(HELP.size()):
			var line: Array = HELP[index]
			var y := panel.position.y + 40.0 + index * 40.0
			draw_string(ArenaPixelArt.FONT, Vector2(panel.position.x + 24.0, y), str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, 60.0, ArenaPixelArt.FONT_SIZE, Color("ffcf4a"))
			draw_string(ArenaPixelArt.FONT_TINY, Vector2(panel.position.x + 96.0, y - 2.0), str(line[1]), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 120.0, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.85))
	draw_string(ArenaPixelArt.FONT_TINY, Vector2(0.0, title_y + 40.0), subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.6))
	if _picking:
		for index in range(_practice_info.size()):
			var button: Button = _practice[index]
			var info: Array = _practice_info[index]
			if info[0] != null:
				var tint := Color("ffcf4a") if int(info[1]) >= WareRunner.MAX_LEVEL else ArenaPixelArt.tint(0.8)
				draw_texture_rect(info[0], Rect2(button.position + Vector2(-44.0, 4.0), Vector2(36.0, 36.0)), false, tint)
	draw_string(ArenaPixelArt.FONT_TINY, Vector2(size.x - 220.0, size.y - 12.0), "M liga/desliga a música", HORIZONTAL_ALIGNMENT_RIGHT, 200.0, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.3))
	if _best > 0 and not _help and not _picking:
		draw_string(ArenaPixelArt.FONT_TINY, Vector2(0.0, size.y - 52.0), "Recorde: %d %s" % [_best, "microjogo" if _best == 1 else "microjogos"], HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.45))
