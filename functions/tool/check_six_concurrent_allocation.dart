/// ★ الفحص ⑥ من «الخطوة صفر» — **على قاعدة بيانات حقيقية**.
///
/// `product-roadmap.md` §0: «**توليد رقمين متزامنين لجونيتين ينجح بلا
/// تكرار**» (`E-43`).
///
/// ⚠️ **ولماذا ليس اختبار وحدة:** التكرار عند التزامن **لا يقع في المنطق بل
/// في المعاملة** — ومحاكاته بمضاعِف تُثبت أن المحاكي يعمل، لا أن قاعدة
/// البيانات تمنع التصادم. `test-strategy.md` §2 يضع هذا في طبقة **التكامل**.
///
/// **التشغيل:**
/// ```bash
/// cd functions
/// GOOGLE_CLOUD_PROJECT=<المشروع التجريبي> dart run tool/check_six_concurrent_allocation.dart
/// ```
/// ⛔ **ولا يُشغَّل على الإنتاج إطلاقاً** — يكتب في عدّادات حقيقية.
library;

import 'dart:io';

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/counter_allocator.dart';
import 'package:qtms_functions/src/firestore_writer.dart';

/// عدد التخصيصات المتزامنة.
const int _concurrency = 12;

Future<void> main() async {
  final String? projectId = Platform.environment['GOOGLE_CLOUD_PROJECT'];
  if (projectId == null || projectId.isEmpty) {
    stderr.writeln('⛔ GOOGLE_CLOUD_PROJECT غير مضبوط');
    exitCode = 2;
    return;
  }
  if (projectId.endsWith('-c001')) {
    stderr.writeln('⛔ هذا مشروع الإنتاج — الفحص للتجريبية وحدها');
    exitCode = 2;
    return;
  }

  final FirestoreWriter writer =
      await FirestoreWriter.connect(projectId: projectId);
  final CounterAllocator allocator = CounterAllocator(
    projectId: projectId,
    api: writer.api,
  );

  // يوم مميَّز لكل تشغيل حتى لا يُخلَط بعدّاد تشغيل سابق.
  final DateTime now = DateTime.now().toUtc();
  final CalendarDay day = CalendarDay.fromUtc(now);
  final String sourceId = 'SRC-CHECK6-${now.millisecondsSinceEpoch}';

  stdout.writeln('المشروع : $projectId');
  stdout.writeln('العدّاد : ${dailySackCounterId(sourceId: sourceId, day: day)}');
  stdout.writeln('التزامن : $_concurrency تخصيصاً في آنٍ واحد\n');

  // ★ تُطلَق كلها معاً بلا انتظار بينها — وهذا هو جوهر الفحص.
  final List<AllocatedSequence> results = await Future.wait<AllocatedSequence>(
    List<Future<AllocatedSequence>>.generate(
      _concurrency,
      (_) => allocator.allocateDailySackSequence(
        sourceId: sourceId,
        day: day,
      ),
    ),
  );

  final List<int> issued = results.map((AllocatedSequence r) => r.sequence).toList()
    ..sort();
  final Set<int> unique = issued.toSet();

  stdout.writeln('الأرقام المُسلَّمة: $issued');

  final bool noDuplicates = unique.length == issued.length;
  final bool startsAtOne = issued.first == 1;
  final bool contiguous = issued.last == _concurrency;

  stdout.writeln('');
  stdout.writeln('لا تكرار      : ${noDuplicates ? "✅" : "⛔"}');
  stdout.writeln('يبدأ من ١     : ${startsAtOne ? "✅" : "⛔"}');
  stdout.writeln('متتابع بلا فجوة: ${contiguous ? "✅" : "⛔"}');

  if (noDuplicates && startsAtOne && contiguous) {
    stdout.writeln('\n✅ الفحص ⑥ نجح — $_concurrency تخصيصاً متزامناً بلا تكرار');
  } else {
    stderr.writeln('\n⛔ الفحص ⑥ فشل');
    exitCode = 1;
  }
}
