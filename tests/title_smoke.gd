extends SceneTree

## Tela de título: a ilustração e os botões ficam num palco de 1280x720 que
## escala junto para cobrir a janela, sem distorcer. Em qualquer proporção
## comum o logotipo pintado e todos os botões ficam inteiros na tela, sem se
## sobrepor; os textos traduzidos cabem nos botões; a fonte (Cormorant
## Garamond) tem todos os caracteres, nos dois idiomas; e o primeiro botão
## começa com o foco (teclado e controle).

## Logotipo pintado (emblema, "Atelier" e o florão de baixo), em px do palco.
const LOGO := Rect2(551, 61, 184, 230)
## Tamanhos lógicos da janela (stretch canvas_items + expand): 16:9, 16:10,
## 21:9 e 4:3.
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(1024, 768)]
const TEXT_KEYS: Array[String] = ["TITLE_TAGLINE", "TITLE_PLAY", "TITLE_SANDBOX", "TITLE_QUIT", "TITLE_DESK_STYLE"]


func _initialize() -> void:
	call_deferred("_run")


func _frames(count := 3) -> void:
	for frame in count:
		await process_frame


func _run() -> void:
	AtelierDeskStyles.settings_path = "user://title_smoke_settings.cfg"
	var title = load("res://scenes/game/Title.tscn").instantiate()
	root.add_child(title)
	await _frames()
	var stage := title.get_node("%Stage") as Control
	var buttons: Array[Control] = [title.get_node("%PlayButton"), title.get_node("%SandboxButton"), title.get_node("%QuitButton"), title.get_node("%StyleOption")]
	assert((title.get_node("%PlayButton") as Control).has_focus(), "The first button starts focused")

	for window in WINDOWS:
		root.size = window
		await _frames()
		var view := Rect2(Vector2.ZERO, title.size)
		assert(stage.scale.x == stage.scale.y, "The stage keeps its proportions")
		var stage_rect := stage.get_global_rect()
		assert(stage_rect.grow(0.5).encloses(view), "%s: the stage %s does not cover the window %s" % [window, stage_rect, view])
		var logo := Rect2(stage.global_position + LOGO.position * stage.scale, LOGO.size * stage.scale)
		assert(view.grow(1.0).encloses(logo), "%s: the painted logo %s is cut off (window %s)" % [window, logo, view])
		for i in buttons.size():
			var rect := buttons[i].get_global_rect()
			assert(view.encloses(rect), "%s: %s leaves the window" % [window, buttons[i].name])
			for j in range(i + 1, buttons.size()):
				assert(not rect.intersects(buttons[j].get_global_rect()), "%s: %s overlaps %s" % [window, buttons[i].name, buttons[j].name])

	# Os textos (no idioma atual) cabem nos botões e na linha da frase.
	root.size = Vector2i(1280, 720)
	await _frames()
	for button: Control in buttons:
		assert(button.get_combined_minimum_size().x <= button.size.x + 0.5, "%s text does not fit: %s > %s" % [button.name, button.get_combined_minimum_size().x, button.size.x])
	var tagline := title.get_node("%Tagline") as Label
	assert(tagline.get_line_count() <= 2 and tagline.get_global_rect().end.y <= (title.get_node("%PlayButton") as Control).get_global_rect().position.y, "The tagline runs into the buttons")

	# A fonte do título tem todos os caracteres dos textos, nos dois idiomas.
	var font := load("res://art/fonts/cormorant_garamond/CormorantGaramond-Variable.ttf") as FontFile
	var missing := {}
	for locale in ["en", "pt_BR"]:
		var table := TranslationServer.get_translation_object(locale)
		var texts: PackedStringArray = []
		for key in TEXT_KEYS:
			texts.append(String(table.get_message(key)))
		for style in AtelierDeskStyles.all():
			texts.append(String(table.get_message(style.title_key)))
		for text in texts:
			for index in text.length():
				if not font.has_char(text.unicode_at(index)):
					missing[text[index]] = true
	assert(missing.is_empty(), "Cormorant Garamond is missing: %s" % " ".join(PackedStringArray(missing.keys())))

	title.queue_free()
	await process_frame
	print("TITLE_SMOKE_OK")
	quit(0)
