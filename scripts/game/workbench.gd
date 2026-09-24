extends Control

## Bancada: o editor de runas em modo jogo, com a encomenda no topo. A bancada
## mostra só os exemplos; entregar confere também os testes ocultos com o
## AtelierSpellJudge. Desistir devolve o cliente.

signal delivered(result: Dictionary)
signal abandoned

const SpellJudge = preload("res://scripts/game/spell_judge.gd")
const FAIL_COLOR := Color(1.0, 0.55, 0.45)
const PASS_COLOR := Color(0.62, 0.9, 0.55)

@onready var order_title: Label = %OrderTitle
@onready var spec_label: Label = %SpecLabel
@onready var cases_label: Label = %CasesLabel
@onready var result_label: Label = %ResultLabel
@onready var deliver_button: Button = %DeliverButton
@onready var abandon_button: Button = %AbandonButton
@onready var reset_button: Button = %ResetButton
## Sem tipo: o editor (atelier_canvas.gd) não declara class_name.
@onready var canvas = %Canvas

var order: AtelierScrollOrder
var judge := SpellJudge.new()


func _ready() -> void:
	deliver_button.pressed.connect(_on_deliver_pressed)
	abandon_button.pressed.connect(func() -> void: abandoned.emit())
	reset_button.pressed.connect(_on_reset_pressed)
	canvas.ritual_finished.connect(_on_preview_finished)


func open_order(new_order: AtelierScrollOrder, runes: PackedStringArray) -> void:
	order = new_order
	order_title.text = "%s  -  for %s" % [order.item, order.client_name]
	spec_label.text = order.spec
	cases_label.text = _describe_cases()
	_say("Draw the ritual, test it with the play button, then deliver.", Color.WHITE)
	canvas.load_connections(order.starting_ritual)
	canvas.set_allowed_symbols(runes)
	# O ▶ da bancada usa as entradas do primeiro exemplo, para o READ ter o que ler.
	canvas.run_memory = order.preview_memory()
	reset_button.text = "Reset to draft" if not order.starting_ritual.is_empty() else "Clear bench"
	canvas.top_panel_open = true
	# O Oráculo abre sozinho ao apertar ▶; fechado, sobra espaço para desenhar.
	canvas.bottom_panel_open = false
	show()
	canvas.grab_focus()
	_frame_after_layout()


## A bancada acabou de aparecer: o canvas só recebe o tamanho real no próximo
## quadro, e centralizar antes disso usaria uma área de desenho vazia.
func _frame_after_layout() -> void:
	await get_tree().process_frame
	canvas.frame_connections()


func _describe_cases() -> String:
	var lines: PackedStringArray = []
	for test_case in order.examples:
		var memory: Dictionary = test_case.get("memory", {})
		var inputs := SpellJudge.describe_memory(memory).trim_prefix("With ").trim_suffix(", ")
		lines.append("%s  ->  %s" % [inputs if not inputs.is_empty() else "no inputs", SpellJudge.describe_output(test_case.get("output", []))])
	var par := "   |   Elegant work: %d runes or fewer" % order.par_runes if order.par_runes > 0 else ""
	var hidden := "   (+%d hidden %s on delivery)" % [order.hidden_tests.size(), "test" if order.hidden_tests.size() == 1 else "tests"] if not order.hidden_tests.is_empty() else ""
	return "Examples: " + "   ;   ".join(lines) + hidden + par


func _on_reset_pressed() -> void:
	canvas.replace_connections(order.starting_ritual)
	canvas.frame_connections()
	_say("Bench reset. Ctrl+Z brings your ritual back.", Color.WHITE)
	canvas.grab_focus()


## Resultado do ▶: compara com o primeiro exemplo, que forneceu a memória.
func _on_preview_finished(result: Dictionary) -> void:
	if order == null or order.examples.is_empty() or not visible or result.get("stopped", false):
		return
	var expected := SpellJudge.describe_output(order.examples[0].get("output", []))
	var actual := SpellJudge.describe_output(result.get("output", []))
	var errors: Array = result.get("errors", [])
	if not errors.is_empty():
		_say("Preview broke: %s" % str(errors[0]), FAIL_COLOR)
	elif actual == expected:
		_say("Preview matches the first example (%s). Deliver when ready." % actual, PASS_COLOR)
	else:
		_say("Preview printed %s; the first example expects %s." % [actual, expected], FAIL_COLOR)


func _say(text: String, color: Color) -> void:
	result_label.text = text
	result_label.modulate = color


func _on_deliver_pressed() -> void:
	var result := judge.judge(canvas.connections, order)
	if not result["passed"]:
		_say(SpellJudge.describe_failure(result), FAIL_COLOR)
		return
	delivered.emit(result)
