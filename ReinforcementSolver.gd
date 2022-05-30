extends Node2D

# Adapted from https://github.com/simoninithomas/Deep_reinforcement_learning_Course/tree/master/Q%20learning/FrozenLake

####### VARIABLES ######
var max_episode_steps = 1000
var current_episode_steps = 0
var width = 0
var height = 0
var qtable = {}
var rewards = []
var total_rewards = 0
var steps = []

var total_episodes = 250      # Total episodes
var current_episode = 0
var learning_rate = 0.8           # Learning rate
var max_steps = 99                # Max steps per episode
var discount_rate = 0.95          # Discounting rate
var state

# Exploration parameters
var epsilon = 1.0                 # Exploration rate
var max_epsilon = 1.0             # Exploration probability at start
var min_epsilon = 0.01            # Minimum exploration probability 
var decay_rate = 0.001            # Exponential decay rate for exploration prob

var actions = [0,1,2,3] # UP, RIGHT, DOWN, LEFT
var map


func _ready():
	set_physics_process(false)


## called by the Maze when it is done setting up
func ready():
	map = get_parent()
	width = map.width
	height = map.height
	state = map.default_state
	for x in range(width):
		for y in range(height):
			qtable[Vector2(x,y)] = [0,0,0,0]
	set_physics_process(true)


## called once per frame
func _physics_process(delta):
	if current_episode < total_episodes:
		if current_episode_steps < max_episode_steps:
			var action
			if randf() > epsilon:
				action = get_best_action(qtable[state])
			else:
				action = actions[randi() % 4]
			
			var result = map.step(state,action)
			var new_state = result[0]
			var reward = result[1]
			
			qtable[state][action] += learning_rate * (reward + discount_rate * qtable[new_state].max() - qtable[state][action])
			total_rewards += reward
			
			state = new_state
			current_episode_steps += 1
			if result[2]: start_new_episode()
		else:
			start_new_episode()
	else:
		set_physics_process(false)
		print_results()


func start_new_episode():
	rewards.append(total_rewards)
	total_rewards = 0
	position = Vector2.ZERO
	state = map.default_state
	print("\nEpisode: " + str(current_episode) + "\nSteps taken: " + str(current_episode_steps) + "\n")
	current_episode += 1
	steps.append(current_episode_steps)
	current_episode_steps = 0
	epsilon = min_epsilon + (max_epsilon - min_epsilon) * exp(-decay_rate*current_episode)


# TODO implement
func print_results():
	return


func get_best_action(state):
	var best = state[0]
	var best_index = 0
	for i in range(state.size()):
		if state[i] > best: 
			best = state[i]
			best_index = i
	return best_index

