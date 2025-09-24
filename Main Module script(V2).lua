-- [This Script is updated for Re-Verification]
-- This game is about Launching Cannonballs Basically with Tons of effects
--This is a Module script

-- Load up Roblox services we’ll be using throughout this script
local Players = game:GetService("Players")  -- allows access to all the player instances currently in the game
local ReplicatedStorage = game:GetService("ReplicatedStorage")  -- shared storage between server and clients
local RS = game:GetService("RunService")  -- Helps to run code every frame
local Debris = game:GetService("Debris")  -- used to remove parts in x timeframe
local Workspace = game:GetService("Workspace")  -- main 3D environment where all parts and objects exist

local CollectionService = game:GetService("CollectionService")  -- It allows tagging objects so we can identify or ignore them later

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))  -- framework for organizing services and overall game logic

-- Projectiles are stored in ReplicatedStorage inside a folder called “ProjectileTemplates”
local ProjectileTemplates = ReplicatedStorage:WaitForChild("ProjectileTemplates")  -- contains all the projectile models we can clone
-- Cannons that fire projectiles live in Workspace inside a folder called “CannonLaunchers”
local CannonFolder = Workspace:WaitForChild("CannonLaunchers")  -- holds all cannons present in the game

-- Projectile settings
local StartSpeed = 100  -- initial speed the projectile moves at when launched
local GravitySim = Vector3.new(0, -50, 0)  -- stronger downward force than the default Roblox gravity
local ProjectileLife = 5  -- time in seconds before a projectile is removed from the world
local TrailSize = Vector3.new(0.2, 0.2, 0.2)  -- size of each tiny trail segment spawned behind the projectile
local TrailLife = 0.2  -- duration each trail segment exists before being removed

-- Debris settings for impact cubes
local ImpactCubeCount = 6  -- how many cubes fly out when projectile collides
local ImpactCubeSize = Vector3.new(1,1,1)  -- size of each cube debris
local ImpactCubeLife = 1.5  -- how long cubes remain before being removed

-- Define a “class-like” table to handle projectiles
local Projectile = {}
Projectile.__index = Projectile  -- ensures that methods work correctly when called using the colon (:) syntax

-- Function to construct a new projectile instance
function Projectile.new(serviceRef, templateName, spawnPos, launchDir, ownerPlayer)
	-- creating a table and set up inheritance so it acts like a projectile object
	local self = setmetatable({}, Projectile)
	self.Service = serviceRef  -- keeps track of the ProjectileService managing this instance
	self.Owner = ownerPlayer  -- stores who fired the projectile

	-- retrieve the projectile template model from ReplicatedStorage
	local template = ProjectileTemplates:FindFirstChild(templateName)
	if not template then
		-- if the template isn’t found, warn and exit the function
		warn("Projectile template not found:", templateName)
		return
	end

	-- cloning the projectile template to get a fresh object
	local projPart = template:Clone()
	projPart.Name = "Projectile"  -- assign a standard name for identification
	projPart.Position = spawnPos  -- place projectile at spawn position
	projPart.CFrame = CFrame.new(spawnPos, spawnPos + launchDir)  -- rotate projectile to face its launch direction
	projPart.Anchored = false  -- allow physics to affect it
	projPart.CanCollide = true  -- enable collisions with other objects
	projPart.Parent = Workspace  -- add it to the world
	CollectionService:AddTag(projPart, "Projectile")  -- tag it so other scripts can recognize it as a projectile
	self.Part = projPart  -- save a reference to the projectile’s part

	-- creating an Attachment for modern physics forces
	local attachment = Instance.new("Attachment")
	attachment.Parent = projPart
	self.Attachment = attachment  -- store reference

	-- creating a VectorForce to propel the projectile forward
	local vectorForce = Instance.new("VectorForce")
	vectorForce.Attachment0 = attachment  -- attach to projectile
	vectorForce.Force = launchDir.Unit * StartSpeed * projPart:GetMass()  -- apply initial velocity
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World  -- apply in world coordinates
	vectorForce.Parent = projPart
	self.VectorForce = vectorForce  -- store reference
	self.Velocity = launchDir.Unit * StartSpeed  -- store velocity vector

	self.StartTime = os.clock()  -- record the time the projectile was spawned
	self.HasCollided = false  -- mark it as not yet collided

	-- creating a trail by spawning small parts each frame
	RS.Heartbeat:Connect(function()
		-- stop generating trail if the projectile is destroyed or has already collided
		if not self.Part or self.HasCollided then return end

		-- spawn a small part to represent one segment of the trail
		local trailBit = Instance.new("Part")
		trailBit.Size = TrailSize  -- set size
		trailBit.Anchored = true  -- keep trail fixed in place
		trailBit.CanCollide = false  -- prevent it from blocking other objects
		trailBit.CFrame = self.Part.CFrame  -- match projectile’s current position
		trailBit.BrickColor = self.Part.BrickColor  -- match color
		trailBit.Material = self.Part.Material  -- match material
		trailBit.Parent = Workspace  -- add to world
		CollectionService:AddTag(trailBit, "ProjectileTrail")  -- tag to distinguish from other objects
		Debris:AddItem(trailBit, TrailLife)  -- schedule cleanup after short time
	end)

	-- connect collision event to HandleCollision function
	self.TouchConnection = projPart.Touched:Connect(function(hitObj)
		self:HandleCollision(hitObj)
	end)

	-- remove projectile automatically after its lifespan expires
	Debris:AddItem(projPart, ProjectileLife)

	return self  -- return the projectile instance
