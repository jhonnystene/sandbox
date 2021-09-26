extends Node2D

var sandboxTexture
var sandboxImage

var changedPixels = {}
var world = []
var worldWidth
var worldHeight

# Special
const TYPE_AIR = {"color": Color(0, 0, 0), "density": 0, "flammable": false, "physics_material": "air", "simulation_material": "none"}

# Powder
const TYPE_SAND = {"color": Color(188, 217, 0), "density": 3, "flammable": false, "physics_passes": 2, "physics_material": "powder", "physics_chance": 75, "simulation_material": "none"}
const TYPE_SALT = {"color": Color("#FFFFFF"), "density": 3, "flammable": false, "physics_passes": 2, "physics_material": "powder", "physics_chance": 75, "simulation_material": "salt"}

# Liquid
const TYPE_WATER = {"color": Color(0, 112, 217), "density": 1, "flammable": false, "physics_passes": 3, "physics_material": "liquid", "physics_chance": 75, "simulation_material": "water", "viscosity": 70, "flow_direction": -1}
const TYPE_OIL = {"color": Color("#6e0b46"), "density": 2, "flammable": true, "burn_time": 0.3, "physics_passes": 2, "physics_material": "liquid", "physics_chance": 75, "simulation_material": "none", "viscosity": 95, "flow_direction": -1}
const TYPE_ACID = {"color": Color("#066b17"), "density": 1, "flammable": false, "physics_passes": 3, "physics_material": "liquid", "physics_chance": 75, "simulation_material": "acid", "viscosity": 70, "flow_direction": -1}
const TYPE_LAVA = {"color": Color("#e07800"), "density": 3, "flammable": false, "physics_passes": 2, "physics_material": "liquid", "physics_chance": 75, "simulation_material": "lava", "viscosity": 70, "flow_direction": -1}

# Gas
const TYPE_STEAM = {"color": Color("#9fd6fc"), "density": 0, "flammable": false, "physics_passes": 1, "physics_material": "rising", "physics_chance": 75, "flow_direction": -1, "simulation_material": "steam"}
const TYPE_METHANE = {"color": Color("#7a08a3"), "density": 0, "flammable": true, "burn_time": 0.2, "physics_passes": 1, "physics_material": "rising", "physics_chance": 75, "flow_direction": -1, "simulation_material": "none"}

# Solid
const TYPE_WOOD = {"color": Color("#634f1a"), "density": 5, "flammable": true, "burn_time": 3, "physics_material": "solid", "simulation_material": "none"}
const TYPE_STONE = {"color": Color("#8c8c8c"), "density": 5, "flammable": false, "burn_time": 3, "physics_material": "solid", "simulation_material": "none"}
const TYPE_FUSE = {"color": Color("#27a308"), "density": 5, "flammable": true, "burn_time": 0.3, "physics_material": "solid", "simulation_material": "none"}

# Burning
const TYPE_FIRE = {"color": Color("#edab26"), "density": 9, "flammable": false, "physics_material": "none", "simulation_material": "fire", "time_to_live": 0.1}
const TYPE_EMBER = {"color": Color("#d8eb10"), "density": 0, "flammable": false, "physics_passes": 1, "physics_material": "rising", "physics_chance": 75, "flow_direction": -1, "simulation_material": "fire", "time_to_live": 1}

const TYPE_TRANSLATION = {"Sand": TYPE_SAND, "Water": TYPE_WATER, "Oil": TYPE_OIL, "Fire": TYPE_FIRE, "Wood": TYPE_WOOD, "Fuse": TYPE_FUSE, "Methane": TYPE_METHANE, "Salt": TYPE_SALT, "Acid": TYPE_ACID, "Stone": TYPE_STONE, "Lava": TYPE_LAVA}

var selected = TYPE_SAND

func IsHyperspeed():
	return $UI/Hyperspeed.pressed

func IsPositionValid(x, y):
	return not (x < 0 or y < 0 or x > worldWidth - 1 or y > worldHeight - 1)

