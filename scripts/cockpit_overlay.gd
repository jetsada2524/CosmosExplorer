extends Control
# ==============================================================
#  cockpit_overlay.gd  —  FPS Cockpit Overlay (Pure Vector)
#  No external PNG — drawn entirely with Godot _draw() API
#  Widescreen 16:9 cockpit interior design
# ==============================================================

# ── Live values ───────────────────────────────────────────────
var _hp_fill:     float = 1.0
var _energy_fill: float = 1.0
var _shield_on:   bool  = false

# ── Dashboard Labels ──────────────────────────────────────────
var _speed_fill: float = 0.55   # updated from cockpit_3d via set_speed()

# ── Radar ring system ─────────────────────────────────────────
var _cockpit_3d: Node = null    # set by gameplay.gd after scene ready

var _layout: Dictionary = {}

# ── Boost button texture ──────────────────────────────────────
var _boost_tex: Texture2D = null

# ── Shield status textures ────────────────────────────────────
var _shield_active_tex:   Texture2D = null
var _shield_inactive_tex: Texture2D = null

# ── Gauge colors ──────────────────────────────────────────────
const C_HP_FULL  := Color(0.08, 0.93, 0.33, 1.00)
const C_HP_MID   := Color(1.00, 0.75, 0.10, 1.00)
const C_HP_LOW   := Color(0.95, 0.20, 0.15, 1.00)
const C_ENG      := Color(0.05, 0.82, 1.00, 1.00)
const C_GAUGE_BG := Color(0.03, 0.05, 0.14, 1.00)
const C_GAUGE_RM := Color(0.15, 0.28, 0.55, 1.00)
const C_RET      := Color(0.20, 0.95, 0.40, 0.82)

# ── Frame colors ──────────────────────────────────────────────
const C_BG      := Color(0.012, 0.020, 0.059, 1.00)   # very dark navy
const C_PANEL   := Color(0.019, 0.031, 0.082, 0.97)   # panel fill
const C_TRIM    := Color(0.039, 0.110, 0.275, 0.95)   # structural blue
const C_TRIM_LT := Color(0.157, 0.318, 0.667, 0.90)   # light-blue edge
const C_ACCENT  := Color(0.275, 0.588, 1.000, 0.88)   # bright accent
const C_GLOW    := Color(0.078, 0.510, 1.000, 0.30)   # glass-edge glow
const C_RIVET   := Color(0.220, 0.420, 0.780, 0.90)

# ── Layout fractions ──────────────────────────────────────────
const DASH_FRAC  := 0.723   # dashboard top Y / H
const GAUGE_Y_FR := 0.610   # gauge center Y / H
const GAUGE_X_L  := 0.185   # left gauge center X / W
const GAUGE_X_R  := 0.815   # right gauge center X / W
const GAUGE_R_FR := 0.072   # gauge radius / W

# A-pillar widths (fraction of W)
const PIL_TOP_W  := 0.155   # width at top bar
const PIL_BOT_W  := 0.072   # width at dashboard

# ─────────────────────────────────────────────────────────────
func _ready() -> void:
    mouse_filter = MOUSE_FILTER_IGNORE
    z_index = -1   # วาดอยู่หลัง console 3D ของยาน
    _layout = ShipLayout.get_layout(GameManager.player_avatar)
    _boost_tex = load("res://assets/ui/btn_boost.png")
    _shield_active_tex   = load("res://assets/ui/btn_shield_status_active.png")
    _shield_inactive_tex = load("res://assets/ui/btn_shield_status_non_active.png")
    GameManager.hp_changed.connect(_on_hp_changed)
    GameManager.energy_changed.connect(_on_energy_changed)
    _build_dashboard_labels()
    _sync_size()
    get_viewport().size_changed.connect(_sync_size)
    resized.connect(queue_redraw)

func _process(_delta: float) -> void:
    # Continuously redraw so radar rings animate smoothly each frame
    queue_redraw()

func _sync_size() -> void:
    var vp := get_viewport().get_visible_rect().size
    position = Vector2.ZERO
    size     = vp
    _reposition_labels()
    queue_redraw()

func _on_hp_changed(val: float) -> void:
    _hp_fill = clampf(val / 100.0, 0.0, 1.0)
    queue_redraw()

func _on_energy_changed(val: float) -> void:
    _energy_fill = clampf(val / 100.0, 0.0, 1.0)
    queue_redraw()

# ── Dashboard label builders ──────────────────────────────────
func _build_dashboard_labels() -> void:
    pass   # no overlay labels — buttons fill left/right panels

func _reposition_labels() -> void:
    pass   # nothing to reposition

