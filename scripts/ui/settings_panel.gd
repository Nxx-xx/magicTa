extends VBoxContainer
var host
var _content: VBoxContainer
var current_tab := 0

func setup(ui) -> void:
	host = ui
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for index in 3:
		var button = ui._button(tabs,["声音","显示","教学"][index],func(): _show(index))
		button.name = "SettingsTab_%d" % index
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation",8)
	add_child(_content)
	_show(0)

func _show(index: int) -> void:
	current_tab = index
	host._clear(_content)
	for i in 3: get_child(0).get_child(i).theme_type_variation = "PrimaryButton" if i == index else "QuietButton"
	match index:
		0:
			host.CampaignPanels._toggle(host,_content,"全部静音","muted")
			host.CampaignPanels._toggle(host,_content,"播放受罚语音","punishment_voice")
			for kind in ["effects_volume","voice_volume"]:
				var label = host._text(_content,"",14,host.MUTED)
				var title := "效果音音量" if kind == "effects_volume" else "语音音量"
				label.text = "%s · %d%%" % [title,roundi(host.settings.get(kind)*100)]
				var slider := HSlider.new()
				slider.min_value = 0
				slider.max_value = 1
				slider.step = 0.05
				slider.value = host.settings.get(kind)
				slider.custom_minimum_size.y = 44
				_content.add_child(slider)
				slider.value_changed.connect(func(value):
					host.settings.set(kind,value)
					label.text = "%s · %d%%" % [title,roundi(value*100)]
					host._save_preferences()
				)
			host._text(_content,"剧情始终保留字幕。效果音与受罚人声均为合成原型。",13,host.MUTED)
		1:
			host.CampaignPanels._toggle(host,_content,"减少动效","reduce_motion")
			host._text(_content,"开启后减少战斗演出和界面动效，战斗结果与奖励保持一致。",16,host.MUTED)
		2:
			host._text(_content,"教学只影响提示，不会重置旅程、剧情或火种。",16,host.MUTED)
			host._button(_content,"重置新手教学",func(): host._tutorial_event({"type":"reset"}))
			host._button(_content,"跳过全部教学",func(): host._tutorial_event({"type":"skip_all"}))
	if not host.settings.last_error.is_empty():
		host._text(_content,host.settings.last_error,14,host.RED)
		host._button(_content,"重试保存偏好",host._save_preferences)
