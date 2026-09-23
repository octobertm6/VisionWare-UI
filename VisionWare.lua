--[[
	VisionWare UI Library
	A Rayfield-style UI library built on the VisionWare menu design: navy window,
	electric-blue accent, a sidebar of categories and tabs, and two columns of
	sections on every tab.

	Quick start:
		local VisionWare = loadstring(readfile("VisionWareUI.lua"))()
		local Window = VisionWare:CreateWindow({ Name = "VisionWare" })
		Window:CreateCategory("Main")
		local Tab = Window:CreateTab("Home", "Gear")
		local Section = Tab:CreateSection({ Name = "Example", Side = "Left" })
		Section:CreateToggle({ Name = "Enabled", CurrentValue = false, Callback = function(v) print(v) end })
		Window:LoadConfiguration()   -- applies the auto-load config, call it last

	See README.md for every element and option.

	Performance notes:
	- No per-frame work while the menu is idle. The only RenderStepped loop is the
	  backdrop snow, and it runs only while the menu is open.
	- One InputBegan / InputChanged / InputEnded connection per window serves every
	  slider, colour picker, keybind and the window drag.
	- Popups (dropdown lists, colour pickers) are built the first time they open and
	  reused after that.
	- Section layout and canvas sizes are recalculated once per batch of changes,
	  not once per element.
]]

local VERSION = "1.0.0"

-- only one copy may run: unload a previous copy before building a new one
local env = (getgenv and getgenv()) or _G
if type(env.VisionWareUI) == "table" and type(env.VisionWareUI.Destroy) == "function" then
	pcall(env.VisionWareUI.Destroy, env.VisionWareUI)
end

local UIS          = game:GetService("UserInputService")
local Players      = game:GetService("Players")
local TextService  = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local Lighting     = game:GetService("Lighting")
local LP           = Players.LocalPlayer

---------------------------------------------------------------------------
-- Fonts: Inter, then Builder Sans, then Gotham
---------------------------------------------------------------------------
local function LoadFamily(family)
	local ok, font = pcall(Font.new, "rbxasset://fonts/families/" .. family .. ".json", Enum.FontWeight.Medium)
	if not ok then return nil end
	local params = Instance.new("GetTextBoundsParams")
	params.Text, params.Font, params.Size, params.Width = "VisionWare", font, 20, 1000
	local ok2, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	if ok2 and bounds and bounds.X > 0 then return family end
	return nil
end
local FAMILY = LoadFamily("Inter") or LoadFamily("BuilderSans") or "GothamSSm"
local function F(weight)
	return Font.new("rbxasset://fonts/families/" .. FAMILY .. ".json", weight, Enum.FontStyle.Normal)
end
local FONT = {
	Regular = F(Enum.FontWeight.Regular),
	Medium  = F(Enum.FontWeight.Medium),
	Bold    = F(Enum.FontWeight.Bold),
	Mono    = Font.fromEnum(Enum.Font.Code),
}
-- text sizes in window units (the whole window is multiplied by the scale)
local TS = {
	Row = 7.3, Key = 7.4, Drop = 5.5, Title = 8.3, Footer = 7.8, SideItem = 7.9, Section = 8.7,
}
local DROP_TEXT_SIZE, DROP_ROW_H = 6.8, 8.5

local ASSETS = {
	Logo = "rbxassetid://76539991703135",   -- VisionWare "V" logo
	Gun  = "rbxassetid://129186730",        -- white pistol silhouette (tinted)
}

---------------------------------------------------------------------------
-- Theme. CreateWindow({ Theme = { Accent = Color3... } }) overrides any key.
---------------------------------------------------------------------------
local C = {
	WindowBg     = Color3.fromRGB(6, 9, 16),
	WindowBorder = Color3.fromRGB(20, 32, 54),
	SidebarLine  = Color3.fromRGB(17, 27, 46),
	Highlight    = Color3.fromRGB(12, 19, 33),
	Footer       = Color3.fromRGB(8, 13, 23),

	PanelBg      = Color3.fromRGB(9, 14, 25),
	PanelBorder  = Color3.fromRGB(20, 32, 54),
	Separator    = Color3.fromRGB(18, 29, 49),

	Accent       = Color3.fromRGB(0, 88, 248),     -- toggles, sliders, indicator
	AccentDark   = Color3.fromRGB(0, 72, 212),
	AccentText   = Color3.fromRGB(89, 176, 252),   -- "Ware" in the wordmark
	Subtitle     = Color3.fromRGB(53, 95, 152),    -- "SCRIPT HUB"
	Glow         = Color3.fromRGB(0, 88, 248),

	Text         = Color3.fromRGB(235, 240, 248),
	Title        = Color3.fromRGB(245, 248, 255),
	Dim          = Color3.fromRGB(78, 88, 108),
	Dimmer       = Color3.fromRGB(62, 72, 92),
	SectionText  = Color3.fromRGB(56, 66, 86),
	IconDim      = Color3.fromRGB(66, 76, 98),

	Track        = Color3.fromRGB(8, 12, 21),
	TrackStroke  = Color3.fromRGB(30, 44, 70),
	DropBg       = Color3.fromRGB(16, 24, 41),
	DropText     = Color3.fromRGB(72, 84, 106),
	Hover        = Color3.fromRGB(34, 46, 70),
	ToggleOff    = Color3.fromRGB(34, 46, 70),
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function New(class, props, children)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then obj[k] = v end
	end
	for _, child in ipairs(children or {}) do child.Parent = obj end
	if props and props.Parent then obj.Parent = props.Parent end
	return obj
end

local function Frame(parent, x, y, w, h, color, extra)
	local f = New("Frame", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.PanelBg, BorderSizePixel = 0, Parent = parent,
	})
	if extra then for k, v in pairs(extra) do f[k] = v end end
	return f
end

local function Round(obj, radius)
	return New("UICorner", { CornerRadius = radius and UDim.new(0, radius) or UDim.new(1, 0), Parent = obj })
end

local function Stroke(obj, color, thickness, transparency)
	local isText = obj:IsA("TextLabel") or obj:IsA("TextButton")
	return New("UIStroke", {
		Color = color, Thickness = thickness or 1, Transparency = transparency or 0,
		ApplyStrokeMode = isText and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border,
		Parent = obj,
	})
end

local function Label(parent, x, y, w, h, text, size, color, font, xalign)
	return New("TextLabel", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
		FontFace = font or FONT.Regular,
		TextXAlignment = xalign or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Parent = parent,
	})
end

local function Button(parent, x, y, w, h)
	return New("TextButton", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = parent,
	})
end

local function Bar(parent, cx, cy, length, thick, rotation, color, rounded)
	local f = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(length, thick), Rotation = rotation or 0,
		BackgroundColor3 = color, BorderSizePixel = 0, Parent = parent,
	})
	if rounded then Round(f) end
	return f
end

local function Circle(parent, cx, cy, d, color)
	local f = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(d, d), BackgroundColor3 = color, BorderSizePixel = 0, Parent = parent,
	})
	Round(f)
	return f
end

local function safeCall(where, fn, ...)
	if type(fn) ~= "function" then return end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[VisionWare] " .. tostring(where) .. ": " .. tostring(err)) end
end

-- lets element methods work with both el:Set(v) and el.Set(v)
local function argOf(self, a, b)
	if a == self then return b end
	return a
end

local function keyName(k)
	if typeof(k) == "EnumItem" then return k.Name end
	if k == nil or k == "" then return "None" end
	return tostring(k)
end

-- "Mouse 1" / "Mouse 2" / "Mouse 3" or a KeyCode name; nil for anything else
local function inputName(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.Keyboard then
		return input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name or nil
	elseif t == Enum.UserInputType.MouseButton1 then return "Mouse 1"
	elseif t == Enum.UserInputType.MouseButton2 then return "Mouse 2"
	elseif t == Enum.UserInputType.MouseButton3 then return "Mouse 3"
	end
	return nil
end

local function isPointer(input)
	local t = input.UserInputType
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

local function isMove(input)
	local t = input.UserInputType
	return t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch
end

local function guiParent()
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then return hui end
	local ok2, core = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and core then return core end
	return LP:WaitForChild("PlayerGui")
end

local function newScreen(name, order)
	local s = New("ScreenGui", {
		Name = name, ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = order,
	})
	pcall(function() s.OnTopOfCoreBlur = true end)
	pcall(function() s.Parent = guiParent() end)
	if not s.Parent then s.Parent = LP:WaitForChild("PlayerGui") end
	return s
end

---------------------------------------------------------------------------
-- Maid: owns connections, instances and cleanup functions
---------------------------------------------------------------------------
local function newMaid()
	local items = {}
	local maid = {}
	function maid:Add(item) items[#items + 1] = item; return item end
	function maid:Clean()
		for i = #items, 1, -1 do
			local item = items[i]
			items[i] = nil
			local kind = typeof(item)
			if kind == "RBXScriptConnection" then item:Disconnect()
			elseif kind == "Instance" then item:Destroy()
			elseif kind == "function" then pcall(item)
			elseif kind == "table" and item.Clean then item:Clean() end
		end
	end
	return maid
end

---------------------------------------------------------------------------
-- Icons: drawn with frames in a 12 x 12 box, so no asset ids are needed.
-- Use them by name: CreateTab("Aimbot", "Gun"). Any asset id also works.
---------------------------------------------------------------------------
local Icons = {}

function Icons.Pistol(h, col)
	local slide = Frame(h, 0.5, 2.6, 11.2, 3, col); Round(slide, 1)
	Frame(h, 0.7, 1.6, 1.4, 1.2, col)
	Frame(h, 9.4, 5.4, 2.3, 0.9, col)
	Frame(h, 0.9, 5.2, 4.2, 1.6, col)
	local grip = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(3.1, 6.2),
		Size = UDim2.fromOffset(3, 5.6), Rotation = 16,
		BackgroundColor3 = col, BorderSizePixel = 0, Parent = h,
	})
	Round(grip, 1)
	local guard = New("Frame", {
		Position = UDim2.fromOffset(4.9, 5.6), Size = UDim2.fromOffset(3.4, 2.8),
		BackgroundTransparency = 1, Parent = h,
	})
	Round(guard, 1.4)
	Stroke(guard, col, 0.9)
	Frame(h, 5.9, 6, 0.9, 1.7, col)
end

-- the pistol image, with the drawn pistol underneath until the image has loaded
function Icons.Gun(h, col)
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(15, 15), BackgroundTransparency = 1, Parent = h,
	})
	local fallback = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = holder,
	})
	Icons.Pistol(fallback, col)
	local img = New("ImageLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = ASSETS.Gun,
		ImageColor3 = col, ScaleType = Enum.ScaleType.Fit, Parent = holder,
	})
	task.spawn(function()
		local CP = game:GetService("ContentProvider")
		pcall(function() CP:PreloadAsync({ img }) end)
		local ok, status = pcall(function() return CP:GetAssetFetchStatus(img.Image) end)
		if img.IsLoaded or (ok and status == Enum.AssetFetchStatus.Success) then
			fallback.Visible = false
		else
			img.Visible = false
		end
	end)