end

-- function that runs when projectile collides with something
function Projectile:HandleCollision(hitThing)
	-- prevent processing collision twice
	if self.HasCollided then return end

	-- ignore hitting other projectiles, trails, or cannons
	if CollectionService:HasTag(hitThing, "Projectile") 
		or CollectionService:HasTag(hitThing, "ProjectileTrail") 
		or hitThing:IsDescendantOf(CannonFolder) then
		return
	end

	-- mark the projectile as having collided
	self.HasCollided = true

	-- creating an explosion effect at the impact point
	local boom = Instance.new("Explosion")
	boom.Position = self.Part.Position
	boom.BlastRadius = 5  -- radius of explosion effect
	boom.BlastPressure = 50_000  -- force applied by explosion
	boom.Parent = Workspace

	-- play explosion sound
	local explosionSound = Instance.new("Sound")
	explosionSound.SoundId = "rbxassetid://138186576"
	explosionSound.Volume = 1
	explosionSound.PlayOnRemove = true  -- sound plays upon destruction
	explosionSound.Parent = self.Part
	explosionSound:Destroy()  -- triggers playback even when destroyed

	-- add particles for visual effect
	local explosionEffect = Instance.new("ParticleEmitter")
	explosionEffect.Texture = "rbxassetid://243098098"
	explosionEffect.Lifetime = NumberRange.new(0.5)
	explosionEffect.Rate = 100
	explosionEffect.Speed = NumberRange.new(10)
	explosionEffect.Parent = self.Part
	Debris:AddItem(explosionEffect, 2)  -- remove particles after 2 seconds

	-- spawn impact cubes at the point of impact
	for i = 1, ImpactCubeCount do
		local cube = Instance.new("Part")  -- create a new cube
		cube.Size = ImpactCubeSize  -- assign size
		cube.CFrame = self.Part.CFrame * CFrame.new(math.random(-2,2), 2, math.random(-2,2))  -- slight horizontal offset
		cube.Anchored = false  -- let physics affect cubes
		cube.CanCollide = false  -- prevent physical obstruction
		cube.Material = Enum.Material.Concrete  -- make cubes look solid
		cube.BrickColor = BrickColor.new("Dark stone grey")  -- standard debris color
		cube.Parent = Workspace  -- add cube to world

		-- attach VectorForce to launch cube upwards
		local attach = Instance.new("Attachment")
		attach.Parent = cube

		local vectorForce = Instance.new("VectorForce")
		vectorForce.Attachment0 = attach
		vectorForce.Force = Vector3.new(
			math.random(-150,150),  -- horizontal spread
			math.random(150,250),   -- upward thrust
			math.random(-150,150)   -- horizontal spread
		) * cube:GetMass()
		vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
		vectorForce.Parent = cube

		-- schedule cube cleanup after ImpactCubeLife
		Debris:AddItem(cube, ImpactCubeLife)
	end

	-- update stats if owner exists in tracking
	if self.Owner and self.Service.PlayerStats[self.Owner] then
		self.Service.PlayerStats[self.Owner].Hits += 1
	end

	-- remove projectile from world
	if self.Part then
		self.Part:Destroy()
	end
