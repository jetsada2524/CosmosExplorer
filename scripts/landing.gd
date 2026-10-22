extends Control
# ==============================================================
#  landing.gd  —  ฉาก "กำลังลงจอด" (storyboard S-08)
#  • avatar 0 (Rocket)  → แสดง spaceship.glb แบบ 3D ผ่าน SubViewport
#  • avatar 1 (UFO)     → แสดง ufo.glb แบบ 3D ผ่าน SubViewport
#  • avatar 2 (Special) → แสดง star.glb แบบ 3D ผ่าน SubViewport
#  • avatar อื่น        → ใช้ sprite 2D ตามเดิม
# ==============================================================

const SHIP_TEXTURES: Array[String] = [
    "res://assets/sprites/ships/ship_rocket.png",
    "res://assets/sprites/ships/ship_ufo.png",
    "res://assets/sprites/ships/ship_star.png",
]
const SHIP_SCALES: Array[float] = [0.32, 0.50, 0.50]
const EARTH_GRAVITY: float = 9.81

const SHIP_3D_PATH    := "res://assets/models/spaceship.glb"
const UFO_3D_PATH     := "res://assets/models/ufo.glb"
const SPECIAL_3D_PATH := "res://assets/models/ship_comet.glb"   # ยานแบบที่ 3 (Comet)

@onready var planet_sky:          TextureRect    = $PlanetSky
@onready var surface:             ColorRect      = $Surface
@onready var surface_texture:     TextureRect    = $Surface/SurfaceTexture
@onready var surface_curve_glow:  TextureRect    = $Surface/SurfaceCurveGlow
@onready var ship_sprite:         Sprite2D       = $ShipSprite
@onready var thruster_glow:       Label          = $ThrusterGlow
@onready var title_label:         Label          = $TitleLabel
@onready var sub_label:           Label          = $SubLabel
@onready var fact_badge:          PanelContainer = $FactBadge
@onready var fact_label:          Label          = $FactBadge/FactLabel
@onready var advance_timer:       Timer          = $AdvanceTimer

# 3D ship (avatar 0 = Rocket, avatar 1 = UFO)
var _ship3d_container: SubViewportContainer = null
var _ship3d_viewport:  SubViewport          = null
var _ship3d_node:      Node3D               = null
var _thruster_l_mat:   StandardMaterial3D   = null
var _thruster_r_mat:   StandardMaterial3D   = null
var _ufo_engine_mat:   StandardMaterial3D   = null   # UFO single engine glow
var _spc_nozzle_l_mat: StandardMaterial3D   = null   # Special engine nozzle L
var _spc_nozzle_r_mat: StandardMaterial3D   = null   # Special engine nozzle R
var _is_ufo_landing:     bool               = false
var _is_special_landing: bool               = false

# เอฟเฟกต์ลงจอด (ไอพ่น / เมฆฝุ่น / ประกายไฟ)
var _ship_cam:      Camera3D = null
var _engine_nodes:  Array[Node3D] = []
var _jets:          Array[Sprite2D] = []
var _cloud_back:    TextureRect = null
var _cloud_front:   TextureRect = null
var _fx_t:          float = 0.0

# 3D planet background
var _planet_bg_vp:  SubViewport = null
var _planet_bg_3d:  Node3D      = null

func _ready() -> void:
    UITheme.apply_cosmos_bg(self)
    TouchInput.reset()
    SoundManager.play_sfx("landing")
    _apply_styles()
    _populate()
    _build_landing_fx()
    _animate_descent()
    advance_timer.timeout.connect(_on_advance)
    advance_timer.wait_time = HOLD_SECONDS   # ค้างหน้า landing + animation ก่อนไปหน้าผลลัพธ์
    advance_timer.start()

func _process(delta: float) -> void:
    if _planet_bg_3d:
        _planet_bg_3d.rotation.y += 0.08 * delta   # หมุนช้ามาก — เหมือนเห็นดาวจากอวกาศ
    _fx_t += delta
    _update_jets()
    # เมฆฝุ่นลอยไหวช้า ๆ
    if _cloud_back:
        _cloud_back.position.x = -240.0 + sin(_fx_t * 0.5) * 26.0
    if _cloud_front:
        _cloud_front.position.x = -240.0 - sin(_fx_t * 0.4 + 1.0) * 34.0

# ── Styles ─────────────────────────────────────────────────────
func _apply_styles() -> void:
    _build_curve_glow()
    title_label.add_theme_font_size_override("font_size", 60)
    title_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.22))
    title_label.add_theme_color_override("font_outline_color", Color(0.35, 0.14, 0.02, 0.95))
    title_label.add_theme_constant_override("outline_size", 12)
    title_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.55, 0.10, 0.45))
    title_label.add_theme_constant_override("shadow_offset_y", 0)
    title_label.add_theme_constant_override("shadow_outline_size", 26)
    sub_label.add_theme_font_size_override("font_size", 34)
    sub_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.90))
    sub_label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.15, 0.85))
    sub_label.add_theme_constant_override("outline_size", 8)
    sub_label.offset_left = -500.0
    sub_label.offset_right = 500.0
    thruster_glow.add_theme_font_size_override("font_size", 48)
    var fb := UITheme.make_panel_style(Color(0.22, 0.11, 0.34, 0.94), Color(0.62, 0.46, 0.95, 0.95), 18, 3)
    fb.content_margin_left = 24
    fb.content_margin_right = 24
    fb.content_margin_top = 8
    fb.content_margin_bottom = 10
    fact_badge.add_theme_stylebox_override("panel", fb)
    fact_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
    fact_label.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)

