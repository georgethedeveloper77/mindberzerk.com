///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$common$en common = Translations$common$en.internal(_root);
	late final Translations$nav$en nav = Translations$nav$en.internal(_root);
	late final Translations$home$en home = Translations$home$en.internal(_root);
	late final Translations$servers$en servers = Translations$servers$en.internal(_root);
	late final Translations$pro$en pro = Translations$pro$en.internal(_root);
	late final Translations$rules$en rules = Translations$rules$en.internal(_root);
	late final Translations$apps$en apps = Translations$apps$en.internal(_root);
	late final Translations$location$en location = Translations$location$en.internal(_root);
	late final Translations$addServer$en addServer = Translations$addServer$en.internal(_root);
	late final Translations$button$en button = Translations$button$en.internal(_root);
	late final Translations$wol$en wol = Translations$wol$en.internal(_root);
	late final Translations$speed$en speed = Translations$speed$en.internal(_root);
	late final Translations$router$en router = Translations$router$en.internal(_root);
	late final Translations$network$en network = Translations$network$en.internal(_root);
	late final Translations$devices$en devices = Translations$devices$en.internal(_root);
	late final Translations$ping$en ping = Translations$ping$en.internal(_root);
	late final Translations$status$en status = Translations$status$en.internal(_root);
	late final Translations$tools$en tools = Translations$tools$en.internal(_root);
	late final Translations$trace$en trace = Translations$trace$en.internal(_root);
	late final Translations$ports$en ports = Translations$ports$en.internal(_root);
	late final Translations$wifi$en wifi = Translations$wifi$en.internal(_root);
	late final Translations$errors$en errors = Translations$errors$en.internal(_root);
	late final Translations$scan$en scan = Translations$scan$en.internal(_root);
	late final Translations$legal$en legal = Translations$legal$en.internal(_root);
	late final Translations$update$en update = Translations$update$en.internal(_root);
	late final Translations$details$en details = Translations$details$en.internal(_root);
	late final Translations$share$en share = Translations$share$en.internal(_root);
	late final Translations$add$en add = Translations$add$en.internal(_root);
	late final Translations$backup$en backup = Translations$backup$en.internal(_root);
	late final Translations$gs$en gs = Translations$gs$en.internal(_root);
	late final Translations$map$en map = Translations$map$en.internal(_root);
	late final Translations$stats$en stats = Translations$stats$en.internal(_root);
	late final Translations$recents$en recents = Translations$recents$en.internal(_root);
	late final Translations$presets$en presets = Translations$presets$en.internal(_root);
	late final Translations$shield$en shield = Translations$shield$en.internal(_root);
	late final Translations$checks$en checks = Translations$checks$en.internal(_root);
	late final Translations$toolSettings$en toolSettings = Translations$toolSettings$en.internal(_root);
	late final Translations$security$en security = Translations$security$en.internal(_root);
	late final Translations$providers$en providers = Translations$providers$en.internal(_root);
	late final Translations$alerts$en alerts = Translations$alerts$en.internal(_root);
	late final Translations$report$en report = Translations$report$en.internal(_root);
	late final Translations$breaches$en breaches = Translations$breaches$en.internal(_root);
	late final Translations$blocked$en blocked = Translations$blocked$en.internal(_root);
}

// Path: common
class Translations$common$en {
	Translations$common$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Got it'
	String get gotIt => 'Got it';

	/// en: 'About'
	String get about => 'About';

	/// en: 'Connect'
	String get connect => 'Connect';

	/// en: 'Connected'
	String get connected => 'Connected';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'OK'
	String get ok => 'OK';

	/// en: 'Remove'
	String get remove => 'Remove';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Continue'
	String get continueLabel => 'Continue';

	/// en: 'Not now'
	String get notNow => 'Not now';

	/// en: 'Open settings'
	String get openSettings => 'Open settings';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Off'
	String get off => 'Off';

	/// en: 'Changes reconnect the VPN'
	String get changesReconnect => 'Changes reconnect the VPN';
}

// Path: nav
class Translations$nav$en {
	Translations$nav$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'VPN'
	String get vpn => 'VPN';

	/// en: 'Servers'
	String get servers => 'Servers';

	/// en: 'Tools'
	String get tools => 'Tools';

	/// en: 'Rules'
	String get rules => 'Rules';

	/// en: 'Pro'
	String get pro => 'Pro';
}

// Path: home
class Translations$home$en {
	Translations$home$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	late final Translations$home$status$en status = Translations$home$status$en.internal(_root);

	/// en: 'Resumes at {time} · tap to resume now'
	String resumesAt({required Object time}) => 'Resumes at ${time} · tap to resume now';

	/// en: 'Could not check your IP'
	String get ipFailed => 'Could not check your IP';

	/// en: 'Checking your IP'
	String get ipChecking => 'Checking your IP';

	/// en: 'Theme: follows phone'
	String get themeSystem => 'Theme: follows phone';

	/// en: 'Theme: light'
	String get themeLight => 'Theme: light';

	/// en: 'Theme: dark'
	String get themeDark => 'Theme: dark';

	/// en: 'Free'
	String get free => 'Free';

	/// en: 'Pick a server'
	String get pickServer => 'Pick a server';

	late final Translations$home$network$en network = Translations$home$network$en.internal(_root);
	late final Translations$home$card$en card = Translations$home$card$en.internal(_root);
	late final Translations$home$tiles$en tiles = Translations$home$tiles$en.internal(_root);
	late final Translations$home$fastest$en fastest = Translations$home$fastest$en.internal(_root);
	late final Translations$home$ip$en ip = Translations$home$ip$en.internal(_root);
}

// Path: servers
class Translations$servers$en {
	Translations$servers$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Servers'
	String get title => 'Servers';

	/// en: 'About servers'
	String get aboutServers => 'About servers';

	late final Translations$servers$tabs$en tabs = Translations$servers$tabs$en.internal(_root);
	late final Translations$servers$sheet$en sheet = Translations$servers$sheet$en.internal(_root);
	late final Translations$servers$badges$en badges = Translations$servers$badges$en.internal(_root);
	late final Translations$servers$filters$en filters = Translations$servers$filters$en.internal(_root);

	/// en: 'Could not load the list'
	String get loadFailed => 'Could not load the list';

	/// en: 'No servers right now'
	String get noServers => 'No servers right now';

	/// en: 'BEST FOR YOU NOW'
	String get best => 'BEST FOR YOU NOW';

	/// en: 'Top ranked right now'
	String get topRanked => 'Top ranked right now';

	/// en: 'ADD A SERVER'
	String get addHeading => 'ADD A SERVER';

	/// en: 'Scan QR'
	String get scanQr => 'Scan QR';

	/// en: 'Import file'
	String get importFile => 'Import file';

	/// en: 'Paste'
	String get paste => 'Paste';

	late final Translations$servers$own$en own = Translations$servers$own$en.internal(_root);

	/// en: 'Config needs attention'
	String get configBroken => 'Config needs attention';

	/// en: 'CONNECTED'
	String get connectedBadge => 'CONNECTED';

	/// en: 'Scanned server'
	String get scannedServer => 'Scanned server';

	/// en: 'Could not scan'
	String get scanFailedTitle => 'Could not scan';

	/// en: 'The scanner is not available on this phone.'
	String get scanFailedBody => 'The scanner is not available on this phone.';

	/// en: 'Could not import'
	String get importFailedTitle => 'Could not import';

	/// en: 'That file could not be read.'
	String get importFailedBody => 'That file could not be read.';

	/// en: 'Rename server'
	String get renameTitle => 'Rename server';

	/// en: 'Name, for example Home router'
	String get nameHint => 'Name, for example Home router';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Disconnect'
	String get disconnect => 'Disconnect';

	/// en: 'More options'
	String get more => 'More options';

	/// en: 'just now'
	String get justNow => 'just now';

	/// en: '{n} min ago'
	String minutesAgo({required Object n}) => '${n} min ago';

	/// en: '{n} h ago'
	String hoursAgo({required Object n}) => '${n} h ago';

	/// en: '{n} d ago'
	String daysAgo({required Object n}) => '${n} d ago';

	/// en: 'Not used yet'
	String get neverUsed => 'Not used yet';

	/// en: 'Last used {when}'
	String lastUsed({required Object when}) => 'Last used ${when}';

	/// en: 'Disconnect first to remove it'
	String get disconnectFirst => 'Disconnect first to remove it';

	/// en: 'Remove this server from G VPN? Its settings are deleted from this phone; the server itself is not changed.'
	String get removeConfirm => 'Remove this server from G VPN? Its settings are deleted from this phone; the server itself is not changed.';

	/// en: 'G Servers'
	String get gTab => 'G Servers';

	/// en: 'Search countries'
	String get search => 'Search countries';

	/// en: 'No servers match.'
	String get noMatch => 'No servers match.';

	/// en: 'best {ms} ms'
	String bestPing({required Object ms}) => 'best ${ms} ms';

	/// en: 'BEST'
	String get bestTag => 'BEST';

	/// en: 'Our own servers'
	String get ownHero => 'Our own servers';

	/// en: 'Faster, private, each phone with its own key'
	String get ownHeroSub => 'Faster, private, each phone with its own key';

	/// en: '(one) {{n} server} (other) {{n} servers}'
	String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} server',
		other: '${n} servers',
	);

	/// en: 'Show all {n}'
	String showAll({required Object n}) => 'Show all ${n}';

	/// en: 'Show fewer'
	String get showFewer => 'Show fewer';

	/// en: 'Fast'
	String get fastTab => 'Fast';

	/// en: 'Fastest free'
	String get fastestFree => 'Fastest free';
}

// Path: pro
class Translations$pro$en {
	Translations$pro$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'You have Pro'
	String get owned => 'You have Pro';

	/// en: 'Waiting for Google Play'
	String get waitingPlay => 'Waiting for Google Play';

	/// en: 'Start {days}-day free trial'
	String startTrial({required Object days}) => 'Start ${days}-day free trial';

	/// en: 'Restore'
	String get restore => 'Restore';

	/// en: 'SAVE {pct}%'
	String save({required Object pct}) => 'SAVE ${pct}%';

	/// en: 'Yearly'
	String get yearly => 'Yearly';

	/// en: 'Monthly'
	String get monthly => 'Monthly';

	/// en: 'billed monthly'
	String get billedMonthly => 'billed monthly';

	/// en: '{days} days free'
	String daysFree({required Object days}) => '${days} days free';

	/// en: '{price} a month'
	String perMonth({required Object price}) => '${price} a month';

	/// en: 'G VPN Pro'
	String get title => 'G VPN Pro';

	/// en: 'Subscriptions renew automatically until cancelled. Cancel anytime in Google Play.'
	String get renewGeneric => 'Subscriptions renew automatically until cancelled. Cancel anytime in Google Play.';

	/// en: '{days} days free, then {price} a {period}. Renews automatically until cancelled; cancel anytime in Google Play, at least a day before the trial ends to avoid being charged.'
	String renewTrial({required Object days, required Object price, required Object period}) => '${days} days free, then ${price} a ${period}. Renews automatically until cancelled; cancel anytime in Google Play, at least a day before the trial ends to avoid being charged.';

	/// en: '{price} a {period}. Renews automatically until cancelled; cancel anytime in Google Play.'
	String renew({required Object price, required Object period}) => '${price} a ${period}. Renews automatically until cancelled; cancel anytime in Google Play.';

	/// en: 'year'
	String get year => 'year';

	/// en: 'month'
	String get month => 'month';

	/// en: 'Manage subscription'
	String get manage => 'Manage subscription';

	late final Translations$pro$free$en free = Translations$pro$free$en.internal(_root);

	/// en: 'Our own fast servers, and every check unlimited'
	String get heroLine => 'Our own fast servers, and every check unlimited';

	/// en: 'Start Pro'
	String get start => 'Start Pro';

	/// en: 'FREE'
	String get compareFree => 'FREE';

	/// en: 'PRO'
	String get comparePro => 'PRO';

	/// en: 'Free servers'
	String get rowFreeServers => 'Free servers';

	/// en: 'Speed test, tools, Wi-Fi checks'
	String get rowTools => 'Speed test, tools, Wi-Fi checks';

	/// en: 'G Servers, no logs'
	String get rowGServers => 'G Servers, no logs';

	/// en: 'Link checks'
	String get rowLinks => 'Link checks';

	/// en: '{n} a month'
	String linksFree({required Object n}) => '${n} a month';

	/// en: 'Unlimited'
	String get unlimited => 'Unlimited';
}

// Path: rules
class Translations$rules$en {
	Translations$rules$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Rules'
	String get title => 'Rules';

	late final Translations$rules$info$en info = Translations$rules$info$en.internal(_root);

	/// en: 'Protection'
	String get protection => 'Protection';

	/// en: 'Shield'
	String get shield => 'Shield';

	/// en: 'Shield without the VPN'
	String get privateDns => 'Shield without the VPN';

	/// en: 'Copy dns.quad9.net for Private DNS'
	String get privateDnsSub => 'Copy dns.quad9.net for Private DNS';

	/// en: 'Copied dns.quad9.net'
	String get privateDnsCopied => 'Copied dns.quad9.net';

	/// en: 'Open Settings, search for Private DNS, choose "Private DNS provider hostname" and paste it.'
	String get privateDnsHow => 'Open Settings, search for Private DNS, choose "Private DNS provider hostname" and paste it.';

	/// en: 'Stay connected'
	String get stay => 'Stay connected';

	/// en: 'Always-on VPN'
	String get alwaysOn => 'Always-on VPN';

	/// en: 'Android restarts G VPN if it stops'
	String get alwaysOnSub => 'Android restarts G VPN if it stops';

	/// en: 'Battery'
	String get battery => 'Battery';

	/// en: 'Unrestricted'
	String get batteryOk => 'Unrestricted';

	/// en: 'Restricted: may stop in background'
	String get batteryRestricted => 'Restricted: may stop in background';

	/// en: 'Auto-connect'
	String get autoConnect => 'Auto-connect';

	/// en: 'Off'
	String get autoOff => 'Off';

	/// en: 'Only when you tap'
	String get autoOffSub => 'Only when you tap';

	/// en: 'Public Wi-Fi'
	String get autoOpen => 'Public Wi-Fi';

	/// en: 'Open, WEP or sign-in networks'
	String get autoOpenSub => 'Open, WEP or sign-in networks';

	/// en: 'Every Wi-Fi'
	String get autoAny => 'Every Wi-Fi';

	/// en: 'Any Wi-Fi network'
	String get autoAnySub => 'Any Wi-Fi network';

	/// en: 'Apps'
	String get apps => 'Apps';

	/// en: 'Apps direct'
	String get appsDirect => 'Apps direct';

	/// en: 'Every app uses the VPN'
	String get appsNone => 'Every app uses the VPN';

	/// en: '{n} apps skip the VPN'
	String appsSome({required Object n}) => '${n} apps skip the VPN';

	/// en: 'Appearance'
	String get appearance => 'Appearance';

	/// en: 'Phone'
	String get themePhone => 'Phone';

	/// en: 'Light'
	String get themeLight => 'Light';

	/// en: 'Dark'
	String get themeDark => 'Dark';

	/// en: 'About'
	String get about => 'About';
}

// Path: apps
class Translations$apps$en {
	Translations$apps$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Apps direct'
	String get title => 'Apps direct';

	/// en: 'Chosen apps connect without the VPN. Everything else stays protected.'
	String get sheetSubtitle => 'Chosen apps connect without the VPN. Everything else stays protected.';

	/// en: 'Why skip an app'
	String get whyTitle => 'Why skip an app';

	/// en: 'Banks and payment apps often block VPN addresses, so payments can fail through a VPN. Some local services only work from your own country.'
	String get whyBody => 'Banks and payment apps often block VPN addresses, so payments can fail through a VPN. Some local services only work from your own country.';

	/// en: 'Star the apps you change often; they stay at the top.'
	String get favouritesBody => 'Star the apps you change often; they stay at the top.';

	/// en: 'While connected'
	String get whileConnected => 'While connected';

	/// en: 'Changing this list reconnects the VPN for a moment.'
	String get whileConnectedBody => 'Changing this list reconnects the VPN for a moment.';

	/// en: 'Search {n} apps'
	String search({required Object n}) => 'Search ${n} apps';

	/// en: 'Skipping the VPN'
	String get skipping => 'Skipping the VPN';

	/// en: 'None. Every app goes through the VPN.'
	String get skippingNone => 'None. Every app goes through the VPN.';

	/// en: 'Protect {app} again'
	String protectAgain({required Object app}) => 'Protect ${app} again';

	/// en: 'Banking and payments'
	String get banking => 'Banking and payments';

	/// en: '{n} found that may block VPNs'
	String bankingFound({required Object n}) => '${n} found that may block VPNs';

	/// en: 'Add all'
	String get addAll => 'Add all';

	/// en: 'Favourites'
	String get favourites => 'Favourites';

	/// en: 'All apps'
	String get all => 'All apps';

	/// en: '{n} found'
	String found({required Object n}) => '${n} found';

	/// en: 'No app matches.'
	String get noMatch => 'No app matches.';

	/// en: 'Show all {n}'
	String showAll({required Object n}) => 'Show all ${n}';

	/// en: 'Skips the VPN'
	String get skips => 'Skips the VPN';

	/// en: 'Remove from favourites'
	String get unstar => 'Remove from favourites';

	/// en: 'Add to favourites'
	String get star => 'Add to favourites';
}

// Path: location
class Translations$location$en {
	Translations$location$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Allow location for Wi-Fi'
	String get title => 'Allow location for Wi-Fi';

	/// en: 'Show your Wi-Fi name on Home'
	String get useHome => 'Show your Wi-Fi name on Home';

	/// en: 'Scan nearby networks and channels'
	String get useScan => 'Scan nearby networks and channels';

	/// en: 'Stays on this phone. Your location is never collected.'
	String get private => 'Stays on this phone. Your location is never collected.';

	/// en: 'Turn on Location'
	String get switchTitle => 'Turn on Location';

	/// en: 'Android hides Wi-Fi names while the Location switch is off'
	String get switchBody => 'Android hides Wi-Fi names while the Location switch is off';
}

// Path: addServer
class Translations$addServer$en {
	Translations$addServer$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'The clipboard is empty.'
	String get clipboardEmpty => 'The clipboard is empty.';

	/// en: 'Add your server'
	String get title => 'Add your server';

	/// en: 'Paste a WireGuard config from your router, VPS or home server.'
	String get body => 'Paste a WireGuard config from your router, VPS or home server.';

	/// en: 'Name, for example Home router'
	String get nameHint => 'Name, for example Home router';

	/// en: 'Paste'
	String get paste => 'Paste';

	/// en: 'Save server'
	String get save => 'Save server';

	/// en: 'This is not a WireGuard config: {error}'
	String notWireguard({required Object error}) => 'This is not a WireGuard config: ${error}';
}

// Path: button
class Translations$button$en {
	Translations$button$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Stop'
	String get stop => 'Stop';

	/// en: 'Connecting'
	String get connecting => 'Connecting';

	/// en: 'Stopping'
	String get stopping => 'Stopping';

	/// en: 'Connect'
	String get connect => 'Connect';

	/// en: 'Disconnect'
	String get disconnect => 'Disconnect';
}

// Path: wol
class Translations$wol$en {
	Translations$wol$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Turns on a computer or NAS on this Wi-Fi, if Wake on LAN is enabled in its settings. Your phone must be on the same network; turn the VPN off first.'
	String get info => 'Turns on a computer or NAS on this Wi-Fi, if Wake on LAN is enabled in its settings. Your phone must be on the same network; turn the VPN off first.';

	/// en: 'That is not a MAC address. It looks like AA:BB:CC:DD:EE:FF.'
	String get badMac => 'That is not a MAC address. It looks like AA:BB:CC:DD:EE:FF.';

	/// en: 'Wake signal sent. The device should start within a minute.'
	String get sent => 'Wake signal sent. The device should start within a minute.';

	/// en: 'Wake on LAN'
	String get title => 'Wake on LAN';

	/// en: 'MAC address'
	String get mac => 'MAC address';

	/// en: 'Could not send: {error}'
	String failed({required Object error}) => 'Could not send: ${error}';

	/// en: 'Computer'
	String get computer => 'Computer';

	/// en: 'Pick a device to wake'
	String get pick => 'Pick a device to wake';

	/// en: 'Waking {name}'
	String waking({required Object name}) => 'Waking ${name}';

	/// en: 'YOUR DEVICES'
	String get yours => 'YOUR DEVICES';

	/// en: 'Wake {name}'
	String wakeNamed({required Object name}) => 'Wake ${name}';

	/// en: 'Hold a device to remove it'
	String get removeHint => 'Hold a device to remove it';

	/// en: 'ADD A DEVICE'
	String get add => 'ADD A DEVICE';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'Save and wake'
	String get saveWake => 'Save and wake';
}

// Path: speed
class Translations$speed$en {
	Translations$speed$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Download'
	String get download => 'Download';

	/// en: 'Upload'
	String get upload => 'Upload';

	/// en: 'Finding a server'
	String get finding => 'Finding a server';

	/// en: 'Through the VPN'
	String get throughVpn => 'Through the VPN';

	/// en: 'Direct, no VPN'
	String get directNoVpn => 'Direct, no VPN';

	/// en: 'Speed test'
	String get title => 'Speed test';

	/// en: 'Stop'
	String get stop => 'Stop';

	/// en: 'Start test'
	String get start => 'Start test';

	/// en: 'Test again'
	String get again => 'Test again';

	/// en: 'Via VPN'
	String get viaVpn => 'Via VPN';

	/// en: 'Direct'
	String get direct => 'Direct';

	/// en: 'Mbps'
	String get mbps => 'Mbps';

	/// en: 'PING'
	String get ping => 'PING';

