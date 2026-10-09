extends Control
# ==============================================================
#  win.gd  —  หน้าสรุปผล "ภารกิจสำเร็จ!" บนกรอบ assets/ui/result_frame.png
#
#  Layout (ตามภาพอ้างอิง):
#            🏆  (ถ้วยรางวัลวางบนรอยบากด้านบนของกรอบ + ประกาย/คอนเฟตติ)
#     ┌──────────────────────────────────────────────────┐
#     │              ภารกิจสำเร็จ! 🎉  (ไล่สีทอง)          │
#     │                 ★  ★  ★                           │
#     │       คุณลงจอดที่ [ดาว] สำเร็จแล้ว                 │
#     │  [⏱ 00:10]          170          [🌑 1]           │
#     │         ยังไม่มีข้อมูลในตารางคะแนน                  │
#     │  [Mission Complete] [Iron Shield] [Eco] [First]   │
#     │  [🏠 หน้าหลัก] [🔄 เล่นอีกครั้ง] [▶ ดาวใหม่]       │
#     │  [============ 🏆 ดูอันดับ (แถบล่างของกรอบ) ======] │
#     └──────────────────────────────────────────────────┘
# ==============================================================

const FRAME_TEX      := "res://assets/ui/result_frame.png"
const STAR_FULL_TEX  := "res://assets/ui/win_star_full.png"
const STAR_EMPTY_TEX := "res://assets/ui/win_star_empty.png"
const STOPWATCH_TEX  := "res://assets/ui/hud_stopwatch.png"
const COIN_TEX       := "res://assets/ui/hud_moon_coin.png"

@onready var frame:            TextureRect   = $Frame
@onready var trophy_label:     Label         = $Frame/TrophyLabel
@onready var banner_label:     Label         = $Frame/Content/BannerLabel
@onready var star_row:         HBoxContainer = $Frame/Content/StarRow
@onready var result_label:     Label         = $Frame/Content/ResultLabel
@onready var time_box:         PanelContainer = $Frame/Content/StatsRow/TimeBox
@onready var time_label:       Label         = $Frame/Content/StatsRow/TimeBox/TimeRow/TimeLabel
@onready var coin_box:         PanelContainer = $Frame/Content/StatsRow/CoinBox
@onready var coin_label:       Label         = $Frame/Content/StatsRow/CoinBox/CoinRow/CoinLabel
@onready var score_label:      Label         = $Frame/Content/StatsRow/ScoreLabel
@onready var rank_status_label: Label        = $Frame/Content/RankStatusLabel
@onready var home_btn:         Button        = $Frame/Content/BtnRow/HomeBtn
@onready var retry_btn:        Button        = $Frame/Content/BtnRow/RetryBtn
@onready var next_btn:         Button        = $Frame/Content/BtnRow/NextBtn
@onready var view_lb_btn:      Button        = $Frame/ViewLeaderboardBtn
@onready var badge_row:        HBoxContainer = $Frame/Content/BadgeRow
@onready var anim:             AnimationPlayer = $AnimationPlayer

func _ready() -> void:
    UITheme.apply_cosmos_bg(self)
    TouchInput.reset()
    SoundManager.play_bgm("win", 1.0)
    # หมายเหตุ: ไม่ต้องเรียก save_result() ที่นี่ — GameManager.complete_mission()
    # บันทึกผลไปแล้วตอนผู้เล่นลงจอดสำเร็จ (ป้องกันการบันทึกซ้ำ)
    _apply_styles()
    _populate_result()
    _populate_rank_status()
    _show_badges()
    _connect_buttons()
    _build_trophy_fx()
    _entrance_animation()

# ── helpers ───────────────────────────────────────────────────
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

func _icon(tex: Texture2D, sz: float) -> TextureRect:
    var ic := TextureRect.new()
    ic.texture = tex
    ic.custom_minimum_size = Vector2(sz, sz)
    ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return ic

# ไล่สีทองเฉพาะพิกเซลเนื้อตัวอักษร (สีขาว) — ขอบ/อีโมจิไม่ถูกเปลี่ยนสี
const GOLD_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(1.00, 0.97, 0.62, 1.0);
uniform vec4 mid_col : source_color = vec4(1.00, 0.82, 0.25, 1.0);
uniform vec4 bot_col : source_color = vec4(1.00, 0.55, 0.08, 1.0);
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

