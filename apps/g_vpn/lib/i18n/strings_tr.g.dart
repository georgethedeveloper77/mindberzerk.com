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
	@override String sitesSee({required Object ip}) => 'Siteler ${ip} adresini görüyor';
	@override String sitesSeeOrg({required Object ip, required Object org}) => 'Siteler ${ip} adresini görüyor · ${org}';
	@override String get ipFailed => 'IP adresiniz kontrol edilemedi';
	@override String get ipChecking => 'IP adresiniz kontrol ediliyor';
	@override String get themeSystem => 'Tema: telefonu izle';
	@override String get themeLight => 'Tema: açık';
	@override String get themeDark => 'Tema: koyu';
	@override String get free => 'Ücretsiz';
	@override String get pickServer => 'Bir sunucu seçin';
	@override late final _Translations$home$waves$tr waves = _Translations$home$waves$tr._(_root);
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
}

// Path: pro
class _Translations$pro$tr extends Translations$pro$en {
	_Translations$pro$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get owned => 'Pro\'nuz var';
	@override String get waitingPlay => 'Google Play bekleniyor';
	@override String startTrial({required Object days}) => '${days} günlük ücretsiz denemeyi başlat';
	@override String thenYearly({required Object price}) => 'Ardından yılda ${price}. Google Play\'den istediğiniz zaman iptal edin.';
	@override String thenMonthly({required Object price}) => 'Ardından ayda ${price}. Google Play\'den istediğiniz zaman iptal edin.';
	@override String yearlyPrice({required Object price}) => 'Yılda ${price}. Google Play\'den istediğiniz zaman iptal edin.';
	@override String monthlyPrice({required Object price}) => 'Ayda ${price}. Google Play\'den istediğiniz zaman iptal edin.';
	@override String get restore => 'Geri yükle';
	@override String get heroTitle => 'Daha hızlı sunucular,\nbizim işlettiğimiz';
	@override String get heroSubtitle => 'WireGuard. Etkinlik kaydı yok. Hesap yok.';
	@override String get benefitSpeed => 'Tam hız, gönüllü sunucu sınırları yok';
	@override String get benefitKey => 'Anahtar telefonunuzda oluşturulur, asla paylaşılmaz';
	@override String get benefitFree => 'Ücretsiz olan her şey ücretsiz kalır';
	@override String save({required Object pct}) => '%${pct} TASARRUF';
	@override String get yearly => 'Yıllık';
	@override String get monthly => 'Aylık';
	@override String get billedMonthly => 'aylık faturalandırılır';
	@override String daysFree({required Object days}) => '${days} gün ücretsiz';
	@override String perMonth({required Object price}) => 'Ayda ${price}';
	@override String get title => 'G VPN Pro';
	@override String get heroTitleOneLine => 'Bizim işlettiğimiz daha hızlı sunucular';
	@override String get includes => 'İçerik';
	@override String get benefitLogs => 'Sunucularımızda etkinlik kaydı yok';
	@override String get plan => 'Bir plan seçin';
	@override String get renewGeneric => 'Abonelikler iptal edilene kadar otomatik yenilenir. Google Play\'den istediğiniz zaman iptal edin.';
	@override String renewTrial({required Object days, required Object period, required Object price}) => '${days} gün ücretsiz, ardından her ${period} için ${price}. İptal edilene kadar otomatik yenilenir; ücret alınmaması için deneme bitmeden en az bir gün önce Google Play\'den iptal edin.';
	@override String renew({required Object period, required Object price}) => 'Her ${period} için ${price}. İptal edilene kadar otomatik yenilenir; Google Play\'den istediğiniz zaman iptal edin.';
	@override String get year => 'yıl';
	@override String get month => 'ay';
	@override String get manage => 'Aboneliği yönet';
	@override late final _Translations$pro$free$tr free = _Translations$pro$free$tr._(_root);
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
	@override String get shieldSub => 'Zararlı yazılım ve kimlik avı sitelerini engeller';
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
	@override String get wake => 'Cihazı uyandır';
	@override String get mac => 'MAC adresi';
	@override String failed({required Object error}) => 'Gönderilemedi: ${error}';
}