func set_shield_active(active: bool) -> void:
    _shield_on = active
    queue_redraw()

func set_speed(normalised: float) -> void:
    _speed_fill = clampf(normalised, 0.0, 1.0)
    queue_redraw()

func set_cockpit_ref(node: Node) -> void:
    _cockpit_3d = node
    # เปลี่ยนรูป shield เมื่อได้รับ/เสีย shield
    if _cockpit_3d and _cockpit_3d.has_signal("shield_changed"):
        _cockpit_3d.shield_changed.connect(set_shield_active)

# ═══════════════════════════════════════════════════════════════
#  MAIN DRAW
# ═══════════════════════════════════════════════════════════════
func _draw() -> void:
    var W := size.x;  var H := size.y
    if W < 10.0 or H < 10.0: return

    var is_fps: bool = true   # ใช้มุมมอง FPS อย่างเดียว (ลบโหมด TPS แล้ว)

    if is_fps and not _layout.is_empty():
        var hp_c  := Vector2(W * float(_layout.hp_center.x),  H * float(_layout.hp_center.y))
        var eng_c := Vector2(W * float(_layout.eng_center.x), H * float(_layout.eng_center.y))
        var gr: float = float(_layout.gauge_r) * W
        _draw_gauge(hp_c,  gr, "HP",  _hp_fill,     _hp_color())
        _draw_gauge(eng_c, gr, "ENG", _energy_fill, C_ENG)
    else:
        if not is_fps:
            _draw_tps_center(W, H)
        var gy := H * GAUGE_Y_FR
        var gr := W * GAUGE_R_FR
        _draw_gauge(Vector2(W * GAUGE_X_L, gy), gr, "HP",  _hp_fill,     _hp_color())
        _draw_gauge(Vector2(W * GAUGE_X_R, gy), gr, "ENG", _energy_fill, C_ENG)

    # ── BOOST + STATUS panels (drawn from layout) ─────────────
    if not _layout.is_empty():
        _draw_boost_panel(W, H, _layout)
        _draw_status_panel(W, H, _layout)

    _draw_radar_rings(W, H)

    # ── Debug borders for layout zones ─────────────────────────
    ShipLayout.draw_debug(self, W, H, _layout)

# ═══════════════════════════════════════════════════════════════
#  TPS CENTER HUD  —  SPD + Shield circles (no frame/panel fill)
# ═══════════════════════════════════════════════════════════════
func _draw_tps_center(W: float, H: float) -> void:
    # Mirror the same circle positions as FPS center panel so BOOST button aligns
    var dash_y := H * DASH_FRAC
    var px     := W * 0.33
    var pw     := W * 0.34
    var area_h := H * 0.880 - dash_y
    var mr     := minf(area_h * 0.46, pw * 0.24)
    mr          = maxf(mr, 24.0)
    var mc_y   := dash_y + area_h * 0.52
    var mc_l   := Vector2(px + pw * 0.27, mc_y)
    var mc_r   := Vector2(px + pw * 0.73, mc_y)

    var spd_val := int(18.0 + _speed_fill * 14.0)
    _draw_spd_circle(mc_l, mr, _speed_fill, Color(0.12, 0.62, 1.00, 0.92), spd_val)

    var shc := Color(0.35, 0.72, 1.00, 0.95) if _shield_on else Color(0.40, 0.42, 0.60, 0.80)
    _draw_shield_circle(mc_r, mr, shc)

