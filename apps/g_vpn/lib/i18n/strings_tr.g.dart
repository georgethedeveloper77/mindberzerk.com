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
class TranslationsTr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsTr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.tr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <tr>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsTr _root = this; // ignore: unused_field

	@override 
	TranslationsTr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsTr(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$tr common = _Translations$common$tr._(_root);
	@override late final _Translations$nav$tr nav = _Translations$nav$tr._(_root);
	@override late final _Translations$home$tr home = _Translations$home$tr._(_root);
	@override late final _Translations$servers$tr servers = _Translations$servers$tr._(_root);
	@override late final _Translations$pro$tr pro = _Translations$pro$tr._(_root);
	@override late final _Translations$rules$tr rules = _Translations$rules$tr._(_root);
	@override late final _Translations$apps$tr apps = _Translations$apps$tr._(_root);
	@override late final _Translations$location$tr location = _Translations$location$tr._(_root);
	@override late final _Translations$addServer$tr addServer = _Translations$addServer$tr._(_root);
	@override late final _Translations$button$tr button = _Translations$button$tr._(_root);
	@override late final _Translations$wol$tr wol = _Translations$wol$tr._(_root);
	@override late final _Translations$speed$tr speed = _Translations$speed$tr._(_root);
	@override late final _Translations$router$tr router = _Translations$router$tr._(_root);
	@override late final _Translations$network$tr network = _Translations$network$tr._(_root);
	@override late final _Translations$devices$tr devices = _Translations$devices$tr._(_root);
	@override late final _Translations$ping$tr ping = _Translations$ping$tr._(_root);
	@override late final _Translations$status$tr status = _Translations$status$tr._(_root);
	@override late final _Translations$tools$tr tools = _Translations$tools$tr._(_root);
	@override late final _Translations$trace$tr trace = _Translations$trace$tr._(_root);
	@override late final _Translations$ports$tr ports = _Translations$ports$tr._(_root);
	@override late final _Translations$wifi$tr wifi = _Translations$wifi$tr._(_root);
	@override late final _Translations$errors$tr errors = _Translations$errors$tr._(_root);
	@override late final _Translations$scan$tr scan = _Translations$scan$tr._(_root);
	@override late final _Translations$legal$tr legal = _Translations$legal$tr._(_root);
	@override late final _Translations$update$tr update = _Translations$update$tr._(_root);
	@override late final _Translations$details$tr details = _Translations$details$tr._(_root);
	@override late final _Translations$share$tr share = _Translations$share$tr._(_root);
	@override late final _Translations$add$tr add = _Translations$add$tr._(_root);
	@override late final _Translations$backup$tr backup = _Translations$backup$tr._(_root);
	@override late final _Translations$gs$tr gs = _Translations$gs$tr._(_root);
	@override late final _Translations$map$tr map = _Translations$map$tr._(_root);
	@override late final _Translations$stats$tr stats = _Translations$stats$tr._(_root);
	@override late final _Translations$recents$tr recents = _Translations$recents$tr._(_root);
	@override late final _Translations$presets$tr presets = _Translations$presets$tr._(_root);
	@override late final _Translations$shield$tr shield = _Translations$shield$tr._(_root);
	@override late final _Translations$checks$tr checks = _Translations$checks$tr._(_root);
	@override late final _Translations$toolSettings$tr toolSettings = _Translations$toolSettings$tr._(_root);
	@override late final _Translations$security$tr security = _Translations$security$tr._(_root);
	@override late final _Translations$providers$tr providers = _Translations$providers$tr._(_root);
	@override late final _Translations$alerts$tr alerts = _Translations$alerts$tr._(_root);
	@override late final _Translations$report$tr report = _Translations$report$tr._(_root);
	@override late final _Translations$breaches$tr breaches = _Translations$breaches$tr._(_root);
	@override late final _Translations$blocked$tr blocked = _Translations$blocked$tr._(_root);
}

// Path: common
class _Translations$common$tr extends Translations$common$en {
	_Translations$common$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get gotIt => 'Anladım';
	@override String get about => 'Hakkında';
	@override String get connect => 'Bağlan';
	@override String get connected => 'Bağlı';
	@override String get retry => 'Tekrar dene';
	@override String get ok => 'Tamam';
	@override String get remove => 'Kaldır';
	@override String get cancel => 'İptal';
	@override String get continueLabel => 'Devam';
	@override String get notNow => 'Şimdi değil';
	@override String get openSettings => 'Ayarları aç';
	@override String get close => 'Kapat';
	@override String get off => 'Kapalı';
	@override String get changesReconnect => 'Değişiklikler VPN\'i yeniden bağlar';
}

// Path: nav
class _Translations$nav$tr extends Translations$nav$en {
	_Translations$nav$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get vpn => 'VPN';
	@override String get servers => 'Sunucular';
	@override String get tools => 'Araçlar';
	@override String get rules => 'Kurallar';
	@override String get pro => 'Pro';
}

// Path: home
class _Translations$home$tr extends Translations$home$en {
	_Translations$home$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$status$tr status = _Translations$home$status$tr._(_root);
	@override String resumesAt({required Object time}) => '${time} itibarıyla devam eder · şimdi devam etmek için dokunun';
	@override String get ipFailed => 'IP adresiniz kontrol edilemedi';
	@override String get ipChecking => 'IP adresiniz kontrol ediliyor';
	@override String get themeSystem => 'Tema: telefonu izle';
	@override String get themeLight => 'Tema: açık';
	@override String get themeDark => 'Tema: koyu';
	@override String get free => 'Ücretsiz';
	@override String get pickServer => 'Bir sunucu seçin';
	@override late final _Translations$home$network$tr network = _Translations$home$network$tr._(_root);
	@override late final _Translations$home$card$tr card = _Translations$home$card$tr._(_root);
	@override late final _Translations$home$tiles$tr tiles = _Translations$home$tiles$tr._(_root);
	@override late final _Translations$home$fastest$tr fastest = _Translations$home$fastest$tr._(_root);
	@override late final _Translations$home$ip$tr ip = _Translations$home$ip$tr._(_root);
}

// Path: servers
class _Translations$servers$tr extends Translations$servers$en {
	_Translations$servers$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sunucular';
	@override String get aboutServers => 'Sunucular hakkında';
	@override late final _Translations$servers$tabs$tr tabs = _Translations$servers$tabs$tr._(_root);
	@override late final _Translations$servers$sheet$tr sheet = _Translations$servers$sheet$tr._(_root);
	@override late final _Translations$servers$badges$tr badges = _Translations$servers$badges$tr._(_root);
	@override late final _Translations$servers$filters$tr filters = _Translations$servers$filters$tr._(_root);
	@override String get loadFailed => 'Liste yüklenemedi';
	@override String get noServers => 'Şu anda sunucu yok';
	@override String get best => 'ŞU AN SİZİN İÇİN EN İYİSİ';
	@override String get topRanked => 'Şu an en üst sırada';
	@override String get addHeading => 'SUNUCU EKLE';
	@override String get scanQr => 'QR tara';
	@override String get importFile => 'Dosya içe aktar';
	@override String get paste => 'Yapıştır';
	@override late final _Translations$servers$own$tr own = _Translations$servers$own$tr._(_root);
	@override String get configBroken => 'Yapılandırma kontrol edilmeli';
	@override String get connectedBadge => 'BAĞLI';
	@override String get scannedServer => 'Taranan sunucu';
	@override String get scanFailedTitle => 'Taranamadı';
	@override String get scanFailedBody => 'Tarayıcı bu telefonda kullanılamıyor.';
	@override String get importFailedTitle => 'İçe aktarılamadı';
	@override String get importFailedBody => 'Bu dosya okunamadı.';
	@override String get renameTitle => 'Sunucuyu yeniden adlandır';
	@override String get nameHint => 'Ad, örneğin Ev modemi';
	@override String get save => 'Kaydet';
	@override String get rename => 'Yeniden adlandır';
	@override String get disconnect => 'Bağlantıyı kes';
	@override String get more => 'Diğer seçenekler';
	@override String get justNow => 'az önce';
	@override String minutesAgo({required Object n}) => '${n} dk önce';
	@override String hoursAgo({required Object n}) => '${n} sa önce';
	@override String daysAgo({required Object n}) => '${n} gün önce';
	@override String get neverUsed => 'Henüz kullanılmadı';
	@override String lastUsed({required Object when}) => 'Son kullanım ${when}';
	@override String get disconnectFirst => 'Kaldırmak için önce bağlantıyı kesin';
	@override String get removeConfirm => 'Bu sunucu G VPN\'den kaldırılsın mı? Ayarları bu telefondan silinir; sunucunun kendisi değişmez.';
	@override String get gTab => 'G Servers';
	@override String get search => 'Ülke ara';
	@override String get noMatch => 'Eşleşen sunucu yok.';
	@override String bestPing({required Object ms}) => 'en iyi ${ms} ms';
	@override String get bestTag => 'EN İYİ';
	@override String get ownHero => 'Kendi sunucularımız';
	@override String get ownHeroSub => 'Daha hızlı, özel, her telefonun kendi anahtarı var';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} sunucu',
	);
	@override String showAll({required Object n}) => '${n} sunucunun tümü';
	@override String get showFewer => 'Daha az göster';
	@override String get fastTab => 'Hızlı';
	@override String get fastestFree => 'En hızlı ücretsiz';
}

// Path: pro
class _Translations$pro$tr extends Translations$pro$en {
	_Translations$pro$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get owned => 'Pro\'nuz var';
	@override String get waitingPlay => 'Google Play bekleniyor';
	@override String startTrial({required Object days}) => '${days} günlük ücretsiz denemeyi başlat';
	@override String get restore => 'Geri yükle';
	@override String save({required Object pct}) => '%${pct} TASARRUF';
	@override String get yearly => 'Yıllık';
	@override String get monthly => 'Aylık';
	@override String get billedMonthly => 'aylık faturalandırılır';
	@override String daysFree({required Object days}) => '${days} gün ücretsiz';
	@override String perMonth({required Object price}) => 'Ayda ${price}';
	@override String get title => 'G VPN Pro';
	@override String get renewGeneric => 'Abonelikler iptal edilene kadar otomatik yenilenir. Google Play\'den istediğiniz zaman iptal edin.';
	@override String renewTrial({required Object days, required Object period, required Object price}) => '${days} gün ücretsiz, ardından her ${period} için ${price}. İptal edilene kadar otomatik yenilenir; ücret alınmaması için deneme bitmeden en az bir gün önce Google Play\'den iptal edin.';
	@override String renew({required Object period, required Object price}) => 'Her ${period} için ${price}. İptal edilene kadar otomatik yenilenir; Google Play\'den istediğiniz zaman iptal edin.';
	@override String get year => 'yıl';
	@override String get month => 'ay';
	@override String get manage => 'Aboneliği yönet';
	@override late final _Translations$pro$free$tr free = _Translations$pro$free$tr._(_root);
	@override String get heroLine => 'Kendi hızlı sunucularımız ve sınırsız her kontrol';
	@override String get start => 'Pro\'yu başlat';
	@override String get compareFree => 'ÜCRETSİZ';
	@override String get comparePro => 'PRO';
	@override String get rowFreeServers => 'Ücretsiz sunucular';
	@override String get rowTools => 'Hız testi, araçlar, Wi-Fi kontrolleri';
	@override String get rowGServers => 'G Servers, kayıt yok';
	@override String get rowLinks => 'Bağlantı kontrolü';
	@override String linksFree({required Object n}) => 'Ayda ${n}';
	@override String get unlimited => 'Sınırsız';
}

// Path: rules
class _Translations$rules$tr extends Translations$rules$en {
	_Translations$rules$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kurallar';
	@override late final _Translations$rules$info$tr info = _Translations$rules$info$tr._(_root);
	@override String get protection => 'Koruma';
	@override String get shield => 'Kalkan';
	@override String get privateDns => 'VPN olmadan Kalkan';
	@override String get privateDnsSub => 'Özel DNS için dns.quad9.net\'i kopyala';
	@override String get privateDnsCopied => 'dns.quad9.net kopyalandı';
	@override String get privateDnsHow => 'Ayarları açın, Özel DNS\'i arayın, "Özel DNS sağlayıcı ana makine adı"nı seçin ve yapıştırın.';
	@override String get stay => 'Bağlı kal';
	@override String get alwaysOn => 'Her zaman açık VPN';
	@override String get alwaysOnSub => 'G VPN durursa Android onu yeniden başlatır';
	@override String get battery => 'Pil';
	@override String get batteryOk => 'Kısıtlamasız';
	@override String get batteryRestricted => 'Kısıtlı: arka planda durabilir';
	@override String get autoConnect => 'Otomatik bağlan';
	@override String get autoOff => 'Kapalı';
	@override String get autoOffSub => 'Yalnızca dokunduğunuzda';
	@override String get autoOpen => 'Genel Wi-Fi';
	@override String get autoOpenSub => 'Açık, WEP veya giriş sayfalı ağlar';
	@override String get autoAny => 'Her Wi-Fi';
	@override String get autoAnySub => 'Herhangi bir Wi-Fi ağı';
	@override String get apps => 'Uygulamalar';
	@override String get appsDirect => 'Doğrudan uygulamalar';
	@override String get appsNone => 'Tüm uygulamalar VPN kullanıyor';
	@override String appsSome({required Object n}) => '${n} uygulama VPN dışı';
	@override String get appearance => 'Görünüm';
	@override String get themePhone => 'Telefon';
	@override String get themeLight => 'Açık';
	@override String get themeDark => 'Koyu';
	@override String get about => 'Hakkında';
}

// Path: apps
class _Translations$apps$tr extends Translations$apps$en {
	_Translations$apps$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Doğrudan uygulamalar';
	@override String get sheetSubtitle => 'Seçilen uygulamalar VPN olmadan bağlanır. Diğer her şey korunmaya devam eder.';
	@override String get whyTitle => 'Bir uygulama neden hariç tutulur';
	@override String get whyBody => 'Bankalar ve ödeme uygulamaları VPN adreslerini sık sık engeller, bu yüzden VPN üzerinden ödemeler başarısız olabilir. Bazı yerel hizmetler yalnızca kendi ülkenizden çalışır.';
	@override String get favouritesBody => 'Sık değiştirdiğiniz uygulamaları yıldızlayın; en üstte kalırlar.';
	@override String get whileConnected => 'Bağlıyken';
	@override String get whileConnectedBody => 'Bu listeyi değiştirmek VPN\'i kısa süreliğine yeniden bağlar.';
	@override String search({required Object n}) => '${n} uygulamada ara';
	@override String get skipping => 'VPN dışı';
	@override String get skippingNone => 'Yok. Tüm uygulamalar VPN üzerinden geçiyor.';
	@override String protectAgain({required Object app}) => '${app} uygulamasını yeniden koru';
	@override String get banking => 'Banka ve ödemeler';
	@override String bankingFound({required Object n}) => 'VPN\'i engelleyebilecek ${n} uygulama bulundu';
	@override String get addAll => 'Tümünü ekle';
	@override String get favourites => 'Favoriler';
	@override String get all => 'Tüm uygulamalar';
	@override String found({required Object n}) => '${n} bulundu';
	@override String get noMatch => 'Eşleşen uygulama yok.';
	@override String showAll({required Object n}) => 'Tümünü göster (${n})';
	@override String get skips => 'VPN dışı';
	@override String get unstar => 'Favorilerden çıkar';
	@override String get star => 'Favorilere ekle';
}

// Path: location
class _Translations$location$tr extends Translations$location$en {
	_Translations$location$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Wi-Fi için konuma izin ver';
	@override String get useHome => 'Wi-Fi adınızı Ana ekranda gösterin';
	@override String get useScan => 'Yakındaki ağları ve kanalları tarayın';
	@override String get private => 'Bu telefonda kalır. Konumunuz asla toplanmaz.';
	@override String get switchTitle => 'Konumu açın';
	@override String get switchBody => 'Konum kapalıyken Android, Wi-Fi adlarını gizler';
}

// Path: addServer
class _Translations$addServer$tr extends Translations$addServer$en {
	_Translations$addServer$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get clipboardEmpty => 'Pano boş.';
	@override String get title => 'Sunucunuzu ekleyin';
	@override String get body => 'Modeminizden, VPS\'inizden veya ev sunucunuzdan bir WireGuard yapılandırması yapıştırın.';
	@override String get nameHint => 'Ad, örneğin Ev modemi';
	@override String get paste => 'Yapıştır';
	@override String get save => 'Sunucuyu kaydet';
	@override String notWireguard({required Object error}) => 'Bu bir WireGuard yapılandırması değil: ${error}';
}

// Path: button
class _Translations$button$tr extends Translations$button$en {
	_Translations$button$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get stop => 'Durdur';
	@override String get connecting => 'Bağlanıyor';
	@override String get stopping => 'Durduruluyor';
	@override String get connect => 'Bağlan';
	@override String get disconnect => 'Bağlantıyı kes';
}

// Path: wol
class _Translations$wol$tr extends Translations$wol$en {
	_Translations$wol$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get info => 'Ayarlarında Wake on LAN etkinse bu Wi-Fi\'deki bir bilgisayarı veya NAS\'ı açar. Telefonunuz aynı ağda olmalı; önce VPN\'i kapatın.';
	@override String get badMac => 'Bu bir MAC adresi değil. Şuna benzer: AA:BB:CC:DD:EE:FF.';
	@override String get sent => 'Uyandırma sinyali gönderildi. Cihaz bir dakika içinde açılmalı.';
	@override String get title => 'Wake on LAN';
	@override String get mac => 'MAC adresi';
	@override String failed({required Object error}) => 'Gönderilemedi: ${error}';
	@override String get computer => 'Bilgisayar';
	@override String get pick => 'Uyandırmak için bir cihaz seçin';
	@override String waking({required Object name}) => '${name} uyandırılıyor';
	@override String get yours => 'CİHAZLARINIZ';
	@override String wakeNamed({required Object name}) => '${name} uyandır';
	@override String get removeHint => 'Kaldırmak için cihaza basılı tutun';
	@override String get add => 'CİHAZ EKLE';
	@override String get name => 'Ad';
	@override String get saveWake => 'Kaydet ve uyandır';
}

// Path: speed
class _Translations$speed$tr extends Translations$speed$en {
	_Translations$speed$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get download => 'İndirme';
	@override String get upload => 'Yükleme';
	@override String get finding => 'Sunucu aranıyor';
	@override String get throughVpn => 'VPN üzerinden';
	@override String get directNoVpn => 'Doğrudan, VPN yok';
	@override String get title => 'Hız testi';
	@override String get stop => 'Durdur';
	@override String get start => 'Testi başlat';
	@override String get again => 'Tekrar test et';
	@override String get viaVpn => 'VPN ile';
	@override String get direct => 'Doğrudan';
	@override String get mbps => 'Mbps';
	@override String get ping => 'PING';
	@override String get vsDirect => 'DOĞRUDANA GÖRE';
	@override String get compare => 'Yakındaki sağlayıcılarla karşılaştır';
	@override String get compareSub => 'Yalnızca hızları paylaşır, asla IP\'nizi değil';
	@override String get tierTv => 'Büyük TV\'ler';
	@override String get tierLaptopLarge => 'Büyük dizüstüler';
	@override String get tierTablet => 'Tabletler ve dizüstüler';
	@override String get tierPhone => 'Telefonlar';
	@override String get tierSmallPhone => 'Küçük telefonlar';
	@override String get tierCalls => 'Aramalar ve ses';
	@override String get messagingOnly => 'Yalnızca mesajlaşma';
	@override String get videoQuality => 'Video kalitesi';
	@override String get preview => 'ÖNİZLEME';
	@override String get history => 'Geçmiş';
	@override String get clear => 'Temizle';
	@override String get viaVpnLower => 'VPN ile';
	@override String get directLower => 'doğrudan';
	@override String get gradeA => 'Aynı anda birkaç 4K yayın ve görüntülü arama';
	@override String get gradeB => 'HD yayın ve akıcı görüntülü aramalar';
	@override String get gradeC => 'Tek HD yayın; yoğun saatlerde aramalar takılabilir';
	@override String get gradeD => 'Gezinme ve mesajlaşma; video zorlanır';
	@override String get yourCountry => 'ülkeniz';
	@override String get median => 'Medyan indirme, son 30 gün';
	@override String get fromUsers => 'Mbps · G VPN kullanıcılarının testlerinden';
	@override String get costLittle => 'VPN hızı çok az düşürüyor';
	@override String get costNoticeable => 'Doğrudana göre belirgin şekilde yavaş';
	@override String get costMuch => 'Çok daha yavaş. Başka bir sunucu deneyin';
	@override String get ofDirect => 'doğrudan hızınızın';
	@override String get none => 'yok';
	@override String ms({required Object n}) => '${n} ms';
	@override String previewTier({required Object tier}) => 'ÖNİZLEME · ${tier}';
	@override String streamsUpTo({required Object tier, required Object who}) => '${tier} kalitesine kadar yayın · ${who}';
	@override String today({required Object time}) => 'Bugün, ${time}';
	@override String tests({required Object n}) => '${n} test';
	@override String gradeVpn({required Object label}) => 'VPN üzerinden ${label}';
	@override String gradeIsp({required Object isp, required Object label}) => '${isp} üzerinde ${label}';
	@override String notEnough({required Object isp}) => '${isp} için henüz yeterli test yok';
	@override String get yourProvider => 'sağlayıcınız';
	@override String rankLine({required Object where, required Object isp, required Object of, required Object rank}) => '${where} bölgesinde ${isp}: ${of} sağlayıcı içinde ${rank}.';
	@override String costLine({required Object note, required Object mbps}) => '${note} · doğrudan ${mbps} Mbps';
	@override String mbpsValue({required Object v}) => '${v} Mbps';
	@override String get gradeExcellent => 'Mükemmel';
	@override String get gradeVeryGood => 'Çok iyi';
	@override String get gradeGood => 'İyi';
	@override String get gradeFair => 'Orta';
	@override String get gradeSlow => 'Yavaş';
	@override String get gradeVerySlow => 'Çok yavaş';
}

