// 导入异步编程支持，提供Future、Stream等异步操作功能
import 'dart:async';

import 'dart:convert';

// 导入Flutter基础UI组件和服务
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

// 导入蓝牙功能
import 'package:myeyes/BLE.dart';

// 导入自定义的WiFi客户端类，处理网络连接和通信
import 'package:myeyes/wifi.dart';

// 导入自定义的文字转语音服务
import 'package:myeyes/TTS.dart';

// 导入帮助页面组件
import 'help.dart';

// 导入导航页面组件
import 'navigation.dart';

import 'services/openai_service.dart';

import 'package:x_amap_base/x_amap_base.dart';

import 'package:amap_map/amap_map.dart';

// 在文件顶部添加雷达客户端导入
import 'wifi_leida.dart';

// 在全局变量中添加雷达客户端实例
WiFiClient MyWifi = WiFiClient("192.168.37.33", 8080);
RadarClient MyRadar = RadarClient("192.168.37.33", 8082); // 使用相同IP但不同端口
TtsService tts = TtsService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 使用 MaterialApp 包装
  runApp(MaterialApp(
    home: const MyApp(),
    debugShowCheckedModeBanner: false,
  ));
  tts.TTS_speakText('听见视界伴您出行');
}

//------------------------------构建主程序----------------------------------------
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final BLEManager _bleManager = BLEManager();

  @override
  void initState() {
    super.initState();
    _bleManager.initBluetooth();
    _bleManager.setOnButtonPressedCallback(() {
      _triggerImageAnalysis();
    });
  }

  @override
  void dispose() {
    _bleManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AMapInitializer.init(context,
        apiKey: AMapApiKey(androidKey: "b1d5458282af400870738a63af553eda"));
    AMapInitializer.updatePrivacyAgree(
        AMapPrivacyStatement(hasAgree: true, hasContains: true, hasShow: true));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Colors.pink,
          secondary: Colors.black,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            backgroundColor: Colors.black,
            title: const Center(
              child: Text(
                '听见视界',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Container(
                height: 35,
                width: 35,
                decoration: const BoxDecoration(
                  color: Colors.yellow,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _bleManager.requestBluetoothPermissions(context);
                  },
                  icon: const Icon(
                    Icons.bluetooth,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 15),
                child: Container(
                  height: 35,
                  width: 35,
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          final ipController =
                              TextEditingController(text: '192.168.');
                          return AlertDialog(
                            backgroundColor: Colors.yellow,
                            title: const Text(
                              '动态设置IP地址',
                              style: TextStyle(color: Colors.black),
                              textAlign: TextAlign.center,
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  child: TextField(
                                    controller: ipController,
                                    style:
                                        const TextStyle(color: Colors.yellow),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '请输入IP地址',
                                      hintStyle:
                                          TextStyle(color: Colors.purple),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '当前IP地址为: ${MyWifi.ip}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  // IP地址格式验证
                                  final RegExp ipRegex = RegExp(
                                      r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');

                                  if (ipRegex.hasMatch(ipController.text)) {
                                    // 同时更新两个设备的IP地址
                                    MyWifi.set_Ip(ipController.text);
                                    MyRadar.setIp(ipController.text);
                                    Navigator.of(context).pop();
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          title: const Text('错误'),
                                          content: const Text('IP地址格式不合法'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text('确定'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                },
                                child: const Text('确定',
                                    style: TextStyle(color: Colors.black)),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: const Icon(
                      Icons.add,
                      color: Colors.yellow,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: const Center(
            child: MyHomePage(),
          ),
        ),
      ),
      routes: {
        '/navigation': (context) => const Navigation(),
      },
    );
  }

  // 触发图像解读功能
  void _triggerImageAnalysis() {
    // 直接调用备用方法处理图像，无需获取MyHomePageState实例
    _processFallbackImage();
  }

  // 新增：备用图像处理方法
  Future<void> _processFallbackImage() async {
    if (MyWifi.getCurrentImage().isEmpty) {
      print('备用方法：没有可用的图像');
      tts.TTS_speakText('没有可用的图像');
      return;
    }

    try {
      print('备用方法：开始处理图像');
      Uint8List image = MyWifi.getCurrentImage();
      final openAIService = OpenAIService();
      final base64Image = base64Encode(image);

      // 添加加载状态提示
      tts.TTS_speakText('图片分析中，请稍候');

      final result = await openAIService
          .analyzeImage(base64Image)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        return "分析超时，请检查网络连接";
      });

      // 使用最高优先级播报完整文本
      await tts.TTS_speakHighestPriorityText(result);
      print('备用方法：图像处理完成');
    } catch (e) {
      print('备用方法：图像处理失败: $e');
      tts.TTS_speakText('图片解读失败，请重试');
    }
  }

  // 获取Navigator的context - 这个方法现在简化为直接返回当前context
  BuildContext getKeyContext() {
    return context;
  }
}

//----------------------------构建主页面------------------------------------------
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => MyHomePageState();
}

//-----------------------------主页面示内容--------------------------------------
class MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  // 添加全局key以便外部访问
  static final GlobalKey<MyHomePageState> globalKey =
      GlobalKey<MyHomePageState>();

  TtsService mytts = TtsService();

  bool _previousConnectState = false; // 添加变量跟踪之前的连接状态
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();

    //传递刷新ui的函数
    MyWifi.refreash = () {
      // 检查连接状态是否发生变化
      if (_previousConnectState != MyWifi.connect_state) {
        if (MyWifi.connect_state) {
          tts.TTS_speakText('眼镜已连接');
        } else {
          tts.TTS_speakText('眼镜已断开连接');
        }
        _previousConnectState = MyWifi.connect_state;
      }
      setState(() {});
    };

    // 监听雷达障碍物流
    MyRadar.obstacleStream.listen((data) {
      // 可以在这里处理UI更新等
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 添加文本控制器以供文本输入使用
  final TextEditingController _questionController = TextEditingController();

  // 图像解读方法 - 显示弹窗
  Future<void> _saveCurrentImage() async {
    // 检查是否有图像，无图像时使用应用图标
    Uint8List? image;
    bool usingAppIcon = false;

    if (MyWifi.getCurrentImage().isEmpty) {
      // 使用应用图标替代
      usingAppIcon = true;
    } else {
      image = MyWifi.getCurrentImage();
    }

    // 重置问题文本
    _questionController.text = '';

    // 显示图像解读弹窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 图像显示 - 根据情况显示实际图像或应用图标
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: usingAppIcon
                            ? Image.asset(
                                'assets/icon/icon.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  print('图标加载错误: $error');
                                  // 提供备用图标或简单的容器
                                  return Container(
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.image,
                                      size: 100,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              )
                            : Image.memory(
                                image!,
                                fit: BoxFit.contain,
                              ),
                      ),
                      const SizedBox(height: 16),

                      // 文本编辑框
                      TextField(
                        controller: _questionController,
                        decoration: const InputDecoration(
                          hintText: '您想询问图片的什么内容？',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // 千问识图按钮
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('千问识图'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(200, 45),
                        ),
                        onPressed: () async {
                          // 关闭对话框
                          Navigator.of(context).pop();

                          // 获取用户问题
                          String userQuestion = _questionController.text.trim();

                          // 添加加载状态提示
                          tts.TTS_speakText('正在分析图片，请稍候');

                          try {
                            final openAIService = OpenAIService();
                            Uint8List imageToAnalyze;

                            // 使用应用图标或相机图像
                            if (usingAppIcon) {
                              // 加载应用图标并转为二进制数据
                              ByteData data =
                                  await rootBundle.load('assets/icon/icon.png');
                              imageToAnalyze = data.buffer.asUint8List();
                            } else {
                              imageToAnalyze = image!;
                            }

                            // 分析图像并回答问题
                            final base64Image = base64Encode(imageToAnalyze);
                            final result = await openAIService
                                .analyzeImageWithQuestion(
                                    base64Image, userQuestion)
                                .timeout(const Duration(seconds: 30),
                                    onTimeout: () {
                              return "分析超时，请检查网络连接";
                            });

                            // 使用最高优先级播报结果
                            await tts.TTS_speakHighestPriorityText(result);
                          } catch (e) {
                            print('图像处理失败: $e');
                            tts.TTS_speakText('图片解读失败，请重试');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('处理失败: ${e.toString()}')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 关闭按钮
                      TextButton(
                        child: const Text(
                          '关闭',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget buildImageWidget() {
    return StreamBuilder<Uint8List>(
      stream: MyWifi.imageStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            gaplessPlayback: true, // 防止图像闪烁
          );
        }
        return Container(); // 或其他占位组件
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 添加key
      key: MyHomePageState.globalKey,
      body: SingleChildScrollView(
        // 添加滚动视图
        child: Column(
          children: <Widget>[
            Center(
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                          decoration: BoxDecoration(
                            color: Colors.red, // 修改为红色背景
                            borderRadius:
                                BorderRadius.circular(15.0), // 设置圆角半径为 15.0
                          ),
                          alignment: Alignment.center,
                          width: 1000,
                          height: 50,
                          child: Text(
                            '摄像头连接状态：${MyWifi.connect_state ? '已连接' : '未连接'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18, // 设置文字大小为18
                              color: Colors.black,
                            ),
                          )),
                      const SizedBox(height: 40),
                      SizedBox(child: buildImageWidget()),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: 800,
                        height: 60,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange, // 设置为橙色
                            ),
                            onPressed: () async {
                              const platform =
                                  MethodChannel('com.example.myeyes/hotspot');
                              try {
                                await platform
                                    .invokeMethod('openHotspotSettings');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('请开启个人热点')),
                                );
                                tts.TTS_speakText('请开启个人热点');
                              } catch (e) {
                                print('开启热点失败: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('开启热失败，请手动开启')),
                                );
                                tts.TTS_speakText('开启热点失败，请手动开启');
                              }
                            },
                            child: const Text("热点设置",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ))),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: 800,
                        height: 60,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow, // 设置为黄色
                            ),
                            onPressed: (MyWifi.connect_state || _isConnecting)
                                ? null
                                : () async {
                                    setState(() {
                                      _isConnecting = true;
                                    });
                                    tts.TTS_speakText('正在连接设备');

                                    // 分别处理连接，避免互相影响
                                    try {
                                      await MyWifi.connectAndCommunicate()
                                          .timeout(const Duration(seconds: 5),
                                              onTimeout: () {
                                        print('摄像头连接超时');
                                        return;
                                      });
                                    } catch (e) {
                                      print('摄像头连接错误: $e');
                                    }

                                    try {
                                      await MyRadar.connectAndCommunicate()
                                          .timeout(const Duration(seconds: 5),
                                              onTimeout: () {
                                        print('雷达连接超时');
                                        return;
                                      });
                                    } catch (e) {
                                      print('雷达连接错误: $e');
                                    }

                                    // 检查连接状态并播报
                                    if (MyWifi.connect_state &&
                                        MyRadar.connectState) {
                                      tts.TTS_speakText('摄像头和雷达均已连接');
                                    } else if (MyWifi.connect_state) {
                                      tts.TTS_speakText('仅摄像头已连接');
                                    } else if (MyRadar.connectState) {
                                      tts.TTS_speakText('仅雷达已连接');
                                    } else {
                                      tts.TTS_speakText('设备连接失败');
                                    }

                                    // 重置连接状态
                                    if (mounted) {
                                      setState(() {
                                        _isConnecting = false;
                                      });
                                    }
                                  },
                            child:
                                Text(_isConnecting ? "正在连接..." : "open my eyes",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Colors.black,
                                    ))),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: 800,
                        height: 60,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green, // 设置为绿色
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) => const Help()),
                              );
                            },
                            child: const Text(
                              '帮 助',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.black,
                              ),
                            )),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width *
                                0.4, // 屏幕宽度的40%
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                backgroundColor: Colors.cyan, // 设置为青色（浅蓝）
                              ),
                              onPressed: () {
                                SystemNavigator.pop();
                              },
                              child: const Text(
                                '退 出',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width *
                                0.4, // 屏幕宽度的40%
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                backgroundColor: Colors.blue, // 设置为蓝色（深蓝）
                              ),
                              onPressed: () {
                                // 实现图像解读逻辑
                                _saveCurrentImage();
                              },
                              child: const Text(
                                '解 读',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Container(
                          decoration: BoxDecoration(
                            color: Colors.purple, // 修改为紫色背景
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          alignment: Alignment.center,
                          width: 1000,
                          height: 50,
                          child: Text(
                            '雷达连接状态：${MyRadar.connectState ? '已连接' : '未连接'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          )),
                      StreamBuilder<Map<String, dynamic>>(
                        stream: MyRadar.obstacleStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData ||
                              MyRadar.displayMatrix.isEmpty) {
                            return Container(
                              height: 150,
                              color: Colors.grey[300],
                              child: const Center(child: Text('等待雷达数据...')),
                            );
                          }

                          return Container(
                            height: 150,
                            color: Colors.grey[300],
                            child: Column(
                              children: [
                                const Text('雷达避障数据',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    )),
                                Expanded(
                                  child: Column(
                                    children: List.generate(
                                      MyRadar.displayMatrix.length,
                                      (row) => Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: List.generate(
                                            MyRadar.displayMatrix[row].length,
                                            (col) {
                                              int distance = MyRadar
                                                  .displayMatrix[row][col];
                                              // 获取当前格子的阈值
                                              int threshold = 0;
                                              if (row == 0)
                                                threshold = 500; // 上行
                                              else if (row == 1)
                                                threshold = 1000; // 中行
                                              else
                                                threshold = 1500; // 下行

                                              // 根据阈值设置颜色（只有红/绿两色）
                                              Color color = distance < threshold
                                                  ? Colors.red
                                                  : Colors.green;

                                              return Container(
                                                width: 50,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '$distance',
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