// Path: speed
class _Translations$speed$tr extends Translations$speed$en {
	_Translations$speed$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get info => 'Açık bir araştırma platformu olan M-Lab tarafından ölçülür. Bir test yaklaşık 50 ila 100 MB kullanır.\n\nHerkese açık sonuçlar: M-Lab her testi, geldiği IP adresi dahil, açık araştırma verisi olarak yayımlar.\n\nSağlayıcı karşılaştırması: VPN olmadan yapılan testten sonra G VPN yalnızca üç hız değerini gönderir. Karşılaştırma hizmeti sağlayıcınızı ve şehrinizi bağlantının kendisinden okur ve hiçbir IP adresi saklamaz. Bu sayfanın altındaki anahtarla kapatın.\n\nVPN üzerinden: VPN açıkken tünel üzerinden hızı ölçer ve VPN\'siz son testinizle karşılaştırır.\n\nVideo önizleme: aynı resim, yayın hizmetlerinin açıkladığı bit hızlarına göre bu hızın oynatabileceği çözünürlükte gösterilir. Hiçbir video indirilmez.';
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
	@override String routerName({required Object name}) => 'Modem: ${name}';
	@override String externalIp({required Object ip}) => 'İnternet adresi: ${ip}';
	@override String mapping({required Object proto, required Object host}) => '${proto} → ${host}';
	@override String get upnpOn => 'UPnP açık';
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
	@override String get nothingNew => 'Son taramadan bu yana yeni bir şey yok';
	@override String get takes => 'Yaklaşık 30 saniye sürer';
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
	@override String get notAnnounced => 'Kendini tanıtmadı. Modeminizin cihaz listesi adını gösterebilir.';
	@override String get newBadge => 'YENİ';
	@override String scanning({required Object n}) => '254 adresin ${n} tanesi tarandı';
	@override String get thisNetwork => 'bu ağ';
	@override String newSince({required Object n}) => 'Son taramadan bu yana ${n} yeni';
	@override String showMore({required Object n}) => '${n} tane daha göster';
	@override String ms({required Object n}) => '${n} ms';
	@override String onNetwork({required Object network}) => '${network} ağındaki cihaz';
}

