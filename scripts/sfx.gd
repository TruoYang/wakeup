extends Node
## Phát âm thanh: 2D (giao diện, cơ thể) và 3D (theo vị trí trong thế giới).

const DIR := "res://assets/sfx/"
var _cache: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _loops: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)
	for i in 20:
		var p3 := AudioStreamPlayer3D.new()
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.attenuation_filter_cutoff_hz = 9000.0
		add_child(p3)
		_pool3d.append(p3)


func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := DIR + sound + ".wav"
		var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if s is AudioStreamWAV and sound.ends_with("_loop"):
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = int(s.get_length() * s.mix_rate)
		_cache[sound] = s
	return _cache[sound]


## Âm có nhiều bản ghi (tên, tên_2, tên_3…): mỗi lần phát chọn ngẫu nhiên một bản cho đỡ lặp.
var _variants: Dictionary = {}


func _pick(sound: String) -> String:
	if not _variants.has(sound):
		var vs: Array[String] = [sound]
		for k in range(2, 7):
			if ResourceLoader.exists(DIR + "%s_%d.wav" % [sound, k]):
				vs.append("%s_%d" % [sound, k])
		_variants[sound] = vs
	var arr: Array = _variants[sound]
	return arr[rng.randi() % arr.size()]


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := stream(_pick(sound))
	if s == null:
		return
	for p in _pool2d:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch * rng.randf_range(0.96, 1.04)
			p.play()
			return


## size: bán kính nghe rõ (m). Âm lớn (gầm, nổ) dùng size lớn.
func play_at(sound: String, pos: Vector3, volume_db := 0.0, size := 8.0, pitch := 1.0) -> void:
	var s := stream(_pick(sound))
	if s == null:
		return
	for p in _pool3d:
		if not p.playing:
			p.stream = s
			p.global_position = pos
			p.volume_db = volume_db
			p.unit_size = size
			p.max_distance = size * 14.0
			p.pitch_scale = pitch * rng.randf_range(0.95, 1.05)
			p.play()
			return


## Âm nền lặp (mưa, gió...). volume 0..1; 0 thì tắt.
func loop(sound: String, volume: float) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null:
		if volume <= 0.001:
			return
		p = AudioStreamPlayer.new()
		p.stream = stream(sound)
		add_child(p)
		_loops[sound] = p
	if volume <= 0.001:
		if p.playing:
			p.stop()
		return
	p.volume_db = linear_to_db(clampf(volume, 0.0, 1.0))
	if not p.playing:
		p.play()


func stop_all_loops() -> void:
	for k: String in _loops:
		(_loops[k] as AudioStreamPlayer).stop()


func step(surface: String, pos: Vector3, loud: float, local: bool) -> void:
	var name := "step_%s_%d" % [surface if surface != "" else "concrete", 1 + rng.randi() % 3]
	if stream(name) == null:
		name = "step_concrete_%d" % (1 + rng.randi() % 3)
	var db := linear_to_db(clampf(0.25 + loud * 0.75, 0.05, 1.0))
	if local:
		play(name, db - 8.0)
	else:
		play_at(name, pos, db - 2.0, 4.0)
