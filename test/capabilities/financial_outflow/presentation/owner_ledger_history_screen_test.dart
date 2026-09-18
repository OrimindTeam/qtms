/// سجل ضمار المالك للأيام السابقة — `WU-016` · `FR-M15-14` (`AM-023`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** ① **تسمياتُ الشرائح بأرقامٍ لاتينية**
/// (`AM-003` · `ui-guidelines.md` §6) · ② **وصفُّ «الصافي النهائي» مميَّزٌ
/// بصرياً** بأسلوب البطاقة الأمّ (`design-system.md` §6-د) · ③ **والبندُ
/// المحكومُ بصلاحيةٍ يخرج من كل صفٍّ هنا كما يخرج من البطاقة** (`E-29`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/financial_outflow/application/owner_ledger_providers.dart';
import 'package:qtms/capabilities/financial_outflow/presentation/owner_ledger_history_screen.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/key_value_row.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_owner_ledger.dart';

final CalendarDay fixedDay = CalendarDay(2026, 8, 20);
const String radaa = 'SRC-001';

late FakeOwnerLedgerDirectory ledger;
late FakeMasterDataDirectory masterData;

const Set<Permission> fullPermissions = <Permission>{
  Permission.ownerLedgerView,
  Permission.withdrawalView,
  Permission.expenseView,
};

OwnerLedgerSummary summaryOf(CalendarDay date) => computeOwnerLedgerSummary(
      sourceId: radaa,
      date: date,
      contributions: const OwnerLedgerContributions(
        credit: Money(518100),
        cash: Money(27450),
        settledOfDay: Money(149500),
        discounts: Money(5000),
        tax: Money(8125),
        withdrawals: Money(20000),
        expenses: Money(5000),
      ),
    );

Future<void> pumpHistory(
  WidgetTester tester, {
  String? sourceId = radaa,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cards.emitCard('U-001', testCard(permissions: fullPermissions));

  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userCardRepositoryProvider.overrideWithValue(cards),
        masterDataDirectoryProvider.overrideWithValue(masterData),
        masterDataAdminProvider.overrideWithValue(FakeMasterDataAdmin()),
        contactPickerProvider.overrideWithValue(null),
        ownerLedgerDirectoryProvider.overrideWithValue(ledger),
        ownerLedgerDayProvider.overrideWith(_FixedDay.new),
        ownerLedgerSourceProvider.overrideWith(() => _FixedSource(sourceId)),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: OwnerLedgerHistoryScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

class _FixedDay extends OwnerLedgerDay {
  @override
  CalendarDay build() => fixedDay;
}

class _FixedSource extends OwnerLedgerSource {
  _FixedSource(this.initial);

  final String? initial;

  @override
  String? build() => initial;
}

void main() {
  setUp(() {
    ledger = FakeOwnerLedgerDirectory();
    masterData = FakeMasterDataDirectory()
      ..emitSources(<SourceCard>[
        const SourceCard(
          sourceId: radaa,
          name: 'رداع',
          requiresSupplierOnIntake: false,
          isActive: true,
        ),
      ]);
  });

  group('⛔⛔★★★ AM-023 ④ — أرقامٌ لاتينية في تسميات الشرائح', () {
    testWidgets('الثلاثةُ بأرقامٍ لاتينية — ⛔ ولا رقمَ عربيٍّ-هنديّ',
        (WidgetTester tester) async {
      await pumpHistory(tester);
      expect(find.text('آخر 7 أيام'), findsOneWidget);
      expect(find.text('آخر 30 يوماً'), findsOneWidget);
      expect(find.text('آخر 90 يوماً'), findsOneWidget);
    });

    test('★ والتسمياتُ في النوع نفسِه — مصدرٌ واحدٌ يقرؤه الشريطُ والاختبار',
        () {
      expect(
        OwnerLedgerHistorySpan.values.map(
          (OwnerLedgerHistorySpan span) => span.label,
        ),
        <String>['آخر 7 أيام', 'آخر 30 يوماً', 'آخر 90 يوماً'],
      );
    });
  });

  group('★★ AM-023 ④ — صفُّ «الصافي النهائي» مميَّزٌ بصرياً', () {
    testWidgets('يحمل `emphasis` وحدَه دون بقية صفوف البطاقة',
        (WidgetTester tester) async {
      ledger.emitRange(radaa, <OwnerLedgerSummary>[summaryOf(fixedDay)]);
      await pumpHistory(tester);
      await tester.pumpAndSettle();

      final Iterable<QtmsKeyValueRow> rows =
          tester.widgetList<QtmsKeyValueRow>(find.byType(QtmsKeyValueRow));
      expect(rows, isNotEmpty);
      for (final QtmsKeyValueRow row in rows) {
        expect(
          row.emphasis,
          row.label == 'الصافي النهائي',
          reason: row.label,
        );
      }
    });

    testWidgets('★ وتسميتُه بلون `primary.ink` لا `textSecondary`',
        (WidgetTester tester) async {
      ledger.emitRange(radaa, <OwnerLedgerSummary>[summaryOf(fixedDay)]);
      await pumpHistory(tester);
      await tester.pumpAndSettle();

      final Text label = tester.widget<Text>(find.text('الصافي النهائي'));
      expect(label.style!.color, SemanticTriads.primary.ink);
      expect(label.style!.fontSize, TypeScale.titleSm.fontSize);
    });
  });

  group('⛔ AM-023 — وبلا مصدرٍ لا سجلّ — IQ-024 · DEBT-40', () {
    testWidgets('حالةٌ فارغةٌ تقول أين يُختار المصدر',
        (WidgetTester tester) async {
      await pumpHistory(tester, sourceId: null);
      expect(find.text('اختر مصدراً أولاً'), findsOneWidget);
    });
  });
}
