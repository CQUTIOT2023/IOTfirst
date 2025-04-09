// 导入Flutter基础UI组件库，提供了构建界面所需的核心组件
import 'package:flutter/material.dart';

// 导入平台服务支持，用于实现与原生平台的通信（如拨打电话功能）
import 'package:flutter/services.dart';

// 导入权限处理插件，用于请求和管理应用权限（如电话权限）
import 'package:permission_handler/permission_handler.dart';

// 导入地理位置定位插件，用于获取用户位置信息
import 'package:geolocator/geolocator.dart';

// 导入天气服务类
import 'services/weather_service.dart';

// 导入新的页面
import 'instructions_privacy.dart';

/// 帮助页面
/// 提供天气查询、紧急求助等功能
class Help extends StatefulWidget {
  const Help({super.key});

  @override
  State<Help> createState() => _HelpState();
}

/// Help页面的状态管理类
class _HelpState extends State<Help> {
  String selectedCity = '北京'; // 当前选择的城市
  final WeatherService _weatherService = WeatherService(); // 天气服务实例
  List<Map<String, dynamic>> weatherData = []; // 天气预报数据
  Map<String, List<String>> cityData = {}; // 省份城市数据
  String selectedProvince = ''; // 当前选择的省份

  // 位置缓存相关
  String? _lastKnownLocation; // 上次获取的位置
  DateTime? _lastLocationUpdate; // 上次更新时间
  final Duration _locationCacheDuration = const Duration(minutes: 5); // 缓存时间

  @override
  void initState() {
    super.initState();
    // 初始化时获取位置信息和加载城市数据
    _initializeLocation();
    _loadCityData();
  }

  /// 检查位置缓存是否有效
  bool _isLocationCacheValid() {
    if (_lastLocationUpdate == null) return false;
    final difference = DateTime.now().difference(_lastLocationUpdate!);
    return difference < _locationCacheDuration;
  }

