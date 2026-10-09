extends Control
# ==============================================================
#  main_menu.gd  —  attach กับ root Control ของ main_menu.tscn
#
#  UI Layout (ตามภาพอ้างอิง — แนวตั้ง):
#  ┌─────────────────────────────────────────────────────┐
#  │  ⚙️ [Settings]              [Sound] 🔊              │  TopBar
#  │                                                     │
#  │        ผจญภัยอวกาศ 🚀                              │  Title
#  │        พิชิตทุกดาวในจักรวาล                        │  Subtitle
#  │                                                     │
#  │  [cockpit/planet background image]                  │
#  │                                                     │
#  │       ┌─────────────────────┐                      │
#  │       │   เริ่มเกม  ▶       │  Gold button          │
#  │       └─────────────────────┘                      │
#  │  ┌──────────────┐  ┌──────────────┐               │
#  │  │ 🚀 ยานของฉัน │  │ 🏆 ตารางคะแนน│  Blue/Purple  │
#  │  └──────────────┘  └──────────────┘               │
#  │                                                     │
#  │  ── เลือกดาว ─────────────────────────────────     │
#  │  [🌙][🔴][⬤][⬤][⬤][⬤][⬤][⬤]  scroll row         │
#  │  ดวงจันทร์ ดาวอังคาร ดาวพุธ ...                    │
#  └─────────────────────────────────────────────────────┘
# ==============================================================

@onready var settings_btn:    Button         = $TopBar/SettingsBtn
@onready var sound_btn:       Button         = $TopBar/SoundBtn
@onready var title_label:     Label          = $TitleArea/TitleLabel
@onready var subtitle_label:  Label          = $TitleArea/SubtitleLabel
@onready var start_btn:       Button         = $ButtonArea/StartBtn
@onready var myship_btn:      Button         = $ButtonArea/MyShipBtn
@onready var leaderboard_btn: Button         = $ButtonArea/LeaderboardBtn
@onready var planet_row:      HBoxContainer  = $PlanetSection/ScrollContainer/PlanetRow
@onready var planet_section_label: Label     = $PlanetSection/SectionLabel
@onready var selected_planet_label: Label    = $PlanetSection/SelectedLabel
@onready var bg_parallax:     ParallaxBackground = $ParallaxBG
@onready var coin_label:      Label          = $TopBar/CoinLabel   # แสดงเหรียญสะสม

var _sound_on:  bool = true
var _selected_planet_id: String = "moon"

func _ready() -> void:
    TouchInput.reset()
    SoundManager.play_bgm("menu", 1.5)
    _apply_styles()
    _build_planet_row()
    _connect_buttons()
    _animate_title()

# ──────────────────────────────────────────────────────────────
func _apply_styles() -> void:
    # Title
    title_label.add_theme_font_size_override("font_size", UITheme.FONT_TITLE)
    title_label.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)

    subtitle_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
    subtitle_label.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)

    # Start button — gold/orange ใหญ่
    UITheme.style_button(start_btn, UITheme.C_ACCENT_ORANGE,
            UITheme.C_TEXT_WHITE, 20)
    start_btn.add_theme_font_size_override("font_size", 32)
    start_btn.custom_minimum_size = Vector2(480, 88)

    # Ship button — Pixar cyan
    UITheme.style_button(myship_btn, UITheme.C_ACCENT_CYAN,
            UITheme.C_BG_DARK, UITheme.BTN_RADIUS)
    myship_btn.custom_minimum_size = Vector2(220, 70)

    # Leaderboard button — purple
    UITheme.style_button(leaderboard_btn, UITheme.C_ACCENT_PURPLE,
            UITheme.C_TEXT_WHITE, UITheme.BTN_RADIUS)
    leaderboard_btn.custom_minimum_size = Vector2(220, 70)

    # Section label
    planet_section_label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    planet_section_label.add_theme_color_override("font_color", UITheme.C_TEXT_GREY)

    # Coin label
    coin_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
    coin_label.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)

func _connect_buttons() -> void:
    start_btn.pressed.connect(_on_start)
    myship_btn.pressed.connect(_on_my_ship)
    leaderboard_btn.pressed.connect(_on_leaderboard)
    settings_btn.pressed.connect(_on_settings)
    sound_btn.pressed.connect(_on_sound_toggle)

# ──────────────────────────────────────────────────────────────
func _build_planet_row() -> void:
    for child in planet_row.get_children():
        child.queue_free()

    for planet in PlanetData.planets:
        var btn := _make_planet_btn(planet)
        planet_row.add_child(btn)

    _select_planet("moon")