// Path: router
class _Translations$router$tr extends Translations$router$en {
	_Translations$router$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get info => 'Modeminize UPnP üzerinden cihazların internete kendi başlarına port açıp açamayacağını sorar ve açılanları listeler. Yalnızca okur, hiçbir şeyi değiştirmez. UPnP\'ye ihtiyaç duyan bir şey yoksa (bazı oyun konsolları ihtiyaç duyar), modem ayarlarından kapatmak daha güvenlidir.';
	@override String get title => 'Modem kontrolü';
	@override String get asking => 'Modeme soruluyor';
	@override String get again => 'Tekrar kontrol et';
	@override String get check => 'Modemi kontrol et';
	@override String get off => 'UPnP kapalı';
	@override String get offBody => 'Cihazlar kendi başlarına port açamaz.';
	@override String get onBody => 'Şu anda bunun üzerinden açık port yok.';
	@override String get checkEach => 'Her birini tanıdığınızdan emin olun.';
	@override String get cgnat => 'Paylaşılan sağlayıcı adresi: internetten erişilemez.';
	@override String get noDescription => 'Açıklama yok';
	@override String opened({required Object n}) => 'Cihazların açtığı ${n} port';
	@override String mapping({required Object proto, required Object host}) => '${proto} → ${host}';
	@override String get upnpOn => 'UPnP açık';
	@override String get routerLabel => 'Yönlendirici';
	@override String get internetAddress => 'İnternet adresi';
	@override String get openedBy => 'Cihazların açtıkları';
}

// Path: network
class _Translations$network$tr extends Translations$network$en {
	_Translations$network$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bu ağ';
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Mobil veri';
	@override String get ethernet => 'Ethernet';
	@override String get offline => 'Çevrimdışı';
	@override String get risky => 'Riskli ağ. Burada VPN\'i bağlayın.';
	@override String get review => 'Güvenmeden önce göz atmaya değer.';
	@override String get covered => 'VPN ile korunuyor.';
	@override String get safe => 'Bu ağ güvenli görünüyor.';
	@override String get mobileSentence => 'Mobil veri.';
	@override String get notConnected => 'Bağlı değil.';
	@override String get showName => 'Adı göster';
	@override String get sitesSee => 'Sitelerin gördüğü';
	@override String get provider => 'Sağlayıcı';
	@override String get location => 'Konum';
	@override String get couldNotCheck => 'Kontrol edilemedi';
	@override String get checking => 'Kontrol ediliyor';
	@override String get signal => 'Sinyal';
	@override String get linkSpeed => 'Bağlantı hızı';
	@override String get gateway => 'Ağ geçidi';
	@override String get none => 'Yok';
	@override String get privateDns => 'Özel DNS';
	@override String get automatic => 'Otomatik';
	@override String get off => 'Kapalı';
	@override String get metered => 'Kotalı';
	@override String get yes => 'Evet';
	@override String get no => 'Hayır';
	@override String readFailed({required Object error}) => 'Ağ okunamadı: ${error}';
}

// Path: devices
class _Translations$devices$tr extends Translations$devices$en {
	_Translations$devices$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get info => 'Wi-Fi aralığınızdaki her adrese uğrar ve cihazlardan kendilerini tanıtmalarını ister. Reddeden bir cihaz da sayılır: ret, orada olduğunu kanıtlar.\n\nAdlar: cihazların yayımladıklarından (Bonjour, UPnP, Windows adları) ve modeminizden.\n\nBilinmeyen cihazlar: Android donanım adreslerini uygulamalardan gizler, bu yüzden ad bildirmeyen sessiz bir cihaz tanımlanamaz. Bunlar için modeminizin cihaz listesine bakın.\n\nYeni: bu ağın son taramasında görülmeyen cihaz.';
	@override String get needWifi => 'Önce bir Wi-Fi ağına bağlanın.';
	@override String get title => 'Cihazlar';
	@override String get again => 'Tekrar tara';
	@override String get looking => 'Cihazlar aranıyor';
	@override String get all => 'Tümü';
	@override String get phones => 'Telefonlar';
	@override String get tvs => 'TV\'ler';
	@override String get computers => 'Bilgisayarlar';
	@override String get other => 'Diğer';
	@override String get thisPhone => 'Bu telefon';
	@override String get router => 'Modem';
	@override String get unknown => 'Bilinmeyen cihaz';
	@override String get address => 'Adres';
	@override String get answersIn => 'Yanıt süresi';
	@override String get type => 'Tür';
	@override String get newBadge => 'YENİ';
	@override String scanning({required Object n}) => '254 adresin ${n} tanesi tarandı';
	@override String newSince({required Object n}) => 'Son taramadan bu yana ${n} yeni';
	@override String ms({required Object n}) => '${n} ms';
	@override String get cameras => 'Kameralar';
	@override String get device => 'Cihaz';
	@override String get online => 'Çevrimiçi';
	@override String get model => 'Model';
	@override String get announced => 'Kendini şöyle tanıtıyor';
	@override String get services => 'AÇIK HİZMETLER';
	@override String get checkingServices => 'Hizmetler kontrol ediliyor';
	@override String get noServices => 'Yaygın hizmetlerden hiçbiri yanıt vermiyor';
	@override String get rename => 'Yeniden adlandır';
	@override String get save => 'Kaydet';
	@override late final _Translations$devices$kinds$tr kinds = _Translations$devices$kinds$tr._(_root);
	@override String get details => 'Ağ ayrıntıları';
	@override String get listView => 'Liste';
	@override String get meshView => 'Ağ örgüsü';
	@override String get offlineHeading => 'Çevrimdışı';
	@override String seen({required Object when}) => '${when} görüldü';
	@override String agoMinutes({required Object n}) => '${n} dk önce';
	@override String agoHours({required Object n}) => '${n} sa önce';
	@override String agoDays({required Object n}) => '${n} gün önce';
	@override String get throughVpn => 'VPN üzerinden';
	@override String get closer => 'Daha yakın = daha hızlı yanıt';
	@override String get yours => 'Bu sizin mi?';
	@override String get mine => 'Benim';
	@override String get notMine => 'Benim değil';
	@override String get whatIsIt => 'Bu ne?';
	@override String ourGuess({required Object kind}) => 'Tahminimiz: ${kind}';
	@override String get groupPersonal => 'Telefonlar ve bilgisayarlar';
	@override String get groupHome => 'Ev ve medya';
	@override String get groupNetwork => 'Ağ ve akıllı ev';
	@override String onlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} çevrimiçi',
	);
	@override String offlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} çevrimdışı',
	);
	@override String toConfirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} onay bekliyor',
	);
}

// Path: ping
class _Translations$ping$tr extends Translations$ping$en {
	_Translations$ping$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get askTitle => 'Bir sunucuya ping at';
	@override String get askHint => 'example.com veya 192.168.1.10';
	@override String get title => 'Ping';
	@override String get router => 'Modem';
	@override String get pause => 'Duraklat';
	@override String get start => 'Başlat';
	@override String get host => 'Sunucu';
	@override String get live => 'Canlı';
	@override String get ago => '60 sn önce';
	@override String get min => 'MİN';
	@override String get avg => 'ORT';
	@override String get jitter => 'JİTTER';
	@override String get loss => 'KAYIP';
	@override String get goodFor => 'Şunlar için yeterli';
	@override String get calls => 'Görüntülü aramalar';
	@override String get games => 'Çevrimiçi oyunlar';
	@override String get streaming => 'Yayın izleme';
	@override String get great => 'Harika';
	@override String get okay => 'Fena değil';
	@override String get poor => 'Zayıf';
	@override String get lost => 'kayıp';
	@override String get now => 'şimdi';
}

// Path: status
class _Translations$status$tr extends Translations$status$en {
	_Translations$status$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get info => 'Her hizmete üç kez bağlanır ve en hızlı yanıtı gösterir.\n\nBurada engelli: doğrudan yanıt vermeyen ama VPN üzerinden çalışan bir hizmet, ağınız veya ülkeniz tarafından engellenmiştir.\n\nGeçmiş: bu telefondan yapılan son 24 saatin kontrolleri, yalnızca bu telefonda saklanır.';
	@override String get title => 'Hizmet durumu';
	@override String get checking => 'Kontrol ediliyor';
	@override String get again => 'Tekrar kontrol et';
	@override String get viaVpn => 'VPN üzerinden kontrol edildi';
	@override String get direct => 'Doğrudan kontrol edildi';
	@override String get favourites => 'Favoriler';
	@override String get edit => 'Düzenle';
	@override String get last24 => 'Son 24 saat';
	@override String get ago => '24 sa önce';
	@override String get all => 'Tüm hizmetler';
	@override String get pickFour => 'En fazla dört seçin';
	@override String get outage => 'VPN ile bile: muhtemelen kesinti';
	@override String get blocked => 'Bu ağda engellenmiş olabilir';
	@override String get connect => 'Bağlan';
	@override String get blockedShort => 'Engelli';
	@override String get now => 'şimdi';
	@override String checks({required Object n}) => '${n} kontrol';
	@override String andMore({required Object first, required Object n}) => '${first} ve ${n} tane daha';
	@override String notReachable({required Object who}) => '${who} erişilemiyor';
}

// Path: tools
class _Translations$tools$tr extends Translations$tools$en {
	_Translations$tools$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Mobil veri';
	@override String get ethernet => 'Ethernet';
	@override String get checking => 'Kontrol ediliyor';
	@override String get offline => 'Çevrimdışı';
	@override String get title => 'Araçlar';
	@override String get networkDesc => 'Güvenlik kontrolü, sitelerin gördükleri, sinyal, modem ve DNS.';
	@override String get internet => 'İnternet';
	@override String get speed => 'Hız testi';
	@override String get speedDesc => 'İndirme, yükleme ve video kalitesi';
	@override String get ping => 'Ping';
	@override String get pingDesc => 'Canlı yanıt süresi ve dalgalanma';
	@override String get status => 'Hizmet durumu';
	@override String get statusDesc => 'Bir uygulama burada çalışıyor mu, engelli mi?';
	@override String get trace => 'Traceroute';
	@override String get traceDesc => 'Bir siteye giden yoldaki her durak';
	@override String get security => 'Bu ağ';
	@override String get devices => 'Bu ağdaki cihazlar';
	@override String get devicesDesc => 'Wi-Fi\'nizde kimler var';
	@override String get router => 'Modem kontrolü';
	@override String get routerDesc => 'Cihazlarınızın açtığı portlar';
	@override String get ports => 'Açık portlar';
	@override String get portsDesc => 'Bir cihaz veya sunucudaki riskli portlar';
	@override String get utilities => 'Araçlar';
	@override String get wifiScanner => 'Wi-Fi tarayıcı';
	@override String get wifiDesc => 'Çevrenizdeki ağlar ve en boş kanal';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'Bu ağdaki bir bilgisayarı açın';
	@override String get passwordCheck => 'Parola kontrolü';
	@override String get passwordCheckDesc => 'Sızdırılmış mı?';
	@override String get linkCheck => 'Bağlantı kontrolü';
	@override String get linkCheckDesc => 'Açmak güvenli mi?';
	@override String get breaches => 'Veri sızıntıları';
	@override String get breachesDesc => 'Son zamanlarda ne sızdı';
	@override String get blocked => 'Ne engelli';
	@override String get blockedDesc => 'Bu ağda engellenen siteler';
}

// Path: trace
class _Translations$trace$tr extends Translations$trace$en {
	_Translations$trace$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get info => 'Her durak, trafiğinizin siteye giderken geçtiği bir yönlendiricidir.\n\nSessiz atlamalar: birçok yönlendirici bu denemelere hiç yanıt vermez. Bu normaldir, bir arıza değildir.\n\nVPN açıkken: yol tünelin içinden başlar, bu yüzden kendi ağınız ve sağlayıcınız gizli kalır.\n\nNasıl: uygulamalar bu paketleri doğrudan gönderemediği için Android\'in kendi ping aracını atlama sınırıyla kullanır.';
	@override String get title => 'Traceroute';
	@override String get stop => 'Durdur';
	@override String get trace => 'İzle';
	@override String get again => 'Tekrar izle';
	@override String get destination => 'Hedef';
	@override String get hops => 'ATLAMA';
	@override String get answered => 'YANIT VERDİ';
	@override String get total => 'TOPLAM';
	@override String get thisPhone => 'Bu telefon';
	@override String get silentOne => '1 sessiz atlama';
	@override String get yourRouter => 'Modeminiz';
	@override String ms({required Object n}) => '${n} ms';
	@override String silentMany({required Object n}) => '${n} sessiz atlama';
	@override String hop({required Object n}) => 'Atlama ${n}';
	@override String slowest({required Object ms, required Object hop}) => 'Gecikmenin çoğu, ${ms} ms, ${hop}. atlamada ekleniyor: genellikle ülkeler arası uzun bir kablo ya da yoğun bir bağlantı.';
	@override String get popular => 'POPÜLER';
	@override String get recent => 'SON KULLANILANLAR';
	@override String get clearRecent => 'Sonları temizle';
	@override String hopsCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} atlama',
	);
}

// Path: ports
class _Translations$ports$tr extends Translations$ports$en {
	_Translations$ports$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get ftpNote => 'Şifreleri şifrelemeden gönderir.';
	@override String get sshNote => 'Uzaktan giriş. Kendiniz kurduysanız sorun yok.';
	@override String get telnetNote => 'Şifresiz uzaktan giriş; botnetlerin favorisi.';
	@override String get dnsNote => 'Modemde normaldir.';
	@override String get web => 'Web (HTTP)';
	@override String get webNote => 'Genellikle modem yönetim sayfası.';
	@override String get webTls => 'Web (HTTPS)';
	@override String get smb => 'Windows dosya paylaşımı';
	@override String get smbNote => 'Asla internete açık olmamalı.';
	@override String get rtsp => 'RTSP kamera yayını';
	@override String get rtspNote => 'Burada yayın yapan bir kamera olabilir.';
	@override String get upnpNote => 'Cihazların modem portlarını kendi başına açmasına izin verir.';
	@override String get rdp => 'Uzak Masaüstü';
	@override String get rdpNote => 'Yaygın bir saldırı yolu.';
	@override String get vncNote => 'Ekran paylaşımı, çoğu zaman şifresiz.';
	@override String get tr069Note => 'İnternet sağlayıcısının uzaktan yönetimi.';
	@override String get webAlt => 'Web (alternatif)';
	@override String get webAltTls => 'Web (alternatif HTTPS)';
	@override String get title => 'Açık portlar';
	@override String get check => 'Portları kontrol et';
	@override String get address => 'Cihaz veya sunucu adresi';
	@override String get risky => 'RİSKLİ';
	@override String get review => 'İNCELE';
	@override String get normal => 'NORMAL';
	@override String info({required Object n}) => 'Ev modemleri ve cihazlarında önemli olan ${n} portu kontrol eder ve açık olan her birini açıklar.\n\nYalnızca sahibi olduğunuz veya yönettiğiniz cihazları ve sunucuları kontrol edin.';
	@override String checking({required Object n}) => '${n} port kontrol ediliyor';
	@override String yourRouter({required Object ip}) => 'Modeminiz: ${ip}';
	@override String noneOpen({required Object host}) => '${host} üzerinde açık yaygın port yok.';
	@override String summary({required Object n, required Object open}) => '${n} port içinde ${open} açık';
	@override String riskyCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} riskli',
	);
	@override String get noneRisky => 'Riskli bir şey yok';
}

// Path: wifi
class _Translations$wifi$tr extends Translations$wifi$en {
	_Translations$wifi$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Wi-Fi tarayıcı';
	@override String get allow => 'Wi-Fi taramasına izin ver';
	@override String get needsPermission => 'Konum izni gerekiyor.';
	@override String get scanning => 'Taranıyor';
	@override String get again => 'Tekrar tara';
	@override String get failed => 'Tarama başarısız';
	@override String get none => 'Ağ bulunamadı. Konum kapalı olabilir.';
	@override String get hidden => 'Gizli ağ';
	@override String nearby({required Object n}) => 'Yakında ${n} ağ';
	@override String get permissionInfo => 'Android, yakındaki Wi-Fi ağlarını yalnızca konum izni olan uygulamalara gösterir. G VPN bunu yalnızca bu telefondaki ağları listelemek için kullanır.';
	@override String get info => 'Telefonun son taramasındaki ağları listeler. Android dakikada yalnızca birkaç taramaya izin verir, bu yüzden hızlı tekrar tarama aynı listeyi gösterebilir. Önerilen kanal, birbiriyle çakışmayan üç kanal olan 1, 6 ve 11 arasında en az kalabalık olanıdır.';
	@override String get airMap => 'Hava haritası';
	@override String get channels => 'Kanallar';
	@override String get list => 'Liste';
	@override String get secure => 'Güvenli';
	@override String get weakLabel => 'Zayıf';
	@override String get openLabel => 'Açık';
	@override String get sizeIsWidth => 'Boyut = kanal genişliği';
	@override String get strongest => 'EN GÜÇLÜ';
	@override String get openNearby => 'YAKINDAKİ AÇIK AĞLAR';
	@override String get onYourChannel => 'KANALINIZDA';
	@override String get noneNearby => 'Yok';
	@override String get verdictOpen => 'Yakındaki herkes gönderilenleri okuyabilir';
	@override String get verdictWep => 'Eski güvenlik, kolay kırılır';
	@override String get verdictWpa => 'Eski güvenlik';
	@override String get verdictWps => 'WPS açık: kırılması daha kolay';
	@override String get verdictGood => 'İyi korunuyor';
	@override String get maker => 'Üretici';
	@override String get address => 'Donanım adresi';
	@override String get privateAddress => 'Gizlilik için yönlendirici uydurdu';
	@override String get you => 'Siz';
	@override String onClear({required Object name}) => '${name} boş bir kanalda';
	@override String move({required Object name, required Object n}) => '${name} ağını ${n}. kanala taşıyın';
	@override String get clear => 'Boş';
	@override String get busy => 'Yoğun';
	@override String get crowded => 'Kalabalık';
	@override String get allBands => 'Tüm bantlar';
	@override String get openOnly => 'Yalnızca açık';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} ağ',
	);
}

// Path: errors
class _Translations$errors$tr extends Translations$errors$en {
	_Translations$errors$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get notAuthorized => 'VPN izni verilmedi.';
	@override String get turnedOff => 'VPN sistem veya başka bir uygulama tarafından kapatıldı.';
	@override String get busy => 'Zaten açık bir izin isteği var.';
	@override String get cancelled => 'Bağlantı iptal edildi.';
	@override String badConfig({required Object error}) => 'Bu sunucunun yapılandırması geçersiz: ${error}';
	@override String get timeout => 'Sunucu yanıt vermedi.';
	@override String get refused => 'Sunucu bağlantıyı reddetti.';
	@override String failed({required Object error}) => 'Bağlanılamadı: ${error}';
	@override String get tryAnother => 'Ücretsiz sunucular gelip gider; başka birini deneyin.';
	@override String get downloadFailed => 'Bu sunucunun ayarları indirilemedi. Bağlantınızı kontrol edin veya başka bir sunucu seçin.';
}

