# ردگیری مرزهای نوشتن سفارش و پوزیشن — Pass 26 (2026-10-09)

## دامنه
بازخوانی مستقیم سورس `MQL5/Experts/SmartTradingBot_FINAL.mq5` در شاخهٔ ممیزی؛ blob SHA `955d9961e3da1d855a162ac6f4acf7bf7fc852b8`، 8,665 خط. این سند فقط نتیجهٔ static inspection است. هیچ build، runtime، tester یا demo اجرا نشده است.

## یافته‌های دقیق

### WB-01 — حذف سفارش: writer واحد است، اما سیاست مجوز در مرز آن صریح نیست
- `STB_ExecuteOrderDelete` در حوالی خطوط 8135–8177 تنها فراخوانی مستقیم `trade.OrderDelete(ticket)` در فایل اصلی است.
- تابع ticket را انتخاب می‌کند، درخواست synchronous می‌فرستد، retcode را بررسی می‌کند و ناپدیدشدن ticket را تأیید می‌کند.
- اما در بدنهٔ writer کنترل صریح `STB_SymbolManagementOwnedVerified(symbol)` یا capability معادل دیده نمی‌شود.
- `STB_RequestOrderDelete` صرفاً پارامترها را به writer منتقل می‌کند.
- حذف هم برای rollback بعد از ایجاد سفارش نامعتبر استفاده می‌شود و هم برای پاک‌سازی/انقضا. پس guard کردن همهٔ حذف‌ها با lease عادی، بدون تعریف مجوز rollback، می‌تواند رفتار را بشکند.

**نتیجه:** این یک gap در طراحی authorization است که باید تعیین تکلیف شود؛ وقوع حذف غیرمجاز از متن ثابت نشده است. راه درست، مدل مجوز تفکیک‌شده برای user-delete، housekeeping، server-expiration و creator rollback است، همراه با آزمون هر مسیر.

### WB-02 — SL writer هم lease دارد و هم محدودیت یک write در هر چرخه
- `ModifyPositionSL` بررسی می‌کند که موقعیت managed باشد، نماد مجاز باشد و lease تأییدشدهٔ مدیریت نماد برقرار باشد.
- `STB_CycleWriteAlreadyDone` سقف یک درخواست modify برای هر ticket در هر cycle را اعمال می‌کند.
- قبل از درخواست، TP از وضعیت جاری خوانده می‌شود و `trade.PositionModify(ticket,newSL,tp)` هر دو SL و TP را ارسال می‌کند.
- بنابراین ریسک snapshot قدیمی واقعی و قابل توضیح است، ولی race وقوع‌یافته اثبات نشده است. همچنین لازم است retcode و state بعد از درخواست در سناریوهای هم‌زمان بررسی شود.

**پیشنهاد طراحی:** پیش از patch مشخص شود چه مؤلفه‌ای مالک TP است، آیا TP باید همواره حفظ شود، و چگونه تغییر هم‌زمان توسط کاربر/EA/سرور تشخیص داده می‌شود. اصلاح صرفاً با جایگزین کردن یک پارامتر بدون regression توصیه نمی‌شود.

### WB-03 — داوری SL عملاً با یک proposal در هر فراخوانی انجام می‌شود
`STB_SubmitPositionSL` آرایه را با اندازهٔ 1 می‌سازد و `STB_ResolvePositionSL` را با count=1 فراخوانی می‌کند. Resolver می‌تواند چند proposal را مرتب کند، اما این مسیر مشخص، arbitration هم‌زمان بین initial protection، profit protection و trailing را نشان نمی‌دهد.

**نتیجه:** فعلاً نباید این ساختار را «داوری مرکزی هم‌زمان تمام پیشنهادها» توصیف کرد. باید یا قرارداد اولویت سریالی مستند و تست شود، یا معماری چندپیشنهادی به‌عنوان تغییر جداگانه طراحی شود.

