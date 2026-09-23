# VisionWare UI

VisionWare UI lets you build a menu for your Roblox script, like Rayfield, but with the VisionWare look. You write a few short lines, and the library draws the window, the tabs, the buttons and everything else for you.

You never have to position anything by hand. You say *what* you want ("a toggle called Aimbot"), and the library works out *where* it goes.

---

## How a menu is built

Every menu is built from five layers, each one inside the one before it:

```
Window                ← the whole menu
 └─ Category          ← a grey heading in the left sidebar  (e.g. "Player")
     └─ Tab           ← a clickable page in the sidebar     (e.g. "Aimbot")
         └─ Section   ← a box on that page                  (e.g. "Aimbot Settings")
             └─ Element  ← the things you click             (toggle, slider, button...)
```

You always build them in that order: window first, then categories and tabs, then sections, then elements. The steps below follow the same order.

---

## Step 1: Load the library

```lua
local VisionWare = loadstring(readfile("VisionWareUI.lua"))()
```

**What it does:** reads the library file from your executor's workspace folder, runs it, and gives you back the `VisionWare` object.

**Why:** everything else you do starts from `VisionWare`. Without this line, none of the other functions exist.

> Put `VisionWare.lua` into your executor's `workspace` folder and name it `VisionWareUI.lua`.
> The repo is private, so `game:HttpGet` can't download it from GitHub yet.

---

## Step 2: Make the window

```lua
local Window = VisionWare:CreateWindow({
    Subtitle  = "SCRIPT HUB",
    Footer    = "My Script v1.0",
    ToggleKey = Enum.KeyCode.RightShift,
})
```

**What it does:** draws the menu window on screen, with the logo, the sidebar and the footer.

**Why:** the window holds everything else. Every tab, section and button goes inside it. You only make **one** window per script.

Every option is optional. Leave any of them out and it uses the default.

| Option | What it changes | Default |
| --- | --- | --- |
| `Name` | The big name at the top left. You can colour parts of it: `'My<font color="#59B0FC">Hub</font>'` | VisionWare |
| `Subtitle` | The small spaced-out text under the name | `"SCRIPT HUB"` |
| `Logo` | The picture at the top left. Use an asset id, or `false` for no logo | VisionWare logo |
| `Footer` | The small text at the bottom of the window | `"VisionWare [beta]"` |
| `Scale` | How big the menu is. `1` is small, `2` is big | `1.7` |
| `ToggleKey` | The key that hides and shows the menu | RightShift |
| `ConfigFolder` | The folder where saved settings go | `"VisionWare"` |
| `Backdrop` | Blurs and tints the game behind the menu while it's open | `true` |
| `Snow` | Adds falling blue snow to the backdrop | `true` |
| `Theme` | Changes colours, for example `{ Accent = Color3.fromRGB(255, 60, 90) }` for a red menu | blue |
| `OnUnload` | A function that runs when the menu is closed for good. Use it to turn your features off | none |

---

## Step 3: Add a category

```lua
Window:CreateCategory("Player")
```

**What it does:** writes a small grey heading in the sidebar.

**Why:** it groups your tabs so the sidebar is easy to read. For example, you might put "Aimbot" and "Weapons" under "Player", and "ESP" and "World" under "Visuals". Categories are optional. If you don't add any, your tabs are simply listed.

---

## Step 4: Add a tab

```lua
local AimTab = Window:CreateTab("Aimbot", "Gun")
```

**What it does:** adds a clickable item to the sidebar (under the last category) and gives it its own empty page.

**Why:** tabs split your menu into pages, so one screen isn't crammed with every option. The first tab you make opens automatically.

- The first value is the tab's name.
- The second value is its icon. You can use a built-in icon name, or any image asset id (`"rbxassetid://123..."`).

**Built-in icons:** `Gun`, `Pistol`, `Bullet`, `Box`, `Pin`, `Person`, `Skeleton`, `Globe`, `Lines`, `Cube`, `Gear`, `Folder`, `Dot`, `Star`, `Home`, `Eye`, `Palette`

---

## Step 5: Add a section

```lua
local AimSection = AimTab:CreateSection({
    Name = "Aimbot",
    Side = "Left",
})
```

**What it does:** draws a box with a title on the tab's page.

**Why:** sections group related options together. Each page has two columns, so you can put two boxes side by side. Each box grows by itself as you add things to it, and the boxes below it move down automatically.

| Option | What it changes |
| --- | --- |
| `Name` | The title at the top of the box |
| `Side` | `"Left"`, `"Right"`, or `"Full"` (the full width of the page). Leave it out and the box goes in whichever column is shorter |
| `Toggle` | `true` adds an on/off switch in the box's title bar. When it's off, everything in the box is greyed out and can't be clicked. This is handy for a whole feature, like "Aimbot on/off" |
| `Default` | Whether that switch starts on (`true`) or off (`false`) |
| `Callback` | A function that runs when the switch is flipped, with `true` or `false` |
| `Icon` | A small icon shown after the title |

You can change a section later from your code:
- `Section:SetVisible(false)` hides the whole box.
- `Section:SetEnabled(false)` flips its switch.
- `Section:SetTitle("New name")` renames it.

