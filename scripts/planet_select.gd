extends Node2D
# ==============================================================
#  planet_select.gd — Solar System Map (ระบบสุริยะ 9 ดวง)
#  วาง planet nodes ตามวงโคจรวงรีจริงจาก orbit_radius_px (PlanetData)
#  ตาม storyboard S-04 / ป๊อปอัพข้อมูลดาว S-05
# ==============================================================

@onready var info_panel:      PanelContainer = $UI/InfoPanel
@onready var planet_preview:  TextureRect = $UI/InfoPanel/InfoVBox/HeaderRow/PlanetPreview
@onready var planet_name_lbl: Label    = $UI/InfoPanel/InfoVBox/HeaderRow/NameCol/PlanetName
@onready var planet_en_lbl:   Label    = $UI/InfoPanel/InfoVBox/HeaderRow/NameCol/PlanetEN
@onready var distance_lbl:    Label    = $UI/InfoPanel/InfoVBox/Distance
@onready var temp_lbl:        Label    = $UI/InfoPanel/InfoVBox/Temperature
@onready var gravity_lbl:     Label    = $UI/InfoPanel/InfoVBox/Gravity
@onready var time_lbl:        Label    = $UI/InfoPanel/InfoVBox/TimeLimit
@onready var diff_lbl:        Label    = $UI/InfoPanel/InfoVBox/Difficulty
@onready var funfact_box:     PanelContainer = $UI/InfoPanel/InfoVBox/FunFactBox
@onready var funfact_lbl:     Label    = $UI/InfoPanel/InfoVBox/FunFactBox/FunFact
@onready var select_btn:      Button   = $UI/InfoPanel/InfoVBox/BtnRow/SelectButton
@onready var back_btn:        Button   = $UI/InfoPanel/InfoVBox/BtnRow/BackButton
@onready var back_menu_btn:   Button   = $UI/BackMenuButton
@onready var solar_map:       Node2D   = $SolarSystemMap
@onready var sun_sprite:      Sprite2D = $SolarSystemMap/Sun
@onready var sun_glow:        Sprite2D = $SolarSystemMap/SunGlow
@onready var sun_area:        Area2D   = $SolarSystemMap/SunArea
@onready var orbit_paths:     Node2D   = $SolarSystemMap/OrbitPaths
@onready var header_lbl:      Label    = $UI/HeaderLabel
@onready var sub_lbl:         Label    = $UI/SubLabel

const PLANET_SCENE := "res://scenes/ui/planet_node.tscn"

# ── 3D viewport references ─────────────────────────────────────
var _sun_3d:       Node3D    = null   # หมุนดวงอาทิตย์บนแผนที่
var _preview_vp:   SubViewport = null  # viewport ใน info panel
var _preview_3d:   Node3D    = null   # หมุน planet ใน info panel

# ── ตำแหน่งดวงอาทิตย์ + ค่าแปลง orbit_radius_px → พิกัดบนจอ ──────
const SUN_POS:        Vector2 = Vector2(270.0, 560.0)
const ORBIT_BASE:      float  = 220.0   # ระยะห่างขั้นต่ำจากดวงอาทิตย์ (ดวงจันทร์)
const ORBIT_SCALE:     float  = 4.0     # ขยายค่า orbit_radius_px จาก json
const ELLIPSE_FLATTEN:  float = 0.32    # ความแบนของวงรี (ry / rx)

# มุมวางแต่ละดาวรอบวงรี (องศา) เพื่อให้กระจายแนวตั้งสวยงามแบบ storyboard
# หมายเหตุ: "moon" ไม่อยู่ในวงโคจรรอบดวงอาทิตย์ — มันคือบริวารของโลก
# จึงถูกตัดออกจาก loop หลักและวางใกล้ "earth" แทน (ดู _build_solar_map)
const ANGLE_DEG: Dictionary = {
    # ดาวเคราะห์ชั้นใน สลับ บน/ล่าง (ซิกแซก) ไม่ให้ดาวและป้ายชื่อซ้อนกัน
    "mercury": -35.0, "venus": 30.0, "earth": -28.0, "mars": 24.0,
    "jupiter": -20.0, "saturn": 18.0, "uranus": -22.0, "neptune": 15.0, "pluto": -10.0,
}

