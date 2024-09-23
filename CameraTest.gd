extends Node

var cameras: ItemList
var formats: ItemList
var activate_feed: CheckButton
var rgb: CheckButton
var separate: CheckButton
var grayscale: CheckButton
var copy: CheckButton
var selected_camera_feed: CameraFeed
var camera_texture: CameraTexture
var frame_progress: ProgressBar
var frame_index := 0
var yuyv_modes: Array


func _ready() -> void:
	assign_controls_to_variables()
	update_cameras()
	CameraServer.connect("camera_feed_added", self.camera_feed_added)
	CameraServer.connect("camera_feed_removed", self.camera_feed_removed)
	cameras.item_selected.connect(on_camera_selected)
	formats.item_selected.connect(on_format_selected)
	activate_feed.toggled.connect(on_activate_feed)
	rgb.toggled.connect(on_yuyv_mode_changed)
	separate.toggled.connect(on_yuyv_mode_changed)
	grayscale.toggled.connect(on_yuyv_mode_changed)
	copy.toggled.connect(on_yuyv_mode_changed)
	var button_group := ButtonGroup.new()
	for button in yuyv_modes:
		button.button_group = button_group
		button.disabled = true
	rgb.set_pressed_no_signal(true)


func assign_controls_to_variables() -> void:
	cameras = $Rows/Cameras
	formats = $Rows/ScrollContainer/Formats
	activate_feed = $Rows/ActivateFeed
	rgb = $Rows/Columns/RGB
	separate = $Rows/Columns/Separate
	grayscale = $Rows/Columns/Grayscale
	copy = $Rows/Columns/Copy
	camera_texture = $CameraRect.get_texture()
	frame_progress = $Rows/FrameProgress
	yuyv_modes = [rgb, separate, grayscale, copy]


func _input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func on_activate_feed(a: bool) -> void:
	if selected_camera_feed:
		selected_camera_feed.set_active(a)
		if not a:
			deactivate_selected_camera_feed()


func update_cameras() -> void:
	deactivate_selected_camera_feed()
	cameras.clear()
	formats.clear()
	for index in range(0, CameraServer.get_feed_count()):
		var camera_feed := CameraServer.get_feed(index)
		var _ignore = cameras.add_item(camera_feed.get_name())


func on_camera_selected(index: int) -> void:
	deactivate_selected_camera_feed()
	if selected_camera_feed:
		activate_feed.set_pressed_no_signal(false)
		selected_camera_feed.format_changed.disconnect(on_format_changed)
		selected_camera_feed.frame_changed.disconnect(on_frame_changed)
	selected_camera_feed = CameraServer.get_feed(index)
	var _ignore = selected_camera_feed.format_changed.connect(on_format_changed)
	_ignore = selected_camera_feed.frame_changed.connect(on_frame_changed)
	camera_texture.set_camera_feed_id(selected_camera_feed.get_id())
	update_formats()


func update_formats() -> void:
	formats.clear()
	var format_index := 0
	for d in selected_camera_feed.get_formats():
		var fps = str(d["frame_denominator"]) if d["frame_numerator"] == 1 else str(d["frame_denominator"], "/", d["frame_numerator"])
		if d["frame_numerator"] < 0:
			fps = "??"
		var _ignore = formats.add_item("%d: %s %dx%d@%sfps" % [format_index, d["format"], d["width"], d["height"], fps])
		format_index += 1
	activate_feed.disabled = true
	for button in yuyv_modes:
		button.disabled = true


func on_format_changed() -> void:
	print("Format changed")


func on_frame_changed() -> void:
	frame_index = (frame_index + 1) % 100
	frame_progress.call_deferred("set_value", frame_index)


func on_format_selected(index: int) -> void:
	var feed_active = activate_feed.is_pressed()
	deactivate_selected_camera_feed()
	var parameters := {}
	if separate.is_pressed():
		parameters = {"output": "separate"} 
	if grayscale.is_pressed():
		parameters = {"output": "grayscale"} 
	if copy.is_pressed():
		parameters = {"output": "copy"} 
	if selected_camera_feed:
		var _ignore = selected_camera_feed.set_format(index, parameters)
	activate_feed.disabled = false
	for button in yuyv_modes:
		button.disabled = false
	if feed_active:
		activate_feed.button_pressed = true


func on_yuyv_mode_changed(_unused: bool) -> void:
	on_format_selected(formats.get_selected_items()[0])


func camera_feed_added(_id: int):
	update_cameras.call_deferred()


func camera_feed_removed(_id: int):
	update_cameras.call_deferred()

func deactivate_selected_camera_feed() -> void:
	activate_feed.button_pressed = false
	frame_index = 0
	frame_progress.value = 0
	
