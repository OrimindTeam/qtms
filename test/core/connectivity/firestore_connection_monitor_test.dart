/// ★★★ **مراقبُ الاتصال — منطقُ التبديل والتحفّظ** — `AM-008` ① · `ADR-0003`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا وُجد هذا الملف — `DEBT-83` مقيسٌ لا مفترَض:**
/// ★ **طبقةُ الاتصال لم تكن مُختبَرةً قطّ** — ⟵ **وهو ثالثَ عشرَ أوجهِ
/// `DEBT-37`.** ★ **والعطلُ الذي كشفه المحاكي (2026-09-02):** **تسجيلُ
/// الخروج يُفشِل مُصغيَ `users/{uid}` بـ`PERMISSION_DENIED`** ⟹ ⛔⛔ **فيموت
/// البثُّ الخارجي ويبقى المؤشّر «غير متصل» إلى آخر عمر العملية** — ★ **ولو
/// عاد المستخدم ودخل والبياناتُ تُقرأ من الخادم فعلاً.**
///
/// ⛔ **ولا يُختبَر هنا `Firestore` نفسُه** — ★ **تلك قناةُ منصّةٍ تُقاس
/// حيّاً** (البروتوكول §د): ★ **يُختبَر ما يملكه هذا الملف — التبديلُ عند
/// تبدّل الهوية، و`distinct`، وقراءةُ الفشل انقطاعاً بلا موتٍ.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/connectivity/connection_status.dart';
import 'package:qtms/core/connectivity/firestore_connection_monitor.dart';

void main() {
  test('⛔ بلا جلسةٍ لا قياس ⟵ unknown', () async {
    final List<ConnectionStatus> seen = await watchProbes(
      userIds: Stream<String?>.fromIterable(<String?>[null, '']),
      probe: (_) => const Stream<ConnectionStatus>.empty(),
    ).toList();

    // ★ **والمعرّفُ الفارغ والمعدومُ حالتان مختلفتان لـ`distinct`** —
    //   ⛔ **وكلتاهما «لا قياس»** ★ **وهو المطلوب.**
    expect(seen, <ConnectionStatus>[
      ConnectionStatus.unknown,
      ConnectionStatus.unknown,
    ]);
  });

  test('✅ بثُّ الخادم ⟵ online، ومن الذاكرة ⟵ offline', () async {
    final List<ConnectionStatus> seen = await watchProbes(
      userIds: Stream<String?>.value('u1'),
      probe: (_) => Stream<ConnectionStatus>.fromIterable(
        <ConnectionStatus>[ConnectionStatus.offline, ConnectionStatus.online],
      ),
    ).toList();

    expect(seen, <ConnectionStatus>[
      ConnectionStatus.offline,
      ConnectionStatus.online,
    ]);
  });

  test('⛔⛔ `distinct`: المعرّفُ نفسُه مرتين ⟵ مُصغٍ واحد', () async {
    int builds = 0;
    await watchProbes(
      userIds: Stream<String?>.fromIterable(<String?>['u1', 'u1', 'u1']),
      probe: (_) {
        builds++;
        return Stream<ConnectionStatus>.value(ConnectionStatus.online);
      },
    ).toList();

    expect(builds, 1);
  });

  test(
    '⛔⛔★★★ `DEBT-83`: فشلُ المُصغي يُقرأ انقطاعاً ⛔ ولا يقتل المراقب',
    () async {
      // ★ **هذا حرفياً تسلسلُ المحاكي:** دخولٌ ⟵ خروجٌ (فشلُ الصلاحية) ⟵ دخول.
      final StreamController<String?> userIds = StreamController<String?>();
      addTearDown(userIds.close);

      final List<ConnectionStatus> seen = <ConnectionStatus>[];
      final StreamSubscription<ConnectionStatus> sub = watchProbes(
        userIds: userIds.stream,
        probe: (String userId) => userId == 'gone'
            ? Stream<ConnectionStatus>.error(
                StateError('PERMISSION_DENIED'),
              )
            : Stream<ConnectionStatus>.value(ConnectionStatus.online),
      ).listen(seen.add);
      addTearDown(sub.cancel);

      userIds.add('u1');
      await pumpEventQueue();
      userIds.add('gone');
      await pumpEventQueue();
      // ★★★ **وهذه هي النقطة:** ⟵ **بعد الفشل يبقى المراقب حيّاً**،
      //    ⛔ **وقبل العلاج كان هذا الحدثُ لا يصل إطلاقاً.**
      userIds.add('u2');
      await pumpEventQueue();

      expect(seen, <ConnectionStatus>[
        ConnectionStatus.online,
        ConnectionStatus.offline,
        ConnectionStatus.online,
      ]);
    },
  );
}
