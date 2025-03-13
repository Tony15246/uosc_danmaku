local msg = require('mp.msg')
local utils = require("mp.utils")

pid = utils.getpid()
danmaku = {sources = {}, count = 1}
delay_property = string.format("user-data/%s/danmaku-delay", mp.get_script_name())

require("modules/options")
require("modules/utils")
require("modules/guess")
require('modules/render')
require('modules/menu')

require("apis/dandanplay")
require('apis/extra')

danmaku_path = os.getenv("TEMP") or "/tmp/"
history_path = mp.command_native({"expand-path", options.history_path})

local exec_path = mp.command_native({ "expand-path", options.DanmakuFactory_Path })
local opencc_path = mp.command_native({ "expand-path", options.OpenCC_Path })
local blacklist_file = mp.command_native({ "expand-path", options.blacklist_path })

platform = (function()
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

function set_danmaku_button()
    if get_danmaku_visibility() then
        mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
    end
end

function show_loaded(init)
    if danmaku.anime and danmaku.episode then
        show_message("匹配内容：" .. danmaku.anime .. "-" .. danmaku.episode .. "\\N弹幕加载成功，共计" .. #comments .. "条弹幕", 3)
        if init then
            msg.info(danmaku.anime .. "-" .. danmaku.episode .. " 弹幕加载成功，共计" .. #comments .. "条弹幕")
        end
    else
        show_message("弹幕加载成功，共计" .. #comments .. "条弹幕", 3)
    end
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

local function extract_between_colons(input_string)
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

local function hex_to_int_color(hex_color)
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

local function get_type_from_position(position)
    if position == 0 then
        return 1
    end
    if position == 1 then
        return 4
    end
    return 5
end

function write_history(episodeid)
    local history = {}
    local path = mp.get_property("path")
    local dir = get_parent_directory(path)
    local fname = mp.get_property('filename/no-ext')
    local episodeNumber = 0
    if episodeid then
        episodeNumber = tonumber(episodeid) % 1000
    elseif danmaku.extra then
        episodeNumber = danmaku.extra.episodenum
    end

    if is_protocol(path) then
        local title, season_num, episod_num = parse_title()
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

    if dir ~= nil then
        local history_json = read_file(history_path)
        if history_json ~= nil then
            history = utils.parse_json(history_json) or {}
        end
        history[dir] = {}
        history[dir].fname = fname
        history[dir].source = danmaku.source
        history[dir].animeTitle = danmaku.anime
        history[dir].episodeTitle = danmaku.episode
        history[dir].episodeNumber = episodeNumber
        if episodeid then
            history[dir].episodeId = episodeid
        elseif danmaku.extra then
            history[dir].extra = danmaku.extra
        end
        write_json_file(history_path, history)
    end
end

function remove_source_from_history(rm_source)
    local history_json = read_file(history_path)
    local path = mp.get_property("path")

    if history_json then
        local history = utils.parse_json(history_json) or {}

        if history[path] ~= nil then
            for i, source in ipairs(history[path]) do
                source = source:gsub("^-", ""):gsub("^<.->", ""):gsub("^{{.-}}", "")
                if source == rm_source then
                    table.remove(history[path], i)
                    break
                end
            end
        end

        write_json_file(history_path, history)
    end
end

function add_source_to_history(add_url, add_source)
    local history_json = read_file(history_path)
    local path = mp.get_property("path")

    if is_protocol(path) then
        path = remove_query(path)
    end

    if history_json then
        local history = utils.parse_json(history_json) or {}
        history[path] = history[path] or {}

        for i, source in ipairs(history[path]) do
            source = source:gsub("^-", ""):gsub("^<.->", ""):gsub("^{{.-}}", "")
            if source == add_url then
                table.remove(history[path], i)
                break
            end
        end

        if add_source.delay then
            add_url = "{{" .. add_source.delay .. "}}" .. add_url
        end

        if add_source.from then
            add_url = "<" .. add_source.from .. ">" .. add_url
        end

        if add_source.blocked then
            add_url = "-" .. add_url
        end

        table.insert(history[path], add_url)

        write_json_file(history_path, history)
    end
end

function read_danmaku_source_record(path)
    if is_protocol(path) then
        path = remove_query(path)
    end

    local history_json = read_file(history_path)

    if history_json ~= nil then
        local history = utils.parse_json(history_json) or {}
        local history_record = history[path]
        if history_record ~= nil then
            for _, source in ipairs(history_record) do
                local blocked = false
                local from = string.match(source,"<(.-)>")
                local delay = string.match(source,"{{(.-)}}")
                if source:match("^-") then
                    source = source:sub(2)
                    blocked = true
                    from = "api_server"
                end
                if from then
                    source = source:gsub("<" .. from .. ">", "")
                end
                if delay then
                    source = source:gsub("{{%-?" .. delay .. "}}", "")
                end

                danmaku.sources[source] = {}

                if blocked then
                    danmaku.sources[source]["blocked"] = true
                end

                danmaku.sources[source]["from"] = from or "user_custom"

                if delay then
                    danmaku.sources[source]["delay"] = delay
                end

                danmaku.sources[source]["from_history"] = true
            end
        end
    end
end

-- 视频播放时保存弹幕
function save_danmaku()
    local danmaku_file = utils.join_path(danmaku_path, "danmaku-" .. pid .. ".ass")
    if file_exists(danmaku_file) then
        local path = mp.get_property("path")
        -- 排除网络播放场景
        if not path or is_protocol(path) then
            show_message("此弹幕文件不支持保存至本地")
            msg.warn("此弹幕文件不支持保存至本地")
        else
            local dir = get_parent_directory(path)
            local filename = mp.get_property('filename/no-ext')
            local danmaku_out = utils.join_path(dir, filename .. ".xml")
            -- show_message(danmaku_out)
            if file_exists(danmaku_out) then
                show_message("已存在同名弹幕文件：" .. danmaku_out)
                msg.info("已存在同名弹幕文件：" .. danmaku_out)
                return
            else
                convert_with_danmaku_factory(danmaku_file, danmaku_out)
                if file_exists(danmaku_out) then
                    if not options.save_danmaku then
                        show_message("成功保存 xml 弹幕文件到视频文件目录")
                    end
                    msg.warn("成功保存 xml 弹幕文件到: " .. danmaku_out)
                else
                    if not options.save_danmaku then
                        show_message("弹幕保存失败", 3)
                    end
                    msg.error("弹幕保存失败")
                end
            end
        end
    else
        show_message("找不到弹幕文件：" .. danmaku_file)
        msg.warn("找不到弹幕文件：" .. danmaku_file)
    end
end

-- 加载弹幕
function load_danmaku(from_menu, no_osd)
    if not enabled then return end
    local temp_file = "danmaku-" .. pid .. ".ass"
    local danmaku_file = utils.join_path(danmaku_path, temp_file)
    local danmaku_input = {}
    local delays = {}

    -- 收集需要加载的弹幕文件
    for _, source in pairs(danmaku.sources) do
        if not source.blocked and source.fname then
            if not file_exists(source.fname) then
                show_message("未找到弹幕文件", 3)
                msg.info("未找到弹幕文件")
                return
            end
            table.insert(danmaku_input, source.fname)

            if source.delay then
                table.insert(delays, source.delay)
            else
                table.insert(delays, "0.0")
            end
        end
    end

    -- 如果没有弹幕文件，退出加载
    if #danmaku_input == 0 then
        show_message("该集弹幕内容为空，结束加载", 3)
        msg.verbose("该集弹幕内容为空，结束加载")
        comments = {}
        return
    end

    -- 异步执行弹幕转换
    convert_with_danmaku_factory(danmaku_input, nil, delays, function(error)
        if error then
            show_message("弹幕转换失败", 3)
            msg.error("弹幕转换失败：" .. error)
            return
        end

        -- 转换完成后加载弹幕
        parse_danmaku(danmaku_file, from_menu, no_osd)
    end)
end

-- 使用 DanmakuFactory 转换弹幕文件
function convert_with_danmaku_factory(danmaku_input, danmaku_out, delays, callback)
    if exec_path == "" then
        exec_path = utils.join_path(mp.get_script_directory(), "bin/DanmakuFactory")
        if platform == "windows" then
            exec_path = utils.join_path(exec_path, "DanmakuFactory.exe")
        else
            exec_path = utils.join_path(exec_path, "DanmakuFactory")
        end
    end
    local danmaku_factory_path = os.getenv("DANMAKU_FACTORY") or exec_path

    local temp_file = "danmaku-" .. pid .. ".ass"
    local danmaku_file = utils.join_path(danmaku_path, temp_file)

    local arg = {
        danmaku_factory_path,
        "-o",
        danmaku_out and danmaku_out or danmaku_file,
        "-i",
        "-t",
        "--ignore-warnings",
        "--scrolltime", options.scrolltime,
        "--fontname", "sans-serif",
        "--fontsize", options.fontsize,
        "--shadow", options.shadow,
        "--bold", options.bold,
        "--density", options.density,
    --  "--displayarea", options.displayarea,
        "--outline", options.outline,
    }

    local shift = 1

    if options.font_size_strict == "true" then
        table.insert(arg, 13, "--font-size-strict")
    end

    -- 检查 danmaku_input 是字符串还是数组，并插入到正确的位置
    if type(danmaku_input) == "string" then
        -- 如果是单个字符串，直接插入
        table.insert(arg, 5, danmaku_input)
    else
        -- 如果是字符串数组，逐个插入
        for i, input in ipairs(danmaku_input) do
            table.insert(arg, 4 + i, input)
        end
        shift = #danmaku_input
    end

    if delays then
        for i, delay in ipairs(delays) do
            table.insert(arg, 5 + shift + i, delay)
        end
    else
        table.insert(arg, 6 + shift, "0.0")
    end

    if blacklist_file ~= "" and file_exists(blacklist_file) then
        table.insert(arg, "--blacklist")
        table.insert(arg, blacklist_file)
    end

    if options.blockmode ~= "" then
        table.insert(arg, "--blockmode")
        table.insert(arg, options.blockmode)
    end

    if not callback then
        mp.command_native({
            name = 'subprocess',
            playback_only = false,
            capture_stdout = true,
            args = arg,
        })
    else
        -- 异步执行命令
        call_cmd_async(arg, function(error, _)
            async_running = false
            if callback then
                callback(error)
            end
        end)
    end
end

-- 简繁转换
function ch_convert(ass_path, case, callback)
    if case == 0 then
        callback(nil)
        return
    end

    if opencc_path == "" then
        opencc_path = utils.join_path(mp.get_script_directory(), "bin")
        if platform == "windows" then
            opencc_path = utils.join_path(opencc_path, "OpenCC_Windows/opencc.exe")
        else
            opencc_path = utils.join_path(opencc_path, "OpenCC_Linux/opencc")
        end
    end
    opencc_path = os.getenv("OPENCC") or opencc_path

    local config
    if case == 1 then
        config = "t2s.json"
    elseif case == 2 then
        config = "s2t.json"
    else
        callback("无效的转换配置")
        return
    end

    local arg = {
        opencc_path,
        "-i",
        ass_path,
        "-o",
        ass_path,
        "-c",
        config,
    }

    call_cmd_async(arg, function(error, _)
        async_running = false
        if error then
            callback("OpenCC 转换失败：" .. error)
        else
            callback(nil)
        end
    end)
end

-- 为 bilibli 网站的视频播放加载弹幕
function load_danmaku_for_bilibili(path)
    local cid, danmaku_id = get_cid()
    if danmaku_id ~= nil then
        mp.commandv('sub-remove', danmaku_id)
    end

    if cid == nil then
        cid = mp.get_opt('cid')
        if not cid then
            local patterns = {
                "bilivideo%.c[nom]+.*/resource/(%d+)%D+.*",
                "bilivideo%.c[nom]+.*/(%d+)-%d+-%d+%..*%?",
            }
            local urls = {
                path,
                mp.get_property("stream-open-filename", ''),
            }

            for _, pattern in ipairs(patterns) do
                for _, url in ipairs(urls) do
                    if url:find(pattern) then
                        cid = url:match(pattern)
                        break
                    end
                end
            end
        end
    end
    if cid == nil and path:match("/video/BV.-") then
        if path:match("video/BV.-/.*") then
            path = path:gsub("/[^/]+$", "")
        end
        add_danmaku_source_online(path, true)
        return
    end
    if cid ~= nil then
        local url = "https://comment.bilibili.com/" .. cid .. ".xml"
        local temp_file = "danmaku-" .. pid .. danmaku.count .. ".xml"
        local danmaku_xml = utils.join_path(danmaku_path, temp_file)
        danmaku.count = danmaku.count + 1
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

        call_cmd_async(arg, function(error)
            async_running = false
            if error then
                show_message("HTTP 请求失败，打开控制台查看详情", 5)
                msg.error(error)
                return
            end
            if file_exists(danmaku_xml) then
                save_danmaku_downloaded(path, danmaku_xml)
                load_danmaku(true)
            end
        end)
    end
end

-- 为 bahamut 网站的视频播放加载弹幕
function load_danmaku_for_bahamut(path)
    local path = path:gsub('%%(%x%x)', hex_to_char)
    local sn = extract_between_colons(path)
    if sn == nil then
        return
    end
    local url = "https://ani.gamer.com.tw/ajax/danmuGet.php"
    local temp_file = "bahamut-" .. pid .. ".json"
    local danmaku_json = utils.join_path(danmaku_path, temp_file)
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

    if options.proxy ~= "" then
        table.insert(arg, '-x')
        table.insert(arg, options.proxy)
    end

    call_cmd_async(arg, function(error)
        async_running = false
        if error then
            show_message("HTTP 请求失败，打开控制台查看详情", 5)
            msg.error(error)
            return
        end
        if not file_exists(danmaku_json) then
            url = "https://ani.gamer.com.tw/animeVideo.php?sn=" .. sn
            enabled = true
            add_danmaku_source_online(url, true)
            return
        end

        local comments_json = read_file(danmaku_json)
        local comments = utils.parse_json(comments_json)
        if not comments then
            return
        end

        temp_file = "danmaku-" .. pid .. danmaku.count .. ".json"
        local json_filename = utils.join_path(danmaku_path, temp_file)
        danmaku.count = danmaku.count + 1
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

        if file_exists(json_filename) then
            save_danmaku_downloaded(
                "https://ani.gamer.com.tw/animeVideo.php?sn=" .. sn,
                json_filename)
            load_danmaku(true)
        end
    end)
end

function load_danmaku_for_url(path)
    if path:find('bilibili.com') or path:find('bilivideo.c[nom]+') then
        load_danmaku_for_bilibili(path)
        return
    end

    if path:find('bahamut.akamaized.net') then
        load_danmaku_for_bahamut(path)
        return
    end

    local title, season_num, episod_num = parse_title()
    local filename = url_decode(mp.get_property("media-title"))
    local episod_number = nil
    if title and episod_num then
        if season_num then
            dir = title .." Season".. season_num
            episod_number = episod_num
        else
            dir = title
        end
        auto_load_danmaku(path, dir, filename, episod_number)
        addon_danmaku(dir, false)
        return
    end
    get_danmaku_with_hash(filename, path)
    addon_danmaku()
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
                local history_extra = history_dir.extra
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
                    danmaku.episode = episode_number and string.format("第%s话", episode_number + x) or history_dir.episodeTitle
                    show_message("自动加载上次匹配的弹幕", 3)
                    msg.verbose("自动加载上次匹配的弹幕")
                    if history_id then
                        local tmp_id = tostring(x + history_id)
                        set_episode_id(tmp_id)
                    elseif history_extra then
                        local episodenum = history_extra.episodenum + x
                        get_details(history_extra.class, history_extra.id, history_extra.site,
                            history_extra.title, history_extra.year, history_extra.number, episodenum)
                    end
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
    local video = mp.get_property_native("current-tracks/video")
    local fps = mp.get_property_number("container-fps", 0)
    local duration = mp.get_property_number("duration", 0)
    if not video or video["image"] or video["albumart"] or fps < 23 or duration < 60 then
        msg.info("不支持的播放内容（非视频）")
        return
    end
    if is_protocol(path) then
        load_danmaku_for_url(path)
    end
    if dir and filename then
        local danmaku_xml = utils.join_path(dir, filename .. ".xml")
        if file_exists(danmaku_xml) then
            add_danmaku_source_local(danmaku_xml, true)
        else
            auto_load_danmaku(path, dir, filename)
            addon_danmaku(dir, true)
        end
    end
end

mp.register_event("file-loaded", function()
    local path = mp.get_property("path")
    local dir = get_parent_directory(path)
    local filename = mp.get_property('filename/no-ext')
    local video = mp.get_property_native("current-tracks/video")
    local fps = mp.get_property_number("container-fps", 0)
    local duration = mp.get_property_number("duration", 0)
    if not video or video["image"] or video["albumart"] or fps < 23 or duration < 60 then
        return
    end

    read_danmaku_source_record(path)

    if not get_danmaku_visibility() then
        return
    end

    if options.autoload_for_url and is_protocol(path) then
        enabled = true
        load_danmaku_for_url(path)
    end

    if filename == nil or dir == nil then
        return
    end
    local danmaku_xml = utils.join_path(dir, filename .. ".xml")
    if options.autoload_local_danmaku then
        if file_exists(danmaku_xml) then
            enabled = true
            add_danmaku_source_local(danmaku_xml)
            return
        end
    end

    if options.auto_load then
        enabled = true
        auto_load_danmaku(path, dir, filename)
        addon_danmaku(dir, false)
        return
    end

    if enabled and comments == nil and not async_running then
        init(path)
    end
end)

-------------- 键位绑定 --------------
mp.add_key_binding(options.open_search_danmaku_menu_key, "open_search_danmaku_menu", function()
    mp.commandv("script-message", "open_search_danmaku_menu")
end)
mp.add_key_binding(options.show_danmaku_keyboard_key, "show_danmaku_keyboard", function()
    mp.commandv("script-message", "show_danmaku_keyboard")
end)

mp.register_script_message("danmaku-delay", function(number)
    local value = tonumber(number)
    if value == nil then
        return msg.error('command danmaku-delay: invalid time')
    end
    if value == 0 then
        delay = 0
    else
        delay = delay + value
    end
    if enabled and comments ~= nil then
        render()
    end
    show_message('设置弹幕延迟: ' .. delay .. ' s')
    mp.set_property_native(delay_property, delay)
end)

mp.register_script_message("clear-source", function()
    local path = mp.get_property("path")
    local history_json = read_file(history_path)

    if history_json ~= nil then
        local history = utils.parse_json(history_json) or {}
        if path and history[path] ~= nil then
            history[path] = nil
            write_json_file(history_path, history)
            for url, source in pairs(danmaku.sources) do
                if source.from == "user_custom" then
                    if source.fname and file_exists(source.fname) then
                        os.remove(source.fname)
                    end
                    danmaku.sources[url] = nil
                end
            end
            load_danmaku(false)
            show_message("已重置当前视频所有弹幕源更改", 3)
            msg.verbose("已重置当前视频所有弹幕源更改")
        end
    end
end)

mp.register_script_message("show_danmaku_keyboard", function()
    enabled = not enabled
    if enabled then
        mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
        set_danmaku_visibility(true)
        if comments == nil then
            show_message("加载弹幕初始化...", 3)
            local path = mp.get_property("path")
            init(path)
        else
            show_loaded()
            show_danmaku_func()
        end
    else
        show_message("关闭弹幕", 2)
        mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "off")
        set_danmaku_visibility(false)
        hide_danmaku_func()
    end
end)

mp.register_script_message("immediately_save_danmaku", save_danmaku)
mp.register_script_message("open_source_delay_menu", danmaku_delay_setup)
mp.register_script_message("open_search_danmaku_menu", open_input_menu)
mp.register_script_message("open_add_source_menu", open_add_menu)
mp.register_script_message("open_add_total_menu", open_add_total_menu)
