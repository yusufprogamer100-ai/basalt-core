--!strict
-- Basalt / design / Typography
-- Builder is Roblox's own platform family, bundled with the client, and reads
-- cleanly at 11px. Mono is used for numbers only, where tabular alignment
-- stops values from jittering while a slider moves.

export type Role = "title" | "body" | "small" | "mono"

local SANS = { "BuilderSans", "Montserrat", "SourceSans" }
local MONO = { "BuilderMono", "RobotoMono" }

local WEIGHTS = {
	title = Enum.FontWeight.Bold,
	body = Enum.FontWeight.Regular,
	small = Enum.FontWeight.Medium,
	mono = Enum.FontWeight.Regular,
}

local FALLBACK_ENUM = {
	title = Enum.Font.BuilderSansBold,
	body = Enum.Font.BuilderSans,
	small = Enum.Font.BuilderSansMedium,
	mono = Enum.Font.RobotoMono,
}

local cache: { [string]: Font } = {}

local Typography = {}

local function tryFromName(name: string, weight: Enum.FontWeight): Font?
	local ok, face = pcall(function()
		return Font.fromName(name, weight, Enum.FontStyle.Normal)
	end)
	if ok and face then
		return face
	end
	return nil
end

function Typography.Resolve(role: Role): Font
	local cached = cache[role]
	if cached then
		return cached
	end

	local families = if role == "mono" then MONO else SANS
	local weight = WEIGHTS[role]

	for _, name in ipairs(families) do
		local face = tryFromName(name, weight)
		if face then
			cache[role] = face
			return face
		end
	end

	-- Last resort: the legacy enum, which every client ships.
	local enumFace = FALLBACK_ENUM[role]
	local ok, face = pcall(function()
		return Font.fromEnum(enumFace)
	end)
	if ok and face then
		cache[role] = face
		return face
	end

	error("Basalt: no usable font for role '" .. role .. "'", 2)
end

function Typography.Reset()
	table.clear(cache)
end

return Typography