func SetPixel(x, y, value, override={}):
	if not IsPositionValid(x, y):
		return
	changedPixels[Vector2(x, y)] = true
	world[x][y] = value.duplicate(true)
	# Physics randomization
	if(IsGroup(value, "liquid") or IsGroup(value, "rising")):
		var flow_direction = -1
		if(rand_range(0, 100) < 50):
			flow_direction = 1
		world[x][y]["flow_direction"] = flow_direction
	
	# Material randomization
	if(IsMaterial(value, "fire")):
		world[x][y]["time_to_live"] = rand_range(0.1, 0.3) + int(selected["physics_material"] != "none")
	
	for property in override:
		world[x][y][property] = override[property]
			
func SwapPixels(x1, y1, x2, y2):
	if not (IsPositionValid(x1, y1) and IsPositionValid(x2, y2)):
		return
	changedPixels[Vector2(x1, y1)] = true
	changedPixels[Vector2(x2, y2)] = true
	var val1 = world[x1][y1]
	world[x1][y1] = world[x2][y2]
	world[x2][y2] = val1
			
func IsEmpty(x, y):
	if not IsPositionValid(x, y):
		return false
	return (IsGroup(world[x][y], "air"))

func IsNeighborsBurning(x, y):
	for sx in range(x - 1, x + 2):
		for sy in range(y - 1, y + 2):
			if not IsPositionValid(sx, sy):
				continue
			if(x == sx and y == sy):
				continue
			if(IsMaterial(world[sx][sy], "fire")):
				return true
	return false

func IsInWater(x, y):
	for sx in range(x - 1, x + 2):
		for sy in range(y - 1, y + 2):
			if not IsPositionValid(sx, sy):
				continue
			if(x == sx and y == sy):
				continue
			if(IsMaterial(world[sx][sy], "water")):
				return true
	return false

func IsType(pixel, type):
	# TODO: make this better
	return (pixel["physics_material"] == type["physics_material"] and pixel["density"] == type["density"])

func IsGroup(pixel, group):
	return pixel["physics_material"] == group
	
func IsMaterial(pixel, material):
	return pixel["simulation_material"] == material
	
func IsFlammable(x, y):
	if not IsPositionValid(x, y):
		return false
	return world[x][y]["flammable"]

func IsSwappable(x1, y1, x2, y2):
	if(x1 < 0 or y1 < 0 or x1 > worldWidth - 1 or y1 > worldHeight - 1):
		return false
	if(x2 < 0 or y2 < 0 or x2 > worldWidth - 1 or y2 > worldHeight - 1):
		return false
	
	var me = world[x1][y1]
	var them = world[x2][y2]
	
	if(IsGroup(them, "air")):
		return true
	elif(IsType(me, them)):
		return false
	elif(IsGroup(me, "liquid") == false and IsGroup(them, "liquid") == true):
		return not (rand_range(0, 100) < them["viscosity"])
	elif(me["density"] > them["density"]):
		return true
	return false
	
func IsLineFull(y):
	if(y > worldHeight - 1):
		return true
	# TODO: factor in density
	for x in range(0, worldWidth):
		if(IsType(world[x][y], TYPE_AIR)):
			return true
	return false
	
func GenerateSandboxImage():
	# Create new image
	sandboxImage = Image.new()
	sandboxImage.create(worldWidth, worldHeight, false, Image.FORMAT_RGB8)
	
	# Fill in image
	sandboxImage.lock()
	for x in range(0, worldWidth):
		for y in range(0, worldHeight):
			sandboxImage.set_pixel(x, y, world[x][y]["color"])
	sandboxImage.unlock()
	
	# Add to texture
	$Display.texture.create_from_image(sandboxImage)
	$Display.texture.set_flags(0)
	
func GenerateWorld():
	worldWidth = get_viewport().size.x / $Display.scale.x
	worldHeight = get_viewport().size.y / $Display.scale.y
	for x in range(0, worldWidth):
		world.append([])
		world[x] = []
		for y in range(0, worldHeight):
			world[x].append([])
			world[x][y] = TYPE_AIR

