extends Control
# ==============================================================
#  cockpit_view.gd  —  attach กับ CockpitView (Control) ใน gameplay.tscn
#
#  First-person cockpit view — อุกาบาตอยู่นิ่ง (world_z คงที่)
#  ยานบินไปข้างหน้า (ship_z เพิ่มขึ้น)
#  ขีดแนวตั้ง ซ้าย/ขวา บอกขอบเขต hitbox ของยาน
# ==============================================================

signal quiz_triggered
signal shield_changed(active: bool)
signal powerup_collected(type: String)

@onready var gradient_rect: ColorRect      = $GradientEffect
@onready var gradient_mat:  ShaderMaterial = gradient_rect.material as ShaderMaterial

# ── Layout ────────────────────────────────────────────────────────
var W: float; var H: float
var CX: float; var CY: float
var PANEL_Y: float   # top of instrument panel (bottom of cockpit glass)

# ── Hitbox (lateral only) ─────────────────────────────────────────
const HIT_HALF_W := 52.0   # world units — half-width of ship hitbox

# ── Ship movement ─────────────────────────────────────────────────
const SHIP_SPEED      := 360.0
const MAX_SHIP_OFFSET := 540.0
const TILT_SPEED      := 8.0

var ship_offset_x: float = 0.0
var ship_smooth_x: float = 0.0
var tilt:          float = 0.0

# ── Shield ────────────────────────────────────────────────────────
var has_shield: bool = false

# ── Stars ─────────────────────────────────────────────────────────
const STAR_COUNT    := 115
const STAR_DIST_MAX := 0.55
var stars: Array = []

# ── Asteroids ─────────────────────────────────────────────────────
const SCALE_FACTOR     := 2.1
const FAR_Z            := 1200.0
const FAR_DEPTH        := 0.04
const NEAR_DEPTH       := 1.05
const AST_DAMAGE_DEPTH := 0.72
const AST_PASS_DEPTH   := 1.05
const THREAT_WX_MAX    := 500.0
const FIELD_SIZE       := 14
const RESPAWN_SPREAD   := 0.30

const TYPE_THREAT := "threat"
const TYPE_QUIZ   := "quiz"
const TYPE_SHIELD := "shield"
const TYPE_ENERGY := "energy"
const TYPE_SCORE  := "score"

var asteroids:   Array[Dictionary] = []
var quiz_active: bool = false

# ── Ship forward Z ────────────────────────────────────────────────
var ship_z: float = 0.0

# ── Visual state ─────────────────────────────────────────────────
var blink_phase:  float = 0.0
var danger_level: float = 0.0
var safe_level:   float = 0.0
var dodge_popups: Array  = []
var combo:        int    = 0
var font: Font

# ── Journey progress ─────────────────────────────────────────────
const FORWARD_SPEED := 80.0

# ── Colors (🎬 Pixar Space Style) ────────────────────────────────
const COL_SKY     := Color(0.030, 0.012, 0.090)   # deep nebula purple
const COL_NEUTRAL := Color(0.50,  0.70,  1.00,  0.40)
const COL_DANGER  := Color(1.00,  0.22,  0.25)   # coral red
const COL_SAFE    := Color(0.10,  0.95,  0.50)   # Pixar green
const COL_GLASS   := Color(0.55,  0.75,  1.0,   0.05)
const COL_PILLAR  := Color(0.08,  0.05,  0.16)   # dark purple metal

# Nebula wisps colours (painted into sky)
const COL_NEB1    := Color(0.42,  0.10,  0.72,  0.18)  # violet
const COL_NEB2    := Color(0.80,  0.12,  0.45,  0.12)  # magenta
const COL_NEB3    := Color(0.05,  0.42,  0.62,  0.12)  # teal

# ──────────────────────────────────────────────────────────────────
func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    font = ThemeDB.fallback_font

    var vp := get_viewport_rect()
    W       = vp.size.x
    H       = vp.size.y
    CX      = W * 0.5
    CY      = H * 0.29
    PANEL_Y = H * 0.67

    gradient_mat.set_shader_parameter("danger",     0.0)
    gradient_mat.set_shader_parameter("safe_level", 0.0)

    _init_stars()
    _init_field()

