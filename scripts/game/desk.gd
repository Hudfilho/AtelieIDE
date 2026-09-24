extends Control

## Balcão da loja: o ciclo do dia. Toca o sino, o cliente entrega o pedido,
## o jogador confere com o livro de regras e carimba APROVAR ou RECUSAR.
## Aprovar leva à bancada, onde o pergaminho precisa ser escrito.

enum Phase { DAY_INTRO, WAITING, SERVING, CRAFTING, DAY_END, DEMO_END }

@onready var day_label: Label = %DayLabel
@onready var money_label: Label = %MoneyLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var queue_label: Label = %QueueLabel
@onready var portrait: ColorRect = %Portrait
@onready var portrait_initial: Label = %PortraitInitial
@onready var client_name_label: Label = %ClientName
@onready var speech_label: Label = %Speech
@onready var bell_button: Button = %BellButton
@onready var rules_label: Label = %RulesLabel
@onready var request_form: Control = %RequestForm
@onready var item_label: Label = %ItemLabel
@onready var fields_label: Label = %FieldsLabel
@onready var details_label: Label = %DetailsLabel
@onready var spec_label: Label = %SpecLabel
@onready var approve_button: Button = %ApproveButton
@onready var reject_button: Button = %RejectButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var workbench = %Workbench
@onready var overlay: Control = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_body: RichTextLabel = %OverlayBody
@onready var overlay_button: Button = %OverlayButton

var phase := Phase.DAY_INTRO
var order_index := -1
var current_order: AtelierScrollOrder
var _overlay_action: Callable


func _ready() -> void:
	GameState.changed.connect(_refresh_hud)
	bell_button.pressed.connect(_call_next_client)
	approve_button.pressed.connect(_on_approve)
	reject_button.pressed.connect(_on_reject)
	overlay_button.pressed.connect(func() -> void: _overlay_action.call())
	workbench.delivered.connect(_on_scroll_delivered)
	workbench.abandoned.connect(_on_scroll_abandoned)
	workbench.hide()
	_start_day()


func _day() -> AtelierShopDay:
	return GameState.current_day()


## ======================== DIA ========================

func _start_day() -> void:
	phase = Phase.DAY_INTRO
	order_index = -1
	_clear_counter()
	var day := _day()
	rules_label.text = "\n\n".join(PackedStringArray(day.rules.map(func(rule: AtelierShopRule) -> String: return "- " + rule.text)))
	var body := day.intro
	var headlines := GameState.publish_news()
	if not headlines.is_empty():
		body = "[b]THE MORNING HERALD[/b]\n" + "\n\n".join(headlines) + "\n\n" + body
	body += "\n\n[b]Rulebook[/b]\n" + rules_label.text
	body += "\n\n[b]Runes on your bench[/b]\n" + ", ".join(_rune_labels(day.runes))
	_show_overlay(day.title, body, "Open the shop", _begin_service)
	_refresh_hud()


func _begin_service() -> void:
	overlay.hide()
	phase = Phase.WAITING
	_say_feedback("Ring the bell to call the first client.")
	_refresh_controls()


func _call_next_client() -> void:
	if phase != Phase.WAITING:
		return
	order_index += 1
	if order_index >= _day().orders.size():
		_end_day()
		return
	current_order = _day().orders[order_index]
	phase = Phase.SERVING
	_show_client(current_order)
	_say_feedback("Check the request against the rulebook, then stamp it.")
	_refresh_controls()


func _end_day() -> void:
	phase = Phase.DAY_END
	_clear_counter()
	var lines: PackedStringArray = []
	var earned := 0
	for entry in GameState.ledger:
		earned += int(entry["money"])
		lines.append("%s   [color=#e8c07a]%s[/color]%s" % [entry["text"], _signed(entry["money"], " coins"), _reputation_suffix(entry["reputation"])])
	var body := "\n".join(lines) if not lines.is_empty() else "A quiet day."
	body += "\n\n[b]Today:[/b] %s     [b]Purse:[/b] %d coins     [b]Reputation:[/b] %d" % [_signed(earned, " coins"), GameState.money, GameState.reputation]
	if GameState.has_next_day():
		_show_overlay("%s - Ledger" % _day().title, body, "Sleep until tomorrow", _go_to_next_day)
	else:
		_show_demo_end(body)


func _go_to_next_day() -> void:
	GameState.begin_next_day()
	_start_day()


func _show_demo_end(ledger_body: String) -> void:
	phase = Phase.DEMO_END
	var body := ledger_body
	if not GameState.pending_consequences.is_empty():
		body += "\n\n[b]Tomorrow's Herald will read:[/b]\n" + "\n\n".join(PackedStringArray(GameState.pending_consequences.map(func(order: AtelierScrollOrder) -> String: return order.consequence_news)))
	body += "\n\n[i]Thanks for playing the Atelier demo![/i]"
	_show_overlay("End of the demo", body, "Back to the title", func() -> void: get_tree().change_scene_to_file("res://scenes/game/Title.tscn"))


