@tool
extends Control

signal request_create_staticbody(options: Dictionary)
signal request_regenerate_collision(options: Dictionary)
signal request_remove_collision()
signal preview_toggled(enabled: bool, options: Dictionary)
signal options_changed(options: Dictionary)

enum TargetType { NONE, SPRITE, STATIC_BODY, TEXTURE_PATH }

var current_target_type: TargetType = TargetType.NONE
var target_sprite: Sprite2D = null
var target_body: CollisionObject2D = null
var target_texture_path: String = ""
var target_texture: Texture2D = null
var _syncing_shadow_controls: bool = false

# Node references
@onready var target_label: Label = %TargetLabel
@onready var target_info_label: Label = %TargetInfoLabel
@onready var target_icon: TextureRect = %TargetIcon

@onready var alpha_slider: HSlider = %AlphaSlider
@onready var alpha_spin: SpinBox = %AlphaSpin
@onready var simpl_option: OptionButton = %SimplOption
@onready var custom_eps_box: HBoxContainer = %CustomEpsBox
@onready var custom_eps_spin: SpinBox = %CustomEpsSpin
@onready var max_points_spin: SpinBox = %MaxPointsSpin
@onready var collision_mode_option: OptionButton = %CollisionModeOption
@onready var build_mode_option: OptionButton = %BuildModeOption

@onready var preset_option: OptionButton = %PresetOption
@onready var rot_speed_box: HBoxContainer = %RotSpeedBox
@onready var rot_speed_spin: SpinBox = %RotSpeedSpin
@onready var bumper_box: HBoxContainer = %BumperBox
@onready var bounce_force_spin: SpinBox = %BounceForceSpin
@onready var star_box: HBoxContainer = %StarBox
@onready var star_index_spin: SpinBox = %StarIndexSpin
@onready var key_door_box: HBoxContainer = %KeyDoorBox
@onready var key_id_edit: LineEdit = %KeyIdEdit
@onready var crumble_box: HBoxContainer = %CrumbleBox
@onready var collapse_delay_spin: SpinBox = %CollapseDelaySpin
@onready var respawn_time_spin: SpinBox = %RespawnTimeSpin
@onready var wind_box: HBoxContainer = %WindBox
@onready var wind_force_spin: SpinBox = %WindForceSpin

@onready var add_shadow_check: CheckBox = %AddShadowCheck
@onready var shadow_controls_box: VBoxContainer = %ShadowControlsBox
@onready var shadow_anchor_option: OptionButton = %ShadowAnchorOption
@onready var custom_anchor_box: HBoxContainer = %CustomAnchorBox
@onready var custom_anchor_x_spin: SpinBox = %CustomAnchorXSpin
@onready var custom_anchor_y_spin: SpinBox = %CustomAnchorYSpin
@onready var shadow_offset_x_spin: SpinBox = %ShadowOffsetXSpin
@onready var shadow_offset_y_spin: SpinBox = %ShadowOffsetYSpin
@onready var shadow_angle_spin: SpinBox = %ShadowAngleSpin
@onready var shadow_dist_spin: SpinBox = %ShadowDistSpin
@onready var shadow_color_picker: ColorPickerButton = %ShadowColorPicker
@onready var shadow_scale_spin: SpinBox = %ShadowScaleSpin
@onready var realtime_shadow_check: CheckBox = %RealtimeShadowCheck

@onready var create_body_check: CheckBox = %CreateBodyCheck
@onready var keep_sprite_check: CheckBox = %KeepSpriteCheck
@onready var auto_col_check: CheckBox = %AutoColCheck

@onready var create_btn: Button = %CreateBtn
@onready var regen_btn: Button = %RegenBtn
@onready var preview_btn: Button = %PreviewBtn
@onready var remove_btn: Button = %RemoveBtn
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	_setup_ui()
	_update_target_ui()

