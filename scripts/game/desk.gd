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
## As configurações (%Settings, pela engrenagem ou Esc) trocam o idioma e o
## estilo de arte na hora: cada texto do balcão guarda como se escreve (uma
## Callable) e é reescrito quando o idioma muda.

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
## Dicas de uso (o que clicar agora) somem da nota depois de um tempo; avisos,
## resultados e penalidades ficam.
const HINT_FADE_TIME := 0.6

## Silhueta usada por clientes sem retrato próprio (tingida com portrait_color).
@export var generic_portrait: Texture2D
## Estilo de arte do balcão; vazio usa o preferido (AtelierDeskStyles).
@export var desk_style: AtelierDeskStyle
## Ligações erradas com um cliente até ele perder a paciência (mínimo 2).
@export var inspection_mistake_threshold := AtelierInspection.DEFAULT_MISTAKE_THRESHOLD
## Reputação perdida, uma única vez por cliente, ao atingir o limite.
@export var inspection_mistake_penalty := 1
## Segundos que uma dica fica na nota antes de sumir.
@export var hint_fade_delay := 6.0

@onready var day_label: Label = %DayLabel
@onready var money_label: Label = %MoneyLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var queue_label: Label = %QueueLabel
@onready var portrait: TextureRect = %Portrait
@onready var client_name_label: Label = %ClientName
@onready var speech_label: Label = %Speech
@onready var bell_button: AtelierDeskStamp = %BellButton
## Páginas do livro de regras aberto (a divisão vem de AtelierContentBudget.rule_pages).
@onready var rule_pages: Array[VBoxContainer] = [%RulesLeft, %RulesRight]
@onready var request_form: Control = %RequestForm
## Botão de cada campo inspecionável, pelas chaves de AtelierScrollOrder.INSPECTABLE_FIELDS.
@onready var field_buttons: Dictionary[String, Button] = {
	"item": %ItemField, "name": %NameField, "age": %AgeField,
	"race": %RaceField, "signature": %SignatureField, "details": %DetailsField,
}
@onready var spec_label: Label = %SpecLabel
@onready var approve_button: AtelierDeskStamp = %ApproveButton
@onready var reject_button: AtelierDeskStamp = %RejectButton
@onready var evidence_label: Label = %EvidenceLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var workbench = %Workbench
@onready var overlay: Control = %Overlay
@onready var overlay_title: Label = %OverlayTitle
@onready var overlay_body: RichTextLabel = %OverlayBody
@onready var overlay_button: Button = %OverlayButton
@onready var feedback: AtelierDeskFeedback = %Feedback
@onready var settings: AtelierSettingsPanel = %Settings

var phase := Phase.DAY_INTRO
var order_index := -1
var current_order: AtelierScrollOrder
var inspection: AtelierInspection
var _overlay_action: Callable
var _selected_field := ""
var _selected_rule: AtelierShopRule
var _rule_buttons: Dictionary[AtelierShopRule, Button] = {}
## Mensagem do balcão para quando o cliente recusado for embora.
var _leave_text: Callable
var _hint_tween: Tween
## Como escrever o texto atual da nota, da fala do cliente e do cartão do
## dia (título, corpo, botão), para reescrever quando o idioma muda.
var _note_text: Callable
var _speech_text: Callable
var _overlay_text: Callable


func _ready() -> void:
	# Normalmente a tela de título já aplicou; vale também abrindo o balcão direto.
	AtelierSettings.apply_language()
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
	for paper: Control in [request_form, %Rulebook]:
		paper.picked_up.connect(feedback.play_sfx.bind(&"paper"))
	%SettingsButton.pressed.connect(settings.open)
	settings.desk_style_changed.connect(apply_style)
	apply_style(desk_style if desk_style != null else AtelierDeskStyles.preferred())
	workbench.hide()
	_start_day(PackedStringArray())


## Troca a arte do balcão. Só texturas e as posições do retrato e da vela:
## o layout e os tamanhos dos papéis são os mesmos em todos os estilos.
func apply_style(style: AtelierDeskStyle) -> void:
	desk_style = style
	(%Backdrop as TextureRect).texture = style.backdrop
	(%DayCard as TextureRect).texture = style.day_card
	(%Candle as TextureRect).texture = style.candle
	(%Candle as Control).position = style.candle_position
	portrait.position = style.portrait_position - portrait.get_parent().position
	(%StampTray as TextureRect).texture = style.stamp_tray
	bell_button.rest_texture = style.bell
	bell_button.lifted_texture = style.bell_lift
	approve_button.rest_texture = style.stamp_approve
	approve_button.lifted_texture = style.stamp_approve_lift
	reject_button.rest_texture = style.stamp_reject
	reject_button.lifted_texture = style.stamp_reject_lift
	feedback.stamp_sprites = {AtelierDeskFeedback.APPROVE: style.stamp_approve_head, AtelierDeskFeedback.REJECT: style.stamp_reject_head}
	_dress_paper(%Rulebook, style.rulebook)
	_dress_paper(request_form, style.request)
	_dress_paper(%InspectionNote, style.note)


