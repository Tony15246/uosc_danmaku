-- 选项
local options = {
    load_more_danmaku = false,
    auto_load = false,
    autoload_local_danmaku = false,
    -- 保存哈希匹配的关联结果
    -- 启用时可以避免同番剧剧集的反复哈希匹配
    -- 禁用时始终进行哈希匹配（仅当同目录从未执行过手动搜索）；可以应对边缘案例：
    -- 同目录存在同一番剧的 OVA 和 MOVIE；同一番剧的剧集文件命名格式不同；同目录存在多个不同番剧
    save_hash_match = false,
    -- 指定 DanmakuFactory 程序的路径，支持绝对路径和相对路径
    -- 留空（默认值）会在脚本同目录的 bin 中查找
    -- 示例：DanmakuFactory_Path = 'DanmakuFactory' 会在环境变量 PATH 中或 mpv 程序旁查找该程序
    DanmakuFactory_Path = '',
    -- 指定弹幕关联历史记录文件的路径，支持绝对路径和相对路径
    history_path = "~~/danmaku-history.json",
    open_search_danmaku_menu_key = "Ctrl+d",
    show_danmaku_keyboard_key = "j",
    --分辨率
    resolution = "1920 1080",
    --速度
    scrolltime = "12",
    --字体
    fontname = "sans-serif",
    --大小 
    fontsize = "50",
    --透明度(1-255)  255 为不透明
    opacity = "150",
    --阴影
    shadow = "0",
    --粗体 true false
    bold = "true",
    --弹幕密度 整数(>=-1) -1：表示不重叠 0：表示无限制 其他表示限定条数
    density = "0.0",
    --全部弹幕的显示范围(0.0-1.0)
    displayarea = "0.85",
    --描边 0-4
    outline = "1",
    --指定弹幕屏蔽词文件路径(black.txt)，支持绝对路径和相对路径。文件内容以换行分隔
    blacklist_path = "",
}

require("mp.options").read_options(options, "uosc_danmaku", function() end)

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local danmaku_path = os.getenv("TEMP") or "/tmp/"
local exec_path = mp.command_native({ "expand-path", options.DanmakuFactory_Path })
local history_path = mp.command_native({"expand-path", options.history_path})
local blacklist_file = mp.command_native({ "expand-path", options.blacklist_path })

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

local function is_protocol(path)
    return type(path) == 'string' and (path:find('^%a[%w.+-]-://') ~= nil or path:find('^%a[%w.+-]-:%?') ~= nil)
end

local function file_exists(path)
    if path then
        local meta = utils.file_info(path)
        return meta and meta.is_file
    end
    return false
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

-- 弹幕加载相关。 移除弹幕轨道
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

    set_danmaku_visibility(true)
end

function hide_danmaku_func()
    mp.set_property("secondary-sid", "no")
    set_danmaku_visibility(false)
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
local function normalize(path)
    if normalize_path ~= nil then
        if normalize_path then
            path = mp.command_native({"normalize-path", path})
        else
            local directory = mp.get_property("working-directory", "")
            path = mp.utils.join_path(directory, path:gusb('^%.[\\/]',''))
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
function get_parent_directory()
    local path = mp.get_property("path")
    local dir = nil
    if path and not is_protocol(path) then
        path = normalize(path)
        dir = utils.split_path(path)
    end
    return dir
end

