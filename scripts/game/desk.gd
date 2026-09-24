extends Control

## Balcão da loja: o ciclo do dia. Toca o sino, o cliente entrega o pedido,
## o jogador confere com o livro de regras e carimba APROVAR ou RECUSAR.
## Aprovar leva à bancada, onde o pergaminho precisa ser escrito.
## Só apresentação: pagamento, reputação e consequências ficam no GameState,
## qual versão de cada cliente aparece vem das flags
## (AtelierShopDay.resolve_customer), e se uma ligação campo → regra é prova
## quem decide é a AtelierInspection. Aqui só se repassam os cliques.
## Animação e som ficam no AtelierDeskFeedback (%Feedback): o carimbo só vira
## decisão no impacto (stamp_impact), e o que vem depois espera o carimbo voltar.

enum Phase {
	DAY_INTRO,
	WAITING,
	SERVING,
	## Carimbo descendo: nada decidido ainda, e nenhum clique novo conta.
	STAMPING,
	CRAFTING,
	## Recusa já decidida; a marca e a reação ficam à vista antes de o cliente sair.
	LEAVING,
	DAY_END,
	DEMO_END,
}

## Altura máxima do texto do jornal/livro-caixa antes de passar a rolar.
const OVERLAY_BODY_MAX_HEIGHT := 440.0
## Tinta das provas citadas no formulário e no livro de regras.
const EVIDENCE_INK := Color(0.72, 0.06, 0.04)
const EVIDENCE_MARK := "» "
const CONTRADICTION_FLASH := Color(1.0, 0.45, 0.4)
## Pausas depois que o carimbo volta (segundos): a marca APPROVED antes da
## bancada abrir, e a marca REFUSED com a reação antes do cliente sair.
const APPROVED_HOLD := 0.35
const REFUSED_LINGER := 0.9

@onready var day_label: Label = %DayLabel
@onready var money_label: Label = %MoneyLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var queue_label: Label = %QueueLabel
@onready var portrait: ColorRect = %Portrait
@onready var portrait_initial: Label = %PortraitInitial
@onready var client_name_label: Label = %ClientName
@onready var speech_label: Label = %Speech
@onready var bell_button: Button = %BellButton
@onready var rules_list: VBoxContainer = %RulesList
@onready var request_form: Control = %RequestForm
## Botão de cada campo inspecionável, pelas chaves de AtelierScrollOrder.INSPECTABLE_FIELDS.
@onready var field_buttons: Dictionary[String, Button] = {
	"item": %ItemField, "name": %NameField, "age": %AgeField,
	"race": %RaceField, "signature": %SignatureField, "details": %DetailsField,
}
@onready var spec_label: Label = %SpecLabel
@onready var approve_button: Button = %ApproveButton
@onready var reject_button: Button = %RejectButton
@onready var evidence_label: Label = %EvidenceLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var workbench = %Workbench
@onready var overlay: Control = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_body: RichTextLabel = %OverlayBody
@onready var overlay_button: Button = %OverlayButton
@onready var feedback: AtelierDeskFeedback = %Feedback

var phase := Phase.DAY_INTRO
var order_index := -1
var current_order: AtelierScrollOrder
var inspection: AtelierInspection
var _overlay_action: Callable
var _selected_field := ""
var _selected_rule: AtelierShopRule
var _rule_buttons: Dictionary[AtelierShopRule, Button] = {}
## Mensagem do balcão para quando o cliente recusado for embora.
var _leave_message := ""


func _ready() -> void:
	GameState.changed.connect(_refresh_hud)
	for field_name in field_buttons:
		field_buttons[field_name].pressed.connect(_on_field_pressed.bind(field_name))
	bell_button.pressed.connect(_call_next_client)
	approve_button.pressed.connect(_on_approve)
	reject_button.pressed.connect(_on_reject)
	overlay_button.pressed.connect(func() -> void: _overlay_action.call())
	workbench.delivered.connect(_on_scroll_delivered)
	workbench.abandoned.connect(_on_scroll_abandoned)
	feedback.stamp_impact.connect(_on_stamp_impact)
	feedback.stamp_finished.connect(_on_stamp_finished)
	for paper: Control in [request_form, $Papers/Rulebook]:
		paper.picked_up.connect(feedback.play_sfx.bind(&"paper"))
	workbench.hide()
	_start_day(PackedStringArray())