  /// 初始化位置信息
  /// 获取当前位置并更新天气信息
  Future<void> _initializeLocation() async {
    try {
      // 检查缓存的位置信息是否有效
      if (_isLocationCacheValid() && _lastKnownLocation != null) {
        await _updateWeather(_lastKnownLocation!);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // 如果权限被拒绝，请求权限
        permission = await Geolocator.requestPermission();
      }

      // 如果有位置权限（使用中或始终允许）
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // 获取当前位置
        Position position = await Geolocator.getCurrentPosition();
        // 使用新添加的方法获取adcode
        String adcode = await _weatherService.getAdcodeFromLocation(
          position.latitude,
          position.longitude,
        );

        // 更新位置缓存
        _lastKnownLocation = adcode;
        _lastLocationUpdate = DateTime.now();

        await _updateWeather(adcode);
      }
    } catch (e) {
      print('定位错误: $e');
      // 发生错误时使用默认城市（北京）
      await _updateWeather("110000");
    }
  }

  /// 加载城市数据
  /// 从高德地图API获取行政区划数据
  Future<void> _loadCityData() async {
    try {
      // 获取行政区划数据
      final districtData = await _weatherService.getDistrict();
      if (districtData['districts'] != null &&
          districtData['districts'].isNotEmpty) {
        // 创建临时Map存储省份和城市数据
        Map<String, List<String>> tempCityData = {};

        // 遍历所有省份
        for (var province in districtData['districts'][0]['districts']) {
          String provinceName = province['name'];
          tempCityData[provinceName] = [];

          // 遍历该省份下的所有城市
          for (var city in province['districts']) {
            tempCityData[provinceName]!.add(city['name']);
          }
        }

        // 更新状态，触发UI重建
        setState(() {
          cityData = tempCityData;
        });
      }
    } catch (e) {
      print('加载城市数据错误: $e');
      if (mounted) {
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载城市数据失败: $e')),
        );
      }
    }
  }

  /// 更新天气信息
  /// [adcode] 城市的行政区划代码
  /// 根据adcode获取并更新天气数据
  Future<void> _updateWeather(String adcode) async {
    try {
      // 获取天气预报数据
      final weather = await _weatherService.getWeather(adcode);
      if (weather['forecasts'] != null && weather['forecasts'].isNotEmpty) {
        // 更新状态：天气数据和选中的城市
        setState(() {
          weatherData =
              List<Map<String, dynamic>>.from(weather['forecasts'][0]['casts']);
          selectedCity = weather['forecasts'][0]['city'];
        });
      }
    } catch (e) {
      print('更新天气错误: $e');
    }
  }

  /// 检查并请求电话权限
  /// 用于拨打紧急电话前的权限检查
  Future<void> _checkAndRequestPermission() async {
    // 检查电话权限状态
    var status = await Permission.phone.status;
    if (!status.isGranted) {
      // 如果没有权限，请求权限
      status = await Permission.phone.request();
      if (!status.isGranted) {
        // 用户拒绝了权限请求
        return;
      }
    }
  }

  /// 显示紧急援助对话框
  /// 提供110、120、119紧急电话拨打功能
  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('紧急援助(SOS)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('110 - 报警'),
                onTap: () async {
                  Navigator.pop(context);
                  // 先检查权限
                  await _checkAndRequestPermission();
                  const platform = MethodChannel('com.example.myeyes/sos');
                  try {
                    await platform.invokeMethod('openDialer');
                  } catch (e) {
                    if (!mounted) return;
                    // 显示错误对话框
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('错误'),
                          content: Text('打开拨号界面失败: $e'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('确定'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('120 - 急救'),
                onTap: () async {
                  Navigator.pop(context);
                  await _checkAndRequestPermission();
                  const platform = MethodChannel('com.example.myeyes/sos');
                  try {
                    await platform.invokeMethod('openDialer120');
                  } catch (e) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('错误'),
                          content: Text('打开拨号界面失败: $e'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('确定'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('119 - 消防'),
                onTap: () async {
                  Navigator.pop(context);
                  await _checkAndRequestPermission();
                  const platform = MethodChannel('com.example.myeyes/sos');
                  try {
                    await platform.invokeMethod('openDialer119');
                  } catch (e) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('错误'),
                          content: Text('打开拨号界面败: $e'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('确定'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示省份选择对话框
  /// 如果城市数据未加载完成，显示提示信息
  /// 否则显示可选择的省份列表
  void _showProvinceDialog() {
    // 检查城市数据是否已加载
    if (cityData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('城市数据加载中，请稍后重试')),
      );
      return;
    }

    // 显示省份选择对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('选择省份'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // 将省份Map的键转换为ListTile列表
              children: cityData.keys.map((province) {
                return ListTile(
                  title: Text(province),
                  onTap: () {
                    Navigator.pop(context); // 关闭省份选择对话框
                    selectedProvince = province; // 更新选中的省份
                    _showCityDialog(province); // 显示对应省份的城市列表
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// 显示城市选择对话框
  /// [province] 选中的省份名称
  /// 根据选中的省份获取并显示对应的城市列表
  void _showCityDialog(String province) async {
    try {
      // 获取指定省份的城市数据
      final cityData = await _weatherService.getDistrict(keywords: province);
      // 检查返回的数据是否有效
      if (cityData['districts'] != null &&
          cityData['districts'].isNotEmpty &&
          cityData['districts'][0]['districts'] != null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('选择城市 - $province'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  // 将城市数据转换为ListTile列表
                  children:
                      cityData['districts'][0]['districts'].map<Widget>((city) {
                    return ListTile(
                      title: Text(city['name']),
                      onTap: () async {
                        setState(() {
                          selectedCity = city['name']; // 更新选中的城市
                        });
                        await _updateWeather(city['adcode']); // 更新天气数据
                        Navigator.pop(context); // 关闭城市选择对话框
                      },
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      print('获取城市数据错误: $e');
      if (mounted) {
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取城市数据失败: $e')),
        );
      }
    }
  }

  /// 显示天气详情对话框
  /// 展示选中城市的四日天气预报信息
  void _showWeatherDetailsDialog() {
    // 检查天气数据是否已加载
    if (weatherData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('天气数据加载中...')),
      );
      return;
    }

    // 显示天气详情对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$selectedCity 四日天气'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            // 将天气数据转换为ListTile列表
            children: weatherData.map((weather) {
              return ListTile(
                title: Text('${weather['date']} ${weather['week']}'),
                subtitle: Text(
                  '日间: ${weather['daytemp']}° ${weather['dayweather']}\n'
                  '夜间: ${weather['nighttemp']}° ${weather['nightweather']}',
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("帮助界面"),
      ),
      body: Center(
          child: Container(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InstructionsPrivacyPage(),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    alignment: Alignment.center,
                    width: 400,
                    height: 100,
                    child: const Text(
                      '点击查看使用说明及隐私合规',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  width: 400,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange, // 橙色背景
                      //foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/navigation'); // 路由跳转
                    },
                    child: const Text(
                      '地图与位置信息',
                      style: TextStyle(
                        fontSize: 30,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  width: 400,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // 使用红色背景
                      //foregroundColor: Colors.black,
                    ),
                    onPressed: _showEmergencyDialog, // 添加点击事件
                    child: const Text(
                      '紧急援助(SOS)',
                      style: TextStyle(
                        fontSize: 30,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // 添加新的Row组件
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 左侧天气信息容器（改为可点击的容器）
                    GestureDetector(
                      onTap: _showWeatherDetailsDialog,
                      child: Container(
                        width: 180,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: weatherData.isEmpty
                              ? const Text(
                                  '加载中...',
                                  style: TextStyle(color: Colors.black),
                                )
                              : const Text(
                                  '点击查看天气详情',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // 右侧城市选择按钮
                    SizedBox(
                      width: 100,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _showProvinceDialog,
                        child: Text(
                          selectedCity,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                Container(
                    decoration: BoxDecoration(
                      color: Colors.pink, // 容器的背景颜色
                      borderRadius: BorderRadius.circular(15.0), // 设置圆角半径为 15.0
                    ),
                    alignment: Alignment.center,
                    width: 400,
                    height: 100,
                    child: const Text(
                      '开发团队:C204\n电子邮箱:jz659947@gmail.com\n联系电话:(+86)19133785078',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    )),
              ]),
        ),
      )),
    );
  }
}
