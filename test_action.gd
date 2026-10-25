extends SceneTree
func _init():
    Input.action_press("right")
    print("axis: ", Input.get_axis("left", "right"))
    quit()