end

function Icons.Skeleton(h, col)
	Circle(h, 6, 2.3, 3.6, col)
	Frame(h, 2.5, 4.8, 7, 1.4, col)
	Frame(h, 5.3, 6.2, 1.4, 5.5, col)
	Frame(h, 3.3, 7.4, 5.4, 0.9, col)
	Frame(h, 3.8, 9.2, 4.4, 0.9, col)
end

function Icons.Person(h, col)
	Circle(h, 6, 3, 4, col)
	local body = Frame(h, 1, 7, 10, 4.5, col)
	Round(body, 3)
end

function Icons.Lines(h, col)
	for i = 0, 2 do
		local l = Frame(h, 1, 2 + i * 3, 10, 2, col)
		Round(l, 1)
	end
end

function Icons.Globe(h, col)
	local c = Circle(h, 6, 6, 10.5, col)
	c.BackgroundTransparency = 1
	Stroke(c, col, 1)
	Frame(h, 1, 5.5, 10, 1, col)
	Frame(h, 2.2, 3, 7.6, 0.9, col)
	Frame(h, 2.2, 8.1, 7.6, 0.9, col)
	local e = Circle(h, 6, 6, 10.5, col)
	e.Size = UDim2.fromOffset(5, 10.5)
	e.BackgroundTransparency = 1
	Stroke(e, col, 0.9)
end

function Icons.Cube(h, col)
	local sq = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(8, 8), Rotation = 45, BackgroundTransparency = 1, Parent = h,
	})
	Stroke(sq, col, 1)
	Frame(h, 5.55, 6, 0.9, 5.8, col)
	Bar(h, 3.6, 4.6, 5, 0.9, 30, col)
	Bar(h, 8.4, 4.6, 5, 0.9, -30, col)
end

function Icons.Gear(h, col)
	Circle(h, 6, 6, 8, col)
	for _, r in ipairs({ 0, 45, 90, 135 }) do Bar(h, 6, 6, 12, 2.6, r, col, true) end
	Circle(h, 6, 6, 3.2, C.WindowBg)
end

function Icons.Bullet(h, col)
	for _, x in ipairs({ 2.2, 7.2 }) do
		local tip = Frame(h, x, 1, 2.6, 4, col); Round(tip, 1.3)
		Frame(h, x, 3, 2.6, 2, col)
		Frame(h, x, 5.6, 2.6, 5, col)
		Frame(h, x - 0.3, 10.2, 3.2, 1, col)
	end
end

function Icons.Box(h, col)
	local body = Frame(h, 1, 3.5, 10, 7.5, col); Round(body, 1)
	Frame(h, 0.5, 1.5, 11, 2.2, col)
	Frame(h, 1, 3.7, 10, 0.8, C.WindowBg)
	Frame(h, 5.2, 1.5, 1.6, 5, C.WindowBg)
end

function Icons.Folder(h, col)
	local tab = Frame(h, 0.5, 2.2, 4.6, 2, col); Round(tab, 1)
	local body = Frame(h, 0.5, 3.4, 11, 7.2, col); Round(body, 1)
end

function Icons.Pin(h, col)
	Circle(h, 6, 4.5, 7.5, col)
	New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 7.4),
		Size = UDim2.fromOffset(4.6, 4.6), Rotation = 45,
		BackgroundColor3 = col, BorderSizePixel = 0, Parent = h,
	})
	Circle(h, 6, 4.5, 2.8, C.WindowBg)
end

function Icons.Dot(h, col)
	Circle(h, 6, 6, 7, col)
end

function Icons.Star(h, col)
	Bar(h, 6, 6, 9, 2, 0, col, true)
	Bar(h, 6, 6, 9, 2, 90, col, true)
	Bar(h, 6, 6, 6, 1.5, 45, col, true)
	Bar(h, 6, 6, 6, 1.5, -45, col, true)
end

function Icons.Home(h, col)
	local roof = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 5),
		Size = UDim2.fromOffset(6.4, 6.4), Rotation = 45,
		BackgroundColor3 = col, BorderSizePixel = 0, Parent = h,
	})
	Round(roof, 1)
	local body = Frame(h, 2.2, 5.5, 7.6, 5.5, col); Round(body, 1)
	Frame(h, 5, 7.5, 2, 3.5, C.WindowBg)
end

function Icons.Eye(h, col)
	local outer = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(11, 7), BackgroundTransparency = 1, Parent = h,
	})
	Round(outer)
	Stroke(outer, col, 1)
	Circle(h, 6, 6, 3.6, col)
end

function Icons.Palette(h, col)
	local c = Circle(h, 6, 6, 10.5, col)
	c.BackgroundTransparency = 1
	Stroke(c, col, 1)
	Circle(h, 4, 4.2, 2, col)
	Circle(h, 7.8, 4.2, 2, col)
	Circle(h, 3.6, 7.6, 2, col)
	Circle(h, 7.6, 8, 2.4, C.WindowBg)
end