func _gold_text(lbl: Label, fs: int, outline: Color, outline_px: int) -> void:
    lbl.add_theme_font_size_override("font_size", fs)
    lbl.add_theme_color_override("font_color", Color.WHITE)
    lbl.add_theme_color_override("font_outline_color", outline)
    lbl.add_theme_constant_override("outline_size", outline_px)
    lbl.add_theme_color_override("font_shadow_color", Color(1.0, 0.65, 0.1, 0.35))
    lbl.add_theme_constant_override("shadow_offset_y", 0)
    lbl.add_theme_constant_override("shadow_outline_size", outline_px + 14)
    var mat := ShaderMaterial.new()
    var sh := Shader.new()
    sh.code = GOLD_SHADER
    mat.shader = sh
    var f := lbl.get_theme_font("font")
    if f:
        var asc := f.get_ascent(fs)
        mat.set_shader_parameter("y0", asc - fs * 0.80)
        mat.set_shader_parameter("y1", asc + fs * 0.10)
    lbl.material = mat

# ปุ่มแคปซูลมันวาว: พื้นสี + ขอบสว่าง + เงาเรือง
func _pill(btn: Button, base: Color, h: float, fs: int) -> void:
    for state in ["normal", "hover", "pressed", "focus", "disabled"]:
        var c := base
        if state == "hover":
            c = base.lightened(0.12)
        elif state == "pressed":
            c = base.darkened(0.15)
        var sb := StyleBoxFlat.new()
        sb.bg_color = c
        sb.set_border_width_all(3)
        sb.border_width_bottom = 5
        sb.border_color = base.lightened(0.45)
        sb.set_corner_radius_all(int(h * 0.42))
        sb.shadow_color = Color(base.r, base.g, base.b, 0.45)
        sb.shadow_size = 8
        sb.content_margin_left = 18
        sb.content_margin_right = 18
        sb.anti_aliasing = true
        if state == "focus":
            sb.draw_center = false
            sb.set_border_width_all(0)
            sb.shadow_size = 0
        btn.add_theme_stylebox_override(state, sb)
    btn.custom_minimum_size.y = h
    btn.add_theme_font_size_override("font_size", fs)
    btn.add_theme_color_override("font_color", Color.WHITE)
    btn.add_theme_color_override("font_hover_color", Color.WHITE)
    btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.9))
    btn.add_theme_color_override("font_outline_color", base.darkened(0.55))
    btn.add_theme_constant_override("outline_size", 6)

func _stat_pill() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.11, 0.07, 0.27, 0.95)
    sb.set_border_width_all(3)
    sb.border_color = Color(0.48, 0.38, 0.86)
    sb.set_corner_radius_all(34)
    sb.shadow_color = Color(0, 0, 0, 0.35)
    sb.shadow_size = 6
    sb.content_margin_left = 6
    sb.content_margin_right = 22
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2
    return sb

