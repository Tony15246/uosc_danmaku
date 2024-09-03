local utils = require("mp.utils")
local episodeId = nil

-- Buffer for the input string
local input_buffer = ""
local danmaku_path = mp.get_script_directory() .. "/danmaku/"

function itable_index_of(itable, value)
	for index = 1, #itable do
		if itable[index] == value then
			return index
		end
	end
end

local platform = (function()
	local platform = mp.get_property_native("platform")
	if platform then
		if itable_index_of({ "windows", "darwin" }, platform) then
			return platform
		end
	else
		if os.getenv("windir") ~= nil then
			return "windows"
		end
		local homedir = os.getenv("HOME")
		if homedir ~= nil and string.sub(homedir, 1, 6) == "/Users" then
			return "darwin"
		end
	end
	return "linux"
end)()

-- Show OSD message to prompt user to input episode ID
function show_input_menu()
	mp.osd_message("Input Episode ID: " .. input_buffer, 10) -- Display the current input buffer in OSD
	mp.add_forced_key_binding("BS", "backspace", handle_backspace) -- Bind Backspace to delete last character
	mp.add_forced_key_binding("Enter", "confirm", confirm_input) -- Bind Enter key to confirm input
	mp.add_forced_key_binding("Esc", "cancel", cancel_input) -- Bind Esc key to cancel input

	-- Bind alphanumeric keys to capture user input
	for i = 0, 9 do
		mp.add_forced_key_binding(tostring(i), "input_" .. i, function()
			handle_input(tostring(i))
		end)
	end
	for i = 97, 122 do
		local char = string.char(i)
		mp.add_forced_key_binding(char, "input_" .. char, function()
			handle_input(char)
		end)
	end
end

-- Handle user input by adding characters to the buffer
function handle_input(char)
	input_buffer = input_buffer .. char
	mp.osd_message("Input Episode ID: " .. input_buffer, 10) -- Update the OSD with current input
end

-- Handle backspace to delete the last character
function handle_backspace()
	input_buffer = input_buffer:sub(1, -2) -- Remove the last character
	mp.osd_message("Input Episode ID: " .. input_buffer, 10) -- Update the OSD
end

-- Confirm the input and process the episode ID
function confirm_input()
	mp.remove_key_binding("backspace")
	mp.remove_key_binding("confirm")
	mp.remove_key_binding("cancel")
	for i = 0, 9 do
		mp.remove_key_binding("input_" .. i)
	end
	for i = 97, 122 do
		mp.remove_key_binding("input_" .. string.char(i))
	end

	if input_buffer ~= "" then
		set_episode_id(input_buffer)
	else
		mp.osd_message("No input provided", 2)
	end
	input_buffer = "" -- Clear the input buffer
end

-- Cancel input
function cancel_input()
	mp.remove_key_binding("backspace")
	mp.remove_key_binding("confirm")
	mp.remove_key_binding("cancel")
	for i = 0, 9 do
		mp.remove_key_binding("input_" .. i)
	end
	for i = 97, 122 do
		mp.remove_key_binding("input_" .. string.char(i))
	end

	mp.osd_message("Input cancelled", 2)
	input_buffer = "" -- Clear the input buffer
end

function remove_danmaku_track()
	local tracks = mp.get_property_native("track-list")
	for i = #tracks, 1, -1 do
		if tracks[i].type == "sub" and tracks[i].title == "danmaku" then
			mp.commandv("sub-remove", tracks[i].id)
			break
		end
	end
end

function show_danmaku_func()
	local tracks = mp.get_property_native("track-list")
	for i = #tracks, 1, -1 do
		if tracks[i].type == "sub" and tracks[i].title == "danmaku" then
			mp.set_property("secondary-sub-ass-override", "yes")
			mp.set_property("secondary-sid", tracks[i].id)
			break
		end
	end
end

function hide_danmaku_func()
	mp.set_property("secondary-sid", "no")
end

-- Function to set episodeId from user input
function set_episode_id(input)
	episodeId = input
	fetch_danmaku(episodeId)
end

-- Function to fetch danmaku from API
function fetch_danmaku(episodeId)
	local url = "https://api.dandanplay.net/api/v2/comment/" .. episodeId .. "?withRelated=true&chConvert=0"

	-- Use curl command to get the JSON data
	local req = {
		args = {
			"curl",
			"-L",
			"-X",
			"GET",
			"--header",
			"Accept: application/json",
			"--header",
			"User-Agent: MyCustomUserAgent/1.0",
			url,
		},
		cancellable = false,
	}

	mp.osd_message("Downloading danmaku...", 60)

	local res = utils.subprocess(req)

	if res.status == 0 then
		local response = utils.parse_json(res.stdout)
		if response and response["comments"] then
			local success = save_json_for_factory(response["comments"])
			if success then
				convert_with_danmaku_factory()

				remove_danmaku_track()
				mp.commandv("sub-add", danmaku_path .. "danmaku.ass", "auto", "danmaku")
				mp.osd_message("", 0)
				show_danmaku_func()
				mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
                print("danmaku number for this episode is " .. response["count"])
			else
				mp.osd_message("Error saving JSON file", 3)
			end
		else
			mp.osd_message("No result", 3)
		end
	else
		mp.osd_message("HTTP Request failed: " .. res.error, 3)
	end
end

-- Function to save the comments as the specific JSON format for DanmakuFactory
function save_json_for_factory(comments)
	local json_filename = danmaku_path .. "danmaku.json"
	local json_file = io.open(json_filename, "w")

	if json_file then
		json_file:write("[[],[],[\n")
		for _, comment in ipairs(comments) do
			local p = comment["p"]
			if p then
				local fields = split(p, ",")
				local c_value = string.format(
					"%s,%s,%s,25,,,",
					fields[1], -- first field of p to first field of c
					fields[3], -- third field of p to second field of c
					fields[2] -- second field of p to third field of c
				)
				local m_value = comment["m"]

				-- Write the JSON object as a single line, no spaces or extra formatting
				local json_entry = string.format('{"c":"%s","m":"%s"},\n', c_value, m_value)
				json_file:write(json_entry)
			end
		end
		json_file:write("]]")
		json_file:close()
		return true
	end

	return false
end

-- Function to convert JSON file using DanmakuFactory
function convert_with_danmaku_factory()
	local bin = platform == "windows" and "DanmakuFactory.exe" or "DanmakuFactory"
	danmaku_factory_path = os.getenv("DANMAKU_FACTORY") or mp.get_script_directory() .. "/bin/" .. bin
	local cmd = {
		danmaku_factory_path,
		"-o",
		danmaku_path .. "danmaku.ass",
		"-i",
		danmaku_path .. "danmaku.json",
		"--ignore-warnings",
	}

	utils.subprocess({ args = cmd })
end

-- Utility function to split a string by a delimiter
function split(str, delim)
	local result = {}
	for match in (str .. delim):gmatch("(.-)" .. delim) do
		table.insert(result, match)
	end
	return result
end

mp.register_script_message("show-input-menu", show_input_menu)
