/// A single emoji category containing a label and a list of emoji strings.
class EmojiCategory {
  final String label;
  final List<String> emojis;

  const EmojiCategory({required this.label, required this.emojis});
}
