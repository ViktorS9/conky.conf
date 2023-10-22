-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- Conky Lua script
do
	-- configuration
	local debug_present = 0
	local log_to_file = 0
	local cpu_model_name = ""
	local cpu_cores = 0
	local cpu_cores_processor = {}
	local cpu_hwmon_name = ""
	local cpu_pack_temp = false
	local cpu_section_cache = ""
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

	function file_log(message)
		if (log_to_file == 1) then
			local log_file = nil
			log_file = io.open("/tmp/concy_conf_lua_log.log", "a+")
			if (log_file ~= nil) then
				io.output(log_file)
				io.write(message .. "\r\n")
				io.close(log_file)
				log_file = nil
			end
		end
	end

	function execute_in_terminal(request)
		local terminal_request = io.popen(request)
		local terminal_respoce = terminal_request:read ("*a")
		terminal_request:close ()
		return terminal_respoce
	end

	function init_cpu_model_name()
		local command_result = execute_in_terminal("cat /proc/cpuinfo | grep 'model name'")
		local cpu_name_records = string.split(command_result, "\n")

		-- we assume that we have 1 CPU
		cpu_model_name = string.sub(cpu_name_records[1], 14)

		print_debug("cpu name found " .. cpu_model_name)
	end

	function get_int_in_end_of_string(string)
		return string:match("%d+$")
	end

	function init_cpu_cores_info()
		local command_result = execute_in_terminal("cat /proc/cpuinfo | grep 'cpu cores'")

		local cpu_records = string.split(command_result, "\n")
		for i = 1, #cpu_records-1 do
			local cpu_cores_new_found = tonumber(get_int_in_end_of_string(cpu_records[i]))
			if (cpu_cores < cpu_cores_new_found) then
				cpu_cores = cpu_cores_new_found
			end
		end
		print_debug("cpu cores found " .. cpu_cores)

		command_result = execute_in_terminal("cat /proc/cpuinfo | grep -e 'core id' -e 'processor'")

		for i = 1, cpu_cores do
			cpu_cores_processor[i] = {}
		end

		local cpu_core_processor_records = string.split(command_result, "\n")
		local processor_number = 0
		for i = 1, #cpu_core_processor_records-1 do
			if cpu_core_processor_records[i]:find("processor") then
				processor_number = tonumber(get_int_in_end_of_string(cpu_core_processor_records[i]))
			end

			if cpu_core_processor_records[i]:find("core id") then
				local core_id = tonumber(get_int_in_end_of_string(cpu_core_processor_records[i])) + 1
				local processor_n = #cpu_cores_processor[core_id] + 1
				cpu_cores_processor[core_id][processor_n] = processor_number
			end
		end
	end

	function init_cpu_pack_temp()
		local command_result = execute_in_terminal("cat /sys/devices/platform/coretemp.0/hwmon/" .. cpu_hwmon_name .. "/temp1_input")

		if (#command_result ~= 0) then
			cpu_pack_temp = true
		else
			cpu_pack_temp = false
		end
	end

	function init_cpu_hwmon_name()
		local command_result = execute_in_terminal("ls /sys/devices/platform/coretemp.0/hwmon")

		cpu_hwmon_name = command_result:sub(1, 6) -- trim "\n" at end of string
		print_debug("cpu_hwmon_name = " .. cpu_hwmon_name)

		init_cpu_pack_temp()
	end

	function conky_cpu_section()
		local result = ""

		if (cpu_section_cache ~= "") then
			return cpu_section_cache
		end

		if (cpu_cores == 0) then
			init_cpu_cores_info()
		end

		if (cpu_hwmon_name == "") then
			init_cpu_hwmon_name()
		end

		if (cpu_model_name == "") then
			init_cpu_model_name()
		end

		result = "CPU cores " .. cpu_cores

		if (cpu_pack_temp == true) then
			result = result .. "${alignc -30}Package ${exec cat /sys/devices/platform/coretemp.0/hwmon/" .. cpu_hwmon_name .. "/temp1_input | cut -c-2 }°C"
		end

		result = result .. "$alignr ${freq_g cpu0}Ghz\n"

		for i = 1, #cpu_cores_processor do
			if (cpu_hwmon_name ~= "") then
				result = result .. "${exec cat /sys/devices/platform/coretemp.0/hwmon/" .. cpu_hwmon_name .. "/temp" .. i+1 .. "_input | cut -c-2 }" .. "°C"
			end
			for j = 1, #cpu_cores_processor[i] do
				local cpu_processor_conky_index = cpu_cores_processor[i][j] + 1     -- +1 because cpu0 for all cpu
				result = result .. "${alignr 210}${cpu cpu" .. cpu_processor_conky_index .. "}%" .. "${goto 70}${cpubar cpu" .. cpu_processor_conky_index .. " 4}"
				if (i ~= #cpu_cores_processor) or (j ~= #cpu_cores_processor[i]) then
					result = result .. "\n"
				end
			end
		end

		cpu_section_cache = result

		return cpu_section_cache
	end

	function conky_cpu_model_name()
		if (cpu_model_name == "") then
			init_cpu_model_name()
		end

		return cpu_model_name
	end

	function get_gpu_model_name()
		local command_result = execute_in_terminal("lspci -v | grep 'VGA controller'")

		if (string.find(command_result, "Intel") ~= nil) then
			print_debug("gpu found Intel")
			gpu_intel_model_name = command_result
			gpu_intel_model_name = gpu_intel_model_name:match(": [%a%s%d]+")
			gpu_intel_model_name = gpu_intel_model_name:gsub(": Intel Corporation ", "")
			gpu_intel_model_name = gpu_intel_model_name:match("^%s*(.-)%s*$")
			print_debug("gpu Intel name " .. gpu_intel_model_name)
		end

		if (string.find(command_result, "NVIDIA") ~= nil) then
			print_debug("gpu found NVIDIA")
			gpu_nvidia_model_name = command_result
			gpu_nvidia_model_name = gpu_nvidia_model_name:match(": [%a%s%d%[%]]+")
			gpu_nvidia_model_name = gpu_nvidia_model_name:match("%[.+%]")
			gpu_nvidia_model_name = gpu_nvidia_model_name:match("[%a%s%d]+")
			print_debug("gpu NVIDIA name " .. gpu_nvidia_model_name)
		end

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

	function string:split(delimiter)
		local result = {}
		local from = 1
		local delim_from, delim_to = string.find(self, delimiter, from)
		while delim_from do
			table.insert(result, string.sub(self, from , delim_from - 1))
			from = delim_to + 1
			delim_from, delim_to = string.find(self, delimiter, from)
		end
		table.insert(result, string.sub(self, from))
		return result
	end

	function get_file_name(file)
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

	function conky_disk_info()					--    1    2    3           4     5     6    7      8
		local command_result = execute_in_terminal("lsblk -M -n -r -o NAME,TYPE,MOUNTPOINTS,KNAME,LABEL,PATH,PKNAME,MODEL")

		local new_check_sum = get_string_check_sum(command_result)
		if new_check_sum == disk_request_checksum then
			return disk_cached_output
		end
		disk_request_checksum = new_check_sum

		local blk_records = string.split(command_result, "\n")
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
		local command_result = execute_in_terminal("ip route list match default")

		local net_record = string.split(command_result, " ")

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
		local command_result = execute_in_terminal("ifstat " .. inet_interface .. " -j")

		command_result = command_result:gsub(",\"", " ")
		command_result = command_result:gsub("\":", " ")

		local net_rates = string.split(command_result, " ")

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
