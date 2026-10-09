extends Control
# ==============================================================
#  login.gd  —  attach กับ root Control ของ login.tscn
#  หน้าเลือก Avatar + ตั้งชื่อนักบิน  (ตาม storyboard S-02)
# ==============================================================

@onready var card:           PanelContainer = $Card
@onready var title_label:    Label        = $Card/VBox/TitleLabel
@onready var name_label:     Label        = $Card/VBox/NameLabel
@onready var name_input:     LineEdit     = $Card/VBox/NameInput
@onready var start_btn:      Button       = $Card/VBox/StartButton
@onready var error_label:    Label        = $Card/VBox/ErrorLabel
@onready var avatar_container: HBoxContainer = $Card/VBox/AvatarSelector

@onready var admin_panel:          Control       = $AdminAuthPanel
@onready var admin_card:           PanelContainer= $AdminAuthPanel/AdminAuthCard
@onready var admin_password_input: LineEdit = $AdminAuthPanel/AdminAuthCard/AdminVBox/AdminPasswordInput
@onready var admin_error_label:    Label    = $AdminAuthPanel/AdminAuthCard/AdminVBox/AdminErrorLabel
@onready var admin_cancel_btn:     Button   = $AdminAuthPanel/AdminAuthCard/AdminVBox/AdminBtnRow/AdminCancelBtn
@onready var admin_confirm_btn:    Button   = $AdminAuthPanel/AdminAuthCard/AdminVBox/AdminBtnRow/AdminConfirmBtn

const AVATAR_ICONS: Array[String] = [
    "res://assets/ui/ship_one_explorer_icon.png",
    "res://assets/ui/ship_two_wing_icon.png",
    "res://assets/ui/ship_three_comet_icon.png",
]

var _vskbt: VSKBT = null
const C_START_BLUE := Color(0.050, 0.900, 1.000)   # Pixar cyan (= UITheme.C_ACCENT_CYAN)

const ADMIN_USERNAME: String = "superadmin"
const ADMIN_PASSWORD: String = "Superadmin@2026"   # hardcode ตามที่ขอ — ใช้ authen เข้า mode admin ในเกมเท่านั้น

var selected_avatar: int = 0
var avatar_wraps: Array = []   # VBoxContainer ที่ครอบ Button+Label ของแต่ละ avatar
var avatar_btns:  Array = []
var avatar_tags:  Array = []   # Label "เลือกแล้ว"

func _ready() -> void:
    UITheme.apply_cosmos_bg(self)
    SoundManager.play_bgm("menu", 1.0)
    TouchInput.reset()
    error_label.hide()
    _apply_styles()
    _build_avatars()
    _on_avatar_selected(0)   # เลือก default

    start_btn.pressed.connect(_on_start_pressed)
    name_input.text_submitted.connect(_on_name_submitted)

    admin_panel.hide()
    admin_error_label.hide()
    admin_cancel_btn.pressed.connect(_on_admin_cancel)
    admin_confirm_btn.pressed.connect(_on_admin_confirm)
    admin_password_input.text_submitted.connect(_on_admin_password_submitted)

    # Virtual Screen Keyboard (สำหรับ touch screen)
    _setup_virtual_keyboard()

