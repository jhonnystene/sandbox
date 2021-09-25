extends Node2D

var SandboxTexture
var SandboxImage

var ChangedPixels = {}
var SandboxWorld = []
var SandboxWorldWidth
var SandboxWorldHeight

const TYPE_AIR = {"behavior": 0, "color": Color(0, 0, 0), "density": 0}
const TYPE_SAND = {"behavior": 1, "color": Color(188, 217, 0), "density": 3, "physics_passes": 2, "physics_material": "powder"}
const TYPE_WATER = {"behavior": 2, "color": Color(0, 112, 217), "density": 1, "physics_passes": 4, "physics_material": "liquid", "viscosity": 70, "flow_direction": -1}

var Selected = TYPE_SAND

func PixelValid(x, y):
	return not (x < 0 or y < 0 or x > SandboxWorldWidth - 1 or y > SandboxWorldHeight - 1)

func SetPixel(x, y, value):
	if not PixelValid(x, y):
		return
	ChangedPixels[Vector2(x, y)] = true
	SandboxWorld[x][y] = value
			
func SwapPixels(x1, y1, x2, y2):
	if not (PixelValid(x1, y1) and PixelValid(x2, y2)):
		return
	ChangedPixels[Vector2(x1, y1)] = true
	ChangedPixels[Vector2(x2, y2)] = true
	var val1 = SandboxWorld[x1][y1]
	SandboxWorld[x1][y1] = SandboxWorld[x2][y2]
	SandboxWorld[x2][y2] = val1
			
func IsPixelEmpty(x, y):
	if not PixelValid(x, y):
		return
	return (SandboxWorld[x][y]["behavior"] == 0)

func IsType(pixel, type):
	return (pixel["behavior"] == type["behavior"] and pixel["density"] == type["density"])

func IsGroup(pixel, group):
	if(pixel["behavior"] == 0):
		return false
	return pixel["physics_material"] == group

func IsPixelSwappable(x1, y1, x2, y2):
	if(x1 < 0 or y1 < 0 or x1 > SandboxWorldWidth - 1 or y1 > SandboxWorldHeight - 1):
		return false
	if(x2 < 0 or y2 < 0 or x2 > SandboxWorldWidth - 1 or y2 > SandboxWorldHeight - 1):
		return false
	
	var me = SandboxWorld[x1][y1]
	var them = SandboxWorld[x2][y2]
	
	if(them["behavior"] == 0):
		return true
	elif(IsType(me, them)):
		return false
	elif(IsGroup(me, "liquid") == false and IsGroup(them, "liquid") == true):
		return not (rand_range(0, 100) < them["viscosity"])
	elif(me["density"] > them["density"]):
		return true
	return false
	
func generateSandboxImage():
	# Create new image
	SandboxImage = Image.new()
	SandboxImage.create(SandboxWorldWidth, SandboxWorldHeight, false, Image.FORMAT_RGB8)
	
	# Fill in image
	SandboxImage.lock()
	for x in range(0, SandboxWorldWidth):
		for y in range(0, SandboxWorldHeight):
			SandboxImage.set_pixel(x, y, SandboxWorld[x][y]["color"])
	SandboxImage.unlock()
	
	# Add to texture
	$Display.texture.create_from_image(SandboxImage)
	$Display.texture.set_flags(0)
	
func generateSandboxWorld():
	SandboxWorldWidth = get_viewport().size.x / $Display.scale.x
	SandboxWorldHeight = get_viewport().size.y / $Display.scale.y
	for x in range(0, SandboxWorldWidth):
		SandboxWorld.append([])
		SandboxWorld[x] = []
		for y in range(0, SandboxWorldHeight):
			SandboxWorld[x].append([])
			SandboxWorld[x][y] = TYPE_AIR

func processSandboxWorld():
	for x in range(0, SandboxWorldWidth):
		for y in range(SandboxWorldHeight - 1, 0, -1):
			var pixel = SandboxWorld[x][y]
			if(IsType(pixel, TYPE_AIR)): # Air
				continue
			elif(IsGroup(pixel, "powder")): # Powders
				var cx = x
				var cy = y
				for i in range(0, pixel["physics_passes"]):
					if(IsPixelSwappable(cx, cy, cx, cy + 1)):
						SwapPixels(cx, cy, cx, cy + 1)
						cy += 1
					elif(IsPixelSwappable(cx, cy, cx - 1, cy + 1)):
						SwapPixels(cx, cy, cx - 1, cy + 1)
						cx -= 1
						cy += 1
					elif(IsPixelSwappable(cx, cy, cx + 1, cy + 1)):
						SwapPixels(cx, cy, cx + 1, cy + 1)
						cx += 1
						cy += 1
					else:
						break
			elif(IsGroup(pixel, "liquid")): # Water
				var cx = x
				var cy = y
				var flow_direction = pixel["flow_direction"]
				for i in range(0, pixel["physics_passes"]):
					if(IsPixelSwappable(cx, cy, cx, cy + 1)):
						SwapPixels(cx, cy, cx, cy + 1)
						cy += 1
						
					elif(IsPixelSwappable(cx, cy, cx + flow_direction, cy + 1)):
						SwapPixels(cx, cy, cx + flow_direction, cy + 1)
						cx += flow_direction
						cy += 1
						
					elif(IsPixelSwappable(cx, cy, cx - flow_direction, cy + 1)):
						SwapPixels(cx, cy, cx - flow_direction, cy + 1)
						cx -= flow_direction
						cy += 1
						
					elif(IsPixelSwappable(cx, cy, cx + flow_direction, cy)):
						SwapPixels(cx, cy, cx + flow_direction, cy)
						cx += flow_direction
						
					elif(IsPixelSwappable(cx, cy, cx - flow_direction, cy)):
						SwapPixels(cx, cy, cx - flow_direction, cy)
						cx -= flow_direction
						SandboxWorld[cx][cy]["flow_direction"] = -flow_direction
						flow_direction = -flow_direction
						
					else:
						break
				
func updateSandboxImage():
	# Fill in image
	SandboxImage.lock()
	for pixel in ChangedPixels:
		SandboxImage.set_pixel(pixel.x, pixel.y, SandboxWorld[pixel.x][pixel.y]["color"])
	SandboxImage.unlock()
	
	ChangedPixels = {}
	
	# Add to texture
	$Display.texture.create_from_image(SandboxImage)
	$Display.texture.set_flags(0)
			
func _process(_delta):
	if(Input.is_mouse_button_pressed(BUTTON_LEFT)):
		var x = get_viewport().get_mouse_position().x / $Display.scale.x
		var y = get_viewport().get_mouse_position().y / $Display.scale.y
		var cursor_size = $UI/HSlider.value
		var cursor_offset = floor(cursor_size / 2)
		
		for sx in range(x - cursor_offset, x + cursor_offset):
			for sy in range(y - cursor_offset, y + cursor_offset):
				SetPixel(sx, sy, Selected)
				if(Selected == TYPE_WATER):
					var flow_direction = -1
					if(rand_range(0, 100) < 50):
						flow_direction = 1
					SandboxWorld[sx][sy]["flow_direction"] = flow_direction
		
	processSandboxWorld()
	updateSandboxImage()

func _ready():
	generateSandboxWorld()
	generateSandboxImage()

func _on_SandButton_pressed():
	Selected = TYPE_SAND

func _on_WaterButton_pressed():
	Selected = TYPE_WATER