## O papel continua com as margens do tema (o texto não muda de lugar); só a
## textura é a do estilo.
static func _dress_paper(paper: Control, texture: Texture2D) -> void:
	paper.remove_theme_stylebox_override(&"panel")
	var box := paper.get_theme_stylebox(&"panel").duplicate() as StyleBoxTexture
	box.texture = texture
	paper.add_theme_stylebox_override(&"panel", box)


func _day() -> AtelierShopDay:
	return GameState.current_day()


## Esc abre as configurações de qualquer tela do balcão (dia, bancada,
## livro-caixa); com elas abertas, o próprio painel fecha com Esc.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not settings.visible:
		settings.open()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_retranslate()


## O idioma mudou: reescreve tudo que o balcão escreveu por código. Textos
## com chave (botões, rótulos da cena) o Godot traduz sozinho.
func _retranslate() -> void:
	_refresh_hud()
	_refresh_inspection_marks()
	if current_order == null:
		client_name_label.text = tr("DESK_WINDOW_EMPTY")
	if _speech_text.is_valid():
		speech_label.text = "\"%s\"" % _speech_text.call()
	if _note_text.is_valid():
		feedback_label.text = _note_text.call()
	if overlay.visible and _overlay_text.is_valid():
		_fill_overlay()


## Texto de uma chave (com argumentos), escrito de novo a cada chamada: é o
## que a nota e a fala guardam para reescrever em outro idioma.
func _translated(key: String, args: Array = []) -> Callable:
	return func() -> String: return tr(key) % args if not args.is_empty() else tr(key)


## Texto que não se traduz (fala e dados do pedido).
static func _verbatim(text: String) -> Callable:
	return func() -> String: return text


## ======================== DIA ========================

func _start_day(headlines: PackedStringArray) -> void:
	phase = Phase.DAY_INTRO
	order_index = -1
	_clear_counter()
	var day := _day()
	# Conteúdo fora do orçamento de texto do balcão é inválido: avisa em vez de
	# encolher fonte ou mudar o layout (veja AtelierContentBudget).
	if OS.is_debug_build():
		for problem in AtelierContentBudget.check_day(day):
			push_warning("Invalid content: %s" % problem)
	_build_rulebook(day)
	_show_overlay(func() -> Array: return [day.title, _day_intro(day, headlines), tr("DESK_OPEN_SHOP")], _begin_service)
	_refresh_hud()


func _day_intro(day: AtelierShopDay, headlines: PackedStringArray) -> String:
	var body := day.intro
	if not headlines.is_empty():
		body = "[b]%s[/b]\n" % tr("DESK_HERALD_HEADER") + "\n\n".join(headlines) + "\n\n" + body
	body += "\n\n[b]%s[/b]\n" % tr("DESK_RULEBOOK_HEADER") + "\n\n".join(PackedStringArray(day.rules.map(func(rule: AtelierShopRule) -> String: return "- " + rule.text)))
	body += "\n\n[b]%s[/b]\n" % tr("DESK_RUNES_HEADER") + ", ".join(_rune_labels(day.runes))
	return body


func _begin_service() -> void:
	overlay.hide()
	phase = Phase.WAITING
	_say_hint(_translated("DESK_RING_FIRST"))
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
	_say_hint(_translated("DESK_CHECK_REQUEST"))
	_refresh_controls()


func _end_day() -> void:
	phase = Phase.DAY_END
	_clear_counter()
	if GameState.has_next_day():
		var title := _day().title
		_show_overlay(func() -> Array: return [tr("DESK_LEDGER_TITLE") % [title], _ledger(), tr("DESK_SLEEP")], _go_to_next_day)
	else:
		_show_demo_end()


