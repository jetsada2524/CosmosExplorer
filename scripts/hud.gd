extends CanvasLayer
# ==============================================================
#  hud.gd  —  Gameplay HUD (cockpit floating-chip redesign)
#
#  Layout zones:
#    Floating chips (y≈10-52): PauseChip | TimerChip | ScoreChip
#    Progress bar  (y≈57-65): slim full-width mission bar
#    Arc gauges    (y≈68-156): HP ring (left) | Energy ring (right)
#    [3D cockpit view fills the middle]
#    Instrument strip (bottom-232 → bottom-162): compact readout
#    Control zone     (bottom-162 → bottom-0): ◀ | BOOST | ▶
# ==============================================================

# ── Node references ──────────────────────────────────────────

@onready var pause_btn:          Button         = $PauseChip/PauseRow/PauseBtn
@onready var planet_name_lbl:    Label          = $PauseChip/PauseRow/PlanetNameLabel
@onready var timer_label:        Label          = $TimerChip/TimerLabel
@onready var coin_label:         Label          = $ScoreChip/ScoreRow/CoinLabel
@onready var progress_track:     Control        = $ProgressTrack
@onready var track_bg:           Panel          = $ProgressTrack/TrackBG
@onready var track_fill:         Panel          = $ProgressTrack/TrackFill
@onready var checkpoint1:        PanelContainer = $ProgressTrack/Checkpoint1
@onready var checkpoint2:        PanelContainer = $ProgressTrack/Checkpoint2
@onready var cp_label1:          Label          = $ProgressTrack/Checkpoint1/CPLabel1
@onready var cp_label2:          Label          = $ProgressTrack/Checkpoint2/CPLabel2
@onready var flag_label:         Label          = $ProgressTrack/FlagLabel
@onready var rocket_label:       Label          = $ProgressTrack/RocketLabel
var hp_gauge:           Control        = null
var energy_gauge:       Control        = null
@onready var hp_value_label:     Label          = $InstrumentStrip/HPValueLabel
@onready var speed_circle:       PanelContainer = $InstrumentStrip/SpeedPanel
@onready var speed_label:        Label          = $InstrumentStrip/SpeedPanel/SpeedVBox/SpeedLabel
@onready var speed_unit:         Label          = $InstrumentStrip/SpeedPanel/SpeedVBox/UnitLabel
@onready var shield_panel:       PanelContainer = $InstrumentStrip/ShieldPanel
@onready var shield_icon:        Label          = $InstrumentStrip/ShieldPanel/ShieldVBox/ShieldIcon
@onready var shield_text:        Label          = $InstrumentStrip/ShieldPanel/ShieldVBox/ShieldText
@onready var energy_value_label: Label          = $InstrumentStrip/EnergyValueLabel
@onready var steer_left_btn:     Button         = $SteerLeftBtn
@onready var boost_btn:          Button         = $BoostBtn
@onready var steer_right_btn:    Button         = $SteerRightBtn
@onready var control_blocker:    ColorRect      = $ControlBlocker
@onready var boost_badge:        PanelContainer = $BoostBadge
@onready var boost_badge_label:  Label          = $BoostBadge/BoostBadgeLabel
@onready var science_tip_panel:  PanelContainer = $ScienceTipPanel
@onready var science_tip_label:  Label          = $ScienceTipPanel/TipLabel
@onready var tip_timer:          Timer          = $ScienceTipTimer
@onready var pause_panel:        Control        = $PausePanel
@onready var pause_card_panel:   PanelContainer = $PausePanel/PauseCardPanel
@onready var pause_title_lbl:    Label          = $PausePanel/PauseCardPanel/PauseCard/PauseTitleLabel
@onready var resume_btn:         Button         = $PausePanel/PauseCardPanel/PauseCard/ResumeBtn
@onready var quit_btn:           Button         = $PausePanel/PauseCardPanel/PauseCard/QuitBtn
@onready var countdown_label:    Label          = $CountdownLabel
@onready var boost_flash:        ColorRect      = $BoostFlash

# ── Internal state ────────────────────────────────────────────

var _current_speed:   float = 785.0
var _checkpoint_done: int   = 0
const CHECKPOINT_COUNT:      int              = 2
const CHECKPOINT_THRESHOLDS: Array[float]     = [0.33, 0.66]

# Arc gauge label refs (created programmatically)
var _hp_pct_lbl:  Label = null
var _eng_pct_lbl: Label = null

# Steer indicator (built programmatically)
var _steer_track:  Control = null
var _steer_marker: Label   = null

# ── Boot ─────────────────────────────────────────────────────

func _ready() -> void:
    pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
    pause_panel.z_index = 10   # หน้าต่างหยุดชั่วคราวอยู่เหนือยานบนแถบความคืบหน้า (rocket z_index = 2)
    _apply_styles()
    _setup_mission_bar()
    pause_panel.hide()
    science_tip_panel.hide()
    countdown_label.hide()
    boost_flash.hide()
    boost_flash.color    = Color(1.0, 0.55, 0.05, 0.08)
    control_blocker.color = Color(0, 0, 0, 0)   # โปร่งใส — ยังกันการกดปุ่มช่วงนับถอยหลัง แต่ไม่เห็นแถบดำ
    control_blocker.show()
    tip_timer.wait_time  = 30.0
    tip_timer.timeout.connect(_show_science_tip)
    tip_timer.start()

    # Hide instrument strip — cockpit_overlay.gd handles dashboard visuals
    get_node("InstrumentStrip").hide()

    # วางตำแหน่งปุ่มตาม layout ของยานที่เลือก (มุมมอง FPS อย่างเดียว)
    _apply_ship_layout()
    # (arc gauges, instrument bg, steer indicator, vignette handled by cockpit_overlay.gd)

    # Signal wiring
    GameManager.hp_changed.connect(_on_hp_changed)
    GameManager.energy_changed.connect(_on_energy_changed)
    GameManager.score_changed.connect(_on_score_changed)
    pause_btn.pressed.connect(_toggle_pause)
    resume_btn.pressed.connect(_toggle_pause)
    quit_btn.pressed.connect(func():
        get_tree().paused = false
        GameManager.go_to_scene("planet_select"))
    boost_btn.button_down.connect(func(): Input.action_press("boost"))
    boost_btn.button_up.connect(func(): Input.action_release("boost"))
    steer_left_btn.button_down.connect(func(): Input.action_press("steer_left"))
    steer_left_btn.button_up.connect(func(): Input.action_release("steer_left"))
    steer_right_btn.button_down.connect(func(): Input.action_press("steer_right"))
    steer_right_btn.button_up.connect(func(): Input.action_release("steer_right"))

# ── Styles ───────────────────────────────────────────────────