func _apply_styles() -> void:
    # หน้าต่างเลือกตัวละคร — กรอบ assets/ui/pause_frame.png (ขอบนีออนฟ้า) 1000×625
    card.add_theme_stylebox_override("panel",
        _frame_box("res://assets/ui/pause_frame.png", 110, 58, 110, 82))
    _center_fixed(card, Vector2(1000, 625))
    card.offset_top -= 80.0      # ขยับหน้าต่างขึ้น 80px
    card.offset_bottom -= 80.0
    (card.get_node("VBox") as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
    (card.get_node("VBox") as VBoxContainer).add_theme_constant_override("separation", 12)

    # AdminAuthCard เป็น popup ยืนยันรหัสผ่าน superadmin — เดิมไม่มีสไตล์
    # เลย (ใช้ default theme ของ Godot) จึงไม่มี padding ให้เนื้อหาด้วย
    admin_card.add_theme_stylebox_override("panel",
        UITheme.make_panel_style(UITheme.C_BG_CARD, UITheme.C_BORDER_GOLD, UITheme.PANEL_RADIUS, 3, 28))

    title_label.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
    title_label.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)

    name_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
    name_label.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)

    var input_style := UITheme.make_panel_style(UITheme.C_BG_PANEL, UITheme.C_BORDER_CYAN, 14, 2)
    var input_focus  := UITheme.make_panel_style(UITheme.C_BG_PANEL, UITheme.C_ACCENT_GOLD, 14, 2)
    input_style.content_margin_left = 20.0
    input_focus.content_margin_left = 20.0
    name_input.add_theme_stylebox_override("normal", input_style)
    name_input.add_theme_stylebox_override("focus", input_focus)
    name_input.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
    name_input.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)
    name_input.add_theme_color_override("font_placeholder_color", UITheme.C_TEXT_GREY)

    error_label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    error_label.add_theme_color_override("font_color", UITheme.C_HP_RED)

    UITheme.style_button(start_btn, C_START_BLUE, UITheme.C_BG_DARK, UITheme.BTN_RADIUS)
    start_btn.custom_minimum_size = Vector2(0, 76)
    start_btn.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
    _style_start_pill()

# ── สร้างปุ่ม Avatar แบบไอคอนใหญ่ (ไม่มีพื้นวงกลม) + ป้าย "เลือกแล้ว" ──
func _build_avatars() -> void:
    var blank := StyleBoxEmpty.new()
    avatar_container.alignment = BoxContainer.ALIGNMENT_CENTER
    avatar_container.add_theme_constant_override("separation", 20)
    for i in AVATAR_ICONS.size():
        var wrap := VBoxContainer.new()
        wrap.alignment = BoxContainer.ALIGNMENT_CENTER
        wrap.add_theme_constant_override("separation", 4)

        var btn := Button.new()
        btn.custom_minimum_size = Vector2(180, 140)
        btn.pivot_offset = Vector2(100, 100)
        btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
        btn.expand_icon = true
        btn.add_theme_stylebox_override("normal",  blank)
        btn.add_theme_stylebox_override("hover",   blank)
        btn.add_theme_stylebox_override("pressed", blank)
        btn.add_theme_stylebox_override("focus",   blank)
        var tex := load(AVATAR_ICONS[i]) as Texture2D
        if tex:
            btn.icon = tex
        btn.pressed.connect(_on_avatar_selected.bind(i))

        var tag := Label.new()
        tag.text = "เลือกแล้ว"
        tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        tag.add_theme_font_size_override("font_size", UITheme.FONT_TINY)
        tag.add_theme_color_override("font_color", Color(0.55, 0.95, 0.35))
        tag.hide()

        wrap.add_child(btn)
        wrap.add_child(tag)
        avatar_container.add_child(wrap)
        avatar_wraps.append(wrap)
        avatar_btns.append(btn)
        avatar_tags.append(tag)

func _on_avatar_selected(idx: int) -> void:
    selected_avatar = idx
    for i in avatar_btns.size():
        var btn: Button = avatar_btns[i]
        var tag: Label  = avatar_tags[i]
        if i == idx:
            # เลือกแล้ว — ไอคอนเต็มสี ขยายขึ้นเล็กน้อยให้เด่น (ไม่มีพื้นวงกลม)
            btn.modulate = Color(1, 1, 1)
            btn.scale = Vector2(1.15, 1.15)
            tag.show()
        else:
            btn.modulate = Color(1, 1, 1, 0.5)
            btn.scale = Vector2(1.0, 1.0)
            tag.hide()
    SoundManager.play_sfx("btn_click")

func _on_start_pressed() -> void:
    _try_start()

