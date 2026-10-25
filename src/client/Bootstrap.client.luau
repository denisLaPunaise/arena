--!strict
--[[
	Bootstrap — point d'entree client.

	Deux responsabilites, et pas une de plus : envoyer l'intention d'attaque,
	et afficher ce que le serveur annonce. Aucun calcul de degats, aucune
	decision : le serveur est seul juge.

	L'attaque est sur le clic ET sur le tap, parce qu'une bonne partie des
	joueurs Roblox sont sur telephone.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Remotes = Arena:WaitForChild("Remotes")
local attackRemote = Remotes:WaitForChild("Attack") :: RemoteEvent
local hudRemote = Remotes:WaitForChild("Hud") :: RemoteEvent

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function makeLabel(name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.TextSize = textSize
	label.TextScaled = false
	label.Text = ""
	return label
end

local gui = Instance.new("ScreenGui")
gui.Name = "ArenaHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local status = makeLabel("Status", UDim2.fromScale(1, 0.06), UDim2.fromScale(0.5, 0.06), 20)
status.Parent = gui

local title = makeLabel("Title", UDim2.fromScale(1, 0.14), UDim2.fromScale(0.5, 0.3), 44)
title.Parent = gui

local hint = makeLabel("Hint", UDim2.fromScale(1, 0.05), UDim2.fromScale(0.5, 0.94), 16)
hint.Text = "Clic ou tap pour frapper"
hint.TextTransparency = 0.35
hint.Parent = gui

hudRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	title.Text = payload.title or ""
	status.Text = payload.status or ""
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end

	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		attackRemote:FireServer()
	end
end)

print(string.format("[Arena] Client démarré pour %s", player.Name))
