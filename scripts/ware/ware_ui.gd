extends RefCounted

## Peças de interface do Atelier Ware no mesmo estilo pixel da arena.

const PX := ArenaPixelArt.PIXEL
const HEART := [
	".kk.kk.",
	"krrkrrk",
	"krwrrrk",
	"krrrrrk",
	".krrrk.",
	"..krk..",
	"...k...",
]


static func button(label: String, big := true) -> Button:
	var node := Button.new()
	node.text = label
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_override("font", ArenaPixelArt.FONT if big else ArenaPixelArt.FONT_TINY)
	node.add_theme_font_size_override("font_size", ArenaPixelArt.FONT_SIZE if big else ArenaPixelArt.FONT_TINY_SIZE)
	node.add_theme_color_override("font_color", ArenaPixelArt.tint(0.9))
	node.add_theme_color_override("font_hover_color", ArenaPixelArt.tint(1.0))
	node.add_theme_color_override("font_pressed_color", ArenaPixelArt.tint(1.0))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.02, 0.04, 0.09, 0.9) if state != "pressed" else Color(0.08, 0.12, 0.22, 0.95)
		box.border_color = ArenaPixelArt.tint(1.0 if state == "hover" else (0.3 if state == "disabled" else 0.7))
		box.set_border_width_all(int(PX))
		box.set_corner_radius_all(0)
		node.add_theme_stylebox_override(state, box)
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return node


static func draw_heart(canvas: CanvasItem, top_left: Vector2, full: bool) -> void:
	var palette := {"k": Color("1b1724"), "r": Color("e8452c") if full else Color("2a3350"), "w": Color("ffb0a0") if full else Color("2a3350")}
	for y in range(HEART.size()):
		var row: String = HEART[y]
		for x in range(row.length()):
			if palette.has(row[x]):
				canvas.draw_rect(Rect2(top_left + Vector2(x, y) * PX, Vector2(PX, PX)), palette[row[x]])


## Caixa escura com moldura pixel (para faixas e cartões).
static func draw_box(canvas: CanvasItem, rect: Rect2, border := ArenaPixelArt.tint(0.7)) -> void:
	canvas.draw_rect(rect, Color(0.02, 0.04, 0.09, 0.92))
	ArenaPixelArt.draw_pixel_frame(canvas, rect)
	if border != ArenaPixelArt.tint(0.7):
		canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, PX)), border)
		canvas.draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - PX), Vector2(rect.size.x, PX)), border)