## Livro-caixa do dia, no idioma atual.
func _ledger() -> String:
	var lines: PackedStringArray = []
	var earned := 0
	for entry in GameState.ledger:
		earned += int(entry["money"])
		lines.append("%s   [color=#e8c07a]%s[/color]%s" % [GameState.entry_text(entry), _signed(entry["money"], "DESK_SIGNED_COINS"), _reputation_suffix(entry["reputation"])])
	var body := "\n".join(lines) if not lines.is_empty() else tr("DESK_QUIET_DAY")
	return body + "\n\n" + tr("DESK_DAY_TOTALS") % [_signed(earned, "DESK_SIGNED_COINS"), GameState.money, GameState.reputation]


func _go_to_next_day() -> void:
	_start_day(GameState.begin_next_day())


func _show_demo_end() -> void:
	phase = Phase.DEMO_END
	var upcoming := GameState.upcoming_headlines()
	_show_overlay(func() -> Array: return [tr("DESK_DEMO_END_TITLE"), _demo_end(upcoming), tr("DESK_BACK_TO_TITLE")],
			func() -> void: get_tree().change_scene_to_file("res://scenes/game/Title.tscn"))


func _demo_end(upcoming: PackedStringArray) -> String:
	var body := _ledger()
	if not upcoming.is_empty():
		body += "\n\n[b]%s[/b]\n" % tr("DESK_TOMORROW_HERALD") + "\n\n".join(upcoming)
	return body + "\n\n[i]%s[/i]" % tr("DESK_THANKS")


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
		_say_feedback(_translated("DESK_APPROVED"))
	else:
		phase = Phase.LEAVING
		var cited := inspection.cited_rules()
		if GameState.reject(order, cited):
			var titles := PackedStringArray(cited.map(func(rule: AtelierShopRule) -> String: return rule.title))
			_leave_text = _translated("DESK_REFUSED_EVIDENCE", [", ".join(titles)])
		elif _day().is_legal(order):
			_leave_text = _translated("DESK_REFUSED_HONEST")
		else:
			_leave_text = _translated("DESK_REFUSED_NO_CAUSE")
		_say_reaction(order, false)
		_say_feedback(_leave_text)
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
			_client_leaves(_leave_text)


func _say_reaction(order: AtelierScrollOrder, approved: bool) -> void:
	var line := order.reaction_approved if approved else order.reaction_refused
	if not line.is_empty():
		_say_speech(_verbatim(line))
	elif approved:
		_say_speech(_translated("DESK_REACTION_APPROVED"))
	elif _day().is_legal(order):
		_say_speech(_translated("DESK_REACTION_HONEST"))
	else:
		_say_speech(_translated("DESK_REACTION_CAUGHT"))
	_show_mood(order, AtelierPortrait.Mood.HAPPY if approved else AtelierPortrait.Mood.UPSET)


func _on_scroll_delivered(result: Dictionary) -> void:
	if phase != Phase.CRAFTING:
		return
	workbench.hide()
	var order := current_order
	var paid := GameState.deliver(order, result["elegant"])
	if paid > 0:
		feedback.play_sfx(&"coins")
	if not _day().is_legal(order):
		_client_leaves(_translated("DESK_DELIVERED_ILLEGAL", [order.client_name]))
	else:
		_client_leaves(_translated("DESK_DELIVERED", [order.client_name, paid]))


func _on_scroll_abandoned() -> void:
	if phase != Phase.CRAFTING:
		return
	workbench.hide()
	var order := current_order
	GameState.abandon(order)
	_client_leaves(_translated("DESK_ABANDONED", [order.client_name]))


func _client_leaves(message: Callable) -> void:
	phase = Phase.WAITING
	current_order = null
	_clear_counter()
	var ring_key := "DESK_RING_NEXT" if _customers_waiting() > 0 else "DESK_RING_CLOSE"
	_say_feedback(func() -> String: return message.call() + "\n" + tr(ring_key))
	_refresh_controls()


## ======================== APRESENTAÇÃO ========================

func _show_client(order: AtelierScrollOrder) -> void:
	_show_mood(order, AtelierPortrait.Mood.NEUTRAL)
	# Fala = personalidade, papel = informação: a raça fica só no pedido.
	client_name_label.text = order.client_name
	_say_speech(_verbatim(order.greeting))
	# O balcão mostra só o resumo (primeira linha); a bancada mostra o resto.
	spec_label.text = order.spec.get_slice("\n", 0)
	inspection = AtelierInspection.new(order, _day().rules, inspection_mistake_threshold)
	_selected_field = ""
	_selected_rule = null
	_refresh_inspection_marks()
	feedback.clear_ink()
	portrait.show()
	request_form.show()
	feedback.play_sfx(&"paper")


