import 'dart:async'; // 添加TimeoutException支持
//import 'package:flutter/services.dart'; // 添加PlatformException支持
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'services/navigation_service.dart';
import 'package:amap_map/amap_map.dart';
import 'package:x_amap_base/x_amap_base.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import 'package:myeyes/privacy_policy_dialog.dart'; // 添加这行
//import 'dart:math' show min, max;
import 'package:myeyes/TTS.dart';

/// 导航页面
/// 提供基于高德地图的步行导航功能
/// 包含地点搜索、路线规划等功能

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final TtsService tts = TtsService();

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  final NavigationService _navigationService = NavigationService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = []; // 搜索结果列表
  Position? _currentPosition; // 当前位置
  Map<String, dynamic>? _selectedRoute; // 选中的路线
  bool _isLoading = false; // 加载状态标志
  late AMapController _mapController;
  final List<Marker> _markers = [];
  //final List<Polyline> _polylines = [];
  LatLng? _currentLatLng;

  // 添加审图号相关状态
  List<String> _approvalNumbers = [];

  @override
  void initState() {
    super.initState();
    // 立即初始化隐私合规
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initPrivacy();
    });
  }

  Future<void> _initPrivacy() async {
    try {
      // 每次都显示隐私弹窗
      final agreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PrivacyPolicyDialog(
          onAgreed: (agreed) {
            Navigator.pop(context, agreed);
          },
        ),
      );

      if (agreed == true) {
        // 初始化地图
        await _initMap();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      print('隐私合规初始化失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('初始化失败: $e')),
        );
      }
    }
  }

  Future<void> _initMap() async {
    try {
      // 获取位置权限和位置信息
      await _getCurrentLocation();
    } catch (e) {
      print('地图初始化失败: $e');
    }
  }

  /// 获取当前位置
  /// 使用Geolocator插件获取设备GPS位置
  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      // 检查服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('请先启用定位服务')));
        }
        return;
      }

      // 获取位置
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _updateCurrentMarker();
        _isLoading = false;
      });
    } catch (e) {
      print('获取位置失败: $e');
      setState(() => _isLoading = false);
    }
  }

  void _updateCurrentMarker() {
    // 使用 _mapController 移动相机
    _mapController.moveCamera(
      CameraUpdate.newLatLngZoom(_currentLatLng!, 15),
    );
  }

  /// 搜索地点
  /// [keyword] 搜索关键词
  /// 使用高德地图POI搜索API
  Future<void> _searchPlace(String keyword) async {
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _navigationService.searchPlace(keyword);
      setState(() {
        _searchResults = result['pois'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('搜索失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 规划步行路线
  Future<void> _planRoute(Map<String, dynamic> destination) async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final origin =
          '${_currentPosition!.longitude},${_currentPosition!.latitude}';
      final dest = '${destination['location']}';

      final route = await _navigationService.getWalkingRoute(origin, dest);
      setState(() {
        _selectedRoute = route;
        _isLoading = false;
      });
    } catch (e) {
      print('规划路线失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _speakCurrentLocation() async {
    if (_currentPosition == null) {
      tts.TTS_speakText('正在获取位置信息，请稍候');
      return;
    }

    try {
      final result = await _navigationService.getAddressFromLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      final address = result['formatted_address'] ?? '未知位置';
      tts.TTS_speakText('您当前位于$address');
    } catch (e) {
      print('获取地址失败: $e');
      tts.TTS_speakText('获取位置信息失败，请重试');
    }
  }

  // 获取审图号
  void _getApprovalNumber() async {
    try {
      // 尝试使用try-catch包装每个可能的API调用，防止某个方法不存在导致整个应用崩溃
      String mapContent = "";
      String satellite = "";

      try {
        mapContent = await _mapController.getMapContentApprovalNumber();
      } catch (e) {
        print('获取地图内容审图号失败: $e');
      }

      try {
        satellite = await _mapController.getSatelliteImageApprovalNumber();
      } catch (e) {
        print('获取卫星图审图号失败: $e');
      }

      if (mounted) {
        setState(() {
          _approvalNumbers = [
            if (mapContent.isNotEmpty) '审图号：$mapContent',
            if (satellite.isNotEmpty) '卫星图审图号：$satellite'
          ];
        });
      }
    } catch (e) {
      print('获取审图号总体失败: $e');
      // 防止因为审图号崩溃影响整个应用
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图与位置信息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _speakCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // 地图容器
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                AMapWidget(
                  onMapCreated: (controller) {
                    setState(() {
                      _mapController = controller;
                      if (_currentLatLng != null) {
                        _updateCurrentMarker();
                      }
                      // 尝试获取审图号，但不影响地图主要功能
                      try {
                        _getApprovalNumber();
                      } catch (e) {
                        print('审图号初始化失败: $e');
                      }
                    });
                  },
                  compassEnabled: true,
                  scaleEnabled: true,
                  zoomGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  markers: Set<Marker>.of(_markers),
                  //polylines: Set<Polyline>.of(_polylines),
                  initialCameraPosition: CameraPosition(
                    target:
                        _currentLatLng ?? const LatLng(39.90960, 116.397228),
                    zoom: 15,
                  ),
                  //myLocationStyleOptions: MyLocationStyleOptions(true),
                ),
                // 显示审图号
                if (_approvalNumbers.isNotEmpty)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _approvalNumbers
                            .map((text) => Text(text,
                                style: const TextStyle(fontSize: 12)))
                            .toList(),
                      ),
                    ),
                  )
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索地点',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchPlace(_searchController.text),
                ),
              ),
            ),
          ),

          // 加载指示器
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final place = _searchResults[index];
                  return ListTile(
                    title: Text(place['name'] ?? ''),
                    subtitle: Text(place['address'] ?? ''),
                    onTap: () {
                      _planRoute(place);
                      tts.TTS_speakText(
                          '已选择${place['name']}，位于${place['address']}');
                    },
                  );
                },
              ),
            ),

          // 显示路线信息
          if (_selectedRoute != null)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '步行路线：',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '总距离: ${_selectedRoute!['route']['paths'][0]['distance']}米\n'
                      '预计时间: ${_selectedRoute!['route']['paths'][0]['duration']}秒',
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _selectedRoute!['route']['paths'][0]['steps']
                            .length,
                        itemBuilder: (context, index) {
                          final step = _selectedRoute!['route']['paths'][0]
                              ['steps'][index];
                          return ListTile(
                            leading: const Icon(Icons.directions_walk),
                            title: Text(step['instruction']),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
