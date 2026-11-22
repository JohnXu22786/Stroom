import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/catcatch/engine/task_progress_path.dart';

void main() {
  test('encodes unsafe task IDs without changing safe legacy filenames', () {
    expect(taskProgressFileName('legacy.task'), 'legacy.task_dl_progress.json');
    expect(taskProgressFileName('旧任务'), '旧任务_dl_progress.json');

    final traversalFileName = taskProgressFileName('../../outside');
    expect(p.basename(traversalFileName), traversalFileName);
    expect(p.isAbsolute(traversalFileName), isFalse);

    expect(taskProgressFileName('a/b'), isNot(taskProgressFileName('a%2Fb')));
    expect(
      taskProgressFileName('\u0000/').toLowerCase(),
      isNot(taskProgressFileName('h/').toLowerCase()),
    );
  });
}
