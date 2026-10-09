class_name Powerup3DView
# ==============================================================
#  powerup_3d_view.gd  —  Utility class (static methods)
#  สร้าง SubViewport ที่ render 3D powerup model จาก .glb
#  ใช้ใน powerup_base.gd (เหมือนกับ Planet3DView สำหรับดาวเคราะห์)
#
#  GLBs ที่รองรับ (export มาจาก Blender, centered at origin):
#    energy_tank   → ถังพลังงาน
#    mystery_box   → กล่องคำถาม
#    roman_shield  → โล่ป้องกัน
#    star          → ดาว (score)
# ==============================================================

# ── ระยะกล้องต่อ model ─────────────────────────────────────────
const CAM_DIST: Dictionary = {
	"energy_tank":  1.2,
	"mystery_box":  1.4,
	"roman_shield": 1.3,
	"star":         1.2,
}

# ── มุมเงยกล้อง (°) — สูงกว่า = มองจากด้านบนมากขึ้น ──────────
const CAM_TILT: Dictionary = {
	"energy_tank":  25.0,
	"mystery_box":  30.0,
	"roman_shield": 15.0,
	"star":         78.0,   # star แบน → มองจากเกือบบนตรงๆ
}

# ==============================================================
# make_powerup_vp — สร้าง SubViewport + 3D scene สำหรับ pickup ชิ้นหนึ่ง
# คืนค่า: { vp: SubViewport, model_node: Node3D }
#         คืน {} ถ้าโหลด GLB ไม่ได้
# ==============================================================
static func make_powerup_vp(
		scene_parent: Node,
		model_id:     String,
		vp_size:      Vector2i,
) -> Dictionary:

	var glb_path := "res://assets/models/powerups/%s.glb" % model_id
	if not ResourceLoader.exists(glb_path):
		push_warning("[Powerup3DView] ไม่พบ GLB: %s" % glb_path)
		return {}

	# ── SubViewport ─────────────────────────────────────────────
	var vp := SubViewport.new()
	vp.size                      = vp_size
	vp.own_world_3d              = true   # ★ world 3D เป็นของตัวเอง
	vp.transparent_bg            = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scene_parent.add_child(vp)

	var root := Node3D.new()
	vp.add_child(root)

	# ── Environment — สว่าง + สีสัน สไตล์ game item ────────────
	var env_node := WorldEnvironment.new()
	var env      := Environment.new()
	env.background_mode        = Environment.BG_COLOR
	env.background_color       = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source   = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color    = Color(1.0, 1.0, 1.0)
	env.ambient_light_energy   = 0.9
	env.glow_enabled           = true
	env.glow_intensity         = 0.9
	env.glow_bloom             = 0.12
	env_node.environment       = env
	root.add_child(env_node)

	# ── Camera ──────────────────────────────────────────────────
	var tilt  := float(CAM_TILT.get(model_id, 25.0))
	var dist  := float(CAM_DIST.get(model_id, 1.3))
	var trad  := deg_to_rad(tilt)

	var cam := Camera3D.new()
	cam.fov     = 45.0
	cam.near    = 0.01
	cam.far     = 50.0
	cam.current = true
	cam.position = Vector3(0.0, sin(trad) * dist, cos(trad) * dist)
	root.add_child(cam)
	cam.look_at(Vector3.ZERO, Vector3.UP)

	# ── Key light (จากบนซ้ายหน้า) ───────────────────────────────
	var key := DirectionalLight3D.new()
	key.light_color      = Color(1.0, 0.98, 0.90)
	key.light_energy     = 2.2
	key.rotation_degrees = Vector3(-40.0, 45.0, 0.0)
	key.shadow_enabled   = false
	root.add_child(key)

	# ── Fill light (สีน้ำเงิน จากด้านล่างขวา) ──────────────────
	var fill := OmniLight3D.new()
	fill.light_color  = Color(0.40, 0.50, 1.0)
	fill.light_energy = 1.0
	fill.omni_range   = 8.0
	fill.position     = Vector3(-1.0, 1.0, 1.5)
	root.add_child(fill)

	# ── Model GLB ───────────────────────────────────────────────
	var packed: PackedScene = load(glb_path)
	var model_node := packed.instantiate() as Node3D
	model_node.position = Vector3.ZERO
	root.add_child(model_node)

	return {"vp": vp, "model_node": model_node}
