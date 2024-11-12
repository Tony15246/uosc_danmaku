local msg = require('mp.msg')
local utils = require("mp.utils")
local md5 = require("md5")

local danmaku_path = os.getenv("TEMP") or "/tmp/"
local exec_path = mp.command_native({ "expand-path", options.DanmakuFactory_Path })
local history_path = mp.command_native({"expand-path", options.history_path})
local blacklist_file = mp.command_native({ "expand-path", options.blacklist_path })

danmaku = {}

-- url编码转换
function url_encode(str)
    -- 将非安全字符转换为百分号编码
    if str then
        str = str:gsub("([^%w%-%.%_%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
    end
    return str
end

function hex_to_char(x)
    return string.char(tonumber(x, 16))
end

-- url解码转换
function url_decode(str)
    if str ~= nil then
        str = str:gsub('^%a[%a%d-_]+://', '')
              :gsub('^%a[%a%d-_]+:\\?', '')
              :gsub('%%(%x%x)', hex_to_char)
        if str:find('://localhost:?') then
            str = str:gsub('^.*/', '')
        end
        str = str:gsub('%?.+', '')
              :gsub('%+', ' ')
        return str
    else
        return
    end
end

function is_protocol(path)
    return type(path) == 'string' and (path:find('^%a[%w.+-]-://') ~= nil or path:find('^%a[%w.+-]-:%?') ~= nil)
end

function file_exists(path)
    if path then
        local meta = utils.file_info(path)
        return meta and meta.is_file
    end
    return false
end

local function get_cid()
    local cid, danmaku_id = nil, nil
    local tracks = mp.get_property_native("track-list")
    for _, track in ipairs(tracks) do
        if track["lang"] == "danmaku" then
            cid = track["external-filename"]:match("/(%d-)%.xml$")
            danmaku_id = track["id"]
            break
        end
    end
    return cid, danmaku_id
end

function extract_between_colons(input_string)
    local start_index = 0
    local end_index = 0
    local count = 0
    for i = 1, #input_string do
        if input_string:sub(i, i) == ":" then
            count = count + 1
            if count == 2 then
                start_index = i
            elseif count == 3 then
                end_index = i
                break
            end
        end
    end
    if start_index > 0 and end_index > 0 then
        return input_string:sub(start_index + 1, end_index - 1)
    else
        return nil
    end
end


function hex_to_int_color(hex_color)
    -- 移除颜色代码中的'#'字符
    hex_color = hex_color:sub(2)  -- 只保留颜色代码部分

    -- 提取R, G, B的十六进制值并转为整数
    local r = tonumber(hex_color:sub(1, 2), 16)
    local g = tonumber(hex_color:sub(3, 4), 16)
    local b = tonumber(hex_color:sub(5, 6), 16)

    -- 计算32位整数值
    local color_int = (r * 256 * 256) + (g * 256) + b

    return color_int
end


function get_type_from_position(position)
    if position == 0 then
        return 1
    end
    if position == 1 then
        return 4
    end
    return 5
end

--读history 和 写history
function read_file(file_path)
    local file = io.open(file_path, "r") -- 打开文件，"r"表示只读模式
    if not file then
        return nil
    end
    local content = file:read("*all") -- 读取文件所有内容
    file:close()                      -- 关闭文件
    return content
end

function write_json_file(file_path, data)
    local file = io.open(file_path, "w")
    if not file then
        return
    end
    file:write(utils.format_json(data)) -- 将 Lua 表转换为 JSON 并写入
    file:close()
end

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

function get_danmaku_visibility()
    local history_json = read_file(history_path)
    local history
    if history_json ~= nil then
        history = utils.parse_json(history_json)
        local flag = history["show_danmaku"]
        if flag == nil then
            history["show_danmaku"] = false
            write_json_file(history_path, history)
        else
            return flag
        end
    else
        history = {}
        history["show_danmaku"] = false
        write_json_file(history_path, history)
    end
    return false
end

function set_danmaku_visibility(flag)
    local history = {}
    local history_json = read_file(history_path)
    if history_json ~= nil then
        history = utils.parse_json(history_json)
    end
    history["show_danmaku"] = flag
    write_json_file(history_path, history)
end

-- 拆分字符串中的字符和数字
local function split_by_numbers(filename)
    local parts = {}
    local pattern = "([^%d]*)(%d+)([^%d]*)"
    for pre, num, post in string.gmatch(filename, pattern) do
        table.insert(parts, {pre = pre, num = tonumber(num), post = post})
    end
    return parts
end

-- 识别并匹配前后剧集
local function compare_filenames(fname1, fname2)
    local parts1 = split_by_numbers(fname1)
    local parts2 = split_by_numbers(fname2)

    local min_len = math.min(#parts1, #parts2)

    -- 逐个部分进行比较
    for i = 1, min_len do
        local part1 = parts1[i]
        local part2 = parts2[i]

        -- 比较数字前的字符是否相同
        if part1.pre ~= part2.pre then
            return false
        end

        -- 比较数字部分
        if part1.num ~= part2.num then
            return part1.num, part2.num
        end

        -- 比较数字后的字符是否相同
        if part1.post ~= part2.post then
            return false
        end
    end

    return false
end

-- 规范化路径
function normalize(path)
    if normalize_path ~= nil then
        if normalize_path then
            path = mp.command_native({"normalize-path", path})
        else
            local directory = mp.get_property("working-directory", "")
            path = utils.join_path(directory, path:gsub('^%.[\\/]',''))
            if platform == "windows" then path = path:gsub("\\", "/") end
        end
        return path
    end

    normalize_path = false

    local commands = mp.get_property_native("command-list", {})
    for _, command in ipairs(commands) do
        if command.name == "normalize-path" then
            normalize_path = true
            break
        end
    end
    return normalize(path)
end

-- 获取父目录路径
function get_parent_directory(path)
    local dir = nil
    if path and not is_protocol(path) then
        path = normalize(path)
        dir = utils.split_path(path)
    end
    return dir
end

-- 获取播放文件标题信息
function get_title(from_menu)
    local path = mp.get_property("path")
    local thin_space = string.char(0xE2, 0x80, 0x89)

    if path and not is_protocol(path) then
        local directory = get_parent_directory(path)
        local dir, title = utils.split_path(directory:sub(1, -2))
        if title:lower():match("^%s*seasons?%s*%d+%s*$") or title:lower():match("^%s*specials?%s*$") or title:match("^%s*SPs?%s*$")
        or title:match("^%s*O[VAD]+s?%s*$") or title:match("^%s*第.-[季部]+%s*$") then
            directory, title = utils.split_path(dir:sub(1, -2))
        end
        title = title
                :gsub(thin_space, " ")
                :gsub("%[.-%]", "")
                :gsub("^%s*%(%d+.?%d*.?%d*%)", "")
                :gsub("%(%d+.?%d*.?%d*%)%s*$", "")
                :gsub("^%s*(.-)%s*$", "%1")
        return title
    end

    local title = mp.get_property("media-title")
    local season_num, episod_num = nil, nil
    if title then
        title = title:gsub(thin_space, " ")
        if title:match(".*S%d+:E%d+") ~= nil then
            title, season_num, episod_num = title:match("(.-)%s*S(%d+):E(%d+)")
            title = title and url_decode(title):gsub("%s*%[.-%]s*", "")
        elseif title:match(".*%-%s*S%d+E%d+") ~= nil then
            title, season_num, episod_num = title:match("(.-)%s*%-%s*S(%d+)E(%d+)")
            title = title and url_decode(title):gsub("%s*%[.-%]s*", "")
        elseif title:match(".*S%d+E%d+") ~= nil then
            title, season_num, episod_num = title:match("(.-)%s*S(%d+)E(%d+)")
            title = title and url_decode(title):gsub("%s*%[.-%]s*", "")
        else
            title = url_decode(title)
            episod_num = get_episode_number(title)
            if episod_num then
                local parts = split(title, episod_num)
                title = parts[1]:gsub("[%[%(].-[%)%]]", "")
                        :gsub("%[.*", "")
                        :gsub("[%-#].*", "")
                        :gsub("第.*", "")
                        :gsub("^%s*(.-)%s*$", "%1")
            else
                title = nil
            end
        end
    end
    if from_menu then
        return title
    end
    return title, season_num, episod_num
end

-- 获取当前文件名所包含的集数
function get_episode_number(filename, fname)

    -- 尝试对比记录文件名来获取当前集数
    if fname then
        local episode_num1, episode_num2 = compare_filenames(fname, filename)
        if episode_num1 and episode_num2 then
            return episode_num1, episode_num2
        else
            return nil, nil
        end
    end

    local thin_space = string.char(0xE2, 0x80, 0x89)
    filename = filename:gsub(thin_space, " ")

    -- 匹配模式：支持多种集数形式
    local patterns = {
        -- 匹配 [数字] 格式
        "%[(%d+)v?%d?%]",
        -- 匹配 S01E02 格式
        "[S%d+]?E(%d+)",
        -- 匹配 第04话 格式
        "第(%d+)话",
        -- 匹配 -/# 第数字 格式
        "[%-#]%s*(%d+)%s*",
        -- 匹配 直接跟随的数字 格式
        "[^%dhHxXvV](%d%d%d?)[^%dpPkKxXbBfF][^%d]*$",
    }

    -- 尝试匹配文件名中的集数
    for _, pattern in ipairs(patterns) do
        local match = {string.match(filename, pattern)}
        if #match > 0 then
            -- 返回集数，通常是匹配的第一个捕获
            local episode_number = tonumber(match[1])
            if episode_number and episode_number < 1000 then
                return episode_number
            end
        end
    end
    -- 未找到集数
    return nil
end

-- 写入history.json
-- 读取episodeId获取danmaku
function set_episode_id(input, from_menu)
    from_menu = from_menu or false
    local episodeId = tonumber(input)
    if from_menu and options.auto_load or options.autoload_for_url then
        local history = {}
        local path = mp.get_property("path")
        local dir = get_parent_directory(path)
        local fname = mp.get_property('filename/no-ext')
        local episodeNumber = tonumber(episodeId) % 1000 --动漫的集数

        if is_protocol(path) then
            local title, season_num, episod_num = get_title()
            if title and episod_num then
                if season_num then
                    dir = title .." Season".. season_num
                else
                    dir = title
                end
                fname = url_decode(mp.get_property("media-title"))
                episodeNumber = episod_num
            end
        end

        --将文件名:episodeId写入history.json
        if dir ~= nil then
            local history_json = read_file(history_path)
            if history_json ~= nil then
                history = utils.parse_json(history_json) or {}
            end
            history[dir] = {}
            history[dir].animeTitle = danmaku.anime
            history[dir].episodeTitle = danmaku.episode
            history[dir].episodeId = episodeId
            history[dir].episodeNumber = episodeNumber
            history[dir].fname = fname
            write_json_file(history_path, history)
        end
    end
    if options.load_more_danmaku then
        fetch_danmaku_all(episodeId, from_menu)
    else
        fetch_danmaku(episodeId, from_menu)
    end
end

-- 使用 curl 发送 HTTP POST 请求获取弹幕 episodeId
local function match_file(file_name, file_hash)
    local url = options.api_server .. "/api/v2/match"
    local body = utils.format_json({
        fileName = file_name,
        fileHash = file_hash,
        matchMode = "hashAndFileName"
    })

    local arg = {
        "curl", "-s", "-X", "POST", url,
        "-H", "Content-Type: application/json",
        "-d", body
    }

    if options.proxy ~= "" then
        table.insert(arg, '-x')
        table.insert(arg, options.proxy)
    end

    local result = mp.command_native({ name = 'subprocess', capture_stdout = true, args = arg })
    if result.status == 0 then
        return result.stdout
    else
        return nil
    end
end

-- 加载弹幕
local function load_danmaku(danmaku_file, from_menu)
    if not file_exists(danmaku_file) then
        msg.verbose("未找到弹幕文件")
        return
    end
    enabled = true
    parse_danmaku(danmaku_file, from_menu)
end

function get_video_data(url)
    local arg = {
        "curl",
        "--range",
        "0-16777215",
        "--user-agent",
        options.user_agent,
        "--output",
        utils.join_path(danmaku_path, "temp.mp4"),
        "-L",
        url,
    }

    if options.proxy ~= "" then
        table.insert(arg, '-x')
        table.insert(arg, options.proxy)
    end

    local cmd = {
        name = 'subprocess',
        capture_stdout = true,
        capture_stderr = true,
        playback_only = true,
        args = arg,
    }

    return mp.command_native(cmd)
end

-- Use curl command to get the JSON data
function get_danmaku_contents(url)
    local arg = {
        "curl",
        "-L",
        "-X",
        "GET",
        "--header",
        "Accept: application/json",
        "--user-agent",
        options.user_agent,
        url,
    }

    if options.proxy ~= "" then
        table.insert(arg, '-x')
        table.insert(arg, options.proxy)
    end

    local cmd = {
        name = 'subprocess',
        capture_stdout = true,
        capture_stderr = true,
        playback_only = true,
        args = arg,
    }

    return mp.command_native(cmd)
end

-- 匹配弹幕库 comment  仅匹配dandan本身弹幕库
-- 通过danmaku api（url）+id获取弹幕
-- Function to fetch danmaku from API
function fetch_danmaku(episodeId, from_menu)
    local url = options.api_server .. "/api/v2/comment/" .. episodeId .. "?withRelated=true&chConvert=0"
    mp.osd_message("弹幕加载中...", 30)
    msg.verbose("尝试获取弹幕：" .. url)
    local res = get_danmaku_contents(url)
    if res.status == 0 then
        local response = utils.parse_json(res.stdout)
        if response and response["comments"] then
            if response["count"] == 0 then
                mp.osd_message("该集弹幕内容为空，结束加载", 3)
                return
            end
            local success = save_json_for_factory(response["comments"])
            if success then
                local danmaku_json = utils.join_path(danmaku_path, "danmaku.json")
                convert_with_danmaku_factory(danmaku_json)
            end
            local danmaku_file = utils.join_path(danmaku_path, "danmaku.ass")
            load_danmaku(danmaku_file, from_menu)
        else
            mp.osd_message("无数据", 3)
            msg.verbose("无数据")
        end
    else
        mp.osd_message("获取数据失败", 3)
        msg.error("HTTP 请求失败：" .. res.stderr)
    end
end

-- 匹配多个弹幕库 related 包括如腾讯、优酷、b站等
function fetch_danmaku_all(episodeId, from_menu)
    local comments = {}
    local url = options.api_server .. "/api/v2/related/" .. episodeId
    mp.osd_message("弹幕加载中...", 30)
    msg.verbose("尝试获取弹幕：" .. url)
    local res = get_danmaku_contents(url)
    if res.status ~= 0 then
        mp.osd_message("获取数据失败", 3)
        msg.error("HTTP 请求失败：" .. res.stderr)
        return
    end

    local response = utils.parse_json(res.stdout)

    if not response or not response["relateds"] then
        mp.osd_message("无数据", 3)
        msg.verbose("无数据")
        return
    end

    for _, related in ipairs(response["relateds"]) do
        url = options.api_server .. "/api/v2/extcomment?url=" .. url_encode(related["url"])
        local shift = related["shift"]
        --mp.osd_message("正在从此地址加载弹幕：" .. related["url"], 30)
        mp.osd_message("正在从第三方库装填弹幕", 30)
        msg.verbose("正在从第三方库装填弹幕：" .. url)
        res = get_danmaku_contents(url)
        if res.status ~= 0 then
            mp.osd_message("获取数据失败", 3)
            msg.error("HTTP 请求失败：" .. res.stderr)
            return
        end

        local response_comments = utils.parse_json(res.stdout)

        if response_comments and response_comments["comments"] then
            if response_comments["count"] == 0 then
                local start = os.time()
                while os.time() - start < 1 do
                    -- 空循环，等待 1 秒
                end

                res = get_danmaku_contents(url)
                response_comments = utils.parse_json(res.stdout)
            end

            for _, comment in ipairs(response_comments["comments"]) do
                comment["shift"] = shift
                table.insert(comments, comment)
            end
        else
            mp.osd_message("无数据", 3)
            msg.verbose("无数据")
        end
    end

    url = options.api_server .. "/api/v2/comment/" .. episodeId .. "?withRelated=false&chConvert=0"
    mp.osd_message("正在从弹弹Play库装填弹幕", 30)
    msg.verbose("尝试获取弹幕：" .. url)
    res = get_danmaku_contents(url)
    if res.status ~= 0 then
        mp.osd_message("获取数据失败", 3)
        msg.error("HTTP 请求失败：" .. res.stderr)
        return
    end

    response = utils.parse_json(res.stdout)

    if not response or not response["comments"] then
        mp.osd_message("无数据", 3)
        msg.verbose("无数据")
        return
    end

    for _, comment in ipairs(response["comments"]) do
        table.insert(comments, comment)
    end

    if #comments == 0 then
        mp.osd_message("该集弹幕内容为空，结束加载", 3)
        return
    end

    local success = save_json_for_factory(comments)
    if success then
        local danmaku_json = utils.join_path(danmaku_path, "danmaku.json")
        convert_with_danmaku_factory(danmaku_json)
    end
    local danmaku_file = utils.join_path(danmaku_path, "danmaku.ass")
    load_danmaku(danmaku_file, from_menu)

end

--通过输入源url获取弹幕库
function add_danmaku_source(query, from_menu)
    from_menu = from_menu or false
    if from_menu and options.add_from_source then
        local path = mp.get_property("path")
        if path then
            local history_json = read_file(history_path)
            if history_json then
                local history = utils.parse_json(history_json) or {}
                history[path] = history[path] or {}

                local flag = false
                for _, source in ipairs(history[path]) do
                    if source == query then
                        flag = true
                        break
                    end
                end

                if not flag then
                    table.insert(history[path], query)
                    write_json_file(history_path, history)
                end
            end
        end
    end

    if is_protocol(query) then
        add_danmaku_source_online(query)
    else
        add_danmaku_source_local(query)
    end
end

function add_danmaku_source_local(query)
    local path = normalize(query)
    if not file_exists(path) then
        msg.verbose("无效的文件路径")
        return
    end
    if not (string.match(path, "%.xml$") or string.match(path, "%.json$") or string.match(path, "%.ass$")) then
        msg.verbose("仅支持弹幕文件")
        return
    end
    local old_danmaku = utils.join_path(danmaku_path, "danmaku.ass")
    local danmaku_input = {path}
    if file_exists(old_danmaku) then
        table.insert(danmaku_input, old_danmaku)
    end
    convert_with_danmaku_factory(danmaku_input)

    local danmaku_file = utils.join_path(danmaku_path, "danmaku.ass")
    load_danmaku(danmaku_file)
end

--通过输入源url获取弹幕库
function add_danmaku_source_online(query)
    local url = options.api_server .. "/api/v2/extcomment?url=" .. url_encode(query)
    mp.osd_message("弹幕加载中...", 30)
    msg.verbose("尝试获取弹幕：" .. url)
    local res = get_danmaku_contents(url)
    if res.status ~= 0 then
        mp.osd_message("获取数据失败", 3)
        msg.error("HTTP 请求失败：" .. res.stderr)
        return
    end

    local response = utils.parse_json(res.stdout)

    if not response or not response["comments"] then
        mp.osd_message("此源弹幕无法加载", 3)
        return
    end

    local new_comments = response["comments"]
    local count = response["count"]

    if count == 0 then
        mp.osd_message("服务器无缓存数据，再次尝试请求", 30)

        local start = os.time()
        while os.time() - start < 2 do
            -- 空循环，等待 1 秒
        end

        res = get_danmaku_contents(url)
        response = utils.parse_json(res.stdout)
        new_comments = response["comments"]
        count = response["count"]
    end

    if count == 0 then
        mp.osd_message("此源弹幕为空，结束加载", 3)
        return
    end

    save_json_for_factory(new_comments)
    local old_danmaku = utils.join_path(danmaku_path, "danmaku.ass")
    local danmaku_input = { utils.join_path(danmaku_path, "danmaku.json") }
    if file_exists(old_danmaku) then
        table.insert(danmaku_input, old_danmaku)
    end
    convert_with_danmaku_factory(danmaku_input)

    local danmaku_file = utils.join_path(danmaku_path, "danmaku.ass")
    load_danmaku(danmaku_file)
end

-- 将弹幕转换为factory可读的json格式
function save_json_for_factory(comments)
    local json_filename = utils.join_path(danmaku_path, "danmaku.json")
    local json_file = io.open(json_filename, "w")

    if json_file then
        json_file:write("[\n")
        for _, comment in ipairs(comments) do
            local p = comment["p"]
            local shift = comment["shift"]
            if p then
                local fields = split(p, ",")
                if shift ~= nil then
                    fields[1] = tonumber(fields[1]) + tonumber(shift)
                end
                local c_value = string.format(
                    "%s,%s,%s,25,,,",
                    tostring(fields[1]), -- first field of p to first field of c
                    fields[3], -- third field of p to second field of c
                    fields[2]  -- second field of p to third field of c
                )
                local m_value = comment["m"]

                -- Write the JSON object as a single line, no spaces or extra formatting
                local json_entry = string.format('{"c":"%s","m":"%s"},\n', c_value, m_value)
                json_file:write(json_entry)
            end
        end
        json_file:write("]")
        json_file:close()
        return true
    end

    return false
end

--将json文件又转换为ass文件。
-- Function to convert JSON file using DanmakuFactory
function convert_with_danmaku_factory(danmaku_input)
    if exec_path == "" then
        exec_path = utils.join_path(mp.get_script_directory(), "bin")
        if platform == "windows" then
            exec_path = utils.join_path(exec_path, "DanmakuFactory.exe")
        else
            exec_path = utils.join_path(exec_path, "DanmakuFactory")
        end
    end
    local danmaku_factory_path = os.getenv("DANMAKU_FACTORY") or exec_path

    local arg = {
        danmaku_factory_path,
        "-o",
        utils.join_path(danmaku_path, "danmaku.ass"),
        "-i",
        "--ignore-warnings",
        "--scrolltime", options.scrolltime,
        "--fontname", options.fontname,
        "--fontsize", options.fontsize,
        "--shadow", options.shadow,
        "--bold", options.bold,
        "--density", options.density,
        "--displayarea", options.displayarea,
        "--outline", options.outline,
    }

    -- 检查 danmaku_input 是字符串还是数组，并插入到正确的位置
    if type(danmaku_input) == "string" then
        -- 如果是单个字符串，直接插入
        table.insert(arg, 5, danmaku_input)
    else
        -- 如果是字符串数组，逐个插入
        for i, input in ipairs(danmaku_input) do
            table.insert(arg, 4 + i, input)
        end
    end

    if blacklist_file ~= "" and file_exists(blacklist_file) then
        table.insert(arg, "--blacklist")
        table.insert(arg, blacklist_file)
    end

    if options.blockmode ~= "" then
        table.insert(arg, "--blockmode")
        table.insert(arg, options.blockmode)
    end

    mp.command_native({
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        args = arg,
    })
end

-- Utility function to split a string by a delimiter
function split(str, delim)
    local result = {}
    for match in (str .. delim):gmatch("(.-)" .. delim) do
        table.insert(result, match)
    end
    return result
end

-- 通过文件前 16M 的 hash 值进行弹幕匹配
function get_danmaku_with_hash(file_name, file_path)
    if is_protocol(file_path) then
        local res = get_video_data(file_path)
        if res.status ~= 0 then
            mp.osd_message("获取数据失败", 3)
            msg.error("HTTP 请求失败：" .. res.stderr)
            return
        end
        file_path = utils.join_path(danmaku_path, "temp.mp4")
        if not file_exists(file_path) then
            return
        end
    end
    -- 计算文件哈希
    local file_info = utils.file_info(file_path)
    if file_info and file_info.size < 16 * 1024 * 1024 then
        msg.verbose("文件小于 16M，无法计算 hash")
        return
    end
    local file, error = io.open(normalize(file_path), 'rb')
    if error ~= nil then
        return msg.error(error)
    end
    local m = md5.new()
    for _ = 1, 16 * 1024 do
        local content = file:read(1024)
        if content == nil then
            file:close()
            return msg.error('无法读取文件内容')
        end
        m:update(content)
    end
    file:close()
    local hash = m:finish()
    if not hash then
        return
    else
        msg.info('hash:', hash)
    end

    -- 发送匹配请求
    local match_data_raw = match_file(file_name, hash)
    if not match_data_raw then
        return
    end

    -- 解析匹配结果
    local match_data = utils.parse_json(match_data_raw)
    if not match_data.isMatched then
        msg.verbose("没有匹配的剧集")
        return
    elseif #match_data.matches > 1 then
        msg.verbose("找到多个匹配的剧集")
        return
    end

    danmaku.anime = match_data.matches[1].animeTitle
    danmaku.episode = match_data.matches[1].episodeTitle:match("(第%d+[话回集]+)") or match_data.matches[1].episodeTitle

    -- 获取并加载弹幕数据
    set_episode_id(match_data.matches[1].episodeId, true)
end

-- 从用户添加过的弹幕源添加弹幕
function addon_danmaku(path)
    local history_json = read_file(history_path)

    if history_json ~= nil then
        local history = utils.parse_json(history_json) or {}
        local history_record = history[path]
        if history_record ~= nil then
            for _, source in ipairs(history_record) do
                add_danmaku_source(source)
            end
        end
    end
end

-- 为 bilibli 网站的视频加载弹幕
function load_danmaku_for_bilibili(path)
    local cid, danmaku_id = get_cid()
    if danmaku_id ~= nil then
        mp.commandv('sub-remove', danmaku_id)
    end
    if path:match("^https://www.bilibili.com/video/BV.-") then
        if path:match("video/BV.-/.*") then
            path = path:gsub("/[^/]+$", "")
        end
        add_danmaku_source_online(path)
        return
    end

    if cid == nil then
        cid = mp.get_opt('cid')
        if not cid then
            local pat = "bilivideo%.c[nom]+.*/resource/(%d+)%D+.*"  -- com cn
            for _, url in pairs({
                    path,
                    mp.get_property("stream-open-filename", ''),
                    }) do
                if url:find(pat) then
                    cid = url:match(pat)
                    break
                end
            end
        end
        if not cid then
            local pat = "bilivideo%.c[nom]+.*/(%d+)-%d+-%d+%..*%?"  -- com cn
            for _, url in pairs({
                    path,
                    mp.get_property("stream-open-filename", ''),
                    }) do
                if url:find(pat) then
                    cid = url:match(pat)
                    break
                end
            end
        end
    end
    if cid ~= nil then
        local url = "https://comment.bilibili.com/" .. cid .. ".xml"
        local danmaku_xml = utils.join_path(danmaku_path, "danmaku.xml")
        local arg = {
            "curl",
            "-L",
            "-s",
            "--compressed",
            "--user-agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0",
            "--output",
            danmaku_xml,
            url,
        }

        local cmd = {
            name = 'subprocess',
            capture_stdout = true,
            capture_stderr = true,
            playback_only = true,
            args = arg,
        }

        local res = mp.command_native(cmd)
        if res.status == 0 then
            if file_exists(danmaku_xml) then
                add_danmaku_source_local(danmaku_xml)
            end
        end
    end
end

function load_danmaku_for_bahamut(path)
    print(path)
    path = path:gsub('%%(%x%x)', hex_to_char)
    local sn = extract_between_colons(path)
    print(sn)
    if sn == nil then
        return
    end
    local url = "https://ani.gamer.com.tw/ajax/danmuGet.php"
    local danmaku_json = utils.join_path(danmaku_path, "bahamut.json")
    local arg = {
        "curl",
        "-X",
        "POST",
        "-d",
        "sn=" .. sn,
        "-L",
        "-s",
        "--user-agent",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.83 Safari/537.36",
        "--header",
        "Origin: https://ani.gamer.com.tw",
        "--header",
        "Content-Type: application/x-www-form-urlencoded;charset=utf-8",
        "--header",
        "Accept: application/json",
        "--header",
        "Authority: ani.gamer.com.tw",
        "--output",
        danmaku_json,
        url,
    }

    local cmd = {
        name = 'subprocess',
        capture_stdout = true,
        capture_stderr = true,
        playback_only = true,
        args = arg,
    }

    local res = mp.command_native(cmd)
    if res.status ~= 0 or not file_exists(danmaku_json) then
        print("error curl")
        return
    end

    local comments_json = read_file(danmaku_json)

    local comments = utils.parse_json(comments_json)

    if not comments then
        print("error parsefile")
        return
    end

    local json_filename = utils.join_path(danmaku_path, "danmaku.json")
    local json_file = io.open(json_filename, "w")

    if json_file then
        json_file:write("[\n")
        for _, comment in ipairs(comments) do
            local m = comment["text"]
            local color = hex_to_int_color(comment["color"])
            local mode = get_type_from_position(comment["position"])
            local time = tonumber(comment["time"]) / 10
            local c = time .. "," .. color .. "," .. mode .. ",25,,,"

            -- Write the JSON object as a single line, no spaces or extra formatting
            local json_entry = string.format('{"c":"%s","m":"%s"},\n', c, m)
            json_file:write(json_entry)
        end
        json_file:write("]")
        json_file:close()
    end

    convert_with_danmaku_factory(json_filename)
    local danmaku_file = utils.join_path(danmaku_path, "danmaku.ass")
    load_danmaku(danmaku_file)

end

-- 自动加载上次匹配的弹幕
function auto_load_danmaku(path, dir, filename, number)
    if dir ~= nil then
        local history_json = read_file(history_path)
        if history_json ~= nil then
            local history = utils.parse_json(history_json) or {}
            -- 1.判断父文件名是否存在
            local history_dir = history[dir]
            if history_dir ~= nil then
                --2.如果存在，则获取number和id
                danmaku.anime = history_dir.animeTitle
                local episode_number = history_dir.episodeTitle and history_dir.episodeTitle:match("%d+")
                local history_number = history_dir.episodeNumber
                local history_id = history_dir.episodeId
                local history_fname = history_dir.fname
                local playing_number = nil

                if history_fname then
                    if filename ~= history_fname then
                        if number then
                            playing_number = number
                        else
                            history_number, playing_number = get_episode_number(filename, history_fname)
                        end
                    else
                        playing_number = history_number
                    end
                else
                    playing_number = get_episode_number(filename)
                end
                if playing_number ~= nil then
                    local x = playing_number - history_number --获取集数差值
                    local tmp_id = tostring(x + history_id)
                    danmaku.episode = episode_number and string.format("第%s话", episode_number + x) or history_dir.episodeTitle
                    mp.osd_message("自动加载上次匹配的弹幕", 3)
                    set_episode_id(tmp_id)
                else
                    get_danmaku_with_hash(filename, path)
                end
            else
                get_danmaku_with_hash(filename, path)
            end
        else
            get_danmaku_with_hash(filename, path)
        end
    end
end

function init(path)
    if not path then return end
    local dir = get_parent_directory(path)
    local filename = mp.get_property('filename/no-ext')
    if filename then
        if dir then
            local danmaku_xml = utils.join_path(dir, filename .. ".xml")
            if file_exists(danmaku_xml) then
                add_danmaku_source_local(danmaku_xml)
                return
            end
        end
        get_danmaku_with_hash(filename, path)
        if options.add_from_source then
            addon_danmaku(path)
        end
    end
end

mp.add_key_binding(options.open_search_danmaku_menu_key, "open_search_danmaku_menu", function ()
    mp.commandv("script-message", "open_search_danmaku_menu")
end)
mp.add_key_binding(options.show_danmaku_keyboard_key, "show_danmaku_keyboard", function ()
    mp.commandv("script-message", "show_danmaku_keyboard")
end)

mp.register_event("file-loaded", function()
    local path = mp.get_property("path")
    local dir = get_parent_directory(path)
    local filename = mp.get_property('filename/no-ext')

    if options.autoload_for_url and is_protocol(path) then
        if path:find('bilibili.com') or path:find('bilivideo.c[nom]+') then
            load_danmaku_for_bilibili(path)
            return
        end

        if path:find('bahamut.akamaized.net') then
            load_danmaku_for_bahamut(path)
            return
        end

        local title, season_num, episod_num = get_title()
        local episod_number = nil
        if title and episod_num then
            if season_num then
                dir = title .." Season".. season_num
                episod_number = episod_num
            else
                dir = title
            end
            filename = url_decode(mp.get_property("media-title"))
            auto_load_danmaku(path, dir, filename, episod_number)
            return
        else
            get_danmaku_with_hash(filename, path)
        end
    end

    if filename == nil or dir == nil then
        return
    end
    local danmaku_xml = utils.join_path(dir, filename .. ".xml")
    if options.autoload_local_danmaku then
        if file_exists(danmaku_xml) then
            add_danmaku_source_local(danmaku_xml)
            return
        end
    end

    if options.auto_load or options.add_from_source then
        if options.auto_load then
            auto_load_danmaku(path, dir, filename)
        end
        if options.add_from_source then
            addon_danmaku(path)
        end
        return
    end

    if enabled and comments == nil then
        init(path)
    end
end)