# ──────────────────────────────────────────────────────────────────
func _init_stars() -> void:
    stars.clear()
    var max_d := minf(W, H) * STAR_DIST_MAX
    # Star color palette — Pixar space: gold, icy-blue, white, faint pink
    var star_hues := [
        Color(1.0,  0.95, 0.70),   # warm gold
        Color(0.75, 0.90, 1.0),    # ice blue
        Color(1.0,  1.0,  1.0),    # pure white
        Color(1.0,  0.85, 0.95),   # faint pink
        Color(0.70, 1.0,  0.90),   # mint
    ]
    for i in STAR_COUNT:
        stars.append({
            a   = randf() * TAU,
            d   = randf() * max_d,
            r   = randf() * 1.2 + 0.3,
            br  = randf() * 0.5 + 0.50,
            spd = 42.0 + randf() * 70.0,
            hue = star_hues[randi() % star_hues.size()],
        })

# ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
    if not GameManager.is_game_running:
        return
    blink_phase += delta * 4.0
    _update_ship(delta)
    _update_stars(delta)
    _update_asteroids(delta)
    _update_journey(delta)
    _update_popups(delta)
    _push_shader()
    queue_redraw()

# ── Ship ─────────────────────────────────────────────────────────
func _update_ship(delta: float) -> void:
    var dir := 0.0
    if TouchInput.is_steering_left:  dir = -1.0
    if TouchInput.is_steering_right: dir =  1.0

    var is_boost := TouchInput.is_boosting and GameManager.current_energy > 0.0
    var boost    := GameSettings.boost_speed_mult if is_boost else 1.0

    ship_offset_x = clampf(
        ship_offset_x + dir * SHIP_SPEED * boost * delta,
        -MAX_SHIP_OFFSET, MAX_SHIP_OFFSET)
    ship_smooth_x = lerpf(ship_smooth_x, ship_offset_x, 10.0 * delta)
    tilt          = lerpf(tilt, -dir * 20.0, TILT_SPEED * delta)
    ship_z        += FORWARD_SPEED * boost * delta

    if is_boost:
        GameManager.use_energy(GameSettings.energy_drain_boost * delta)
    else:
        GameManager.restore_energy(GameSettings.energy_idle_regen * delta)

# ── Stars ─────────────────────────────────────────────────────────
func _update_stars(delta: float) -> void:
    var max_d := minf(W, H) * STAR_DIST_MAX
    for st in stars:
        st.d += st.spd * delta
        if st.d > max_d:
            st.d = randf() * 20.0
            st.a = randf() * TAU

# ── Interactive asteroids ─────────────────────────────────────────
func _update_asteroids(delta: float) -> void:
    var any_in   := false
    var any_safe := false
    var to_respawn: Array = []

    for ast in asteroids:
        var rel_z: float = ast.world_z - ship_z
        var t: float     = clampf(1.0 - rel_z / FAR_Z, 0.0, 1.2)
        ast.depth = lerpf(FAR_DEPTH, NEAR_DEPTH, t)

        var d  : float = ast.depth
        var sx : float = _ast_sx(ast)
        var sy : float = _ast_sy(ast)
        var sr : float = _ast_sr(ast)
        var in_c := _in_hitbox(ast)

        match ast.type:
            TYPE_THREAT:
                if d >= AST_DAMAGE_DEPTH and d <= AST_PASS_DEPTH:
                    if in_c and not ast.damage_dealt:
                        ast.damage_dealt = true
                        _deal_damage(ast)
                    elif not in_c and d >= AST_PASS_DEPTH - 0.08 \
                            and not ast.damage_dealt and not ast.dodged:
                        ast.dodged = true
                        combo += 1
                        GameManager.add_score(100 * combo)
                        var combo_txt := " ×" + str(combo) if combo > 1 else ""
                        _spawn_popup(sx + 55, sy - 35,
                            "หลบพ้น! +" + str(100 * combo) + combo_txt)

                if d >= AST_DAMAGE_DEPTH and d < AST_PASS_DEPTH:
                    if in_c: any_in   = true
                    else:    any_safe = true

            TYPE_QUIZ:
                if d >= AST_DAMAGE_DEPTH and in_c and not ast.collected:
                    ast.collected = true
                    quiz_active   = true
                    quiz_triggered.emit()

            TYPE_SHIELD:
                if d >= AST_DAMAGE_DEPTH and in_c and not ast.collected:
                    ast.collected = true
                    has_shield = true
                    shield_changed.emit(true)
                    powerup_collected.emit("shield")
                    GameManager.add_score(100)

            TYPE_ENERGY:
                if d >= AST_DAMAGE_DEPTH and in_c and not ast.collected:
                    ast.collected = true
                    powerup_collected.emit("energy")
                    GameManager.restore_energy_or_score(25.0, GameSettings.overflow_coin_bonus)

            TYPE_SCORE:
                if d >= AST_DAMAGE_DEPTH and in_c and not ast.collected:
                    ast.collected = true
                    GameManager.add_score(500)

        if rel_z < -(FAR_Z * 0.15):
            to_respawn.append(ast)

    for ast in to_respawn:
        asteroids.erase(ast)
        _spawn_at_world_z(ship_z + FAR_Z * randf_range(0.85, 1.0 + RESPAWN_SPREAD))

    var target_danger := 1.0 if any_in   else 0.0
    var target_safe   := 1.0 if any_safe else 0.0
    danger_level = lerpf(danger_level, target_danger, 7.0 * delta)
    if any_in:
        safe_level = lerpf(safe_level, 0.0, 9.0 * delta)
    else:
        safe_level = lerpf(safe_level, target_safe, 5.0 * delta)

