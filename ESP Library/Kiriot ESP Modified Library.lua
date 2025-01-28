local ESP = {
	Enabled = false,
	Players = true,
	Names = true,
	Distance = false,
	UseMeDistance = false,
	MaxMeDistance = math.huge,
	Boxes = true,
	Health = true,
	HealthOffsetX = 4,
	HealthOffsetY = - 2,
	Items = false,
	ItemOffset = 10,
	Chams = false,
	ChamsTransparency = .5,
	ChamsOutlineTransparency = 0,
	ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
	Tracers = false,
	Origin = "Bottom",
	OutOfViewArrows = false,
	OutOfViewArrowsRadius = 100,
	OutOfViewArrowsSize = 25,
	OutOfViewArrowsOutline = false,
	OutOfViewArrowsOutlineColor = Color3.fromRGB(255, 255, 255),
	FaceCamera = false,
	TeamColor = true,
	TeamMates = true,
	Font = "Plex",
	TextSize = 19,
	BoxShift = CFrame.new(0, - 1.5, 0),
	BoxSize = Vector3.new(4, 6, 0),
	Color = Color3.fromRGB(0, 166, 255),
	HighlightColor = Color3.new(1, 1, 1),
	ScreenScale = 1,
	Thickness = 2,
	AttachShift = 1,
	Bars = false,
	GlobalBars = {},
	HrpName = "HumanoidRootPart",
	Objects = setmetatable({}, {
		__mode = "kv"
	}),
	Overrides = {},
}
getgenv().shared.ESP = ESP
if ... and type(...) == "table" then
	for i, v in next, ... do
		ESP[i] = v
	end
end
local cam = workspace.CurrentCamera
local Players, UIS = game:GetService("Players"), game:GetService("UserInputService")
local Me = Players.LocalPlayer
local mouse = Me:GetMouse()
local WorldToViewportPoint = cam.WorldToViewportPoint
local PointToObjectSpace = CFrame.new().PointToObjectSpace
local Cross = Vector3.new().Cross
local Folder = Instance.new("Folder", game.CoreGui)
local lastFov, lastScale = nil, nil
function round(number)
	return typeof(number) == "Vector2" and Vector2.new(round(number.X), round(number.Y)) or math.floor(number)
end
function GetScaleFactor(fov, depth)
	if (fov ~= lastFov) then
		lastScale = math.tan(math.rad(fov * .5)) * 2
		lastFov = fov
	end
	return 1 / (depth * lastScale) * 1e3
end
function BrahWth(position)
	local screenPosition, onScreen = WorldToViewportPoint(cam, position)
	return Vector2.new(screenPosition.X, screenPosition.Y), onScreen, screenPosition.Z
end
function GetBoundingBox(torso)
	local torsoPosition, onScreen, depth = BrahWth(torso.Position)
	local scaleFactor = GetScaleFactor(cam.FieldOfView, depth)
	local size = round(Vector2.new(4 * scaleFactor, 5 * scaleFactor))
	return onScreen, size, round(Vector2.new(torsoPosition.X - (size.X * .5), torsoPosition.Y - (size.Y * .5))), torsoPosition
end
local function Draw(obj, props)
	local new = Drawing.new(obj)
	props = props or {}
	for i, v in next, props do
		new[i] = v
	end
	return new
end
function ESP:GetTeam(p)
	local ov = self.Overrides.GetTeam
	if ov then
		return ov(p)
	end
	return p and p.Team
end
function ESP:IsTeamMate(p)
	local ov = self.Overrides.IsTeamMate
	if ov then
		return ov(p)
	end
	return self:GetTeam(p) == self:GetTeam(Me)
end
function ESP:GetColor(obj)
	local ov = self.Overrides.GetColor
	if ov then
		return ov(obj)
	end
	local p = self:GetMeFromChar(obj)
	return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
end
function ESP:GetMeFromChar(char)
	local ov = self.Overrides.GetMeFromChar
	if ov then
		return ov(char)
	end
	
	return Players:GetPlayerFromCharacter(char)
end
function ESP:Toggle(bool)
	self.Enabled = bool
	if not bool then
		for i, v in next, self.Objects do
			if v.Type == "Box" then
				if v.Temporary then
					v:Remove()
				else
					for i, v in next, v.Components do
						if typeof(v) == "Instance" then
							v.Enabled = false
						else
							v.Visible = false
						end
					end
				end
			end
		end
	end
