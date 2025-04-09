import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
//import 'package:myeyes/amap_initializer.dart';

class PrivacyPolicyDialog extends StatelessWidget {
  final Function(bool) onAgreed;

  const PrivacyPolicyDialog({
    Key? key,
    required this.onAgreed,
  }) : super(key: key);

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
      // 可以在这里添加用户提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('无法打开链接: $urlString',
                style: TextStyle(color: Colors.black))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('隐私政策', style: TextStyle(color: Colors.black)),
      content: SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              '本应用使用高德开放平台位置服务SDK，需要收集：\n'
              '1. 位置信息：用于导航和定位服务\n'
              '2. 设备信息：用于地图服务性能优化\n'
              '3. 网络状态：用于在线地图和路径规划\n\n'
              '您可以查看完整的隐私政策和高德地图隐私权政策了解详情。\n\n'
              '继续使用表示您同意我们的隐私政策。',
              style: TextStyle(fontSize: 14, color: Colors.black),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => _launchURL(context,
                      'https://github.com/ProgramerZJH/MyEyesPrivacy/blob/main/privacy_policy.md'),
                  child: const Text('听见视界隐私政策',
                      style: TextStyle(color: Colors.black)),
                ),
                TextButton(
                  onPressed: () => _launchURL(
                      context, 'https://lbs.amap.com/pages/privacy/'),
                  child: const Text('高德隐私政策',
                      style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('同意', style: TextStyle(color: Colors.black)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('不同意', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }
}
