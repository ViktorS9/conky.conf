-- Conky Lua scripting example
--
-- In your conkyrc, use ${lua string_func} to call conky_string_func(), ${lua
-- int_func} to call conky_int_func(), and so forth.  You must load this script
-- in your conkyrc using 'lua_load <path>' before TEXT in order to call the
-- function.
--
do
	-- configuration
	local interval = 5
	local debug_present = 1
	local test = 0
	local cpu_model_name = ""
	local cpu_cores = 0

	-- debug function
	function print_debug(message)
		if (debug_present == 1) then
			print(message)
		end
	end

	function init_cpu_model_name()
		local terminal_request = io.popen ("cat /proc/cpuinfo | grep 'model name'")
		local terminal_respoce = terminal_request:read ("*a")
		terminal_request:close ()

		local cpu_name_records = string.split(terminal_respoce, "\n")

		-- we assume that we have 1 CPU
		cpu_model_name = string.sub(cpu_name_records[1], 14)

		print_debug("cpu name found " .. cpu_model_name)
	end

	function get_int_in_end_of_string(string)
		return string:match("%d+$")
	end

	function init_cpu_cores_info()
		local terminal_request = io.popen ("cat /proc/cpuinfo | grep 'cpu cores'")
		local terminal_respoce = terminal_request:read ("*a")
		terminal_request:close ()

		local cpu_records = string.split(terminal_respoce, "\n")
		for i = 1, #cpu_records-1 do
			local cpu_cores_new_found = tonumber(get_int_in_end_of_string(cpu_records[i]))
			if (cpu_cores < cpu_cores_new_found) then
				cpu_cores = cpu_cores_new_found
			end
		end
		print_debug("cpu cores found " .. cpu_cores)
	end

	function conky_cpu_section()
		local result = ""

		if (cpu_cores == 0) then
			init_cpu_cores_info()
		end

		if (cpu_model_name == "") then
			init_cpu_model_name()
		end

		result = "CPU cores " .. cpu_cores .. "${alignc -30}Package ${exec cat /sys/devices/platform/coretemp.0/hwmon/hwmon6/temp1_input | cut -c-2 }°C" .. "$alignr ${freq_g cpu0}Ghz\n"

		for i = 1, cpu_cores do
			result = result .. "${exec cat /sys/devices/platform/coretemp.0/hwmon/hwmon6/temp" .. i+1 .. "_input | cut -c-2 }" .. "°C" .. "${alignr 220}${cpu cpu" .. i .. "}" .. " ${goto 60}${cpubar cpu" .. i .. " 4}"
			if i < cpu_cores then
				result = result .. "\n"
			end
		end

		return result
	end

	function conky_cpu_model_name()
		if (cpu_model_name == "") then
			init_cpu_model_name()
		end

		return cpu_model_name
	end

	-- local variables protected from the evil outside world
	local next_update
	local buf
	local int = 0
	local colour = 0
	local function update_buf()
		buf = os.time()
	end


	function string:split (delimiter)
		local result = {}
		local from = 1
		local delim_from, delim_to = string.find (self, delimiter, from)
		while delim_from do
			table.insert (result, string.sub (self, from , delim_from - 1))
			from = delim_to + 1
			delim_from, delim_to = string.find (self, delimiter, from)
		end
		table.insert ( result, string.sub (self, from))
		return result
	end


	-- a function that returns the time with some special effects using a 5
	-- second interval
	function conky_string_func()
		local now = os.time()

		if next_update == nil or now >= next_update then
			update_buf();
			next_update = now + interval
		end
		colour = colour + 11100

		return string.format("${color #%06x}The time is now ", colour%0xffffff) .. tostring(buf) .. "${color}"
	end

	-- this function changes Conky's top colour based on a threshold
	function conky_top_colour(value, default_colour, upper_thresh, lower_thresh)
		local r, g, b = default_colour, default_colour, default_colour
		local colour = 0
		-- in my case, there are 4 CPUs so a typical high value starts at around ~20%, and 25% is one thread/process maxed out
		local thresh_diff = upper_thresh - lower_thresh
		if (value - lower_thresh) > 0 then
			if value > upper_thresh then value = upper_thresh end
			-- add some redness, depending on the 'strength'
			r = math.ceil(default_colour + ((value - lower_thresh) / thresh_diff) * (0xff - default_colour))
			b = math.floor(default_colour - ((value - lower_thresh) / thresh_diff) * default_colour)
			g = b
		end
		colour = (r * 0x10000) + (g * 0x100) + b -- no bit shifting operator in Lua afaik

		return string.format("${color #%06x}", colour%0xffffff)
	end
	-- parses the output from top and calls the colour function
	function conky_top_cpu_colour(arg)
		-- input is ' ${top name 1} ${top pid 1} ${top cpu 1} ${top mem 1}'
		local cpu = tonumber(string.match(arg, '(%d+%.%d+)'))
		-- tweak the last 3 parameters to your liking
		-- my machine has 4 CPUs, so an upper thresh of 25% is appropriate
		return conky_top_colour(cpu, 0xd3, 25, 15) .. arg
	end
	function conky_top_mem_colour(arg)
		-- input is '${top_mem name 1} ${top_mem pid 1} ${top_mem cpu 1} ${top_mem mem 1}'
		local mem = tonumber(string.match(arg, '%d+%.%d+%s+(%d+%.%d+)'))
		-- tweak the last 3 parameters to your liking
		-- my machine has 8GiB of ram, so an upper thresh of 15% is appropriate
		return conky_top_colour(mem, 0xd3, 15, 5) .. arg
	end

	-- returns a percentage value that loops around
	function conky_int_func()
		int = int + 1
		return int % 100
	end

	function get_file_name(file)
--	      return file:match("[^\/]*$")
	      return file:match("([^/]+)$")
	end

	function conky_disk_info()
		local file = io.popen ("lsblk -l --output MOUNTPOINTS | grep /")
		output = file:read ("*a")
		file:close ()
		
		local disks = string.split(output, "\n")
		local names = {}

		for i = 1, #disks-1 do
			if disks[i] == "/" then
				names[i] = "root"
			else
				names[i] = get_file_name(disks[i])
			end
		end

		local rez = ""

		for i = 1, #names do
			rez = rez .. "$font${color 778899}" .. names[i] .. "(${fs_type " .. disks[i] .. "}) $alignr ${fs_used " .. disks[i] .. "} / ${fs_size " .. disks[i] .. "}    ${fs_free_perc " .. disks[i] .. "}%" .. "\n"
			if i == #names then
				rez = rez .. "${fs_bar 4 " .. disks[i] .. "}"
			else
				rez = rez .. "${fs_bar 4 " .. disks[i] .. "}" .. "\n"
			end

		end

		-- return string.format("${color #%06x}time ", colour%0xffffff) .. tostring(buf) .. "${color}"
--		return "${color Tan1}" .. tostring(buf) .. "${color}"
--		return get_file_name(disks[3])
--		return tostring(o)
--		return #names
		return rez
	end
end
