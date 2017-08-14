local type, setmetatable, tostring, select, unpack = type, setmetatable, tostring, select, unpack
local tinsert, ioo, iop, osrem = table.insert, io.open, io.popen, os.remove

local tmpfile = os.tmpname()
local _EXIT = "exit"
local _SIGNAL = "signal"
local _TABLE = "table"
local _FUNC, _STR, _NUM, _BOOL = "function", "string", "number", "boolean"
local _TRIM = "^%s*(.-)%s*$"
local ignoreKeys = {
	["__cmd"] = true,
	["__input"] = true,
	["__exitcode"] = true,
	["__signal"] = true,
}

local function posixify(key, value)
	if ignoreKeys[key] then return "" end
	if type(key) == "function" then key = key(value) end
	if type(key) ~= "string" then return "" end
	local t = type(value)
	if t == _FUNC then
		value = value(key)
		t = type(value)
		-- Silent return if the funcref returns nil.
		if t == "nil" then return "" end
	end

	if #key == 1 then key = " -" .. key
	else
		key = key:gsub("_", "-")
		key = " --" .. key
	end

	if t == _STR then
		-- Return --key='value'
		if #value > 0 then return key .. "='" .. value .. "'" end
		return "" -- 'value' is zero-length, so return nothing
	end
	if t == _NUM then
		-- Return --key=value
		return key .. "=" .. tostring(value)
	end
	if t == _BOOL then
		if value == true then return key end
		return ""
	end
	error("invalid argument type", t, a)
end

local process
process = function(n, s, ...)
	for i = 1, n do
		local a = (select(i, ...))
		if type(a) == _TABLE then
			if a.__input then
				local f = ioo(tmpfile, "w")
				f:write(a.__input)
				f:close()
				s = s .. " <" .. tmpfile
			end
			if #a ~= 0 then
				s = s .. process(#a, s, unpack(a))
			else
				for k, v in pairs(a) do s = s .. posixify(k, v) end
			end
		else
			s = s .. " " .. tostring(a)
		end
	end
	return s
end

-- returns a function that executes the command with given args and returns its
-- output, exit status etc
local command
command = function(cmd)
	return function(...)
		local s = cmd
		local n = select("#", ...)
		if n ~= 0 then s = cmd .. process(n, "", ...) end

		local p = iop(s, "r")
		local output = p:read("*a")
		local _, exit, status = p:close()
		osrem(tmpfile)

		-- If you add new keys here, add them to ignoreKeys
		return setmetatable({
			__cmd = s,
			__input = output,
			__exitcode = exit == _EXIT and status or 127,
			__signal = exit == _SIGNAL and status or 0
		}, {
			__index = function(_, k) return command(k) end,
			__tostring = function(self) return self.__input:match(_TRIM) end
		})
	end
end

-- allow to call sh to run shell commands
return setmetatable({
	command = command,
	fork = "folknor",
	version = 2,
}, {
	__div = function(_, v) return command(v) end,
	__call = function(_, ...)
		local n = select("#", ...)
		if n == 1 then return command(...) end
		local ret = {}
		for i = 1, n do
			ret[#ret+1] = command((select(i, ...)))
		end
		return unpack(ret)
	end
})