func _on_name_submitted(_text: String) -> void:
    # กด Enter จาก hardware keyboard → ปิด virtual keyboard (ถ้าเปิดอยู่) แทนที่จะ submit
    if _vskbt != null and _vskbt.is_open():
        _vskbt.close_keyboard()
        return
    _try_start()

func _try_start() -> void:
    var name_text: String = name_input.text.strip_edges()
    if name_text.is_empty():
        name_text = "น้องอวกาศ"
    if name_text.length() < 2:
        error_label.text = "กรุณากรอกชื่อ อย่างน้อย 2 ตัวอักษร"
        error_label.show()
        return
    if name_text.length() > 16:
        error_label.text = "ชื่อยาวเกินไป (สูงสุด 16 ตัวอักษร)"
        error_label.show()
        return

    # ชื่อ "superadmin" → ต้องยืนยันรหัสผ่านก่อนเข้าโหมดผู้ดูแลระบบ
    if name_text.to_lower() == ADMIN_USERNAME:
        error_label.hide()
        _show_admin_auth()
        return

    error_label.hide()
    # ถ้าเป็นชื่อคนละคนกับครั้งก่อน (เช่น เพิ่งทดสอบโหมด superadmin แล้วมา
    # login ด้วยชื่อใหม่) ให้ถือว่าเป็นผู้เล่นใหม่ — โชว์วิธีเล่นอีกครั้ง
    if name_text != GameManager.last_player_name:
        GameManager.first_play = true
    GameManager.player_name      = name_text
    GameManager.player_avatar    = selected_avatar
    GameManager.is_admin         = false
    GameManager.last_player_name = name_text
    SoundManager.play_sfx("btn_click")
    _go_after_login()

func _go_after_login() -> void:
    if GameManager.first_play:
        GameManager.go_to_scene("how_to_play")
    else:
        GameManager.go_to_scene("planet_select")

# ── หน้าต่างยืนยันรหัสผ่านสำหรับ superadmin ────────────────────
func _show_admin_auth() -> void:
    admin_password_input.text = ""
    admin_error_label.hide()
    admin_panel.show()
    admin_password_input.grab_focus()

func _on_admin_cancel() -> void:
    SoundManager.play_sfx("btn_click")
    admin_panel.hide()
    name_input.grab_focus()

func _on_admin_password_submitted(_text: String) -> void:
    _on_admin_confirm()

func _on_admin_confirm() -> void:
    if admin_password_input.text == ADMIN_PASSWORD:
        if "Super Admin" != GameManager.last_player_name:
            GameManager.first_play = true
        GameManager.player_name      = "Super Admin"
        GameManager.player_avatar    = selected_avatar
        GameManager.is_admin         = true
        GameManager.last_player_name = "Super Admin"
        SoundManager.play_sfx("btn_click")
        admin_panel.hide()
        _go_after_login()
    else:
        admin_error_label.text = "❌ รหัสผ่านไม่ถูกต้อง"
        admin_error_label.show()
        admin_password_input.text = ""
        admin_password_input.grab_focus()

# ==============================================================
#  Virtual Screen Keyboard (VSKBT)
# ==============================================================
func _setup_virtual_keyboard() -> void:
    _vskbt = VSKBT.new()
    _vskbt.name = "VirtualKeyboard"
    add_child(_vskbt)

    # กด Enter บน virtual keyboard → ปิด keyboard เฉยๆ (ไม่ submit)
    _vskbt.text_submitted.connect(_on_vskbt_enter)

    # กดช่อง name_input → เปิด keyboard
    name_input.focus_entered.connect(func() -> void:
        if not _vskbt.is_open():
            _vskbt.show_for(name_input)
    )

    # กดช่อง admin password → เปิด keyboard
    admin_password_input.focus_entered.connect(func() -> void:
        if not _vskbt.is_open():
            _vskbt.show_for(admin_password_input)
    )