-- builds an icon (a name from Icons, a builder function, or an asset id) in a
-- size x size holder. Returns the holder and a recolour function whose parts are
-- collected once here, so switching tabs never walks the icon's descendants.
local function MakeIcon(parent, icon, x, y, size, col)
	size = size or 12
	local holder = New("Frame", {
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1, Parent = parent,
	})
	local builder = (type(icon) == "function" and icon) or (type(icon) == "string" and Icons[icon]) or nil
	if builder then
		local box = holder
		if size ~= 12 then
			box = New("Frame", { Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = holder })
			New("UIScale", { Scale = size / 12, Parent = box })
		end
		builder(box, col)
	elseif icon ~= nil and icon ~= 0 and icon ~= "" then
		local id = tostring(icon)
		if tonumber(id) then id = "rbxassetid://" .. id end
		New("ImageLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = id,
			ImageColor3 = col, ScaleType = Enum.ScaleType.Fit, Parent = holder,
		})
	end
	local parts = {}
	for _, d in ipairs(holder:GetDescendants()) do
		if (d:IsA("Frame") and d.BackgroundTransparency < 1 and d.BackgroundColor3 ~= C.WindowBg)
			or d:IsA("ImageLabel") or d:IsA("UIStroke") then
			parts[#parts + 1] = d
		end
	end
	local function recolor(c)
		for i = 1, #parts do
			local d = parts[i]
			if d:IsA("ImageLabel") then d.ImageColor3 = c
			elseif d:IsA("UIStroke") then d.Color = c
			else d.BackgroundColor3 = c end
		end
	end
	return holder, recolor
end

---------------------------------------------------------------------------
-- Library object
---------------------------------------------------------------------------
local VisionWare = {
	Version = VERSION,
	Flags   = {},        -- flag -> element (every element that holds a value)
	Windows = {},
	Icons   = Icons,
	Theme   = C,
	Fonts   = FONT,
}

local Window  = {}; Window.__index  = Window
local Tab     = {}; Tab.__index     = Tab
local Section = {}; Section.__index = Section
local Element = {}; Element.__index = Element

-- window layout, in window units (before the scale is applied)
local WIN_W, WIN_H = 480, 307
local SIDEBAR_W, FOOTER_Y = 150, 293
local HEADER_H, ROW_START, ROW_GAP = 13, 21, 11.45
local PANEL_GAP, PAGE_TOP = 7, 14
local METRICS = {
	Left  = { X = 7,   W = 160, PadLeft = 8, PadRight = 11, ToggleInset = 5, ToggleW = 21, SliderW = 73 },
	Right = { X = 176, W = 143, PadLeft = 7, PadRight = 8,  ToggleInset = 7, ToggleW = 20, SliderW = 63 },
	Full  = { X = 7,   W = 312, PadLeft = 8, PadRight = 11, ToggleInset = 5, ToggleW = 21, SliderW = 110 },
}
local function panelHeight(rows) return math.ceil(ROW_START + (math.max(rows, 1) - 1) * ROW_GAP + 9) end

---------------------------------------------------------------------------
-- Element base: value, callback, OnChanged listeners
---------------------------------------------------------------------------
function Element:_fire(v)
	self.CurrentValue = v
	if self.Callback then safeCall(self.Name, self.Callback, v) end
	local l = self.Listeners
	if l then for i = 1, #l do safeCall(self.Name, l[i], v) end end
end

-- extra listener on top of the Callback; runs on every change
function Element:OnChanged(fn)
	self.Listeners = self.Listeners or {}
	table.insert(self.Listeners, fn)
	return self
end

function Element:Get() return self.CurrentValue end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function VisionWare:CreateWindow(opts)
	opts = opts or {}

	-- theme overrides (Accent also recolours the darker accent and the glow)
	if type(opts.Theme) == "table" then
		for k, v in pairs(opts.Theme) do C[k] = v end
		if opts.Theme.Accent then
			if not opts.Theme.AccentDark then C.AccentDark = opts.Theme.Accent:Lerp(Color3.new(0, 0, 0), 0.15) end
			if not opts.Theme.Glow then C.Glow = opts.Theme.Accent end
		end
	end

	local saving = type(opts.ConfigurationSaving) == "table" and opts.ConfigurationSaving or {}
	local self = setmetatable({
		Maid          = newMaid(),
		Tabs          = {},
		Scale         = opts.Scale or 1.7,
		ToggleKey     = keyName(opts.ToggleKey or "RightShift"),
		ConfigFolder  = opts.ConfigFolder or saving.FolderName or "VisionWare",
		Binds         = {},     -- key name -> { keybind, ... }
		Drag          = nil,    -- active drag handler (slider, colour picker, window)
		Listening     = nil,    -- keybind waiting for a key
		Popup         = nil,    -- open popup { Frame, Owner, Page, OnClose }
		SideY         = 0,
		SideLast      = nil,
		BackdropOn    = opts.Backdrop ~= false,
		Notes         = {},
		NoteCount     = 0,
		OnUnloadFns   = {},
		-- plain-text name for notifications (rich-text tags stripped)
		Title         = opts.Title or (opts.Name and (tostring(opts.Name):gsub("<[^>]->", ""))) or "VisionWare",
	}, Window)
	if type(opts.OnUnload) == "function" then table.insert(self.OnUnloadFns, opts.OnUnload) end
	table.insert(VisionWare.Windows, self)
	local maid = self.Maid

	-- screen, holder (unscaled, for dragging in real pixels) and the scaled window
	local screen = maid:Add(newScreen("VisionWare", 999999990))
	self.Screen = screen
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIN_W * self.Scale, WIN_H * self.Scale),
		BackgroundTransparency = 1, Parent = screen,
	})
	self.Holder = holder
	local win = Frame(holder, 0, 0, WIN_W, WIN_H, C.WindowBg)
	self.UIScale = New("UIScale", { Scale = self.Scale, Parent = win })
	Stroke(win, C.WindowBorder, 1)
	Round(win, 2)
	win.ClipsDescendants = true
	self.Frame = win

	-- accent glow behind the logo: stacked translucent circles from the top-left corner
	do
		local layers = 14
		for i = 1, layers do
			local r = 95 * (1 - (i - 1) / layers)
			local c = Circle(win, 0, 0, r * 2, C.Glow)
			c.BackgroundTransparency = 1 - 0.0125
		end
	end

	-- header: logo, wordmark (rich text), spaced subtitle
	do
		local textX = 39
		if opts.Logo ~= false then
			New("ImageLabel", {
				Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(24, 19),
				BackgroundTransparency = 1, Image = opts.Logo or ASSETS.Logo,
				ScaleType = Enum.ScaleType.Fit, Parent = win,
			})
		else
			textX = 12
		end
		local accentHex = C.AccentText:ToHex()
		local word = Label(win, textX, 7, 110, 14, "", 11.5, C.Text, FONT.Bold)
		word.RichText = true
		word.Text = opts.Name or ('Vision<font color="#' .. accentHex .. '">Ware</font>')
		local subtitle = opts.Subtitle or "SCRIPT HUB"
		local spaced = subtitle:upper():gsub("(.)", "%1 "):sub(1, -2)
		Label(win, textX + 1, 20, 110, 8, spaced, 4.6, C.Subtitle, FONT.Medium)
	end

	-- sidebar divider and footer
	Frame(win, SIDEBAR_W, 0, 1, FOOTER_Y, C.SidebarLine)
	local footer = Frame(win, 0, FOOTER_Y, WIN_W, WIN_H - FOOTER_Y, C.Footer)
	self.FooterLabel = Label(footer, SIDEBAR_W + 1, 0, WIN_W - SIDEBAR_W - 1, 13,
		opts.Footer or "VisionWare [beta]", TS.Footer, C.SectionText, FONT.Regular, Enum.TextXAlignment.Center)

	-- pages
	self.PagesHolder = New("Frame", {
		Position = UDim2.fromOffset(SIDEBAR_W + 1, 2), Size = UDim2.fromOffset(WIN_W - SIDEBAR_W - 3, FOOTER_Y - 2),
		BackgroundTransparency = 1, Parent = win,
	})

	-- sidebar list (scrolls when there are more tabs than fit)
	local side = New("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 32), Size = UDim2.fromOffset(SIDEBAR_W, FOOTER_Y - 32),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y, CanvasSize = UDim2.new(), Parent = win,
	})
	self.Sidebar = side
	self.SelHighlight = Frame(side, 13, 0, 113, 22, C.Highlight, { Visible = false, ZIndex = 1 })
	Round(self.SelHighlight, 3)
	self.SelIndicator = Frame(side, 11, 0, 2, 15, C.AccentDark, { Visible = false, ZIndex = 2 })
	Round(self.SelIndicator, 1)

	-- popup layer: one full-window layer above everything; clicking outside the
	-- open popup closes it
	local layer = New("Frame", {
		Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundTransparency = 1,
		Visible = false, ZIndex = 100, Parent = win,
	})
	local catcher = Button(layer, 0, 0, WIN_W, WIN_H)
	catcher.MouseButton1Click:Connect(function() self:ClosePopup() end)
	self.PopupLayer = layer

	-- window drag: the logo area and the strip above the sections
	do
		local function beginDrag(input)
			if not isPointer(input) then return end
			local start = UIS:GetMouseLocation()
			local startPos = holder.Position
			self.Drag = function()
				local d = UIS:GetMouseLocation() - start
				local ox, oy = self:_clampOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
				holder.Position = UDim2.new(0.5, ox, 0.5, oy)
			end
		end
		for _, grip in ipairs({ Button(win, 0, 0, SIDEBAR_W, 32), Button(win, SIDEBAR_W, 0, WIN_W - SIDEBAR_W, PAGE_TOP + 2) }) do
			grip.ZIndex = 10
			grip.InputBegan:Connect(beginDrag)
		end
		maid:Add(screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:_clampWindow() end))
	end

	-- the three shared input connections
	maid:Add(UIS.InputChanged:Connect(function(input)
		local drag = self.Drag
		if drag and isMove(input) then drag(input) end
	end))
	maid:Add(UIS.InputEnded:Connect(function(input)
		if isPointer(input) then self.Drag = nil end
		local name = inputName(input)
		local list = name and self.Binds[name]
		if list then
			for i = 1, #list do
				local k = list[i]
				if k.Held then k.Held = false; k:_release() end
			end
		end
	end))
	maid:Add(UIS.InputBegan:Connect(function(input, gp)
		local listen = self.Listening
		if listen then listen(input) return end
		if gp then return end
		local name = inputName(input)
		if not name then return end
		if name == self.ToggleKey then self:Toggle() return end
		local list = self.Binds[name]
		if list then for i = 1, #list do list[i]:_press() end end
	end))

	-- notifications (unscaled, bottom right)
	do
		local ns = maid:Add(newScreen("VisionWareNotify", 999999995))
		self.NotifyHolder = New("Frame", {
			AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(270, 600),
			BackgroundTransparency = 1, Parent = ns,
		})
		New("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = self.NotifyHolder,
		})
	end

	-- backdrop: blur + tint + drifting snow while the menu is open
	if opts.Backdrop ~= false then self:_buildBackdrop(opts) end

	-- touch devices get a small button to open / close the menu
	if opts.ShowToggleButton or (opts.ShowToggleButton == nil and UIS.TouchEnabled and not UIS.KeyboardEnabled) then
		local ts = maid:Add(newScreen("VisionWareToggle", 999999991))
		local b = New("ImageButton", {
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = C.WindowBg, AutoButtonColor = false, Image = (opts.Logo ~= false and opts.Logo) or ASSETS.Logo,
			ScaleType = Enum.ScaleType.Fit, Parent = ts,
		})
		Round(b, 8); Stroke(b, C.WindowBorder, 1)
		New("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = b })
		b.MouseButton1Click:Connect(function() self:Toggle() end)
	end

	env.VisionWareUI = VisionWare
	return self
end

-- keep the window fully on screen (the holder is centred, so offsets clamp symmetrically)
function Window:_clampOffset(ox, oy)
	local screen, size = self.Screen.AbsoluteSize, self.Holder.AbsoluteSize
	local lx = math.max(0, (screen.X - size.X) * 0.5)
	local ly = math.max(0, (screen.Y - size.Y) * 0.5)
	return math.clamp(ox, -lx, lx), math.clamp(oy, -ly, ly)
end
function Window:_clampWindow()
	local p = self.Holder.Position
	local ox, oy = self:_clampOffset(p.X.Offset, p.Y.Offset)
	self.Holder.Position = UDim2.new(0.5, ox, 0.5, oy)
end

function Window:_buildBackdrop(opts)
	local maid = self.Maid
	local BLUR_SIZE   = opts.BlurSize or 10
	local TINT_ALPHA  = 0.7
	local SNOW_COUNT  = opts.Snow == false and 0 or 70
	local SNOW_COLORS = { Color3.fromRGB(150, 196, 255), Color3.fromRGB(110, 165, 245), Color3.fromRGB(205, 228, 255) }
	local FADE        = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local backdrop = maid:Add(newScreen("VisionWareBackdrop", 999999989))
	local tint = New("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 26, 62),
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = backdrop,
	})
	local snowLayer = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = backdrop })
	local blur
	if opts.Blur ~= false then
		blur = Instance.new("BlurEffect")
		blur.Name = "VisionWareBlur"
		blur.Size = 0
		blur.Parent = Lighting
		maid:Add(blur)
	end

	local flakes = {}
	for i = 1, SNOW_COUNT do
		local size = math.random(2, 5)
		local f = New("Frame", {
			Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
			BackgroundColor3 = SNOW_COLORS[math.random(1, #SNOW_COLORS)], BackgroundTransparency = 1, Parent = snowLayer,
		})
		Round(f)
		flakes[i] = {
			frame = f, x = math.random(), y = math.random(),
			speed = 35 + math.random() * 75 * (size / 5),
			sway = 6 + math.random() * 18, phase = math.random() * math.pi * 2, swaySpeed = 0.6 + math.random() * 1.2,
			alpha = 0.15 + math.random() * 0.45,
		}
	end

	local shown, drawnShown = 0, -1
	local animConn = nil
	local function step(dt)
		local size = backdrop.AbsoluteSize
		local w, h = size.X, size.Y
		if w <= 0 or h <= 0 then return end
		local t = os.clock()
		local fading = shown ~= drawnShown          -- transparency is only written while fading
		drawnShown = shown
		for i = 1, #flakes do
			local fl = flakes[i]
			fl.y = fl.y + (fl.speed * dt) / h
			if fl.y > 1.02 then fl.y = -0.02; fl.x = math.random() end
			fl.frame.Position = UDim2.fromOffset(fl.x * w + math.sin(t * fl.swaySpeed + fl.phase) * fl.sway, fl.y * h)
			if fading then fl.frame.BackgroundTransparency = 1 - (1 - fl.alpha) * shown end
		end
	end
	local fadeToken = 0
	local function setOpen(open)
		fadeToken = fadeToken + 1
		local token = fadeToken
		TweenService:Create(tint, FADE, { BackgroundTransparency = open and TINT_ALPHA or 1 }):Play()
		if blur then TweenService:Create(blur, FADE, { Size = open and BLUR_SIZE or 0 }):Play() end
		if #flakes == 0 then return end
		if open and not animConn then animConn = RunService.RenderStepped:Connect(step) end
		local from, start = shown, os.clock()
		task.spawn(function()
			while token == fadeToken do
				local a = math.clamp((os.clock() - start) / FADE.Time, 0, 1)
				shown = from + ((open and 1 or 0) - from) * a
				if a >= 1 then break end
				RunService.RenderStepped:Wait()
			end
			-- fully closed: stop the animation, nothing runs while the menu is hidden
			if token == fadeToken and not open and animConn then
				animConn:Disconnect(); animConn = nil
				for i = 1, #flakes do flakes[i].frame.BackgroundTransparency = 1 end
				drawnShown = -1
			end
		end)
	end
	maid:Add(function() fadeToken = fadeToken + 1; if animConn then animConn:Disconnect(); animConn = nil end end)
	self._setBackdrop = setOpen
	setOpen(self.Holder.Visible and self.BackdropOn)
end

-- open / close ------------------------------------------------------------
function Window:SetVisible(v)
	v = v and true or false
	if self.Holder.Visible == v then return end
	self.Holder.Visible = v
	if not v then self:ClosePopup(); self.Drag = nil end
	if self._setBackdrop then self._setBackdrop(v and self.BackdropOn) end
end
function Window:Toggle() self:SetVisible(not self.Holder.Visible) end
function Window:IsVisible() return self.Holder.Visible end

function Window:SetBackdrop(on)
	self.BackdropOn = on and true or false
	if self._setBackdrop then self._setBackdrop(self.Holder.Visible and self.BackdropOn) end
end

function Window:SetScale(v)
	v = math.clamp(tonumber(v) or 1.7, 0.5, 4)
	self.Scale = v
	self.UIScale.Scale = v
	self.Holder.Size = UDim2.fromOffset(WIN_W * v, WIN_H * v)
	self:ClosePopup()
	self:_clampWindow()
end

function Window:SetToggleKey(k)
	self.ToggleKey = keyName(k)
end

function Window:SetFooter(text) self.FooterLabel.Text = text end

-- popups ------------------------------------------------------------------
-- shows `popup` (a frame parented to PopupLayer) under `anchor`, right-aligned
-- with it, flipped above when there is no room below
function Window:OpenPopup(popup, anchor, owner, onClose)
	self:ClosePopup()
	local s = self.Scale
	local base = self.Frame.AbsolutePosition
	local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
	local w, h = popup.Size.X.Offset, popup.Size.Y.Offset
	local x = (ap.X - base.X + as.X) / s - w
	local y = (ap.Y - base.Y + as.Y) / s + 1
	if y + h > FOOTER_Y - 2 then y = (ap.Y - base.Y) / s - h - 1 end
	x = math.clamp(x, 2, WIN_W - w - 2)
	y = math.clamp(y, 2, WIN_H - h - 2)
	popup.Position = UDim2.fromOffset(x, y)
	popup.Visible = true
	self.PopupLayer.Visible = true
	self.Popup = { Frame = popup, Owner = owner, OnClose = onClose }
end

function Window:ClosePopup()
	local p = self.Popup
	if not p then return end
	self.Popup = nil
	self.Drag = nil
	p.Frame.Visible = false
	self.PopupLayer.Visible = false
	if p.OnClose then safeCall("popup", p.OnClose) end
end

-- sidebar -----------------------------------------------------------------
-- spacing: category label -> first tab 17, tab -> tab 22, last tab -> next label 20
function Window:CreateCategory(name)
	local y
	if self.SideLast == nil then y = 8.5
	elseif self.SideLast == "tab" then y = self.SideY + 20
	else y = self.SideY + 17 end
	self.SideY, self.SideLast = y, "label"
	local l = Label(self.Sidebar, 14, y - 6, 120, 12, tostring(name), TS.Section, C.SectionText, FONT.Medium)
	l.ZIndex = 3
	self.Sidebar.CanvasSize = UDim2.fromOffset(0, y + 14)
	return l
end
Window.CreateSeparator = Window.CreateCategory

function Window:CreateTab(name, icon)
	local opts = type(name) == "table" and name or { Name = name, Icon = icon }
	local y
	if self.SideLast == nil then y = 12
	elseif self.SideLast == "label" then y = self.SideY + 17
	else y = self.SideY + 22 end
	self.SideY, self.SideLast = y, "tab"
	self.Sidebar.CanvasSize = UDim2.fromOffset(0, y + 14)

	local page = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = C.Accent, ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(), Visible = false, Parent = self.PagesHolder,
	})
	local tab = setmetatable({
		Window = self, Name = tostring(opts.Name or "Tab"), Page = page, Sections = {}, Y = y,
	}, Tab)

	local ic, recolor = MakeIcon(self.Sidebar, opts.Icon or opts.Image, 29, y - 6, 12, C.IconDim)
	ic.ZIndex = 3
	tab.Recolor = recolor
	tab.Label = Label(self.Sidebar, 47, y - 7, 100, 14, tab.Name, TS.SideItem, C.Dimmer, FONT.Medium)
	tab.Label.ZIndex = 3
	local btn = Button(self.Sidebar, 13, y - 11, 113, 22)
	btn.ZIndex = 4
	btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
	btn.MouseEnter:Connect(function() if self.CurrentTab ~= tab then tab.Label.TextColor3 = C.Dim end end)
	btn.MouseLeave:Connect(function() if self.CurrentTab ~= tab then tab.Label.TextColor3 = C.Dimmer end end)

	-- scrolling moves the elements, so a popup anchored to one would be left behind
	self.Maid:Add(page:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if self.Popup then self:ClosePopup() end
	end))

	table.insert(self.Tabs, tab)
	if not self.CurrentTab then self:SelectTab(tab) end
	return tab
