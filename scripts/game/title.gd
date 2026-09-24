extends Control

## Tela inicial do demo: começa o dia de loja ou abre a IDE livre (sandbox).


func _ready() -> void:
	%PlayButton.pressed.connect(_on_play)
	%SandboxButton.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())
	%PlayButton.grab_focus()


func _on_play() -> void:
	GameState.new_game()
	get_tree().change_scene_to_file("res://scenes/game/Desk.tscn")
