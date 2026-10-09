extends Node
# ==============================================================
#  sound_manager.gd  —  Autoload Singleton
#  ลงทะเบียนใน Project → Autoload  ชื่อ "SoundManager"
#  จัดการ BGM และ SFX ทั้งหมดของเกม
# ==============================================================

# ── Audio Bus Names (ตั้งใน Project → Audio) ──────────────────
const BUS_MASTER: String = "Master"
const BUS_BGM:    String = "BGM"
const BUS_SFX:    String = "SFX"

# ── BGM Paths ─────────────────────────────────────────────────
const BGM_PATHS: Dictionary = {
	"attract":   "res://assets/audio/bgm/bgm_attract.ogg",
	"menu":      "res://assets/audio/bgm/bgm_menu.ogg",
	"gameplay":  "res://assets/audio/bgm/bgm_gameplay.ogg",
	"boss":      "res://assets/audio/bgm/bgm_intense.ogg",
	"win":       "res://assets/audio/bgm/bgm_win.ogg",
	"game_over": "res://assets/audio/bgm/bgm_gameover.ogg",
}

# ── SFX Paths ─────────────────────────────────────────────────
const SFX_PATHS: Dictionary = {
	"boost":       "res://assets/audio/sfx/sfx_boost.ogg",
	"hit":         "res://assets/audio/sfx/sfx_hit.ogg",
	"explosion":   "res://assets/audio/sfx/sfx_explosion.ogg",
	"powerup":     "res://assets/audio/sfx/sfx_powerup.ogg",
	"quiz_correct":"res://assets/audio/sfx/sfx_correct.ogg",
	"quiz_wrong":  "res://assets/audio/sfx/sfx_wrong.ogg",
	"btn_click":   "res://assets/audio/sfx/sfx_click.ogg",
	"shield_on":   "res://assets/audio/sfx/sfx_shield.ogg",
	"countdown":   "res://assets/audio/sfx/sfx_countdown.ogg",
	"landing":     "res://assets/audio/sfx/sfx_landing.ogg",
}

var _bgm_player: AudioStreamPlayer = null
var _bgm_fade_tween: Tween = null   # เก็บ tween fade-in ไว้เพื่อ kill ตอน mute
var _sfx_pool:   Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE: int = 8

var bgm_volume:  float = 0.8   # 0.0–1.0
var sfx_volume:  float = 1.0

var bgm_muted:   bool  = false
var sfx_muted:   bool  = false

signal bgm_mute_changed(muted: bool)
signal sfx_mute_changed(muted: bool)

# ใช้ค่า dB ต่ำที่จำกัด (ไม่ใช่ -INF) — interpolate ไป/มาจาก -INF
# ทำให้ tween คำนวณได้ NaN (lerp(-inf, finite, t) = NaN เมื่อ 0<t<1)
const SILENCE_DB: float = -80.0

func _ready() -> void:
	_ensure_buses()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = BUS_BGM
	add_child(_bgm_player)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)
	_apply_volumes()

# ──────────────────────────────────────────────────────────────
func play_bgm(key: String, fade_in: float = 1.0) -> void:
	if not BGM_PATHS.has(key):
		push_warning("SoundManager: BGM key '%s' ไม่พบ" % key)
		return
	if not ResourceLoader.exists(BGM_PATHS[key]):  # export: .ogg ต้นฉบับไม่ถูกแพ็ก มีแต่ไฟล์ที่ import แล้ว
		return   # ไฟล์ยังไม่มี — ข้ามโดยไม่ error
	var stream: AudioStream = load(BGM_PATHS[key])
	# บังคับให้ BGM เล่นซ้ำไปเรื่อยๆ (infinite loop) แทนที่จะหยุดเมื่อเล่นจบ
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	if _bgm_player.playing:
		var tween := create_tween()
		tween.tween_property(_bgm_player, "volume_db",
			SILENCE_DB, fade_in * 0.5)
		await tween.finished
	_bgm_player.stream = stream
	_bgm_player.volume_db = SILENCE_DB
	_bgm_player.play()
	# ถ้า mute อยู่ → เล่นเพลงไว้ (เพื่อให้ unmute แล้วมีเพลงต่อทันที) แต่คง volume ที่ SILENCE_DB
	if bgm_muted:
		return
	# kill tween เก่าก่อน (ป้องกัน fade-in ทับ mute)
	if _bgm_fade_tween and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(_bgm_player, "volume_db",
		linear_to_db(bgm_volume), fade_in * 0.5)

func stop_bgm(fade_out: float = 0.8) -> void:
	if not _bgm_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_bgm_player, "volume_db",
		SILENCE_DB, fade_out)
	await tween.finished
	_bgm_player.stop()

# ──────────────────────────────────────────────────────────────
func play_sfx(key: String) -> void:
	if sfx_muted:
		return
	if not SFX_PATHS.has(key):
		push_warning("SoundManager: SFX key '%s' ไม่พบ" % key)
		return
	if not ResourceLoader.exists(SFX_PATHS[key]):
		return
	var player := _get_free_sfx_player()
	if player == null:
		return
	player.stream    = load(SFX_PATHS[key])
	player.volume_db = linear_to_db(sfx_volume)
	player.play()

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0]   # fallback: ใช้ตัวแรก

# ──────────────────────────────────────────────────────────────
func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	if not bgm_muted:
		_bgm_player.volume_db = linear_to_db(bgm_volume)

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)

func _apply_volumes() -> void:
	if bgm_muted:
		_bgm_player.volume_db = SILENCE_DB
	else:
		_bgm_player.volume_db = linear_to_db(bgm_volume)

# ── Mute Toggle ──────────────────────────────────────────────
func toggle_bgm_mute() -> void:
	bgm_muted = not bgm_muted
	if bgm_muted:
		# kill fade-in tween ที่กำลัง run อยู่ — ป้องกัน tween เขียนทับ volume_db
		if _bgm_fade_tween and _bgm_fade_tween.is_valid():
			_bgm_fade_tween.kill()
			_bgm_fade_tween = null
		_bgm_player.volume_db = SILENCE_DB
	else:
		_bgm_player.volume_db = linear_to_db(bgm_volume)
	bgm_mute_changed.emit(bgm_muted)

func toggle_sfx_mute() -> void:
	sfx_muted = not sfx_muted
	sfx_mute_changed.emit(sfx_muted)

func set_bgm_muted(muted: bool) -> void:
	bgm_muted = muted
	if bgm_muted:
		# kill fade-in tween ที่กำลัง run อยู่ — ป้องกัน tween เขียนทับ volume_db
		if _bgm_fade_tween and _bgm_fade_tween.is_valid():
			_bgm_fade_tween.kill()
			_bgm_fade_tween = null
		_bgm_player.volume_db = SILENCE_DB
	else:
		_bgm_player.volume_db = linear_to_db(bgm_volume)
	bgm_mute_changed.emit(bgm_muted)

func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	sfx_mute_changed.emit(sfx_muted)

# สร้าง bus BGM / SFX ถ้ายังไม่มี (กันพลาดกรณี default_bus_layout.tres หาย)
# บน Web (ไม่มี thread) Godot เล่นเสียงแบบ sample ซึ่งจะ error "invalid bus index -1"
# ถ้า AudioStreamPlayer อ้างชื่อ bus ที่ไม่มีอยู่จริง
func _ensure_buses() -> void:
	for bus_name in [BUS_BGM, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)
