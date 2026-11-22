--[[
	R Client  |  Roblox Rivals  |  v1.0.0
	Mobile-first client for Delta. Dark violet panel, sticky head aim,
	ESP, silent aim, rage, trigger, 50+ modules and a client-side skin changer.

	Load:
		loadstring(game:HttpGet("https://raw.githubusercontent.com/njjjjjhij/r-client/main/RClient.lua"))()

	Tap the R badge in the corner to open or close the panel.
	Insert toggles the panel. Right Shift is panic.

	Everything here is client-side: it changes your camera, your own
	viewmodel and your own local GUI. It never writes to the server.
]]

local VERSION = "1.0.0"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
if not LP then
	return
end

-- Tear down a previous instance so re-running never stacks GUIs or loops.
if _G.RClient and type(_G.RClient) == "table" and _G.RClient.destroy then
	pcall(function()
		_G.RClient.destroy()
	end)
end

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local VIEWPORT = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local SCALE = math.clamp(VIEWPORT.X / 900, 0.72, 1.3)
if IS_MOBILE then
	SCALE = math.clamp(VIEWPORT.X / 760, 0.72, 1.15)
end

local function px(value)
	return math.floor(value * SCALE + 0.5)
end

local Theme = {
	panel = Color3.fromRGB(11, 10, 16),
	deep = Color3.fromRGB(8, 7, 12),
	card = Color3.fromRGB(18, 16, 25),
	row = Color3.fromRGB(22, 20, 31),
	rowHover = Color3.fromRGB(30, 27, 42),
	rowActive = Color3.fromRGB(38, 31, 56),
	stroke = Color3.fromRGB(41, 35, 56),
	accent = Color3.fromRGB(155, 92, 255),
	accentSoft = Color3.fromRGB(196, 156, 255),
	accentDeep = Color3.fromRGB(96, 48, 190),
	text = Color3.fromRGB(240, 238, 248),
	dim = Color3.fromRGB(148, 141, 166),
	muted = Color3.fromRGB(96, 90, 112),
	good = Color3.fromRGB(86, 226, 140),
	bad = Color3.fromRGB(240, 82, 96),
	warn = Color3.fromRGB(255, 190, 80),
	black = Color3.fromRGB(0, 0, 0),
}

