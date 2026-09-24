extends SceneTree

## Cadeia de consequências pelo GameState, sem UI: decisões agendam efeitos,
## as manhãs os aplicam e as flags escolhem a versão de cada cliente.

var game_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _order(order_id: String) -> AtelierScrollOrder:
	return load("res://data/orders/%s.tres" % order_id) as AtelierScrollOrder


func _slot(day: AtelierShopDay, order_id: String) -> AtelierScrollOrder:
	for slot in day.orders:
		if slot.id == order_id:
			return slot
	assert(false, "Day has no slot %s" % order_id)
	return null


func _ledger_has(text: String) -> bool:
	for entry in game_state.ledger:
		if text in str(entry["text"]):
			return true
	return false


func _run() -> void:
	game_state = root.get_node("GameState")
	var fireball := _order("anderdingus_fireball")
	var day_3 := load("res://data/days/day_03.tres") as AtelierShopDay
	var goblin_slot := _slot(day_3, "anderdingus_hush")
	var inspector_slot := _slot(day_3, "guild_inspector_routine")

	# Aprovar e entregar o Fireball agenda a consequência para a manhã seguinte.
	game_state.new_game()
	game_state.deliver(fireball, false)
	assert(game_state.outcomes["anderdingus_fireball"] == "delivered")
	assert(game_state.scheduled.size() == 1)
	var entry: Dictionary = game_state.scheduled[0]
	assert(int(entry["due_day"]) == 1 and entry["source_id"] == "anderdingus_fireball")
	assert(game_state.flag("guild_suspicion") == 0, "The consequence should wait for the morning")

	# Dia 2: jornal, multa e suspeita chegam juntos.
	var money_before: int = game_state.money
	var reputation_before: int = game_state.reputation
	var headlines: PackedStringArray = game_state.begin_next_day()
	assert(headlines.size() == 1 and "NORTHERN CAVES" in headlines[0], str(headlines))
	assert(game_state.money == money_before - 15)
	assert(game_state.reputation == reputation_before - 4)
	assert(game_state.flag("guild_suspicion") == 2 and game_state.flag("goblin_armed") == 1)
	assert(_ledger_has("Guild fine: the Millbrook fire"))
	assert(game_state.scheduled.is_empty())

	# Dia 3: o goblin volta armado e o inspetor vem auditar.
	game_state.begin_next_day()
	assert(game_state.current_day() == day_3)
	assert(game_state.resolve_customer(goblin_slot).id == "anderdingus_bigger_fireball")
	assert(game_state.resolve_customer(inspector_slot).id == "guild_inspector_audit")

	# Recusar o Fireball não dispara a cadeia.
	game_state.new_game()
	money_before = game_state.money
	game_state.reject(fireball)
	assert(game_state.outcomes["anderdingus_fireball"] == "rejected")
	assert(game_state.scheduled.is_empty())
	assert(game_state.flag("goblin_refused") == 1, "Refusal is remembered right away")
	headlines = game_state.begin_next_day()
	assert(headlines.is_empty())
	assert(game_state.money == money_before)
	assert(game_state.flag("guild_suspicion") == 0 and game_state.flag("goblin_armed") == 0)
	game_state.begin_next_day()
	assert(game_state.resolve_customer(goblin_slot).id == "anderdingus_hush")
	assert(game_state.resolve_customer(inspector_slot).id == "guild_inspector_routine")

	# Desistir do Fireball: nenhuma flag do goblin, então ele não volta.
	game_state.new_game()
	game_state.abandon(fireball)
	assert(game_state.resolve_customer(goblin_slot) == null)

	# O inspetor sempre vem; a variante depende só de guild_suspicion.
	assert(AtelierShopDay.resolve_customer(inspector_slot, {}).id == "guild_inspector_routine")
	assert(AtelierShopDay.resolve_customer(inspector_slot, {"guild_suspicion": 1}).id == "guild_inspector_routine")
	assert(AtelierShopDay.resolve_customer(inspector_slot, {"guild_suspicion": 2}).id == "guild_inspector_audit")
	assert(AtelierShopDay.resolve_customer(inspector_slot, {"guild_suspicion": 7}).id == "guild_inspector_audit")

	# Consequência imediata: vender magia proibida vira o inspetor no mesmo dia.
	game_state.new_game()
	game_state.day_index = 2
	assert(game_state.resolve_customer(inspector_slot).id == "guild_inspector_routine")
	game_state.deliver(_order("osric_gentle_forgetting"), false)
	assert(game_state.flag("guild_suspicion") == 2)
	assert(game_state.resolve_customer(inspector_slot).id == "guild_inspector_audit")
	assert(game_state.scheduled.size() == 1, "The fine still waits for the newspaper")
	assert("MERCHANT'S MEMORY STOLEN" in game_state.upcoming_headlines()[0])

	# Passar na auditoria alivia a suspeita na hora e deixa a manchete para amanhã.
	game_state.deliver(_order("guild_inspector_audit"), false)
	assert(game_state.flag("guild_suspicion") == 0)
	assert(_ledger_has("Passed the Guild audit"))
	assert(game_state.upcoming_headlines().size() == 2)

	print("CONSEQUENCE_CHAIN_SMOKE_OK")
	quit(0)