func ProcessWorld(delta):
	for x in range(0, worldWidth):
		for y in range(worldHeight - 1, -1, -1):
			var pixel = world[x][y]
			
			# MATERIAL SIMULATION
			if(IsMaterial(pixel, "fire")):
				var spread_rate = 15
				if(IsFlammable(x - 1, y - 1) and rand_range(0, 100) < spread_rate):
					SetPixel(x - 1, y - 1, TYPE_FIRE, {"time_to_live": world[x - 1][y - 1]["burn_time"]})
				if(IsFlammable(x, y - 1) and rand_range(0, 100) < spread_rate):
					SetPixel(x, y - 1, TYPE_FIRE, {"time_to_live": world[x][y - 1]["burn_time"]})
				if(IsFlammable(x + 1, y - 1) and rand_range(0, 100) < spread_rate):
					SetPixel(x + 1, y - 1, TYPE_FIRE, {"time_to_live": world[x + 1][y - 1]["burn_time"]})
				if(IsFlammable(x - 1, y) and rand_range(0, 100) < spread_rate):
					SetPixel(x - 1, y, TYPE_FIRE, {"time_to_live": world[x - 1][y]["burn_time"]})
				if(IsFlammable(x + 1, y) and rand_range(0, 100) < spread_rate):
					SetPixel(x + 1, y, TYPE_FIRE, {"time_to_live": world[x + 1][y]["burn_time"]})
				if(IsFlammable(x - 1, y + 1) and rand_range(0, 100) < spread_rate):
					SetPixel(x - 1, y + 1, TYPE_FIRE, {"time_to_live": world[x - 1][y + 1]["burn_time"]})
				if(IsFlammable(x, y + 1) and rand_range(0, 100) < spread_rate):
					SetPixel(x, y + 1, TYPE_FIRE, {"time_to_live": world[x][y + 1]["burn_time"]})
				if(IsFlammable(x + 1, y + 1) and rand_range(0, 100) < spread_rate):
					SetPixel(x + 1, y + 1, TYPE_FIRE, {"time_to_live": world[x + 1][y + 1]["burn_time"]})
					
				world[x][y]["time_to_live"] -= delta
				if(world[x][y]["time_to_live"] <= 0):
					SetPixel(x, y, TYPE_AIR)
				else:
					if(pixel["physics_material"] == "none"):
						# Create embers periodically
						if(IsEmpty(x, y - 1) and rand_range(0, 100) > 10):
							SetPixel(x, y - 1, TYPE_EMBER, {"time_to_live": rand_range(0.5, 1)})
					else:
						# We are an ember
						world[x][y]["color"] = Color(0.92, rand_range(0.42, 0.89), 0.06)
			elif(IsMaterial(pixel, "water")):
				if(IsNeighborsBurning(x, y)):
					SetPixel(x, y, TYPE_STEAM)
					continue # Skip physics
			elif(IsMaterial(pixel, "steam")):
				if not(IsMaterial(world[x][y - 1], "water") or IsMaterial(world[x][y - 1], "steam") or IsEmpty(x, y - 1)) or y == 0:
					SetPixel(x, y, TYPE_WATER)
					continue
			elif(IsMaterial(pixel, "salt")):
				if(IsInWater(x, y) and rand_range(0, 100) < 15):
					SetPixel(x, y, TYPE_WATER)
			elif(IsMaterial(pixel, "acid")):
				if not(IsSwappable(x, y, x, y + 1)):
					if(rand_range(0, 100) < 25):
						SetPixel(x, y + 1, TYPE_AIR)
			elif(IsMaterial(pixel, "lava")):
				if(y != worldHeight - 1):
					if not(IsSwappable(x, y, x, y + 1)):
						if(rand_range(0, 100) < 25 && (IsFlammable(x, y + 1) or IsMaterial(world[x][y + 1], "fire"))):
							SetPixel(x, y + 1, TYPE_AIR)
						
				if(x != 0 and IsFlammable(x - 1, y)):
					SetPixel(x - 1, y, TYPE_FIRE)
				
				if(x != worldWidth - 1 and IsFlammable(x + 1, y)):
					SetPixel(x + 1, y, TYPE_FIRE)
			
			# PHYSICS SIMULATION
			if(IsType(pixel, TYPE_AIR)): # Air
				continue
			elif(IsGroup(pixel, "powder")): # Powders
				var cx = x
				var cy = y
				for _i in range(0, pixel["physics_passes"]):
					if(rand_range(0, 100) < pixel["physics_chance"] and not IsHyperspeed()):
						continue
					if(IsSwappable(cx, cy, cx, cy + 1)):
						SwapPixels(cx, cy, cx, cy + 1)
						cy += 1
					elif(IsSwappable(cx, cy, cx - 1, cy + 1)):
						SwapPixels(cx, cy, cx - 1, cy + 1)
						cx -= 1
						cy += 1
					elif(IsSwappable(cx, cy, cx + 1, cy + 1)):
						SwapPixels(cx, cy, cx + 1, cy + 1)
						cx += 1
						cy += 1
					else:
						break
			elif(IsGroup(pixel, "liquid") or IsGroup(pixel, "rising")):
				var cx = x
				var cy = y
				var flow_direction = pixel["flow_direction"]
				var y_direction = 1
				if(IsGroup(pixel, "rising")):
					y_direction = -1
				for _i in range(0, pixel["physics_passes"]):
					if(rand_range(0, 100) < pixel["physics_chance"] and not IsHyperspeed()):
						continue
					var do_not_propagate_sideways = false
					
					if(IsSwappable(cx, cy, cx, cy + y_direction)):
						SwapPixels(cx, cy, cx, cy + y_direction)
						cy += 1
						
					elif(IsSwappable(cx, cy, cx + flow_direction, cy + y_direction)):
						SwapPixels(cx, cy, cx + flow_direction, cy + y_direction)
						cx += flow_direction
						cy += 1
						
					elif(IsSwappable(cx, cy, cx - flow_direction, cy + y_direction)):
						SwapPixels(cx, cy, cx - flow_direction, cy + y_direction)
						cx -= flow_direction
						cy += 1
						
					elif(IsSwappable(cx, cy, cx + flow_direction, cy) and !do_not_propagate_sideways):
						SwapPixels(cx, cy, cx + flow_direction, cy)
						cx += flow_direction
						
					elif(IsSwappable(cx, cy, cx - flow_direction, cy) and !do_not_propagate_sideways):
						SwapPixels(cx, cy, cx - flow_direction, cy)
						cx -= flow_direction
						world[cx][cy]["flow_direction"] = -flow_direction
						flow_direction = -flow_direction
						
					else:
						break
