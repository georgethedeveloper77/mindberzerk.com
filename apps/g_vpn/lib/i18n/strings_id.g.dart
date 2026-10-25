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
	@override String sitesSee({required Object ip}) => 'Situs melihat ${ip}';
	@override String sitesSeeOrg({required Object ip, required Object org}) => 'Situs melihat ${ip} · ${org}';
	@override String get ipFailed => 'Tidak dapat memeriksa IP Anda';
	@override String get ipChecking => 'Memeriksa IP Anda';
	@override String get themeSystem => 'Tema: ikuti ponsel';
	@override String get themeLight => 'Tema: terang';
	@override String get themeDark => 'Tema: gelap';
	@override String get free => 'Gratis';
	@override String get pickServer => 'Pilih server';
	@override late final _Translations$home$waves$id waves = _Translations$home$waves$id._(_root);
	@override late final _Translations$home$network$id network = _Translations$home$network$id._(_root);
	@override late final _Translations$home$card$id card = _Translations$home$card$id._(_root);
	@override late final _Translations$home$tiles$id tiles = _Translations$home$tiles$id._(_root);
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
}

// Path: pro
class _Translations$pro$id extends Translations$pro$en {
	_Translations$pro$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get owned => 'Anda punya Pro';
	@override String get waitingPlay => 'Menunggu Google Play';
	@override String startTrial({required Object days}) => 'Mulai uji coba gratis ${days} hari';
	@override String thenYearly({required Object price}) => 'Lalu ${price} per tahun. Batalkan kapan saja di Google Play.';
	@override String thenMonthly({required Object price}) => 'Lalu ${price} per bulan. Batalkan kapan saja di Google Play.';
	@override String yearlyPrice({required Object price}) => '${price} per tahun. Batalkan kapan saja di Google Play.';
	@override String monthlyPrice({required Object price}) => '${price} per bulan. Batalkan kapan saja di Google Play.';
	@override String get restore => 'Pulihkan';
	@override String get heroTitle => 'Server lebih cepat,\ndikelola oleh kami';
	@override String get heroSubtitle => 'WireGuard. Tanpa log aktivitas. Tanpa akun.';
	@override String get benefitSpeed => 'Kecepatan penuh, tanpa batas server sukarelawan';
	@override String get benefitKey => 'Kunci dibuat di ponsel Anda, tidak pernah dibagikan';
	@override String get benefitFree => 'Semua yang gratis tetap gratis';
	@override String save({required Object pct}) => 'HEMAT ${pct}%';
	@override String get yearly => 'Tahunan';
	@override String get monthly => 'Bulanan';
	@override String get billedMonthly => 'ditagih bulanan';
	@override String daysFree({required Object days}) => '${days} hari gratis';
	@override String perMonth({required Object price}) => '${price} per bulan';
	@override String get title => 'G VPN Pro';
	@override String get heroTitleOneLine => 'Server lebih cepat, dikelola oleh kami';
	@override String get includes => 'Termasuk';
	@override String get benefitLogs => 'Tanpa log aktivitas di server kami';
	@override String get plan => 'Pilih paket';
	@override String get renewGeneric => 'Langganan diperpanjang otomatis hingga dibatalkan. Batalkan kapan saja di Google Play.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} hari gratis, lalu ${price} per ${period}. Diperpanjang otomatis hingga dibatalkan; batalkan di Google Play paling lambat sehari sebelum uji coba berakhir agar tidak ditagih.';
	@override String renew({required Object price, required Object period}) => '${price} per ${period}. Diperpanjang otomatis hingga dibatalkan; batalkan kapan saja di Google Play.';
	@override String get year => 'tahun';
	@override String get month => 'bulan';
	@override String get manage => 'Kelola langganan';
	@override late final _Translations$pro$free$id free = _Translations$pro$free$id._(_root);
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
	@override String get shieldSub => 'Memblokir situs malware dan phishing';
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
	@override String get wake => 'Nyalakan perangkat';
	@override String get mac => 'Alamat MAC';
	@override String failed({required Object error}) => 'Tidak dapat mengirim: ${error}';
}

