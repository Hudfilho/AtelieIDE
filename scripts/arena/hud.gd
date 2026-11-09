extends CanvasLayer

## HUD da arena: estande inclinada embaixo, orbes de vidro flutuando em cima.
## Slot 0 é o "+" (criação). Os outros guardam feitiços: segure e arraste a
## orbe para o mapa para lançar; soltar em cima da estande cancela. A
## velocidade do mouse ao soltar vira o arremesso da bolinha.

signal plus_pressed(orb_center: Vector2)
signal cast_requested(spell: Dictionary, screen_position: Vector2, throw_velocity: Vector2)

const OrbSlot = preload("res://scripts/arena/glass_orb.gd")
const PX := ArenaPixelArt.PIXEL
const SLOT_COUNT := 3
## Movimento mais antigo que isso no momento de soltar não conta como arremesso.
const THROW_WINDOW_MS := 80

var _root: Control
var _stand: Sprite2D
var _slots: Array = []
var _drag_index := -1
var _drag_sprite: Sprite2D
var _status: Label
var _drag_velocity := Vector2.ZERO
var _drag_velocity_at := 0


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_stand = Sprite2D.new()
	_stand.texture = ArenaPixelArt.stand_texture()
	_stand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stand.scale = Vector2(PX, PX)
	_stand.centered = false
	_root.add_child(_stand)

	for index in range(SLOT_COUNT):
		var slot = OrbSlot.new()
		slot.kind = "plus" if index == 0 else "empty"
		slot.pressed.connect(_on_slot_pressed.bind(index))
		slot.button_down.connect(_on_slot_down.bind(index))
		_root.add_child(slot)
		_slots.append(slot)

	_drag_sprite = Sprite2D.new()
	_drag_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_drag_sprite.scale = Vector2(PX, PX)
	_drag_sprite.visible = false
	_root.add_child(_drag_sprite)

	_status = Label.new()
	_status.position = Vector2(24.0, 18.0)
	_status.add_theme_font_override("font", ArenaPixelArt.FONT)
	_status.add_theme_font_size_override("font_size", ArenaPixelArt.FONT_SIZE)
	_status.add_theme_color_override("font_color", ArenaPixelArt.tint(0.8))
	_root.add_child(_status)

	_root.resized.connect(_layout)
	_layout()


## Centro da orbe de um slot, em coordenadas de tela.
func orb_center(index: int) -> Vector2:
	return _slots[index].orb_center()


## Texto do canto superior esquerdo (sala, mana...).
func set_status(text: String) -> void:
	_status.text = text


## Há alguma orbe com feitiço na estande (ou sendo arrastada)?
func has_any_spell() -> bool:
	for index in range(1, _slots.size()):
		if _slots[index].spell != null:
			return true
	return false


## Primeiro slot de feitiço vazio, ou -1.
func free_spell_slot() -> int:
	for index in range(1, _slots.size()):
		if _slots[index].spell == null and index != _drag_index:
			return index
	return -1


func set_spell(index: int, spell) -> void:
	_slots[index].set_spell(spell)


func _on_slot_pressed(index: int) -> void:
	if index == 0:
		plus_pressed.emit(_slots[0].orb_center())


func _on_slot_down(index: int) -> void:
	if index == 0 or _slots[index].spell == null or _drag_index >= 0:
		return
	_drag_index = index
	_slots[index].set_orb_hidden(true)
	_drag_sprite.texture = ArenaPixelArt.spell_orb_texture(_slots[index].spell["color"])
	_drag_sprite.position = _snap(_root.get_global_mouse_position())
	_drag_sprite.visible = true


func _input(event: InputEvent) -> void:
	if _drag_index < 0:
		return
	if event is InputEventMouseMotion:
		_drag_sprite.position = _snap(event.position)
		_drag_velocity = event.velocity
		_drag_velocity_at = Time.get_ticks_msec()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(event.position)
		get_viewport().set_input_as_handled()


func _finish_drag(screen_position: Vector2) -> void:
	var slot = _slots[_drag_index]
	_drag_sprite.visible = false
	_drag_index = -1
	# Soltar em cima da estande devolve a orbe.
	if screen_position.y >= _stand.position.y - 4.0 * PX:
		slot.set_orb_hidden(false)
		return
	var spell: Dictionary = slot.spell
	slot.set_spell(null)
	var throw := _drag_velocity if Time.get_ticks_msec() - _drag_velocity_at <= THROW_WINDOW_MS else Vector2.ZERO
	cast_requested.emit(spell, screen_position, throw)


func _snap(point: Vector2) -> Vector2:
	return Vector2(snappedf(point.x, PX), snappedf(point.y, PX))


func _layout() -> void:
	var view := _root.size
	var stand_size: Vector2 = _stand.texture.get_size() * PX
	var stand_pos := Vector2(snappedf((view.x - stand_size.x) * 0.5, PX), snappedf(view.y - stand_size.y - 2.0 * PX, PX))
	_stand.position = stand_pos
	var top_y := stand_pos.y + 2.0 * PX
	var usable := stand_size.x - 16.0 * PX
	for index in range(_slots.size()):
		var slot: Control = _slots[index]
		var cx := stand_pos.x + 8.0 * PX + usable * (float(index) + 0.5) / float(SLOT_COUNT)
		slot.position = Vector2(snappedf(cx - slot.size.x * 0.5, PX), snappedf(top_y - slot.size.y + 5.0 * PX, PX))
