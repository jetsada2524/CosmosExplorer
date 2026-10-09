extends Node
# ==============================================================
#  ui_theme.gd  —  Autoload Singleton  "UITheme"
#
#  🎬 PIXAR SPACE STYLE
#  Inspired by: Lightyear, WALL·E, Toy Story — vibrant,
#  rounded, friendly with deep cosmic backgrounds.
#  สี: rich nebula purples + warm golden accents +
#       brilliant cyan glows + coral/orange warmth
# ==============================================================

# ── Deep Space Background ──────────────────────────────────────
const C_BG_DARK      := Color(0.030, 0.012, 0.090)      # #08022E ม่วงเข้มอวกาศ
const C_BG_CARD      := Color(0.080, 0.045, 0.200, 0.93) # #140B33 การ์ดม่วง
const C_BG_PANEL     := Color(0.055, 0.030, 0.160, 0.95) # panel พื้นม่วง

# ── Pixar Accent Colors ────────────────────────────────────────
const C_ACCENT_GOLD   := Color(1.000, 0.820, 0.100)      # #FFD21A ทองสด (Pixar gold)
const C_ACCENT_ORANGE := Color(1.000, 0.480, 0.100)      # #FF7A1A ส้มพิกซาร์
const C_ACCENT_CYAN   := Color(0.050, 0.900, 1.000)      # #0DE6FF ฟ้าเรือง (Lightyear)
const C_ACCENT_BLUE   := Color(0.200, 0.520, 1.000)      # #3385FF น้ำเงินสด
const C_ACCENT_GREEN  := Color(0.100, 0.950, 0.500)      # #1AF280 เขียวสด (WALL·E)
const C_ACCENT_PURPLE := Color(0.700, 0.250, 1.000)      # #B340FF ม่วงสด
const C_ACCENT_CORAL  := Color(1.000, 0.350, 0.400)      # #FF5966 ปะการัง
const C_ACCENT_PINK   := Color(1.000, 0.200, 0.700)      # #FF33B3 ชมพูสด

# ── Text Colors ────────────────────────────────────────────────
const C_TEXT_WHITE   := Color(1.000, 1.000, 1.000)
const C_TEXT_LIGHT   := Color(0.880, 0.920, 1.000)       # ขาวอมม่วง
const C_TEXT_GOLD    := Color(1.000, 0.870, 0.250)
const C_TEXT_GREY    := Color(0.600, 0.580, 0.780)       # เทาม่วง

# ── HP / Status Colors ─────────────────────────────────────────
const C_HP_GREEN     := Color(0.100, 0.950, 0.500)       # เขียวสด (Pixar)
const C_HP_ORANGE    := Color(1.000, 0.600, 0.050)
const C_HP_RED       := Color(1.000, 0.200, 0.250)       # แดงสด
const C_ENERGY_CYAN  := Color(0.050, 0.900, 1.000)       # ฟ้าพลังงาน
const C_SHIELD_BLUE  := Color(0.350, 0.650, 1.000)

# ── Border / Glow (Pixar glow is warmer & brighter) ───────────
const C_BORDER_GOLD   := Color(1.000, 0.820, 0.100, 0.90)
const C_BORDER_CYAN   := Color(0.050, 0.900, 1.000, 0.80)
const C_BORDER_BLUE   := Color(0.200, 0.520, 1.000, 0.75)
const C_BORDER_PURPLE := Color(0.700, 0.250, 1.000, 0.75)
const C_GLOW_GOLD     := Color(1.000, 0.820, 0.100, 0.35)
const C_GLOW_CYAN     := Color(0.050, 0.900, 1.000, 0.35)

# ── Radius & Sizes (larger = friendlier / more Pixar) ─────────
const BTN_RADIUS   : int = 22
const CARD_RADIUS  : int = 28
const PANEL_RADIUS : int = 32

# ── Font Sizes ─────────────────────────────────────────────────
const FONT_TITLE   : int = 56
const FONT_HEADING : int = 34
const FONT_BODY    : int = 30
const FONT_SMALL   : int = 22
const FONT_TINY    : int = 20