func _day() -> AtelierShopDay:
	return GameState.current_day()


## ======================== DIA ========================

func _start_day(headlines: PackedStringArray) -> void:
	phase = Phase.DAY_INTRO
	order_index = -1
	_clear_counter()
	var day := _day()
	_build_rulebook(day)
	var body := day.intro
	if not headlines.is_empty():
		body = "[b]THE MORNING HERALD[/b]\n" + "\n\n".join(headlines) + "\n\n" + body
	body += "\n\n[b]Rulebook[/b]\n" + "\n\n".join(PackedStringArray(day.rules.map(func(rule: AtelierShopRule) -> String: return "- " + rule.text)))
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
	feedback.play_sfx(&"bell")
	# Clientes cujas condições não valem hoje simplesmente não vêm.
	current_order = null
	while current_order == null:
		order_index += 1
		if order_index >= _day().orders.size():
			_end_day()
			return
		current_order = GameState.resolve_customer(_day().orders[order_index])
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
	_start_day(GameState.begin_next_day())


func _show_demo_end(ledger_body: String) -> void:
	phase = Phase.DEMO_END
	var body := ledger_body
	var upcoming := GameState.upcoming_headlines()
	if not upcoming.is_empty():
		body += "\n\n[b]Tomorrow's Herald will read:[/b]\n" + "\n\n".join(upcoming)
	body += "\n\n[i]Thanks for playing the Atelier demo![/i]"
	_show_overlay("End of the demo", body, "Back to the title", func() -> void: get_tree().change_scene_to_file("res://scenes/game/Title.tscn"))


## ======================== CARIMBOS ========================

func _on_approve() -> void:
	_press_stamp(AtelierDeskFeedback.APPROVE, approve_button)


func _on_reject() -> void:
	_press_stamp(AtelierDeskFeedback.REJECT, reject_button)


## O clique só inicia o carimbo; cliques repetidos caem fora por causa da fase.
func _press_stamp(kind: StringName, button: Button) -> void:
	if phase != Phase.SERVING:
		return
	phase = Phase.STAMPING
	_selected_field = ""
	_selected_rule = null
	_refresh_inspection_marks()
	_refresh_controls()
	feedback.play_stamp(kind, button, request_form)


## Impacto do carimbo: é aqui que a decisão passa a valer.
func _on_stamp_impact(kind: StringName) -> void:
	if phase != Phase.STAMPING or current_order == null:
		return
	var order := current_order
	if kind == AtelierDeskFeedback.APPROVE:
		phase = Phase.CRAFTING
		_say_reaction(order, true)
		_say_feedback("Approved. Take the request to your bench.")
	else:
		phase = Phase.LEAVING
		var cited := inspection.cited_rules()
		if GameState.reject(order, cited):
			var titles := PackedStringArray(cited.map(func(rule: AtelierShopRule) -> String: return rule.title))
			_leave_message = "Good call. Refused on evidence: %s." % ", ".join(titles)
		elif _day().is_legal(order):
			_leave_message = "An honest customer leaves disappointed. Your reputation suffers."
		else:
			_leave_message = "You refused without citing a broken rule, so it counts as refusing without cause. Link a field to the rule it breaks before stamping."
		_say_reaction(order, false)
		_say_feedback(_leave_message)
	_refresh_controls()


## O carimbo voltou: depois de uma pausa curta, abre a bancada ou o cliente sai.
## Cada passo confere se ainda é o mesmo cliente e a mesma fase.
func _on_stamp_finished(kind: StringName) -> void:
	var order := current_order
	if kind == AtelierDeskFeedback.APPROVE and phase == Phase.CRAFTING:
		await feedback.hold(APPROVED_HOLD)
		if phase == Phase.CRAFTING and current_order == order and not workbench.visible:
			workbench.open_order(order, _day().runes)
	elif kind == AtelierDeskFeedback.REJECT and phase == Phase.LEAVING:
		await feedback.hold(REFUSED_LINGER)
		if phase == Phase.LEAVING and current_order == order:
			_client_leaves(_leave_message)


