extends Control

## Fim da run: sem orbes, sem Explosão ou sem mana com esqueletos vivos.

signal restart_requested

var room := 1


func _ready() -> void:
	# No _ready o nó já está na árvore: sem "and_offsets" ele manteria tamanho 0.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var button := Button.new()
	button.text = "RECOMEÇAR"
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", ArenaPixelArt.FONT)
	button.add_theme_font_size_override("font_size", ArenaPixelArt.FONT_SIZE)
	button.add_theme_color_override("font_color", ArenaPixelArt.tint(0.9))
	button.add_theme_color_override("font_hover_color", ArenaPixelArt.tint(1.0))
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.02, 0.04, 0.09, 0.9)
		box.border_color = ArenaPixelArt.tint(1.0 if state == "hover" else 0.7)
		box.set_border_width_all(int(ArenaPixelArt.PIXEL))
		box.set_corner_radius_all(0)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button.offset_left = -130.0
	button.offset_right = 130.0
	button.offset_top = 40.0
	button.offset_bottom = 100.0
	button.pressed.connect(func() -> void: restart_requested.emit())
	add_child(button)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 0.85))
	var mid := size.y * 0.5
	draw_string(ArenaPixelArt.FONT, Vector2(0.0, mid - 60.0), "SEM MAGIAS", HORIZONTAL_ALIGNMENT_CENTER, size.x, 44, Color("ff9a8a"))
	draw_string(ArenaPixelArt.FONT_TINY, Vector2(0.0, mid - 16.0), "Você caiu na sala %d." % room, HORIZONTAL_ALIGNMENT_CENTER, size.x, ArenaPixelArt.FONT_TINY_SIZE, ArenaPixelArt.tint(0.8))
