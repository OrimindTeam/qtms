/// تنفيذ عمليات البيانات المرجعية — **الطرف الذي يلمس الشبكة**.
///
/// ★ **مفصول عن `master_data.dart` عمداً**، بنفس منطق `user_admin_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **وترتيب مقصود من ثلاث مراحل، ولا يُعكَس:**
///
/// ① **البوابة قبل المعاملة** — نقصُ الصلاحية أو تعطُّلُ الحساب يُرفَض
///    **بلا فتح معاملة**، ⟵ **فلا أقفال تُحجَز لطلبٍ مرفوض أصلاً.**
///
/// ② ★★ **كل القراءات داخل المعاملة** — المستند القائم · **سجل حراسة
///    التفرد** · **عدّاد الكود** · **أرصدة المقوت** — ⛔ **لا قبلها بلقطةٍ
///    تصير قديمة**: `master-data-design.md` §3 نصّاً («**وبلا ذلك يستطيع
///    مستخدمان إنشاء نفس الرقم في نفس اللحظة**»).
///
/// ③ **الكتابات وقيد التدقيق في التزام واحد** — `ADR-0013` القاعدة 1.
///    ⟵ **فلا مستندَ بلا قيد، ولا قيدَ بلا مستند، ولا كودَ يُستهلَك ثم
///    تفشل الكتابة فتبقى فجوة.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️ **وتخصيص الكود خطوة داخلية لا عملية مستقلة** — حسم `IQ-009`
/// (الخيار أ) مطبَّقاً على أكواد الكيانات: **العدّاد يُقرأ ويُكتب داخل
/// المعاملة نفسها**، ⛔ **ولا `allocateEntityCode` منفصلة.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'counter_allocator.dart' show counterValueField;
import 'identity_gateway.dart';
import 'master_data.dart';
import 'permission_sync_handler.dart' show requestIdField;

/// اسم حقل سبب التعديل في الحمولة — `ADR-0004` · `DEBT-21` ①.
const String masterDataAmendReasonField = 'amendReason';

/// ★ اسم حقل **إقرار تعطيل مقوت له رصيد** — `FR-M4-09` · `E-39`.
const String balanceAcknowledgementField = 'balanceAcknowledgement';

/// مفتاح استعلام أرصدة المقوت داخل المعاملة.
const String _dealerBalancesQueryKey = 'dealerBalances';

/// ★ حدّ قراءة أرصدة المقوت.
///
/// ⚠️ **ولماذا حدٌّ أصلاً:** الاستعلام يقرأ **حساباً لكل مصدر**، ⟵ ★ **فهو
/// محدود بعدد المصادر لا بعدد الحركات**، والمئة هامشٌ واسع جداً على نظامٍ
/// مصادرُه تُعدّ بالأصابع. ⛔ **وتجاوزُه لا يُبتلَع** — راجع `_censusOf`.
const int _dealerBalancesLimit = 100;