func _build_curve_glow() -> void:
    var grad := Gradient.new()
    grad.colors  = PackedColorArray([Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
    grad.offsets = PackedFloat32Array([0.0, 1.0])
    var curve_tex := GradientTexture2D.new()
    curve_tex.gradient = grad
    curve_tex.fill     = GradientTexture2D.FILL_RADIAL
    curve_tex.fill_from = Vector2(0.5, 0.0)
    curve_tex.fill_to   = Vector2(0.5, 1.0)
    curve_tex.width  = 128
    curve_tex.height = 64
    surface_curve_glow.texture = curve_tex

# ── Populate ───────────────────────────────────────────────────
func _populate() -> void:
    var data: Dictionary = GameManager.selected_planet
    sub_label.text = "ยินดีต้อนรับสู่%s" % data.get("name_th", "ดาวปลายทาง")

    var pid: String = data.get("id", "")
    var tex_path := "res://assets/sprites/planets/%s.png" % pid
    if ResourceLoader.exists(tex_path):
        var planet_tex: Texture2D = load(tex_path)
        planet_sky.texture       = planet_tex
        surface_texture.texture  = planet_tex

    var grav: float = data.get("gravity", EARTH_GRAVITY)
    if grav < EARTH_GRAVITY:
        fact_label.text = "💡 แรงโน้มถ่วงน้อยกว่าโลก %.1f เท่า!" % (EARTH_GRAVITY / maxf(grav, 0.01))
    else:
        fact_label.text = "💡 แรงโน้มถ่วงมากกว่าโลก %.1f เท่า!" % (grav / EARTH_GRAVITY)

    var color_hex: String = data.get("color_hex", "#a06840")
    surface.color             = Color.html(color_hex).darkened(0.35)
    surface_texture.modulate  = Color.html(color_hex).darkened(0.10)
    # พื้นผิวจริงของดาวปลายทาง (แถบเส้นศูนย์สูตรจาก texture ของโมเดลดาว)
    var surf_path := "res://assets/sprites/planets/surface_%s.png" % pid
    if ResourceLoader.exists(surf_path):
        surface_texture.texture      = load(surf_path)
        surface_texture.modulate     = Color.WHITE
        surface_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        surface_curve_glow.anchor_left  = 0.0   # กว้างเต็มจอ ไม่ให้เห็นรอยต่อบนพื้นผิวจริง
        surface_curve_glow.anchor_right = 1.0
        surface_curve_glow.offset_left  = 0.0
        surface_curve_glow.offset_right = 0.0

    # ── 3D planet background ──────────────────────────────────────
    _spawn_3d_planet_bg(pid)

    var avatar: int = GameManager.player_avatar
    _is_ufo_landing     = (avatar == 1)
    _is_special_landing = (avatar == 2)

    # ยาน 3D ชุดใหม่ (assets/models/ships) — ถ้าโหลดไม่ได้ใช้รูป 2D ตามหน้าเลือกตัวละครแทน
    if not _setup_ship_3d(avatar):
        _setup_ship_2d(avatar)

# ── 3D Planet Background ──────────────────────────────────────
func _spawn_3d_planet_bg(planet_id: String) -> void:
    if planet_id.is_empty():
        return

    # ขนาด viewport ใหญ่กว่าจอ เพื่อให้ดาวใหญ่เต็มพื้นที่ภาพฉากหลัง
    var sz := Vector2i(900, 900)
    var tilt := 14.0 if planet_id == "saturn" else 10.0

    var vd := Planet3DView.make_planet_vp(self, planet_id, sz, tilt)
    if vd.is_empty():
        return

    _planet_bg_vp = vd["vp"]
    _planet_bg_3d = vd["planet_node"]

    # ใช้ ViewportTexture กับ planet_sky TextureRect
    planet_sky.texture     = _planet_bg_vp.get_texture()
    planet_sky.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    planet_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

    # ดาวปลายทางใหญ่เต็มตา อยู่ด้านหลังยาน (ตามดีไซน์)
    planet_sky.modulate = Color.WHITE
    var rect_sz: float = PLANET_RECT_SATURN if planet_id == "saturn" else PLANET_RECT
    planet_sky.anchor_top = 0.0
    planet_sky.anchor_bottom = 0.0
    planet_sky.offset_left = -rect_sz * 0.5
    planet_sky.offset_right = rect_sz * 0.5
    planet_sky.offset_top = PLANET_CENTER_Y - rect_sz * 0.5
    planet_sky.offset_bottom = PLANET_CENTER_Y + rect_sz * 0.5
    _add_planet_halo(planet_id)

# ── 3D Ship via SubViewport ────────────────────────────────────
func _spawn_3d_ship(glb_path: String) -> void:
    # SubViewportContainer (2D canvas layer — same position as ship_sprite)
    _ship3d_container = SubViewportContainer.new()
    _ship3d_container.stretch = true
    _ship3d_container.custom_minimum_size = Vector2(440, 520)
    # วางตรงกลางจอ ไว้เหนือพื้นผิวดาว (ใหญ่ขึ้น ใกล้กล้องตามดีไซน์)
    _ship3d_container.set_anchors_preset(Control.PRESET_CENTER)
    _ship3d_container.offset_left   = -220
    _ship3d_container.offset_right  =  220
    _ship3d_container.offset_top    = -260
    _ship3d_container.offset_bottom =  260
    add_child(_ship3d_container)

    # SubViewport
    _ship3d_viewport = SubViewport.new()
    _ship3d_viewport.size               = Vector2i(440, 520)
    _ship3d_viewport.transparent_bg     = true
    _ship3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    _ship3d_container.add_child(_ship3d_viewport)

    # 3D scene inside viewport
    var scene_root := Node3D.new()
    _ship3d_viewport.add_child(scene_root)

    # Camera looking at ship from slightly below-front
    var cam := Camera3D.new()
    cam.position = Vector3(0.0, 0.8, 3.5)
    cam.rotation_degrees = Vector3(-12.0, 0.0, 0.0)   # หันหน้าเข้าหายาน (-Z)
    cam.fov  = 45.0
    cam.near = 0.1
    cam.far  = 50.0
    scene_root.add_child(cam)
    _ship_cam = cam

    # Environment — transparent + glow
    var env_node := WorldEnvironment.new()
    var env      := Environment.new()
    env.background_mode  = Environment.BG_COLOR
    env.background_color = Color(0, 0, 0, 0)
    env.glow_enabled     = true
    env.glow_intensity   = 0.8
    env_node.environment = env
    scene_root.add_child(env_node)

    # Lights
    var sun := DirectionalLight3D.new()
    sun.light_color  = Color(1.0, 0.92, 0.80)
    sun.light_energy = 1.4
    sun.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
    scene_root.add_child(sun)

    var fill := OmniLight3D.new()
    fill.light_color  = Color(0.35, 0.55, 1.0)
    fill.light_energy = 0.6
    fill.omni_range   = 12.0
    fill.position     = Vector3(-2.0, 1.0, 2.0)
    scene_root.add_child(fill)

    # Ship model (Rocket หรือ UFO)
    var ship_glb: PackedScene = load(glb_path)
    _ship3d_node = ship_glb.instantiate() as Node3D
    if _is_ufo_landing:
        # UFO ทรงจาน — ขยายและวางสูงขึ้นเล็กน้อยเพื่อให้มองเห็นดิสก์ชัดเจน
        _ship3d_node.scale    = Vector3.ONE * 0.65
        _ship3d_node.position = Vector3(0.0, 1.3, 0.0)
    elif _is_special_landing:
        # Comet — ยานทรงกลม หน้าต่างใหญ่หันเข้ากล้อง, origin ที่ปลายขา
        _ship3d_node.scale    = Vector3.ONE * 0.85
        _ship3d_node.position = Vector3(0.0, 1.5, 0.0)
    else:
        _ship3d_node.scale    = Vector3.ONE * 0.55
        _ship3d_node.position = Vector3(0.0, 1.5, 0.0)   # เริ่มสูง → ลงจอด
    scene_root.add_child(_ship3d_node)
    # จุดปล่อยไอพ่น (ใช้วาดลำไอพ่น 2D ให้ตามยานขณะลงจอด)
    for en in ["ThrusterGlow_L", "ThrusterGlow_R", "UFO_EngineGlow", "Comet_EngineGlow"]:
        var n := _ship3d_node.find_child(en, true, false) as Node3D
        if n:
            _engine_nodes.append(n)

    if _is_ufo_landing:
        # UFO: engine glow node เดียว (UFO_EngineGlow)
        var eg := _ship3d_node.find_child("UFO_EngineGlow", true, false) as MeshInstance3D
        if eg:
            _ufo_engine_mat = StandardMaterial3D.new()
            _ufo_engine_mat.albedo_color               = Color(0.4, 0.9, 1.0, 0.85)
            _ufo_engine_mat.emission_enabled           = true
            _ufo_engine_mat.emission                   = Color(0.3, 0.8, 1.0)
            _ufo_engine_mat.emission_energy_multiplier = 5.0
            _ufo_engine_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
            _ufo_engine_mat.cull_mode                  = BaseMaterial3D.CULL_DISABLED
            eg.material_override = _ufo_engine_mat
    elif _is_special_landing:
        # Special: engine nozzle 2 ข้าง (Special_EngineNozzleL / Special_EngineNozzleR)
        var nl := _ship3d_node.find_child("Special_EngineNozzleL", true, false) as MeshInstance3D
        var nr := _ship3d_node.find_child("Special_EngineNozzleR", true, false) as MeshInstance3D
        # Comet: ไฟเครื่องยนต์จานเดียวใต้ยาน (สีส้มตามธีมยาน)
        var cg := _ship3d_node.find_child("Comet_EngineGlow", true, false) as MeshInstance3D
        if cg:
            _spc_nozzle_l_mat = StandardMaterial3D.new()
            _spc_nozzle_l_mat.albedo_color               = Color(1.0, 0.65, 0.2, 0.9)
            _spc_nozzle_l_mat.emission_enabled           = true
            _spc_nozzle_l_mat.emission                   = Color(1.0, 0.55, 0.1)
            _spc_nozzle_l_mat.emission_energy_multiplier = 8.0
            _spc_nozzle_l_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
            cg.material_override = _spc_nozzle_l_mat
        if nl:
            _spc_nozzle_l_mat = StandardMaterial3D.new()
            _spc_nozzle_l_mat.albedo_color               = Color(0.95, 0.97, 1.0, 0.9)
            _spc_nozzle_l_mat.emission_enabled           = true
            _spc_nozzle_l_mat.emission                   = Color(1.0, 1.0, 1.0)
            _spc_nozzle_l_mat.emission_energy_multiplier = 8.0
            _spc_nozzle_l_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
            nl.material_override = _spc_nozzle_l_mat
        if nr:
            _spc_nozzle_r_mat = _spc_nozzle_l_mat.duplicate() as StandardMaterial3D if _spc_nozzle_l_mat else null
            if _spc_nozzle_r_mat:
                nr.material_override = _spc_nozzle_r_mat
    else:
        # Rocket: ไฟพ่น 2 ข้าง (ThrusterGlow_L / ThrusterGlow_R)
        var tl := _ship3d_node.find_child("ThrusterGlow_L", true, false) as MeshInstance3D
        var tr := _ship3d_node.find_child("ThrusterGlow_R", true, false) as MeshInstance3D
        if tl:
            _thruster_l_mat = StandardMaterial3D.new()
            _thruster_l_mat.albedo_color               = Color(0.5, 0.75, 1.0, 0.9)
            _thruster_l_mat.emission_enabled           = true
            _thruster_l_mat.emission                   = Color(0.4, 0.65, 1.0)
            _thruster_l_mat.emission_energy_multiplier = 4.0
            _thruster_l_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
            _thruster_l_mat.cull_mode                  = BaseMaterial3D.CULL_DISABLED
            tl.material_override = _thruster_l_mat
        if tr:
            _thruster_r_mat = _thruster_l_mat.duplicate() as StandardMaterial3D if _thruster_l_mat else null
            if tr and _thruster_r_mat:
                tr.material_override = _thruster_r_mat

# ── Animation ──────────────────────────────────────────────────
func _animate_descent() -> void:
    if _s3_active:
        _animate_ship_3d()
        return
    if _ship2d_active:
        _animate_ship_2d()
        return
    if _ship3d_node:
        # 3D descent: ship drops from above onto planet surface
        _ship3d_node.position.y = 1.8
        var tween := create_tween()
        tween.tween_property(_ship3d_node, "position:y", 0.25, 2.0) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        if _is_ufo_landing:
            # UFO: หมุนช้าๆ บนแกน Y — ดูเป็นจานบินลงจอด
            var rot_tween := create_tween()
            rot_tween.tween_property(_ship3d_node, "rotation_degrees:y", 30.0, 2.0) \
                .set_trans(Tween.TRANS_SINE)
        elif _is_special_landing:
            # Special: เอียงปีก + หมุนเล็กน้อยบน Y — landing ดูเท่
            var rot_tween := create_tween()
            rot_tween.tween_property(_ship3d_node, "rotation_degrees:z", 3.5, 2.0) \
                .set_trans(Tween.TRANS_SINE)
        else:
            # Rocket: เอียงเล็กน้อยตอนลงจอด
            var rot_tween := create_tween()
            rot_tween.tween_property(_ship3d_node, "rotation_degrees:z", 2.5, 2.0) \
                .set_trans(Tween.TRANS_SINE)
        # Thruster glow pulse
        _pulse_thrusters()
    else:
        # 2D fallback
        ship_sprite.position.y -= 80.0
        var tween := create_tween()
        tween.tween_property(ship_sprite, "position:y", ship_sprite.position.y + 80.0, 1.4) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
        thruster_glow.modulate.a = 0.4
        var glow_tween := create_tween().set_loops()
        glow_tween.tween_property(thruster_glow, "modulate:a", 1.0, 0.25)
        glow_tween.tween_property(thruster_glow, "modulate:a", 0.4, 0.25)

func _pulse_thrusters() -> void:
    var has_glow := (_thruster_l_mat != null or _ufo_engine_mat != null
                     or _spc_nozzle_l_mat != null)
    if not has_glow:
        return
    var lo := 8.0 if _is_special_landing else 5.0   # Special nozzles brighter baseline
    var hi := 16.0 if _is_special_landing else 5.0
    var t := create_tween().set_loops()
    t.tween_method(_set_thruster_energy, hi, lo, 0.3)
    t.tween_method(_set_thruster_energy, lo, hi, 0.3)

func _set_thruster_energy(val: float) -> void:
    if _thruster_l_mat:    _thruster_l_mat.emission_energy_multiplier    = val
    if _thruster_r_mat:    _thruster_r_mat.emission_energy_multiplier    = val
    if _ufo_engine_mat:    _ufo_engine_mat.emission_energy_multiplier    = val
    if _spc_nozzle_l_mat:  _spc_nozzle_l_mat.emission_energy_multiplier = val
    if _spc_nozzle_r_mat:  _spc_nozzle_r_mat.emission_energy_multiplier = val

func _on_advance() -> void:
    GameManager.go_to_scene("win")


# ==============================================================
#  Landing FX — ดาวใหญ่มีแสงเรือง, ลำไอพ่นฟ้า-ขาว, เมฆฝุ่น, ประกายไฟ
# ==============================================================
const PLANET_CENTER_Y    := 330.0
const PLANET_RECT        := 640.0    # ดาวทั่วไป: ตัวดาว ≈ 0.8 ของกรอบ
const PLANET_RECT_SATURN := 1420.0   # ดาวเสาร์: กรอบรวมวงแหวน
const CLOUD_TOP_BACK     := 650.0
const CLOUD_TOP_FRONT    := 575.0
const JET_GROUND_Y       := 815.0

func _planet_color() -> Color:
    return Color.html(str(GameManager.selected_planet.get("color_hex", "#c8a070")))

func _fx_tex(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return load(path) as Texture2D
    var img := Image.load_from_file(ProjectSettings.globalize_path(path))
    return ImageTexture.create_from_image(img) if img else null

func _soft_dot(sz: int = 32) -> Texture2D:
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

# แสงเรืองรอบดาวปลายทาง (สีตามดาว)
func _add_planet_halo(planet_id: String) -> void:
    var c := _planet_color().lightened(0.25)
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(c.r, c.g, c.b, 0.55), Color(c.r, c.g, c.b, 0.22), Color(c.r, c.g, c.b, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
    var t := GradientTexture2D.new()
    t.gradient = g
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to = Vector2(1.0, 0.5)
    t.width = 256
    t.height = 256
    var halo := TextureRect.new()
    halo.name = "PlanetHalo"
    halo.texture = t
    halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var ball_d: float = 360.0 if planet_id == "saturn" else PLANET_RECT * 0.8
    var hs: float = ball_d * 1.7
    halo.position = Vector2(960.0 - hs * 0.5, PLANET_CENTER_Y - hs * 0.5)
    halo.size = Vector2(hs, hs)
    add_child(halo)
    move_child(halo, planet_sky.get_index())   # อยู่หลังดาว

func _build_landing_fx() -> void:
    var _tint := Color.WHITE.lerp(_planet_color().lightened(0.30), 0.32)
    if surface.has_node("SurfaceRidge"):
        surface.get_node("SurfaceRidge").hide()   # ขอบแข็งของพื้นผิว — ให้เมฆกลืนเส้นขอบฟ้าแทน
    # ── ลำไอพ่น (อยู่หลังตัวยาน) ──
    var jet_tex := _fx_tex("res://assets/ui/landing_jet.png")
    var n_jets: int = _jet_markers.size() if _s3_active else (_nozzles.size() if _ship2d_active else (maxi(_engine_nodes.size(), 1) if _ship3d_container else 0))
    for i in n_jets:
        var j := Sprite2D.new()
        j.texture = jet_tex
        j.centered = false
        j.offset = Vector2(-96, 0)   # จุดยึด = กึ่งกลางด้านบน (ปากท่อไอพ่น)
        var mat := CanvasItemMaterial.new()
        mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        j.material = mat
        if _s3_active:
            j.self_modulate = _s3_cfg["tint"]
        elif _ship2d_active:
            j.self_modulate = SHIP2D_JET_TINT[_ship2d_idx]
        add_child(j)
        _jets.append(j)
    # (เอาเมฆฝุ่นภาพนิ่งออกแล้ว — ใช้ควันแบบ animation จาก particle แทน)
    # ไอพ่น + ยาน อยู่หน้าเมฆชั้นหลัง (แสงไอพ่นส่องทับเมฆ) แต่หลังเมฆชั้นหน้า
    for j in _jets:
        move_child(j, get_child_count() - 1)
    if _ship3d_container:
        move_child(_ship3d_container, get_child_count() - 1)
    if _ship2d_active:
        move_child(ship_sprite, get_child_count() - 1)
    # แสงเรืองตรงที่ไอพ่นกระทบเมฆ
    var splash := Sprite2D.new()
    splash.texture = _soft_dot(128)
    splash.position = Vector2(960, JET_GROUND_Y)
    splash.scale = Vector2(3.6, 1.6)
    splash.modulate = Color(0.75, 0.9, 1.0, 0.75)
    var spm := CanvasItemMaterial.new()
    spm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    splash.material = spm
    add_child(splash)
    _splash = splash
    var stw := splash.create_tween().set_loops()
    stw.tween_property(splash, "modulate:a", 0.45, 0.35)
    stw.tween_property(splash, "modulate:a", 0.8, 0.35)
    # ประกายไฟ/ฝุ่นจากไอพ่นกระทบพื้น
    var sparks := CPUParticles2D.new()
    sparks.texture = _soft_dot(16)
    sparks.amount = 110
    sparks.lifetime = 1.3
    sparks.position = Vector2(960, JET_GROUND_Y)
    sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    sparks.emission_rect_extents = Vector2(120, 10)
    sparks.direction = Vector2(0, -1)
    sparks.spread = 75.0
    sparks.initial_velocity_min = 120.0
    sparks.initial_velocity_max = 380.0
    sparks.gravity = Vector2(0, 260)
    sparks.scale_amount_min = 0.25
    sparks.scale_amount_max = 0.7
    var ramp := Gradient.new()
    ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1.0, 0.75, 0.35, 0.9), Color(1.0, 0.45, 0.15, 0.0)])
    sparks.color_ramp = ramp
    var smat := CanvasItemMaterial.new()
    smat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    sparks.material = smat
    add_child(sparks)
    _sparks = sparks
    if _s3_active:
        sparks.position.y = LAND_GROUND_Y + 30.0
        splash.position.y = LAND_GROUND_Y + 30.0
    # ละอองประกายสีทองลอยเหนือเมฆ
    var embers := CPUParticles2D.new()
    embers.texture = _soft_dot(16)
    embers.amount = 90
    embers.lifetime = 4.0
    embers.preprocess = 4.0
    embers.position = Vector2(960, 760)
    embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    embers.emission_rect_extents = Vector2(980, 200)
    embers.direction = Vector2(0, -1)
    embers.spread = 30.0
    embers.initial_velocity_min = 10.0
    embers.initial_velocity_max = 40.0
    embers.gravity = Vector2.ZERO
    embers.scale_amount_min = 0.12
    embers.scale_amount_max = 0.35
    var er := Gradient.new()
    er.colors = PackedColorArray([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.85, 0.5, 0.9), Color(1.0, 0.7, 0.4, 0.0)])
    er.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
    embers.color_ramp = er
    var emat := CanvasItemMaterial.new()
    emat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    embers.material = emat
    add_child(embers)
    if _s3_active:
        _build_smoke_fx()   # ควันฝุ่นอยู่หน้าเมฆ (เห็นชัดตอนพวยพุ่ง)
    # ข้อความ + ป้ายข้อเท็จจริง อยู่บนสุด
    for n in [title_label, sub_label, fact_badge]:
        move_child(n, get_child_count() - 1)

