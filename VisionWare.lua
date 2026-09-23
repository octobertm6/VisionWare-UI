--!strict
--[[
	VisionWare menu – Roblox recreation of the reference layout (480x307 px),
	re-themed to the VisionWare logo / banner colours.

	Every position / size below is the pixel value measured from the screenshot.
	SCALE multiplies the whole window (1.7 = 816x522 on screen; the Misc tab's Menu Scale changes it live). Change it freely.

	Controls are functional: toggles, checkboxes, sliders (drag), dropdowns,
	keybinds (click, then press a key / mouse button), colour swatch (click for a
	palette). Values live in Library.Config[<Panel>][<Label>].

	RightShift hides / shows the menu. Drag the window by its top bar.
	No game logic is included – wire your own code to the Callback arguments.
]]

-- only one copy may run: unload any previous instance before building a new one
do
	local env = (getgenv and getgenv()) or _G
	local previous = env.VisionWare
	if type(previous) == "table" and type(previous.Destroy) == "function" then pcall(previous.Destroy) end
end
-- unique suffix so this copy's render steps can never collide with another copy's
local INSTANCE_ID = tostring(math.random(100000, 999999)) .. tostring(os.clock()):gsub("%.", "")

local SCALE      = 1.7
local TOGGLE_KEY = Enum.KeyCode.RightShift
local PANIC_KEY  = Enum.KeyCode.End        -- unloads the menu instantly

local UIS         = game:GetService("UserInputService")
local Players     = game:GetService("Players")
local TextService = game:GetService("TextService")

---------------------------------------------------------------------------
-- Fonts. The reference uses an Inter-style typeface; Roblox ships Inter as a
-- font family. If it cannot be loaded we fall back to Builder Sans, then Gotham.
---------------------------------------------------------------------------
local function LoadFamily(family)
	local ok, font = pcall(Font.new, "rbxasset://fonts/families/" .. family .. ".json", Enum.FontWeight.Medium)
	if not ok then return nil end
	local params = Instance.new("GetTextBoundsParams")
	params.Text, params.Font, params.Size, params.Width = "Aimbot", font, 20, 1000
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
}
-- text sizes at 1x, calibrated so rendered widths match the screenshot
local TS = {
	Row = 7.3, Key = 7.4, Drop = 5.5, Title = 8.3, Header = 8, Footer = 7.8,
	SideItem = 7.9, Section = 8.7,
}

---------------------------------------------------------------------------
-- Assets (VisionWare branding)
---------------------------------------------------------------------------
local ASSETS = {
	Logo   = "rbxassetid://76539991703135",   -- VisionWare "V" logo
	Banner = "rbxassetid://82251562379641",   -- VisionWare banner (colours sampled from it)
	-- white pistol silhouette: decal 129186731 resolves to image 129186730
	-- (the ImageLabel needs the image id, not the decal id). Tinted via ImageColor3.
	Gun    = "rbxassetid://129186730",
}

---------------------------------------------------------------------------
-- Theme: VisionWare. Navy backgrounds and the electric-blue accent are sampled
-- from the logo / banner (bg ~ (5,8,15)..(11,23,42), accent (0,88,248),
-- light text blue (89,176,252), muted blue (53,95,152)).
-- Key names are kept from the original layout code (Red = accent colour).
---------------------------------------------------------------------------
local C = {
	WindowBg      = Color3.fromRGB(6, 9, 16),
	WindowBorder  = Color3.fromRGB(20, 32, 54),
	SidebarLine   = Color3.fromRGB(17, 27, 46),
	Highlight     = Color3.fromRGB(12, 19, 33),
	Footer        = Color3.fromRGB(8, 13, 23),

	PanelBg       = Color3.fromRGB(9, 14, 25),
	PanelBorder   = Color3.fromRGB(20, 32, 54),
	Separator     = Color3.fromRGB(18, 29, 49),

	Red           = Color3.fromRGB(0, 88, 248),     -- accent (toggles, sliders, ticks, indicator)
	RedDark       = Color3.fromRGB(0, 72, 212),
	CheckRed      = Color3.fromRGB(0, 88, 248),
	LightBlue     = Color3.fromRGB(89, 176, 252),   -- "Ware" in the wordmark
	MutedBlue     = Color3.fromRGB(53, 95, 152),    -- "SCRIPT HUB"
	Glow          = Color3.fromRGB(0, 88, 248),

	White         = Color3.fromRGB(235, 240, 248),
	TitleWhite    = Color3.fromRGB(245, 248, 255),
	Dim           = Color3.fromRGB(78, 88, 108),
	Dimmer        = Color3.fromRGB(62, 72, 92),
	SectionText   = Color3.fromRGB(56, 66, 86),
	IconDim       = Color3.fromRGB(66, 76, 98),

	Track         = Color3.fromRGB(8, 12, 21),
	TrackStroke   = Color3.fromRGB(30, 44, 70),
	BoxStroke     = Color3.fromRGB(30, 44, 70),
	DropBg        = Color3.fromRGB(16, 24, 41),
	DropText      = Color3.fromRGB(72, 84, 106),
	ToggleOff     = Color3.fromRGB(34, 46, 70),
	Cyan          = Color3.fromRGB(89, 176, 252),   -- default FOV colour
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function New(class, props, children)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then obj[k] = v end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	if props and props.Parent then obj.Parent = props.Parent end
	return obj
end

local function Frame(parent, x, y, w, h, color, extra)
	local f = New("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color or C.PanelBg,
		BorderSizePixel = 0,
		Parent = parent,
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
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		FontFace = font or FONT.Regular,
		TextXAlignment = xalign or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = parent,
	})
end

local function Button(parent, x, y, w, h)
	return New("TextButton", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	})
end

-- thin rotated bar, centred on (cx, cy)
local function Bar(parent, cx, cy, length, thick, rotation, color, rounded)
	local f = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(length, thick),
		Rotation = rotation or 0,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
	if rounded then Round(f) end
	return f
end

local function Circle(parent, cx, cy, d, color)
	local f = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(d, d),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Round(f)
	return f
end

---------------------------------------------------------------------------
-- Icons (drawn with frames so no asset ids are needed). Each builder receives
-- a holder frame and a colour.
---------------------------------------------------------------------------
local Icons = {}

function Icons.Pistol(h, col)          -- sidebar "Aimbot" / "Silent Aim": pistol pointing right
	local slide = Frame(h, 0.5, 2.6, 11.2, 3, col); Round(slide, 1)     -- slide
	Frame(h, 0.7, 1.6, 1.4, 1.2, col)                                    -- rear sight / hammer
	Frame(h, 9.4, 5.4, 2.3, 0.9, col)                                    -- muzzle underside
	Frame(h, 0.9, 5.2, 4.2, 1.6, col)                                    -- frame above grip
	local grip = New("Frame", {                                          -- grip, leaning back
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(3.1, 6.2),
		Size = UDim2.fromOffset(3, 5.6), Rotation = 16,
		BackgroundColor3 = col, BorderSizePixel = 0, Parent = h,
	})
	Round(grip, 1)
	local guard = New("Frame", {                                         -- trigger guard (outline)
		Position = UDim2.fromOffset(4.9, 5.6), Size = UDim2.fromOffset(3.4, 2.8),
		BackgroundTransparency = 1, Parent = h,
	})
	Round(guard, 1.4)
	Stroke(guard, col, 0.9)
	Frame(h, 5.9, 6, 0.9, 1.7, col)                                      -- trigger
end

function Icons.Skeleton(h, col)        -- sidebar "Player"
	Circle(h, 6, 2.3, 3.6, col)
	Frame(h, 2.5, 4.8, 7, 1.4, col)
	Frame(h, 5.3, 6.2, 1.4, 5.5, col)
	Frame(h, 3.3, 7.4, 5.4, 0.9, col)
	Frame(h, 3.8, 9.2, 4.4, 0.9, col)
end

-- Tintable pistol: the image asset on top, the drawn pistol underneath as a
-- fallback that is hidden once the image has actually loaded.
local function GunImage(parent, size, col)
	local holder = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local fallback = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	Icons.Pistol(fallback, col)
	local img = New("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = ASSETS.Gun,
		ImageColor3 = col,
		ScaleType = Enum.ScaleType.Fit,
		Parent = holder,
	})
	-- IsLoaded is not reliable in every executor, so ask ContentProvider whether the
	-- asset actually fetched: on success show the image, otherwise keep the drawn pistol
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
	return holder
end

function Icons.Gun(h, col)             -- sidebar "Aimbot" / "Silent Aim"
	GunImage(h, 15, col)                   -- glyph fills ~75% of the image, so oversize a little
end

function Icons.Person(h, col)          -- sidebar "Players": head centred over the body
	Circle(h, 6, 3, 4, col)                -- head spans x 4..8
	local body = Frame(h, 1, 7, 10, 4.5, col) -- body spans x 1..11, centre 6
	Round(body, 3)
end

function Icons.Lines(h, col)           -- sidebar "Lists": three bars, tight and thick
	-- whole-pixel positions (2 / 5 / 8, 2 thick) so the gaps stay identical after scaling
	for i = 0, 2 do
		local l = Frame(h, 1, 2 + i * 3, 10, 2, col)
		Round(l, 1)
	end
end

function Icons.Globe(h, col)           -- sidebar "World"
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

function Icons.Cube(h, col)            -- sidebar "Lists"
	local sq = New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(8, 8), Rotation = 45,
		BackgroundTransparency = 1, Parent = h,
	})
	Stroke(sq, col, 1)
	Frame(h, 5.55, 6, 0.9, 5.8, col)
	Bar(h, 3.6, 4.6, 5, 0.9, 30, col)
	Bar(h, 8.4, 4.6, 5, 0.9, -30, col)
end

function Icons.Gear(h, col)            -- sidebar "Miscellaneous", panel "Magic Bullet"
	Circle(h, 6, 6, 8, col)
	for _, r in ipairs({ 0, 45, 90, 135 }) do
		Bar(h, 6, 6, 12, 2.6, r, col, true)
	end
	Circle(h, 6, 6, 3.2, C.WindowBg)
end

function Icons.Bullet(h, col)          -- sidebar "Weapons": two bullets side by side
	for _, x in ipairs({ 2.2, 7.2 }) do
		local tip = Frame(h, x, 1, 2.6, 4, col); Round(tip, 1.3)          -- rounded tip
		Frame(h, x, 3, 2.6, 2, col)                                         -- square off the tip's bottom
		Frame(h, x, 5.6, 2.6, 5, col)                                       -- casing (gap = the crimp line)
		Frame(h, x - 0.3, 10.2, 3.2, 1, col)                                -- rim
	end
end

function Icons.Box(h, col)             -- sidebar "Autofarm": a shipping box
	local body = Frame(h, 1, 3.5, 10, 7.5, col); Round(body, 1)       -- box body
	Frame(h, 0.5, 1.5, 11, 2.2, col)                                   -- lid
	Frame(h, 1, 3.7, 10, 0.8, C.WindowBg)                              -- gap under the lid
	Frame(h, 5.2, 1.5, 1.6, 5, C.WindowBg)                             -- tape strip
end

function Icons.Folder(h, col)          -- sidebar "Configs"
	local tab = Frame(h, 0.5, 2.2, 4.6, 2, col); Round(tab, 1)
	local body = Frame(h, 0.5, 3.4, 11, 7.2, col); Round(body, 1)
end

function Icons.Pin(h, col)             -- sidebar "Teleports": a map pin
	Circle(h, 6, 4.5, 7.5, col)                                        -- head
	local tip = New("Frame", {                                         -- point, a rotated square under the head
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(6, 7.4),
		Size = UDim2.fromOffset(4.6, 4.6), Rotation = 45,
		BackgroundColor3 = col, BorderSizePixel = 0, Parent = h,
	})
	Circle(h, 6, 4.5, 2.8, C.WindowBg)                                 -- hole
	return tip
end

function Icons.Dot(h, col)             -- panel "Aimbot"
	Circle(h, 4.5, 4.5, 9, col)
end

function Icons.Spark(h, col)           -- panel "Triggerbot" (tiny)
	local f = Frame(h, 0, 0, 3, 6, col); Round(f, 1)
	Circle(h, 1.5, 7, 2, col)
end

function Icons.Star(h, col)            -- panel "Silent Aim"
	Bar(h, 5, 4.5, 9, 2, 0, col, true)
	Bar(h, 5, 4.5, 9, 2, 90, col, true)
	Bar(h, 5, 4.5, 6, 1.5, 45, col, true)
	Bar(h, 5, 4.5, 6, 1.5, -45, col, true)
	Circle(h, 9, 1, 2, col)
	Circle(h, 9.5, 8, 2, col)
end

local function MakeIcon(parent, builder, x, y, w, h, col)
	local holder = New("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w or 12, h or 12),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	builder(holder, col)
	return holder
end

local function Recolor(holder, col)
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("Frame") and d.BackgroundTransparency < 1 and d.BackgroundColor3 ~= C.WindowBg then
			d.BackgroundColor3 = col
		elseif d:IsA("ImageLabel") then
			d.ImageColor3 = col
		elseif d:IsA("UIStroke") then
			d.Color = col
		end
	end
end

---------------------------------------------------------------------------
-- Screen / window
---------------------------------------------------------------------------
local Library = { Config = {}, Pages = {}, Panels = {} }

local parentGui
do
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then parentGui = hui end
	if not parentGui then
		local ok2, core = pcall(function() return game:GetService("CoreGui") end)
		if ok2 and core then parentGui = core end
	end
	if not parentGui then
		parentGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
end

local Screen = New("ScreenGui", {
	Name = "VisionWare",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 999999990,        -- above every Roblox core / game gui
})
pcall(function() Screen.OnTopOfCoreBlur = true end)
pcall(function() Screen.Parent = parentGui end)
if not Screen.Parent then Screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

local WIN_W, WIN_H = 480, 307

-- Holder is unscaled (so dragging works in real pixels); Window carries the UIScale.
local Holder = New("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIN_W * SCALE, WIN_H * SCALE),
	BackgroundTransparency = 1,
	Parent = Screen,
})

local Window = Frame(Holder, 0, 0, WIN_W, WIN_H, C.WindowBg)
New("UIScale", { Scale = SCALE, Parent = Window })
Stroke(Window, C.WindowBorder, 1)
Round(Window, 2)
Window.ClipsDescendants = true

-- blue glow behind the logo: a radial falloff from the top-left corner,
-- built from stacked translucent circles (same falloff as the reference menu)
do
	local layers = 14
	for i = 1, layers do
		local r = 95 * (1 - (i - 1) / layers)
		local c = Circle(Window, 0, 0, r * 2, C.Glow)
		c.BackgroundTransparency = 1 - 0.0125
		c.ZIndex = 1
	end
end

-- VisionWare header: "V" logo, then the wordmark laid out like the banner
-- ("Vision" white, "Ware" light blue, "SCRIPT HUB" small and muted underneath)
do
	New("ImageLabel", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(24, 19),          -- logo aspect 420:336
		BackgroundTransparency = 1,
		Image = ASSETS.Logo,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2, Parent = Window,
	})
	local word = Label(Window, 39, 7, 110, 14, "", 11.5, C.White, FONT.Bold)
	word.RichText = true
	word.Text = 'Vision<font color="#59B0FC">Ware</font>'
	word.ZIndex = 2
	local sub = Label(Window, 40, 20, 110, 8, "S C R I P T   H U B", 4.6, C.MutedBlue, FONT.Medium)
	sub.ZIndex = 2
end

-- sidebar divider (x = 150) and footer (y = 293..305)
Frame(Window, 150, 0, 1, 293, C.SidebarLine)
local Footer = Frame(Window, 0, 293, WIN_W, 13, C.Footer)
Label(Footer, 189, 0, 140, 13, "VisionWare [beta]", TS.Footer, C.SectionText, FONT.Regular)


-- pages container
local PagesHolder = New("Frame", {
	Position = UDim2.fromOffset(151, 2),
	Size = UDim2.fromOffset(327, 291),
	BackgroundTransparency = 1,
	Parent = Window,
})

---------------------------------------------------------------------------
-- Sidebar
---------------------------------------------------------------------------
local Sidebar = New("Frame", { Size = UDim2.fromOffset(150, 293), BackgroundTransparency = 1, ZIndex = 4, Parent = Window })

local SelHighlight = Frame(Sidebar, 13, 56, 113, 22, C.Highlight, { ZIndex = 4 })
Round(SelHighlight, 3)
local SelIndicator = Frame(Sidebar, 11, 60, 2, 15, C.RedDark, { ZIndex = 5 })
Round(SelIndicator, 1)

local SidebarItems = {}
local CurrentPage

local function SelectItem(item)
	for _, it in ipairs(SidebarItems) do
		local on = (it == item)
		it.Text.TextColor3 = on and C.White or C.Dimmer
		Recolor(it.Icon, on and C.Red or C.IconDim)
		it.Page.Visible = on
	end
	SelHighlight.Position = UDim2.fromOffset(13, item.Y - 10.5)
	SelIndicator.Position = UDim2.fromOffset(11, item.Y - 7)
	CurrentPage = item.Page
end

local function SectionLabel(text, yCenter)
	Label(Sidebar, 14, yCenter - 6, 120, 12, text, TS.Section, C.SectionText, FONT.Medium).ZIndex = 5
end

local function SidebarItem(text, pageTitle, yCenter, iconBuilder)
	-- pages scroll vertically so a tab can hold more panels than the window shows
	local page = New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = C.Red, ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(), Visible = false, Parent = PagesHolder,
	})
	Library.Pages[text] = page

	local icon = MakeIcon(Sidebar, iconBuilder, 29, yCenter - 6, 12, 12, C.IconDim)
	icon.ZIndex = 5
	for _, d in ipairs(icon:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex = 5 end end
	local lbl = Label(Sidebar, 47, yCenter - 7, 100, 14, text, TS.SideItem, C.Dimmer, FONT.Medium)
	lbl.ZIndex = 5

	local item = { Text = lbl, Icon = icon, Page = page, Y = yCenter, PageTitle = pageTitle }
	table.insert(SidebarItems, item)

	local btn = Button(Sidebar, 13, yCenter - 11, 113, 22)
	btn.ZIndex = 6
	btn.MouseButton1Click:Connect(function() SelectItem(item) end)
	return page
end

-- Sidebar grid: section label -> first item 17 px, item -> item 22 px,
-- last item -> next section label 20 px (uniform for every section).
-- (the whole list starts 5 px higher than the original 45.5 so the four sections
-- fit above the footer at 293)
SectionLabel("Player", 40.5)
local PageAim     = SidebarItem("Aimbot",        "Aim",           57.5,  Icons.Gun)
local PageWeapons = SidebarItem("Weapons",       "Weapons",       79.5,  Icons.Bullet)
SectionLabel("Auto", 99.5)
local PageFarm    = SidebarItem("Autofarm",      "Autofarm",      116.5, Icons.Box)
local PageTP      = SidebarItem("Teleports",     "Teleports",     138.5, Icons.Pin)
SectionLabel("Visuals", 158.5)
local PagePlayers = SidebarItem("Players",       "Players",       175.5, Icons.Person)
local PageWorld   = SidebarItem("World",         "World",         197.5, Icons.Globe)
SectionLabel("Miscellaneous", 217.5)
local PageLists   = SidebarItem("Lists",         "Lists",         234.5, Icons.Lines)
local PageMisc    = SidebarItem("Miscellaneous", "Miscellaneous", 256.5, Icons.Gear)
local PageConfigs = SidebarItem("Configs",       "Configs",       278.5, Icons.Folder)

---------------------------------------------------------------------------
-- Panel + controls
---------------------------------------------------------------------------
local Panel = {}
Panel.__index = Panel

-- one InputChanged / InputEnded pair serves every slider (each slider used to
-- own two connections, so every mouse move woke ~60 handlers)
local ActiveDrag = nil
UIS.InputChanged:Connect(function(input)
	if ActiveDrag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		ActiveDrag()
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		ActiveDrag = nil
	end
end)

-- opts: X, Y, W, H (window pixels), Title, Gun (icon after the title),
--       HeaderH, RowStart, RowGap, PadLeft, PadRight, ToggleInset, ToggleW, SliderW
local function NewPanel(page, opts)
	local self = setmetatable({}, Panel)
	self.Opts  = opts
	self.Rows  = 0
	self.Title = opts.Title
	Library.Config[opts.Title] = Library.Config[opts.Title] or {}
	self.Config = Library.Config[opts.Title]
	self.Controls = {}          -- label -> { Set = fn, Get = fn } (used by config load)
	self.Hooks    = {}          -- label -> { fn, ... } (feature code subscribes with panel:On)

	-- PagesHolder starts at window (151, 2): convert window coords to page coords
	local frame = Frame(page, opts.X - 151, opts.Y - 2, opts.W, opts.H, C.PanelBg)
	Round(frame, 3)
	Stroke(frame, C.PanelBorder, 1)
	self.Frame = frame

	Frame(frame, 0, opts.HeaderH, opts.W, 1, C.Separator)

	local titleY = opts.HeaderH / 2
	-- no header icon: the title sits flush with the row labels (PadLeft)
	local title = Label(frame, opts.PadLeft, titleY - 7, 120, 14, opts.Title, TS.Title, C.TitleWhite, FONT.Bold)
	Stroke(title, Color3.fromRGB(255, 255, 255), 1, 0.88)   -- soft glow
	self.TitleLabel = title

	-- optional gun icon right after the title text (Aimbot / Silent Aim)
	if opts.Gun then
		local width = #opts.Title * TS.Title * 0.58          -- estimate, replaced by a real measurement below
		local params = Instance.new("GetTextBoundsParams")
		params.Text, params.Font, params.Size, params.Width = opts.Title, FONT.Bold, TS.Title, 1000
		local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
		if ok and bounds and bounds.X > 0 then width = bounds.X end
		local slot = New("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(opts.PadLeft + width + 3, titleY),
			Size = UDim2.fromOffset(11, 11),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		GunImage(slot, 11, C.Red)
	end

	-- header toggle (21 x 8 pill, knob on the right when on)
	local tw, th = opts.ToggleW or 21, 8
	-- opts.NoToggle: a settings box without a master switch (always enabled)
	local toggle = Frame(frame, opts.W - opts.ToggleInset - tw, titleY - th / 2, tw, th, C.Red)
	Round(toggle)
	local knob = Circle(toggle, tw - 4, th / 2, 5, Color3.fromRGB(255, 255, 255))
	toggle.Visible = not opts.NoToggle
	-- "veil": covers every row when the section is switched off. It dims the
	-- controls and, being Active, sinks all clicks / drags so nothing below can
	-- be changed until the toggle is switched back on.
	local veil = New("Frame", {
		Position = UDim2.fromOffset(0, opts.HeaderH + 1),
		Size = UDim2.fromOffset(opts.W, opts.H - opts.HeaderH - 1),
		BackgroundColor3 = C.PanelBg,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 50,
		Parent = frame,
	})
	Round(veil, 3)

	self.Enabled = true
	self.Config["Enabled"] = true
	local function setEnabled(v)
		self.Enabled = v
		self.Config["Enabled"] = v
		toggle.BackgroundColor3 = v and C.Red or C.ToggleOff
		knob.Position = UDim2.fromOffset(v and (tw - 4) or 4, th / 2)
		veil.Visible = not v
		if not v then ActiveDrag = nil end   -- stop a slider drag that was in progress
		for _, tb in ipairs(self.LockedTextBoxes or {}) do
			tb.TextEditable = v
			if not v and tb:IsFocused() then tb:ReleaseFocus() end
		end
		self:_fire("Enabled", v)
		-- close any open dropdown / palette popups in this section
		for _, d in ipairs(frame:GetChildren()) do
			if d:IsA("Frame") and d.ZIndex == 20 then d.Visible = false end
		end
		if opts.Callback then opts.Callback(v) end
	end
	if not opts.NoToggle then
		local tbtn = Button(frame, opts.W - opts.ToggleInset - tw - 3, titleY - th / 2 - 3, tw + 6, th + 6)
		tbtn.MouseButton1Click:Connect(function() setEnabled(not self.Enabled) end)
	end
	self.SetEnabled = setEnabled

	Library.Panels[opts.Title] = self
	return self
end

-- feature hooks: panel:On("Label", fn) runs fn(value) now and on every change;
-- panel:On("Enabled", fn) follows the header toggle.
function Panel:On(key, fn)
	self.Hooks[key] = self.Hooks[key] or {}
	table.insert(self.Hooks[key], fn)
	local cur = self.Config[key]
	if cur ~= nil then task.spawn(fn, cur) end
end
function Panel:_fire(key, v)
	local hooks = self.Hooks[key]
	if not hooks then return end
	for _, fn in ipairs(hooks) do
		task.spawn(function()
			local ok, err = pcall(fn, v)
			if not ok then warn("[VisionWare] " .. self.Title .. " / " .. key .. ": " .. tostring(err)) end
		end)
	end
end

-- while the panel's big switch is off, no control in it accepts input
function Panel:_locked(): boolean
	return self.Enabled == false
end

function Panel:_nextRow()
	local y = self.Opts.RowStart + self.Rows * self.Opts.RowGap
	self.Rows = self.Rows + 1
	return y
end

function Panel:_label(text, y, bright)
	return Label(self.Frame, self.Opts.PadLeft, y - 6, 110, 12, text, TS.Row, bright and C.White or C.Dim, FONT.Medium)
end

function Panel:_rightEdge() return self.Opts.W - self.Opts.PadRight end

-- Checkbox: 7x7 box, red with white check when on. Label is white when on, dim when off.
-- disabled = true shows the row greyed out and ignores clicks (e.g. "coming soon")
function Panel:Checkbox(text, default, callback, disabled)
	local y = self:_nextRow()
	local lbl = self:_label(text, y, default)
	-- 6x6, radius 2, no border: same height and right edge as the dropdown boxes.
	-- Off = dark filled box (like an empty dropdown), on = accent fill. No tick.
	local box = Frame(self.Frame, self:_rightEdge() - 6, y - 3, 6, 6, C.DropBg)
	Round(box, 2)

	local state = default and true or false
	local function apply(v)
		state = v
		self.Config[text] = v
		box.BackgroundColor3 = v and C.CheckRed or C.DropBg
		lbl.TextColor3 = v and C.White or C.Dim
		if callback then callback(v) end
		self:_fire(text, v)
	end
	apply(state)
	if disabled then
		lbl.TextColor3 = C.SectionText
		box.BackgroundTransparency = 0.5
	end

	local btn = Button(self.Frame, 0, y - 5.5, self.Opts.W, 11)
	btn.MouseButton1Click:Connect(function() if disabled or self:_locked() then return end apply(not state) end)
	local ctl = { Set = apply, Get = function() return state end }
	self.Controls[text] = ctl
	return ctl
end

-- Keybind: dim label left, key name right ("Mouse 2"). Click the key name to rebind.
function Panel:Keybind(text, default, callback)
	local y = self:_nextRow()
	self:_label(text, y, false)
	local keyLbl = Label(self.Frame, self:_rightEdge() - 60, y - 6, 60, 12, default, TS.Key, Color3.fromRGB(66, 66, 66), FONT.Regular, Enum.TextXAlignment.Right)
	self.Config[text] = default

	local listening = false
	local btn = Button(self.Frame, self:_rightEdge() - 60, y - 6, 60, 12)
	btn.MouseButton1Click:Connect(function()
		if listening or self:_locked() then return end
		listening = true
		keyLbl.Text = "..."
		local conn
		conn = UIS.InputBegan:Connect(function(input)
			local name
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					name = self.Config[text]
				else
					name = input.KeyCode.Name
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then name = "Mouse 1"
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then name = "Mouse 2"
			elseif input.UserInputType == Enum.UserInputType.MouseButton3 then name = "Mouse 3"
			end
			if name then
				conn:Disconnect()
				listening = false
				keyLbl.Text = name
				self.Config[text] = name
				if callback then callback(name) end
				self:_fire(text, name)
			end
		end)
	end)
	local ctl = {
		Set = function(name)
			keyLbl.Text = name
			self.Config[text] = name
			if callback then callback(name) end
			self:_fire(text, name)
		end,
		Get = function() return self.Config[text] end,
	}
	self.Controls[text] = ctl
	return ctl
end

-- Slider: 73 x 4 pill track, red fill, with the current number shown just left of
-- the track. Whole-number sliders (whole min / max / default, range of 10 or more)
-- snap to whole numbers; small ranges such as Menu Scale keep their exact value and
-- show one decimal. showValue: nil = automatic, "decimal" = always one decimal,
-- false = no number.
function Panel:Slider(text, min, max, default, callback, showValue)
	local isInt = function(n) return n == math.floor(n) end
	local whole = showValue ~= "decimal" and isInt(min) and isInt(max) and isInt(default) and (max - min) >= 10
	if showValue == nil or showValue == "decimal" then showValue = true end
	local y = self:_nextRow()
	self:_label(text, y, false)
	local w = self.Opts.SliderW
	local track = Frame(self.Frame, self:_rightEdge() - w, y - 2, w, 4, C.Track)
	Round(track)
	Stroke(track, C.TrackStroke, 1)
	local fill = Frame(track, 0, 0, 0, 4, C.Red)
	Round(fill)
	local readout = showValue and Label(self.Frame, self:_rightEdge() - w - 24, y - 6, 21, 12, "", TS.Key, C.White, FONT.Medium, Enum.TextXAlignment.Right) or nil

	local function format(v: number): string
		if whole then return tostring(math.floor(v + 0.5)) end
		local str = string.format("%.1f", v)
		return (str:gsub("%.0$", ""))
	end
	local value = default
	local function apply(v)
		v = math.clamp(v, min, max)
		if whole then v = math.floor(v + 0.5) end
		value = v
		self.Config[text] = v
		if readout then readout.Text = format(v) end
		fill.Size = UDim2.fromOffset(w * (v - min) / (max - min), 4)
		if callback then callback(v) end
		self:_fire(text, v)
	end
	apply(default)

	local hit = Button(self.Frame, self:_rightEdge() - w - 3, y - 6, w + 6, 12)
	local function update()
		local mx = UIS:GetMouseLocation().X
		local frac = (mx - track.AbsolutePosition.X) / track.AbsoluteSize.X
		apply(min + math.clamp(frac, 0, 1) * (max - min))
	end
	hit.InputBegan:Connect(function(input)
		if self:_locked() then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			ActiveDrag = update
			update()
		end
	end)
	local ctl = { Set = apply, Get = function() return value end }
	self.Controls[text] = ctl
	return ctl
end

-- Dropdown: 73 x 7 box, tiny text. Click to expand.
-- dropdown text was 5.5 and hard to read; box and list rows grow with it
local DROP_TEXT_SIZE, DROP_ROW_H = 6.8, 8.5
function Panel:Dropdown(text, options, default, callback)
	local y = self:_nextRow()
	self:_label(text, y, false)
	local w = self.Opts.SliderW
	local h = DROP_ROW_H
	local box = Frame(self.Frame, self:_rightEdge() - w, y - h / 2, w, h, C.DropBg)
	Round(box, 2)
	box.ZIndex = 3
	local val = Label(box, 3, 0, w - 6, h, default, DROP_TEXT_SIZE, C.DropText, FONT.Regular)
	val.ZIndex = 4

	self.Config[text] = default

	local list = New("Frame", {
		Position = UDim2.fromOffset(self:_rightEdge() - w, y + h / 2 + 0.5),
		Size = UDim2.fromOffset(w, #options * h + 2),
		BackgroundColor3 = C.DropBg, BorderSizePixel = 0, Visible = false, ZIndex = 20, Parent = self.Frame,
	})
	Round(list, 2)
	Stroke(list, C.PanelBorder, 1)
	local open = false
	local function setOpen(v) open = v; list.Visible = v end

	local function select(opt)
		val.Text = opt
		self.Config[text] = opt
		for _, c in ipairs(list:GetDescendants()) do
			if c:IsA("TextLabel") then c.TextColor3 = (c.Text == opt) and C.White or C.DropText end
		end
		setOpen(false)
		if callback then callback(opt) end
		self:_fire(text, opt)
	end

	for i, opt in ipairs(options) do
		local ob = Button(list, 0, 1 + (i - 1) * h, w, h)
		ob.ZIndex = 21
		local ol = Label(ob, 3, 0, w - 6, h, opt, DROP_TEXT_SIZE, opt == default and C.White or C.DropText, FONT.Regular)
		ol.ZIndex = 22
		ob.MouseButton1Click:Connect(function() if self:_locked() then setOpen(false) return end select(opt) end)
	end

	local btn = Button(self.Frame, self:_rightEdge() - w, y - 5, w, 10)
	btn.ZIndex = 5
	btn.MouseButton1Click:Connect(function() if self:_locked() then return end setOpen(not list.Visible) end)
	local ctl = { Set = select, Get = function() return self.Config[text] end }
	self.Controls[text] = ctl
	return ctl
end

-- ColorPicker: 7 px round swatch. Click to pick from a small palette.
function Panel:ColorPicker(text, default, callback)
	local y = self:_nextRow()
	self:_label(text, y, true)
	local sw = Circle(self.Frame, self:_rightEdge() - 3.5, y, 7, default)
	self.Config[text] = default

	local palette = {
		C.Cyan, Color3.fromRGB(255, 26, 6), Color3.fromRGB(255, 170, 0), Color3.fromRGB(80, 255, 80),
		Color3.fromRGB(70, 130, 255), Color3.fromRGB(200, 60, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 80, 180),
	}
	local pop = New("Frame", {
		Position = UDim2.fromOffset(self:_rightEdge() - 7 - #palette * 9 - 4, y - 5),
		Size = UDim2.fromOffset(#palette * 9 + 3, 10),
		BackgroundColor3 = C.DropBg, BorderSizePixel = 0, Visible = false, ZIndex = 20, Parent = self.Frame,
	})
	Round(pop, 2)
	Stroke(pop, C.PanelBorder, 1)
	local function setColor(col)
		sw.BackgroundColor3 = col
		self.Config[text] = col
		pop.Visible = false
		if callback then callback(col) end
		self:_fire(text, col)
	end
	for i, col in ipairs(palette) do
		local b = Button(pop, 2 + (i - 1) * 9, 1.5, 7, 7)
		b.ZIndex = 21
		b.BackgroundTransparency = 0
		b.BackgroundColor3 = col
		Round(b)
		b.MouseButton1Click:Connect(function() if self:_locked() then pop.Visible = false return end setColor(col) end)
	end

	local btn = Button(self.Frame, self:_rightEdge() - 10, y - 5, 10, 10)
	btn.ZIndex = 5
	btn.MouseButton1Click:Connect(function() if self:_locked() then return end pop.Visible = not pop.Visible end)
	local ctl = { Set = setColor, Get = function() return self.Config[text] end }
	self.Controls[text] = ctl
	return ctl
end

-- Button: a full-width pill with centred text. Runs callback on click.
function Panel:Button(text, callback)
	local y = self:_nextRow()
	local w = self:_rightEdge() - self.Opts.PadLeft
	local box = Frame(self.Frame, self.Opts.PadLeft, y - 4.5, w, 9, C.DropBg)
	Round(box, 2)
	Stroke(box, C.PanelBorder, 1)
	local lbl = Label(box, 0, 0, w, 9, text, TS.Row, C.White, FONT.Medium, Enum.TextXAlignment.Center)
	local btn = Button(self.Frame, self.Opts.PadLeft, y - 5.5, w, 11)
	btn.MouseButton1Down:Connect(function() box.BackgroundColor3 = C.ToggleOff end)
	btn.MouseButton1Up:Connect(function() box.BackgroundColor3 = C.DropBg end)
	btn.MouseLeave:Connect(function() box.BackgroundColor3 = C.DropBg end)
	btn.MouseButton1Click:Connect(function()
		if self:_locked() then return end
		if callback then
			local ok, err = pcall(callback)
			if not ok then warn("[VisionWare] " .. text .. ": " .. tostring(err)) end
		end
	end)
	return { SetText = function(t) lbl.Text = t end }
end

-- Info: read-only row, dim label left and a white value right. Returns { Set = fn(text) }.
function Panel:Info(text, value)
	local y = self:_nextRow()
	self:_label(text, y, false)
	local w = self.Opts.SliderW
	local val = Label(self.Frame, self:_rightEdge() - w, y - 6, w, 12, value or "", TS.Row, C.White, FONT.Medium, Enum.TextXAlignment.Right)
	return { Set = function(t) val.Text = t end }
end

-- InfoBox: a read-only wrapped text area that takes `lines` rows. Returns { Set = fn(text) }.
-- mono = true uses a monospace font (terminal look).
function Panel:InfoBox(lines, text, mono)
	local y0 = self:_nextRow()
	for _ = 2, lines do self:_nextRow() end
	local w = self:_rightEdge() - self.Opts.PadLeft
	local h = (lines - 1) * self.Opts.RowGap + 10
	local box = Frame(self.Frame, self.Opts.PadLeft, y0 - 5, w, h, C.DropBg)
	Round(box, 2)
	Stroke(box, C.PanelBorder, 1)
	local lbl = Label(box, 3, 1, w - 6, h - 2, text or "", TS.Drop, C.DropText, FONT.Regular)
	lbl.TextWrapped = true
	lbl.TextYAlignment = Enum.TextYAlignment.Top
	if mono then lbl.FontFace = Font.fromEnum(Enum.Font.Code) end
	return { Set = function(t) lbl.Text = t end }
end

-- ButtonList: a scrolling list of clickable rows that takes `lines` rows of the panel.
-- Returns { Set = fn(items, onClick) } where items = { { text = ..., key = ... }, ... };
-- clicking a row calls onClick(key). An empty list shows `emptyText`.
function Panel:ButtonList(lines, emptyText)
	local y0 = self:_nextRow()
	for _ = 2, lines do self:_nextRow() end
	local w = self:_rightEdge() - self.Opts.PadLeft
	local h = (lines - 1) * self.Opts.RowGap + 10
	local box = Frame(self.Frame, self.Opts.PadLeft, y0 - 5, w, h, C.DropBg)
	Round(box, 2)
	Stroke(box, C.PanelBorder, 1)
	local scroll = New("ScrollingFrame", { Size = UDim2.new(1, -4, 1, -4), Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.Dim, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = box })
	New("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	local empty = Label(box, 3, 1, w - 6, 9, emptyText or "Empty", TS.Drop, C.DropText, FONT.Regular)
	local rowH = 9
	local panel = self
	return {
		Set = function(items, onClick)
			for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
			empty.Visible = #items == 0
			for i, item in ipairs(items) do
				local b = New("TextButton", { Size = UDim2.new(1, -3, 0, rowH), BackgroundColor3 = C.PanelBg, BackgroundTransparency = 0.35,
					AutoButtonColor = false, BorderSizePixel = 0, Text = "  " .. item.text, TextColor3 = C.White, TextSize = TS.Drop,
					FontFace = FONT.Regular, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = scroll })
				Round(b, 2)
				b.MouseEnter:Connect(function() b.BackgroundColor3 = C.ToggleOff end)
				b.MouseLeave:Connect(function() b.BackgroundColor3 = C.PanelBg end)
				b.MouseButton1Click:Connect(function()
					if panel:_locked() then return end
					if onClick then pcall(onClick, item.key) end
				end)
			end
		end,
	}
end

-- TextBox: dim label left, editable box right (same size as a dropdown).
function Panel:TextBox(text, default, callback)
	local y = self:_nextRow()
	self:_label(text, y, false)
	local w = self.Opts.SliderW
	local box = Frame(self.Frame, self:_rightEdge() - w, y - 3.5, w, 7, C.DropBg)
	Round(box, 2)
	local tb = New("TextBox", {
		Position = UDim2.fromOffset(3, 0),
		Size = UDim2.fromOffset(w - 6, 7),
		BackgroundTransparency = 1,
		Text = default or "",
		PlaceholderText = "",
		TextSize = TS.Drop,
		TextColor3 = C.White,
		FontFace = FONT.Regular,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = box,
	})
	self.Config[text] = default or ""
	self.LockedTextBoxes = self.LockedTextBoxes or {}
	table.insert(self.LockedTextBoxes, tb)
	tb.FocusLost:Connect(function()
		if self:_locked() then tb.Text = self.Config[text] or ""; return end
		self.Config[text] = tb.Text
		if callback then callback(tb.Text) end
		self:_fire(text, tb.Text)
	end)
	local ctl = {
		Set = function(v) tb.Text = v; self.Config[text] = v; self:_fire(text, v) end,
		Get = function() return tb.Text end,
	}
	self.Controls[text] = ctl
	return ctl
end

---------------------------------------------------------------------------
-- Tab content. Panels stack in two columns; each page scrolls if it overflows.
---------------------------------------------------------------------------
local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LEFT  = { PadLeft = 8, PadRight = 11, ToggleInset = 5, ToggleW = 21, SliderW = 73 }
local RIGHT = { PadLeft = 7, PadRight = 8,  ToggleInset = 7, ToggleW = 20, SliderW = 63 }
local function merge(a, b)
	local t = {}
	for k, v in pairs(a) do t[k] = v end
	for k, v in pairs(b) do t[k] = v end
	return t
end
local METRICS = { HeaderH = 13, RowStart = 21, RowGap = 11.45 }
local function PanelH(rows) return math.ceil(21 + (rows - 1) * 11.45 + 9) end

-- Column: stacks panels top-to-bottom in the left (x 158, w 160) or right (x 327, w 143) column
local function Column(page, side)
	local col = { y = 16 }
	function col:Add(title, rows, extra)
		local opts = merge(side == "L" and LEFT or RIGHT, METRICS)
		opts.X, opts.W = (side == "L") and 158 or 327, (side == "L") and 160 or 143
		opts.Y, opts.H, opts.Title = self.y, PanelH(rows), title
		if extra then for k, v in pairs(extra) do opts[k] = v end end
		local p = NewPanel(page, opts)
		self.y = self.y + opts.H + 7
		return p
	end
	return col
end

local HITBOXES = { "Head", "Neck", "Torso", "HumanoidRootPart", "Closest", "Random" }

-- Every store register on the map: found by flying a 350-stud grid over the whole
-- map. All five are gas stations (GasStationWorker behind the counter).
Library.ShopRegisters = {   -- (a field, not a local: the main chunk is at Luau's 200-local limit)
	Vector3.new(559.5, 52.8, 119.4),
	Vector3.new(884.1, 52.9, -373.3),
	Vector3.new(1183.3, 52.9, -378.4),
	Vector3.new(291.1, 52.7, 137.3),
	Vector3.new(1165.9, 70.6, 595.9),
}

-- Gun store stock (measured from workspace.Map.GunStore). Wall slots 21-30 need the
-- Premium / VIP gamepass (the store UI refuses them without it) and are left out;
-- nothing on the walls costs Robux. Live prices / levels are read from the store
-- when it is streamed in; these are the fallback.
local GUN_STORE = {
	{ Name = "Ruger",       Price = 800,   Level = 0,  Slot = "1" },
	{ Name = "Makarov",     Price = 1000,  Level = 0,  Slot = "2" },
	{ Name = "Glock17",     Price = 1200,  Level = 0,  Slot = "3" },
	{ Name = "Mac",         Price = 3000,  Level = 3,  Slot = "4" },
	{ Name = "Tec-9",       Price = 3500,  Level = 5,  Slot = "5" },
	{ Name = "UMP",         Price = 4800,  Level = 5,  Slot = "6" },
	{ Name = "Shotgun",     Price = 5000,  Level = 5,  Slot = "7" },
	{ Name = "Glock19X",    Price = 5000,  Level = 3,  Slot = "8" },
	{ Name = "AUG",         Price = 5000,  Level = 5,  Slot = "9" },
	{ Name = "Draco",       Price = 5200,  Level = 5,  Slot = "10" },
	{ Name = "GlockSwitch", Price = 5400,  Level = 5,  Slot = "11" },
	{ Name = "ARPistol",    Price = 5000,  Level = 5,  Slot = "12" },
	{ Name = "HoneyBadger", Price = 5500,  Level = 5,  Slot = "13" },
	{ Name = "AK-47",       Price = 6500,  Level = 5,  Slot = "14" },
	{ Name = "Vector",      Price = 7000,  Level = 5,  Slot = "15" },
	{ Name = "MP5",         Price = 7500,  Level = 10, Slot = "16" },
	{ Name = "TSR-15",      Price = 8000,  Level = 10, Slot = "17" },
	{ Name = "BinaryG17",   Price = 7000,  Level = 10, Slot = "18" },
	{ Name = "AKS-74U",     Price = 8500,  Level = 15, Slot = "19" },
	{ Name = "Scar-17",     Price = 10000, Level = 20, Slot = "20" },
}
local AMMO_STORE = {   -- GWall
	{ Name = "Pistol",  Price = 50,  Slot = "1" },
	{ Name = "Rifle",   Price = 100, Slot = "2" },
	{ Name = "SMG",     Price = 100, Slot = "3" },
	{ Name = "Shotgun", Price = 100, Slot = "4" },
}
local GUN_LABELS, GUN_BY_LABEL = {}, {}
for _, g in ipairs(GUN_STORE) do
	local label = g.Level > 0 and ("%s  $%d  L%d"):format(g.Name, g.Price, g.Level) or ("%s  $%d"):format(g.Name, g.Price)
	GUN_LABELS[#GUN_LABELS + 1] = label
	GUN_BY_LABEL[label] = g
end
local AMMO_LABELS = {}
for _, a in ipairs(AMMO_STORE) do AMMO_LABELS[#AMMO_LABELS + 1] = a.Name end

-- Aim tab ---------------------------------------------------------------------
do
	local L, R = Column(PageAim, "L"), Column(PageAim, "R")

	local Aimbot = L:Add("Aimbot", 16, { Gun = true })
	Aimbot:Checkbox("Enable Aimbot", false)
	Aimbot:Keybind("Aimbot Hotkey", "Mouse 2")
	Aimbot:Dropdown("Aim Mode", { "Camera", "Mouse", "Silent" }, "Camera")
	Aimbot:Dropdown("Target Priority", { "Closest To Crosshair", "Closest Distance", "Lowest Health", "Highest Threat" }, "Closest To Crosshair")
	Aimbot:Dropdown("Hitbox", HITBOXES, "Head")
	Aimbot:Checkbox("Visible Check", false)
	Aimbot:Checkbox("Ignore Downed", false)
	Aimbot:Checkbox("Sticky Aim", false)
	Aimbot:Checkbox("Auto Shoot", false)
	Aimbot:Slider("Field Of View", 0, 100, 82)
	Aimbot:Slider("Smooth", 0, 100, 63)
	Aimbot:Dropdown("Smooth Type", { "Linear", "Exponential", "Humanized" }, "Linear")
	Aimbot:Slider("Aim Distance", 0, 100, 94)
	Aimbot:Checkbox("FOV Circle", false)
	Aimbot:ColorPicker("FOV Color", C.Cyan)
	Aimbot:Checkbox("Show Target", false)

	-- Weapon Mods lives on the Weapons tab
	local WeaponMods = Column(PageWeapons, "L"):Add("Weapon Mods", 9)
	WeaponMods:Checkbox("Rapid Fire", false)
	WeaponMods:Slider("Fire Rate", 1, 8, 8)          -- x normal fire rate (8x measured as fully counted by the server)
	WeaponMods:Checkbox("Force Automatic", false)
	WeaponMods:Checkbox("Auto Reload", false)
	WeaponMods:Checkbox("No Recoil", false)
	WeaponMods:Checkbox("No Spread", false)
	WeaponMods:Checkbox("No Sway", false)
	WeaponMods:Checkbox("Infinite Range", false)
	WeaponMods:Checkbox("No Bullet Drop", false)

	-- Auto Buy (Weapons tab, right column): gun store purchases through the GunBuy remote
	local WeaponsR = Column(PageWeapons, "R")      -- one column object, so the boxes stack under each other
	local AutoBuy = WeaponsR:Add("Auto Buy", 7, { NoToggle = true })
	AutoBuy:Dropdown("Weapon", GUN_LABELS, GUN_LABELS[3])
	AutoBuy:Button("Buy Weapon", function() if Library.AutoBuy then Library.AutoBuy.BuyWeapon() end end)
	AutoBuy:Button("Buy All Weapons", function() if Library.AutoBuy then Library.AutoBuy.BuyAll() end end)
	AutoBuy:Dropdown("Ammo", AMMO_LABELS, AMMO_LABELS[1])
	AutoBuy:Slider("Ammo Amount", 1, 20, 1)
	AutoBuy:Button("Buy Ammo", function() if Library.AutoBuy then Library.AutoBuy.BuyAmmo() end end)
	AutoBuy:Checkbox("Auto Buy Ammo", false)      -- keeps one ammo box for every gun you own

	-- Auto Safe (Weapons tab, under Auto Buy): moves your stuff into your safe storage
	local AutoSafe = WeaponsR:Add("Auto Safe", 8, { NoToggle = true })
	AutoSafe:Checkbox("Auto Safe", false)         -- keeps storing backpack items (never the one in your hand)
	AutoSafe:Dropdown("Store", { "Everything", "Weapons", "Jewels & Items" }, "Everything")
	AutoSafe:Button("Store All Now", function() if Library.AutoSafe then Library.AutoSafe.StoreAll() end end)
	AutoSafe:Button("Take All Out", function() if Library.AutoSafe then Library.AutoSafe.TakeAll() end end)
	-- what is in the safe right now (filled in by section 9h)
	AutoSafe.SafeCount = AutoSafe:Info("In Safe", "0 / 10")
	AutoSafe.SafeList = AutoSafe:ButtonList(3, "Empty")       -- click an item to take one out

	local SilentAim = R:Add("Silent Aim", 9, { Gun = true })       -- always on while enabled (no hotkey)
	SilentAim:Checkbox("Enable Silent Aim", false)
	SilentAim:Dropdown("Hitbox", HITBOXES, "Head")
	SilentAim:Slider("Field Of View", 0, 100, 65)
	SilentAim:Slider("Hit Chance", 0, 100, 100)
	SilentAim:Checkbox("Visible Check", false)
	SilentAim:Checkbox("Closest Part", false)
	SilentAim:Checkbox("FOV Circle", false)
	SilentAim:ColorPicker("FOV Color", C.Cyan)
	SilentAim:Checkbox("Show Target", false)

	-- Kill Aura (under Silent Aim): fires your gun at the nearest player in range,
	-- all around you, through the same bullet redirect as Silent Aim (section 9f)
	local KillAura = R:Add("Kill Aura", 4, { Gun = true })        -- always hits the head
	KillAura:Checkbox("Enable Kill Aura", false)
	KillAura:Slider("Range", 10, 300, 100)
	KillAura:Checkbox("Visible Check", false)     -- off = shoots through walls
	KillAura:Checkbox("Ignore Downed", false)
	-- the header switches stay on; every option inside starts off, so nothing runs
	-- until its Enable option is ticked

end

-- Players tab (Visuals) ---------------------------------------------------------
do
	local L, R = Column(PagePlayers, "L"), Column(PagePlayers, "R")

	local Local = L:Add("Local", 6)
	Local:Checkbox("Custom FOV", false)
	Local:Slider("Field Of View", 70, 120, 70)
	Local:Checkbox("Freecam", false)
	Local:Keybind("Freecam Key", "F")
	Local:Slider("Freecam Speed", 1, 100, 20)
	Local:Checkbox("Remove Camera Movements", false)

	local ESPStyle = L:Add("ESP Settings", 9)
	-- defaults follow the menu theme: a softer take on the accent blue, menu white,
	-- dim blue-grey, the menu font
	ESPStyle:ColorPicker("Box Color", Color3.fromRGB(72, 112, 184))
	ESPStyle:ColorPicker("Name Color", C.White)
	ESPStyle:ColorPicker("Skeleton Color", C.White)
	ESPStyle:ColorPicker("Hidden Color", C.Dim)
	ESPStyle:Dropdown("Font", { "Menu", "Plex", "Monospace", "System", "UI" }, "Menu")
	ESPStyle:Slider("Text Size", 6, 16, 10)
	ESPStyle:Checkbox("Text Outline", true)
	ESPStyle:Slider("Box Thickness", 1, 4, 1)
	ESPStyle:Checkbox("Preview Window", false)   -- 3D preview of the ESP on your own character (section 6b)

	local Others = R:Add("Others", 9)
	Others:Checkbox("Box ESP", false)
	Others:Dropdown("Box Type", { "2D", "Corner" }, "2D")
	Others:Checkbox("Name ESP", false)
	Others:Checkbox("Health Bar", false)
	Others:Checkbox("Health Text", false)
	Others:Checkbox("Distance ESP", false)
	Others:Checkbox("Skeleton", false)
	Others:Checkbox("Show Downed", true)
	Others:Slider("ESP Distance", 50, 2000, 500)

end

-- World tab ----------------------------------------------------------------------
do
	local L, R = Column(PageWorld, "L"), Column(PageWorld, "R")

	local World = L:Add("World", 13)
	World:Checkbox("Fullbright", false)
	World:Slider("Brightness", 0, 10, 1, nil, "decimal")
	World:Checkbox("No Fog", false)
	World:Checkbox("No Shadows", false)
	World:Slider("Time Of Day", 0, 24, 14, nil, "decimal")
	World:Checkbox("Remove Sky", false)
	World:Checkbox("Remove Clouds", false)
	World:Checkbox("Remove Textures", false)
	World:Checkbox("Remove Water", false)
	World:Checkbox("Remove Glow / Lights", false)
	World:Checkbox("Remove Sun Rays", false)
	World:Checkbox("Render Entire Map (-FPS)", false)   -- streams the whole map in and keeps it loaded (section 9m)
	World:Checkbox("FPS Booster", false)                -- hides walk-through map props: trees, lamp posts... (section 8)

	local Visual = R:Add("Visual", 8)
	Visual:Checkbox("Crosshair", false)
	Visual:Dropdown("Crosshair Type", { "Cross", "Dot", "Circle", "Plus", "T" }, "Cross")
	Visual:Slider("Crosshair Size", 2, 30, 8)
	Visual:Slider("Crosshair Gap", 0, 20, 4)
	Visual:ColorPicker("Crosshair Color", C.Cyan)
	Visual:Checkbox("Watermark", true)
	Visual:Slider("Watermark Size", 8, 28, 16)
	Visual:Checkbox("Notifications", true)

end

-- Teleports tab: click a place to go there with the scooter method (your scooter,
-- or a rented one, same as the farms). Lists are filled by section 9n.
do
	local L, R = Column(PageTP, "L"), Column(PageTP, "R")
	local Places = L:Add("Locations", 17, { NoToggle = true })
	Places.List = Places:ButtonList(17, "Loading...")
	local Dealers = R:Add("Dealers & Buyers", 11, { NoToggle = true })
	Dealers.List = Dealers:ButtonList(11, "Loading...")
	local TP = R:Add("Teleport", 4, { NoToggle = true })
	TP:Checkbox("Show Path", false)      -- draws the path finder's route and outlines what it treats as walls
	TP:Button("Walk To Scooter", function() if Library.Teleports then Library.Teleports.WalkToScooter() end end)
	-- camera on your scooter wherever it is; click again to come back (section 9n)
	TP.ViewButton = TP:Button("View Scooter", function() if Library.Teleports then Library.Teleports.ViewScooter() end end)
	TP:Button("Refresh Lists", function() if Library.Teleports then Library.Teleports.Refresh() end end)
end

-- Lists tab: static player list. Built when the tab is opened, torn down when
-- it is closed, no per-frame or timed work. Each row has Spectate / Stop and TP.
do
	local panel = NewPanel(PageLists, merge(merge(LEFT, METRICS), { X = 158, Y = 16, W = 312, H = 266, Title = "Player List" }))
	local f = panel.Frame
	for _, c in ipairs({ { "Player", 8, 120 }, { "Health", 150, 60 }, { "Dist", 214, 34 } }) do
		Label(f, c[2], 15, c[3], 10, c[1], TS.Drop + 0.5, C.Dim, FONT.Medium)
	end
	Frame(f, 4, 27, 304, 1, C.Separator)
	local scroll = New("ScrollingFrame", {
		Position = UDim2.fromOffset(4, 29), Size = UDim2.fromOffset(304, 266 - 33),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = C.Red,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = f,
	})
	New("UIListLayout", { SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 1), Parent = scroll })

	local rows = {}
	Library.ListRows = rows
	Library.SpectateTarget = nil

	local function smallButton(parent, x, w, text, cb)
		local box = Frame(parent, x, 1.5, w, 8, C.DropBg); Round(box, 2)
		local lbl = Label(box, 0, 0, w, 8, text, TS.Drop, C.White, FONT.Medium, Enum.TextXAlignment.Center)
		local b = Button(parent, x, 1.5, w, 8)
		b.MouseButton1Click:Connect(function() pcall(cb) end)
		return lbl
	end
	local function teleportTo(plr)
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		local mine = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if root and mine then
			mine.CFrame = root.CFrame * CFrame.new(0, 0, 3)
			if Library.Notify then Library.Notify("Teleported to " .. plr.DisplayName) end
		elseif Library.Notify then
			Library.Notify(plr.DisplayName .. " has no character right now")
		end
	end
	local function newRow(plr)
		local r = New("Frame", {
			Name = plr.Name, Size = UDim2.fromOffset(304, 11),
			BackgroundColor3 = C.DropBg, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = scroll,
		})
		Round(r, 2)
		local isMe = plr == Players.LocalPlayer
		local shown = isMe and ((Library.ShownName and Library.ShownName() or plr.DisplayName) .. " (you)") or plr.DisplayName
		Label(r, 4, 0, 130, 11, shown, TS.Drop + 0.5, isMe and C.LightBlue or C.White, FONT.Medium)
		local hp   = Label(r, 146, -1, 60, 11, "-", TS.Drop + 0.5, C.Dim, FONT.Regular)
		local bar  = Frame(r, 146, 8.5, 50, 1.5, C.Track); Round(bar)
		local fill = Frame(bar, 0, 0, 0, 1.5, C.Red); Round(fill)
		local dist = Label(r, 210, 0, 34, 11, "-", TS.Drop + 0.5, C.Dim, FONT.Regular)
		local row = { Frame = r, Hp = hp, Fill = fill, Dist = dist, Player = plr }
		if not isMe then
			row.Spec = smallButton(r, 246, 34, Library.SpectateTarget == plr and "Stop" or "Spectate", function()
				if Library.Spectate then
					if Library.SpectateTarget == plr then Library.Spectate(nil) else Library.Spectate(plr) end
				end
			end)
			smallButton(r, 283, 18, "TP", function() teleportTo(plr) end)
		end
		return row
	end
	local function fillRow(row, myRoot)
		local plr = row.Player
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			row.Hp.Text = string.format("%d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth))
			row.Fill.Size = UDim2.fromOffset(50 * math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1.5)
		else
			row.Hp.Text = "dead"
			row.Fill.Size = UDim2.fromOffset(0, 1.5)
		end
		local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if myRoot and root and plr ~= Players.LocalPlayer then
			row.Dist.Text = string.format("%dm", (myRoot.Position - root.Position).Magnitude)
		else
			row.Dist.Text = "-"
		end
	end
	local function build()
		local me = Players.LocalPlayer
		local myRoot = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
		for _, plr in ipairs(Players:GetPlayers()) do
			local row = newRow(plr)
			rows[plr] = row
			pcall(fillRow, row, myRoot)
		end
	end
	local function clear()
		for plr, row in pairs(rows) do row.Frame:Destroy(); rows[plr] = nil end
	end
	-- one-shot: build when the tab opens, drop everything when it closes
	PageLists:GetPropertyChangedSignal("Visible"):Connect(function()
		clear()
		if PageLists.Visible then pcall(build) end
	end)
	-- header refresh button (re-snapshots the list without leaving the tab)
	local refreshBox = Frame(f, 228, 2.5, 52, 8, C.DropBg); Round(refreshBox, 2)
	Label(refreshBox, 0, 0, 52, 8, "Refresh", TS.Drop, C.White, FONT.Medium, Enum.TextXAlignment.Center)
	Button(f, 228, 2.5, 52, 8).MouseButton1Click:Connect(function() clear(); pcall(build) end)
end

-- Miscellaneous tab ------------------------------------------------------------
do
	local L, R = Column(PageMisc, "L"), Column(PageMisc, "R")

	local Misc = L:Add("Misc", 5)
	do
		local antiAfk
		Misc:Checkbox("Anti AFK", true, function(v)
			if antiAfk then antiAfk:Disconnect(); antiAfk = nil end
			if v then
				antiAfk = Players.LocalPlayer.Idled:Connect(function()
					local vu = game:GetService("VirtualUser")
					vu:CaptureController()
					vu:ClickButton2(Vector2.new())
				end)
			end
		end)
	end
	Misc:Keybind("Menu Key", "RightShift", function(name)
		pcall(function() TOGGLE_KEY = Enum.KeyCode[name] end)
	end)
	Misc:Keybind("Panic Key", "End", function(name)
		pcall(function() PANIC_KEY = Enum.KeyCode[name] end)
	end)
	Misc:Slider("Menu Scale", 1, 3, SCALE, function(v)
		Window.UIScale.Scale = v
		Holder.Size = UDim2.fromOffset(WIN_W * v, WIN_H * v)
		if Library.ClampWindow then Library.ClampWindow() end
	end)
	Misc:Button("Unload Menu", function() Library.Destroy() end)

	-- Autofarm tab: settings box, no master switch
	do
		local FarmL = Column(PageFarm, "L")          -- one column object, so the boxes stack
		local FarmSettings = FarmL:Add("Autofarm Settings", 5, { NoToggle = true })
		FarmSettings:Slider("Travel Speed", 10, 30, 25)   -- the script's TWEEN_SPEED (studs / s), 30 max
		FarmSettings:Checkbox("Auto Respawn", true)
		FarmSettings:Checkbox("Auto Deposit", false)    -- banks everything above $1,000 of cash
		FarmSettings:Checkbox("Auto Buy Gun", true)     -- Shops farm: buys a Ruger ($800) when you have no gun
		FarmSettings:Slider("Min Register Cash", 2500, 15000, 2500)  -- Shops farm: skip registers with less (the game refuses under $2,500)

		-- Farm Terminal (under the settings): farming time, money made, recent log
		local Term = FarmL:Add("Farm Terminal", 14, { NoToggle = true })
		Term.Time = Term:Info("Farming Time", "00:00:00")
		Term.Earned = Term:Info("Earned", "$0")
		Term.Spent = Term:Info("Spent", "$0")
		Term.Net = Term:Info("Net", "$0")
		Term.Cooldowns = Term:InfoBox(4, "> checking cooldowns...", true)   -- shops, airdrop, oil rig, box job
		Term.Log = Term:InfoBox(5, "> waiting for a farm to start", true)
		Term:Button("Reset Stats", function() if Library.FarmStats then Library.FarmStats.Reset() end end)

		-- Farms: one toggle per farm (right column)
		local Farms = Column(PageFarm, "R"):Add("Farms", 8)
		Farms:Checkbox("Box Job", false)
		Farms:Checkbox("Oil Rig", false)
		Farms:Checkbox("Airdrops", false)
		Farms:Checkbox("Steal Farm", false)
		Farms:Checkbox("Shops", false)
		Farms:Checkbox("Yacht", false)
		Farms:Checkbox("City Driver", false)
		Farms:Checkbox("VIP (Soon)", false, nil, true)
	end

	-- Streamer box, under the Misc box in the Misc tab
	local Streamer = L:Add("Streamer", 7)
	Streamer:Checkbox("Streamer Mode", false)
	Streamer:Checkbox("Hide Level", false)      -- your overhead level badge shows the VisionWare logo
	Streamer:TextBox("Spoof User ID", "")
	Streamer:TextBox("Cash", "")          -- blank = spoof target's value, or hidden
	Streamer:TextBox("Bank", "")
	Streamer:TextBox("Card Balance", "")  -- the balances shown on the phone
	Streamer:TextBox("Level", "")         -- overhead level badge + level-up popup

	local Server = R:Add("Server", 7)
	Server:Button("Rejoin Server", function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Players.LocalPlayer)
	end)
	local function hop(smallest)
		local req = (syn and syn.request) or (http and http.request) or http_request or request
		if not req then warn("[VisionWare] this executor has no HTTP request function") return end
		local order = smallest and "Asc" or "Desc"
		local res = req({ Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. order .. "&limit=100", Method = "GET" })
		local data = HttpService:JSONDecode(res.Body)
		for _, s in ipairs(data.data or {}) do
			if s.id ~= game.JobId and s.playing < s.maxPlayers then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, Players.LocalPlayer)
				return
			end
		end
		warn("[VisionWare] no other server with free slots found")
	end
	Server:Button("Server Hop", function() hop(false) end)
	Server:Button("Smallest Server", function() hop(true) end)
	Server:Button("Copy Job ID", function()
		local copy = setclipboard or toclipboard
		if copy then copy(game.JobId) else warn("[VisionWare] no clipboard function") end
	end)
	local jobBox = Server:TextBox("Job ID", "")
	Server:Button("Join Job ID", function()
		local id = jobBox.Get()
		if id ~= "" then TeleportService:TeleportToPlaceInstance(game.PlaceId, id, Players.LocalPlayer) end
	end)
	Server:Button("Copy Discord Invite", function()
		local copy = setclipboard or toclipboard
		if copy then copy("https://discord.gg/") end
	end)

	-- Arcade (under Server): set the score the punching bag / bird game gives you
	local Arcade = R:Add("Arcade", 4, { NoToggle = true })
	Arcade:Checkbox("Punching Bag Score", false)   -- every punch reports this strength
	Arcade:TextBox("Punch Amount", "999")          -- type any number (the game itself tops out at 999)
	Arcade:Checkbox("Bird Game Score", false)      -- pressing Play wins instantly with this score
	Arcade:Slider("Bird Amount", 1, 999, 100)

end

-- Configs tab: save / load every panel's values to <executor>/VisionWare/ --------
do
	local Configs = Column(PageConfigs, "L"):Add("Configs", 6)
	local FOLDER  = "VisionWare"
	local canFile = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
	local nameBox = Configs:TextBox("Config Name", "default")
	local function ensureFolder()
		if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(FOLDER) then makefolder(FOLDER) end
	end
	local function path(n) return FOLDER .. "/" .. (n or "default") .. ".json" end
	local function currentName()
		local n = nameBox.Get()
		return (n ~= nil and n ~= "") and n or "default"
	end
	local function encode()
		local out = {}
		for panel, vals in pairs(Library.Config) do
			out[panel] = {}
			for k, v in pairs(vals) do
				if typeof(v) == "Color3" then out[panel][k] = { __color = { v.R, v.G, v.B } } else out[panel][k] = v end
			end
		end
		return HttpService:JSONEncode(out)
	end
	local function applyData(data)
		for panel, vals in pairs(data) do
			local p = Library.Panels[panel]
			if p then
				for k, v in pairs(vals) do
					if type(v) == "table" and v.__color then v = Color3.new(v.__color[1], v.__color[2], v.__color[3]) end
					if k == "Enabled" then
						p.SetEnabled(v == true)
					elseif p.Controls[k] then
						pcall(p.Controls[k].Set, v)
					elseif type(v) ~= "table" then
						p.Config[k] = v       -- values with no control (e.g. the ESP layout sides from the preview)
					end
				end
			end
		end
	end
	local function load(n)
		if canFile and isfile(path(n)) then
			applyData(HttpService:JSONDecode(readfile(path(n))))
		else
			warn("[VisionWare] config not found: " .. tostring(n))
		end
	end
	Configs:Button("Save Config", function()
		if not canFile then warn("[VisionWare] this executor cannot write files") return end
		ensureFolder()
		writefile(path(currentName()), encode())
	end)
	Configs:Button("Load Config", function() load(currentName()) end)
	Configs:Button("Delete Config", function()
		if canFile and type(delfile) == "function" and isfile(path(currentName())) then delfile(path(currentName())) end
	end)
	Configs:Checkbox("Auto Load", false, function(v)
		if canFile then ensureFolder(); writefile(FOLDER .. "/autoload.txt", v and currentName() or "") end
	end)
	Configs:Button("Reset To Defaults", function()
		for _, p in pairs(Library.Panels) do p.SetEnabled(true) end
		warn("[VisionWare] re-execute the script to fully reset values")
	end)
	if canFile and isfile(FOLDER .. "/autoload.txt") then
		local n = readfile(FOLDER .. "/autoload.txt")
		if n ~= "" and isfile(path(n)) then
			nameBox.Set(n)
			pcall(load, n)
		end
	end
	Library.SaveConfig, Library.LoadConfig = function(n) ensureFolder(); writefile(path(n or currentName()), encode()) end, load
end

-- size each page's canvas to its tallest column
for _, page in pairs(Library.Pages) do
	local bottom = 0
	for _, child in ipairs(page:GetChildren()) do
		if child:IsA("GuiObject") then
			bottom = math.max(bottom, child.Position.Y.Offset + child.Size.Y.Offset)
		end
	end
	page.CanvasSize = UDim2.fromOffset(0, bottom + 6)
end

SelectItem(SidebarItems[1])   -- "Aimbot" selected, header reads "Aim"

---------------------------------------------------------------------------
-- Dragging (top 40 px of the window) and show / hide
---------------------------------------------------------------------------
do
	local dragging, dragStart, startPos
	-- drag handles only cover empty space: the logo area of the sidebar and the thin
	-- strip above the panels (panels start at y 18, so a taller strip would block them)
	local grips = {
		Button(Window, 0, 0, 150, 40),          -- sidebar logo area
		Button(Window, 150, 0, WIN_W - 150, 16), -- strip above the panels
	}
	for _, grip in ipairs(grips) do
		grip.ZIndex = 10
		grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = UIS:GetMouseLocation()
				startPos = Holder.Position
			end
		end)
	end
	-- keep the window fully on screen (Holder is centred, so offsets are clamped symmetrically)
	local function clampWindow(ox, oy)
		local screen, size = Screen.AbsoluteSize, Holder.AbsoluteSize
		local lx = math.max(0, (screen.X - size.X) * 0.5)
		local ly = math.max(0, (screen.Y - size.Y) * 0.5)
		return math.clamp(ox, -lx, lx), math.clamp(oy, -ly, ly)
	end
	Library.ClampWindow = function()
		local ox, oy = clampWindow(Holder.Position.X.Offset, Holder.Position.Y.Offset)
		Holder.Position = UDim2.new(0.5, ox, 0.5, oy)
	end
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = UIS:GetMouseLocation() - dragStart
			local ox, oy = clampWindow(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
			Holder.Position = UDim2.new(0.5, ox, 0.5, oy)
		end
	end)
	Screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(Library.ClampWindow)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == TOGGLE_KEY then
			Holder.Visible = not Holder.Visible
		elseif input.KeyCode == PANIC_KEY then
			Library.Destroy()
		end
	end)
end

Library.Screen   = Screen
Library.Window   = Window
Library.Toggle   = function() Holder.Visible = not Holder.Visible end
Library.IsOpen   = function() return Holder.Visible end
Library.Destroy  = function() Screen:Destroy() end
Library.NewPanel = NewPanel
Library.Icons    = Icons

---------------------------------------------------------------------------
-- FEATURES (stability / performance pass)
--
-- Layout of this section:
--   1. services, constants, Log, Maid, quality
--   2. player registry: one cached state table per other player, filled on
--      CharacterAdded, cleared on CharacterRemoving / Died / PlayerRemoving
--   3. overlay + notifications
--   4. Visual (crosshair, watermark)         - fixed-rate, event driven
--   5. Local (FOV, freecam)                  - ONE RenderStepped connection
--   6. ESP                                   - ONE RenderStepped connection
--   8. World (chunked sweeps)                - event driven
--   9. Misc hooks, chat spy, spectate
--  10. Library.Destroy -> RootMaid:Clean()
---------------------------------------------------------------------------
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local Stats            = game:GetService("Stats")
local Debris           = game:GetService("Debris")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local LP               = Players.LocalPlayer
local Cfg              = Library.Config

-- tunables ----------------------------------------------------------------
local VISIBILITY_CACHE_SECONDS   = 0.1     -- raycast reuse window per player
local CHARACTER_WAIT_SECONDS     = 10      -- WaitForChild timeout for Humanoid / root
local NOTIFY_MAX                 = 6
local NOTIFY_SECONDS             = 3
local DESCENDANT_CHUNK           = 400     -- instances handled per Heartbeat in world sweeps
local LOW_QUALITY_LEVEL          = 4       -- SavedQualityLevel <= this => reduced detail
local BOX_ASPECT                 = 0.55    -- ESP box width / height (R15 proportions)
local BOX_PAD                    = 0.25    -- studs of padding above the head / below the feet
local ESP_MAX_PLAYERS_LOW        = 12      -- nearest N players get ESP on low quality
local WATERMARK_SECONDS          = 1
local SPECTATE_CHECK_SECONDS     = 0.5
local FREECAM_LOOK_SENSITIVITY   = 0.004
local FREECAM_BOOST              = 3
local FREECAM_PITCH_LIMIT        = 1.5
local WHITE                      = Color3.fromRGB(255, 255, 255)
local BLACK                      = Color3.fromRGB(0, 0, 0)
local HEALTH_BAR_WIDTH           = 2
local HP_GRADIENT_TOP            = Color3.fromRGB(165, 165, 165)   -- health bar gradient: grey at the top ...
local HP_GRADIENT_BOTTOM         = Color3.fromRGB(0, 0, 0)         -- ... to black at the bottom

-- ESP layout: which side of the box each item sits on (dragged in the ESP preview,
-- stored in ESP Settings as "<item> Side"). Shared by the real ESP and the preview.
local ESP_ITEMS = { Name = "Top", Distance = "Bottom", ["Health Bar"] = "Left", ["Health Text"] = "Left" }
local ESP_TEXT_W = 70        -- width given to a text on the left / right of the box
local function espSide(S, item: string): string
	local v = S and S[item .. " Side"]
	if v == "Middle" and item ~= "Health Bar" then return v end     -- texts can also sit in the middle of the box
	return (v == "Top" or v == "Bottom" or v == "Left" or v == "Right") and v or ESP_ITEMS[item]
end
-- rects (x, y, w, h) for every item around the box minX, minY, w, h; items on the same
-- side stack outward, the bar hugs the box. frac = health 0..1 (the health text follows
-- the fill level when it shares a left / right side with the bar).
-- `out` (optional) is refilled in place: the real ESP passes one per player so this
-- runs every frame without allocating (it used to build ~8 tables + a closure per
-- player per frame, ~250 tables a frame with a full server)
local espLayout
do   -- own scope: the main chunk is close to Luau's 200-local limit
local function espRect(r, x: number, y: number, w: number, h: number)
	r[1], r[2], r[3], r[4] = x, y, w, h
	return r
end
local function espText(out, S, item: string, key: string, minX: number, minY: number, w: number, h: number, ts: number, frac: number, barSide: string)
	local GAP = 2
	local side = espSide(S, item)
	local th = ts + 2
	local off, down = out._off, out._down
	local r = out[key] or table.create(4)
	out[key] = r
	if side == "Middle" then
		-- centred in the box; several middle texts stack downward from the centre
		espRect(r, minX - 50, minY + h / 2 - th / 2 + out._middle, w + 100, th)
		out._middle = out._middle + th
		return Enum.TextXAlignment.Center
	elseif side == "Top" then
		espRect(r, minX - 50, minY - off.Top - GAP - th, w + 100, th)
		off.Top = off.Top + GAP + th
		return Enum.TextXAlignment.Center
	elseif side == "Bottom" then
		espRect(r, minX - 50, minY + h + off.Bottom + GAP, w + 100, th)
		off.Bottom = off.Bottom + GAP + th
		return Enum.TextXAlignment.Center
	end
	local y = minY + down[side]
	if item == "Health Text" and side == barSide then y = minY + h * (1 - frac) - ts * 0.5 else down[side] = down[side] + th end
	if side == "Left" then espRect(r, minX - off.Left - GAP - ESP_TEXT_W, y, ESP_TEXT_W, th) return Enum.TextXAlignment.Right end
	espRect(r, minX + w + off.Right + GAP, y, ESP_TEXT_W, th)
	return Enum.TextXAlignment.Left
end
function espLayout(S, minX: number, minY: number, w: number, h: number, ts: number, frac: number, out)
	local GAP = 2
	out = out or {}
	local off, down = out._off, out._down
	if not off then
		off, down = {}, {}
		out._off, out._down = off, down
	end
	off.Top, off.Bottom, off.Left, off.Right = 0, 0, 0, 0
	down.Left, down.Right = 0, 0
	out._middle = 0
	local barSide = espSide(S, "Health Bar")
	-- the bar first, so it sits right against the box
	local bw = HEALTH_BAR_WIDTH
	local bar = out.bar or table.create(4)
	out.bar = bar
	if barSide == "Left" then espRect(bar, minX - GAP - bw - 1, minY, bw, h)
	elseif barSide == "Right" then espRect(bar, minX + w + GAP + 1, minY, bw, h)
	elseif barSide == "Top" then espRect(bar, minX, minY - GAP - bw - 1, w, bw)
	else espRect(bar, minX, minY + h + GAP + 1, w, bw) end
	off[barSide] = GAP + bw + 1
	out.barVertical = barSide == "Left" or barSide == "Right"
	out.barSide = barSide
	out.nameAlign = espText(out, S, "Name", "name", minX, minY, w, h, ts, frac, barSide)
	out.distAlign = espText(out, S, "Distance", "dist", minX, minY, w, h, ts, frac, barSide)
	out.hpAlign = espText(out, S, "Health Text", "hp", minX, minY, w, h, ts, frac, barSide)
	return out
end
end
-- point the health bar fill the right way (bottom-up when vertical, left-to-right when flat)
-- memo (optional): { vertical, frac } last written, so an unchanged bar costs no writes
local function espOrientBar(fill, grad, vertical: boolean, frac: number, memo)
	if memo then
		if memo[1] == vertical and memo[2] == frac then return end
		memo[1], memo[2] = vertical, frac
	end
	if vertical then
		fill.AnchorPoint, fill.Position, fill.Size = Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, frac)
		if grad then grad.Rotation = 90 end
	else
		fill.AnchorPoint, fill.Position, fill.Size = Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(frac, 1)
		if grad then grad.Rotation = 180 end
	end
end

-- Log ---------------------------------------------------------------------
local Log = { Level = 1 } -- 0 silent, 1 warnings, 2 info
function Log.warn(...) if Log.Level >= 1 then warn("[VisionWare]", ...) end end
function Log.info(...) if Log.Level >= 2 then print("[VisionWare]", ...) end end
Library.Log = Log
-- MicroProfiler labels for the per-frame work (no-ops where the executor's debug
-- library does not have them)
Library.ProfBegin = (type(debug) == "table" and type(debug.profilebegin) == "function") and debug.profilebegin or function() end
Library.ProfEnd = (type(debug) == "table" and type(debug.profileend) == "function") and debug.profileend or function() end

-- Maid: everything created at runtime is owned by a maid ------------------
type Maid = { Add: (any, any) -> any, Clean: (any) -> () }
local function newMaid(): Maid
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
local RootMaid = newMaid()

-- quality -----------------------------------------------------------------
-- asked every ESP frame: the setting is read at most once a second (a pcall'd
-- engine read per frame for a value that changes only in the settings menu)
local isLowQuality
do
	local lowT, lowV = -math.huge, false
	function isLowQuality(): boolean
		local now = os.clock()
		if now - lowT < 1 then return lowV end
		lowT = now
		local ok, level = pcall(function() return UserGameSettings.SavedQualityLevel.Value end)
		lowV = ok and level > 0 and level <= LOW_QUALITY_LEVEL
		return lowV
	end
end

-- camera (re-read when the game swaps cameras) -----------------------------
local Camera = workspace.CurrentCamera
RootMaid:Add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if workspace.CurrentCamera then Camera = workspace.CurrentCamera end
end))
local ORIGINAL_CAMERA_TYPE = Camera.CameraType

-- local character refs
local myChar, myRoot = LP.Character, nil
local function bindMyChar(c)
	myChar = c
	task.spawn(function() myRoot = c and c:WaitForChild("HumanoidRootPart", CHARACTER_WAIT_SECONDS) or nil end)
end
if myChar then bindMyChar(myChar) end
RootMaid:Add(LP.CharacterAdded:Connect(bindMyChar))
RootMaid:Add(LP.CharacterRemoving:Connect(function() myChar, myRoot = nil, nil end))

local function P(name) return Library.Panels[name] end
local function En(name) local c = Cfg[name]; return c ~= nil and c.Enabled == true end
local function rainbow(): Color3 return Color3.fromHSV((os.clock() * 0.15) % 1, 0.85, 1) end
local function alpha(v): number return math.clamp((v or 0) / 100, 0, 1) end
local FONT_MAP = { Plex = Enum.Font.Code, Monospace = Enum.Font.RobotoMono, System = Enum.Font.SourceSans, UI = Enum.Font.Gotham }
local function fontEnum(name) return FONT_MAP[name] or Enum.Font.Code end

---------------------------------------------------------------------------
-- 2. player registry
---------------------------------------------------------------------------
local LIMB_NAMES = {
	"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
	"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}
type PlayerState = { Player: Player, Maid: Maid, CharMaid: Maid, Char: any, Hum: any, Root: any, Head: any, Tool: any, Limbs: any, Filter: any, Visible: boolean, VisT: number, Dist: number, ESP: any, IsR15: boolean }

local states = {}          -- [Player] = PlayerState
local playerList = {}      -- array of other players, rebuilt on join / leave (no GetPlayers per frame)
local onCharacterReady = {}   -- fn(state)
local onCharacterGone  = {}   -- fn(state)
local onPlayerGone     = {}   -- fn(plr)

local function rebuildPlayerList()
	table.clear(playerList)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then playerList[#playerList + 1] = plr end
	end
end

local function clearCharacter(state: PlayerState)
	if state.Char then
		for i = 1, #onCharacterGone do pcall(onCharacterGone[i], state) end
	end
	state.CharMaid:Clean()
	state.Char, state.Hum, state.Root, state.Head, state.Tool = nil, nil, nil, nil, nil
	table.clear(state.Limbs)
	state.Filter = { Camera }
end

local function bindCharacter(state: PlayerState, c)
	clearCharacter(state)
	state.CharMaid = newMaid()
	task.spawn(function()
		local hum = c:WaitForChild("Humanoid", CHARACTER_WAIT_SECONDS)
		local root = c:WaitForChild("HumanoidRootPart", CHARACTER_WAIT_SECONDS)
		if not hum or not root or c.Parent == nil or state.Player.Character ~= c then return end
		state.Char, state.Hum, state.Root, state.Head = c, hum, root, c:FindFirstChild("Head")
		state.Tool = c:FindFirstChildOfClass("Tool")
		state.IsR15 = c:FindFirstChild("UpperTorso") ~= nil
		state.Filter = { Camera, c }
		for i = 1, #LIMB_NAMES do
			local name = LIMB_NAMES[i]
			state.Limbs[name] = c:FindFirstChild(name)
		end
		state.CharMaid:Add(c.ChildAdded:Connect(function(child)
			if child:IsA("BasePart") then state.Limbs[child.Name] = child
			elseif child:IsA("Tool") then state.Tool = child end
			if child.Name == "Head" and child:IsA("BasePart") then state.Head = child end
		end))
		state.CharMaid:Add(c.ChildRemoved:Connect(function(child)
			if state.Limbs[child.Name] == child then state.Limbs[child.Name] = nil end
			if state.Tool == child then state.Tool = c:FindFirstChildOfClass("Tool") end
			if state.Head == child then state.Head = nil end
		end))
		state.CharMaid:Add(hum.Died:Connect(function()
			for i = 1, #onCharacterGone do pcall(onCharacterGone[i], state) end
		end))
		for i = 1, #onCharacterReady do pcall(onCharacterReady[i], state) end
	end)
end

local function addPlayer(plr: Player)
	if plr == LP or states[plr] then return end
	local state: PlayerState = {
		Player = plr, Maid = newMaid(), CharMaid = newMaid(),
		Char = nil, Hum = nil, Root = nil, Head = nil, Tool = nil, Limbs = {}, Filter = { Camera },
		Visible = false, VisT = 0, Dist = 0,
		ESP = nil, IsR15 = true,
	}
	states[plr] = state
	state.Maid:Add(plr.CharacterAdded:Connect(function(c) bindCharacter(state, c) end))
	state.Maid:Add(plr.CharacterRemoving:Connect(function() clearCharacter(state) end))
	if plr.Character then bindCharacter(state, plr.Character) end
	rebuildPlayerList()
end

local function removePlayer(plr: Player)
	local state = states[plr]
	if not state then return end
	clearCharacter(state)
	for i = 1, #onPlayerGone do pcall(onPlayerGone[i], plr, state) end
	state.Maid:Clean()
	states[plr] = nil
	rebuildPlayerList()
end

RootMaid:Add(Players.PlayerAdded:Connect(addPlayer))
RootMaid:Add(Players.PlayerRemoving:Connect(removePlayer))
RootMaid:Add(function() for plr in pairs(states) do removePlayer(plr) end end)

-- visibility (cached) and bounds (cached)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function isVisible(state: PlayerState, now: number): boolean
	if now - state.VisT < VISIBILITY_CACHE_SECONDS then return state.Visible end
	state.VisT = now
	local target = state.Head or state.Root
	if not target then state.Visible = false return false end
	local filter = state.Filter
	filter[3] = myChar   -- slot 3 is the local character (may be nil, which truncates the array)
	rayParams.FilterDescendantsInstances = filter
	local origin = Camera.CFrame.Position
	state.Visible = workspace:Raycast(origin, target.Position - origin, rayParams) == nil
	return state.Visible
end

---------------------------------------------------------------------------
-- 3. overlay + notifications
---------------------------------------------------------------------------
local Overlay = New("ScreenGui", { Name = "VisionWareOverlay", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 999999980 })
pcall(function() Overlay.OnTopOfCoreBlur = true end)
pcall(function() Overlay.Parent = Screen.Parent end)
if not Overlay.Parent then Overlay.Parent = LP:WaitForChild("PlayerGui") end
RootMaid:Add(Overlay)

local notifyHolder = New("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(240, 300),
	BackgroundTransparency = 1, Parent = Overlay,
})
New("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), Parent = notifyHolder })
function Library.Notify(text: string, seconds: number?)
	if Cfg.Visual and En("Visual") and Cfg.Visual["Notifications"] == false then return end
	local children = notifyHolder:GetChildren()
	local count = 0
	for i = 1, #children do if children[i]:IsA("Frame") then count = count + 1 end end
	if count >= NOTIFY_MAX then
		for i = 1, #children do if children[i]:IsA("Frame") then children[i]:Destroy() break end end
	end
	local n = New("Frame", { Size = UDim2.fromOffset(240, 28), BackgroundColor3 = C.PanelBg, BorderSizePixel = 0, Parent = notifyHolder })
	Round(n, 4); Stroke(n, C.PanelBorder, 1)
	Frame(n, 0, 0, 3, 28, C.Red)
	New("TextLabel", {
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -14, 1, 0), BackgroundTransparency = 1,
		Text = text, TextSize = 13, TextColor3 = C.White, FontFace = FONT.Medium, TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true, Parent = n,
	})
	Debris:AddItem(n, seconds or NOTIFY_SECONDS)
end

---------------------------------------------------------------------------
-- 4. Visual: crosshair on the cursor, draggable watermark (text at 1 Hz)
---------------------------------------------------------------------------
do
	-- the crosshair gets its own gui above the menu, so it is never hidden by the window
	local CrossGui = New("ScreenGui", { Name = "VisionWareCrosshair", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 999999999 })
	pcall(function() CrossGui.OnTopOfCoreBlur = true end)
	CrossGui.Parent = Overlay.Parent
	RootMaid:Add(CrossGui)
	local cross = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Visible = false, Parent = CrossGui })
	local arms = {}
	for i = 1, 4 do arms[i] = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false, Parent = cross }) end
	local dot = Circle(cross, 0, 0, 4, WHITE); dot.Visible = false
	local ring = Circle(cross, 0, 0, 10, WHITE); ring.BackgroundTransparency = 1; ring.Visible = false
	local ringStroke = Stroke(ring, WHITE, 1.5)
	local DIRS = { Vector2.new(-1, 0), Vector2.new(1, 0), Vector2.new(0, -1), Vector2.new(0, 1) }
	local cursorHidden = false
	local function setCursor(hidden: boolean)
		if hidden == cursorHidden then return end
		cursorHidden = hidden
		UIS.MouseIconEnabled = not hidden
	end
	local function rebuild()
		local on = En("Visual") and Cfg.Visual["Crosshair"] == true
		cross.Visible = on
		setCursor(on)
		if not on then return end
		local kind, size, gap, col = Cfg.Visual["Crosshair Type"], Cfg.Visual["Crosshair Size"], Cfg.Visual["Crosshair Gap"], Cfg.Visual["Crosshair Color"]
		for i = 1, 4 do arms[i].Visible = false; arms[i].BackgroundColor3 = col end
		dot.Visible, ring.Visible = false, false
		dot.BackgroundColor3 = col; ringStroke.Color = col
		if kind == "Dot" then
			dot.Size = UDim2.fromOffset(size / 2, size / 2); dot.Visible = true
		elseif kind == "Circle" then
			ring.Size = UDim2.fromOffset(size * 2, size * 2); ring.Visible = true
			dot.Size = UDim2.fromOffset(2, 2); dot.Visible = true
		else
			if kind == "Plus" then gap = 0 end
			for i = 1, 4 do
				if not (kind == "T" and i == 3) then
					local d, f = DIRS[i], arms[i]
					f.Visible = true
					f.Size = d.Y == 0 and UDim2.fromOffset(size, 2) or UDim2.fromOffset(2, size)
					f.Position = UDim2.fromOffset(d.X * (gap + size / 2), d.Y * (gap + size / 2))
				end
			end
		end
	end
	for _, k in ipairs({ "Enabled", "Crosshair", "Crosshair Type", "Crosshair Size", "Crosshair Gap", "Crosshair Color" }) do P("Visual"):On(k, rebuild) end
	RootMaid:Add(function() setCursor(false) end)
	-- the crosshair IS the cursor: it sits on the mouse position every frame
	local lastMouse = nil
	RootMaid:Add(RunService.RenderStepped:Connect(function()
		if not cross.Visible then lastMouse = nil return end
		local m = UIS:GetMouseLocation()
		if m == lastMouse then return end          -- mouse still: nothing to move
		lastMouse = m
		cross.Position = UDim2.fromOffset(m.X, m.Y)
	end))

	-- watermark styled like a menu panel: panel background + border, accent bar,
	-- the V logo, brand wordmark, dim separators, accent-coloured numbers
	local wm = New("Frame", {
		Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.PanelBg, BorderSizePixel = 0, Visible = false, Parent = Overlay,
	})
	Round(wm, 4); Stroke(wm, C.PanelBorder, 1)
	local wmBar = New("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = C.Red, BorderSizePixel = 0, Parent = wm })
	New("UICorner", { CornerRadius = UDim.new(0, 4), Parent = wmBar })
	local wmIcon = New("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(14, 11),
		BackgroundTransparency = 1, Image = ASSETS.Logo, ScaleType = Enum.ScaleType.Fit, Parent = wm,
	})
	local wmText = New("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 28, 0.5, 0), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1, Text = "", TextSize = 12, TextColor3 = C.White, FontFace = FONT.Medium,
		TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = wm,
	})
	New("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = wmText })
	local SEP = '<font color="#3A4A66">  |  </font>'
	local function hex(c: Color3): string return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
	local ACCENT, DIMTXT = hex(C.LightBlue), hex(C.Dim)
	-- size slider: text size drives the box height and the logo size
	P("Visual"):On("Watermark Size", function(v)
		local size = math.floor(v)
		if wmText.TextSize ~= size then wmText.TextSize = size end
		local h = size + 10
		wm.Size = UDim2.fromOffset(0, h); wmText.Size = UDim2.fromOffset(0, h)
		wmIcon.Size = UDim2.fromOffset(size + 2, size - 1)
		wmText.Position = UDim2.new(0, size + 16, 0.5, 0)
	end)
	-- watermark is draggable while the menu is open; its position is saved with configs
	do
		local saved = Cfg.Visual["Watermark Pos"]
		if type(saved) == "table" and saved.x and saved.y then
			local screen = Overlay.AbsoluteSize
			wm.Position = UDim2.fromOffset(math.clamp(saved.x, 0, math.max(0, screen.X - 40)), math.clamp(saved.y, 0, math.max(0, screen.Y - 20)))
		end
		local dragging, dragStart, startPos = false, nil, nil
		wm.Active = true
		RootMaid:Add(wm.InputBegan:Connect(function(input)
			if not Holder.Visible then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging, dragStart, startPos = true, UIS:GetMouseLocation(), wm.Position
			end
		end))
		RootMaid:Add(UIS.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local d = UIS:GetMouseLocation() - dragStart
				local screen, size = Overlay.AbsoluteSize, wm.AbsoluteSize
				local x = math.clamp(startPos.X.Offset + d.X, 0, math.max(0, screen.X - size.X))
				local y = math.clamp(startPos.Y.Offset + d.Y, 0, math.max(0, screen.Y - size.Y))
				wm.Position = UDim2.fromOffset(x, y)
			end
		end))
		RootMaid:Add(UIS.InputEnded:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				dragging = false
				Cfg.Visual["Watermark Pos"] = { x = wm.Position.X.Offset, y = wm.Position.Y.Offset }
			end
		end))
	end
	local frames = 0
	RootMaid:Add(RunService.Heartbeat:Connect(function() frames = frames + 1 end))
	local alive = true
	RootMaid:Add(function() alive = false end)
	task.spawn(function()
		while alive do
			task.wait(WATERMARK_SECONDS)
			if not alive then break end
			local fps = frames; frames = 0
			local ping = 0
			pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
			local showWm = En("Visual") and Cfg.Visual["Watermark"] == true
			if wm.Visible ~= showWm then wm.Visible = showWm end
			if showWm then
				local name = Library.ShownName and Library.ShownName() or LP.DisplayName
				wmText.Text = string.format('Vision<font color="%s">Ware</font>%s<font color="%s">%s</font>%s<font color="%s">%d</font> fps%s<font color="%s">%d</font> ms',
					ACCENT, SEP, DIMTXT, name, SEP, ACCENT, fps, SEP, ACCENT, ping)
			end
		end
	end)
end

---------------------------------------------------------------------------
-- 5. Local: FOV + freecam (one RenderStepped)
---------------------------------------------------------------------------
do
	-- freecam state
	local free, freeCF = false, CFrame.identity
	-- while freecam is on the character must not move: player controls are
	-- disabled through the PlayerModule and the root part is anchored as a backstop
	local function getControls()
		local ok, controls = pcall(function()
			return require(LP:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
		end)
		return ok and controls or nil
	end
	local function freezeCharacter(freeze: boolean)
		local controls = getControls()
		if controls then pcall(function() if freeze then controls:Disable() else controls:Enable() end end) end
		if myRoot then
			myRoot.Anchored = freeze
			if freeze then myRoot.AssemblyLinearVelocity = Vector3.zero end
		end
	end
	local function setFree(v: boolean)
		if v == free then return end
		free = v
		if v then
			freeCF = Camera.CFrame
			Camera.CameraType = Enum.CameraType.Scriptable
			freezeCharacter(true)
		else
			Camera.CameraType = ORIGINAL_CAMERA_TYPE
			UIS.MouseBehavior = Enum.MouseBehavior.Default
			freezeCharacter(false)
			local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
			if hum then Camera.CameraSubject = hum end
		end
	end
	P("Local"):On("Freecam", function(v) if En("Local") then setFree(v == true) end end)
	P("Local"):On("Enabled", function(v) if not v then setFree(false) end end)
	RootMaid:Add(function() setFree(false) end)
	RootMaid:Add(UIS.InputBegan:Connect(function(input, gp)
		if gp or not En("Local") or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local ok, key = pcall(function() return Enum.KeyCode[Cfg.Local["Freecam Key"]] end)
		if ok and key and input.KeyCode == key then P("Local").Controls["Freecam"].Set(not Cfg.Local["Freecam"]) end
	end))

	local FORWARD, BACK, LEFT, RIGHT, UP, DOWN = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), Vector3.yAxis, -Vector3.yAxis
	RunService:BindToRenderStep("VW_Local_" .. INSTANCE_ID, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local L = Cfg.Local
		if not L.Enabled then return end
		-- only override the FOV when asked: forcing it every frame fights the game's
		-- own sprint / aim FOV tweens and makes everything on screen stutter
		if L["Custom FOV"] then
			local fov = L["Field Of View"]
			if fov and Camera.FieldOfView ~= fov then Camera.FieldOfView = fov end
		end
		-- camera bob / shake is almost always done through Humanoid.CameraOffset: zero it every frame
		if L["Remove Camera Movements"] and myChar then
			local hum = myChar:FindFirstChildOfClass("Humanoid")
			if hum and hum.CameraOffset ~= Vector3.zero then hum.CameraOffset = Vector3.zero end
		end
		if not free then return end
		local speed = (L["Freecam Speed"] or 20) * dt * 2
		local d = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then d = d + FORWARD end
		if UIS:IsKeyDown(Enum.KeyCode.S) then d = d + BACK end
		if UIS:IsKeyDown(Enum.KeyCode.A) then d = d + LEFT end
		if UIS:IsKeyDown(Enum.KeyCode.D) then d = d + RIGHT end
		if UIS:IsKeyDown(Enum.KeyCode.E) then d = d + UP end
		if UIS:IsKeyDown(Enum.KeyCode.Q) then d = d + DOWN end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then speed = speed * FREECAM_BOOST end
		if myRoot and not myRoot.Anchored then myRoot.Anchored = true end   -- respawned mid-freecam
		local delta = UIS:GetMouseDelta()
		local rx, ry = freeCF:ToEulerAnglesYXZ()
		rx = math.clamp(rx - delta.Y * FREECAM_LOOK_SENSITIVITY, -FREECAM_PITCH_LIMIT, FREECAM_PITCH_LIMIT)
		ry = ry - delta.X * FREECAM_LOOK_SENSITIVITY
		freeCF = CFrame.new(freeCF.Position) * CFrame.fromEulerAnglesYXZ(rx, ry, 0) * CFrame.new(d * speed)
		Camera.CFrame = freeCF
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
	end)
	RootMaid:Add(function() pcall(RunService.UnbindFromRenderStep, RunService, "VW_Local_" .. INSTANCE_ID) end)


end

---------------------------------------------------------------------------
-- 6. ESP: one RenderStepped, cached refs, stable head-to-feet box,
--    no per-frame allocation beyond the UDim2 values written
---------------------------------------------------------------------------
do
	local espRoot = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = Overlay })
	local R15 = {
		{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
		{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
		{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
		{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
	}
	local R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }

	local function vis(obj, v: boolean) if obj.Visible ~= v then obj.Visible = v end end
	local function hideLines(list) for i = 1, #list do local l = list[i]; if l.Visible then l.Visible = false end end end
	-- lines are rotated frames; every property write makes the GUI redraw them, so each
	-- line remembers what it shows and only what changed is written (a still player /
	-- still camera then costs nothing). With 28 players the skeleton alone is ~390 lines.
	local lineState = setmetatable({}, { __mode = "k" })   -- frame -> { x, y, len, rot, thick, color }
	local SKELETON_MIN_PX = 40      -- skeleton only on players at least this tall on screen
	local function newLine(parent)
		local f = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = WHITE, BorderSizePixel = 0, Visible = false, Parent = parent })
		lineState[f] = { 0, 0, -1, 0, -1, WHITE }
		return f
	end
	local function setLine(f, ax: number, ay: number, bx: number, by: number, color: Color3, thick: number)
		local dx, dy = bx - ax, by - ay
		local x, y = (ax + bx) * 0.5, (ay + by) * 0.5
		local len = math.sqrt(dx * dx + dy * dy)
		local rot = math.deg(math.atan2(dy, dx))
		local s = lineState[f]
		if math.abs(s[1] - x) > 0.25 or math.abs(s[2] - y) > 0.25 then s[1], s[2] = x, y; f.Position = UDim2.fromOffset(x, y) end
		if math.abs(s[3] - len) > 0.25 or s[5] ~= thick then s[3], s[5] = len, thick; f.Size = UDim2.fromOffset(len, thick) end
		if math.abs(s[4] - rot) > 0.2 then s[4] = rot; f.Rotation = rot end
		if s[6] ~= color then s[6] = color; f.BackgroundColor3 = color end
		if not f.Visible then f.Visible = true end
	end
	-- same idea for boxes / texts / the health bar: position + size written only when
	-- they moved (each write builds two UDim2s and crosses into the engine)
	local rectState = setmetatable({}, { __mode = "k" })   -- gui -> { x, y, w, h }
	local function setRect(g, x: number, y: number, w: number, h: number)
		local s = rectState[g]
		if not s then s = { math.huge, math.huge, -1, -1 }; rectState[g] = s end
		if math.abs(s[1] - x) > 0.25 or math.abs(s[2] - y) > 0.25 then s[1], s[2] = x, y; g.Position = UDim2.fromOffset(x, y) end
		if math.abs(s[3] - w) > 0.25 or math.abs(s[4] - h) > 0.25 then s[3], s[4] = w, h; g.Size = UDim2.fromOffset(w, h) end
	end
	local function newObj(state: PlayerState)
		local holder = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = espRoot })
		state.Maid:Add(holder)
		local o = { holder = holder }
		o.box = New("Frame", { BackgroundTransparency = 1, Visible = false, Parent = holder }); o.boxStroke = Stroke(o.box, WHITE, 1)
		o.corners = table.create(8); for i = 1, 8 do o.corners[i] = newLine(holder) end
		o.skel = table.create(14); for i = 1, 14 do o.skel[i] = newLine(holder) end
		o.strokes = {}
		o.fonts = {}
		local function txt(align)
			local t = New("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = 10, TextColor3 = C.White, FontFace = FONT.Medium, TextXAlignment = align or Enum.TextXAlignment.Center, Visible = false, Parent = holder })
			o.strokes[t] = Stroke(t, C.WindowBg, 1)      -- outline in the menu's background colour
			o.fonts[t] = "Menu"
			return t
		end
		o.name, o.dist, o.hpText = txt(), txt(), txt(Enum.TextXAlignment.Right)
		-- health bar: menu track colour + border, fill is a black -> grey gradient
		o.hpBar = New("Frame", { BackgroundColor3 = C.Track, BorderSizePixel = 0, Visible = false, Parent = holder })
		Stroke(o.hpBar, C.BoxStroke, 1)
		o.hpFill = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = o.hpBar })
		o.hpGrad = New("UIGradient", { Rotation = 90, Color = ColorSequence.new(HP_GRADIENT_TOP, HP_GRADIENT_BOTTOM), Parent = o.hpFill })
		o.hpGradKey = false      -- false = black / grey; a Color3 = the blue it was last set to
		o.lastName, o.lastDist, o.lastHp = "", "", ""
		o.lay = {}               -- this player's layout, refilled every frame (espLayout)
		o.barMemo = {}           -- health bar fill last written (espOrientBar)
		o.colors = {}            -- text -> colour last written
		return o
	end
	local wasOn = false

	local function style(o, t, col: Color3, ts: number, fontName: string, outline: boolean)
		if t.TextSize ~= ts then t.TextSize = ts end
		if o.fonts[t] ~= fontName then
			o.fonts[t] = fontName
			if fontName == "Menu" then t.FontFace = FONT.Medium else t.Font = fontEnum(fontName) end   -- Menu = the menu's own font
		end
		if o.colors[t] ~= col then o.colors[t] = col; t.TextColor3 = col end
		local st = outline and 0 or 1
		local stroke = o.strokes[t]
		if stroke.Transparency ~= st then stroke.Transparency = st end
	end

	local function update()
		local O0 = Cfg.Others
		-- nothing to draw (panel on but every drawing option off): same as off, so
		-- no per-player projection / visibility raycasts run for nothing
		local on = En("Others") and O0 ~= nil and (O0["Box ESP"] or O0["Name ESP"] or O0["Distance ESP"]
			or O0["Health Bar"] or O0["Health Text"] or O0["Skeleton"]) == true
		if not on then
			if wasOn then
				for _, state in pairs(states) do if state.ESP then vis(state.ESP.holder, false) end end
				wasOn = false
			end
			return
		end
		wasOn = true
		local low = isLowQuality()

		local S, O = Cfg["ESP Settings"], Cfg.Others
		local now = os.clock()
		local vp = Camera.ViewportSize
		local vpX, vpY = vp.X, vp.Y
		local camPos = Camera.CFrame.Position
		local originPos = myRoot and myRoot.Position or camPos
		local font, ts, outline, thick = S["Font"] or "Menu", S["Text Size"] or 10, S["Text Outline"] == true, S["Box Thickness"] or 1
		local maxDist = O["ESP Distance"] or 500
		local wantBox, boxType = O["Box ESP"], O["Box Type"]
		local wantName, wantDist, wantHpBar, wantHpText, wantSkel = O["Name ESP"], O["Distance ESP"], O["Health Bar"], O["Health Text"], O["Skeleton"]
		local showDowned = O["Show Downed"]
		local boxColVis, boxColHid, nameCol, skelCol = S["Box Color"], S["Hidden Color"], S["Name Color"], S["Skeleton Color"]
		local drawn = 0
		local maxDrawn = low and ESP_MAX_PLAYERS_LOW or math.huge

		for idx = 1, #playerList do
			local plr = playerList[idx]
			local state = states[plr]
			local o = state and state.ESP
			local c, hum, root = state and state.Char, state and state.Hum, state and state.Root
			if not state or not c or not hum or not root or (hum.Health <= 0 and not showDowned) then
				if o then vis(o.holder, false) end
			else
				local rootPos = root.Position
				local dv = originPos - rootPos
				local distSq = dv.X * dv.X + dv.Y * dv.Y + dv.Z * dv.Z
				state.Dist = distSq
				if distSq > maxDist * maxDist or drawn >= maxDrawn then
					if o then vis(o.holder, false) end
				else
					if not o then o = newObj(state); state.ESP = o end
					drawn = drawn + 1
					local visible = isVisible(state, now)
					-- stable 2D box: project the top of the head and the feet (both on the
					-- root's vertical axis) and use a fixed aspect ratio. This does not
					-- change when the player turns or animates, so the box never jitters.
					local rootSize = root.Size
					local head = state.Head
					local topY = head and (head.Position.Y + head.Size.Y * 0.5) or (rootPos.Y + rootSize.Y * 0.5 + 1.5)
					local bottomY = rootPos.Y - hum.HipHeight - rootSize.Y * 0.5
					local topSp = Camera:WorldToViewportPoint(Vector3.new(rootPos.X, topY + BOX_PAD, rootPos.Z))
					local botSp = Camera:WorldToViewportPoint(Vector3.new(rootPos.X, bottomY - BOX_PAD, rootPos.Z))
					local rootSp = Camera:WorldToViewportPoint(rootPos)
					local inFront = topSp.Z > 0 and botSp.Z > 0
					local h = math.abs(botSp.Y - topSp.Y)
					local w = h * BOX_ASPECT
					local minX, maxX = rootSp.X - w * 0.5, rootSp.X + w * 0.5
					local minY, maxY = math.min(topSp.Y, botSp.Y), math.max(topSp.Y, botSp.Y)
					local onScreen = inFront and maxX > 0 and minX < vpX and maxY > 0 and minY < vpY
					if not onScreen then
						vis(o.holder, false)
					else
						vis(o.holder, true)
						local boxCol = visible and boxColVis or boxColHid
						local show2d = wantBox and boxType == "2D"
						vis(o.box, show2d)
						if show2d then
							setRect(o.box, minX, minY, w, h)
							if o.boxCol ~= boxCol then o.boxCol = boxCol; o.boxStroke.Color = boxCol end
							if o.boxStroke.Thickness ~= thick then o.boxStroke.Thickness = thick end
						end
						if wantBox and boxType == "Corner" then
							local cl = math.max(4, math.min(w, h) * 0.25)
							local L = o.corners
							setLine(L[1], minX, minY, minX + cl, minY, boxCol, thick); setLine(L[2], minX, minY, minX, minY + cl, boxCol, thick)
							setLine(L[3], maxX, minY, maxX - cl, minY, boxCol, thick); setLine(L[4], maxX, minY, maxX, minY + cl, boxCol, thick)
							setLine(L[5], minX, maxY, minX + cl, maxY, boxCol, thick); setLine(L[6], minX, maxY, minX, maxY - cl, boxCol, thick)
							setLine(L[7], maxX, maxY, maxX - cl, maxY, boxCol, thick); setLine(L[8], maxX, maxY, maxX, maxY - cl, boxCol, thick)
						else
							hideLines(o.corners)
						end
						-- item positions come from the layout dragged in the ESP preview
						local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
						local lay = espLayout(S, minX, minY, w, h, ts, frac, o.lay)
						vis(o.name, wantName)
						if wantName then
							style(o, o.name, nameCol, ts, font, outline)
							local nm = plr.DisplayName
							if o.lastName ~= nm then o.lastName = nm; o.name.Text = nm end
							local r = lay.name
							setRect(o.name, r[1], r[2], r[3], r[4])
							if o.name.TextXAlignment ~= lay.nameAlign then o.name.TextXAlignment = lay.nameAlign end
						end
						vis(o.dist, wantDist)
						if wantDist then
							style(o, o.dist, nameCol, ts, font, outline)
							local d = math.floor(math.sqrt(distSq))
							if o.lastDist ~= d then o.lastDist = d; o.dist.Text = d .. "m" end
							local r = lay.dist
							setRect(o.dist, r[1], r[2], r[3], r[4])
							if o.dist.TextXAlignment ~= lay.distAlign then o.dist.TextXAlignment = lay.distAlign end
						end
						vis(o.hpBar, wantHpBar)
						if wantHpBar then
							local r = lay.bar
							setRect(o.hpBar, r[1], r[2], r[3], r[4])
							espOrientBar(o.hpFill, o.hpGrad, lay.barVertical, frac, o.barMemo)
							-- visible players: blue gradient (the ESP Box Color fading to a dark
							-- shade of it); hidden players: black / grey. Only rewritten on change.
							local key = visible and boxColVis or false
							if o.hpGradKey ~= key then
								o.hpGradKey = key
								o.hpGrad.Color = key and ColorSequence.new(key, key:Lerp(BLACK, 0.7))
									or ColorSequence.new(HP_GRADIENT_TOP, HP_GRADIENT_BOTTOM)
							end
						end
						vis(o.hpText, wantHpText)
						if wantHpText then
							style(o, o.hpText, C.White, ts, font, outline)
							local hp = math.floor(hum.Health)
							if o.lastHp ~= hp then o.lastHp = hp; o.hpText.Text = tostring(hp) end
							local r = lay.hp
							setRect(o.hpText, r[1], r[2], r[3], r[4])
							if o.hpText.TextXAlignment ~= lay.hpAlign then o.hpText.TextXAlignment = lay.hpAlign end
						end
						-- skeleton only when the player is big enough on screen to read it (far
						-- away it is a few pixels of lines and ~14 redrawn frames each)
						if wantSkel and h >= SKELETON_MIN_PX then
							local pairs_ = state.IsR15 and R15 or R6
							local limbs = state.Limbs
							local col = visible and skelCol or boxColHid
							for i = 1, 14 do
								local l, pr = o.skel[i], pairs_[i]
								local a = pr and limbs[pr[1]]
								local b = pr and limbs[pr[2]]
								if a and b then
									local sa, sb = Camera:WorldToViewportPoint(a.Position), Camera:WorldToViewportPoint(b.Position)
									setLine(l, sa.X, sa.Y, sb.X, sb.Y, col, thick)
								else
									vis(l, false)
								end
							end
						else
							hideLines(o.skel)
						end
					end
				end
			end
		end
	end
	local errorShown = false
	-- run AFTER the camera step (priority Camera + 1): RenderStepped handlers fire
	-- before the camera updates, which made the ESP lag a frame behind fast movement
	RunService:BindToRenderStep("VW_ESP_" .. INSTANCE_ID, Enum.RenderPriority.Camera.Value + 1, function()
		Library.ProfBegin("VW_ESP")          -- shows up as its own bar in the MicroProfiler
		local ok, err = pcall(update)
		Library.ProfEnd()
		if not ok and not errorShown then errorShown = true; Log.warn("ESP:", err) end
	end)
	RootMaid:Add(function() pcall(RunService.UnbindFromRenderStep, RunService, "VW_ESP_" .. INSTANCE_ID) end)
	table.insert(onCharacterGone, function(state: PlayerState) if state.ESP then vis(state.ESP.holder, false) end end)
end

---------------------------------------------------------------------------
-- 6b. ESP preview window (ESP Settings > Preview Window): a small draggable window
--     with a 3D copy of your own character in a ViewportFrame. Drag inside it to
--     spin the character (it turns slowly on its own otherwise). The ESP is drawn on
--     top with the current ESP settings, projected through the preview camera.
---------------------------------------------------------------------------
do
	local WIN_W2, WIN_H2 = 200, 270
	local TITLE_H = 22
	local CAM_DIST, CAM_FOV = 11, 50
	local AUTO_SPIN = math.rad(25)             -- per second while not dragging
	local PREVIEW_HP = 0.72                     -- health shown on the preview
	local SKELETON = {
		{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
		{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
		{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
		{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
		{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
	}

	local gui = New("ScreenGui", { Name = "VisionWarePreview", IgnoreGuiInset = true, ResetOnSpawn = false,
		DisplayOrder = Screen.DisplayOrder + 1, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false })
	pcall(function() gui.Parent = Screen.Parent end)
	if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
	RootMaid:Add(gui)

	local win = New("Frame", { Size = UDim2.fromOffset(WIN_W2, WIN_H2), Position = UDim2.new(1, -WIN_W2 - 24, 0.5, -WIN_H2 / 2),
		BackgroundColor3 = C.WindowBg, BorderSizePixel = 0, Parent = gui })
	Round(win, 4)
	Stroke(win, C.WindowBorder, 1)
	local title = New("TextLabel", { Size = UDim2.new(1, -16, 0, TITLE_H), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1,
		Text = "ESP Preview", TextColor3 = C.White, FontFace = FONT.Medium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = win })
	New("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, TITLE_H), BackgroundColor3 = C.WindowBorder, BorderSizePixel = 0, Parent = win })
	local body = New("ViewportFrame", { Size = UDim2.new(1, -12, 1, -TITLE_H - 8), Position = UDim2.fromOffset(6, TITLE_H + 3),
		BackgroundColor3 = C.Track, BorderSizePixel = 0, Ambient = Color3.fromRGB(170, 175, 190), LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1), Parent = win })
	Round(body, 3)
	local cam = Instance.new("Camera")
	cam.FieldOfView = CAM_FOV
	cam.Parent = body
	body.CurrentCamera = cam
	local world = Instance.new("WorldModel")
	world.Parent = body
	local overlay = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5, Parent = body })
	local hint = New("TextLabel", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -16), BackgroundTransparency = 1,
		Text = "drag labels to move them | drag to spin", TextColor3 = C.Dim, FontFace = FONT.Regular, TextSize = 9, ZIndex = 6, Parent = body })

	-- ESP pieces drawn in the overlay
	local function line()
		return New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = WHITE, Visible = false, ZIndex = 6, Parent = overlay })
	end
	local function setLine(f, a: Vector2, b: Vector2, color: Color3, thick: number)
		local d = b - a
		f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
		f.Size = UDim2.fromOffset(d.Magnitude, thick)
		f.Rotation = math.deg(math.atan2(d.Y, d.X))
		f.BackgroundColor3 = color
		f.Visible = true
	end
	local box = New("Frame", { BackgroundTransparency = 1, Visible = false, ZIndex = 6, Parent = overlay })
	local boxStroke = Stroke(box, WHITE, 1)
	local corners, bones = {}, {}
	for i = 1, 8 do corners[i] = line() end
	for i = 1, #SKELETON do bones[i] = line() end
	local function text(align)
		local t = New("TextLabel", { BackgroundTransparency = 1, Text = "", TextColor3 = C.White, FontFace = FONT.Medium, TextSize = 10,
			TextXAlignment = align or Enum.TextXAlignment.Center, Visible = false, ZIndex = 7, Parent = overlay })
		return t, Stroke(t, C.WindowBg, 1)
	end
	local nameLbl, nameStroke = text()
	local distLbl, distStroke = text()
	local hpLbl, hpStroke = text(Enum.TextXAlignment.Right)
	local hpBar = New("Frame", { BackgroundColor3 = C.Track, BorderSizePixel = 0, Visible = false, ZIndex = 6, Parent = overlay })
	Stroke(hpBar, C.BoxStroke, 1)
	local hpFill = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, PREVIEW_HP),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 6, Parent = hpBar })
	local hpGrad = New("UIGradient", { Rotation = 90, Parent = hpFill })

	-- the 3D copy of your character
	local model, modelFor = nil, nil
	local function buildModel()
		local c = LP.Character
		if not c or c == modelFor then return end
		if model then model:Destroy(); model = nil end
		local was = c.Archivable
		c.Archivable = true
		local ok, copy = pcall(function() return c:Clone() end)
		c.Archivable = was
		if not ok or not copy then return end
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Tool") or d:IsA("ForceField")
				or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Highlight") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		local hum = copy:FindFirstChildOfClass("Humanoid")
		if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
		copy:PivotTo(CFrame.new())
		copy.Parent = world
		model, modelFor = copy, c
	end

	-- dragging the window (title bar), dragging an ESP item to another side of the box,
	-- or spinning the character (drag on empty space inside the view)
	local yaw, dragWin, dragSpin, dragStart, winStart, lastX = 0, false, false, nil, nil, nil
	local dragItem, lastBox = nil, nil
	local ITEM_GUIS = { { "Name", nameLbl }, { "Distance", distLbl }, { "Health Text", hpLbl }, { "Health Bar", hpBar } }
	local function itemUnderMouse(m: Vector2): string?
		for _, pair in ipairs(ITEM_GUIS) do
			local g = pair[2]
			if g.Visible then
				local p, s = g.AbsolutePosition, g.AbsoluteSize
				local pad = pair[1] == "Health Bar" and 4 or 1        -- the bar is thin: give it a bigger grab area
				if m.X >= p.X - pad and m.X <= p.X + s.X + pad and m.Y >= p.Y - pad and m.Y <= p.Y + s.Y + pad then return pair[1] end
			end
		end
		return nil
	end
	-- drop: a text dropped inside the box goes to the middle of it; otherwise the side
	-- of the box nearest to where it was let go (the bar always takes a side)
	local function dropItem(item: string)
		if not lastBox then return end
		local m = UIS:GetMouseLocation() - overlay.AbsolutePosition
		local cx, cy = lastBox[1] + lastBox[3] / 2, lastBox[2] + lastBox[4] / 2
		local dx, dy = (m.X - cx) / math.max(lastBox[3] / 2, 1), (m.Y - cy) / math.max(lastBox[4] / 2, 1)
		local side
		if item ~= "Health Bar" and math.abs(dx) < 0.7 and math.abs(dy) < 0.7 then
			side = "Middle"
		elseif math.abs(dx) > math.abs(dy) then
			side = dx < 0 and "Left" or "Right"
		else
			side = dy < 0 and "Top" or "Bottom"
		end
		Cfg["ESP Settings"][item .. " Side"] = side
	end
	-- each item also catches its own press, so pressing right on it always grabs it
	for _, pair in ipairs(ITEM_GUIS) do
		local item, g = pair[1], pair[2]
		g.Active = true
		RootMaid:Add(g.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragItem, dragSpin = item, false
			end
		end))
	end
	RootMaid:Add(title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragWin, dragStart, winStart = true, UIS:GetMouseLocation(), win.AbsolutePosition
		end
	end))
	-- listen on UserInputService, not on the view: a click on a text label lands on the
	-- label itself (the view never saw it), which is why the texts could not be dragged
	RootMaid:Add(UIS.InputBegan:Connect(function(input)
		if not gui.Enabled then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local m = UIS:GetMouseLocation()
			local p, s = body.AbsolutePosition, body.AbsoluteSize
			if m.X < p.X or m.X > p.X + s.X or m.Y < p.Y or m.Y > p.Y + s.Y then return end   -- not inside the view
			local item = itemUnderMouse(m)
			if item then dragItem = item return end
			dragSpin, lastX = true, m.X
		end
	end))
	RootMaid:Add(UIS.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local m = UIS:GetMouseLocation()
		if dragWin then
			local d = m - dragStart
			win.Position = UDim2.fromOffset(winStart.X + d.X, winStart.Y + d.Y)
		elseif dragSpin and lastX then
			yaw = yaw - (m.X - lastX) * 0.012
			lastX = m.X
		end
	end))
	RootMaid:Add(UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragItem then dropItem(dragItem) end
			dragWin, dragSpin, dragItem = false, false, nil
		end
	end))

	-- project a world point through the preview camera into overlay pixels
	local function project(p: Vector3, size: Vector2): Vector2?
		local rel = cam.CFrame:PointToObjectSpace(p)
		if rel.Z >= -0.05 then return nil end
		local t = math.tan(math.rad(cam.FieldOfView) / 2)
		local aspect = size.X / size.Y
		local x = (rel.X / (-rel.Z * t * aspect) + 1) / 2 * size.X
		local y = (1 - rel.Y / (-rel.Z * t)) / 2 * size.Y
		return Vector2.new(x, y)
	end
	local function hideAll()
		box.Visible, nameLbl.Visible, distLbl.Visible, hpLbl.Visible, hpBar.Visible = false, false, false, false, false
		for _, l in ipairs(corners) do l.Visible = false end
		for _, l in ipairs(bones) do l.Visible = false end
	end
	local function applyFont(lbl, stroke, S, ts)
		local f = S["Font"] or "Menu"
		if f == "Menu" then lbl.FontFace = FONT.Medium else lbl.Font = fontEnum(f) end
		lbl.TextSize = ts
		stroke.Transparency = S["Text Outline"] == true and 0 or 1
	end

	local function step(dt)
		buildModel()
		if not model then hideAll() return end
		if not dragSpin then yaw = yaw + AUTO_SPIN * dt end
		local root = model:FindFirstChild("HumanoidRootPart")
		local head = model:FindFirstChild("Head")
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not (root and hum) then hideAll() return end
		local center = root.Position + Vector3.new(0, 0.4, 0)
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(yaw) * CAM_DIST, 1.2, math.cos(yaw) * CAM_DIST), center)

		local S, O = Cfg["ESP Settings"], Cfg.Others
		local size = overlay.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then return end
		hideAll()
		if not En("Others") then hint.Text = "ESP is off (Others)" return end
		hint.Text = "drag labels to move them | drag to spin"
		local ts = tonumber(S["Text Size"]) or 10
		local thick = tonumber(S["Box Thickness"]) or 1
		local boxCol = S["Box Color"] or WHITE
		-- same box as the real ESP: head top to feet on the root's axis, fixed aspect
		local topY = head and (head.Position.Y + head.Size.Y * 0.5) or (root.Position.Y + 2.5)
		local botY = root.Position.Y - hum.HipHeight - root.Size.Y * 0.5
		local top = project(Vector3.new(root.Position.X, topY + BOX_PAD, root.Position.Z), size)
		local bot = project(Vector3.new(root.Position.X, botY - BOX_PAD, root.Position.Z), size)
		local mid = project(root.Position, size)
		if not (top and bot and mid) then return end
		local h = math.abs(bot.Y - top.Y)
		local w = h * BOX_ASPECT
		local minX, minY, maxX, maxY = mid.X - w / 2, math.min(top.Y, bot.Y), mid.X + w / 2, math.max(top.Y, bot.Y)
		if O["Box ESP"] then
			if O["Box Type"] == "Corner" then
				local cl = math.max(4, math.min(w, h) * 0.25)
				setLine(corners[1], Vector2.new(minX, minY), Vector2.new(minX + cl, minY), boxCol, thick)
				setLine(corners[2], Vector2.new(minX, minY), Vector2.new(minX, minY + cl), boxCol, thick)
				setLine(corners[3], Vector2.new(maxX, minY), Vector2.new(maxX - cl, minY), boxCol, thick)
				setLine(corners[4], Vector2.new(maxX, minY), Vector2.new(maxX, minY + cl), boxCol, thick)
				setLine(corners[5], Vector2.new(minX, maxY), Vector2.new(minX + cl, maxY), boxCol, thick)
				setLine(corners[6], Vector2.new(minX, maxY), Vector2.new(minX, maxY - cl), boxCol, thick)
				setLine(corners[7], Vector2.new(maxX, maxY), Vector2.new(maxX - cl, maxY), boxCol, thick)
				setLine(corners[8], Vector2.new(maxX, maxY), Vector2.new(maxX, maxY - cl), boxCol, thick)
			else
				box.Position, box.Size = UDim2.fromOffset(minX, minY), UDim2.fromOffset(w, h)
				boxStroke.Color, boxStroke.Thickness = boxCol, thick
				box.Visible = true
			end
		end
		-- the same layout as the real ESP; the item being dragged follows the mouse
		lastBox = { minX, minY, w, h }
		local lay = espLayout(S, minX, minY, w, h, ts, PREVIEW_HP)
		local mouseIn = UIS:GetMouseLocation() - overlay.AbsolutePosition
		local function put(gui2, item, r)
			if dragItem == item then
				gui2.Position = UDim2.fromOffset(mouseIn.X - r[3] / 2, mouseIn.Y - r[4] / 2)
			else
				gui2.Position = UDim2.fromOffset(r[1], r[2])
			end
			gui2.Size = UDim2.fromOffset(r[3], r[4])
		end
		if O["Name ESP"] then
			applyFont(nameLbl, nameStroke, S, ts)
			nameLbl.TextColor3 = S["Name Color"] or WHITE
			nameLbl.Text = LP.DisplayName
			nameLbl.TextXAlignment = lay.nameAlign
			put(nameLbl, "Name", lay.name)
			nameLbl.Visible = true
		end
		if O["Distance ESP"] then
			applyFont(distLbl, distStroke, S, ts)
			distLbl.TextColor3 = S["Name Color"] or WHITE
			distLbl.Text = "25m"
			distLbl.TextXAlignment = lay.distAlign
			put(distLbl, "Distance", lay.dist)
			distLbl.Visible = true
		end
		if O["Health Bar"] then
			put(hpBar, "Health Bar", lay.bar)
			espOrientBar(hpFill, hpGrad, lay.barVertical, PREVIEW_HP)
			hpGrad.Color = ColorSequence.new(boxCol, boxCol:Lerp(BLACK, 0.7))      -- the "visible" gradient
			hpBar.Visible = true
		end
		if O["Health Text"] then
			applyFont(hpLbl, hpStroke, S, ts)
			hpLbl.Text = tostring(math.floor(PREVIEW_HP * 100))
			hpLbl.TextXAlignment = lay.hpAlign
			put(hpLbl, "Health Text", lay.hp)
			hpLbl.Visible = true
		end
		if O["Skeleton"] then
			local col = S["Skeleton Color"] or WHITE
			for i, pair in ipairs(SKELETON) do
				local a, b = model:FindFirstChild(pair[1]), model:FindFirstChild(pair[2])
				local pa, pb = a and project(a.Position, size), b and project(b.Position, size)
				if pa and pb then setLine(bones[i], pa, pb, col, thick) end
			end
		end
	end

	-- shown only while the option is on AND the menu is open; no work while hidden
	local stepConn, wanted = nil, false
	local function refresh()
		local v = wanted and Holder.Visible
		gui.Enabled = v
		if v and not stepConn then
			stepConn = RunService.RenderStepped:Connect(function(dt) pcall(step, dt) end)
		elseif not v and stepConn then
			stepConn:Disconnect(); stepConn = nil
		end
	end
	P("ESP Settings"):On("Preview Window", function(v) wanted = v == true; refresh() end)
	RootMaid:Add(Holder:GetPropertyChangedSignal("Visible"):Connect(refresh))
	RootMaid:Add(function() if stepConn then stepConn:Disconnect() end end)
end

---------------------------------------------------------------------------
-- 8. World (property writes on change; map-wide sweeps are chunked
--    across frames so a big map never hitches)
---------------------------------------------------------------------------
-- runs fn(instance) for every current workspace descendant, DESCENDANT_CHUNK per Heartbeat
local activeSweeps = {}
RootMaid:Add(function() for conn in pairs(activeSweeps) do conn:Disconnect() end table.clear(activeSweeps) end)
local function sweepWorkspace(fn, onDone)
	local list = workspace:GetDescendants()
	local i, n = 1, #list
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local stop = math.min(n, i + DESCENDANT_CHUNK - 1)
		for j = i, stop do
			local inst = list[j]
			if inst.Parent then pcall(fn, inst) end
		end
		i = stop + 1
		if i > n then
			conn:Disconnect(); activeSweeps[conn] = nil
			table.clear(list)
			if onDone then onDone() end
		end
	end)
	activeSweeps[conn] = true
end

do
	local orig = {
		Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, GlobalShadows = Lighting.GlobalShadows,
		Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
	}
	local function W() return Cfg.World end
	local function on(k: string) return En("World") and Cfg.World[k] == true end
	local function set(inst, prop: string, value) if inst[prop] ~= value then inst[prop] = value end end

	local function applyLighting()
		if not En("World") then
			set(Lighting, "Brightness", orig.Brightness); set(Lighting, "GlobalShadows", orig.GlobalShadows)
			set(Lighting, "Ambient", orig.Ambient); set(Lighting, "OutdoorAmbient", orig.OutdoorAmbient)
			set(Lighting, "FogEnd", orig.FogEnd); set(Lighting, "FogStart", orig.FogStart)
			return
		end
		local Wc = W()
		if Wc["Fullbright"] then
			set(Lighting, "Brightness", 2); set(Lighting, "GlobalShadows", false)
			set(Lighting, "Ambient", WHITE); set(Lighting, "OutdoorAmbient", WHITE)
		else
			set(Lighting, "Brightness", Wc["Brightness"] or orig.Brightness)
			set(Lighting, "GlobalShadows", not Wc["No Shadows"])
			set(Lighting, "Ambient", orig.Ambient); set(Lighting, "OutdoorAmbient", orig.OutdoorAmbient)
		end
		if Wc["No Fog"] then set(Lighting, "FogEnd", 1e9); set(Lighting, "FogStart", 1e9) else set(Lighting, "FogEnd", orig.FogEnd); set(Lighting, "FogStart", orig.FogStart) end
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if atm then
			if atm:GetAttribute("VW_Density") == nil then atm:SetAttribute("VW_Density", atm.Density) end
			set(atm, "Density", Wc["No Fog"] and 0 or atm:GetAttribute("VW_Density"))
		end
	end
	do -- seed from the game's own values so enabling the panel changes nothing by itself
		local ctl = P("World").Controls
		ctl["Brightness"].Set(math.clamp(orig.Brightness, 0, 10))
		ctl["Time Of Day"].Set(orig.ClockTime)
		ctl["No Shadows"].Set(not orig.GlobalShadows)
	end
	for _, k in ipairs({ "Enabled", "Fullbright", "Brightness", "No Fog", "No Shadows" }) do
		P("World"):On(k, applyLighting)
	end
	-- Time Of Day: once you move the slider (or a config sets it) the time is locked
	-- there, and the game's day/night cycle is undone every time it moves the clock.
	-- Works without the World header toggle. Until then the game's own time runs.
	do
		local lockedTime = nil
		local first = true
		P("World"):On("Time Of Day", function(v)
			if first then first = false return end      -- the initial call right after seeding
			lockedTime = tonumber(v)
			if lockedTime then Lighting.ClockTime = lockedTime end
		end)
		RootMaid:Add(Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
			if lockedTime and math.abs(Lighting.ClockTime - lockedTime) > 0.01 then Lighting.ClockTime = lockedTime end
		end))
		RootMaid:Add(function() lockedTime = nil end)
	end
	RootMaid:Add(Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
		if on("Fullbright") and Lighting.Brightness ~= 2 then Lighting.Brightness = 2 end
	end))

	local skyHolder = New("Folder", { Name = "VW_SkyHolder" })
	RootMaid:Add(function() for _, s in ipairs(skyHolder:GetChildren()) do s.Parent = Lighting end end)
	P("World"):On("Remove Sky", function()
		local v = on("Remove Sky")
		for _, s in ipairs(Lighting:GetChildren()) do if s:IsA("Sky") and s.Name ~= "VW_Sky" then s.Parent = v and skyHolder or Lighting end end
		if not v then for _, s in ipairs(skyHolder:GetChildren()) do s.Parent = Lighting end end
	end)
	P("World"):On("Remove Clouds", function()
		local v = on("Remove Clouds")
		for _, c in ipairs(workspace.Terrain:GetChildren()) do if c:IsA("Clouds") then set(c, "Enabled", not v) end end
	end)
	P("World"):On("Remove Water", function()
		local v = on("Remove Water")
		local t = workspace.Terrain
		if v then
			if t:GetAttribute("VW_WT") == nil then t:SetAttribute("VW_WT", t.WaterTransparency) end
			t.WaterTransparency = 1
		elseif t:GetAttribute("VW_WT") ~= nil then t.WaterTransparency = t:GetAttribute("VW_WT") end
	end)

	-- per-part world effects. Only parts actually changed are remembered (weak-keyed,
	-- so destroyed parts do not leak): turning an option off restores just those
	-- instead of walking the whole map again, and with both options off nothing is
	-- walked at all (that full sweep used to cost ~5 ms a frame for seconds after
	-- every load, with the options off).
	local partOrig = setmetatable({}, { __mode = "k" })
	local function isCharacterPart(p): boolean
		local parent = p.Parent
		return parent ~= nil and (Players:GetPlayerFromCharacter(parent) ~= nil or parent == myChar)
	end
	local function applyToPart(p)
		if not p:IsA("BasePart") then return end
		local o = partOrig[p]
		local texOff, glowOff = on("Remove Textures"), on("Remove Glow / Lights")
		if not o then
			if not (texOff or (glowOff and p.Material == Enum.Material.Neon)) or isCharacterPart(p) then return end
			o = { p.Material }; partOrig[p] = o
		end
		local flat = texOff or (glowOff and o[1] == Enum.Material.Neon)
		set(p, "Material", flat and Enum.Material.SmoothPlastic or o[1])
		if not flat then partOrig[p] = nil end              -- back to its own material: forget it
	end
	-- decals / textures / lights that were changed (to put back without a map walk)
	local changedFx = {}
	-- lights: PointLight / SpotLight / SurfaceLight are switched off, originals kept in an attribute
	local function applyToLight(l)
		if not l:IsA("Light") then return end
		if on("Remove Glow / Lights") then
			if l:GetAttribute("VW_L") == nil then l:SetAttribute("VW_L", l.Enabled) table.insert(changedFx, l) end
			set(l, "Enabled", false)
		elseif l:GetAttribute("VW_L") ~= nil then
			set(l, "Enabled", l:GetAttribute("VW_L"))
			l:SetAttribute("VW_L", nil)
		end
	end
	-- post effects toggled by class, originals kept in an attribute
	local function applyEffect(className: string, optionName: string)
		local v = on(optionName)
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA(className) then
				if v then
					if e:GetAttribute("VW_B") == nil then e:SetAttribute("VW_B", e.Enabled) end
					set(e, "Enabled", false)
				elseif e:GetAttribute("VW_B") ~= nil then
					set(e, "Enabled", e:GetAttribute("VW_B"))
				end
			end
		end
	end
	local function applyBloom()
		applyEffect("BloomEffect", "Remove Glow / Lights")
		applyEffect("SunRaysEffect", "Remove Sun Rays")
	end
	P("World"):On("Remove Sun Rays", function() applyEffect("SunRaysEffect", "Remove Sun Rays") end)
	-- effects added by the game later are handled too
	RootMaid:Add(Lighting.ChildAdded:Connect(function(e)
		if e:IsA("PostEffect") then task.defer(function() pcall(applyBloom) end) end
	end))
	local function applyToDecal(d)
		if not (d:IsA("Texture") or d:IsA("Decal")) then return end
		if on("Remove Textures") then
			if d:GetAttribute("VW_T") == nil then d:SetAttribute("VW_T", d.Transparency) table.insert(changedFx, d) end
			set(d, "Transparency", 1)
		elseif d:GetAttribute("VW_T") ~= nil then
			set(d, "Transparency", d:GetAttribute("VW_T"))
			d:SetAttribute("VW_T", nil)
		end
	end
	local sweeping, sweepAgain = false, false
	local applied = false                                -- some part / decal / light is changed right now
	-- new parts are only watched while one of the two options is on: a teleport streams
	-- in tens of thousands of instances and each one called this listener even with
	-- both options off
	local addedConn = nil
	local function watchAdded(want: boolean)
		if want and not addedConn then
			addedConn = workspace.DescendantAdded:Connect(function(p)
				if (on("Remove Textures") or on("Remove Glow / Lights")) and (p:IsA("BasePart") or p:IsA("Decal") or p:IsA("Texture") or p:IsA("Light")) then
					task.defer(function() pcall(applyToPart, p); pcall(applyToDecal, p); pcall(applyToLight, p) end)
				end
			end)
		elseif not want and addedConn then
			addedConn:Disconnect(); addedConn = nil
		end
	end
	RootMaid:Add(function() watchAdded(false) end)
	local function applyParts()
		applyBloom()
		local want = on("Remove Textures") or on("Remove Glow / Lights")
		watchAdded(want)
		if not want then
			-- off: put back only what was changed, no map walk
			if applied then
				applied = false
				for p, o in pairs(partOrig) do if p.Parent then pcall(set, p, "Material", o[1]) end end
				table.clear(partOrig)
				for _, inst in ipairs(changedFx) do
					if inst.Parent then pcall(function() applyToDecal(inst); applyToLight(inst) end) end
				end
				table.clear(changedFx)
			end
			return
		end
		if sweeping then sweepAgain = true return end
		sweeping, applied = true, true
		sweepWorkspace(function(inst) applyToPart(inst); applyToDecal(inst); applyToLight(inst) end, function()
			sweeping = false
			if sweepAgain then sweepAgain = false; applyParts() end
		end)
	end
	-- the hooks below all fire once when the menu loads: run a single pass for them
	local applyQueued = false
	local function queueApply()
		if applyQueued then return end
		applyQueued = true
		task.defer(function() applyQueued = false; applyParts() end)
	end
	for _, k in ipairs({ "Enabled", "Remove Textures", "Remove Glow / Lights" }) do P("World"):On(k, queueApply) end

	RootMaid:Add(function()
		P("World").SetEnabled(false)
		pcall(applyLighting)
		for part, o in pairs(partOrig) do if part.Parent then part.Material = o[1] end end
	end)
end

-- FPS Booster (works on its own, the World header toggle is not needed): removes the
-- map clutter the game does not need. Whole Map.Trees and Map.Lamps (trees, lamp
-- posts), and every visible map part you can walk through (CanCollide off: plants,
-- balcony lights, crossings, signs...). Gameplay folders (doors, registers, ATMs,
-- stores, jobs, NPCs, crates...) and anything with a prompt / click / touch zone are
-- left alone. Animations on everything but your own character are stopped too.
-- Removed parts are kept (parented to nil) and put back when it is turned off;
-- parts streamed in later are handled as they arrive.
do
	local REMOVE_FOLDERS = { Trees = true, Lamps = true }           -- removed whole
	local KEEP_FOLDERS = {                                          -- never touched
		Interactions = true, Jobs = true, RobNPC = true, Registers = true, Doors = true, ATMs = true,
		ATMModels = true, Scooters = true, SurfBoards = true, FlipsyPrompts = true, Crates = true,
		CrewTurfs = true, Breakable = true, GunStore = true, CarDealer = true, CarCustomisation = true,
		Drip = true, Clothing = true, Tattoo = true, Jewelry = true, Stations = true, StationModels = true,
		GasPumps = true, Locations = true, NPCPositions = true, PDCameras = true, Misc = true, Texts = true,
		ParkingSpots = true, Paths = true, InvisFiller = true, MapBundles = true,
	}
	local removed = {}     -- instance -> original parent
	local function on() return Cfg.World["FPS Booster"] == true end
	local function topFolder(inst, map)                             -- the Map child inst lives under
		local cur = inst
		while cur and cur.Parent ~= map do cur = cur.Parent end
		return cur
	end
	local function usedByGame(part): boolean
		if part:FindFirstChildWhichIsA("ProximityPrompt", true) or part:FindFirstChildWhichIsA("ClickDetector")
			or part:FindFirstChildWhichIsA("TouchTransmitter") then return true end
		local model = part:FindFirstAncestorOfClass("Model")
		return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
	end
	local function remove(inst)
		if removed[inst] or not inst.Parent then return end
		removed[inst] = inst.Parent
		inst.Parent = nil
	end
	local function applyTo(inst)
		local map = workspace:FindFirstChild("Map")
		if not map or not inst:IsDescendantOf(map) then return end
		local top = topFolder(inst, map)
		if not top or KEEP_FOLDERS[top.Name] then return end
		if REMOVE_FOLDERS[top.Name] then
			-- the folder's direct children go whole (one removal per tree / lamp)
			local child = inst
			while child.Parent ~= top do child = child.Parent end
			remove(child)
			return
		end
		if not inst:IsA("BasePart") or inst.CanCollide or not inst.Anchored or inst.Transparency >= 1 then return end
		if usedByGame(inst) then return end
		remove(inst)
	end
	-- animations: every Animator except your own character's has its tracks stopped,
	-- and anything it starts later is stopped as it plays (other players, NPCs, props)
	local animConns = {}
	local function killAnims(animator)
		if not animator:IsA("Animator") or animConns[animator] then return end
		local char = LP.Character
		if char and animator:IsDescendantOf(char) then return end
		for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0) end
		animConns[animator] = animator.AnimationPlayed:Connect(function(t)
			if on() then t:Stop(0) end
		end)
	end
	local function restoreAll()
		for inst, parent in pairs(removed) do
			if parent.Parent or parent == workspace then pcall(function() inst.Parent = parent end) end
		end
		table.clear(removed)
		for _, c in pairs(animConns) do c:Disconnect() end
		table.clear(animConns)
	end
	local sweepToken = 0
	-- parts / animators that stream in later: only listened for while the booster is on
	local addedConn = nil
	local function watchAdded(want: boolean)
		if want and not addedConn then
			addedConn = workspace.DescendantAdded:Connect(function(p)
				if not on() then return end
				if p:IsA("Animator") then task.defer(function() pcall(killAnims, p) end)
				elseif p:IsA("BasePart") or p:IsA("Model") then task.defer(function() if p.Parent then pcall(applyTo, p) end end) end
			end)
		elseif not want and addedConn then
			addedConn:Disconnect(); addedConn = nil
		end
	end
	local function apply()
		sweepToken = sweepToken + 1
		watchAdded(on())
		if not on() then restoreAll() return end
		local my = sweepToken
		task.spawn(function()
			local map = workspace:FindFirstChild("Map")
			local list = map and map:GetDescendants() or {}
			for i, inst in ipairs(list) do
				if sweepToken ~= my then return end
				if inst.Parent then pcall(applyTo, inst) end
				if i % DESCENDANT_CHUNK == 0 then RunService.Heartbeat:Wait() end
			end
			for i, inst in ipairs(workspace:GetDescendants()) do
				if sweepToken ~= my then return end
				if inst:IsA("Animator") then pcall(killAnims, inst) end
				if i % DESCENDANT_CHUNK == 0 then RunService.Heartbeat:Wait() end
			end
		end)
	end
	P("World"):On("FPS Booster", apply)
	RootMaid:Add(function() sweepToken = sweepToken + 1; watchAdded(false); restoreAll() end)
end

---------------------------------------------------------------------------
-- 9. Spectate
---------------------------------------------------------------------------
do
	local target = nil
	local function follow()
		local state = target and states[target]
		if state and state.Hum then Camera.CameraSubject = state.Hum end
		if state and state.Root then pcall(function() LP:RequestStreamAroundAsync(state.Root.Position, 1) end) end
	end
	function Library.Spectate(plr)
		target = plr
		Library.SpectateTarget = plr
		if plr then
			follow()
			Library.Notify("Spectating " .. plr.DisplayName)
		else
			local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
			if hum then Camera.CameraSubject = hum end
			Library.Notify("Stopped spectating")
		end
		for p, r in pairs(Library.ListRows or {}) do
			r.Frame.BackgroundColor3 = (p == plr) and C.Red or C.DropBg
			r.Frame.BackgroundTransparency = (p == plr) and 0.6 or 0.5
			if r.Spec then r.Spec.Text = (p == plr) and "Stop" or "Spectate" end
		end
	end
	local alive = true
	RootMaid:Add(function() alive = false; if target then Library.Spectate(nil) end end)
	task.spawn(function()
		while alive do
			task.wait(SPECTATE_CHECK_SECONDS)
			if not alive then break end
			if target then
				local state = states[target]
				if not target.Parent or not state then Library.Spectate(nil)
				elseif state.Hum and Camera.CameraSubject ~= state.Hum then follow() end
			end
		end
	end)
	table.insert(onPlayerGone, function(plr) if plr == target then Library.Spectate(nil) end end)
end

---------------------------------------------------------------------------
-- 9b. Streamer mode + identity spoof (client-side only: nothing is sent to the
--     server, other players still see the real account)
--
--   Streamer Mode on, no ID  -> name "Player", id hidden, cash / bank masked
--   Streamer Mode on, ID set -> name, display name, avatar images, character
--                               look, cash and bank taken from that user
--
-- Every TextLabel / TextButton / ImageLabel / ImageButton in PlayerGui, CoreGui
-- (player list, chat, escape menu, bubbles) and world billboards is tracked while
-- the mode is on: the game's real text is kept, a rewritten copy is displayed, and
-- any later write by the game is caught and rewritten again. Turning it off writes
-- the real text back and drops every hook, so it costs nothing while off.
---------------------------------------------------------------------------
do
	local CoreGui     = game:GetService("CoreGui")
	local UserService = game:GetService("UserService")
	local REAL_NAME, REAL_DISPLAY, REAL_ID = LP.Name, LP.DisplayName, tostring(LP.UserId)
	local HIDDEN = { name = "Player", display = "Player", id = "1", idNum = nil, player = nil }
	local MASK = "•••••"
	local SWEEP_CHUNK = 600
	local MONEY_LABEL_NAMES = { Balance = true, Amount = true, Wallet = true, Bank = true, Cash = true, Money = true }

	local active = false         -- tracking is running (only while the Streamer Mode toggle is on)
	local hideIdentity = false   -- Streamer Mode checkbox: name / id / avatar / masking
	local fake = HIDDEN
	local tracked = {}           -- [instance] = { prop, real, written, pg, conn, dconn }
	local rootConns, sweepConns = {}, {}
	local targetConns = {}

	-- money sources: this game keeps them in Player.Data, others in leaderstats
	local function valueObj(plr, names)
		for _, folderName in ipairs({ "Data", "leaderstats" }) do
			local folder = plr:FindFirstChild(folderName)
			if folder then
				for _, n in ipairs(names) do
					local v = folder:FindFirstChild(n)
					if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return v end
				end
			end
		end
		return nil
	end
	local MONEY_NAMES, BANK_NAMES, LEVEL_NAMES = { "Money", "Cash", "Wallet" }, { "Bank" }, { "Level" }
	-- a typed value from the Streamer box: "50000", "50,000", "$50k", "1.2m" all work
	local function customValue(key: string): number?
		local raw = Cfg.Streamer and Cfg.Streamer[key]
		if type(raw) ~= "string" then return nil end
		raw = raw:lower():gsub("[%s%$,]", "")
		if raw == "" then return nil end
		local num, suffix = raw:match("^([%d%.]+)([km]?)$")
		local n = tonumber(num)
		if not n then return nil end
		if suffix == "k" then n = n * 1e3 elseif suffix == "m" then n = n * 1e6 end
		return math.floor(n)
	end
	local function realValue(names) local v = valueObj(LP, names); return v and v.Value or nil end
	local function fakeValue(names)
		if not fake.player then return nil end
		local v = valueObj(fake.player, names)
		return v and v.Value or nil
	end

	-- helpers -----------------------------------------------------------------
	local function esc(s: string): string return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end
	local function escRepl(s: string): string return (s:gsub("%%", "%%%%")) end
	local function isGrouped(core: string): boolean
		-- "3.000", "33,036", "1.000.000": first group 1-3 digits, every later group exactly 3
		local sep = core:match("%d([%.,])")
		if not sep then return true end
		local first = true
		for group in (core .. sep):gmatch("(%d*)" .. esc(sep)) do
			if first then
				if #group < 1 or #group > 3 then return false end
				first = false
			elseif #group ~= 3 then
				return false
			end
		end
		return true
	end
	local function formatLike(sample: string, n: number): string
		local str = tostring(math.floor(n))
		local sep = sample:match("%d([%.,])%d%d%d")
		if sep then
			str = str:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
			if str:sub(1, 1) == sep then str = str:sub(2) end
		end
		return str
	end
	local function rewriteMoney(text: string, rec): string
		local mv, bv = realValue(MONEY_NAMES), realValue(BANK_NAMES)
		if not mv and not bv then return text end
		return (text:gsub("%d[%d%.,]*", function(tok)
			local trail = tok:match("[%.,]+$") or ""
			local core = tok:sub(1, #tok - #trail)
			if not isGrouped(core) then return nil end
			local n = tonumber((core:gsub("[^%d]", "")))
			if not n or n < 10 then return nil end
			local replacement
			-- priority: typed value in the Streamer box > spoof target's value > masked
			if mv and n == mv then
				local f = customValue("Cash") or (hideIdentity and fakeValue(MONEY_NAMES)) or nil
				replacement = f and formatLike(core, f) or (hideIdentity and MASK or nil)
			elseif bv and n == bv then
				local f
				if rec.phone then f = customValue("Card Balance") end
				f = f or customValue("Bank") or (hideIdentity and fakeValue(BANK_NAMES)) or nil
				replacement = f and formatLike(core, f) or (hideIdentity and MASK or nil)
			end
			return replacement and (replacement .. trail) or nil
		end))
	end
	local function rewriteText(inst, rec, real: string): string
		local out = real
		if hideIdentity and out:find(REAL_NAME, 1, true) then
			out = out:gsub("@" .. esc(REAL_NAME), "@" .. escRepl(fake.name))
			local shown = (REAL_NAME == REAL_DISPLAY) and fake.display or fake.name
			out = out:gsub(esc(REAL_NAME), escRepl(shown))
		end
		if hideIdentity and REAL_DISPLAY ~= REAL_NAME and out:find(REAL_DISPLAY, 1, true) then
			out = out:gsub(esc(REAL_DISPLAY), escRepl(fake.display))
		end
		if hideIdentity and out:find(REAL_ID, 1, true) then out = out:gsub(REAL_ID, fake.id) end
		if rec.pg and (out:find("%$") or MONEY_LABEL_NAMES[inst.Name]) then out = rewriteMoney(out, rec) end
		if rec.level then
			local lv = realValue(LEVEL_NAMES)
			if lv and out:match("^%s*" .. lv .. "%s*$") then
				local f = customValue("Level") or (hideIdentity and fakeValue(LEVEL_NAMES)) or nil
				if f then out = tostring(f) elseif hideIdentity then out = "?" end
			end
		end
		return out
	end
	local function rewriteImage(real: string): string
		if hideIdentity and real:find(REAL_ID, 1, true) then return (real:gsub(REAL_ID, fake.id)) end
		return real
	end

	-- tracking ----------------------------------------------------------------
	local function render(inst, rec)
		local out = rec.real
		if active then
			if rec.prop == "Text" then out = rewriteText(inst, rec, out) else out = rewriteImage(out) end
		end
		rec.written = out
		if inst[rec.prop] ~= out then inst[rec.prop] = out end
	end
	local function untrack(inst)
		local rec = tracked[inst]
		if not rec then return end
		if rec.conn then rec.conn:Disconnect() end
		if rec.dconn then rec.dconn:Disconnect() end
		tracked[inst] = nil
	end
	local function track(inst, prop: string, pg: boolean)
		if tracked[inst] then return end
		local rec = { prop = prop, real = inst[prop], written = nil, pg = pg, phone = pg and inst:FindFirstAncestor("PhoneUI") ~= nil }
		-- level labels: the badge on YOUR overhead tag (not other players') and the level-up popup
		if prop == "Text" then
			local mine = (LP.Character ~= nil and inst:IsDescendantOf(LP.Character)) or pg
			local levelish = inst.Name == "Level" or inst:FindFirstAncestor("LevelIcon") ~= nil or inst:FindFirstAncestor("LevelUp") ~= nil
			rec.level = mine and levelish
		end
		tracked[inst] = rec
		rec.conn = inst:GetPropertyChangedSignal(prop):Connect(function()
			local now = inst[prop]
			if now == rec.written then return end
			rec.real = now
			pcall(render, inst, rec)
		end)
		rec.dconn = inst.Destroying:Connect(function() untrack(inst) end)
		render(inst, rec)
	end
	local function consider(inst, where: string)
		local isText = inst:IsA("TextLabel") or inst:IsA("TextButton")
		local isImage = (not isText) and (inst:IsA("ImageLabel") or inst:IsA("ImageButton"))
		if not isText and not isImage then return end
		local holder = inst:FindFirstAncestorWhichIsA("LayerCollector")
		if not holder or holder.Name:sub(1, 10) == "VisionWare" then return end
		if where == "workspace" and not (holder:IsA("BillboardGui") or holder:IsA("SurfaceGui")) then return end
		track(inst, isText and "Text" or "Image", where == "pg")
	end
	local function sweepRoot(root, where: string)
		local ok, list = pcall(root.GetDescendants, root)
		if not ok then return end
		local i, n = 1, #list
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local stop = math.min(n, i + SWEEP_CHUNK - 1)
			for j = i, stop do
				local inst = list[j]
				if active and inst.Parent then pcall(consider, inst, where) end
			end
			i = stop + 1
			if i > n or not active then conn:Disconnect(); sweepConns[conn] = nil; table.clear(list) end
		end)
		sweepConns[conn] = true
	end
	local function roots()
		local list = { { workspace, "workspace" }, { CoreGui, "core" } }
		local pg = LP:FindFirstChildOfClass("PlayerGui")
		if pg then table.insert(list, 1, { pg, "pg" }) end
		return list
	end
	local function rerenderAll()
		for inst, rec in pairs(tracked) do pcall(render, inst, rec) end
	end
	local function startTracking()
		for _, r in ipairs(roots()) do
			local root, where = r[1], r[2]
			sweepRoot(root, where)
			rootConns[#rootConns + 1] = root.DescendantAdded:Connect(function(inst)
				if active then task.defer(function() if inst.Parent then pcall(consider, inst, where) end end) end
			end)
		end
	end
	local function stopTracking()
		for conn in pairs(sweepConns) do conn:Disconnect() end
		table.clear(sweepConns)
		for _, conn in ipairs(rootConns) do conn:Disconnect() end
		table.clear(rootConns)
		rerenderAll()                 -- active is false here, so the real text goes back
		for inst in pairs(tracked) do untrack(inst) end
	end

	-- avatar (character look) ---------------------------------------------------
	-- Humanoid:ApplyDescription is server-only, so the target's avatar is built with
	-- CreateHumanoidModelFromUserId and its clothes / colours / face / accessories are
	-- copied onto the local character. Originals are stored and put back afterwards.
	local avatar = { added = {}, hidden = {}, colors = {}, face = nil, faceTex = nil }
	local COLOR_KEYS = {
		Head = "HeadColor3", Torso = "TorsoColor3", UpperTorso = "TorsoColor3", LowerTorso = "TorsoColor3",
		["Left Arm"] = "LeftArmColor3", LeftUpperArm = "LeftArmColor3", LeftLowerArm = "LeftArmColor3", LeftHand = "LeftArmColor3",
		["Right Arm"] = "RightArmColor3", RightUpperArm = "RightArmColor3", RightLowerArm = "RightArmColor3", RightHand = "RightArmColor3",
		["Left Leg"] = "LeftLegColor3", LeftUpperLeg = "LeftLegColor3", LeftLowerLeg = "LeftLegColor3", LeftFoot = "LeftLegColor3",
		["Right Leg"] = "RightLegColor3", RightUpperLeg = "RightLegColor3", RightLowerLeg = "RightLegColor3", RightFoot = "RightLegColor3",
	}
	local function clearAvatar()
		for _, inst in ipairs(avatar.added) do pcall(function() inst:Destroy() end) end
		table.clear(avatar.added)
		for inst, parent in pairs(avatar.hidden) do
			if parent and parent.Parent then pcall(function() inst.Parent = parent end) end
		end
		table.clear(avatar.hidden)
		for part, color in pairs(avatar.colors) do if part.Parent then part.Color = color end end
		table.clear(avatar.colors)
		if avatar.face and avatar.face.Parent then avatar.face.Texture = avatar.faceTex end
		avatar.face, avatar.faceTex = nil, nil
	end
	local function attachAccessory(char, acc)
		local handle = acc:FindFirstChild("Handle")
		if not handle or not handle:IsA("BasePart") then acc:Destroy() return end
		local hAtt = handle:FindFirstChildOfClass("Attachment")
		local target
		if hAtt then
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("Attachment") and d.Name == hAtt.Name and not d:FindFirstAncestorOfClass("Accessory") then target = d; break end
			end
		end
		local part = target and target.Parent or char:FindFirstChild("Head")
		if not part then acc:Destroy() return end
		for _, w in ipairs(handle:GetChildren()) do
			if w:IsA("JointInstance") or w:IsA("WeldConstraint") or w:IsA("RigidConstraint") then w:Destroy() end
		end
		handle.Anchored, handle.CanCollide, handle.CanQuery, handle.CanTouch, handle.Massless = false, false, false, false, true
		handle.CFrame = target and (target.WorldCFrame * hAtt.CFrame:Inverse()) or part.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = part, handle
		weld.Parent = handle
		acc.Parent = char
		table.insert(avatar.added, acc)
	end
	local avatarToken = 0
	local function applyAvatar()
		avatarToken = avatarToken + 1
		local token = avatarToken
		clearAvatar()
		local char = LP.Character
		if not (active and hideIdentity and fake.idNum and char) then return end
		local ok, model = pcall(Players.CreateHumanoidModelFromUserId, Players, fake.idNum)
		if token ~= avatarToken or LP.Character ~= char then if ok and model then model:Destroy() end return end
		if not ok or not model then Library.Notify("Could not load that user's avatar") return end
		for _, ch in ipairs(char:GetChildren()) do
			if ch:IsA("Accessory") or ch:IsA("Shirt") or ch:IsA("Pants") or ch:IsA("ShirtGraphic") or ch:IsA("BodyColors") then
				avatar.hidden[ch] = char
				ch.Parent = nil
			end
		end
		local bc = model:FindFirstChildOfClass("BodyColors")
		if bc then
			for _, part in ipairs(char:GetChildren()) do
				local key = part:IsA("BasePart") and COLOR_KEYS[part.Name]
				if key then avatar.colors[part] = part.Color; part.Color = bc[key] end
			end
		end
		for _, ch in ipairs(model:GetChildren()) do
			if ch:IsA("Shirt") or ch:IsA("Pants") or ch:IsA("ShirtGraphic") then
				local c = ch:Clone(); c.Parent = char; table.insert(avatar.added, c)
			end
		end
		local myHead, theirHead = char:FindFirstChild("Head"), model:FindFirstChild("Head")
		local myFace = myHead and myHead:FindFirstChildOfClass("Decal")
		local theirFace = theirHead and theirHead:FindFirstChildOfClass("Decal")
		if myFace and theirFace then avatar.face, avatar.faceTex = myFace, myFace.Texture; myFace.Texture = theirFace.Texture end
		for _, ch in ipairs(model:GetChildren()) do
			if ch:IsA("Accessory") then pcall(attachAccessory, char, ch:Clone()) end
		end
		model:Destroy()
	end
	RootMaid:Add(LP.CharacterAdded:Connect(function(char)
		table.clear(avatar.hidden); table.clear(avatar.colors); table.clear(avatar.added)
		avatar.face, avatar.faceTex = nil, nil
		if active and hideIdentity and fake.idNum then
			char:WaitForChild("Humanoid", CHARACTER_WAIT_SECONDS)
			task.wait(1)   -- let the game finish dressing the character first
			applyAvatar()
		end
	end))

	-- target lookup -------------------------------------------------------------
	local function resolve(idStr: string)
		local id = tonumber(idStr)
		if not id then return nil end
		local plr = Players:GetPlayerByUserId(id)
		if plr then return { name = plr.Name, display = plr.DisplayName, id = tostring(id), idNum = id, player = plr } end
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
		if not ok or not name then return nil end
		local display = name
		local ok2, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, { id })
		if ok2 and type(infos) == "table" and infos[1] and infos[1].DisplayName then display = infos[1].DisplayName end
		return { name = name, display = display, id = tostring(id), idNum = id, player = nil }
	end
	local function watchTargetMoney()
		for _, c in ipairs(targetConns) do c:Disconnect() end
		table.clear(targetConns)
		if not fake.player then return end
		local pending = false
		local function soon()
			if pending then return end
			pending = true
			task.delay(0.25, function() pending = false; if active then rerenderAll() end end)
		end
		for _, names in ipairs({ MONEY_NAMES, BANK_NAMES, LEVEL_NAMES }) do
			local v = valueObj(fake.player, names)
			if v then targetConns[#targetConns + 1] = v.Changed:Connect(soon) end
		end
	end

	-- panel wiring ----------------------------------------------------------------
	local generation = 0
	local function refresh()
		generation = generation + 1
		local gen = generation
		-- nothing runs unless the Streamer Mode toggle is on (and the Streamer box's switch):
		-- the Cash / Bank / Card Balance / Level boxes only apply while it is on
		local identity = En("Streamer") and Cfg.Streamer["Streamer Mode"] == true
		local want = identity
		local idStr = (tostring(Cfg.Streamer["Spoof User ID"] or "")):gsub("%s", "")
		local newFake = HIDDEN
		if identity and idStr ~= "" then
			local info = resolve(idStr)
			if gen ~= generation then return end
			if info then newFake = info else Library.Notify("No Roblox user with ID " .. idStr) end
		end
		fake = newFake
		hideIdentity = identity
		watchTargetMoney()
		if want and not active then
			active = true
			startTracking()
		elseif not want and active then
			active = false
			stopTracking()
		else
			rerenderAll()
		end
		applyAvatar()
	end
	for _, key in ipairs({ "Enabled", "Streamer Mode", "Spoof User ID" }) do
		P("Streamer"):On(key, function() task.spawn(refresh) end)
	end
	for _, key in ipairs({ "Cash", "Bank", "Card Balance", "Level" }) do
		P("Streamer"):On(key, function() task.spawn(refresh) end)
	end
	RootMaid:Add(Players.PlayerAdded:Connect(function(plr)
		if active and fake.idNum and plr.UserId == fake.idNum then task.spawn(refresh) end
	end))

	-- other menu parts ask for the name to show
	function Library.ShownName(): string
		return (active and hideIdentity) and fake.display or LP.DisplayName
	end

	RootMaid:Add(function()
		generation = generation + 1
		for _, c in ipairs(targetConns) do c:Disconnect() end
		if active then active = false; stopTracking() end
		avatarToken = avatarToken + 1
		clearAvatar()
	end)
end

---------------------------------------------------------------------------
-- 9b2. Nav: the menu's own path finder, used by every trip.
--   A grid A* over the map, built on the fly from raycasts (only collidable parts
--   count, so invisible walls do and decorations do not):
--   * a cell is walkable when there is solid ground (not water) within a step of
--     the cell it is entered from, with room for a body above it;
--   * moving between two cells sweeps a body-sized sphere at body height, so walls,
--     fences, poles, railings and parked cars are never crossed;
--   * the cell path is pulled tight (string pulling, same checks, ground followed
--     every few studs) into the fewest straight legs, then resampled so the route
--     follows the real ground height.
--   Areas that are not loaded count as blocked.
---------------------------------------------------------------------------
Library.Nav = (function()
	local CELL       = 6        -- grid size (studs)
	local STEP_UP    = 2.6      -- biggest height change between neighbouring cells
	local HEAD       = 7.5      -- room needed above the ground (rider's head included)
	local BODY = {              -- swept body per mode: half width, sweep height above the floor
		walk = { r = 1.4, y = 2.7 },
		ride = { r = 2.3, y = 3.3 },   -- the scooter is ~5 long: sweep its whole length
	}
	local MAX_NODES  = 45000    -- A* node budget
	local TIME_LIMIT = 4        -- seconds of searching before giving up
	local WEIGHT     = 1.2      -- heuristic weight: much faster, routes stay near-shortest
	local ROAD       = "CantCrashInThis"   -- the game's ground blocks (roads are the bare ones)
	local Nav = {}

	-- floors: only solid (collidable) parts can be stood on
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	-- obstacles: anything solid OR visible (many walls / props here have no collision
	-- but you would still see yourself go through them); invisible trigger zones
	-- (non-collidable and fully transparent) are ignored
	local solid = RaycastParams.new()
	solid.FilterType = Enum.RaycastFilterType.Exclude
	solid.RespectCanCollide = false
	local ghosts, ghostList, ghostsDirty, ghostsBuilt = {}, {}, false, false
	local function isGhost(d): boolean
		return d:IsA("BasePart") and not d.CanCollide and d.Transparency >= 0.95
	end
	local function addGhost(d)
		if not ghosts[d] and isGhost(d) then ghosts[d] = true ghostsDirty = true end
	end
	local function buildGhosts()
		if ghostsBuilt then return end
		ghostsBuilt = true
		for _, d in ipairs(workspace:GetDescendants()) do addGhost(d) end
		-- new parts are checked in one batch per frame (a teleport streams in tens of
		-- thousands of instances; one deferred task each was a lot of overhead), and
		-- only parts are queued at all
		local pending, queued = {}, false
		local function flush()
			queued = false
			for i = 1, #pending do addGhost(pending[i]) end
			table.clear(pending)
		end
		RootMaid:Add(workspace.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				pending[#pending + 1] = d
				if not queued then queued = true task.defer(flush) end
			end
		end))
	end
	local function refresh()
		buildGhosts()
		local ignore = {}
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
		local vehicles = workspace:FindFirstChild("Vehicles")
		if vehicles then                                   -- your own vehicle is not an obstacle
			for _, v in ipairs(vehicles:GetChildren()) do
				if v.Name:find(LP.Name, 1, true) then table.insert(ignore, v) end
			end
		end
		params.FilterDescendantsInstances = ignore
		if ghostsDirty then
			ghostsDirty = false
			table.clear(ghostList)
			for g in pairs(ghosts) do if g.Parent then table.insert(ghostList, g) else ghosts[g] = nil end end
		end
		local all = table.clone(ghostList)
		for _, x in ipairs(ignore) do table.insert(all, x) end
		solid.FilterDescendantsInstances = all
	end
	Nav.refresh = refresh

	-- Show Path (Teleports tab): while a search runs, every part that blocks a move
	-- (a wall, pole, fence, low ceiling...) is noted; afterwards the route and those
	-- parts are drawn (see draw below)
	local recording, walls, wallCount = false, {}, 0
	local MAX_WALLS = 400
	local function noteWall(hit)
		if recording and hit and not walls[hit.Instance] and wallCount < MAX_WALLS then
			walls[hit.Instance] = true
			wallCount = wallCount + 1
		end
	end

	local function down(x: number, z: number, top: number, depth: number)
		return workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -depth, 0), params)
	end
	local function headroom(p: Vector3): boolean
		local hit = workspace:Raycast(p + Vector3.new(0, 0.6, 0), Vector3.new(0, HEAD, 0), solid)
		noteWall(hit)
		return hit == nil
	end
	local function openSky(p: Vector3): boolean
		return workspace:Raycast(p + Vector3.new(0, 0.6, 0), Vector3.new(0, 220, 0), solid) == nil
	end
	-- outdoors (no solid roof overhead; a lamp head, sign or leaves above do not count)
	local function outdoors(p: Vector3): boolean
		return workspace:Raycast(p + Vector3.new(0, 0.6, 0), Vector3.new(0, 220, 0), params) == nil
	end
	-- a body-sized sphere can move from floor point a to floor point b
	local function sweep(a: Vector3, b: Vector3, body): boolean
		local y = math.max(a.Y, b.Y) + body.y
		local from = Vector3.new(a.X, y, a.Z)
		local dir = Vector3.new(b.X, y, b.Z) - from
		if dir.Magnitude < 0.05 then return true end
		local hit = workspace:Spherecast(from, body.r, dir, solid)
		noteWall(hit)
		return hit == nil
	end
	-- the floor at (x, z) reachable from a floor at height fromY (within a step), or nil
	local function floorAt(x: number, z: number, fromY: number)
		local hit = down(x, z, fromY + STEP_UP + 1.5, STEP_UP * 2 + 14)
		if not hit or hit.Material == Enum.Material.Water then return nil end
		local y = hit.Position.Y
		if math.abs(y - fromY) > STEP_UP then return nil end
		local p = Vector3.new(x, y, z)
		if not headroom(p) then return nil end
		return p, hit
	end
	-- the floor under a point (feet level), whatever its height
	function Nav.floor(p: Vector3): Vector3?
		refresh()
		local hit = down(p.X, p.Z, p.Y + 3, 40)
		if not hit or hit.Material == Enum.Material.Water then return nil end
		return hit.Position
	end
	-- the floor under p is one of the game's ground blocks (a street, not a roof / deck)
	function Nav.onGround(p: Vector3): boolean
		refresh()
		local hit = down(p.X, p.Z, p.Y + 3, 12)
		return hit ~= nil and hit.Instance.Name == ROAD
	end

	-- straight leg a -> b is walkable: ground all along (within a step each few studs)
	-- and a clear sweep between the samples
	local function legClear(a: Vector3, b: Vector3, body): boolean
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local n = math.max(1, math.ceil(flat.Magnitude / 3))
		local prev = a
		for i = 1, n do
			local t = i / n
			local p = floorAt(a.X + flat.X * t, a.Z + flat.Z * t, prev.Y)
			if not p or not sweep(prev, p, body) then return false end
			prev = p
		end
		return math.abs(prev.Y - b.Y) <= STEP_UP
	end
	-- the leg as dense ground-following points (every ~3 studs), after a
	local function legPoints(a: Vector3, b: Vector3, out)
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local n = math.max(1, math.ceil(flat.Magnitude / 3))
		local prevY = a.Y
		for i = 1, n do
			local t = i / n
			local x, z = a.X + flat.X * t, a.Z + flat.Z * t
			local p = floorAt(x, z, prevY)
			local y = p and p.Y or (a.Y + (b.Y - a.Y) * t)
			table.insert(out, Vector3.new(x, y, z))
			prevY = y
		end
	end

	-- string pulling: from each point jump as far ahead as a clear leg allows
	-- (galloping then binary search), then resample the legs on the ground
	local function smooth(pts, body)
		if #pts <= 2 then return pts end
		local keep = { pts[1] }
		local i = 1
		while i < #pts do
			local good, step = i + 1, 1
			while true do                                 -- gallop
				local j = math.min(#pts, i + step * 2)
				if j == good or not legClear(pts[i], pts[j], body) then break end
				good = j
				if j == #pts then break end
				step = step * 2
			end
			local lo, hi = good, math.min(#pts, i + step * 2)
			while hi - lo > 1 do                          -- binary search between
				local mid = (lo + hi) // 2
				if legClear(pts[i], pts[mid], body) then lo = mid else hi = mid end
			end
			table.insert(keep, pts[lo])
			i = lo
		end
		local out = { keep[1] }
		for k = 2, #keep do legPoints(keep[k - 1], keep[k], out) end
		return out
	end

	-- binary heap on f
	local function heapPush(h, fs, id)
		table.insert(h, id)
		local i = #h
		while i > 1 do
			local parent = i // 2
			if fs[h[parent]] <= fs[h[i]] then break end
			h[parent], h[i] = h[i], h[parent]
			i = parent
		end
	end
	local function heapPop(h, fs)
		local top = h[1]
		local last = table.remove(h)
		if #h > 0 then
			h[1] = last
			local i, n = 1, #h
			while true do
				local l, r, s = i * 2, i * 2 + 1, i
				if l <= n and fs[h[l]] < fs[h[s]] then s = l end
				if r <= n and fs[h[r]] < fs[h[s]] then s = r end
				if s == i then break end
				h[s], h[i] = h[i], h[s]
				i = s
			end
		end
		return top
	end

	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
	-- from / to are floor points (feet level). mode "ride" prefers roads and sweeps a
	-- scooter-sized body, "walk" a person-sized one. Returns dense ground-following
	-- points (feet level), or nil. With to = nil and pred given it finds the nearest
	-- reachable cell where pred(point) is true (plain Dijkstra, small budget).
	local function findRoute(from: Vector3, to: Vector3?, mode: string?, pred)
		refresh()
		local t0 = os.clock()
		local ride = mode == "ride"
		local body = ride and BODY.ride or BODY.walk
		local start = floorAt(from.X, from.Z, from.Y) or from
		local goal = to or start
		local nodeCap = to and MAX_NODES or 4000
		if pred and pred(start) then return { start } end
		if to and (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(start.X, 0, start.Z)).Magnitude < CELL and math.abs(goal.Y - start.Y) <= STEP_UP and legClear(start, goal, body) then
			return { start, goal }
		end
		local ox, oz = start.X, start.Z                  -- grid anchored on the start
		local pos, g, fs, parent, closed = {}, {}, {}, {}, {}
		local heap = {}
		local function keyOf(ix, iz, y) return ix .. "," .. iz .. "," .. math.floor(y / 4 + 0.5) end
		local function h(p)
			if not to then return 0 end
			local dx, dz = math.abs(p.X - goal.X), math.abs(p.Z - goal.Z)
			return (math.max(dx, dz) + 0.41421356 * math.min(dx, dz)) * WEIGHT
		end
		local surfaceCost = {}
		local function costAt(p, hit)
			if not ride then return 1 end
			if hit and hit.Instance and hit.Instance.Name == ROAD and outdoors(p) then return 1 end
			return 1.3                                    -- sidewalks / grass / indoors: allowed, not preferred
		end
		local startKey = keyOf(0, 0, start.Y)
		pos[startKey], g[startKey], fs[startKey] = start, 0, h(start)
		heapPush(heap, fs, startKey)
		local cellOf = { [startKey] = { 0, 0 } }
		local expanded, found = 0, nil
		while #heap > 0 do
			local cur = heapPop(heap, fs)
			if not closed[cur] then
				closed[cur] = true
				local p = pos[cur]
				if to then
					if (Vector3.new(p.X - goal.X, 0, p.Z - goal.Z)).Magnitude <= CELL * 1.5 and math.abs(p.Y - goal.Y) <= STEP_UP * 2 and sweep(p, goal, body) then
						found = cur
						break
					end
				elseif pred(p) then
					found = cur
					break
				end
				expanded = expanded + 1
				if expanded > nodeCap or os.clock() - t0 > TIME_LIMIT then break end
				if expanded % 300 == 0 then RunService.Heartbeat:Wait() end
				local c = cellOf[cur]
				for _, d in ipairs(DIRS) do
					local ix, iz = c[1] + d[1], c[2] + d[2]
					local np, hit = floorAt(ox + ix * CELL, oz + iz * CELL, p.Y)
					if np then
						local k = keyOf(ix, iz, np.Y)
						if not closed[k] then
							local step = (d[1] ~= 0 and d[2] ~= 0) and CELL * 1.41421356 or CELL
							local ng = g[cur] + step * (surfaceCost[k] or costAt(np, hit))
							if (g[k] == nil or ng < g[k]) and sweep(p, np, body) then
								surfaceCost[k] = surfaceCost[k] or costAt(np, hit)
								g[k], pos[k], parent[k], cellOf[k] = ng, np, cur, { ix, iz }
								fs[k] = ng + h(np)
								heapPush(heap, fs, k)
							end
						end
					end
				end
			end
		end
		if not found then return nil end
		local rev, k = {}, found
		while k do table.insert(rev, pos[k]) k = parent[k] end
		local pts = {}
		for i = #rev, 1, -1 do table.insert(pts, rev[i]) end
		if to then table.insert(pts, goal) end
		return smooth(pts, body)
	end

	-- Show Path drawing: local parts in workspace.VisionWarePathDebug that raycasts
	-- and touches ignore (CanQuery / CanTouch off), so they never affect the finder
	local ROUTE_COLOR, WALL_COLOR = Color3.fromRGB(89, 176, 252), Color3.fromRGB(255, 70, 70)
	local drawFolder
	local function showPath(): boolean
		local c = Cfg.Teleport
		return c ~= nil and c["Show Path"] == true
	end
	local function clearDrawing()
		if drawFolder then drawFolder:Destroy() drawFolder = nil end
	end
	local function newPart(color: Color3, shape)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = color
		if shape then p.Shape = shape end
		p.Parent = drawFolder
		return p
	end
	local function segment(a: Vector3, b: Vector3, color: Color3, width: number)
		local len = (b - a).Magnitude
		if len < 0.05 then return end
		local p = newPart(color)
		p.Size = Vector3.new(width, width, len)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
	end
	local function dot(at: Vector3, color: Color3, size: number)
		local p = newPart(color, Enum.PartType.Ball)
		p.Size = Vector3.new(size, size, size)
		p.CFrame = CFrame.new(at)
	end
	local function draw(route, from: Vector3, to: Vector3?)
		clearDrawing()
		drawFolder = Instance.new("Folder")
		drawFolder.Name = "VisionWarePathDebug"
		drawFolder.Parent = workspace
		for part in pairs(walls) do                       -- what it treated as walls
			if part.Parent and part:IsA("BasePart") then
				local box = Instance.new("SelectionBox")
				box.Adornee = part
				box.Color3 = WALL_COLOR
				box.LineThickness = 0.06
				box.SurfaceTransparency = 1
				box.Parent = drawFolder
			end
		end
		local up = Vector3.new(0, 0.4, 0)                -- just above the floor
		if route and #route > 0 then                      -- where it is going
			for i = 2, #route do segment(route[i - 1] + up, route[i] + up, ROUTE_COLOR, 0.3) end
			dot(route[1] + up, Color3.fromRGB(80, 230, 120), 1.2)       -- start
			dot(route[#route] + up, ROUTE_COLOR, 1.6)                   -- goal
		elseif to then                                    -- no route found: where it wanted to go
			segment(from + up, to + up, WALL_COLOR, 0.2)
			dot(to + up, WALL_COLOR, 1.6)
		end
	end
	P("Teleport"):On("Show Path", function(v) if not v then clearDrawing() end end)
	RootMaid:Add(clearDrawing)

	-- the path finder (see findRoute); with Show Path on, the route and the walls it
	-- ran into are drawn each time
	function Nav.find(from: Vector3, to: Vector3?, mode: string?, pred)
		local drawing = showPath()
		if drawing then
			recording = true
			table.clear(walls)
			wallCount = 0
		end
		local ok, route = pcall(findRoute, from, to, mode, pred)
		recording = false
		if drawing then pcall(draw, ok and route or nil, from, to) end
		if not ok then error(route, 0) end
		return route
	end
	-- the nearest spot under open sky you can get to from 'from' (to leave a building
	-- or an overhang before flying, or before calling the scooter over)
	function Nav.findOpen(from: Vector3, mode: string?)
		return Nav.find(from, nil, mode, function(p) return openSky(p) end)
	end

	Nav.openSky = function(p) refresh() return openSky(p) end

	return Nav
end)()

---------------------------------------------------------------------------
-- 9c. Autofarm: shared travel methods + Box Job
--
-- Ported from the user's "Scooter -> Box Job (v39)" script, same logic and timings:
--   Travel.walkTo = pathfinding glide on foot; Travel.toScooter = walk to your
--   scooter, or to the nearest rental and rent one. Travel.moveTo (the scooter
--   ride to a place) was removed and is being remade: it reports that for now.
--   Box Job = pickup -> glide to delivery -> deliver -> glide back, repeated while
--   its toggle is on.
-- The path lines / markers / tracker ball from the script are debug visuals and
-- are left out. Railing tags are removed again when the menu unloads.
---------------------------------------------------------------------------
do
	local PathfindingService = game:GetService("PathfindingService")

	-- Box Job route (measured in this map)
	local GROUND_Y   = 52
	local PARK_POS   = Vector3.new(199, 52, 387)
	local PICKUP_POS = Vector3.new(201, 52, 340)
	local WP1        = Vector3.new(200, 52, 295)
	local WP2        = Vector3.new(161, 53, 262)

	local BOX_CASH_RADIUS    = 30     -- Box Job: grab dropped cash this close to the delivery spot
	local PROMPT_STOP_DIST   = 6      -- stop at most this far from a scooter's prompt
	local PROMPT_MARGIN      = 2      -- ... and this far inside the prompt's reach
	local RENT_ATTEMPTS      = 3
	local ARRIVE_RADIUS      = 12     -- already this close to the pickup: skip travel
	local SEAT_TIMEOUT       = 2
	local VEHICLE_SPAWN_WAIT = 5
	local RESPAWN_WAIT       = 15
	local MAX_FAILS          = 3
	local RAILING_TEXTURE    = "rbxassetid://7728516136"

	local Travel = {}
	Library.Travel = Travel
	local function settings() return Cfg["Autofarm Settings"] end

	local function refs()
		local c = LP.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and hrp then return c, hum, hrp end
		return nil, nil, nil
	end

	-- pathfinding avoids the map's railings: they are tagged once and restored on unload
	local railMods, railCollide, railsTagged = {}, {}, false
	local function tagRailings()
		if railsTagged then return end
		railsTagged = true
		local map = workspace:FindFirstChild("Map")
		if not map then return end
		for _, d in ipairs(map:GetDescendants()) do
			if d:IsA("Texture") and d.Texture == RAILING_TEXTURE then
				local part = d.Parent
				if part and part:IsA("BasePart") and not part:FindFirstChild("_RailMod") then
					local mod = Instance.new("PathfindingModifier")
					mod.Name, mod.Label, mod.PassThrough = "_RailMod", "Railing", false
					mod.Parent = part
					railMods[#railMods + 1] = mod
					if railCollide[part] == nil then railCollide[part] = part.CanCollide end
					part.CanCollide = true
				end
			end
		end
	end
	RootMaid:Add(function()
		for _, m in ipairs(railMods) do pcall(m.Destroy, m) end
		for part, was in pairs(railCollide) do if part.Parent then part.CanCollide = was end end
	end)

	-- how high the root part sits above the ground when standing
	local function standHeight(): number
		local _, hum, hrp = refs()
		if hum and hrp then return hum.HipHeight + hrp.Size.Y / 2 end
		return 3
	end

	-- y = a number: every point at that fixed height (the Box Job's locked route).
	-- y = nil: follow the path's real ground height (+ standing height), so leaving
	-- an area goes over slopes / steps / around things instead of through them.
	local function computePath(fromPos: Vector3, toPos: Vector3, y: number?)
		local points = {}
		local lift = standHeight()
		local path = PathfindingService:CreatePath({
			AgentRadius = 4, AgentHeight = 6, AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 4,
			Costs = { Climb = math.huge, Jump = 5, Railing = math.huge },
		})
		local ok = pcall(path.ComputeAsync, path, fromPos, toPos)
		if ok and path.Status == Enum.PathStatus.Success then
			for _, wp in ipairs(path:GetWaypoints()) do
				points[#points + 1] = Vector3.new(wp.Position.X, y or (wp.Position.Y + lift), wp.Position.Z)
			end
			return points, true
		end
		points[1] = Vector3.new(fromPos.X, y or fromPos.Y, fromPos.Z)
		points[2] = Vector3.new(toPos.X, y or toPos.Y, toPos.Z)
		return points, false
	end

	-- slide the root part along the points at Travel Speed; y = a fixed height, or
	-- nil to use each point's own height. Returns false if cancelled or the
	-- character is gone.
	local function glide(points, y: number?, cancelled): boolean
		if #points < 2 then return true end
		local cum, total = { 0 }, 0
		for i = 2, #points do
			total = total + (points[i] - points[i - 1]).Magnitude
			cum[i] = total
		end
		if total < 0.5 then return true end
		local speed = math.max(1, settings()["Travel Speed"] or 25)
		local duration = total / speed
		local start = os.clock()
		while true do
			if cancelled() then return false end
			local _, _, hrp = refs()
			if not hrp then return false end
			local alpha = math.min((os.clock() - start) / duration, 1)
			local target = alpha * total
			local seg = #points - 1
			for i = 2, #cum do
				if cum[i] >= target then seg = i - 1; break end
			end
			local segLen = cum[seg + 1] - cum[seg]
			local segAlpha = segLen > 0 and math.clamp((target - cum[seg]) / segLen, 0, 1) or 0
			local p = points[seg]:Lerp(points[seg + 1], segAlpha)
			hrp.CFrame = CFrame.new(p.X, y or p.Y, p.Z)
			if alpha >= 1 then return true end
			RunService.Heartbeat:Wait()
		end
	end
	Travel.glide = glide

	-- dropped cash: a "Money" part with a "Grab Cash" prompt (ReplicatedStorage.Misc.Money
	-- clones). Grabs every one within radius of center: everything already in reach is
	-- fired at once, the rest by snapping next to each (no glide), hold skipped.
	-- Returns how many were grabbed.
	local function cashPrompts(center: Vector3, radius: number, tried)
		local list = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(center, radius)) do
			if part.Name == "Money" and not tried[part] then
				local pr = part:FindFirstChildWhichIsA("ProximityPrompt")
				if pr and pr.Enabled and pr.ObjectText == "Grab Cash" then table.insert(list, { part = part, prompt = pr }) end
			end
		end
		return list
	end
	local function fireCash(pr)
		local hold = pr.HoldDuration
		pr.HoldDuration = 0
		pcall(fireproximityprompt, pr)
		pr.HoldDuration = hold
	end
	-- fire every cash prompt already in reach, no movement; used while waiting at a
	-- register. seen (optional) remembers every cash pile that has shown up; returns
	-- how many different piles have shown up so far.
	function Travel.grabCashInReach(center: Vector3, radius: number, seen): number
		seen = seen or {}
		local _, _, hrp = refs()
		if hrp then
			for _, c in ipairs(cashPrompts(center, radius, {})) do
				seen[c.part] = true
				if (c.part.Position - hrp.Position).Magnitude < c.prompt.MaxActivationDistance - 0.5 then
					fireCash(c.prompt)
				end
			end
		end
		local n = 0
		for _ in pairs(seen) do n = n + 1 end
		return n
	end
	function Travel.grabCash(center: Vector3, radius: number, cancelled): number
		local grabbed, tried = 0, {}
		for _ = 1, 4 do                                          -- a few sweeps catch late drops
			if cancelled and cancelled() then break end
			local _, _, hrp = refs()
			if not hrp then break end
			local list = cashPrompts(center, radius, tried)
			if #list == 0 then break end
			local here = hrp.Position
			table.sort(list, function(a, b) return (a.part.Position - here).Magnitude < (b.part.Position - here).Magnitude end)
			for _, c in ipairs(list) do
				if cancelled and cancelled() then break end
				_, _, hrp = refs()
				if not hrp then break end
				if c.part.Parent then
					tried[c.part] = true
					if (c.part.Position - hrp.Position).Magnitude > c.prompt.MaxActivationDistance - 1 then
						hrp.CFrame = CFrame.new(c.part.Position + Vector3.new(0, 2.5, 0)) * hrp.CFrame.Rotation
						hrp.AssemblyLinearVelocity = Vector3.zero
						RunService.Heartbeat:Wait()
					end
					fireCash(c.prompt)
					grabbed = grabbed + 1
				end
			end
			task.wait(0.1)
		end
		return grabbed
	end

	-- prone (crawl) through the game's own crouch control: its Crouch button cycles
	-- stand -> crouch -> crawl -> stand, and the game keeps the state in _G.Crawling
	function Travel.setProne(on: boolean)
		local genv = (type(getrenv) == "function" and getrenv()._G) or _G
		local main = LP:FindFirstChildOfClass("PlayerGui") and LP.PlayerGui:FindFirstChild("MobileUIs")
		local button = main and main:FindFirstChild("Crouch", true)
		if not (button and type(getconnections) == "function") then return false end
		local function press()
			for _, c in ipairs(getconnections(button.MouseButton1Click)) do pcall(function() c:Fire() end) end
			task.wait(0.15)
		end
		for _ = 1, 3 do
			if (genv.Crawling == true) == on and (on or not genv.Crouching) then return true end
			press()
		end
		return (genv.Crawling == true) == on
	end

	-- vehicles --------------------------------------------------------------
	local function vehiclesFolder() return workspace:FindFirstChild("Vehicles") end
	local function ownsVehicle(v) return v.Name:find(LP.Name, 1, true) ~= nil end
	local function findMyScooter()
		local folder = vehiclesFolder()
		if not folder then return nil end
		for _, v in ipairs(folder:GetChildren()) do
			if ownsVehicle(v) then
				local seat = v:FindFirstChild("DriveSeat")
				local prompt = seat and seat:FindFirstChild("Interact")
				if prompt and prompt:IsA("ProximityPrompt") and prompt.ActionText:find("Scooter", 1, true) then return v end
			end
		end
		return nil
	end
	local function waitForMyVehicle(cancelled)
		local folder = vehiclesFolder()
		local deadline = os.clock() + VEHICLE_SPAWN_WAIT
		while folder and os.clock() < deadline and not cancelled() do
			-- only one you can sit on (an old wrecked one has no DriveSeat)
			for _, v in ipairs(folder:GetChildren()) do
				local seat = ownsVehicle(v) and v:FindFirstChild("DriveSeat")
				if seat and seat:FindFirstChild("Interact") then return v end
			end
			task.wait(0.3)
		end
		return nil
	end
	local function closestRental(fromPos: Vector3)
		local map = workspace:FindFirstChild("Map")
		local folder = map and map:FindFirstChild("Scooters")
		if not folder then return nil end
		local best
		for _, scooter in ipairs(folder:GetChildren()) do
			if scooter:IsA("Model") then
				for _, d in ipairs(scooter:GetDescendants()) do
					if d.Name == "Position" and d:IsA("BasePart") then
						local prompt = d:FindFirstChildOfClass("ProximityPrompt")
						if prompt then
							local dist = (fromPos - d.Position).Magnitude
							if not best or dist < best.dist then best = { dist = dist, pos = d.Position, prompt = prompt } end
						end
						break
					end
				end
			end
		end
		return best
	end
	-- cash for a scooter rental: if your wallet is short, withdraw only the missing
	-- amount from the bank through the game's ATM remote (works from anywhere)
	local DEFAULT_RENT_COST = 150
	local WITHDRAW_WAIT = 3
	local function rentCost(prompt): number
		local n = tonumber(((prompt and prompt.ObjectText or "") .. " " .. (prompt and prompt.ActionText or "")):gsub(",", ""):match("%$%s*(%d+)") or "")
		return n or DEFAULT_RENT_COST
	end
	function Travel.ensureCash(amount: number)
		local data = LP:FindFirstChild("Data")
		local money = data and data:FindFirstChild("Money")
		local bank = data and data:FindFirstChild("Bank")
		if not money then return true end                    -- cannot tell, let the game decide
		if money.Value >= amount then return true end
		local need = math.ceil(amount - money.Value)
		if not bank or bank.Value < need then return false, ("not enough money: need $%d more and the bank has $%d"):format(need, bank and bank.Value or 0) end
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		local atm = remotes and remotes:FindFirstChild("ATM")
		if not (atm and atm:IsA("RemoteEvent")) then return false, "no ATM remote to withdraw with" end
		local ok = pcall(atm.FireServer, atm, "Withdraw", need)
		if not ok then return false, "withdraw failed" end
		local deadline = os.clock() + WITHDRAW_WAIT
		while money.Value < amount and os.clock() < deadline do task.wait(0.1) end
		if money.Value < amount then return false, "the bank did not pay out" end
		Library.Notify(("Withdrew $%d from the bank"):format(need))
		return true
	end

	do   -- own scope: keeps the farm section under Luau's 200-local limit
		-- Trips (Nav, section 9b2, does the route finding). The scooter teleport /
		-- riding was removed (to be remade); what is left: walking a path-found route
		-- (walkTo) and getting to your scooter (toScooter: walk to it, or walk to the
		-- nearest rental and rent one).
		-- far parts of the map may not be loaded yet (no buildings to avoid there), so
		-- only the part of a route within TRUST_R of you is followed, then the route is
		-- planned again from there with the newly loaded area
		local TRUST_R = 150
		local function feetOf(hrp) return hrp.Position - Vector3.new(0, standHeight(), 0) end
		local function trustedPart(pts, center: Vector3)
			local out = { pts[1] }
			for i = 2, #pts do
				table.insert(out, pts[i])
				if Vector3.new(pts[i].X - center.X, 0, pts[i].Z - center.Z).Magnitude > TRUST_R then return out, false end
			end
			return out, true
		end
		-- walk a path-found route to a feet-level point
		function Travel.walkTo(target: Vector3, cancelled): boolean
			cancelled = cancelled or function() return false end
			local Nav = Library.Nav
			for _ = 1, 12 do
				local _, _, hrp = refs()
				if not hrp then return false end
				local here = feetOf(hrp)
				if Vector3.new(here.X - target.X, 0, here.Z - target.Z).Magnitude < 1.5 then return true end
				local pts = Nav.find(here, target, "walk")
				if not pts then
					-- the menu's finder found nothing: the game's path finder, only if it
					-- found a real route (never a straight line through things)
					local alt, found = computePath(hrp.Position, target + Vector3.new(0, standHeight(), 0), nil)
					if not found then return false end
					return glide(alt, nil, cancelled)
				end
				local part, done = trustedPart(pts, here)
				local lift = standHeight()
				for i, p in ipairs(part) do part[i] = p + Vector3.new(0, lift, 0) end
				if not glide(part, nil, cancelled) then return false end
				if done then return true end
			end
			return false
		end
		-- walk to your scooter, or walk the path to the nearest rental and rent one;
		-- returns the scooter (you are left standing next to it, not seated)
		function Travel.toScooter(cancelled)
			cancelled = cancelled or function() return false end
			local _, _, hrp = refs()
			if not hrp then return nil end
			local vehicle = findMyScooter()
			if vehicle then
				local at = vehicle:GetPivot().Position
				local dir = Vector3.new(hrp.Position.X - at.X, 0, hrp.Position.Z - at.Z)
				dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
				local side = at + dir * 4
				local stop = Library.Nav.floor(side + Vector3.new(0, 2, 0)) or (side - Vector3.new(0, 2, 0))
				if not Travel.walkTo(stop, cancelled) then return nil, "could not walk to your scooter" end
				return vehicle
			end
			local rental = closestRental(hrp.Position)
			if not rental then return nil, "no scooter rental found" end
			local dir = Vector3.new(rental.pos.X - hrp.Position.X, 0, rental.pos.Z - hrp.Position.Z)
			dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
			-- the rental prompt only reaches ~6 studs: stop well inside it
			local stopDist = math.max(1.5, math.min(PROMPT_STOP_DIST, rental.prompt.MaxActivationDistance - PROMPT_MARGIN))
			local stop = Library.Nav.floor(rental.pos - dir * stopDist) or (rental.pos - dir * stopDist - Vector3.new(0, 2, 0))
			if not Travel.walkTo(stop, cancelled) then return nil, "could not walk to the scooter rental" end
			task.wait(0.15)
			local canPay, why = Travel.ensureCash(rentCost(rental.prompt))
			if not canPay then return nil, why end
			for _ = 1, RENT_ATTEMPTS do                     -- a single fire sometimes does nothing
				if cancelled() then return nil end
				pcall(fireproximityprompt, rental.prompt)
				task.wait(1)
				vehicle = waitForMyVehicle(cancelled)
				if vehicle then break end
			end
			if not vehicle then return nil, "no scooter spawned" end
			return vehicle
		end

		-- your scooter, seated or not
		function Travel.myScooterSeat(vehicle)
			local _, hum = refs()
			local seat = hum and hum.SeatPart
			if seat and vehicle and seat:IsDescendantOf(vehicle) then return seat end
			if seat and not vehicle then
				local model = seat:FindFirstAncestorOfClass("Model")
				if model and ownsVehicle(model) then return seat, model end
			end
			return nil
		end
		-- freeze / unfreeze a vehicle where it is (anchored on your side only; parts are
		-- tagged so only what was frozen here is unfrozen). Move it first and let the
		-- move reach the server (settleFreeze), then freeze, so it holds exactly there.
		function Travel.freezeVehicle(vehicle, on: boolean)
			for _, d in ipairs(vehicle:GetDescendants()) do
				if d:IsA("BasePart") then
					if on then
						if not d.Anchored then d:SetAttribute("VW_Frozen", true) d.Anchored = true end
					elseif d:GetAttribute("VW_Frozen") then
						d:SetAttribute("VW_Frozen", nil)
						d.Anchored = false
						d.AssemblyLinearVelocity = Vector3.zero
						d.AssemblyAngularVelocity = Vector3.zero
					end
				end
			end
		end
		function Travel.settleFreeze(vehicle)
			for _, d in ipairs(vehicle:GetDescendants()) do
				if d:IsA("BasePart") and not d.Anchored then
					d.AssemblyLinearVelocity = Vector3.zero
					d.AssemblyAngularVelocity = Vector3.zero
				end
			end
			task.wait(0.15)
			Travel.freezeVehicle(vehicle, true)
		end
		-- a free spot on a green parking strip, as close as possible to 'want': the
		-- ground right there has to be the strip's own road level (not a parked car's
		-- roof, a bench or a lamp base) and a scooter-sized box there has to be clear
		-- of anything solid. Checks every 2 studs outwards from 'want'. Returns the
		-- point on the strip (road level) and the strip's direction, or nil when full.
		function Travel.clearOnStrip(strip, want: Vector3, vehicle)
			local cf, size = strip.CFrame, strip.Size
			local longX = size.X >= size.Z
			local along = longX and cf.RightVector or cf.LookVector
			along = Vector3.new(along.X, 0, along.Z).Unit
			local half = (longX and size.X or size.Z) / 2
			local top = strip.Position.Y + size.Y / 2
			local center = Vector3.new(strip.Position.X, top, strip.Position.Z)
			local ok, _, vsize = pcall(vehicle.GetBoundingBox, vehicle)
			if not ok then vsize = Vector3.new(3, 4, 6) end
			local boxSize = Vector3.new(math.min(vsize.X, vsize.Z) - 0.4, vsize.Y - 0.6, math.max(vsize.X, vsize.Z) - 0.4)
			local ignore = { vehicle, strip.Parent }
			for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ignore, pl.Character) end end
			local ray = RaycastParams.new()
			ray.FilterType = Enum.RaycastFilterType.Exclude
			ray.FilterDescendantsInstances = ignore
			ray.RespectCanCollide = true
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances = ignore
			overlap.RespectCanCollide = true
			local margin = math.max(1, boxSize.Z / 2)
			local t0 = math.clamp((want - center):Dot(along), -half + margin, math.max(-half + margin, half - margin))
			for k = 0, math.ceil(half) do
				for _, sign in ipairs(k == 0 and { 1 } or { 1, -1 }) do
					local t = t0 + sign * k * 2
					if t >= -half + margin - 0.01 and t <= half - margin + 0.01 then
						local p = center + along * t
						local hit = workspace:Raycast(p + Vector3.new(0, 8, 0), Vector3.new(0, -14, 0), ray)
						if hit and math.abs(hit.Position.Y - top) < 1.2 then
							local ground = Vector3.new(p.X, hit.Position.Y, p.Z)
							local boxCF = CFrame.lookAt(ground + Vector3.new(0, boxSize.Y / 2 + 0.5, 0), ground + Vector3.new(0, boxSize.Y / 2 + 0.5, 0) + along)
							if #workspace:GetPartBoundsInBox(boxCF, boxSize, overlap) == 0 then return ground, along end
						end
					end
				end
			end
			return nil
		end
		-- how high a vehicle's pivot sits above its wheels (from its own bounding box,
		-- so it is right wherever the vehicle is, even in the air)
		function Travel.vehicleLift(vehicle): number
			local ok, cf, size = pcall(vehicle.GetBoundingBox, vehicle)
			if not ok then return 2.6 end
			local bottom = cf.Position.Y - size.Y / 2
			return math.clamp(vehicle:GetPivot().Position.Y - bottom, 0.5, 6)
		end
		-- your scooter anywhere on the map (its seat may not be loaded while it is far
		-- away, so it is also found by the Owner / CarType attributes the game sets)
		local function anyScooter()
			local v = findMyScooter()
			if v then return v end
			local folder = vehiclesFolder()
			if folder then
				for _, x in ipairs(folder:GetChildren()) do
					if x:GetAttribute("Owner") == LP.Name and x:GetAttribute("CarType") == "Scooter" then return x end
				end
			end
			return nil
		end
		-- pull your (already rented) scooter over to stand beside you, facing your way.
		-- Steps out from under any roof first so it never lands inside a building.
		local function bringScooter(vehicle, cancelled): boolean
			local Nav = Library.Nav
			local _, _, hrp = refs()
			if not hrp then return false end
			local feet = hrp.Position - Vector3.new(0, standHeight(), 0)
			if not Nav.openSky(feet) then
				local out = Nav.findOpen(feet, "walk")
				if out and #out > 0 then Travel.walkTo(out[#out], cancelled) end
				_, _, hrp = refs()
				if not hrp then return false end
			end
			Travel.freezeVehicle(vehicle, false)
			local lift = Travel.vehicleLift(vehicle)
			local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
			look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
			local side = hrp.CFrame.RightVector
			side = Vector3.new(side.X, 0, side.Z).Unit
			local spot = hrp.Position + side * 4
			local floor = Nav.floor(spot + Vector3.new(0, 2, 0)) or (spot - Vector3.new(0, standHeight(), 0))
			local at = floor + Vector3.new(0, lift, 0)
			vehicle:PivotTo(CFrame.lookAt(at, at + look))
			Travel.settleFreeze(vehicle)                   -- held still beside you
			return (vehicle:GetPivot().Position - at).Magnitude < 6
		end
		-- get on your scooter: one you already have is brought to you; with none, walk
		-- to the nearest rental and rent one (toScooter). Sits you with the scooter's
		-- own seat prompt and waits until the server has seated you.
		function Travel.getOnScooter(cancelled)
			cancelled = cancelled or function() return false end
			local seat, model = Travel.myScooterSeat(nil)
			if seat then return model end
			-- a scooter you can still sit on: its seat and seat prompt are there (a wrecked
			-- one, e.g. sunk in the water, keeps its model but loses its DriveSeat)
			local function usable(v)
				local seat = v and v:WaitForChild("DriveSeat", 3)
				return seat ~= nil and seat:FindFirstChild("Interact") ~= nil
			end
			local vehicle = anyScooter()
			if vehicle then
				if not bringScooter(vehicle, cancelled) or not usable(vehicle) then
					vehicle = nil                                   -- wrecked or not usable: rent a new one
					Library.Notify("Your scooter is wrecked: renting a new one")
				else
					vehicle = findMyScooter() or vehicle            -- its seat is loaded now
				end
			end
			if not vehicle then
				local why
				vehicle, why = Travel.toScooter(cancelled)
				if not vehicle then return nil, why end
			end
			if cancelled() then return nil end
			local driveSeat = vehicle:WaitForChild("DriveSeat", 3)
			local interact = driveSeat and driveSeat:FindFirstChild("Interact")
			if not interact then return nil, "your scooter has no seat prompt" end
			local _, hum = refs()
			local t = os.clock()
			while hum and not hum.SeatPart and os.clock() - t < SEAT_TIMEOUT + 1 do
				if cancelled() then return nil end
				pcall(fireproximityprompt, interact)
				task.wait(0.2)
			end
			Travel.freezeVehicle(vehicle, false)           -- only held still while you got on
			if not (hum and hum.SeatPart) then return nil, "could not sit on the scooter" end
			return vehicle
		end

		-- Scooter teleport. HOME is where the scooter waits between trips: the point in
		-- the middle of all 5 shops (every shop within ~580 studs of it). The scooter is
		-- left on the game's parking spot nearest to it (Map.ParkingSpots: the green curb
		-- strips, "Park" parts) so the game does not delete it.
		Travel.HOME = Vector3.new(865, 49.1, 105)
		-- the farthest a parking strip can be from you: further out your game unloads the
		-- scooter before its move reaches the server (700 worked, 1370 did not)
		Travel.PARK_RANGE = 700
		-- CFrame for a vehicle parked on a parking spot near 'near': the rank-th closest
		-- (1 = nearest; fewer spots than that = the farthest there is), centred on the
		-- strip, facing along it, 'lift' above it (the vehicle's pivot height)
		function Travel.parkingCFrame(near: Vector3, lift: number, rank: number?)
			local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ParkingSpots")
			if not folder then return nil end
			local spots = {}
			for _, p in ipairs(folder:GetChildren()) do
				if p:IsA("BasePart") then table.insert(spots, { part = p, d = (p.Position - near).Magnitude }) end
			end
			if #spots == 0 then return nil end
			table.sort(spots, function(a, b) return a.d < b.d end)
			local best = spots[math.min(rank or 1, #spots)].part
			local cf = best.CFrame
			local along = best.Size.X >= best.Size.Z and cf.RightVector or cf.LookVector
			along = Vector3.new(along.X, 0, along.Z).Unit
			local top = best.Position + Vector3.new(0, best.Size.Y / 2, 0)
			local at = top + Vector3.new(0, lift, 0)
			return CFrame.lookAt(at, at + along), best
		end
		-- where to park: a free spot (clearOnStrip) on the rank-th closest green strip to
		-- 'near'; when that strip is full, the next closest ones are tried
		-- every green strip ever seen (they only exist on your client while their area
		-- is loaded, e.g. none are loaded out at the oil rig), remembered with where it
		-- is, which way it runs and how long it is; saved to a file. The strip by the
		-- middle of the shops (checked in game) is always known.
		local STRIP_FILE = "VisionWare_parking.json"
		local strips = {}                                   -- key -> { x, y, z, ax, az, half }
		local function stripKey(p: Vector3) return math.floor(p.X / 4 + 0.5) .. "," .. math.floor(p.Z / 4 + 0.5) end
		local function stripRecord(part)
			local cf, size = part.CFrame, part.Size
			local longX = size.X >= size.Z
			local along = longX and cf.RightVector or cf.LookVector
			along = Vector3.new(along.X, 0, along.Z).Unit
			local top = part.Position.Y + size.Y / 2
			return { part.Position.X, top, part.Position.Z, along.X, along.Z, (longX and size.X or size.Z) / 2 }
		end
		strips[stripKey(Vector3.new(866.65, 0, 83.06))] = { 866.65, 49.79, 83.06, 0, 1, 67.2 }
		pcall(function()
			if not (isfile and isfile(STRIP_FILE)) then return end
			for k, r in pairs(HttpService:JSONDecode(readfile(STRIP_FILE))) do strips[k] = r end
		end)
		local function learnStrips()
			local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ParkingSpots")
			if not folder then return end
			local added = false
			for _, p in ipairs(folder:GetChildren()) do
				if p:IsA("BasePart") then
					local k = stripKey(p.Position)
					if not strips[k] then added = true end
					strips[k] = stripRecord(p)
				end
			end
			if added then pcall(function() writefile(STRIP_FILE, HttpService:JSONEncode(strips)) end) end
		end
		task.defer(learnStrips)
		do
			local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ParkingSpots")
			if folder then RootMaid:Add(folder.ChildAdded:Connect(function() task.defer(learnStrips) end)) end
		end
		-- the loaded strip part for a remembered strip, if its area is loaded
		local function loadedStrip(r)
			local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ParkingSpots")
			if not folder then return nil end
			for _, p in ipairs(folder:GetChildren()) do
				if p:IsA("BasePart") and math.abs(p.Position.X - r[1]) < 1 and math.abs(p.Position.Z - r[3]) < 1 then return p end
			end
			return nil
		end
		-- where to park: the 3rd closest strip to 'near' (the closest one when fewer than
		-- 3 are within 300 studs, e.g. at the oil rig), on a free spot (clearOnStrip) when
		-- its area is loaded, else its middle; when a strip is full the next ones are
		-- tried. Returns the CFrame and whether the strip is loaded on your side.
		function Travel.parkSpot(near: Vector3, rank: number, vehicle, lift: number)
			learnStrips()
			local list = {}
			for _, r in pairs(strips) do
				table.insert(list, { r = r, d = (Vector3.new(r[1], r[2], r[3]) - near).Magnitude })
			end
			if #list == 0 then return nil end
			table.sort(list, function(a, b) return a.d < b.d end)
			local nearby = 0
			for _, e in ipairs(list) do if e.d <= 300 then nearby = nearby + 1 end end
			if nearby < rank then rank = 1 end
			for i = math.min(rank, #list), math.min(rank + 6, #list) do
				local r = list[i].r
				local part = loadedStrip(r)
				local along = Vector3.new(r[4], 0, r[5])
				if part then
					local free, dir = Travel.clearOnStrip(part, part.Position, vehicle)
					if free then
						local at = free + Vector3.new(0, lift, 0)
						return CFrame.lookAt(at, at + dir), true
					end
				else
					local at = Vector3.new(r[1], r[2], r[3]) + Vector3.new(0, lift, 0)
					return CFrame.lookAt(at, at + along), false
				end
			end
			return nil
		end
		-- 1. you have to be sitting on your own scooter, the server has to have seated
		--    you, and no part of the scooter may be anchored;
		-- 2. the scooter (you on it) is teleported to dest;
		-- 3. once you and the scooter are both confirmed there (checked twice, so a
		--    snap-back by the game is caught), you get off at standAt;
		-- 4. the scooter is teleported away on its own to HOME and the trip only ends
		--    once it is fully there (or has gone out of range, i.e. left your area).
		-- (along: optional direction for the scooter to face at dest, e.g. along a
		-- parking strip; default: facing where you get off. strip: the green parking
		-- strip dest is on; then the nearest free spot on it is used, see clearOnStrip.
		-- face: a point to face when you are put down, e.g. the place you went to)
		function Travel.scooterTrip(vehicle, dest: Vector3, standAt: Vector3, cancelled, along: Vector3?, strip, face: Vector3?)
			cancelled = cancelled or function() return false end
			local Nav = Library.Nav
			local function vehicleParts()
				local list = {}
				for _, d in ipairs(vehicle:GetDescendants()) do if d:IsA("BasePart") then table.insert(list, d) end end
				return list
			end

			-- 1. seated on it, seat confirmed, nothing anchored (a freeze from an earlier
			--    step is undone first; anything else anchored stops the trip)
			Travel.freezeVehicle(vehicle, false)
			local ready, reason = false, "you are not on your scooter"
			local t = os.clock()
			repeat
				local _, hum = refs()
				local seat = Travel.myScooterSeat(vehicle)
				if not seat then
					reason = "you are not on your scooter"
				elseif not seat:FindFirstChild("SeatWeld") then
					reason = "the game has not seated you yet"
				else
					local anchored = false
					for _, p in ipairs(vehicleParts()) do if p.Anchored then anchored = true break end end
					if anchored then reason = "your scooter is anchored" else ready = true end
				end
				if not ready then task.wait(0.1) end
			until ready or os.clock() - t > 2 or cancelled()
			if not ready then return false, reason end
			task.wait(0.35)                                   -- let the server settle the seat
			if cancelled() then return false end

			-- 2. teleport the scooter with you on it
			local lift = Travel.vehicleLift(vehicle)
			local destFloor = nil
			if strip then                                      -- a free bit of the strip, on the road
				local free, dir = Travel.clearOnStrip(strip, dest, vehicle)
				if free then
					standAt = standAt + Vector3.new(free.X - dest.X, 0, free.Z - dest.Z)   -- get off beside it
					destFloor, along = free, dir
				end
			end
			destFloor = destFloor or Nav.floor(dest + Vector3.new(0, 3, 0)) or dest
			local look = along or Vector3.new(standAt.X - destFloor.X, 0, standAt.Z - destFloor.Z)
			look = look.Magnitude > 0.1 and look.Unit or vehicle:GetPivot().LookVector
			local destCF = CFrame.lookAt(destFloor + Vector3.new(0, lift, 0), destFloor + Vector3.new(0, lift, 0) + Vector3.new(look.X, 0, look.Z))
			vehicle:PivotTo(destCF)
			Travel.settleFreeze(vehicle)                   -- frozen there so it cannot move

			-- 3. both there together (twice, half a second apart), then get off
			local function together(): boolean
				local _, hum, hrp = refs()
				if not (hum and hrp and Travel.myScooterSeat(vehicle)) then return false end
				return (vehicle:GetPivot().Position - destCF.Position).Magnitude < 6 and (hrp.Position - destCF.Position).Magnitude < 10
			end
			local function fail(why)                          -- never leave it frozen
				if vehicle.Parent then Travel.freezeVehicle(vehicle, false) end
				return false, why
			end
			task.wait(0.15)
			if not together() then return fail("you and the scooter did not arrive together") end
			task.wait(0.3)
			if not together() then return fail("the game moved you back after the teleport") end
			if cancelled() then return fail(nil) end
			-- get off: drop the seat weld and stand up (no jump, so there is no hop before
			-- you are put on the curb); a jump only if the seat does not let go
			local c, hum, hrp = refs()
			for _, root in ipairs({ c, hum.SeatPart }) do
				for _, obj in ipairs(root:GetDescendants()) do
					if (obj:IsA("Weld") or obj:IsA("WeldConstraint")) and obj.Name == "SeatWeld" then obj:Destroy() end
				end
			end
			hum.Sit = false
			t = os.clock()
			while hum.SeatPart and os.clock() - t < SEAT_TIMEOUT do
				hum.Sit = false
				if os.clock() - t > 0.1 then hum.Jump = true end
				RunService.Heartbeat:Wait()
			end
			if hum.SeatPart then return fail("could not get off the scooter") end
			local standFloor = Nav.floor(standAt + Vector3.new(0, 3, 0)) or (standAt - Vector3.new(0, standHeight(), 0))
			local standPos = standFloor + Vector3.new(0, standHeight(), 0)
			hrp.AssemblyLinearVelocity = Vector3.zero
			local faceFlat = face and Vector3.new(face.X, standPos.Y, face.Z)
			if faceFlat and (faceFlat - standPos).Magnitude > 0.5 then
				hrp.CFrame = CFrame.lookAt(standPos, faceFlat)       -- facing the place straight away
				-- standing up from the seat can turn you again a moment later: face it once
				-- more then, turning only (never moving you) and only if you are not moving
				task.delay(0.2, function()
					local _, h2, r2 = refs()
					if not (h2 and r2) or h2.MoveDirection.Magnitude > 0.1 then return end
					local flat = Vector3.new(face.X, r2.Position.Y, face.Z)
					if (flat - r2.Position).Magnitude > 0.5 then r2.CFrame = CFrame.lookAt(r2.Position, flat) end
				end)
			else
				hrp.CFrame = CFrame.new(standPos) * hrp.CFrame.Rotation
			end

			-- 4. the scooter goes away on its own, onto the 3rd closest parking spot to you
			--    (the green curb strips, so it is not deleted; the closest one when there
			--    are not 3 near you); done once it is fully there
			local homeCF, stripLoaded = Travel.parkSpot(standFloor, 3, vehicle, lift)
			-- a strip too far from you cannot be reached: your game unloads the scooter the
			-- moment it lands out there, so the move never reaches the server and it pops
			-- back to where you got off (seen at the oil rig, strip 1370 away). Then it
			-- stays beside you and is kept alive instead (see keepAlive below).
			if not homeCF or (homeCF.Position - standFloor).Magnitude > Travel.PARK_RANGE then
				local _, _, r = refs()
				local right = r and r.CFrame.RightVector or Vector3.new(1, 0, 0)
				right = Vector3.new(right.X, 0, right.Z).Unit
				local spot = standFloor + right * 6
				local floor = Nav.floor(spot + Vector3.new(0, 3, 0)) or standFloor
				Travel.freezeVehicle(vehicle, false)
				vehicle:PivotTo(CFrame.new(floor + Vector3.new(0, lift, 0)) * vehicle:GetPivot().Rotation)
				Travel.settleFreeze(vehicle)
				task.wait(0.3)
				if vehicle.Parent then Travel.freezeVehicle(vehicle, false) end
				Travel.keepAlive = vehicle
				Library.Notify("No parking strip in reach: your scooter stays beside you and is kept alive")
				return true
			end
			Travel.keepAlive = nil
			Travel.freezeVehicle(vehicle, false)
			vehicle:PivotTo(homeCF)
			Travel.settleFreeze(vehicle)                   -- frozen on the strip so it stays put
			-- a strip whose area is not loaded on your side has no ground under it here:
			-- hold it longer so it does not drop before the game has it (checked in game)
			if not stripLoaded then task.wait(3) end
			t = os.clock()
			local settled, parked = 0, false
			while os.clock() - t < 5 and not cancelled() do
				if not vehicle.Parent or not vehicle:FindFirstChildWhichIsA("BasePart", true) then parked = true break end   -- out of range: it has left your area
				if (vehicle:GetPivot().Position - homeCF.Position).Magnitude < 8 then
					settled = settled + 1
					if settled >= 5 then parked = true break end        -- stayed there for ~0.5 s
				else
					settled = 0
				end
				task.wait(0.1)
			end
			-- frozen only during the teleport: once it is parked it is let go again
			if vehicle.Parent then Travel.freezeVehicle(vehicle, false) end
			if cancelled() then return false end
			if not parked then return false, "the scooter did not stay at home" end
			return true
		end

		-- keep alive: a scooter left beside you (no parking strip in reach) is deleted
		-- 120 s after you get off it, and sitting on it resets that. When its countdown
		-- is down to KEEP_AT seconds you sit on it for a moment and are put back exactly
		-- where you were (checked in game: the sign goes back to 120). Only while it is
		-- near you; the next trip parks it on a strip and ends this.
		do
			local KEEP_AT, KEEP_NEAR = 10, 150
			local busyKeep, lastCheck = false, 0
			-- after a refresh the sign still shows the old number for a moment, so a
			-- refresh only happens once the sign has gone back above KEEP_AT and at least
			-- REFRESH_GAP seconds after the last one (else it sits on it twice)
			local REFRESH_GAP = 20
			local lastRefresh, armed = -math.huge, true
			RootMaid:Add(RunService.Heartbeat:Connect(function()
				local now = os.clock()
				if busyKeep or now - lastCheck < 0.5 then return end
				lastCheck = now
				local vehicle = Travel.keepAlive
				if not vehicle then return end
				if not vehicle.Parent then Travel.keepAlive = nil return end
				local _, hum, hrp = refs()
				if not (hum and hrp) or hum.SeatPart then return end          -- riding it keeps it alive anyway
				if (vehicle:GetPivot().Position - hrp.Position).Magnitude > KEEP_NEAR then return end
				local sign = vehicle:FindFirstChild("Billboard")
				local lbl = sign and sign:FindFirstChildWhichIsA("TextLabel")
				local left = lbl and tonumber(tostring(lbl.Text):match("(%d+)"))
				if not left then return end
				if left > KEEP_AT then armed = true return end
				if not armed or now - lastRefresh < REFRESH_GAP then return end
				armed, lastRefresh = false, now
				busyKeep = true
				task.spawn(function()
					pcall(function()
						local back = hrp.CFrame
						if not Travel.getOnScooter() then return end
						task.wait(0.6)
						local c, h = refs()
						for _, root in ipairs({ c, h.SeatPart }) do
							if root then
								for _, o in ipairs(root:GetDescendants()) do
									if o.Name == "SeatWeld" and (o:IsA("Weld") or o:IsA("WeldConstraint")) then o:Destroy() end
								end
							end
						end
						h.Sit = false
						local t = os.clock()
						while h.SeatPart and os.clock() - t < SEAT_TIMEOUT do
							h.Sit = false
							if os.clock() - t > 0.1 then h.Jump = true end
							RunService.Heartbeat:Wait()
						end
						local _, _, r = refs()
						if r then r.AssemblyLinearVelocity = Vector3.zero r.CFrame = back end
					end)
					busyKeep = false
				end)
			end))
		end

		-- the old scooter travel was removed (to be remade): every other trip reports that,
		-- so the farms that travel stop with a clear reason instead of doing something odd
		function Travel.moveTo(dest: Vector3, opts)
			return false, "scooter travel is being remade"
		end
	end

	-- Box Job ------------------------------------------------------------------
	local function boxJobParts()
		local map = workspace:FindFirstChild("Map")
		local jobs = map and map:FindFirstChild("Jobs")
		local job = jobs and jobs:FindFirstChild("BoxJob")
		local take = job and job:FindFirstChild("Take") and job.Take:FindFirstChild("Take")
		local deliver = job and job:FindFirstChild("Deliver") and job.Deliver:FindFirstChild("Deliver")
		local takePrompt = take and take:FindFirstChild("Interact")
		local deliverPrompt = deliver and deliver:FindFirstChild("Interact")
		if takePrompt and deliverPrompt then return take, takePrompt, deliverPrompt end
		return nil
	end
	local DELIVER_POINTS = {
		Vector3.new(PICKUP_POS.X, GROUND_Y, PICKUP_POS.Z),
		Vector3.new(WP1.X, GROUND_Y, WP1.Z),
		Vector3.new(WP2.X, GROUND_Y, WP2.Z),
	}
	local RETURN_POINTS = { DELIVER_POINTS[3], DELIVER_POINTS[2], DELIVER_POINTS[1] }

	local function boxJobCycle(cancelled)
		local take, takePrompt, deliverPrompt = boxJobParts()
		if not take then return false, "Box Job not found on this map" end
		local _, _, hrp = refs()
		if not hrp then return false, "no character" end

		local flat = Vector3.new(hrp.Position.X - PICKUP_POS.X, 0, hrp.Position.Z - PICKUP_POS.Z).Magnitude
		if flat > ARRIVE_RADIUS then
			-- get on your scooter, teleport it (with you) to the pickup, get off, send the
			-- scooter home, and only start once it has fully left
			local vehicle, why = Travel.getOnScooter(cancelled)
			if not vehicle then return false, why end
			local ok, why2 = Travel.scooterTrip(vehicle, PICKUP_POS + Vector3.new(4, 0, 0), PICKUP_POS, cancelled)
			if not ok then return false, why2 end
		end
		_, _, hrp = refs()
		if not hrp or cancelled() then return false end
		hrp.CFrame = CFrame.new(PICKUP_POS.X, GROUND_Y, PICKUP_POS.Z)
		task.wait(0.5)
		hrp.CFrame = CFrame.new(PICKUP_POS.X, GROUND_Y, PICKUP_POS.Z)
		task.wait(0.3)
		pcall(fireproximityprompt, takePrompt)
		task.wait(0.5)

		if not glide(DELIVER_POINTS, GROUND_Y, cancelled) then return false end
		task.wait(0.2)
		pcall(fireproximityprompt, deliverPrompt)
		task.wait(0.3)
		-- pick up any cash dropped around the delivery spot (the payout / other drops)
		local deliverPart = deliverPrompt.Parent
		if deliverPart and deliverPart:IsA("BasePart") then
			task.wait(0.4)
			Travel.grabCash(deliverPart.Position, BOX_CASH_RADIUS, cancelled)
		end
		if not glide(RETURN_POINTS, GROUND_Y, cancelled) then return false end
		return true
	end

	-- Farm turn-taking: several farms can be on at once, but only one moves the
	-- character at a time. A farm claims the turn before it acts and releases it
	-- after. Box Job finishes its current run, then lets any farm that is waiting
	-- (Shops with a register over the minimum, an airdrop, the oil rig) go first.
	local Turn = { owner = nil, waiting = {} }
	function Turn.claim(name: string, cancelled): boolean
		Turn.waiting[name] = true
		while Turn.owner ~= nil and Turn.owner ~= name do
			if cancelled() then Turn.waiting[name] = nil return false end
			task.wait(0.2)
		end
		Turn.waiting[name] = nil
		Turn.owner = name
		return true
	end
	function Turn.release(name: string)
		if Turn.owner == name then Turn.owner = nil end
	end
	function Turn.othersWaiting(name: string): boolean
		for k in pairs(Turn.waiting) do if k ~= name then return true end end
		return false
	end
	-- run fn while holding the turn (always released, even if fn errors)
	function Turn.run(name: string, cancelled, fn, ...)
		if not Turn.claim(name, cancelled) then return false, "cancelled" end
		local results = table.pack(pcall(fn, ...))
		Turn.release(name)
		return table.unpack(results, 1, results.n)
	end
	RootMaid:Add(function() Turn.owner = nil; table.clear(Turn.waiting) end)
	Library.FarmTurn = Turn        -- the Farm Terminal labels money changes with the farm holding the turn

	local boxToken = 0
	local function boxJobWanted() return En("Farms") and Cfg.Farms["Box Job"] == true end
	local function stopBoxJob(reason: string?)
		if reason then Library.Notify("Box Job stopped: " .. reason) end
		if Cfg.Farms["Box Job"] then P("Farms").Controls["Box Job"].Set(false) end
	end
	local function runBoxJob()
		boxToken = boxToken + 1
		local token = boxToken
		if not boxJobWanted() then return end
		if type(fireproximityprompt) ~= "function" then stopBoxJob("your executor has no fireproximityprompt") return end
		local function cancelled()
			return token ~= boxToken or not boxJobWanted()
		end
		task.spawn(function()
			Library.Notify("Box Job started")
			local fails, loops = 0, 0
			while not cancelled() do
				if not refs() then
					if not settings()["Auto Respawn"] then stopBoxJob("you died (Auto Respawn is off)") return end
					local deadline = os.clock() + RESPAWN_WAIT
					while not refs() and os.clock() < deadline and not cancelled() do task.wait(0.5) end
					if cancelled() then return end
					if not refs() then stopBoxJob("did not respawn") return end
					task.wait(1)
				end
				-- another farm is waiting for its turn (e.g. Shops found a register over
				-- the minimum): the last run is finished, so step aside until it is done
				while (Turn.othersWaiting("box") or (Turn.owner ~= nil and Turn.owner ~= "box")) and not cancelled() do
					task.wait(0.3)
				end
				if cancelled() then return end
				local ok, res, why = Turn.run("box", cancelled, boxJobCycle, cancelled)
				if cancelled() then return end
				if ok and res then
					fails, loops = 0, loops + 1
				elseif not refs() then
					-- died during the run: not a failure, it starts again after respawning
				else
					fails = fails + 1
					Log.warn("Box Job cycle failed:", ok and why or res)
					if fails >= MAX_FAILS then stopBoxJob(tostring((ok and why) or "it kept failing")) return end
					task.wait(2)
				end
				task.wait(0.2)
			end
		end)
	end
	P("Farms"):On("Box Job", function() runBoxJob() end)
	P("Farms"):On("Enabled", function() runBoxJob() end)
	RootMaid:Add(function() boxToken = boxToken + 1 end)

	do   -- own scope: keeps this section under Luau's 200-local limit
	-- Oil Rig -------------------------------------------------------------------
		-- step 1: scooter to the rig's top deck (skipped when you are already on the
		-- rig). step 2: tween along the pump route on the top deck and fire every oil
		-- prompt in reach at each point, end back at the arrival spot and stop (toggle
		-- turns off).
		local OIL_RIG_ARRIVE = Vector3.new(-298, 82, -1678)
		local OIL_DECK_Y     = 82
		local OIL_RIG_MIN    = Vector3.new(-395, 25, -1745)   -- the rig's bounds, with a margin
		local OIL_RIG_MAX    = Vector3.new(-200, 150, -1620)
		-- the route, in order; it ends back at the arrival spot
		local OIL_ROUTE = {
			Vector3.new(-321, 82, -1663), Vector3.new(-275, 82, -1664), Vector3.new(-284, 82, -1664),
			Vector3.new(-285, 82, -1675), Vector3.new(-273, 82, -1691), Vector3.new(-272, 82, -1729),
			Vector3.new(-286, 82, -1720), Vector3.new(-286, 82, -1712), Vector3.new(-317, 82, -1713),
			Vector3.new(-317, 82, -1721), Vector3.new(-316, 82, -1714), Vector3.new(-308, 82, -1714),
			OIL_RIG_ARRIVE,
		}
		local OIL_PROMPT_MARGIN = 0.5
		local function onOilRig(pos: Vector3): boolean
			return pos.X >= OIL_RIG_MIN.X and pos.X <= OIL_RIG_MAX.X and pos.Y >= OIL_RIG_MIN.Y and pos.Y <= OIL_RIG_MAX.Y
				and pos.Z >= OIL_RIG_MIN.Z and pos.Z <= OIL_RIG_MAX.Z
		end
		-- fire every OilJob prompt within reach; hold prompts are fired with the hold
		-- skipped, and a prompt that shows a price gets that cash withdrawn first
		local function fireOilPromptsInReach(): number
			local _, _, hrp = refs()
			local job = workspace:FindFirstChild("OilJob")
			if not (hrp and job) then return 0 end
			local fired = 0
			for _, pr in ipairs(job:GetDescendants()) do
				if pr:IsA("ProximityPrompt") and pr.Enabled and pr.Parent:IsA("BasePart")
					and (pr.Parent.Position - hrp.Position).Magnitude <= pr.MaxActivationDistance + OIL_PROMPT_MARGIN then
					local price = tonumber(((pr.ActionText or "") .. " " .. (pr.ObjectText or "")):gsub(",", ""):match("%$%s*(%d+)") or "")
					if price then Travel.ensureCash(price) end
					local hold = pr.HoldDuration
					pr.HoldDuration = 0
					pcall(fireproximityprompt, pr)
					pr.HoldDuration = hold
					fired = fired + 1
					task.wait(0.3)
				end
			end
			return fired
		end
		-- each leg runs from the previous route point to the next one, so the path is
		-- exactly the route's coordinates (only the first leg starts where you stand)
		local function oilLap(cancelled): boolean
			local _, _, hrp = refs()
			if not hrp then return false end
			local from = Vector3.new(hrp.Position.X, OIL_DECK_Y, hrp.Position.Z)
			for _, point in ipairs(OIL_ROUTE) do
				if cancelled() then return false end
				if not glide({ from, point }, OIL_DECK_Y, cancelled) then return false end
				_, _, hrp = refs()
				if not hrp then return false end
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.CFrame = CFrame.new(point)
				fireOilPromptsInReach()
				from = point
			end
			return true
		end
		local oilToken = 0
		local function oilWanted() return En("Farms") and Cfg.Farms["Oil Rig"] == true end
		local function stopOil(reason: string?)
			if reason then Library.Notify("Oil Rig stopped: " .. reason) end
			if Cfg.Farms["Oil Rig"] then P("Farms").Controls["Oil Rig"].Set(false) end
		end
		local function runOil()
			oilToken = oilToken + 1
			local token = oilToken
			if not oilWanted() then return end
			if type(fireproximityprompt) ~= "function" then stopOil("your executor has no fireproximityprompt") return end
			local function cancelled() return token ~= oilToken or not oilWanted() end
			task.spawn(function()
				Library.Notify("Oil Rig started")
				local fails = 0
				while not cancelled() do
					if not refs() then
						if not settings()["Auto Respawn"] then stopOil("you died (Auto Respawn is off)") return end
						local deadline = os.clock() + RESPAWN_WAIT
						while not refs() and os.clock() < deadline and not cancelled() do task.wait(0.5) end
						if cancelled() then return end
						if not refs() then stopOil("did not respawn") return end
						task.wait(1)
					end
					-- one attempt while holding the turn (other farms wait; the turn is always
					-- handed back): "done", or "fail" + reason
					local okRun, status, why = Turn.run("oil", cancelled, function()
						local _, _, hrp = refs()
						local onRig = hrp ~= nil and onOilRig(hrp.Position)
						if not onRig then
							-- first trip: scooter to the rig
							local ok, res, whyTravel = pcall(Travel.moveTo, OIL_RIG_ARRIVE, { standAt = OIL_RIG_ARRIVE, groundY = OIL_RIG_ARRIVE.Y, cancelled = cancelled })
							if not (ok and res == true) then return "fail", tostring((ok and whyTravel) or res or "could not reach the oil rig") end
						end
						local ok, res = pcall(oilLap, cancelled)
						if ok and res then return "done" end
						return "fail", tostring(res or "lap failed")
					end)
					if cancelled() then return end
					if okRun and status == "done" then
						-- one pass of the route, then stop at the last point
						Library.Notify("Oil Rig: route done")
						stopOil()
						return
					elseif refs() then
						fails = fails + 1
						Log.warn("Oil Rig failed:", okRun and why or status)
						if fails >= MAX_FAILS then stopOil(tostring((okRun and why) or "it kept failing")) return end
						task.wait(2)
					end
					task.wait(0.2)
				end
			end)
		end
		P("Farms"):On("Oil Rig", function() runOil() end)
		P("Farms"):On("Enabled", function() runOil() end)
		RootMaid:Add(function() oilToken = oilToken + 1 end)

	
	end

	do   -- own scope: keeps this section under Luau's 200-local limit
	-- Airdrops ------------------------------------------------------------------
		-- The game announces a drop with a notification (Remotes.Notify: text, time).
		-- When the Airdrops farm is on and a notification is about an airdrop: get on
		-- your scooter, hop it (you on it) WATCH_HEIGHT above the drop spot named in
		-- the message (every spot in turn when none is named) and hold it there so the
		-- area loads, wait for the crate to land (it stops falling), then the scooter
		-- trip puts you on top of it, the crate is opened and the scooter parks.
		-- A drop already lying at a loaded spot is picked up the same way.
		-- Airdrop notifications are logged to VisionWare_airdrop_log.txt so the exact
		-- wording can be checked.
		(function()   -- own function: its own 200-local budget
			local SPOTS = {   -- workspace.AirdropSpawns.<name>.AirdropSpawn, measured in game
				{ name = "The Ice", pos = Vector3.new(187, 53, 210) },
				{ name = "Warehouse", pos = Vector3.new(-139, 70, 472) },
				{ name = "Uphill", pos = Vector3.new(887, 70, 598) },
				{ name = "ParkingStation", pos = Vector3.new(-115, 114, -39) },
				{ name = "Court", pos = Vector3.new(446.4, 52.6, -702.2) },
				{ name = "Pier", pos = Vector3.new(811.1, 52.7, -996.6) },
			}
			local RADIUS       = 90     -- a drop lands within this of its spot
			local WATCH_HEIGHT = 60     -- hover this high above the spot while waiting
			local FIND_TIME    = 90     -- give up if no crate shows up / lands within this
			local OPEN_TIME    = 20     -- keep trying to open it for this long
			local STAY_MAX     = 30     -- after opening, stay inside it at most this long (moving ends it sooner)
			local POLL         = 5      -- check the loaded spots for a lying drop this often
			local LOG_FILE     = "VisionWare_airdrop_log.txt"
			local airToken = 0
			local incoming = nil        -- { spot = SPOTS entry or nil, t = os.clock(), text }
			local newPrompts = {}       -- prompts that appeared since the last announcement

			local function airWanted() return En("Farms") and Cfg.Farms["Airdrops"] == true end
			local function stopAir(reason: string?)
				if reason then Library.Notify("Airdrops stopped: " .. reason) end
				if Cfg.Farms["Airdrops"] then P("Farms").Controls["Airdrops"].Set(false) end
			end
			local function logLine(line: string)
				pcall(function()
					local old = (isfile and isfile(LOG_FILE)) and readfile(LOG_FILE) or ""
					if #old > 20000 then old = old:sub(-10000) end
					writefile(LOG_FILE, old .. os.date("%H:%M:%S ") .. line .. "\n")
				end)
			end
			local function spotPos(spot): Vector3
				local folder = workspace:FindFirstChild("AirdropSpawns")
				local m = folder and folder:FindFirstChild(spot.name)
				local p = m and m:FindFirstChild("AirdropSpawn")
				return p and p.Position or spot.pos
			end
			local function squash(s: string): string return (s:lower():gsub("[^%a]", "")) end
			local function spotFromText(text: string)
				local t = squash(text)
				for _, s in ipairs(SPOTS) do if t:find(squash(s.name), 1, true) then return s end end
				if t:find("parking", 1, true) then return SPOTS[4] end
				if t:find("ice", 1, true) then return SPOTS[1] end
				return nil
			end
			local function isAirdropText(text: string): boolean
				local t = text:lower()
				if t:find("airdrop", 1, true) or t:find("air drop", 1, true) or t:find("supply", 1, true) then return true end
				return spotFromText(text) ~= nil and (t:find("drop", 1, true) or t:find("crate", 1, true) or t:find("falling", 1, true) or t:find("land", 1, true)) ~= nil
			end

			-- the announcement
			do
				local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
				local notify = remotes and remotes:FindFirstChild("Notify")
				if notify and notify:IsA("RemoteEvent") then
					RootMaid:Add(notify.OnClientEvent:Connect(function(text)
						if type(text) ~= "string" or not isAirdropText(text) then return end
						local spot = spotFromText(text)
						logLine(("notification: %q -> spot %s"):format(text, spot and spot.name or "?"))
						table.clear(newPrompts)
						incoming = { spot = spot, t = os.clock(), text = text }
						if airWanted() then Library.Notify("Airdrop announced" .. (spot and (" at " .. spot.name) or "") .. ": going") end
					end))
				end
				-- prompts that show up after an announcement are the best drop candidates
				RootMaid:Add(workspace.DescendantAdded:Connect(function(d)
					if incoming and d:IsA("ProximityPrompt") then newPrompts[d] = true end
				end))
			end

			local function promptPart(pr)
				local parent = pr.Parent
				if parent and parent:IsA("Attachment") then parent = parent.Parent end
				return (parent and parent:IsA("BasePart")) and parent or nil
			end
			-- the crate: the game puts it in the spot itself (AirdropSpawns.<spot>.AirDrop, its
			-- prompt says "Airdrop"; seen in game), so only a prompt labelled Airdrop counts.
			-- (Any unknown prompt used to count and the Warehouse building's door was taken
			-- for a drop.) New prompts near the spot are checked too, in case it is put elsewhere.
			local function isAirdropPrompt(pr): boolean
				return pr:IsA("ProximityPrompt") and tostring(pr.ObjectText):lower():find("airdrop", 1, true) ~= nil
			end
			local function findDrop(spot)
				local folder = workspace:FindFirstChild("AirdropSpawns")
				local home = folder and folder:FindFirstChild(spot.name)
				if home then
					for _, d in ipairs(home:GetDescendants()) do
						if isAirdropPrompt(d) then return d end
					end
				end
				local center = spotPos(spot)
				for pr in pairs(newPrompts) do
					local part = pr.Parent and promptPart(pr)
					if part and isAirdropPrompt(pr) and Vector3.new(part.Position.X - center.X, 0, part.Position.Z - center.Z).Magnitude <= RADIUS then return pr end
				end
				return nil
			end
			-- hold the scooter (you on it) above a point so the area loads
			local function hover(vehicle, at: Vector3)
				Travel.freezeVehicle(vehicle, false)
				vehicle:PivotTo(CFrame.new(at) * vehicle:GetPivot().Rotation)
				Travel.settleFreeze(vehicle)
			end
			local function firePrompt(pr, useHold: boolean)
				if useHold and pr.HoldDuration > 0 then
					pr:InputHoldBegin()
					task.wait(pr.HoldDuration + 0.2)
					pr:InputHoldEnd()
					return
				end
				local hold = pr.HoldDuration
				pr.HoldDuration = 0
				pcall(fireproximityprompt, pr)
				pr.HoldDuration = hold
			end

			local function handleDrop(job, cancelled)
				local vehicle, why = Travel.getOnScooter(cancelled)
				if not vehicle then return false, why or "could not get on your scooter" end
				-- where to look: the named spot, else every spot, nearest first
				local spots = {}
				if job.spot then
					spots = { job.spot }
				else
					local _, _, hrp = refs()
					for _, s in ipairs(SPOTS) do table.insert(spots, s) end
					if hrp then
						table.sort(spots, function(a, b) return (spotPos(a) - hrp.Position).Magnitude < (spotPos(b) - hrp.Position).Magnitude end)
					end
				end
				local deadline = os.clock() + FIND_TIME
				local pr, spot = nil, nil
				repeat
					for _, s in ipairs(spots) do
						hover(vehicle, spotPos(s) + Vector3.new(0, WATCH_HEIGHT, 0))
						local t = os.clock()
						repeat
							pr = findDrop(s)
							if pr then spot = s break end
							task.wait(0.4)
						until os.clock() - t > (job.spot and 6 or 3) or cancelled()
						if pr or cancelled() then break end
					end
				until pr or os.clock() > deadline or cancelled()
				if not pr then
					Travel.freezeVehicle(vehicle, false)
					return false, cancelled() and "cancelled" or "no crate showed up"
				end
				logLine(("drop found at %s: %s (%s / %s)"):format(spot.name, pr:GetFullName(), pr.ObjectText, pr.ActionText))
				-- wait for it to land: its height stops changing for about a second
				local part = promptPart(pr)
				local lastY, still = part and part.Position.Y, 0
				while part and part.Parent and still < 4 and os.clock() < deadline and not cancelled() do
					task.wait(0.25)
					local y = part.Position.Y
					if math.abs(y - lastY) < 0.15 then still = still + 1 else still = 0 end
					lastY = y
				end
				if cancelled() then Travel.freezeVehicle(vehicle, false) return false, "cancelled" end
				if not (part and part.Parent) then Travel.freezeVehicle(vehicle, false) return false, "the crate disappeared" end
				-- on top of it: the scooter lands beside it, you get off on its top
				local holder = pr:FindFirstAncestorOfClass("Model") or part
				local cf, size
				if holder:IsA("Model") then cf, size = holder:GetBoundingBox() else cf, size = part.CFrame, part.Size end
				local center = cf.Position
				local top = center + Vector3.new(0, size.Y / 2, 0)
				local _, _, hrp = refs()
				local away = hrp and Vector3.new(hrp.Position.X - center.X, 0, hrp.Position.Z - center.Z) or Vector3.new(1, 0, 0)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
				local beside = Vector3.new(center.X, center.Y - size.Y / 2, center.Z) + away * (math.max(size.X, size.Z) / 2 + 5)
				local ok, why2 = Travel.scooterTrip(vehicle, beside, top, cancelled, nil, nil, center)
				if not ok then return false, why2 or "could not get to the crate" end
				-- inside it: stand in the middle of the crate on its floor and be held there
				-- (anchored on your side once the game has you there, so its walls cannot
				-- push you out) while it is opened, and after that until you move yourself
				local _, hum, hrp = refs()
				if not (hum and hrp) then return false, "no character" end
				local inside = CFrame.new(center.X, center.Y - size.Y / 2 + standHeight(), center.Z) * (hrp.CFrame - hrp.CFrame.Position)
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.CFrame = inside
				task.wait(0.15)                                       -- let the game register you inside
				hrp.CFrame = inside
				hrp.Anchored = true
				local function release()
					local _, _, r = refs()
					if r then r.Anchored = false r.AssemblyLinearVelocity = Vector3.zero end
				end
				-- open it (hold skipped; every third try a real hold)
				local stop, tries = os.clock() + OPEN_TIME, 0
				while pr.Parent and pr.Enabled and os.clock() < stop and not cancelled() and refs() do
					tries = tries + 1
					firePrompt(pr, tries % 3 == 0)
					task.wait(0.5)
				end
				if pr.Parent and pr.Enabled and not cancelled() then release() return false, "the crate would not open" end
				logLine("drop opened")
				-- stay inside until you move (any movement key), the crate goes, or STAY_MAX
				local stayUntil = os.clock() + STAY_MAX
				while os.clock() < stayUntil and not cancelled() do
					local _, h2 = refs()
					if not h2 or h2.MoveDirection.Magnitude > 0.1 then break end
					if not (part and part.Parent) then break end
					task.wait(0.1)
				end
				release()
				return true
			end

			local function runAir()
				airToken = airToken + 1
				local token = airToken
				if not airWanted() then return end
				if type(fireproximityprompt) ~= "function" then stopAir("your executor has no fireproximityprompt") return end
				local function cancelled() return token ~= airToken or not airWanted() end
				task.spawn(function()
					Library.Notify("Airdrops: waiting for an airdrop announcement")
					local fails, lastPoll = 0, 0
					while not cancelled() do
						if not refs() then
							if not settings()["Auto Respawn"] then stopAir("you died (Auto Respawn is off)") return end
							local deadline = os.clock() + RESPAWN_WAIT
							while not refs() and os.clock() < deadline and not cancelled() do task.wait(0.5) end
							if cancelled() then return end
							if not refs() then stopAir("did not respawn") return end
							task.wait(1)
						end
						local job = incoming
						if job and os.clock() - job.t > FIND_TIME then incoming, job = nil, nil end   -- too old: it has landed and been taken, or never came
						-- nothing announced: every POLL seconds, a drop already lying at a loaded spot
						if not job and os.clock() - lastPoll >= POLL then
							lastPoll = os.clock()
							for _, s in ipairs(SPOTS) do
								local folder = workspace:FindFirstChild("AirdropSpawns")
								if folder and folder:FindFirstChild(s.name) and folder[s.name]:FindFirstChild("AirdropSpawn") and findDrop(s) then
									job = { spot = s, t = os.clock(), text = "(found lying at " .. s.name .. ")" }
									break
								end
							end
						end
						if job then
							incoming = nil
							local ok, res, why = Turn.run("air", cancelled, handleDrop, job, cancelled)
							table.clear(newPrompts)
							do   -- never leave you held inside the crate (e.g. after an error)
								local _, _, r = refs()
								if r and r.Anchored then r.Anchored = false end
							end
							if cancelled() then return end
							if ok and res then
								fails = 0
								Library.Notify("Airdrops: crate opened")
							else
								fails = fails + 1
								Log.warn("Airdrops:", ok and why or res)
								logLine("failed: " .. tostring((ok and why) or res))
								Library.Notify("Airdrops: " .. tostring((ok and why) or res))
								if fails >= MAX_FAILS then stopAir(tostring((ok and why) or "it kept failing")) return end
							end
						end
						task.wait(0.5)
					end
				end)
			end
			P("Farms"):On("Airdrops", function() runAir() end)
			P("Farms"):On("Enabled", function() runAir() end)
			RootMaid:Add(function() airToken = airToken + 1 end)
			Library.Airdrops = {   -- for testing: pretend an announcement came in
				Announce = function(text: string)
					local spot = spotFromText(text)
					table.clear(newPrompts)
					incoming = { spot = spot, t = os.clock(), text = text }
					return spot and spot.name
				end,
				FindDrop = function(name: string)
					for _, s in ipairs(SPOTS) do if s.name == name then return findDrop(s) end end
				end,
			}
		end)()

	
	end

	do   -- own scope: keeps this section under Luau's 200-local limit
	-- Shops (store robberies) ---------------------------------------------------
		-- Measured: every store register is a Part in workspace.Map.Registers with an
		-- Amount (cash in the till), a Cooldown flag and a ~12-stud "Proximity" zone the
		-- server watches (touch). Walking into it WITHOUT a gun gives "Gun needed to rob
		-- this Store!", so: have a gun (or buy a Ruger, never from the safe), scooter to the
		-- nearest register with at least Min Register Cash that is not on cooldown, get
		-- off just outside the zone (the scooter is parked on the nearest road outside),
		-- equip the gun, walk into the zone and stay until the till is emptied.
		local SHOP_ROB_TIME    = 40     -- give up on a register after this long
		local SHOP_IDLE_DONE   = 3      -- till stopped dropping this long after dropping = done
		local SHOP_WAIT_EMPTY  = 10     -- no register worth robbing: check again after this
		local SHOP_GUN_WAIT    = 4
		local SHOP_CASH_RADIUS = 15     -- grab dropped cash this close to the register
		local CollectionService = game:GetService("CollectionService")
		local shopToken = 0
		local function shopWanted() return En("Farms") and Cfg.Farms["Shops"] == true end
		local function stopShop(reason: string?)
			if reason then Library.Notify("Shops stopped: " .. reason) end
			if Cfg.Farms["Shops"] then P("Farms").Controls["Shops"].Set(false) end
		end
		local function findGun()
			for _, container in ipairs({ LP.Character, LP.Backpack }) do
				if container then
					for _, t in ipairs(container:GetChildren()) do
						if t:IsA("Tool") and CollectionService:HasTag(t, "Gun") then return t end
					end
				end
			end
			return nil
		end
		-- no gun in your hand / backpack: buy a Ruger from the gun store (Auto Buy Gun),
		-- at most ONCE per run of the farm. Guns in your safe are left alone on purpose.
		local boughtThisRun = false
		local function ensureGun()
			if findGun() then return true end
			if boughtThisRun then return false, "the Ruger it bought is gone (only buys one per run)" end
			local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			if settings()["Auto Buy Gun"] ~= true then return false, "you have no gun (turn on Auto Buy Gun)" end
			local ruger = GUN_STORE[1]
			local gunBuy = remotes and remotes:FindFirstChild("GunBuy")
			if not gunBuy then return false, "gun store remote not found" end
			local canPay, why = Travel.ensureCash(ruger.Price)
			if not canPay then return false, why end
			boughtThisRun = true
			pcall(gunBuy.FireServer, gunBuy, ruger.Name, ruger.Price)
			local t = os.clock() + SHOP_GUN_WAIT
			repeat task.wait(0.2) until findGun() or os.clock() > t
			if findGun() then Library.Notify("Shops: bought a Ruger") return true end
			return false, "could not buy a Ruger"
		end
		-- store memory: registers only exist on your client while their area is loaded,
		-- so every register ever seen is remembered (saved to a file). Checking far ones
		-- in person (scooter hops) was removed with the scooter travel, to be remade.
		-- (its own function, so it has its own 200-local budget)
		local Stores = (function()
			local REG_FILE       = "VisionWare_registers.json"
			local SCOUT_EVERY    = 45       -- seconds between checks of the far stores
			local knownRegs = { list = {}, discovered = false, lastScout = 0 }
			local function regKey(p: Vector3): string return math.floor(p.X / 8 + 0.5) .. "," .. math.floor(p.Z / 8 + 0.5) end
			local function saveRegs()
				local out = { discovered = knownRegs.discovered, registers = {} }
				for _, p in pairs(knownRegs.list) do table.insert(out.registers, { p.X, p.Y, p.Z }) end
				pcall(function() writefile(REG_FILE, HttpService:JSONEncode(out)) end)
			end
			local function learnReg(pos: Vector3): boolean
				local k = regKey(pos)
				if knownRegs.list[k] then return false end
				knownRegs.list[k] = pos
				return true
			end
			-- every store register on the map (found by flying a 350-stud grid over the
			-- whole map); all gas stations with a GasStationWorker behind the counter
			for _, p in ipairs(Library.ShopRegisters) do learnReg(p) end
			knownRegs.discovered = true
			pcall(function()
				if not (isfile and isfile(REG_FILE)) then return end
				local data = HttpService:JSONDecode(readfile(REG_FILE))
				knownRegs.discovered = data.discovered == true
				for _, r in ipairs(data.registers or {}) do learnReg(Vector3.new(r[1], r[2], r[3])) end
			end)
			local function regFolder()
				return workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Registers")
			end
			local function learnLoaded()
				local folder = regFolder()
				local added = false
				if folder then
					for _, r in ipairs(folder:GetChildren()) do
						if r:IsA("BasePart") and learnReg(r.Position) then added = true end
					end
				end
				if added then saveRegs() end
			end
			do   -- learn stores as they stream in while you play
				local folder = regFolder()
				if folder then RootMaid:Add(folder.ChildAdded:Connect(function() task.defer(learnLoaded) end)) end
			end
			local function registerNear(pos: Vector3)
				local folder = regFolder()
				if not folder then return nil end
				for _, r in ipairs(folder:GetChildren()) do
					if r:IsA("BasePart") and (r.Position - pos).Magnitude < 12 then return r end
				end
				return nil
			end
			local function readyRegister(r): boolean
				local minCash = tonumber(settings()["Min Register Cash"]) or 2500
				local amount, cooldown, zone = r:FindFirstChild("Amount"), r:FindFirstChild("Cooldown"), r:FindFirstChild("Proximity")
				return amount ~= nil and zone ~= nil and amount.Value >= minCash and not (cooldown and cooldown.Value)
			end
			-- far stores used to be checked in person with scooter hops (removed with the
			-- scooter travel, to be remade): only loaded registers are used for now
			local function findFarRegister(cancelled)
				knownRegs.lastScout = os.clock()
				return nil
			end
			local function waitOnSky(cancelled) end      -- the ride to the safe roof was removed (to be remade)
			return { known = knownRegs, SCOUT_EVERY = SCOUT_EVERY, learnLoaded = learnLoaded,
				readyRegister = readyRegister, findFarRegister = findFarRegister, waitOnSky = waitOnSky }
		end)()
		local function pickRegister()
			local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Registers")
			local _, _, hrp = refs()
			if not (folder and hrp) then return nil end
			local best, bestD
			for _, r in ipairs(folder:GetChildren()) do
				if r:IsA("BasePart") and Stores.readyRegister(r) then
					local d = (r.Position - hrp.Position).Magnitude
					if not bestD or d < bestD then best, bestD = r, d end
				end
			end
			return best
		end
		local function roadPointNear(pos: Vector3): Vector3?
			local roads = workspace:FindFirstChild("RoadSpawnPoints")
			if not roads then return nil end
			local best, bestD
			for _, p in ipairs(roads:GetDescendants()) do
				if p:IsA("BasePart") then
					local d = (p.Position - pos).Magnitude
					if not bestD or d < bestD then best, bestD = p.Position, d end
				end
			end
			return best and (best + Vector3.new(0, 3, 0)) or nil
		end
		-- where to hide: behind the counter, between the register and the worker's spot
		-- (the worker's OriginalCFrame attribute is where they stand behind the counter)
		local function hideSpot(register)
			local npcRef = register:FindFirstChild("NPC")
			local npc = npcRef and npcRef.Value
			local workerCF = npc and npc:GetAttribute("OriginalCFrame")
			local zone = register.Proximity
			if typeof(workerCF) == "CFrame" then
				local w = workerCF.Position
				local flat = Vector3.new(w.X - register.Position.X, 0, w.Z - register.Position.Z)
				local dir = flat.Magnitude > 0.2 and flat.Unit or Vector3.new(1, 0, 0)
				local spot = Vector3.new(register.Position.X, w.Y, register.Position.Z) + dir * math.min(1.2, flat.Magnitude * 0.55)
				return spot, w.Y
			end
			local floorY = zone.Position.Y - zone.Size.Y / 2 + 3
			return Vector3.new(zone.Position.X, floorY, zone.Position.Z), floorY
		end
		local function robRegister(register, cancelled)
			local amount = register.Amount
			local park = roadPointNear(register.Position)           -- the scooter is left outside on the road
			local spot, floorY = hideSpot(register)
			local _, hum = refs()
			local gun = findGun()
			if not (hum and gun) then return false, "lost the gun" end
			hum:EquipTool(gun)                                       -- arrive with the gun out
			local ok, why = Travel.moveTo(spot, { standAt = spot, groundY = floorY, park = park, cancelled = cancelled })
			if not ok then return false, why or "could not reach the store" end
			_, hum = refs()
			if not hum or cancelled() then return false end
			if LP.Character:FindFirstChildOfClass("Tool") ~= gun and gun.Parent then pcall(hum.EquipTool, hum, gun) end
			Travel.setProne(true)                                    -- hide prone under the counter
			-- stay until the till is empty / stops dropping, or time runs out; grab any
			-- cash that drops around the register while waiting
			local start, lastDrop, last = os.clock(), os.clock(), amount.Value
			local dropped = false
			local piles = {}                                         -- every cash pile that has dropped
			while os.clock() - start < SHOP_ROB_TIME and not cancelled() do
				if not refs() then break end                         -- died
				if LP.Character:FindFirstChildOfClass("Tool") ~= gun and gun.Parent then pcall(hum.EquipTool, hum, gun) end
				local now = amount.Value
				if now < last then dropped, lastDrop = true, os.clock() end
				last = now
				if now <= 0 or (dropped and os.clock() - lastDrop > SHOP_IDLE_DONE) then break end
				-- pick up drops as they land; a register pays out in 3 cash piles, so
				-- once they are all down grab them and go
				if Travel.grabCashInReach(register.Position, SHOP_CASH_RADIUS, piles) >= 3 then
					dropped = true
					break
				end
				task.wait(0.1)
			end
			if refs() and not cancelled() then Travel.grabCash(register.Position, SHOP_CASH_RADIUS, cancelled) end
			Travel.setProne(false)
			if cancelled() then return false end
			return dropped, (not dropped) and "the register did not pay out" or nil
		end
		local function runShop()
			shopToken = shopToken + 1
			local token = shopToken
			if not shopWanted() then return end
			if type(fireproximityprompt) ~= "function" then stopShop("your executor has no fireproximityprompt") return end
			local function cancelled() return token ~= shopToken or not shopWanted() end
			task.spawn(function()
				Library.Notify("Shops started")
				boughtThisRun = false           -- one Ruger allowed per run
				local fails, told = 0, false
				while not cancelled() do
					if not refs() then
						if not settings()["Auto Respawn"] then stopShop("you died (Auto Respawn is off)") return end
						local deadline = os.clock() + RESPAWN_WAIT
						while not refs() and os.clock() < deadline and not cancelled() do task.wait(0.5) end
						if cancelled() then return end
						if not refs() then stopShop("did not respawn") return end
						task.wait(1)
					end
					local okGun, whyGun = ensureGun()
					if cancelled() then return end
					if not okGun then stopShop(tostring(whyGun)) return end
					Stores.learnLoaded()
					local register = pickRegister()
					if not register and os.clock() - Stores.known.lastScout < Stores.SCOUT_EVERY then
						-- nothing ready nearby and the far stores were checked recently
						if not told then told = true; Library.Notify("Shops: no register has enough cash, waiting") end
						local t = os.clock() + SHOP_WAIT_EMPTY
						while os.clock() < t and not cancelled() do task.wait(0.5) end
					else
						told = false
						-- ask for the turn: Box Job finishes its current run first, then this goes
						local ok, res, why = Turn.run("shop", cancelled, function()
							-- re-check (it may have been robbed while waiting), else check the far stores
							local r = pickRegister() or Stores.findFarRegister(cancelled)
							if not r then
								if not cancelled() and refs() then Stores.waitOnSky(cancelled) end
								return false, "no register left"
							end
							return robRegister(r, cancelled)
						end)
						if cancelled() then return end
						if ok and res then
							fails = 0
							Library.Notify("Shops: robbed a register")
						elseif not refs() then
							-- died during the robbery: not a failure; Box Job (if on) carries on
						elseif ok and why == "no register left" then
							-- someone else got it first
						else
							fails = fails + 1
							Log.warn("Shops:", ok and why or res)
							if fails >= MAX_FAILS then stopShop(tostring((ok and why) or "it kept failing")) return end
							task.wait(2)
						end
					end
				end
			end)
		end
		P("Farms"):On("Shops", function() runShop() end)
		P("Farms"):On("Enabled", function() runShop() end)
		RootMaid:Add(function() shopToken = shopToken + 1 end)
	end
end

---------------------------------------------------------------------------
-- 9d. Auto Deposit: whenever cash goes above KEEP_CASH, the extra is deposited
--     through the game's ATM remote (works from anywhere, no ATM needed)
---------------------------------------------------------------------------
do
	local KEEP_CASH       = 1000      -- always left in the wallet
	local DEPOSIT_DEBOUNCE = 1        -- wait for cash to settle (payouts come in bursts)
	local CONFIRM_WAIT    = 3         -- give the server this long to apply a deposit
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local function atmRemote()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local atm = remotes and remotes:FindFirstChild("ATM")
		return (atm and atm:IsA("RemoteEvent")) and atm or nil
	end
	local function cashValue()
		local data = LP:FindFirstChild("Data")
		local money = data and data:FindFirstChild("Money")
		return (money and (money:IsA("IntValue") or money:IsA("NumberValue"))) and money or nil
	end
	local function wanted() return Cfg["Autofarm Settings"]["Auto Deposit"] == true end

	local busy, queued = false, false
	local function depositExtra()
		if busy then queued = true return end
		busy = true
		task.delay(DEPOSIT_DEBOUNCE, function()
			local money, atm = cashValue(), atmRemote()
			if wanted() and money and atm then
				local extra = math.floor(money.Value - KEEP_CASH)
				if extra > 0 then
					local before = money.Value
					local ok, err = pcall(atm.FireServer, atm, "Deposit", extra)
					if not ok then
						Log.warn("Auto Deposit failed:", err)
					else
						local deadline = os.clock() + CONFIRM_WAIT
						while money.Value == before and os.clock() < deadline do task.wait(0.1) end
					end
				end
			elseif wanted() and not atm then
				Library.Notify("Auto Deposit: this game has no ATM remote")
			end
			busy = false
			if queued then queued = false; depositExtra() end
		end)
	end

	local moneyConn
	local function watch()
		if moneyConn then moneyConn:Disconnect(); moneyConn = nil end
		if not wanted() then return end
		local money = cashValue()
		if not money then Library.Notify("Auto Deposit: cash value not found") return end
		moneyConn = money.Changed:Connect(depositExtra)
		depositExtra()      -- bank what is already over the limit right away
	end
	P("Autofarm Settings"):On("Auto Deposit", function() watch() end)
	RootMaid:Add(function() if moneyConn then moneyConn:Disconnect() end end)
end

---------------------------------------------------------------------------
-- 9e. Weapon Mods: edits the game's own gun object (GunFramework) and its
--     Settings table for the gun in your hand; turning a mod off puts the
--     gun's original value back.
--     Measured in this game: the server keeps its own ammo count and reload
--     timer (the Ruger always takes 2.5 s server side). The server counted every
--     shot at 8x fire rate (Glock17).
---------------------------------------------------------------------------
do
	local MAX_FIRE_MULT     = 8          -- the server counted every shot at 8x (Glock17, 0.018 s apart)
	local FAST_BULLET_SPEED = 20000      -- studs / s: bullets land almost instantly
	local FAR_RANGE         = 100000
	local APPLY_EVERY       = 0.2
	local CollectionService = game:GetService("CollectionService")

	local originals = setmetatable({}, { __mode = "k" })   -- Settings table -> its original values
	local objCache  = setmetatable({}, { __mode = "k" })   -- gun tool -> the game's gun object
	local function mods() return Cfg["Weapon Mods"] end
	local function on(name: string): boolean return En("Weapon Mods") and mods()[name] == true end

	local function equippedGun()
		local c = LP.Character
		if not c then return nil end
		for _, t in ipairs(c:GetChildren()) do
			if t:IsA("Tool") and CollectionService:HasTag(t, "Gun") then return t end
		end
		return nil
	end
	-- the game's client object for your gun (has Settings, DeltaTime, Spring_Recoil, Reload)
	local function gunObject(tool)
		local cached = objCache[tool]
		if cached and not cached.IsDestroyed then return cached end
		if type(getgc) ~= "function" then return nil end
		for _, v in ipairs(getgc(true)) do
			if type(v) == "table" and rawget(v, "Instance") == tool and rawget(v, "Spring_Recoil") ~= nil and rawget(v, "DeltaTime") ~= nil then
				objCache[tool] = v
				return v
			end
		end
		return nil
	end

	local function apply(obj)
		local S = obj.Settings
		if type(S) ~= "table" then return end
		local o = originals[S]
		if not o then
			o = { IsAutomatic = S.IsAutomatic, Recoil = S.Recoil, SprayAngle = S.SprayAngle, SpreadFactor = S.SpreadFactor,
				Range = S.Range, BulletSpeed = S.BulletSpeed, FireRate = S.FireRate, JamChance = S.JamChance or false }
			originals[S] = o
		end
		-- Rapid Fire: the shot delay (DeltaTime) AND FireRate both have to go up, because
		-- the game's Fire() also waits half a FireRate interval after every shot. It
		-- makes the gun automatic and jam-free, or holding the trigger would do nothing.
		local rapid = on("Rapid Fire")
		local mult = rapid and math.clamp(tonumber(mods()["Fire Rate"]) or 1, 1, MAX_FIRE_MULT) or 1
		S.FireRate = o.FireRate * mult
		obj.DeltaTime = 60 / S.FireRate
		if rapid then S.JamChance = nil elseif o.JamChance then S.JamChance = o.JamChance end
		S.IsAutomatic = rapid or on("Force Automatic") or o.IsAutomatic
		S.Recoil      = on("No Recoil") and 0 or o.Recoil
		-- shotgun pellets are the only random spread; pistols / rifles already fly
		-- straight at the mouse, so No Spread also keeps the camera from drifting (below)
		S.SprayAngle   = on("No Spread") and 0 or o.SprayAngle
		S.SpreadFactor = on("No Spread") and 0 or o.SpreadFactor
		S.Range       = on("Infinite Range") and FAR_RANGE or o.Range
		S.BulletSpeed = on("No Bullet Drop") and FAST_BULLET_SPEED or o.BulletSpeed   -- no gravity here, so: near-instant bullets
	end

	local RELOAD_MARGIN = 0.3     -- wait this long past the reload time before another one
	local current, lastApply, reloadBusyUntil = nil, 0, 0
	RootMaid:Add(RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastApply < APPLY_EVERY then return end
		lastApply = now
		local tool = equippedGun()
		current = tool and gunObject(tool) or nil
		if not current then return end
		apply(current)
		-- at high fire rates the server skips a few shots, so your client can count
		-- the mag empty while the server still has rounds: copy the server's count back
		local serverAmmo = tool:GetAttribute("Ammo_Server") or 0
		if En("Weapon Mods") and (tool:GetAttribute("Ammo_Client") or 0) <= 0 and serverAmmo > 0 and not tool:GetAttribute("IsReloading") then
			tool:SetAttribute("Ammo_Client", serverAmmo)
		end
		-- Auto Reload: reload as soon as the server's mag is empty
		if on("Auto Reload") and serverAmmo <= 0 and now >= reloadBusyUntil and not tool:GetAttribute("IsReloading") then
			local kind = tool:GetAttribute("AmmoType") or current.Settings.AmmoType
			local hasReserve = (tool:GetAttribute("Capacity") or 0) > 0 or (kind and LP.Backpack:FindFirstChild(kind .. " Ammo"))
			if hasReserve then
				reloadBusyUntil = now + (current.Settings.ReloadTime or 2.5) + RELOAD_MARGIN
				pcall(current.Reload, current)
			end
		end
	end))
	Library.CurrentGun = function() return current end   -- the game's object for the gun in your hand (Aimbot Auto Shoot)
	-- the gun kicks the camera through a spring (pitch / yaw from Recoil plus a random
	-- roll that Recoil = 0 does not remove). Measured spring offset per shot: 0.93
	-- normal, 0.80 with Recoil = 0, 0.00 with this reset. So No Recoil, No Spread
	-- (camera drift between shots) and No Sway reset the spring right before the gun
	-- moves the camera.
	RunService:BindToRenderStep("VW_NoSway_" .. INSTANCE_ID, Enum.RenderPriority.Camera.Value, function()
		if current and current.Spring_Recoil and (on("No Recoil") or on("No Spread") or on("No Sway")) then
			pcall(current.Spring_Recoil.ResetState, current.Spring_Recoil)
		end
	end)
	-- No Sway also stops the game's screen shakes (taking damage, explosions, fists,
	-- weather): every CameraShaker shares one module, so its Update is wrapped
	local okShaker, Shaker = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("CameraShaker", 5))
	end)
	if okShaker and type(Shaker) == "table" and type(Shaker.Update) == "function" then
		local originalUpdate = Shaker.Update
		Shaker.Update = function(self, dt)
			if on("No Sway") then
				if type(self._camShakeInstances) == "table" then table.clear(self._camShakeInstances) end
				return CFrame.identity
			end
			return originalUpdate(self, dt)
		end
		RootMaid:Add(function() Shaker.Update = originalUpdate end)
	end
	RootMaid:Add(function()
		pcall(RunService.UnbindFromRenderStep, RunService, "VW_NoSway_" .. INSTANCE_ID)
		-- put every modified gun back to normal
		for S, o in pairs(originals) do
			for k, v in pairs(o) do
				if k == "JamChance" then S[k] = v or nil else S[k] = v end
			end
		end
		for _, obj in pairs(objCache) do
			local o = originals[obj.Settings]
			if o then obj.DeltaTime = 60 / o.FireRate end
		end
	end)
end

---------------------------------------------------------------------------
-- 9f. Aimbot + Silent Aim
--   Silent Aim is the logic of the user's silent aim script: every bullet YOUR
--   gun creates (GunFramework Projectile.new) is pointed at the target part, and
--   with Visible Check off it only collides with the target (so it goes through
--   walls). Its visuals are on the menu's FOV Circle / FOV Color / Show Target. Fixed
--   from the original: other players' bullets are left alone, and the gun's shared
--   RaycastParams is never changed (a fresh one is made per redirected bullet).
--   Aimbot moves the camera or the mouse onto the target while its hotkey is held;
--   Aim Mode "Silent" uses the bullet redirect with the Aimbot's settings.
---------------------------------------------------------------------------
do
	local CollectionService = game:GetService("CollectionService")
	local FOV_PX_PER_UNIT = 5            -- Field Of View slider 0-100 -> 0-500 px around the mouse
	local DIST_PER_UNIT   = 10           -- Aim Distance slider 0-100 -> 0-1000 studs (100 = no limit)
	local OWN_BULLET_DIST = 25           -- a bullet starting this close to you is yours
	local AIM_PARTS = { "Head", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm",
		"LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
		"Left Arm", "Right Arm", "Left Leg", "Right Leg" }

	-- per-frame answers shared by the render step and the Heartbeat shot code (one
	-- table: this section is close to Luau's 200-local limit). n goes up once a frame
	-- (start of the Aimbot render step); keys = hotkey name -> Enum.KeyCode (false =
	-- not a key); gun / aura / silent = the answer and the frame it was worked out in
	local AimFrame = { n = 0, keys = {}, gun = { f = -1, v = false }, aura = { f = -1 }, silent = { f = -1 }, errShown = false }
	local function keyHeld(name): boolean
		if name == "Mouse 1" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
		if name == "Mouse 2" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
		if name == "Mouse 3" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton3) end
		local code = AimFrame.keys[name]
		if code == nil then
			local ok, c = pcall(function() return Enum.KeyCode[name] end)
			code = ok and c or false
			AimFrame.keys[name] = code
		end
		return code ~= false and UIS:IsKeyDown(code)
	end
	local function holdingGun(): boolean
		local gunMemo = AimFrame.gun
		if gunMemo.f == AimFrame.n then return gunMemo.v end
		local v = false
		local c = LP.Character
		if c then
			for _, t in ipairs(c:GetChildren()) do
				if t:IsA("Tool") and CollectionService:HasTag(t, "Gun") then v = true break end
			end
		end
		gunMemo.f, gunMemo.v = AimFrame.n, v
		return v
	end
	-- safe zones: workspace.Zones.Safe holds (possibly rotated) block parts; a player
	-- whose root is inside one is never targeted by Aimbot, Silent Aim or Kill Aura
	local SAFE_REFRESH = 5
	local safeParts, safeT = {}, -math.huge
	local function inSafeZone(state): boolean
		local now = os.clock()
		if now - safeT > SAFE_REFRESH then
			safeT = now
			safeParts = {}
			local zones = workspace:FindFirstChild("Zones")
			local safe = zones and zones:FindFirstChild("Safe")
			if safe then
				for _, d in ipairs(safe:GetDescendants()) do
					if d:IsA("BasePart") then safeParts[#safeParts + 1] = d end
				end
			end
		end
		local root = state.Root
		if not root then return false end
		local pos = root.Position
		for i = 1, #safeParts do
			local part = safeParts[i]
			if part.Parent then
				local lp = part.CFrame:PointToObjectSpace(pos)
				local half = part.Size * 0.5
				if math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z then return true end
			end
		end
		return false
	end
	-- players in the tutorial: the game's own gun code refuses hits on a character that
	-- has an "OnboardingHighlight" ("This Player is in a Tutorial!"), so they are skipped
	local function inTutorial(state): boolean
		return state.Char ~= nil and state.Char:FindFirstChild("OnboardingHighlight") ~= nil
	end
	local function isDowned(state): boolean
		return state.Char:GetAttribute("Critical") == true or state.Hum:GetAttribute("_RagdollState") ~= nil and state.Hum:GetAttribute("_RagdollState") ~= false
	end

	-- the same things the gun's bullets ignore (Zones, Storage, map background, IgnoreBullets)
	local visParams = RaycastParams.new()
	visParams.FilterType = Enum.RaycastFilterType.Exclude
	pcall(function() visParams.CollisionGroup = "Bullet" end)
	-- The filter (ignore list + your character) is set once and refreshed every 2 s or
	-- when you respawn, not per ray: it used to be copied and handed to the engine for
	-- every player checked, every frame (the engine converts the whole array each time,
	-- and IgnoreBullets can tag many parts). The target's character is not in the
	-- filter any more; a ray that hits the target itself counts as a clear view, which
	-- is the same answer as excluding it (the ray ends on the target).
	local ignoreT, ignoreChar = -math.huge, nil
	local function canSee(state, point: Vector3): boolean
		local now = os.clock()
		local myCharNow = LP.Character
		if now - ignoreT > 2 or ignoreChar ~= myCharNow then
			ignoreT, ignoreChar = now, myCharNow
			local list = {}
			for _, name in ipairs({ "Zones", "Storage" }) do
				local f = workspace:FindFirstChild(name)
				if f then list[#list + 1] = f end
			end
			local map = workspace:FindFirstChild("Map")
			if map and map:FindFirstChild("Background") then list[#list + 1] = map.Background end
			for _, inst in ipairs(CollectionService:GetTagged("IgnoreBullets")) do list[#list + 1] = inst end
			if myCharNow then list[#list + 1] = myCharNow end
			visParams.FilterDescendantsInstances = list
		end
		local origin = Camera.CFrame.Position
		local hit = workspace:Raycast(origin, point - origin, visParams)
		return hit == nil or (state.Char ~= nil and hit.Instance:IsDescendantOf(state.Char))
	end

	local function screenDist(point: Vector3, mouse: Vector2): number?
		local v, onScreen = Camera:WorldToViewportPoint(point)
		if not onScreen or v.Z <= 0 then return nil end
		return (Vector2.new(v.X, v.Y) - mouse).Magnitude
	end
	-- the part (and the world point on it) to aim at for a Hitbox choice
	local function aimPoint(state, hitbox: string, mouse: Vector2)
		local c = state.Char
		if hitbox == "Closest" or hitbox == "Random" then
			-- limbs come from the player registry (kept up to date by ChildAdded /
			-- ChildRemoved), not 17 FindFirstChild calls per player per frame
			local limbs, random = state.Limbs, hitbox == "Random"
			local list = random and {} or nil
			local best, bestD = nil, nil
			for _, name in ipairs(AIM_PARTS) do
				local p = name == "HumanoidRootPart" and state.Root or limbs[name]
				if p and p.Parent == c then
					if list then list[#list + 1] = p end
					local d = screenDist(p.Position, mouse)
					if d and (not bestD or d < bestD) then best, bestD = p, d end
				end
			end
			if list and #list > 0 then best = list[math.random(1, #list)] end
			return best, best and best.Position
		end
		if hitbox == "Neck" then
			local h = state.Head
			return h, h and (h.Position - Vector3.new(0, h.Size.Y * 0.35, 0))
		end
		if hitbox == "Torso" then
			local t = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
			return t, t and t.Position
		end
		if hitbox == "HumanoidRootPart" then return state.Root, state.Root and state.Root.Position end
		local h = state.Head or state.Root
		return h, h and h.Position
	end

	-- o = { fov (px), maxDist, hitbox, visible, downed, priority, sticky (state) }
	local function findTarget(o)
		local mouse = UIS:GetMouseLocation()
		local camPos = Camera.CFrame.Position
		local best, bestScore, bestPart, bestPoint
		for _, plr in ipairs(playerList) do
			local s = states[plr]
			if s and s.Char and s.Char.Parent and s.Hum and s.Hum.Health > 0
				and not (o.downed and isDowned(s)) and not inSafeZone(s) and not inTutorial(s) then
				local part, point = aimPoint(s, o.hitbox, mouse)
				if part and point then
					local sd = screenDist(point, mouse)
					local wd = (point - camPos).Magnitude
					if sd and sd <= o.fov and wd <= o.maxDist and (not o.visible or canSee(s, point)) then
						local score
						if o.priority == "Closest Distance" then score = wd
						elseif o.priority == "Lowest Health" then score = s.Hum.Health
						elseif o.priority == "Highest Threat" then
							score = wd * ((s.Tool and CollectionService:HasTag(s.Tool, "Gun")) and 0.25 or 1)
						else score = sd end
						if o.sticky and s == o.sticky then score = -math.huge end
						if not bestScore or score < bestScore then best, bestScore, bestPart, bestPoint = s, score, part, point end
					end
				end
			end
		end
		return best, bestPart, bestPoint
	end

	local function aimbotOpts(sticky)
		local A = Cfg.Aimbot
		local distUnits = tonumber(A["Aim Distance"]) or 100
		return {
			fov = (tonumber(A["Field Of View"]) or 0) * FOV_PX_PER_UNIT,
			maxDist = distUnits >= 100 and math.huge or distUnits * DIST_PER_UNIT,
			hitbox = A["Hitbox"] or "Head", visible = A["Visible Check"] == true,
			downed = A["Ignore Downed"] == true, priority = A["Target Priority"], sticky = sticky,
		}
	end
	local function silentOpts()
		local S = Cfg["Silent Aim"]
		return {
			fov = (tonumber(S["Field Of View"]) or 0) * FOV_PX_PER_UNIT, maxDist = math.huge,
			hitbox = S["Closest Part"] and "Closest" or (S["Hitbox"] or "Head"), visible = S["Visible Check"] == true,
			downed = false, priority = "Closest To Crosshair", silent = true,
		}
	end
	local function aimbotOn(): boolean
		return En("Aimbot") and Cfg.Aimbot["Enable Aimbot"] == true
	end
	local function aimbotHeld(): boolean
		return aimbotOn() and keyHeld(Cfg.Aimbot["Aimbot Hotkey"])
	end
	-- which redirect applies to a bullet right now (nil = leave it alone)
	local function silentSettings()
		if not holdingGun() then return nil end
		local S = Cfg["Silent Aim"]
		if En("Silent Aim") and S["Enable Silent Aim"] then            -- always on, no hotkey
			return silentOpts(), tonumber(S["Hit Chance"]) or 100
		end
		if aimbotHeld() and Cfg.Aimbot["Aim Mode"] == "Silent" then return aimbotOpts(nil), 100 end
		return nil
	end

	-- Kill Aura: the nearest player within Range of YOU (all directions, no FOV). How
	-- hits reach the server (read from GunClient): every shot sends Fire(code, origin,
	-- dir) and the server takes a round for it; a bullet that hits a player sends
	-- Position(code, gunId, part, dir, nil, token). So the gun really fires (ammo is
	-- used) and each bullet is pointed at the aura target, like Silent Aim.
	local function killAuraOn(): boolean
		local K = Cfg["Kill Aura"]
		return En("Kill Aura") and K ~= nil and K["Enable Kill Aura"] == true and holdingGun()
	end
	function AimFrame.searchAura()
		local K = Cfg["Kill Aura"]
		local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if not root then return nil end
		local range = tonumber(K["Range"]) or 100
		local mouse = UIS:GetMouseLocation()
		local best, bestD, bestPart, bestPoint
		for _, plr in ipairs(playerList) do
			local s = states[plr]
			if s and s.Char and s.Char.Parent and s.Hum and s.Hum.Health > 0 and s.Root
				and not (K["Ignore Downed"] and isDowned(s)) and not inSafeZone(s) and not inTutorial(s) then
				local d = (s.Root.Position - root.Position).Magnitude
				if d <= range and (not bestD or d < bestD) then
					local part, point = aimPoint(s, "Head", mouse)        -- Kill Aura only hits the head
					if part and point and (not K["Visible Check"] or canSee(s, point)) then
						best, bestD, bestPart, bestPoint = s, d, part, point
					end
				end
			end
		end
		return best, bestPart, bestPoint
	end
	-- The target searches (every player: safe zone, limbs, projection, raycast) ran
	-- twice a frame, once in the Aimbot render step (Kill Aura trigger, Silent Aim
	-- circle / tracer) and again in the Heartbeat that prepares the next shot. The
	-- first search of a frame is kept and reused; the reuse re-reads the chosen part's
	-- position so the shot does not aim where the target was before physics ran.
	function AimFrame.fresh(part, point: Vector3, hitbox: string?): Vector3
		if not part.Parent then return point end
		if hitbox == "Neck" then return part.Position - Vector3.new(0, part.Size.Y * 0.35, 0) end
		return part.Position
	end
	local function findAuraTarget()
		local m = AimFrame.aura
		if m.f == AimFrame.n then
			return m.t, m.part, m.part and AimFrame.fresh(m.part, m.point, "Head")
		end
		local t, part, point = AimFrame.searchAura()
		m.f, m.t, m.part, m.point = AimFrame.n, t, part, point
		return t, part, point
	end
	-- the same for Silent Aim's own settings (silentOpts)
	local function findSilentTarget(opts)
		local m = AimFrame.silent
		if m.f == AimFrame.n and m.hitbox == opts.hitbox then
			return m.t, m.part, m.part and AimFrame.fresh(m.part, m.point, opts.hitbox)
		end
		local t, part, point = findTarget(opts)
		m.f, m.hitbox, m.t, m.part, m.point = AimFrame.n, opts.hitbox, t, part, point
		return t, part, point
	end

	-- point a bullet at a target part and let it collide with ONLY that part. Letting it
	-- hit the whole character was not enough: hats / hair (accessory Handles) sit in
	-- front of the head and a hit on them is not a hit on the player (the game only
	-- counts a part whose parent holds the Humanoid). Target selection has already
	-- done the Visible Check, so this is safe for both through-walls and visible modes.
	local function redirect(params, part, point: Vector3)
		params.Direction = (point - params.Origin).Unit
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { part }
		if params.RaycastParams then pcall(function() rp.CollisionGroup = params.RaycastParams.CollisionGroup end) end
		params.RaycastParams = rp
	end

	-- One decision per shot: which part (if any) this shot goes to. Kill Aura first
	-- (while it has someone in range every shot goes to them), then Silent Aim.
	local function chooseShot()
		if killAuraOn() then
			local t, part, point = findAuraTarget()
			if t and part and point and part:IsDescendantOf(workspace) then return part, point end
		end
		local opts, chance = silentSettings()
		if not opts or math.random(1, 100) > chance then return nil end
		local target, part, point = (opts.silent and findSilentTarget or findTarget)(opts)
		if target and part and point and part:IsDescendantOf(workspace) then return part, point end
		return nil
	end

	-- A shot is two messages: Fire(code, origin, direction) when you shoot, then the hit
	-- report (Position) when the bullet lands. Redirecting only the bullet made the two
	-- disagree (the shot pointed at the mouse, the hit somewhere else) and the server
	-- threw the hit away: the hit marker showed but no damage was done. So the Fire call
	-- is pointed at the target too, and the bullets of that shot reuse the same decision.
	local SHOT_WINDOW = 0.25        -- a shot's bullets are created right after its Fire call
	local pending = nil             -- { part, point, t } decided when the shot was sent
	-- The target is worked out every frame (only while Silent Aim or Kill Aura is on),
	-- NOT inside the Fire hook: finding a target makes method calls (:FindFirstChild,
	-- :Raycast, ...), and a method call made inside the __namecall hook replaces the
	-- method the hook is handling, so the game's FireServer went out as some other
	-- method and the server never got the shot (checked in game: no ammo used, no
	-- damage, with Silent Aim / Kill Aura off too). The redirect only reads the ready
	-- answer and makes no method calls at all.
	local nextShot = { part = nil, point = nil }
	RootMaid:Add(RunService.Heartbeat:Connect(function()
		if not (killAuraOn() or silentSettings()) then nextShot.part, nextShot.point = nil, nil return end
		Library.ProfBegin("VW_NextShot")
		local ok, part, point = pcall(chooseShot)
		Library.ProfEnd()
		if ok and part then nextShot.part, nextShot.point = part, point else nextShot.part, nextShot.point = nil, nil end
	end))
	getgenv().VW_ShotRedirect = function(origin: Vector3)
		local part, point = nextShot.part, nextShot.point
		pending = { part = part, point = point, t = os.clock() }
		if not part then return nil end
		return (point - origin).Unit
	end
	RootMaid:Add(function() getgenv().VW_ShotRedirect = nil end)
	-- the Fire hook is installed once per game session and calls whatever redirect the
	-- current menu instance set, so reloading the menu never stacks hooks. It sees every
	-- method call the game makes, so it is only installed the first time Silent Aim or
	-- Kill Aura is turned on.
	local function installShotHook()
		if getgenv().VW_ShotHooked or type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return end
		local okRemote, fireRemote = pcall(function()
			return game:GetService("ReplicatedStorage").Modules.GunFramework.Remotes.Fire
		end)
		if okRemote and fireRemote then
			getgenv().VW_ShotHooked = true
			local genv = getgenv()
			local old
			local setMethod = type(setnamecallmethod) == "function" and setnamecallmethod or nil
			old = hookmetamethod(game, "__namecall", function(self, ...)
				if self == fireRemote then
					local method = getnamecallmethod()
					if method == "FireServer" then
						local fn = genv.VW_ShotRedirect
						if fn then
							local args = table.pack(...)
							if typeof(args[2]) == "Vector3" and typeof(args[3]) == "Vector3" then
								local ok, dir = pcall(fn, args[2])
								-- whatever fn did, the call below stays a FireServer (see VW_ShotRedirect)
								if setMethod then setMethod(method) end
								if ok and dir then
									args[3] = dir
									return old(self, table.unpack(args, 1, args.n))
								end
							end
						end
					end
				end
				return old(self, ...)
			end)
		end
	end
	local function maybeInstallShotHook()
		local SA, KA = Cfg["Silent Aim"], Cfg["Kill Aura"]
		if (SA and SA["Enable Silent Aim"] == true) or (KA and KA["Enable Kill Aura"] == true) then installShotHook() end
	end
	P("Silent Aim"):On("Enable Silent Aim", maybeInstallShotHook)
	P("Kill Aura"):On("Enable Kill Aura", maybeInstallShotHook)

	-- Silent Aim / Kill Aura: redirect your bullets as the game creates them
	local okProj, Projectile = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("GunFramework", 5).Modules.Projectile)
	end)
	if okProj and type(Projectile) == "table" and type(Projectile.new) == "function" then
		local originalNew = Projectile.new
		Projectile.new = function(params)
			local ok = pcall(function()
				if type(params) ~= "table" or typeof(params.Origin) ~= "Vector3" then return end
				local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
				if not root or (params.Origin - root.Position).Magnitude > OWN_BULLET_DIST then return end   -- someone else's bullet
				-- use the decision made when this shot was sent (the Fire call above)
				local shot = pending
				if shot and os.clock() - shot.t <= SHOT_WINDOW then
					if shot.part and shot.part:IsDescendantOf(workspace) then redirect(params, shot.part, shot.point) end
					return
				end
				-- no recent Fire decision (hook unavailable): decide now
				local part, point = chooseShot()
				if part then redirect(params, part, point) end
			end)
			if not ok then Log.warn("Silent Aim: redirect failed") end
			return originalNew(params)
		end
		RootMaid:Add(function() Projectile.new = originalNew end)
	else
		Log.warn("Silent Aim: GunFramework Projectile module not found")
	end

	-- Aimbot: camera / mouse aim, Auto Shoot, FOV circle, Show Target
	local fovCircle = New("Frame", { Name = "AimbotFOV", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = Overlay })
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fovCircle })
	local fovStroke = New("UIStroke", { Thickness = 1.2, Transparency = 0.3, Parent = fovCircle })
	-- Show Target (Aimbot and Silent Aim): a tracer line from the mouse to the target point
	local TRACER_THICKNESS = 1.5
	local SILENT_RED = Color3.fromRGB(255, 50, 50)
	local function newTracer(name: string)
		return New("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
			BackgroundColor3 = SILENT_RED, Visible = false, ZIndex = 2, Parent = Overlay })
	end
	local function placeTracer(line, from: Vector2, to: Vector2)
		local delta = to - from
		local mid = (from + to) / 2
		line.Position = UDim2.fromOffset(mid.X, mid.Y)
		line.Size = UDim2.fromOffset(delta.Magnitude, TRACER_THICKNESS)
		line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	end
	local aimTracer = newTracer("AimbotTracer")
	RootMaid:Add(fovCircle); RootMaid:Add(aimTracer)
	-- Silent Aim visuals (as in the user's script): FOV circle on the mouse + tracer to the target
	local silentCircle = New("Frame", { Name = "SilentFOV", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = Overlay })
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = silentCircle })
	local silentStroke = New("UIStroke", { Thickness = 1.2, Transparency = 0.3, Parent = silentCircle })
	local silentTracer = newTracer("SilentTracer")
	RootMaid:Add(silentCircle); RootMaid:Add(silentTracer)

	local locked = nil          -- Sticky Aim target
	local autoFlip, autoShooting = false, false
	local function stopAutoShoot()
		if not autoShooting then return end
		autoShooting = false
		local gun = Library.CurrentGun and Library.CurrentGun()
		if gun then gun._FireRequest = false end
	end
	local function smoothAlpha(dt: number): number
		local A = Cfg.Aimbot
		local s = math.clamp((tonumber(A["Smooth"]) or 0) / 100, 0, 0.98)
		local base = 1 - s                                   -- share of the gap closed per 60 fps frame
		local kind = A["Smooth Type"]
		if kind == "Exponential" then return 1 - (1 - base) ^ (dt * 60) end
		if kind == "Humanized" then return math.clamp((1 - (1 - base) ^ (dt * 60)) * (0.6 + math.random() * 0.8), 0, 1) end
		return math.clamp(base * dt * 60, 0, 1)             -- Linear
	end

	-- Kill Aura trigger: holds the game's own trigger (toggled each frame so semi-autos
	-- fire too) while someone is in range; the bullets are redirected above
	local auraFlip, auraShooting = false, false
	local function stopAura()
		if not auraShooting then return end
		auraShooting = false
		local gun = Library.CurrentGun and Library.CurrentGun()
		if gun then gun._FireRequest = false end
	end
	local function killAuraStep()
		if not killAuraOn() then stopAura() return end
		local target = findAuraTarget()
		local gun = Library.CurrentGun and Library.CurrentGun()
		if target and gun then
			auraFlip = not auraFlip
			gun._FireRequest = auraFlip
			auraShooting = true
		else
			stopAura()
		end
	end

	function AimFrame.step(dt)
		local A = Cfg.Aimbot
		local enabled = aimbotOn()
		local mouse = UIS:GetMouseLocation()
		pcall(killAuraStep)
		-- FOV circle
		local showFov = enabled and A["FOV Circle"] == true
		if fovCircle.Visible ~= showFov then fovCircle.Visible = showFov end
		if showFov then
			local r = (tonumber(A["Field Of View"]) or 0) * FOV_PX_PER_UNIT
			fovCircle.Size = UDim2.fromOffset(r * 2, r * 2)
			fovCircle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
			if typeof(A["FOV Color"]) == "Color3" then fovStroke.Color = A["FOV Color"] end
		end
		-- Silent Aim FOV circle + target tracer (shown whenever Silent Aim is on)
		local SA = Cfg["Silent Aim"]
		local silentOn = En("Silent Aim") and SA["Enable Silent Aim"] == true
		local showSilentFov = silentOn and SA["FOV Circle"] == true
		if silentCircle.Visible ~= showSilentFov then silentCircle.Visible = showSilentFov end
		local silentTarget, silentPoint = nil, nil
		if silentOn and (showSilentFov or SA["Show Target"]) then
			local t, _, p = findSilentTarget(silentOpts())
			silentTarget, silentPoint = t, p
		end
		if showSilentFov then
			local r = (tonumber(SA["Field Of View"]) or 0) * FOV_PX_PER_UNIT
			silentCircle.Size = UDim2.fromOffset(r * 2, r * 2)
			silentCircle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
			-- the circle turns red while it has a target, like the original script
			silentStroke.Color = silentTarget and Color3.fromRGB(255, 50, 50)
				or (typeof(SA["FOV Color"]) == "Color3" and SA["FOV Color"] or Color3.new(1, 1, 1))
		end
		local silentLine = false
		if silentOn and SA["Show Target"] and silentPoint then
			local v, onScreen = Camera:WorldToViewportPoint(silentPoint)
			if onScreen then
				placeTracer(silentTracer, mouse, Vector2.new(v.X, v.Y))
				silentLine = true
			end
		end
		if silentTracer.Visible ~= silentLine then silentTracer.Visible = silentLine end

		if not aimbotHeld() then
			locked = nil
			if aimTracer.Visible then aimTracer.Visible = false end
			stopAutoShoot()
			return
		end
		local target, _, point = findTarget(aimbotOpts(A["Sticky Aim"] and locked or nil))
		locked = target
		local aimLine = false
		if target and point and A["Show Target"] then
			local v, onScreen = Camera:WorldToViewportPoint(point)
			if onScreen then
				if typeof(A["FOV Color"]) == "Color3" then aimTracer.BackgroundColor3 = A["FOV Color"] end
				placeTracer(aimTracer, mouse, Vector2.new(v.X, v.Y))
				aimLine = true
			end
		end
		if aimTracer.Visible ~= aimLine then aimTracer.Visible = aimLine end
		if not (target and point) then stopAutoShoot() return end

		local mode = A["Aim Mode"]
		if mode ~= "Silent" then
			local alpha = smoothAlpha(dt)
			if A["Smooth Type"] == "Humanized" then point = point + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.3 end
			if mode == "Mouse" and type(mousemoverel) == "function" then
				local v, onScreen = Camera:WorldToViewportPoint(point)
				if onScreen then
					local delta = (Vector2.new(v.X, v.Y) - mouse) * alpha
					mousemoverel(delta.X, delta.Y)
				end
			else
				local cf = Camera.CFrame
				local want = (point - cf.Position).Unit
				local look = cf.LookVector:Lerp(want, alpha)
				Camera.CFrame = CFrame.lookAt(cf.Position, cf.Position + look)
			end
		end

		-- Auto Shoot: pull the game's own trigger while a visible target is locked
		if A["Auto Shoot"] and holdingGun() then
			local gun = Library.CurrentGun and Library.CurrentGun()
			if gun and canSee(target, point) then
				autoFlip = not autoFlip             -- toggling fires semi-auto guns too
				gun._FireRequest = autoFlip
				autoShooting = true
			else
				stopAutoShoot()
			end
		else
			stopAutoShoot()
		end
	end
	RunService:BindToRenderStep("VW_Aimbot_" .. INSTANCE_ID, Enum.RenderPriority.Camera.Value + 2, function(dt)
		AimFrame.n = AimFrame.n + 1      -- a new frame: the per-frame answers above start over
		Library.ProfBegin("VW_Aim")
		local ok, err = pcall(AimFrame.step, dt)
		Library.ProfEnd()
		if not ok and not AimFrame.errShown then AimFrame.errShown = true; Log.warn("Aimbot:", err) end
	end)
	RootMaid:Add(function()
		pcall(RunService.UnbindFromRenderStep, RunService, "VW_Aimbot_" .. INSTANCE_ID)
		stopAutoShoot()
		stopAura()
	end)
end

---------------------------------------------------------------------------
-- 9g. Auto Buy: gun store purchases through the game's GunBuy remote (works away
--     from the store; measured with Pistol Ammo). Cash that is short is withdrawn
--     from the bank first. A purchase counts once the cash actually drops.
---------------------------------------------------------------------------
do
	local BUY_CONFIRM_WAIT = 2.5
	local AUTO_AMMO_EVERY  = 2
	local CollectionService = game:GetService("CollectionService")

	local function gunBuyRemote()
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		return remotes and remotes:FindFirstChild("GunBuy")
	end
	local function data(name: string)
		local d = LP:FindFirstChild("Data")
		return d and d:FindFirstChild(name)
	end
	local function owns(name: string): boolean
		return LP.Backpack:FindFirstChild(name) ~= nil or (LP.Character ~= nil and LP.Character:FindFirstChild(name) ~= nil)
	end
	-- live price / level from the store wall when it is streamed in
	local function storeSlot(wallName: string, slot: string)
		local map = workspace:FindFirstChild("Map")
		local store = map and map:FindFirstChild("GunStore")
		local wall = store and store:FindFirstChild(wallName)
		return wall and wall:FindFirstChild(slot)
	end
	local function livePrice(entry, wallName: string)
		local slot = storeSlot(wallName, entry.Slot)
		local p = slot and slot:FindFirstChild("Price")
		local lv = slot and slot:FindFirstChild("Level")
		return (p and p.Value) or entry.Price, (lv and lv.Value) or entry.Level or 0
	end

	-- one purchase; returns ok, reason
	local function buy(toolName: string, price: number)
		local remote = gunBuyRemote()
		local money = data("Money")
		if not (remote and money) then return false, "gun store remote not found" end
		local canPay, why = true, nil
		if Library.Travel and Library.Travel.ensureCash then canPay, why = Library.Travel.ensureCash(price) end
		if not canPay then return false, why or "not enough money" end
		local before = money.Value
		pcall(remote.FireServer, remote, toolName, price)
		local deadline = os.clock() + BUY_CONFIRM_WAIT
		while money.Value >= before and os.clock() < deadline do task.wait(0.1) end
		if money.Value < before then return true end
		return false, "the store did not sell " .. toolName
	end
	local function canBuyWeapon(entry)
		if owns(entry.Name) then return false, "you already have a " .. entry.Name end
		local price, level = livePrice(entry, "Wall")
		local myLevel = data("Level")
		if myLevel and myLevel.Value < level then return false, ("%s needs level %d"):format(entry.Name, level) end
		return true, price
	end

	local busy = false
	local function run(fn)
		if busy then Library.Notify("Auto Buy: still busy with the last purchase") return end
		busy = true
		task.spawn(function()
			local ok, err = pcall(fn)
			if not ok then Log.warn("Auto Buy:", err) end
			busy = false
		end)
	end

	Library.AutoBuy = {
		BuyWeapon = function()
			run(function()
				local entry = GUN_BY_LABEL[Cfg["Auto Buy"]["Weapon"]]
				if not entry then Library.Notify("Auto Buy: pick a weapon") return end
				local okBuy, priceOrWhy = canBuyWeapon(entry)
				if not okBuy then Library.Notify("Auto Buy: " .. priceOrWhy) return end
				local ok, why = buy(entry.Name, priceOrWhy)
				Library.Notify(ok and ("Bought " .. entry.Name) or ("Auto Buy: " .. tostring(why)))
			end)
		end,
		BuyAll = function()
			run(function()
				local bought, skipped = 0, 0
				for _, entry in ipairs(GUN_STORE) do
					local okBuy, priceOrWhy = canBuyWeapon(entry)
					if okBuy then
						local ok, why = buy(entry.Name, priceOrWhy)
						if ok then
							bought = bought + 1
						else
							Library.Notify("Auto Buy stopped: " .. tostring(why))
							break
						end
					else
						skipped = skipped + 1
					end
				end
				Library.Notify(("Auto Buy: bought %d weapon%s, skipped %d (owned or level locked)"):format(bought, bought == 1 and "" or "s", skipped))
			end)
		end,
		BuyAmmo = function()
			run(function()
				local kind = Cfg["Auto Buy"]["Ammo"]
				local entry
				for _, a in ipairs(AMMO_STORE) do if a.Name == kind then entry = a end end
				if not entry then Library.Notify("Auto Buy: pick an ammo type") return end
				local amount = math.max(1, math.floor((tonumber(Cfg["Auto Buy"]["Ammo Amount"]) or 1) + 0.5))
				local price = livePrice(entry, "GWall")
				local got = 0
				for _ = 1, amount do
					local ok, why = buy(entry.Name .. " Ammo", price)
					if not ok then Library.Notify("Auto Buy stopped: " .. tostring(why)) break end
					got = got + 1
				end
				Library.Notify(("Bought %d %s Ammo"):format(got, entry.Name))
			end)
		end,
	}

	-- Auto Buy Ammo: keep one ammo box for every ammo type your guns use
	local lastCheck = 0
	RootMaid:Add(RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck < AUTO_AMMO_EVERY or busy then return end
		lastCheck = now
		if Cfg["Auto Buy"]["Auto Buy Ammo"] ~= true then return end
		local needed = {}
		for _, container in ipairs({ LP.Backpack, LP.Character }) do
			if container then
				for _, t in ipairs(container:GetChildren()) do
					if t:IsA("Tool") and CollectionService:HasTag(t, "Gun") then
						local kind = t:GetAttribute("AmmoType")
						if kind and not LP.Backpack:FindFirstChild(kind .. " Ammo") then needed[kind] = true end
					end
				end
			end
		end
		for _, entry in ipairs(AMMO_STORE) do
			if needed[entry.Name] then
				run(function()
					local ok, why = buy(entry.Name .. " Ammo", (livePrice(entry, "GWall")))
					if not ok then Log.warn("Auto Buy Ammo:", why) end
				end)
				return   -- one box per check
			end
		end
	end))
end

---------------------------------------------------------------------------
-- 9h. Auto Safe: the game's Storage remote ("Deposit" / "Grab", item name), the
--     same calls the safe UI makes; it works from anywhere (measured). Rules copied
--     from the safe UI: storable = guns (have Settings), the listed items, watches,
--     chains and seeds, never StrictTools; capacity 10 (+10 Double Storage, +5 / +10
--     tier, +5 per extra space); the UI waits 1.5 s between moves, so do we.
---------------------------------------------------------------------------
do
	local MOVE_GAP   = 1.6
	local AUTO_EVERY = 1
	local STORABLE_ITEMS = { "Military Vest", "Katana", "Knife", "Bat", "LockPick", "Crude Oil", "Refined Oil",
		"Rocket Ammo", "Heavy Ammo", "C4", "MentosBag", "Rush Juice", "DuffleBag" }
	local CollectionService = game:GetService("CollectionService")
	local okStrict, StrictTools = pcall(function() return require(game:GetService("ReplicatedStorage").Modules.StrictTools) end)
	if not okStrict or type(StrictTools) ~= "table" then StrictTools = {} end

	local function storageRemote()
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		return remotes and remotes:FindFirstChild("Storage")
	end
	local function safeItems()
		local d = LP:FindFirstChild("Data")
		return d and d:FindFirstChild("SafeItems")
	end
	local doubleStorage = nil   -- gamepass lookup yields, so it is done once
	local function capacity(): number
		local d = LP:FindFirstChild("Data")
		local cap = 10
		if doubleStorage == nil then
			local ok, owns = pcall(function() return game:GetService("MarketplaceService"):UserOwnsGamePassAsync(LP.UserId, 982099321) end)
			local passes = d and d:FindFirstChild("Passes")
			doubleStorage = (ok and owns) or (passes ~= nil and string.find(tostring(passes.Value), "DoubleStorage") ~= nil)
		end
		if doubleStorage then cap = cap + 10 end
		local tier = LP:GetAttribute("HasTier")
		if tier == 1 then cap = cap + 5 elseif type(tier) == "number" and tier >= 2 then cap = cap + 10 end
		local extra = d and d:FindFirstChild("ExtraSpaces")
		local n = extra and tonumber(string.split(tostring(extra.Value), " ")[2])
		if n and n > 0 then cap = cap + 5 * n end
		return cap
	end
	local function kindOf(tool): string?
		if table.find(StrictTools, tool.Name) then return nil end
		local name = tool.Name
		if CollectionService:HasTag(tool, "Gun") or tool:FindFirstChild("Settings") then return "Weapons" end
		if name:match("Watch") or name:match("Chain") or name:match("Seeds") or table.find(STORABLE_ITEMS, name) then return "Jewels & Items" end
		return nil
	end
	local function wanted(tool): boolean
		if not tool:IsA("Tool") then return false end
		local kind = kindOf(tool)
		if not kind then return false end
		local filter = Cfg["Auto Safe"]["Store"] or "Everything"
		return filter == "Everything" or filter == kind
	end

	local lastMove = 0
	local function move(action: string, name: string): boolean
		local remote = storageRemote()
		if not remote then return false end
		local wait = MOVE_GAP - (os.clock() - lastMove)
		if wait > 0 then task.wait(wait) end
		lastMove = os.clock()
		pcall(remote.FireServer, remote, action, name)
		return true
	end
	-- next backpack item to store (the tool in your hand stays in your hand); an item
	-- the safe refused is skipped for a while so Auto Safe does not retry it forever
	local REFUSED_SKIP = 30
	local refused = {}
	local function nextToStore()
		local now = os.clock()
		for _, t in ipairs(LP.Backpack:GetChildren()) do
			if wanted(t) and not (refused[t.Name] and now - refused[t.Name] < REFUSED_SKIP) then return t end
		end
		return nil
	end

	local busy = false
	local function run(fn)
		if busy then Library.Notify("Auto Safe: still moving items") return end
		busy = true
		task.spawn(function()
			local ok, err = pcall(fn)
			if not ok then Log.warn("Auto Safe:", err) end
			busy = false
		end)
	end
	local function storeAll(silent: boolean)
		local safe = safeItems()
		if not safe then return 0 end
		local stored = 0
		while true do
			if #safe:GetChildren() >= capacity() then
				if not silent then Library.Notify("Auto Safe: your safe is full") end
				break
			end
			local t = nextToStore()
			if not t then break end
			local name = t.Name
			local before = #safe:GetChildren()
			move("Deposit", name)
			local deadline = os.clock() + 2
			while #safe:GetChildren() <= before and os.clock() < deadline do task.wait(0.1) end
			if #safe:GetChildren() <= before then
				refused[name] = os.clock()
				if not silent then Library.Notify("Auto Safe: the safe did not take " .. name) end
				break
			end
			stored = stored + 1
		end
		return stored
	end

	Library.AutoSafe = {
		StoreAll = function()
			run(function()
				local n = storeAll(false)
				Library.Notify(("Auto Safe: stored %d item%s"):format(n, n == 1 and "" or "s"))
			end)
		end,
		TakeAll = function()
			run(function()
				local safe = safeItems()
				if not safe then return end
				local taken = 0
				for _, item in ipairs(safe:GetChildren()) do
					move("Grab", item.Name)
					taken = taken + 1
				end
				Library.Notify(("Auto Safe: took out %d item%s"):format(taken, taken == 1 and "" or "s"))
			end)
		end,
		-- one click in the safe list = take ONE of that item out. Clicks are queued and
		-- sent one at a time at the safe's pace, so fast clicking still works.
		Take = function(name: string)
			Library.AutoSafe._queue = Library.AutoSafe._queue or {}
			table.insert(Library.AutoSafe._queue, name)
			if Library.AutoSafe._working then return end
			Library.AutoSafe._working = true
			task.spawn(function()
				while #Library.AutoSafe._queue > 0 do
					local nextName = table.remove(Library.AutoSafe._queue, 1)
					local safe = safeItems()
					if safe and safe:FindFirstChild(nextName) then move("Grab", nextName) end
				end
				Library.AutoSafe._working = false
			end)
		end,
	}

	local lastCheck = 0
	RootMaid:Add(RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck < AUTO_EVERY or busy then return end
		lastCheck = now
		if Cfg["Auto Safe"]["Auto Safe"] ~= true or not nextToStore() then return end
		run(function() storeAll(true) end)
	end))

	-- live view of what is in the safe (the Auto Safe box's "In Safe" row + list)
	local function refreshSafeView()
		local panel = P("Auto Safe")
		if not (panel and panel.SafeCount and panel.SafeList) then return end
		local safe = safeItems()
		local counts, order, total = {}, {}, 0
		if safe then
			for _, item in ipairs(safe:GetChildren()) do
				total = total + 1
				if not counts[item.Name] then counts[item.Name] = 0; order[#order + 1] = item.Name end
				counts[item.Name] = counts[item.Name] + 1
			end
		end
		table.sort(order)
		local items = {}
		for _, name in ipairs(order) do
			items[#items + 1] = { text = counts[name] > 1 and (name .. " x" .. counts[name]) or name, key = name }
		end
		panel.SafeCount.Set(("%d / %d"):format(total, capacity()))
		panel.SafeList.Set(items, function(name) Library.AutoSafe.Take(name) end)   -- click = take one out
	end
	task.spawn(function()
		local d = LP:WaitForChild("Data", 10)
		local safe = d and d:WaitForChild("SafeItems", 10)
		if not safe then return end
		RootMaid:Add(safe.ChildAdded:Connect(refreshSafeView))
		RootMaid:Add(safe.ChildRemoved:Connect(refreshSafeView))
		refreshSafeView()
	end)
end

---------------------------------------------------------------------------
-- 9i. Menu backdrop: while the menu is open the world is lightly blurred, the
--     screen gets a soft blue tint and blue snow drifts down. It fades in / out
--     with the menu and does no work at all while the menu is closed.
---------------------------------------------------------------------------
do
	local TweenService = game:GetService("TweenService")
	local Lighting = game:GetService("Lighting")
	local BLUR_SIZE      = 10
	local TINT_COLOR     = Color3.fromRGB(10, 26, 62)
	local TINT_ALPHA     = 0.7                          -- tint transparency when fully shown
	local SNOW_COUNT     = 70
	local SNOW_COLORS    = { Color3.fromRGB(150, 196, 255), Color3.fromRGB(110, 165, 245), Color3.fromRGB(205, 228, 255) }
	local FADE           = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local backdrop = New("ScreenGui", { Name = "VisionWareBackdrop", IgnoreGuiInset = true, ResetOnSpawn = false,
		DisplayOrder = Screen.DisplayOrder - 1, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })   -- right under the menu
	pcall(function() backdrop.Parent = Screen.Parent end)
	if not backdrop.Parent then backdrop.Parent = LP:WaitForChild("PlayerGui") end
	RootMaid:Add(backdrop)

	local tint = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = TINT_COLOR, BackgroundTransparency = 1,
		BorderSizePixel = 0, Parent = backdrop })
	local snowLayer = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = backdrop })

	local blur = Instance.new("BlurEffect")
	blur.Name = "VisionWareBlur"
	blur.Size = 0
	blur.Parent = Lighting
	RootMaid:Add(blur)

	-- flakes: size, fall speed, sideways sway, and a base transparency each
	local flakes = {}
	for i = 1, SNOW_COUNT do
		local size = math.random(2, 5)
		local f = New("Frame", { Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
			BackgroundColor3 = SNOW_COLORS[math.random(1, #SNOW_COLORS)], BackgroundTransparency = 1, Parent = snowLayer })
		New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
		flakes[i] = {
			frame = f, x = math.random(), y = math.random(), size = size,
			speed = 35 + math.random() * 75 * (size / 5),       -- bigger flakes fall a bit faster
			sway = 6 + math.random() * 18, phase = math.random() * math.pi * 2, swaySpeed = 0.6 + math.random() * 1.2,
			alpha = 0.15 + math.random() * 0.45,
		}
	end

	local shown = 0            -- 0 = hidden, 1 = fully shown (drives the snow's fade)
	local drawnShown = -1      -- the 'shown' the flakes' transparency was last written for
	local animConn = nil
	local function step(dt)
		local size = backdrop.AbsoluteSize
		local w, h = size.X, size.Y
		if w <= 0 or h <= 0 then return end
		local t = os.clock()
		local fading = shown ~= drawnShown                  -- transparency only changes while fading
		drawnShown = shown
		for i = 1, #flakes do
			local fl = flakes[i]
			fl.y = fl.y + (fl.speed * dt) / h
			if fl.y > 1.02 then fl.y = -0.02; fl.x = math.random() end
			local x = fl.x * w + math.sin(t * fl.swaySpeed + fl.phase) * fl.sway
			fl.frame.Position = UDim2.fromOffset(x, fl.y * h)
			if fading then fl.frame.BackgroundTransparency = 1 - (1 - fl.alpha) * shown end
		end
	end
	local fadeToken = 0
	local function setOpen(open: boolean)
		fadeToken = fadeToken + 1
		local token = fadeToken
		TweenService:Create(tint, FADE, { BackgroundTransparency = open and TINT_ALPHA or 1 }):Play()
		TweenService:Create(blur, FADE, { Size = open and BLUR_SIZE or 0 }):Play()
		if open and not animConn then
			animConn = RunService.RenderStepped:Connect(step)
		end
		-- snow fades with the same timing, then the animation stops while closed
		local from, start = shown, os.clock()
		task.spawn(function()
			while token == fadeToken do
				local a = math.clamp((os.clock() - start) / FADE.Time, 0, 1)
				shown = from + ((open and 1 or 0) - from) * a
				if a >= 1 then break end
				RunService.RenderStepped:Wait()
			end
			if token == fadeToken and not open and animConn then
				animConn:Disconnect(); animConn = nil
				for i = 1, #flakes do flakes[i].frame.BackgroundTransparency = 1 end
				drawnShown = -1
			end
		end)
	end
	RootMaid:Add(Holder:GetPropertyChangedSignal("Visible"):Connect(function() setOpen(Holder.Visible) end))
	RootMaid:Add(function() fadeToken = fadeToken + 1; if animConn then animConn:Disconnect() end end)
	setOpen(Holder.Visible)
end

---------------------------------------------------------------------------
-- 9j. Arcade
--   Punching bag: the bag UI sends Remotes.Arcade:FireServer("PunchingBag",
--   strength 0-999, bag) when you punch; with Punching Bag Score on, the strength
--   in that call is replaced by Punch Amount. The hook is installed once per game
--   session and reads getgenv().VW_ArcadePunch, so reloading the menu never stacks it.
--   Bird game: runs entirely on your client and only feeds the "New Record" popup;
--   with Bird Game Score on, pressing Play wins at once with Bird Amount.
---------------------------------------------------------------------------
do
	local BIRD_SHOW_TIME = 2
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- punching bag
	-- Punch Amount is a text box: digits only, any size (commas / spaces are ignored)
	local function punchAmount(): number
		local digits = tostring(Cfg.Arcade["Punch Amount"] or ""):gsub("[^%d]", "")
		return tonumber(digits) or 999
	end
	local function syncPunch()
		getgenv().VW_ArcadePunch = (Cfg.Arcade["Punching Bag Score"] == true) and punchAmount() or nil
	end
	-- the hook sees every method call the game makes, so it is only installed the first
	-- time the option is turned on (once per game session, never stacked), and the
	-- cheap "is it the arcade remote" test comes first
	local function installPunchHook()
		if getgenv().VW_ArcadeHooked or type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local arcadeRemote = remotes and remotes:FindFirstChild("Arcade")
		if not arcadeRemote then return end
		getgenv().VW_ArcadeHooked = true
		local genv = getgenv()
		local old
		old = hookmetamethod(game, "__namecall", function(self, ...)
			if self == arcadeRemote then
				local amount = genv.VW_ArcadePunch
				if amount and getnamecallmethod() == "FireServer" then
					local args = table.pack(...)
					if args[1] == "PunchingBag" then
						args[2] = amount
						return old(self, table.unpack(args, 1, args.n))
					end
				end
			end
			return old(self, ...)
		end)
	end
	local function onPunchOption()
		syncPunch()
		if getgenv().VW_ArcadePunch then installPunchHook() end
	end
	P("Arcade"):On("Punching Bag Score", onPunchOption)
	P("Arcade"):On("Punch Amount", onPunchOption)
	onPunchOption()
	RootMaid:Add(function() getgenv().VW_ArcadePunch = nil end)

	-- bird game: the arcade machines keep the game functions in a table captured by
	-- their prompt's Triggered handler (PlayerScripts.Arcade.GameModes); its Bird
	-- entry is swapped for an instant win while the option is on
	local gameTable, originalBird = nil, nil
	local function findGameTable()
		if gameTable then return gameTable end
		local arcade = workspace:FindFirstChild("Arcade")
		local modes = arcade and arcade:FindFirstChild("GameModes")
		if not (modes and type(getconnections) == "function" and debug.getupvalues) then return nil end
		for _, prompt in ipairs(modes:GetDescendants()) do
			if prompt:IsA("ProximityPrompt") then
				for _, conn in ipairs(getconnections(prompt.Triggered)) do
					local fn = conn.Function
					if fn then
						local ok, ups = pcall(debug.getupvalues, fn)
						if ok then
							for _, up in pairs(ups) do
								if type(up) == "table" and type(rawget(up, "Bird")) == "function" then gameTable = up; return up end
							end
						end
					end
				end
			end
		end
		return nil
	end
	local function fakeBird()
		local amount = math.floor(tonumber(Cfg.Arcade["Bird Amount"]) or 100)
		local main = LP.PlayerGui:FindFirstChild("Main")
		local bird = main and main:FindFirstChild("MiniGames") and main.MiniGames:FindFirstChild("Bird")
		local frame = bird and bird:FindFirstChild("GameFrame")
		local label = frame and frame:FindFirstChild("Label")
		if frame and label then
			frame.Visible = true
			label.Text = ("YOU WIN! SCORE: %d"):format(amount)
			label.TextColor3 = Color3.fromRGB(0, 255, 0)
			task.wait(BIRD_SHOW_TIME)
			frame.Visible = false
		end
		return true, amount
	end
	local function syncBird()
		local t = findGameTable()
		if not t then return end
		if not originalBird then originalBird = t.Bird end
		t.Bird = (Cfg.Arcade["Bird Game Score"] == true) and fakeBird or originalBird
	end
	P("Arcade"):On("Bird Game Score", syncBird)
	task.delay(4, syncBird)          -- the arcade script sets its table up ~3 s after joining
	RootMaid:Add(function() if gameTable and originalBird then gameTable.Bird = originalBird end end)
end

---------------------------------------------------------------------------
-- 9k. Streamer: Hide Level. While Hide Level is on (with or without Streamer Mode),
--     the level badge on your overhead tag (Head.Overhead.LevelIcon, number in its
--     "Level" label) shows the VisionWare "V" logo and the number is hidden.
--     Everything is put back when it goes off. Checked twice a second so it follows
--     respawns and a rebuilt tag.
---------------------------------------------------------------------------
do
	local CHECK_EVERY = 0.5
	local LOGO_TRANSPARENCY = 0.25
	local saved = setmetatable({}, { __mode = "k" })   -- LevelIcon -> its original look

	local function myBadge()
		local c = LP.Character
		local head = c and c:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("Overhead")
		local icon = tag and tag:FindFirstChild("LevelIcon")
		return (icon and icon:IsA("ImageLabel")) and icon or nil
	end
	local function apply(icon)
		if not saved[icon] then
			local num = icon:FindFirstChild("Level")
			saved[icon] = { Image = icon.Image, ScaleType = icon.ScaleType, ImageTransparency = icon.ImageTransparency,
				Num = num, NumText = num and num.TextTransparency, NumStroke = num and num.TextStrokeTransparency }
		end
		if icon.Image ~= ASSETS.Logo then icon.Image = ASSETS.Logo end
		if icon.ScaleType ~= Enum.ScaleType.Fit then icon.ScaleType = Enum.ScaleType.Fit end
		if icon.ImageTransparency ~= LOGO_TRANSPARENCY then icon.ImageTransparency = LOGO_TRANSPARENCY end   -- the badge is drawn at 0.6, too faint for the logo
		local num = saved[icon].Num
		if num and num.Parent then
			if num.TextTransparency ~= 1 then num.TextTransparency = 1 end
			if num.TextStrokeTransparency ~= 1 then num.TextStrokeTransparency = 1 end
		end
	end
	local function restore(icon)
		local s = saved[icon]
		if not s then return end
		saved[icon] = nil
		if not icon.Parent then return end
		icon.Image, icon.ScaleType, icon.ImageTransparency = s.Image, s.ScaleType, s.ImageTransparency
		if s.Num and s.Num.Parent then
			s.Num.TextTransparency = s.NumText
			s.Num.TextStrokeTransparency = s.NumStroke
		end
	end
	local function restoreAll() for icon in pairs(saved) do pcall(restore, icon) end end

	local last = 0
	RootMaid:Add(RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - last < CHECK_EVERY then return end
		last = now
		local S = Cfg.Streamer
		local want = S and S["Hide Level"] == true      -- works on its own, Streamer Mode not required
		if want then
			local icon = myBadge()
			if icon then pcall(apply, icon) end
		elseif next(saved) then
			restoreAll()
		end
	end))
	RootMaid:Add(restoreAll)
end

---------------------------------------------------------------------------
-- 9l. Farm Terminal (Autofarm tab): how long any farm toggle has been on, and the
--     money made while farming. Cash + bank are compared once a second, so moving
--     money between them (Auto Deposit, withdrawals for a scooter) nets out; money
--     spent (rentals, a Ruger) counts as Spent. Each change is logged with the farm
--     that held the turn.
---------------------------------------------------------------------------
do
	local FARMS = { "Box Job", "Oil Rig", "Airdrops", "Shops" }
	local TURN_NAMES = { box = "Box Job", shop = "Shops", air = "Airdrops", oil = "Oil Rig" }
	local LOG_LINES = 5
	local stats = { time = 0, earned = 0, spent = 0, log = {} }
	local lastWorth = nil
	local wasActive = false

	local function netWorth(): number?
		local d = LP:FindFirstChild("Data")
		local m, b = d and d:FindFirstChild("Money"), d and d:FindFirstChild("Bank")
		if not (m and b) then return nil end
		return (tonumber(m.Value) or 0) + (tonumber(b.Value) or 0)
	end
	local function farming(): boolean
		if not En("Farms") then return false end
		for _, name in ipairs(FARMS) do if Cfg.Farms[name] == true then return true end end
		return false
	end
	local function clock(sec: number): string
		sec = math.floor(sec)
		return ("%02d:%02d:%02d"):format(sec // 3600, (sec // 60) % 60, sec % 60)
	end
	local function money(n: number): string
		local s = tostring(math.floor(math.abs(n)))
		s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		return (n < 0 and "-$" or "$") .. s
	end
	local function addLog(line: string)
		local mm = math.floor(stats.time)
		table.insert(stats.log, ("%02d:%02d %s"):format(mm // 60, mm % 60, line))
		while #stats.log > LOG_LINES do table.remove(stats.log, 1) end
	end
	-- cooldowns / status of every farm ------------------------------------------
	local REGISTER_MIN = 2500           -- the game refuses to let a register be robbed under this
	local function shopsLine(): string
		local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Registers")
		if not folder then return "Shops    no registers loaded" end
		-- status only (no amounts / timers): READY, wait (still filling up) or cooldown
		local parts = {}
		for _, r in ipairs(folder:GetChildren()) do
			local a, cd = r:FindFirstChild("Amount"), r:FindFirstChild("Cooldown")
			if a then
				if cd and cd.Value then parts[#parts + 1] = "cooldown"
				elseif a.Value >= REGISTER_MIN then parts[#parts + 1] = "READY"
				else parts[#parts + 1] = "wait" end
			end
		end
		return "Shops    " .. (#parts > 0 and table.concat(parts, " | ") or "none")
	end
	local function airdropLine(): string
		local spawns = workspace:FindFirstChild("AirdropSpawns")
		if not spawns then return "Airdrop  -" end
		local map, veh = workspace:FindFirstChild("Map"), workspace:FindFirstChild("Vehicles")
		for _, s in ipairs(spawns:GetChildren()) do
			local sp = s:FindFirstChild("AirdropSpawn")
			if sp then
				for _, part in ipairs(workspace:GetPartBoundsInRadius(sp.Position, 80)) do
					local pr = part:FindFirstChildWhichIsA("ProximityPrompt", true)
					if pr and pr.Enabled and not (map and pr:IsDescendantOf(map)) and not (veh and pr:IsDescendantOf(veh))
						and not pr:FindFirstAncestor("Dumpster") then
						return "Airdrop  OUT at " .. s.Name
					end
				end
			end
		end
		return "Airdrop  none out"
	end
	local function oilLine(): string
		local job = workspace:FindFirstChild("OilJob")
		if not job then return "Oil Rig  -" end
		local total, ready = 0, 0
		for _, pump in ipairs(job:GetChildren()) do
			if pump.Name == "Pump" then
				total = total + 1
				local lbl = pump:FindFirstChild("TextLabel", true)
				if lbl and tostring(lbl.Text):upper():find("AVAILABLE") then ready = ready + 1 end
			end
		end
		return total > 0 and ("Oil Rig  %d/%d pumps available"):format(ready, total) or "Oil Rig  not loaded"
	end

	-- the cooldown lines search the map (the airdrop one scans every part near each
	-- drop spot, ~15 ms), so they are only worked out while you can see them: menu
	-- open on the Autofarm tab, at most every COOLDOWN_EVERY seconds
	local COOLDOWN_EVERY = 3
	local lastCooldowns = -math.huge
	local function render()
		local t = P("Farm Terminal")
		if not (t and t.Time) then return end
		local page = Library.Pages and Library.Pages["Autofarm"]
		local now = os.clock()
		if Library.IsOpen() and page and page.Visible and now - lastCooldowns >= COOLDOWN_EVERY then
			lastCooldowns = now
			t.Cooldowns.Set(table.concat({ shopsLine(), airdropLine(), oilLine(), "Box Job  always available" }, "\n"))
		end
		t.Time.Set(clock(stats.time))
		t.Earned.Set(money(stats.earned))
		t.Spent.Set(money(stats.spent))
		t.Net.Set(money(stats.earned - stats.spent))
		t.Log.Set(#stats.log > 0 and table.concat(stats.log, "\n") or "> waiting for a farm to start")
	end

	Library.FarmStats = {
		Reset = function()
			stats.time, stats.earned, stats.spent = 0, 0, 0
			table.clear(stats.log)
			lastWorth = netWorth()
			render()
		end,
	}

	local lastTick = os.clock()
	RootMaid:Add(RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastTick < 1 then return end
		local dt = now - lastTick
		lastTick = now
		local active = farming()
		local worth = netWorth()
		if active then
			if not wasActive then addLog("farming started") end
			stats.time = stats.time + dt
			if worth and lastWorth and worth ~= lastWorth then
				local delta = worth - lastWorth
				local turn = Library.FarmTurn and Library.FarmTurn.owner
				local who = (turn and TURN_NAMES[turn]) or "Farm"
				if delta > 0 then stats.earned = stats.earned + delta else stats.spent = stats.spent - delta end
				addLog(("%s %s%s"):format(who, delta > 0 and "+" or "", money(delta)))
			end
		elseif wasActive then
			addLog("farming stopped")
		end
		wasActive = active
		lastWorth = worth
		render()
	end))
end

---------------------------------------------------------------------------
-- 9m. World: Render Entire Map. The game uses StreamingEnabled, so only the area
--     around you is loaded. While on, the whole map is requested from the server
--     in a grid (RequestStreamAroundAsync, your character is not moved) and the
--     sweep repeats so far areas that stream back out are loaded again. Costs FPS
--     and memory; turning it off just stops the sweeps and the game unloads far
--     parts on its own.
---------------------------------------------------------------------------
do
	-- The server stops answering if it is flooded with requests, so a sweep only asks
	-- for grid spots that have (almost) nothing loaded, one at a time with a gap, and
	-- never waits more than REQUEST_WAIT on a request that does not come back.
	local MAP_MIN, MAP_MAX = Vector3.new(-700, 60, -1950), Vector3.new(1600, 60, 800)   -- map extent + margin
	local STEP          = 250     -- grid spacing (studs)
	local LOADED_RADIUS = 90      -- a spot counts as loaded when this area has parts...
	local LOADED_PARTS  = 25      -- ...at least this many
	local REQUEST_GAP   = 0.4     -- seconds between requests
	local REQUEST_WAIT  = 4       -- give up waiting on a request after this
	local SWEEP_EVERY   = 60      -- seconds between sweeps while on
	local token = 0

	local function enabled() return Cfg.World and Cfg.World["Render Entire Map (-FPS)"] == true end
	local function loaded(spot: Vector3): boolean
		local params = OverlapParams.new()
		params.MaxParts = LOADED_PARTS
		return #workspace:GetPartBoundsInBox(CFrame.new(spot), Vector3.new(LOADED_RADIUS * 2, 600, LOADED_RADIUS * 2), params) >= LOADED_PARTS
	end
	local function sweep(my: number)
		for x = MAP_MIN.X, MAP_MAX.X, STEP do
			for z = MAP_MIN.Z, MAP_MAX.Z, STEP do
				if token ~= my or not enabled() then return end
				local spot = Vector3.new(x, MAP_MIN.Y, z)
				if not loaded(spot) then
					local done = false
					task.spawn(function()
						pcall(function() LP:RequestStreamAroundAsync(spot, REQUEST_WAIT) end)
						done = true
					end)
					local t = os.clock()
					while not done and os.clock() - t < REQUEST_WAIT and token == my do task.wait(0.1) end
					task.wait(REQUEST_GAP)
				end
			end
		end
	end
	local function start()
		token = token + 1
		local my = token
		task.spawn(function()
			while token == my and enabled() do
				sweep(my)
				local t = os.clock()
				while token == my and enabled() and os.clock() - t < SWEEP_EVERY do task.wait(0.5) end
			end
		end)
	end
	P("World"):On("Render Entire Map (-FPS)", function(v)   -- also fires once with the loaded value
		if v then start() else token = token + 1 end
	end)
	RootMaid:Add(function() token = token + 1 end)
end

---------------------------------------------------------------------------
-- 9n. Teleports tab: the place lists (every main area, dealer, buyer and store,
--     measured in game). Clicking one takes you there by scooter teleport onto the
--     green parking strip closest to it (see go below).
---------------------------------------------------------------------------
do
	local Tele = {}
	Library.Teleports = Tele
	-- leftover sky platform from an older version
	for _, c in ipairs(workspace:GetChildren()) do
		if c.Name == "VisionWareSky" then c:Destroy() end
	end

	-- place lists: { text, pos (fallback), live = fn() -> Vector3? }. Filled in below.
	-- Positions measured in game by flying the whole map and reading every prompt,
	-- NPC and building sign (NPC entries are their prompt; you are stood in front).
	local LOCATIONS, DEALERS = {}, {}
	Tele.Locations, Tele.Dealers = LOCATIONS, DEALERS
	local function add(list, text: string, x: number, y: number, z: number)
		table.insert(list, { text = text, pos = Vector3.new(x, y, z) })
	end
	-- "nearest X": the closest of several spots to you, worked out when clicked
	local function addNearest(list, text: string, spots)
		table.insert(list, { text = text, pos = spots[1], live = function()
			local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			if not hrp then return nil end
			local best, bestD
			for _, s in ipairs(spots) do
				local d = (s - hrp.Position).Magnitude
				if not bestD or d < bestD then best, bestD = s, d end
			end
			return best
		end })
	end
	local function V(t) local out = {} for i, p in ipairs(t) do out[i] = Vector3.new(p[1], p[2], p[3]) end return out end

	-- main areas
	for i, p in ipairs(Library.ShopRegisters) do
		table.insert(LOCATIONS, { text = ("🏪 Shop %d (Gas Station)"):format(i), pos = p })
	end
	add(LOCATIONS, "🏦 Bank (The Vault)",       395, 52, 95)
	add(LOCATIONS, "🏛️ Museum",                 1371.9, 54.4, -118.3)
	add(LOCATIONS, "🛥️ Yacht",                  1024.5, 78.4, -1836.9)
	add(LOCATIONS, "💎 Jewelry Store",          -9.9, 52.1, -253.7)
	add(LOCATIONS, "🛢️ Oil Rig",                -298, 82, -1678)
	add(LOCATIONS, "🏭 Oil Refinery",           -127.8, 68.8, 413.3)
	add(LOCATIONS, "🕹️ Arcade",                 549.4, 53, -445.8)
	add(LOCATIONS, "🎡 Lucky Wheel",            560.9, 53, -429.5)
	add(LOCATIONS, "🎁 Limited Crate",          555.6, 50, -418)
	add(LOCATIONS, "🎯 Shooting Range",         622.4, 52, -409.4)
	add(LOCATIONS, "💪 Gym",                    122.6, 52.3, -423.3)
	add(LOCATIONS, "🧊 The Ice (Club)",         182.6, 52, 149.5)
	add(LOCATIONS, "⚔️ The Arena",              116.3, 55, -228.7)
	add(LOCATIONS, "🏥 Hospital",               1363.8, 55.1, -393.4)
	add(LOCATIONS, "🏢 Apartments",             387.9, 52, -501.1)
	add(LOCATIONS, "🏙️ Street Life HQ",         743.8, 55, -746.4)
	add(LOCATIONS, "⚓ Pier",                   842.8, 55, -809.7)
	add(LOCATIONS, "🏀 Court",                  563.1, 55, -637.6)
	add(LOCATIONS, "🌱 Plant Garden",           1040, 52.3, -420)
	add(LOCATIONS, "🎁 Rewards",                567.6, 51.5, -64.1)
	add(LOCATIONS, "📦 Box Job",                202.2, 49.1, 340.1)
	add(LOCATIONS, "🚚 Delivery Job",           517.3, 51.8, -394.4)
	add(LOCATIONS, "🍦 Frosty Job",             893.7, 53.1, -473.2)
	add(LOCATIONS, "🧹 Cleaning Job",           271.3, 49.1, -168.1)
	add(LOCATIONS, "🏴 North Zone",             773.2, 52.2, -212.2)
	add(LOCATIONS, "🏴 South Zone",             181.5, 52.2, 73.8)
	add(LOCATIONS, "🏴 East Zone",              779.9, 52.1, 134.2)
	add(LOCATIONS, "🏴 West Zone",              544, 98.3, -529.5)

	-- dealers, buyers and stores
	add(DEALERS, "🔫 Gun Store (City)",         669.3, 52, -387.4)
	add(DEALERS, "🔫 Gun Store (North)",        26, 70, 610.1)
	add(DEALERS, "🚗 Car Dealer",               567.4, 51.9, 56.9)
	add(DEALERS, "🛥️ Boat Dealer",              814.5, 52.3, -979)
	add(DEALERS, "💰 Loot Buyer",               268.2, 51.7, 296.6)
	add(DEALERS, "🗿 Object Buyer",             -107.3, 69.7, 399.5)
	add(DEALERS, "🔫 Gun Buyer (sell 50%)",     1057.9, 53.7, -121.2)
	add(DEALERS, "🔧 Car Buyer (chop car)",     1096.5, 69.7, 608.9)
	add(DEALERS, "🕶️ Black Market",             272.3, 51.8, -687.9)
	add(DEALERS, "🧳 Merchant",                 865.2, 51.8, -714.9)
	add(DEALERS, "📦 Supplies",                 1058.5, 52, -599.6)
	add(DEALERS, "🥪 Deli",                     554.6, 52.3, -49.7)
	add(DEALERS, "🍗 Chicken Shop",             368.4, 52.1, -60.7)
	add(DEALERS, "👟 Drip",                     303.8, 52.1, -68.4)
	add(DEALERS, "👕 Clothing",                 653.5, 52.2, -72.2)
	add(DEALERS, "🎭 Mask Shop",                178.8, 51.7, -56.3)
	add(DEALERS, "🖋️ Tattoo Store",             948.5, 69.7, 579.5)
	addNearest(DEALERS, "🛵 Nearest Scooter Rental", V({ { 311.6, 52.2, -95.5 }, { 542.9, 52.1, -95.4 }, { 888, 52.1, 182 },
		{ 1249.1, 52.2, -184.8 }, { 826.3, 69.9, 566.7 }, { 871.4, 40.5, -817.6 }, { 1279.3, 52.6, -555.2 }, { -67.5, 70, 88.4 }, { 103.3, 69.9, 563.6 } }))
	addNearest(DEALERS, "🏄 Nearest Surf Board Rental", V({ { -253.4, 40, -1651.5 }, { 893.9, 40, -1865.1 }, { 873, 40, -1053.8 }, { -155.7, 40.1, -642 } }))
	addNearest(DEALERS, "🏧 Nearest ATM", V({ { 572.1, 52.2, 65.3 }, { 404.6, 52.1, -95.9 }, { -86.7, 70, 38.1 }, { 613.9, 52.1, -34.7 },
		{ 620.5, 52.2, -389.3 }, { 378.3, 53.1, 95.2 }, { 44.6, 70.1, 577.7 }, { 505.8, 52.2, -411.4 }, { -31.8, 52.2, -440.9 },
		{ 862.7, 52, -672.7 }, { 415.2, 52.1, 75.6 }, { 118.8, 52.4, -411.3 }, { 616.3, 52, -191.5 }, { 673.4, 52.2, -377.9 },
		{ 267.2, 52, 150.8 }, { 873.5, 52.2, 185.9 }, { 630.1, 52.4, -84.3 }, { 561.6, 52.2, -418.6 }, { 197.7, 52, 306.2 }, { 427.4, 70, 571.4 } }))
	addNearest(DEALERS, "🔧 Nearest Garage Station", V({ { 1132.1, 53, -653.1 }, { 1413.8, 55.7, 151 }, { -29, 53.2, -212.4 },
		{ 1220.2, 53, 210.8 }, { 934.4, 41.6, -817.4 }, { 1214.8, 70.8, 575 }, { 617.6, 53.3, -507.7 }, { 1445.9, 53.1, -179.5 },
		{ 1220.2, 53, 75.6 }, { 867, 71, 611.2 }, { 159.7, 70.7, 611.5 }, { 1058.8, 53.1, -523.8 }, { -133.3, 71, 372.4 } }))
	addNearest(DEALERS, "🛥️ Nearest Boat Station", V({ { -196, 41, -1691.2 }, { 836.8, 41, -1824.7 }, { -115.2, 41.1, -657.6 }, { 834, 41, -1112.4 } }))

	-- the green parking strip (Map.ParkingSpots) closest to a place: the point on the
	-- strip level with the place, the strip's direction, and where you get off (on
	-- the curb beside it, on the place's side). nil when none is within reach.
	local CURB_MAX = 150
	local function nearestCurb(place: Vector3)
		local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ParkingSpots")
		if not folder then return nil end
		local best, bestD
		for _, p in ipairs(folder:GetChildren()) do
			if p:IsA("BasePart") then
				-- distance to the strip itself (not its centre: some are 130+ long)
				local rel = p.CFrame:PointToObjectSpace(place)
				local cx = math.clamp(rel.X, -p.Size.X / 2, p.Size.X / 2)
				local cz = math.clamp(rel.Z, -p.Size.Z / 2, p.Size.Z / 2)
				local d = (p.CFrame:PointToWorldSpace(Vector3.new(cx, 0, cz)) - place).Magnitude
				if not bestD or d < bestD then best, bestD = p, d end
			end
		end
		if not best or bestD > CURB_MAX then return nil end
		local cf, size = best.CFrame, best.Size
		local longX = size.X >= size.Z
		local along = longX and cf.RightVector or cf.LookVector
		along = Vector3.new(along.X, 0, along.Z).Unit
		local half = (longX and size.X or size.Z) / 2
		local top = best.Position + Vector3.new(0, size.Y / 2, 0)
		local t = math.clamp((place - top):Dot(along), -half + 3, math.max(-half + 3, half - 3))
		local dest = top + along * t
		local toPlace = Vector3.new(place.X - dest.X, 0, place.Z - dest.Z)
		local perp = toPlace - along * toPlace:Dot(along)          -- sideways, towards the place
		perp = perp.Magnitude > 0.1 and perp.Unit or Vector3.new(-along.Z, 0, along.X)
		return dest, along, dest + perp * 4, best
	end

	-- go to a place: get on your scooter (yours is brought over, or a rental), teleport
	-- onto the green parking strip closest to the place, get off on the curb beside it
	-- facing the place; the scooter then parks itself (Travel.scooterTrip)
	local busy = false
	local function go(label: string, place: Vector3)
		if busy then Library.Notify("Already teleporting") return end
		local Travel = Library.Travel
		if not (Travel and Travel.scooterTrip) then return end
		busy = true
		Library.Notify("Teleporting: " .. label)
		task.spawn(function()
			local ok, err = pcall(function()
				local vehicle, why = Travel.getOnScooter()
				if not vehicle then error(why or "could not get on your scooter", 0) end
				-- a far place's area is not loaded yet (so its own strip is missing and a
				-- loaded one further off would be picked): hop the scooter, you on it, 60
				-- above the place and hold it there until the area has loaded
				local hrp0 = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
				local far = not hrp0 or (hrp0.Position - place).Magnitude > 250
				local dest, along, standAt, strip = nil, nil, nil, nil
				if not far then dest, along, standAt, strip = nearestCurb(place) end
				if not dest then
					local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
					local seat = hum and hum.SeatPart
					if seat then
						Library.Travel.freezeVehicle(vehicle, false)  -- a frozen move would not reach the server
						vehicle:PivotTo(CFrame.new(place + Vector3.new(0, 60, 0)) * vehicle:GetPivot().Rotation)
						Library.Travel.settleFreeze(vehicle)        -- held in the air while the area loads
						local t = os.clock()
						repeat
							task.wait(0.25)
						until (os.clock() - t > 0.75 and #workspace:GetPartBoundsInRadius(place, 60) >= 25) or os.clock() - t > 3
						dest, along, standAt, strip = nearestCurb(place)
						-- (the trip unfreezes it before it moves on)
					end
				end
				if not dest then dest, standAt = place, place end    -- still no green strip near: the place itself
				local arrived, why2 = Travel.scooterTrip(vehicle, dest, standAt, nil, along, strip, place)
				if not arrived then error(why2 or "the teleport failed", 0) end
			end)
			busy = false
			if ok then Library.Notify("Arrived: " .. label) else Library.Notify("Teleport failed: " .. tostring(err)) end
		end)
	end
	local function entryPos(e): Vector3
		local live = e.live and select(2, pcall(e.live))
		return (typeof(live) == "Vector3" and live) or e.pos
	end
	Tele.Go, Tele.NearestCurb = go, nearestCurb

	function Tele.Refresh()
		local function fill(panelName: string, list)
			local p = P(panelName)
			if not (p and p.List) then return end
			local items = {}
			for i, e in ipairs(list) do items[i] = { text = e.text, key = i } end
			p.List.Set(items, function(i)
				local e = list[i]
				if e then go(e.text, entryPos(e)) end
			end)
		end
		fill("Locations", LOCATIONS)
		fill("Dealers & Buyers", DEALERS)
	end

	-- walk the path-found route to your scooter (or to the nearest rental and rent
	-- one); with Show Path on you can watch the route it plans
	local walking = false
	function Tele.WalkToScooter()
		if walking then Library.Notify("Already walking to the scooter") return end
		local Travel = Library.Travel
		if not (Travel and Travel.toScooter) then return end
		walking = true
		task.spawn(function()
			local ok, vehicle, why = pcall(Travel.toScooter)
			walking = false
			if ok and vehicle then
				Library.Notify("At your scooter")
			else
				Library.Notify("Walk to scooter failed: " .. tostring((ok and (why or "no route")) or vehicle))
			end
		end)
	end

	-- View Scooter: the camera follows your scooter (wherever it is parked); click
	-- again to come back. Ends by itself if the scooter goes away or you respawn.
	local viewing = nil                                   -- the scooter part being watched
	local viewConns = {}
	local function viewButtonText(t: string)
		local p = P("Teleport")
		if p and p.ViewButton then p.ViewButton.SetText(t) end
	end
	local function stopViewing(quiet: boolean?)
		for _, c in ipairs(viewConns) do c:Disconnect() end
		table.clear(viewConns)
		if viewing then
			viewing = nil
			local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
			if hum then Camera.CameraSubject = hum end
			if not quiet then Library.Notify("Stopped viewing your scooter") end
		end
		viewButtonText("View Scooter")
	end
	local function myScooter()
		local folder = workspace:FindFirstChild("Vehicles")
		if not folder then return nil end
		for _, v in ipairs(folder:GetChildren()) do
			if (v:GetAttribute("Owner") == LP.Name and v:GetAttribute("CarType") == "Scooter") or v.Name:find(LP.Name, 1, true) then return v end
		end
		return nil
	end
	function Tele.ViewScooter()
		if viewing then stopViewing() return end
		local scooter = myScooter()
		local part = scooter and (scooter:FindFirstChild("DriveSeat") or scooter.PrimaryPart or scooter:FindFirstChildWhichIsA("BasePart", true))
		if not part then Library.Notify("You have no scooter out") return end
		-- spectating someone keeps pulling the camera back to them: stop that first
		local subject = Camera.CameraSubject
		local myHum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
		if subject and subject ~= myHum and subject:IsA("Humanoid") and Library.Spectate then Library.Spectate(nil) end
		viewing = part
		Camera.CameraSubject = part
		viewButtonText("Stop Viewing")
		local d = (part.Position - (LP.Character and LP.Character:GetPivot().Position or part.Position)).Magnitude
		Library.Notify(("Viewing your scooter (%d studs away)"):format(math.floor(d)))
		table.insert(viewConns, scooter.AncestryChanged:Connect(function()
			if not scooter:IsDescendantOf(workspace) then stopViewing() Library.Notify("Your scooter is gone") end
		end))
		table.insert(viewConns, LP.CharacterAdded:Connect(function() stopViewing(true) end))
		-- something else (spectate, freecam) took the camera: this view is over
		table.insert(viewConns, Camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
			if viewing and Camera.CameraSubject ~= viewing then stopViewing(true) end
		end))
	end
	RootMaid:Add(function() stopViewing(true) end)

	Tele.Refresh()
end

---------------------------------------------------------------------------
-- 10. teardown
---------------------------------------------------------------------------
-- register existing players last so every onCharacterReady hook is in place
for _, plr in ipairs(Players:GetPlayers()) do addPlayer(plr) end

do
	local oldDestroy = Library.Destroy
	Library.Destroy = function()
		RootMaid:Clean()
		oldDestroy()
	end
end

local env = (getgenv and getgenv()) or _G
env.VisionWare = Library
return Library
