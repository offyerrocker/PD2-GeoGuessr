
GeoGuessr = _G.GeoGuessr or {}
GeoGuessr._mod_path = ModPath
GeoGuessr._SAVE_PATH = SavePath .. "geoguessr_settings.json" -- not used
GeoGuessr._TRIGGER_PATH = SavePath .. "geoguessr_triggers.json"
GeoGuessr._API_VERSION = 1
GeoGuessr._saved_triggers = {}
GeoGuessr._current_triggers = {}
GeoGuessr._require = {}


function GeoGuessr:require(path)
	if path then
		if self._require[path] then
			return self._require[path]
		else
			local class = blt.vm.dofile(self._mod_path .. path .. ".lua")
			self._require[path] = class
			return class
		end
	else
		error("GeoGuessr:require() No path!")
	end
end

function GeoGuessr:OnMapChanged(level_id)
	self:ClearCurrentTriggers()
	
	for _,params in pairs(self._saved_triggers) do 
		if table.contains(params.levels,level_id) then
			self:InstantiateTrigger(params)
		end
	end
end

function GeoGuessr:ClearCurrentTriggers()
	for k,trigger in pairs(self._current_triggers) do 
		trigger:pre_destroy()
		self._current_triggers[k] = nil
	end
end

function GeoGuessr:Setup()
	blt.xaudio.setup()
	
	Hooks:Add("GameSetupUpdate", "GeoGuessr_update",callback(self,self,"Update"))
end

function GeoGuessr:Update(t,dt)
	for i=#self._current_triggers,1,-1 do 
		local trigger = self._current_triggers[i]
		if trigger:active() and trigger:update(t,dt) then
			trigger:on_trigger()
			trigger:set_active(false)
		end
	end
end

function GeoGuessr:VerifySavedTriggerData(params)
	-- slotmask optional
	-- sound optional
	-- message optional
	
	if params.api_version ~= self._API_VERSION then
		return false,string.format("Version mismatch! %i, %i",params.api_version,self._API_VERSION)
	end
	if not params.id then 
		return false,"Missing id!"
	end
	if type(params.levels) ~= "table" then 
		return false,"Missing levels!"
	end
	
	local x,y,z = params.x,params.y,params.z
	--[[
	local pos = params.position or params.pos
	if pos then
		local pos_type = type(params.pos)
		if type(pos.unpack) == "function" then
			x,y,z = pos:unpack()
		else
			return false,"Invalid position!"
		end
	end
	--]]
	
	if type(x)~="number" or type(y)~="number" or type(z)~="number" then
		return false,"Invalid coordinates!"
	end
	
	if type(params.radius) ~= "number" then
		return false,"Invalid radius!"
	end
	
	return true,params
end

function GeoGuessr:InstantiateTrigger(params)
	local FakeAreaTrigger = self:require("lua/FakeAreaTrigger")
	local trigger = FakeAreaTrigger:new(params)
	table.insert(self._current_triggers,#self._current_triggers+1,trigger)
end

function GeoGuessr:RemoveCurrentTrigger(id)
	for i,trigger in pairs(self._current_triggers) do 
		if trigger.id == id then
			trigger:pre_destroy()
			return table.remove(self._current_triggers,i)
		end
	end
end
function GeoGuessr:GetCurrentTrigger(id)
	for i,trigger in pairs(self._current_triggers) do 
		if trigger.id == id then
			return trigger
		end
	end
end

function GeoGuessr:AddSavedTrigger(params)
	self._saved_triggers[params.id] = params
	if managers.job and table.contains(params.levels,managers.job:current_level_id()) then
		self:InstantiateTrigger(params)
	end
end

function GeoGuessr.encodePos(x,y,z)
	--return string.format("$%x",x),string.format("$%x",y),string.format("$%x",z)
	return x,y,z
end

function GeoGuessr.decodePos(x,y,z)
	--return tonumber("0x"..string.gsub(x,"$","")),tonumber("0x"..string.gsub(y,"$","")),tonumber("0x"..string.gsub(z,"$",""))
	return x,y,z
end

function GeoGuessr:SaveTriggers()
	local file = io.open(self._TRIGGER_PATH,"w+")
	if file then
		local saves = {}
		for _,trigger in pairs(self._saved_triggers) do 
			local saved_trigger = table.deep_map_copy(trigger)
			saved_trigger.x,saved_trigger.y,saved_trigger.z = self.encodePos(saved_trigger.x,saved_trigger.y,saved_trigger.z)
			table.insert(saves,saved_trigger)
		end
		file:write(json.encode(saves))
		file:close()
	end
end

function GeoGuessr:LoadTriggers()
	local file = io.open(self._TRIGGER_PATH, "r")
	if file then
		for _,params in pairs(json.decode(file:read("*all"))) do
			params.x,params.y,params.z = self.decodePos(params.x,params.y,params.z)
			local success,err = self:VerifySavedTriggerData(params)
			if success then
				--log("Loading trigger:",params.id)
				self:AddSavedTrigger(params)
			else
				log(string.format("GeoGuessr:LoadTriggers() Could not load trigger %s: %s",params.id,err))
			end
		end
	end
end

-- not used
function GeoGuessr:SaveSettings()
	local file = io.open(self._SAVE_PATH,"w+")
	if file then
		file:write(json.encode(self._settings))
		file:close()
	end
end

-- not used
function GeoGuessr:LoadSettings()
	local file = io.open(self._SAVE_PATH, "r")
	if file then
		for k, v in pairs(json.decode(file:read("*all"))) do
			self._settings[k] = v
		end
	end
end

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_geoguessr", function(menu_manager)
	--GeoGuessr:LoadSettings()
	GeoGuessr:LoadTriggers()
	--MenuHelper:LoadFromJsonFile(GeoGuessr._SAVE_PATH, GeoGuessr, GeoGuessr._settings)
end)

Hooks:Add("BaseNetworkSessionOnLoadComplete","BaseNetworkSessionOnLoadComplete_geoguessr",function()
	GeoGuessr:OnMapChanged(managers.job:current_level_id())
end)

GeoGuessr:Setup()
