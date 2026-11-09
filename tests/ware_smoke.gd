extends SceneTree

## Atelier Ware: cada microjogo, em cada nível, tem um ritual que resolve o
## desafio passando pelo compilador e pela VM de verdade, dentro dos limites
## de runas e de intensidade; ritual vazio falha. Também roda o caminho
## completo na cena: abrir o editor, desenhar, confirmar e vencer.

const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")
const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const Nasm = preload("res://scripts/core/rune_nasm_exporter.gd")
const WareRunner = preload("res://scripts/ware/ware_runner.gd")
const RuneIcons = preload("res://scripts/arena/rune_icons.gd")
const STEP_LIMIT := 2000
const MAX_ACTIONS := 300

var failures := 0
var checks := 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FALHOU: ", label)


static func cells(program: Array) -> Array:
	var result: Array = []
	for index in range(program.size()):
		var entry: Dictionary = program[index]
		result.append({"from": Vector2(index, 0), "to": Vector2(index + 1, 0), "symbol": str(entry["kind"]), "intensity": int(entry["intensity"])})
	return result


## Caracteres que a fonte pixel não tem (viram quadradinho na tela).
static func missing_glyphs(text: String, font: Font) -> String:
	var missing := ""
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code != 32 and code != 10 and not font.has_char(code) and not missing.contains(text[index]):
			missing += text[index]
	return missing


func run_program(program: Array) -> Dictionary:
	var compiled: Dictionary = RuneCompiler.new().compile(cells(program))
	if not bool(compiled.get("ok", false)):
		return {"ok": false, "error": str(compiled.get("errors"))}
	var run: Dictionary = RuneVM.new().run_program(compiled["instructions"], {}, STEP_LIMIT)
	if not bool(run.get("ok", false)) and not bool(run.get("timed_out", false)):
		return {"ok": false, "error": str(run.get("errors"))}
	var actions: Array = run.get("magic", [])
	return {"ok": true, "actions": actions.slice(0, MAX_ACTIONS), "output": run.get("output", [])}


