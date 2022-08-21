extends Node2D

####### VARIABLES ######

enum actions {UP=0,RIGHT=1,DOWN=2,LEFT=3}
var map

var old_state
var current_state
var explored_map = {}
var steps_taken := []
var unexplored_states = []
var terminal_states = []

var goal_found = false
var running = false

var qtable = {}
var rewards = {}

var discount_rate = .99
var epsilon = 1
var exploration_round = false

func _ready():
	set_physics_process(false)


## called by the Maze when it is done setting up
func ready():
	pause_mode = Node.PAUSE_MODE_STOP
	map = get_parent()
	# sets the initial values needed to start
	current_state = map.default_state
	old_state = current_state
	explored_map[current_state] = [null,null,null,null]
	rewards[current_state] = [null,null,null,null]
	unexplored_states.append(current_state)
	map.add_pos(current_state)
	
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
	# Fills all Q table states with an initial value. This is necessary for the proper filling in the next step
	for state in explored_map:
		if not state in qtable:
			qtable[state] = [0,0,0,0]
	
	# states_to_visit "inverts" the explored map so it can be traversed backwards
	var states_to_visit = {}
	for key in explored_map:
		var val = explored_map[key]
		for pos in val:
			if not states_to_visit.keys().has(pos):
				states_to_visit[pos] = []
			states_to_visit[pos].append(key)
	#states_to_visit.erase(null)
	
	
	for terminal in terminal_states:
		# Backtracker to fill the Q table
		var queue = [terminal]
		var explored = []
		while queue.size() > 0:
			if not queue.front() in explored:
				explored.append(queue.front())
			for state in states_to_visit[queue.front()]:
				if not state in explored:
					queue.append(state)
			queue.pop_front()
		
		# Adapted Q Learning function
		var next_terminal = false
		if not next_terminal:
			for state in explored:
				if state in terminal_states: continue
				for action in range(explored_map[state].size()):
					if not rewards[state][action] == null:
						var reward = rewards[state][action]
						var best_neighbour = qtable[explored_map[state][action]].max()
						var result = reward + discount_rate * best_neighbour
						if result >= qtable[state][action] or qtable[state][action] == 0:
							if result == 0: print(result)
							qtable[state][action] = result
						else: next_terminal = true
	
	draw_results()
	
	# Reset the solver to its default position
	position = Vector2.ZERO
	steps_taken.clear()
	current_state = position
	goal_found = false
	var i = 0
	for s in unexplored_states:
		if not has_unexplored_path(s): 
			unexplored_states.remove(i)
		i+=1
	
	# decide, if the next round will be an exploration round
	exploration_round = unexplored_states.size() > 0 and randf() <= epsilon


func get_best_move(state):
	var best_val = -INF
	var best_actions = []
	
	if not current_state in qtable:
		return [best_val,randi()%4]
	
	for a in explored_map[current_state].size():
		if qtable[current_state][a] > best_val:
			best_val = qtable[current_state][a]
			best_actions = [a]
		elif qtable[current_state][a] == best_val:
			best_actions.append(a)
	return [best_val,best_actions[randi()%best_actions.size()]]


## Explores the map by always exploring unknown tiles and otherwise following the best path
func move_forwards():
	var exploring = false
	var chosen_direction = -1
	old_state = current_state
	
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
			if point in terminal_states: continue
			for neighbor in explored_map[point]:
				if neighbor in terminal_states: continue
				if neighbor != null and neighbor != point and neighbor: 
					astar.connect_points(back[point],back[neighbor])
		var unexplored_pos = unexplored_states[randi() % unexplored_states.size()]
		var path = astar.get_point_path(back[current_state],back[unexplored_pos])
		path.remove(0)
		for point in path:
			var result = step(current_state,get_direction_to(current_state,point))
		
		#travel the unknown path, until we hit a known tile
		while has_unexplored_path(current_state):
			chosen_direction = get_unexplored_path(current_state)
			var result = step(current_state,chosen_direction)
			if goal_found: return
			backtrack()
	
	# if there is an unexplored path next to us, take it
	if has_unexplored_path(current_state):
		exploring = true
		chosen_direction = get_unexplored_path(current_state)
	# if there isn't, we choose the direction with the highest Q value
	elif current_state in qtable:
		exploration_round = false
		chosen_direction = get_direction_to(current_state,explored_map[current_state][get_best_move(current_state)[1]])
	else:
		backtrack()
	
	# Tell the environment where are and what we want to do
	# result = [new_state, reward, done, hit_wall]
	var result = step(current_state,chosen_direction)
	if goal_found: return
	
	if exploring: backtrack()