local function create(class, props, parent)
	local object = Instance.new(class)
	if props then
		for key, value in pairs(props) do
			object[key] = value
		end
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function round(object, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = object
	return corner
end

local function edge(object, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.stroke
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = object
	return stroke
end

local function gradient(object, top, bottom, rotation)
	local item = Instance.new("UIGradient")
	item.Color = ColorSequence.new(top, bottom)
	item.Rotation = rotation or 90
	item.Parent = object
	return item
end

local function padding(object, all, horizontal, vertical)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, horizontal or all or 0)
	pad.PaddingRight = UDim.new(0, horizontal or all or 0)
	pad.PaddingTop = UDim.new(0, vertical or all or 0)
	pad.PaddingBottom = UDim.new(0, vertical or all or 0)
	pad.Parent = object
	return pad
end

local function tween(object, props, time, style)
	local info = TweenInfo.new(time or 0.14, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local item = TweenService:Create(object, info, props)
	item:Play()
	return item
end

local function label(parent, text, size, color, bold)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, size + 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		Text = text,
		TextColor3 = color or Theme.text,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local function clamp(value, low, high)
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function formatNumber(value)
	if value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end
	return tostring(value)
end

--------------------------------------------------------------------------
-- GUI shell
--------------------------------------------------------------------------

local function guiParent()
	-- PlayerGui is the reliable parent for input; hidden containers can eat taps.
	local playerGui = LP:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		return playerGui
	end
	local ok, hidden = pcall(function()
		return gethui()
	end)
	if ok and hidden then
		return hidden
	end
	return LP:WaitForChild("PlayerGui")
end

local GUI = create("ScreenGui", {
	Name = "RClientUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 9999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, guiParent())

local function protectGui()
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(GUI)
		end
		if protect_gui then
			protect_gui(GUI)
		end
	end)
end

protectGui()

--------------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------------

local toastHolder = create("Frame", {
	Name = "Toasts",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -px(14), 0, px(14)),
	Size = UDim2.fromOffset(px(238), px(300)),
}, GUI)

create("UIListLayout", {
	Padding = UDim.new(0, px(6)),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, toastHolder)

local function notify(message, color)
	local card = create("Frame", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.05,
		Size = UDim2.new(1, 0, 0, px(34)),
		LayoutOrder = -os.clock(),
		ClipsDescendants = true,
	}, toastHolder)
	round(card, px(7))
	edge(card, color or Theme.stroke, 1, 0.25)

	local bar = create("Frame", {
		BackgroundColor3 = color or Theme.accent,
		Size = UDim2.new(0, px(3), 1, 0),
	}, card)
	round(bar, px(2))

	local text = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(11), 0),
		Size = UDim2.new(1, -px(18), 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = message,
		TextColor3 = Theme.text,
		TextSize = px(12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)

	card.BackgroundTransparency = 1
	bar.BackgroundTransparency = 1
	text.TextTransparency = 1
	tween(card, { BackgroundTransparency = 0.05 }, 0.16)
	tween(bar, { BackgroundTransparency = 0 }, 0.16)
	tween(text, { TextTransparency = 0 }, 0.16)

	task.delay(3.2, function()
		if not card.Parent then
			return
		end
		tween(card, { BackgroundTransparency = 1 }, 0.2)
		tween(bar, { BackgroundTransparency = 1 }, 0.2)
		tween(text, { TextTransparency = 1 }, 0.2)
		task.wait(0.22)
		card:Destroy()
	end)
end

--------------------------------------------------------------------------
-- Value helpers shared by every feature
--------------------------------------------------------------------------

local Config = {}
local listeners = {}
local UI, CAPTURE = nil, false

local function get(id, key)
	local entry = Config[id]
	if not entry then
		return nil
	end
	return entry[key]
end

local function on(id)
	local entry = Config[id]
	return entry and entry.enabled == true
end

local function set(id, key, value)
	local entry = Config[id]
	if not entry then
		return
	end
	entry[key] = value
	for index = 1, #listeners do
		local fn = listeners[index]
		local ok, err = pcall(fn, id, key, value)
		if not ok then
			warn("[R Client] listener error: " .. tostring(err))
		end
	end
end

local function toggle(id)
	set(id, "enabled", not on(id))
end

local function onChange(fn)
	listeners[#listeners + 1] = fn
	return fn
end

--------------------------------------------------------------------------
-- Drawing probe (ESP / HUD surface)
--------------------------------------------------------------------------

local DRAW_OK = false
do
	local ok = pcall(function()
		local probe = Drawing.new("Square")
		probe:Remove()
	end)
	DRAW_OK = ok
end

local function drawing(class)
	if not DRAW_OK then
		return nil
	end
	local ok, object = pcall(function()
		return Drawing.new(class)
	end)
	if ok then
		return object
	end
	return nil
end

local function drop(object)
	if object and object.Remove then
		pcall(function()
			object:Remove()
		end)
	end
end

local function hide(object)
	if object then
		object.Visible = false
	end
end

local function square(object, position, size, color, thickness, transparency, filled)
	if not object then
		return
	end
	object.Position = position
	object.Size = size
	object.Color = color
	object.Thickness = thickness or 1
	object.Transparency = transparency or 0
	object.Filled = filled == true
	object.Visible = true
end

local function text(object, value, position, color, size)
	if not object then
		return
	end
	object.Text = value
	object.Position = position
	object.Color = color
	object.Size = size
	object.Center = true
	object.Outline = true
	object.OutlineColor = Theme.black
	object.OutlineTransparency = 0.35
	object.Visible = true
end

local function line(object, from, to, color, thickness, transparency)
	if not object then
		return
	end
	object.From = from
	object.To = to
	object.Color = color
	object.Thickness = thickness or 1
	object.Transparency = transparency or 0
	object.Visible = true
end

local function onScreen(camera, point)
	local screen, visible = camera:WorldToViewportPoint(point)
	if not visible or screen.Z <= 0 then
		return nil
	end
	return Vector2.new(screen.X, screen.Y)
end

local function cameraOrigin()
	local camera = workspace.CurrentCamera
	if not camera then
		return Vector3.new(0, 0, 0)
	end
	return camera.CFrame.Position
end

local function getCharacter(player)
	local character = player.Character
	if not character then
		local found = workspace:FindFirstChild(player.Name)
		if found and found:FindFirstChildOfClass("Humanoid") then
			character = found
		end
	end
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart", true)
	local head = character:FindFirstChild("Head", true)
	if not root or not head then
		return nil
	end
	return character, humanoid, root, head
end

local function sameTeam(player)
	if not player.Team or not LP.Team then
		return false
	end
	return player.Team == LP.Team
end

local KNOCKED = { "Knocked", "knocked", "Downed", "downed", "IsKnocked", "IsDowned" }

local function isKnocked(player, character, humanoid)
	if humanoid and humanoid.Health <= 0 then
		return true
	end
	if character then
		for _, name in ipairs(KNOCKED) do
			if character:GetAttribute(name) == true then
				return true
			end
		end
	end
	for _, name in ipairs(KNOCKED) do
		if player:GetAttribute(name) == true then
			return true
		end
	end
	return false
end

local rayParams = RaycastParams.new()
local modernRay = pcall(function()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
end)
if not modernRay then
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
end
rayParams.IgnoreWater = true
pcall(function()
	rayParams.RespectCanCollide = true
end)

local function rayBlocked(character, part)
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local filter = { camera }
	if LP.Character then
		filter[#filter + 1] = LP.Character
	end
	if character then
		filter[#filter + 1] = character
	end
	rayParams.FilterDescendantsInstances = filter
	local origin = camera.CFrame.Position
	local hit = workspace:Raycast(origin, part.Position - origin, rayParams)
	if hit and hit.Instance and not hit.Instance:IsDescendantOf(character) then
		return (hit.Position - origin).Magnitude > 2.5
	end
	return false
end

local function fireWeapon()
	if type(mouse1click) == "function" then
		if pcall(mouse1click) then
			return true
		end
	end
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local ok = pcall(function()
		game:GetService("VirtualUser"):ClickButton1(Vector2.new(size.X * 0.5, size.Y * 0.5))
	end)
	return ok
end

--------------------------------------------------------------------------
-- Module registry
--
-- One schema drives the panel, the defaults and the profile serializer.
-- type: "toggle" | "slider" | "cycle" | "key"
--------------------------------------------------------------------------

local Registry = {}
local Order = {}

local function T(key, name, def)
	return { key = key, name = name, type = "toggle", def = def ~= false }
end

local function S(key, name, min, max, def, step)
	return { key = key, name = name, type = "slider", min = min, max = max, def = def, step = step or 1 }
end

local function C(key, name, values, def)
	return { key = key, name = name, type = "cycle", values = values, def = def or values[1] }
end

local function B(key, name, def)
	return { key = key, name = name, type = "key", def = def or "None" }
end

local function M(id, name, cat, desc, settings)
	local item = { id = id, name = name, cat = cat, desc = desc, settings = settings or {} }
	Registry[id] = item
	Order[#Order + 1] = item
	return item
end

local Categories = { "Aim", "Combat", "ESP", "Visuals", "Movement", "World", "Skins", "Utility" }

--------------------------------------------------------------------------
-- Aim
--------------------------------------------------------------------------

M("aimbot", "Aimbot", "Aim", "Sticky head lock with exponential smoothing, no jitter.", {
	C("mode", "Activation", { "Always", "Hold", "On Fire" }, "Always"),
	S("fov", "FOV", 20, 360, 150, 5),
	S("smooth", "Smoothness", 10, 400, 110, 5),
	S("turn", "Max Turn", 60, 1440, 720, 20),
	S("deadzone", "Deadzone", 0, 3, 0.35, 0.05),
	S("prediction", "Prediction", 0, 30, 8, 1),
	C("part", "Target Bone", { "Head", "Body", "Nearest" }, "Head"),
	T("wall", "Wall Check", true),
	T("team", "Team Check", true),
	T("sticky", "Sticky Lock", true),
	S("stickyTime", "Lock Persistence", 0, 1.5, 0.4, 0.05),
	T("firstPerson", "First Person", true),
	S("maxDist", "Max Distance", 50, 2000, 900, 25),
	T("autoFire", "Auto Fire", false),
	S("fireDelay", "Fire Delay", 10, 300, 60, 5),
	T("hitMarker", "Hit Marker", true),
	T("targetHud", "Target Info", true),
	T("fovCircle", "FOV Circle", true),
	B("key", "Hold Key", "Q"),
})

M("aimassist", "Aim Assist", "Aim", "Gentle pull toward the nearest body, keeps your own input.", {
	S("strength", "Strength", 1, 40, 12, 1),
	S("radius", "Radius", 10, 320, 90, 5),
	T("team", "Team Check", true),
	T("wall", "Wall Check", false),
	B("key", "Hold Key", "F"),
})

M("silentaim", "Silent Aim", "Aim", "Redirects the attack frame so shots land without moving your view.", {
	S("chance", "Hit Chance", 1, 100, 100, 1),
	S("fov", "FOV", 20, 360, 140, 5),
	C("mode", "Resolve Mode", { "Camera", "Character", "Both" }, "Camera"),
	C("part", "Target Bone", { "Head", "Body", "Nearest" }, "Head"),
	T("wall", "Wall Check", true),
	T("team", "Team Check", true),
	S("maxDist", "Max Distance", 50, 2000, 900, 25),
	S("prediction", "Prediction", 0, 30, 6, 1),
	B("key", "Hold Key", "E"),
})

M("ragebot", "Ragebot", "Aim", "Instant snap, resolver and auto fire for close fights.", {
	T("autoFire", "Auto Fire", true),
	S("chance", "Hit Chance", 1, 100, 100, 1),
	S("fov", "FOV", 20, 360, 360, 5),
	T("ignoreFov", "Ignore FOV", false),
	C("priority", "Priority", { "Crosshair", "Distance", "Health" }, "Crosshair"),
	C("part", "Target Bone", { "Head", "Body" }, "Head"),
	C("snap", "Snap", { "Instant", "Smooth" }, "Instant"),
	T("resolver", "Resolver", true),
	T("wall", "Wall Check", true),
	T("team", "Team Check", true),
	S("fireDelay", "Fire Delay", 10, 400, 40, 5),
	S("maxDist", "Max Distance", 50, 2000, 1200, 25),
	B("key", "Hold Key", "R"),
})

M("triggerbot", "Triggerbot", "Aim", "Fires the moment your crosshair crosses a hitbox.", {
	S("delay", "Base Delay", 0, 400, 60, 5),
	S("jitter", "Delay Jitter", 0, 200, 25, 5),
	S("fov", "FOV", 0, 40, 5, 1),
	C("hitbox", "Hitbox", { "Any", "Head", "Body" }, "Any"),
	T("wall", "Wall Check", true),
	T("team", "Team Check", true),
	S("maxDist", "Max Distance", 20, 800, 400, 10),
	S("chance", "Hit Chance", 1, 100, 100, 1),
	B("key", "Hold Key", "C"),
})

M("killaura", "Kill Aura", "Aim", "Swings at anything nearby, optional multi target.", {
	S("range", "Range", 4, 40, 18, 1),
	S("rate", "Swing Rate", 1, 20, 6, 1),
	T("multi", "Multi Target", false),
	S("targets", "Max Targets", 1, 5, 2, 1),
	T("wall", "Wall Check", true),
	T("team", "Team Check", true),
	T("rotate", "Rotate Camera", true),
})

M("autoshoot", "Auto Shoot", "Aim", "Fires whenever a target sits inside the cone.", {
	S("range", "Range", 20, 600, 220, 10),
	S("delay", "Fire Delay", 20, 400, 80, 10),
	S("chance", "Hit Chance", 1, 100, 100, 1),
	T("wall", "Wall Check", true),
	T("team", "Team Check", true),
})

M("resolver", "Resolver", "Aim", "Corrects replicated velocity against ping so leads stay on target.", {
	C("mode", "Mode", { "Velocity", "Ping", "Hybrid" }, "Hybrid"),
	S("correction", "Correction", 0, 100, 60, 5),
	S("smooth", "Smoothing", 0, 100, 20, 5),
	T("debug", "Debug Markers", false),
})

--------------------------------------------------------------------------
-- Combat
--------------------------------------------------------------------------

M("hitbox", "Hitbox Expander", "Combat", "Grows enemy hitboxes and shows the expanded volume.", {
	S("size", "Size", 1, 8, 2.2, 0.1),
	C("part", "Part", { "Head", "Torso", "All" }, "Head"),
	T("visualize", "Visualize", true),
	S("distance", "Max Distance", 30, 800, 400, 10),
	T("team", "Team Check", true),
	S("transparency", "Fill Alpha", 0.1, 1, 0.6, 0.05),
})

M("reach", "Reach", "Combat", "Extends your melee reach client-side.", {
	S("distance", "Reach", 5, 40, 12, 1),
	T("visualizer", "Range Visualizer", false),
})

M("antiaim", "Anti-Aim", "Combat", "Moves your replicated yaw away from your real aim.", {
	C("mode", "Mode", { "Jitter", "Spin", "Ghost", "Static" }, "Jitter"),
	S("yaw", "Yaw Range", 0, 180, 25, 1),
	S("pitch", "Pitch", -89, 89, 6, 1),
	S("speed", "Speed", 1, 60, 12, 1),
	T("lowerBody", "Lower Body", true),
	T("visual", "Visual Indicator", false),
})

M("autoparry", "Auto Parry", "Combat", "Blocks on reaction when a swing comes in.", {
	S("range", "Range", 4, 40, 14, 1),
	S("window", "Parry Window", 40, 500, 180, 10),
	S("reaction", "Reaction", 0, 250, 60, 5),
	S("jitter", "Jitter", 0, 150, 30, 5),
	B("key", "Block Key", "F"),
})

M("autoblock", "Auto Block", "Combat", "Holds block while an enemy is close.", {
	S("range", "Range", 4, 40, 12, 1),
	S("hold", "Hold Time", 40, 800, 220, 10),
	S("delay", "Delay", 0, 300, 40, 5),
	T("team", "Team Check", true),
})

M("autododge", "Auto Dodge", "Combat", "Side dashes out of incoming fire.", {
	S("range", "Range", 5, 60, 20, 1),
	S("cooldown", "Cooldown", 0.2, 5, 1.2, 0.1),
	S("power", "Power", 10, 200, 60, 5),
	C("direction", "Direction", { "Left", "Right", "Back" }, "Left"),
})

M("autoability", "Auto Ability", "Combat", "Uses your ability slot when a target is in range.", {
	B("key", "Ability Key", "X"),
	S("range", "Range", 5, 120, 30, 1),
	S("buffer", "Cooldown Buffer", 0, 3, 0.5, 0.1),
	T("onlyWithTarget", "Only With Target", true),
})

M("autoequip", "Auto Equip", "Combat", "Swaps to the best tool for the distance.", {
	C("priority", "Priority", { "Melee", "Ranged", "Ability" }, "Melee"),
	S("delay", "Delay", 0, 500, 120, 10),
	T("combatOnly", "Only In Combat", true),
})

--------------------------------------------------------------------------
-- ESP
--------------------------------------------------------------------------

M("esp", "Player ESP", "ESP", "Boxes, names, health, distance and team colours.", {
	C("style", "Box Style", { "Box", "Corners", "Thin" }, "Box"),
	T("fill", "Fill", false),
	T("health", "Health Bar", true),
	T("healthText", "Health Text", false),
	T("name", "Names", true),
	C("nameMode", "Name Mode", { "Display", "Username", "Both" }, "Display"),
	T("distance", "Distance", true),
	T("teamColor", "Team Colours", false),
	T("team", "Team Check", false),
	S("maxDist", "Max Distance", 50, 1500, 500, 25),
	S("textSize", "Text Size", 8, 22, 13, 1),
	S("opacity", "Opacity", 0.2, 1, 1, 0.05),
})

M("skeleton", "Skeleton", "ESP", "Bone lines for R6 and R15 rigs.", {
	S("thickness", "Thickness", 1, 4, 1, 0.5),
	S("transparency", "Transparency", 0, 0.9, 0.15, 0.05),
	S("maxDist", "Max Distance", 50, 1000, 400, 25),
	T("team", "Team Check", false),
})

M("chams", "Chams", "ESP", "Highlight fill and outline through walls.", {
	T("throughWalls", "Through Walls", true),
	S("fill", "Fill Alpha", 0, 1, 0.55, 0.05),
	S("outline", "Outline Alpha", 0, 1, 0.9, 0.05),
	T("team", "Team Check", false),
})

M("tracers", "Tracers", "ESP", "Lines from a screen origin to every enemy.", {
	C("origin", "Origin", { "Bottom", "Center", "Top" }, "Bottom"),
	S("thickness", "Thickness", 1, 4, 1, 0.5),
	S("alpha", "Alpha", 0.2, 1, 0.65, 0.05),
	S("maxDist", "Max Distance", 50, 1000, 450, 25),
	T("team", "Team Check", false),
})

M("itemesp", "Item ESP", "ESP", "Names and distance for loose tools and drops.", {
	T("names", "Names", true),
	T("distance", "Distance", true),
	S("maxDist", "Max Distance", 20, 600, 200, 10),
})

M("arrows", "Off-screen Arrows", "ESP", "Edge arrows pointing at enemies behind you.", {
	S("size", "Arrow Size", 6, 24, 12, 1),
	S("maxDist", "Max Distance", 50, 1000, 500, 25),
	T("team", "Team Check", false),
})

M("fovcircle", "FOV Circle", "ESP", "Draws the aim FOV ring at the crosshair.", {
	S("thickness", "Thickness", 1, 4, 1, 0.5),
	S("alpha", "Alpha", 0.1, 1, 0.55, 0.05),
	T("fill", "Fill", false),
	T("pulse", "Pulse", true),
})

M("crosshair", "Crosshair", "ESP", "Custom crosshair that replaces the default one.", {
	C("style", "Style", { "Cross", "Dot", "T" }, "Cross"),
	S("size", "Size", 2, 40, 9, 1),
	S("gap", "Gap", 0, 20, 3, 1),
	S("thickness", "Thickness", 1, 4, 1, 0.5),
	T("dynamic", "Dynamic", false),
})

M("radar", "Radar", "ESP", "Minimap with rotation, view cone and names.", {
	S("size", "Size", 70, 220, 110, 5),
	S("range", "Range", 50, 800, 300, 10),
	C("corner", "Corner", { "Top Left", "Top Right", "Bottom Left", "Bottom Right" }, "Bottom Right"),
	T("rotation", "Rotate With Camera", true),
	T("names", "Names", false),
	S("dotSize", "Dot Size", 2, 10, 4, 1),
})

--------------------------------------------------------------------------
-- Visuals
--------------------------------------------------------------------------

M("fullbright", "Fullbright", "Visuals", "Bright lighting everywhere, restores on disable.", {
	S("brightness", "Brightness", 1, 5, 3, 0.1),
	S("ambient", "Ambient", 1, 255, 180, 5),
	T("clock", "Lock Clock", true),
})

M("nofog", "No Fog", "Visuals", "Pushes fog and atmosphere out of view.", {
	T("atmosphere", "Flatten Atmosphere", true),
})

M("noeffects", "No Effects", "Visuals", "Disables blur, rays and colour correction.", {
	T("blur", "Blur", true),
	T("rays", "Sun Rays", true),
	T("grade", "Colour Correction", true),
})

M("customtime", "Custom Time", "Visuals", "Sets the in-game clock.", {
	S("time", "Clock Time", 0, 24, 14, 0.5),
	T("freeze", "Freeze", true),
})

M("colorgrade", "Colour Grade", "Visuals", "Adds your own colour correction pass.", {
	S("saturation", "Saturation", -1, 1, 0.15, 0.05),
	S("contrast", "Contrast", -1, 1, 0.1, 0.05),
	S("brightness", "Brightness", -1, 1, 0, 0.05),
	S("bloom", "Bloom", 0, 2, 0.2, 0.05),
})

M("watermark", "Watermark", "Visuals", "R Client badge with FPS, ping and players.", {
	T("fps", "FPS", true),
	T("ping", "Ping", true),
	T("clock", "Clock", true),
	T("players", "Players", true),
	S("scale", "Scale", 0.6, 1.6, 1, 0.05),
})

M("keybindlist", "Keybind List", "Visuals", "Shows your binds in the corner.", {
	T("onlyEnabled", "Only Enabled", true),
	S("scale", "Scale", 0.6, 1.6, 1, 0.05),
})

--------------------------------------------------------------------------
-- Movement
--------------------------------------------------------------------------

M("walkspeed", "WalkSpeed", "Movement", "Sets your walkspeed, smooth ramp optional.", {
	S("value", "Speed", 8, 300, 26, 1),
	T("ramp", "Smooth Ramp", true),
	T("restore", "Restore On Disable", true),
	B("key", "Hold Key", "LeftShift"),
})

M("jumppower", "Jump Power", "Movement", "Sets jump power and enables jump power mode.", {
	S("value", "Jump Power", 20, 300, 60, 1),
	B("key", "Hold Key", "None"),
})

M("infinitejump", "Infinite Jump", "Movement", "Lets you jump again in mid air.", {
	T("whileJumping", "Only While Jumping", false),
})

M("autojump", "Auto Jump", "Movement", "Jumps automatically on landing.", {
	S("delay", "Delay", 0, 0.5, 0.05, 0.01),
})

M("fly", "Fly", "Movement", "Free flight with camera or horizontal mode.", {
	S("speed", "Speed", 10, 400, 60, 5),
	C("mode", "Mode", { "Camera", "Horizontal" }, "Camera"),
	T("vertical", "Space / Ctrl Vertical", true),
	B("key", "Toggle Key", "G"),
})

M("noclip", "Noclip", "Movement", "Walk through walls client-side.", {
	C("mode", "Mode", { "Loop", "Stealth" }, "Loop"),
	T("disableOnSpawn", "Disable On Respawn", true),
	B("key", "Toggle Key", "N"),
})

M("sprint", "Sprint", "Movement", "Multiplies your sprint speed with optional FOV punch.", {
	S("multiplier", "Multiplier", 1, 3, 1.35, 0.05),
	T("punch", "FOV Punch", true),
	S("amount", "Punch Amount", 0, 30, 6, 1),
})

M("longjump", "Long Jump", "Movement", "Launches you forward on key press.", {
	S("power", "Power", 20, 300, 90, 5),
	S("cooldown", "Cooldown", 0.2, 5, 1, 0.1),
	T("cameraDir", "Camera Direction", true),
	B("key", "Key", "V"),
})

M("teleport", "Teleport", "Movement", "Teleport to mouse, player or spawn.", {
	C("mode", "Mode", { "Mouse", "Player", "Spawn" }, "Mouse"),
	S("distance", "Mouse Distance", 2, 300, 40, 2),
	B("key", "Key", "T"),
})

M("antvoid", "Anti Void", "Movement", "Catches you before you fall out of the map.", {
	S("floor", "Floor Y", -500, 100, -40, 5),
	S("offset", "Respawn Offset", 0, 40, 12, 1),
	T("notify", "Notify", true),
})

--------------------------------------------------------------------------
-- World
--------------------------------------------------------------------------

M("scale", "Character Scale", "World", "Resizes your character, restores on disable.", {
	S("width", "Width", 0.2, 3, 1, 0.05),
	S("height", "Height", 0.2, 3, 1, 0.05),
	S("depth", "Depth", 0.2, 3, 1, 0.05),
})

M("antifling", "Anti Fling", "World", "Clamps absurd velocity from fling exploits.", {
	S("trigger", "Trigger Speed", 50, 1000, 200, 25),
	T("angular", "Zero Angular", true),
})

M("antistun", "Anti Stun", "World", "Clears stun states on an interval.", {
	C("mode", "Mode", { "State", "Position", "Both" }, "Both"),
	S("interval", "Interval", 0.05, 1, 0.2, 0.05),
})

M("antiragdoll", "Anti Ragdoll", "World", "Forces you back up and restores control.", {
	S("interval", "Interval", 0.05, 1, 0.2, 0.05),
	T("restoreSpeed", "Restore WalkSpeed", true),
})

--------------------------------------------------------------------------
-- Skins
--------------------------------------------------------------------------

M("skinchanger", "Skin Changer", "Skins", "Client-side repaint of your weapon, arms and character.", {
	C("skin", "Skin", {
		"Frostbite", "Nebula", "Ember", "Toxic", "Voidheart", "Chrome",
		"Sakura", "Bloodmoon", "Cyber", "Gold Rush", "Glacier", "Purple Haze",
		"Molten", "Phantom", "Candy", "Matrix", "Inferno", "Arctic",
	}, "Frostbite"),
	C("material", "Material", { "Neon", "ForceField", "Glass", "Metal", "SmoothPlastic", "Marble" }, "Neon"),
	T("rainbow", "Rainbow", false),
	S("rainbowSpeed", "Rainbow Speed", 0.05, 1, 0.25, 0.05),
	T("tools", "Include Tools", true),
	T("viewmodel", "Include Viewmodel", true),
	T("character", "Include Character", false),
})

M("skinpreview", "Unlock All Skins", "Skins", "Cycles the full skin catalogue on your viewmodel, client-side only.", {
	T("autoCycle", "Auto Cycle", false),
	S("speed", "Cycle Speed", 0.2, 5, 1.2, 0.1),
	T("applyViewmodel", "Apply To Viewmodel", true),
	T("showName", "Show Skin Name", true),
})

--------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------

M("antiafk", "Anti AFK", "Utility", "Nudges the client so the idle kick never fires.", {
	S("interval", "Interval", 30, 600, 120, 10),
	T("caption", "Caption Click", true),
})

M("fpsunlock", "FPS Unlock", "Utility", "Raises the frame cap, restores on disable.", {
	S("cap", "Cap", 60, 360, 240, 10),
	T("restore", "Restore Cap", true),
})

M("serverhop", "Server Hop", "Utility", "Hops to a lower ping server when you die.", {
	T("onDeath", "On Death", false),
	S("delay", "Delay", 1, 20, 4, 1),
	S("maxPlayers", "Max Players", 1, 50, 12, 1),
	B("key", "Key", "H"),
})

M("panic", "Panic", "Utility", "Drops every feature and hides the panel.", {
	T("hideUi", "Hide UI", true),
	T("disableAll", "Disable All", true),
	T("notify", "Notify", true),
	B("key", "Key", "RightShift"),
})

M("stats", "Server Stats", "Utility", "FPS, ping, players and coordinates.", {
	T("fps", "FPS", true),
	T("ping", "Ping", true),
	T("players", "Players", true),
	T("coords", "Coordinates", true),
})

M("config", "Config", "Utility", "Save and load your settings.", {
	T("autoload", "Autoload Profile", true),
	T("autosave", "Autosave", true),
	B("key", "Open Panel", "Insert"),
})

--------------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------------

for _, item in ipairs(Order) do
	local entry = { enabled = false }
	for _, setting in ipairs(item.settings) do
		entry[setting.key] = setting.def
	end
	Config[item.id] = entry
end

-- Sensible out-of-the-box state: ESP on, aim ready, UI closed.
Config.esp.enabled = true
Config.aimbot.enabled = true
Config.fovcircle.enabled = true
Config.watermark.enabled = true
--------------------------------------------------------------------------
-- Targeting
--------------------------------------------------------------------------

local Stats = game:GetService("Stats")
local unpackFn = table.unpack or unpack
local clock = os.clock

local function pingSeconds()
	local ok, value = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
	end)
	if ok and type(value) == "number" then
		return math.clamp(value, 0.01, 0.35)
	end
	return 0.06
end

local function screenRadius(camera, fov)
	local size = camera.ViewportSize
	local halfFov = math.rad(clamp(fov or 90, 1, 179.5)) * 0.5
	local halfCam = math.rad(clamp(camera.FieldOfView, 1, 179)) * 0.5
	local radius = math.tan(halfFov) / math.max(math.tan(halfCam), 0.001) * (size.Y * 0.5)
	return clamp(radius, 8, math.max(size.X, size.Y))
end

local function partFor(character, head, root, mode)
	if mode == "Body" then
		return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root
	end
	if mode == "Nearest" then
		local origin = cameraOrigin()
		local best = head
		local bestDistance = (head.Position - origin).Magnitude
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if torso then
			local distance = (torso.Position - origin).Magnitude
			if distance < bestDistance then
				best = torso
			end
		end
		return best
	end
	return head
end

local visibility = {}

local function visible(player, character, part)
	local now = clock()
	local cached = visibility[player]
	if cached and now - cached.at < 0.1 then
		return cached.ok
	end
	local ok = not rayBlocked(character, part)
	visibility[player] = { at = now, ok = ok }
	return ok
end

-- Picks the best candidate. `current` gets a large bonus while sticky is on,
-- which is what keeps the lock glued to the same head instead of hopping.
local function pickTarget(settings, current)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil, nil, nil
	end
	local size = camera.ViewportSize
	local center = Vector2.new(size.X * 0.5, size.Y * 0.5)
	local radius = settings.ignoreFov and math.max(size.X, size.Y) or screenRadius(camera, settings.fov)
	local origin = camera.CFrame.Position
	local maxDistance = settings.maxDist or 900
	local best, bestPart, bestHumanoid, bestCharacter, bestScore = nil, nil, nil, nil, math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LP and not (settings.team and sameTeam(player)) then
			local character, humanoid, root, head = getCharacter(player)
			if character and not isKnocked(player, character, humanoid) then
				local part = partFor(character, head, root, settings.part)
				if part then
					local worldDistance = (part.Position - origin).Magnitude
					if worldDistance <= maxDistance then
						local screen, onscreen = camera:WorldToViewportPoint(part.Position)
						if onscreen and screen.Z > 0 then
							local dx = screen.X - center.X
							local dy = screen.Y - center.Y
							local screenDistance = math.sqrt(dx * dx + dy * dy)
							if screenDistance <= radius or settings.ignoreFov then
								if not settings.wall or visible(player, character, part) then
									local score
									if settings.priority == "Distance" then
										score = worldDistance
									elseif settings.priority == "Health" then
										score = humanoid.Health
									else
										score = screenDistance + worldDistance * 0.02
									end
									if settings.sticky and current and player == current then
										score = score - 100000
									end
									if score < bestScore then
										bestScore = score
										best = player
										bestPart = part
										bestHumanoid = humanoid
										bestCharacter = character
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return best, bestPart, bestHumanoid, bestCharacter
end

local function keyDown(name)
	if not name or name == "None" then
		return false
	end
	local ok, code = pcall(function()
		return Enum.KeyCode[name]
	end)
	if not ok or not code then
		return false
	end
	return UserInputService:IsKeyDown(code)
end

local input = { fire = false }

UserInputService.InputBegan:Connect(function(item, processed)
	if processed then
		return
	end
	local kind = item.UserInputType
	if kind == Enum.UserInputType.MouseButton1 then
		input.fire = true
	elseif kind == Enum.UserInputType.Touch then
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		if item.Position.X > size.X * 0.4 then
			input.fire = true
		end
	end
end)

UserInputService.InputEnded:Connect(function(item)
	local kind = item.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		input.fire = false
	end
end)

local function aimActive()
	local settings = Config.aimbot
	if not settings.enabled then
		return false
	end
	if settings.mode == "Hold" then
		return keyDown(settings.key)
	end
	if settings.mode == "On Fire" then
		return input.fire
	end
	return true
end

--------------------------------------------------------------------------
-- Aim
--
-- Runs after Roblox's own camera update so the write survives the frame.
-- Three filters keep it smooth instead of twitchy:
--   1. the aim point is low-pass filtered with an exponential average
--   2. the turn is clamped to Max Turn degrees per second
--   3. inside the deadzone the camera is simply not written
-- There is no random offset anywhere, so the camera cannot shiver.
--------------------------------------------------------------------------

local AimState = {
	target = nil,
	part = nil,
	seen = 0,
	smooth = nil,
	point = nil,
	acquired = 0,
	watch = nil,
	lastHealth = nil,
	watchName = nil,
	hitUntil = 0,
	lastFire = 0,
}

local function releaseAim()
	AimState.target = nil
	AimState.part = nil
	AimState.smooth = nil
	AimState.point = nil
	AimState.watch = nil
	AimState.lastHealth = nil
	AimState.watchName = nil
end

local function aimPointFor(part, settings)
	local point = part.Position
	if settings.prediction and settings.prediction > 0 then
		local velocity = part.AssemblyLinearVelocity
		if velocity then
			point = point + velocity * (settings.prediction / 100)
		end
	end
	return point
end

local function writeCamera(point, delta, settings)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position

	if not AimState.smooth then
		AimState.smooth = point
	else
		local tau = math.max(settings.smooth or 110, 10) / 1000
		local alpha = 1 - math.exp(-delta / tau)
		AimState.smooth = AimState.smooth:Lerp(point, clamp(alpha, 0, 1))
		if (AimState.smooth - point).Magnitude > 60 then
			AimState.smooth = point
		end
	end

	local desired = AimState.smooth - origin
	if desired.Magnitude < 0.6 then
		return
	end
	desired = desired.Unit

	local current = camera.CFrame.LookVector
	local angle = math.acos(clamp(current:Dot(desired), -1, 1))
	if math.deg(angle) <= (settings.deadzone or 0) then
		return
	end

	local maxStep = math.rad(math.max(settings.turn or 720, 30)) * math.max(delta, 0.001)
	local direction
	if angle <= maxStep then
		direction = desired
	else
		direction = current:Lerp(desired, maxStep / angle).Unit
	end

	camera.CFrame = CFrame.lookAt(origin, origin + direction)
	AimState.point = AimState.smooth
end

local function stepAim(delta)
	local settings = Config.aimbot
	if not aimActive() then
		releaseAim()
		return
	end

	local now = clock()
	local current = AimState.target
	if current and AimState.part and settings.sticky then
		local character, humanoid, root, head = getCharacter(current)
		local stillThere = character and head and not isKnocked(current, character, humanoid)
		if stillThere then
			stillThere = (head.Position - cameraOrigin()).Magnitude <= (settings.maxDist or 900)
				and (now - AimState.seen) <= math.max(settings.stickyTime or 0.4, 0.05)
		end
		if stillThere then
			AimState.part = settings.part == "Head" and head or partFor(character, head, root, settings.part)
		else
			releaseAim()
			current = nil
		end
	end

	local player, part, humanoid = pickTarget(settings, current)
	if not player or not part then
		if AimState.watch and AimState.lastHealth and AimState.lastHealth > 0 then
			if AimState.watch.Health <= 0 and settings.hitMarker and AimState.watchName then
				notify("eliminated " .. AimState.watchName, Theme.good)
			end
		end
		AimState.watch = nil
		releaseAim()
		return
	end

	if player ~= AimState.target then
		AimState.target = player
		AimState.acquired = now
		AimState.smooth = nil
	end
	AimState.seen = now

	if humanoid then
		if AimState.watch ~= humanoid then
			AimState.watch = humanoid
			AimState.lastHealth = humanoid.Health
			AimState.watchName = player.DisplayName or player.Name
		elseif AimState.lastHealth and humanoid.Health < AimState.lastHealth - 0.5 then
			if settings.hitMarker then
				AimState.hitUntil = now + 0.14
			end
			local damage = math.floor(AimState.lastHealth - humanoid.Health + 0.5)
			if damage > 0 then
				notify(string.format("%s  -%d", AimState.watchName or player.Name, damage), Theme.accentSoft)
			end
		end
		AimState.lastHealth = humanoid.Health
	end

	local point = aimPointFor(part, settings)
	writeCamera(point, delta, settings)
	AimState.part = part

	if settings.autoFire and AimState.point then
		local camera = workspace.CurrentCamera
		if camera then
			local toPoint = AimState.point - camera.CFrame.Position
			if toPoint.Magnitude > 0.1 and camera.CFrame.LookVector:Dot(toPoint.Unit) > 0.995 then
				if now - AimState.lastFire >= (settings.fireDelay or 60) / 1000 then
					AimState.lastFire = now
					fireWeapon()
				end
			end
		end
	end
end

--------------------------------------------------------------------------
-- Rage
--------------------------------------------------------------------------

local Rage = { lastFire = 0, target = nil }

local function stepRage(delta)
	local settings = Config.ragebot
	if not settings.enabled or not keyDown(settings.key) then
		Rage.target = nil
		return
	end
	local player, part = pickTarget(settings, Rage.target)
	Rage.target = player
	if not player or not part then
		return
	end
	if math.random() * 100 > (settings.chance or 100) then
		return
	end
	local point = part.Position
	if settings.resolver then
		local velocity = part.AssemblyLinearVelocity
		if velocity then
			point = point + velocity * pingSeconds()
		end
	end
	if settings.snap == "Smooth" then
		writeCamera(point, delta, { smooth = 24, turn = 1440, deadzone = 0 })
	else
		local camera = workspace.CurrentCamera
		if camera then
			local origin = camera.CFrame.Position
			if (point - origin).Magnitude > 0.4 then
				camera.CFrame = CFrame.lookAt(origin, point)
				AimState.smooth = nil
				AimState.point = point
			end
		end
	end
	if settings.autoFire then
		local now = clock()
		if now - Rage.lastFire >= (settings.fireDelay or 40) / 1000 then
			Rage.lastFire = now
			fireWeapon()
		end
	end
end

--------------------------------------------------------------------------
-- Silent aim
--
-- The camera is rotated only for the duration of the remote call, so nothing
-- on screen moves. It is restored before the frame renders.
--------------------------------------------------------------------------

local Silent = { point = nil, target = nil, hooked = false }

local function installSilentHook()
	if Silent.hooked then
		return
	end
	if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
		return
	end
	local ok = pcall(function()
		local original
		original = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()
			local isAttack = method == "FireServer" or method == "Fire" or method == "InvokeServer"
			if isAttack and Silent.point and not checkcaller() then
				local camera = workspace.CurrentCamera
				if camera then
					local saved = camera.CFrame
					local origin = saved.Position
					if (Silent.point - origin).Magnitude > 0.4 then
						camera.CFrame = CFrame.lookAt(origin, Silent.point)
					end
					local results = { pcall(original, self, ...) }
					camera.CFrame = saved
					if results[1] then
						return unpackFn(results, 2)
					end
					return nil
				end
			end
			return original(self, ...)
		end)
		Silent.hooked = true
	end)
	if not ok then
		Silent.hooked = false
	end
end

local function stepSilent()
	local settings = Config.silentaim
	if not settings.enabled or not keyDown(settings.key) then
		Silent.point = nil
		Silent.target = nil
		return
	end
	local player, part = pickTarget(settings, Silent.target)
	Silent.target = player
	if not player or not part then
		Silent.point = nil
		return
	end
	if math.random() * 100 > (settings.chance or 100) then
		Silent.point = nil
		return
	end
	local point = part.Position
	if settings.prediction and settings.prediction > 0 then
		local velocity = part.AssemblyLinearVelocity
		if velocity then
			point = point + velocity * (settings.prediction / 100)
		end
	end
	Silent.point = point
	if settings.mode ~= "Camera" then
		local character = LP.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(point.X, root.Position.Y, point.Z))
		end
	end
end

--------------------------------------------------------------------------
-- Triggerbot
--------------------------------------------------------------------------

local Trigger = { last = 0 }

local function stepTrigger()
	local settings = Config.triggerbot
	if not settings.enabled or not keyDown(settings.key) then
		return
	end
	local now = clock()
	local wait = math.max(settings.delay or 60, 10) / 1000
	if now - Trigger.last < wait then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local target, part
	if (settings.fov or 0) > 0 then
		local mode = "Nearest"
		if settings.hitbox == "Head" then
			mode = "Head"
		elseif settings.hitbox == "Body" then
			mode = "Body"
		end
		target, part = pickTarget({
			fov = settings.fov,
			part = mode,
			team = settings.team,
			wall = settings.wall,
			maxDist = settings.maxDist,
			priority = "Crosshair",
		}, nil)
	else
		local filter = { camera }
		if LP.Character then
			filter[#filter + 1] = LP.Character
		end
		rayParams.FilterDescendantsInstances = filter
		local hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * (settings.maxDist or 400), rayParams)
		if hit and hit.Instance then
			local node = hit.Instance
			while node and node ~= workspace do
				if node:IsA("Model") then
					local found = Players:GetPlayerFromCharacter(node)
					if found then
						target = found
						part = hit.Instance
						break
					end
				end
				node = node.Parent
			end
		end
	end

	if not target or target == LP then
		return
	end
	local character = getCharacter(target)
	if not character then
		return
	end
	if settings.hitbox == "Head" and part and part.Name then
		if not part.Name:lower():find("head") then
			return
		end
	end
	if math.random() * 100 > (settings.chance or 100) then
		return
	end
	local jitter = (settings.jitter or 0) / 1000
	if jitter > 0 and math.random() * jitter > 0.01 then
		return
	end
	Trigger.last = now
	fireWeapon()
end

--------------------------------------------------------------------------
-- Combat extras
--------------------------------------------------------------------------

local combat = {
	lastSwing = 0,
	lastShoot = 0,
	lastBlock = 0,
	lastDodge = 0,
	lastAbility = 0,
	lastEquip = 0,
}

local hitboxSizes = setmetatable({}, { __mode = "k" })

local function restoreHitboxes()
	for part, size in pairs(hitboxSizes) do
		if part and part.Parent then
			pcall(function()
				part.Size = size
			end)
		end
	end
	hitboxSizes = setmetatable({}, { __mode = "k" })
end

local function tapKey(name)
	if not name or name == "None" then
		return
	end
	local ok, code = pcall(function()
		return Enum.KeyCode[name]
	end)
	if not ok or not code then
		return
	end
	if type(keypress) == "function" then
		if pcall(keypress, code) then
			return
		end
	end
	pcall(function()
		local manager = game:GetService("VirtualInputManager")
		manager:SendKeyEvent(true, code, false, game)
		task.wait(0.05)
		manager:SendKeyEvent(false, code, false, game)
	end)
end

local function nearestEnemy(range, team)
	local origin = cameraOrigin()
	local best, bestDistance, bestCharacter, bestHumanoid = nil, range, nil, nil
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LP and not (team and sameTeam(player)) then
			local character, humanoid, root = getCharacter(player)
			if character and root then
				local distance = (root.Position - origin).Magnitude
				if distance < bestDistance then
					best, bestDistance, bestCharacter, bestHumanoid = player, distance, character, humanoid
				end
			end
		end
	end
	return best, bestDistance, bestCharacter, bestHumanoid
end

local function stepCombat(delta)
	local now = clock()

	-- Kill aura
	local aura = Config.killaura
	if aura.enabled then
		local rate = 1 / math.max(aura.rate or 6, 1)
		if now - combat.lastSwing >= rate then
			local target, distance, character = nearestEnemy(aura.range or 18, aura.team)
			if target and character then
				local head = character:FindFirstChild("Head")
				if head and not (aura.wall and rayBlocked(character, head)) then
					combat.lastSwing = now
					if aura.rotate then
						local camera = workspace.CurrentCamera
						if camera then
							camera.CFrame = CFrame.lookAt(camera.CFrame.Position, head.Position)
						end
					end
					fireWeapon()
				end
			end
		end
	end

	-- Auto shoot
	local shoot = Config.autoshoot
	if shoot.enabled and now - combat.lastShoot >= (shoot.delay or 80) / 1000 then
		local target, distance, character = nearestEnemy(shoot.range or 220, shoot.team)
		if target and character and math.random() * 100 <= (shoot.chance or 100) then
			local head = character:FindFirstChild("Head")
			if head and not (shoot.wall and rayBlocked(character, head)) then
				combat.lastShoot = now
				fireWeapon()
			end
		end
	end

	-- Auto parry / block
	local parry = Config.autoparry
	local block = Config.autoblock
	if parry.enabled or block.enabled then
		local range = parry.enabled and (parry.range or 14) or (block.range or 12)
		local target = nearestEnemy(range, block.team)
		if target then
			if parry.enabled then
				if now - combat.lastBlock >= ((parry.window or 180) + (parry.reaction or 60)) / 1000 then
					combat.lastBlock = now
					tapKey(parry.key)
				end
			elseif now - combat.lastBlock >= ((block.hold or 220) + (block.delay or 40)) / 1000 then
				combat.lastBlock = now
				tapKey("F")
			end
		end
	end

	-- Auto dodge
	local dodge = Config.autododge
	if dodge.enabled and now - combat.lastDodge >= (dodge.cooldown or 1.2) then
		local target = nearestEnemy(dodge.range or 20)
		if target then
			combat.lastDodge = now
			local character = LP.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local direction = root.CFrame.RightVector
				if dodge.direction == "Right" then
					direction = -direction
				elseif dodge.direction == "Back" then
					direction = -root.CFrame.LookVector
				end
				root.AssemblyLinearVelocity = direction * (dodge.power or 60) + Vector3.new(0, 12, 0)
			end
		end
	end

	-- Auto ability
	local ability = Config.autoability
	if ability.enabled and now - combat.lastAbility >= (ability.buffer or 0.5) then
		local target = nearestEnemy(ability.range or 30)
		if target or not ability.onlyWithTarget then
			combat.lastAbility = now
			tapKey(ability.key)
		end
	end

	-- Auto equip
	local equip = Config.autoequip
	if equip.enabled and now - combat.lastEquip >= (equip.delay or 120) / 1000 then
		combat.lastEquip = now
		local backpack = LP:FindFirstChild("Backpack")
		local character = LP.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if backpack and humanoid then
			local wantRanged = equip.priority == "Ranged"
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then
					local lower = tool.Name:lower()
					local isRanged = lower:find("gun") or lower:find("bow") or lower:find("blaster") or lower:find("rifle")
					if (wantRanged and isRanged) or (not wantRanged and not isRanged) then
						pcall(function()
							humanoid:EquipTool(tool)
						end)
						break
					end
				end
			end
		end
	end

	-- Hitbox expander / reach assist, with proper restore
	local hitbox = Config.hitbox
	local reach = Config.reach
	local origin = cameraOrigin()
	local keep = {}
	if hitbox.enabled or reach.enabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LP and not (hitbox.enabled and hitbox.team and sameTeam(player)) then
				local character, humanoid, root, head = getCharacter(player)
				if character then
					local part = head
					if hitbox.enabled then
						if hitbox.part == "Torso" then
							part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or head
						elseif hitbox.part == "All" then
							part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
						end
					end
					if part and part:IsA("BasePart") then
						local distance = (root.Position - origin).Magnitude
						local limit = hitbox.enabled and (hitbox.distance or 400) or (reach.distance or 12) * 3
						if distance <= limit then
							if not hitboxSizes[part] then
								hitboxSizes[part] = part.Size
							end
							keep[part] = true
							if hitbox.enabled then
								part.Size = Vector3.new(hitbox.size or 2, hitbox.size or 2, hitbox.size or 2)
							else
								part.Size = Vector3.new(2, 3, 2)
							end
						end
					end
				end
			end
		end
	end
	for part in pairs(hitboxSizes) do
		if not keep[part] then
			if part and part.Parent then
				pcall(function()
					part.Size = hitboxSizes[part]
				end)
			end
			hitboxSizes[part] = nil
		end
	end
end
--------------------------------------------------------------------------
-- ESP, HUD and world visuals
--------------------------------------------------------------------------

local SKELETON_R15 = {
	{ "Head", "UpperTorso" },
	{ "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" },
	{ "LeftUpperArm", "LeftLowerArm" },
	{ "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" },
	{ "RightUpperArm", "RightLowerArm" },
	{ "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" },
	{ "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" },
	{ "RightUpperLeg", "RightLowerLeg" },
	{ "RightLowerLeg", "RightFoot" },
}

local SKELETON_R6 = {
	{ "Head", "Torso" },
	{ "Torso", "Left Arm" },
	{ "Torso", "Right Arm" },
	{ "Torso", "Left Leg" },
	{ "Torso", "Right Leg" },
}

local ESP = {
	entries = {},
	chams = {},
	items = {},
	itemClock = 0,
}

local function newEntry()
	local entry = {
		box = drawing("Square"),
		fill = drawing("Square"),
		healthBack = drawing("Square"),
		healthBar = drawing("Square"),
		name = drawing("Text"),
		distance = drawing("Text"),
		healthText = drawing("Text"),
		tracer = drawing("Line"),
		headDot = drawing("Square"),
		arrow = drawing("Triangle"),
		corners = {},
		bones = {},
	}
	return entry
end

local function dropEntry(entry)
	for _, object in pairs(entry) do
		if type(object) == "table" then
			for _, child in ipairs(object) do
				drop(child)
			end
		else
			drop(object)
		end
	end
end

local function espColor(player, settings)
	if settings.teamColor and player.TeamColor then
		return player.TeamColor.Color
	end
	return Theme.accentSoft
end

local function updateSkeleton(entry, character, camera, thickness, transparency)
	local links = character:FindFirstChild("UpperTorso") and SKELETON_R15 or SKELETON_R6
	for index, link in ipairs(links) do
		local object = entry.bones[index]
		if not object then
			object = drawing("Line")
			entry.bones[index] = object
		end
		local jointA = character:FindFirstChild(link[1], true)
		local jointB = character:FindFirstChild(link[2], true)
		if object and jointA and jointB then
			local a = onScreen(camera, jointA.Position)
			local b = onScreen(camera, jointB.Position)
			if a and b then
				line(object, a, b, Theme.text, thickness, transparency)
			else
				hide(object)
			end
		elseif object then
			hide(object)
		end
	end
	for index = #links + 1, #entry.bones do
		hide(entry.bones[index])
	end
end

local function updateChams(character, settings)
	local highlight = ESP.chams[character]
	if settings and not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "RClientChams"
		highlight.Adornee = character
		highlight.FillColor = Theme.accent
		highlight.OutlineColor = Theme.accentSoft
		highlight.DepthMode = settings.throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		highlight.Parent = workspace
		ESP.chams[character] = highlight
	end
	if highlight then
		highlight.FillTransparency = 1 - (settings.fill or 0.55)
		highlight.OutlineTransparency = 1 - (settings.outline or 0.9)
		highlight.DepthMode = settings.throughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
	end
end

local function updateESP()
	if not DRAW_OK then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local esp = Config.esp
	local skeleton = Config.skeleton
	local cham = Config.chams
	local tracers = Config.tracers
	local arrows = Config.arrows
	local size = camera.ViewportSize
	local origin = camera.CFrame.Position
	local seen = {}
	local alive = {}

	if esp.enabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LP then
				local character, humanoid, root, head = getCharacter(player)
				local skip = not character
				if character then
					if esp.team and sameTeam(player) then
						skip = true
					end
					if isKnocked(player, character, humanoid) then
						skip = true
					end
					local distance = (root.Position - origin).Magnitude
					if distance > (esp.maxDist or 500) or distance < 0.6 then
						skip = true
					end
				end

				if not skip then
					local distance = (root.Position - origin).Magnitude
					local entry = ESP.entries[player]
					if not entry then
						entry = newEntry()
						ESP.entries[player] = entry
					end
					seen[player] = true
					alive[character] = true

					local top = onScreen(camera, head.Position + Vector3.new(0, 1.1, 0))
					local foot = onScreen(camera, root.Position - Vector3.new(0, 2.6, 0))
					local color = espColor(player, esp)

					if top and foot then
						local height = math.abs(foot.Y - top.Y)
						local width = math.max(height * 0.55, 6)
						local centerX = (top.X + foot.X) * 0.5
						local topY = math.min(top.Y, foot.Y)
						local bottomY = math.max(top.Y, foot.Y)
						local left = centerX - width * 0.5
						local alpha = clamp(1 - (distance / math.max(esp.maxDist, 1)) * 0.6, 0.35, 1)
						local transparency = 1 - alpha * (esp.opacity or 1)

						if esp.style == "Thin" then
							square(entry.box, Vector2.new(left, topY), Vector2.new(width, height), color, 1, transparency, false)
						elseif esp.style == "Corners" then
							hide(entry.box)
							local reach = math.min(width, height) * 0.24
							local points = {
								{ left, topY, left + reach, topY },
								{ left, topY, left, topY + reach },
								{ left + width, topY, left + width - reach, topY },
								{ left + width, topY, left + width, topY + reach },
								{ left, bottomY, left + reach, bottomY },
								{ left, bottomY, left, bottomY - reach },
								{ left + width, bottomY, left + width - reach, bottomY },
								{ left + width, bottomY, left + width, bottomY - reach },
							}
							for index, point in ipairs(points) do
								local object = entry.corners[index]
								if not object then
									object = drawing("Line")
									entry.corners[index] = object
								end
								line(object, Vector2.new(point[1], point[2]), Vector2.new(point[3], point[4]), color, 1, transparency)
							end
						else
							square(entry.box, Vector2.new(left, topY), Vector2.new(width, height), color, 1, transparency, false)
						end
						for index = 1, #entry.corners do
							if esp.style ~= "Corners" or index > 8 then
								hide(entry.corners[index])
							end
						end

						if esp.fill then
							square(entry.fill, Vector2.new(left + 1, topY + 1), Vector2.new(math.max(width - 2, 1), math.max(height - 2, 1)), color, 1, math.max(transparency, 0.82), true)
						else
							hide(entry.fill)
						end

						if esp.health and humanoid then
							local ratio = clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
							local barX = left - px(6)
							square(entry.healthBack, Vector2.new(barX, topY), Vector2.new(px(3), height), Theme.black, 1, 0.35, true)
							square(entry.healthBar, Vector2.new(barX, topY + height * (1 - ratio)), Vector2.new(px(3), math.max(height * ratio, 1)), Theme.good:Lerp(Theme.bad, 1 - ratio), 1, 0.05, true)
						else
							hide(entry.healthBack)
							hide(entry.healthBar)
						end

						if esp.healthText and humanoid then
							text(entry.healthText, tostring(math.floor(humanoid.Health + 0.5)), Vector2.new(left - px(12), topY + height * 0.5), Theme.text, px(10))
						else
							hide(entry.healthText)
						end

						if esp.name then
							local name = player.DisplayName or player.Name
							if esp.nameMode == "Username" then
								name = player.Name
							elseif esp.nameMode == "Both" then
								name = (player.DisplayName or player.Name) .. " (" .. player.Name .. ")"
							end
							text(entry.name, name, Vector2.new(centerX, topY - px(11)), Theme.text, px(esp.textSize or 13))
						else
							hide(entry.name)
						end

						if esp.distance then
							text(entry.distance, string.format("%dm", math.floor(distance + 0.5)), Vector2.new(centerX, bottomY + px(7)), color, px(math.max((esp.textSize or 13) - 3, 8)))
						else
							hide(entry.distance)
						end

						if Config.skeleton.enabled and distance <= (skeleton.maxDist or 400) then
							updateSkeleton(entry, character, camera, skeleton.thickness or 1, skeleton.transparency or 0.15)
						else
							for _, bone in ipairs(entry.bones) do
								hide(bone)
							end
						end

						if tracers.enabled and distance <= (tracers.maxDist or 450) then
							local fromY = size.Y
							if tracers.origin == "Center" then
								fromY = size.Y * 0.5
							elseif tracers.origin == "Top" then
								fromY = 0
							end
							line(entry.tracer, Vector2.new(size.X * 0.5, fromY), Vector2.new(centerX, bottomY), color, tracers.thickness or 1, 1 - (tracers.alpha or 0.65))
						else
							hide(entry.tracer)
						end

						if Config.esp.name and Config.esp.headDot ~= false then
							square(entry.headDot, Vector2.new(top.X - px(2.5), top.Y + px(2), px(5), px(5)), Theme.bad, 1, 0.2, true)
						else
							hide(entry.headDot)
						end

						if cham.enabled then
							updateChams(character, cham)
						end
					else
						if entry then
							hide(entry.box)
							hide(entry.fill)
							hide(entry.name)
							hide(entry.distance)
							hide(entry.tracer)
							hide(entry.headDot)
							hide(entry.healthBack)
							hide(entry.healthBar)
							hide(entry.healthText)
							for _, corner in ipairs(entry.corners) do
								hide(corner)
							end
							for _, bone in ipairs(entry.bones) do
								hide(bone)
							end
						end
					end

					if arrows.enabled and distance <= (arrows.maxDist or 500) then
						local point = onScreen(camera, head.Position)
						local entryRef = ESP.entries[player]
						if not point and entryRef then
							local world, visiblePoint = camera:WorldToViewportPoint(head.Position)
							local sx, sy = world.X, world.Y
							if world.Z <= 0 then
								sx = size.X - sx
								sy = size.Y * 0.5
							end
							local dx = sx - size.X * 0.5
							local dy = sy - size.Y * 0.5
							local length = math.max(math.sqrt(dx * dx + dy * dy), 0.1)
							local ux, uy = dx / length, dy / length
							local margin = px(56)
							local scaleX = (size.X * 0.5 - margin) / math.max(math.abs(ux), 0.001)
							local scaleY = (size.Y * 0.5 - margin) / math.max(math.abs(uy), 0.001)
							local reach = math.min(scaleX, scaleY)
							local tipX = size.X * 0.5 + ux * reach
							local tipY = size.Y * 0.5 + uy * reach
							local arrow = entryRef.arrow
							if arrow then
								local tip = math.max(arrows.size or 12, 6)
								local half = tip * 0.62
								arrow.PointA = Vector2.new(tipX, tipY)
								arrow.PointB = Vector2.new(tipX - ux * tip - uy * half, tipY - uy * tip + ux * half)
								arrow.PointC = Vector2.new(tipX - ux * tip + uy * half, tipY - uy * tip - ux * half)
								arrow.Color = Theme.accent
								arrow.Thickness = 1
								arrow.Filled = true
								arrow.Transparency = 0.15
								arrow.Visible = true
							end
						elseif entryRef then
							hide(entryRef.arrow)
						end
					elseif ESP.entries[player] then
						hide(ESP.entries[player].arrow)
					end
				end
			end
		end
	end

	for player, entry in pairs(ESP.entries) do
		if not seen[player] then
			dropEntry(entry)
			ESP.entries[player] = nil
		end
	end

	for character, highlight in pairs(ESP.chams) do
		if not alive[character] or not cham.enabled or not esp.enabled then
			pcall(function()
				highlight:Destroy()
			end)
			ESP.chams[character] = nil
		end
	end
end

--------------------------------------------------------------------------
-- Item ESP
--------------------------------------------------------------------------

local function updateItemESP(delta)
	ESP.itemClock = ESP.itemClock + delta
	local settings = Config.itemesp
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if not settings.enabled or not DRAW_OK then
		if next(ESP.items) then
			for object, entry in pairs(ESP.items) do
				drop(entry.box)
				drop(entry.label)
				ESP.items[object] = nil
			end
		end
		return
	end
	if ESP.itemClock >= 0.5 then
		ESP.itemClock = 0
		local found = {}
		for _, object in ipairs(workspace:GetDescendants()) do
			if object:IsA("Tool") then
				local holder = object.Parent and Players:GetPlayerFromCharacter(object.Parent)
				if not holder then
					found[object] = true
					if not ESP.items[object] then
						ESP.items[object] = { box = drawing("Square"), label = drawing("Text") }
					end
				end
			end
		end
		for object, entry in pairs(ESP.items) do
			if not found[object] or not object.Parent then
				drop(entry.box)
				drop(entry.label)
				ESP.items[object] = nil
			end
		end
	end
	local origin = camera.CFrame.Position
	for object, entry in pairs(ESP.items) do
		local handle = object:FindFirstChild("Handle")
		if handle then
			local distance = (handle.Position - origin).Magnitude
			local point = distance <= (settings.maxDist or 200) and onScreen(camera, handle.Position) or nil
			if point then
				square(entry.box, Vector2.new(point.X - px(4), point.Y - px(4)), Vector2.new(px(8), px(8)), Theme.good, 1, 0.3, false)
				if settings.names then
					local value = object.Name
					if settings.distance then
						value = string.format("%s  %dm", value, math.floor(distance + 0.5))
					end
					text(entry.label, value, Vector2.new(point.X, point.Y - px(12)), Theme.good, px(11))
				else
					hide(entry.label)
				end
			else
				hide(entry.box)
				hide(entry.label)
			end
		else
			hide(entry.box)
			hide(entry.label)
		end
	end
end

--------------------------------------------------------------------------
-- Crosshair, FOV ring, radar, hit marker, target HUD
--------------------------------------------------------------------------

local hud = {
	cross = {},
	dot = nil,
	ring = nil,
	ringFill = nil,
	radarCircle = nil,
	radarDots = {},
	hit = {},
	targetName = nil,
	targetBar = nil,
	targetBack = nil,
}

local function drawCrosshair(camera)
	local settings = Config.crosshair
	if not DRAW_OK or not settings.enabled then
		for _, object in pairs(hud.cross) do
			hide(object)
		end
		hide(hud.dot)
		return
	end
	local size = camera.ViewportSize
	local center = Vector2.new(size.X * 0.5, size.Y * 0.5)
	if #hud.cross == 0 then
		for index = 1, 4 do
			hud.cross[index] = drawing("Line")
		end
		hud.dot = drawing("Square")
	end
	local gap = settings.gap or 3
	local reach = settings.size or 9
	local thickness = settings.thickness or 1
	for _, object in ipairs(hud.cross) do
		hide(object)
	end
	if settings.style == "Cross" then
		line(hud.cross[1], Vector2.new(center.X - gap - reach, center.Y), Vector2.new(center.X - gap, center.Y), Theme.text, thickness, 0.1)
		line(hud.cross[2], Vector2.new(center.X + gap, center.Y), Vector2.new(center.X + gap + reach, center.Y), Theme.text, thickness, 0.1)
		line(hud.cross[3], Vector2.new(center.X, center.Y - gap - reach), Vector2.new(center.X, center.Y - gap), Theme.text, thickness, 0.1)
		line(hud.cross[4], Vector2.new(center.X, center.Y + gap), Vector2.new(center.X, center.Y + gap + reach), Theme.text, thickness, 0.1)
	elseif settings.style == "T" then
		line(hud.cross[1], Vector2.new(center.X - reach, center.Y), Vector2.new(center.X + reach, center.Y), Theme.text, thickness, 0.1)
		line(hud.cross[2], Vector2.new(center.X, center.Y + gap), Vector2.new(center.X, center.Y + gap + reach), Theme.text, thickness, 0.1)
	end
	local dotSize = math.max(thickness + 1, 2)
	square(hud.dot, Vector2.new(center.X - dotSize * 0.5, center.Y - dotSize * 0.5), Vector2.new(dotSize, dotSize), Theme.text, 1, 0.05, true)
end

local function drawFov(camera)
	local settings = Config.fovcircle
	if not DRAW_OK or not settings.enabled then
		hide(hud.ring)
		hide(hud.ringFill)
		return
	end
	local size = camera.ViewportSize
	local center = Vector2.new(size.X * 0.5, size.Y * 0.5)
	local radius = screenRadius(camera, (Config.aimbot.enabled and Config.aimbot.fov) or 90)
	if settings.pulse and Config.aimbot.enabled then
		radius = radius + math.sin(clock() * 3) * 2
	end
	if not hud.ring then
		hud.ring = drawing("Circle")
		hud.ringFill = drawing("Circle")
	end
	if hud.ring then
		hud.ring.Position = center
		hud.ring.Radius = radius
		hud.ring.Thickness = settings.thickness or 1
		hud.ring.Color = Theme.accent
		hud.ring.Transparency = 1 - (settings.alpha or 0.55)
		hud.ring.Filled = false
		hud.ring.Visible = true
	end
	if hud.ringFill then
		hud.ringFill.Position = center
		hud.ringFill.Radius = radius
		hud.ringFill.Thickness = 1
		hud.ringFill.Color = Theme.accent
		hud.ringFill.Filled = settings.fill == true
		hud.ringFill.Transparency = settings.fill and 0.985 or 1
		hud.ringFill.Visible = settings.fill == true
	end
end

local function drawRadar(camera)
	local settings = Config.radar
	if not DRAW_OK or not settings.enabled then
		hide(hud.radarCircle)
		for _, object in pairs(hud.radarDots) do
			hide(object)
		end
		return
	end
	local size = camera.ViewportSize
	local radius = (settings.size or 110) * 0.5
	local margin = radius + px(18)
	local anchor = Vector2.new(size.X - margin, size.Y - margin)
	if settings.corner == "Top Left" then
		anchor = Vector2.new(margin, margin)
	elseif settings.corner == "Top Right" then
		anchor = Vector2.new(size.X - margin, margin)
	elseif settings.corner == "Bottom Left" then
		anchor = Vector2.new(margin, size.Y - margin)
	end
	if not hud.radarCircle then
		hud.radarCircle = drawing("Circle")
	end
	local circle = hud.radarCircle
	if circle then
		circle.Position = anchor
		circle.Radius = radius
		circle.Thickness = 1
		circle.Color = Theme.stroke
		circle.Filled = true
		circle.Transparency = 0.82
		circle.Visible = true
	end

	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local angle = math.atan2(look.Z, look.X)
	if not settings.rotation then
		angle = 0
	end
	local index = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LP then
			local character, humanoid, root = getCharacter(player)
			if character and root and not isKnocked(player, character, humanoid) then
				local offset = root.Position - origin
				local flat = Vector2.new(offset.X, offset.Z)
				local distance = flat.Magnitude
				if distance <= (settings.range or 300) then
					local scale = radius / math.max(settings.range or 300, 1)
					local rotated = Vector2.new(
						flat.X * math.cos(-angle) - flat.Y * math.sin(-angle),
						flat.X * math.sin(-angle) + flat.Y * math.cos(-angle)
					)
					index = index + 1
					local dot = hud.radarDots[index]
					if not dot then
						dot = drawing("Circle")
						hud.radarDots[index] = dot
					end
					local point = anchor + rotated * scale
					dot.Position = point
					dot.Radius = (settings.dotSize or 4) * 0.5
					dot.Filled = true
					dot.Transparency = 0.1
					dot.Color = sameTeam(player) and Theme.good or Theme.bad
					dot.Visible = true
				end
			end
		end
	end
	for i = index + 1, #hud.radarDots do
		hide(hud.radarDots[i])
	end
end

local function drawHitMarker(camera)
	if not DRAW_OK then
		return
	end
	local active = clock() < AimState.hitUntil
	for index = 1, 4 do
		if not hud.hit[index] then
			hud.hit[index] = drawing("Line")
		end
	end
	if not active then
		for _, object in ipairs(hud.hit) do
			hide(object)
		end
		return
	end
	local size = camera.ViewportSize
	local center = Vector2.new(size.X * 0.5, size.Y * 0.5)
	local reach = px(9)
	local gap = px(3)
	local fade = clamp((AimState.hitUntil - clock()) / 0.14, 0, 1)
	line(hud.hit[1], center + Vector2.new(-gap - reach, -gap - reach), center + Vector2.new(-gap, -gap), Theme.text, 2, 1 - fade)
	line(hud.hit[2], center + Vector2.new(gap, -gap), center + Vector2.new(gap + reach, -gap - reach), Theme.text, 2, 1 - fade)
	line(hud.hit[3], center + Vector2.new(-gap, gap), center + Vector2.new(-gap - reach, gap + reach), Theme.text, 2, 1 - fade)
	line(hud.hit[4], center + Vector2.new(gap + reach, gap + reach), center + Vector2.new(gap, gap), Theme.text, 2, 1 - fade)
end

local function drawTargetHud(camera)
	local settings = Config.aimbot
	if not DRAW_OK or not settings.enabled or not settings.targetHud or not AimState.target then
		hide(hud.targetName)
		hide(hud.targetBar)
		hide(hud.targetBack)
		return
	end
	local character, humanoid = getCharacter(AimState.target)
	if not character or not humanoid then
		hide(hud.targetName)
		hide(hud.targetBar)
		hide(hud.targetBack)
		return
	end
	local size = camera.ViewportSize
	local center = Vector2.new(size.X * 0.5, size.Y * 0.5)
	if not hud.targetName then
		hud.targetName = drawing("Text")
		hud.targetBar = drawing("Square")
		hud.targetBack = drawing("Square")
	end
	local ratio = clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	local width = px(92)
	local y = center.Y + px(38)
	text(hud.targetName, string.format("%s  %d", AimState.target.DisplayName or AimState.target.Name, math.floor(humanoid.Health + 0.5)), Vector2.new(center.X, y - px(10)), Theme.text, px(12))
	square(hud.targetBack, Vector2.new(center.X - width * 0.5, y), Vector2.new(width, px(3)), Theme.black, 1, 0.35, true)
	square(hud.targetBar, Vector2.new(center.X - width * 0.5, y), Vector2.new(width * ratio, px(3)), Theme.good:Lerp(Theme.bad, 1 - ratio), 1, 0.05, true)
end

--------------------------------------------------------------------------
-- World visuals
--------------------------------------------------------------------------

local Visual = {
	saved = nil,
	fog = nil,
	effects = {},
	grade = nil,
}

local function updateVisuals()
	local settings = Config.visual
	local fullbright = Config.fullbright
	local nofog = Config.nofog
	local noeffects = Config.noeffects
	local customtime = Config.customtime
	local grade = Config.colorgrade

	if fullbright.enabled then
		if not Visual.saved then
			Visual.saved = {
				brightness = Lighting.Brightness,
				ambient = Lighting.Ambient,
				outdoor = Lighting.OutdoorAmbient,
				clock = Lighting.ClockTime,
			}
		end
		Lighting.Brightness = fullbright.brightness or 3
		local ambient = (fullbright.ambient or 180) / 255
		Lighting.Ambient = Color3.fromRGB(255 * ambient, 255 * ambient, 255 * ambient)
		Lighting.OutdoorAmbient = Color3.fromRGB(255 * ambient, 255 * ambient, 255 * ambient)
		if fullbright.clock then
			Lighting.ClockTime = 14
		end
	elseif Visual.saved then
		Lighting.Brightness = Visual.saved.brightness
		Lighting.Ambient = Visual.saved.ambient
		Lighting.OutdoorAmbient = Visual.saved.outdoor
		Lighting.ClockTime = Visual.saved.clock
		Visual.saved = nil
	end

	if nofog.enabled then
		if not Visual.fog then
			Visual.fog = { start = Lighting.FogStart, finish = Lighting.FogEnd }
		end
		Lighting.FogStart = 1000000
		Lighting.FogEnd = 1000000
		if nofog.atmosphere then
			for _, object in ipairs(Lighting:GetChildren()) do
				if object:IsA("Atmosphere") then
					object.Density = 0
					object.Haze = 0
				end
			end
		end
	elseif Visual.fog then
		Lighting.FogStart = Visual.fog.start
		Lighting.FogEnd = Visual.fog.finish
		Visual.fog = nil
	end

	if customtime.enabled then
		if customtime.freeze then
			Lighting.ClockTime = customtime.time or 14
		end
	elseif noeffects.enabled then
		Lighting.ClockTime = Lighting.ClockTime
	end

	if noeffects.enabled then
		for _, object in ipairs(Lighting:GetChildren()) do
			local wanted = (object:IsA("BlurEffect") and noeffects.blur)
				or (object:IsA("SunRaysEffect") and noeffects.rays)
				or (object:IsA("ColorCorrectionEffect") and noeffects.grade)
			if wanted then
				if Visual.effects[object] == nil then
					Visual.effects[object] = object.Enabled
				end
				object.Enabled = false
			end
		end
	else
		for object, enabled in pairs(Visual.effects) do
			if object and object.Parent then
				object.Enabled = enabled
			end
		end
		Visual.effects = {}
	end

	if grade.enabled then
		if not Visual.grade then
			Visual.grade = Instance.new("ColorCorrectionEffect")
			Visual.grade.Name = "RClientGrade"
			Visual.grade.Parent = Lighting
		end
		Visual.grade.Saturation = grade.saturation or 0
		Visual.grade.Contrast = grade.contrast or 0
		Visual.grade.Brightness = grade.brightness or 0
		Visual.grade.TintColor = Theme.accentSoft
	elseif Visual.grade then
		pcall(function()
			Visual.grade:Destroy()
		end)
		Visual.grade = nil
	end
end
--------------------------------------------------------------------------
-- Movement
--------------------------------------------------------------------------

local Move = {
	humanoid = nil,
	baseSpeed = 16,
	baseJump = 50,
	flyBody = nil,
	flying = false,
	clipped = {},
	scales = {},
	lastLongJump = 0,
	baseFov = nil,
	jumpApplied = false,
}

local function currentHumanoid()
	local character = LP.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character
end

local function stopFly()
	if Move.flyBody then
		pcall(function()
			Move.flyBody:Destroy()
		end)
		Move.flyBody = nil
	end
	if Move.flying then
		local humanoid = currentHumanoid()
		if humanoid then
			pcall(function()
				humanoid.PlatformStand = false
			end)
		end
	end
	Move.flying = false
end

local function restoreNoclip()
	for part in pairs(Move.clipped) do
		if part and part.Parent then
			pcall(function()
				part.CanCollide = true
			end)
		end
	end
	Move.clipped = {}
end

local function doLongJump()
	local now = clock()
	local settings = Config.longjump
	if now - Move.lastLongJump < (settings.cooldown or 1) then
		return
	end
	local character = LP.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	Move.lastLongJump = now
	local direction
	if settings.cameraDir then
		local camera = workspace.CurrentCamera
		direction = camera and camera.CFrame.LookVector or root.CFrame.LookVector
		direction = Vector3.new(direction.X, 0, direction.Z)
	else
		direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	if direction.Magnitude < 0.05 then
		return
	end
	root.AssemblyLinearVelocity = direction.Unit * (settings.power or 90) + Vector3.new(0, 34, 0)
end

local function doTeleport()
	local settings = Config.teleport
	local character = LP.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local target
	if settings.mode == "Mouse" then
		local mouse = LP:GetMouse()
		if mouse and mouse.Hit then
			target = mouse.Hit.Position + mouse.UnitRay.Direction * (settings.distance or 40)
		end
	elseif settings.mode == "Player" then
		local enemy = nearestEnemy(2000)
		local enemyCharacter = enemy and enemy.Character
		local enemyRoot = enemyCharacter and enemyCharacter:FindFirstChild("HumanoidRootPart")
		if enemyRoot then
			target = enemyRoot.Position + Vector3.new(0, 3, 0)
		end
	else
		local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
		target = spawn and spawn.Position + Vector3.new(0, 6, 0) or Vector3.new(0, 60, 0)
	end
	if target then
		pcall(function()
			root.CFrame = CFrame.new(target)
		end)
		if Config.teleport.mode ~= "Spawn" then
			notify("teleported", Theme.accent)
		end
	end
end

local jumpConnection
local function updateMovement(delta)
	local humanoid, character = currentHumanoid()
	if humanoid ~= Move.humanoid then
		stopFly()
		Move.humanoid = humanoid
		if humanoid then
			Move.baseSpeed = humanoid.WalkSpeed
			Move.baseJump = humanoid.JumpPower
		end
		Move.clipped = {}
	end
	if not humanoid or not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")

	-- WalkSpeed
	local speed = Config.walkspeed
	local speedWanted = speed.enabled and (speed.key == "None" or keyDown(speed.key))
	if speedWanted then
		local target = speed.value or 26
		if speed.ramp then
			humanoid.WalkSpeed = lerp(humanoid.WalkSpeed, target, clamp(delta * 8, 0, 1))
		else
			humanoid.WalkSpeed = target
		end
	elseif humanoid.WalkSpeed ~= (Move.baseSpeed or 16) and not Config.sprint.enabled then
		humanoid.WalkSpeed = Move.baseSpeed or 16
	end

	-- Sprint
	local sprint = Config.sprint
	if sprint.enabled and not speedWanted then
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		humanoid.WalkSpeed = (Move.baseSpeed or 16) * (moving and (sprint.multiplier or 1.35) or 1)
		local camera = workspace.CurrentCamera
		if camera then
			if sprint.punch and moving then
				if not Move.baseFov then
					Move.baseFov = camera.FieldOfView
				end
				camera.FieldOfView = lerp(camera.FieldOfView, (Move.baseFov or 70) + (sprint.amount or 6), clamp(delta * 6, 0, 1))
			elseif Move.baseFov then
				camera.FieldOfView = lerp(camera.FieldOfView, Move.baseFov, clamp(delta * 6, 0, 1))
			end
		end
	elseif Move.baseFov then
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = Move.baseFov
		end
		Move.baseFov = nil
	end

	-- Jump power (only written while we own the value)
	local jump = Config.jumppower
	if jump.enabled and (jump.key == "None" or keyDown(jump.key)) then
		pcall(function()
			humanoid.UseJumpPower = true
		end)
		humanoid.JumpPower = jump.value or 60
		Move.jumpApplied = true
	elseif Move.jumpApplied then
		humanoid.JumpPower = Move.baseJump or 50
		Move.jumpApplied = false
	end

	-- Auto jump
	if Config.autojump.enabled and humanoid.FloorMaterial ~= Enum.Material.Air then
		humanoid.Jump = true
	end

	-- Infinite jump
	local infinite = Config.infinitejump
	if infinite.enabled and not jumpConnection then
		jumpConnection = UserInputService.JumpRequest:Connect(function()
			if not Config.infinitejump.enabled then
				return
			end
			local hum = currentHumanoid()
			if hum then
				pcall(function()
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end)
			end
		end)
	elseif not infinite.enabled and jumpConnection then
		jumpConnection:Disconnect()
		jumpConnection = nil
	end

	-- Fly
	local fly = Config.fly
	if fly.enabled and root then
		if not Move.flyBody then
			local body = Instance.new("BodyVelocity")
			body.Name = "RClientFly"
			body.MaxForce = Vector3.new(1000000, 1000000, 1000000)
			body.P = 1250
			body.Parent = root
			Move.flyBody = body
			Move.flying = true
			pcall(function()
				humanoid.PlatformStand = true
			end)
		end
		local camera = workspace.CurrentCamera
		local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)
		local direction = look
		if fly.mode == "Horizontal" then
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				direction = flat.Unit
			end
		end
		local velocity = direction * (fly.speed or 60)
		if fly.vertical then
			if keyDown("Space") then
				velocity = velocity + Vector3.new(0, fly.speed or 60, 0)
			elseif keyDown("LeftControl") then
				velocity = velocity - Vector3.new(0, fly.speed or 60, 0)
			end
		end
		if Move.flyBody then
			Move.flyBody.Velocity = velocity
		end
	elseif Move.flyBody then
		stopFly()
	end

	-- Noclip
	if Config.noclip.enabled then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				Move.clipped[part] = true
				part.CanCollide = false
			end
		end
	elseif next(Move.clipped) then
		restoreNoclip()
	end

	-- Character scale
	local scale = Config.scale
	if scale.enabled then
		local values = {
			BodyWidthScale = scale.width or 1,
			BodyHeightScale = scale.height or 1,
			BodyDepthScale = scale.depth or 1,
			HeadScale = 1,
		}
		for name, value in pairs(values) do
			local item = humanoid:FindFirstChild(name)
			if item then
				if Move.scales[item] == nil then
					Move.scales[item] = item.Value
				end
				pcall(function()
					item.Value = value
				end)
			end
		end
	elseif next(Move.scales) then
		for item, value in pairs(Move.scales) do
			if item and item.Parent then
				pcall(function()
					item.Value = value
				end)
			end
		end
		Move.scales = {}
	end

	-- Anti fling
	local fling = Config.antifling
	if fling.enabled and root then
		local velocity = root.AssemblyLinearVelocity
		if velocity.Magnitude > (fling.trigger or 200) then
			pcall(function()
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				if fling.angular then
					root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				end
			end)
		end
	end

	-- Anti stun / anti ragdoll
	if Config.antistun.enabled or Config.antiragdoll.enabled then
		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
		if Config.antiragdoll.restoreSpeed then
			local wanted = (Move.baseSpeed or 16) * (Config.sprint.enabled and (Config.sprint.multiplier or 1.35) or 1)
			if humanoid.WalkSpeed < 1 then
				humanoid.WalkSpeed = wanted
			end
		end
	end

	-- Anti void
	local antvoid = Config.antvoid
	if antvoid.enabled and root and root.Position.Y < (antvoid.floor or -40) then
		root.CFrame = CFrame.new(root.Position.X, 40, root.Position.Z)
		if antvoid.notify then
			notify("anti void saved you", Theme.warn)
		end
	end
end

--------------------------------------------------------------------------
-- Anti-aim (client-side body spoof)
--------------------------------------------------------------------------

local function updateAntiAim()
	local settings = Config.antiaim
	local character = LP.Character
	if not settings.enabled or not character then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return
	end
	local now = clock()
	local offset = 0
	if settings.mode == "Spin" then
		offset = (now * (settings.speed or 12) * 30) % 360
	elseif settings.mode == "Jitter" then
		offset = math.sin(now * (settings.speed or 12)) * (settings.yaw or 25)
	elseif settings.mode == "Ghost" then
		offset = math.sin(now * 0.6) * (settings.yaw or 25) * 0.5
	else
		offset = settings.yaw or 25
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local base = root and root.CFrame.Rotation or torso.CFrame.Rotation
	pcall(function()
		torso.CFrame = CFrame.new(torso.Position) * base * CFrame.Angles(0, math.rad(offset), 0)
	end)
end

--------------------------------------------------------------------------
-- Skin changer (client-side only)
--------------------------------------------------------------------------

local SKINS = {
	Frostbite = { Color3.fromRGB(182, 232, 255), Color3.fromRGB(92, 158, 255) },
	Nebula = { Color3.fromRGB(150, 96, 255), Color3.fromRGB(48, 24, 120) },
	Ember = { Color3.fromRGB(255, 140, 60), Color3.fromRGB(140, 34, 20) },
	Toxic = { Color3.fromRGB(150, 255, 90), Color3.fromRGB(30, 90, 30) },
	Voidheart = { Color3.fromRGB(70, 40, 110), Color3.fromRGB(12, 8, 24) },
	Chrome = { Color3.fromRGB(235, 238, 245), Color3.fromRGB(140, 146, 160) },
	Sakura = { Color3.fromRGB(255, 176, 214), Color3.fromRGB(150, 60, 110) },
	Bloodmoon = { Color3.fromRGB(200, 26, 46), Color3.fromRGB(40, 0, 8) },
	Cyber = { Color3.fromRGB(60, 240, 240), Color3.fromRGB(20, 60, 120) },
	["Gold Rush"] = { Color3.fromRGB(255, 208, 96), Color3.fromRGB(150, 96, 18) },
	Glacier = { Color3.fromRGB(210, 245, 255), Color3.fromRGB(120, 190, 220) },
	["Purple Haze"] = { Color3.fromRGB(196, 156, 255), Color3.fromRGB(70, 32, 140) },
	Molten = { Color3.fromRGB(255, 96, 20), Color3.fromRGB(90, 12, 0) },
	Phantom = { Color3.fromRGB(220, 220, 235), Color3.fromRGB(60, 60, 90) },
	Candy = { Color3.fromRGB(255, 140, 190), Color3.fromRGB(120, 220, 255) },
	Matrix = { Color3.fromRGB(90, 255, 130), Color3.fromRGB(0, 40, 10) },
	Inferno = { Color3.fromRGB(255, 70, 40), Color3.fromRGB(255, 180, 40) },
	Arctic = { Color3.fromRGB(240, 252, 255), Color3.fromRGB(150, 200, 230) },
}

local SkinCatalog = {
	"Frostbite", "Nebula", "Ember", "Toxic", "Voidheart", "Chrome",
	"Sakura", "Bloodmoon", "Cyber", "Gold Rush", "Glacier", "Purple Haze",
	"Molten", "Phantom", "Candy", "Matrix", "Inferno", "Arctic",
}

local Skin = {
	originals = setmetatable({}, { __mode = "k" }),
	lastPaint = 0,
	cycle = 1,
}

local function skinColors(name)
	local entry = SKINS[name] or SKINS.Frostbite
	return entry[1], entry[2]
end

local function paint(container, first, second, material)
	local index = 0
	for _, part in ipairs(container:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("SurfaceAppearance") then
			index = index + 1
			if not Skin.originals[part] then
				Skin.originals[part] = {
					color = part.Color,
					material = part:IsA("BasePart") and part.Material or nil,
				}
			end
			pcall(function()
				part.Color = (index % 2 == 0) and second or first
				if part:IsA("BasePart") and material then
					part.Material = material
				end
			end)
		end
	end
end

local function restoreSkins()
	for part, original in pairs(Skin.originals) do
		if part and part.Parent then
			pcall(function()
				part.Color = original.color
				if original.material then
					part.Material = original.material
				end
			end)
		end
	end
	Skin.originals = setmetatable({}, { __mode = "k" })
end

local function skinMaterial(name)
	local ok, material = pcall(function()
		return Enum.Material[name]
	end)
	if ok and material then
		return material
	end
	return Enum.Material.Neon
end

local function skinName()
	if Config.skinpreview.enabled and not Config.skinchanger.enabled then
		return SkinCatalog[Skin.cycle] or "Frostbite"
	end
	return Config.skinchanger.skin or "Frostbite"
end

local function applySkins(delta)
	local changer = Config.skinchanger
	local preview = Config.skinpreview
	if not changer.enabled and not preview.enabled then
		if next(Skin.originals) then
			restoreSkins()
		end
		return
	end

	if preview.enabled and preview.autoCycle and not changer.enabled then
		Skin.lastPaint = Skin.lastPaint + delta
		if Skin.lastPaint >= (preview.speed or 1.2) then
			Skin.lastPaint = 0
			Skin.cycle = Skin.cycle % #SkinCatalog + 1
		end
	end

	local name = skinName()
	local first, second = skinColors(name)
	if changer.enabled and changer.rainbow then
		local hue = (clock() * (changer.rainbowSpeed or 0.25)) % 1
		first = Color3.fromHSV(hue, 0.75, 1)
		second = Color3.fromHSV((hue + 0.12) % 1, 0.75, 0.75)
	end
	local material = skinMaterial(changer.material or "Neon")

	local character = LP.Character
	if character then
		if changer.enabled and changer.tools then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Tool") then
					paint(child, first, second, material)
				end
			end
		end
		if changer.enabled and changer.character then
			for _, part in ipairs(character:GetChildren()) do
				if part:IsA("BasePart") then
					if not Skin.originals[part] then
						Skin.originals[part] = { color = part.Color, material = part.Material }
					end
					pcall(function()
						part.Color = first
					end)
				end
			end
		end
		local backpack = LP:FindFirstChild("Backpack")
		if changer.enabled and changer.tools and backpack then
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then
					paint(tool, first, second, material)
				end
			end
		end
	end

	if changer.enabled and changer.viewmodel or preview.enabled and preview.applyViewmodel then
		for _, object in ipairs(workspace:GetChildren()) do
			local lower = string.lower(object.Name)
			if object:IsA("Model") or object:IsA("Folder") then
				if lower:find("viewmodel") or lower:find("view model") or lower:find("arms") or lower:find("weapon") then
					paint(object, first, second, material)
				end
			end
		end
	end
end

--------------------------------------------------------------------------
-- Utility modules
--------------------------------------------------------------------------

local Utility = {
	lastAfk = 0,
	lastStun = 0,
	lastHop = 0,
	fpsCap = nil,
	statsText = nil,
}

local function updateUtility(delta)
	local now = clock()

	if Config.antiafk.enabled and now - Utility.lastAfk >= (Config.antiafk.interval or 120) then
		Utility.lastAfk = now
		pcall(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end

	local fps = Config.fpsunlock
	if fps.enabled then
		if type(setfpscap) == "function" then
			pcall(setfpscap, fps.cap or 240)
		end
	elseif Utility.fpsCap then
		if type(setfpscap) == "function" then
			pcall(setfpscap, Utility.fpsCap)
		end
		Utility.fpsCap = nil
	end

	local hop = Config.serverhop
	if hop.onDeath and now - Utility.lastHop >= (hop.delay or 4) then
		local humanoid = currentHumanoid()
		if humanoid and humanoid.Health <= 0 then
			Utility.lastHop = now
			pcall(function()
				game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
			end)
		end
	end
end

local function doServerHop()
	local ok = pcall(function()
		local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100", game.PlaceId)
		local body = game:HttpGet(url)
		local data = HttpService:JSONDecode(body)
		for _, server in ipairs(data.data or {}) do
			if server.playing < server.maxPlayers and server.id ~= game.JobId then
				game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, server.id, LP)
				return
			end
		end
		game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
	end)
	if ok then
		notify("hopping servers", Theme.accent)
	end
end

local function doPanic()
	releaseAim()
	Silent.point = nil
	stopFly()
	restoreNoclip()
	restoreHitboxes()
	restoreSkins()
	Skin.originals = setmetatable({}, { __mode = "k" })
	if Config.panic.disableAll then
		for _, module in ipairs(Order) do
			Config[module.id].enabled = false
		end
	end
	if Config.panic.hideUi and UI and UI.panel then
		UI.setOpen(false)
	end
	if Config.panic.notify then
		notify("panic - everything off", Theme.bad)
	end
end

--------------------------------------------------------------------------
-- Keybinds
--------------------------------------------------------------------------

local function bindMatches(id, key, pressed)
	local value = get(id, key)
	return value and value ~= "None" and value == pressed
end

UserInputService.InputBegan:Connect(function(item, processed)
	if processed then
		return
	end
	if CAPTURE then
		return
	end
	if item.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local pressed = item.KeyCode.Name

	if pressed == "Insert" then
		if UI then
			UI.setOpen(not UI.open)
		end
		return
	end
	if pressed == "RightShift" or bindMatches("panic", "key", pressed) then
		doPanic()
		return
	end
	if bindMatches("fly", "key", pressed) then
		toggle("fly")
		notify("fly " .. (on("fly") and "on" or "off"), on("fly") and Theme.good or Theme.dim)
	elseif bindMatches("noclip", "key", pressed) then
		toggle("noclip")
		notify("noclip " .. (on("noclip") and "on" or "off"), on("noclip") and Theme.good or Theme.dim)
	elseif bindMatches("teleport", "key", pressed) then
		doTeleport()
	elseif bindMatches("longjump", "key", pressed) then
		doLongJump()
	elseif bindMatches("serverhop", "key", pressed) then
		doServerHop()
	end
end)
--------------------------------------------------------------------------
-- Panel
--
-- Built from real TextButtons so touch and mouse both fire Activated.
-- Every visible control is wired: badge, rail, search, rows, switches,
-- sliders, cyclers, keybinds, master enable, reset, save, panic, close.
--------------------------------------------------------------------------

UI = {
	open = false,
	panel = nil,
	badge = nil,
	list = nil,
	detail = nil,
	rows = {},
	widgets = {},
	railButtons = {},
	category = "Aim",
	selected = "aimbot",
	query = "",
}

local function click(object, fn)
	object.Activated:Connect(function()
		local ok, err = pcall(fn)
		if not ok then
			warn("[R Client] click: " .. tostring(err))
		end
	end)
end

local function hover(object, normal, hovered)
	object.MouseEnter:Connect(function()
		tween(object, { BackgroundTransparency = hovered }, 0.1)
	end)
	object.MouseLeave:Connect(function()
		tween(object, { BackgroundTransparency = normal }, 0.1)
	end)
end

local function chip(parent, text, width, order)
	local item = create("TextLabel", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(px(width or 54), px(17)),
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = Theme.accentSoft,
		TextSize = px(8),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = order or 0,
	}, parent)
	round(item, px(8))
	return item
end

--------------------------------------------------------------------------
-- Drag plumbing (sliders and the badge)
--------------------------------------------------------------------------

local drag = { active = false, handler = nil }

UserInputService.InputChanged:Connect(function(item)
	if not drag.active or not drag.handler then
		return
	end
	local kind = item.UserInputType
	if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
		drag.handler(item.Position.X)
	end
end)

UserInputService.InputEnded:Connect(function(item)
	local kind = item.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		drag.active = false
		drag.handler = nil
	end
end)

--------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------

local function makeSwitch(parent, initial, position, changed)
	local button = create("TextButton", {
		BackgroundColor3 = initial and Theme.accent or Theme.stroke,
		BackgroundTransparency = initial and 0.05 or 0.25,
		Size = UDim2.fromOffset(px(30), px(16)),
		Position = position,
		AutoButtonColor = false,
		Text = "",
		Active = true,
	}, parent)
	round(button, px(8))
	local knob = create("Frame", {
		BackgroundColor3 = initial and Theme.text or Theme.dim,
		Size = UDim2.fromOffset(px(12), px(12)),
		Position = UDim2.fromOffset(initial and px(16) or px(2), px(2)),
	}, button)
	round(knob, px(6))

	local state = initial

	local function set(value, silent)
		state = value
		tween(button, {
			BackgroundColor3 = value and Theme.accent or Theme.stroke,
			BackgroundTransparency = value and 0.05 or 0.25,
		}, 0.1)
		tween(knob, {
			Position = UDim2.fromOffset(value and px(16) or px(2), px(2)),
			BackgroundColor3 = value and Theme.text or Theme.dim,
		}, 0.1)
		if not silent and changed then
			changed(value)
		end
	end

	click(button, function()
		set(not state, true)
		if changed then
			changed(state)
		end
	end)
	return set, button
end

--------------------------------------------------------------------------
-- Module rows
--------------------------------------------------------------------------

local function makeRow(parent, module)
	local row = create("TextButton", {
		BackgroundColor3 = Theme.row,
		BackgroundTransparency = on(module.id) and 0.45 or 0.75,
		Size = UDim2.new(1, 0, 0, px(32)),
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = true,
		Active = true,
	}, parent)
	round(row, px(7))

	local bar = create("Frame", {
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = on(module.id) and 0 or 1,
		Size = UDim2.fromOffset(px(2), px(18)),
		Position = UDim2.fromOffset(px(4), px(7)),
	}, row)
	round(bar, px(1))

	local dot = create("Frame", {
		BackgroundColor3 = on(module.id) and Theme.accent or Theme.muted,
		Size = UDim2.fromOffset(px(4), px(4)),
		Position = UDim2.fromOffset(px(12), px(14)),
	}, row)
	round(dot, px(2))

	local name = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(21), 0),
		Size = UDim2.new(1, -px(88), 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = module.name,
		TextColor3 = on(module.id) and Theme.text or Theme.dim,
		TextSize = px(11),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local switch, switchButton = makeSwitch(row, on(module.id), UDim2.new(1, -px(54), 0.5, -px(8)), function(value)
		set(module.id, "enabled", value)
	end)

	local settings = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -px(18), 0, px(6)),
		Size = UDim2.fromOffset(px(16), px(20)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "›",
		TextColor3 = Theme.muted,
		TextSize = px(14),
		Active = true,
	}, row)
	click(settings, function()
		UI.select(module.id)
		notify(module.name .. " settings", Theme.accentSoft)
	end)
	settings.MouseEnter:Connect(function()
		settings.TextColor3 = Theme.accent2 or Theme.accentSoft
	end)
	settings.MouseLeave:Connect(function()
		settings.TextColor3 = Theme.muted
	end)

	click(row, function()
		toggle(module.id)
	end)
	hover(row, on(module.id) and 0.45 or 0.75, 0.35)

	local record = {
		frame = row,
		module = module,
		switch = switch,
		bar = bar,
		dot = dot,
		label = name,
	}

	function record.refresh()
		local state = on(module.id)
		row.BackgroundTransparency = state and 0.45 or 0.75
		bar.BackgroundTransparency = state and 0 or 1
		dot.BackgroundColor3 = state and Theme.accent or Theme.muted
		name.TextColor3 = state and Theme.text or Theme.dim
		switch(state, true)
	end

	return record
