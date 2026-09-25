extends Control

## Tela inicial do demo: começa o dia de loja ou abre a IDE livre (sandbox),
## e escolhe o estilo de arte do balcão (fica salvo para as próximas vezes).

@onready var style_option: OptionButton = %StyleOption


func _ready() -> void:
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