func _deal_damage(_ast: Dictionary) -> void:
    if has_shield:
        has_shield = false
        shield_changed.emit(false)
        SoundManager.play_sfx("powerup")
        combo = 0
        return
    GameManager.take_damage(25.0)
    SoundManager.play_sfx("explosion")
    combo = 0

# ── Field init & spawn ───────────────────────────────────────────
func _init_field() -> void:
    for i in FIELD_SIZE:
        var base := float(i) / float(FIELD_SIZE)
        var wz := ship_z + FAR_Z * (0.5 + base * 1.7 + randf() * 0.06)
        _spawn_at_world_z(wz)

func _spawn_at_world_z(world_z: float) -> void:
    var rng  := randf()
    var type : String
    if   rng < 0.62: type = TYPE_THREAT
    elif rng < 0.67 and not quiz_active: type = TYPE_QUIZ
    elif rng < 0.79: type = TYPE_SHIELD
    elif rng < 0.91: type = TYPE_ENERGY
    else:            type = TYPE_SCORE

    var wx:     float
    var base_r: float
    if type == TYPE_THREAT:
        wx     = randf_range(-THREAT_WX_MAX, THREAT_WX_MAX)
        base_r = 22.0 + randf() * 12.0
    else:
        wx     = randf_range(50.0, THREAT_WX_MAX) * (1.0 if randf() > 0.5 else -1.0)
        base_r = 20.0

    asteroids.append({
        type         = type,
        world_z      = world_z,
        wx           = wx,
        wy           = randf_range(-70.0, 70.0),
        depth        = FAR_DEPTH,
        base_r       = base_r,
        damage_dealt = false,
        collected    = false,
        dodged       = false,
    })

# ── Journey progress ──────────────────────────────────────────────
func _update_journey(delta: float) -> void:
    var is_boost := TouchInput.is_boosting and GameManager.current_energy > 0.0
    var speed    := FORWARD_SPEED * (GameSettings.boost_speed_mult if is_boost else 1.0)
    var total: float = GameManager.selected_planet.get("time_limit", 300.0) * FORWARD_SPEED

    GameManager.journey_progress = minf(1.0,
        GameManager.journey_progress + (speed * delta) / total)
    GameManager.add_score(int(speed * delta * 0.5))

    if GameManager.journey_progress >= 1.0 and GameManager.is_game_running:
        GameManager.complete_mission()

# ── Popups ────────────────────────────────────────────────────────
func _update_popups(delta: float) -> void:
    var to_remove: Array = []
    for p in dodge_popups:
        p.y    += p.vy * delta
        p.life -= delta
        if p.life <= 0.0:
            to_remove.append(p)
    for p in to_remove:
        dodge_popups.erase(p)

func _spawn_popup(x: float, y: float, text: String) -> void:
    dodge_popups.append({x = x, y = y, vy = -32.0, life = 1.5, text = text})

# ── Shader sync ───────────────────────────────────────────────────
func _push_shader() -> void:
    gradient_mat.set_shader_parameter("danger",     danger_level)
    gradient_mat.set_shader_parameter("safe_level", safe_level)

# ── Screen-space helpers ──────────────────────────────────────────
func _ast_sx(ast: Dictionary) -> float:
    return CX + (ast.wx - ship_smooth_x) * ast.depth * SCALE_FACTOR

func _ast_sy(ast: Dictionary) -> float:
    return CY + ast.wy * ast.depth * SCALE_FACTOR

func _ast_sr(ast: Dictionary) -> float:
    return ast.base_r * ast.depth * SCALE_FACTOR

func _in_hitbox(ast: Dictionary) -> bool:
    return abs(ast.wx - ship_smooth_x) < HIT_HALF_W