func _setup_ui() -> void:
	# Populate Dropdowns
	if simpl_option and simpl_option.item_count == 0:
		simpl_option.add_item("Low (Detailed - 128 pts)")
		simpl_option.add_item("Medium (Balanced - 64 pts)")
		simpl_option.add_item("High (Low-Poly - 32 pts)")
		simpl_option.add_item("Custom...")
		simpl_option.select(1)
		
	if collision_mode_option and collision_mode_option.item_count == 0:
		collision_mode_option.add_item("Single Polygon")
		collision_mode_option.add_item("Convex Decomposition")
		collision_mode_option.select(0)
		
	if build_mode_option and build_mode_option.item_count == 0:
		build_mode_option.add_item("Solids (Filled Area)")
		build_mode_option.add_item("Segments (Edges Only)")
		build_mode_option.select(0)
		
	if preset_option and preset_option.item_count == 0:
		preset_option.add_item("🧱 Static Wall / Platform")
		preset_option.add_item("🌀 Rotating Obstacle / Spinner")
		preset_option.add_item("⚠️ Hazard / Trap")
		preset_option.add_item("🏁 Goal / Checkered Flag")
		preset_option.add_item("🦘 Bumper / Spring Pad")
		preset_option.add_item("🛡️ One-Way Jelly Membrane")
		preset_option.add_item("🌀 Teleport Portal")
		preset_option.add_item("⭐ Collectible Star / Gem")
		preset_option.add_item("🔑 Key Pickup")
		preset_option.add_item("🚪 Locked Door")
		preset_option.add_item("💥 Crumbling / Falling Platform")
		preset_option.add_item("💨 Wind Vent / Air Fan")
		preset_option.add_item("🔘 Pressure Plate / Switch")
		preset_option.add_item("🧊 Ice / Slippery Floor")
		preset_option.select(0)

	# Connect Value syncs
	if alpha_slider and alpha_spin:
		alpha_slider.value_changed.connect(func(val):
			if absf(alpha_spin.value - val) > 0.001:
				alpha_spin.value = val
			_on_settings_modified()
		)
		alpha_spin.value_changed.connect(func(val):
			if absf(alpha_slider.value - val) > 0.001:
				alpha_slider.value = val
			_on_settings_modified()
		)
		
	if simpl_option:
		simpl_option.item_selected.connect(func(idx):
			if custom_eps_box:
				custom_eps_box.visible = (idx == 3)
			# Auto update max points default
			if idx == 0 and max_points_spin: max_points_spin.value = 128
			elif idx == 1 and max_points_spin: max_points_spin.value = 64
			elif idx == 2 and max_points_spin: max_points_spin.value = 32
			_on_settings_modified()
		)
		if custom_eps_box:
			custom_eps_box.visible = (simpl_option.selected == 3)
			
	if preset_option:
		var on_preset_selected = func(idx):
			if rot_speed_box: rot_speed_box.visible = (idx == 1)
			if bumper_box: bumper_box.visible = (idx == 4)
			if star_box: star_box.visible = (idx == 7)
			if key_door_box: key_door_box.visible = (idx == 8 or idx == 9)
			if crumble_box: crumble_box.visible = (idx == 10)
			if wind_box: wind_box.visible = (idx == 11)
			_on_settings_modified()
		preset_option.item_selected.connect(on_preset_selected)
		on_preset_selected.call(preset_option.selected)
		
	if rot_speed_spin:
		rot_speed_spin.value_changed.connect(func(_val): _on_settings_modified())
	if bounce_force_spin:
		bounce_force_spin.value_changed.connect(func(_val): _on_settings_modified())
	if star_index_spin:
		star_index_spin.value_changed.connect(func(_val): _on_settings_modified())
	if key_id_edit:
		key_id_edit.text_changed.connect(func(_val): _on_settings_modified())
	if collapse_delay_spin:
		collapse_delay_spin.value_changed.connect(func(_val): _on_settings_modified())
	if respawn_time_spin:
		respawn_time_spin.value_changed.connect(func(_val): _on_settings_modified())
	if wind_force_spin:
		wind_force_spin.value_changed.connect(func(_val): _on_settings_modified())
	if max_points_spin:
		max_points_spin.value_changed.connect(func(val):
			var cur_preset = simpl_option.selected if simpl_option else 1
			var preset_default = 128 if cur_preset == 0 else (64 if cur_preset == 1 else (32 if cur_preset == 2 else -1))
			if preset_default > 0 and int(val) != preset_default:
				simpl_option.select(3) # Switch to Custom
				if custom_eps_box: custom_eps_box.visible = true
			_on_settings_modified()
		)
	if collision_mode_option:
		collision_mode_option.item_selected.connect(func(_idx): _on_settings_modified())
	if build_mode_option:
		build_mode_option.item_selected.connect(func(_idx): _on_settings_modified())
	if rot_speed_spin:
		rot_speed_spin.value_changed.connect(func(_val): _on_settings_modified())
		
	if shadow_anchor_option and shadow_anchor_option.item_count == 0:
		shadow_anchor_option.add_item("Center (Top-Down)")
		shadow_anchor_option.add_item("Bottom / Ground (Floor)")
		shadow_anchor_option.add_item("Custom Anchor")
		shadow_anchor_option.select(0)

	# Connect Shadow Controls
	if add_shadow_check:
		add_shadow_check.toggled.connect(func(toggled):
			if shadow_controls_box:
				shadow_controls_box.visible = toggled
			_on_settings_modified()
		)
		if shadow_controls_box:
			shadow_controls_box.visible = add_shadow_check.button_pressed

	if shadow_anchor_option:
		shadow_anchor_option.item_selected.connect(func(idx):
			if custom_anchor_box:
				custom_anchor_box.visible = (idx == 2)
			_on_settings_modified()
		)
		if custom_anchor_box:
			custom_anchor_box.visible = (shadow_anchor_option.selected == 2)

	if custom_anchor_x_spin:
		custom_anchor_x_spin.value_changed.connect(func(_val): _on_settings_modified())
	if custom_anchor_y_spin:
		custom_anchor_y_spin.value_changed.connect(func(_val): _on_settings_modified())

	var on_offset_changed = func(_val):
		if _syncing_shadow_controls: return
		_syncing_shadow_controls = true
		var off = Vector2(shadow_offset_x_spin.value if shadow_offset_x_spin else 0.0, shadow_offset_y_spin.value if shadow_offset_y_spin else 0.0)
		if shadow_dist_spin:
			shadow_dist_spin.value = off.length()
		if shadow_angle_spin and off.length() > 0.001:
			shadow_angle_spin.value = fposmod(rad_to_deg(off.angle()), 360.0)
		_syncing_shadow_controls = false
		_on_settings_modified()

	if shadow_offset_x_spin:
		shadow_offset_x_spin.value_changed.connect(on_offset_changed)
	if shadow_offset_y_spin:
		shadow_offset_y_spin.value_changed.connect(on_offset_changed)

	var on_angle_dist_changed = func(_val):
		if _syncing_shadow_controls: return
		_syncing_shadow_controls = true
		var rad = deg_to_rad(shadow_angle_spin.value if shadow_angle_spin else 0.0)
		var dist = shadow_dist_spin.value if shadow_dist_spin else 10.0
		var off = Vector2(cos(rad), sin(rad)) * dist
		if shadow_offset_x_spin: shadow_offset_x_spin.value = off.x
		if shadow_offset_y_spin: shadow_offset_y_spin.value = off.y
		_syncing_shadow_controls = false
		_on_settings_modified()

	if shadow_angle_spin:
		shadow_angle_spin.value_changed.connect(on_angle_dist_changed)
	if shadow_dist_spin:
		shadow_dist_spin.value_changed.connect(on_angle_dist_changed)

	if shadow_color_picker:
		shadow_color_picker.color_changed.connect(func(_val): _on_settings_modified())
	if shadow_scale_spin:
		shadow_scale_spin.value_changed.connect(func(_val): _on_settings_modified())
	if realtime_shadow_check:
		realtime_shadow_check.toggled.connect(func(_val): _on_settings_modified())
		
	# Connect Action Buttons
	if create_btn:
		create_btn.pressed.connect(func():
			request_create_staticbody.emit(get_options())
		)
	if regen_btn:
		regen_btn.pressed.connect(func():
			request_regenerate_collision.emit(get_options())
		)
	if preview_btn:
		preview_btn.toggled.connect(func(toggled):
			preview_toggled.emit(toggled, get_options())
		)
	if remove_btn:
		remove_btn.pressed.connect(func():
			request_remove_collision.emit()
		)

