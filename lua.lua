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
	local inet_ip4 = ""
	local inet_interface = ""
	local inet_rx_last = 0
	local inet_tx_last = 0
	local inet_rx_diff = 0
	local inet_tx_diff = 0
	local gpu_nvidia_model_name = ""
	local gpu_intel_model_name = ""
	local disk_cached_output = ""
	local disk_request_checksum = 0

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

	function get_gpu_model_name()
		local terminal_request = io.popen ("lspci -v | grep 'VGA controller'")
		local terminal_respoce = terminal_request:read ("*a")
		terminal_request:close ()

		if (string.find(terminal_respoce, "Intel") ~= nil) then
			print_debug("gpu found Intel")
			gpu_intel_model_name = terminal_respoce
			gpu_intel_model_name = gpu_intel_model_name:match(": [%a%s%d]+")
			gpu_intel_model_name = gpu_intel_model_name:gsub(": Intel Corporation ", "")
			gpu_intel_model_name = gpu_intel_model_name:match("^%s*(.-)%s*$")
			print_debug("gpu Intel name " .. gpu_intel_model_name)
		end

		if (string.find(terminal_respoce, "NVIDIA") ~= nil) then
			print_debug("gpu found NVIDIA")
			gpu_nvidia_model_name = terminal_respoce
			gpu_nvidia_model_name = gpu_nvidia_model_name:match(": [%a%s%d%[%]]+")
			gpu_nvidia_model_name = gpu_nvidia_model_name:match("%[.+%]")
			gpu_nvidia_model_name = gpu_nvidia_model_name:match("[%a%s%d]+")
			print_debug("gpu NVIDIA name " .. gpu_nvidia_model_name)
		end

		local gpu_records = string.split(terminal_respoce, "\n")
	end

	function conky_gpu_section()
		local result = ""

		if (gpu_nvidia_model_name == "") and (gpu_intel_model_name == "") then
			get_gpu_model_name()
		end

		if (gpu_nvidia_model_name ~= "") then
			result = gpu_nvidia_model_name .. "${alignr}Temp ${nvidia temp}°C\n" .. "GPU freq ${nvidia gpufreq}MHz${alignr}MEM freq ${nvidia memfreq}MHz"
		end

		if (gpu_intel_model_name ~= "") then
			result = gpu_intel_model_name
		end

		return result
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

	function get_string_check_sum(str)
		local checksum = 0
		for i = 1, #str do
			checksum = checksum + string.byte(str, i)
		end
		return checksum
	end

	function disk_temp(disk_kname)
		if string.find(disk_kname, "nvme") ~= nil then
			return "${exec cat /sys/block/" .. disk_kname .. "/device/hwmon3/temp1_input | cut -c-2 }"
		end
		return "--"
	end

	function formatting_name(str, delim, max_len)
		if (string.find(str, delim) ~= nil) then
			-- multiple words
			local mp = string.split(str, delim)

			if (#mp[#mp] > max_len-2) then
				local diff_len = #mp[#mp] - (max_len-2)
				if diff_len == 1 then
					return "…" .. string.sub(mp[#mp], 1, max_len-1)
				else
					return "…" .. string.sub(mp[#mp], 1, max_len-2) .. "…"
				end
			else
				local diff_len = max_len - #mp[#mp]

				if (#mp[1] > diff_len-1) then
					return string.sub(mp[1], 1, diff_len-1) .. "…" .. mp[#mp]
				else
					if (#mp == 2) then
						return mp[1] .. " " .. mp[#mp]
					else
						return mp[1] .. "…" .. mp[#mp]
					end
				end
			end
		else
			-- one word, if word is long cut off the end
			if (#str > max_len) then
				return string.sub(str, 1, max_len-1) .. "…"
			else
				return str
			end
		end
	end

	function part_formatting_name(str, delim, max_len)
		if (string.find(str, delim) ~= nil) then
			local mp = string.split(str, delim)
			for i = 1, #mp do
				if (str == "/") then
					mp[i] = "root"
				end
			end
			return formatting_name(str, delim, max_len)
		else
			if (str == "/") then
				return "root"
			else
				return formatting_name(get_file_name(str), "/", max_len)
			end
		end
	end

	function conky_disk_info()				--    1    2    3           4     5     6    7      8
		local terminal_request = io.popen ("lsblk -M -n -r -o NAME,TYPE,MOUNTPOINTS,KNAME,LABEL,PATH,PKNAME,MODEL")
		local terminal_respoce = terminal_request:read ("*a")
		terminal_request:close ()

		local new_check_sum = get_string_check_sum(terminal_respoce)
		if new_check_sum == disk_request_checksum then
			return disk_cached_output
		end
		disk_request_checksum = new_check_sum

		local blk_records = string.split(terminal_respoce, "\n")
		local disk_record_added = false
		local disk_record = ""
		local first_disk = true

		disk_cached_output = ""

		for i = 1, #blk_records do
			local sp_record = string.split(blk_records[i], " ")

			if (#sp_record == 1) then
				goto skip_record
			end

			if (sp_record[2] == "disk") or (sp_record[2] == "raid0") then
				print_debug("disk record formatting")
				local disk_name = ""

				if (sp_record[8] ~= nil) and (sp_record[8] ~= "") then
					disk_name = formatting_name(sp_record[8], "\\x20", 12)
				else
					disk_name = formatting_name(sp_record[4], " ", 12)
				end

				disk_record = "• " .. disk_name
				.. "${goto 120}R:${diskio_read " .. sp_record[6] .. "}"
				.. "${goto 185}W:${diskio_write " .. sp_record[6] .. "}"

				local disk_temp_record = disk_temp(sp_record[4])
				if (disk_temp_record ~= "--") then
					disk_record = disk_record .. "${alignr} " .. disk_temp(sp_record[4]) .. "°C" .. "\n"
				else
					disk_record = disk_record .. "\n"
				end

				disk_record_added = false
			end

			if (sp_record[2] == "part") or (sp_record[3] ~= "") then
				print_debug("part record formatting")
				local part_name = ""

				if (sp_record[3] == "[SWAP]") or (sp_record[3] == "/boot/efi") or (sp_record[3] == "") then
					goto skip_record
				end

				if first_disk == true then
					first_disk = false
				else
					disk_cached_output = disk_cached_output .. "\n"
				end

				if disk_record_added == false then
					disk_cached_output = disk_cached_output .. disk_record
					disk_record_added = true
				end

				-- get one of multiple mount points
				if (string.find(sp_record[3], "\\x0a") ~= nil) then
					local mp = string.split(sp_record[3], "\\x0a")
					sp_record[3] = mp[#mp]
				end

				-- formatting part name
				if (sp_record[5] ~= nil) and (sp_record[5] ~= "") then
					part_name = part_formatting_name(sp_record[5], " ", 15)
				else
					part_name = part_formatting_name(sp_record[3], "\\x0a", 15)
				end

				disk_cached_output = disk_cached_output .. "" ..
				"$font${color 778899}" .. part_name ..
				"(${fs_type " .. sp_record[3] .. "}) $alignr ${fs_used " .. sp_record[3]
				.. "} / ${fs_size " .. sp_record[3] .. "}    ${fs_free_perc " .. sp_record[3] .. "}%" .. "\n"
				.. "${fs_bar 4 " .. sp_record[3] .. "}"

			end
			::skip_record::
		end

		return disk_cached_output
	end

	function init_inet()
		local terminal_request = io.popen ("ip route list match default")
		local terminal_respoce = terminal_request:read ("*a")
		terminal_request:close ()

		local net_record = string.split(terminal_respoce, " ")

		for i = 1, #net_record do
			if net_record[i] == "dev" then
				inet_interface = net_record[i+1]
				print_debug("inet_interface found " .. inet_interface)
			end
			if net_record[i] == "src" then
				inet_ip4 = net_record[i+1]
				print_debug("inet_ip4 found " .. inet_ip4)
			end
		end
	end

	function conky_inet_interface()
		if (inet_interface == "") then
			init_inet()
		end

		return inet_interface
	end

	function conky_inet_address()
		if (inet_ip4 == "") then
			init_inet()
		end

		return inet_ip4
	end

	function conky_inet_process_rates()
		local terminal_request = io.popen ("ifstat " .. inet_interface .. " -j")
		local terminal_respoce = terminal_request:read ("*a")
		terminal_request:close ()

		terminal_respoce = terminal_respoce:gsub(",\"", " ")
		terminal_respoce = terminal_respoce:gsub("\":", " ")
		local net_rates = string.split(terminal_respoce, " ")
		print_debug(terminal_respoce)
		local inet_rx = 0
		local inet_tx = 0

		for i = 1, #net_rates do
			if net_rates[i] == "rx_bytes" then
				inet_rx = net_rates[i+1]
				print_debug("inet rx " .. inet_rx)
			end
			if net_rates[i] == "tx_bytes" then
				inet_tx = net_rates[i+1]
				print_debug("inet tx " .. inet_tx)
			end
		end

		if (inet_rx_last == 0) then
			inet_rx_diff = 0
			inet_rx_last = inet_rx
		else
			inet_rx_diff = inet_rx - inet_rx_last
			inet_rx_last = inet_rx
		end

		if (inet_tx_last == 0) then
			inet_tx_diff = 0
			inet_tx_last = inet_tx
		else
			inet_tx_diff = inet_tx - inet_tx_last
			inet_tx_last = inet_tx
		end

		print_debug("inet rx diff " .. inet_rx_diff)
		print_debug("inet tx diff " .. inet_tx_diff)

		return ""
	end

	function conky_get_inet_download_rate_string()
		return string.format("%.1f", inet_rx_diff/1024)
	end

	function conky_get_inet_upload_rate_string()
		return string.format("%.1f", inet_tx_diff/1024)
	end

	function conky_get_inet_download_value()
		return inet_rx_diff
	end

	function conky_get_inet_upload_value()
		return inet_tx_diff
	end
end
