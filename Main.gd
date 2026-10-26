extends Node2D

const GRID_SIZE := 5
const TILE_W := 72
const TILE_H := 36
const STAGES := [
    "Prospector",
    "Mining Foreman",
    "Regional Operator",
    "Hash Farm CEO",
    "Global Crypto Empire"
]
const STAGE_TARGETS := [
    2500.0,
    15000.0,
    75000.0,
    350000.0,
    1500000.0
]

var tiles: Array = []
var selected_data: Dictionary = {}
var game_active := false

var cash := 1800.0
var crypto_balance := 0.0
var market_price := 12850.0
var total_hash_rate := 0.0
var power_capacity := 70.0
var power_usage := 0.0
var miners_owned := 0
var cooling_level := 1
var efficiency := 1.0
var stage_index := 0

var menu_root: CanvasLayer
var hud_root: CanvasLayer
var cash_label: Label
var btc_label: Label
var hash_label: Label
var power_label: Label
var market_label: Label
var selected_label: Label
var stage_label: Label
var objective_label: Label
var status_label: Label
var log_label: Label
var progress_bar: ProgressBar

func _ready() -> void:
    _build_menu()
    _build_game_world()
    _build_hud()
    _update_progression()
    _update_ui()
    _set_status("Press Start to begin your crypto empire.")

func _build_menu() -> void:
    menu_root = CanvasLayer.new()
    add_child(menu_root)

    var center = CenterContainer.new()
    center.anchor_left = 0.0
    center.anchor_top = 0.0
    center.anchor_right = 1.0
    center.anchor_bottom = 1.0
    menu_root.add_child(center)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(560, 360)
    center.add_child(panel)

    var vbox = VBoxContainer.new()
    vbox.alignment = BoxAlignment.CENTER
    panel.add_child(vbox)

    var title = Label.new()
    title.text = "Crypto Mine Tycoon"
    title.add_theme_font_size_override("font_size", 36)
    title.modulate = Color(0.85, 0.95, 1.0)
    vbox.add_child(title)

    var subtitle = Label.new()
    subtitle.text = "Build a mining empire, power your rigs, and grow your crypto wealth."
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.custom_minimum_size = Vector2(480, 60)
    vbox.add_child(subtitle)

    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(0, 18)
    vbox.add_child(spacer)

    var start_button = Button.new()
    start_button.text = "Start Mining"
    start_button.custom_minimum_size = Vector2(240, 48)
    start_button.pressed.connect(_on_start_game_pressed)
    vbox.add_child(start_button)

    var reset_button = Button.new()
    reset_button.text = "Reset Run"
    reset_button.custom_minimum_size = Vector2(240, 48)
    reset_button.pressed.connect(_on_reset_game_pressed)
    vbox.add_child(reset_button)

    var quit_button = Button.new()
    quit_button.text = "Quit"
    quit_button.custom_minimum_size = Vector2(240, 48)
    quit_button.pressed.connect(_on_quit_game_pressed)
    vbox.add_child(quit_button)

func _build_game_world() -> void:
    for x in range(GRID_SIZE):
        tiles.append([])
        for y in range(GRID_SIZE):
            var tile_data: Dictionary = {
                "x": x,
                "y": y,
                "occupied": false,
                "rig_level": 0,
                "hash_rate": 0.0,
                "power_draw": 0.0,
                "node": null,
                "rig_node": null
            }

            var tile = Area2D.new()
            tile.position = _iso_to_screen(x, y)
            tile.set_meta("grid_pos", Vector2i(x, y))
            tile.input_event.connect(func(_viewport, event, _shape_idx):
                if not game_active:
                    return
                if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
                    selected_data = tile_data
                    _update_ui()
                    _set_status("Selected tile (%d, %d)." % [x, y])
            )

            var shape = CollisionPolygon2D.new()
            shape.polygon = PackedVector2Array([
                Vector2(0, -TILE_H * 0.5),
                Vector2(TILE_W * 0.5, 0),
                Vector2(0, TILE_H * 0.5),
                Vector2(-TILE_W * 0.5, 0)
            ])
            tile.add_child(shape)

            var ground = Polygon2D.new()
            ground.polygon = shape.polygon
            ground.color = Color(0.11, 0.15, 0.19)
            tile.add_child(ground)

            var rig = Polygon2D.new()
            rig.polygon = PackedVector2Array([
                Vector2(-10, -10),
                Vector2(10, -10),
                Vector2(10, 10),
                Vector2(-10, 10)
            ])
            rig.position = Vector2(0, -18)
            rig.visible = false
            rig.color = Color(0.25, 0.9, 0.75)
            tile.add_child(rig)

            tile_data["node"] = tile
            tile_data["rig_node"] = rig
            add_child(tile)
            tiles[x].append(tile_data)

