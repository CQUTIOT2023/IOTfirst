# Hear the Vision（听见视界）开发文档
这是一套视距双模感知的AI多模态视障辅助系统

## 项目说明
该系统主要用于帮助视力障碍人士,通过语音和无障碍功能的方式,提供视力障碍人士的生活辅助。 其功能包含目标检测识别，激光测距，图像解读，紧急呼叫，天气查询，地图显示、定位、地点搜索与步行路径规划等。

### 开发环境配置
如果你是第一次接触 Flutter 开发，可以参考以下资源：
- [Flutter 入门教程：创建你的第一个应用](https://docs.flutter.dev/get-started/codelab)
- [Flutter 实用示例教程](https://docs.flutter.dev/cookbook)
更多 Flutter 开发相关的帮助，请访问
[Flutter 官方文档](https://docs.flutter.dev/)，那里提供了详细的教程、
示例代码、移动开发指南以及完整的 API 文档。

硬件部分
需要安装有Ubuntu 18 至Ubuntu 24 均可
需要安装配置SDK ，具体SDK参考下面部分
-https://wiki.luckfox.com/zh/Luckfox-Pico/Luckfox-Pico-SDK
由于本项目使用的是在官方SDK基础上进行的二次开发SDK，可以参考下面链接
-https://liefyuan.blog.csdn.net/article/details/133148418
登录开发板推荐使用ADB或者SSH

### 主要功能
-【图传识别】:APP首页可显示摄像头实时图像，并通过预训练yolov5视觉模型进行识别检测。
-【雷达判距】:APP首页可显示雷达距离矩阵信息。
-【智能解读】:可通过蓝牙连接或组件按钮两种方式，触发通义千问视觉模型预设/自定义文本分析图像功能。
-【地图定位】:集成了高德相关功能，支持地图显示、定位信息、地点搜索、步行路径规划。
-【天气预报】:集成了高德天气API，可查询各省市实时天气及未来三日天气。
-【紧急呼叫】:集成了APP内紧急呼叫按钮。
-【语音播报】:以上功能及相关状态通过TTS文字转语音播报告知用户。

### 技术栈
-Flutter 3.24.5
-Dart 3.5.4
-移动端第三方依赖包：（见pubspec.yaml）
-C++
-Python
-OpenCV Mobile