# ── ดวงจันทร์ลอยเป็นบริวารข้างโลก ไม่ใช่วงโคจรรอบดวงอาทิตย์ ──
# อยู่ใกล้โลก + ป้ายชื่อของดวงจันทร์ถูกสลับไปไว้ด้านบน (ดู planet_node.gd)
# จึงไม่ทับป้ายชื่อของโลกที่อยู่ด้านล่างแม้จะอยู่ใกล้กันมาก
const MOON_OFFSET_PX:  float = 80.0   # ระยะห่างจากโลกบนจอ (พิกเซล)
const MOON_ANGLE_DEG:  float = -75.0  # มุมตำแหน่งของดวงจันทร์เทียบกับโลก (ขึ้น-ขวา ห่างจากศุกร์)

const DEFAULT_HIGHLIGHT := "moon"

var selected_planet_data: Dictionary = {}
var _planet_nodes: Dictionary = {}

func _ready() -> void:
    UITheme.apply_cosmos_bg(self)
    SoundManager.play_bgm("menu", 1.0)
    TouchInput.reset()
    info_panel.hide()
    _apply_styles()
    _setup_sun()
    _build_solar_map()
    _setup_planet_preview()
    select_btn.pressed.connect(_on_select_confirmed)
    back_btn.pressed.connect(func():
        SoundManager.play_sfx("btn_click")
        info_panel.hide()
        _clear_selection())   # ยกเลิก → ดาวกลับสู่สถานะเดิม ไม่กะพริบ
    back_menu_btn.pressed.connect(func():
        SoundManager.play_sfx("btn_click")
        GameManager.go_to_scene("attract"))


func _process(delta: float) -> void:
    if _sun_3d:
        _sun_3d.rotation.y    += 0.10 * delta   # ดวงอาทิตย์หมุนช้ามาก
    if _preview_3d:
        _preview_3d.rotation.y += 0.35 * delta   # ดาวใน info panel หมุนปานกลาง

# ─── Styles ───────────────────────────────────────────────────
func _apply_styles() -> void:
    _style_title()

    # หน้าต่างข้อมูลดาว — กรอบ assets/ui/mission_fail_frame.png (ขอบนีออนแดง) 1080×720
    info_panel.add_theme_stylebox_override("panel",
        _frame_box("res://assets/ui/mission_fail_frame.png", 145, 92, 135, 88))
    _center_fixed(info_panel, Vector2(1080, 720))
    _layout_info_stats()

    planet_name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
    planet_name_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)
    planet_en_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    planet_en_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_GREY)

    for lbl in [distance_lbl, temp_lbl, gravity_lbl, time_lbl]:
        lbl.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
    diff_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)

    funfact_box.add_theme_stylebox_override("panel",
        UITheme.make_panel_style(Color(0.25, 0.12, 0.40, 0.55), UITheme.C_BORDER_PURPLE, 14, 2, 16))
    funfact_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    funfact_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)

    UITheme.style_button(back_btn, UITheme.C_ACCENT_PURPLE, UITheme.C_TEXT_WHITE)
    UITheme.style_button(select_btn, UITheme.C_ACCENT_ORANGE, UITheme.C_TEXT_WHITE)
    for btn in [back_btn, select_btn]:
        btn.custom_minimum_size = Vector2(0, 72)

    _style_menu_pill()

