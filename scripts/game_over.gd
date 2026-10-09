extends Control
# ==============================================================
#  game_over.gd  —  styled to match reference UI
# ==============================================================

@onready var reason_label:    Label         = $Frame/Content/ReasonLabel
@onready var score_label:     Label         = $Frame/Content/ScoreLabel
@onready var progress_label:  Label         = $Frame/Content/ProgressLabel
@onready var encourage_label: Label         = $Frame/Content/EncourageLabel
@onready var retry_btn:       Button        = $Frame/Content/BtnRow/RetryBtn
@onready var home_btn:        Button        = $Frame/Content/BtnRow/HomeBtn
@onready var lb_btn:          Button        = $Frame/Content/BtnRow/LBBtn
@onready var frame:           TextureRect   = $Frame

const FRAME_TEX := "res://assets/ui/mission_fail_frame.png"

const ENCOURAGE_MESSAGES: Array[String] = [
	"อย่าเพิ่งท้อ! นักบินตัวจริงฝึกซ้อมทุกวัน 💪",
	"เกือบถึงแล้ว! ลองอีกครั้งนะ 🚀",
	"ประสบการณ์คือครู ลองอีกที! ⭐",
	"Neil Armstrong ก็เคยล้มเหลวมาก่อน! 🌙",
	"หลบอุกกาบาตให้ได้ครั้งนี้! ☄️",
]

func _ready() -> void:
	UITheme.apply_cosmos_bg(self)
	TouchInput.reset()
	SoundManager.play_bgm("game_over", 1.0)
	_apply_styles()
	_populate_results()
	_connect_buttons()
	_entrance_animation()

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null

func _bold_font(weight: int = 800) -> Font:
	var base := load(UITheme.FONT_BALOO) as Font
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv

