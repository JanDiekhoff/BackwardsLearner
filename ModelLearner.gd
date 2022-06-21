extends Node2D

####### VARIABLES ######

enum actions {UP=0,RIGHT=1,DOWN=2,LEFT=3}
var map

var old_state
var state
var explored_map = {}
var steps_taken := []
var unexplored_states = []

var goal_found = false
var running = false

var qtable = {}
var rewards = {}

var learning_rate = 0.8 
var discount_rate = .99
var epsilon = .1
var exploration_round = false

func _ready():
	set_physics_process(false)


## called by the Maze when it is done setting up
func ready():
	pause_mode = Node.PAUSE_MODE_STOP
	map = get_parent()
	# sets the initial values needed to start
	state = map.default_state
	old_state = state
	explored_map[state] = [null,null,null,null]
	unexplored_states.append(state)
	rewards[state] = 0
	map.add_pos(state)
	
	set_physics_process(true)


## called once per frame
func _physics_process(delta):
	move()


func move():
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
	var queue = [state]
	var explored = []
	while queue.size() > 0:
		if not queue.front() in explored:
			explored.append(queue.front())
		for state in states_to_visit[queue.front()]:
			if not state in explored:
				queue.append(state)
		queue.pop_front()
	
	for state in explored:
		qtable[state] = rewards[state] + discount_rate * get_best_neighbor(state,states_to_visit[state])[1]
	print_results()
	
	# Reset the solver to its default position
	position = Vector2.ZERO
	steps_taken.clear()
	state = position
	goal_found = false
	var i = 0
	for s in unexplored_states:
		if not has_unexplored_path(explored_map[s]): 
			unexplored_states.remove(i)
		i+=1
	
	# decide, if the next round will be an exploration round
	exploration_round = unexplored_states.size() > 0 and randf() <= epsilon


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
	old_state = state
	
	# explore unknown paths that are not directly adjacent to the path
	if exploration_round:
		# to find the path to a position with an unknown path, A* is used
		var astar = AStar2D.new()
		var back = {}
		var x = 0
		for point in explored_map:
			astar.add_point(x,point)
			back[point] = x
			x += 1
		for point in explored_map:
			for neighbor in explored_map[point]:
				if neighbor != null and neighbor != point and neighbor: 
					astar.connect_points(back[point],back[neighbor])
		var unexplored_pos = unexplored_states[randi() % unexplored_states.size()]
		var path = astar.get_point_path(back[state],back[unexplored_pos])
		path.remove(0)
		for point in path:
			var result = map.step(state,get_direction_to(state,point))
			old_state = state
			state = result[0]
		
		# travel the unknown path, until we hit a known tile
		while has_unexplored_path(explored_map[state]):
			chosen_direction = get_unexplored_path(explored_map[state])
			var result = map.step(state,chosen_direction)
			old_state = state
			state = result[0]
			if not state in explored_map.keys():
				explored_map[state] = [null,null,null,null]
				if not result[2]:
					unexplored_states.append(state)
			if not has_unexplored_path(explored_map[state]):
				var i = 0
				for s in unexplored_states:
					if s == old_state: 
						unexplored_states.remove(i)
						break
					i+=1
			
			explored_map[old_state][chosen_direction] = state
			if not result[3]: 
				rewards[state] = result[1]
				steps_taken.append(chosen_direction)
				explored_map[state][go_back(chosen_direction)] = old_state
	
	# if there is an unexplored path next to us, take it
	if has_unexplored_path(explored_map[state]):
		exploring = true
		chosen_direction = get_unexplored_path(explored_map[state])
	# if there isn't, we choose the direction with the highest Q value
	else:
		exploration_round = false
		chosen_direction = get_direction_to(state,get_best_neighbor(state,explored_map[state])[0])
	
	# Tell the environment where are and what we want to do
	# result = [new_state, reward, done, hit_wall]
	var result = map.step(state,chosen_direction)
	old_state = state
	state = result[0]
	
	# Add the new position to the position and direction we came from
	explored_map[old_state][chosen_direction] = state
	if not has_unexplored_path(explored_map[old_state]):
		var i = 0
		for s in unexplored_states:
			if s == old_state: 
				unexplored_states.remove(i)
				break
			i+=1

	# If we haven't been to this position before, we need to initialize it
	if not state in explored_map.keys():
		explored_map[state] = [null,null,null,null]
		rewards[state] = result[1]
	
	check_neighbor(state)
	if not state in unexplored_states and has_unexplored_path(explored_map[state]):
		unexplored_states.append(state)
	
	
	# If we haven't hit a wall, we remember where we came from
	if not result[3]:
		explored_map[state][go_back(chosen_direction)] = old_state
		steps_taken.append(chosen_direction)
	
	# If we reached the end, we prepare for filling the Q table backwards
	if result[2]:
		goal_found = true
		rewards[state] = result[1]
		qtable[state] = result[1]
		return
	
	# If we find a tile that doesn't have unexplored directions, we backtrack until we find one that does
	# To prevent the Solver from constantly backtracking after the first round of exploration, 
	# it will only do this if it doesn't have a "Q value path" to follow
	while not has_unexplored_path(explored_map[state]) and exploring and not get_best_neighbor(state,explored_map[state])[1] > 0:
		if not steps_taken.size(): return
		result = map.step(state,go_back(steps_taken[steps_taken.size()-1]))
		old_state = state
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


## checks, which neighboring states are walls
func check_neighbor(state):
	if not state in explored_map: return
	for i in range(explored_map[state].size()):
		if explored_map[state][i] == null:
			var result = map.step(state,i,true)
			if result[3]:
				explored_map[state][i] = state
			else:
				map.step(result[0],go_back(i))