---

## Step 6: Add elements (the things people click)

Elements go inside a section. Every element follows the same pattern:

```lua
Section:CreateSomething({
    Name     = "What the user sees",
    Callback = function(value)
        -- runs every time the user changes it
    end,
})
```

> **What is a "Callback"?**
> It's your function, and the library runs it for you whenever the user changes that element. It gets the new value (for example `true` or `false` for a toggle). This is where you switch your feature on or off.
>
> The callback runs when the **user** changes the value, and when your code or a loaded config changes it.
> It does **not** run when the element is first created.

### Toggle: an on/off box

```lua
local AimToggle = Section:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = false,
    Callback = function(isOn)
        print("Aimbot is now", isOn)
    end,
})
```

**Use it for:** anything that's either on or off.
**The callback gets:** `true` or `false`.
**From your code:** `AimToggle:Set(true)` turns it on. `AimToggle.CurrentValue` tells you whether it's on right now.

### Slider: pick a number by dragging

```lua
Section:CreateSlider({
    Name = "Field Of View",
    Range = { 0, 100 },     -- lowest and highest number
    Increment = 1,          -- step size (use 0.1 for decimals)
    CurrentValue = 80,      -- starting number
    Suffix = "",            -- text after the number, e.g. "m" or "%"
    Callback = function(number)
        print("FOV is", number)
    end,
})
```

**Use it for:** any amount, such as a speed, a distance, a size or a percentage.
**The callback gets:** the number. It runs while the user drags.

### Dropdown: pick one option from a list

```lua
Section:CreateDropdown({
    Name = "Hitbox",
    Options = { "Head", "Torso", "Closest" },
    CurrentOption = "Head",
    Callback = function(choice)
        print("Aiming at", choice)
    end,
})
```

**Use it for:** choosing one thing from a fixed list.
**The callback gets:** the option that was picked, as text.

It has a few extras:
- **Pick several:** add `MultipleOptions = true`. The user can then tick several options, and the callback gets a list such as `{ "Head", "Torso" }`.
- **Long lists:** a list with more than 8 options gets a search box automatically.
- **Changing the list later:** `Dropdown:Refresh({ "New", "Options" })` replaces the options, for example with a list of players that changes.

### Keybind: let the user pick a key

```lua
Section:CreateKeybind({
    Name = "Aim Key",
    CurrentKeybind = "Q",
    HoldToInteract = false,
    Callback = function()
        print("Key pressed!")
    end,
})
```

**Use it for:** hotkeys, so the user can choose their own key.
**The callback runs:** every time that key is pressed during the game. Key presses are ignored while the user is typing in chat.

- **Hold mode:** with `HoldToInteract = true`, the callback gets `true` when the key goes down and `false` when it comes up. Use this for things that should only work while the key is held, like aiming.
- **How the user changes the key:** they click it, then press the new key. Escape cancels, and Backspace removes the key.
- **Mouse buttons** are named `"Mouse 1"`, `"Mouse 2"` and `"Mouse 3"`.

### Color picker: pick any colour

```lua
Section:CreateColorPicker({
    Name = "ESP Color",
    Color = Color3.fromRGB(0, 88, 248),
    Callback = function(color)
        print("New colour", color)
    end,
})
```

**Use it for:** colours of ESP boxes, crosshairs, chams and so on.
**How it works:** the user clicks the little circle, and a picker opens with a colour square, a rainbow bar and a box for typing a hex code.
**The callback gets:** a `Color3`.

### Input: a text box

```lua
Section:CreateInput({
    Name = "Target Name",
    PlaceholderText = "type a name",
    NumbersOnly = false,
    Callback = function(text)
        print("You typed", text)
    end,
})
```

**Use it for:** anything the user types, like a player name, an amount or a message.
**The callback runs:** when the user clicks away or presses Enter, not on every letter.

- `NumbersOnly = true` only lets the user type numbers.
- `RemoveTextAfterFocusLost = true` empties the box after they finish.

### Button: do something once

```lua
local Btn = Section:CreateButton({
    Name = "Teleport To Spawn",
    Callback = function()
        print("Clicked!")
    end,
})
```

**Use it for:** one-time actions, like teleporting, rejoining, resetting or buying something.
**From your code:** `Btn:Set("New text")` changes what the button says.

### Label: plain text

```lua
local Status = Section:CreateLabel("Waiting...")
Status:Set("Running!")
```

**Use it for:** notes, warnings or status messages.

### Info: a name with a value on the right

```lua
local Money = Section:CreateInfo({ Name = "Money", Value = "$0" })
Money:Set("$5,000")
```

**Use it for:** showing live numbers such as money, a timer, a kill count or the current state.

### Paragraph: a block of longer text

```lua
Section:CreateParagraph({
    Title = "How to use",
    Content = "Hold Q to aim. Press RightShift to hide the menu.",
    Lines = 3,        -- how many rows tall the box is
})
```

**Use it for:** instructions, changelogs, credits or a log. Add `Mono = true` for a terminal-style font.

### List: rows the user can click