end

--------------------------------------------------------------------------
-- Detail widgets
--------------------------------------------------------------------------

local function clearDetail()
	for _, child in ipairs(UI.detail:GetChildren()) do
		local kind = child.ClassName
		if kind ~= "UICorner" and kind ~= "UIStroke" and kind ~= "UIPadding" and kind ~= "UIGradient" then
			child:Destroy()
		end
	end
	UI.widgets = {}
end

local function makeSlider(parent, module, setting, order)
	local wrap = create("Frame", {
		BackgroundColor3 = Theme.row,
		BackgroundTransparency = 0.72,
		Size = UDim2.new(1, 0, 0, px(40)),
		LayoutOrder = order,
	}, parent)
	round(wrap, px(6))

	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(8), px(3)),
		Size = UDim2.new(1, -px(70), 0, px(16)),
		Font = Enum.Font.Gotham,
		Text = setting.name,
		TextColor3 = Theme.dim,
		TextSize = px(10),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, wrap)

	local value = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -px(62), px(3)),
		Size = UDim2.fromOffset(px(54), px(16)),
		Font = Enum.Font.GothamBold,
		Text = "",
		TextColor3 = Theme.accentSoft,
		TextSize = px(10),
		TextXAlignment = Enum.TextXAlignment.Right,
	}, wrap)

	local minus = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.1,
		Position = UDim2.fromOffset(px(8), px(22)),
		Size = UDim2.fromOffset(px(16), px(14)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "-",
		TextColor3 = Theme.dim,
		TextSize = px(11),
		Active = true,
	}, wrap)
	round(minus, px(4))

	local plus = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.1,
		Position = UDim2.new(1, -px(24), px(22)),
		Size = UDim2.fromOffset(px(16), px(14)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "+",
		TextColor3 = Theme.accentSoft,
		TextSize = px(11),
		Active = true,
	}, wrap)
	round(plus, px(4))

	local track = create("TextButton", {
		BackgroundColor3 = Theme.stroke,
		BackgroundTransparency = 0.1,
		Position = UDim2.fromOffset(px(28), px(27)),
		Size = UDim2.new(1, -px(58), 0, px(5)),
		AutoButtonColor = false,
		Text = "",
		Active = true,
	}, wrap)
	round(track, px(3))

	local fill = create("Frame", {
		BackgroundColor3 = Theme.accent,
		Size = UDim2.new(0, 0, 1, 0),
	}, track)
	round(fill, px(3))

	local knob = create("Frame", {
		BackgroundColor3 = Theme.text,
		Size = UDim2.fromOffset(px(9), px(9)),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
	}, track)
	round(knob, px(5))

	local function decimals()
		if setting.step and setting.step < 1 then
			return 2
		end
		return 0
	end

	local function render(valueNow)
		local span = math.max(setting.max - setting.min, 0.001)
		local ratio = clamp((valueNow - setting.min) / span, 0, 1)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		knob.Position = UDim2.new(ratio, 0, 0.5, 0)
		if decimals() > 0 then
			value.Text = string.format("%." .. decimals() .. "f", valueNow)
		else
			value.Text = tostring(math.floor(valueNow + 0.5))
		end
	end

	local function commit(raw)
		local step = setting.step or 1
		raw = math.floor(raw / step + 0.5) * step
		raw = clamp(raw, setting.min, setting.max)
		set(module.id, setting.key, raw)
		render(raw)
	end

	local function applyX(x)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local ratio = clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		commit(setting.min + (setting.max - setting.min) * ratio)
	end

	track.InputBegan:Connect(function(item)
		local kind = item.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			drag.active = true
			drag.handler = applyX
			applyX(item.Position.X)
		end
	end)

	click(minus, function()
		commit((get(module.id, setting.key) or setting.min) - (setting.step or 1))
	end)
	click(plus, function()
		commit((get(module.id, setting.key) or setting.min) + (setting.step or 1))
	end)

	render(get(module.id, setting.key) or setting.min)
	UI.widgets[#UI.widgets + 1] = function()
		render(get(module.id, setting.key) or setting.min)
	end
end

local function makeCycle(parent, module, setting, order)
	local wrap = create("Frame", {
		BackgroundColor3 = Theme.row,
		BackgroundTransparency = 0.72,
		Size = UDim2.new(1, 0, 0, px(30)),
		LayoutOrder = order,
	}, parent)
	round(wrap, px(6))

	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(8), 0),
		Size = UDim2.new(1, -px(96), 1, 0),
		Font = Enum.Font.Gotham,
		Text = setting.name,
		TextColor3 = Theme.dim,
		TextSize = px(10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, wrap)

	local pill = create("TextLabel", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.1,
		Position = UDim2.new(1, -px(78), 0.5, -px(9)),
		Size = UDim2.fromOffset(px(56), px(18)),
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = Theme.accentSoft,
		TextSize = px(9),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, wrap)
	round(pill, px(9))

	local function step(direction)
		local values = setting.values
		local current = get(module.id, setting.key)
		local index = 1
		for i, value in ipairs(values) do
			if value == current then
				index = i
				break
			end
		end
		index = (index - 1 + direction) % #values + 1
		set(module.id, setting.key, values[index])
		pill.Text = values[index]
	end

	local back = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.1,
		Position = UDim2.new(1, -px(96), 0.5, -px(9)),
		Size = UDim2.fromOffset(px(16), px(18)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "‹",
		TextColor3 = Theme.dim,
		TextSize = px(11),
		Active = true,
	}, wrap)
	round(back, px(6))

	local forward = create("TextButton", {
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = 0.78,
		Position = UDim2.new(1, -px(20), 0.5, -px(9)),
		Size = UDim2.fromOffset(px(16), px(18)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "›",
		TextColor3 = Theme.accentSoft,
		TextSize = px(11),
		Active = true,
	}, wrap)
	round(forward, px(6))

	click(back, function()
		step(-1)
	end)
	click(forward, function()
		step(1)
	end)

	local function refresh()
		pill.Text = tostring(get(module.id, setting.key))
	end
	refresh()
	UI.widgets[#UI.widgets + 1] = refresh
end

local function makeToggle(parent, module, setting, order)
	local row = create("TextButton", {
		BackgroundColor3 = Theme.row,
		BackgroundTransparency = 0.72,
		Size = UDim2.new(1, 0, 0, px(28)),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Active = true,
	}, parent)
	round(row, px(6))

	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(8), 0),
		Size = UDim2.new(1, -px(52), 1, 0),
		Font = Enum.Font.Gotham,
		Text = setting.name,
		TextColor3 = Theme.dim,
		TextSize = px(10),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local setSwitch = makeSwitch(row, get(module.id, setting.key) == true, UDim2.new(1, -px(36), 0.5, -px(8)), function(value)
		set(module.id, setting.key, value)
	end)

	click(row, function()
		set(module.id, setting.key, not get(module.id, setting.key))
		setSwitch(get(module.id, setting.key) == true, true)
	end)
	hover(row, 0.72, 0.6)

	UI.widgets[#UI.widgets + 1] = function()
		setSwitch(get(module.id, setting.key) == true, true)
	end
end

local function makeKey(parent, module, setting, order)
	local row = create("TextButton", {
		BackgroundColor3 = Theme.row,
		BackgroundTransparency = 0.72,
		Size = UDim2.new(1, 0, 0, px(28)),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Active = true,
	}, parent)
	round(row, px(6))

	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(8), 0),
		Size = UDim2.new(1, -px(92), 1, 0),
		Font = Enum.Font.Gotham,
		Text = setting.name,
		TextColor3 = Theme.dim,
		TextSize = px(10),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local pill = create("TextLabel", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.1,
		Position = UDim2.new(1, -px(84), 0.5, -px(9)),
		Size = UDim2.fromOffset(px(62), px(18)),
		Font = Enum.Font.GothamMedium,
		Text = tostring(get(module.id, setting.key)),
		TextColor3 = Theme.accentSoft,
		TextSize = px(9),
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)
	round(pill, px(9))

	local clear = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -px(18), 0.5, -px(9)),
		Size = UDim2.fromOffset(px(16), px(18)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "×",
		TextColor3 = Theme.muted,
		TextSize = px(10),
		Active = true,
	}, row)
	click(clear, function()
		set(module.id, setting.key, "None")
		pill.Text = "None"
	end)

	click(row, function()
		CAPTURE = true
		pill.Text = "press"
		pill.TextColor3 = Theme.warn
		local connection
		local function finish()
			CAPTURE = false
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end
		connection = UserInputService.InputBegan:Connect(function(item)
			if item.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			local key = item.KeyCode.Name
			set(module.id, setting.key, key == "Escape" and "None" or key)
			pill.Text = tostring(get(module.id, setting.key))
			pill.TextColor3 = Theme.accentSoft
			finish()
		end)
		task.delay(5, function()
			if CAPTURE then
				finish()
				pill.Text = tostring(get(module.id, setting.key))
				pill.TextColor3 = Theme.accentSoft
			end
		end)
	end)

	UI.widgets[#UI.widgets + 1] = function()
		if not CAPTURE then
			pill.Text = tostring(get(module.id, setting.key))
			pill.TextColor3 = Theme.accentSoft
		end
	end
end

--------------------------------------------------------------------------
-- Detail pane
--------------------------------------------------------------------------

local function buildDetail()
	clearDetail()
	local module = Registry[UI.selected]
	if not module then
		return
	end
	local settingsCount = #module.settings

	local head = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, px(40)),
	}, UI.detail)

	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -px(58), 0, px(20)),
		Font = Enum.Font.GothamBold,
		Text = module.name,
		TextColor3 = Theme.text,
		TextSize = px(14),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, head)

	local meta = chip(head, string.upper(module.cat), 52)
	meta.Position = UDim2.fromOffset(0, px(22))

	local count = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(58), px(22)),
		Size = UDim2.fromOffset(px(80), px(17)),
		Font = Enum.Font.Gotham,
		Text = settingsCount .. " settings",
		TextColor3 = Theme.muted,
		TextSize = px(9),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, head)

	local master = create("TextButton", {
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = on(module.id) and 0.1 or 0.82,
		Position = UDim2.new(1, -px(52), 0, px(2)),
		Size = UDim2.fromOffset(px(52), px(20)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = on(module.id) and "ON" or "OFF",
		TextColor3 = on(module.id) and Theme.text or Theme.dim,
		TextSize = px(9),
		Active = true,
	}, head)
	round(master, px(6))

	local function refreshMaster()
		local state = on(module.id)
		master.BackgroundTransparency = state and 0.1 or 0.82
		master.Text = state and "ON" or "OFF"
		master.TextColor3 = state and Theme.text or Theme.dim
	end

	click(master, function()
		toggle(module.id)
		refreshMaster()
		if UI.rows[module.id] then
			UI.rows[module.id].refresh()
		end
	end)

	local desc = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, px(42)),
		Size = UDim2.new(1, 0, 0, px(24)),
		Font = Enum.Font.Gotham,
		Text = module.desc,
		TextColor3 = Theme.muted,
		TextSize = px(9),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, UI.detail)

	local footer = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, px(22)),
		Position = UDim2.new(0, 0, 1, -px(22)),
	}, UI.detail)

	local reset = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(px(58), px(20)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "RESET",
		TextColor3 = Theme.dim,
		TextSize = px(8),
		Active = true,
	}, footer)
	round(reset, px(5))
	click(reset, function()
		for _, setting in ipairs(module.settings) do
			Config[module.id][setting.key] = setting.def
		end
		buildDetail()
		notify(module.name .. " reset", Theme.accentSoft)
	end)

	local panic = create("TextButton", {
		BackgroundColor3 = Theme.bad,
		BackgroundTransparency = 0.82,
		Position = UDim2.new(1, -px(58), 0, 0),
		Size = UDim2.fromOffset(px(58), px(20)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "PANIC",
		TextColor3 = Theme.bad,
		TextSize = px(8),
		Active = true,
	}, footer)
	round(panic, px(5))
	click(panic, function()
		doPanic()
	end)

	local scroll = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, px(76)),
		Size = UDim2.new(1, 0, 1, -px(100)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = px(2),
		ScrollBarImageColor3 = Theme.accent,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, UI.detail)
	create("UIListLayout", {
		Padding = UDim.new(0, px(4)),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroll)

	local order = 0
	for _, setting in ipairs(module.settings) do
		order = order + 1
		if setting.type == "slider" then
			makeSlider(scroll, module, setting, order)
		elseif setting.type == "cycle" then
			makeCycle(scroll, module, setting, order)
		elseif setting.type == "toggle" then
			makeToggle(scroll, module, setting, order)
		elseif setting.type == "key" then
			makeKey(scroll, module, setting, order)
		end
	end

	UI.widgets[#UI.widgets + 1] = refreshMaster
end

function UI.select(id)
	UI.selected = id
	local module = Registry[id]
	if module then
		buildDetail()
		if module.cat ~= UI.category and UI.query == "" then
			UI.category = module.cat
			UI.filter()
		end
	end
end

function UI.filter()
	local query = string.lower(UI.query or "")
	local showAll = query ~= ""
	local shown = 0
	for _, row in pairs(UI.rows) do
		local module = row.module
		local matchesCategory = showAll or module.cat == UI.category
		local matchesQuery = query == "" or string.find(string.lower(module.name), query, 1, true) or string.find(string.lower(module.cat), query, 1, true)
		local visible = matchesCategory and matchesQuery
		row.frame.Visible = visible
		if visible then
			shown = shown + 1
		end
	end
	for _, button in ipairs(UI.railButtons) do
		local active = not showAll and button.cat == UI.category
		button.frame.BackgroundTransparency = active and 0.08 or 1
		button.label.TextColor3 = active and Theme.text or Theme.muted
		button.mark.BackgroundTransparency = active and 0 or 1
	end
	if UI.empty then
		UI.empty.Visible = shown == 0
	end
	if UI.listHead then
		UI.listHead.Text = string.upper(showAll and "search" or UI.category) .. "  ·  " .. shown
	end
end

function UI.setOpen(value)
	UI.open = value
	if not UI.panel then
		return
	end
	if value then
		UI.panel.Visible = true
		UI.panel.Position = UDim2.new(0.5, 0, 0.56, 0)
		tween(UI.panel, { Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.16)
		UI.filter()
		if UI.badgeDot then
			UI.badgeDot.BackgroundColor3 = Theme.good
		end
	else
		tween(UI.panel, { Position = UDim2.new(0.5, 0, 0.6, 0) }, 0.12)
		task.delay(0.13, function()
			if not UI.open and UI.panel then
				UI.panel.Visible = false
			end
		end)
		if UI.badgeDot then
			UI.badgeDot.BackgroundColor3 = Theme.accent
		end
	end
end

--------------------------------------------------------------------------
-- Badge
--------------------------------------------------------------------------

local function buildBadge()
	local badge = create("TextButton", {
		Name = "RBadge",
		BackgroundColor3 = Theme.card,
		Size = UDim2.fromOffset(px(54), px(54)),
		Position = UDim2.new(0, px(14), 1, -px(68)),
		AutoButtonColor = false,
		Text = "",
		ClipsDescendants = false,
		Active = true,
	}, GUI)
	round(badge, px(15))
	edge(badge, Theme.accent, 1, 0.25)
	local fill = create("Frame", {
		BackgroundColor3 = Theme.panel,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.02,
	}, badge)
	round(fill, px(14))
	gradient(fill, Color3.fromRGB(56, 48, 78), Color3.fromRGB(14, 12, 20))
	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		Text = "R",
		TextColor3 = Theme.text,
		TextSize = px(27),
	}, badge)
	local dot = create("Frame", {
		BackgroundColor3 = Theme.accent,
		Size = UDim2.fromOffset(px(8), px(8)),
		Position = UDim2.new(1, -px(10), 0, px(6)),
	}, badge)
	round(dot, px(4))
	edge(dot, Theme.black, 1, 0.4)
	UI.badgeDot = dot

	local press, origin, moved = nil, nil, false

	badge.InputBegan:Connect(function(item)
		local kind = item.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			press = item.Position
			origin = badge.Position
			moved = false
		end
	end)

	UserInputService.InputChanged:Connect(function(item)
		if not press then
			return
		end
		local kind = item.UserInputType
		if kind ~= Enum.UserInputType.MouseMovement and kind ~= Enum.UserInputType.Touch then
			return
		end
		local delta = item.Position - press
		if delta.Magnitude > px(7) then
			moved = true
		end
		if moved then
			badge.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(item)
		local kind = item.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if press then
			press = nil
		end
	end)

	-- One toggle path only: Activated fires on touch and mouse alike.
	click(badge, function()
		if moved then
			moved = false
			return
		end
		UI.setOpen(not UI.open)
	end)

	UI.badge = badge
end

--------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------

local function railButton(parent, label, category, order)
	local button = create("TextButton", {
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(px(38), px(30)),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Active = true,
	}, parent)
	round(button, px(8))

	local mark = create("Frame", {
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(px(2), px(16)),
		Position = UDim2.fromOffset(px(-2), px(7)),
	}, button)
	round(mark, px(1))

	local text = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		Text = label,
		TextColor3 = Theme.muted,
		TextSize = px(9),
	}, button)

	click(button, function()
		UI.category = category
		UI.query = ""
		if UI.searchBox then
			UI.searchBox.Text = ""
		end
		UI.filter()
	end)
	button.MouseEnter:Connect(function()
		if UI.category ~= category or UI.query ~= "" then
			button.BackgroundTransparency = 0.82
		end
	end)
	button.MouseLeave:Connect(function()
		if UI.category ~= category or UI.query ~= "" then
			button.BackgroundTransparency = 1
		end
	end)

	return { frame = button, label = text, mark = mark, cat = category }
