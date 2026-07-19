extends Node
## Autoload. Player settings, persisted to disk and applied on boot so the game
## comes up the way it was left.

const PATH := "user://settings.cfg"

var volume: float = 0.8       # 0..1, master bus
var fullscreen: bool = false

func _ready() -> void:
	load_settings()
	apply()

func apply() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),
		linear_to_db(clampf(volume, 0.0001, 1.0)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), volume <= 0.001)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)

func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	apply()
	save_settings()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply()
	save_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	volume = float(cfg.get_value("audio", "volume", volume))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(PATH)
