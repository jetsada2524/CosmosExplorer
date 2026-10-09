class_name VSKBT
extends Control

## รายการ	เดิม	ใหม่ (2x)	ตัวแปร
## ความกว้าง keyboard	620px	1240px	_panel.offset_left/right
## ความสูงปุ่ม	44px	88px	_kh
## ความกว้างปุ่ม EN	42px	84px	_en_kw
## ความกว้างปุ่ม TH	38px	76px	_th_kw
## ช่องว่างระหว่างปุ่ม	3px	6px	_kg
## ตัวหนังสือปุ่ม	15px	30px	_font_key
## ตัวหนังสือปุ่ม TH	16px	32px	_font_key_th

signal keyboard_opened
signal keyboard_closed
signal text_submitted(text: String)

var _lang := "en"
var _shift := false
var _target: LineEdit = null
var _is_open := false

var _overlay: ColorRect
var _panel: PanelContainer
var _main_vbox: VBoxContainer
var _btn_en: Button
var _btn_th: Button
var _lbl_shift: Label
var _lbl_lang: Label
var _rows_container: VBoxContainer

## ── Theme ─────────────────────────────────────────────
## กำหนด theme โดยเปลี่ยนค่า theme_id:
##   0 = Default (white/gray)
##   1 = Space blue
##   2 = Warm cream
##   3 = Cosmic purple
##   4 = Planet green
##   5 = Sunset coral
var theme_id: int = 5

var _accent := Color.WHITE
var _key_bg := Color.WHITE
var _key_sp := Color.WHITE
var _panel_bg := Color.WHITE
var _panel_border := Color.WHITE
var _ink := Color.WHITE
var _muted := Color.WHITE
var _overlay_clr := Color(0, 0, 0, 0.35)
var _key_border := Color.WHITE
var _key_shadow := Color.TRANSPARENT
var _border_w: float = 1.0
var _corner_r: float = 8.0
var _kh: float = 60.0
var _kg: float = 6.0
var _en_kw: float = 84.0
var _th_kw: float = 76.0
var _font_key: int = 30
var _font_key_th: int = 32
var _font_header: int = 26
var _font_lang: int = 28


func _apply_theme() -> void:
    match theme_id:
        1: _theme_space_blue()
        2: _theme_warm_cream()
        3: _theme_cosmic_purple()
        4: _theme_planet_green()
        5: _theme_sunset_coral()
        _: _theme_default()


func _theme_default() -> void:
    _accent = Color("#4a7dff")
    _key_bg = Color("#f0f2f5")
    _key_sp = Color("#dfe3e8")
    _panel_bg = Color("#ffffff")
    _panel_border = Color("#c8cdd6")
    _ink = Color("#1a2332")
    _muted = Color("#8a94a6")
    _overlay_clr = Color(0, 0, 0, 0.35)
    _key_border = Color("#c8cdd6")
    _key_shadow = Color.TRANSPARENT
    _border_w = 1.0
    _corner_r = 8.0


func _theme_space_blue() -> void:
    _accent = Color("#4a7dff")
    _key_bg = Color(1, 1, 1, 0.07)
    _key_sp = Color(1, 1, 1, 0.04)
    _panel_bg = Color("#0f1b3d")
    _panel_border = Color("#2a3f6e")
    _ink = Color(1, 1, 1, 0.85)
    _muted = Color(1, 1, 1, 0.45)
    _overlay_clr = Color(0, 0, 0, 0.5)
    _key_border = Color(1, 1, 1, 0.1)
    _key_shadow = Color.TRANSPARENT
    _border_w = 1.0
    _corner_r = 8.0


func _theme_warm_cream() -> void:
    _accent = Color("#D4883A")
    _key_bg = Color("#FFFFFF")
    _key_sp = Color("#F5E6D0")
    _panel_bg = Color("#FFF8ED")
    _panel_border = Color("#E8D5B5")
    _ink = Color("#5C4A2A")
    _muted = Color("#B89E70")
    _overlay_clr = Color(0, 0, 0, 0.35)
    _key_border = Color("#E0CDB0")
    _key_shadow = Color("#E0CDB0")
    _border_w = 1.5
    _corner_r = 10.0


