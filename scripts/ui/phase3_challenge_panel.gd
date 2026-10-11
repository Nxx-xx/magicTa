extends VBoxContainer
## Selection-only UI: snapshots are emitted; the host creates/saves a fresh run.
signal start_requested(selection: Dictionary, seed_text: String)
signal selection_changed(selection: Dictionary)
const Progress = preload("res://scripts/core/phase3_progress.gd")
const Details = preload("res://scripts/ui/paged_catalog.gd")
var _form: VBoxContainer
var _details: PanelContainer
var account: Dictionary = {}
var frozen_definitions: Dictionary = {}
var challenge_id := "p3_c0"
var config_id := "default"
var selection: Dictionary = {}
var seed_input: LineEdit
var _summary: Label
var _start: Button
var _challenge: OptionButton
var _config: OptionButton
var _badge: TextureRect
var _unlock_box: VBoxContainer
var _unlock_tween: Tween
var preparation_only := false

func setup(meta: Dictionary, custom: Dictionary = {}) -> void:
	account = Progress.migrate_meta(meta)
	frozen_definitions = Progress.definitions() if custom.is_empty() else custom.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation",6 if preparation_only else 8)
	add_child(_form)
	var selectors: BoxContainer = VBoxContainer.new() if preparation_only else HBoxContainer.new()
	_form.add_child(selectors)
	var challenge_column: BoxContainer = HBoxContainer.new() if preparation_only else VBoxContainer.new()
	challenge_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selectors.add_child(challenge_column)
	var config_column: BoxContainer = HBoxContainer.new() if preparation_only else VBoxContainer.new()
	config_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selectors.add_child(config_column)
	for pair in [[challenge_column,"挑战难度"],[config_column,"起始配置"]]:
		var label := Label.new()
		label.text = pair[1]
		label.custom_minimum_size.x = 64 if preparation_only else 0
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.add_theme_font_size_override("font_size",14)
		pair[0].add_child(label)
	_challenge = OptionButton.new()
	_challenge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_column.add_child(_challenge)
	_fill_choices(_challenge, frozen_definitions.challenges.challenges, "p3_c0")
	_config = OptionButton.new()
	_config.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	config_column.add_child(_config)
	_fill_choices(_config, frozen_definitions.challenges.start_configs, "default")
	var row := HBoxContainer.new()
	_form.add_child(row)
	_badge = TextureRect.new()
	_badge.custom_minimum_size = Vector2(48, 48)
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_badge)
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if preparation_only: _summary.add_theme_font_size_override("font_size",14)
	row.add_child(_summary)
	seed_input = null
	if not preparation_only:
		seed_input = LineEdit.new()
		seed_input.placeholder_text = "种子（留空随机）"
		seed_input.custom_minimum_size.y = 48
		_form.add_child(seed_input)
	if preparation_only:
		var hint := Label.new()
		hint.text = "仅在新旅程生效"
		hint.add_theme_font_size_override("font_size",14)
		_form.add_child(hint)
	_start = Button.new()
	_start.text = "确认准备" if preparation_only else "以这些属性开始新旅程"
	if preparation_only: _start.theme_type_variation = "PrimaryButton"
	_start.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_start.custom_minimum_size.y = 48 if preparation_only else 52
	_form.add_child(_start)
	_start.pressed.connect(func():
		if selection.get("ok", false):
			start_requested.emit(selection.duplicate(true), "" if preparation_only else seed_input.text)
	)
	_challenge.item_selected.connect(func(_index): _refresh())
	_config.item_selected.connect(func(_index): _refresh())
	_unlock_box = VBoxContainer.new()
	_form.add_child(_unlock_box)
	_details = Details.new()
	_details.back_label = "‹  返回旅程准备"
	_details.embedded = true
	add_child(_details)
	_details.visible = false
	var information := Button.new()
	information.name = "PreparationDetails"
	information.text = "查看详情与解锁条件"
	information.custom_minimum_size.y = 44
	_form.add_child(information)
	information.pressed.connect(func():
		_details._selected = ""
		_details.present_choices([{"id":"selection","name":"出发配置与解锁条件","readonly":true,"detail":_selection_details()}],"","")
		_details.on_back = func(): _details.hide(); _form.show()
		_form.hide()
		_details.show()
		_details._show_detail("selection")
	)
	_refresh()

func select_ids(challenge: String, config: String) -> Dictionary:
	var candidate := Progress.select_start(account, challenge, config, frozen_definitions)
	if not candidate.ok:
		return candidate
	for index in _challenge.item_count:
		if _challenge.get_item_metadata(index) == challenge:
			_challenge.select(index)
	for index in _config.item_count:
		if _config.get_item_metadata(index) == config:
			_config.select(index)
	_refresh()
	return selection.duplicate(true)

