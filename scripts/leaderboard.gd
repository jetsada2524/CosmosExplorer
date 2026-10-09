extends Control
# ==============================================================
#  leaderboard.gd  —  ตารางอันดับบนกรอบ assets/ui/result_table_frame.png
#  • หัวข้อ "ตารางอันดับ 🏆" อยู่ในช่องบากด้านบนของกรอบ
#  • แต่ละแถว: อันดับ (มงกุฎ/เหรียญ) | ยานที่ผู้เล่นใช้ในรอบนั้น | ชื่อ | ดาว | คะแนน | ดาวรางวัล
#  • แถวของผู้เล่นปัจจุบัน = แคปซูลเขียวมันวาว, แถวอื่น = แคปซูลน้ำเงินเข้ม
# ==============================================================

const FRAME_TEX     := "res://assets/ui/result_table_frame.png"
const STAR_TEX      := "res://assets/ui/win_star_full.png"
# ไอคอนยานตามลำดับหน้าเลือกตัวละคร (login.gd) — avatar ที่บันทึกไว้ในแต่ละรอบ
const SHIP_ICONS: Array[String] = [
    "res://assets/ui/ship_one_explorer_icon.png",
    "res://assets/ui/ship_two_wing_icon.png",
    "res://assets/ui/ship_three_comet_icon.png",
]
const SHIP_FACES_LEFT: Array[bool] = [true, false, true]   # กลับด้านให้หัวยานหันขวาเหมือนกันทุกลำ

@onready var frame:           TextureRect    = $Frame
@onready var rank_list:       VBoxContainer  = $Frame/ScrollContainer/RankList
@onready var scroll:          ScrollContainer = $Frame/ScrollContainer
@onready var player_rank_lbl: Label          = $Frame/PlayerRankLabel
@onready var badge_row:       HBoxContainer  = $Frame/BadgeRow
@onready var back_btn:        Button         = $Frame/BackBtn
@onready var clear_btn:       Button         = $Frame/ClearBtn
@onready var title_lbl:       Label          = $Frame/TitleLabel

var _bold: Font = null
var _ship_tex: Array[Texture2D] = []
var _star_tex: Texture2D = null

func _ready() -> void:
    UITheme.apply_cosmos_bg(self)
    TouchInput.reset()
    SoundManager.play_bgm("menu", 1.0)
    clear_btn.visible = GameManager.is_admin   # ปุ่มลบข้อมูลทั้งหมด แสดงเฉพาะ admin
    _bold = _bold_font()
    for p in SHIP_ICONS:
        _ship_tex.append(_tex(p))
    _star_tex = _tex(STAR_TEX)
    _apply_styles()
    _connect_buttons()
    _populate_list()
    _show_badges()
    _show_player_rank()

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

func _icon(tex: Texture2D, sz: Vector2) -> TextureRect:
    var ic := TextureRect.new()
    ic.texture = tex
    ic.custom_minimum_size = sz
    ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return ic

func _outline(lbl: Label, col: Color, px: int) -> void:
    lbl.add_theme_color_override("font_outline_color", col)
    lbl.add_theme_constant_override("outline_size", px)

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

func _pill(btn: Button, base: Color, fs: int) -> void:
    for state in ["normal", "hover", "pressed", "focus"]:
        var c := base
        if state == "hover":
            c = base.lightened(0.12)
        elif state == "pressed":
            c = base.darkened(0.15)
        var sb := StyleBoxFlat.new()
        sb.bg_color = c
        sb.set_border_width_all(3)
        sb.border_width_bottom = 5
        sb.border_color = base.lightened(0.40)
        sb.set_corner_radius_all(24)
        sb.shadow_color = Color(base.r, base.g, base.b, 0.45)
        sb.shadow_size = 8
        sb.content_margin_left = 22
        sb.content_margin_right = 22
        if state == "focus":
            sb.draw_center = false
            sb.set_border_width_all(0)
            sb.shadow_size = 0
        btn.add_theme_stylebox_override(state, sb)
    btn.add_theme_font_size_override("font_size", fs)
    btn.add_theme_color_override("font_color", Color.WHITE)
    btn.add_theme_color_override("font_hover_color", Color.WHITE)
    btn.add_theme_color_override("font_outline_color", base.darkened(0.55))
    btn.add_theme_constant_override("outline_size", 6)

