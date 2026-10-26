extends Node2D

const GRID_SIZE := 5
const TILE_W := 72
const TILE_H := 36

var tiles: Array = []
var map_root: Node2D
var hud_root: CanvasLayer
var selected_data = null

var cash: float = 1800.0
var crypto_balance: float = 0.0
var market_price: float = 12850.0
var total_hash_rate: float = 0.0
var power_capacity: float = 70.0
var power_usage: float = 0.0
var miners_owned: int = 0
var cooling_level: int = 1
var efficiency: float = 1.0

var cash_label: Label
var btc_label: Label
var hash_rate_label: Label
var power_label: Label
var selected_label: Label
var status_label: Label
var market_label: Label
var log_label: Label

var buy_button: Button
var upgrade_button: Button
var power_button: Button
var cooling_button: Button
var sell_button: Button

func _ready() -> void:
	map_root = Node2D.new()
	add_child(map_root)

	hud_root = CanvasLayer.new()
	add_child(hud_root)

	_build_mine_grid()
	_build_hud()
	_update_ui()
	_set_status("Click a mine tile to buy your first ASIC rig.")

func _build_mine_grid() -> void:
	for x in range(GRID_SIZE):
		tiles.append([])
		for y in range(GRID_SIZE):
			var tile_data = {
				"x": x,
				"y": y,
				"occupied": false,
				"rig_level": 0,
				"hash_rate": 0.0,
				"power_draw": 0.0,
				"node": null,
				"rig_node": null,
			}

			var tile = Area2D.new()
			tile.position = _iso_to_screen(x, y)
			var shape = CollisionPolygon2D.new()
			shape.polygon = PackedVector2Array([
				Vector2(0, -TILE_H * 0.5),
				Vector2(TILE_W * 0.5, 0),
				Vector2(0, TILE_H * 0.5),
				Vector2(-TILE_W * 0.5, 0)
			])
			tile.add_child(shape)
			tile.set_meta("grid_pos", Vector2i(x, y))
			tile.input_event.connect(func(viewport, event, shape_idx): _on_tile_click(tile_data, event))
			map_root.add_child(tile)

			var ground = Polygon2D.new()
			ground.polygon = shape.polygon
			ground.position = Vector2.ZERO
			ground.color = Color(0.12, 0.14, 0.18)
			tile.add_child(ground)

			var rig = Polygon2D.new()
			rig.polygon = PackedVector2Array([
				Vector2(-8, -8),
				Vector2(8, -8),
				Vector2(8, 8),
				Vector2(-8, 8)
			])
			rig.position = Vector2(0, -18)
			rig.color = Color(0.18, 0.9, 0.7)
			rig.visible = false
			tile.add_child(rig)

			tile_data["node"] = tile
			tile_data["rig_node"] = rig
			tiles[x].append(tile_data)

func _build_hud() -> void:
	var root = MarginContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 18
	root.offset_top = 18
	root.offset_right = -18
	root.offset_bottom = -18
	hud_root.add_child(root)

	var box = VBoxContainer.new()
	root.add_child(box)

	var header = Label.new()
	header.text = "Crypto Mine Tycoon"
	header.add_theme_font_size_override("font_size", 26)
	header.modulate = Color(0.88, 0.94, 1.0)
	box.add_child(header)

	var top_row = HBoxContainer.new()
	box.add_child(top_row)

	cash_label = _make_label("Cash: $0")
	btc_label = _make_label("BTC: 0.000")
	hash_rate_label = _make_label("Hash: 0 H/s")
	power_label = _make_label("Power: 0 / 0 MW")
	market_label = _make_label("Market: $0 / BTC")
	selected_label = _make_label("Selected: none")
	status_label = _make_label("Status: idle")
	log_label = _make_label("")

	for child in [cash_label, btc_label, hash_rate_label, power_label, market_label, selected_label]:
		top_row.add_child(child)

	var panel = PanelContainer.new()
	box.add_child(panel)

	var panel_box = VBoxContainer.new()
	panel.add_child(panel_box)
	panel_box.add_child(status_label)
	panel_box.add_child(log_label)

	var buttons = HBoxContainer.new()
	box.add_child(buttons)

	buy_button = Button.new()
	buy_button.text = "Buy Rig"
	buy_button.pressed.connect(_on_buy_rig_pressed)
	buttons.add_child(buy_button)

	upgrade_button = Button.new()
	upgrade_button.text = "Upgrade Rig"
	upgrade_button.pressed.connect(_on_upgrade_rig_pressed)
	buttons.add_child(upgrade_button)

	power_button = Button.new()
	power_button.text = "Power Grid +"
	power_button.pressed.connect(_on_power_upgrade_pressed)
	buttons.add_child(power_button)

	cooling_button = Button.new()
	cooling_button.text = "Cooling +"
	cooling_button.pressed.connect(_on_cooling_upgrade_pressed)
	buttons.add_child(cooling_button)

	sell_button = Button.new()
	sell_button.text = "Sell BTC"
	sell_button.pressed.connect(_on_sell_pressed)
	buttons.add_child(sell_button)

	var tip = Label.new()
	tip.text = "Tip: click a tile to buy or upgrade your mining rigs."
	box.add_child(tip)

