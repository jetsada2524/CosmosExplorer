extends Area2D
# ==============================================================
#  planet_node.gd  —  attach กับ Area2D แต่ละดาวใน SolarSystemMap
#  ส่ง signal เมื่อถูกแตะ + แสดง 3D model จาก Blender + ป้ายความยาก
# ==============================================================

signal planet_tapped(planet_id: String)

@export var planet_id: String = ""

@onready var sprite:     Sprite2D = $Sprite2D
@onready var name_label: Label    = $NameLabel
@onready var diff_badge: Label    = $DiffBadge
@onready var glow:       Node2D   = $GlowEffect

# ── ขนาดแสดงผลตามสัดส่วนจริง (sqrt-compressed) ───────────────────
# Earth = 21px radius → ดาวอื่นคำนวณจาก real diameter^0.55
const PLANET_DISPLAY_RADIUS: Dictionary = {
    "moon":    7,   # 3,474 km
    "mercury": 9,   # 4,879 km
    "venus":   17,   # 12,104 km
    "earth":   18,   # 12,742 km (reference)
    "mars":    11,   # 6,779 km
    "jupiter": 45,   # 139,820 km (capped)
    "saturn":  39,   # 116,460 km (capped; rings shown in viewport)
    "uranus":  25,   # 50,724 km
    "neptune": 24,   # 49,244 km
    "pluto":    5,   # 2,377 km
}

var _planet_3d:    Node3D    = null
var _is_hovered:   bool      = false
var _is_selected:  bool      = false
var _rot_speed:    float     = 0.0   # rad/s

func _ready() -> void:
    input_event.connect(_on_input_event)
    mouse_entered.connect(func(): _set_hover(true))
    mouse_exited.connect(func():  _set_hover(false))
    _load_visual()

func _process(delta: float) -> void:
    if _planet_3d and _rot_speed != 0.0:
        _planet_3d.rotation.y += _rot_speed * delta

func _load_visual() -> void:
    var data: Dictionary = PlanetData.get_planet(planet_id)
    if data.is_empty():
        return

    name_label.text = data.get("name_th", planet_id)
    name_label.add_theme_font_size_override("font_size", 22)
    name_label.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)
    name_label.add_theme_constant_override("outline_size", 10)
    name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.08, 0.95))
    name_label.add_theme_constant_override("shadow_offset_x", 2)
    name_label.add_theme_constant_override("shadow_offset_y", 2)
    name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))

    diff_badge.text = data.get("difficulty_label", "")
    diff_badge.add_theme_font_size_override("font_size", 20)
    diff_badge.add_theme_color_override("font_color",
        Color.html(data.get("difficulty_color", "#ffffff")))
    diff_badge.add_theme_constant_override("outline_size", 8)
    diff_badge.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.08, 0.9))

    var radius_px: float = float(PLANET_DISPLAY_RADIUS.get(planet_id, 10))
    var vp_size: Vector2i = Planet3DView.MAP_VP_SIZE.get(planet_id, Vector2i(25, 25))

    var vp_data := Planet3DView.make_planet_vp(self, planet_id, vp_size)
    if vp_data.is_empty():
        # fallback: sprite 2D (ถ้าไม่มี GLB)
        var tex_path := "res://assets/sprites/planets/%s.png" % planet_id
        if ResourceLoader.exists(tex_path):
            sprite.texture = load(tex_path)
            var s: float = (radius_px * 2.0) / 1280.0 #1280.0
            sprite.scale = Vector2(s, s)
    else:
        var vp := vp_data["vp"] as SubViewport
        _planet_3d = vp_data["planet_node"]
        # ใช้ ViewportTexture กับ Sprite2D
        sprite.texture = vp.get_texture()
        sprite.scale   = Vector2.ONE
        # ความเร็วหมุนตามขนาด (ดาวเล็กหมุนเร็วกว่า ดาวใหญ่หมุนช้ากว่า)
        _rot_speed = remap(float(vp_size.x), 20.0, 150.0, 0.6, 0.15)

    _build_label_tag()

func _on_input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
    if event is InputEventScreenTouch and event.pressed:
        planet_tapped.emit(planet_id)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        planet_tapped.emit(planet_id)

func _set_hover(h: bool) -> void:
    _is_hovered = h
    var tween := create_tween()
    var scale_target := Vector2(1.15, 1.15) if h else Vector2(1.0, 1.0)
    tween.tween_property(self, "scale", scale_target, 0.15)

var _sel_tween: Tween = null   # tween กะพริบตอนถูกเลือก — ต้องหยุดเมื่อยกเลิกการเลือก

func set_selected(active: bool) -> void:
    _is_selected = active
    # หยุด tween กะพริบเดิมก่อนเสมอ (ไม่งั้นดาวจะกะพริบค้างแม้ยกเลิกการเลือกแล้ว)
    if _sel_tween and _sel_tween.is_valid():
        _sel_tween.kill()
    _sel_tween = null
    if active:
        sprite.modulate = Color(1.25, 1.25, 1.05)
        _sel_tween = create_tween().set_loops()
        _sel_tween.tween_property(sprite, "modulate:a", 0.7, 0.6)
        _sel_tween.tween_property(sprite, "modulate:a", 1.0, 0.6)
    else:
        sprite.modulate = Color(1, 1, 1, 1)   # กลับสู่สถานะปกติ


# ── ป้ายชื่อ + ความยาก อยู่ในกรอบมนสีเข้มโปร่งแสง (ตามภาพอ้างอิง) ──
const TAG_BG     := Color(0.07, 0.05, 0.18, 0.80)
const TAG_BORDER := Color(0.62, 0.52, 0.92, 0.75)

func _build_label_tag() -> void:
    var label_y: float = name_label.position.y      # ระยะใต้ดาว (จาก tscn)
    var tag := PanelContainer.new()
    tag.name = "LabelTag"
    tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var sb := StyleBoxFlat.new()
    sb.bg_color = TAG_BG
    sb.border_color = TAG_BORDER
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(12)
    sb.content_margin_left = 12
    sb.content_margin_right = 12
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
    for lbl: Label in [name_label, diff_badge]:
        remove_child(lbl)
        lbl.position = Vector2.ZERO
        lbl.custom_minimum_size = Vector2.ZERO
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if lbl.text != "":
            vb.add_child(lbl)
        else:
            lbl.queue_free()
    add_child(tag)
    # ไม่ให้ป้ายหดตาม hover-scale ของดาวมากเกินไป → ขนาดคงที่ตาม layout
    await get_tree().process_frame
    var sz: Vector2 = tag.get_combined_minimum_size()
    tag.size = sz
    if planet_id == "moon":
        # ดวงจันทร์อยู่ใกล้โลก — ป้ายอยู่ด้านบนดาว กันทับป้ายโลก
        tag.position = Vector2(-sz.x * 0.5, -label_y - sz.y + 6.0)
    else:
        tag.position = Vector2(-sz.x * 0.5, label_y - 4.0)
