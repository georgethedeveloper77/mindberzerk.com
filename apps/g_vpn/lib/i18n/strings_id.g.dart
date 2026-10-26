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
class TranslationsId extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsId({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.id,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <id>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsId _root = this; // ignore: unused_field

	@override 
	TranslationsId $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsId(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$id common = _Translations$common$id._(_root);
	@override late final _Translations$nav$id nav = _Translations$nav$id._(_root);
	@override late final _Translations$home$id home = _Translations$home$id._(_root);
	@override late final _Translations$servers$id servers = _Translations$servers$id._(_root);
	@override late final _Translations$pro$id pro = _Translations$pro$id._(_root);
	@override late final _Translations$rules$id rules = _Translations$rules$id._(_root);
	@override late final _Translations$apps$id apps = _Translations$apps$id._(_root);
	@override late final _Translations$location$id location = _Translations$location$id._(_root);
	@override late final _Translations$addServer$id addServer = _Translations$addServer$id._(_root);
	@override late final _Translations$button$id button = _Translations$button$id._(_root);
	@override late final _Translations$wol$id wol = _Translations$wol$id._(_root);
	@override late final _Translations$speed$id speed = _Translations$speed$id._(_root);
	@override late final _Translations$router$id router = _Translations$router$id._(_root);
	@override late final _Translations$network$id network = _Translations$network$id._(_root);
	@override late final _Translations$devices$id devices = _Translations$devices$id._(_root);
	@override late final _Translations$ping$id ping = _Translations$ping$id._(_root);
	@override late final _Translations$status$id status = _Translations$status$id._(_root);
	@override late final _Translations$tools$id tools = _Translations$tools$id._(_root);
	@override late final _Translations$trace$id trace = _Translations$trace$id._(_root);
	@override late final _Translations$ports$id ports = _Translations$ports$id._(_root);
	@override late final _Translations$wifi$id wifi = _Translations$wifi$id._(_root);
	@override late final _Translations$errors$id errors = _Translations$errors$id._(_root);
	@override late final _Translations$scan$id scan = _Translations$scan$id._(_root);
	@override late final _Translations$legal$id legal = _Translations$legal$id._(_root);
	@override late final _Translations$update$id update = _Translations$update$id._(_root);
	@override late final _Translations$details$id details = _Translations$details$id._(_root);
	@override late final _Translations$share$id share = _Translations$share$id._(_root);
	@override late final _Translations$add$id add = _Translations$add$id._(_root);
	@override late final _Translations$backup$id backup = _Translations$backup$id._(_root);
	@override late final _Translations$gs$id gs = _Translations$gs$id._(_root);
	@override late final _Translations$map$id map = _Translations$map$id._(_root);
	@override late final _Translations$stats$id stats = _Translations$stats$id._(_root);
	@override late final _Translations$recents$id recents = _Translations$recents$id._(_root);
	@override late final _Translations$presets$id presets = _Translations$presets$id._(_root);
	@override late final _Translations$shield$id shield = _Translations$shield$id._(_root);
	@override late final _Translations$checks$id checks = _Translations$checks$id._(_root);
	@override late final _Translations$toolSettings$id toolSettings = _Translations$toolSettings$id._(_root);
	@override late final _Translations$security$id security = _Translations$security$id._(_root);
	@override late final _Translations$providers$id providers = _Translations$providers$id._(_root);
	@override late final _Translations$alerts$id alerts = _Translations$alerts$id._(_root);
	@override late final _Translations$report$id report = _Translations$report$id._(_root);
	@override late final _Translations$breaches$id breaches = _Translations$breaches$id._(_root);
	@override late final _Translations$blocked$id blocked = _Translations$blocked$id._(_root);
}

// Path: common
class _Translations$common$id extends Translations$common$en {
	_Translations$common$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get gotIt => 'Mengerti';
	@override String get about => 'Tentang';
	@override String get connect => 'Hubungkan';
	@override String get connected => 'Terhubung';
	@override String get retry => 'Coba lagi';
	@override String get ok => 'OK';
	@override String get remove => 'Hapus';
	@override String get cancel => 'Batal';
	@override String get continueLabel => 'Lanjutkan';
	@override String get notNow => 'Nanti saja';
	@override String get openSettings => 'Buka setelan';
	@override String get close => 'Tutup';
	@override String get off => 'Mati';
	@override String get changesReconnect => 'Perubahan akan menyambungkan ulang VPN';
}

// Path: nav
class _Translations$nav$id extends Translations$nav$en {
	_Translations$nav$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get vpn => 'VPN';
	@override String get servers => 'Server';
	@override String get tools => 'Alat';
	@override String get rules => 'Aturan';
	@override String get pro => 'Pro';
}

// Path: home
class _Translations$home$id extends Translations$home$en {
	_Translations$home$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$status$id status = _Translations$home$status$id._(_root);
	@override String resumesAt({required Object time}) => 'Lanjut pukul ${time} · ketuk untuk lanjut sekarang';
	@override String get ipFailed => 'Tidak dapat memeriksa IP Anda';
	@override String get ipChecking => 'Memeriksa IP Anda';
	@override String get themeSystem => 'Tema: ikuti ponsel';
	@override String get themeLight => 'Tema: terang';
	@override String get themeDark => 'Tema: gelap';
	@override String get free => 'Gratis';
	@override String get pickServer => 'Pilih server';
	@override late final _Translations$home$network$id network = _Translations$home$network$id._(_root);
	@override late final _Translations$home$card$id card = _Translations$home$card$id._(_root);
	@override late final _Translations$home$tiles$id tiles = _Translations$home$tiles$id._(_root);
	@override late final _Translations$home$fastest$id fastest = _Translations$home$fastest$id._(_root);
	@override late final _Translations$home$ip$id ip = _Translations$home$ip$id._(_root);
}

// Path: servers
class _Translations$servers$id extends Translations$servers$en {
	_Translations$servers$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Server';
	@override String get aboutServers => 'Tentang server';
	@override late final _Translations$servers$tabs$id tabs = _Translations$servers$tabs$id._(_root);
	@override late final _Translations$servers$sheet$id sheet = _Translations$servers$sheet$id._(_root);
	@override late final _Translations$servers$badges$id badges = _Translations$servers$badges$id._(_root);
	@override late final _Translations$servers$filters$id filters = _Translations$servers$filters$id._(_root);
	@override String get loadFailed => 'Tidak dapat memuat daftar';
	@override String get noServers => 'Belum ada server saat ini';
	@override String get best => 'TERBAIK UNTUK ANDA SAAT INI';
	@override String get topRanked => 'Peringkat teratas saat ini';
	@override String get addHeading => 'TAMBAH SERVER';
	@override String get scanQr => 'Pindai QR';
	@override String get importFile => 'Impor file';
	@override String get paste => 'Tempel';
	@override late final _Translations$servers$own$id own = _Translations$servers$own$id._(_root);
	@override String get configBroken => 'Konfigurasi perlu diperiksa';
	@override String get connectedBadge => 'TERHUBUNG';
	@override String get scannedServer => 'Server hasil pindaian';
	@override String get scanFailedTitle => 'Tidak dapat memindai';
	@override String get scanFailedBody => 'Pemindai tidak tersedia di ponsel ini.';
	@override String get importFailedTitle => 'Tidak dapat mengimpor';
	@override String get importFailedBody => 'File itu tidak dapat dibaca.';
	@override String get renameTitle => 'Ganti nama server';
	@override String get nameHint => 'Nama, misalnya Router rumah';
	@override String get save => 'Simpan';
	@override String get rename => 'Ganti nama';
	@override String get disconnect => 'Putuskan';
	@override String get more => 'Opsi lainnya';
	@override String get justNow => 'baru saja';
	@override String minutesAgo({required Object n}) => '${n} mnt lalu';
	@override String hoursAgo({required Object n}) => '${n} jam lalu';
	@override String daysAgo({required Object n}) => '${n} hari lalu';
	@override String get neverUsed => 'Belum pernah dipakai';
	@override String lastUsed({required Object when}) => 'Terakhir dipakai ${when}';
	@override String get disconnectFirst => 'Putuskan dulu untuk menghapusnya';
	@override String get removeConfirm => 'Hapus server ini dari G VPN? Setelannya dihapus dari ponsel ini; server itu sendiri tidak berubah.';
	@override String get gTab => 'G Servers';
	@override String get search => 'Cari negara';
	@override String get noMatch => 'Tidak ada server yang cocok.';
	@override String bestPing({required Object ms}) => 'terbaik ${ms} ms';
	@override String get bestTag => 'TERBAIK';
	@override String get ownHero => 'Server milik kami';
	@override String get ownHeroSub => 'Lebih cepat, privat, tiap ponsel punya kunci sendiri';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} server',
	);
	@override String showAll({required Object n}) => 'Tampilkan semua ${n}';
	@override String get showFewer => 'Tampilkan lebih sedikit';
	@override String get fastTab => 'Cepat';
	@override String get fastestFree => 'Gratis tercepat';
}

// Path: pro
class _Translations$pro$id extends Translations$pro$en {
	_Translations$pro$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get owned => 'Anda punya Pro';
	@override String get waitingPlay => 'Menunggu Google Play';
	@override String startTrial({required Object days}) => 'Mulai uji coba gratis ${days} hari';
	@override String get restore => 'Pulihkan';
	@override String save({required Object pct}) => 'HEMAT ${pct}%';
	@override String get yearly => 'Tahunan';
	@override String get monthly => 'Bulanan';
	@override String get billedMonthly => 'ditagih bulanan';
	@override String daysFree({required Object days}) => '${days} hari gratis';
	@override String perMonth({required Object price}) => '${price} per bulan';
	@override String get title => 'G VPN Pro';
	@override String get renewGeneric => 'Langganan diperpanjang otomatis hingga dibatalkan. Batalkan kapan saja di Google Play.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} hari gratis, lalu ${price} per ${period}. Diperpanjang otomatis hingga dibatalkan; batalkan di Google Play paling lambat sehari sebelum uji coba berakhir agar tidak ditagih.';
	@override String renew({required Object price, required Object period}) => '${price} per ${period}. Diperpanjang otomatis hingga dibatalkan; batalkan kapan saja di Google Play.';
	@override String get year => 'tahun';
	@override String get month => 'bulan';
	@override String get manage => 'Kelola langganan';
	@override late final _Translations$pro$free$id free = _Translations$pro$free$id._(_root);
	@override String get heroLine => 'Server cepat milik kami, dan semua pengecekan tanpa batas';
	@override String get start => 'Mulai Pro';
	@override String get compareFree => 'GRATIS';
	@override String get comparePro => 'PRO';
	@override String get rowFreeServers => 'Server gratis';
	@override String get rowTools => 'Tes kecepatan, alat, cek Wi-Fi';
	@override String get rowGServers => 'G Servers, tanpa log';
	@override String get rowLinks => 'Cek tautan';
	@override String linksFree({required Object n}) => '${n} per bulan';
	@override String get unlimited => 'Tanpa batas';
}

// Path: rules
class _Translations$rules$id extends Translations$rules$en {
	_Translations$rules$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aturan';
	@override late final _Translations$rules$info$id info = _Translations$rules$info$id._(_root);
	@override String get protection => 'Perlindungan';
	@override String get shield => 'Perisai';
	@override String get privateDns => 'Perisai tanpa VPN';
	@override String get privateDnsSub => 'Salin dns.quad9.net untuk DNS Pribadi';
	@override String get privateDnsCopied => 'dns.quad9.net disalin';
	@override String get privateDnsHow => 'Buka Setelan, cari DNS Pribadi, pilih "Nama host penyedia DNS pribadi", lalu tempelkan.';
	@override String get stay => 'Tetap terhubung';
	@override String get alwaysOn => 'VPN selalu aktif';
	@override String get alwaysOnSub => 'Android memulai ulang G VPN jika berhenti';
	@override String get battery => 'Baterai';
	@override String get batteryOk => 'Tanpa batasan';
	@override String get batteryRestricted => 'Dibatasi: bisa berhenti di latar belakang';
	@override String get autoConnect => 'Sambung otomatis';
	@override String get autoOff => 'Mati';
	@override String get autoOffSub => 'Hanya saat Anda mengetuk';
	@override String get autoOpen => 'Wi-Fi publik';
	@override String get autoOpenSub => 'Jaringan terbuka, WEP, atau dengan halaman masuk';
	@override String get autoAny => 'Semua Wi-Fi';
	@override String get autoAnySub => 'Jaringan Wi-Fi apa pun';
	@override String get apps => 'Aplikasi';
	@override String get appsDirect => 'Aplikasi langsung';
	@override String get appsNone => 'Semua aplikasi memakai VPN';
	@override String appsSome({required Object n}) => '${n} aplikasi tanpa VPN';
	@override String get appearance => 'Tampilan';
	@override String get themePhone => 'Ponsel';
	@override String get themeLight => 'Terang';
	@override String get themeDark => 'Gelap';
	@override String get about => 'Tentang';
}

// Path: apps
class _Translations$apps$id extends Translations$apps$en {
	_Translations$apps$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aplikasi langsung';
	@override String get sheetSubtitle => 'Aplikasi pilihan terhubung tanpa VPN. Lainnya tetap terlindungi.';
	@override String get whyTitle => 'Mengapa mengecualikan aplikasi';
	@override String get whyBody => 'Bank dan aplikasi pembayaran sering memblokir alamat VPN, jadi pembayaran bisa gagal lewat VPN. Beberapa layanan lokal hanya berfungsi dari negara Anda sendiri.';
	@override String get favouritesBody => 'Beri bintang pada aplikasi yang sering Anda ubah; aplikasi itu tetap di atas.';
	@override String get whileConnected => 'Saat terhubung';
	@override String get whileConnectedBody => 'Mengubah daftar ini akan menyambungkan ulang VPN sebentar.';
	@override String search({required Object n}) => 'Cari ${n} aplikasi';
	@override String get skipping => 'Tanpa VPN';
	@override String get skippingNone => 'Tidak ada. Semua aplikasi melewati VPN.';
	@override String protectAgain({required Object app}) => 'Lindungi ${app} lagi';
	@override String get banking => 'Bank dan pembayaran';
	@override String bankingFound({required Object n}) => '${n} ditemukan yang mungkin memblokir VPN';
	@override String get addAll => 'Tambah semua';
	@override String get favourites => 'Favorit';
	@override String get all => 'Semua aplikasi';
	@override String found({required Object n}) => '${n} ditemukan';
	@override String get noMatch => 'Tidak ada aplikasi yang cocok.';
	@override String showAll({required Object n}) => 'Tampilkan semua ${n}';
	@override String get skips => 'Tanpa VPN';
	@override String get unstar => 'Hapus dari favorit';
	@override String get star => 'Tambah ke favorit';
}

// Path: location
class _Translations$location$id extends Translations$location$en {
	_Translations$location$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Izinkan lokasi untuk Wi-Fi';
	@override String get useHome => 'Tampilkan nama Wi-Fi di Beranda';
	@override String get useScan => 'Pindai jaringan dan kanal di sekitar';
	@override String get private => 'Tetap di ponsel ini. Lokasi Anda tidak pernah dikumpulkan.';
	@override String get switchTitle => 'Aktifkan Lokasi';
	@override String get switchBody => 'Android menyembunyikan nama Wi-Fi saat Lokasi mati';
}

// Path: addServer
class _Translations$addServer$id extends Translations$addServer$en {
	_Translations$addServer$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get clipboardEmpty => 'Papan klip kosong.';
	@override String get title => 'Tambah server Anda';
	@override String get body => 'Tempelkan konfigurasi WireGuard dari router, VPS, atau server rumah Anda.';
	@override String get nameHint => 'Nama, misalnya Router rumah';
	@override String get paste => 'Tempel';
	@override String get save => 'Simpan server';
	@override String notWireguard({required Object error}) => 'Ini bukan konfigurasi WireGuard: ${error}';
}

// Path: button
class _Translations$button$id extends Translations$button$en {
	_Translations$button$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get stop => 'Hentikan';
	@override String get connecting => 'Menghubungkan';
	@override String get stopping => 'Memutuskan';
	@override String get connect => 'Hubungkan';
	@override String get disconnect => 'Putuskan';
}

// Path: wol
class _Translations$wol$id extends Translations$wol$en {
	_Translations$wol$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get info => 'Menyalakan komputer atau NAS di Wi-Fi ini, jika Wake on LAN aktif di setelannya. Ponsel Anda harus di jaringan yang sama; matikan VPN terlebih dahulu.';
	@override String get badMac => 'Itu bukan alamat MAC. Bentuknya seperti AA:BB:CC:DD:EE:FF.';
	@override String get sent => 'Sinyal dikirim. Perangkat seharusnya menyala dalam satu menit.';
	@override String get title => 'Wake on LAN';
	@override String get mac => 'Alamat MAC';
	@override String failed({required Object error}) => 'Tidak dapat mengirim: ${error}';
	@override String get computer => 'Komputer';
	@override String get pick => 'Pilih perangkat untuk dinyalakan';
	@override String waking({required Object name}) => 'Menyalakan ${name}';
	@override String get yours => 'PERANGKAT ANDA';
	@override String wakeNamed({required Object name}) => 'Nyalakan ${name}';
	@override String get removeHint => 'Tahan perangkat untuk menghapusnya';
	@override String get add => 'TAMBAH PERANGKAT';
	@override String get name => 'Nama';
	@override String get saveWake => 'Simpan dan nyalakan';
}

