extends Node2D

####### VARIABLES ######

enum actions {UP=0,RIGHT=1,DOWN=2,LEFT=3}
var map

var state
var explored_map = {}
var steps_taken := []

var goal_found = false
var running = false

var pos

var qtable = {}
var rewards = {}

var learning_rate = 0.8 
var discount_rate = .99
var epsilon = 0.1

func _ready():
	set_physics_process(false)


## called by the Maze when it is done setting up
func ready():
	pause_mode = Node.PAUSE_MODE_STOP
	map = get_parent()
	# sets the initial values needed to start
	state = map.default_state
	pos = position/map.tile_size
	explored_map[pos] = [null,null,null,null]
	rewards[pos] = 0
	map.add_pos(pos)
	
	set_physics_process(true)


## called once per frame
func _physics_process(delta):
	step()


func step():
	# since a step may still be in process when _physics_process() is called again,
	# we lock our function with "running"
	if not running:
		running = true
		if goal_found:
			move_backwards()
		else:
			move_forwards()
		# Pauses briefly after each step
		# to make the process more watchable
		yield(get_tree().create_timer(.03),"timeout")
		running = false


## Recursively moves backwards through the explored map and fills the Q table 
func move_backwards():
	# states_to_visit "inverts" the explored map so it can be traversed backwards
	var states_to_visit = {}
	for key in explored_map:
		var val = explored_map[key]
		for pos in val:
			if not states_to_visit.keys().has(pos):
				states_to_visit[pos] = []
			states_to_visit[pos].append(key)
	states_to_visit.erase(null)
	
	# Fills all Q table states with an initial value. This is necessary for the proper filling in the next step
	for state in explored_map:
		if not state in rewards:
			qtable[state] = -INF
		else:
			qtable[state] = rewards[state]
		
	
	# Recursive backtracker to fill the Q table
	var queue = [pos]
	var explored = []
	while queue.size() > 0:
		if not queue.front() in explored:
			explored.append(queue.front())
		for state in states_to_visit[queue.front()]:
			if not state in explored:
				queue.append(state)
		queue.pop_front()
	
	
	#table_queue = _fill_qtable_queue(states_to_visit,table_queue,[])
	
	for state in explored:
		#print(state)
		qtable[state] = rewards[state] + discount_rate * get_best_neighbor(state,states_to_visit[state])[1]
	
	print_results()
	
	# Reset the solver to its default position
	position = Vector2.ZERO
	pos = position
	state = position
	goal_found = false


func _fill_qtable_queue(states_to_visit,queue,explored):
	explored.append(queue[0])
	for state in states_to_visit[queue[0]]:
		if not state in queue:
			queue.append(state)
	for state in states_to_visit[queue[0]]:
		if not state == queue[0] and not state in explored:
			queue = _fill_qtable_queue(states_to_visit,queue,explored)
	return queue


## Fills the Q table using an adapted Q learning algorithm where alpha is always 1
func _fill_qtable(states_to_visit,current_pos,visited):
	for state in states_to_visit[current_pos]:
		if qtable[state] < qtable[current_pos]:
			qtable[state] = rewards[state] + discount_rate * get_best_neighbor(state,states_to_visit[state])[1]
			visited.append(state)
			_fill_qtable(states_to_visit,state,visited)


## Returns the best neighbor and its Q value
## If all neighbors have a value of 0 or lower, returns a random neighbor
func get_best_neighbor(pos,neighbors):
	var best_neighbor = neighbors[randi()%neighbors.size()]
	while best_neighbor == pos:
		best_neighbor = neighbors[randi()%neighbors.size()]
	var best_value = 0
	var best_neighbors = [best_neighbor]
	for neighbor in neighbors:
		if neighbor != null and neighbor in qtable and qtable[neighbor] > best_value and neighbor != pos:
			best_neighbor = neighbor
			best_value = qtable[best_neighbor]
			best_neighbors = [best_neighbor]
		elif neighbor != null and neighbor in qtable and qtable[neighbor] == best_value and neighbor != pos:
			best_neighbors.append(neighbor)
	return [best_neighbors[randi()%best_neighbors.size()],best_value]


