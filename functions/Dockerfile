# حاوية العمليات السحابية — ★ **Dart SDK بلا Flutter** (`ADR-0009` ②).
#
# ⚠️ **سياق البناء هو جذر المستودع لا مجلد `functions/`** — لأن الحزمة تعتمد
#    `../packages/qtms_domain` بمسار محلي (`ADR-0012`)، وسياقٌ أضيق لا يراه:
#      docker build -f functions/Dockerfile -t qtms-functions .
#
# ★ **وهذا الملف هو ما يُنفِّذ القاعدة 1 من `ADR-0012` بالبناء لا بالمراجعة:**
#    الصورة لا تحوي Flutter إطلاقاً، فلو تسرّبت اعتمادية عليه إلى حزمة النطاق
#    **فشل `dart pub get` هنا** — قبل النشر لا بعده.

# الإصدار مثبَّت عمداً لا `stable` — ليكون البناء قابلاً لإعادة الإنتاج.
FROM dart:3.11 AS build

WORKDIR /app

# ① الاعتماديات أولاً في طبقة منفصلة — فلا تُعاد عند كل تغيير كود.
COPY packages/qtms_domain/pubspec.yaml packages/qtms_domain/
COPY functions/pubspec.yaml functions/pubspec.lock functions/
RUN cd functions && dart pub get

# ② ثم الكود.
COPY packages/qtms_domain/ packages/qtms_domain/
COPY functions/ functions/
RUN cd functions && dart pub get --offline

# ③ تصريف إلى تنفيذي أصلي — بلا مفسّر وبلا SDK في صورة التشغيل.
RUN cd functions && dart compile exe bin/server.dart -o bin/server

# صورة التشغيل: التنفيذي ومكتبات التشغيل وحدها.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/functions/bin/server /app/bin/server

# Cloud Run يمرّر المنفذ في `PORT`، و`functions_framework` يقرأه.
EXPOSE 8080
CMD ["/app/bin/server"]