# ═══════════════════════════════════════════════════════════════
#  COCKPIT FRAME
# ═══════════════════════════════════════════════════════════════
func _draw_cockpit_frame(W: float, H: float) -> void:
    var dash_y := H * DASH_FRAC
    var top_h  := H * 0.052
    var ptw    := W * PIL_TOP_W   # pillar width at top
    var pbw    := W * PIL_BOT_W   # pillar width at dashboard

    # ── TOP BAR ──────────────────────────────────────────────────
    draw_polygon(
        PackedVector2Array([Vector2(0,0), Vector2(W,0), Vector2(W,top_h), Vector2(0,top_h)]),
        PackedColorArray([C_BG, C_BG, C_TRIM.darkened(0.10), C_TRIM.darkened(0.10)]))
    # Accent edge
    draw_line(Vector2(0, top_h), Vector2(W, top_h), C_TRIM_LT, 2.5)
    draw_line(Vector2(0, top_h * 0.45), Vector2(W, top_h * 0.45),
        Color(C_TRIM.r, C_TRIM.g, C_TRIM.b, 0.45), 1.0)
    # Rivets
    for i: int in 10:
        var rx := W * 0.05 + i * (W * 0.90 / 9.0)
        draw_circle(Vector2(rx, top_h * 0.50), 3.2, C_RIVET)
        draw_arc(Vector2(rx, top_h * 0.50), 3.2, 0.0, TAU, 8, C_TRIM_LT.darkened(0.35), 0.8)

    # ── LEFT A-PILLAR ─────────────────────────────────────────────
    var lp := PackedVector2Array([
        Vector2(0.0,  top_h),
        Vector2(ptw,  top_h),
        Vector2(pbw,  dash_y),
        Vector2(0.0,  dash_y)])
    draw_polygon(lp, PackedColorArray([C_BG, C_TRIM, C_TRIM.darkened(0.25), C_BG]))
    # Inner glass edge
    draw_line(Vector2(ptw, top_h),  Vector2(pbw, dash_y), C_GLOW,    3.5)
    draw_line(Vector2(ptw, top_h),  Vector2(pbw, dash_y), C_TRIM_LT, 1.8)
    # Secondary structural line
    draw_line(Vector2(ptw * 0.58, top_h), Vector2(pbw * 0.58, dash_y),
        Color(C_TRIM.r, C_TRIM.g, C_TRIM.b, 0.40), 1.0)

    # ── RIGHT A-PILLAR ────────────────────────────────────────────
    var rp := PackedVector2Array([
        Vector2(W - ptw, top_h),
        Vector2(W,       top_h),
        Vector2(W,       dash_y),
        Vector2(W - pbw, dash_y)])
    draw_polygon(rp, PackedColorArray([C_TRIM, C_BG, C_BG, C_TRIM.darkened(0.25)]))
    draw_line(Vector2(W - ptw, top_h), Vector2(W - pbw, dash_y), C_GLOW,    3.5)
    draw_line(Vector2(W - ptw, top_h), Vector2(W - pbw, dash_y), C_TRIM_LT, 1.8)
    draw_line(Vector2(W - ptw * 0.58, top_h), Vector2(W - pbw * 0.58, dash_y),
        Color(C_TRIM.r, C_TRIM.g, C_TRIM.b, 0.40), 1.0)

    # ── WINDSHIELD CORNER GLOW (glass refraction) ─────────────────
    for i: int in 4:
        var a  := 0.10 - i * 0.022
        var gc := Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, a)
        var o  := float(i) * 5.0
        draw_line(Vector2(pbw - o, dash_y - o * 2.5),
                  Vector2(pbw - o + 35.0, dash_y + 1.0), gc, 1.8 - i * 0.3)
        draw_line(Vector2(W - pbw + o, dash_y - o * 2.5),
                  Vector2(W - pbw + o - 35.0, dash_y + 1.0), gc, 1.8 - i * 0.3)

    # ── DASHBOARD BASE ────────────────────────────────────────────
    draw_polygon(
        PackedVector2Array([Vector2(0,dash_y), Vector2(W,dash_y), Vector2(W,H), Vector2(0,H)]),
        PackedColorArray([C_TRIM.darkened(0.12), C_TRIM.darkened(0.12), C_BG, C_BG]))
    draw_line(Vector2(0, dash_y),     Vector2(W, dash_y),     C_ACCENT,                    3.0)
    draw_line(Vector2(0, dash_y + 5), Vector2(W, dash_y + 5),
        Color(C_TRIM.r, C_TRIM.g, C_TRIM.b, 0.55), 1.0)

    # Panel dividers
    draw_line(Vector2(W * 0.33, dash_y), Vector2(W * 0.33, H), C_TRIM_LT, 1.5)
    draw_line(Vector2(W * 0.67, dash_y), Vector2(W * 0.67, H), C_TRIM_LT, 1.5)

    # ── PANEL CONTENTS ────────────────────────────────────────────
    _draw_left_panel(W, H, dash_y)
    _draw_center_panel(W, H, dash_y)
    _draw_right_panel(W, H, dash_y)

# ─────────────────────────────────────────────────────────────
#  CORNER BRACKET helper
# ─────────────────────────────────────────────────────────────
func _draw_corners(r: Rect2, col: Color, len_frac: float = 0.15) -> void:
    var lx := r.size.x * len_frac
    var ly := r.size.y * len_frac
    var tl := r.position
    var trn := Vector2(r.end.x, r.position.y)
    var bl := Vector2(r.position.x, r.end.y)
    var br := r.end
    var w  := 2.0
    draw_line(tl,  tl  + Vector2(lx, 0),   col, w)
    draw_line(tl,  tl  + Vector2(0, ly),   col, w)
    draw_line(trn, trn + Vector2(-lx, 0),  col, w)
    draw_line(trn, trn + Vector2(0, ly),   col, w)
    draw_line(bl,  bl  + Vector2(lx, 0),   col, w)
    draw_line(bl, bl + Vector2(0, -ly), col, w)
    draw_line(br, br + Vector2(-lx, 0), col, w)
    draw_line(br, br + Vector2(0, -ly), col, w)

