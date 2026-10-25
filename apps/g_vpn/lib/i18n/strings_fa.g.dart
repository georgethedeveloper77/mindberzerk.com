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
class TranslationsFa extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsFa({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.fa,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <fa>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsFa _root = this; // ignore: unused_field

	@override 
	TranslationsFa $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsFa(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$fa common = _Translations$common$fa._(_root);
	@override late final _Translations$nav$fa nav = _Translations$nav$fa._(_root);
	@override late final _Translations$home$fa home = _Translations$home$fa._(_root);
	@override late final _Translations$servers$fa servers = _Translations$servers$fa._(_root);
	@override late final _Translations$pro$fa pro = _Translations$pro$fa._(_root);
	@override late final _Translations$rules$fa rules = _Translations$rules$fa._(_root);
	@override late final _Translations$apps$fa apps = _Translations$apps$fa._(_root);
	@override late final _Translations$location$fa location = _Translations$location$fa._(_root);
	@override late final _Translations$addServer$fa addServer = _Translations$addServer$fa._(_root);
	@override late final _Translations$button$fa button = _Translations$button$fa._(_root);
	@override late final _Translations$wol$fa wol = _Translations$wol$fa._(_root);
	@override late final _Translations$speed$fa speed = _Translations$speed$fa._(_root);
	@override late final _Translations$router$fa router = _Translations$router$fa._(_root);
	@override late final _Translations$network$fa network = _Translations$network$fa._(_root);
	@override late final _Translations$devices$fa devices = _Translations$devices$fa._(_root);
	@override late final _Translations$ping$fa ping = _Translations$ping$fa._(_root);
	@override late final _Translations$status$fa status = _Translations$status$fa._(_root);
	@override late final _Translations$tools$fa tools = _Translations$tools$fa._(_root);
	@override late final _Translations$trace$fa trace = _Translations$trace$fa._(_root);
	@override late final _Translations$ports$fa ports = _Translations$ports$fa._(_root);
	@override late final _Translations$wifi$fa wifi = _Translations$wifi$fa._(_root);
	@override late final _Translations$errors$fa errors = _Translations$errors$fa._(_root);
	@override late final _Translations$scan$fa scan = _Translations$scan$fa._(_root);
	@override late final _Translations$legal$fa legal = _Translations$legal$fa._(_root);
	@override late final _Translations$update$fa update = _Translations$update$fa._(_root);
	@override late final _Translations$details$fa details = _Translations$details$fa._(_root);
	@override late final _Translations$share$fa share = _Translations$share$fa._(_root);
	@override late final _Translations$add$fa add = _Translations$add$fa._(_root);
	@override late final _Translations$backup$fa backup = _Translations$backup$fa._(_root);
	@override late final _Translations$gs$fa gs = _Translations$gs$fa._(_root);
}

// Path: common
class _Translations$common$fa extends Translations$common$en {
	_Translations$common$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get gotIt => 'متوجه شدم';
	@override String get about => 'درباره';
	@override String get connect => 'اتصال';
	@override String get connected => 'متصل';
	@override String get retry => 'تلاش دوباره';
	@override String get ok => 'باشه';
	@override String get remove => 'حذف';
	@override String get cancel => 'لغو';
	@override String get continueLabel => 'ادامه';
	@override String get notNow => 'الان نه';
	@override String get openSettings => 'باز کردن تنظیمات';
	@override String get close => 'بستن';
	@override String get off => 'خاموش';
	@override String get changesReconnect => 'تغییرات، VPN را دوباره وصل می‌کند';
}

// Path: nav
class _Translations$nav$fa extends Translations$nav$en {
	_Translations$nav$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get vpn => 'VPN';
	@override String get servers => 'سرورها';
	@override String get tools => 'ابزارها';
	@override String get rules => 'قوانین';
	@override String get pro => 'Pro';
}

// Path: home
class _Translations$home$fa extends Translations$home$en {
	_Translations$home$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$status$fa status = _Translations$home$status$fa._(_root);
	@override String resumesAt({required Object time}) => 'ادامه در ${time} · برای ادامه ضربه بزنید';
	@override String sitesSee({required Object ip}) => 'سایت‌ها می‌بینند: ${ip}';
	@override String sitesSeeOrg({required Object ip, required Object org}) => 'سایت‌ها می‌بینند: ${ip} · ${org}';
	@override String get ipFailed => 'بررسی IP ممکن نشد';
	@override String get ipChecking => 'در حال بررسی IP';
	@override String get themeSystem => 'پوسته: مطابق گوشی';
	@override String get themeLight => 'پوسته: روشن';
	@override String get themeDark => 'پوسته: تیره';
	@override String get free => 'رایگان';
	@override String get pickServer => 'یک سرور انتخاب کنید';
	@override late final _Translations$home$waves$fa waves = _Translations$home$waves$fa._(_root);
	@override late final _Translations$home$network$fa network = _Translations$home$network$fa._(_root);
	@override late final _Translations$home$card$fa card = _Translations$home$card$fa._(_root);
	@override late final _Translations$home$tiles$fa tiles = _Translations$home$tiles$fa._(_root);
	@override late final _Translations$home$fastest$fa fastest = _Translations$home$fastest$fa._(_root);
	@override late final _Translations$home$ip$fa ip = _Translations$home$ip$fa._(_root);
}

// Path: servers
class _Translations$servers$fa extends Translations$servers$en {
	_Translations$servers$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'سرورها';
	@override String get aboutServers => 'درباره سرورها';
	@override late final _Translations$servers$tabs$fa tabs = _Translations$servers$tabs$fa._(_root);
	@override late final _Translations$servers$sheet$fa sheet = _Translations$servers$sheet$fa._(_root);
	@override late final _Translations$servers$badges$fa badges = _Translations$servers$badges$fa._(_root);
	@override late final _Translations$servers$filters$fa filters = _Translations$servers$filters$fa._(_root);
	@override String get loadFailed => 'بارگیری فهرست ممکن نشد';
	@override String get noServers => 'فعلاً سروری نیست';
	@override String get best => 'بهترین برای شما';
	@override String get topRanked => 'بالاترین رتبه در حال حاضر';
	@override String get addHeading => 'افزودن سرور';
	@override String get scanQr => 'اسکن QR';
	@override String get importFile => 'وارد کردن فایل';
	@override String get paste => 'چسباندن';
	@override late final _Translations$servers$own$fa own = _Translations$servers$own$fa._(_root);
	@override String get configBroken => 'پیکربندی نیاز به بررسی دارد';
	@override String get connectedBadge => 'متصل';
	@override String get scannedServer => 'سرور اسکن‌شده';
	@override String get scanFailedTitle => 'اسکن ممکن نشد';
	@override String get scanFailedBody => 'اسکنر روی این گوشی در دسترس نیست.';
	@override String get importFailedTitle => 'وارد کردن ممکن نشد';
	@override String get importFailedBody => 'آن فایل خوانده نشد.';
	@override String get renameTitle => 'تغییر نام سرور';
	@override String get nameHint => 'نام، مثلاً روتر خانه';
	@override String get save => 'ذخیره';
	@override String get rename => 'تغییر نام';
	@override String get disconnect => 'قطع اتصال';
	@override String get more => 'گزینه‌های بیشتر';
	@override String get justNow => 'همین الان';
	@override String minutesAgo({required Object n}) => '${n} دقیقه پیش';
	@override String hoursAgo({required Object n}) => '${n} ساعت پیش';
	@override String daysAgo({required Object n}) => '${n} روز پیش';
	@override String get neverUsed => 'هنوز استفاده نشده';
	@override String lastUsed({required Object when}) => 'آخرین استفاده: ${when}';
	@override String get disconnectFirst => 'برای حذف، ابتدا اتصال را قطع کنید';
	@override String get removeConfirm => 'این سرور از G VPN حذف شود؟ تنظیمات آن از این گوشی پاک می‌شود؛ خود سرور تغییری نمی‌کند.';
}

// Path: pro
class _Translations$pro$fa extends Translations$pro$en {
	_Translations$pro$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get owned => 'شما Pro دارید';
	@override String get waitingPlay => 'در انتظار Google Play';
	@override String startTrial({required Object days}) => 'شروع دوره رایگان ${days} روزه';
	@override String thenYearly({required Object price}) => 'سپس سالی ${price}. هر زمان در Google Play لغو کنید.';
	@override String thenMonthly({required Object price}) => 'سپس ماهی ${price}. هر زمان در Google Play لغو کنید.';
	@override String yearlyPrice({required Object price}) => 'سالی ${price}. هر زمان در Google Play لغو کنید.';
	@override String monthlyPrice({required Object price}) => 'ماهی ${price}. هر زمان در Google Play لغو کنید.';
	@override String get restore => 'بازیابی';
	@override String get heroTitle => 'سرورهای سریع‌تر،\nاداره‌شده توسط ما';
	@override String get heroSubtitle => 'WireGuard. بدون گزارش فعالیت. بدون حساب کاربری.';
	@override String get benefitSpeed => 'سرعت کامل، بدون محدودیت سرورهای داوطلبانه';
	@override String get benefitKey => 'کلید روی گوشی شما ساخته می‌شود و هرگز به اشتراک گذاشته نمی‌شود';
	@override String get benefitFree => 'هر چیز رایگان، رایگان می‌ماند';
	@override String save({required Object pct}) => '${pct}٪ صرفه‌جویی';
	@override String get yearly => 'سالانه';
	@override String get monthly => 'ماهانه';
	@override String get billedMonthly => 'پرداخت ماهانه';
	@override String daysFree({required Object days}) => '${days} روز رایگان';
	@override String perMonth({required Object price}) => 'ماهی ${price}';
	@override String get title => 'G VPN Pro';
	@override String get heroTitleOneLine => 'سرورهای سریع‌تر، اداره‌شده توسط ما';
	@override String get includes => 'شامل';
	@override String get benefitLogs => 'بدون گزارش فعالیت روی سرورهای ما';
	@override String get plan => 'یک طرح انتخاب کنید';
	@override String get renewGeneric => 'اشتراک‌ها تا زمان لغو خودکار تمدید می‌شوند. هر زمان در Google Play لغو کنید.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} روز رایگان، سپس ${price} در هر ${period}. تا زمان لغو خودکار تمدید می‌شود؛ برای جلوگیری از پرداخت، دست‌کم یک روز پیش از پایان دوره رایگان در Google Play لغو کنید.';
	@override String renew({required Object price, required Object period}) => '${price} در هر ${period}. تا زمان لغو خودکار تمدید می‌شود؛ هر زمان در Google Play لغو کنید.';
	@override String get year => 'سال';
	@override String get month => 'ماه';
	@override String get manage => 'مدیریت اشتراک';
	@override late final _Translations$pro$free$fa free = _Translations$pro$free$fa._(_root);
}

// Path: rules
class _Translations$rules$fa extends Translations$rules$en {
	_Translations$rules$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'قوانین';
	@override late final _Translations$rules$info$fa info = _Translations$rules$info$fa._(_root);
	@override String get protection => 'محافظت';
	@override String get shield => 'سپر';
	@override String get shieldSub => 'سایت‌های بدافزار و فیشینگ را مسدود می‌کند';
	@override String get privateDns => 'سپر بدون VPN';
	@override String get privateDnsSub => 'کپی dns.quad9.net برای DNS خصوصی';
	@override String get privateDnsCopied => 'dns.quad9.net کپی شد';
	@override String get privateDnsHow => 'تنظیمات را باز کنید، «DNS خصوصی» را جست‌وجو کنید، «نام میزبان ارائه‌دهنده DNS خصوصی» را انتخاب کنید و آن را بچسبانید.';
	@override String get stay => 'متصل ماندن';
	@override String get alwaysOn => 'VPN همیشه روشن';
	@override String get alwaysOnSub => 'اگر G VPN متوقف شود، اندروید آن را دوباره اجرا می‌کند';
	@override String get battery => 'باتری';
	@override String get batteryOk => 'بدون محدودیت';
	@override String get batteryRestricted => 'محدود: ممکن است در پس‌زمینه متوقف شود';
	@override String get autoConnect => 'اتصال خودکار';
	@override String get autoOff => 'خاموش';
	@override String get autoOffSub => 'فقط وقتی ضربه بزنید';
	@override String get autoOpen => 'Wi-Fi عمومی';
	@override String get autoOpenSub => 'شبکه‌های باز، WEP یا دارای صفحه ورود';
	@override String get autoAny => 'هر Wi-Fi';
	@override String get autoAnySub => 'هر شبکه Wi-Fi';
	@override String get apps => 'برنامه‌ها';
	@override String get appsDirect => 'برنامه‌های مستقیم';
	@override String get appsNone => 'همه برنامه‌ها از VPN استفاده می‌کنند';
	@override String appsSome({required Object n}) => '${n} برنامه بدون VPN';
	@override String get appearance => 'ظاهر';
	@override String get themePhone => 'گوشی';
	@override String get themeLight => 'روشن';
	@override String get themeDark => 'تیره';
	@override String get about => 'درباره';
}

// Path: apps
class _Translations$apps$fa extends Translations$apps$en {
	_Translations$apps$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'برنامه‌های مستقیم';
	@override String get sheetSubtitle => 'برنامه‌های انتخاب‌شده بدون VPN وصل می‌شوند. بقیه محافظت‌شده می‌مانند.';
	@override String get whyTitle => 'چرا یک برنامه را مستثنا کنیم';
	@override String get whyBody => 'بانک‌ها و برنامه‌های پرداخت اغلب آدرس‌های VPN را مسدود می‌کنند، پس پرداخت از طریق VPN ممکن است ناموفق باشد. برخی خدمات محلی فقط از کشور خودتان کار می‌کنند.';
	@override String get favouritesBody => 'برنامه‌هایی را که زیاد تغییر می‌دهید ستاره‌دار کنید؛ بالای فهرست می‌مانند.';
	@override String get whileConnected => 'هنگام اتصال';
	@override String get whileConnectedBody => 'تغییر این فهرست، VPN را برای لحظه‌ای دوباره وصل می‌کند.';
	@override String search({required Object n}) => 'جست‌وجو در ${n} برنامه';
	@override String get skipping => 'بدون VPN';
	@override String get skippingNone => 'هیچ. همه برنامه‌ها از VPN عبور می‌کنند.';
	@override String protectAgain({required Object app}) => 'محافظت دوباره از ${app}';
	@override String get banking => 'بانک و پرداخت';
	@override String bankingFound({required Object n}) => '${n} برنامه پیدا شد که ممکن است VPN را مسدود کنند';
	@override String get addAll => 'افزودن همه';
	@override String get favourites => 'علاقه‌مندی‌ها';
	@override String get all => 'همه برنامه‌ها';
	@override String found({required Object n}) => '${n} مورد پیدا شد';
	@override String get noMatch => 'برنامه‌ای پیدا نشد.';
	@override String showAll({required Object n}) => 'نمایش همه ${n}';
	@override String get skips => 'بدون VPN';
	@override String get unstar => 'حذف از علاقه‌مندی‌ها';
	@override String get star => 'افزودن به علاقه‌مندی‌ها';
}

// Path: location
class _Translations$location$fa extends Translations$location$en {
	_Translations$location$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'اجازه موقعیت برای Wi-Fi';
	@override String get useHome => 'نمایش نام Wi-Fi در صفحه اصلی';
	@override String get useScan => 'اسکن شبکه‌ها و کانال‌های اطراف';
	@override String get private => 'روی همین گوشی می‌ماند. موقعیت شما هرگز جمع‌آوری نمی‌شود.';
	@override String get switchTitle => 'روشن کردن موقعیت مکانی';
	@override String get switchBody => 'وقتی موقعیت مکانی خاموش است، اندروید نام Wi-Fi را پنهان می‌کند';
}

// Path: addServer
class _Translations$addServer$fa extends Translations$addServer$en {
	_Translations$addServer$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get clipboardEmpty => 'کلیپ‌بورد خالی است.';
	@override String get title => 'سرور خود را اضافه کنید';
	@override String get body => 'یک پیکربندی WireGuard از روتر، VPS یا سرور خانگی خود بچسبانید.';
	@override String get nameHint => 'نام، مثلاً روتر خانه';
	@override String get paste => 'چسباندن';
	@override String get save => 'ذخیره سرور';
	@override String notWireguard({required Object error}) => 'این یک پیکربندی WireGuard نیست: ${error}';
}

// Path: button
class _Translations$button$fa extends Translations$button$en {
	_Translations$button$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get stop => 'توقف';
	@override String get connecting => 'در حال اتصال';
	@override String get stopping => 'در حال قطع';
	@override String get connect => 'اتصال';
	@override String get disconnect => 'قطع اتصال';
}

// Path: wol
class _Translations$wol$fa extends Translations$wol$en {
	_Translations$wol$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get info => 'اگر Wake on LAN در تنظیمات یک کامپیوتر یا NAS در این Wi-Fi فعال باشد، آن را روشن می‌کند. گوشی شما باید در همان شبکه باشد؛ ابتدا VPN را خاموش کنید.';
	@override String get badMac => 'این آدرس MAC نیست. شکل آن مانند AA:BB:CC:DD:EE:FF است.';
	@override String get sent => 'سیگنال روشن شدن ارسال شد. دستگاه باید ظرف یک دقیقه روشن شود.';
	@override String get title => 'Wake on LAN';
	@override String get wake => 'روشن کردن دستگاه';
	@override String get mac => 'آدرس MAC';
	@override String failed({required Object error}) => 'ارسال ممکن نشد: ${error}';
}

// Path: speed
class _Translations$speed$fa extends Translations$speed$en {
	_Translations$speed$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get info => 'اندازه‌گیری توسط M-Lab، یک پلتفرم پژوهشی باز. هر آزمایش حدود ۵۰ تا ۱۰۰ مگابایت مصرف می‌کند.\n\nنتایج عمومی: M-Lab هر آزمایش، از جمله آدرس IP مبدأ آن، را به‌عنوان داده پژوهشی باز منتشر می‌کند.\n\nمقایسه ارائه‌دهنده: پس از آزمایش بدون VPN، G VPN فقط سه عدد سرعت را می‌فرستد. سرویس مقایسه، ارائه‌دهنده و شهر شما را از خود اتصال می‌خواند و هیچ آدرس IP ذخیره نمی‌کند. با کلید پایین این صفحه آن را خاموش کنید.\n\nاز طریق VPN: با VPN روشن، سرعت داخل تونل را اندازه می‌گیرد و با آخرین آزمایش بدون VPN مقایسه می‌کند.\n\nپیش‌نمایش ویدیو: همان تصویر با وضوحی که این سرعت می‌تواند پخش کند، بر اساس نرخ بیتی که سرویس‌های پخش اعلام می‌کنند. هیچ ویدیویی دانلود نمی‌شود.';
	@override String get download => 'دریافت';
	@override String get upload => 'ارسال';
	@override String get finding => 'در حال یافتن سرور';
	@override String get throughVpn => 'از طریق VPN';
	@override String get directNoVpn => 'مستقیم، بدون VPN';
	@override String get title => 'آزمایش سرعت';
	@override String get stop => 'توقف';
	@override String get start => 'شروع آزمایش';
	@override String get again => 'آزمایش دوباره';
	@override String get viaVpn => 'با VPN';
	@override String get direct => 'مستقیم';
	@override String get mbps => 'Mbps';
	@override String get ping => 'پینگ';
	@override String get vsDirect => 'نسبت به مستقیم';
	@override String get compare => 'مقایسه با ارائه‌دهنده‌های اطراف';
	@override String get compareSub => 'فقط سرعت‌ها را می‌فرستد، هرگز IP شما را';
	@override String get tierTv => 'تلویزیون‌های بزرگ';
	@override String get tierLaptopLarge => 'لپ‌تاپ‌های بزرگ';
	@override String get tierTablet => 'تبلت و لپ‌تاپ';
	@override String get tierPhone => 'گوشی‌ها';
	@override String get tierSmallPhone => 'گوشی‌های کوچک';
	@override String get tierCalls => 'تماس و صدا';
	@override String get messagingOnly => 'فقط پیام‌رسانی';
	@override String get videoQuality => 'کیفیت ویدیو';
	@override String get preview => 'پیش‌نمایش';
	@override String get history => 'تاریخچه';
	@override String get clear => 'پاک کردن';
	@override String get viaVpnLower => 'با VPN';
	@override String get directLower => 'مستقیم';
	@override String get gradeA => 'چند پخش 4K و تماس تصویری هم‌زمان';
	@override String get gradeB => 'پخش HD و تماس تصویری روان';
	@override String get gradeC => 'یک پخش HD؛ تماس‌ها ممکن است در ساعات شلوغ قطع‌ووصل شوند';
	@override String get gradeD => 'مرور وب و پیام‌رسانی؛ ویدیو مشکل دارد';
	@override String get yourCountry => 'کشور شما';
	@override String get median => 'میانه سرعت دریافت، ۳۰ روز گذشته';
	@override String get fromUsers => 'Mbps · از آزمایش‌های کاربران G VPN';
	@override String get costLittle => 'VPN سرعت کمی کم می‌کند';
	@override String get costNoticeable => 'به‌طور محسوسی کندتر از مستقیم';
	@override String get costMuch => 'بسیار کندتر. سرور دیگری را امتحان کنید';
	@override String get ofDirect => 'از سرعت مستقیم شما';
	@override String get none => 'هیچ';
	@override String ms({required Object n}) => '${n} میلی‌ثانیه';
	@override String previewTier({required Object tier}) => 'پیش‌نمایش · ${tier}';
	@override String streamsUpTo({required Object tier, required Object who}) => 'پخش تا ${tier} · ${who}';
	@override String today({required Object time}) => 'امروز، ${time}';
	@override String tests({required Object n}) => '${n} آزمایش';
	@override String gradeVpn({required Object label}) => '${label} از طریق VPN';
	@override String gradeIsp({required Object label, required Object isp}) => '${label} روی ${isp}';
	@override String notEnough({required Object isp}) => 'هنوز آزمایش کافی برای ${isp} نیست';
	@override String get yourProvider => 'ارائه‌دهنده شما';
	@override String rankLine({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} در ${where}: رتبه ${rank} از ${of}';
	@override String costLine({required Object note, required Object mbps}) => '${note} · مستقیم ${mbps} Mbps';
	@override String mbpsValue({required Object v}) => '${v} Mbps';
	@override String get gradeExcellent => 'عالی';
	@override String get gradeVeryGood => 'خیلی خوب';
	@override String get gradeGood => 'خوب';
	@override String get gradeFair => 'متوسط';
	@override String get gradeSlow => 'کند';
	@override String get gradeVerySlow => 'خیلی کند';
}

// Path: router
class _Translations$router$fa extends Translations$router$en {
	_Translations$router$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get info => 'از روتر شما از طریق UPnP می‌پرسد که آیا دستگاه‌ها می‌توانند خودشان پورت‌ها را به اینترنت باز کنند، و پورت‌های باز شده را فهرست می‌کند. فقط می‌خواند و چیزی را تغییر نمی‌دهد. اگر چیزی به UPnP نیاز ندارد (برخی کنسول‌های بازی نیاز دارند)، خاموش کردن آن در تنظیمات روتر امن‌تر است.';
	@override String get title => 'بررسی روتر';
	@override String get asking => 'در حال پرسیدن از روتر';
	@override String get again => 'بررسی دوباره';
	@override String get check => 'بررسی روتر';
	@override String get off => 'UPnP خاموش است';
	@override String get offBody => 'دستگاه‌ها نمی‌توانند خودشان پورت باز کنند.';
	@override String get onBody => 'اکنون پورتی از طریق آن باز نیست.';
	@override String get checkEach => 'مطمئن شوید همه را می‌شناسید.';
	@override String get cgnat => 'آدرس مشترک ارائه‌دهنده: از اینترنت قابل دسترسی نیست.';
	@override String get noDescription => 'بدون توضیح';
	@override String opened({required Object n}) => '${n} پورت توسط دستگاه‌ها باز شده';
	@override String routerName({required Object name}) => 'روتر: ${name}';
	@override String externalIp({required Object ip}) => 'آدرس اینترنت: ${ip}';
	@override String mapping({required Object proto, required Object host}) => '${proto} به ${host}';
	@override String get upnpOn => 'UPnP روشن است';
}

// Path: network
class _Translations$network$fa extends Translations$network$en {
	_Translations$network$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'این شبکه';
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'داده تلفن همراه';
	@override String get ethernet => 'اترنت';
	@override String get offline => 'آفلاین';
	@override String get risky => 'شبکه پرخطر. اینجا VPN را وصل کنید.';
	@override String get review => 'پیش از اعتماد، نگاهی بیندازید.';
	@override String get covered => 'تحت پوشش VPN.';
	@override String get safe => 'این شبکه امن به نظر می‌رسد.';
	@override String get mobileSentence => 'داده تلفن همراه.';
	@override String get notConnected => 'متصل نیست.';
	@override String get showName => 'نمایش نام';
	@override String get sitesSee => 'سایت‌ها می‌بینند';
	@override String get provider => 'ارائه‌دهنده';
	@override String get location => 'موقعیت';
	@override String get couldNotCheck => 'بررسی ممکن نشد';
	@override String get checking => 'در حال بررسی';
	@override String get signal => 'سیگنال';
	@override String get linkSpeed => 'سرعت لینک';
	@override String get gateway => 'دروازه';
	@override String get none => 'هیچ';
	@override String get privateDns => 'DNS خصوصی';
	@override String get automatic => 'خودکار';
	@override String get off => 'خاموش';
	@override String get metered => 'حجمی';
	@override String get yes => 'بله';
	@override String get no => 'خیر';
	@override String readFailed({required Object error}) => 'خواندن شبکه ممکن نشد: ${error}';
}

// Path: devices
class _Translations$devices$fa extends Translations$devices$en {
	_Translations$devices$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get info => 'به هر آدرس در محدوده Wi-Fi شما سر می‌زند و از دستگاه‌ها می‌خواهد خود را معرفی کنند. دستگاهی که پاسخ رد بدهد هم شمرده می‌شود: رد کردن ثابت می‌کند که آنجاست.\n\nنام‌ها: از آنچه دستگاه‌ها منتشر می‌کنند (Bonjour، UPnP، نام‌های ویندوز) و از روتر شما.\n\nدستگاه‌های ناشناس: اندروید آدرس‌های سخت‌افزاری را از برنامه‌ها پنهان می‌کند، پس دستگاه ساکتی که نامی اعلام نکند قابل شناسایی نیست. فهرست دستگاه‌های روتر خود را برای آن‌ها بررسی کنید.\n\nجدید: دستگاهی که در آخرین اسکن این شبکه دیده نشده بود.';
	@override String get needWifi => 'ابتدا به یک شبکه Wi-Fi وصل شوید.';
	@override String get title => 'دستگاه‌ها';
	@override String get again => 'اسکن دوباره';
	@override String get looking => 'در حال جست‌وجوی دستگاه‌ها';
	@override String get nothingNew => 'از آخرین اسکن چیز جدیدی نیست';
	@override String get takes => 'حدود ۳۰ ثانیه طول می‌کشد';
	@override String get all => 'همه';
	@override String get phones => 'گوشی‌ها';
	@override String get tvs => 'تلویزیون‌ها';
	@override String get computers => 'کامپیوترها';
	@override String get other => 'سایر';
	@override String get thisPhone => 'این گوشی';
	@override String get router => 'روتر';
	@override String get unknown => 'دستگاه ناشناس';
	@override String get address => 'آدرس';
	@override String get answersIn => 'پاسخ در';
	@override String get type => 'نوع';
	@override String get notAnnounced => 'اعلام نشده. فهرست دستگاه‌های روتر شما می‌تواند نام آن را نشان دهد.';
	@override String get newBadge => 'جدید';
	@override String scanning({required Object n}) => 'اسکن ${n} از ۲۵۴';
	@override String get thisNetwork => 'این شبکه';
	@override String newSince({required Object n}) => '${n} دستگاه جدید از آخرین اسکن';
	@override String showMore({required Object n}) => 'نمایش ${n} مورد دیگر';
	@override String ms({required Object n}) => '${n} میلی‌ثانیه';
	@override String onNetwork({required Object network}) => 'دستگاه در ${network}';
}

// Path: ping
class _Translations$ping$fa extends Translations$ping$en {
	_Translations$ping$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get info => 'مدت زمان یک رفت‌وبرگشت تا سرور، هر ثانیه در یک دقیقه گذشته اندازه‌گیری می‌شود.\n\nلرزش (Jitter): میزان تفاوت هر پاسخ با پاسخ قبلی. لرزش زیاد باعث قطع‌ووصلی تماس‌ها می‌شود.\n\nاتلاف: پاسخ‌هایی که هرگز برنگشتند.\n\nروش: برنامه‌های اندروید نمی‌توانند پینگ کلاسیک بفرستند، پس هر آزمایش زمان یک دست‌دادن اتصال را می‌سنجد که همان یک رفت‌وبرگشت است.';
	@override String get askTitle => 'پینگ یک میزبان';
	@override String get askHint => 'example.com یا 192.168.1.10';
	@override String get cancel => 'لغو';
	@override String get title => 'پینگ';
	@override String get router => 'روتر';
	@override String get pause => 'توقف';
	@override String get start => 'شروع';
	@override String get host => 'میزبان';
	@override String get live => 'زنده';
	@override String get ago => '۶۰ ثانیه پیش';
	@override String get min => 'کمینه';
	@override String get avg => 'میانگین';
	@override String get jitter => 'لرزش';
	@override String get loss => 'اتلاف';
	@override String get goodFor => 'مناسب برای';
	@override String get calls => 'تماس تصویری';
	@override String get games => 'بازی آنلاین';
	@override String get streaming => 'پخش ویدیو';
	@override String get great => 'عالی';
	@override String get okay => 'قابل قبول';
	@override String get poor => 'ضعیف';
	@override String get lost => 'گم شد';
	@override String get now => 'اکنون';
}

// Path: status
class _Translations$status$fa extends Translations$status$en {
	_Translations$status$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get info => 'به هر سرویس سه بار وصل می‌شود و سریع‌ترین پاسخ را نشان می‌دهد.\n\nمسدود در اینجا: سرویسی که مستقیم پاسخ نمی‌دهد اما از طریق VPN کار می‌کند، توسط شبکه یا کشور شما مسدود شده است.\n\nتاریخچه: بررسی‌های ۲۴ ساعت گذشته از این گوشی، فقط روی همین گوشی نگه داشته می‌شود.';
	@override String get title => 'وضعیت سرویس‌ها';
	@override String get checking => 'در حال بررسی';
	@override String get again => 'بررسی دوباره';
	@override String get viaVpn => 'بررسی‌شده از طریق VPN';
	@override String get direct => 'بررسی مستقیم';
	@override String get favourites => 'علاقه‌مندی‌ها';
	@override String get edit => 'ویرایش';
	@override String get last24 => '۲۴ ساعت گذشته';
	@override String get ago => '۲۴ ساعت پیش';
	@override String get all => 'همه سرویس‌ها';
	@override String get pickFour => 'حداکثر چهار مورد انتخاب کنید';
	@override String get outage => 'حتی از طریق VPN: احتمالاً قطعی است';
	@override String get blocked => 'ممکن است در این شبکه مسدود باشد';
	@override String get connect => 'اتصال';
	@override String get blockedShort => 'مسدود';
	@override String get unreachable => 'غیرقابل دسترس';
	@override String get now => 'اکنون';
	@override String checks({required Object n}) => '${n} بررسی';
	@override String andMore({required Object first, required Object n}) => '${first} و ${n} مورد دیگر';
	@override String notReachable({required Object who}) => '${who} در دسترس نیست';
}

// Path: tools
class _Translations$tools$fa extends Translations$tools$en {
	_Translations$tools$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'داده تلفن همراه';
	@override String get ethernet => 'اترنت';
	@override String get checking => 'در حال بررسی';
	@override String get offline => 'آفلاین';
	@override String get title => 'ابزارها';
	@override String get networkDesc => 'بررسی ایمنی، آنچه سایت‌ها می‌بینند، سیگنال، روتر و DNS.';
	@override String get internet => 'اتصال اینترنت';
	@override String get speed => 'آزمایش سرعت';
	@override String get speedDesc => 'سرعت دریافت و ارسال، و کیفیت ویدیویی که پشتیبانی می‌کند.';
	@override String get ping => 'پینگ';
	@override String get pingDesc => 'زمان پاسخ زنده و لرزش تا هر سرور یا روتر شما.';
	@override String get status => 'وضعیت سرویس‌ها';
	@override String get statusDesc => 'آیا WhatsApp، YouTube یا Google از اینجا در دسترس است یا مسدود؟';
	@override String get trace => 'ردیابی مسیر';
	@override String get traceDesc => 'همه روترهای بین شما و یک سایت، و زمان هر کدام.';
	@override String get security => 'امنیت شبکه';
	@override String get devices => 'دستگاه‌های این شبکه';
	@override String get devicesDesc => 'چه کسانی در Wi-Fi شما هستند: گوشی، تلویزیون، دوربین و کامپیوتر.';
	@override String get router => 'بررسی روتر';
	@override String get routerDesc => 'آیا دستگاه‌ها می‌توانند خودشان روی روتر شما پورت باز کنند (UPnP).';
	@override String get ports => 'پورت‌های باز';
	@override String get portsDesc => 'روتر یا یک سرور را از نظر پورت‌های باز پرخطر بررسی کنید.';
	@override String get utilities => 'ابزارهای کمکی';
	@override String get wifiScanner => 'اسکنر Wi-Fi';
	@override String get wifiDesc => 'شبکه‌های اطراف، امنیت آن‌ها و خلوت‌ترین کانال.';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'یک کامپیوتر یا NAS را در این شبکه روشن کنید.';
}

// Path: trace
class _Translations$trace$fa extends Translations$trace$en {
	_Translations$trace$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get info => 'هر توقف، یک روتر است که ترافیک شما در راه رسیدن به سایت از آن عبور می‌کند.\n\nگام‌های ساکت: بسیاری از روترها هرگز به این آزمایش‌ها پاسخ نمی‌دهند. این عادی است و خطا نیست.\n\nبا VPN روشن: مسیر از داخل تونل شروع می‌شود، پس شبکه و ارائه‌دهنده خودتان پنهان می‌مانند.\n\nروش: از ابزار پینگ خود اندروید با محدودیت گام استفاده می‌کند، چون برنامه‌ها نمی‌توانند مستقیماً این بسته‌ها را بفرستند.';
	@override String get title => 'ردیابی مسیر';
	@override String get stop => 'توقف';
	@override String get trace => 'ردیابی';
	@override String get again => 'ردیابی دوباره';
	@override String get destination => 'مقصد';
	@override String get hops => 'گام‌ها';
	@override String get answered => 'پاسخ‌داده';
	@override String get total => 'کل';
	@override String get thisPhone => 'این گوشی';
	@override String get silentOne => '۱ گام ساکت';
	@override String get yourRouter => 'روتر شما';
	@override String ms({required Object n}) => '${n} میلی‌ثانیه';
	@override String silentMany({required Object n}) => '${n} گام ساکت';
	@override String hop({required Object n}) => 'گام ${n}';
	@override String slowest({required Object ms, required Object hop}) => 'بیشتر تأخیر، ${ms} میلی‌ثانیه، در گام ${hop} اضافه می‌شود: معمولاً یک کابل طولانی بین کشورها یا یک لینک شلوغ.';
}

// Path: ports
class _Translations$ports$fa extends Translations$ports$en {
	_Translations$ports$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get ftpNote => 'رمزها را بدون رمزگذاری می‌فرستد.';
	@override String get sshNote => 'ورود از راه دور. اگر خودتان راه انداخته‌اید مشکلی نیست.';
	@override String get telnetNote => 'ورود از راه دور بدون رمزگذاری؛ مورد علاقه بات‌نت‌ها.';
	@override String get dnsNote => 'روی روتر عادی است.';
	@override String get web => 'وب (HTTP)';
	@override String get webNote => 'معمولاً صفحه مدیریت روتر.';
	@override String get webTls => 'وب (HTTPS)';
	@override String get smb => 'اشتراک فایل ویندوز';
	@override String get smbNote => 'هرگز نباید رو به اینترنت باشد.';
	@override String get rtsp => 'جریان دوربین RTSP';
	@override String get rtspNote => 'ممکن است دوربینی اینجا در حال پخش باشد.';
	@override String get upnpNote => 'به دستگاه‌ها اجازه می‌دهد خودشان پورت روتر باز کنند.';
	@override String get rdp => 'دسکتاپ از راه دور';
	@override String get rdpNote => 'یک راه رایج نفوذ.';
	@override String get vncNote => 'اشتراک صفحه، اغلب بدون رمز.';
	@override String get tr069Note => 'مدیریت از راه دور توسط ارائه‌دهنده اینترنت.';
	@override String get webAlt => 'وب (جایگزین)';
	@override String get webAltTls => 'وب (HTTPS جایگزین)';
	@override String get title => 'پورت‌های باز';
	@override String get check => 'بررسی پورت‌ها';
	@override String get address => 'آدرس دستگاه یا سرور';
	@override String get risky => 'پرخطر';
	@override String get review => 'بررسی شود';
	@override String get normal => 'عادی';
	@override String info({required Object n}) => '${n} پورت مهم روی روترها و دستگاه‌های خانگی را بررسی می‌کند و هر پورت باز را توضیح می‌دهد.\n\nفقط دستگاه‌ها و سرورهایی را بررسی کنید که مالک یا مدیر آن‌ها هستید.';
	@override String checking({required Object n}) => 'در حال بررسی ${n} پورت';
	@override String yourRouter({required Object ip}) => 'روتر شما ${ip} است';
	@override String noneOpen({required Object host}) => 'هیچ پورت رایجی روی ${host} باز نیست.';
}

// Path: wifi
class _Translations$wifi$fa extends Translations$wifi$en {
	_Translations$wifi$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'اسکنر Wi-Fi';
	@override String get allow => 'اجازه اسکن Wi-Fi';
	@override String get needsPermission => 'به اجازه موقعیت نیاز دارد.';
	@override String get scanning => 'در حال اسکن';
	@override String get again => 'اسکن دوباره';
	@override String get failed => 'اسکن ناموفق بود';
	@override String get none => 'شبکه‌ای پیدا نشد. ممکن است موقعیت مکانی خاموش باشد.';
	@override String get hidden => 'شبکه پنهان';
	@override String nearby({required Object n}) => '${n} شبکه در اطراف';
	@override String bestChannel({required Object n}) => 'خلوت‌ترین کانال 2.4 GHz: ${n}';
	@override String weak({required Object n}) => '${n} شبکه باز یا ضعیف';
	@override String get connectedPrefix => 'متصل · ';
	@override String get permissionInfo => 'اندروید شبکه‌های Wi-Fi اطراف را فقط به برنامه‌های دارای اجازه موقعیت نشان می‌دهد. G VPN از آن فقط برای فهرست کردن شبکه‌ها روی همین گوشی استفاده می‌کند.';
	@override String get info => 'شبکه‌ها را از آخرین اسکن گوشی فهرست می‌کند. اندروید فقط چند اسکن در دقیقه اجازه می‌دهد، پس اسکن دوباره سریع ممکن است همان فهرست را نشان دهد. کانال پیشنهادی خلوت‌ترین از میان ۱، ۶ و ۱۱ است، سه کانالی که هم‌پوشانی ندارند.';
}

// Path: errors
class _Translations$errors$fa extends Translations$errors$en {
	_Translations$errors$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get notAuthorized => 'اجازه VPN داده نشد.';
	@override String get turnedOff => 'VPN توسط سیستم یا برنامه دیگری خاموش شد.';
	@override String get busy => 'یک درخواست اجازه از قبل باز است.';
	@override String get cancelled => 'اتصال لغو شد.';
	@override String badConfig({required Object error}) => 'پیکربندی این سرور نامعتبر است: ${error}';
	@override String get timeout => 'سرور پاسخ نداد.';
	@override String get refused => 'سرور اتصال را رد کرد.';
	@override String failed({required Object error}) => 'اتصال ممکن نشد: ${error}';
	@override String get tryAnother => 'سرورهای رایگان می‌آیند و می‌روند؛ سرور دیگری را امتحان کنید.';
	@override String get downloadFailed => 'دریافت تنظیمات این سرور ممکن نشد. اتصال خود را بررسی کنید یا سرور دیگری انتخاب کنید.';
}

// Path: scan
class _Translations$scan$fa extends Translations$scan$en {
	_Translations$scan$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get mobile => 'داده تلفن همراه';
	@override String get ping => 'پینگ';
	@override String get noReply => 'بدون پاسخ';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9، تونل';
	@override String get dnsTunnel => 'داخل تونل';
	@override String get privateDns => 'DNS خصوصی';
	@override String get dnsIsp => 'ارائه‌دهنده، قابل مشاهده';
	@override String get network => 'شبکه';
	@override String get offline => 'آفلاین';
	@override String get open => 'باز، بدون رمز';
	@override String get wep => 'WEP، ناامن';
	@override String get owe => 'باز، رمزگذاری‌شده';
	@override String get enterprise => 'سازمانی';
	@override String get unknown => 'نامشخص';
	@override String get wifi => 'WI-FI';
	@override String get signIn => 'صفحه ورود';
	@override String ms({required Object n}) => '${n} میلی‌ثانیه';
	@override String covered({required Object what}) => '${what}، محافظت‌شده';
}

// Path: legal
class _Translations$legal$fa extends Translations$legal$en {
	_Translations$legal$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get privacy => 'سیاست حریم خصوصی';
	@override String get terms => 'شرایط استفاده';
	@override String get licences => 'مجوزهای متن‌باز';
}

// Path: update
class _Translations$update$fa extends Translations$update$en {
	_Translations$update$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get ready => 'به‌روزرسانی آماده است';
	@override String get restart => 'راه‌اندازی دوباره';
}

// Path: details
class _Translations$details$fa extends Translations$details$en {
	_Translations$details$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get share => 'اشتراک';
	@override String connectedFor({required Object n}) => 'متصل · ${n} دقیقه';
	@override String get notConnected => 'متصل نیست';
	@override String get downloaded => 'دریافت‌شده';
	@override String get uploaded => 'ارسال‌شده';
	@override String get lastUsed => 'آخرین استفاده';
	@override String get connection => 'اتصال';
	@override String get protocol => 'پروتکل';
	@override String get address => 'آدرس شما';
	@override String get dns => 'DNS';
	@override String get routes => 'مسیرها';
	@override String get allTraffic => 'همه ترافیک';
	@override String someRoutes({required Object n}) => '${n} شبکه';
	@override String get keepalive => 'Keepalive';
	@override String get serverKey => 'کلید سرور';
	@override String get copy => 'کپی';
	@override String get copied => 'کپی شد';
	@override String get manage => 'مدیریت';
	@override String get export => 'خروجی برای پشتیبان';
	@override String get exportSub => 'همه سرورهای شما در یک فایل';
}

// Path: share
class _Translations$share$fa extends Translations$share$en {
	_Translations$share$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String title({required Object name}) => 'اشتراک ${name}';
	@override String get sameKey => 'این کار کلید همین گوشی را به اشتراک می‌گذارد. هر کس آن را داشته باشد می‌تواند به‌جای شما از سرورتان استفاده کند و هم‌زمان فقط یک دستگاه می‌تواند با آن متصل باشد.';
	@override String get scanHint => 'در گوشی دیگر: G VPN، سرورها، اسکن QR. تصویر ذخیره‌شده هم کار می‌کند.';
	@override String get saveImage => 'ذخیره تصویر';
	@override String get send => 'ارسال';
}

// Path: add
class _Translations$add$fa extends Translations$add$en {
	_Translations$add$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'افزودن سرور';
	@override String get subtitle => 'هر سرور WireGuard: روتر، VPS یا سرور خانگی.';
	@override String get camera => 'اسکن با دوربین';
	@override String get cameraSub => 'QR روی صفحه‌ای دیگر';
	@override String get image => 'از یک تصویر';
	@override String get imageSub => 'اسکرین‌شات یا عکس ذخیره‌شده';
	@override String get noQr => 'در آن تصویر کد QR پیدا نشد.';
	@override String get tip => 'QR را در واتس‌اپ یا تلگرام گرفته‌اید؟ روی تصویر «اشتراک» را بزنید و G VPN را انتخاب کنید.';
}

// Path: backup
class _Translations$backup$fa extends Translations$backup$en {
	_Translations$backup$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String restored({required Object n}) => '${n} سرور بازیابی شد';
	@override String get nothingNew => 'این سرورها از قبل اینجا هستند';
}

// Path: gs
class _Translations$gs$fa extends Translations$gs$en {
	_Translations$gs$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'G Servers برای مشترکان G VPN Pro است.';
	@override String get off => 'G Servers فعلاً خاموش است.';
	@override String get network => 'دسترسی به G Servers ممکن نشد. اتصال خود را بررسی کنید و دوباره امتحان کنید.';
	@override String get active => 'فعال';
	@override String get servers => 'G Servers';
	@override String busy({required Object n}) => '${n}٪ مشغول';
	@override String get offline => 'آفلاین';
	@override String get devices => 'دستگاه‌های شما';
	@override String devicesSub({required Object n}) => 'تا ${n} گوشی، هر کدام با کلید خودش';
	@override String get footnote => 'هر گوشی کلید خودش را دارد که روی همان گوشی ساخته می‌شود. G Servers هیچ گزارش فعالیتی نگه نمی‌دارند.';
	@override String get leastBusy => 'کم‌مشغله‌ترین در حال حاضر';
	@override String busyNoLogs({required Object n}) => '${n}٪ مشغول · بدون گزارش';
	@override String subtitle({required Object country}) => 'G Server · ${country} · WireGuard';
	@override String get busyLabel => 'مشغولی';
	@override String get status => 'وضعیت';
	@override String get online => 'آنلاین';
	@override String get onThisServer => 'روی این سرور';
	@override String get thisPhone => 'این گوشی';
	@override String get added => 'اضافه شده · کلید اینجا ساخته شد';
	@override String get notAdded => 'هنگام اتصال اضافه می‌شود';
	@override String get logs => 'گزارش فعالیت';
	@override String get noneKept => 'نگه داشته نمی‌شود';
	@override String get privacy => 'سرور این گوشی را فقط با کلید عمومی‌اش می‌شناسد و هیچ سابقه‌ای از سایت‌هایی که می‌بینید یا ترافیکی که می‌فرستید نگه نمی‌دارد.';
	@override String get stepPro1 => 'G VPN را روی گوشی نصب کنید، با همان حساب Google.';
	@override String get stepPro2 => 'زبانه Pro را باز کنید. Pro خودکار فعال می‌شود، یا «بازیابی» را بزنید.';
	@override String get step3 => 'اتصال را بزنید. گوشی کلیدش را می‌سازد و به G Servers اضافه می‌شود. بدون QR و بدون کد.';
	@override String get stepFree1 => 'G VPN را روی گوشی نصب کنید.';
	@override String get stepFree2 => 'زبانه Pro را باز کنید.';
	@override String get devicesIntroPro => 'Pro همراه حساب Google شماست. هر گوشی کلید خودش را دارد، پس هیچ‌کدام دیگری را قطع نمی‌کند.';
	@override String get devicesIntroFree => 'هر گوشی کلید خودش را دارد، پس گوشی‌ها یکدیگر را قطع نمی‌کنند.';
	@override String get otherPhone => 'گوشی دیگر';
	@override String lastConnected({required Object when}) => 'آخرین اتصال ${when}';
	@override String get noDevices => 'یک بار به یک G Server وصل شوید تا گوشی‌هایتان اینجا دیده شوند.';
	@override String get addTitle => 'افزودن گوشی یا نصب دوباره';
	@override String idle({required Object n}) => 'گوشی‌ای که ${n} روز وصل نشده خودکار از G Servers حذف می‌شود، پس گوشی قدیمی یا نصب دوباره هرگز جایی را اشغال نمی‌کند.';
	@override String limitNote({required Object n}) => 'تا ${n} گوشی برای هر طرح.';
	@override String fullTitle({required Object n}) => 'هر ${n} جا پر است';
	@override String get fullBody => 'گوشی‌ای را که دیگر استفاده نمی‌کنید حذف کنید تا این گوشی فوراً وصل شود.';
	@override String get busyNow => 'در حال حاضر گوشی‌های جدید زیادی اضافه می‌شوند. کمی بعد دوباره امتحان کنید.';
	@override String get serverFull => 'این سرور پر است. G Server دیگری را امتحان کنید.';
	@override String get ping => 'پینگ';
	@override String get last24 => 'مشغولی، ۲۴ ساعت گذشته';
	@override String get noHistory => 'نمودار با استفاده از سرور در طول روز پر می‌شود.';
	@override String chartLabel({required Object max}) => 'مشغولی در ۲۴ ساعت گذشته، حداکثر ${max} درصد';
	@override String get hoursAgo => '۲۴ ساعت پیش';
	@override String get now => 'اکنون';
}

// Path: home.status
class _Translations$home$status$fa extends Translations$home$status$en {
	_Translations$home$status$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get paused => 'متوقف موقت';
	@override String get reconnecting => 'در حال اتصال دوباره';
	@override String get protected => 'محافظت‌شده';
	@override String get connecting => 'در حال اتصال';
	@override String get stopping => 'در حال قطع';
	@override String get notProtected => 'محافظت‌نشده';
}

// Path: home.waves
class _Translations$home$waves$fa extends Translations$home$waves$en {
	_Translations$home$waves$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get encrypted => 'رمزگذاری‌شده';
	@override String get securing => 'در حال ایمن‌سازی';
	@override String get exposed => 'بی‌محافظ';
}

// Path: home.network
class _Translations$home$network$fa extends Translations$home$network$en {
	_Translations$home$network$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'این شبکه';
	@override String get wifi => 'Wi-Fi';
	@override String get offline => 'آفلاین';
	@override String get showName => 'نمایش نام';
	@override String get scanFailed => 'بررسی ناموفق بود. با تغییر شبکه دوباره انجام می‌شود.';
}

// Path: home.card
class _Translations$home$card$fa extends Translations$home$card$en {
	_Translations$home$card$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get connectedVia => 'متصل از طریق';
	@override String get protocol => 'پروتکل';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9، داخل تونل';
	@override String get dnsServer => 'سرور، داخل تونل';
	@override String get downloaded => 'دریافت‌شده';
	@override String get uploaded => 'ارسال‌شده';
	@override String get wireguard => 'WireGuard';
	@override String openvpn({required Object proto}) => 'OpenVPN ${proto}';
	@override String get selected => 'انتخاب‌شده';
	@override String get browsingFrom => 'در حال گشت‌وگذار از';
	@override String get disconnect => 'قطع اتصال';
	@override String get change => 'تغییر';
	@override String get enabled => 'روشن';
	@override String get shield => 'سپر';
}

// Path: home.tiles
class _Translations$home$tiles$fa extends Translations$home$tiles$en {
	_Translations$home$tiles$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get shield => 'سپر';
	@override String get shieldOn => 'سایت‌های مخرب را مسدود می‌کند';
	@override String get appsDirect => 'برنامه‌های مستقیم';
	@override String get appsAll => 'همه برنامه‌ها محافظت‌شده';
	@override String appsSkip({required Object n}) => '${n} برنامه بدون VPN';
	@override String get autoConnect => 'اتصال خودکار';
	@override String get autoOpen => 'در Wi-Fi عمومی';
	@override String get autoAny => 'در هر Wi-Fi';
	@override String get speed => 'سرعت';
	@override String get speedTap => 'برای آزمایش ضربه بزنید';
	@override String speedDirect({required Object mbps}) => 'مستقیم ${mbps} Mbps';
}

// Path: home.fastest
class _Translations$home$fastest$fa extends Translations$home$fastest$en {
	_Translations$home$fastest$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'سریع‌ترین سرور رایگان';
	@override String get pickedFrom => 'انتخاب‌شده از';
	@override String more({required Object n}) => '+${n}';
	@override String get finding => 'در حال یافتن سریع‌ترین سرور';
	@override String get failed => 'سرورهای رایگان بارگیری نشدند';
	@override String get how => 'سرور چگونه انتخاب می‌شود';
	@override String get sheetBody => 'G VPN شما را به سرور رایگانی وصل می‌کند که در این لحظه از نظر سرعت، بار و مدت روشن ماندن بهترین رتبه را دارد. با آمدن و رفتن سرورها، رتبه‌بندی تغییر می‌کند.';
}

// Path: home.ip
class _Translations$home$ip$fa extends Translations$home$ip$en {
	_Translations$home$ip$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'آنچه سایت‌ها می‌بینند';
	@override String get real => 'موقعیت واقعی شما';
	@override String get vpn => 'موقعیت VPN';
	@override String get address => 'نشانی IP';
	@override String get coordinates => 'مختصات';
	@override String get note => 'برآورد از روی IP شما. هرگز ذخیره نمی‌شود.';
	@override String get hide => 'پنهان کردن موقعیت من';
	@override String near({required Object place}) => 'حدود ${place}';
}

// Path: servers.tabs
class _Translations$servers$tabs$fa extends Translations$servers$tabs$en {
	_Translations$servers$tabs$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get pro => 'Pro';
	@override String get free => 'رایگان';
	@override String get yours => 'مال شما';
}

// Path: servers.sheet
class _Translations$servers$sheet$fa extends Translations$servers$sheet$en {
	_Translations$servers$sheet$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'سرورها از کجا می‌آیند';
	@override String get subtitle => 'سه نوع، یک فهرست';
	@override String get free => 'سرورهای داوطلبانه که هر دو ساعت بررسی می‌شوند. گردانندگان آن‌ها حدود دو هفته گزارش اتصال نگه می‌دارند.';
	@override String get pro => 'توسط ما با WireGuard اداره می‌شود. بدون گزارش فعالیت، بدون حساب کاربری.';
	@override String get yours => 'هر سرور WireGuard که خودتان دارید: روتر، VPS یا سرور خانگی.';
}

// Path: servers.badges
class _Translations$servers$badges$fa extends Translations$servers$badges$en {
	_Translations$servers$badges$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get mostUsed => 'پرکاربردترین';
	@override String get mostStable => 'پایدارترین';
	@override String get fastest => 'سریع‌ترین';
}

// Path: servers.filters
class _Translations$servers$filters$fa extends Translations$servers$filters$en {
	_Translations$servers$filters$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get all => 'همه';
	@override String get fastest => 'سریع‌ترین';
	@override String get stable => 'پایدارترین';
	@override String get popular => 'محبوب';
}

// Path: servers.own
class _Translations$servers$own$fa extends Translations$servers$own$en {
	_Translations$servers$own$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'سرور خودتان را راه بیندازید';
	@override String get subtitle => 'هر سرور WireGuard کار می‌کند';
	@override String get router => 'یک روتر';
	@override String get routerBody => 'بسیاری از روترها WireGuard داخلی دارند. پیکربندی کلاینت را خروجی بگیرید و کد QR آن را اینجا اسکن کنید.';
	@override String get vps => 'یک VPS';
	@override String get vpsBody => 'هر سرور کوچک لینوکسی. WireGuard را نصب کنید، یک کلاینت بسازید و فایل پیکربندی آن را وارد کنید.';
	@override String get home => 'یک سرور خانگی';
	@override String get homeBody => 'از هر جا به همین روش به شبکه خودتان دسترسی داشته باشید.';
	@override String get noneYet => 'هنوز سروری ندارید؟';
	@override String get addAnother => 'افزودن یکی دیگر';
	@override String get hint => 'روی روتر، VPS یا سرور خانگی راه بیندازید';
}

// Path: pro.free
class _Translations$pro$free$fa extends Translations$pro$free$en {
	_Translations$pro$free$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get title => 'طرح شما';
	@override String get headline => 'همه چیز رایگان است';
	@override String get body => 'همه سرورها و همه ابزارها، بدون حساب کاربری و بدون تبلیغ.';
	@override String get included => 'شامل';
	@override String get servers => 'سرورهای رایگان';
	@override String get serversSub => 'رتبه‌بندی بر اساس سرعت و پایداری در ده‌ها کشور';
	@override String get own => 'سرورهای خودتان';
	@override String get ownSub => 'اتصال به هر روتر، VPS یا سرور خانگی WireGuard';
	@override String get shield => 'سپر';
	@override String get shieldSub => 'سایت‌های شناخته‌شده بدافزار و فیشینگ را مسدود می‌کند';
	@override String get auto => 'اتصال خودکار و قوانین برنامه‌ها';
	@override String get autoSub => 'Wi-Fi عمومی را محافظت کنید؛ برنامه‌های بانکی مستقیم بروند';
	@override String get pause => 'توقف موقت و تنظیمات سریع';
	@override String get pauseSub => 'توقف از اعلان، روشن و خاموش از کاشی';
	@override String get tools => 'همه ابزارهای شبکه';
	@override String get toolsSub => 'آزمایش سرعت، پینگ، وضعیت سرویس‌ها، ردیابی مسیر، دستگاه‌ها و بیشتر';
	@override String get later => 'G VPN Pro سرورهای سریع‌تری اضافه می‌کند که توسط ما اداره می‌شوند. همه موارد بالا رایگان می‌مانند.';
}

// Path: rules.info
class _Translations$rules$info$fa extends Translations$rules$info$en {
	_Translations$rules$info$fa._(TranslationsFa root) : this._root = root, super.internal(root);

	final TranslationsFa _root; // ignore: unused_field

	// Translations
	@override String get shield => 'سپر درخواست‌های DNS را به Quad9 می‌فرستد که سایت‌های شناخته‌شده بدافزار و فیشینگ را رد می‌کند. تبلیغات را مسدود نمی‌کند و تا روشن است جایگزین DNS سرور می‌شود.';
	@override String get autoConnect => 'اتصال خودکار: از سرور WireGuard انتخاب‌شده شما استفاده می‌کند. قطع دستی آن را تا پیوستن به شبکه‌ای دیگر متوقف می‌کند.';
	@override String get apps => 'برنامه‌های مستقیم: برنامه‌هایی که از VPN عبور نمی‌کنند مستقیم وصل می‌شوند. بانک‌ها اغلب آدرس‌های VPN را مسدود می‌کنند، پس پرداخت از طریق VPN ممکن است ناموفق باشد.';
	@override String get reconnect => 'تغییر سپر یا برنامه‌ها، VPN را برای لحظه‌ای دوباره وصل می‌کند.';
	@override String get stay => 'متصل ماندن: برخی گوشی‌ها برای صرفه‌جویی در باتری، برنامه‌ها را در پس‌زمینه متوقف می‌کنند. VPN همیشه روشن و تنظیم باتری بدون محدودیت، G VPN را فعال نگه می‌دارند.';
}

/// The flat map containing all translations for locale <fa>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsFa {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.gotIt' => 'متوجه شدم',
			'common.about' => 'درباره',
			'common.connect' => 'اتصال',
			'common.connected' => 'متصل',
			'common.retry' => 'تلاش دوباره',
			'common.ok' => 'باشه',
			'common.remove' => 'حذف',
			'common.cancel' => 'لغو',
			'common.continueLabel' => 'ادامه',
			'common.notNow' => 'الان نه',
			'common.openSettings' => 'باز کردن تنظیمات',
			'common.close' => 'بستن',
			'common.off' => 'خاموش',
			'common.changesReconnect' => 'تغییرات، VPN را دوباره وصل می‌کند',
			'nav.vpn' => 'VPN',
			'nav.servers' => 'سرورها',
			'nav.tools' => 'ابزارها',
			'nav.rules' => 'قوانین',
			'nav.pro' => 'Pro',
			'home.status.paused' => 'متوقف موقت',
			'home.status.reconnecting' => 'در حال اتصال دوباره',
			'home.status.protected' => 'محافظت‌شده',
			'home.status.connecting' => 'در حال اتصال',
			'home.status.stopping' => 'در حال قطع',
			'home.status.notProtected' => 'محافظت‌نشده',
			'home.resumesAt' => ({required Object time}) => 'ادامه در ${time} · برای ادامه ضربه بزنید',
			'home.sitesSee' => ({required Object ip}) => 'سایت‌ها می‌بینند: ${ip}',
			'home.sitesSeeOrg' => ({required Object ip, required Object org}) => 'سایت‌ها می‌بینند: ${ip} · ${org}',
			'home.ipFailed' => 'بررسی IP ممکن نشد',
			'home.ipChecking' => 'در حال بررسی IP',
			'home.themeSystem' => 'پوسته: مطابق گوشی',
			'home.themeLight' => 'پوسته: روشن',
			'home.themeDark' => 'پوسته: تیره',
			'home.free' => 'رایگان',
			'home.pickServer' => 'یک سرور انتخاب کنید',
			'home.waves.encrypted' => 'رمزگذاری‌شده',
			'home.waves.securing' => 'در حال ایمن‌سازی',
			'home.waves.exposed' => 'بی‌محافظ',
			'home.network.title' => 'این شبکه',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'آفلاین',
			'home.network.showName' => 'نمایش نام',
			'home.network.scanFailed' => 'بررسی ناموفق بود. با تغییر شبکه دوباره انجام می‌شود.',
			'home.card.connectedVia' => 'متصل از طریق',
			'home.card.protocol' => 'پروتکل',
			'home.card.dns' => 'DNS',
			'home.card.dnsQuad9' => 'Quad9، داخل تونل',
			'home.card.dnsServer' => 'سرور، داخل تونل',
			'home.card.downloaded' => 'دریافت‌شده',
			'home.card.uploaded' => 'ارسال‌شده',
			'home.card.wireguard' => 'WireGuard',
			'home.card.openvpn' => ({required Object proto}) => 'OpenVPN ${proto}',
			'home.card.selected' => 'انتخاب‌شده',
			'home.card.browsingFrom' => 'در حال گشت‌وگذار از',
			'home.card.disconnect' => 'قطع اتصال',
			'home.card.change' => 'تغییر',
			'home.card.enabled' => 'روشن',
			'home.card.shield' => 'سپر',
			'home.tiles.shield' => 'سپر',
			'home.tiles.shieldOn' => 'سایت‌های مخرب را مسدود می‌کند',
			'home.tiles.appsDirect' => 'برنامه‌های مستقیم',
			'home.tiles.appsAll' => 'همه برنامه‌ها محافظت‌شده',
			'home.tiles.appsSkip' => ({required Object n}) => '${n} برنامه بدون VPN',
			'home.tiles.autoConnect' => 'اتصال خودکار',
			'home.tiles.autoOpen' => 'در Wi-Fi عمومی',
			'home.tiles.autoAny' => 'در هر Wi-Fi',
			'home.tiles.speed' => 'سرعت',
			'home.tiles.speedTap' => 'برای آزمایش ضربه بزنید',
			'home.tiles.speedDirect' => ({required Object mbps}) => 'مستقیم ${mbps} Mbps',
			'home.fastest.title' => 'سریع‌ترین سرور رایگان',
			'home.fastest.pickedFrom' => 'انتخاب‌شده از',
			'home.fastest.more' => ({required Object n}) => '+${n}',
			'home.fastest.finding' => 'در حال یافتن سریع‌ترین سرور',
			'home.fastest.failed' => 'سرورهای رایگان بارگیری نشدند',
			'home.fastest.how' => 'سرور چگونه انتخاب می‌شود',
			'home.fastest.sheetBody' => 'G VPN شما را به سرور رایگانی وصل می‌کند که در این لحظه از نظر سرعت، بار و مدت روشن ماندن بهترین رتبه را دارد. با آمدن و رفتن سرورها، رتبه‌بندی تغییر می‌کند.',
			'home.ip.title' => 'آنچه سایت‌ها می‌بینند',
			'home.ip.real' => 'موقعیت واقعی شما',
			'home.ip.vpn' => 'موقعیت VPN',
			'home.ip.address' => 'نشانی IP',
			'home.ip.coordinates' => 'مختصات',
			'home.ip.note' => 'برآورد از روی IP شما. هرگز ذخیره نمی‌شود.',
			'home.ip.hide' => 'پنهان کردن موقعیت من',
			'home.ip.near' => ({required Object place}) => 'حدود ${place}',
			'servers.title' => 'سرورها',
			'servers.aboutServers' => 'درباره سرورها',
			'servers.tabs.pro' => 'Pro',
			'servers.tabs.free' => 'رایگان',
			'servers.tabs.yours' => 'مال شما',
			'servers.sheet.title' => 'سرورها از کجا می‌آیند',
			'servers.sheet.subtitle' => 'سه نوع، یک فهرست',
			'servers.sheet.free' => 'سرورهای داوطلبانه که هر دو ساعت بررسی می‌شوند. گردانندگان آن‌ها حدود دو هفته گزارش اتصال نگه می‌دارند.',
			'servers.sheet.pro' => 'توسط ما با WireGuard اداره می‌شود. بدون گزارش فعالیت، بدون حساب کاربری.',
			'servers.sheet.yours' => 'هر سرور WireGuard که خودتان دارید: روتر، VPS یا سرور خانگی.',
			'servers.badges.mostUsed' => 'پرکاربردترین',
			'servers.badges.mostStable' => 'پایدارترین',
			'servers.badges.fastest' => 'سریع‌ترین',
			'servers.filters.all' => 'همه',
			'servers.filters.fastest' => 'سریع‌ترین',
			'servers.filters.stable' => 'پایدارترین',
			'servers.filters.popular' => 'محبوب',
			'servers.loadFailed' => 'بارگیری فهرست ممکن نشد',
			'servers.noServers' => 'فعلاً سروری نیست',
			'servers.best' => 'بهترین برای شما',
			'servers.topRanked' => 'بالاترین رتبه در حال حاضر',
			'servers.addHeading' => 'افزودن سرور',
			'servers.scanQr' => 'اسکن QR',
			'servers.importFile' => 'وارد کردن فایل',
			'servers.paste' => 'چسباندن',
			'servers.own.title' => 'سرور خودتان را راه بیندازید',
			'servers.own.subtitle' => 'هر سرور WireGuard کار می‌کند',
			'servers.own.router' => 'یک روتر',
			'servers.own.routerBody' => 'بسیاری از روترها WireGuard داخلی دارند. پیکربندی کلاینت را خروجی بگیرید و کد QR آن را اینجا اسکن کنید.',
			'servers.own.vps' => 'یک VPS',
			'servers.own.vpsBody' => 'هر سرور کوچک لینوکسی. WireGuard را نصب کنید، یک کلاینت بسازید و فایل پیکربندی آن را وارد کنید.',
			'servers.own.home' => 'یک سرور خانگی',
			'servers.own.homeBody' => 'از هر جا به همین روش به شبکه خودتان دسترسی داشته باشید.',
			'servers.own.noneYet' => 'هنوز سروری ندارید؟',
			'servers.own.addAnother' => 'افزودن یکی دیگر',
			'servers.own.hint' => 'روی روتر، VPS یا سرور خانگی راه بیندازید',
			'servers.configBroken' => 'پیکربندی نیاز به بررسی دارد',
			'servers.connectedBadge' => 'متصل',
			'servers.scannedServer' => 'سرور اسکن‌شده',
			'servers.scanFailedTitle' => 'اسکن ممکن نشد',
			'servers.scanFailedBody' => 'اسکنر روی این گوشی در دسترس نیست.',
			'servers.importFailedTitle' => 'وارد کردن ممکن نشد',
			'servers.importFailedBody' => 'آن فایل خوانده نشد.',
			'servers.renameTitle' => 'تغییر نام سرور',
			'servers.nameHint' => 'نام، مثلاً روتر خانه',
			'servers.save' => 'ذخیره',
			'servers.rename' => 'تغییر نام',
			'servers.disconnect' => 'قطع اتصال',
			'servers.more' => 'گزینه‌های بیشتر',
			'servers.justNow' => 'همین الان',
			'servers.minutesAgo' => ({required Object n}) => '${n} دقیقه پیش',
			'servers.hoursAgo' => ({required Object n}) => '${n} ساعت پیش',
			'servers.daysAgo' => ({required Object n}) => '${n} روز پیش',
			'servers.neverUsed' => 'هنوز استفاده نشده',
			'servers.lastUsed' => ({required Object when}) => 'آخرین استفاده: ${when}',
			'servers.disconnectFirst' => 'برای حذف، ابتدا اتصال را قطع کنید',
			'servers.removeConfirm' => 'این سرور از G VPN حذف شود؟ تنظیمات آن از این گوشی پاک می‌شود؛ خود سرور تغییری نمی‌کند.',
			'pro.owned' => 'شما Pro دارید',
			'pro.waitingPlay' => 'در انتظار Google Play',
			'pro.startTrial' => ({required Object days}) => 'شروع دوره رایگان ${days} روزه',
			'pro.thenYearly' => ({required Object price}) => 'سپس سالی ${price}. هر زمان در Google Play لغو کنید.',
			'pro.thenMonthly' => ({required Object price}) => 'سپس ماهی ${price}. هر زمان در Google Play لغو کنید.',
			'pro.yearlyPrice' => ({required Object price}) => 'سالی ${price}. هر زمان در Google Play لغو کنید.',
			'pro.monthlyPrice' => ({required Object price}) => 'ماهی ${price}. هر زمان در Google Play لغو کنید.',
			'pro.restore' => 'بازیابی',
			'pro.heroTitle' => 'سرورهای سریع‌تر،\nاداره‌شده توسط ما',
			'pro.heroSubtitle' => 'WireGuard. بدون گزارش فعالیت. بدون حساب کاربری.',
			'pro.benefitSpeed' => 'سرعت کامل، بدون محدودیت سرورهای داوطلبانه',
			'pro.benefitKey' => 'کلید روی گوشی شما ساخته می‌شود و هرگز به اشتراک گذاشته نمی‌شود',
			'pro.benefitFree' => 'هر چیز رایگان، رایگان می‌ماند',
			'pro.save' => ({required Object pct}) => '${pct}٪ صرفه‌جویی',
			'pro.yearly' => 'سالانه',
			'pro.monthly' => 'ماهانه',
			'pro.billedMonthly' => 'پرداخت ماهانه',
			'pro.daysFree' => ({required Object days}) => '${days} روز رایگان',
			'pro.perMonth' => ({required Object price}) => 'ماهی ${price}',
			'pro.title' => 'G VPN Pro',
			'pro.heroTitleOneLine' => 'سرورهای سریع‌تر، اداره‌شده توسط ما',
			'pro.includes' => 'شامل',
			'pro.benefitLogs' => 'بدون گزارش فعالیت روی سرورهای ما',
			'pro.plan' => 'یک طرح انتخاب کنید',
			'pro.renewGeneric' => 'اشتراک‌ها تا زمان لغو خودکار تمدید می‌شوند. هر زمان در Google Play لغو کنید.',
			'pro.renewTrial' => ({required Object days, required Object price, required Object period}) => '${days} روز رایگان، سپس ${price} در هر ${period}. تا زمان لغو خودکار تمدید می‌شود؛ برای جلوگیری از پرداخت، دست‌کم یک روز پیش از پایان دوره رایگان در Google Play لغو کنید.',
			'pro.renew' => ({required Object price, required Object period}) => '${price} در هر ${period}. تا زمان لغو خودکار تمدید می‌شود؛ هر زمان در Google Play لغو کنید.',
			'pro.year' => 'سال',
			'pro.month' => 'ماه',
			'pro.manage' => 'مدیریت اشتراک',
			'pro.free.title' => 'طرح شما',
			'pro.free.headline' => 'همه چیز رایگان است',
			'pro.free.body' => 'همه سرورها و همه ابزارها، بدون حساب کاربری و بدون تبلیغ.',
			'pro.free.included' => 'شامل',
			'pro.free.servers' => 'سرورهای رایگان',
			'pro.free.serversSub' => 'رتبه‌بندی بر اساس سرعت و پایداری در ده‌ها کشور',
			'pro.free.own' => 'سرورهای خودتان',
			'pro.free.ownSub' => 'اتصال به هر روتر، VPS یا سرور خانگی WireGuard',
			'pro.free.shield' => 'سپر',
			'pro.free.shieldSub' => 'سایت‌های شناخته‌شده بدافزار و فیشینگ را مسدود می‌کند',
			'pro.free.auto' => 'اتصال خودکار و قوانین برنامه‌ها',
			'pro.free.autoSub' => 'Wi-Fi عمومی را محافظت کنید؛ برنامه‌های بانکی مستقیم بروند',
			'pro.free.pause' => 'توقف موقت و تنظیمات سریع',
			'pro.free.pauseSub' => 'توقف از اعلان، روشن و خاموش از کاشی',
			'pro.free.tools' => 'همه ابزارهای شبکه',
			'pro.free.toolsSub' => 'آزمایش سرعت، پینگ، وضعیت سرویس‌ها، ردیابی مسیر، دستگاه‌ها و بیشتر',
			'pro.free.later' => 'G VPN Pro سرورهای سریع‌تری اضافه می‌کند که توسط ما اداره می‌شوند. همه موارد بالا رایگان می‌مانند.',
			'rules.title' => 'قوانین',
			'rules.info.shield' => 'سپر درخواست‌های DNS را به Quad9 می‌فرستد که سایت‌های شناخته‌شده بدافزار و فیشینگ را رد می‌کند. تبلیغات را مسدود نمی‌کند و تا روشن است جایگزین DNS سرور می‌شود.',
			'rules.info.autoConnect' => 'اتصال خودکار: از سرور WireGuard انتخاب‌شده شما استفاده می‌کند. قطع دستی آن را تا پیوستن به شبکه‌ای دیگر متوقف می‌کند.',
			'rules.info.apps' => 'برنامه‌های مستقیم: برنامه‌هایی که از VPN عبور نمی‌کنند مستقیم وصل می‌شوند. بانک‌ها اغلب آدرس‌های VPN را مسدود می‌کنند، پس پرداخت از طریق VPN ممکن است ناموفق باشد.',
			'rules.info.reconnect' => 'تغییر سپر یا برنامه‌ها، VPN را برای لحظه‌ای دوباره وصل می‌کند.',
			'rules.info.stay' => 'متصل ماندن: برخی گوشی‌ها برای صرفه‌جویی در باتری، برنامه‌ها را در پس‌زمینه متوقف می‌کنند. VPN همیشه روشن و تنظیم باتری بدون محدودیت، G VPN را فعال نگه می‌دارند.',
			'rules.protection' => 'محافظت',
			'rules.shield' => 'سپر',
			'rules.shieldSub' => 'سایت‌های بدافزار و فیشینگ را مسدود می‌کند',
			'rules.privateDns' => 'سپر بدون VPN',
			'rules.privateDnsSub' => 'کپی dns.quad9.net برای DNS خصوصی',
			'rules.privateDnsCopied' => 'dns.quad9.net کپی شد',
			'rules.privateDnsHow' => 'تنظیمات را باز کنید، «DNS خصوصی» را جست‌وجو کنید، «نام میزبان ارائه‌دهنده DNS خصوصی» را انتخاب کنید و آن را بچسبانید.',
			'rules.stay' => 'متصل ماندن',
			'rules.alwaysOn' => 'VPN همیشه روشن',
			'rules.alwaysOnSub' => 'اگر G VPN متوقف شود، اندروید آن را دوباره اجرا می‌کند',
			'rules.battery' => 'باتری',
			'rules.batteryOk' => 'بدون محدودیت',
			'rules.batteryRestricted' => 'محدود: ممکن است در پس‌زمینه متوقف شود',
			'rules.autoConnect' => 'اتصال خودکار',
			'rules.autoOff' => 'خاموش',
			'rules.autoOffSub' => 'فقط وقتی ضربه بزنید',
			'rules.autoOpen' => 'Wi-Fi عمومی',
			'rules.autoOpenSub' => 'شبکه‌های باز، WEP یا دارای صفحه ورود',
			'rules.autoAny' => 'هر Wi-Fi',
			'rules.autoAnySub' => 'هر شبکه Wi-Fi',
			'rules.apps' => 'برنامه‌ها',
			'rules.appsDirect' => 'برنامه‌های مستقیم',
			'rules.appsNone' => 'همه برنامه‌ها از VPN استفاده می‌کنند',
			'rules.appsSome' => ({required Object n}) => '${n} برنامه بدون VPN',
			'rules.appearance' => 'ظاهر',
			'rules.themePhone' => 'گوشی',
			'rules.themeLight' => 'روشن',
			'rules.themeDark' => 'تیره',
			'rules.about' => 'درباره',
			'apps.title' => 'برنامه‌های مستقیم',
			'apps.sheetSubtitle' => 'برنامه‌های انتخاب‌شده بدون VPN وصل می‌شوند. بقیه محافظت‌شده می‌مانند.',
			'apps.whyTitle' => 'چرا یک برنامه را مستثنا کنیم',
			'apps.whyBody' => 'بانک‌ها و برنامه‌های پرداخت اغلب آدرس‌های VPN را مسدود می‌کنند، پس پرداخت از طریق VPN ممکن است ناموفق باشد. برخی خدمات محلی فقط از کشور خودتان کار می‌کنند.',
			'apps.favouritesBody' => 'برنامه‌هایی را که زیاد تغییر می‌دهید ستاره‌دار کنید؛ بالای فهرست می‌مانند.',
			'apps.whileConnected' => 'هنگام اتصال',
			'apps.whileConnectedBody' => 'تغییر این فهرست، VPN را برای لحظه‌ای دوباره وصل می‌کند.',
			'apps.search' => ({required Object n}) => 'جست‌وجو در ${n} برنامه',
			'apps.skipping' => 'بدون VPN',
			'apps.skippingNone' => 'هیچ. همه برنامه‌ها از VPN عبور می‌کنند.',
			'apps.protectAgain' => ({required Object app}) => 'محافظت دوباره از ${app}',
			'apps.banking' => 'بانک و پرداخت',
			'apps.bankingFound' => ({required Object n}) => '${n} برنامه پیدا شد که ممکن است VPN را مسدود کنند',
			'apps.addAll' => 'افزودن همه',
			'apps.favourites' => 'علاقه‌مندی‌ها',
			'apps.all' => 'همه برنامه‌ها',
			'apps.found' => ({required Object n}) => '${n} مورد پیدا شد',
			'apps.noMatch' => 'برنامه‌ای پیدا نشد.',
			'apps.showAll' => ({required Object n}) => 'نمایش همه ${n}',
			'apps.skips' => 'بدون VPN',
			'apps.unstar' => 'حذف از علاقه‌مندی‌ها',
			'apps.star' => 'افزودن به علاقه‌مندی‌ها',
			'location.title' => 'اجازه موقعیت برای Wi-Fi',
			'location.useHome' => 'نمایش نام Wi-Fi در صفحه اصلی',
			'location.useScan' => 'اسکن شبکه‌ها و کانال‌های اطراف',
			'location.private' => 'روی همین گوشی می‌ماند. موقعیت شما هرگز جمع‌آوری نمی‌شود.',
			'location.switchTitle' => 'روشن کردن موقعیت مکانی',
			'location.switchBody' => 'وقتی موقعیت مکانی خاموش است، اندروید نام Wi-Fi را پنهان می‌کند',
			'addServer.clipboardEmpty' => 'کلیپ‌بورد خالی است.',
			'addServer.title' => 'سرور خود را اضافه کنید',
			'addServer.body' => 'یک پیکربندی WireGuard از روتر، VPS یا سرور خانگی خود بچسبانید.',
			'addServer.nameHint' => 'نام، مثلاً روتر خانه',
			'addServer.paste' => 'چسباندن',
			'addServer.save' => 'ذخیره سرور',
			'addServer.notWireguard' => ({required Object error}) => 'این یک پیکربندی WireGuard نیست: ${error}',
			'button.stop' => 'توقف',
			'button.connecting' => 'در حال اتصال',
			'button.stopping' => 'در حال قطع',
			'button.connect' => 'اتصال',
			'button.disconnect' => 'قطع اتصال',
			'wol.info' => 'اگر Wake on LAN در تنظیمات یک کامپیوتر یا NAS در این Wi-Fi فعال باشد، آن را روشن می‌کند. گوشی شما باید در همان شبکه باشد؛ ابتدا VPN را خاموش کنید.',
			'wol.badMac' => 'این آدرس MAC نیست. شکل آن مانند AA:BB:CC:DD:EE:FF است.',
			'wol.sent' => 'سیگنال روشن شدن ارسال شد. دستگاه باید ظرف یک دقیقه روشن شود.',
			'wol.title' => 'Wake on LAN',
			'wol.wake' => 'روشن کردن دستگاه',
			'wol.mac' => 'آدرس MAC',
			'wol.failed' => ({required Object error}) => 'ارسال ممکن نشد: ${error}',
			'speed.info' => 'اندازه‌گیری توسط M-Lab، یک پلتفرم پژوهشی باز. هر آزمایش حدود ۵۰ تا ۱۰۰ مگابایت مصرف می‌کند.\n\nنتایج عمومی: M-Lab هر آزمایش، از جمله آدرس IP مبدأ آن، را به‌عنوان داده پژوهشی باز منتشر می‌کند.\n\nمقایسه ارائه‌دهنده: پس از آزمایش بدون VPN، G VPN فقط سه عدد سرعت را می‌فرستد. سرویس مقایسه، ارائه‌دهنده و شهر شما را از خود اتصال می‌خواند و هیچ آدرس IP ذخیره نمی‌کند. با کلید پایین این صفحه آن را خاموش کنید.\n\nاز طریق VPN: با VPN روشن، سرعت داخل تونل را اندازه می‌گیرد و با آخرین آزمایش بدون VPN مقایسه می‌کند.\n\nپیش‌نمایش ویدیو: همان تصویر با وضوحی که این سرعت می‌تواند پخش کند، بر اساس نرخ بیتی که سرویس‌های پخش اعلام می‌کنند. هیچ ویدیویی دانلود نمی‌شود.',
			'speed.download' => 'دریافت',
			'speed.upload' => 'ارسال',
			'speed.finding' => 'در حال یافتن سرور',
			'speed.throughVpn' => 'از طریق VPN',
			'speed.directNoVpn' => 'مستقیم، بدون VPN',
			'speed.title' => 'آزمایش سرعت',
			'speed.stop' => 'توقف',
			'speed.start' => 'شروع آزمایش',
			'speed.again' => 'آزمایش دوباره',
			'speed.viaVpn' => 'با VPN',
			'speed.direct' => 'مستقیم',
			'speed.mbps' => 'Mbps',
			'speed.ping' => 'پینگ',
			'speed.vsDirect' => 'نسبت به مستقیم',
			'speed.compare' => 'مقایسه با ارائه‌دهنده‌های اطراف',
			'speed.compareSub' => 'فقط سرعت‌ها را می‌فرستد، هرگز IP شما را',
			'speed.tierTv' => 'تلویزیون‌های بزرگ',
			'speed.tierLaptopLarge' => 'لپ‌تاپ‌های بزرگ',
			'speed.tierTablet' => 'تبلت و لپ‌تاپ',
			'speed.tierPhone' => 'گوشی‌ها',
			'speed.tierSmallPhone' => 'گوشی‌های کوچک',
			'speed.tierCalls' => 'تماس و صدا',
			'speed.messagingOnly' => 'فقط پیام‌رسانی',
			'speed.videoQuality' => 'کیفیت ویدیو',
			'speed.preview' => 'پیش‌نمایش',
			'speed.history' => 'تاریخچه',
			'speed.clear' => 'پاک کردن',
			'speed.viaVpnLower' => 'با VPN',
			'speed.directLower' => 'مستقیم',
			'speed.gradeA' => 'چند پخش 4K و تماس تصویری هم‌زمان',
			'speed.gradeB' => 'پخش HD و تماس تصویری روان',
			'speed.gradeC' => 'یک پخش HD؛ تماس‌ها ممکن است در ساعات شلوغ قطع‌ووصل شوند',
			'speed.gradeD' => 'مرور وب و پیام‌رسانی؛ ویدیو مشکل دارد',
			'speed.yourCountry' => 'کشور شما',
			'speed.median' => 'میانه سرعت دریافت، ۳۰ روز گذشته',
			'speed.fromUsers' => 'Mbps · از آزمایش‌های کاربران G VPN',
			'speed.costLittle' => 'VPN سرعت کمی کم می‌کند',
			'speed.costNoticeable' => 'به‌طور محسوسی کندتر از مستقیم',
			'speed.costMuch' => 'بسیار کندتر. سرور دیگری را امتحان کنید',
			'speed.ofDirect' => 'از سرعت مستقیم شما',
			'speed.none' => 'هیچ',
			'speed.ms' => ({required Object n}) => '${n} میلی‌ثانیه',
			'speed.previewTier' => ({required Object tier}) => 'پیش‌نمایش · ${tier}',
			'speed.streamsUpTo' => ({required Object tier, required Object who}) => 'پخش تا ${tier} · ${who}',
			'speed.today' => ({required Object time}) => 'امروز، ${time}',
			'speed.tests' => ({required Object n}) => '${n} آزمایش',
			'speed.gradeVpn' => ({required Object label}) => '${label} از طریق VPN',
			'speed.gradeIsp' => ({required Object label, required Object isp}) => '${label} روی ${isp}',
			'speed.notEnough' => ({required Object isp}) => 'هنوز آزمایش کافی برای ${isp} نیست',
			'speed.yourProvider' => 'ارائه‌دهنده شما',
			'speed.rankLine' => ({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} در ${where}: رتبه ${rank} از ${of}',
			'speed.costLine' => ({required Object note, required Object mbps}) => '${note} · مستقیم ${mbps} Mbps',
			'speed.mbpsValue' => ({required Object v}) => '${v} Mbps',
			'speed.gradeExcellent' => 'عالی',
			'speed.gradeVeryGood' => 'خیلی خوب',
			'speed.gradeGood' => 'خوب',
			'speed.gradeFair' => 'متوسط',
			'speed.gradeSlow' => 'کند',
			'speed.gradeVerySlow' => 'خیلی کند',
			'router.info' => 'از روتر شما از طریق UPnP می‌پرسد که آیا دستگاه‌ها می‌توانند خودشان پورت‌ها را به اینترنت باز کنند، و پورت‌های باز شده را فهرست می‌کند. فقط می‌خواند و چیزی را تغییر نمی‌دهد. اگر چیزی به UPnP نیاز ندارد (برخی کنسول‌های بازی نیاز دارند)، خاموش کردن آن در تنظیمات روتر امن‌تر است.',
			'router.title' => 'بررسی روتر',
			'router.asking' => 'در حال پرسیدن از روتر',
			'router.again' => 'بررسی دوباره',
			'router.check' => 'بررسی روتر',
			'router.off' => 'UPnP خاموش است',
			'router.offBody' => 'دستگاه‌ها نمی‌توانند خودشان پورت باز کنند.',
			'router.onBody' => 'اکنون پورتی از طریق آن باز نیست.',
			'router.checkEach' => 'مطمئن شوید همه را می‌شناسید.',
			'router.cgnat' => 'آدرس مشترک ارائه‌دهنده: از اینترنت قابل دسترسی نیست.',
			'router.noDescription' => 'بدون توضیح',
			'router.opened' => ({required Object n}) => '${n} پورت توسط دستگاه‌ها باز شده',
			'router.routerName' => ({required Object name}) => 'روتر: ${name}',
			'router.externalIp' => ({required Object ip}) => 'آدرس اینترنت: ${ip}',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} به ${host}',
			'router.upnpOn' => 'UPnP روشن است',
			'network.title' => 'این شبکه',
			'network.wifi' => 'Wi-Fi',
			'network.mobile' => 'داده تلفن همراه',
			'network.ethernet' => 'اترنت',
			'network.offline' => 'آفلاین',
			'network.risky' => 'شبکه پرخطر. اینجا VPN را وصل کنید.',
			'network.review' => 'پیش از اعتماد، نگاهی بیندازید.',
			'network.covered' => 'تحت پوشش VPN.',
			'network.safe' => 'این شبکه امن به نظر می‌رسد.',
			'network.mobileSentence' => 'داده تلفن همراه.',
			'network.notConnected' => 'متصل نیست.',
			'network.showName' => 'نمایش نام',
			'network.sitesSee' => 'سایت‌ها می‌بینند',
			'network.provider' => 'ارائه‌دهنده',
			'network.location' => 'موقعیت',
			'network.couldNotCheck' => 'بررسی ممکن نشد',
			'network.checking' => 'در حال بررسی',
			'network.signal' => 'سیگنال',
			'network.linkSpeed' => 'سرعت لینک',
			'network.gateway' => 'دروازه',
			'network.none' => 'هیچ',
			'network.privateDns' => 'DNS خصوصی',
			'network.automatic' => 'خودکار',
			'network.off' => 'خاموش',
			'network.metered' => 'حجمی',
			'network.yes' => 'بله',
			'network.no' => 'خیر',
			'network.readFailed' => ({required Object error}) => 'خواندن شبکه ممکن نشد: ${error}',
			'devices.info' => 'به هر آدرس در محدوده Wi-Fi شما سر می‌زند و از دستگاه‌ها می‌خواهد خود را معرفی کنند. دستگاهی که پاسخ رد بدهد هم شمرده می‌شود: رد کردن ثابت می‌کند که آنجاست.\n\nنام‌ها: از آنچه دستگاه‌ها منتشر می‌کنند (Bonjour، UPnP، نام‌های ویندوز) و از روتر شما.\n\nدستگاه‌های ناشناس: اندروید آدرس‌های سخت‌افزاری را از برنامه‌ها پنهان می‌کند، پس دستگاه ساکتی که نامی اعلام نکند قابل شناسایی نیست. فهرست دستگاه‌های روتر خود را برای آن‌ها بررسی کنید.\n\nجدید: دستگاهی که در آخرین اسکن این شبکه دیده نشده بود.',
			'devices.needWifi' => 'ابتدا به یک شبکه Wi-Fi وصل شوید.',
			'devices.title' => 'دستگاه‌ها',
			'devices.again' => 'اسکن دوباره',
			'devices.looking' => 'در حال جست‌وجوی دستگاه‌ها',
			'devices.nothingNew' => 'از آخرین اسکن چیز جدیدی نیست',
			'devices.takes' => 'حدود ۳۰ ثانیه طول می‌کشد',
			'devices.all' => 'همه',
			'devices.phones' => 'گوشی‌ها',
			'devices.tvs' => 'تلویزیون‌ها',
			'devices.computers' => 'کامپیوترها',
			'devices.other' => 'سایر',
			'devices.thisPhone' => 'این گوشی',
			'devices.router' => 'روتر',
			'devices.unknown' => 'دستگاه ناشناس',
			'devices.address' => 'آدرس',
			'devices.answersIn' => 'پاسخ در',
			'devices.type' => 'نوع',
			'devices.notAnnounced' => 'اعلام نشده. فهرست دستگاه‌های روتر شما می‌تواند نام آن را نشان دهد.',
			'devices.newBadge' => 'جدید',
			'devices.scanning' => ({required Object n}) => 'اسکن ${n} از ۲۵۴',
			'devices.thisNetwork' => 'این شبکه',
			'devices.newSince' => ({required Object n}) => '${n} دستگاه جدید از آخرین اسکن',
			'devices.showMore' => ({required Object n}) => 'نمایش ${n} مورد دیگر',
			'devices.ms' => ({required Object n}) => '${n} میلی‌ثانیه',
			'devices.onNetwork' => ({required Object network}) => 'دستگاه در ${network}',
			'ping.info' => 'مدت زمان یک رفت‌وبرگشت تا سرور، هر ثانیه در یک دقیقه گذشته اندازه‌گیری می‌شود.\n\nلرزش (Jitter): میزان تفاوت هر پاسخ با پاسخ قبلی. لرزش زیاد باعث قطع‌ووصلی تماس‌ها می‌شود.\n\nاتلاف: پاسخ‌هایی که هرگز برنگشتند.\n\nروش: برنامه‌های اندروید نمی‌توانند پینگ کلاسیک بفرستند، پس هر آزمایش زمان یک دست‌دادن اتصال را می‌سنجد که همان یک رفت‌وبرگشت است.',
			'ping.askTitle' => 'پینگ یک میزبان',
			'ping.askHint' => 'example.com یا 192.168.1.10',
			'ping.cancel' => 'لغو',
			'ping.title' => 'پینگ',
			'ping.router' => 'روتر',
			'ping.pause' => 'توقف',
			'ping.start' => 'شروع',
			'ping.host' => 'میزبان',
			'ping.live' => 'زنده',
			'ping.ago' => '۶۰ ثانیه پیش',
			'ping.min' => 'کمینه',
			'ping.avg' => 'میانگین',
			'ping.jitter' => 'لرزش',
			'ping.loss' => 'اتلاف',
			'ping.goodFor' => 'مناسب برای',
			'ping.calls' => 'تماس تصویری',
			'ping.games' => 'بازی آنلاین',
			'ping.streaming' => 'پخش ویدیو',
			'ping.great' => 'عالی',
			'ping.okay' => 'قابل قبول',
			'ping.poor' => 'ضعیف',
			'ping.lost' => 'گم شد',
			'ping.now' => 'اکنون',
			'status.info' => 'به هر سرویس سه بار وصل می‌شود و سریع‌ترین پاسخ را نشان می‌دهد.\n\nمسدود در اینجا: سرویسی که مستقیم پاسخ نمی‌دهد اما از طریق VPN کار می‌کند، توسط شبکه یا کشور شما مسدود شده است.\n\nتاریخچه: بررسی‌های ۲۴ ساعت گذشته از این گوشی، فقط روی همین گوشی نگه داشته می‌شود.',
			'status.title' => 'وضعیت سرویس‌ها',
			'status.checking' => 'در حال بررسی',
			'status.again' => 'بررسی دوباره',
			'status.viaVpn' => 'بررسی‌شده از طریق VPN',
			'status.direct' => 'بررسی مستقیم',
			'status.favourites' => 'علاقه‌مندی‌ها',
			'status.edit' => 'ویرایش',
			'status.last24' => '۲۴ ساعت گذشته',
			'status.ago' => '۲۴ ساعت پیش',
			'status.all' => 'همه سرویس‌ها',
			'status.pickFour' => 'حداکثر چهار مورد انتخاب کنید',
			'status.outage' => 'حتی از طریق VPN: احتمالاً قطعی است',
			'status.blocked' => 'ممکن است در این شبکه مسدود باشد',
			'status.connect' => 'اتصال',
			'status.blockedShort' => 'مسدود',
			'status.unreachable' => 'غیرقابل دسترس',
			'status.now' => 'اکنون',
			'status.checks' => ({required Object n}) => '${n} بررسی',
			'status.andMore' => ({required Object first, required Object n}) => '${first} و ${n} مورد دیگر',
			'status.notReachable' => ({required Object who}) => '${who} در دسترس نیست',
			'tools.wifi' => 'Wi-Fi',
			'tools.mobile' => 'داده تلفن همراه',
			'tools.ethernet' => 'اترنت',
			'tools.checking' => 'در حال بررسی',
			'tools.offline' => 'آفلاین',
			'tools.title' => 'ابزارها',
			'tools.networkDesc' => 'بررسی ایمنی، آنچه سایت‌ها می‌بینند، سیگنال، روتر و DNS.',
			'tools.internet' => 'اتصال اینترنت',
			'tools.speed' => 'آزمایش سرعت',
			'tools.speedDesc' => 'سرعت دریافت و ارسال، و کیفیت ویدیویی که پشتیبانی می‌کند.',
			'tools.ping' => 'پینگ',
			'tools.pingDesc' => 'زمان پاسخ زنده و لرزش تا هر سرور یا روتر شما.',
			'tools.status' => 'وضعیت سرویس‌ها',
			'tools.statusDesc' => 'آیا WhatsApp، YouTube یا Google از اینجا در دسترس است یا مسدود؟',
			'tools.trace' => 'ردیابی مسیر',
			'tools.traceDesc' => 'همه روترهای بین شما و یک سایت، و زمان هر کدام.',
			'tools.security' => 'امنیت شبکه',
			'tools.devices' => 'دستگاه‌های این شبکه',
			'tools.devicesDesc' => 'چه کسانی در Wi-Fi شما هستند: گوشی، تلویزیون، دوربین و کامپیوتر.',
			'tools.router' => 'بررسی روتر',
			'tools.routerDesc' => 'آیا دستگاه‌ها می‌توانند خودشان روی روتر شما پورت باز کنند (UPnP).',
			'tools.ports' => 'پورت‌های باز',
			'tools.portsDesc' => 'روتر یا یک سرور را از نظر پورت‌های باز پرخطر بررسی کنید.',
			'tools.utilities' => 'ابزارهای کمکی',
			'tools.wifiScanner' => 'اسکنر Wi-Fi',
			'tools.wifiDesc' => 'شبکه‌های اطراف، امنیت آن‌ها و خلوت‌ترین کانال.',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'یک کامپیوتر یا NAS را در این شبکه روشن کنید.',
			'trace.info' => 'هر توقف، یک روتر است که ترافیک شما در راه رسیدن به سایت از آن عبور می‌کند.\n\nگام‌های ساکت: بسیاری از روترها هرگز به این آزمایش‌ها پاسخ نمی‌دهند. این عادی است و خطا نیست.\n\nبا VPN روشن: مسیر از داخل تونل شروع می‌شود، پس شبکه و ارائه‌دهنده خودتان پنهان می‌مانند.\n\nروش: از ابزار پینگ خود اندروید با محدودیت گام استفاده می‌کند، چون برنامه‌ها نمی‌توانند مستقیماً این بسته‌ها را بفرستند.',
			'trace.title' => 'ردیابی مسیر',
			'trace.stop' => 'توقف',
			'trace.trace' => 'ردیابی',
			'trace.again' => 'ردیابی دوباره',
			'trace.destination' => 'مقصد',
			'trace.hops' => 'گام‌ها',
			'trace.answered' => 'پاسخ‌داده',
			'trace.total' => 'کل',
			'trace.thisPhone' => 'این گوشی',
			'trace.silentOne' => '۱ گام ساکت',
			'trace.yourRouter' => 'روتر شما',
			'trace.ms' => ({required Object n}) => '${n} میلی‌ثانیه',
			'trace.silentMany' => ({required Object n}) => '${n} گام ساکت',
			'trace.hop' => ({required Object n}) => 'گام ${n}',
			'trace.slowest' => ({required Object ms, required Object hop}) => 'بیشتر تأخیر، ${ms} میلی‌ثانیه، در گام ${hop} اضافه می‌شود: معمولاً یک کابل طولانی بین کشورها یا یک لینک شلوغ.',
			'ports.ftpNote' => 'رمزها را بدون رمزگذاری می‌فرستد.',
			'ports.sshNote' => 'ورود از راه دور. اگر خودتان راه انداخته‌اید مشکلی نیست.',
			'ports.telnetNote' => 'ورود از راه دور بدون رمزگذاری؛ مورد علاقه بات‌نت‌ها.',
			'ports.dnsNote' => 'روی روتر عادی است.',
			'ports.web' => 'وب (HTTP)',
			'ports.webNote' => 'معمولاً صفحه مدیریت روتر.',
			'ports.webTls' => 'وب (HTTPS)',
			'ports.smb' => 'اشتراک فایل ویندوز',
			'ports.smbNote' => 'هرگز نباید رو به اینترنت باشد.',
			'ports.rtsp' => 'جریان دوربین RTSP',
			'ports.rtspNote' => 'ممکن است دوربینی اینجا در حال پخش باشد.',
			'ports.upnpNote' => 'به دستگاه‌ها اجازه می‌دهد خودشان پورت روتر باز کنند.',
			'ports.rdp' => 'دسکتاپ از راه دور',
			'ports.rdpNote' => 'یک راه رایج نفوذ.',
			'ports.vncNote' => 'اشتراک صفحه، اغلب بدون رمز.',
			'ports.tr069Note' => 'مدیریت از راه دور توسط ارائه‌دهنده اینترنت.',
			'ports.webAlt' => 'وب (جایگزین)',
			'ports.webAltTls' => 'وب (HTTPS جایگزین)',
			'ports.title' => 'پورت‌های باز',
			'ports.check' => 'بررسی پورت‌ها',
			'ports.address' => 'آدرس دستگاه یا سرور',
			'ports.risky' => 'پرخطر',
			'ports.review' => 'بررسی شود',
			_ => null,
		} ?? switch (path) {
			'ports.normal' => 'عادی',
			'ports.info' => ({required Object n}) => '${n} پورت مهم روی روترها و دستگاه‌های خانگی را بررسی می‌کند و هر پورت باز را توضیح می‌دهد.\n\nفقط دستگاه‌ها و سرورهایی را بررسی کنید که مالک یا مدیر آن‌ها هستید.',
			'ports.checking' => ({required Object n}) => 'در حال بررسی ${n} پورت',
			'ports.yourRouter' => ({required Object ip}) => 'روتر شما ${ip} است',
			'ports.noneOpen' => ({required Object host}) => 'هیچ پورت رایجی روی ${host} باز نیست.',
			'wifi.title' => 'اسکنر Wi-Fi',
			'wifi.allow' => 'اجازه اسکن Wi-Fi',
			'wifi.needsPermission' => 'به اجازه موقعیت نیاز دارد.',
			'wifi.scanning' => 'در حال اسکن',
			'wifi.again' => 'اسکن دوباره',
			'wifi.failed' => 'اسکن ناموفق بود',
			'wifi.none' => 'شبکه‌ای پیدا نشد. ممکن است موقعیت مکانی خاموش باشد.',
			'wifi.hidden' => 'شبکه پنهان',
			'wifi.nearby' => ({required Object n}) => '${n} شبکه در اطراف',
			'wifi.bestChannel' => ({required Object n}) => 'خلوت‌ترین کانال 2.4 GHz: ${n}',
			'wifi.weak' => ({required Object n}) => '${n} شبکه باز یا ضعیف',
			'wifi.connectedPrefix' => 'متصل · ',
			'wifi.permissionInfo' => 'اندروید شبکه‌های Wi-Fi اطراف را فقط به برنامه‌های دارای اجازه موقعیت نشان می‌دهد. G VPN از آن فقط برای فهرست کردن شبکه‌ها روی همین گوشی استفاده می‌کند.',
			'wifi.info' => 'شبکه‌ها را از آخرین اسکن گوشی فهرست می‌کند. اندروید فقط چند اسکن در دقیقه اجازه می‌دهد، پس اسکن دوباره سریع ممکن است همان فهرست را نشان دهد. کانال پیشنهادی خلوت‌ترین از میان ۱، ۶ و ۱۱ است، سه کانالی که هم‌پوشانی ندارند.',
			'errors.notAuthorized' => 'اجازه VPN داده نشد.',
			'errors.turnedOff' => 'VPN توسط سیستم یا برنامه دیگری خاموش شد.',
			'errors.busy' => 'یک درخواست اجازه از قبل باز است.',
			'errors.cancelled' => 'اتصال لغو شد.',
			'errors.badConfig' => ({required Object error}) => 'پیکربندی این سرور نامعتبر است: ${error}',
			'errors.timeout' => 'سرور پاسخ نداد.',
			'errors.refused' => 'سرور اتصال را رد کرد.',
			'errors.failed' => ({required Object error}) => 'اتصال ممکن نشد: ${error}',
			'errors.tryAnother' => 'سرورهای رایگان می‌آیند و می‌روند؛ سرور دیگری را امتحان کنید.',
			'errors.downloadFailed' => 'دریافت تنظیمات این سرور ممکن نشد. اتصال خود را بررسی کنید یا سرور دیگری انتخاب کنید.',
			'scan.mobile' => 'داده تلفن همراه',
			'scan.ping' => 'پینگ',
			'scan.noReply' => 'بدون پاسخ',
			'scan.dns' => 'DNS',
			'scan.dnsQuad9' => 'Quad9، تونل',
			'scan.dnsTunnel' => 'داخل تونل',
			'scan.privateDns' => 'DNS خصوصی',
			'scan.dnsIsp' => 'ارائه‌دهنده، قابل مشاهده',
			'scan.network' => 'شبکه',
			'scan.offline' => 'آفلاین',
			'scan.open' => 'باز، بدون رمز',
			'scan.wep' => 'WEP، ناامن',
			'scan.owe' => 'باز، رمزگذاری‌شده',
			'scan.enterprise' => 'سازمانی',
			'scan.unknown' => 'نامشخص',
			'scan.wifi' => 'WI-FI',
			'scan.signIn' => 'صفحه ورود',
			'scan.ms' => ({required Object n}) => '${n} میلی‌ثانیه',
			'scan.covered' => ({required Object what}) => '${what}، محافظت‌شده',
			'legal.privacy' => 'سیاست حریم خصوصی',
			'legal.terms' => 'شرایط استفاده',
			'legal.licences' => 'مجوزهای متن‌باز',
			'update.ready' => 'به‌روزرسانی آماده است',
			'update.restart' => 'راه‌اندازی دوباره',
			'details.share' => 'اشتراک',
			'details.connectedFor' => ({required Object n}) => 'متصل · ${n} دقیقه',
			'details.notConnected' => 'متصل نیست',
			'details.downloaded' => 'دریافت‌شده',
			'details.uploaded' => 'ارسال‌شده',
			'details.lastUsed' => 'آخرین استفاده',
			'details.connection' => 'اتصال',
			'details.protocol' => 'پروتکل',
			'details.address' => 'آدرس شما',
			'details.dns' => 'DNS',
			'details.routes' => 'مسیرها',
			'details.allTraffic' => 'همه ترافیک',
			'details.someRoutes' => ({required Object n}) => '${n} شبکه',
			'details.keepalive' => 'Keepalive',
			'details.serverKey' => 'کلید سرور',
			'details.copy' => 'کپی',
			'details.copied' => 'کپی شد',
			'details.manage' => 'مدیریت',
			'details.export' => 'خروجی برای پشتیبان',
			'details.exportSub' => 'همه سرورهای شما در یک فایل',
			'share.title' => ({required Object name}) => 'اشتراک ${name}',
			'share.sameKey' => 'این کار کلید همین گوشی را به اشتراک می‌گذارد. هر کس آن را داشته باشد می‌تواند به‌جای شما از سرورتان استفاده کند و هم‌زمان فقط یک دستگاه می‌تواند با آن متصل باشد.',
			'share.scanHint' => 'در گوشی دیگر: G VPN، سرورها، اسکن QR. تصویر ذخیره‌شده هم کار می‌کند.',
			'share.saveImage' => 'ذخیره تصویر',
			'share.send' => 'ارسال',
			'add.title' => 'افزودن سرور',
			'add.subtitle' => 'هر سرور WireGuard: روتر، VPS یا سرور خانگی.',
			'add.camera' => 'اسکن با دوربین',
			'add.cameraSub' => 'QR روی صفحه‌ای دیگر',
			'add.image' => 'از یک تصویر',
			'add.imageSub' => 'اسکرین‌شات یا عکس ذخیره‌شده',
			'add.noQr' => 'در آن تصویر کد QR پیدا نشد.',
			'add.tip' => 'QR را در واتس‌اپ یا تلگرام گرفته‌اید؟ روی تصویر «اشتراک» را بزنید و G VPN را انتخاب کنید.',
			'backup.restored' => ({required Object n}) => '${n} سرور بازیابی شد',
			'backup.nothingNew' => 'این سرورها از قبل اینجا هستند',
			'gs.proRequired' => 'G Servers برای مشترکان G VPN Pro است.',
			'gs.off' => 'G Servers فعلاً خاموش است.',
			'gs.network' => 'دسترسی به G Servers ممکن نشد. اتصال خود را بررسی کنید و دوباره امتحان کنید.',
			'gs.active' => 'فعال',
			'gs.servers' => 'G Servers',
			'gs.busy' => ({required Object n}) => '${n}٪ مشغول',
			'gs.offline' => 'آفلاین',
			'gs.devices' => 'دستگاه‌های شما',
			'gs.devicesSub' => ({required Object n}) => 'تا ${n} گوشی، هر کدام با کلید خودش',
			'gs.footnote' => 'هر گوشی کلید خودش را دارد که روی همان گوشی ساخته می‌شود. G Servers هیچ گزارش فعالیتی نگه نمی‌دارند.',
			'gs.leastBusy' => 'کم‌مشغله‌ترین در حال حاضر',
			'gs.busyNoLogs' => ({required Object n}) => '${n}٪ مشغول · بدون گزارش',
			'gs.subtitle' => ({required Object country}) => 'G Server · ${country} · WireGuard',
			'gs.busyLabel' => 'مشغولی',
			'gs.status' => 'وضعیت',
			'gs.online' => 'آنلاین',
			'gs.onThisServer' => 'روی این سرور',
			'gs.thisPhone' => 'این گوشی',
			'gs.added' => 'اضافه شده · کلید اینجا ساخته شد',
			'gs.notAdded' => 'هنگام اتصال اضافه می‌شود',
			'gs.logs' => 'گزارش فعالیت',
			'gs.noneKept' => 'نگه داشته نمی‌شود',
			'gs.privacy' => 'سرور این گوشی را فقط با کلید عمومی‌اش می‌شناسد و هیچ سابقه‌ای از سایت‌هایی که می‌بینید یا ترافیکی که می‌فرستید نگه نمی‌دارد.',
			'gs.stepPro1' => 'G VPN را روی گوشی نصب کنید، با همان حساب Google.',
			'gs.stepPro2' => 'زبانه Pro را باز کنید. Pro خودکار فعال می‌شود، یا «بازیابی» را بزنید.',
			'gs.step3' => 'اتصال را بزنید. گوشی کلیدش را می‌سازد و به G Servers اضافه می‌شود. بدون QR و بدون کد.',
			'gs.stepFree1' => 'G VPN را روی گوشی نصب کنید.',
			'gs.stepFree2' => 'زبانه Pro را باز کنید.',
			'gs.devicesIntroPro' => 'Pro همراه حساب Google شماست. هر گوشی کلید خودش را دارد، پس هیچ‌کدام دیگری را قطع نمی‌کند.',
			'gs.devicesIntroFree' => 'هر گوشی کلید خودش را دارد، پس گوشی‌ها یکدیگر را قطع نمی‌کنند.',
			'gs.otherPhone' => 'گوشی دیگر',
			'gs.lastConnected' => ({required Object when}) => 'آخرین اتصال ${when}',
			'gs.noDevices' => 'یک بار به یک G Server وصل شوید تا گوشی‌هایتان اینجا دیده شوند.',
			'gs.addTitle' => 'افزودن گوشی یا نصب دوباره',
			'gs.idle' => ({required Object n}) => 'گوشی‌ای که ${n} روز وصل نشده خودکار از G Servers حذف می‌شود، پس گوشی قدیمی یا نصب دوباره هرگز جایی را اشغال نمی‌کند.',
			'gs.limitNote' => ({required Object n}) => 'تا ${n} گوشی برای هر طرح.',
			'gs.fullTitle' => ({required Object n}) => 'هر ${n} جا پر است',
			'gs.fullBody' => 'گوشی‌ای را که دیگر استفاده نمی‌کنید حذف کنید تا این گوشی فوراً وصل شود.',
			'gs.busyNow' => 'در حال حاضر گوشی‌های جدید زیادی اضافه می‌شوند. کمی بعد دوباره امتحان کنید.',
			'gs.serverFull' => 'این سرور پر است. G Server دیگری را امتحان کنید.',
			'gs.ping' => 'پینگ',
			'gs.last24' => 'مشغولی، ۲۴ ساعت گذشته',
			'gs.noHistory' => 'نمودار با استفاده از سرور در طول روز پر می‌شود.',
			'gs.chartLabel' => ({required Object max}) => 'مشغولی در ۲۴ ساعت گذشته، حداکثر ${max} درصد',
			'gs.hoursAgo' => '۲۴ ساعت پیش',
			'gs.now' => 'اکنون',
			_ => null,
		};
	}
}