# ── Styles ────────────────────────────────────────────────────
func _apply_styles() -> void:
    frame.texture = _tex(FRAME_TEX)
    var bold := _bold_font()

    # ถ้วยรางวัล
    trophy_label.add_theme_font_size_override("font_size", 170)

    # หัวข้อ "ภารกิจสำเร็จ! 🎉" — ไล่สีทอง ขอบน้ำตาลส้ม
    _gold_text(banner_label, 70, Color(0.42, 0.16, 0.02, 1.0), 14)

    # ข้อความผล
    result_label.add_theme_font_size_override("font_size", 34)
    result_label.add_theme_color_override("font_color", Color.WHITE)
    result_label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.24, 0.9))
    result_label.add_theme_constant_override("outline_size", 8)

    # เวลา (นาฬิกาจับเวลา + ตัวเลข)
    time_box.add_theme_stylebox_override("panel", _stat_pill())
    var trow := time_label.get_parent() as HBoxContainer
    var sw := _icon(_tex(STOPWATCH_TEX), 58)
    trow.add_child(sw)
    trow.move_child(sw, 0)
    if bold:
        time_label.add_theme_font_override("font", bold)
    time_label.add_theme_font_size_override("font_size", 50)
    time_label.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
    time_label.add_theme_color_override("font_outline_color", Color(0.20, 0.45, 0.95, 0.85))
    time_label.add_theme_constant_override("outline_size", 6)

    # เหรียญ (หินดวงจันทร์ + จำนวน)
    coin_box.add_theme_stylebox_override("panel", _stat_pill())
    var crow := coin_label.get_parent() as HBoxContainer
    var ci := _icon(_tex(COIN_TEX), 80)
    crow.add_child(ci)
    crow.move_child(ci, 0)
    if bold:
        coin_label.add_theme_font_override("font", bold)
    coin_label.add_theme_font_size_override("font_size", 50)
    coin_label.add_theme_color_override("font_color", Color.WHITE)
    coin_label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.24, 0.9))
    coin_label.add_theme_constant_override("outline_size", 6)

    # คะแนนรวม — ตัวใหญ่ไล่สีทอง
    if bold:
        score_label.add_theme_font_override("font", bold)
    _gold_text(score_label, 108, Color(0.45, 0.18, 0.02, 1.0), 12)
    # ตัวเลขคะแนนใหญ่ แต่ไม่ให้ความสูงบรรทัดดันแถวสถิติให้สูงเกินไป:
    # ห่อด้วย Control ความสูงคงที่ แล้วให้ป้ายล้นออกบน-ล่างเท่ากัน
    var row := score_label.get_parent()
    var holder := Control.new()
    holder.name = "ScoreHolder"
    holder.custom_minimum_size = Vector2(320, 116)
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(holder)
    row.move_child(holder, score_label.get_index())
    score_label.reparent(holder)
    score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    score_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
    score_label.grow_vertical = Control.GROW_DIRECTION_BOTH

    # สถานะอันดับ
    rank_status_label.add_theme_font_size_override("font_size", 26)
    rank_status_label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.24, 0.9))
    rank_status_label.add_theme_constant_override("outline_size", 6)

    # ปุ่ม
    _pill(home_btn,  Color(0.62, 0.30, 0.95), 74, 34)
    _pill(retry_btn, Color(0.98, 0.52, 0.12), 74, 34)
    _pill(next_btn,  Color(0.22, 0.78, 0.30), 74, 34)

    # ปุ่ม "ดูอันดับ" อยู่ในแถบล่างของกรอบ — โปร่งใส ไฮไลต์ตอนชี้
    for state in ["normal", "hover", "pressed", "focus"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(1, 1, 1, 0.0 if state in ["normal", "focus"] else (0.08 if state == "hover" else 0.14))
        sb.set_corner_radius_all(20)
        view_lb_btn.add_theme_stylebox_override(state, sb)
    view_lb_btn.add_theme_font_size_override("font_size", 32)
    view_lb_btn.add_theme_color_override("font_color", Color.WHITE)
    view_lb_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.6))
    view_lb_btn.add_theme_color_override("font_outline_color", Color(0.10, 0.04, 0.24, 0.9))
    view_lb_btn.add_theme_constant_override("outline_size", 6)

func _populate_result() -> void:
    var planet_name: String = GameManager.selected_planet.get("name_th","")
    result_label.text = "คุณลงจอดที่ %s สำเร็จแล้ว" % planet_name

    var time_used := LeaderboardManager._calc_time_used()
    @warning_ignore("integer_division")
    time_label.text = "%02d:%02d" % [int(time_used)/60, int(time_used)%60]

    @warning_ignore("integer_division")
    var coins: int = GameManager.current_score / 100
    coin_label.text = "%d" % coins

    score_label.text = _fmt_score(GameManager.current_score)

    # ดาว 3 ดวง (ดาวทอง = ได้, ดาวม่วงเข้ม = ยังไม่ได้)
    for child in star_row.get_children():
        child.queue_free()
    var stars := LeaderboardManager._calc_stars()
    var full_tex := _tex(STAR_FULL_TEX)
    var empty_tex := _tex(STAR_EMPTY_TEX)
    for i in 3:
        var st := _icon(full_tex if i < stars else empty_tex, 96 if i == 1 else 84)
        st.pivot_offset = st.custom_minimum_size * 0.5
        star_row.add_child(st)
        st.modulate.a = 0.0
        st.scale = Vector2(0.4, 0.4)
        var tween := create_tween()
        tween.tween_interval(0.3 * i + 0.5)
        tween.tween_property(st, "modulate:a", 1.0, 0.2)
        tween.parallel().tween_property(st, "scale", Vector2(1.25, 1.25), 0.2) \
            .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(st, "scale", Vector2.ONE, 0.15)

