extends Node2D

## A orbe solta no mapa: encolhe até virar uma bolinha de vidro pixel art,
## quica, rola na direção do arremesso e só ativa depois de ARM_SECONDS.
## Os quadros do rolamento são uma esfera 8x8 sombreada com uma faixa que gira
## em volta do eixo perpendicular ao movimento; o quadro avança pela distância
## percorrida, então também rola quando o feitiço a move (Projétil).

const PX := ArenaPixelArt.PIXEL
const SIZE := 8
const FRAMES := 8
const DIRECTIONS := 8
## Raio da bolinha na tela, para converter distância em giro.
const RADIUS_SCREEN := 3.5 * PX
const SHRINK_SECONDS := 0.16
const ARM_SECONDS := 1.0
const FRICTION := 3.2
const THROW_SCALE := 0.35
const MAX_SPEED := 420.0
const MIN_SPEED := 60.0
const HOP_HEIGHT := 3.0 * PX
const SHADOW := ["..####..", ".######.", "..####.."]

static var _frame_cache: Dictionary = {}

var color := Color("e8452c")
## Área onde a bolinha pode rolar; bate e volta nas bordas.
var bounds := Rect2(0.0, 0.0, 1280.0, 720.0)
var velocity := Vector2.ZERO

var _sprite: Sprite2D
var _shadow: Sprite2D
var _rolling := false
var _distance := 0.0
var _direction := 0
var _last_position := Vector2.ZERO
var _hop := 0.0


func _ready() -> void:
	_shadow = _make_sprite(ArenaPixelArt.texture("ball_shadow", SHADOW, {"#": Color(0.0, 0.0, 0.0, 0.35)}))
	_shadow.visible = false
	_sprite = _make_sprite(ArenaPixelArt.spell_orb_texture(color))
	_last_position = position


func _make_sprite(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(PX, PX)
	add_child(sprite)
	return sprite


## Encolhe, quica e rola; retorna quando o feitiço deve ativar.
func land(throw_velocity: Vector2) -> void:
	# A orbe de 16 px encolhe até o tamanho da bolinha (8 px) e é trocada por ela.
	var shrink := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	shrink.tween_property(_sprite, "scale", Vector2(PX, PX) * 0.5, SHRINK_SECONDS)
	await shrink.finished
	_sprite.scale = Vector2(PX, PX)
	_shadow.visible = true
	velocity = (throw_velocity * THROW_SCALE).limit_length(MAX_SPEED)
	if velocity.length() < MIN_SPEED:
		var direction := velocity.normalized() if velocity.length() > 1.0 else Vector2.from_angle(randf() * TAU)
		velocity = direction * MIN_SPEED
	_rolling = true
	_refresh_frame()
	# Quique curto ao tocar o chão.
	var hop := create_tween()
	hop.tween_method(_set_hop, HOP_HEIGHT, 0.0, 0.14).set_ease(Tween.EASE_IN)
	hop.tween_method(_set_hop, 0.0, HOP_HEIGHT * 0.4, 0.09).set_ease(Tween.EASE_OUT)
	hop.tween_method(_set_hop, HOP_HEIGHT * 0.4, 0.0, 0.09).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(ARM_SECONDS).timeout
	_rolling = false
	velocity = Vector2.ZERO
	# Pisca antes de ativar.
	var arm := create_tween()
	arm.tween_property(_sprite, "modulate", Color(2.0, 2.0, 2.0), 0.06)
	arm.tween_property(_sprite, "modulate", Color.WHITE, 0.06)
	await arm.finished


## Some depois que o feitiço terminou.
func vanish() -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.2)
	fade.tween_callback(queue_free)


func _set_hop(value: float) -> void:
	_hop = value


func _process(delta: float) -> void:
	if _rolling:
		velocity *= exp(-FRICTION * delta)
		position += velocity * delta
		_bounce()
	var moved := position - _last_position
	_last_position = position
	if moved.length_squared() > 0.0001 and _shadow.visible:
		_distance += moved.length()
		_direction = posmod(roundi(moved.angle() / TAU * DIRECTIONS), DIRECTIONS)
		_refresh_frame()
	# Desenho alinhado à grade do pixel, mesmo com a posição em float.
	var snapped_global := Vector2(snappedf(global_position.x, PX), snappedf(global_position.y, PX))
	var offset := snapped_global - global_position
	_shadow.position = offset + Vector2(0.0, 3.0 * PX)
	_sprite.position = offset - Vector2(0.0, snappedf(_hop, PX))


func _bounce() -> void:
	if position.x < bounds.position.x or position.x > bounds.end.x:
		position.x = clampf(position.x, bounds.position.x, bounds.end.x)
		velocity.x = -velocity.x * 0.6
	if position.y < bounds.position.y or position.y > bounds.end.y:
		position.y = clampf(position.y, bounds.position.y, bounds.end.y)
		velocity.y = -velocity.y * 0.6


func _refresh_frame() -> void:
	if not _shadow.visible:
		return
	var turn := _distance / RADIUS_SCREEN
	var frame := posmod(int(floor(turn / (TAU / FRAMES))), FRAMES)
	_sprite.texture = ball_frame(color, _direction, frame)


## Esfera 8x8: aro de vidro, miolo na cor do feitiço com 4 tons de luz, faixa
## clara e duas pintas escuras (polos) que giram com o rolamento, e um brilho fixo.
static func ball_frame(ball_color: Color, direction: int, frame: int) -> ImageTexture:
	var key := "%s:%d:%d" % [ball_color.to_html(), direction, frame]
	if _frame_cache.has(key):
		return _frame_cache[key]
	var forward2 := Vector2.from_angle(TAU * float(direction) / float(DIRECTIONS))
	var forward := Vector3(forward2.x, forward2.y, 0.0)
	var axis := Vector3(-forward2.y, forward2.x, 0.0)
	var angle := TAU * float(frame) / float(FRAMES)
	var light := Vector3(-0.5, -0.6, 0.62).normalized()
	var rim := Color(ArenaPixelArt.HUD_COLOR, 0.95)
	var tones := [ball_color.darkened(0.55), ball_color.darkened(0.25), ball_color, ball_color.lightened(0.3)]
	var stripe := ball_color.lightened(0.55)
	var spot := ball_color.darkened(0.45)
	var radius := SIZE * 0.5 - 0.5
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in range(SIZE):
		for x in range(SIZE):
			var nx := (float(x) + 0.5 - SIZE * 0.5) / radius
			var ny := (float(y) + 0.5 - SIZE * 0.5) / radius
			var rr := nx * nx + ny * ny
			if rr > 1.0:
				continue
			if rr > 0.72:
				image.set_pixel(x, y, rim)
				continue
			var normal := Vector3(nx, ny, sqrt(1.0 - rr))
			var lit := normal.dot(light)
			var tone: Color = tones[0]
			if lit > 0.75:
				tone = tones[3]
			elif lit > 0.45:
				tone = tones[2]
			elif lit > 0.15:
				tone = tones[1]
			# Ponto do material: desfaz o giro para saber se cai na faixa.
			var surface := normal.rotated(axis, -angle)
			var along := surface.dot(forward)
			if absf(along) < 0.22:
				tone = stripe
			elif absf(along) > 0.86:
				# Pinta: cruza o centro quando a faixa está na borda.
				tone = spot
			image.set_pixel(x, y, tone)
	image.set_pixel(2, 2, Color(1.0, 1.0, 1.0, 0.95))
	var texture := ImageTexture.create_from_image(image)
	_frame_cache[key] = texture
	return texture
