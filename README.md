# uosc_danmaku

在MPV播放器中加载弹弹play弹幕，基于 uosc UI框架和弹弹play API的mpv弹幕扩展插件

> [!WARNING]
> Release1.2.0及Release1.2.0之前的发行版，都由于弹弹play接口使用政策改版，部分功能无法使用。如果发现插件功能异常，比如搜索弹幕总是显示无结果，请拉取或下载主分支最新源代码；或下载[最新发行版](https://github.com/Tony15246/uosc_danmaku/releases/latest)

> [!IMPORTANT]
> mpv 需基于 LuaJIT 或 Lua 5.2 构建，脚本不支持 Lua 5.1

> [!NOTE]
> 已添加对mpv内部 `mp.input`的支持，在uosc不可用时通过键绑定调用此方式渲染菜单
>
> 欲启用此支持mpv最低版本要求：0.39.0

## 项目简介

插件具体效果见演示视频：

<video width="902" src="https://github.com/user-attachments/assets/86717e75-9176-4f1a-88cd-71fa94da0c0e">
</video>

在未安装uosc框架时，调用mpv内部的 `mp.input`进行菜单渲染，具体效果见[此pr](https://github.com/Tony15246/uosc_danmaku/pull/24)

### 主要功能

1. 从弹弹play或自定义服务的API获取剧集及弹幕数据，并根据用户选择的集数加载弹幕
2. 通过点击uosc control bar中的弹幕搜索按钮可以显示搜索菜单供用户选择需要的弹幕
3. 通过点击加入uosc control bar中的弹幕开关控件可以控制弹幕的开关
4. 通过点击加入uosc control bar中的[从源获取弹幕](#从弹幕源向当前弹幕添加新弹幕内容可选)按钮可以通过受支持的网络源或本地文件添加弹幕
5. 通过点击加入uosc control bar中的[弹幕样式](#实时修改弹幕样式可选)按钮可以打开uosc弹幕样式菜单供用户在视频播放时实时修改弹幕样式（注意⚠️：未安装uosc框架时该功能不可用）
6. 通过点击加入uosc control bar中的[弹幕设置](#弹幕设置可选)按钮可以打开多级功能复合菜单，包含了插件目前所有的图形化功能。
7. 通过点击加入uosc control bar中的[弹幕源延迟设置](#弹幕源延迟设置)按钮可以打开弹幕源延迟控制菜单，可以独立控制每个弹幕源的延迟（注意⚠️：未安装uosc框架时该功能不可用）
8. 记忆型全自动弹幕填装，在为某个文件夹下的某一集番剧加载过一次弹幕后，加载过的弹幕会自动关联到该集；之后每次重新播放该文件就会自动加载弹幕，同时该文件对应的文件夹下的所有其他集数的文件都会在播放时自动加载弹幕，无需再重复手动输入番剧名进行搜索（注意⚠️：全自动弹幕填装默认关闭，如需开启请阅读[auto_load配置项说明](#auto_load)）
9. 在没有手动加载过弹幕，没有填装自动弹幕记忆之前，通过文件哈希匹配的方式自动添加弹幕（~仅限本地文件~，现已支持网络视频），对于能够哈希匹配关联的文件不再需要手动搜索关联，实现全自动加载弹幕并添加记忆。该功能随记忆型全自动弹幕填装功能一起开启（哈希匹配自动加载准确率较低，如关联到错误的剧集请手动加载正确的剧集）
10. 通过打开配置项load_more_danmaku可以爬取所有可用弹幕源，获取更多弹幕（注意⚠️：爬取所有可用弹幕源默认关闭，如需开启请阅读[load_more_danmaku配置项说明](#load_more_danmaku)）
11. 自动记忆弹幕开关情况，播放视频时保持上次关闭时的弹幕开关状态
12. 自定义默认播放弹幕样式（具体设置方法详见[自定义弹幕样式](#DanmakuFactory相关配置自定义弹幕样式相关配置)）
13. 在使用如[Play-With-MPV](https://github.com/LuckyPuppy514/Play-With-MPV)或[ff2mpv](https://github.com/woodruffw/ff2mpv)等网络播放手段时，自动加载弹幕（注意⚠️：目前支持自动加载bilibili和巴哈姆特这两个网站的弹幕，具体说明查看[autoload_for_url配置项说明](#autoload_for_url)）
14. 保存当前弹幕到本地（详细功能说明见[save_danmaku配置项说明](#save_danmaku)）
15. 可以合并一定时间段内同时出现的大量重复弹幕（具体设置方法详见[merge_tolerance配置项说明](#merge_tolerance)）
16. 弹幕简体字繁体字转换，解决弹幕简繁混杂问题（具体设置方法详见[chConvert配置项说明](#chConvert)）
17. 自定义插件相关提示的显示位置，可以自由调节距离画面左上角的两个维度的距离（具体设置方法详见[message_x配置项说明](#message_x)和[message_y配置项说明](#message_y)）

无需亲自下载整合弹幕文件资源，无需亲自处理文件格式转换，在mpv播放器中一键加载包含了哔哩哔哩、巴哈姆特等弹幕网站弹幕的弹弹play的动画弹幕。

插件本身支持Linux和Windows平台。项目依赖于[uosc UI框架](https://github.com/tomasklaen/uosc)。欲使用本插件强烈建议为mpv播放器中安装uosc。uosc的安装步骤可以参考其[官方安装教程](https://github.com/tomasklaen/uosc?tab=readme-ov-file#install)。当然，如果使用[MPV_lazy](https://github.com/hooke007/MPV_lazy)等内置了uosc的懒人包则只需安装本插件即可。

另外本插件也使用了DanmakuFactory弹幕格式转换工具。在Windows平台和Linux平台上本插件均调用作者自己编译构建的可执行文件。如果本项目仓库中bin文件夹下提供的可执行文件无法正确运行，请前往[DanmakuFactory项目地址](https://github.com/hihkm/DanmakuFactory)，按照其教程选择或编译兼容自己环境的可执行文件。

字体简繁转换基于OpenCC简繁转换工具。在Windows平台上本插件调用OpenCC官方编译的x86_64版本，在Linux平台上本插件调用基于作者自己Linux系统编译的二进制文件。如果本项目仓库中bin文件夹下提供的可执行文件无法正确运行，请前往[OpenCC项目地址](https://github.com/BYVoid/OpenCC)，按照其教程选择或编译兼容自己环境的可执行文件。

## 安装

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

想要使用本插件，请将本插件完整地[下载](https://github.com/Tony15246/uosc_danmaku/releases)或者克隆到 `scripts`目录下，文件结构如下：

> [!IMPORTANT]
>
> 1. scripts目录下放置本插件的文件夹名称必须为uosc_danmaku，否则必须参照uosc控件配置部分[修改uosc控件](#修改uosc控件可选)
> 2. 记得给bin文件夹下的文件赋予可执行权限

```
~/.config/mpv/scripts 
└── uosc_danmaku
    ├── api.lua
    ├── bin
    │   ├── dandanplay
    │   │   ├── dandanplay
    │   │   └── dandanplay.exe
    │   ├── OpenCC_Linux
    │   │   └── opencc
    │   └── OpenCC_Windows
    │       ├── opencc.dll
    │       ├── opencc.exe
    │       ├── s2t.json
    │       ├── STCharacters.ocd2
    │       ├── STPhrases.ocd2
    │       ├── t2s.json
    │       ├── TSCharacters.ocd2
    │       └── TSPhrases.ocd2
    ├── LICENSE
    ├── main.lua
    ├── md5.lua
    ├── options.lua
    ├── README.md
    └── render.lua
```

### 基本配置

#### uosc控件配置

这一步非常重要，不添加控件，弹幕搜索按钮和弹幕开关就不会显示在进度条上方的控件条中。若没有控件，则只能通过[绑定快捷键](#绑定快捷键可选)调用弹幕搜索和弹幕开关功能

想要添加uosc控件，需要修改mpv配置文件夹下的 `script-opts`中的 `uosc.conf`文件。如果已经安装了uosc，但是 `script-opts`文件夹下没有 `uosc.conf`文件，可以去[uosc项目地址](https://github.com/tomasklaen/uosc)下载官方的 `uosc.conf`文件，并按照后面的配置步骤进行配置。

由于uosc最近才更新了部分接口和控件代码，导致老旧版本的uosc和新版的uosc配置有所不同。如果是下载的最新git版uosc或者一直保持更新的用户按照[最新版uosc的控件配置步骤](#最新版uosc的控件配置步骤)配置即可。如果不确定自己的uosc版本，或者在使用诸如[MPV_lazy](https://github.com/hooke007/MPV_lazy)等由第三方管理uosc版本的用户，可以使用兼容新版和旧版uosc的[旧版uosc控件配置步骤](#旧版uosc控件配置步骤)

##### 最新版uosc的控件配置步骤

找到 `uosc.conf`文件中的 `controls`配置项，uosc官方默认的配置可能如下：

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

在 `controls`控件配置项中添加 `button:danmaku`的弹幕搜索按钮和 `cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关`的弹幕开关。放置的位置就是实际会在在进度条上方的控件条中显示的位置，可以放在自己喜欢的位置。我个人把这两个控件放在了 `<stream>stream-quality`画质选择控件后边。添加完控件的配置大概如下：

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,button:danmaku,cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

##### 旧版uosc控件配置步骤

找到 `uosc.conf`文件中的 `controls`配置项，uosc官方默认的配置可能如下：

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

在 `controls`控件配置项中添加 `command:search:script-message open_search_danmaku_menu?搜索弹幕`的弹幕搜索按钮和 `cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关`的弹幕开关。放置的位置就是实际会在在进度条上方的控件条中显示的位置，可以放在自己喜欢的位置。我个人把这两个控件放在了 `<stream>stream-quality`画质选择控件后边。添加完控件的配置大概如下：

```
controls=menu,gap,subtitles,<has_many_audio>audio,<has_many_video>video,<has_many_edition>editions,<stream>stream-quality,command:search:script-message open_search_danmaku_menu?搜索弹幕,cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关,gap,space,speed,space,shuffle,loop-playlist,loop-file,gap,prev,items,next,gap,fullscreen
```

##### 修改uosc控件（可选）

如果出于重名等各种原因，无法将本插件所放置的文件夹命名为 `uosc_danmaku`的话，需要修改 `cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关`的弹幕开关配置中的 `uosc_danmaku`为放置本插件的文件夹的名称。假如将本插件放置在 `my_folder`文件夹下，那么弹幕开关配置就要修改为 `cycle:toggle_on:show_danmaku@my_folder:on=toggle_on/off=toggle_off?弹幕开关`

#### 绑定快捷键（可选）

对于坚定的键盘爱好者和不使用鼠标主义者，可以选择通过快捷键调用弹幕搜索和弹幕开关功能

快捷键已经进行了默认绑定。默认情况下弹幕搜索功能绑定“Ctrl+d”；弹幕开关功能绑定“j”

弹幕搜索功能绑定的脚本消息为 `open_search_danmaku_menu`，弹幕开关功能绑定的脚本消息为 `show_danmaku_keyboard`

如需配置快捷键，只需在 `input.conf`中添加如下行即可，快捷键可以改为自己喜欢的按键组合。

```
Ctrl+d script-message open_search_danmaku_menu
j script-message show_danmaku_keyboard
```

> 根据[此issue中的需求](https://github.com/Tony15246/uosc_danmaku/issues/6)，添加了通过uosc_danmaku.conf绑定快捷键的功能。（请注意，最高优先级仍然是input.conf中设置的快捷键）
> 想要在uosc_danmaku.conf中自定义快捷键，可以像下面这样更改默认快捷键。

```
open_search_danmaku_menu_key=Ctrl+i
show_danmaku_keyboard_key=i
```

#### 从弹幕源向当前弹幕添加新弹幕内容（可选）

从弹幕源添加弹幕。在已经在播放弹幕的情况下会将添加的弹幕追加到现有弹幕中。

~目前尚未解决弹幕去重等问题~

弹幕去重问题已解决，可参考[此issue](https://github.com/Tony15246/uosc_danmaku/issues/31)

可添加的弹幕源如哔哩哔哩上任意视频通过video路径加BV号，或者巴哈姆特上的视频地址等。比如说以下地址均可作为有效弹幕源被添加：

```
https://www.bilibili.com/video/BV1kx411o7Yo
https://ani.gamer.com.tw/animeVideo.php?sn=36843
```

此功能通过调用弹弹Play的extcomment接口实现获取第三方弹幕站（如A/B/C站）上指定网址对应的弹幕。想要启用此功能，需要参照[uosc控件配置](#uosc控件配置)，根据uosc版本添加 `button:danmaku_source`或 `command:add_box:script-message open_add_source_menu?从源添加弹幕`到 `uosc.conf`的controls配置项中。

想要通过快捷键使用此功能，请添加类似下面的配置到 `input.conf`中。从源添加弹幕功能对应的脚本消息为 `open_add_source_menu`。

```
key script-message open_add_source_menu
```

现已添加了对加载本地弹幕文件的支持，输入本地弹幕文件的绝对路径即可使用本插件加载弹幕。加载出来的弹幕样式同在本插件中设置的弹幕样式。支持的文件格式有ass文件和xml文件。具体可参见[此issue](https://github.com/Tony15246/uosc_danmaku/issues/26)

```
#Linux下示例
/home/tony/Downloads/example.xml
#Windows下示例
C:\Users\Tony\Downloads\example.xml
```

现已更新增强了此菜单。现在在该菜单内可以可视化地控制所有弹幕源，删除或者屏蔽任何不想要的弹幕源。对于自己手动添加的弹幕源，可以进行移除。对于来自弹弹play的弹幕源，无法进行移除，但是可以进行屏蔽，将不会再从屏蔽过的弹幕源获取弹幕。当然，也可以解除对来自弹弹play的弹幕源的屏蔽。另外需要注意在菜单内对于弹幕源的可视化操作都需要下次打开视频，或者重新用弹幕搜索功能加载一次弹幕才会生效。

#### 弹幕源延迟设置

可以独立控制每个弹幕源的延迟，延迟支持两种输入模式。第一种模式为输入数字（最高可精确到小数点后两位），单位为秒；第二种输入模式为输入形如 `14m15s`格式的字符串，代表延迟的分钟数和秒数。

想要启用此功能，需要参照[uosc控件配置](#uosc控件配置)，根据uosc版本添加 `button:danmaku_delay`或 `command:more_time:script-message open_source_delay_menu?弹幕源延迟设置`到 `uosc.conf`的controls配置项中。

想要通过快捷键使用此功能，请添加类似下面的配置到 `input.conf`中。弹幕源延迟设置功能对应的脚本消息为 `open_source_delay_menu`。

```
key script-message open_source_delay_menu
```

#### 实时修改弹幕样式（可选）

依赖于[uosc UI框架](https://github.com/tomasklaen/uosc)实现**弹幕样式实时修改**，将打开弹幕样式修改图形化菜单供用户手动修改，该功能目前仅依靠 uosc 实现（uosc不可用时无法使用此功能，并默认使用[自定义弹幕样式](#DanmakuFactory相关配置自定义弹幕样式相关配置)里的样式配置）。想要启用此功能，需要参照[uosc控件配置](#uosc控件配置)，根据uosc版本添加 `button:danmaku_styles`或 `command:palette:script-message open_setup_danmaku_menu?弹幕样式`到 `uosc.conf`的controls配置项中。

想要通过快捷键使用此功能，请添加类似下面的配置到 `input.conf`中。实时修改弹幕样式功能对应的脚本消息为 `open_setup_danmaku_menu`。

```
key script-message open_setup_danmaku_menu
```

#### 弹幕设置（可选）

打开多级功能复合菜单，包含了插件目前所有的图形化功能。想要启用此功能，需要参照[uosc控件配置](#uosc控件配置)，根据uosc版本添加 `button:danmaku_menu`或 `command:grid_view:script-message open_add_total_menu?弹幕设置`到 `uosc.conf`的controls配置项中。

想要通过快捷键使用此功能，请添加类似下面的配置到 `input.conf`中。从源添加弹幕功能对应的脚本消息为 `open_add_total_menu`。

```
key script-message open_add_total_menu
```

#### 设置弹幕延迟（可选）

可以通过快捷键绑定以下命令来调整弹幕延迟，单位：秒。可以为负数

```
key script-message danmaku-delay <seconds>
```

> 当前弹幕延迟的值可以从 `user-data/uosc_danmaku/danmaku-delay`属性中获取到，具体用法可以参考[此issue](https://github.com/Tony15246/uosc_danmaku/issues/77)

#### 清空当前视频关联的弹幕源（可选）

可以清空当前视频中，用户通过[从源获取弹幕](#从弹幕源向当前弹幕添加新弹幕内容可选)菜单手动添加的所有弹幕源（注意该功能不会删除来源于弹幕服务器的弹幕，此类弹幕只能屏蔽或者手动重新匹配新弹幕库）。清空过弹幕源之后，下次播放该视频，就不会再加载之前手动添加过的弹幕源，可以重新添加弹幕源。

想要通过快捷键使用此功能，请添加类似下面的配置到 `input.conf`中。从源添加弹幕功能对应的脚本消息为 `clear-source`。

```
key script-message clear-source
```

#### 保存当前视频弹幕（可选）

在视频播放时手动保存弹幕至视频所在文件夹，保存格式为 `xml`（注：此功能将保存为视频同名弹幕，若视频文件夹下存在同名文件将不会执行该功能）

想要通过快捷键使用此功能，请添加类似下面的配置到 `input.conf`中。从源添加弹幕功能对应的脚本消息为 `immediately_save_danmaku`。

```
key script-message immediately_save_danmaku
```

## 配置选项（可选）

### api_server

#### 功能说明

允许自定义弹幕 API 的服务地址

> [!NOTE]
>
> 请确保自定义服务的 API 与弹弹play 的兼容，已知兼容：[anoraker/abetsy](https://hub.docker.com/repository/docker/anoraker/abetsy)

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并自定义如下内容：

```
api_server=https://api.dandanplay.net
```

### load_more_danmaku

#### 功能说明

由于弹弹Play默认对于弹幕较多的番剧加载并且整合弹幕的上限大约每集7000条，而这7000条弹幕也不是均匀分配，例如有时弹幕基本只来自于哔哩哔哩，有时弹幕又只来自于巴哈姆特。这样的话弹幕观看体验就和直接在哔哩哔哩或者巴哈姆特观看没有区别了，失去了弹弹Play整合全平台弹幕的优势。

因此，本人添加了配置选项 `load_more_danmaku`，用来将从弹弹Play获取弹幕的逻辑更改为逐一搜索所有弹幕源下的全部弹幕，并由本脚本整合加载。开启此选项可以获取到所有可用弹幕源下的所有弹幕。但是对于一些热门番剧来说，弹幕数量可能破万，如果接受不了屏幕上弹幕太多，请不要开启此选项。（嘛，不过本人看视频从来只会觉得弹幕多多益善）

#### 使用方法

想要开启此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并添加如下内容：

```
load_more_danmaku=yes
```

### auto_load

#### 功能说明

该选项控制是否开启全自动弹幕填装功能。该功能会在为某个文件夹下的某一集番剧加载过一次弹幕后，把加载过的弹幕会自动关联到该集。之后每次重新播放该文件就会自动加载对应的弹幕，同时该文件对应的文件夹下的所有其他集数的文件都会在播放时自动加载弹幕。

举个例子，比如说有一个文件夹结构如下

```
败犬女主太多了
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_01WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_02WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_03WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_04WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_05WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_06WebRipHEVC_AACCHS_JP.mp4
├── KitaujiSub_Make_Heroine_ga_Oosugiru!_07v2WebRipHEVC_AACCHS_JP.mp4
└── KitaujiSub_Make_Heroine_ga_Oosugiru!_08WebRipHEVC_AACCHS_JP.mp4
```

只要在播放第一集 `KitaujiSub_Make_Heroine_ga_Oosugiru!_01WebRipHEVC_AACCHS_JP.mp4`的时候手动搜索并且加载过一次弹幕，那么打开第二集时就会直接自动加载第二集的弹幕，打开第三集时就会直接加载第三集的弹幕，以此类推，不用再手动搜索

#### 使用方法

想要开启此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并添加如下内容：

```
auto_load=yes
```

注意⚠️： 一个文件夹下有且仅有一同部番剧的若干视频文件才会生效。下面这种情况下，如果手动搜索并且加载过一次《少女歌剧》第一集的弹幕，《哭泣少女乐队》第二集必须重新手动识别，但这样会破坏《少女歌剧》的弹幕记录

```
少女歌剧
├── 少女歌剧1.mp4
├── 少女歌剧2.mp4
├── 少女歌剧3.mp4
├── 少女歌剧4.mp4
└── 哭泣少女乐队2.mp4
```

### autoload_local_danmaku

#### 功能说明

自动加载播放文件同目录下同名的 xml 格式的弹幕文件

#### 使用方法

想要开启此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并添加如下内容：

```
autoload_local_danmaku=yes
```

### autoload_for_url

#### 功能说明

开启此选项后，会为可能支持的 url 视频文件实现弹幕关联记忆和继承，配合播放列表食用效果最佳。目前兼容在使用[embyToLocalPlayer](https://github.com/kjtsune/embyToLocalPlayer)、[mpv-torrserver](https://github.com/dyphire/mpv-config/blob/master/scripts/mpv-torrserver.lua)、[tsukimi](https://github.com/tsukinaha/tsukimi)等场景时进行弹幕关联记忆和继承。

目前的具体支持情况和实现效果可以参考[此pr](https://github.com/Tony15246/uosc_danmaku/pull/16)

另外，开启此选项后还会在网络播放bilibili以及巴哈姆特的视频时自动加载对应视频的弹幕，可配合[Play-With-MPV](https://github.com/LuckyPuppy514/Play-With-MPV)或[ff2mpv](https://github.com/woodruffw/ff2mpv)等网络播放手段使用。（播放巴哈姆特的视频时弹幕自动加载如果失败，请检查[proxy](#proxy)选项配置是否正确）

> [!NOTE]
>
> 实验性功能，尚不完善

#### 使用方法

想要开启此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并添加如下内容：

```
autoload_for_url=yes
```

### add_from_source

> [!NOTE]
>
> 该可选配置项在Release v1.2.0之后已废除。现在通过 `从弹幕源向当前弹幕添加新弹幕内容`功能关联过的弹幕源被记录，并且下次播放同一个视频的时候自动关联并加载所有添加过的弹幕源，这样的行为已经成为了插件的默认行为，不需要再通过 `add_from_source`来开启。在[从源获取弹幕](#从弹幕源向当前弹幕添加新弹幕内容可选)菜单中可以可视化地管理所有添加过的弹幕源。

#### 功能说明

开启此选项后，通过 `从弹幕源向当前弹幕添加新弹幕内容`功能关联过的弹幕源会被记录，并且下次播放同一个视频的时候会自动关联并加载添加过的弹幕源。

#### 使用方法

想要开启此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并添加如下内容：

```
add_from_source=yes
```

### save_danmaku

#### 功能说明

当文件关闭时自动保存弹幕文件（xml格式）至视频同目录，保存的弹幕文件名与对应的视频文件名相同。配合[autoload_local_danmaku选项](#autoload_local_danmaku)可以实现弹幕自动保存到本地并且下次播放时自动加载本地保存的弹幕。此功能默认禁用。

> [!NOTE]
>
> 当开启[autoload_local_danmaku选项](#autoload_local_danmaku)时，会自动加载播放文件同目录下同名的 xml 格式的弹幕文件，优先级高于一切其他自动加载弹幕功能。如果不希望每次播放都加载之前保存的本地弹幕，则请关闭[autoload_local_danmaku选项](#autoload_local_danmaku)；或者在保存完弹幕之后转移弹幕文件至其他路径并关闭 `save_danmaku`选项。
>
> `save_danmaku`选项的打开和关闭可以运行时实时更新。在 `input.conf`中添加如下内容，可通过快捷键实时控制 `save_danmaku`选项的打开和关闭
>
> ```
> key cycle-values script-opts uosc_danmaku-save_danmaku=yes uosc_danmaku-save_danmaku=no
> ```

#### 使用方法

想要启用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并指定如下内容：

```
save_danmaku=yes
```

### user_agent

#### 功能说明

自定义 `curl`发送网络请求时使用的 User Agent，默认值是 `mpv_danmaku/1.0`

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并自定义如下内容（不可为空）：

> [!NOTE]
>
> User-Agent格式必须符合弹弹play的标准，否则无法成功请求。具体格式要求见[弹弹play官方文档](https://github.com/kaedei/dandanplay-libraryindex/blob/master/api/OpenPlatform.md#5user-agent)
>
> 若想提高URL播放的哈希匹配成功率，可以将此项设为 `mpv`或浏览器的User-Agent

```
user_agent=mpv_danmaku/1.0
```

### proxy

#### 功能说明

自定义 `curl`发送网络请求时使用的代理，默认禁用

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并自定义如下内容：

```
proxy=127.0.0.1:7890
```

### vf_fps

#### 功能说明

指定是否使用 fps 视频滤镜 `@danmaku:fps=fps=60/1.001`，可大幅提升弹幕平滑度。默认禁用

注意该视频滤镜的性能开销较大，需在确保设备性能足够的前提下开启

启用选项后仅在视频帧率小于 60 及显示器刷新率大于等于 60 时生效

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并指定如下内容：

```
vf_fps=yes
```

### fps

#### 功能说明

指定要使用的 fps 滤镜参数，例如如果设置fps为 `60/1.001`，则实际生效的视频滤镜参数为 `@danmaku:fps=fps=60/1.001`

使用这个选项，可以根据自己显示器的刷新率调整要使用的视频滤镜参数

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并指定如下内容：

```
fps=60/1.001
```

### transparency

#### 功能说明

自定义弹幕的透明度，0（不透明）到255（完全透明）。默认值：48

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并自定义如下内容：

```
transparency=48
```

### merge_tolerance

#### 功能说明

指定合并重复弹幕的时间间隔的容差值，单位为秒。默认值: -1，表示禁用

当值设为0时会合并同一时间相同内容的弹幕，值大于0时会合并指定秒数误差内的相同内容的弹幕

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并自定义如下内容：

```
merge_tolerance=1
```

### chConvert

#### 功能说明

中文简繁转换。0-不转换，1-转换为简体，2-转换为繁体。默认值: 0，不转换简繁字体，按照弹幕源原本字体显示

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并自定义如下内容：

```
chConvert=0
```

### DanmakuFactory_Path

#### 功能说明

指定 DanmakuFactory 程序的路径，支持绝对路径和相对路径
不特殊指定或者留空（默认值）会在脚本同目录的 bin 中查找，调用本人构建好的 DanmakuFactory 可执行文件
示例：`DanmakuFactory_Path=DanmakuFactory` 会在环境变量 PATH 中或 mpv 程序旁查找该程序

#### 使用示例

想要配置此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并添加类似如下内容：

> [!IMPORTANT]
> 不要直接复制这里的配置，这只是一个示例，路径要写成真实存在的路径。此选项可以不配置，脚本会默认选择环境变量或bin文件夹中的可执行文件。

```
DanmakuFactory_Path=/path/to/your/DanmakuFactory
```

### OpenCC_Path

#### 功能说明

指定 OpenCC 程序的路径，支持绝对路径和相对路径
不特殊指定或者留空（默认值）会在脚本同目录的 bin 中查找，调用本人构建好的 OpenCC 可执行文件
示例：`OpenCC_Path=opencc` 会在环境变量 PATH 中或 mpv 程序旁查找该程序

#### 使用示例

想要配置此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并添加类似如下内容：

> [!IMPORTANT]
> 不要直接复制这里的配置，这只是一个示例，路径要写成真实存在的路径。此选项可以不配置，脚本会默认选择环境变量或bin文件夹中的可执行文件。

```
OpenCC_Path=/path/to/your/opencc
```

### history_path

#### 功能说明

指定弹幕关联历史记录文件的路径，支持绝对路径和相对路径。默认值是 `~~/danmaku-history.json`也就是mpv配置文件夹的根目录下

#### 使用示例

想要配置此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并添加类似如下内容：

> [!IMPORTANT]
> 不要直接复制这里的配置，这只是一个示例，路径要写成真实存在的路径。此选项可以不配置，脚本会默认放在mpv配置文件夹的根目录下。

```
history_path=/path/to/your/danmaku-history.json
```

### message_x

#### 功能说明

自定义插件相关提示的显示位置，距离屏幕左上角的x轴的距离

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并自定义如下内容：

```
message_x=30
```

### message_y

#### 功能说明

自定义插件相关提示的显示位置，距离屏幕左上角的y轴的距离

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并自定义如下内容：

```
message_y=30
```

### title_replace

自定义标题解析中的额外替换规则，内容格式为 JSON 字符串，替换模式为 lua 的 string.gsub 函数

注意⚠️：由于 mpv 的 lua 版本限制，自定义规则只支持形如 %n 的捕获组写法，即示例用法，不支持直接替换字符的写法

用法示例：

```
title_replace=[{"rules":[{ "^〔(.-)〕": "%1"},{ "^.*《(.-)》": "%1" }]}]
```

### DanmakuFactory相关配置（自定义弹幕样式相关配置）

默认配置如下，可根据需求更改并自定义弹幕样式

想要配置此选项，请在mpv配置文件夹下的 `script-opts`中创建 `uosc_danmaku.conf`文件并添加类似如下内容：

```
#速度
scrolltime=15
#字体(名称两边不需要使用引号""括住)
fontname=sans-serif
#大小 
fontsize=50
#是否严格保持指定的字号大小，（true false）
#这会破坏特效弹幕的显示，建议仅当弹幕显示重叠时启用
font_size_strict=false
#阴影
shadow=0
#粗体（true false）
bold=true
#弹幕密度 整数(>=-1) -1：表示不重叠 0：表示无限制 其他表示限定条数
density=0.0
#全部弹幕的显示范围(0.0-1.0)
displayarea=0.85
#描边 0-4
outline=1
#指定不会显示在屏幕上的弹幕类型。使用“-”连接类型名称，例如“L2R-TOP-BOTTOM”。可用的类型包括：L2R,R2L,TOP,BOTTOM,SPECIAL,COLOR,REPEAT
blockmode=REPEAT
#指定弹幕屏蔽词文件路径(black.txt)，支持绝对路径和相对路径。文件内容以换行分隔
blacklist_path=
```

## 常见问题

### 我在Windows平台上使用此插件，总是会显示“未找到弹幕文件”/搜索弹幕总是无结果/弹幕无法加载

可能是Windows系统的病毒威胁与保护误查杀了本插件使用的可执行程序，把可执行程序当成了病毒。windows平台上，插件运行必不可少的可执行程序有 `bin\DanmakuFactory`文件夹下的DanmakuFactory.exe，和 `bin\dandanplay`文件夹下的 `dandanplay.exe`。请检查这些程序是否已经被系统自动删除，如果已经被删除，找到下图中的界面还原可执行程序并允许此应用

<img width="902" alt="image_2024-10-06_11-50-12" src="https://github.com/user-attachments/assets/ebcc1a37-0041-42ce-8afe-0e9c2899dd29">

### 简繁转换功能无法生效

检查mpv及其本插件是否安装在了含中文字符的文件夹路径下。简繁转换功能所依赖的OpenCC第三方工具在非英文路径名下无法正常工作。想了解更多可以参考[此discussion](https://github.com/Tony15246/uosc_danmaku/discussions/92)

## 特别感谢

感谢以下项目为本项目提供了实现参考或者外部依赖

- 弹幕api：[弹弹play](https://github.com/kaedei/dandanplay-libraryindex/blob/master/api/OpenPlatform.md)
- 菜单api：[uosc](https://github.com/tomasklaen/uosc)
- 弹幕格式转换：[DanmakuFactory](https://github.com/hihkm/DanmakuFactory)
- 简繁转换：[OpenCC](https://github.com/BYVoid/OpenCC)
- lua原生md5计算实现：https://github.com/rkscv/danmaku
- b站在线播放弹幕获取实现参考：[MPV-Play-BiliBili-Comments](https://github.com/itKelis/MPV-Play-BiliBili-Comments)
- 巴哈姆特在线播放弹幕获取实现参考：[MPV-Play-BAHA-Comments](https://github.com/s594569321/MPV-Play-BAHA-Comments)
- 向dandanplay开放平台发送请求时附加身份验证信息，避免应用凭证公开: https://github.com/zhongfly/dandanplay