## Expressão do cliente na janela. Sem retrato próprio, fica a silhueta
## genérica tingida com portrait_color (ela não muda de expressão).
func _show_mood(order: AtelierScrollOrder, mood: AtelierPortrait.Mood) -> void:
	var face := order.portrait
	portrait.texture = face.texture_for(mood) if face != null else generic_portrait
	portrait.self_modulate = Color.WHITE if face != null else order.portrait_color


func _clear_counter() -> void:
	portrait.hide()
	client_name_label.text = tr("DESK_WINDOW_EMPTY")
	_speech_text = Callable()
	speech_label.text = ""
	request_form.hide()
	feedback.clear_ink()
	inspection = null
	_selected_field = ""
	_selected_rule = null
	_refresh_inspection_marks()


## ======================== INSPEÇÃO ========================

## Livro aberto: as regras numeradas se dividem entre as duas páginas.
func _build_rulebook(day: AtelierShopDay) -> void:
	for page in rule_pages:
		for child in page.get_children():
			page.remove_child(child)
			child.queue_free()
	_rule_buttons.clear()
	var pages := AtelierContentBudget.rule_pages(day.rules)
	var number := 0
	for page_index in pages.size():
		for rule: AtelierShopRule in pages[page_index]:
			number += 1
			var entry := VBoxContainer.new()
			entry.add_theme_constant_override(&"separation", 0)
			var label := Label.new()
			label.theme_type_variation = &"TinyCaps"
			label.text = "%02d" % number
			entry.add_child(label)
			var button := Button.new()
			button.name = "Rule_%s" % rule.id
			button.theme_type_variation = &"PaperField"
			button.toggle_mode = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			# Largura e fonte vêm da cena (página) e do tema, não do código.
			button.custom_minimum_size.x = rule_pages[page_index].custom_minimum_size.x
			button.pressed.connect(_on_rule_pressed.bind(rule))
			entry.add_child(button)
			rule_pages[page_index].add_child(entry)
			_rule_buttons[rule] = button
	_refresh_inspection_marks()


## Botão de uma regra do dia pelo id (para testes e ferramentas).
func rule_button(rule_id: String) -> Button:
	for rule in _rule_buttons:
		if rule.id == rule_id:
			return _rule_buttons[rule]
	return null


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
		_say_hint(_translated("DESK_PICK_RULE"))
		return
	if _selected_field.is_empty():
		_say_hint(_translated("DESK_PICK_FIELD"))
		return
	var field_name := _selected_field
	var rule := _selected_rule
	_selected_field = ""
	_selected_rule = null
	var link := inspection.link(field_name, rule)
	# A mensagem é refeita pela inspeção deste cliente (no idioma da vez).
	var check := inspection
	var result: AtelierInspection.Result = link["result"]
	var message := func() -> String: return check.describe(result, field_name, rule)
	_say_feedback(message)
	if link["mistake"]:
		_flash(field_buttons[field_name])
		_flash(_rule_buttons[rule])
		_react_to_mistake(link, message)


## Reação do cliente a erros de inspeção, crescendo com a paciência; a
## penalidade vem da inspeção (penalty_due) e só acontece uma vez.
func _react_to_mistake(link: Dictionary, message: Callable) -> void:
	match link["patience"]:
		AtelierInspection.Patience.UNEASY:
			_say_speech(_translated("DESK_PATIENCE_UNEASY"))
			_show_mood(current_order, AtelierPortrait.Mood.UNEASY)
		AtelierInspection.Patience.UPSET:
			_say_speech(_translated("DESK_PATIENCE_UPSET"))
			_show_mood(current_order, AtelierPortrait.Mood.UPSET)
		AtelierInspection.Patience.EXASPERATED:
			_say_speech(_translated("DESK_PATIENCE_EXASPERATED"))
			_show_mood(current_order, AtelierPortrait.Mood.UPSET)
	if link["penalty_due"]:
		GameState.penalize_inspection(current_order, inspection_mistake_penalty)
		var penalty := inspection_mistake_penalty
		_say_feedback(func() -> String: return message.call() + "\n" + tr("DESK_PATIENCE_PENALTY") % [penalty])


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
		button.text = (EVIDENCE_MARK if cited else "") + rule.text
		button.set_pressed_no_signal(rule == _selected_rule)
		_set_ink(button, cited)
	if inspection == null:
		evidence_label.text = ""
	elif not inspection.has_evidence():
		evidence_label.text = tr("DESK_NO_EVIDENCE")
	else:
		# Uma linha por regra citada (com os campos que a provam): cabe na nota
		# do balcão mesmo com todas as provas de um pedido.
		var lines: PackedStringArray = []
		for rule in inspection.cited_rules():
			var fields: PackedStringArray = []
			for entry in inspection.evidence:
				if entry["rule"] == rule:
					fields.append(tr(AtelierScrollOrder.FIELD_LABELS[entry["field"]]))
			lines.append("- %s: %s" % [rule.title, ", ".join(fields)])
		evidence_label.text = "\n".join(lines)
	if inspection != null and inspection.mistakes > 0:
		evidence_label.text += "\n" + tr("DESK_WRONG_LINKS") % [inspection.mistakes, inspection.mistake_threshold]
	# As provas só ocupam espaço na nota quando há algo a mostrar.
	evidence_label.visible = not evidence_label.text.is_empty()