end

local function buildPanel()
	local panel = create("Frame", {
		Name = "Panel",
		BackgroundColor3 = Theme.panel,
		Size = UDim2.fromScale(0.94, 0.76),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Visible = false,
		ClipsDescendants = true,
		Active = true,
	}, GUI)
	round(panel, px(14))
	edge(panel, Theme.stroke, 1, 0.05)
	gradient(panel, Color3.fromRGB(24, 20, 33), Color3.fromRGB(9, 8, 13))
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(820, 540)
	limit.MinSize = Vector2.new(300, 260)
	limit.Parent = panel
	UI.panel = panel

	-- header
	local header = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, px(44)),
		Active = true,
	}, panel)

	local mark = create("Frame", {
		BackgroundColor3 = Theme.accent,
		Size = UDim2.fromOffset(px(22), px(22)),
		Position = UDim2.fromOffset(px(12), px(11)),
	}, header)
	round(mark, px(6))
	gradient(mark, Theme.accentSoft, Theme.accentDeep)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		Text = "R",
		TextColor3 = Theme.text,
		TextSize = px(13),
	}, mark)

	label(header, "R CLIENT", px(13), Theme.text, true).Position = UDim2.fromOffset(px(42), px(11))

	local beta = create("TextLabel", {
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = 0.78,
		Position = UDim2.fromOffset(px(118), px(14)),
		Size = UDim2.fromOffset(px(36), px(16)),
		Font = Enum.Font.GothamBold,
		Text = "BETA",
		TextColor3 = Theme.accentSoft,
		TextSize = px(8),
		Active = true,
	}, header)
	round(beta, px(8))
	local betaButton = create("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		Active = true,
	}, beta)
	click(betaButton, function()
		notify("R Client " .. VERSION .. " beta - " .. #Order .. " modules", Theme.accentSoft)
	end)

	local version = create("TextButton", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(160), px(13)),
		Size = UDim2.fromOffset(px(54), px(18)),
		AutoButtonColor = false,
		Font = Enum.Font.Gotham,
		Text = "v" .. VERSION,
		TextColor3 = Theme.muted,
		TextSize = px(9),
		TextXAlignment = Enum.TextXAlignment.Left,
		Active = true,
	}, header)
	click(version, function()
		notify(string.format("%d modules - %d skins", #Order, #SkinCatalog), Theme.accentSoft)
	end)

	local user = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.05,
		Position = UDim2.new(1, -px(108), 0, px(13)),
		Size = UDim2.fromOffset(px(72), px(18)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		Text = LP.Name,
		TextColor3 = Theme.dim,
		TextSize = px(9),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Active = true,
	}, header)
	round(user, px(9))
	click(user, function()
		notify("logged in as " .. LP.Name, Theme.accentSoft)
	end)

	local close = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -px(30), 0, px(11)),
		Size = UDim2.fromOffset(px(20), px(22)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "×",
		TextSize = px(17),
		TextColor3 = Theme.dim,
		Active = true,
	}, header)
	round(close, px(6))
	click(close, function()
		UI.setOpen(false)
	end)
	close.MouseEnter:Connect(function()
		close.TextColor3 = Theme.text
		close.BackgroundTransparency = 0.75
	end)
	close.MouseLeave:Connect(function()
		close.TextColor3 = Theme.dim
		close.BackgroundTransparency = 1
	end)

	local accentLine = create("Frame", {
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = 0.55,
		Position = UDim2.fromOffset(px(12), px(43)),
		Size = UDim2.new(1, -px(24), 0, px(1)),
	}, panel)

	local body = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, px(45)),
		Size = UDim2.new(1, 0, 1, -px(45)),
	}, panel)

	-- rail
	local rail = create("Frame", {
		BackgroundColor3 = Theme.deep,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(px(46), 1),
	}, body)
	local railList = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -px(40)),
		Position = UDim2.fromOffset(0, px(8)),
	}, rail)
	create("UIListLayout", {
		Padding = UDim.new(0, px(3)),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, railList)

	local shortcuts = {
		Aim = "AIM",
		Combat = "CMB",
		ESP = "ESP",
		Visuals = "VIS",
		Movement = "MOV",
		World = "WLD",
		Skins = "SKN",
		Utility = "UTL",
	}
	UI.railButtons = {}
	for index, category in ipairs(Categories) do
		UI.railButtons[#UI.railButtons + 1] = railButton(railList, shortcuts[category] or string.sub(category, 1, 3), category, index)
	end

	local railClose = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.05,
		Position = UDim2.new(0, px(6), 1, -px(34)),
		Size = UDim2.fromOffset(px(34), px(26)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "×",
		TextColor3 = Theme.dim,
		TextSize = px(13),
		Active = true,
	}, rail)
	round(railClose, px(7))
	click(railClose, function()
		UI.setOpen(false)
	end)

	local railEdge = create("Frame", {
		BackgroundColor3 = Theme.stroke,
		BackgroundTransparency = 0.4,
		Position = UDim2.new(1, -1, 0, 0),
		Size = UDim2.fromOffset(1, 1),
	}, rail)

	-- list pane
	local listPane = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(46), 0),
		Size = UDim2.new(0.53, -px(46), 1, 0),
	}, body)
	padding(listPane, 0, px(8), px(8))

	local listHead = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, px(14)),
		Font = Enum.Font.GothamBold,
		Text = "AIM  ·  0",
		TextColor3 = Theme.muted,
		TextSize = px(8),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, listPane)
	UI.listHead = listHead

	local search = create("TextBox", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.1,
		Position = UDim2.fromOffset(0, px(17)),
		Size = UDim2.new(1, -px(24), 0, px(26)),
		Font = Enum.Font.Gotham,
		PlaceholderText = "  search modules",
		PlaceholderColor3 = Theme.muted,
		Text = "",
		TextColor3 = Theme.text,
		TextSize = px(10),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Active = true,
	}, listPane)
	round(search, px(7))
	padding(search, 0, px(8), 0)
	UI.searchBox = search
	search:GetPropertyChangedSignal("Text"):Connect(function()
		UI.query = search.Text
		UI.filter()
	end)

	local clear = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -px(22), px(19)),
		Size = UDim2.fromOffset(px(20), px(22)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "×",
		TextColor3 = Theme.muted,
		TextSize = px(11),
		Active = true,
	}, listPane)
	click(clear, function()
		search.Text = ""
		UI.query = ""
		UI.filter()
	end)

	local list = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, px(47)),
		Size = UDim2.new(1, 0, 1, -px(47)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = px(2),
		ScrollBarImageColor3 = Theme.accent,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, listPane)
	create("UIListLayout", {
		Padding = UDim.new(0, px(3)),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	UI.list = list

	UI.rows = {}
	for index, module in ipairs(Order) do
		local record = makeRow(list, module)
		record.frame.LayoutOrder = index
		UI.rows[module.id] = record
	end

	local empty = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, px(60)),
		Size = UDim2.new(1, 0, 0, px(30)),
		Font = Enum.Font.Gotham,
		Text = "no modules match",
		TextColor3 = Theme.muted,
		TextSize = px(10),
		Visible = false,
	}, listPane)
	UI.empty = empty

	-- detail pane
	local detail = create("Frame", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.45,
		Position = UDim2.new(0.53, px(4), 0, 0),
		Size = UDim2.new(0.47, -px(14), 1, -px(16)),
	}, body)
	round(detail, px(10))
	edge(detail, Theme.stroke, 1, 0.4)
	padding(detail, 0, px(10), px(10))
	UI.detail = detail

	-- footer
	local footer = create("Frame", {
		BackgroundColor3 = Theme.deep,
		BackgroundTransparency = 0.4,
		Position = UDim2.new(0, 0, 1, -px(26)),
		Size = UDim2.new(1, 0, 0, px(26)),
	}, panel)
	local footText = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(12), 0),
		Size = UDim2.new(1, -px(140), 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = string.format("%d modules  ·  %d skins", #Order, #SkinCatalog),
		TextColor3 = Theme.muted,
		TextSize = px(9),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, footer)

	local save = create("TextButton", {
		BackgroundColor3 = Theme.accent,
		BackgroundTransparency = 0.82,
		Position = UDim2.new(1, -px(112), px(5)),
		Size = UDim2.fromOffset(px(48), px(16)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "SAVE",
		TextColor3 = Theme.accentSoft,
		TextSize = px(8),
		Active = true,
	}, footer)
	round(save, px(5))
	click(save, function()
		if _G.RClient and _G.RClient.save then
			pcall(_G.RClient.save)
		else
			notify("save unavailable here", Theme.warn)
		end
	end)

	local loadBtn = create("TextButton", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.1,
		Position = UDim2.new(1, -px(60), px(5)),
		Size = UDim2.fromOffset(px(48), px(16)),
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = "LOAD",
		TextColor3 = Theme.dim,
		TextSize = px(8),
		Active = true,
	}, footer)
	round(loadBtn, px(5))
	click(loadBtn, function()
		if _G.RClient and _G.RClient.load then
			pcall(_G.RClient.load)
		else
			notify("load unavailable here", Theme.warn)
		end
	end)

	-- drag the header
	local moving, offset = false, nil
	header.InputBegan:Connect(function(item)
		local kind = item.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			moving = true
			offset = Vector2.new(item.Position.X - panel.AbsolutePosition.X, item.Position.Y - panel.AbsolutePosition.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(item)
		if not moving or not offset then
			return
		end
		local kind = item.UserInputType
		if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
			panel.Position = UDim2.fromOffset(item.Position.X - offset.X, item.Position.Y - offset.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(item)
		local kind = item.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			moving = false
		end
	end)

	UI.filter()
	buildDetail()
end

--------------------------------------------------------------------------
-- On-screen readouts
--------------------------------------------------------------------------

local hudGui = {
	watermark = nil,
	watermarkText = nil,
	binds = nil,
	stats = nil,
	skinLabel = nil,
	clock = 0,
	bindSignature = nil,
}

local FPS = { value = 60 }

local function statsValue()
	return math.floor(FPS.value + 0.5)
end

local function buildReadouts()
	local watermark = create("Frame", {
		BackgroundColor3 = Theme.card,
		BackgroundTransparency = 0.12,
		Position = UDim2.fromOffset(px(12), px(10)),
		Size = UDim2.fromOffset(px(170), px(24)),
		Visible = false,
	}, GUI)
	round(watermark, px(7))
	edge(watermark, Theme.stroke, 1, 0.2)
	local accent = create("Frame", {
		BackgroundColor3 = Theme.accent,
		Size = UDim2.fromOffset(px(2), px(14)),
		Position = UDim2.fromOffset(px(8), px(5)),
	}, watermark)
	round(accent, px(1))
	local wmText = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(15), 0),
		Size = UDim2.new(1, -px(19), 1, 0),
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextColor3 = Theme.text,
		TextSize = px(9),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, watermark)
	hudGui.watermark = watermark
	hudGui.watermarkText = wmText

	local binds = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(14), px(42)),
		Size = UDim2.fromOffset(px(190), px(90)),
		Visible = false,
	}, GUI)
	create("UIListLayout", {
		Padding = UDim.new(0, px(2)),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, binds)
	hudGui.binds = binds

	local stats = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, px(14), 0, px(96)),
		Size = UDim2.fromOffset(px(220), px(64)),
		Font = Enum.Font.Gotham,
		Text = "",
		TextColor3 = Theme.dim,
		TextSize = px(10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
	}, GUI)
	hudGui.stats = stats

	local skin = create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -px(12)),
		Size = UDim2.fromOffset(px(260), px(18)),
		Font = Enum.Font.GothamBold,
		Text = "",
		TextColor3 = Theme.accentSoft,
		TextSize = px(11),
		TextTransparency = 0.2,
		Visible = false,
	}, GUI)
	hudGui.skinLabel = skin
