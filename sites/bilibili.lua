local msg = require('mp.msg')
local utils = require("mp.utils")

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

local function get_bilibili_id_and_page(path)
    local bvid, aid, page = nil, nil, nil
    if not bvid then
        bvid = path:match("/video/(BV[%w]+)")
            or path:match("[?&]bvid=(BV[%w]+)")
    end
    if not aid then
        aid = path:match("/video/av([%d]+)")
    end
    if not page then
        page = tonumber(path:match("[?&]p=(%d+)"))
    end
    return bvid, aid, page or 1
end

local function get_bilibili_pagelist_args(bvid, aid)
    local url
    if bvid ~= nil then
        url = "https://api.bilibili.com/x/player/pagelist?bvid=" .. bvid
    else
        url = "https://api.bilibili.com/x/player/pagelist?aid=" .. aid
    end
    local arg = {
        "curl",
        "-L",
        "-s",
        "--compressed",
        "--user-agent",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.0.0",
        "-H",
        "Referer: https://www.bilibili.com/video/" .. (bvid or ("av" .. aid)),
        url
    }
    if options.cookie_file and options.cookie_file ~= "" then
        table.insert(arg, '-b')
        table.insert(arg, mp.command_native({"expand-path", options.cookie_file}))
    end

    if options.proxy ~= "" then
        table.insert(arg, '-x')
        table.insert(arg, options.proxy)
    end

    return arg
end

local function resolve_bilibili_cid(path, callback)
    local bvid, aid, page = get_bilibili_id_and_page(path)
    if not bvid and not aid then
        callback(nil)
        return
    end

    call_cmd_async(get_bilibili_pagelist_args(bvid, aid), function(error, json)
        if error then
            msg.warn("Failed to request bilibili pagelist: " .. tostring(error))
            callback(nil)
            return
        end

        local data = utils.parse_json(json)
        local pages = data and data["data"]
        if type(pages) ~= "table" then
            callback(nil)
            return
        end

        local page_info = pages[page] or pages[1]
        local cid = page_info and page_info["cid"]
        callback(cid and tostring(cid) or nil)
    end)
end

local function download_bilibili_danmaku(path, cid, from_menu)
    local url = "https://comment.bilibili.com/" .. cid .. ".xml"
    local temp_file = "danmaku-" .. PID .. DANMAKU.count .. ".xml"
    local danmaku_xml = utils.join_path(DANMAKU_PATH, temp_file)
    DANMAKU.count = DANMAKU.count + 1
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

    if options.cookie_file and options.cookie_file ~= "" then
        table.insert(arg, '-b')
        table.insert(arg, mp.command_native({"expand-path", options.cookie_file}))
    end

    if options.proxy ~= "" then
        table.insert(arg, '-x')
        table.insert(arg, options.proxy)
    end

    call_cmd_async(arg, function(error)
        if error then
            show_message("HTTP request failed, see console for details", 5)
            msg.error(error)
            return
        end
        if file_exists(danmaku_xml) then
            save_danmaku_downloaded(path, danmaku_xml)
            load_danmaku(from_menu == nil and true or from_menu)
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
    if cid == nil then
        resolve_bilibili_cid(path, function(resolved_cid)
            if resolved_cid then
                download_bilibili_danmaku(path, resolved_cid, true)
            else
                show_message("获取哔哩哔哩视频cid失败", 3)
                msg.error("获取哔哩哔哩视频cid失败")
            end
        end)
        return
    end
    if cid ~= nil then
        download_bilibili_danmaku(path, cid, true)
    end
end
