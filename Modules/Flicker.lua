local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

local FLICKER_ID = "rbxassetid://109243294526867"
local DASH_SOUND_ID = "rbxassetid://136726771728921"

local Settings = {
	Duration = 0.75,
	Cooldown = 0.1,

	Speed = 75,
	Acceleration = 0.1,
	Deceleration = 0.5,

	Transparency = 1,
	Volume = 0.5,
}

local Debounce = false
local ActiveConnection = nil

local Flicker
do
	local Success, Objects = pcall(function()
		return game:GetObjects(FLICKER_ID)
	end)

	if Success and Objects and Objects[1] then
		Flicker = Objects[1]
	end
end

local function PlaySound(SoundId, PlaybackSpeed)
	local Sound = Instance.new("Sound")
	Sound.SoundId = SoundId
	Sound.PlaybackSpeed = PlaybackSpeed or 1
	Sound.Volume = Settings.Volume
	Sound.Parent = workspace
	Sound:Play()

	local Removed = false
	Sound.Ended:Connect(function()
		if Removed then return end
		Removed = true
		if Sound.Parent then
			Sound:Destroy()
		end
	end)

	Debris:AddItem(Sound, 10)
end

local function GetCharacter()
	local Character = Player.Character
	if not Character then return end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Root = Character:FindFirstChild("HumanoidRootPart")

	if not Humanoid or not Root or Humanoid.Health <= 0 then
		return
	end

	return Character, Humanoid, Root
end

local function CaptureTransparency(Character)
	local Store = {}

	for _, Object in ipairs(Character:GetDescendants()) do
		if Object:IsA("BasePart") then
			if Object.Name ~= "HumanoidRootPart" then
				Store[Object] = Object.Transparency
				Object.Transparency = Settings.Transparency
			end
		elseif Object:IsA("Decal") or Object:IsA("Texture") then
			Store[Object] = Object.Transparency
			Object.Transparency = Settings.Transparency
		end
	end

	return Store
end

local function RestoreTransparency(Store)
	for Object, Transparency in pairs(Store) do
		if Object.Parent then
			Object.Transparency = Transparency
		end
	end
end

local function GetDashDirection(Root)
	local Camera = workspace.CurrentCamera
	local Direction

	if Camera then
		Direction = Camera.CFrame.LookVector
	else
		Direction = Root.CFrame.LookVector
	end

	local Horizontal = Vector3.new(Direction.X, 0, Direction.Z)

	if Horizontal.Magnitude > 0.0001 then
		return Horizontal.Unit
	end

	local Fallback = Vector3.new(Root.CFrame.LookVector.X, 0, Root.CFrame.LookVector.Z)

	if Fallback.Magnitude > 0.0001 then
		return Fallback.Unit
	end

	return Vector3.new(0, 0, -1)
end

function module.IsDashing()
	return Debounce
end

function module.SetSettings(Overrides)
	if typeof(Overrides) ~= "table" then return end

	for Key, Value in pairs(Overrides) do
		if Settings[Key] ~= nil then
			Settings[Key] = Value
		end
	end
end

function module.Cancel()
	if not Debounce then return end
	if ActiveConnection then
		ActiveConnection:Disconnect()
		ActiveConnection = nil
	end
end

function module.Dash()
	if Debounce then return end

	local Character, Humanoid, Root = GetCharacter()
	if not Character then return end

	Debounce = true

	local Finished = false
	local Connection
	local TransparencyStore = CaptureTransparency(Character)
	local StartTime = os.clock()
	local DecelerationStart = nil
	local DecelerationDelay = math.max(Settings.Duration, Settings.Acceleration)
	local DashSpeed = Settings.Speed

	local Velocity = Root.AssemblyLinearVelocity
	local BaseVelocity = Vector3.new(Velocity.X, 0, Velocity.Z)
	local Direction = GetDashDirection(Root)

	local FlickerModel
	local FlickerWeld

	if Flicker then
		local Clone = Flicker:Clone()
		Clone.Parent = Root

		local Weld = Clone:FindFirstChildWhichIsA("Weld", true)
		if Weld then
			Weld.Part0 = Root
			FlickerWeld = Weld
		end

		FlickerModel = Clone
	end

	local function DetachFlicker()
		if not FlickerModel then return end

		if FlickerWeld and FlickerWeld.Parent then
			FlickerWeld.Part0 = nil
			FlickerWeld.Part1 = nil
			FlickerWeld:Destroy()
		end

		FlickerWeld = nil

		for _, Object in ipairs(FlickerModel:GetDescendants()) do
			if Object:IsA("BasePart") then
				Object.Anchored = true
			end
		end

		FlickerModel.Parent = workspace
		Debris:AddItem(FlickerModel, 1)
		FlickerModel = nil
	end

	local function Stop()
		if Finished then return end
		Finished = true

		if Connection then
			Connection:Disconnect()
			Connection = nil
		end

		if ActiveConnection == Connection then
			ActiveConnection = nil
		end

		RestoreTransparency(TransparencyStore)
		TransparencyStore = {}

		DetachFlicker()
	end

	PlaySound(DASH_SOUND_ID, 1)

	Connection = RunService.RenderStepped:Connect(function()
		if Finished then return end

		if not Character.Parent or not Root.Parent or not Humanoid.Parent or Humanoid.Health <= 0 then
			Stop()
			return
		end

		local Elapsed = os.clock() - StartTime
		local Boost

		if Elapsed < DecelerationDelay then
			local Alpha

			if Settings.Acceleration > 0 then
				Alpha = math.clamp(Elapsed / Settings.Acceleration, 0, 1)
			else
				Alpha = 1
			end

			local Eased = TweenService:GetValue(
				Alpha,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)

			Boost = DashSpeed * Eased
		else
			if not DecelerationStart then
				DecelerationStart = os.clock()

				RestoreTransparency(TransparencyStore)
				TransparencyStore = {}

				DetachFlicker()

				PlaySound(DASH_SOUND_ID, 1.7)
			end

			local Alpha = math.clamp(
				(os.clock() - DecelerationStart) / math.max(Settings.Deceleration, 0.01),
				0,
				1
			)

			local Eased = TweenService:GetValue(
				Alpha,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)

			Boost = DashSpeed * (1 - Eased)

			if Alpha >= 1 then
				Root.AssemblyLinearVelocity = Vector3.new(
					BaseVelocity.X,
					Root.AssemblyLinearVelocity.Y,
					BaseVelocity.Z
				)

				Stop()
				return
			end
		end

		local Horizontal = BaseVelocity + Direction * Boost
		local CurrentVelocity = Root.AssemblyLinearVelocity

		Root.AssemblyLinearVelocity = Vector3.new(
			Horizontal.X,
			CurrentVelocity.Y,
			Horizontal.Z
		)
	end)

	ActiveConnection = Connection

	task.delay(DecelerationDelay + math.max(Settings.Deceleration, 0) + Settings.Cooldown, function()
		Debounce = false
	end)
end

return module
