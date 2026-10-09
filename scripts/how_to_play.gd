extends Control
# ==============================================================
#  how_to_play.gd  —  attach กับ root ของ how_to_play.tscn
#  แสดงวิธีเล่นแบบ grid 2x2 คงที่ (ตาม storyboard S-03)
# ==============================================================

@onready var frame:             TextureRect    = $Frame
@onready var header_label:      Label          = $Frame/HeaderLabel
@onready var grid:              GridContainer  = $Frame/Grid
@onready var key_row:           PanelContainer = $Frame/KeyRow
@onready var ok_btn:            Button         = $Frame/OKButton
@onready var admin_settings_btn: Button        = $Frame/AdminSettingsBtn

const FRAME_TEX := "res://assets/ui/result_table_frame.png"

const ADMIN_SETTINGS_SCENE: String = "res://scenes/admin_settings.tscn"

const CARD_DATA: Array[Dictionary] = [
    {
        "icon": "◀ 🚀 ▶",
        "title": "บังคับยาน",
        "desc": "ยานบินไปข้างหน้าเองอัตโนมัติ\nกด ◀ = เลี้ยวซ้าย   กด ▶ = เลี้ยวขวา\nเลี้ยวหลบอุกกาบาตได้ถึงขอบซ้าย-ขวาสุด\nดาวยิ่งยาก ยานยิ่งบินเร็ว!"
    },
    {
        "icon": "☄️",
        "title": "แถวอุกกาบาต",
        "desc": "อุกกาบาตลอยนิ่งเรียงเป็นแถวข้างหน้า\nทุกแถวมีช่องว่างให้ลอดผ่านได้เสมอ\nชนอุกกาบาต = HP ลด 20 (HP หมด = ล้มเหลว)\nหลบพ้นแต่ละก้อน ได้ +5 คะแนน"
    },
    {
        "icon": "🔴 🟢 🟡",
        "title": "วงเตือนภัย",
        "desc": "🔴 วงแดง = อุกกาบาตอยู่ในทางของยาน รีบหลบ!\n🟢 วงเขียว = หลบพ้นแล้ว ปลอดภัย\n🟡 วงทอง = ไอเทม บินเข้าไปเก็บได้เลย"
    },
    {
        "icon": "🔥",
        "title": "ปุ่ม BOOST",
        "desc": "กดค้างปุ่ม BOOST = ยานพุ่งเร็วขึ้น\nใช้พลังงาน ⚡ ระหว่างกด\nปล่อยปุ่มแล้ว ⚡ จะค่อย ๆ ชาร์จกลับเอง"
    },
    {
        "icon": "🛡 ❓ ⚡ ⭐",
        "title": "ไอเทมในเกม",
        "desc": "🛡 โล่ = กันการชนได้ 1 ครั้ง\n❓ Quiz = ตอบถูกได้ HP +20\n⚡ พลังงาน = เติม energy +25\n⭐ ดาว = ได้ +50 คะแนน\nถ้า HP / พลังงานเต็มอยู่แล้ว จะได้ 🪙 แทน!"
    },
    {
        "icon": "🏁 🏆",
        "title": "ภารกิจ",
        "desc": "แถบบนจอ = ระยะทางถึงดาวปลายทาง\nผ่าน checkpoint ✓ ทีละจุด\nบินจนถึงปลายทางโดย HP ไม่หมด\n= ภารกิจสำเร็จ! ลงจอดบนดาวได้เลย 🏆"
    },
]

func _ready() -> void:
    UITheme.apply_cosmos_bg(self)
    _apply_styles()
    _build_grid()
    _build_key_row()
    ok_btn.pressed.connect(_on_ok_pressed)
    admin_settings_btn.visible = GameManager.is_admin
    admin_settings_btn.pressed.connect(_on_admin_settings_pressed)