func _apply_styles() -> void:

    # ── Pause chip — pill, dark purple ──────────────────────────
    var pc_style := _pill_style(Color(0.031, 0.012, 0.118, 0.88),
                                Color(0.50, 0.20, 0.85, 0.80), 14.0, 7.0)
    get_node("PauseChip").add_theme_stylebox_override("panel", pc_style)
    UITheme.style_button(pause_btn, Color(0, 0, 0, 0), UITheme.C_TEXT_WHITE, 4)
    pause_btn.add_theme_font_size_override("font_size", 18)
    pause_btn.add_theme_color_override("font_color", Color(0.80, 0.70, 1.00, 0.95))
    planet_name_lbl.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)
    planet_name_lbl.add_theme_font_size_override("font_size", 16)

    # ── Timer chip — pill, dark blue | cyan border ───────────────
    var tc_style := _pill_style(Color(0.016, 0.004, 0.086, 0.90),
                                Color(0.15, 0.60, 0.95, 0.80), 12.0, 6.0)
    get_node("TimerChip").add_theme_stylebox_override("panel", tc_style)
    timer_label.add_theme_font_size_override("font_size", 26)
    timer_label.add_theme_color_override("font_color", UITheme.C_ACCENT_CYAN)

    # ── Score chip — pill, dark | gold border ────────────────────
    var sc_style := _pill_style(Color(0.031, 0.016, 0.086, 0.92),
                                Color(0.95, 0.78, 0.15, 0.90), 14.0, 8.0)
    get_node("ScoreChip").add_theme_stylebox_override("panel", sc_style)
    coin_label.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)
    coin_label.add_theme_font_size_override("font_size", 20)
    coin_label.add_theme_constant_override("outline_size", 2)
    coin_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
    coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    # ── Progress track ──────────────────────────────────────────
    track_bg.add_theme_stylebox_override("panel",
        UITheme.make_panel_style(Color(0.047, 0.024, 0.157, 0.80),
                                 UITheme.C_BORDER_PURPLE, 4, 0))
    track_fill.add_theme_stylebox_override("panel",
        UITheme.make_panel_style(Color(0.19, 0.43, 0.96, 0.88),
                                 UITheme.C_ACCENT_CYAN, 4, 0))
    for cp in [checkpoint1, checkpoint2]:
        cp.add_theme_stylebox_override("panel",
            UITheme.make_panel_style(Color(0.25, 0.18, 0.45, 1.0), UITheme.C_TEXT_WHITE, 10, 2))
    for lbl in [cp_label1, cp_label2]:
        lbl.add_theme_font_size_override("font_size", UITheme.FONT_TINY)
        lbl.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)
    flag_label.add_theme_font_size_override("font_size", 16)
    rocket_label.add_theme_font_size_override("font_size", 16)

    # Arc gauges are configured in _build_arc_gauges() which runs after _apply_styles()

    # ── Text values (emoji/Thai set in code; .tscn uses plain ASCII) ─
    steer_left_btn.text    = "◀"
    steer_right_btn.text   = "▶"
    boost_btn.text         = "🔥\nBOOST"
    shield_icon.text       = "🛡"
    shield_text.text       = "ไม่มี"
    rocket_label.text      = "🚀"
    flag_label.text        = "🚩"
    timer_label.text       = "00:00"
    coin_label.text        = "0"
    boost_badge_label.text = "🔥 BOOST x1.5"
    pause_title_lbl.text   = "หยุดชั่วคราว"
    resume_btn.text        = "▶ เล่นต่อ"
    quit_btn.text          = "🏠 ออกไปเลือกดาว"

    _apply_top_hud_style()   # PauseChip / TimerChip / ScoreChip / ProgressTrack แบบเรืองแสง

    # ── Instrument strip labels ──────────────────────────────────
    hp_value_label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    hp_value_label.add_theme_color_override("font_color", UITheme.C_HP_GREEN)
    hp_value_label.add_theme_constant_override("outline_size", 2)
    hp_value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.80))

    energy_value_label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    energy_value_label.add_theme_color_override("font_color", UITheme.C_ENERGY_CYAN)
    energy_value_label.add_theme_constant_override("outline_size", 2)
    energy_value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.80))

    # Speed panel — amber digital readout
    var spd_style := StyleBoxFlat.new()
    spd_style.bg_color                    = Color(0.04, 0.025, 0.06, 0.94)
    spd_style.border_width_left           = 1
    spd_style.border_width_right          = 1
    spd_style.border_width_top            = 1
    spd_style.border_width_bottom         = 1
    spd_style.border_color                = Color(0.75, 0.55, 0.10, 0.55)
    spd_style.corner_radius_top_left      = 9
    spd_style.corner_radius_top_right     = 9
    spd_style.corner_radius_bottom_left   = 9
    spd_style.corner_radius_bottom_right  = 9
    spd_style.content_margin_left  = 10.0
    spd_style.content_margin_right = 10.0
    speed_circle.add_theme_stylebox_override("panel", spd_style)
    speed_label.add_theme_font_size_override("font_size", 28)
    speed_label.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)
    speed_label.add_theme_constant_override("outline_size", 2)
    speed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    speed_unit.add_theme_font_size_override("font_size", UITheme.FONT_TINY)
    speed_unit.add_theme_color_override("font_color", Color(0.72, 0.60, 0.22, 0.85))

    # Shield panel — purple status indicator
    var shd_style := StyleBoxFlat.new()
    shd_style.bg_color                    = Color(0.04, 0.03, 0.12, 0.94)
    shd_style.border_width_left           = 1
    shd_style.border_width_right          = 1
    shd_style.border_width_top            = 1
    shd_style.border_width_bottom         = 1
    shd_style.border_color                = Color(0.50, 0.20, 0.85, 0.55)
    shd_style.corner_radius_top_left      = 9
    shd_style.corner_radius_top_right     = 9
    shd_style.corner_radius_bottom_left   = 9
    shd_style.corner_radius_bottom_right  = 9
    shd_style.content_margin_left  = 10.0
    shd_style.content_margin_right = 10.0
    shield_panel.add_theme_stylebox_override("panel", shd_style)
    shield_icon.add_theme_font_size_override("font_size", 22)
    shield_text.add_theme_font_size_override("font_size", UITheme.FONT_TINY)
    shield_text.add_theme_color_override("font_color", UITheme.C_TEXT_GREY)

    # ── Steer buttons — fill left/right dashboard panels ─────────
    var _mk_steer := func(bg: Color, bg_h: Color, bg_p: Color) -> Array:
        var sn := StyleBoxFlat.new()
        sn.bg_color = bg
        sn.corner_radius_top_left     = 8
        sn.corner_radius_top_right    = 8
        sn.corner_radius_bottom_left  = 8
        sn.corner_radius_bottom_right = 8
        var sh := sn.duplicate() as StyleBoxFlat
        sh.bg_color = bg_h
        var sp := sn.duplicate() as StyleBoxFlat
        sp.bg_color = bg_p
        return [sn, sh, sp]

    var ls: Array = _mk_steer.call(Color(0.05, 0.12, 0.35, 0.55),
                                    Color(0.10, 0.25, 0.65, 0.70),
                                    Color(0.20, 0.45, 0.90, 0.85))
    steer_left_btn.add_theme_stylebox_override("normal",  ls[0])
    steer_left_btn.add_theme_stylebox_override("hover",   ls[1])
    steer_left_btn.add_theme_stylebox_override("pressed", ls[2])
    steer_left_btn.add_theme_stylebox_override("focus",   ls[0].duplicate())
    steer_left_btn.add_theme_font_size_override("font_size", 96)
    steer_left_btn.add_theme_color_override("font_color",         Color(0.55, 0.80, 1.00, 0.85))
    steer_left_btn.add_theme_color_override("font_hover_color",   Color(0.70, 0.90, 1.00, 0.96))
    steer_left_btn.add_theme_color_override("font_pressed_color", Color(1.00, 1.00, 1.00, 1.00))

    var rs: Array = _mk_steer.call(Color(0.05, 0.12, 0.35, 0.55),
                                    Color(0.10, 0.25, 0.65, 0.70),
                                    Color(0.20, 0.45, 0.90, 0.85))
    steer_right_btn.add_theme_stylebox_override("normal",  rs[0])
    steer_right_btn.add_theme_stylebox_override("hover",   rs[1])
    steer_right_btn.add_theme_stylebox_override("pressed", rs[2])
    steer_right_btn.add_theme_stylebox_override("focus",   rs[0].duplicate())
    steer_right_btn.add_theme_font_size_override("font_size", 96)
    steer_right_btn.add_theme_color_override("font_color",         Color(0.55, 0.80, 1.00, 0.85))
    steer_right_btn.add_theme_color_override("font_hover_color",   Color(0.70, 0.90, 1.00, 0.96))
    steer_right_btn.add_theme_color_override("font_pressed_color", Color(1.00, 1.00, 1.00, 1.00))

    # ── Boost button — orange circle with gold glow border ───────
    var boost_n := _circle_style(Color(0.57, 0.19, 0.03, 0.94), Color(0.92, 0.57, 0.06, 0.88))
    var boost_h := _circle_style(Color(0.80, 0.28, 0.04, 0.96), Color(1.00, 0.75, 0.20, 1.00))
    var boost_p := _circle_style(Color(1.00, 0.42, 0.06, 1.00), Color(1.00, 1.00, 0.50, 1.00))
    boost_btn.add_theme_stylebox_override("normal",  boost_n)
    boost_btn.add_theme_stylebox_override("hover",   boost_h)
    boost_btn.add_theme_stylebox_override("pressed", boost_p)
    boost_btn.add_theme_stylebox_override("focus",   boost_n.duplicate())
    boost_btn.add_theme_font_size_override("font_size", 26)
    boost_btn.add_theme_color_override("font_color",         Color(1.0, 0.95, 0.80, 1.0))
    boost_btn.add_theme_color_override("font_hover_color",   Color(1.0, 1.0, 0.90, 1.0))
    boost_btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))

    # ── Science tip ──────────────────────────────────────────────
    _apply_science_tip_frame()

    # ── Pause card ───────────────────────────────────────────────
    _apply_pause_frame()

    # ── Boost badge ──────────────────────────────────────────────
    boost_badge.add_theme_stylebox_override("panel",
        UITheme.make_panel_style(UITheme.C_ACCENT_ORANGE, UITheme.C_ACCENT_GOLD, 14, 2))
    boost_badge_label.add_theme_font_size_override("font_size", UITheme.FONT_SMALL)
    boost_badge_label.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)