# ─────────────────────────────────────────────────────────────
#  LEFT PANEL  — Steer Left button area (HUD button fills this)
# ─────────────────────────────────────────────────────────────
func _draw_left_panel(W: float, H: float, dash_y: float) -> void:
    var px := 0.0
    var py := dash_y
    var pw := W * 0.33
    var ph := H - dash_y

    # Panel fill + border  (HUD SteerLeftBtn fills this area)
    var pr := Rect2(px + 5, py + 5, pw - 10, ph - 5)
    draw_colored_polygon(
        PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]),
        C_PANEL)
    draw_rect(pr, C_TRIM_LT.darkened(0.45), false, 1.2)
    _draw_corners(pr, C_ACCENT, 0.12)

# ─────────────────────────────────────────────────────────────
#  CENTER PANEL  — Large SPD/Shield circles + small BOOST button
# ─────────────────────────────────────────────────────────────
func _draw_center_panel(W: float, H: float, dash_y: float) -> void:
    var px   := W * 0.33
    var py   := dash_y
    var pw   := W * 0.34
    var ph   := H - dash_y

    # Panel fill
    var pr := Rect2(px + 5, py + 5, pw - 10, ph - 5)
    draw_colored_polygon(
        PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]),
        C_PANEL)
    draw_rect(pr, C_TRIM_LT.darkened(0.45), false, 1.2)
    _draw_corners(pr, C_ACCENT, 0.10)

    # ── TWO LARGE CIRCLES (SPD left, Shield right) ─────────────────
    # BOOST button occupies bottom ~9.5% of viewport (0.880–0.975*H)
    # So circles fill dash_y → 0.880*H
    var boost_top_y := H * 0.880
    var area_h      := boost_top_y - dash_y
    var mr          := minf(area_h * 0.46, pw * 0.24)
    mr              = maxf(mr, 24.0)
    var mc_y        := dash_y + area_h * 0.52
    var mc_l        := Vector2(px + pw * 0.27, mc_y)
    var mc_r        := Vector2(px + pw * 0.73, mc_y)

    # Left: SPEED circle
    var spd_val := int(18.0 + _speed_fill * 14.0)
    _draw_spd_circle(mc_l, mr, _speed_fill, Color(0.12, 0.62, 1.00, 0.92), spd_val)

    # Right: SHIELD circle
    var shc := Color(0.35, 0.72, 1.00, 0.95) if _shield_on else Color(0.40, 0.42, 0.60, 0.80)
    _draw_shield_circle(mc_r, mr, shc)

    # Thin divider
    var div_x := px + pw * 0.5
    draw_line(Vector2(div_x, dash_y + area_h * 0.12),
              Vector2(div_x, dash_y + area_h * 0.88),
              Color(C_TRIM_LT.r, C_TRIM_LT.g, C_TRIM_LT.b, 0.18), 1.0)

# ─────────────────────────────────────────────────────────────
#  RIGHT PANEL  — Steer Right button area (HUD button fills this)
# ─────────────────────────────────────────────────────────────
func _draw_right_panel(W: float, H: float, dash_y: float) -> void:
    var px := W * 0.67
    var py := dash_y
    var pw := W * 0.33
    var ph := H - dash_y

    # Panel fill + border  (HUD SteerRightBtn fills this area)
    var pr := Rect2(px + 5, py + 5, pw - 10, ph - 5)
    draw_colored_polygon(
        PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]),
        C_PANEL)
    draw_rect(pr, C_TRIM_LT.darkened(0.45), false, 1.2)
    _draw_corners(pr, C_ACCENT, 0.12)