# ─── ดวงอาทิตย์ ───────────────────────────────────────────────
func _setup_sun() -> void:
    var target_diam: float = 300.0
    sun_sprite.position = SUN_POS
    sun_area.position   = SUN_POS
    sun_area.input_event.connect(_on_sun_input_event)
    _build_sun_glow(target_diam)

    # ── 3D Sun ──
    var sz_i := Vector2i(int(target_diam), int(target_diam))
    var vd   := Planet3DView.make_planet_vp(solar_map, "sun", sz_i, 8.0)
    if false and not vd.is_empty():   # 3D sun ออกมาขาวจ้า → ใช้ดวงอาทิตย์ 2D แบบเรืองแสงแทน
        _sun_3d        = vd["planet_node"]
        sun_sprite.texture = (vd["vp"] as SubViewport).get_texture()
        sun_sprite.scale   = Vector2.ONE
    elif true:
        if not vd.is_empty():
            (vd["vp"] as SubViewport).queue_free()
        _build_sun_2d(target_diam)
    else:
        # fallback sprite
        var tex_path := "res://assets/sprites/ui/sun.png"
        if ResourceLoader.exists(tex_path):
            sun_sprite.texture = load(tex_path)
            var s: float = target_diam / float(sun_sprite.texture.get_width())
            sun_sprite.scale = Vector2(s, s)

func _on_sun_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _on_sun_tapped()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _on_sun_tapped()   # สำหรับ test บน PC

# ดวงอาทิตย์ไม่ใช่ปลายทางภารกิจ — กดดูข้อมูลได้อย่างเดียว กลับได้อย่างเดียว
func _on_sun_tapped() -> void:
    var data: Dictionary = {
        "id": "sun", "name_th": "ดวงอาทิตย์", "name_en": "The Sun",
        "distance_km": 149600000, "temperature_avg": 5505, "gravity": 274.0,
        "fun_fact": "ดวงอาทิตย์มีมวลกว่า 99.8% ของมวลทั้งระบบสุริยะ และมีขนาดใหญ่กว่าโลกถึง 1.3 ล้านเท่า!",
    }
    selected_planet_data = data
    SoundManager.play_sfx("btn_click")
    for pid in _planet_nodes:
        _planet_nodes[pid].set_selected(false)
    _populate_info(data)
    info_panel.show()

# ── Planet preview SubViewport ใน info panel ──────────────────
# สร้าง SubViewport เปล่าไว้ก่อน — texture จะถูกเปลี่ยนตอน _populate_info
func _setup_planet_preview() -> void:
    # สร้าง SubViewport เริ่มต้นด้วย Earth (placeholder)
    var sz_i := Vector2i(160, 160)
    var vd   := Planet3DView.make_planet_vp(info_panel, "earth", sz_i, 15.0)
    if not vd.is_empty():
        _preview_vp = vd["vp"]
        _preview_3d = vd["planet_node"]
        planet_preview.texture = _preview_vp.get_texture()
        planet_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

# ── ไอร้อนรอบดวงอาทิตย์: gradient วงรัศมีสีส้ม/เหลืองที่จางลงเรื่อยๆ + เอฟเฟกต์เต้นเบาๆ ──
# (sun.png เป็นวงกลมทึบไม่มี glow ในตัวภาพ ต้องสร้างไอร้อนแยกด้วยโค้ดเหมือน landing.gd)
func _build_sun_glow(sun_diam: float) -> void:
    var grad := Gradient.new()
    grad.colors  = PackedColorArray([
        Color(1.0, 0.88, 0.50, 0.80),
        Color(1.0, 0.62, 0.22, 0.38),
        Color(1.0, 0.42, 0.12, 0.0),
    ])
    grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])

    var glow_tex := GradientTexture2D.new()
    glow_tex.gradient   = grad
    glow_tex.fill       = GradientTexture2D.FILL_RADIAL
    glow_tex.fill_from  = Vector2(0.5, 0.5)
    glow_tex.fill_to    = Vector2(1.0, 0.5)
    glow_tex.width      = 512
    glow_tex.height     = 512

    sun_glow.texture  = glow_tex
    sun_glow.centered = true
    sun_glow.position = SUN_POS
    var glow_diam: float = sun_diam * 2.4
    sun_glow.scale = Vector2(glow_diam / 512.0, glow_diam / 512.0)

    # ไอร้อนสั่นเบาๆ ให้ดูเหมือนพลังงานพวยพุ่งออกมาตลอดเวลา
    var tween := create_tween().set_loops()
    tween.tween_property(sun_glow, "scale", sun_glow.scale * 1.18, 1.4) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(sun_glow, "scale", sun_glow.scale * 0.94, 1.4) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ─── Build map ────────────────────────────────────────────────
