
local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Flicker = game:GetObjects('rbxassetid://109243294526867')[1]

local Settings = {
	Duration = 0.75,
	Cooldown = 0.5,

	Speed = 75,
	Acceleration = 0.1,
	Deceleration = 0.5,

	Transparency = 1,
}

local Debounce = false
local ActiveConnection

local function SetCharacterTransparency(Character, Transparency)
	for _, Object in ipairs(Character:GetDescendants()) do
		if Object:IsA("BasePart") then
			if Object.Name ~= "HumanoidRootPart" then
				Object.Transparency = Transparency
			end
		elseif Object:IsA("Decal") or Object:IsA("Texture") then
			Object.Transparency = Transparency
		end
	end
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

function module.Dash()
	if Debounce then return end

	local Character, Humanoid, Root = GetCharacter()
	if not Character then return end

	Debounce = true

	local NewFlicker = Flicker:Clone()
	NewFlicker.Parent = Root

	local Weld = NewFlicker:FindFirstChildWhichIsA("Weld", true)
	if Weld then
		Weld.Part0 = Root
	end

	Debris:AddItem(NewFlicker, Settings.Duration + Settings.Deceleration + 1)

	local OriginalTransparency = {}

	for _, Object in ipairs(Character:GetDescendants()) do
		if Object:IsA("BasePart") or Object:IsA("Decal") or Object:IsA("Texture") then
			OriginalTransparency[Object] = Object.Transparency
		end
	end

	SetCharacterTransparency(Character, Settings.Transparency)

	local StartTime = os.clock()
	local DecelerationStart = nil
	local InitialVelocity = nil
	
	local Sound = Instance.new('Sound',workspace)
	Sound.SoundId = 'rbxassetid://136726771728921'
	Sound:Play()
	Sound.Ended:Connect(function() Sound:Destroy() end)
	
	local Connection
	Connection = RunService.RenderStepped:Connect(function()
		if not Character.Parent or Humanoid.Health <= 0 or not Root.Parent then
			Connection:Disconnect()
			ActiveConnection = nil

			for Object, Transparency in pairs(OriginalTransparency) do
				if Object.Parent then
					Object.Transparency = Transparency
				end
			end

			if NewFlicker then
				NewFlicker.Weld.Part0 = nil
				NewFlicker.Weld.Part1 = nil 
				NewFlicker.Anchored = true
				Debris:AddItem(NewFlicker, 1)
			end

			Debounce = false
			return
		end

		local Elapsed = os.clock() - StartTime

		local Camera = workspace.CurrentCamera
		local Direction = Camera.CFrame.LookVector
		local HorizontalDirection = Vector3.new(Direction.X, 0, Direction.Z)

		if HorizontalDirection.Magnitude > 0 then
			HorizontalDirection = HorizontalDirection.Unit
		end

		-- Acceleration phase
		if Elapsed < Settings.Duration then
			local Alpha = math.clamp(Elapsed / Settings.Acceleration, 0, 1)

			local EasedAlpha = TweenService:GetValue(
				Alpha,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)

			local CurrentSpeed = Settings.Speed * EasedAlpha

			Root.AssemblyLinearVelocity = Vector3.new(
				HorizontalDirection.X * CurrentSpeed,
				Root.AssemblyLinearVelocity.Y,
				HorizontalDirection.Z * CurrentSpeed
			)

		else
			-- Begin deceleration
			if not DecelerationStart then
				DecelerationStart = os.clock()

				local Velocity = Root.AssemblyLinearVelocity
				InitialVelocity = Vector3.new(Velocity.X, 0, Velocity.Z)

				-- Restore transparency
				
				local Sound = Instance.new('Sound',workspace)
				Sound.SoundId = 'rbxassetid://136726771728921'
				Sound:Play()
				Sound.PlaybackSpeed = 1.7
				Sound.Ended:Connect(function() Sound:Destroy() end)
				
				for Object, Transparency in pairs(OriginalTransparency) do
					if Object.Parent then
						Object.Transparency = Transparency
					end
				end

				if NewFlicker then
					NewFlicker.Weld.Part0 = nil
					NewFlicker.Weld.Part1 = nil 
					NewFlicker.Anchored = true
					Debris:AddItem(NewFlicker, 1)
				end
			end

			-- Deceleration phase
			local Alpha = math.clamp(
				(os.clock() - DecelerationStart) / Settings.Deceleration,
				0,
				1
			)

			local EasedAlpha = TweenService:GetValue(
				Alpha,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)

			local Velocity = InitialVelocity:Lerp(Vector3.zero, EasedAlpha)

			Root.AssemblyLinearVelocity = Vector3.new(
				Velocity.X,
				Root.AssemblyLinearVelocity.Y,
				Velocity.Z
			)

			if Alpha >= 1 then
				
				Connection:Disconnect()
				ActiveConnection = nil
			end
		end
	end)

	ActiveConnection = Connection

	task.delay(Settings.Duration + Settings.Deceleration + Settings.Cooldown, function()
		Debounce = false
	end)
end

return module