end

local function updateReadouts(delta)
	hudGui.clock = hudGui.clock + delta
	if hudGui.clock < 0.25 then
		return
	end
	hudGui.clock = 0

	local watermark = Config.watermark
	if hudGui.watermark then
		hudGui.watermark.Visible = watermark.enabled
		if watermark.enabled then
			local parts = { "R CLIENT" }
			if watermark.fps then
				parts[#parts + 1] = statsValue() .. " fps"
			end
			if watermark.ping then
				parts[#parts + 1] = math.floor(pingSeconds() * 1000) .. " ms"
			end
			if watermark.players then
				parts[#parts + 1] = #Players:GetPlayers() .. " p"
			end
			if watermark.clock then
				parts[#parts + 1] = os.date("%H:%M")
			end
			local text = table.concat(parts, "   ")
			hudGui.watermarkText.Text = text
			hudGui.watermark.Size = UDim2.fromOffset(px(math.max(120, #text * 5.6)), px(24))
		end
	end

	local bindModule = Config.keybindlist
	local binds = hudGui.binds
	if binds then
		binds.Visible = bindModule.enabled
		local signature = table.concat({
			tostring(Config.aimbot.key), tostring(Config.silentaim.key), tostring(Config.ragebot.key),
			tostring(Config.triggerbot.key), tostring(Config.fly.key), tostring(Config.noclip.key),
			tostring(Config.panic.key), tostring(Config.aimbot.enabled), tostring(Config.silentaim.enabled),
			tostring(Config.ragebot.enabled), tostring(Config.triggerbot.enabled),
			tostring(bindModule.onlyEnabled), tostring(bindModule.enabled),
		}, "|")
		if bindModule.enabled and signature ~= hudGui.bindSignature then
			hudGui.bindSignature = signature
			for _, child in ipairs(binds:GetChildren()) do
				if child:IsA("TextLabel") then
					child:Destroy()
				end
			end
			local lines = {
				{ "Aimbot", Config.aimbot.key, Config.aimbot.enabled },
				{ "Silent", Config.silentaim.key, Config.silentaim.enabled },
				{ "Rage", Config.ragebot.key, Config.ragebot.enabled },
				{ "Trigger", Config.triggerbot.key, Config.triggerbot.enabled },
				{ "Fly", Config.fly.key, Config.fly.enabled },
				{ "Noclip", Config.noclip.key, Config.noclip.enabled },
				{ "Panic", Config.panic.key, true },
			}
			local order = 0
			for _, line in ipairs(lines) do
				if line[3] or not bindModule.onlyEnabled then
					order = order + 1
					local item = create("TextLabel", {
						BackgroundColor3 = Theme.card,
						BackgroundTransparency = 0.55,
						Size = UDim2.new(1, 0, 0, px(15)),
						Font = Enum.Font.GothamMedium,
						Text = string.format("  %s   [%s]", line[1], tostring(line[2])),
						TextColor3 = line[3] and Theme.text or Theme.muted,
						TextSize = px(9),
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = order,
					}, binds)
					round(item, px(4))
				end
			end
		end
	end

	local stats = Config.stats
	if hudGui.stats then
		hudGui.stats.Visible = stats.enabled
		if stats.enabled then
			local parts = {}
			if stats.fps then
				parts[#parts + 1] = "fps " .. statsValue()
			end
			if stats.ping then
				parts[#parts + 1] = "ping " .. math.floor(pingSeconds() * 1000) .. "ms"
			end
			if stats.players then
				parts[#parts + 1] = "players " .. #Players:GetPlayers()
			end
			if stats.coords then
				local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
				if root then
					parts[#parts + 1] = string.format("%d, %d, %d", math.floor(root.Position.X), math.floor(root.Position.Y), math.floor(root.Position.Z))
				end
			end
			hudGui.stats.Text = table.concat(parts, "\n")
		end
	end

	if hudGui.skinLabel then
		local show = Config.skinpreview.enabled or Config.skinchanger.enabled
		hudGui.skinLabel.Visible = show
		if show then
			hudGui.skinLabel.Text = "SKIN  ·  " .. string.upper(skinName())
		end
	end
end

local function refreshRows()
	for _, row in pairs(UI.rows) do
		row.refresh()
	end
end


--------------------------------------------------------------------------
-- Profiles
--------------------------------------------------------------------------

local PROFILE = "RClient/profile.json"

local function encodeProfile()
	local data = { version = VERSION, modules = {} }
	for id, entry in pairs(Config) do
		local copy = {}
		for key, value in pairs(entry) do
			copy[key] = value
		end
		data.modules[id] = copy
	end
	return HttpService:JSONEncode(data)
end

local function saveProfile(quiet)
	if type(writefile) ~= "function" then
		return false
	end
	local ok = pcall(function()
		if type(isfolder) == "function" and type(makefolder) == "function" then
			if not isfolder("RClient") then
				makefolder("RClient")
			end
		end
		writefile(PROFILE, encodeProfile())
	end)
	if ok and not quiet then
		notify("profile saved", Theme.good)
	end
	return ok
end

local function loadProfile(quiet)
	if type(isfile) ~= "function" or type(readfile) ~= "function" then
		return false
	end
	local exists = pcall(function()
		return isfile(PROFILE)
	end)
	if not exists then
		return false
	end
	local ok, raw = pcall(readfile, PROFILE)
	if not ok or type(raw) ~= "string" then
		return false
	end
	local decoded, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not decoded or type(data) ~= "table" or type(data.modules) ~= "table" then
		return false
	end
	for id, values in pairs(data.modules) do
		local entry = Config[id]
		if entry and type(values) == "table" then
			for key, value in pairs(values) do
				if entry[key] ~= nil then
					entry[key] = value
				end
			end
		end
	end
	if not quiet then
		notify("profile loaded", Theme.good)
	end
	return true
end

--------------------------------------------------------------------------
-- Boot
--------------------------------------------------------------------------

buildBadge()
buildPanel()
buildReadouts()

installSilentHook()

if Config.config.autoload then
	pcall(loadProfile, true)
end

onChange(function(id, key, value)
	for _, fn in ipairs(UI.widgets) do
		pcall(fn)
	end
	local row = UI.rows[id]
	if row then
		row.refresh()
	end
	if key == "enabled" and id == "fly" then
		notify("fly " .. (value and "on" or "off"), value and Theme.good or Theme.dim)
	end
end)

-- Aim and rage write the camera at Camera + 1, after Roblox's camera update.
RunService:BindToRenderStep("RClientAim", Enum.RenderPriority.Camera.Value + 1, function(delta)
	stepAim(delta)
	stepRage(delta)
end)

local connections = {}
local visualClock = 0
local autosaveClock = 0

connections[#connections + 1] = RunService.RenderStepped:Connect(function(delta)
	FPS.value = lerp(FPS.value, 1 / math.max(delta, 0.0001), 0.08)

	stepSilent()
	stepTrigger()
	stepCombat(delta)

	updateESP()
	updateItemESP(delta)

	visualClock = visualClock + delta
	if visualClock >= 0.2 then
		visualClock = 0
		updateVisuals()
	end

	updateMovement(delta)
	updateAntiAim()
	applySkins(delta)
	updateUtility(delta)
	updateReadouts(delta)

	local camera = workspace.CurrentCamera
	if camera then
		drawCrosshair(camera)
		drawFov(camera)
		drawRadar(camera)
		drawHitMarker(camera)
		drawTargetHud(camera)
	end

	if Config.config.autosave and type(writefile) == "function" then
		autosaveClock = autosaveClock + delta
		if autosaveClock >= 15 then
			autosaveClock = 0
			pcall(saveProfile, true)
		end
	end
end)

LP.CharacterAdded:Connect(function()
	restoreHitboxes()
	Skin.originals = setmetatable({}, { __mode = "k" })
	if Config.noclip.disableOnSpawn then
		Config.noclip.enabled = false
	end
end)

--------------------------------------------------------------------------
-- Unload
--------------------------------------------------------------------------

local function unload()
	pcall(function()
		RunService:UnbindFromRenderStep("RClientAim")
	end)
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	releaseAim()
	Silent.point = nil
	restoreHitboxes()
	stopFly()
	restoreNoclip()
	restoreSkins()
	pcall(saveProfile, true)

	for _, entry in pairs(ESP.entries) do
		dropEntry(entry)
	end
	for _, highlight in pairs(ESP.chams) do
		pcall(function()
			highlight:Destroy()
		end)
	end
	for _, entry in pairs(ESP.items) do
		drop(entry.box)
		drop(entry.label)
	end

	if Visual.saved then
		Lighting.Brightness = Visual.saved.brightness
		Lighting.Ambient = Visual.saved.ambient
		Lighting.OutdoorAmbient = Visual.saved.outdoor
		Lighting.ClockTime = Visual.saved.clock
	end
	if Visual.fog then
		Lighting.FogStart = Visual.fog.start
		Lighting.FogEnd = Visual.fog.finish
	end
	if Visual.grade then
		pcall(function()
			Visual.grade:Destroy()
		end)
	end
	for object, enabled in pairs(Visual.effects) do
		if object and object.Parent then
			pcall(function()
				object.Enabled = enabled
			end)
		end
	end

	local humanoid = currentHumanoid()
	if humanoid then
		pcall(function()
			humanoid.WalkSpeed = Move.baseSpeed or 16
			humanoid.JumpPower = Move.baseJump or 50
		end)
	end

	pcall(function()
		GUI:Destroy()
	end)
	_G.RClient = nil
end

_G.RClient = {
	version = VERSION,
	destroy = unload,
	unload = unload,
	toggle = function()
		UI.setOpen(not UI.open)
	end,
	panic = doPanic,
	save = saveProfile,
	load = loadProfile,
}

notify("R Client " .. VERSION .. " loaded - tap the R badge", Theme.accent)