// Path: speed
class _Translations$speed$id extends Translations$speed$en {
	_Translations$speed$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get info => 'Diukur oleh M-Lab, platform riset terbuka. Satu tes memakai sekitar 50 sampai 100 MB.\n\nHasil publik: M-Lab menerbitkan setiap tes, termasuk alamat IP asalnya, sebagai data riset terbuka.\n\nPerbandingan penyedia: setelah tes tanpa VPN, G VPN hanya mengirim tiga angka kecepatan. Layanan perbandingan membaca penyedia dan kota Anda dari koneksi itu sendiri dan tidak menyimpan alamat IP. Matikan dengan sakelar di bagian bawah halaman ini.\n\nMelalui VPN: saat VPN aktif, tes mengukur kecepatan melalui terowongan dan membandingkannya dengan tes terakhir tanpa VPN.\n\nPratinjau video: gambar yang sama ditampilkan pada resolusi yang dapat diputar kecepatan ini, berdasarkan bitrate yang dipublikasikan layanan streaming. Tidak ada video yang diunduh.';
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
	@override String routerName({required Object name}) => 'Router: ${name}';
	@override String externalIp({required Object ip}) => 'Alamat internet: ${ip}';
	@override String mapping({required Object proto, required Object host}) => '${proto} ke ${host}';
	@override String get upnpOn => 'UPnP aktif';
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
	@override String get nothingNew => 'Tidak ada yang baru sejak pindaian terakhir';
	@override String get takes => 'Sekitar 30 detik';
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
	@override String get notAnnounced => 'Tidak diumumkan. Daftar perangkat di router Anda dapat menamainya.';
	@override String get newBadge => 'BARU';
	@override String scanning({required Object n}) => 'Memindai ${n} dari 254';
	@override String get thisNetwork => 'jaringan ini';
	@override String newSince({required Object n}) => '${n} baru sejak pindaian terakhir';
	@override String showMore({required Object n}) => 'Tampilkan ${n} lagi';
	@override String ms({required Object n}) => '${n} md';
	@override String onNetwork({required Object network}) => 'perangkat di ${network}';
}