func _theme_cosmic_purple() -> void:
    _accent = Color("#A855F7")
    _key_bg = Color(0.66, 0.33, 0.97, 0.12)
    _key_sp = Color(0.66, 0.33, 0.97, 0.08)
    _panel_bg = Color("#2D1B4E")
    _panel_border = Color("#5C3D8F")
    _ink = Color("#E2D0FF")
    _muted = Color(0.78, 0.67, 1.0, 0.5)
    _overlay_clr = Color(0, 0, 0, 0.5)
    _key_border = Color(0.66, 0.33, 0.97, 0.25)
    _key_shadow = Color.TRANSPARENT
    _border_w = 1.0
    _corner_r = 10.0


func _theme_planet_green() -> void:
    _accent = Color("#22A86B")
    _key_bg = Color("#FFFFFF")
    _key_sp = Color("#DFF2E6")
    _panel_bg = Color("#F0FAF4")
    _panel_border = Color("#A3D9B5")
    _ink = Color("#1A4D32")
    _muted = Color("#7DC09A")
    _overlay_clr = Color(0, 0, 0, 0.35)
    _key_border = Color("#B8E0C8")
    _key_shadow = Color.TRANSPARENT
    _border_w = 1.5
    _corner_r = 8.0


func _theme_sunset_coral() -> void:
    _accent = Color("#E8643A")
    _key_bg = Color("#FFFFFF")
    _key_sp = Color("#FDDDD0")
    _panel_bg = Color("#FFF5F0")
    _panel_border = Color("#F5C4B3")
    _ink = Color("#6B2A12")
    _muted = Color("#E0A58A")
    _overlay_clr = Color(0, 0, 0, 0.35)
    _key_border = Color("#F5C4B3")
    _key_shadow = Color("#F5C4B3")
    _border_w = 1.5
    _corner_r = 12.0


func _ready() -> void:
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    z_index = 100
    _apply_theme()
    _build_ui()


func show_for(target: LineEdit) -> void:
    _target = target
    _is_open = true
    _lang = "en"
    _shift = false
    visible = true
    _rebuild_keys()
    _update_header()
    keyboard_opened.emit()


func close_keyboard() -> void:
    if not _is_open:
        return
    _is_open = false
    visible = false
    _target = null
    keyboard_closed.emit()


func is_open() -> bool:
    return _is_open


func _get_layout() -> Dictionary:
    var num := ["1","2","3","4","5","6","7","8","9","0"]
    var th_num_s := ["\u0e51","\u0e52","\u0e53","\u0e54","\u0e55","\u0e56","\u0e57","\u0e58","\u0e59","\u0e50"]

    var en1 := ["q","w","e","r","t","y","u","i","o","p"]
    var en2 := ["a","s","d","f","g","h","j","k","l"]
    var en3 := ["z","x","c","v","b","n","m"]

    var th1 := ["\u0e46","\u0e44","\u0e33","\u0e1e","\u0e30","\u0e31","\u0e35","\u0e23","\u0e19","\u0e22","\u0e1a","\u0e25"]
    var th2 := ["\u0e1f","\u0e2b","\u0e01","\u0e14","\u0e40","\u0e49","\u0e48","\u0e32","\u0e2a","\u0e27","\u0e07"]
    var th3 := ["\u0e1c","\u0e1b","\u0e41","\u0e2d","\u0e34","\u0e37","\u0e38","\u0e36","\u0e17","\u0e21"]

    var ts1 := ["\u0e45","\u0e42","\u0e43","\u0e20","\u0e16","\u0e39","\u0e04","\u0e15","\u0e08","\u0e02","\u0e0a","\u0e1d"]
    var ts2 := ["\u0e24","\u0e06","\u0e0f","\u0e0e","\u0e0c","\u0e47","\u0e4b","\u0e29","\u0e28","\u0e0b","\u0e0d","\u0e2f"]
    var ts3 := ["\u0e18","\u0e11","\u0e12","\u0e09","\u0e2e","\u0e4c","\u0e4a","\u0e13","\u0e10","\u0e2c"]

    if _lang == "en":
        var r1 = en1.duplicate()
        var r2 = en2.duplicate()
        var r3 = en3.duplicate()
        if _shift:
            r1 = _upper(en1)
            r2 = _upper(en2)
            r3 = _upper(en3)
        return {"num": num, "r1": r1, "r2": r2, "r3": r3, "kw": _en_kw}
    else:
        var n = num.duplicate()
        var r1 = th1.duplicate()
        var r2 = th2.duplicate()
        var r3 = th3.duplicate()
        if _shift:
            n = th_num_s.duplicate()
            r1 = ts1.duplicate()
            r2 = ts2.duplicate()
            r3 = ts3.duplicate()
        return {"num": n, "r1": r1, "r2": r2, "r3": r3, "kw": _th_kw}


