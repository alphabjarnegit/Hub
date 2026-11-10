-- UILibrary.lua
-- ModuleScript (z. B. in ReplicatedStorage), wird von einem LocalScript benutzt.
--
-- Beispiel:
--   local UILibrary = require(game.ReplicatedStorage.UILibrary)
--   local window = UILibrary.CreateWindow("Dev Panel", UDim2.fromOffset(420, 300))
--   local main = window:AddTab("Main")
--   window:AddButton(main, "Hallo", function() print("Hallo") end)
--   -- später: window:Destroy()

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UILibrary = {}

local Window = {}
Window.__index = Window

-- Farben und Maße an einer Stelle
local THEME = {
	Background = Color3.fromRGB(30, 30, 34),
	Header = Color3.fromRGB(40, 40, 46),
	TabBar = Color3.fromRGB(36, 36, 41),
	Tab = Color3.fromRGB(46, 46, 53),
	TabActive = Color3.fromRGB(70, 70, 82),
	Button = Color3.fromRGB(52, 52, 60),
	ButtonHover = Color3.fromRGB(66, 66, 76),
	Close = Color3.fromRGB(200, 60, 60),
	Text = Color3.fromRGB(235, 235, 240),
	TextDim = Color3.fromRGB(170, 170, 180),
	Font = Enum.Font.GothamMedium,
	HeaderHeight = 32,
	TabBarHeight = 28,
	ButtonHeight = 30,
	Padding = 8,
	Corner = 6,
}

---------------------------------------------------------------------------
-- Interne Helfer
---------------------------------------------------------------------------

-- Erstellt eine Instanz und setzt Eigenschaften. Parent wird zuletzt gesetzt,
-- damit Roblox nicht bei jeder Eigenschaft neu rendert.
local function create(className: string, props: { [string]: any }): Instance
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local function addCorner(parent: Instance, radius: number?)
	create("UICorner", { CornerRadius = UDim.new(0, radius or THEME.Corner), Parent = parent })
end

-- Nimmt UDim2 oder Vector2 an
local function toUDim2(size: any): UDim2
	if typeof(size) == "UDim2" then
		return size
	elseif typeof(size) == "Vector2" then
		return UDim2.fromOffset(size.X, size.Y)
	end
	return UDim2.fromOffset(420, 300)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

-- Erstellt ein Fenster mit Header, Titel und Schließen-Button.
function UILibrary.CreateWindow(title: string, size: (UDim2 | Vector2)?)
	local player = Players.LocalPlayer
	assert(player, "UILibrary muss in einem LocalScript benutzt werden")

	local self = setmetatable({}, Window)
	self._connections = {} :: { RBXScriptConnection }
	self._tabs = {}
	self._activeTab = nil
	self._destroyed = false

	self.Gui = create("ScreenGui", {
		Name = "UILibrary_" .. title,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	self.Frame = create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = toUDim2(size),
		BackgroundColor3 = THEME.Background,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.Gui,
	}) :: Frame
	addCorner(self.Frame)

	-- Header
	local header = create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, THEME.HeaderHeight),
		BackgroundColor3 = THEME.Header,
		BorderSizePixel = 0,
		Parent = self.Frame,
	}) :: Frame
	self.Header = header
	-- ClipsDescendants schneidet nicht rund ab: Header oben abrunden und
	-- die untere Rundung mit einem Streifen in Header-Farbe auffüllen
	addCorner(header)
	create("Frame", {
		Name = "CornerFill",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, THEME.Corner),
		BackgroundColor3 = THEME.Header,
		BorderSizePixel = 0,
		Parent = header,
	})

	create("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(THEME.Padding + 2, 0),
		Size = UDim2.new(1, -(THEME.HeaderHeight + THEME.Padding * 2), 1, 0),
		BackgroundTransparency = 1,
		Font = THEME.Font,
		Text = title,
		TextColor3 = THEME.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})

	local closeButton = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(THEME.HeaderHeight - 8, THEME.HeaderHeight - 8),
		BackgroundColor3 = THEME.Header,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = THEME.Font,
		Text = "X",
		TextColor3 = THEME.TextDim,
		TextSize = 14,
		Parent = header,
	}) :: TextButton
	addCorner(closeButton, 4)

	self:_connect(closeButton.MouseEnter, function()
		closeButton.BackgroundColor3 = THEME.Close
		closeButton.TextColor3 = THEME.Text
	end)
	self:_connect(closeButton.MouseLeave, function()
		closeButton.BackgroundColor3 = THEME.Header
		closeButton.TextColor3 = THEME.TextDim
	end)
	self:_connect(closeButton.Activated, function()
		self:Destroy()
	end)

	-- Tab-Leiste (unsichtbar, bis der erste Tab angelegt wird)
	self.TabBar = create("Frame", {
		Name = "TabBar",
		Position = UDim2.fromOffset(0, THEME.HeaderHeight),
		Size = UDim2.new(1, 0, 0, THEME.TabBarHeight),
		BackgroundColor3 = THEME.TabBar,
		BorderSizePixel = 0,
		Visible = false,
		Parent = self.Frame,
	}) :: Frame
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = self.TabBar,
	})
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
		Parent = self.TabBar,
	})

	-- Inhaltsbereich: ohne Tabs landen Buttons direkt hier
	self.Content = create("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, THEME.HeaderHeight),
		Size = UDim2.new(1, 0, 1, -THEME.HeaderHeight),
		BackgroundTransparency = 1,
		Parent = self.Frame,
	}) :: Frame
	self.Container = self:_createPage(self.Content, "Default")

	self:_enableDragging()

	return self
