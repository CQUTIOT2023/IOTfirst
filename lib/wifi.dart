// 导入IO操作支持，提供Socket网络通信功能
import 'dart:io';

// 导入Flutter基础库，提供如compute等用于处理异步计算的核心功能
import 'package:flutter/foundation.dart';

// 导入自定义的图像检测模块，用于处理接收到的图像数据
import 'Detection.dart';

// 导入异步编程支持，提供Future、Stream等异步操作功能
import 'dart:async';

// 导入自定义的文字转语音服务，用于语音提示
import 'package:myeyes/TTS.dart';

// 导入OpenCV图像处理库
import 'package:opencv_dart/opencv_dart.dart';

import 'dart:collection'; // 添加这一行

/// WiFi客户端类
/// 负责与眼镜端建立Socket连接并处理图像数据
class WiFiClient {
  // 实例化TTS服务，用于语音播报
  TtsService tts = TtsService();

  // 实例化目标检测服务
  final MyDetection detection = MyDetection();

  // 存储当前接收到的图像数据
  Uint8List currentImageData = Uint8List(0);

  // 存储经过OpenCV处理后的图像数据
  Uint8List processedImageData = Uint8List(0);

  // 预期接收的图像大小（字节数）
  int expectedImageSize = 0;

  // 标记是否正在接收图像数据
  bool isReceivingImage = false;

  // 标记是否正在处理图像
  bool isProcessingImage = false;

  // Socket连接的目标IP地址
  String ip;

  // Socket连接的目标端口
  int port;

  // 连接状态标志
  bool connect_state = false;

  // Socket连接实例
  Socket? socket;

  // UI刷新回调函数
  Function? refreash;

  // 存储日志消息的列表
  List<String> logMessages = [];

  // 添加图像显示控制器
  final StreamController<Uint8List> imageStreamController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get imageStream => imageStreamController.stream;

  // 添加超时控制
  final Duration _imageTimeout = const Duration(seconds: 1);
  DateTime? _lastImageUpdate;

  // 添加缓冲区大小控制
  static const int BUFFER_SIZE = 65536; // 64KB 缓冲区
  final Queue<Uint8List> _dataBuffer = Queue<Uint8List>();
  bool _isProcessing = false;

  // 构造函数，初始化IP和端口
  WiFiClient(this.ip, this.port);

  /// 建立Socket连接并开始通信
  Future<void> connectAndCommunicate() async {
    try {
      socket = await Socket.connect(ip, port);
      socket!.setOption(SocketOption.tcpNoDelay, true); // 禁用Nagle算法
      connect_state = true;
      print('Connected to server');

      // 启动图像监控机制
      _startImageMonitor();

      socket!.listen(
        (data) async {
          await handleIncomingData(data);
        },
        onError: (error) {
          print('Error: $error');
          _resetState();
          reconnect();
        },
        onDone: () {
          print('Server disconnected');
          _resetState();
          reconnect();
        },
      );
    } catch (e) {
      print('Failed to connect: $e');
      connect_state = false;
    }
  }

  /// 处理接收到的数据
  /// [data] 接收到的二进制数据
  Future<void> handleIncomingData(Uint8List data) async {
    try {
      _dataBuffer.add(data);

      if (!_isProcessing) {
        _isProcessing = true;
        while (_dataBuffer.isNotEmpty) {
          final currentData = _dataBuffer.removeFirst();
          await _processData(currentData);
        }
        _isProcessing = false;
      }
    } catch (e) {
      //addLog('数据处理错误: $e');
      _resetState();
    }
  }

  void _resetState() {
    isReceivingImage = false;
    isProcessingImage = false;
    _isProcessing = false;
    _dataBuffer.clear();
    currentImageData = Uint8List(0);
    expectedImageSize = 0;
  }

  /// 断开Socket连接
  void disconnect() {
    socket?.close();
    connect_state = false;
  }

  /// 设置新的IP地址
  /// [data] 新的IP地址
  void set_Ip(String data) {
    ip = data;
  }