// Path: speed
class _Translations$speed$id extends Translations$speed$en {
	_Translations$speed$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get download => 'Unduh';
	@override String get upload => 'Unggah';
	@override String get finding => 'Mencari server';
	@override String get throughVpn => 'Melalui VPN';
	@override String get directNoVpn => 'Langsung, tanpa VPN';
	@override String get title => 'Tes kecepatan';
	@override String get stop => 'Hentikan';
	@override String get start => 'Mulai tes';
	@override String get again => 'Tes lagi';
	@override String get viaVpn => 'Lewat VPN';
	@override String get direct => 'Langsung';
	@override String get mbps => 'Mbps';
	@override String get ping => 'PING';
	@override String get vsDirect => 'VS LANGSUNG';
	@override String get compare => 'Bandingkan dengan penyedia sekitar';
	@override String get compareSub => 'Hanya membagikan kecepatan, tidak pernah IP Anda';
	@override String get tierTv => 'TV besar';
	@override String get tierLaptopLarge => 'Laptop besar';
	@override String get tierTablet => 'Tablet dan laptop';
	@override String get tierPhone => 'Ponsel';
	@override String get tierSmallPhone => 'Ponsel kecil';
	@override String get tierCalls => 'Panggilan dan audio';
	@override String get messagingOnly => 'Hanya perpesanan';
	@override String get videoQuality => 'Kualitas video';
	@override String get preview => 'PRATINJAU';
	@override String get history => 'Riwayat';
	@override String get clear => 'Hapus';
	@override String get viaVpnLower => 'lewat VPN';
	@override String get directLower => 'langsung';
	@override String get gradeA => 'Beberapa streaming 4K dan panggilan video sekaligus';
	@override String get gradeB => 'Streaming HD dan panggilan video lancar';
	@override String get gradeC => 'Satu streaming HD; panggilan bisa tersendat saat ramai';
	@override String get gradeD => 'Menjelajah dan perpesanan; video tersendat';
	@override String get yourCountry => 'negara Anda';
	@override String get median => 'Median unduhan, 30 hari terakhir';
	@override String get fromUsers => 'Mbps · dari tes pengguna G VPN';
	@override String get costLittle => 'Hanya sedikit kecepatan hilang karena VPN';
	@override String get costNoticeable => 'Terasa lebih lambat daripada langsung';
	@override String get costMuch => 'Jauh lebih lambat. Coba server lain';
	@override String get ofDirect => 'dari kecepatan langsung Anda';
	@override String get none => 'tidak ada';
	@override String ms({required Object n}) => '${n} md';
	@override String previewTier({required Object tier}) => 'PRATINJAU · ${tier}';
	@override String streamsUpTo({required Object tier, required Object who}) => 'Streaming hingga ${tier} · ${who}';
	@override String today({required Object time}) => 'Hari ini, ${time}';
	@override String tests({required Object n}) => '${n} tes';
	@override String gradeVpn({required Object label}) => '${label} melalui VPN';
	@override String gradeIsp({required Object label, required Object isp}) => '${label} di ${isp}';
	@override String notEnough({required Object isp}) => 'Belum cukup tes untuk ${isp}';
	@override String get yourProvider => 'penyedia Anda';
	@override String rankLine({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} di ${where}: ${rank} dari ${of}';
	@override String costLine({required Object note, required Object mbps}) => '${note} · langsung ${mbps} Mbps';
	@override String mbpsValue({required Object v}) => '${v} Mbps';
	@override String get gradeExcellent => 'Luar biasa';
	@override String get gradeVeryGood => 'Sangat baik';
	@override String get gradeGood => 'Baik';
	@override String get gradeFair => 'Cukup';
	@override String get gradeSlow => 'Lambat';
	@override String get gradeVerySlow => 'Sangat lambat';
}

// Path: router
class _Translations$router$id extends Translations$router$en {
	_Translations$router$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get info => 'Menanyakan router Anda, lewat UPnP, apakah perangkat boleh membuka port ke internet sendiri, dan menampilkan port yang sudah dibuka. Hanya membaca dan tidak mengubah apa pun. Jika tidak ada yang membutuhkan UPnP (beberapa konsol game butuh), mematikannya di setelan router lebih aman.';
	@override String get title => 'Periksa router';
	@override String get asking => 'Menanyakan router';
	@override String get again => 'Periksa lagi';
	@override String get check => 'Periksa router';
	@override String get off => 'UPnP mati';
	@override String get offBody => 'Perangkat tidak dapat membuka port sendiri.';
	@override String get onBody => 'Saat ini tidak ada port yang dibuka lewat UPnP.';
	@override String get checkEach => 'Pastikan Anda mengenali setiap port.';
	@override String get cgnat => 'Alamat penyedia bersama: tidak dapat dijangkau dari internet.';
	@override String get noDescription => 'Tanpa deskripsi';
	@override String opened({required Object n}) => '${n} port dibuka oleh perangkat';
	@override String mapping({required Object proto, required Object host}) => '${proto} ke ${host}';
	@override String get upnpOn => 'UPnP aktif';
	@override String get routerLabel => 'Router';
	@override String get internetAddress => 'Alamat internet';
	@override String get openedBy => 'Dibuka oleh perangkat';
}

// Path: network
class _Translations$network$id extends Translations$network$en {
	_Translations$network$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jaringan ini';
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Data seluler';
	@override String get ethernet => 'Ethernet';
	@override String get offline => 'Offline';
	@override String get risky => 'Jaringan berisiko. Hubungkan VPN di sini.';
	@override String get review => 'Perlu diperiksa sebelum Anda mempercayainya.';
	@override String get covered => 'Dilindungi VPN.';
	@override String get safe => 'Jaringan ini tampak aman.';
	@override String get mobileSentence => 'Data seluler.';
	@override String get notConnected => 'Tidak terhubung.';
	@override String get showName => 'Tampilkan nama';
	@override String get sitesSee => 'Situs melihat';
	@override String get provider => 'Penyedia';
	@override String get location => 'Lokasi';
	@override String get couldNotCheck => 'Tidak dapat memeriksa';
	@override String get checking => 'Memeriksa';
	@override String get signal => 'Sinyal';
	@override String get linkSpeed => 'Kecepatan tautan';
	@override String get gateway => 'Gateway';
	@override String get none => 'Tidak ada';
	@override String get privateDns => 'DNS Pribadi';
	@override String get automatic => 'Otomatis';
	@override String get off => 'Mati';
	@override String get metered => 'Berkuota';
	@override String get yes => 'Ya';
	@override String get no => 'Tidak';
	@override String readFailed({required Object error}) => 'Tidak dapat membaca jaringan: ${error}';
}

// Path: devices
class _Translations$devices$id extends Translations$devices$en {
	_Translations$devices$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get info => 'Mengetuk setiap alamat dalam jangkauan Wi-Fi Anda dan meminta perangkat memperkenalkan diri. Perangkat yang menolak tetap dihitung: penolakan membuktikan perangkat itu ada.\n\nNama: dari yang dipublikasikan perangkat (Bonjour, UPnP, nama Windows) dan dari router Anda.\n\nPerangkat tak dikenal: Android menyembunyikan alamat perangkat keras dari aplikasi, jadi perangkat diam tanpa nama tidak dapat dikenali. Periksa daftar perangkat di router Anda untuk itu.\n\nBaru: perangkat yang tidak terlihat pada pindaian terakhir jaringan ini.';
	@override String get needWifi => 'Hubungkan ke jaringan Wi-Fi terlebih dahulu.';
	@override String get title => 'Perangkat';
	@override String get again => 'Pindai lagi';
	@override String get looking => 'Mencari perangkat';
	@override String get all => 'Semua';
	@override String get phones => 'Ponsel';
	@override String get tvs => 'TV';
	@override String get computers => 'Komputer';
	@override String get other => 'Lainnya';
	@override String get thisPhone => 'Ponsel ini';
	@override String get router => 'Router';
	@override String get unknown => 'Perangkat tak dikenal';
	@override String get address => 'Alamat';
	@override String get answersIn => 'Menjawab dalam';
	@override String get type => 'Jenis';
	@override String get newBadge => 'BARU';
	@override String scanning({required Object n}) => 'Memindai ${n} dari 254';
	@override String newSince({required Object n}) => '${n} baru sejak pindaian terakhir';
	@override String ms({required Object n}) => '${n} md';
	@override String get cameras => 'Kamera';
	@override String get device => 'Perangkat';
	@override String get online => 'Online';
	@override String get model => 'Model';
	@override String get announced => 'Mengumumkan diri sebagai';
	@override String get services => 'LAYANAN TERBUKA';
	@override String get checkingServices => 'Memeriksa layanan';
	@override String get noServices => 'Tidak ada layanan umum yang menjawab';
	@override String get rename => 'Ganti nama';
	@override String get save => 'Simpan';
	@override late final _Translations$devices$kinds$id kinds = _Translations$devices$kinds$id._(_root);
	@override String get details => 'Detail jaringan';
	@override String get listView => 'Daftar';
	@override String get meshView => 'Jaring';
	@override String get offlineHeading => 'Offline';
	@override String seen({required Object when}) => 'Terlihat ${when}';
	@override String agoMinutes({required Object n}) => '${n} mnt lalu';
	@override String agoHours({required Object n}) => '${n} jam lalu';
	@override String agoDays({required Object n}) => '${n} hari lalu';
	@override String get throughVpn => 'Lewat VPN';
	@override String get closer => 'Lebih dekat = menjawab lebih cepat';
	@override String get yours => 'Ini milik Anda?';
	@override String get mine => 'Milik saya';
	@override String get notMine => 'Bukan milik saya';
	@override String get whatIsIt => 'Apa ini?';
	@override String ourGuess({required Object kind}) => 'Tebakan kami: ${kind}';
	@override String get groupPersonal => 'Ponsel dan komputer';
	@override String get groupHome => 'Rumah dan media';
	@override String get groupNetwork => 'Jaringan dan rumah pintar';
	@override String onlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} online',
	);
	@override String offlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} offline',
	);
	@override String toConfirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} perlu dikonfirmasi',
	);
}

// Path: ping
class _Translations$ping$id extends Translations$ping$en {
	_Translations$ping$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get askTitle => 'Ping host';
	@override String get askHint => 'example.com atau 192.168.1.10';
	@override String get title => 'Ping';
	@override String get router => 'Router';
	@override String get pause => 'Jeda';
	@override String get start => 'Mulai';
	@override String get host => 'Host';
	@override String get live => 'Langsung';
	@override String get ago => '60 dtk lalu';
	@override String get min => 'MIN';
	@override String get avg => 'RATA';
	@override String get jitter => 'JITTER';
	@override String get loss => 'LOSS';
	@override String get goodFor => 'Cukup baik untuk';
	@override String get calls => 'Panggilan video';
	@override String get games => 'Game online';
	@override String get streaming => 'Streaming';
	@override String get great => 'Bagus';
	@override String get okay => 'Lumayan';
	@override String get poor => 'Buruk';
	@override String get lost => 'hilang';
	@override String get now => 'sekarang';
}

// Path: status
class _Translations$status$id extends Translations$status$en {
	_Translations$status$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get info => 'Menghubungi setiap layanan tiga kali dan menampilkan jawaban tercepat.\n\nDiblokir di sini: layanan yang tidak menjawab langsung tetapi berfungsi lewat VPN diblokir oleh jaringan atau negara Anda.\n\nRiwayat: pemeriksaan 24 jam terakhir dari ponsel ini, hanya disimpan di ponsel ini.';
	@override String get title => 'Status layanan';
	@override String get checking => 'Memeriksa';
	@override String get again => 'Periksa lagi';
	@override String get viaVpn => 'Diperiksa lewat VPN';
	@override String get direct => 'Diperiksa langsung';
	@override String get favourites => 'Favorit';
	@override String get edit => 'Ubah';
	@override String get last24 => '24 jam terakhir';
	@override String get ago => '24 jam lalu';
	@override String get all => 'Semua layanan';
	@override String get pickFour => 'Pilih hingga empat';
	@override String get outage => 'Bahkan lewat VPN: kemungkinan gangguan';
	@override String get blocked => 'Mungkin diblokir di jaringan ini';
	@override String get connect => 'Hubungkan';
	@override String get blockedShort => 'Diblokir';
	@override String get now => 'sekarang';
	@override String checks({required Object n}) => '${n} pemeriksaan';
	@override String andMore({required Object first, required Object n}) => '${first} dan ${n} lainnya';
	@override String notReachable({required Object who}) => '${who} tidak terjangkau';
}

// Path: tools
class _Translations$tools$id extends Translations$tools$en {
	_Translations$tools$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Data seluler';
	@override String get ethernet => 'Ethernet';
	@override String get checking => 'Memeriksa';
	@override String get offline => 'Offline';
	@override String get title => 'Alat';
	@override String get networkDesc => 'Pemeriksaan keamanan, apa yang dilihat situs, sinyal, router, dan DNS.';
	@override String get internet => 'Internet';
	@override String get speed => 'Tes kecepatan';
	@override String get speedDesc => 'Unduh, unggah, dan kualitas video';
	@override String get ping => 'Ping';
	@override String get pingDesc => 'Waktu respons dan jitter langsung';
	@override String get status => 'Status layanan';
	@override String get statusDesc => 'Aplikasi bisa diakses atau diblokir di sini?';
	@override String get trace => 'Traceroute';
	@override String get traceDesc => 'Setiap persinggahan menuju situs';
	@override String get security => 'Jaringan ini';
	@override String get devices => 'Perangkat di jaringan ini';
	@override String get devicesDesc => 'Siapa saja di Wi-Fi Anda';
	@override String get router => 'Periksa router';
	@override String get routerDesc => 'Port yang dibuka perangkat Anda';
	@override String get ports => 'Port terbuka';
	@override String get portsDesc => 'Port berisiko di perangkat atau server';
	@override String get utilities => 'Utilitas';
	@override String get wifiScanner => 'Pemindai Wi-Fi';
	@override String get wifiDesc => 'Jaringan di sekitar dan kanal paling sepi';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'Nyalakan komputer di jaringan ini';
	@override String get passwordCheck => 'Cek kata sandi';
	@override String get passwordCheckDesc => 'Pernah bocor?';
	@override String get linkCheck => 'Cek tautan';
	@override String get linkCheckDesc => 'Aman dibuka?';
	@override String get breaches => 'Kebocoran data';
	@override String get breachesDesc => 'Apa yang bocor belakangan ini';
	@override String get blocked => 'Apa yang diblokir';
	@override String get blockedDesc => 'Situs yang diblokir di jaringan ini';
}

// Path: trace
class _Translations$trace$id extends Translations$trace$en {
	_Translations$trace$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get info => 'Setiap perhentian adalah satu router yang dilewati lalu lintas Anda menuju situs.\n\nHop diam: banyak router tidak pernah menjawab uji ini. Itu normal dan bukan kesalahan.\n\nDengan VPN aktif: jalurnya dimulai di dalam terowongan, jadi jaringan dan penyedia Anda tersembunyi.\n\nCara: memakai alat ping bawaan Android dengan batas hop, karena aplikasi tidak dapat mengirim paket ini secara langsung.';
	@override String get title => 'Traceroute';
	@override String get stop => 'Hentikan';
	@override String get trace => 'Lacak';
	@override String get again => 'Lacak lagi';
	@override String get destination => 'Tujuan';
	@override String get hops => 'HOP';
	@override String get answered => 'MENJAWAB';
	@override String get total => 'TOTAL';
	@override String get thisPhone => 'Ponsel ini';
	@override String get silentOne => '1 hop diam';
	@override String get yourRouter => 'Router Anda';
	@override String ms({required Object n}) => '${n} md';
	@override String silentMany({required Object n}) => '${n} hop diam';
	@override String hop({required Object n}) => 'Hop ${n}';
	@override String slowest({required Object ms, required Object hop}) => 'Sebagian besar jeda, ${ms} md, ditambahkan di hop ${hop}: biasanya kabel panjang antarnegara, atau jalur yang padat.';
	@override String get popular => 'POPULER';
	@override String get recent => 'TERBARU';
	@override String get clearRecent => 'Hapus terbaru';
	@override String hopsCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} lompatan',
	);
}

// Path: ports
class _Translations$ports$id extends Translations$ports$en {
	_Translations$ports$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get ftpNote => 'Mengirim kata sandi tanpa enkripsi.';
	@override String get sshNote => 'Login jarak jauh. Aman jika Anda yang menyiapkannya.';
	@override String get telnetNote => 'Login jarak jauh tanpa enkripsi; favorit botnet.';
	@override String get dnsNote => 'Normal di router.';
	@override String get web => 'Web (HTTP)';
	@override String get webNote => 'Biasanya halaman admin router.';
	@override String get webTls => 'Web (HTTPS)';
	@override String get smb => 'Berbagi file Windows';
	@override String get smbNote => 'Tidak boleh terbuka ke internet.';
	@override String get rtsp => 'Siaran kamera RTSP';
	@override String get rtspNote => 'Mungkin ada kamera yang menyiarkan di sini.';
	@override String get upnpNote => 'Memungkinkan perangkat membuka port router sendiri.';
	@override String get rdp => 'Remote Desktop';
	@override String get rdpNote => 'Jalur pembobolan yang umum.';
	@override String get vncNote => 'Berbagi layar, sering tanpa kata sandi.';
	@override String get tr069Note => 'Pengelolaan jarak jauh oleh ISP.';
	@override String get webAlt => 'Web (alternatif)';
	@override String get webAltTls => 'Web (HTTPS alternatif)';
	@override String get title => 'Port terbuka';
	@override String get check => 'Periksa port';
	@override String get address => 'Alamat perangkat atau server';
	@override String get risky => 'BERISIKO';
	@override String get review => 'TINJAU';
	@override String get normal => 'NORMAL';
	@override String info({required Object n}) => 'Memeriksa ${n} port yang penting di router dan perangkat rumah, dan menjelaskan setiap port yang terbuka.\n\nHanya periksa perangkat dan server yang Anda miliki atau kelola.';
	@override String checking({required Object n}) => 'Memeriksa ${n} port';
	@override String yourRouter({required Object ip}) => 'Router Anda adalah ${ip}';
	@override String noneOpen({required Object host}) => 'Tidak ada port umum yang terbuka di ${host}.';
	@override String summary({required Object open, required Object n}) => '${open} terbuka dari ${n} dicek';
	@override String riskyCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} berisiko',
	);
	@override String get noneRisky => 'Tidak ada yang berisiko';
}

// Path: wifi
class _Translations$wifi$id extends Translations$wifi$en {
	_Translations$wifi$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pemindai Wi-Fi';
	@override String get allow => 'Izinkan pemindaian Wi-Fi';
	@override String get needsPermission => 'Memerlukan izin lokasi.';
	@override String get scanning => 'Memindai';
	@override String get again => 'Pindai lagi';
	@override String get failed => 'Pemindaian gagal';
	@override String get none => 'Tidak ada jaringan ditemukan. Lokasi mungkin mati.';
	@override String get hidden => 'Jaringan tersembunyi';
	@override String nearby({required Object n}) => '${n} jaringan di sekitar';
	@override String get permissionInfo => 'Android hanya menampilkan jaringan Wi-Fi di sekitar kepada aplikasi yang memiliki izin lokasi. G VPN memakainya hanya untuk menampilkan jaringan di ponsel ini.';
	@override String get info => 'Menampilkan jaringan dari pemindaian terakhir ponsel. Android hanya mengizinkan beberapa pemindaian per menit, jadi pemindaian ulang yang cepat bisa menampilkan daftar yang sama. Kanal yang disarankan adalah yang paling sepi di antara 1, 6, dan 11, tiga kanal yang tidak tumpang tindih.';
	@override String get airMap => 'Peta udara';
	@override String get channels => 'Kanal';
	@override String get list => 'Daftar';
	@override String get secure => 'Aman';
	@override String get weakLabel => 'Lemah';
	@override String get openLabel => 'Terbuka';
	@override String get sizeIsWidth => 'Ukuran = lebar kanal';
	@override String get strongest => 'TERKUAT';
	@override String get openNearby => 'TERBUKA DI SEKITAR';
	@override String get onYourChannel => 'DI KANAL ANDA';
	@override String get noneNearby => 'Tidak ada';
	@override String get verdictOpen => 'Siapa pun di sekitar bisa membaca yang dikirim';
	@override String get verdictWep => 'Keamanan lama, mudah dibobol';
	@override String get verdictWpa => 'Keamanan lama';
	@override String get verdictWps => 'WPS aktif: lebih mudah dibobol';
	@override String get verdictGood => 'Terlindungi baik';
	@override String get maker => 'Pembuat';
	@override String get address => 'Alamat perangkat keras';
	@override String get privateAddress => 'Dibuat router demi privasi';
	@override String get you => 'Anda';
	@override String onClear({required Object name}) => '${name} ada di kanal yang sepi';
	@override String move({required Object name, required Object n}) => 'Pindahkan ${name} ke kanal ${n}';
	@override String get clear => 'Sepi';
	@override String get busy => 'Sibuk';
	@override String get crowded => 'Padat';
	@override String get allBands => 'Semua pita';
	@override String get openOnly => 'Hanya terbuka';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} jaringan',
	);
}

// Path: errors
class _Translations$errors$id extends Translations$errors$en {
	_Translations$errors$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get notAuthorized => 'Izin VPN tidak diberikan.';
	@override String get turnedOff => 'VPN dimatikan oleh sistem atau aplikasi lain.';
	@override String get busy => 'Permintaan izin sudah terbuka.';
	@override String get cancelled => 'Koneksi dibatalkan.';
	@override String badConfig({required Object error}) => 'Konfigurasi server ini tidak valid: ${error}';
	@override String get timeout => 'Server tidak menjawab.';
	@override String get refused => 'Server menolak koneksi.';
	@override String failed({required Object error}) => 'Tidak dapat terhubung: ${error}';
	@override String get tryAnother => 'Server gratis datang dan pergi; coba server lain.';
	@override String get downloadFailed => 'Tidak dapat mengunduh setelan server ini. Periksa koneksi Anda, atau pilih server lain.';
}

