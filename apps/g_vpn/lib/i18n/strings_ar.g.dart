///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsAr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsAr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ar,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ar>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsAr _root = this; // ignore: unused_field

	@override 
	TranslationsAr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsAr(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$ar common = _Translations$common$ar._(_root);
	@override late final _Translations$nav$ar nav = _Translations$nav$ar._(_root);
	@override late final _Translations$home$ar home = _Translations$home$ar._(_root);
	@override late final _Translations$servers$ar servers = _Translations$servers$ar._(_root);
	@override late final _Translations$pro$ar pro = _Translations$pro$ar._(_root);
	@override late final _Translations$rules$ar rules = _Translations$rules$ar._(_root);
	@override late final _Translations$apps$ar apps = _Translations$apps$ar._(_root);
	@override late final _Translations$location$ar location = _Translations$location$ar._(_root);
	@override late final _Translations$addServer$ar addServer = _Translations$addServer$ar._(_root);
	@override late final _Translations$button$ar button = _Translations$button$ar._(_root);
	@override late final _Translations$wol$ar wol = _Translations$wol$ar._(_root);
	@override late final _Translations$speed$ar speed = _Translations$speed$ar._(_root);
	@override late final _Translations$router$ar router = _Translations$router$ar._(_root);
	@override late final _Translations$network$ar network = _Translations$network$ar._(_root);
	@override late final _Translations$devices$ar devices = _Translations$devices$ar._(_root);
	@override late final _Translations$ping$ar ping = _Translations$ping$ar._(_root);
	@override late final _Translations$status$ar status = _Translations$status$ar._(_root);
	@override late final _Translations$tools$ar tools = _Translations$tools$ar._(_root);
	@override late final _Translations$trace$ar trace = _Translations$trace$ar._(_root);
	@override late final _Translations$ports$ar ports = _Translations$ports$ar._(_root);
	@override late final _Translations$wifi$ar wifi = _Translations$wifi$ar._(_root);
	@override late final _Translations$errors$ar errors = _Translations$errors$ar._(_root);
	@override late final _Translations$scan$ar scan = _Translations$scan$ar._(_root);
	@override late final _Translations$legal$ar legal = _Translations$legal$ar._(_root);
	@override late final _Translations$update$ar update = _Translations$update$ar._(_root);
	@override late final _Translations$details$ar details = _Translations$details$ar._(_root);
	@override late final _Translations$share$ar share = _Translations$share$ar._(_root);
	@override late final _Translations$add$ar add = _Translations$add$ar._(_root);
	@override late final _Translations$backup$ar backup = _Translations$backup$ar._(_root);
	@override late final _Translations$gs$ar gs = _Translations$gs$ar._(_root);
}

// Path: common
class _Translations$common$ar extends Translations$common$en {
	_Translations$common$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get gotIt => 'فهمت';
	@override String get about => 'حول';
	@override String get connect => 'اتصال';
	@override String get connected => 'متصل';
	@override String get retry => 'إعادة المحاولة';
	@override String get ok => 'حسنًا';
	@override String get remove => 'إزالة';
	@override String get cancel => 'إلغاء';
	@override String get continueLabel => 'متابعة';
	@override String get notNow => 'ليس الآن';
	@override String get openSettings => 'فتح الإعدادات';
	@override String get close => 'إغلاق';
	@override String get off => 'متوقف';
	@override String get changesReconnect => 'التغييرات تعيد اتصال VPN';
}

// Path: nav
class _Translations$nav$ar extends Translations$nav$en {
	_Translations$nav$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get vpn => 'VPN';
	@override String get servers => 'الخوادم';
	@override String get tools => 'الأدوات';
	@override String get rules => 'القواعد';
	@override String get pro => 'Pro';
}

// Path: home
class _Translations$home$ar extends Translations$home$en {
	_Translations$home$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$status$ar status = _Translations$home$status$ar._(_root);
	@override String resumesAt({required Object time}) => 'يُستأنف عند ${time} · اضغط للاستئناف الآن';
	@override String sitesSee({required Object ip}) => 'المواقع ترى ${ip}';
	@override String sitesSeeOrg({required Object ip, required Object org}) => 'المواقع ترى ${ip} · ${org}';
	@override String get ipFailed => 'تعذّر التحقق من عنوان IP';
	@override String get ipChecking => 'جارٍ التحقق من عنوان IP';
	@override String get themeSystem => 'المظهر: حسب الهاتف';
	@override String get themeLight => 'المظهر: فاتح';
	@override String get themeDark => 'المظهر: داكن';
	@override String get free => 'مجاني';
	@override String get pickServer => 'اختر خادمًا';
	@override late final _Translations$home$waves$ar waves = _Translations$home$waves$ar._(_root);
	@override late final _Translations$home$network$ar network = _Translations$home$network$ar._(_root);
	@override late final _Translations$home$card$ar card = _Translations$home$card$ar._(_root);
	@override late final _Translations$home$tiles$ar tiles = _Translations$home$tiles$ar._(_root);
	@override late final _Translations$home$fastest$ar fastest = _Translations$home$fastest$ar._(_root);
	@override late final _Translations$home$ip$ar ip = _Translations$home$ip$ar._(_root);
}

// Path: servers
class _Translations$servers$ar extends Translations$servers$en {
	_Translations$servers$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'الخوادم';
	@override String get aboutServers => 'حول الخوادم';
	@override late final _Translations$servers$tabs$ar tabs = _Translations$servers$tabs$ar._(_root);
	@override late final _Translations$servers$sheet$ar sheet = _Translations$servers$sheet$ar._(_root);
	@override late final _Translations$servers$badges$ar badges = _Translations$servers$badges$ar._(_root);
	@override late final _Translations$servers$filters$ar filters = _Translations$servers$filters$ar._(_root);
	@override String get loadFailed => 'تعذّر تحميل القائمة';
	@override String get noServers => 'لا توجد خوادم الآن';
	@override String get best => 'الأفضل لك الآن';
	@override String get topRanked => 'الأعلى تقييمًا الآن';
	@override String get addHeading => 'إضافة خادم';
	@override String get scanQr => 'مسح QR';
	@override String get importFile => 'استيراد ملف';
	@override String get paste => 'لصق';
	@override late final _Translations$servers$own$ar own = _Translations$servers$own$ar._(_root);
	@override String get configBroken => 'الإعدادات تحتاج إلى مراجعة';
	@override String get connectedBadge => 'متصل';
	@override String get scannedServer => 'خادم ممسوح';
	@override String get scanFailedTitle => 'تعذّر المسح';
	@override String get scanFailedBody => 'الماسح غير متاح على هذا الهاتف.';
	@override String get importFailedTitle => 'تعذّر الاستيراد';
	@override String get importFailedBody => 'تعذّرت قراءة هذا الملف.';
	@override String get renameTitle => 'إعادة تسمية الخادم';
	@override String get nameHint => 'الاسم، مثلًا راوتر المنزل';
	@override String get save => 'حفظ';
	@override String get rename => 'إعادة تسمية';
	@override String get disconnect => 'قطع الاتصال';
	@override String get more => 'خيارات أخرى';
	@override String get justNow => 'الآن';
	@override String minutesAgo({required Object n}) => 'قبل ${n} د';
	@override String hoursAgo({required Object n}) => 'قبل ${n} س';
	@override String daysAgo({required Object n}) => 'قبل ${n} يوم';
	@override String get neverUsed => 'لم يُستخدم بعد';
	@override String lastUsed({required Object when}) => 'آخر استخدام ${when}';
	@override String get disconnectFirst => 'اقطع الاتصال أولًا لإزالته';
	@override String get removeConfirm => 'إزالة هذا الخادم من G VPN؟ تُحذف إعداداته من هذا الهاتف؛ ولا يتغيّر الخادم نفسه.';
}

// Path: pro
class _Translations$pro$ar extends Translations$pro$en {
	_Translations$pro$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get owned => 'لديك Pro';
	@override String get waitingPlay => 'بانتظار Google Play';
	@override String startTrial({required Object days}) => 'ابدأ تجربة مجانية لمدة ${days} يومًا';
	@override String thenYearly({required Object price}) => 'ثم ${price} سنويًا. ألغِ في أي وقت من Google Play.';
	@override String thenMonthly({required Object price}) => 'ثم ${price} شهريًا. ألغِ في أي وقت من Google Play.';
	@override String yearlyPrice({required Object price}) => '${price} سنويًا. ألغِ في أي وقت من Google Play.';
	@override String monthlyPrice({required Object price}) => '${price} شهريًا. ألغِ في أي وقت من Google Play.';
	@override String get restore => 'استعادة';
	@override String get heroTitle => 'خوادم أسرع،\nنديرها بأنفسنا';
	@override String get heroSubtitle => 'WireGuard. بلا سجلات نشاط. بلا حساب.';
	@override String get benefitSpeed => 'سرعة كاملة، بلا قيود الخوادم التطوعية';
	@override String get benefitKey => 'المفتاح يُنشأ على هاتفك ولا يُشارَك أبدًا';
	@override String get benefitFree => 'كل ما هو مجاني يبقى مجانيًا';
	@override String save({required Object pct}) => 'وفّر ${pct}%';
	@override String get yearly => 'سنوي';
	@override String get monthly => 'شهري';
	@override String get billedMonthly => 'يُدفع شهريًا';
	@override String daysFree({required Object days}) => '${days} يومًا مجانًا';
	@override String perMonth({required Object price}) => '${price} شهريًا';
	@override String get title => 'G VPN Pro';
	@override String get heroTitleOneLine => 'خوادم أسرع نديرها بأنفسنا';
	@override String get includes => 'يشمل';
	@override String get benefitLogs => 'بلا سجلات نشاط على خوادمنا';
	@override String get plan => 'اختر خطة';
	@override String get renewGeneric => 'تتجدد الاشتراكات تلقائيًا حتى إلغائها. ألغِ في أي وقت من Google Play.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} يومًا مجانًا، ثم ${price} لكل ${period}. يتجدد تلقائيًا حتى الإلغاء؛ ألغِ من Google Play قبل انتهاء التجربة بيوم على الأقل لتجنّب الدفع.';
	@override String renew({required Object price, required Object period}) => '${price} لكل ${period}. يتجدد تلقائيًا حتى الإلغاء؛ ألغِ في أي وقت من Google Play.';
	@override String get year => 'سنة';
	@override String get month => 'شهر';
	@override String get manage => 'إدارة الاشتراك';
	@override late final _Translations$pro$free$ar free = _Translations$pro$free$ar._(_root);
}

// Path: rules
class _Translations$rules$ar extends Translations$rules$en {
	_Translations$rules$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'القواعد';
	@override late final _Translations$rules$info$ar info = _Translations$rules$info$ar._(_root);
	@override String get protection => 'الحماية';
	@override String get shield => 'الدرع';
	@override String get shieldSub => 'يحظر مواقع البرامج الضارة والتصيّد';
	@override String get privateDns => 'الدرع دون VPN';
	@override String get privateDnsSub => 'انسخ dns.quad9.net لاستخدامه في DNS الخاص';
	@override String get privateDnsCopied => 'تم نسخ dns.quad9.net';
	@override String get privateDnsHow => 'افتح الإعدادات وابحث عن "DNS الخاص" واختر "اسم مضيف مزوّد DNS الخاص" ثم الصقه.';
	@override String get stay => 'البقاء متصلًا';
	@override String get alwaysOn => 'VPN دائم التشغيل';
	@override String get alwaysOnSub => 'يعيد Android تشغيل G VPN إذا توقف';
	@override String get battery => 'البطارية';
	@override String get batteryOk => 'غير مقيّد';
	@override String get batteryRestricted => 'مقيّد: قد يتوقف في الخلفية';
	@override String get autoConnect => 'اتصال تلقائي';
	@override String get autoOff => 'متوقف';
	@override String get autoOffSub => 'فقط عند الضغط';
	@override String get autoOpen => 'Wi-Fi العامة';
	@override String get autoOpenSub => 'الشبكات المفتوحة أو WEP أو التي تتطلب تسجيل دخول';
	@override String get autoAny => 'كل Wi-Fi';
	@override String get autoAnySub => 'أي شبكة Wi-Fi';
	@override String get apps => 'التطبيقات';
	@override String get appsDirect => 'تطبيقات مباشرة';
	@override String get appsNone => 'كل التطبيقات تستخدم VPN';
	@override String appsSome({required Object n}) => '${n} تطبيقات دون VPN';
	@override String get appearance => 'المظهر';
	@override String get themePhone => 'الهاتف';
	@override String get themeLight => 'فاتح';
	@override String get themeDark => 'داكن';
	@override String get about => 'حول';
}