// Path: scan
class _Translations$scan$tr extends Translations$scan$en {
	_Translations$scan$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get mobile => 'Mobil veri';
	@override String get ping => 'PING';
	@override String get noReply => 'Yanıt yok';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, tünel';
	@override String get dnsTunnel => 'Tünelde';
	@override String get privateDns => 'Özel DNS';
	@override String get dnsIsp => 'Sağlayıcı, görünür';
	@override String get network => 'AĞ';
	@override String get offline => 'Çevrimdışı';
	@override String get open => 'Açık, şifresiz';
	@override String get wep => 'WEP, güvensiz';
	@override String get owe => 'Açık, şifreli';
	@override String get enterprise => 'Kurumsal';
	@override String get unknown => 'Bilinmiyor';
	@override String get wifi => 'WI-FI';
	@override String get signIn => 'Giriş sayfası';
	@override String ms({required Object n}) => '${n} ms';
	@override String covered({required Object what}) => '${what}, korunuyor';
}

// Path: legal
class _Translations$legal$tr extends Translations$legal$en {
	_Translations$legal$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get privacy => 'Gizlilik politikası';
	@override String get terms => 'Kullanım koşulları';
	@override String get licences => 'Açık kaynak lisansları';
}

// Path: update
class _Translations$update$tr extends Translations$update$en {
	_Translations$update$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get ready => 'Güncelleme hazır';
	@override String get restart => 'Yeniden başlat';
}

// Path: details
class _Translations$details$tr extends Translations$details$en {
	_Translations$details$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get share => 'Paylaş';
	@override String connectedFor({required Object n}) => 'BAĞLI · ${n} DK';
	@override String get notConnected => 'BAĞLI DEĞİL';
	@override String get downloaded => 'İNDİRİLEN';
	@override String get uploaded => 'YÜKLENEN';
	@override String get lastUsed => 'SON KULLANIM';
	@override String get connection => 'Bağlantı';
	@override String get protocol => 'Protokol';
	@override String get address => 'Adresiniz';
	@override String get dns => 'DNS';
	@override String get routes => 'Rotalar';
	@override String get allTraffic => 'Tüm trafik';
	@override String someRoutes({required Object n}) => '${n} ağ';
	@override String get keepalive => 'Keepalive';
	@override String get serverKey => 'Sunucu anahtarı';
	@override String get copy => 'Kopyala';
	@override String get copied => 'Kopyalandı';
	@override String get manage => 'Yönet';
	@override String get export => 'Yedek için dışa aktar';
	@override String get exportSub => 'Tüm sunucularınız tek dosyada';
}

// Path: share
class _Translations$share$tr extends Translations$share$en {
	_Translations$share$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String title({required Object name}) => '${name} paylaş';
	@override String get sameKey => 'Bu, bu telefonun anahtarını paylaşır. Ona sahip olan herkes sunucunuzu sizin yerinize kullanabilir ve aynı anda yalnızca bir cihaz bağlanabilir.';
	@override String get scanHint => 'Diğer telefonda: G VPN, Sunucular, QR tara. Kaydedilmiş bir resim de olur.';
	@override String get saveImage => 'Resmi kaydet';
	@override String get send => 'Gönder';
}

// Path: add
class _Translations$add$tr extends Translations$add$en {
	_Translations$add$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sunucu ekle';
	@override String get subtitle => 'Herhangi bir WireGuard sunucusu: modem, VPS veya ev sunucusu.';
	@override String get camera => 'Kamerayla tara';
	@override String get cameraSub => 'Başka ekrandaki QR';
	@override String get image => 'Bir resimden';
	@override String get imageSub => 'Ekran görüntüsü veya kayıtlı fotoğraf';
	@override String get noQr => 'Bu resimde QR kod bulunamadı.';
	@override String get tip => 'QR\'ı WhatsApp veya Telegram\'dan mı aldınız? Resimde Paylaş\'a dokunup G VPN\'i seçin.';
}

// Path: backup
class _Translations$backup$tr extends Translations$backup$en {
	_Translations$backup$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String restored({required Object n}) => '${n} sunucu geri yüklendi';
	@override String get nothingNew => 'Bu sunucular zaten burada';
}

// Path: gs
class _Translations$gs$tr extends Translations$gs$en {
	_Translations$gs$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'G Servers, G VPN Pro aboneleri içindir.';
	@override String get off => 'G Servers şu anda kapalı.';
	@override String get network => 'G Servers\'a ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.';
	@override String get active => 'AKTİF';
	@override String get servers => 'G Servers';
	@override String busy({required Object n}) => '%${n} meşgul';
	@override String get offline => 'Çevrimdışı';
	@override String get devices => 'Cihazlarınız';
	@override String subtitle({required Object country}) => 'G Server · ${country} · WireGuard';
	@override String get busyLabel => 'MEŞGUL';
	@override String get status => 'DURUM';
	@override String get online => 'Çevrimiçi';
	@override String get onThisServer => 'Bu sunucuda';
	@override String get thisPhone => 'Bu telefon';
	@override String get added => 'Eklendi · anahtar burada oluşturuldu';
	@override String get notAdded => 'Bağlandığınızda eklenir';
	@override String get logs => 'Etkinlik kayıtları';
	@override String get noneKept => 'Tutulmuyor';
	@override String get privacy => 'Sunucu bu telefonu yalnızca açık anahtarıyla tanır. Ziyaret ettiğiniz siteleri veya gönderdiğiniz trafiği kaydetmez.';
	@override String get stepPro1 => 'G VPN\'i aynı Google hesabıyla telefona kurun.';
	@override String get stepPro2 => 'Pro sekmesini açın. Pro kendiliğinden açılır ya da Geri yükle\'ye dokunun.';
	@override String get step3 => 'Bağlan\'a dokunun. Telefon anahtarını oluşturur ve G Servers\'a eklenir. QR yok, kod yok.';
	@override String get stepFree1 => 'G VPN\'i telefona kurun.';
	@override String get stepFree2 => 'Pro sekmesini açın.';
	@override String get devicesIntroPro => 'Pro, Google hesabınızla gelir. Her telefonun kendi anahtarı vardır, bu yüzden birbirlerinin bağlantısını kesmezler.';
	@override String get devicesIntroFree => 'Her telefonun kendi anahtarı vardır, bu yüzden birbirlerinin bağlantısını kesmezler.';
	@override String get otherPhone => 'Başka bir telefon';
	@override String lastConnected({required Object when}) => 'Son bağlantı ${when}';
	@override String get noDevices => 'Bir G Server\'a bir kez bağlanın, telefonlarınız burada görünür.';
	@override String get addTitle => 'Telefon ekle veya yeniden kur';
	@override String idle({required Object n}) => '${n} gün bağlanmayan telefon G Servers\'dan kendiliğinden kaldırılır; böylece eski ya da yeniden kurulan telefon yer kaplamaz.';
	@override String limitNote({required Object n}) => 'Plan başına en fazla ${n} telefon.';
	@override String fullTitle({required Object n}) => '${n} yerin hepsi kullanımda';
	@override String get fullBody => 'Artık kullanmadığınız bir telefonu kaldırın, bu telefon hemen bağlansın.';
	@override String get busyNow => 'Şu anda çok fazla yeni telefon var. Biraz sonra tekrar deneyin.';
	@override String get serverFull => 'Bu sunucu dolu. Başka bir G Server deneyin.';
	@override String get ping => 'PING';
	@override String get last24 => 'Meşguliyet, son 24 saat';
	@override String get noHistory => 'Grafik, sunucu gün içinde kullanıldıkça dolar.';
	@override String chartLabel({required Object max}) => 'Son 24 saatteki meşguliyet, en fazla yüzde ${max}';
	@override String get hoursAgo => '24 sa önce';
	@override String get now => 'Şimdi';
	@override String get included => 'Dahil';
	@override String get perkServers => 'Hızlı, özel sunucular';
	@override String get perkServersSub => 'WireGuard, bizim işlettiğimiz, etkinlik kaydı yok';
	@override String get perkLinks => 'Sınırsız bağlantı kontrolü';
	@override String get perkLinksSub => 'Size gönderilen her bağlantıyı kontrol edin';
	@override String devicesOf({required Object limit, required Object used}) => 'Cihazlarınız · ${limit} içinde ${used}';
	@override String get eachKey => 'Her telefonun kendi anahtarı var';
	@override String get connected => 'Bağlı';
	@override String get bestNow => 'ŞU AN SİZİN İÇİN EN İYİSİ';
	@override String get logsShort => 'KAYIT';
}

// Path: map
class _Translations$map$tr extends Translations$map$en {
	_Translations$map$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get open => 'Haritayı aç';
	@override String get searchCountries => 'Ülke ara';
	@override String get noMatch => 'Eşleşen ülke yok';
	@override String get locate => 'Konumum';
	@override String get list => 'Liste';
	@override String get map => 'Harita';
	@override String freeServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} ücretsiz sunucu',
	);
	@override late final _Translations$map$grade$tr grade = _Translations$map$grade$tr._(_root);
	@override String get switchTo => 'Geç';
	@override String freeServer({required Object n}) => 'Ücretsiz sunucu ${n}';
	@override String get best => 'EN İYİ';
	@override String gServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} G Server',
	);
}

// Path: stats
class _Translations$stats$tr extends Translations$stats$en {
	_Translations$stats$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get thisWeek => 'Bu hafta';
	@override String get time => 'Süre';
	@override String get data => 'Veri';
	@override String get protected => 'korumalı';
	@override String get throughVpn => 'VPN üzerinden';
	@override String get seeDetails => 'Ayrıntılar';
	@override String get title => 'İstatistikler';
	@override String get week => 'Hafta';
	@override String get month => 'Ay';
	@override String get protectedLabel => 'KORUMALI';
	@override String get dataUsed => 'KULLANILAN VERİ';
	@override String get byServer => 'SUNUCUYA GÖRE';
	@override String get onPhone => 'Yalnızca bu telefonda';
	@override String get reset => 'Sıfırla';
	@override String get resetTitle => 'İstatistikler sıfırlansın mı?';
	@override String get resetBody => 'Bu telefondaki korumalı süre ve veri silinir. Geri alınamaz.';
	@override String hm({required Object h, required Object m}) => '${h} sa ${m} dk';
	@override String m({required Object m}) => '${m} dk';
	@override String get empty => 'Saymaya başlamak için bağlanın.';
}

// Path: recents
class _Translations$recents$tr extends Translations$recents$en {
	_Translations$recents$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Son kullanılanlar';
	@override String get allServers => 'Tüm sunucular';
	@override String get free => 'Ücretsiz sunucu';
	@override String get yours => 'Sunucunuz';
	@override String get gserver => 'G Server';
}

// Path: presets
class _Translations$presets$tr extends Translations$presets$en {
	_Translations$presets$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hazır ayarlar';
	@override String get all => 'Tümü';
	@override String get newPreset => 'Yeni ayar';
	@override String get edit => 'Ayarı düzenle';
	@override String get name => 'Ad';
	@override String get namePlaceholder => 'Ayarım';
	@override String get server => 'SUNUCU';
	@override String get fastestOption => 'En hızlı';
	@override String get countryOption => 'Ülke';
	@override String get pickCountry => 'Ülke seçin';
	@override String get skipMyCountry => 'Ülkemi atla';
	@override String get notMine => 'ülkem hariç';
	@override String get protocol => 'PROTOKOL';
	@override String get auto => 'Otomatik';
	@override String get tryNext => 'Engellenirse sonrakini dene';
	@override String get shield => 'KALKAN';
	@override String get followRules => 'Kurallardaki gibi';
	@override String get allApps => 'Tüm uygulamalar VPN\'den';
	@override String get allAppsShort => 'tüm uygulamalar';
	@override String get save => 'Kaydet';
	@override String get delete => 'Sil';
	@override String get reset => 'Varsayılana dön';
	@override String get none => 'Şu an bu ayara uyan ücretsiz sunucu yok.';
	@override late final _Translations$presets$names$tr names = _Translations$presets$names$tr._(_root);
}

// Path: shield
class _Translations$shield$tr extends Translations$shield$en {
	_Translations$shield$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kalkan';
	@override String get sub => 'Bağlıyken çalışır';
	@override String get off => 'Kapalı';
	@override String get offSub => 'Sunucunun kendi DNS\'i';
	@override String get malware => 'Kötü amaçlı yazılım';
	@override String get malwareSub => 'Zararlı ve oltalama sitelerini engeller';
	@override String get family => 'Kötü amaçlı ve yetişkin siteleri';
	@override String get familySub => 'Yetişkin içeriği de engeller';
	@override String get custom => 'Özel DNS';
	@override String get customSub => 'Kendi DNS sunucularınız';
	@override String get customHint => 'IP adresi, örneğin 1.1.1.1';
	@override String get invalid => 'Bir veya iki IP adresi girin.';
}

// Path: checks
class _Translations$checks$tr extends Translations$checks$en {
	_Translations$checks$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Güvenlik kontrolleri';
	@override String get password => 'Parola';
	@override String get link => 'Bağlantı';
	@override String get pwTitle => 'Sızdırıldı mı?';
	@override String get pwHint => 'Kontrol edilecek parola';
	@override String get showPassword => 'Parolayı göster';
	@override String get hidePassword => 'Parolayı gizle';
	@override String get check => 'Kontrol et';
	@override String get leaked => 'Sızıntılarda bulundu';
	@override String seen({required Object n}) => '${n} kez görüldü';
	@override String get leakedAdvice => 'Kullandığınız her yerde değiştirin; e-posta ve bankadan başlayın.';
	@override String get notFound => 'Bilinen sızıntılarda yok';
	@override String get notFoundAdvice => 'İyi bir işaret, garanti değil. Her hesapta farklı parola kullanın.';
	@override String get failed => 'Kontrol edilemedi. Tekrar deneyin.';
	@override String get private => 'Parolanız bu telefondan hiç çıkmaz';
	@override String get linkTitle => 'Bu bağlantı güvenli mi?';
	@override String get linkHint => 'Kontrol edilecek bağlantı';
	@override String get paste => 'Yapıştır';
	@override String get danger => 'Tehlikeli bağlantı';
	@override String get dangerAdvice => 'Açmayın ve hiçbir bilgi girmeyin.';
	@override String get clear => 'Bilinen kötü amaçlı yazılım veya oltalama listelerinde yok';
	@override String get clearAdvice => 'Yine de giriş yapmadan önce adrese bakın.';
	@override String get goesTo => 'Gittiği yer';
	@override String get redirects => 'Yönlendirmeler';
	@override String get invalid => 'Bu bir web adresine benzemiyor.';
	@override String get busy => 'Çok fazla kontrol. Biraz sonra tekrar deneyin.';
	@override String get unavailable => 'Bağlantı kontrolü şu an kullanılamıyor.';
	@override String get listed => 'Kötü amaçlı yazılım veya oltalamayla bilinen';
	@override String get missing => 'Bu adreste site yok';
	@override String get missingAdvice => 'Yazımı kontrol edin: dolandırıcılar benzer adresler kullanır.';
	@override String left({required Object total, required Object n}) => 'Bu ay ${total} ücretsiz kontrolden ${n} kaldı';
	@override String get usedUp => 'Bu ayın ücretsiz bağlantı kontrollerini kullandınız';
	@override String get usedUpSub => 'Pro\'da sınırsız kontrol var. Ücretsiz kontroller ayın 1\'inde yenilenir.';
	@override String get getPro => 'Pro\'yu al';
}

// Path: toolSettings
class _Translations$toolSettings$tr extends Translations$toolSettings$en {
	_Translations$toolSettings$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Araç ayarları';
	@override String get askMobile => 'Mobil veride hız testinden önce sor';
	@override String get askMobileSub => 'Hızlı bağlantıda bir test 100 MB\'tan fazla kullanabilir';
	@override String get mobileTitle => 'Mobil veri kullanılsın mı?';
	@override String get mobileBody => 'Hızlı bağlantıda bir hız testi 100 MB\'tan fazla kullanabilir.';
	@override String get mobileGo => 'Test et';
	@override String get safe => 'Güvenli';
	@override String get unsafe => 'Güvensiz';
	@override String devices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} cihaz',
	);
	@override String get hideMac => 'Donanım adreslerini gizle';
	@override String get hideMacSub => 'MAC adreslerinin yalnızca üretici kısmını gösterir';
	@override String get names => 'Yönlendirici ve sunucu adlarını göster';
	@override String get namesSub => 'Traceroute\'ta adresler için ad arar';
	@override String get remember => 'Son kullanılan adresleri hatırla';
	@override String get rememberSub => 'Traceroute için';
	@override String get clear => 'Araç geçmişini temizle';
	@override String get clearSub => 'Son adresleri ve her ağdaki cihazları unutur';
	@override String get clearGo => 'Temizle';
}

// Path: security
class _Translations$security$tr extends Translations$security$en {
	_Translations$security$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get tab => 'Güvenlik';
	@override String get good => 'İyi';
	@override String get fair => 'Orta';
	@override String get atRisk => 'Riskli';
	@override String get allClear => 'Düzeltilecek bir şey yok';
	@override String checked({required Object time}) => '${time} itibarıyla kontrol edildi';
	@override String get trend => 'SON İKİ HAFTA';
	@override String get checking => 'Bu ağ kontrol ediliyor';
	@override String get snoozed => 'Ertelenenler';
	@override String get remindLater => 'Sonra hatırlat';
	@override String get unsnooze => 'Şimdi hatırlat';
	@override String get review => 'İncele';
	@override String get confirmGo => 'Onayla';
	@override String get scanGo => 'Tara';
	@override String get look => 'Bak';
	@override String get connectGo => 'Bağlan';
	@override String get checkAgain => 'Tekrar kontrol et';
	@override String get wifiOpen => 'Wi-Fi açık';
	@override String get wifiOpenDetail => 'Yakındaki herkes gönderilenleri görebilir';
	@override String get wifiWep => 'Wi-Fi WEP kullanıyor';
	@override String get wifiWepDetail => 'Eski güvenlik, kolay kırılır';
	@override String get wifiOwe => 'Wi-Fi Enhanced Open kullanıyor';
	@override String get wifiOweDetail => 'Şifreli ama herkes katılabilir';
	@override String get wifiSecure => 'Wi-Fi şifrelemesi';
	@override String get wifiUnknown => 'Wi-Fi güvenliği bilinmiyor';
	@override String get wifiUnknownDetail => 'Android nasıl korunduğunu bildirmedi';
	@override String get wps => 'WPS açık';
	@override String get wpsDetail => 'Yönlendirici ayarlarından kapatın';
	@override String get upnpOff => 'Yönlendirici portları kapalı tutuyor';
	@override String get upnpOffDetail => 'UPnP kapalı';
	@override String get upnpOn => 'Yönlendirici cihazların port açmasına izin veriyor';
	@override String get upnpOnDetail => 'UPnP açık';
	@override String get portsOk => 'Yönlendiricide riskli port yok';
	@override String get portsRisky => 'Yönlendiricide riskli portlar açık';
	@override String get scanFirst => 'Burada kimler var görmek için tarayın';
	@override String get scanFirstDetail => 'Bilinmeyen cihazlar puanı düşürür';
	@override String get notMineDetail => 'Yönlendiricinin cihaz listesine bakın';
	@override String get confirmDetail => 'Sizin olanları işaretleyin';
	@override String get devicesOk => 'Tüm cihazlar biliniyor';
	@override String get devicesOkDetail => 'Hepsini onayladınız';
	@override String get camera => 'Bu ağda bir kamera var';
	@override String get dnsHijack => 'Bilinmeyen adlar yönlendiriliyor';
	@override String get dnsHijackDetail => 'Sağlayıcınız veya yönlendiriciniz sorguları değiştiriyor';
	@override String get dnsOk => 'DNS normal yanıt veriyor';
	@override String get dnsOkDetail => 'Yönlendirme belirtisi yok';
	@override String get vpnOn => 'VPN açık';
	@override String get vpnOnDetail => 'Trafik tünelden çıkıyor';
	@override String get vpnOff => 'VPN kapalı';
	@override String get vpnOffDetail => 'Sağlayıcınız her siteyi görüyor';
	@override String toFix({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: 'Düzeltilecek ${n} şey',
	);
	@override String upnpOpened({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: 'Cihazların açtığı ${n} port',
	);
	@override String portsChecked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} port kontrol edildi',
	);
	@override String notMine({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} cihaz sizin değil',
	);
	@override String confirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: 'Onaylanacak ${n} cihaz',
	);
}

