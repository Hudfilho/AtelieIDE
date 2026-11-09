class_name AtelierPlaceholderSfx
extends RefCounted

## Sons provisórios gerados em código, para o balcão não ficar mudo enquanto
## não há áudio de verdade. Cada deixa pode ser trocada por um arquivo no
## Inspector do nó Feedback do balcão (AtelierDeskFeedback.sounds).

const MIX_RATE := 22050


static func build(cue: StringName) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cue)
	match cue:
		&"bell":
			return _render(0.7, func(t: float) -> float:
				return (sin(TAU * 880.0 * t) + 0.6 * sin(TAU * 1320.0 * t) + 0.3 * sin(TAU * 2640.0 * t)) * exp(-t * 5.0) * 0.28)
		&"stamp_approve", &"stamp_reject":
			var pitch := 1.0 if cue == &"stamp_approve" else 0.82
			return _render(0.2, func(t: float) -> float:
				var thump := sin(TAU * (130.0 - 260.0 * t) * pitch * t) * exp(-t * 26.0)
				var slap := rng.randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.5
				return (thump + slap) * 0.7)
		&"paper":
			var smooth := [0.0]
			return _render(0.16, func(t: float) -> float:
				smooth[0] = lerpf(smooth[0], rng.randf_range(-1.0, 1.0), 0.35)
				return smooth[0] * minf(t / 0.015, 1.0) * exp(-t * 18.0) * 0.5)
		&"coins":
			return _render(0.4, func(t: float) -> float:
				var ping := func(start: float, frequency: float) -> float:
					return 0.0 if t < start else sin(TAU * frequency * (t - start)) * exp(-(t - start) * 16.0)
				return (ping.call(0.0, 2093.0) + ping.call(0.07, 2637.0) + 0.6 * ping.call(0.13, 3136.0)) * 0.22)
		_:
			return null


static func _render(seconds: float, sample: Callable) -> AudioStreamWAV:
	var count := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in range(count):
		var value := clampf(sample.call(float(index) / MIX_RATE), -1.0, 1.0)
		data.encode_s16(index * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
