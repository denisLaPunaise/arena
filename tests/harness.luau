--!strict
--[[
	harness — le minimum pour ecrire des tests lisibles sans dependance externe.

	Un test est une fonction qui recoit ce harnais et appelle ses assertions.
	Aucune magie : si une assertion echoue, elle est enregistree et le test
	continue, ce qui permet de voir toutes les erreurs d'un coup plutot qu'une
	par execution.
]]

export type Harness = {
	section: (string) -> (),
	check: (string, boolean) -> (),
	equal: (string, unknown, unknown) -> (),
	failures: () -> number,
	total: () -> number,
}

local function create(): Harness
	local failures = 0
	local total = 0

	local function section(title: string)
		print("")
		print("-- " .. title)
	end

	local function check(label: string, condition: boolean)
		total += 1
		if condition then
			print("   ok   " .. label)
		else
			failures += 1
			print("  ECHEC " .. label)
		end
	end

	local function equal(label: string, actual: unknown, expected: unknown)
		total += 1
		if actual == expected then
			print("   ok   " .. label)
		else
			failures += 1
			print(string.format("  ECHEC %s (obtenu %s, attendu %s)", label, tostring(actual), tostring(expected)))
		end
	end

	return {
		section = section,
		check = check,
		equal = equal,
		failures = function()
			return failures
		end,
		total = function()
			return total
		end,
	}
end

return { create = create }