# ── Programmatic builders ────────────────────────────────────

# Dark glass panel behind the instrument strip + top border line
func _build_instrument_bg() -> void:
    var bg := ColorRect.new()
    bg.anchor_left   = 0.0
    bg.anchor_right  = 1.0
    bg.anchor_top    = 1.0
    bg.anchor_bottom = 1.0
    bg.offset_top    = -232.0
    bg.offset_bottom = -162.0
    bg.color         = Color(0.016, 0.008, 0.063, 0.97)
    bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    move_child(bg, get_node("InstrumentStrip").get_index())

    var border_line := ColorRect.new()
    border_line.anchor_left   = 0.0
    border_line.anchor_right  = 1.0
    border_line.anchor_top    = 1.0
    border_line.anchor_bottom = 1.0
    border_line.offset_top    = -233.0
    border_line.offset_bottom = -231.0
    border_line.color         = Color(0.14, 0.27, 0.82, 0.50)
    border_line.mouse_filter  = Control.MOUSE_FILTER_IGNORE
    add_child(border_line)
    move_child(border_line, get_node("InstrumentStrip").get_index())

# Create arc gauge Control nodes (script loaded at runtime, not via .tscn ext_resource)
func _build_arc_gauges() -> void:
    var arc_script := load("res://scripts/arc_gauge.gd")

    # HP gauge — top-left corner
    hp_gauge = Control.new()
    hp_gauge.name = "HPGauge"
    hp_gauge.set_script(arc_script)
    hp_gauge.anchor_left   = 0.0
    hp_gauge.anchor_top    = 0.0
    hp_gauge.anchor_right  = 0.0
    hp_gauge.anchor_bottom = 0.0
    hp_gauge.offset_left   = 2.0
    hp_gauge.offset_top    = 68.0
    hp_gauge.offset_right  = 90.0
    hp_gauge.offset_bottom = 156.0
    hp_gauge.mouse_filter  = Control.MOUSE_FILTER_IGNORE
    add_child(hp_gauge)
    move_child(hp_gauge, get_node("InstrumentStrip").get_index())

    # Energy gauge — top-right corner
    energy_gauge = Control.new()
    energy_gauge.name = "EnergyGauge"
    energy_gauge.set_script(arc_script)
    energy_gauge.anchor_left   = 1.0
    energy_gauge.anchor_top    = 0.0
    energy_gauge.anchor_right  = 1.0
    energy_gauge.anchor_bottom = 0.0
    energy_gauge.offset_left   = -90.0
    energy_gauge.offset_top    = 68.0
    energy_gauge.offset_right  = -2.0
    energy_gauge.offset_bottom = 156.0
    energy_gauge.mouse_filter  = Control.MOUSE_FILTER_IGNORE
    add_child(energy_gauge)
    move_child(energy_gauge, get_node("InstrumentStrip").get_index())

    # Apply initial arc colors
    hp_gauge.set("arc_color",  Color(0.08, 0.93, 0.33, 1.0))
    hp_gauge.set("ring_color", Color(0.02, 0.08, 0.02, 0.88))
    hp_gauge.set("fill", 1.0)
    hp_gauge.set("thickness", 7.0)
    energy_gauge.set("arc_color",  Color(0.05, 0.85, 1.00, 1.0))
    energy_gauge.set("ring_color", Color(0.02, 0.04, 0.08, 0.88))
    energy_gauge.set("fill", 1.0)
    energy_gauge.set("thickness", 7.0)

    # Add text labels inside each gauge
    _hp_pct_lbl  = _make_gauge_label_pair(hp_gauge,     "HP",  Color(0.08, 0.93, 0.33, 1.0))
    _eng_pct_lbl = _make_gauge_label_pair(energy_gauge, "ENG", Color(0.05, 0.85, 1.00, 1.0))

