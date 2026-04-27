/// 从 Supabase Storage 公开 URL 解析 object path，以及为头像 URL 追加缓存破坏参数。
class StorageAvatarUtils {
  StorageAvatarUtils._();

  /// 例如 path 含 `/storage/v1/object/public/user-avatars/<userId>/file.jpg`
  static String? objectPathFromPublicUrl(String url, String bucket) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final path = uri.path;
    final marker = '/object/public/$bucket/';
    final i = path.indexOf(marker);
    if (i == -1) return null;
    var objectPath = path.substring(i + marker.length);
    if (objectPath.isEmpty) return null;
    return Uri.decodeComponent(objectPath);
  }

  /// 去掉已有 query 后追加时间戳，避免固定文件名导致 CDN/客户端缓存旧图。
  static String appendCacheBuster(String publicUrl) {
    final t = DateTime.now().millisecondsSinceEpoch;
    final base = publicUrl.split('?').first;
    return '$base?t=$t';
  }
}