### WB-04 — سه مسیر ایجاد سفارش به‌وضوح guard یکسان SYMBOL_VOLUME_LIMIT را نشان نمی‌دهند
- `PlaceSetup` بعد از تعیین حجم، `DirectionExposureVolume(symbol,direction)+volume` را در برابر `SYMBOL_VOLUME_LIMIT` کنترل می‌کند.
- `PlaceManualPendingDirection` و `PlaceManualLimitDirection` حجم را از `InpBaseLots` نرمال می‌کنند؛ در بخش‌های بررسی‌شده guard هم‌ارز `SYMBOL_VOLUME_LIMIT` دیده نشد.
- `OneClickHedge` حجم را از حجم موقعیت منبع می‌گیرد و محدودیت حجم یک سفارش را بررسی می‌کند، اما در بخش بررسی‌شده guard صریح `SYMBOL_VOLUME_LIMIT` یا جمع exposure هم‌جهت ندارد.
- `DirectionExposureVolume` هم‌جهت‌بودن پوزیشن‌ها و pending orderها را جمع می‌کند؛ این تابع به‌خودی‌خود guard نیست و فقط در صورت فراخوانی اثر دارد.

**نتیجه:** پوشش guard در مسیرها نامتوازن به نظر می‌رسد. این مشاهده به‌تنهایی اثبات نقض محدودیت broker نیست؛ باید رفتار و معنای `SYMBOL_VOLUME_LIMIT` و exposure در حساب netting/hedging با مستندات MQL5 و تست broker-specific تأیید شود. قبل از هر patch باید سیاست مشترک برای strategy/manual/hedge تعیین شود و مشخص شود که hedge از محدودیت کلی مستثناست یا نه.

### WB-05 — مدیریت چرخه یکپارچه است، اما تضمین runtime نیست
`OnTick` و `OnTimer` هر دو `STB_RunManagementCycle` را صدا می‌زنند؛ این تابع cycle جدید را آغاز کرده و `ManagePositions`, `ManagePendingOrders` و `STB_PendingTrailProcess` را اجرا می‌کند. `OnTradeTransaction` نیز ورودی تراکنش را به `STB_TradeIntakeFromTransaction` می‌دهد.

این طراحی مسیر مدیریت مشترک را نشان می‌دهد، اما idempotency کامل در ترتیب‌های متفاوت callback، restart، fill جزئی و تغییر دستی از متن به‌تنهایی اثبات نمی‌شود.

## برنامهٔ آزمون اولویت‌دار
1. حذف عادی در lease معتبر/نامعتبر؛ rollback پس از ایجاد سفارش و شکست تأیید SL؛ expiration cleanup؛ ticket ناپدیدشده یا باقی‌مانده؛ تکرار درخواست.
2. PositionModify با TP صفر/غیرصفر، تغییر هم‌زمان TP، پاسخ NO_CHANGES، reject، timeout و وضعیت واقعی پس از پاسخ.
3. proposalهای initial/profit/trail در تمام ترتیب‌های ممکن، هم‌زمان و سریالی؛ اطمینان از monotonicity SL و احترام به manual override.
4. محاسبهٔ exposure با ترکیب پوزیشن و pending سفارش‌ها، هر دو جهت، چند magic، حساب netting/hedging و تمام مسیرهای strategy/manual/hedge.
5. تکرار و جابه‌جایی ترتیب OnTick/OnTimer/OnTradeTransaction و restart در میانهٔ lifecycle.
6. اجرای تمام تست‌ها در حساب دمو/Strategy Tester سازگار با سناریو، ذخیرهٔ journal و نتیجهٔ خام.

## تصمیم
- در این گذر سورس اجرایی تغییر نکرد.
- Scanner به ساختار معاملاتی اضافه نشد.
- WB-01 تا WB-05 به‌عنوان موارد نیازمند طراحی/تست ثبت می‌شوند؛ هیچ‌کدام را بدون تست مناسب، «باگ runtime اثبات‌شده» نمی‌نامیم.
- وضعیت انتشار: BLOCKED / NOT VERIFIED.
- وضعیت ممیزی: `DOCUMENTATION PASS COMPLETE — TECHNICAL AUDIT OPEN`.
