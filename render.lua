-- modified from https://github.com/rkscv/danmaku/blob/main/danmaku.lua
local msg = require('mp.msg')
local utils = require("mp.utils")

local INTERVAL = options.vf_fps and 0.01 or 0.001
local osd_width, osd_height, delay, pause = 0, 0, 0, true
enabled, comments = false, nil
local delay_property = string.format("user-data/%s/danmaku-delay", mp.get_script_name())
local opencc_path = mp.command_native({ "expand-path", options.OpenCC_Path })
mp.set_property_native(delay_property, 0)

-- 从时间字符串转换为秒数
local function time_to_seconds(time_str)
    local h, m, s = time_str:match("(%d+):(%d+):([%d%.]+)")
    return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
end

-- 提取 \move 参数 (x1, y1, x2, y2) 并返回
local function parse_move_tag(text)
    -- 匹配包括小数和负数在内的坐标值
    local x1, y1, x2, y2 = text:match("\\move%((%-?[%d%.]+),%s*(%-?[%d%.]+),%s*(%-?[%d%.]+),%s*(%-?[%d%.]+).*%)")
    if x1 and y1 and x2 and y2 then
        return tonumber(x1), tonumber(y1), tonumber(x2), tonumber(y2)
    end
    return nil
end

local function parse_comment(event, pos, height)
    local x1, y1, x2, y2 = parse_move_tag(event.text)
    local displayarea = tonumber(height * options.displayarea)
    if not x1 then
        local current_x, current_y = event.text:match("\\pos%((%-?[%d%.]+),%s*(%-?[%d%.]+).*%)")
        if tonumber(current_y) > displayarea then return end
        if event.style ~= "SP" and event.style ~= "MSG" then
            return string.format("{\\an8}%s", event.text)
        else
            return string.format("{\\an7}%s", event.text)
        end
    end

    -- 计算移动的时间范围
    local duration = event.end_time - event.start_time  --mean: options.scrolltime
    local progress = (pos - event.start_time - delay) / duration  -- 移动进度 [0, 1]

    -- 计算当前坐标
    local current_x = tonumber(x1 + (x2 - x1) * progress)
    local current_y = tonumber(y1 + (y2 - y1) * progress)

    -- 移除 \move 标签并应用当前坐标
    local clean_text = event.text:gsub("\\move%(.-%)", "")
    if current_y > displayarea then return end
    if event.style ~= "SP" and event.style ~= "MSG" then
        return string.format("{\\pos(%.1f,%.1f)\\an8}%s", current_x, current_y, clean_text)
    else
        return string.format("{\\pos(%.1f,%.1f)\\an7}%s", current_x, current_y, clean_text)
    end
end

local function ch_convert(ass_path, case)
    if case == 0 then
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

    mp.command_native({
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        args = arg,
    })

end

-- 从 ASS 文件中解析样式和事件
local function parse_ass(ass_path)
    ch_convert(ass_path, options.chConvert)

    local ass_file = io.open(ass_path, "r")
    if not ass_file then
        return nil
    end

    local events = {}
    local time_tolerance = options.merge_tolerance

    for line in ass_file:lines() do
        if line:match("^Dialogue:") then
            local start_time, end_time, style, text = line:match("Dialogue:%s*[^,]*,%s*([^,]*),%s*([^,]*),%s*([^,]*),[^,]*,[^,]*,[^,]*,[^,]*,[^,]*,(.*)")

            if start_time and end_time and text then
                local event = {
                    start_time = time_to_seconds(start_time),
                    end_time = time_to_seconds(end_time),
                    style = style,
                    text = text:gsub("%s+$", ""),
                    clean_text = text:gsub("\\pos%(.-%)", ""):gsub("\\move%(.-%)", ""),
                    pos = text:match("\\pos"),
                    move = text:match("\\move"),
                }

                local merged = false
                for _, existing_event in ipairs(events) do
                    if existing_event.clean_text == event.clean_text and
                       math.abs(existing_event.start_time - event.start_time) <= time_tolerance then
                        if (existing_event.style == event.style) or
                        (existing_event.pos == event.pos) or (existing_event.move == event.move) then
                            existing_event.end_time = math.max(existing_event.end_time, event.end_time)
                            existing_event.count = (existing_event.count or 1) + 1
                            if not existing_event.text:find("{\\b1\\i1}x%d+$") then
                                existing_event.text = existing_event.text .. "{\\b1\\i1}x" .. existing_event.count
                            else
                                existing_event.text = existing_event.text:gsub("x%d+$", "x" .. existing_event.count)
                            end
                            merged = true
                            break
                        end
                    end
                end

                if not merged then
                    event.count = 1
                    table.insert(events, event)
                end
            end
        end
    end

    table.sort(events, function(a, b)
        return a.start_time < b.start_time
    end)

    ass_file:close()
    return events