## Explores the map by always exploring unknown tiles and otherwise following the best path
func move_forwards():
	var exploring = false
	var chosen_direction = -1
	
	# if there is an unknown path we always want to explore it
	if has_unexplored_path(explored_map[pos]):
		exploring = true
		chosen_direction = get_unexplored_path(explored_map[pos])
	# if there isn't, we choose the direction with the highest Q value
	else:
		chosen_direction = get_direction_to(pos,get_best_neighbor(pos,explored_map[pos])[0])
	
	var old_pos = pos
	# Tell the environment where are and what we want to do
	# result = [new_state, reward, done, hit_wall]
	var result = map.step(state,chosen_direction)
	pos = position/map.tile_size
	state = result[0]
	
	# Add the new position to the position and direction we came from
	explored_map[old_pos][chosen_direction] = pos
	
	# If we haven't been to this position before, we need to initialize it
	if not pos in explored_map.keys():
		explored_map[pos] = [null,null,null,null]
		rewards[pos] = result[1]
	
	# If we haven't hit a wall, we remember where we came from
	if not result[3]:
		explored_map[pos][go_back(chosen_direction)] = old_pos
		steps_taken.append(chosen_direction)
	
	# If we reached the end, we prepare for filling the Q table backwards
	if result[2]:
		goal_found = true
		rewards[pos] = result[1]
		qtable[pos] = result[1]
		return
	
	# If we find a tile that doesn't have unexplored directions, we backtrack until we find one that does
	# To prevent the Solver from constantly backtracking after the first round of exploration, 
	# it will only do this if it doesn't have a "Q value path" to follow
	while not has_unexplored_path(explored_map[pos]) and exploring and not get_best_neighbor(pos,explored_map[pos])[1] > 0:
		if not steps_taken.size(): return
		result = map.step(state,go_back(steps_taken[steps_taken.size()-1]))
		pos = position/map.tile_size
		steps_taken.remove(steps_taken.size()-1)
		state = result[0]


## Gets the direction needed to travel from pos to new_pos.
## Returns -1 if this is impossible.
func get_direction_to(pos,new_pos):
	for i in range(explored_map[pos].size()):
		if new_pos == explored_map[pos][i]:
			return i
	return -1


## Adds a label containing the Q value of each state to each known position
## These values should decrease from the terminal state
func print_results():
	for child in map.Results.get_children():
		map.Results.remove_child(child)
	for state in qtable:
		var n = Node2D.new()
		var l = Label.new()
		# Limits the text to two decimal places to increase readability
		l.text = str(stepify(qtable[state],.01))
		# Makes the text red to increase readability
		l.modulate = Color.crimson
		# Moves the text from the corner closer to the center of the tile
		n.position = (state+Vector2(.35,.35))*map.tile_size
		n.add_child(l)
		map.Results.add_child(n)


## Returns the opposite of the given direction
func go_back(dir):
	match dir:
		actions.UP: return actions.DOWN
		actions.DOWN: return actions.UP
		actions.LEFT: return actions.RIGHT
		actions.RIGHT: return actions.LEFT
		_: return -1 # error case


## Returns a random unexplored direction from a given position
## If there are no unexplored directions, returns null
func get_unexplored_path(slot):
	var unexplored = []
	for direction in range(actions.size()):
		if slot[direction] == null:
			unexplored.append(direction)
	
	# Prevents going back by removing the opposite of the last taken step
	if steps_taken:
		for i in range(unexplored.size()):
			if unexplored[i] == go_back(steps_taken[steps_taken.size()-1]):
				unexplored.remove(i)
				break
	
	if unexplored.size() > 0:
		return unexplored[randi() % unexplored.size()]
	else:
		return null

## Checks if a given position has unexplored directions
func has_unexplored_path(slot):
	var unexplored = []
	for direction in range(actions.size()):
		if slot[direction] == null:
			unexplored.append(direction)
	
	# Prevents going back by removing the opposite of the last taken step
	if steps_taken:
		for i in range(unexplored.size()):
			if unexplored[i] == go_back(steps_taken[steps_taken.size()-1]):
				unexplored.remove(i)
				break
	
	return unexplored.size() > 0
