
local module = {}

--// Services

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

--// Settings

local Settings = {
	FillTransparency = 0.65,
	OutlineTransparency = 0.25,

	PulseSpeed = 2.5,

	Colors = {
		Color3.fromRGB(170, 0, 0),
		Color3.fromRGB(255, 0, 0),
	},

	HealthDisplay = {
		Enabled = true,

		Size = UDim2.fromOffset(50, 18),
		Offset = Vector3.new(0, 0, 0),

		TextSize = 15,
		Font = Enum.Font.GothamBold,

		TextColor = Color3.fromRGB(255, 255, 255),
		GradientColors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 0, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 0, 0)),
		}),

		StrokeTransparency = 0.25,
	},
}

--// State

local index = {}
local enabled = false

local CurrentConfig = {
	Range = 150,
}

local RenderConnection
local DescendantConnection

--// Utility

local function IsValidCharacter(Model)
	if not Model or not Model:IsA("Model") then
		return false
	end

	if Model == LocalPlayer.Character then
		return false
	end

	if Players:GetPlayerFromCharacter(Model) == LocalPlayer then
		return false
	end

	return Model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function GetDistance(Model)
	local Character = LocalPlayer.Character
	if not Character then return math.huge end

	local Root = Character:FindFirstChild("HumanoidRootPart")
	local TargetRoot = Model:FindFirstChild("HumanoidRootPart")

	if not Root or not TargetRoot then
		return math.huge
	end

	return (Root.Position - TargetRoot.Position).Magnitude
end

--// Health Display

local function CreateHealthDisplay(Model, Humanoid)
	if not Settings.HealthDisplay.Enabled then return end

	local Head = Model:FindFirstChild("Head")
	if not Head then return end

	local Billboard = Instance.new("BillboardGui")
	Billboard.Name = "SharinganHealth"
	Billboard.Adornee = Head
	Billboard.Size = Settings.HealthDisplay.Size
	Billboard.StudsOffset = Settings.HealthDisplay.Offset
	Billboard.AlwaysOnTop = true
	Billboard.LightInfluence = 0
	Billboard.Enabled = false
	Billboard.Parent = Head

	local Label = Instance.new("TextLabel")
	Label.Name = "Health"
	Label.Size = UDim2.fromScale(1, 1)
	Label.BackgroundTransparency = 1

	Label.TextColor3 = Settings.HealthDisplay.TextColor
	Label.TextSize = Settings.HealthDisplay.TextSize
	Label.Font = Settings.HealthDisplay.Font

	Label.TextStrokeTransparency = Settings.HealthDisplay.StrokeTransparency
	Label.Text = tostring(math.ceil(Humanoid.Health))

	Label.Parent = Billboard

	local Gradient = Instance.new("UIGradient")
	Gradient.Color = Settings.HealthDisplay.GradientColors
	Gradient.Rotation = 90
	Gradient.Parent = Label

	local HealthConnection = Humanoid.HealthChanged:Connect(function(Health)
		if Label.Parent then
			Label.Text = tostring(math.ceil(Health))
		end
	end)

	return Billboard, HealthConnection
end

--// Highlight Creation

local function CreateHighlight(Model)
	if not IsValidCharacter(Model) then return end
	if index[Model] then return end

	local Humanoid = Model:FindFirstChildOfClass("Humanoid")

	local Highlight = Instance.new("Highlight")
	Highlight.Name = "SharinganHighlight"
	Highlight.Adornee = Model

	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

	Highlight.FillColor = Settings.Colors[1]
	Highlight.OutlineColor = Settings.Colors[1]

	Highlight.FillTransparency = Settings.FillTransparency
	Highlight.OutlineTransparency = Settings.OutlineTransparency

	Highlight.Enabled = false
	Highlight.Parent = Model

	local HealthDisplay, HealthConnection =
		CreateHealthDisplay(Model, Humanoid)

	index[Model] = {
		Highlight = Highlight,
		HealthDisplay = HealthDisplay,
		HealthConnection = HealthConnection,
	}
end

local function RemoveHighlight(Model)
	local Data = index[Model]
	if not Data then return end

	if Data.HealthConnection then
		Data.HealthConnection:Disconnect()
	end

	if Data.Highlight then
		Data.Highlight:Destroy()
	end

	if Data.HealthDisplay then
		Data.HealthDisplay:Destroy()
	end

	index[Model] = nil
end

local function ClearHighlights()
	for Model in pairs(index) do
		RemoveHighlight(Model)
	end
end

--// Visual Effects

local function StartPulse()
	local StartTime = os.clock()

	RenderConnection = RunService.RenderStepped:Connect(function()
		if not enabled then return end

		local Alpha = (
			math.sin((os.clock() - StartTime) * Settings.PulseSpeed) + 1
		) / 2

		local Color = Settings.Colors[1]:Lerp(
			Settings.Colors[2],
			Alpha
		)

		for Model, Data in pairs(index) do
			if not Model.Parent then
				RemoveHighlight(Model)
				continue
			end

			local InRange = GetDistance(Model) <= CurrentConfig.Range

			Data.Highlight.Enabled = InRange

			if Data.HealthDisplay then
				Data.HealthDisplay.Enabled = InRange
			end

			if InRange then
				Data.Highlight.FillColor = Color
				Data.Highlight.OutlineColor = Color
			end
		end
	end)
end

--// Configuration

function module.SetConfig(Config)
	if typeof(Config) ~= "table" then return end

	CurrentConfig = Config
end

--// Module Functions

function module.Enable()
	if enabled then return end

	enabled = true

	for _, Model in ipairs(workspace:GetDescendants()) do
		if Model:IsA("Model") then
			CreateHighlight(Model)
		end
	end

	DescendantConnection = workspace.DescendantAdded:Connect(function(Object)
		if not enabled then return end

		if Object:IsA("Humanoid") then
			local Model = Object.Parent

			if Model then
				CreateHighlight(Model)
			end
		end
	end)

	StartPulse()
end

function module.Disable()
	if not enabled then return end

	enabled = false

	if RenderConnection then
		RenderConnection:Disconnect()
		RenderConnection = nil
	end

	if DescendantConnection then
		DescendantConnection:Disconnect()
		DescendantConnection = nil
	end

	ClearHighlights()
end

return module