end

-- manual physics update function for projectile motion
function Projectile:Update()
	local elapsed = os.clock() - self.StartTime  -- time since spawn
	local newVel = self.Velocity + GravitySim * elapsed  -- apply gravity
	local displacement = self.Velocity * elapsed + 0.5 * GravitySim * (elapsed ^ 2)  -- compute displacement

	-- move projectile and update velocity
	if self.Part then
		self.Part.CFrame = self.Part.CFrame + displacement
		self.Velocity = newVel
	end
end

-- list holding all currently active projectiles
local activeShots = {}

-- define main ProjectileService for handling projectile logic
local ProjectileService = Knit.CreateService {
	Name = "ProjectileService",
	Client = {},  -- client-facing methods (currently unused)
	PlayerStats = {}  -- keeps track of shots fired and hits per player
}

-- function to launch a projectile from a cannon
function ProjectileService:LaunchFrom(cannon, shooter)
	local spawnPos = cannon.Position + Vector3.new(0, 2, 0)  -- spawn slightly above cannon
	local dir = cannon.CFrame.LookVector  -- direction cannon is facing
	local chosenType = cannon:GetAttribute("ProjectileType") or "Fireball"  -- default projectile type

	local newProj = Projectile.new(self, chosenType, spawnPos, dir, shooter)
	table.insert(activeShots, newProj)  -- add to active projectile list

	-- update player stats for shots fired
	if not self.PlayerStats[shooter] then
		self.PlayerStats[shooter] = { Shots = 0, Hits = 0 }
	end
	self.PlayerStats[shooter].Shots += 1
end

-- remove all active projectiles from the world
function ProjectileService:CleanupAll()
	for i = #activeShots, 1, -1 do
		local shot = activeShots[i]
		if shot and shot.Part then
			shot.Part:Destroy()
		end
		table.remove(activeShots, i)
	end
end

-- print stats for a player
function ProjectileService:PrintStats(player)
	local stats = self.PlayerStats[player]
	if stats then
		local acc = stats.Shots > 0 and (stats.Hits / stats.Shots * 100) or 0
		print(player.Name .. " | Shots: " .. stats.Shots .. " | Hits: " .. stats.Hits .. " | Accuracy: " .. math.floor(acc) .. "%")
	end
end

-- handle chat commands from the creator/admin
function ProjectileService:HandleAdminCommand(player, msg)
	if player.UserId ~= game.CreatorId then return end
	local cmd = msg:lower()  -- normalize to lowercase

	if cmd == "!clear" then
		self:CleanupAll()  -- wipe all active projectiles
	elseif cmd == "!stats" then
		for p in pairs(self.PlayerStats) do
			self:PrintStats(p)  -- display stats for all players
		end
	elseif cmd:sub(1,6) == "!kick " then
		local target = cmd:sub(7)
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Name:lower() == target then
				plr:Kick("Removed by admin")  -- remove targeted player
				break
			end
		end
	end
end

-- initialize the service
function ProjectileService:KnitStart()
	-- connect cannon click detectors to launch projectiles
	for _, cannon in ipairs(CannonFolder:GetChildren()) do
		local clicker = cannon:FindFirstChild("ClickDetector")
		if clicker then
			clicker.MouseClick:Connect(function(player)
				self:LaunchFrom(cannon, player)
			end)
		end
	end

	-- update projectiles every frame and apply gravity
	RS.Heartbeat:Connect(function()
		for i = #activeShots, 1, -1 do
			local proj = activeShots[i]
			if not proj or not proj.Part or proj.HasCollided then
				table.remove(activeShots, i)  -- remove inactive projectiles
			else
				proj:Update()  -- move active projectiles
			end
		end
	end)

	-- clear player stats when they leave
	Players.PlayerRemoving:Connect(function(p)
		self.PlayerStats[p] = nil
	end)

	-- connect chat commands for new players
	Players.PlayerAdded:Connect(function(p)
		p.Chatted:Connect(function(msg)
			self:HandleAdminCommand(p, msg)
		end)
	end)
end

-- return the service so Knit can use it
return ProjectileService
