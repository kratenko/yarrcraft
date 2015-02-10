-------------
-- YarrState
YarrState = {
	special_states={
		term=1,
		reset=1,
	},
}
YarrState.__index = YarrState

function YarrState:new(info)
	local self = setmetatable({}, self)
	self.name = info.name
	self.code = info.code
	self.results = info.results
	self.reads = info.reads or {}
	self.writes = info.writes or {}
	self.machine = nil
	self:create_sets()
	return self
end

function YarrState:verify()
	if not self.name then
		error("YarrState does not have a name.")
	end
	if YarrState.special_states[self.name] then
		error("Cannot use reserved state name '"
			..self.name.."' as a custom state name.")
	end
	if not self.code then
		error("YarrState does not have any code.")
	end
	if not self.results then
		error("YarrState does not have any result transitions.")
	end
end

function YarrState:short()
	return "<"..self.machine.name..":"..self.name..">"
end

function YarrState:create_sets()
	self.reads_set = {}
	for _, name in pairs(self.reads) do
		self.reads_set[name] = 1
	end
	self.writes_set = {}
	for _, name in pairs(self.writes) do
		self.writes_set[name] = 1
	end
end

-----------------
-- YarrMachine --
YarrMachine = {}
YarrMachine.__index = YarrMachine

-- constructor
function YarrMachine:new(name, initial, initial_values)
	local self = setmetatable({}, self)
	self.name = name or "YM"
	self.states = {}
	self.values = {}
	self.current_state = nil
	self.result = nil
	self.value_names = {}
	self.initial = initial or nil
	self.initial_values = initial_values or {}
	self.logging = true
	self:log("created new YarrMachine '"..self.name.."'")
	return self
end

-- make sure YarrMachine is fit to run
function YarrMachine:verify()
	self:log("checking YarrMachine "..self:short().." for sanity.")
	if not self.name then
		error("YarrMachine does not have a name.")
	end
	if not self.initial then
		self:error("No initial state.")
	end
	if not self.states then
		self:error("No states.")
	end
	if not self.states[self.initial] then
		self:error("Initial state '"..self.initial..
			"' is not a state in this machine.")
	end
	for name, state_o in pairs(self.states) do
		state_o:verify()
		if state_o.name ~= name then
			self:error("state '"..state_o.name..
				"' stored under wrong name '"..
				name.."'.")
		end
		for result, next_state in pairs(state_o.results) do
			if not (self.states[next_state] or YarrState.special_states[next_state]) then
				self:error("State " .. state_o:short()
					.." has invalid transition to "
					.."unknown state '"..next_state.."'.")
			end
		end
	end
end

function YarrMachine:short()
	return "<"..self.name..">"
end

function YarrMachine:log(text)
	if self.logging then
		print(self:short()..': '..text)
	end
end

function YarrMachine:error(text)
	error("<"..self.name..">: " .. text)
end

function YarrMachine:add_state(state)
	self:log("adding new state '"..state.name.."' to machine.")
	local name = state.name
	local state_o = YarrState:new(state)
	state_o:verify()
	state_o.machine = self
	self.states[name] = state_o
	-- add read values to sm value list:
	if state_o.reads then
		for k, _ in pairs(state_o.reads) do
			self.value_names[k] = 1
		end
	end
	-- add written values to sm value list:
	if state_o.writes then
		for k, _ in pairs(state_o.writes) do
			self.value_names[k] = 1
		end
	end
end


function YarrMachine:dump()
	for k, v in pairs(self.states) do
		print(k, "->", v)
	end
end


function YarrMachine:_load_values(state_o)
	values = {}
	for _, name in pairs(state_o.reads) do
		values[name] = self.values[name]
	end
	return values
end

-- check if output of state has valid result and output values
function YarrMachine:_verify_output(state_o, result, values_out)
	if not result then
		self:error("State "..state_o:short()
			.." did not return a result.")
	end
	if not state_o.results[result] then
		self:error("State "..state_o:short()
			.." returned invalid result '"..result.."'.")
	end
	if values_out then
		for k, v in pairs(values_out) do
			if not state_o.writes_set[k] then
				self:error("State "..state_o:short()
					.." illegaly tried to write to "
					.."value '"..k.."'.")
			end
		end
	end
end

-- update sm's values from state's output
function YarrMachine:_store_values(values_out)
	if values_out then
		for k, v in pairs(values_out) do
			self.values[k] = v
		end
	end
end

function YarrMachine:_values(values)
	if not values then
		return 'nil'
	end
	local s = "{"
	for k, v in pairs(values) do
		s = s..k.."="..v..','
	end
	return s .. "}"
end

function YarrMachine:_execute_state(state)
	-- get state object for state name:
	local state_o = self.states[state]
	-- get input values for state (read values):
	local values_in = self:_load_values(state_o)
	-- run state's code:
	self:log("-->entering state '".. state_o:short() .. "'")
	self:log("   input: " .. self:_values(values_in))
	result, values_out = state_o.code(values_in)
	self:log("<--leaving state '"..state_o:short().."'")
	self:log("   result: '" .. result .. "'")
	self:log("   output: " .. self:_values(values_out))
	-- make sure, output is sound:
	self:_verify_output(state_o, result, values_out)
	-- update sm's values written by executed state:
	self:_store_values(values_out)
	self:log("   current values: " .. self:_values(self.values))
	-- look up next state according to result:
	local next_state = state_o.results[result]
	self:log("   next state: '" .. next_state .. "'")
	return next_state
end

function YarrMachine:_initialize_values()
	self.values = {}
	for k, v in pairs(self.initial_values) do
		self.values[k] = v
	end
end

function YarrMachine:run(start_state)
	self:verify()
	self:log("!->Arrr! Time to get her sailin' - start running...")
	self:_initialize_values()
	self:log("   current values: " .. self:_values(self.values))
	local current_state = self.initial
	while current_state ~= 'term' do
		local next_state = self:_execute_state(current_state)
		if next_state == 'reset' then
			self:log("!-!reached 'reset' state. "
				.."Turning everything back to start.")
			self:_initialize_values()
			self:log("   current values: " .. self:_values(self.values))
			next_state = self.initial
		end
		current_state = next_state
	end

	self:log("!<-reachead 'term' state, this YarrMachine is done for.")
end

