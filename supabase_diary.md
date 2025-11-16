supabase edge function name: diary 
URL: https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/diary

## 请求格式

### Dify Workflow API 格式

宠物日记使用 Dify 的 Workflow API，需要将参数放在 `inputs` 对象中：

**流式模式 (Streaming)**:
```json
{
  "inputs": {
    "query": "今天，我带我的宠物狗狗十六去逍遥津的大草坪玩飞盘。小妮带着她的宠物狗狗朱朱一起。十六跑得比朱朱快。十六和朱朱都玩得很开心，我奖励它们吃苹果狗粮。",
    "style": "小红书"
  },
  "response_mode": "streaming",
  "user": "supabase-test"
}
```

**阻塞模式 (Blocking)**:
```json
{
  "inputs": {
    "query": "今天，我带我的宠物狗狗十六去逍遥津的大草坪玩飞盘。小妮带着她的宠物狗狗朱朱一起。十六跑得比朱朱快。十六和朱朱都玩得很开心，我奖励它们吃苹果狗粮。",
    "style": "小红书"
  },
  "response_mode": "blocking",
  "user": "supabase-test"
}
```

### 支持的风格 (style)
- `哲学` - 哲学思考风格
- `搞笑` - 幽默搞笑风格
- `治愈` - 温馨治愈风格
- `中二` - 中二少年风格
- `小红书` - 小红书风格

## Flutter 调用示例

```dart
// 流式调用
final diaryService = PetDiaryEdgeService();
final stream = diaryService.generatePetDiary(
  query: '今天去公园玩了',
  style: '小红书',
  userId: 'flutter_user_123',
);

await for (final event in stream) {
  if (event is DiaryContentEvent) {
    print('收到内容: ${event.fullText}');
  } else if (event is DiaryDoneEvent) {
    print('生成完成: ${event.finalText}');
  } else if (event is DiaryErrorEvent) {
    print('错误: ${event.error}');
  }
}

// 阻塞调用
final result = await diaryService.generatePetDiaryBlocking(
  query: '今天去公园玩了',
  style: '小红书',
  userId: 'flutter_user_123',
);
print('生成结果: $result');
```