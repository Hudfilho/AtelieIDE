class_name AtelierUITheme
extends RefCounted

## Constrói o Theme usado pelos nós de interface. O canvas do diagrama mantém
## seu desenho próprio, mas botões, listas, campos e barras passam a usar o
## sistema de tema do Godot.


static func build(palette: Dictionary) -> Theme:
	var theme := Theme.new()
	var text: Color = palette["text"]
	var text_faint: Color = palette["text_faint"]
	var gold: Color = palette["gold"]
	var gold_bright: Color = palette["gold_bright"]
	var gold_glow: Color = palette["gold_glow"]
	var brass: Color = palette["brass"]
	var frame: Color = Color(palette["frame_top"]).lerp(palette["frame_bottom"], 0.5)
	var inset: Color = palette["inset_deep"]
	var disabled: Color = palette["disabled"]

	var panel_box := _box(frame, brass, 10, 1, palette["frame_shadow"], 9)
	panel_box.content_margin_left = 4.0
	panel_box.content_margin_top = 4.0
	panel_box.content_margin_right = 4.0
	panel_box.content_margin_bottom = 4.0
	theme.set_stylebox("panel", "PanelContainer", panel_box)
	theme.set_stylebox("panel", "MarginContainer", StyleBoxEmpty.new())

	var button_normal := _box(palette["inset"], brass, 7, 1)
	var button_hover := _box(Color(palette["inset"]).lerp(gold, 0.18), gold_bright, 7, 1)
	var button_pressed := _box(Color(palette["inset"]).lerp(gold, 0.28), gold_glow, 7, 1)
	var button_disabled := _box(Color(palette["inset"]).darkened(0.25), disabled, 7, 1)
	for button_type: String in ["Button", "RuneTileButton"]:
		theme.set_stylebox("normal", button_type, button_normal)
		theme.set_stylebox("hover", button_type, button_hover)
		theme.set_stylebox("pressed", button_type, button_pressed)
		theme.set_stylebox("focus", button_type, button_hover)
		theme.set_stylebox("disabled", button_type, button_disabled)
		theme.set_color("font_color", button_type, text)
		theme.set_color("font_hover_color", button_type, gold_glow)
		theme.set_color("font_pressed_color", button_type, gold_bright)
		theme.set_color("font_disabled_color", button_type, disabled)
		theme.set_font_size("font_size", button_type, 13)

	theme.set_color("font_color", "Label", text)
	theme.set_color("font_shadow_color", "Label", palette["title_shadow"])
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_font_size("font_size", "Label", 13)

	var text_panel := _box(inset, Color(brass, 0.72), 7, 1)
	theme.set_stylebox("normal", "RichTextLabel", text_panel)
	theme.set_color("default_color", "RichTextLabel", text)
	theme.set_color("font_selected_color", "RichTextLabel", palette["ink_deep"])
	theme.set_color("selection_color", "RichTextLabel", Color(gold_glow, 0.72))
	theme.set_font_size("normal_font_size", "RichTextLabel", 13)

	for line_type: String in ["LineEdit", "SpinBox"]:
		theme.set_stylebox("normal", line_type, _box(inset, brass, 6, 1))
		theme.set_stylebox("focus", line_type, _box(inset, gold_glow, 6, 2))
		theme.set_color("font_color", line_type, text)
		theme.set_color("font_selected_color", line_type, palette["ink_deep"])
		theme.set_color("selection_color", line_type, Color(gold_glow, 0.72))

	var slider_track := _box(inset, brass, 3, 1)
	var slider_fill := _box(gold, gold_bright, 3, 1)
	theme.set_stylebox("slider", "HSlider", slider_track)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)
	theme.set_icon("grabber", "HSlider", _circle_texture(14, gold_glow, brass))
	theme.set_icon("grabber_highlight", "HSlider", _circle_texture(14, gold_glow.lightened(0.12), gold_bright))

	var scrollbar_track := _box(Color(inset, 0.55), Color(brass, 0.35), 4, 0)
	var scrollbar_grabber := _box(Color(brass, 0.85), gold, 4, 0)
	for scrollbar_type: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", scrollbar_type, scrollbar_track)
		theme.set_stylebox("grabber", scrollbar_type, scrollbar_grabber)
		theme.set_stylebox("grabber_highlight", scrollbar_type, _box(gold, gold_bright, 4, 0))
		theme.set_stylebox("grabber_pressed", scrollbar_type, _box(gold_bright, gold_glow, 4, 0))

	theme.set_color("separator", "HSeparator", Color(brass, 0.55))
	theme.set_color("separator", "VSeparator", Color(brass, 0.55))
	theme.set_stylebox("panel", "ItemList", text_panel)
	theme.set_stylebox("focus", "ItemList", _box(Color(inset, 0.15), gold, 6, 1))
	theme.set_stylebox("selected", "ItemList", _box(Color(gold, 0.22), gold, 5, 1))
	theme.set_stylebox("selected_focus", "ItemList", _box(Color(gold, 0.30), gold_bright, 5, 1))
	theme.set_color("font_color", "ItemList", text)
	theme.set_color("font_selected_color", "ItemList", gold_glow)
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("separation", "HBoxContainer", 6)
	theme.set_constant("margin_left", "MarginContainer", 6)
	theme.set_constant("margin_top", "MarginContainer", 4)
	theme.set_constant("margin_right", "MarginContainer", 6)
	theme.set_constant("margin_bottom", "MarginContainer", 4)
	return theme


static func _box(
		fill: Color,
		border: Color,
		radius: int,
		border_width: int,
		shadow := Color(0.0, 0.0, 0.0, 0.0),
		shadow_size := 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.shadow_color = shadow
	box.shadow_size = shadow_size
	box.shadow_offset = Vector2(0.0, minf(float(shadow_size) * 0.45, 5.0))
	box.anti_aliasing = true
	box.content_margin_left = 8.0
	box.content_margin_top = 6.0
	box.content_margin_right = 8.0
	box.content_margin_bottom = 6.0
	return box


static func _circle_texture(extent: int, fill: Color, border: Color) -> Texture2D:
	var texture_size := Vector2i(extent, extent)
	var image := Image.create(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(extent), float(extent)) * 0.5
	var radius := float(extent) * 0.5 - 0.75
	for y in range(extent):
		for x in range(extent):
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if distance > radius + 0.5:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			elif distance >= radius - 1.0:
				var edge_alpha := clampf(radius + 0.5 - distance, 0.0, 1.0)
				image.set_pixel(x, y, Color(border, border.a * edge_alpha))
			else:
				image.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(image)
