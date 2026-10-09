class_name Planet3DView
# ==============================================================
#  planet_3d_view.gd  —  Utility class (static methods)
#  สร้าง SubViewport ที่ render 3D planet model จาก .glb
#  ใช้ร่วมกันใน planet_node.gd, planet_select.gd, landing.gd
# ==============================================================

# ── ระยะกล้องต่อดาว (Blender radius × 3.0) ──────────────────────
const CAM_DIST: Dictionary = {
    "sun":     9.0,
    "mercury": 1.05,
    "venus":   1.65,
    "earth":   1.90,
    "moon":    0.55,
    "mars":    1.35,
    "jupiter": 4.85,
    "saturn":  9.70,   # ใช้ ring radius เป็น reference
    "uranus":  3.05,
    "neptune": 2.90,
    "pluto":   0.75,
}

# ── ขนาด SubViewport (pixel) สำหรับ planet_node บน solar map ──
const MAP_VP_SIZE: Dictionary = {
    "moon":    Vector2i(64,  64),
    "mercury": Vector2i(72,  72),
    "venus":   Vector2i(112, 112),
    "earth":   Vector2i(126, 126),
    "mars":    Vector2i(86,  86),
    "jupiter": Vector2i(256, 256),
    "saturn":  Vector2i(344, 344),
    "uranus":  Vector2i(158, 158),
    "neptune": Vector2i(155, 155),
    "pluto":   Vector2i(54,  54),
}

# ── มุมเอียงกล้องแต่ละดาว (องศา, มองจากด้านบนลงมา) ────────────
const CAM_TILT: Dictionary = {
    "saturn": 28.0,   # เอียงมากขึ้นเพื่อให้เห็น ring ชัด
}

# ==============================================================
# make_planet_vp — สร้าง SubViewport + 3D scene สำหรับดาวหนึ่งดวง
# คืนค่า: { vp: SubViewport, planet_node: Node3D }
# - scene_parent: node ที่ SubViewport จะถูก add_child() เข้าไป
# - planet_id: "earth", "mars", "saturn" ...
# - vp_size: ขนาด viewport เป็น pixel (Vector2i)
# - tilt_deg: มุมกล้องจากแนวราบ (ค่า default อ่านจาก CAM_TILT)
# ==============================================================
static func make_planet_vp(
        scene_parent: Node,
        planet_id:    String,
        vp_size:      Vector2i,
        tilt_deg:     float = -1.0,
) -> Dictionary:

    var glb_path := "res://assets/models/planets/%s.glb" % planet_id
    if not ResourceLoader.exists(glb_path):
        return {}

    # ── SubViewport ────────────────────────────────────────────
    var vp := SubViewport.new()
    vp.size                      = vp_size
    # ★ CRITICAL: ต้องมี world 3D เป็นของตัวเองเมื่อใช้ใน 2D scene
    # ถ้าไม่ตั้งค่านี้ SubViewport จะไม่มี 3D world → render ไม่ออก → ขาวทั้งหมด
    vp.own_world_3d              = true
    vp.transparent_bg            = true
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    scene_parent.add_child(vp)

    var root := Node3D.new()
    vp.add_child(root)

    # ── Environment ────────────────────────────────────────────
    var env_node := WorldEnvironment.new()
    var env      := Environment.new()
    env.background_mode  = Environment.BG_COLOR
    env.background_color = Color(0.0, 0.0, 0.0, 0.0)   # โปร่งใส
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color  = Color(0.20, 0.15, 0.35)
    env.ambient_light_energy = 0.4
    env.glow_enabled          = true
    env.glow_intensity        = 0.5
    env.glow_bloom            = 0.06
    env_node.environment      = env
    root.add_child(env_node)

    # ── Camera ─────────────────────────────────────────────────
    var actual_tilt: float = (tilt_deg if tilt_deg >= 0.0
        else float(CAM_TILT.get(planet_id, 15.0)))
    var d: float = float(CAM_DIST.get(planet_id, 3.0))
    var trad: float = deg_to_rad(actual_tilt)

    var cam := Camera3D.new()
    cam.fov     = 45.0
    cam.near    = 0.01
    cam.far     = 300.0
    cam.current = true   # ★ ระบุชัดเจนว่า camera นี้คือ active camera ของ viewport
    cam.position = Vector3(0.0, sin(trad) * d, cos(trad) * d)
    root.add_child(cam)
    # ★ look_at() ต้องเรียกหลัง add_child() เพื่อให้ global_transform พร้อม
    cam.look_at(Vector3.ZERO, Vector3.UP)

    # ── Lights ─────────────────────────────────────────────────
    var sun_lt := DirectionalLight3D.new()
    sun_lt.light_color        = Color(1.0, 0.96, 0.88)
    sun_lt.light_energy       = 1.2   # ลดจาก 1.8 ป้องกัน overexpose
    sun_lt.rotation_degrees   = Vector3(-35.0, 45.0, 0.0)
    sun_lt.shadow_enabled     = false
    root.add_child(sun_lt)

    var fill_lt := OmniLight3D.new()
    fill_lt.light_color  = Color(0.30, 0.45, 0.85)
    fill_lt.light_energy = 0.35
    fill_lt.omni_range   = 30.0
    fill_lt.position     = Vector3(-3.0, 1.5, 4.0)
    root.add_child(fill_lt)

    # ── Planet GLB ─────────────────────────────────────────────
    var packed: PackedScene = load(glb_path)
    var planet_node := packed.instantiate() as Node3D
    planet_node.position = Vector3.ZERO
    root.add_child(planet_node)

    return {"vp": vp, "planet_node": planet_node}