# ═══════════════════════════════════════════════════════════════
#  SPEED CIRCLE  —  large circle: speed number (top) + "km/s" (bottom)
# ═══════════════════════════════════════════════════════════════
func _draw_spd_circle(c: Vector2, r: float, fill: float, col: Color, spd_val: int) -> void:
    # Background fill + rim
    draw_circle(c, r, Color(0.03, 0.05, 0.14, 0.92))
    draw_arc(c, r * 0.97, 0.0, TAU, 48, C_GAUGE_RM, 1.5)
    # Arc track
    const SA := -PI * 0.72
    const EA :=  PI * 0.72
    draw_arc(c, r * 0.80, SA, EA, 48, Color(0.05, 0.09, 0.22, 0.72), 5.5)
    if fill > 0.01:
        var fe := SA + fill * (EA - SA)
        draw_arc(c, r * 0.80, SA, fe, 48, col, 5.5)
    # Speed number (top, large)
    var font := ThemeDB.fallback_font
    var hw   := r * 0.90
    draw_string(font, c + Vector2(-hw, r * 0.12), str(spd_val),
        HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, int(r * 0.40), col)
    # Unit label (bottom, small)
    draw_string(font, c + Vector2(-hw, r * 0.52), "km/s",
        HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, int(r * 0.24),
        Color(col.r, col.g, col.b, 0.65))
    # "SPD" tiny label at top arc
    draw_string(font, c + Vector2(-hw, -r * 0.62), "SPD",
        HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, int(r * 0.20),
        Color(col.r, col.g, col.b, 0.50))

# ═══════════════════════════════════════════════════════════════
#  SHIELD CIRCLE  —  large circle: shield icon (top) + status (bottom)
# ═══════════════════════════════════════════════════════════════
func _draw_shield_circle(c: Vector2, r: float, col: Color) -> void:
    # Background fill + rim
    draw_circle(c, r, Color(0.03, 0.05, 0.14, 0.92))
    draw_arc(c, r * 0.97, 0.0, TAU, 48, C_GAUGE_RM, 1.5)
    # Shield icon (top half)
    var font := ThemeDB.fallback_font
    var hw   := r * 0.90
    draw_string(font, c + Vector2(-hw, -r * 0.08), "🛡",
        HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, int(r * 0.48), col)
    # Status text (bottom)
    var status_txt := "พร้อม" if _shield_on else "ไม่มี"
    var status_col := Color(0.20, 1.00, 0.55, 0.95) if _shield_on else Color(0.65, 0.65, 0.75, 0.80)
    draw_string(font, c + Vector2(-hw, r * 0.52), status_txt,
        HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, int(r * 0.26), status_col)
    # "SLD" tiny label at top
    draw_string(font, c + Vector2(-hw, -r * 0.62), "SLD",
        HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, int(r * 0.20),
        Color(col.r, col.g, col.b, 0.50))
    # Pulse glow ring when shield active
    if _shield_on:
        var tf := Time.get_ticks_msec() * 0.004
        var fl := 0.28 + 0.28 * sin(tf)
        draw_arc(c, r * 1.08, 0.0, TAU, 48, Color(col.r, col.g, col.b, fl), 2.5)

# ═══════════════════════════════════════════════════════════════
#  CIRCULAR ARC GAUGE
# ═══════════════════════════════════════════════════════════════
func _draw_gauge(c: Vector2, r: float, label: String, fill: float, col: Color) -> void:
    draw_circle(c, r * 1.10, C_GAUGE_BG)
    draw_arc(c, r * 1.08, 0.0, TAU, 64, C_GAUGE_RM, 2.5)

    const SA := -PI * 0.75
    const EA :=  PI * 0.75
    draw_arc(c, r * 0.80, SA, EA, 64, Color(0.05, 0.09, 0.22, 0.72), 8.0)
    if fill > 0.01:
        var fe := SA + fill * (EA - SA)
        draw_arc(c, r * 0.80, SA, fe, 64, col, 8.0)

    for i: int in 9:
        var a  := SA + i * (EA - SA) / 8.0
        var r1 := r * 0.66
        var r2 := r * (0.54 if i % 4 == 0 else 0.59)
        draw_line(c + Vector2(cos(a), sin(a)) * r1,
                  c + Vector2(cos(a), sin(a)) * r2,
                  Color(0.40, 0.58, 0.80, 0.55), 1.5)

    draw_circle(c, r * 0.46, Color(0.02, 0.04, 0.12, 0.94))
    draw_arc(c, r * 0.46, 0.0, TAU, 32, col.darkened(0.25), 1.5)

    var font    := ThemeDB.fallback_font
    var pct_str := "%d%%" % int(fill * 100.0)
    var hw      := r * 0.55
    draw_string(font, c + Vector2(-hw,  r * 0.12), pct_str,
        HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, int(r * 0.32), col)
    draw_string(font, c + Vector2(-hw, -r * 0.14), label,
        HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, int(r * 0.20),
        Color(col.r, col.g, col.b, 0.72))

    var bw := r * 0.72
    var by := c.y + r * 0.30
    draw_rect(Rect2(c.x - bw * 0.5, by, bw, 5.5), Color(0.06, 0.10, 0.24, 0.80))
    if fill > 0.0:
        draw_rect(Rect2(c.x - bw * 0.5, by, bw * fill, 5.5), col)

    if fill < 0.25:
        var t     := Time.get_ticks_msec() * 0.007
        var flash := (0.5 + 0.5 * sin(t)) * 0.24
        draw_circle(c, r * 1.10, Color(col.r, col.g, col.b, flash))

