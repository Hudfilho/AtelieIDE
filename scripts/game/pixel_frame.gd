class_name AtelierPixelFrame
extends CanvasLayer

## Moldura do balcão em pixel art. O SubViewport fica sempre em BASE_SIZE e é
## mostrado com a MAIOR ESCALA INTEIRA que cabe na janela, centralizado; o que
## sobra vira tarja (Letterbox, numa camada abaixo). Nunca há escala
## fracionária no balcão. A bancada de runas e os cartões do dia não passam
## por aqui.
##
## Por que um CanvasLayer: o Godot arredonda a posição de todo Control para o
## pixel LÓGICO (gui/common/snap_controls_to_pixels). Com a janela 1280x720
## esticada para, por exemplo, 1366x768, um pixel lógico inteiro não cai num
## pixel físico inteiro e o balcão desalinha. A transformação de uma camada
## não sofre esse arredondamento, então é ela que posiciona e escala o balcão.

const BASE_SIZE := Vector2i(640, 360)
## Folga (px físicos) para o balcão cair no pixel inteiro certo; ver apply_fit.
const PIXEL_BIAS := 0.25

## O contêiner que mostra o SubViewport do balcão, filho desta camada.
@export var view: SubViewportContainer

## Escala inteira em uso (1, 2, 3...), para testes e depuração.
var desk_scale := 1


func _ready() -> void:
	view.stretch = false
	view.position = Vector2.ZERO
	view.size = Vector2(BASE_SIZE)
	for child in view.get_children():
		if child is SubViewport:
			(child as SubViewport).size = BASE_SIZE
	get_tree().root.size_changed.connect(refit)
	refit()


## Maior escala inteira que cabe em window_size e o retângulo centralizado que
## o balcão ocupa, em pixels físicos: {"scale": int, "rect": Rect2i}.
static func fit(window_size: Vector2i, base := BASE_SIZE) -> Dictionary:
	var scale := maxi(1, mini(window_size.x / base.x, window_size.y / base.y))
	var fitted := base * scale
	return {"scale": scale, "rect": Rect2i((window_size - fitted) / 2, fitted)}


func refit() -> void:
	var window := get_window()
	apply_fit(window.size, window.get_final_transform().get_scale())


## Posiciona a camada para o tamanho físico da janela. As coordenadas da camada
## são lógicas (janela 1280x720, stretch canvas_items), então a escala lógica
## é k / (lógico->físico): na tela ela vira exatamente k.
func apply_fit(window_size: Vector2i, logical_to_physical: Vector2) -> void:
	var result := fit(window_size)
	var rect: Rect2i = result["rect"]
	desk_scale = result["scale"]
	var layer_scale := Vector2(float(desk_scale), float(desk_scale)) / logical_to_physical
	# Mira um quarto de pixel para dentro: a ida e volta lógico->físico em float
	# pode cair em 23.9999 em vez de 24. Com a folga, arredondando ou truncando,
	# o balcão começa no pixel inteiro certo, e os texels continuam exatos.
	var origin := (Vector2(rect.position) + Vector2(PIXEL_BIAS, PIXEL_BIAS)) / logical_to_physical
	transform = Transform2D(0.0, layer_scale, 0.0, origin)