end
function ESP:GetBox(obj)
	return self.Objects[obj]
end
function ESP:AddObjectListener(parent, options)
	local function NewListener(c)
		if type(options.Type) == "string" and c:IsA(options.Type) or options.Type == nil then
			if type(options.Name) == "string" and c.Name == options.Name or options.Name == nil then
				if not options.Validator or options.Validator(c) then
					local box = ESP:Add(c, {
						PrimaryPart = type(options.PrimaryPart) == "string" and c:WaitForChild(options.PrimaryPart) or type(options.PrimaryPart) == "function" and options.PrimaryPart(c),
						Color = type(options.Color) == "function" and options.Color(c) or options.Color,
						ColorDynamic = options.ColorDynamic,
						Name = type(options.CustomName) == "function" and options.CustomName(c) or options.CustomName,
						IsEnabled = options.IsEnabled,
						RenderInNil = options.RenderInNil
					})
					if options.OnAdded then
						coroutine.wrap(options.OnAdded)(box)
					end
				end
			end
		end
	end
	if options.Recursive then
		parent.DescendantAdded:Connect(NewListener)
		for i, v in next, parent:GetDescendants() do
			coroutine.wrap(NewListener)(v)
		end
	else
		parent.ChildAdded:Connect(NewListener)
		for i, v in next, parent:GetChildren() do
			coroutine.wrap(NewListener)(v)
		end
	end
end
function ESP:AddGlobalPlayerBar(name, options, onAdded)
	table.insert(self.GlobalBars, {
		name,
		options,
		onAdded
	})
	for i, box in next, self.Objects do
		if box.Player then
			coroutine.wrap(onAdded)(box, box:AddBar(name, options))
		end
	end
end
local boxBase = {}
boxBase.__index = boxBase
function boxBase:Remove()
	ESP.Objects[self.Object] = nil
	for i, v in next, self.Components do
		if typeof(v) == "Instance" then
			v:Destroy()
		else
			v:Remove()
		end
		self.Components[i] = nil
	end
