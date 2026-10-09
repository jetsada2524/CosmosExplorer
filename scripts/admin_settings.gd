extends CanvasLayer
# ==============================================================
#  admin_settings.gd  —  attach กับ CanvasLayer "AdminSettings"
#  หน้าตั้งค่าระบบสำหรับ superadmin เปิดจากหน้า วิธีเล่น
#  สร้าง UI ทั้งหมดด้วยโค้ด (ตามแนวทางเดียวกับ leaderboard.gd/how_to_play.gd)
# ==============================================================

func _ready() -> void:
    layer = 20
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_ui()

func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0, 0, 0, 0.75)
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var card := PanelContainer.new()
    card.anchor_left   = 0.5
    card.anchor_top    = 0.5
    card.anchor_right  = 0.5
    card.anchor_bottom = 0.5
    card.offset_left   = -440.0
    card.offset_top    = -440.0
    card.offset_right  = 440.0
    card.offset_bottom = 440.0
    card.add_theme_stylebox_override("panel",
        UITheme.make_panel_style(UITheme.C_BG_CARD, UITheme.C_BORDER_GOLD, UITheme.PANEL_RADIUS, 3, 28))
    add_child(card)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 14)
    card.add_child(vbox)

    var title := Label.new()
    title.text = "⚙️ ตั้งค่าระบบ (Admin)"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", UITheme.FONT_HEADING)
    title.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)
    vbox.add_child(title)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 580)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(scroll)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)

    # ── 6.1 เวลาในการเล่นแต่ละดวงดาว ───────────────────────────
    _add_section_header(content, "🪐 เวลาในการเล่นแต่ละดวงดาว (วินาที)")
    for p in PlanetData.planets:
        var pid: String = p.get("id", "")
        if pid == "earth":
            continue
        var default_t: float = float(p.get("time_limit", 300))
        var current_t: float = GameSettings.get_planet_time(pid, default_t)
        var spin := _add_spin_row(content, p.get("name_th", pid), current_t, 10.0, 3600.0, 5.0)
        spin.value_changed.connect(func(v: float): GameSettings.set_planet_time(pid, v))

    # ── 6.2 / 6.3 / 6.4 ค่าทั่วไป ───────────────────────────────
    _add_section_header(content, "⏱ ค่าทั่วไปที่ตั้งค่าได้")

    var drop_spin := _add_spin_row(content, "เวลา drop ไอเทม (วินาที)",
        GameSettings.powerup_drop_interval, 2.0, 60.0, 0.5)
    drop_spin.value_changed.connect(GameSettings.set_powerup_drop_interval)

    var coin_spin := _add_spin_row(content, "Bonus coin เมื่อพลัง/energy เต็ม",
        float(GameSettings.overflow_coin_bonus), 0.0, 2000.0, 10.0)
    coin_spin.value_changed.connect(func(v: float): GameSettings.set_overflow_coin_bonus(int(v)))

    var fall_spin := _add_spin_row(content, "ความเร็วอุกกาบาตตกตอน boost (x เท่า)",
        GameSettings.boost_fall_mult, 1.0, 4.0, 0.1)
    fall_spin.value_changed.connect(GameSettings.set_boost_fall_mult)

    var speed_spin := _add_spin_row(content, "ความเร็วยานตอน boost (x เท่า)",
        GameSettings.boost_speed_mult, 1.0, 4.0, 0.1)
    speed_spin.value_changed.connect(GameSettings.set_boost_speed_mult)

    var drain_spin := _add_spin_row(content, "Energy ลด %/วินาที ตอน boost",
        GameSettings.energy_drain_boost, 0.0, 50.0, 1.0)
    drain_spin.value_changed.connect(GameSettings.set_energy_drain_boost)

    var regen_spin := _add_spin_row(content, "Energy ฟื้น %/วินาที ตอนไม่ boost",
        GameSettings.energy_idle_regen, 0.0, 20.0, 0.5)
    regen_spin.value_changed.connect(GameSettings.set_energy_idle_regen)

    # ── Keyboard Mapping (แสดงผลเท่านั้น) ───────────────────────
    _add_section_header(content, "⌨️ Keyboard Mapping")
    _add_key_row(content, "เลี้ยวซ้าย",  "← Arrow Left")
    _add_key_row(content, "เลี้ยวขวา",   "→ Arrow Right")
    _add_key_row(content, "บูสต์",       "Space Bar")

    var btn_row := HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 16)
    vbox.add_child(btn_row)

    var reset_btn := Button.new()
    reset_btn.text = "↺ รีเซ็ตค่าเริ่มต้น"
    reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reset_btn.custom_minimum_size = Vector2(0, 64)
    UITheme.style_button(reset_btn, Color(0.45, 0.30, 0.08), UITheme.C_TEXT_WHITE, UITheme.BTN_RADIUS)
    reset_btn.pressed.connect(_on_reset_pressed)
    btn_row.add_child(reset_btn)

    var close_btn := Button.new()
    close_btn.text = "✅ ปิด"
    close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    close_btn.custom_minimum_size = Vector2(0, 64)
    UITheme.style_button(close_btn, UITheme.C_ACCENT_GREEN, UITheme.C_TEXT_WHITE, UITheme.BTN_RADIUS)
    close_btn.pressed.connect(_on_close_pressed)
    btn_row.add_child(close_btn)

func _add_section_header(parent: VBoxContainer, text: String) -> void:
    var lbl := Label.new()
    lbl.text = text
    lbl.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
    lbl.add_theme_color_override("font_color", UITheme.C_TEXT_GOLD)
    parent.add_child(lbl)

func _add_spin_row(parent: VBoxContainer, label_text: String,
        value: float, min_v: float, max_v: float, step: float) -> SpinBox:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)

    var lbl := Label.new()
    lbl.text = label_text
    lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lbl.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
    row.add_child(lbl)

    var spin := SpinBox.new()
    spin.min_value = min_v
    spin.max_value = max_v
    spin.step      = step
    spin.value     = value
    spin.custom_minimum_size = Vector2(150, 0)
    row.add_child(spin)

    parent.add_child(row)
    return spin

func _add_key_row(parent: VBoxContainer, action_text: String, key_text: String) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)

    var lbl := Label.new()
    lbl.text = action_text
    lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lbl.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
    row.add_child(lbl)

    var key_lbl := Label.new()
    key_lbl.text = key_text
    key_lbl.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    key_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_GOLD)
    key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(key_lbl)

    parent.add_child(row)

func _on_reset_pressed() -> void:
    SoundManager.play_sfx("btn_click")
    GameSettings.reset_to_defaults()
    queue_free()

func _on_close_pressed() -> void:
    SoundManager.play_sfx("btn_click")
    queue_free()
