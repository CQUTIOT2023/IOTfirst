// 导入集合库，提供HashMap等数据结构，用于存储检测到的物体信息
import 'dart:collection';

// 导入UI库并重命名为ui，提供图像处理相关功能
// 用于获取图像尺寸等信息
import 'dart:ui' as ui;

// 导入机器视觉库，提供YOLOv5目标检测功能
// 用于实时识别图像中的物体
import 'package:flutter_vision/flutter_vision.dart';

// 导入自定义的文字转语音服务
// 用于播报检测到的物体信息
import 'package:myeyes/TTS.dart';

// 导入类型化数据支持，用于处理二进制图像数据
// 主要用于图像数据的处理和传输
import 'dart:typed_data';

class MyDetection {
  //-------实例化了一个TTS插件
  static TtsService ttsService = TtsService();

  //储存YOLO识别到的物体  ==紧急==  格式：[方向(中/左/右)名字(string)  ==>  出现次数(int)]
  static Map<String, int> YOLO_Obj0 = HashMap();
  //储存YOLO识别到的物体  ==注意==  格式：[方向(中/左/右)名字(string)  ==>  出现次数(int)]
  static Map<String, int> YOLO_Obj1 = HashMap();

  // 添加静态变量存储最近结果
  static List<dynamic> _lastResults = [];

  // 添加获取结果方法
  static List<dynamic> getLastResults() {
    return _lastResults;
  }

  // 在检测完成后更新结果
  static void updateResults(List<dynamic> results) {
    _lastResults = results;
  }

  static FlutterVision? _vision;
  static bool _isModelLoaded = false;

  // 初始化并加载模型
  static Future<void> initModel() async {
    if (_vision == null) {
      _vision = FlutterVision();
      try {
        await _vision!.loadYoloModel(
            //labels: 'assets/best-fp16.txt',
            //labels: 'assets/best.txt',
            labels: 'assets/yolov5.txt',

            //modelPath: 'assets/best-fp16.tflite',
            //modelPath: 'assets/best.tflite',
            modelPath: 'assets/yolov5.tflite',
            modelVersion: "yolov5",
            quantization: false,
            numThreads: 5,
            useGpu: true);
        _isModelLoaded = true;
      } catch (e) {
        print('模型加载失败: $e');
        ttsService.TTS_speakImpText('模型加载失败');
      }
    }
  }

  //==========================开始推理===========================================
  static Future<void> Det_StartInference(Uint8List imageBytes) async {
    if (!_isModelLoaded) {
      await initModel();
    }

    try {
      List<Map<String, dynamic>> YoloData = await _vision!.yoloOnImage(
          bytesList: imageBytes,
          imageHeight: 416,
          imageWidth: 416,
          iouThreshold: 0.8,
          confThreshold: 0.4,
          classThreshold: 0.7);

      print(YoloData);
      var wide = await getImageWidth(imageBytes);
      Dec_YoloFilter(YoloData, wide);
      updateResults(YoloData);
    } catch (e) {
      print('推理失败: $e');
    }
  }

  //在此进行YOLO算法输出列表的过滤和生效算法
  static void Dec_YoloFilter(List<dynamic> data, int wide) {
    String detectedClass = '';
    List<dynamic> Temp = [];
    //     宽   横坐标   高   纵坐标    置信度
    double w = 0,
        x = 0,
        //h = 0,
        //y = 0,
        confidence = 0;

    //对于每一个被检测到的目标来说：
    for (var element in data) {
      detectedClass = element['tag']; // 获取检测到的物体类别名称
      Temp = element['box']; // 获取物体的边界框信息 [x1, y1, x2, y2, confidence]
      confidence = Temp[4]; // 获取检测的置信度分数
      w = (Temp[2] - Temp[0]) / wide; // 计算目标宽度比例
      x = (Temp[0] / wide) + (w / 2); // 计算目标中心点x坐标比例

      print('x:$x;w:$w');

      // 如果目标不是特别小且置信度高就考虑播报
      if (w > 0.05 && confidence > 0.7) {
        add_Obj_to_Map(x, w, detectedClass);

        YOLO_Map_To_Tts();
      }
    }
  }

  static void YOLO_Map_To_Tts() {
    for (var entry in YOLO_Obj0.entries.toList()) {
      var value = entry.value; // 获取物体的出现次数
      var key = entry.key; // 获取物体的名称
      if (value >= 6) {
        // 紧急物体阈值为6次
        ttsService.TTS_speakImpText('注意$key'); // 播报格式："注意+方向+物体名称"
        //删除已经播报过的目标
        YOLO_Obj0.clear();
      }
    }
    for (var entry in YOLO_Obj1.entries.toList()) {
      var value = entry.value; // 获取物体的出现次数
      var key = entry.key; // 获取物体的名称
      if (value >= 11) {
        // 普通物体阈值为11次
        ttsService.TTS_speakImpText(key); // 播报格式："注意+方向+物体名称"
        //删除已经播报过的目标 减少内存占用
        YOLO_Obj1.clear();
      }
    }
  }

