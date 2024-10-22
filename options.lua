local opt = require("mp.options")

-- 选项
local options = {
    api_server = "https://api.dandanplay.net",
    load_more_danmaku = false,
    auto_load = false,
    autoload_local_danmaku = false,
    autoload_for_url = false,
    user_agent = "mpv_danmaku/1.0",
    proxy = "",
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

opt.read_options(options, mp.get_script_name(), function() end)

return options