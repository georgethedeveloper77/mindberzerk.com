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
	@override late final _Translations$map$ar map = _Translations$map$ar._(_root);
	@override late final _Translations$stats$ar stats = _Translations$stats$ar._(_root);
	@override late final _Translations$recents$ar recents = _Translations$recents$ar._(_root);
	@override late final _Translations$presets$ar presets = _Translations$presets$ar._(_root);
	@override late final _Translations$shield$ar shield = _Translations$shield$ar._(_root);
	@override late final _Translations$checks$ar checks = _Translations$checks$ar._(_root);
	@override late final _Translations$toolSettings$ar toolSettings = _Translations$toolSettings$ar._(_root);
	@override late final _Translations$security$ar security = _Translations$security$ar._(_root);
	@override late final _Translations$providers$ar providers = _Translations$providers$ar._(_root);
	@override late final _Translations$alerts$ar alerts = _Translations$alerts$ar._(_root);
	@override late final _Translations$report$ar report = _Translations$report$ar._(_root);
	@override late final _Translations$breaches$ar breaches = _Translations$breaches$ar._(_root);
	@override late final _Translations$blocked$ar blocked = _Translations$blocked$ar._(_root);
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
	@override String get ipFailed => 'تعذّر التحقق من عنوان IP';
	@override String get ipChecking => 'جارٍ التحقق من عنوان IP';
	@override String get themeSystem => 'المظهر: حسب الهاتف';
	@override String get themeLight => 'المظهر: فاتح';
	@override String get themeDark => 'المظهر: داكن';
	@override String get free => 'مجاني';
	@override String get pickServer => 'اختر خادمًا';
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
	@override String get gTab => 'G Servers';
	@override String get search => 'ابحث عن دولة';
	@override String get noMatch => 'لا خوادم مطابقة.';
	@override String bestPing({required Object ms}) => 'الأفضل ${ms} مللي ث';
	@override String get bestTag => 'الأفضل';
	@override String get ownHero => 'خوادمنا';
	@override String get ownHeroSub => 'أسرع وخاصة، لكل هاتف مفتاحه';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} خوادم',
	);
	@override String showAll({required Object n}) => 'عرض الكل ${n}';
	@override String get showFewer => 'عرض أقل';
	@override String get fastTab => 'سريعة';
	@override String get fastestFree => 'الأسرع المجانية';
}

// Path: pro
class _Translations$pro$ar extends Translations$pro$en {
	_Translations$pro$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get owned => 'لديك Pro';
	@override String get waitingPlay => 'بانتظار Google Play';
	@override String startTrial({required Object days}) => 'ابدأ تجربة مجانية لمدة ${days} يومًا';
	@override String get restore => 'استعادة';
	@override String save({required Object pct}) => 'وفّر ${pct}%';
	@override String get yearly => 'سنوي';
	@override String get monthly => 'شهري';
	@override String get billedMonthly => 'يُدفع شهريًا';
	@override String daysFree({required Object days}) => '${days} يومًا مجانًا';
	@override String perMonth({required Object price}) => '${price} شهريًا';
	@override String get title => 'G VPN Pro';
	@override String get renewGeneric => 'تتجدد الاشتراكات تلقائيًا حتى إلغائها. ألغِ في أي وقت من Google Play.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} يومًا مجانًا، ثم ${price} لكل ${period}. يتجدد تلقائيًا حتى الإلغاء؛ ألغِ من Google Play قبل انتهاء التجربة بيوم على الأقل لتجنّب الدفع.';
	@override String renew({required Object price, required Object period}) => '${price} لكل ${period}. يتجدد تلقائيًا حتى الإلغاء؛ ألغِ في أي وقت من Google Play.';
	@override String get year => 'سنة';
	@override String get month => 'شهر';
	@override String get manage => 'إدارة الاشتراك';
	@override late final _Translations$pro$free$ar free = _Translations$pro$free$ar._(_root);
	@override String get heroLine => 'خوادمنا السريعة، وكل الفحوصات بلا حد';
	@override String get start => 'ابدأ Pro';
	@override String get compareFree => 'مجاني';
	@override String get comparePro => 'PRO';
	@override String get rowFreeServers => 'خوادم مجانية';
	@override String get rowTools => 'اختبار السرعة والأدوات وفحص Wi-Fi';
	@override String get rowGServers => 'G Servers بلا سجلات';
	@override String get rowLinks => 'فحص الروابط';
	@override String linksFree({required Object n}) => '${n} شهريًا';
	@override String get unlimited => 'بلا حد';
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
	@override String get mac => 'عنوان MAC';
	@override String failed({required Object error}) => 'تعذّر الإرسال: ${error}';
	@override String get computer => 'حاسوب';
	@override String get pick => 'اختر جهازًا لتشغيله';
	@override String waking({required Object name}) => 'جارٍ تشغيل ${name}';
	@override String get yours => 'أجهزتك';
	@override String wakeNamed({required Object name}) => 'تشغيل ${name}';
	@override String get removeHint => 'اضغط مطولًا على جهاز لإزالته';
	@override String get add => 'إضافة جهاز';
	@override String get name => 'الاسم';
	@override String get saveWake => 'حفظ وتشغيل';
}

// Path: speed
class _Translations$speed$ar extends Translations$speed$en {
	_Translations$speed$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
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
	@override String mapping({required Object proto, required Object host}) => '${proto} إلى ${host}';
	@override String get upnpOn => 'UPnP مفعّل';
	@override String get routerLabel => 'الراوتر';
	@override String get internetAddress => 'عنوان الإنترنت';
	@override String get openedBy => 'فتحتها الأجهزة';
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
	@override String get newBadge => 'جديد';
	@override String scanning({required Object n}) => 'جارٍ فحص ${n} من 254';
	@override String newSince({required Object n}) => '${n} جديد منذ آخر فحص';
	@override String ms({required Object n}) => '${n} مللي ثانية';
	@override String get cameras => 'الكاميرات';
	@override String get device => 'الجهاز';
	@override String get online => 'متصل';
	@override String get model => 'الطراز';
	@override String get announced => 'يعرّف نفسه باسم';
	@override String get services => 'الخدمات المفتوحة';
	@override String get checkingServices => 'جارٍ فحص الخدمات';
	@override String get noServices => 'لا تستجيب أي خدمة شائعة';
	@override String get rename => 'إعادة التسمية';
	@override String get save => 'حفظ';
	@override late final _Translations$devices$kinds$ar kinds = _Translations$devices$kinds$ar._(_root);
	@override String get details => 'تفاصيل الشبكة';
	@override String get listView => 'قائمة';
	@override String get meshView => 'شبكة مترابطة';
	@override String get offlineHeading => 'غير متصل';
	@override String seen({required Object when}) => 'شوهد ${when}';
	@override String agoMinutes({required Object n}) => 'قبل ${n} د';
	@override String agoHours({required Object n}) => 'قبل ${n} س';
	@override String agoDays({required Object n}) => 'قبل ${n} يوم';
	@override String get throughVpn => 'عبر VPN';
	@override String get closer => 'الأقرب = يستجيب أسرع';
	@override String get yours => 'هل هذا لك؟';
	@override String get mine => 'لي';
	@override String get notMine => 'ليس لي';
	@override String get whatIsIt => 'ما هذا؟';
	@override String ourGuess({required Object kind}) => 'تخميننا: ${kind}';
	@override String get groupPersonal => 'الهواتف والحواسيب';
	@override String get groupHome => 'المنزل والوسائط';
	@override String get groupNetwork => 'الشبكة والمنزل الذكي';
	@override String onlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} متصل',
	);
	@override String offlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} غير متصل',
	);
	@override String toConfirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} للتأكيد',
	);
}

// Path: ping
class _Translations$ping$ar extends Translations$ping$en {
	_Translations$ping$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get askTitle => 'Ping لمضيف';
	@override String get askHint => 'example.com أو 192.168.1.10';
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
	@override String get internet => 'الإنترنت';
	@override String get speed => 'اختبار السرعة';
	@override String get speedDesc => 'التنزيل والرفع وجودة الفيديو';
	@override String get ping => 'Ping';
	@override String get pingDesc => 'زمن الاستجابة والتذبذب مباشرة';
	@override String get status => 'حالة الخدمات';
	@override String get statusDesc => 'هل التطبيق متاح أم محظور هنا؟';
	@override String get trace => 'تتبّع المسار';
	@override String get traceDesc => 'كل محطة في الطريق إلى موقع';
	@override String get security => 'هذه الشبكة';
	@override String get devices => 'الأجهزة على هذه الشبكة';
	@override String get devicesDesc => 'من على شبكة Wi-Fi لديك';
	@override String get router => 'فحص الراوتر';
	@override String get routerDesc => 'المنافذ التي فتحتها أجهزتك';
	@override String get ports => 'المنافذ المفتوحة';
	@override String get portsDesc => 'منافذ خطرة على جهاز أو خادم';
	@override String get utilities => 'أدوات';
	@override String get wifiScanner => 'ماسح Wi-Fi';
	@override String get wifiDesc => 'الشبكات من حولك وأهدأ قناة';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'تشغيل حاسوب على هذه الشبكة';
	@override String get passwordCheck => 'فحص كلمة المرور';
	@override String get passwordCheckDesc => 'هل تسرّبت؟';
	@override String get linkCheck => 'فحص الرابط';
	@override String get linkCheckDesc => 'هل فتحه آمن؟';
	@override String get breaches => 'تسريبات البيانات';
	@override String get breachesDesc => 'ما الذي تسرّب مؤخرًا';
	@override String get blocked => 'ما المحجوب';
	@override String get blockedDesc => 'مواقع محجوبة على هذه الشبكة';
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
	@override String get popular => 'الشائعة';
	@override String get recent => 'الأخيرة';
	@override String get clearRecent => 'مسح الأخيرة';
	@override String hopsCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} قفزة',
	);
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
	@override String summary({required Object open, required Object n}) => '${open} مفتوح من ${n} تم فحصها';
	@override String riskyCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} خطر',
	);
	@override String get noneRisky => 'لا شيء خطر';
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
	@override String get permissionInfo => 'لا يعرض Android شبكات Wi-Fi القريبة إلا للتطبيقات التي لديها إذن الموقع. يستخدمه G VPN فقط لعرض الشبكات على هذا الهاتف.';
	@override String get info => 'يعرض الشبكات من آخر فحص للهاتف. يسمح Android بعدد قليل من الفحوصات في الدقيقة، لذا قد يُظهر الفحص السريع القائمة نفسها. القناة المقترحة هي الأقل ازدحامًا بين 1 و6 و11، وهي القنوات الثلاث غير المتداخلة.';
	@override String get airMap => 'خريطة الهواء';
	@override String get channels => 'القنوات';
	@override String get list => 'القائمة';
	@override String get secure => 'آمنة';
	@override String get weakLabel => 'ضعيفة';
	@override String get openLabel => 'مفتوحة';
	@override String get sizeIsWidth => 'الحجم = عرض القناة';
	@override String get strongest => 'الأقوى';
	@override String get openNearby => 'المفتوحة بالقرب';
	@override String get onYourChannel => 'على قناتك';
	@override String get noneNearby => 'لا شيء';
	@override String get verdictOpen => 'يمكن لأي شخص قريب قراءة ما يُرسل';
	@override String get verdictWep => 'حماية قديمة وسهلة الكسر';
	@override String get verdictWpa => 'حماية قديمة';
	@override String get verdictWps => 'WPS مفعّل: الاختراق أسهل';
	@override String get verdictGood => 'محمية جيدًا';
	@override String get maker => 'الشركة المصنّعة';
	@override String get address => 'العنوان الفعلي';
	@override String get privateAddress => 'أنشأه الراوتر للخصوصية';
	@override String get you => 'أنت';
	@override String onClear({required Object name}) => '${name} على قناة هادئة';
	@override String move({required Object name, required Object n}) => 'انقل ${name} إلى القناة ${n}';
	@override String get clear => 'هادئة';
	@override String get busy => 'مشغولة';
	@override String get crowded => 'مزدحمة';
	@override String get allBands => 'كل النطاقات';
	@override String get openOnly => 'المفتوحة فقط';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} شبكة',
	);
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
	@override String get ping => 'زمن الاستجابة';
	@override String get last24 => 'الانشغال، آخر 24 ساعة';
	@override String get noHistory => 'يمتلئ الرسم مع استخدام الخادم خلال اليوم.';
	@override String chartLabel({required Object max}) => 'الانشغال خلال آخر 24 ساعة، بحد أقصى ${max} بالمئة';
	@override String get hoursAgo => 'قبل 24 س';
	@override String get now => 'الآن';
	@override String get included => 'مشمول';
	@override String get perkServers => 'خوادم سريعة وخاصة';
	@override String get perkServersSub => 'WireGuard، نديرها بأنفسنا، بلا سجلات نشاط';
	@override String get perkLinks => 'فحص روابط غير محدود';
	@override String get perkLinksSub => 'افحص كل رابط يصلك';
	@override String devicesOf({required Object used, required Object limit}) => 'أجهزتك · ${used} من ${limit}';
	@override String get eachKey => 'لكل هاتف مفتاحه الخاص';
	@override String get connected => 'متصل';
	@override String get bestNow => 'الأفضل لك الآن';
	@override String get logsShort => 'السجلات';
}