end

local TAB_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
function Window:SelectTab(tab)
	if type(tab) == "string" then
		for _, t in ipairs(self.Tabs) do if t.Name == tab then tab = t break end end
	end
	if type(tab) ~= "table" or self.CurrentTab == tab then return end
	self:ClosePopup()
	local prev = self.CurrentTab
	if prev then
		prev.Page.Visible = false
		prev.Label.TextColor3 = C.Dimmer
		prev.Recolor(C.IconDim)
	end
	self.CurrentTab = tab
	tab.Page.Visible = true
	tab.Label.TextColor3 = C.Text
	tab.Recolor(C.Accent)
	local hl, ind = self.SelHighlight, self.SelIndicator
	local hp, ip = UDim2.fromOffset(13, tab.Y - 10.5), UDim2.fromOffset(11, tab.Y - 7)
	if prev then
		TweenService:Create(hl, TAB_TWEEN, { Position = hp }):Play()
		TweenService:Create(ind, TAB_TWEEN, { Position = ip }):Play()
	else
		hl.Position, ind.Position = hp, ip
		hl.Visible, ind.Visible = true, true
	end
end

-- notifications -----------------------------------------------------------
local NOTE_W, NOTE_MAX = 260, 6
local NOTE_IN  = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local NOTE_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local function textHeight(text, font, size, width)
	local params = Instance.new("GetTextBoundsParams")
	params.Text, params.Font, params.Size, params.Width = text, font, size, width
	local ok, b = pcall(TextService.GetTextBoundsAsync, TextService, params)
	return (ok and b) and math.ceil(b.Y) or size + 2
end

-- Notify("text") or Notify({ Title = "...", Content = "...", Duration = 4 })
function Window:Notify(opts)
	if type(opts) ~= "table" then opts = { Content = tostring(opts) } end
	local title = tostring(opts.Title or self.Title)
	local content = tostring(opts.Content or opts.Text or "")
	local duration = tonumber(opts.Duration) or 4
	task.spawn(function()
		-- oldest one goes first when the stack is full
		while #self.Notes >= NOTE_MAX do
			local old = table.remove(self.Notes, 1)
			if old then old:Destroy() end
		end
		local innerW = NOTE_W - 24
		local titleH = textHeight(title, FONT.Bold, 14, innerW)
		local bodyH = content ~= "" and textHeight(content, FONT.Regular, 13, innerW) or 0
		local h = 10 + titleH + (bodyH > 0 and (3 + bodyH) or 0) + 12

		self.NoteCount = self.NoteCount + 1
		local slot = New("Frame", {
			Size = UDim2.fromOffset(NOTE_W, h), BackgroundTransparency = 1,
			LayoutOrder = self.NoteCount, Parent = self.NotifyHolder,
		})
		local card = Frame(slot, NOTE_W + 20, 0, NOTE_W, h, C.PanelBg)
		Round(card, 5); Stroke(card, C.PanelBorder, 1)
		Frame(card, 0, 0, 3, h, C.Accent)
		Label(card, 13, 9, innerW, titleH, title, 14, C.Title, FONT.Bold)
		if bodyH > 0 then
			local b = Label(card, 13, 9 + titleH + 3, innerW, bodyH, content, 13, C.Text, FONT.Regular)
			b.TextWrapped = true
			b.TextYAlignment = Enum.TextYAlignment.Top
		end
		local timer = Frame(card, 3, h - 2, NOTE_W - 3, 2, C.Accent)
		timer.BackgroundTransparency = 0.4
		table.insert(self.Notes, slot)

		TweenService:Create(card, NOTE_IN, { Position = UDim2.fromOffset(0, 0) }):Play()
		TweenService:Create(timer, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromOffset(0, 2) }):Play()
		task.wait(duration)
		if slot.Parent == nil then return end
		TweenService:Create(card, NOTE_OUT, { Position = UDim2.fromOffset(NOTE_W + 20, 0) }):Play()
		task.wait(NOTE_OUT.Time)
		local i = table.find(self.Notes, slot)
		if i then table.remove(self.Notes, i) end
		slot:Destroy()
	end)
end