# ── Styles ────────────────────────────────────────────────────
func _apply_styles() -> void:
    frame.texture = _tex(FRAME_TEX)

    # หัวข้อในช่องบาก — ไล่สีทอง
    var fs := 54
    title_lbl.add_theme_font_size_override("font_size", fs)
    title_lbl.add_theme_color_override("font_color", Color.WHITE)
    _outline(title_lbl, Color(0.40, 0.15, 0.02), 12)
    var mat := ShaderMaterial.new()
    var sh := Shader.new()
    sh.code = GOLD_SHADER
    mat.shader = sh
    var f := title_lbl.get_theme_font("font")
    if f:
        var asc := f.get_ascent(fs)
        mat.set_shader_parameter("y0", asc - fs * 0.80)
        mat.set_shader_parameter("y1", asc + fs * 0.10)
    title_lbl.material = mat

    player_rank_lbl.add_theme_font_size_override("font_size", 30)
    player_rank_lbl.add_theme_color_override("font_color", Color(0.50, 0.88, 1.0))
    _outline(player_rank_lbl, Color(0.04, 0.06, 0.20, 0.9), 6)

    _pill(back_btn, Color(0.60, 0.32, 0.92), 36)
    _pill(clear_btn, UITheme.C_ACCENT_CORAL, 24)

    # แถบเลื่อนบาง ๆ สีม่วง
    var vbar := scroll.get_v_scroll_bar()
    var grab := StyleBoxFlat.new()
    grab.bg_color = Color(0.45, 0.40, 0.85, 0.85)
    grab.set_corner_radius_all(4)
    grab.content_margin_left = 3
    grab.content_margin_right = 3
    var track := StyleBoxFlat.new()
    track.bg_color = Color(0.10, 0.10, 0.28, 0.6)
    track.set_corner_radius_all(4)
    track.content_margin_left = 3
    track.content_margin_right = 3
    for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
        vbar.add_theme_stylebox_override(st, grab)
    vbar.add_theme_stylebox_override("scroll", track)

func _connect_buttons() -> void:
    back_btn.pressed.connect(func():
        SoundManager.play_sfx("btn_click")
        GameManager.go_to_scene("main_menu"))
    clear_btn.pressed.connect(_confirm_clear)

const MAX_VISIBLE_RANKS: int = 8
const ROW_H := 72.0

func _populate_list() -> void:
    for child in rank_list.get_children():
        child.queue_free()
    var data: Array[Dictionary] = LeaderboardManager.get_top(MAX_VISIBLE_RANKS)
    if data.is_empty():
        var lbl := Label.new()
        lbl.text = "ยังไม่มีคะแนน — ออกไปบินกันเถอะ! 🚀"
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.add_theme_font_size_override("font_size", 34)
        lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
        rank_list.add_child(lbl)
        return
    for i in data.size():
        _add_row(i + 1, data[i])

# ทุกแถวใช้พื้นน้ำเงินเข้มเดียวกัน — อันดับ 1-3 มีขอบสี ทอง / เงิน / ทองแดง
const RANK_BORDER: Dictionary = {
    1: Color(1.00, 0.80, 0.22),   # ทอง
    2: Color(0.80, 0.84, 0.90),   # เงิน
    3: Color(0.80, 0.50, 0.25),   # ทองแดง
}

# is_new = คะแนนรอบล่าสุดที่เพิ่งเข้าตาราง (ทำให้อันดับเปลี่ยน) → พื้นสีเขียว
func _row_style(rank: int, is_new: bool = false) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.25, 0.52, 0.24, 0.97) if is_new else Color(0.09, 0.09, 0.17, 0.95)
    if RANK_BORDER.has(rank):
        var c: Color = RANK_BORDER[rank]
        sb.border_color = c
        sb.set_border_width_all(3)
        sb.shadow_color = Color(c.r, c.g, c.b, 0.40)   # เรืองแสงจาง ๆ ตามสีขอบ
        sb.shadow_size = 8
        sb.shadow_offset = Vector2.ZERO
    elif is_new:
        sb.border_color = Color(0.45, 0.75, 0.40)
        sb.set_border_width_all(2)
        sb.border_width_top = 3
        sb.shadow_color = Color(0, 0, 0, 0.45)
        sb.shadow_size = 6
        sb.shadow_offset = Vector2(0, 3)
    else:
        sb.border_color = Color(0.20, 0.20, 0.34)
        sb.set_border_width_all(2)
        sb.shadow_color = Color(0, 0, 0, 0.45)
        sb.shadow_size = 6
        sb.shadow_offset = Vector2(0, 3)
    sb.set_corner_radius_all(14)
    sb.content_margin_left = 18
    sb.content_margin_right = 24
    return sb