# ════════════════════════════════════════════════════════════════
#  DRAW — first-person cockpit
# ════════════════════════════════════════════════════════════════
func _draw() -> void:
    _draw_sky()
    _draw_stars()
    _draw_asteroids()
    _draw_vertical_markers()
    _draw_status_text()
    _draw_dodge_popups()
    _draw_glass_edge()
    _draw_ship()
    _draw_panel_screens()
    _draw_cockpit_arch()

# ── Sky + Nebula wisps (Pixar deep space) ────────────────────────
func _draw_sky() -> void:
    draw_rect(Rect2(0.0, 0.0, W, PANEL_Y + 2.0), COL_SKY)
    # Nebula wisps — 3 large soft ellipses offset from center
    var phase := blink_phase * 0.08   # very slow drift
    _draw_nebula_wisp(CX - W*0.28 + sin(phase)*12.0,   PANEL_Y*0.35, W*0.52, PANEL_Y*0.55, COL_NEB1)
    _draw_nebula_wisp(CX + W*0.22 + cos(phase*0.7)*10.0, PANEL_Y*0.55, W*0.45, PANEL_Y*0.48, COL_NEB2)
    _draw_nebula_wisp(CX + W*0.05,                      PANEL_Y*0.18, W*0.38, PANEL_Y*0.32, COL_NEB3)