func _build_ui() -> void:
    _overlay = ColorRect.new()
    _overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
    _overlay.color = _overlay_clr
    _overlay.gui_input.connect(_on_overlay_click)
    add_child(_overlay)

    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var ps := StyleBoxFlat.new()
    ps.bg_color = _panel_bg
    ps.border_color = _panel_border
    ps.set_border_width_all(int(_border_w) + 1)
    ps.set_corner_radius_all(16)
    ps.content_margin_left = 24
    ps.content_margin_right = 24
    ps.content_margin_top = 20
    ps.content_margin_bottom = 24
    ps.shadow_color = Color(0, 0, 0, 0.15)
    ps.shadow_size = 12
    ps.shadow_offset = Vector2(0, 4)
    _panel.add_theme_stylebox_override("panel", ps)
    add_child(_panel)

    _panel.anchor_left = 0.5
    _panel.anchor_right = 0.5
    _panel.anchor_top = 1.0
    _panel.anchor_bottom = 1.0
    _panel.offset_left = -450 ## -620
    _panel.offset_right = 450 ## 620
    _panel.offset_top = -460 ## -880
    _panel.offset_bottom = -30 ## -20

    _main_vbox = VBoxContainer.new()
    _main_vbox.add_theme_constant_override("separation", 8)
    _panel.add_child(_main_vbox)

    _build_header()

    var sep := HSeparator.new()
    _main_vbox.add_child(sep)

    _rows_container = VBoxContainer.new()
    _rows_container.add_theme_constant_override("separation", int(_kg))
    _main_vbox.add_child(_rows_container)

    _rebuild_keys()


func _build_header() -> void:
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 6)
    _main_vbox.add_child(header)

    var lang_box := HBoxContainer.new()
    lang_box.add_theme_constant_override("separation", 4)
    header.add_child(lang_box)

    _btn_en = Button.new()
    _btn_en.text = "EN"
    _btn_en.custom_minimum_size = Vector2(104, 68)
    _btn_en.pressed.connect(func(): _set_lang("en"))
    lang_box.add_child(_btn_en)

    _btn_th = Button.new()
    _btn_th.text = "TH"
    _btn_th.custom_minimum_size = Vector2(104, 68)
    _btn_th.pressed.connect(func(): _set_lang("th"))
    lang_box.add_child(_btn_th)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)

    _lbl_shift = Label.new()
    _lbl_shift.add_theme_color_override("font_color", _muted)
    _lbl_shift.add_theme_font_size_override("font_size", _font_header)
    header.add_child(_lbl_shift)

    _lbl_lang = Label.new()
    _lbl_lang.add_theme_font_size_override("font_size", _font_lang)
    _lbl_lang.add_theme_color_override("font_color", Color("#5a6577"))
    header.add_child(_lbl_lang)

    var btn_close := Button.new()
    btn_close.text = "\u2715"
    btn_close.custom_minimum_size = Vector2(68, 68)
    btn_close.pressed.connect(close_keyboard)
    _style_key(btn_close, true)
    header.add_child(btn_close)

    _update_header()


