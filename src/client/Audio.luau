--!strict
--[[
	Audio — ce qu'on entend quand un coup part, touche, ou qu'on tombe.

	POURQUOI CE MODULE EST COTE CLIENT, ET POURQUOI IL NE COUTE RIEN. Le
	serveur annonce deja chaque coup, chaque soin et chaque chute avec sa
	position, par le remote des effets. Le son se greffe sur ces memes
	annonces : pas un remote de plus, pas un octet de plus. C'est aussi ce qui
	garantit que l'image et le son partent ensemble — ils lisent le meme
	message.

	UN SON MODERE ECHOUE EN SILENCE. C'est le piege de l'audio Roblox : un
	identifiant retire, privé ou du mauvais type ne leve aucune erreur, le son
	ne sort simplement pas. `Audio.verify` recharge tout le catalogue et dit ce
	qui manque ; `Bootstrap` l'appelle au demarrage, et la console le dit.

	LE SON RENSEIGNE, IL NE DECORE PAS. Deux consequences dans le code :
	la portee est bornee (`maxDistanceStuds`), pour qu'un duel a l'autre bout
	de l'arene ne couvre pas le sien ; et chaque evenement tire sa piste au
	sort dans une plage de hauteur, parce qu'un son identique repete trois fois
	par seconde cesse d'etre un coup et devient un bruit de machine.
]]

local Audio = {}

local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Arena = ReplicatedStorage:WaitForChild("Arena")
local Config = require(Arena:WaitForChild("Config"))

-- Les sons poses dans le monde vivent la, pour ne pas semer des parts dans le
-- Workspace et pour qu'un seul `:Destroy()` nettoie tout.
local function holder(): Folder
	local existing = Workspace:FindFirstChild("ArenaAudio")
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "ArenaAudio"
	folder.Parent = Workspace
	return folder
end

local function entryFor(eventName: string): any
	return Config.sounds.events[eventName]
end

-- La piste jouee cette fois-ci, et sa hauteur. Les deux tirages sont
-- independants : deux coups de suite peuvent partager la piste sans partager
-- la hauteur.
local function pick(entry: any): (string, number)
	local assets = entry.assets
	local assetId = assets[math.random(1, #assets)]
	local low, high = entry.pitch[1], entry.pitch[2]
	return "rbxassetid://" .. assetId, low + math.random() * (high - low)
end

local function configure(sound: Sound, entry: any)
	local assetId, pitch = pick(entry)
	sound.SoundId = assetId
	sound.PlaybackSpeed = pitch
	sound.Volume = entry.volume * Config.sounds.masterVolume
end

-- Un son pose A UN ENDROIT du monde : il s'attenue avec la distance, donc il
-- dit ou se passe quelque chose, et pas seulement que quelque chose se passe.
function Audio.playAt(eventName: string, position: Vector3)
	if not Config.sounds.enabled then
		return
	end
	local entry = entryFor(eventName)
	if entry == nil then
		return
	end

	-- Une part invisible qui ne touche a rien. Elle est locale au client :
	-- elle n'existe sur aucune autre machine et ne peut rien bousculer.
	local anchor = Instance.new("Part")
	anchor.Name = "ArenaSound"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Position = position

	local sound = Instance.new("Sound")
	configure(sound, entry)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = Config.sounds.minDistanceStuds
	sound.RollOffMaxDistance = Config.sounds.maxDistanceStuds
	sound.Parent = anchor

	anchor.Parent = holder()
	sound:Play()

	-- ON NE PEUT PAS CALCULER LA DUREE ICI. Verifie en jeu le 26 octobre 2026 :
	-- `TimeLength` vaut 0 a l'instant ou on pose le son, meme pour une piste
	-- deja prechargee, parce qu'elle arrive de facon asynchrone cote client. Un
	-- nettoyage calcule sur `TimeLength` retombe donc TOUJOURS sur son repli, et
	-- les sons s'empilent. On ecoute la fin reelle du son a la place.
	sound.Ended:Once(function()
		anchor:Destroy()
	end)

	-- Et un filet, pour deux choses differentes. `maxSeconds` COUPE volontairement
	-- une piste trop longue pour son evenement : sans ca un impact de deux
	-- secondes sonne encore quand le coup suivant part, et une serie de coups
	-- devient un bourdon. Sans `maxSeconds`, le filet sert seulement a ce qu'une
	-- piste qui n'arrive jamais ne laisse pas une part derriere elle.
	Debris:AddItem(anchor, entry.maxSeconds or 6)
end

-- Un son sans lieu : l'interface, la fin d'une manche. Il ne s'attenue pas,
-- parce qu'il ne vient de nulle part.
function Audio.play(eventName: string)
	if not Config.sounds.enabled then
		return
	end
	local entry = entryFor(eventName)
	if entry == nil then
		return
	end
	local sound = Instance.new("Sound")
	configure(sound, entry)
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
end

-- Le son de l'arme qui porte ce coup. `voice` arrive du serveur avec
-- l'annonce du coup ; une classe sans arme equipee retombe sur les poings.
function Audio.voice(voice: string?): any
	local name = voice or Config.sounds.defaultVoice
	local found = Config.sounds.voices[name]
	if found == nil then
		return Config.sounds.voices[Config.sounds.defaultVoice]
	end
	return found
end

-- Recharge tout le catalogue et renvoie la liste de ce qui n'est PAS arrive.
-- Un identifiant modere ne leve aucune erreur : sans cette verification, le
-- jeu devient muet et personne ne sait pourquoi.
function Audio.verify(): { string }
	local probes: { Instance } = {}
	local names: { [string]: string } = {}

	for eventName, entry in Config.sounds.events do
		for _, assetId in entry.assets do
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://" .. assetId
			sound.Parent = SoundService
			table.insert(probes, sound)
			names[sound.SoundId] = eventName
		end
	end

	local missing: { string } = {}
	local ok = pcall(function()
		ContentProvider:PreloadAsync(probes, function(id, status)
			if status ~= Enum.AssetFetchStatus.Success then
				table.insert(
					missing,
					(names[id] or "?") .. " : " .. id .. " (" .. tostring(status) .. ")"
				)
			end
		end)
	end)
	if not ok then
		table.insert(missing, "le prechargement lui-meme a echoue")
	end

	for _, probe in probes do
		probe:Destroy()
	end
	return missing
end

function Audio.start()
	if not Config.sounds.enabled then
		print("[Arena] Son désactivé dans Config.sounds.enabled.")
		return
	end

	-- Le prechargement sert deux choses a la fois : il evite le silence du
	-- tout premier coup, le temps que la piste arrive, et il dit ce qui
	-- manque. On ne bloque pas le demarrage du client pour autant.
	task.spawn(function()
		local missing = Audio.verify()
		if #missing == 0 then
			local count = 0
			for _ in Config.sounds.events do
				count += 1
			end
			print("[Arena] Son : " .. count .. " évènements, toutes les pistes chargées.")
			return
		end
		warn(
			"[Arena] "
				.. #missing
				.. " son(s) introuvable(s) — ils seront muets, sans autre erreur :\n  "
				.. table.concat(missing, "\n  ")
		)
	end)
end

return Audio
