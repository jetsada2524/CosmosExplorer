extends RefCounted
class_name ShipLayout
# ==============================================================
#  ship_layout.gd — ตำแหน่ง UI ของแต่ละยาน (fraction ของ 1920×1080)
#  ทุกค่าเป็น fraction 0.0–1.0 ของ viewport
#
#  steer_l / steer_r  → Vector2 center + steer_r_radius (fraction of W)
#  boost / status     → Rect2 (fraction)
# ==============================================================

## Toggle this to show/hide debug borders on gameplay
const DEBUG_BORDERS: bool = false

## Debug border colors
const DBG_STEER_L := Color(0.0, 1.0, 0.0, 0.85)   # green
const DBG_STEER_R := Color(0.0, 0.7, 1.0, 0.85)   # cyan
const DBG_BOOST   := Color(1.0, 0.6, 0.0, 0.85)   # orange
const DBG_STATUS  := Color(1.0, 0.2, 0.8, 0.85)   # magenta
const DBG_HP      := Color(0.1, 0.9, 0.3, 0.60)   # green (gauge)
const DBG_ENG     := Color(0.1, 0.7, 1.0, 0.60)   # blue (gauge)

const LAYOUTS: Dictionary = {
    # ── Ship 1: Explorer (teal/cream) ────────────────────────
    0: {
        "name":          "Explorer",
        "hp_center":     Vector2(0.318, 0.629),
        "eng_center":    Vector2(0.727, 0.629),
        "gauge_r":       0.053,
        "steer_l":       Vector2(0.335, 0.855),
        "steer_r":       Vector2(0.703, 0.855),
        "steer_radius":  0.040,
        "status":        Rect2(0.430, 0.571, 0.182, 0.189),
        "boost":         Rect2(0.428, 0.798, 0.183, 0.150),
        "dash_top":      0.36,
        "spawn_x_min":   0.42,
        "spawn_x_max":   0.58,
    },
    # ── Ship 2: Comet (orange) ───────────────────────────────
    1: {
        "name":          "Comet",
        "hp_center":     Vector2(0.344, 0.670),
        "eng_center":    Vector2(0.676, 0.670),
        "gauge_r":       0.047,
        "steer_l":       Vector2(0.149, 0.849),
        "steer_r":       Vector2(0.867, 0.849),
        "steer_radius":  0.047,
        "status":        Rect2(0.444, 0.629, 0.132, 0.104),
        "boost":         Rect2(0.439, 0.771, 0.144, 0.115),
        "dash_top":      0.32,
        "spawn_x_min":   0.42,
        "spawn_x_max":   0.58,
    },
    # ── Ship 3: Starwing (purple) ────────────────────────────
    2: {
        "name":          "Starwing",
        "hp_center":     Vector2(0.164, 0.635),
        "eng_center":    Vector2(0.878, 0.634),
        "gauge_r":       0.072,
        "steer_l":       Vector2(0.307, 0.807),
        "steer_r":       Vector2(0.739, 0.807),
        "steer_radius":  0.055,
        "status":        Rect2(0.421, 0.658, 0.207, 0.144),
        "boost":         Rect2(0.419, 0.816, 0.209, 0.134),
        "dash_top":      0.40,
        "spawn_x_min":   0.38,
        "spawn_x_max":   0.62,
    },
}

static func get_layout(avatar_idx: int) -> Dictionary:
    return LAYOUTS.get(clampi(avatar_idx, 0, 2), LAYOUTS[0])

# ==============================================================
#  Debug draw helpers — call from any Control._draw()
#  Pass viewport size (W, H) and the layout dict
# ==============================================================