# ลำไอพ่นตามตำแหน่งท่อไอพ่นของยาน 3D (แปลงพิกัด 3D → จอ)
func _update_jets() -> void:
    if _s3_active:
        _update_jets_3d()
        return
    if _ship2d_active:
        _update_jets_2d()
        return
    if _jets.is_empty() or _ship_cam == null or _ship3d_container == null:
        return
    var vp_sz := Vector2(_ship3d_viewport.size)
    var k := _ship3d_container.size / vp_sz
    for i in _jets.size():
        var j := _jets[i]
        var p2: Vector2
        if i < _engine_nodes.size() and is_instance_valid(_engine_nodes[i]):
            p2 = _ship_cam.unproject_position(_engine_nodes[i].global_position)
        else:
            p2 = _ship_cam.unproject_position(_ship3d_node.global_position)
        var pos := _ship3d_container.position + p2 * k
        j.position = pos
        var single := _jets.size() == 1
        var len_px := maxf(JET_GROUND_Y + 60.0 - pos.y, 120.0)
        var flick := randf_range(0.92, 1.08)
        j.scale = Vector2((1.5 if single else 1.1) * flick, len_px / 512.0 * randf_range(0.96, 1.04))
        j.modulate.a = randf_range(0.85, 1.0)



# ==============================================================
#  ยาน 2D ตอนลงจอด — รูปยานเดียวกับหน้าเลือกตัวละคร + ไอพ่นพุ่งลงจากใต้ยาน
#  (ตามภาพอ้างอิง: Comet ไอพ่นใต้ขา 4 จุด, Explorer ใต้ท้อง 3 จุด, Wing ใต้ลำตัว 2 จุด)
# ==============================================================
const SHIP2D_TEX: Array[String] = [
    "res://assets/ui/ship_one_explorer_icon.png",
    "res://assets/ui/ship_two_wing_icon.png",
    "res://assets/ui/ship_three_comet_icon.png",
]
const SHIP2D_WIDTH: Array[float] = [460.0, 500.0, 360.0]
# จุดปล่อยไอพ่น (สัดส่วนบนรูปยาน 0..1)
const SHIP2D_NOZZLES: Array = [
    [Vector2(0.32, 0.92), Vector2(0.50, 0.95), Vector2(0.68, 0.88)],
    [Vector2(0.40, 0.78), Vector2(0.62, 0.80)],
    [Vector2(0.12, 0.92), Vector2(0.37, 0.87), Vector2(0.66, 0.96), Vector2(0.91, 0.90)],
]
const SHIP2D_JET_TINT: Array[Color] = [
    Color(0.80, 0.95, 1.00),   # Explorer: ฟ้าขาว
    Color(1.00, 0.92, 0.80),   # Wing: ขาวอมส้ม
    Color(1.00, 0.82, 0.55),   # Comet: ส้มเหลือง
]
const SHIP2D_HOVER_Y := 520.0     # ตำแหน่งยานตอนลอยเหนือเมฆ (กึ่งกลางรูป)