# ติดอันดับ = อยู่ใน Top 10 ของตารางคะแนน
const RANKED_THRESHOLD: int = 10

func _populate_rank_status() -> void:
    # ใช้คะแนนของรอบนี้ (current_score) หาอันดับ ไม่ใช่อันดับที่ดีที่สุดที่เคยทำได้
    var rank := LeaderboardManager.get_rank_for_score(GameManager.player_name, GameManager.current_score)
    if rank <= 0:
        rank_status_label.text = "ยังไม่มีข้อมูลในตารางคะแนน"
        rank_status_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.78))
    elif rank <= RANKED_THRESHOLD:
        rank_status_label.text = "🏆 ติดอันดับที่ %d ในตารางคะแนน!" % rank
        rank_status_label.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)
    else:
        rank_status_label.text = "อันดับของคุณ: %d (ยังไม่ติด Top %d)" % [rank, RANKED_THRESHOLD]
        rank_status_label.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)

const BADGE_INFO: Dictionary = {
    "Mission Complete":   {"icon": "🏁", "color": Color(0.20, 0.55, 0.90)},
    "Iron Shield":        {"icon": "🛡️", "color": Color(0.36, 0.48, 0.80)},
    "Eco Pilot":          {"icon": "🌱", "color": Color(0.24, 0.62, 0.26)},
    "Star Collector":     {"icon": "⭐", "color": Color(0.88, 0.62, 0.10)},
    "First Flight":       {"icon": "🚀", "color": Color(0.56, 0.30, 0.82)},
    "Deep Space Pioneer": {"icon": "🌌", "color": Color(0.45, 0.22, 0.70)},
    "Pluto Legend":       {"icon": "🪐", "color": Color(0.78, 0.30, 0.58)},
}

func _show_badges() -> void:
    for child in badge_row.get_children():
        child.queue_free()
    for badge in GameManager.badges_earned:
        var info: Dictionary = BADGE_INFO.get(badge, {"icon": "🏅", "color": UITheme.C_ACCENT_GOLD})
        var c: Color = info["color"]
        var chip := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = c
        sb.set_border_width_all(3)
        sb.border_width_bottom = 5
        sb.border_color = c.lightened(0.45)
        sb.set_corner_radius_all(28)
        sb.shadow_color = Color(c.r, c.g, c.b, 0.40)
        sb.shadow_size = 6
        sb.content_margin_left = 20
        sb.content_margin_right = 20
        sb.content_margin_top = 4
        sb.content_margin_bottom = 6
        chip.add_theme_stylebox_override("panel", sb)
        chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # เต็มแถวเหมือนแถวปุ่ม
        var lbl := Label.new()
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.text = "%s %s" % [info["icon"], badge]
        lbl.add_theme_font_size_override("font_size", 33)
        lbl.add_theme_color_override("font_color", Color.WHITE)
        lbl.add_theme_color_override("font_outline_color", c.darkened(0.55))
        lbl.add_theme_constant_override("outline_size", 6)
        chip.add_child(lbl)
        badge_row.add_child(chip)

func _connect_buttons() -> void:
    home_btn.pressed.connect(func():
        SoundManager.play_sfx("btn_click")
        GameManager.go_to_scene("main_menu"))
    retry_btn.pressed.connect(func():
        SoundManager.play_sfx("btn_click")
        GameManager.start_mission(GameManager.selected_planet)
        GameManager.go_to_scene("gameplay"))
    next_btn.pressed.connect(func():
        SoundManager.play_sfx("btn_click")
        GameManager.go_to_scene("planet_select"))
    view_lb_btn.pressed.connect(func():
        SoundManager.play_sfx("btn_click")
        GameManager.go_to_scene("leaderboard"))

