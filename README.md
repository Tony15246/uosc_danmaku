# uosc_danmaku
在MPV播放器中加载弹弹play弹幕，基于 uosc UI框架和弹弹play API的mpv弹幕扩展插件

## 项目简介

插件具体效果见演示视频：

https://github.com/user-attachments/assets/86717e75-9176-4f1a-88cd-71fa94da0c0e

### 主要功能
1. 从弹弹play的API获取剧集及弹幕数据，并根据用户选择的集数加载弹幕
2. 通过点击uosc control bar中的弹幕搜索按钮可以显示搜索菜单供用户选择需要的弹幕
3. 通过点击加入uosc control bar中的弹幕开关控件可以控制弹幕的开关

无需亲自下载整合弹幕文件资源，无需亲自处理文件格式转换，在mpv播放器中一键加载包含了哔哩哔哩、巴哈姆特等弹幕网站弹幕的弹弹play的动画弹幕。

插件本身支持Linux和Windows平台。项目依赖于[uosc UI框架](https://github.com/tomasklaen/uosc)。欲使用本插件必须在mpv播放器中安装有uosc。uosc的安装步骤可以参考其[官方安装教程](https://github.com/tomasklaen/uosc?tab=readme-ov-file#install)。当然，如果使用[MPV_lazy](https://github.com/hooke007/MPV_lazy)等内置了uosc的懒人包则只需安装本插件即可。

另外本插件也使用了DanmakuFactory弹幕格式转换工具。在Windows平台上本插件调用DanmakuFactory官方release版的DanmakuFactory.exe文件，在Linux平台上本插件调用基于作者自己Linux系统编译的二进制文件。如果本项目仓库中bin文件夹下提供的可执行文件无法正确运行，请前往[DanmakuFactory项目地址](https://github.com/hihkm/DanmakuFactory)，按照其教程选择或编译兼容自己环境的可执行文件。

## 使用方法

### 下载

一般的mpv配置目录结构大致如下

```
~/.config/mpv
├── fonts
├── input.conf
├── mplayer-input.conf
├── mpv.conf
├── script-opts
└── scripts
```

想要使用本插件，请将本插件完整地下载或者克隆到`scripts`目录下，文件结构如下：

> 务必注意⚠️
> 1. scripts目录下放置本插件的文件夹名称必须为uosc_danmaku，否则必须参照uosc控件配置部分[修改uosc控件](#修改uosc控件可选)
> 2. danmaku目录虽然下载或者克隆时为空，但插件依赖此目录缓存弹幕文件，此文件夹不可或缺，不要因为这是空文件夹就删除此文件夹
> 3. 记得给bin文件夹下的文件赋予可执行权限

```
~/.config/mpv/scripts 
└── uosc_danmaku
    ├── api.lua
    ├── bin
    │   ├── DanmakuFactory
    │   └── DanmakuFactory.exe
    ├── danmaku
    └── main.lua
```
### 配置

#### uosc控件配置

这一步非常重要，不添加控件，弹幕搜索按钮和弹幕开关就不会显示在进度条上方的控件条中。若没有控件，则只能通过[绑定快捷键](#绑定快捷键可选)调用弹幕搜索和弹幕开关功能

想要添加uosc控件，需要修改mpv配置文件夹下的`script-opts`中的`uosc.conf`文件。如果已经安装了uosc，但是`script-opts`文件夹下没有`uosc.conf`文件，可以去[uosc项目地址](https://github.com/tomasklaen/uosc)下载官方的`uosc.conf`文件，并按照后面的配置步骤进行配置。

由于uosc最近才更新了部分接口和控件代码，导致老旧版本的uosc和新版的uosc配置有所不同。如果是下载的最新git版uosc或者一直保持更新的用户按照[最新版uosc的控件配置步骤](#最新版uosc的控件配置步骤)配置即可。如何不确定自己的uosc版本，或者在使用诸如[MPV_lazy](https://github.com/hooke007/MPV_lazy)等由第三方管理uosc版本的用户，可以使用兼容新版和旧版uosc的[旧版uosc控件配置步骤](#旧版uosc控件配置步骤)

##### 最新版uosc的控件配置步骤

找到`uosc.conf`文件中的`controls`配置项，uosc官方默认的配置可能如下：

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

在`controls`控件配置项中添加`button:danmaku`的弹幕搜索按钮和`cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关`的弹幕开关。放置的位置就是实际会在在进度条上方的控件条中显示的位置，可以放在自己喜欢的位置。我个人把这两个控件放在了`<stream>stream-quality`画质选择控件后边。添加完控件的配置大概如下：

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,button:danmaku,cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

##### 旧版uosc控件配置步骤

找到`uosc.conf`文件中的`controls`配置项，uosc官方默认的配置可能如下：

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

在`controls`控件配置项中添加`command:search:script-message open_search_menu?搜索弹幕`的弹幕搜索按钮和`cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关`的弹幕开关。放置的位置就是实际会在在进度条上方的控件条中显示的位置，可以放在自己喜欢的位置。我个人把这两个控件放在了`<stream>stream-quality`画质选择控件后边。添加完控件的配置大概如下：

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,command:search:script-message open_search_menu?搜索弹幕,cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

##### 修改uosc控件（可选）

如果出于重名等各种原因，无法将本插件所放置的文件夹命名为`uosc_danmaku`的话，需要修改`cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关`的弹幕开关配置中的`uosc_danmaku`改为放置本插件的文件夹的名称。假如将本插件放置在`my_folder`文件夹下，那么弹幕开关配置就要修改为`cycle:toggle_on:show_danmaku@my_folder:on=toggle_on/off=toggle_off?弹幕开关`

#### 绑定快捷键（可选）

对于坚定的键盘爱好者和不使用鼠标主义者，可以选择通过快捷键调用弹幕搜索和弹幕开关功能

弹幕搜索功能绑定的脚本消息为`open_search_danmaku_menu`和`show_danmaku_keyboard`

如需配置快捷键，只需在`input.conf`中添加如下行即可。快捷键可以改为自己喜欢的组合

```
Ctrl+d script-message open_search_danmaku_menu
j script-message show_danmaku_keyboard
```
