local FakeAreaTrigger = class()
function FakeAreaTrigger:init(params)
	self._id = params.id
	self._position = Vector3(params.x,params.y,params.z)
	self._radius = params.radius
	self._slotmask = params.slotmask or managers.slot:get_mask("players")
	self._active = params.start_active
	self._message = params.message
	self._sound_path = params.sound
	
	self._debug_color = Color.red:with_alpha(0.6)
end

function FakeAreaTrigger:active()
	return self._active
end

function FakeAreaTrigger:set_active(state)
	self._active = state
end

function FakeAreaTrigger:update(t,dt)
	local player = managers.player:local_player()
	if alive(player) then
		for _,unit in pairs(World:find_units_quick("sphere",self._position,self._radius,self._slotmask)) do 
			if unit == player then
				return true
			end
		end
	end
end

-- on triggered
function FakeAreaTrigger:on_trigger()
	if self._message then
		managers.chat:_receive_message(ChatManager.GAME, managers.localization:to_upper_text("menu_system_message"), self._message, tweak_data.system_chat_color)
	end
	if self._sound_path then
		XAudio.UnitSource:new(XAudio.PLAYER,XAudio.Buffer:new(self._sound_path))
	end
end

-- debug only
function FakeAreaTrigger:draw(t,dt)
	Draw:brush(self._debug_color:with_alpha(0.5)):sphere(self._position,self._radius)
end

function FakeAreaTrigger:pre_destroy()
	
end

return FakeAreaTrigger