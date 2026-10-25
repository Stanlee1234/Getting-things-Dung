extends SceneTree

func _init():
    var pcm_script = load("res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd")
    var pcm = Node.new()
    pcm.set_script(pcm_script)
    pcm.name = "PhantomCameraManager"
    root.add_child(pcm)
    
    var game_scene = load("res://Scenes/game.tscn").instantiate()
    root.add_child(game_scene)
    paused = false
    
    var ball = game_scene.get_node("DungBall")
    var beetle = game_scene.get_node("Beetle")
    
    for i in range(20):
        await physics_frame
        
    print("Ball contacts at rest: ", ball.last_contact_pos, " norm: ", ball.last_contact_normal)
    quit()
