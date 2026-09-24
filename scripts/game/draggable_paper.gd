extends PanelContainer

## Papel sobre a mesa: arraste com o botão esquerdo; o papel tocado vai para
## cima da pilha, como em Papers, Please.

signal picked_up


var _dragging := false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			move_to_front()
			picked_up.emit()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		position += event.relative
		_keep_inside_parent()
		accept_event()


func _keep_inside_parent() -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var limit := parent_control.size - size
	position = position.clamp(Vector2(-size.x * 0.5, 0.0), limit + Vector2(size.x * 0.5, size.y * 0.5))