	/// en: 'VS DIRECT'
	String get vsDirect => 'VS DIRECT';

	/// en: 'Compare with providers nearby'
	String get compare => 'Compare with providers nearby';

	/// en: 'Shares speeds only, never your IP'
	String get compareSub => 'Shares speeds only, never your IP';

	/// en: 'Large TVs'
	String get tierTv => 'Large TVs';

	/// en: 'Large laptops'
	String get tierLaptopLarge => 'Large laptops';

	/// en: 'Tablets and laptops'
	String get tierTablet => 'Tablets and laptops';

	/// en: 'Phones'
	String get tierPhone => 'Phones';

	/// en: 'Small phones'
	String get tierSmallPhone => 'Small phones';

	/// en: 'Calls and audio'
	String get tierCalls => 'Calls and audio';

	/// en: 'Messaging only'
	String get messagingOnly => 'Messaging only';

	/// en: 'Video quality'
	String get videoQuality => 'Video quality';

	/// en: 'PREVIEW'
	String get preview => 'PREVIEW';

	/// en: 'History'
	String get history => 'History';

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'via VPN'
	String get viaVpnLower => 'via VPN';

	/// en: 'direct'
	String get directLower => 'direct';

	/// en: 'Several 4K streams and video calls at once'
	String get gradeA => 'Several 4K streams and video calls at once';

	/// en: 'HD streaming and smooth video calls'
	String get gradeB => 'HD streaming and smooth video calls';

	/// en: 'One HD stream; calls may stutter at busy times'
	String get gradeC => 'One HD stream; calls may stutter at busy times';

	/// en: 'Browsing and messaging; video struggles'
	String get gradeD => 'Browsing and messaging; video struggles';

	/// en: 'your country'
	String get yourCountry => 'your country';

	/// en: 'Median download, last 30 days'
	String get median => 'Median download, last 30 days';

	/// en: 'Mbps · from G VPN users' tests'
	String get fromUsers => 'Mbps · from G VPN users\' tests';

	/// en: 'Little speed lost to the VPN'
	String get costLittle => 'Little speed lost to the VPN';

	/// en: 'Noticeably slower than direct'
	String get costNoticeable => 'Noticeably slower than direct';

	/// en: 'Much slower. Try another server'
	String get costMuch => 'Much slower. Try another server';

	/// en: 'of your direct speed'
	String get ofDirect => 'of your direct speed';

	/// en: 'none'
	String get none => 'none';

	/// en: '{n} ms'
	String ms({required Object n}) => '${n} ms';

	/// en: 'PREVIEW · {tier}'
	String previewTier({required Object tier}) => 'PREVIEW · ${tier}';

	/// en: 'Streams up to {tier} · {who}'
	String streamsUpTo({required Object tier, required Object who}) => 'Streams up to ${tier} · ${who}';

	/// en: 'Today, {time}'
	String today({required Object time}) => 'Today, ${time}';

	/// en: '{n} tests'
	String tests({required Object n}) => '${n} tests';

	/// en: '{label} through the VPN'
	String gradeVpn({required Object label}) => '${label} through the VPN';

	/// en: '{label} on {isp}'
	String gradeIsp({required Object label, required Object isp}) => '${label} on ${isp}';

	/// en: 'Not enough tests yet for {isp}'
	String notEnough({required Object isp}) => 'Not enough tests yet for ${isp}';

	/// en: 'your provider'
	String get yourProvider => 'your provider';

	/// en: '{isp} in {where}: {rank} of {of}'
	String rankLine({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} in ${where}: ${rank} of ${of}';

	/// en: '{note} · direct {mbps} Mbps'
	String costLine({required Object note, required Object mbps}) => '${note} · direct ${mbps} Mbps';

	/// en: '{v} Mbps'
	String mbpsValue({required Object v}) => '${v} Mbps';

	/// en: 'Excellent'
	String get gradeExcellent => 'Excellent';

	/// en: 'Very good'
	String get gradeVeryGood => 'Very good';

	/// en: 'Good'
	String get gradeGood => 'Good';

	/// en: 'Fair'
	String get gradeFair => 'Fair';

	/// en: 'Slow'
	String get gradeSlow => 'Slow';

	/// en: 'Very slow'
	String get gradeVerySlow => 'Very slow';
}

// Path: router
class Translations$router$en {
	Translations$router$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Asks your router, over UPnP, whether devices may open ports to the internet on their own, and lists any they have opened. It only reads and changes nothing. If nothing needs UPnP (some game consoles do), turning it off in the router settings is safer.'
	String get info => 'Asks your router, over UPnP, whether devices may open ports to the internet on their own, and lists any they have opened. It only reads and changes nothing. If nothing needs UPnP (some game consoles do), turning it off in the router settings is safer.';

	/// en: 'Router check'
	String get title => 'Router check';

	/// en: 'Asking the router'
	String get asking => 'Asking the router';

	/// en: 'Check again'
	String get again => 'Check again';

	/// en: 'Check router'
	String get check => 'Check router';

	/// en: 'UPnP is off'
	String get off => 'UPnP is off';

	/// en: 'Devices cannot open ports by themselves.'
	String get offBody => 'Devices cannot open ports by themselves.';

	/// en: 'No ports open through it right now.'
	String get onBody => 'No ports open through it right now.';

	/// en: 'Check you recognise each one.'
	String get checkEach => 'Check you recognise each one.';

	/// en: 'Shared provider address: not reachable from the internet.'
	String get cgnat => 'Shared provider address: not reachable from the internet.';

	/// en: 'No description'
	String get noDescription => 'No description';

	/// en: '{n} ports opened by devices'
	String opened({required Object n}) => '${n} ports opened by devices';

	/// en: '{proto} to {host}'
	String mapping({required Object proto, required Object host}) => '${proto} to ${host}';

	/// en: 'UPnP is on'
	String get upnpOn => 'UPnP is on';

	/// en: 'Router'
	String get routerLabel => 'Router';

	/// en: 'Internet address'
	String get internetAddress => 'Internet address';

	/// en: 'Opened by devices'
	String get openedBy => 'Opened by devices';
}

// Path: network
class Translations$network$en {
	Translations$network$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'This network'
	String get title => 'This network';

	/// en: 'Wi-Fi'
	String get wifi => 'Wi-Fi';

	/// en: 'Mobile data'
	String get mobile => 'Mobile data';

	/// en: 'Ethernet'
	String get ethernet => 'Ethernet';

	/// en: 'Offline'
	String get offline => 'Offline';

	/// en: 'Risky network. Connect the VPN here.'
	String get risky => 'Risky network. Connect the VPN here.';

	/// en: 'Worth a look before you trust it.'
	String get review => 'Worth a look before you trust it.';

	/// en: 'Covered by the VPN.'
	String get covered => 'Covered by the VPN.';

	/// en: 'This network looks safe.'
	String get safe => 'This network looks safe.';

	/// en: 'Mobile data.'
	String get mobileSentence => 'Mobile data.';

	/// en: 'Not connected.'
	String get notConnected => 'Not connected.';

	/// en: 'Show name'
	String get showName => 'Show name';

	/// en: 'Sites see'
	String get sitesSee => 'Sites see';

	/// en: 'Provider'
	String get provider => 'Provider';

	/// en: 'Location'
	String get location => 'Location';

	/// en: 'Could not check'
	String get couldNotCheck => 'Could not check';

	/// en: 'Checking'
	String get checking => 'Checking';

	/// en: 'Signal'
	String get signal => 'Signal';

	/// en: 'Link speed'
	String get linkSpeed => 'Link speed';

	/// en: 'Gateway'
	String get gateway => 'Gateway';

	/// en: 'None'
	String get none => 'None';

	/// en: 'Private DNS'
	String get privateDns => 'Private DNS';

	/// en: 'Automatic'
	String get automatic => 'Automatic';

	/// en: 'Off'
	String get off => 'Off';

	/// en: 'Metered'
	String get metered => 'Metered';

	/// en: 'Yes'
	String get yes => 'Yes';

	/// en: 'No'
	String get no => 'No';

	/// en: 'Could not read the network: {error}'
	String readFailed({required Object error}) => 'Could not read the network: ${error}';
}

// Path: devices
class Translations$devices$en {
	Translations$devices$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Knocks on every address in your Wi-Fi's range and asks devices to announce themselves. A device that refuses still counts: a refusal proves it is there. Names: from what devices publish (Bonjour, UPnP, Windows names) and from your router. Unknown devices: Android hides hardware addresses from apps, so a silent device with no announced name cannot be identified. Check your router's device list for those. New: a device not seen in your last scan of this network.'
	String get info => 'Knocks on every address in your Wi-Fi\'s range and asks devices to announce themselves. A device that refuses still counts: a refusal proves it is there.\n\nNames: from what devices publish (Bonjour, UPnP, Windows names) and from your router.\n\nUnknown devices: Android hides hardware addresses from apps, so a silent device with no announced name cannot be identified. Check your router\'s device list for those.\n\nNew: a device not seen in your last scan of this network.';

	/// en: 'Connect to a Wi-Fi network first.'
	String get needWifi => 'Connect to a Wi-Fi network first.';

	/// en: 'Devices'
	String get title => 'Devices';

	/// en: 'Scan again'
	String get again => 'Scan again';

	/// en: 'Looking for devices'
	String get looking => 'Looking for devices';

	/// en: 'All'
	String get all => 'All';

	/// en: 'Phones'
	String get phones => 'Phones';

	/// en: 'TVs'
	String get tvs => 'TVs';

	/// en: 'Computers'
	String get computers => 'Computers';

	/// en: 'Other'
	String get other => 'Other';

	/// en: 'This phone'
	String get thisPhone => 'This phone';

	/// en: 'Router'
	String get router => 'Router';

	/// en: 'Unknown device'
	String get unknown => 'Unknown device';

	/// en: 'Address'
	String get address => 'Address';

	/// en: 'Answers in'
	String get answersIn => 'Answers in';

	/// en: 'Type'
	String get type => 'Type';

	/// en: 'NEW'
	String get newBadge => 'NEW';

	/// en: 'Scanning {n} of 254'
	String scanning({required Object n}) => 'Scanning ${n} of 254';

	/// en: '{n} new since the last scan'
	String newSince({required Object n}) => '${n} new since the last scan';

	/// en: '{n} ms'
	String ms({required Object n}) => '${n} ms';

	/// en: 'Cameras'
	String get cameras => 'Cameras';

	/// en: 'Device'
	String get device => 'Device';

	/// en: 'Online'
	String get online => 'Online';

	/// en: 'Model'
	String get model => 'Model';

	/// en: 'Announces itself as'
	String get announced => 'Announces itself as';

	/// en: 'OPEN SERVICES'
	String get services => 'OPEN SERVICES';

	/// en: 'Checking services'
	String get checkingServices => 'Checking services';

	/// en: 'No common services answer'
	String get noServices => 'No common services answer';

	/// en: 'Rename'
	String get rename => 'Rename';

	/// en: 'Save'
	String get save => 'Save';

	late final Translations$devices$kinds$en kinds = Translations$devices$kinds$en.internal(_root);

	/// en: 'Network details'
	String get details => 'Network details';

	/// en: 'List'
	String get listView => 'List';

	/// en: 'Mesh'
	String get meshView => 'Mesh';

	/// en: 'Offline'
	String get offlineHeading => 'Offline';

	/// en: 'Seen {when}'
	String seen({required Object when}) => 'Seen ${when}';

	/// en: '{n} min ago'
	String agoMinutes({required Object n}) => '${n} min ago';

	/// en: '{n} h ago'
	String agoHours({required Object n}) => '${n} h ago';

	/// en: '{n} d ago'
	String agoDays({required Object n}) => '${n} d ago';

	/// en: 'Through the VPN'
	String get throughVpn => 'Through the VPN';

	/// en: 'Closer = answers faster'
	String get closer => 'Closer = answers faster';

	/// en: 'Is this yours?'
	String get yours => 'Is this yours?';

	/// en: 'Mine'
	String get mine => 'Mine';

	/// en: 'Not mine'
	String get notMine => 'Not mine';

	/// en: 'What is it?'
	String get whatIsIt => 'What is it?';

	/// en: 'Our guess: {kind}'
	String ourGuess({required Object kind}) => 'Our guess: ${kind}';

	/// en: 'Phones and computers'
	String get groupPersonal => 'Phones and computers';

	/// en: 'Home and media'
	String get groupHome => 'Home and media';

	/// en: 'Network and smart home'
	String get groupNetwork => 'Network and smart home';

	/// en: '(one) {{n} online} (other) {{n} online}'
	String onlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} online',
		other: '${n} online',
	);

	/// en: '(one) {{n} offline} (other) {{n} offline}'
	String offlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} offline',
		other: '${n} offline',
	);

	/// en: '(one) {{n} to confirm} (other) {{n} to confirm}'
	String toConfirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} to confirm',
		other: '${n} to confirm',
	);
}

// Path: ping
class Translations$ping$en {
	Translations$ping$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Ping a host'
	String get askTitle => 'Ping a host';

	/// en: 'example.com or 192.168.1.10'
	String get askHint => 'example.com or 192.168.1.10';

	/// en: 'Ping'
	String get title => 'Ping';

	/// en: 'Router'
	String get router => 'Router';

	/// en: 'Pause'
	String get pause => 'Pause';

	/// en: 'Start'
	String get start => 'Start';

	/// en: 'Host'
	String get host => 'Host';

	/// en: 'Live'
	String get live => 'Live';

	/// en: '60 s ago'
	String get ago => '60 s ago';

	/// en: 'MIN'
	String get min => 'MIN';

	/// en: 'AVG'
	String get avg => 'AVG';

	/// en: 'JITTER'
	String get jitter => 'JITTER';

	/// en: 'LOSS'
	String get loss => 'LOSS';

	/// en: 'Good enough for'
	String get goodFor => 'Good enough for';

	/// en: 'Video calls'
	String get calls => 'Video calls';

	/// en: 'Online games'
	String get games => 'Online games';

	/// en: 'Streaming'
	String get streaming => 'Streaming';

	/// en: 'Great'
	String get great => 'Great';

	/// en: 'Okay'
	String get okay => 'Okay';

	/// en: 'Poor'
	String get poor => 'Poor';

	/// en: 'lost'
	String get lost => 'lost';

	/// en: 'now'
	String get now => 'now';
}

// Path: status
class Translations$status$en {
	Translations$status$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Connects to each service three times and shows the fastest answer. Blocked here: a service that does not answer directly but works through the VPN is blocked by your network or country. History: the last 24 hours of checks from this phone, kept only on this phone.'
	String get info => 'Connects to each service three times and shows the fastest answer.\n\nBlocked here: a service that does not answer directly but works through the VPN is blocked by your network or country.\n\nHistory: the last 24 hours of checks from this phone, kept only on this phone.';

	/// en: 'Service status'
	String get title => 'Service status';

	/// en: 'Checking'
	String get checking => 'Checking';

	/// en: 'Check again'
	String get again => 'Check again';

	/// en: 'Checked through the VPN'
	String get viaVpn => 'Checked through the VPN';

	/// en: 'Checked directly'
	String get direct => 'Checked directly';

	/// en: 'Favourites'
	String get favourites => 'Favourites';

	/// en: 'Edit'
	String get edit => 'Edit';

	/// en: 'Last 24 hours'
	String get last24 => 'Last 24 hours';

	/// en: '24 h ago'
	String get ago => '24 h ago';

	/// en: 'All services'
	String get all => 'All services';

	/// en: 'Pick up to four'
	String get pickFour => 'Pick up to four';

	/// en: 'Even through the VPN: likely an outage'
	String get outage => 'Even through the VPN: likely an outage';

	/// en: 'May be blocked on this network'
	String get blocked => 'May be blocked on this network';

	/// en: 'Connect'
	String get connect => 'Connect';

	/// en: 'Blocked'
	String get blockedShort => 'Blocked';

	/// en: 'now'
	String get now => 'now';

	/// en: '{n} checks'
	String checks({required Object n}) => '${n} checks';

	/// en: '{first} and {n} more'
	String andMore({required Object first, required Object n}) => '${first} and ${n} more';

	/// en: '{who} not reachable'
	String notReachable({required Object who}) => '${who} not reachable';
}

// Path: tools
class Translations$tools$en {
	Translations$tools$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Wi-Fi'
	String get wifi => 'Wi-Fi';

	/// en: 'Mobile data'
	String get mobile => 'Mobile data';

	/// en: 'Ethernet'
	String get ethernet => 'Ethernet';

	/// en: 'Checking'
	String get checking => 'Checking';

	/// en: 'Offline'
	String get offline => 'Offline';

	/// en: 'Tools'
	String get title => 'Tools';

	/// en: 'Safety check, what sites see, signal, router and DNS.'
	String get networkDesc => 'Safety check, what sites see, signal, router and DNS.';

	/// en: 'Internet'
	String get internet => 'Internet';

	/// en: 'Speed test'
	String get speed => 'Speed test';

	/// en: 'Download, upload and video quality'
	String get speedDesc => 'Download, upload and video quality';

	/// en: 'Ping'
	String get ping => 'Ping';

	/// en: 'Live response time and jitter'
	String get pingDesc => 'Live response time and jitter';

	/// en: 'Service status'
	String get status => 'Service status';

	/// en: 'Is an app reachable or blocked here?'
	String get statusDesc => 'Is an app reachable or blocked here?';

	/// en: 'Traceroute'
	String get trace => 'Traceroute';

	/// en: 'Every stop on the way to a site'
	String get traceDesc => 'Every stop on the way to a site';

	/// en: 'This network'
	String get security => 'This network';

	/// en: 'Devices on this network'
	String get devices => 'Devices on this network';

	/// en: 'Who is on your Wi-Fi'
	String get devicesDesc => 'Who is on your Wi-Fi';

	/// en: 'Router check'
	String get router => 'Router check';

	/// en: 'Ports your devices opened'
	String get routerDesc => 'Ports your devices opened';

	/// en: 'Open ports'
	String get ports => 'Open ports';

	/// en: 'Risky ports on a device or server'
	String get portsDesc => 'Risky ports on a device or server';

	/// en: 'Utilities'
	String get utilities => 'Utilities';

	/// en: 'Wi-Fi scanner'
	String get wifiScanner => 'Wi-Fi scanner';

	/// en: 'Networks around you and the clearest channel'
	String get wifiDesc => 'Networks around you and the clearest channel';

	/// en: 'Wake on LAN'
	String get wol => 'Wake on LAN';

	/// en: 'Turn on a computer on this network'
	String get wolDesc => 'Turn on a computer on this network';

	/// en: 'Password check'
	String get passwordCheck => 'Password check';

	/// en: 'Has it been leaked?'
	String get passwordCheckDesc => 'Has it been leaked?';

	/// en: 'Link check'
	String get linkCheck => 'Link check';

	/// en: 'Is it safe to open?'
	String get linkCheckDesc => 'Is it safe to open?';

	/// en: 'Data breaches'
	String get breaches => 'Data breaches';

	/// en: 'What leaked lately'
	String get breachesDesc => 'What leaked lately';

	/// en: 'What's blocked'
	String get blocked => 'What\'s blocked';

	/// en: 'Sites blocked on this network'
	String get blockedDesc => 'Sites blocked on this network';
}

// Path: trace
class Translations$trace$en {
	Translations$trace$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Each stop is one router your traffic passes through on the way to the site. Silent hops: many routers never answer these probes. That is normal and not a fault. With the VPN on: the path starts inside the tunnel, so your own network and provider are hidden. How: it uses Android's own ping tool with a hop limit, since apps cannot send these packets directly.'
	String get info => 'Each stop is one router your traffic passes through on the way to the site.\n\nSilent hops: many routers never answer these probes. That is normal and not a fault.\n\nWith the VPN on: the path starts inside the tunnel, so your own network and provider are hidden.\n\nHow: it uses Android\'s own ping tool with a hop limit, since apps cannot send these packets directly.';

	/// en: 'Traceroute'
	String get title => 'Traceroute';

	/// en: 'Stop'
	String get stop => 'Stop';

	/// en: 'Trace'
	String get trace => 'Trace';

	/// en: 'Trace again'
	String get again => 'Trace again';

	/// en: 'Destination'
	String get destination => 'Destination';

	/// en: 'HOPS'
	String get hops => 'HOPS';

	/// en: 'ANSWERED'
	String get answered => 'ANSWERED';

	/// en: 'TOTAL'
	String get total => 'TOTAL';

	/// en: 'This phone'
	String get thisPhone => 'This phone';

	/// en: '1 silent hop'
	String get silentOne => '1 silent hop';

	/// en: 'Your router'
	String get yourRouter => 'Your router';

	/// en: '{n} ms'
	String ms({required Object n}) => '${n} ms';

	/// en: '{n} silent hops'
	String silentMany({required Object n}) => '${n} silent hops';

	/// en: 'Hop {n}'
	String hop({required Object n}) => 'Hop ${n}';

	/// en: 'Most of the delay, {ms} ms, is added at hop {hop}: usually a long cable between countries, or a busy link.'
	String slowest({required Object ms, required Object hop}) => 'Most of the delay, ${ms} ms, is added at hop ${hop}: usually a long cable between countries, or a busy link.';

	/// en: 'POPULAR'
	String get popular => 'POPULAR';

	/// en: 'RECENT'
	String get recent => 'RECENT';

	/// en: 'Clear recent'
	String get clearRecent => 'Clear recent';

	/// en: '(one) {{n} hop} (other) {{n} hops}'
	String hopsCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} hop',
		other: '${n} hops',
	);
}

// Path: ports
class Translations$ports$en {
	Translations$ports$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sends passwords unencrypted.'
	String get ftpNote => 'Sends passwords unencrypted.';

	/// en: 'Remote login. Fine if you set it up.'
	String get sshNote => 'Remote login. Fine if you set it up.';