var _ship2d_active: bool = false
var _ship2d_idx: int = 0
var _nozzles: Array = []

func _setup_ship_2d(avatar: int) -> void:
    _ship2d_idx = clampi(avatar, 0, SHIP2D_TEX.size() - 1)
    var tex := _fx_tex(SHIP2D_TEX[_ship2d_idx])
    if tex == null:
        return
    _ship2d_active = true
    thruster_glow.hide()
    ship_sprite.show()
    ship_sprite.texture = tex
    ship_sprite.centered = true
    var sc: float = SHIP2D_WIDTH[_ship2d_idx] / float(tex.get_width())
    ship_sprite.scale = Vector2(sc, sc)
    ship_sprite.position = Vector2(960, SHIP2D_HOVER_Y)
    _nozzles = SHIP2D_NOZZLES[_ship2d_idx]

func _animate_ship_2d() -> void:
    # ร่อนลงจากด้านบน แล้วลอยโยกเบา ๆ เหนือเมฆ
    var start_y := SHIP2D_HOVER_Y - 300.0
    ship_sprite.position.y = start_y
    ship_sprite.rotation = deg_to_rad(-4.0)
    var tw := create_tween()
    tw.tween_property(ship_sprite, "position:y", SHIP2D_HOVER_Y, 2.0) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(ship_sprite, "rotation", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
    tw.tween_callback(func():
        var bob := ship_sprite.create_tween().set_loops()
        bob.tween_property(ship_sprite, "position:y", SHIP2D_HOVER_Y - 10.0, 0.9).set_trans(Tween.TRANS_SINE)
        bob.tween_property(ship_sprite, "position:y", SHIP2D_HOVER_Y, 0.9).set_trans(Tween.TRANS_SINE))

# ไอพ่นตามจุดใต้ยาน (หมุน/เลื่อนตามรูปยาน)
func _update_jets_2d() -> void:
    if _jets.is_empty() or ship_sprite.texture == null:
        return
    var tsz := Vector2(ship_sprite.texture.get_size()) * ship_sprite.scale
    var many := _nozzles.size() >= 3
    for i in _jets.size():
        var j := _jets[i]
        var n: Vector2 = _nozzles[mini(i, _nozzles.size() - 1)]
        var local := (n - Vector2(0.5, 0.5)) * tsz
        var pos := ship_sprite.position + local.rotated(ship_sprite.rotation)
        j.position = pos
        var len_px := maxf(JET_GROUND_Y + 60.0 - pos.y, 140.0)
        var flick := randf_range(0.90, 1.10)
        j.scale = Vector2((0.62 if many else 0.80) * flick, len_px / 512.0 * randf_range(0.95, 1.05))
        j.modulate.a = randf_range(0.85, 1.0)


# ==============================================================
#  ยาน 3D ชุดใหม่ (assets/models/ships) — ลงจอดจริงแบบ 3D
#  • ไอพ่นเฉพาะของแต่ละลำ (ตำแหน่งท่อ/จำนวน/สี ตามโมเดล)
#  • ควันฝุ่นพวยพุ่งตอนไอพ่นกระทบพื้น + ระเบิดฝุ่นตอนแตะพื้น
#  • ค้างหน้า landing ไว้ HOLD_SECONDS วินาที แล้วจึงไปหน้าผลลัพธ์
# ==============================================================
const HOLD_SECONDS   := 10.0
const SMOKE_TEX      := "res://assets/ui/landing_smoke_puff.png"
const CAM_Z          := 10.0
const CAM_FOV        := 30.0
const LAND_GROUND_Y  := 785.0    # ระดับพื้น (พิกัดจอ) ที่ฐานยานแตะตอนลงจอด
const T_DESCENT      := 3.2      # ร่อนลงจากฟ้าจนลอยนิ่งเหนือพื้น
const T_SETTLE       := 1.1      # ค่อย ๆ หย่อนตัวจนแตะพื้น
const T_ENGINE_OFF   := 1.3      # ไอพ่นค่อย ๆ ดับหลังแตะพื้น

# jets = จุดปากท่อไอพ่น (พิกัดในโมเดล), jet_w = ความกว้างลำไอพ่น
# bottom = จุดต่ำสุดของโมเดล (ใช้วางให้ฐานยานแตะพื้นพอดี)
const SHIPS3D: Array = [
    {   # 0 Explorer (ship1) — แผ่นไอพ่นใหญ่ใต้ท้อง + บูสเตอร์ท้าย 2 ตัว
        "path": "res://assets/models/ships/ship1.glb",
        "scale": 0.60, "yaw": -118.0, "pitch": 9.0, "bottom": -0.99,
        "jets": [Vector3(0.0, -0.92, -0.30), Vector3(0.42, -0.46, 1.35), Vector3(-0.42, -0.46, 1.35)],
        "jet_w": [1.30, 0.62, 0.62],
        "tint": Color(1.00, 0.82, 0.52),
        "flames": "BoosterFlames",
    },
    {   # 1 Wing (ship2) — เครื่องยนต์คู่ใต้ปีก
        "path": "res://assets/models/ships/ship2.glb",
        "scale": 0.50, "yaw": -118.0, "pitch": 9.0, "bottom": -0.44,
        "jets": [Vector3(0.64, -0.36, 1.15), Vector3(-0.64, -0.36, 1.15)],
        "jet_w": [0.90, 0.90],
        "tint": Color(1.00, 0.74, 0.94),
        "flames": "EngineFlames",
    },
    {   # 2 Comet pod (ship3) — เครื่องยนต์หลักกลางฐาน ระหว่างขาลงจอด 4 ขา
        "path": "res://assets/models/ships/ship3.glb",
        "scale": 0.76, "yaw": 156.0, "pitch": 7.0, "bottom": -0.02,
        "jets": [Vector3(0.0, 0.17, 0.0)],
        "jet_w": [1.75],
        "tint": Color(1.00, 0.84, 0.52),
        "flames": "",
    },
]

var _s3_active: bool = false
var _s3_cfg: Dictionary = {}
var _s3_ship: Node3D = null
var _jet_markers: Array[Node3D] = []
var _flame_nodes: Array[GeometryInstance3D] = []
var _jet_light: OmniLight3D = null
var _jet_power: float = 1.0
var _landed: bool = false
var _sparks: CPUParticles2D = null
var _splash: Sprite2D = null
var _smoke_jet: Array[CPUParticles2D] = []
var _smoke_linger: CPUParticles2D = null

func _px_per_unit() -> float:
    return 1080.0 / (2.0 * CAM_Z * tan(deg_to_rad(CAM_FOV * 0.5)))

func _screen_to_world_y(y: float) -> float:
    return (540.0 - y) / _px_per_unit()

func _setup_ship_3d(avatar: int) -> bool:
    var idx := clampi(avatar, 0, SHIPS3D.size() - 1)
    var cfg: Dictionary = SHIPS3D[idx]
    if not ResourceLoader.exists(cfg["path"]):
        return false
    var ps := load(cfg["path"]) as PackedScene
    if ps == null:
        return false
    _s3_active = true
    _s3_cfg = cfg
    _ship2d_idx = idx
    ship_sprite.hide()
    thruster_glow.hide()

    # SubViewport เต็มจอ → พิกัดจอ = พิกัดใน viewport (คำนวณตำแหน่งไอพ่นง่าย)
    var cont := SubViewportContainer.new()
    cont.stretch = true
    cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cont.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(cont)
    var vp := SubViewport.new()
    vp.size = Vector2i(1920, 1080)
    vp.transparent_bg = true
    vp.own_world_3d = true
    vp.msaa_3d = Viewport.MSAA_4X
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    cont.add_child(vp)
    var root := Node3D.new()
    vp.add_child(root)

    var cam := Camera3D.new()
    cam.position = Vector3(0.0, 0.0, CAM_Z)
    cam.fov = CAM_FOV
    cam.near = 0.1
    cam.far = 60.0
    root.add_child(cam)

    var we := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0, 0, 0, 0)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.62, 0.62, 0.78)
    env.ambient_light_energy = 0.55
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    we.environment = env
    root.add_child(we)

    var key := DirectionalLight3D.new()           # แสงหลัก อุ่น จากซ้ายบน-หน้า
    key.light_color = Color(1.0, 0.94, 0.84)
    key.light_energy = 1.5
    key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
    root.add_child(key)
    var rim := DirectionalLight3D.new()           # แสงขอบ สีตามดาวปลายทาง (จากด้านหลัง)
    rim.light_color = _planet_color().lightened(0.35)
    rim.light_energy = 1.1
    rim.rotation_degrees = Vector3(-20.0, 160.0, 0.0)
    root.add_child(rim)

    var pivot := Node3D.new()
    root.add_child(pivot)
    var ship := ps.instantiate() as Node3D
    ship.scale = Vector3.ONE * float(cfg["scale"])
    ship.rotation_degrees = Vector3(float(cfg["pitch"]), float(cfg["yaw"]), 0.0)
    pivot.add_child(ship)
    for p in cfg["jets"]:
        var m := Marker3D.new()
        m.position = p
        ship.add_child(m)
        _jet_markers.append(m)
    if str(cfg["flames"]) != "":
        var f := ship.find_child(str(cfg["flames"]), true, false) as GeometryInstance3D
        if f:
            _flame_nodes.append(f)
    # แสงไอพ่นส่องใต้ท้องยาน
    _jet_light = OmniLight3D.new()
    _jet_light.light_color = cfg["tint"]
    _jet_light.light_energy = 2.5
    _jet_light.omni_range = 4.0
    _jet_light.position = Vector3(0.0, float(cfg["bottom"]) * float(cfg["scale"]) - 0.6, 0.6)
    pivot.add_child(_jet_light)

    _ship3d_container = cont
    _ship3d_viewport = vp
    _ship_cam = cam
    _ship3d_node = pivot
    _s3_ship = ship
    return true