```lua
local PlayerList = Section:CreateList({ Lines = 5, Empty = "No players" })
PlayerList:Set({ "Player1", "Player2" }, function(clicked)
    print("You clicked", clicked)
end)
```

**Use it for:** a list that changes, like players, saved locations or items. Clicking a row runs your function with that row.

### Divider: a thin line

```lua
Section:CreateDivider()
```

**Use it for:** splitting a section into parts so it's easier to read.

---

## Step 7: Save settings (configs)

Users hate setting everything up again every time they run the script. Configs remember their settings.

**The easy way:** add the ready-made Configs box, and you're done.

```lua
local SettingsTab = Window:CreateTab("Settings", "Gear")
SettingsTab:CreateConfigSection({ Side = "Right" })
```

That box lets the user type a name, save, load or delete a config, and tick **Auto Load** so the config loads by itself next time.

**How it knows what to save:** every element that holds a value (toggle, slider, dropdown, keybind, colour, input) is saved automatically. Each one is saved under a name called its **Flag**. If you don't give one, it gets `"Tab/Section/Name"`. Give your own `Flag` if you might rename things later, so old configs still load:

```lua
Section:CreateToggle({ Name = "Enable Aimbot", Flag = "AimbotEnabled", Callback = ... })
```

To keep an element out of configs, add `Save = false`.

---

## Step 8: Menu settings box

```lua
SettingsTab:CreateMenuSection({ Side = "Left" })
```

**What it does:** adds a box where the user can change the menu key, the menu size, and the background blur and snow. It also has an **Unload** button.

**Why:** almost every script wants these options, so you don't have to build them yourself.

---

## Step 9: Notifications

```lua
Window:Notify({
    Title = "Aimbot",
    Content = "Locked on to the closest player",
    Duration = 4,     -- seconds
})
```

**What it does:** a small card slides in at the bottom right of the screen, then slides away by itself.

**Why:** it tells the user something happened without them having to open the menu. You can also just write `Window:Notify("Hello!")`.

---

## Step 10: Finish up (always last)

```lua
Window:LoadConfiguration()
```

**What it does:** loads the user's **Auto Load** config, if they set one.

**Why it must be last:** it can only fill in elements that already exist. If you call it before you've made your toggles and sliders, their saved values have nowhere to go.

---

## Controlling the menu from your code

| Code | What it does |
| --- | --- |
| `Window:Toggle()` | Hides the menu if it's open, shows it if it's hidden |
| `Window:SetVisible(true / false)` | Shows or hides the menu |
| `Window:SetScale(2)` | Makes the menu bigger or smaller |
| `Window:SetToggleKey("Insert")` | Changes the open/close key |
| `Window:SelectTab("Aimbot")` | Jumps to a tab |
| `Window:SetFooter("text")` | Changes the footer text |
| `Window:OnUnload(function() ... end)` | Runs your function when the menu is unloaded, so you can switch your features off |
| `Window:Destroy()` | Unloads the menu completely |
| `VisionWare.Flags["AimbotEnabled"].CurrentValue` | Reads any element's value by its Flag |

---

## A complete small script

```lua
-- 1. load the library
local VisionWare = loadstring(readfile("VisionWareUI.lua"))()

-- 2. make the window
local Window = VisionWare:CreateWindow({ Footer = "My Script" })

-- 3 + 4. a category and a tab
Window:CreateCategory("Main")
local MainTab = Window:CreateTab("Main", "Home")

-- 5. a section
local Section = MainTab:CreateSection({ Name = "Player", Side = "Left" })

-- 6. elements
Section:CreateSlider({
    Name = "Walk Speed", Range = { 16, 100 }, Increment = 1, CurrentValue = 16,
    Callback = function(speed)
        local hum = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = speed end
    end,
})

-- 7 + 8. settings
local SettingsTab = Window:CreateTab("Settings", "Gear")
SettingsTab:CreateMenuSection({ Side = "Left" })
SettingsTab:CreateConfigSection({ Side = "Right" })

-- 10. always last
Window:LoadConfiguration()
```

`Example.lua` in this repo uses **every** element, with comments explaining each line.

---

## Common problems

| Problem | Fix |
| --- | --- |
| Nothing shows up | Check the file is in your executor's `workspace` folder, named `VisionWareUI.lua` |
| My saved settings don't load | Put `Window:LoadConfiguration()` at the very **end** of your script |
| My callback didn't run when the menu opened | That's on purpose: callbacks only run when a value **changes**. If you need the starting value, read `Element.CurrentValue` |
| I can't click anything in a section | Its title-bar switch is off (only sections made with `Toggle = true` have one) |
| The menu is too big or too small | Change `Scale` in `CreateWindow`, or use the Menu Scale slider in the Menu box |

---

## Why it doesn't lag

- **Idle costs nothing.** Nothing runs every frame while the menu sits there. The snow only animates while the menu is open, and it stops completely when you close it.
- **Shared input.** One set of input listeners handles every slider, keybind and colour picker. It doesn't matter if you have 5 or 500 of them.
- **Popups are reused.** Dropdown lists and colour pickers are built once, the first time they open, then reused.
- **Clean unload.** Unloading removes everything the library made, so nothing is left running.
