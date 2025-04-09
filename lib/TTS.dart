// 导入文字转语音插件，提供TTS（Text-To-Speech）功能
// 支持多平台（iOS/Android）的语音合成
// 可设置语速、音调、音量等参数
// 本项目中使用讯飞语音引擎进行中文语音合成
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  double speed = 0.5;
  //唯一存在的实例变量   ↓↓↓↓↓
  static final TtsService _instance = TtsService._internal();
  FlutterTts flutterTts = FlutterTts();

  static bool Importent = false;
  static bool HighestPriority = false;

  factory TtsService() {
    return _instance;
  }

  TtsService._internal() {
    initTts();
  }

  Future<void> initTts() async {
    await flutterTts.setSpeechRate(speed);
    await flutterTts.setPitch(1);
    await flutterTts.setEngine("com.iflytek.tts");

    flutterTts.setCompletionHandler(() {
      Importent = false;
      print("==新的状态：Importent = ${TtsService.Importent}");
    });
  }

  //------------------播放文本内容(打断式)
  Future<void> TTS_speakText(String text) async {
    if (!Importent && !HighestPriority) {
      await flutterTts.speak(text);
    }
  }

  Future<void> TTS_speakImpText(String text) async {
    if (!HighestPriority && Importent == false) {
      await flutterTts.speak(text);
      Importent = true;
    }
  }

  // 添加最高优先级播报方法（用于图片解读）
  Future<void> TTS_speakHighestPriorityText(String text) async {
    // 停止当前所有播报
    await flutterTts.stop();

    // 设置最高优先级标志
    HighestPriority = true;

    // 播报文本
    await flutterTts.speak(text);

    // 播报完成后释放最高优先级
    HighestPriority = false;
  }

  //-----------------设置速度
  Future<void> TTS_setSpeed(double newSpeed) async {
    speed = newSpeed;
    await flutterTts.setSpeechRate(newSpeed);
  }

  double TTS_getspeed() {
    return speed;
  }
}
