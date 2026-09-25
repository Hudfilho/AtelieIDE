extends Control

## Tela inicial do demo: começa o dia de loja ou abre a IDE livre (sandbox),
## e escolhe o estilo de arte do balcão (fica salvo para as próximas vezes).
## A ilustração tem o logotipo pintado e os botões ficam onde estavam os
## pintados, então fundo e botões estão num palco de 1280x720 que escala
## junto para cobrir a janela (tools/title_art/import_title_art.py).

## Tamanho do palco (o da ilustração na tela).
const STAGE_SIZE := Vector2(1280, 720)
## Quando a janela é mais larga que 16:9, o palco corta mais embaixo (mesa)
## do que em cima (logotipo): fração do corte vertical que sai de cima.
const CROP_FROM_TOP := 0.3

@onready var stage: Control = %Stage
@onready var style_option: OptionButton = %StyleOption


func _ready() -> void:
	resized.connect(fit_stage)
	fit_stage()
	var preferred := AtelierDeskStyles.preferred()
	for style in AtelierDeskStyles.all():
		style_option.add_item(tr(style.title_key))
		if style.id == preferred.id:
			style_option.select(style_option.item_count - 1)
	style_option.item_selected.connect(func(index: int) -> void: AtelierDeskStyles.remember(AtelierDeskStyles.all()[index]))
	%PlayButton.pressed.connect(_on_play)
	%SandboxButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())
	%PlayButton.grab_focus()


func _on_play() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file("res://scenes/game/Desk.tscn")


## Escala o palco para cobrir a janela sem distorcer, centrado na horizontal.
func fit_stage() -> void:
	var scale_factor := maxf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
	stage.scale = Vector2(scale_factor, scale_factor)
	var spare := size - STAGE_SIZE * scale_factor
	stage.position = Vector2(spare.x * 0.5, spare.y * CROP_FROM_TOP)
