class_name GameAudioManager extends Node

const SAMPLE_RATE := 22050
const POOL_SIZE := 12
const MIN_DB := -80.0
const TAU := PI * 2.0

const EVENT_UI := "ui"
const EVENT_SHOOT_ARROW := "shoot_arrow"
const EVENT_SWORD := "sword"
const EVENT_MAGIC := "magic"
const EVENT_EXPLOSION := "explosion"
const EVENT_COIN := "coin"
const EVENT_LEVEL_UP := "level_up"
const EVENT_PURCHASE := "purchase"
const EVENT_CAPTURE := "capture"
const EVENT_HURT := "hurt"
const EVENT_HEAL := "heal"
const EVENT_REVIVE := "revive"
const EVENT_CANNON := "cannon"
const EVENT_MUSKET := "musket"
const EVENT_RIFLE := "rifle"
const EVENT_ROCKET := "rocket"
const EVENT_MACHINE_GUN := "machine_gun"
const EVENT_BOMB := "bomb"
const EVENT_BEAM := "beam"
const EVENT_WARNING := "warning"
const EVENT_BOSS_HISS := "boss_hiss"
const EVENT_BOSS_CONSTRICT := "boss_constrict"
const EVENT_BOSS_DASH := "boss_dash"
const EVENT_BOSS_IMPACT := "boss_impact"
const EVENT_BOSS_BITE := "boss_bite"
const EVENT_BOSS_POISON := "boss_poison"
const EVENT_BOSS_BUBBLE := "boss_bubble"
const EVENT_BOSS_TAIL := "boss_tail"
const EVENT_BOSS_STUN := "boss_stun"
const EVENT_BOSS_PHASE := "boss_phase"
const EVENT_BOSS_DEATH := "boss_death"
const EVENT_TIME_TICK := "time_tick"
const EVENT_TIME_SHATTER := "time_shatter"
const EVENT_TIME_REWIND := "time_rewind"
const EVENT_TIME_BELL := "time_bell"

const WAVE_SINE := 0
const WAVE_SQUARE := 1
const WAVE_TRIANGLE := 2


var _pool: Array[AudioStreamPlayer] = []
var _pool_cursor := 0
var _cue_streams: Dictionary = {}
var _volume_linear := 1.0
var _muted := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_create_pool()
	_build_cues()