func _build_hud() -> void:
    hud_root = CanvasLayer.new()
    add_child(hud_root)

    var root = MarginContainer.new()
    root.anchor_left = 0.0
    root.anchor_top = 0.0
    root.anchor_right = 1.0
    root.anchor_bottom = 1.0
    root.offset_left = 18
    root.offset_top = 18
    root.offset_right = -18
    root.offset_bottom = -18
    hud_root.add_child(root)

    var vbox = VBoxContainer.new()
    root.add_child(vbox)

    var topbar = HBoxContainer.new()
    vbox.add_child(topbar)

    cash_label = _new_label("Cash: $0.00")
    btc_label = _new_label("BTC: 0.0000")
    hash_label = _new_label("Hash: 0 H/s")
    power_label = _new_label("Power: 0 / 0 MW")
    market_label = _new_label("Market: $0 / BTC")
    stage_label = _new_label("Stage: Prospector")
    selected_label = _new_label("Selected: none")
    objective_label = _new_label("Objective: Reach $2,500")

    for child in [cash_label, btc_label, hash_label, power_label, market_label, stage_label, selected_label, objective_label]:
        topbar.add_child(child)

    progress_bar = ProgressBar.new()
    progress_bar.min_value = 0.0
    progress_bar.max_value = 100.0
    progress_bar.value = 0.0
    progress_bar.custom_minimum_size = Vector2(420, 22)
    vbox.add_child(progress_bar)

    var buttons = HBoxContainer.new()
    vbox.add_child(buttons)

    var buy_button = Button.new()
    buy_button.text = "Buy Rig"
    buy_button.pressed.connect(_on_buy_rig_pressed)
    buttons.add_child(buy_button)

    var upgrade_button = Button.new()
    upgrade_button.text = "Upgrade Rig"
    upgrade_button.pressed.connect(_on_upgrade_rig_pressed)
    buttons.add_child(upgrade_button)

    var power_button = Button.new()
    power_button.text = "Power Grid +"
    power_button.pressed.connect(_on_power_upgrade_pressed)
    buttons.add_child(power_button)

    var cooling_button = Button.new()
    cooling_button.text = "Cooling +"
    cooling_button.pressed.connect(_on_cooling_upgrade_pressed)
    buttons.add_child(cooling_button)

    var sell_button = Button.new()
    sell_button.text = "Sell BTC"
    sell_button.pressed.connect(_on_sell_pressed)
    buttons.add_child(sell_button)

    var lower_panel = PanelContainer.new()
    vbox.add_child(lower_panel)

    var lower_vbox = VBoxContainer.new()
    lower_panel.add_child(lower_vbox)

    status_label = _new_label("Status: waiting")
    log_label = _new_label("Miners: 0 | Cooling: 1 | Empire value: $0")
    lower_vbox.add_child(status_label)
    lower_vbox.add_child(log_label)

    hud_root.visible = false

func _new_label(text: String) -> Label:
    var label = Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 16)
    label.modulate = Color(0.92, 0.97, 1.0)
    return label

func _on_start_game_pressed() -> void:
    game_active = true
    menu_root.visible = false
    hud_root.visible = true
    _set_status("Mining operation online.")
    _update_progression()
    _update_ui()

func _on_reset_game_pressed() -> void:
    cash = 1800.0
    crypto_balance = 0.0
    market_price = 12850.0
    total_hash_rate = 0.0
    power_capacity = 70.0
    power_usage = 0.0
    miners_owned = 0
    cooling_level = 1
    efficiency = 1.0
    stage_index = 0
    selected_data.clear()

    for x in range(GRID_SIZE):
        for y in range(GRID_SIZE):
            var cell: Dictionary = tiles[x][y]
            cell["occupied"] = false
            cell["rig_level"] = 0
            cell["hash_rate"] = 0.0
            cell["power_draw"] = 0.0
            if cell["rig_node"] != null:
                cell["rig_node"].visible = false
                cell["rig_node"].scale = Vector2.ONE

    _update_progression()
    _update_ui()
    _set_status("Run reset. Time to build a new empire.")

func _on_quit_game_pressed() -> void:
    get_tree().quit()

func _process(delta: float) -> void:
    if not game_active:
        return

    var overload := max(0.0, power_usage - power_capacity)
    var cooling_bonus := 1.0 + (cooling_level - 1) * 0.14
    var power_penalty := 1.0 - (overload / max(1.0, power_capacity)) * 0.55
    efficiency = clamp(power_penalty * cooling_bonus, 0.35, 1.5)

    market_price = max(6500.0, market_price + randf_range(-30.0, 60.0) * delta * 0.9)

    if total_hash_rate > 0.0:
        var mined := total_hash_rate * delta * 0.014 * efficiency
        crypto_balance += mined

    _update_progression()
    _update_ui()

