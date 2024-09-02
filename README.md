# uosc_danmaku
基于MPV播放器 uosc UI框架和弹弹play API的动画弹幕扩展mpv插件

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
~编写中~
