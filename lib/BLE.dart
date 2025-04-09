import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:myeyes/main.dart'; // 导入全局变量tts

class BLEManager {
  // 存储已发现的设备
  List<BluetoothDevice> discoveredDevices = [];

  // 已连接的设备
  BluetoothDevice? connectedDevice;

  // 通知特征
  BluetoothCharacteristic? notifyCharacteristic;

  // 设备连接状态
  bool isConnected = false;

  // 设备扫描状态
  bool isScanning = false;

  // 按钮按下回调
  VoidCallback? onButtonPressed;

  // 服务和特征UUID (与BLE.cpp中定义的相同)
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // 初始化蓝牙
  Future<void> initBluetooth() async {
    // 检查蓝牙是否可用
    try {
      // 监听蓝牙状态变化
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          print('蓝牙已打开');
        } else if (state == BluetoothAdapterState.off) {
          print('蓝牙已关闭');
          isConnected = false;
          connectedDevice = null;
        }
      });
    } catch (e) {
      print('初始化蓝牙出错: $e');
    }
  }

  // 请求蓝牙权限
  Future<void> requestBluetoothPermissions(BuildContext context) async {
    // 请求必要的权限
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    // 检查权限是否被授予
    if (statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.location]!.isGranted) {
      // 开始扫描设备
      await startScan(context);
    } else {
      // 显示权限被拒绝的提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要蓝牙和位置权限才能搜索设备')),
      );
    }
  }

  // 开始扫描蓝牙设备
  Future<void> startScan(BuildContext context) async {
    // 清空之前发现的设备
    discoveredDevices.clear();

    // 检查蓝牙是否已打开
    BluetoothAdapterState state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请打开蓝牙')),
      );
      return;
    }

    // 如果已连接，返回
    if (isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已有设备连接')),
      );
      return;
    }

    // 如果正在扫描，返回
    if (isScanning) {
      return;
    }

    // 设置扫描状态
    isScanning = true;

    // 显示扫描中的提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在扫描设备...')),
    );

    // 开始扫描
    try {
      // 扫描10秒
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // 处理扫描结果
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.name.contains('TingJian BLE')) {
            // 找到目标设备
            if (!discoveredDevices.contains(result.device)) {
              discoveredDevices.add(result.device);
              // 自动连接到第一个找到的目标设备
              connectToDevice(context, result.device);
              break;
            }
          }
        }
      });

      // 扫描完成后更新状态
      await Future.delayed(const Duration(seconds: 10));
      isScanning = false;

      // 如果未找到设备
      if (discoveredDevices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到听见BLE设备')),
        );
      }
    } catch (e) {
      isScanning = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描出错: $e')),
      );
    }
  }

  // 连接到设备
  Future<void> connectToDevice(
      BuildContext context, BluetoothDevice device) async {
    try {
      // 停止扫描
      await FlutterBluePlus.stopScan();

      // 显示连接提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在连接到 ${device.name}...')),
      );

      // 连接到设备
      await device.connect(autoConnect: false).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception("连接超时");
        },
      );

      // 更新连接状态
      isConnected = true;
      connectedDevice = device;

      // 显示连接成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已连接到 ${device.name}')),
      );

      // 播放TTS提示
      await TTS_speakText('已连接到蓝牙设备');

      // 获取设备的服务
      List<BluetoothService> services = await device.discoverServices();

      // 寻找目标服务和特征
      for (BluetoothService service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() == CHARACTERISTIC_UUID) {
              notifyCharacteristic = characteristic;

              // 开启通知
              await characteristic.setNotifyValue(true);

              // 监听特征值变化
              characteristic.value.listen((value) {
                if (value.isNotEmpty) {
                  // 将字节数组转换为字符串
                  String message = String.fromCharCodes(value);
                  print('蓝牙收到消息: $message');

                  // 检查消息是否包含关键词，而不是完全匹配
                  if (message.contains("AAA")) {
                    print('识别到按钮按下消息，触发解读功能');
                    // 如果设置了按钮按下回调，则触发
                    if (onButtonPressed != null) {
                      onButtonPressed!();
                    }
                  }
                }
              });

              break;
            }
          }
          break;
        }
      }
    } catch (e) {
      isConnected = false;
      connectedDevice = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接失败: $e')),
      );
      await TTS_speakText('蓝牙连接失败');
    }
  }

  // 断开连接
  Future<void> disconnect() async {
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
        isConnected = false;
        connectedDevice = null;
        notifyCharacteristic = null;
      } catch (e) {
        print('断开连接出错: $e');
      }
    }
  }

  // 设置按钮按下回调
  void setOnButtonPressedCallback(VoidCallback callback) {
    onButtonPressed = callback;
  }

  // 播放TTS提示
  Future<void> TTS_speakText(String text) async {
    // 使用main.dart中导入的全局TTS服务播放提示
    try {
      await tts.TTS_speakText(text);
    } catch (e) {
      print('TTS播放失败: $e');
    }
  }

  // 释放资源
  void dispose() {
    disconnect();
  }
}