## Draw all debug borders for the given layout
static func draw_debug(canvas: Control, W: float, H: float, layout: Dictionary) -> void:
    if not DEBUG_BORDERS:
        return
    if layout.is_empty():
        return

    var font := ThemeDB.fallback_font

    # ── Steer L (circle) ──────────────────────────────────────
    var sl_c := Vector2(W * float(layout.steer_l.x), H * float(layout.steer_l.y))
    var sl_r := W * float(layout.steer_radius)
    canvas.draw_arc(sl_c, sl_r, 0.0, TAU, 48, DBG_STEER_L, 2.5)
    canvas.draw_arc(sl_c, 4.0, 0.0, TAU, 12, DBG_STEER_L, 2.0)
    canvas.draw_string(font, sl_c + Vector2(-30, -sl_r - 8), "STEER_L",
        HORIZONTAL_ALIGNMENT_CENTER, 60, 11, DBG_STEER_L)

    # ── Steer R (circle) ──────────────────────────────────────
    var sr_c := Vector2(W * float(layout.steer_r.x), H * float(layout.steer_r.y))
    var sr_r := W * float(layout.steer_radius)
    canvas.draw_arc(sr_c, sr_r, 0.0, TAU, 48, DBG_STEER_R, 2.5)
    canvas.draw_arc(sr_c, 4.0, 0.0, TAU, 12, DBG_STEER_R, 2.0)
    canvas.draw_string(font, sr_c + Vector2(-30, -sr_r - 8), "STEER_R",
        HORIZONTAL_ALIGNMENT_CENTER, 60, 11, DBG_STEER_R)

    # ── Boost (rect) ──────────────────────────────────────────
    var boost_r := layout.boost as Rect2
    var b_rect := Rect2(W * boost_r.position.x, H * boost_r.position.y,
                        W * boost_r.size.x, H * boost_r.size.y)
    canvas.draw_rect(b_rect, DBG_BOOST, false, 2.5)
    # cross lines
    canvas.draw_line(b_rect.position, b_rect.end, Color(DBG_BOOST, 0.35), 1.0)
    canvas.draw_line(Vector2(b_rect.end.x, b_rect.position.y),
                     Vector2(b_rect.position.x, b_rect.end.y), Color(DBG_BOOST, 0.35), 1.0)
    canvas.draw_string(font, b_rect.position + Vector2(4, -6), "BOOST",
        HORIZONTAL_ALIGNMENT_LEFT, 80, 11, DBG_BOOST)

    # ── Status (rect) ─────────────────────────────────────────
    var status_r := layout.status as Rect2
    var s_rect := Rect2(W * status_r.position.x, H * status_r.position.y,
                        W * status_r.size.x, H * status_r.size.y)
    canvas.draw_rect(s_rect, DBG_STATUS, false, 2.5)
    canvas.draw_line(s_rect.position, s_rect.end, Color(DBG_STATUS, 0.35), 1.0)
    canvas.draw_line(Vector2(s_rect.end.x, s_rect.position.y),
                     Vector2(s_rect.position.x, s_rect.end.y), Color(DBG_STATUS, 0.35), 1.0)
    canvas.draw_string(font, s_rect.position + Vector2(4, -6), "STATUS",
        HORIZONTAL_ALIGNMENT_LEFT, 80, 11, DBG_STATUS)

    # ── HP gauge center ───────────────────────────────────────
    var hp_c := Vector2(W * float(layout.hp_center.x), H * float(layout.hp_center.y))
    var hp_r := W * float(layout.gauge_r)
    canvas.draw_arc(hp_c, hp_r + 6.0, 0.0, TAU, 32, DBG_HP, 1.5)
    canvas.draw_string(font, hp_c + Vector2(-20, -hp_r - 14), "HP",
        HORIZONTAL_ALIGNMENT_CENTER, 40, 10, DBG_HP)

    # ── Energy gauge center ───────────────────────────────────
    var eng_c := Vector2(W * float(layout.eng_center.x), H * float(layout.eng_center.y))
    var eng_r := W * float(layout.gauge_r)
    canvas.draw_arc(eng_c, eng_r + 6.0, 0.0, TAU, 32, DBG_ENG, 1.5)
    canvas.draw_string(font, eng_c + Vector2(-20, -eng_r - 14), "ENG",
        HORIZONTAL_ALIGNMENT_CENTER, 40, 10, DBG_ENG)

    # ── Info text (top-left) ──────────────────────────────────
    var info := "DEBUG  ship=%s  steer_r=%.3f" % [layout.name, layout.steer_radius]
    canvas.draw_string(font, Vector2(10, 20), info,
        HORIZONTAL_ALIGNMENT_LEFT, 500, 12, Color(1, 1, 0, 0.8))