func _on_vskbt_enter(_text: String) -> void:
    # กด Enter บน virtual keyboard → แค่ปิด keyboard ให้ผู้เล่นเลือกยานก่อน
    # ไม่ submit / ไม่นำทางไปหน้าถัดไป
    pass  # close_keyboard() ถูกเรียกอัตโนมัติใน VSKBT._on_enter() แล้ว


# ==============================================================
#  ปุ่ม "ออกเดินทาง!" — สไตล์เดียวกับปุ่ม "แตะเพื่อเริ่มผจญภัย!" หน้า Attract
#  (แคปซูลฟ้า + ขอบล่างหนา + เรืองแสง + ตัวอักษรขาวมีขอบ + ขยาย-หด + ประกายดาว)
#  ใช้ font เดิมของเกม (ไม่ override font)
# ==============================================================
const C_PILL_CYAN      := Color(0.20, 0.84, 0.92)
const C_PILL_CYAN_EDGE := Color(0.03, 0.42, 0.52)
const PILL_H           := 76.0

func _style_start_pill() -> void:
    for state in ["normal", "hover", "pressed", "disabled"]:
        var sb := StyleBoxFlat.new()
        var c := C_PILL_CYAN
        if state == "hover":   c = C_PILL_CYAN.lightened(0.10)
        if state == "pressed": c = C_PILL_CYAN.darkened(0.12)
        sb.bg_color = c
        sb.set_corner_radius_all(int(PILL_H * 0.5))
        sb.border_color = C_PILL_CYAN_EDGE
        sb.set_border_width_all(3)
        sb.border_width_bottom = 6 if state != "pressed" else 3
        sb.shadow_color = Color(0.25, 0.95, 1.0, 0.55)
        sb.shadow_size  = 10
        sb.anti_aliasing = true
        sb.corner_detail = 12
        start_btn.add_theme_stylebox_override(state, sb)
    start_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        start_btn.add_theme_color_override(k, Color.WHITE)
    start_btn.add_theme_color_override("font_outline_color", Color(0.02, 0.28, 0.36))
    start_btn.add_theme_constant_override("outline_size", 10)

    # รอ layout คำนวณขนาดปุ่มก่อน แล้วตั้ง pivot กลางปุ่ม + ประกายดาวที่มุม
    await get_tree().process_frame
    start_btn.pivot_offset = start_btn.size * 0.5
    #var pulse := create_tween().set_loops()
    #pulse.tween_property(start_btn, "scale", Vector2(1.05, 1.05), 0.9).set_trans(Tween.TRANS_SINE)
    #pulse.tween_property(start_btn, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
    _add_btn_sparkle(Vector2(start_btn.size.x - 8.0, 6.0), 22.0, 0.3)
    _add_btn_sparkle(Vector2(10.0, start_btn.size.y - 4.0), 15.0, 0.8)

func _add_btn_sparkle(pos: Vector2, sz: float, delay: float) -> void:
    var sp := BtnSparkle.new()
    sp.radius = sz
    sp.position = pos
    start_btn.add_child(sp)
    sp.scale = Vector2(0.6, 0.6)
    var t := create_tween().set_loops()
    t.tween_interval(delay)
    t.tween_property(sp, "scale", Vector2(1.1, 1.1), 0.7).set_trans(Tween.TRANS_SINE)
    t.tween_property(sp, "scale", Vector2(0.6, 0.6), 0.7).set_trans(Tween.TRANS_SINE)
    t.tween_interval(1.2 - delay)

class BtnSparkle extends Control:
    var radius: float = 20.0
    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
    func _draw() -> void:
        var r := radius
        var w := r * 0.22
        draw_circle(Vector2.ZERO, r * 0.55, Color(1.0, 0.92, 0.75, 0.25))
        draw_colored_polygon(PackedVector2Array([
            Vector2(0, -r), Vector2(w, -w), Vector2(r, 0), Vector2(w, w),
            Vector2(0, r), Vector2(-w, w), Vector2(-r, 0), Vector2(-w, -w)]), Color(1.0, 0.97, 0.88))
        draw_circle(Vector2.ZERO, w * 0.9, Color.WHITE)


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