// Path: scan
class _Translations$scan$id extends Translations$scan$en {
	_Translations$scan$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get mobile => 'Data seluler';
	@override String get ping => 'PING';
	@override String get noReply => 'Tidak ada jawaban';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, terowongan';
	@override String get dnsTunnel => 'Di dalam terowongan';
	@override String get privateDns => 'DNS Pribadi';
	@override String get dnsIsp => 'ISP, terlihat';
	@override String get network => 'JARINGAN';
	@override String get offline => 'Offline';
	@override String get open => 'Terbuka, tanpa sandi';
	@override String get wep => 'WEP, tidak aman';
	@override String get owe => 'Terbuka, terenkripsi';
	@override String get enterprise => 'Perusahaan';
	@override String get unknown => 'Tidak diketahui';
	@override String get wifi => 'WI-FI';
	@override String get signIn => 'Halaman masuk';
	@override String ms({required Object n}) => '${n} md';
	@override String covered({required Object what}) => '${what}, terlindungi';
}

// Path: legal
class _Translations$legal$id extends Translations$legal$en {
	_Translations$legal$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get privacy => 'Kebijakan privasi';
	@override String get terms => 'Ketentuan penggunaan';
	@override String get licences => 'Lisensi sumber terbuka';
}

// Path: update
class _Translations$update$id extends Translations$update$en {
	_Translations$update$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get ready => 'Pembaruan siap';
	@override String get restart => 'Mulai ulang';
}

// Path: details
class _Translations$details$id extends Translations$details$en {
	_Translations$details$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get share => 'Bagikan';
	@override String connectedFor({required Object n}) => 'TERHUBUNG · ${n} MNT';
	@override String get notConnected => 'TIDAK TERHUBUNG';
	@override String get downloaded => 'DIUNDUH';
	@override String get uploaded => 'DIUNGGAH';
	@override String get lastUsed => 'TERAKHIR DIPAKAI';
	@override String get connection => 'Koneksi';
	@override String get protocol => 'Protokol';
	@override String get address => 'Alamat Anda';
	@override String get dns => 'DNS';
	@override String get routes => 'Rute';
	@override String get allTraffic => 'Semua lalu lintas';
	@override String someRoutes({required Object n}) => '${n} jaringan';
	@override String get keepalive => 'Keepalive';
	@override String get serverKey => 'Kunci server';
	@override String get copy => 'Salin';
	@override String get copied => 'Disalin';
	@override String get manage => 'Kelola';
	@override String get export => 'Ekspor untuk cadangan';
	@override String get exportSub => 'Semua server Anda dalam satu file';
}

// Path: share
class _Translations$share$id extends Translations$share$en {
	_Translations$share$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String title({required Object name}) => 'Bagikan ${name}';
	@override String get sameKey => 'Ini membagikan kunci ponsel ini. Siapa pun yang memilikinya dapat memakai server Anda sebagai Anda, dan hanya satu perangkat yang bisa terhubung dengannya pada satu waktu.';
	@override String get scanHint => 'Di ponsel lain: G VPN, Server, Pindai QR. Gambar yang disimpan juga bisa.';
	@override String get saveImage => 'Simpan gambar';
	@override String get send => 'Kirim';
}

// Path: add
class _Translations$add$id extends Translations$add$en {
	_Translations$add$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tambah server';
	@override String get subtitle => 'Server WireGuard apa pun: router, VPS, atau server rumah.';
	@override String get camera => 'Pindai dengan kamera';
	@override String get cameraSub => 'QR di layar lain';
	@override String get image => 'Dari gambar';
	@override String get imageSub => 'Tangkapan layar atau foto tersimpan';
	@override String get noQr => 'Tidak ada kode QR di gambar itu.';
	@override String get tip => 'Dapat QR di WhatsApp atau Telegram? Ketuk Bagikan pada gambar dan pilih G VPN.';
}

// Path: backup
class _Translations$backup$id extends Translations$backup$en {
	_Translations$backup$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String restored({required Object n}) => '${n} server dipulihkan';
	@override String get nothingNew => 'Server ini sudah ada';
}

// Path: gs
class _Translations$gs$id extends Translations$gs$en {
	_Translations$gs$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'G Servers khusus pelanggan G VPN Pro.';
	@override String get off => 'G Servers sedang dimatikan.';
	@override String get network => 'Tidak dapat menjangkau G Servers. Periksa koneksi Anda dan coba lagi.';
	@override String get active => 'AKTIF';
	@override String get servers => 'G Servers';
	@override String busy({required Object n}) => '${n}% sibuk';
	@override String get offline => 'Offline';
	@override String get devices => 'Perangkat Anda';
	@override String subtitle({required Object country}) => 'G Server · ${country} · WireGuard';
	@override String get busyLabel => 'SIBUK';
	@override String get status => 'STATUS';
	@override String get online => 'Online';
	@override String get onThisServer => 'Di server ini';
	@override String get thisPhone => 'Ponsel ini';
	@override String get added => 'Ditambahkan · kunci dibuat di sini';
	@override String get notAdded => 'Ditambahkan saat Anda terhubung';
	@override String get logs => 'Log aktivitas';
	@override String get noneKept => 'Tidak disimpan';
	@override String get privacy => 'Server hanya mengenal ponsel ini dari kunci publiknya. Server tidak mencatat situs yang Anda kunjungi atau lalu lintas yang Anda kirim.';
	@override String get stepPro1 => 'Pasang G VPN di ponsel, masuk dengan akun Google yang sama.';
	@override String get stepPro2 => 'Buka tab Pro. Pro terbuka otomatis, atau ketuk Pulihkan.';
	@override String get step3 => 'Ketuk Hubungkan. Ponsel membuat kuncinya dan ditambahkan ke G Servers. Tanpa QR, tanpa kode.';
	@override String get stepFree1 => 'Pasang G VPN di ponsel.';
	@override String get stepFree2 => 'Buka tab Pro.';
	@override String get devicesIntroPro => 'Pro mengikuti akun Google Anda. Setiap ponsel punya kuncinya sendiri, jadi tidak saling memutuskan.';
	@override String get devicesIntroFree => 'Setiap ponsel punya kuncinya sendiri, jadi tidak saling memutuskan.';
	@override String get otherPhone => 'Ponsel lain';
	@override String lastConnected({required Object when}) => 'Terakhir terhubung ${when}';
	@override String get noDevices => 'Hubungkan ke G Server sekali dan ponsel Anda muncul di sini.';
	@override String get addTitle => 'Tambah ponsel atau pasang ulang';
	@override String idle({required Object n}) => 'Ponsel yang tidak terhubung selama ${n} hari dihapus otomatis dari G Servers, jadi ponsel lama atau yang dipasang ulang tidak memakan tempat.';
	@override String limitNote({required Object n}) => 'Hingga ${n} ponsel per paket.';
	@override String fullTitle({required Object n}) => 'Ke-${n} tempat sudah terpakai';
	@override String get fullBody => 'Hapus ponsel yang tidak lagi Anda pakai, dan ponsel ini langsung terhubung.';
	@override String get busyNow => 'Terlalu banyak ponsel baru saat ini. Coba lagi sebentar lagi.';
	@override String get serverFull => 'Server ini penuh. Coba G Server lain.';
	@override String get ping => 'PING';
	@override String get last24 => 'Kesibukan, 24 jam terakhir';
	@override String get noHistory => 'Grafik terisi seiring server dipakai sepanjang hari.';
	@override String chartLabel({required Object max}) => 'Kesibukan 24 jam terakhir, paling tinggi ${max} persen';
	@override String get hoursAgo => '24 jam lalu';
	@override String get now => 'Sekarang';
	@override String get included => 'Termasuk';
	@override String get perkServers => 'Server cepat dan privat';
	@override String get perkServersSub => 'WireGuard, dikelola kami, tanpa log aktivitas';
	@override String get perkLinks => 'Cek tautan tanpa batas';
	@override String get perkLinksSub => 'Cek setiap tautan yang Anda terima';
	@override String devicesOf({required Object used, required Object limit}) => 'Perangkat Anda · ${used} dari ${limit}';
	@override String get eachKey => 'Setiap ponsel punya kuncinya sendiri';
	@override String get connected => 'Tersambung';
	@override String get bestNow => 'TERBAIK UNTUK ANDA SEKARANG';
	@override String get logsShort => 'LOG';
}

// Path: map
class _Translations$map$id extends Translations$map$en {
	_Translations$map$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get open => 'Buka peta';
	@override String get searchCountries => 'Cari negara';
	@override String get noMatch => 'Tidak ada negara yang cocok';
	@override String get locate => 'Lokasi saya';
	@override String get list => 'Daftar';
	@override String get map => 'Peta';
	@override String freeServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} server gratis',
	);
	@override late final _Translations$map$grade$id grade = _Translations$map$grade$id._(_root);
	@override String get switchTo => 'Ganti';
	@override String freeServer({required Object n}) => 'Server gratis ${n}';
	@override String get best => 'TERBAIK';
	@override String gServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} G Server',
	);
}

// Path: stats
class _Translations$stats$id extends Translations$stats$en {
	_Translations$stats$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get thisWeek => 'Minggu ini';
	@override String get time => 'Waktu';
	@override String get data => 'Data';
	@override String get protected => 'terlindungi';
	@override String get throughVpn => 'lewat VPN';
	@override String get seeDetails => 'Lihat detail';
	@override String get title => 'Statistik';
	@override String get week => 'Minggu';
	@override String get month => 'Bulan';
	@override String get protectedLabel => 'TERLINDUNGI';
	@override String get dataUsed => 'DATA TERPAKAI';
	@override String get byServer => 'PER SERVER';
	@override String get onPhone => 'Hanya di ponsel ini';
	@override String get reset => 'Atur ulang';
	@override String get resetTitle => 'Atur ulang statistik?';
	@override String get resetBody => 'Menghapus waktu terlindungi dan data di ponsel ini. Tidak bisa dibatalkan.';
	@override String hm({required Object h, required Object m}) => '${h} j ${m} m';
	@override String m({required Object m}) => '${m} m';
	@override String get empty => 'Hubungkan untuk mulai menghitung.';
}

// Path: recents
class _Translations$recents$id extends Translations$recents$en {
	_Translations$recents$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Terbaru';
	@override String get allServers => 'Semua server';
	@override String get free => 'Server gratis';
	@override String get yours => 'Server Anda';
	@override String get gserver => 'G Server';
}

// Path: presets
class _Translations$presets$id extends Translations$presets$en {
	_Translations$presets$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Preset';
	@override String get all => 'Semua';
	@override String get newPreset => 'Preset baru';
	@override String get edit => 'Ubah preset';
	@override String get name => 'Nama';
	@override String get namePlaceholder => 'Preset saya';
	@override String get server => 'SERVER';
	@override String get fastestOption => 'Tercepat';
	@override String get countryOption => 'Negara';
	@override String get pickCountry => 'Pilih negara';
	@override String get skipMyCountry => 'Lewati negara saya';
	@override String get notMine => 'bukan negara saya';
	@override String get protocol => 'PROTOKOL';
	@override String get auto => 'Otomatis';
	@override String get tryNext => 'Jika diblokir, coba server berikutnya';
	@override String get shield => 'PERISAI';
	@override String get followRules => 'Sesuai Aturan';
	@override String get allApps => 'Semua aplikasi lewat VPN';
	@override String get allAppsShort => 'semua aplikasi';
	@override String get save => 'Simpan';
	@override String get delete => 'Hapus';
	@override String get reset => 'Kembalikan bawaan';
	@override String get none => 'Belum ada server gratis yang cocok untuk preset ini.';
	@override late final _Translations$presets$names$id names = _Translations$presets$names$id._(_root);
}

// Path: shield
class _Translations$shield$id extends Translations$shield$en {
	_Translations$shield$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Perisai';
	@override String get sub => 'Bekerja saat Anda terhubung';
	@override String get off => 'Mati';
	@override String get offSub => 'DNS milik server';
	@override String get malware => 'Malware';
	@override String get malwareSub => 'Memblokir situs berbahaya dan phishing';
	@override String get family => 'Malware dan situs dewasa';
	@override String get familySub => 'Juga memblokir konten dewasa';
	@override String get custom => 'DNS sendiri';
	@override String get customSub => 'Server DNS Anda sendiri';
	@override String get customHint => 'Alamat IP, misalnya 1.1.1.1';
	@override String get invalid => 'Masukkan satu atau dua alamat IP.';
}

// Path: checks
class _Translations$checks$id extends Translations$checks$en {
	_Translations$checks$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pemeriksaan keamanan';
	@override String get password => 'Kata sandi';
	@override String get link => 'Tautan';
	@override String get pwTitle => 'Pernah bocor?';
	@override String get pwHint => 'Kata sandi yang dicek';
	@override String get showPassword => 'Tampilkan kata sandi';
	@override String get hidePassword => 'Sembunyikan kata sandi';
	@override String get check => 'Cek';
	@override String get leaked => 'Ditemukan di kebocoran';
	@override String seen({required Object n}) => 'Terlihat ${n} kali';
	@override String get leakedAdvice => 'Ganti di semua tempat Anda memakainya, mulai dari email dan bank.';
	@override String get notFound => 'Tidak ada di kebocoran yang diketahui';
	@override String get notFoundAdvice => 'Pertanda baik, bukan jaminan. Pakai kata sandi berbeda untuk tiap akun.';
	@override String get failed => 'Gagal mengecek. Coba lagi.';
	@override String get private => 'Kata sandi Anda tidak pernah keluar dari ponsel ini';
	@override String get linkTitle => 'Amankah tautan ini?';
	@override String get linkHint => 'Tautan yang dicek';
	@override String get paste => 'Tempel';
	@override String get danger => 'Tautan berbahaya';
	@override String get dangerAdvice => 'Jangan dibuka dan jangan isi data apa pun.';
	@override String get clear => 'Tidak ada di daftar malware atau phishing yang dikenal';
	@override String get clearAdvice => 'Tetap periksa alamatnya sebelum masuk ke mana pun.';
	@override String get goesTo => 'Menuju ke';
	@override String get redirects => 'Pengalihan';
	@override String get invalid => 'Itu tidak tampak seperti alamat web.';
	@override String get busy => 'Terlalu banyak pengecekan. Coba lagi nanti.';
	@override String get unavailable => 'Cek tautan sedang tidak tersedia.';
	@override String get listed => 'Dikenal sebagai malware atau phishing';
	@override String get missing => 'Tidak ada situs di alamat ini';
	@override String get missingAdvice => 'Periksa ejaannya: penipuan sering memakai alamat yang mirip.';
	@override String left({required Object n, required Object total}) => 'Sisa ${n} dari ${total} cek gratis bulan ini';
	@override String get usedUp => 'Cek tautan gratis bulan ini sudah habis';
	@override String get usedUpSub => 'Pro punya cek tanpa batas. Cek gratis kembali setiap tanggal 1.';
	@override String get getPro => 'Dapatkan Pro';
}

// Path: toolSettings
class _Translations$toolSettings$id extends Translations$toolSettings$en {
	_Translations$toolSettings$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pengaturan alat';
	@override String get askMobile => 'Tanya sebelum tes kecepatan di data seluler';
	@override String get askMobileSub => 'Satu tes bisa memakai lebih dari 100 MB di koneksi cepat';
	@override String get mobileTitle => 'Pakai data seluler?';
	@override String get mobileBody => 'Tes kecepatan bisa memakai lebih dari 100 MB di koneksi cepat.';
	@override String get mobileGo => 'Tes';
	@override String get safe => 'Aman';
	@override String get unsafe => 'Tidak aman';
	@override String devices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} perangkat',
	);
	@override String get hideMac => 'Sembunyikan alamat perangkat keras';
	@override String get hideMacSub => 'Hanya tampilkan bagian pembuat dari alamat MAC';
	@override String get names => 'Tampilkan nama router dan server';
	@override String get namesSub => 'Mencari nama alamat di Traceroute';
	@override String get remember => 'Ingat host terbaru';
	@override String get rememberSub => 'Untuk Traceroute';
	@override String get clear => 'Hapus riwayat alat';
	@override String get clearSub => 'Melupakan host terbaru dan perangkat di tiap jaringan';
	@override String get clearGo => 'Hapus';
}

// Path: security
class _Translations$security$id extends Translations$security$en {
	_Translations$security$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get tab => 'Keamanan';
	@override String get good => 'Baik';
	@override String get fair => 'Cukup';
	@override String get atRisk => 'Berisiko';
	@override String get allClear => 'Tidak ada yang perlu diperbaiki';
	@override String checked({required Object time}) => 'Dicek pukul ${time}';
	@override String get trend => 'DUA MINGGU TERAKHIR';
	@override String get checking => 'Memeriksa jaringan ini';
	@override String get snoozed => 'Ditunda';
	@override String get remindLater => 'Ingatkan nanti';
	@override String get unsnooze => 'Ingatkan sekarang';
	@override String get review => 'Tinjau';
	@override String get confirmGo => 'Konfirmasi';
	@override String get scanGo => 'Pindai';
	@override String get look => 'Lihat';
	@override String get connectGo => 'Hubungkan';
	@override String get checkAgain => 'Cek lagi';
	@override String get wifiOpen => 'Wi-Fi terbuka';
	@override String get wifiOpenDetail => 'Siapa pun di sekitar bisa melihat yang dikirim';
	@override String get wifiWep => 'Wi-Fi memakai WEP';
	@override String get wifiWepDetail => 'Keamanan lama, mudah dibobol';
	@override String get wifiOwe => 'Wi-Fi memakai Enhanced Open';
	@override String get wifiOweDetail => 'Terenkripsi, tapi siapa pun bisa masuk';
	@override String get wifiSecure => 'Enkripsi Wi-Fi';
	@override String get wifiUnknown => 'Keamanan Wi-Fi tidak diketahui';
	@override String get wifiUnknownDetail => 'Android tidak menyebut perlindungannya';
	@override String get wps => 'WPS aktif';
	@override String get wpsDetail => 'Matikan di pengaturan router';
	@override String get upnpOff => 'Router menjaga port tetap tertutup';
	@override String get upnpOffDetail => 'UPnP mati';
	@override String get upnpOn => 'Router membiarkan perangkat membuka port';
	@override String get upnpOnDetail => 'UPnP aktif';
	@override String get portsOk => 'Tidak ada port berisiko di router';
	@override String get portsRisky => 'Port berisiko terbuka di router';
	@override String get scanFirst => 'Pindai untuk melihat siapa di sini';
	@override String get scanFirstDetail => 'Perangkat tak dikenal mengurangi skor';
	@override String get notMineDetail => 'Periksa daftar perangkat di router';
	@override String get confirmDetail => 'Tandai yang milik Anda';
	@override String get devicesOk => 'Semua perangkat dikenal';
	@override String get devicesOkDetail => 'Anda sudah mengonfirmasi semuanya';
	@override String get camera => 'Ada kamera di jaringan ini';
	@override String get dnsHijack => 'Nama tak dikenal dialihkan';
	@override String get dnsHijackDetail => 'Penyedia atau router Anda mengubah pencarian';
	@override String get dnsOk => 'DNS menjawab normal';
	@override String get dnsOkDetail => 'Tidak ada tanda pengalihan';
	@override String get vpnOn => 'VPN aktif';
	@override String get vpnOnDetail => 'Lalu lintas keluar lewat terowongan';
	@override String get vpnOff => 'VPN mati';
	@override String get vpnOffDetail => 'Penyedia Anda melihat setiap situs';
	@override String toFix({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} hal perlu diperbaiki',
	);
	@override String upnpOpened({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} port dibuka perangkat',
	);
	@override String portsChecked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} port dicek',
	);
	@override String notMine({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} perangkat bukan milik Anda',
	);
	@override String confirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} perangkat perlu dikonfirmasi',
	);
}