func UpdateSandboxImage():
	# Fill in image
	sandboxImage.lock()
	for pixel in changedPixels:
		sandboxImage.set_pixel(pixel.x, pixel.y, world[pixel.x][pixel.y]["color"])
	sandboxImage.unlock()
	
	changedPixels = {}
	
	# Add to texture
	$Display.texture.create_from_image(sandboxImage)
	$Display.texture.set_flags(0)
			
func _process(delta):
	if($UI/Paused.pressed):
		return
	selected = TYPE_TRANSLATION[$UI/OptionButton.text]
	
	if(Input.is_mouse_button_pressed(BUTTON_LEFT)):
		var x = get_viewport().get_mouse_position().x / $Display.scale.x
		var y = get_viewport().get_mouse_position().y / $Display.scale.y
		var cursor_size = $UI/HSlider.value
		var cursor_offset = floor(cursor_size / 2)
		
		for sx in range(x - cursor_offset, x + cursor_offset):
			for sy in range(y - cursor_offset, y + cursor_offset):
				if not(IsPositionValid(sx, sy)):
					continue
				SetPixel(sx, sy, selected)
				if(IsGroup(selected, "liquid")):
					var flow_direction = -1
					if(rand_range(0, 100) < 50):
						flow_direction = 1
					world[sx][sy]["flow_direction"] = flow_direction
	elif(Input.is_mouse_button_pressed(BUTTON_RIGHT)):
		var x = get_viewport().get_mouse_position().x / $Display.scale.x
		var y = get_viewport().get_mouse_position().y / $Display.scale.y
		var cursor_size = $UI/HSlider.value
		var cursor_offset = floor(cursor_size / 2)
		
		for sx in range(x - cursor_offset, x + cursor_offset):
			for sy in range(y - cursor_offset, y + cursor_offset):
				SetPixel(sx, sy, TYPE_AIR)
	ProcessWorld(delta)
	UpdateSandboxImage()

func _ready():
	for type in TYPE_TRANSLATION:
		$UI/OptionButton.add_item(type)
	
	GenerateWorld()
	GenerateSandboxImage()