func _hp_color() -> Color:
    if _hp_fill <= 0.25: return C_HP_LOW
    elif _hp_fill <= 0.50: return C_HP_MID
    return C_HP_FULL

# ═══════════════════════════════════════════════════════════════
#  RADAR RINGS  —  แสดงตำแหน่งอุกาบาต/ไอเทมบน 2D overlay

# รัศมีวงแจ้งเตือน (px) — คงที่ทุกระยะ
const RADAR_RING_R := 28.0

# ═══════════════════════════════════════════════════════════════
func _draw_radar_rings(W: float, H: float) -> void:
    if not _cockpit_3d or not is_instance_valid(_cockpit_3d):
        return
    var cam: Camera3D = _cockpit_3d.camera
    if not cam or not cam.is_inside_tree():
        return

    var font := ThemeDB.fallback_font
    var tt   := Time.get_ticks_msec() * 0.008
    var cam_pos: Vector3 = cam.global_position
    var cam_fwd: Vector3 = -cam.global_transform.basis.z

    for m: Node3D in _cockpit_3d._active_meteors:
        if not is_instance_valid(m):
            continue
        if m.get_meta("hit", false):
            continue

        var wpos: Vector3 = m.global_position
        # Skip if behind camera
        if cam_fwd.dot(wpos - cam_pos) <= 0.1:
            continue

        var sp: Vector2 = cam.unproject_position(wpos)
        # Skip if off-screen
        if sp.x < -60 or sp.x > W + 60 or sp.y < -60 or sp.y > H + 60:
            continue

        var mtype: String  = m.get_meta("type", "threat")
        var mzone: String  = m.get_meta("zone", "middle")
        var sc_f: float    = m.scale.x
        var dx: float      = wpos.x - cam_pos.x

        # รัศมีคงที่ — ไม่ขยายตามระยะ, วาดแบบ 2D บนจอจึงหันหน้าเข้าหาผู้เล่นเสมอ
        var ring_r := RADAR_RING_R

        # Decorative zones (top/bottom): skip entirely — no radar ring
        if mzone != "middle":
            continue

        if mtype == "threat":
            # ── แดง = อยู่ในวิถีชน (ถ้ายานอยู่ตำแหน่ง X นี้ต่อไปจะชน)
            # ── เขียว = พ้นรัศมีชนแล้ว (หลบไปแล้ว)
            # ยานเลื่อนแค่แกน X → เช็กว่าความกว้างของอุกกาบาต/แท่ง ครอบตำแหน่งยานไหม
            var half_w: float = float(m.get_meta("half_w", 0.0))
            var reach: float
            if half_w > 0.0:
                reach = half_w + _cockpit_3d.SHIP_HALF_W          # bar
            else:
                reach = _cockpit_3d.HIT_RADIUS_BASE * sc_f        # อุกกาบาตเดี่ยว
            var ahead: bool     = wpos.z < cam_pos.z               # ยังไม่ผ่านยาน
            var in_danger: bool = ahead and absf(dx) < reach
            var col: Color = Color(0.95, 0.15, 0.10, 0.90) if in_danger else Color(0.10, 0.92, 0.38, 0.65)

            draw_arc(sp, ring_r, 0.0, TAU, 40, col, 2.2, true)
            # Danger: outer ring กะพริบ (ขนาดคงที่ เปลี่ยนแค่ความสว่าง)
            if in_danger:
                var fl := 0.35 + 0.35 * sin(tt * 2.5)
                draw_arc(sp, ring_r * 1.40, 0.0, TAU, 40,
                    Color(col.r, col.g, col.b, fl), 1.2, true)
        else:
            # Powerup: วงแหวนสีทองกะพริบ + label (แยกจากอุกกาบาต)
            var fl    := 0.55 + 0.45 * sin(tt * 1.8)
            var pcol  := Color(1.00, 0.82, 0.20, 0.60 + fl * 0.40)
            draw_arc(sp, ring_r, 0.0, TAU, 32, pcol, 3.0)
            draw_arc(sp, ring_r * 1.30, 0.0, TAU, 24,
                Color(1.00, 0.82, 0.20, fl * 0.45), 1.6)
            # Item label
            var lbl := _item_label(mtype)
            var hw  := 55.0
            draw_string(font, sp + Vector2(-hw, ring_r + 5.0), lbl,
                HORIZONTAL_ALIGNMENT_CENTER, hw * 2.0, 11, pcol)