func _say_reaction(order: AtelierScrollOrder, approved: bool) -> void:
	var line := order.reaction_approved if approved else order.reaction_refused
	if line.is_empty():
		if approved:
			line = "Wonderful, thank you!"
		elif _day().is_legal(order):
			line = "But... my request was honest!"
		else:
			line = "Tch. Fine. I'll find another shop."
	speech_label.text = "\"%s\"" % line


func _on_scroll_delivered(result: Dictionary) -> void:
	if phase != Phase.CRAFTING:
		return
	workbench.hide()
	var order := current_order
	var paid := GameState.deliver(order, result["elegant"])
	if paid > 0:
		feedback.play_sfx(&"coins")
	if not _day().is_legal(order):
		_client_leaves("%s pays and hurries off with the scroll. You have an uneasy feeling..." % order.client_name)
	else:
		_client_leaves("%s thanks you and pays %d coins." % [order.client_name, paid])


func _on_scroll_abandoned() -> void:
	if phase != Phase.CRAFTING:
		return
	workbench.hide()
	var order := current_order
	GameState.abandon(order)
	_client_leaves("You couldn't write the scroll. %s leaves empty-handed." % order.client_name)


func _client_leaves(message: String) -> void:
	phase = Phase.WAITING
	current_order = null
	_clear_counter()
	_say_feedback(message + ("\nRing the bell for the next client." if _customers_waiting() > 0 else "\nNo one else is waiting. Ring the bell to close the shop."))
	_refresh_controls()


## ======================== APRESENTAÇÃO ========================

func _show_client(order: AtelierScrollOrder) -> void:
	portrait.color = order.portrait_color
	portrait_initial.text = order.client_name.left(1)
	client_name_label.text = "%s, %s" % [order.client_name, order.race]
	speech_label.text = "\"%s\"" % order.greeting
	spec_label.text = "Scroll must: %s" % order.spec.get_slice("\n", 0)
	inspection = AtelierInspection.new(order, _day().rules)
	_selected_field = ""
	_selected_rule = null
	_refresh_inspection_marks()
	feedback.clear_ink()
	portrait.show()
	request_form.show()
	feedback.play_sfx(&"paper")


func _clear_counter() -> void:
	portrait.hide()
	client_name_label.text = "The window is empty."
	speech_label.text = ""
	request_form.hide()
	feedback.clear_ink()
	inspection = null
	_selected_field = ""
	_selected_rule = null
	_refresh_inspection_marks()


## ======================== INSPEÇÃO ========================

func _build_rulebook(day: AtelierShopDay) -> void:
	for child in rules_list.get_children():
		rules_list.remove_child(child)
		child.queue_free()
	_rule_buttons.clear()
	for rule in day.rules:
		var button := Button.new()
		button.name = "Rule_%s" % rule.id
		button.theme_type_variation = &"PaperField"
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.x = 290.0
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_rule_pressed.bind(rule))
		rules_list.add_child(button)
		_rule_buttons[rule] = button
	_refresh_inspection_marks()


func _on_field_pressed(field_name: String) -> void:
	if phase == Phase.SERVING and inspection != null:
		_selected_field = "" if _selected_field == field_name else field_name
		_try_link()
	_refresh_inspection_marks()


func _on_rule_pressed(rule: AtelierShopRule) -> void:
	if phase == Phase.SERVING and inspection != null:
		_selected_rule = null if _selected_rule == rule else rule
		_try_link()
	_refresh_inspection_marks()


## Com um campo e uma regra escolhidos, a inspeção julga a ligação.
func _try_link() -> void:
	if _selected_field.is_empty() and _selected_rule == null:
		return
	if _selected_rule == null:
		_say_feedback("Now click the rule this field breaks.")
		return
	if _selected_field.is_empty():
		_say_feedback("Now click the field on the request that breaks this rule.")
		return
	var field_name := _selected_field
	var rule := _selected_rule
	_selected_field = ""
	_selected_rule = null
	var link := inspection.link(field_name, rule)
	_say_feedback(link["message"])
	var result: AtelierInspection.Result = link["result"]
	if result != AtelierInspection.Result.VALID and result != AtelierInspection.Result.DUPLICATE:
		_flash(field_buttons[field_name])
		_flash(_rule_buttons[rule])


