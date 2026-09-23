--[[
	VisionWare UI: example script
	This builds a menu that uses EVERY element, with a comment on each part saying
	what it does and why you would use it. Copy the bits you need into your own script.

	Before running: put VisionWare.lua in your executor's workspace folder and
	name it VisionWareUI.lua.
]]

-----------------------------------------------------------------------------
-- STEP 1: load the library
-- Reads the library file and runs it. Everything below starts from `VisionWare`,
-- so this line always comes first.
-----------------------------------------------------------------------------
local VisionWare = loadstring(readfile("VisionWareUI.lua"))()

-----------------------------------------------------------------------------
-- STEP 2: make the window
-- The window is the whole menu. Every tab, box and button goes inside it.
-- Make only ONE per script. Every option is optional.
-----------------------------------------------------------------------------
local Window = VisionWare:CreateWindow({
	-- Name      = 'My<font color="#59B0FC">Hub</font>',  -- your own name (the coloured part is optional)
	Subtitle     = "SCRIPT HUB",                            -- small text under the name
	Footer       = "VisionWare UI  v" .. VisionWare.Version, -- text at the bottom of the window
	Scale        = 1.7,                                      -- menu size (1 = small, 2 = big)
	ToggleKey    = Enum.KeyCode.RightShift,                  -- key that hides / shows the menu
	ConfigFolder = "VisionWare",                             -- folder the saved settings go in
	Backdrop     = true,                                     -- blur the game behind the menu while it's open
	-- Theme     = { Accent = Color3.fromRGB(255, 60, 90) }, -- uncomment for a red menu
})

-----------------------------------------------------------------------------
-- STEP 3: a category
-- A grey heading in the sidebar. It groups the tabs under it so the sidebar
-- is easy to read.
-----------------------------------------------------------------------------
Window:CreateCategory("Elements")

-----------------------------------------------------------------------------
-- STEP 4: a tab
-- A clickable item in the sidebar with its own page. Tabs split the menu into
-- pages so one screen isn't crammed. ("Home" is a built-in icon.)
-----------------------------------------------------------------------------
local Main = Window:CreateTab("Main", "Home")

-----------------------------------------------------------------------------
-- STEP 5: a section
-- A box on the page that groups related options. Side = "Left" / "Right" / "Full".
-- Toggle = true adds an on/off switch in the box's title: when it is off,
-- everything inside is greyed out and can't be clicked.
-----------------------------------------------------------------------------
local Toggles = Main:CreateSection({ Name = "Toggles", Side = "Left", Toggle = true, Icon = "Gun" })

-----------------------------------------------------------------------------
-- STEP 6: elements (the things people click)
-- "Callback" is YOUR function: the library runs it every time the user changes
-- the element, and gives it the new value. That's where your feature goes.
-----------------------------------------------------------------------------

-- TOGGLE: an on/off box. Use it for anything that is either on or off.
-- The callback gets true / false.
Toggles:CreateToggle({
	Name = "Enable Feature",
	CurrentValue = false,
	Flag = "Feature",          -- the name it is saved under in configs (optional)
	Callback = function(isOn)
		print("Enable Feature:", isOn)
	end,
})
Toggles:CreateToggle({ Name = "Starts On", CurrentValue = true })

-- KEYBIND: lets the user choose their own hotkey. The callback runs whenever
-- that key is pressed in game. Click the key in the menu to change it.
Toggles:CreateKeybind({
	Name = "Hotkey",
	CurrentKeybind = "Q",
	Callback = function()
		Window:Notify({ Title = "Hotkey", Content = "You pressed the hotkey" })
	end,
})

-- KEYBIND (hold): with HoldToInteract, the callback gets true when the key goes
-- down and false when it comes up. Use it for "only while held" things like aiming.
Toggles:CreateKeybind({
	Name = "Hold Key",
	CurrentKeybind = "Mouse 2",
	HoldToInteract = true,
	Callback = function(isHeld)
		print("holding:", isHeld)
	end,
})

-- A second box, in the right column
local Sliders = Main:CreateSection({ Name = "Sliders", Side = "Right" })

-- SLIDER: pick a number by dragging. Use it for amounts: speed, distance, size...
-- Range = lowest and highest, Increment = step size. The callback gets the number.
Sliders:CreateSlider({
	Name = "Field Of View",
	Range = { 0, 100 },
	Increment = 1,
	CurrentValue = 80,
	Callback = function(number)
		print("FOV:", number)
	end,
})
Sliders:CreateSlider({ Name = "Smoothness", Range = { 0, 1 }, Increment = 0.05, CurrentValue = 0.5 })   -- decimals
Sliders:CreateSlider({ Name = "Distance", Range = { 50, 2000 }, Increment = 50, CurrentValue = 500, Suffix = "m" }) -- "500 m"

local Dropdowns = Main:CreateSection({ Name = "Dropdowns", Side = "Right" })

-- DROPDOWN: pick ONE option from a list. The callback gets the option's text.
Dropdowns:CreateDropdown({
	Name = "Hitbox",
	Options = { "Head", "Torso", "HumanoidRootPart", "Closest" },
	CurrentOption = "Head",
	Callback = function(choice)
		print("Hitbox:", choice)
	end,
})