func _animate_ship_3d() -> void:
    var ppu := _px_per_unit()
    var land_y := _screen_to_world_y(LAND_GROUND_Y) - float(_s3_cfg["bottom"]) * float(_s3_cfg["scale"])
    var hover_y := land_y + 120.0 / ppu
    _ship3d_node.position = Vector3(-1.4, land_y + 900.0 / ppu, 0.0)
    _ship3d_node.rotation_degrees = Vector3(0.0, 0.0, 9.0)
    var tw := create_tween()
    tw.tween_property(_ship3d_node, "position", Vector3(0.0, hover_y, 0.0), T_DESCENT) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(_ship3d_node, "rotation_degrees:z", 0.0, T_DESCENT) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_callback(_start_jet_smoke).set_delay(1.2)
    tw.tween_interval(0.25)
    tw.tween_property(_ship3d_node, "position:y", land_y, T_SETTLE) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tw.tween_callback(_on_touchdown)
    # ยุบตัวเล็กน้อยตอนกระแทกพื้น แล้วเด้งกลับ
    tw.tween_property(_ship3d_node, "scale", Vector3(1.04, 0.94, 1.04), 0.08)
    tw.tween_property(_ship3d_node, "scale", Vector3.ONE, 0.45) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    # ไอพ่นดับ
    tw.tween_method(_set_jet_power, 1.0, 0.0, T_ENGINE_OFF) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
    tw.tween_callback(_on_engine_off)