func _make_gauge_label_pair(gauge: Control, icon: String, c: Color) -> Label:
    var icon_lbl := Label.new()
    icon_lbl.text = icon
    icon_lbl.add_theme_font_size_override("font_size", 15)
    icon_lbl.add_theme_color_override("font_color", c)
    icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    icon_lbl.offset_left  = -20.0
    icon_lbl.offset_top   = -16.0
    icon_lbl.offset_right =  20.0
    icon_lbl.offset_bottom = 2.0
    icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gauge.add_child(icon_lbl)

    var pct_lbl := Label.new()
    pct_lbl.text = "100%"
    pct_lbl.add_theme_font_size_override("font_size", 12)
    pct_lbl.add_theme_color_override("font_color", c)
    pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pct_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    pct_lbl.offset_left  = -22.0
    pct_lbl.offset_top   =   4.0
    pct_lbl.offset_right =  22.0
    pct_lbl.offset_bottom = 20.0
    pct_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gauge.add_child(pct_lbl)

    return pct_lbl

# Thin steer-position indicator just below the progress bar
func _build_steer_indicator() -> void:
    _steer_track = Control.new()
    _steer_track.anchor_left   = 0.0
    _steer_track.anchor_right  = 1.0
    _steer_track.anchor_top    = 0.0
    _steer_track.anchor_bottom = 0.0
    _steer_track.offset_top    = 67.0
    _steer_track.offset_bottom = 80.0
    _steer_track.mouse_filter  = Control.MOUSE_FILTER_IGNORE
    add_child(_steer_track)

    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.04, 0.03, 0.12, 0.60)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _steer_track.add_child(bg)

    for cfg in [["◀", Control.PRESET_CENTER_LEFT, 6.0], ["▶", Control.PRESET_CENTER_RIGHT, -22.0]]:
        var lbl := Label.new()
        lbl.text = cfg[0]
        lbl.add_theme_font_size_override("font_size", 11)
        lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0, 0.6))
        lbl.set_anchors_and_offsets_preset(cfg[1])
        lbl.offset_left  = cfg[2]
        lbl.offset_top   = -7.0
        lbl.offset_right = cfg[2] + 16.0
        lbl.offset_bottom = 7.0
        lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _steer_track.add_child(lbl)

    var center_line := ColorRect.new()
    center_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    center_line.offset_left  = -1.0
    center_line.offset_top   = -6.0
    center_line.offset_right =  1.0
    center_line.offset_bottom = 6.0
    center_line.color = Color(1.0, 1.0, 1.0, 0.18)
    center_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _steer_track.add_child(center_line)

    _steer_marker = Label.new()
    _steer_marker.text = "◆"
    _steer_marker.add_theme_font_size_override("font_size", 13)
    _steer_marker.add_theme_color_override("font_color", Color(0.25, 0.85, 1.0, 1.0))
    _steer_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _steer_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _steer_marker.size = Vector2(20, 14)
    _steer_track.add_child(_steer_marker)

# Cockpit vignette — dark gradient strips on left/right screen edges
func _build_cockpit_vignette() -> void:
    var gradient := Gradient.new()
    gradient.set_colors(PackedColorArray([
        Color(0.02, 0.01, 0.06, 0.90),
        Color(0.02, 0.01, 0.06, 0.0)
    ]))
    gradient.set_offsets(PackedFloat32Array([0.0, 1.0]))

    var grad_tex := GradientTexture1D.new()
    grad_tex.gradient = gradient
    grad_tex.width    = 256

    var left := TextureRect.new()
    left.texture      = grad_tex
    left.stretch_mode = TextureRect.STRETCH_SCALE
    left.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
    left.mouse_filter = Control.MOUSE_FILTER_IGNORE
    left.anchor_left   = 0.0
    left.anchor_right  = 0.0
    left.anchor_top    = 0.0
    left.anchor_bottom = 1.0
    left.offset_left   = 0.0
    left.offset_top    = 0.0
    left.offset_right  = 88.0
    left.offset_bottom = 0.0
    add_child(left)

    var right := left.duplicate() as TextureRect
    right.flip_h       = true
    right.anchor_left  = 1.0
    right.anchor_right = 1.0
    right.offset_left  = -88.0
    right.offset_right =   0.0
    add_child(right)

# ── Mission bar setup ─────────────────────────────────────────

func _setup_mission_bar() -> void:
    if planet_name_lbl:
        planet_name_lbl.text = GameManager.selected_planet.get("name_th", "")
    _checkpoint_done = 0

# ── Per-frame update ──────────────────────────────────────────

func _process(delta: float) -> void:
    if not GameManager.is_game_running:
        return

    # ── Timer countdown display ──
    var secs := GameManager.time_remaining
    @warning_ignore("integer_division")
    timer_label.text = "%02d:%02d" % [int(secs) / 60, int(secs) % 60]
    if secs <= 30.0:
        timer_label.add_theme_color_override("font_color", UITheme.C_HP_RED)
        timer_label.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
    elif secs <= 60.0:
        timer_label.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)
        timer_label.modulate.a = 1.0
    else:
        timer_label.add_theme_color_override("font_color", TIMER_BLUE)
        timer_label.modulate.a = 1.0

    # ── Speed readout ──
    var target_spd: float = 1800.0 if TouchInput.is_boosting else 785.0
    _current_speed = lerpf(_current_speed, target_spd, 3.0 * delta)
    speed_label.text = "%d" % int(_current_speed)

    # ── Boost effects ──
    boost_flash.visible = TouchInput.is_boosting and GameManager.current_energy > 0.0
    boost_badge.visible = boost_flash.visible

    # ── Steer marker position ──
    if _steer_track and _steer_marker:
        var norm    := clampf(TouchInput.steer_x_norm, -1.0, 1.0)
        var usable  := _steer_track.size.x - 36.0
        var marker_x := 18.0 + (norm + 1.0) * 0.5 * usable - _steer_marker.size.x * 0.5
        _steer_marker.position.x = marker_x
        _steer_marker.position.y = (_steer_track.size.y - _steer_marker.size.y) * 0.5

    # ── Progress bar ──
    var prog    := clampf(GameManager.journey_progress, 0.0, 1.0)
    var track_w := progress_track.size.x
    track_fill.size.x = maxf(4.0, track_w * prog)
    # หัวจรวดอยู่ที่ปลายแถบความคืบหน้า
    rocket_label.position.x = clampf(
        track_w * prog - rocket_label.size.x * 0.88,
        -rocket_label.size.x * 0.3, track_w - rocket_label.size.x)
    _update_checkpoints(prog)

