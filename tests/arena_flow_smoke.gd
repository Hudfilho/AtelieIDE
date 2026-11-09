extends SceneTree

## Fluxo do modo jogo: VM mágica, regras do feitiço, NASM recusando, arena,
## criação (desenhar + confirmar), orbe na estande, lançar e matar esqueletos.

const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")
const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const Nasm = preload("res://scripts/core/rune_nasm_exporter.gd")
const SpellRules = preload("res://scripts/arena/spell_rules.gd")
const RuneIcons = preload("res://scripts/arena/rune_icons.gd")
const Rarity = preload("res://scripts/arena/rarity.gd")

var failures := 0


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FALHOU: ", label)


func cell(x: int, kind: String, intensity: int) -> Dictionary:
	return {"from": Vector2(x, 0), "to": Vector2(x + 1, 0), "symbol": kind, "intensity": intensity}


func _initialize() -> void:
	# --- linguagem
	check(RuneCatalog.SYMBOLS.size() == 30, "Sandbox continua com 30 runas")
	check(RuneCatalog.opcode_for_kind("FIRE") == 0x1f, "FIRE tem opcode")
	var ritual := [cell(0, "FIRE", 30), cell(1, "INT_MOD", 0), cell(2, "PLUS", 3), cell(3, "EXPLOSION", 20), cell(4, "ORB", 7), cell(5, "TRIANGLE", 0)]
	var compiled: Dictionary = RuneCompiler.new().compile(ritual)
	check(bool(compiled["ok"]), "ritual mágico compila: %s" % [compiled.get("errors")])
	var run: Dictionary = RuneVM.new().run(compiled["bytecode"])
	check(bool(run["ok"]), "ritual roda: %s" % [run.get("errors")])
	var magic: Array = run["magic"]
	check(magic.size() == 2, "duas propriedades mágicas")
	check(magic[0]["kind"] == "FIRE" and int(magic[1]["intensity"]) == 60, "INT_MOD MUL 3 vale para a explosão (20 -> 60): %s" % [magic])
	check(run["output"] == ["7"], "pilha numérica isolada: %s" % [run["output"]])
	var spell := SpellRules.build(magic)
	check(spell["effects"].size() == 1 and int(spell["effects"][0]["damage"]) == 90, "dano = explosão + fogo")
	check(spell["color"] == SpellRules.COLOR_FIRE, "orbe vermelha com fogo")
	var nasm: Dictionary = Nasm.new().generate(ritual)
	check(not bool(nasm["ok"]) and str(nasm["errors"][0]).contains("modo jogo"), "NASM recusa runa mágica")
	# APLICAR: 10 x 6 calculado na pilha vira a intensidade da explosão desenhada com 0.
	var apply_ritual := [cell(0, "ORB", 10), cell(1, "ORB", 6), cell(2, "PLUS", 0), cell(3, "INT_APPLY", 0), cell(4, "EXPLOSION", 0)]
	var apply_run: Dictionary = RuneVM.new().run(RuneCompiler.new().compile(apply_ritual)["bytecode"])
	check(bool(apply_run["ok"]) and int(apply_run["magic"][0]["intensity"]) == 60, "APLICAR põe 60 na explosão: %s" % [apply_run])
	check((apply_run["stack"] as Array).is_empty(), "APLICAR consome o topo")
	var clamp_run: Dictionary = RuneVM.new().run(RuneCompiler.new().compile([cell(0, "ORB", 200), cell(1, "TWIN", 0), cell(2, "PLUS", 0), cell(3, "INT_APPLY", 0), cell(4, "EXPLOSION", 0)])["bytecode"])
	check(int(clamp_run["magic"][0]["intensity"]) == 255, "APLICAR limita a 255")
	var no_target: Dictionary = RuneCompiler.new().compile([cell(0, "ORB", 5), cell(1, "INT_APPLY", 0)])
	check(not bool(no_target["ok"]) and no_target["diagnostics"][0]["code"] == "COMPILER_INT_APPLY_NO_TARGET", "APLICAR sem alvo é erro de compilação")
	var empty_run: Dictionary = RuneVM.new().run(RuneCompiler.new().compile([cell(0, "INT_APPLY", 0), cell(1, "EXPLOSION", 9)])["bytecode"])
	check(not bool(empty_run["ok"]), "APLICAR com pilha vazia é erro")
	check(not bool(Nasm.new().generate(apply_ritual)["ok"]), "NASM recusa APLICAR")
	# Laço: a explosão executa 3 vezes por causa do salto.
	var loop := [cell(0, "ORB", 3), cell(1, "ORB", 0), cell(2, "WARP_ENDPOINT", 1), cell(3, "CUP", 0), cell(4, "EXPLOSION", 5), cell(5, "ORB", 1), cell(6, "MOON", 0), cell(7, "TWIN", 0), cell(8, "ORB", 0), cell(9, "GT", 0), cell(10, "JUMP_IF_TRUE", 1)]
	var loop_run: Dictionary = RuneVM.new().run(RuneCompiler.new().compile(loop)["bytecode"])
	check(loop_run["magic"].size() == 3, "runa mágica em laço executa 3x: %d" % loop_run["magic"].size())
	for kind in ["FIRE", "PROJECTILE", "EXPLOSION", "ORB", "INT_APPLY", "TWIN", "WARP"]:
		var icon := RuneIcons.icon(kind)
		check(icon != null and icon.get_width() == 16, "ícone pixel de " + kind)
	var lit := 0
	var image := RuneIcons.icon("ORB").get_image()
	for y in range(16):
		for x in range(16):
			if image.get_pixel(x, y).a > 0.5:
				lit += 1
	check(lit > 10 and lit < 200, "glifo pixelizado do atlas tem traço (%d px)" % lit)

	# --- linguagem do jogo nova
	var dup_run: Dictionary = RuneVM.new().run(RuneCompiler.new().compile([cell(0, "DUPLICATE", 0), cell(1, "EXPLOSION", 5)])["bytecode"])
	check(dup_run["magic"].size() == 2, "DUPLICAR repete a explosão: %s" % [dup_run["magic"]])
	var dup_stack: Dictionary = RuneVM.new().run(RuneCompiler.new().compile([cell(0, "ORB", 3), cell(1, "DUPLICATE", 0), cell(2, "TWIN", 0)])["bytecode"])
	check(dup_stack["stack"] == [3, 3, 3], "DUPLICAR repete Copiar: %s" % [dup_stack["stack"]])
	var ice_spell := SpellRules.build([{"kind": "ICE", "intensity": 60}, {"kind": "EXPLOSION", "intensity": 20}])
	check(ice_spell["color"] == SpellRules.COLOR_ICE and float(ice_spell["effects"][0]["freeze"]) >= 2.0 and int(ice_spell["effects"][0]["damage"]) == 50, "gelo congela e soma metade: %s" % [ice_spell])
	var bolt_spell := SpellRules.build([{"kind": "LIGHTNING", "intensity": 100}, {"kind": "EXPLOSION", "intensity": 20}])
	check(float(bolt_spell["effects"][0]["stun"]) > 0.0 and float(bolt_spell["effects"][0]["radius"]) > 42.0 * 1.4, "raio atordoa e cresce")
	# Portal frágil: comum quebra depois de 2 saltos (3 explosões), raro depois de 3.
	var fragile := [cell(0, "WARP_ENDPOINT", 1), cell(1, "EXPLOSION", 5), cell(2, "WARP_FRAGILE", 1)]
	var fragile_compiled: Dictionary = RuneCompiler.new().compile(fragile)
	check(bool(fragile_compiled["ok"]), "portal frágil compila: %s" % [fragile_compiled.get("errors")])
	var fragile_run: Dictionary = RuneVM.new().run_program(fragile_compiled["instructions"])
	check(fragile_run["magic"].size() == 3, "portal frágil comum: 2 saltos (%d explosões)" % fragile_run["magic"].size())
	var rare_fragile := fragile.duplicate(true)
	rare_fragile[2]["rarity"] = 1
	var rare_run: Dictionary = RuneVM.new().run_program(RuneCompiler.new().compile(rare_fragile)["instructions"])
	check(rare_run["magic"].size() == 4, "portal frágil raro: 3 saltos (%d explosões)" % rare_run["magic"].size())
	check(not bool(Nasm.new().generate(fragile)["ok"]), "NASM recusa portal frágil")
	var normal_warp_loop: Dictionary = RuneVM.new().run(RuneCompiler.new().compile([cell(0, "ORB", 2), cell(1, "WARP", 1), cell(2, "ORB", 9), cell(3, "WARP_ENDPOINT", 1), cell(4, "TRIANGLE", 0)])["bytecode"])
	check(normal_warp_loop["output"] == ["2"], "WARP normal do Sandbox continua igual: %s" % [normal_warp_loop["output"]])
	# Raridade multiplica a intensidade das mágicas (não a do projétil).
	var epic := SpellRules.build([{"kind": "EXPLOSION", "intensity": 20, "rarity": 2}, {"kind": "PROJECTILE", "intensity": 20, "rarity": 3}])
	check(int(epic["effects"][0]["damage"]) == 40, "explosão épica x2")
	check(is_equal_approx(float(epic["effects"][1]["distance"]), SpellRules.MOVE_BASE + 20 * SpellRules.MOVE_PER_INTENSITY), "projétil ignora raridade")
	var Creation = load("res://scripts/arena/spell_creation.gd")
	check(Creation.palette_keys({"EXPLOSION#2": 1, "EXPLOSION": 1, "FIRE": 1}) == ["FIRE", "EXPLOSION", "EXPLOSION#2"], "ordem da paleta por tipo e raridade")
	check(Creation.display_name("EXPLOSION#3") == "Explosão (Lendária)", "nome com raridade")
	check(Creation.GAME_RUNES.size() >= 30, "runas do jogo: %d" % Creation.GAME_RUNES.size())
	for kind in Creation.GAME_RUNES:
		check(RuneIcons.icon(kind) != null, "ícone de " + kind)
		check(Creation.RUNE_NAMES.has(kind), "nome de " + kind)
		check(RuneCatalog.opcode_for_kind(kind) >= 0, "opcode de " + kind)
		for bad in ["—", ";", "=", "<", ">"]:
			check(not str(Creation.RUNE_NAMES.get(kind, "")).contains(bad), "nome de %s sem '%s'" % [kind, bad])
	var Skeleton = load("res://scripts/arena/skeleton.gd")
	Skeleton._ensure_frames()
	check(Skeleton._walk_frames.size() == 4 and Skeleton._walk_frames[0].get_image().get_data() != Skeleton._walk_frames[2].get_image().get_data(), "4 quadros de caminhada diferentes")

	var SpellBall = load("res://scripts/arena/spell_ball.gd")
	check(SpellBall.ball_frame(Color("e8452c"), 0, 0).get_image().get_data() != SpellBall.ball_frame(Color("e8452c"), 0, 1).get_image().get_data(), "bolinha gira")

	# --- arena: sala 1
	var arena: Node = load("res://scenes/arena/Arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var hud = arena.hud
	check(arena._alive_enemies().size() == arena.skeleton_count(1), "esqueletos da sala 1")
	check(arena.inventory["EXPLOSION"] == 4 and arena.inventory["WARP_FRAGILE"] == 2 and arena.inventory["ORB"] == arena.UNLIMITED, "bolsa inicial")
	check(SpellRules.count_effects(hud._slots[1].spell, "explode") == 3, "orbe inicial é uma corrente de 3 explosões")
	check(hud._slots[1].spell != null, "orbe inicial pronta na estande")
	# Sala 1 dá para vencer: a Explosão padrão (20) mata um esqueleto da sala 1.
	var default_blast := SpellRules.build([{"kind": "EXPLOSION", "intensity": 20}])
	check(int(default_blast["effects"][0]["damage"]) >= arena.skeleton_hp(1), "explosão padrão mata na sala 1")
	# Várias explosões com poucas runas: Fim de portal, Projétil, Explosão, Portal frágil.
	var chain := [cell(0, "WARP_ENDPOINT", 1), cell(1, "PROJECTILE", 30), cell(2, "EXPLOSION", 20), cell(3, "WARP_FRAGILE", 1)]
	var chain_spell := SpellRules.build(RuneVM.new().run_program(RuneCompiler.new().compile(chain)["instructions"])["magic"])
	check(SpellRules.count_effects(chain_spell, "explode") == 3 and int(chain_spell["cost"]) == 75, "corrente: 3 explosões por 75 de mana (%s)" % [chain_spell["cost"]])
	check(arena.max_mana >= int(chain_spell["cost"]) * 2, "dá para lançar a corrente pelo menos 2 vezes na sala 1")
	check(arena.skeleton_count(1) >= 5, "sala 1 com grupo grande")
	await create_timer(0.8).timeout # nascem da terra
	arena.inventory["EXPLOSION#1"] = 1
	arena.open_creation(0, hud.orb_center(0))
	while arena._busy:
		await process_frame
	var creation = arena._creation
	var canvas = creation.canvas
	check(canvas.pixel_hud, "editor em pixel_hud")
	var g: float = canvas.GRID_SPACING
	var grid_cell := func(i: int) -> Dictionary: return {"from": Vector2(i, 0) * g, "to": Vector2(i + 1, 0) * g, "symbol": "", "intensity": 0}
	canvas.load_connections([grid_cell.call(0), grid_cell.call(1), grid_cell.call(2), grid_cell.call(3)], Vector2(400, 360), 1.0)
	await process_frame
	var mid := func(i: int) -> Vector2: return canvas._world_to_screen(Vector2(i + 0.5, 0) * g)
	check(canvas.drop_symbol_at(mid.call(0), "FIRE"), "solta FOGO")
	check(canvas.drop_symbol_at(mid.call(2), "EXPLOSION", 1), "solta EXPLOSÃO rara")
	check(canvas.rune_rarity(2) == 1, "célula guarda a raridade")
	await process_frame
	check(creation._available("EXPLOSION#1") == 0 and creation._available("EXPLOSION") == 4, "rara sai da pilha rara")
	check(creation._palette.kinds.has("EXPLOSION#1"), "paleta mostra a pilha rara")
	canvas.set_rune_intensity(2, 40, true)
	await process_frame
	check(creation._available("FIRE") == 1, "FOGO no desenho sai da bolsa")
	check(creation._available("ORB") == creation.UNLIMITED_DISPLAY, "runa de lógica é infinita")
	arena.inventory["PROJECTILE"] = 0
	creation._begin_rune_drag("PROJECTILE")
	check(creation._drag_kind == "", "não arrasta runa que acabou")
	arena.inventory["PROJECTILE"] = 4
	check(creation._cost == 30, "custo por execução: fogo 20/2 + explosão 40/2 = 30 (%d)" % creation._cost)
	check(SpellRules.summary(creation._preview["spell"]) == "1 explosão", "prévia: %s" % SpellRules.summary(creation._preview["spell"]))
	creation._on_confirm()
	while arena._busy or arena._creating:
		await process_frame
	check(arena.mana == arena.max_mana - 30, "mana gasta: %d" % arena.mana)
	check(arena.inventory["FIRE"] == 1 and arena.inventory["EXPLOSION"] == 4 and arena.inventory["EXPLOSION#1"] == 0, "runas mágicas gastas: %s" % [arena.inventory])
	check(canvas.connections.size() == 4 and canvas.connections.all(func(c): return str(c["symbol"]) == ""), "desenho fica só com as linhas")
	check(hud._slots[2].spell != null and hud._slots[2].spell["runes"] == {"FIRE": 1, "EXPLOSION#1": 1}, "orbe nova guarda as runas mágicas: %s" % [hud._slots[2].spell.get("runes")])
	check(int(hud._slots[2].spell["effects"][0]["damage"]) == 80, "rara: 40 x1,5 + fogo 20 = 80 (%s)" % [hud._slots[2].spell["effects"][0]["damage"]])
	# A prévia da criação conta as explosões de uma corrente desenhada.
	arena.open_creation(0, hud.orb_center(0))
	while arena._busy:
		await process_frame
	var chain_cells: Array = []
	for i in range(4):
		var chain_cell: Dictionary = grid_cell.call(i)
		chain_cell["symbol"] = ["WARP_ENDPOINT", "PROJECTILE", "EXPLOSION", "WARP_FRAGILE"][i]
		chain_cell["intensity"] = [1, 30, 20, 1][i]
		chain_cells.append(chain_cell)
	canvas.load_connections(chain_cells, Vector2(400, 360), 1.0)
	await process_frame
	await process_frame
	check(bool(creation._preview.get("ok", false)) and SpellRules.summary(creation._preview["spell"]) == "3 explosões, 3 projéteis", "prévia da corrente: %s" % [creation._preview])
	check(int(creation._preview["cost"]) == 75, "prévia do custo da corrente")
	creation.close_requested.emit()
	while arena._busy or arena._creating:
		await process_frame
	# Lança em cima de um esqueleto.
	# Esqueletos parados (só eles: a bolinha fica no mesmo nó e precisa rodar).
	for enemy in arena._alive_enemies():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var target: Node2D = arena._alive_enemies()[0]
	var ready_spell: Dictionary = hud._slots[2].spell
	hud._slots[2].set_spell(null)
	arena._cast(ready_spell, target.position, Vector2.ZERO)
	await create_timer(0.6).timeout
	check(is_instance_valid(target) and target.alive, "não ativou antes de 1 s")
	var balls: Array = arena.creatures.get_children().filter(func(c): return c.has_method("land"))
	check(balls.size() == 1 and balls[0]._rolling, "bolinha rolando entre os esqueletos (y-sort)")
	await create_timer(1.2).timeout
	check(not is_instance_valid(target) or not target.alive, "esqueleto atingido morreu")
	check(arena.spent_this_room.get("EXPLOSION#1", 0) == 1, "lançamento conta para o reembolso")
	var debris: Array = arena.creatures.get_children().filter(func(c): return c.get_script() != null and c.get_script().resource_path.ends_with("bone_debris.gd"))
	check(not debris.is_empty(), "ossos espalhados")

	# --- sala limpa -> recompensa -> sala 2
	for enemy in arena._alive_enemies():
		enemy.take_damage(999)
	arena._check_room_cleared()
	await create_timer(1.7).timeout
	var screens: Array = arena._overlay_layer.get_children()
	check(screens.size() == 1 and screens[0].offers.size() == 3, "tela de recompensa com 3 ofertas")
	var view_size: Vector2 = arena.get_viewport().get_visible_rect().size
	check(screens[0].size == view_size, "tela de recompensa ocupa a tela toda: %s de %s" % [screens[0].size, view_size])
	screens[0]._layout_cards()
	for card in screens[0]._cards:
		check(Rect2(Vector2.ZERO, view_size).encloses(card), "cartão dentro da tela: %s" % [card])
	check(arena._transition.size == view_size, "transição ocupa a tela toda")
	var kinds := {}
	for offer in screens[0].offers:
		kinds[offer["kind"]] = true
	check(kinds.size() == 3, "ofertas diferentes")
	check(arena.inventory["EXPLOSION"] == 5, "+1 Explosão de bônus (4 + 1): %d" % arena.inventory["EXPLOSION"])
	for offer_entry in screens[0].offers:
		var offered: String = offer_entry["kind"]
		if offered == arena.MANA_OFFER:
			continue
		check(arena.is_consumable(offered) == (int(offer_entry["amount"]) > 0), "mágica vem em quantidade, lógica vem como nova: " + offered)
		check(arena.is_consumable(offered) or not arena.inventory.has(offered), "não oferece lógica já liberada: " + offered)
		check(int(offer_entry["rarity"]) == 0 or Rarity.has_rarity(Rarity.kind_of(offered)), "raridade só em runa que tem: " + offered)
	var offer: Dictionary = screens[0].offers[0]
	var before := int(arena.inventory.get(offer["kind"], 0))
	screens[0].picked.emit(offer["kind"], offer["amount"])
	await process_frame
	if offer["kind"] == arena.MANA_OFFER:
		check(arena.bonus_mana == arena.MANA_OFFER_AMOUNT, "mana máxima extra")
	elif int(offer["amount"]) > 0:
		check(int(arena.inventory[offer["kind"]]) == before + int(offer["amount"]), "runa escolhida entra na bolsa")
	else:
		check(int(arena.inventory[offer["kind"]]) == arena.UNLIMITED, "runa de lógica liberada")
	check(arena.room == 2 and arena.mana == arena.max_mana and arena.max_mana == arena.BASE_MANA + arena.MANA_PER_ROOM + arena.bonus_mana, "sala 2 com mana cheia")
	check(arena._alive_enemies().size() == arena.skeleton_count(2), "mais esqueletos na sala 2")
	check(arena._alive_enemies()[0].max_hp == arena.skeleton_hp(2), "esqueletos mais fortes")

	# --- sem magias
	for rune_key in arena.inventory.keys():
		if Rarity.kind_of(rune_key) == "EXPLOSION":
			arena.inventory[rune_key] = 0
	arena._check_out_of_magic()
	check(not arena._game_over, "com orbe na estande ainda não perdeu")
	hud.set_spell(1, null)
	arena._check_out_of_magic()
	var over_screens: Array = arena._overlay_layer.get_children().filter(func(c): return c.get("room") != null)
	check(over_screens.size() == 1 and over_screens[0].size == view_size, "tela de fim ocupa a tela toda")
	check(arena._game_over, "sem Explosão e sem orbe: fim de jogo")

	# Efeitos de gelo e raio carregam.
	for element in ["ice", "lightning", "fire", ""]:
		var blast = load("res://scripts/arena/explosion.gd").new()
		blast.element = element
		blast.freeze = 1.0
		root.add_child(blast)
		check(blast.get_child_count() == 1, "explosão de " + element)

	# Mesa pixel: desenha sem erro com linhas retas e diagonais.
	canvas.queue_redraw()
	await process_frame
	check(canvas._px_unit() == 2.0, "unidade pixel = 2 px no zoom 1")
	if failures == 0:
		print("ARENA_FLOW_OK")
	quit(1 if failures > 0 else 0)
