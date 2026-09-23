# VisionWare UI

A Rayfield-style UI library for Roblox, built on the VisionWare menu design. It has a navy window with an electric-blue accent, a sidebar of categories and tabs, and two columns of sections on every tab.

- **Elements:** toggles, sliders, dropdowns (single, multi-select and searchable), keybinds (press or hold), an HSV colour picker, buttons, text inputs, labels, info rows, paragraphs, clickable lists and dividers
- **Configs:** save and load configs, with an optional auto-load config
- **Notifications:** notifications that close by themselves, with a timer bar
- **Window:** drag the window, change its scale, and pick the key that opens and closes it. It has an optional blur and snow backdrop, and a button that opens the menu on touch devices.
- **Performance:** nothing runs every frame while the menu sits idle (see [Performance](#performance))

## Loading

```lua
-- from your executor's workspace folder
local VisionWare = loadstring(readfile("VisionWareUI.lua"))()
```

`Example.lua` shows every element. Copy `VisionWare.lua` into your executor's workspace as `VisionWareUI.lua`, then run `Example.lua`.

## Window

```lua
local Window = VisionWare:CreateWindow({
    Name         = 'Vision<font color="#59B0FC">Ware</font>', -- rich text wordmark
    Subtitle     = "SCRIPT HUB",            -- small spaced text under the name
    Logo         = "rbxassetid://76539991703135", -- false = no logo
    Footer       = "VisionWare [beta]",
    Scale        = 1.7,                     -- size multiplier
    ToggleKey    = Enum.KeyCode.RightShift, -- or a key name string
    ConfigFolder = "VisionWare",
    Backdrop     = true,                    -- blur + tint while open
    Snow         = true,                    -- drifting snow in the backdrop
    Blur         = true,
    ShowToggleButton = nil,                 -- nil = only on touch devices
    Theme        = { Accent = Color3.fromRGB(0, 88, 248) }, -- override any theme colour
    OnUnload     = function() end,
})
```

| Method | What it does |
| --- | --- |
| `Window:CreateCategory(name)` | Adds a grey heading to the sidebar |
| `Window:CreateTab(name, icon)` | Adds a tab and returns it |
| `Window:SelectTab(tab or name)` | Switches to a tab |
| `Window:Notify({ Title, Content, Duration })` | Shows a notification. A plain string also works |
| `Window:Toggle()` / `SetVisible(bool)` / `IsVisible()` | Shows or hides the menu |
| `Window:SetScale(n)` / `SetToggleKey(key)` / `SetBackdrop(bool)` / `SetFooter(text)` | Changes the scale, the toggle key, the backdrop or the footer text |
| `Window:SaveConfiguration(name)` / `LoadConfiguration(name?)` / `DeleteConfiguration(name)` / `ListConfigurations()` | Saves, loads, deletes or lists configs |
| `Window:SetAutoLoad(name)` / `GetAutoLoad()` | Sets or reads the config that loads by itself |
| `Window:OnUnload(fn)` / `Destroy()` | Runs `fn` when the menu unloads / unloads the menu |

Call `Window:LoadConfiguration()` with no name **after** you have made every element. It applies the auto-load config.

## Tabs and sections

```lua
Window:CreateCategory("Player")
local Tab = Window:CreateTab("Aimbot", "Gun")   -- icon: a built-in name or an asset id

local Section = Tab:CreateSection({
    Name     = "Aimbot",
    Side     = "Left",      -- "Left", "Right" or "Full"; leave out to use the shorter column
    Toggle   = true,        -- master switch in the header; off = the rows are locked
    Default  = true,
    Icon     = "Gun",       -- small icon after the title
    Callback = function(enabled) end,
})
```

Sections grow as you add elements, and the columns re-stack automatically. Other section methods are `SetVisible(bool)`, `SetEnabled(bool)` and `SetTitle(text)`.

You can use Rayfield style too. `Tab:CreateToggle(...)` adds the element to the last section on that tab. If the tab has no section yet, it makes one.

**Built-in icons:** `Gun`, `Pistol`, `Bullet`, `Box`, `Pin`, `Person`, `Skeleton`, `Globe`, `Lines`, `Cube`, `Gear`, `Folder`, `Dot`, `Star`, `Home`, `Eye`, `Palette`

## Elements

Every element that holds a value has `:Set(value)`, `:Get()`, `:OnChanged(fn)` and `.CurrentValue`. It is also stored in `VisionWare.Flags[flag]`. If you leave out `Flag`, it gets one automatically (`"Tab/Section/Name"`). Set `Save = false` to keep an element out of configs.

```lua
Section:CreateToggle({ Name = "Enabled", CurrentValue = false, Flag = "Enabled", Callback = function(v) end })
Section:CreateSlider({ Name = "FOV", Range = { 0, 100 }, Increment = 1, CurrentValue = 80, Suffix = "", Callback = function(v) end })
Section:CreateDropdown({ Name = "Hitbox", Options = { "Head", "Torso" }, CurrentOption = "Head", Callback = function(o) end })
Section:CreateDropdown({ Name = "Targets", Options = { "A", "B", "C" }, MultipleOptions = true, CurrentOption = { "A" }, Callback = function(list) end })
Section:CreateKeybind({ Name = "Key", CurrentKeybind = "Q", HoldToInteract = false, Callback = function() end, ChangedCallback = function(key) end })
Section:CreateColorPicker({ Name = "Color", Color = Color3.fromRGB(0, 88, 248), Callback = function(c) end })
Section:CreateInput({ Name = "Name", PlaceholderText = "...", NumbersOnly = false, RemoveTextAfterFocusLost = false, Callback = function(text) end })
Section:CreateButton({ Name = "Do It", Callback = function() end })     -- :Set(text) renames it
Section:CreateLabel("Some text")                                         -- :Set(text)
Section:CreateInfo({ Name = "Status", Value = "Idle" })                  -- :Set(value)
Section:CreateParagraph({ Title = "Title", Content = "Long text...", Lines = 3, Mono = false })
Section:CreateList({ Lines = 5, Empty = "Empty", Items = { "a", { Text = "b", Key = 2 } }, Callback = function(key) end })
Section:CreateDivider()
```

A few details:
- **Callbacks:** a callback runs when the user changes the value, and when `:Set()` or a loaded config changes it. It does not run when the element is created. `Set(value, true)` changes a toggle, slider or colour quietly, without running the callback.
- **Dropdowns:** `:Refresh(options, keepSelection)` replaces the options. A dropdown with more than 8 options gets a search box.
- **Keybinds:** click the key to rebind it. Escape cancels and Backspace clears it. Mouse buttons are `"Mouse 1"`, `"Mouse 2"` and `"Mouse 3"`. With `HoldToInteract`, the callback gets `true` when the key goes down and `false` when it comes up.

## Ready-made sections

```lua
local Settings = Window:CreateTab("Settings", "Gear")
Settings:CreateMenuSection({ Side = "Left" })    -- menu key, menu scale, background effect, unload
Settings:CreateConfigSection({ Side = "Right" }) -- config name, saved list, save / load / delete, auto load
```

## Performance

- **No per-frame loops.** The only per-frame work is the backdrop snow, and it stops completely when the menu is closed.
- **Shared input.** Each window has one `InputBegan`, one `InputChanged` and one `InputEnded` connection, shared by every slider, colour picker, keybind and the window drag. A key press is looked up in a table, so the cost doesn't grow with the number of keybinds.
- **Popups are reused.** Dropdown lists and colour pickers are built the first time they open, then reused.
- **Layout is batched.** Section layout and canvas sizes are recalculated once per batch of changes, not once per element.
- **Nothing leaks.** Unloading disconnects everything and removes every instance the library made, including the blur.