-- 获取当前文件名所包含的集数
function get_episode_number(fname)
    local filename = mp.get_property('filename/no-ext')

    -- 尝试对比记录文件名来获取当前集数
    if fname then
        local episode_num1, episode_num2 = compare_filenames(fname, filename)
        if episode_num1 and episode_num2 then
            return episode_num1, episode_num2
        else
            return nil, nil
        end
    end

    -- 匹配模式：支持多种集数形式
    local patterns = {
        -- 匹配 [数字] 格式
        "%[(%d+)%v?%d?]",
        -- 匹配 S01E02 格式
        "[S%d+]?E(%d+)",
        -- 匹配 第04话 格式
        "第(%d+)话",
        -- 匹配 -/# 第数字 格式
        "[-#]%s*(%d+)%s*",
        -- 匹配 直接跟随的数字 格式
        "[^vV](%d+)[^pPkK][^%d]*$",
        -- 匹配 直接跟随的数字 格式
        "[^%d](%d+)[^%d]*",
    }

    -- 尝试匹配文件名中的集数
    for _, pattern in ipairs(patterns) do
        local match = {string.match(filename, pattern)}
        if #match > 0 then
            -- 返回集数，通常是匹配的第一个捕获
            local episode_number = tonumber(match[1])
            if episode_number then
                if episode_number >= 1000 then
                    goto continue
                end
                return episode_number
            end
        end
        ::continue::
    end
    -- 未找到集数
    return nil
end

-- 写入history.json
-- 读取episodeId获取danmaku
function set_episode_id(input, from_menu)
    local fname = mp.get_property('filename/no-ext')
    from_menu = from_menu or false
    local episodeId = tonumber(input)
    if options.auto_load and from_menu then
        local history = {}
        local dir = get_parent_directory()
        local episodeNumber = tonumber(episodeId) % 1000 --动漫的集数
        --将文件名:episodeId写入history.json
        if dir ~= nil then
            local history_json = read_file(history_path)
            if history_json ~= nil then
                history = utils.parse_json(history_json) or {}
            end
            history[dir] = {}
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

-- 使用 Unix 的 head 和 md5sum 命令计算前 16MB 的 MD5 哈希
local function get_md5_unix(file_path)
    local arg = { "sh", "-c", "head -c 16M '" .. file_path .. "' | md5sum" }
    local result = mp.command_native({ name = 'subprocess', capture_stdout = true, args = arg })

    if result.status == 0 then
        return result.stdout:gsub("%s+", "")
    else
        return nil
    end
end

-- 使用 Windows PowerShell 的命令计算前 16MB 的 MD5 哈希
local function get_md5_windows(file_path)
    local cmd = [[
        $stream = [System.IO.File]::OpenRead(']] .. file_path .. [['); 
        $buffer = New-Object byte[] (16MB); 
        $bytesRead = $stream.Read($buffer, 0, 16MB); 
        $stream.Close(); 
        $s = [System.IO.MemoryStream]::new($buffer, 0, $bytesRead); 
        Get-FileHash -Algorithm MD5 -InputStream $s | Select-Object -ExpandProperty Hash
    ]]

    local arg = {"powershell", "-NoProfile", "-Command", cmd}
    local result = mp.command_native({ name = 'subprocess', capture_stdout = true, args = arg })

    if result.status == 0 then
        return result.stdout:gsub("%s+", "")
    else
        return nil
    end
end

-- 根据操作系统调用不同的哈希计算函数
local function get_file_md5(file_path)
    if platform == "windows" then
        return get_md5_windows(file_path)
    else
        return get_md5_unix(file_path)
    end
end

-- 使用 curl 发送 HTTP POST 请求获取弹幕 episodeId
local function match_file(file_name, file_hash)
    local url = "https://api.dandanplay.net/api/v2/match"
    local body = utils.format_json({
        fileName = file_name,
        fileHash = file_hash,
    })

    local arg = {
        "curl", "-s", "-X", "POST", url,
        "-H", "Content-Type: application/json",
        "-d", body
    }

    local result = mp.command_native({ name = 'subprocess', capture_stdout = true, args = arg })
    if result.status == 0 then
        return result.stdout
    else
        return nil
    end
end