func _update_checkpoints(prog: float) -> void:
    for i in CHECKPOINT_COUNT:
        if prog >= CHECKPOINT_THRESHOLDS[i] and i >= _checkpoint_done:
            _checkpoint_done = i + 1
            var badge: PanelContainer = checkpoint1 if i == 0 else checkpoint2
            badge.add_theme_stylebox_override("panel", _cp_style(true))
            var tw := badge.create_tween()
            badge.pivot_offset = badge.size * 0.5
            tw.tween_property(badge, "scale", Vector2(1.25, 1.25), 0.12)
            tw.tween_property(badge, "scale", Vector2.ONE, 0.18)

# ── Signal handlers ───────────────────────────────────────────

func _on_hp_changed(_val: float) -> void:
    pass  # cockpit_overlay.gd handles HP gauge visuals

func _on_energy_changed(_val: float) -> void:
    pass  # cockpit_overlay.gd handles Energy gauge visuals

func _on_score_changed(val: int) -> void:
    coin_label.text = _fmt_score(val)

func _show_science_tip() -> void:
    var tips := QuizManager.get_random_tips(1)
    if tips.is_empty():
        return
    science_tip_label.text = "🔭  " + tips[0]
    science_tip_panel.show()
    var tween := create_tween()
    tween.tween_interval(5.0)
    tween.tween_callback(science_tip_panel.hide)

# ── Pause / controls ──────────────────────────────────────────

func _toggle_pause() -> void:
    var pausing := not pause_panel.visible
    pause_panel.visible = pausing
    get_tree().paused   = pausing
    if pausing:
        SoundManager.stop_bgm(0.3)
        TouchInput.reset()
    else:
        SoundManager.play_bgm("gameplay", 0.5)

func show_countdown(text: String) -> void:
    countdown_label.text    = text
    countdown_label.visible = true
    countdown_label.add_theme_font_size_override("font_size", 96)
    countdown_label.add_theme_color_override("font_color", UITheme.C_ACCENT_GOLD)
    var tween := create_tween()
    tween.tween_property(countdown_label, "scale", Vector2(1.4, 1.4), 0.1)
    tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3)

func hide_countdown() -> void:
    countdown_label.visible = false

func set_controls_enabled(enabled: bool) -> void:
    control_blocker.visible = not enabled

func set_shield_active(active: bool) -> void:
    shield_text.text = "พร้อม" if active else "ไม่มี"
    var c: Color = UITheme.C_SHIELD_BLUE if active else UITheme.C_TEXT_GREY
    shield_text.add_theme_color_override("font_color", c)
    shield_panel.add_theme_stylebox_override("panel",
        UITheme.make_panel_style(Color(0.05, 0.10, 0.24, 0.88), c, 8, 1))

# ── Helpers ───────────────────────────────────────────────────

# Pill-shaped StyleBoxFlat for chip panels
func _pill_style(bg: Color, border: Color,
                 h_margin: float, v_margin: float) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color                    = bg
    s.border_width_left           = 2
    s.border_width_right          = 2
    s.border_width_top            = 2
    s.border_width_bottom         = 2
    s.border_color                = border
    s.corner_radius_top_left      = 22
    s.corner_radius_top_right     = 22
    s.corner_radius_bottom_left   = 22
    s.corner_radius_bottom_right  = 22
    s.content_margin_left         = h_margin
    s.content_margin_right        = h_margin
    s.content_margin_top          = v_margin
    s.content_margin_bottom       = v_margin
    return s