func _update_header() -> void:
    _style_lang_btn(_btn_en, _lang == "en")
    _style_lang_btn(_btn_th, _lang == "th")
    if _lang == "en":
        _lbl_shift.text = "A > a" if _shift else "a > A"
        _lbl_lang.text = "English"
    else:
        _lbl_shift.text = "\u0e0f > \u0e01" if _shift else "\u0e01 > \u0e0f"
        _lbl_lang.text = "\u0e20\u0e32\u0e29\u0e32\u0e44\u0e17\u0e22"


func _rebuild_keys() -> void:
    for child in _rows_container.get_children():
        child.queue_free()

    var layout := _get_layout()
    var kw: float = layout["kw"]
    var is_th := _lang == "th"

    _add_row(layout["num"], kw, is_th)
    _add_row(layout["r1"], kw, is_th)
    _add_row(layout["r2"], kw, is_th)

    var row3 := _hbox()
    _rows_container.add_child(row3)

    var shift_btn := Button.new()
    shift_btn.text = "\u21e7"
    shift_btn.custom_minimum_size = Vector2(104, _kh)
    shift_btn.pressed.connect(_on_shift)
    if _shift:
        _style_accent(shift_btn)
    else:
        _style_key(shift_btn, true)
    row3.add_child(shift_btn)

    for ch in layout["r3"]:
        row3.add_child(_char_btn(ch, kw, is_th))

    var bksp := Button.new()
    bksp.text = "\u232b"
    bksp.custom_minimum_size = Vector2(104, _kh)
    bksp.pressed.connect(_on_backspace)
    _style_key(bksp, true)
    row3.add_child(bksp)

    var row4 := _hbox()
    _rows_container.add_child(row4)

    var lang_btn := Button.new()
    lang_btn.text = "\u0e44\u0e17\u0e22" if _lang == "en" else "EN"
    lang_btn.custom_minimum_size = Vector2(136, _kh)
    lang_btn.pressed.connect(_on_toggle_lang)
    _style_key(lang_btn, true)
    row4.add_child(lang_btn)

    var at_btn := Button.new()
    at_btn.text = "@"
    at_btn.custom_minimum_size = Vector2(96, _kh)
    at_btn.pressed.connect(func(): _type_char("@"))
    _style_key(at_btn, true)
    row4.add_child(at_btn)

    var space := Button.new()
    space.text = "space"
    space.custom_minimum_size = Vector2(320, _kh)
    space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    space.pressed.connect(func(): _type_char(" "))
    _style_key(space, false)
    row4.add_child(space)

    var enter := Button.new()
    enter.text = "Enter"
    enter.custom_minimum_size = Vector2(220, _kh)
    enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    enter.pressed.connect(_on_enter)
    _style_accent(enter)
    row4.add_child(enter)


func _add_row(chars: Array, kw: float, is_th: bool) -> void:
    var h := _hbox()
    _rows_container.add_child(h)
    for ch in chars:
        h.add_child(_char_btn(ch, kw, is_th))


func _hbox() -> HBoxContainer:
    var h := HBoxContainer.new()
    h.alignment = BoxContainer.ALIGNMENT_CENTER
    h.add_theme_constant_override("separation", int(_kg))
    return h


func _char_btn(ch: String, w: float, is_th: bool) -> Button:
    var btn := Button.new()
    btn.text = ch
    btn.custom_minimum_size = Vector2(w, _kh)
    btn.pressed.connect(_type_char.bind(ch))
    _style_key(btn, false)
    if is_th:
        btn.add_theme_font_size_override("font_size", _font_key_th)
    return btn