/// منفّذ عمليات البيانات المرجعية.
final class MasterDataHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const MasterDataHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
  })  : _identity = identity,
        _transaction = transaction;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    MasterDataOperation operation,
  ) async {
    final CallableParse parsed = await parseCallableRequest(httpRequest);
    if (parsed is RejectedCallable) return callableFailure(parsed.error);
    final CallableRequest call = (parsed as ParsedCallable).request;

    try {
      return await _execute(call, operation);
    } on IdentityGatewayException catch (error) {
      return callableFailure(
        _mapIdentityFailure(error),
        detail: error.diagnostic,
      );
    } on AbortTransaction catch (aborted) {
      return callableFailure(aborted.reason as CallableError);
    } on TransactionContentionException catch (error) {
      // ⛔ ليس ابتلاعاً: يصل المستخدم رمز تعارض صريح فيُعيد المحاولة.
      return callableFailure(CallableError.concurrency, detail: '$error');
    }
  }

  Future<Response> _execute(
    CallableRequest call,
    MasterDataOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    if (requestId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة.
    final MasterDataRejected? gate = masterDataGate(
      MasterDataRequest(
        actor: actor,
        // ⚠️ المعرّف الحقيقي قد لا يوجد بعد (الإنشاء) — والبوابة **لا
        //    تفحصه**، وتفحصه [planMasterData] على الطلب المكتمل.
        entityId: _pendingEntityId,
        requestId: requestId,
      ),
      operation,
    );
    if (gate != null) return callableFailure(gate.error);

    final _Payload? payload = _readPayload(call, operation);
    if (payload == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    return switch (operation) {
      MasterDataOperation.writeAppSettings =>
        await _writeAppSettings(call, actor, requestId, payload),
      _ => await _writeEntity(call, actor, requestId, operation, payload),
    };
  }

  // ═════════════════════════════════════════════════════════════════════
  // كيان واحد — إنشاءً أو تعديلاً
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _writeEntity(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    MasterDataOperation operation,
    _Payload payload,
  ) async {
    final String? existingId =
        operation.isCreate ? null : call.readString(payload.idField);
    if (!operation.isCreate && existingId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      entityCounterId(kind: payload.entityKind),
    );
    final String guardPath = _transaction.documentPath(
      payload.guardCollection,
      payload.guardKey,
    );
    final String? entityPath = existingId == null
        ? null
        : _transaction.documentPath(payload.collectionId, existingId);

    // ★★ **كل القراءات داخل المعاملة** — ② من ترويسة الملف.
    final List<String> readPaths = <String>[
      guardPath,
      if (operation.isCreate) counterPath,
      ?entityPath,
    ];

    // ★ **أرصدة المقوت تُقاس عند التعطيل وحده** — ⛔ ولا تُقرأ بلا داعٍ.
    final bool measuresBalances = payload.entityKind == EntityKind.dealer &&
        !operation.isCreate &&
        payload.isDeactivating;
    final List<DocumentQuery> queries = <DocumentQuery>[
      if (measuresBalances)
        DocumentQuery(
          key: _dealerBalancesQueryKey,
          collectionId: dealerBalancesCollection,
          fieldPath: 'dealerId',
          equalTo: existingId,
          limit: _dealerBalancesLimit,
        ),
    ];

    String allocatedId = existingId ?? '';
    await _transaction.run<void>(
      readPaths: readPaths,
      queries: queries,
      plan: (TransactionReads reads) {
        // ★ **الكود من العدّاد داخل المعاملة** — `naming-conventions.md` §5.
        int? nextValue;
        if (operation.isCreate) {
          final int sequence = nextSequence(
            _intOf(reads.document(counterPath)?[counterValueField]),
          );
          nextValue = sequence;
          allocatedId = formatEntityCode(
            kind: payload.entityKind,
            sequence: sequence,
          );
        }

        final MasterDataPlan plan = planMasterData(
          MasterDataRequest(
            actor: actor,
            entityId: allocatedId,
            requestId: requestId,
            source: payload.source,
            supplier: payload.supplier,
            dealer: payload.dealer,
            item: payload.item,
            amendReason: call.readString(masterDataAmendReasonField),
            balanceAcknowledgement:
                call.readString(balanceAcknowledgementField),
            guard: UniquenessGuardRead(
              collectionId: payload.guardCollection,
              key: payload.guardKey,
              stored: reads.document(guardPath),
            ),
            stored: entityPath == null ? null : reads.document(entityPath),
            dealerBalances: measuresBalances
                ? _censusOf(reads.matchedDocuments(_dealerBalancesQueryKey))
                : null,
          ),
          operation,
        );
        if (plan case MasterDataRejected(:final CallableError error)) {
          // ★ **الرفض بعد القراءة يُبطل المعاملة صراحةً** — ⛔ ولا يكتب شيئاً.
          throw AbortTransaction(error);
        }

        final MasterDataAccepted accepted = plan as MasterDataAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final MasterDataWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّاد يُستهلَك في الالتزام نفسه** — ⟵ **فلا كودٌ
            //    يُخصَّص ثم تفشل الكتابة فتبقى فجوة** (`counter_allocator.dart`).
            if (nextValue case final int value)
              PendingDocument(
                collectionId: documentCountersCollection,
                documentId: entityCounterId(kind: payload.entityKind),
                fields: <String, Object?>{counterValueField: value},
                updateMask: const <String>[counterValueField],
              ),
          ],
          entry: accepted.entry,
          result: null,
        );
      },
    );

    return callableSuccess(<String, Object?>{
      payload.idField: allocatedId,
      // ★★ `ADR-0016`: الصلاحيات تسري فوراً، **والنطاق وحده في الرمز** —
      //   ⛔ **وهذه العمليات لا تمسّ النطاق إطلاقاً.**
      // ⚠️ **ونطاق `all` يشمل المصدر الجديد تلقائياً** بينما القائمة
      //    المحددة **لا يُضاف لها** (`FR-M1-08` · معيار قبول `WU-002`).
      'tokenRefreshRequired': false,
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // ★★ الإعداد التأسيسي — ومعه «السكرب» في المعاملة نفسها (`IQ-012`)
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _writeAppSettings(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    _Payload payload,
  ) async {
    final String businessPath = _transaction.documentPath(
      appSettingsCollection,
      appSettingsBusinessDocId,
    );
    final String formattingPath = _transaction.documentPath(
      appSettingsCollection,
      appSettingsFormattingDocId,
    );
    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      entityCounterId(kind: EntityKind.item),
    );
    final String guardPath = _transaction.documentPath(
      uniqueItemNamesCollection,
      payload.guardKey,
    );

    await _transaction.run<void>(
      readPaths: <String>[businessPath, formattingPath, counterPath, guardPath],
      plan: (TransactionReads reads) {
        final int sequence = nextSequence(
          _intOf(reads.document(counterPath)?[counterValueField]),
        );
        final String scrapItemId = formatEntityCode(
          kind: EntityKind.item,
          sequence: sequence,
        );

        final MasterDataPlan plan = planMasterData(
          MasterDataRequest(
            actor: actor,
            entityId: appSettingsBusinessDocId,
            requestId: requestId,
            settings: payload.settings,
            businessSettingsExist: reads.document(businessPath) != null,
            formattingSettingsExist: reads.document(formattingPath) != null,
            scrapItemId: scrapItemId,
            guard: UniquenessGuardRead(
              collectionId: uniqueItemNamesCollection,
              key: payload.guardKey,
              stored: reads.document(guardPath),
            ),
          ),
          MasterDataOperation.writeAppSettings,
        );
        if (plan case MasterDataRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final MasterDataAccepted accepted = plan as MasterDataAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final MasterDataWrite write in accepted.writes)
              _toPending(write),
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId: entityCounterId(kind: EntityKind.item),
              fields: <String, Object?>{counterValueField: sequence},
              updateMask: const <String>[counterValueField],
            ),
          ],
          entry: accepted.entry,
          result: null,
        );
      },
    );

    return callableSuccess(<String, Object?>{
      'written': true,
      'tokenRefreshRequired': false,
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // قراءة الحمولة — ⛔ **والتحقق من طبقة النطاق لا من هنا**
  // ═════════════════════════════════════════════════════════════════════

  static _Payload? _readPayload(
    CallableRequest call,
    MasterDataOperation operation,
  ) =>
      switch (operation) {
        MasterDataOperation.createSource ||
        MasterDataOperation.updateSource =>
          _sourcePayload(call),
        MasterDataOperation.createSupplier ||
        MasterDataOperation.updateSupplier =>
          _supplierPayload(call),
        MasterDataOperation.createDealer ||
        MasterDataOperation.updateDealer =>
          _dealerPayload(call),
        MasterDataOperation.createItem ||
        MasterDataOperation.updateItem =>
          _itemPayload(call),
        MasterDataOperation.writeAppSettings => _settingsPayload(call),
      };

  static _Payload? _sourcePayload(CallableRequest call) {
    final Outcome<ValidatedSource> outcome = validateSource(
      SourceInput(
        name: call.readString('name') ?? '',
        requiresSupplierOnIntake:
            _boolOf(call.data['requiresSupplierOnIntake']) ?? false,
        notes: call.readString('notes'),
        isActive: _boolOf(call.data['isActive']) ?? true,
        disableReason: call.readString('disableReason'),
      ),
    );
    if (outcome is Failure<ValidatedSource>) return null;
    final ValidatedSource source = (outcome as Success<ValidatedSource>).value;
    return _Payload(
      idField: 'sourceId',
      entityKind: EntityKind.source,
      collectionId: sourcesCollection,
      guardCollection: uniqueSourceNamesCollection,
      guardKey: source.normalizedName,
      isDeactivating: !source.isActive,
      source: source,
    );
  }

  static _Payload? _supplierPayload(CallableRequest call) {
    final Outcome<ValidatedSupplier> outcome = validateSupplier(
      SupplierInput(
        sourceIds: call.readStringList('sourceIds') ?? const <String>[],
        name: call.readString('name') ?? '',
        phone: call.readString('phone') ?? '',
        notes: call.readString('notes'),
        isActive: _boolOf(call.data['isActive']) ?? true,
        disableReason: call.readString('disableReason'),
      ),
    );
    if (outcome is Failure<ValidatedSupplier>) return null;
    final ValidatedSupplier supplier =
        (outcome as Success<ValidatedSupplier>).value;
    return _Payload(
      idField: 'supplierId',
      entityKind: EntityKind.supplier,
      collectionId: suppliersCollection,
      guardCollection: uniqueSupplierPhonesCollection,
      guardKey: supplier.normalizedPhone,
      isDeactivating: !supplier.isActive,
      supplier: supplier,
    );
  }

  static _Payload? _dealerPayload(CallableRequest call) {
    final Outcome<ValidatedDealer> outcome = validateDealer(
      DealerInput(
        name: call.readString('name') ?? '',
        phone: call.readString('phone') ?? '',
        notes: call.readString('notes'),
        isActive: _boolOf(call.data['isActive']) ?? true,
        disableReason: call.readString('disableReason'),
      ),
    );
    if (outcome is Failure<ValidatedDealer>) return null;
    final ValidatedDealer dealer = (outcome as Success<ValidatedDealer>).value;
    return _Payload(
      idField: 'dealerId',
      entityKind: EntityKind.dealer,
      collectionId: dealersCollection,
      guardCollection: uniqueDealerPhonesCollection,
      guardKey: dealer.normalizedPhone,
      isDeactivating: !dealer.isActive,
      dealer: dealer,
    );
  }

  static _Payload? _itemPayload(CallableRequest call) {
    final ItemNature? nature = _natureOf(call.data['nature']);
    if (nature == null) return null;
    final Outcome<ValidatedItem> outcome = validateItem(
      ItemInput(
        sourceIds: call.readStringList('sourceIds') ?? const <String>[],
        name: call.readString('name') ?? '',
        nature: nature,
        pieceWeightGrams: _doubleOf(call.data['pieceWeightGrams']),
        isActive: _boolOf(call.data['isActive']) ?? true,
        disableReason: call.readString('disableReason'),
        // ⛔★★ **ولا يُقرأ `isSystemDefault` من الحمولة إطلاقاً** — «من
        //    السحابة فقط» (`FR-M5-05` · `master-data-design.md` §5)، ⟵
        //    **وقراءتُه كانت ستجعل أي عميل يُنشئ نوعاً محصَّناً بالكيلوجرام.**
        // ★ **والحقول الإضافية تُفحَص مقابل ممنوعات السعر** (`FR-M5-09`).
        extraFields: call.data.keys.toSet(),
      ),
    );
    if (outcome is Failure<ValidatedItem>) return null;
    final ValidatedItem item = (outcome as Success<ValidatedItem>).value;
    return _Payload(
      idField: 'itemId',
      entityKind: EntityKind.item,
      collectionId: itemsCollection,
      guardCollection: uniqueItemNamesCollection,
      guardKey: item.normalizedName,
      isDeactivating: !item.isActive,
      item: item,
    );
  }

  static _Payload? _settingsPayload(CallableRequest call) {
    final Outcome<ValidatedAppSettings> outcome = validateAppSettings(
      AppSettingsInput(
        businessName: call.readString('businessName') ?? '',
        currencySymbol: call.readString('currencySymbol') ?? '',
        logo: call.readString('logo'),
        phone: call.readString('phone'),
        address: call.readString('address'),
        thousandsSeparator: call.readString('thousandsSeparator') ?? ',',
      ),
    );
    if (outcome is Failure<ValidatedAppSettings>) return null;
    return _Payload(
      idField: 'settingsId',
      entityKind: EntityKind.item,
      collectionId: appSettingsCollection,
      guardCollection: uniqueItemNamesCollection,
      // ★ مفتاح حراسة «السكرب» — ⟵ **من مصدر التطبيع الواحد** (`IQ-013`).
      guardKey: normalizeName(scrapItemName),
      isDeactivating: false,
      settings: (outcome as Success<ValidatedAppSettings>).value,
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // مساعدات
  // ═════════════════════════════════════════════════════════════════════

  static PendingDocument _toPending(MasterDataWrite write) => PendingDocument(
        collectionId: write.collectionId,
        documentId: write.documentId,
        fields: write.fields,
        updateMask: write.updateMask,
        serverTimestampFields: write.serverTimestampFields,
      );

  /// ★★ يبني إحصاء الأرصدة **من القراءة الفعلية** — ⛔ ولا من افتراض.
  ///
  /// ⚠️ **ومستندٌ بلا `sourceId` أو بلا `balance` لا يُتجاهَل:** يدخل
  /// الإحصاء **بمفتاحٍ صريح وقيمةٍ صفرية**؟ ⛔ **لا** — ★ **يدخل بقيمةٍ
  /// غير صفرية عمداً**، فقراءتُه صفراً كانت ستُعطِّل مقوتاً برصيدٍ لم
  /// يُقرأ. ⟵ **والرفض الافتراضي هنا يعني: ما لا أفهمه أعُدّه رصيداً.**
  static DealerBalanceCensus _censusOf(List<Map<String, Object?>> documents) {
    final Map<String, int> balances = <String, int>{};
    for (int index = 0; index < documents.length; index++) {
      final Map<String, Object?> document = documents[index];
      final Object? sourceId = document['sourceId'];
      final int? balance = _intOf(document['balance']);
      final String key =
          sourceId is String && sourceId.isNotEmpty ? sourceId : 'unknown_$index';
      // ★ **الغياب رصيدٌ لا صفر** — راجع التعليق أعلاه.
      balances[key] = balance ?? 1;
    }
    return DealerBalanceCensus.measured(balances);
  }

  static int? _intOf(Object? raw) => switch (raw) {
        final int value => value,
        // ★ القاعدة قد تُعيد العدد الصحيح عشرياً — ⛔ والكسر ليس عدّاداً.
        final double value when value == value.roundToDouble() => value.toInt(),
        final String value => int.tryParse(value),
        _ => null,
      };

  static double? _doubleOf(Object? raw) => switch (raw) {
        final int value => value.toDouble(),
        final double value => value,
        final String value => double.tryParse(value),
        _ => null,
      };

  /// ⛔ **ولا يُقرأ النصّ `'true'` قيمةً منطقية** — نوعٌ غير متوقَّع يعني
  /// **خللَ عميل**، ★ **والتساهل فيه يُخفي الخلل حتى يقع أثره في البيانات.**
  static bool? _boolOf(Object? raw) => raw is bool ? raw : null;

  static ItemNature? _natureOf(Object? raw) {
    for (final ItemNature nature in ItemNature.values) {
      if (nature.name == raw) return nature;
    }
    return null;
  }

  /// ★ معرّف نائب **لفحص البوابة قبل تخصيص الكود** — ⛔ ولا يُكتب أبداً.
  static const String _pendingEntityId = 'pending';

  static CallableError _mapIdentityFailure(IdentityGatewayException error) =>
      switch (error.failure) {
        IdentityFailure.invalidToken => CallableError.sessionExpired,
        IdentityFailure.accountNotFound => CallableError.invalidArgument,
        IdentityFailure.claimsTooLarge => CallableError.internal,
        IdentityFailure.emailAlreadyExists => CallableError.internal,
      };
}

/// حمولة مقروءة ومُتحقَّق منها — **بمواضع قراءتها وكتابتها**.
final class _Payload {
  const _Payload({
    required this.idField,
    required this.entityKind,
    required this.collectionId,
    required this.guardCollection,
    required this.guardKey,
    required this.isDeactivating,
    this.source,
    this.supplier,
    this.dealer,
    this.item,
    this.settings,
  });

  final String idField;
  final EntityKind entityKind;
  final String collectionId;
  final String guardCollection;
  final String guardKey;
  final bool isDeactivating;
  final ValidatedSource? source;
  final ValidatedSupplier? supplier;
  final ValidatedDealer? dealer;
  final ValidatedItem? item;
  final ValidatedAppSettings? settings;
}
