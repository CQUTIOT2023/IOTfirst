import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:myeyes/TTS.dart';
import 'dart:async';

class RadarClient {
  // 实例化TTS服务，用于语音播报
  TtsService tts = TtsService();

  // 连接信息
  String ip;
  int port;
  bool connectState = false;
  Socket? socket;

  // 数据存储
  List<List<int>> distanceMatrix = []; // 原始25x25数据
  List<List<int>> displayMatrix = []; // UI显示用3x3数据
  /*
  List<String> logMessages = [];
  */

  // 避障阈值（毫米）
  final int closeThreshold = 500; // 紧急警告距离
  final int nearThreshold = 1000; // 警告距离
  final int alertThreshold = 1500; // 提醒距离

  // 方位定义（9个区域）
  final List<String> positions = [
    '左上',
    '中上',
    '右上',
    '左中',
    '中',
    '右中',
    '左下',
    '中下',
    '右下'
  ];

  // 冷却时间控制（避免语音播报过于频繁）
  DateTime? lastAlertTime;
  final alertCooldown = const Duration(seconds: 3);

  // 创建避障状态流
  final _obstacleStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get obstacleStream =>
      _obstacleStreamController.stream;

  RadarClient(this.ip, this.port);

  /// 建立Socket连接并开始通信
  Future<void> connectAndCommunicate() async {
    try {
      socket = await Socket.connect(ip, port, timeout: Duration(seconds: 5));
      socket!.setOption(SocketOption.tcpNoDelay, true);
      connectState = true;
      //addLog('已连接到雷达服务器');

      socket!.listen(
        (data) => handleIncomingData(data),
        onError: (error) {
          print('雷达连接错误: $error');
          //addLog('雷达连接错误: $error');
          reset();
          reconnect();
        },
        onDone: () {
          print('雷达服务器断开连接');
          //addLog('雷达服务器断开连接');
          reset();
          reconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('雷达连接失败: $e');
      //addLog('雷达连接失败: $e');
      connectState = false;
      await Future.delayed(Duration(seconds: 2));
      reconnect();
    }
  }

  /// 处理接收到的雷达数据
  void handleIncomingData(Uint8List data) {
    try {
      // 解析数据为距离矩阵
      List<List<int>> distances = parseDistanceData(data);
      distanceMatrix = distances;

      // 将25x25矩阵转换为3x3显示矩阵
      displayMatrix = convertToDisplayMatrix(distances);

      // 检测障碍物并发出警告
      detectObstaclesAndAlert(distances);

      // 发送数据更新到流
      _obstacleStreamController.add({
        'distances': displayMatrix,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      print('雷达数据处理错误: $e');
      //addLog('雷达数据处理错误: $e');
    }
  }

  /// 解析距离数据（对应main.cpp的格式）
  List<List<int>> parseDistanceData(Uint8List data) {
    int rows = 25;
    int cols = 25;
    List<List<int>> distances =
        List.generate(rows, (_) => List.filled(cols, 0));

    try {
      // 检查数据包最小长度（对应EXPECTED_DATA_SIZE=646）
      if (data.length < 646) {
        //addLog('数据包长度不足: ${data.length}字节，期望646字节');
        return distances;
      }

      // 数据开始位置（跳过包头）
      int dataStartIndex = 21; // 根据具体包头长度调整

      // 解析距离数据
      for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
          int index = dataStartIndex + (i * cols + j);
          if (index < data.length) {
            // 使用与main.cpp中相同的Distance函数
            int rawValue = data[index].toInt();
            int distance = ((rawValue / 5.1) * (rawValue / 5.1)).round();

            //规避数据处理出错导致distances=0而播报
            if (distance == 0) {
              distance = 9999;
            }
            // 限制有效距离为2500毫米
            else if (distance > 2500) {
              distance = 2500; // 超出范围设为最大值
            }

            distances[i][j] = distance;
          }
        }
      }
    } catch (e) {
      //addLog('雷达数据解析错误: $e');
    }

    return distances;
  }

  /// 将25x25矩阵转换为3x3显示矩阵（UI显示用）
  List<List<int>> convertToDisplayMatrix(List<List<int>> fullMatrix) {
    int horizontalParts = 3;
    int verticalParts = 3;
    List<List<int>> displayMatrix =
        List.generate(verticalParts, (_) => List.filled(horizontalParts, 0));

    if (fullMatrix.isEmpty) return displayMatrix;

    int rows = fullMatrix.length;
    int cols = fullMatrix[0].length;
    int rowsPerPart = rows ~/ verticalParts;
    int colsPerPart = cols ~/ horizontalParts;

    // 计算每个3x3区域内的平均距离
    for (int i = 0; i < verticalParts; i++) {
      for (int j = 0; j < horizontalParts; j++) {
        int sum = 0;
        int count = 0;

        // 遍历当前区域内的所有点
        for (int r = i * rowsPerPart;
            r < (i + 1) * rowsPerPart && r < rows;
            r++) {
          for (int c = j * colsPerPart;
              c < (j + 1) * colsPerPart && c < cols;
              c++) {
            if (fullMatrix[r][c] > 0) {
              sum += fullMatrix[r][c];
              count++;
            }
          }
        }

        // 计算当前区域的平均距离
        displayMatrix[i][j] = count > 0 ? (sum / count).round() : 0;
      }
    }

    return displayMatrix;
  }

  /// 检测障碍物并发出警告（对应main.cpp的AvoidObstacle函数）
  void detectObstaclesAndAlert(List<List<int>> distances) {
    if (distances.isEmpty) return;

    // 定义三个大区域的状态（左/中/右）
    bool leftHasObstacle = false;
    bool centerHasObstacle = false;
    bool rightHasObstacle = false;

    // 与main.cpp中相同的划分参数
    int horizontalParts = 3;
    int verticalParts = 3;

    // 设置各区域阈值（根据要求，按行分别为500mm/1000mm/1500mm）
    List<int> thresholds = [
      500, 500, 500, // 上三个区域阈值为500
      1000, 1000, 1000, // 中三个区域阈值为1000
      1500, 1500, 1500 // 下三个区域阈值为1500
    ];

    int rows = distances.length;
    int cols = distances[0].length;
    int rowsPerPart = rows ~/ verticalParts;
    int colsPerPart = cols ~/ horizontalParts;

    // 处理3x3区域
    for (int v = 0; v < verticalParts; v++) {
      for (int h = 0; h < horizontalParts; h++) {
        List<int> points = [];

        // 收集当前区域内的所有有效距离值（与main.cpp逻辑一致）
        for (int i = v * rowsPerPart;
            i < (v + 1) * rowsPerPart && i < rows;
            i++) {
          for (int j = h * colsPerPart;
              j < (h + 1) * colsPerPart && j < cols;
              j++) {
            if (distances[i][j] > 0 && distances[i][j] < 2500) {
              points.add(distances[i][j]);
            }
          }
        }

        if (points.isNotEmpty) {
          // 排序以计算20%分位点（与main.cpp逻辑一致）
          points.sort();

          // 计算20%的点数
          int lowPercentileCount = (points.length * 0.2).ceil();
          if (lowPercentileCount > 0) {
            // 计算最近20%点的平均距离
            double sum = 0;
            for (int k = 0; k < lowPercentileCount; k++) {
              sum += points[k];
            }
            double avgDistance = sum / lowPercentileCount;

            // 获取当前区域的阈值
            int threshold = thresholds[v * horizontalParts + h];

            // 根据分区位置更新大区域状态
            if (avgDistance < threshold) {
              if (h == 0) {
                // 左侧区域
                leftHasObstacle = true;
              } else if (h == 1) {
                // 中间区域
                centerHasObstacle = true;
              } else {
                // 右侧区域
                rightHasObstacle = true;
              }
            }

            // 更新显示矩阵（用于UI展示）
            displayMatrix[v][h] = avgDistance.round();
          }
        }
      }
    }

    // 根据大区域状态生成语音警告
    List<String> alerts = [];
    if (leftHasObstacle) {
      alerts.add('左侧有障碍');
    }
    if (centerHasObstacle) {
      alerts.add('前方有障碍');
    }
    if (rightHasObstacle) {
      alerts.add('右侧有障碍');
    }

    // 播报警告（带冷却时间控制，约2秒间隔）
    if (alerts.isNotEmpty && shouldAlert()) {
      // 限制警报数量，防止过多
      if (alerts.length > 2) {
        alerts = alerts.sublist(0, 2);
      }

      String alertMessage = alerts.join('，');
      tts.TTS_speakImpText(alertMessage);
      lastAlertTime = DateTime.now();
    }
  }

  /// 判断是否应该发出警告（避免警告过于频繁）
  bool shouldAlert() {
    if (lastAlertTime == null) return true;
    return DateTime.now().difference(lastAlertTime!) >
        Duration(seconds: 2); // 调整为2秒冷却时间
  }

  /// 重置状态
  void reset() {
    connectState = false;
    distanceMatrix = [];
    displayMatrix = List.generate(3, (_) => List.filled(3, 0));
  }

  /// 断开连接
  void disconnect() {
    socket?.close();
    connectState = false;
    //addLog('已断开雷达连接');
  }

  /// 重新连接
  Future<void> reconnect() async {
    socket?.close();
    await Future.delayed(Duration(seconds: 2));
    await connectAndCommunicate();
  }

  /// 设置新的IP地址
  void setIp(String newIp) {
    ip = newIp;
    //addLog('已更新雷达IP地址: $newIp');
  }

  /// 添加日志
  /*
  void addLog(String message) {
    logMessages.add("[${DateTime.now().toString()}] $message");
    if (logMessages.length > 100) {
      logMessages.removeAt(0);
    }
  }
  */

  /// 释放资源
  void dispose() {
    socket?.close();
    _obstacleStreamController.close();
  }
}