func _initialize() -> void:
	# Recorde/treino dos testes vão para outro arquivo (o do jogador fica intacto).
	WareRunner.save_path = "user://atelier_ware_teste.cfg"
	# --- runas de ação: catálogo, ícones, VM e NASM
	for kind in ["MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT", "JUMP", "PAINT", "BELL", "TURN", "SHOOT", "AIM"]:
		var opcode := RuneCatalog.opcode_for_kind(kind)
		check(opcode >= 0x30 and opcode <= 0x39, "%s tem opcode de ação" % kind)
		check(RuneCatalog.is_magic(opcode) and RuneCatalog.is_game_only(opcode), "%s é ação só do modo jogo" % kind)
		check(RuneIcons.icon(kind) != null, "%s tem ícone" % kind)
	check(RuneCatalog.SYMBOLS.size() == 30, "Sandbox continua com 30 runas")
	var editor_names: Dictionary = load("res://scripts/arena/spell_creation.gd").RUNE_NAMES
	for kind in editor_names:
		check(missing_glyphs(str(editor_names[kind]), ArenaPixelArt.FONT_TINY).is_empty(), "nome da runa %s cabe na fonte pequena" % kind)
	var loop := run_program([{"kind": "WARP_ENDPOINT", "intensity": 1}, {"kind": "MOVE_RIGHT", "intensity": 2}, {"kind": "WARP", "intensity": 1}])
	check(bool(loop["ok"]) and loop["actions"].size() == MAX_ACTIONS and loop["actions"][0]["kind"] == "MOVE_RIGHT", "laço infinito vira ações até o teto")
	var nasm: Dictionary = Nasm.new().generate(cells([{"kind": "MOVE_UP", "intensity": 3}]))
	check(not bool(nasm.get("ok", true)), "NASM recusa runa de ação: %s" % [nasm.get("errors", nasm.get("error", ""))])

	# --- todos os microjogos, níveis 1 a 5, duas sementes cada
	for path in WareRunner.GAMES:
		for level in range(1, 6):
			for seed_value in [11, 4242, 7, 90210]:
				var game = (load(path) as GDScript).new()
				game.area = Rect2(40.0, 100.0, 1200.0, 504.0)
				game.speed = 60.0
				root.add_child(game)
				var started := Time.get_ticks_msec()
				game.setup(level, seed_value)
				var label := "%s nível %d semente %d" % [game.title, level, seed_value]
				var tiny_texts: Array = [game.objective] + game.names.values()
				for shown in tiny_texts:
					check(missing_glyphs(str(shown), ArenaPixelArt.FONT_TINY).is_empty(), "%s: fonte pequena tem todos os caracteres de '%s' (faltam '%s')" % [label, shown, missing_glyphs(str(shown), ArenaPixelArt.FONT_TINY)])
				for shown in [game.title, game.instruction]:
					check(missing_glyphs(str(shown), ArenaPixelArt.FONT).is_empty(), "%s: fonte tem todos os caracteres de '%s'" % [label, shown])
				check(Time.get_ticks_msec() - started < 1500, "%s: monta em menos de 1,5 s (%d ms)" % [label, Time.get_ticks_msec() - started])
				for kind in game.max_intensity:
					check(int(game.max_intensity[kind]) <= 255, "%s: máximo de %s cabe em 1 byte" % [label, kind])
				if str(path).ends_with("torches.gd") and (level == 3 or level == 4):
					check(int(game.max_intensity.get("FIRE", 3)) == 1, "%s: Fogo só alcança 1 nos níveis de laço" % label)
				var program: Array = game.solution_program()
				check(not program.is_empty(), "%s: tem solução" % label)
				var used := {}
				for entry in program:
					var kind := str(entry["kind"])
					used[kind] = int(used.get(kind, 0)) + 1
					check(game.runes.has(kind), "%s: %s está na paleta" % [label, kind])
					check(int(entry["intensity"]) >= 0 and int(entry["intensity"]) <= 255, "%s: intensidade de %s cabe em 1 byte" % [label, kind])
					if game.max_intensity.has(kind):
						check(int(entry["intensity"]) <= int(game.max_intensity[kind]), "%s: %s respeita o máximo" % [label, kind])
				for kind in game.limits:
					check(int(used.get(kind, 0)) <= int(game.limits[kind]), "%s: %s dentro do limite (%d de %d)" % [label, kind, int(used.get(kind, 0)), int(game.limits[kind])])
				var run := run_program(program)
				check(bool(run["ok"]), "%s: ritual compila e roda (%s)" % [label, run.get("error", "")])
				if bool(run["ok"]):
					var preview := str(game.preview_text(run["actions"], run["output"]))
					check(not preview.is_empty() and missing_glyphs(preview, ArenaPixelArt.FONT).is_empty(), "%s: prévia '%s' cabe na fonte" % [label, preview])
					var won: bool = await game.execute(run["actions"], run["output"])
					check(won, "%s: a solução vence (%s) %s" % [label, game.fail_reason, program])
				game.reset_world()
				var empty: bool = await game.execute([], [])
				check(not empty and not game.fail_reason.is_empty(), "%s: ritual vazio perde com motivo" % label)
				check(missing_glyphs(game.fail_reason.to_upper(), ArenaPixelArt.FONT).is_empty() and missing_glyphs(game.fail_reason, ArenaPixelArt.FONT_TINY).is_empty(), "%s: motivo '%s' cabe nas fontes" % [label, game.fail_reason])
				game.queue_free()
				await process_frame

	# --- erros específicos
	var maze = (load("res://scripts/ware/games/maze.gd") as GDScript).new()
	maze.speed = 60.0
	root.add_child(maze)
	maze.setup(1, 7)
	var blocked := ""
	for kind in ["MOVE_UP", "MOVE_LEFT"]:
		maze.reset_world()
		var bumped: bool = await maze.execute([{"kind": kind, "intensity": 1}], [])
		blocked = maze.fail_reason
		check(not bumped and blocked == "Bateu na parede", "labirinto: sair pela borda bate na parede")
	maze.queue_free()
	var bells = (load("res://scripts/ware/games/bells.gd") as GDScript).new()
	bells.speed = 60.0
	root.add_child(bells)
	bells.setup(1, 3)
	var wrong_note: int = (int(bells.melody[0]) % int(bells.bell_count)) + 1
	var wrong: bool = await bells.execute([{"kind": "BELL", "intensity": wrong_note}], [])
	check(not wrong and bells.fail_reason.begins_with("Nota errada"), "sinos: nota errada perde (%s)" % bells.fail_reason)
	bells.queue_free()
	var number = (load("res://scripts/ware/games/number.gd") as GDScript).new()
	number.speed = 60.0
	root.add_child(number)
	number.setup(3, 5)
	var off: bool = await number.execute([], [str(number.target + 1)])
	check(not off and number.fail_reason.begins_with("Entregou"), "número: valor errado perde")
	number.queue_free()

	# --- cena completa: treino do labirinto e das moedas pelo editor
	for path in ["res://scripts/ware/games/maze.gd", "res://scripts/ware/games/coins.gd", "res://scripts/ware/games/number.gd"]:
		await _play_scene(path, 2 if path.ends_with("coins.gd") else 1)
	await _boss_round()
	for path in ["res://scripts/ware/games/turret.gd", "res://scripts/ware/games/bells.gd", "res://scripts/ware/games/painter.gd"]:
		await _play_by_dropping(path, 3)
	await _loop_and_stop()
	await _move_rune_to_slot()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WareRunner.save_path))
	print("ware_smoke: %d verificações, %d falhas" % [checks, failures])
	if failures == 0:
		print("WARE_SMOKE_OK")
	quit(1 if failures > 0 else 0)