// Path: providers
class _Translations$providers$id extends Translations$providers$en {
	_Translations$providers$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get tab => 'Internet';
	@override String get unavailable => 'Tidak bisa memuat daftar penyedia. Periksa koneksi Anda.';
	@override String get cached => 'Menurut pengecekan terakhir tanpa VPN';
	@override String get notEnough => 'Belum cukup penilaian';
	@override String get yourRating => 'Penilaian Anda bulan ini';
	@override String get yourSpeed => 'KECEPATAN ANDA';
	@override String get runTest => 'Jalankan tes kecepatan';
	@override String get aboutAverage => 'Setara rata-rata di sini';
	@override String aboveAverage({required Object pct}) => '${pct}% di atas rata-rata lokal';
	@override String belowAverage({required Object pct}) => '${pct}% di bawah rata-rata lokal';
	@override String get call => 'Telepon';
	@override String get website => 'Situs web';
	@override String get outages => 'Gangguan';
	@override String get rate => 'Nilai';
	@override String get changeRating => 'Ubah penilaian';
	@override String get compare => 'Bandingkan';
	@override String rateTitle({required Object name}) => 'Nilai ${name}';
	@override String get oncePerMonth => 'Satu penilaian sebulan';
	@override String get tapStars => 'Ketuk bintangnya';
	@override String verified({required Object mbps}) => 'Terverifikasi oleh tes Anda: ${mbps} Mbps';
	@override String get busy => 'Terlalu banyak penilaian dari sini. Coba nanti.';
	@override String get failed => 'Gagal mengirim. Coba lagi.';
	@override String get post => 'Kirim penilaian';
	@override String get nearTitle => 'Penyedia di sekitar Anda';
	@override String slower({required Object pct}) => 'Unduhan Anda ${pct}% di bawah rata-rata penyedia Anda di sini';
	@override String inPlace({required Object place}) => 'Internet rumah di ${place}';
	@override String get byRating => 'Penilaian';
	@override String get bySpeed => 'Kecepatan';
	@override String get footnote => 'Kecepatan adalah rata-rata tes G VPN';
	@override String get noneNearby => 'Belum ada penilaian di sekitar. Jadilah yang pertama.';
	@override String get you => 'Anda';
	@override String get topRated => 'Nilai tertinggi';
	@override String starsOf({required Object n}) => '${n} dari 5';
	@override late final _Translations$providers$tags$id tags = _Translations$providers$tags$id._(_root);
	@override late final _Translations$providers$words$id words = _Translations$providers$words$id._(_root);
	@override String ratings({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} penilaian',
	);
}

// Path: alerts
class _Translations$alerts$id extends Translations$alerts$en {
	_Translations$alerts$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get channel => 'Peringatan';
	@override String get title => 'Peringatan';
	@override String get markAllRead => 'Tandai semua dibaca';
	@override String get clearAll => 'Hapus semua';
	@override String get thisNetwork => 'jaringan ini';
	@override String openWifiTitle({required Object name}) => 'Anda tersambung ke Wi-Fi terbuka: ${name}';
	@override String get openWifiBody => 'Siapa pun di sekitar bisa melihat yang dikirim. Nyalakan G VPN.';
	@override String get reportTitle => 'Laporan mingguan Anda siap';
	@override String reportBody({required Object hours}) => '${hours} jam terlindungi minggu lalu';
	@override String blockedTitle({required Object name}) => '${name} diblokir di sini';
	@override String get blockedBody => 'Bisa diakses lewat VPN';
	@override late final _Translations$alerts$kinds$id kinds = _Translations$alerts$kinds$id._(_root);
	@override String newDeviceTitle({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} perangkat baru di ${network}',
	);
	@override String get settings => 'Pengaturan peringatan';
	@override String get look => 'Lihat';
	@override String get read => 'Baca';
	@override String get open => 'Buka';
	@override String get check => 'Cek';
	@override String get today => 'HARI INI';
	@override String get thisWeek => 'MINGGU INI';
	@override String get earlier => 'SEBELUMNYA';
	@override String get all => 'Semua';
	@override String get quiet => 'Semua tenang';
	@override String get quietSub => 'Tidak ada yang perlu Anda tangani';
	@override String breachTitle({required Object name}) => 'Kebocoran baru: ${name}';
	@override late final _Translations$alerts$status$id status = _Translations$alerts$status$id._(_root);
}

// Path: report
class _Translations$report$id extends Translations$report$en {
	_Translations$report$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Laporan mingguan';
	@override String get share => 'Bagikan sebagai gambar';
	@override String get shareText => 'Minggu saya dengan G VPN';
	@override String get safer => 'Minggu yang lebih aman';
	@override String get moreProtected => 'Lebih terlindungi dari minggu lalu';
	@override String get yourWeek => 'Minggu Anda';
	@override String soFar({required Object range}) => '${range}, sejauh ini';
	@override String get protected => 'Terlindungi';
	@override String get data => 'Data';
	@override String get security => 'Keamanan';
	@override String get speed => 'Kecepatan terbaik';
	@override String get noScore => 'Belum dicek';
	@override String get noTest => 'Belum ada tes';
	@override String get bestDirect => 'Tes langsung';
	@override String moreThan({required Object d}) => '${d} lebih lama dari minggu lalu';
	@override String lessThan({required Object d}) => '${d} lebih singkat dari minggu lalu';
	@override String get protectedTime => 'WAKTU TERLINDUNGI';
	@override String mostUsed({required Object name}) => 'Paling sering: ${name}';
	@override String get quiet => 'Minggu yang tenang: tidak ada yang perlu Anda tangani';
	@override String newDevices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} perangkat baru bergabung',
	);
	@override String openWifi({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: 'Bergabung ke ${n} Wi-Fi terbuka',
	);
	@override String blocked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} aplikasi diblokir',
	);
	@override String breaches({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} kebocoran besar baru',
	);
}

// Path: breaches
class _Translations$breaches$id extends Translations$breaches$en {
	_Translations$breaches$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kebocoran data';
	@override String get info => 'Kebocoran data terbaru, dari daftar publik Have I Been Pwned. Tidak ada data Anda yang dikirim: daftarnya sama untuk semua orang.\n\nJika Anda punya akun di situs yang bocor, ganti kata sandinya, juga di tempat lain yang memakai sandi sama.';
	@override String get unavailable => 'Gagal memuat daftar. Periksa koneksi Anda.';
	@override String get biggest => 'TERBESAR BULAN INI';
	@override String get newest => 'Terbaru';
	@override String get biggestSort => 'Terbesar';
	@override String get withPasswords => 'Dengan kata sandi';
	@override String get passwordsMark => 'KATA SANDI';
	@override String get one => 'Kebocoran';
	@override String get checkPassword => 'Cek kata sandi';
	@override String get verified => 'Terverifikasi';
	@override String get hasPasswords => 'Ada kata sandi';
	@override String get accountsLabel => 'Akun';
	@override String get happened => 'Terjadi';
	@override String get published => 'Dipublikasikan';
	@override String get website => 'Situs web';
	@override String get leaked => 'YANG BOCOR';
	@override String get ifUsed => 'JIKA ANDA MEMAKAINYA';
	@override String get stepPassword => 'Ganti kata sandi yang Anda pakai di sana';
	@override String get stepReuse => 'Ganti juga di tempat lain yang memakai sandi sama';
	@override String get stepTwoStep => 'Aktifkan verifikasi dua langkah jika bisa';
	@override String get stepScams => 'Waspadai telepon dan pesan penipuan';
	@override String accounts({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${count} akun',
	);
	@override String worldwide({required Object n}) => 'Global · ${n}';
	@override String get noneHere => 'Tidak ada kebocoran dari sini di daftar terbaru.';
	@override String get bigMap => 'Peta lebih besar';
	@override String get showInList => 'Tampilkan di daftar';
	@override String get mapTitle => 'Peta kebocoran';
	@override String get zoomIn => 'Perbesar';
	@override String get zoomOut => 'Perkecil';
	@override String get wholeWorld => 'Seluruh dunia';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} kebocoran',
	);
	@override String get findCountry => 'Cari negara';
	@override String get seeAll => 'Lihat semua';
	@override String get search => 'Cari kebocoran';
}