# ═══════════════════════════════════════════════════════════════
#  BOOST PANEL  —  ใช้ texture btn_boost.png + ข้อความ BOOST
#  Position from ship_layout "boost" Rect2
# ═══════════════════════════════════════════════════════════════
func _draw_boost_panel(W: float, H: float, layout: Dictionary) -> void:
    var br: Rect2 = layout.boost
    var r := Rect2(W * br.position.x, H * br.position.y, W * br.size.x, H * br.size.y)
    var font := ThemeDB.fallback_font
    var is_active: bool = TouchInput.is_boosting

    # ── Draw texture ──────────────────────────────────────────────
    if _boost_tex:
        # ปกติ = สีเดิม, กด = เปลี่ยนเป็นเขียว
        var mod_col := Color.WHITE
        draw_texture_rect(_boost_tex, r, false, mod_col)
    else:
        # Fallback ถ้าโหลด texture ไม่ได้
        var rad := minf(r.size.x, r.size.y) * 0.28
        _draw_rounded_rect(r, rad, Color(0.04, 0.08, 0.18, 0.92))

    # ── "BOOST" text (ด้านขวาของ icon จรวด) ──────────────────────
    var txt_sz := int(minf(r.size.y * 0.42, r.size.x * 0.13))
    # ข้อความอยู่ครึ่งขวาของปุ่ม (icon จรวดอยู่ซ้าย ~45%)
    var txt_x  := r.position.x + r.size.x * 0.38
    var txt_y  := r.position.y + (r.size.y + txt_sz * 0.45) * 0.5
    var txt_w  := r.size.x * 0.50
    var txt_col := Color(0.30, 1.0, 0.45, 1.0) if is_active else Color(1.0, 1.0, 1.0, 0.95)
    # Drop shadow
    draw_string(font, Vector2(txt_x + 2, txt_y + 2), "BOOST",
        HORIZONTAL_ALIGNMENT_CENTER, txt_w, txt_sz, Color(0, 0, 0, 0.50))
    # Main text
    draw_string(font, Vector2(txt_x, txt_y), "BOOST",
        HORIZONTAL_ALIGNMENT_CENTER, txt_w, txt_sz, txt_col)



# ═══════════════════════════════════════════════════════════════
#  STATUS PANEL  —  สถานะเกราะ / โล่เปิด–ปิด
#  Position from ship_layout "status" Rect2
# ═══════════════════════════════════════════════════════════════
func _draw_status_panel(W: float, H: float, layout: Dictionary) -> void:
    var sr: Rect2 = layout.status
    var r := Rect2(W * sr.position.x, H * sr.position.y, W * sr.size.x, H * sr.size.y)

    # ── เลือก texture ตามสถานะ shield ─────────────────────────────
    var tex: Texture2D = _shield_active_tex if _shield_on else _shield_inactive_tex

    if tex:
        draw_texture_rect(tex, r, false, Color.WHITE)
    else:
        # Fallback: วาด vector ถ้าโหลด texture ไม่ได้
        var rad := minf(r.size.x, r.size.y) * 0.18
        var accent := Color(0.10, 0.85, 0.40, 0.95) if _shield_on else Color(0.50, 0.52, 0.58, 0.65)
        _draw_rounded_rect(r, rad, Color(0.52, 0.56, 0.60, 0.95))
        _draw_rounded_rect_outline(r, rad, accent.darkened(0.10), 2.0)