# Fully circular StyleBoxFlat for Boost button
func _circle_style(bg: Color, border: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color                    = bg
    s.border_width_left           = 2
    s.border_width_right          = 2
    s.border_width_top            = 2
    s.border_width_bottom         = 2
    s.border_color                = border
    s.corner_radius_top_left      = 100
    s.corner_radius_top_right     = 100
    s.corner_radius_bottom_left   = 100
    s.corner_radius_bottom_right  = 100
    return s

func _fmt_score(val: int) -> String:
    var s := str(val)
    var out := ""
    var cnt := 0
    for i in range(s.length() - 1, -1, -1):
        if cnt > 0 and cnt % 3 == 0:
            out = "," + out
        out = s[i] + out
        cnt += 1
    return out

# ==============================================================
#  Ship Layout — วางตำแหน่งปุ่มตามรูป cockpit interior ของแต่ละยาน
# ==============================================================
func _apply_ship_layout() -> void:
    var lay := ShipLayout.get_layout(GameManager.player_avatar)
    if lay.is_empty():
        return
    var vp := get_viewport().get_visible_rect().size
    var W := vp.x
    var H := vp.y

    # ปุ่มเลี้ยวซ้าย — Vector2 center + radius → bounding rect
    var sl_c: Vector2 = lay.steer_l
    var sl_r: float   = float(lay.steer_radius) * W
    _set_btn_rect(steer_left_btn,
        sl_c.x * W - sl_r, sl_c.y * H - sl_r, sl_r * 2.0, sl_r * 2.0)
    steer_left_btn.modulate = Color(1, 1, 1, 0.01)  # แทบโปร่งใส

    # ปุ่มเลี้ยวขวา — Vector2 center + radius → bounding rect
    var sr_c: Vector2 = lay.steer_r
    var sr_r: float   = float(lay.steer_radius) * W
    _set_btn_rect(steer_right_btn,
        sr_c.x * W - sr_r, sr_c.y * H - sr_r, sr_r * 2.0, sr_r * 2.0)
    steer_right_btn.modulate = Color(1, 1, 1, 0.01)

    # ปุ่ม Boost
    var bo: Rect2 = lay.boost
    _set_btn_rect(boost_btn, bo.position.x * W, bo.position.y * H, bo.size.x * W, bo.size.y * H)
    boost_btn.modulate = Color(1, 1, 1, 0.01)

func _set_btn_rect(btn: Button, x: float, y: float, w: float, h: float) -> void:
    btn.anchor_left   = 0.0
    btn.anchor_top    = 0.0
    btn.anchor_right  = 0.0
    btn.anchor_bottom = 0.0
    btn.offset_left   = x
    btn.offset_top    = y
    btn.offset_right  = x + w
    btn.offset_bottom = y + h


# ==============================================================
#  Science Tip — กรอบ "รู้หรือไม่? กล่องความรู้" (assets/ui/science_tip_frame.png 520×335)
#  ข้อความอยู่ในช่องสีน้ำเงินเข้ม ใต้หัวข้อ และไม่ทับหลอดไฟ/ดาวพฤหัสมุมขวา
# ==============================================================
const TIP_FRAME_TEX  := "res://assets/ui/science_tip_frame.png"
const TIP_FRAME_SIZE := Vector2(380, 245)   # ขนาดเล็กลง (เดิม 520×335)

func _apply_science_tip_frame() -> void:
    var tex := load(TIP_FRAME_TEX) as Texture2D
    if tex == null:
        science_tip_panel.add_theme_stylebox_override("panel",
            UITheme.make_panel_style(Color(0.10, 0.05, 0.28, 0.94), UITheme.C_BORDER_CYAN, 18, 2, 14))
    else:
        var sb := StyleBoxTexture.new()
        sb.texture = tex
        # 9-slice: หัวข้อ/หลอดไฟ/ดาว อยู่ในขอบ → ไม่ยืดถ้าข้อความยาว
        sb.texture_margin_left   = 44
        sb.texture_margin_right  = 88
        sb.texture_margin_top    = 70
        sb.texture_margin_bottom = 80
        # พื้นที่ข้อความ = ช่องมืดด้านใน
        sb.content_margin_left   = 37
        sb.content_margin_right  = 56
        sb.content_margin_top    = 67
        sb.content_margin_bottom = 48
        science_tip_panel.add_theme_stylebox_override("panel", sb)
    # วางมุมซ้ายบน ใต้แถบความคืบหน้า
    science_tip_panel.anchor_left   = 0.0
    science_tip_panel.anchor_right  = 0.0
    science_tip_panel.anchor_top    = 0.0
    science_tip_panel.anchor_bottom = 0.0
    science_tip_panel.offset_left   = 24.0
    science_tip_panel.offset_top    = 132.0   # ใต้แถบความคืบหน้า
    science_tip_panel.offset_right  = 24.0 + TIP_FRAME_SIZE.x
    science_tip_panel.offset_bottom = 132.0 + TIP_FRAME_SIZE.y
    science_tip_panel.custom_minimum_size = TIP_FRAME_SIZE
    science_tip_label.add_theme_color_override("font_color", Color.WHITE)
    science_tip_label.add_theme_font_size_override("font_size", 24)
    science_tip_label.add_theme_constant_override("line_spacing", 4)
    science_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    science_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


# ==============================================================
#  Top HUD — PauseChip | TimerChip | ScoreChip + ProgressTrack
#  แคปซูลพื้นน้ำเงินเข้ม ขอบหนาเรืองแสง (ม่วง / ฟ้า / ทอง) ตามแบบดีไซน์
# ==============================================================
const TOP_CHIP_H   := 54.0
const TIMER_BLUE   := Color(0.36, 0.70, 1.00)
const NAME_GOLD    := Color(1.00, 0.80, 0.26)
const CHIP_BG      := Color(0.075, 0.050, 0.170, 0.94)
const TRACK_TOP    := 80.0
const TRACK_H      := 14.0
const CP_SIZE      := 44.0
const FLAG_PLANET  := 64.0   # ขนาดดาวปลายทางที่ปลายแถบ
const SHIP_ICONS: Array[String] = [   # ลำดับเดียวกับหน้าเลือกตัวละคร (login.gd)
    "res://assets/ui/ship_one_explorer_icon.png",
    "res://assets/ui/ship_two_wing_icon.png",
    "res://assets/ui/ship_three_comet_icon.png",
]
# รูปยานต้นฉบับหันซ้ายหรือไม่ (Explorer: ไฟท้ายอยู่ขวา, Comet: ช่องหน้าต่างอยู่ซ้าย, Wing: หัวอยู่ขวาแล้ว)
const SHIP_FACES_LEFT: Array[bool] = [true, false, true]

func _hud_tex(path: String) -> Texture2D:
    if ResourceLoader.exists(path):
        return load(path) as Texture2D
    # ยังไม่ถูก import (ไฟล์ใหม่) → โหลดตรงจากไฟล์
    var img := Image.load_from_file(ProjectSettings.globalize_path(path))
    return ImageTexture.create_from_image(img) if img else null

func _glow_pill(border: Color, glow: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = CHIP_BG
    s.set_border_width_all(3)
    s.border_color = border
    s.set_corner_radius_all(int(TOP_CHIP_H * 0.5))
    s.shadow_color = glow
    s.shadow_size = 8
    s.shadow_offset = Vector2.ZERO
    s.content_margin_left = 18
    s.content_margin_right = 22
    s.content_margin_top = 4
    s.content_margin_bottom = 4
    s.anti_aliasing = true
    return s

func _bold_font(weight: int = 800) -> Font:
    var base := load(UITheme.FONT_BALOO) as Font
    if base == null:
        return null
    var fv := FontVariation.new()
    fv.base_font = base
    var ts := TextServerManager.get_primary_interface()
    fv.variation_opentype = {ts.name_to_tag("wght"): weight}
    return fv

# ฟอนต์ไทยเดิมแบบหนาขึ้น (embolden) สำหรับชื่อดาว
func _emboldened(f: Font, amount: float = 0.7) -> Font:
    if f == null:
        return null
    var fv := FontVariation.new()
    fv.base_font = f
    fv.variation_embolden = amount
    return fv

func _icon_rect(tex: Texture2D, sz: Vector2) -> TextureRect:
    var ic := TextureRect.new()
    ic.texture = tex
    ic.custom_minimum_size = sz
    ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return ic

func _cp_style(done: bool) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.40, 0.74, 0.24) if done else Color(0.22, 0.18, 0.42)
    s.set_border_width_all(3)
    s.border_color = Color(0.22, 0.48, 0.12) if done else Color(0.10, 0.08, 0.22)
    s.set_corner_radius_all(int(CP_SIZE * 0.5))
    s.shadow_color = Color(0.45, 0.95, 0.35, 0.55) if done else Color(0, 0, 0, 0.45)
    s.shadow_size = 6
    s.shadow_offset = Vector2.ZERO if done else Vector2(0, 2)
    s.set_content_margin_all(0)
    return s

func _apply_top_hud_style() -> void:
    var bold := _bold_font()

    # ── PauseChip: ขอบม่วง | ไอคอนพักทอง | เส้นคั่น | ชื่อดาวสีทอง ──
    var pchip := get_node("PauseChip") as PanelContainer
    pchip.add_theme_stylebox_override("panel",
        _glow_pill(Color(0.52, 0.24, 0.95), Color(0.55, 0.20, 1.00, 0.55)))
    pchip.offset_left = 16.0
    pchip.offset_top = 10.0
    pchip.custom_minimum_size = Vector2(0, TOP_CHIP_H)
    (pchip.get_node("PauseRow") as HBoxContainer).add_theme_constant_override("separation", 14)
    pause_btn.text = ""
    pause_btn.icon = _hud_tex("res://assets/ui/hud_pause.png")
    pause_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pause_btn.add_theme_constant_override("icon_max_width", 23)
    pause_btn.custom_minimum_size = Vector2(30, 40)
    var flat := StyleBoxEmpty.new()
    for st in ["normal", "hover", "pressed", "focus", "disabled"]:
        pause_btn.add_theme_stylebox_override(st, flat)
    pause_btn.add_theme_color_override("icon_hover_color", Color(1.0, 1.0, 0.85))
    pause_btn.add_theme_color_override("icon_pressed_color", Color(0.85, 0.75, 0.5))
    var sep := pchip.get_node("PauseRow/PauseSep") as VSeparator
    var line := StyleBoxLine.new()
    line.vertical = true
    line.thickness = 3
    line.color = Color(0.40, 0.28, 0.62, 0.95)
    sep.add_theme_stylebox_override("separator", line)
    sep.custom_minimum_size = Vector2(3, 34)
    var thai_bold := _emboldened(planet_name_lbl.get_theme_font("font"), 0.8)
    if thai_bold:
        planet_name_lbl.add_theme_font_override("font", thai_bold)
    planet_name_lbl.add_theme_font_size_override("font_size", 28)
    planet_name_lbl.add_theme_color_override("font_color", NAME_GOLD)
    planet_name_lbl.add_theme_color_override("font_outline_color", Color(0.20, 0.09, 0.02, 0.85))
    planet_name_lbl.add_theme_constant_override("outline_size", 4)
    planet_name_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
    planet_name_lbl.add_theme_constant_override("shadow_offset_y", 2)

    # ── TimerChip: ขอบฟ้า | นาฬิกาจับเวลา | ตัวเลขสีฟ้า ──
    var tchip := get_node("TimerChip") as PanelContainer
    tchip.add_theme_stylebox_override("panel",
        _glow_pill(Color(0.30, 0.85, 1.00), Color(0.15, 0.80, 1.00, 0.55)))
    tchip.offset_left = -78.0
    tchip.offset_right = 78.0
    tchip.offset_top = 10.0
    tchip.offset_bottom = 10.0 + TOP_CHIP_H
    if not tchip.has_node("TimerRow"):
        var row := HBoxContainer.new()
        row.name = "TimerRow"
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        row.add_theme_constant_override("separation", 10)
        tchip.add_child(row)
        timer_label.reparent(row)
        row.add_child(_icon_rect(_hud_tex("res://assets/ui/hud_stopwatch.png"), Vector2(38, 38)))
        row.move_child(row.get_child(1), 0)
    if bold:
        timer_label.add_theme_font_override("font", bold)
    timer_label.add_theme_font_size_override("font_size", 32)
    timer_label.add_theme_color_override("font_color", TIMER_BLUE)
    timer_label.add_theme_color_override("font_outline_color", Color(0.03, 0.06, 0.20, 0.9))
    timer_label.add_theme_constant_override("outline_size", 4)

    # ── ScoreChip: ขอบทอง | เหรียญหินดวงจันทร์ | ตัวเลขสีทอง ──
    var schip := get_node("ScoreChip") as PanelContainer
    schip.add_theme_stylebox_override("panel",
        _glow_pill(Color(1.00, 0.80, 0.28), Color(1.00, 0.75, 0.15, 0.50)))
    schip.offset_left = -166.0
    schip.offset_right = -16.0
    schip.offset_top = 10.0
    schip.offset_bottom = 10.0 + TOP_CHIP_H
    schip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    var srow := schip.get_node("ScoreRow") as HBoxContainer
    srow.add_theme_constant_override("separation", 10)
    if not srow.has_node("CoinIcon"):
        var ci := _icon_rect(_hud_tex("res://assets/ui/hud_moon_coin.png"), Vector2(42, 42))
        ci.name = "CoinIcon"
        srow.add_child(ci)
        srow.move_child(ci, 0)
    if bold:
        coin_label.add_theme_font_override("font", bold)
    coin_label.add_theme_font_size_override("font_size", 32)
    coin_label.add_theme_color_override("font_color", NAME_GOLD)
    coin_label.add_theme_color_override("font_outline_color", Color(0.20, 0.09, 0.02, 0.85))
    coin_label.add_theme_constant_override("outline_size", 4)

    # ── ProgressTrack: แถบเข้ม + แถบฟ้าเรืองแสง + จรวด + จุดเช็กพอยต์ V + ลูกศรแดง ──
    progress_track.offset_left = 22.0
    progress_track.offset_right = -40.0
    progress_track.offset_top = TRACK_TOP
    progress_track.offset_bottom = TRACK_TOP + TRACK_H
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.13, 0.09, 0.28, 0.95)
    bg.set_border_width_all(2)
    bg.border_color = Color(0.32, 0.24, 0.58, 0.95)
    bg.set_corner_radius_all(int(TRACK_H * 0.5))
    bg.shadow_color = Color(0, 0, 0, 0.45)
    bg.shadow_size = 4
    track_bg.add_theme_stylebox_override("panel", bg)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color(0.30, 0.68, 1.00)
    fill.set_border_width_all(2)
    fill.border_color = Color(0.70, 0.93, 1.00)
    fill.set_corner_radius_all(int(TRACK_H * 0.5))
    fill.shadow_color = Color(0.20, 0.75, 1.00, 0.65)
    fill.shadow_size = 9
    track_fill.add_theme_stylebox_override("panel", fill)
    for cp in [checkpoint1, checkpoint2]:
        cp.offset_left = -CP_SIZE * 0.5
        cp.offset_right = CP_SIZE * 0.5
        cp.offset_top = -CP_SIZE * 0.5
        cp.offset_bottom = CP_SIZE * 0.5
        cp.add_theme_stylebox_override("panel", _cp_style(false))
    for lbl in [cp_label1, cp_label2]:
        lbl.text = "V"
        if bold:
            lbl.add_theme_font_override("font", bold)
        lbl.add_theme_font_size_override("font_size", 26)
        lbl.add_theme_color_override("font_color", Color(1, 1, 1))
        lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
        lbl.add_theme_constant_override("outline_size", 3)
    # ยานของผู้เล่น (ที่เลือกในหน้าเลือกตัวละคร) — วิ่งไปตามแถบความคืบหน้า
    rocket_label.text = ""
    rocket_label.offset_left = 0.0
    rocket_label.offset_right = 84.0
    rocket_label.offset_top = -26.0
    rocket_label.offset_bottom = 26.0
    if not rocket_label.has_node("RocketIcon"):
        var ship_idx := clampi(GameManager.player_avatar, 0, SHIP_ICONS.size() - 1)
        var ri := _icon_rect(_hud_tex(SHIP_ICONS[ship_idx]), Vector2(84, 52))
        ri.flip_h = SHIP_FACES_LEFT[ship_idx]   # ให้หัวยานหันไปทางขวา (ทิศที่วิ่งบนแถบ)
        ri.name = "RocketIcon"
        ri.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        rocket_label.add_child(ri)
    rocket_label.z_index = 2   # ยานอยู่หน้าจุดเช็กพอยต์ (checkpoint z_index = 0)
    checkpoint1.z_index = 0
    checkpoint2.z_index = 0
    # ปลายทาง = ดาวของภารกิจ (โมเดล 3D ชุดเดียวกับหน้าเลือกดาว)
    flag_label.text = ""
    var mission_id: String = GameManager.selected_planet.get("id", "")
    var fsz: float = FLAG_PLANET * (1.7 if mission_id == "saturn" else 1.0)   # ดาวเสาร์: ภาพรวมวงแหวน ตัวดาวจึงเล็กกว่า
    flag_label.offset_left = -fsz * 0.5
    flag_label.offset_right = fsz * 0.5
    flag_label.offset_top = -fsz * 0.5
    flag_label.offset_bottom = fsz * 0.5
    progress_track.offset_right = -(fsz * 0.5 + 10.0)   # เผื่อที่ให้ดาวปลายทางไม่ล้นจอ
    if not flag_label.has_node("TargetPlanet"):
        var pid: String = GameManager.selected_planet.get("id", "")
        var tex: Texture2D = null
        if pid != "":
            var vd := Planet3DView.make_planet_vp(flag_label, pid, Vector2i(160, 160),
                    12.0 if pid == "saturn" else -1.0)
            if not vd.is_empty():
                tex = (vd["vp"] as SubViewport).get_texture()
        if tex == null:
            tex = _hud_tex("res://assets/ui/hud_arrow.png")
        var pr := _icon_rect(tex, Vector2(fsz, fsz))
        pr.name = "TargetPlanet"
        pr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        flag_label.add_child(pr)



