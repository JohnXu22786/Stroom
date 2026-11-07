import 'dart:convert';
import 'dart:io';

Future<void> append(String path, String line) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final separator = await _needsSeparator(file) ? '\n' : '';
  await file.writeAsString(
    '$separator$line\n',
    mode: FileMode.append,
    flush: true,
  );
}

Future<List<String>?> readLines(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final contents = await file.readAsBytes();
  return utf8.decode(contents, allowMalformed: true).split('\n');
}

Future<bool> delete(String path) async {
  final file = File(path);
  if (!await file.exists()) return true;
  await file.delete();
  return true;
}

Future<bool> _needsSeparator(File file) async {
  if (!await file.exists()) return false;
  final length = await file.length();
  if (length == 0) return false;
  final handle = await file.open();
  try {
    await handle.setPosition(length - 1);
    return await handle.readByte() != 10;
  } finally {
    await handle.close();
  }
}
