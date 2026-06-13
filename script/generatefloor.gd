extends Node2D

@onready var floor_tilemap = $TileMapLayer

var random = RandomNumberGenerator.new()

signal next_floor # fire when stairway activated

var is_active = true

func setup():
	# generate map
	floor_tilemap.set_cell(Vector2i(0,0), 0, Vector2i(0,0))
	
	var player_start = to_global(floor_tilemap.map_to_local(grow_map(3, 0.5)[-1]))
	
	$NextFloorStairway.position = to_global(floor_tilemap.map_to_local(grow_map(1,0.3)[-1]))
	
	# make sure the next floor stairway isn't always THAT close
	while $NextFloorStairway.position.distance_to(player_start) <= 200:
		$NextFloorStairway.position = to_global(floor_tilemap.map_to_local(grow_map(1,0.3)[-1]))
	
	var output = {
		"player_start_pos": player_start
	}
	
	return output

func grow_map(iterations, chance):
	var change_list = []
	
	for i in range(iterations):
		# Wish the Array.shuffle() method returned the result
		var cells = floor_tilemap.get_used_cells()
		cells.shuffle()
		for tile in cells:
			for direction in [TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_TOP_SIDE]:
				if floor_tilemap.get_cell_source_id(floor_tilemap.get_neighbor_cell(tile, direction)) == -1:
					if random.randf() <= chance:
						floor_tilemap.set_cell(floor_tilemap.get_neighbor_cell(tile, direction), 0, Vector2i(0,0))
						change_list.append(floor_tilemap.get_neighbor_cell(tile, direction))
	
	# if it's COMPLETELY EMPTY, reroll
	if len(change_list) == 0:
		return grow_map(iterations, chance)
	
	# return the list of added tiles for generation purposes
	return change_list