func _set_jet_power(v: float) -> void:
    _jet_power = v

func _start_jet_smoke() -> void:
    for s in _smoke_jet:
        s.emitting = true

func _on_touchdown() -> void:
    _landed = true
    if _s3_ship:
        _s3_ship.rotation_degrees.z = 0.0
        _s3_ship.rotation_degrees.x = float(_s3_cfg["pitch"])
    # ระเบิดฝุ่นออกสองข้าง
    for dir_x in [-1.0, 1.0]:
        var b := _make_smoke(dir_x, true)
        add_child(b)
        move_child(b, title_label.get_index())   # หน้ายาน แต่อยู่ใต้ข้อความ
        b.emitting = true
        get_tree().create_timer(b.lifetime + 0.5).timeout.connect(b.queue_free)
    if _smoke_linger:
        _smoke_linger.emitting = true
    # เขย่าจอเบา ๆ
    var sh := create_tween()
    for i in 5:
        sh.tween_property(self, "position", Vector2(randf_range(-7, 7), randf_range(-5, 5)), 0.04)
    sh.tween_property(self, "position", Vector2.ZERO, 0.06)
    title_label.text = "ลงจอดสำเร็จ!"
    title_label.pivot_offset = title_label.size * 0.5
    var tp := create_tween()
    tp.tween_property(title_label, "scale", Vector2(1.15, 1.15), 0.12)
    tp.tween_property(title_label, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_engine_off() -> void:
    for s in _smoke_jet:
        s.emitting = false
    if _sparks:
        _sparks.emitting = false
    if _splash:
        var t := _splash.create_tween()
        t.tween_property(_splash, "modulate:a", 0.0, 0.6)

func _smoke_color() -> Color:
    # ฝุ่นอมสีพื้นดาว แต่สว่างพอให้เห็นเป็นควันชัดเจน
    return Color(1.0, 0.98, 0.95).lerp(_planet_color().lightened(0.40), 0.26)

func _make_smoke(dir_x: float, burst: bool) -> CPUParticles2D:
    var p := CPUParticles2D.new()
    p.texture = _fx_tex(SMOKE_TEX)
    p.local_coords = false
    p.position = Vector2(960.0 + dir_x * (120.0 if burst else 70.0), LAND_GROUND_Y + 26.0)
    p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
    p.emission_rect_extents = Vector2(60, 10)
    p.direction = Vector2(dir_x, -0.10)
    p.spread = 12.0
    p.angle_min = -180.0
    p.angle_max = 180.0
    p.angular_velocity_min = -28.0
    p.angular_velocity_max = 28.0
    p.gravity = Vector2(0, -18)
    var c := _smoke_color()
    var ramp := Gradient.new()
    ramp.offsets = PackedFloat32Array([0.0, 0.10, 0.55, 1.0])
    ramp.colors = PackedColorArray([Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, 0.85),
        Color(c.r * 0.97, c.g * 0.97, c.b * 0.97, 0.55), Color(c.r * 0.94, c.g * 0.94, c.b * 0.94, 0.0)])
    p.color_ramp = ramp
    var curve := Curve.new()
    curve.add_point(Vector2(0.0, 0.45))
    curve.add_point(Vector2(1.0, 1.0))
    p.scale_amount_curve = curve
    if burst:
        p.one_shot = true
        p.explosiveness = 0.88
        p.amount = 34
        p.lifetime = 3.4
        p.initial_velocity_min = 260.0
        p.initial_velocity_max = 560.0
        p.damping_min = 160.0
        p.damping_max = 240.0
        p.scale_amount_min = 0.75
        p.scale_amount_max = 1.35
    else:
        p.amount = 40
        p.lifetime = 2.6
        p.initial_velocity_min = 160.0
        p.initial_velocity_max = 420.0
        p.damping_min = 90.0
        p.damping_max = 150.0
        p.scale_amount_min = 0.5
        p.scale_amount_max = 1.0
    p.emitting = false
    return p

