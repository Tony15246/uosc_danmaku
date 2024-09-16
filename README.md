# uosc_danmaku
在MPV播放器中加载弹弹play弹幕，基于 uosc UI框架和弹弹play API的mpv弹幕扩展插件

## 项目简介

插件具体效果见演示视频：

https://github.com/user-attachments/assets/86717e75-9176-4f1a-88cd-71fa94da0c0e

### 主要功能
1. 从弹弹play的API获取剧集及弹幕数据，并根据用户选择的集数加载弹幕
2. 通过点击uosc control bar中的弹幕搜索按钮可以显示搜索菜单供用户选择需要的弹幕
3. 通过点击加入uosc control bar中的弹幕开关控件可以控制弹幕的开关
4. 记忆型全自动弹幕填装，在为某个文件夹下的某一集番剧加载过一次弹幕后，加载过的弹幕会自动关联到该集；之后每次重新播放该文件就会自动加载弹幕，同时该文件对应的文件夹下的所有其他集数的文件都会在播放时自动加载弹幕，无需再重复手动输入番剧名进行搜索（注意⚠️：全自动弹幕填装默认关闭，如需开启请阅读[auto_load配置项说明](#auto_load)）

无需亲自下载整合弹幕文件资源，无需亲自处理文件格式转换，在mpv播放器中一键加载包含了哔哩哔哩、巴哈姆特等弹幕网站弹幕的弹弹play的动画弹幕。

插件本身支持Linux和Windows平台。项目依赖于[uosc UI框架](https://github.com/tomasklaen/uosc)。欲使用本插件必须在mpv播放器中安装有uosc。uosc的安装步骤可以参考其[官方安装教程](https://github.com/tomasklaen/uosc?tab=readme-ov-file#install)。当然，如果使用[MPV_lazy](https://github.com/hooke007/MPV_lazy)等内置了uosc的懒人包则只需安装本插件即可。

另外本插件也使用了DanmakuFactory弹幕格式转换工具。在Windows平台上本插件调用DanmakuFactory官方release版的DanmakuFactory.exe文件，在Linux平台上本插件调用基于作者自己Linux系统编译的二进制文件。如果本项目仓库中bin文件夹下提供的可执行文件无法正确运行，请前往[DanmakuFactory项目地址](https://github.com/hihkm/DanmakuFactory)，按照其教程选择或编译兼容自己环境的可执行文件。

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

想要使用本插件，请将本插件完整地[下载](https://github.com/Tony15246/uosc_danmaku/releases)或者克隆到`scripts`目录下，文件结构如下：

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
### 基本配置

#### uosc控件配置

这一步非常重要，不添加控件，弹幕搜索按钮和弹幕开关就不会显示在进度条上方的控件条中。若没有控件，则只能通过[绑定快捷键](#绑定快捷键可选)调用弹幕搜索和弹幕开关功能

想要添加uosc控件，需要修改mpv配置文件夹下的`script-opts`中的`uosc.conf`文件。如果已经安装了uosc，但是`script-opts`文件夹下没有`uosc.conf`文件，可以去[uosc项目地址](https://github.com/tomasklaen/uosc)下载官方的`uosc.conf`文件，并按照后面的配置步骤进行配置。

由于uosc最近才更新了部分接口和控件代码，导致老旧版本的uosc和新版的uosc配置有所不同。如果是下载的最新git版uosc或者一直保持更新的用户按照[最新版uosc的控件配置步骤](#最新版uosc的控件配置步骤)配置即可。如果不确定自己的uosc版本，或者在使用诸如[MPV_lazy](https://github.com/hooke007/MPV_lazy)等由第三方管理uosc版本的用户，可以使用兼容新版和旧版uosc的[旧版uosc控件配置步骤](#旧版uosc控件配置步骤)

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

如果出于重名等各种原因，无法将本插件所放置的文件夹命名为`uosc_danmaku`的话，需要修改`cycle:toggle_on:show_danmaku@uosc_danmaku:on=toggle_on/off=toggle_off?弹幕开关`的弹幕开关配置中的`uosc_danmaku`为放置本插件的文件夹的名称。假如将本插件放置在`my_folder`文件夹下，那么弹幕开关配置就要修改为`cycle:toggle_on:show_danmaku@my_folder:on=toggle_on/off=toggle_off?弹幕开关`

#### 绑定快捷键（可选）

对于坚定的键盘爱好者和不使用鼠标主义者，可以选择通过快捷键调用弹幕搜索和弹幕开关功能

弹幕搜索功能绑定的脚本消息为`open_search_danmaku_menu`，弹幕开关功能绑定的脚本消息为`show_danmaku_keyboard`

如需配置快捷键，只需在`input.conf`中添加如下行即可，快捷键可以改为自己喜欢的按键组合。

```
Ctrl+d script-message open_search_danmaku_menu
j script-message show_danmaku_keyboard
```

#### 从弹幕源向当前弹幕添加新弹幕内容（可选）

此功能尚为实验性功能，目前尚未解决弹幕去重等问题。

可添加的弹幕源如哔哩哔哩上任意视频通过video路径加BV号，或者巴哈姆特上的视频地址等。比如说以下地址均可作为有效弹幕源被添加：

```
https://www.bilibili.com/video/BV1kx411o7Yo
https://ani.gamer.com.tw/animeVideo.php?sn=36843
```

此功能通过调用弹弹Play的extcomment接口实现获取第三方弹幕站（如A/B/C站）上指定网址对应的弹幕。想要启用此功能，需要参照[uosc控件配置](#uosc控件配置)，根据uosc版本添加`button:danmaku_source`或`command:add_box:script-message open_add_source_menu?从源添加弹幕`到`uosc.conf`的controls配置项中。

想要通过快捷键使用此功能，请添加类似下面的配置到`input.conf`中。从源添加弹幕功能对应的脚本消息为`open_add_source_menu`。

```
Ctrl+j script-message open_add_source_menu
```

## 配置选项（可选）

### load_more_danmaku

#### 功能说明

由于弹弹Play默认对于弹幕较多的番剧加载并且整合弹幕的上限大约每集7000条，而这7000条弹幕也不是均匀分配，例如有时弹幕基本只来自于哔哩哔哩，有时弹幕又只来自于巴哈姆特。这样的话弹幕观看体验就和直接在哔哩哔哩或者巴哈姆特观看没有区别了，失去了弹弹Play整合全平台弹幕的优势。

因此，本人添加了配置选项`load_more_danmaku`，用来将从弹弹Play获取弹幕的逻辑更改为逐一搜索所有弹幕源下的全部弹幕，并由本脚本整合加载。开启此选项可以获取到所有可用弹幕源下的所有弹幕。但是对于一些热门番剧来说，弹幕数量可能破万，如果接受不了屏幕上弹幕太多，请不要开启此选项。（嘛，不过本人看视频从来只会觉得弹幕多多益善）

#### 使用方法

想要开启此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并添加如下内容：

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

只要在播放第一集`KitaujiSub_Make_Heroine_ga_Oosugiru!_01WebRipHEVC_AACCHS_JP.mp4`的时候手动搜索并且加载过一次弹幕，那么打开第二集时就会直接自动加载第二集的弹幕，打开第三集时就会直接加载第三集的弹幕，以此类推，不用再手动搜索

#### 使用方法

想要开启此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并添加如下内容：

```
auto_load=yes
```

注意⚠️以下两点，否则此功能无法正常工作：

1. 一个文件夹下有且仅有一同部番剧的若干视频文件才会生效。下面这种情况下，如果手动搜索并且加载过一次《少女歌剧》第一集的弹幕，《哭泣少女乐队》第二集的弹幕会被自动加载成《少女歌剧》第二集的弹幕
```
少女歌剧
├── 少女歌剧1.mp4
├── 少女歌剧2.mp4
├── 少女歌剧3.mp4
├── 少女歌剧4.mp4
└── 哭泣少女乐队2.mp4
```
2. 在番剧的“集数”的阿拉伯数字之前没有出现其他阿拉伯数字才能生效，比如说
```
KitaujiSub_Make_Heroine_ga_Oosugiru!_02WebRipHEVC_AACCHS_JP.mp4 可以正常读取出是第2集
[ANi] 超超超超超喜歡你的 100 個女朋友 - 01 [1080P][Baha][WEB-DL][AAC AVC][CHT] 会被读取成是第100集，这种特殊情况下请重命名文件，确保集数是第一个出现的阿拉伯数字
```