func _build_solar_map() -> void:
    var planet_scene: PackedScene = load(PLANET_SCENE)
    var radii: Array = []

    # ── ดาวเคราะห์ที่โคจรรอบดวงอาทิตย์จริง (ไม่รวมดวงจันทร์) ──
    for planet in PlanetData.planets:
        var pid: String = planet.get("id", "")
        if pid == "moon":
            continue   # ดวงจันทร์ไม่มีวงโคจรรอบดวงอาทิตย์ของตัวเอง — วางไว้ข้างโลกแทน

        var orbit_px: float = float(planet.get("orbit_radius_px", 0))
        var rx: float = ORBIT_BASE + orbit_px * ORBIT_SCALE
        var ry: float = rx * ELLIPSE_FLATTEN
        radii.append(Vector2(rx, ry))

        var angle_deg: float = ANGLE_DEG.get(pid, 0.0)
        var angle_rad: float = deg_to_rad(angle_deg)
        var offset := Vector2(cos(angle_rad) * rx, sin(angle_rad) * ry)

        var node: Area2D = planet_scene.instantiate()
        node.planet_id = pid
        node.position  = SUN_POS + offset
        node.planet_tapped.connect(_on_planet_tapped)
        solar_map.add_child(node)
        _planet_nodes[pid] = node

    # ── ดวงจันทร์: วางเป็นบริวารข้างโลก แทนวงโคจรรอบดวงอาทิตย์ ──
    if _planet_nodes.has("earth"):
        var earth_node: Area2D = _planet_nodes["earth"]
        var moon_angle_rad: float = deg_to_rad(MOON_ANGLE_DEG)
        var moon_offset := Vector2(cos(moon_angle_rad), sin(moon_angle_rad)) * MOON_OFFSET_PX

        var moon_node: Area2D = planet_scene.instantiate()
        moon_node.planet_id = "moon"
        moon_node.position  = earth_node.position + moon_offset
        moon_node.planet_tapped.connect(_on_planet_tapped)
        solar_map.add_child(moon_node)
        _planet_nodes["moon"] = moon_node

    orbit_paths.position = SUN_POS
    orbit_paths.set_radii(radii)

    # Highlight ดาวเริ่มต้น (ดวงจันทร์ - ภารกิจแรก) ตาม storyboard
    if _planet_nodes.has(DEFAULT_HIGHLIGHT):
        _planet_nodes[DEFAULT_HIGHLIGHT].set_selected(true)

# ยกเลิกการเลือกดาวทุกดวง (ไม่กะพริบ ไม่ไฮไลต์)
func _clear_selection() -> void:
    selected_planet_data = {}
    for pid in _planet_nodes:
        _planet_nodes[pid].set_selected(false)

# ─── Planet tapped ────────────────────────────────────────────
func _on_planet_tapped(planet_id: String) -> void:
    var data: Dictionary = PlanetData.get_planet(planet_id)
    if data.is_empty():
        return
    selected_planet_data = data
    SoundManager.play_sfx("btn_click")

    for pid in _planet_nodes:
        _planet_nodes[pid].set_selected(pid == planet_id)

    _populate_info(data)
    info_panel.show()

