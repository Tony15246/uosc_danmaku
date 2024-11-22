local opt = require("mp.options")

-- 选项
options = {
    api_server = "https://api.dandanplay.net",
    load_more_danmaku = false,
    auto_load = false,
    autoload_local_danmaku = false,
    autoload_for_url = false,
    add_from_source = false,
    user_agent = "mpv_danmaku/1.0",
    proxy = "",
    -- 使用 fps 视频滤镜，大幅提升弹幕平滑度。默认禁用
    vf_fps = false,
    -- 透明度：0（不透明）到255（完全透明）
    transparency = 0x30,
    -- 指定合并重复弹幕的时间间隔的容差值，单位为秒。默认值: -1，表示禁用
    merge_tolerance = -1,
    -- 指定 DanmakuFactory 程序的路径，支持绝对路径和相对路径
    -- 留空（默认值）会在脚本同目录的 bin 中查找
    -- 示例：DanmakuFactory_Path = 'DanmakuFactory' 会在环境变量 PATH 中或 mpv 程序旁查找该程序
    DanmakuFactory_Path = "",
    -- 指定弹幕关联历史记录文件的路径，支持绝对路径和相对路径
    history_path = "~~/danmaku-history.json",
    open_search_danmaku_menu_key = "Ctrl+d",
    show_danmaku_keyboard_key = "j",
    --速度
    scrolltime = "15",
    --字体
    fontname = "sans-serif",
    --大小 
    fontsize = "50",
    --阴影
    shadow = "0",
    --粗体 true false
    bold = "true",
    --弹幕密度 整数(>=-1) -1：表示不重叠 0：表示无限制 其他表示限定条数
    density = "0.0",
    --全部弹幕的显示范围(0.0-1.0)
    displayarea = "0.85",
    --描边 0-4
    outline = "1.0",
    -- 指定不会显示在屏幕上的弹幕类型。使用“-”连接类型名称，例如“L2R-TOP-BOTTOM”。可用的类型包括：L2R,R2L,TOP,BOTTOM,SPECIAL,COLOR,REPEAT
    blockmode = "",
    --指定弹幕屏蔽词文件路径(black.txt)，支持绝对路径和相对路径。文件内容以换行分隔
    blacklist_path = "",
}

opt.read_options(options, mp.get_script_name(), function() end)
