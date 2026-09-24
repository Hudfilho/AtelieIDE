class_name AtelierDeskFeedback
extends Node

## Retorno tátil do balcão: carimbo que desce e volta, marca de tinta no
## pedido, tremida da mesa e deixas de som. Não conhece regras nem dinheiro:
## o balcão reage a stamp_impact (quando a decisão vale) e a stamp_finished.
## Com instant = true tudo acontece na hora, sem tweens nem esperas; os testes
## headless usam isso para não depender de animação ou áudio.

signal stamp_impact(kind: StringName)
signal stamp_finished(kind: StringName)
## Toda deixa pedida, tocando som ou não. Útil para testes e depuração.
signal sfx_requested(cue: StringName)
signal _hold_released

const APPROVE := &"approve"
const REJECT := &"reject"
const CUES: Array[StringName] = [&"bell", &"stamp_approve", &"stamp_reject", &"paper", &"coins"]

## ---- Tempos do carimbo (segundos). Impacto em TRAVEL + PRESS = 0.23 s. ----
const STAMP_TRAVEL := 0.16
const STAMP_PRESS := 0.07
const STAMP_HOLD := 0.06
const STAMP_LIFT := 0.08
const STAMP_RETURN := 0.16
## Escala do carimbo erguido sobre o papel e no instante da pressão.
const STAMP_LIFTED_SCALE := 1.12
const STAMP_PRESSED_SCALE := 0.96
## Altura (px do balcão em pixel art) em que o carimbo paira antes de descer.
const STAMP_HOVER_HEIGHT := 10.0
## ---- Marca de tinta (sem rotação: texto girado perde a nitidez do pixel) ----
const INK_POP := 0.08
const INK_POP_SCALE := 1.25
const INK_ALPHA := 0.9
## ---- Tremida da mesa, em pixels inteiros do balcão ----
const SHAKE_DURATION := 0.18
const SHAKE_STRENGTH := 2.0
const SHAKE_STEPS := 6

@export var instant := false
## Anuncia as deixas (sfx_requested) sem tocá-las. Testes headless usam isso:
## com o driver de áudio falso, o que chega a tocar fica preso até a saída.
@export var mute := false
## Nó que treme no impacto (o balcão inteiro).
@export var shake_target: Control
## Carimbo que voa até o papel; recebe o sprite do tipo em stamp_sprites.
@export var stamp_head: TextureRect
@export var stamp_sprites: Dictionary[StringName, Texture2D] = {}
## Área reservada no pedido onde a marca cai, longe dos campos de texto.
@export var stamp_target: Control
@export var ink_mark: Label
## Substitui o som provisório de uma deixa (bell, stamp_approve, stamp_reject, paper, coins).
@export var sounds: Dictionary[StringName, AudioStream] = {}

var _active_kind := &""
var _impacted := false
var _stamp_tween: Tween
var _shake_tween: Tween
var _shake_base := Vector2.ZERO
var _paper: Control
var _source_button: Control
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _hold_serial := 0


func _ready() -> void:
	for cue in CUES:
		if not sounds.has(cue) or sounds[cue] == null:
			sounds[cue] = AtelierPlaceholderSfx.build(cue)
	for index in range(4):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	if stamp_head != null:
		stamp_head.hide()
	clear_ink()


## Troca de cena ou saída no meio de um som: para os players em vez de deixar
## reproduções órfãs no AudioServer.
func _exit_tree() -> void:
	for player in _players:
		player.stop()


func is_stamping() -> bool:
	return not _active_kind.is_empty()


## ======================== CARIMBO ========================