func play(event_name: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = _cue_streams.get(event_name.strip_edges().to_lower()) as AudioStream
	if stream == null:
		return

	var player := _acquire_player()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.set_meta("event_volume_scale", max(volume_scale, 0.0))
	_apply_player_volume(player)
	player.play()


func set_volume(linear: float) -> void:
	_volume_linear = max(linear, 0.0)
	for player in _pool:
		_apply_player_volume(player)


func set_muted(muted: bool) -> void:
	_muted = muted
	for player in _pool:
		_apply_player_volume(player)


func _create_pool() -> void:
	_rng.randomize()
	for index in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "audio_pool_player_%d" % index
		add_child(player)
		_pool.append(player)


func _build_cues() -> void:
	_cue_streams = {
		EVENT_UI: _make_cue(0.07, 680.0, 980.0, 0.18, WAVE_SINE, 0.0, 0.003, 0.02, 1.7),
		EVENT_SHOOT_ARROW: _make_cue(0.08, 1600.0, 920.0, 0.20, WAVE_SINE, 0.1, 0.003, 0.02, 0.9, 2.0, 0.12, 1.5),
		EVENT_SWORD: _make_cue(0.10, 460.0, 120.0, 0.24, WAVE_SQUARE, 0.25, 0.004, 0.04, 1.4, 2.0, 0.15, 3.0),
		EVENT_MAGIC: _make_cue(0.14, 360.0, 840.0, 0.20, WAVE_SINE, 0.22, 0.004, 0.05, 1.6, 2.0, 0.17, 2.5),
		EVENT_EXPLOSION: _make_cue(0.18, 190.0, 55.0, 0.33, WAVE_TRIANGLE, 0.74, 0.001, 0.06, 1.0, 1.0, 0.0, 1.0),
		EVENT_COIN: _make_cue(0.09, 520.0, 1450.0, 0.16, WAVE_SINE, 0.0, 0.005, 0.02, 1.4, 1.5, 0.15, 2.2),
		EVENT_LEVEL_UP: _make_cue(0.22, 300.0, 900.0, 0.20, WAVE_SINE, 0.05, 0.004, 0.07, 1.6, 1.5, 0.22, 2.0),
		EVENT_PURCHASE: _make_cue(0.09, 460.0, 660.0, 0.15, WAVE_SINE, 0.0, 0.006, 0.02, 1.2),
		EVENT_CAPTURE: _make_cue(0.12, 330.0, 700.0, 0.17, WAVE_SINE, 0.05, 0.004, 0.025, 1.5),
		EVENT_HURT: _make_cue(0.09, 420.0, 190.0, 0.22, WAVE_SQUARE, 0.15, 0.002, 0.04, 1.3, 1.0, 0.12, 3.0),
		EVENT_HEAL: _make_cue(0.11, 470.0, 980.0, 0.17, WAVE_SINE, 0.06, 0.005, 0.03, 1.2, 1.25, 0.12, 2.0),
		EVENT_REVIVE: _make_cue(0.16, 300.0, 760.0, 0.20, WAVE_SINE, 0.05, 0.01, 0.05, 1.5, 1.6, 0.16, 2.2),
		EVENT_CANNON: _make_cue(0.20, 150.0, 60.0, 0.30, WAVE_TRIANGLE, 0.40, 0.001, 0.06, 1.0, 1.0, 0.0, 1.0),
		EVENT_MUSKET: _make_cue(0.16, 310.0, 72.0, 0.28, WAVE_SQUARE, 0.54, 0.001, 0.07, 0.72, 1.0, 0.08, 2.4),
		EVENT_RIFLE: _make_cue(0.075, 520.0, 155.0, 0.19, WAVE_SQUARE, 0.34, 0.001, 0.025, 0.78, 1.0, 0.12, 2.1),
		EVENT_ROCKET: _make_cue(0.31, 95.0, 310.0, 0.25, WAVE_TRIANGLE, 0.58, 0.006, 0.11, 1.35, 1.0, 0.0, 1.0),
		EVENT_MACHINE_GUN: _make_cue(0.055, 430.0, 145.0, 0.15, WAVE_SQUARE, 0.32, 0.001, 0.018, 0.72, 1.0, 0.10, 2.2),
		EVENT_BOMB: _make_cue(0.28, 125.0, 38.0, 0.31, WAVE_TRIANGLE, 0.68, 0.001, 0.10, 0.92, 1.0, 0.0, 1.0),
		EVENT_BEAM: _make_cue(0.38, 760.0, 115.0, 0.18, WAVE_SINE, 0.18, 0.012, 0.14, 1.45, 2.0, 0.14, 0.72),
		EVENT_WARNING: _make_cue(0.13, 620.0, 210.0, 0.22, WAVE_SINE, 0.12, 0.003, 0.04, 0.8, 1.5, 0.14, 2.3),
		EVENT_BOSS_HISS: _make_cue(0.42, 115.0, 62.0, 0.24, WAVE_TRIANGLE, 0.56, 0.012, 0.12, 0.82, 0.55, 0.20, 1.8),
		EVENT_BOSS_CONSTRICT: _make_cue(0.28, 92.0, 46.0, 0.25, WAVE_SQUARE, 0.42, 0.004, 0.09, 0.74, 0.60, 0.16, 2.2),
		EVENT_BOSS_DASH: _make_cue(0.30, 780.0, 86.0, 0.20, WAVE_SINE, 0.68, 0.003, 0.08, 0.58, 1.2, 0.18, 2.4),
		EVENT_BOSS_IMPACT: _make_cue(0.26, 130.0, 42.0, 0.34, WAVE_TRIANGLE, 0.78, 0.001, 0.09, 0.88, 0.75, 0.10, 1.7),
		EVENT_BOSS_BITE: _make_cue(0.18, 310.0, 72.0, 0.26, WAVE_SQUARE, 0.36, 0.002, 0.05, 0.74, 1.3, 0.10, 2.8),
		EVENT_BOSS_POISON: _make_cue(0.34, 180.0, 510.0, 0.19, WAVE_SINE, 0.48, 0.008, 0.12, 0.65, 1.5, 0.22, 2.6),
		EVENT_BOSS_BUBBLE: _make_cue(0.16, 76.0, 225.0, 0.14, WAVE_SINE, 0.34, 0.004, 0.07, 1.45, 1.6, 0.12, 2.1),
		EVENT_BOSS_TAIL: _make_cue(0.27, 920.0, 95.0, 0.23, WAVE_SINE, 0.62, 0.002, 0.08, 0.54, 1.3, 0.18, 2.3),
		EVENT_BOSS_STUN: _make_cue(0.42, 240.0, 118.0, 0.24, WAVE_TRIANGLE, 0.28, 0.003, 0.14, 0.80, 1.8, 0.30, 2.0),
		EVENT_BOSS_PHASE: _make_cue(0.72, 72.0, 460.0, 0.27, WAVE_TRIANGLE, 0.48, 0.008, 0.22, 0.72, 1.4, 0.30, 2.4),
		EVENT_BOSS_DEATH: _make_cue(1.10, 105.0, 28.0, 0.32, WAVE_TRIANGLE, 0.70, 0.010, 0.34, 0.62, 0.70, 0.24, 1.8),
		# 艾歐尼斯使用短促時鐘、玻璃碎裂、倒放與十二鐘聲；全部由程式合成，
		# 不增加 Web 下載素材，也可直接使用既有的 AudioStreamPlayer pool。
		EVENT_TIME_TICK: _make_cue(0.095, 1180.0, 720.0, 0.16, WAVE_SQUARE, 0.04, 0.001, 0.018, 1.5, 2.0, 0.10, 1.8),
		EVENT_TIME_SHATTER: _make_cue(0.34, 1680.0, 95.0, 0.24, WAVE_TRIANGLE, 0.62, 0.001, 0.12, 0.55, 1.8, 0.22, 2.7),
		EVENT_TIME_REWIND: _make_cue(0.58, 155.0, 1260.0, 0.21, WAVE_SINE, 0.24, 0.012, 0.16, 1.7, 1.5, 0.20, 0.72),
		EVENT_TIME_BELL: _make_cue(0.92, 246.0, 78.0, 0.29, WAVE_SINE, 0.12, 0.004, 0.34, 0.82, 2.0, 0.34, 2.01)
	}


func _acquire_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player

	var player := _pool[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _pool.size()
	player.stop()
	return player


func _apply_player_volume(player: AudioStreamPlayer) -> void:
	if _muted:
		player.volume_db = MIN_DB
		return

	var event_scale := 1.0
	if player.has_meta("event_volume_scale"):
		event_scale = maxf(float(player.get_meta("event_volume_scale")), 0.0)
	player.volume_db = _linear_to_db(_volume_linear * event_scale)


func _linear_to_db(value: float) -> float:
	var clamped: float = maxf(value, 0.00001)
	return linear_to_db(clamped)


func _make_cue(
	duration: float,
	start_frequency: float,
	end_frequency: float,
	amplitude: float,
	waveform: int = WAVE_SINE,
	noise_mix: float = 0.0,
	attack: float = 0.004,
	release: float = 0.03,
	frequency_curve: float = 1.0,
	secondary_harmonic: float = 0.0,
	secondary_mix: float = 0.0,
	secondary_start_ratio: float = 1.0,
	secondary_end_ratio: float = 1.0
) -> AudioStreamWAV:
	var frame_count: int = maxi(1, int(round(duration * SAMPLE_RATE)))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	var data: PackedByteArray = PackedByteArray()
	data.resize(frame_count * 2)

	var envelope_attack: float = 0.0
	var envelope_release: float = 0.0
	if duration > 0.0:
		envelope_attack = minf(attack / duration, 1.0)
		envelope_release = minf(release / duration, 1.0)

	for index in frame_count:
		var progress: float = float(index) / float(maxi(frame_count - 1, 1))
		var curved_progress: float = pow(progress, frequency_curve)
		var attack_env: float = 1.0
		var release_env: float = 1.0

		if progress < envelope_attack and envelope_attack > 0.0:
			attack_env = progress / envelope_attack
		if progress > (1.0 - envelope_release) and envelope_release > 0.0:
			release_env = (1.0 - progress) / envelope_release

		var freq: float = lerpf(start_frequency, end_frequency, curved_progress)
		var secondary_freq: float = (
			freq * lerpf(secondary_start_ratio, secondary_end_ratio, curved_progress) * secondary_harmonic
			if secondary_harmonic > 0.0
			else 0.0
		)

		var t: float = float(index) / float(SAMPLE_RATE)
		var wave: float = _sample_wave(waveform, t, freq)
		var sample: float = wave * (1.0 - secondary_mix)

		if secondary_harmonic > 0.0 and secondary_mix > 0.0:
			sample += _sample_wave(waveform, t * (1.0 + secondary_start_ratio * secondary_harmonic), secondary_freq) * secondary_mix

		if noise_mix > 0.0:
			sample = lerpf(sample, _rng.randf_range(-1.0, 1.0), clampf(noise_mix, 0.0, 1.0))

		var env: float = clampf(attack_env * release_env, 0.0, 1.0)
		var pcm_f: float = clampf(sample * env * amplitude, -1.0, 1.0) * 32767.0
		var pcm_i: int = int(pcm_f)
		var byte_index: int = index * 2
		data[byte_index] = pcm_i & 0xFF
		data[byte_index + 1] = (pcm_i >> 8) & 0xFF

	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


func _sample_wave(waveform: int, phase_t: float, frequency: float) -> float:
	var phase: float = phase_t * TAU * frequency
	match waveform:
		WAVE_SQUARE:
			return 1.0 if sin(phase) >= 0.0 else -1.0
		WAVE_TRIANGLE:
			var saw: float = fmod(phase, TAU)
			var normalized: float = saw / TAU
			return 1.0 - absf(normalized * 2.0 - 1.0) * 2.0
		_:
			return sin(phase)
