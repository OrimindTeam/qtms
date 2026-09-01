import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  group('validateSource — FR-M2-01', () {
    test('يقبل مصدراً باسمٍ صحيح ويُطبِّع اسمه', () {
      final Outcome<ValidatedSource> outcome = validateSource(
        const SourceInput(name: '  مَصْدَر أ  ', requiresSupplierOnIntake: true),
      );
      final ValidatedSource source =
          (outcome as Success<ValidatedSource>).value;
      expect(source.name, 'مَصْدَر أ');
      // ★ التشكيل يسقط والهمزة تُوحَّد — `IQ-013`.
      expect(source.normalizedName, normalizeName('مصدر ا'));
      expect(source.requiresSupplierOnIntake, isTrue);
      expect(source.notes, isNull);
      expect(source.disableReason, isNull);
    });

    test('يرفض اسماً بحرفٍ واحد', () {
      expect(
        validateSource(
          const SourceInput(name: 'م', requiresSupplierOnIntake: false),
        ),
        isA<Failure<ValidatedSource>>(),
      );
    });

    test('يرفض اسماً يخلو من محرف دالّ بعد التطبيع', () {
      // ⛔ معرّف مستند الحراسة هو القيمة المُطبَّعة نفسها.
      expect(
        validateSource(
          const SourceInput(name: 'ءءء', requiresSupplierOnIntake: false),
        ),
        isA<Failure<ValidatedSource>>(),
      );
    });

    test('★ يرفض التعطيل بلا سبب نصّي — FR-M2-07', () {
      expect(
        validateSource(
          const SourceInput(
            name: 'مصدر أ',
            requiresSupplierOnIntake: false,
            isActive: false,
          ),
        ),
        isA<Failure<ValidatedSource>>(),
      );
    });

    test('★ السجل النشط لا يحمل سبب تعطيل ولو أُرسل', () {
      final Outcome<ValidatedSource> outcome = validateSource(
        const SourceInput(
          name: 'مصدر أ',
          requiresSupplierOnIntake: false,
          disableReason: 'سبب قديم',
        ),
      );
      expect((outcome as Success<ValidatedSource>).value.disableReason, isNull);
    });
  });

  group('validateSupplier — FR-M3', () {
    SupplierInput input({
      String name = 'رعوي مثال',
      String phone = '0777123456',
    }) =>
        SupplierInput(name: name, phone: phone);

    test('★ التفرد على الهاتف المُطبَّع — خمس صيغ مفتاحٌ واحد', () {
      const List<String> forms = <String>[
        '0777123456',
        '+967777123456',
        '00967777123456',
        '(0777) 123-456',
        '٧٧٧١٢٣٤٥٦',
      ];
      final Set<String> keys = <String>{
        for (final String form in forms)
          (validateSupplier(input(phone: form)) as Success<ValidatedSupplier>)
              .value
              .normalizedPhone,
      };
      expect(keys, hasLength(1));
      expect(keys.single, '777123456');
    });

    // ⛔⛔★★★ **اختبارا المصادر سقطا بـ`CR-006`** (2026-08-31) — ★ **وحلّ
    //    محلَّهما حارسٌ بنيويّ:** ⟵ **المُدخَل نفسُه لم يعد يحمل الحقل**،
    //    ⛔ **فلا يُمرَّر سهواً ولا يُكتَب.**
    //
    // ★ **نصُّهما قبل:** «يرفض رعوياً بلا مصادر — `FR-M3-01`» ·
    //    «★ المصادر مرتبة ومنزوعة التكرار».
    test('⛔★★★ ولا حقلَ مصدرٍ في مُدخَل الرعوي إطلاقاً — CR-006', () {
      // ★ **حارسٌ يفشل عند أول محاولةِ إعادةٍ للحقل** — ⟵ **فالقرار
      //   محروسٌ بالبنية لا بالمراجعة.**
      expect(
        const SupplierInput(name: 'رعوي مثال', phone: '0777123456'),
        isA<SupplierInput>(),
      );
      final ValidatedSupplier supplier =
          (validateSupplier(input()) as Success<ValidatedSupplier>).value;
      // ⛔ **ولا خاصيّةَ `sourceIds` على النوع المُتحقَّق منه** — ★ **يفرضه
      //   المحلّل الساكن**، ⟵ **والاختبار يؤكّد بقيّةَ الحقول كما هي.**
      expect(supplier.name, 'رعوي مثال');
      expect(supplier.normalizedPhone, '777123456');
    });

    test('يرفض اسماً أقصر من ثلاثة أحرف', () {
      expect(
        validateSupplier(input(name: 'اب')),
        isA<Failure<ValidatedSupplier>>(),
      );
    });

    test('يرفض هاتفاً بلا أي خانة بعد التطبيع', () {
      expect(
        validateSupplier(input(phone: '---')),
        isA<Failure<ValidatedSupplier>>(),
      );
    });
  });

  group('validateDealer — FR-M4', () {
    test('★ لا حقل مصدر في مدخلات المقوت إطلاقاً — FR-M4-04', () {
      // ⛔ الفحص بنيوي: [DealerInput] لا يملك حقل مصادر أصلاً، فلو أُضيف
      //    لَفشل التصريف هنا. وهذا الاختبار يوثّق النية صراحةً.
      const DealerInput input = DealerInput(name: 'مقوت مثال', phone: '777123456');
      expect(input.name, 'مقوت مثال');
    });

    test('يقبل مقوتاً صحيحاً', () {
      final Outcome<ValidatedDealer> outcome = validateDealer(
        const DealerInput(name: 'مقوت مثال', phone: '٠٧٧٧-١٢٣-٤٥٦'),
      );
      final ValidatedDealer dealer = (outcome as Success<ValidatedDealer>).value;
      expect(dealer.normalizedPhone, '777123456');
      expect(dealer.isActive, isTrue);
    });

    test('★ التعطيل بلا سبب مرفوض — data-dictionary §dealers', () {
      expect(
        validateDealer(
          const DealerInput(
            name: 'مقوت مثال',
            phone: '777123456',
            isActive: false,
          ),
        ),
        isA<Failure<ValidatedDealer>>(),
      );
    });
  });

  group('validateItem — FR-M5', () {
    ItemInput input({
      ItemNature nature = ItemNature.countBased,
      double? pieceWeightGrams,
      Set<String> extraFields = const <String>{},
      bool isSystemDefault = false,
      String name = 'عود',
    }) =>
        ItemInput(
          sourceIds: const <String>['SRC-001'],
          name: name,
          nature: nature,
          pieceWeightGrams: pieceWeightGrams,
          isSystemDefault: isSystemDefault,
          extraFields: extraFields,
        );

    test('★ وحدة نوع المستخدم «حبة» دائماً — FR-M5-03', () {
      final Outcome<ValidatedItem> outcome = validateItem(input());
      expect((outcome as Success<ValidatedItem>).value.unit, ItemUnit.piece);
    });

    test('★★ وحدة السكرب «كيلوجرام» — FR-M5-05', () {
      final Outcome<ValidatedItem> outcome = validateItem(
        input(
          name: scrapItemName,
          nature: ItemNature.weightBased,
          isSystemDefault: true,
        ),
      );
      expect((outcome as Success<ValidatedItem>).value.unit, ItemUnit.kilogram);
    });

    test('★ E-09: نوع عددي بوزن حبة يدوي يُرفَض', () {
      expect(
        validateItem(input(pieceWeightGrams: 12.5)),
        isA<Failure<ValidatedItem>>(),
      );
    });

    test('★ E-08: نوع وزني بلا وزن حبة مقبول', () {
      final Outcome<ValidatedItem> outcome =
          validateItem(input(nature: ItemNature.weightBased));
      expect(
        (outcome as Success<ValidatedItem>).value.pieceWeightGrams,
        isNull,
      );
    });

    test('يرفض وزن حبة غير موجب', () {
      expect(
        validateItem(
          input(nature: ItemNature.weightBased, pieceWeightGrams: 0),
        ),
        isA<Failure<ValidatedItem>>(),
      );
    });

    test('★★ FR-M5-09: أي حقل سعر يُبطل الطلب كاملاً', () {
      for (final String field in <String>[
        'price',
        'Price',
        'distributionPrice',
        'minCashPrice',
      ]) {
        expect(
          validateItem(input(extraFields: <String>{field})),
          isA<Failure<ValidatedItem>>(),
          reason: 'الحقل «$field» يجب أن يُرفَض',
        );
      }
    });

    test('يرفض اسماً يتجاوز الخمسين حرفاً', () {
      expect(
        validateItem(input(name: 'ع' * (itemNameMaxLength + 1))),
        isA<Failure<ValidatedItem>>(),
      );
    });
  });

  group('حرّاس النوع الافتراضي', () {
    test('★★ تعديل السكرب مرفوض — FR-M5-05', () {
      expect(
        validateSystemDefaultGuard(storedIsSystemDefault: true),
        isA<Failure<void>>(),
      );
      expect(
        validateSystemDefaultGuard(storedIsSystemDefault: false),
        isA<Success<void>>(),
      );
    });

    test('★★ تغيير الوحدة مرفوض — FR-M5-04', () {
      expect(
        validateItemUnitUnchanged(
          stored: ItemUnit.piece,
          incoming: ItemUnit.kilogram,
        ),
        isA<Failure<void>>(),
      );
      expect(
        validateItemUnitUnchanged(
          stored: ItemUnit.piece,
          incoming: ItemUnit.piece,
        ),
        isA<Success<void>>(),
      );
    });
  });

  group('DealerBalanceCensus — FR-M4-09 · E-39', () {
    test('رصيدٌ صفري في كل المصادر ⟵ التعطيل بلا إقرار مقبول', () {
      final Outcome<void> outcome = validateDealerDeactivation(
        census: const DealerBalanceCensus.measured(<String, int>{
          'SRC-001': 0,
          'SRC-002': 0,
        }),
        acknowledgement: null,
        canDisableWithBalance: false,
      );
      expect(outcome, isA<Success<void>>());
    });

    test('★★ ورصيدُ الصفر لا يشترط المفتاح المستقل — `IQ-020`', () {
      // ⛔★★ **حارسٌ على انزلاقٍ مُغرٍ:** لو صار المفتاح شرطاً في كل تعطيل
      //    لَصار **بديلاً عن `dealerWrite`** — وهو ما ينفيه نصّ `IQ-020`
      //    صراحةً. ★ **فالشرط الثلاثي يخصّ الحالة الاستثنائية وحدها.**
      final Outcome<void> outcome = validateDealerDeactivation(
        census: const DealerBalanceCensus.measured(<String, int>{'SRC-001': 0}),
        acknowledgement: null,
        canDisableWithBalance: false,
      );
      expect(outcome, isA<Success<void>>());
    });

    test('★ رصيدٌ غير صفري في مصدرٍ واحد ⟵ يُرفَض بلا إقرار', () {
      final Outcome<void> outcome = validateDealerDeactivation(
        census: const DealerBalanceCensus.measured(<String, int>{
          'SRC-001': 0,
          'SRC-002': 5000,
        }),
        acknowledgement: '   ',
        canDisableWithBalance: true,
      );
      expect(outcome, isA<Failure<void>>());
      expect((outcome as Failure<void>).error, isA<ValidationError>());
    });

    test('★ ويُقبل بإقرارٍ نصّي غير فارغ ومفتاحٍ مستقل', () {
      final Outcome<void> outcome = validateDealerDeactivation(
        census: const DealerBalanceCensus.measured(<String, int>{
          'SRC-002': -5000,
        }),
        acknowledgement: 'أقرّ بأن عليه رصيداً وأتحمّل المتابعة',
        canDisableWithBalance: true,
      );
      expect(outcome, isA<Success<void>>());
    });

    test('⛔★★★ ولا يكفي الإقرار وحده بلا `dealerDisableWithBalance`', () {
      // ★★ **هذا هو الشطر الذي كان `DEBT-26`** — `IQ-020` الخيار أ.
      final Outcome<void> outcome = validateDealerDeactivation(
        census: const DealerBalanceCensus.measured(<String, int>{
          'SRC-002': -5000,
        }),
        acknowledgement: 'أقرّ بأن عليه رصيداً وأتحمّل المتابعة',
        canDisableWithBalance: false,
      );
      expect(outcome, isA<Failure<void>>());
      expect((outcome as Failure<void>).error, isA<PermissionError>(),
          reason: '⛔ «ليست لك» تُميَّز عن «اكتب إقراراً» — ولا رمز جامع');
    });

    test('⛔★ ولا المفتاح وحده بلا إقرار — الشرطان معاً لا أحدهما', () {
      final Outcome<void> outcome = validateDealerDeactivation(
        census: const DealerBalanceCensus.measured(<String, int>{
          'SRC-002': 5000,
        }),
        acknowledgement: null,
        canDisableWithBalance: true,
      );
      expect(outcome, isA<Failure<void>>());
      expect((outcome as Failure<void>).error, isA<ValidationError>());
    });

    test('★ الرصيد السالب رصيدٌ أيضاً — ولا يُقرأ صفراً', () {
      const DealerBalanceCensus census =
          DealerBalanceCensus.measured(<String, int>{'SRC-001': -1});
      expect(census.hasNonZeroBalance, isTrue);
      expect(census.sourcesWithBalance, <String>['SRC-001']);
    });
  });

  group('validateAppSettings — FR-M21', () {
    AppSettingsInput input({
      String businessName = 'وكالة محمد المحامي',
      String currencySymbol = 'ر.ي',
      String thousandsSeparator = ',',
    }) =>
        AppSettingsInput(
          businessName: businessName,
          currencySymbol: currencySymbol,
          thousandsSeparator: thousandsSeparator,
        );

    test('★★ decimalPlaces صفر حتماً — ADR-0015', () {
      final Outcome<ValidatedAppSettings> outcome = validateAppSettings(input());
      expect(
        (outcome as Success<ValidatedAppSettings>).value.decimalPlaces,
        0,
      );
      expect(outcome.value.formattingFields['decimalPlaces'], 0);
    });

    test('يرفض اسم منشأة فارغاً', () {
      expect(
        validateAppSettings(input(businessName: ' ')),
        isA<Failure<ValidatedAppSettings>>(),
      );
    });

    test('يرفض فاصل آلاف بأكثر من محرف', () {
      expect(
        validateAppSettings(input(thousandsSeparator: '__')),
        isA<Failure<ValidatedAppSettings>>(),
      );
    });

    test('★ الفاصل الفارغ خيارٌ صحيح لا خطأ', () {
      expect(
        validateAppSettings(input(thousandsSeparator: '')),
        isA<Success<ValidatedAppSettings>>(),
      );
    });

    test('★★ AT-65: الإعداد المكتوب لا يُكتب ثانيةً', () {
      expect(
        validateAppSettingsUnwritten(
          businessExists: true,
          formattingExists: false,
        ),
        isA<Failure<void>>(),
      );
      expect(
        validateAppSettingsUnwritten(
          businessExists: false,
          formattingExists: true,
        ),
        isA<Failure<void>>(),
      );
      expect(
        validateAppSettingsUnwritten(
          businessExists: false,
          formattingExists: false,
        ),
        isA<Success<void>>(),
      );
    });

    test('★ مفتاحان فقط — FR-M21-05', () {
      expect(appSettingsDocIds, <String>{'business', 'formatting'});
    });
  });

  group('entityCounterId — naming-conventions §5', () {
    test('★ فضاء أسماء منفصل لا يتصادم مع عدّاد المستندات', () {
      final Set<String> entityIds = <String>{
        for (final EntityKind kind in EntityKind.values)
          entityCounterId(kind: kind),
      };
      expect(entityIds, hasLength(EntityKind.values.length));
      for (final String id in entityIds) {
        expect(id, startsWith('entity_'));
      }
      // ⛔ ولا يتصادم مع معرّف عدّاد مستند: ذاك يبدأ باسم [DocumentKind].
      final String documentId = documentCounterId(
        kind: DocumentKind.sack,
        day: CalendarDay(2026, 8, 25),
      );
      expect(entityIds.contains(documentId), isFalse);
    });
  });
}
