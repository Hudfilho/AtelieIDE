extends Node2D

## Explosão do feitiço com os shaders pixel art (effects/): fogo usa a bola de
## fogo, gelo o vórtice de gelo (o chão fica congelado enquanto dura o
## congelamento), raio a onda elétrica. Sem elemento, a bola de fogo recebe a
## paleta violeta arcana. Cada pixel do shader mede PX na tela.

const Fireball = preload("res://effects/fire/fireball_pixel.tscn")
const Electric = preload("res://effects/electric/electric_pixel.tscn")
const Ice = preload("res://effects/ice/ice_pixel.tscn")
const PX := ArenaPixelArt.PIXEL
## O anel dos shaders chega a ~0,84 do raio do quadrado; o desenho cobre o raio de dano.
const VISUAL_REACH := 0.84

const ARCANE_PALETTE := {
	"core_color": Color(0.96, 0.92, 1.0),
	"yellow_color": Color(0.80, 0.66, 1.0),
	"orange_color": Color(0.58, 0.40, 0.95),
	"red_color": Color(0.33, 0.18, 0.62),
	"smoke_color": Color(0.17, 0.14, 0.28),
}

var radius := 60.0
var element := ""
## Segundos de congelamento (o chão de gelo dura o mesmo tanto).
var freeze := 0.0


func _ready() -> void:
	var scene: PackedScene = Fireball
	match element:
		"ice":
			scene = Ice
		"lightning":
			scene = Electric
	var effect := scene.instantiate()
	var resolution := clampi(int(ceil(radius * 2.0 / VISUAL_REACH / PX)), 16, 128)
	effect.pixel_resolution = resolution
	effect.diameter = resolution * PX
	if element == "ice":
		effect.frozen_duration = maxf(freeze, 0.5)
	effect.finished.connect(queue_free)
	add_child(effect)
	if element == "":
		var material: ShaderMaterial = effect._material
		for key in ARCANE_PALETTE:
			material.set_shader_parameter(key, ARCANE_PALETTE[key])
