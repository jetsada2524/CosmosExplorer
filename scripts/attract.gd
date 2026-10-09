extends Node2D
# ==============================================================
#  attract.gd  —  attach กับ root Node ของ attract.tscn
#  หน้า Idle/Attract แสดงเมื่อไม่มีผู้เล่น
# ==============================================================

# ── Node References ────────────────────────────────────────────
@onready var anim_player:  AnimationPlayer = $AnimationPlayer
@onready var idle_timer:   Timer           = $IdleTimer
@onready var tap_button:   Button          = $UI/TapButton
@onready var title_label:  Label           = $UI/TitleLabel
@onready var sub_label:    Label           = $UI/SubtitleLabel
@onready var solar_anim:   Node2D          = $SolarSystemAnim
@onready var earth_sprite: Sprite2D        = $SolarSystemAnim/Earth
@onready var orbit_moon:   Node2D          = $SolarSystemAnim/OrbitMoon
@onready var moon_sprite:  Sprite2D        = $SolarSystemAnim/OrbitMoon/MoonPlanet

# ── Sound Toggle (สร้างจากโค้ด) ─────────────────────────────────
var bgm_toggle: Button = null
var sfx_toggle: Button = null

# ── Exhibition Mode: reset กลับมาที่ attract หลัง X นาที ──────
const IDLE_TIMEOUT: float = 180.0  # 3 นาที

var _started:    bool    = false
var _earth_node: Node3D = null
var _moon_node:  Node3D = null

func _ready() -> void:
    UITheme.apply_cosmos_bg(self)
    TouchInput.reset()
    SoundManager.play_bgm("attract", 2.0)
    anim_player.play("orbit_planets")

    idle_timer.wait_time = IDLE_TIMEOUT
    idle_timer.one_shot  = true
    idle_timer.timeout.connect(_on_idle_timeout)
    idle_timer.start()

    # สไตล์ปุ่ม "แตะเพื่อเริ่ม" — Pixar cyan glow
    UITheme.style_button(tap_button, UITheme.C_ACCENT_CYAN, UITheme.C_BG_DARK, 32)
    tap_button.pressed.connect(_go_to_login)

    # ปุ่มเปิด/ปิด เสียง BGM / SFX
    _create_sound_toggles()

    # ตัวอักษรหน้า Attract: โลโก้ไล่สี + ขอบ + เงา + ประกายดาว
    _style_title_texts()

    _setup_earth_3d()
    _setup_moon_3d()

# ── 3D Earth ────────────────────────────────────────────────────
func _setup_earth_3d() -> void:
    var vp_data := Planet3DView.make_planet_vp(solar_anim, "earth", Vector2i(180, 180), 10.0)
    if vp_data.is_empty():
        return
    _earth_node = vp_data["planet_node"]
    earth_sprite.visible = false
    var display := Sprite2D.new()
    display.texture = (vp_data["vp"] as SubViewport).get_texture()
    solar_anim.add_child(display)
    solar_anim.move_child(display, 2)

# ── 3D Moon ─────────────────────────────────────────────────────
func _setup_moon_3d() -> void:
    # render ที่ 120px แล้วย่อเหลือขนาดเดิม (50px) → ขอบดวงจันทร์และหลุมคมชัด ไม่เป็นขั้นบันได
    var vp_data := Planet3DView.make_planet_vp(orbit_moon, "moon", Vector2i(120, 120))
    if vp_data.is_empty():
        return
    _moon_node = vp_data["planet_node"]
    moon_sprite.visible = false
    var display := Sprite2D.new()
    display.texture = (vp_data["vp"] as SubViewport).get_texture()
    display.position = Vector2(0, -140)
    display.scale = Vector2.ONE * (50.0 / 120.0)
    (vp_data["vp"] as SubViewport).msaa_3d = Viewport.MSAA_4X
    orbit_moon.add_child(display)

# ── Rotate 3D planets every frame ──────────────────────────────
func _process(delta: float) -> void:
    if _earth_node:
        _earth_node.rotation_degrees.y += 20.0 * delta
    if _moon_node:
        _moon_node.rotation_degrees.y += 5.0 * delta

# ── Input / Navigation ──────────────────────────────────────────
# เริ่มเกมได้เฉพาะการกดปุ่ม "แตะเพื่อเริ่มผจญภัย!" (tap_button.pressed) เท่านั้น
# — ไม่รับการแตะที่อื่นบนจออีกต่อไป

func _is_mouse_over_ui() -> bool:
    var buttons: Array = [bgm_toggle, sfx_toggle, tap_button]
    for btn in buttons:
        if btn != null and btn is Control:
            var c: Control = btn as Control
            if c.get_global_rect().has_point(c.get_global_mouse_position()):
                return true
    return false

