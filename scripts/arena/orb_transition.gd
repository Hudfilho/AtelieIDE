extends Control

## Transição da orbe: um disco de vidro em pixel art cresce a partir da orbe
## até cobrir a tela, ou encolhe de volta para ela. Também faz fade do disco
## cheio para revelar (ou esconder) a cena de criação por baixo.

const PX := ArenaPixelArt.PIXEL
const FILL := Color("0b1226")
const GROW_SECONDS := 0.42
const FADE_SECONDS := 0.22

var _center := Vector2.ZERO
var _radius := 0.0
var _tween: Tween


func _ready() -> void:
	# No _ready o nó já está na árvore: sem "and_offsets" ele manteria tamanho 0.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Cresce da orbe até cobrir tudo. Termina com a tela coberta pelo disco.
func cover_from(center: Vector2, start_radius: float) -> void:
	_begin(center)
	modulate.a = 1.0
	_radius = start_radius
	_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_tween.tween_method(_set_radius, start_radius, _cover_radius(), GROW_SECONDS)
	await _tween.finished


## Some o disco cheio, revelando o que está embaixo.
func reveal() -> void:
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	await _tween.finished
	_end()


## Volta a cobrir a tela com o disco cheio (para sair da criação).
func cover() -> void:
	_begin(_center)
	_radius = _cover_radius()
	modulate.a = 0.0
	queue_redraw()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	await _tween.finished


## Encolhe de volta para a orbe.
func shrink_to(center: Vector2, end_radius: float) -> void:
	_center = center
	_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_radius, _radius, end_radius, GROW_SECONDS)
	await _tween.finished
	_end()


func _begin(center: Vector2) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_center = Vector2(snappedf(center.x, PX), snappedf(center.y, PX))
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP # bloqueia cliques durante a animação


func _end() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_radius(value: float) -> void:
	_radius = value
	queue_redraw()


func _cover_radius() -> float:
	var farthest := 0.0
	for corner in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
		farthest = maxf(farthest, _center.distance_to(corner))
	return farthest + PX * 2.0


func _draw() -> void:
	if _radius <= 0.0:
		return
	_draw_disc(_radius, ArenaPixelArt.tint(0.85))
	_draw_disc(_radius - PX, FILL)


## Disco "rasterizado" em linhas de PX de altura, alinhado à grade do pixel.
func _draw_disc(radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var y := -snappedf(radius, PX)
	while y < radius:
		var mid := y + PX * 0.5
		var half := snappedf(sqrt(maxf(radius * radius - mid * mid, 0.0)), PX)
		if half > 0.0:
			draw_rect(Rect2(_center.x - half, _center.y + y, half * 2.0, PX), color)
		y += PX