  /// 获取当前图像数据
  /// 返回处理后的图像，如果没有则返回原始图像
  Uint8List getCurrentImage() {
    return processedImageData.isEmpty ? currentImageData : processedImageData;
  }

  /// 添加日志记录
  /// [message] 日志消息内容
  /*
  void //addLog(String message) {
    logMessages.add("[${DateTime.now().toString()}] $message");
    // 保持最新的100条记录
    if (logMessages.length > 100) {
      logMessages.removeAt(0);
    }
  }
  */

  // 在不需要时释放资源
  void dispose() {
    imageStreamController.close();
    socket?.close();
  }

  // 修改图像流处理
  void handleImageData(Uint8List data) {
    try {
      _lastImageUpdate = DateTime.now();
      imageStreamController.add(data);
    } catch (e) {
      print('图像处理错误: $e');
    }
  }

  // 修改图像监控机制
  void _startImageMonitor() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_lastImageUpdate != null) {
        final difference = DateTime.now().difference(_lastImageUpdate!);
        if (difference > _imageTimeout) {
          print('图像更新超时，尝试重新连接...');
          reconnect();
        }
      }
    });
  }

  // 修改连接方法
  Future<void> connect() async {
    try {
      socket = await Socket.connect(ip, port);
      socket!.setOption(SocketOption.tcpNoDelay, true); // 禁用Nagle算法
      _startImageMonitor();
      // ... 其他连接代码 ...
    } catch (e) {
      print('连接错误: $e');
    }
  }

  // 添加重连方法
  Future<void> reconnect() async {
    socket?.close();
    socket = null;
    await connect();
  }

  Future<void> _processData(Uint8List data) async {
    try {
      if (data.length == 4 && !isReceivingImage) {
        expectedImageSize =
            ByteData.view(data.buffer).getUint32(0, Endian.little);
        //('预期图片大小: $expectedImageSize 字节');
        currentImageData = Uint8List(0);
        isReceivingImage = true;
      }
      // 如果正在接收图像数据
      else if (isReceivingImage) {
        // 将新接收的数据追加到当前图像数据中
        currentImageData = Uint8List.fromList([...currentImageData, ...data]);
        //addLog('当前接收数据长度: ${currentImageData.length} 字节');

        if (currentImageData.length >= expectedImageSize) {
          isReceivingImage = false;
          //addLog('图片接收完成！总大小: ${currentImageData.length} 字节');

          // 如果数据大小正确且未在处理中，则开始处理图像
          if (currentImageData.length == expectedImageSize &&
              !isProcessingImage) {
            isProcessingImage = true;

            try {
              // 立即更新图像流，减少延迟
              imageStreamController.add(currentImageData);
              _lastImageUpdate = DateTime.now();

              // 进行目标检测
              await MyDetection.Det_StartInference(currentImageData);

              // 使用OpenCV处理图像
              try {
                // 从内存中解码JPEG数据
                final mat = imdecode(currentImageData, IMREAD_COLOR);

                // 直接编码为JPEG，不进行颜色空间转换
                final (success, encodedBytes) = imencode('.jpg', mat);
                if (success) {
                  // 通过 Stream 发送处理后的图像数据
                  processedImageData = encodedBytes;
                  //('图像处理成功');
                } else {
                  processedImageData = currentImageData;
                }

                // 释放OpenCV资源
                mat.dispose();
              } catch (e) {
                //addLog('OpenCV处理错误: $e');
                processedImageData = currentImageData;
              }

              // 如果存在刷新回调，则刷新UI
              if (refreash != null) {
                refreash!();
              }
            } catch (e) {
              //('处理图像时发生错误: $e');
            } finally {
              isProcessingImage = false;
            }
          }

          // 清理数据，准备接收下一张图像
          currentImageData = Uint8List(0);
          expectedImageSize = 0;
        }
      }
    } catch (e) {
      // 发生错误时重置所有状态
      //('数据处理错误: $e');
      isReceivingImage = false;
      isProcessingImage = false;
      currentImageData = Uint8List(0);
      expectedImageSize = 0;
    }
  }
}