-- 加载弹幕
local function load_danmaku(comments, from_menu)
    local success = save_json_for_factory(comments)
    if success then
        local danmaku_json = utils.join_path(danmaku_path, "danmaku.json")
        convert_with_danmaku_factory(danmaku_json)

        remove_danmaku_track()
        local danmaku_file = utils.join_path(danmaku_path, "danmaku.ass")
        if not file_exists(danmaku_file) then
            mp.osd_message("未找到弹幕文件", 3)
            return
        end
        mp.commandv("sub-add", danmaku_file, "auto", "danmaku")
        if from_menu then
            show_danmaku_func()
            mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
        elseif get_danmaku_visibility() then
            show_danmaku_func()
            mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
        end
        mp.osd_message("弹幕加载成功，共计" .. #comments .. "条弹幕", 3)
    else
        msg.verbose("Error saving JSON file")
    end
end

-- Use curl command to get the JSON data
local function get_danmaku_comments(url)
    local cmd = {
        name = 'subprocess',
        capture_stdout = true,
        capture_stderr = true,
        playback_only = true,
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
    }

    return mp.command_native(cmd)
end

-- 匹配弹幕库 comment  仅匹配dandan本身弹幕库
-- 通过danmaku api（url）+id获取弹幕
-- Function to fetch danmaku from API
function fetch_danmaku(episodeId, from_menu)
    local url = "https://api.dandanplay.net/api/v2/comment/" .. episodeId .. "?withRelated=true&chConvert=0"
    mp.osd_message("弹幕加载中...", 30)
    local res = get_danmaku_comments(url)
    if res.status == 0 then
        local response = utils.parse_json(res.stdout)
        if response and response["comments"] then
            if response["count"] == 0 then
                mp.osd_message("该集弹幕内容为空，结束加载", 3)
                return
            end
            load_danmaku(response["comments"], from_menu)
        else
            mp.osd_message("无数据", 3)
            msg.verbose("No result")
        end
    else
        mp.osd_message("获取数据失败", 3)
        msg.error("HTTP Request failed: " .. res.stderr)
    end
end

-- 匹配多个弹幕库 related 包括如腾讯、优酷、b站等
function fetch_danmaku_all(episodeId, from_menu)
    local comments = {}
    local url = "https://api.dandanplay.net/api/v2/related/" .. episodeId
    mp.osd_message("弹幕加载中...", 30)
    local res = get_danmaku_comments(url)
    if res.status ~= 0 then
        mp.osd_message("获取数据失败", 3)
        msg.error("HTTP Request failed: " .. res.stderr)
        return
    end

    local response = utils.parse_json(res.stdout)

    if not response or not response["relateds"] then
        mp.osd_message("无数据", 3)
        msg.verbose("No result")
        return
    end

    for _, related in ipairs(response["relateds"]) do
        url = "https://api.dandanplay.net/api/v2/extcomment?url=" .. url_encode(related["url"])
        local shift = related["shift"]
        --mp.osd_message("正在从此地址加载弹幕：" .. related["url"], 30)
        mp.osd_message("正在从第三方库装填弹幕", 30)
        res = get_danmaku_comments(url)
        if res.status ~= 0 then
            mp.osd_message("获取数据失败", 3)
            msg.error("HTTP Request failed: " .. res.stderr)
            return
        end

        local response_comments = utils.parse_json(res.stdout)

        if not response_comments or not response_comments["comments"] then
            mp.osd_message("无数据", 3)
            msg.verbose("No result")
            goto continue
        end

        if response_comments["count"] == 0 then
            local start = os.time()
            while os.time() - start < 1 do
                -- 空循环，等待 1 秒
            end

            res = get_danmaku_comments(url)
            response_comments = utils.parse_json(res.stdout)
        end

        for _, comment in ipairs(response_comments["comments"]) do
            comment["shift"] = shift
            table.insert(comments, comment)
        end
        ::continue::
    end

    url = "https://api.dandanplay.net/api/v2/comment/" .. episodeId .. "?withRelated=false&chConvert=0"
    mp.osd_message("正在从弹弹Play库装填弹幕", 30)
    res = get_danmaku_comments(url)
    if res.status ~= 0 then
        mp.osd_message("获取数据失败", 3)
        msg.error("HTTP Request failed: " .. res.stderr)
        return
    end

    response = utils.parse_json(res.stdout)

    if not response or not response["comments"] then
        mp.osd_message("无数据", 3)
        msg.verbose("No result")
        return
    end

    for _, comment in ipairs(response["comments"]) do
        table.insert(comments, comment)
    end

    if #comments == 0 then
        mp.osd_message("该集弹幕内容为空，结束加载", 3)
        return
    end

    load_danmaku(comments, from_menu)
end

--通过输入源url获取弹幕库
function add_danmaku_source(query)
    local url = "https://api.dandanplay.net/api/v2/extcomment?url=" .. url_encode(query)
    mp.osd_message("弹幕加载中...", 30)
    local res = get_danmaku_comments(url)
    if res.status ~= 0 then
        mp.osd_message("获取数据失败", 3)
        msg.error("HTTP Request failed: " .. res.stderr)
        return
    end

    local response = utils.parse_json(res.stdout)

    if not response or not response["comments"] then
        mp.osd_message("此源弹幕无法加载", 3)
        return
    end

    local new_comments = response["comments"]
    local add_count = response["count"]

    if add_count == 0 then
        mp.osd_message("服务器无缓存数据，再次尝试请求", 30)

        local start = os.time()
        while os.time() - start < 2 do
            -- 空循环，等待 1 秒
        end

        res = get_danmaku_comments(url)
        response = utils.parse_json(res.stdout)
        new_comments = response["comments"]
        add_count = response["count"]
    end

    if add_count == 0 then
        mp.osd_message("此源弹幕为空，结束加载", 3)
        return
    end

    new_comments = convert_json_for_merge(new_comments)

    local old_comment_path = utils.join_path(danmaku_path, "danmaku.json")
    local comments = read_file(old_comment_path)

    if comments == nil then
        comments = {}
    else
        comments = utils.parse_json(comments)
    end

    for _, comment in ipairs(new_comments) do
        table.insert(comments, comment)
    end

    local json_filename = utils.join_path(danmaku_path, "danmaku.json")
    local json_file = io.open(json_filename, "w")

    if json_file then
        json_file:write("[\n")
        for _, comment in ipairs(comments) do
            local json_entry = string.format('{"c":"%s","m":"%s"},\n', comment["c"], comment["m"])
            json_file:write(json_entry)
        end
        json_file:write("]")
        json_file:close()
    else
        msg.verbose("Error saving JSON file")
    end

    local danmaku_json = utils.join_path(danmaku_path, "danmaku.json")
    convert_with_danmaku_factory(danmaku_json)
    remove_danmaku_track()
    local danmaku_file = utils.join_path(danmaku_path, "danmaku.ass")
    if not file_exists(danmaku_file) then
        mp.osd_message("未找到弹幕文件", 3)
    end
    mp.commandv("sub-add", danmaku_file, "auto", "danmaku")
    show_danmaku_func()
    mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
    mp.osd_message("弹幕加载成功，添加了" .. add_count .. "条弹幕，共计" .. #comments .. "条弹幕", 3)
end

function convert_json_for_merge(comments)
    local content = {}
    for _, comment in ipairs(comments) do
        local p = comment["p"]
        if p then
            local fields = split(p, ",")
            local c_value = string.format(
                "%s,%s,%s,25,,,",
                fields[1], -- first field of p to first field of c
                fields[3], -- third field of p to second field of c
                fields[2]  -- second field of p to third field of c
            )
            local m_value = comment["m"]

            m_value = escape_json_string(m_value)

            table.insert(content, { ["c"] = c_value, ["m"] = m_value })
        end
    end
    return content
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

                m_value = escape_json_string(m_value)

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
        danmaku_input,
        "--ignore-warnings",
        "--resolution", options.resolution,
        "--scrolltime", options.scrolltime,
        "--fontname", options.fontname,
        "--fontsize", options.fontsize,
        "--opacity", options.opacity,
        "--shadow", options.shadow,
        "--bold", options.bold,
        "--density", options.density,
        "--displayarea", options.displayarea,
        "--outline", options.outline,
    }

    if blacklist_file ~= "" and file_exists(blacklist_file) then
        table.insert(arg, "--blacklist")
        table.insert(arg, blacklist_file)
    end

    mp.command_native({
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        args = arg,
    })
end

function escape_json_string(str)
    -- 将 JSON 中需要转义的字符进行替换
    str = str:gsub("\\", "\\\\") -- 反斜杠
    str = str:gsub('"', '\\"')   -- 双引号
    str = str:gsub("\b", "\\b")  -- 退格符
    str = str:gsub("\f", "\\f")  -- 换页符
    str = str:gsub("\n", "\\n")  -- 换行符
    str = str:gsub("\r", "\\r")  -- 回车符
    str = str:gsub("\t", "\\t")  -- 制表符
    return str
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
local function get_danmaku_with_hash(file_name, file_path)
    if is_protocol(file_path) then
        return
    end
    -- 计算文件哈希
    local hash = get_file_md5(normalize(file_path))
    if not hash then
        return
    end

    -- 发送匹配请求
    local match_data_raw = match_file(file_name, hash)
    if not match_data_raw then
        return
    end

    -- 解析匹配结果
    local match_data = utils.parse_json(match_data_raw)
    if not match_data.isMatched then
        msg.verbose("No matching episode")
        return
    elseif #match_data.matches > 1 then
        msg.verbose("Multiple matching episodes")
        return
    end

    -- 获取并加载弹幕数据
    if options.save_hash_match then
        set_episode_id(match_data.matches[1].episodeId, true)
    else
        if options.load_more_danmaku then
            fetch_danmaku_all(match_data.matches[1].episodeId, true)
        else
            fetch_danmaku(match_data.matches[1].episodeId, true)
        end
    end
end

-- 自动加载上次匹配的弹幕
function auto_load_danmaku()
    local path = mp.get_property("path")
    local dir = get_parent_directory()
    local filename = mp.get_property('filename/no-ext')

    -- 加载可能存在的本地 xml 弹幕
    if options.autoload_local_danmaku then
        local danmaku_xml = utils.join_path(dir, filename .. ".xml")
        if file_exists(danmaku_xml) then
            convert_with_danmaku_factory(danmaku_xml)
            remove_danmaku_track()
            local danmaku_file = utils.join_path(danmaku_path, "danmaku.ass")
            if not file_exists(danmaku_file) then
                msg.verbose("xml 弹幕文件未转换成功")
            end
            mp.commandv("sub-add", danmaku_file, "auto", "danmaku")
            show_danmaku_func()
            mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
            return
        end
    end

    if dir ~= nil then
        local history_json = read_file(history_path)
        if history_json ~= nil then
            local history = utils.parse_json(history_json) or {}
            -- 1.判断父文件名是否存在
            local history_dir = history[dir]
            if history_dir ~= nil then
                --2.如果存在，则获取number和id
                local history_number = history[dir].episodeNumber
                local history_id = history[dir].episodeId
                local history_fname = history[dir].fname
                local playing_number = nil
                if history_fname then
                    if history_fname ~= filename then
                        history_number, playing_number = get_episode_number(history_fname)
                    else
                        playing_number = history_number
                    end
                else
                    playing_number = get_episode_number()
                end
                if playing_number ~= nil then
                    local x = playing_number - history_number --获取集数差值
                    local tmp_id = tostring(x + history_id)
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

if options.auto_load or options.autoload_local_danmaku then
    mp.register_event("file-loaded", auto_load_danmaku)
end

mp.add_hook("on_unload", 50, function()
    local rm1 = utils.join_path(danmaku_path, "danmaku.json")
    local rm2 = utils.join_path(danmaku_path, "danmaku.ass")
    if file_exists(rm1) then os.remove(rm1) end
    if file_exists(rm2) then os.remove(rm2) end
end)

mp.add_key_binding(options.open_search_danmaku_menu_key, "open_search_danmaku_menu", function ()
    mp.commandv("script-message", "open_search_danmaku_menu")
end)
mp.add_key_binding(options.show_danmaku_keyboard_key, "show_danmaku_keyboard", function ()
    mp.commandv("script-message", "show_danmaku_keyboard")
end)