func _go_to_login() -> void:
    if _started:
        return
    _started = true
    idle_timer.stop()
    SoundManager.play_sfx("btn_click")
    GameManager.go_to_scene("login")

func _on_idle_timeout() -> void:
    anim_player.play("orbit_planets")
    idle_timer.start()

# ==============================================================
#  Sound Toggle Buttons — CanvasLayer แยก layer 10 ให้อยู่บนสุด
# ==============================================================
func _create_sound_toggles() -> void:
    # สร้าง CanvasLayer ใหม่ layer สูง (10) ให้แน่ใจว่าวาดทับทุกอย่าง
    var sound_layer := CanvasLayer.new()
    sound_layer.name = "SoundLayer"
    sound_layer.layer = 10
    add_child(sound_layer)

    # สร้าง Control เต็มจอเป็น anchor root
    var full_rect := Control.new()
    full_rect.name = "FullRect"
    full_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    full_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    sound_layer.add_child(full_rect)

    # ── ปุ่ม BGM ──────────────────────────────────────────────
    bgm_toggle = Button.new()
    bgm_toggle.name = "BgmToggle"
    bgm_toggle.size = Vector2(155, 56)
    bgm_toggle.position = Vector2(1920 - 155 - 170 - 16, 24)   # มุมขวาบน
    bgm_toggle.text = "BGM  ON"
    bgm_toggle.add_theme_font_size_override("font_size", 20)
    bgm_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
    full_rect.add_child(bgm_toggle)

    # ── ปุ่ม SFX ──────────────────────────────────────────────
    sfx_toggle = Button.new()
    sfx_toggle.name = "SfxToggle"
    sfx_toggle.size = Vector2(155, 56)
    sfx_toggle.position = Vector2(1920 - 155 - 24, 24)          # ถัดไปทางขวา
    sfx_toggle.text = "SFX  ON"
    sfx_toggle.add_theme_font_size_override("font_size", 20)
    sfx_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
    full_rect.add_child(sfx_toggle)

    # ── สไตล์ + connect ──────────────────────────────────────
    _update_bgm_button_style()
    _update_sfx_button_style()
    bgm_toggle.pressed.connect(_on_bgm_toggle)
    sfx_toggle.pressed.connect(_on_sfx_toggle)
    SoundManager.bgm_mute_changed.connect(func(_m: bool) -> void: _update_bgm_button_style())
    SoundManager.sfx_mute_changed.connect(func(_m: bool) -> void: _update_sfx_button_style())

    print("[Attract] Sound toggles created — BGM pos: %s, SFX pos: %s" % [str(bgm_toggle.position), str(sfx_toggle.position)])

func _on_bgm_toggle() -> void:
    SoundManager.toggle_bgm_mute()

func _on_sfx_toggle() -> void:
    SoundManager.toggle_sfx_mute()

func _update_bgm_button_style() -> void:
    if bgm_toggle == null:
        return
    bgm_toggle.text = "BGM OFF" if SoundManager.bgm_muted else "BGM ON"
    _style_toggle(bgm_toggle, not SoundManager.bgm_muted, true)

func _update_sfx_button_style() -> void:
    if sfx_toggle == null:
        return
    sfx_toggle.text = "SFX OFF" if SoundManager.sfx_muted else "SFX ON"
    _style_toggle(sfx_toggle, not SoundManager.sfx_muted)


# ==============================================================
#  TITLE TEXT STYLE — โลโก้ "COSMOS EXPLORER" แบบไล่สี + ขอบหนา + เงา 3D
# ==============================================================
const TITLE_FONT    := "res://fonts/Baloo_2/static/Baloo2-ExtraBold.ttf"
const THAI_FONT     := "res://fonts/Sarabun/Sarabun-ExtraBold.ttf"
const TITLE_SIZE    := 112
const SUB_SIZE      := 54
const BTN_SIZE      := 38
const C_TITLE_EDGE  := Color(0.19, 0.07, 0.36)        # ขอบม่วงเข้ม
const C_TITLE_SHADE := Color(0.08, 0.02, 0.20, 0.95)  # เงาด้านล่าง
const C_SUB_EDGE    := Color(0.14, 0.06, 0.30)
const C_BTN_EDGE    := Color(0.02, 0.28, 0.36)        # ขอบตัวอักษรบนปุ่มฟ้า

# shader ไล่สีเฉพาะ "เนื้อ" ตัวอักษร (สีขาว) — ขอบและเงาสีเข้มไม่ถูกเปลี่ยน
const TITLE_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(1.00, 0.88, 0.98, 1.0);
uniform vec4 mid_col : source_color = vec4(0.86, 0.68, 1.00, 1.0);
uniform vec4 bot_col : source_color = vec4(0.56, 0.40, 0.98, 1.0);
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

