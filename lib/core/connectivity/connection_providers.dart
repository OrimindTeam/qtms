/// مزوّد حالة الاتصال — ★ **مصدرٌ واحد يقرأ منه الشريط العلوي في كل شاشة.**
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_status.dart';

/// مراقب الاتصال — ⛔ **يُحقَن في الجذر**.
final Provider<ConnectionMonitor> connectionMonitorProvider =
    Provider<ConnectionMonitor>((Ref ref) {
  throw UnimplementedError('connectionMonitorProvider يجب تجاوزه عند الجذر');
});

/// ★★ الحالة الحيّة — ⛔ **والخطأ يُقرأ انقطاعاً لا يُبتلَع.**
///
/// ⚠️ **ولماذا الخطأ = انقطاع هنا بالذات:** ★ **فشلُ المُصغي نفسِه أقربُ ما
/// يكون إلى تعذّر بلوغ الخادم** — ⟵ **ووسمُه «متصل» يُعيد الادّعاء الذي
/// وُجد هذا المؤشّر لمنعه**، ⛔ **بينما «غير متصل» أسوأ ما يقوله أنه متحفّظ.**
final Provider<ConnectionStatus> connectionStatusProvider =
    Provider<ConnectionStatus>((Ref ref) {
  final AsyncValue<ConnectionStatus> value =
      ref.watch(connectionStatusStreamProvider);
  if (value.hasError) return ConnectionStatus.offline;
  return value.value ?? ConnectionStatus.unknown;
});

/// البثّ الخام — ★ **مفصولٌ ليُختبَر وحده.**
final StreamProvider<ConnectionStatus> connectionStatusStreamProvider =
    StreamProvider<ConnectionStatus>(
  (Ref ref) => ref.watch(connectionMonitorProvider).watch(),
);