func _tex(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return load(path) as Texture2D
    var img := Image.load_from_file(ProjectSettings.globalize_path(path))
    return ImageTexture.create_from_image(img) if img else null

# ไล่สีทองเฉพาะพิกเซลเนื้อตัวอักษร (สีขาว) — ขอบไม่ถูกเปลี่ยนสี
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

func _apply_styles() -> void:
    frame.texture = _tex(FRAME_TEX)
    # หัวข้อในช่องบากด้านบนของกรอบ — ไล่สีทอง
    var fs := 54
    header_label.add_theme_font_size_override("font_size", fs)
    header_label.add_theme_color_override("font_color", Color.WHITE)
    header_label.add_theme_color_override("font_outline_color", Color(0.40, 0.15, 0.02))
    header_label.add_theme_constant_override("outline_size", 12)
    var mat := ShaderMaterial.new()
    var sh := Shader.new()
    sh.code = GOLD_SHADER
    mat.shader = sh
    var f := header_label.get_theme_font("font")
    if f:
        var asc := f.get_ascent(fs)
        mat.set_shader_parameter("y0", asc - fs * 0.80)
        mat.set_shader_parameter("y1", asc + fs * 0.10)
    header_label.material = mat

    # ปุ่มแคปซูลฟ้า แบบเดียวกับ "แตะเพื่อเริ่มผจญภัย!" (font เดิม, ไม่มี tween)
    ok_btn.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
    _style_pill(ok_btn, 72.0)

func _build_grid() -> void:
    grid.add_theme_constant_override("h_separation", 16)
    grid.add_theme_constant_override("v_separation", 14)

    for data in CARD_DATA:
        var card := PanelContainer.new()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.size_flags_vertical   = Control.SIZE_EXPAND_FILL
        card.custom_minimum_size   = Vector2(0, 252)
        var csb := StyleBoxFlat.new()
        csb.bg_color = Color(0.09, 0.09, 0.20, 0.92)
        csb.border_color = Color(1.0, 0.80, 0.30, 0.75)
        csb.set_border_width_all(2)
        csb.set_corner_radius_all(16)
        csb.shadow_color = Color(0, 0, 0, 0.4)
        csb.shadow_size = 6
        csb.set_content_margin_all(10)
        card.add_theme_stylebox_override("panel", csb)

        var vbox := VBoxContainer.new()
        vbox.alignment = BoxContainer.ALIGNMENT_CENTER
        vbox.add_theme_constant_override("separation", 4)  # 10→4

        var icon := Label.new()
        icon.text = data["icon"]
        icon.add_theme_font_size_override("font_size", 32)
        icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

        var title := Label.new()
        title.text = data["title"]
        title.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
        title.add_theme_color_override("font_color", UITheme.C_TEXT_GOLD)
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

        var desc := Label.new()
        desc.text = data["desc"]
        desc.add_theme_font_size_override("font_size", 23)
        desc.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
        desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD
        desc.add_theme_constant_override("line_spacing", 0)  # 6→0

        vbox.add_child(icon)
        vbox.add_child(title)
        vbox.add_child(desc)
        card.add_child(vbox)
        grid.add_child(card)

# ── แถบการบังคับด้วยคีย์บอร์ด (อ่านปุ่มจริงจาก InputMap + GameSettings) ──
const KEY_ACTIONS: Array = [
    ["steer_left",  "เลี้ยวซ้าย"],
    ["steer_right", "เลี้ยวขวา"],
    ["boost",       "BOOST (กดค้าง)"],
]

func _key_name(code: int) -> String:
    match code:
        KEY_LEFT:  return "←"
        KEY_RIGHT: return "→"
        KEY_UP:    return "↑"
        KEY_DOWN:  return "↓"
    return OS.get_keycode_string(code as Key)

# รวมปุ่มทั้งหมดของ action (ไม่ซ้ำ): ปุ่มจาก project.godot + ปุ่มที่ตั้งใน GameSettings
func _keys_for(action: String) -> Array[String]:
    var codes: Array[int] = []
    var gs_key: int = {"steer_left": GameSettings.key_steer_left,
        "steer_right": GameSettings.key_steer_right, "boost": GameSettings.key_boost}.get(action, 0)
    if gs_key != 0:
        codes.append(gs_key)
    if InputMap.has_action(action):
        for ev in InputMap.action_get_events(action):
            if ev is InputEventKey:
                var k := ev as InputEventKey
                var c: int = int(k.keycode) if int(k.keycode) != 0 else int(k.physical_keycode)
                if c != 0 and not codes.has(c):
                    codes.append(c)
    var names: Array[String] = []
    for c in codes:
        names.append(_key_name(c))
    return names

func _keycap(txt: String) -> PanelContainer:
    var cap := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.92, 0.94, 1.0)
    sb.border_color = Color(0.55, 0.58, 0.75)
    sb.set_border_width_all(2)
    sb.border_width_bottom = 5
    sb.set_corner_radius_all(8)
    sb.content_margin_left = 12
    sb.content_margin_right = 12
    sb.content_margin_top = 0
    sb.content_margin_bottom = 2
    cap.add_theme_stylebox_override("panel", sb)
    cap.custom_minimum_size = Vector2(46, 46)
    cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var l := Label.new()
    l.text = txt
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", 26)
    l.add_theme_color_override("font_color", Color(0.12, 0.12, 0.25))
    cap.add_child(l)
    return cap

