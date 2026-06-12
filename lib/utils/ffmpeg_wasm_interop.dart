import 'dart:js_interop';
import 'dart:typed_data';

/// FFmpeg.wasm JavaScript 互操作桥接
///
/// 通过 `web/ffmpeg_wasm.js` 暴露的全局函数与 ffmpeg.wasm 通信。
@JS('ffmpegWasmLoad')
external JSPromise _ffmpegWasmLoad();

@JS('ffmpegWasmIsLoaded')
external JSBoolean _ffmpegWasmIsLoaded();

@JS('ffmpegWasmWriteFile')
external JSPromise _ffmpegWasmWriteFile(
  JSString fileName,
  JSArray<JSNumber> data,
);

@JS('ffmpegWasmExec')
external JSPromise _ffmpegWasmExec(JSArray<JSString> args);

@JS('ffmpegWasmReadFile')
external JSPromise _ffmpegWasmReadFile(JSString fileName);

@JS('ffmpegWasmDeleteFile')
external JSPromise _ffmpegWasmDeleteFile(JSString fileName);

@JS('ffmpegWasmOnProgress')
external void _ffmpegWasmOnProgress(JSFunction? callback);

@JS('ffmpegWasmOnLog')
external void _ffmpegWasmOnLog(JSFunction? callback);

@JS('ffmpegWasmTerminate')
external void _ffmpegWasmTerminate();

/// 加载 ffmpeg-core WASM（约 31MB，从 CDN 下载）
Future<bool> ffmpegWasmLoad() async {
  final result = await _ffmpegWasmLoad().toDart;
  return result.dartify() as bool;
}

/// 检查 ffmpeg.wasm 是否已加载
bool ffmpegWasmIsLoaded() {
  return _ffmpegWasmIsLoaded().toDart;
}

/// 写入输入文件到 ffmpeg.wasm 虚拟文件系统
Future<bool> ffmpegWasmWriteFile(String fileName, Uint8List data) async {
  final jsArray = data.map((b) => b.toJS).toList().toJS;
  final result = await _ffmpegWasmWriteFile(fileName.toJS, jsArray).toDart;
  return result.dartify() as bool;
}

/// 执行 ffmpeg 命令
///
/// 返回退出码（0 表示成功）
Future<int> ffmpegWasmExec(List<String> args) async {
  final jsArgs = args.map((a) => a.toJS).toList().toJS;
  final result = await _ffmpegWasmExec(jsArgs).toDart;
  return result.dartify() as int;
}

/// 从 ffmpeg.wasm 虚拟文件系统读取输出文件
Future<Uint8List> ffmpegWasmReadFile(String fileName) async {
  final result = await _ffmpegWasmReadFile(fileName.toJS).toDart;
  final list = result.dartify() as List<int>;
  return Uint8List.fromList(list);
}

/// 从虚拟文件系统删除文件
Future<bool> ffmpegWasmDeleteFile(String fileName) async {
  final result = await _ffmpegWasmDeleteFile(fileName.toJS).toDart;
  return result.dartify() as bool;
}

/// 设置进度回调
///
/// [callback] 接收两个参数：progress (0.0-1.0) 和 time (微秒)
void ffmpegWasmOnProgress(void Function(double progress, int time)? callback) {
  if (callback == null) {
    _ffmpegWasmOnProgress(null);
    return;
  }
  _ffmpegWasmOnProgress((JSNumber progress, JSNumber time) {
    callback(progress.toDartDouble, time.toDartInt);
  }.toJS);
}

/// 设置日志回调
void ffmpegWasmOnLog(void Function(String message)? callback) {
  if (callback == null) {
    _ffmpegWasmOnLog(null);
    return;
  }
  _ffmpegWasmOnLog((JSString message) {
    callback(message.toDart);
  }.toJS);
}

/// 清理 ffmpeg.wasm 资源
void ffmpegWasmTerminate() {
  _ffmpegWasmTerminate();
}
