extends Node

var sizes = [50]
var maps_to_check = 50
var episodes = 25


const N = 1
const E = 2
const S = 4
const W = 8

var cell_walls = {Vector2(0, -1): N, Vector2(1, 0): E, 
				  Vector2(0, 1): S, Vector2(-1, 0): W}

var wall_cells = {N:Vector2(0, -1), E:Vector2(1, 0), S:Vector2(0, 1), W:Vector2(-1, 0)}

func _input(event):
	# pause
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = not get_tree().paused

onready var Maze = $Maze

func _ready():
	randomize()
	run()


func run():
	print("starting time: " + str(OS.get_time()))
	for size in sizes:
		print("size ",size)
		#var qfile = File.new()
		var bqfile = File.new()
		#qfile.open("data/q"+str(size)+".txt", File.WRITE)
		bqfile.open("data/bq"+str(size)+".txt", File.WRITE)
		for i in range(maps_to_check):
			print("new map ",i," at " + str(OS.get_time()))
			Maze.ready(make_maze(size,size),size,size)
			
			#var qsolver = QSolver.new()
			#Maze.add_child(qsolver)
			#Maze.Solver = qsolver
			#qfile.store_string("MAP " + str(i) + "\n")
			#qsolver.ready(episodes,INF,qfile)
			#yield(qsolver,"done")
			#qsolver.queue_free()
			
			var bqsolver = BQSolver.new()
			Maze.add_child(bqsolver)
			Maze.Solver = bqsolver
			bqfile.store_string("MAP " + str(i) + "\n")
			bqsolver.ready(episodes,INF,bqfile)
			yield(bqsolver,"done")
			bqsolver.queue_free()
			
		#qfile.close()
		bqfile.close()
	print("DONE")
	print("ending time: " + str(OS.get_time()))



func make_maze(width,height):
	# array of unvisited tiles
	var Map = TileMap.new()
	Map.tile_set = load("road_tiles.tres")
	Map.cell_size = Vector2(64,64)
	
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
		# yield(get_tree(), 'idle_frame')
	
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
	return Map


# returns an array of cell's unvisited neighbors
func check_neighbors(cell, unvisited):
	var list = []
	for n in cell_walls.keys():
		if cell + n in unvisited:
			list.append(cell + n)
	return list
