# Floor scene includes things limited to this floor. Enemies are also appended to it. 
# Also includes item generation and things.


extends Node2D

@onready var layout_tiles = $LayoutTiles
@onready var floor_tiles = $FullFloorTiles

var random = RandomNumberGenerator.new()

@warning_ignore("unused_signal") signal next_floor # fire when stairway activated

var is_active := true
@export var square_room_size = 4
@export var floor_type = "uhhh idk replace later" # TODO do this later ig when implementing actual shit

# Main setup, handles others
# Room thing positions are handled by the LayoutTiles. Actual collision and details are handled by FullFloorTiles
func setup():
	# Generate map first
	layout_tiles.set_cell(Vector2i(0,0), 0, Vector2i(0,0))
	
	var player_start = to_global(layout_tiles.map_to_local(grow_map(3, 0.5)[-1]))
	
	$NextFloorStairway.position = to_global(layout_tiles.map_to_local(grow_map(1,0.3)[-1])) * Vector2(2,2)
	
	# make sure the next floor stairway isn't always THAT close
	while $NextFloorStairway.position.distance_to(player_start) <= 200:
		$NextFloorStairway.position = to_global(layout_tiles.map_to_local(grow_map(1,0.3)[-1]))
		
	# Recompile map into for proper collision
	convert_to_floor(square_room_size)
	
	var output = {
		"player_start_pos": player_start
	}
	
	# print(layout_tiles.get_used_cells()) debug
	
	return output

# Grows map by going through every tile and having a set chance to fill in all surrounding tiles
func grow_map(iterations, chance):
	var change_list = []
	
	for i in range(iterations):
		# Wish the Array.shuffle() method returned the result
		var cells = layout_tiles.get_used_cells()
		cells.shuffle()
		for tile in cells:
			for direction in [TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE,TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_TOP_SIDE]:
				if layout_tiles.get_cell_source_id(layout_tiles.get_neighbor_cell(tile, direction)) == -1:
					if random.randf() <= chance:
						layout_tiles.set_cell(layout_tiles.get_neighbor_cell(tile, direction), 0, Vector2i(0,0))
						change_list.append(layout_tiles.get_neighbor_cell(tile, direction))
	
	# if it's COMPLETELY EMPTY, reroll
	if len(change_list) == 0:
		return grow_map(iterations, chance)
	
	# return the list of added tiles for generation purposes
	return change_list
	
# Takes the created layout and uses terrains to generate collisions & walls
func convert_to_floor(room_size):
	for tile_coord in layout_tiles.get_used_cells(): # Vector2s for its position in the tile layer, from origin
		var origin_tile_coord = tile_coord * Vector2i(room_size,room_size) # Multiplied by room size to fill full room
		var x_increment = 0
		while x_increment < room_size:
			var y_increment = 0
			while y_increment < room_size:
				floor_tiles.set_cell(origin_tile_coord + Vector2i(x_increment, y_increment), 0, Vector2i(0,0))
				y_increment += 1
			x_increment += 1
	
	# set_cells_terrain_connect bugs out when surrounding tiles aren't also added to the set
	var used_cells := []
	
	for used_tile in floor_tiles.get_used_cells():
		used_cells.append(used_tile)
		for direction in [ # all 8 directions in vector2i 
			Vector2i.UP,
			Vector2i(1,1),
			Vector2i.RIGHT,
			Vector2i(1,-1),
			Vector2i.DOWN,
			Vector2i(-1,-1),
			Vector2i.LEFT,
			Vector2i(-1,1),
		]:
			if floor_tiles.get_cell_source_id(used_tile + direction) == -1: # doesn't count used tiles so no dupes, only the empty neighbors
				used_cells.append(used_tile + direction) 
	
	# Formats them according to terrain
	floor_tiles.set_cells_terrain_connect(used_cells, 0, 0)
