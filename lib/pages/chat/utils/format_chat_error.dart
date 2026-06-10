/// 格式化聊天错误信息，分类显示友好的提示并保留原始错误
String formatChatErrorMessage(Object error) {
  final errorStr = error.toString();

  if (errorStr.contains('请先配置聊天供应商')) {
    return '错误: 聊天 API 未配置，请先前往设置页面配置';
  }

  if (errorStr.contains('API key not configured')) {
    return '错误: API Key 未配置，请检查设置';
  }

  if (errorStr.contains('无法连接到服务器') ||
      errorStr.contains('连接错误')) {
    return '错误: 无法连接到服务器，请检查网络连接和 API 地址\n$errorStr';
  }

  if (errorStr.contains('SocketException') ||
      errorStr.contains('Connection refused') ||
      errorStr.contains('连接失败')) {
    return '错误: 网络连接失败，请检查网络连接\n$errorStr';
  }

  if (errorStr.contains('timeout') || errorStr.contains('超时')) {
    return '错误: 连接超时，服务器无响应\n$errorStr';
  }

  if (errorStr.contains('HTTP ')) {
    return '错误: $errorStr';
  }

  return '错误: $errorStr';
}
