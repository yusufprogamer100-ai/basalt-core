--!strict
-- Basalt / core / Error
-- One reporting path for every caught failure. The rule: a pcall without a
-- report is a silent failure, and silent failures are bugs.

export type Report = {
	context: string,
	message: string,
	time: number,
}

local MAX_HISTORY = 24

local Error = {
	verbose = false,
}

local history: { Report } = {}
local seen: { [string]: boolean } = {}
local handler: ((report: Report) -> ())? = nil
local total = 0

local function describe(err: any): string
	if type(err) == "string" then
		return err
	end

	if type(err) == "table" then
		local message = (err :: any).message
		if type(message) == "string" then
			return message
		end
	end

	return tostring(err)
end

function Error.SetHandler(fn: ((report: Report) -> ())?)
	handler = fn
end

function Error.Report(context: string, err: any)
	total += 1

	local report: Report = {
		context = context,
		message = describe(err),
		time = os.clock(),
	}

	table.insert(history, report)
	if #history > MAX_HISTORY then
		table.remove(history, 1)
	end

	local key = context .. "\0" .. report.message
	local first = not seen[key]
	seen[key] = true

	if handler then
		local ok = pcall(handler, report)
		if not ok then
			warn("[Basalt] error handler failed: " .. report.message)
		end
	end

	-- Repeat failures stay quiet unless verbose is on. The count is still kept.
	if first or Error.verbose then
		warn(string.format("[Basalt] %s: %s", context, report.message))
	end
end

function Error.Count(): number
	return total
end

function Error.History(): { Report }
	return table.clone(history)
end

function Error.Reset()
	table.clear(history)
	table.clear(seen)
	total = 0
end

return Error
