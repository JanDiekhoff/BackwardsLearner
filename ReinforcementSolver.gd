extends Node2D
class_name QSolver
signal done
# Adapted from https://github.com/simoninithomas/Deep_reinforcement_learning_Course/tree/master/Q%20learning/FrozenLake

####### VARIABLES ######
var max_episode_steps = INF
var current_episode_steps = 0
var width = 0
var height = 0
var qtable = {}
var rewards = []
var total_rewards = 0
var steps = []

var total_episodes = 250          # Total episodes
var current_episode = 0
var learning_rate = .1           # Learning rate
var discount_rate = 0.9           # Discounting rate
var current_state

# Exploration parameters
var epsilon = 1.0                 # Exploration rate
var max_epsilon = 1.0             # Exploration probability at start
var min_epsilon = 0.01            # Minimum exploration probability 
var decay_rate = -0.01            # Exponential decay rate for exploration prob

var actions = [0,1,2,3] # UP, RIGHT, DOWN, LEFT
var map

var file


## called by the Maze when it is done setting up
func ready(episodes,max_steps,f):
	max_episode_steps = max_steps
	total_episodes = episodes
	map = get_parent()
	width = map.width
	height = width
	
	file = f
	
	current_state = map.default_state
	for x in range(width):
		for y in range(height):
			qtable[Vector2(x,y)] = []
			for a in actions.size():
				qtable[Vector2(x,y)].insert(a,rand_range(-.1,.1))


## called once per frame
func _physics_process(delta):
	if current_episode < total_episodes:
		if current_episode_steps < max_episode_steps:
			var action
			if randf() > epsilon:
				action = get_best_action(qtable[current_state])
			else:
				action = actions[randi() % 4]
			
			var result = map.step(current_state,action)
			var new_state = result[0]
			var reward = result[1]
			
			qtable[current_state][action] += learning_rate * (reward + discount_rate * qtable[new_state].max() - qtable[current_state][action])
			total_rewards += reward
			
			current_state = new_state
			current_episode_steps += 1
			print_results(current_state)
			if result[2]: start_new_episode()
		else:
			start_new_episode()
	else:
		set_physics_process(false)
		emit_signal("done")


func start_new_episode():
	rewards.append(total_rewards)
	total_rewards = 0
	position = Vector2.ZERO
	current_state = map.default_state
	file.store_string("Episode: " + str(current_episode) + ", Steps taken: " + str(current_episode_steps) + "\n")
	current_episode += 1
	steps.append(current_episode_steps)
	current_episode_steps = 0
	epsilon = min_epsilon + (max_epsilon - min_epsilon) * exp(decay_rate*current_episode)


## Adds a label containing the Q value of each state to each known position
## These values should decrease from the terminal state
func print_results(state):
	return


func get_best_action(state):
	var best = state[0]
	var best_index = 0
	for i in range(state.size()):
		if state[i] > best: 
			best = state[i]
			best_index = i
	return best_index

