class_name AtelierDeskStamp
extends Button

## Carimbo de borracha em pé sobre a mesa: o sprite fica em cima (erguido 2 px
## com contorno de latão no hover) e o nome numa plaquinha de latão embaixo.
## Continua sendo um Button comum (texto traduzido, disabled, pressed); o
## estilo PixelStamp reserva o alto do botão para o sprite.

## Folga acima do corpo no sprite em repouso (é para onde ele sobe no hover).
const HEAD_TOP := 4.0

## Sprite em repouso (com sombra) e erguido (hover).
@export var rest_texture: Texture2D
@export var lifted_texture: Texture2D

var _plate: Control


func _ready() -> void:
	_plate = Control.new()
	_plate.name = "Plate"
	_plate.show_behind_parent = true
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate, false, Node.INTERNAL_MODE_FRONT)
	_plate.draw.connect(_draw_plate)
	resized.connect(_place_plate)
	_place_plate()


func is_lifted() -> bool:
	return is_hovered() and not disabled


## Onde a cabeça do carimbo começa o voo até o papel (AtelierDeskFeedback):
## em cima do sprite em repouso, e não no centro do botão.
func head_origin(head_size: Vector2) -> Vector2:
	return global_position + Vector2(floorf((size.x - head_size.x) * 0.5), HEAD_TOP)


func _draw() -> void:
	var texture := lifted_texture if is_lifted() and lifted_texture != null else rest_texture
	if texture != null:
		var tint := get_theme_color(&"icon_disabled_color") if disabled else Color.WHITE
		draw_texture(texture, Vector2(floorf((size.x - texture.get_width()) * 0.5), 0.0), tint)
	_plate.queue_redraw()


func _place_plate() -> void:
	var top := get_theme_stylebox(&"normal").content_margin_top - 2.0
	_plate.position = Vector2(2.0, top)
	_plate.size = Vector2(size.x - 4.0, size.y - top - 1.0)


func _draw_plate() -> void:
	var style := &"plate_disabled" if disabled else &"plate_hover" if is_lifted() else &"plate"
	_plate.draw_style_box(get_theme_stylebox(style), Rect2(Vector2.ZERO, _plate.size))
