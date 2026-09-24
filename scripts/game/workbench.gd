extends Control

## Bancada: o editor de runas em modo jogo, com a encomenda no topo. Entregar
## confere o pergaminho com o AtelierSpellJudge; desistir devolve o cliente.

signal delivered(result: Dictionary)
signal abandoned

const SpellJudge = preload("res://scripts/game/spell_judge.gd")

@onready var order_title: Label = %OrderTitle
@onready var spec_label: Label = %SpecLabel
@onready var cases_label: Label = %CasesLabel
@onready var result_label: Label = %ResultLabel
@onready var deliver_button: Button = %DeliverButton
@onready var abandon_button: Button = %AbandonButton
## Sem tipo: o editor (atelier_canvas.gd) não declara class_name.
@onready var canvas = %Canvas

var order: AtelierScrollOrder
var judge := SpellJudge.new()


func _ready() -> void:
	deliver_button.pressed.connect(_on_deliver_pressed)
	abandon_button.pressed.connect(func() -> void: abandoned.emit())


func open_order(new_order: AtelierScrollOrder, runes: PackedStringArray) -> void:
	order = new_order
	order_title.text = "%s  -  for %s" % [order.item, order.client_name]
	spec_label.text = order.spec
	cases_label.text = _describe_cases()
	result_label.text = "Draw the ritual, test it with the play button, then deliver."
	result_label.modulate = Color.WHITE
	canvas.load_connections([])
	canvas.set_allowed_symbols(runes)
	# O ▶ da bancada usa as entradas do primeiro caso, para o READ ter o que ler.
	canvas.run_memory = order.test_cases[0].get("memory", {}) if not order.test_cases.is_empty() else {}
	canvas.top_panel_open = true
	# O Oráculo abre sozinho ao apertar ▶; fechado, sobra espaço para desenhar.
	canvas.bottom_panel_open = false
	show()
	canvas.grab_focus()


func _describe_cases() -> String:
	var lines: PackedStringArray = []
	for test_case in order.test_cases:
		var memory: Dictionary = test_case.get("memory", {})
		var inputs := SpellJudge.describe_memory(memory).trim_prefix("With ").trim_suffix(", ")
		lines.append("%s  ->  %s" % [inputs if not inputs.is_empty() else "no inputs", SpellJudge.describe_output(test_case.get("output", []))])
	var par := "   |   Elegant work: %d runes or fewer" % order.par_runes if order.par_runes > 0 else ""
	return "Tests: " + "   ;   ".join(lines) + par


func _on_deliver_pressed() -> void:
	var result := judge.judge(canvas.connections, order)
	if not result["passed"]:
		result_label.text = SpellJudge.describe_failure(result)
		result_label.modulate = Color(1.0, 0.55, 0.45)
		return
	delivered.emit(result)