function VisionWare:Notify(opts)
	local w = self.Windows[#self.Windows]
	if w then w:Notify(opts) end
end

-- configs -----------------------------------------------------------------
local function canFile()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function Window:_configPath(name)
	return self.ConfigFolder .. "/" .. tostring(name or "default") .. ".json"
end

function Window:_ensureFolder()
	if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(self.ConfigFolder) then
		makefolder(self.ConfigFolder)
	end
end

function Window:_ownsFlag(el)
	return el.Section ~= nil and el.Section.Window == self
end

-- every saveable value of this window, as a JSON-safe table
function Window:GetConfiguration()
	local out = {}
	for flag, el in pairs(VisionWare.Flags) do
		if el.Save and self:_ownsFlag(el) and el.CurrentValue ~= nil then
			local v = el.CurrentValue
			if typeof(v) == "Color3" then v = { __color = v:ToHex() } end
			out[flag] = v
		end
	end
	return out
end

function Window:ApplyConfiguration(data)
	if type(data) ~= "table" then return end
	for flag, v in pairs(data) do
		local el = VisionWare.Flags[flag]
		if el and el.Save and el.Set and self:_ownsFlag(el) then
			if type(v) == "table" and v.__color then
				local ok, col = pcall(Color3.fromHex, v.__color)
				v = ok and col or nil
			end
			if v ~= nil then safeCall(flag, el.Set, el, v) end
		end
	end
end

function Window:SaveConfiguration(name)
	if not canFile() then warn("[VisionWare] this executor cannot write files") return false end
	self:_ensureFolder()
	local ok, err = pcall(writefile, self:_configPath(name), HttpService:JSONEncode(self:GetConfiguration()))
	if not ok then warn("[VisionWare] save failed: " .. tostring(err)) end
	return ok
end

-- with no name, loads the auto-load config (if one is set). Call it after every
-- element has been created.
function Window:LoadConfiguration(name)
	if not canFile() then return false end
	if name == nil then
		name = self:GetAutoLoad()
		if not name then return false end
	end
	local path = self:_configPath(name)
	if not isfile(path) then return false end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
	if not ok then warn("[VisionWare] config is not valid JSON: " .. path) return false end
	self:ApplyConfiguration(data)
	return true
end

function Window:DeleteConfiguration(name)
	local path = self:_configPath(name)
	if canFile() and type(delfile) == "function" and isfile(path) then delfile(path) return true end
	return false
end

function Window:ListConfigurations()
	local names = {}
	if type(listfiles) ~= "function" or type(isfolder) ~= "function" or not isfolder(self.ConfigFolder) then return names end
	local ok, files = pcall(listfiles, self.ConfigFolder)
	if not ok then return names end
	for _, f in ipairs(files) do
		local n = tostring(f):match("([^/\\]+)%.json$")
		if n then names[#names + 1] = n end
	end
	table.sort(names)
	return names
end

function Window:GetAutoLoad()
	if not canFile() then return nil end
	local p = self.ConfigFolder .. "/autoload.txt"
	if not isfile(p) then return nil end
	local n = readfile(p)
	return n ~= "" and n or nil
end

function Window:SetAutoLoad(name)
	if not canFile() then return end
	self:_ensureFolder()
	writefile(self.ConfigFolder .. "/autoload.txt", name or "")
end

-- unload --------------------------------------------------------------------
function Window:OnUnload(fn) table.insert(self.OnUnloadFns, fn) end

function Window:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true
	self:ClosePopup()
	self.Listening = nil
	for _, fn in ipairs(self.OnUnloadFns) do safeCall("OnUnload", fn) end
	self.Maid:Clean()
	for flag, el in pairs(VisionWare.Flags) do
		if self:_ownsFlag(el) then VisionWare.Flags[flag] = nil end
	end
	local i = table.find(VisionWare.Windows, self)
	if i then table.remove(VisionWare.Windows, i) end
end

function VisionWare:Destroy()
	for i = #self.Windows, 1, -1 do self.Windows[i]:Destroy() end
	if env.VisionWareUI == self then env.VisionWareUI = nil end
end

---------------------------------------------------------------------------
-- Tab: sections stack in two columns (or full width); the page scrolls
---------------------------------------------------------------------------
-- column bottoms without moving anything (used to pick a side)
function Tab:_columnHeights()
	local yL, yR = PAGE_TOP, PAGE_TOP
	for _, s in ipairs(self.Sections) do
		if s.Visible then
			if s.Side == "Full" then
				local y = math.max(yL, yR) + s.Height + PANEL_GAP
				yL, yR = y, y
			elseif s.Side == "Left" then yL = yL + s.Height + PANEL_GAP
			else yR = yR + s.Height + PANEL_GAP end
		end
	end
	return yL, yR
end

function Tab:_layout()
	self.LayoutQueued = false
	local yL, yR = PAGE_TOP, PAGE_TOP
	for _, s in ipairs(self.Sections) do
		if s.Visible then
			local y
			if s.Side == "Full" then
				y = math.max(yL, yR)
				yL, yR = y + s.Height + PANEL_GAP, y + s.Height + PANEL_GAP
			elseif s.Side == "Left" then
				y = yL; yL = yL + s.Height + PANEL_GAP
			else
				y = yR; yR = yR + s.Height + PANEL_GAP
			end
			s.Frame.Position = UDim2.fromOffset(s.M.X, y)
		end
	end
	self.Page.CanvasSize = UDim2.fromOffset(0, math.max(yL, yR) - PANEL_GAP + 6)
end

-- many elements are usually added in one go: lay the tab out once, after them
function Tab:_queueLayout()
	if self.LayoutQueued then return end
	self.LayoutQueued = true
	task.defer(self._layout, self)
end

-- CreateSection("Name") or CreateSection({ Name, Side = "Left"|"Right"|"Full",
-- Toggle = true, Default = true, Flag, Callback, Icon })
function Tab:CreateSection(opts)
	if type(opts) ~= "table" then opts = { Name = tostring(opts or "Section") } end
	local side = opts.Side
	if side == "L" or side == "left" then side = "Left" elseif side == "R" or side == "right" then side = "Right" end
	if side ~= "Left" and side ~= "Right" and side ~= "Full" then
		local yL, yR = self:_columnHeights()
		side = (yR < yL) and "Right" or "Left"
	end
	local M = METRICS[side]
	local s = setmetatable({
		Tab = self, Window = self.Window, Name = tostring(opts.Name or "Section"), Side = side, M = M,
		Rows = 0, Height = panelHeight(0), Enabled = true, Visible = true, TextBoxes = {},
	}, Section)

	local frame = Frame(self.Page, M.X, PAGE_TOP, M.W, s.Height, C.PanelBg)
	Round(frame, 3)
	Stroke(frame, C.PanelBorder, 1)
	s.Frame = frame
	Frame(frame, 0, HEADER_H, M.W, 1, C.Separator)

	-- title, with an optional icon right after the text
	local titleRow = New("Frame", {
		Position = UDim2.fromOffset(M.PadLeft, HEADER_H / 2 - 7), Size = UDim2.fromOffset(M.W - M.PadLeft - 34, 14),
		BackgroundTransparency = 1, Parent = frame,
	})
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = titleRow,
	})
	local title = New("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), BackgroundTransparency = 1,
		Text = s.Name, TextSize = TS.Title, TextColor3 = C.Title, FontFace = FONT.Bold, LayoutOrder = 1, Parent = titleRow,
	})
	Stroke(title, Color3.fromRGB(255, 255, 255), 1, 0.88)
	s.TitleLabel = title
	if opts.Icon then
		local ic = MakeIcon(titleRow, opts.Icon, 0, 0, 11, C.Accent)
		ic.LayoutOrder = 2
	end

	-- optional master switch in the header: when off, a veil dims the rows and
	-- swallows every click until it is switched back on
	if opts.Toggle then
		local tw, th = M.ToggleW, 8
		local titleY = HEADER_H / 2
		local toggle = Frame(frame, M.W - M.ToggleInset - tw, titleY - th / 2, tw, th, C.Accent)
		Round(toggle)
		local knob = Circle(toggle, tw - 4, th / 2, 5, Color3.fromRGB(255, 255, 255))
		local veil = New("Frame", {
			Position = UDim2.fromOffset(0, HEADER_H + 1), Size = UDim2.fromOffset(M.W, s.Height - HEADER_H - 1),
			BackgroundColor3 = C.PanelBg, BackgroundTransparency = 0.45, BorderSizePixel = 0,
			Active = true, Visible = false, ZIndex = 50, Parent = frame,
		})
		Round(veil, 3)
		s.Veil = veil

		local el = setmetatable({ Type = "SectionToggle" }, Element)
		s:_register(el, { Name = s.Name .. " (section)", Flag = opts.Flag, Callback = opts.Callback, Save = opts.Save }, "Enabled")
		local function apply(v, silent)
			v = v and true or false
			if v == s.Enabled and el.CurrentValue ~= nil then return end
			s.Enabled = v
			toggle.BackgroundColor3 = v and C.Accent or C.ToggleOff
			knob.Position = UDim2.fromOffset(v and (tw - 4) or 4, th / 2)
			veil.Visible = not v
			for _, tb in ipairs(s.TextBoxes) do
				tb.TextEditable = v
				if not v and tb:IsFocused() then tb:ReleaseFocus() end
			end
			if not v then
				local w = s.Window
				if w.Popup and w.Popup.Owner == s then w:ClosePopup() end
			end
			if silent then el.CurrentValue = v else el:_fire(v) end
		end
		apply(opts.Default ~= false, true)
		local tbtn = Button(frame, M.W - M.ToggleInset - tw - 3, titleY - th / 2 - 3, tw + 6, th + 6)
		tbtn.MouseButton1Click:Connect(function() apply(not s.Enabled) end)
		el.Set = function(a, b) apply(argOf(el, a, b)) end
		s.Toggle = el
	end

	table.insert(self.Sections, s)
	self.CurrentSection = s
	self:_queueLayout()
	return s
end

-- Rayfield style: Tab:CreateToggle(...) adds to the last section of the tab
-- (a section named after the tab is made if there is none yet)
function Tab:_section()
	return self.CurrentSection or self:CreateSection({ Name = self.Name })
end
for _, name in ipairs({
	"CreateToggle", "CreateCheckbox", "CreateSlider", "CreateDropdown", "CreateButton", "CreateKeybind",
	"CreateColorPicker", "CreateInput", "CreateLabel", "CreateInfo", "CreateParagraph", "CreateList", "CreateDivider",
}) do
	Tab[name] = function(self, ...)
		local s = self:_section()
		return s[name](s, ...)
	end
end

-- ready-made sections --------------------------------------------------------
-- Menu: menu key, scale, background effect, unload
function Tab:CreateMenuSection(opts)
	opts = opts or {}
	local w = self.Window
	local s = self:CreateSection({ Name = opts.Name or "Menu", Side = opts.Side })
	s:CreateKeybind({
		Name = "Menu Key", CurrentKeybind = w.ToggleKey, Flag = opts.KeyFlag or "VisionWare/MenuKey",
		AllowNone = false, NoBind = true,
		ChangedCallback = function(k) w:SetToggleKey(k) end,
	})
	s:CreateSlider({
		Name = "Menu Scale", Range = { 1, 3 }, Increment = 0.1, CurrentValue = w.Scale, Save = false,
		Callback = function(v) w:SetScale(v) end,
	})
	if w._setBackdrop then
		s:CreateToggle({
			Name = "Background Effect", CurrentValue = w.BackdropOn, Flag = "VisionWare/Backdrop",
			Callback = function(v) w:SetBackdrop(v) end,
		})
	end
	s:CreateButton({ Name = "Unload Menu", Callback = function() w:Destroy() end })
	return s
end

-- Configs: name box, saved list, save / load / delete, auto load
function Tab:CreateConfigSection(opts)
	opts = opts or {}
	local w = self.Window
	local s = self:CreateSection({ Name = opts.Name or "Configs", Side = opts.Side })
	if not canFile() then
		s:CreateLabel("This executor cannot save files")
		return s
	end
	local auto = w:GetAutoLoad()
	local nameBox = s:CreateInput({ Name = "Config Name", CurrentValue = auto or "default", Save = false })
	local function current()
		local n = nameBox.CurrentValue
		return (n ~= nil and n ~= "") and n or "default"
	end
	local saved = s:CreateDropdown({
		Name = "Saved Configs", Options = w:ListConfigurations(), CurrentOption = auto, Save = false,
		Callback = function(o) if o then nameBox:Set(o) end end,
	})
	local autoToggle
	local function refresh()
		saved:Refresh(w:ListConfigurations(), true)
		autoToggle:Set(w:GetAutoLoad() == current(), true)
	end
	s:CreateButton({ Name = "Save Config", Callback = function()
		if w:SaveConfiguration(current()) then w:Notify({ Title = "Config", Content = "Saved \"" .. current() .. "\"" }) end
		refresh()
	end })
	s:CreateButton({ Name = "Load Config", Callback = function()
		if w:LoadConfiguration(current()) then
			w:Notify({ Title = "Config", Content = "Loaded \"" .. current() .. "\"" })
		else
			w:Notify({ Title = "Config", Content = "No config called \"" .. current() .. "\"" })
		end
	end })
	s:CreateButton({ Name = "Delete Config", Callback = function()
		if w:DeleteConfiguration(current()) then
			if w:GetAutoLoad() == current() then w:SetAutoLoad(nil) end
			w:Notify({ Title = "Config", Content = "Deleted \"" .. current() .. "\"" })
		end
		refresh()
	end })
	autoToggle = s:CreateToggle({ Name = "Auto Load This Config", CurrentValue = auto ~= nil and auto == current(), Save = false,
		Callback = function(v)
			if v then w:SetAutoLoad(current()) elseif w:GetAutoLoad() == current() then w:SetAutoLoad(nil) end
		end })
	nameBox:OnChanged(function() autoToggle:Set(w:GetAutoLoad() == current(), true) end)
	return s
