extends Node2D

## Esqueleto pixel art 2.5D. O corpo é montado por partes (crânio, costelas,
## braços, pernas) em 4 quadros de caminhada e 2 de respiração. A origem do nó
## fica nos pés (para o y-sort da arena) com uma sombra no chão; o sprite
## sobe da terra ao nascer, pula para trás com o golpe (altura falsa), pisca,
## mostra o dano, congela, treme atordoado e desmonta em ossos quando morre.

const BoneDebris = preload("res://scripts/arena/bone_debris.gd")
const FloatText = preload("res://scripts/arena/float_text.gd")

const PIXEL := 4.0
const W := 16
const H := 20
## Primeira linha abaixo dos pés: o chão do sprite.
const FEET_ROW := 19
const PALETTE := {
	"k": Color("1b1724"), "w": Color("eee8d8"), "b": Color("c7bfa9"),
	"s": Color("8d8574"), "E": Color("ff7a3d"),
}
const HEAD := [
	"..kkkk..",
	".kwwwwk.",
	"kwswwswk",
	"kwEwwEbk",
	"kwwbbwbk",
	".kbkkbk.",
	"..kkkk..",
]
const TORSO := [
	"...kk...",
	".kkwwkk.",
	"kwbkkbwk",
	"kbwkkwbk",
	".kbwwbk.",
	"..kbbk..",
]
const ARM := ["kkk", "kwk", "kbk", "kwk", "kwk", ".k."]
const LEG := ["kwk", "kwk", "kbk", "kwk", "kwk", "kkk"]
## Pose: [balanço do corpo, perna esq. erguida, perna dir. erguida, braço esq., braço dir.]
const WALK_POSES := [[0, 1, 0, 1, -1], [1, 0, 0, 0, 0], [0, 0, 1, -1, 1], [1, 0, 0, 0, 0]]
const IDLE_POSES := [[0, 0, 0, 0, 0], [1, 0, 0, 0, 0]]
const SHADOW := ["..######..", ".########.", "..######.."]
const WALK_FPS := 8.0
const IDLE_FPS := 2.0
const GRAVITY := 900.0
const RISE_SECONDS := 0.7
const FLASH_SECONDS := 0.15

static var _walk_frames: Array = []
static var _idle_frames: Array = []

var bounds := Rect2(0.0, 0.0, 1280.0, 720.0)
var speed := 40.0
var max_hp := 30
var hp := 30
var alive := true

var _sprite: Sprite2D
var _shadow: Sprite2D
var _target := Vector2.ZERO
var _idle_left := 0.0
var _clock := 0.0
var _walking := false
var _z := 0.0
var _vz := 0.0
var _knock := Vector2.ZERO
var _frozen := 0.0
var _stunned := 0.0
var _flash := 0.0
var _rising := RISE_SECONDS
var _dust: Array = []


func _ready() -> void:
	_ensure_frames()
	hp = max_hp
	_shadow = Sprite2D.new()
	_shadow.texture = ArenaPixelArt.texture("skeleton_shadow", SHADOW, {"#": Color(0.0, 0.0, 0.0, 0.35)})
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.scale = Vector2(PIXEL, PIXEL)
	add_child(_shadow)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _idle_frames[0]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(PIXEL, PIXEL)
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, W, 0)
	add_child(_sprite)
	speed = randf_range(28.0, 55.0)
	_idle_left = randf_range(0.3, 1.5)
	_pick_target()
	for index in range(6):
		_dust.append(Vector2(randf_range(-7.0, 7.0), randf_range(-1.0, 1.0)) * PIXEL)