func _update_progression() -> void:
    while stage_index < STAGES.size() - 1 and cash >= STAGE_TARGETS[stage_index + 1]:
        stage_index += 1

    var current_target = STAGE_TARGETS[stage_index]
    var next_target = STAGE_TARGETS[min(stage_index + 1, STAGE_TARGETS.size() - 1)]
    var progress_value := 0.0

    if stage_index == STAGES.size() - 1:
        progress_value = 100.0
    else:
        var span = max(1.0, next_target - current_target)
        var offset = cash - current_target
        progress_value = clamp((offset / span) * 100.0, 0.0, 100.0)

    progress_bar.value = progress_value
    stage_label.text = "Stage: %s" % STAGES[stage_index]
    if stage_index < STAGES.size() - 1:
        objective_label.text = "Objective: Reach $%.0f" % STAGE_TARGETS[stage_index + 1]
    else:
        objective_label.text = "Objective: Final empire reached"

func _on_buy_rig_pressed() -> void:
    if not game_active:
        return
    if selected_data.is_empty():
        _set_status("Select a tile first.")
        return
    if selected_data["occupied"]:
        _set_status("This tile is already occupied.")
        return

    var cost := 220.0
    if cash < cost:
        _set_status("Not enough cash for a miner.")
        return

    cash -= cost
    selected_data["occupied"] = true
    selected_data["rig_level"] = 1
    selected_data["hash_rate"] = 18.0
    selected_data["power_draw"] = 9.0
    selected_data["rig_node"].visible = true
    selected_data["rig_node"].color = Color(0.25, 0.9, 0.75)
    total_hash_rate += selected_data["hash_rate"]
    power_usage += selected_data["power_draw"]
    miners_owned += 1
    _set_status("ASIC rig purchased.")
    _update_ui()

func _on_upgrade_rig_pressed() -> void:
    if not game_active:
        return
    if selected_data.is_empty() or not selected_data["occupied"]:
        _set_status("Select a rig to upgrade.")
        return

    var current_level := selected_data["rig_level"]
    var upgrade_cost := 120.0 + (current_level * 85.0)
    if cash < upgrade_cost:
        _set_status("Not enough cash to upgrade.")
        return

    var old_hash := selected_data["hash_rate"]
    var old_power := selected_data["power_draw"]
    cash -= upgrade_cost
    selected_data["rig_level"] += 1
    selected_data["hash_rate"] = 18.0 * selected_data["rig_level"]
    selected_data["power_draw"] = 9.0 * selected_data["rig_level"]
    total_hash_rate += selected_data["hash_rate"] - old_hash
    power_usage += selected_data["power_draw"] - old_power
    selected_data["rig_node"].scale = Vector2(1.0 + selected_data["rig_level"] * 0.12, 1.0 + selected_data["rig_level"] * 0.12)
    _set_status("Rig upgraded to level %d." % selected_data["rig_level"])
    _update_ui()

func _on_power_upgrade_pressed() -> void:
    if not game_active:
        return
    var cost := 260.0 + (power_capacity * 1.7)
    if cash < cost:
        _set_status("Not enough cash to expand the grid.")
        return

    cash -= cost
    power_capacity += 30.0
    _set_status("Power grid expanded.")
    _update_ui()

func _on_cooling_upgrade_pressed() -> void:
    if not game_active:
        return
    var cost := 320.0 + (cooling_level * 110.0)
    if cash < cost:
        _set_status("Not enough cash for cooling.")
        return

    cash -= cost
    cooling_level += 1
    _set_status("Cooling upgraded to level %d." % cooling_level)
    _update_ui()

func _on_sell_pressed() -> void:
    if not game_active:
        return
    if crypto_balance <= 0.0:
        _set_status("No BTC to sell yet.")
        return

    var value := crypto_balance * market_price
    cash += value
    crypto_balance = 0.0
    _set_status("Sold BTC for $%.2f." % value)
    _update_ui()

func _update_ui() -> void:
    cash_label.text = "Cash: $%.2f" % cash
    btc_label.text = "BTC: %.4f" % crypto_balance
    hash_label.text = "Hash: %.1f H/s" % total_hash_rate
    power_label.text = "Power: %.1f / %.1f MW" % [power_usage, power_capacity]
    market_label.text = "Market: $%.2f / BTC" % market_price
    selected_label.text = "Selected: %s" % ("(%d, %d)" % [selected_data["x"], selected_data["y"]] if not selected_data.is_empty() else "none")
    status_label.text = "Status: mining %.2fx efficient" % efficiency
    log_label.text = "Miners: %d | Cooling: %d | Empire value: $%.2f" % [miners_owned, cooling_level, crypto_balance * market_price]

func _set_status(message: String) -> void:
    status_label.text = "Status: %s" % message

func _iso_to_screen(x: int, y: int) -> Vector2:
    return Vector2((x - y) * (TILE_W * 0.5), (x + y) * (TILE_H * 0.5))