func _play_scene(path: String, start_level: int) -> void:
	WareRunner.practice_game = path
	WareRunner.practice_level = start_level
	var runner = (load("res://scenes/ware/Ware.tscn") as PackedScene).instantiate()
	root.add_child(runner)
	await process_frame
	var name := path.get_file()
	check(runner.state == "intro", "%s: começa com a ordem na tela" % name)
	while runner.state == "intro":
		await process_frame
	runner.game.speed = 60.0
	runner.open_editor()
	while runner._busy:
		await process_frame
	check(runner.state == "editor", "%s: PROGRAMAR abre o editor" % name)
	var creation = runner._creation
	check(creation.ware_mode and creation.visible, "%s: editor em modo ware" % name)
	check(creation._palette.kinds == runner.game.runes, "%s: paleta do microjogo %s" % [name, creation._palette.kinds])
	var canvas = creation.canvas
	var g: float = canvas.GRID_SPACING
	var program: Array = runner.game.solution_program()
	var drawn: Array = []
	for cell in cells(program):
		cell["from"] = cell["from"] * g
		cell["to"] = cell["to"] * g
		drawn.append(cell)
	canvas.load_connections(drawn, Vector2(300, 360), 1.0)
	await process_frame
	await process_frame
	check(bool(creation._preview.get("ok", false)), "%s: prévia ok (%s)" % [name, creation._preview])
	var level_before: int = runner.level
	creation._on_confirm()
	var frames := 0
	while runner.state != "result" and frames < 2000:
		await process_frame
		frames += 1
	check(runner.score == 1 and runner._banner == "BOA!", "%s: ritual desenhado vence pela cena (%s)" % [name, runner.game.fail_reason])
	while runner.state == "result":
		await process_frame
	check(runner.level == mini(level_before + 1, 5), "%s: treino sobe o nível" % name)
	runner.queue_free()
	WareRunner.practice_game = ""
	await process_frame


## O décimo microjogo da sequência é chefão: nível acima, mais tempo, e
## vencer devolve uma vida.
func _boss_round() -> void:
	WareRunner.practice_game = ""
	var runner = (load("res://scenes/ware/Ware.tscn") as PackedScene).instantiate()
	root.add_child(runner)
	await process_frame
	var normal_time: float = runner.time_total
	check(not runner.boss, "primeiro microjogo não é chefão")
	runner._played = WareRunner.BOSS_EVERY - 1
	runner.lives = 2
	runner.next_game()
	check(runner.boss, "o décimo é chefão")
	check(runner.time_total > normal_time * 1.2 or runner.time_total >= 60.0, "chefão tem mais tempo (%.0f s)" % runner.time_total)
	while runner.state == "intro":
		await process_frame
	runner.game.speed = 60.0
	runner.state = "running"
	var solution: Dictionary = runner.game.solution()
	var won: bool = await runner.game.execute(solution["actions"], solution["output"])
	check(won, "chefão tem solução")
	runner._win()
	var frames := 0
	while runner.state != "intro" and frames < 2000:
		await process_frame
		frames += 1
	check(runner.lives == 3 and runner.score == 1, "vencer o chefão devolve uma vida (%d vidas)" % runner.lives)
	check(not runner.boss, "depois do chefão volta ao normal")
	runner.queue_free()
	await process_frame