  // 将检测到的物体添加到对应的Map中
  static void add_Obj_to_Map(double x, w, String detectedClass) {
    if (judge_Near_Obj(x, w, detectedClass)) {
      return;
    } else if (judge_Point_Obj(x, detectedClass)) {
      return;
    }
  }

  //------------------------检测到的物体是否大到需要提醒-----------------------------
  static bool judge_Near_Obj(double x, w, String detectedClass) {
    //若目标体积较大（较近）,且在屏幕中间，则存在map里
    if ((w >= 0.55) && (0.33 <= x && x <= 0.67)) {
      // 检查该物体是否已经在Map中
      if (YOLO_Obj0.containsKey('前$detectedClass')) {
        // 已存在则计数加1
        YOLO_Obj0['前$detectedClass'] = (YOLO_Obj0['前$detectedClass'])! + 1;
        return true;
      } else {
        // 不存在则添加并初始化计数为1
        YOLO_Obj0['前$detectedClass'] = 1;
        return true;
      }
    }
    //若目标体积较大（较近）,且在屏幕左侧，则存在map里
    if ((w >= 0.55) && (0 <= x && x < 0.33)) {
      if (YOLO_Obj0.containsKey('左$detectedClass')) {
        YOLO_Obj0['左$detectedClass'] = (YOLO_Obj0['左$detectedClass'])! + 1;
        return true;
      } else {
        YOLO_Obj0['左$detectedClass'] = 1;
        return true;
      }
    }
    //若目标体积较大（较近）,且在屏幕右侧，则存在map里
    if ((w >= 0.55) && (0.67 < x && x <= 1)) {
      if (YOLO_Obj0.containsKey('右$detectedClass')) {
        YOLO_Obj0['右$detectedClass'] = (YOLO_Obj0['右$detectedClass'])! + 1;
        return true;
      } else {
        YOLO_Obj0['右$detectedClass'] = 1;
        return true;
      }
    }
    // 如果物体不满足任何条件，返回false
    return false;
  }

  //------------------------检测到的物体是否需要提醒--------------------------------
  // 判断检测到的物体是否为需要关注的普通物体，并根据位置添加到普通物体Map中
  static bool judge_Point_Obj(double x, String detectedClass) {
    if (0.33 <= x && x <= 0.67) {
      if (YOLO_Obj1.containsKey('前$detectedClass')) {
        YOLO_Obj1['前$detectedClass'] = (YOLO_Obj1['前$detectedClass'])! + 1;
        return true;
      } else {
        YOLO_Obj1['前$detectedClass'] = 1;
        return true;
      }
    }
    if (0 <= x && x < 0.33) {
      if (YOLO_Obj1.containsKey('左$detectedClass')) {
        YOLO_Obj1['左$detectedClass'] = (YOLO_Obj1['左$detectedClass'])! + 1;
        return true;
      } else {
        YOLO_Obj1['左$detectedClass'] = 1;
        return true;
      }
    }
    if (0.67 < x && x <= 1) {
      if (YOLO_Obj1.containsKey('右$detectedClass')) {
        YOLO_Obj1['右$detectedClass'] = (YOLO_Obj1['右$detectedClass'])! + 1;
        return true;
      } else {
        YOLO_Obj1['右$detectedClass'] = 1;
        return true;
      }
    }
    return false;
  }

  // 获取图像宽度的异步方法
  // 参数 imageData: 二进制格式的图像数据
  // 返回值: 图像宽度（像素）
  static Future<int> getImageWidth(Uint8List imageData) async {
    // 步骤1：将二进制数据解码为图像编解码器
    // instantiateImageCodec：创建图像解码器实例
    // 支持常见图像格式如JPEG、PNG等
    ui.Codec codec = await ui.instantiateImageCodec(imageData);
    // 步骤2：获取图像的第一帧
    // getNextFrame：获取图像帧信息
    // 对于静态图像，只有一帧
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    // 步骤3：返回图像宽度
    // frameInfo.image.width：获取图像的实际像素宽度
    // 这个宽度用于后续计算物体的相对位置和大小
    return frameInfo.image.width;
  }

  Future<Uint8List> processImage(Uint8List imageData) async {
    // 实现目标检测逻辑
    // 返回处理后的图片数据
    return imageData;
  }

  // 释放资源
  static void dispose() {
    _vision = null;
    _isModelLoaded = false;
  }
}