func _populate_info(data: Dictionary) -> void:
    var pid: String = data.get("id", "")

    # ── อัปเดต 3D preview planet ──
    _rebuild_preview(pid)

    # fallback texture (กรณี 3D ไม่โหลด)
    if planet_preview.texture == null:
        var tex_path := ("res://assets/sprites/ui/sun.png" if pid == "sun"
            else "res://assets/sprites/planets/%s.png" % pid)
        if ResourceLoader.exists(tex_path):
            planet_preview.texture = load(tex_path)

    planet_name_lbl.text = data.get("name_th", "")
    planet_en_lbl.text   = data.get("name_en", "")

    var dist: int = data.get("distance_km", 0)
    if dist >= 1_000_000_000:
        distance_lbl.text = "ระยะทาง: %.2f พันล้าน กม." % (dist / 1_000_000_000.0)
    elif dist >= 1_000_000:
        distance_lbl.text = "ระยะทาง: %.1f ล้าน กม." % (dist / 1_000_000.0)
    else:
        distance_lbl.text = "ระยะทาง: %s กม." % _fmt(dist)
    distance_lbl.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)

    temp_lbl.text = "อุณหภูมิเฉลี่ย: %d°C" % data.get("temperature_avg", 0)
    temp_lbl.add_theme_color_override("font_color", UITheme.C_ACCENT_BLUE)

    gravity_lbl.text = "แรงโน้มถ่วง: %.2f m/s²" % data.get("gravity", 0.0)
    gravity_lbl.add_theme_color_override("font_color", UITheme.C_ACCENT_GREEN)

    # ดวงอาทิตย์ไม่มีภารกิจ/เวลาจำกัด/ระดับความยาก — ซ่อนแถวที่ไม่เกี่ยวข้อง
    time_lbl.visible = pid != "sun"
    diff_lbl.visible = pid != "sun"
    if pid != "sun":
        # ใช้เวลาที่ admin ตั้งค่าไว้ (ถ้ามี) แทนค่า time_limit เดิมจาก planets.json
        # เพื่อให้ตรงกับเวลาที่ใช้จริงตอนเริ่มภารกิจ (ดู game_manager.gd)
        var tl: int = int(GameSettings.get_planet_time(pid, float(data.get("time_limit", 0))))
        @warning_ignore("integer_division")
        time_lbl.text = "เวลาจำกัด: %d:%02d" % [tl / 60, tl % 60]
        time_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)

        diff_lbl.text = data.get("difficulty_label", "")
        diff_lbl.add_theme_color_override("font_color",
            Color.html(data.get("difficulty_color", "#ffffff")))
    funfact_lbl.text = "💡 รู้หรือไม่? " + data.get("fun_fact", "")

    # โลก/ดวงอาทิตย์ ไม่ใช่ด่านภารกิจ — ดูข้อมูลได้ แต่กดรับภารกิจไม่ได้
    select_btn.visible = pid != "earth" and pid != "sun"

func _rebuild_preview(planet_id: String) -> void:
    # ลบ SubViewport เดิมก่อน (ถ้ามี)
    if _preview_vp and is_instance_valid(_preview_vp):
        _preview_vp.queue_free()
        _preview_vp = null
        _preview_3d = null
        planet_preview.texture = null
    if planet_preview.has_node("PreviewCorona"):
        planet_preview.get_node("PreviewCorona").free()

    # ดวงอาทิตย์: ใช้ภาพดวงอาทิตย์ 2D + เปลวไฟยืด-หด แบบเดียวกับบนแผนที่ (3D ออกมาขาวจ้า)
    if planet_id == "sun":
        planet_preview.texture = _make_sun_texture()
        planet_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        var corona := SunCorona.new()
        corona.name = "PreviewCorona"
        corona.show_behind_parent = true   # อยู่หลังตัวดวง
        planet_preview.add_child(corona)
        var rt := corona.create_tween().set_loops()
        rt.tween_property(corona, "rotation", TAU, 60.0).from(0.0)
        await get_tree().process_frame
        if is_instance_valid(corona):
            var sz := planet_preview.size
            corona.position = sz * 0.5
            corona.radius = minf(sz.x, sz.y) * 0.5 * 0.92
        return

    var sz_i := Vector2i(160, 160)
    var tilt := 28.0 if planet_id == "saturn" else 15.0
    var vd   := Planet3DView.make_planet_vp(info_panel, planet_id, sz_i, tilt)
    if not vd.is_empty():
        _preview_vp = vd["vp"]
        _preview_3d = vd["planet_node"]
        planet_preview.texture = _preview_vp.get_texture()
        planet_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

func _on_select_confirmed() -> void:
    if selected_planet_data.is_empty():
        return
    var sel_id: String = selected_planet_data.get("id", "")
    if sel_id == "earth" or sel_id == "sun":
        return   # โลก/ดวงอาทิตย์ ไม่ใช่ปลายทางภารกิจ
    SoundManager.play_sfx("btn_click")
    GameManager.start_mission(selected_planet_data)
    GameManager.go_to_scene("gameplay")

