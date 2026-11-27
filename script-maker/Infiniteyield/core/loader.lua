-- core/loader.lua
-- Loader modul command hasil splitter.
--
-- Refactored from EdgeIY/infiniteyield (MIT License).
--
-- Pemakaian di Roblox:
--   local Loader = require(script.Parent.core.loader)
--   Loader.loadAll(script.Parent.commands)
--
-- Setiap file di commands/ mengembalikan tabel:
--   { name = "fly", aliases = {"fly"}, fn = function(args, speaker) ... end }
--
-- Loader hanya mendaftarkan. Cara memanggil command tetap milik program utama
-- (misalnya untuk mengecek alias, lalu memanggil entry.fn(args, speaker)).

local Loader = {}

-- command asli, key = nama command
Loader.commands = {}

-- semua nama + alias (huruf kecil), value = nama command asli
Loader.aliases = {}

local function normalize(name)
	return string.lower(tostring(name))
end

--- Daftarkan satu command dengan pola yang seragam.
-- @param name    string  nama command
-- @param aliases table   daftar alias (boleh nil)
-- @param fn      function fungsi command(args, speaker)
function Loader.registerCommand(name, aliases, fn)
	assert(type(name) == "string" and name ~= "", "registerCommand: name harus string")
	assert(type(fn) == "function", "registerCommand: fn harus function")

	aliases = aliases or {}

	local entry = {
		name = name,
		aliases = aliases,
		fn = fn,
	}

	Loader.commands[name] = entry
	Loader.aliases[normalize(name)] = name

	for _, alias in ipairs(aliases) do
		Loader.aliases[normalize(alias)] = name
	end

	return entry
end

--- Cari command berdasarkan nama atau alias.
function Loader.get(name)
	local realName = Loader.aliases[normalize(name)]
	if realName == nil then
		return nil
	end
	return Loader.commands[realName]
end

--- Require commands/index.lua, lalu daftarkan semua modulnya.
-- @param commandsFolder Instance folder `commands` di Roblox
function Loader.loadAll(commandsFolder)
	local modules = require(commandsFolder:WaitForChild("index"))

	for _, module in ipairs(modules) do
		Loader.registerCommand(module.name, module.aliases, module.fn)
	end

	return Loader
end

return Loader