func _build_smoke_fx() -> void:
    # ควันจากไอพ่นกระทบพื้น (สองข้าง) — เริ่มเมื่อยานใกล้พื้น หยุดเมื่อไอพ่นดับ
    for dir_x in [-1.0, 1.0]:
        var s := _make_smoke(dir_x, false)
        add_child(s)
        _smoke_jet.append(s)
    # ฝุ่นที่ค่อย ๆ ลอยอ้อยอิ่งหลังลงจอด (ทำให้ฉากยังมีชีวิตระหว่างค้างหน้า)
    _smoke_linger = _make_smoke(1.0, false)
    _smoke_linger.amount = 24
    _smoke_linger.lifetime = 5.5
    _smoke_linger.direction = Vector2(0, -1)
    _smoke_linger.spread = 70.0
    _smoke_linger.emission_rect_extents = Vector2(260, 14)
    _smoke_linger.position = Vector2(960, LAND_GROUND_Y + 25.0)
    _smoke_linger.initial_velocity_min = 12.0
    _smoke_linger.initial_velocity_max = 45.0
    _smoke_linger.damping_min = 0.0
    _smoke_linger.damping_max = 4.0
    _smoke_linger.scale_amount_min = 0.7
    _smoke_linger.scale_amount_max = 1.4
    var lc := _smoke_color()
    var lr := Gradient.new()
    lr.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
    lr.colors = PackedColorArray([Color(lc.r, lc.g, lc.b, 0.0), Color(lc.r, lc.g, lc.b, 0.6), Color(lc.r, lc.g, lc.b, 0.0)])
    _smoke_linger.color_ramp = lr
    add_child(_smoke_linger)

