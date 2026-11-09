--!strict
-- Basalt / runtime / Input
-- Every keyboard shortcut lives in this one table. Components never listen for
-- a key themselves, so two controls cannot both claim Enter, and a user who
-- remaps a shortcut does it in one place.
--
-- Shortcut claims are global on purpose: two Basalt instances in the same game
-- must not fight over RightShift. The claim table is the only mutable state the
-- library keeps outside an App, and it holds nothing but key names.

export type Action =
	"next"
	| "previous"
	| "up"
	| "down"
	| "left"
	| "right"
	| "activate"
	| "escape"
	| "search"
	| "nudgeUp"
	| "nudgeDown"

export type Binding = {
	key: Enum.KeyCode,
	shift: boolean?,
}

export type Claim = {
	key: Enum.KeyCode,
	release: () -> (),
}

local Input = {}

Input.Actions = {
	next = { key = Enum.KeyCode.Tab },
	previous = { key = Enum.KeyCode.Tab, shift = true },
	up = { key = Enum.KeyCode.Up },
	down = { key = Enum.KeyCode.Down },
	left = { key = Enum.KeyCode.Left },
	right = { key = Enum.KeyCode.Right },
	activate = { key = Enum.KeyCode.Return },
	escape = { key = Enum.KeyCode.Escape },
	search = { key = Enum.KeyCode.Slash },
	nudgeUp = { key = Enum.KeyCode.Equals },
	nudgeDown = { key = Enum.KeyCode.Minus },
} :: { [string]: Binding }

Input.ToggleCandidates = {
	Enum.KeyCode.RightShift,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.Insert,
}

local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local function globalStore(): { [string]: any }?
	local ok, environment = pcall(getfenv, 0)

	if not ok or type(environment) ~= "table" then
		return nil
	end

	local writable = pcall(function()
		environment.__BASALT_PROBE = true
	end)

	environment.__BASALT_PROBE = nil

	if not writable then
		return nil
	end

	local claims = environment.__BASALT_KEY_CLAIMS

	if type(claims) ~= "table" then
		claims = {}
		environment.__BASALT_KEY_CLAIMS = claims
	end

	return claims
end

local function shiftHeld(isDown: ((Enum.KeyCode) -> boolean)?): boolean
	if not isDown then
		return false
	end

	local ok, value = pcall(function()
		return isDown(Enum.KeyCode.LeftShift) == true or isDown(Enum.KeyCode.RightShift) == true
	end)

	return ok and value == true
end

function Input.ActionFor(input: any, isDown: ((Enum.KeyCode) -> boolean)?): Action?
	if type(input) ~= "table" or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return nil
	end

	local key = input.KeyCode

	if key == Enum.KeyCode.Tab then
		return if shiftHeld(isDown) then "previous" else "next"
	end

	-- Space activates like Enter, but is not listed twice in the table.
	if key == Enum.KeyCode.Space then
		return "activate"
	end

	for action, binding in pairs(Input.Actions) do
		if binding.key == key and not binding.shift then
			return action :: Action
		end
	end

	return nil
end

-- 1..9 are tab shortcuts only when they arrive without a modifier; the number
-- row is also used for typing inside a TextBox, which the Window filters out
-- before this is ever called.
function Input.Number(input: any, isDown: ((Enum.KeyCode) -> boolean)?): number?
	if type(input) ~= "table" or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return nil
	end

	if shiftHeld(isDown) then
		return nil
	end

	local index = table.find(NUMBER_KEYS, input.KeyCode)

	if index then
		return index
	end

	return nil
end

-- Claims the first free candidate. With no global store (a sandboxed host that
-- forbids writes) the preferred key still works, the conflict warning is simply
-- not available.
function Input.Claim(candidates: { Enum.KeyCode }): Claim
	local list = if #candidates > 0 then candidates else Input.ToggleCandidates
	local claims = globalStore()

	if not claims then
		return {
			key = list[1],
			release = function() end,
		}
	end

	for _, key in ipairs(list) do
		if claims[key.Name] ~= true then
			claims[key.Name] = true

			return {
				key = key,
				release = function()
					claims[key.Name] = nil
				end,
			}
		end
	end

	-- Every candidate is taken. Returning nil is honest: the caller tells the
	-- user that this window has no toggle key instead of stealing another's.
	return nil :: any
end

return Input