## Como o jogador faz: o editor já abre com uma linha vazia; soltar as runas
## da solução nas casas dessa linha, acertar as intensidades e confirmar.
func _play_by_dropping(path: String, start_level: int) -> void:
	WareRunner.practice_game = path
	WareRunner.practice_level = start_level
	var runner = (load("res://scenes/ware/Ware.tscn") as PackedScene).instantiate()
	root.add_child(runner)
	await process_frame
	var name := path.get_file()
	while runner.state == "intro":
		await process_frame
	runner.game.speed = 60.0
	runner.open_editor()
	while runner._busy:
		await process_frame
	var creation = runner._creation
	var canvas = creation.canvas
	var program: Array = runner.game.solution_program()
	check(canvas.connections.size() == clampi(program.size() + 3, 6, 15), "%s: editor abre com a linha pronta (%d casas)" % [name, canvas.connections.size()])
	# Solta de três jeitos: no meio do quadradinho, na borda de fora dele (longe
	# do traço) e em cima da linha. Os três caem na casa certa.
	for index in range(program.size()):
		var cell: Dictionary = canvas.connections[index]
		var middle: Vector2 = canvas._world_to_screen((Vector2(cell["from"]) + Vector2(cell["to"])) * 0.5)
		var slot: Vector2 = canvas._symbol_position(cell, index)
		var at := middle
		if index % 3 == 0:
			at = slot
		elif index % 3 == 1:
			at = slot + (slot - middle).normalized() * 11.0 * canvas.zoom
		if index % 3 == 0 and index < program.size() - 1:
			# Arrasto de verdade: pega na paleta e solta pelo evento do mouse.
			creation._begin_rune_drag(str(program[index]["kind"]))
			var motion := InputEventMouseMotion.new()
			motion.position = canvas.get_global_transform_with_canvas() * at
			creation._input(motion)
			check(creation.drop_target() == index, "%s: quadradinho %d acende ao arrastar por cima (%d)" % [name, index, creation.drop_target()])
			var release := InputEventMouseButton.new()
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			release.position = motion.position
			creation._input(release)
			check(str(canvas.connections[index].get("symbol", "")) == str(program[index]["kind"]), "%s: soltar no quadradinho %d põe a runa" % [name, index])
		else:
			check(canvas.drop_symbol_at(at, str(program[index]["kind"])), "%s: solta %s na casa %d" % [name, program[index]["kind"], index])
			check(str(canvas.connections[index].get("symbol", "")) == str(program[index]["kind"]), "%s: a runa %d caiu na casa certa" % [name, index])
		canvas.set_rune_intensity(index, int(program[index]["intensity"]), false)
	var far: Vector2 = canvas._symbol_position(canvas.connections[0], 0)
	far += (far - canvas._world_to_screen((Vector2(canvas.connections[0]["from"]) + Vector2(canvas.connections[0]["to"])) * 0.5)).normalized() * 90.0 * canvas.zoom
	check(canvas.drop_target_at(far) < 0 or canvas.drop_target_at(far) >= program.size(), "%s: longe da linha não pega casa da solução" % name)
	await process_frame
	await process_frame
	check(bool(creation._preview.get("ok", false)), "%s: ritual solto na linha compila (%s)" % [name, creation._preview.get("error", "")])
	creation._on_confirm()
	var frames := 0
	while runner.state != "result" and frames < 3000:
		await process_frame
		frames += 1
	check(runner.score == 1, "%s: ritual montado soltando runas vence (%s)" % [name, runner.game.fail_reason])
	runner.queue_free()
	WareRunner.practice_game = ""
	await process_frame


## Mover uma runa já colocada: arrastar o ícone e soltar no quadradinho de
## outra casa (fora do traço) leva a runa para lá.
func _move_rune_to_slot() -> void:
	WareRunner.practice_game = "res://scripts/ware/games/maze.gd"
	WareRunner.practice_level = 1
	var runner = (load("res://scenes/ware/Ware.tscn") as PackedScene).instantiate()
	root.add_child(runner)
	await process_frame
	while runner.state == "intro":
		await process_frame
	runner.open_editor()
	while runner._busy:
		await process_frame
	var creation = runner._creation
	var canvas = creation.canvas
	check(canvas.snap_drops_to_slots, "modo ware aceita soltar no quadradinho")
	canvas.drop_symbol_at(canvas._symbol_position(canvas.connections[0], 0), "MOVE_UP")
	await process_frame
	var from: Vector2 = canvas._symbol_position(canvas.connections[0], 0)
	var target := 3
	var middle: Vector2 = canvas._world_to_screen((Vector2(canvas.connections[target]["from"]) + Vector2(canvas.connections[target]["to"])) * 0.5)
	var to: Vector2 = canvas._symbol_position(canvas.connections[target], target)
	to += (to - middle).normalized() * 10.0 * canvas.zoom
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	canvas._gui_input(press)
	await process_frame
	for step in range(1, 11):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, step / 10.0)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		canvas._gui_input(motion)
		await process_frame
	check(creation.drop_target() == target, "arrastando a runa, o quadradinho de destino acende (%d)" % creation.drop_target())
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	canvas._gui_input(release)
	await process_frame
	check(str(canvas.connections[target].get("symbol", "")) == "MOVE_UP" and str(canvas.connections[0].get("symbol", "")).is_empty(), "soltar no quadradinho de outra casa move a runa")
	runner.queue_free()
	WareRunner.practice_game = ""
	await process_frame


