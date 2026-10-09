extends Node
# ==============================================================
#  gameplay.gd  —  attach กับ root Node ของ gameplay.tscn
#  ควบคุม Game Loop หลักทั้งหมด (3D first-person cockpit)
# ==============================================================

@onready var world_3d:        Node3D           = $World3D
@onready var hud:             CanvasLayer      = $HUD
@onready var quiz_popup:      CanvasLayer      = $QuizPopup
@onready var pause_panel:     Control          = $HUD/PausePanel
@onready var countdown_label: Label            = $HUD/CountdownLabel
@onready var bgm:             AudioStreamPlayer = $BGM

var _is_paused:        bool        = false
var _cockpit_overlay:  CanvasLayer = null

func _ready() -> void:
	get_tree().paused = false
	TouchInput.reset()
	_build_cockpit_overlay()
	SoundManager.play_bgm("gameplay", 1.0)

	# GameManager.start_mission() (เรียกจากฉากก่อนหน้า) ตั้ง is_game_running = true
	# ไว้ก่อนเปลี่ยนมาฉากนี้แล้ว ต้องปิดใหม่ให้ทุกอย่างรอ countdown จบก่อน
	GameManager.is_game_running = false

	# เชื่อม signals จาก GameManager
	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.mission_complete.connect(_on_mission_complete)

	# เชื่อม PauseBtn / ResumeBtn → _toggle_pause (ผ่าน hud.gd ที่ handle แล้ว)
	# hud.gd เชื่อม pause_btn → hud._toggle_pause อยู่แล้ว ไม่ต้องทำซ้ำ

	# เชื่อม signals จาก World3D (cockpit_3d.gd)
	world_3d.quiz_triggered.connect(_on_quiz_triggered)
	world_3d.shield_changed.connect(hud.set_shield_active)

	# แสดงสถานะ shield ตั้งต้น (ไม่มี)
	hud.set_shield_active(false)

	# Countdown ก่อนเริ่ม
	await _start_countdown()
	GameManager.is_game_running = true
	hud.set_controls_enabled(true)   # เปิดปุ่มเลี้ยว/บูสต์ — เอา shadow ที่คลุมไว้ออก

func _process(delta: float) -> void:
	if _is_paused or not GameManager.is_game_running:
		return
	GameManager.tick_timer(delta)

# ──────────────────────────────────────────────────────────────
# สีสันแต่ละสเตปของ countdown — ไล่จากแดง(ตื่นเต้น) → ส้ม → เหลือง → เขียว(ลุย!)
const COUNTDOWN_COLORS: Dictionary = {
	"3":   Color(1.00, 0.25, 0.25),
	"2":   Color(1.00, 0.55, 0.10),
	"1":   Color(1.00, 0.90, 0.15),
	"GO!": Color(0.30, 1.00, 0.45),
}

func _start_countdown() -> void:
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_constant_override("outline_size", 16)
	countdown_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.12, 0.95))
	countdown_label.add_theme_constant_override("shadow_outline_size", 10)
	countdown_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	countdown_label.pivot_offset = countdown_label.size / 2.0
	countdown_label.show()

	for i in [3, 2, 1]:
		countdown_label.add_theme_font_size_override("font_size", 180)
		await _punch_countdown(str(i), COUNTDOWN_COLORS[str(i)])
		SoundManager.play_sfx("countdown")
		await get_tree().create_timer(0.55).timeout

	countdown_label.add_theme_font_size_override("font_size", 220)
	await _punch_countdown("GO!", COUNTDOWN_COLORS["GO!"])
	SoundManager.play_sfx("powerup")
	await get_tree().create_timer(0.5).timeout
	countdown_label.hide()

# เล่นแอนิเมชัน "เด้งเข้า" แบบตื่นเต้น — ซูมใหญ่ + เอียงเล็กน้อย แล้วสปริงกลับสู่ปกติ
func _punch_countdown(txt: String, color: Color) -> void:
	countdown_label.text = txt
	countdown_label.add_theme_color_override("font_color", color)
	countdown_label.modulate.a   = 0.0
	countdown_label.scale        = Vector2(2.8, 2.8)
	countdown_label.rotation_degrees = randf_range(-10.0, 10.0)
	var tween := create_tween()
	tween.tween_property(countdown_label, "modulate:a", 1.0, 0.06)
	tween.parallel().tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.32) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(countdown_label, "rotation_degrees", 0.0, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

# ──────────────────────────────────────────────────────────────
func _toggle_pause() -> void:
	_is_paused = !_is_paused
	get_tree().paused = _is_paused
	pause_panel.visible = _is_paused
	if _is_paused:
		SoundManager.stop_bgm(0.3)
		TouchInput.reset()
	else:
		SoundManager.play_bgm("gameplay", 0.5)

func resume_from_quiz() -> void:
	# เรียกจาก quiz_popup.gd หลังปิด quiz
	get_tree().paused = false
	world_3d.quiz_active = false   # อนุญาตให้ quiz spawn ใหม่ได้

func _on_quiz_triggered() -> void:
	quiz_popup.show_quiz()

# ──────────────────────────────────────────────────────────────
func _on_game_over() -> void:
	GameManager.is_game_running = false
	SoundManager.play_sfx("explosion")
	SoundManager.stop_bgm(1.0)
	await get_tree().create_timer(2.0).timeout
	GameManager.go_to_scene("game_over")

func _on_mission_complete() -> void:
	GameManager.is_game_running = false
	SoundManager.stop_bgm(1.0)
	await get_tree().create_timer(0.8).timeout
	GameManager.go_to_scene("landing")

# ──────────────────────────────────────────────────────────────
# COCKPIT OVERLAY  (FPS only)
# สร้าง CanvasLayer + CockpitFrame Control แบบ programmatic
# เพื่อเลี่ยง UID registration issue ใน .tscn
# ──────────────────────────────────────────────────────────────
const SHIP_INSIDE_TEXTURES: Array[String] = [
    "res://assets/ui/ship_one_explorer_inside.png",
    "res://assets/ui/ship_two_wing_inside.png",
    "res://assets/ui/ship_three_comet_inside.png",
]

func _build_cockpit_overlay() -> void:
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name  = "CockpitOverlay"
	overlay_layer.layer = 8
	add_child(overlay_layer)

	# รูป interior ยานตามที่ผู้เล่นเลือก
	var avatar_idx := clampi(GameManager.player_avatar, 0, SHIP_INSIDE_TEXTURES.size() - 1)
	var inside_tex := load(SHIP_INSIDE_TEXTURES[avatar_idx]) as Texture2D
	if inside_tex:
		var inside_rect := TextureRect.new()
		inside_rect.name = "ShipInterior"
		inside_rect.texture = inside_tex
		inside_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		inside_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		inside_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_layer.add_child(inside_rect)

	var frame_script := load("res://scripts/cockpit_overlay.gd")
	var frame_ctrl   := Control.new()
	frame_ctrl.set_script(frame_script)
	frame_ctrl.name         = "CockpitFrame"
	frame_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(frame_ctrl)

	_cockpit_overlay = overlay_layer
	frame_ctrl.set_cockpit_ref(world_3d)
	_update_overlay_visibility()
	GameSettings.settings_changed.connect(_update_overlay_visibility)

func _update_overlay_visibility() -> void:
	if _cockpit_overlay:
		_cockpit_overlay.visible = true   # show in both FPS and TPS