// Path: ping
class _Translations$ping$id extends Translations$ping$en {
	_Translations$ping$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get info => 'Berapa lama satu perjalanan pulang-pergi ke server, diukur setiap detik selama satu menit terakhir.\n\nJitter: seberapa besar setiap jawaban berbeda dari jawaban sebelumnya. Jitter tinggi membuat panggilan putus-putus.\n\nLoss: jawaban yang tidak pernah kembali.\n\nCara: aplikasi Android tidak dapat mengirim ping klasik, jadi setiap uji mengukur waktu jabat tangan koneksi, yang sama dengan satu perjalanan pulang-pergi.';
	@override String get askTitle => 'Ping host';
	@override String get askHint => 'example.com atau 192.168.1.10';
	@override String get cancel => 'Batal';
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
	@override String get unreachable => 'Tidak terjangkau';
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
	@override String get internet => 'Konektivitas internet';
	@override String get speed => 'Tes kecepatan';
	@override String get speedDesc => 'Kecepatan unduh dan unggah, serta kualitas video yang didukung.';
	@override String get ping => 'Ping';
	@override String get pingDesc => 'Waktu respons langsung dan jitter ke server mana pun atau router Anda.';
	@override String get status => 'Status layanan';
	@override String get statusDesc => 'Apakah WhatsApp, YouTube, atau Google dapat dijangkau dari sini, atau diblokir?';
	@override String get trace => 'Traceroute';
	@override String get traceDesc => 'Setiap router antara Anda dan sebuah situs, dan berapa lama masing-masing.';
	@override String get security => 'Keamanan jaringan';
	@override String get devices => 'Perangkat di jaringan ini';
	@override String get devicesDesc => 'Siapa lagi di Wi-Fi Anda: ponsel, TV, kamera, dan komputer.';
	@override String get router => 'Periksa router';
	@override String get routerDesc => 'Apakah perangkat dapat membuka port di router Anda sendiri (UPnP).';
	@override String get ports => 'Port terbuka';
	@override String get portsDesc => 'Periksa router atau server dari port terbuka yang berisiko.';
	@override String get utilities => 'Utilitas';
	@override String get wifiScanner => 'Pemindai Wi-Fi';
	@override String get wifiDesc => 'Jaringan di sekitar, keamanannya, dan kanal paling sepi.';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'Nyalakan komputer atau NAS di jaringan ini.';
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
	@override String bestChannel({required Object n}) => 'Kanal 2,4 GHz paling sepi: ${n}';
	@override String weak({required Object n}) => '${n} terbuka atau lemah';
	@override String get connectedPrefix => 'Terhubung · ';
	@override String get permissionInfo => 'Android hanya menampilkan jaringan Wi-Fi di sekitar kepada aplikasi yang memiliki izin lokasi. G VPN memakainya hanya untuk menampilkan jaringan di ponsel ini.';
	@override String get info => 'Menampilkan jaringan dari pemindaian terakhir ponsel. Android hanya mengizinkan beberapa pemindaian per menit, jadi pemindaian ulang yang cepat bisa menampilkan daftar yang sama. Kanal yang disarankan adalah yang paling sepi di antara 1, 6, dan 11, tiga kanal yang tidak tumpang tindih.';
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
	@override String devicesSub({required Object n}) => 'Hingga ${n} ponsel, masing-masing dengan kuncinya sendiri';
	@override String get footnote => 'Setiap ponsel mendapat kuncinya sendiri, dibuat di ponsel itu. G Servers tidak menyimpan log aktivitas.';
	@override String get leastBusy => 'PALING SEPI SAAT INI';
	@override String busyNoLogs({required Object n}) => '${n}% sibuk · tanpa log';
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

// Path: home.waves
class _Translations$home$waves$id extends Translations$home$waves$en {
	_Translations$home$waves$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get encrypted => 'TERENKRIPSI';
	@override String get securing => 'MENGAMANKAN';
	@override String get exposed => 'TERBUKA';
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
	@override String get connectedVia => 'TERHUBUNG MELALUI';
	@override String get protocol => 'PROTOKOL';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, di dalam terowongan';
	@override String get dnsServer => 'Server, di dalam terowongan';
	@override String get downloaded => 'DIUNDUH';
	@override String get uploaded => 'DIUNGGAH';
	@override String get wireguard => 'WireGuard';
	@override String openvpn({required Object proto}) => 'OpenVPN ${proto}';
}

// Path: home.tiles
class _Translations$home$tiles$id extends Translations$home$tiles$en {
	_Translations$home$tiles$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get shield => 'Perisai';
	@override String get shieldOn => 'Memblokir situs berbahaya';
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
	@override String get shield => 'Perisai mengirim pencarian DNS ke Quad9, yang menolak situs malware dan phishing yang dikenal. Perisai tidak memblokir iklan, dan menggantikan DNS server selama aktif.';
	@override String get autoConnect => 'Sambung otomatis: memakai server WireGuard pilihan Anda. Memutus secara manual menjedanya sampai Anda bergabung ke jaringan lain.';
	@override String get apps => 'Aplikasi langsung: aplikasi yang melewati VPN terhubung langsung. Bank sering memblokir alamat VPN, jadi pembayaran bisa gagal lewat VPN.';
	@override String get reconnect => 'Mengubah Perisai atau aplikasi akan menyambungkan ulang VPN sebentar.';
	@override String get stay => 'Tetap terhubung: beberapa ponsel menghentikan aplikasi di latar belakang untuk menghemat baterai. VPN selalu aktif dan setelan baterai tanpa batasan menjaga G VPN tetap berjalan.';
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
			'home.sitesSee' => ({required Object ip}) => 'Situs melihat ${ip}',
			'home.sitesSeeOrg' => ({required Object ip, required Object org}) => 'Situs melihat ${ip} · ${org}',
			'home.ipFailed' => 'Tidak dapat memeriksa IP Anda',
			'home.ipChecking' => 'Memeriksa IP Anda',
			'home.themeSystem' => 'Tema: ikuti ponsel',
			'home.themeLight' => 'Tema: terang',
			'home.themeDark' => 'Tema: gelap',
			'home.free' => 'Gratis',
			'home.pickServer' => 'Pilih server',
			'home.waves.encrypted' => 'TERENKRIPSI',
			'home.waves.securing' => 'MENGAMANKAN',
			'home.waves.exposed' => 'TERBUKA',
			'home.network.title' => 'JARINGAN INI',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Offline',
			'home.network.showName' => 'Tampilkan nama',
			'home.network.scanFailed' => 'Pemeriksaan gagal. Akan dijalankan lagi saat jaringan berubah.',
			'home.card.connectedVia' => 'TERHUBUNG MELALUI',
			'home.card.protocol' => 'PROTOKOL',
			'home.card.dns' => 'DNS',
			'home.card.dnsQuad9' => 'Quad9, di dalam terowongan',
			'home.card.dnsServer' => 'Server, di dalam terowongan',
			'home.card.downloaded' => 'DIUNDUH',
			'home.card.uploaded' => 'DIUNGGAH',
			'home.card.wireguard' => 'WireGuard',
			'home.card.openvpn' => ({required Object proto}) => 'OpenVPN ${proto}',
			'home.tiles.shield' => 'Perisai',
			'home.tiles.shieldOn' => 'Memblokir situs berbahaya',
			'home.tiles.appsDirect' => 'Aplikasi langsung',
			'home.tiles.appsAll' => 'Semua aplikasi terlindungi',
			'home.tiles.appsSkip' => ({required Object n}) => '${n} tanpa VPN',
			'home.tiles.autoConnect' => 'Sambung otomatis',
			'home.tiles.autoOpen' => 'Di Wi-Fi publik',
			'home.tiles.autoAny' => 'Di semua Wi-Fi',
			'home.tiles.speed' => 'Kecepatan',
			'home.tiles.speedTap' => 'Ketuk untuk tes',
			'home.tiles.speedDirect' => ({required Object mbps}) => 'Langsung ${mbps} Mbps',
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
			'pro.owned' => 'Anda punya Pro',
			'pro.waitingPlay' => 'Menunggu Google Play',
			'pro.startTrial' => ({required Object days}) => 'Mulai uji coba gratis ${days} hari',
			'pro.thenYearly' => ({required Object price}) => 'Lalu ${price} per tahun. Batalkan kapan saja di Google Play.',
			'pro.thenMonthly' => ({required Object price}) => 'Lalu ${price} per bulan. Batalkan kapan saja di Google Play.',
			'pro.yearlyPrice' => ({required Object price}) => '${price} per tahun. Batalkan kapan saja di Google Play.',
			'pro.monthlyPrice' => ({required Object price}) => '${price} per bulan. Batalkan kapan saja di Google Play.',
			'pro.restore' => 'Pulihkan',
			'pro.heroTitle' => 'Server lebih cepat,\ndikelola oleh kami',
			'pro.heroSubtitle' => 'WireGuard. Tanpa log aktivitas. Tanpa akun.',
			'pro.benefitSpeed' => 'Kecepatan penuh, tanpa batas server sukarelawan',
			'pro.benefitKey' => 'Kunci dibuat di ponsel Anda, tidak pernah dibagikan',
			'pro.benefitFree' => 'Semua yang gratis tetap gratis',
			'pro.save' => ({required Object pct}) => 'HEMAT ${pct}%',
			'pro.yearly' => 'Tahunan',
			'pro.monthly' => 'Bulanan',
			'pro.billedMonthly' => 'ditagih bulanan',
			'pro.daysFree' => ({required Object days}) => '${days} hari gratis',
			'pro.perMonth' => ({required Object price}) => '${price} per bulan',
			'pro.title' => 'G VPN Pro',
			'pro.heroTitleOneLine' => 'Server lebih cepat, dikelola oleh kami',
			'pro.includes' => 'Termasuk',
			'pro.benefitLogs' => 'Tanpa log aktivitas di server kami',
			'pro.plan' => 'Pilih paket',
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
			'rules.title' => 'Aturan',
			'rules.info.shield' => 'Perisai mengirim pencarian DNS ke Quad9, yang menolak situs malware dan phishing yang dikenal. Perisai tidak memblokir iklan, dan menggantikan DNS server selama aktif.',
			'rules.info.autoConnect' => 'Sambung otomatis: memakai server WireGuard pilihan Anda. Memutus secara manual menjedanya sampai Anda bergabung ke jaringan lain.',
			'rules.info.apps' => 'Aplikasi langsung: aplikasi yang melewati VPN terhubung langsung. Bank sering memblokir alamat VPN, jadi pembayaran bisa gagal lewat VPN.',
			'rules.info.reconnect' => 'Mengubah Perisai atau aplikasi akan menyambungkan ulang VPN sebentar.',
			'rules.info.stay' => 'Tetap terhubung: beberapa ponsel menghentikan aplikasi di latar belakang untuk menghemat baterai. VPN selalu aktif dan setelan baterai tanpa batasan menjaga G VPN tetap berjalan.',
			'rules.protection' => 'Perlindungan',
			'rules.shield' => 'Perisai',
			'rules.shieldSub' => 'Memblokir situs malware dan phishing',
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
			'wol.wake' => 'Nyalakan perangkat',
			'wol.mac' => 'Alamat MAC',
			'wol.failed' => ({required Object error}) => 'Tidak dapat mengirim: ${error}',
			'speed.info' => 'Diukur oleh M-Lab, platform riset terbuka. Satu tes memakai sekitar 50 sampai 100 MB.\n\nHasil publik: M-Lab menerbitkan setiap tes, termasuk alamat IP asalnya, sebagai data riset terbuka.\n\nPerbandingan penyedia: setelah tes tanpa VPN, G VPN hanya mengirim tiga angka kecepatan. Layanan perbandingan membaca penyedia dan kota Anda dari koneksi itu sendiri dan tidak menyimpan alamat IP. Matikan dengan sakelar di bagian bawah halaman ini.\n\nMelalui VPN: saat VPN aktif, tes mengukur kecepatan melalui terowongan dan membandingkannya dengan tes terakhir tanpa VPN.\n\nPratinjau video: gambar yang sama ditampilkan pada resolusi yang dapat diputar kecepatan ini, berdasarkan bitrate yang dipublikasikan layanan streaming. Tidak ada video yang diunduh.',
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
			'router.routerName' => ({required Object name}) => 'Router: ${name}',
			'router.externalIp' => ({required Object ip}) => 'Alamat internet: ${ip}',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} ke ${host}',
			'router.upnpOn' => 'UPnP aktif',
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
			'devices.nothingNew' => 'Tidak ada yang baru sejak pindaian terakhir',
			'devices.takes' => 'Sekitar 30 detik',
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
			'devices.notAnnounced' => 'Tidak diumumkan. Daftar perangkat di router Anda dapat menamainya.',
			'devices.newBadge' => 'BARU',
			'devices.scanning' => ({required Object n}) => 'Memindai ${n} dari 254',
			'devices.thisNetwork' => 'jaringan ini',
			'devices.newSince' => ({required Object n}) => '${n} baru sejak pindaian terakhir',
			'devices.showMore' => ({required Object n}) => 'Tampilkan ${n} lagi',
			'devices.ms' => ({required Object n}) => '${n} md',
			'devices.onNetwork' => ({required Object network}) => 'perangkat di ${network}',
			'ping.info' => 'Berapa lama satu perjalanan pulang-pergi ke server, diukur setiap detik selama satu menit terakhir.\n\nJitter: seberapa besar setiap jawaban berbeda dari jawaban sebelumnya. Jitter tinggi membuat panggilan putus-putus.\n\nLoss: jawaban yang tidak pernah kembali.\n\nCara: aplikasi Android tidak dapat mengirim ping klasik, jadi setiap uji mengukur waktu jabat tangan koneksi, yang sama dengan satu perjalanan pulang-pergi.',
			'ping.askTitle' => 'Ping host',
			'ping.askHint' => 'example.com atau 192.168.1.10',
			'ping.cancel' => 'Batal',
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
			'status.unreachable' => 'Tidak terjangkau',
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
			'tools.internet' => 'Konektivitas internet',
			'tools.speed' => 'Tes kecepatan',
			'tools.speedDesc' => 'Kecepatan unduh dan unggah, serta kualitas video yang didukung.',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'Waktu respons langsung dan jitter ke server mana pun atau router Anda.',
			'tools.status' => 'Status layanan',
			'tools.statusDesc' => 'Apakah WhatsApp, YouTube, atau Google dapat dijangkau dari sini, atau diblokir?',
			'tools.trace' => 'Traceroute',
			'tools.traceDesc' => 'Setiap router antara Anda dan sebuah situs, dan berapa lama masing-masing.',
			'tools.security' => 'Keamanan jaringan',
			'tools.devices' => 'Perangkat di jaringan ini',
			'tools.devicesDesc' => 'Siapa lagi di Wi-Fi Anda: ponsel, TV, kamera, dan komputer.',
			'tools.router' => 'Periksa router',
			'tools.routerDesc' => 'Apakah perangkat dapat membuka port di router Anda sendiri (UPnP).',
			'tools.ports' => 'Port terbuka',
			'tools.portsDesc' => 'Periksa router atau server dari port terbuka yang berisiko.',
			'tools.utilities' => 'Utilitas',
			'tools.wifiScanner' => 'Pemindai Wi-Fi',
			'tools.wifiDesc' => 'Jaringan di sekitar, keamanannya, dan kanal paling sepi.',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Nyalakan komputer atau NAS di jaringan ini.',
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
			'wifi.title' => 'Pemindai Wi-Fi',
			'wifi.allow' => 'Izinkan pemindaian Wi-Fi',
			'wifi.needsPermission' => 'Memerlukan izin lokasi.',
			'wifi.scanning' => 'Memindai',
			'wifi.again' => 'Pindai lagi',
			'wifi.failed' => 'Pemindaian gagal',
			'wifi.none' => 'Tidak ada jaringan ditemukan. Lokasi mungkin mati.',
			'wifi.hidden' => 'Jaringan tersembunyi',
			'wifi.nearby' => ({required Object n}) => '${n} jaringan di sekitar',
			'wifi.bestChannel' => ({required Object n}) => 'Kanal 2,4 GHz paling sepi: ${n}',
			'wifi.weak' => ({required Object n}) => '${n} terbuka atau lemah',
			'wifi.connectedPrefix' => 'Terhubung · ',
			'wifi.permissionInfo' => 'Android hanya menampilkan jaringan Wi-Fi di sekitar kepada aplikasi yang memiliki izin lokasi. G VPN memakainya hanya untuk menampilkan jaringan di ponsel ini.',
			'wifi.info' => 'Menampilkan jaringan dari pemindaian terakhir ponsel. Android hanya mengizinkan beberapa pemindaian per menit, jadi pemindaian ulang yang cepat bisa menampilkan daftar yang sama. Kanal yang disarankan adalah yang paling sepi di antara 1, 6, dan 11, tiga kanal yang tidak tumpang tindih.',
			'errors.notAuthorized' => 'Izin VPN tidak diberikan.',
			'errors.turnedOff' => 'VPN dimatikan oleh sistem atau aplikasi lain.',
			_ => null,
		} ?? switch (path) {
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
			'gs.devicesSub' => ({required Object n}) => 'Hingga ${n} ponsel, masing-masing dengan kuncinya sendiri',
			'gs.footnote' => 'Setiap ponsel mendapat kuncinya sendiri, dibuat di ponsel itu. G Servers tidak menyimpan log aktivitas.',
			'gs.leastBusy' => 'PALING SEPI SAAT INI',
			'gs.busyNoLogs' => ({required Object n}) => '${n}% sibuk · tanpa log',
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
			_ => null,
		};
	}
}
