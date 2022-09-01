extends Node2D

const N = 1
const E = 2
const S = 4
const W = 8

var cell_walls = {Vector2(0, -1): N, Vector2(1, 0): E, 
				  Vector2(0, 1): S, Vector2(-1, 0): W}

var wall_cells = {N:Vector2(0, -1), E:Vector2(1, 0), S:Vector2(0, 1), W:Vector2(-1, 0)}

enum actions {UP=0,RIGHT=1,DOWN=2,LEFT=3}

var tile_size  # tile size (in pixels)
export var width = 10  # width of map (in tiles)
export var height = 10  # height of map (in tiles)

onready var white = preload("white.png")
var sprites = {}
onready var Map = $TileMap
onready var Results = $Results

var default_state
var Solver

var array_map = {}

func ready(map,w,h):
	Map = map
	width = w
	height = h
	for pos in map.get_used_cells():
		array_map[pos] = map.get_cellv(pos)
	tile_size = Vector2(64,64)
	default_state = calculate_state(Vector2(0,0))


func scale_camera():
	var cam = $TileMap/Camera2D
	if get_viewport().size.x < width*tile_size.x:
		cam.zoom.x = (width*tile_size.x)/get_viewport().size.x
	if get_viewport().size.y < height*tile_size.y:
		cam.zoom.y = (height*tile_size.y)/get_viewport().size.y
	if cam.zoom.y < cam.zoom.x: cam.zoom.y = cam.zoom.x
	else: cam.zoom.x = cam.zoom.y


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
		Solver.position += dir
	else:
		hit_wall = true
	
	if not checking:
		add_pos(Solver.position)
	state = calculate_state(Solver.position)
	var reward = calculate_reward(hit_wall,state)
	return [state,reward,reward>=0,hit_wall]


## Calculates the state
func calculate_state(pos):
	#var s = pos/tile_size
	return pos


## the bottom right corner is the terminal state
func calculate_reward(hit_wall,state):
	if state == Vector2(width-1,height-1): 
		return 10
	if hit_wall:
		return -5
	else:
		return -1


## Checks for a wall in the direction from the state
func can_move(state,direction):
	#var tile = Map.get_cellv(Map.world_to_map(state*tile_size))
	var tile = array_map[state]
	# The tile index is treated as four bit flags
	# and the direction is the position for the bit to check
	# e.g. 9 is a tile where you can move down. Down is position 2, so 2^2 or 4
	# ~1001 & 0100 = 0100
	# 6 is a tile where you cannot move down
	# ~0110 & 0100 = 0000
	return ~tile & int(pow(2,direction))


## Highlights a tile once it has been visited by the solver
func add_pos(pos):
	return
	if not pos in sprites:
		var n = Sprite.new()
		n.centered = false
		n.texture = white
		n.scale = tile_size
		n.position = pos
		Results.add_child(n)
		sprites[pos] = n


func paint_pos(pos,color):
	return
	pos *= tile_size
	if not pos in sprites: return
	var tile = sprites[pos]
	tile.set_modulate(color)


func print_value(pos,val):
	return
	val = int(val)
	pos *= tile_size
	pos += tile_size/3
	var label = Label.new()
	label.text = str(val)
	label.modulate = Color.black
	label.rect_global_position = pos
	$Results.add_child(label)


func wipe_values():
	for c in $Results.get_children():
		c.queue_free()


func wipe_value(pos):
	pos *= tile_size
	pos += tile_size/3
	for c in $Results.get_children():
		if c is Sprite and c.position == pos or c is Label and c.rect_global_position == pos:
			c.queue_free()
			break