func _make_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(0.93, 0.98, 1.0)
	return label

func _on_tile_click(tile_data, event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected_data = tile_data
		for x in range(GRID_SIZE):
			for y in range(GRID_SIZE):
				var cell = tiles[x][y]
				if cell["node"]:
					var is_selected = cell == selected_data
					cell["node"].modulate = Color(1, 1, 1) if not is_selected else Color(1.3, 1.3, 1.3)
		_update_ui()
		_set_status("Selected tile (%d, %d)." % [tile_data["x"], tile_data["y"]])

func _on_buy_rig_pressed() -> void:
	if selected_data == null:
		_set_status("Select a tile first.")
		return
	if selected_data["occupied"]:
		_set_status("This tile already has a rig.")
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
	selected_data["rig_node"].color = Color(0.2, 0.9, 0.7)
	total_hash_rate += selected_data["hash_rate"]
	power_usage += selected_data["power_draw"]
	miners_owned += 1
	_set_status("ASIC rig purchased.")
	_update_ui()

func _on_upgrade_rig_pressed() -> void:
	if selected_data == null:
		_set_status("Select a tile first.")
		return
	if not selected_data["occupied"]:
		_set_status("There is no rig to upgrade.")
		return

	var current_level := selected_data["rig_level"]
	var upgrade_cost := 120.0 + (current_level * 85.0)
	if cash < upgrade_cost:
		_set_status("Not enough cash for the upgrade.")
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
	var cost := 260.0 + (power_capacity * 1.7)
	if cash < cost:
		_set_status("Not enough cash to expand power grid.")
		return
	cash -= cost
	power_capacity += 30.0
	_set_status("Power grid expanded.")
	_update_ui()

func _on_cooling_upgrade_pressed() -> void:
	var cost := 320.0 + (cooling_level * 110.0)
	if cash < cost:
		_set_status("Not enough cash to improve cooling.")
		return
	cash -= cost
	cooling_level += 1
	_set_status("Cooling upgraded to level %d." % cooling_level)
	_update_ui()

func _on_sell_pressed() -> void:
	if crypto_balance <= 0.0:
		_set_status("No BTC available to sell.")
		return
	var value := crypto_balance * market_price
	cash += value
	crypto_balance = 0.0
	_set_status("Sold BTC for $%.2f." % value)
	_update_ui()

func _process(delta: float) -> void:
	var overload := max(0.0, power_usage - power_capacity)
	var cooling_bonus := 1.0 + (cooling_level - 1) * 0.16
	var power_penalty := 1.0 - (overload / max(1.0, power_capacity)) * 0.55
	efficiency = clamp(power_penalty * cooling_bonus, 0.35, 1.5)

	market_price = max(6500.0, market_price + randf_range(-28.0, 58.0) * delta * 0.8)
	if total_hash_rate > 0.0:
		var mined := total_hash_rate * delta * 0.014 * efficiency
		crypto_balance += mined

func _update_ui() -> void:
	cash_label.text = "Cash: $%.2f" % cash
	btc_label.text = "BTC: %.4f" % crypto_balance
	hash_rate_label.text = "Hash: %.1f H/s" % total_hash_rate
	power_label.text = "Power: %.1f / %.1f MW" % [power_usage, power_capacity]
	market_label.text = "Market: $%.2f / BTC" % market_price
	selected_label.text = "Selected: %s" % ("(%d, %d)" % [selected_data["x"], selected_data["y"]] if selected_data != null else "none")
	status_label.text = "Status: mining %.2fx efficient" % efficiency
	log_label.text = "Miners: %d | Cooling: %d | BTC value: $%.2f" % [miners_owned, cooling_level, crypto_balance * market_price]

func _set_status(message: String) -> void:
	log_label.text = message
	status_label.text = "Status: %s" % message

func _iso_to_screen(x: int, y: int) -> Vector2:
	return Vector2((x - y) * (TILE_W * 0.5), (x + y) * (TILE_H * 0.5))