## ======================== CARIMBOS ========================

func _on_approve() -> void:
	if phase != Phase.SERVING:
		return
	phase = Phase.CRAFTING
	_refresh_controls()
	workbench.open_order(current_order, _day().runes)


func _on_reject() -> void:
	if phase != Phase.SERVING:
		return
	if current_order.is_legal():
		GameState.record("Turned away %s (honest request)" % current_order.client_name, 0, -1)
		_client_leaves("An honest customer leaves disappointed. Your reputation suffers.")
	else:
		GameState.record("Refused %s's %s" % [current_order.client_name, current_order.item], 0, 1)
		_client_leaves("Good call. %s" % _violation_summary(current_order))


func _on_scroll_delivered(result: Dictionary) -> void:
	workbench.hide()
	var bonus := 5 if result["elegant"] else 0
	var note := " (elegant work!)" if bonus > 0 else ""
	GameState.record("Sold %s to %s%s" % [current_order.item, current_order.client_name, note], current_order.reward + bonus, 1 if current_order.is_legal() else 0)
	if not current_order.is_legal():
		GameState.pending_consequences.append(current_order)
		_client_leaves("%s pays and hurries off with the scroll. You have an uneasy feeling..." % current_order.client_name)
	else:
		_client_leaves("%s thanks you and pays %d coins." % [current_order.client_name, current_order.reward + bonus])


func _on_scroll_abandoned() -> void:
	workbench.hide()
	GameState.record("Failed to write %s for %s" % [current_order.item, current_order.client_name], 0, -1)
	_client_leaves("You couldn't write the scroll. %s leaves empty-handed." % current_order.client_name)


func _client_leaves(message: String) -> void:
	phase = Phase.WAITING
	current_order = null
	_clear_counter()
	var remaining := _day().orders.size() - order_index - 1
	_say_feedback(message + ("\nRing the bell for the next client." if remaining > 0 else "\nNo one else is waiting. Ring the bell to close the shop."))
	_refresh_controls()


## ======================== APRESENTAÇÃO ========================

func _show_client(order: AtelierScrollOrder) -> void:
	portrait.color = order.portrait_color
	portrait_initial.text = order.client_name.left(1)
	client_name_label.text = "%s, %s" % [order.client_name, order.race]
	speech_label.text = "\"%s\"" % order.greeting
	item_label.text = order.item
	fields_label.text = "Name:  %s\nAge:  %s\nRace:  %s\nSignature:  %s" % [order.client_name, order.age, order.race, order.signature]
	details_label.text = "Details:\n%s" % order.details
	spec_label.text = "Scroll must: %s" % order.spec.get_slice("\n", 0)
	portrait.show()
	request_form.show()


func _clear_counter() -> void:
	portrait.hide()
	client_name_label.text = "The window is empty."
	speech_label.text = ""
	request_form.hide()


func _refresh_hud() -> void:
	day_label.text = _day().title
	money_label.text = "%d coins" % GameState.money
	reputation_label.text = "Reputation %d" % GameState.reputation
	var waiting := maxi(_day().orders.size() - order_index - 1, 0)
	queue_label.text = "%d waiting outside" % waiting


func _refresh_controls() -> void:
	bell_button.disabled = phase != Phase.WAITING
	approve_button.disabled = phase != Phase.SERVING
	reject_button.disabled = phase != Phase.SERVING
	_refresh_hud()


func _say_feedback(text: String) -> void:
	feedback_label.text = text


func _show_overlay(title: String, body: String, button_text: String, action: Callable) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_button.text = button_text
	_overlay_action = action
	_refresh_controls()
	overlay.show()


func _violation_summary(order: AtelierScrollOrder) -> String:
	var reasons: PackedStringArray = []
	for rule_id in order.violations:
		reasons.append(_day().rule_text(rule_id))
	return "Broken rule: " + " / ".join(reasons)


func _rune_labels(kinds: PackedStringArray) -> PackedStringArray:
	var labels: PackedStringArray = []
	for kind in kinds:
		labels.append(str(AtelierRuneCatalog.symbol_data(kind)["label"]))
	return labels


static func _signed(value: int, unit: String) -> String:
	if value == 0:
		return ""
	return ("+%d" % value if value > 0 else "%d" % value) + unit


static func _reputation_suffix(value: int) -> String:
	if value == 0:
		return ""
	return "   [color=#9fc28a]%s[/color]" % _signed(value, " rep")