func _style_title_texts() -> void:
    var f_title := load(TITLE_FONT) as Font
    var f_thai  := load(THAI_FONT) as Font

    # ── COSMOS EXPLORER ───────────────────────────────────────
    title_label.anchor_top    = 0.555
    title_label.anchor_bottom = 0.555
    title_label.offset_left   = -760.0
    title_label.offset_right  =  760.0
    if f_title: title_label.add_theme_font_override("font", f_title)
    title_label.add_theme_font_size_override("font_size", TITLE_SIZE)
    title_label.add_theme_color_override("font_color", Color.WHITE)
    title_label.add_theme_color_override("font_outline_color", C_TITLE_EDGE)
    title_label.add_theme_constant_override("outline_size", 22)
    title_label.add_theme_color_override("font_shadow_color", C_TITLE_SHADE)
    title_label.add_theme_constant_override("shadow_offset_x", 0)
    title_label.add_theme_constant_override("shadow_offset_y", 9)
    title_label.add_theme_constant_override("shadow_outline_size", 24)
    var mat := ShaderMaterial.new()
    var sh := Shader.new()
    sh.code = TITLE_SHADER
    mat.shader = sh
    if f_title:
        var asc := f_title.get_ascent(TITLE_SIZE)
        mat.set_shader_parameter("y0", asc - TITLE_SIZE * 0.72)   # บนตัวอักษรพิมพ์ใหญ่
        mat.set_shader_parameter("y1", asc)                        # เส้นฐาน
    title_label.material = mat

    # ── นักบินอวกาศตัวน้อย ────────────────────────────────────
    sub_label.anchor_top    = 0.705
    sub_label.anchor_bottom = 0.705
    sub_label.offset_left   = -500.0
    sub_label.offset_right  =  500.0
    if f_thai: sub_label.add_theme_font_override("font", f_thai)
    sub_label.add_theme_font_size_override("font_size", SUB_SIZE)
    sub_label.add_theme_color_override("font_color", Color.WHITE)
    sub_label.add_theme_color_override("font_outline_color", C_SUB_EDGE)
    sub_label.add_theme_constant_override("outline_size", 14)
    sub_label.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.15, 0.85))
    sub_label.add_theme_constant_override("shadow_offset_x", 0)
    sub_label.add_theme_constant_override("shadow_offset_y", 5)
    sub_label.add_theme_constant_override("shadow_outline_size", 14)

    # ── ปุ่ม "แตะเพื่อเริ่มผจญภัย!" ──────────────────────────────
    tap_button.anchor_top    = 0.875
    tap_button.anchor_bottom = 0.875
    tap_button.offset_left   = -270.0
    tap_button.offset_right  =  270.0
    tap_button.offset_top    = -44.0
    tap_button.offset_bottom =  44.0
    if f_thai: tap_button.add_theme_font_override("font", f_thai)
    tap_button.add_theme_font_size_override("font_size", BTN_SIZE)
    for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        tap_button.add_theme_color_override(k, Color.WHITE)
    tap_button.add_theme_color_override("font_outline_color", C_BTN_EDGE)
    tap_button.add_theme_constant_override("outline_size", 10)
    _glossy_pill(tap_button, 88.0, C_PILL_CYAN, C_PILL_CYAN_EDGE, Color(0.25, 0.95, 1.0, 0.55))
    # ขยาย-หดเบา ๆ แทนการกระพริบจาง (ตัวอักษรคมชัดตลอด)
    tap_button.pivot_offset = Vector2(270.0, 44.0)
    var pulse := create_tween().set_loops()
    pulse.tween_property(tap_button, "scale", Vector2(1.05, 1.05), 0.9).set_trans(Tween.TRANS_SINE)
    pulse.tween_property(tap_button, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

    # ── ประกายดาวรอบโลโก้ + ปุ่ม (วางหลัง layout คำนวณขนาดเสร็จ) ──
    await get_tree().process_frame
    var ui := title_label.get_parent()
    var tw := title_label.get_theme_font("font").get_string_size(
        title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
    var tc := title_label.global_position + Vector2(title_label.size.x * 0.5, 0.0)
    var asc2 := title_label.get_theme_font("font").get_ascent(TITLE_SIZE)
    var cap_top := tc.y + asc2 - TITLE_SIZE * 0.72
    _add_sparkle(ui, Vector2(tc.x - tw * 0.5 - 14.0, cap_top - 6.0), 26.0, 0.0)
    _add_sparkle(ui, Vector2(tc.x - tw * 0.02,       cap_top - 12.0), 22.0, 0.5)
    _add_sparkle(ui, Vector2(tc.x + tw * 0.5 + 10.0, cap_top - 2.0), 30.0, 1.0)
    var bc := tap_button.global_position
    _add_sparkle(ui, bc + Vector2(540.0 - 6.0, 4.0), 22.0, 0.3)
    _add_sparkle(ui, bc + Vector2(6.0, 84.0), 16.0, 0.8)

func _add_sparkle(parent: Node, pos: Vector2, size: float, delay: float) -> void:
    var sp := Sparkle.new()
    sp.radius = size
    sp.position = pos
    parent.add_child(sp)
    sp.scale = Vector2(0.6, 0.6)
    var t := create_tween().set_loops()
    t.tween_interval(delay)
    t.tween_property(sp, "scale", Vector2(1.1, 1.1), 0.7).set_trans(Tween.TRANS_SINE)
    t.tween_property(sp, "scale", Vector2(0.6, 0.6), 0.7).set_trans(Tween.TRANS_SINE)
    t.tween_interval(1.2 - delay)

# ประกายดาว 4 แฉก (วาดเอง ไม่ต้องใช้รูป)
class Sparkle extends Control:
    var radius: float = 24.0
    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
    func _draw() -> void:
        var r := radius
        var w := r * 0.22
        var glow := Color(1.0, 0.92, 0.75, 0.25)
        draw_circle(Vector2.ZERO, r * 0.55, glow)
        var pts := PackedVector2Array([
            Vector2(0, -r), Vector2(w, -w), Vector2(r, 0), Vector2(w, w),
            Vector2(0, r), Vector2(-w, w), Vector2(-r, 0), Vector2(-w, -w)])
        draw_colored_polygon(pts, Color(1.0, 0.97, 0.88))
        draw_circle(Vector2.ZERO, w * 0.9, Color.WHITE)


# ==============================================================
#  GLOSSY PILL BUTTONS — ปุ่มแคปซูลมันวาว (ตามภาพอ้างอิง)
# ==============================================================
const C_PILL_CYAN      := Color(0.20, 0.84, 0.92)   # ฟ้าสด (ปุ่มเริ่ม / ปุ่ม ON)
const C_PILL_CYAN_EDGE := Color(0.03, 0.42, 0.52)   # ขอบฟ้าเข้ม
const C_PILL_MAGENTA      := Color(0.88, 0.22, 0.78)   # ชมพูม่วง (ปุ่ม BGM ON)
const C_PILL_MAGENTA_EDGE := Color(0.42, 0.04, 0.40)
const C_PILL_OFF       := Color(0.30, 0.37, 0.47)   # เทาอมฟ้า (ปุ่ม OFF)
const C_PILL_OFF_EDGE  := Color(0.55, 0.62, 0.72)   # ขอบเทาอ่อน

# สร้าง StyleBox แคปซูล: มุมโค้งเต็ม + ขอบล่างหนา (มิติ 3D) + เรืองแสงรอบปุ่ม + แถบเงาวาวด้านบน
func _glossy_pill(btn: Button, h: float, base: Color, edge: Color, glow: Color) -> void:
    for state in ["normal", "hover", "pressed", "disabled"]:
        var sb := StyleBoxFlat.new()
        var c := base
        if state == "hover":   c = base.lightened(0.10)
        if state == "pressed": c = base.darkened(0.12)
        sb.bg_color = c
        sb.set_corner_radius_all(int(h * 0.5))
        sb.border_color = edge
        sb.set_border_width_all(3)
        sb.border_width_bottom = 6 if state != "pressed" else 3
        sb.shadow_color = glow
        sb.shadow_size  = 12 if glow.a > 0.0 else 0
        sb.anti_aliasing = true
        sb.corner_detail = 12
        btn.add_theme_stylebox_override(state, sb)
    btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# ปุ่ม BGM / SFX: ON = ฟ้ามันวาว + เรืองแสง, OFF = เทาอมฟ้า ไม่เรืองแสง
func _style_toggle(btn: Button, on: bool, magenta: bool = false) -> void:
    btn.modulate = Color.WHITE
    var f := load(TITLE_FONT) as Font
    if f: btn.add_theme_font_override("font", f)
    btn.add_theme_font_size_override("font_size", 24)
    var txt := Color.WHITE if on else Color(0.80, 0.85, 0.92)
    for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        btn.add_theme_color_override(k, txt)
    var on_col  := C_PILL_MAGENTA if magenta else C_PILL_CYAN
    var on_edge := C_PILL_MAGENTA_EDGE if magenta else C_PILL_CYAN_EDGE
    var on_glow := Color(1.0, 0.35, 0.90, 0.45) if magenta else Color(0.25, 0.95, 1.0, 0.45)
    btn.add_theme_color_override("font_outline_color", on_edge if on else Color(0.16, 0.20, 0.27))
    btn.add_theme_constant_override("outline_size", 6)
    if on:
        _glossy_pill(btn, btn.size.y, on_col, on_edge, on_glow)
    else:
        _glossy_pill(btn, btn.size.y, C_PILL_OFF, C_PILL_OFF_EDGE, Color(0, 0, 0, 0))