# ==============================================================
#  หน้าต่างหยุดชั่วคราว — กรอบ assets/ui/pause_frame.png (ขอบนีออนฟ้า)
#  หัวข้อสีทอง + ปุ่มแคปซูลมันวาว เขียว (เล่นต่อ) / แดงปะการัง (ออก)
# ==============================================================
const PAUSE_FRAME_TEX  := "res://assets/ui/pause_frame.png"
const PAUSE_FRAME_SIZE := Vector2(600, 374)   # สัดส่วนเดียวกับรูปกรอบ 1996×1245

func _pause_pill(btn: Button, base: Color) -> void:
    for state in ["normal", "hover", "pressed", "focus"]:
        var c := base
        if state == "hover":
            c = base.lightened(0.12)
        elif state == "pressed":
            c = base.darkened(0.15)
        var sb := StyleBoxFlat.new()
        sb.bg_color = c
        sb.set_border_width_all(3)
        sb.border_width_bottom = 6
        sb.border_color = base.lightened(0.45)
        sb.set_corner_radius_all(30)
        sb.shadow_color = Color(base.r, base.g, base.b, 0.45)
        sb.shadow_size = 8
        sb.content_margin_left = 16
        sb.content_margin_right = 16
        sb.anti_aliasing = true
        if state == "focus":
            sb.draw_center = false
            sb.set_border_width_all(0)
            sb.shadow_size = 0
        btn.add_theme_stylebox_override(state, sb)
    btn.custom_minimum_size = Vector2(0, 68)
    btn.add_theme_font_size_override("font_size", 34)
    btn.add_theme_color_override("font_color", Color.WHITE)
    btn.add_theme_color_override("font_hover_color", Color.WHITE)
    btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.9))
    btn.add_theme_color_override("font_outline_color", base.darkened(0.55))
    btn.add_theme_constant_override("outline_size", 6)

