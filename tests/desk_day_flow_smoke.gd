extends SceneTree

## Joga o demo inteiro pelo balcão: recusa e aprova pedidos, escreve pergaminhos
## na bancada e confere dinheiro, reputação e o jornal do dia seguinte.

const SpellJudgeSmoke = preload("res://tests/spell_judge_smoke.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	var desk := load("res://scenes/game/Desk.tscn").instantiate() as Control
	root.add_child(desk)
	await process_frame

	var overlay := desk.get_node("%Overlay") as Control
	var bell := desk.get_node("%BellButton") as Button
	var approve := desk.get_node("%ApproveButton") as Button
	var reject := desk.get_node("%RejectButton") as Button
	var workbench = desk.get_node("%Workbench")
	assert(overlay.visible, "Day intro should open the day")
	assert(bell.disabled)
	desk.get_node("%OverlayButton").pressed.emit()
	assert(not overlay.visible)
	assert(not bell.disabled and approve.disabled)

	# Dia 1, cliente 1 (Mira): aprovar abre a bancada só com as runas do dia.
	bell.pressed.emit()
	assert(not approve.disabled)
	assert((desk.get_node("%ItemLabel") as Label).text == "Scroll of Warm Light")
	approve.pressed.emit()
	await process_frame
	assert(workbench.visible)
	var canvas = workbench.get_node("%Canvas")
	assert(canvas.palette_symbols.size() == 5, "Day 1 bench should show 5 runes")
	assert(canvas.get_node_or_null("FileToolbar") == null, "Game mode hides the IDE file bar")

	# Pergaminho errado: fica na bancada e explica a falha.
	canvas.load_connections(SpellJudgeSmoke._program([["ORB", 4], ["TRIANGLE", 128]]))
	workbench.get_node("%DeliverButton").pressed.emit()
	assert(workbench.visible)
	assert("expected 3, got 4" in (workbench.get_node("%ResultLabel") as Label).text)
	canvas.load_connections(SpellJudgeSmoke._program(SpellJudgeSmoke.SOLUTIONS["Scroll of Warm Light"]))
	workbench.get_node("%DeliverButton").pressed.emit()
	assert(not workbench.visible)
	assert(game_state.money == 20 + 8 + 5, "Reward plus elegant bonus")

	# Cliente 2 (goblin do Fireball): recusar é o certo.
	bell.pressed.emit()
	assert((desk.get_node("%ItemLabel") as Label).text == "Fireball")
	reject.pressed.emit()
	assert(game_state.reputation == 5 + 1 + 1)

	# Cliente 3 (Tomas): desistir custa reputação.
	bell.pressed.emit()
	approve.pressed.emit()
	workbench.get_node("%AbandonButton").pressed.emit()
	assert(not workbench.visible)
	assert(game_state.reputation == 6)

	# Fim do dia 1 → livro-caixa → dia 2.
	bell.pressed.emit()
	assert(overlay.visible)
	assert("Ledger" in (desk.get_node("%OverlayTitle") as Label).text)
	desk.get_node("%OverlayButton").pressed.emit()
	assert(game_state.day_index == 1)
	assert("Embargo" in (desk.get_node("%OverlayTitle") as Label).text)
	desk.get_node("%OverlayButton").pressed.emit()

	# Dia 2: entregar o pedido élfico ilegal gera a notícia de amanhã.
	bell.pressed.emit() # Pip
	reject.pressed.emit()
	bell.pressed.emit() # Faelar (embargo)
	approve.pressed.emit()
	assert(canvas.palette_symbols.size() == 12)
	canvas.load_connections(SpellJudgeSmoke._program(SpellJudgeSmoke.SOLUTIONS["Scroll of Quiet Growth"]))
	workbench.get_node("%DeliverButton").pressed.emit()
	assert(game_state.pending_consequences.size() == 1)
	bell.pressed.emit() # Brom
	reject.pressed.emit()
	bell.pressed.emit() # Oona
	approve.pressed.emit()
	canvas.load_connections(SpellJudgeSmoke._program(SpellJudgeSmoke.SOLUTIONS["Bell of Vespers"]))
	workbench.get_node("%DeliverButton").pressed.emit()
	assert(not workbench.visible, "The countdown loop should pass on the real bench")
	bell.pressed.emit()
	assert(overlay.visible)
	assert((desk.get_node("%OverlayTitle") as Label).text == "End of the demo")
	assert("CROWN FINES" in (desk.get_node("%OverlayBody") as RichTextLabel).text)

	print("desk_day_flow_smoke: demo played through, %d coins, reputation %d" % [game_state.money, game_state.reputation])
	quit(0)
