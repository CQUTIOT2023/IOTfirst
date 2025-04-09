import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

class InstructionsPrivacyPage extends StatelessWidget {
  const InstructionsPrivacyPage({Key? key}) : super(key: key);

  Future<void> _launchURL(BuildContext context, String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launcher.launchUrl(
        url,
        mode: launcher.LaunchMode.externalApplication,
      )) {
        throw Exception('Could not launch $urlString');
      }
    } catch (e) {
      print('Error launching URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接: $urlString')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("使用说明及隐私合规"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 使用说明部分
            const Text(
              "使用说明",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. 主界面：点击"open my eyes"按钮连接连接到眼镜设备后，开始获取实时环境图像以及雷达距离矩阵。\n\n'
              '2. 地图功能：点击"地图与位置信息"按钮进入导航界面，可获知当前位置信息，搜索目的地并获取步行路线。\n\n'
              '3. 紧急援助：点击"紧急援助(SOS)"按钮可快速拨打110、120或119电话。\n\n'
              '4. 天气查询：点击天气信息区域可查看详细天气预报。\n\n'
              '5. 语音播报：应用会自动播报摄像头yolov5检测到的障碍物和重要信息，以及激光雷达检测到的近距离障碍物。\n\n'
              '6. 智能识图：连接蓝牙或点击首页"解读"按钮可对拍摄画面进行预设或自定义解读。',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),

            // 隐私合规部分
            const Text(
              "隐私合规",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "本应用使用高德开放平台位置服务SDK，需要收集：\n\n"
              "1. 位置信息：用于导航和定位服务\n"
              "2. 设备信息：用于地图服务性能优化\n"
              "3. 网络状态：用于在线地图和路径规划\n\n"
              "我们承诺：\n"
              "• 仅收集必要的信息\n"
              "• 不会将您的信息用于与服务无关的目的\n"
              "• 实时环境图像不会被保存或上传\n"
              "• 您可以随时在系统设置中管理权限\n\n"
              "详细内容请参阅我们的完整隐私政策。",
              style: TextStyle(fontSize: 16),
            ),

            // 添加隐私政策链接
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "查看完整隐私政策",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            onPressed: () => _launchURL(context,
                                'https://github.com/ProgramerZJH/MyEyesPrivacy/blob/main/privacy_policy.md'),
                            child: const Text(
                              '听见视界\n隐私政策',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                            onPressed: () => _launchURL(
                                context, 'https://lbs.amap.com/pages/privacy/'),
                            child: const Text(
                              '高德\n隐私政策',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