func _fmt(n: int) -> String:
    var s := str(n); var out := ""; var cnt := 0
    for i in range(s.length()-1,-1,-1):
        if cnt > 0 and cnt%3==0: out=","+out
        out=s[i]+out; cnt+=1
    return out


# ==============================================================
#  ดวงอาทิตย์ 2D — แกนขาวเหลือง → ขอบส้ม + เปลวไฟรอบดวง (ตามภาพอ้างอิง)
# ==============================================================
func _build_sun_2d(diam: float) -> void:
    sun_sprite.texture = _make_sun_texture()
    sun_sprite.scale = Vector2.ONE * (diam / 512.0)
    sun_sprite.modulate = Color.WHITE
    _add_sun_corona(diam)
    _add_sun_label(diam)

# ป้ายชื่อดวงอาทิตย์ — สไตล์เดียวกับป้ายดาวเคราะห์ (planet_node.gd) วางใต้ดวง แตะเพื่อดูข้อมูลได้
func _add_sun_label(diam: float) -> void:
    var tag := PanelContainer.new()
    tag.name = "SunLabelTag"
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.07, 0.05, 0.18, 0.80)
    sb.border_color = Color(1.00, 0.72, 0.30, 0.85)   # ขอบส้มทองให้เข้ากับดวงอาทิตย์
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(12)
    sb.content_margin_left = 14
    sb.content_margin_right = 14
    sb.content_margin_top = 2
    sb.content_margin_bottom = 4
    sb.shadow_color = Color(0, 0, 0, 0.35)
    sb.shadow_size = 4
    sb.anti_aliasing = true
    tag.add_theme_stylebox_override("panel", sb)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", -4)
    vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tag.add_child(vb)
    var name_lbl := Label.new()
    name_lbl.text = "ดวงอาทิตย์"
    name_lbl.add_theme_font_size_override("font_size", 24)
    name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
    name_lbl.add_theme_constant_override("outline_size", 10)
    name_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.08, 0.95))
    var sun_sub_lbl := Label.new()
    sun_sub_lbl.text = "ศูนย์กลางระบบสุริยะ"
    sun_sub_lbl.add_theme_font_size_override("font_size", 18)
    sun_sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.68, 0.30))
    sun_sub_lbl.add_theme_constant_override("outline_size", 8)
    sun_sub_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.08, 0.9))
    for l: Label in [name_lbl, sun_sub_lbl]:
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        vb.add_child(l)
    tag.mouse_filter = Control.MOUSE_FILTER_STOP
    tag.gui_input.connect(func(ev: InputEvent):
        if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
                or (ev is InputEventScreenTouch and ev.pressed):
            _on_sun_tapped())
    solar_map.add_child(tag)
    await get_tree().process_frame
    var sz: Vector2 = tag.get_combined_minimum_size()
    tag.size = sz
    # ใต้ตัวดวง (เลยปลายเปลวไฟเล็กน้อย)
    tag.position = SUN_POS + Vector2(-sz.x * 0.5, diam * 0.5 + 34.0)