end

---------------------------------------------------------------------------
-- Section
---------------------------------------------------------------------------
function Section:_register(el, opts, key)
	el.Section = self
	el.Name = opts.Name
	el.Callback = opts.Callback
	el.Save = opts.Save ~= false
	local flag = opts.Flag
	if flag == nil then
		flag = self.Tab.Name .. "/" .. self.Name .. "/" .. tostring(key or opts.Name)
		if VisionWare.Flags[flag] then
			local i = 2
			while VisionWare.Flags[flag .. "#" .. i] do i = i + 1 end
			flag = flag .. "#" .. i
		end
	end
	el.Flag = flag
	VisionWare.Flags[flag] = el
	return el
end

function Section:_locked() return self.Enabled == false end

function Section:_nextRow()
	local y = ROW_START + self.Rows * ROW_GAP
	self.Rows = self.Rows + 1
	local h = panelHeight(self.Rows)
	if h ~= self.Height then
		self.Height = h
		self.Frame.Size = UDim2.fromOffset(self.M.W, h)
		if self.Veil then self.Veil.Size = UDim2.fromOffset(self.M.W, h - HEADER_H - 1) end
		self.Tab:_queueLayout()
	end
	return y
end

function Section:_rightEdge() return self.M.W - self.M.PadRight end

-- row label; `reserve` = width kept free on the right for the control
function Section:_label(text, y, bright, reserve)
	local M = self.M
	local l = Label(self.Frame, M.PadLeft, y - 6, M.W - M.PadLeft - M.PadRight - (reserve or 0) - 3, 12,
		tostring(text or ""), TS.Row, bright and C.Text or C.Dim, FONT.Medium)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	return l
end

function Section:SetVisible(v)
	v = v and true or false
	if self.Visible == v then return end
	self.Visible = v
	self.Frame.Visible = v
	if not v and self.Window.Popup and self.Window.Popup.Owner == self then self.Window:ClosePopup() end
	self.Tab:_queueLayout()
end

function Section:SetEnabled(v) if self.Toggle then self.Toggle:Set(v) end end

function Section:SetTitle(text)
	self.Name = tostring(text)
	self.TitleLabel.Text = self.Name
end

-- Toggle ----------------------------------------------------------------------
-- { Name, CurrentValue = false, Flag, Callback(bool), Save }
-- Set(value, silent): silent = true changes it without running the callback
function Section:CreateToggle(opts)
	opts = type(opts) == "table" and opts or { Name = opts }
	local el = setmetatable({ Type = "Toggle" }, Element)
	self:_register(el, opts)
	local y = self:_nextRow()
	local lbl = self:_label(opts.Name, y, false, 8)
	local box = Frame(self.Frame, self:_rightEdge() - 6, y - 3, 6, 6, C.DropBg)
	Round(box, 2)
	local state
	local function apply(v, silent)
		v = v and true or false
		if v == state then return end
		state = v
		box.BackgroundColor3 = v and C.Accent or C.DropBg
		lbl.TextColor3 = v and C.Text or C.Dim
		if silent then el.CurrentValue = v else el:_fire(v) end
	end
	apply(opts.CurrentValue == true, true)
	local btn = Button(self.Frame, 0, y - 5.5, self.M.W, 11)
	btn.MouseButton1Click:Connect(function()
		if self:_locked() then return end
		apply(not state)
	end)
	el.Set = function(a, b, c)
		if a == el then apply(b, c) else apply(a, b) end
	end
	return el
end
Section.CreateCheckbox = Section.CreateToggle

-- Slider ------------------------------------------------------------------------
-- { Name, Range = {min, max}, Increment = 1, CurrentValue, Suffix, Flag, Callback(number) }
function Section:CreateSlider(opts)
	opts = opts or {}
	local el = setmetatable({ Type = "Slider" }, Element)
	self:_register(el, opts)
	local range = opts.Range or { opts.Min or 0, opts.Max or 100 }
	local min, max = range[1], range[2]
	local inc = tonumber(opts.Increment) or 1
	local decimals = 0
	do
		local s = tostring(inc)
		local dot = s:find("%.")
		if dot then decimals = #s - dot end
	end
	local fmt = "%." .. decimals .. "f"
	local suffix = opts.Suffix and opts.Suffix ~= "" and (" " .. opts.Suffix) or ""

	local y = self:_nextRow()
	local w = self.M.SliderW
	self:_label(opts.Name, y, false, w + 4)
	local track = Frame(self.Frame, self:_rightEdge() - w, y - 2, w, 4, C.Track)
	Round(track)
	Stroke(track, C.TrackStroke, 1)
	local fill = Frame(track, 0, 0, 0, 4, C.Accent)
	Round(fill)
	-- the number sits just left of the track, right-aligned so it grows leftwards
	local readout = Label(self.Frame, self:_rightEdge() - w - 25, y - 6, 22, 12, "", TS.Key, C.Text, FONT.Medium, Enum.TextXAlignment.Right)

	local value
	local function apply(v, silent)
		v = tonumber(v) or min
		v = math.clamp(v, min, max)
		if inc > 0 then v = math.clamp(min + math.floor((v - min) / inc + 0.5) * inc, min, max) end
		v = tonumber(string.format(fmt, v))
		if v == value then return end
		value = v
		readout.Text = string.format(fmt, v) .. suffix
		fill.Size = UDim2.fromOffset(max > min and w * (v - min) / (max - min) or 0, 4)
		if silent then el.CurrentValue = v else el:_fire(v) end
	end
	apply(opts.CurrentValue or opts.Default or min, true)

	local hit = Button(self.Frame, self:_rightEdge() - w - 3, y - 6, w + 6, 12)
	local function update()
		local frac = (UIS:GetMouseLocation().X - track.AbsolutePosition.X) / track.AbsoluteSize.X
		apply(min + math.clamp(frac, 0, 1) * (max - min))
	end
	hit.InputBegan:Connect(function(input)
		if self:_locked() or not isPointer(input) then return end
		self.Window.Drag = update
		update()
	end)
	el.Set = function(a, b, c)
		if a == el then apply(b, c) else apply(a, b) end
	end
	return el
end

-- Dropdown ------------------------------------------------------------------------
-- { Name, Options = {...}, CurrentOption, MultipleOptions = false, Flag, Callback }
-- single: value / callback is the chosen string; multi: a table of strings.
-- Refresh(options, keepSelection) replaces the options.
local DROP_MAX_ROWS = 8
function Section:CreateDropdown(opts)
	opts = opts or {}
	local el = setmetatable({ Type = "Dropdown" }, Element)
	self:_register(el, opts)
	local multi = opts.MultipleOptions == true
	local options = table.clone(opts.Options or {})

	local current
	if multi then
		current = {}
		local init = opts.CurrentOption
		if type(init) == "string" then init = { init } end
		for _, o in ipairs(init or {}) do table.insert(current, o) end
	else
		current = opts.CurrentOption
		if type(current) == "table" then current = current[1] end
	end

	local y = self:_nextRow()
	local w, h = self.M.SliderW, DROP_ROW_H
	self:_label(opts.Name, y, false, w)
	local box = Frame(self.Frame, self:_rightEdge() - w, y - h / 2, w, h, C.DropBg)
	Round(box, 2)
	local valLabel = Label(box, 3, 0, w - 11, h, "", DROP_TEXT_SIZE, C.DropText, FONT.Regular)
	valLabel.TextTruncate = Enum.TextTruncate.AtEnd
	-- small "v" chevron drawn with two bars (no glyph, so it works with every font)
	Bar(box, w - 5.6, h / 2, 2.6, 0.8, 45, C.DropText)
	Bar(box, w - 4, h / 2, 2.6, 0.8, -45, C.DropText)

	local popup, rows, search
	local function isSelected(o)
		if multi then return table.find(current, o) ~= nil end
		return current == o
	end
	local function display()
		local text
		if multi then text = #current == 0 and "None" or table.concat(current, ", ")
		else text = current ~= nil and tostring(current) or "None" end
		valLabel.Text = text
		valLabel.TextColor3 = (multi and #current > 0 or (not multi and current ~= nil)) and C.Text or C.DropText
	end
	local function paint()
		if not rows then return end
		for i = 1, #rows do
			local r = rows[i]
			r.Label.TextColor3 = isSelected(r.Option) and C.Text or C.DropText
			r.Tick.Visible = isSelected(r.Option)
		end
	end
	local function choose(o)
		if multi then
			local i = table.find(current, o)
			if i then table.remove(current, i) else table.insert(current, o) end
			display(); paint()
			el:_fire(table.clone(current))
		else
			current = o
			display(); paint()
			self.Window:ClosePopup()
			el:_fire(o)
		end
	end
	-- positions the rows that match the search text
	local function filter(list)
		local q = search and search.Text:lower() or ""
		local k = 0
		for i = 1, #rows do
			local r = rows[i]
			local show = q == "" or tostring(r.Option):lower():find(q, 1, true) ~= nil
			r.Button.Visible = show
			if show then r.Button.Position = UDim2.fromOffset(0, k * h); k = k + 1 end
		end
		list.CanvasSize = UDim2.fromOffset(0, k * h)
	end
	local function build()
		if popup then popup:Destroy() end
		local n = #options
		local visible = math.clamp(n, 1, DROP_MAX_ROWS)
		local searchH = n > DROP_MAX_ROWS and (h + 2) or 0
		local pw = math.max(w, 60)
		popup = New("Frame", {
			Size = UDim2.fromOffset(pw, visible * h + 2 + searchH), BackgroundColor3 = C.DropBg,
			BorderSizePixel = 0, Visible = false, ZIndex = 2, Parent = self.Window.PopupLayer,
		})
		Round(popup, 2)
		Stroke(popup, C.PanelBorder, 1)
		local list = New("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 1 + searchH), Size = UDim2.fromOffset(pw, visible * h),
			BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 1.5, ScrollBarImageColor3 = C.Dim,
			CanvasSize = UDim2.fromOffset(0, n * h), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = popup,
		})
		if searchH > 0 then
			local sb = Frame(popup, 2, 2, pw - 4, h, C.Track)
			Round(sb, 2)
			search = New("TextBox", {
				Position = UDim2.fromOffset(3, 0), Size = UDim2.fromOffset(pw - 10, h), BackgroundTransparency = 1,
				Text = "", PlaceholderText = "Search...", PlaceholderColor3 = C.DropText, TextColor3 = C.Text,
				TextSize = DROP_TEXT_SIZE, FontFace = FONT.Regular, TextXAlignment = Enum.TextXAlignment.Left,
				ClearTextOnFocus = false, Parent = sb,
			})
			search:GetPropertyChangedSignal("Text"):Connect(function() filter(list) end)
		else
			search = nil
		end
		rows = {}
		for i, o in ipairs(options) do
			local b = Button(list, 0, (i - 1) * h, pw, h)
			b.BackgroundColor3 = C.Hover
			local l = Label(b, 3, 0, pw - 12, h, tostring(o), DROP_TEXT_SIZE, C.DropText, FONT.Regular)
			l.TextTruncate = Enum.TextTruncate.AtEnd
			local tick = Frame(b, pw - 7, h / 2 - 1.5, 3, 3, C.Accent)
			Round(tick)
			b.MouseEnter:Connect(function() b.BackgroundTransparency = 0.4 end)
			b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
			b.MouseButton1Click:Connect(function() choose(o) end)
			rows[i] = { Option = o, Button = b, Label = l, Tick = tick }
		end
		if n == 0 then
			Label(list, 3, 0, pw - 6, h, "No options", DROP_TEXT_SIZE, C.DropText, FONT.Regular)
		end
	end

	display()
	el.CurrentValue = multi and table.clone(current) or current

	local btn = Button(self.Frame, self:_rightEdge() - w, y - 5, w, 10)
	btn.MouseEnter:Connect(function() box.BackgroundColor3 = C.Hover end)
	btn.MouseLeave:Connect(function() box.BackgroundColor3 = C.DropBg end)
	btn.MouseButton1Click:Connect(function()
		if self:_locked() then return end
		if not popup then build() end
		if search then search.Text = "" end
		paint()
		self.Window:OpenPopup(popup, box, self)
	end)

	el.Set = function(a, b)
		local v = argOf(el, a, b)
		if multi then
			if type(v) == "string" then v = { v } end
			current = {}
			for _, o in ipairs(v or {}) do table.insert(current, o) end
			display(); paint()
			el:_fire(table.clone(current))
		else
			if type(v) == "table" then v = v[1] end
			current = v
			display(); paint()
			el:_fire(v)
		end
	end
	el.Refresh = function(a, b, c)
		local newOptions, keep = a, b
		if a == el then newOptions, keep = b, c end
		options = table.clone(newOptions or {})
		if multi then
			local kept = {}
			if keep then for _, o in ipairs(current) do if table.find(options, o) then table.insert(kept, o) end end end
			current = kept
		elseif not keep or not table.find(options, current) then
			current = nil
		end
		if popup then
			if self.Window.Popup and self.Window.Popup.Frame == popup then self.Window:ClosePopup() end
			popup:Destroy(); popup = nil; rows = nil
		end
		display()
		el.CurrentValue = multi and table.clone(current) or current
	end
	el.GetOptions = function() return table.clone(options) end
	return el
