/// مزوّد بوابة الكتابة — **حالة تطبيق** (`ADR-0010`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'write_gate.dart';

/// متحكّم البوابة.
final NotifierProvider<WriteGateController, WriteGate> writeGateProvider =
    NotifierProvider<WriteGateController, WriteGate>(WriteGateController.new);

/// يُبدِّل حالة البوابة بأحداث الاتصال وإعادة القراءة.
class WriteGateController extends Notifier<WriteGate> {
  @override
  WriteGate build() => WriteGate.open;

  void connectionLost() => state = state.onConnectionLost();
  void connectionRestored() => state = state.onConnectionRestored();
  void dataRefreshed() => state = state.onDataRefreshed();
}