# ภาพดวงอาทิตย์ (แกนขาวเหลือง → ขอบส้ม) — ใช้ทั้งบนแผนที่และในกล่องข้อมูล
func _make_sun_texture() -> Texture2D:
    var g := Gradient.new()
    g.colors = PackedColorArray([
        Color(1.00, 1.00, 0.94, 1.0),
        Color(1.00, 0.96, 0.70, 1.0),
        Color(1.00, 0.82, 0.38, 1.0),
        Color(1.00, 0.62, 0.18, 1.0),
        Color(1.00, 0.55, 0.12, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 0.45, 0.78, 0.96, 1.0])
    var t := GradientTexture2D.new()
    t.gradient = g
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to   = Vector2(1.0, 0.5)
    t.width = 512
    t.height = 512
    return t

func _add_sun_corona(diam: float) -> void:
    var corona := SunCorona.new()
    corona.radius = diam * 0.5
    corona.position = SUN_POS
    solar_map.add_child(corona)
    solar_map.move_child(corona, sun_sprite.get_index())   # อยู่หลังตัวดวง
    var rt := create_tween().set_loops()
    rt.tween_property(corona, "rotation", TAU, 60.0).from(0.0)

class SunCorona extends Node2D:
    # เปลวไฟรอบดวงอาทิตย์ — แต่ละแฉก "ยืดออก-หดลง" ด้วยจังหวะของตัวเอง
    var radius: float = 150.0
    var _flames: Array = []      # [angle, base_len, width, bend, speed, phase, layer]
    var _t: float = 0.0
    const LAYERS := [
        [64, 0.30, Color(1.0, 0.52, 0.14, 0.30)],
        [56, 0.20, Color(1.0, 0.66, 0.22, 0.40)],
        [48, 0.12, Color(1.0, 0.84, 0.40, 0.55)],
    ]
    func _ready() -> void:
        var rng := RandomNumberGenerator.new()
        rng.seed = 42
        for li in LAYERS.size():
            var n: int = LAYERS[li][0]
            for i in n:
                _flames.append([
                    TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(n),   # มุม
                    rng.randf_range(0.35, 1.0) * float(LAYERS[li][1]),         # ความยาวฐาน
                    TAU / float(n) * rng.randf_range(0.9, 1.4),                # ความกว้าง
                    rng.randf_range(-0.12, 0.12),                              # โค้งเล็กน้อย
                    rng.randf_range(1.2, 2.6),                                 # ความเร็วยืด-หด
                    rng.randf_range(0.0, TAU),                                 # เฟสเริ่ม
                    li])
    func _process(delta: float) -> void:
        _t += delta
        queue_redraw()
    func _draw() -> void:
        for f in _flames:
            var a: float = f[0]
            var w: float = f[2]
            var bend: float = f[3]
            # ยืดออก-หดลง: ความยาวแกว่งระหว่าง ~45% ถึง ~165% ของค่าฐาน
            var k: float = 1.05 + 0.60 * sin(_t * float(f[4]) + float(f[5]))
            var L: float = radius * (1.0 + float(f[1]) * k)
            var p0 := Vector2(cos(a - w), sin(a - w)) * radius * 0.92
            var p1 := Vector2(cos(a + bend), sin(a + bend)) * L
            var p2 := Vector2(cos(a + w), sin(a + w)) * radius * 0.92
            draw_colored_polygon(PackedVector2Array([Vector2.ZERO, p0, p1, p2]), LAYERS[f[6]][2])

# ==============================================================
#  หัวข้อ "เลือกดาวปลายทาง" — ไล่สีขาว→ม่วง + ขอบม่วงเข้ม + เงา (font เดิม)
# ==============================================================
const TITLE_SHADER := """
shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(1.00, 0.95, 1.00, 1.0);
uniform vec4 mid_col : source_color = vec4(0.88, 0.74, 1.00, 1.0);
uniform vec4 bot_col : source_color = vec4(0.62, 0.45, 0.98, 1.0);
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

func _style_title() -> void:
    var fs := 64
    header_lbl.anchor_top = 0.025
    header_lbl.anchor_bottom = 0.025
    header_lbl.add_theme_font_size_override("font_size", fs)
    header_lbl.add_theme_color_override("font_color", Color.WHITE)
    header_lbl.add_theme_color_override("font_outline_color", Color(0.19, 0.07, 0.36))
    header_lbl.add_theme_constant_override("outline_size", 16)
    header_lbl.add_theme_color_override("font_shadow_color", Color(0.06, 0.02, 0.16, 0.9))
    header_lbl.add_theme_constant_override("shadow_offset_x", 0)
    header_lbl.add_theme_constant_override("shadow_offset_y", 6)
    header_lbl.add_theme_constant_override("shadow_outline_size", 16)
    var mat := ShaderMaterial.new()
    var sh := Shader.new()
    sh.code = TITLE_SHADER
    mat.shader = sh
    var f := header_lbl.get_theme_font("font")
    if f:
        var asc := f.get_ascent(fs)
        mat.set_shader_parameter("y0", asc - fs * 0.80)
        mat.set_shader_parameter("y1", asc + fs * 0.10)
    header_lbl.material = mat

    sub_lbl.anchor_top = 0.105
    sub_lbl.anchor_bottom = 0.105
    sub_lbl.add_theme_font_size_override("font_size", 28)
    sub_lbl.add_theme_color_override("font_color", Color.WHITE)
    sub_lbl.add_theme_constant_override("outline_size", 8)
    sub_lbl.add_theme_color_override("font_outline_color", Color(0.10, 0.04, 0.24, 0.95))

# ── ปุ่ม "◀ เมนู" — แคปซูลม่วงลาเวนเดอร์ เรืองแสง ──
func _style_menu_pill() -> void:
    var base := Color(0.56, 0.46, 0.96)
    var edge := Color(0.24, 0.14, 0.55)
    var h := 58.0
    back_menu_btn.offset_top = -h * 0.5
    back_menu_btn.offset_bottom = h * 0.5
    back_menu_btn.offset_left = 24.0
    back_menu_btn.offset_right = 24.0 + 160.0
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
        sb.shadow_color = Color(0.65, 0.50, 1.0, 0.45)
        sb.shadow_size = 10
        sb.anti_aliasing = true
        sb.corner_detail = 12
        back_menu_btn.add_theme_stylebox_override(state, sb)
    back_menu_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        back_menu_btn.add_theme_color_override(k, Color.WHITE)
    back_menu_btn.add_theme_color_override("font_outline_color", edge)
    back_menu_btn.add_theme_constant_override("outline_size", 8)
    back_menu_btn.add_theme_font_size_override("font_size", 28)


# กรอบรูปภาพ (ยืดทั้งภาพให้พอดีกล่องขนาดคงที่ สัดส่วนเท่ารูป) + ระยะเนื้อหาด้านใน
func _frame_box(path: String, ml: float, mt: float, mr: float, mb: float) -> StyleBox:
    var tex: Texture2D = null
    if ResourceLoader.exists(path):
        tex = load(path) as Texture2D
    else:
        var img := Image.load_from_file(ProjectSettings.globalize_path(path))
        if img:
            tex = ImageTexture.create_from_image(img)
    if tex == null:
        return UITheme.make_panel_style(UITheme.C_BG_CARD, UITheme.C_BORDER_GOLD, UITheme.PANEL_RADIUS, 3, 30)
    var sb := StyleBoxTexture.new()
    sb.texture = tex
    sb.content_margin_left = ml
    sb.content_margin_top = mt
    sb.content_margin_right = mr
    sb.content_margin_bottom = mb
    return sb

func _center_fixed(ctrl: Control, sz: Vector2) -> void:
    ctrl.anchor_left = 0.5
    ctrl.anchor_right = 0.5
    ctrl.anchor_top = 0.5
    ctrl.anchor_bottom = 0.5
    ctrl.offset_left = -sz.x * 0.5
    ctrl.offset_right = sz.x * 0.5
    ctrl.offset_top = -sz.y * 0.5
    ctrl.offset_bottom = sz.y * 0.5

# ข้อมูล ระยะทาง/อุณหภูมิ/แรงโน้มถ่วง/เวลา จัดเป็น 2 คอลัมน์ ให้พอดีกรอบแนวนอน
func _layout_info_stats() -> void:
    var vbox := distance_lbl.get_parent() as VBoxContainer
    if vbox.has_node("StatsGrid"):
        return
    vbox.add_theme_constant_override("separation", 10)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    var g := GridContainer.new()
    g.name = "StatsGrid"
    g.columns = 2
    g.add_theme_constant_override("h_separation", 30)
    g.add_theme_constant_override("v_separation", 6)
    vbox.add_child(g)
    vbox.move_child(g, distance_lbl.get_index())
    for l: Label in [distance_lbl, temp_lbl, gravity_lbl, time_lbl]:
        l.reparent(g)
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    planet_preview.custom_minimum_size = Vector2(130, 130)