func _field_text(order: AtelierScrollOrder, field_name: String) -> String:
	if order == null:
		return ""
	match field_name:
		"item":
			return order.item
		"details":
			return order.details
		_:
			return "%s:  %s" % [tr(AtelierScrollOrder.FIELD_LABELS[field_name]), order.field_value(field_name)]


static func _set_ink(button: Button, cited: bool) -> void:
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		if cited:
			button.add_theme_color_override(color_name, EVIDENCE_INK)
		else:
			button.remove_theme_color_override(color_name)


func _flash(control: Control) -> void:
	control.modulate = CONTRADICTION_FLASH
	create_tween().tween_property(control, "modulate", Color.WHITE, 0.45)


## Cartão do dia: números ao lado dos ícones pintados (sol, moedas, estandarte,
## fila); o texto completo fica na dica de cada número.
func _refresh_hud() -> void:
	var waiting := _customers_waiting()
	day_label.text = tr("DESK_HUD_DAY") % [GameState.day_index + 1]
	day_label.tooltip_text = _day().title
	money_label.text = str(GameState.money)
	money_label.tooltip_text = tr("DESK_HUD_MONEY") % [GameState.money]
	reputation_label.text = str(GameState.reputation)
	reputation_label.tooltip_text = tr("DESK_HUD_REPUTATION") % [GameState.reputation]
	queue_label.text = str(waiting)
	queue_label.tooltip_text = tr("DESK_HUD_QUEUE") % [waiting]


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


## Mensagem na nota da inspeção. Recebe como escrevê-la (e não o texto
## pronto) para reescrever no idioma novo se ele mudar.
func _say_feedback(text: Callable) -> void:
	if _hint_tween != null:
		_hint_tween.kill()
		_hint_tween = null
	feedback_label.modulate.a = 1.0
	_note_text = text
	feedback_label.text = text.call()


## Dica de uso: aparece como qualquer mensagem e some sozinha depois de
## hint_fade_delay. Uma mensagem nova (dica ou não) cancela o sumiço.
func _say_hint(text: Callable) -> void:
	_say_feedback(text)
	_hint_tween = create_tween()
	_hint_tween.tween_interval(hint_fade_delay)
	_hint_tween.tween_property(feedback_label, "modulate:a", 0.0, HINT_FADE_TIME)


## Fala do cliente no balão, entre aspas.
func _say_speech(text: Callable) -> void:
	_speech_text = text
	speech_label.text = "\"%s\"" % text.call()


## Cartão de tela cheia (manhã, livro-caixa, fim do demo). text devolve
## [título, corpo, botão] no idioma atual.
func _show_overlay(text: Callable, action: Callable) -> void:
	_overlay_text = text
	_overlay_action = action
	_refresh_controls()
	_fill_overlay()
	overlay.show()


func _fill_overlay() -> void:
	var parts: Array = _overlay_text.call()
	overlay_title.text = parts[0]
	overlay_body.text = parts[1]
	overlay_button.text = parts[2]
	overlay_body.fit_content = true
	overlay_body.custom_minimum_size.y = 0.0
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


## Valor com sinal na unidade da chave (DESK_SIGNED_COINS/_REP); vazio se zero.
func _signed(value: int, unit_key: String) -> String:
	if value == 0:
		return ""
	return tr(unit_key) % ["+%d" % value if value > 0 else "%d" % value]


func _reputation_suffix(value: int) -> String:
	if value == 0:
		return ""
	return "   [color=#9fc28a]%s[/color]" % _signed(value, "DESK_SIGNED_REP")