end
function boxBase:Update()
	if not self.PrimaryPart then
		return self:Remove()
	end
	local color
	if ESP.Highlighted == self.Object then
		color = ESP.HighlightColor
	else
		color = self.Color or self.ColorDynamic and self:ColorDynamic() or ESP:GetColor(self.Object) or ESP.Color
	end

	local allow = true
	if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then
		allow = false
	end
	if self.Player and not ESP.TeamMates and ESP:IsTeamMate(self.Player) then
		allow = false
	end
	if self.Player and not ESP.Players then
		allow = false
	end
	if self.IsEnabled and (type(self.IsEnabled) == "string" and not ESP[self.IsEnabled] or type(self.IsEnabled) == "function" and not self:IsEnabled()) then
		allow = false
	end
	if not workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then
		allow = false
	end
	if not allow then
		for i, v in next, self.Components do
			if typeof(v) == "Instance" then
				v.Enabled = false
			else
				v.Visible = false
			end
		end
		return
	end
	if ESP.Highlighted == self.Object then
		color = ESP.HighlightColor
	end
	local IsMeHighlighted = (ESP.Highlighted == self.Object and self.Player ~= nil)
	local cf = self.PrimaryPart.CFrame
	if ESP.FaceCamera then
		cf = CFrame.new(cf.Position, cam.CFrame.Position)
	end
	local distance = math.floor((cam.CFrame.Position - cf.Position).magnitude)
	if self.Player and ESP.UseMeDistance and distance > ESP.MaxMeDistance then
		for i, v in next, self.Components do
			if typeof(v) == "Instance" then
				v.Enabled = false
			else
				v.Visible = false
			end
		end
		return
	end
	self.Distance = distance
	local size = self.Size
	local locs = {
		TopLeft = cf * ESP.BoxShift * CFrame.new(size.X / 2, size.Y / 2, 0),
		TopRight = cf * ESP.BoxShift * CFrame.new(- size.X / 2, size.Y / 2, 0),
		BottomLeft = cf * ESP.BoxShift * CFrame.new(size.X / 2, - size.Y / 2, 0),
		BottomRight = cf * ESP.BoxShift * CFrame.new(- size.X / 2, - size.Y / 2, 0),
		TagPos = cf * ESP.BoxShift * CFrame.new(0, size.Y / 2, 0),
		Torso = cf
	}
	if ESP.Boxes then
		local onScreen, size, position = GetBoundingBox(locs.Torso)
		if self.Components.Box and self.Components.BoxOutline and self.Components.BoxFill then
			if onScreen and position and size then
				self.Components.Box.Visible = true
				self.Components.Box.Color = color
				self.Components.Box.Size = size
				self.Components.Box.Position = position
				self.Components.BoxOutline.Visible = true
				self.Components.BoxOutline.Size = size
				self.Components.BoxOutline.Position = position
				self.Components.BoxFill.Visible = true
				self.Components.BoxFill.Color = color
				self.Components.BoxFill.Size = size
				self.Components.BoxFill.Position = position
			else
				self.Components.Box.Visible = false
				self.Components.BoxOutline.Visible = false
				self.Components.BoxFill.Visible = false
			end
		end
	else
		self.Components.Box.Visible = false
		self.Components.BoxOutline.Visible = false
		self.Components.BoxFill.Visible = false
	end
	if ESP.Names then
		local onScreen, size, position = GetBoundingBox(locs.Torso)
		if onScreen and size and position then
			self.Components.Name.Visible = true
			self.Components.Name.Position = round(position + Vector2.new(size.X * .5, - (self.Components.Name.TextBounds.Y + 2)))
			self.Components.Name.Text = self.Name
			self.Components.Name.Color = color
		else
			self.Components.Name.Visible = false
		end
	else
		self.Components.Name.Visible = false
	end
	if ESP.Distance then
		local onScreen, size, position = GetBoundingBox(locs.Torso)
		if onScreen and size and position then
			self.Components.Distance.Visible = true
			self.Components.Distance.Position = round(position + Vector2.new(size.X * .5, size.Y + 1))
			self.Components.Distance.Text = math.floor((cam.CFrame.Position - cf.Position).magnitude) .. "m"
			self.Components.Distance.Color = color
		else
			self.Components.Distance.Visible = false
		end
	else
		self.Components.Distance.Visible = false
	end
	if ESP.Tracers then
		local TorsoPos, Vis7 = WorldToViewportPoint(cam, locs.Torso.Position)
		if Vis7 then
			self.Components.Tracer.Visible = true
			self.Components.Tracer.From = Vector2.new(TorsoPos.X, TorsoPos.Y)
			self.Components.Tracer.To = ESP.Origin == "Mouse" and UIS:GetMouseLocation() or ESP.Origin == "Bottom" and Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / ESP.AttachShift)
			self.Components.Tracer.Color = color
			self.Components["Tracer"].ZIndex = IsMeHighlighted and 2 or 1
		else
			self.Components.Tracer.Visible = false
		end
	else
		self.Components.Tracer.Visible = false
	end
	if ESP.Bars and ESP.FaceCamera then
		if not ESP.Boxes then
			TopLeft, Vis1 = WorldToViewportPoint(cam, locs.TopLeft.p)
			BottomLeft, Vis3 = WorldToViewportPoint(cam, locs.BottomLeft.p)
		end
		local amount = 0
		for i, v in next, self.Bars do
			if (Vis1 or Vis3) and v.Value < 1 then
				local x = TopLeft.X - amount * 5 - 3
				local barWidth = 4
				local barPadding = 1
				v.Components.BarBackground.Visible = true
				v.Components.BarBackground.PointA = Vector2.new(x, TopLeft.Y)
				v.Components.BarBackground.PointB = Vector2.new(x - barWidth, TopLeft.Y)
				v.Components.BarBackground.PointC = Vector2.new(x - barWidth, BottomLeft.Y)
				v.Components.BarBackground.PointD = Vector2.new(x, BottomLeft.Y)
				v.Components.Bar.Visible = true
				v.Components.Bar.Color = v.Color
				local height = (BottomLeft.Y - TopLeft.Y - barPadding * 2) * (1 - v.Value)
				v.Components.Bar.PointA = Vector2.new(x - barPadding, TopLeft.Y + height + barPadding)
				v.Components.Bar.PointB = Vector2.new(x - barWidth + barPadding, TopLeft.Y + height + barPadding)
				v.Components.Bar.PointC = Vector2.new(x - barWidth + barPadding, BottomLeft.Y - barPadding)
				v.Components.Bar.PointD = Vector2.new(x - barPadding, BottomLeft.Y - barPadding)
				amount = amount + 1
			else
				v.Components.BarBackground.Visible = false
				v.Components.Bar.Visible = false
			end
		end
	else
		for i, v in next, self.Bars do
			v.Components.BarBackground.Visible = false
			v.Components.Bar.Visible = false
		end
	end
	if ESP.Health then
		local onScreen, size, position = GetBoundingBox(locs.Torso)
		if onScreen and size and position then
			if self.Object and self.Object:FindFirstChildOfClass("Humanoid") then
				local Health, MaxHealth = self.Object:FindFirstChildOfClass("Humanoid").Health, self.Object:FindFirstChildOfClass("Humanoid").MaxHealth
				local healthBarSize = round(Vector2.new(1, - (size.Y * (Health / MaxHealth))))
				local healthBarPosition = round(Vector2.new(position.X - (3 + healthBarSize.X), position.Y + size.Y))
				local g = Color3.fromRGB(0, 255, 8)
				local r = Color3.fromRGB(255, 0, 0)
				self.Components.HealthBar.Visible = true
				self.Components.HealthBar.Color = r:lerp(g, Health / MaxHealth)
				self.Components.HealthBar.Transparency = 1
				self.Components.HealthBar.Size = healthBarSize
				self.Components.HealthBar.Position = healthBarPosition
				self.Components.HealthBarOutline.Visible = true
				self.Components.HealthBarOutline.Transparency = 1
				self.Components.HealthBarOutline.Size = round(Vector2.new(healthBarSize.X, - size.Y) + Vector2.new(2, - 2))
				self.Components.HealthBarOutline.Position = healthBarPosition - Vector2.new(1, - 1)
				self.Components.HealthText.Visible = true
				self.Components.HealthText.Color = r:lerp(g, Health / MaxHealth)
				self.Components.HealthText.Text = "HP: " .. math.floor(Health + .5) .. "\n" .. "MHP: " .. MaxHealth
				self.Components.HealthText.Position = round(position + Vector2.new(size.X + 3, - 3))
			end
		else
			self.Components.HealthBar.Visible = false
			self.Components.HealthBarOutline.Visible = false
			self.Components.HealthText.Visible = false
		end
	else
		self.Components.HealthBar.Visible = false
		self.Components.HealthBarOutline.Visible = false
		self.Components.HealthText.Visible = false
	end
	if ESP.Items then
		local onScreen, size, position = GetBoundingBox(locs.Torso)
		if onScreen and size and position then
			if self.Object and self.Object:FindFirstChildOfClass("Tool") then
				self.Components.Items.Text = tostring(self.Object:FindFirstChildOfClass("Tool").Name)
				local ItemOffset = ESP.ItemOffset
				self.Components.Items.Position = round(position + Vector2.new(size.X * .5, size.Y - 50))
				self.Components.Items.Visible = true
				self.Components.Items.Color = color
			else
				self.Components.Items.Visible = false
			end
		else
			self.Components.Items.Visible = false
		end
	else
		self.Components.Items.Visible = false
	end
	local TorsoPos, Vis11 = WorldToViewportPoint(cam, locs.Torso.Position)
	if not Vis11 then
		local viewportSize = cam.ViewportSize
		local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
		local objectSpacePoint = (PointToObjectSpace(cam.CFrame, locs.Torso.Position) * Vector3.new(1, 0, 1)).Unit
		local crossVector = Cross(objectSpacePoint, Vector3.new(0, 1, 1))
		local rightVector = Vector2.new(crossVector.X, crossVector.Z)
		local arrowRadius, arrowSize = ESP.OutOfViewArrowsRadius, ESP.OutOfViewArrowsSize
		local arrowPosition = screenCenter + Vector2.new(objectSpacePoint.X, objectSpacePoint.Z) * arrowRadius
		local arrowDirection = (arrowPosition - screenCenter).Unit
		local pointA, pointB, pointC = arrowPosition, screenCenter + arrowDirection * (arrowRadius - arrowSize) + rightVector * arrowSize, screenCenter + arrowDirection * (arrowRadius - arrowSize) + - rightVector * arrowSize
		if ESP.OutOfViewArrows then
			self.Components.Arrow.Visible = true
			self.Components.Arrow.Filled = true
			self.Components.Arrow.Transparency = .5
			self.Components.Arrow.Color = color
			self.Components.Arrow.PointA = pointA
			self.Components.Arrow.PointB = pointB
			self.Components.Arrow.PointC = pointC
		else
			self.Components.Arrow.Visible = false
		end
		if ESP.OutOfViewArrowsOutline then
			self.Components.Arrow2.Visible = true
			self.Components.Arrow2.Filled = false
			self.Components.Arrow2.Transparency = 1
			self.Components.Arrow2.Color = ESP.OutOfViewArrowsOutlineColor
			self.Components.Arrow2.PointA = pointA
			self.Components.Arrow2.PointB = pointB
			self.Components.Arrow2.PointC = pointC
		else
			self.Components.Arrow2.Visible = false
		end
	else
		self.Components.Arrow.Visible = false
		self.Components.Arrow2.Visible = false
	end
	if ESP.Chams then
		local TorsoPos, Vis12 = WorldToViewportPoint(cam, locs.Torso.Position)
		if Vis12 then
			self.Components.Highlight.Enabled = true
			self.Components.Highlight.FillColor = color
			self.Components.Highlight.FillTransparency = ESP.ChamsTransparency
			self.Components.Highlight.OutlineTransparency = ESP.ChamsOutlineTransparency
			self.Components.Highlight.OutlineColor = ESP.ChamsOutlineColor
		else
			self.Components.Highlight.Enabled = false
		end
	else
		self.Components.Highlight.Enabled = false
	end