// Path: map
class _Translations$map$ar extends Translations$map$en {
	_Translations$map$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get open => 'فتح الخريطة';
	@override String get searchCountries => 'ابحث عن دولة';
	@override String get noMatch => 'لا توجد دولة مطابقة';
	@override String get locate => 'موقعي';
	@override String get list => 'قائمة';
	@override String get map => 'خريطة';
	@override String freeServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		zero: 'لا خوادم مجانية',
		one: 'خادم مجاني واحد',
		two: 'خادمان مجانيان',
		few: '${n} خوادم مجانية',
		many: '${n} خادمًا مجانيًا',
		other: '${n} خادم مجاني',
	);
	@override late final _Translations$map$grade$ar grade = _Translations$map$grade$ar._(_root);
	@override String get switchTo => 'تبديل';
	@override String freeServer({required Object n}) => 'خادم مجاني ${n}';
	@override String get best => 'الأفضل';
	@override String gServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} G Server',
	);
}

// Path: stats
class _Translations$stats$ar extends Translations$stats$en {
	_Translations$stats$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get thisWeek => 'هذا الأسبوع';
	@override String get time => 'الوقت';
	@override String get data => 'البيانات';
	@override String get protected => 'محمي';
	@override String get throughVpn => 'عبر VPN';
	@override String get seeDetails => 'التفاصيل';
	@override String get title => 'الإحصاءات';
	@override String get week => 'أسبوع';
	@override String get month => 'شهر';
	@override String get protectedLabel => 'محمي';
	@override String get dataUsed => 'البيانات المستخدمة';
	@override String get byServer => 'حسب الخادم';
	@override String get onPhone => 'محفوظة على هذا الهاتف فقط';
	@override String get reset => 'إعادة الضبط';
	@override String get resetTitle => 'إعادة ضبط الإحصاءات؟';
	@override String get resetBody => 'يمحو وقت الحماية والبيانات على هذا الهاتف. لا يمكن التراجع.';
	@override String hm({required Object h, required Object m}) => '${h} س ${m} د';
	@override String m({required Object m}) => '${m} د';
	@override String get empty => 'اتصل لبدء العد.';
}

// Path: recents
class _Translations$recents$ar extends Translations$recents$en {
	_Translations$recents$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'الأخيرة';
	@override String get allServers => 'كل الخوادم';
	@override String get free => 'خادم مجاني';
	@override String get yours => 'خادمك';
	@override String get gserver => 'G Server';
}

// Path: presets
class _Translations$presets$ar extends Translations$presets$en {
	_Translations$presets$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'الإعدادات الجاهزة';
	@override String get all => 'الكل';
	@override String get newPreset => 'إعداد جديد';
	@override String get edit => 'تعديل الإعداد';
	@override String get name => 'الاسم';
	@override String get namePlaceholder => 'إعدادي';
	@override String get server => 'الخادم';
	@override String get fastestOption => 'الأسرع';
	@override String get countryOption => 'الدولة';
	@override String get pickCountry => 'اختر دولة';
	@override String get skipMyCountry => 'تجاوز دولتي';
	@override String get notMine => 'ليست دولتي';
	@override String get protocol => 'البروتوكول';
	@override String get auto => 'تلقائي';
	@override String get tryNext => 'عند الحظر، جرّب الخادم التالي';
	@override String get shield => 'الدرع';
	@override String get followRules => 'كما في القواعد';
	@override String get allApps => 'كل التطبيقات عبر VPN';
	@override String get allAppsShort => 'كل التطبيقات';
	@override String get save => 'حفظ';
	@override String get delete => 'حذف';
	@override String get reset => 'استعادة الافتراضي';
	@override String get none => 'لا يوجد خادم مجاني يناسب هذا الإعداد الآن.';
	@override late final _Translations$presets$names$ar names = _Translations$presets$names$ar._(_root);
}

// Path: shield
class _Translations$shield$ar extends Translations$shield$en {
	_Translations$shield$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'الدرع';
	@override String get sub => 'يعمل أثناء الاتصال';
	@override String get off => 'إيقاف';
	@override String get offSub => 'DNS الخاص بالخادم';
	@override String get malware => 'البرمجيات الخبيثة';
	@override String get malwareSub => 'يحظر المواقع الضارة والتصيد';
	@override String get family => 'البرمجيات الخبيثة ومواقع البالغين';
	@override String get familySub => 'يحظر محتوى البالغين أيضًا';
	@override String get custom => 'DNS مخصص';
	@override String get customSub => 'خوادم DNS الخاصة بك';
	@override String get customHint => 'عنوان IP، مثل 1.1.1.1';
	@override String get invalid => 'أدخل عنوان IP واحدًا أو اثنين.';
}

// Path: checks
class _Translations$checks$ar extends Translations$checks$en {
	_Translations$checks$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'فحوصات الأمان';
	@override String get password => 'كلمة المرور';
	@override String get link => 'الرابط';
	@override String get pwTitle => 'هل تسرّبت؟';
	@override String get pwHint => 'كلمة المرور للفحص';
	@override String get showPassword => 'إظهار كلمة المرور';
	@override String get hidePassword => 'إخفاء كلمة المرور';
	@override String get check => 'افحص';
	@override String get leaked => 'موجودة في التسريبات';
	@override String seen({required Object n}) => 'ظهرت ${n} مرة';
	@override String get leakedAdvice => 'غيّرها في كل مكان تستخدمها فيه، بدءًا بالبريد والبنك.';
	@override String get notFound => 'غير موجودة في التسريبات المعروفة';
	@override String get notFoundAdvice => 'علامة جيدة وليست ضمانًا. استخدم كلمة مرور مختلفة لكل حساب.';
	@override String get failed => 'تعذّر الفحص. حاول مجددًا.';
	@override String get private => 'كلمة مرورك لا تغادر هذا الهاتف أبدًا';
	@override String get linkTitle => 'هل هذا الرابط آمن؟';
	@override String get linkHint => 'الرابط للفحص';
	@override String get paste => 'لصق';
	@override String get danger => 'رابط خطير';
	@override String get dangerAdvice => 'لا تفتحه ولا تُدخل أي بيانات.';
	@override String get clear => 'ليس في القوائم المعروفة للبرمجيات الخبيثة أو التصيّد';
	@override String get clearAdvice => 'ومع ذلك، تحقّق من العنوان قبل تسجيل الدخول.';
	@override String get goesTo => 'يؤدي إلى';
	@override String get redirects => 'عمليات التحويل';
	@override String get invalid => 'هذا لا يبدو عنوان ويب.';
	@override String get busy => 'فحوصات كثيرة. حاول بعد قليل.';
	@override String get unavailable => 'فحص الروابط غير متاح الآن.';
	@override String get listed => 'معروف بالبرمجيات الخبيثة أو التصيّد';
	@override String get missing => 'لا يوجد موقع على هذا العنوان';
	@override String get missingAdvice => 'تحقّق من الكتابة: يستخدم المحتالون عناوين متشابهة.';
	@override String left({required Object n, required Object total}) => 'تبقّى ${n} من ${total} فحوصات مجانية هذا الشهر';
	@override String get usedUp => 'استخدمت فحوصات الروابط المجانية لهذا الشهر';
	@override String get usedUpSub => 'في Pro فحوصات بلا حد. تعود الفحوصات المجانية في اليوم الأول من الشهر.';
	@override String get getPro => 'احصل على Pro';
}

