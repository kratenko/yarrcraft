require 'sm'

s1 = {
	name="start",
	results={
		
	},
	code=function()
		print "nice..."
		return ''
	end
}

wait_signal = {
	name="wait_signal",
	results={
		timeout='wait_signal',
		button_pressed='open_door',
	},
	writes={'button'},
	code=function()
		return 'button_pressed', {button=1}
	end
}

open_door = {
	name="open_door",
	results={
		done='term',
	},
	code=function()
		return 'done'
	end
}

m = YarrMachine:new()
m:add_state(wait_signal)
m:add_state(open_door)

m.initial = "wait_signal"
m:run('wait_signal')