## Leva o carimbo do botão até o papel, pressiona e volta. Emite stamp_impact
## no toque e stamp_finished quando o carimbo voltou ao lugar.
func play_stamp(kind: StringName, source_button: Control, paper: Control) -> void:
	if is_stamping():
		return
	_active_kind = kind
	_impacted = false
	_paper = paper
	_source_button = source_button
	if instant or stamp_head == null:
		_impact()
		_finish()
		return
	_dress_stamp_head(kind)
	var home := source_button.global_position + (source_button.size - stamp_head.size) * 0.5
	var pressed_at := _spot() - stamp_head.size * 0.5
	var hover := pressed_at + Vector2(0.0, -STAMP_HOVER_HEIGHT)
	stamp_head.global_position = home
	stamp_head.scale = Vector2.ONE
	stamp_head.show()
	source_button.modulate.a = 0.35
	_stamp_tween = create_tween()
	_stamp_tween.tween_property(stamp_head, "global_position", hover, STAMP_TRAVEL).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_stamp_tween.parallel().tween_property(stamp_head, "scale", Vector2.ONE * STAMP_LIFTED_SCALE, STAMP_TRAVEL)
	_stamp_tween.tween_property(stamp_head, "global_position", pressed_at, STAMP_PRESS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_stamp_tween.parallel().tween_property(stamp_head, "scale", Vector2.ONE * STAMP_PRESSED_SCALE, STAMP_PRESS)
	_stamp_tween.tween_callback(_impact)
	_stamp_tween.tween_interval(STAMP_HOLD)
	_stamp_tween.tween_property(stamp_head, "global_position", hover, STAMP_LIFT)
	_stamp_tween.parallel().tween_property(stamp_head, "scale", Vector2.ONE * STAMP_LIFTED_SCALE, STAMP_LIFT)
	_stamp_tween.tween_property(stamp_head, "global_position", home, STAMP_RETURN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_stamp_tween.parallel().tween_property(stamp_head, "scale", Vector2.ONE, STAMP_RETURN)
	_stamp_tween.tween_callback(_finish)


## Conclui na hora o carimbo em andamento (impacto, se ainda não houve, e fim).
## release_pending_holds libera também a espera que o balcão fizer em seguida.
func finish_now(release_pending_holds := true) -> void:
	if is_stamping():
		if _stamp_tween != null:
			_stamp_tween.kill()
		if not _impacted:
			_impact()
		_finish()
	_stop_shake()
	if release_pending_holds:
		release_holds()


func _impact() -> void:
	_impacted = true
	show_ink(_active_kind)
	play_sfx(&"stamp_approve" if _active_kind == APPROVE else &"stamp_reject")
	shake()
	stamp_impact.emit(_active_kind)


func _finish() -> void:
	var kind := _active_kind
	_active_kind = &""
	_stamp_tween = null
	if stamp_head != null:
		stamp_head.hide()
		stamp_head.scale = Vector2.ONE
	if _source_button != null:
		_source_button.modulate.a = 1.0
	stamp_finished.emit(kind)


## Centro da área do carimbo (ou do papel, se não houver área reservada),
## arredondado para cair em pixel inteiro.
func _spot() -> Vector2:
	if stamp_target != null:
		return (stamp_target.global_position + stamp_target.size * 0.5).round()
	return (_paper.global_position + _paper.size * 0.5).round()


func _dress_stamp_head(kind: StringName) -> void:
	stamp_head.texture = stamp_sprites.get(kind)
	stamp_head.size = stamp_head.texture.get_size() if stamp_head.texture != null else Vector2(40.0, 46.0)
	stamp_head.pivot_offset = (stamp_head.size * 0.5).round()


## ======================== MARCA DE TINTA ========================

## Marca permanente no pedido ("APPROVED"/"REFUSED"), até o próximo cliente.
## A marca é filha centralizada da área do carimbo: acompanha o papel e o
## layout sozinha, sem depender de coordenadas calculadas no impacto.
func show_ink(kind: StringName) -> void:
	if ink_mark == null:
		return
	var ink := Color(0.12, 0.42, 0.2) if kind == APPROVE else Color(0.72, 0.08, 0.06)
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.anti_aliasing = false
	frame.border_color = ink
	frame.set_border_width_all(2)
	frame.content_margin_left = 5.0
	frame.content_margin_right = 4.0
	frame.content_margin_top = 0.0
	frame.content_margin_bottom = 0.0
	ink_mark.add_theme_stylebox_override("normal", frame)
	ink_mark.add_theme_color_override("font_color", ink)
	ink_mark.text = tr("DESK_INK_APPROVED" if kind == APPROVE else "DESK_INK_REFUSED")
	ink_mark.pivot_offset = (ink_mark.get_combined_minimum_size() * 0.5).round()
	ink_mark.show()
	if instant:
		ink_mark.scale = Vector2.ONE
		ink_mark.modulate.a = INK_ALPHA
		return
	ink_mark.scale = Vector2.ONE * INK_POP_SCALE
	ink_mark.modulate.a = 0.0
	var pop := create_tween().set_parallel()
	pop.tween_property(ink_mark, "scale", Vector2.ONE, INK_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(ink_mark, "modulate:a", INK_ALPHA, INK_POP)


func clear_ink() -> void:
	if ink_mark != null:
		ink_mark.hide()
		ink_mark.text = ""


## ======================== TREMIDA ========================

func shake(strength := SHAKE_STRENGTH) -> void:
	if instant or shake_target == null:
		return
	_stop_shake()
	_shake_base = shake_target.position
	_shake_tween = create_tween()
	var step := SHAKE_DURATION / float(SHAKE_STEPS)
	for index in range(SHAKE_STEPS):
		var decay := 1.0 - float(index) / float(SHAKE_STEPS)
		var offset := (Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * strength * decay).round()
		_shake_tween.tween_property(shake_target, "position", _shake_base + offset, step)
	_shake_tween.tween_property(shake_target, "position", _shake_base, step)


func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		shake_target.position = _shake_base
	_shake_tween = null


## ======================== SOM E ESPERAS ========================

## Em modo instant ou mute a deixa é só anunciada (sfx_requested), sem tocar.
func play_sfx(cue: StringName) -> void:
	sfx_requested.emit(cue)
	var stream: AudioStream = sounds.get(cue)
	if instant or mute or stream == null or _players.is_empty():
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.play()


## Pausa curta de apresentação (reação do cliente, marca à vista). Em modo
## instant não espera; release_holds encerra qualquer espera pendente.
func hold(seconds: float) -> void:
	if instant or seconds <= 0.0:
		return
	_hold_serial += 1
	# Método (não lambda): a conexão some sozinha se o balcão for liberado antes.
	get_tree().create_timer(seconds).timeout.connect(_on_hold_timeout.bind(_hold_serial))
	await _hold_released


func _on_hold_timeout(serial: int) -> void:
	# Um timer antigo não encerra uma espera mais nova.
	if serial == _hold_serial:
		_hold_released.emit()


func release_holds() -> void:
	_hold_serial += 1
	_hold_released.emit()