	/// en: 'Unencrypted remote login; a favourite of botnets.'
	String get telnetNote => 'Unencrypted remote login; a favourite of botnets.';

	/// en: 'Normal on a router.'
	String get dnsNote => 'Normal on a router.';

	/// en: 'Web (HTTP)'
	String get web => 'Web (HTTP)';

	/// en: 'Usually the router admin page.'
	String get webNote => 'Usually the router admin page.';

	/// en: 'Web (HTTPS)'
	String get webTls => 'Web (HTTPS)';

	/// en: 'Windows file sharing'
	String get smb => 'Windows file sharing';

	/// en: 'Should never face the internet.'
	String get smbNote => 'Should never face the internet.';

	/// en: 'RTSP camera stream'
	String get rtsp => 'RTSP camera stream';

	/// en: 'A camera may be streaming here.'
	String get rtspNote => 'A camera may be streaming here.';

	/// en: 'Lets devices open router ports on their own.'
	String get upnpNote => 'Lets devices open router ports on their own.';

	/// en: 'Remote Desktop'
	String get rdp => 'Remote Desktop';

	/// en: 'A common break-in route.'
	String get rdpNote => 'A common break-in route.';

	/// en: 'Screen sharing, often without a password.'
	String get vncNote => 'Screen sharing, often without a password.';

	/// en: 'ISP remote management.'
	String get tr069Note => 'ISP remote management.';

	/// en: 'Web (alt)'
	String get webAlt => 'Web (alt)';

	/// en: 'Web (alt HTTPS)'
	String get webAltTls => 'Web (alt HTTPS)';

	/// en: 'Open ports'
	String get title => 'Open ports';

	/// en: 'Check ports'
	String get check => 'Check ports';

	/// en: 'Device or server address'
	String get address => 'Device or server address';

	/// en: 'RISKY'
	String get risky => 'RISKY';

	/// en: 'REVIEW'
	String get review => 'REVIEW';

	/// en: 'NORMAL'
	String get normal => 'NORMAL';

	/// en: 'Checks the {n} ports that matter on home routers and devices, and explains each open one. Only check devices and servers you own or manage.'
	String info({required Object n}) => 'Checks the ${n} ports that matter on home routers and devices, and explains each open one.\n\nOnly check devices and servers you own or manage.';

	/// en: 'Checking {n} ports'
	String checking({required Object n}) => 'Checking ${n} ports';

	/// en: 'Your router is {ip}'
	String yourRouter({required Object ip}) => 'Your router is ${ip}';

	/// en: 'No common ports open on {host}.'
	String noneOpen({required Object host}) => 'No common ports open on ${host}.';

	/// en: '{open} open of {n} checked'
	String summary({required Object open, required Object n}) => '${open} open of ${n} checked';

	/// en: '(one) {{n} risky} (other) {{n} risky}'
	String riskyCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} risky',
		other: '${n} risky',
	);

	/// en: 'Nothing risky'
	String get noneRisky => 'Nothing risky';
}

// Path: wifi
class Translations$wifi$en {
	Translations$wifi$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Wi-Fi scanner'
	String get title => 'Wi-Fi scanner';

	/// en: 'Allow Wi-Fi scanning'
	String get allow => 'Allow Wi-Fi scanning';

	/// en: 'Needs location permission.'
	String get needsPermission => 'Needs location permission.';

	/// en: 'Scanning'
	String get scanning => 'Scanning';

	/// en: 'Scan again'
	String get again => 'Scan again';

	/// en: 'Scan failed'
	String get failed => 'Scan failed';

	/// en: 'No networks found. Location services may be off.'
	String get none => 'No networks found. Location services may be off.';

	/// en: 'Hidden network'
	String get hidden => 'Hidden network';

	/// en: '{n} networks nearby'
	String nearby({required Object n}) => '${n} networks nearby';

	/// en: 'Android only shows nearby Wi-Fi networks to apps with location permission. G VPN uses it to list networks on this phone and nothing else.'
	String get permissionInfo => 'Android only shows nearby Wi-Fi networks to apps with location permission. G VPN uses it to list networks on this phone and nothing else.';

	/// en: 'Lists networks from the phone's last scan. Android allows only a few scans a minute, so a quick re-scan may show the same list. The suggested channel is the least crowded of 1, 6 and 11, the three that do not overlap.'
	String get info => 'Lists networks from the phone\'s last scan. Android allows only a few scans a minute, so a quick re-scan may show the same list. The suggested channel is the least crowded of 1, 6 and 11, the three that do not overlap.';

	/// en: 'Air map'
	String get airMap => 'Air map';

	/// en: 'Channels'
	String get channels => 'Channels';

	/// en: 'List'
	String get list => 'List';

	/// en: 'Secure'
	String get secure => 'Secure';

	/// en: 'Weak'
	String get weakLabel => 'Weak';

	/// en: 'Open'
	String get openLabel => 'Open';

	/// en: 'Size = channel width'
	String get sizeIsWidth => 'Size = channel width';

	/// en: 'STRONGEST'
	String get strongest => 'STRONGEST';

	/// en: 'OPEN NEARBY'
	String get openNearby => 'OPEN NEARBY';

	/// en: 'ON YOUR CHANNEL'
	String get onYourChannel => 'ON YOUR CHANNEL';

	/// en: 'None'
	String get noneNearby => 'None';

	/// en: 'Anyone nearby can read what is sent'
	String get verdictOpen => 'Anyone nearby can read what is sent';

	/// en: 'Old security, easy to break'
	String get verdictWep => 'Old security, easy to break';

	/// en: 'Older security'
	String get verdictWpa => 'Older security';

	/// en: 'WPS is on: easier to break into'
	String get verdictWps => 'WPS is on: easier to break into';

	/// en: 'Well protected'
	String get verdictGood => 'Well protected';

	/// en: 'Maker'
	String get maker => 'Maker';

	/// en: 'Hardware address'
	String get address => 'Hardware address';

	/// en: 'Made up by the router for privacy'
	String get privateAddress => 'Made up by the router for privacy';

	/// en: 'You'
	String get you => 'You';

	/// en: '{name} is on a clear channel'
	String onClear({required Object name}) => '${name} is on a clear channel';

	/// en: 'Move {name} to channel {n}'
	String move({required Object name, required Object n}) => 'Move ${name} to channel ${n}';

	/// en: 'Clear'
	String get clear => 'Clear';

	/// en: 'Busy'
	String get busy => 'Busy';

	/// en: 'Crowded'
	String get crowded => 'Crowded';

	/// en: 'All bands'
	String get allBands => 'All bands';

	/// en: 'Open only'
	String get openOnly => 'Open only';

	/// en: '(one) {{n} network} (other) {{n} networks}'
	String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} network',
		other: '${n} networks',
	);
}

// Path: errors
class Translations$errors$en {
	Translations$errors$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'VPN permission was not granted.'
	String get notAuthorized => 'VPN permission was not granted.';

	/// en: 'The VPN was turned off by the system or another app.'
	String get turnedOff => 'The VPN was turned off by the system or another app.';

	/// en: 'A permission request is already open.'
	String get busy => 'A permission request is already open.';

	/// en: 'Connection cancelled.'
	String get cancelled => 'Connection cancelled.';

	/// en: 'This server config is invalid: {error}'
	String badConfig({required Object error}) => 'This server config is invalid: ${error}';

	/// en: 'The server did not answer.'
	String get timeout => 'The server did not answer.';

	/// en: 'The server refused the connection.'
	String get refused => 'The server refused the connection.';

	/// en: 'Could not connect: {error}'
	String failed({required Object error}) => 'Could not connect: ${error}';

	/// en: 'Community servers come and go; try another one.'
	String get tryAnother => 'Community servers come and go; try another one.';

	/// en: 'Could not download this server's settings. Check your connection, or pick another server.'
	String get downloadFailed => 'Could not download this server\'s settings. Check your connection, or pick another server.';
}

// Path: scan
class Translations$scan$en {
	Translations$scan$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Mobile data'
	String get mobile => 'Mobile data';

	/// en: 'PING'
	String get ping => 'PING';

	/// en: 'No reply'
	String get noReply => 'No reply';

	/// en: 'DNS'
	String get dns => 'DNS';

	/// en: 'Quad9, tunnel'
	String get dnsQuad9 => 'Quad9, tunnel';

	/// en: 'In the tunnel'
	String get dnsTunnel => 'In the tunnel';

	/// en: 'Private DNS'
	String get privateDns => 'Private DNS';

	/// en: 'ISP: Visible'
	String get dnsIsp => 'ISP: Visible';

	/// en: 'NETWORK'
	String get network => 'NETWORK';

	/// en: 'Offline'
	String get offline => 'Offline';

	/// en: 'Open, no password'
	String get open => 'Open, no password';

	/// en: 'WEP, broken'
	String get wep => 'WEP, broken';

	/// en: 'Open, encrypted'
	String get owe => 'Open, encrypted';

	/// en: 'Enterprise'
	String get enterprise => 'Enterprise';

	/// en: 'Unknown'
	String get unknown => 'Unknown';

	/// en: 'WI-FI'
	String get wifi => 'WI-FI';

	/// en: 'Sign-in page'
	String get signIn => 'Sign-in page';

	/// en: '{n} ms'
	String ms({required Object n}) => '${n} ms';

	/// en: '{what}, covered'
	String covered({required Object what}) => '${what}, covered';
}

// Path: legal
class Translations$legal$en {
	Translations$legal$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Privacy policy'
	String get privacy => 'Privacy policy';

	/// en: 'Terms of use'
	String get terms => 'Terms of use';

	/// en: 'Open-source licences'
	String get licences => 'Open-source licences';
}

// Path: update
class Translations$update$en {
	Translations$update$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'An update is ready'
	String get ready => 'An update is ready';

	/// en: 'Restart'
	String get restart => 'Restart';
}

// Path: details
class Translations$details$en {
	Translations$details$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Share'
	String get share => 'Share';

	/// en: 'CONNECTED · {n} MIN'
	String connectedFor({required Object n}) => 'CONNECTED · ${n} MIN';

	/// en: 'NOT CONNECTED'
	String get notConnected => 'NOT CONNECTED';

	/// en: 'DOWNLOADED'
	String get downloaded => 'DOWNLOADED';

	/// en: 'UPLOADED'
	String get uploaded => 'UPLOADED';

	/// en: 'LAST USED'
	String get lastUsed => 'LAST USED';

	/// en: 'Connection'
	String get connection => 'Connection';

	/// en: 'Protocol'
	String get protocol => 'Protocol';

	/// en: 'Your address'
	String get address => 'Your address';

	/// en: 'DNS'
	String get dns => 'DNS';

	/// en: 'Routes'
	String get routes => 'Routes';

	/// en: 'All traffic'
	String get allTraffic => 'All traffic';

	/// en: '{n} networks'
	String someRoutes({required Object n}) => '${n} networks';

	/// en: 'Keepalive'
	String get keepalive => 'Keepalive';

	/// en: 'Server key'
	String get serverKey => 'Server key';

	/// en: 'Copy'
	String get copy => 'Copy';

	/// en: 'Copied'
	String get copied => 'Copied';

	/// en: 'Manage'
	String get manage => 'Manage';

	/// en: 'Export for backup'
	String get export => 'Export for backup';

	/// en: 'All your servers in one file'
	String get exportSub => 'All your servers in one file';
}

// Path: share
class Translations$share$en {
	Translations$share$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Share {name}'
	String title({required Object name}) => 'Share ${name}';

	/// en: 'This shares this phone's key. Anyone with it can use your server as you, and only one device can be connected with it at a time.'
	String get sameKey => 'This shares this phone\'s key. Anyone with it can use your server as you, and only one device can be connected with it at a time.';

	/// en: 'On the other phone: G VPN, Servers, Scan QR. A saved image works too.'
	String get scanHint => 'On the other phone: G VPN, Servers, Scan QR. A saved image works too.';

	/// en: 'Save image'
	String get saveImage => 'Save image';

	/// en: 'Send'
	String get send => 'Send';
}

// Path: add
class Translations$add$en {
	Translations$add$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Add a server'
	String get title => 'Add a server';

	/// en: 'Any WireGuard server: a router, a VPS or a home server.'
	String get subtitle => 'Any WireGuard server: a router, a VPS or a home server.';

	/// en: 'Scan with camera'
	String get camera => 'Scan with camera';

	/// en: 'QR on another screen'
	String get cameraSub => 'QR on another screen';

	/// en: 'From an image'
	String get image => 'From an image';

	/// en: 'Screenshot or saved photo'
	String get imageSub => 'Screenshot or saved photo';

	/// en: 'No QR code found in that image.'
	String get noQr => 'No QR code found in that image.';

	/// en: 'Got the QR in WhatsApp or Telegram? Tap Share on the image and choose G VPN.'
	String get tip => 'Got the QR in WhatsApp or Telegram? Tap Share on the image and choose G VPN.';
}

// Path: backup
class Translations$backup$en {
	Translations$backup$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: '{n} servers restored'
	String restored({required Object n}) => '${n} servers restored';

	/// en: 'These servers are already here'
	String get nothingNew => 'These servers are already here';
}

// Path: gs
class Translations$gs$en {
	Translations$gs$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'G Servers are for G VPN Pro subscribers.'
	String get proRequired => 'G Servers are for G VPN Pro subscribers.';

	/// en: 'G Servers are switched off right now.'
	String get off => 'G Servers are switched off right now.';

	/// en: 'Could not reach G Servers. Check your connection and try again.'
	String get network => 'Could not reach G Servers. Check your connection and try again.';

	/// en: 'ACTIVE'
	String get active => 'ACTIVE';

	/// en: 'G Servers'
	String get servers => 'G Servers';

	/// en: '{n}% busy'
	String busy({required Object n}) => '${n}% busy';

	/// en: 'Offline'
	String get offline => 'Offline';

	/// en: 'Your devices'
	String get devices => 'Your devices';

	/// en: 'G Server · {country} · WireGuard'
	String subtitle({required Object country}) => 'G Server · ${country} · WireGuard';

	/// en: 'BUSY'
	String get busyLabel => 'BUSY';

	/// en: 'STATUS'
	String get status => 'STATUS';

	/// en: 'Online'
	String get online => 'Online';

	/// en: 'On this server'
	String get onThisServer => 'On this server';

	/// en: 'This phone'
	String get thisPhone => 'This phone';

	/// en: 'Added · key made here'
	String get added => 'Added · key made here';

	/// en: 'Added when you connect'
	String get notAdded => 'Added when you connect';

	/// en: 'Activity logs'
	String get logs => 'Activity logs';

	/// en: 'None kept'
	String get noneKept => 'None kept';

	/// en: 'The server knows this phone only by its public key. It keeps no record of the sites you visit or the traffic you send.'
	String get privacy => 'The server knows this phone only by its public key. It keeps no record of the sites you visit or the traffic you send.';

	/// en: 'Install G VPN on the phone, signed in to the same Google account.'
	String get stepPro1 => 'Install G VPN on the phone, signed in to the same Google account.';

	/// en: 'Open the Pro tab. Pro unlocks by itself, or tap Restore.'
	String get stepPro2 => 'Open the Pro tab. Pro unlocks by itself, or tap Restore.';

	/// en: 'Tap Connect. The phone makes its key and is added to G Servers. No QR, no code.'
	String get step3 => 'Tap Connect. The phone makes its key and is added to G Servers. No QR, no code.';

	/// en: 'Install G VPN on the phone.'
	String get stepFree1 => 'Install G VPN on the phone.';

	/// en: 'Open the Pro tab.'
	String get stepFree2 => 'Open the Pro tab.';

	/// en: 'Pro follows your Google account. Each phone has its own key, so they never knock each other off.'
	String get devicesIntroPro => 'Pro follows your Google account. Each phone has its own key, so they never knock each other off.';

	/// en: 'Each phone has its own key, so phones never knock each other off.'
	String get devicesIntroFree => 'Each phone has its own key, so phones never knock each other off.';

	/// en: 'Another phone'
	String get otherPhone => 'Another phone';

	/// en: 'Last connected {when}'
	String lastConnected({required Object when}) => 'Last connected ${when}';

	/// en: 'Connect to a G Server once and your phones appear here.'
	String get noDevices => 'Connect to a G Server once and your phones appear here.';

	/// en: 'Add a phone or reinstall'
	String get addTitle => 'Add a phone or reinstall';

	/// en: 'A phone that has not connected for {n} days is removed from G Servers by itself, so an old or reinstalled phone never uses up a place.'
	String idle({required Object n}) => 'A phone that has not connected for ${n} days is removed from G Servers by itself, so an old or reinstalled phone never uses up a place.';

	/// en: 'Up to {n} phones per plan.'
	String limitNote({required Object n}) => 'Up to ${n} phones per plan.';

	/// en: 'All {n} places are in use'
	String fullTitle({required Object n}) => 'All ${n} places are in use';

	/// en: 'Remove a phone you no longer use, and this one connects straight away.'
	String get fullBody => 'Remove a phone you no longer use, and this one connects straight away.';

	/// en: 'Too many new phones right now. Try again in a little while.'
	String get busyNow => 'Too many new phones right now. Try again in a little while.';

	/// en: 'This server is full. Try another G Server.'
	String get serverFull => 'This server is full. Try another G Server.';

	/// en: 'PING'
	String get ping => 'PING';

	/// en: 'Busy, last 24 hours'
	String get last24 => 'Busy, last 24 hours';

	/// en: 'The chart fills in as the server is used over the day.'
	String get noHistory => 'The chart fills in as the server is used over the day.';

	/// en: 'Busy over the last 24 hours, at most {max} percent'
	String chartLabel({required Object max}) => 'Busy over the last 24 hours, at most ${max} percent';

	/// en: '24 h ago'
	String get hoursAgo => '24 h ago';

	/// en: 'Now'
	String get now => 'Now';

	/// en: 'Included'
	String get included => 'Included';

	/// en: 'Fast, private servers'
	String get perkServers => 'Fast, private servers';

	/// en: 'WireGuard, run by us, no activity logs'
	String get perkServersSub => 'WireGuard, run by us, no activity logs';

	/// en: 'Unlimited link checks'
	String get perkLinks => 'Unlimited link checks';

	/// en: 'Check every link you are sent'
	String get perkLinksSub => 'Check every link you are sent';

	/// en: 'Your devices · {used} of {limit}'
	String devicesOf({required Object used, required Object limit}) => 'Your devices · ${used} of ${limit}';

	/// en: 'Each phone has its own key'
	String get eachKey => 'Each phone has its own key';

	/// en: 'Connected'
	String get connected => 'Connected';

	/// en: 'BEST FOR YOU NOW'
	String get bestNow => 'BEST FOR YOU NOW';

	/// en: 'LOGS'
	String get logsShort => 'LOGS';
}

// Path: map
class Translations$map$en {
	Translations$map$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Open the map'
	String get open => 'Open the map';

	/// en: 'Search countries'
	String get searchCountries => 'Search countries';

	/// en: 'No country matches'
	String get noMatch => 'No country matches';

	/// en: 'My location'
	String get locate => 'My location';

	/// en: 'List'
	String get list => 'List';

	/// en: 'Map'
	String get map => 'Map';

	/// en: '(one) {{n} free server} (other) {{n} free servers}'
	String freeServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} free server',
		other: '${n} free servers',
	);

	late final Translations$map$grade$en grade = Translations$map$grade$en.internal(_root);

	/// en: 'Switch'
	String get switchTo => 'Switch';

	/// en: 'Free server {n}'
	String freeServer({required Object n}) => 'Free server ${n}';

	/// en: 'BEST'
	String get best => 'BEST';

	/// en: '(one) {{n} G Server} (other) {{n} G Servers}'
	String gServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} G Server',
		other: '${n} G Servers',
	);
}

// Path: stats
class Translations$stats$en {
	Translations$stats$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'This week'
	String get thisWeek => 'This week';

	/// en: 'Time'
	String get time => 'Time';

	/// en: 'Data'
	String get data => 'Data';

	/// en: 'protected'
	String get protected => 'protected';

	/// en: 'through the VPN'
	String get throughVpn => 'through the VPN';

	/// en: 'See details'
	String get seeDetails => 'See details';

	/// en: 'Stats'
	String get title => 'Stats';

	/// en: 'Week'
	String get week => 'Week';

	/// en: 'Month'
	String get month => 'Month';

	/// en: 'PROTECTED'
	String get protectedLabel => 'PROTECTED';

	/// en: 'DATA USED'
	String get dataUsed => 'DATA USED';

	/// en: 'BY SERVER'
	String get byServer => 'BY SERVER';

	/// en: 'Kept on this phone only'
	String get onPhone => 'Kept on this phone only';

	/// en: 'Reset'
	String get reset => 'Reset';

	/// en: 'Reset stats?'
	String get resetTitle => 'Reset stats?';

	/// en: 'Clears protected time and data on this phone. This cannot be undone.'
	String get resetBody => 'Clears protected time and data on this phone. This cannot be undone.';

	/// en: '{h} h {m} m'
	String hm({required Object h, required Object m}) => '${h} h ${m} m';

	/// en: '{m} m'
	String m({required Object m}) => '${m} m';

	/// en: 'Connect to start counting.'
	String get empty => 'Connect to start counting.';
}

// Path: recents
class Translations$recents$en {
	Translations$recents$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Recent'
	String get title => 'Recent';

	/// en: 'All servers'
	String get allServers => 'All servers';

	/// en: 'Free server'
	String get free => 'Free server';

	/// en: 'Your server'
	String get yours => 'Your server';

	/// en: 'G Server'
	String get gserver => 'G Server';
}

// Path: presets
class Translations$presets$en {
	Translations$presets$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Presets'
	String get title => 'Presets';