func _build_key_row() -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.09, 0.09, 0.20, 0.92)
    sb.border_color = Color(0.45, 0.85, 1.0, 0.75)
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(16)
    sb.content_margin_left = 20
    sb.content_margin_right = 20
    key_row.add_theme_stylebox_override("panel", sb)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 10)
    key_row.add_child(row)
    var head := Label.new()
    head.text = "⌨️ คีย์บอร์ด:"
    head.add_theme_font_size_override("font_size", 28)
    head.add_theme_color_override("font_color", UITheme.C_TEXT_GOLD)
    row.add_child(head)
    for i in KEY_ACTIONS.size():
        var spacer := Control.new()
        spacer.custom_minimum_size = Vector2(26, 0)
        row.add_child(spacer)
        var keys := _keys_for(KEY_ACTIONS[i][0])
        for j in keys.size():
            if j > 0:
                var orl := Label.new()
                orl.text = "/"
                orl.add_theme_font_size_override("font_size", 24)
                orl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
                row.add_child(orl)
            row.add_child(_keycap(keys[j]))
        var lbl := Label.new()
        lbl.text = "= " + str(KEY_ACTIONS[i][1])
        lbl.add_theme_font_size_override("font_size", 26)
        lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
        row.add_child(lbl)

func _on_ok_pressed() -> void:
    SoundManager.play_sfx("btn_click")
    GameManager.go_to_scene("planet_select")

func _on_admin_settings_pressed() -> void:
    SoundManager.play_sfx("btn_click")
    var scene: PackedScene = load(ADMIN_SETTINGS_SCENE)
    if scene == null:
        push_warning("how_to_play: โหลด admin_settings.tscn ไม่สำเร็จ")
        return
    add_child(scene.instantiate())


# ==============================================================
#  ปุ่มแคปซูลฟ้า — สไตล์เดียวกับปุ่ม "แตะเพื่อเริ่มผจญภัย!" หน้า Attract
#  (มุมโค้งเต็ม + ขอบล่างหนา + เรืองแสงฟ้า + ตัวอักษรขาวมีขอบ) — ใช้ font เดิม
# ==============================================================
const C_PILL_CYAN      := Color(0.20, 0.84, 0.92)
const C_PILL_CYAN_EDGE := Color(0.03, 0.42, 0.52)

func _style_pill(btn: Button, h: float) -> void:
    for state in ["normal", "hover", "pressed", "disabled"]:
        var sb := StyleBoxFlat.new()
        var c := C_PILL_CYAN
        if state == "hover":   c = C_PILL_CYAN.lightened(0.10)
        if state == "pressed": c = C_PILL_CYAN.darkened(0.12)
        sb.bg_color = c
        sb.set_corner_radius_all(int(h * 0.5))
        sb.border_color = C_PILL_CYAN_EDGE
        sb.set_border_width_all(3)
        sb.border_width_bottom = 6 if state != "pressed" else 3
        sb.shadow_color = Color(0.25, 0.95, 1.0, 0.55)
        sb.shadow_size  = 12
        sb.anti_aliasing = true
        sb.corner_detail = 12
        btn.add_theme_stylebox_override(state, sb)
    btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        btn.add_theme_color_override(k, Color.WHITE)
    btn.add_theme_color_override("font_outline_color", Color(0.02, 0.28, 0.36))
    btn.add_theme_constant_override("outline_size", 10)
