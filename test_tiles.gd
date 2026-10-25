extends SceneTree

func _init():
    var game_scene = load("res://Scenes/game.tscn").instantiate()
    var tilemap = game_scene.get_node("TileMapLayer")
    var used_cells = tilemap.get_used_cells()
    var sources = {}
    for c in used_cells:
        var src = tilemap.get_cell_source_id(c)
        sources[src] = sources.get(src, 0) + 1
    print("Sources: ", sources)
    quit()
