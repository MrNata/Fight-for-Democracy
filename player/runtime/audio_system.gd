extends Node
const CHANNELS = ["Music", "Effects", "Voices", "Crowd", "Ambience", "UI"]
var root = ""
var last_played: Dictionary = {}
var rng = RandomNumberGenerator.new()
var music: AudioStreamPlayer
var impact_file = ""

func _ready() -> void:
	rng.randomize()
	for channel in CHANNELS:
		if AudioServer.get_bus_index(channel) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1, channel)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	add_child(music)

func set_volume(channel: String, value: float) -> void:
	var index = AudioServer.get_bus_index(channel)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(value, 0.0001, 1)))

func load_stream(path: String) -> AudioStream:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return load(path) as AudioStream
	match path.get_extension().to_lower():
		"wav": return AudioStreamWAV.load_from_file(path)
		"ogg": return AudioStreamOggVorbis.load_from_file(path)
		"mp3": return AudioStreamMP3.load_from_file(path)
	return null

func play_file(relative: String, channel: String = "Voices", volume: float = 1.0) -> void:
	var stream = load_stream(relative if relative.is_absolute_path() else root.path_join(relative))
	if stream == null:
		return
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = channel
	player.volume_db = linear_to_db(maxf(0.0001, volume))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func voice(character: Dictionary, event: String) -> void:
	var clips: Array = character.get("voices", {}).get(event, [])
	var eligible: Array = []
	var total = 0.0
	var seconds = Time.get_ticks_msec() / 1000.0
	for clip in clips:
		var key = character.id + "/" + event + "/" + clip.file
		if seconds - float(last_played.get(key, -1000)) >= float(clip.interval):
			eligible.append(clip)
			total += float(clip.weight)
	if eligible.is_empty():
		return
	var choice = rng.randf() * total
	for clip in eligible:
		choice -= float(clip.weight)
		if choice <= 0:
			last_played[character.id + "/" + event + "/" + clip.file] = seconds
			play_file(clip.file, "Voices", clip.volume)
			return

func tone(frequency: float = 180.0) -> void:
	if not impact_file.is_empty():
		play_file(impact_file,"Effects",0.8)
		return
	## Original temporary synthesized impact; no imitation of a human voice.
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples = PackedByteArray()
	samples.resize(2205*2)
	for i in 2205:
		var sample = sin(TAU*frequency*i/22050.0) * exp(-i/400.0) * 12000
		samples.encode_s16(i*2,int(sample))
	stream.data = samples
	var player = AudioStreamPlayer.new()
	player.bus = "Effects"
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
