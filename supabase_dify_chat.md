Slug: chat
Endpoint URL: https://tcftpcvcldfudzxgemdh.supabase.co/functions/v1/chat

Invoke function:
``` dart
final res = await supabase.functions.invoke('chat', body: {'name': 'Functions'});
final data = res.data;
```

在线官方文档：
https://supabase.com/docs/reference/dart/upgrade-guide