extends Node

var player_count: int = 2
var player_configs: Array = []
var sound_enabled: bool = true
var music_enabled: bool = true

func is_valid() -> bool:
    if player_configs.size() < 2:
        return false
    if player_configs.size() > 4:
        return false
    return _all_characters_unique()

func _all_characters_unique() -> bool:
    var used = []
    for config in player_configs:
        var cid = config.get("character_id", "")
        if cid == "":
            return false
        if cid in used:
            return false
        used.append(cid)
    return true

func reset() -> void:
    player_count = 2
    player_configs = []
