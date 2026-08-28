/// مفاتيح عدّادات الترقيم.
///
/// ★ **المصدر:** `data-dictionary.md` §1 («العدّادات ⛅»):
/// `document_counters` · `daily_sack_counters` **(المفتاح: المصدر × التاريخ)**
/// — «**السحابة فقط · والقراءة مرفوضة للجميع**».
///
/// ★ **ولماذا عدّاد الجونية وحده بالمصدر:** `naming-conventions.md` §5 يخصّه
/// بنصّ صريح — «**والرقم المتسلسل اليومي للجونية مستقل لكل مصدر ويبدأ من ١
/// كل يوم**». ⟵ **والتخصيص بالذكر هو ما يجعله استثناءً**: لو كان كل ترقيم
/// بالمصدر لما لزم إفراده بجملة. فبقية المستندات **عدّادها لليوم والنوع**.
///
/// ⚠️ **وترتيب أجزاء المفتاح ثابت لا يُبدَّل** (`naming-conventions.md` §4):
/// «لأنه يحدد الفهارس وكفاءة الاستعلام».
library;

import 'calendar_day.dart';
import 'document_number.dart';

/// اسم مجموعة عدّادات المستندات.
const String documentCountersCollection = 'document_counters';

/// اسم مجموعة العدّاد اليومي للجواني.
const String dailySackCountersCollection = 'daily_sack_counters';

/// معرّف مستند عدّاد نوعٍ في يوم — `{kind}_{YYYYMMDD}`.
///
/// [day] هو اليوم الذي يدخل الرقم فعلاً — أي ناتج `documentNumberDay` لا
/// تاريخ المستند خاماً (`IQ-005`).
String documentCounterId({
  required DocumentKind kind,
  required CalendarDay day,
}) =>
    '${kind.name}_${day.format()}';

/// ★ معرّف مستند عدّاد **أكواد الكيانات** — `entity_{kind}`.
///
/// ⚠️⚠️ **قرار تنفيذي موثَّق لا نقلٌ عن مستند:** `naming-conventions.md` §5
/// يفرض أن **«الترقيم تُولِّده السحابة حصراً»** لأكواد الكيانات
/// (`SRC-001` · `SUP-0001` · `MQT-0001` · `ITM-0001` · `USR-0001`)،
/// ⛔ **لكن `data-dictionary.md` §1 لا يذكر مجموعةَ عدّادٍ لها** بينما
/// يذكرها للمستندات واليوميات.
///
/// ★ **والحلّ إعادةُ استعمال [documentCountersCollection] بفضاء أسماء
/// منفصل** — ⛔ **لا مجموعة جديدة**: المجموعة نفسها **«السحابة فقط
/// والقراءة مرفوضة للجميع»**، ⟵ **فلا تتغيّر قاعدة حماية ولا تُضاف
/// مجموعةٌ بلا سطر في القاموس.** ★ **والبادئة `entity_` تمنع أي تصادم**
/// مع `documentCounterId` الذي يبدأ باسم [DocumentKind] دائماً.
String entityCounterId({required EntityKind kind}) => 'entity_${kind.name}';

/// معرّف مستند العدّاد اليومي للجواني — `{sourceId}_{YYYYMMDD}`.
///
/// ★ **بالمصدر عمداً** — راجع ترويسة الملف.
String dailySackCounterId({
  required String sourceId,
  required CalendarDay day,
}) {
  if (sourceId.isEmpty) {
    throw ArgumentError.value(sourceId, 'sourceId', 'المصدر إلزامي');
  }
  return '${sourceId}_${day.format()}';
}

/// الرقم التالي من قيمة العدّاد الحالية.
///
/// ★ **الغياب يعني صفراً فيبدأ من ١** — `naming-conventions.md` §5
/// («**يبدأ من ١ كل يوم**»). ⛔ **ولا يُعاد استخدام رقم ولا يُملأ فراغ**:
/// العدّاد يتقدّم دائماً، والفجوة أثر مشروع لإلغاء
/// (`data-dictionary.md` §5-ب القاعدة 4).
int nextSequence(int? currentValue) {
  if (currentValue == null) return 1;
  if (currentValue < 0) {
    throw ArgumentError.value(currentValue, 'currentValue', 'العدّاد لا يسلب');
  }
  return currentValue + 1;
}