func _add_row(rank: int, entry: Dictionary) -> void:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _row_style(rank, LeaderboardManager.is_latest(entry)))
    panel.custom_minimum_size = Vector2(0, ROW_H)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)

    # อันดับ: 1 = มงกุฎ, 2-3 = เหรียญ, ที่เหลือ = ตัวเลข
    var rank_lbl := Label.new()
    rank_lbl.custom_minimum_size = Vector2(62, 0)
    rank_lbl.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
    rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    match rank:
        1: rank_lbl.text = "👑"
        2: rank_lbl.text = "🥈"
        3: rank_lbl.text = "🥉"
        _: rank_lbl.text = str(rank)
    rank_lbl.add_theme_font_size_override("font_size", 44 if rank <= 3 else 36)
    if rank > 3 and _bold:
        rank_lbl.add_theme_font_override("font", _bold)
    rank_lbl.add_theme_color_override("font_color", Color.WHITE)
    _outline(rank_lbl, Color(0, 0, 0, 0.45), 6)

    # ยานที่ผู้เล่นเลือกในรอบนั้น (avatar ที่บันทึกกับคะแนน)
    var av := clampi(int(entry.get("avatar", 0)), 0, _ship_tex.size() - 1)
    var ship := _icon(_ship_tex[av], Vector2(78, 50))
    ship.flip_h = SHIP_FACES_LEFT[av]

    var name_lbl := Label.new()
    name_lbl.text = entry.get("name","?")
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
    name_lbl.add_theme_font_size_override("font_size", 36)
    name_lbl.add_theme_color_override("font_color", Color.WHITE)
    _outline(name_lbl, Color(0, 0, 0, 0.45), 6)

    var planet_lbl := Label.new()
    planet_lbl.text = entry.get("planet","?")
    planet_lbl.custom_minimum_size = Vector2(170, 0)
    planet_lbl.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
    planet_lbl.add_theme_font_size_override("font_size", 26)
    planet_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
    _outline(planet_lbl, Color(0, 0, 0, 0.45), 5)

    var sc_lbl := Label.new()
    sc_lbl.text = _fmt_score(int(entry.get("score",0)))
    sc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    sc_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
    sc_lbl.custom_minimum_size  = Vector2(150, 0)
    if _bold:
        sc_lbl.add_theme_font_override("font", _bold)
    sc_lbl.add_theme_font_size_override("font_size", 38)
    sc_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25))
    _outline(sc_lbl, Color(0.30, 0.14, 0.0, 0.85), 6)

    # ดาวรางวัล (รูปดาวทอง ชิดซ้ายต่อจากคะแนน)
    var stars_box := HBoxContainer.new()
    stars_box.custom_minimum_size = Vector2(102, 0)
    stars_box.add_theme_constant_override("separation", 0)
    for i in clampi(int(entry.get("stars", 1)), 0, 3):
        stars_box.add_child(_icon(_star_tex, Vector2(34, 34)))

    row.add_child(rank_lbl)
    row.add_child(ship)
    row.add_child(name_lbl)
    row.add_child(planet_lbl)
    row.add_child(sc_lbl)
    row.add_child(stars_box)
    panel.add_child(row)
    rank_list.add_child(panel)

func _show_player_rank() -> void:
    var rank := LeaderboardManager.get_player_rank()
    player_rank_lbl.text = "อันดับของคุณ: #%d" % rank if rank > 0 else ""

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
        sb.set_corner_radius_all(26)
        sb.shadow_color = Color(c.r, c.g, c.b, 0.40)
        sb.shadow_size = 6
        sb.content_margin_left = 26
        sb.content_margin_right = 26
        sb.content_margin_top = 4
        sb.content_margin_bottom = 6
        chip.add_theme_stylebox_override("panel", sb)
        var lbl := Label.new()
        lbl.text = "%s %s" % [info["icon"], badge]
        lbl.add_theme_font_size_override("font_size", 36)
        lbl.add_theme_color_override("font_color", Color.WHITE)
        _outline(lbl, c.darkened(0.55), 6)
        chip.add_child(lbl)
        badge_row.add_child(chip)

func _confirm_clear() -> void:
    var dialog := AcceptDialog.new()
    dialog.title       = "ยืนยันลบข้อมูล"
    dialog.dialog_text = "ลบคะแนนทั้งหมด?"
    dialog.confirmed.connect(func():
        LeaderboardManager.clear_all()
        _populate_list())
    add_child(dialog)
    dialog.popup_centered()

func _fmt_score(val: int) -> String:
    var s := str(val); var out := ""; var cnt := 0
    for i in range(s.length()-1,-1,-1):
        if cnt > 0 and cnt%3==0: out=","+out
        out=s[i]+out; cnt+=1
    return out