end

local overlay = mp.create_osd_overlay('ass-events')

local function render()
    if comments == nil then return end

    local pos, err = mp.get_property_number('time-pos')
    if err ~= nil then
        return msg.error(err)
    end

    local fontname = options.fontname
    local fontsize = options.fontsize

    local width, height = 1920, 1080
    local ratio = osd_width / osd_height
    if width / height < ratio then
        height = width / ratio
        fontsize = options.fontsize - ratio * 2
    end

    local ass_events = {}

    for _, event in ipairs(comments) do
        if pos >= event.start_time + delay and pos <= event.end_time + delay then
            local text = parse_comment(event, pos, height)

            if text and text:match("\\fs%d+") then
                local font_size = text:match("\\fs(%d+)") * 1.5
                text = text:gsub("\\fs%d+", string.format("\\fs%s", font_size))
            end

            -- 构建 ASS 字符串
            local ass_text = text and string.format("{\\fn%s\\fs%d\\c&HFFFFFF&\\alpha&H%x\\bord%s\\shad%s\\b%s\\q2}%s",
                fontname, text:match("{\\b1\\i1}x%d+$") and fontsize + text:match("x(%d+)$") or fontsize,
                options.transparency, options.outline, options.shadow, options.bold == "true" and "1" or "0", text)

            table.insert(ass_events, ass_text)
        end
    end

    overlay.res_x = width
    overlay.res_y = height
    overlay.data = table.concat(ass_events, '\n')
    overlay:update()
end

local timer = mp.add_periodic_timer(INTERVAL, render, true)