func _on_settings_modified() -> void:
	options_changed.emit(get_options())
	if preview_btn and preview_btn.button_pressed:
		preview_toggled.emit(true, get_options())

func get_options() -> Dictionary:
	return {
		"alpha_threshold": alpha_slider.value if alpha_slider else 0.5,
		"simplification_preset": simpl_option.selected if simpl_option else 1,
		"custom_epsilon": custom_eps_spin.value if custom_eps_spin else 2.5,
		"max_points": int(max_points_spin.value) if max_points_spin else 64,
		"collision_mode": collision_mode_option.selected if collision_mode_option else 0,
		"build_mode": build_mode_option.selected if build_mode_option else 0,
		"preset": preset_option.selected if preset_option else 0,
		"rotation_speed": rot_speed_spin.value if rot_speed_spin else 45.0,
		"bounce_force": bounce_force_spin.value if bounce_force_spin else 650.0,
		"star_index": int(star_index_spin.value) if star_index_spin else 1,
		"key_id": key_id_edit.text if key_id_edit else "gold",
		"collapse_delay": collapse_delay_spin.value if collapse_delay_spin else 0.8,
		"respawn_time": respawn_time_spin.value if respawn_time_spin else 3.0,
		"wind_force": wind_force_spin.value if wind_force_spin else 500.0,
		"add_shadow": add_shadow_check.button_pressed if add_shadow_check else true,
		"anchor_mode": shadow_anchor_option.selected if shadow_anchor_option else 0,
		"custom_anchor_offset": Vector2(custom_anchor_x_spin.value if custom_anchor_x_spin else 0.0, custom_anchor_y_spin.value if custom_anchor_y_spin else 0.0),
		"shadow_offset": Vector2(shadow_offset_x_spin.value if shadow_offset_x_spin else 6.0, shadow_offset_y_spin.value if shadow_offset_y_spin else 8.0),
		"light_angle": shadow_angle_spin.value if shadow_angle_spin else 53.1,
		"shadow_distance": shadow_dist_spin.value if shadow_dist_spin else 10.0,
		"shadow_color": shadow_color_picker.color if shadow_color_picker else Color(0, 0, 0, 0.45),
		"shadow_scale": shadow_scale_spin.value if shadow_scale_spin else 1.0,
		"realtime_shadow": realtime_shadow_check.button_pressed if realtime_shadow_check else true,
		"create_static_body": create_body_check.button_pressed if create_body_check else true,
		"keep_sprite": keep_sprite_check.button_pressed if keep_sprite_check else true,
		"auto_collision": auto_col_check.button_pressed if auto_col_check else true
	}

