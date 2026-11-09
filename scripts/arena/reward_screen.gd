extends Control

## Tela entre salas: diz o que voltou para a bolsa (reembolso e bônus) e
## oferece 3 runas; o jogador escolhe uma. Quantidade negativa = runa de
## lógica nova (infinita). Tudo em pixel art de uma cor só.

signal picked(kind: String, amount: int)

const PX := ArenaPixelArt.PIXEL
const CARD_SIZE := Vector2(300.0, 220.0)
const CARD_GAP := 24.0

var title := ""
var summary := ""
## [{kind, amount, icon: Texture2D, name, description}]
var offers: Array = []

var _cards: Array[Rect2] = []
var _hovered := -1


func _ready() -> void:
	# No _ready o nó já está na árvore: sem "and_offsets" ele manteria tamanho 0.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _layout_cards() -> void:
	_cards.clear()
	var total := offers.size() * CARD_SIZE.x + (offers.size() - 1) * CARD_GAP
	var x := snappedf((size.x - total) * 0.5, PX)
	var y := snappedf(size.y * 0.5 - CARD_SIZE.y * 0.5 + 30.0, PX)
	for index in range(offers.size()):
		_cards.append(Rect2(Vector2(x + index * (CARD_SIZE.x + CARD_GAP), y), CARD_SIZE))


func _gui_input(event: InputEvent) -> void:
	_layout_cards()
	if event is InputEventMouseMotion:
		var index := _card_at(event.position)
		if index != _hovered:
			_hovered = index
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index := _card_at(event.position)
		if index >= 0:
			accept_event()
			picked.emit(str(offers[index]["kind"]), int(offers[index]["amount"]))


func _card_at(point: Vector2) -> int:
	for index in range(_cards.size()):
		if _cards[index].has_point(point):
			return index
	return -1


func _draw() -> void:
	_layout_cards()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.09, 0.78))
	var font := ArenaPixelArt.FONT
	var tiny := ArenaPixelArt.FONT_TINY
	var top := _cards[0].position.y if not _cards.is_empty() else size.y * 0.4
	draw_string(font, Vector2(0.0, top - 92.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_SIZE, ArenaPixelArt.tint(1.0))
	draw_string(tiny, Vector2(0.0, top - 58.0), summary, HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.7))
	draw_string(tiny, Vector2(0.0, top - 22.0), "Escolha uma runa:", HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.85))
	for index in range(_cards.size()):
		var card := _cards[index]
		var offer: Dictionary = offers[index]
		var lift := PX * 2.0 if index == _hovered else 0.0
		card.position.y -= lift
		ArenaPixelArt.draw_pixel_frame(self, card)
		if index == _hovered:
			ArenaPixelArt.draw_pixel_frame(self, card.grow(PX * 2.0))
		var rarity := int(offer.get("rarity", 0))
		var rarity_color: Color = ArenaPixelArt.RARITY_COLORS[clampi(rarity, 0, 3)]
		if rarity > 0:
			# Moldura interna e pontinhos na cor da raridade.
			ArenaPixelArt.draw_pixel_frame(self, card.grow(-PX * 2.0))
			draw_rect(Rect2(card.position + Vector2(PX * 2.0, PX * 2.0), Vector2(card.size.x - PX * 4.0, PX)), rarity_color)
			for pip in range(rarity):
				draw_rect(Rect2(card.position + Vector2(PX * 4.0 + pip * PX * 3.0, PX * 5.0), Vector2(PX * 2.0, PX * 2.0)), rarity_color)
		var icon: Texture2D = offer.get("icon")
		if icon != null:
			draw_texture_rect(icon, Rect2(card.position + Vector2(card.size.x * 0.5 - 32.0, 20.0), Vector2(64.0, 64.0)), false, rarity_color if rarity > 0 else ArenaPixelArt.tint(1.0))
		var amount := int(offer["amount"])
		var name_line := "%s  +%d" % [offer["name"], amount] if amount > 0 else "%s  NOVA" % offer["name"]
		draw_string(font, card.position + Vector2(0.0, 112.0), name_line, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, ArenaPixelArt.FONT_SIZE, rarity_color if rarity > 0 else ArenaPixelArt.tint(1.0))
		draw_multiline_string(tiny, card.position + Vector2(16.0, 142.0), str(offer["description"]), HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 32.0, ArenaPixelArt.FONT_TINY_SIZE, 4, ArenaPixelArt.tint(0.7))
