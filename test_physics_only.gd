extends SceneTree

func _init():
    var ball = RigidBody2D.new()
    var ball_col = CollisionShape2D.new()
    var ball_circle = CircleShape2D.new()
    ball_circle.radius = 30.0
    ball_col.shape = ball_circle
    ball.add_child(ball_col)
    ball.position = Vector2(0, 100)
    root.add_child(ball)
    
    var floor_body = StaticBody2D.new()
    var floor_col = CollisionShape2D.new()
    var floor_shape = WorldBoundaryShape2D.new()
    floor_shape.normal = Vector2(0, -1)
    floor_shape.distance = 0.0
    floor_col.shape = floor_shape
    floor_body.position = Vector2(0, 130)
    floor_body.add_child(floor_col)
    root.add_child(floor_body)
    
    var cb = CharacterBody2D.new()
    var cb_col = CollisionShape2D.new()
    var cb_box = RectangleShape2D.new()
    cb_box.size = Vector2(25, 40)
    cb_col.shape = cb_box
    cb.add_child(cb_col)
    cb.position = Vector2(0, 45)
    root.add_child(cb)
    
    for i in range(60):
        await physics_frame
        cb.velocity.y += 980.0 * (1.0/60.0)
        cb.velocity.x = 100.0
        cb.move_and_slide()
        if i % 10 == 0:
            print("Frame ", i, " ball pos: ", ball.position, " vel: ", ball.linear_velocity, " ang: ", ball.angular_velocity, " cb pos: ", cb.position)
    
    quit()