func _refresh_inspection_marks() -> void:
	var order := inspection.order if inspection != null else null
	for field_name in field_buttons:
		var button := field_buttons[field_name]
		var cited := inspection != null and inspection.evidence.any(func(entry: Dictionary) -> bool: return entry["field"] == field_name)
		button.text = (EVIDENCE_MARK if cited else "") + _field_text(order, field_name)
		button.set_pressed_no_signal(field_name == _selected_field)
		_set_ink(button, cited)
	for rule in _rule_buttons:
		var button := _rule_buttons[rule]
		var cited := inspection != null and inspection.cited_rules().has(rule)
		button.text = (EVIDENCE_MARK if cited else "- ") + rule.text
		button.set_pressed_no_signal(rule == _selected_rule)
		_set_ink(button, cited)
	if inspection == null:
		evidence_label.text = ""
	elif not inspection.has_evidence():
		evidence_label.text = "No evidence yet. Refusing without a cited rule counts as refusing without cause."
	else:
		var lines: PackedStringArray = ["Evidence for refusal:"]
		for entry in inspection.evidence:
			var rule: AtelierShopRule = entry["rule"]
			lines.append("- %s -> %s" % [AtelierScrollOrder.FIELD_LABELS[entry["field"]], rule.title])
		evidence_label.text = "\n".join(lines)


static func _field_text(order: AtelierScrollOrder, field_name: String) -> String:
	if order == null:
		return ""
	match field_name:
		"item":
			return order.item
		"details":
			return "Details:\n%s" % order.details
		_:
			return "%s:  %s" % [AtelierScrollOrder.FIELD_LABELS[field_name], order.field_value(field_name)]


static func _set_ink(button: Button, cited: bool) -> void:
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		if cited:
			button.add_theme_color_override(color_name, EVIDENCE_INK)
		else:
			button.remove_theme_color_override(color_name)


func _flash(control: Control) -> void:
	control.modulate = CONTRADICTION_FLASH
	create_tween().tween_property(control, "modulate", Color.WHITE, 0.45)


func _refresh_hud() -> void:
	day_label.text = _day().title
	money_label.text = "%d coins" % GameState.money
	reputation_label.text = "Reputation %d" % GameState.reputation
	queue_label.text = "%d waiting outside" % _customers_waiting()


## Clientes ainda na fila que de fato viriam com as flags atuais.
func _customers_waiting() -> int:
	var waiting := 0
	for index in range(order_index + 1, _day().orders.size()):
		if GameState.resolve_customer(_day().orders[index]) != null:
			waiting += 1
	return waiting


func _refresh_controls() -> void:
	bell_button.disabled = phase != Phase.WAITING
	# Durante STAMPING os carimbos seguem com a aparência normal (um deles está
	# voando até o papel); cliques extras são ignorados pela fase em _press_stamp.
	var stamps_ready := phase == Phase.SERVING or phase == Phase.STAMPING
	approve_button.disabled = not stamps_ready
	reject_button.disabled = not stamps_ready
	_refresh_hud()


func _say_feedback(text: String) -> void:
	feedback_label.text = text


func _show_overlay(title: String, body: String, button_text: String, action: Callable) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_button.text = button_text
	_overlay_action = action
	_refresh_controls()
	overlay_body.fit_content = true
	overlay_body.custom_minimum_size.y = 0.0
	overlay.show()
	_cap_overlay_body()


## Manhãs com muitas manchetes cresceriam além da janela e esconderiam o botão;
## acima do limite, o texto passa a rolar dentro do cartão.
func _cap_overlay_body() -> void:
	await get_tree().process_frame
	if overlay_body.get_content_height() > OVERLAY_BODY_MAX_HEIGHT:
		overlay_body.fit_content = false
		overlay_body.custom_minimum_size.y = OVERLAY_BODY_MAX_HEIGHT
		overlay_body.scroll_to_line(0)


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