# ไอพ่น 2D ตามปากท่อของยาน 3D (unproject จากกล้อง) + ความแรงตาม _jet_power
func _update_jets_3d() -> void:
    if _ship_cam == null:
        return
    var on := _jet_power > 0.02
    var jw: Array = _s3_cfg["jet_w"]
    for i in _jets.size():
        var j := _jets[i]
        j.visible = on
        if not on or i >= _jet_markers.size():
            continue
        var pos := _ship_cam.unproject_position(_jet_markers[i].global_position)
        j.position = pos
        var flick := randf_range(0.92, 1.08)
        var ground := LAND_GROUND_Y + 50.0
        var len_px := maxf(ground - pos.y, 60.0) * (0.55 + 0.45 * _jet_power)
        j.scale = Vector2(float(jw[i]) * (0.45 + 0.55 * _jet_power) * flick,
            len_px / 512.0 * randf_range(0.95, 1.05))
        j.modulate.a = _jet_power * randf_range(0.85, 1.0)
    if _jet_light:
        _jet_light.light_energy = 2.5 * _jet_power * randf_range(0.85, 1.1)
    for f in _flame_nodes:
        f.transparency = clampf(1.0 - _jet_power * randf_range(0.8, 1.0), 0.0, 1.0)
    if _splash and _jets.size() > 0 and on:
        _splash.position = Vector2(_jets[0].position.x, LAND_GROUND_Y + 30.0)
    # ยานโยกเบา ๆ ตอนลอยอยู่ (ก่อนแตะพื้น)
    if _s3_ship and not _landed:
        _s3_ship.rotation_degrees.z = sin(_fx_t * 1.7) * 1.6
        _s3_ship.rotation_degrees.x = float(_s3_cfg["pitch"]) + sin(_fx_t * 1.3 + 0.6) * 1.2
