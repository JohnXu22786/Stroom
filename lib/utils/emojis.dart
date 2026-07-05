import 'emoji_category.dart';
part 'emoji_category_data_core.dart';
part 'emoji_category_data_extra.dart';
part 'emoji_category_data_rest_a.dart';
part 'emoji_category_data_rest_b.dart';

/// Categorized emoji collection organized by standard Unicode groups.
class EmojiCategories {
  EmojiCategories._();

  static const List<EmojiCategory> categories = [
    ..._coreCategories,
    ..._extraCategories,
    ..._restACategories,
    ..._restBCategories,
  ];
}