end

-- Keybind -----------------------------------------------------------------------
-- { Name, CurrentKeybind = "Q", HoldToInteract = false, Flag, Callback, ChangedCallback(key) }
-- Callback runs when the key is pressed (HoldToInteract: Callback(true) on press,
-- Callback(false) on release). Click the key to rebind; Escape cancels,
-- Backspace clears. Keys: KeyCode names or "Mouse 1" / "Mouse 2" / "Mouse 3".
function Section:CreateKeybind(opts)
	opts = opts or {}
	local el = setmetatable({ Type = "Keybind" }, Element)
	self:_register(el, opts)
	el.Callback = nil       -- the press callback is not a value-change callback
	local pressCallback = opts.Callback
	local hold = opts.HoldToInteract == true
	local allowNone = opts.AllowNone ~= false
	local win = self.Window

	local y = self:_nextRow()
	self:_label(opts.Name, y, false, 42)
	local keyLbl = Label(self.Frame, self:_rightEdge() - 40, y - 6, 40, 12, "", TS.Key, C.DropText, FONT.Regular, Enum.TextXAlignment.Right)

	local key = "None"
	local function unbind()
		local list = win.Binds[key]
		if list then
			local i = table.find(list, el)
			if i then table.remove(list, i) end
			if #list == 0 then win.Binds[key] = nil end
		end
	end
	local function setKey(k, silent)
		k = keyName(k)
		if k == "None" and not allowNone then return end
		if not opts.NoBind then unbind() end
		key = k
		keyLbl.Text = k
		if k ~= "None" and not opts.NoBind then
			win.Binds[k] = win.Binds[k] or {}
			table.insert(win.Binds[k], el)
		end
		el.CurrentValue = k
		if not silent then
			if opts.ChangedCallback then safeCall(opts.Name, opts.ChangedCallback, k) end
			local l = el.Listeners
			if l then for i = 1, #l do safeCall(opts.Name, l[i], k) end end
		end
	end
	setKey(opts.CurrentKeybind or opts.Default or "None", true)
	if opts.ChangedCallback and key ~= "None" then safeCall(opts.Name, opts.ChangedCallback, key) end

	function el:_press()
		if self.Section:_locked() then return end
		if hold then
			self.Held = true
			safeCall(opts.Name, pressCallback, true)
		else
			safeCall(opts.Name, pressCallback, key)
		end
	end
	function el:_release()
		if hold then safeCall(opts.Name, pressCallback, false) end
	end

	local btn = Button(self.Frame, self:_rightEdge() - 40, y - 6, 40, 12)
	btn.MouseEnter:Connect(function() if win.Listening == nil then keyLbl.TextColor3 = C.Text end end)
	btn.MouseLeave:Connect(function() if win.Listening == nil then keyLbl.TextColor3 = C.DropText end end)
	btn.MouseButton1Click:Connect(function()
		if self:_locked() or win.Listening then return end
		keyLbl.Text = "..."
		keyLbl.TextColor3 = C.AccentText
		win.Listening = function(input)
			local t = input.UserInputType
			local name
			if t == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then name = key
				elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
					name = allowNone and "None" or key
				else name = inputName(input) end
			else
				name = inputName(input)
			end
			if not name then return end        -- not a key or mouse button: keep listening
			win.Listening = nil
			keyLbl.TextColor3 = C.DropText
			if name == key then keyLbl.Text = key else setKey(name) end
		end
	end)

	el.Set = function(a, b) setKey(argOf(el, a, b)) end
	return el
end

-- ColorPicker -------------------------------------------------------------------
-- { Name, Color = Color3, Flag, Callback(Color3) }. Click the swatch for a
-- saturation / value square, a hue bar and a hex box.
local HUE_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0,     Color3.fromHSV(0, 1, 1)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
	ColorSequenceKeypoint.new(1,     Color3.fromHSV(1, 1, 1)),
})
function Section:CreateColorPicker(opts)
	opts = opts or {}
	local el = setmetatable({ Type = "ColorPicker" }, Element)
	self:_register(el, opts)
	local color = opts.Color or opts.Default or C.Accent
	local hue, sat, val = color:ToHSV()

	local y = self:_nextRow()
	self:_label(opts.Name, y, true, 10)
	local swatch = Circle(self.Frame, self:_rightEdge() - 3.5, y, 7, color)
	local ring = Stroke(swatch, C.TrackStroke, 1)

	local popup, sv, svCursor, hueCursor, hexBox, preview
	local SV_W, SV_H, PW, PH = 82, 50, 92, 80

	local function paintPopup()
		if not popup then return end
		sv.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		svCursor.Position = UDim2.fromOffset(sat * SV_W, (1 - val) * SV_H)
		hueCursor.Position = UDim2.fromOffset(hue * SV_W, 2.5)
		preview.BackgroundColor3 = color
		if not hexBox:IsFocused() then hexBox.Text = "#" .. color:ToHex():upper() end
	end
	local function commit(silent)
		color = Color3.fromHSV(hue, sat, val)
		swatch.BackgroundColor3 = color
		paintPopup()
		if silent then el.CurrentValue = color else el:_fire(color) end
	end
	local function setColor(c, silent)
		if typeof(c) ~= "Color3" then return end
		hue, sat, val = c:ToHSV()
		commit(silent)
	end

	local function build()
		popup = New("Frame", {
			Size = UDim2.fromOffset(PW, PH), BackgroundColor3 = C.DropBg, BorderSizePixel = 0,
			Visible = false, ZIndex = 2, Parent = self.Window.PopupLayer,
		})
		Round(popup, 3)
		Stroke(popup, C.PanelBorder, 1)

		sv = Frame(popup, 5, 5, SV_W, SV_H, Color3.fromHSV(hue, 1, 1))
		Round(sv, 2)
		local white = Frame(sv, 0, 0, SV_W, SV_H, Color3.new(1, 1, 1))
		Round(white, 2)
		New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
		local black = Frame(sv, 0, 0, SV_W, SV_H, Color3.new(0, 0, 0))
		Round(black, 2)
		New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
		svCursor = Circle(sv, 0, 0, 4, Color3.new(1, 1, 1))
		svCursor.BackgroundTransparency = 1
		Stroke(svCursor, Color3.new(1, 1, 1), 1)

		local hueBar = Frame(popup, 5, 59, SV_W, 5, Color3.new(1, 1, 1))
		Round(hueBar, 2)
		New("UIGradient", { Color = HUE_SEQUENCE, Parent = hueBar })
		hueCursor = New("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 7),
			BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = hueBar,
		})
		Round(hueCursor, 1)

		local hexBg = Frame(popup, 5, 68, 58, 8, C.Track)
		Round(hexBg, 2)
		hexBox = New("TextBox", {
			Position = UDim2.fromOffset(3, 0), Size = UDim2.fromOffset(52, 8), BackgroundTransparency = 1,
			Text = "", TextColor3 = C.Text, TextSize = DROP_TEXT_SIZE, FontFace = FONT.Mono,
			TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = hexBg,
		})
		hexBox.FocusLost:Connect(function()
			local ok, c = pcall(Color3.fromHex, (hexBox.Text:gsub("[^%x]", "")))
			if ok and c then setColor(c) else paintPopup() end
		end)
		preview = Frame(popup, 66, 68, 21, 8, color)
		Round(preview, 2)

		local svHit = Button(popup, 5, 5, SV_W, SV_H)
		local hueHit = Button(popup, 5, 57, SV_W, 9)
		local function svUpdate()
			local m = UIS:GetMouseLocation()
			local p, s = sv.AbsolutePosition, sv.AbsoluteSize
			sat = math.clamp((m.X - p.X) / s.X, 0, 1)
			val = 1 - math.clamp((m.Y - p.Y) / s.Y, 0, 1)
			commit()
		end
		local function hueUpdate()
			local m = UIS:GetMouseLocation()
			local p, s = hueBar.AbsolutePosition, hueBar.AbsoluteSize
			hue = math.clamp((m.X - p.X) / s.X, 0, 0.999)
			commit()
		end
		svHit.InputBegan:Connect(function(input)
			if not isPointer(input) then return end
			self.Window.Drag = svUpdate
			svUpdate()
		end)
		hueHit.InputBegan:Connect(function(input)
			if not isPointer(input) then return end
			self.Window.Drag = hueUpdate
			hueUpdate()
		end)
	end

	el.CurrentValue = color
	local btn = Button(self.Frame, self:_rightEdge() - 10, y - 5, 10, 10)
	btn.MouseEnter:Connect(function() ring.Color = C.Text end)
	btn.MouseLeave:Connect(function() ring.Color = C.TrackStroke end)
	btn.MouseButton1Click:Connect(function()
		if self:_locked() then return end
		if not popup then build() end
		paintPopup()
		self.Window:OpenPopup(popup, swatch, self)
	end)

	el.Set = function(a, b, c)
		if a == el then setColor(b, c) else setColor(a, b) end
	end
	return el