// Path: toolSettings
class _Translations$toolSettings$ar extends Translations$toolSettings$en {
	_Translations$toolSettings$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'إعدادات الأدوات';
	@override String get askMobile => 'اسأل قبل اختبار السرعة على بيانات الجوال';
	@override String get askMobileSub => 'قد يستهلك الاختبار أكثر من 100 ميغابايت على اتصال سريع';
	@override String get mobileTitle => 'استخدام بيانات الجوال؟';
	@override String get mobileBody => 'قد يستهلك اختبار السرعة أكثر من 100 ميغابايت على اتصال سريع.';
	@override String get mobileGo => 'اختبار';
	@override String get safe => 'آمنة';
	@override String get unsafe => 'غير آمنة';
	@override String devices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} جهاز',
	);
	@override String get hideMac => 'إخفاء العناوين الفعلية';
	@override String get hideMacSub => 'عرض جزء الشركة المصنّعة فقط من عناوين MAC';
	@override String get names => 'إظهار أسماء الراوترات والخوادم';
	@override String get namesSub => 'يبحث عن أسماء العناوين في Traceroute';
	@override String get remember => 'تذكّر المضيفين الأخيرين';
	@override String get rememberSub => 'لـ Traceroute';
	@override String get clear => 'مسح سجل الأدوات';
	@override String get clearSub => 'ينسى المضيفين الأخيرين والأجهزة في كل شبكة';
	@override String get clearGo => 'مسح';
}

// Path: security
class _Translations$security$ar extends Translations$security$en {
	_Translations$security$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get tab => 'الأمان';
	@override String get good => 'جيد';
	@override String get fair => 'مقبول';
	@override String get atRisk => 'في خطر';
	@override String get allClear => 'لا شيء لإصلاحه';
	@override String checked({required Object time}) => 'فُحصت الساعة ${time}';
	@override String get trend => 'آخر أسبوعين';
	@override String get checking => 'جارٍ فحص هذه الشبكة';
	@override String get snoozed => 'مؤجلة';
	@override String get remindLater => 'ذكّرني لاحقًا';
	@override String get unsnooze => 'ذكّرني الآن';
	@override String get review => 'مراجعة';
	@override String get confirmGo => 'تأكيد';
	@override String get scanGo => 'فحص';
	@override String get look => 'عرض';
	@override String get connectGo => 'اتصال';
	@override String get checkAgain => 'افحص مجددًا';
	@override String get wifiOpen => 'شبكة Wi-Fi مفتوحة';
	@override String get wifiOpenDetail => 'يمكن لأي شخص قريب رؤية ما يُرسل';
	@override String get wifiWep => 'الشبكة تستخدم WEP';
	@override String get wifiWepDetail => 'حماية قديمة وسهلة الكسر';
	@override String get wifiOwe => 'الشبكة تستخدم Enhanced Open';
	@override String get wifiOweDetail => 'مشفّرة لكن يمكن لأي شخص الانضمام';
	@override String get wifiSecure => 'تشفير Wi-Fi';
	@override String get wifiUnknown => 'أمان Wi-Fi غير معروف';
	@override String get wifiUnknownDetail => 'لم يذكر Android طريقة الحماية';
	@override String get wps => 'WPS مفعّل';
	@override String get wpsDetail => 'أوقفه من إعدادات الراوتر';
	@override String get upnpOff => 'الراوتر يبقي المنافذ مغلقة';
	@override String get upnpOffDetail => 'UPnP متوقف';
	@override String get upnpOn => 'الراوتر يسمح للأجهزة بفتح منافذ';
	@override String get upnpOnDetail => 'UPnP مفعّل';
	@override String get portsOk => 'لا منافذ خطرة على الراوتر';
	@override String get portsRisky => 'منافذ خطرة مفتوحة على الراوتر';
	@override String get scanFirst => 'افحص لترى من هنا';
	@override String get scanFirstDetail => 'الأجهزة المجهولة تخفض النتيجة';
	@override String get notMineDetail => 'راجع قائمة أجهزة الراوتر';
	@override String get confirmDetail => 'حدّد أجهزتك';
	@override String get devicesOk => 'كل الأجهزة معروفة';
	@override String get devicesOkDetail => 'أكدت كل جهاز';
	@override String get camera => 'توجد كاميرا على هذه الشبكة';
	@override String get dnsHijack => 'تُعاد توجيه الأسماء المجهولة';
	@override String get dnsHijackDetail => 'مزوّدك أو الراوتر يعيد كتابة الاستعلامات';
	@override String get dnsOk => 'DNS يجيب بشكل طبيعي';
	@override String get dnsOkDetail => 'لا أثر لإعادة التوجيه';
	@override String get vpnOn => 'VPN مفعّل';
	@override String get vpnOnDetail => 'تخرج البيانات عبر النفق';
	@override String get vpnOff => 'VPN متوقف';
	@override String get vpnOffDetail => 'مزوّدك يرى كل موقع';
	@override String toFix({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} أمور لإصلاحها',
	);
	@override String upnpOpened({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} منافذ فتحتها الأجهزة',
	);
	@override String portsChecked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} منافذ فُحصت',
	);
	@override String notMine({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} أجهزة ليست لك',
	);
	@override String confirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} أجهزة للتأكيد',
	);
}

// Path: providers
class _Translations$providers$ar extends Translations$providers$en {
	_Translations$providers$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get tab => 'الإنترنت';
	@override String get unavailable => 'تعذّر تحميل قائمة المزوّدين. تحقق من اتصالك.';
	@override String get cached => 'حسب آخر فحص بدون VPN';
	@override String get notEnough => 'لا توجد تقييمات كافية بعد';
	@override String get yourRating => 'تقييمك هذا الشهر';
	@override String get yourSpeed => 'سرعتك';
	@override String get runTest => 'إجراء اختبار سرعة';
	@override String get aboutAverage => 'قريب من المتوسط هنا';
	@override String aboveAverage({required Object pct}) => 'أعلى من المتوسط المحلي بنسبة ${pct}٪';
	@override String belowAverage({required Object pct}) => 'أقل من المتوسط المحلي بنسبة ${pct}٪';
	@override String get call => 'اتصال';
	@override String get website => 'الموقع';
	@override String get outages => 'الأعطال';
	@override String get rate => 'قيّم';
	@override String get changeRating => 'تغيير التقييم';
	@override String get compare => 'قارن';
	@override String rateTitle({required Object name}) => 'قيّم ${name}';
	@override String get oncePerMonth => 'تقييم واحد شهريًا';
	@override String get tapStars => 'اضغط على النجوم';
	@override String verified({required Object mbps}) => 'موثّق باختبار سرعتك: ${mbps} ميغابت/ث';
	@override String get busy => 'تقييمات كثيرة من هنا. حاول لاحقًا.';
	@override String get failed => 'تعذّر الإرسال. حاول مجددًا.';
	@override String get post => 'إرسال التقييم';
	@override String get nearTitle => 'مزوّدون بالقرب منك';
	@override String slower({required Object pct}) => 'التنزيل لديك أقل بنسبة ${pct}٪ من متوسط مزوّدك هنا';
	@override String inPlace({required Object place}) => 'الإنترنت المنزلي في ${place}';
	@override String get byRating => 'التقييم';
	@override String get bySpeed => 'السرعة';
	@override String get footnote => 'السرعات متوسطات اختبارات G VPN';
	@override String get noneNearby => 'لا تقييمات قريبة بعد. كن الأول.';
	@override String get you => 'أنت';
	@override String get topRated => 'الأعلى تقييمًا';
	@override String starsOf({required Object n}) => '${n} من 5';
	@override late final _Translations$providers$tags$ar tags = _Translations$providers$tags$ar._(_root);
	@override late final _Translations$providers$words$ar words = _Translations$providers$words$ar._(_root);
	@override String ratings({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} تقييمات',
	);
}

// Path: alerts
class _Translations$alerts$ar extends Translations$alerts$en {
	_Translations$alerts$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get channel => 'التنبيهات';
	@override String get title => 'التنبيهات';
	@override String get markAllRead => 'تعليم الكل كمقروء';
	@override String get clearAll => 'مسح الكل';
	@override String get thisNetwork => 'هذه الشبكة';
	@override String openWifiTitle({required Object name}) => 'اتصلت بشبكة Wi-Fi مفتوحة: ${name}';
	@override String get openWifiBody => 'يمكن لأي شخص قريب رؤية ما يُرسل. شغّل G VPN.';
	@override String get reportTitle => 'تقريرك الأسبوعي جاهز';
	@override String reportBody({required Object hours}) => '${hours} ساعات حماية الأسبوع الماضي';
	@override String blockedTitle({required Object name}) => '${name} محظور هنا';
	@override String get blockedBody => 'يعمل عبر VPN';
	@override late final _Translations$alerts$kinds$ar kinds = _Translations$alerts$kinds$ar._(_root);
	@override String newDeviceTitle({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} أجهزة جديدة على ${network}',
	);
	@override String get settings => 'إعدادات التنبيهات';
	@override String get look => 'عرض';
	@override String get read => 'قراءة';
	@override String get open => 'فتح';
	@override String get check => 'فحص';
	@override String get today => 'اليوم';
	@override String get thisWeek => 'هذا الأسبوع';
	@override String get earlier => 'سابقًا';
	@override String get all => 'الكل';
	@override String get quiet => 'كل شيء هادئ';
	@override String get quietSub => 'لم يحتج إليك شيء مؤخرًا';
	@override String breachTitle({required Object name}) => 'تسريب جديد: ${name}';
	@override late final _Translations$alerts$status$ar status = _Translations$alerts$status$ar._(_root);
}

// Path: report
class _Translations$report$ar extends Translations$report$en {
	_Translations$report$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'التقرير الأسبوعي';
	@override String get share => 'مشاركة كصورة';
	@override String get shareText => 'أسبوعي مع G VPN';
	@override String get safer => 'أسبوع أكثر أمانًا';
	@override String get moreProtected => 'حماية أكثر من الأسبوع الماضي';
	@override String get yourWeek => 'أسبوعك';
	@override String soFar({required Object range}) => '${range}، حتى الآن';
	@override String get protected => 'محمي';
	@override String get data => 'البيانات';
	@override String get security => 'الأمان';
	@override String get speed => 'أفضل سرعة';
	@override String get noScore => 'لم يُفحص';
	@override String get noTest => 'لا اختبار';
	@override String get bestDirect => 'اختبار مباشر';
	@override String moreThan({required Object d}) => 'أكثر بـ ${d} من الأسبوع الماضي';
	@override String lessThan({required Object d}) => 'أقل بـ ${d} من الأسبوع الماضي';
	@override String get protectedTime => 'وقت الحماية';
	@override String mostUsed({required Object name}) => 'الأكثر استخدامًا: ${name}';
	@override String get quiet => 'أسبوع هادئ: لم يحتج شيء إليك';
	@override String newDevices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: 'انضمت ${n} أجهزة جديدة',
	);
	@override String openWifi({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: 'اتصلت بـ ${n} شبكات Wi-Fi مفتوحة',
	);
	@override String blocked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} تطبيقات محظورة',
	);
	@override String breaches({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} تسريبات كبيرة جديدة',
	);
}