end
function ESP:Add(obj, options)
	if not obj.Parent and not options.RenderInNil then
		return warn("[KH ESP]:", obj, "has no parent")
	end
	local box = setmetatable({
		Name = options.Name or obj.Name,
		Type = "Box",
		Color = options.Color,
		Size = options.Size or self.BoxSize,
		Object = obj,
		Player = options.Player or Players:GetPlayerFromCharacter(obj),
		PrimaryPart = options.PrimaryPart or obj.ClassName == "Model" and (obj.PrimaryPart or obj:FindFirstChild(ESP.HrpName) or obj:FindFirstChildWhichIsA("BasePart")) or obj:IsA("BasePart") and obj,
		Components = {},
		IsEnabled = options.IsEnabled,
		Temporary = options.Temporary,
		ColorDynamic = options.ColorDynamic,
		RenderInNil = options.RenderInNil,
		Bars = {}
	}, boxBase)
	if self:GetBox(obj) then
		self:GetBox(obj):Remove()
	end
	box.Components["Box"] = Draw("Square", {
		Thickness = self.Thickness,
		Color = color,
		Transparency = 1,
		Filled = false,
		Visible = self.Enabled and self.Boxes
	})
	box.Components["BoxOutline"] = Draw("Square", {
		Thickness = self.Thickness,
		Color = color,
		Transparency = 3,
		Filled = false,
		Visible = self.Enabled and self.Boxes
	})
	box.Components["BoxFill"] = Draw("Square", {
		Thickness = self.Thickness,
		Color = color,
		Transparency = 1,
		Filled = false,
		Visible = self.Enabled and self.Boxes
	})
	box.Components["Name"] = Draw("Text", {
		Text = box.Name,
		Color = box.Color,
		Center = true,
		Outline = true,
		Size = self.TextSize,
		Visible = self.Enabled and self.Names
	})
	box.Components["Distance"] = Draw("Text", {
		Color = box.Color,
		Center = true,
		Outline = true,
		Size = 19,
		Visible = self.Enabled and self.Names
	})
	
	box.Components["Tracer"] = Draw("Line", {
		Thickness = ESP.Thickness,
		Color = box.Color,
		Transparency = 1,
		Visible = self.Enabled and self.Tracers
	})
	box.Components["Items"] = Draw("Text", {
		Color = box.Color,
		Center = true,
		Outline = true,
		Size = self.TextSize,
		Visible = self.Enabled and self.Items
	})
	box.Components["HealthBarOutline"] = Draw("Square", {
		Transparency = 1,
		Thickness = 1,
		Filled = true,
		Visible = self.Enabled and self.Health
	})
	box.Components["HealthBar"] = Draw("Square", {
		Transparency = 1,
		Thickness = 1,
		Visible = self.Enabled and self.Health
	})
	box.Components["HealthText"] = Draw("Text", {
		Color = box.Color,
		Center = true,
		Outline = true,
		Size = self.TextSize,
		Visible = self.Enabled and self.Health
	})
	box.Components["Tracer"] = Draw("Line", {
		Thickness = ESP.Thickness,
		Color = box.Color,
		Transparency = 1,
		Visible = self.Enabled and self.Tracers
	})
	box.Components["Arrow"] = Draw("Triangle", {
		Thickness = 1
	})
	box.Components["Arrow2"] = Draw("Triangle", {
		Thickness = 1
	})
	local h = Instance.new("Highlight")
	h.Enabled = ESP.Chams
	h.FillTransparency = .35
	h.OutlineTransparency = .35
	h.FillColor = ESP.Color
	h.OutlineColor = ESP.ChamsOutlineColor
	h.DepthMode = 0
	h.Name = "Too Geeked Up"
	h.Parent = Folder
	h.Adornee = obj
	box.Components["Highlight"] = h
	self.Objects[obj] = box
	obj.AncestryChanged:Connect(function(_, parent)
		if parent == nil and ESP.AutoRemove ~= false then
			box:Remove()
		end
	end)
	obj:GetPropertyChangedSignal("Parent"):Connect(function()
		if obj.Parent == nil and ESP.AutoRemove ~= false then
			box:Remove()
		end
	end)
	local hum = obj:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			if ESP.AutoRemove ~= false then
				box:Remove()
			end
		end)
	end
	return box