// Path: ping
class _Translations$ping$tr extends Translations$ping$en {
	_Translations$ping$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get info => 'Bir sunucuya gidip dönmenin ne kadar sürdüğü; son bir dakika boyunca her saniye ölçülür.\n\nJitter: her yanıtın bir öncekinden ne kadar farklı olduğu. Yüksek jitter aramaları böler.\n\nKayıp: hiç geri dönmeyen yanıtlar.\n\nNasıl: Android uygulamaları klasik ping gönderemez, bu yüzden her deneme bir bağlantı el sıkışmasını ölçer; bu da aynı gidiş-dönüştür.';
	@override String get askTitle => 'Bir sunucuya ping at';
	@override String get askHint => 'example.com veya 192.168.1.10';
	@override String get cancel => 'İptal';
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
	@override String get unreachable => 'Erişilemiyor';
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
	@override String get internet => 'İnternet bağlantısı';
	@override String get speed => 'Hız testi';
	@override String get speedDesc => 'İndirme ve yükleme hızı, desteklediği video kalitesi.';
	@override String get ping => 'Ping';
	@override String get pingDesc => 'Herhangi bir sunucuya veya modeminize canlı yanıt süresi ve jitter.';
	@override String get status => 'Hizmet durumu';
	@override String get statusDesc => 'WhatsApp, YouTube veya Google buradan erişilebilir mi, yoksa engelli mi?';
	@override String get trace => 'Traceroute';
	@override String get traceDesc => 'Sizinle bir site arasındaki her modem ve her birinin süresi.';
	@override String get security => 'Ağ güvenliği';
	@override String get devices => 'Bu ağdaki cihazlar';
	@override String get devicesDesc => 'Wi-Fi\'nizde başka kimler var: telefonlar, TV\'ler, kameralar ve bilgisayarlar.';
	@override String get router => 'Modem kontrolü';
	@override String get routerDesc => 'Cihazlar modeminizde kendi başlarına port açabiliyor mu (UPnP).';
	@override String get ports => 'Açık portlar';
	@override String get portsDesc => 'Modeminizi veya bir sunucuyu riskli açık portlar için kontrol edin.';
	@override String get utilities => 'Yardımcı araçlar';
	@override String get wifiScanner => 'Wi-Fi tarayıcı';
	@override String get wifiDesc => 'Yakındaki ağlar, güvenlikleri ve en az kalabalık kanal.';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'Bu ağdaki bir bilgisayarı veya NAS\'ı açın.';
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
	@override String bestChannel({required Object n}) => 'En az kalabalık 2,4 GHz kanalı: ${n}';
	@override String weak({required Object n}) => '${n} açık veya zayıf';
	@override String get connectedPrefix => 'Bağlı · ';
	@override String get permissionInfo => 'Android, yakındaki Wi-Fi ağlarını yalnızca konum izni olan uygulamalara gösterir. G VPN bunu yalnızca bu telefondaki ağları listelemek için kullanır.';
	@override String get info => 'Telefonun son taramasındaki ağları listeler. Android dakikada yalnızca birkaç taramaya izin verir, bu yüzden hızlı tekrar tarama aynı listeyi gösterebilir. Önerilen kanal, birbiriyle çakışmayan üç kanal olan 1, 6 ve 11 arasında en az kalabalık olanıdır.';
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
	@override String devicesSub({required Object n}) => 'En fazla ${n} telefon, her biri kendi anahtarıyla';
	@override String get footnote => 'Her telefon, telefonda oluşturulan kendi anahtarını alır. G Servers etkinlik kaydı tutmaz.';
	@override String get leastBusy => 'ŞU AN EN AZ MEŞGUL';
	@override String busyNoLogs({required Object n}) => '%${n} meşgul · kayıt yok';
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

// Path: home.waves
class _Translations$home$waves$tr extends Translations$home$waves$en {
	_Translations$home$waves$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get encrypted => 'ŞİFRELİ';
	@override String get securing => 'KORUNUYOR';
	@override String get exposed => 'AÇIKTA';
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
	@override String get connectedVia => 'BAĞLANTI';
	@override String get protocol => 'PROTOKOL';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, tünel içinde';
	@override String get dnsServer => 'Sunucu, tünel içinde';
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
	@override String get shieldOn => 'Zararlı siteleri engeller';
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
	@override String get shield => 'Kalkan, DNS sorgularını bilinen zararlı yazılım ve kimlik avı sitelerini reddeden Quad9\'a gönderir. Reklamları engellemez ve açıkken sunucunun DNS\'inin yerini alır.';
	@override String get autoConnect => 'Otomatik bağlanma: seçtiğiniz WireGuard sunucusunu kullanır. Elle bağlantıyı kesmek, başka bir ağa katılana kadar onu duraklatır.';
	@override String get apps => 'Doğrudan uygulamalar: VPN dışında kalan uygulamalar doğrudan bağlanır. Bankalar VPN adreslerini sık sık engeller, bu yüzden VPN üzerinden ödemeler başarısız olabilir.';
	@override String get reconnect => 'Kalkanı veya uygulamaları değiştirmek VPN\'i kısa süreliğine yeniden bağlar.';
	@override String get stay => 'Bağlı kal: bazı telefonlar pil tasarrufu için arka plandaki uygulamaları durdurur. Her zaman açık VPN ve kısıtlamasız pil ayarı G VPN\'in çalışmasını sağlar.';
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
			'home.sitesSee' => ({required Object ip}) => 'Siteler ${ip} adresini görüyor',
			'home.sitesSeeOrg' => ({required Object ip, required Object org}) => 'Siteler ${ip} adresini görüyor · ${org}',
			'home.ipFailed' => 'IP adresiniz kontrol edilemedi',
			'home.ipChecking' => 'IP adresiniz kontrol ediliyor',
			'home.themeSystem' => 'Tema: telefonu izle',
			'home.themeLight' => 'Tema: açık',
			'home.themeDark' => 'Tema: koyu',
			'home.free' => 'Ücretsiz',
			'home.pickServer' => 'Bir sunucu seçin',
			'home.waves.encrypted' => 'ŞİFRELİ',
			'home.waves.securing' => 'KORUNUYOR',
			'home.waves.exposed' => 'AÇIKTA',
			'home.network.title' => 'BU AĞ',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Çevrimdışı',
			'home.network.showName' => 'Adı göster',
			'home.network.scanFailed' => 'Tarama başarısız. Ağ değiştiğinde tekrar çalışır.',
			'home.card.connectedVia' => 'BAĞLANTI',
			'home.card.protocol' => 'PROTOKOL',
			'home.card.dns' => 'DNS',
			'home.card.dnsQuad9' => 'Quad9, tünel içinde',
			'home.card.dnsServer' => 'Sunucu, tünel içinde',
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
			'home.tiles.shieldOn' => 'Zararlı siteleri engeller',
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
			'pro.owned' => 'Pro\'nuz var',
			'pro.waitingPlay' => 'Google Play bekleniyor',
			'pro.startTrial' => ({required Object days}) => '${days} günlük ücretsiz denemeyi başlat',
			'pro.thenYearly' => ({required Object price}) => 'Ardından yılda ${price}. Google Play\'den istediğiniz zaman iptal edin.',
			'pro.thenMonthly' => ({required Object price}) => 'Ardından ayda ${price}. Google Play\'den istediğiniz zaman iptal edin.',
			'pro.yearlyPrice' => ({required Object price}) => 'Yılda ${price}. Google Play\'den istediğiniz zaman iptal edin.',
			'pro.monthlyPrice' => ({required Object price}) => 'Ayda ${price}. Google Play\'den istediğiniz zaman iptal edin.',
			'pro.restore' => 'Geri yükle',
			'pro.heroTitle' => 'Daha hızlı sunucular,\nbizim işlettiğimiz',
			'pro.heroSubtitle' => 'WireGuard. Etkinlik kaydı yok. Hesap yok.',
			'pro.benefitSpeed' => 'Tam hız, gönüllü sunucu sınırları yok',
			'pro.benefitKey' => 'Anahtar telefonunuzda oluşturulur, asla paylaşılmaz',
			'pro.benefitFree' => 'Ücretsiz olan her şey ücretsiz kalır',
			'pro.save' => ({required Object pct}) => '%${pct} TASARRUF',
			'pro.yearly' => 'Yıllık',
			'pro.monthly' => 'Aylık',
			'pro.billedMonthly' => 'aylık faturalandırılır',
			'pro.daysFree' => ({required Object days}) => '${days} gün ücretsiz',
			'pro.perMonth' => ({required Object price}) => 'Ayda ${price}',
			'pro.title' => 'G VPN Pro',
			'pro.heroTitleOneLine' => 'Bizim işlettiğimiz daha hızlı sunucular',
			'pro.includes' => 'İçerik',
			'pro.benefitLogs' => 'Sunucularımızda etkinlik kaydı yok',
			'pro.plan' => 'Bir plan seçin',
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
			'rules.title' => 'Kurallar',
			'rules.info.shield' => 'Kalkan, DNS sorgularını bilinen zararlı yazılım ve kimlik avı sitelerini reddeden Quad9\'a gönderir. Reklamları engellemez ve açıkken sunucunun DNS\'inin yerini alır.',
			'rules.info.autoConnect' => 'Otomatik bağlanma: seçtiğiniz WireGuard sunucusunu kullanır. Elle bağlantıyı kesmek, başka bir ağa katılana kadar onu duraklatır.',
			'rules.info.apps' => 'Doğrudan uygulamalar: VPN dışında kalan uygulamalar doğrudan bağlanır. Bankalar VPN adreslerini sık sık engeller, bu yüzden VPN üzerinden ödemeler başarısız olabilir.',
			'rules.info.reconnect' => 'Kalkanı veya uygulamaları değiştirmek VPN\'i kısa süreliğine yeniden bağlar.',
			'rules.info.stay' => 'Bağlı kal: bazı telefonlar pil tasarrufu için arka plandaki uygulamaları durdurur. Her zaman açık VPN ve kısıtlamasız pil ayarı G VPN\'in çalışmasını sağlar.',
			'rules.protection' => 'Koruma',
			'rules.shield' => 'Kalkan',
			'rules.shieldSub' => 'Zararlı yazılım ve kimlik avı sitelerini engeller',
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
			'wol.wake' => 'Cihazı uyandır',
			'wol.mac' => 'MAC adresi',
			'wol.failed' => ({required Object error}) => 'Gönderilemedi: ${error}',
			'speed.info' => 'Açık bir araştırma platformu olan M-Lab tarafından ölçülür. Bir test yaklaşık 50 ila 100 MB kullanır.\n\nHerkese açık sonuçlar: M-Lab her testi, geldiği IP adresi dahil, açık araştırma verisi olarak yayımlar.\n\nSağlayıcı karşılaştırması: VPN olmadan yapılan testten sonra G VPN yalnızca üç hız değerini gönderir. Karşılaştırma hizmeti sağlayıcınızı ve şehrinizi bağlantının kendisinden okur ve hiçbir IP adresi saklamaz. Bu sayfanın altındaki anahtarla kapatın.\n\nVPN üzerinden: VPN açıkken tünel üzerinden hızı ölçer ve VPN\'siz son testinizle karşılaştırır.\n\nVideo önizleme: aynı resim, yayın hizmetlerinin açıkladığı bit hızlarına göre bu hızın oynatabileceği çözünürlükte gösterilir. Hiçbir video indirilmez.',
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
			'router.routerName' => ({required Object name}) => 'Modem: ${name}',
			'router.externalIp' => ({required Object ip}) => 'İnternet adresi: ${ip}',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} → ${host}',
			'router.upnpOn' => 'UPnP açık',
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
			'devices.nothingNew' => 'Son taramadan bu yana yeni bir şey yok',
			'devices.takes' => 'Yaklaşık 30 saniye sürer',
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
			'devices.notAnnounced' => 'Kendini tanıtmadı. Modeminizin cihaz listesi adını gösterebilir.',
			'devices.newBadge' => 'YENİ',
			'devices.scanning' => ({required Object n}) => '254 adresin ${n} tanesi tarandı',
			'devices.thisNetwork' => 'bu ağ',
			'devices.newSince' => ({required Object n}) => 'Son taramadan bu yana ${n} yeni',
			'devices.showMore' => ({required Object n}) => '${n} tane daha göster',
			'devices.ms' => ({required Object n}) => '${n} ms',
			'devices.onNetwork' => ({required Object network}) => '${network} ağındaki cihaz',
			'ping.info' => 'Bir sunucuya gidip dönmenin ne kadar sürdüğü; son bir dakika boyunca her saniye ölçülür.\n\nJitter: her yanıtın bir öncekinden ne kadar farklı olduğu. Yüksek jitter aramaları böler.\n\nKayıp: hiç geri dönmeyen yanıtlar.\n\nNasıl: Android uygulamaları klasik ping gönderemez, bu yüzden her deneme bir bağlantı el sıkışmasını ölçer; bu da aynı gidiş-dönüştür.',
			'ping.askTitle' => 'Bir sunucuya ping at',
			'ping.askHint' => 'example.com veya 192.168.1.10',
			'ping.cancel' => 'İptal',
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
			'status.unreachable' => 'Erişilemiyor',
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
			'tools.internet' => 'İnternet bağlantısı',
			'tools.speed' => 'Hız testi',
			'tools.speedDesc' => 'İndirme ve yükleme hızı, desteklediği video kalitesi.',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'Herhangi bir sunucuya veya modeminize canlı yanıt süresi ve jitter.',
			'tools.status' => 'Hizmet durumu',
			'tools.statusDesc' => 'WhatsApp, YouTube veya Google buradan erişilebilir mi, yoksa engelli mi?',
			'tools.trace' => 'Traceroute',
			'tools.traceDesc' => 'Sizinle bir site arasındaki her modem ve her birinin süresi.',
			'tools.security' => 'Ağ güvenliği',
			'tools.devices' => 'Bu ağdaki cihazlar',
			'tools.devicesDesc' => 'Wi-Fi\'nizde başka kimler var: telefonlar, TV\'ler, kameralar ve bilgisayarlar.',
			'tools.router' => 'Modem kontrolü',
			'tools.routerDesc' => 'Cihazlar modeminizde kendi başlarına port açabiliyor mu (UPnP).',
			'tools.ports' => 'Açık portlar',
			'tools.portsDesc' => 'Modeminizi veya bir sunucuyu riskli açık portlar için kontrol edin.',
			'tools.utilities' => 'Yardımcı araçlar',
			'tools.wifiScanner' => 'Wi-Fi tarayıcı',
			'tools.wifiDesc' => 'Yakındaki ağlar, güvenlikleri ve en az kalabalık kanal.',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Bu ağdaki bir bilgisayarı veya NAS\'ı açın.',
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
			_ => null,
		} ?? switch (path) {
			'ports.normal' => 'NORMAL',
			'ports.info' => ({required Object n}) => 'Ev modemleri ve cihazlarında önemli olan ${n} portu kontrol eder ve açık olan her birini açıklar.\n\nYalnızca sahibi olduğunuz veya yönettiğiniz cihazları ve sunucuları kontrol edin.',
			'ports.checking' => ({required Object n}) => '${n} port kontrol ediliyor',
			'ports.yourRouter' => ({required Object ip}) => 'Modeminiz: ${ip}',
			'ports.noneOpen' => ({required Object host}) => '${host} üzerinde açık yaygın port yok.',
			'wifi.title' => 'Wi-Fi tarayıcı',
			'wifi.allow' => 'Wi-Fi taramasına izin ver',
			'wifi.needsPermission' => 'Konum izni gerekiyor.',
			'wifi.scanning' => 'Taranıyor',
			'wifi.again' => 'Tekrar tara',
			'wifi.failed' => 'Tarama başarısız',
			'wifi.none' => 'Ağ bulunamadı. Konum kapalı olabilir.',
			'wifi.hidden' => 'Gizli ağ',
			'wifi.nearby' => ({required Object n}) => 'Yakında ${n} ağ',
			'wifi.bestChannel' => ({required Object n}) => 'En az kalabalık 2,4 GHz kanalı: ${n}',
			'wifi.weak' => ({required Object n}) => '${n} açık veya zayıf',
			'wifi.connectedPrefix' => 'Bağlı · ',
			'wifi.permissionInfo' => 'Android, yakındaki Wi-Fi ağlarını yalnızca konum izni olan uygulamalara gösterir. G VPN bunu yalnızca bu telefondaki ağları listelemek için kullanır.',
			'wifi.info' => 'Telefonun son taramasındaki ağları listeler. Android dakikada yalnızca birkaç taramaya izin verir, bu yüzden hızlı tekrar tarama aynı listeyi gösterebilir. Önerilen kanal, birbiriyle çakışmayan üç kanal olan 1, 6 ve 11 arasında en az kalabalık olanıdır.',
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
			'gs.devicesSub' => ({required Object n}) => 'En fazla ${n} telefon, her biri kendi anahtarıyla',
			'gs.footnote' => 'Her telefon, telefonda oluşturulan kendi anahtarını alır. G Servers etkinlik kaydı tutmaz.',
			'gs.leastBusy' => 'ŞU AN EN AZ MEŞGUL',
			'gs.busyNoLogs' => ({required Object n}) => '%${n} meşgul · kayıt yok',
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
			_ => null,
		};
	}
}
