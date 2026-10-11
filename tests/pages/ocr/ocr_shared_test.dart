import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:stroom/pages/ocr/ocr_shared.dart';
import 'package:stroom/utils/ocr_image_payload.dart';

void main() {
  test('edited bytes refresh format and retain the source filename', () {
    final sourceBytes = img.encodeJpg(img.Image(width: 2, height: 2));
    final editedBytes = img.encodePng(img.Image(width: 3, height: 2));
    final original = SelectedImage(
      bytes: sourceBytes,
      format: 'jpeg',
      sourceName: 'receipt.jpg',
    );

    final edited = original.withEditedPayload(
      prepareOcrImagePayloadSync(editedBytes),
    );

    expect(edited.format, 'png');
    expect(edited.bytes, editedBytes);
    expect(edited.sourceName, 'receipt.jpg');
  });
}
