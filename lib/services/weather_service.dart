import 'dart:convert'; // 导入JSON编解码支持
import 'package:http/http.dart' as http; // 导入HTTP客户端支持
import 'package:dio/dio.dart'; // 导入Dio客户端支持

/// WeatherService类用于处理天气相关的API请求
/// 包括获取天气预报、实时天气和行政区域信息
class WeatherService {
  // 高德地图API密钥，用于认证API请求
  final String _apiKey = 'd9d5b5221f0dbf8b4e6b09110d91cab0';

  // 高德天气API的基础URL
  final String _baseUrl = 'https://restapi.amap.com/v3/weather/weatherInfo';

  // Dio客户端实例
  final Dio dio = Dio();

  // 添加缓存相关的变量
  final Map<String, dynamic> _weatherCache = {};
  final Map<String, dynamic> _districtCache = {};
  final Duration _cacheDuration = const Duration(minutes: 30); // 缓存有效期30分钟
  final Map<String, DateTime> _cacheTimestamp = {};

  /// 检查缓存是否有效
  bool _isCacheValid(String key) {
    if (!_cacheTimestamp.containsKey(key)) return false;
    final difference = DateTime.now().difference(_cacheTimestamp[key]!);
    return difference < _cacheDuration;
  }

  /// 获取天气预报信息（带缓存）
  /// [adcode] 城市的行政区划代码
  /// 返回包含未来几天天气预报的Map对象
  Future<Map<String, dynamic>> getWeather(String adcode) async {
    final cacheKey = 'weather_$adcode';

    // 检查缓存是否有效
    if (_isCacheValid(cacheKey) && _weatherCache.containsKey(cacheKey)) {
      return _weatherCache[cacheKey];
    }

    try {
      // 构建API请求URL，extensions=all表示获取预报天气
      final response = await http.get(
        Uri.parse('$_baseUrl?key=$_apiKey&city=$adcode&extensions=all'),
      );

      // 检查响应状态
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // 检查API返回状态，1表示成功
        if (data['status'] == '1') {
          // 更新缓存
          _weatherCache[cacheKey] = data;
          _cacheTimestamp[cacheKey] = DateTime.now();
          return data;
        } else {
          throw Exception('API返回错误: ${data['info']}');
        }
      } else {
        throw Exception('获取天气数据失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取天气数据失败: $e');
    }
  }

  /// 获取实时天气信息
  /// [adcode] 城市的行政区划代码
  /// 返回包含实时天气数据的Map对象
  Future<Map<String, dynamic>> getCurrentWeather(String adcode) async {
    try {
      // 构建API请求URL，extensions=base表示获取实时天气
      final response = await http.get(
        Uri.parse('$_baseUrl?key=$_apiKey&city=$adcode&extensions=base'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == '1') {
          return data;
        } else {
          throw Exception('API返回错误: ${data['info']}');
        }
      } else {
        throw Exception('获取天气数据失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取天气数据失败: $e');
    }
  }

  /// 获取行政区域信息（带缓存）
  /// [keywords] 可选的关键字参数，用于搜索特定地区
  /// 返回包含行政区划数据的Map对象
  Future<Map<String, dynamic>> getDistrict({String? keywords}) async {
    final cacheKey = 'district_${keywords ?? "all"}';

    // 检查缓存是否有效
    if (_isCacheValid(cacheKey) && _districtCache.containsKey(cacheKey)) {
      return _districtCache[cacheKey];
    }

    try {
      // 构建行政区划查询API的URL
      // subdistrict=2 表示返回两级行政区划
      final response = await http.get(
        Uri.parse('https://restapi.amap.com/v3/config/district?key=$_apiKey'
            '${keywords != null ? "&keywords=$keywords" : ""}'
            '&subdistrict=2'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == '1') {
          // 更新缓存
          _districtCache[cacheKey] = data;
          _cacheTimestamp[cacheKey] = DateTime.now();
          return data;
        } else {
          throw Exception('API返回错误: ${data['info']}');
        }
      } else {
        throw Exception('获取行政区域数据失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取行政区域数据失败: $e');
    }
  }

  /// 获取地址编码
  /// [latitude] 纬度
  /// [longitude] 经度
  /// 返回包含地址编码的String对象
  Future<String> getAdcodeFromLocation(
      double latitude, double longitude) async {
    try {
      final response = await dio.get(
        'https://restapi.amap.com/v3/geocode/regeo',
        queryParameters: {
          'key': 'd9d5b5221f0dbf8b4e6b09110d91cab0',
          'location': '$longitude,$latitude',
        },
      );

      if (response.data['status'] == '1' &&
          response.data['regeocode'] != null) {
        return response.data['regeocode']['addressComponent']['adcode'];
      }
      throw Exception('获取地址编码失败');
    } catch (e) {
      throw Exception('逆地理编码请求失败: $e');
    }
  }
}
