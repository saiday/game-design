class_name SeededRng
extends RefCounted
# Deterministic named-track RNG: one stream per system (map/battle/opportunity/rivals/
# democracy/naming) so systems don't perturb each other's sequences. Same run seed +
# same call order within a track => identical outcomes, which is what makes full-run
# simulation tests reproducible.

var _run_seed: int
var _tracks: Dictionary = {}


func _init(run_seed: int) -> void:
	_run_seed = run_seed


func track(track_name: StringName) -> RandomNumberGenerator:
	if not _tracks.has(track_name):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s" % [_run_seed, track_name])
		_tracks[track_name] = rng
	return _tracks[track_name] as RandomNumberGenerator


func randi_range(track_name: StringName, from: int, to: int) -> int:
	return track(track_name).randi_range(from, to)


func randf(track_name: StringName) -> float:
	return track(track_name).randf()


func chance(track_name: StringName, probability: float) -> bool:
	return track(track_name).randf() < probability


func pick(track_name: StringName, options: Array) -> Variant:
	assert(not options.is_empty())
	return options[track(track_name).randi_range(0, options.size() - 1)]


func weighted_pick(track_name: StringName, weights: Dictionary) -> Variant:
	# weights: option -> numeric weight (> 0)
	assert(not weights.is_empty())
	var total := 0.0
	for w: Variant in weights.values():
		total += float(w)
	var roll := track(track_name).randf() * total
	for option: Variant in weights.keys():
		roll -= float(weights[option])
		if roll < 0.0:
			return option
	return weights.keys().back()