// Path: apps
class _Translations$apps$ar extends Translations$apps$en {
	_Translations$apps$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'تطبيقات مباشرة';
	@override String get sheetSubtitle => 'التطبيقات المختارة تتصل دون VPN. كل ما عداها يبقى محميًا.';
	@override String get whyTitle => 'لماذا تستثني تطبيقًا';
	@override String get whyBody => 'كثيرًا ما تحظر البنوك وتطبيقات الدفع عناوين VPN، لذا قد تفشل المدفوعات عبر VPN. بعض الخدمات المحلية لا تعمل إلا من بلدك.';
	@override String get favouritesBody => 'ضع نجمة على التطبيقات التي تغيّرها كثيرًا؛ تبقى في الأعلى.';
	@override String get whileConnected => 'أثناء الاتصال';
	@override String get whileConnectedBody => 'تغيير هذه القائمة يعيد اتصال VPN للحظة.';
	@override String search({required Object n}) => 'ابحث في ${n} تطبيق';
	@override String get skipping => 'دون VPN';
	@override String get skippingNone => 'لا شيء. كل التطبيقات تمر عبر VPN.';
	@override String protectAgain({required Object app}) => 'حماية ${app} مجددًا';
	@override String get banking => 'البنوك والمدفوعات';
	@override String bankingFound({required Object n}) => 'عُثر على ${n} قد تحظر VPN';
	@override String get addAll => 'إضافة الكل';
	@override String get favourites => 'المفضلة';
	@override String get all => 'كل التطبيقات';
	@override String found({required Object n}) => 'عُثر على ${n}';
	@override String get noMatch => 'لا يوجد تطبيق مطابق.';
	@override String showAll({required Object n}) => 'عرض الكل (${n})';
	@override String get skips => 'دون VPN';
	@override String get unstar => 'إزالة من المفضلة';
	@override String get star => 'إضافة إلى المفضلة';
}

// Path: location
class _Translations$location$ar extends Translations$location$en {
	_Translations$location$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'السماح بالموقع لشبكة Wi-Fi';
	@override String get useHome => 'إظهار اسم Wi-Fi في الصفحة الرئيسية';
	@override String get useScan => 'فحص الشبكات والقنوات القريبة';
	@override String get private => 'يبقى على هذا الهاتف. لا يُجمع موقعك أبدًا.';
	@override String get switchTitle => 'شغّل خدمة الموقع';
	@override String get switchBody => 'يخفي Android أسماء Wi-Fi عندما تكون خدمة الموقع متوقفة';
}

// Path: addServer
class _Translations$addServer$ar extends Translations$addServer$en {
	_Translations$addServer$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get clipboardEmpty => 'الحافظة فارغة.';
	@override String get title => 'أضف خادمك';
	@override String get body => 'الصق إعدادات WireGuard من الراوتر أو VPS أو الخادم المنزلي.';
	@override String get nameHint => 'الاسم، مثلًا راوتر المنزل';
	@override String get paste => 'لصق';
	@override String get save => 'حفظ الخادم';
	@override String notWireguard({required Object error}) => 'هذه ليست إعدادات WireGuard: ${error}';
}

// Path: button
class _Translations$button$ar extends Translations$button$en {
	_Translations$button$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get stop => 'إيقاف';
	@override String get connecting => 'جارٍ الاتصال';
	@override String get stopping => 'جارٍ الإيقاف';
	@override String get connect => 'اتصال';
	@override String get disconnect => 'قطع الاتصال';
}

// Path: wol
class _Translations$wol$ar extends Translations$wol$en {
	_Translations$wol$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get info => 'يشغّل حاسوبًا أو NAS على شبكة Wi-Fi هذه إذا كان Wake on LAN مفعّلًا في إعداداته. يجب أن يكون هاتفك على الشبكة نفسها؛ أوقف VPN أولًا.';
	@override String get badMac => 'هذا ليس عنوان MAC. شكله مثل AA:BB:CC:DD:EE:FF.';
	@override String get sent => 'أُرسلت إشارة التشغيل. يُفترض أن يعمل الجهاز خلال دقيقة.';
	@override String get title => 'Wake on LAN';
	@override String get wake => 'تشغيل الجهاز';
	@override String get mac => 'عنوان MAC';
	@override String failed({required Object error}) => 'تعذّر الإرسال: ${error}';
}