	/// en: 'All'
	String get all => 'All';

	/// en: 'New preset'
	String get newPreset => 'New preset';

	/// en: 'Edit preset'
	String get edit => 'Edit preset';

	/// en: 'Name'
	String get name => 'Name';

	/// en: 'My preset'
	String get namePlaceholder => 'My preset';

	/// en: 'SERVER'
	String get server => 'SERVER';

	/// en: 'Fastest'
	String get fastestOption => 'Fastest';

	/// en: 'Country'
	String get countryOption => 'Country';

	/// en: 'Pick a country'
	String get pickCountry => 'Pick a country';

	/// en: 'Skip my country'
	String get skipMyCountry => 'Skip my country';

	/// en: 'not my country'
	String get notMine => 'not my country';

	/// en: 'PROTOCOL'
	String get protocol => 'PROTOCOL';

	/// en: 'Auto'
	String get auto => 'Auto';

	/// en: 'If blocked, try the next server'
	String get tryNext => 'If blocked, try the next server';

	/// en: 'SHIELD'
	String get shield => 'SHIELD';

	/// en: 'As in Rules'
	String get followRules => 'As in Rules';

	/// en: 'Every app through the VPN'
	String get allApps => 'Every app through the VPN';

	/// en: 'all apps'
	String get allAppsShort => 'all apps';

	/// en: 'Save'
	String get save => 'Save';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Reset to default'
	String get reset => 'Reset to default';

	/// en: 'No free server fits this preset right now.'
	String get none => 'No free server fits this preset right now.';

	late final Translations$presets$names$en names = Translations$presets$names$en.internal(_root);
}

// Path: shield
class Translations$shield$en {
	Translations$shield$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Shield'
	String get title => 'Shield';

	/// en: 'Works while you are connected'
	String get sub => 'Works while you are connected';

	/// en: 'Off'
	String get off => 'Off';

	/// en: 'The server's own DNS'
	String get offSub => 'The server\'s own DNS';

	/// en: 'Malware'
	String get malware => 'Malware';

	/// en: 'Blocks harmful and phishing sites'
	String get malwareSub => 'Blocks harmful and phishing sites';

	/// en: 'Malware and adult sites'
	String get family => 'Malware and adult sites';

	/// en: 'Also blocks adult content'
	String get familySub => 'Also blocks adult content';

	/// en: 'Custom DNS'
	String get custom => 'Custom DNS';

	/// en: 'Your own DNS servers'
	String get customSub => 'Your own DNS servers';

	/// en: 'IP address, for example 1.1.1.1'
	String get customHint => 'IP address, for example 1.1.1.1';

	/// en: 'Enter one or two IP addresses.'
	String get invalid => 'Enter one or two IP addresses.';
}

// Path: checks
class Translations$checks$en {
	Translations$checks$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Safety checks'
	String get title => 'Safety checks';

	/// en: 'Password'
	String get password => 'Password';

	/// en: 'Link'
	String get link => 'Link';

	/// en: 'Was it leaked?'
	String get pwTitle => 'Was it leaked?';

	/// en: 'Password to check'
	String get pwHint => 'Password to check';

	/// en: 'Show password'
	String get showPassword => 'Show password';

	/// en: 'Hide password'
	String get hidePassword => 'Hide password';

	/// en: 'Check'
	String get check => 'Check';

	/// en: 'Found in leaks'
	String get leaked => 'Found in leaks';

	/// en: 'Seen {n} times'
	String seen({required Object n}) => 'Seen ${n} times';

	/// en: 'Change it everywhere you use it, starting with email and banking.'
	String get leakedAdvice => 'Change it everywhere you use it, starting with email and banking.';

	/// en: 'Not in known leaks'
	String get notFound => 'Not in known leaks';

	/// en: 'A good sign, not a guarantee. Use a different password for every account.'
	String get notFoundAdvice => 'A good sign, not a guarantee. Use a different password for every account.';

	/// en: 'Could not check. Try again.'
	String get failed => 'Could not check. Try again.';

	/// en: 'Your password never leaves this phone'
	String get private => 'Your password never leaves this phone';

	/// en: 'Is this link safe?'
	String get linkTitle => 'Is this link safe?';

	/// en: 'Link to check'
	String get linkHint => 'Link to check';

	/// en: 'Paste'
	String get paste => 'Paste';

	/// en: 'Dangerous link'
	String get danger => 'Dangerous link';

	/// en: 'Do not open it or enter any details.'
	String get dangerAdvice => 'Do not open it or enter any details.';

	/// en: 'Not on known malware or phishing lists'
	String get clear => 'Not on known malware or phishing lists';

	/// en: 'Still look at the address before you sign in anywhere.'
	String get clearAdvice => 'Still look at the address before you sign in anywhere.';

	/// en: 'Goes to'
	String get goesTo => 'Goes to';

	/// en: 'Redirects'
	String get redirects => 'Redirects';

	/// en: 'That does not look like a web address.'
	String get invalid => 'That does not look like a web address.';

	/// en: 'Too many checks. Try again in a while.'
	String get busy => 'Too many checks. Try again in a while.';

	/// en: 'Link check is not available right now.'
	String get unavailable => 'Link check is not available right now.';

	/// en: 'Known for malware or phishing'
	String get listed => 'Known for malware or phishing';

	/// en: 'No website at this address'
	String get missing => 'No website at this address';

	/// en: 'Check the spelling: scams often use look-alike addresses.'
	String get missingAdvice => 'Check the spelling: scams often use look-alike addresses.';

	/// en: '{n} of {total} free checks left this month'
	String left({required Object n, required Object total}) => '${n} of ${total} free checks left this month';

	/// en: 'You have used this month's free link checks'
	String get usedUp => 'You have used this month\'s free link checks';

	/// en: 'Pro has unlimited link checks. Your free checks come back on the 1st.'
	String get usedUpSub => 'Pro has unlimited link checks. Your free checks come back on the 1st.';

	/// en: 'Get Pro'
	String get getPro => 'Get Pro';
}

// Path: toolSettings
class Translations$toolSettings$en {
	Translations$toolSettings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Tool settings'
	String get title => 'Tool settings';

	/// en: 'Ask before speed tests on mobile data'
	String get askMobile => 'Ask before speed tests on mobile data';

	/// en: 'A test can use over 100 MB on a fast connection'
	String get askMobileSub => 'A test can use over 100 MB on a fast connection';

	/// en: 'Use mobile data?'
	String get mobileTitle => 'Use mobile data?';

	/// en: 'A speed test can use over 100 MB on a fast connection.'
	String get mobileBody => 'A speed test can use over 100 MB on a fast connection.';

	/// en: 'Test'
	String get mobileGo => 'Test';

	/// en: 'Safe'
	String get safe => 'Safe';

	/// en: 'Unsafe'
	String get unsafe => 'Unsafe';

	/// en: '(one) {{n} device} (other) {{n} devices}'
	String devices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} device',
		other: '${n} devices',
	);

	/// en: 'Hide hardware addresses'
	String get hideMac => 'Hide hardware addresses';

	/// en: 'Shows only the maker part of MAC addresses'
	String get hideMacSub => 'Shows only the maker part of MAC addresses';

	/// en: 'Show names of routers and servers'
	String get names => 'Show names of routers and servers';

	/// en: 'Looks up names for addresses in Traceroute'
	String get namesSub => 'Looks up names for addresses in Traceroute';

	/// en: 'Remember recent hosts'
	String get remember => 'Remember recent hosts';

	/// en: 'For Traceroute'
	String get rememberSub => 'For Traceroute';

	/// en: 'Clear tool history'
	String get clear => 'Clear tool history';

	/// en: 'Forgets recent hosts and which devices each network had'
	String get clearSub => 'Forgets recent hosts and which devices each network had';

	/// en: 'Clear'
	String get clearGo => 'Clear';
}

// Path: security
class Translations$security$en {
	Translations$security$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Security'
	String get tab => 'Security';

	/// en: 'Good'
	String get good => 'Good';

	/// en: 'Fair'
	String get fair => 'Fair';

	/// en: 'At risk'
	String get atRisk => 'At risk';

	/// en: 'Nothing to fix'
	String get allClear => 'Nothing to fix';

	/// en: 'Checked {time}'
	String checked({required Object time}) => 'Checked ${time}';

	/// en: 'LAST TWO WEEKS'
	String get trend => 'LAST TWO WEEKS';

	/// en: 'Checking this network'
	String get checking => 'Checking this network';

	/// en: 'Snoozed'
	String get snoozed => 'Snoozed';

	/// en: 'Remind me later'
	String get remindLater => 'Remind me later';

	/// en: 'Remind me now'
	String get unsnooze => 'Remind me now';

	/// en: 'Review'
	String get review => 'Review';

	/// en: 'Confirm'
	String get confirmGo => 'Confirm';

	/// en: 'Scan'
	String get scanGo => 'Scan';

	/// en: 'Look'
	String get look => 'Look';

	/// en: 'Connect'
	String get connectGo => 'Connect';

	/// en: 'Check again'
	String get checkAgain => 'Check again';

	/// en: 'Wi-Fi is open'
	String get wifiOpen => 'Wi-Fi is open';

	/// en: 'Anyone nearby can see what is sent'
	String get wifiOpenDetail => 'Anyone nearby can see what is sent';

	/// en: 'Wi-Fi uses WEP'
	String get wifiWep => 'Wi-Fi uses WEP';

	/// en: 'Old security, easy to break'
	String get wifiWepDetail => 'Old security, easy to break';

	/// en: 'Wi-Fi uses Enhanced Open'
	String get wifiOwe => 'Wi-Fi uses Enhanced Open';

	/// en: 'Encrypted, but anyone can join'
	String get wifiOweDetail => 'Encrypted, but anyone can join';

	/// en: 'Wi-Fi encryption'
	String get wifiSecure => 'Wi-Fi encryption';

	/// en: 'Wi-Fi security unknown'
	String get wifiUnknown => 'Wi-Fi security unknown';

	/// en: 'Android did not say how it is protected'
	String get wifiUnknownDetail => 'Android did not say how it is protected';

	/// en: 'WPS is on'
	String get wps => 'WPS is on';

	/// en: 'Turn it off in the router's settings'
	String get wpsDetail => 'Turn it off in the router\'s settings';

	/// en: 'Router keeps ports closed'
	String get upnpOff => 'Router keeps ports closed';

	/// en: 'UPnP is off'
	String get upnpOffDetail => 'UPnP is off';

	/// en: 'Router lets devices open ports'
	String get upnpOn => 'Router lets devices open ports';

	/// en: 'UPnP is on'
	String get upnpOnDetail => 'UPnP is on';

	/// en: 'No risky ports on the router'
	String get portsOk => 'No risky ports on the router';

	/// en: 'Risky ports open on the router'
	String get portsRisky => 'Risky ports open on the router';

	/// en: 'Scan to see who is here'
	String get scanFirst => 'Scan to see who is here';

	/// en: 'Unknown devices count against the score'
	String get scanFirstDetail => 'Unknown devices count against the score';

	/// en: 'Check your router's device list'
	String get notMineDetail => 'Check your router\'s device list';

	/// en: 'Mark the ones that are yours'
	String get confirmDetail => 'Mark the ones that are yours';

	/// en: 'Every device is known'
	String get devicesOk => 'Every device is known';

	/// en: 'You confirmed each one'
	String get devicesOkDetail => 'You confirmed each one';

	/// en: 'A camera is on this network'
	String get camera => 'A camera is on this network';

	/// en: 'Unknown names are redirected'
	String get dnsHijack => 'Unknown names are redirected';

	/// en: 'Your provider or router rewrites lookups'
	String get dnsHijackDetail => 'Your provider or router rewrites lookups';

	/// en: 'DNS answers normally'
	String get dnsOk => 'DNS answers normally';

	/// en: 'No sign of redirection'
	String get dnsOkDetail => 'No sign of redirection';

	/// en: 'VPN is on'
	String get vpnOn => 'VPN is on';

	/// en: 'Traffic leaves through the tunnel'
	String get vpnOnDetail => 'Traffic leaves through the tunnel';

	/// en: 'VPN is off'
	String get vpnOff => 'VPN is off';

	/// en: 'Your provider sees every site'
	String get vpnOffDetail => 'Your provider sees every site';

	/// en: '(one) {{n} thing to fix} (other) {{n} things to fix}'
	String toFix({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} thing to fix',
		other: '${n} things to fix',
	);

	/// en: '(one) {{n} port opened by devices} (other) {{n} ports opened by devices}'
	String upnpOpened({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} port opened by devices',
		other: '${n} ports opened by devices',
	);

	/// en: '(one) {{n} port checked} (other) {{n} ports checked}'
	String portsChecked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} port checked',
		other: '${n} ports checked',
	);

	/// en: '(one) {{n} device is not yours} (other) {{n} devices are not yours}'
	String notMine({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} device is not yours',
		other: '${n} devices are not yours',
	);

	/// en: '(one) {{n} device to confirm} (other) {{n} devices to confirm}'
	String confirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} device to confirm',
		other: '${n} devices to confirm',
	);
}

// Path: providers
class Translations$providers$en {
	Translations$providers$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Internet'
	String get tab => 'Internet';

	/// en: 'Could not reach the provider list. Check your connection.'
	String get unavailable => 'Could not reach the provider list. Check your connection.';

	/// en: 'As of your last check without the VPN'
	String get cached => 'As of your last check without the VPN';

	/// en: 'Not enough ratings yet'
	String get notEnough => 'Not enough ratings yet';

	/// en: 'Your rating this month'
	String get yourRating => 'Your rating this month';

	/// en: 'YOUR SPEED'
	String get yourSpeed => 'YOUR SPEED';

	/// en: 'Run a speed test'
	String get runTest => 'Run a speed test';

	/// en: 'About average here'
	String get aboutAverage => 'About average here';

	/// en: '{pct}% above the local average'
	String aboveAverage({required Object pct}) => '${pct}% above the local average';

	/// en: '{pct}% below the local average'
	String belowAverage({required Object pct}) => '${pct}% below the local average';

	/// en: 'Call'
	String get call => 'Call';

	/// en: 'Website'
	String get website => 'Website';

	/// en: 'Outages'
	String get outages => 'Outages';

	/// en: 'Rate'
	String get rate => 'Rate';

	/// en: 'Change rating'
	String get changeRating => 'Change rating';

	/// en: 'Compare'
	String get compare => 'Compare';

	/// en: 'Rate {name}'
	String rateTitle({required Object name}) => 'Rate ${name}';

	/// en: 'One rating a month'
	String get oncePerMonth => 'One rating a month';

	/// en: 'Tap the stars'
	String get tapStars => 'Tap the stars';

	/// en: 'Verified by your speed test: {mbps} Mbps'
	String verified({required Object mbps}) => 'Verified by your speed test: ${mbps} Mbps';

	/// en: 'Too many ratings from here. Try later.'
	String get busy => 'Too many ratings from here. Try later.';

	/// en: 'Could not post. Try again.'
	String get failed => 'Could not post. Try again.';

	/// en: 'Post rating'
	String get post => 'Post rating';

	/// en: 'Providers near you'
	String get nearTitle => 'Providers near you';

	/// en: 'Your download is {pct}% below your provider's average here'
	String slower({required Object pct}) => 'Your download is ${pct}% below your provider\'s average here';

	/// en: 'Home internet in {place}'
	String inPlace({required Object place}) => 'Home internet in ${place}';

	/// en: 'Rating'
	String get byRating => 'Rating';

	/// en: 'Speed'
	String get bySpeed => 'Speed';

	/// en: 'Speeds are averages of G VPN speed tests'
	String get footnote => 'Speeds are averages of G VPN speed tests';

	/// en: 'No ratings near you yet. Be the first.'
	String get noneNearby => 'No ratings near you yet. Be the first.';

	/// en: 'You'
	String get you => 'You';

	/// en: 'Top rated'
	String get topRated => 'Top rated';

	/// en: '{n} out of 5'
	String starsOf({required Object n}) => '${n} out of 5';

	late final Translations$providers$tags$en tags = Translations$providers$tags$en.internal(_root);
	late final Translations$providers$words$en words = Translations$providers$words$en.internal(_root);

	/// en: '(one) {{n} rating} (other) {{n} ratings}'
	String ratings({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} rating',
		other: '${n} ratings',
	);
}

// Path: alerts
class Translations$alerts$en {
	Translations$alerts$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Alerts'
	String get channel => 'Alerts';

	/// en: 'Alerts'
	String get title => 'Alerts';

	/// en: 'Mark all read'
	String get markAllRead => 'Mark all read';

	/// en: 'Clear all'
	String get clearAll => 'Clear all';

	/// en: 'this network'
	String get thisNetwork => 'this network';

	/// en: 'You joined an open Wi-Fi: {name}'
	String openWifiTitle({required Object name}) => 'You joined an open Wi-Fi: ${name}';

	/// en: 'Anyone nearby can see what is sent. Turn on G VPN.'
	String get openWifiBody => 'Anyone nearby can see what is sent. Turn on G VPN.';

	/// en: 'Your weekly report is ready'
	String get reportTitle => 'Your weekly report is ready';

	/// en: '{hours} hours protected last week'
	String reportBody({required Object hours}) => '${hours} hours protected last week';

	/// en: '{name} is blocked here'
	String blockedTitle({required Object name}) => '${name} is blocked here';

	/// en: 'It answers through the VPN'
	String get blockedBody => 'It answers through the VPN';

	late final Translations$alerts$kinds$en kinds = Translations$alerts$kinds$en.internal(_root);

	/// en: '(one) {New device on {network}} (other) {{n} new devices on {network}}'
	String newDeviceTitle({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'New device on ${network}',
		other: '${n} new devices on ${network}',
	);

	/// en: 'Alert settings'
	String get settings => 'Alert settings';

	/// en: 'Look'
	String get look => 'Look';

	/// en: 'Read'
	String get read => 'Read';

	/// en: 'Open'
	String get open => 'Open';

	/// en: 'Check'
	String get check => 'Check';

	/// en: 'TODAY'
	String get today => 'TODAY';

	/// en: 'THIS WEEK'
	String get thisWeek => 'THIS WEEK';

	/// en: 'EARLIER'
	String get earlier => 'EARLIER';

	/// en: 'All'
	String get all => 'All';

	/// en: 'All quiet'
	String get quiet => 'All quiet';

	/// en: 'Nothing needed you lately'
	String get quietSub => 'Nothing needed you lately';

	/// en: 'New breach: {name}'
	String breachTitle({required Object name}) => 'New breach: ${name}';

	late final Translations$alerts$status$en status = Translations$alerts$status$en.internal(_root);
}

// Path: report
class Translations$report$en {
	Translations$report$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Weekly report'
	String get title => 'Weekly report';

	/// en: 'Share as image'
	String get share => 'Share as image';

	/// en: 'My week with G VPN'
	String get shareText => 'My week with G VPN';

	/// en: 'A safer week'
	String get safer => 'A safer week';

	/// en: 'More protected than last week'
	String get moreProtected => 'More protected than last week';

	/// en: 'Your week'
	String get yourWeek => 'Your week';

	/// en: '{range}, so far'
	String soFar({required Object range}) => '${range}, so far';

	/// en: 'Protected'
	String get protected => 'Protected';

	/// en: 'Data'
	String get data => 'Data';

	/// en: 'Security'
	String get security => 'Security';

	/// en: 'Best speed'
	String get speed => 'Best speed';

	/// en: 'Not checked'
	String get noScore => 'Not checked';

	/// en: 'No test'
	String get noTest => 'No test';

	/// en: 'Direct test'
	String get bestDirect => 'Direct test';

	/// en: '{d} more than last week'
	String moreThan({required Object d}) => '${d} more than last week';

	/// en: '{d} less than last week'
	String lessThan({required Object d}) => '${d} less than last week';

	/// en: 'PROTECTED TIME'
	String get protectedTime => 'PROTECTED TIME';

	/// en: 'Most used: {name}'
	String mostUsed({required Object name}) => 'Most used: ${name}';

	/// en: 'A quiet week: nothing needed you'
	String get quiet => 'A quiet week: nothing needed you';

	/// en: '(one) {{n} new device joined} (other) {{n} new devices joined}'
	String newDevices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} new device joined',
		other: '${n} new devices joined',
	);

	/// en: '(one) {Joined {n} open Wi-Fi} (other) {Joined {n} open Wi-Fi networks}'
	String openWifi({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Joined ${n} open Wi-Fi',
		other: 'Joined ${n} open Wi-Fi networks',
	);

	/// en: '(one) {{n} app blocked} (other) {{n} apps blocked}'
	String blocked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} app blocked',
		other: '${n} apps blocked',
	);

	/// en: '(one) {{n} big new breach} (other) {{n} big new breaches}'
	String breaches({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} big new breach',
		other: '${n} big new breaches',
	);
}

// Path: breaches
class Translations$breaches$en {
	Translations$breaches$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Data breaches'
	String get title => 'Data breaches';

	/// en: 'The latest data breaches, from Have I Been Pwned's public list. Nothing about you is sent: the list is the same for everyone. If you had an account with a breached site, change that password, and anywhere you reused it.'
	String get info => 'The latest data breaches, from Have I Been Pwned\'s public list. Nothing about you is sent: the list is the same for everyone.\n\nIf you had an account with a breached site, change that password, and anywhere you reused it.';

	/// en: 'Could not load the breach list. Check your connection.'
	String get unavailable => 'Could not load the breach list. Check your connection.';

	/// en: 'BIGGEST THIS MONTH'
	String get biggest => 'BIGGEST THIS MONTH';

	/// en: 'Newest'
	String get newest => 'Newest';

	/// en: 'Biggest'
	String get biggestSort => 'Biggest';

	/// en: 'With passwords'
	String get withPasswords => 'With passwords';