func _make_planet_btn(planet: Dictionary) -> Control:
    var container := VBoxContainer.new()
    container.custom_minimum_size = Vector2(90, 110)
    container.alignment = BoxContainer.ALIGNMENT_CENTER

    # Planet circle button
    var btn := Button.new()
    btn.custom_minimum_size = Vector2(72, 72)
    btn.text = _planet_emoji(planet.get("id",""))
    btn.add_theme_font_size_override("font_size", 36)
    var normal_style := UITheme.make_button_style(
        UITheme.C_BG_CARD, UITheme.C_BORDER_CYAN, 36, 2)
    btn.add_theme_stylebox_override("normal", normal_style)
    btn.add_theme_stylebox_override("hover",
        UITheme.make_button_style(
            UITheme.C_BG_CARD.lightened(.1),
            UITheme.C_BORDER_GOLD, 36, 3))
    btn.pressed.connect(_select_planet.bind(planet.get("id","")))

    # Planet name label
    var lbl := Label.new()
    lbl.text = planet.get("name_th","")
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.add_theme_font_size_override("font_size", UITheme.FONT_TINY)
    lbl.add_theme_color_override("font_color", UITheme.C_TEXT_LIGHT)
    lbl.name = "NameLabel"

    container.add_child(btn)
    container.add_child(lbl)
    container.name = "Planet_" + planet.get("id","")
    return container

func _planet_emoji(id: String) -> String:
    match id:
        "moon":    return "🌙"
        "mars":    return "🔴"
        "mercury": return "⚫"
        "venus":   return "🟡"
        "jupiter": return "🟠"
        "saturn":  return "🪐"
        "uranus":  return "🔵"
        "neptune": return "💙"
    return "⬤"

func _select_planet(id: String) -> void:
    _selected_planet_id = id
    var data := PlanetData.get_planet(id)
    if data.is_empty():
        return

    var diff_idx: int = clampi(data.get("difficulty", 1), 0, 4)
    selected_planet_label.text = (
        "%s  —  %s  |  เวลา %ds" % [
            data.get("name_th",""),
            UITheme.DIFF_LABELS[diff_idx],
            data.get("time_limit", 0)
        ]
    )
    selected_planet_label.add_theme_color_override(
        "font_color", UITheme.DIFF_COLORS[diff_idx])

    # Highlight selected planet button
    for child in planet_row.get_children():
        for sub in child.get_children():
            if sub is Button:
                var is_sel: bool = child.name == "Planet_" + id
                sub.add_theme_stylebox_override("normal",
                    UITheme.make_button_style(
                        UITheme.C_BG_CARD.lightened(.05) if is_sel else UITheme.C_BG_CARD,
                        UITheme.C_BORDER_GOLD if is_sel else UITheme.C_BORDER_CYAN,
                        36,
                        3 if is_sel else 2
                    )
                )
    SoundManager.play_sfx("btn_click")

# ──────────────────────────────────────────────────────────────
func _animate_title() -> void:
    title_label.modulate.a = 0.0
    var tween := create_tween()
    tween.tween_property(title_label, "modulate:a", 1.0, 0.8)
    tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.5)

    # Bounce start button
    var btween := create_tween().set_loops()
    btween.tween_property(start_btn, "scale", Vector2(1.03, 1.03), 0.6)
    btween.tween_property(start_btn, "scale", Vector2(1.0,  1.0),  0.6)

# ──────────────────────────────────────────────────────────────
func _on_start() -> void:
    var data := PlanetData.get_planet(_selected_planet_id)
    if data.is_empty():
        return
    SoundManager.play_sfx("btn_click")
    GameManager.start_mission(data)
    # Transition effect
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.4)
    await tween.finished
    GameManager.go_to_scene("gameplay")

func _on_my_ship() -> void:
    SoundManager.play_sfx("btn_click")
    GameManager.go_to_scene("login")

func _on_leaderboard() -> void:
    SoundManager.play_sfx("btn_click")
    GameManager.go_to_scene("leaderboard")

func _on_settings() -> void:
    SoundManager.play_sfx("btn_click")
    # เปิด settings panel (สร้างเป็น popup แยก)
    $SettingsPanel.show()

func _on_sound_toggle() -> void:
    _sound_on = !_sound_on
    sound_btn.text = "🔊" if _sound_on else "🔇"
    SoundManager.set_bgm_volume(1.0 if _sound_on else 0.0)
    SoundManager.set_sfx_volume(1.0 if _sound_on else 0.0)
