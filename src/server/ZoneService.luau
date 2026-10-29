--!strict
--[[
	ZoneService — la couche mince qui dessine la zone et la fait mordre.

	Tout le calcul est dans Zone, qui est pur et teste hors de Studio. Ici on
	ne fait que trois choses : fabriquer le cylindre, le redimensionner quand
	le palier change, et demander a CombatService de retirer des PV a ceux qui
	sont dehors.

	Le cylindre est construit a chaque manche et detruit a la fin. Il vit dans
	Workspace, donc en dehors de Git : si quelqu'un le trouve dans l'explorateur
	apres un test interrompu, il peut le supprimer sans rien casser.

	Le rayon change d'un coup, pas progressivement, et l'affichage suit a
	l'identique. Une bordure qui glisse pendant que les degats suivent une
	autre regle est la meilleure facon de rendre un systeme injuste.
]]

local ZoneService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))
local Zone = require(Arena:WaitForChild("Zone"))

local CALM_COLOR = Color3.fromRGB(90, 150, 220)
local WARNING_COLOR = Color3.fromRGB(230, 120, 60)
local CLOSED_COLOR = Color3.fromRGB(210, 70, 70)

local FLASH_SECONDS = Config.round.zoneFlashSeconds

export type Snapshot = {
	radius: number,
	step: number,
	secondsUntilNextShrink: number?,
	warning: boolean,
	closed: boolean,
}

local wall: Part? = nil
local center = Vector3.zero
local startRadius = 0
local startedAt = 0
local lastStep = -1
local active = false

local function destroyWall()
	local existing = wall
	if existing then
		existing:Destroy()
	end
	wall = nil
end

-- Un cylindre Roblox est couche sur l'axe X : il faut le redresser.
local function wallCFrame(): CFrame
	return CFrame.new(center.X, center.Y + (Config.round.zoneHeightStuds / 2), center.Z)
		* CFrame.Angles(0, 0, math.rad(90))
end

local function sizeFor(radius: number): Vector3
	return Vector3.new(Config.round.zoneHeightStuds, radius * 2, radius * 2)
end

local function createWall(radius: number)
	destroyWall()

	local part = Instance.new("Part")
	part.Name = "ArenaZone"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.ForceField
	part.Color = CALM_COLOR
	part.Transparency = 0.82
	part.Size = sizeFor(radius)
	part.CFrame = wallCFrame()
	part.Parent = Workspace

	wall = part
end

local function colorFor(snapshot: Snapshot): Color3
	if snapshot.closed then
		return CLOSED_COLOR
	end
	return if snapshot.warning then WARNING_COLOR else CALM_COLOR
end

-- Un eclat bref au moment du resserrement : c'est le seul signal qui dit
-- "ca vient de bouger", et sans lui le changement passe inapercu.
local function flash(part: Part)
	part.Transparency = 0.55
	TweenService:Create(part, TweenInfo.new(FLASH_SECONDS), { Transparency = 0.82 }):Play()
end

function ZoneService.snapshot(): Snapshot
	local elapsed = os.clock() - startedAt
	return {
		radius = Zone.radiusAt(Config, startRadius, elapsed),
		step = Zone.stepAt(Config, elapsed),
		secondsUntilNextShrink = Zone.secondsUntilNextShrink(Config, elapsed),
		warning = Zone.isWarning(Config, elapsed),
		closed = Zone.isClosed(Config, elapsed),
	}
end

function ZoneService.isActive(): boolean
	return active
end

function ZoneService.distanceFromCenter(position: Vector3): number
	-- Distance horizontale seulement : sauter ne doit pas mettre a l'abri.
	return (Vector3.new(position.X, 0, position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
end

function ZoneService.isOutside(position: Vector3): boolean
	if not active then
		return false
	end
	return Zone.isOutside(ZoneService.distanceFromCenter(position), ZoneService.snapshot().radius)
end

-- Demarre la zone pour une manche. mapWidthStuds vient de MapBounds.
function ZoneService.start(zoneCenter: Vector3, mapWidthStuds: number?)
	if not Config.round.zoneEnabled then
		return
	end

	center = zoneCenter
	startRadius = Zone.startRadiusFor(Config, mapWidthStuds)
	startedAt = os.clock()
	lastStep = 0
	active = true

	createWall(startRadius)
end

function ZoneService.stop()
	active = false
	lastStep = -1
	destroyWall()
end

-- Les degats a appliquer sur cet intervalle a qui se trouve dehors. Le retrait
-- des PV se fait dans CombatService, qui est le seul endroit du jeu ou les PV
-- bougent : deux chemins differents vers les degats, c'est deux bugs.
function ZoneService.damageFor(deltaSeconds: number): number
	return Zone.damageFor(Config, deltaSeconds)
end

local function onHeartbeat()
	if not active then
		return
	end

	local snapshot = ZoneService.snapshot()
	local part = wall
	if part == nil then
		return
	end

	if snapshot.step ~= lastStep then
		part.Size = sizeFor(snapshot.radius)
		part.CFrame = wallCFrame()
		if lastStep >= 0 then
			flash(part)
		end
		lastStep = snapshot.step
	end

	part.Color = colorFor(snapshot)
end

function ZoneService.init()
	RunService.Heartbeat:Connect(onHeartbeat)
end

return ZoneService