end
local barBase = {}
barBase.__index = barBase
function boxBase:AddBar(name, options)
	local bar = setmetatable({
		Name = name,
		Type = "Bar",
		Color = options.Color,
		Components = {},
		Value = 0.4
	}, barBase)

	table.insert(self.Bars, bar)
	bar.Components["BarBackground"] = Draw("Quad", {
		Thickness = ESP.Thickness,
		Color = Color3.fromRGB(26, 26, 26),
		Transparency = 1,
		Filled = true,
		Visible = ESP.Enabled and ESP.Bars
	})
	bar.Components["Bar"] = Draw("Quad", {
		Thickness = ESP.Thickness,
		Color = bar.Color,
		Transparency = 1,
		Filled = true,
		Visible = ESP.Enabled and ESP.Bars
	})
	for i, v in next, bar.Components do
		table.insert(self.Components, v)
	end
	return bar
end
local function CharAdded(char)
	local p = Players:GetPlayerFromCharacter(char)
	if not char:FindFirstChild(ESP.HrpName) then
		local ev
		ev = char.ChildAdded:Connect(function(c)
			if c.Name == ESP.HrpName then
				ev:Disconnect()
				local box = ESP:Add(char, {
					Name = p.Name,
					Player = p,
					PrimaryPart = c
				})
				for i, v in next, ESP.GlobalBars do
					coroutine.wrap(v[3])(box, box:AddBar(v[1], v[2]))
				end
			end
		end)
	else
		local box = ESP:Add(char, {
			Name = p.Name,
			Player = p,
			PrimaryPart = char:FindFirstChild(ESP.HrpName)
		})
		for i, v in next, ESP.GlobalBars do
			coroutine.wrap(v[3])(box, box:AddBar(v[1], v[2]))
		end
	end
end
local function PlayerAdded(p)
	p.CharacterAdded:Connect(CharAdded)
	if p.Character then
		coroutine.wrap(CharAdded)(p.Character)
	end
end
Players.PlayerAdded:Connect(PlayerAdded)
for i, v in next, Players:GetPlayers() do
	if v ~= Me then
		PlayerAdded(v)
	end
end
ESP.OnRenderStepped = game:GetService("RunService").PostSimulation:Connect(function()
	cam = workspace.CurrentCamera
	for i, v in (ESP.Enabled and pairs or ipairs)(ESP.Objects) do
		if v.Update then
			local s, e = pcall(v.Update, v)
			if not s then
				warn("[EU]", e, v.Object:GetFullName())
			end
		end
	end
end)
return ESP
