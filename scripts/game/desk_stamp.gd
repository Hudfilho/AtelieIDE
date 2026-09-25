class_name AtelierDeskStamp
extends Button

## Objeto clicável em pé no balcão (os carimbos na bandeja, o sino no
## peitoril): o sprite fica em cima e sobe 2 px com contorno de latão no
## hover. Continua sendo um Button comum (texto traduzido, disabled, pressed).
## Os carimbos mostram o nome numa plaquinha de latão embaixo (o estilo
## PixelStamp reserva o alto do botão para o sprite). O sino não tem
## plaquinha: brilha de leve enquanto pode ser tocado e mais forte no hover.

## Folga acima do corpo no sprite em repouso (é para onde ele sobe no hover).
const HEAD_TOP := 4.0
## Brilho (0 a 1): pulsa entre GLOW_IDLE_MIN e GLOW_IDLE_MAX a cada
## GLOW_PERIOD segundos enquanto o objeto pode ser usado; GLOW_HOVER no hover.
const GLOW_IDLE_MIN := 0.25
const GLOW_IDLE_MAX := 0.55
const GLOW_HOVER := 1.0
const GLOW_PERIOD := 2.4

## Sprite em repouso (com sombra) e erguido (hover). Trocar redesenha (o
## estilo do balcão troca os sprites em jogo).
@export var rest_texture: Texture2D:
	set(value):
		rest_texture = value
		queue_redraw()
@export var lifted_texture: Texture2D:
	set(value):
		lifted_texture = value
		queue_redraw()
## Plaquinha de latão com o texto do botão (os carimbos têm; o sino não).
@export var show_plate := true
## Halo desenhado atrás do sprite (vazio = sem brilho).
@export var glow_texture: Texture2D

var _plate: Control


func _ready() -> void:
	if show_plate:
		_plate = Control.new()
		_plate.name = "Plate"
		_plate.show_behind_parent = true
		_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_plate, false, Node.INTERNAL_MODE_FRONT)
		_plate.draw.connect(_draw_plate)
		resized.connect(_place_plate)
		_place_plate()
	# O brilho pulsa: redesenha a cada quadro só enquanto ele pode aparecer.
	set_process(glow_texture != null)


func _process(_delta: float) -> void:
	queue_redraw()


func is_lifted() -> bool:
	return is_hovered() and not disabled


## Intensidade do brilho agora (0 sem brilho), para o desenho e os testes.
func glow_level() -> float:
	if glow_texture == null or disabled:
		return 0.0
	if is_lifted():
		return GLOW_HOVER
	var wave := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU / GLOW_PERIOD)
	return lerpf(GLOW_IDLE_MIN, GLOW_IDLE_MAX, wave)


## Onde a cabeça do carimbo começa o voo até o papel (AtelierDeskFeedback):
## em cima do sprite em repouso, e não no centro do botão.
func head_origin(head_size: Vector2) -> Vector2:
	return global_position + Vector2(floorf((size.x - head_size.x) * 0.5), HEAD_TOP)


func _draw() -> void:
	var texture := lifted_texture if is_lifted() and lifted_texture != null else rest_texture
	if texture == null:
		return
	var at := Vector2(floorf((size.x - texture.get_width()) * 0.5), 0.0)
	var glow := glow_level()
	if glow > 0.0:
		# Halo centrado no corpo do sprite (abaixo da folga de cima), em pixel inteiro.
		var center := at + Vector2(texture.get_width(), texture.get_height() + HEAD_TOP) * 0.5
		draw_texture(glow_texture, (center - glow_texture.get_size() * 0.5).floor(), Color(1, 1, 1, glow))
	var tint := get_theme_color(&"icon_disabled_color") if disabled else Color.WHITE
	draw_texture(texture, at, tint)
	if _plate != null:
		_plate.queue_redraw()


func _place_plate() -> void:
	var top := get_theme_stylebox(&"normal").content_margin_top - 2.0
	_plate.position = Vector2(2.0, top)
	_plate.size = Vector2(size.x - 4.0, size.y - top - 1.0)


func _draw_plate() -> void:
	var style := &"plate_disabled" if disabled else &"plate_hover" if is_lifted() else &"plate"
	_plate.draw_style_box(get_theme_stylebox(style), Rect2(Vector2.ZERO, _plate.size))