func _style_key(btn: Button, special: bool) -> void:
    var bg: Color = _key_sp if special else _key_bg
    for state in ["normal", "hover", "pressed", "focus"]:
        var s := StyleBoxFlat.new()
        s.set_corner_radius_all(int(_corner_r))
        s.set_border_width_all(int(_border_w))
        s.border_color = _key_border
        s.content_margin_left = 2
        s.content_margin_right = 2
        s.content_margin_top = 2
        s.content_margin_bottom = 2
        if _key_shadow != Color.TRANSPARENT:
            s.shadow_color = _key_shadow
            s.shadow_size = 2
            s.shadow_offset = Vector2(0, 2)
        if state == "hover":
            s.bg_color = bg.darkened(0.04)
        elif state == "pressed":
            s.bg_color = bg.darkened(0.12)
        elif state == "focus":
            s.bg_color = bg
            s.border_color = _accent
        else:
            s.bg_color = bg
        btn.add_theme_stylebox_override(state, s)
    btn.add_theme_color_override("font_color", _ink)
    btn.add_theme_color_override("font_hover_color", _ink)
    btn.add_theme_color_override("font_pressed_color", _ink)
    btn.add_theme_font_size_override("font_size", _font_key)


func _style_accent(btn: Button) -> void:
    for state in ["normal", "hover", "pressed", "focus"]:
        var s := StyleBoxFlat.new()
        s.set_corner_radius_all(int(_corner_r))
        s.content_margin_left = 4
        s.content_margin_right = 4
        s.content_margin_top = 2
        s.content_margin_bottom = 2
        if _key_shadow != Color.TRANSPARENT:
            s.shadow_color = _accent.darkened(0.2)
            s.shadow_size = 2
            s.shadow_offset = Vector2(0, 2)
        if state == "hover":
            s.bg_color = _accent.lightened(0.1)
        elif state == "pressed":
            s.bg_color = _accent.darkened(0.12)
        else:
            s.bg_color = _accent
        btn.add_theme_stylebox_override(state, s)
    btn.add_theme_color_override("font_color", Color.WHITE)
    btn.add_theme_color_override("font_hover_color", Color.WHITE)
    btn.add_theme_color_override("font_pressed_color", Color.WHITE)
    btn.add_theme_font_size_override("font_size", _font_key)


func _style_lang_btn(btn: Button, active: bool) -> void:
    var s := StyleBoxFlat.new()
    s.set_corner_radius_all(int(_corner_r))
    s.content_margin_left = 10
    s.content_margin_right = 10
    s.content_margin_top = 4
    s.content_margin_bottom = 4
    if active:
        s.bg_color = _accent
        btn.add_theme_color_override("font_color", Color.WHITE)
    else:
        s.bg_color = _key_sp
        s.set_border_width_all(int(_border_w))
        s.border_color = _key_border
        btn.add_theme_color_override("font_color", _ink)
    btn.add_theme_stylebox_override("normal", s)
    var h := s.duplicate()
    if active:
        h.bg_color = s.bg_color.darkened(0.03)
    else:
        h.bg_color = s.bg_color.darkened(0.04)
    btn.add_theme_stylebox_override("hover", h)
    btn.add_theme_font_size_override("font_size", _font_lang)


func _type_char(ch: String) -> void:
    if _target == null:
        return
    var pos: int = _target.caret_column
    var t: String = _target.text
    _target.text = t.left(pos) + ch + t.substr(pos)
    _target.caret_column = pos + ch.length()
    _target.text_changed.emit(_target.text)


func _on_backspace() -> void:
    if _target == null:
        return
    var pos: int = _target.caret_column
    if pos > 0:
        var t: String = _target.text
        _target.text = t.left(pos - 1) + t.substr(pos)
        _target.caret_column = pos - 1
        _target.text_changed.emit(_target.text)


func _on_enter() -> void:
    if _target:
        text_submitted.emit(_target.text)
    close_keyboard()


func _on_shift() -> void:
    _shift = not _shift
    _rebuild_keys()
    _update_header()


func _on_toggle_lang() -> void:
    _set_lang("th" if _lang == "en" else "en")


func _set_lang(l: String) -> void:
    _lang = l
    _shift = false
    _rebuild_keys()
    _update_header()


func _on_overlay_click(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            close_keyboard()
            get_viewport().set_input_as_handled()


func _upper(arr: Array) -> Array:
    var r: Array = []
    for s in arr:
        r.append(s.to_upper())
    return r