## Gets the direction needed to travel from pos to new_pos.
## Returns -1 if this is impossible.
func get_direction_to(pos,new_pos):
	for i in range(explored_map[pos].size()):
		if new_pos == explored_map[pos][i]:
			return i
	return -1


func print_results():
	map.wipe_values()
	for state in explored_map:
		map.print_value(state,qtable[state].max())


## Adds a label containing the Q value of each state to each known position
## These values should decrease from the terminal state
func draw_results():
	var min_value = INF
	var max_value = -INF
	for state in qtable:
		if state in terminal_states: continue
		var state_max_value = -INF
		for value in qtable[state]:
			state_max_value = max(value,state_max_value)
			max_value = max(state_max_value,max_value)
		min_value = min(state_max_value,min_value)
	
	var offset = 0
	if min_value < 1: 
		offset = 1 - min_value
		min_value += offset
		max_value += offset
	min_value = log(min_value)
	max_value = log(max_value)
	
	for state in qtable:
		if state in terminal_states: continue
		var state_average_value = 0
		for value in qtable[state]:
			state_average_value += value
		state_average_value /= qtable[state].size()
		
		state_average_value += offset
		state_average_value = log(state_average_value)
		
		var percent = (state_average_value - min_value) / (max_value - min_value)
		var c = Color(1-(percent*2-1),percent*2,0)
		map.paint_pos(state,c)


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
		if rewards[slot][direction] == null:
			unexplored.append(direction)
	
	if unexplored.size() > 0:
		return unexplored[randi() % unexplored.size()]
	else:
		return null


## Checks if a given position has unexplored directions
func has_unexplored_path(slot):
	var unexplored = []
	for direction in range(actions.size()):
		if rewards[slot][direction] == null:
			unexplored.append(direction)
	
	return unexplored.size() > 0


## checks, which neighboring states are walls
func check_neighbor(state):
	if not state in explored_map: return
	for i in range(explored_map[state].size()):
		if rewards[state][i] == null:
			var result = step(state,i,false,true)
			if result[3]:
				explored_map[state][i] = state
				rewards[state][i] = result[1]
			else:
				step(result[0],go_back(i),false,true)


func step(pos,dir,backtracking=false,checking=false):
	# tell the map where we want to go and from where
	# result = [new_state, reward, episode done, hit wall]
	var result = map.step(pos,dir,checking)
	if checking: return result
	
	old_state = current_state
	current_state = result[0]
	
	# initialize the state in the explored map
	if not current_state in explored_map:
		explored_map[current_state] = [null,null,null,null]
	explored_map[old_state][dir] = current_state
	if not result[3] and not backtracking:
		steps_taken.append(dir)
	
	# initialize rewards for the state if they dont exist yet
	if not current_state in rewards:
		rewards[current_state] = [null,null,null,null]
	rewards[old_state][dir] = result[1]
	
	# check for walls next to our state so that they aren't added to unexplored states
	if not result[2]:
		check_neighbor(current_state)
	else:
		goal_found = true
		if not current_state in terminal_states:
			terminal_states.append(current_state)
			rewards[current_state] = [0,0,0,0]
	
	# either add or remove the state from unexplored_states
	if has_unexplored_path(current_state):
		if not result[2]: 
			unexplored_states.append(current_state)
	for state in unexplored_states:
		if not has_unexplored_path(state):
			unexplored_states.erase(state)
	
	return result


func backtrack():
	# If we find a tile that doesn't have unexplored directions, we backtrack until we find one that does
	# To prevent the Solver from constantly backtracking after the first round of exploration, 
	# it will only do this if it doesn't have a "Q value path" to follow
	while not has_unexplored_path(current_state) and get_best_move(current_state)[0] == -INF:
		if not steps_taken.size(): return
		var result = step(current_state,go_back(steps_taken[steps_taken.size()-1]),true)
		steps_taken.remove(steps_taken.size()-1)