# ═══════════════════════════════════════════════════════════════
#  Shield Icon helper — vector-drawn shield shape
# ═══════════════════════════════════════════════════════════════
func _draw_shield_icon(center: Vector2, half: float, col: Color) -> void:
    # วาดรูปร่างโล่แบบ polygon (shield shape)
    var pts: PackedVector2Array = PackedVector2Array()
    var cx := center.x
    var cy := center.y
    # Top center
    pts.append(Vector2(cx, cy - half * 1.0))
    # Top-right curve
    pts.append(Vector2(cx + half * 0.55, cy - half * 0.85))
    pts.append(Vector2(cx + half * 0.85, cy - half * 0.55))
    # Right shoulder
    pts.append(Vector2(cx + half * 0.95, cy - half * 0.20))
    # Right side
    pts.append(Vector2(cx + half * 0.85, cy + half * 0.15))
    # Bottom-right taper
    pts.append(Vector2(cx + half * 0.55, cy + half * 0.55))
    # Bottom point
    pts.append(Vector2(cx, cy + half * 1.05))
    # Bottom-left taper
    pts.append(Vector2(cx - half * 0.55, cy + half * 0.55))
    # Left side
    pts.append(Vector2(cx - half * 0.85, cy + half * 0.15))
    # Left shoulder
    pts.append(Vector2(cx - half * 0.95, cy - half * 0.20))
    pts.append(Vector2(cx - half * 0.85, cy - half * 0.55))
    pts.append(Vector2(cx - half * 0.55, cy - half * 0.85))

    # Filled shield
    draw_colored_polygon(pts, col)
    # Outline
    var outline_col := Color(col.r, col.g, col.b, minf(col.a + 0.20, 1.0))
    for i in pts.size():
        var next_i := (i + 1) % pts.size()
        draw_line(pts[i], pts[next_i], outline_col, 1.5, true)

    # Inner highlight line (เส้นแบ่งครึ่งบนโล่)
    var inner_col := Color(col.r + 0.15, col.g + 0.15, col.b + 0.15, col.a * 0.45)
    draw_line(Vector2(cx, cy - half * 0.65), Vector2(cx, cy + half * 0.70),
        inner_col, 1.0, true)

# ═══════════════════════════════════════════════════════════════
#  Rounded Rect helpers (approximated with polygons)
# ═══════════════════════════════════════════════════════════════
func _draw_rounded_rect(rect: Rect2, radius: float, col: Color) -> void:
    # Fill using 3 rects + 4 corner circles
    var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
    # Center rect (full width, reduced height)
    draw_rect(Rect2(rect.position.x, rect.position.y + r,
                    rect.size.x, rect.size.y - r * 2.0), col)
    # Top rect (reduced width)
    draw_rect(Rect2(rect.position.x + r, rect.position.y,
                    rect.size.x - r * 2.0, r), col)
    # Bottom rect (reduced width)
    draw_rect(Rect2(rect.position.x + r, rect.end.y - r,
                    rect.size.x - r * 2.0, r), col)
    # 4 corner circles
    draw_circle(Vector2(rect.position.x + r, rect.position.y + r), r, col)  # TL
    draw_circle(Vector2(rect.end.x - r,      rect.position.y + r), r, col)  # TR
    draw_circle(Vector2(rect.position.x + r, rect.end.y - r),      r, col)  # BL
    draw_circle(Vector2(rect.end.x - r,      rect.end.y - r),      r, col)  # BR

func _draw_rounded_rect_top(rect: Rect2, radius: float, col: Color) -> void:
    # Fill only the top portion with rounded top corners
    var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
    draw_rect(Rect2(rect.position.x, rect.position.y + r,
                    rect.size.x, rect.size.y - r), col)
    draw_rect(Rect2(rect.position.x + r, rect.position.y,
                    rect.size.x - r * 2.0, r), col)
    draw_circle(Vector2(rect.position.x + r, rect.position.y + r), r, col)
    draw_circle(Vector2(rect.end.x - r,      rect.position.y + r), r, col)

func _draw_rounded_rect_outline(rect: Rect2, radius: float, col: Color, width: float = 2.0) -> void:
    var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
    # Top edge
    draw_line(Vector2(rect.position.x + r, rect.position.y),
              Vector2(rect.end.x - r,      rect.position.y), col, width)
    # Bottom edge
    draw_line(Vector2(rect.position.x + r, rect.end.y),
              Vector2(rect.end.x - r,      rect.end.y), col, width)
    # Left edge
    draw_line(Vector2(rect.position.x, rect.position.y + r),
              Vector2(rect.position.x, rect.end.y - r), col, width)
    # Right edge
    draw_line(Vector2(rect.end.x, rect.position.y + r),
              Vector2(rect.end.x, rect.end.y - r), col, width)
    # Corner arcs
    var segs := 12
    draw_arc(Vector2(rect.position.x + r, rect.position.y + r), r, PI,     PI * 1.5, segs, col, width)  # TL
    draw_arc(Vector2(rect.end.x - r,      rect.position.y + r), r, -PI*0.5, 0.0,     segs, col, width)  # TR
    draw_arc(Vector2(rect.position.x + r, rect.end.y - r),      r, PI*0.5,  PI,      segs, col, width)  # BL
    draw_arc(Vector2(rect.end.x - r,      rect.end.y - r),      r, 0.0,     PI*0.5,  segs, col, width)  # BR

func _item_label(t: String) -> String:
    match t:
        "quiz":   return "❓ คำถาม"
        "shield": return "🛡 โล่ป้องกัน"
        "energy": return "⚡ พลังงาน"
        "score":  return "🪙 เหรียญ"
    return ""