func _apply_pause_frame() -> void:
    var tex := _hud_tex(PAUSE_FRAME_TEX)
    if tex:
        var sb := StyleBoxTexture.new()
        sb.texture = tex
        # รูปกรอบความละเอียดสูง — ยืดทั้งภาพให้พอดีกล่อง (ขนาดคงที่ สัดส่วนเท่ารูป จึงไม่เบี้ยว)
        sb.content_margin_left = 96
        sb.content_margin_right = 96
        sb.content_margin_top = 56
        sb.content_margin_bottom = 58
        pause_card_panel.add_theme_stylebox_override("panel", sb)
    else:
        pause_card_panel.add_theme_stylebox_override("panel",
            UITheme.make_panel_style(UITheme.C_BG_CARD, UITheme.C_BORDER_CYAN, UITheme.CARD_RADIUS, 3, 26))
    # ขนาดคงที่ กลางจอ
    pause_card_panel.anchor_left = 0.5
    pause_card_panel.anchor_right = 0.5
    pause_card_panel.anchor_top = 0.5
    pause_card_panel.anchor_bottom = 0.5
    pause_card_panel.offset_left = -PAUSE_FRAME_SIZE.x * 0.5
    pause_card_panel.offset_right = PAUSE_FRAME_SIZE.x * 0.5
    pause_card_panel.offset_top = -PAUSE_FRAME_SIZE.y * 0.5
    pause_card_panel.offset_bottom = PAUSE_FRAME_SIZE.y * 0.5
    var card := pause_title_lbl.get_parent() as VBoxContainer
    card.alignment = BoxContainer.ALIGNMENT_CENTER
    card.add_theme_constant_override("separation", 16)
    # หัวข้อ "หยุดชั่วคราว" — สีทอง ขอบน้ำตาลเข้ม
    pause_title_lbl.add_theme_font_size_override("font_size", 46)
    pause_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
    pause_title_lbl.add_theme_color_override("font_outline_color", Color(0.32, 0.14, 0.02, 0.95))
    pause_title_lbl.add_theme_constant_override("outline_size", 10)
    pause_title_lbl.add_theme_color_override("font_shadow_color", Color(1.0, 0.7, 0.2, 0.30))
    pause_title_lbl.add_theme_constant_override("shadow_offset_y", 0)
    pause_title_lbl.add_theme_constant_override("shadow_outline_size", 22)
    _pause_pill(resume_btn, Color(0.36, 0.78, 0.36))
    _pause_pill(quit_btn,   Color(0.92, 0.38, 0.38))
