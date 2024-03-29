extends Node2D

const N = 1
const E = 2
const S = 4
const W = 8

enum actions {UP=0,RIGHT=1,DOWN=2,LEFT=3}

var cell_walls = {Vector2(0, -1): N, Vector2(1, 0): E, 
				  Vector2(0, 1): S, Vector2(-1, 0): W}

var wall_cells = {N:Vector2(0, -1), E:Vector2(1, 0), S:Vector2(0, 1), W:Vector2(-1, 0)}

var tile_size  # tile size (in pixels)
export var width = 10  # width of map (in tiles)
export var height = 10  # height of map (in tiles)

onready var white = preload("white.png")
var sprites = {}
onready var Map = $TileMap
onready var Solver = $Solver
onready var Results = $Results

var default_state

var started = false


func _input(event):
	# pause
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = not get_tree().paused


# returns an array of cell's unvisited neighbors
func check_neighbors(cell, unvisited):
	var list = []
	for n in cell_walls.keys():
		if cell + n in unvisited:
			list.append(cell + n)
	return list


func scale_camera():
	var cam = $TileMap/Camera2D
	if get_viewport().size.x < width*tile_size.x:
		cam.zoom.x = (width*tile_size.x)/get_viewport().size.x
	if get_viewport().size.y < height*tile_size.y:
		cam.zoom.y = (height*tile_size.y)/get_viewport().size.y
	if cam.zoom.y < cam.zoom.x: cam.zoom.y = cam.zoom.x
	else: cam.zoom.x = cam.zoom.y


## Creates the maze for the agent to explore
## Algorithm adapted from https://github.com/kidscancode/godot3_procgen_demos
func make_maze():
	pause_mode = Node.PAUSE_MODE_PROCESS
	# array of unvisited tiles
	var unvisited = []  
	var stack = []
	
	# fill the map with solid tiles
	Map.clear()
	for x in range(width):
		for y in range(height):
			unvisited.append(Vector2(x, y))
			Map.set_cellv(Vector2(x, y), N|E|S|W)
	var current = Vector2(0, 0)
	unvisited.erase(current)
	
	# execute recursive backtracker algorithm
	while unvisited:
		var neighbors = check_neighbors(current, unvisited)
		if neighbors.size() > 0:
			var next = neighbors[randi() % neighbors.size()]
			stack.append(current)
			
			# remove walls from *both* cells
			var dir = next - current
			var current_walls = Map.get_cellv(current) - cell_walls[dir]
			var next_walls = Map.get_cellv(next) - cell_walls[-dir]
			Map.set_cellv(current, current_walls)
			Map.set_cellv(next, next_walls)
			current = next
			unvisited.erase(current)
		
		elif stack:
			current = stack.pop_back()
		
		# skips a frame to update the map before continuing
		#yield(get_tree(), 'idle_frame')
	
	# create alternate paths
	for i in range((width*height)/4):
		var x = int(rand_range(1,width-1))
		var y = int(rand_range(1,height-1))
		var dirs = [N,E,S,W]
		var chosen = dirs[randi()%4]
		Map.set_cell(x,y,~(~Map.get_cell(x,y) | chosen))
		var to_pos = Vector2(x+wall_cells[chosen].x,y+wall_cells[chosen].y)
		var new_dir = 0
		match chosen:
			N: new_dir = S
			S: new_dir = N
			E: new_dir = W
			W: new_dir = E
		Map.set_cellv(to_pos,~(~Map.get_cellv(to_pos) | new_dir))
		
		#yield(get_tree(), 'idle_frame')
	Solver.ready()


## moves the actor by a step and returns all relevant information 
## (new state, reward, episode finished and if it hit a wall)
func step(state,action,checking=false):
	var hit_wall = false
	
	var dir = Vector2.ZERO
	match action:
		0: dir = Vector2.UP
		1: dir = Vector2.RIGHT
		2: dir = Vector2.DOWN
		3: dir = Vector2.LEFT
		_: pass #print(action)
	
	if can_move(state,action):
		Solver.position += dir*tile_size
	else:
		hit_wall = true
	
	if not checking:
		add_pos(Solver.position)
	state = calculate_state(Solver.position)
	var reward = calculate_reward(hit_wall,state)
	return [state,reward,reward>=10,hit_wall]


## Calculates the state
func calculate_state(pos):
	var s = pos/tile_size
	return s


## the bottom right corner is the terminal state
func calculate_reward(hit_wall,state):
	if state == Vector2(width-1,height-1): # or state == Vector2(width-1,0): 
		return 10
	if hit_wall:
		return -5
	else:
		return -1


## Checks for a wall in the direction from the state
func can_move(state,direction):
	var tile = Map.get_cellv(Map.world_to_map(state*tile_size))
	# The tile index is treated as four bit flags
	# and the direction is the position for the bit to check
	# e.g. 9 is a tile where you can move down. Down is position 2, so 2^2 or 4
	# ~1001 & 0100 = 0100
	# 6 is a tile where you cannot move down
	# ~0110 & 0100 = 0000
	return ~tile & int(pow(2,direction))


## Highlights a tile once it has been visited by the solver
func add_pos(pos):
	if not pos in sprites:
		var n = Sprite.new()
		n.centered = false
		n.texture = white
		n.scale = tile_size
		n.position = pos
		Results.add_child(n)
		sprites[pos] = n


func paint_pos(pos,color):
	pos *= tile_size
	if not pos in sprites: return
	var tile = sprites[pos]
	tile.set_modulate(color)


func print_value(pos,val):
	val = int(val)
	pos *= tile_size
	pos += tile_size/3
	var label = Label.new()
	label.text = str(val)
	label.rect_global_position = pos
	$Results.add_child(label)


func wipe_values():
	for c in $Results.get_children():
		c.queue_free()


func wipe_value(pos):
	pos *= tile_size
	pos += tile_size/3
	#for c in $Results.get_children():
	#	if c.rect_global_position == pos:
	#		c.queue_free()
	#		break

## Starts the algorithm with the chosen type
func _on_Button_pressed(type):
	remove_child($BackwardsLearner)
	remove_child($ReinforcementLearner)
	tile_size = Map.cell_size
	default_state = calculate_state(Vector2(0,0))
	Solver.set_script(load(type+".gd"))
	started = true
	randomize()
	scale_camera()
	make_maze()
