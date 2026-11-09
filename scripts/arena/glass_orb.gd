extends Control

## Um lugar na estande: orbe de vidro flutuando, com sombra na madeira.
## kind: "plus" (abre a criação), "empty" (vidro apagado) ou "spell" (vidro
## preenchido com a cor do feitiço, que pode ser arrastado para o mapa).

signal pressed
signal button_down

const PX := ArenaPixelArt.PIXEL
const BOB_HEIGHT := 5.0
const HOVER_LIFT := 6.0

@export var kind := "empty"
var spell = null

var _orb: Sprite2D
var _plus: Sprite2D
var _shadow: Sprite2D
var _button: Button
var _phase := randf() * TAU
var _clock := 0.0
var _lift := 0.0
var _hovered := false


func _ready() -> void:
	custom_minimum_size = Vector2(18.0, 30.0) * PX
	size = custom_minimum_size
	_shadow = _sprite(ArenaPixelArt.shadow_texture())
	_orb = _sprite(ArenaPixelArt.slot_texture())
	_plus = _sprite(ArenaPixelArt.plus_texture())
	_button = Button.new()
	_button.flat = true
	_button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	_button.pressed.connect(func() -> void: pressed.emit())
	_button.button_down.connect(func() -> void: button_down.emit())
	_button.mouse_entered.connect(func() -> void: _hovered = true)
	_button.mouse_exited.connect(func() -> void: _hovered = false)
	add_child(_button)
	_refresh()


func set_spell(new_spell) -> void:
	spell = new_spell
	if kind != "plus":
		kind = "spell" if spell != null else "empty"
	_refresh()


func set_orb_hidden(hidden: bool) -> void:
	_orb.visible = not hidden
	_shadow.visible = not hidden


func _refresh() -> void:
	if _orb == null:
		return
	match kind:
		"spell":
			_orb.texture = ArenaPixelArt.spell_orb_texture(spell["color"])
		_:
			_orb.texture = ArenaPixelArt.slot_texture()
	_orb.modulate.a = 0.45 if kind == "empty" else 1.0
	_plus.visible = kind == "plus"
	var interactive := kind != "empty"
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	set_orb_hidden(false)


func _sprite(tex: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(PX, PX)
	add_child(sprite)
	return sprite


func _process(delta: float) -> void:
	_clock += delta
	_lift = HOVER_LIFT if _hovered and kind != "empty" else 0.0
	var bob := sin(_clock * 2.2 + _phase) * BOB_HEIGHT
	# Posições em múltiplos do pixel para não quebrar a grade.
	var center_x := snappedf(size.x * 0.5, PX)
	var orb_y := snappedf(size.y * 0.45 - bob - _lift, PX)
	_orb.position = Vector2(center_x, orb_y)
	_plus.position = _orb.position
	_shadow.position = Vector2(center_x, snappedf(size.y - 4.0 * PX, PX))
	var squash := 1.0 - (bob + BOB_HEIGHT + _lift) / (BOB_HEIGHT * 2.0 + HOVER_LIFT) * 0.35
	_shadow.scale = Vector2(PX * squash, PX)
	_shadow.modulate.a = 0.6 + 0.4 * squash


## Centro atual da orbe (com o balanço), em coordenadas de tela.
func orb_center() -> Vector2:
	return get_global_transform_with_canvas() * _orb.position
