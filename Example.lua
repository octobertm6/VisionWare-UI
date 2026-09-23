--[[
	VisionWare UI - example script. Shows every element the library has.
	Put VisionWare.lua in your executor's workspace folder as VisionWareUI.lua,
	then run this file.
]]

local VisionWare = loadstring(readfile("VisionWareUI.lua"))()

local Window = VisionWare:CreateWindow({
	-- Name = 'My<font color="#59B0FC">Hub</font>',   -- rich text; defaults to the VisionWare wordmark
	Subtitle     = "SCRIPT HUB",
	Footer       = "VisionWare UI  v" .. VisionWare.Version,
	Scale        = 1.7,
	ToggleKey    = Enum.KeyCode.RightShift,
	ConfigFolder = "VisionWare",
	Backdrop     = true,     -- blur + tint + snow while the menu is open
	-- Theme     = { Accent = Color3.fromRGB(255, 60, 90) },
})

-----------------------------------------------------------------------------
Window:CreateCategory("Elements")
-----------------------------------------------------------------------------
local Main = Window:CreateTab("Main", "Home")

local Toggles = Main:CreateSection({ Name = "Toggles", Side = "Left", Toggle = true, Icon = "Gun" })
Toggles:CreateToggle({ Name = "Enable Feature", CurrentValue = false, Flag = "Feature", Callback = function(v)
	print("Enable Feature:", v)
end })
Toggles:CreateToggle({ Name = "Starts On", CurrentValue = true })
Toggles:CreateKeybind({ Name = "Hotkey", CurrentKeybind = "Q", Callback = function()
	Window:Notify({ Title = "Hotkey", Content = "You pressed the hotkey" })
end })
Toggles:CreateKeybind({ Name = "Hold Key", CurrentKeybind = "Mouse 2", HoldToInteract = true, Callback = function(held)
	print("holding:", held)
end })

local Sliders = Main:CreateSection({ Name = "Sliders", Side = "Right" })
Sliders:CreateSlider({ Name = "Field Of View", Range = { 0, 100 }, Increment = 1, CurrentValue = 80, Callback = function(v)
	print("FOV:", v)
end })
Sliders:CreateSlider({ Name = "Smoothness", Range = { 0, 1 }, Increment = 0.05, CurrentValue = 0.5 })
Sliders:CreateSlider({ Name = "Distance", Range = { 50, 2000 }, Increment = 50, CurrentValue = 500, Suffix = "m" })

local Dropdowns = Main:CreateSection({ Name = "Dropdowns", Side = "Right" })
Dropdowns:CreateDropdown({ Name = "Hitbox", Options = { "Head", "Torso", "HumanoidRootPart", "Closest" }, CurrentOption = "Head",
	Callback = function(o) print("Hitbox:", o) end })
Dropdowns:CreateDropdown({ Name = "Show On", Options = { "Players", "NPCs", "Items", "Vehicles" }, MultipleOptions = true,
	CurrentOption = { "Players" }, Callback = function(list) print("Show On:", table.concat(list, ", ")) end })
local numbers = {}
for i = 1, 25 do numbers[i] = "Option " .. i end
Dropdowns:CreateDropdown({ Name = "Long List", Options = numbers, CurrentOption = "Option 1" })   -- over 8 options: gets a search box

local Buttons = Main:CreateSection({ Name = "Buttons", Side = "Left" })
Buttons:CreateButton({ Name = "Send Notification", Callback = function()
	Window:Notify({ Title = "VisionWare", Content = "This is a notification. It closes by itself.", Duration = 4 })
end })
local counter = 0
local countButton
countButton = Buttons:CreateButton({ Name = "Clicked 0 times", Callback = function()
	counter = counter + 1
	countButton:Set("Clicked " .. counter .. " times")
end })

-----------------------------------------------------------------------------
local Visuals = Window:CreateTab("Visuals", "Eye")

local Colors = Visuals:CreateSection({ Name = "Colours", Side = "Left" })
Colors:CreateColorPicker({ Name = "Box Color", Color = Color3.fromRGB(72, 112, 184), Callback = function(c)
	print("Box Color:", c:ToHex())
end })
Colors:CreateColorPicker({ Name = "Name Color", Color = Color3.fromRGB(235, 240, 248) })
Colors:CreateDivider()
Colors:CreateToggle({ Name = "Rainbow", CurrentValue = false })

local Text = Visuals:CreateSection({ Name = "Text", Side = "Right" })
Text:CreateInput({ Name = "Username", PlaceholderText = "type here", Callback = function(t) print("Username:", t) end })
Text:CreateInput({ Name = "Amount", PlaceholderText = "numbers", NumbersOnly = true })
local info = Text:CreateInfo({ Name = "Time Open", Value = "0s" })
Text:CreateLabel("A plain label")

local Wide = Visuals:CreateSection({ Name = "Full Width", Side = "Full" })
Wide:CreateParagraph({ Title = "Paragraph", Content = "A paragraph wraps long text inside a box. Set Lines to choose how tall it is, and Mono = true for a terminal look.", Lines = 3 })
local list = Wide:CreateList({ Lines = 4, Empty = "Nothing here" })
list:Set({ "Click a row", { Text = "Rows can carry a key", Key = 42 }, "Third row" }, function(key)
	Window:Notify({ Title = "List", Content = "Clicked: " .. tostring(key) })
end)

-----------------------------------------------------------------------------
Window:CreateCategory("Settings")
-----------------------------------------------------------------------------
local Settings = Window:CreateTab("Settings", "Gear")
Settings:CreateMenuSection({ Side = "Left" })
Settings:CreateConfigSection({ Side = "Right" })

-- the info row updates once a second (no per-frame work)
task.spawn(function()
	local opened = os.clock()
	while not Window.Destroyed do
		info:Set(string.format("%ds", os.clock() - opened))
		task.wait(1)
	end
end)

Window:OnUnload(function() print("VisionWare unloaded") end)

-- apply the auto-load config (if one is set) now that every element exists
Window:LoadConfiguration()
Window:Notify({ Title = "VisionWare", Content = "Loaded. Press RightShift to hide or show the menu." })