# ── ถ้วยรางวัล: แสงเรือง + คอนเฟตติ + ประกายดาว ─────────────────
func _soft_dot(sz: int) -> Texture2D:
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
    var t := GradientTexture2D.new()
    t.gradient = g
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to = Vector2(1.0, 0.5)
    t.width = sz
    t.height = sz
    return t

func _build_trophy_fx() -> void:
    var center := Vector2(700, 52)   # กึ่งกลางถ้วย (พิกัดในกรอบ)
    # แสงเรืองสีทองหลังถ้วย
    var glow := Sprite2D.new()
    glow.texture = _soft_dot(256)
    glow.position = center
    glow.scale = Vector2(1.5, 1.5)
    glow.modulate = Color(1.0, 0.82, 0.30, 0.65)
    var gm := CanvasItemMaterial.new()
    gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    glow.material = gm
    frame.add_child(glow)
    frame.move_child(glow, trophy_label.get_index())
    var gt := glow.create_tween().set_loops()
    gt.tween_property(glow, "scale", Vector2(1.7, 1.7), 1.2).set_trans(Tween.TRANS_SINE)
    gt.tween_property(glow, "scale", Vector2(1.45, 1.45), 1.2).set_trans(Tween.TRANS_SINE)
    # คอนเฟตติหลากสีพุ่งออกจากถ้วย
    var conf := CPUParticles2D.new()
    var ctex := GradientTexture2D.new()
    var cg := Gradient.new()
    cg.colors = PackedColorArray([Color.WHITE, Color.WHITE])
    ctex.gradient = cg
    ctex.width = 10
    ctex.height = 5
    conf.texture = ctex
    conf.position = center + Vector2(0, -40)
    conf.amount = 46
    conf.lifetime = 2.6
    conf.preprocess = 1.0
    conf.direction = Vector2(0, -1)
    conf.spread = 70.0
    conf.initial_velocity_min = 140.0
    conf.initial_velocity_max = 260.0
    conf.gravity = Vector2(0, 180)
    conf.angular_velocity_min = -360.0
    conf.angular_velocity_max = 360.0
    conf.scale_amount_min = 0.9
    conf.scale_amount_max = 1.6
    var cols := Gradient.new()
    cols.colors = PackedColorArray([Color(1.0, 0.35, 0.45), Color(1.0, 0.82, 0.2), Color(0.35, 0.85, 1.0),
                                    Color(0.55, 1.0, 0.45), Color(0.80, 0.45, 1.0)])
    conf.color_initial_ramp = cols
    frame.add_child(conf)
    # ประกายดาวกะพริบรอบถ้วย
    var spark := CPUParticles2D.new()
    spark.texture = _soft_dot(24)
    spark.position = center
    spark.amount = 18
    spark.lifetime = 1.4
    spark.preprocess = 1.4
    spark.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    spark.emission_sphere_radius = 120.0
    spark.gravity = Vector2.ZERO
    spark.initial_velocity_min = 0.0
    spark.initial_velocity_max = 8.0
    spark.scale_amount_min = 0.3
    spark.scale_amount_max = 0.8
    var sr := Gradient.new()
    sr.colors = PackedColorArray([Color(1, 0.95, 0.6, 0), Color(1, 0.95, 0.6, 1), Color(1, 0.95, 0.6, 0)])
    sr.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
    spark.color_ramp = sr
    var sm := CanvasItemMaterial.new()
    sm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    spark.material = sm
    frame.add_child(spark)
    # ถ้วยลอยขึ้นลงเบา ๆ
    trophy_label.pivot_offset = trophy_label.size * 0.5
    var tt := trophy_label.create_tween().set_loops()
    tt.tween_property(trophy_label, "position:y", trophy_label.position.y - 8.0, 1.1).set_trans(Tween.TRANS_SINE)
    tt.tween_property(trophy_label, "position:y", trophy_label.position.y, 1.1).set_trans(Tween.TRANS_SINE)

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
