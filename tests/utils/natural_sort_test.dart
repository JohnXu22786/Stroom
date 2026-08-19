import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/utils/natural_sort.dart';
import 'package:stroom/utils/sort_config.dart';

void main() {
  group('compareNatural — 数字感知的自然排序', () {
    test('点分数字按数值比较而非字典序（用户案例）', () {
      // 字典序会错误地得出 25.12.6 < 25.2.6、25.3.30 < 25.3.9
      expect(compareNatural('25.2.6', '25.12.6'), lessThan(0));
      expect(compareNatural('25.3.9', '25.3.30'), lessThan(0));
      expect(compareNatural('25.12.6', '25.2.6'), greaterThan(0));
      expect(compareNatural('25.3.30', '25.3.9'), greaterThan(0));
    });

    test('数字后缀：file2 排在 file10 之前', () {
      expect(compareNatural('file2', 'file10'), lessThan(0));
      expect(compareNatural('file10', 'file2'), greaterThan(0));
      expect(compareNatural('img1', 'img9'), lessThan(0));
      expect(compareNatural('img9', 'img10'), lessThan(0));
    });

    test('数值相等时按原文（含前导零）兜底，保证总序稳定', () {
      // 1 与 01 数值相等 → 原文比较 "01" < "1"
      expect(compareNatural('a01', 'a1'), lessThan(0));
      // 完全一致返回 0
      expect(compareNatural('25.2.6', '25.2.6'), equals(0));
    });

    test('大小写不敏感，纯大小写差异用原始字符串兜底', () {
      // 自然段全部相等 → 原始字符串比较保证总序确定（大写 < 小写）
      expect(compareNatural('ABC', 'abc'), lessThan(0));
      expect(compareNatural('abc', 'ABC'), greaterThan(0));
      // 数字段已分出大小，不走到大小写兜底
      expect(compareNatural('AbC2', 'abc10'), lessThan(0));
    });

    test('数字与非数字混排按原始码元比较（保持旧字典序行为）', () {
      // ASCII 数字码元 < 字母码元 → 2a 仍在 a2 之前
      expect(compareNatural('2a', 'a2'), lessThan(0));
      // 符号/空格 < 数字码元，与改动前的 compareTo 行为一致
      expect(compareNatural('a-1', 'a12'), lessThan(0));
      expect(compareNatural('file 2', 'file10'), lessThan(0));
      // 数字段与数字段仍按数值比较（含空格前缀的 case）
      expect(compareNatural('file 2', 'file 10'), lessThan(0));
    });

    test('整列表排序结果完整正确（前缀/兜底交互）', () {
      final list = ['25.12.6', '25.3.30', '25.2.6', '25.3.9']
        ..sort(compareNatural);
      expect(list, ['25.2.6', '25.3.9', '25.3.30', '25.12.6']);

      final mixed = ['img10', 'img2', 'img', 'img02']..sort(compareNatural);
      expect(mixed, ['img', 'img02', 'img2', 'img10']);
    });

    test('前缀规则：短串相等部分完成后短的在前', () {
      expect(compareNatural('img', 'img2'), lessThan(0));
      expect(compareNatural('img2', 'img'), greaterThan(0));
    });

    test('空字符串最小', () {
      expect(compareNatural('', 'a'), lessThan(0));
      expect(compareNatural('1', ''), greaterThan(0));
    });

    test('中文名保持原有字典序（不受数字逻辑影响）', () {
      // 与改动前 toLowerCase().compareTo 相同的码元顺序
      expect(compareNatural('照片', '笔记'), lessThan(0));
      expect(compareNatural('笔记', '照片'), greaterThan(0));
    });
  });

  group('compareFileRecords — 共享文件排序比较器', () {
    ImageRecord rec({
      String name = 'n',
      required DateTime created,
      required DateTime modified,
      int size = 0,
    }) =>
        ImageRecord(
          name: name,
          hash: 'h',
          format: 'jpg',
          createdAt: created,
          modifiedAt: modified,
          size: size,
        );

    test('按修改时间排序', () {
      final a = rec(
          name: 'a',
          created: DateTime(2024, 1, 1),
          modified: DateTime(2024, 1, 3));
      final b = rec(
          name: 'b',
          created: DateTime(2024, 1, 2),
          modified: DateTime(2024, 1, 1));
      expect(compareFileRecords(a, b, SortField.modifiedAt), greaterThan(0));
      expect(compareFileRecords(b, a, SortField.modifiedAt), lessThan(0));
    });

    test('按名称走自然排序', () {
      final a = rec(
          name: 'img10',
          created: DateTime(2024, 1, 1),
          modified: DateTime(2024, 1, 1));
      final b = rec(
          name: 'img2',
          created: DateTime(2024, 1, 1),
          modified: DateTime(2024, 1, 1));
      expect(compareFileRecords(a, b, SortField.name), greaterThan(0));
    });

    test('按创建时间与大小排序保持原语义', () {
      final a = rec(
          name: 'a',
          created: DateTime(2024, 1, 1),
          modified: DateTime(2024, 1, 3),
          size: 10);
      final b = rec(
          name: 'b',
          created: DateTime(2024, 1, 2),
          modified: DateTime(2024, 1, 1),
          size: 999);
      expect(compareFileRecords(a, b, SortField.createdAt), lessThan(0));
      expect(compareFileRecords(a, b, SortField.size), lessThan(0));
    });
  });
}