// Path: speed
class _Translations$speed$ar extends Translations$speed$en {
	_Translations$speed$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get info => 'تقيسه منصة M-Lab البحثية المفتوحة. يستهلك الاختبار نحو 50 إلى 100 ميغابايت.\n\nنتائج علنية: تنشر M-Lab كل اختبار، بما فيه عنوان IP الذي جاء منه، كبيانات بحثية مفتوحة.\n\nمقارنة المزوّدين: بعد اختبار دون VPN، يرسل G VPN أرقام السرعة الثلاثة فقط. تقرأ خدمة المقارنة مزوّدك ومدينتك من الاتصال نفسه ولا تخزّن أي عنوان IP. أوقفها بالمفتاح أسفل هذه الصفحة.\n\nعبر VPN: عند تشغيل VPN يقيس السرعة عبر النفق ويقارنها بآخر اختبار دونه.\n\nمعاينة الفيديو: الصورة نفسها بالدقة التي تتيحها هذه السرعة، وفق معدلات البت التي تنشرها خدمات البث. لا يُنزَّل أي فيديو.';
	@override String get download => 'التنزيل';
	@override String get upload => 'الرفع';
	@override String get finding => 'جارٍ البحث عن خادم';
	@override String get throughVpn => 'عبر VPN';
	@override String get directNoVpn => 'مباشر، دون VPN';
	@override String get title => 'اختبار السرعة';
	@override String get stop => 'إيقاف';
	@override String get start => 'بدء الاختبار';
	@override String get again => 'اختبار مجددًا';
	@override String get viaVpn => 'عبر VPN';
	@override String get direct => 'مباشر';
	@override String get mbps => 'ميغابت/ث';
	@override String get ping => 'PING';
	@override String get vsDirect => 'مقابل المباشر';
	@override String get compare => 'قارن بالمزوّدين القريبين';
	@override String get compareSub => 'يشارك السرعات فقط، ولا يشارك عنوان IP أبدًا';
	@override String get tierTv => 'أجهزة التلفاز الكبيرة';
	@override String get tierLaptopLarge => 'الحواسيب المحمولة الكبيرة';
	@override String get tierTablet => 'الأجهزة اللوحية والحواسيب';
	@override String get tierPhone => 'الهواتف';
	@override String get tierSmallPhone => 'الهواتف الصغيرة';
	@override String get tierCalls => 'المكالمات والصوت';
	@override String get messagingOnly => 'المراسلة فقط';
	@override String get videoQuality => 'جودة الفيديو';
	@override String get preview => 'معاينة';
	@override String get history => 'السجل';
	@override String get clear => 'مسح';
	@override String get viaVpnLower => 'عبر VPN';
	@override String get directLower => 'مباشر';
	@override String get gradeA => 'عدة بثوث 4K ومكالمات فيديو في الوقت نفسه';
	@override String get gradeB => 'بث HD ومكالمات فيديو سلسة';
	@override String get gradeC => 'بث HD واحد؛ قد تتقطع المكالمات في أوقات الذروة';
	@override String get gradeD => 'تصفّح ومراسلة؛ الفيديو يتعثّر';
	@override String get yourCountry => 'بلدك';
	@override String get median => 'متوسط التنزيل (الوسيط)، آخر 30 يومًا';
	@override String get fromUsers => 'ميغابت/ث · من اختبارات مستخدمي G VPN';
	@override String get costLittle => 'VPN يقلّل السرعة قليلًا';
	@override String get costNoticeable => 'أبطأ بشكل ملحوظ من المباشر';
	@override String get costMuch => 'أبطأ بكثير. جرّب خادمًا آخر';
	@override String get ofDirect => 'من سرعتك المباشرة';
	@override String get none => 'لا شيء';
	@override String ms({required Object n}) => '${n} مللي ثانية';
	@override String previewTier({required Object tier}) => 'معاينة · ${tier}';
	@override String streamsUpTo({required Object tier, required Object who}) => 'يبث حتى ${tier} · ${who}';
	@override String today({required Object time}) => 'اليوم، ${time}';
	@override String tests({required Object n}) => '${n} اختبارات';
	@override String gradeVpn({required Object label}) => '${label} عبر VPN';
	@override String gradeIsp({required Object label, required Object isp}) => '${label} على ${isp}';
	@override String notEnough({required Object isp}) => 'لا توجد اختبارات كافية بعد لـ ${isp}';
	@override String get yourProvider => 'مزوّدك';
	@override String rankLine({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} في ${where}: المرتبة ${rank} من ${of}';
	@override String costLine({required Object note, required Object mbps}) => '${note} · المباشر ${mbps} ميغابت/ث';
	@override String mbpsValue({required Object v}) => '${v} ميغابت/ث';
	@override String get gradeExcellent => 'ممتاز';
	@override String get gradeVeryGood => 'جيد جدًا';
	@override String get gradeGood => 'جيد';
	@override String get gradeFair => 'مقبول';
	@override String get gradeSlow => 'بطيء';
	@override String get gradeVerySlow => 'بطيء جدًا';
}

// Path: router
class _Translations$router$ar extends Translations$router$en {
	_Translations$router$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get info => 'يسأل الراوتر عبر UPnP عمّا إذا كان بإمكان الأجهزة فتح منافذ إلى الإنترنت بنفسها، ويعرض ما فتحته. يقرأ فقط ولا يغيّر شيئًا. إن لم يكن هناك ما يحتاج UPnP (بعض أجهزة الألعاب تحتاجه)، فإيقافه من إعدادات الراوتر أكثر أمانًا.';
	@override String get title => 'فحص الراوتر';
	@override String get asking => 'جارٍ سؤال الراوتر';
	@override String get again => 'افحص مجددًا';
	@override String get check => 'فحص الراوتر';
	@override String get off => 'UPnP متوقف';
	@override String get offBody => 'لا تستطيع الأجهزة فتح منافذ بنفسها.';
	@override String get onBody => 'لا توجد منافذ مفتوحة عبره الآن.';
	@override String get checkEach => 'تأكّد من أنك تعرف كل واحد منها.';
	@override String get cgnat => 'عنوان مشترك لدى المزوّد: لا يمكن الوصول إليه من الإنترنت.';
	@override String get noDescription => 'بلا وصف';
	@override String opened({required Object n}) => '${n} منافذ فتحتها الأجهزة';
	@override String routerName({required Object name}) => 'الراوتر: ${name}';
	@override String externalIp({required Object ip}) => 'عنوان الإنترنت: ${ip}';
	@override String mapping({required Object proto, required Object host}) => '${proto} إلى ${host}';
	@override String get upnpOn => 'UPnP مفعّل';
}

// Path: network
class _Translations$network$ar extends Translations$network$en {
	_Translations$network$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'هذه الشبكة';
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'بيانات الجوال';
	@override String get ethernet => 'Ethernet';
	@override String get offline => 'غير متصل';
	@override String get risky => 'شبكة خطرة. شغّل VPN هنا.';
	@override String get review => 'تستحق نظرة قبل أن تثق بها.';
	@override String get covered => 'محمية بـ VPN.';
	@override String get safe => 'تبدو هذه الشبكة آمنة.';
	@override String get mobileSentence => 'بيانات الجوال.';
	@override String get notConnected => 'غير متصل.';
	@override String get showName => 'إظهار الاسم';
	@override String get sitesSee => 'المواقع ترى';
	@override String get provider => 'المزوّد';
	@override String get location => 'الموقع';
	@override String get couldNotCheck => 'تعذّر التحقق';
	@override String get checking => 'جارٍ التحقق';
	@override String get signal => 'الإشارة';
	@override String get linkSpeed => 'سرعة الاتصال';
	@override String get gateway => 'البوابة';
	@override String get none => 'لا يوجد';
	@override String get privateDns => 'DNS الخاص';
	@override String get automatic => 'تلقائي';
	@override String get off => 'متوقف';
	@override String get metered => 'محدودة البيانات';
	@override String get yes => 'نعم';
	@override String get no => 'لا';
	@override String readFailed({required Object error}) => 'تعذّرت قراءة الشبكة: ${error}';
}

// Path: devices
class _Translations$devices$ar extends Translations$devices$en {
	_Translations$devices$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get info => 'يطرق كل عنوان في نطاق شبكة Wi-Fi ويطلب من الأجهزة أن تعرّف بنفسها. الجهاز الذي يرفض يُحتسب أيضًا: الرفض يثبت وجوده.\n\nالأسماء: مما تنشره الأجهزة (Bonjour وUPnP وأسماء Windows) ومن الراوتر.\n\nالأجهزة المجهولة: يخفي Android العناوين المادية عن التطبيقات، لذا لا يمكن التعرّف على جهاز صامت بلا اسم معلن. راجع قائمة الأجهزة في الراوتر لمعرفتها.\n\nجديد: جهاز لم يظهر في آخر فحص لهذه الشبكة.';
	@override String get needWifi => 'اتصل بشبكة Wi-Fi أولًا.';
	@override String get title => 'الأجهزة';
	@override String get again => 'افحص مجددًا';
	@override String get looking => 'جارٍ البحث عن الأجهزة';
	@override String get nothingNew => 'لا جديد منذ آخر فحص';
	@override String get takes => 'يستغرق نحو 30 ثانية';
	@override String get all => 'الكل';
	@override String get phones => 'الهواتف';
	@override String get tvs => 'التلفاز';
	@override String get computers => 'الحواسيب';
	@override String get other => 'أخرى';
	@override String get thisPhone => 'هذا الهاتف';
	@override String get router => 'الراوتر';
	@override String get unknown => 'جهاز مجهول';
	@override String get address => 'العنوان';
	@override String get answersIn => 'يستجيب خلال';
	@override String get type => 'النوع';
	@override String get notAnnounced => 'لم يعرّف بنفسه. يمكن لقائمة الأجهزة في الراوتر تسميته.';
	@override String get newBadge => 'جديد';
	@override String scanning({required Object n}) => 'جارٍ فحص ${n} من 254';
	@override String get thisNetwork => 'هذه الشبكة';
	@override String newSince({required Object n}) => '${n} جديد منذ آخر فحص';
	@override String showMore({required Object n}) => 'عرض ${n} أخرى';
	@override String ms({required Object n}) => '${n} مللي ثانية';
	@override String onNetwork({required Object network}) => 'أجهزة على ${network}';
}

// Path: ping
class _Translations$ping$ar extends Translations$ping$en {
	_Translations$ping$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get info => 'المدة التي تستغرقها رحلة ذهاب وإياب واحدة إلى الخادم، تُقاس كل ثانية خلال الدقيقة الأخيرة.\n\nالتذبذب: مقدار اختلاف كل رد عن الذي قبله. التذبذب العالي هو ما يقطع المكالمات.\n\nالفقدان: ردود لم تعد أبدًا.\n\nالطريقة: لا تستطيع تطبيقات Android إرسال ping التقليدي، لذا يقيس كل اختبار زمن إنشاء اتصال، وهو رحلة الذهاب والإياب نفسها.';
	@override String get askTitle => 'Ping لمضيف';
	@override String get askHint => 'example.com أو 192.168.1.10';
	@override String get cancel => 'إلغاء';
	@override String get title => 'Ping';
	@override String get router => 'الراوتر';
	@override String get pause => 'إيقاف مؤقت';
	@override String get start => 'بدء';
	@override String get host => 'مضيف';
	@override String get live => 'مباشر';
	@override String get ago => 'قبل 60 ث';
	@override String get min => 'الأدنى';
	@override String get avg => 'المتوسط';
	@override String get jitter => 'التذبذب';
	@override String get loss => 'الفقدان';
	@override String get goodFor => 'مناسب لـ';
	@override String get calls => 'مكالمات الفيديو';
	@override String get games => 'الألعاب عبر الإنترنت';
	@override String get streaming => 'البث';
	@override String get great => 'ممتاز';
	@override String get okay => 'مقبول';
	@override String get poor => 'ضعيف';
	@override String get lost => 'مفقود';
	@override String get now => 'الآن';
}

// Path: status
class _Translations$status$ar extends Translations$status$en {
	_Translations$status$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get info => 'يتصل بكل خدمة ثلاث مرات ويعرض أسرع رد.\n\nمحظور هنا: الخدمة التي لا تستجيب مباشرة لكنها تعمل عبر VPN محظورة من شبكتك أو بلدك.\n\nالسجل: فحوصات آخر 24 ساعة من هذا الهاتف، محفوظة على هذا الهاتف فقط.';
	@override String get title => 'حالة الخدمات';
	@override String get checking => 'جارٍ الفحص';
	@override String get again => 'افحص مجددًا';
	@override String get viaVpn => 'تم الفحص عبر VPN';
	@override String get direct => 'تم الفحص مباشرة';
	@override String get favourites => 'المفضلة';
	@override String get edit => 'تعديل';
	@override String get last24 => 'آخر 24 ساعة';
	@override String get ago => 'قبل 24 س';
	@override String get all => 'كل الخدمات';
	@override String get pickFour => 'اختر حتى أربع';
	@override String get outage => 'حتى عبر VPN: غالبًا انقطاع';
	@override String get blocked => 'قد يكون محظورًا على هذه الشبكة';
	@override String get connect => 'اتصال';
	@override String get blockedShort => 'محظور';
	@override String get unreachable => 'يتعذّر الوصول';
	@override String get now => 'الآن';
	@override String checks({required Object n}) => '${n} فحوصات';
	@override String andMore({required Object first, required Object n}) => '${first} و${n} أخرى';
	@override String notReachable({required Object who}) => '${who} يتعذّر الوصول إليه';
}

// Path: tools
class _Translations$tools$ar extends Translations$tools$en {
	_Translations$tools$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'بيانات الجوال';
	@override String get ethernet => 'Ethernet';
	@override String get checking => 'جارٍ التحقق';
	@override String get offline => 'غير متصل';
	@override String get title => 'الأدوات';
	@override String get networkDesc => 'فحص الأمان، وما تراه المواقع، والإشارة، والراوتر وDNS.';
	@override String get internet => 'الاتصال بالإنترنت';
	@override String get speed => 'اختبار السرعة';
	@override String get speedDesc => 'سرعة التنزيل والرفع، وجودة الفيديو التي تدعمها.';
	@override String get ping => 'Ping';
	@override String get pingDesc => 'زمن الاستجابة والتذبذب مباشرة إلى أي خادم أو إلى الراوتر.';
	@override String get status => 'حالة الخدمات';
	@override String get statusDesc => 'هل يمكن الوصول إلى WhatsApp أو YouTube أو Google من هنا، أم أنها محظورة؟';
	@override String get trace => 'تتبّع المسار';
	@override String get traceDesc => 'كل راوتر بينك وبين موقع ما، والوقت الذي يستغرقه كل منها.';
	@override String get security => 'أمان الشبكة';
	@override String get devices => 'الأجهزة على هذه الشبكة';
	@override String get devicesDesc => 'من غيرك على Wi-Fi: هواتف وتلفاز وكاميرات وحواسيب.';
	@override String get router => 'فحص الراوتر';
	@override String get routerDesc => 'هل تستطيع الأجهزة فتح منافذ على الراوتر بنفسها (UPnP).';
	@override String get ports => 'المنافذ المفتوحة';
	@override String get portsDesc => 'افحص الراوتر أو خادمًا بحثًا عن منافذ مفتوحة خطرة.';
	@override String get utilities => 'أدوات مساعدة';
	@override String get wifiScanner => 'ماسح Wi-Fi';
	@override String get wifiDesc => 'الشبكات القريبة وأمانها والقناة الأقل ازدحامًا.';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'شغّل حاسوبًا أو NAS على هذه الشبكة.';
}

// Path: trace
class _Translations$trace$ar extends Translations$trace$en {
	_Translations$trace$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get info => 'كل محطة هي راوتر تمر به حركة بياناتك في طريقها إلى الموقع.\n\nالقفزات الصامتة: كثير من أجهزة الراوتر لا تستجيب أبدًا لهذه الاختبارات. هذا طبيعي وليس عطلًا.\n\nمع تشغيل VPN: يبدأ المسار داخل النفق، فتبقى شبكتك ومزوّدك مخفيين.\n\nالطريقة: يستخدم أداة ping المدمجة في Android مع حدّ للقفزات، لأن التطبيقات لا تستطيع إرسال هذه الحزم مباشرة.';
	@override String get title => 'تتبّع المسار';
	@override String get stop => 'إيقاف';
	@override String get trace => 'تتبّع';
	@override String get again => 'تتبّع مجددًا';
	@override String get destination => 'الوجهة';
	@override String get hops => 'القفزات';
	@override String get answered => 'استجابت';
	@override String get total => 'الإجمالي';
	@override String get thisPhone => 'هذا الهاتف';
	@override String get silentOne => 'قفزة صامتة واحدة';
	@override String get yourRouter => 'الراوتر الخاص بك';
	@override String ms({required Object n}) => '${n} مللي ثانية';
	@override String silentMany({required Object n}) => '${n} قفزات صامتة';
	@override String hop({required Object n}) => 'القفزة ${n}';
	@override String slowest({required Object ms, required Object hop}) => 'معظم التأخير، ${ms} مللي ثانية، يُضاف عند القفزة ${hop}: غالبًا كابل طويل بين الدول أو رابط مزدحم.';
}

// Path: ports
class _Translations$ports$ar extends Translations$ports$en {
	_Translations$ports$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get ftpNote => 'يرسل كلمات المرور دون تشفير.';
	@override String get sshNote => 'تسجيل دخول عن بُعد. لا بأس إن كنت أعددته بنفسك.';
	@override String get telnetNote => 'تسجيل دخول عن بُعد دون تشفير؛ مفضّل لدى شبكات البوتات.';
	@override String get dnsNote => 'طبيعي على الراوتر.';
	@override String get web => 'الويب (HTTP)';
	@override String get webNote => 'عادةً صفحة إدارة الراوتر.';
	@override String get webTls => 'الويب (HTTPS)';
	@override String get smb => 'مشاركة ملفات Windows';
	@override String get smbNote => 'يجب ألا يكون مكشوفًا للإنترنت أبدًا.';
	@override String get rtsp => 'بث كاميرا RTSP';
	@override String get rtspNote => 'قد تكون هناك كاميرا تبث هنا.';
	@override String get upnpNote => 'يسمح للأجهزة بفتح منافذ الراوتر بنفسها.';
	@override String get rdp => 'سطح المكتب البعيد';
	@override String get rdpNote => 'طريق شائع للاختراق.';
	@override String get vncNote => 'مشاركة الشاشة، غالبًا دون كلمة مرور.';
	@override String get tr069Note => 'إدارة عن بُعد من مزوّد الإنترنت.';
	@override String get webAlt => 'الويب (بديل)';
	@override String get webAltTls => 'الويب (HTTPS بديل)';
	@override String get title => 'المنافذ المفتوحة';
	@override String get check => 'فحص المنافذ';
	@override String get address => 'عنوان الجهاز أو الخادم';
	@override String get risky => 'خطر';
	@override String get review => 'راجِع';
	@override String get normal => 'طبيعي';
	@override String info({required Object n}) => 'يفحص ${n} منفذًا مهمًا على أجهزة الراوتر والأجهزة المنزلية، ويشرح كل منفذ مفتوح.\n\nافحص فقط الأجهزة والخوادم التي تملكها أو تديرها.';
	@override String checking({required Object n}) => 'جارٍ فحص ${n} منفذًا';
	@override String yourRouter({required Object ip}) => 'الراوتر الخاص بك هو ${ip}';
	@override String noneOpen({required Object host}) => 'لا توجد منافذ شائعة مفتوحة على ${host}.';
}

// Path: wifi
class _Translations$wifi$ar extends Translations$wifi$en {
	_Translations$wifi$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'ماسح Wi-Fi';
	@override String get allow => 'السماح بفحص Wi-Fi';
	@override String get needsPermission => 'يحتاج إلى إذن الموقع.';
	@override String get scanning => 'جارٍ الفحص';
	@override String get again => 'افحص مجددًا';
	@override String get failed => 'فشل الفحص';
	@override String get none => 'لم يُعثر على شبكات. قد تكون خدمة الموقع متوقفة.';
	@override String get hidden => 'شبكة مخفية';
	@override String nearby({required Object n}) => '${n} شبكات قريبة';
	@override String bestChannel({required Object n}) => 'القناة الأقل ازدحامًا في 2.4 غيغاهرتز: ${n}';
	@override String weak({required Object n}) => '${n} مفتوحة أو ضعيفة';
	@override String get connectedPrefix => 'متصل · ';
	@override String get permissionInfo => 'لا يعرض Android شبكات Wi-Fi القريبة إلا للتطبيقات التي لديها إذن الموقع. يستخدمه G VPN فقط لعرض الشبكات على هذا الهاتف.';
	@override String get info => 'يعرض الشبكات من آخر فحص للهاتف. يسمح Android بعدد قليل من الفحوصات في الدقيقة، لذا قد يُظهر الفحص السريع القائمة نفسها. القناة المقترحة هي الأقل ازدحامًا بين 1 و6 و11، وهي القنوات الثلاث غير المتداخلة.';
}

// Path: errors
class _Translations$errors$ar extends Translations$errors$en {
	_Translations$errors$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get notAuthorized => 'لم يُمنح إذن VPN.';
	@override String get turnedOff => 'أوقف النظام أو تطبيق آخر VPN.';
	@override String get busy => 'طلب إذن مفتوح بالفعل.';
	@override String get cancelled => 'أُلغي الاتصال.';
	@override String badConfig({required Object error}) => 'إعدادات هذا الخادم غير صالحة: ${error}';
	@override String get timeout => 'لم يستجب الخادم.';
	@override String get refused => 'رفض الخادم الاتصال.';
	@override String failed({required Object error}) => 'تعذّر الاتصال: ${error}';
	@override String get tryAnother => 'الخوادم المجانية تظهر وتختفي؛ جرّب خادمًا آخر.';
	@override String get downloadFailed => 'تعذّر تنزيل إعدادات هذا الخادم. تحقّق من اتصالك أو اختر خادمًا آخر.';
}

// Path: scan
class _Translations$scan$ar extends Translations$scan$en {
	_Translations$scan$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get mobile => 'بيانات الجوال';
	@override String get ping => 'PING';
	@override String get noReply => 'لا رد';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9، النفق';
	@override String get dnsTunnel => 'داخل النفق';
	@override String get privateDns => 'DNS الخاص';
	@override String get dnsIsp => 'المزوّد، ظاهر';
	@override String get network => 'الشبكة';
	@override String get offline => 'غير متصل';
	@override String get open => 'مفتوحة، بلا كلمة مرور';
	@override String get wep => 'WEP، غير آمنة';
	@override String get owe => 'مفتوحة، مشفّرة';
	@override String get enterprise => 'مؤسسية';
	@override String get unknown => 'غير معروف';
	@override String get wifi => 'WI-FI';
	@override String get signIn => 'صفحة تسجيل دخول';
	@override String ms({required Object n}) => '${n} مللي ثانية';
	@override String covered({required Object what}) => '${what}، محمية';
}

// Path: legal
class _Translations$legal$ar extends Translations$legal$en {
	_Translations$legal$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get privacy => 'سياسة الخصوصية';
	@override String get terms => 'شروط الاستخدام';
	@override String get licences => 'تراخيص البرامج المفتوحة المصدر';
}

// Path: update
class _Translations$update$ar extends Translations$update$en {
	_Translations$update$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get ready => 'التحديث جاهز';
	@override String get restart => 'إعادة التشغيل';
}

// Path: details
class _Translations$details$ar extends Translations$details$en {
	_Translations$details$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get share => 'مشاركة';
	@override String connectedFor({required Object n}) => 'متصل · ${n} د';
	@override String get notConnected => 'غير متصل';
	@override String get downloaded => 'تم تنزيله';
	@override String get uploaded => 'تم رفعه';
	@override String get lastUsed => 'آخر استخدام';
	@override String get connection => 'الاتصال';
	@override String get protocol => 'البروتوكول';
	@override String get address => 'عنوانك';
	@override String get dns => 'DNS';
	@override String get routes => 'المسارات';
	@override String get allTraffic => 'كل حركة البيانات';
	@override String someRoutes({required Object n}) => '${n} شبكات';
	@override String get keepalive => 'Keepalive';
	@override String get serverKey => 'مفتاح الخادم';
	@override String get copy => 'نسخ';
	@override String get copied => 'تم النسخ';
	@override String get manage => 'الإدارة';
	@override String get export => 'تصدير نسخة احتياطية';
	@override String get exportSub => 'كل خوادمك في ملف واحد';
}

// Path: share
class _Translations$share$ar extends Translations$share$en {
	_Translations$share$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String title({required Object name}) => 'مشاركة ${name}';
	@override String get sameKey => 'هذا يشارك مفتاح هذا الهاتف. يمكن لأي شخص يملكه استخدام خادمك باسمك، ولا يمكن إلا لجهاز واحد الاتصال به في الوقت نفسه.';
	@override String get scanHint => 'على الهاتف الآخر: G VPN، الخوادم، مسح QR. تعمل الصورة المحفوظة أيضًا.';
	@override String get saveImage => 'حفظ الصورة';
	@override String get send => 'إرسال';
}

// Path: add
class _Translations$add$ar extends Translations$add$en {
	_Translations$add$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'إضافة خادم';
	@override String get subtitle => 'أي خادم WireGuard: راوتر أو VPS أو خادم منزلي.';
	@override String get camera => 'المسح بالكاميرا';
	@override String get cameraSub => 'QR على شاشة أخرى';
	@override String get image => 'من صورة';
	@override String get imageSub => 'لقطة شاشة أو صورة محفوظة';
	@override String get noQr => 'لا يوجد رمز QR في هذه الصورة.';
	@override String get tip => 'وصلك رمز QR على واتساب أو تيليجرام؟ اضغط مشاركة على الصورة واختر G VPN.';
}

// Path: backup
class _Translations$backup$ar extends Translations$backup$en {
	_Translations$backup$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String restored({required Object n}) => 'تمت استعادة ${n} خوادم';
	@override String get nothingNew => 'هذه الخوادم موجودة بالفعل';
}

// Path: gs
class _Translations$gs$ar extends Translations$gs$en {
	_Translations$gs$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'خوادم G Servers لمشتركي G VPN Pro.';
	@override String get off => 'خوادم G Servers متوقفة الآن.';
	@override String get network => 'تعذّر الوصول إلى G Servers. تحقّق من اتصالك وحاول مجددًا.';
	@override String get active => 'نشط';
	@override String get servers => 'G Servers';
	@override String busy({required Object n}) => 'مشغول ${n}%';
	@override String get offline => 'غير متصل';
	@override String get devices => 'أجهزتك';
	@override String devicesSub({required Object n}) => 'حتى ${n} هواتف، لكل منها مفتاحه';
	@override String get footnote => 'يحصل كل هاتف على مفتاحه الخاص المُنشأ عليه. لا تحتفظ G Servers بسجلات نشاط.';
	@override String get leastBusy => 'الأقل انشغالًا الآن';
	@override String busyNoLogs({required Object n}) => 'مشغول ${n}% · بلا سجلات';
	@override String subtitle({required Object country}) => 'G Server · ${country} · WireGuard';
	@override String get busyLabel => 'الانشغال';
	@override String get status => 'الحالة';
	@override String get online => 'متصل';
	@override String get onThisServer => 'على هذا الخادم';
	@override String get thisPhone => 'هذا الهاتف';
	@override String get added => 'مُضاف · المفتاح أُنشئ هنا';
	@override String get notAdded => 'يُضاف عند الاتصال';
	@override String get logs => 'سجلات النشاط';
	@override String get noneKept => 'لا يُحتفظ بها';
	@override String get privacy => 'لا يعرف الخادم هذا الهاتف إلا بمفتاحه العام، ولا يحتفظ بأي سجل للمواقع التي تزورها أو البيانات التي ترسلها.';
	@override String get stepPro1 => 'ثبّت G VPN على الهاتف بحساب Google نفسه.';
	@override String get stepPro2 => 'افتح علامة تبويب Pro. يُفعَّل Pro تلقائيًا، أو اضغط استعادة.';
	@override String get step3 => 'اضغط اتصال. ينشئ الهاتف مفتاحه ويُضاف إلى G Servers. بلا QR وبلا رمز.';
	@override String get stepFree1 => 'ثبّت G VPN على الهاتف.';
	@override String get stepFree2 => 'افتح علامة تبويب Pro.';
	@override String get devicesIntroPro => 'يتبع Pro حسابك في Google. لكل هاتف مفتاحه، فلا يفصل أحدها الآخر.';
	@override String get devicesIntroFree => 'لكل هاتف مفتاحه، فلا تفصل الهواتف بعضها.';
	@override String get otherPhone => 'هاتف آخر';
	@override String lastConnected({required Object when}) => 'آخر اتصال ${when}';
	@override String get noDevices => 'اتصل بخادم G Server مرة وستظهر هواتفك هنا.';
	@override String get addTitle => 'إضافة هاتف أو إعادة التثبيت';
	@override String idle({required Object n}) => 'الهاتف الذي لم يتصل منذ ${n} يومًا يُزال تلقائيًا من G Servers، فلا يشغل هاتف قديم أو أُعيد تثبيته مكانًا.';
	@override String limitNote({required Object n}) => 'حتى ${n} هواتف لكل خطة.';
	@override String fullTitle({required Object n}) => 'كل الأماكن الـ ${n} مستخدمة';
	@override String get fullBody => 'أزل هاتفًا لم تعد تستخدمه، وسيتصل هذا الهاتف فورًا.';
	@override String get busyNow => 'هناك هواتف جديدة كثيرة الآن. حاول مجددًا بعد قليل.';
	@override String get serverFull => 'هذا الخادم ممتلئ. جرّب خادم G Server آخر.';
	@override String get ping => 'PING';
	@override String get last24 => 'الانشغال، آخر 24 ساعة';
	@override String get noHistory => 'يمتلئ الرسم مع استخدام الخادم خلال اليوم.';
	@override String chartLabel({required Object max}) => 'الانشغال خلال آخر 24 ساعة، بحد أقصى ${max} بالمئة';
	@override String get hoursAgo => 'قبل 24 س';
	@override String get now => 'الآن';
}

// Path: home.status
class _Translations$home$status$ar extends Translations$home$status$en {
	_Translations$home$status$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get paused => 'متوقف مؤقتًا';
	@override String get reconnecting => 'جارٍ إعادة الاتصال';
	@override String get protected => 'محمي';
	@override String get connecting => 'جارٍ الاتصال';
	@override String get stopping => 'جارٍ الإيقاف';
	@override String get notProtected => 'غير محمي';
}

// Path: home.waves
class _Translations$home$waves$ar extends Translations$home$waves$en {
	_Translations$home$waves$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get encrypted => 'مشفّر';
	@override String get securing => 'جارٍ التأمين';
	@override String get exposed => 'مكشوف';
}

// Path: home.network
class _Translations$home$network$ar extends Translations$home$network$en {
	_Translations$home$network$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'هذه الشبكة';
	@override String get wifi => 'Wi-Fi';
	@override String get offline => 'غير متصل';
	@override String get showName => 'إظهار الاسم';
	@override String get scanFailed => 'فشل الفحص. سيُعاد عند تغيّر الشبكة.';
}

// Path: home.card
class _Translations$home$card$ar extends Translations$home$card$en {
	_Translations$home$card$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get connectedVia => 'متصل عبر';
	@override String get protocol => 'البروتوكول';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9، داخل النفق';
	@override String get dnsServer => 'الخادم، داخل النفق';
	@override String get downloaded => 'تم تنزيله';
	@override String get uploaded => 'تم رفعه';
	@override String get wireguard => 'WireGuard';
	@override String openvpn({required Object proto}) => 'OpenVPN ${proto}';
	@override String get selected => 'المحدد';
	@override String get browsingFrom => 'تتصفح من';
	@override String get disconnect => 'قطع الاتصال';
	@override String get change => 'تغيير';
	@override String get enabled => 'مفعّل';
	@override String get shield => 'الدرع';
}

// Path: home.tiles
class _Translations$home$tiles$ar extends Translations$home$tiles$en {
	_Translations$home$tiles$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get shield => 'الدرع';
	@override String get shieldOn => 'يحظر المواقع الضارة';
	@override String get appsDirect => 'تطبيقات مباشرة';
	@override String get appsAll => 'كل التطبيقات محمية';
	@override String appsSkip({required Object n}) => '${n} دون VPN';
	@override String get autoConnect => 'اتصال تلقائي';
	@override String get autoOpen => 'على Wi-Fi العامة';
	@override String get autoAny => 'على كل Wi-Fi';
	@override String get speed => 'السرعة';
	@override String get speedTap => 'اضغط للاختبار';
	@override String speedDirect({required Object mbps}) => 'مباشر ${mbps} ميغابت/ث';
}

// Path: home.fastest
class _Translations$home$fastest$ar extends Translations$home$fastest$en {
	_Translations$home$fastest$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'أسرع خادم مجاني';
	@override String get pickedFrom => 'مختار من';
	@override String more({required Object n}) => '+${n}';
	@override String get finding => 'جارٍ البحث عن أسرع خادم';
	@override String get failed => 'تعذّر تحميل الخوادم المجانية';
	@override String get how => 'كيف يتم اختيار الخادم';
	@override String get sheetBody => 'يوصلك G VPN بالخادم المجاني الأعلى تقييمًا الآن، حسب السرعة والحمل ومدة التشغيل دون انقطاع. يتغير الترتيب مع ظهور الخوادم واختفائها.';
}

// Path: home.ip
class _Translations$home$ip$ar extends Translations$home$ip$en {
	_Translations$home$ip$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'ما تراه المواقع';
	@override String get real => 'موقعك الحقيقي';
	@override String get vpn => 'موقع VPN';
	@override String get address => 'عنوان IP';
	@override String get coordinates => 'الإحداثيات';
	@override String get note => 'تقدير من عنوان IP. لا يُخزَّن أبدًا.';
	@override String get hide => 'إخفاء موقعي';
	@override String near({required Object place}) => 'بالقرب من ${place}';
}

// Path: servers.tabs
class _Translations$servers$tabs$ar extends Translations$servers$tabs$en {
	_Translations$servers$tabs$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get pro => 'Pro';
	@override String get free => 'مجانية';
	@override String get yours => 'خوادمك';
}

// Path: servers.sheet
class _Translations$servers$sheet$ar extends Translations$servers$sheet$en {
	_Translations$servers$sheet$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'من أين تأتي الخوادم';
	@override String get subtitle => 'ثلاثة أنواع، قائمة واحدة';
	@override String get free => 'خوادم تطوعية تُفحص كل ساعتين. يحتفظ مشغّلوها بسجلات الاتصال نحو أسبوعين.';
	@override String get pro => 'نديرها بأنفسنا على WireGuard. بلا سجلات نشاط وبلا حساب.';
	@override String get yours => 'أي خادم WireGuard تديره: راوتر أو VPS أو خادم منزلي.';
}

// Path: servers.badges
class _Translations$servers$badges$ar extends Translations$servers$badges$en {
	_Translations$servers$badges$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get mostUsed => 'الأكثر استخدامًا';
	@override String get mostStable => 'الأكثر استقرارًا';
	@override String get fastest => 'الأسرع';
}

// Path: servers.filters
class _Translations$servers$filters$ar extends Translations$servers$filters$en {
	_Translations$servers$filters$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get all => 'الكل';
	@override String get fastest => 'الأسرع';
	@override String get stable => 'الأكثر استقرارًا';
	@override String get popular => 'الشائعة';
}

// Path: servers.own
class _Translations$servers$own$ar extends Translations$servers$own$en {
	_Translations$servers$own$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'شغّل خادمك الخاص';
	@override String get subtitle => 'أي خادم WireGuard يعمل';
	@override String get router => 'راوتر';
	@override String get routerBody => 'كثير من أجهزة الراوتر فيها WireGuard مدمج. صدّر إعدادات العميل وامسح رمز QR هنا.';
	@override String get vps => 'VPS';
	@override String get vpsBody => 'أي خادم Linux صغير. ثبّت WireGuard وأنشئ عميلًا واستورد ملف إعداداته.';
	@override String get home => 'خادم منزلي';
	@override String get homeBody => 'صِل إلى شبكتك من أي مكان بالطريقة نفسها.';
	@override String get noneYet => 'لا تملك خادمًا بعد؟';
	@override String get addAnother => 'إضافة آخر';
	@override String get hint => 'شغّله على راوتر أو VPS أو خادم منزلي';
}

// Path: pro.free
class _Translations$pro$free$ar extends Translations$pro$free$en {
	_Translations$pro$free$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'خطتك';
	@override String get headline => 'كل شيء مجاني';
	@override String get body => 'كل الخوادم وكل الأدوات، بلا حساب وبلا إعلانات.';
	@override String get included => 'يشمل';
	@override String get servers => 'خوادم مجانية';
	@override String get serversSub => 'مرتّبة حسب السرعة والاستقرار في عشرات الدول';
	@override String get own => 'خوادمك الخاصة';
	@override String get ownSub => 'اتصل بأي راوتر أو VPS أو خادم منزلي يعمل بـ WireGuard';
	@override String get shield => 'الدرع';
	@override String get shieldSub => 'يحظر مواقع البرامج الضارة والتصيّد المعروفة';
	@override String get auto => 'اتصال تلقائي وقواعد التطبيقات';
	@override String get autoSub => 'احمِ شبكات Wi-Fi العامة؛ ودع تطبيقات البنوك تتصل مباشرة';
	@override String get pause => 'الإيقاف المؤقت والإعدادات السريعة';
	@override String get pauseSub => 'أوقف مؤقتًا من الإشعار، وشغّل من البلاطة';
	@override String get tools => 'كل أدوات الشبكة';
	@override String get toolsSub => 'اختبار السرعة وping وحالة الخدمات وتتبّع المسار والأجهزة والمزيد';
	@override String get later => 'سيضيف G VPN Pro خوادم أسرع نديرها بأنفسنا. كل ما سبق يبقى مجانيًا.';
}

// Path: rules.info
class _Translations$rules$info$ar extends Translations$rules$info$en {
	_Translations$rules$info$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get shield => 'يرسل الدرع استعلامات DNS إلى Quad9 الذي يرفض مواقع البرامج الضارة والتصيّد المعروفة. لا يحظر الإعلانات، ويحلّ محل DNS الخادم أثناء تشغيله.';
	@override String get autoConnect => 'الاتصال التلقائي: يستخدم خادم WireGuard الذي اخترته. قطع الاتصال يدويًا يوقفه مؤقتًا حتى تنضم إلى شبكة أخرى.';
	@override String get apps => 'التطبيقات المباشرة: التطبيقات المستثناة من VPN تتصل مباشرة. كثيرًا ما تحظر البنوك عناوين VPN، لذا قد تفشل المدفوعات عبر VPN.';
	@override String get reconnect => 'تغيير الدرع أو التطبيقات يعيد اتصال VPN للحظة.';
	@override String get stay => 'البقاء متصلًا: بعض الهواتف توقف التطبيقات في الخلفية لتوفير البطارية. يبقي VPN الدائم وإعداد البطارية غير المقيّد تطبيق G VPN يعمل.';
}

/// The flat map containing all translations for locale <ar>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsAr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.gotIt' => 'فهمت',
			'common.about' => 'حول',
			'common.connect' => 'اتصال',
			'common.connected' => 'متصل',
			'common.retry' => 'إعادة المحاولة',
			'common.ok' => 'حسنًا',
			'common.remove' => 'إزالة',
			'common.cancel' => 'إلغاء',
			'common.continueLabel' => 'متابعة',
			'common.notNow' => 'ليس الآن',
			'common.openSettings' => 'فتح الإعدادات',
			'common.close' => 'إغلاق',
			'common.off' => 'متوقف',
			'common.changesReconnect' => 'التغييرات تعيد اتصال VPN',
			'nav.vpn' => 'VPN',
			'nav.servers' => 'الخوادم',
			'nav.tools' => 'الأدوات',
			'nav.rules' => 'القواعد',
			'nav.pro' => 'Pro',
			'home.status.paused' => 'متوقف مؤقتًا',
			'home.status.reconnecting' => 'جارٍ إعادة الاتصال',
			'home.status.protected' => 'محمي',
			'home.status.connecting' => 'جارٍ الاتصال',
			'home.status.stopping' => 'جارٍ الإيقاف',
			'home.status.notProtected' => 'غير محمي',
			'home.resumesAt' => ({required Object time}) => 'يُستأنف عند ${time} · اضغط للاستئناف الآن',
			'home.sitesSee' => ({required Object ip}) => 'المواقع ترى ${ip}',
			'home.sitesSeeOrg' => ({required Object ip, required Object org}) => 'المواقع ترى ${ip} · ${org}',
			'home.ipFailed' => 'تعذّر التحقق من عنوان IP',
			'home.ipChecking' => 'جارٍ التحقق من عنوان IP',
			'home.themeSystem' => 'المظهر: حسب الهاتف',
			'home.themeLight' => 'المظهر: فاتح',
			'home.themeDark' => 'المظهر: داكن',
			'home.free' => 'مجاني',
			'home.pickServer' => 'اختر خادمًا',
			'home.waves.encrypted' => 'مشفّر',
			'home.waves.securing' => 'جارٍ التأمين',
			'home.waves.exposed' => 'مكشوف',
			'home.network.title' => 'هذه الشبكة',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'غير متصل',
			'home.network.showName' => 'إظهار الاسم',
			'home.network.scanFailed' => 'فشل الفحص. سيُعاد عند تغيّر الشبكة.',
			'home.card.connectedVia' => 'متصل عبر',
			'home.card.protocol' => 'البروتوكول',
			'home.card.dns' => 'DNS',
			'home.card.dnsQuad9' => 'Quad9، داخل النفق',
			'home.card.dnsServer' => 'الخادم، داخل النفق',
			'home.card.downloaded' => 'تم تنزيله',
			'home.card.uploaded' => 'تم رفعه',
			'home.card.wireguard' => 'WireGuard',
			'home.card.openvpn' => ({required Object proto}) => 'OpenVPN ${proto}',
			'home.card.selected' => 'المحدد',
			'home.card.browsingFrom' => 'تتصفح من',
			'home.card.disconnect' => 'قطع الاتصال',
			'home.card.change' => 'تغيير',
			'home.card.enabled' => 'مفعّل',
			'home.card.shield' => 'الدرع',
			'home.tiles.shield' => 'الدرع',
			'home.tiles.shieldOn' => 'يحظر المواقع الضارة',
			'home.tiles.appsDirect' => 'تطبيقات مباشرة',
			'home.tiles.appsAll' => 'كل التطبيقات محمية',
			'home.tiles.appsSkip' => ({required Object n}) => '${n} دون VPN',
			'home.tiles.autoConnect' => 'اتصال تلقائي',
			'home.tiles.autoOpen' => 'على Wi-Fi العامة',
			'home.tiles.autoAny' => 'على كل Wi-Fi',
			'home.tiles.speed' => 'السرعة',
			'home.tiles.speedTap' => 'اضغط للاختبار',
			'home.tiles.speedDirect' => ({required Object mbps}) => 'مباشر ${mbps} ميغابت/ث',
			'home.fastest.title' => 'أسرع خادم مجاني',
			'home.fastest.pickedFrom' => 'مختار من',
			'home.fastest.more' => ({required Object n}) => '+${n}',
			'home.fastest.finding' => 'جارٍ البحث عن أسرع خادم',
			'home.fastest.failed' => 'تعذّر تحميل الخوادم المجانية',
			'home.fastest.how' => 'كيف يتم اختيار الخادم',
			'home.fastest.sheetBody' => 'يوصلك G VPN بالخادم المجاني الأعلى تقييمًا الآن، حسب السرعة والحمل ومدة التشغيل دون انقطاع. يتغير الترتيب مع ظهور الخوادم واختفائها.',
			'home.ip.title' => 'ما تراه المواقع',
			'home.ip.real' => 'موقعك الحقيقي',
			'home.ip.vpn' => 'موقع VPN',
			'home.ip.address' => 'عنوان IP',
			'home.ip.coordinates' => 'الإحداثيات',
			'home.ip.note' => 'تقدير من عنوان IP. لا يُخزَّن أبدًا.',
			'home.ip.hide' => 'إخفاء موقعي',
			'home.ip.near' => ({required Object place}) => 'بالقرب من ${place}',
			'servers.title' => 'الخوادم',
			'servers.aboutServers' => 'حول الخوادم',
			'servers.tabs.pro' => 'Pro',
			'servers.tabs.free' => 'مجانية',
			'servers.tabs.yours' => 'خوادمك',
			'servers.sheet.title' => 'من أين تأتي الخوادم',
			'servers.sheet.subtitle' => 'ثلاثة أنواع، قائمة واحدة',
			'servers.sheet.free' => 'خوادم تطوعية تُفحص كل ساعتين. يحتفظ مشغّلوها بسجلات الاتصال نحو أسبوعين.',
			'servers.sheet.pro' => 'نديرها بأنفسنا على WireGuard. بلا سجلات نشاط وبلا حساب.',
			'servers.sheet.yours' => 'أي خادم WireGuard تديره: راوتر أو VPS أو خادم منزلي.',
			'servers.badges.mostUsed' => 'الأكثر استخدامًا',
			'servers.badges.mostStable' => 'الأكثر استقرارًا',
			'servers.badges.fastest' => 'الأسرع',
			'servers.filters.all' => 'الكل',
			'servers.filters.fastest' => 'الأسرع',
			'servers.filters.stable' => 'الأكثر استقرارًا',
			'servers.filters.popular' => 'الشائعة',
			'servers.loadFailed' => 'تعذّر تحميل القائمة',
			'servers.noServers' => 'لا توجد خوادم الآن',
			'servers.best' => 'الأفضل لك الآن',
			'servers.topRanked' => 'الأعلى تقييمًا الآن',
			'servers.addHeading' => 'إضافة خادم',
			'servers.scanQr' => 'مسح QR',
			'servers.importFile' => 'استيراد ملف',
			'servers.paste' => 'لصق',
			'servers.own.title' => 'شغّل خادمك الخاص',
			'servers.own.subtitle' => 'أي خادم WireGuard يعمل',
			'servers.own.router' => 'راوتر',
			'servers.own.routerBody' => 'كثير من أجهزة الراوتر فيها WireGuard مدمج. صدّر إعدادات العميل وامسح رمز QR هنا.',
			'servers.own.vps' => 'VPS',
			'servers.own.vpsBody' => 'أي خادم Linux صغير. ثبّت WireGuard وأنشئ عميلًا واستورد ملف إعداداته.',
			'servers.own.home' => 'خادم منزلي',
			'servers.own.homeBody' => 'صِل إلى شبكتك من أي مكان بالطريقة نفسها.',
			'servers.own.noneYet' => 'لا تملك خادمًا بعد؟',
			'servers.own.addAnother' => 'إضافة آخر',
			'servers.own.hint' => 'شغّله على راوتر أو VPS أو خادم منزلي',
			'servers.configBroken' => 'الإعدادات تحتاج إلى مراجعة',
			'servers.connectedBadge' => 'متصل',
			'servers.scannedServer' => 'خادم ممسوح',
			'servers.scanFailedTitle' => 'تعذّر المسح',
			'servers.scanFailedBody' => 'الماسح غير متاح على هذا الهاتف.',
			'servers.importFailedTitle' => 'تعذّر الاستيراد',
			'servers.importFailedBody' => 'تعذّرت قراءة هذا الملف.',
			'servers.renameTitle' => 'إعادة تسمية الخادم',
			'servers.nameHint' => 'الاسم، مثلًا راوتر المنزل',
			'servers.save' => 'حفظ',
			'servers.rename' => 'إعادة تسمية',
			'servers.disconnect' => 'قطع الاتصال',
			'servers.more' => 'خيارات أخرى',
			'servers.justNow' => 'الآن',
			'servers.minutesAgo' => ({required Object n}) => 'قبل ${n} د',
			'servers.hoursAgo' => ({required Object n}) => 'قبل ${n} س',
			'servers.daysAgo' => ({required Object n}) => 'قبل ${n} يوم',
			'servers.neverUsed' => 'لم يُستخدم بعد',
			'servers.lastUsed' => ({required Object when}) => 'آخر استخدام ${when}',
			'servers.disconnectFirst' => 'اقطع الاتصال أولًا لإزالته',
			'servers.removeConfirm' => 'إزالة هذا الخادم من G VPN؟ تُحذف إعداداته من هذا الهاتف؛ ولا يتغيّر الخادم نفسه.',
			'pro.owned' => 'لديك Pro',
			'pro.waitingPlay' => 'بانتظار Google Play',
			'pro.startTrial' => ({required Object days}) => 'ابدأ تجربة مجانية لمدة ${days} يومًا',
			'pro.thenYearly' => ({required Object price}) => 'ثم ${price} سنويًا. ألغِ في أي وقت من Google Play.',
			'pro.thenMonthly' => ({required Object price}) => 'ثم ${price} شهريًا. ألغِ في أي وقت من Google Play.',
			'pro.yearlyPrice' => ({required Object price}) => '${price} سنويًا. ألغِ في أي وقت من Google Play.',
			'pro.monthlyPrice' => ({required Object price}) => '${price} شهريًا. ألغِ في أي وقت من Google Play.',
			'pro.restore' => 'استعادة',
			'pro.heroTitle' => 'خوادم أسرع،\nنديرها بأنفسنا',
			'pro.heroSubtitle' => 'WireGuard. بلا سجلات نشاط. بلا حساب.',
			'pro.benefitSpeed' => 'سرعة كاملة، بلا قيود الخوادم التطوعية',
			'pro.benefitKey' => 'المفتاح يُنشأ على هاتفك ولا يُشارَك أبدًا',
			'pro.benefitFree' => 'كل ما هو مجاني يبقى مجانيًا',
			'pro.save' => ({required Object pct}) => 'وفّر ${pct}%',
			'pro.yearly' => 'سنوي',
			'pro.monthly' => 'شهري',
			'pro.billedMonthly' => 'يُدفع شهريًا',
			'pro.daysFree' => ({required Object days}) => '${days} يومًا مجانًا',
			'pro.perMonth' => ({required Object price}) => '${price} شهريًا',
			'pro.title' => 'G VPN Pro',
			'pro.heroTitleOneLine' => 'خوادم أسرع نديرها بأنفسنا',
			'pro.includes' => 'يشمل',
			'pro.benefitLogs' => 'بلا سجلات نشاط على خوادمنا',
			'pro.plan' => 'اختر خطة',
			'pro.renewGeneric' => 'تتجدد الاشتراكات تلقائيًا حتى إلغائها. ألغِ في أي وقت من Google Play.',
			'pro.renewTrial' => ({required Object days, required Object price, required Object period}) => '${days} يومًا مجانًا، ثم ${price} لكل ${period}. يتجدد تلقائيًا حتى الإلغاء؛ ألغِ من Google Play قبل انتهاء التجربة بيوم على الأقل لتجنّب الدفع.',
			'pro.renew' => ({required Object price, required Object period}) => '${price} لكل ${period}. يتجدد تلقائيًا حتى الإلغاء؛ ألغِ في أي وقت من Google Play.',
			'pro.year' => 'سنة',
			'pro.month' => 'شهر',
			'pro.manage' => 'إدارة الاشتراك',
			'pro.free.title' => 'خطتك',
			'pro.free.headline' => 'كل شيء مجاني',
			'pro.free.body' => 'كل الخوادم وكل الأدوات، بلا حساب وبلا إعلانات.',
			'pro.free.included' => 'يشمل',
			'pro.free.servers' => 'خوادم مجانية',
			'pro.free.serversSub' => 'مرتّبة حسب السرعة والاستقرار في عشرات الدول',
			'pro.free.own' => 'خوادمك الخاصة',
			'pro.free.ownSub' => 'اتصل بأي راوتر أو VPS أو خادم منزلي يعمل بـ WireGuard',
			'pro.free.shield' => 'الدرع',
			'pro.free.shieldSub' => 'يحظر مواقع البرامج الضارة والتصيّد المعروفة',
			'pro.free.auto' => 'اتصال تلقائي وقواعد التطبيقات',
			'pro.free.autoSub' => 'احمِ شبكات Wi-Fi العامة؛ ودع تطبيقات البنوك تتصل مباشرة',
			'pro.free.pause' => 'الإيقاف المؤقت والإعدادات السريعة',
			'pro.free.pauseSub' => 'أوقف مؤقتًا من الإشعار، وشغّل من البلاطة',
			'pro.free.tools' => 'كل أدوات الشبكة',
			'pro.free.toolsSub' => 'اختبار السرعة وping وحالة الخدمات وتتبّع المسار والأجهزة والمزيد',
			'pro.free.later' => 'سيضيف G VPN Pro خوادم أسرع نديرها بأنفسنا. كل ما سبق يبقى مجانيًا.',
			'rules.title' => 'القواعد',
			'rules.info.shield' => 'يرسل الدرع استعلامات DNS إلى Quad9 الذي يرفض مواقع البرامج الضارة والتصيّد المعروفة. لا يحظر الإعلانات، ويحلّ محل DNS الخادم أثناء تشغيله.',
			'rules.info.autoConnect' => 'الاتصال التلقائي: يستخدم خادم WireGuard الذي اخترته. قطع الاتصال يدويًا يوقفه مؤقتًا حتى تنضم إلى شبكة أخرى.',
			'rules.info.apps' => 'التطبيقات المباشرة: التطبيقات المستثناة من VPN تتصل مباشرة. كثيرًا ما تحظر البنوك عناوين VPN، لذا قد تفشل المدفوعات عبر VPN.',
			'rules.info.reconnect' => 'تغيير الدرع أو التطبيقات يعيد اتصال VPN للحظة.',
			'rules.info.stay' => 'البقاء متصلًا: بعض الهواتف توقف التطبيقات في الخلفية لتوفير البطارية. يبقي VPN الدائم وإعداد البطارية غير المقيّد تطبيق G VPN يعمل.',
			'rules.protection' => 'الحماية',
			'rules.shield' => 'الدرع',
			'rules.shieldSub' => 'يحظر مواقع البرامج الضارة والتصيّد',
			'rules.privateDns' => 'الدرع دون VPN',
			'rules.privateDnsSub' => 'انسخ dns.quad9.net لاستخدامه في DNS الخاص',
			'rules.privateDnsCopied' => 'تم نسخ dns.quad9.net',
			'rules.privateDnsHow' => 'افتح الإعدادات وابحث عن "DNS الخاص" واختر "اسم مضيف مزوّد DNS الخاص" ثم الصقه.',
			'rules.stay' => 'البقاء متصلًا',
			'rules.alwaysOn' => 'VPN دائم التشغيل',
			'rules.alwaysOnSub' => 'يعيد Android تشغيل G VPN إذا توقف',
			'rules.battery' => 'البطارية',
			'rules.batteryOk' => 'غير مقيّد',
			'rules.batteryRestricted' => 'مقيّد: قد يتوقف في الخلفية',
			'rules.autoConnect' => 'اتصال تلقائي',
			'rules.autoOff' => 'متوقف',
			'rules.autoOffSub' => 'فقط عند الضغط',
			'rules.autoOpen' => 'Wi-Fi العامة',
			'rules.autoOpenSub' => 'الشبكات المفتوحة أو WEP أو التي تتطلب تسجيل دخول',
			'rules.autoAny' => 'كل Wi-Fi',
			'rules.autoAnySub' => 'أي شبكة Wi-Fi',
			'rules.apps' => 'التطبيقات',
			'rules.appsDirect' => 'تطبيقات مباشرة',
			'rules.appsNone' => 'كل التطبيقات تستخدم VPN',
			'rules.appsSome' => ({required Object n}) => '${n} تطبيقات دون VPN',
			'rules.appearance' => 'المظهر',
			'rules.themePhone' => 'الهاتف',
			'rules.themeLight' => 'فاتح',
			'rules.themeDark' => 'داكن',
			'rules.about' => 'حول',
			'apps.title' => 'تطبيقات مباشرة',
			'apps.sheetSubtitle' => 'التطبيقات المختارة تتصل دون VPN. كل ما عداها يبقى محميًا.',
			'apps.whyTitle' => 'لماذا تستثني تطبيقًا',
			'apps.whyBody' => 'كثيرًا ما تحظر البنوك وتطبيقات الدفع عناوين VPN، لذا قد تفشل المدفوعات عبر VPN. بعض الخدمات المحلية لا تعمل إلا من بلدك.',
			'apps.favouritesBody' => 'ضع نجمة على التطبيقات التي تغيّرها كثيرًا؛ تبقى في الأعلى.',
			'apps.whileConnected' => 'أثناء الاتصال',
			'apps.whileConnectedBody' => 'تغيير هذه القائمة يعيد اتصال VPN للحظة.',
			'apps.search' => ({required Object n}) => 'ابحث في ${n} تطبيق',
			'apps.skipping' => 'دون VPN',
			'apps.skippingNone' => 'لا شيء. كل التطبيقات تمر عبر VPN.',
			'apps.protectAgain' => ({required Object app}) => 'حماية ${app} مجددًا',
			'apps.banking' => 'البنوك والمدفوعات',
			'apps.bankingFound' => ({required Object n}) => 'عُثر على ${n} قد تحظر VPN',
			'apps.addAll' => 'إضافة الكل',
			'apps.favourites' => 'المفضلة',
			'apps.all' => 'كل التطبيقات',
			'apps.found' => ({required Object n}) => 'عُثر على ${n}',
			'apps.noMatch' => 'لا يوجد تطبيق مطابق.',
			'apps.showAll' => ({required Object n}) => 'عرض الكل (${n})',
			'apps.skips' => 'دون VPN',
			'apps.unstar' => 'إزالة من المفضلة',
			'apps.star' => 'إضافة إلى المفضلة',
			'location.title' => 'السماح بالموقع لشبكة Wi-Fi',
			'location.useHome' => 'إظهار اسم Wi-Fi في الصفحة الرئيسية',
			'location.useScan' => 'فحص الشبكات والقنوات القريبة',
			'location.private' => 'يبقى على هذا الهاتف. لا يُجمع موقعك أبدًا.',
			'location.switchTitle' => 'شغّل خدمة الموقع',
			'location.switchBody' => 'يخفي Android أسماء Wi-Fi عندما تكون خدمة الموقع متوقفة',
			'addServer.clipboardEmpty' => 'الحافظة فارغة.',
			'addServer.title' => 'أضف خادمك',
			'addServer.body' => 'الصق إعدادات WireGuard من الراوتر أو VPS أو الخادم المنزلي.',
			'addServer.nameHint' => 'الاسم، مثلًا راوتر المنزل',
			'addServer.paste' => 'لصق',
			'addServer.save' => 'حفظ الخادم',
			'addServer.notWireguard' => ({required Object error}) => 'هذه ليست إعدادات WireGuard: ${error}',
			'button.stop' => 'إيقاف',
			'button.connecting' => 'جارٍ الاتصال',
			'button.stopping' => 'جارٍ الإيقاف',
			'button.connect' => 'اتصال',
			'button.disconnect' => 'قطع الاتصال',
			'wol.info' => 'يشغّل حاسوبًا أو NAS على شبكة Wi-Fi هذه إذا كان Wake on LAN مفعّلًا في إعداداته. يجب أن يكون هاتفك على الشبكة نفسها؛ أوقف VPN أولًا.',
			'wol.badMac' => 'هذا ليس عنوان MAC. شكله مثل AA:BB:CC:DD:EE:FF.',
			'wol.sent' => 'أُرسلت إشارة التشغيل. يُفترض أن يعمل الجهاز خلال دقيقة.',
			'wol.title' => 'Wake on LAN',
			'wol.wake' => 'تشغيل الجهاز',
			'wol.mac' => 'عنوان MAC',
			'wol.failed' => ({required Object error}) => 'تعذّر الإرسال: ${error}',
			'speed.info' => 'تقيسه منصة M-Lab البحثية المفتوحة. يستهلك الاختبار نحو 50 إلى 100 ميغابايت.\n\nنتائج علنية: تنشر M-Lab كل اختبار، بما فيه عنوان IP الذي جاء منه، كبيانات بحثية مفتوحة.\n\nمقارنة المزوّدين: بعد اختبار دون VPN، يرسل G VPN أرقام السرعة الثلاثة فقط. تقرأ خدمة المقارنة مزوّدك ومدينتك من الاتصال نفسه ولا تخزّن أي عنوان IP. أوقفها بالمفتاح أسفل هذه الصفحة.\n\nعبر VPN: عند تشغيل VPN يقيس السرعة عبر النفق ويقارنها بآخر اختبار دونه.\n\nمعاينة الفيديو: الصورة نفسها بالدقة التي تتيحها هذه السرعة، وفق معدلات البت التي تنشرها خدمات البث. لا يُنزَّل أي فيديو.',
			'speed.download' => 'التنزيل',
			'speed.upload' => 'الرفع',
			'speed.finding' => 'جارٍ البحث عن خادم',
			'speed.throughVpn' => 'عبر VPN',
			'speed.directNoVpn' => 'مباشر، دون VPN',
			'speed.title' => 'اختبار السرعة',
			'speed.stop' => 'إيقاف',
			'speed.start' => 'بدء الاختبار',
			'speed.again' => 'اختبار مجددًا',
			'speed.viaVpn' => 'عبر VPN',
			'speed.direct' => 'مباشر',
			'speed.mbps' => 'ميغابت/ث',
			'speed.ping' => 'PING',
			'speed.vsDirect' => 'مقابل المباشر',
			'speed.compare' => 'قارن بالمزوّدين القريبين',
			'speed.compareSub' => 'يشارك السرعات فقط، ولا يشارك عنوان IP أبدًا',
			'speed.tierTv' => 'أجهزة التلفاز الكبيرة',
			'speed.tierLaptopLarge' => 'الحواسيب المحمولة الكبيرة',
			'speed.tierTablet' => 'الأجهزة اللوحية والحواسيب',
			'speed.tierPhone' => 'الهواتف',
			'speed.tierSmallPhone' => 'الهواتف الصغيرة',
			'speed.tierCalls' => 'المكالمات والصوت',
			'speed.messagingOnly' => 'المراسلة فقط',
			'speed.videoQuality' => 'جودة الفيديو',
			'speed.preview' => 'معاينة',
			'speed.history' => 'السجل',
			'speed.clear' => 'مسح',
			'speed.viaVpnLower' => 'عبر VPN',
			'speed.directLower' => 'مباشر',
			'speed.gradeA' => 'عدة بثوث 4K ومكالمات فيديو في الوقت نفسه',
			'speed.gradeB' => 'بث HD ومكالمات فيديو سلسة',
			'speed.gradeC' => 'بث HD واحد؛ قد تتقطع المكالمات في أوقات الذروة',
			'speed.gradeD' => 'تصفّح ومراسلة؛ الفيديو يتعثّر',
			'speed.yourCountry' => 'بلدك',
			'speed.median' => 'متوسط التنزيل (الوسيط)، آخر 30 يومًا',
			'speed.fromUsers' => 'ميغابت/ث · من اختبارات مستخدمي G VPN',
			'speed.costLittle' => 'VPN يقلّل السرعة قليلًا',
			'speed.costNoticeable' => 'أبطأ بشكل ملحوظ من المباشر',
			'speed.costMuch' => 'أبطأ بكثير. جرّب خادمًا آخر',
			'speed.ofDirect' => 'من سرعتك المباشرة',
			'speed.none' => 'لا شيء',
			'speed.ms' => ({required Object n}) => '${n} مللي ثانية',
			'speed.previewTier' => ({required Object tier}) => 'معاينة · ${tier}',
			'speed.streamsUpTo' => ({required Object tier, required Object who}) => 'يبث حتى ${tier} · ${who}',
			'speed.today' => ({required Object time}) => 'اليوم، ${time}',
			'speed.tests' => ({required Object n}) => '${n} اختبارات',
			'speed.gradeVpn' => ({required Object label}) => '${label} عبر VPN',
			'speed.gradeIsp' => ({required Object label, required Object isp}) => '${label} على ${isp}',
			'speed.notEnough' => ({required Object isp}) => 'لا توجد اختبارات كافية بعد لـ ${isp}',
			'speed.yourProvider' => 'مزوّدك',
			'speed.rankLine' => ({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} في ${where}: المرتبة ${rank} من ${of}',
			'speed.costLine' => ({required Object note, required Object mbps}) => '${note} · المباشر ${mbps} ميغابت/ث',
			'speed.mbpsValue' => ({required Object v}) => '${v} ميغابت/ث',
			'speed.gradeExcellent' => 'ممتاز',
			'speed.gradeVeryGood' => 'جيد جدًا',
			'speed.gradeGood' => 'جيد',
			'speed.gradeFair' => 'مقبول',
			'speed.gradeSlow' => 'بطيء',
			'speed.gradeVerySlow' => 'بطيء جدًا',
			'router.info' => 'يسأل الراوتر عبر UPnP عمّا إذا كان بإمكان الأجهزة فتح منافذ إلى الإنترنت بنفسها، ويعرض ما فتحته. يقرأ فقط ولا يغيّر شيئًا. إن لم يكن هناك ما يحتاج UPnP (بعض أجهزة الألعاب تحتاجه)، فإيقافه من إعدادات الراوتر أكثر أمانًا.',
			'router.title' => 'فحص الراوتر',
			'router.asking' => 'جارٍ سؤال الراوتر',
			'router.again' => 'افحص مجددًا',
			'router.check' => 'فحص الراوتر',
			'router.off' => 'UPnP متوقف',
			'router.offBody' => 'لا تستطيع الأجهزة فتح منافذ بنفسها.',
			'router.onBody' => 'لا توجد منافذ مفتوحة عبره الآن.',
			'router.checkEach' => 'تأكّد من أنك تعرف كل واحد منها.',
			'router.cgnat' => 'عنوان مشترك لدى المزوّد: لا يمكن الوصول إليه من الإنترنت.',
			'router.noDescription' => 'بلا وصف',
			'router.opened' => ({required Object n}) => '${n} منافذ فتحتها الأجهزة',
			'router.routerName' => ({required Object name}) => 'الراوتر: ${name}',
			'router.externalIp' => ({required Object ip}) => 'عنوان الإنترنت: ${ip}',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} إلى ${host}',
			'router.upnpOn' => 'UPnP مفعّل',
			'network.title' => 'هذه الشبكة',
			'network.wifi' => 'Wi-Fi',
			'network.mobile' => 'بيانات الجوال',
			'network.ethernet' => 'Ethernet',
			'network.offline' => 'غير متصل',
			'network.risky' => 'شبكة خطرة. شغّل VPN هنا.',
			'network.review' => 'تستحق نظرة قبل أن تثق بها.',
			'network.covered' => 'محمية بـ VPN.',
			'network.safe' => 'تبدو هذه الشبكة آمنة.',
			'network.mobileSentence' => 'بيانات الجوال.',
			'network.notConnected' => 'غير متصل.',
			'network.showName' => 'إظهار الاسم',
			'network.sitesSee' => 'المواقع ترى',
			'network.provider' => 'المزوّد',
			'network.location' => 'الموقع',
			'network.couldNotCheck' => 'تعذّر التحقق',
			'network.checking' => 'جارٍ التحقق',
			'network.signal' => 'الإشارة',
			'network.linkSpeed' => 'سرعة الاتصال',
			'network.gateway' => 'البوابة',
			'network.none' => 'لا يوجد',
			'network.privateDns' => 'DNS الخاص',
			'network.automatic' => 'تلقائي',
			'network.off' => 'متوقف',
			'network.metered' => 'محدودة البيانات',
			'network.yes' => 'نعم',
			'network.no' => 'لا',
			'network.readFailed' => ({required Object error}) => 'تعذّرت قراءة الشبكة: ${error}',
			'devices.info' => 'يطرق كل عنوان في نطاق شبكة Wi-Fi ويطلب من الأجهزة أن تعرّف بنفسها. الجهاز الذي يرفض يُحتسب أيضًا: الرفض يثبت وجوده.\n\nالأسماء: مما تنشره الأجهزة (Bonjour وUPnP وأسماء Windows) ومن الراوتر.\n\nالأجهزة المجهولة: يخفي Android العناوين المادية عن التطبيقات، لذا لا يمكن التعرّف على جهاز صامت بلا اسم معلن. راجع قائمة الأجهزة في الراوتر لمعرفتها.\n\nجديد: جهاز لم يظهر في آخر فحص لهذه الشبكة.',
			'devices.needWifi' => 'اتصل بشبكة Wi-Fi أولًا.',
			'devices.title' => 'الأجهزة',
			'devices.again' => 'افحص مجددًا',
			'devices.looking' => 'جارٍ البحث عن الأجهزة',
			'devices.nothingNew' => 'لا جديد منذ آخر فحص',
			'devices.takes' => 'يستغرق نحو 30 ثانية',
			'devices.all' => 'الكل',
			'devices.phones' => 'الهواتف',
			'devices.tvs' => 'التلفاز',
			'devices.computers' => 'الحواسيب',
			'devices.other' => 'أخرى',
			'devices.thisPhone' => 'هذا الهاتف',
			'devices.router' => 'الراوتر',
			'devices.unknown' => 'جهاز مجهول',
			'devices.address' => 'العنوان',
			'devices.answersIn' => 'يستجيب خلال',
			'devices.type' => 'النوع',
			'devices.notAnnounced' => 'لم يعرّف بنفسه. يمكن لقائمة الأجهزة في الراوتر تسميته.',
			'devices.newBadge' => 'جديد',
			'devices.scanning' => ({required Object n}) => 'جارٍ فحص ${n} من 254',
			'devices.thisNetwork' => 'هذه الشبكة',
			'devices.newSince' => ({required Object n}) => '${n} جديد منذ آخر فحص',
			'devices.showMore' => ({required Object n}) => 'عرض ${n} أخرى',
			'devices.ms' => ({required Object n}) => '${n} مللي ثانية',
			'devices.onNetwork' => ({required Object network}) => 'أجهزة على ${network}',
			'ping.info' => 'المدة التي تستغرقها رحلة ذهاب وإياب واحدة إلى الخادم، تُقاس كل ثانية خلال الدقيقة الأخيرة.\n\nالتذبذب: مقدار اختلاف كل رد عن الذي قبله. التذبذب العالي هو ما يقطع المكالمات.\n\nالفقدان: ردود لم تعد أبدًا.\n\nالطريقة: لا تستطيع تطبيقات Android إرسال ping التقليدي، لذا يقيس كل اختبار زمن إنشاء اتصال، وهو رحلة الذهاب والإياب نفسها.',
			'ping.askTitle' => 'Ping لمضيف',
			'ping.askHint' => 'example.com أو 192.168.1.10',
			'ping.cancel' => 'إلغاء',
			'ping.title' => 'Ping',
			'ping.router' => 'الراوتر',
			'ping.pause' => 'إيقاف مؤقت',
			'ping.start' => 'بدء',
			'ping.host' => 'مضيف',
			'ping.live' => 'مباشر',
			'ping.ago' => 'قبل 60 ث',
			'ping.min' => 'الأدنى',
			'ping.avg' => 'المتوسط',
			'ping.jitter' => 'التذبذب',
			'ping.loss' => 'الفقدان',
			'ping.goodFor' => 'مناسب لـ',
			'ping.calls' => 'مكالمات الفيديو',
			'ping.games' => 'الألعاب عبر الإنترنت',
			'ping.streaming' => 'البث',
			'ping.great' => 'ممتاز',
			'ping.okay' => 'مقبول',
			'ping.poor' => 'ضعيف',
			'ping.lost' => 'مفقود',
			'ping.now' => 'الآن',
			'status.info' => 'يتصل بكل خدمة ثلاث مرات ويعرض أسرع رد.\n\nمحظور هنا: الخدمة التي لا تستجيب مباشرة لكنها تعمل عبر VPN محظورة من شبكتك أو بلدك.\n\nالسجل: فحوصات آخر 24 ساعة من هذا الهاتف، محفوظة على هذا الهاتف فقط.',
			'status.title' => 'حالة الخدمات',
			'status.checking' => 'جارٍ الفحص',
			'status.again' => 'افحص مجددًا',
			'status.viaVpn' => 'تم الفحص عبر VPN',
			'status.direct' => 'تم الفحص مباشرة',
			'status.favourites' => 'المفضلة',
			'status.edit' => 'تعديل',
			'status.last24' => 'آخر 24 ساعة',
			'status.ago' => 'قبل 24 س',
			'status.all' => 'كل الخدمات',
			'status.pickFour' => 'اختر حتى أربع',
			'status.outage' => 'حتى عبر VPN: غالبًا انقطاع',
			'status.blocked' => 'قد يكون محظورًا على هذه الشبكة',
			'status.connect' => 'اتصال',
			'status.blockedShort' => 'محظور',
			'status.unreachable' => 'يتعذّر الوصول',
			'status.now' => 'الآن',
			'status.checks' => ({required Object n}) => '${n} فحوصات',
			'status.andMore' => ({required Object first, required Object n}) => '${first} و${n} أخرى',
			'status.notReachable' => ({required Object who}) => '${who} يتعذّر الوصول إليه',
			'tools.wifi' => 'Wi-Fi',
			'tools.mobile' => 'بيانات الجوال',
			'tools.ethernet' => 'Ethernet',
			'tools.checking' => 'جارٍ التحقق',
			'tools.offline' => 'غير متصل',
			'tools.title' => 'الأدوات',
			'tools.networkDesc' => 'فحص الأمان، وما تراه المواقع، والإشارة، والراوتر وDNS.',
			'tools.internet' => 'الاتصال بالإنترنت',
			'tools.speed' => 'اختبار السرعة',
			'tools.speedDesc' => 'سرعة التنزيل والرفع، وجودة الفيديو التي تدعمها.',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'زمن الاستجابة والتذبذب مباشرة إلى أي خادم أو إلى الراوتر.',
			'tools.status' => 'حالة الخدمات',
			'tools.statusDesc' => 'هل يمكن الوصول إلى WhatsApp أو YouTube أو Google من هنا، أم أنها محظورة؟',
			'tools.trace' => 'تتبّع المسار',
			'tools.traceDesc' => 'كل راوتر بينك وبين موقع ما، والوقت الذي يستغرقه كل منها.',
			'tools.security' => 'أمان الشبكة',
			'tools.devices' => 'الأجهزة على هذه الشبكة',
			'tools.devicesDesc' => 'من غيرك على Wi-Fi: هواتف وتلفاز وكاميرات وحواسيب.',
			'tools.router' => 'فحص الراوتر',
			'tools.routerDesc' => 'هل تستطيع الأجهزة فتح منافذ على الراوتر بنفسها (UPnP).',
			'tools.ports' => 'المنافذ المفتوحة',
			'tools.portsDesc' => 'افحص الراوتر أو خادمًا بحثًا عن منافذ مفتوحة خطرة.',
			'tools.utilities' => 'أدوات مساعدة',
			'tools.wifiScanner' => 'ماسح Wi-Fi',
			'tools.wifiDesc' => 'الشبكات القريبة وأمانها والقناة الأقل ازدحامًا.',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'شغّل حاسوبًا أو NAS على هذه الشبكة.',
			'trace.info' => 'كل محطة هي راوتر تمر به حركة بياناتك في طريقها إلى الموقع.\n\nالقفزات الصامتة: كثير من أجهزة الراوتر لا تستجيب أبدًا لهذه الاختبارات. هذا طبيعي وليس عطلًا.\n\nمع تشغيل VPN: يبدأ المسار داخل النفق، فتبقى شبكتك ومزوّدك مخفيين.\n\nالطريقة: يستخدم أداة ping المدمجة في Android مع حدّ للقفزات، لأن التطبيقات لا تستطيع إرسال هذه الحزم مباشرة.',
			'trace.title' => 'تتبّع المسار',
			'trace.stop' => 'إيقاف',
			'trace.trace' => 'تتبّع',
			'trace.again' => 'تتبّع مجددًا',
			'trace.destination' => 'الوجهة',
			'trace.hops' => 'القفزات',
			'trace.answered' => 'استجابت',
			'trace.total' => 'الإجمالي',
			'trace.thisPhone' => 'هذا الهاتف',
			'trace.silentOne' => 'قفزة صامتة واحدة',
			'trace.yourRouter' => 'الراوتر الخاص بك',
			'trace.ms' => ({required Object n}) => '${n} مللي ثانية',
			'trace.silentMany' => ({required Object n}) => '${n} قفزات صامتة',
			'trace.hop' => ({required Object n}) => 'القفزة ${n}',
			'trace.slowest' => ({required Object ms, required Object hop}) => 'معظم التأخير، ${ms} مللي ثانية، يُضاف عند القفزة ${hop}: غالبًا كابل طويل بين الدول أو رابط مزدحم.',
			'ports.ftpNote' => 'يرسل كلمات المرور دون تشفير.',
			'ports.sshNote' => 'تسجيل دخول عن بُعد. لا بأس إن كنت أعددته بنفسك.',
			'ports.telnetNote' => 'تسجيل دخول عن بُعد دون تشفير؛ مفضّل لدى شبكات البوتات.',
			'ports.dnsNote' => 'طبيعي على الراوتر.',
			'ports.web' => 'الويب (HTTP)',
			'ports.webNote' => 'عادةً صفحة إدارة الراوتر.',
			'ports.webTls' => 'الويب (HTTPS)',
			'ports.smb' => 'مشاركة ملفات Windows',
			'ports.smbNote' => 'يجب ألا يكون مكشوفًا للإنترنت أبدًا.',
			'ports.rtsp' => 'بث كاميرا RTSP',
			'ports.rtspNote' => 'قد تكون هناك كاميرا تبث هنا.',
			'ports.upnpNote' => 'يسمح للأجهزة بفتح منافذ الراوتر بنفسها.',
			'ports.rdp' => 'سطح المكتب البعيد',
			'ports.rdpNote' => 'طريق شائع للاختراق.',
			'ports.vncNote' => 'مشاركة الشاشة، غالبًا دون كلمة مرور.',
			'ports.tr069Note' => 'إدارة عن بُعد من مزوّد الإنترنت.',
			'ports.webAlt' => 'الويب (بديل)',
			'ports.webAltTls' => 'الويب (HTTPS بديل)',
			'ports.title' => 'المنافذ المفتوحة',
			'ports.check' => 'فحص المنافذ',
			'ports.address' => 'عنوان الجهاز أو الخادم',
			'ports.risky' => 'خطر',
			'ports.review' => 'راجِع',
			_ => null,
		} ?? switch (path) {
			'ports.normal' => 'طبيعي',
			'ports.info' => ({required Object n}) => 'يفحص ${n} منفذًا مهمًا على أجهزة الراوتر والأجهزة المنزلية، ويشرح كل منفذ مفتوح.\n\nافحص فقط الأجهزة والخوادم التي تملكها أو تديرها.',
			'ports.checking' => ({required Object n}) => 'جارٍ فحص ${n} منفذًا',
			'ports.yourRouter' => ({required Object ip}) => 'الراوتر الخاص بك هو ${ip}',
			'ports.noneOpen' => ({required Object host}) => 'لا توجد منافذ شائعة مفتوحة على ${host}.',
			'wifi.title' => 'ماسح Wi-Fi',
			'wifi.allow' => 'السماح بفحص Wi-Fi',
			'wifi.needsPermission' => 'يحتاج إلى إذن الموقع.',
			'wifi.scanning' => 'جارٍ الفحص',
			'wifi.again' => 'افحص مجددًا',
			'wifi.failed' => 'فشل الفحص',
			'wifi.none' => 'لم يُعثر على شبكات. قد تكون خدمة الموقع متوقفة.',
			'wifi.hidden' => 'شبكة مخفية',
			'wifi.nearby' => ({required Object n}) => '${n} شبكات قريبة',
			'wifi.bestChannel' => ({required Object n}) => 'القناة الأقل ازدحامًا في 2.4 غيغاهرتز: ${n}',
			'wifi.weak' => ({required Object n}) => '${n} مفتوحة أو ضعيفة',
			'wifi.connectedPrefix' => 'متصل · ',
			'wifi.permissionInfo' => 'لا يعرض Android شبكات Wi-Fi القريبة إلا للتطبيقات التي لديها إذن الموقع. يستخدمه G VPN فقط لعرض الشبكات على هذا الهاتف.',
			'wifi.info' => 'يعرض الشبكات من آخر فحص للهاتف. يسمح Android بعدد قليل من الفحوصات في الدقيقة، لذا قد يُظهر الفحص السريع القائمة نفسها. القناة المقترحة هي الأقل ازدحامًا بين 1 و6 و11، وهي القنوات الثلاث غير المتداخلة.',
			'errors.notAuthorized' => 'لم يُمنح إذن VPN.',
			'errors.turnedOff' => 'أوقف النظام أو تطبيق آخر VPN.',
			'errors.busy' => 'طلب إذن مفتوح بالفعل.',
			'errors.cancelled' => 'أُلغي الاتصال.',
			'errors.badConfig' => ({required Object error}) => 'إعدادات هذا الخادم غير صالحة: ${error}',
			'errors.timeout' => 'لم يستجب الخادم.',
			'errors.refused' => 'رفض الخادم الاتصال.',
			'errors.failed' => ({required Object error}) => 'تعذّر الاتصال: ${error}',
			'errors.tryAnother' => 'الخوادم المجانية تظهر وتختفي؛ جرّب خادمًا آخر.',
			'errors.downloadFailed' => 'تعذّر تنزيل إعدادات هذا الخادم. تحقّق من اتصالك أو اختر خادمًا آخر.',
			'scan.mobile' => 'بيانات الجوال',
			'scan.ping' => 'PING',
			'scan.noReply' => 'لا رد',
			'scan.dns' => 'DNS',
			'scan.dnsQuad9' => 'Quad9، النفق',
			'scan.dnsTunnel' => 'داخل النفق',
			'scan.privateDns' => 'DNS الخاص',
			'scan.dnsIsp' => 'المزوّد، ظاهر',
			'scan.network' => 'الشبكة',
			'scan.offline' => 'غير متصل',
			'scan.open' => 'مفتوحة، بلا كلمة مرور',
			'scan.wep' => 'WEP، غير آمنة',
			'scan.owe' => 'مفتوحة، مشفّرة',
			'scan.enterprise' => 'مؤسسية',
			'scan.unknown' => 'غير معروف',
			'scan.wifi' => 'WI-FI',
			'scan.signIn' => 'صفحة تسجيل دخول',
			'scan.ms' => ({required Object n}) => '${n} مللي ثانية',
			'scan.covered' => ({required Object what}) => '${what}، محمية',
			'legal.privacy' => 'سياسة الخصوصية',
			'legal.terms' => 'شروط الاستخدام',
			'legal.licences' => 'تراخيص البرامج المفتوحة المصدر',
			'update.ready' => 'التحديث جاهز',
			'update.restart' => 'إعادة التشغيل',
			'details.share' => 'مشاركة',
			'details.connectedFor' => ({required Object n}) => 'متصل · ${n} د',
			'details.notConnected' => 'غير متصل',
			'details.downloaded' => 'تم تنزيله',
			'details.uploaded' => 'تم رفعه',
			'details.lastUsed' => 'آخر استخدام',
			'details.connection' => 'الاتصال',
			'details.protocol' => 'البروتوكول',
			'details.address' => 'عنوانك',
			'details.dns' => 'DNS',
			'details.routes' => 'المسارات',
			'details.allTraffic' => 'كل حركة البيانات',
			'details.someRoutes' => ({required Object n}) => '${n} شبكات',
			'details.keepalive' => 'Keepalive',
			'details.serverKey' => 'مفتاح الخادم',
			'details.copy' => 'نسخ',
			'details.copied' => 'تم النسخ',
			'details.manage' => 'الإدارة',
			'details.export' => 'تصدير نسخة احتياطية',
			'details.exportSub' => 'كل خوادمك في ملف واحد',
			'share.title' => ({required Object name}) => 'مشاركة ${name}',
			'share.sameKey' => 'هذا يشارك مفتاح هذا الهاتف. يمكن لأي شخص يملكه استخدام خادمك باسمك، ولا يمكن إلا لجهاز واحد الاتصال به في الوقت نفسه.',
			'share.scanHint' => 'على الهاتف الآخر: G VPN، الخوادم، مسح QR. تعمل الصورة المحفوظة أيضًا.',
			'share.saveImage' => 'حفظ الصورة',
			'share.send' => 'إرسال',
			'add.title' => 'إضافة خادم',
			'add.subtitle' => 'أي خادم WireGuard: راوتر أو VPS أو خادم منزلي.',
			'add.camera' => 'المسح بالكاميرا',
			'add.cameraSub' => 'QR على شاشة أخرى',
			'add.image' => 'من صورة',
			'add.imageSub' => 'لقطة شاشة أو صورة محفوظة',
			'add.noQr' => 'لا يوجد رمز QR في هذه الصورة.',
			'add.tip' => 'وصلك رمز QR على واتساب أو تيليجرام؟ اضغط مشاركة على الصورة واختر G VPN.',
			'backup.restored' => ({required Object n}) => 'تمت استعادة ${n} خوادم',
			'backup.nothingNew' => 'هذه الخوادم موجودة بالفعل',
			'gs.proRequired' => 'خوادم G Servers لمشتركي G VPN Pro.',
			'gs.off' => 'خوادم G Servers متوقفة الآن.',
			'gs.network' => 'تعذّر الوصول إلى G Servers. تحقّق من اتصالك وحاول مجددًا.',
			'gs.active' => 'نشط',
			'gs.servers' => 'G Servers',
			'gs.busy' => ({required Object n}) => 'مشغول ${n}%',
			'gs.offline' => 'غير متصل',
			'gs.devices' => 'أجهزتك',
			'gs.devicesSub' => ({required Object n}) => 'حتى ${n} هواتف، لكل منها مفتاحه',
			'gs.footnote' => 'يحصل كل هاتف على مفتاحه الخاص المُنشأ عليه. لا تحتفظ G Servers بسجلات نشاط.',
			'gs.leastBusy' => 'الأقل انشغالًا الآن',
			'gs.busyNoLogs' => ({required Object n}) => 'مشغول ${n}% · بلا سجلات',
			'gs.subtitle' => ({required Object country}) => 'G Server · ${country} · WireGuard',
			'gs.busyLabel' => 'الانشغال',
			'gs.status' => 'الحالة',
			'gs.online' => 'متصل',
			'gs.onThisServer' => 'على هذا الخادم',
			'gs.thisPhone' => 'هذا الهاتف',
			'gs.added' => 'مُضاف · المفتاح أُنشئ هنا',
			'gs.notAdded' => 'يُضاف عند الاتصال',
			'gs.logs' => 'سجلات النشاط',
			'gs.noneKept' => 'لا يُحتفظ بها',
			'gs.privacy' => 'لا يعرف الخادم هذا الهاتف إلا بمفتاحه العام، ولا يحتفظ بأي سجل للمواقع التي تزورها أو البيانات التي ترسلها.',
			'gs.stepPro1' => 'ثبّت G VPN على الهاتف بحساب Google نفسه.',
			'gs.stepPro2' => 'افتح علامة تبويب Pro. يُفعَّل Pro تلقائيًا، أو اضغط استعادة.',
			'gs.step3' => 'اضغط اتصال. ينشئ الهاتف مفتاحه ويُضاف إلى G Servers. بلا QR وبلا رمز.',
			'gs.stepFree1' => 'ثبّت G VPN على الهاتف.',
			'gs.stepFree2' => 'افتح علامة تبويب Pro.',
			'gs.devicesIntroPro' => 'يتبع Pro حسابك في Google. لكل هاتف مفتاحه، فلا يفصل أحدها الآخر.',
			'gs.devicesIntroFree' => 'لكل هاتف مفتاحه، فلا تفصل الهواتف بعضها.',
			'gs.otherPhone' => 'هاتف آخر',
			'gs.lastConnected' => ({required Object when}) => 'آخر اتصال ${when}',
			'gs.noDevices' => 'اتصل بخادم G Server مرة وستظهر هواتفك هنا.',
			'gs.addTitle' => 'إضافة هاتف أو إعادة التثبيت',
			'gs.idle' => ({required Object n}) => 'الهاتف الذي لم يتصل منذ ${n} يومًا يُزال تلقائيًا من G Servers، فلا يشغل هاتف قديم أو أُعيد تثبيته مكانًا.',
			'gs.limitNote' => ({required Object n}) => 'حتى ${n} هواتف لكل خطة.',
			'gs.fullTitle' => ({required Object n}) => 'كل الأماكن الـ ${n} مستخدمة',
			'gs.fullBody' => 'أزل هاتفًا لم تعد تستخدمه، وسيتصل هذا الهاتف فورًا.',
			'gs.busyNow' => 'هناك هواتف جديدة كثيرة الآن. حاول مجددًا بعد قليل.',
			'gs.serverFull' => 'هذا الخادم ممتلئ. جرّب خادم G Server آخر.',
			'gs.ping' => 'PING',
			'gs.last24' => 'الانشغال، آخر 24 ساعة',
			'gs.noHistory' => 'يمتلئ الرسم مع استخدام الخادم خلال اليوم.',
			'gs.chartLabel' => ({required Object max}) => 'الانشغال خلال آخر 24 ساعة، بحد أقصى ${max} بالمئة',
			'gs.hoursAgo' => 'قبل 24 س',
			'gs.now' => 'الآن',
			_ => null,
		};
	}
}
