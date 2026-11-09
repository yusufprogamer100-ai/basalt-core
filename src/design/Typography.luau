--!strict
-- Basalt / design / Typography
-- Builder is Roblox's own platform family, bundled with the client, and reads
-- cleanly at 11px. Mono is used for numbers only, where tabular alignment
-- stops values from jittering while a slider moves.

export type Role = "caption" | "body" | "bodyLg" | "h3" | "h2" | "h1" | "mono"

local SANS = { "BuilderSans", "Montserrat", "SourceSans" }
local MONO = { "BuilderMono", "RobotoMono" }

local WEIGHTS = {
	h3 = Enum.FontWeight.Bold,
	body = Enum.FontWeight.Regular,
	bodyLg = Enum.FontWeight.Medium,
	mono = Enum.FontWeight.Regular,
}

local FALLBACK_ENUM = {
	h3 = Enum.Font.BuilderSansBold,
	body = Enum.Font.BuilderSans,
	bodyLg = Enum.Font.BuilderSansMedium,
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

	-- Try configured families first.
	for _, name in ipairs(families) do
		local face = tryFromName(name, weight)

		if face then
			cache[role] = face

			return face
		end
	end

	-- Try all fallback families as secondary options.
	local allFamilies = { "BuilderSans", "Montserrat", "SourceSans", "BuilderMono", "RobotoMono" }

	for _, name in ipairs(allFamilies) do
		local face = tryFromName(name, weight)

		if face then
			cache[role] = face

			return face
		end
	end

	-- Last resort: legacy enum fonts which every Roblox client ships.
	local enumFace = FALLBACK_ENUM[role]
	local ok, face = pcall(function()
		return Font.fromEnum(enumFace)
	end)

	if ok and face then
		cache[role] = face

		return face
	end

	-- Absolute last resort: try System font via pcall without throwing.
	local systemFace = pcall(function()
		return Font.fromEnum(Enum.Font.BuilderSans)
	end)

	if systemFace then
		cache[role] = systemFace

		return systemFace
	end

	-- Should never reach here, but if we do, avoid crashing executors.
	local dummy = Font.fromEnum(Enum.Font.BuilderSansBold)
	cache[role] = dummy

	return dummy
end

function Typography.Reset()
	table.clear(cache)
end

return Typography