# ── Difficulty colors ──────────────────────────────────────────
const DIFF_COLORS: Array[Color] = [
    Color.WHITE,
    Color(0.10, 0.95, 0.50),   # easy  - Pixar green
    Color(1.00, 0.82, 0.10),   # medium - Pixar gold
    Color(1.00, 0.48, 0.10),   # hard  - Pixar orange
    Color(0.70, 0.25, 1.00),   # expert - Pixar purple
]
const DIFF_LABELS: Array[String] = ["", "ง่าย ★", "ปานกลาง ★★", "ยาก ★★★", "โหด ★★★★"]

# ══════════════════════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════════════════════

func make_button_style(
        bg: Color,
        border: Color = Color.TRANSPARENT,
        radius: int   = BTN_RADIUS,
        border_w: int = 2) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color           = bg
    s.border_color       = border
    s.set_border_width_all(border_w)
    s.set_corner_radius_all(radius)
    s.shadow_color       = Color(0.0, 0.0, 0.0, 0.45)
    s.shadow_size        = 8
    s.shadow_offset      = Vector2(0, 3)
    return s

func style_button(btn: Button,
        bg: Color         = C_ACCENT_ORANGE,
        text_color: Color = C_TEXT_WHITE,
        radius: int       = BTN_RADIUS) -> void:
    # Normal: vivid base with bright top border (Pixar gloss effect)
    var border_hi := Color(
        clampf(bg.r + 0.20, 0, 1),
        clampf(bg.g + 0.15, 0, 1),
        clampf(bg.b + 0.10, 0, 1), 1.0)
    var normal  := make_button_style(bg, border_hi, radius, 3)
    var hover   := make_button_style(bg.lightened(0.18), Color.WHITE, radius, 3)
    var pressed := make_button_style(bg.darkened(0.20), border_hi, radius, 2)
    # Inner highlight line (top) — simulates Pixar gloss
    normal.border_width_top  = 4
    hover.border_width_top   = 4
    btn.add_theme_stylebox_override("normal",  normal)
    btn.add_theme_stylebox_override("hover",   hover)
    btn.add_theme_stylebox_override("pressed", pressed)
    btn.add_theme_stylebox_override("focus",   hover)
    btn.add_theme_color_override("font_color", text_color)
    btn.add_theme_font_size_override("font_size", FONT_BODY)

# ── Fonts ──────────────────────────────────────────────────────
const FONT_ITIM     := "res://fonts/Itim/Itim-Regular.ttf"
const FONT_BALOO    := "res://fonts/Baloo_2/Baloo2-VariableFont_wght.ttf"
const FONT_SARABUN  := "res://fonts/Sarabun/Sarabun-Medium.ttf"
const FONT_SARABUN_BOLD := "res://fonts/Sarabun/Sarabun-Bold.ttf"
const FONT_EMOJI    := "res://fonts/Emoji/CosmosEmoji.ttf"
const FONT_SYMBOLS  := "res://fonts/Emoji/CosmosSymbols.ttf"

# ฟอนต์ทั้งหมดที่เกมใช้ — จะถูกเติม fallback (ไทย/สัญลักษณ์/อีโมจิ) ตอนเริ่มเกม
const ALL_GAME_FONTS: Array[String] = [
    "res://fonts/Itim/Itim-Regular.ttf",
    "res://fonts/Baloo_2/Baloo2-VariableFont_wght.ttf",
    "res://fonts/Baloo_2/static/Baloo2-ExtraBold.ttf",
    "res://fonts/Sarabun/Sarabun-Medium.ttf",
    "res://fonts/Sarabun/Sarabun-Bold.ttf",
    "res://fonts/Sarabun/Sarabun-ExtraBold.ttf",
]

func _ready() -> void:
    _setup_font_fallbacks()

