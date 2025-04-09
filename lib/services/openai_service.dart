import 'package:openai_dart/openai_dart.dart';

class OpenAIService {
  final OpenAIClient _client;

  OpenAIService()
      : _client = OpenAIClient(
          apiKey: 'sk-9608d82aba824991a36c629aef67cc87',
          baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        );

  Future<String> analyzeImage(String base64Image) async {
    try {
      final res = await _client.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: const ChatCompletionModel.modelId("qwen-vl-plus"),
          messages: [
            const ChatCompletionMessage.system(
              content: "你是一个专业的视觉辅助助手，根据图片内容为视障人士提供帮助",
            ),
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.parts([
                ChatCompletionMessageContentPart.text(
                  text: "请用中文详细描述这张图片的内容，尽可能完整地提供以下信息："
                      "1. 场景概述和主要物体\n"
                      "2. 场景中的文字内容（如果有）\n"
                      "3. 可能存在的危险或障碍物\n"
                      "4. 适合盲人理解的空间关系描述",
                ),
                ChatCompletionMessageContentPart.image(
                  imageUrl: ChatCompletionMessageImageUrl(
                    url: "data:image/jpeg;base64,$base64Image",
                  ),
                ),
              ]),
            ),
          ],
          temperature: 0.2,
          maxTokens: 2000,
        ),
      );
      return res.choices.first.message.content ?? "未获取到描述内容";
    } catch (e) {
      print("图片分析失败: $e");
      return "图片分析失败，请稍后再试";
    }
  }

  Future<String> analyzeImageWithQuestion(
      String base64Image, String userQuestion) async {
    try {
      final res = await _client.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: const ChatCompletionModel.modelId("qwen-vl-plus"),
          messages: [
            const ChatCompletionMessage.system(
              content: "你是一个专业的视觉辅助助手，帮助视障用户理解图像内容并回答他们的问题",
            ),
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.parts([
                ChatCompletionMessageContentPart.text(
                  text: userQuestion.isNotEmpty
                      ? "基于图片内容，请用中文回答我的问题：$userQuestion"
                      : "请用中文详细描述这张图片的内容，适合盲人理解",
                ),
                ChatCompletionMessageContentPart.image(
                  imageUrl: ChatCompletionMessageImageUrl(
                    url: "data:image/jpeg;base64,$base64Image",
                  ),
                ),
              ]),
            ),
          ],
          temperature: 0.3,
          maxTokens: 2000,
        ),
      );
      return res.choices.first.message.content ?? "未获取到回答内容";
    } catch (e) {
      print("图片分析及问答失败: $e");
      return "处理失败，请稍后再试";
    }
  }
}