	/// en: 'PASSWORDS'
	String get passwordsMark => 'PASSWORDS';

	/// en: 'Breach'
	String get one => 'Breach';

	/// en: 'Check a password'
	String get checkPassword => 'Check a password';

	/// en: 'Verified'
	String get verified => 'Verified';

	/// en: 'Has passwords'
	String get hasPasswords => 'Has passwords';

	/// en: 'Accounts'
	String get accountsLabel => 'Accounts';

	/// en: 'Happened'
	String get happened => 'Happened';

	/// en: 'Published'
	String get published => 'Published';

	/// en: 'Website'
	String get website => 'Website';

	/// en: 'WHAT LEAKED'
	String get leaked => 'WHAT LEAKED';

	/// en: 'IF YOU USED IT'
	String get ifUsed => 'IF YOU USED IT';

	/// en: 'Change the password you used there'
	String get stepPassword => 'Change the password you used there';

	/// en: 'Change it anywhere you used the same one'
	String get stepReuse => 'Change it anywhere you used the same one';

	/// en: 'Turn on two-step sign-in where you can'
	String get stepTwoStep => 'Turn on two-step sign-in where you can';

	/// en: 'Expect scam calls and texts'
	String get stepScams => 'Expect scam calls and texts';

	/// en: '(one) {{count} account} (other) {{count} accounts}'
	String accounts({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${count} account',
		other: '${count} accounts',
	);

	/// en: 'Worldwide · {n}'
	String worldwide({required Object n}) => 'Worldwide · ${n}';

	/// en: 'No breaches from here in the recent list.'
	String get noneHere => 'No breaches from here in the recent list.';

	/// en: 'Bigger map'
	String get bigMap => 'Bigger map';

	/// en: 'Show in list'
	String get showInList => 'Show in list';

	/// en: 'Breach map'
	String get mapTitle => 'Breach map';

	/// en: 'Zoom in'
	String get zoomIn => 'Zoom in';

	/// en: 'Zoom out'
	String get zoomOut => 'Zoom out';

	/// en: 'Whole world'
	String get wholeWorld => 'Whole world';

	/// en: '(one) {{n} breach} (other) {{n} breaches}'
	String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} breach',
		other: '${n} breaches',
	);

	/// en: 'Find a country'
	String get findCountry => 'Find a country';

	/// en: 'See all'
	String get seeAll => 'See all';

	/// en: 'Search breaches'
	String get search => 'Search breaches';
}

// Path: blocked
class Translations$blocked$en {
	Translations$blocked$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'What's blocked'
	String get title => 'What\'s blocked';

	/// en: 'Tests well-known sites from this phone, without the VPN, and shows which ones this network blocks and how. Wrong address: the network's name lookup gives a false answer. Cut off: the connection is reset as it starts. No answer: nothing comes back. Block page: something else answers in the site's place. The test shows where a site is blocked, not who blocked it. Nothing is stored or sent anywhere.'
	String get info => 'Tests well-known sites from this phone, without the VPN, and shows which ones this network blocks and how.\n\nWrong address: the network\'s name lookup gives a false answer.\n\nCut off: the connection is reset as it starts.\n\nNo answer: nothing comes back.\n\nBlock page: something else answers in the site\'s place.\n\nThe test shows where a site is blocked, not who blocked it. Nothing is stored or sent anywhere.';

	/// en: 'This network'
	String get thisNetwork => 'This network';

	/// en: 'Your country'
	String get country => 'Your country';

	/// en: 'What's blocked here?'
	String get question => 'What\'s blocked here?';

	/// en: 'TESTING ON'
	String get testingOn => 'TESTING ON';

	/// en: 'VPN ON'
	String get vpnOn => 'VPN ON';

	/// en: 'Turn off G VPN to test'
	String get turnOff => 'Turn off G VPN to test';

	/// en: 'Test this network'
	String get test => 'Test this network';

	/// en: 'Stop'
	String get stop => 'Stop';

	/// en: 'SITES TO TEST · {n}'
	String sitesToTest({required Object n}) => 'SITES TO TEST · ${n}';

	/// en: 'of {n} sites'
	String ofSites({required Object n}) => 'of ${n} sites';

	/// en: '{n} BLOCKED'
	String blockedCount({required Object n}) => '${n} BLOCKED';

	/// en: '{n} OPEN'
	String openCount({required Object n}) => '${n} OPEN';

	/// en: 'Nothing blocked on {network}'
	String noneBlocked({required Object network}) => 'Nothing blocked on ${network}';

	/// en: '{open} of {total} open'
	String openOf({required Object open, required Object total}) => '${open} of ${total} open';

	/// en: 'ALL WORK WITH G VPN'
	String get allWork => 'ALL WORK WITH G VPN';

	/// en: 'BLOCKED'
	String get blockedHeading => 'BLOCKED';

	/// en: 'BY KIND'
	String get byKind => 'BY KIND';

	/// en: 'Works with VPN'
	String get worksVpn => 'Works with VPN';

	/// en: 'Blocked through VPN too'
	String get failsVpn => 'Blocked through VPN too';

	/// en: 'Check through G VPN'
	String get checkVpn => 'Check through G VPN';

	/// en: 'Connect G VPN'
	String get connect => 'Connect G VPN';

	/// en: 'Test again'
	String get again => 'Test again';

	/// en: 'WITHOUT VPN'
	String get withoutVpn => 'WITHOUT VPN';

	/// en: 'THROUGH G VPN'
	String get throughVpn => 'THROUGH G VPN';

	/// en: 'Not checked'
	String get notChecked => 'Not checked';

	/// en: 'Opens'
	String get opens => 'Opens';

	/// en: 'Blocked'
	String get stillBlocked => 'Blocked';

	/// en: 'WHAT HAPPENED'
	String get whatHappened => 'WHAT HAPPENED';

	/// en: 'sites blocked in {country}'
	String countryBlocked({required Object country}) => 'sites blocked in ${country}';

	/// en: 'Found by volunteers' tests in the last 30 days'
	String get countrySub => 'Found by volunteers\' tests in the last 30 days';

	/// en: 'No blocked sites reported in the last 30 days.'
	String get countryNone => 'No blocked sites reported in the last 30 days.';

	/// en: 'Could not load the country's results. Check your connection.'
	String get countryUnavailable => 'Could not load the country\'s results. Check your connection.';

	/// en: 'BLOCKED'
	String get confirmed => 'BLOCKED';

	/// en: 'OFTEN FAILS'
	String get oftenFails => 'OFTEN FAILS';

	late final Translations$blocked$kinds$en kinds = Translations$blocked$kinds$en.internal(_root);
	late final Translations$blocked$how$en how = Translations$blocked$how$en.internal(_root);
	late final Translations$blocked$fail$en fail = Translations$blocked$fail$en.internal(_root);
	late final Translations$blocked$steps$en steps = Translations$blocked$steps$en.internal(_root);
	late final Translations$blocked$consent$en consent = Translations$blocked$consent$en.internal(_root);

	/// en: '(one) {{n} site blocked on {network}} (other) {{n} sites blocked on {network}}'
	String someBlocked({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} site blocked on ${network}',
		other: '${n} sites blocked on ${network}',
	);

	/// en: '(one) {{n} test} (other) {{n} tests}'
	String tests({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} test',
		other: '${n} tests',
	);
}

// Path: home.status
class Translations$home$status$en {
	Translations$home$status$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Paused'
	String get paused => 'Paused';

	/// en: 'Reconnecting'
	String get reconnecting => 'Reconnecting';

	/// en: 'Protected'
	String get protected => 'Protected';

	/// en: 'Connecting'
	String get connecting => 'Connecting';

	/// en: 'Stopping'
	String get stopping => 'Stopping';

	/// en: 'Not protected'
	String get notProtected => 'Not protected';
}

// Path: home.network
class Translations$home$network$en {
	Translations$home$network$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'THIS NETWORK'
	String get title => 'THIS NETWORK';

	/// en: 'Wi-Fi'
	String get wifi => 'Wi-Fi';

	/// en: 'Offline'
	String get offline => 'Offline';

	/// en: 'Show name'
	String get showName => 'Show name';

	/// en: 'Scan failed. It runs again when the network changes.'
	String get scanFailed => 'Scan failed. It runs again when the network changes.';
}

// Path: home.card
class Translations$home$card$en {
	Translations$home$card$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'DOWNLOADED'
	String get downloaded => 'DOWNLOADED';

	/// en: 'UPLOADED'
	String get uploaded => 'UPLOADED';

	/// en: 'WireGuard'
	String get wireguard => 'WireGuard';

	/// en: 'OpenVPN {proto}'
	String openvpn({required Object proto}) => 'OpenVPN ${proto}';

	/// en: 'SELECTED'
	String get selected => 'SELECTED';

	/// en: 'BROWSING FROM'
	String get browsingFrom => 'BROWSING FROM';

	/// en: 'Disconnect'
	String get disconnect => 'Disconnect';

	/// en: 'Change'
	String get change => 'Change';

	/// en: 'On'
	String get enabled => 'On';

	/// en: 'SHIELD'
	String get shield => 'SHIELD';
}

// Path: home.tiles
class Translations$home$tiles$en {
	Translations$home$tiles$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Shield'
	String get shield => 'Shield';

	/// en: 'Apps direct'
	String get appsDirect => 'Apps direct';

	/// en: 'All apps protected'
	String get appsAll => 'All apps protected';

	/// en: '{n} skip the VPN'
	String appsSkip({required Object n}) => '${n} skip the VPN';

	/// en: 'Auto-connect'
	String get autoConnect => 'Auto-connect';

	/// en: 'On public Wi-Fi'
	String get autoOpen => 'On public Wi-Fi';

	/// en: 'On every Wi-Fi'
	String get autoAny => 'On every Wi-Fi';

	/// en: 'Speed'
	String get speed => 'Speed';

	/// en: 'Tap to test'
	String get speedTap => 'Tap to test';

	/// en: 'Direct {mbps} Mbps'
	String speedDirect({required Object mbps}) => 'Direct ${mbps} Mbps';
}

// Path: home.fastest
class Translations$home$fastest$en {
	Translations$home$fastest$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Fastest free server'
	String get title => 'Fastest free server';

	/// en: 'Picked from'
	String get pickedFrom => 'Picked from';

	/// en: '+{n}'
	String more({required Object n}) => '+${n}';

	/// en: 'Finding the fastest server'
	String get finding => 'Finding the fastest server';

	/// en: 'Free servers could not load'
	String get failed => 'Free servers could not load';

	/// en: 'How the server is picked'
	String get how => 'How the server is picked';

	/// en: 'G VPN connects you to the free server ranked best right now, by speed, load and how long it has stayed up. The ranking changes as servers come and go.'
	String get sheetBody => 'G VPN connects you to the free server ranked best right now, by speed, load and how long it has stayed up. The ranking changes as servers come and go.';
}

// Path: home.ip
class Translations$home$ip$en {
	Translations$home$ip$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'What sites see'
	String get title => 'What sites see';

	/// en: 'Your real location'
	String get real => 'Your real location';

	/// en: 'VPN location'
	String get vpn => 'VPN location';

	/// en: 'IP address'
	String get address => 'IP address';

	/// en: 'Coordinates'
	String get coordinates => 'Coordinates';

	/// en: 'Estimated from your IP. Never stored.'
	String get note => 'Estimated from your IP. Never stored.';

	/// en: 'Hide my location'
	String get hide => 'Hide my location';

	/// en: 'Near {place}'
	String near({required Object place}) => 'Near ${place}';
}

// Path: servers.tabs
class Translations$servers$tabs$en {
	Translations$servers$tabs$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Pro'
	String get pro => 'Pro';

	/// en: 'Free'
	String get free => 'Free';

	/// en: 'Yours'
	String get yours => 'Yours';
}

// Path: servers.sheet
class Translations$servers$sheet$en {
	Translations$servers$sheet$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Where servers come from'
	String get title => 'Where servers come from';

	/// en: 'Three kinds, one list'
	String get subtitle => 'Three kinds, one list';

	/// en: 'Volunteer servers, checked every two hours. Their operators keep connection logs for about two weeks.'
	String get free => 'Volunteer servers, checked every two hours. Their operators keep connection logs for about two weeks.';

	/// en: 'Run by us on WireGuard. No activity logs, no account.'
	String get pro => 'Run by us on WireGuard. No activity logs, no account.';

	/// en: 'Any WireGuard server you run: a router, a VPS or a home server.'
	String get yours => 'Any WireGuard server you run: a router, a VPS or a home server.';
}

// Path: servers.badges
class Translations$servers$badges$en {
	Translations$servers$badges$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'MOST USED'
	String get mostUsed => 'MOST USED';

	/// en: 'MOST STABLE'
	String get mostStable => 'MOST STABLE';

	/// en: 'FASTEST'
	String get fastest => 'FASTEST';
}

// Path: servers.filters
class Translations$servers$filters$en {
	Translations$servers$filters$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'All'
	String get all => 'All';

	/// en: 'Fastest'
	String get fastest => 'Fastest';

	/// en: 'Most stable'
	String get stable => 'Most stable';

	/// en: 'Popular'
	String get popular => 'Popular';
}

// Path: servers.own
class Translations$servers$own$en {
	Translations$servers$own$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Run your own server'
	String get title => 'Run your own server';

	/// en: 'Any WireGuard server works'
	String get subtitle => 'Any WireGuard server works';

	/// en: 'A router'
	String get router => 'A router';

	/// en: 'Many routers have WireGuard built in. Export the client config and scan its QR code here.'
	String get routerBody => 'Many routers have WireGuard built in. Export the client config and scan its QR code here.';

	/// en: 'A VPS'
	String get vps => 'A VPS';

	/// en: 'Any small Linux server. Install WireGuard, create a client, and import its config file.'
	String get vpsBody => 'Any small Linux server. Install WireGuard, create a client, and import its config file.';

	/// en: 'A home server'
	String get home => 'A home server';

	/// en: 'Reach your own network from anywhere, the same way.'
	String get homeBody => 'Reach your own network from anywhere, the same way.';

	/// en: 'No server yet?'
	String get noneYet => 'No server yet?';

	/// en: 'Add another'
	String get addAnother => 'Add another';

	/// en: 'Run one on a router, VPS or home server'
	String get hint => 'Run one on a router, VPS or home server';
}

// Path: pro.free
class Translations$pro$free$en {
	Translations$pro$free$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Your plan'
	String get title => 'Your plan';

	/// en: 'Everything is free'
	String get headline => 'Everything is free';

	/// en: 'Every server and every tool, with no account and no ads.'
	String get body => 'Every server and every tool, with no account and no ads.';

	/// en: 'Included'
	String get included => 'Included';

	/// en: 'Free servers'
	String get servers => 'Free servers';

	/// en: 'Ranked by speed and stability in dozens of countries'
	String get serversSub => 'Ranked by speed and stability in dozens of countries';

	/// en: 'Your own servers'
	String get own => 'Your own servers';

	/// en: 'Connect to any WireGuard router, VPS or home server'
	String get ownSub => 'Connect to any WireGuard router, VPS or home server';

	/// en: 'Shield'
	String get shield => 'Shield';

	/// en: 'Blocks known malware and phishing sites'
	String get shieldSub => 'Blocks known malware and phishing sites';

	/// en: 'Auto-connect and app rules'
	String get auto => 'Auto-connect and app rules';

	/// en: 'Protect public Wi-Fi; let banking apps go direct'
	String get autoSub => 'Protect public Wi-Fi; let banking apps go direct';

	/// en: 'Pause and Quick Settings'
	String get pause => 'Pause and Quick Settings';

	/// en: 'Pause from the notification, toggle from the tile'
	String get pauseSub => 'Pause from the notification, toggle from the tile';

	/// en: 'Every network tool'
	String get tools => 'Every network tool';

	/// en: 'Speed test, ping, service status, traceroute, devices and more'
	String get toolsSub => 'Speed test, ping, service status, traceroute, devices and more';

	/// en: 'G VPN Pro will add faster servers run by us. Everything above stays free.'
	String get later => 'G VPN Pro will add faster servers run by us. Everything above stays free.';
}

// Path: rules.info
class Translations$rules$info$en {
	Translations$rules$info$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Shield filters lookups while you are connected: Quad9 blocks malware and phishing, Cloudflare for Families also blocks adult sites, or use your own DNS. It never blocks ads.'
	String get shield => 'Shield filters lookups while you are connected: Quad9 blocks malware and phishing, Cloudflare for Families also blocks adult sites, or use your own DNS. It never blocks ads.';

	/// en: 'Auto-connect: uses your selected WireGuard server. Disconnecting by hand pauses it until you join another network.'
	String get autoConnect => 'Auto-connect: uses your selected WireGuard server. Disconnecting by hand pauses it until you join another network.';

	/// en: 'Apps direct: apps that skip the VPN connect directly. Banks often block VPN addresses, so payments can fail through a VPN.'
	String get apps => 'Apps direct: apps that skip the VPN connect directly. Banks often block VPN addresses, so payments can fail through a VPN.';

	/// en: 'Changing Shield or apps reconnects the VPN for a moment.'
	String get reconnect => 'Changing Shield or apps reconnects the VPN for a moment.';

	/// en: 'Stay connected: some phones stop apps in the background to save battery. Always-on VPN and an unrestricted battery setting keep G VPN running.'
	String get stay => 'Stay connected: some phones stop apps in the background to save battery. Always-on VPN and an unrestricted battery setting keep G VPN running.';
}

// Path: devices.kinds
class Translations$devices$kinds$en {
	Translations$devices$kinds$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Phone'
	String get phone => 'Phone';

	/// en: 'Computer'
	String get computer => 'Computer';

	/// en: 'TV'
	String get tv => 'TV';

	/// en: 'Speaker'
	String get speaker => 'Speaker';

	/// en: 'Printer'
	String get printer => 'Printer';

	/// en: 'Camera'
	String get camera => 'Camera';

	/// en: 'Smart home'
	String get smartHome => 'Smart home';

	/// en: 'Router'
	String get router => 'Router';

	/// en: 'Not announced'
	String get unknown => 'Not announced';
}

// Path: map.grade
class Translations$map$grade$en {
	Translations$map$grade$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Fast'
	String get fast => 'Fast';

	/// en: 'Good'
	String get good => 'Good';

	/// en: 'Slow'
	String get slow => 'Slow';
}

// Path: presets.names
class Translations$presets$names$en {
	Translations$presets$names$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Fastest'
	String get fastest => 'Fastest';

	/// en: 'Unblock'
	String get unblock => 'Unblock';

	/// en: 'Streaming'
	String get streaming => 'Streaming';

	/// en: 'Privacy max'
	String get privacy => 'Privacy max';
}

// Path: providers.tags
class Translations$providers$tags$en {
	Translations$providers$tags$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Fast'
	String get fast => 'Fast';

	/// en: 'Reliable'
	String get reliable => 'Reliable';

	/// en: 'Good support'
	String get support => 'Good support';

	/// en: 'Fair price'
	String get price => 'Fair price';

	/// en: 'Slow evenings'
	String get slowEvenings => 'Slow evenings';

	/// en: 'Drops often'
	String get drops => 'Drops often';

	/// en: 'Poor support'
	String get poorSupport => 'Poor support';

	/// en: 'Pricey'
	String get pricey => 'Pricey';
}

// Path: providers.words
class Translations$providers$words$en {
	Translations$providers$words$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Bad'
	String get bad => 'Bad';

	/// en: 'Poor'
	String get poor => 'Poor';

	/// en: 'Okay'
	String get okay => 'Okay';

	/// en: 'Good'
	String get good => 'Good';

	/// en: 'Great'
	String get great => 'Great';
}

// Path: alerts.kinds
class Translations$alerts$kinds$en {
	Translations$alerts$kinds$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'New devices on my Wi-Fi'
	String get newDevice => 'New devices on my Wi-Fi';

	/// en: 'Open or weak Wi-Fi'
	String get openWifi => 'Open or weak Wi-Fi';

	/// en: 'Blocked apps'
	String get blocked => 'Blocked apps';

	/// en: 'Weekly report'
	String get report => 'Weekly report';

	/// en: 'Breaches'
	String get breach => 'Breaches';
}

// Path: alerts.status
class Translations$alerts$status$en {
	Translations$alerts$status$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Every few hours'
	String get background => 'Every few hours';

	/// en: 'Last checked {time}'
	String checked({required Object time}) => 'Last checked ${time}';

	/// en: 'Every network you join'
	String get wifi => 'Every network you join';

	/// en: 'When Service status runs'
	String get blocked => 'When Service status runs';

	/// en: 'Every Monday'
	String get report => 'Every Monday';
}

// Path: blocked.kinds
class Translations$blocked$kinds$en {
	Translations$blocked$kinds$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Social'
	String get social => 'Social';

	/// en: 'Messaging'
	String get messaging => 'Messaging';

	/// en: 'News'
	String get news => 'News';

	/// en: 'Video and music'
	String get video => 'Video and music';

	/// en: 'Privacy tools'
	String get privacy => 'Privacy tools';
}

// Path: blocked.how
class Translations$blocked$how$en {
	Translations$blocked$how$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Wrong address'
	String get dns => 'Wrong address';

	/// en: 'Cut off'
	String get reset => 'Cut off';

	/// en: 'No answer'
	String get timeout => 'No answer';

	/// en: 'Block page'
	String get page => 'Block page';

	/// en: 'Open'
	String get open => 'Open';
}

// Path: blocked.fail
class Translations$blocked$fail$en {
	Translations$blocked$fail$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'no answer'
	String get noAnswer => 'no answer';

	/// en: 'refused'
	String get refused => 'refused';

	/// en: 'cut off after {s} s'
	String cutOff({required Object s}) => 'cut off after ${s} s';

	/// en: 'wrong certificate'
	String get wrongCert => 'wrong certificate';
}