func set_target_sprite(sprite: Sprite2D) -> void:
	current_target_type = TargetType.SPRITE
	target_sprite = sprite
	target_body = null
	target_texture_path = ""
	target_texture = sprite.texture if sprite else null
	_update_target_ui()

func set_target_body(body: CollisionObject2D, sprite: Sprite2D) -> void:
	current_target_type = TargetType.STATIC_BODY
	target_body = body
	target_sprite = sprite
	target_texture_path = ""
	target_texture = sprite.texture if sprite else null
	
	# Detect existing shadow on body and sync UI controls
	if is_instance_valid(body):
		var found_shadow: Sprite2D = null
		for child in body.get_children():
			if child is Sprite2D and child != sprite and (child.name.begins_with("Shadow") or child.name.ends_with("Shadow")):
				found_shadow = child
				break
		if found_shadow:
			if add_shadow_check: add_shadow_check.button_pressed = true
			if "anchor_mode" in found_shadow and shadow_anchor_option:
				shadow_anchor_option.select(found_shadow.anchor_mode)
				if custom_anchor_box:
					custom_anchor_box.visible = (found_shadow.anchor_mode == 2)
			if "custom_anchor_offset" in found_shadow:
				if custom_anchor_x_spin: custom_anchor_x_spin.value = found_shadow.custom_anchor_offset.x
				if custom_anchor_y_spin: custom_anchor_y_spin.value = found_shadow.custom_anchor_offset.y
			if "shadow_offset" in found_shadow:
				if shadow_offset_x_spin: shadow_offset_x_spin.value = found_shadow.shadow_offset.x
				if shadow_offset_y_spin: shadow_offset_y_spin.value = found_shadow.shadow_offset.y
			elif shadow_offset_x_spin and shadow_offset_y_spin:
				shadow_offset_x_spin.value = found_shadow.position.x
				shadow_offset_y_spin.value = found_shadow.position.y
			if "light_angle_deg" in found_shadow and shadow_angle_spin:
				shadow_angle_spin.value = found_shadow.light_angle_deg
			if "shadow_distance" in found_shadow and shadow_dist_spin:
				shadow_dist_spin.value = found_shadow.shadow_distance
			if "shadow_color" in found_shadow and shadow_color_picker:
				shadow_color_picker.color = found_shadow.shadow_color
			elif shadow_color_picker:
				shadow_color_picker.color = found_shadow.modulate
			if "shadow_scale" in found_shadow and shadow_scale_spin:
				shadow_scale_spin.value = found_shadow.shadow_scale
			elif shadow_scale_spin:
				shadow_scale_spin.value = found_shadow.scale.x
			if "maintain_light_direction" in found_shadow and realtime_shadow_check:
				realtime_shadow_check.button_pressed = found_shadow.maintain_light_direction
				
	_update_target_ui()