# Web export ไม่มีฟอนต์ของระบบให้ยืม (ต่างจาก macOS/Windows) → ตัวอักษรที่
# ฟอนต์หลักไม่มี (ภาษาไทยใน Baloo / fallback_font, อีโมจิ, ★ ✓) จะกลายเป็นกล่อง
# จึงเติม fallback chain ให้ทุกฟอนต์ + เปลี่ยน ThemeDB.fallback_font (ที่ใช้ใน
# draw_string และ Control ที่ไม่มี theme) เป็น Itim ซึ่งรองรับภาษาไทย
func _setup_font_fallbacks() -> void:
    var extras: Array[Font] = []
    for p in [FONT_SYMBOLS, FONT_EMOJI]:
        if ResourceLoader.exists(p):
            extras.append(load(p) as Font)
    var itim := load(FONT_ITIM) as Font
    for p in ALL_GAME_FONTS:
        if not ResourceLoader.exists(p):
            continue
        var f := load(p) as Font
        var fb: Array[Font] = []
        if p.contains("Baloo"):
            fb.append(itim)          # Baloo ไม่มีอักษรไทย
        fb.append_array(extras)
        f.fallbacks = fb
    ThemeDB.fallback_font = itim

static func get_font_itim() -> Font:
    return load(FONT_ITIM) as Font

static func get_font_baloo() -> Font:
    return load(FONT_BALOO) as Font

static func get_font_sarabun() -> Font:
    return load(FONT_SARABUN) as Font

static func get_font_sarabun_bold() -> Font:
    return load(FONT_SARABUN_BOLD) as Font

## ใช้ Baloo สำหรับ heading labels
static func apply_heading_font(label: Label, size: int = 45) -> void:
    var f := load(FONT_BALOO) as Font
    if f:
        label.add_theme_font_override("font", f)
    label.add_theme_font_size_override("font_size", size)

## ใช้ Sarabun สำหรับ body/data labels
static func apply_body_font(label: Label, size: int = 28) -> void:
    var f := load(FONT_SARABUN) as Font
    if f:
        label.add_theme_font_override("font", f)
    label.add_theme_font_size_override("font_size", size)

## ใช้ Baloo สำหรับ buttons
static func apply_button_font(btn: Button, size: int = 45) -> void:
    var f := load(FONT_BALOO) as Font
    if f:
        btn.add_theme_font_override("font", f)
    btn.add_theme_font_size_override("font_size", size)

# ── Cosmos Background ──────────────────────────────────────────
const BG_COSMOS_PATH := "res://assets/ui/bg_cosmos.png"

## เรียกจาก _ready() ของทุก scene เพื่อเปลี่ยน Background node
## เป็น bg_cosmos.png อัตโนมัติ
static func apply_cosmos_bg(scene_root: Node) -> void:
    var tex := load(BG_COSMOS_PATH) as Texture2D
    if tex == null:
        push_warning("UITheme: bg_cosmos.png not found")
        return
    for bg_name in ["Background", "BG"]:
        var old_bg := scene_root.get_node_or_null(bg_name)
        if old_bg:
            old_bg.queue_free()
    var new_bg := TextureRect.new()
    new_bg.name = "CosmosBG"
    new_bg.texture = tex
    new_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    new_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    if scene_root is Control:
        new_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        new_bg.position = Vector2.ZERO
        new_bg.size = Vector2(1920, 1080)
    new_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    new_bg.z_index = -100
    scene_root.add_child(new_bg)
    scene_root.move_child(new_bg, 0)

func make_panel_style(
        bg: Color            = C_BG_CARD,
        border: Color        = C_BORDER_CYAN,
        radius: int          = CARD_RADIUS,
        border_w: int        = 2,
        content_padding: int = -1) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color     = bg
    s.border_color = border
    s.set_border_width_all(border_w)
    s.set_corner_radius_all(radius)
    s.shadow_color  = Color(0.0, 0.0, 0.0, 0.50)
    s.shadow_size   = 12
    s.shadow_offset = Vector2(0, 4)
    if content_padding >= 0:
        s.content_margin_left   = content_padding
        s.content_margin_top    = content_padding
        s.content_margin_right  = content_padding
        s.content_margin_bottom = content_padding
    return s