// Path: blocked
class _Translations$blocked$id extends Translations$blocked$en {
	_Translations$blocked$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Apa yang diblokir';
	@override String get info => 'Menguji situs terkenal dari ponsel ini, tanpa VPN, dan menunjukkan mana yang diblokir jaringan ini serta caranya.\n\nAlamat palsu: pencarian nama jaringan memberi jawaban palsu.\n\nDiputus: koneksi diputus saat dimulai.\n\nTidak ada jawaban: tidak ada yang kembali.\n\nHalaman blokir: hal lain menjawab menggantikan situs.\n\nTes menunjukkan di mana situs diblokir, bukan siapa yang memblokir. Tidak ada yang disimpan atau dikirim.';
	@override String get thisNetwork => 'Jaringan ini';
	@override String get country => 'Negara Anda';
	@override String get question => 'Apa yang diblokir di sini?';
	@override String get testingOn => 'MENGUJI DI';
	@override String get vpnOn => 'VPN AKTIF';
	@override String get turnOff => 'Matikan G VPN untuk menguji';
	@override String get test => 'Uji jaringan ini';
	@override String get stop => 'Berhenti';
	@override String sitesToTest({required Object n}) => 'SITUS YANG DIUJI · ${n}';
	@override String ofSites({required Object n}) => 'dari ${n} situs';
	@override String blockedCount({required Object n}) => '${n} DIBLOKIR';
	@override String openCount({required Object n}) => '${n} TERBUKA';
	@override String noneBlocked({required Object network}) => 'Tidak ada yang diblokir di ${network}';
	@override String openOf({required Object open, required Object total}) => '${open} dari ${total} terbuka';
	@override String get allWork => 'SEMUA BISA DENGAN G VPN';
	@override String get blockedHeading => 'DIBLOKIR';
	@override String get byKind => 'MENURUT JENIS';
	@override String get worksVpn => 'Bisa dengan VPN';
	@override String get failsVpn => 'Tetap diblokir lewat VPN';
	@override String get checkVpn => 'Cek lewat G VPN';
	@override String get connect => 'Sambungkan G VPN';
	@override String get again => 'Uji lagi';
	@override String get withoutVpn => 'TANPA VPN';
	@override String get throughVpn => 'LEWAT G VPN';
	@override String get notChecked => 'Belum dicek';
	@override String get opens => 'Terbuka';
	@override String get stillBlocked => 'Diblokir';
	@override String get whatHappened => 'APA YANG TERJADI';
	@override String countryBlocked({required Object country}) => 'situs diblokir di ${country}';
	@override String get countrySub => 'Ditemukan oleh tes relawan dalam 30 hari terakhir';
	@override String get countryNone => 'Tidak ada situs diblokir yang dilaporkan dalam 30 hari terakhir.';
	@override String get countryUnavailable => 'Gagal memuat hasil negara. Periksa koneksi Anda.';
	@override String get confirmed => 'DIBLOKIR';
	@override String get oftenFails => 'SERING GAGAL';
	@override late final _Translations$blocked$kinds$id kinds = _Translations$blocked$kinds$id._(_root);
	@override late final _Translations$blocked$how$id how = _Translations$blocked$how$id._(_root);
	@override late final _Translations$blocked$fail$id fail = _Translations$blocked$fail$id._(_root);
	@override late final _Translations$blocked$steps$id steps = _Translations$blocked$steps$id._(_root);
	@override late final _Translations$blocked$consent$id consent = _Translations$blocked$consent$id._(_root);
	@override String someBlocked({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} situs diblokir di ${network}',
	);
	@override String tests({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n,
		other: '${n} tes',
	);
}

// Path: home.status
class _Translations$home$status$id extends Translations$home$status$en {
	_Translations$home$status$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get paused => 'Dijeda';
	@override String get reconnecting => 'Menyambung ulang';
	@override String get protected => 'Terlindungi';
	@override String get connecting => 'Menghubungkan';
	@override String get stopping => 'Memutuskan';
	@override String get notProtected => 'Tidak terlindungi';
}

// Path: home.network
class _Translations$home$network$id extends Translations$home$network$en {
	_Translations$home$network$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'JARINGAN INI';
	@override String get wifi => 'Wi-Fi';
	@override String get offline => 'Offline';
	@override String get showName => 'Tampilkan nama';
	@override String get scanFailed => 'Pemeriksaan gagal. Akan dijalankan lagi saat jaringan berubah.';
}

// Path: home.card
class _Translations$home$card$id extends Translations$home$card$en {
	_Translations$home$card$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get downloaded => 'DIUNDUH';
	@override String get uploaded => 'DIUNGGAH';
	@override String get wireguard => 'WireGuard';
	@override String openvpn({required Object proto}) => 'OpenVPN ${proto}';
	@override String get selected => 'DIPILIH';
	@override String get browsingFrom => 'MENJELAJAH DARI';
	@override String get disconnect => 'Putuskan';
	@override String get change => 'Ganti';
	@override String get enabled => 'Aktif';
	@override String get shield => 'PERISAI';
}

// Path: home.tiles
class _Translations$home$tiles$id extends Translations$home$tiles$en {
	_Translations$home$tiles$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get shield => 'Perisai';
	@override String get appsDirect => 'Aplikasi langsung';
	@override String get appsAll => 'Semua aplikasi terlindungi';
	@override String appsSkip({required Object n}) => '${n} tanpa VPN';
	@override String get autoConnect => 'Sambung otomatis';
	@override String get autoOpen => 'Di Wi-Fi publik';
	@override String get autoAny => 'Di semua Wi-Fi';
	@override String get speed => 'Kecepatan';
	@override String get speedTap => 'Ketuk untuk tes';
	@override String speedDirect({required Object mbps}) => 'Langsung ${mbps} Mbps';
}

// Path: home.fastest
class _Translations$home$fastest$id extends Translations$home$fastest$en {
	_Translations$home$fastest$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Server gratis tercepat';
	@override String get pickedFrom => 'Dipilih dari';
	@override String more({required Object n}) => '+${n}';
	@override String get finding => 'Mencari server tercepat';
	@override String get failed => 'Server gratis tidak dapat dimuat';
	@override String get how => 'Cara server dipilih';
	@override String get sheetBody => 'G VPN menghubungkan Anda ke server gratis dengan peringkat terbaik saat ini, berdasarkan kecepatan, beban, dan lama server menyala. Peringkat berubah saat server datang dan pergi.';
}

// Path: home.ip
class _Translations$home$ip$id extends Translations$home$ip$en {
	_Translations$home$ip$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Yang dilihat situs';
	@override String get real => 'Lokasi asli Anda';
	@override String get vpn => 'Lokasi VPN';
	@override String get address => 'Alamat IP';
	@override String get coordinates => 'Koordinat';
	@override String get note => 'Perkiraan dari IP Anda. Tidak pernah disimpan.';
	@override String get hide => 'Sembunyikan lokasi saya';
	@override String near({required Object place}) => 'Dekat ${place}';
}

// Path: servers.tabs
class _Translations$servers$tabs$id extends Translations$servers$tabs$en {
	_Translations$servers$tabs$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get pro => 'Pro';
	@override String get free => 'Gratis';
	@override String get yours => 'Milik Anda';
}

// Path: servers.sheet
class _Translations$servers$sheet$id extends Translations$servers$sheet$en {
	_Translations$servers$sheet$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Asal server';
	@override String get subtitle => 'Tiga jenis, satu daftar';
	@override String get free => 'Server sukarelawan, diperiksa setiap dua jam. Pengelolanya menyimpan log koneksi sekitar dua minggu.';
	@override String get pro => 'Dikelola oleh kami dengan WireGuard. Tanpa log aktivitas, tanpa akun.';
	@override String get yours => 'Server WireGuard apa pun milik Anda: router, VPS, atau server rumah.';
}

// Path: servers.badges
class _Translations$servers$badges$id extends Translations$servers$badges$en {
	_Translations$servers$badges$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get mostUsed => 'PALING BANYAK DIPAKAI';
	@override String get mostStable => 'PALING STABIL';
	@override String get fastest => 'TERCEPAT';
}

// Path: servers.filters
class _Translations$servers$filters$id extends Translations$servers$filters$en {
	_Translations$servers$filters$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get all => 'Semua';
	@override String get fastest => 'Tercepat';
	@override String get stable => 'Paling stabil';
	@override String get popular => 'Populer';
}

// Path: servers.own
class _Translations$servers$own$id extends Translations$servers$own$en {
	_Translations$servers$own$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jalankan server Anda sendiri';
	@override String get subtitle => 'Server WireGuard apa pun bisa';
	@override String get router => 'Router';
	@override String get routerBody => 'Banyak router punya WireGuard bawaan. Ekspor konfigurasi klien dan pindai kode QR-nya di sini.';
	@override String get vps => 'VPS';
	@override String get vpsBody => 'Server Linux kecil apa pun. Pasang WireGuard, buat klien, lalu impor file konfigurasinya.';
	@override String get home => 'Server rumah';
	@override String get homeBody => 'Akses jaringan Anda sendiri dari mana saja, dengan cara yang sama.';
	@override String get noneYet => 'Belum punya server?';
	@override String get addAnother => 'Tambah lagi';
	@override String get hint => 'Jalankan di router, VPS, atau server rumah';
}

// Path: pro.free
class _Translations$pro$free$id extends Translations$pro$free$en {
	_Translations$pro$free$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Paket Anda';
	@override String get headline => 'Semuanya gratis';
	@override String get body => 'Semua server dan semua alat, tanpa akun dan tanpa iklan.';
	@override String get included => 'Termasuk';
	@override String get servers => 'Server gratis';
	@override String get serversSub => 'Diurutkan menurut kecepatan dan stabilitas di puluhan negara';
	@override String get own => 'Server Anda sendiri';
	@override String get ownSub => 'Hubungkan ke router, VPS, atau server rumah WireGuard apa pun';
	@override String get shield => 'Perisai';
	@override String get shieldSub => 'Memblokir situs malware dan phishing yang dikenal';
	@override String get auto => 'Sambung otomatis dan aturan aplikasi';
	@override String get autoSub => 'Lindungi Wi-Fi publik; biarkan aplikasi bank langsung';
	@override String get pause => 'Jeda dan Setelan Cepat';
	@override String get pauseSub => 'Jeda dari notifikasi, aktifkan dari ubin';
	@override String get tools => 'Semua alat jaringan';
	@override String get toolsSub => 'Tes kecepatan, ping, status layanan, traceroute, perangkat, dan lainnya';
	@override String get later => 'G VPN Pro akan menambah server lebih cepat yang dikelola oleh kami. Semua di atas tetap gratis.';
}

// Path: rules.info
class _Translations$rules$info$id extends Translations$rules$info$en {
	_Translations$rules$info$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get shield => 'Perisai menyaring pencarian DNS saat Anda terhubung: Quad9 memblokir malware dan phishing, Cloudflare for Families juga memblokir situs dewasa, atau pakai DNS Anda sendiri. Tidak pernah memblokir iklan.';
	@override String get autoConnect => 'Sambung otomatis: memakai server WireGuard pilihan Anda. Memutus secara manual menjedanya sampai Anda bergabung ke jaringan lain.';
	@override String get apps => 'Aplikasi langsung: aplikasi yang melewati VPN terhubung langsung. Bank sering memblokir alamat VPN, jadi pembayaran bisa gagal lewat VPN.';
	@override String get reconnect => 'Mengubah Perisai atau aplikasi akan menyambungkan ulang VPN sebentar.';
	@override String get stay => 'Tetap terhubung: beberapa ponsel menghentikan aplikasi di latar belakang untuk menghemat baterai. VPN selalu aktif dan setelan baterai tanpa batasan menjaga G VPN tetap berjalan.';
}

// Path: devices.kinds
class _Translations$devices$kinds$id extends Translations$devices$kinds$en {
	_Translations$devices$kinds$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get phone => 'Ponsel';
	@override String get computer => 'Komputer';
	@override String get tv => 'TV';
	@override String get speaker => 'Speaker';
	@override String get printer => 'Printer';
	@override String get camera => 'Kamera';
	@override String get smartHome => 'Rumah pintar';
	@override String get router => 'Router';
	@override String get unknown => 'Tidak diumumkan';
}

// Path: map.grade
class _Translations$map$grade$id extends Translations$map$grade$en {
	_Translations$map$grade$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get fast => 'Cepat';
	@override String get good => 'Baik';
	@override String get slow => 'Lambat';
}

// Path: presets.names
class _Translations$presets$names$id extends Translations$presets$names$en {
	_Translations$presets$names$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get fastest => 'Tercepat';
	@override String get unblock => 'Buka blokir';
	@override String get streaming => 'Streaming';
	@override String get privacy => 'Privasi maksimal';
}

// Path: providers.tags
class _Translations$providers$tags$id extends Translations$providers$tags$en {
	_Translations$providers$tags$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get fast => 'Cepat';
	@override String get reliable => 'Andal';
	@override String get support => 'Dukungan baik';
	@override String get price => 'Harga wajar';
	@override String get slowEvenings => 'Lambat malam hari';
	@override String get drops => 'Sering putus';
	@override String get poorSupport => 'Dukungan buruk';
	@override String get pricey => 'Mahal';
}

// Path: providers.words
class _Translations$providers$words$id extends Translations$providers$words$en {
	_Translations$providers$words$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get bad => 'Buruk';
	@override String get poor => 'Kurang';
	@override String get okay => 'Lumayan';
	@override String get good => 'Bagus';
	@override String get great => 'Hebat';
}

// Path: alerts.kinds
class _Translations$alerts$kinds$id extends Translations$alerts$kinds$en {
	_Translations$alerts$kinds$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get newDevice => 'Perangkat baru di Wi-Fi saya';
	@override String get openWifi => 'Wi-Fi terbuka atau lemah';
	@override String get blocked => 'Aplikasi diblokir';
	@override String get report => 'Laporan mingguan';
	@override String get breach => 'Kebocoran';
}

// Path: alerts.status
class _Translations$alerts$status$id extends Translations$alerts$status$en {
	_Translations$alerts$status$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get background => 'Setiap beberapa jam';
	@override String checked({required Object time}) => 'Dicek pukul ${time}';
	@override String get wifi => 'Setiap jaringan yang Anda masuki';
	@override String get blocked => 'Saat status layanan dicek';
	@override String get report => 'Setiap Senin';
}

// Path: blocked.kinds
class _Translations$blocked$kinds$id extends Translations$blocked$kinds$en {
	_Translations$blocked$kinds$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get social => 'Media sosial';
	@override String get messaging => 'Pesan';
	@override String get news => 'Berita';
	@override String get video => 'Video dan musik';
	@override String get privacy => 'Privasi';
}

// Path: blocked.how
class _Translations$blocked$how$id extends Translations$blocked$how$en {
	_Translations$blocked$how$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get dns => 'Alamat palsu';
	@override String get reset => 'Diputus';
	@override String get timeout => 'Tidak ada jawaban';
	@override String get page => 'Halaman blokir';
	@override String get open => 'Terbuka';
}

// Path: blocked.fail
class _Translations$blocked$fail$id extends Translations$blocked$fail$en {
	_Translations$blocked$fail$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get noAnswer => 'tidak ada jawaban';
	@override String get refused => 'ditolak';
	@override String cutOff({required Object s}) => 'diputus setelah ${s} dtk';
	@override String get wrongCert => 'sertifikat salah';
}

// Path: blocked.steps
class _Translations$blocked$steps$id extends Translations$blocked$steps$en {
	_Translations$blocked$steps$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get lookup => 'Pencarian nama';
	@override String get connect => 'Sambung';
	@override String get handshake => 'Jabat tangan aman';
}

// Path: blocked.consent
class _Translations$blocked$consent$id extends Translations$blocked$consent$en {
	_Translations$blocked$consent$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sebelum tes pertama';
	@override String get body => 'Tes membuka tiap situs dari ponsel ini, tanpa VPN, seperti browser.';
	@override String get noticeTitle => 'Bisa terlihat';
	@override String get notice => 'Penyedia Anda melihat situs ini dibuka. Di beberapa negara mengunjunginya, meski hanya untuk tes, bisa menarik perhatian. Uji hanya jika Anda merasa aman.';
	@override String get ok => 'Saya mengerti, uji';
}

/// The flat map containing all translations for locale <id>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsId {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.gotIt' => 'Mengerti',
			'common.about' => 'Tentang',
			'common.connect' => 'Hubungkan',
			'common.connected' => 'Terhubung',
			'common.retry' => 'Coba lagi',
			'common.ok' => 'OK',
			'common.remove' => 'Hapus',
			'common.cancel' => 'Batal',
			'common.continueLabel' => 'Lanjutkan',
			'common.notNow' => 'Nanti saja',
			'common.openSettings' => 'Buka setelan',
			'common.close' => 'Tutup',
			'common.off' => 'Mati',
			'common.changesReconnect' => 'Perubahan akan menyambungkan ulang VPN',
			'nav.vpn' => 'VPN',
			'nav.servers' => 'Server',
			'nav.tools' => 'Alat',
			'nav.rules' => 'Aturan',
			'nav.pro' => 'Pro',
			'home.status.paused' => 'Dijeda',
			'home.status.reconnecting' => 'Menyambung ulang',
			'home.status.protected' => 'Terlindungi',
			'home.status.connecting' => 'Menghubungkan',
			'home.status.stopping' => 'Memutuskan',
			'home.status.notProtected' => 'Tidak terlindungi',
			'home.resumesAt' => ({required Object time}) => 'Lanjut pukul ${time} · ketuk untuk lanjut sekarang',
			'home.ipFailed' => 'Tidak dapat memeriksa IP Anda',
			'home.ipChecking' => 'Memeriksa IP Anda',
			'home.themeSystem' => 'Tema: ikuti ponsel',
			'home.themeLight' => 'Tema: terang',
			'home.themeDark' => 'Tema: gelap',
			'home.free' => 'Gratis',
			'home.pickServer' => 'Pilih server',
			'home.network.title' => 'JARINGAN INI',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Offline',
			'home.network.showName' => 'Tampilkan nama',
			'home.network.scanFailed' => 'Pemeriksaan gagal. Akan dijalankan lagi saat jaringan berubah.',
			'home.card.downloaded' => 'DIUNDUH',
			'home.card.uploaded' => 'DIUNGGAH',
			'home.card.wireguard' => 'WireGuard',
			'home.card.openvpn' => ({required Object proto}) => 'OpenVPN ${proto}',
			'home.card.selected' => 'DIPILIH',
			'home.card.browsingFrom' => 'MENJELAJAH DARI',
			'home.card.disconnect' => 'Putuskan',
			'home.card.change' => 'Ganti',
			'home.card.enabled' => 'Aktif',
			'home.card.shield' => 'PERISAI',
			'home.tiles.shield' => 'Perisai',
			'home.tiles.appsDirect' => 'Aplikasi langsung',
			'home.tiles.appsAll' => 'Semua aplikasi terlindungi',
			'home.tiles.appsSkip' => ({required Object n}) => '${n} tanpa VPN',
			'home.tiles.autoConnect' => 'Sambung otomatis',
			'home.tiles.autoOpen' => 'Di Wi-Fi publik',
			'home.tiles.autoAny' => 'Di semua Wi-Fi',
			'home.tiles.speed' => 'Kecepatan',
			'home.tiles.speedTap' => 'Ketuk untuk tes',
			'home.tiles.speedDirect' => ({required Object mbps}) => 'Langsung ${mbps} Mbps',
			'home.fastest.title' => 'Server gratis tercepat',
			'home.fastest.pickedFrom' => 'Dipilih dari',
			'home.fastest.more' => ({required Object n}) => '+${n}',
			'home.fastest.finding' => 'Mencari server tercepat',
			'home.fastest.failed' => 'Server gratis tidak dapat dimuat',
			'home.fastest.how' => 'Cara server dipilih',
			'home.fastest.sheetBody' => 'G VPN menghubungkan Anda ke server gratis dengan peringkat terbaik saat ini, berdasarkan kecepatan, beban, dan lama server menyala. Peringkat berubah saat server datang dan pergi.',
			'home.ip.title' => 'Yang dilihat situs',
			'home.ip.real' => 'Lokasi asli Anda',
			'home.ip.vpn' => 'Lokasi VPN',
			'home.ip.address' => 'Alamat IP',
			'home.ip.coordinates' => 'Koordinat',
			'home.ip.note' => 'Perkiraan dari IP Anda. Tidak pernah disimpan.',
			'home.ip.hide' => 'Sembunyikan lokasi saya',
			'home.ip.near' => ({required Object place}) => 'Dekat ${place}',
			'servers.title' => 'Server',
			'servers.aboutServers' => 'Tentang server',
			'servers.tabs.pro' => 'Pro',
			'servers.tabs.free' => 'Gratis',
			'servers.tabs.yours' => 'Milik Anda',
			'servers.sheet.title' => 'Asal server',
			'servers.sheet.subtitle' => 'Tiga jenis, satu daftar',
			'servers.sheet.free' => 'Server sukarelawan, diperiksa setiap dua jam. Pengelolanya menyimpan log koneksi sekitar dua minggu.',
			'servers.sheet.pro' => 'Dikelola oleh kami dengan WireGuard. Tanpa log aktivitas, tanpa akun.',
			'servers.sheet.yours' => 'Server WireGuard apa pun milik Anda: router, VPS, atau server rumah.',
			'servers.badges.mostUsed' => 'PALING BANYAK DIPAKAI',
			'servers.badges.mostStable' => 'PALING STABIL',
			'servers.badges.fastest' => 'TERCEPAT',
			'servers.filters.all' => 'Semua',
			'servers.filters.fastest' => 'Tercepat',
			'servers.filters.stable' => 'Paling stabil',
			'servers.filters.popular' => 'Populer',
			'servers.loadFailed' => 'Tidak dapat memuat daftar',
			'servers.noServers' => 'Belum ada server saat ini',
			'servers.best' => 'TERBAIK UNTUK ANDA SAAT INI',
			'servers.topRanked' => 'Peringkat teratas saat ini',
			'servers.addHeading' => 'TAMBAH SERVER',
			'servers.scanQr' => 'Pindai QR',
			'servers.importFile' => 'Impor file',
			'servers.paste' => 'Tempel',
			'servers.own.title' => 'Jalankan server Anda sendiri',
			'servers.own.subtitle' => 'Server WireGuard apa pun bisa',
			'servers.own.router' => 'Router',
			'servers.own.routerBody' => 'Banyak router punya WireGuard bawaan. Ekspor konfigurasi klien dan pindai kode QR-nya di sini.',
			'servers.own.vps' => 'VPS',
			'servers.own.vpsBody' => 'Server Linux kecil apa pun. Pasang WireGuard, buat klien, lalu impor file konfigurasinya.',
			'servers.own.home' => 'Server rumah',
			'servers.own.homeBody' => 'Akses jaringan Anda sendiri dari mana saja, dengan cara yang sama.',
			'servers.own.noneYet' => 'Belum punya server?',
			'servers.own.addAnother' => 'Tambah lagi',
			'servers.own.hint' => 'Jalankan di router, VPS, atau server rumah',
			'servers.configBroken' => 'Konfigurasi perlu diperiksa',
			'servers.connectedBadge' => 'TERHUBUNG',
			'servers.scannedServer' => 'Server hasil pindaian',
			'servers.scanFailedTitle' => 'Tidak dapat memindai',
			'servers.scanFailedBody' => 'Pemindai tidak tersedia di ponsel ini.',
			'servers.importFailedTitle' => 'Tidak dapat mengimpor',
			'servers.importFailedBody' => 'File itu tidak dapat dibaca.',
			'servers.renameTitle' => 'Ganti nama server',
			'servers.nameHint' => 'Nama, misalnya Router rumah',
			'servers.save' => 'Simpan',
			'servers.rename' => 'Ganti nama',
			'servers.disconnect' => 'Putuskan',
			'servers.more' => 'Opsi lainnya',
			'servers.justNow' => 'baru saja',
			'servers.minutesAgo' => ({required Object n}) => '${n} mnt lalu',
			'servers.hoursAgo' => ({required Object n}) => '${n} jam lalu',
			'servers.daysAgo' => ({required Object n}) => '${n} hari lalu',
			'servers.neverUsed' => 'Belum pernah dipakai',
			'servers.lastUsed' => ({required Object when}) => 'Terakhir dipakai ${when}',
			'servers.disconnectFirst' => 'Putuskan dulu untuk menghapusnya',
			'servers.removeConfirm' => 'Hapus server ini dari G VPN? Setelannya dihapus dari ponsel ini; server itu sendiri tidak berubah.',
			'servers.gTab' => 'G Servers',
			'servers.search' => 'Cari negara',
			'servers.noMatch' => 'Tidak ada server yang cocok.',
			'servers.bestPing' => ({required Object ms}) => 'terbaik ${ms} ms',
			'servers.bestTag' => 'TERBAIK',
			'servers.ownHero' => 'Server milik kami',
			'servers.ownHeroSub' => 'Lebih cepat, privat, tiap ponsel punya kunci sendiri',
			'servers.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} server', ), 
			'servers.showAll' => ({required Object n}) => 'Tampilkan semua ${n}',
			'servers.showFewer' => 'Tampilkan lebih sedikit',
			'servers.fastTab' => 'Cepat',
			'servers.fastestFree' => 'Gratis tercepat',
			'pro.owned' => 'Anda punya Pro',
			'pro.waitingPlay' => 'Menunggu Google Play',
			'pro.startTrial' => ({required Object days}) => 'Mulai uji coba gratis ${days} hari',
			'pro.restore' => 'Pulihkan',
			'pro.save' => ({required Object pct}) => 'HEMAT ${pct}%',
			'pro.yearly' => 'Tahunan',
			'pro.monthly' => 'Bulanan',
			'pro.billedMonthly' => 'ditagih bulanan',
			'pro.daysFree' => ({required Object days}) => '${days} hari gratis',
			'pro.perMonth' => ({required Object price}) => '${price} per bulan',
			'pro.title' => 'G VPN Pro',
			'pro.renewGeneric' => 'Langganan diperpanjang otomatis hingga dibatalkan. Batalkan kapan saja di Google Play.',
			'pro.renewTrial' => ({required Object days, required Object price, required Object period}) => '${days} hari gratis, lalu ${price} per ${period}. Diperpanjang otomatis hingga dibatalkan; batalkan di Google Play paling lambat sehari sebelum uji coba berakhir agar tidak ditagih.',
			'pro.renew' => ({required Object price, required Object period}) => '${price} per ${period}. Diperpanjang otomatis hingga dibatalkan; batalkan kapan saja di Google Play.',
			'pro.year' => 'tahun',
			'pro.month' => 'bulan',
			'pro.manage' => 'Kelola langganan',
			'pro.free.title' => 'Paket Anda',
			'pro.free.headline' => 'Semuanya gratis',
			'pro.free.body' => 'Semua server dan semua alat, tanpa akun dan tanpa iklan.',
			'pro.free.included' => 'Termasuk',
			'pro.free.servers' => 'Server gratis',
			'pro.free.serversSub' => 'Diurutkan menurut kecepatan dan stabilitas di puluhan negara',
			'pro.free.own' => 'Server Anda sendiri',
			'pro.free.ownSub' => 'Hubungkan ke router, VPS, atau server rumah WireGuard apa pun',
			'pro.free.shield' => 'Perisai',
			'pro.free.shieldSub' => 'Memblokir situs malware dan phishing yang dikenal',
			'pro.free.auto' => 'Sambung otomatis dan aturan aplikasi',
			'pro.free.autoSub' => 'Lindungi Wi-Fi publik; biarkan aplikasi bank langsung',
			'pro.free.pause' => 'Jeda dan Setelan Cepat',
			'pro.free.pauseSub' => 'Jeda dari notifikasi, aktifkan dari ubin',
			'pro.free.tools' => 'Semua alat jaringan',
			'pro.free.toolsSub' => 'Tes kecepatan, ping, status layanan, traceroute, perangkat, dan lainnya',
			'pro.free.later' => 'G VPN Pro akan menambah server lebih cepat yang dikelola oleh kami. Semua di atas tetap gratis.',
			'pro.heroLine' => 'Server cepat milik kami, dan semua pengecekan tanpa batas',
			'pro.start' => 'Mulai Pro',
			'pro.compareFree' => 'GRATIS',
			'pro.comparePro' => 'PRO',
			'pro.rowFreeServers' => 'Server gratis',
			'pro.rowTools' => 'Tes kecepatan, alat, cek Wi-Fi',
			'pro.rowGServers' => 'G Servers, tanpa log',
			'pro.rowLinks' => 'Cek tautan',
			'pro.linksFree' => ({required Object n}) => '${n} per bulan',
			'pro.unlimited' => 'Tanpa batas',
			'rules.title' => 'Aturan',
			'rules.info.shield' => 'Perisai menyaring pencarian DNS saat Anda terhubung: Quad9 memblokir malware dan phishing, Cloudflare for Families juga memblokir situs dewasa, atau pakai DNS Anda sendiri. Tidak pernah memblokir iklan.',
			'rules.info.autoConnect' => 'Sambung otomatis: memakai server WireGuard pilihan Anda. Memutus secara manual menjedanya sampai Anda bergabung ke jaringan lain.',
			'rules.info.apps' => 'Aplikasi langsung: aplikasi yang melewati VPN terhubung langsung. Bank sering memblokir alamat VPN, jadi pembayaran bisa gagal lewat VPN.',
			'rules.info.reconnect' => 'Mengubah Perisai atau aplikasi akan menyambungkan ulang VPN sebentar.',
			'rules.info.stay' => 'Tetap terhubung: beberapa ponsel menghentikan aplikasi di latar belakang untuk menghemat baterai. VPN selalu aktif dan setelan baterai tanpa batasan menjaga G VPN tetap berjalan.',
			'rules.protection' => 'Perlindungan',
			'rules.shield' => 'Perisai',
			'rules.privateDns' => 'Perisai tanpa VPN',
			'rules.privateDnsSub' => 'Salin dns.quad9.net untuk DNS Pribadi',
			'rules.privateDnsCopied' => 'dns.quad9.net disalin',
			'rules.privateDnsHow' => 'Buka Setelan, cari DNS Pribadi, pilih "Nama host penyedia DNS pribadi", lalu tempelkan.',
			'rules.stay' => 'Tetap terhubung',
			'rules.alwaysOn' => 'VPN selalu aktif',
			'rules.alwaysOnSub' => 'Android memulai ulang G VPN jika berhenti',
			'rules.battery' => 'Baterai',
			'rules.batteryOk' => 'Tanpa batasan',
			'rules.batteryRestricted' => 'Dibatasi: bisa berhenti di latar belakang',
			'rules.autoConnect' => 'Sambung otomatis',
			'rules.autoOff' => 'Mati',
			'rules.autoOffSub' => 'Hanya saat Anda mengetuk',
			'rules.autoOpen' => 'Wi-Fi publik',
			'rules.autoOpenSub' => 'Jaringan terbuka, WEP, atau dengan halaman masuk',
			'rules.autoAny' => 'Semua Wi-Fi',
			'rules.autoAnySub' => 'Jaringan Wi-Fi apa pun',
			'rules.apps' => 'Aplikasi',
			'rules.appsDirect' => 'Aplikasi langsung',
			'rules.appsNone' => 'Semua aplikasi memakai VPN',
			'rules.appsSome' => ({required Object n}) => '${n} aplikasi tanpa VPN',
			'rules.appearance' => 'Tampilan',
			'rules.themePhone' => 'Ponsel',
			'rules.themeLight' => 'Terang',
			'rules.themeDark' => 'Gelap',
			'rules.about' => 'Tentang',
			'apps.title' => 'Aplikasi langsung',
			'apps.sheetSubtitle' => 'Aplikasi pilihan terhubung tanpa VPN. Lainnya tetap terlindungi.',
			'apps.whyTitle' => 'Mengapa mengecualikan aplikasi',
			'apps.whyBody' => 'Bank dan aplikasi pembayaran sering memblokir alamat VPN, jadi pembayaran bisa gagal lewat VPN. Beberapa layanan lokal hanya berfungsi dari negara Anda sendiri.',
			'apps.favouritesBody' => 'Beri bintang pada aplikasi yang sering Anda ubah; aplikasi itu tetap di atas.',
			'apps.whileConnected' => 'Saat terhubung',
			'apps.whileConnectedBody' => 'Mengubah daftar ini akan menyambungkan ulang VPN sebentar.',
			'apps.search' => ({required Object n}) => 'Cari ${n} aplikasi',
			'apps.skipping' => 'Tanpa VPN',
			'apps.skippingNone' => 'Tidak ada. Semua aplikasi melewati VPN.',
			'apps.protectAgain' => ({required Object app}) => 'Lindungi ${app} lagi',
			'apps.banking' => 'Bank dan pembayaran',
			'apps.bankingFound' => ({required Object n}) => '${n} ditemukan yang mungkin memblokir VPN',
			'apps.addAll' => 'Tambah semua',
			'apps.favourites' => 'Favorit',
			'apps.all' => 'Semua aplikasi',
			'apps.found' => ({required Object n}) => '${n} ditemukan',
			'apps.noMatch' => 'Tidak ada aplikasi yang cocok.',
			'apps.showAll' => ({required Object n}) => 'Tampilkan semua ${n}',
			'apps.skips' => 'Tanpa VPN',
			'apps.unstar' => 'Hapus dari favorit',
			'apps.star' => 'Tambah ke favorit',
			'location.title' => 'Izinkan lokasi untuk Wi-Fi',
			'location.useHome' => 'Tampilkan nama Wi-Fi di Beranda',
			'location.useScan' => 'Pindai jaringan dan kanal di sekitar',
			'location.private' => 'Tetap di ponsel ini. Lokasi Anda tidak pernah dikumpulkan.',
			'location.switchTitle' => 'Aktifkan Lokasi',
			'location.switchBody' => 'Android menyembunyikan nama Wi-Fi saat Lokasi mati',
			'addServer.clipboardEmpty' => 'Papan klip kosong.',
			'addServer.title' => 'Tambah server Anda',
			'addServer.body' => 'Tempelkan konfigurasi WireGuard dari router, VPS, atau server rumah Anda.',
			'addServer.nameHint' => 'Nama, misalnya Router rumah',
			'addServer.paste' => 'Tempel',
			'addServer.save' => 'Simpan server',
			'addServer.notWireguard' => ({required Object error}) => 'Ini bukan konfigurasi WireGuard: ${error}',
			'button.stop' => 'Hentikan',
			'button.connecting' => 'Menghubungkan',
			'button.stopping' => 'Memutuskan',
			'button.connect' => 'Hubungkan',
			'button.disconnect' => 'Putuskan',
			'wol.info' => 'Menyalakan komputer atau NAS di Wi-Fi ini, jika Wake on LAN aktif di setelannya. Ponsel Anda harus di jaringan yang sama; matikan VPN terlebih dahulu.',
			'wol.badMac' => 'Itu bukan alamat MAC. Bentuknya seperti AA:BB:CC:DD:EE:FF.',
			'wol.sent' => 'Sinyal dikirim. Perangkat seharusnya menyala dalam satu menit.',
			'wol.title' => 'Wake on LAN',
			'wol.mac' => 'Alamat MAC',
			'wol.failed' => ({required Object error}) => 'Tidak dapat mengirim: ${error}',
			'wol.computer' => 'Komputer',
			'wol.pick' => 'Pilih perangkat untuk dinyalakan',
			'wol.waking' => ({required Object name}) => 'Menyalakan ${name}',
			'wol.yours' => 'PERANGKAT ANDA',
			'wol.wakeNamed' => ({required Object name}) => 'Nyalakan ${name}',
			'wol.removeHint' => 'Tahan perangkat untuk menghapusnya',
			'wol.add' => 'TAMBAH PERANGKAT',
			'wol.name' => 'Nama',
			'wol.saveWake' => 'Simpan dan nyalakan',
			'speed.download' => 'Unduh',
			'speed.upload' => 'Unggah',
			'speed.finding' => 'Mencari server',
			'speed.throughVpn' => 'Melalui VPN',
			'speed.directNoVpn' => 'Langsung, tanpa VPN',
			'speed.title' => 'Tes kecepatan',
			'speed.stop' => 'Hentikan',
			'speed.start' => 'Mulai tes',
			'speed.again' => 'Tes lagi',
			'speed.viaVpn' => 'Lewat VPN',
			'speed.direct' => 'Langsung',
			'speed.mbps' => 'Mbps',
			'speed.ping' => 'PING',
			'speed.vsDirect' => 'VS LANGSUNG',
			'speed.compare' => 'Bandingkan dengan penyedia sekitar',
			'speed.compareSub' => 'Hanya membagikan kecepatan, tidak pernah IP Anda',
			'speed.tierTv' => 'TV besar',
			'speed.tierLaptopLarge' => 'Laptop besar',
			'speed.tierTablet' => 'Tablet dan laptop',
			'speed.tierPhone' => 'Ponsel',
			'speed.tierSmallPhone' => 'Ponsel kecil',
			'speed.tierCalls' => 'Panggilan dan audio',
			'speed.messagingOnly' => 'Hanya perpesanan',
			'speed.videoQuality' => 'Kualitas video',
			'speed.preview' => 'PRATINJAU',
			'speed.history' => 'Riwayat',
			'speed.clear' => 'Hapus',
			'speed.viaVpnLower' => 'lewat VPN',
			'speed.directLower' => 'langsung',
			'speed.gradeA' => 'Beberapa streaming 4K dan panggilan video sekaligus',
			'speed.gradeB' => 'Streaming HD dan panggilan video lancar',
			'speed.gradeC' => 'Satu streaming HD; panggilan bisa tersendat saat ramai',
			'speed.gradeD' => 'Menjelajah dan perpesanan; video tersendat',
			'speed.yourCountry' => 'negara Anda',
			'speed.median' => 'Median unduhan, 30 hari terakhir',
			'speed.fromUsers' => 'Mbps · dari tes pengguna G VPN',
			'speed.costLittle' => 'Hanya sedikit kecepatan hilang karena VPN',
			'speed.costNoticeable' => 'Terasa lebih lambat daripada langsung',
			'speed.costMuch' => 'Jauh lebih lambat. Coba server lain',
			'speed.ofDirect' => 'dari kecepatan langsung Anda',
			'speed.none' => 'tidak ada',
			'speed.ms' => ({required Object n}) => '${n} md',
			'speed.previewTier' => ({required Object tier}) => 'PRATINJAU · ${tier}',
			'speed.streamsUpTo' => ({required Object tier, required Object who}) => 'Streaming hingga ${tier} · ${who}',
			'speed.today' => ({required Object time}) => 'Hari ini, ${time}',
			'speed.tests' => ({required Object n}) => '${n} tes',
			'speed.gradeVpn' => ({required Object label}) => '${label} melalui VPN',
			'speed.gradeIsp' => ({required Object label, required Object isp}) => '${label} di ${isp}',
			'speed.notEnough' => ({required Object isp}) => 'Belum cukup tes untuk ${isp}',
			'speed.yourProvider' => 'penyedia Anda',
			'speed.rankLine' => ({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} di ${where}: ${rank} dari ${of}',
			'speed.costLine' => ({required Object note, required Object mbps}) => '${note} · langsung ${mbps} Mbps',
			'speed.mbpsValue' => ({required Object v}) => '${v} Mbps',
			'speed.gradeExcellent' => 'Luar biasa',
			'speed.gradeVeryGood' => 'Sangat baik',
			'speed.gradeGood' => 'Baik',
			'speed.gradeFair' => 'Cukup',
			'speed.gradeSlow' => 'Lambat',
			'speed.gradeVerySlow' => 'Sangat lambat',
			'router.info' => 'Menanyakan router Anda, lewat UPnP, apakah perangkat boleh membuka port ke internet sendiri, dan menampilkan port yang sudah dibuka. Hanya membaca dan tidak mengubah apa pun. Jika tidak ada yang membutuhkan UPnP (beberapa konsol game butuh), mematikannya di setelan router lebih aman.',
			'router.title' => 'Periksa router',
			'router.asking' => 'Menanyakan router',
			'router.again' => 'Periksa lagi',
			'router.check' => 'Periksa router',
			'router.off' => 'UPnP mati',
			'router.offBody' => 'Perangkat tidak dapat membuka port sendiri.',
			'router.onBody' => 'Saat ini tidak ada port yang dibuka lewat UPnP.',
			'router.checkEach' => 'Pastikan Anda mengenali setiap port.',
			'router.cgnat' => 'Alamat penyedia bersama: tidak dapat dijangkau dari internet.',
			'router.noDescription' => 'Tanpa deskripsi',
			'router.opened' => ({required Object n}) => '${n} port dibuka oleh perangkat',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} ke ${host}',
			'router.upnpOn' => 'UPnP aktif',
			'router.routerLabel' => 'Router',
			'router.internetAddress' => 'Alamat internet',
			'router.openedBy' => 'Dibuka oleh perangkat',
			'network.title' => 'Jaringan ini',
			'network.wifi' => 'Wi-Fi',
			'network.mobile' => 'Data seluler',
			'network.ethernet' => 'Ethernet',
			'network.offline' => 'Offline',
			'network.risky' => 'Jaringan berisiko. Hubungkan VPN di sini.',
			'network.review' => 'Perlu diperiksa sebelum Anda mempercayainya.',
			'network.covered' => 'Dilindungi VPN.',
			'network.safe' => 'Jaringan ini tampak aman.',
			'network.mobileSentence' => 'Data seluler.',
			'network.notConnected' => 'Tidak terhubung.',
			'network.showName' => 'Tampilkan nama',
			'network.sitesSee' => 'Situs melihat',
			'network.provider' => 'Penyedia',
			'network.location' => 'Lokasi',
			'network.couldNotCheck' => 'Tidak dapat memeriksa',
			'network.checking' => 'Memeriksa',
			'network.signal' => 'Sinyal',
			'network.linkSpeed' => 'Kecepatan tautan',
			'network.gateway' => 'Gateway',
			'network.none' => 'Tidak ada',
			'network.privateDns' => 'DNS Pribadi',
			'network.automatic' => 'Otomatis',
			'network.off' => 'Mati',
			'network.metered' => 'Berkuota',
			'network.yes' => 'Ya',
			'network.no' => 'Tidak',
			'network.readFailed' => ({required Object error}) => 'Tidak dapat membaca jaringan: ${error}',
			'devices.info' => 'Mengetuk setiap alamat dalam jangkauan Wi-Fi Anda dan meminta perangkat memperkenalkan diri. Perangkat yang menolak tetap dihitung: penolakan membuktikan perangkat itu ada.\n\nNama: dari yang dipublikasikan perangkat (Bonjour, UPnP, nama Windows) dan dari router Anda.\n\nPerangkat tak dikenal: Android menyembunyikan alamat perangkat keras dari aplikasi, jadi perangkat diam tanpa nama tidak dapat dikenali. Periksa daftar perangkat di router Anda untuk itu.\n\nBaru: perangkat yang tidak terlihat pada pindaian terakhir jaringan ini.',
			'devices.needWifi' => 'Hubungkan ke jaringan Wi-Fi terlebih dahulu.',
			'devices.title' => 'Perangkat',
			'devices.again' => 'Pindai lagi',
			'devices.looking' => 'Mencari perangkat',
			'devices.all' => 'Semua',
			'devices.phones' => 'Ponsel',
			'devices.tvs' => 'TV',
			'devices.computers' => 'Komputer',
			'devices.other' => 'Lainnya',
			'devices.thisPhone' => 'Ponsel ini',
			'devices.router' => 'Router',
			'devices.unknown' => 'Perangkat tak dikenal',
			'devices.address' => 'Alamat',
			'devices.answersIn' => 'Menjawab dalam',
			'devices.type' => 'Jenis',
			'devices.newBadge' => 'BARU',
			'devices.scanning' => ({required Object n}) => 'Memindai ${n} dari 254',
			'devices.newSince' => ({required Object n}) => '${n} baru sejak pindaian terakhir',
			'devices.ms' => ({required Object n}) => '${n} md',
			'devices.cameras' => 'Kamera',
			'devices.device' => 'Perangkat',
			'devices.online' => 'Online',
			'devices.model' => 'Model',
			'devices.announced' => 'Mengumumkan diri sebagai',
			'devices.services' => 'LAYANAN TERBUKA',
			'devices.checkingServices' => 'Memeriksa layanan',
			'devices.noServices' => 'Tidak ada layanan umum yang menjawab',
			'devices.rename' => 'Ganti nama',
			'devices.save' => 'Simpan',
			'devices.kinds.phone' => 'Ponsel',
			'devices.kinds.computer' => 'Komputer',
			'devices.kinds.tv' => 'TV',
			'devices.kinds.speaker' => 'Speaker',
			'devices.kinds.printer' => 'Printer',
			'devices.kinds.camera' => 'Kamera',
			'devices.kinds.smartHome' => 'Rumah pintar',
			'devices.kinds.router' => 'Router',
			'devices.kinds.unknown' => 'Tidak diumumkan',
			'devices.details' => 'Detail jaringan',
			'devices.listView' => 'Daftar',
			'devices.meshView' => 'Jaring',
			'devices.offlineHeading' => 'Offline',
			'devices.seen' => ({required Object when}) => 'Terlihat ${when}',
			'devices.agoMinutes' => ({required Object n}) => '${n} mnt lalu',
			'devices.agoHours' => ({required Object n}) => '${n} jam lalu',
			'devices.agoDays' => ({required Object n}) => '${n} hari lalu',
			'devices.throughVpn' => 'Lewat VPN',
			'devices.closer' => 'Lebih dekat = menjawab lebih cepat',
			'devices.yours' => 'Ini milik Anda?',
			'devices.mine' => 'Milik saya',
			'devices.notMine' => 'Bukan milik saya',
			'devices.whatIsIt' => 'Apa ini?',
			'devices.ourGuess' => ({required Object kind}) => 'Tebakan kami: ${kind}',
			'devices.groupPersonal' => 'Ponsel dan komputer',
			'devices.groupHome' => 'Rumah dan media',
			'devices.groupNetwork' => 'Jaringan dan rumah pintar',
			'devices.onlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} online', ), 
			'devices.offlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} offline', ), 
			'devices.toConfirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} perlu dikonfirmasi', ), 
			'ping.askTitle' => 'Ping host',
			'ping.askHint' => 'example.com atau 192.168.1.10',
			'ping.title' => 'Ping',
			'ping.router' => 'Router',
			'ping.pause' => 'Jeda',
			'ping.start' => 'Mulai',
			'ping.host' => 'Host',
			'ping.live' => 'Langsung',
			'ping.ago' => '60 dtk lalu',
			'ping.min' => 'MIN',
			'ping.avg' => 'RATA',
			'ping.jitter' => 'JITTER',
			'ping.loss' => 'LOSS',
			'ping.goodFor' => 'Cukup baik untuk',
			'ping.calls' => 'Panggilan video',
			'ping.games' => 'Game online',
			'ping.streaming' => 'Streaming',
			'ping.great' => 'Bagus',
			'ping.okay' => 'Lumayan',
			'ping.poor' => 'Buruk',
			'ping.lost' => 'hilang',
			'ping.now' => 'sekarang',
			'status.info' => 'Menghubungi setiap layanan tiga kali dan menampilkan jawaban tercepat.\n\nDiblokir di sini: layanan yang tidak menjawab langsung tetapi berfungsi lewat VPN diblokir oleh jaringan atau negara Anda.\n\nRiwayat: pemeriksaan 24 jam terakhir dari ponsel ini, hanya disimpan di ponsel ini.',
			'status.title' => 'Status layanan',
			'status.checking' => 'Memeriksa',
			'status.again' => 'Periksa lagi',
			'status.viaVpn' => 'Diperiksa lewat VPN',
			'status.direct' => 'Diperiksa langsung',
			'status.favourites' => 'Favorit',
			'status.edit' => 'Ubah',
			'status.last24' => '24 jam terakhir',
			'status.ago' => '24 jam lalu',
			'status.all' => 'Semua layanan',
			'status.pickFour' => 'Pilih hingga empat',
			'status.outage' => 'Bahkan lewat VPN: kemungkinan gangguan',
			'status.blocked' => 'Mungkin diblokir di jaringan ini',
			'status.connect' => 'Hubungkan',
			'status.blockedShort' => 'Diblokir',
			'status.now' => 'sekarang',
			'status.checks' => ({required Object n}) => '${n} pemeriksaan',
			'status.andMore' => ({required Object first, required Object n}) => '${first} dan ${n} lainnya',
			'status.notReachable' => ({required Object who}) => '${who} tidak terjangkau',
			'tools.wifi' => 'Wi-Fi',
			'tools.mobile' => 'Data seluler',
			'tools.ethernet' => 'Ethernet',
			'tools.checking' => 'Memeriksa',
			'tools.offline' => 'Offline',
			'tools.title' => 'Alat',
			'tools.networkDesc' => 'Pemeriksaan keamanan, apa yang dilihat situs, sinyal, router, dan DNS.',
			'tools.internet' => 'Internet',
			'tools.speed' => 'Tes kecepatan',
			'tools.speedDesc' => 'Unduh, unggah, dan kualitas video',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'Waktu respons dan jitter langsung',
			'tools.status' => 'Status layanan',
			'tools.statusDesc' => 'Aplikasi bisa diakses atau diblokir di sini?',
			'tools.trace' => 'Traceroute',
			'tools.traceDesc' => 'Setiap persinggahan menuju situs',
			'tools.security' => 'Jaringan ini',
			'tools.devices' => 'Perangkat di jaringan ini',
			'tools.devicesDesc' => 'Siapa saja di Wi-Fi Anda',
			'tools.router' => 'Periksa router',
			'tools.routerDesc' => 'Port yang dibuka perangkat Anda',
			'tools.ports' => 'Port terbuka',
			'tools.portsDesc' => 'Port berisiko di perangkat atau server',
			'tools.utilities' => 'Utilitas',
			'tools.wifiScanner' => 'Pemindai Wi-Fi',
			'tools.wifiDesc' => 'Jaringan di sekitar dan kanal paling sepi',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Nyalakan komputer di jaringan ini',
			'tools.passwordCheck' => 'Cek kata sandi',
			'tools.passwordCheckDesc' => 'Pernah bocor?',
			'tools.linkCheck' => 'Cek tautan',
			_ => null,
		} ?? switch (path) {
			'tools.linkCheckDesc' => 'Aman dibuka?',
			'tools.breaches' => 'Kebocoran data',
			'tools.breachesDesc' => 'Apa yang bocor belakangan ini',
			'tools.blocked' => 'Apa yang diblokir',
			'tools.blockedDesc' => 'Situs yang diblokir di jaringan ini',
			'trace.info' => 'Setiap perhentian adalah satu router yang dilewati lalu lintas Anda menuju situs.\n\nHop diam: banyak router tidak pernah menjawab uji ini. Itu normal dan bukan kesalahan.\n\nDengan VPN aktif: jalurnya dimulai di dalam terowongan, jadi jaringan dan penyedia Anda tersembunyi.\n\nCara: memakai alat ping bawaan Android dengan batas hop, karena aplikasi tidak dapat mengirim paket ini secara langsung.',
			'trace.title' => 'Traceroute',
			'trace.stop' => 'Hentikan',
			'trace.trace' => 'Lacak',
			'trace.again' => 'Lacak lagi',
			'trace.destination' => 'Tujuan',
			'trace.hops' => 'HOP',
			'trace.answered' => 'MENJAWAB',
			'trace.total' => 'TOTAL',
			'trace.thisPhone' => 'Ponsel ini',
			'trace.silentOne' => '1 hop diam',
			'trace.yourRouter' => 'Router Anda',
			'trace.ms' => ({required Object n}) => '${n} md',
			'trace.silentMany' => ({required Object n}) => '${n} hop diam',
			'trace.hop' => ({required Object n}) => 'Hop ${n}',
			'trace.slowest' => ({required Object ms, required Object hop}) => 'Sebagian besar jeda, ${ms} md, ditambahkan di hop ${hop}: biasanya kabel panjang antarnegara, atau jalur yang padat.',
			'trace.popular' => 'POPULER',
			'trace.recent' => 'TERBARU',
			'trace.clearRecent' => 'Hapus terbaru',
			'trace.hopsCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} lompatan', ), 
			'ports.ftpNote' => 'Mengirim kata sandi tanpa enkripsi.',
			'ports.sshNote' => 'Login jarak jauh. Aman jika Anda yang menyiapkannya.',
			'ports.telnetNote' => 'Login jarak jauh tanpa enkripsi; favorit botnet.',
			'ports.dnsNote' => 'Normal di router.',
			'ports.web' => 'Web (HTTP)',
			'ports.webNote' => 'Biasanya halaman admin router.',
			'ports.webTls' => 'Web (HTTPS)',
			'ports.smb' => 'Berbagi file Windows',
			'ports.smbNote' => 'Tidak boleh terbuka ke internet.',
			'ports.rtsp' => 'Siaran kamera RTSP',
			'ports.rtspNote' => 'Mungkin ada kamera yang menyiarkan di sini.',
			'ports.upnpNote' => 'Memungkinkan perangkat membuka port router sendiri.',
			'ports.rdp' => 'Remote Desktop',
			'ports.rdpNote' => 'Jalur pembobolan yang umum.',
			'ports.vncNote' => 'Berbagi layar, sering tanpa kata sandi.',
			'ports.tr069Note' => 'Pengelolaan jarak jauh oleh ISP.',
			'ports.webAlt' => 'Web (alternatif)',
			'ports.webAltTls' => 'Web (HTTPS alternatif)',
			'ports.title' => 'Port terbuka',
			'ports.check' => 'Periksa port',
			'ports.address' => 'Alamat perangkat atau server',
			'ports.risky' => 'BERISIKO',
			'ports.review' => 'TINJAU',
			'ports.normal' => 'NORMAL',
			'ports.info' => ({required Object n}) => 'Memeriksa ${n} port yang penting di router dan perangkat rumah, dan menjelaskan setiap port yang terbuka.\n\nHanya periksa perangkat dan server yang Anda miliki atau kelola.',
			'ports.checking' => ({required Object n}) => 'Memeriksa ${n} port',
			'ports.yourRouter' => ({required Object ip}) => 'Router Anda adalah ${ip}',
			'ports.noneOpen' => ({required Object host}) => 'Tidak ada port umum yang terbuka di ${host}.',
			'ports.summary' => ({required Object open, required Object n}) => '${open} terbuka dari ${n} dicek',
			'ports.riskyCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} berisiko', ), 
			'ports.noneRisky' => 'Tidak ada yang berisiko',
			'wifi.title' => 'Pemindai Wi-Fi',
			'wifi.allow' => 'Izinkan pemindaian Wi-Fi',
			'wifi.needsPermission' => 'Memerlukan izin lokasi.',
			'wifi.scanning' => 'Memindai',
			'wifi.again' => 'Pindai lagi',
			'wifi.failed' => 'Pemindaian gagal',
			'wifi.none' => 'Tidak ada jaringan ditemukan. Lokasi mungkin mati.',
			'wifi.hidden' => 'Jaringan tersembunyi',
			'wifi.nearby' => ({required Object n}) => '${n} jaringan di sekitar',
			'wifi.permissionInfo' => 'Android hanya menampilkan jaringan Wi-Fi di sekitar kepada aplikasi yang memiliki izin lokasi. G VPN memakainya hanya untuk menampilkan jaringan di ponsel ini.',
			'wifi.info' => 'Menampilkan jaringan dari pemindaian terakhir ponsel. Android hanya mengizinkan beberapa pemindaian per menit, jadi pemindaian ulang yang cepat bisa menampilkan daftar yang sama. Kanal yang disarankan adalah yang paling sepi di antara 1, 6, dan 11, tiga kanal yang tidak tumpang tindih.',
			'wifi.airMap' => 'Peta udara',
			'wifi.channels' => 'Kanal',
			'wifi.list' => 'Daftar',
			'wifi.secure' => 'Aman',
			'wifi.weakLabel' => 'Lemah',
			'wifi.openLabel' => 'Terbuka',
			'wifi.sizeIsWidth' => 'Ukuran = lebar kanal',
			'wifi.strongest' => 'TERKUAT',
			'wifi.openNearby' => 'TERBUKA DI SEKITAR',
			'wifi.onYourChannel' => 'DI KANAL ANDA',
			'wifi.noneNearby' => 'Tidak ada',
			'wifi.verdictOpen' => 'Siapa pun di sekitar bisa membaca yang dikirim',
			'wifi.verdictWep' => 'Keamanan lama, mudah dibobol',
			'wifi.verdictWpa' => 'Keamanan lama',
			'wifi.verdictWps' => 'WPS aktif: lebih mudah dibobol',
			'wifi.verdictGood' => 'Terlindungi baik',
			'wifi.maker' => 'Pembuat',
			'wifi.address' => 'Alamat perangkat keras',
			'wifi.privateAddress' => 'Dibuat router demi privasi',
			'wifi.you' => 'Anda',
			'wifi.onClear' => ({required Object name}) => '${name} ada di kanal yang sepi',
			'wifi.move' => ({required Object name, required Object n}) => 'Pindahkan ${name} ke kanal ${n}',
			'wifi.clear' => 'Sepi',
			'wifi.busy' => 'Sibuk',
			'wifi.crowded' => 'Padat',
			'wifi.allBands' => 'Semua pita',
			'wifi.openOnly' => 'Hanya terbuka',
			'wifi.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} jaringan', ), 
			'errors.notAuthorized' => 'Izin VPN tidak diberikan.',
			'errors.turnedOff' => 'VPN dimatikan oleh sistem atau aplikasi lain.',
			'errors.busy' => 'Permintaan izin sudah terbuka.',
			'errors.cancelled' => 'Koneksi dibatalkan.',
			'errors.badConfig' => ({required Object error}) => 'Konfigurasi server ini tidak valid: ${error}',
			'errors.timeout' => 'Server tidak menjawab.',
			'errors.refused' => 'Server menolak koneksi.',
			'errors.failed' => ({required Object error}) => 'Tidak dapat terhubung: ${error}',
			'errors.tryAnother' => 'Server gratis datang dan pergi; coba server lain.',
			'errors.downloadFailed' => 'Tidak dapat mengunduh setelan server ini. Periksa koneksi Anda, atau pilih server lain.',
			'scan.mobile' => 'Data seluler',
			'scan.ping' => 'PING',
			'scan.noReply' => 'Tidak ada jawaban',
			'scan.dns' => 'DNS',
			'scan.dnsQuad9' => 'Quad9, terowongan',
			'scan.dnsTunnel' => 'Di dalam terowongan',
			'scan.privateDns' => 'DNS Pribadi',
			'scan.dnsIsp' => 'ISP, terlihat',
			'scan.network' => 'JARINGAN',
			'scan.offline' => 'Offline',
			'scan.open' => 'Terbuka, tanpa sandi',
			'scan.wep' => 'WEP, tidak aman',
			'scan.owe' => 'Terbuka, terenkripsi',
			'scan.enterprise' => 'Perusahaan',
			'scan.unknown' => 'Tidak diketahui',
			'scan.wifi' => 'WI-FI',
			'scan.signIn' => 'Halaman masuk',
			'scan.ms' => ({required Object n}) => '${n} md',
			'scan.covered' => ({required Object what}) => '${what}, terlindungi',
			'legal.privacy' => 'Kebijakan privasi',
			'legal.terms' => 'Ketentuan penggunaan',
			'legal.licences' => 'Lisensi sumber terbuka',
			'update.ready' => 'Pembaruan siap',
			'update.restart' => 'Mulai ulang',
			'details.share' => 'Bagikan',
			'details.connectedFor' => ({required Object n}) => 'TERHUBUNG · ${n} MNT',
			'details.notConnected' => 'TIDAK TERHUBUNG',
			'details.downloaded' => 'DIUNDUH',
			'details.uploaded' => 'DIUNGGAH',
			'details.lastUsed' => 'TERAKHIR DIPAKAI',
			'details.connection' => 'Koneksi',
			'details.protocol' => 'Protokol',
			'details.address' => 'Alamat Anda',
			'details.dns' => 'DNS',
			'details.routes' => 'Rute',
			'details.allTraffic' => 'Semua lalu lintas',
			'details.someRoutes' => ({required Object n}) => '${n} jaringan',
			'details.keepalive' => 'Keepalive',
			'details.serverKey' => 'Kunci server',
			'details.copy' => 'Salin',
			'details.copied' => 'Disalin',
			'details.manage' => 'Kelola',
			'details.export' => 'Ekspor untuk cadangan',
			'details.exportSub' => 'Semua server Anda dalam satu file',
			'share.title' => ({required Object name}) => 'Bagikan ${name}',
			'share.sameKey' => 'Ini membagikan kunci ponsel ini. Siapa pun yang memilikinya dapat memakai server Anda sebagai Anda, dan hanya satu perangkat yang bisa terhubung dengannya pada satu waktu.',
			'share.scanHint' => 'Di ponsel lain: G VPN, Server, Pindai QR. Gambar yang disimpan juga bisa.',
			'share.saveImage' => 'Simpan gambar',
			'share.send' => 'Kirim',
			'add.title' => 'Tambah server',
			'add.subtitle' => 'Server WireGuard apa pun: router, VPS, atau server rumah.',
			'add.camera' => 'Pindai dengan kamera',
			'add.cameraSub' => 'QR di layar lain',
			'add.image' => 'Dari gambar',
			'add.imageSub' => 'Tangkapan layar atau foto tersimpan',
			'add.noQr' => 'Tidak ada kode QR di gambar itu.',
			'add.tip' => 'Dapat QR di WhatsApp atau Telegram? Ketuk Bagikan pada gambar dan pilih G VPN.',
			'backup.restored' => ({required Object n}) => '${n} server dipulihkan',
			'backup.nothingNew' => 'Server ini sudah ada',
			'gs.proRequired' => 'G Servers khusus pelanggan G VPN Pro.',
			'gs.off' => 'G Servers sedang dimatikan.',
			'gs.network' => 'Tidak dapat menjangkau G Servers. Periksa koneksi Anda dan coba lagi.',
			'gs.active' => 'AKTIF',
			'gs.servers' => 'G Servers',
			'gs.busy' => ({required Object n}) => '${n}% sibuk',
			'gs.offline' => 'Offline',
			'gs.devices' => 'Perangkat Anda',
			'gs.subtitle' => ({required Object country}) => 'G Server · ${country} · WireGuard',
			'gs.busyLabel' => 'SIBUK',
			'gs.status' => 'STATUS',
			'gs.online' => 'Online',
			'gs.onThisServer' => 'Di server ini',
			'gs.thisPhone' => 'Ponsel ini',
			'gs.added' => 'Ditambahkan · kunci dibuat di sini',
			'gs.notAdded' => 'Ditambahkan saat Anda terhubung',
			'gs.logs' => 'Log aktivitas',
			'gs.noneKept' => 'Tidak disimpan',
			'gs.privacy' => 'Server hanya mengenal ponsel ini dari kunci publiknya. Server tidak mencatat situs yang Anda kunjungi atau lalu lintas yang Anda kirim.',
			'gs.stepPro1' => 'Pasang G VPN di ponsel, masuk dengan akun Google yang sama.',
			'gs.stepPro2' => 'Buka tab Pro. Pro terbuka otomatis, atau ketuk Pulihkan.',
			'gs.step3' => 'Ketuk Hubungkan. Ponsel membuat kuncinya dan ditambahkan ke G Servers. Tanpa QR, tanpa kode.',
			'gs.stepFree1' => 'Pasang G VPN di ponsel.',
			'gs.stepFree2' => 'Buka tab Pro.',
			'gs.devicesIntroPro' => 'Pro mengikuti akun Google Anda. Setiap ponsel punya kuncinya sendiri, jadi tidak saling memutuskan.',
			'gs.devicesIntroFree' => 'Setiap ponsel punya kuncinya sendiri, jadi tidak saling memutuskan.',
			'gs.otherPhone' => 'Ponsel lain',
			'gs.lastConnected' => ({required Object when}) => 'Terakhir terhubung ${when}',
			'gs.noDevices' => 'Hubungkan ke G Server sekali dan ponsel Anda muncul di sini.',
			'gs.addTitle' => 'Tambah ponsel atau pasang ulang',
			'gs.idle' => ({required Object n}) => 'Ponsel yang tidak terhubung selama ${n} hari dihapus otomatis dari G Servers, jadi ponsel lama atau yang dipasang ulang tidak memakan tempat.',
			'gs.limitNote' => ({required Object n}) => 'Hingga ${n} ponsel per paket.',
			'gs.fullTitle' => ({required Object n}) => 'Ke-${n} tempat sudah terpakai',
			'gs.fullBody' => 'Hapus ponsel yang tidak lagi Anda pakai, dan ponsel ini langsung terhubung.',
			'gs.busyNow' => 'Terlalu banyak ponsel baru saat ini. Coba lagi sebentar lagi.',
			'gs.serverFull' => 'Server ini penuh. Coba G Server lain.',
			'gs.ping' => 'PING',
			'gs.last24' => 'Kesibukan, 24 jam terakhir',
			'gs.noHistory' => 'Grafik terisi seiring server dipakai sepanjang hari.',
			'gs.chartLabel' => ({required Object max}) => 'Kesibukan 24 jam terakhir, paling tinggi ${max} persen',
			'gs.hoursAgo' => '24 jam lalu',
			'gs.now' => 'Sekarang',
			'gs.included' => 'Termasuk',
			'gs.perkServers' => 'Server cepat dan privat',
			'gs.perkServersSub' => 'WireGuard, dikelola kami, tanpa log aktivitas',
			'gs.perkLinks' => 'Cek tautan tanpa batas',
			'gs.perkLinksSub' => 'Cek setiap tautan yang Anda terima',
			'gs.devicesOf' => ({required Object used, required Object limit}) => 'Perangkat Anda · ${used} dari ${limit}',
			'gs.eachKey' => 'Setiap ponsel punya kuncinya sendiri',
			'gs.connected' => 'Tersambung',
			'gs.bestNow' => 'TERBAIK UNTUK ANDA SEKARANG',
			'gs.logsShort' => 'LOG',
			'map.open' => 'Buka peta',
			'map.searchCountries' => 'Cari negara',
			'map.noMatch' => 'Tidak ada negara yang cocok',
			'map.locate' => 'Lokasi saya',
			'map.list' => 'Daftar',
			'map.map' => 'Peta',
			'map.freeServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} server gratis', ), 
			'map.grade.fast' => 'Cepat',
			'map.grade.good' => 'Baik',
			'map.grade.slow' => 'Lambat',
			'map.switchTo' => 'Ganti',
			'map.freeServer' => ({required Object n}) => 'Server gratis ${n}',
			'map.best' => 'TERBAIK',
			'map.gServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} G Server', ), 
			'stats.thisWeek' => 'Minggu ini',
			'stats.time' => 'Waktu',
			'stats.data' => 'Data',
			'stats.protected' => 'terlindungi',
			'stats.throughVpn' => 'lewat VPN',
			'stats.seeDetails' => 'Lihat detail',
			'stats.title' => 'Statistik',
			'stats.week' => 'Minggu',
			'stats.month' => 'Bulan',
			'stats.protectedLabel' => 'TERLINDUNGI',
			'stats.dataUsed' => 'DATA TERPAKAI',
			'stats.byServer' => 'PER SERVER',
			'stats.onPhone' => 'Hanya di ponsel ini',
			'stats.reset' => 'Atur ulang',
			'stats.resetTitle' => 'Atur ulang statistik?',
			'stats.resetBody' => 'Menghapus waktu terlindungi dan data di ponsel ini. Tidak bisa dibatalkan.',
			'stats.hm' => ({required Object h, required Object m}) => '${h} j ${m} m',
			'stats.m' => ({required Object m}) => '${m} m',
			'stats.empty' => 'Hubungkan untuk mulai menghitung.',
			'recents.title' => 'Terbaru',
			'recents.allServers' => 'Semua server',
			'recents.free' => 'Server gratis',
			'recents.yours' => 'Server Anda',
			'recents.gserver' => 'G Server',
			'presets.title' => 'Preset',
			'presets.all' => 'Semua',
			'presets.newPreset' => 'Preset baru',
			'presets.edit' => 'Ubah preset',
			'presets.name' => 'Nama',
			'presets.namePlaceholder' => 'Preset saya',
			'presets.server' => 'SERVER',
			'presets.fastestOption' => 'Tercepat',
			'presets.countryOption' => 'Negara',
			'presets.pickCountry' => 'Pilih negara',
			'presets.skipMyCountry' => 'Lewati negara saya',
			'presets.notMine' => 'bukan negara saya',
			'presets.protocol' => 'PROTOKOL',
			'presets.auto' => 'Otomatis',
			'presets.tryNext' => 'Jika diblokir, coba server berikutnya',
			'presets.shield' => 'PERISAI',
			'presets.followRules' => 'Sesuai Aturan',
			'presets.allApps' => 'Semua aplikasi lewat VPN',
			'presets.allAppsShort' => 'semua aplikasi',
			'presets.save' => 'Simpan',
			'presets.delete' => 'Hapus',
			'presets.reset' => 'Kembalikan bawaan',
			'presets.none' => 'Belum ada server gratis yang cocok untuk preset ini.',
			'presets.names.fastest' => 'Tercepat',
			'presets.names.unblock' => 'Buka blokir',
			'presets.names.streaming' => 'Streaming',
			'presets.names.privacy' => 'Privasi maksimal',
			'shield.title' => 'Perisai',
			'shield.sub' => 'Bekerja saat Anda terhubung',
			'shield.off' => 'Mati',
			'shield.offSub' => 'DNS milik server',
			'shield.malware' => 'Malware',
			'shield.malwareSub' => 'Memblokir situs berbahaya dan phishing',
			'shield.family' => 'Malware dan situs dewasa',
			'shield.familySub' => 'Juga memblokir konten dewasa',
			'shield.custom' => 'DNS sendiri',
			'shield.customSub' => 'Server DNS Anda sendiri',
			'shield.customHint' => 'Alamat IP, misalnya 1.1.1.1',
			'shield.invalid' => 'Masukkan satu atau dua alamat IP.',
			'checks.title' => 'Pemeriksaan keamanan',
			'checks.password' => 'Kata sandi',
			'checks.link' => 'Tautan',
			'checks.pwTitle' => 'Pernah bocor?',
			'checks.pwHint' => 'Kata sandi yang dicek',
			'checks.showPassword' => 'Tampilkan kata sandi',
			'checks.hidePassword' => 'Sembunyikan kata sandi',
			'checks.check' => 'Cek',
			'checks.leaked' => 'Ditemukan di kebocoran',
			'checks.seen' => ({required Object n}) => 'Terlihat ${n} kali',
			'checks.leakedAdvice' => 'Ganti di semua tempat Anda memakainya, mulai dari email dan bank.',
			'checks.notFound' => 'Tidak ada di kebocoran yang diketahui',
			'checks.notFoundAdvice' => 'Pertanda baik, bukan jaminan. Pakai kata sandi berbeda untuk tiap akun.',
			'checks.failed' => 'Gagal mengecek. Coba lagi.',
			'checks.private' => 'Kata sandi Anda tidak pernah keluar dari ponsel ini',
			'checks.linkTitle' => 'Amankah tautan ini?',
			'checks.linkHint' => 'Tautan yang dicek',
			'checks.paste' => 'Tempel',
			'checks.danger' => 'Tautan berbahaya',
			'checks.dangerAdvice' => 'Jangan dibuka dan jangan isi data apa pun.',
			'checks.clear' => 'Tidak ada di daftar malware atau phishing yang dikenal',
			'checks.clearAdvice' => 'Tetap periksa alamatnya sebelum masuk ke mana pun.',
			'checks.goesTo' => 'Menuju ke',
			'checks.redirects' => 'Pengalihan',
			'checks.invalid' => 'Itu tidak tampak seperti alamat web.',
			'checks.busy' => 'Terlalu banyak pengecekan. Coba lagi nanti.',
			'checks.unavailable' => 'Cek tautan sedang tidak tersedia.',
			'checks.listed' => 'Dikenal sebagai malware atau phishing',
			'checks.missing' => 'Tidak ada situs di alamat ini',
			'checks.missingAdvice' => 'Periksa ejaannya: penipuan sering memakai alamat yang mirip.',
			'checks.left' => ({required Object n, required Object total}) => 'Sisa ${n} dari ${total} cek gratis bulan ini',
			'checks.usedUp' => 'Cek tautan gratis bulan ini sudah habis',
			'checks.usedUpSub' => 'Pro punya cek tanpa batas. Cek gratis kembali setiap tanggal 1.',
			'checks.getPro' => 'Dapatkan Pro',
			'toolSettings.title' => 'Pengaturan alat',
			'toolSettings.askMobile' => 'Tanya sebelum tes kecepatan di data seluler',
			'toolSettings.askMobileSub' => 'Satu tes bisa memakai lebih dari 100 MB di koneksi cepat',
			'toolSettings.mobileTitle' => 'Pakai data seluler?',
			'toolSettings.mobileBody' => 'Tes kecepatan bisa memakai lebih dari 100 MB di koneksi cepat.',
			'toolSettings.mobileGo' => 'Tes',
			'toolSettings.safe' => 'Aman',
			'toolSettings.unsafe' => 'Tidak aman',
			'toolSettings.devices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} perangkat', ), 
			'toolSettings.hideMac' => 'Sembunyikan alamat perangkat keras',
			'toolSettings.hideMacSub' => 'Hanya tampilkan bagian pembuat dari alamat MAC',
			'toolSettings.names' => 'Tampilkan nama router dan server',
			'toolSettings.namesSub' => 'Mencari nama alamat di Traceroute',
			'toolSettings.remember' => 'Ingat host terbaru',
			'toolSettings.rememberSub' => 'Untuk Traceroute',
			'toolSettings.clear' => 'Hapus riwayat alat',
			'toolSettings.clearSub' => 'Melupakan host terbaru dan perangkat di tiap jaringan',
			'toolSettings.clearGo' => 'Hapus',
			'security.tab' => 'Keamanan',
			'security.good' => 'Baik',
			'security.fair' => 'Cukup',
			'security.atRisk' => 'Berisiko',
			'security.allClear' => 'Tidak ada yang perlu diperbaiki',
			'security.checked' => ({required Object time}) => 'Dicek pukul ${time}',
			'security.trend' => 'DUA MINGGU TERAKHIR',
			'security.checking' => 'Memeriksa jaringan ini',
			'security.snoozed' => 'Ditunda',
			'security.remindLater' => 'Ingatkan nanti',
			'security.unsnooze' => 'Ingatkan sekarang',
			'security.review' => 'Tinjau',
			'security.confirmGo' => 'Konfirmasi',
			'security.scanGo' => 'Pindai',
			'security.look' => 'Lihat',
			'security.connectGo' => 'Hubungkan',
			'security.checkAgain' => 'Cek lagi',
			'security.wifiOpen' => 'Wi-Fi terbuka',
			'security.wifiOpenDetail' => 'Siapa pun di sekitar bisa melihat yang dikirim',
			'security.wifiWep' => 'Wi-Fi memakai WEP',
			'security.wifiWepDetail' => 'Keamanan lama, mudah dibobol',
			'security.wifiOwe' => 'Wi-Fi memakai Enhanced Open',
			'security.wifiOweDetail' => 'Terenkripsi, tapi siapa pun bisa masuk',
			'security.wifiSecure' => 'Enkripsi Wi-Fi',
			'security.wifiUnknown' => 'Keamanan Wi-Fi tidak diketahui',
			'security.wifiUnknownDetail' => 'Android tidak menyebut perlindungannya',
			'security.wps' => 'WPS aktif',
			'security.wpsDetail' => 'Matikan di pengaturan router',
			'security.upnpOff' => 'Router menjaga port tetap tertutup',
			'security.upnpOffDetail' => 'UPnP mati',
			'security.upnpOn' => 'Router membiarkan perangkat membuka port',
			'security.upnpOnDetail' => 'UPnP aktif',
			'security.portsOk' => 'Tidak ada port berisiko di router',
			'security.portsRisky' => 'Port berisiko terbuka di router',
			'security.scanFirst' => 'Pindai untuk melihat siapa di sini',
			'security.scanFirstDetail' => 'Perangkat tak dikenal mengurangi skor',
			'security.notMineDetail' => 'Periksa daftar perangkat di router',
			'security.confirmDetail' => 'Tandai yang milik Anda',
			'security.devicesOk' => 'Semua perangkat dikenal',
			'security.devicesOkDetail' => 'Anda sudah mengonfirmasi semuanya',
			'security.camera' => 'Ada kamera di jaringan ini',
			'security.dnsHijack' => 'Nama tak dikenal dialihkan',
			'security.dnsHijackDetail' => 'Penyedia atau router Anda mengubah pencarian',
			'security.dnsOk' => 'DNS menjawab normal',
			'security.dnsOkDetail' => 'Tidak ada tanda pengalihan',
			'security.vpnOn' => 'VPN aktif',
			'security.vpnOnDetail' => 'Lalu lintas keluar lewat terowongan',
			'security.vpnOff' => 'VPN mati',
			'security.vpnOffDetail' => 'Penyedia Anda melihat setiap situs',
			'security.toFix' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} hal perlu diperbaiki', ), 
			'security.upnpOpened' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} port dibuka perangkat', ), 
			'security.portsChecked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} port dicek', ), 
			'security.notMine' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} perangkat bukan milik Anda', ), 
			'security.confirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} perangkat perlu dikonfirmasi', ), 
			'providers.tab' => 'Internet',
			'providers.unavailable' => 'Tidak bisa memuat daftar penyedia. Periksa koneksi Anda.',
			'providers.cached' => 'Menurut pengecekan terakhir tanpa VPN',
			'providers.notEnough' => 'Belum cukup penilaian',
			'providers.yourRating' => 'Penilaian Anda bulan ini',
			'providers.yourSpeed' => 'KECEPATAN ANDA',
			'providers.runTest' => 'Jalankan tes kecepatan',
			'providers.aboutAverage' => 'Setara rata-rata di sini',
			'providers.aboveAverage' => ({required Object pct}) => '${pct}% di atas rata-rata lokal',
			'providers.belowAverage' => ({required Object pct}) => '${pct}% di bawah rata-rata lokal',
			'providers.call' => 'Telepon',
			'providers.website' => 'Situs web',
			'providers.outages' => 'Gangguan',
			'providers.rate' => 'Nilai',
			'providers.changeRating' => 'Ubah penilaian',
			'providers.compare' => 'Bandingkan',
			'providers.rateTitle' => ({required Object name}) => 'Nilai ${name}',
			'providers.oncePerMonth' => 'Satu penilaian sebulan',
			'providers.tapStars' => 'Ketuk bintangnya',
			'providers.verified' => ({required Object mbps}) => 'Terverifikasi oleh tes Anda: ${mbps} Mbps',
			'providers.busy' => 'Terlalu banyak penilaian dari sini. Coba nanti.',
			'providers.failed' => 'Gagal mengirim. Coba lagi.',
			'providers.post' => 'Kirim penilaian',
			'providers.nearTitle' => 'Penyedia di sekitar Anda',
			'providers.slower' => ({required Object pct}) => 'Unduhan Anda ${pct}% di bawah rata-rata penyedia Anda di sini',
			'providers.inPlace' => ({required Object place}) => 'Internet rumah di ${place}',
			'providers.byRating' => 'Penilaian',
			'providers.bySpeed' => 'Kecepatan',
			'providers.footnote' => 'Kecepatan adalah rata-rata tes G VPN',
			'providers.noneNearby' => 'Belum ada penilaian di sekitar. Jadilah yang pertama.',
			'providers.you' => 'Anda',
			'providers.topRated' => 'Nilai tertinggi',
			'providers.starsOf' => ({required Object n}) => '${n} dari 5',
			'providers.tags.fast' => 'Cepat',
			'providers.tags.reliable' => 'Andal',
			'providers.tags.support' => 'Dukungan baik',
			'providers.tags.price' => 'Harga wajar',
			'providers.tags.slowEvenings' => 'Lambat malam hari',
			'providers.tags.drops' => 'Sering putus',
			'providers.tags.poorSupport' => 'Dukungan buruk',
			'providers.tags.pricey' => 'Mahal',
			'providers.words.bad' => 'Buruk',
			'providers.words.poor' => 'Kurang',
			'providers.words.okay' => 'Lumayan',
			'providers.words.good' => 'Bagus',
			'providers.words.great' => 'Hebat',
			'providers.ratings' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} penilaian', ), 
			'alerts.channel' => 'Peringatan',
			'alerts.title' => 'Peringatan',
			'alerts.markAllRead' => 'Tandai semua dibaca',
			'alerts.clearAll' => 'Hapus semua',
			'alerts.thisNetwork' => 'jaringan ini',
			'alerts.openWifiTitle' => ({required Object name}) => 'Anda tersambung ke Wi-Fi terbuka: ${name}',
			'alerts.openWifiBody' => 'Siapa pun di sekitar bisa melihat yang dikirim. Nyalakan G VPN.',
			'alerts.reportTitle' => 'Laporan mingguan Anda siap',
			'alerts.reportBody' => ({required Object hours}) => '${hours} jam terlindungi minggu lalu',
			'alerts.blockedTitle' => ({required Object name}) => '${name} diblokir di sini',
			'alerts.blockedBody' => 'Bisa diakses lewat VPN',
			'alerts.kinds.newDevice' => 'Perangkat baru di Wi-Fi saya',
			'alerts.kinds.openWifi' => 'Wi-Fi terbuka atau lemah',
			'alerts.kinds.blocked' => 'Aplikasi diblokir',
			'alerts.kinds.report' => 'Laporan mingguan',
			'alerts.kinds.breach' => 'Kebocoran',
			'alerts.newDeviceTitle' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} perangkat baru di ${network}', ), 
			'alerts.settings' => 'Pengaturan peringatan',
			'alerts.look' => 'Lihat',
			'alerts.read' => 'Baca',
			'alerts.open' => 'Buka',
			'alerts.check' => 'Cek',
			'alerts.today' => 'HARI INI',
			'alerts.thisWeek' => 'MINGGU INI',
			'alerts.earlier' => 'SEBELUMNYA',
			'alerts.all' => 'Semua',
			'alerts.quiet' => 'Semua tenang',
			'alerts.quietSub' => 'Tidak ada yang perlu Anda tangani',
			'alerts.breachTitle' => ({required Object name}) => 'Kebocoran baru: ${name}',
			'alerts.status.background' => 'Setiap beberapa jam',
			'alerts.status.checked' => ({required Object time}) => 'Dicek pukul ${time}',
			'alerts.status.wifi' => 'Setiap jaringan yang Anda masuki',
			'alerts.status.blocked' => 'Saat status layanan dicek',
			'alerts.status.report' => 'Setiap Senin',
			'report.title' => 'Laporan mingguan',
			'report.share' => 'Bagikan sebagai gambar',
			'report.shareText' => 'Minggu saya dengan G VPN',
			'report.safer' => 'Minggu yang lebih aman',
			'report.moreProtected' => 'Lebih terlindungi dari minggu lalu',
			'report.yourWeek' => 'Minggu Anda',
			'report.soFar' => ({required Object range}) => '${range}, sejauh ini',
			'report.protected' => 'Terlindungi',
			'report.data' => 'Data',
			'report.security' => 'Keamanan',
			'report.speed' => 'Kecepatan terbaik',
			'report.noScore' => 'Belum dicek',
			'report.noTest' => 'Belum ada tes',
			'report.bestDirect' => 'Tes langsung',
			'report.moreThan' => ({required Object d}) => '${d} lebih lama dari minggu lalu',
			'report.lessThan' => ({required Object d}) => '${d} lebih singkat dari minggu lalu',
			'report.protectedTime' => 'WAKTU TERLINDUNGI',
			'report.mostUsed' => ({required Object name}) => 'Paling sering: ${name}',
			'report.quiet' => 'Minggu yang tenang: tidak ada yang perlu Anda tangani',
			'report.newDevices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} perangkat baru bergabung', ), 
			'report.openWifi' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: 'Bergabung ke ${n} Wi-Fi terbuka', ), 
			'report.blocked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} aplikasi diblokir', ), 
			'report.breaches' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} kebocoran besar baru', ), 
			'breaches.title' => 'Kebocoran data',
			'breaches.info' => 'Kebocoran data terbaru, dari daftar publik Have I Been Pwned. Tidak ada data Anda yang dikirim: daftarnya sama untuk semua orang.\n\nJika Anda punya akun di situs yang bocor, ganti kata sandinya, juga di tempat lain yang memakai sandi sama.',
			'breaches.unavailable' => 'Gagal memuat daftar. Periksa koneksi Anda.',
			'breaches.biggest' => 'TERBESAR BULAN INI',
			'breaches.newest' => 'Terbaru',
			'breaches.biggestSort' => 'Terbesar',
			'breaches.withPasswords' => 'Dengan kata sandi',
			'breaches.passwordsMark' => 'KATA SANDI',
			'breaches.one' => 'Kebocoran',
			_ => null,
		} ?? switch (path) {
			'breaches.checkPassword' => 'Cek kata sandi',
			'breaches.verified' => 'Terverifikasi',
			'breaches.hasPasswords' => 'Ada kata sandi',
			'breaches.accountsLabel' => 'Akun',
			'breaches.happened' => 'Terjadi',
			'breaches.published' => 'Dipublikasikan',
			'breaches.website' => 'Situs web',
			'breaches.leaked' => 'YANG BOCOR',
			'breaches.ifUsed' => 'JIKA ANDA MEMAKAINYA',
			'breaches.stepPassword' => 'Ganti kata sandi yang Anda pakai di sana',
			'breaches.stepReuse' => 'Ganti juga di tempat lain yang memakai sandi sama',
			'breaches.stepTwoStep' => 'Aktifkan verifikasi dua langkah jika bisa',
			'breaches.stepScams' => 'Waspadai telepon dan pesan penipuan',
			'breaches.accounts' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${count} akun', ), 
			'breaches.worldwide' => ({required Object n}) => 'Global · ${n}',
			'breaches.noneHere' => 'Tidak ada kebocoran dari sini di daftar terbaru.',
			'breaches.bigMap' => 'Peta lebih besar',
			'breaches.showInList' => 'Tampilkan di daftar',
			'breaches.mapTitle' => 'Peta kebocoran',
			'breaches.zoomIn' => 'Perbesar',
			'breaches.zoomOut' => 'Perkecil',
			'breaches.wholeWorld' => 'Seluruh dunia',
			'breaches.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} kebocoran', ), 
			'breaches.findCountry' => 'Cari negara',
			'breaches.seeAll' => 'Lihat semua',
			'breaches.search' => 'Cari kebocoran',
			'blocked.title' => 'Apa yang diblokir',
			'blocked.info' => 'Menguji situs terkenal dari ponsel ini, tanpa VPN, dan menunjukkan mana yang diblokir jaringan ini serta caranya.\n\nAlamat palsu: pencarian nama jaringan memberi jawaban palsu.\n\nDiputus: koneksi diputus saat dimulai.\n\nTidak ada jawaban: tidak ada yang kembali.\n\nHalaman blokir: hal lain menjawab menggantikan situs.\n\nTes menunjukkan di mana situs diblokir, bukan siapa yang memblokir. Tidak ada yang disimpan atau dikirim.',
			'blocked.thisNetwork' => 'Jaringan ini',
			'blocked.country' => 'Negara Anda',
			'blocked.question' => 'Apa yang diblokir di sini?',
			'blocked.testingOn' => 'MENGUJI DI',
			'blocked.vpnOn' => 'VPN AKTIF',
			'blocked.turnOff' => 'Matikan G VPN untuk menguji',
			'blocked.test' => 'Uji jaringan ini',
			'blocked.stop' => 'Berhenti',
			'blocked.sitesToTest' => ({required Object n}) => 'SITUS YANG DIUJI · ${n}',
			'blocked.ofSites' => ({required Object n}) => 'dari ${n} situs',
			'blocked.blockedCount' => ({required Object n}) => '${n} DIBLOKIR',
			'blocked.openCount' => ({required Object n}) => '${n} TERBUKA',
			'blocked.noneBlocked' => ({required Object network}) => 'Tidak ada yang diblokir di ${network}',
			'blocked.openOf' => ({required Object open, required Object total}) => '${open} dari ${total} terbuka',
			'blocked.allWork' => 'SEMUA BISA DENGAN G VPN',
			'blocked.blockedHeading' => 'DIBLOKIR',
			'blocked.byKind' => 'MENURUT JENIS',
			'blocked.worksVpn' => 'Bisa dengan VPN',
			'blocked.failsVpn' => 'Tetap diblokir lewat VPN',
			'blocked.checkVpn' => 'Cek lewat G VPN',
			'blocked.connect' => 'Sambungkan G VPN',
			'blocked.again' => 'Uji lagi',
			'blocked.withoutVpn' => 'TANPA VPN',
			'blocked.throughVpn' => 'LEWAT G VPN',
			'blocked.notChecked' => 'Belum dicek',
			'blocked.opens' => 'Terbuka',
			'blocked.stillBlocked' => 'Diblokir',
			'blocked.whatHappened' => 'APA YANG TERJADI',
			'blocked.countryBlocked' => ({required Object country}) => 'situs diblokir di ${country}',
			'blocked.countrySub' => 'Ditemukan oleh tes relawan dalam 30 hari terakhir',
			'blocked.countryNone' => 'Tidak ada situs diblokir yang dilaporkan dalam 30 hari terakhir.',
			'blocked.countryUnavailable' => 'Gagal memuat hasil negara. Periksa koneksi Anda.',
			'blocked.confirmed' => 'DIBLOKIR',
			'blocked.oftenFails' => 'SERING GAGAL',
			'blocked.kinds.social' => 'Media sosial',
			'blocked.kinds.messaging' => 'Pesan',
			'blocked.kinds.news' => 'Berita',
			'blocked.kinds.video' => 'Video dan musik',
			'blocked.kinds.privacy' => 'Privasi',
			'blocked.how.dns' => 'Alamat palsu',
			'blocked.how.reset' => 'Diputus',
			'blocked.how.timeout' => 'Tidak ada jawaban',
			'blocked.how.page' => 'Halaman blokir',
			'blocked.how.open' => 'Terbuka',
			'blocked.fail.noAnswer' => 'tidak ada jawaban',
			'blocked.fail.refused' => 'ditolak',
			'blocked.fail.cutOff' => ({required Object s}) => 'diputus setelah ${s} dtk',
			'blocked.fail.wrongCert' => 'sertifikat salah',
			'blocked.steps.lookup' => 'Pencarian nama',
			'blocked.steps.connect' => 'Sambung',
			'blocked.steps.handshake' => 'Jabat tangan aman',
			'blocked.consent.title' => 'Sebelum tes pertama',
			'blocked.consent.body' => 'Tes membuka tiap situs dari ponsel ini, tanpa VPN, seperti browser.',
			'blocked.consent.noticeTitle' => 'Bisa terlihat',
			'blocked.consent.notice' => 'Penyedia Anda melihat situs ini dibuka. Di beberapa negara mengunjunginya, meski hanya untuk tes, bisa menarik perhatian. Uji hanya jika Anda merasa aman.',
			'blocked.consent.ok' => 'Saya mengerti, uji',
			'blocked.someBlocked' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} situs diblokir di ${network}', ), 
			'blocked.tests' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('id'))(n, other: '${n} tes', ), 
			_ => null,
		};
	}
}