// Path: providers
class _Translations$providers$tr extends Translations$providers$en {
	_Translations$providers$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get tab => 'İnternet';
	@override String get unavailable => 'Sağlayıcı listesi yüklenemedi. Bağlantınızı kontrol edin.';
	@override String get cached => 'VPN\'siz son kontrolünüze göre';
	@override String get notEnough => 'Henüz yeterli puan yok';
	@override String get yourRating => 'Bu ayki puanınız';
	@override String get yourSpeed => 'HIZINIZ';
	@override String get runTest => 'Hız testi yap';
	@override String get aboutAverage => 'Buradaki ortalama civarında';
	@override String aboveAverage({required Object pct}) => 'Yerel ortalamanın %${pct} üstünde';
	@override String belowAverage({required Object pct}) => 'Yerel ortalamanın %${pct} altında';
	@override String get call => 'Ara';
	@override String get website => 'Web sitesi';
	@override String get outages => 'Kesintiler';
	@override String get rate => 'Puanla';
	@override String get changeRating => 'Puanı değiştir';
	@override String get compare => 'Karşılaştır';
	@override String rateTitle({required Object name}) => '${name} sağlayıcısını puanla';
	@override String get oncePerMonth => 'Ayda bir puan';
	@override String get tapStars => 'Yıldızlara dokunun';
	@override String verified({required Object mbps}) => 'Hız testinizle doğrulandı: ${mbps} Mbps';
	@override String get busy => 'Buradan çok fazla puan geldi. Sonra deneyin.';
	@override String get failed => 'Gönderilemedi. Tekrar deneyin.';
	@override String get post => 'Puanı gönder';
	@override String get nearTitle => 'Yakınınızdaki sağlayıcılar';
	@override String slower({required Object pct}) => 'İndirme hızınız sağlayıcınızın buradaki ortalamasının %${pct} altında';
	@override String inPlace({required Object place}) => '${place} ev interneti';
	@override String get byRating => 'Puan';
	@override String get bySpeed => 'Hız';
	@override String get footnote => 'Hızlar G VPN hız testlerinin ortalamasıdır';
	@override String get noneNearby => 'Yakında henüz puan yok. İlk siz olun.';
	@override String get you => 'Siz';
	@override String get topRated => 'En yüksek puanlı';
	@override String starsOf({required Object n}) => '5 üzerinden ${n}';
	@override late final _Translations$providers$tags$tr tags = _Translations$providers$tags$tr._(_root);
	@override late final _Translations$providers$words$tr words = _Translations$providers$words$tr._(_root);
	@override String ratings({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} puan',
	);
}

// Path: alerts
class _Translations$alerts$tr extends Translations$alerts$en {
	_Translations$alerts$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get channel => 'Uyarılar';
	@override String get title => 'Uyarılar';
	@override String get markAllRead => 'Tümünü okundu yap';
	@override String get clearAll => 'Tümünü temizle';
	@override String get thisNetwork => 'bu ağ';
	@override String openWifiTitle({required Object name}) => 'Açık bir Wi-Fi\'ye bağlandınız: ${name}';
	@override String get openWifiBody => 'Yakındaki herkes gönderilenleri görebilir. G VPN\'i açın.';
	@override String get reportTitle => 'Haftalık raporunuz hazır';
	@override String reportBody({required Object hours}) => 'Geçen hafta ${hours} saat korundunuz';
	@override String blockedTitle({required Object name}) => '${name} burada engelli';
	@override String get blockedBody => 'VPN üzerinden yanıt veriyor';
	@override late final _Translations$alerts$kinds$tr kinds = _Translations$alerts$kinds$tr._(_root);
	@override String newDeviceTitle({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${network} ağında ${n} yeni cihaz',
	);
	@override String get settings => 'Uyarı ayarları';
	@override String get look => 'Bak';
	@override String get read => 'Oku';
	@override String get open => 'Aç';
	@override String get check => 'Kontrol et';
	@override String get today => 'BUGÜN';
	@override String get thisWeek => 'BU HAFTA';
	@override String get earlier => 'DAHA ÖNCE';
	@override String get all => 'Tümü';
	@override String get quiet => 'Her şey sakin';
	@override String get quietSub => 'Son zamanlarda hiçbir şey size ihtiyaç duymadı';
	@override String breachTitle({required Object name}) => 'Yeni sızıntı: ${name}';
	@override late final _Translations$alerts$status$tr status = _Translations$alerts$status$tr._(_root);
}

// Path: report
class _Translations$report$tr extends Translations$report$en {
	_Translations$report$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Haftalık rapor';
	@override String get share => 'Görsel olarak paylaş';
	@override String get shareText => 'G VPN ile haftam';
	@override String get safer => 'Daha güvenli bir hafta';
	@override String get moreProtected => 'Geçen haftadan daha korunaklı';
	@override String get yourWeek => 'Haftanız';
	@override String soFar({required Object range}) => '${range}, şu ana kadar';
	@override String get protected => 'Korunan';
	@override String get data => 'Veri';
	@override String get security => 'Güvenlik';
	@override String get speed => 'En iyi hız';
	@override String get noScore => 'Kontrol edilmedi';
	@override String get noTest => 'Test yok';
	@override String get bestDirect => 'Doğrudan test';
	@override String moreThan({required Object d}) => 'Geçen haftadan ${d} fazla';
	@override String lessThan({required Object d}) => 'Geçen haftadan ${d} az';
	@override String get protectedTime => 'KORUNAN SÜRE';
	@override String mostUsed({required Object name}) => 'En çok kullanılan: ${name}';
	@override String get quiet => 'Sakin bir hafta: hiçbir şey size ihtiyaç duymadı';
	@override String newDevices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} yeni cihaz katıldı',
	);
	@override String openWifi({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} açık Wi-Fi\'ye bağlandınız',
	);
	@override String blocked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} uygulama engellendi',
	);
	@override String breaches({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} büyük yeni sızıntı',
	);
}

// Path: breaches
class _Translations$breaches$tr extends Translations$breaches$en {
	_Translations$breaches$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Veri sızıntıları';
	@override String get info => 'Have I Been Pwned\'ın herkese açık listesinden en yeni veri sızıntıları. Sizinle ilgili hiçbir şey gönderilmez: liste herkes için aynıdır.\n\nSızdırılan bir sitede hesabınız varsa o parolayı ve aynısını kullandığınız her yerde değiştirin.';
	@override String get unavailable => 'Liste yüklenemedi. Bağlantınızı kontrol edin.';
	@override String get biggest => 'BU AYIN EN BÜYÜĞÜ';
	@override String get newest => 'En yeni';
	@override String get biggestSort => 'En büyük';
	@override String get withPasswords => 'Parola içeren';
	@override String get passwordsMark => 'PAROLALAR';
	@override String get one => 'Sızıntı';
	@override String get checkPassword => 'Bir parolayı kontrol et';
	@override String get verified => 'Doğrulanmış';
	@override String get hasPasswords => 'Parola içeriyor';
	@override String get accountsLabel => 'Hesaplar';
	@override String get happened => 'Gerçekleşti';
	@override String get published => 'Yayımlandı';
	@override String get website => 'Web sitesi';
	@override String get leaked => 'NE SIZDI';
	@override String get ifUsed => 'KULLANDIYSANIZ';
	@override String get stepPassword => 'Orada kullandığınız parolayı değiştirin';
	@override String get stepReuse => 'Aynısını kullandığınız her yerde değiştirin';
	@override String get stepTwoStep => 'Mümkünse iki adımlı girişi açın';
	@override String get stepScams => 'Dolandırıcı arama ve mesajlarına hazırlıklı olun';
	@override String accounts({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${count} hesap',
	);
	@override String worldwide({required Object n}) => 'Dünya geneli · ${n}';
	@override String get noneHere => 'Son listede buradan sızıntı yok.';
	@override String get bigMap => 'Daha büyük harita';
	@override String get showInList => 'Listede göster';
	@override String get mapTitle => 'Sızıntı haritası';
	@override String get zoomIn => 'Yakınlaştır';
	@override String get zoomOut => 'Uzaklaştır';
	@override String get wholeWorld => 'Tüm dünya';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} sızıntı',
	);
	@override String get findCountry => 'Bir ülke bul';
	@override String get seeAll => 'Tümünü gör';
	@override String get search => 'Sızıntılarda ara';
}