// Path: breaches
class _Translations$breaches$ar extends Translations$breaches$en {
	_Translations$breaches$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'تسريبات البيانات';
	@override String get info => 'أحدث تسريبات البيانات من القائمة العامة لـ Have I Been Pwned. لا يُرسل شيء عنك: القائمة واحدة للجميع.\n\nإن كان لديك حساب في موقع مُسرَّب فغيّر تلك الكلمة، وكل مكان استخدمتها فيه.';
	@override String get unavailable => 'تعذّر تحميل القائمة. تحقق من اتصالك.';
	@override String get biggest => 'الأكبر هذا الشهر';
	@override String get newest => 'الأحدث';
	@override String get biggestSort => 'الأكبر';
	@override String get withPasswords => 'مع كلمات مرور';
	@override String get passwordsMark => 'كلمات مرور';
	@override String get one => 'تسريب';
	@override String get checkPassword => 'فحص كلمة مرور';
	@override String get verified => 'موثّق';
	@override String get hasPasswords => 'يحتوي كلمات مرور';
	@override String get accountsLabel => 'الحسابات';
	@override String get happened => 'حدث';
	@override String get published => 'نُشر';
	@override String get website => 'الموقع';
	@override String get leaked => 'ما الذي تسرّب';
	@override String get ifUsed => 'إن كنت تستخدمه';
	@override String get stepPassword => 'غيّر كلمة المرور التي استخدمتها هناك';
	@override String get stepReuse => 'غيّرها حيثما استخدمت الكلمة نفسها';
	@override String get stepTwoStep => 'فعّل التحقق بخطوتين حيث أمكن';
	@override String get stepScams => 'توقّع مكالمات ورسائل احتيال';
	@override String accounts({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${count} حساب',
	);
	@override String worldwide({required Object n}) => 'عالميًا · ${n}';
	@override String get noneHere => 'لا تسريبات من هنا في القائمة الأخيرة.';
	@override String get bigMap => 'خريطة أكبر';
	@override String get showInList => 'عرض في القائمة';
	@override String get mapTitle => 'خريطة التسريبات';
	@override String get zoomIn => 'تكبير';
	@override String get zoomOut => 'تصغير';
	@override String get wholeWorld => 'العالم كله';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} تسريبات',
	);
	@override String get findCountry => 'ابحث عن دولة';
	@override String get seeAll => 'عرض الكل';
	@override String get search => 'ابحث في التسريبات';
}