-- DROPDOWN (multi): MultipleOptions = true lets the user tick SEVERAL options.
-- The callback gets a list, e.g. { "Players", "Items" }.
Dropdowns:CreateDropdown({
	Name = "Show On",
	Options = { "Players", "NPCs", "Items", "Vehicles" },
	MultipleOptions = true,
	CurrentOption = { "Players" },
	Callback = function(list)
		print("Show On:", table.concat(list, ", "))
	end,
})

-- A list with more than 8 options gets a search box automatically
local numbers = {}
for i = 1, 25 do numbers[i] = "Option " .. i end
Dropdowns:CreateDropdown({ Name = "Long List", Options = numbers, CurrentOption = "Option 1" })

local Buttons = Main:CreateSection({ Name = "Buttons", Side = "Left" })

-- BUTTON: does something once per click. Use it for actions such as teleport,
-- rejoin or reset.
Buttons:CreateButton({
	Name = "Send Notification",
	Callback = function()
		-- NOTIFY: a small card at the bottom right that goes away by itself.
		-- Use it to tell the user something happened.
		Window:Notify({ Title = "VisionWare", Content = "This is a notification. It closes by itself.", Duration = 4 })
	end,
})

-- Buttons can change their own text with :Set()
local counter = 0
local countButton
countButton = Buttons:CreateButton({
	Name = "Clicked 0 times",
	Callback = function()
		counter = counter + 1
		countButton:Set("Clicked " .. counter .. " times")
	end,
})

-----------------------------------------------------------------------------
-- A second tab
-----------------------------------------------------------------------------
local Visuals = Window:CreateTab("Visuals", "Eye")

local Colors = Visuals:CreateSection({ Name = "Colours", Side = "Left" })

-- COLOR PICKER: pick any colour. Click the little circle to open the picker.
-- The callback gets a Color3. Use it for ESP, crosshair or chams colours.
Colors:CreateColorPicker({
	Name = "Box Color",
	Color = Color3.fromRGB(72, 112, 184),
	Callback = function(color)
		print("Box Color:", color:ToHex())
	end,
})
Colors:CreateColorPicker({ Name = "Name Color", Color = Color3.fromRGB(235, 240, 248) })

-- DIVIDER: a thin line that splits a box into parts
Colors:CreateDivider()
Colors:CreateToggle({ Name = "Rainbow", CurrentValue = false })

local Text = Visuals:CreateSection({ Name = "Text", Side = "Right" })

-- INPUT: a text box. The callback runs when the user clicks away or presses Enter.
Text:CreateInput({
	Name = "Username",
	PlaceholderText = "type here",
	Callback = function(text)
		print("Username:", text)
	end,
})
Text:CreateInput({ Name = "Amount", PlaceholderText = "numbers", NumbersOnly = true })  -- only numbers allowed

-- INFO: a name on the left and a value on the right. Update it with :Set().
-- Use it for live numbers like money or a timer.
local timeOpen = Text:CreateInfo({ Name = "Time Open", Value = "0s" })

-- LABEL: plain text, for notes or status messages
Text:CreateLabel("A plain label")

-- Side = "Full" makes a box that spans the whole width of the page
local Wide = Visuals:CreateSection({ Name = "Full Width", Side = "Full" })

-- PARAGRAPH: a block of longer text. Lines = how many rows tall the box is.
Wide:CreateParagraph({
	Title = "Paragraph",
	Content = "A paragraph wraps long text inside a box. Set Lines to choose how tall it is, and Mono = true for a terminal look.",
	Lines = 3,
})

-- LIST: rows the user can click. Fill it with :Set(rows, whatToDoOnClick).
-- Use it for things that change, like a player list.
local list = Wide:CreateList({ Lines = 4, Empty = "Nothing here" })
list:Set({ "Click a row", { Text = "Rows can carry a key", Key = 42 }, "Third row" }, function(clicked)
	Window:Notify({ Title = "List", Content = "Clicked: " .. tostring(clicked) })
end)

-----------------------------------------------------------------------------
-- STEP 7 + 8: settings tab with the two ready-made boxes
-- Menu box:    menu key, menu size, background effect, unload button
-- Configs box: save / load / delete settings, plus Auto Load
-- Almost every script needs these, so they come built in.
-----------------------------------------------------------------------------
Window:CreateCategory("Settings")
local Settings = Window:CreateTab("Settings", "Gear")
Settings:CreateMenuSection({ Side = "Left" })
Settings:CreateConfigSection({ Side = "Right" })

-- keeps the "Time Open" info row up to date, once a second (not every frame)
task.spawn(function()
	local opened = os.clock()
	while not Window.Destroyed do
		timeOpen:Set(string.format("%ds", os.clock() - opened))
		task.wait(1)
	end
end)

-- runs when the menu is unloaded: switch your features off here
Window:OnUnload(function()
	print("VisionWare unloaded")
end)

-----------------------------------------------------------------------------
-- STEP 10: ALWAYS LAST
-- Loads the user's Auto Load config. It has to come after every element is made,
-- or the saved values have nothing to go into.
-----------------------------------------------------------------------------
Window:LoadConfiguration()
Window:Notify({ Title = "VisionWare", Content = "Loaded. Press RightShift to hide or show the menu." })