func set_target_texture(path: String, texture: Texture2D) -> void:
	current_target_type = TargetType.TEXTURE_PATH
	target_texture_path = path
	target_texture = texture
	target_sprite = null
	target_body = null
	_update_target_ui()

func clear_target() -> void:
	current_target_type = TargetType.NONE
	target_sprite = null
	target_body = null
	target_texture_path = ""
	target_texture = null
	_update_target_ui()

func _update_target_ui() -> void:
	var has_valid_target = false
	var target_name = "No Sprite2D selected"
	var detail_text = "Select a Sprite2D in the scene or a texture in FileSystem"
	
	match current_target_type:
		TargetType.SPRITE:
			if is_instance_valid(target_sprite) and target_sprite.texture:
				has_valid_target = true
				target_name = "Detected Sprite: %s" % target_sprite.name
				detail_text = "Texture: %s (%dx%d)" % [
					target_sprite.texture.resource_path.get_file(),
					target_sprite.texture.get_width(),
					target_sprite.texture.get_height()
				]
				if target_icon: target_icon.texture = target_sprite.texture
		TargetType.STATIC_BODY:
			if is_instance_valid(target_body) and is_instance_valid(target_sprite) and target_sprite.texture:
				has_valid_target = true
				target_name = "Detected Body: %s" % target_body.name
				detail_text = "Contains Sprite: %s (%s)" % [
					target_sprite.name,
					target_sprite.texture.resource_path.get_file()
				]
				if target_icon: target_icon.texture = target_sprite.texture
		TargetType.TEXTURE_PATH:
			if target_texture:
				has_valid_target = true
				target_name = "Detected Texture: %s" % target_texture_path.get_file()
				detail_text = "FileSystem path: %s (%dx%d)" % [
					target_texture_path,
					target_texture.get_width(),
					target_texture.get_height()
				]
				if target_icon: target_icon.texture = target_texture
		_:
			if target_icon: target_icon.texture = null
			
	if target_label:
		target_label.text = target_name
	if target_info_label:
		target_info_label.text = detail_text
		
	# Enable/Disable Buttons
	if create_btn:
		create_btn.disabled = not has_valid_target
	if regen_btn:
		regen_btn.disabled = (current_target_type != TargetType.STATIC_BODY and current_target_type != TargetType.SPRITE)
	if preview_btn:
		preview_btn.disabled = not has_valid_target
	if remove_btn:
		remove_btn.disabled = (current_target_type != TargetType.STATIC_BODY and current_target_type != TargetType.SPRITE)

func set_stats(polygons_count: int, points_count: int) -> void:
	if status_label:
		status_label.text = "Generated %d polygon(s), %d vertices total." % [polygons_count, points_count]
		status_label.modulate = Color(0.4, 1.0, 0.5)

func set_status_message(msg: String, is_error: bool = false) -> void:
	if status_label:
		status_label.text = msg
		status_label.modulate = Color(1.0, 0.4, 0.4) if is_error else Color(0.8, 0.9, 1.0)