func _draw_nebula_wisp(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
    # Approximate soft ellipse with concentric transparent ellipses
    var steps := 8
    for i in steps:
        var t: float = float(i) / steps
        var alpha: float = col.a * (1.0 - t) * (1.0 - t)
        var fc := Color(col.r, col.g, col.b, alpha)
        var ex := rx * (1.0 - t * 0.6)
        var ey := ry * (1.0 - t * 0.6)
        draw_arc(Vector2(cx, cy), ex * 0.5, 0.0, TAU, 32, fc, ey)
        # Use rect to approximate filled ellipse (Godot has no draw_ellipse fill)
        draw_rect(Rect2(cx - ex * 0.5, cy - ey * 0.5, ex, ey), fc)

# ── Stars (Pixar: coloured stars with glow) ───────────────────────
func _draw_stars() -> void:
    var max_d := minf(W, H) * STAR_DIST_MAX
    for st in stars:
        var sx: float = CX + cos(st.a) * st.d - ship_smooth_x * 0.1
        var sy: float = CY + sin(st.a) * st.d * 0.65
        if sy < 0.0 or sy > PANEL_Y: continue
        var hue: Color = st.get("hue", Color.WHITE)
        # Warp trail for fast stars
        if st.d > max_d * 0.30:
            var trail: float = st.spd * 0.16
            draw_line(Vector2(sx, sy),
                Vector2(sx - cos(st.a)*trail, sy - sin(st.a)*trail*0.65),
                Color(hue.r, hue.g, hue.b, st.br * 0.28), st.r * 0.55, true)
        # Glow halo for brighter stars
        if st.r > 0.9:
            draw_circle(Vector2(sx, sy), st.r * 2.5, Color(hue.r, hue.g, hue.b, 0.12))
        # Star core
        draw_circle(Vector2(sx, sy), st.r, Color(hue.r, hue.g, hue.b, st.br))

# ── Asteroids (🎬 Pixar cartoon style) ────────────────────────────
func _draw_asteroids() -> void:
    for ast in asteroids:
        var ax := _ast_sx(ast)
        var ay := _ast_sy(ast)
        var ar := _ast_sr(ast)
        if ar < 2.0 or ar > W * 0.75: continue
        if ax < -100.0 or ax > W + 100.0: continue

        # Pixar colour palette per type
        var col: Color
        var col_dark: Color
        var col_rim: Color
        match ast.type:
            TYPE_THREAT:
                col      = Color(0.75, 0.45, 0.18)   # warm caramel rock
                col_dark = Color(0.42, 0.22, 0.06)
                col_rim  = Color(1.00, 0.70, 0.35)
            TYPE_QUIZ:
                col      = Color(0.20, 0.65, 1.00)   # Pixar blue orb
                col_dark = Color(0.05, 0.25, 0.75)
                col_rim  = Color(0.60, 0.90, 1.00)
            TYPE_SHIELD:
                col      = Color(0.35, 0.50, 1.00)   # indigo orb
                col_dark = Color(0.10, 0.15, 0.70)
                col_rim  = Color(0.70, 0.80, 1.00)
            TYPE_ENERGY:
                col      = Color(0.05, 0.90, 0.70)   # cyan-green
                col_dark = Color(0.00, 0.45, 0.35)
                col_rim  = Color(0.60, 1.00, 0.85)
            TYPE_SCORE:
                col      = Color(1.00, 0.82, 0.10)   # Pixar gold
                col_dark = Color(0.65, 0.45, 0.00)
                col_rim  = Color(1.00, 0.95, 0.60)
            _:
                col      = Color(0.75, 0.45, 0.18)
                col_dark = Color(0.42, 0.22, 0.06)
                col_rim  = Color(1.00, 0.70, 0.35)

        var av := Vector2(ax, ay)

        # ── Danger aura (pulsing coral glow) ──────────────────────
        if ast.type == TYPE_THREAT and danger_level > 0.15:
            var pulse := 0.6 + 0.35 * sin(blink_phase * 2.0)
            draw_circle(av, ar + 32.0, Color(1.0, 0.22, 0.25, 0.14 * danger_level * pulse))
            draw_circle(av, ar + 18.0, Color(1.0, 0.45, 0.10, 0.10 * danger_level * pulse))

        # ── Body shadow (offset dark circle) ──────────────────────
        if ar > 6.0:
            draw_circle(Vector2(ax + ar*0.18, ay + ar*0.18), ar * 0.92,
                Color(col_dark.r, col_dark.g, col_dark.b, 0.55))

        # ── Main body ─────────────────────────────────────────────
        draw_circle(av, ar, col)

        if ar > 8.0:
            # Darker lower-right shading (directional light)
            draw_circle(Vector2(ax + ar*0.22, ay + ar*0.22), ar * 0.72,
                Color(col_dark.r, col_dark.g, col_dark.b, 0.45))
            # Highlight (top-left Pixar gloss)
            draw_circle(Vector2(ax - ar*0.28, ay - ar*0.30), ar * 0.38,
                Color(1.0, 1.0, 1.0, 0.20))
            draw_circle(Vector2(ax - ar*0.18, ay - ar*0.22), ar * 0.15,
                Color(1.0, 1.0, 1.0, 0.50))

        # ── Cartoon outline ────────────────────────────────────────
        if ar > 5.0:
            draw_arc(av, ar, 0.0, TAU, clamp(int(ar * 2), 12, 48),
                Color(col_dark.r * 0.5, col_dark.g * 0.5, col_dark.b * 0.5, 0.80),
                maxf(2.0, ar * 0.08))

        # ── Glow ring for powerups (animated) ─────────────────────
        if ast.type != TYPE_THREAT:
            var pulse := 0.7 + 0.3 * sin(blink_phase * 1.8)
            draw_arc(av, ar + 7.0, 0.0, TAU, 36,
                Color(col_rim.r, col_rim.g, col_rim.b, 0.65 * pulse), 2.8)
            draw_arc(av, ar + 13.0, 0.0, TAU, 24,
                Color(col_rim.r, col_rim.g, col_rim.b, 0.25 * pulse), 1.5)

        # ── Approach dashed line for threats ──────────────────────
        if ast.type == TYPE_THREAT and ast.depth > 0.25 and ast.depth < AST_DAMAGE_DEPTH * 0.82:
            var fa: float = (ast.depth - 0.25) / (AST_DAMAGE_DEPTH * 0.82 - 0.25) * 0.40
            draw_dashed_line(av, Vector2(CX, CY),
                Color(1.0, 0.45, 0.12, fa), 1.8, 12.0)

# ── Vertical boundary markers ─────────────────────────────────────
#    ขีดแนวตั้งซ้าย/ขวา บ่งบอกขอบเขตของ hitbox ยาน
#    หาก asteroid อยู่ระหว่างเส้นสองเส้นนี้ = ชน
func _draw_vertical_markers() -> void:
    # screen half-width of hitbox at collision depth
    var hw := HIT_HALF_W * AST_DAMAGE_DEPTH * SCALE_FACTOR   # ≈ 78.6 px
    var lx := CX - hw
    var rx := CX + hw

    # Color by state
    var mc: Color
    if danger_level > 0.3:
        mc = Color(COL_DANGER.r, COL_DANGER.g, COL_DANGER.b,
                   0.82 + 0.15 * sin(blink_phase))
    elif safe_level > 0.3:
        mc = Color(COL_SAFE.r, COL_SAFE.g, COL_SAFE.b,
                   0.72 + 0.12 * sin(blink_phase * 0.5))
    else:
        mc = Color(0.45, 0.65, 1.0, 0.50)

    # Shield halo around the zone
    if has_shield:
        var sa := 0.42 + 0.18 * sin(blink_phase * 0.7)
        draw_arc(Vector2(CX, CY), hw + 16.0, 0.0, TAU, 48,
            Color(0.30, 0.60, 1.0, sa), 3.5)

    # Main vertical lines spanning the full glass height
    draw_line(Vector2(lx, 0.0), Vector2(lx, PANEL_Y), mc, 2.0)
    draw_line(Vector2(rx, 0.0), Vector2(rx, PANEL_Y), mc, 2.0)

    # Tick marks along the lines (every 1/7 of glass height)
    for i in 7:
        var ty := PANEL_Y * (float(i) + 0.5) / 7.0
        var tlen := 9.0 if i % 3 == 1 else 4.5
        draw_line(Vector2(lx - tlen, ty), Vector2(lx + tlen, ty), mc, 1.5)
        draw_line(Vector2(rx - tlen, ty), Vector2(rx + tlen, ty), mc, 1.5)

    # Bottom brackets at panel mouth
    var by := PANEL_Y - 7.0
    draw_line(Vector2(lx - 15.0, by), Vector2(lx + 15.0, by), mc, 3.0)
    draw_line(Vector2(rx - 15.0, by), Vector2(rx + 15.0, by), mc, 3.0)

# ── Status text ───────────────────────────────────────────────────
func _draw_status_text() -> void:
    var fsize := 22

    if danger_level > 0.5 and fmod(blink_phase, 1.6) < 0.8:
        var s  := "⚠ อุกกาบาตเข้าเขตอันตราย!"
        var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
        draw_string(font, Vector2(CX - sw * 0.5, CY - 140.0),
            s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
            Color(0.94, 0.22, 0.10, 0.9))
    elif safe_level > 0.4:
        var s  := "✓ หลบพ้นแล้ว — PATH CLEAR"
        var sw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
        draw_string(font, Vector2(CX - sw * 0.5, CY - 140.0),
            s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
            Color(0.16, 0.90, 0.39, safe_level * 0.9))

    # Dodge direction hint
    for ast in asteroids:
        if ast.type == TYPE_THREAT and ast.depth > 0.3 and ast.depth < AST_PASS_DEPTH:
            var eff_x: float = ast.wx - ship_smooth_x
            var lbl   := "◀ หลบซ้าย" if eff_x > 0.0 else "หลบขวา ▶"
            var ls    := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
            var show  := (fmod(blink_phase, 1.2) < 0.6) if danger_level > 0.3 else true
            if show:
                draw_string(font, Vector2(CX - ls * 0.5, PANEL_Y - 68.0),
                    lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
                    Color(1.0, 0.82, 0.20, 0.85))
            break

# ── Dodge popups ──────────────────────────────────────────────────
func _draw_dodge_popups() -> void:
    var fsize := 22
    for p in dodge_popups:
        var fa  := clampf(p.life / 0.25, 0.0, 1.0) * clampf(p.life / 1.5, 0.0, 1.0)
        var tw  := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + 28.0
        var px2: float = p.x; var py2: float = p.y
        draw_rect(Rect2(px2 - tw*0.5, py2 - 16.0, tw, 26.0),
            Color(0.0, 0.44, 0.15, fa * 0.88))
        draw_rect(Rect2(px2 - tw*0.5, py2 - 16.0, tw, 26.0),
            Color(0.22, 0.92, 0.43, fa * 0.75), false, 1.0)
        draw_string(font, Vector2(px2 - tw*0.5 + 14.0, py2 + 4.0),
            p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize,
            Color(1.0, 1.0, 1.0, fa * 0.96))

# ── Glass edge sheen ──────────────────────────────────────────────
func _draw_glass_edge() -> void:
    var pts := PackedVector2Array([
        Vector2(0.0, PANEL_Y - H * 0.05),
        Vector2(W,   PANEL_Y - H * 0.05),
        Vector2(W,   PANEL_Y),
        Vector2(0.0, PANEL_Y),
    ])
    var cols := PackedColorArray([
        Color(0.47, 0.63, 1.0, 0.0),
        Color(0.47, 0.63, 1.0, 0.0),
        COL_GLASS,
        COL_GLASS,
    ])
    draw_polygon(pts, cols)

# ── Ship icon (cockpit nose view) ─────────────────────────────────
func _draw_ship() -> void:
    var bx := CX + ship_smooth_x * 0.07
    var by := PANEL_Y - 46.0

    var col_body: Color
    var col_hull: Color
    if danger_level > 0.4:
        col_body = Color(0.38, 0.11, 0.11)
        col_hull = Color(0.67, 0.19, 0.19)
    elif safe_level > 0.4:
        col_body = Color(0.11, 0.38, 0.22)
        col_hull = Color(0.20, 0.67, 0.36)
    else:
        col_body = Color(0.11, 0.21, 0.54)
        col_hull = Color(0.19, 0.44, 0.74)

    var ct := cos(deg_to_rad(tilt))

    # Engine glow (3 layers)
    for i in range(3, 0, -1):
        var gc: Color
        if danger_level > 0.4:
            gc = Color(1.0, 0.39, 0.31, 0.22 - i * 0.06)
        elif safe_level > 0.4:
            gc = Color(0.31, 0.78, 1.0, 0.22 - i * 0.06)
        else:
            gc = Color(0.31, 0.59, 1.0, 0.22 - i * 0.06)
        draw_circle(Vector2(bx, by + 22.0 + i * 10.0), 10.0 - i * 2.5, gc)

    # Ship body
    var body := PackedVector2Array([
        Vector2(bx,           by - 32.0),
        Vector2(bx - 22.0*ct, by + 20.0),
        Vector2(bx - 10.0*ct, by + 16.0),
        Vector2(bx,            by + 22.0),
        Vector2(bx + 10.0*ct, by + 16.0),
        Vector2(bx + 22.0*ct, by + 20.0),
    ])
    var n6 := PackedColorArray([col_body, col_body, col_body, col_body, col_body, col_body])
    draw_polygon(body, n6)

    # Hull highlight
    var hull := PackedVector2Array([
        Vector2(bx,           by - 32.0),
        Vector2(bx - 8.0*ct, by + 12.0),
        Vector2(bx,           by + 10.0),
        Vector2(bx + 8.0*ct, by + 12.0),
    ])
    var n4 := PackedColorArray([col_hull, col_hull, col_hull, col_hull])
    draw_polygon(hull, n4)

    # Cockpit glass bubble
    draw_circle(Vector2(bx, by - 15.0), 7.0, Color(0.55, 0.78, 1.0, 0.55))

    # Engine core
    draw_circle(Vector2(bx, by + 20.0), 12.0, Color(0.39, 0.71, 1.0, 0.75))
    draw_circle(Vector2(bx, by + 20.0),  7.0, Color(0.70, 0.90, 1.0, 0.50))

# ── Instrument panel screens (drawn before arch) ──────────────────
func _draw_panel_screens() -> void:
    var PAD     := 8.0
    var MISS_H  := 80.0   # MissionBar height (matches HUD offset)
    var g_top   := PANEL_Y + MISS_H   # top of gauge columns
    var g_h     := H - g_top - PAD
    var sw      := (W - PAD * 4.0) / 3.0

    # 🎬 Pixar instrument panel — deep purple with cyan/green/gold screens
    draw_rect(Rect2(0.0, PANEL_Y, W, H - PANEL_Y), Color(0.05, 0.02, 0.12))

    # Top rule — cyan glow
    draw_line(Vector2(0.0, PANEL_Y),       Vector2(W, PANEL_Y),       Color(0.25, 0.78, 1.00, 0.90), 3.0)
    draw_line(Vector2(0.0, PANEL_Y + 4.0), Vector2(W, PANEL_Y + 4.0), Color(0.25, 0.78, 1.00, 0.22), 2.0)
    draw_line(Vector2(0.0, g_top - 1.0),   Vector2(W, g_top - 1.0),   Color(0.50, 0.30, 0.80, 0.50), 2.0)

    # Three Pixar screens: green (HP) | cyan (Nav) | gold (Speed)
    var bords := [Color(0.10, 0.95, 0.50), Color(0.25, 0.78, 1.00), Color(1.00, 0.82, 0.10)]
    var lbls  := ["[ HP / ENERGY ]", "[ NAVIGATION ]", "[ VELOCITY ]"]
    for i in 3:
        var sx := PAD + i * (sw + PAD)
        var sy := g_top + PAD
        var sh := g_h - PAD
        var bc: Color = bords[i]
        draw_rect(Rect2(sx, sy, sw, sh), Color(0.04, 0.02, 0.10))
        draw_rect(Rect2(sx - 1, sy - 1, sw + 2, sh + 2), Color(bc.r, bc.g, bc.b, 0.28), false, 4.0)
        draw_rect(Rect2(sx, sy, sw, sh), bc, false, 2.0)
        # Corner brackets
        for cx2 in [sx, sx + sw]:
            for cy2 in [sy, sy + sh]:
                var dx2 := 1.0 if cx2 == sx else -1.0
                var dy2 := 1.0 if cy2 == sy else -1.0
                draw_line(Vector2(cx2, cy2), Vector2(cx2 + dx2 * 16.0, cy2), bc, 2.5)
                draw_line(Vector2(cx2, cy2), Vector2(cx2, cy2 + dy2 * 16.0), bc, 2.5)
        var tw := font.get_string_size(lbls[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
        draw_string(font, Vector2(sx + sw * 0.5 - tw * 0.5, sy + 15.0),
            lbls[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(bc.r, bc.g, bc.b, 0.70))

    # Dividers
    for i in range(1, 3):
        var dx := PAD + i * (sw + PAD) - PAD * 0.5
        draw_line(Vector2(dx, g_top), Vector2(dx, H), Color(0.30, 0.20, 0.50, 0.40), 2.0)

# ── Wing-Commander cockpit arch frame ─────────────────────────────
func _draw_cockpit_arch() -> void:
    # 🎬 Pixar cockpit — deep purple-indigo with cyan rim glow
    var METAL     := Color(0.08, 0.05, 0.18)    # deep purple metal
    var METAL_HI  := Color(0.22, 0.16, 0.40)    # lighter purple
    var METAL_SH  := Color(0.03, 0.02, 0.08)    # near-black
    var METAL_RIM := Color(0.25, 0.78, 1.00)    # Pixar cyan glow

    var lw    := W * 0.100   # pillar width = 10%
    var rw    := W - lw
    var arch_h := H * 0.048  # top arch strip height
    var arch_lx := W * 0.13  # inner left  x of arch at arch_h
    var arch_rx := W - W * 0.13

    var c4 := PackedColorArray([METAL, METAL, METAL, METAL])

    # Left pillar (full height)
    draw_polygon(PackedVector2Array([
        Vector2(0.0, 0.0), Vector2(lw, 0.0),
        Vector2(lw, PANEL_Y), Vector2(0.0, PANEL_Y)]), c4)

    # Right pillar (full height)
    draw_polygon(PackedVector2Array([
        Vector2(W, 0.0), Vector2(W, PANEL_Y),
        Vector2(rw, PANEL_Y), Vector2(rw, 0.0)]), c4)

    # Top arch brow — full screen width at y=0, narrows to arch inner edge at arch_h
    draw_polygon(PackedVector2Array([
        Vector2(0.0, 0.0), Vector2(W, 0.0),
        Vector2(arch_rx, arch_h), Vector2(arch_lx, arch_h)]), c4)

    # Inner edge rim highlight (side pillars)
    draw_line(Vector2(lw, 0.0),  Vector2(lw, PANEL_Y),  METAL_RIM, 3.5)
    draw_line(Vector2(rw, 0.0),  Vector2(rw, PANEL_Y),  METAL_RIM, 3.5)
    # Inner shadow
    draw_line(Vector2(lw + 5.0, 0.0), Vector2(lw + 5.0, PANEL_Y), METAL_SH, 2.5)
    draw_line(Vector2(rw - 5.0, 0.0), Vector2(rw - 5.0, PANEL_Y), METAL_SH, 2.5)

    # Arch brow bottom rim
    draw_line(Vector2(arch_lx, arch_h), Vector2(arch_rx, arch_h), METAL_RIM, 2.0)
    draw_line(Vector2(arch_lx, arch_h + 4.0), Vector2(arch_rx, arch_h + 4.0), METAL_SH, 2.0)

    # Decorative horizontal rivet lines on pillars
    for i in 7:
        var py := PANEL_Y * (float(i) + 0.5) / 7.0
        draw_line(Vector2(lw * 0.08, py), Vector2(lw * 0.85, py), METAL_HI, 1.0)
        draw_line(Vector2(rw + lw * 0.15, py), Vector2(W * 0.995, py), METAL_HI, 1.0)

    # Sensor port rectangles on pillars (decorative)
    for i in 3:
        var py := PANEL_Y * (float(i) + 1.0) / 4.0
        draw_rect(Rect2(lw * 0.15, py - 6.0, lw * 0.55, 12.0), METAL_HI)
        draw_rect(Rect2(lw * 0.15, py - 6.0, lw * 0.55, 12.0), METAL_RIM, false, 1.0)
        draw_rect(Rect2(rw + lw * 0.30, py - 6.0, lw * 0.55, 12.0), METAL_HI)
        draw_rect(Rect2(rw + lw * 0.30, py - 6.0, lw * 0.55, 12.0), METAL_RIM, false, 1.0)

    # Bottom panel boundary
    draw_line(Vector2(0.0, PANEL_Y), Vector2(W, PANEL_Y), METAL_HI, 3.0)