# ไล่สีเฉพาะพิกเซลเนื้อตัวอักษร (สีขาว) — ขอบ/อีโมจิไม่ถูกเปลี่ยนสี
const GRAD_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(1.0, 0.95, 0.6, 1.0);
uniform vec4 mid_col : source_color = vec4(1.0, 0.8, 0.25, 1.0);
uniform vec4 bot_col : source_color = vec4(1.0, 0.55, 0.08, 1.0);
uniform float y0 = 0.0;
uniform float y1 = 100.0;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	if (COLOR.r > 0.85 && COLOR.g > 0.85 && COLOR.b > 0.85) {
		float t = clamp((ly - y0) / (y1 - y0), 0.0, 1.0);
		vec3 g = t < 0.45 ? mix(top_col.rgb, mid_col.rgb, t / 0.45)
						  : mix(mid_col.rgb, bot_col.rgb, (t - 0.45) / 0.55);
		COLOR = vec4(g, COLOR.a);
	}
}
"""

func _grad_text(lbl: Label, fs: int, top: Color, mid: Color, bot: Color,
		outline: Color, outline_px: int, glow: Color) -> void:
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", outline)
	lbl.add_theme_constant_override("outline_size", outline_px)
	lbl.add_theme_color_override("font_shadow_color", glow)
	lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.add_theme_constant_override("shadow_outline_size", outline_px + 16)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRAD_SHADER
	mat.shader = sh
	mat.set_shader_parameter("top_col", top)
	mat.set_shader_parameter("mid_col", mid)
	mat.set_shader_parameter("bot_col", bot)
	var f := lbl.get_theme_font("font")
	if f:
		var asc := f.get_ascent(fs)
		mat.set_shader_parameter("y0", asc - fs * 0.80)
		mat.set_shader_parameter("y1", asc + fs * 0.10)
	lbl.material = mat

# ปุ่มแคปซูลมันวาว: พื้นสี + ขอบสว่าง + เงาเรือง
func _pill(btn: Button, base: Color, h: float, fs: int) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		var c := base
		if state == "hover":
			c = base.lightened(0.12)
		elif state == "pressed":
			c = base.darkened(0.15)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_border_width_all(3)
		sb.border_width_bottom = 6
		sb.border_color = base.lightened(0.40)
		sb.set_corner_radius_all(int(h * 0.36))
		sb.shadow_color = Color(base.r, base.g, base.b, 0.45)
		sb.shadow_size = 8
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.anti_aliasing = true
		if state == "focus":
			sb.draw_center = false
			sb.set_border_width_all(0)
			sb.shadow_size = 0
		btn.add_theme_stylebox_override(state, sb)
	btn.custom_minimum_size = Vector2(0, h)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", fs)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", base.darkened(0.55))
	btn.add_theme_constant_override("outline_size", 6)

func _apply_styles() -> void:
	frame.texture = _tex(FRAME_TEX)
	# หัวข้อสาเหตุ — ไล่สีส้มแดง ขอบน้ำตาลเข้ม เรืองแดง
	_grad_text(reason_label, 58, Color(1.0, 0.86, 0.45), Color(1.0, 0.55, 0.22), Color(0.95, 0.22, 0.12),
		Color(0.30, 0.05, 0.04), 12, Color(1.0, 0.25, 0.15, 0.35))
	# คะแนน — ตัวหนาใหญ่ ไล่สีทอง
	var bold := _bold_font()
	if bold:
		score_label.add_theme_font_override("font", bold)
	_grad_text(score_label, 104, Color(1.0, 0.97, 0.62), Color(1.0, 0.82, 0.25), Color(1.0, 0.55, 0.08),
		Color(0.40, 0.17, 0.02), 10, Color(1.0, 0.70, 0.15, 0.35))
	progress_label.add_theme_font_size_override("font_size", 36)
	progress_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	progress_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.16, 0.9))
	progress_label.add_theme_constant_override("outline_size", 8)
	encourage_label.add_theme_font_size_override("font_size", 34)
	encourage_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	encourage_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.16, 0.9))
	encourage_label.add_theme_constant_override("outline_size", 8)
	_pill(retry_btn, Color(0.93, 0.36, 0.28), 84, 36)
	_pill(home_btn,  Color(0.58, 0.36, 0.95), 84, 36)
	_pill(lb_btn,    Color(0.45, 0.13, 0.48), 84, 36)

func _populate_results() -> void:
	score_label.text    = _fmt_score(GameManager.current_score)
	progress_label.text = "ระยะทาง %.0f%%  |  HP เหลือ %d%%" % [
		GameManager.journey_progress * 100.0,
		int(GameManager.current_hp)
	]
	if GameManager.current_hp <= 0.0:
		reason_label.text = "💥 ยานถูกทำลาย!"
	elif GameManager.current_energy <= 0.0:
		reason_label.text = "🔋 พลังงานหมด!"
	else:
		reason_label.text = "⏰ หมดเวลา!"
	encourage_label.text = ENCOURAGE_MESSAGES[randi() % ENCOURAGE_MESSAGES.size()]

func _connect_buttons() -> void:
	retry_btn.pressed.connect(func():
		SoundManager.play_sfx("btn_click")
		GameManager.start_mission(GameManager.selected_planet)
		GameManager.go_to_scene("gameplay"))
	home_btn.pressed.connect(func():
		SoundManager.play_sfx("btn_click")
		GameManager.go_to_scene("main_menu"))
	lb_btn.pressed.connect(func():
		SoundManager.play_sfx("btn_click")
		# หมายเหตุ: ไม่บันทึกคะแนนที่นี่ — ผู้เล่นที่แพ้/ไม่ลงจอดสำเร็จ
		# จะไม่ถูกเก็บลงตารางคะแนน (เก็บเฉพาะผู้ที่ลงจอดสำเร็จเท่านั้น)
		GameManager.go_to_scene("leaderboard"))

func _entrance_animation() -> void:
	# กรอบเด้งเข้ามา (Frame ไม่ได้อยู่ใน Container จึงปรับ scale ได้ตรง ๆ)
	frame.pivot_offset = frame.size * 0.5
	frame.modulate.a = 0.0
	frame.scale = Vector2(0.9, 0.9)
	var tween := create_tween()
	tween.tween_property(frame, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(frame, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fmt_score(val: int) -> String:
	var s := str(val); var out := ""; var cnt := 0
	for i in range(s.length()-1,-1,-1):
		if cnt > 0 and cnt%3==0: out=","+out
		out=s[i]+out; cnt+=1
	return out