func _process(delta: float) -> void:
	if not alive:
		return
	_clock += delta
	if _rising > 0.0:
		_update_rise(delta)
		return
	_frozen = maxf(_frozen - delta, 0.0)
	_stunned = maxf(_stunned - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_update_physics(delta)
	_walking = false
	if _frozen <= 0.0 and _stunned <= 0.0 and _z <= 0.0 and _knock.length() < 20.0:
		_wander(delta)
	_animate()


## Sai da terra de cabeça para cima: mostra só as linhas de cima do sprite,
## com a base sempre no chão, e levanta poeira.
func _update_rise(delta: float) -> void:
	_rising = maxf(_rising - delta, 0.0)
	var shown := 1.0 - _rising / RISE_SECONDS
	var rows := maxi(1, roundi(FEET_ROW * shown))
	_sprite.region_rect = Rect2(0, 0, W, rows)
	_sprite.position = Vector2(-W * PIXEL * 0.5, -rows * PIXEL)
	queue_redraw()
	if _rising <= 0.0:
		_sprite.region_enabled = false
		_animate()


func _draw() -> void:
	if _rising <= 0.0:
		return
	var alpha := clampf(_rising / RISE_SECONDS, 0.0, 1.0)
	for index in range(_dust.size()):
		var puff: Vector2 = _dust[index]
		var lift := (1.0 - alpha) * PIXEL * (2.0 + index % 3)
		var at := Vector2(snappedf(puff.x, PIXEL), snappedf(puff.y - lift, PIXEL))
		draw_rect(Rect2(at, Vector2(PIXEL, PIXEL) * (2.0 if index % 2 == 0 else 1.0)), Color(0.55, 0.6, 0.72, 0.6 * alpha))


func _update_physics(delta: float) -> void:
	if _knock.length_squared() > 1.0:
		position += _knock * delta
		_knock *= exp(-6.0 * delta)
		position = position.clamp(bounds.position, bounds.end)
	if _z > 0.0 or _vz > 0.0:
		_vz -= GRAVITY * delta
		_z += _vz * delta
		if _z <= 0.0:
			_z = 0.0
			_vz = -_vz * 0.3 if _vz < -150.0 else 0.0


func _wander(delta: float) -> void:
	if _idle_left > 0.0:
		_idle_left -= delta
		return
	var to_target := _target - position
	if to_target.length() < 3.0:
		_idle_left = randf_range(0.6, 2.2)
		_pick_target()
		return
	var step := to_target.normalized() * speed * delta
	position += step
	_walking = true
	if absf(step.x) > 0.01:
		_sprite.flip_h = step.x < 0.0


func _animate() -> void:
	if _frozen > 0.0:
		_sprite.texture = _walk_frames[0]
	elif _walking:
		_sprite.texture = _walk_frames[int(_clock * WALK_FPS) % _walk_frames.size()]
	else:
		_sprite.texture = _idle_frames[int(_clock * IDLE_FPS) % _idle_frames.size()]
	var shake := 0.0
	if _stunned > 0.0:
		shake = PIXEL if int(_clock * 20.0) % 2 == 0 else -PIXEL
	_sprite.position = Vector2(-W * PIXEL * 0.5 + shake, -FEET_ROW * PIXEL - snappedf(_z, PIXEL))
	var lift := clampf(_z / (20.0 * PIXEL), 0.0, 0.45)
	_shadow.scale = Vector2(PIXEL * (1.0 - lift), PIXEL)
	_shadow.modulate.a = 1.0 - lift
	var tint := Color.WHITE
	if _frozen > 0.0:
		tint = Color(0.62, 0.86, 1.0)
	if _stunned > 0.0 and int(_clock * 12.0) % 2 == 0:
		tint = Color(1.0, 0.95, 0.55)
	if _flash > 0.0:
		tint = Color(1.0, 0.42, 0.36)
	_sprite.modulate = tint


## Dano de feitiço vindo de `from`: pisca, mostra o número, é jogado para
## longe com um pulo e, ao zerar, desmonta em ossos.
func take_damage(amount: int, from := Vector2.INF) -> void:
	if not alive:
		return
	if _rising > 0.0:
		_rising = 0.0
		_sprite.region_enabled = false
	hp -= amount
	_flash = FLASH_SECONDS
	var away := Vector2.from_angle(randf() * TAU) if from == Vector2.INF or position.distance_to(from) < 1.0 else (position - from).normalized()
	_knock = away * (80.0 + amount * 1.5)
	_vz = 160.0
	_float_text("-%d" % amount)
	if hp <= 0:
		_die(away)


func freeze(seconds: float) -> void:
	if alive and seconds > 0.0:
		_frozen = maxf(_frozen, seconds)


func stun(seconds: float) -> void:
	if alive and seconds > 0.0:
		_stunned = maxf(_stunned, seconds)


func _die(direction: Vector2) -> void:
	alive = false
	var debris := BoneDebris.new()
	debris.position = position
	debris.direction = direction
	debris.skull_rows = HEAD
	debris.skull_palette = PALETTE
	get_parent().add_child(debris)
	queue_free()


func _float_text(text: String) -> void:
	var label := FloatText.new()
	label.text = text
	label.position = position + Vector2(0.0, -FEET_ROW * PIXEL - 6.0)
	label.z_index = 20
	get_parent().add_child(label)


func _pick_target() -> void:
	_target = Vector2(
		randf_range(bounds.position.x, bounds.end.x),
		randf_range(bounds.position.y, bounds.end.y),
	)


## ======================== QUADROS ========================

static func _ensure_frames() -> void:
	if not _walk_frames.is_empty():
		return
	for index in range(WALK_POSES.size()):
		_walk_frames.append(_compose("skeleton_walk_%d" % index, WALK_POSES[index]))
	for index in range(IDLE_POSES.size()):
		_idle_frames.append(_compose("skeleton_idle_%d" % index, IDLE_POSES[index]))


## Monta um quadro 16x20: pernas, tronco, crânio e braços, nessa ordem.
static func _compose(_key: String, pose: Array) -> ImageTexture:
	var bob := int(pose[0])
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	_stamp(image, LEG, 4, 13 - int(pose[1]))
	_stamp(image, LEG, 9, 13 - int(pose[2]))
	_stamp(image, TORSO, 4, 7 + bob)
	_stamp(image, HEAD, 4, 0 + bob)
	_stamp(image, ARM, 1, 8 + bob + int(pose[3]))
	_stamp(image, ARM, 12, 8 + bob + int(pose[4]))
	return ImageTexture.create_from_image(image)


static func _stamp(image: Image, rows: Array, origin_x: int, origin_y: int) -> void:
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row[x]
			var px := origin_x + x
			var py := origin_y + y
			if PALETTE.has(key) and px >= 0 and py >= 0 and px < W and py < H:
				image.set_pixel(px, py, PALETTE[key])