end

-- Button --------------------------------------------------------------------------
-- { Name, Callback() }. Set(text) renames it.
function Section:CreateButton(opts)
	opts = type(opts) == "table" and opts or { Name = opts }
	local el = setmetatable({ Type = "Button", Name = opts.Name, Section = self }, Element)
	local y = self:_nextRow()
	local M = self.M
	local w = self:_rightEdge() - M.PadLeft
	local box = Frame(self.Frame, M.PadLeft, y - 4.5, w, 9, C.DropBg)
	Round(box, 2)
	local stroke = Stroke(box, C.PanelBorder, 1)
	local lbl = Label(box, 0, 0, w, 9, tostring(opts.Name or "Button"), TS.Row, C.Text, FONT.Medium, Enum.TextXAlignment.Center)
	local btn = Button(self.Frame, M.PadLeft, y - 5.5, w, 11)
	btn.MouseEnter:Connect(function() stroke.Color = C.Accent end)
	btn.MouseLeave:Connect(function() stroke.Color = C.PanelBorder; box.BackgroundColor3 = C.DropBg end)
	btn.MouseButton1Down:Connect(function() box.BackgroundColor3 = C.Hover end)
	btn.MouseButton1Up:Connect(function() box.BackgroundColor3 = C.DropBg end)
	btn.MouseButton1Click:Connect(function()
		if self:_locked() then return end
		safeCall(opts.Name, opts.Callback)
	end)
	el.Set = function(a, b) lbl.Text = tostring(argOf(el, a, b)) end
	el.SetText = el.Set
	el.Fire = function() safeCall(opts.Name, opts.Callback) end
	return el
end

-- Input ---------------------------------------------------------------------------
-- { Name, CurrentValue = "", PlaceholderText, NumbersOnly, RemoveTextAfterFocusLost,
--   Flag, Callback(text) }. The callback runs when the box loses focus.
function Section:CreateInput(opts)
	opts = opts or {}
	local el = setmetatable({ Type = "Input" }, Element)
	self:_register(el, opts)
	local y = self:_nextRow()
	local w = self.M.SliderW
	self:_label(opts.Name, y, false, w)
	local box = Frame(self.Frame, self:_rightEdge() - w, y - 4, w, 8, C.DropBg)
	Round(box, 2)
	local stroke = Stroke(box, C.PanelBorder, 1)
	stroke.Transparency = 1
	local tb = New("TextBox", {
		Position = UDim2.fromOffset(3, 0), Size = UDim2.fromOffset(w - 6, 8), BackgroundTransparency = 1,
		Text = tostring(opts.CurrentValue or ""), PlaceholderText = opts.PlaceholderText or "",
		PlaceholderColor3 = C.DropText, TextSize = DROP_TEXT_SIZE, TextColor3 = C.Text, FontFace = FONT.Regular,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ClipsDescendants = true, Parent = box,
	})
	table.insert(self.TextBoxes, tb)
	el.CurrentValue = tb.Text
	if opts.NumbersOnly then
		tb:GetPropertyChangedSignal("Text"):Connect(function()
			local clean = tb.Text:gsub("[^%d%.%-]", "")
			if clean ~= tb.Text then tb.Text = clean end
		end)
	end
	tb.Focused:Connect(function() stroke.Transparency = 0; stroke.Color = C.Accent end)
	tb.FocusLost:Connect(function()
		stroke.Transparency = 1
		if self:_locked() then tb.Text = el.CurrentValue or ""; return end
		local text = tb.Text
		if opts.RemoveTextAfterFocusLost then tb.Text = "" end
		el:_fire(text)
	end)
	el.Set = function(a, b)
		local v = tostring(argOf(el, a, b) or "")
		tb.Text = v
		el:_fire(v)
	end
	return el
end

-- Label ---------------------------------------------------------------------------
-- CreateLabel("text") or { Text, Color }. Set(text).
function Section:CreateLabel(opts)
	opts = type(opts) == "table" and opts or { Text = opts }
	local y = self:_nextRow()
	local l = self:_label(opts.Text or opts.Name or "", y, true)
	if opts.Color then l.TextColor3 = opts.Color end
	local el = { Type = "Label", Instance = l }
	el.Set = function(a, b)
		local v = argOf(el, a, b)
		l.Text = tostring(v or "")
	end
	return el
end

-- Info: dim name on the left, value on the right. { Name, Value }. Set(value).
function Section:CreateInfo(opts)
	opts = type(opts) == "table" and opts or { Name = opts }
	local y = self:_nextRow()
	local w = self.M.SliderW
	self:_label(opts.Name, y, false, w)
	local v = Label(self.Frame, self:_rightEdge() - w, y - 6, w, 12, tostring(opts.Value or ""), TS.Row, C.Text, FONT.Medium, Enum.TextXAlignment.Right)
	v.TextTruncate = Enum.TextTruncate.AtEnd
	local el = { Type = "Info", Instance = v }
	el.Set = function(a, b) v.Text = tostring(argOf(el, a, b) or "") end
	return el
end

-- Paragraph: optional title row, then a wrapped text box `Lines` rows tall.
-- { Title, Content, Lines = 3, Mono = false }. Set(content) or Set({ Title, Content }).
function Section:CreateParagraph(opts)
	opts = type(opts) == "table" and opts or { Content = opts }
	local titleLbl
	if opts.Title then
		local ty = self:_nextRow()
		titleLbl = self:_label(opts.Title, ty, true)
	end
	local lines = math.max(tonumber(opts.Lines) or 3, 1)
	local y0 = self:_nextRow()
	for _ = 2, lines do self:_nextRow() end
	local M = self.M
	local w = self:_rightEdge() - M.PadLeft
	local h = (lines - 1) * ROW_GAP + 10
	local box = Frame(self.Frame, M.PadLeft, y0 - 5, w, h, C.DropBg)
	Round(box, 2)
	Stroke(box, C.PanelBorder, 1)
	local lbl = Label(box, 3, 1, w - 6, h - 2, tostring(opts.Content or ""), TS.Drop, C.DropText, opts.Mono and FONT.Mono or FONT.Regular)
	lbl.TextWrapped = true
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	local el = { Type = "Paragraph", Instance = lbl }
	el.Set = function(a, b)
		local v = argOf(el, a, b)
		if type(v) == "table" then
			if v.Title and titleLbl then titleLbl.Text = tostring(v.Title) end
			if v.Content then lbl.Text = tostring(v.Content) end
		else
			lbl.Text = tostring(v or "")
		end
	end
	return el
end

-- List: a scrolling list of clickable rows, `Lines` rows tall.
-- { Lines = 5, Empty = "Empty", Items = {...}, Callback(key) }
-- Items are strings or { Text = "...", Key = anything }. Set(items, callback?).
function Section:CreateList(opts)
	opts = opts or {}
	local lines = math.max(tonumber(opts.Lines) or 5, 1)
	local y0 = self:_nextRow()
	for _ = 2, lines do self:_nextRow() end
	local M = self.M
	local w = self:_rightEdge() - M.PadLeft
	local h = (lines - 1) * ROW_GAP + 10
	local box = Frame(self.Frame, M.PadLeft, y0 - 5, w, h, C.DropBg)
	Round(box, 2)
	Stroke(box, C.PanelBorder, 1)
	local scroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(w - 4, h - 4), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 1.5, ScrollBarImageColor3 = C.Dim, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = box,
	})
	local empty = Label(box, 3, 1, w - 6, 9, opts.Empty or "Empty", TS.Drop, C.DropText, FONT.Regular)
	local rowH, gap = 9, 1
	local el = { Type = "List", Items = {} }
	local onClick = opts.Callback
	local buttons = {}
	el.Set = function(a, b, c)
		local items, cb = a, b
		if a == el then items, cb = b, c end
		if cb then onClick = cb end
		items = items or {}
		el.Items = items
		for i = 1, #buttons do buttons[i]:Destroy() end
		table.clear(buttons)
		empty.Visible = #items == 0
		for i, item in ipairs(items) do
			local text, key = item, item
			if type(item) == "table" then
				text = item.Text or item.text or tostring(item.Key or item.key)
				key = item.Key or item.key or text
			end
			local b = New("TextButton", {
				Position = UDim2.fromOffset(0, (i - 1) * (rowH + gap)), Size = UDim2.fromOffset(w - 7, rowH),
				BackgroundColor3 = C.PanelBg, BackgroundTransparency = 0.35, AutoButtonColor = false, BorderSizePixel = 0,
				Text = "  " .. tostring(text), TextColor3 = C.Text, TextSize = TS.Drop, FontFace = FONT.Regular,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = scroll,
			})
			Round(b, 2)
			b.MouseEnter:Connect(function() b.BackgroundColor3 = C.Hover end)
			b.MouseLeave:Connect(function() b.BackgroundColor3 = C.PanelBg end)
			b.MouseButton1Click:Connect(function()
				if self:_locked() then return end
				safeCall("List", onClick, key)
			end)
			buttons[i] = b
		end
		scroll.CanvasSize = UDim2.fromOffset(0, #items * (rowH + gap))
	end
	el.Set(opts.Items or {})
	return el
end

-- Divider: a thin line across the section (takes one row)
function Section:CreateDivider()
	local y = self:_nextRow()
	local M = self.M
	local line = Frame(self.Frame, M.PadLeft, y, self:_rightEdge() - M.PadLeft, 1, C.Separator)
	return { Type = "Divider", Instance = line, Set = function() end }
end

env.VisionWareUI = VisionWare
return VisionWare