func show_unlocks(new_ids: Array, reduced_motion: bool = false) -> void:
	if _unlock_tween != null:
		_unlock_tween.kill()
	for child in _unlock_box.get_children():
		_unlock_box.remove_child(child)
		child.queue_free()
	var catalog: Dictionary = frozen_definitions.unlocks.unlocks
	var title := Label.new()
	title.text = "本次新增 %d 项 · 累计完成 %d 项" % [new_ids.size(), account.achievement_ids.size()]
	_unlock_box.add_child(title)
	for index in mini(3, new_ids.size()):
		var rule: Dictionary = catalog.get(new_ids[index], {})
		var row := HBoxContainer.new()
		_unlock_box.add_child(row)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(42, 42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = badge(str(rule.get("icon", "default")))
		row.add_child(icon)
		var label := Label.new()
		label.text = str(rule.get("name", "新的旅程纪念"))
		row.add_child(label)
		if not reduced_motion:
			icon.modulate.a = 0
			label.modulate.a = 0
			if _unlock_tween == null or not _unlock_tween.is_running():
				_unlock_tween = create_tween()
			_unlock_tween.tween_property(icon, "modulate:a", 1.0, 0.15)
			_unlock_tween.tween_property(label, "modulate:a", 1.0, 0.25)
	if new_ids.size() > 3:
		var more := Button.new()
		more.text = "另有 %d 项 · 查看全部" % (new_ids.size() - 3)
		_unlock_box.add_child(more)
		more.pressed.connect(func():
			for id in new_ids.slice(3):
				var label := Label.new()
				label.text = str(catalog.get(id, {}).get("name", "新的旅程纪念"))
				_unlock_box.add_child(label)
			more.disabled = true
		)
	if not reduced_motion and not new_ids.is_empty():
		var skip := Button.new()
		skip.text = "跳过动效"
		_unlock_box.add_child(skip)
		skip.pressed.connect(func(): show_unlocks(new_ids, true))

func _refresh() -> void:
	challenge_id = str(_challenge.get_item_metadata(_challenge.selected))
	config_id = str(_config.get_item_metadata(_config.selected))
	selection = Progress.select_start(account, challenge_id, config_id, frozen_definitions)
	_start.disabled = not selection.ok
	if not selection.ok:
		_summary.text = selection.error
		return
	var player: Dictionary = selection.player
	var levels: Dictionary = account.get("upgrades", {"hp":0,"attack":0,"gold":0})
	_summary.text = "生命 %d / %d · 攻击 %d · 防御 %d · 金币 %d\n火种：生命 %d / 攻击 %d / 金币 %d" % [player.hp, player.max_hp, player.attack, player.defense, player.gold, levels.hp, levels.attack, levels.gold]
	if preparation_only:
		_summary.text = "生命 %d · 攻击 %d\n防御 %d · 金币 %d" % [player.max_hp,player.attack,player.defense,player.gold]
	_badge.texture = badge(config_id)
	selection_changed.emit(selection.duplicate(true))

func _fill_choices(widget: OptionButton, catalog: Dictionary, selected_id: String) -> void:
	# Open after the gesture completes. A press-opened popup receives the
	# adapter's duplicate touch-down as an outside tap and immediately closes.
	widget.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	widget.custom_minimum_size.y = 48
	widget.fit_to_longest_item = false
	widget.clip_text = true
	widget.add_theme_constant_override("icon_max_width", 40)
	# OptionButton's icon limit does not apply to its separate PopupMenu.
	# Bound every popup icon as well: full-size badges make the menu exceed phones.
	var popup := widget.get_popup()
	popup.add_theme_font_size_override("font_size", 16)
	popup.add_theme_constant_override("v_separation", 12)
	for id in catalog:
		var unlocked: bool = id in account.get("unlocked_ids", [])
		var label: String = catalog[id].name + ("" if unlocked else " · 尚未解锁")
		widget.add_icon_item(badge(id), label)
		var index := widget.item_count - 1
		popup.set_item_icon_max_width(index, 32)
		widget.set_item_metadata(index, id)
		widget.set_item_disabled(index, not unlocked)
		if not unlocked:
			var requirement: String = catalog[id].get("requires", "")
			widget.set_item_tooltip(index, frozen_definitions.unlocks.unlocks.get(requirement, {}).get("description", ""))
		if id == selected_id:
			widget.select(index)

func _selection_details() -> String:
	var text := "当前：%s · %s\n%s" % [selection.get("challenge_snapshot", {}).get("name", ""), selection.get("start_config_snapshot", {}).get("name", ""), _summary.text]
	for catalog in [frozen_definitions.challenges.challenges, frozen_definitions.challenges.start_configs]:
		for id in catalog:
			var entry: Dictionary = catalog[id]
			var unlocked: bool = id in account.get("unlocked_ids", [])
			text += "\n\n%s · %s\n%s" % [entry.name, "已解锁" if unlocked else "尚未解锁", entry.description]
			if not unlocked:
				var rule: Dictionary = frozen_definitions.unlocks.unlocks.get(entry.get("requires", ""), {})
				text += "\n解锁条件：" + str(rule.get("description", "继续探索旅程。"))
	return text

func _label(text_value: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)

static func badge(id: String) -> Texture2D:
	if id not in ["p3_c0", "p3_c1", "p3_c2", "default", "p3_vanguard", "p3_keeper", "p3_trader"]:
		return null
	return image_texture("res://assets/ui/phase3/progression/%s.png" % id)

static func image_texture(path: String) -> Texture2D:
	# Imported resources work in exported PCKs; raw fallback supports the pre-import preview.
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return null if image == null or image.is_empty() else ImageTexture.create_from_image(image)

func back_to_overview() -> bool:
	if is_instance_valid(_details) and _details.visible:
		_details.hide()
		_form.show()
		return true
	return false