local function show_loaded()
    if danmaku.anime and danmaku.episode then
        show_message("匹配内容：" .. danmaku.anime .. "-" .. danmaku.episode .. "\\N弹幕加载成功，共计" .. #comments .. "条弹幕", 3)
        msg.info(danmaku.anime .. "-" .. danmaku.episode .. " 弹幕加载成功，共计" .. #comments .. "条弹幕")
    else
        show_message("弹幕加载成功，共计" .. #comments .. "条弹幕", 3)
    end
end

function parse_danmaku(ass_file_path, from_menu, no_osd)
    comments, err = parse_ass(ass_file_path)
    if not comments then
        msg.error("ASS 解析错误:", err)
        return
    end

    if enabled and (from_menu or get_danmaku_visibility()) then
        if not no_osd then
            show_loaded()
        end
        show_danmaku_func()
        mp.commandv("script-message-to", "uosc", "set", "show_danmaku", "on")
    else
        show_message("")
        hide_danmaku_func()
    end
end

local function filter_state(label, key, value)
    local filters = mp.get_property_native("vf")
    for _, filter in pairs(filters) do
        if filter["label"] == label and (not key or key and filter[key] == value) then
            return true
        end
    end
    return false
end

function show_danmaku_func()
    render()
    if not pause then
        timer:resume()
    end
    enabled = true
    set_danmaku_visibility(true)
    if options.vf_fps then
        local display_fps = mp.get_property_number('display-fps')
        local video_fps = mp.get_property_number('estimated-vf-fps')
        if (display_fps and display_fps < 58) or (video_fps and video_fps > 58) then
            return
        end
        mp.commandv("vf", "append", "@danmaku:fps=fps=60/1.001")
    end
end

function hide_danmaku_func()
    timer:kill()
    overlay:remove()
    enabled = false
    set_danmaku_visibility(false)
    if filter_state("danmaku") then
        mp.commandv("vf", "remove", "@danmaku")
    end
end

local message_overlay = mp.create_osd_overlay('ass-events')
local message_timer = mp.add_timeout(3, function ()
    message_overlay:remove()
end, true)

function show_message(text, time)
    message_timer.timeout = time or 3
    message_timer:kill()
    message_overlay:remove()
    local message = string.format("{\\an%d\\pos(%d,%d)}%s", options.message_anlignment,
       options.message_x, options.message_y, text)
    local width, height = 1920, 1080
    local ratio = osd_width / osd_height
    if width / height < ratio then
        height = width / ratio
    end
    message_overlay.res_x = width
    message_overlay.res_y = height
    message_overlay.data = message
    message_overlay:update()
    message_timer:resume()
end

mp.observe_property('osd-width', 'number', function(_, value) osd_width = value or osd_width end)
mp.observe_property('osd-height', 'number', function(_, value) osd_height = value or osd_height end)
mp.observe_property('display-fps', 'number', function(_, value)
    if value ~= nil then
        local interval = 1 / value / 10
        if interval > INTERVAL then
            timer:kill()
            timer = mp.add_periodic_timer(interval, render, true)
            if enabled then
                timer:resume()
            end
        else
            timer:kill()
            timer = mp.add_periodic_timer(INTERVAL, render, true)
            if enabled then
                timer:resume()
            end
        end
    end
end)
mp.observe_property('pause', 'bool', function(_, value)
    if value ~= nil then
        pause = value
    end
    if enabled then
        if pause then
            timer:kill()
        elseif comments ~= nil then
            timer:resume()
        end
    end
end)

mp.add_hook("on_unload", 50, function()
    mp.unobserve_property('pause')
    comments, delay = nil, 0
    timer:kill()
    overlay:remove()
    mp.set_property_native(delay_property, 0)
    if filter_state("danmaku") then
        mp.commandv("vf", "remove", "@danmaku")
    end

    local danmaku_path = os.getenv("TEMP") or "/tmp/"
    local rm1 = utils.join_path(danmaku_path, "danmaku.json")
    local rm2 = utils.join_path(danmaku_path, "danmaku.ass")
    local rm3 = utils.join_path(danmaku_path, "danmaku.xml")
    local rm4 = utils.join_path(danmaku_path, "temp.mp4")
    local rm5 = utils.join_path(danmaku_path, "bahamut.json")
    if file_exists(rm1) then os.remove(rm1) end
    if file_exists(rm2) then
        if options.save_danmaku then
            save_danmaku_func("xml")
        end
        os.remove(rm2)
    end
    if file_exists(rm3) then os.remove(rm3) end
    if file_exists(rm4) then os.remove(rm4) end
    if file_exists(rm5) then os.remove(rm5) end
    for _, source in pairs(danmaku.sources) do
        if source.fname and source.from and source.from ~= "user_local" and file_exists(source.fname) then
            os.remove(source.fname)
        end
    end
    danmaku = {sources = {}, count = 1}
end)

mp.register_event('playback-restart', function(event)
    if event.error then
        return msg.error(event.error)
    end
    if enabled and comments ~= nil then
        render()
    end
end)

mp.register_script_message("danmaku-delay", function(number)
    local value = tonumber(number)
    if value == nil then
        return msg.error('command danmaku-delay: invalid time')
    end
    delay = delay + value
    if enabled and comments ~= nil then
        render()
    end
    show_message('设置弹幕延迟: ' .. delay .. ' s')
    mp.set_property_native(delay_property, delay)
end)