end

-- Registriert eine Verbindung, damit Destroy() sie trennen kann.
function Window:_connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local conn = signal:Connect(fn)
	table.insert(self._connections, conn)
	return conn
end

-- Scrollbare Seite mit vertikaler Liste
function Window:_createPage(parent: Instance, name: string): ScrollingFrame
	local page = create("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = THEME.TextDim,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}) :: ScrollingFrame
	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = page,
	})
	create("UIPadding", {
		PaddingTop = UDim.new(0, THEME.Padding),
		PaddingBottom = UDim.new(0, THEME.Padding),
		PaddingLeft = UDim.new(0, THEME.Padding),
		PaddingRight = UDim.new(0, THEME.Padding + 4), -- Platz für die Scrollbar
		Parent = page,
	})
	return page
end

-- Fenster am Header verschieben (Maus und Touch)
function Window:_enableDragging()
	local dragging = false
	local dragStart: Vector3
	local startPos: UDim2

	self:_connect(self.Header.InputBegan, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = self.Frame.Position
		end
	end)

	self:_connect(UserInputService.InputChanged, function(input: InputObject)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			self.Frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)

	self:_connect(UserInputService.InputEnded, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

function Window:_selectTab(tab)
	for _, other in self._tabs do
		local active = other == tab
		other.Page.Visible = active
		other.Button.BackgroundColor3 = if active then THEME.TabActive else THEME.Tab
		other.Button.TextColor3 = if active then THEME.Text else THEME.TextDim
	end
	self._activeTab = tab
end

-- Erstellt einen Tab-Umschalter und gibt den Tab zurück.
-- Der Tab kann direkt an AddButton übergeben werden.
function Window:AddTab(name: string)
	-- Beim ersten Tab: Tab-Leiste zeigen und Standardseite verstecken
	if #self._tabs == 0 then
		self.TabBar.Visible = true
		self.Content.Position = UDim2.fromOffset(0, THEME.HeaderHeight + THEME.TabBarHeight)
		self.Content.Size = UDim2.new(1, 0, 1, -(THEME.HeaderHeight + THEME.TabBarHeight))
		self.Container.Visible = false
	end

	local button = create("TextButton", {
		Name = name,
		LayoutOrder = #self._tabs + 1,
		Size = UDim2.new(0, 0, 1, -6),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.Tab,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = THEME.Font,
		Text = name,
		TextColor3 = THEME.TextDim,
		TextSize = 13,
		Parent = self.TabBar,
	}) :: TextButton
	addCorner(button, 4)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = button,
	})

	local tab = {
		Name = name,
		Button = button,
		Page = self:_createPage(self.Content, name),
	}
	tab.Container = tab.Page
	tab.Page.Visible = false
	table.insert(self._tabs, tab)

	self:_connect(button.Activated, function()
		self:_selectTab(tab)
	end)

	if self._activeTab == nil then
		self:_selectTab(tab)
	end

	return tab
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

-- container: ein Tab aus AddTab, das Fenster selbst, ein beliebiges GuiObject
-- oder nil (dann der aktive Tab).
function Window:AddButton(container: any, text: string, callback: (() -> ())?): TextButton
	local parent: Instance
	if type(container) == "table" and container.Container then
		parent = container.Container
	elseif typeof(container) == "Instance" then
		parent = container
	else
		-- Ohne Angabe: aktiver Tab, sonst die Standardseite
		parent = if self._activeTab then self._activeTab.Container else self.Container
	end

	local button = create("TextButton", {
		Name = text,
		LayoutOrder = #parent:GetChildren(),
		Size = UDim2.new(1, 0, 0, THEME.ButtonHeight),
		BackgroundColor3 = THEME.Button,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = THEME.Font,
		Text = text,
		TextColor3 = THEME.Text,
		TextSize = 14,
		Parent = parent,
	}) :: TextButton
	addCorner(button, 4)

	self:_connect(button.MouseEnter, function()
		button.BackgroundColor3 = THEME.ButtonHover
	end)
	self:_connect(button.MouseLeave, function()
		button.BackgroundColor3 = THEME.Button
	end)

	if callback then
		self:_connect(button.Activated, function()
			-- Eigener Thread: ein Fehler oder ein task.wait im Callback
			-- blockiert die UI nicht
			task.spawn(function()
				local ok, err = pcall(callback)
				if not ok then
					warn("[UILibrary] Fehler im Button-Callback '" .. text .. "':", err)
				end
			end)
		end)
	end

	return button
end

---------------------------------------------------------------------------
-- Destroy
---------------------------------------------------------------------------

-- Trennt alle Verbindungen und löscht die ScreenGui, egal wo sie gerade hängt.
-- Kann mehrfach aufgerufen werden.
function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true

	for _, conn in self._connections do
		conn:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._tabs)
	self._activeTab = nil

	if self.Gui then
		self.Gui:Destroy()
		self.Gui = nil
	end
end

return UILibrary