## Laço sem fim (pular reto para cima para sempre): PARAR recomeça o mesmo
## desafio com o desenho intacto; na sequência o relógio volta a andar depois
## de alguns segundos de ritual. Runa de fora da paleta não passa.
func _loop_and_stop() -> void:
	WareRunner.practice_game = "res://scripts/ware/games/jump_knight.gd"
	WareRunner.practice_level = 1
	var runner = (load("res://scenes/ware/Ware.tscn") as PackedScene).instantiate()
	root.add_child(runner)
	await process_frame
	while runner.state == "intro":
		await process_frame
	runner.open_editor()
	while runner._busy:
		await process_frame
	var creation = runner._creation
	var canvas = creation.canvas
	var g: float = canvas.GRID_SPACING
	var foreign := [{"kind": "BELL", "intensity": 1}]
	var foreign_cells: Array = []
	for cell in cells(foreign):
		cell["from"] = cell["from"] * g
		cell["to"] = cell["to"] * g
		foreign_cells.append(cell)
	canvas.load_connections(foreign_cells, Vector2(300, 360), 1.0)
	await process_frame
	await process_frame
	check(not bool(creation._preview.get("ok", true)) and str(creation._preview.get("error", "")).contains("não vale"), "runa de fora da paleta é recusada (%s)" % creation._preview)
	var loop := [{"kind": "WARP_ENDPOINT", "intensity": 1}, {"kind": "JUMP", "intensity": 90}, {"kind": "WARP", "intensity": 1}]
	var drawn: Array = []
	for cell in cells(loop):
		cell["from"] = cell["from"] * g
		cell["to"] = cell["to"] * g
		drawn.append(cell)
	canvas.load_connections(drawn, Vector2(300, 360), 1.0)
	await process_frame
	await process_frame
	var old_game = runner.game
	var seed_before: int = runner._game_seed
	creation._on_confirm()
	while runner.state != "running":
		await process_frame
	await create_timer(0.5).timeout
	check(runner.state == "running" and runner._program_button.text == "PARAR", "laço sem fim continua rodando e o botão vira PARAR")
	runner._on_program_button()
	check(runner.state == "result", "PARAR interrompe o ritual")
	while runner.state == "result":
		await process_frame
	check(runner.state == "play" and runner.game != old_game and runner._game_seed == seed_before, "PARAR recomeça o mesmo desafio")
	runner.open_editor()
	while runner._busy:
		await process_frame
	check(canvas.connections.size() == 3 and str(canvas.connections[1]["symbol"]) == "JUMP", "o desenho continua no editor depois do PARAR")
	creation._clear.pressed.emit()
	check(canvas.diagram.undo_history.size() > 0, "LIMPAR pode ser desfeito (Ctrl+Z)")
	var empty_line: bool = canvas.connections.size() == clampi(runner.game.solution_program().size() + 3, 6, 15)
	for connection in canvas.connections:
		empty_line = empty_line and str(connection.get("symbol", "")).is_empty()
	check(creation._clear.visible and empty_line, "LIMPAR volta para a linha vazia")
	# Digitar números muda a intensidade da runa selecionada (a recém-solta).
	var first: Dictionary = canvas.connections[0]
	canvas.drop_symbol_at(canvas._world_to_screen((Vector2(first["from"]) + Vector2(first["to"])) * 0.5), "JUMP")
	await process_frame
	await process_frame
	for code in [KEY_4, KEY_5]:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = true
		creation._input(key)
	check(canvas.rune_intensity(0) == 45, "digitar 4 e 5 deixa a runa com 45 (%d)" % canvas.rune_intensity(0))
	var nine := InputEventKey.new()
	nine.keycode = KEY_9
	nine.pressed = true
	creation._input(nine)
	check(canvas.rune_intensity(0) == 9, "terceiro dígito que passa do máximo recomeça o número (%d)" % canvas.rune_intensity(0))
	runner.queue_free()
	await process_frame
	# Sequência: depois da folga o relógio anda mesmo com o ritual rodando.
	WareRunner.practice_game = ""
	runner = (load("res://scenes/ware/Ware.tscn") as PackedScene).instantiate()
	root.add_child(runner)
	await process_frame
	while runner.state == "intro":
		await process_frame
	runner.state = "running"
	runner._running_time = WareRunner.RUN_GRACE + 1.0
	runner.time_left = 0.2
	var frames := 0
	while runner.state == "running" and frames < 600:
		await process_frame
		frames += 1
	check(runner.state == "result" and runner.lives == WareRunner.START_LIVES - 1, "ritual longo demais deixa o tempo acabar")
	runner.queue_free()
	await process_frame