// Path: blocked
class _Translations$blocked$tr extends Translations$blocked$en {
	_Translations$blocked$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ne engelli';
	@override String get info => 'Bilinen siteleri bu telefondan VPN olmadan dener ve bu ağın hangilerini nasıl engellediğini gösterir.\n\nYanlış adres: ağın ad sorgusu yanlış yanıt verir.\n\nKesildi: bağlantı başlarken kesilir.\n\nYanıt yok: hiçbir şey dönmez.\n\nEngel sayfası: sitenin yerine başka bir şey yanıt verir.\n\nTest bir sitenin nerede engellendiğini gösterir, kimin engellediğini değil. Hiçbir şey kaydedilmez veya gönderilmez.';
	@override String get thisNetwork => 'Bu ağ';
	@override String get country => 'Ülkeniz';
	@override String get question => 'Burada ne engelli?';
	@override String get testingOn => 'TEST EDİLEN';
	@override String get vpnOn => 'VPN AÇIK';
	@override String get turnOff => 'Test için G VPN\'i kapatın';
	@override String get test => 'Bu ağı test et';
	@override String get stop => 'Durdur';
	@override String sitesToTest({required Object n}) => 'TEST EDİLECEK SİTELER · ${n}';
	@override String ofSites({required Object n}) => '${n} siteden';
	@override String blockedCount({required Object n}) => '${n} ENGELLİ';
	@override String openCount({required Object n}) => '${n} AÇIK';
	@override String noneBlocked({required Object network}) => '${network} üzerinde engelli bir şey yok';
	@override String openOf({required Object total, required Object open}) => '${total} siteden ${open} açık';
	@override String get allWork => 'HEPSİ G VPN İLE ÇALIŞIYOR';
	@override String get blockedHeading => 'ENGELLİ';
	@override String get byKind => 'TÜRE GÖRE';
	@override String get worksVpn => 'VPN ile çalışıyor';
	@override String get failsVpn => 'VPN ile de engelli';
	@override String get checkVpn => 'G VPN üzerinden kontrol et';
	@override String get connect => 'G VPN\'e bağlan';
	@override String get again => 'Tekrar test et';
	@override String get withoutVpn => 'VPN OLMADAN';
	@override String get throughVpn => 'G VPN ÜZERİNDEN';
	@override String get notChecked => 'Kontrol edilmedi';
	@override String get opens => 'Açılıyor';
	@override String get stillBlocked => 'Engelli';
	@override String get whatHappened => 'NE OLDU';
	@override String countryBlocked({required Object country}) => '${country} ülkesinde engelli site';
	@override String get countrySub => 'Gönüllü testlerinin son 30 günde bulduğu';
	@override String get countryNone => 'Son 30 günde bildirilen engelli site yok.';
	@override String get countryUnavailable => 'Ülke sonuçları yüklenemedi. Bağlantınızı kontrol edin.';
	@override String get confirmed => 'ENGELLİ';
	@override String get oftenFails => 'SIK HATA';
	@override late final _Translations$blocked$kinds$tr kinds = _Translations$blocked$kinds$tr._(_root);
	@override late final _Translations$blocked$how$tr how = _Translations$blocked$how$tr._(_root);
	@override late final _Translations$blocked$fail$tr fail = _Translations$blocked$fail$tr._(_root);
	@override late final _Translations$blocked$steps$tr steps = _Translations$blocked$steps$tr._(_root);
	@override late final _Translations$blocked$consent$tr consent = _Translations$blocked$consent$tr._(_root);
	@override String someBlocked({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${network} üzerinde ${n} site engelli',
	);
	@override String tests({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n,
		other: '${n} test',
	);
}

// Path: home.status
class _Translations$home$status$tr extends Translations$home$status$en {
	_Translations$home$status$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get paused => 'Duraklatıldı';
	@override String get reconnecting => 'Yeniden bağlanıyor';
	@override String get protected => 'Korunuyor';
	@override String get connecting => 'Bağlanıyor';
	@override String get stopping => 'Durduruluyor';
	@override String get notProtected => 'Korunmuyor';
}

// Path: home.network
class _Translations$home$network$tr extends Translations$home$network$en {
	_Translations$home$network$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'BU AĞ';
	@override String get wifi => 'Wi-Fi';
	@override String get offline => 'Çevrimdışı';
	@override String get showName => 'Adı göster';
	@override String get scanFailed => 'Tarama başarısız. Ağ değiştiğinde tekrar çalışır.';
}

// Path: home.card
class _Translations$home$card$tr extends Translations$home$card$en {
	_Translations$home$card$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get downloaded => 'İNDİRİLEN';
	@override String get uploaded => 'YÜKLENEN';
	@override String get wireguard => 'WireGuard';
	@override String openvpn({required Object proto}) => 'OpenVPN ${proto}';
	@override String get selected => 'SEÇİLİ';
	@override String get browsingFrom => 'BURADAN GEZİNİYORSUNUZ';
	@override String get disconnect => 'Bağlantıyı kes';
	@override String get change => 'Değiştir';
	@override String get enabled => 'Açık';
	@override String get shield => 'KALKAN';
}

// Path: home.tiles
class _Translations$home$tiles$tr extends Translations$home$tiles$en {
	_Translations$home$tiles$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get shield => 'Kalkan';
	@override String get appsDirect => 'Doğrudan uygulamalar';
	@override String get appsAll => 'Tüm uygulamalar korunuyor';
	@override String appsSkip({required Object n}) => '${n} uygulama VPN dışı';
	@override String get autoConnect => 'Otomatik bağlan';
	@override String get autoOpen => 'Genel Wi-Fi\'de';
	@override String get autoAny => 'Her Wi-Fi\'de';
	@override String get speed => 'Hız';
	@override String get speedTap => 'Test için dokunun';
	@override String speedDirect({required Object mbps}) => 'Doğrudan ${mbps} Mbps';
}

// Path: home.fastest
class _Translations$home$fastest$tr extends Translations$home$fastest$en {
	_Translations$home$fastest$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'En hızlı ücretsiz sunucu';
	@override String get pickedFrom => 'Şunlardan seçildi';
	@override String more({required Object n}) => '+${n}';
	@override String get finding => 'En hızlı sunucu aranıyor';
	@override String get failed => 'Ücretsiz sunucular yüklenemedi';
	@override String get how => 'Sunucu nasıl seçilir';
	@override String get sheetBody => 'G VPN sizi şu anda hız, yük ve kesintisiz çalışma süresine göre en iyi sıradaki ücretsiz sunucuya bağlar. Sunucular gelip gittikçe sıralama değişir.';
}

// Path: home.ip
class _Translations$home$ip$tr extends Translations$home$ip$en {
	_Translations$home$ip$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sitelerin gördüğü';
	@override String get real => 'Gerçek konumunuz';
	@override String get vpn => 'VPN konumu';
	@override String get address => 'IP adresi';
	@override String get coordinates => 'Koordinatlar';
	@override String get note => 'IP adresinizden tahmin edilir. Asla saklanmaz.';
	@override String get hide => 'Konumumu gizle';
	@override String near({required Object place}) => '${place} yakınında';
}

// Path: servers.tabs
class _Translations$servers$tabs$tr extends Translations$servers$tabs$en {
	_Translations$servers$tabs$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get pro => 'Pro';
	@override String get free => 'Ücretsiz';
	@override String get yours => 'Sizinkiler';
}

// Path: servers.sheet
class _Translations$servers$sheet$tr extends Translations$servers$sheet$en {
	_Translations$servers$sheet$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sunucular nereden geliyor';
	@override String get subtitle => 'Üç tür, tek liste';
	@override String get free => 'Gönüllü sunucular, iki saatte bir kontrol edilir. İşletmecileri bağlantı kayıtlarını yaklaşık iki hafta saklar.';
	@override String get pro => 'WireGuard ile bizim işlettiğimiz sunucular. Etkinlik kaydı yok, hesap yok.';
	@override String get yours => 'Çalıştırdığınız herhangi bir WireGuard sunucusu: modem, VPS veya ev sunucusu.';
}

// Path: servers.badges
class _Translations$servers$badges$tr extends Translations$servers$badges$en {
	_Translations$servers$badges$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get mostUsed => 'EN ÇOK KULLANILAN';
	@override String get mostStable => 'EN KARARLI';
	@override String get fastest => 'EN HIZLI';
}

// Path: servers.filters
class _Translations$servers$filters$tr extends Translations$servers$filters$en {
	_Translations$servers$filters$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get all => 'Tümü';
	@override String get fastest => 'En hızlı';
	@override String get stable => 'En kararlı';
	@override String get popular => 'Popüler';
}

// Path: servers.own
class _Translations$servers$own$tr extends Translations$servers$own$en {
	_Translations$servers$own$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kendi sunucunuzu çalıştırın';
	@override String get subtitle => 'Her WireGuard sunucusu çalışır';
	@override String get router => 'Modem';
	@override String get routerBody => 'Birçok modemde WireGuard yerleşiktir. İstemci yapılandırmasını dışa aktarın ve QR kodunu burada tarayın.';
	@override String get vps => 'VPS';
	@override String get vpsBody => 'Herhangi bir küçük Linux sunucusu. WireGuard\'ı kurun, bir istemci oluşturun ve yapılandırma dosyasını içe aktarın.';
	@override String get home => 'Ev sunucusu';
	@override String get homeBody => 'Kendi ağınıza aynı şekilde her yerden ulaşın.';
	@override String get noneYet => 'Henüz sunucunuz yok mu?';
	@override String get addAnother => 'Bir tane daha ekle';
	@override String get hint => 'Modem, VPS veya ev sunucusunda çalıştırın';
}

// Path: pro.free
class _Translations$pro$free$tr extends Translations$pro$free$en {
	_Translations$pro$free$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Planınız';
	@override String get headline => 'Her şey ücretsiz';
	@override String get body => 'Tüm sunucular ve tüm araçlar; hesap yok, reklam yok.';
	@override String get included => 'İçerik';
	@override String get servers => 'Ücretsiz sunucular';
	@override String get serversSub => 'Onlarca ülkede hız ve kararlılığa göre sıralanır';
	@override String get own => 'Kendi sunucularınız';
	@override String get ownSub => 'Herhangi bir WireGuard modem, VPS veya ev sunucusuna bağlanın';
	@override String get shield => 'Kalkan';
	@override String get shieldSub => 'Bilinen zararlı yazılım ve kimlik avı sitelerini engeller';
	@override String get auto => 'Otomatik bağlanma ve uygulama kuralları';
	@override String get autoSub => 'Genel Wi-Fi\'yi koruyun; banka uygulamaları doğrudan bağlansın';
	@override String get pause => 'Duraklatma ve Hızlı Ayarlar';
	@override String get pauseSub => 'Bildirimden duraklatın, kutucuktan açıp kapatın';
	@override String get tools => 'Tüm ağ araçları';
	@override String get toolsSub => 'Hız testi, ping, servis durumu, traceroute, cihazlar ve daha fazlası';
	@override String get later => 'G VPN Pro, bizim işlettiğimiz daha hızlı sunucular ekleyecek. Yukarıdaki her şey ücretsiz kalır.';
}

// Path: rules.info
class _Translations$rules$info$tr extends Translations$rules$info$en {
	_Translations$rules$info$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get shield => 'Kalkan, bağlıyken DNS sorgularını süzer: Quad9 kötü amaçlı yazılımı ve oltalamayı engeller, Cloudflare for Families yetişkin sitelerini de engeller ya da kendi DNS\'inizi kullanın. Reklamları asla engellemez.';
	@override String get autoConnect => 'Otomatik bağlanma: seçtiğiniz WireGuard sunucusunu kullanır. Elle bağlantıyı kesmek, başka bir ağa katılana kadar onu duraklatır.';
	@override String get apps => 'Doğrudan uygulamalar: VPN dışında kalan uygulamalar doğrudan bağlanır. Bankalar VPN adreslerini sık sık engeller, bu yüzden VPN üzerinden ödemeler başarısız olabilir.';
	@override String get reconnect => 'Kalkanı veya uygulamaları değiştirmek VPN\'i kısa süreliğine yeniden bağlar.';
	@override String get stay => 'Bağlı kal: bazı telefonlar pil tasarrufu için arka plandaki uygulamaları durdurur. Her zaman açık VPN ve kısıtlamasız pil ayarı G VPN\'in çalışmasını sağlar.';
}

// Path: devices.kinds
class _Translations$devices$kinds$tr extends Translations$devices$kinds$en {
	_Translations$devices$kinds$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get phone => 'Telefon';
	@override String get computer => 'Bilgisayar';
	@override String get tv => 'TV';
	@override String get speaker => 'Hoparlör';
	@override String get printer => 'Yazıcı';
	@override String get camera => 'Kamera';
	@override String get smartHome => 'Akıllı ev';
	@override String get router => 'Yönlendirici';
	@override String get unknown => 'Tanıtılmadı';
}

// Path: map.grade
class _Translations$map$grade$tr extends Translations$map$grade$en {
	_Translations$map$grade$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get fast => 'Hızlı';
	@override String get good => 'İyi';
	@override String get slow => 'Yavaş';
}

// Path: presets.names
class _Translations$presets$names$tr extends Translations$presets$names$en {
	_Translations$presets$names$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get fastest => 'En hızlı';
	@override String get unblock => 'Engel aş';
	@override String get streaming => 'Yayın';
	@override String get privacy => 'En yüksek gizlilik';
}

// Path: providers.tags
class _Translations$providers$tags$tr extends Translations$providers$tags$en {
	_Translations$providers$tags$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get fast => 'Hızlı';
	@override String get reliable => 'Güvenilir';
	@override String get support => 'İyi destek';
	@override String get price => 'Makul fiyat';
	@override String get slowEvenings => 'Akşamları yavaş';
	@override String get drops => 'Sık kopuyor';
	@override String get poorSupport => 'Kötü destek';
	@override String get pricey => 'Pahalı';
}

// Path: providers.words
class _Translations$providers$words$tr extends Translations$providers$words$en {
	_Translations$providers$words$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get bad => 'Kötü';
	@override String get poor => 'Zayıf';
	@override String get okay => 'İdare eder';
	@override String get good => 'İyi';
	@override String get great => 'Harika';
}

// Path: alerts.kinds
class _Translations$alerts$kinds$tr extends Translations$alerts$kinds$en {
	_Translations$alerts$kinds$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get newDevice => 'Wi-Fi\'mdaki yeni cihazlar';
	@override String get openWifi => 'Açık veya zayıf Wi-Fi';
	@override String get blocked => 'Engelli uygulamalar';
	@override String get report => 'Haftalık rapor';
	@override String get breach => 'Sızıntılar';
}

// Path: alerts.status
class _Translations$alerts$status$tr extends Translations$alerts$status$en {
	_Translations$alerts$status$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get background => 'Birkaç saatte bir';
	@override String checked({required Object time}) => '${time} itibarıyla kontrol edildi';
	@override String get wifi => 'Bağlandığınız her ağ';
	@override String get blocked => 'Hizmet durumu çalıştığında';
	@override String get report => 'Her pazartesi';
}

// Path: blocked.kinds
class _Translations$blocked$kinds$tr extends Translations$blocked$kinds$en {
	_Translations$blocked$kinds$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get social => 'Sosyal';
	@override String get messaging => 'Mesajlaşma';
	@override String get news => 'Haber';
	@override String get video => 'Video ve müzik';
	@override String get privacy => 'Gizlilik araçları';
}

// Path: blocked.how
class _Translations$blocked$how$tr extends Translations$blocked$how$en {
	_Translations$blocked$how$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get dns => 'Yanlış adres';
	@override String get reset => 'Kesildi';
	@override String get timeout => 'Yanıt yok';
	@override String get page => 'Engel sayfası';
	@override String get open => 'Açık';
}

// Path: blocked.fail
class _Translations$blocked$fail$tr extends Translations$blocked$fail$en {
	_Translations$blocked$fail$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get noAnswer => 'yanıt yok';
	@override String get refused => 'reddedildi';
	@override String cutOff({required Object s}) => '${s} sn sonra kesildi';
	@override String get wrongCert => 'yanlış sertifika';
}

// Path: blocked.steps
class _Translations$blocked$steps$tr extends Translations$blocked$steps$en {
	_Translations$blocked$steps$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get lookup => 'Ad sorgusu';
	@override String get connect => 'Bağlantı';
	@override String get handshake => 'Güvenli el sıkışma';
}

// Path: blocked.consent
class _Translations$blocked$consent$tr extends Translations$blocked$consent$en {
	_Translations$blocked$consent$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'İlk testten önce';
	@override String get body => 'Test her siteyi bu telefondan, VPN olmadan, bir tarayıcı gibi açar.';
	@override String get noticeTitle => 'Fark edilebilir';
	@override String get notice => 'Sağlayıcınız bu sitelerin açıldığını görür. Bazı ülkelerde test için bile ziyaret etmek dikkat çekebilir. Yalnızca kendinizi güvende hissettiğiniz yerde test edin.';
	@override String get ok => 'Anladım, test et';
}

/// The flat map containing all translations for locale <tr>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsTr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.gotIt' => 'Anladım',
			'common.about' => 'Hakkında',
			'common.connect' => 'Bağlan',
			'common.connected' => 'Bağlı',
			'common.retry' => 'Tekrar dene',
			'common.ok' => 'Tamam',
			'common.remove' => 'Kaldır',
			'common.cancel' => 'İptal',
			'common.continueLabel' => 'Devam',
			'common.notNow' => 'Şimdi değil',
			'common.openSettings' => 'Ayarları aç',
			'common.close' => 'Kapat',
			'common.off' => 'Kapalı',
			'common.changesReconnect' => 'Değişiklikler VPN\'i yeniden bağlar',
			'nav.vpn' => 'VPN',
			'nav.servers' => 'Sunucular',
			'nav.tools' => 'Araçlar',
			'nav.rules' => 'Kurallar',
			'nav.pro' => 'Pro',
			'home.status.paused' => 'Duraklatıldı',
			'home.status.reconnecting' => 'Yeniden bağlanıyor',
			'home.status.protected' => 'Korunuyor',
			'home.status.connecting' => 'Bağlanıyor',
			'home.status.stopping' => 'Durduruluyor',
			'home.status.notProtected' => 'Korunmuyor',
			'home.resumesAt' => ({required Object time}) => '${time} itibarıyla devam eder · şimdi devam etmek için dokunun',
			'home.ipFailed' => 'IP adresiniz kontrol edilemedi',
			'home.ipChecking' => 'IP adresiniz kontrol ediliyor',
			'home.themeSystem' => 'Tema: telefonu izle',
			'home.themeLight' => 'Tema: açık',
			'home.themeDark' => 'Tema: koyu',
			'home.free' => 'Ücretsiz',
			'home.pickServer' => 'Bir sunucu seçin',
			'home.network.title' => 'BU AĞ',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Çevrimdışı',
			'home.network.showName' => 'Adı göster',
			'home.network.scanFailed' => 'Tarama başarısız. Ağ değiştiğinde tekrar çalışır.',
			'home.card.downloaded' => 'İNDİRİLEN',
			'home.card.uploaded' => 'YÜKLENEN',
			'home.card.wireguard' => 'WireGuard',
			'home.card.openvpn' => ({required Object proto}) => 'OpenVPN ${proto}',
			'home.card.selected' => 'SEÇİLİ',
			'home.card.browsingFrom' => 'BURADAN GEZİNİYORSUNUZ',
			'home.card.disconnect' => 'Bağlantıyı kes',
			'home.card.change' => 'Değiştir',
			'home.card.enabled' => 'Açık',
			'home.card.shield' => 'KALKAN',
			'home.tiles.shield' => 'Kalkan',
			'home.tiles.appsDirect' => 'Doğrudan uygulamalar',
			'home.tiles.appsAll' => 'Tüm uygulamalar korunuyor',
			'home.tiles.appsSkip' => ({required Object n}) => '${n} uygulama VPN dışı',
			'home.tiles.autoConnect' => 'Otomatik bağlan',
			'home.tiles.autoOpen' => 'Genel Wi-Fi\'de',
			'home.tiles.autoAny' => 'Her Wi-Fi\'de',
			'home.tiles.speed' => 'Hız',
			'home.tiles.speedTap' => 'Test için dokunun',
			'home.tiles.speedDirect' => ({required Object mbps}) => 'Doğrudan ${mbps} Mbps',
			'home.fastest.title' => 'En hızlı ücretsiz sunucu',
			'home.fastest.pickedFrom' => 'Şunlardan seçildi',
			'home.fastest.more' => ({required Object n}) => '+${n}',
			'home.fastest.finding' => 'En hızlı sunucu aranıyor',
			'home.fastest.failed' => 'Ücretsiz sunucular yüklenemedi',
			'home.fastest.how' => 'Sunucu nasıl seçilir',
			'home.fastest.sheetBody' => 'G VPN sizi şu anda hız, yük ve kesintisiz çalışma süresine göre en iyi sıradaki ücretsiz sunucuya bağlar. Sunucular gelip gittikçe sıralama değişir.',
			'home.ip.title' => 'Sitelerin gördüğü',
			'home.ip.real' => 'Gerçek konumunuz',
			'home.ip.vpn' => 'VPN konumu',
			'home.ip.address' => 'IP adresi',
			'home.ip.coordinates' => 'Koordinatlar',
			'home.ip.note' => 'IP adresinizden tahmin edilir. Asla saklanmaz.',
			'home.ip.hide' => 'Konumumu gizle',
			'home.ip.near' => ({required Object place}) => '${place} yakınında',
			'servers.title' => 'Sunucular',
			'servers.aboutServers' => 'Sunucular hakkında',
			'servers.tabs.pro' => 'Pro',
			'servers.tabs.free' => 'Ücretsiz',
			'servers.tabs.yours' => 'Sizinkiler',
			'servers.sheet.title' => 'Sunucular nereden geliyor',
			'servers.sheet.subtitle' => 'Üç tür, tek liste',
			'servers.sheet.free' => 'Gönüllü sunucular, iki saatte bir kontrol edilir. İşletmecileri bağlantı kayıtlarını yaklaşık iki hafta saklar.',
			'servers.sheet.pro' => 'WireGuard ile bizim işlettiğimiz sunucular. Etkinlik kaydı yok, hesap yok.',
			'servers.sheet.yours' => 'Çalıştırdığınız herhangi bir WireGuard sunucusu: modem, VPS veya ev sunucusu.',
			'servers.badges.mostUsed' => 'EN ÇOK KULLANILAN',
			'servers.badges.mostStable' => 'EN KARARLI',
			'servers.badges.fastest' => 'EN HIZLI',
			'servers.filters.all' => 'Tümü',
			'servers.filters.fastest' => 'En hızlı',
			'servers.filters.stable' => 'En kararlı',
			'servers.filters.popular' => 'Popüler',
			'servers.loadFailed' => 'Liste yüklenemedi',
			'servers.noServers' => 'Şu anda sunucu yok',
			'servers.best' => 'ŞU AN SİZİN İÇİN EN İYİSİ',
			'servers.topRanked' => 'Şu an en üst sırada',
			'servers.addHeading' => 'SUNUCU EKLE',
			'servers.scanQr' => 'QR tara',
			'servers.importFile' => 'Dosya içe aktar',
			'servers.paste' => 'Yapıştır',
			'servers.own.title' => 'Kendi sunucunuzu çalıştırın',
			'servers.own.subtitle' => 'Her WireGuard sunucusu çalışır',
			'servers.own.router' => 'Modem',
			'servers.own.routerBody' => 'Birçok modemde WireGuard yerleşiktir. İstemci yapılandırmasını dışa aktarın ve QR kodunu burada tarayın.',
			'servers.own.vps' => 'VPS',
			'servers.own.vpsBody' => 'Herhangi bir küçük Linux sunucusu. WireGuard\'ı kurun, bir istemci oluşturun ve yapılandırma dosyasını içe aktarın.',
			'servers.own.home' => 'Ev sunucusu',
			'servers.own.homeBody' => 'Kendi ağınıza aynı şekilde her yerden ulaşın.',
			'servers.own.noneYet' => 'Henüz sunucunuz yok mu?',
			'servers.own.addAnother' => 'Bir tane daha ekle',
			'servers.own.hint' => 'Modem, VPS veya ev sunucusunda çalıştırın',
			'servers.configBroken' => 'Yapılandırma kontrol edilmeli',
			'servers.connectedBadge' => 'BAĞLI',
			'servers.scannedServer' => 'Taranan sunucu',
			'servers.scanFailedTitle' => 'Taranamadı',
			'servers.scanFailedBody' => 'Tarayıcı bu telefonda kullanılamıyor.',
			'servers.importFailedTitle' => 'İçe aktarılamadı',
			'servers.importFailedBody' => 'Bu dosya okunamadı.',
			'servers.renameTitle' => 'Sunucuyu yeniden adlandır',
			'servers.nameHint' => 'Ad, örneğin Ev modemi',
			'servers.save' => 'Kaydet',
			'servers.rename' => 'Yeniden adlandır',
			'servers.disconnect' => 'Bağlantıyı kes',
			'servers.more' => 'Diğer seçenekler',
			'servers.justNow' => 'az önce',
			'servers.minutesAgo' => ({required Object n}) => '${n} dk önce',
			'servers.hoursAgo' => ({required Object n}) => '${n} sa önce',
			'servers.daysAgo' => ({required Object n}) => '${n} gün önce',
			'servers.neverUsed' => 'Henüz kullanılmadı',
			'servers.lastUsed' => ({required Object when}) => 'Son kullanım ${when}',
			'servers.disconnectFirst' => 'Kaldırmak için önce bağlantıyı kesin',
			'servers.removeConfirm' => 'Bu sunucu G VPN\'den kaldırılsın mı? Ayarları bu telefondan silinir; sunucunun kendisi değişmez.',
			'servers.gTab' => 'G Servers',
			'servers.search' => 'Ülke ara',
			'servers.noMatch' => 'Eşleşen sunucu yok.',
			'servers.bestPing' => ({required Object ms}) => 'en iyi ${ms} ms',
			'servers.bestTag' => 'EN İYİ',
			'servers.ownHero' => 'Kendi sunucularımız',
			'servers.ownHeroSub' => 'Daha hızlı, özel, her telefonun kendi anahtarı var',
			'servers.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} sunucu', ), 
			'servers.showAll' => ({required Object n}) => '${n} sunucunun tümü',
			'servers.showFewer' => 'Daha az göster',
			'servers.fastTab' => 'Hızlı',
			'servers.fastestFree' => 'En hızlı ücretsiz',
			'pro.owned' => 'Pro\'nuz var',
			'pro.waitingPlay' => 'Google Play bekleniyor',
			'pro.startTrial' => ({required Object days}) => '${days} günlük ücretsiz denemeyi başlat',
			'pro.restore' => 'Geri yükle',
			'pro.save' => ({required Object pct}) => '%${pct} TASARRUF',
			'pro.yearly' => 'Yıllık',
			'pro.monthly' => 'Aylık',
			'pro.billedMonthly' => 'aylık faturalandırılır',
			'pro.daysFree' => ({required Object days}) => '${days} gün ücretsiz',
			'pro.perMonth' => ({required Object price}) => 'Ayda ${price}',
			'pro.title' => 'G VPN Pro',
			'pro.renewGeneric' => 'Abonelikler iptal edilene kadar otomatik yenilenir. Google Play\'den istediğiniz zaman iptal edin.',
			'pro.renewTrial' => ({required Object days, required Object period, required Object price}) => '${days} gün ücretsiz, ardından her ${period} için ${price}. İptal edilene kadar otomatik yenilenir; ücret alınmaması için deneme bitmeden en az bir gün önce Google Play\'den iptal edin.',
			'pro.renew' => ({required Object period, required Object price}) => 'Her ${period} için ${price}. İptal edilene kadar otomatik yenilenir; Google Play\'den istediğiniz zaman iptal edin.',
			'pro.year' => 'yıl',
			'pro.month' => 'ay',
			'pro.manage' => 'Aboneliği yönet',
			'pro.free.title' => 'Planınız',
			'pro.free.headline' => 'Her şey ücretsiz',
			'pro.free.body' => 'Tüm sunucular ve tüm araçlar; hesap yok, reklam yok.',
			'pro.free.included' => 'İçerik',
			'pro.free.servers' => 'Ücretsiz sunucular',
			'pro.free.serversSub' => 'Onlarca ülkede hız ve kararlılığa göre sıralanır',
			'pro.free.own' => 'Kendi sunucularınız',
			'pro.free.ownSub' => 'Herhangi bir WireGuard modem, VPS veya ev sunucusuna bağlanın',
			'pro.free.shield' => 'Kalkan',
			'pro.free.shieldSub' => 'Bilinen zararlı yazılım ve kimlik avı sitelerini engeller',
			'pro.free.auto' => 'Otomatik bağlanma ve uygulama kuralları',
			'pro.free.autoSub' => 'Genel Wi-Fi\'yi koruyun; banka uygulamaları doğrudan bağlansın',
			'pro.free.pause' => 'Duraklatma ve Hızlı Ayarlar',
			'pro.free.pauseSub' => 'Bildirimden duraklatın, kutucuktan açıp kapatın',
			'pro.free.tools' => 'Tüm ağ araçları',
			'pro.free.toolsSub' => 'Hız testi, ping, servis durumu, traceroute, cihazlar ve daha fazlası',
			'pro.free.later' => 'G VPN Pro, bizim işlettiğimiz daha hızlı sunucular ekleyecek. Yukarıdaki her şey ücretsiz kalır.',
			'pro.heroLine' => 'Kendi hızlı sunucularımız ve sınırsız her kontrol',
			'pro.start' => 'Pro\'yu başlat',
			'pro.compareFree' => 'ÜCRETSİZ',
			'pro.comparePro' => 'PRO',
			'pro.rowFreeServers' => 'Ücretsiz sunucular',
			'pro.rowTools' => 'Hız testi, araçlar, Wi-Fi kontrolleri',
			'pro.rowGServers' => 'G Servers, kayıt yok',
			'pro.rowLinks' => 'Bağlantı kontrolü',
			'pro.linksFree' => ({required Object n}) => 'Ayda ${n}',
			'pro.unlimited' => 'Sınırsız',
			'rules.title' => 'Kurallar',
			'rules.info.shield' => 'Kalkan, bağlıyken DNS sorgularını süzer: Quad9 kötü amaçlı yazılımı ve oltalamayı engeller, Cloudflare for Families yetişkin sitelerini de engeller ya da kendi DNS\'inizi kullanın. Reklamları asla engellemez.',
			'rules.info.autoConnect' => 'Otomatik bağlanma: seçtiğiniz WireGuard sunucusunu kullanır. Elle bağlantıyı kesmek, başka bir ağa katılana kadar onu duraklatır.',
			'rules.info.apps' => 'Doğrudan uygulamalar: VPN dışında kalan uygulamalar doğrudan bağlanır. Bankalar VPN adreslerini sık sık engeller, bu yüzden VPN üzerinden ödemeler başarısız olabilir.',
			'rules.info.reconnect' => 'Kalkanı veya uygulamaları değiştirmek VPN\'i kısa süreliğine yeniden bağlar.',
			'rules.info.stay' => 'Bağlı kal: bazı telefonlar pil tasarrufu için arka plandaki uygulamaları durdurur. Her zaman açık VPN ve kısıtlamasız pil ayarı G VPN\'in çalışmasını sağlar.',
			'rules.protection' => 'Koruma',
			'rules.shield' => 'Kalkan',
			'rules.privateDns' => 'VPN olmadan Kalkan',
			'rules.privateDnsSub' => 'Özel DNS için dns.quad9.net\'i kopyala',
			'rules.privateDnsCopied' => 'dns.quad9.net kopyalandı',
			'rules.privateDnsHow' => 'Ayarları açın, Özel DNS\'i arayın, "Özel DNS sağlayıcı ana makine adı"nı seçin ve yapıştırın.',
			'rules.stay' => 'Bağlı kal',
			'rules.alwaysOn' => 'Her zaman açık VPN',
			'rules.alwaysOnSub' => 'G VPN durursa Android onu yeniden başlatır',
			'rules.battery' => 'Pil',
			'rules.batteryOk' => 'Kısıtlamasız',
			'rules.batteryRestricted' => 'Kısıtlı: arka planda durabilir',
			'rules.autoConnect' => 'Otomatik bağlan',
			'rules.autoOff' => 'Kapalı',
			'rules.autoOffSub' => 'Yalnızca dokunduğunuzda',
			'rules.autoOpen' => 'Genel Wi-Fi',
			'rules.autoOpenSub' => 'Açık, WEP veya giriş sayfalı ağlar',
			'rules.autoAny' => 'Her Wi-Fi',
			'rules.autoAnySub' => 'Herhangi bir Wi-Fi ağı',
			'rules.apps' => 'Uygulamalar',
			'rules.appsDirect' => 'Doğrudan uygulamalar',
			'rules.appsNone' => 'Tüm uygulamalar VPN kullanıyor',
			'rules.appsSome' => ({required Object n}) => '${n} uygulama VPN dışı',
			'rules.appearance' => 'Görünüm',
			'rules.themePhone' => 'Telefon',
			'rules.themeLight' => 'Açık',
			'rules.themeDark' => 'Koyu',
			'rules.about' => 'Hakkında',
			'apps.title' => 'Doğrudan uygulamalar',
			'apps.sheetSubtitle' => 'Seçilen uygulamalar VPN olmadan bağlanır. Diğer her şey korunmaya devam eder.',
			'apps.whyTitle' => 'Bir uygulama neden hariç tutulur',
			'apps.whyBody' => 'Bankalar ve ödeme uygulamaları VPN adreslerini sık sık engeller, bu yüzden VPN üzerinden ödemeler başarısız olabilir. Bazı yerel hizmetler yalnızca kendi ülkenizden çalışır.',
			'apps.favouritesBody' => 'Sık değiştirdiğiniz uygulamaları yıldızlayın; en üstte kalırlar.',
			'apps.whileConnected' => 'Bağlıyken',
			'apps.whileConnectedBody' => 'Bu listeyi değiştirmek VPN\'i kısa süreliğine yeniden bağlar.',
			'apps.search' => ({required Object n}) => '${n} uygulamada ara',
			'apps.skipping' => 'VPN dışı',
			'apps.skippingNone' => 'Yok. Tüm uygulamalar VPN üzerinden geçiyor.',
			'apps.protectAgain' => ({required Object app}) => '${app} uygulamasını yeniden koru',
			'apps.banking' => 'Banka ve ödemeler',
			'apps.bankingFound' => ({required Object n}) => 'VPN\'i engelleyebilecek ${n} uygulama bulundu',
			'apps.addAll' => 'Tümünü ekle',
			'apps.favourites' => 'Favoriler',
			'apps.all' => 'Tüm uygulamalar',
			'apps.found' => ({required Object n}) => '${n} bulundu',
			'apps.noMatch' => 'Eşleşen uygulama yok.',
			'apps.showAll' => ({required Object n}) => 'Tümünü göster (${n})',
			'apps.skips' => 'VPN dışı',
			'apps.unstar' => 'Favorilerden çıkar',
			'apps.star' => 'Favorilere ekle',
			'location.title' => 'Wi-Fi için konuma izin ver',
			'location.useHome' => 'Wi-Fi adınızı Ana ekranda gösterin',
			'location.useScan' => 'Yakındaki ağları ve kanalları tarayın',
			'location.private' => 'Bu telefonda kalır. Konumunuz asla toplanmaz.',
			'location.switchTitle' => 'Konumu açın',
			'location.switchBody' => 'Konum kapalıyken Android, Wi-Fi adlarını gizler',
			'addServer.clipboardEmpty' => 'Pano boş.',
			'addServer.title' => 'Sunucunuzu ekleyin',
			'addServer.body' => 'Modeminizden, VPS\'inizden veya ev sunucunuzdan bir WireGuard yapılandırması yapıştırın.',
			'addServer.nameHint' => 'Ad, örneğin Ev modemi',
			'addServer.paste' => 'Yapıştır',
			'addServer.save' => 'Sunucuyu kaydet',
			'addServer.notWireguard' => ({required Object error}) => 'Bu bir WireGuard yapılandırması değil: ${error}',
			'button.stop' => 'Durdur',
			'button.connecting' => 'Bağlanıyor',
			'button.stopping' => 'Durduruluyor',
			'button.connect' => 'Bağlan',
			'button.disconnect' => 'Bağlantıyı kes',
			'wol.info' => 'Ayarlarında Wake on LAN etkinse bu Wi-Fi\'deki bir bilgisayarı veya NAS\'ı açar. Telefonunuz aynı ağda olmalı; önce VPN\'i kapatın.',
			'wol.badMac' => 'Bu bir MAC adresi değil. Şuna benzer: AA:BB:CC:DD:EE:FF.',
			'wol.sent' => 'Uyandırma sinyali gönderildi. Cihaz bir dakika içinde açılmalı.',
			'wol.title' => 'Wake on LAN',
			'wol.mac' => 'MAC adresi',
			'wol.failed' => ({required Object error}) => 'Gönderilemedi: ${error}',
			'wol.computer' => 'Bilgisayar',
			'wol.pick' => 'Uyandırmak için bir cihaz seçin',
			'wol.waking' => ({required Object name}) => '${name} uyandırılıyor',
			'wol.yours' => 'CİHAZLARINIZ',
			'wol.wakeNamed' => ({required Object name}) => '${name} uyandır',
			'wol.removeHint' => 'Kaldırmak için cihaza basılı tutun',
			'wol.add' => 'CİHAZ EKLE',
			'wol.name' => 'Ad',
			'wol.saveWake' => 'Kaydet ve uyandır',
			'speed.download' => 'İndirme',
			'speed.upload' => 'Yükleme',
			'speed.finding' => 'Sunucu aranıyor',
			'speed.throughVpn' => 'VPN üzerinden',
			'speed.directNoVpn' => 'Doğrudan, VPN yok',
			'speed.title' => 'Hız testi',
			'speed.stop' => 'Durdur',
			'speed.start' => 'Testi başlat',
			'speed.again' => 'Tekrar test et',
			'speed.viaVpn' => 'VPN ile',
			'speed.direct' => 'Doğrudan',
			'speed.mbps' => 'Mbps',
			'speed.ping' => 'PING',
			'speed.vsDirect' => 'DOĞRUDANA GÖRE',
			'speed.compare' => 'Yakındaki sağlayıcılarla karşılaştır',
			'speed.compareSub' => 'Yalnızca hızları paylaşır, asla IP\'nizi değil',
			'speed.tierTv' => 'Büyük TV\'ler',
			'speed.tierLaptopLarge' => 'Büyük dizüstüler',
			'speed.tierTablet' => 'Tabletler ve dizüstüler',
			'speed.tierPhone' => 'Telefonlar',
			'speed.tierSmallPhone' => 'Küçük telefonlar',
			'speed.tierCalls' => 'Aramalar ve ses',
			'speed.messagingOnly' => 'Yalnızca mesajlaşma',
			'speed.videoQuality' => 'Video kalitesi',
			'speed.preview' => 'ÖNİZLEME',
			'speed.history' => 'Geçmiş',
			'speed.clear' => 'Temizle',
			'speed.viaVpnLower' => 'VPN ile',
			'speed.directLower' => 'doğrudan',
			'speed.gradeA' => 'Aynı anda birkaç 4K yayın ve görüntülü arama',
			'speed.gradeB' => 'HD yayın ve akıcı görüntülü aramalar',
			'speed.gradeC' => 'Tek HD yayın; yoğun saatlerde aramalar takılabilir',
			'speed.gradeD' => 'Gezinme ve mesajlaşma; video zorlanır',
			'speed.yourCountry' => 'ülkeniz',
			'speed.median' => 'Medyan indirme, son 30 gün',
			'speed.fromUsers' => 'Mbps · G VPN kullanıcılarının testlerinden',
			'speed.costLittle' => 'VPN hızı çok az düşürüyor',
			'speed.costNoticeable' => 'Doğrudana göre belirgin şekilde yavaş',
			'speed.costMuch' => 'Çok daha yavaş. Başka bir sunucu deneyin',
			'speed.ofDirect' => 'doğrudan hızınızın',
			'speed.none' => 'yok',
			'speed.ms' => ({required Object n}) => '${n} ms',
			'speed.previewTier' => ({required Object tier}) => 'ÖNİZLEME · ${tier}',
			'speed.streamsUpTo' => ({required Object tier, required Object who}) => '${tier} kalitesine kadar yayın · ${who}',
			'speed.today' => ({required Object time}) => 'Bugün, ${time}',
			'speed.tests' => ({required Object n}) => '${n} test',
			'speed.gradeVpn' => ({required Object label}) => 'VPN üzerinden ${label}',
			'speed.gradeIsp' => ({required Object isp, required Object label}) => '${isp} üzerinde ${label}',
			'speed.notEnough' => ({required Object isp}) => '${isp} için henüz yeterli test yok',
			'speed.yourProvider' => 'sağlayıcınız',
			'speed.rankLine' => ({required Object where, required Object isp, required Object of, required Object rank}) => '${where} bölgesinde ${isp}: ${of} sağlayıcı içinde ${rank}.',
			'speed.costLine' => ({required Object note, required Object mbps}) => '${note} · doğrudan ${mbps} Mbps',
			'speed.mbpsValue' => ({required Object v}) => '${v} Mbps',
			'speed.gradeExcellent' => 'Mükemmel',
			'speed.gradeVeryGood' => 'Çok iyi',
			'speed.gradeGood' => 'İyi',
			'speed.gradeFair' => 'Orta',
			'speed.gradeSlow' => 'Yavaş',
			'speed.gradeVerySlow' => 'Çok yavaş',
			'router.info' => 'Modeminize UPnP üzerinden cihazların internete kendi başlarına port açıp açamayacağını sorar ve açılanları listeler. Yalnızca okur, hiçbir şeyi değiştirmez. UPnP\'ye ihtiyaç duyan bir şey yoksa (bazı oyun konsolları ihtiyaç duyar), modem ayarlarından kapatmak daha güvenlidir.',
			'router.title' => 'Modem kontrolü',
			'router.asking' => 'Modeme soruluyor',
			'router.again' => 'Tekrar kontrol et',
			'router.check' => 'Modemi kontrol et',
			'router.off' => 'UPnP kapalı',
			'router.offBody' => 'Cihazlar kendi başlarına port açamaz.',
			'router.onBody' => 'Şu anda bunun üzerinden açık port yok.',
			'router.checkEach' => 'Her birini tanıdığınızdan emin olun.',
			'router.cgnat' => 'Paylaşılan sağlayıcı adresi: internetten erişilemez.',
			'router.noDescription' => 'Açıklama yok',
			'router.opened' => ({required Object n}) => 'Cihazların açtığı ${n} port',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} → ${host}',
			'router.upnpOn' => 'UPnP açık',
			'router.routerLabel' => 'Yönlendirici',
			'router.internetAddress' => 'İnternet adresi',
			'router.openedBy' => 'Cihazların açtıkları',
			'network.title' => 'Bu ağ',
			'network.wifi' => 'Wi-Fi',
			'network.mobile' => 'Mobil veri',
			'network.ethernet' => 'Ethernet',
			'network.offline' => 'Çevrimdışı',
			'network.risky' => 'Riskli ağ. Burada VPN\'i bağlayın.',
			'network.review' => 'Güvenmeden önce göz atmaya değer.',
			'network.covered' => 'VPN ile korunuyor.',
			'network.safe' => 'Bu ağ güvenli görünüyor.',
			'network.mobileSentence' => 'Mobil veri.',
			'network.notConnected' => 'Bağlı değil.',
			'network.showName' => 'Adı göster',
			'network.sitesSee' => 'Sitelerin gördüğü',
			'network.provider' => 'Sağlayıcı',
			'network.location' => 'Konum',
			'network.couldNotCheck' => 'Kontrol edilemedi',
			'network.checking' => 'Kontrol ediliyor',
			'network.signal' => 'Sinyal',
			'network.linkSpeed' => 'Bağlantı hızı',
			'network.gateway' => 'Ağ geçidi',
			'network.none' => 'Yok',
			'network.privateDns' => 'Özel DNS',
			'network.automatic' => 'Otomatik',
			'network.off' => 'Kapalı',
			'network.metered' => 'Kotalı',
			'network.yes' => 'Evet',
			'network.no' => 'Hayır',
			'network.readFailed' => ({required Object error}) => 'Ağ okunamadı: ${error}',
			'devices.info' => 'Wi-Fi aralığınızdaki her adrese uğrar ve cihazlardan kendilerini tanıtmalarını ister. Reddeden bir cihaz da sayılır: ret, orada olduğunu kanıtlar.\n\nAdlar: cihazların yayımladıklarından (Bonjour, UPnP, Windows adları) ve modeminizden.\n\nBilinmeyen cihazlar: Android donanım adreslerini uygulamalardan gizler, bu yüzden ad bildirmeyen sessiz bir cihaz tanımlanamaz. Bunlar için modeminizin cihaz listesine bakın.\n\nYeni: bu ağın son taramasında görülmeyen cihaz.',
			'devices.needWifi' => 'Önce bir Wi-Fi ağına bağlanın.',
			'devices.title' => 'Cihazlar',
			'devices.again' => 'Tekrar tara',
			'devices.looking' => 'Cihazlar aranıyor',
			'devices.all' => 'Tümü',
			'devices.phones' => 'Telefonlar',
			'devices.tvs' => 'TV\'ler',
			'devices.computers' => 'Bilgisayarlar',
			'devices.other' => 'Diğer',
			'devices.thisPhone' => 'Bu telefon',
			'devices.router' => 'Modem',
			'devices.unknown' => 'Bilinmeyen cihaz',
			'devices.address' => 'Adres',
			'devices.answersIn' => 'Yanıt süresi',
			'devices.type' => 'Tür',
			'devices.newBadge' => 'YENİ',
			'devices.scanning' => ({required Object n}) => '254 adresin ${n} tanesi tarandı',
			'devices.newSince' => ({required Object n}) => 'Son taramadan bu yana ${n} yeni',
			'devices.ms' => ({required Object n}) => '${n} ms',
			'devices.cameras' => 'Kameralar',
			'devices.device' => 'Cihaz',
			'devices.online' => 'Çevrimiçi',
			'devices.model' => 'Model',
			'devices.announced' => 'Kendini şöyle tanıtıyor',
			'devices.services' => 'AÇIK HİZMETLER',
			'devices.checkingServices' => 'Hizmetler kontrol ediliyor',
			'devices.noServices' => 'Yaygın hizmetlerden hiçbiri yanıt vermiyor',
			'devices.rename' => 'Yeniden adlandır',
			'devices.save' => 'Kaydet',
			'devices.kinds.phone' => 'Telefon',
			'devices.kinds.computer' => 'Bilgisayar',
			'devices.kinds.tv' => 'TV',
			'devices.kinds.speaker' => 'Hoparlör',
			'devices.kinds.printer' => 'Yazıcı',
			'devices.kinds.camera' => 'Kamera',
			'devices.kinds.smartHome' => 'Akıllı ev',
			'devices.kinds.router' => 'Yönlendirici',
			'devices.kinds.unknown' => 'Tanıtılmadı',
			'devices.details' => 'Ağ ayrıntıları',
			'devices.listView' => 'Liste',
			'devices.meshView' => 'Ağ örgüsü',
			'devices.offlineHeading' => 'Çevrimdışı',
			'devices.seen' => ({required Object when}) => '${when} görüldü',
			'devices.agoMinutes' => ({required Object n}) => '${n} dk önce',
			'devices.agoHours' => ({required Object n}) => '${n} sa önce',
			'devices.agoDays' => ({required Object n}) => '${n} gün önce',
			'devices.throughVpn' => 'VPN üzerinden',
			'devices.closer' => 'Daha yakın = daha hızlı yanıt',
			'devices.yours' => 'Bu sizin mi?',
			'devices.mine' => 'Benim',
			'devices.notMine' => 'Benim değil',
			'devices.whatIsIt' => 'Bu ne?',
			'devices.ourGuess' => ({required Object kind}) => 'Tahminimiz: ${kind}',
			'devices.groupPersonal' => 'Telefonlar ve bilgisayarlar',
			'devices.groupHome' => 'Ev ve medya',
			'devices.groupNetwork' => 'Ağ ve akıllı ev',
			'devices.onlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} çevrimiçi', ), 
			'devices.offlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} çevrimdışı', ), 
			'devices.toConfirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} onay bekliyor', ), 
			'ping.askTitle' => 'Bir sunucuya ping at',
			'ping.askHint' => 'example.com veya 192.168.1.10',
			'ping.title' => 'Ping',
			'ping.router' => 'Modem',
			'ping.pause' => 'Duraklat',
			'ping.start' => 'Başlat',
			'ping.host' => 'Sunucu',
			'ping.live' => 'Canlı',
			'ping.ago' => '60 sn önce',
			'ping.min' => 'MİN',
			'ping.avg' => 'ORT',
			'ping.jitter' => 'JİTTER',
			'ping.loss' => 'KAYIP',
			'ping.goodFor' => 'Şunlar için yeterli',
			'ping.calls' => 'Görüntülü aramalar',
			'ping.games' => 'Çevrimiçi oyunlar',
			'ping.streaming' => 'Yayın izleme',
			'ping.great' => 'Harika',
			'ping.okay' => 'Fena değil',
			'ping.poor' => 'Zayıf',
			'ping.lost' => 'kayıp',
			'ping.now' => 'şimdi',
			'status.info' => 'Her hizmete üç kez bağlanır ve en hızlı yanıtı gösterir.\n\nBurada engelli: doğrudan yanıt vermeyen ama VPN üzerinden çalışan bir hizmet, ağınız veya ülkeniz tarafından engellenmiştir.\n\nGeçmiş: bu telefondan yapılan son 24 saatin kontrolleri, yalnızca bu telefonda saklanır.',
			'status.title' => 'Hizmet durumu',
			'status.checking' => 'Kontrol ediliyor',
			'status.again' => 'Tekrar kontrol et',
			'status.viaVpn' => 'VPN üzerinden kontrol edildi',
			'status.direct' => 'Doğrudan kontrol edildi',
			'status.favourites' => 'Favoriler',
			'status.edit' => 'Düzenle',
			'status.last24' => 'Son 24 saat',
			'status.ago' => '24 sa önce',
			'status.all' => 'Tüm hizmetler',
			'status.pickFour' => 'En fazla dört seçin',
			'status.outage' => 'VPN ile bile: muhtemelen kesinti',
			'status.blocked' => 'Bu ağda engellenmiş olabilir',
			'status.connect' => 'Bağlan',
			'status.blockedShort' => 'Engelli',
			'status.now' => 'şimdi',
			'status.checks' => ({required Object n}) => '${n} kontrol',
			'status.andMore' => ({required Object first, required Object n}) => '${first} ve ${n} tane daha',
			'status.notReachable' => ({required Object who}) => '${who} erişilemiyor',
			'tools.wifi' => 'Wi-Fi',
			'tools.mobile' => 'Mobil veri',
			'tools.ethernet' => 'Ethernet',
			'tools.checking' => 'Kontrol ediliyor',
			'tools.offline' => 'Çevrimdışı',
			'tools.title' => 'Araçlar',
			'tools.networkDesc' => 'Güvenlik kontrolü, sitelerin gördükleri, sinyal, modem ve DNS.',
			'tools.internet' => 'İnternet',
			'tools.speed' => 'Hız testi',
			'tools.speedDesc' => 'İndirme, yükleme ve video kalitesi',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'Canlı yanıt süresi ve dalgalanma',
			'tools.status' => 'Hizmet durumu',
			'tools.statusDesc' => 'Bir uygulama burada çalışıyor mu, engelli mi?',
			'tools.trace' => 'Traceroute',
			'tools.traceDesc' => 'Bir siteye giden yoldaki her durak',
			'tools.security' => 'Bu ağ',
			'tools.devices' => 'Bu ağdaki cihazlar',
			'tools.devicesDesc' => 'Wi-Fi\'nizde kimler var',
			'tools.router' => 'Modem kontrolü',
			'tools.routerDesc' => 'Cihazlarınızın açtığı portlar',
			'tools.ports' => 'Açık portlar',
			'tools.portsDesc' => 'Bir cihaz veya sunucudaki riskli portlar',
			'tools.utilities' => 'Araçlar',
			'tools.wifiScanner' => 'Wi-Fi tarayıcı',
			'tools.wifiDesc' => 'Çevrenizdeki ağlar ve en boş kanal',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Bu ağdaki bir bilgisayarı açın',
			'tools.passwordCheck' => 'Parola kontrolü',
			'tools.passwordCheckDesc' => 'Sızdırılmış mı?',
			'tools.linkCheck' => 'Bağlantı kontrolü',
			_ => null,
		} ?? switch (path) {
			'tools.linkCheckDesc' => 'Açmak güvenli mi?',
			'tools.breaches' => 'Veri sızıntıları',
			'tools.breachesDesc' => 'Son zamanlarda ne sızdı',
			'tools.blocked' => 'Ne engelli',
			'tools.blockedDesc' => 'Bu ağda engellenen siteler',
			'trace.info' => 'Her durak, trafiğinizin siteye giderken geçtiği bir yönlendiricidir.\n\nSessiz atlamalar: birçok yönlendirici bu denemelere hiç yanıt vermez. Bu normaldir, bir arıza değildir.\n\nVPN açıkken: yol tünelin içinden başlar, bu yüzden kendi ağınız ve sağlayıcınız gizli kalır.\n\nNasıl: uygulamalar bu paketleri doğrudan gönderemediği için Android\'in kendi ping aracını atlama sınırıyla kullanır.',
			'trace.title' => 'Traceroute',
			'trace.stop' => 'Durdur',
			'trace.trace' => 'İzle',
			'trace.again' => 'Tekrar izle',
			'trace.destination' => 'Hedef',
			'trace.hops' => 'ATLAMA',
			'trace.answered' => 'YANIT VERDİ',
			'trace.total' => 'TOPLAM',
			'trace.thisPhone' => 'Bu telefon',
			'trace.silentOne' => '1 sessiz atlama',
			'trace.yourRouter' => 'Modeminiz',
			'trace.ms' => ({required Object n}) => '${n} ms',
			'trace.silentMany' => ({required Object n}) => '${n} sessiz atlama',
			'trace.hop' => ({required Object n}) => 'Atlama ${n}',
			'trace.slowest' => ({required Object ms, required Object hop}) => 'Gecikmenin çoğu, ${ms} ms, ${hop}. atlamada ekleniyor: genellikle ülkeler arası uzun bir kablo ya da yoğun bir bağlantı.',
			'trace.popular' => 'POPÜLER',
			'trace.recent' => 'SON KULLANILANLAR',
			'trace.clearRecent' => 'Sonları temizle',
			'trace.hopsCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} atlama', ), 
			'ports.ftpNote' => 'Şifreleri şifrelemeden gönderir.',
			'ports.sshNote' => 'Uzaktan giriş. Kendiniz kurduysanız sorun yok.',
			'ports.telnetNote' => 'Şifresiz uzaktan giriş; botnetlerin favorisi.',
			'ports.dnsNote' => 'Modemde normaldir.',
			'ports.web' => 'Web (HTTP)',
			'ports.webNote' => 'Genellikle modem yönetim sayfası.',
			'ports.webTls' => 'Web (HTTPS)',
			'ports.smb' => 'Windows dosya paylaşımı',
			'ports.smbNote' => 'Asla internete açık olmamalı.',
			'ports.rtsp' => 'RTSP kamera yayını',
			'ports.rtspNote' => 'Burada yayın yapan bir kamera olabilir.',
			'ports.upnpNote' => 'Cihazların modem portlarını kendi başına açmasına izin verir.',
			'ports.rdp' => 'Uzak Masaüstü',
			'ports.rdpNote' => 'Yaygın bir saldırı yolu.',
			'ports.vncNote' => 'Ekran paylaşımı, çoğu zaman şifresiz.',
			'ports.tr069Note' => 'İnternet sağlayıcısının uzaktan yönetimi.',
			'ports.webAlt' => 'Web (alternatif)',
			'ports.webAltTls' => 'Web (alternatif HTTPS)',
			'ports.title' => 'Açık portlar',
			'ports.check' => 'Portları kontrol et',
			'ports.address' => 'Cihaz veya sunucu adresi',
			'ports.risky' => 'RİSKLİ',
			'ports.review' => 'İNCELE',
			'ports.normal' => 'NORMAL',
			'ports.info' => ({required Object n}) => 'Ev modemleri ve cihazlarında önemli olan ${n} portu kontrol eder ve açık olan her birini açıklar.\n\nYalnızca sahibi olduğunuz veya yönettiğiniz cihazları ve sunucuları kontrol edin.',
			'ports.checking' => ({required Object n}) => '${n} port kontrol ediliyor',
			'ports.yourRouter' => ({required Object ip}) => 'Modeminiz: ${ip}',
			'ports.noneOpen' => ({required Object host}) => '${host} üzerinde açık yaygın port yok.',
			'ports.summary' => ({required Object n, required Object open}) => '${n} port içinde ${open} açık',
			'ports.riskyCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} riskli', ), 
			'ports.noneRisky' => 'Riskli bir şey yok',
			'wifi.title' => 'Wi-Fi tarayıcı',
			'wifi.allow' => 'Wi-Fi taramasına izin ver',
			'wifi.needsPermission' => 'Konum izni gerekiyor.',
			'wifi.scanning' => 'Taranıyor',
			'wifi.again' => 'Tekrar tara',
			'wifi.failed' => 'Tarama başarısız',
			'wifi.none' => 'Ağ bulunamadı. Konum kapalı olabilir.',
			'wifi.hidden' => 'Gizli ağ',
			'wifi.nearby' => ({required Object n}) => 'Yakında ${n} ağ',
			'wifi.permissionInfo' => 'Android, yakındaki Wi-Fi ağlarını yalnızca konum izni olan uygulamalara gösterir. G VPN bunu yalnızca bu telefondaki ağları listelemek için kullanır.',
			'wifi.info' => 'Telefonun son taramasındaki ağları listeler. Android dakikada yalnızca birkaç taramaya izin verir, bu yüzden hızlı tekrar tarama aynı listeyi gösterebilir. Önerilen kanal, birbiriyle çakışmayan üç kanal olan 1, 6 ve 11 arasında en az kalabalık olanıdır.',
			'wifi.airMap' => 'Hava haritası',
			'wifi.channels' => 'Kanallar',
			'wifi.list' => 'Liste',
			'wifi.secure' => 'Güvenli',
			'wifi.weakLabel' => 'Zayıf',
			'wifi.openLabel' => 'Açık',
			'wifi.sizeIsWidth' => 'Boyut = kanal genişliği',
			'wifi.strongest' => 'EN GÜÇLÜ',
			'wifi.openNearby' => 'YAKINDAKİ AÇIK AĞLAR',
			'wifi.onYourChannel' => 'KANALINIZDA',
			'wifi.noneNearby' => 'Yok',
			'wifi.verdictOpen' => 'Yakındaki herkes gönderilenleri okuyabilir',
			'wifi.verdictWep' => 'Eski güvenlik, kolay kırılır',
			'wifi.verdictWpa' => 'Eski güvenlik',
			'wifi.verdictWps' => 'WPS açık: kırılması daha kolay',
			'wifi.verdictGood' => 'İyi korunuyor',
			'wifi.maker' => 'Üretici',
			'wifi.address' => 'Donanım adresi',
			'wifi.privateAddress' => 'Gizlilik için yönlendirici uydurdu',
			'wifi.you' => 'Siz',
			'wifi.onClear' => ({required Object name}) => '${name} boş bir kanalda',
			'wifi.move' => ({required Object name, required Object n}) => '${name} ağını ${n}. kanala taşıyın',
			'wifi.clear' => 'Boş',
			'wifi.busy' => 'Yoğun',
			'wifi.crowded' => 'Kalabalık',
			'wifi.allBands' => 'Tüm bantlar',
			'wifi.openOnly' => 'Yalnızca açık',
			'wifi.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} ağ', ), 
			'errors.notAuthorized' => 'VPN izni verilmedi.',
			'errors.turnedOff' => 'VPN sistem veya başka bir uygulama tarafından kapatıldı.',
			'errors.busy' => 'Zaten açık bir izin isteği var.',
			'errors.cancelled' => 'Bağlantı iptal edildi.',
			'errors.badConfig' => ({required Object error}) => 'Bu sunucunun yapılandırması geçersiz: ${error}',
			'errors.timeout' => 'Sunucu yanıt vermedi.',
			'errors.refused' => 'Sunucu bağlantıyı reddetti.',
			'errors.failed' => ({required Object error}) => 'Bağlanılamadı: ${error}',
			'errors.tryAnother' => 'Ücretsiz sunucular gelip gider; başka birini deneyin.',
			'errors.downloadFailed' => 'Bu sunucunun ayarları indirilemedi. Bağlantınızı kontrol edin veya başka bir sunucu seçin.',
			'scan.mobile' => 'Mobil veri',
			'scan.ping' => 'PING',
			'scan.noReply' => 'Yanıt yok',
			'scan.dns' => 'DNS',
			'scan.dnsQuad9' => 'Quad9, tünel',
			'scan.dnsTunnel' => 'Tünelde',
			'scan.privateDns' => 'Özel DNS',
			'scan.dnsIsp' => 'Sağlayıcı, görünür',
			'scan.network' => 'AĞ',
			'scan.offline' => 'Çevrimdışı',
			'scan.open' => 'Açık, şifresiz',
			'scan.wep' => 'WEP, güvensiz',
			'scan.owe' => 'Açık, şifreli',
			'scan.enterprise' => 'Kurumsal',
			'scan.unknown' => 'Bilinmiyor',
			'scan.wifi' => 'WI-FI',
			'scan.signIn' => 'Giriş sayfası',
			'scan.ms' => ({required Object n}) => '${n} ms',
			'scan.covered' => ({required Object what}) => '${what}, korunuyor',
			'legal.privacy' => 'Gizlilik politikası',
			'legal.terms' => 'Kullanım koşulları',
			'legal.licences' => 'Açık kaynak lisansları',
			'update.ready' => 'Güncelleme hazır',
			'update.restart' => 'Yeniden başlat',
			'details.share' => 'Paylaş',
			'details.connectedFor' => ({required Object n}) => 'BAĞLI · ${n} DK',
			'details.notConnected' => 'BAĞLI DEĞİL',
			'details.downloaded' => 'İNDİRİLEN',
			'details.uploaded' => 'YÜKLENEN',
			'details.lastUsed' => 'SON KULLANIM',
			'details.connection' => 'Bağlantı',
			'details.protocol' => 'Protokol',
			'details.address' => 'Adresiniz',
			'details.dns' => 'DNS',
			'details.routes' => 'Rotalar',
			'details.allTraffic' => 'Tüm trafik',
			'details.someRoutes' => ({required Object n}) => '${n} ağ',
			'details.keepalive' => 'Keepalive',
			'details.serverKey' => 'Sunucu anahtarı',
			'details.copy' => 'Kopyala',
			'details.copied' => 'Kopyalandı',
			'details.manage' => 'Yönet',
			'details.export' => 'Yedek için dışa aktar',
			'details.exportSub' => 'Tüm sunucularınız tek dosyada',
			'share.title' => ({required Object name}) => '${name} paylaş',
			'share.sameKey' => 'Bu, bu telefonun anahtarını paylaşır. Ona sahip olan herkes sunucunuzu sizin yerinize kullanabilir ve aynı anda yalnızca bir cihaz bağlanabilir.',
			'share.scanHint' => 'Diğer telefonda: G VPN, Sunucular, QR tara. Kaydedilmiş bir resim de olur.',
			'share.saveImage' => 'Resmi kaydet',
			'share.send' => 'Gönder',
			'add.title' => 'Sunucu ekle',
			'add.subtitle' => 'Herhangi bir WireGuard sunucusu: modem, VPS veya ev sunucusu.',
			'add.camera' => 'Kamerayla tara',
			'add.cameraSub' => 'Başka ekrandaki QR',
			'add.image' => 'Bir resimden',
			'add.imageSub' => 'Ekran görüntüsü veya kayıtlı fotoğraf',
			'add.noQr' => 'Bu resimde QR kod bulunamadı.',
			'add.tip' => 'QR\'ı WhatsApp veya Telegram\'dan mı aldınız? Resimde Paylaş\'a dokunup G VPN\'i seçin.',
			'backup.restored' => ({required Object n}) => '${n} sunucu geri yüklendi',
			'backup.nothingNew' => 'Bu sunucular zaten burada',
			'gs.proRequired' => 'G Servers, G VPN Pro aboneleri içindir.',
			'gs.off' => 'G Servers şu anda kapalı.',
			'gs.network' => 'G Servers\'a ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.',
			'gs.active' => 'AKTİF',
			'gs.servers' => 'G Servers',
			'gs.busy' => ({required Object n}) => '%${n} meşgul',
			'gs.offline' => 'Çevrimdışı',
			'gs.devices' => 'Cihazlarınız',
			'gs.subtitle' => ({required Object country}) => 'G Server · ${country} · WireGuard',
			'gs.busyLabel' => 'MEŞGUL',
			'gs.status' => 'DURUM',
			'gs.online' => 'Çevrimiçi',
			'gs.onThisServer' => 'Bu sunucuda',
			'gs.thisPhone' => 'Bu telefon',
			'gs.added' => 'Eklendi · anahtar burada oluşturuldu',
			'gs.notAdded' => 'Bağlandığınızda eklenir',
			'gs.logs' => 'Etkinlik kayıtları',
			'gs.noneKept' => 'Tutulmuyor',
			'gs.privacy' => 'Sunucu bu telefonu yalnızca açık anahtarıyla tanır. Ziyaret ettiğiniz siteleri veya gönderdiğiniz trafiği kaydetmez.',
			'gs.stepPro1' => 'G VPN\'i aynı Google hesabıyla telefona kurun.',
			'gs.stepPro2' => 'Pro sekmesini açın. Pro kendiliğinden açılır ya da Geri yükle\'ye dokunun.',
			'gs.step3' => 'Bağlan\'a dokunun. Telefon anahtarını oluşturur ve G Servers\'a eklenir. QR yok, kod yok.',
			'gs.stepFree1' => 'G VPN\'i telefona kurun.',
			'gs.stepFree2' => 'Pro sekmesini açın.',
			'gs.devicesIntroPro' => 'Pro, Google hesabınızla gelir. Her telefonun kendi anahtarı vardır, bu yüzden birbirlerinin bağlantısını kesmezler.',
			'gs.devicesIntroFree' => 'Her telefonun kendi anahtarı vardır, bu yüzden birbirlerinin bağlantısını kesmezler.',
			'gs.otherPhone' => 'Başka bir telefon',
			'gs.lastConnected' => ({required Object when}) => 'Son bağlantı ${when}',
			'gs.noDevices' => 'Bir G Server\'a bir kez bağlanın, telefonlarınız burada görünür.',
			'gs.addTitle' => 'Telefon ekle veya yeniden kur',
			'gs.idle' => ({required Object n}) => '${n} gün bağlanmayan telefon G Servers\'dan kendiliğinden kaldırılır; böylece eski ya da yeniden kurulan telefon yer kaplamaz.',
			'gs.limitNote' => ({required Object n}) => 'Plan başına en fazla ${n} telefon.',
			'gs.fullTitle' => ({required Object n}) => '${n} yerin hepsi kullanımda',
			'gs.fullBody' => 'Artık kullanmadığınız bir telefonu kaldırın, bu telefon hemen bağlansın.',
			'gs.busyNow' => 'Şu anda çok fazla yeni telefon var. Biraz sonra tekrar deneyin.',
			'gs.serverFull' => 'Bu sunucu dolu. Başka bir G Server deneyin.',
			'gs.ping' => 'PING',
			'gs.last24' => 'Meşguliyet, son 24 saat',
			'gs.noHistory' => 'Grafik, sunucu gün içinde kullanıldıkça dolar.',
			'gs.chartLabel' => ({required Object max}) => 'Son 24 saatteki meşguliyet, en fazla yüzde ${max}',
			'gs.hoursAgo' => '24 sa önce',
			'gs.now' => 'Şimdi',
			'gs.included' => 'Dahil',
			'gs.perkServers' => 'Hızlı, özel sunucular',
			'gs.perkServersSub' => 'WireGuard, bizim işlettiğimiz, etkinlik kaydı yok',
			'gs.perkLinks' => 'Sınırsız bağlantı kontrolü',
			'gs.perkLinksSub' => 'Size gönderilen her bağlantıyı kontrol edin',
			'gs.devicesOf' => ({required Object limit, required Object used}) => 'Cihazlarınız · ${limit} içinde ${used}',
			'gs.eachKey' => 'Her telefonun kendi anahtarı var',
			'gs.connected' => 'Bağlı',
			'gs.bestNow' => 'ŞU AN SİZİN İÇİN EN İYİSİ',
			'gs.logsShort' => 'KAYIT',
			'map.open' => 'Haritayı aç',
			'map.searchCountries' => 'Ülke ara',
			'map.noMatch' => 'Eşleşen ülke yok',
			'map.locate' => 'Konumum',
			'map.list' => 'Liste',
			'map.map' => 'Harita',
			'map.freeServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} ücretsiz sunucu', ), 
			'map.grade.fast' => 'Hızlı',
			'map.grade.good' => 'İyi',
			'map.grade.slow' => 'Yavaş',
			'map.switchTo' => 'Geç',
			'map.freeServer' => ({required Object n}) => 'Ücretsiz sunucu ${n}',
			'map.best' => 'EN İYİ',
			'map.gServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} G Server', ), 
			'stats.thisWeek' => 'Bu hafta',
			'stats.time' => 'Süre',
			'stats.data' => 'Veri',
			'stats.protected' => 'korumalı',
			'stats.throughVpn' => 'VPN üzerinden',
			'stats.seeDetails' => 'Ayrıntılar',
			'stats.title' => 'İstatistikler',
			'stats.week' => 'Hafta',
			'stats.month' => 'Ay',
			'stats.protectedLabel' => 'KORUMALI',
			'stats.dataUsed' => 'KULLANILAN VERİ',
			'stats.byServer' => 'SUNUCUYA GÖRE',
			'stats.onPhone' => 'Yalnızca bu telefonda',
			'stats.reset' => 'Sıfırla',
			'stats.resetTitle' => 'İstatistikler sıfırlansın mı?',
			'stats.resetBody' => 'Bu telefondaki korumalı süre ve veri silinir. Geri alınamaz.',
			'stats.hm' => ({required Object h, required Object m}) => '${h} sa ${m} dk',
			'stats.m' => ({required Object m}) => '${m} dk',
			'stats.empty' => 'Saymaya başlamak için bağlanın.',
			'recents.title' => 'Son kullanılanlar',
			'recents.allServers' => 'Tüm sunucular',
			'recents.free' => 'Ücretsiz sunucu',
			'recents.yours' => 'Sunucunuz',
			'recents.gserver' => 'G Server',
			'presets.title' => 'Hazır ayarlar',
			'presets.all' => 'Tümü',
			'presets.newPreset' => 'Yeni ayar',
			'presets.edit' => 'Ayarı düzenle',
			'presets.name' => 'Ad',
			'presets.namePlaceholder' => 'Ayarım',
			'presets.server' => 'SUNUCU',
			'presets.fastestOption' => 'En hızlı',
			'presets.countryOption' => 'Ülke',
			'presets.pickCountry' => 'Ülke seçin',
			'presets.skipMyCountry' => 'Ülkemi atla',
			'presets.notMine' => 'ülkem hariç',
			'presets.protocol' => 'PROTOKOL',
			'presets.auto' => 'Otomatik',
			'presets.tryNext' => 'Engellenirse sonrakini dene',
			'presets.shield' => 'KALKAN',
			'presets.followRules' => 'Kurallardaki gibi',
			'presets.allApps' => 'Tüm uygulamalar VPN\'den',
			'presets.allAppsShort' => 'tüm uygulamalar',
			'presets.save' => 'Kaydet',
			'presets.delete' => 'Sil',
			'presets.reset' => 'Varsayılana dön',
			'presets.none' => 'Şu an bu ayara uyan ücretsiz sunucu yok.',
			'presets.names.fastest' => 'En hızlı',
			'presets.names.unblock' => 'Engel aş',
			'presets.names.streaming' => 'Yayın',
			'presets.names.privacy' => 'En yüksek gizlilik',
			'shield.title' => 'Kalkan',
			'shield.sub' => 'Bağlıyken çalışır',
			'shield.off' => 'Kapalı',
			'shield.offSub' => 'Sunucunun kendi DNS\'i',
			'shield.malware' => 'Kötü amaçlı yazılım',
			'shield.malwareSub' => 'Zararlı ve oltalama sitelerini engeller',
			'shield.family' => 'Kötü amaçlı ve yetişkin siteleri',
			'shield.familySub' => 'Yetişkin içeriği de engeller',
			'shield.custom' => 'Özel DNS',
			'shield.customSub' => 'Kendi DNS sunucularınız',
			'shield.customHint' => 'IP adresi, örneğin 1.1.1.1',
			'shield.invalid' => 'Bir veya iki IP adresi girin.',
			'checks.title' => 'Güvenlik kontrolleri',
			'checks.password' => 'Parola',
			'checks.link' => 'Bağlantı',
			'checks.pwTitle' => 'Sızdırıldı mı?',
			'checks.pwHint' => 'Kontrol edilecek parola',
			'checks.showPassword' => 'Parolayı göster',
			'checks.hidePassword' => 'Parolayı gizle',
			'checks.check' => 'Kontrol et',
			'checks.leaked' => 'Sızıntılarda bulundu',
			'checks.seen' => ({required Object n}) => '${n} kez görüldü',
			'checks.leakedAdvice' => 'Kullandığınız her yerde değiştirin; e-posta ve bankadan başlayın.',
			'checks.notFound' => 'Bilinen sızıntılarda yok',
			'checks.notFoundAdvice' => 'İyi bir işaret, garanti değil. Her hesapta farklı parola kullanın.',
			'checks.failed' => 'Kontrol edilemedi. Tekrar deneyin.',
			'checks.private' => 'Parolanız bu telefondan hiç çıkmaz',
			'checks.linkTitle' => 'Bu bağlantı güvenli mi?',
			'checks.linkHint' => 'Kontrol edilecek bağlantı',
			'checks.paste' => 'Yapıştır',
			'checks.danger' => 'Tehlikeli bağlantı',
			'checks.dangerAdvice' => 'Açmayın ve hiçbir bilgi girmeyin.',
			'checks.clear' => 'Bilinen kötü amaçlı yazılım veya oltalama listelerinde yok',
			'checks.clearAdvice' => 'Yine de giriş yapmadan önce adrese bakın.',
			'checks.goesTo' => 'Gittiği yer',
			'checks.redirects' => 'Yönlendirmeler',
			'checks.invalid' => 'Bu bir web adresine benzemiyor.',
			'checks.busy' => 'Çok fazla kontrol. Biraz sonra tekrar deneyin.',
			'checks.unavailable' => 'Bağlantı kontrolü şu an kullanılamıyor.',
			'checks.listed' => 'Kötü amaçlı yazılım veya oltalamayla bilinen',
			'checks.missing' => 'Bu adreste site yok',
			'checks.missingAdvice' => 'Yazımı kontrol edin: dolandırıcılar benzer adresler kullanır.',
			'checks.left' => ({required Object total, required Object n}) => 'Bu ay ${total} ücretsiz kontrolden ${n} kaldı',
			'checks.usedUp' => 'Bu ayın ücretsiz bağlantı kontrollerini kullandınız',
			'checks.usedUpSub' => 'Pro\'da sınırsız kontrol var. Ücretsiz kontroller ayın 1\'inde yenilenir.',
			'checks.getPro' => 'Pro\'yu al',
			'toolSettings.title' => 'Araç ayarları',
			'toolSettings.askMobile' => 'Mobil veride hız testinden önce sor',
			'toolSettings.askMobileSub' => 'Hızlı bağlantıda bir test 100 MB\'tan fazla kullanabilir',
			'toolSettings.mobileTitle' => 'Mobil veri kullanılsın mı?',
			'toolSettings.mobileBody' => 'Hızlı bağlantıda bir hız testi 100 MB\'tan fazla kullanabilir.',
			'toolSettings.mobileGo' => 'Test et',
			'toolSettings.safe' => 'Güvenli',
			'toolSettings.unsafe' => 'Güvensiz',
			'toolSettings.devices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} cihaz', ), 
			'toolSettings.hideMac' => 'Donanım adreslerini gizle',
			'toolSettings.hideMacSub' => 'MAC adreslerinin yalnızca üretici kısmını gösterir',
			'toolSettings.names' => 'Yönlendirici ve sunucu adlarını göster',
			'toolSettings.namesSub' => 'Traceroute\'ta adresler için ad arar',
			'toolSettings.remember' => 'Son kullanılan adresleri hatırla',
			'toolSettings.rememberSub' => 'Traceroute için',
			'toolSettings.clear' => 'Araç geçmişini temizle',
			'toolSettings.clearSub' => 'Son adresleri ve her ağdaki cihazları unutur',
			'toolSettings.clearGo' => 'Temizle',
			'security.tab' => 'Güvenlik',
			'security.good' => 'İyi',
			'security.fair' => 'Orta',
			'security.atRisk' => 'Riskli',
			'security.allClear' => 'Düzeltilecek bir şey yok',
			'security.checked' => ({required Object time}) => '${time} itibarıyla kontrol edildi',
			'security.trend' => 'SON İKİ HAFTA',
			'security.checking' => 'Bu ağ kontrol ediliyor',
			'security.snoozed' => 'Ertelenenler',
			'security.remindLater' => 'Sonra hatırlat',
			'security.unsnooze' => 'Şimdi hatırlat',
			'security.review' => 'İncele',
			'security.confirmGo' => 'Onayla',
			'security.scanGo' => 'Tara',
			'security.look' => 'Bak',
			'security.connectGo' => 'Bağlan',
			'security.checkAgain' => 'Tekrar kontrol et',
			'security.wifiOpen' => 'Wi-Fi açık',
			'security.wifiOpenDetail' => 'Yakındaki herkes gönderilenleri görebilir',
			'security.wifiWep' => 'Wi-Fi WEP kullanıyor',
			'security.wifiWepDetail' => 'Eski güvenlik, kolay kırılır',
			'security.wifiOwe' => 'Wi-Fi Enhanced Open kullanıyor',
			'security.wifiOweDetail' => 'Şifreli ama herkes katılabilir',
			'security.wifiSecure' => 'Wi-Fi şifrelemesi',
			'security.wifiUnknown' => 'Wi-Fi güvenliği bilinmiyor',
			'security.wifiUnknownDetail' => 'Android nasıl korunduğunu bildirmedi',
			'security.wps' => 'WPS açık',
			'security.wpsDetail' => 'Yönlendirici ayarlarından kapatın',
			'security.upnpOff' => 'Yönlendirici portları kapalı tutuyor',
			'security.upnpOffDetail' => 'UPnP kapalı',
			'security.upnpOn' => 'Yönlendirici cihazların port açmasına izin veriyor',
			'security.upnpOnDetail' => 'UPnP açık',
			'security.portsOk' => 'Yönlendiricide riskli port yok',
			'security.portsRisky' => 'Yönlendiricide riskli portlar açık',
			'security.scanFirst' => 'Burada kimler var görmek için tarayın',
			'security.scanFirstDetail' => 'Bilinmeyen cihazlar puanı düşürür',
			'security.notMineDetail' => 'Yönlendiricinin cihaz listesine bakın',
			'security.confirmDetail' => 'Sizin olanları işaretleyin',
			'security.devicesOk' => 'Tüm cihazlar biliniyor',
			'security.devicesOkDetail' => 'Hepsini onayladınız',
			'security.camera' => 'Bu ağda bir kamera var',
			'security.dnsHijack' => 'Bilinmeyen adlar yönlendiriliyor',
			'security.dnsHijackDetail' => 'Sağlayıcınız veya yönlendiriciniz sorguları değiştiriyor',
			'security.dnsOk' => 'DNS normal yanıt veriyor',
			'security.dnsOkDetail' => 'Yönlendirme belirtisi yok',
			'security.vpnOn' => 'VPN açık',
			'security.vpnOnDetail' => 'Trafik tünelden çıkıyor',
			'security.vpnOff' => 'VPN kapalı',
			'security.vpnOffDetail' => 'Sağlayıcınız her siteyi görüyor',
			'security.toFix' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: 'Düzeltilecek ${n} şey', ), 
			'security.upnpOpened' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: 'Cihazların açtığı ${n} port', ), 
			'security.portsChecked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} port kontrol edildi', ), 
			'security.notMine' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} cihaz sizin değil', ), 
			'security.confirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: 'Onaylanacak ${n} cihaz', ), 
			'providers.tab' => 'İnternet',
			'providers.unavailable' => 'Sağlayıcı listesi yüklenemedi. Bağlantınızı kontrol edin.',
			'providers.cached' => 'VPN\'siz son kontrolünüze göre',
			'providers.notEnough' => 'Henüz yeterli puan yok',
			'providers.yourRating' => 'Bu ayki puanınız',
			'providers.yourSpeed' => 'HIZINIZ',
			'providers.runTest' => 'Hız testi yap',
			'providers.aboutAverage' => 'Buradaki ortalama civarında',
			'providers.aboveAverage' => ({required Object pct}) => 'Yerel ortalamanın %${pct} üstünde',
			'providers.belowAverage' => ({required Object pct}) => 'Yerel ortalamanın %${pct} altında',
			'providers.call' => 'Ara',
			'providers.website' => 'Web sitesi',
			'providers.outages' => 'Kesintiler',
			'providers.rate' => 'Puanla',
			'providers.changeRating' => 'Puanı değiştir',
			'providers.compare' => 'Karşılaştır',
			'providers.rateTitle' => ({required Object name}) => '${name} sağlayıcısını puanla',
			'providers.oncePerMonth' => 'Ayda bir puan',
			'providers.tapStars' => 'Yıldızlara dokunun',
			'providers.verified' => ({required Object mbps}) => 'Hız testinizle doğrulandı: ${mbps} Mbps',
			'providers.busy' => 'Buradan çok fazla puan geldi. Sonra deneyin.',
			'providers.failed' => 'Gönderilemedi. Tekrar deneyin.',
			'providers.post' => 'Puanı gönder',
			'providers.nearTitle' => 'Yakınınızdaki sağlayıcılar',
			'providers.slower' => ({required Object pct}) => 'İndirme hızınız sağlayıcınızın buradaki ortalamasının %${pct} altında',
			'providers.inPlace' => ({required Object place}) => '${place} ev interneti',
			'providers.byRating' => 'Puan',
			'providers.bySpeed' => 'Hız',
			'providers.footnote' => 'Hızlar G VPN hız testlerinin ortalamasıdır',
			'providers.noneNearby' => 'Yakında henüz puan yok. İlk siz olun.',
			'providers.you' => 'Siz',
			'providers.topRated' => 'En yüksek puanlı',
			'providers.starsOf' => ({required Object n}) => '5 üzerinden ${n}',
			'providers.tags.fast' => 'Hızlı',
			'providers.tags.reliable' => 'Güvenilir',
			'providers.tags.support' => 'İyi destek',
			'providers.tags.price' => 'Makul fiyat',
			'providers.tags.slowEvenings' => 'Akşamları yavaş',
			'providers.tags.drops' => 'Sık kopuyor',
			'providers.tags.poorSupport' => 'Kötü destek',
			'providers.tags.pricey' => 'Pahalı',
			'providers.words.bad' => 'Kötü',
			'providers.words.poor' => 'Zayıf',
			'providers.words.okay' => 'İdare eder',
			'providers.words.good' => 'İyi',
			'providers.words.great' => 'Harika',
			'providers.ratings' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} puan', ), 
			'alerts.channel' => 'Uyarılar',
			'alerts.title' => 'Uyarılar',
			'alerts.markAllRead' => 'Tümünü okundu yap',
			'alerts.clearAll' => 'Tümünü temizle',
			'alerts.thisNetwork' => 'bu ağ',
			'alerts.openWifiTitle' => ({required Object name}) => 'Açık bir Wi-Fi\'ye bağlandınız: ${name}',
			'alerts.openWifiBody' => 'Yakındaki herkes gönderilenleri görebilir. G VPN\'i açın.',
			'alerts.reportTitle' => 'Haftalık raporunuz hazır',
			'alerts.reportBody' => ({required Object hours}) => 'Geçen hafta ${hours} saat korundunuz',
			'alerts.blockedTitle' => ({required Object name}) => '${name} burada engelli',
			'alerts.blockedBody' => 'VPN üzerinden yanıt veriyor',
			'alerts.kinds.newDevice' => 'Wi-Fi\'mdaki yeni cihazlar',
			'alerts.kinds.openWifi' => 'Açık veya zayıf Wi-Fi',
			'alerts.kinds.blocked' => 'Engelli uygulamalar',
			'alerts.kinds.report' => 'Haftalık rapor',
			'alerts.kinds.breach' => 'Sızıntılar',
			'alerts.newDeviceTitle' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${network} ağında ${n} yeni cihaz', ), 
			'alerts.settings' => 'Uyarı ayarları',
			'alerts.look' => 'Bak',
			'alerts.read' => 'Oku',
			'alerts.open' => 'Aç',
			'alerts.check' => 'Kontrol et',
			'alerts.today' => 'BUGÜN',
			'alerts.thisWeek' => 'BU HAFTA',
			'alerts.earlier' => 'DAHA ÖNCE',
			'alerts.all' => 'Tümü',
			'alerts.quiet' => 'Her şey sakin',
			'alerts.quietSub' => 'Son zamanlarda hiçbir şey size ihtiyaç duymadı',
			'alerts.breachTitle' => ({required Object name}) => 'Yeni sızıntı: ${name}',
			'alerts.status.background' => 'Birkaç saatte bir',
			'alerts.status.checked' => ({required Object time}) => '${time} itibarıyla kontrol edildi',
			'alerts.status.wifi' => 'Bağlandığınız her ağ',
			'alerts.status.blocked' => 'Hizmet durumu çalıştığında',
			'alerts.status.report' => 'Her pazartesi',
			'report.title' => 'Haftalık rapor',
			'report.share' => 'Görsel olarak paylaş',
			'report.shareText' => 'G VPN ile haftam',
			'report.safer' => 'Daha güvenli bir hafta',
			'report.moreProtected' => 'Geçen haftadan daha korunaklı',
			'report.yourWeek' => 'Haftanız',
			'report.soFar' => ({required Object range}) => '${range}, şu ana kadar',
			'report.protected' => 'Korunan',
			'report.data' => 'Veri',
			'report.security' => 'Güvenlik',
			'report.speed' => 'En iyi hız',
			'report.noScore' => 'Kontrol edilmedi',
			'report.noTest' => 'Test yok',
			'report.bestDirect' => 'Doğrudan test',
			'report.moreThan' => ({required Object d}) => 'Geçen haftadan ${d} fazla',
			'report.lessThan' => ({required Object d}) => 'Geçen haftadan ${d} az',
			'report.protectedTime' => 'KORUNAN SÜRE',
			'report.mostUsed' => ({required Object name}) => 'En çok kullanılan: ${name}',
			'report.quiet' => 'Sakin bir hafta: hiçbir şey size ihtiyaç duymadı',
			'report.newDevices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} yeni cihaz katıldı', ), 
			'report.openWifi' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} açık Wi-Fi\'ye bağlandınız', ), 
			'report.blocked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} uygulama engellendi', ), 
			'report.breaches' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} büyük yeni sızıntı', ), 
			'breaches.title' => 'Veri sızıntıları',
			'breaches.info' => 'Have I Been Pwned\'ın herkese açık listesinden en yeni veri sızıntıları. Sizinle ilgili hiçbir şey gönderilmez: liste herkes için aynıdır.\n\nSızdırılan bir sitede hesabınız varsa o parolayı ve aynısını kullandığınız her yerde değiştirin.',
			'breaches.unavailable' => 'Liste yüklenemedi. Bağlantınızı kontrol edin.',
			'breaches.biggest' => 'BU AYIN EN BÜYÜĞÜ',
			'breaches.newest' => 'En yeni',
			'breaches.biggestSort' => 'En büyük',
			'breaches.withPasswords' => 'Parola içeren',
			'breaches.passwordsMark' => 'PAROLALAR',
			'breaches.one' => 'Sızıntı',
			_ => null,
		} ?? switch (path) {
			'breaches.checkPassword' => 'Bir parolayı kontrol et',
			'breaches.verified' => 'Doğrulanmış',
			'breaches.hasPasswords' => 'Parola içeriyor',
			'breaches.accountsLabel' => 'Hesaplar',
			'breaches.happened' => 'Gerçekleşti',
			'breaches.published' => 'Yayımlandı',
			'breaches.website' => 'Web sitesi',
			'breaches.leaked' => 'NE SIZDI',
			'breaches.ifUsed' => 'KULLANDIYSANIZ',
			'breaches.stepPassword' => 'Orada kullandığınız parolayı değiştirin',
			'breaches.stepReuse' => 'Aynısını kullandığınız her yerde değiştirin',
			'breaches.stepTwoStep' => 'Mümkünse iki adımlı girişi açın',
			'breaches.stepScams' => 'Dolandırıcı arama ve mesajlarına hazırlıklı olun',
			'breaches.accounts' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${count} hesap', ), 
			'breaches.worldwide' => ({required Object n}) => 'Dünya geneli · ${n}',
			'breaches.noneHere' => 'Son listede buradan sızıntı yok.',
			'breaches.bigMap' => 'Daha büyük harita',
			'breaches.showInList' => 'Listede göster',
			'breaches.mapTitle' => 'Sızıntı haritası',
			'breaches.zoomIn' => 'Yakınlaştır',
			'breaches.zoomOut' => 'Uzaklaştır',
			'breaches.wholeWorld' => 'Tüm dünya',
			'breaches.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} sızıntı', ), 
			'breaches.findCountry' => 'Bir ülke bul',
			'breaches.seeAll' => 'Tümünü gör',
			'breaches.search' => 'Sızıntılarda ara',
			'blocked.title' => 'Ne engelli',
			'blocked.info' => 'Bilinen siteleri bu telefondan VPN olmadan dener ve bu ağın hangilerini nasıl engellediğini gösterir.\n\nYanlış adres: ağın ad sorgusu yanlış yanıt verir.\n\nKesildi: bağlantı başlarken kesilir.\n\nYanıt yok: hiçbir şey dönmez.\n\nEngel sayfası: sitenin yerine başka bir şey yanıt verir.\n\nTest bir sitenin nerede engellendiğini gösterir, kimin engellediğini değil. Hiçbir şey kaydedilmez veya gönderilmez.',
			'blocked.thisNetwork' => 'Bu ağ',
			'blocked.country' => 'Ülkeniz',
			'blocked.question' => 'Burada ne engelli?',
			'blocked.testingOn' => 'TEST EDİLEN',
			'blocked.vpnOn' => 'VPN AÇIK',
			'blocked.turnOff' => 'Test için G VPN\'i kapatın',
			'blocked.test' => 'Bu ağı test et',
			'blocked.stop' => 'Durdur',
			'blocked.sitesToTest' => ({required Object n}) => 'TEST EDİLECEK SİTELER · ${n}',
			'blocked.ofSites' => ({required Object n}) => '${n} siteden',
			'blocked.blockedCount' => ({required Object n}) => '${n} ENGELLİ',
			'blocked.openCount' => ({required Object n}) => '${n} AÇIK',
			'blocked.noneBlocked' => ({required Object network}) => '${network} üzerinde engelli bir şey yok',
			'blocked.openOf' => ({required Object total, required Object open}) => '${total} siteden ${open} açık',
			'blocked.allWork' => 'HEPSİ G VPN İLE ÇALIŞIYOR',
			'blocked.blockedHeading' => 'ENGELLİ',
			'blocked.byKind' => 'TÜRE GÖRE',
			'blocked.worksVpn' => 'VPN ile çalışıyor',
			'blocked.failsVpn' => 'VPN ile de engelli',
			'blocked.checkVpn' => 'G VPN üzerinden kontrol et',
			'blocked.connect' => 'G VPN\'e bağlan',
			'blocked.again' => 'Tekrar test et',
			'blocked.withoutVpn' => 'VPN OLMADAN',
			'blocked.throughVpn' => 'G VPN ÜZERİNDEN',
			'blocked.notChecked' => 'Kontrol edilmedi',
			'blocked.opens' => 'Açılıyor',
			'blocked.stillBlocked' => 'Engelli',
			'blocked.whatHappened' => 'NE OLDU',
			'blocked.countryBlocked' => ({required Object country}) => '${country} ülkesinde engelli site',
			'blocked.countrySub' => 'Gönüllü testlerinin son 30 günde bulduğu',
			'blocked.countryNone' => 'Son 30 günde bildirilen engelli site yok.',
			'blocked.countryUnavailable' => 'Ülke sonuçları yüklenemedi. Bağlantınızı kontrol edin.',
			'blocked.confirmed' => 'ENGELLİ',
			'blocked.oftenFails' => 'SIK HATA',
			'blocked.kinds.social' => 'Sosyal',
			'blocked.kinds.messaging' => 'Mesajlaşma',
			'blocked.kinds.news' => 'Haber',
			'blocked.kinds.video' => 'Video ve müzik',
			'blocked.kinds.privacy' => 'Gizlilik araçları',
			'blocked.how.dns' => 'Yanlış adres',
			'blocked.how.reset' => 'Kesildi',
			'blocked.how.timeout' => 'Yanıt yok',
			'blocked.how.page' => 'Engel sayfası',
			'blocked.how.open' => 'Açık',
			'blocked.fail.noAnswer' => 'yanıt yok',
			'blocked.fail.refused' => 'reddedildi',
			'blocked.fail.cutOff' => ({required Object s}) => '${s} sn sonra kesildi',
			'blocked.fail.wrongCert' => 'yanlış sertifika',
			'blocked.steps.lookup' => 'Ad sorgusu',
			'blocked.steps.connect' => 'Bağlantı',
			'blocked.steps.handshake' => 'Güvenli el sıkışma',
			'blocked.consent.title' => 'İlk testten önce',
			'blocked.consent.body' => 'Test her siteyi bu telefondan, VPN olmadan, bir tarayıcı gibi açar.',
			'blocked.consent.noticeTitle' => 'Fark edilebilir',
			'blocked.consent.notice' => 'Sağlayıcınız bu sitelerin açıldığını görür. Bazı ülkelerde test için bile ziyaret etmek dikkat çekebilir. Yalnızca kendinizi güvende hissettiğiniz yerde test edin.',
			'blocked.consent.ok' => 'Anladım, test et',
			'blocked.someBlocked' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${network} üzerinde ${n} site engelli', ), 
			'blocked.tests' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(n, other: '${n} test', ), 
			_ => null,
		};
	}
}
