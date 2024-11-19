# uosc_danmaku
在MPV播放器中加载弹弹play弹幕，基于 uosc UI框架和弹弹play API的mpv弹幕扩展插件

> [!IMPORTANT]
> mpv 需基于 LuaJIT 或 Lua 5.2 构建，脚本不支持 Lua 5.1

> [!NOTE]
> 已添加对mpv内部`mp.input`的支持，在uosc不可用时通过键绑定调用此方式渲染菜单
>
> 欲启用此支持mpv最低版本要求：0.39.0

## 项目简介

插件具体效果见演示视频：

<video width="902" src="https://github.com/user-attachments/assets/86717e75-9176-4f1a-88cd-71fa94da0c0e">
</video>

在未安装uosc框架时，调用mpv内部的`mp.input`进行菜单渲染，具体效果见[此pr](https://github.com/Tony15246/uosc_danmaku/pull/24)

### 主要功能
1. 从弹弹play或自定义服务的API获取剧集及弹幕数据，并根据用户选择的集数加载弹幕
2. 通过点击uosc control bar中的弹幕搜索按钮可以显示搜索菜单供用户选择需要的弹幕
3. 通过点击加入uosc control bar中的弹幕开关控件可以控制弹幕的开关
4. 通过点击加入uosc control bar中的[从源获取弹幕](#从弹幕源向当前弹幕添加新弹幕内容可选)按钮可以通过受支持的网络源或本地文件添加弹幕
5. 记忆型全自动弹幕填装，在为某个文件夹下的某一集番剧加载过一次弹幕后，加载过的弹幕会自动关联到该集；之后每次重新播放该文件就会自动加载弹幕，同时该文件对应的文件夹下的所有其他集数的文件都会在播放时自动加载弹幕，无需再重复手动输入番剧名进行搜索（注意⚠️：全自动弹幕填装默认关闭，如需开启请阅读[auto_load配置项说明](#auto_load)）
6. 在没有手动加载过弹幕，没有填装自动弹幕记忆之前，通过文件哈希匹配的方式自动添加弹幕（~仅限本地文件~，现已支持网络视频），对于能够哈希匹配关联的文件不再需要手动搜索关联，实现全自动加载弹幕并添加记忆。该功能随记忆型全自动弹幕填装功能一起开启（哈希匹配自动加载准确率较低，如关联到错误的剧集请手动加载正确的剧集）
7. 通过打开配置项load_more_danmaku可以爬取所有可用弹幕源，获取更多弹幕（注意⚠️：爬取所有可用弹幕源默认关闭，如需开启请阅读[load_more_danmaku配置项说明](#load_more_danmaku)）
8. 自动记忆弹幕开关情况，播放视频时保持上次关闭时的弹幕开关状态
9. 自定义弹幕样式（具体设置方法详见[自定义弹幕样式](#DanmakuFactory相关配置自定义弹幕样式相关配置)）

无需亲自下载整合弹幕文件资源，无需亲自处理文件格式转换，在mpv播放器中一键加载包含了哔哩哔哩、巴哈姆特等弹幕网站弹幕的弹弹play的动画弹幕。

插件本身支持Linux和Windows平台。项目依赖于[uosc UI框架](https://github.com/tomasklaen/uosc)。欲使用本插件强烈建议为mpv播放器中安装uosc。uosc的安装步骤可以参考其[官方安装教程](https://github.com/tomasklaen/uosc?tab=readme-ov-file#install)。当然，如果使用[MPV_lazy](https://github.com/hooke007/MPV_lazy)等内置了uosc的懒人包则只需安装本插件即可。

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

> [!IMPORTANT]
> 1. scripts目录下放置本插件的文件夹名称必须为uosc_danmaku，否则必须参照uosc控件配置部分[修改uosc控件](#修改uosc控件可选)
> 2. 记得给bin文件夹下的文件赋予可执行权限

```
~/.config/mpv/scripts 
└── uosc_danmaku
    ├── api.lua
    ├── bin
    │   ├── DanmakuFactory
    │   └── DanmakuFactory.exe
    └── main.lua
    └── md5.lua
    └── options.lua
    └── render.lua
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

快捷键已经进行了默认绑定。默认情况下弹幕搜索功能绑定“Ctrl+d”；弹幕开关功能绑定“j”

弹幕搜索功能绑定的脚本消息为`open_search_danmaku_menu`，弹幕开关功能绑定的脚本消息为`show_danmaku_keyboard`

如需配置快捷键，只需在`input.conf`中添加如下行即可，快捷键可以改为自己喜欢的按键组合。

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

#### 设置弹幕延迟（可选）

可以通过快捷键绑定以下命令来调整弹幕延迟，单位：秒。可以为负数

```
key script-message danmaku-delay <seconds>
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

此功能通过调用弹弹Play的extcomment接口实现获取第三方弹幕站（如A/B/C站）上指定网址对应的弹幕。想要启用此功能，需要参照[uosc控件配置](#uosc控件配置)，根据uosc版本添加`button:danmaku_source`或`command:add_box:script-message open_add_source_menu?从源添加弹幕`到`uosc.conf`的controls配置项中。

想要通过快捷键使用此功能，请添加类似下面的配置到`input.conf`中。从源添加弹幕功能对应的脚本消息为`open_add_source_menu`。

```
Ctrl+j script-message open_add_source_menu
```

现已添加了对加载本地弹幕文件的支持，输入本地弹幕文件的绝对路径即可使用本插件加载弹幕。加载出来的弹幕样式同在本插件中设置的弹幕样式。支持的文件格式有ass文件和xml文件。具体可参见[此issue](https://github.com/Tony15246/uosc_danmaku/issues/26)

```
#Linux下示例
/home/tony/Downloads/example.xml
#Windows下示例
C:\Users\Tony\Downloads\example.xml
```

## 配置选项（可选）

### api_server

#### 功能说明

允许自定义弹幕 API 的服务地址

> [!NOTE]
>
> 请确保自定义服务的 API 与弹弹play 的兼容，已知兼容：[anoraker/abetsy](https://hub.docker.com/repository/docker/anoraker/abetsy)

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并自定义如下内容：

```
api_server=https://api.dandanplay.net
```


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

想要开启此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并添加如下内容：

```
autoload_local_danmaku=yes
```

### autoload_for_url

#### 功能说明

为可能支持的 url 视频文件实现弹幕关联记忆和继承，配合播放列表食用效果最佳

目前的具体支持情况和实现效果可以参考[此pr](https://github.com/Tony15246/uosc_danmaku/pull/16)

> [!NOTE]
>
> 实验性功能，尚不完善

#### 使用方法

想要开启此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并添加如下内容：

```
autoload_for_url=yes
```

### user_agent

#### 功能说明

自定义`curl`发送网络请求时使用的 User Agent，默认值是`mpv_danmaku/1.0`

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并自定义如下内容（不可为空）：

> [!NOTE]
>
> User-Agent格式必须符合弹弹play的标准，否则无法成功请求。具体格式要求见[弹弹play官方文档](https://github.com/kaedei/dandanplay-libraryindex/blob/master/api/OpenPlatform.md#5user-agent)
>
> 若想提高URL播放的哈希匹配成功率，可以将此项设为`mpv`或浏览器的User-Agent

```
user_agent=mpv_danmaku/1.0
```

### proxy

#### 功能说明

自定义`curl`发送网络请求时使用的代理，默认禁用

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并自定义如下内容：

```
proxy=127.0.0.1:7890
```

### transparency

#### 功能说明

自定义弹幕的透明度，0（不透明）到255（完全透明）。默认值：48

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并自定义如下内容：

```
transparency=48
```

### merge_tolerance

#### 功能说明

指定合并重复弹幕的时间间隔的容差值，单位为秒。默认值: -1，表示禁用

当值设为0时会合并同一时间相同内容的弹幕，值大于0时会合并指定秒数误差内的相同内容的弹幕

#### 使用方法

想要使用此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并自定义如下内容：

```
merge_tolerance=1
```

### DanmakuFactory_Path

#### 功能说明

指定 DanmakuFactory 程序的路径，支持绝对路径和相对路径
不特殊指定或者留空（默认值）会在脚本同目录的 bin 中查找，调用本人构建好的 DanmakuFactory 可执行文件
示例：`DanmakuFactory_Path=DanmakuFactory` 会在环境变量 PATH 中或 mpv 程序旁查找该程序

#### 使用示例

想要配置此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并添加类似如下内容：


> [!IMPORTANT]
> 不要直接复制这里的配置，这只是一个示例，路径要写成真实存在的路径。此选项可以不配置，脚本会默认选择环境变量或bin文件夹中的可执行文件。

```
DanmakuFactory_Path=/path/to/your/DanmakuFactory
```

### history_path

#### 功能说明

指定弹幕关联历史记录文件的路径，支持绝对路径和相对路径。默认值是`~~/danmaku-history.json`也就是mpv配置文件夹的根目录下

#### 使用示例

想要配置此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并添加类似如下内容：

> [!IMPORTANT]
> 不要直接复制这里的配置，这只是一个示例，路径要写成真实存在的路径。此选项可以不配置，脚本会默认放在mpv配置文件夹的根目录下。

```
history_path=/path/to/your/danmaku-history.json
```

### DanmakuFactory相关配置（自定义弹幕样式相关配置）

默认配置如下，可根据需求更改并自定义弹幕样式

想要配置此选项，请在mpv配置文件夹下的`script-opts`中创建`uosc_danmaku.conf`文件并添加类似如下内容：

```
#速度
scrolltime=15
#字体
fontname=sans-serif
#大小 
fontsize=50
#阴影
shadow=0
#粗体 true false
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

### 我在Windows平台上使用此插件，总是会显示“未找到弹幕文件”

可能是Windows系统的病毒威胁与保护误查杀了本插件使用的DanmakuFactory.exe，把DanmakuFactory.exe当成了病毒。找到下图中的界面还原DanmakuFactory.exe并允许此应用

<img width="902" alt="image_2024-10-06_11-50-12" src="https://github.com/user-attachments/assets/ebcc1a37-0041-42ce-8afe-0e9c2899dd29">