// Path: blocked
class _Translations$blocked$ar extends Translations$blocked$en {
	_Translations$blocked$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'ما المحجوب';
	@override String get info => 'يختبر مواقع معروفة من هذا الهاتف، دون VPN، ويبيّن أيها تحجبه هذه الشبكة وكيف.\n\nعنوان مزيف: بحث الأسماء في الشبكة يعطي إجابة خاطئة.\n\nمقطوع: يُقطع الاتصال عند بدايته.\n\nلا إجابة: لا يعود شيء.\n\nصفحة حجب: يجيب شيء آخر مكان الموقع.\n\nيبيّن الاختبار أين الموقع محجوب، لا من حجبه. لا يُحفظ أو يُرسل أي شيء.';
	@override String get thisNetwork => 'هذه الشبكة';
	@override String get country => 'بلدك';
	@override String get question => 'ما المحجوب هنا؟';
	@override String get testingOn => 'الاختبار على';
	@override String get vpnOn => 'VPN مفعّل';
	@override String get turnOff => 'أوقف G VPN للاختبار';
	@override String get test => 'اختبر هذه الشبكة';
	@override String get stop => 'إيقاف';
	@override String sitesToTest({required Object n}) => 'مواقع للاختبار · ${n}';
	@override String ofSites({required Object n}) => 'من ${n} موقعًا';
	@override String blockedCount({required Object n}) => '${n} محجوب';
	@override String openCount({required Object n}) => '${n} مفتوح';
	@override String noneBlocked({required Object network}) => 'لا شيء محجوب على ${network}';
	@override String openOf({required Object open, required Object total}) => '${open} من ${total} مفتوحة';
	@override String get allWork => 'كلها تعمل مع G VPN';
	@override String get blockedHeading => 'محجوب';
	@override String get byKind => 'حسب النوع';
	@override String get worksVpn => 'يعمل مع VPN';
	@override String get failsVpn => 'محجوب حتى مع VPN';
	@override String get checkVpn => 'تحقق عبر G VPN';
	@override String get connect => 'اتصل بـ G VPN';
	@override String get again => 'اختبر مجددًا';
	@override String get withoutVpn => 'دون VPN';
	@override String get throughVpn => 'عبر G VPN';
	@override String get notChecked => 'لم يُتحقق';
	@override String get opens => 'يفتح';
	@override String get stillBlocked => 'محجوب';
	@override String get whatHappened => 'ما الذي حدث';
	@override String countryBlocked({required Object country}) => 'موقعًا محجوبًا في ${country}';
	@override String get countrySub => 'وجدتها اختبارات المتطوعين في آخر 30 يومًا';
	@override String get countryNone => 'لا مواقع محجوبة مُبلّغ عنها في آخر 30 يومًا.';
	@override String get countryUnavailable => 'تعذّر تحميل نتائج البلد. تحقق من اتصالك.';
	@override String get confirmed => 'محجوب';
	@override String get oftenFails => 'يفشل كثيرًا';
	@override late final _Translations$blocked$kinds$ar kinds = _Translations$blocked$kinds$ar._(_root);
	@override late final _Translations$blocked$how$ar how = _Translations$blocked$how$ar._(_root);
	@override late final _Translations$blocked$fail$ar fail = _Translations$blocked$fail$ar._(_root);
	@override late final _Translations$blocked$steps$ar steps = _Translations$blocked$steps$ar._(_root);
	@override late final _Translations$blocked$consent$ar consent = _Translations$blocked$consent$ar._(_root);
	@override String someBlocked({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} مواقع محجوبة على ${network}',
	);
	@override String tests({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n,
		other: '${n} اختبارات',
	);
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
	@override String get shield => 'يرشّح الدرع طلبات DNS أثناء الاتصال: Quad9 يحظر البرمجيات الخبيثة والتصيد، وCloudflare for Families يحظر مواقع البالغين أيضًا، أو استخدم DNS الخاص بك. لا يحظر الإعلانات أبدًا.';
	@override String get autoConnect => 'الاتصال التلقائي: يستخدم خادم WireGuard الذي اخترته. قطع الاتصال يدويًا يوقفه مؤقتًا حتى تنضم إلى شبكة أخرى.';
	@override String get apps => 'التطبيقات المباشرة: التطبيقات المستثناة من VPN تتصل مباشرة. كثيرًا ما تحظر البنوك عناوين VPN، لذا قد تفشل المدفوعات عبر VPN.';
	@override String get reconnect => 'تغيير الدرع أو التطبيقات يعيد اتصال VPN للحظة.';
	@override String get stay => 'البقاء متصلًا: بعض الهواتف توقف التطبيقات في الخلفية لتوفير البطارية. يبقي VPN الدائم وإعداد البطارية غير المقيّد تطبيق G VPN يعمل.';
}

// Path: devices.kinds
class _Translations$devices$kinds$ar extends Translations$devices$kinds$en {
	_Translations$devices$kinds$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get phone => 'هاتف';
	@override String get computer => 'حاسوب';
	@override String get tv => 'تلفاز';
	@override String get speaker => 'سماعة';
	@override String get printer => 'طابعة';
	@override String get camera => 'كاميرا';
	@override String get smartHome => 'منزل ذكي';
	@override String get router => 'راوتر';
	@override String get unknown => 'لم يعرّف نفسه';
}

// Path: map.grade
class _Translations$map$grade$ar extends Translations$map$grade$en {
	_Translations$map$grade$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get fast => 'سريع';
	@override String get good => 'جيد';
	@override String get slow => 'بطيء';
}

// Path: presets.names
class _Translations$presets$names$ar extends Translations$presets$names$en {
	_Translations$presets$names$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get fastest => 'الأسرع';
	@override String get unblock => 'فك الحظر';
	@override String get streaming => 'البث';
	@override String get privacy => 'أقصى خصوصية';
}

// Path: providers.tags
class _Translations$providers$tags$ar extends Translations$providers$tags$en {
	_Translations$providers$tags$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get fast => 'سريع';
	@override String get reliable => 'موثوق';
	@override String get support => 'دعم جيد';
	@override String get price => 'سعر عادل';
	@override String get slowEvenings => 'بطيء مساءً';
	@override String get drops => 'ينقطع كثيرًا';
	@override String get poorSupport => 'دعم سيئ';
	@override String get pricey => 'مكلف';
}

// Path: providers.words
class _Translations$providers$words$ar extends Translations$providers$words$en {
	_Translations$providers$words$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get bad => 'سيئ';
	@override String get poor => 'ضعيف';
	@override String get okay => 'مقبول';
	@override String get good => 'جيد';
	@override String get great => 'ممتاز';
}

// Path: alerts.kinds
class _Translations$alerts$kinds$ar extends Translations$alerts$kinds$en {
	_Translations$alerts$kinds$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get newDevice => 'أجهزة جديدة على شبكتي';
	@override String get openWifi => 'Wi-Fi مفتوحة أو ضعيفة';
	@override String get blocked => 'تطبيقات محظورة';
	@override String get report => 'التقرير الأسبوعي';
	@override String get breach => 'التسريبات';
}

// Path: alerts.status
class _Translations$alerts$status$ar extends Translations$alerts$status$en {
	_Translations$alerts$status$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get background => 'كل بضع ساعات';
	@override String checked({required Object time}) => 'فُحص الساعة ${time}';
	@override String get wifi => 'كل شبكة تنضم إليها';
	@override String get blocked => 'عند فحص حالة الخدمات';
	@override String get report => 'كل يوم اثنين';
}

// Path: blocked.kinds
class _Translations$blocked$kinds$ar extends Translations$blocked$kinds$en {
	_Translations$blocked$kinds$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get social => 'التواصل الاجتماعي';
	@override String get messaging => 'المراسلة';
	@override String get news => 'الأخبار';
	@override String get video => 'الفيديو والموسيقى';
	@override String get privacy => 'أدوات الخصوصية';
}

// Path: blocked.how
class _Translations$blocked$how$ar extends Translations$blocked$how$en {
	_Translations$blocked$how$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get dns => 'عنوان مزيف';
	@override String get reset => 'مقطوع';
	@override String get timeout => 'لا إجابة';
	@override String get page => 'صفحة حجب';
	@override String get open => 'مفتوح';
}

// Path: blocked.fail
class _Translations$blocked$fail$ar extends Translations$blocked$fail$en {
	_Translations$blocked$fail$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get noAnswer => 'لا إجابة';
	@override String get refused => 'مرفوض';
	@override String cutOff({required Object s}) => 'قُطع بعد ${s} ث';
	@override String get wrongCert => 'شهادة خاطئة';
}

// Path: blocked.steps
class _Translations$blocked$steps$ar extends Translations$blocked$steps$en {
	_Translations$blocked$steps$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get lookup => 'بحث الاسم';
	@override String get connect => 'الاتصال';
	@override String get handshake => 'المصافحة الآمنة';
}

// Path: blocked.consent
class _Translations$blocked$consent$ar extends Translations$blocked$consent$en {
	_Translations$blocked$consent$ar._(TranslationsAr root) : this._root = root, super.internal(root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get title => 'قبل الاختبار الأول';
	@override String get body => 'يفتح الاختبار كل موقع من هذا الهاتف، دون VPN، كما يفعل المتصفح.';
	@override String get noticeTitle => 'قد يُلاحَظ';
	@override String get notice => 'يرى مزوّدك فتح هذه المواقع. في بعض البلدان قد تلفت زيارتها الانتباه حتى للاختبار. اختبر فقط حيث تشعر بالأمان.';
	@override String get ok => 'فهمت، اختبر';
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
			'home.ipFailed' => 'تعذّر التحقق من عنوان IP',
			'home.ipChecking' => 'جارٍ التحقق من عنوان IP',
			'home.themeSystem' => 'المظهر: حسب الهاتف',
			'home.themeLight' => 'المظهر: فاتح',
			'home.themeDark' => 'المظهر: داكن',
			'home.free' => 'مجاني',
			'home.pickServer' => 'اختر خادمًا',
			'home.network.title' => 'هذه الشبكة',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'غير متصل',
			'home.network.showName' => 'إظهار الاسم',
			'home.network.scanFailed' => 'فشل الفحص. سيُعاد عند تغيّر الشبكة.',
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
			'servers.gTab' => 'G Servers',
			'servers.search' => 'ابحث عن دولة',
			'servers.noMatch' => 'لا خوادم مطابقة.',
			'servers.bestPing' => ({required Object ms}) => 'الأفضل ${ms} مللي ث',
			'servers.bestTag' => 'الأفضل',
			'servers.ownHero' => 'خوادمنا',
			'servers.ownHeroSub' => 'أسرع وخاصة، لكل هاتف مفتاحه',
			'servers.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} خوادم', ), 
			'servers.showAll' => ({required Object n}) => 'عرض الكل ${n}',
			'servers.showFewer' => 'عرض أقل',
			'servers.fastTab' => 'سريعة',
			'servers.fastestFree' => 'الأسرع المجانية',
			'pro.owned' => 'لديك Pro',
			'pro.waitingPlay' => 'بانتظار Google Play',
			'pro.startTrial' => ({required Object days}) => 'ابدأ تجربة مجانية لمدة ${days} يومًا',
			'pro.restore' => 'استعادة',
			'pro.save' => ({required Object pct}) => 'وفّر ${pct}%',
			'pro.yearly' => 'سنوي',
			'pro.monthly' => 'شهري',
			'pro.billedMonthly' => 'يُدفع شهريًا',
			'pro.daysFree' => ({required Object days}) => '${days} يومًا مجانًا',
			'pro.perMonth' => ({required Object price}) => '${price} شهريًا',
			'pro.title' => 'G VPN Pro',
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
			'pro.heroLine' => 'خوادمنا السريعة، وكل الفحوصات بلا حد',
			'pro.start' => 'ابدأ Pro',
			'pro.compareFree' => 'مجاني',
			'pro.comparePro' => 'PRO',
			'pro.rowFreeServers' => 'خوادم مجانية',
			'pro.rowTools' => 'اختبار السرعة والأدوات وفحص Wi-Fi',
			'pro.rowGServers' => 'G Servers بلا سجلات',
			'pro.rowLinks' => 'فحص الروابط',
			'pro.linksFree' => ({required Object n}) => '${n} شهريًا',
			'pro.unlimited' => 'بلا حد',
			'rules.title' => 'القواعد',
			'rules.info.shield' => 'يرشّح الدرع طلبات DNS أثناء الاتصال: Quad9 يحظر البرمجيات الخبيثة والتصيد، وCloudflare for Families يحظر مواقع البالغين أيضًا، أو استخدم DNS الخاص بك. لا يحظر الإعلانات أبدًا.',
			'rules.info.autoConnect' => 'الاتصال التلقائي: يستخدم خادم WireGuard الذي اخترته. قطع الاتصال يدويًا يوقفه مؤقتًا حتى تنضم إلى شبكة أخرى.',
			'rules.info.apps' => 'التطبيقات المباشرة: التطبيقات المستثناة من VPN تتصل مباشرة. كثيرًا ما تحظر البنوك عناوين VPN، لذا قد تفشل المدفوعات عبر VPN.',
			'rules.info.reconnect' => 'تغيير الدرع أو التطبيقات يعيد اتصال VPN للحظة.',
			'rules.info.stay' => 'البقاء متصلًا: بعض الهواتف توقف التطبيقات في الخلفية لتوفير البطارية. يبقي VPN الدائم وإعداد البطارية غير المقيّد تطبيق G VPN يعمل.',
			'rules.protection' => 'الحماية',
			'rules.shield' => 'الدرع',
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
			'wol.mac' => 'عنوان MAC',
			'wol.failed' => ({required Object error}) => 'تعذّر الإرسال: ${error}',
			'wol.computer' => 'حاسوب',
			'wol.pick' => 'اختر جهازًا لتشغيله',
			'wol.waking' => ({required Object name}) => 'جارٍ تشغيل ${name}',
			'wol.yours' => 'أجهزتك',
			'wol.wakeNamed' => ({required Object name}) => 'تشغيل ${name}',
			'wol.removeHint' => 'اضغط مطولًا على جهاز لإزالته',
			'wol.add' => 'إضافة جهاز',
			'wol.name' => 'الاسم',
			'wol.saveWake' => 'حفظ وتشغيل',
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
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} إلى ${host}',
			'router.upnpOn' => 'UPnP مفعّل',
			'router.routerLabel' => 'الراوتر',
			'router.internetAddress' => 'عنوان الإنترنت',
			'router.openedBy' => 'فتحتها الأجهزة',
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
			'devices.newBadge' => 'جديد',
			'devices.scanning' => ({required Object n}) => 'جارٍ فحص ${n} من 254',
			'devices.newSince' => ({required Object n}) => '${n} جديد منذ آخر فحص',
			'devices.ms' => ({required Object n}) => '${n} مللي ثانية',
			'devices.cameras' => 'الكاميرات',
			'devices.device' => 'الجهاز',
			'devices.online' => 'متصل',
			'devices.model' => 'الطراز',
			'devices.announced' => 'يعرّف نفسه باسم',
			'devices.services' => 'الخدمات المفتوحة',
			'devices.checkingServices' => 'جارٍ فحص الخدمات',
			'devices.noServices' => 'لا تستجيب أي خدمة شائعة',
			'devices.rename' => 'إعادة التسمية',
			'devices.save' => 'حفظ',
			'devices.kinds.phone' => 'هاتف',
			'devices.kinds.computer' => 'حاسوب',
			'devices.kinds.tv' => 'تلفاز',
			'devices.kinds.speaker' => 'سماعة',
			'devices.kinds.printer' => 'طابعة',
			'devices.kinds.camera' => 'كاميرا',
			'devices.kinds.smartHome' => 'منزل ذكي',
			'devices.kinds.router' => 'راوتر',
			'devices.kinds.unknown' => 'لم يعرّف نفسه',
			'devices.details' => 'تفاصيل الشبكة',
			'devices.listView' => 'قائمة',
			'devices.meshView' => 'شبكة مترابطة',
			'devices.offlineHeading' => 'غير متصل',
			'devices.seen' => ({required Object when}) => 'شوهد ${when}',
			'devices.agoMinutes' => ({required Object n}) => 'قبل ${n} د',
			'devices.agoHours' => ({required Object n}) => 'قبل ${n} س',
			'devices.agoDays' => ({required Object n}) => 'قبل ${n} يوم',
			'devices.throughVpn' => 'عبر VPN',
			'devices.closer' => 'الأقرب = يستجيب أسرع',
			'devices.yours' => 'هل هذا لك؟',
			'devices.mine' => 'لي',
			'devices.notMine' => 'ليس لي',
			'devices.whatIsIt' => 'ما هذا؟',
			'devices.ourGuess' => ({required Object kind}) => 'تخميننا: ${kind}',
			'devices.groupPersonal' => 'الهواتف والحواسيب',
			'devices.groupHome' => 'المنزل والوسائط',
			'devices.groupNetwork' => 'الشبكة والمنزل الذكي',
			'devices.onlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} متصل', ), 
			'devices.offlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} غير متصل', ), 
			'devices.toConfirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} للتأكيد', ), 
			'ping.askTitle' => 'Ping لمضيف',
			'ping.askHint' => 'example.com أو 192.168.1.10',
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
			'tools.internet' => 'الإنترنت',
			'tools.speed' => 'اختبار السرعة',
			'tools.speedDesc' => 'التنزيل والرفع وجودة الفيديو',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'زمن الاستجابة والتذبذب مباشرة',
			'tools.status' => 'حالة الخدمات',
			'tools.statusDesc' => 'هل التطبيق متاح أم محظور هنا؟',
			'tools.trace' => 'تتبّع المسار',
			'tools.traceDesc' => 'كل محطة في الطريق إلى موقع',
			'tools.security' => 'هذه الشبكة',
			'tools.devices' => 'الأجهزة على هذه الشبكة',
			'tools.devicesDesc' => 'من على شبكة Wi-Fi لديك',
			'tools.router' => 'فحص الراوتر',
			'tools.routerDesc' => 'المنافذ التي فتحتها أجهزتك',
			'tools.ports' => 'المنافذ المفتوحة',
			'tools.portsDesc' => 'منافذ خطرة على جهاز أو خادم',
			'tools.utilities' => 'أدوات',
			'tools.wifiScanner' => 'ماسح Wi-Fi',
			'tools.wifiDesc' => 'الشبكات من حولك وأهدأ قناة',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'تشغيل حاسوب على هذه الشبكة',
			'tools.passwordCheck' => 'فحص كلمة المرور',
			'tools.passwordCheckDesc' => 'هل تسرّبت؟',
			'tools.linkCheck' => 'فحص الرابط',
			_ => null,
		} ?? switch (path) {
			'tools.linkCheckDesc' => 'هل فتحه آمن؟',
			'tools.breaches' => 'تسريبات البيانات',
			'tools.breachesDesc' => 'ما الذي تسرّب مؤخرًا',
			'tools.blocked' => 'ما المحجوب',
			'tools.blockedDesc' => 'مواقع محجوبة على هذه الشبكة',
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
			'trace.popular' => 'الشائعة',
			'trace.recent' => 'الأخيرة',
			'trace.clearRecent' => 'مسح الأخيرة',
			'trace.hopsCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} قفزة', ), 
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
			'ports.normal' => 'طبيعي',
			'ports.info' => ({required Object n}) => 'يفحص ${n} منفذًا مهمًا على أجهزة الراوتر والأجهزة المنزلية، ويشرح كل منفذ مفتوح.\n\nافحص فقط الأجهزة والخوادم التي تملكها أو تديرها.',
			'ports.checking' => ({required Object n}) => 'جارٍ فحص ${n} منفذًا',
			'ports.yourRouter' => ({required Object ip}) => 'الراوتر الخاص بك هو ${ip}',
			'ports.noneOpen' => ({required Object host}) => 'لا توجد منافذ شائعة مفتوحة على ${host}.',
			'ports.summary' => ({required Object open, required Object n}) => '${open} مفتوح من ${n} تم فحصها',
			'ports.riskyCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} خطر', ), 
			'ports.noneRisky' => 'لا شيء خطر',
			'wifi.title' => 'ماسح Wi-Fi',
			'wifi.allow' => 'السماح بفحص Wi-Fi',
			'wifi.needsPermission' => 'يحتاج إلى إذن الموقع.',
			'wifi.scanning' => 'جارٍ الفحص',
			'wifi.again' => 'افحص مجددًا',
			'wifi.failed' => 'فشل الفحص',
			'wifi.none' => 'لم يُعثر على شبكات. قد تكون خدمة الموقع متوقفة.',
			'wifi.hidden' => 'شبكة مخفية',
			'wifi.nearby' => ({required Object n}) => '${n} شبكات قريبة',
			'wifi.permissionInfo' => 'لا يعرض Android شبكات Wi-Fi القريبة إلا للتطبيقات التي لديها إذن الموقع. يستخدمه G VPN فقط لعرض الشبكات على هذا الهاتف.',
			'wifi.info' => 'يعرض الشبكات من آخر فحص للهاتف. يسمح Android بعدد قليل من الفحوصات في الدقيقة، لذا قد يُظهر الفحص السريع القائمة نفسها. القناة المقترحة هي الأقل ازدحامًا بين 1 و6 و11، وهي القنوات الثلاث غير المتداخلة.',
			'wifi.airMap' => 'خريطة الهواء',
			'wifi.channels' => 'القنوات',
			'wifi.list' => 'القائمة',
			'wifi.secure' => 'آمنة',
			'wifi.weakLabel' => 'ضعيفة',
			'wifi.openLabel' => 'مفتوحة',
			'wifi.sizeIsWidth' => 'الحجم = عرض القناة',
			'wifi.strongest' => 'الأقوى',
			'wifi.openNearby' => 'المفتوحة بالقرب',
			'wifi.onYourChannel' => 'على قناتك',
			'wifi.noneNearby' => 'لا شيء',
			'wifi.verdictOpen' => 'يمكن لأي شخص قريب قراءة ما يُرسل',
			'wifi.verdictWep' => 'حماية قديمة وسهلة الكسر',
			'wifi.verdictWpa' => 'حماية قديمة',
			'wifi.verdictWps' => 'WPS مفعّل: الاختراق أسهل',
			'wifi.verdictGood' => 'محمية جيدًا',
			'wifi.maker' => 'الشركة المصنّعة',
			'wifi.address' => 'العنوان الفعلي',
			'wifi.privateAddress' => 'أنشأه الراوتر للخصوصية',
			'wifi.you' => 'أنت',
			'wifi.onClear' => ({required Object name}) => '${name} على قناة هادئة',
			'wifi.move' => ({required Object name, required Object n}) => 'انقل ${name} إلى القناة ${n}',
			'wifi.clear' => 'هادئة',
			'wifi.busy' => 'مشغولة',
			'wifi.crowded' => 'مزدحمة',
			'wifi.allBands' => 'كل النطاقات',
			'wifi.openOnly' => 'المفتوحة فقط',
			'wifi.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} شبكة', ), 
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
			'gs.ping' => 'زمن الاستجابة',
			'gs.last24' => 'الانشغال، آخر 24 ساعة',
			'gs.noHistory' => 'يمتلئ الرسم مع استخدام الخادم خلال اليوم.',
			'gs.chartLabel' => ({required Object max}) => 'الانشغال خلال آخر 24 ساعة، بحد أقصى ${max} بالمئة',
			'gs.hoursAgo' => 'قبل 24 س',
			'gs.now' => 'الآن',
			'gs.included' => 'مشمول',
			'gs.perkServers' => 'خوادم سريعة وخاصة',
			'gs.perkServersSub' => 'WireGuard، نديرها بأنفسنا، بلا سجلات نشاط',
			'gs.perkLinks' => 'فحص روابط غير محدود',
			'gs.perkLinksSub' => 'افحص كل رابط يصلك',
			'gs.devicesOf' => ({required Object used, required Object limit}) => 'أجهزتك · ${used} من ${limit}',
			'gs.eachKey' => 'لكل هاتف مفتاحه الخاص',
			'gs.connected' => 'متصل',
			'gs.bestNow' => 'الأفضل لك الآن',
			'gs.logsShort' => 'السجلات',
			'map.open' => 'فتح الخريطة',
			'map.searchCountries' => 'ابحث عن دولة',
			'map.noMatch' => 'لا توجد دولة مطابقة',
			'map.locate' => 'موقعي',
			'map.list' => 'قائمة',
			'map.map' => 'خريطة',
			'map.freeServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, zero: 'لا خوادم مجانية', one: 'خادم مجاني واحد', two: 'خادمان مجانيان', few: '${n} خوادم مجانية', many: '${n} خادمًا مجانيًا', other: '${n} خادم مجاني', ), 
			'map.grade.fast' => 'سريع',
			'map.grade.good' => 'جيد',
			'map.grade.slow' => 'بطيء',
			'map.switchTo' => 'تبديل',
			'map.freeServer' => ({required Object n}) => 'خادم مجاني ${n}',
			'map.best' => 'الأفضل',
			'map.gServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} G Server', ), 
			'stats.thisWeek' => 'هذا الأسبوع',
			'stats.time' => 'الوقت',
			'stats.data' => 'البيانات',
			'stats.protected' => 'محمي',
			'stats.throughVpn' => 'عبر VPN',
			'stats.seeDetails' => 'التفاصيل',
			'stats.title' => 'الإحصاءات',
			'stats.week' => 'أسبوع',
			'stats.month' => 'شهر',
			'stats.protectedLabel' => 'محمي',
			'stats.dataUsed' => 'البيانات المستخدمة',
			'stats.byServer' => 'حسب الخادم',
			'stats.onPhone' => 'محفوظة على هذا الهاتف فقط',
			'stats.reset' => 'إعادة الضبط',
			'stats.resetTitle' => 'إعادة ضبط الإحصاءات؟',
			'stats.resetBody' => 'يمحو وقت الحماية والبيانات على هذا الهاتف. لا يمكن التراجع.',
			'stats.hm' => ({required Object h, required Object m}) => '${h} س ${m} د',
			'stats.m' => ({required Object m}) => '${m} د',
			'stats.empty' => 'اتصل لبدء العد.',
			'recents.title' => 'الأخيرة',
			'recents.allServers' => 'كل الخوادم',
			'recents.free' => 'خادم مجاني',
			'recents.yours' => 'خادمك',
			'recents.gserver' => 'G Server',
			'presets.title' => 'الإعدادات الجاهزة',
			'presets.all' => 'الكل',
			'presets.newPreset' => 'إعداد جديد',
			'presets.edit' => 'تعديل الإعداد',
			'presets.name' => 'الاسم',
			'presets.namePlaceholder' => 'إعدادي',
			'presets.server' => 'الخادم',
			'presets.fastestOption' => 'الأسرع',
			'presets.countryOption' => 'الدولة',
			'presets.pickCountry' => 'اختر دولة',
			'presets.skipMyCountry' => 'تجاوز دولتي',
			'presets.notMine' => 'ليست دولتي',
			'presets.protocol' => 'البروتوكول',
			'presets.auto' => 'تلقائي',
			'presets.tryNext' => 'عند الحظر، جرّب الخادم التالي',
			'presets.shield' => 'الدرع',
			'presets.followRules' => 'كما في القواعد',
			'presets.allApps' => 'كل التطبيقات عبر VPN',
			'presets.allAppsShort' => 'كل التطبيقات',
			'presets.save' => 'حفظ',
			'presets.delete' => 'حذف',
			'presets.reset' => 'استعادة الافتراضي',
			'presets.none' => 'لا يوجد خادم مجاني يناسب هذا الإعداد الآن.',
			'presets.names.fastest' => 'الأسرع',
			'presets.names.unblock' => 'فك الحظر',
			'presets.names.streaming' => 'البث',
			'presets.names.privacy' => 'أقصى خصوصية',
			'shield.title' => 'الدرع',
			'shield.sub' => 'يعمل أثناء الاتصال',
			'shield.off' => 'إيقاف',
			'shield.offSub' => 'DNS الخاص بالخادم',
			'shield.malware' => 'البرمجيات الخبيثة',
			'shield.malwareSub' => 'يحظر المواقع الضارة والتصيد',
			'shield.family' => 'البرمجيات الخبيثة ومواقع البالغين',
			'shield.familySub' => 'يحظر محتوى البالغين أيضًا',
			'shield.custom' => 'DNS مخصص',
			'shield.customSub' => 'خوادم DNS الخاصة بك',
			'shield.customHint' => 'عنوان IP، مثل 1.1.1.1',
			'shield.invalid' => 'أدخل عنوان IP واحدًا أو اثنين.',
			'checks.title' => 'فحوصات الأمان',
			'checks.password' => 'كلمة المرور',
			'checks.link' => 'الرابط',
			'checks.pwTitle' => 'هل تسرّبت؟',
			'checks.pwHint' => 'كلمة المرور للفحص',
			'checks.showPassword' => 'إظهار كلمة المرور',
			'checks.hidePassword' => 'إخفاء كلمة المرور',
			'checks.check' => 'افحص',
			'checks.leaked' => 'موجودة في التسريبات',
			'checks.seen' => ({required Object n}) => 'ظهرت ${n} مرة',
			'checks.leakedAdvice' => 'غيّرها في كل مكان تستخدمها فيه، بدءًا بالبريد والبنك.',
			'checks.notFound' => 'غير موجودة في التسريبات المعروفة',
			'checks.notFoundAdvice' => 'علامة جيدة وليست ضمانًا. استخدم كلمة مرور مختلفة لكل حساب.',
			'checks.failed' => 'تعذّر الفحص. حاول مجددًا.',
			'checks.private' => 'كلمة مرورك لا تغادر هذا الهاتف أبدًا',
			'checks.linkTitle' => 'هل هذا الرابط آمن؟',
			'checks.linkHint' => 'الرابط للفحص',
			'checks.paste' => 'لصق',
			'checks.danger' => 'رابط خطير',
			'checks.dangerAdvice' => 'لا تفتحه ولا تُدخل أي بيانات.',
			'checks.clear' => 'ليس في القوائم المعروفة للبرمجيات الخبيثة أو التصيّد',
			'checks.clearAdvice' => 'ومع ذلك، تحقّق من العنوان قبل تسجيل الدخول.',
			'checks.goesTo' => 'يؤدي إلى',
			'checks.redirects' => 'عمليات التحويل',
			'checks.invalid' => 'هذا لا يبدو عنوان ويب.',
			'checks.busy' => 'فحوصات كثيرة. حاول بعد قليل.',
			'checks.unavailable' => 'فحص الروابط غير متاح الآن.',
			'checks.listed' => 'معروف بالبرمجيات الخبيثة أو التصيّد',
			'checks.missing' => 'لا يوجد موقع على هذا العنوان',
			'checks.missingAdvice' => 'تحقّق من الكتابة: يستخدم المحتالون عناوين متشابهة.',
			'checks.left' => ({required Object n, required Object total}) => 'تبقّى ${n} من ${total} فحوصات مجانية هذا الشهر',
			'checks.usedUp' => 'استخدمت فحوصات الروابط المجانية لهذا الشهر',
			'checks.usedUpSub' => 'في Pro فحوصات بلا حد. تعود الفحوصات المجانية في اليوم الأول من الشهر.',
			'checks.getPro' => 'احصل على Pro',
			'toolSettings.title' => 'إعدادات الأدوات',
			'toolSettings.askMobile' => 'اسأل قبل اختبار السرعة على بيانات الجوال',
			'toolSettings.askMobileSub' => 'قد يستهلك الاختبار أكثر من 100 ميغابايت على اتصال سريع',
			'toolSettings.mobileTitle' => 'استخدام بيانات الجوال؟',
			'toolSettings.mobileBody' => 'قد يستهلك اختبار السرعة أكثر من 100 ميغابايت على اتصال سريع.',
			'toolSettings.mobileGo' => 'اختبار',
			'toolSettings.safe' => 'آمنة',
			'toolSettings.unsafe' => 'غير آمنة',
			'toolSettings.devices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} جهاز', ), 
			'toolSettings.hideMac' => 'إخفاء العناوين الفعلية',
			'toolSettings.hideMacSub' => 'عرض جزء الشركة المصنّعة فقط من عناوين MAC',
			'toolSettings.names' => 'إظهار أسماء الراوترات والخوادم',
			'toolSettings.namesSub' => 'يبحث عن أسماء العناوين في Traceroute',
			'toolSettings.remember' => 'تذكّر المضيفين الأخيرين',
			'toolSettings.rememberSub' => 'لـ Traceroute',
			'toolSettings.clear' => 'مسح سجل الأدوات',
			'toolSettings.clearSub' => 'ينسى المضيفين الأخيرين والأجهزة في كل شبكة',
			'toolSettings.clearGo' => 'مسح',
			'security.tab' => 'الأمان',
			'security.good' => 'جيد',
			'security.fair' => 'مقبول',
			'security.atRisk' => 'في خطر',
			'security.allClear' => 'لا شيء لإصلاحه',
			'security.checked' => ({required Object time}) => 'فُحصت الساعة ${time}',
			'security.trend' => 'آخر أسبوعين',
			'security.checking' => 'جارٍ فحص هذه الشبكة',
			'security.snoozed' => 'مؤجلة',
			'security.remindLater' => 'ذكّرني لاحقًا',
			'security.unsnooze' => 'ذكّرني الآن',
			'security.review' => 'مراجعة',
			'security.confirmGo' => 'تأكيد',
			'security.scanGo' => 'فحص',
			'security.look' => 'عرض',
			'security.connectGo' => 'اتصال',
			'security.checkAgain' => 'افحص مجددًا',
			'security.wifiOpen' => 'شبكة Wi-Fi مفتوحة',
			'security.wifiOpenDetail' => 'يمكن لأي شخص قريب رؤية ما يُرسل',
			'security.wifiWep' => 'الشبكة تستخدم WEP',
			'security.wifiWepDetail' => 'حماية قديمة وسهلة الكسر',
			'security.wifiOwe' => 'الشبكة تستخدم Enhanced Open',
			'security.wifiOweDetail' => 'مشفّرة لكن يمكن لأي شخص الانضمام',
			'security.wifiSecure' => 'تشفير Wi-Fi',
			'security.wifiUnknown' => 'أمان Wi-Fi غير معروف',
			'security.wifiUnknownDetail' => 'لم يذكر Android طريقة الحماية',
			'security.wps' => 'WPS مفعّل',
			'security.wpsDetail' => 'أوقفه من إعدادات الراوتر',
			'security.upnpOff' => 'الراوتر يبقي المنافذ مغلقة',
			'security.upnpOffDetail' => 'UPnP متوقف',
			'security.upnpOn' => 'الراوتر يسمح للأجهزة بفتح منافذ',
			'security.upnpOnDetail' => 'UPnP مفعّل',
			'security.portsOk' => 'لا منافذ خطرة على الراوتر',
			'security.portsRisky' => 'منافذ خطرة مفتوحة على الراوتر',
			'security.scanFirst' => 'افحص لترى من هنا',
			'security.scanFirstDetail' => 'الأجهزة المجهولة تخفض النتيجة',
			'security.notMineDetail' => 'راجع قائمة أجهزة الراوتر',
			'security.confirmDetail' => 'حدّد أجهزتك',
			'security.devicesOk' => 'كل الأجهزة معروفة',
			'security.devicesOkDetail' => 'أكدت كل جهاز',
			'security.camera' => 'توجد كاميرا على هذه الشبكة',
			'security.dnsHijack' => 'تُعاد توجيه الأسماء المجهولة',
			'security.dnsHijackDetail' => 'مزوّدك أو الراوتر يعيد كتابة الاستعلامات',
			'security.dnsOk' => 'DNS يجيب بشكل طبيعي',
			'security.dnsOkDetail' => 'لا أثر لإعادة التوجيه',
			'security.vpnOn' => 'VPN مفعّل',
			'security.vpnOnDetail' => 'تخرج البيانات عبر النفق',
			'security.vpnOff' => 'VPN متوقف',
			'security.vpnOffDetail' => 'مزوّدك يرى كل موقع',
			'security.toFix' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} أمور لإصلاحها', ), 
			'security.upnpOpened' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} منافذ فتحتها الأجهزة', ), 
			'security.portsChecked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} منافذ فُحصت', ), 
			'security.notMine' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} أجهزة ليست لك', ), 
			'security.confirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} أجهزة للتأكيد', ), 
			'providers.tab' => 'الإنترنت',
			'providers.unavailable' => 'تعذّر تحميل قائمة المزوّدين. تحقق من اتصالك.',
			'providers.cached' => 'حسب آخر فحص بدون VPN',
			'providers.notEnough' => 'لا توجد تقييمات كافية بعد',
			'providers.yourRating' => 'تقييمك هذا الشهر',
			'providers.yourSpeed' => 'سرعتك',
			'providers.runTest' => 'إجراء اختبار سرعة',
			'providers.aboutAverage' => 'قريب من المتوسط هنا',
			'providers.aboveAverage' => ({required Object pct}) => 'أعلى من المتوسط المحلي بنسبة ${pct}٪',
			'providers.belowAverage' => ({required Object pct}) => 'أقل من المتوسط المحلي بنسبة ${pct}٪',
			'providers.call' => 'اتصال',
			'providers.website' => 'الموقع',
			'providers.outages' => 'الأعطال',
			'providers.rate' => 'قيّم',
			'providers.changeRating' => 'تغيير التقييم',
			'providers.compare' => 'قارن',
			'providers.rateTitle' => ({required Object name}) => 'قيّم ${name}',
			'providers.oncePerMonth' => 'تقييم واحد شهريًا',
			'providers.tapStars' => 'اضغط على النجوم',
			'providers.verified' => ({required Object mbps}) => 'موثّق باختبار سرعتك: ${mbps} ميغابت/ث',
			'providers.busy' => 'تقييمات كثيرة من هنا. حاول لاحقًا.',
			'providers.failed' => 'تعذّر الإرسال. حاول مجددًا.',
			'providers.post' => 'إرسال التقييم',
			'providers.nearTitle' => 'مزوّدون بالقرب منك',
			'providers.slower' => ({required Object pct}) => 'التنزيل لديك أقل بنسبة ${pct}٪ من متوسط مزوّدك هنا',
			'providers.inPlace' => ({required Object place}) => 'الإنترنت المنزلي في ${place}',
			'providers.byRating' => 'التقييم',
			'providers.bySpeed' => 'السرعة',
			'providers.footnote' => 'السرعات متوسطات اختبارات G VPN',
			'providers.noneNearby' => 'لا تقييمات قريبة بعد. كن الأول.',
			'providers.you' => 'أنت',
			'providers.topRated' => 'الأعلى تقييمًا',
			'providers.starsOf' => ({required Object n}) => '${n} من 5',
			'providers.tags.fast' => 'سريع',
			'providers.tags.reliable' => 'موثوق',
			'providers.tags.support' => 'دعم جيد',
			'providers.tags.price' => 'سعر عادل',
			'providers.tags.slowEvenings' => 'بطيء مساءً',
			'providers.tags.drops' => 'ينقطع كثيرًا',
			'providers.tags.poorSupport' => 'دعم سيئ',
			'providers.tags.pricey' => 'مكلف',
			'providers.words.bad' => 'سيئ',
			'providers.words.poor' => 'ضعيف',
			'providers.words.okay' => 'مقبول',
			'providers.words.good' => 'جيد',
			'providers.words.great' => 'ممتاز',
			'providers.ratings' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} تقييمات', ), 
			'alerts.channel' => 'التنبيهات',
			'alerts.title' => 'التنبيهات',
			'alerts.markAllRead' => 'تعليم الكل كمقروء',
			'alerts.clearAll' => 'مسح الكل',
			'alerts.thisNetwork' => 'هذه الشبكة',
			'alerts.openWifiTitle' => ({required Object name}) => 'اتصلت بشبكة Wi-Fi مفتوحة: ${name}',
			'alerts.openWifiBody' => 'يمكن لأي شخص قريب رؤية ما يُرسل. شغّل G VPN.',
			'alerts.reportTitle' => 'تقريرك الأسبوعي جاهز',
			'alerts.reportBody' => ({required Object hours}) => '${hours} ساعات حماية الأسبوع الماضي',
			'alerts.blockedTitle' => ({required Object name}) => '${name} محظور هنا',
			'alerts.blockedBody' => 'يعمل عبر VPN',
			'alerts.kinds.newDevice' => 'أجهزة جديدة على شبكتي',
			'alerts.kinds.openWifi' => 'Wi-Fi مفتوحة أو ضعيفة',
			'alerts.kinds.blocked' => 'تطبيقات محظورة',
			'alerts.kinds.report' => 'التقرير الأسبوعي',
			'alerts.kinds.breach' => 'التسريبات',
			'alerts.newDeviceTitle' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} أجهزة جديدة على ${network}', ), 
			'alerts.settings' => 'إعدادات التنبيهات',
			'alerts.look' => 'عرض',
			'alerts.read' => 'قراءة',
			'alerts.open' => 'فتح',
			'alerts.check' => 'فحص',
			'alerts.today' => 'اليوم',
			'alerts.thisWeek' => 'هذا الأسبوع',
			'alerts.earlier' => 'سابقًا',
			'alerts.all' => 'الكل',
			'alerts.quiet' => 'كل شيء هادئ',
			'alerts.quietSub' => 'لم يحتج إليك شيء مؤخرًا',
			'alerts.breachTitle' => ({required Object name}) => 'تسريب جديد: ${name}',
			'alerts.status.background' => 'كل بضع ساعات',
			'alerts.status.checked' => ({required Object time}) => 'فُحص الساعة ${time}',
			'alerts.status.wifi' => 'كل شبكة تنضم إليها',
			'alerts.status.blocked' => 'عند فحص حالة الخدمات',
			'alerts.status.report' => 'كل يوم اثنين',
			'report.title' => 'التقرير الأسبوعي',
			'report.share' => 'مشاركة كصورة',
			'report.shareText' => 'أسبوعي مع G VPN',
			'report.safer' => 'أسبوع أكثر أمانًا',
			'report.moreProtected' => 'حماية أكثر من الأسبوع الماضي',
			'report.yourWeek' => 'أسبوعك',
			'report.soFar' => ({required Object range}) => '${range}، حتى الآن',
			'report.protected' => 'محمي',
			'report.data' => 'البيانات',
			'report.security' => 'الأمان',
			'report.speed' => 'أفضل سرعة',
			'report.noScore' => 'لم يُفحص',
			'report.noTest' => 'لا اختبار',
			'report.bestDirect' => 'اختبار مباشر',
			'report.moreThan' => ({required Object d}) => 'أكثر بـ ${d} من الأسبوع الماضي',
			'report.lessThan' => ({required Object d}) => 'أقل بـ ${d} من الأسبوع الماضي',
			'report.protectedTime' => 'وقت الحماية',
			'report.mostUsed' => ({required Object name}) => 'الأكثر استخدامًا: ${name}',
			'report.quiet' => 'أسبوع هادئ: لم يحتج شيء إليك',
			'report.newDevices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: 'انضمت ${n} أجهزة جديدة', ), 
			'report.openWifi' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: 'اتصلت بـ ${n} شبكات Wi-Fi مفتوحة', ), 
			'report.blocked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} تطبيقات محظورة', ), 
			'report.breaches' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} تسريبات كبيرة جديدة', ), 
			'breaches.title' => 'تسريبات البيانات',
			'breaches.info' => 'أحدث تسريبات البيانات من القائمة العامة لـ Have I Been Pwned. لا يُرسل شيء عنك: القائمة واحدة للجميع.\n\nإن كان لديك حساب في موقع مُسرَّب فغيّر تلك الكلمة، وكل مكان استخدمتها فيه.',
			'breaches.unavailable' => 'تعذّر تحميل القائمة. تحقق من اتصالك.',
			'breaches.biggest' => 'الأكبر هذا الشهر',
			'breaches.newest' => 'الأحدث',
			'breaches.biggestSort' => 'الأكبر',
			'breaches.withPasswords' => 'مع كلمات مرور',
			'breaches.passwordsMark' => 'كلمات مرور',
			'breaches.one' => 'تسريب',
			_ => null,
		} ?? switch (path) {
			'breaches.checkPassword' => 'فحص كلمة مرور',
			'breaches.verified' => 'موثّق',
			'breaches.hasPasswords' => 'يحتوي كلمات مرور',
			'breaches.accountsLabel' => 'الحسابات',
			'breaches.happened' => 'حدث',
			'breaches.published' => 'نُشر',
			'breaches.website' => 'الموقع',
			'breaches.leaked' => 'ما الذي تسرّب',
			'breaches.ifUsed' => 'إن كنت تستخدمه',
			'breaches.stepPassword' => 'غيّر كلمة المرور التي استخدمتها هناك',
			'breaches.stepReuse' => 'غيّرها حيثما استخدمت الكلمة نفسها',
			'breaches.stepTwoStep' => 'فعّل التحقق بخطوتين حيث أمكن',
			'breaches.stepScams' => 'توقّع مكالمات ورسائل احتيال',
			'breaches.accounts' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${count} حساب', ), 
			'breaches.worldwide' => ({required Object n}) => 'عالميًا · ${n}',
			'breaches.noneHere' => 'لا تسريبات من هنا في القائمة الأخيرة.',
			'breaches.bigMap' => 'خريطة أكبر',
			'breaches.showInList' => 'عرض في القائمة',
			'breaches.mapTitle' => 'خريطة التسريبات',
			'breaches.zoomIn' => 'تكبير',
			'breaches.zoomOut' => 'تصغير',
			'breaches.wholeWorld' => 'العالم كله',
			'breaches.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} تسريبات', ), 
			'breaches.findCountry' => 'ابحث عن دولة',
			'breaches.seeAll' => 'عرض الكل',
			'breaches.search' => 'ابحث في التسريبات',
			'blocked.title' => 'ما المحجوب',
			'blocked.info' => 'يختبر مواقع معروفة من هذا الهاتف، دون VPN، ويبيّن أيها تحجبه هذه الشبكة وكيف.\n\nعنوان مزيف: بحث الأسماء في الشبكة يعطي إجابة خاطئة.\n\nمقطوع: يُقطع الاتصال عند بدايته.\n\nلا إجابة: لا يعود شيء.\n\nصفحة حجب: يجيب شيء آخر مكان الموقع.\n\nيبيّن الاختبار أين الموقع محجوب، لا من حجبه. لا يُحفظ أو يُرسل أي شيء.',
			'blocked.thisNetwork' => 'هذه الشبكة',
			'blocked.country' => 'بلدك',
			'blocked.question' => 'ما المحجوب هنا؟',
			'blocked.testingOn' => 'الاختبار على',
			'blocked.vpnOn' => 'VPN مفعّل',
			'blocked.turnOff' => 'أوقف G VPN للاختبار',
			'blocked.test' => 'اختبر هذه الشبكة',
			'blocked.stop' => 'إيقاف',
			'blocked.sitesToTest' => ({required Object n}) => 'مواقع للاختبار · ${n}',
			'blocked.ofSites' => ({required Object n}) => 'من ${n} موقعًا',
			'blocked.blockedCount' => ({required Object n}) => '${n} محجوب',
			'blocked.openCount' => ({required Object n}) => '${n} مفتوح',
			'blocked.noneBlocked' => ({required Object network}) => 'لا شيء محجوب على ${network}',
			'blocked.openOf' => ({required Object open, required Object total}) => '${open} من ${total} مفتوحة',
			'blocked.allWork' => 'كلها تعمل مع G VPN',
			'blocked.blockedHeading' => 'محجوب',
			'blocked.byKind' => 'حسب النوع',
			'blocked.worksVpn' => 'يعمل مع VPN',
			'blocked.failsVpn' => 'محجوب حتى مع VPN',
			'blocked.checkVpn' => 'تحقق عبر G VPN',
			'blocked.connect' => 'اتصل بـ G VPN',
			'blocked.again' => 'اختبر مجددًا',
			'blocked.withoutVpn' => 'دون VPN',
			'blocked.throughVpn' => 'عبر G VPN',
			'blocked.notChecked' => 'لم يُتحقق',
			'blocked.opens' => 'يفتح',
			'blocked.stillBlocked' => 'محجوب',
			'blocked.whatHappened' => 'ما الذي حدث',
			'blocked.countryBlocked' => ({required Object country}) => 'موقعًا محجوبًا في ${country}',
			'blocked.countrySub' => 'وجدتها اختبارات المتطوعين في آخر 30 يومًا',
			'blocked.countryNone' => 'لا مواقع محجوبة مُبلّغ عنها في آخر 30 يومًا.',
			'blocked.countryUnavailable' => 'تعذّر تحميل نتائج البلد. تحقق من اتصالك.',
			'blocked.confirmed' => 'محجوب',
			'blocked.oftenFails' => 'يفشل كثيرًا',
			'blocked.kinds.social' => 'التواصل الاجتماعي',
			'blocked.kinds.messaging' => 'المراسلة',
			'blocked.kinds.news' => 'الأخبار',
			'blocked.kinds.video' => 'الفيديو والموسيقى',
			'blocked.kinds.privacy' => 'أدوات الخصوصية',
			'blocked.how.dns' => 'عنوان مزيف',
			'blocked.how.reset' => 'مقطوع',
			'blocked.how.timeout' => 'لا إجابة',
			'blocked.how.page' => 'صفحة حجب',
			'blocked.how.open' => 'مفتوح',
			'blocked.fail.noAnswer' => 'لا إجابة',
			'blocked.fail.refused' => 'مرفوض',
			'blocked.fail.cutOff' => ({required Object s}) => 'قُطع بعد ${s} ث',
			'blocked.fail.wrongCert' => 'شهادة خاطئة',
			'blocked.steps.lookup' => 'بحث الاسم',
			'blocked.steps.connect' => 'الاتصال',
			'blocked.steps.handshake' => 'المصافحة الآمنة',
			'blocked.consent.title' => 'قبل الاختبار الأول',
			'blocked.consent.body' => 'يفتح الاختبار كل موقع من هذا الهاتف، دون VPN، كما يفعل المتصفح.',
			'blocked.consent.noticeTitle' => 'قد يُلاحَظ',
			'blocked.consent.notice' => 'يرى مزوّدك فتح هذه المواقع. في بعض البلدان قد تلفت زيارتها الانتباه حتى للاختبار. اختبر فقط حيث تشعر بالأمان.',
			'blocked.consent.ok' => 'فهمت، اختبر',
			'blocked.someBlocked' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} مواقع محجوبة على ${network}', ), 
			'blocked.tests' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ar'))(n, other: '${n} اختبارات', ), 
			_ => null,
		};
	}
}