// Path: blocked.steps
class Translations$blocked$steps$en {
	Translations$blocked$steps$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Name lookup'
	String get lookup => 'Name lookup';

	/// en: 'Connect'
	String get connect => 'Connect';

	/// en: 'Secure handshake'
	String get handshake => 'Secure handshake';
}

// Path: blocked.consent
class Translations$blocked$consent$en {
	Translations$blocked$consent$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Before the first test'
	String get title => 'Before the first test';

	/// en: 'The test opens each site from this phone, without the VPN, the way a browser would.'
	String get body => 'The test opens each site from this phone, without the VPN, the way a browser would.';

	/// en: 'It can be noticed'
	String get noticeTitle => 'It can be noticed';

	/// en: 'Your provider sees these sites being opened. In some countries visiting them, even to test, can draw attention. Only test where you feel safe to.'
	String get notice => 'Your provider sees these sites being opened. In some countries visiting them, even to test, can draw attention. Only test where you feel safe to.';

	/// en: 'I understand, test'
	String get ok => 'I understand, test';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.gotIt' => 'Got it',
			'common.about' => 'About',
			'common.connect' => 'Connect',
			'common.connected' => 'Connected',
			'common.retry' => 'Retry',
			'common.ok' => 'OK',
			'common.remove' => 'Remove',
			'common.cancel' => 'Cancel',
			'common.continueLabel' => 'Continue',
			'common.notNow' => 'Not now',
			'common.openSettings' => 'Open settings',
			'common.close' => 'Close',
			'common.off' => 'Off',
			'common.changesReconnect' => 'Changes reconnect the VPN',
			'nav.vpn' => 'VPN',
			'nav.servers' => 'Servers',
			'nav.tools' => 'Tools',
			'nav.rules' => 'Rules',
			'nav.pro' => 'Pro',
			'home.status.paused' => 'Paused',
			'home.status.reconnecting' => 'Reconnecting',
			'home.status.protected' => 'Protected',
			'home.status.connecting' => 'Connecting',
			'home.status.stopping' => 'Stopping',
			'home.status.notProtected' => 'Not protected',
			'home.resumesAt' => ({required Object time}) => 'Resumes at ${time} · tap to resume now',
			'home.ipFailed' => 'Could not check your IP',
			'home.ipChecking' => 'Checking your IP',
			'home.themeSystem' => 'Theme: follows phone',
			'home.themeLight' => 'Theme: light',
			'home.themeDark' => 'Theme: dark',
			'home.free' => 'Free',
			'home.pickServer' => 'Pick a server',
			'home.network.title' => 'THIS NETWORK',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Offline',
			'home.network.showName' => 'Show name',
			'home.network.scanFailed' => 'Scan failed. It runs again when the network changes.',
			'home.card.downloaded' => 'DOWNLOADED',
			'home.card.uploaded' => 'UPLOADED',
			'home.card.wireguard' => 'WireGuard',
			'home.card.openvpn' => ({required Object proto}) => 'OpenVPN ${proto}',
			'home.card.selected' => 'SELECTED',
			'home.card.browsingFrom' => 'BROWSING FROM',
			'home.card.disconnect' => 'Disconnect',
			'home.card.change' => 'Change',
			'home.card.enabled' => 'On',
			'home.card.shield' => 'SHIELD',
			'home.tiles.shield' => 'Shield',
			'home.tiles.appsDirect' => 'Apps direct',
			'home.tiles.appsAll' => 'All apps protected',
			'home.tiles.appsSkip' => ({required Object n}) => '${n} skip the VPN',
			'home.tiles.autoConnect' => 'Auto-connect',
			'home.tiles.autoOpen' => 'On public Wi-Fi',
			'home.tiles.autoAny' => 'On every Wi-Fi',
			'home.tiles.speed' => 'Speed',
			'home.tiles.speedTap' => 'Tap to test',
			'home.tiles.speedDirect' => ({required Object mbps}) => 'Direct ${mbps} Mbps',
			'home.fastest.title' => 'Fastest free server',
			'home.fastest.pickedFrom' => 'Picked from',
			'home.fastest.more' => ({required Object n}) => '+${n}',
			'home.fastest.finding' => 'Finding the fastest server',
			'home.fastest.failed' => 'Free servers could not load',
			'home.fastest.how' => 'How the server is picked',
			'home.fastest.sheetBody' => 'G VPN connects you to the free server ranked best right now, by speed, load and how long it has stayed up. The ranking changes as servers come and go.',
			'home.ip.title' => 'What sites see',
			'home.ip.real' => 'Your real location',
			'home.ip.vpn' => 'VPN location',
			'home.ip.address' => 'IP address',
			'home.ip.coordinates' => 'Coordinates',
			'home.ip.note' => 'Estimated from your IP. Never stored.',
			'home.ip.hide' => 'Hide my location',
			'home.ip.near' => ({required Object place}) => 'Near ${place}',
			'servers.title' => 'Servers',
			'servers.aboutServers' => 'About servers',
			'servers.tabs.pro' => 'Pro',
			'servers.tabs.free' => 'Free',
			'servers.tabs.yours' => 'Yours',
			'servers.sheet.title' => 'Where servers come from',
			'servers.sheet.subtitle' => 'Three kinds, one list',
			'servers.sheet.free' => 'Volunteer servers, checked every two hours. Their operators keep connection logs for about two weeks.',
			'servers.sheet.pro' => 'Run by us on WireGuard. No activity logs, no account.',
			'servers.sheet.yours' => 'Any WireGuard server you run: a router, a VPS or a home server.',
			'servers.badges.mostUsed' => 'MOST USED',
			'servers.badges.mostStable' => 'MOST STABLE',
			'servers.badges.fastest' => 'FASTEST',
			'servers.filters.all' => 'All',
			'servers.filters.fastest' => 'Fastest',
			'servers.filters.stable' => 'Most stable',
			'servers.filters.popular' => 'Popular',
			'servers.loadFailed' => 'Could not load the list',
			'servers.noServers' => 'No servers right now',
			'servers.best' => 'BEST FOR YOU NOW',
			'servers.topRanked' => 'Top ranked right now',
			'servers.addHeading' => 'ADD A SERVER',
			'servers.scanQr' => 'Scan QR',
			'servers.importFile' => 'Import file',
			'servers.paste' => 'Paste',
			'servers.own.title' => 'Run your own server',
			'servers.own.subtitle' => 'Any WireGuard server works',
			'servers.own.router' => 'A router',
			'servers.own.routerBody' => 'Many routers have WireGuard built in. Export the client config and scan its QR code here.',
			'servers.own.vps' => 'A VPS',
			'servers.own.vpsBody' => 'Any small Linux server. Install WireGuard, create a client, and import its config file.',
			'servers.own.home' => 'A home server',
			'servers.own.homeBody' => 'Reach your own network from anywhere, the same way.',
			'servers.own.noneYet' => 'No server yet?',
			'servers.own.addAnother' => 'Add another',
			'servers.own.hint' => 'Run one on a router, VPS or home server',
			'servers.configBroken' => 'Config needs attention',
			'servers.connectedBadge' => 'CONNECTED',
			'servers.scannedServer' => 'Scanned server',
			'servers.scanFailedTitle' => 'Could not scan',
			'servers.scanFailedBody' => 'The scanner is not available on this phone.',
			'servers.importFailedTitle' => 'Could not import',
			'servers.importFailedBody' => 'That file could not be read.',
			'servers.renameTitle' => 'Rename server',
			'servers.nameHint' => 'Name, for example Home router',
			'servers.save' => 'Save',
			'servers.rename' => 'Rename',
			'servers.disconnect' => 'Disconnect',
			'servers.more' => 'More options',
			'servers.justNow' => 'just now',
			'servers.minutesAgo' => ({required Object n}) => '${n} min ago',
			'servers.hoursAgo' => ({required Object n}) => '${n} h ago',
			'servers.daysAgo' => ({required Object n}) => '${n} d ago',
			'servers.neverUsed' => 'Not used yet',
			'servers.lastUsed' => ({required Object when}) => 'Last used ${when}',
			'servers.disconnectFirst' => 'Disconnect first to remove it',
			'servers.removeConfirm' => 'Remove this server from G VPN? Its settings are deleted from this phone; the server itself is not changed.',
			'servers.gTab' => 'G Servers',
			'servers.search' => 'Search countries',
			'servers.noMatch' => 'No servers match.',
			'servers.bestPing' => ({required Object ms}) => 'best ${ms} ms',
			'servers.bestTag' => 'BEST',
			'servers.ownHero' => 'Our own servers',
			'servers.ownHeroSub' => 'Faster, private, each phone with its own key',
			'servers.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} server', other: '${n} servers', ), 
			'servers.showAll' => ({required Object n}) => 'Show all ${n}',
			'servers.showFewer' => 'Show fewer',
			'servers.fastTab' => 'Fast',
			'servers.fastestFree' => 'Fastest free',
			'pro.owned' => 'You have Pro',
			'pro.waitingPlay' => 'Waiting for Google Play',
			'pro.startTrial' => ({required Object days}) => 'Start ${days}-day free trial',
			'pro.restore' => 'Restore',
			'pro.save' => ({required Object pct}) => 'SAVE ${pct}%',
			'pro.yearly' => 'Yearly',
			'pro.monthly' => 'Monthly',
			'pro.billedMonthly' => 'billed monthly',
			'pro.daysFree' => ({required Object days}) => '${days} days free',
			'pro.perMonth' => ({required Object price}) => '${price} a month',
			'pro.title' => 'G VPN Pro',
			'pro.renewGeneric' => 'Subscriptions renew automatically until cancelled. Cancel anytime in Google Play.',
			'pro.renewTrial' => ({required Object days, required Object price, required Object period}) => '${days} days free, then ${price} a ${period}. Renews automatically until cancelled; cancel anytime in Google Play, at least a day before the trial ends to avoid being charged.',
			'pro.renew' => ({required Object price, required Object period}) => '${price} a ${period}. Renews automatically until cancelled; cancel anytime in Google Play.',
			'pro.year' => 'year',
			'pro.month' => 'month',
			'pro.manage' => 'Manage subscription',
			'pro.free.title' => 'Your plan',
			'pro.free.headline' => 'Everything is free',
			'pro.free.body' => 'Every server and every tool, with no account and no ads.',
			'pro.free.included' => 'Included',
			'pro.free.servers' => 'Free servers',
			'pro.free.serversSub' => 'Ranked by speed and stability in dozens of countries',
			'pro.free.own' => 'Your own servers',
			'pro.free.ownSub' => 'Connect to any WireGuard router, VPS or home server',
			'pro.free.shield' => 'Shield',
			'pro.free.shieldSub' => 'Blocks known malware and phishing sites',
			'pro.free.auto' => 'Auto-connect and app rules',
			'pro.free.autoSub' => 'Protect public Wi-Fi; let banking apps go direct',
			'pro.free.pause' => 'Pause and Quick Settings',
			'pro.free.pauseSub' => 'Pause from the notification, toggle from the tile',
			'pro.free.tools' => 'Every network tool',
			'pro.free.toolsSub' => 'Speed test, ping, service status, traceroute, devices and more',
			'pro.free.later' => 'G VPN Pro will add faster servers run by us. Everything above stays free.',
			'pro.heroLine' => 'Our own fast servers, and every check unlimited',
			'pro.start' => 'Start Pro',
			'pro.compareFree' => 'FREE',
			'pro.comparePro' => 'PRO',
			'pro.rowFreeServers' => 'Free servers',
			'pro.rowTools' => 'Speed test, tools, Wi-Fi checks',
			'pro.rowGServers' => 'G Servers, no logs',
			'pro.rowLinks' => 'Link checks',
			'pro.linksFree' => ({required Object n}) => '${n} a month',
			'pro.unlimited' => 'Unlimited',
			'rules.title' => 'Rules',
			'rules.info.shield' => 'Shield filters lookups while you are connected: Quad9 blocks malware and phishing, Cloudflare for Families also blocks adult sites, or use your own DNS. It never blocks ads.',
			'rules.info.autoConnect' => 'Auto-connect: uses your selected WireGuard server. Disconnecting by hand pauses it until you join another network.',
			'rules.info.apps' => 'Apps direct: apps that skip the VPN connect directly. Banks often block VPN addresses, so payments can fail through a VPN.',
			'rules.info.reconnect' => 'Changing Shield or apps reconnects the VPN for a moment.',
			'rules.info.stay' => 'Stay connected: some phones stop apps in the background to save battery. Always-on VPN and an unrestricted battery setting keep G VPN running.',
			'rules.protection' => 'Protection',
			'rules.shield' => 'Shield',
			'rules.privateDns' => 'Shield without the VPN',
			'rules.privateDnsSub' => 'Copy dns.quad9.net for Private DNS',
			'rules.privateDnsCopied' => 'Copied dns.quad9.net',
			'rules.privateDnsHow' => 'Open Settings, search for Private DNS, choose "Private DNS provider hostname" and paste it.',
			'rules.stay' => 'Stay connected',
			'rules.alwaysOn' => 'Always-on VPN',
			'rules.alwaysOnSub' => 'Android restarts G VPN if it stops',
			'rules.battery' => 'Battery',
			'rules.batteryOk' => 'Unrestricted',
			'rules.batteryRestricted' => 'Restricted: may stop in background',
			'rules.autoConnect' => 'Auto-connect',
			'rules.autoOff' => 'Off',
			'rules.autoOffSub' => 'Only when you tap',
			'rules.autoOpen' => 'Public Wi-Fi',
			'rules.autoOpenSub' => 'Open, WEP or sign-in networks',
			'rules.autoAny' => 'Every Wi-Fi',
			'rules.autoAnySub' => 'Any Wi-Fi network',
			'rules.apps' => 'Apps',
			'rules.appsDirect' => 'Apps direct',
			'rules.appsNone' => 'Every app uses the VPN',
			'rules.appsSome' => ({required Object n}) => '${n} apps skip the VPN',
			'rules.appearance' => 'Appearance',
			'rules.themePhone' => 'Phone',
			'rules.themeLight' => 'Light',
			'rules.themeDark' => 'Dark',
			'rules.about' => 'About',
			'apps.title' => 'Apps direct',
			'apps.sheetSubtitle' => 'Chosen apps connect without the VPN. Everything else stays protected.',
			'apps.whyTitle' => 'Why skip an app',
			'apps.whyBody' => 'Banks and payment apps often block VPN addresses, so payments can fail through a VPN. Some local services only work from your own country.',
			'apps.favouritesBody' => 'Star the apps you change often; they stay at the top.',
			'apps.whileConnected' => 'While connected',
			'apps.whileConnectedBody' => 'Changing this list reconnects the VPN for a moment.',
			'apps.search' => ({required Object n}) => 'Search ${n} apps',
			'apps.skipping' => 'Skipping the VPN',
			'apps.skippingNone' => 'None. Every app goes through the VPN.',
			'apps.protectAgain' => ({required Object app}) => 'Protect ${app} again',
			'apps.banking' => 'Banking and payments',
			'apps.bankingFound' => ({required Object n}) => '${n} found that may block VPNs',
			'apps.addAll' => 'Add all',
			'apps.favourites' => 'Favourites',
			'apps.all' => 'All apps',
			'apps.found' => ({required Object n}) => '${n} found',
			'apps.noMatch' => 'No app matches.',
			'apps.showAll' => ({required Object n}) => 'Show all ${n}',
			'apps.skips' => 'Skips the VPN',
			'apps.unstar' => 'Remove from favourites',
			'apps.star' => 'Add to favourites',
			'location.title' => 'Allow location for Wi-Fi',
			'location.useHome' => 'Show your Wi-Fi name on Home',
			'location.useScan' => 'Scan nearby networks and channels',
			'location.private' => 'Stays on this phone. Your location is never collected.',
			'location.switchTitle' => 'Turn on Location',
			'location.switchBody' => 'Android hides Wi-Fi names while the Location switch is off',
			'addServer.clipboardEmpty' => 'The clipboard is empty.',
			'addServer.title' => 'Add your server',
			'addServer.body' => 'Paste a WireGuard config from your router, VPS or home server.',
			'addServer.nameHint' => 'Name, for example Home router',
			'addServer.paste' => 'Paste',
			'addServer.save' => 'Save server',
			'addServer.notWireguard' => ({required Object error}) => 'This is not a WireGuard config: ${error}',
			'button.stop' => 'Stop',
			'button.connecting' => 'Connecting',
			'button.stopping' => 'Stopping',
			'button.connect' => 'Connect',
			'button.disconnect' => 'Disconnect',
			'wol.info' => 'Turns on a computer or NAS on this Wi-Fi, if Wake on LAN is enabled in its settings. Your phone must be on the same network; turn the VPN off first.',
			'wol.badMac' => 'That is not a MAC address. It looks like AA:BB:CC:DD:EE:FF.',
			'wol.sent' => 'Wake signal sent. The device should start within a minute.',
			'wol.title' => 'Wake on LAN',
			'wol.mac' => 'MAC address',
			'wol.failed' => ({required Object error}) => 'Could not send: ${error}',
			'wol.computer' => 'Computer',
			'wol.pick' => 'Pick a device to wake',
			'wol.waking' => ({required Object name}) => 'Waking ${name}',
			'wol.yours' => 'YOUR DEVICES',
			'wol.wakeNamed' => ({required Object name}) => 'Wake ${name}',
			'wol.removeHint' => 'Hold a device to remove it',
			'wol.add' => 'ADD A DEVICE',
			'wol.name' => 'Name',
			'wol.saveWake' => 'Save and wake',
			'speed.download' => 'Download',
			'speed.upload' => 'Upload',
			'speed.finding' => 'Finding a server',
			'speed.throughVpn' => 'Through the VPN',
			'speed.directNoVpn' => 'Direct, no VPN',
			'speed.title' => 'Speed test',
			'speed.stop' => 'Stop',
			'speed.start' => 'Start test',
			'speed.again' => 'Test again',
			'speed.viaVpn' => 'Via VPN',
			'speed.direct' => 'Direct',
			'speed.mbps' => 'Mbps',
			'speed.ping' => 'PING',
			'speed.vsDirect' => 'VS DIRECT',
			'speed.compare' => 'Compare with providers nearby',
			'speed.compareSub' => 'Shares speeds only, never your IP',
			'speed.tierTv' => 'Large TVs',
			'speed.tierLaptopLarge' => 'Large laptops',
			'speed.tierTablet' => 'Tablets and laptops',
			'speed.tierPhone' => 'Phones',
			'speed.tierSmallPhone' => 'Small phones',
			'speed.tierCalls' => 'Calls and audio',
			'speed.messagingOnly' => 'Messaging only',
			'speed.videoQuality' => 'Video quality',
			'speed.preview' => 'PREVIEW',
			'speed.history' => 'History',
			'speed.clear' => 'Clear',
			'speed.viaVpnLower' => 'via VPN',
			'speed.directLower' => 'direct',
			'speed.gradeA' => 'Several 4K streams and video calls at once',
			'speed.gradeB' => 'HD streaming and smooth video calls',
			'speed.gradeC' => 'One HD stream; calls may stutter at busy times',
			'speed.gradeD' => 'Browsing and messaging; video struggles',
			'speed.yourCountry' => 'your country',
			'speed.median' => 'Median download, last 30 days',
			'speed.fromUsers' => 'Mbps · from G VPN users\' tests',
			'speed.costLittle' => 'Little speed lost to the VPN',
			'speed.costNoticeable' => 'Noticeably slower than direct',
			'speed.costMuch' => 'Much slower. Try another server',
			'speed.ofDirect' => 'of your direct speed',
			'speed.none' => 'none',
			'speed.ms' => ({required Object n}) => '${n} ms',
			'speed.previewTier' => ({required Object tier}) => 'PREVIEW · ${tier}',
			'speed.streamsUpTo' => ({required Object tier, required Object who}) => 'Streams up to ${tier} · ${who}',
			'speed.today' => ({required Object time}) => 'Today, ${time}',
			'speed.tests' => ({required Object n}) => '${n} tests',
			'speed.gradeVpn' => ({required Object label}) => '${label} through the VPN',
			'speed.gradeIsp' => ({required Object label, required Object isp}) => '${label} on ${isp}',
			'speed.notEnough' => ({required Object isp}) => 'Not enough tests yet for ${isp}',
			'speed.yourProvider' => 'your provider',
			'speed.rankLine' => ({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} in ${where}: ${rank} of ${of}',
			'speed.costLine' => ({required Object note, required Object mbps}) => '${note} · direct ${mbps} Mbps',
			'speed.mbpsValue' => ({required Object v}) => '${v} Mbps',
			'speed.gradeExcellent' => 'Excellent',
			'speed.gradeVeryGood' => 'Very good',
			'speed.gradeGood' => 'Good',
			'speed.gradeFair' => 'Fair',
			'speed.gradeSlow' => 'Slow',
			'speed.gradeVerySlow' => 'Very slow',
			'router.info' => 'Asks your router, over UPnP, whether devices may open ports to the internet on their own, and lists any they have opened. It only reads and changes nothing. If nothing needs UPnP (some game consoles do), turning it off in the router settings is safer.',
			'router.title' => 'Router check',
			'router.asking' => 'Asking the router',
			'router.again' => 'Check again',
			'router.check' => 'Check router',
			'router.off' => 'UPnP is off',
			'router.offBody' => 'Devices cannot open ports by themselves.',
			'router.onBody' => 'No ports open through it right now.',
			'router.checkEach' => 'Check you recognise each one.',
			'router.cgnat' => 'Shared provider address: not reachable from the internet.',
			'router.noDescription' => 'No description',
			'router.opened' => ({required Object n}) => '${n} ports opened by devices',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} to ${host}',
			'router.upnpOn' => 'UPnP is on',
			'router.routerLabel' => 'Router',
			'router.internetAddress' => 'Internet address',
			'router.openedBy' => 'Opened by devices',
			'network.title' => 'This network',
			'network.wifi' => 'Wi-Fi',
			'network.mobile' => 'Mobile data',
			'network.ethernet' => 'Ethernet',
			'network.offline' => 'Offline',
			'network.risky' => 'Risky network. Connect the VPN here.',
			'network.review' => 'Worth a look before you trust it.',
			'network.covered' => 'Covered by the VPN.',
			'network.safe' => 'This network looks safe.',
			'network.mobileSentence' => 'Mobile data.',
			'network.notConnected' => 'Not connected.',
			'network.showName' => 'Show name',
			'network.sitesSee' => 'Sites see',
			'network.provider' => 'Provider',
			'network.location' => 'Location',
			'network.couldNotCheck' => 'Could not check',
			'network.checking' => 'Checking',
			'network.signal' => 'Signal',
			'network.linkSpeed' => 'Link speed',
			'network.gateway' => 'Gateway',
			'network.none' => 'None',
			'network.privateDns' => 'Private DNS',
			'network.automatic' => 'Automatic',
			'network.off' => 'Off',
			'network.metered' => 'Metered',
			'network.yes' => 'Yes',
			'network.no' => 'No',
			'network.readFailed' => ({required Object error}) => 'Could not read the network: ${error}',
			'devices.info' => 'Knocks on every address in your Wi-Fi\'s range and asks devices to announce themselves. A device that refuses still counts: a refusal proves it is there.\n\nNames: from what devices publish (Bonjour, UPnP, Windows names) and from your router.\n\nUnknown devices: Android hides hardware addresses from apps, so a silent device with no announced name cannot be identified. Check your router\'s device list for those.\n\nNew: a device not seen in your last scan of this network.',
			'devices.needWifi' => 'Connect to a Wi-Fi network first.',
			'devices.title' => 'Devices',
			'devices.again' => 'Scan again',
			'devices.looking' => 'Looking for devices',
			'devices.all' => 'All',
			'devices.phones' => 'Phones',
			'devices.tvs' => 'TVs',
			'devices.computers' => 'Computers',
			'devices.other' => 'Other',
			'devices.thisPhone' => 'This phone',
			'devices.router' => 'Router',
			'devices.unknown' => 'Unknown device',
			'devices.address' => 'Address',
			'devices.answersIn' => 'Answers in',
			'devices.type' => 'Type',
			'devices.newBadge' => 'NEW',
			'devices.scanning' => ({required Object n}) => 'Scanning ${n} of 254',
			'devices.newSince' => ({required Object n}) => '${n} new since the last scan',
			'devices.ms' => ({required Object n}) => '${n} ms',
			'devices.cameras' => 'Cameras',
			'devices.device' => 'Device',
			'devices.online' => 'Online',
			'devices.model' => 'Model',
			'devices.announced' => 'Announces itself as',
			'devices.services' => 'OPEN SERVICES',
			'devices.checkingServices' => 'Checking services',
			'devices.noServices' => 'No common services answer',
			'devices.rename' => 'Rename',
			'devices.save' => 'Save',
			'devices.kinds.phone' => 'Phone',
			'devices.kinds.computer' => 'Computer',
			'devices.kinds.tv' => 'TV',
			'devices.kinds.speaker' => 'Speaker',
			'devices.kinds.printer' => 'Printer',
			'devices.kinds.camera' => 'Camera',
			'devices.kinds.smartHome' => 'Smart home',
			'devices.kinds.router' => 'Router',
			'devices.kinds.unknown' => 'Not announced',
			'devices.details' => 'Network details',
			'devices.listView' => 'List',
			'devices.meshView' => 'Mesh',
			'devices.offlineHeading' => 'Offline',
			'devices.seen' => ({required Object when}) => 'Seen ${when}',
			'devices.agoMinutes' => ({required Object n}) => '${n} min ago',
			'devices.agoHours' => ({required Object n}) => '${n} h ago',
			'devices.agoDays' => ({required Object n}) => '${n} d ago',
			'devices.throughVpn' => 'Through the VPN',
			'devices.closer' => 'Closer = answers faster',
			'devices.yours' => 'Is this yours?',
			'devices.mine' => 'Mine',
			'devices.notMine' => 'Not mine',
			'devices.whatIsIt' => 'What is it?',
			'devices.ourGuess' => ({required Object kind}) => 'Our guess: ${kind}',
			'devices.groupPersonal' => 'Phones and computers',
			'devices.groupHome' => 'Home and media',
			'devices.groupNetwork' => 'Network and smart home',
			'devices.onlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} online', other: '${n} online', ), 
			'devices.offlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} offline', other: '${n} offline', ), 
			'devices.toConfirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} to confirm', other: '${n} to confirm', ), 
			'ping.askTitle' => 'Ping a host',
			'ping.askHint' => 'example.com or 192.168.1.10',
			'ping.title' => 'Ping',
			'ping.router' => 'Router',
			'ping.pause' => 'Pause',
			'ping.start' => 'Start',
			'ping.host' => 'Host',
			'ping.live' => 'Live',
			'ping.ago' => '60 s ago',
			'ping.min' => 'MIN',
			'ping.avg' => 'AVG',
			'ping.jitter' => 'JITTER',
			'ping.loss' => 'LOSS',
			'ping.goodFor' => 'Good enough for',
			'ping.calls' => 'Video calls',
			'ping.games' => 'Online games',
			'ping.streaming' => 'Streaming',
			'ping.great' => 'Great',
			'ping.okay' => 'Okay',
			'ping.poor' => 'Poor',
			'ping.lost' => 'lost',
			'ping.now' => 'now',
			'status.info' => 'Connects to each service three times and shows the fastest answer.\n\nBlocked here: a service that does not answer directly but works through the VPN is blocked by your network or country.\n\nHistory: the last 24 hours of checks from this phone, kept only on this phone.',
			'status.title' => 'Service status',
			'status.checking' => 'Checking',
			'status.again' => 'Check again',
			'status.viaVpn' => 'Checked through the VPN',
			'status.direct' => 'Checked directly',
			'status.favourites' => 'Favourites',
			'status.edit' => 'Edit',
			'status.last24' => 'Last 24 hours',
			'status.ago' => '24 h ago',
			'status.all' => 'All services',
			'status.pickFour' => 'Pick up to four',
			'status.outage' => 'Even through the VPN: likely an outage',
			'status.blocked' => 'May be blocked on this network',
			'status.connect' => 'Connect',
			'status.blockedShort' => 'Blocked',
			'status.now' => 'now',
			'status.checks' => ({required Object n}) => '${n} checks',
			'status.andMore' => ({required Object first, required Object n}) => '${first} and ${n} more',
			'status.notReachable' => ({required Object who}) => '${who} not reachable',
			'tools.wifi' => 'Wi-Fi',
			'tools.mobile' => 'Mobile data',
			'tools.ethernet' => 'Ethernet',
			'tools.checking' => 'Checking',
			'tools.offline' => 'Offline',
			'tools.title' => 'Tools',
			'tools.networkDesc' => 'Safety check, what sites see, signal, router and DNS.',
			'tools.internet' => 'Internet',
			'tools.speed' => 'Speed test',
			'tools.speedDesc' => 'Download, upload and video quality',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'Live response time and jitter',
			'tools.status' => 'Service status',
			'tools.statusDesc' => 'Is an app reachable or blocked here?',
			'tools.trace' => 'Traceroute',
			'tools.traceDesc' => 'Every stop on the way to a site',
			'tools.security' => 'This network',
			'tools.devices' => 'Devices on this network',
			'tools.devicesDesc' => 'Who is on your Wi-Fi',
			'tools.router' => 'Router check',
			'tools.routerDesc' => 'Ports your devices opened',
			'tools.ports' => 'Open ports',
			'tools.portsDesc' => 'Risky ports on a device or server',
			'tools.utilities' => 'Utilities',
			'tools.wifiScanner' => 'Wi-Fi scanner',
			'tools.wifiDesc' => 'Networks around you and the clearest channel',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Turn on a computer on this network',
			'tools.passwordCheck' => 'Password check',
			'tools.passwordCheckDesc' => 'Has it been leaked?',
			'tools.linkCheck' => 'Link check',
			_ => null,
		} ?? switch (path) {
			'tools.linkCheckDesc' => 'Is it safe to open?',
			'tools.breaches' => 'Data breaches',
			'tools.breachesDesc' => 'What leaked lately',
			'tools.blocked' => 'What\'s blocked',
			'tools.blockedDesc' => 'Sites blocked on this network',
			'trace.info' => 'Each stop is one router your traffic passes through on the way to the site.\n\nSilent hops: many routers never answer these probes. That is normal and not a fault.\n\nWith the VPN on: the path starts inside the tunnel, so your own network and provider are hidden.\n\nHow: it uses Android\'s own ping tool with a hop limit, since apps cannot send these packets directly.',
			'trace.title' => 'Traceroute',
			'trace.stop' => 'Stop',
			'trace.trace' => 'Trace',
			'trace.again' => 'Trace again',
			'trace.destination' => 'Destination',
			'trace.hops' => 'HOPS',
			'trace.answered' => 'ANSWERED',
			'trace.total' => 'TOTAL',
			'trace.thisPhone' => 'This phone',
			'trace.silentOne' => '1 silent hop',
			'trace.yourRouter' => 'Your router',
			'trace.ms' => ({required Object n}) => '${n} ms',
			'trace.silentMany' => ({required Object n}) => '${n} silent hops',
			'trace.hop' => ({required Object n}) => 'Hop ${n}',
			'trace.slowest' => ({required Object ms, required Object hop}) => 'Most of the delay, ${ms} ms, is added at hop ${hop}: usually a long cable between countries, or a busy link.',
			'trace.popular' => 'POPULAR',
			'trace.recent' => 'RECENT',
			'trace.clearRecent' => 'Clear recent',
			'trace.hopsCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} hop', other: '${n} hops', ), 
			'ports.ftpNote' => 'Sends passwords unencrypted.',
			'ports.sshNote' => 'Remote login. Fine if you set it up.',
			'ports.telnetNote' => 'Unencrypted remote login; a favourite of botnets.',
			'ports.dnsNote' => 'Normal on a router.',
			'ports.web' => 'Web (HTTP)',
			'ports.webNote' => 'Usually the router admin page.',
			'ports.webTls' => 'Web (HTTPS)',
			'ports.smb' => 'Windows file sharing',
			'ports.smbNote' => 'Should never face the internet.',
			'ports.rtsp' => 'RTSP camera stream',
			'ports.rtspNote' => 'A camera may be streaming here.',
			'ports.upnpNote' => 'Lets devices open router ports on their own.',
			'ports.rdp' => 'Remote Desktop',
			'ports.rdpNote' => 'A common break-in route.',
			'ports.vncNote' => 'Screen sharing, often without a password.',
			'ports.tr069Note' => 'ISP remote management.',
			'ports.webAlt' => 'Web (alt)',
			'ports.webAltTls' => 'Web (alt HTTPS)',
			'ports.title' => 'Open ports',
			'ports.check' => 'Check ports',
			'ports.address' => 'Device or server address',
			'ports.risky' => 'RISKY',
			'ports.review' => 'REVIEW',
			'ports.normal' => 'NORMAL',
			'ports.info' => ({required Object n}) => 'Checks the ${n} ports that matter on home routers and devices, and explains each open one.\n\nOnly check devices and servers you own or manage.',
			'ports.checking' => ({required Object n}) => 'Checking ${n} ports',
			'ports.yourRouter' => ({required Object ip}) => 'Your router is ${ip}',
			'ports.noneOpen' => ({required Object host}) => 'No common ports open on ${host}.',
			'ports.summary' => ({required Object open, required Object n}) => '${open} open of ${n} checked',
			'ports.riskyCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} risky', other: '${n} risky', ), 
			'ports.noneRisky' => 'Nothing risky',
			'wifi.title' => 'Wi-Fi scanner',
			'wifi.allow' => 'Allow Wi-Fi scanning',
			'wifi.needsPermission' => 'Needs location permission.',
			'wifi.scanning' => 'Scanning',
			'wifi.again' => 'Scan again',
			'wifi.failed' => 'Scan failed',
			'wifi.none' => 'No networks found. Location services may be off.',
			'wifi.hidden' => 'Hidden network',
			'wifi.nearby' => ({required Object n}) => '${n} networks nearby',
			'wifi.permissionInfo' => 'Android only shows nearby Wi-Fi networks to apps with location permission. G VPN uses it to list networks on this phone and nothing else.',
			'wifi.info' => 'Lists networks from the phone\'s last scan. Android allows only a few scans a minute, so a quick re-scan may show the same list. The suggested channel is the least crowded of 1, 6 and 11, the three that do not overlap.',
			'wifi.airMap' => 'Air map',
			'wifi.channels' => 'Channels',
			'wifi.list' => 'List',
			'wifi.secure' => 'Secure',
			'wifi.weakLabel' => 'Weak',
			'wifi.openLabel' => 'Open',
			'wifi.sizeIsWidth' => 'Size = channel width',
			'wifi.strongest' => 'STRONGEST',
			'wifi.openNearby' => 'OPEN NEARBY',
			'wifi.onYourChannel' => 'ON YOUR CHANNEL',
			'wifi.noneNearby' => 'None',
			'wifi.verdictOpen' => 'Anyone nearby can read what is sent',
			'wifi.verdictWep' => 'Old security, easy to break',
			'wifi.verdictWpa' => 'Older security',
			'wifi.verdictWps' => 'WPS is on: easier to break into',
			'wifi.verdictGood' => 'Well protected',
			'wifi.maker' => 'Maker',
			'wifi.address' => 'Hardware address',
			'wifi.privateAddress' => 'Made up by the router for privacy',
			'wifi.you' => 'You',
			'wifi.onClear' => ({required Object name}) => '${name} is on a clear channel',
			'wifi.move' => ({required Object name, required Object n}) => 'Move ${name} to channel ${n}',
			'wifi.clear' => 'Clear',
			'wifi.busy' => 'Busy',
			'wifi.crowded' => 'Crowded',
			'wifi.allBands' => 'All bands',
			'wifi.openOnly' => 'Open only',
			'wifi.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} network', other: '${n} networks', ), 
			'errors.notAuthorized' => 'VPN permission was not granted.',
			'errors.turnedOff' => 'The VPN was turned off by the system or another app.',
			'errors.busy' => 'A permission request is already open.',
			'errors.cancelled' => 'Connection cancelled.',
			'errors.badConfig' => ({required Object error}) => 'This server config is invalid: ${error}',
			'errors.timeout' => 'The server did not answer.',
			'errors.refused' => 'The server refused the connection.',
			'errors.failed' => ({required Object error}) => 'Could not connect: ${error}',
			'errors.tryAnother' => 'Community servers come and go; try another one.',
			'errors.downloadFailed' => 'Could not download this server\'s settings. Check your connection, or pick another server.',
			'scan.mobile' => 'Mobile data',
			'scan.ping' => 'PING',
			'scan.noReply' => 'No reply',
			'scan.dns' => 'DNS',
			'scan.dnsQuad9' => 'Quad9, tunnel',
			'scan.dnsTunnel' => 'In the tunnel',
			'scan.privateDns' => 'Private DNS',
			'scan.dnsIsp' => 'ISP: Visible',
			'scan.network' => 'NETWORK',
			'scan.offline' => 'Offline',
			'scan.open' => 'Open, no password',
			'scan.wep' => 'WEP, broken',
			'scan.owe' => 'Open, encrypted',
			'scan.enterprise' => 'Enterprise',
			'scan.unknown' => 'Unknown',
			'scan.wifi' => 'WI-FI',
			'scan.signIn' => 'Sign-in page',
			'scan.ms' => ({required Object n}) => '${n} ms',
			'scan.covered' => ({required Object what}) => '${what}, covered',
			'legal.privacy' => 'Privacy policy',
			'legal.terms' => 'Terms of use',
			'legal.licences' => 'Open-source licences',
			'update.ready' => 'An update is ready',
			'update.restart' => 'Restart',
			'details.share' => 'Share',
			'details.connectedFor' => ({required Object n}) => 'CONNECTED · ${n} MIN',
			'details.notConnected' => 'NOT CONNECTED',
			'details.downloaded' => 'DOWNLOADED',
			'details.uploaded' => 'UPLOADED',
			'details.lastUsed' => 'LAST USED',
			'details.connection' => 'Connection',
			'details.protocol' => 'Protocol',
			'details.address' => 'Your address',
			'details.dns' => 'DNS',
			'details.routes' => 'Routes',
			'details.allTraffic' => 'All traffic',
			'details.someRoutes' => ({required Object n}) => '${n} networks',
			'details.keepalive' => 'Keepalive',
			'details.serverKey' => 'Server key',
			'details.copy' => 'Copy',
			'details.copied' => 'Copied',
			'details.manage' => 'Manage',
			'details.export' => 'Export for backup',
			'details.exportSub' => 'All your servers in one file',
			'share.title' => ({required Object name}) => 'Share ${name}',
			'share.sameKey' => 'This shares this phone\'s key. Anyone with it can use your server as you, and only one device can be connected with it at a time.',
			'share.scanHint' => 'On the other phone: G VPN, Servers, Scan QR. A saved image works too.',
			'share.saveImage' => 'Save image',
			'share.send' => 'Send',
			'add.title' => 'Add a server',
			'add.subtitle' => 'Any WireGuard server: a router, a VPS or a home server.',
			'add.camera' => 'Scan with camera',
			'add.cameraSub' => 'QR on another screen',
			'add.image' => 'From an image',
			'add.imageSub' => 'Screenshot or saved photo',
			'add.noQr' => 'No QR code found in that image.',
			'add.tip' => 'Got the QR in WhatsApp or Telegram? Tap Share on the image and choose G VPN.',
			'backup.restored' => ({required Object n}) => '${n} servers restored',
			'backup.nothingNew' => 'These servers are already here',
			'gs.proRequired' => 'G Servers are for G VPN Pro subscribers.',
			'gs.off' => 'G Servers are switched off right now.',
			'gs.network' => 'Could not reach G Servers. Check your connection and try again.',
			'gs.active' => 'ACTIVE',
			'gs.servers' => 'G Servers',
			'gs.busy' => ({required Object n}) => '${n}% busy',
			'gs.offline' => 'Offline',
			'gs.devices' => 'Your devices',
			'gs.subtitle' => ({required Object country}) => 'G Server · ${country} · WireGuard',
			'gs.busyLabel' => 'BUSY',
			'gs.status' => 'STATUS',
			'gs.online' => 'Online',
			'gs.onThisServer' => 'On this server',
			'gs.thisPhone' => 'This phone',
			'gs.added' => 'Added · key made here',
			'gs.notAdded' => 'Added when you connect',
			'gs.logs' => 'Activity logs',
			'gs.noneKept' => 'None kept',
			'gs.privacy' => 'The server knows this phone only by its public key. It keeps no record of the sites you visit or the traffic you send.',
			'gs.stepPro1' => 'Install G VPN on the phone, signed in to the same Google account.',
			'gs.stepPro2' => 'Open the Pro tab. Pro unlocks by itself, or tap Restore.',
			'gs.step3' => 'Tap Connect. The phone makes its key and is added to G Servers. No QR, no code.',
			'gs.stepFree1' => 'Install G VPN on the phone.',
			'gs.stepFree2' => 'Open the Pro tab.',
			'gs.devicesIntroPro' => 'Pro follows your Google account. Each phone has its own key, so they never knock each other off.',
			'gs.devicesIntroFree' => 'Each phone has its own key, so phones never knock each other off.',
			'gs.otherPhone' => 'Another phone',
			'gs.lastConnected' => ({required Object when}) => 'Last connected ${when}',
			'gs.noDevices' => 'Connect to a G Server once and your phones appear here.',
			'gs.addTitle' => 'Add a phone or reinstall',
			'gs.idle' => ({required Object n}) => 'A phone that has not connected for ${n} days is removed from G Servers by itself, so an old or reinstalled phone never uses up a place.',
			'gs.limitNote' => ({required Object n}) => 'Up to ${n} phones per plan.',
			'gs.fullTitle' => ({required Object n}) => 'All ${n} places are in use',
			'gs.fullBody' => 'Remove a phone you no longer use, and this one connects straight away.',
			'gs.busyNow' => 'Too many new phones right now. Try again in a little while.',
			'gs.serverFull' => 'This server is full. Try another G Server.',
			'gs.ping' => 'PING',
			'gs.last24' => 'Busy, last 24 hours',
			'gs.noHistory' => 'The chart fills in as the server is used over the day.',
			'gs.chartLabel' => ({required Object max}) => 'Busy over the last 24 hours, at most ${max} percent',
			'gs.hoursAgo' => '24 h ago',
			'gs.now' => 'Now',
			'gs.included' => 'Included',
			'gs.perkServers' => 'Fast, private servers',
			'gs.perkServersSub' => 'WireGuard, run by us, no activity logs',
			'gs.perkLinks' => 'Unlimited link checks',
			'gs.perkLinksSub' => 'Check every link you are sent',
			'gs.devicesOf' => ({required Object used, required Object limit}) => 'Your devices · ${used} of ${limit}',
			'gs.eachKey' => 'Each phone has its own key',
			'gs.connected' => 'Connected',
			'gs.bestNow' => 'BEST FOR YOU NOW',
			'gs.logsShort' => 'LOGS',
			'map.open' => 'Open the map',
			'map.searchCountries' => 'Search countries',
			'map.noMatch' => 'No country matches',
			'map.locate' => 'My location',
			'map.list' => 'List',
			'map.map' => 'Map',
			'map.freeServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} free server', other: '${n} free servers', ), 
			'map.grade.fast' => 'Fast',
			'map.grade.good' => 'Good',
			'map.grade.slow' => 'Slow',
			'map.switchTo' => 'Switch',
			'map.freeServer' => ({required Object n}) => 'Free server ${n}',
			'map.best' => 'BEST',
			'map.gServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} G Server', other: '${n} G Servers', ), 
			'stats.thisWeek' => 'This week',
			'stats.time' => 'Time',
			'stats.data' => 'Data',
			'stats.protected' => 'protected',
			'stats.throughVpn' => 'through the VPN',
			'stats.seeDetails' => 'See details',
			'stats.title' => 'Stats',
			'stats.week' => 'Week',
			'stats.month' => 'Month',
			'stats.protectedLabel' => 'PROTECTED',
			'stats.dataUsed' => 'DATA USED',
			'stats.byServer' => 'BY SERVER',
			'stats.onPhone' => 'Kept on this phone only',
			'stats.reset' => 'Reset',
			'stats.resetTitle' => 'Reset stats?',
			'stats.resetBody' => 'Clears protected time and data on this phone. This cannot be undone.',
			'stats.hm' => ({required Object h, required Object m}) => '${h} h ${m} m',
			'stats.m' => ({required Object m}) => '${m} m',
			'stats.empty' => 'Connect to start counting.',
			'recents.title' => 'Recent',
			'recents.allServers' => 'All servers',
			'recents.free' => 'Free server',
			'recents.yours' => 'Your server',
			'recents.gserver' => 'G Server',
			'presets.title' => 'Presets',
			'presets.all' => 'All',
			'presets.newPreset' => 'New preset',
			'presets.edit' => 'Edit preset',
			'presets.name' => 'Name',
			'presets.namePlaceholder' => 'My preset',
			'presets.server' => 'SERVER',
			'presets.fastestOption' => 'Fastest',
			'presets.countryOption' => 'Country',
			'presets.pickCountry' => 'Pick a country',
			'presets.skipMyCountry' => 'Skip my country',
			'presets.notMine' => 'not my country',
			'presets.protocol' => 'PROTOCOL',
			'presets.auto' => 'Auto',
			'presets.tryNext' => 'If blocked, try the next server',
			'presets.shield' => 'SHIELD',
			'presets.followRules' => 'As in Rules',
			'presets.allApps' => 'Every app through the VPN',
			'presets.allAppsShort' => 'all apps',
			'presets.save' => 'Save',
			'presets.delete' => 'Delete',
			'presets.reset' => 'Reset to default',
			'presets.none' => 'No free server fits this preset right now.',
			'presets.names.fastest' => 'Fastest',
			'presets.names.unblock' => 'Unblock',
			'presets.names.streaming' => 'Streaming',
			'presets.names.privacy' => 'Privacy max',
			'shield.title' => 'Shield',
			'shield.sub' => 'Works while you are connected',
			'shield.off' => 'Off',
			'shield.offSub' => 'The server\'s own DNS',
			'shield.malware' => 'Malware',
			'shield.malwareSub' => 'Blocks harmful and phishing sites',
			'shield.family' => 'Malware and adult sites',
			'shield.familySub' => 'Also blocks adult content',
			'shield.custom' => 'Custom DNS',
			'shield.customSub' => 'Your own DNS servers',
			'shield.customHint' => 'IP address, for example 1.1.1.1',
			'shield.invalid' => 'Enter one or two IP addresses.',
			'checks.title' => 'Safety checks',
			'checks.password' => 'Password',
			'checks.link' => 'Link',
			'checks.pwTitle' => 'Was it leaked?',
			'checks.pwHint' => 'Password to check',
			'checks.showPassword' => 'Show password',
			'checks.hidePassword' => 'Hide password',
			'checks.check' => 'Check',
			'checks.leaked' => 'Found in leaks',
			'checks.seen' => ({required Object n}) => 'Seen ${n} times',
			'checks.leakedAdvice' => 'Change it everywhere you use it, starting with email and banking.',
			'checks.notFound' => 'Not in known leaks',
			'checks.notFoundAdvice' => 'A good sign, not a guarantee. Use a different password for every account.',
			'checks.failed' => 'Could not check. Try again.',
			'checks.private' => 'Your password never leaves this phone',
			'checks.linkTitle' => 'Is this link safe?',
			'checks.linkHint' => 'Link to check',
			'checks.paste' => 'Paste',
			'checks.danger' => 'Dangerous link',
			'checks.dangerAdvice' => 'Do not open it or enter any details.',
			'checks.clear' => 'Not on known malware or phishing lists',
			'checks.clearAdvice' => 'Still look at the address before you sign in anywhere.',
			'checks.goesTo' => 'Goes to',
			'checks.redirects' => 'Redirects',
			'checks.invalid' => 'That does not look like a web address.',
			'checks.busy' => 'Too many checks. Try again in a while.',
			'checks.unavailable' => 'Link check is not available right now.',
			'checks.listed' => 'Known for malware or phishing',
			'checks.missing' => 'No website at this address',
			'checks.missingAdvice' => 'Check the spelling: scams often use look-alike addresses.',
			'checks.left' => ({required Object n, required Object total}) => '${n} of ${total} free checks left this month',
			'checks.usedUp' => 'You have used this month\'s free link checks',
			'checks.usedUpSub' => 'Pro has unlimited link checks. Your free checks come back on the 1st.',
			'checks.getPro' => 'Get Pro',
			'toolSettings.title' => 'Tool settings',
			'toolSettings.askMobile' => 'Ask before speed tests on mobile data',
			'toolSettings.askMobileSub' => 'A test can use over 100 MB on a fast connection',
			'toolSettings.mobileTitle' => 'Use mobile data?',
			'toolSettings.mobileBody' => 'A speed test can use over 100 MB on a fast connection.',
			'toolSettings.mobileGo' => 'Test',
			'toolSettings.safe' => 'Safe',
			'toolSettings.unsafe' => 'Unsafe',
			'toolSettings.devices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} device', other: '${n} devices', ), 
			'toolSettings.hideMac' => 'Hide hardware addresses',
			'toolSettings.hideMacSub' => 'Shows only the maker part of MAC addresses',
			'toolSettings.names' => 'Show names of routers and servers',
			'toolSettings.namesSub' => 'Looks up names for addresses in Traceroute',
			'toolSettings.remember' => 'Remember recent hosts',
			'toolSettings.rememberSub' => 'For Traceroute',
			'toolSettings.clear' => 'Clear tool history',
			'toolSettings.clearSub' => 'Forgets recent hosts and which devices each network had',
			'toolSettings.clearGo' => 'Clear',
			'security.tab' => 'Security',
			'security.good' => 'Good',
			'security.fair' => 'Fair',
			'security.atRisk' => 'At risk',
			'security.allClear' => 'Nothing to fix',
			'security.checked' => ({required Object time}) => 'Checked ${time}',
			'security.trend' => 'LAST TWO WEEKS',
			'security.checking' => 'Checking this network',
			'security.snoozed' => 'Snoozed',
			'security.remindLater' => 'Remind me later',
			'security.unsnooze' => 'Remind me now',
			'security.review' => 'Review',
			'security.confirmGo' => 'Confirm',
			'security.scanGo' => 'Scan',
			'security.look' => 'Look',
			'security.connectGo' => 'Connect',
			'security.checkAgain' => 'Check again',
			'security.wifiOpen' => 'Wi-Fi is open',
			'security.wifiOpenDetail' => 'Anyone nearby can see what is sent',
			'security.wifiWep' => 'Wi-Fi uses WEP',
			'security.wifiWepDetail' => 'Old security, easy to break',
			'security.wifiOwe' => 'Wi-Fi uses Enhanced Open',
			'security.wifiOweDetail' => 'Encrypted, but anyone can join',
			'security.wifiSecure' => 'Wi-Fi encryption',
			'security.wifiUnknown' => 'Wi-Fi security unknown',
			'security.wifiUnknownDetail' => 'Android did not say how it is protected',
			'security.wps' => 'WPS is on',
			'security.wpsDetail' => 'Turn it off in the router\'s settings',
			'security.upnpOff' => 'Router keeps ports closed',
			'security.upnpOffDetail' => 'UPnP is off',
			'security.upnpOn' => 'Router lets devices open ports',
			'security.upnpOnDetail' => 'UPnP is on',
			'security.portsOk' => 'No risky ports on the router',
			'security.portsRisky' => 'Risky ports open on the router',
			'security.scanFirst' => 'Scan to see who is here',
			'security.scanFirstDetail' => 'Unknown devices count against the score',
			'security.notMineDetail' => 'Check your router\'s device list',
			'security.confirmDetail' => 'Mark the ones that are yours',
			'security.devicesOk' => 'Every device is known',
			'security.devicesOkDetail' => 'You confirmed each one',
			'security.camera' => 'A camera is on this network',
			'security.dnsHijack' => 'Unknown names are redirected',
			'security.dnsHijackDetail' => 'Your provider or router rewrites lookups',
			'security.dnsOk' => 'DNS answers normally',
			'security.dnsOkDetail' => 'No sign of redirection',
			'security.vpnOn' => 'VPN is on',
			'security.vpnOnDetail' => 'Traffic leaves through the tunnel',
			'security.vpnOff' => 'VPN is off',
			'security.vpnOffDetail' => 'Your provider sees every site',
			'security.toFix' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} thing to fix', other: '${n} things to fix', ), 
			'security.upnpOpened' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} port opened by devices', other: '${n} ports opened by devices', ), 
			'security.portsChecked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} port checked', other: '${n} ports checked', ), 
			'security.notMine' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} device is not yours', other: '${n} devices are not yours', ), 
			'security.confirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} device to confirm', other: '${n} devices to confirm', ), 
			'providers.tab' => 'Internet',
			'providers.unavailable' => 'Could not reach the provider list. Check your connection.',
			'providers.cached' => 'As of your last check without the VPN',
			'providers.notEnough' => 'Not enough ratings yet',
			'providers.yourRating' => 'Your rating this month',
			'providers.yourSpeed' => 'YOUR SPEED',
			'providers.runTest' => 'Run a speed test',
			'providers.aboutAverage' => 'About average here',
			'providers.aboveAverage' => ({required Object pct}) => '${pct}% above the local average',
			'providers.belowAverage' => ({required Object pct}) => '${pct}% below the local average',
			'providers.call' => 'Call',
			'providers.website' => 'Website',
			'providers.outages' => 'Outages',
			'providers.rate' => 'Rate',
			'providers.changeRating' => 'Change rating',
			'providers.compare' => 'Compare',
			'providers.rateTitle' => ({required Object name}) => 'Rate ${name}',
			'providers.oncePerMonth' => 'One rating a month',
			'providers.tapStars' => 'Tap the stars',
			'providers.verified' => ({required Object mbps}) => 'Verified by your speed test: ${mbps} Mbps',
			'providers.busy' => 'Too many ratings from here. Try later.',
			'providers.failed' => 'Could not post. Try again.',
			'providers.post' => 'Post rating',
			'providers.nearTitle' => 'Providers near you',
			'providers.slower' => ({required Object pct}) => 'Your download is ${pct}% below your provider\'s average here',
			'providers.inPlace' => ({required Object place}) => 'Home internet in ${place}',
			'providers.byRating' => 'Rating',
			'providers.bySpeed' => 'Speed',
			'providers.footnote' => 'Speeds are averages of G VPN speed tests',
			'providers.noneNearby' => 'No ratings near you yet. Be the first.',
			'providers.you' => 'You',
			'providers.topRated' => 'Top rated',
			'providers.starsOf' => ({required Object n}) => '${n} out of 5',
			'providers.tags.fast' => 'Fast',
			'providers.tags.reliable' => 'Reliable',
			'providers.tags.support' => 'Good support',
			'providers.tags.price' => 'Fair price',
			'providers.tags.slowEvenings' => 'Slow evenings',
			'providers.tags.drops' => 'Drops often',
			'providers.tags.poorSupport' => 'Poor support',
			'providers.tags.pricey' => 'Pricey',
			'providers.words.bad' => 'Bad',
			'providers.words.poor' => 'Poor',
			'providers.words.okay' => 'Okay',
			'providers.words.good' => 'Good',
			'providers.words.great' => 'Great',
			'providers.ratings' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} rating', other: '${n} ratings', ), 
			'alerts.channel' => 'Alerts',
			'alerts.title' => 'Alerts',
			'alerts.markAllRead' => 'Mark all read',
			'alerts.clearAll' => 'Clear all',
			'alerts.thisNetwork' => 'this network',
			'alerts.openWifiTitle' => ({required Object name}) => 'You joined an open Wi-Fi: ${name}',
			'alerts.openWifiBody' => 'Anyone nearby can see what is sent. Turn on G VPN.',
			'alerts.reportTitle' => 'Your weekly report is ready',
			'alerts.reportBody' => ({required Object hours}) => '${hours} hours protected last week',
			'alerts.blockedTitle' => ({required Object name}) => '${name} is blocked here',
			'alerts.blockedBody' => 'It answers through the VPN',
			'alerts.kinds.newDevice' => 'New devices on my Wi-Fi',
			'alerts.kinds.openWifi' => 'Open or weak Wi-Fi',
			'alerts.kinds.blocked' => 'Blocked apps',
			'alerts.kinds.report' => 'Weekly report',
			'alerts.kinds.breach' => 'Breaches',
			'alerts.newDeviceTitle' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'New device on ${network}', other: '${n} new devices on ${network}', ), 
			'alerts.settings' => 'Alert settings',
			'alerts.look' => 'Look',
			'alerts.read' => 'Read',
			'alerts.open' => 'Open',
			'alerts.check' => 'Check',
			'alerts.today' => 'TODAY',
			'alerts.thisWeek' => 'THIS WEEK',
			'alerts.earlier' => 'EARLIER',
			'alerts.all' => 'All',
			'alerts.quiet' => 'All quiet',
			'alerts.quietSub' => 'Nothing needed you lately',
			'alerts.breachTitle' => ({required Object name}) => 'New breach: ${name}',
			'alerts.status.background' => 'Every few hours',
			'alerts.status.checked' => ({required Object time}) => 'Last checked ${time}',
			'alerts.status.wifi' => 'Every network you join',
			'alerts.status.blocked' => 'When Service status runs',
			'alerts.status.report' => 'Every Monday',
			'report.title' => 'Weekly report',
			'report.share' => 'Share as image',
			'report.shareText' => 'My week with G VPN',
			'report.safer' => 'A safer week',
			'report.moreProtected' => 'More protected than last week',
			'report.yourWeek' => 'Your week',
			'report.soFar' => ({required Object range}) => '${range}, so far',
			'report.protected' => 'Protected',
			'report.data' => 'Data',
			'report.security' => 'Security',
			'report.speed' => 'Best speed',
			'report.noScore' => 'Not checked',
			'report.noTest' => 'No test',
			'report.bestDirect' => 'Direct test',
			'report.moreThan' => ({required Object d}) => '${d} more than last week',
			'report.lessThan' => ({required Object d}) => '${d} less than last week',
			'report.protectedTime' => 'PROTECTED TIME',
			'report.mostUsed' => ({required Object name}) => 'Most used: ${name}',
			'report.quiet' => 'A quiet week: nothing needed you',
			'report.newDevices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} new device joined', other: '${n} new devices joined', ), 
			'report.openWifi' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Joined ${n} open Wi-Fi', other: 'Joined ${n} open Wi-Fi networks', ), 
			'report.blocked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} app blocked', other: '${n} apps blocked', ), 
			'report.breaches' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} big new breach', other: '${n} big new breaches', ), 
			'breaches.title' => 'Data breaches',
			'breaches.info' => 'The latest data breaches, from Have I Been Pwned\'s public list. Nothing about you is sent: the list is the same for everyone.\n\nIf you had an account with a breached site, change that password, and anywhere you reused it.',
			'breaches.unavailable' => 'Could not load the breach list. Check your connection.',
			'breaches.biggest' => 'BIGGEST THIS MONTH',
			'breaches.newest' => 'Newest',
			'breaches.biggestSort' => 'Biggest',
			'breaches.withPasswords' => 'With passwords',
			'breaches.passwordsMark' => 'PASSWORDS',
			'breaches.one' => 'Breach',
			_ => null,
		} ?? switch (path) {
			'breaches.checkPassword' => 'Check a password',
			'breaches.verified' => 'Verified',
			'breaches.hasPasswords' => 'Has passwords',
			'breaches.accountsLabel' => 'Accounts',
			'breaches.happened' => 'Happened',
			'breaches.published' => 'Published',
			'breaches.website' => 'Website',
			'breaches.leaked' => 'WHAT LEAKED',
			'breaches.ifUsed' => 'IF YOU USED IT',
			'breaches.stepPassword' => 'Change the password you used there',
			'breaches.stepReuse' => 'Change it anywhere you used the same one',
			'breaches.stepTwoStep' => 'Turn on two-step sign-in where you can',
			'breaches.stepScams' => 'Expect scam calls and texts',
			'breaches.accounts' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${count} account', other: '${count} accounts', ), 
			'breaches.worldwide' => ({required Object n}) => 'Worldwide · ${n}',
			'breaches.noneHere' => 'No breaches from here in the recent list.',
			'breaches.bigMap' => 'Bigger map',
			'breaches.showInList' => 'Show in list',
			'breaches.mapTitle' => 'Breach map',
			'breaches.zoomIn' => 'Zoom in',
			'breaches.zoomOut' => 'Zoom out',
			'breaches.wholeWorld' => 'Whole world',
			'breaches.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} breach', other: '${n} breaches', ), 
			'breaches.findCountry' => 'Find a country',
			'breaches.seeAll' => 'See all',
			'breaches.search' => 'Search breaches',
			'blocked.title' => 'What\'s blocked',
			'blocked.info' => 'Tests well-known sites from this phone, without the VPN, and shows which ones this network blocks and how.\n\nWrong address: the network\'s name lookup gives a false answer.\n\nCut off: the connection is reset as it starts.\n\nNo answer: nothing comes back.\n\nBlock page: something else answers in the site\'s place.\n\nThe test shows where a site is blocked, not who blocked it. Nothing is stored or sent anywhere.',
			'blocked.thisNetwork' => 'This network',
			'blocked.country' => 'Your country',
			'blocked.question' => 'What\'s blocked here?',
			'blocked.testingOn' => 'TESTING ON',
			'blocked.vpnOn' => 'VPN ON',
			'blocked.turnOff' => 'Turn off G VPN to test',
			'blocked.test' => 'Test this network',
			'blocked.stop' => 'Stop',
			'blocked.sitesToTest' => ({required Object n}) => 'SITES TO TEST · ${n}',
			'blocked.ofSites' => ({required Object n}) => 'of ${n} sites',
			'blocked.blockedCount' => ({required Object n}) => '${n} BLOCKED',
			'blocked.openCount' => ({required Object n}) => '${n} OPEN',
			'blocked.noneBlocked' => ({required Object network}) => 'Nothing blocked on ${network}',
			'blocked.openOf' => ({required Object open, required Object total}) => '${open} of ${total} open',
			'blocked.allWork' => 'ALL WORK WITH G VPN',
			'blocked.blockedHeading' => 'BLOCKED',
			'blocked.byKind' => 'BY KIND',
			'blocked.worksVpn' => 'Works with VPN',
			'blocked.failsVpn' => 'Blocked through VPN too',
			'blocked.checkVpn' => 'Check through G VPN',
			'blocked.connect' => 'Connect G VPN',
			'blocked.again' => 'Test again',
			'blocked.withoutVpn' => 'WITHOUT VPN',
			'blocked.throughVpn' => 'THROUGH G VPN',
			'blocked.notChecked' => 'Not checked',
			'blocked.opens' => 'Opens',
			'blocked.stillBlocked' => 'Blocked',
			'blocked.whatHappened' => 'WHAT HAPPENED',
			'blocked.countryBlocked' => ({required Object country}) => 'sites blocked in ${country}',
			'blocked.countrySub' => 'Found by volunteers\' tests in the last 30 days',
			'blocked.countryNone' => 'No blocked sites reported in the last 30 days.',
			'blocked.countryUnavailable' => 'Could not load the country\'s results. Check your connection.',
			'blocked.confirmed' => 'BLOCKED',
			'blocked.oftenFails' => 'OFTEN FAILS',
			'blocked.kinds.social' => 'Social',
			'blocked.kinds.messaging' => 'Messaging',
			'blocked.kinds.news' => 'News',
			'blocked.kinds.video' => 'Video and music',
			'blocked.kinds.privacy' => 'Privacy tools',
			'blocked.how.dns' => 'Wrong address',
			'blocked.how.reset' => 'Cut off',
			'blocked.how.timeout' => 'No answer',
			'blocked.how.page' => 'Block page',
			'blocked.how.open' => 'Open',
			'blocked.fail.noAnswer' => 'no answer',
			'blocked.fail.refused' => 'refused',
			'blocked.fail.cutOff' => ({required Object s}) => 'cut off after ${s} s',
			'blocked.fail.wrongCert' => 'wrong certificate',
			'blocked.steps.lookup' => 'Name lookup',
			'blocked.steps.connect' => 'Connect',
			'blocked.steps.handshake' => 'Secure handshake',
			'blocked.consent.title' => 'Before the first test',
			'blocked.consent.body' => 'The test opens each site from this phone, without the VPN, the way a browser would.',
			'blocked.consent.noticeTitle' => 'It can be noticed',
			'blocked.consent.notice' => 'Your provider sees these sites being opened. In some countries visiting them, even to test, can draw attention. Only test where you feel safe to.',
			'blocked.consent.ok' => 'I understand, test',
			'blocked.someBlocked' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} site blocked on ${network}', other: '${n} sites blocked on ${network}', ), 
			'blocked.tests' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} test', other: '${n} tests', ), 
			_ => null,
		};
	}
}
