/// بوابة الكتابة — `FR-SYS-14`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/write_gate/write_gate.dart';

void main() {
  group('WriteGate — FR-SYS-14', () {
    test('البداية مفتوحة', () {
      expect(WriteGate.open.allowsWrite, isTrue);
    });

    test('⛔ انقطاع الاتصال يُغلق الحفظ فعلياً لا تحذيراً', () {
      final WriteGate gate = WriteGate.open.onConnectionLost();
      expect(gate.status, WriteGateStatus.blockedOffline);
      expect(gate.allowsWrite, isFalse);
    });

    test('★★ وعودة الاتصال وحدها لا تفتح البوابة — هذا هو نصّ FR-SYS-14', () {
      final WriteGate gate =
          WriteGate.open.onConnectionLost().onConnectionRestored();
      expect(gate.status, WriteGateStatus.blockedAwaitingRefresh);
      expect(gate.allowsWrite, isFalse);
    });

    test('★ ولا تُفتَح إلا بعد إعادة القراءة فعلاً', () {
      final WriteGate gate = WriteGate.open
          .onConnectionLost()
          .onConnectionRestored()
          .onDataRefreshed();
      expect(gate.allowsWrite, isTrue);
    });

    test('⛔ وإعادة القراءة أثناء الانقطاع لا تفتح شيئاً', () {
      final WriteGate gate = WriteGate.open.onConnectionLost().onDataRefreshed();
      expect(gate.status, WriteGateStatus.blockedOffline);
      expect(gate.allowsWrite, isFalse);
    });
  });
}
