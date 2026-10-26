--!strict
--[[
	Tests du catalogue sonore.

	CE QUE CES TESTS PEUVENT ET CE QU'ILS NE PEUVENT PAS. Ils ne disent pas si
	un son est beau, ni meme s'il ressemble a un coup d'epee : ca demande une
	oreille, et c'est le travail de Josh. Ils attrapent la seule panne sonore
	qui ne se voit JAMAIS en jouant — une famille d'armes qui pointe vers un
	evenement inexistant, ou une arme dont la voix n'est declaree nulle part.
	Dans les deux cas, le jeu ne leve aucune erreur : il devient muet pour cette
	arme-la, et personne ne sait pourquoi.

	La verification des identifiants eux-memes ne peut pas se faire ici : un son
	modere echoue en silence et seul Roblox sait lequel. C'est
	`Audio.verify`, au demarrage du client, qui s'en charge.
]]

local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("Le catalogue tient debout")

	local sounds = Config.sounds
	t.equal("il y a un volume d'ensemble", typeof(sounds.masterVolume), "number")
	t.equal(
		"la portee d'un son est bornee, et la borne haute est la plus haute",
		sounds.minDistanceStuds < sounds.maxDistanceStuds,
		true
	)

	for name, event in sounds.events do
		t.equal("« " .. name .. " » a au moins une piste", #event.assets >= 1, true)
		t.equal("« " .. name .. " » a un volume", typeof(event.volume), "number")
		t.equal(
			"« " .. name .. " » a une plage de hauteur dans le bon ordre",
			event.pitch[1] > 0 and event.pitch[1] <= event.pitch[2],
			true
		)
		if event.maxSeconds ~= nil then
			t.equal(
				"la coupe de « " .. name .. " » laisse entendre quelque chose",
				event.maxSeconds > 0.2,
				true
			)
		end
		for _, assetId in event.assets do
			t.equal(
				"« " .. name .. " » ne porte que des identifiants numeriques",
				tonumber(assetId) ~= nil,
				true
			)
		end
	end

	t.section("Chaque voix joue quelque chose qui existe")

	-- C'est LE test qui compte. Une voix qui pointe vers un evenement absent ne
	-- leve rien : l'arme devient muette, et c'est tout.
	for voiceName, voice in sounds.voices do
		t.equal(
			"la voix « " .. voiceName .. " » a un son de depart qui existe",
			sounds.events[voice.swing] ~= nil,
			true
		)
		t.equal("et un son d'impact qui existe", sounds.events[voice.hit] ~= nil, true)
	end

	t.equal("la voix par defaut est declaree", sounds.voices[sounds.defaultVoice] ~= nil, true)

	t.section("Chaque arme a une voix declaree")

	for _, item in Config.items do
		if item.category ~= "primary" and item.category ~= "secondary" then
			continue
		end
		local look = item.look
		t.equal("« " .. item.id .. " » a une allure", look ~= nil, true)
		if look == nil then
			continue
		end
		t.equal(
			"« " .. item.id .. " » nomme une voix connue",
			look.voice ~= nil and sounds.voices[look.voice] ~= nil,
			true
		)
	end

	t.section("Les sons sans arme sont la aussi")

	-- Une chute et une explosion ne passent pas par une voix d'arme : elles
	-- sont nommees en dur dans le client, donc elles doivent exister ici.
	t.equal("le son de la chute existe", sounds.events.down ~= nil, true)
	t.equal("celui de l'explosion aussi", sounds.events.blast ~= nil, true)

	t.section("L'impact arrive apres le coup, pas avec lui")

	t.equal("le decalage est positif", sounds.hitDelaySeconds > 0, true)
	-- Plus long que le depart du geste, et le son d'impact arriverait apres que
	-- l'arme a commence a revenir : l'oeil et l'oreille se contrediraient.
	t.equal(
		"et il tient dans le geste de l'arme",
		sounds.hitDelaySeconds <= Config.loadout.weaponMotion.outSeconds,
		true
	)
end
