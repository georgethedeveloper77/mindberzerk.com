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
class TranslationsRu extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsRu({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ru,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ru>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsRu _root = this; // ignore: unused_field

	@override 
	TranslationsRu $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsRu(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$ru common = _Translations$common$ru._(_root);
	@override late final _Translations$nav$ru nav = _Translations$nav$ru._(_root);
	@override late final _Translations$home$ru home = _Translations$home$ru._(_root);
	@override late final _Translations$servers$ru servers = _Translations$servers$ru._(_root);
	@override late final _Translations$pro$ru pro = _Translations$pro$ru._(_root);
	@override late final _Translations$rules$ru rules = _Translations$rules$ru._(_root);
	@override late final _Translations$apps$ru apps = _Translations$apps$ru._(_root);
	@override late final _Translations$location$ru location = _Translations$location$ru._(_root);
	@override late final _Translations$addServer$ru addServer = _Translations$addServer$ru._(_root);
	@override late final _Translations$button$ru button = _Translations$button$ru._(_root);
	@override late final _Translations$wol$ru wol = _Translations$wol$ru._(_root);
	@override late final _Translations$speed$ru speed = _Translations$speed$ru._(_root);
	@override late final _Translations$router$ru router = _Translations$router$ru._(_root);
	@override late final _Translations$network$ru network = _Translations$network$ru._(_root);
	@override late final _Translations$devices$ru devices = _Translations$devices$ru._(_root);
	@override late final _Translations$ping$ru ping = _Translations$ping$ru._(_root);
	@override late final _Translations$status$ru status = _Translations$status$ru._(_root);
	@override late final _Translations$tools$ru tools = _Translations$tools$ru._(_root);
	@override late final _Translations$trace$ru trace = _Translations$trace$ru._(_root);
	@override late final _Translations$ports$ru ports = _Translations$ports$ru._(_root);
	@override late final _Translations$wifi$ru wifi = _Translations$wifi$ru._(_root);
	@override late final _Translations$errors$ru errors = _Translations$errors$ru._(_root);
	@override late final _Translations$scan$ru scan = _Translations$scan$ru._(_root);
	@override late final _Translations$legal$ru legal = _Translations$legal$ru._(_root);
	@override late final _Translations$update$ru update = _Translations$update$ru._(_root);
	@override late final _Translations$details$ru details = _Translations$details$ru._(_root);
	@override late final _Translations$share$ru share = _Translations$share$ru._(_root);
	@override late final _Translations$add$ru add = _Translations$add$ru._(_root);
	@override late final _Translations$backup$ru backup = _Translations$backup$ru._(_root);
	@override late final _Translations$gs$ru gs = _Translations$gs$ru._(_root);
	@override late final _Translations$map$ru map = _Translations$map$ru._(_root);
	@override late final _Translations$stats$ru stats = _Translations$stats$ru._(_root);
	@override late final _Translations$recents$ru recents = _Translations$recents$ru._(_root);
	@override late final _Translations$presets$ru presets = _Translations$presets$ru._(_root);
	@override late final _Translations$shield$ru shield = _Translations$shield$ru._(_root);
	@override late final _Translations$checks$ru checks = _Translations$checks$ru._(_root);
	@override late final _Translations$toolSettings$ru toolSettings = _Translations$toolSettings$ru._(_root);
	@override late final _Translations$security$ru security = _Translations$security$ru._(_root);
	@override late final _Translations$providers$ru providers = _Translations$providers$ru._(_root);
	@override late final _Translations$alerts$ru alerts = _Translations$alerts$ru._(_root);
	@override late final _Translations$report$ru report = _Translations$report$ru._(_root);
	@override late final _Translations$breaches$ru breaches = _Translations$breaches$ru._(_root);
	@override late final _Translations$blocked$ru blocked = _Translations$blocked$ru._(_root);
}

// Path: common
class _Translations$common$ru extends Translations$common$en {
	_Translations$common$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get gotIt => 'Понятно';
	@override String get about => 'О приложении';
	@override String get connect => 'Подключить';
	@override String get connected => 'Подключено';
	@override String get retry => 'Повторить';
	@override String get ok => 'ОК';
	@override String get remove => 'Удалить';
	@override String get cancel => 'Отмена';
	@override String get continueLabel => 'Продолжить';
	@override String get notNow => 'Не сейчас';
	@override String get openSettings => 'Открыть настройки';
	@override String get close => 'Закрыть';
	@override String get off => 'Выкл.';
	@override String get changesReconnect => 'Изменения переподключат VPN';
}

// Path: nav
class _Translations$nav$ru extends Translations$nav$en {
	_Translations$nav$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get vpn => 'VPN';
	@override String get servers => 'Серверы';
	@override String get tools => 'Инструменты';
	@override String get rules => 'Правила';
	@override String get pro => 'Pro';
}

// Path: home
class _Translations$home$ru extends Translations$home$en {
	_Translations$home$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$status$ru status = _Translations$home$status$ru._(_root);
	@override String resumesAt({required Object time}) => 'Возобновится в ${time} · нажмите, чтобы продолжить сейчас';
	@override String get ipFailed => 'Не удалось проверить IP';
	@override String get ipChecking => 'Проверка IP';
	@override String get themeSystem => 'Тема: как в телефоне';
	@override String get themeLight => 'Тема: светлая';
	@override String get themeDark => 'Тема: тёмная';
	@override String get free => 'Бесплатно';
	@override String get pickServer => 'Выберите сервер';
	@override late final _Translations$home$network$ru network = _Translations$home$network$ru._(_root);
	@override late final _Translations$home$card$ru card = _Translations$home$card$ru._(_root);
	@override late final _Translations$home$tiles$ru tiles = _Translations$home$tiles$ru._(_root);
	@override late final _Translations$home$fastest$ru fastest = _Translations$home$fastest$ru._(_root);
	@override late final _Translations$home$ip$ru ip = _Translations$home$ip$ru._(_root);
}

// Path: servers
class _Translations$servers$ru extends Translations$servers$en {
	_Translations$servers$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Серверы';
	@override String get aboutServers => 'О серверах';
	@override late final _Translations$servers$tabs$ru tabs = _Translations$servers$tabs$ru._(_root);
	@override late final _Translations$servers$sheet$ru sheet = _Translations$servers$sheet$ru._(_root);
	@override late final _Translations$servers$badges$ru badges = _Translations$servers$badges$ru._(_root);
	@override late final _Translations$servers$filters$ru filters = _Translations$servers$filters$ru._(_root);
	@override String get loadFailed => 'Не удалось загрузить список';
	@override String get noServers => 'Сейчас серверов нет';
	@override String get best => 'ЛУЧШИЙ ДЛЯ ВАС СЕЙЧАС';
	@override String get topRanked => 'Лучший в рейтинге сейчас';
	@override String get addHeading => 'ДОБАВИТЬ СЕРВЕР';
	@override String get scanQr => 'Сканировать QR';
	@override String get importFile => 'Импорт файла';
	@override String get paste => 'Вставить';
	@override late final _Translations$servers$own$ru own = _Translations$servers$own$ru._(_root);
	@override String get configBroken => 'Конфигурация требует внимания';
	@override String get connectedBadge => 'ПОДКЛЮЧЕНО';
	@override String get scannedServer => 'Отсканированный сервер';
	@override String get scanFailedTitle => 'Не удалось сканировать';
	@override String get scanFailedBody => 'Сканер недоступен на этом телефоне.';
	@override String get importFailedTitle => 'Не удалось импортировать';
	@override String get importFailedBody => 'Не удалось прочитать этот файл.';
	@override String get renameTitle => 'Переименовать сервер';
	@override String get nameHint => 'Название, например Домашний роутер';
	@override String get save => 'Сохранить';
	@override String get rename => 'Переименовать';
	@override String get disconnect => 'Отключить';
	@override String get more => 'Ещё';
	@override String get justNow => 'только что';
	@override String minutesAgo({required Object n}) => '${n} мин назад';
	@override String hoursAgo({required Object n}) => '${n} ч назад';
	@override String daysAgo({required Object n}) => '${n} дн. назад';
	@override String get neverUsed => 'Ещё не использовался';
	@override String lastUsed({required Object when}) => 'Использовался ${when}';
	@override String get disconnectFirst => 'Сначала отключитесь, чтобы удалить';
	@override String get removeConfirm => 'Удалить этот сервер из G VPN? Его настройки удалятся с этого телефона; сам сервер не изменится.';
	@override String get gTab => 'G Servers';
	@override String get search => 'Поиск стран';
	@override String get noMatch => 'Нет подходящих серверов.';
	@override String bestPing({required Object ms}) => 'лучший ${ms} мс';
	@override String get bestTag => 'ЛУЧШИЙ';
	@override String get ownHero => 'Наши серверы';
	@override String get ownHeroSub => 'Быстрее, приватно, у каждого телефона свой ключ';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} сервер',
		few: '${n} сервера',
		many: '${n} серверов',
		other: '${n} сервера',
	);
	@override String showAll({required Object n}) => 'Показать все ${n}';
	@override String get showFewer => 'Свернуть';
	@override String get fastTab => 'Быстрые';
	@override String get fastestFree => 'Самые быстрые бесплатные';
}

// Path: pro
class _Translations$pro$ru extends Translations$pro$en {
	_Translations$pro$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get owned => 'У вас есть Pro';
	@override String get waitingPlay => 'Ожидание Google Play';
	@override String startTrial({required Object days}) => 'Начать бесплатный период на ${days} дн.';
	@override String get restore => 'Восстановить';
	@override String save({required Object pct}) => 'ЭКОНОМИЯ ${pct}%';
	@override String get yearly => 'На год';
	@override String get monthly => 'На месяц';
	@override String get billedMonthly => 'оплата ежемесячно';
	@override String daysFree({required Object days}) => '${days} дн. бесплатно';
	@override String perMonth({required Object price}) => '${price} в месяц';
	@override String get title => 'G VPN Pro';
	@override String get renewGeneric => 'Подписки продлеваются автоматически до отмены. Отмена в любой момент в Google Play.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} дн. бесплатно, затем ${price} за ${period}. Продлевается автоматически до отмены; отмените в Google Play не позднее чем за день до конца пробного периода, чтобы не было списания.';
	@override String renew({required Object price, required Object period}) => '${price} за ${period}. Продлевается автоматически до отмены; отмена в любой момент в Google Play.';
	@override String get year => 'год';
	@override String get month => 'месяц';
	@override String get manage => 'Управление подпиской';
	@override late final _Translations$pro$free$ru free = _Translations$pro$free$ru._(_root);
	@override String get heroLine => 'Наши быстрые серверы и все проверки без ограничений';
	@override String get start => 'Начать Pro';
	@override String get compareFree => 'БЕСПЛАТНО';
	@override String get comparePro => 'PRO';
	@override String get rowFreeServers => 'Бесплатные серверы';
	@override String get rowTools => 'Тест скорости, инструменты, проверка Wi-Fi';
	@override String get rowGServers => 'G Servers, без журналов';
	@override String get rowLinks => 'Проверка ссылок';
	@override String linksFree({required Object n}) => '${n} в месяц';
	@override String get unlimited => 'Без ограничений';
}

// Path: rules
class _Translations$rules$ru extends Translations$rules$en {
	_Translations$rules$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Правила';
	@override late final _Translations$rules$info$ru info = _Translations$rules$info$ru._(_root);
	@override String get protection => 'Защита';
	@override String get shield => 'Щит';
	@override String get privateDns => 'Щит без VPN';
	@override String get privateDnsSub => 'Скопировать dns.quad9.net для частного DNS';
	@override String get privateDnsCopied => 'dns.quad9.net скопирован';
	@override String get privateDnsHow => 'Откройте Настройки, найдите «Частный DNS», выберите «Имя хоста поставщика частного DNS» и вставьте его.';
	@override String get stay => 'Оставаться на связи';
	@override String get alwaysOn => 'Постоянный VPN';
	@override String get alwaysOnSub => 'Android перезапустит G VPN, если он остановится';
	@override String get battery => 'Батарея';
	@override String get batteryOk => 'Без ограничений';
	@override String get batteryRestricted => 'Ограничено: может остановиться в фоне';
	@override String get autoConnect => 'Автоподключение';
	@override String get autoOff => 'Выкл.';
	@override String get autoOffSub => 'Только по нажатию';
	@override String get autoOpen => 'Публичные Wi-Fi';
	@override String get autoOpenSub => 'Открытые, WEP или с входом через страницу';
	@override String get autoAny => 'Любой Wi-Fi';
	@override String get autoAnySub => 'Любая сеть Wi-Fi';
	@override String get apps => 'Приложения';
	@override String get appsDirect => 'Приложения напрямую';
	@override String get appsNone => 'Все приложения используют VPN';
	@override String appsSome({required Object n}) => '${n} прилож. без VPN';
	@override String get appearance => 'Оформление';
	@override String get themePhone => 'Как в телефоне';
	@override String get themeLight => 'Светлая';
	@override String get themeDark => 'Тёмная';
	@override String get about => 'О приложении';
}

// Path: apps
class _Translations$apps$ru extends Translations$apps$en {
	_Translations$apps$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Приложения напрямую';
	@override String get sheetSubtitle => 'Выбранные приложения подключаются без VPN. Всё остальное остаётся защищённым.';
	@override String get whyTitle => 'Зачем исключать приложение';
	@override String get whyBody => 'Банки и платёжные приложения часто блокируют адреса VPN, поэтому платежи через VPN могут не проходить. Некоторые местные сервисы работают только из вашей страны.';
	@override String get favouritesBody => 'Отмечайте звёздочкой приложения, которые часто меняете; они останутся сверху.';
	@override String get whileConnected => 'Во время подключения';
	@override String get whileConnectedBody => 'Изменение этого списка ненадолго переподключает VPN.';
	@override String search({required Object n}) => 'Поиск среди ${n} приложений';
	@override String get skipping => 'Без VPN';
	@override String get skippingNone => 'Нет. Все приложения идут через VPN.';
	@override String protectAgain({required Object app}) => 'Снова защитить ${app}';
	@override String get banking => 'Банки и платежи';
	@override String bankingFound({required Object n}) => 'Найдено ${n}, могут блокировать VPN';
	@override String get addAll => 'Добавить все';
	@override String get favourites => 'Избранное';
	@override String get all => 'Все приложения';
	@override String found({required Object n}) => 'Найдено: ${n}';
	@override String get noMatch => 'Приложений не найдено.';
	@override String showAll({required Object n}) => 'Показать все (${n})';
	@override String get skips => 'Без VPN';
	@override String get unstar => 'Убрать из избранного';
	@override String get star => 'Добавить в избранное';
}

// Path: location
class _Translations$location$ru extends Translations$location$en {
	_Translations$location$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Доступ к геолокации для Wi-Fi';
	@override String get useHome => 'Показывать имя Wi-Fi на главном экране';
	@override String get useScan => 'Сканировать ближайшие сети и каналы';
	@override String get private => 'Остаётся на этом телефоне. Ваше местоположение не собирается.';
	@override String get switchTitle => 'Включите геолокацию';
	@override String get switchBody => 'Android скрывает имена Wi-Fi, пока геолокация выключена';
}

// Path: addServer
class _Translations$addServer$ru extends Translations$addServer$en {
	_Translations$addServer$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get clipboardEmpty => 'Буфер обмена пуст.';
	@override String get title => 'Добавить свой сервер';
	@override String get body => 'Вставьте конфигурацию WireGuard с вашего роутера, VPS или домашнего сервера.';
	@override String get nameHint => 'Название, например Домашний роутер';
	@override String get paste => 'Вставить';
	@override String get save => 'Сохранить сервер';
	@override String notWireguard({required Object error}) => 'Это не конфигурация WireGuard: ${error}';
}

// Path: button
class _Translations$button$ru extends Translations$button$en {
	_Translations$button$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get stop => 'Стоп';
	@override String get connecting => 'Подключение';
	@override String get stopping => 'Отключение';
	@override String get connect => 'Подключить';
	@override String get disconnect => 'Отключить';
}

// Path: wol
class _Translations$wol$ru extends Translations$wol$en {
	_Translations$wol$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get info => 'Включает компьютер или NAS в этой сети Wi-Fi, если в его настройках включён Wake on LAN. Телефон должен быть в той же сети; сначала выключите VPN.';
	@override String get badMac => 'Это не MAC-адрес. Он выглядит так: AA:BB:CC:DD:EE:FF.';
	@override String get sent => 'Сигнал отправлен. Устройство должно включиться в течение минуты.';
	@override String get title => 'Wake on LAN';
	@override String get mac => 'MAC-адрес';
	@override String failed({required Object error}) => 'Не удалось отправить: ${error}';
	@override String get computer => 'Компьютер';
	@override String get pick => 'Выберите устройство для включения';
	@override String waking({required Object name}) => 'Включаем ${name}';
	@override String get yours => 'ВАШИ УСТРОЙСТВА';
	@override String wakeNamed({required Object name}) => 'Включить ${name}';
	@override String get removeHint => 'Удерживайте устройство, чтобы удалить';
	@override String get add => 'ДОБАВИТЬ УСТРОЙСТВО';
	@override String get name => 'Название';
	@override String get saveWake => 'Сохранить и включить';
}

// Path: speed
class _Translations$speed$ru extends Translations$speed$en {
	_Translations$speed$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get download => 'Загрузка';
	@override String get upload => 'Отдача';
	@override String get finding => 'Поиск сервера';
	@override String get throughVpn => 'Через VPN';
	@override String get directNoVpn => 'Напрямую, без VPN';
	@override String get title => 'Тест скорости';
	@override String get stop => 'Стоп';
	@override String get start => 'Начать тест';
	@override String get again => 'Повторить тест';
	@override String get viaVpn => 'Через VPN';
	@override String get direct => 'Напрямую';
	@override String get mbps => 'Мбит/с';
	@override String get ping => 'ПИНГ';
	@override String get vsDirect => 'К НАПРЯМУЮ';
	@override String get compare => 'Сравнить с провайдерами поблизости';
	@override String get compareSub => 'Передаёт только скорость, никогда ваш IP';
	@override String get tierTv => 'Большие телевизоры';
	@override String get tierLaptopLarge => 'Большие ноутбуки';
	@override String get tierTablet => 'Планшеты и ноутбуки';
	@override String get tierPhone => 'Телефоны';
	@override String get tierSmallPhone => 'Небольшие телефоны';
	@override String get tierCalls => 'Звонки и аудио';
	@override String get messagingOnly => 'Только мессенджеры';
	@override String get videoQuality => 'Качество видео';
	@override String get preview => 'ПРЕДПРОСМОТР';
	@override String get history => 'История';
	@override String get clear => 'Очистить';
	@override String get viaVpnLower => 'через VPN';
	@override String get directLower => 'напрямую';
	@override String get gradeA => 'Несколько 4K-потоков и видеозвонков одновременно';
	@override String get gradeB => 'HD-видео и плавные видеозвонки';
	@override String get gradeC => 'Один HD-поток; в часы пик звонки могут прерываться';
	@override String get gradeD => 'Сайты и мессенджеры; видео тормозит';
	@override String get yourCountry => 'ваша страна';
	@override String get median => 'Медиана загрузки за 30 дней';
	@override String get fromUsers => 'Мбит/с · по тестам пользователей G VPN';
	@override String get costLittle => 'VPN почти не снижает скорость';
	@override String get costNoticeable => 'Заметно медленнее, чем напрямую';
	@override String get costMuch => 'Намного медленнее. Попробуйте другой сервер';
	@override String get ofDirect => 'от вашей прямой скорости';
	@override String get none => 'нет';
	@override String ms({required Object n}) => '${n} мс';
	@override String previewTier({required Object tier}) => 'ПРЕДПРОСМОТР · ${tier}';
	@override String streamsUpTo({required Object tier, required Object who}) => 'Видео до ${tier} · ${who}';
	@override String today({required Object time}) => 'Сегодня, ${time}';
	@override String tests({required Object n}) => 'Тестов: ${n}';
	@override String gradeVpn({required Object label}) => '${label} через VPN';
	@override String gradeIsp({required Object label, required Object isp}) => '${label} у ${isp}';
	@override String notEnough({required Object isp}) => 'Пока мало тестов для ${isp}';
	@override String get yourProvider => 'вашего провайдера';
	@override String rankLine({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} в ${where}: ${rank} из ${of}';
	@override String costLine({required Object note, required Object mbps}) => '${note} · напрямую ${mbps} Мбит/с';
	@override String mbpsValue({required Object v}) => '${v} Мбит/с';
	@override String get gradeExcellent => 'Отлично';
	@override String get gradeVeryGood => 'Очень хорошо';
	@override String get gradeGood => 'Хорошо';
	@override String get gradeFair => 'Удовлетворительно';
	@override String get gradeSlow => 'Медленно';
	@override String get gradeVerySlow => 'Очень медленно';
}

// Path: router
class _Translations$router$ru extends Translations$router$en {
	_Translations$router$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get info => 'Спрашивает ваш роутер по UPnP, могут ли устройства сами открывать порты в интернет, и показывает уже открытые. Только читает и ничего не меняет. Если UPnP ничему не нужен (некоторым игровым приставкам нужен), безопаснее выключить его в настройках роутера.';
	@override String get title => 'Проверка роутера';
	@override String get asking => 'Опрос роутера';
	@override String get again => 'Проверить снова';
	@override String get check => 'Проверить роутер';
	@override String get off => 'UPnP выключен';
	@override String get offBody => 'Устройства не могут сами открывать порты.';
	@override String get onBody => 'Сейчас через него не открыт ни один порт.';
	@override String get checkEach => 'Убедитесь, что знаете каждый из них.';
	@override String get cgnat => 'Общий адрес провайдера: недоступен из интернета.';
	@override String get noDescription => 'Без описания';
	@override String opened({required Object n}) => 'Устройства открыли портов: ${n}';
	@override String mapping({required Object proto, required Object host}) => '${proto} на ${host}';
	@override String get upnpOn => 'UPnP включён';
	@override String get routerLabel => 'Роутер';
	@override String get internetAddress => 'Адрес в интернете';
	@override String get openedBy => 'Открыто устройствами';
}

// Path: network
class _Translations$network$ru extends Translations$network$en {
	_Translations$network$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Эта сеть';
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Мобильные данные';
	@override String get ethernet => 'Ethernet';
	@override String get offline => 'Нет сети';
	@override String get risky => 'Опасная сеть. Подключите здесь VPN.';
	@override String get review => 'Стоит проверить, прежде чем доверять.';
	@override String get covered => 'Защищено VPN.';
	@override String get safe => 'Сеть выглядит безопасной.';
	@override String get mobileSentence => 'Мобильные данные.';
	@override String get notConnected => 'Нет подключения.';
	@override String get showName => 'Показать имя';
	@override String get sitesSee => 'Сайты видят';
	@override String get provider => 'Провайдер';
	@override String get location => 'Местоположение';
	@override String get couldNotCheck => 'Не удалось проверить';
	@override String get checking => 'Проверка';
	@override String get signal => 'Сигнал';
	@override String get linkSpeed => 'Скорость связи';
	@override String get gateway => 'Шлюз';
	@override String get none => 'Нет';
	@override String get privateDns => 'Частный DNS';
	@override String get automatic => 'Автоматически';
	@override String get off => 'Выкл.';
	@override String get metered => 'Лимитная';
	@override String get yes => 'Да';
	@override String get no => 'Нет';
	@override String readFailed({required Object error}) => 'Не удалось прочитать сеть: ${error}';
}

// Path: devices
class _Translations$devices$ru extends Translations$devices$en {
	_Translations$devices$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get info => 'Обращается к каждому адресу в диапазоне вашей сети Wi-Fi и просит устройства представиться. Устройство, ответившее отказом, тоже учитывается: отказ доказывает, что оно есть.\n\nИмена: из того, что публикуют сами устройства (Bonjour, UPnP, имена Windows), и из вашего роутера.\n\nНеизвестные устройства: Android скрывает аппаратные адреса от приложений, поэтому молчащее устройство без имени не опознать. Посмотрите их в списке устройств роутера.\n\nНовое: устройство, которого не было при прошлом сканировании этой сети.';
	@override String get needWifi => 'Сначала подключитесь к сети Wi-Fi.';
	@override String get title => 'Устройства';
	@override String get again => 'Сканировать снова';
	@override String get looking => 'Поиск устройств';
	@override String get all => 'Все';
	@override String get phones => 'Телефоны';
	@override String get tvs => 'Телевизоры';
	@override String get computers => 'Компьютеры';
	@override String get other => 'Другое';
	@override String get thisPhone => 'Этот телефон';
	@override String get router => 'Роутер';
	@override String get unknown => 'Неизвестное устройство';
	@override String get address => 'Адрес';
	@override String get answersIn => 'Отвечает за';
	@override String get type => 'Тип';
	@override String get newBadge => 'НОВОЕ';
	@override String scanning({required Object n}) => 'Сканирование ${n} из 254';
	@override String newSince({required Object n}) => 'Новых с прошлого сканирования: ${n}';
	@override String ms({required Object n}) => '${n} мс';
	@override String get cameras => 'Камеры';
	@override String get device => 'Устройство';
	@override String get online => 'В сети';
	@override String get model => 'Модель';
	@override String get announced => 'Представляется как';
	@override String get services => 'ОТКРЫТЫЕ СЛУЖБЫ';
	@override String get checkingServices => 'Проверяем службы';
	@override String get noServices => 'Обычные службы не отвечают';
	@override String get rename => 'Переименовать';
	@override String get save => 'Сохранить';
	@override late final _Translations$devices$kinds$ru kinds = _Translations$devices$kinds$ru._(_root);
	@override String get details => 'Сведения о сети';
	@override String get listView => 'Список';
	@override String get meshView => 'Сеть-граф';
	@override String get offlineHeading => 'Не в сети';
	@override String seen({required Object when}) => 'Был ${when}';
	@override String agoMinutes({required Object n}) => '${n} мин назад';
	@override String agoHours({required Object n}) => '${n} ч назад';
	@override String agoDays({required Object n}) => '${n} дн. назад';
	@override String get throughVpn => 'Через VPN';
	@override String get closer => 'Ближе = отвечает быстрее';
	@override String get yours => 'Это ваше?';
	@override String get mine => 'Моё';
	@override String get notMine => 'Не моё';
	@override String get whatIsIt => 'Что это?';
	@override String ourGuess({required Object kind}) => 'Наша догадка: ${kind}';
	@override String get groupPersonal => 'Телефоны и компьютеры';
	@override String get groupHome => 'Дом и медиа';
	@override String get groupNetwork => 'Сеть и умный дом';
	@override String onlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} в сети',
		few: '${n} в сети',
		many: '${n} в сети',
		other: '${n} в сети',
	);
	@override String offlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} не в сети',
		few: '${n} не в сети',
		many: '${n} не в сети',
		other: '${n} не в сети',
	);
	@override String toConfirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} подтвердить',
		few: '${n} подтвердить',
		many: '${n} подтвердить',
		other: '${n} подтвердить',
	);
}

// Path: ping
class _Translations$ping$ru extends Translations$ping$en {
	_Translations$ping$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get askTitle => 'Пинг узла';
	@override String get askHint => 'example.com или 192.168.1.10';
	@override String get title => 'Пинг';
	@override String get router => 'Роутер';
	@override String get pause => 'Пауза';
	@override String get start => 'Старт';
	@override String get host => 'Узел';
	@override String get live => 'В реальном времени';
	@override String get ago => '60 с назад';
	@override String get min => 'МИН';
	@override String get avg => 'СРЕД';
	@override String get jitter => 'ДЖИТТЕР';
	@override String get loss => 'ПОТЕРИ';
	@override String get goodFor => 'Подходит для';
	@override String get calls => 'Видеозвонки';
	@override String get games => 'Онлайн-игры';
	@override String get streaming => 'Стриминг';
	@override String get great => 'Отлично';
	@override String get okay => 'Нормально';
	@override String get poor => 'Плохо';
	@override String get lost => 'потерян';
	@override String get now => 'сейчас';
}

// Path: status
class _Translations$status$ru extends Translations$status$en {
	_Translations$status$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get info => 'Подключается к каждому сервису трижды и показывает самый быстрый ответ.\n\nЗаблокировано здесь: сервис, который не отвечает напрямую, но работает через VPN, заблокирован вашей сетью или страной.\n\nИстория: проверки за последние 24 часа с этого телефона, хранятся только на нём.';
	@override String get title => 'Статус сервисов';
	@override String get checking => 'Проверка';
	@override String get again => 'Проверить снова';
	@override String get viaVpn => 'Проверено через VPN';
	@override String get direct => 'Проверено напрямую';
	@override String get favourites => 'Избранное';
	@override String get edit => 'Изменить';
	@override String get last24 => 'Последние 24 часа';
	@override String get ago => '24 ч назад';
	@override String get all => 'Все сервисы';
	@override String get pickFour => 'Выберите до четырёх';
	@override String get outage => 'Даже через VPN: вероятно, сбой';
	@override String get blocked => 'Возможно, заблокирован в этой сети';
	@override String get connect => 'Подключить';
	@override String get blockedShort => 'Блок';
	@override String get now => 'сейчас';
	@override String checks({required Object n}) => 'Проверок: ${n}';
	@override String andMore({required Object first, required Object n}) => '${first} и ещё ${n}';
	@override String notReachable({required Object who}) => '${who}: недоступно';
}

// Path: tools
class _Translations$tools$ru extends Translations$tools$en {
	_Translations$tools$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Мобильные данные';
	@override String get ethernet => 'Ethernet';
	@override String get checking => 'Проверка';
	@override String get offline => 'Нет сети';
	@override String get title => 'Инструменты';
	@override String get networkDesc => 'Проверка безопасности, что видят сайты, сигнал, роутер и DNS.';
	@override String get internet => 'Интернет';
	@override String get speed => 'Тест скорости';
	@override String get speedDesc => 'Загрузка, отдача и качество видео';
	@override String get ping => 'Пинг';
	@override String get pingDesc => 'Отклик и джиттер в реальном времени';
	@override String get status => 'Статус сервисов';
	@override String get statusDesc => 'Приложение доступно или заблокировано?';
	@override String get trace => 'Трассировка';
	@override String get traceDesc => 'Каждая остановка на пути к сайту';
	@override String get security => 'Эта сеть';
	@override String get devices => 'Устройства в этой сети';
	@override String get devicesDesc => 'Кто в вашем Wi-Fi';
	@override String get router => 'Проверка роутера';
	@override String get routerDesc => 'Порты, открытые устройствами';
	@override String get ports => 'Открытые порты';
	@override String get portsDesc => 'Опасные порты на устройстве или сервере';
	@override String get utilities => 'Утилиты';
	@override String get wifiScanner => 'Сканер Wi-Fi';
	@override String get wifiDesc => 'Сети вокруг и самый свободный канал';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'Включить компьютер в этой сети';
	@override String get passwordCheck => 'Проверка пароля';
	@override String get passwordCheckDesc => 'Утёк ли пароль?';
	@override String get linkCheck => 'Проверка ссылки';
	@override String get linkCheckDesc => 'Безопасно ли открыть?';
	@override String get breaches => 'Утечки данных';
	@override String get breachesDesc => 'Что утекло недавно';
	@override String get blocked => 'Что заблокировано';
	@override String get blockedDesc => 'Сайты, заблокированные в этой сети';
}

// Path: trace
class _Translations$trace$ru extends Translations$trace$en {
	_Translations$trace$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get info => 'Каждая точка обозначает роутер, через который проходит ваш трафик на пути к сайту.\n\nМолчащие узлы: многие роутеры никогда не отвечают на эти пробы. Это нормально и не является ошибкой.\n\nС включённым VPN: маршрут начинается внутри туннеля, поэтому ваша сеть и провайдер скрыты.\n\nКак: используется встроенная в Android утилита ping с ограничением числа узлов, так как приложения не могут отправлять такие пакеты напрямую.';
	@override String get title => 'Трассировка';
	@override String get stop => 'Стоп';
	@override String get trace => 'Трассировать';
	@override String get again => 'Трассировать снова';
	@override String get destination => 'Назначение';
	@override String get hops => 'УЗЛЫ';
	@override String get answered => 'ОТВЕТИЛИ';
	@override String get total => 'ВСЕГО';
	@override String get thisPhone => 'Этот телефон';
	@override String get silentOne => '1 молчащий узел';
	@override String get yourRouter => 'Ваш роутер';
	@override String ms({required Object n}) => '${n} мс';
	@override String silentMany({required Object n}) => 'Молчащих узлов: ${n}';
	@override String hop({required Object n}) => 'Узел ${n}';
	@override String slowest({required Object ms, required Object hop}) => 'Основная задержка, ${ms} мс, добавляется на узле ${hop}: обычно это длинный кабель между странами или перегруженный канал.';
	@override String get popular => 'ПОПУЛЯРНЫЕ';
	@override String get recent => 'НЕДАВНИЕ';
	@override String get clearRecent => 'Очистить недавние';
	@override String hopsCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} узел',
		few: '${n} узла',
		many: '${n} узлов',
		other: '${n} узла',
	);
}

// Path: ports
class _Translations$ports$ru extends Translations$ports$en {
	_Translations$ports$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get ftpNote => 'Передаёт пароли без шифрования.';
	@override String get sshNote => 'Удалённый вход. Нормально, если вы настроили его сами.';
	@override String get telnetNote => 'Удалённый вход без шифрования; любимец ботнетов.';
	@override String get dnsNote => 'Обычно для роутера.';
	@override String get web => 'Веб (HTTP)';
	@override String get webNote => 'Обычно страница настроек роутера.';
	@override String get webTls => 'Веб (HTTPS)';
	@override String get smb => 'Общий доступ к файлам Windows';
	@override String get smbNote => 'Никогда не должен быть открыт в интернет.';
	@override String get rtsp => 'Поток камеры RTSP';
	@override String get rtspNote => 'Здесь может транслировать камера.';
	@override String get upnpNote => 'Позволяет устройствам самим открывать порты роутера.';
	@override String get rdp => 'Удалённый рабочий стол';
	@override String get rdpNote => 'Частый путь для взлома.';
	@override String get vncNote => 'Демонстрация экрана, часто без пароля.';
	@override String get tr069Note => 'Удалённое управление провайдером.';
	@override String get webAlt => 'Веб (доп.)';
	@override String get webAltTls => 'Веб (доп. HTTPS)';
	@override String get title => 'Открытые порты';
	@override String get check => 'Проверить порты';
	@override String get address => 'Адрес устройства или сервера';
	@override String get risky => 'ОПАСНО';
	@override String get review => 'ПРОВЕРИТЬ';
	@override String get normal => 'НОРМА';
	@override String info({required Object n}) => 'Проверяет ${n} портов, важных для домашних роутеров и устройств, и объясняет каждый открытый.\n\nПроверяйте только устройства и серверы, которыми вы владеете или управляете.';
	@override String checking({required Object n}) => 'Проверка портов: ${n}';
	@override String yourRouter({required Object ip}) => 'Ваш роутер: ${ip}';
	@override String noneOpen({required Object host}) => 'На ${host} нет открытых распространённых портов.';
	@override String summary({required Object open, required Object n}) => 'Открыто ${open} из ${n} проверенных';
	@override String riskyCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} опасный',
		few: '${n} опасных',
		many: '${n} опасных',
		other: '${n} опасных',
	);
	@override String get noneRisky => 'Ничего опасного';
}

// Path: wifi
class _Translations$wifi$ru extends Translations$wifi$en {
	_Translations$wifi$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Сканер Wi-Fi';
	@override String get allow => 'Разрешить сканирование Wi-Fi';
	@override String get needsPermission => 'Нужен доступ к геолокации.';
	@override String get scanning => 'Сканирование';
	@override String get again => 'Сканировать снова';
	@override String get failed => 'Сканирование не удалось';
	@override String get none => 'Сети не найдены. Возможно, геолокация выключена.';
	@override String get hidden => 'Скрытая сеть';
	@override String nearby({required Object n}) => 'Сетей поблизости: ${n}';
	@override String get permissionInfo => 'Android показывает ближайшие сети Wi-Fi только приложениям с доступом к геолокации. G VPN использует его лишь для списка сетей на этом телефоне.';
	@override String get info => 'Показывает сети из последнего сканирования телефона. Android разрешает лишь несколько сканирований в минуту, поэтому быстрое повторное может показать тот же список. Рекомендуемый канал: наименее загруженный из 1, 6 и 11, трёх неперекрывающихся.';
	@override String get airMap => 'Карта эфира';
	@override String get channels => 'Каналы';
	@override String get list => 'Список';
	@override String get secure => 'Защищена';
	@override String get weakLabel => 'Слабая';
	@override String get openLabel => 'Открытая';
	@override String get sizeIsWidth => 'Размер = ширина канала';
	@override String get strongest => 'САМАЯ СИЛЬНАЯ';
	@override String get openNearby => 'ОТКРЫТЫЕ РЯДОМ';
	@override String get onYourChannel => 'НА ВАШЕМ КАНАЛЕ';
	@override String get noneNearby => 'Нет';
	@override String get verdictOpen => 'Любой рядом может читать передаваемое';
	@override String get verdictWep => 'Старая защита, легко взломать';
	@override String get verdictWpa => 'Устаревшая защита';
	@override String get verdictWps => 'Включён WPS: проще взломать';
	@override String get verdictGood => 'Хорошо защищена';
	@override String get maker => 'Производитель';
	@override String get address => 'Аппаратный адрес';
	@override String get privateAddress => 'Придуман роутером ради приватности';
	@override String get you => 'Вы';
	@override String onClear({required Object name}) => '${name} на свободном канале';
	@override String move({required Object name, required Object n}) => 'Переведите ${name} на канал ${n}';
	@override String get clear => 'Свободен';
	@override String get busy => 'Занят';
	@override String get crowded => 'Перегружен';
	@override String get allBands => 'Все диапазоны';
	@override String get openOnly => 'Только открытые';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} сеть',
		few: '${n} сети',
		many: '${n} сетей',
		other: '${n} сети',
	);
}

// Path: errors
class _Translations$errors$ru extends Translations$errors$en {
	_Translations$errors$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get notAuthorized => 'Разрешение на VPN не выдано.';
	@override String get turnedOff => 'VPN был выключен системой или другим приложением.';
	@override String get busy => 'Запрос разрешения уже открыт.';
	@override String get cancelled => 'Подключение отменено.';
	@override String badConfig({required Object error}) => 'Неверная конфигурация сервера: ${error}';
	@override String get timeout => 'Сервер не ответил.';
	@override String get refused => 'Сервер отклонил подключение.';
	@override String failed({required Object error}) => 'Не удалось подключиться: ${error}';
	@override String get tryAnother => 'Бесплатные серверы появляются и исчезают; попробуйте другой.';
	@override String get downloadFailed => 'Не удалось загрузить настройки этого сервера. Проверьте подключение или выберите другой сервер.';
}

// Path: scan
class _Translations$scan$ru extends Translations$scan$en {
	_Translations$scan$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get mobile => 'Мобильные данные';
	@override String get ping => 'ПИНГ';
	@override String get noReply => 'Нет ответа';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, туннель';
	@override String get dnsTunnel => 'В туннеле';
	@override String get privateDns => 'Частный DNS';
	@override String get dnsIsp => 'Провайдер, видно';
	@override String get network => 'СЕТЬ';
	@override String get offline => 'Нет сети';
	@override String get open => 'Открытая, без пароля';
	@override String get wep => 'WEP, ненадёжно';
	@override String get owe => 'Открытая, с шифрованием';
	@override String get enterprise => 'Корпоративная';
	@override String get unknown => 'Неизвестно';
	@override String get wifi => 'WI-FI';
	@override String get signIn => 'Страница входа';
	@override String ms({required Object n}) => '${n} мс';
	@override String covered({required Object what}) => '${what}, под защитой';
}

// Path: legal
class _Translations$legal$ru extends Translations$legal$en {
	_Translations$legal$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get privacy => 'Политика конфиденциальности';
	@override String get terms => 'Условия использования';
	@override String get licences => 'Лицензии открытого ПО';
}

// Path: update
class _Translations$update$ru extends Translations$update$en {
	_Translations$update$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get ready => 'Обновление готово';
	@override String get restart => 'Перезапустить';
}

// Path: details
class _Translations$details$ru extends Translations$details$en {
	_Translations$details$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get share => 'Поделиться';
	@override String connectedFor({required Object n}) => 'ПОДКЛЮЧЕНО · ${n} МИН';
	@override String get notConnected => 'НЕ ПОДКЛЮЧЕНО';
	@override String get downloaded => 'ПОЛУЧЕНО';
	@override String get uploaded => 'ОТПРАВЛЕНО';
	@override String get lastUsed => 'ИСПОЛЬЗОВАЛСЯ';
	@override String get connection => 'Подключение';
	@override String get protocol => 'Протокол';
	@override String get address => 'Ваш адрес';
	@override String get dns => 'DNS';
	@override String get routes => 'Маршруты';
	@override String get allTraffic => 'Весь трафик';
	@override String someRoutes({required Object n}) => 'Сетей: ${n}';
	@override String get keepalive => 'Keepalive';
	@override String get serverKey => 'Ключ сервера';
	@override String get copy => 'Копировать';
	@override String get copied => 'Скопировано';
	@override String get manage => 'Управление';
	@override String get export => 'Экспорт для резервной копии';
	@override String get exportSub => 'Все ваши серверы в одном файле';
}

// Path: share
class _Translations$share$ru extends Translations$share$en {
	_Translations$share$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String title({required Object name}) => 'Поделиться: ${name}';
	@override String get sameKey => 'Вы делитесь ключом этого телефона. Любой, у кого он есть, сможет пользоваться сервером от вашего имени, и одновременно с ним может быть подключено только одно устройство.';
	@override String get scanHint => 'На другом телефоне: G VPN, Серверы, Сканировать QR. Сохранённое изображение тоже подойдёт.';
	@override String get saveImage => 'Сохранить изображение';
	@override String get send => 'Отправить';
}

// Path: add
class _Translations$add$ru extends Translations$add$en {
	_Translations$add$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Добавить сервер';
	@override String get subtitle => 'Любой сервер WireGuard: роутер, VPS или домашний сервер.';
	@override String get camera => 'Сканировать камерой';
	@override String get cameraSub => 'QR на другом экране';
	@override String get image => 'Из изображения';
	@override String get imageSub => 'Скриншот или сохранённое фото';
	@override String get noQr => 'На этом изображении нет QR-кода.';
	@override String get tip => 'Получили QR в WhatsApp или Telegram? Нажмите «Поделиться» на изображении и выберите G VPN.';
}

// Path: backup
class _Translations$backup$ru extends Translations$backup$en {
	_Translations$backup$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String restored({required Object n}) => 'Восстановлено серверов: ${n}';
	@override String get nothingNew => 'Эти серверы уже добавлены';
}

// Path: gs
class _Translations$gs$ru extends Translations$gs$en {
	_Translations$gs$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'G Servers доступны подписчикам G VPN Pro.';
	@override String get off => 'G Servers сейчас выключены.';
	@override String get network => 'Не удалось связаться с G Servers. Проверьте подключение и попробуйте снова.';
	@override String get active => 'АКТИВНО';
	@override String get servers => 'G Servers';
	@override String busy({required Object n}) => 'Загрузка ${n}%';
	@override String get offline => 'Не в сети';
	@override String get devices => 'Ваши устройства';
	@override String subtitle({required Object country}) => 'G Server · ${country} · WireGuard';
	@override String get busyLabel => 'ЗАГРУЗКА';
	@override String get status => 'СТАТУС';
	@override String get online => 'В сети';
	@override String get onThisServer => 'На этом сервере';
	@override String get thisPhone => 'Этот телефон';
	@override String get added => 'Добавлен · ключ создан здесь';
	@override String get notAdded => 'Добавится при подключении';
	@override String get logs => 'Журналы активности';
	@override String get noneKept => 'Не хранятся';
	@override String get privacy => 'Сервер знает этот телефон только по открытому ключу. Он не записывает, какие сайты вы посещаете и какой трафик отправляете.';
	@override String get stepPro1 => 'Установите G VPN на телефон с тем же аккаунтом Google.';
	@override String get stepPro2 => 'Откройте вкладку Pro. Pro включится сам, или нажмите «Восстановить».';
	@override String get step3 => 'Нажмите «Подключить». Телефон создаст ключ и будет добавлен в G Servers. Без QR и кодов.';
	@override String get stepFree1 => 'Установите G VPN на телефон.';
	@override String get stepFree2 => 'Откройте вкладку Pro.';
	@override String get devicesIntroPro => 'Pro привязан к вашему аккаунту Google. У каждого телефона свой ключ, поэтому они не отключают друг друга.';
	@override String get devicesIntroFree => 'У каждого телефона свой ключ, поэтому они не отключают друг друга.';
	@override String get otherPhone => 'Другой телефон';
	@override String lastConnected({required Object when}) => 'Подключался ${when}';
	@override String get noDevices => 'Подключитесь к G Server один раз, и ваши телефоны появятся здесь.';
	@override String get addTitle => 'Добавить телефон или переустановить';
	@override String idle({required Object n}) => 'Телефон, не подключавшийся ${n} дней, удаляется из G Servers автоматически, так что старый или переустановленный телефон не занимает место.';
	@override String limitNote({required Object n}) => 'До ${n} телефонов на план.';
	@override String fullTitle({required Object n}) => 'Все ${n} мест заняты';
	@override String get fullBody => 'Удалите телефон, которым больше не пользуетесь, и этот сразу подключится.';
	@override String get busyNow => 'Сейчас слишком много новых телефонов. Попробуйте чуть позже.';
	@override String get serverFull => 'Этот сервер заполнен. Попробуйте другой G Server.';
	@override String get ping => 'ПИНГ';
	@override String get last24 => 'Загрузка за 24 часа';
	@override String get noHistory => 'График заполняется по мере работы сервера в течение дня.';
	@override String chartLabel({required Object max}) => 'Загрузка за последние 24 часа, максимум ${max} процентов';
	@override String get hoursAgo => '24 ч назад';
	@override String get now => 'Сейчас';
	@override String get included => 'Включено';
	@override String get perkServers => 'Быстрые частные серверы';
	@override String get perkServersSub => 'WireGuard, наши серверы, без журналов';
	@override String get perkLinks => 'Безлимитная проверка ссылок';
	@override String get perkLinksSub => 'Проверяйте каждую присланную ссылку';
	@override String devicesOf({required Object used, required Object limit}) => 'Ваши устройства · ${used} из ${limit}';
	@override String get eachKey => 'У каждого телефона свой ключ';
	@override String get connected => 'Подключено';
	@override String get bestNow => 'ЛУЧШИЙ ДЛЯ ВАС СЕЙЧАС';
	@override String get logsShort => 'ЖУРНАЛЫ';
}

// Path: map
class _Translations$map$ru extends Translations$map$en {
	_Translations$map$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get open => 'Открыть карту';
	@override String get searchCountries => 'Поиск страны';
	@override String get noMatch => 'Страна не найдена';
	@override String get locate => 'Моё местоположение';
	@override String get list => 'Список';
	@override String get map => 'Карта';
	@override String freeServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} бесплатный сервер',
		few: '${n} бесплатных сервера',
		many: '${n} бесплатных серверов',
		other: '${n} бесплатного сервера',
	);
	@override late final _Translations$map$grade$ru grade = _Translations$map$grade$ru._(_root);
	@override String get switchTo => 'Переключить';
	@override String freeServer({required Object n}) => 'Бесплатный сервер ${n}';
	@override String get best => 'ЛУЧШИЙ';
	@override String gServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} G Server',
		few: '${n} G Server',
		many: '${n} G Server',
		other: '${n} G Server',
	);
}

// Path: stats
class _Translations$stats$ru extends Translations$stats$en {
	_Translations$stats$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get thisWeek => 'Эта неделя';
	@override String get time => 'Время';
	@override String get data => 'Данные';
	@override String get protected => 'под защитой';
	@override String get throughVpn => 'через VPN';
	@override String get seeDetails => 'Подробнее';
	@override String get title => 'Статистика';
	@override String get week => 'Неделя';
	@override String get month => 'Месяц';
	@override String get protectedLabel => 'ПОД ЗАЩИТОЙ';
	@override String get dataUsed => 'ДАННЫЕ';
	@override String get byServer => 'ПО СЕРВЕРАМ';
	@override String get onPhone => 'Хранится только на этом телефоне';
	@override String get reset => 'Сбросить';
	@override String get resetTitle => 'Сбросить статистику?';
	@override String get resetBody => 'Удалит время под защитой и данные на этом телефоне. Отменить нельзя.';
	@override String hm({required Object h, required Object m}) => '${h} ч ${m} мин';
	@override String m({required Object m}) => '${m} мин';
	@override String get empty => 'Подключитесь, чтобы начать подсчёт.';
}

// Path: recents
class _Translations$recents$ru extends Translations$recents$en {
	_Translations$recents$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Недавние';
	@override String get allServers => 'Все серверы';
	@override String get free => 'Бесплатный сервер';
	@override String get yours => 'Ваш сервер';
	@override String get gserver => 'G Server';
}

// Path: presets
class _Translations$presets$ru extends Translations$presets$en {
	_Translations$presets$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Профили';
	@override String get all => 'Все';
	@override String get newPreset => 'Новый профиль';
	@override String get edit => 'Изменить профиль';
	@override String get name => 'Название';
	@override String get namePlaceholder => 'Мой профиль';
	@override String get server => 'СЕРВЕР';
	@override String get fastestOption => 'Самый быстрый';
	@override String get countryOption => 'Страна';
	@override String get pickCountry => 'Выберите страну';
	@override String get skipMyCountry => 'Не моя страна';
	@override String get notMine => 'не моя страна';
	@override String get protocol => 'ПРОТОКОЛ';
	@override String get auto => 'Авто';
	@override String get tryNext => 'Если заблокировано, пробовать следующий';
	@override String get shield => 'ЩИТ';
	@override String get followRules => 'Как в Правилах';
	@override String get allApps => 'Все приложения через VPN';
	@override String get allAppsShort => 'все приложения';
	@override String get save => 'Сохранить';
	@override String get delete => 'Удалить';
	@override String get reset => 'Сбросить';
	@override String get none => 'Сейчас нет бесплатного сервера для этого профиля.';
	@override late final _Translations$presets$names$ru names = _Translations$presets$names$ru._(_root);
}

// Path: shield
class _Translations$shield$ru extends Translations$shield$en {
	_Translations$shield$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Щит';
	@override String get sub => 'Работает, пока вы подключены';
	@override String get off => 'Выкл.';
	@override String get offSub => 'DNS самого сервера';
	@override String get malware => 'Вредоносное ПО';
	@override String get malwareSub => 'Блокирует вредоносные и фишинговые сайты';
	@override String get family => 'Вредоносное ПО и сайты для взрослых';
	@override String get familySub => 'Также блокирует контент для взрослых';
	@override String get custom => 'Свой DNS';
	@override String get customSub => 'Ваши DNS-серверы';
	@override String get customHint => 'IP-адрес, например 1.1.1.1';
	@override String get invalid => 'Введите один или два IP-адреса.';
}

// Path: checks
class _Translations$checks$ru extends Translations$checks$en {
	_Translations$checks$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Проверки';
	@override String get password => 'Пароль';
	@override String get link => 'Ссылка';
	@override String get pwTitle => 'Утёк ли пароль?';
	@override String get pwHint => 'Пароль для проверки';
	@override String get showPassword => 'Показать пароль';
	@override String get hidePassword => 'Скрыть пароль';
	@override String get check => 'Проверить';
	@override String get leaked => 'Найден в утечках';
	@override String seen({required Object n}) => 'Встречался ${n} раз';
	@override String get leakedAdvice => 'Смените его везде, где используете, начиная с почты и банка.';
	@override String get notFound => 'Нет в известных утечках';
	@override String get notFoundAdvice => 'Хороший знак, но не гарантия. Используйте разные пароли для каждого аккаунта.';
	@override String get failed => 'Не удалось проверить. Попробуйте ещё раз.';
	@override String get private => 'Ваш пароль не покидает этот телефон';
	@override String get linkTitle => 'Безопасна ли ссылка?';
	@override String get linkHint => 'Ссылка для проверки';
	@override String get paste => 'Вставить';
	@override String get danger => 'Опасная ссылка';
	@override String get dangerAdvice => 'Не открывайте её и не вводите никаких данных.';
	@override String get clear => 'Нет в известных списках вредоносных и фишинговых сайтов';
	@override String get clearAdvice => 'Всё равно проверьте адрес, прежде чем входить.';
	@override String get goesTo => 'Ведёт на';
	@override String get redirects => 'Перенаправления';
	@override String get invalid => 'Это не похоже на веб-адрес.';
	@override String get busy => 'Слишком много проверок. Попробуйте позже.';
	@override String get unavailable => 'Проверка ссылок сейчас недоступна.';
	@override String get listed => 'Известен вредоносным ПО или фишингом';
	@override String get missing => 'По этому адресу нет сайта';
	@override String get missingAdvice => 'Проверьте написание: мошенники используют похожие адреса.';
	@override String left({required Object n, required Object total}) => 'Осталось ${n} из ${total} бесплатных проверок в этом месяце';
	@override String get usedUp => 'Бесплатные проверки ссылок на этот месяц закончились';
	@override String get usedUpSub => 'В Pro проверки без ограничений. Бесплатные вернутся 1-го числа.';
	@override String get getPro => 'Получить Pro';
}

// Path: toolSettings
class _Translations$toolSettings$ru extends Translations$toolSettings$en {
	_Translations$toolSettings$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Настройки инструментов';
	@override String get askMobile => 'Спрашивать перед тестом на мобильных данных';
	@override String get askMobileSub => 'На быстром соединении тест может потратить больше 100 МБ';
	@override String get mobileTitle => 'Использовать мобильные данные?';
	@override String get mobileBody => 'Тест скорости может потратить больше 100 МБ на быстром соединении.';
	@override String get mobileGo => 'Проверить';
	@override String get safe => 'Безопасна';
	@override String get unsafe => 'Небезопасна';
	@override String devices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} устройство',
		few: '${n} устройства',
		many: '${n} устройств',
		other: '${n} устройства',
	);
	@override String get hideMac => 'Скрывать аппаратные адреса';
	@override String get hideMacSub => 'Показывать только часть MAC-адреса с производителем';
	@override String get names => 'Показывать имена роутеров и серверов';
	@override String get namesSub => 'Ищет имена адресов в Traceroute';
	@override String get remember => 'Запоминать недавние адреса';
	@override String get rememberSub => 'Для Traceroute';
	@override String get clear => 'Очистить историю инструментов';
	@override String get clearSub => 'Забывает недавние адреса и устройства каждой сети';
	@override String get clearGo => 'Очистить';
}

// Path: security
class _Translations$security$ru extends Translations$security$en {
	_Translations$security$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get tab => 'Безопасность';
	@override String get good => 'Хорошо';
	@override String get fair => 'Средне';
	@override String get atRisk => 'Под угрозой';
	@override String get allClear => 'Исправлять нечего';
	@override String checked({required Object time}) => 'Проверено в ${time}';
	@override String get trend => 'ЗА ДВЕ НЕДЕЛИ';
	@override String get checking => 'Проверяем эту сеть';
	@override String get snoozed => 'Отложенные';
	@override String get remindLater => 'Напомнить позже';
	@override String get unsnooze => 'Напомнить сейчас';
	@override String get review => 'Посмотреть';
	@override String get confirmGo => 'Подтвердить';
	@override String get scanGo => 'Сканировать';
	@override String get look => 'Открыть';
	@override String get connectGo => 'Подключить';
	@override String get checkAgain => 'Проверить снова';
	@override String get wifiOpen => 'Wi-Fi открыт';
	@override String get wifiOpenDetail => 'Любой рядом видит передаваемое';
	@override String get wifiWep => 'Wi-Fi использует WEP';
	@override String get wifiWepDetail => 'Старая защита, легко взломать';
	@override String get wifiOwe => 'Wi-Fi использует Enhanced Open';
	@override String get wifiOweDetail => 'Шифруется, но войти может любой';
	@override String get wifiSecure => 'Шифрование Wi-Fi';
	@override String get wifiUnknown => 'Защита Wi-Fi неизвестна';
	@override String get wifiUnknownDetail => 'Android не сообщил, как она защищена';
	@override String get wps => 'Включён WPS';
	@override String get wpsDetail => 'Отключите его в настройках роутера';
	@override String get upnpOff => 'Роутер держит порты закрытыми';
	@override String get upnpOffDetail => 'UPnP выключен';
	@override String get upnpOn => 'Роутер позволяет устройствам открывать порты';
	@override String get upnpOnDetail => 'UPnP включён';
	@override String get portsOk => 'Опасных портов на роутере нет';
	@override String get portsRisky => 'На роутере открыты опасные порты';
	@override String get scanFirst => 'Просканируйте, чтобы увидеть, кто здесь';
	@override String get scanFirstDetail => 'Неизвестные устройства снижают оценку';
	@override String get notMineDetail => 'Проверьте список устройств в роутере';
	@override String get confirmDetail => 'Отметьте свои';
	@override String get devicesOk => 'Все устройства известны';
	@override String get devicesOkDetail => 'Вы подтвердили каждое';
	@override String get camera => 'В этой сети есть камера';
	@override String get dnsHijack => 'Неизвестные имена перенаправляются';
	@override String get dnsHijackDetail => 'Провайдер или роутер подменяет ответы';
	@override String get dnsOk => 'DNS отвечает нормально';
	@override String get dnsOkDetail => 'Признаков подмены нет';
	@override String get vpnOn => 'VPN включён';
	@override String get vpnOnDetail => 'Трафик идёт через туннель';
	@override String get vpnOff => 'VPN выключен';
	@override String get vpnOffDetail => 'Провайдер видит каждый сайт';
	@override String toFix({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} проблема',
		other: '${n} проблемы',
		few: '${n} проблемы',
		many: '${n} проблем',
	);
	@override String upnpOpened({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: 'Устройства открыли ${n} порт',
		other: 'Устройства открыли ${n} порта',
		few: 'Устройства открыли ${n} порта',
		many: 'Устройства открыли ${n} портов',
	);
	@override String portsChecked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: 'Проверен ${n} порт',
		other: 'Проверено ${n} порта',
		few: 'Проверено ${n} порта',
		many: 'Проверено ${n} портов',
	);
	@override String notMine({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} устройство не ваше',
		other: '${n} устройства не ваши',
		few: '${n} устройства не ваши',
		many: '${n} устройств не ваши',
	);
	@override String confirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} устройство подтвердить',
		other: '${n} устройства подтвердить',
		few: '${n} устройства подтвердить',
		many: '${n} устройств подтвердить',
	);
}

// Path: providers
class _Translations$providers$ru extends Translations$providers$en {
	_Translations$providers$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get tab => 'Интернет';
	@override String get unavailable => 'Не удалось загрузить список провайдеров. Проверьте связь.';
	@override String get cached => 'По последней проверке без VPN';
	@override String get notEnough => 'Пока мало оценок';
	@override String get yourRating => 'Ваша оценка в этом месяце';
	@override String get yourSpeed => 'ВАША СКОРОСТЬ';
	@override String get runTest => 'Проверить скорость';
	@override String get aboutAverage => 'Около среднего здесь';
	@override String aboveAverage({required Object pct}) => 'На ${pct}% выше местного среднего';
	@override String belowAverage({required Object pct}) => 'На ${pct}% ниже местного среднего';
	@override String get call => 'Позвонить';
	@override String get website => 'Сайт';
	@override String get outages => 'Сбои';
	@override String get rate => 'Оценить';
	@override String get changeRating => 'Изменить оценку';
	@override String get compare => 'Сравнить';
	@override String rateTitle({required Object name}) => 'Оценить ${name}';
	@override String get oncePerMonth => 'Одна оценка в месяц';
	@override String get tapStars => 'Нажмите на звёзды';
	@override String verified({required Object mbps}) => 'Подтверждено вашим тестом: ${mbps} Мбит/с';
	@override String get busy => 'Слишком много оценок отсюда. Попробуйте позже.';
	@override String get failed => 'Не удалось отправить. Попробуйте ещё раз.';
	@override String get post => 'Отправить оценку';
	@override String get nearTitle => 'Провайдеры рядом';
	@override String slower({required Object pct}) => 'Ваша загрузка на ${pct}% ниже среднего у вашего провайдера здесь';
	@override String inPlace({required Object place}) => 'Домашний интернет: ${place}';
	@override String get byRating => 'Оценка';
	@override String get bySpeed => 'Скорость';
	@override String get footnote => 'Скорости — средние по тестам G VPN';
	@override String get noneNearby => 'Рядом пока нет оценок. Будьте первым.';
	@override String get you => 'Вы';
	@override String get topRated => 'Лучшие оценки';
	@override String starsOf({required Object n}) => '${n} из 5';
	@override late final _Translations$providers$tags$ru tags = _Translations$providers$tags$ru._(_root);
	@override late final _Translations$providers$words$ru words = _Translations$providers$words$ru._(_root);
	@override String ratings({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} оценка',
		few: '${n} оценки',
		many: '${n} оценок',
		other: '${n} оценки',
	);
}

// Path: alerts
class _Translations$alerts$ru extends Translations$alerts$en {
	_Translations$alerts$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get channel => 'Оповещения';
	@override String get title => 'Оповещения';
	@override String get markAllRead => 'Прочитать все';
	@override String get clearAll => 'Очистить всё';
	@override String get thisNetwork => 'этой сети';
	@override String openWifiTitle({required Object name}) => 'Вы подключились к открытому Wi-Fi: ${name}';
	@override String get openWifiBody => 'Любой рядом видит передаваемое. Включите G VPN.';
	@override String get reportTitle => 'Еженедельный отчёт готов';
	@override String reportBody({required Object hours}) => '${hours} ч под защитой на прошлой неделе';
	@override String blockedTitle({required Object name}) => '${name} здесь заблокирован';
	@override String get blockedBody => 'Работает через VPN';
	@override late final _Translations$alerts$kinds$ru kinds = _Translations$alerts$kinds$ru._(_root);
	@override String newDeviceTitle({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} новое устройство в ${network}',
		few: '${n} новых устройства в ${network}',
		many: '${n} новых устройств в ${network}',
		other: '${n} новых устройства в ${network}',
	);
	@override String get settings => 'Настройки оповещений';
	@override String get look => 'Открыть';
	@override String get read => 'Читать';
	@override String get open => 'Открыть';
	@override String get check => 'Проверить';
	@override String get today => 'СЕГОДНЯ';
	@override String get thisWeek => 'НА ЭТОЙ НЕДЕЛЕ';
	@override String get earlier => 'РАНЕЕ';
	@override String get all => 'Все';
	@override String get quiet => 'Всё спокойно';
	@override String get quietSub => 'В последнее время ничего не требовало внимания';
	@override String breachTitle({required Object name}) => 'Новая утечка: ${name}';
	@override late final _Translations$alerts$status$ru status = _Translations$alerts$status$ru._(_root);
}

// Path: report
class _Translations$report$ru extends Translations$report$en {
	_Translations$report$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Еженедельный отчёт';
	@override String get share => 'Поделиться картинкой';
	@override String get shareText => 'Моя неделя с G VPN';
	@override String get safer => 'Неделя стала безопаснее';
	@override String get moreProtected => 'Больше защиты, чем на прошлой неделе';
	@override String get yourWeek => 'Ваша неделя';
	@override String soFar({required Object range}) => '${range}, пока что';
	@override String get protected => 'Под защитой';
	@override String get data => 'Данные';
	@override String get security => 'Безопасность';
	@override String get speed => 'Лучшая скорость';
	@override String get noScore => 'Не проверено';
	@override String get noTest => 'Нет теста';
	@override String get bestDirect => 'Прямой тест';
	@override String moreThan({required Object d}) => 'На ${d} больше, чем на прошлой неделе';
	@override String lessThan({required Object d}) => 'На ${d} меньше, чем на прошлой неделе';
	@override String get protectedTime => 'ВРЕМЯ ПОД ЗАЩИТОЙ';
	@override String mostUsed({required Object name}) => 'Чаще всего: ${name}';
	@override String get quiet => 'Спокойная неделя: ничего не требовало внимания';
	@override String newDevices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: 'Подключилось ${n} новое устройство',
		few: 'Подключилось ${n} новых устройства',
		many: 'Подключилось ${n} новых устройств',
		other: 'Подключилось ${n} новых устройства',
	);
	@override String openWifi({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} открытый Wi-Fi',
		few: '${n} открытых Wi-Fi',
		many: '${n} открытых Wi-Fi',
		other: '${n} открытых Wi-Fi',
	);
	@override String blocked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} приложение заблокировано',
		few: '${n} приложения заблокировано',
		many: '${n} приложений заблокировано',
		other: '${n} приложения заблокировано',
	);
	@override String breaches({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} крупная новая утечка',
		few: '${n} крупные новые утечки',
		many: '${n} крупных новых утечек',
		other: '${n} крупные новые утечки',
	);
}

// Path: breaches
class _Translations$breaches$ru extends Translations$breaches$en {
	_Translations$breaches$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Утечки данных';
	@override String get info => 'Последние утечки данных из открытого списка Have I Been Pwned. О вас ничего не отправляется: список один для всех.\n\nЕсли у вас был аккаунт на взломанном сайте, смените этот пароль и везде, где использовали такой же.';
	@override String get unavailable => 'Не удалось загрузить список. Проверьте подключение.';
	@override String get biggest => 'КРУПНЕЙШАЯ ЗА МЕСЯЦ';
	@override String get newest => 'Новые';
	@override String get biggestSort => 'Крупные';
	@override String get withPasswords => 'С паролями';
	@override String get passwordsMark => 'ПАРОЛИ';
	@override String get one => 'Утечка';
	@override String get checkPassword => 'Проверить пароль';
	@override String get verified => 'Подтверждена';
	@override String get hasPasswords => 'Есть пароли';
	@override String get accountsLabel => 'Аккаунты';
	@override String get happened => 'Произошла';
	@override String get published => 'Опубликована';
	@override String get website => 'Сайт';
	@override String get leaked => 'ЧТО УТЕКЛО';
	@override String get ifUsed => 'ЕСЛИ ВЫ ПОЛЬЗОВАЛИСЬ';
	@override String get stepPassword => 'Смените пароль, который использовали там';
	@override String get stepReuse => 'Смените его везде, где он был таким же';
	@override String get stepTwoStep => 'Включите двухэтапный вход, где можно';
	@override String get stepScams => 'Ожидайте мошеннических звонков и сообщений';
	@override String accounts({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${count} аккаунт',
		few: '${count} аккаунта',
		many: '${count} аккаунтов',
		other: '${count} аккаунта',
	);
	@override String worldwide({required Object n}) => 'По всему миру · ${n}';
	@override String get noneHere => 'В недавнем списке нет утечек отсюда.';
	@override String get bigMap => 'Большая карта';
	@override String get showInList => 'Показать в списке';
	@override String get mapTitle => 'Карта утечек';
	@override String get zoomIn => 'Приблизить';
	@override String get zoomOut => 'Отдалить';
	@override String get wholeWorld => 'Весь мир';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} утечка',
		few: '${n} утечки',
		many: '${n} утечек',
		other: '${n} утечки',
	);
	@override String get findCountry => 'Найти страну';
	@override String get seeAll => 'Смотреть все';
	@override String get search => 'Поиск утечек';
}

// Path: blocked
class _Translations$blocked$ru extends Translations$blocked$en {
	_Translations$blocked$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Что заблокировано';
	@override String get info => 'Проверяет известные сайты с этого телефона без VPN и показывает, какие из них блокирует эта сеть и как.\n\nЛожный адрес: поиск имени в сети даёт ложный ответ.\n\nОбрыв: соединение рвётся в начале.\n\nНет ответа: ничего не возвращается.\n\nСтраница блокировки: вместо сайта отвечает что-то другое.\n\nПроверка показывает, где сайт заблокирован, но не кто его заблокировал. Ничего не сохраняется и не отправляется.';
	@override String get thisNetwork => 'Эта сеть';
	@override String get country => 'Ваша страна';
	@override String get question => 'Что здесь заблокировано?';
	@override String get testingOn => 'ПРОВЕРКА В СЕТИ';
	@override String get vpnOn => 'VPN ВКЛЮЧЁН';
	@override String get turnOff => 'Выключите G VPN для проверки';
	@override String get test => 'Проверить эту сеть';
	@override String get stop => 'Стоп';
	@override String sitesToTest({required Object n}) => 'САЙТЫ ДЛЯ ПРОВЕРКИ · ${n}';
	@override String ofSites({required Object n}) => 'из ${n} сайтов';
	@override String blockedCount({required Object n}) => 'ЗАБЛОКИРОВАНО: ${n}';
	@override String openCount({required Object n}) => 'ОТКРЫТО: ${n}';
	@override String noneBlocked({required Object network}) => 'В сети ${network} ничего не заблокировано';
	@override String openOf({required Object open, required Object total}) => 'Открыто ${open} из ${total}';
	@override String get allWork => 'ВСЁ РАБОТАЕТ ЧЕРЕЗ G VPN';
	@override String get blockedHeading => 'ЗАБЛОКИРОВАНО';
	@override String get byKind => 'ПО ТИПАМ';
	@override String get worksVpn => 'Работает через VPN';
	@override String get failsVpn => 'Заблокирован и через VPN';
	@override String get checkVpn => 'Проверить через G VPN';
	@override String get connect => 'Подключить G VPN';
	@override String get again => 'Проверить снова';
	@override String get withoutVpn => 'БЕЗ VPN';
	@override String get throughVpn => 'ЧЕРЕЗ G VPN';
	@override String get notChecked => 'Не проверено';
	@override String get opens => 'Открывается';
	@override String get stillBlocked => 'Заблокирован';
	@override String get whatHappened => 'ЧТО ПРОИЗОШЛО';
	@override String countryBlocked({required Object country}) => 'сайтов заблокировано: ${country}';
	@override String get countrySub => 'По проверкам волонтёров за последние 30 дней';
	@override String get countryNone => 'За последние 30 дней заблокированных сайтов не найдено.';
	@override String get countryUnavailable => 'Не удалось загрузить данные по стране. Проверьте подключение.';
	@override String get confirmed => 'ЗАБЛОКИРОВАН';
	@override String get oftenFails => 'ЧАСТО НЕДОСТУПЕН';
	@override late final _Translations$blocked$kinds$ru kinds = _Translations$blocked$kinds$ru._(_root);
	@override late final _Translations$blocked$how$ru how = _Translations$blocked$how$ru._(_root);
	@override late final _Translations$blocked$fail$ru fail = _Translations$blocked$fail$ru._(_root);
	@override late final _Translations$blocked$steps$ru steps = _Translations$blocked$steps$ru._(_root);
	@override late final _Translations$blocked$consent$ru consent = _Translations$blocked$consent$ru._(_root);
	@override String someBlocked({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} сайт заблокирован в сети ${network}',
		few: '${n} сайта заблокировано в сети ${network}',
		many: '${n} сайтов заблокировано в сети ${network}',
		other: '${n} сайта заблокировано в сети ${network}',
	);
	@override String tests({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n,
		one: '${n} проверка',
		few: '${n} проверки',
		many: '${n} проверок',
		other: '${n} проверки',
	);
}

// Path: home.status
class _Translations$home$status$ru extends Translations$home$status$en {
	_Translations$home$status$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get paused => 'Пауза';
	@override String get reconnecting => 'Переподключение';
	@override String get protected => 'Защищено';
	@override String get connecting => 'Подключение';
	@override String get stopping => 'Отключение';
	@override String get notProtected => 'Не защищено';
}

// Path: home.network
class _Translations$home$network$ru extends Translations$home$network$en {
	_Translations$home$network$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'ЭТА СЕТЬ';
	@override String get wifi => 'Wi-Fi';
	@override String get offline => 'Нет сети';
	@override String get showName => 'Показать имя';
	@override String get scanFailed => 'Проверка не удалась. Она повторится при смене сети.';
}

// Path: home.card
class _Translations$home$card$ru extends Translations$home$card$en {
	_Translations$home$card$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get downloaded => 'ПОЛУЧЕНО';
	@override String get uploaded => 'ОТПРАВЛЕНО';
	@override String get wireguard => 'WireGuard';
	@override String openvpn({required Object proto}) => 'OpenVPN ${proto}';
	@override String get selected => 'ВЫБРАН';
	@override String get browsingFrom => 'ВЫХОД В СЕТЬ ИЗ';
	@override String get disconnect => 'Отключить';
	@override String get change => 'Сменить';
	@override String get enabled => 'Вкл.';
	@override String get shield => 'ЩИТ';
}

// Path: home.tiles
class _Translations$home$tiles$ru extends Translations$home$tiles$en {
	_Translations$home$tiles$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get shield => 'Щит';
	@override String get appsDirect => 'Приложения напрямую';
	@override String get appsAll => 'Все приложения защищены';
	@override String appsSkip({required Object n}) => '${n} без VPN';
	@override String get autoConnect => 'Автоподключение';
	@override String get autoOpen => 'В публичных Wi-Fi';
	@override String get autoAny => 'В любой Wi-Fi';
	@override String get speed => 'Скорость';
	@override String get speedTap => 'Нажмите для теста';
	@override String speedDirect({required Object mbps}) => 'Напрямую ${mbps} Мбит/с';
}

// Path: home.fastest
class _Translations$home$fastest$ru extends Translations$home$fastest$en {
	_Translations$home$fastest$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Самый быстрый бесплатный сервер';
	@override String get pickedFrom => 'Выбран из';
	@override String more({required Object n}) => '+${n}';
	@override String get finding => 'Ищем самый быстрый сервер';
	@override String get failed => 'Не удалось загрузить бесплатные серверы';
	@override String get how => 'Как выбирается сервер';
	@override String get sheetBody => 'G VPN подключает вас к бесплатному серверу с лучшим рейтингом на данный момент: по скорости, нагрузке и времени непрерывной работы. Рейтинг меняется по мере появления и исчезновения серверов.';
}

// Path: home.ip
class _Translations$home$ip$ru extends Translations$home$ip$en {
	_Translations$home$ip$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Что видят сайты';
	@override String get real => 'Ваше реальное местоположение';
	@override String get vpn => 'Местоположение VPN';
	@override String get address => 'IP-адрес';
	@override String get coordinates => 'Координаты';
	@override String get note => 'Определено по IP. Не сохраняется.';
	@override String get hide => 'Скрыть моё местоположение';
	@override String near({required Object place}) => 'Примерно: ${place}';
}

// Path: servers.tabs
class _Translations$servers$tabs$ru extends Translations$servers$tabs$en {
	_Translations$servers$tabs$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get pro => 'Pro';
	@override String get free => 'Бесплатные';
	@override String get yours => 'Ваши';
}

// Path: servers.sheet
class _Translations$servers$sheet$ru extends Translations$servers$sheet$en {
	_Translations$servers$sheet$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Откуда берутся серверы';
	@override String get subtitle => 'Три вида, один список';
	@override String get free => 'Серверы волонтёров, проверяются каждые два часа. Их владельцы хранят журналы подключений около двух недель.';
	@override String get pro => 'Наши серверы на WireGuard. Без журналов активности, без аккаунта.';
	@override String get yours => 'Любой ваш сервер WireGuard: роутер, VPS или домашний сервер.';
}

// Path: servers.badges
class _Translations$servers$badges$ru extends Translations$servers$badges$en {
	_Translations$servers$badges$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get mostUsed => 'ПОПУЛЯРНЫЙ';
	@override String get mostStable => 'САМЫЙ СТАБИЛЬНЫЙ';
	@override String get fastest => 'САМЫЙ БЫСТРЫЙ';
}

// Path: servers.filters
class _Translations$servers$filters$ru extends Translations$servers$filters$en {
	_Translations$servers$filters$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get all => 'Все';
	@override String get fastest => 'Самые быстрые';
	@override String get stable => 'Самые стабильные';
	@override String get popular => 'Популярные';
}

// Path: servers.own
class _Translations$servers$own$ru extends Translations$servers$own$en {
	_Translations$servers$own$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Свой сервер';
	@override String get subtitle => 'Подойдёт любой сервер WireGuard';
	@override String get router => 'Роутер';
	@override String get routerBody => 'Во многих роутерах WireGuard встроен. Экспортируйте конфигурацию клиента и отсканируйте её QR-код здесь.';
	@override String get vps => 'VPS';
	@override String get vpsBody => 'Любой небольшой Linux-сервер. Установите WireGuard, создайте клиента и импортируйте файл конфигурации.';
	@override String get home => 'Домашний сервер';
	@override String get homeBody => 'Доступ к своей сети откуда угодно тем же способом.';
	@override String get noneYet => 'Ещё нет сервера?';
	@override String get addAnother => 'Добавить ещё';
	@override String get hint => 'Запустите его на роутере, VPS или домашнем сервере';
}

// Path: pro.free
class _Translations$pro$free$ru extends Translations$pro$free$en {
	_Translations$pro$free$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ваш план';
	@override String get headline => 'Всё бесплатно';
	@override String get body => 'Все серверы и все инструменты, без аккаунта и без рекламы.';
	@override String get included => 'Что входит';
	@override String get servers => 'Бесплатные серверы';
	@override String get serversSub => 'Рейтинг по скорости и стабильности в десятках стран';
	@override String get own => 'Ваши серверы';
	@override String get ownSub => 'Подключение к любому роутеру, VPS или домашнему серверу WireGuard';
	@override String get shield => 'Щит';
	@override String get shieldSub => 'Блокирует известные вредоносные и фишинговые сайты';
	@override String get auto => 'Автоподключение и правила приложений';
	@override String get autoSub => 'Защита публичных Wi-Fi; банковские приложения напрямую';
	@override String get pause => 'Пауза и быстрые настройки';
	@override String get pauseSub => 'Пауза из уведомления, переключение из плитки';
	@override String get tools => 'Все сетевые инструменты';
	@override String get toolsSub => 'Тест скорости, пинг, статус сервисов, трассировка, устройства и другое';
	@override String get later => 'G VPN Pro добавит быстрые серверы, которыми управляем мы. Всё перечисленное останется бесплатным.';
}

// Path: rules.info
class _Translations$rules$info$ru extends Translations$rules$info$en {
	_Translations$rules$info$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get shield => 'Щит фильтрует DNS-запросы, пока вы подключены: Quad9 блокирует вредоносное ПО и фишинг, Cloudflare for Families также блокирует сайты для взрослых, или используйте свой DNS. Рекламу он не блокирует никогда.';
	@override String get autoConnect => 'Автоподключение: использует выбранный вами сервер WireGuard. Ручное отключение приостанавливает его до подключения к другой сети.';
	@override String get apps => 'Приложения напрямую: приложения вне VPN подключаются напрямую. Банки часто блокируют адреса VPN, поэтому платежи через VPN могут не проходить.';
	@override String get reconnect => 'Изменение щита или списка приложений ненадолго переподключает VPN.';
	@override String get stay => 'Оставаться на связи: некоторые телефоны останавливают фоновые приложения для экономии батареи. Постоянный VPN и неограниченный режим батареи сохраняют работу G VPN.';
}

// Path: devices.kinds
class _Translations$devices$kinds$ru extends Translations$devices$kinds$en {
	_Translations$devices$kinds$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get phone => 'Телефон';
	@override String get computer => 'Компьютер';
	@override String get tv => 'ТВ';
	@override String get speaker => 'Колонка';
	@override String get printer => 'Принтер';
	@override String get camera => 'Камера';
	@override String get smartHome => 'Умный дом';
	@override String get router => 'Роутер';
	@override String get unknown => 'Не представилось';
}

// Path: map.grade
class _Translations$map$grade$ru extends Translations$map$grade$en {
	_Translations$map$grade$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get fast => 'Быстрый';
	@override String get good => 'Хороший';
	@override String get slow => 'Медленный';
}

// Path: presets.names
class _Translations$presets$names$ru extends Translations$presets$names$en {
	_Translations$presets$names$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get fastest => 'Самый быстрый';
	@override String get unblock => 'Обход блокировок';
	@override String get streaming => 'Стриминг';
	@override String get privacy => 'Максимум приватности';
}

// Path: providers.tags
class _Translations$providers$tags$ru extends Translations$providers$tags$en {
	_Translations$providers$tags$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get fast => 'Быстрый';
	@override String get reliable => 'Надёжный';
	@override String get support => 'Хорошая поддержка';
	@override String get price => 'Честная цена';
	@override String get slowEvenings => 'Медленно вечером';
	@override String get drops => 'Часто обрывается';
	@override String get poorSupport => 'Плохая поддержка';
	@override String get pricey => 'Дорого';
}

// Path: providers.words
class _Translations$providers$words$ru extends Translations$providers$words$en {
	_Translations$providers$words$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get bad => 'Плохо';
	@override String get poor => 'Слабо';
	@override String get okay => 'Нормально';
	@override String get good => 'Хорошо';
	@override String get great => 'Отлично';
}

// Path: alerts.kinds
class _Translations$alerts$kinds$ru extends Translations$alerts$kinds$en {
	_Translations$alerts$kinds$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get newDevice => 'Новые устройства в моём Wi-Fi';
	@override String get openWifi => 'Открытый или слабый Wi-Fi';
	@override String get blocked => 'Заблокированные приложения';
	@override String get report => 'Еженедельный отчёт';
	@override String get breach => 'Утечки';
}

// Path: alerts.status
class _Translations$alerts$status$ru extends Translations$alerts$status$en {
	_Translations$alerts$status$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get background => 'Раз в несколько часов';
	@override String checked({required Object time}) => 'Проверено в ${time}';
	@override String get wifi => 'Каждая сеть, к которой вы подключаетесь';
	@override String get blocked => 'Когда проверяется статус сервисов';
	@override String get report => 'Каждый понедельник';
}

// Path: blocked.kinds
class _Translations$blocked$kinds$ru extends Translations$blocked$kinds$en {
	_Translations$blocked$kinds$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get social => 'Соцсети';
	@override String get messaging => 'Мессенджеры';
	@override String get news => 'Новости';
	@override String get video => 'Видео и музыка';
	@override String get privacy => 'Приватность';
}

// Path: blocked.how
class _Translations$blocked$how$ru extends Translations$blocked$how$en {
	_Translations$blocked$how$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get dns => 'Ложный адрес';
	@override String get reset => 'Обрыв';
	@override String get timeout => 'Нет ответа';
	@override String get page => 'Страница блокировки';
	@override String get open => 'Открыт';
}

// Path: blocked.fail
class _Translations$blocked$fail$ru extends Translations$blocked$fail$en {
	_Translations$blocked$fail$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get noAnswer => 'нет ответа';
	@override String get refused => 'отказано';
	@override String cutOff({required Object s}) => 'обрыв через ${s} с';
	@override String get wrongCert => 'неверный сертификат';
}

// Path: blocked.steps
class _Translations$blocked$steps$ru extends Translations$blocked$steps$en {
	_Translations$blocked$steps$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get lookup => 'Поиск имени';
	@override String get connect => 'Подключение';
	@override String get handshake => 'Защищённое соединение';
}

// Path: blocked.consent
class _Translations$blocked$consent$ru extends Translations$blocked$consent$en {
	_Translations$blocked$consent$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get title => 'Перед первой проверкой';
	@override String get body => 'Проверка открывает каждый сайт с этого телефона без VPN, как это сделал бы браузер.';
	@override String get noticeTitle => 'Это может быть заметно';
	@override String get notice => 'Ваш провайдер видит, что эти сайты открываются. В некоторых странах их посещение, даже ради проверки, может привлечь внимание. Проверяйте только там, где чувствуете себя в безопасности.';
	@override String get ok => 'Понятно, проверить';
}

/// The flat map containing all translations for locale <ru>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsRu {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.gotIt' => 'Понятно',
			'common.about' => 'О приложении',
			'common.connect' => 'Подключить',
			'common.connected' => 'Подключено',
			'common.retry' => 'Повторить',
			'common.ok' => 'ОК',
			'common.remove' => 'Удалить',
			'common.cancel' => 'Отмена',
			'common.continueLabel' => 'Продолжить',
			'common.notNow' => 'Не сейчас',
			'common.openSettings' => 'Открыть настройки',
			'common.close' => 'Закрыть',
			'common.off' => 'Выкл.',
			'common.changesReconnect' => 'Изменения переподключат VPN',
			'nav.vpn' => 'VPN',
			'nav.servers' => 'Серверы',
			'nav.tools' => 'Инструменты',
			'nav.rules' => 'Правила',
			'nav.pro' => 'Pro',
			'home.status.paused' => 'Пауза',
			'home.status.reconnecting' => 'Переподключение',
			'home.status.protected' => 'Защищено',
			'home.status.connecting' => 'Подключение',
			'home.status.stopping' => 'Отключение',
			'home.status.notProtected' => 'Не защищено',
			'home.resumesAt' => ({required Object time}) => 'Возобновится в ${time} · нажмите, чтобы продолжить сейчас',
			'home.ipFailed' => 'Не удалось проверить IP',
			'home.ipChecking' => 'Проверка IP',
			'home.themeSystem' => 'Тема: как в телефоне',
			'home.themeLight' => 'Тема: светлая',
			'home.themeDark' => 'Тема: тёмная',
			'home.free' => 'Бесплатно',
			'home.pickServer' => 'Выберите сервер',
			'home.network.title' => 'ЭТА СЕТЬ',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Нет сети',
			'home.network.showName' => 'Показать имя',
			'home.network.scanFailed' => 'Проверка не удалась. Она повторится при смене сети.',
			'home.card.downloaded' => 'ПОЛУЧЕНО',
			'home.card.uploaded' => 'ОТПРАВЛЕНО',
			'home.card.wireguard' => 'WireGuard',
			'home.card.openvpn' => ({required Object proto}) => 'OpenVPN ${proto}',
			'home.card.selected' => 'ВЫБРАН',
			'home.card.browsingFrom' => 'ВЫХОД В СЕТЬ ИЗ',
			'home.card.disconnect' => 'Отключить',
			'home.card.change' => 'Сменить',
			'home.card.enabled' => 'Вкл.',
			'home.card.shield' => 'ЩИТ',
			'home.tiles.shield' => 'Щит',
			'home.tiles.appsDirect' => 'Приложения напрямую',
			'home.tiles.appsAll' => 'Все приложения защищены',
			'home.tiles.appsSkip' => ({required Object n}) => '${n} без VPN',
			'home.tiles.autoConnect' => 'Автоподключение',
			'home.tiles.autoOpen' => 'В публичных Wi-Fi',
			'home.tiles.autoAny' => 'В любой Wi-Fi',
			'home.tiles.speed' => 'Скорость',
			'home.tiles.speedTap' => 'Нажмите для теста',
			'home.tiles.speedDirect' => ({required Object mbps}) => 'Напрямую ${mbps} Мбит/с',
			'home.fastest.title' => 'Самый быстрый бесплатный сервер',
			'home.fastest.pickedFrom' => 'Выбран из',
			'home.fastest.more' => ({required Object n}) => '+${n}',
			'home.fastest.finding' => 'Ищем самый быстрый сервер',
			'home.fastest.failed' => 'Не удалось загрузить бесплатные серверы',
			'home.fastest.how' => 'Как выбирается сервер',
			'home.fastest.sheetBody' => 'G VPN подключает вас к бесплатному серверу с лучшим рейтингом на данный момент: по скорости, нагрузке и времени непрерывной работы. Рейтинг меняется по мере появления и исчезновения серверов.',
			'home.ip.title' => 'Что видят сайты',
			'home.ip.real' => 'Ваше реальное местоположение',
			'home.ip.vpn' => 'Местоположение VPN',
			'home.ip.address' => 'IP-адрес',
			'home.ip.coordinates' => 'Координаты',
			'home.ip.note' => 'Определено по IP. Не сохраняется.',
			'home.ip.hide' => 'Скрыть моё местоположение',
			'home.ip.near' => ({required Object place}) => 'Примерно: ${place}',
			'servers.title' => 'Серверы',
			'servers.aboutServers' => 'О серверах',
			'servers.tabs.pro' => 'Pro',
			'servers.tabs.free' => 'Бесплатные',
			'servers.tabs.yours' => 'Ваши',
			'servers.sheet.title' => 'Откуда берутся серверы',
			'servers.sheet.subtitle' => 'Три вида, один список',
			'servers.sheet.free' => 'Серверы волонтёров, проверяются каждые два часа. Их владельцы хранят журналы подключений около двух недель.',
			'servers.sheet.pro' => 'Наши серверы на WireGuard. Без журналов активности, без аккаунта.',
			'servers.sheet.yours' => 'Любой ваш сервер WireGuard: роутер, VPS или домашний сервер.',
			'servers.badges.mostUsed' => 'ПОПУЛЯРНЫЙ',
			'servers.badges.mostStable' => 'САМЫЙ СТАБИЛЬНЫЙ',
			'servers.badges.fastest' => 'САМЫЙ БЫСТРЫЙ',
			'servers.filters.all' => 'Все',
			'servers.filters.fastest' => 'Самые быстрые',
			'servers.filters.stable' => 'Самые стабильные',
			'servers.filters.popular' => 'Популярные',
			'servers.loadFailed' => 'Не удалось загрузить список',
			'servers.noServers' => 'Сейчас серверов нет',
			'servers.best' => 'ЛУЧШИЙ ДЛЯ ВАС СЕЙЧАС',
			'servers.topRanked' => 'Лучший в рейтинге сейчас',
			'servers.addHeading' => 'ДОБАВИТЬ СЕРВЕР',
			'servers.scanQr' => 'Сканировать QR',
			'servers.importFile' => 'Импорт файла',
			'servers.paste' => 'Вставить',
			'servers.own.title' => 'Свой сервер',
			'servers.own.subtitle' => 'Подойдёт любой сервер WireGuard',
			'servers.own.router' => 'Роутер',
			'servers.own.routerBody' => 'Во многих роутерах WireGuard встроен. Экспортируйте конфигурацию клиента и отсканируйте её QR-код здесь.',
			'servers.own.vps' => 'VPS',
			'servers.own.vpsBody' => 'Любой небольшой Linux-сервер. Установите WireGuard, создайте клиента и импортируйте файл конфигурации.',
			'servers.own.home' => 'Домашний сервер',
			'servers.own.homeBody' => 'Доступ к своей сети откуда угодно тем же способом.',
			'servers.own.noneYet' => 'Ещё нет сервера?',
			'servers.own.addAnother' => 'Добавить ещё',
			'servers.own.hint' => 'Запустите его на роутере, VPS или домашнем сервере',
			'servers.configBroken' => 'Конфигурация требует внимания',
			'servers.connectedBadge' => 'ПОДКЛЮЧЕНО',
			'servers.scannedServer' => 'Отсканированный сервер',
			'servers.scanFailedTitle' => 'Не удалось сканировать',
			'servers.scanFailedBody' => 'Сканер недоступен на этом телефоне.',
			'servers.importFailedTitle' => 'Не удалось импортировать',
			'servers.importFailedBody' => 'Не удалось прочитать этот файл.',
			'servers.renameTitle' => 'Переименовать сервер',
			'servers.nameHint' => 'Название, например Домашний роутер',
			'servers.save' => 'Сохранить',
			'servers.rename' => 'Переименовать',
			'servers.disconnect' => 'Отключить',
			'servers.more' => 'Ещё',
			'servers.justNow' => 'только что',
			'servers.minutesAgo' => ({required Object n}) => '${n} мин назад',
			'servers.hoursAgo' => ({required Object n}) => '${n} ч назад',
			'servers.daysAgo' => ({required Object n}) => '${n} дн. назад',
			'servers.neverUsed' => 'Ещё не использовался',
			'servers.lastUsed' => ({required Object when}) => 'Использовался ${when}',
			'servers.disconnectFirst' => 'Сначала отключитесь, чтобы удалить',
			'servers.removeConfirm' => 'Удалить этот сервер из G VPN? Его настройки удалятся с этого телефона; сам сервер не изменится.',
			'servers.gTab' => 'G Servers',
			'servers.search' => 'Поиск стран',
			'servers.noMatch' => 'Нет подходящих серверов.',
			'servers.bestPing' => ({required Object ms}) => 'лучший ${ms} мс',
			'servers.bestTag' => 'ЛУЧШИЙ',
			'servers.ownHero' => 'Наши серверы',
			'servers.ownHeroSub' => 'Быстрее, приватно, у каждого телефона свой ключ',
			'servers.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} сервер', few: '${n} сервера', many: '${n} серверов', other: '${n} сервера', ), 
			'servers.showAll' => ({required Object n}) => 'Показать все ${n}',
			'servers.showFewer' => 'Свернуть',
			'servers.fastTab' => 'Быстрые',
			'servers.fastestFree' => 'Самые быстрые бесплатные',
			'pro.owned' => 'У вас есть Pro',
			'pro.waitingPlay' => 'Ожидание Google Play',
			'pro.startTrial' => ({required Object days}) => 'Начать бесплатный период на ${days} дн.',
			'pro.restore' => 'Восстановить',
			'pro.save' => ({required Object pct}) => 'ЭКОНОМИЯ ${pct}%',
			'pro.yearly' => 'На год',
			'pro.monthly' => 'На месяц',
			'pro.billedMonthly' => 'оплата ежемесячно',
			'pro.daysFree' => ({required Object days}) => '${days} дн. бесплатно',
			'pro.perMonth' => ({required Object price}) => '${price} в месяц',
			'pro.title' => 'G VPN Pro',
			'pro.renewGeneric' => 'Подписки продлеваются автоматически до отмены. Отмена в любой момент в Google Play.',
			'pro.renewTrial' => ({required Object days, required Object price, required Object period}) => '${days} дн. бесплатно, затем ${price} за ${period}. Продлевается автоматически до отмены; отмените в Google Play не позднее чем за день до конца пробного периода, чтобы не было списания.',
			'pro.renew' => ({required Object price, required Object period}) => '${price} за ${period}. Продлевается автоматически до отмены; отмена в любой момент в Google Play.',
			'pro.year' => 'год',
			'pro.month' => 'месяц',
			'pro.manage' => 'Управление подпиской',
			'pro.free.title' => 'Ваш план',
			'pro.free.headline' => 'Всё бесплатно',
			'pro.free.body' => 'Все серверы и все инструменты, без аккаунта и без рекламы.',
			'pro.free.included' => 'Что входит',
			'pro.free.servers' => 'Бесплатные серверы',
			'pro.free.serversSub' => 'Рейтинг по скорости и стабильности в десятках стран',
			'pro.free.own' => 'Ваши серверы',
			'pro.free.ownSub' => 'Подключение к любому роутеру, VPS или домашнему серверу WireGuard',
			'pro.free.shield' => 'Щит',
			'pro.free.shieldSub' => 'Блокирует известные вредоносные и фишинговые сайты',
			'pro.free.auto' => 'Автоподключение и правила приложений',
			'pro.free.autoSub' => 'Защита публичных Wi-Fi; банковские приложения напрямую',
			'pro.free.pause' => 'Пауза и быстрые настройки',
			'pro.free.pauseSub' => 'Пауза из уведомления, переключение из плитки',
			'pro.free.tools' => 'Все сетевые инструменты',
			'pro.free.toolsSub' => 'Тест скорости, пинг, статус сервисов, трассировка, устройства и другое',
			'pro.free.later' => 'G VPN Pro добавит быстрые серверы, которыми управляем мы. Всё перечисленное останется бесплатным.',
			'pro.heroLine' => 'Наши быстрые серверы и все проверки без ограничений',
			'pro.start' => 'Начать Pro',
			'pro.compareFree' => 'БЕСПЛАТНО',
			'pro.comparePro' => 'PRO',
			'pro.rowFreeServers' => 'Бесплатные серверы',
			'pro.rowTools' => 'Тест скорости, инструменты, проверка Wi-Fi',
			'pro.rowGServers' => 'G Servers, без журналов',
			'pro.rowLinks' => 'Проверка ссылок',
			'pro.linksFree' => ({required Object n}) => '${n} в месяц',
			'pro.unlimited' => 'Без ограничений',
			'rules.title' => 'Правила',
			'rules.info.shield' => 'Щит фильтрует DNS-запросы, пока вы подключены: Quad9 блокирует вредоносное ПО и фишинг, Cloudflare for Families также блокирует сайты для взрослых, или используйте свой DNS. Рекламу он не блокирует никогда.',
			'rules.info.autoConnect' => 'Автоподключение: использует выбранный вами сервер WireGuard. Ручное отключение приостанавливает его до подключения к другой сети.',
			'rules.info.apps' => 'Приложения напрямую: приложения вне VPN подключаются напрямую. Банки часто блокируют адреса VPN, поэтому платежи через VPN могут не проходить.',
			'rules.info.reconnect' => 'Изменение щита или списка приложений ненадолго переподключает VPN.',
			'rules.info.stay' => 'Оставаться на связи: некоторые телефоны останавливают фоновые приложения для экономии батареи. Постоянный VPN и неограниченный режим батареи сохраняют работу G VPN.',
			'rules.protection' => 'Защита',
			'rules.shield' => 'Щит',
			'rules.privateDns' => 'Щит без VPN',
			'rules.privateDnsSub' => 'Скопировать dns.quad9.net для частного DNS',
			'rules.privateDnsCopied' => 'dns.quad9.net скопирован',
			'rules.privateDnsHow' => 'Откройте Настройки, найдите «Частный DNS», выберите «Имя хоста поставщика частного DNS» и вставьте его.',
			'rules.stay' => 'Оставаться на связи',
			'rules.alwaysOn' => 'Постоянный VPN',
			'rules.alwaysOnSub' => 'Android перезапустит G VPN, если он остановится',
			'rules.battery' => 'Батарея',
			'rules.batteryOk' => 'Без ограничений',
			'rules.batteryRestricted' => 'Ограничено: может остановиться в фоне',
			'rules.autoConnect' => 'Автоподключение',
			'rules.autoOff' => 'Выкл.',
			'rules.autoOffSub' => 'Только по нажатию',
			'rules.autoOpen' => 'Публичные Wi-Fi',
			'rules.autoOpenSub' => 'Открытые, WEP или с входом через страницу',
			'rules.autoAny' => 'Любой Wi-Fi',
			'rules.autoAnySub' => 'Любая сеть Wi-Fi',
			'rules.apps' => 'Приложения',
			'rules.appsDirect' => 'Приложения напрямую',
			'rules.appsNone' => 'Все приложения используют VPN',
			'rules.appsSome' => ({required Object n}) => '${n} прилож. без VPN',
			'rules.appearance' => 'Оформление',
			'rules.themePhone' => 'Как в телефоне',
			'rules.themeLight' => 'Светлая',
			'rules.themeDark' => 'Тёмная',
			'rules.about' => 'О приложении',
			'apps.title' => 'Приложения напрямую',
			'apps.sheetSubtitle' => 'Выбранные приложения подключаются без VPN. Всё остальное остаётся защищённым.',
			'apps.whyTitle' => 'Зачем исключать приложение',
			'apps.whyBody' => 'Банки и платёжные приложения часто блокируют адреса VPN, поэтому платежи через VPN могут не проходить. Некоторые местные сервисы работают только из вашей страны.',
			'apps.favouritesBody' => 'Отмечайте звёздочкой приложения, которые часто меняете; они останутся сверху.',
			'apps.whileConnected' => 'Во время подключения',
			'apps.whileConnectedBody' => 'Изменение этого списка ненадолго переподключает VPN.',
			'apps.search' => ({required Object n}) => 'Поиск среди ${n} приложений',
			'apps.skipping' => 'Без VPN',
			'apps.skippingNone' => 'Нет. Все приложения идут через VPN.',
			'apps.protectAgain' => ({required Object app}) => 'Снова защитить ${app}',
			'apps.banking' => 'Банки и платежи',
			'apps.bankingFound' => ({required Object n}) => 'Найдено ${n}, могут блокировать VPN',
			'apps.addAll' => 'Добавить все',
			'apps.favourites' => 'Избранное',
			'apps.all' => 'Все приложения',
			'apps.found' => ({required Object n}) => 'Найдено: ${n}',
			'apps.noMatch' => 'Приложений не найдено.',
			'apps.showAll' => ({required Object n}) => 'Показать все (${n})',
			'apps.skips' => 'Без VPN',
			'apps.unstar' => 'Убрать из избранного',
			'apps.star' => 'Добавить в избранное',
			'location.title' => 'Доступ к геолокации для Wi-Fi',
			'location.useHome' => 'Показывать имя Wi-Fi на главном экране',
			'location.useScan' => 'Сканировать ближайшие сети и каналы',
			'location.private' => 'Остаётся на этом телефоне. Ваше местоположение не собирается.',
			'location.switchTitle' => 'Включите геолокацию',
			'location.switchBody' => 'Android скрывает имена Wi-Fi, пока геолокация выключена',
			'addServer.clipboardEmpty' => 'Буфер обмена пуст.',
			'addServer.title' => 'Добавить свой сервер',
			'addServer.body' => 'Вставьте конфигурацию WireGuard с вашего роутера, VPS или домашнего сервера.',
			'addServer.nameHint' => 'Название, например Домашний роутер',
			'addServer.paste' => 'Вставить',
			'addServer.save' => 'Сохранить сервер',
			'addServer.notWireguard' => ({required Object error}) => 'Это не конфигурация WireGuard: ${error}',
			'button.stop' => 'Стоп',
			'button.connecting' => 'Подключение',
			'button.stopping' => 'Отключение',
			'button.connect' => 'Подключить',
			'button.disconnect' => 'Отключить',
			'wol.info' => 'Включает компьютер или NAS в этой сети Wi-Fi, если в его настройках включён Wake on LAN. Телефон должен быть в той же сети; сначала выключите VPN.',
			'wol.badMac' => 'Это не MAC-адрес. Он выглядит так: AA:BB:CC:DD:EE:FF.',
			'wol.sent' => 'Сигнал отправлен. Устройство должно включиться в течение минуты.',
			'wol.title' => 'Wake on LAN',
			'wol.mac' => 'MAC-адрес',
			'wol.failed' => ({required Object error}) => 'Не удалось отправить: ${error}',
			'wol.computer' => 'Компьютер',
			'wol.pick' => 'Выберите устройство для включения',
			'wol.waking' => ({required Object name}) => 'Включаем ${name}',
			'wol.yours' => 'ВАШИ УСТРОЙСТВА',
			'wol.wakeNamed' => ({required Object name}) => 'Включить ${name}',
			'wol.removeHint' => 'Удерживайте устройство, чтобы удалить',
			'wol.add' => 'ДОБАВИТЬ УСТРОЙСТВО',
			'wol.name' => 'Название',
			'wol.saveWake' => 'Сохранить и включить',
			'speed.download' => 'Загрузка',
			'speed.upload' => 'Отдача',
			'speed.finding' => 'Поиск сервера',
			'speed.throughVpn' => 'Через VPN',
			'speed.directNoVpn' => 'Напрямую, без VPN',
			'speed.title' => 'Тест скорости',
			'speed.stop' => 'Стоп',
			'speed.start' => 'Начать тест',
			'speed.again' => 'Повторить тест',
			'speed.viaVpn' => 'Через VPN',
			'speed.direct' => 'Напрямую',
			'speed.mbps' => 'Мбит/с',
			'speed.ping' => 'ПИНГ',
			'speed.vsDirect' => 'К НАПРЯМУЮ',
			'speed.compare' => 'Сравнить с провайдерами поблизости',
			'speed.compareSub' => 'Передаёт только скорость, никогда ваш IP',
			'speed.tierTv' => 'Большие телевизоры',
			'speed.tierLaptopLarge' => 'Большие ноутбуки',
			'speed.tierTablet' => 'Планшеты и ноутбуки',
			'speed.tierPhone' => 'Телефоны',
			'speed.tierSmallPhone' => 'Небольшие телефоны',
			'speed.tierCalls' => 'Звонки и аудио',
			'speed.messagingOnly' => 'Только мессенджеры',
			'speed.videoQuality' => 'Качество видео',
			'speed.preview' => 'ПРЕДПРОСМОТР',
			'speed.history' => 'История',
			'speed.clear' => 'Очистить',
			'speed.viaVpnLower' => 'через VPN',
			'speed.directLower' => 'напрямую',
			'speed.gradeA' => 'Несколько 4K-потоков и видеозвонков одновременно',
			'speed.gradeB' => 'HD-видео и плавные видеозвонки',
			'speed.gradeC' => 'Один HD-поток; в часы пик звонки могут прерываться',
			'speed.gradeD' => 'Сайты и мессенджеры; видео тормозит',
			'speed.yourCountry' => 'ваша страна',
			'speed.median' => 'Медиана загрузки за 30 дней',
			'speed.fromUsers' => 'Мбит/с · по тестам пользователей G VPN',
			'speed.costLittle' => 'VPN почти не снижает скорость',
			'speed.costNoticeable' => 'Заметно медленнее, чем напрямую',
			'speed.costMuch' => 'Намного медленнее. Попробуйте другой сервер',
			'speed.ofDirect' => 'от вашей прямой скорости',
			'speed.none' => 'нет',
			'speed.ms' => ({required Object n}) => '${n} мс',
			'speed.previewTier' => ({required Object tier}) => 'ПРЕДПРОСМОТР · ${tier}',
			'speed.streamsUpTo' => ({required Object tier, required Object who}) => 'Видео до ${tier} · ${who}',
			'speed.today' => ({required Object time}) => 'Сегодня, ${time}',
			'speed.tests' => ({required Object n}) => 'Тестов: ${n}',
			'speed.gradeVpn' => ({required Object label}) => '${label} через VPN',
			'speed.gradeIsp' => ({required Object label, required Object isp}) => '${label} у ${isp}',
			'speed.notEnough' => ({required Object isp}) => 'Пока мало тестов для ${isp}',
			'speed.yourProvider' => 'вашего провайдера',
			'speed.rankLine' => ({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} в ${where}: ${rank} из ${of}',
			'speed.costLine' => ({required Object note, required Object mbps}) => '${note} · напрямую ${mbps} Мбит/с',
			'speed.mbpsValue' => ({required Object v}) => '${v} Мбит/с',
			'speed.gradeExcellent' => 'Отлично',
			'speed.gradeVeryGood' => 'Очень хорошо',
			'speed.gradeGood' => 'Хорошо',
			'speed.gradeFair' => 'Удовлетворительно',
			'speed.gradeSlow' => 'Медленно',
			'speed.gradeVerySlow' => 'Очень медленно',
			'router.info' => 'Спрашивает ваш роутер по UPnP, могут ли устройства сами открывать порты в интернет, и показывает уже открытые. Только читает и ничего не меняет. Если UPnP ничему не нужен (некоторым игровым приставкам нужен), безопаснее выключить его в настройках роутера.',
			'router.title' => 'Проверка роутера',
			'router.asking' => 'Опрос роутера',
			'router.again' => 'Проверить снова',
			'router.check' => 'Проверить роутер',
			'router.off' => 'UPnP выключен',
			'router.offBody' => 'Устройства не могут сами открывать порты.',
			'router.onBody' => 'Сейчас через него не открыт ни один порт.',
			'router.checkEach' => 'Убедитесь, что знаете каждый из них.',
			'router.cgnat' => 'Общий адрес провайдера: недоступен из интернета.',
			'router.noDescription' => 'Без описания',
			'router.opened' => ({required Object n}) => 'Устройства открыли портов: ${n}',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} на ${host}',
			'router.upnpOn' => 'UPnP включён',
			'router.routerLabel' => 'Роутер',
			'router.internetAddress' => 'Адрес в интернете',
			'router.openedBy' => 'Открыто устройствами',
			'network.title' => 'Эта сеть',
			'network.wifi' => 'Wi-Fi',
			'network.mobile' => 'Мобильные данные',
			'network.ethernet' => 'Ethernet',
			'network.offline' => 'Нет сети',
			'network.risky' => 'Опасная сеть. Подключите здесь VPN.',
			'network.review' => 'Стоит проверить, прежде чем доверять.',
			'network.covered' => 'Защищено VPN.',
			'network.safe' => 'Сеть выглядит безопасной.',
			'network.mobileSentence' => 'Мобильные данные.',
			'network.notConnected' => 'Нет подключения.',
			'network.showName' => 'Показать имя',
			'network.sitesSee' => 'Сайты видят',
			'network.provider' => 'Провайдер',
			'network.location' => 'Местоположение',
			'network.couldNotCheck' => 'Не удалось проверить',
			'network.checking' => 'Проверка',
			'network.signal' => 'Сигнал',
			'network.linkSpeed' => 'Скорость связи',
			'network.gateway' => 'Шлюз',
			'network.none' => 'Нет',
			'network.privateDns' => 'Частный DNS',
			'network.automatic' => 'Автоматически',
			'network.off' => 'Выкл.',
			'network.metered' => 'Лимитная',
			'network.yes' => 'Да',
			'network.no' => 'Нет',
			'network.readFailed' => ({required Object error}) => 'Не удалось прочитать сеть: ${error}',
			'devices.info' => 'Обращается к каждому адресу в диапазоне вашей сети Wi-Fi и просит устройства представиться. Устройство, ответившее отказом, тоже учитывается: отказ доказывает, что оно есть.\n\nИмена: из того, что публикуют сами устройства (Bonjour, UPnP, имена Windows), и из вашего роутера.\n\nНеизвестные устройства: Android скрывает аппаратные адреса от приложений, поэтому молчащее устройство без имени не опознать. Посмотрите их в списке устройств роутера.\n\nНовое: устройство, которого не было при прошлом сканировании этой сети.',
			'devices.needWifi' => 'Сначала подключитесь к сети Wi-Fi.',
			'devices.title' => 'Устройства',
			'devices.again' => 'Сканировать снова',
			'devices.looking' => 'Поиск устройств',
			'devices.all' => 'Все',
			'devices.phones' => 'Телефоны',
			'devices.tvs' => 'Телевизоры',
			'devices.computers' => 'Компьютеры',
			'devices.other' => 'Другое',
			'devices.thisPhone' => 'Этот телефон',
			'devices.router' => 'Роутер',
			'devices.unknown' => 'Неизвестное устройство',
			'devices.address' => 'Адрес',
			'devices.answersIn' => 'Отвечает за',
			'devices.type' => 'Тип',
			'devices.newBadge' => 'НОВОЕ',
			'devices.scanning' => ({required Object n}) => 'Сканирование ${n} из 254',
			'devices.newSince' => ({required Object n}) => 'Новых с прошлого сканирования: ${n}',
			'devices.ms' => ({required Object n}) => '${n} мс',
			'devices.cameras' => 'Камеры',
			'devices.device' => 'Устройство',
			'devices.online' => 'В сети',
			'devices.model' => 'Модель',
			'devices.announced' => 'Представляется как',
			'devices.services' => 'ОТКРЫТЫЕ СЛУЖБЫ',
			'devices.checkingServices' => 'Проверяем службы',
			'devices.noServices' => 'Обычные службы не отвечают',
			'devices.rename' => 'Переименовать',
			'devices.save' => 'Сохранить',
			'devices.kinds.phone' => 'Телефон',
			'devices.kinds.computer' => 'Компьютер',
			'devices.kinds.tv' => 'ТВ',
			'devices.kinds.speaker' => 'Колонка',
			'devices.kinds.printer' => 'Принтер',
			'devices.kinds.camera' => 'Камера',
			'devices.kinds.smartHome' => 'Умный дом',
			'devices.kinds.router' => 'Роутер',
			'devices.kinds.unknown' => 'Не представилось',
			'devices.details' => 'Сведения о сети',
			'devices.listView' => 'Список',
			'devices.meshView' => 'Сеть-граф',
			'devices.offlineHeading' => 'Не в сети',
			'devices.seen' => ({required Object when}) => 'Был ${when}',
			'devices.agoMinutes' => ({required Object n}) => '${n} мин назад',
			'devices.agoHours' => ({required Object n}) => '${n} ч назад',
			'devices.agoDays' => ({required Object n}) => '${n} дн. назад',
			'devices.throughVpn' => 'Через VPN',
			'devices.closer' => 'Ближе = отвечает быстрее',
			'devices.yours' => 'Это ваше?',
			'devices.mine' => 'Моё',
			'devices.notMine' => 'Не моё',
			'devices.whatIsIt' => 'Что это?',
			'devices.ourGuess' => ({required Object kind}) => 'Наша догадка: ${kind}',
			'devices.groupPersonal' => 'Телефоны и компьютеры',
			'devices.groupHome' => 'Дом и медиа',
			'devices.groupNetwork' => 'Сеть и умный дом',
			'devices.onlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} в сети', few: '${n} в сети', many: '${n} в сети', other: '${n} в сети', ), 
			'devices.offlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} не в сети', few: '${n} не в сети', many: '${n} не в сети', other: '${n} не в сети', ), 
			'devices.toConfirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} подтвердить', few: '${n} подтвердить', many: '${n} подтвердить', other: '${n} подтвердить', ), 
			'ping.askTitle' => 'Пинг узла',
			'ping.askHint' => 'example.com или 192.168.1.10',
			'ping.title' => 'Пинг',
			'ping.router' => 'Роутер',
			'ping.pause' => 'Пауза',
			'ping.start' => 'Старт',
			'ping.host' => 'Узел',
			'ping.live' => 'В реальном времени',
			'ping.ago' => '60 с назад',
			'ping.min' => 'МИН',
			'ping.avg' => 'СРЕД',
			'ping.jitter' => 'ДЖИТТЕР',
			'ping.loss' => 'ПОТЕРИ',
			'ping.goodFor' => 'Подходит для',
			'ping.calls' => 'Видеозвонки',
			'ping.games' => 'Онлайн-игры',
			'ping.streaming' => 'Стриминг',
			'ping.great' => 'Отлично',
			'ping.okay' => 'Нормально',
			'ping.poor' => 'Плохо',
			'ping.lost' => 'потерян',
			'ping.now' => 'сейчас',
			'status.info' => 'Подключается к каждому сервису трижды и показывает самый быстрый ответ.\n\nЗаблокировано здесь: сервис, который не отвечает напрямую, но работает через VPN, заблокирован вашей сетью или страной.\n\nИстория: проверки за последние 24 часа с этого телефона, хранятся только на нём.',
			'status.title' => 'Статус сервисов',
			'status.checking' => 'Проверка',
			'status.again' => 'Проверить снова',
			'status.viaVpn' => 'Проверено через VPN',
			'status.direct' => 'Проверено напрямую',
			'status.favourites' => 'Избранное',
			'status.edit' => 'Изменить',
			'status.last24' => 'Последние 24 часа',
			'status.ago' => '24 ч назад',
			'status.all' => 'Все сервисы',
			'status.pickFour' => 'Выберите до четырёх',
			'status.outage' => 'Даже через VPN: вероятно, сбой',
			'status.blocked' => 'Возможно, заблокирован в этой сети',
			'status.connect' => 'Подключить',
			'status.blockedShort' => 'Блок',
			'status.now' => 'сейчас',
			'status.checks' => ({required Object n}) => 'Проверок: ${n}',
			'status.andMore' => ({required Object first, required Object n}) => '${first} и ещё ${n}',
			'status.notReachable' => ({required Object who}) => '${who}: недоступно',
			'tools.wifi' => 'Wi-Fi',
			'tools.mobile' => 'Мобильные данные',
			'tools.ethernet' => 'Ethernet',
			'tools.checking' => 'Проверка',
			'tools.offline' => 'Нет сети',
			'tools.title' => 'Инструменты',
			'tools.networkDesc' => 'Проверка безопасности, что видят сайты, сигнал, роутер и DNS.',
			'tools.internet' => 'Интернет',
			'tools.speed' => 'Тест скорости',
			'tools.speedDesc' => 'Загрузка, отдача и качество видео',
			'tools.ping' => 'Пинг',
			'tools.pingDesc' => 'Отклик и джиттер в реальном времени',
			'tools.status' => 'Статус сервисов',
			'tools.statusDesc' => 'Приложение доступно или заблокировано?',
			'tools.trace' => 'Трассировка',
			'tools.traceDesc' => 'Каждая остановка на пути к сайту',
			'tools.security' => 'Эта сеть',
			'tools.devices' => 'Устройства в этой сети',
			'tools.devicesDesc' => 'Кто в вашем Wi-Fi',
			'tools.router' => 'Проверка роутера',
			'tools.routerDesc' => 'Порты, открытые устройствами',
			'tools.ports' => 'Открытые порты',
			'tools.portsDesc' => 'Опасные порты на устройстве или сервере',
			'tools.utilities' => 'Утилиты',
			'tools.wifiScanner' => 'Сканер Wi-Fi',
			'tools.wifiDesc' => 'Сети вокруг и самый свободный канал',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Включить компьютер в этой сети',
			'tools.passwordCheck' => 'Проверка пароля',
			'tools.passwordCheckDesc' => 'Утёк ли пароль?',
			'tools.linkCheck' => 'Проверка ссылки',
			_ => null,
		} ?? switch (path) {
			'tools.linkCheckDesc' => 'Безопасно ли открыть?',
			'tools.breaches' => 'Утечки данных',
			'tools.breachesDesc' => 'Что утекло недавно',
			'tools.blocked' => 'Что заблокировано',
			'tools.blockedDesc' => 'Сайты, заблокированные в этой сети',
			'trace.info' => 'Каждая точка обозначает роутер, через который проходит ваш трафик на пути к сайту.\n\nМолчащие узлы: многие роутеры никогда не отвечают на эти пробы. Это нормально и не является ошибкой.\n\nС включённым VPN: маршрут начинается внутри туннеля, поэтому ваша сеть и провайдер скрыты.\n\nКак: используется встроенная в Android утилита ping с ограничением числа узлов, так как приложения не могут отправлять такие пакеты напрямую.',
			'trace.title' => 'Трассировка',
			'trace.stop' => 'Стоп',
			'trace.trace' => 'Трассировать',
			'trace.again' => 'Трассировать снова',
			'trace.destination' => 'Назначение',
			'trace.hops' => 'УЗЛЫ',
			'trace.answered' => 'ОТВЕТИЛИ',
			'trace.total' => 'ВСЕГО',
			'trace.thisPhone' => 'Этот телефон',
			'trace.silentOne' => '1 молчащий узел',
			'trace.yourRouter' => 'Ваш роутер',
			'trace.ms' => ({required Object n}) => '${n} мс',
			'trace.silentMany' => ({required Object n}) => 'Молчащих узлов: ${n}',
			'trace.hop' => ({required Object n}) => 'Узел ${n}',
			'trace.slowest' => ({required Object ms, required Object hop}) => 'Основная задержка, ${ms} мс, добавляется на узле ${hop}: обычно это длинный кабель между странами или перегруженный канал.',
			'trace.popular' => 'ПОПУЛЯРНЫЕ',
			'trace.recent' => 'НЕДАВНИЕ',
			'trace.clearRecent' => 'Очистить недавние',
			'trace.hopsCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} узел', few: '${n} узла', many: '${n} узлов', other: '${n} узла', ), 
			'ports.ftpNote' => 'Передаёт пароли без шифрования.',
			'ports.sshNote' => 'Удалённый вход. Нормально, если вы настроили его сами.',
			'ports.telnetNote' => 'Удалённый вход без шифрования; любимец ботнетов.',
			'ports.dnsNote' => 'Обычно для роутера.',
			'ports.web' => 'Веб (HTTP)',
			'ports.webNote' => 'Обычно страница настроек роутера.',
			'ports.webTls' => 'Веб (HTTPS)',
			'ports.smb' => 'Общий доступ к файлам Windows',
			'ports.smbNote' => 'Никогда не должен быть открыт в интернет.',
			'ports.rtsp' => 'Поток камеры RTSP',
			'ports.rtspNote' => 'Здесь может транслировать камера.',
			'ports.upnpNote' => 'Позволяет устройствам самим открывать порты роутера.',
			'ports.rdp' => 'Удалённый рабочий стол',
			'ports.rdpNote' => 'Частый путь для взлома.',
			'ports.vncNote' => 'Демонстрация экрана, часто без пароля.',
			'ports.tr069Note' => 'Удалённое управление провайдером.',
			'ports.webAlt' => 'Веб (доп.)',
			'ports.webAltTls' => 'Веб (доп. HTTPS)',
			'ports.title' => 'Открытые порты',
			'ports.check' => 'Проверить порты',
			'ports.address' => 'Адрес устройства или сервера',
			'ports.risky' => 'ОПАСНО',
			'ports.review' => 'ПРОВЕРИТЬ',
			'ports.normal' => 'НОРМА',
			'ports.info' => ({required Object n}) => 'Проверяет ${n} портов, важных для домашних роутеров и устройств, и объясняет каждый открытый.\n\nПроверяйте только устройства и серверы, которыми вы владеете или управляете.',
			'ports.checking' => ({required Object n}) => 'Проверка портов: ${n}',
			'ports.yourRouter' => ({required Object ip}) => 'Ваш роутер: ${ip}',
			'ports.noneOpen' => ({required Object host}) => 'На ${host} нет открытых распространённых портов.',
			'ports.summary' => ({required Object open, required Object n}) => 'Открыто ${open} из ${n} проверенных',
			'ports.riskyCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} опасный', few: '${n} опасных', many: '${n} опасных', other: '${n} опасных', ), 
			'ports.noneRisky' => 'Ничего опасного',
			'wifi.title' => 'Сканер Wi-Fi',
			'wifi.allow' => 'Разрешить сканирование Wi-Fi',
			'wifi.needsPermission' => 'Нужен доступ к геолокации.',
			'wifi.scanning' => 'Сканирование',
			'wifi.again' => 'Сканировать снова',
			'wifi.failed' => 'Сканирование не удалось',
			'wifi.none' => 'Сети не найдены. Возможно, геолокация выключена.',
			'wifi.hidden' => 'Скрытая сеть',
			'wifi.nearby' => ({required Object n}) => 'Сетей поблизости: ${n}',
			'wifi.permissionInfo' => 'Android показывает ближайшие сети Wi-Fi только приложениям с доступом к геолокации. G VPN использует его лишь для списка сетей на этом телефоне.',
			'wifi.info' => 'Показывает сети из последнего сканирования телефона. Android разрешает лишь несколько сканирований в минуту, поэтому быстрое повторное может показать тот же список. Рекомендуемый канал: наименее загруженный из 1, 6 и 11, трёх неперекрывающихся.',
			'wifi.airMap' => 'Карта эфира',
			'wifi.channels' => 'Каналы',
			'wifi.list' => 'Список',
			'wifi.secure' => 'Защищена',
			'wifi.weakLabel' => 'Слабая',
			'wifi.openLabel' => 'Открытая',
			'wifi.sizeIsWidth' => 'Размер = ширина канала',
			'wifi.strongest' => 'САМАЯ СИЛЬНАЯ',
			'wifi.openNearby' => 'ОТКРЫТЫЕ РЯДОМ',
			'wifi.onYourChannel' => 'НА ВАШЕМ КАНАЛЕ',
			'wifi.noneNearby' => 'Нет',
			'wifi.verdictOpen' => 'Любой рядом может читать передаваемое',
			'wifi.verdictWep' => 'Старая защита, легко взломать',
			'wifi.verdictWpa' => 'Устаревшая защита',
			'wifi.verdictWps' => 'Включён WPS: проще взломать',
			'wifi.verdictGood' => 'Хорошо защищена',
			'wifi.maker' => 'Производитель',
			'wifi.address' => 'Аппаратный адрес',
			'wifi.privateAddress' => 'Придуман роутером ради приватности',
			'wifi.you' => 'Вы',
			'wifi.onClear' => ({required Object name}) => '${name} на свободном канале',
			'wifi.move' => ({required Object name, required Object n}) => 'Переведите ${name} на канал ${n}',
			'wifi.clear' => 'Свободен',
			'wifi.busy' => 'Занят',
			'wifi.crowded' => 'Перегружен',
			'wifi.allBands' => 'Все диапазоны',
			'wifi.openOnly' => 'Только открытые',
			'wifi.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} сеть', few: '${n} сети', many: '${n} сетей', other: '${n} сети', ), 
			'errors.notAuthorized' => 'Разрешение на VPN не выдано.',
			'errors.turnedOff' => 'VPN был выключен системой или другим приложением.',
			'errors.busy' => 'Запрос разрешения уже открыт.',
			'errors.cancelled' => 'Подключение отменено.',
			'errors.badConfig' => ({required Object error}) => 'Неверная конфигурация сервера: ${error}',
			'errors.timeout' => 'Сервер не ответил.',
			'errors.refused' => 'Сервер отклонил подключение.',
			'errors.failed' => ({required Object error}) => 'Не удалось подключиться: ${error}',
			'errors.tryAnother' => 'Бесплатные серверы появляются и исчезают; попробуйте другой.',
			'errors.downloadFailed' => 'Не удалось загрузить настройки этого сервера. Проверьте подключение или выберите другой сервер.',
			'scan.mobile' => 'Мобильные данные',
			'scan.ping' => 'ПИНГ',
			'scan.noReply' => 'Нет ответа',
			'scan.dns' => 'DNS',
			'scan.dnsQuad9' => 'Quad9, туннель',
			'scan.dnsTunnel' => 'В туннеле',
			'scan.privateDns' => 'Частный DNS',
			'scan.dnsIsp' => 'Провайдер, видно',
			'scan.network' => 'СЕТЬ',
			'scan.offline' => 'Нет сети',
			'scan.open' => 'Открытая, без пароля',
			'scan.wep' => 'WEP, ненадёжно',
			'scan.owe' => 'Открытая, с шифрованием',
			'scan.enterprise' => 'Корпоративная',
			'scan.unknown' => 'Неизвестно',
			'scan.wifi' => 'WI-FI',
			'scan.signIn' => 'Страница входа',
			'scan.ms' => ({required Object n}) => '${n} мс',
			'scan.covered' => ({required Object what}) => '${what}, под защитой',
			'legal.privacy' => 'Политика конфиденциальности',
			'legal.terms' => 'Условия использования',
			'legal.licences' => 'Лицензии открытого ПО',
			'update.ready' => 'Обновление готово',
			'update.restart' => 'Перезапустить',
			'details.share' => 'Поделиться',
			'details.connectedFor' => ({required Object n}) => 'ПОДКЛЮЧЕНО · ${n} МИН',
			'details.notConnected' => 'НЕ ПОДКЛЮЧЕНО',
			'details.downloaded' => 'ПОЛУЧЕНО',
			'details.uploaded' => 'ОТПРАВЛЕНО',
			'details.lastUsed' => 'ИСПОЛЬЗОВАЛСЯ',
			'details.connection' => 'Подключение',
			'details.protocol' => 'Протокол',
			'details.address' => 'Ваш адрес',
			'details.dns' => 'DNS',
			'details.routes' => 'Маршруты',
			'details.allTraffic' => 'Весь трафик',
			'details.someRoutes' => ({required Object n}) => 'Сетей: ${n}',
			'details.keepalive' => 'Keepalive',
			'details.serverKey' => 'Ключ сервера',
			'details.copy' => 'Копировать',
			'details.copied' => 'Скопировано',
			'details.manage' => 'Управление',
			'details.export' => 'Экспорт для резервной копии',
			'details.exportSub' => 'Все ваши серверы в одном файле',
			'share.title' => ({required Object name}) => 'Поделиться: ${name}',
			'share.sameKey' => 'Вы делитесь ключом этого телефона. Любой, у кого он есть, сможет пользоваться сервером от вашего имени, и одновременно с ним может быть подключено только одно устройство.',
			'share.scanHint' => 'На другом телефоне: G VPN, Серверы, Сканировать QR. Сохранённое изображение тоже подойдёт.',
			'share.saveImage' => 'Сохранить изображение',
			'share.send' => 'Отправить',
			'add.title' => 'Добавить сервер',
			'add.subtitle' => 'Любой сервер WireGuard: роутер, VPS или домашний сервер.',
			'add.camera' => 'Сканировать камерой',
			'add.cameraSub' => 'QR на другом экране',
			'add.image' => 'Из изображения',
			'add.imageSub' => 'Скриншот или сохранённое фото',
			'add.noQr' => 'На этом изображении нет QR-кода.',
			'add.tip' => 'Получили QR в WhatsApp или Telegram? Нажмите «Поделиться» на изображении и выберите G VPN.',
			'backup.restored' => ({required Object n}) => 'Восстановлено серверов: ${n}',
			'backup.nothingNew' => 'Эти серверы уже добавлены',
			'gs.proRequired' => 'G Servers доступны подписчикам G VPN Pro.',
			'gs.off' => 'G Servers сейчас выключены.',
			'gs.network' => 'Не удалось связаться с G Servers. Проверьте подключение и попробуйте снова.',
			'gs.active' => 'АКТИВНО',
			'gs.servers' => 'G Servers',
			'gs.busy' => ({required Object n}) => 'Загрузка ${n}%',
			'gs.offline' => 'Не в сети',
			'gs.devices' => 'Ваши устройства',
			'gs.subtitle' => ({required Object country}) => 'G Server · ${country} · WireGuard',
			'gs.busyLabel' => 'ЗАГРУЗКА',
			'gs.status' => 'СТАТУС',
			'gs.online' => 'В сети',
			'gs.onThisServer' => 'На этом сервере',
			'gs.thisPhone' => 'Этот телефон',
			'gs.added' => 'Добавлен · ключ создан здесь',
			'gs.notAdded' => 'Добавится при подключении',
			'gs.logs' => 'Журналы активности',
			'gs.noneKept' => 'Не хранятся',
			'gs.privacy' => 'Сервер знает этот телефон только по открытому ключу. Он не записывает, какие сайты вы посещаете и какой трафик отправляете.',
			'gs.stepPro1' => 'Установите G VPN на телефон с тем же аккаунтом Google.',
			'gs.stepPro2' => 'Откройте вкладку Pro. Pro включится сам, или нажмите «Восстановить».',
			'gs.step3' => 'Нажмите «Подключить». Телефон создаст ключ и будет добавлен в G Servers. Без QR и кодов.',
			'gs.stepFree1' => 'Установите G VPN на телефон.',
			'gs.stepFree2' => 'Откройте вкладку Pro.',
			'gs.devicesIntroPro' => 'Pro привязан к вашему аккаунту Google. У каждого телефона свой ключ, поэтому они не отключают друг друга.',
			'gs.devicesIntroFree' => 'У каждого телефона свой ключ, поэтому они не отключают друг друга.',
			'gs.otherPhone' => 'Другой телефон',
			'gs.lastConnected' => ({required Object when}) => 'Подключался ${when}',
			'gs.noDevices' => 'Подключитесь к G Server один раз, и ваши телефоны появятся здесь.',
			'gs.addTitle' => 'Добавить телефон или переустановить',
			'gs.idle' => ({required Object n}) => 'Телефон, не подключавшийся ${n} дней, удаляется из G Servers автоматически, так что старый или переустановленный телефон не занимает место.',
			'gs.limitNote' => ({required Object n}) => 'До ${n} телефонов на план.',
			'gs.fullTitle' => ({required Object n}) => 'Все ${n} мест заняты',
			'gs.fullBody' => 'Удалите телефон, которым больше не пользуетесь, и этот сразу подключится.',
			'gs.busyNow' => 'Сейчас слишком много новых телефонов. Попробуйте чуть позже.',
			'gs.serverFull' => 'Этот сервер заполнен. Попробуйте другой G Server.',
			'gs.ping' => 'ПИНГ',
			'gs.last24' => 'Загрузка за 24 часа',
			'gs.noHistory' => 'График заполняется по мере работы сервера в течение дня.',
			'gs.chartLabel' => ({required Object max}) => 'Загрузка за последние 24 часа, максимум ${max} процентов',
			'gs.hoursAgo' => '24 ч назад',
			'gs.now' => 'Сейчас',
			'gs.included' => 'Включено',
			'gs.perkServers' => 'Быстрые частные серверы',
			'gs.perkServersSub' => 'WireGuard, наши серверы, без журналов',
			'gs.perkLinks' => 'Безлимитная проверка ссылок',
			'gs.perkLinksSub' => 'Проверяйте каждую присланную ссылку',
			'gs.devicesOf' => ({required Object used, required Object limit}) => 'Ваши устройства · ${used} из ${limit}',
			'gs.eachKey' => 'У каждого телефона свой ключ',
			'gs.connected' => 'Подключено',
			'gs.bestNow' => 'ЛУЧШИЙ ДЛЯ ВАС СЕЙЧАС',
			'gs.logsShort' => 'ЖУРНАЛЫ',
			'map.open' => 'Открыть карту',
			'map.searchCountries' => 'Поиск страны',
			'map.noMatch' => 'Страна не найдена',
			'map.locate' => 'Моё местоположение',
			'map.list' => 'Список',
			'map.map' => 'Карта',
			'map.freeServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} бесплатный сервер', few: '${n} бесплатных сервера', many: '${n} бесплатных серверов', other: '${n} бесплатного сервера', ), 
			'map.grade.fast' => 'Быстрый',
			'map.grade.good' => 'Хороший',
			'map.grade.slow' => 'Медленный',
			'map.switchTo' => 'Переключить',
			'map.freeServer' => ({required Object n}) => 'Бесплатный сервер ${n}',
			'map.best' => 'ЛУЧШИЙ',
			'map.gServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} G Server', few: '${n} G Server', many: '${n} G Server', other: '${n} G Server', ), 
			'stats.thisWeek' => 'Эта неделя',
			'stats.time' => 'Время',
			'stats.data' => 'Данные',
			'stats.protected' => 'под защитой',
			'stats.throughVpn' => 'через VPN',
			'stats.seeDetails' => 'Подробнее',
			'stats.title' => 'Статистика',
			'stats.week' => 'Неделя',
			'stats.month' => 'Месяц',
			'stats.protectedLabel' => 'ПОД ЗАЩИТОЙ',
			'stats.dataUsed' => 'ДАННЫЕ',
			'stats.byServer' => 'ПО СЕРВЕРАМ',
			'stats.onPhone' => 'Хранится только на этом телефоне',
			'stats.reset' => 'Сбросить',
			'stats.resetTitle' => 'Сбросить статистику?',
			'stats.resetBody' => 'Удалит время под защитой и данные на этом телефоне. Отменить нельзя.',
			'stats.hm' => ({required Object h, required Object m}) => '${h} ч ${m} мин',
			'stats.m' => ({required Object m}) => '${m} мин',
			'stats.empty' => 'Подключитесь, чтобы начать подсчёт.',
			'recents.title' => 'Недавние',
			'recents.allServers' => 'Все серверы',
			'recents.free' => 'Бесплатный сервер',
			'recents.yours' => 'Ваш сервер',
			'recents.gserver' => 'G Server',
			'presets.title' => 'Профили',
			'presets.all' => 'Все',
			'presets.newPreset' => 'Новый профиль',
			'presets.edit' => 'Изменить профиль',
			'presets.name' => 'Название',
			'presets.namePlaceholder' => 'Мой профиль',
			'presets.server' => 'СЕРВЕР',
			'presets.fastestOption' => 'Самый быстрый',
			'presets.countryOption' => 'Страна',
			'presets.pickCountry' => 'Выберите страну',
			'presets.skipMyCountry' => 'Не моя страна',
			'presets.notMine' => 'не моя страна',
			'presets.protocol' => 'ПРОТОКОЛ',
			'presets.auto' => 'Авто',
			'presets.tryNext' => 'Если заблокировано, пробовать следующий',
			'presets.shield' => 'ЩИТ',
			'presets.followRules' => 'Как в Правилах',
			'presets.allApps' => 'Все приложения через VPN',
			'presets.allAppsShort' => 'все приложения',
			'presets.save' => 'Сохранить',
			'presets.delete' => 'Удалить',
			'presets.reset' => 'Сбросить',
			'presets.none' => 'Сейчас нет бесплатного сервера для этого профиля.',
			'presets.names.fastest' => 'Самый быстрый',
			'presets.names.unblock' => 'Обход блокировок',
			'presets.names.streaming' => 'Стриминг',
			'presets.names.privacy' => 'Максимум приватности',
			'shield.title' => 'Щит',
			'shield.sub' => 'Работает, пока вы подключены',
			'shield.off' => 'Выкл.',
			'shield.offSub' => 'DNS самого сервера',
			'shield.malware' => 'Вредоносное ПО',
			'shield.malwareSub' => 'Блокирует вредоносные и фишинговые сайты',
			'shield.family' => 'Вредоносное ПО и сайты для взрослых',
			'shield.familySub' => 'Также блокирует контент для взрослых',
			'shield.custom' => 'Свой DNS',
			'shield.customSub' => 'Ваши DNS-серверы',
			'shield.customHint' => 'IP-адрес, например 1.1.1.1',
			'shield.invalid' => 'Введите один или два IP-адреса.',
			'checks.title' => 'Проверки',
			'checks.password' => 'Пароль',
			'checks.link' => 'Ссылка',
			'checks.pwTitle' => 'Утёк ли пароль?',
			'checks.pwHint' => 'Пароль для проверки',
			'checks.showPassword' => 'Показать пароль',
			'checks.hidePassword' => 'Скрыть пароль',
			'checks.check' => 'Проверить',
			'checks.leaked' => 'Найден в утечках',
			'checks.seen' => ({required Object n}) => 'Встречался ${n} раз',
			'checks.leakedAdvice' => 'Смените его везде, где используете, начиная с почты и банка.',
			'checks.notFound' => 'Нет в известных утечках',
			'checks.notFoundAdvice' => 'Хороший знак, но не гарантия. Используйте разные пароли для каждого аккаунта.',
			'checks.failed' => 'Не удалось проверить. Попробуйте ещё раз.',
			'checks.private' => 'Ваш пароль не покидает этот телефон',
			'checks.linkTitle' => 'Безопасна ли ссылка?',
			'checks.linkHint' => 'Ссылка для проверки',
			'checks.paste' => 'Вставить',
			'checks.danger' => 'Опасная ссылка',
			'checks.dangerAdvice' => 'Не открывайте её и не вводите никаких данных.',
			'checks.clear' => 'Нет в известных списках вредоносных и фишинговых сайтов',
			'checks.clearAdvice' => 'Всё равно проверьте адрес, прежде чем входить.',
			'checks.goesTo' => 'Ведёт на',
			'checks.redirects' => 'Перенаправления',
			'checks.invalid' => 'Это не похоже на веб-адрес.',
			'checks.busy' => 'Слишком много проверок. Попробуйте позже.',
			'checks.unavailable' => 'Проверка ссылок сейчас недоступна.',
			'checks.listed' => 'Известен вредоносным ПО или фишингом',
			'checks.missing' => 'По этому адресу нет сайта',
			'checks.missingAdvice' => 'Проверьте написание: мошенники используют похожие адреса.',
			'checks.left' => ({required Object n, required Object total}) => 'Осталось ${n} из ${total} бесплатных проверок в этом месяце',
			'checks.usedUp' => 'Бесплатные проверки ссылок на этот месяц закончились',
			'checks.usedUpSub' => 'В Pro проверки без ограничений. Бесплатные вернутся 1-го числа.',
			'checks.getPro' => 'Получить Pro',
			'toolSettings.title' => 'Настройки инструментов',
			'toolSettings.askMobile' => 'Спрашивать перед тестом на мобильных данных',
			'toolSettings.askMobileSub' => 'На быстром соединении тест может потратить больше 100 МБ',
			'toolSettings.mobileTitle' => 'Использовать мобильные данные?',
			'toolSettings.mobileBody' => 'Тест скорости может потратить больше 100 МБ на быстром соединении.',
			'toolSettings.mobileGo' => 'Проверить',
			'toolSettings.safe' => 'Безопасна',
			'toolSettings.unsafe' => 'Небезопасна',
			'toolSettings.devices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} устройство', few: '${n} устройства', many: '${n} устройств', other: '${n} устройства', ), 
			'toolSettings.hideMac' => 'Скрывать аппаратные адреса',
			'toolSettings.hideMacSub' => 'Показывать только часть MAC-адреса с производителем',
			'toolSettings.names' => 'Показывать имена роутеров и серверов',
			'toolSettings.namesSub' => 'Ищет имена адресов в Traceroute',
			'toolSettings.remember' => 'Запоминать недавние адреса',
			'toolSettings.rememberSub' => 'Для Traceroute',
			'toolSettings.clear' => 'Очистить историю инструментов',
			'toolSettings.clearSub' => 'Забывает недавние адреса и устройства каждой сети',
			'toolSettings.clearGo' => 'Очистить',
			'security.tab' => 'Безопасность',
			'security.good' => 'Хорошо',
			'security.fair' => 'Средне',
			'security.atRisk' => 'Под угрозой',
			'security.allClear' => 'Исправлять нечего',
			'security.checked' => ({required Object time}) => 'Проверено в ${time}',
			'security.trend' => 'ЗА ДВЕ НЕДЕЛИ',
			'security.checking' => 'Проверяем эту сеть',
			'security.snoozed' => 'Отложенные',
			'security.remindLater' => 'Напомнить позже',
			'security.unsnooze' => 'Напомнить сейчас',
			'security.review' => 'Посмотреть',
			'security.confirmGo' => 'Подтвердить',
			'security.scanGo' => 'Сканировать',
			'security.look' => 'Открыть',
			'security.connectGo' => 'Подключить',
			'security.checkAgain' => 'Проверить снова',
			'security.wifiOpen' => 'Wi-Fi открыт',
			'security.wifiOpenDetail' => 'Любой рядом видит передаваемое',
			'security.wifiWep' => 'Wi-Fi использует WEP',
			'security.wifiWepDetail' => 'Старая защита, легко взломать',
			'security.wifiOwe' => 'Wi-Fi использует Enhanced Open',
			'security.wifiOweDetail' => 'Шифруется, но войти может любой',
			'security.wifiSecure' => 'Шифрование Wi-Fi',
			'security.wifiUnknown' => 'Защита Wi-Fi неизвестна',
			'security.wifiUnknownDetail' => 'Android не сообщил, как она защищена',
			'security.wps' => 'Включён WPS',
			'security.wpsDetail' => 'Отключите его в настройках роутера',
			'security.upnpOff' => 'Роутер держит порты закрытыми',
			'security.upnpOffDetail' => 'UPnP выключен',
			'security.upnpOn' => 'Роутер позволяет устройствам открывать порты',
			'security.upnpOnDetail' => 'UPnP включён',
			'security.portsOk' => 'Опасных портов на роутере нет',
			'security.portsRisky' => 'На роутере открыты опасные порты',
			'security.scanFirst' => 'Просканируйте, чтобы увидеть, кто здесь',
			'security.scanFirstDetail' => 'Неизвестные устройства снижают оценку',
			'security.notMineDetail' => 'Проверьте список устройств в роутере',
			'security.confirmDetail' => 'Отметьте свои',
			'security.devicesOk' => 'Все устройства известны',
			'security.devicesOkDetail' => 'Вы подтвердили каждое',
			'security.camera' => 'В этой сети есть камера',
			'security.dnsHijack' => 'Неизвестные имена перенаправляются',
			'security.dnsHijackDetail' => 'Провайдер или роутер подменяет ответы',
			'security.dnsOk' => 'DNS отвечает нормально',
			'security.dnsOkDetail' => 'Признаков подмены нет',
			'security.vpnOn' => 'VPN включён',
			'security.vpnOnDetail' => 'Трафик идёт через туннель',
			'security.vpnOff' => 'VPN выключен',
			'security.vpnOffDetail' => 'Провайдер видит каждый сайт',
			'security.toFix' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} проблема', other: '${n} проблемы', few: '${n} проблемы', many: '${n} проблем', ), 
			'security.upnpOpened' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: 'Устройства открыли ${n} порт', other: 'Устройства открыли ${n} порта', few: 'Устройства открыли ${n} порта', many: 'Устройства открыли ${n} портов', ), 
			'security.portsChecked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: 'Проверен ${n} порт', other: 'Проверено ${n} порта', few: 'Проверено ${n} порта', many: 'Проверено ${n} портов', ), 
			'security.notMine' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} устройство не ваше', other: '${n} устройства не ваши', few: '${n} устройства не ваши', many: '${n} устройств не ваши', ), 
			'security.confirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} устройство подтвердить', other: '${n} устройства подтвердить', few: '${n} устройства подтвердить', many: '${n} устройств подтвердить', ), 
			'providers.tab' => 'Интернет',
			'providers.unavailable' => 'Не удалось загрузить список провайдеров. Проверьте связь.',
			'providers.cached' => 'По последней проверке без VPN',
			'providers.notEnough' => 'Пока мало оценок',
			'providers.yourRating' => 'Ваша оценка в этом месяце',
			'providers.yourSpeed' => 'ВАША СКОРОСТЬ',
			'providers.runTest' => 'Проверить скорость',
			'providers.aboutAverage' => 'Около среднего здесь',
			'providers.aboveAverage' => ({required Object pct}) => 'На ${pct}% выше местного среднего',
			'providers.belowAverage' => ({required Object pct}) => 'На ${pct}% ниже местного среднего',
			'providers.call' => 'Позвонить',
			'providers.website' => 'Сайт',
			'providers.outages' => 'Сбои',
			'providers.rate' => 'Оценить',
			'providers.changeRating' => 'Изменить оценку',
			'providers.compare' => 'Сравнить',
			'providers.rateTitle' => ({required Object name}) => 'Оценить ${name}',
			'providers.oncePerMonth' => 'Одна оценка в месяц',
			'providers.tapStars' => 'Нажмите на звёзды',
			'providers.verified' => ({required Object mbps}) => 'Подтверждено вашим тестом: ${mbps} Мбит/с',
			'providers.busy' => 'Слишком много оценок отсюда. Попробуйте позже.',
			'providers.failed' => 'Не удалось отправить. Попробуйте ещё раз.',
			'providers.post' => 'Отправить оценку',
			'providers.nearTitle' => 'Провайдеры рядом',
			'providers.slower' => ({required Object pct}) => 'Ваша загрузка на ${pct}% ниже среднего у вашего провайдера здесь',
			'providers.inPlace' => ({required Object place}) => 'Домашний интернет: ${place}',
			'providers.byRating' => 'Оценка',
			'providers.bySpeed' => 'Скорость',
			'providers.footnote' => 'Скорости — средние по тестам G VPN',
			'providers.noneNearby' => 'Рядом пока нет оценок. Будьте первым.',
			'providers.you' => 'Вы',
			'providers.topRated' => 'Лучшие оценки',
			'providers.starsOf' => ({required Object n}) => '${n} из 5',
			'providers.tags.fast' => 'Быстрый',
			'providers.tags.reliable' => 'Надёжный',
			'providers.tags.support' => 'Хорошая поддержка',
			'providers.tags.price' => 'Честная цена',
			'providers.tags.slowEvenings' => 'Медленно вечером',
			'providers.tags.drops' => 'Часто обрывается',
			'providers.tags.poorSupport' => 'Плохая поддержка',
			'providers.tags.pricey' => 'Дорого',
			'providers.words.bad' => 'Плохо',
			'providers.words.poor' => 'Слабо',
			'providers.words.okay' => 'Нормально',
			'providers.words.good' => 'Хорошо',
			'providers.words.great' => 'Отлично',
			'providers.ratings' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} оценка', few: '${n} оценки', many: '${n} оценок', other: '${n} оценки', ), 
			'alerts.channel' => 'Оповещения',
			'alerts.title' => 'Оповещения',
			'alerts.markAllRead' => 'Прочитать все',
			'alerts.clearAll' => 'Очистить всё',
			'alerts.thisNetwork' => 'этой сети',
			'alerts.openWifiTitle' => ({required Object name}) => 'Вы подключились к открытому Wi-Fi: ${name}',
			'alerts.openWifiBody' => 'Любой рядом видит передаваемое. Включите G VPN.',
			'alerts.reportTitle' => 'Еженедельный отчёт готов',
			'alerts.reportBody' => ({required Object hours}) => '${hours} ч под защитой на прошлой неделе',
			'alerts.blockedTitle' => ({required Object name}) => '${name} здесь заблокирован',
			'alerts.blockedBody' => 'Работает через VPN',
			'alerts.kinds.newDevice' => 'Новые устройства в моём Wi-Fi',
			'alerts.kinds.openWifi' => 'Открытый или слабый Wi-Fi',
			'alerts.kinds.blocked' => 'Заблокированные приложения',
			'alerts.kinds.report' => 'Еженедельный отчёт',
			'alerts.kinds.breach' => 'Утечки',
			'alerts.newDeviceTitle' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} новое устройство в ${network}', few: '${n} новых устройства в ${network}', many: '${n} новых устройств в ${network}', other: '${n} новых устройства в ${network}', ), 
			'alerts.settings' => 'Настройки оповещений',
			'alerts.look' => 'Открыть',
			'alerts.read' => 'Читать',
			'alerts.open' => 'Открыть',
			'alerts.check' => 'Проверить',
			'alerts.today' => 'СЕГОДНЯ',
			'alerts.thisWeek' => 'НА ЭТОЙ НЕДЕЛЕ',
			'alerts.earlier' => 'РАНЕЕ',
			'alerts.all' => 'Все',
			'alerts.quiet' => 'Всё спокойно',
			'alerts.quietSub' => 'В последнее время ничего не требовало внимания',
			'alerts.breachTitle' => ({required Object name}) => 'Новая утечка: ${name}',
			'alerts.status.background' => 'Раз в несколько часов',
			'alerts.status.checked' => ({required Object time}) => 'Проверено в ${time}',
			'alerts.status.wifi' => 'Каждая сеть, к которой вы подключаетесь',
			'alerts.status.blocked' => 'Когда проверяется статус сервисов',
			'alerts.status.report' => 'Каждый понедельник',
			'report.title' => 'Еженедельный отчёт',
			'report.share' => 'Поделиться картинкой',
			'report.shareText' => 'Моя неделя с G VPN',
			'report.safer' => 'Неделя стала безопаснее',
			'report.moreProtected' => 'Больше защиты, чем на прошлой неделе',
			'report.yourWeek' => 'Ваша неделя',
			'report.soFar' => ({required Object range}) => '${range}, пока что',
			'report.protected' => 'Под защитой',
			'report.data' => 'Данные',
			'report.security' => 'Безопасность',
			'report.speed' => 'Лучшая скорость',
			'report.noScore' => 'Не проверено',
			'report.noTest' => 'Нет теста',
			'report.bestDirect' => 'Прямой тест',
			'report.moreThan' => ({required Object d}) => 'На ${d} больше, чем на прошлой неделе',
			'report.lessThan' => ({required Object d}) => 'На ${d} меньше, чем на прошлой неделе',
			'report.protectedTime' => 'ВРЕМЯ ПОД ЗАЩИТОЙ',
			'report.mostUsed' => ({required Object name}) => 'Чаще всего: ${name}',
			'report.quiet' => 'Спокойная неделя: ничего не требовало внимания',
			'report.newDevices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: 'Подключилось ${n} новое устройство', few: 'Подключилось ${n} новых устройства', many: 'Подключилось ${n} новых устройств', other: 'Подключилось ${n} новых устройства', ), 
			'report.openWifi' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} открытый Wi-Fi', few: '${n} открытых Wi-Fi', many: '${n} открытых Wi-Fi', other: '${n} открытых Wi-Fi', ), 
			'report.blocked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} приложение заблокировано', few: '${n} приложения заблокировано', many: '${n} приложений заблокировано', other: '${n} приложения заблокировано', ), 
			'report.breaches' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} крупная новая утечка', few: '${n} крупные новые утечки', many: '${n} крупных новых утечек', other: '${n} крупные новые утечки', ), 
			'breaches.title' => 'Утечки данных',
			'breaches.info' => 'Последние утечки данных из открытого списка Have I Been Pwned. О вас ничего не отправляется: список один для всех.\n\nЕсли у вас был аккаунт на взломанном сайте, смените этот пароль и везде, где использовали такой же.',
			'breaches.unavailable' => 'Не удалось загрузить список. Проверьте подключение.',
			'breaches.biggest' => 'КРУПНЕЙШАЯ ЗА МЕСЯЦ',
			'breaches.newest' => 'Новые',
			'breaches.biggestSort' => 'Крупные',
			'breaches.withPasswords' => 'С паролями',
			'breaches.passwordsMark' => 'ПАРОЛИ',
			'breaches.one' => 'Утечка',
			_ => null,
		} ?? switch (path) {
			'breaches.checkPassword' => 'Проверить пароль',
			'breaches.verified' => 'Подтверждена',
			'breaches.hasPasswords' => 'Есть пароли',
			'breaches.accountsLabel' => 'Аккаунты',
			'breaches.happened' => 'Произошла',
			'breaches.published' => 'Опубликована',
			'breaches.website' => 'Сайт',
			'breaches.leaked' => 'ЧТО УТЕКЛО',
			'breaches.ifUsed' => 'ЕСЛИ ВЫ ПОЛЬЗОВАЛИСЬ',
			'breaches.stepPassword' => 'Смените пароль, который использовали там',
			'breaches.stepReuse' => 'Смените его везде, где он был таким же',
			'breaches.stepTwoStep' => 'Включите двухэтапный вход, где можно',
			'breaches.stepScams' => 'Ожидайте мошеннических звонков и сообщений',
			'breaches.accounts' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${count} аккаунт', few: '${count} аккаунта', many: '${count} аккаунтов', other: '${count} аккаунта', ), 
			'breaches.worldwide' => ({required Object n}) => 'По всему миру · ${n}',
			'breaches.noneHere' => 'В недавнем списке нет утечек отсюда.',
			'breaches.bigMap' => 'Большая карта',
			'breaches.showInList' => 'Показать в списке',
			'breaches.mapTitle' => 'Карта утечек',
			'breaches.zoomIn' => 'Приблизить',
			'breaches.zoomOut' => 'Отдалить',
			'breaches.wholeWorld' => 'Весь мир',
			'breaches.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} утечка', few: '${n} утечки', many: '${n} утечек', other: '${n} утечки', ), 
			'breaches.findCountry' => 'Найти страну',
			'breaches.seeAll' => 'Смотреть все',
			'breaches.search' => 'Поиск утечек',
			'blocked.title' => 'Что заблокировано',
			'blocked.info' => 'Проверяет известные сайты с этого телефона без VPN и показывает, какие из них блокирует эта сеть и как.\n\nЛожный адрес: поиск имени в сети даёт ложный ответ.\n\nОбрыв: соединение рвётся в начале.\n\nНет ответа: ничего не возвращается.\n\nСтраница блокировки: вместо сайта отвечает что-то другое.\n\nПроверка показывает, где сайт заблокирован, но не кто его заблокировал. Ничего не сохраняется и не отправляется.',
			'blocked.thisNetwork' => 'Эта сеть',
			'blocked.country' => 'Ваша страна',
			'blocked.question' => 'Что здесь заблокировано?',
			'blocked.testingOn' => 'ПРОВЕРКА В СЕТИ',
			'blocked.vpnOn' => 'VPN ВКЛЮЧЁН',
			'blocked.turnOff' => 'Выключите G VPN для проверки',
			'blocked.test' => 'Проверить эту сеть',
			'blocked.stop' => 'Стоп',
			'blocked.sitesToTest' => ({required Object n}) => 'САЙТЫ ДЛЯ ПРОВЕРКИ · ${n}',
			'blocked.ofSites' => ({required Object n}) => 'из ${n} сайтов',
			'blocked.blockedCount' => ({required Object n}) => 'ЗАБЛОКИРОВАНО: ${n}',
			'blocked.openCount' => ({required Object n}) => 'ОТКРЫТО: ${n}',
			'blocked.noneBlocked' => ({required Object network}) => 'В сети ${network} ничего не заблокировано',
			'blocked.openOf' => ({required Object open, required Object total}) => 'Открыто ${open} из ${total}',
			'blocked.allWork' => 'ВСЁ РАБОТАЕТ ЧЕРЕЗ G VPN',
			'blocked.blockedHeading' => 'ЗАБЛОКИРОВАНО',
			'blocked.byKind' => 'ПО ТИПАМ',
			'blocked.worksVpn' => 'Работает через VPN',
			'blocked.failsVpn' => 'Заблокирован и через VPN',
			'blocked.checkVpn' => 'Проверить через G VPN',
			'blocked.connect' => 'Подключить G VPN',
			'blocked.again' => 'Проверить снова',
			'blocked.withoutVpn' => 'БЕЗ VPN',
			'blocked.throughVpn' => 'ЧЕРЕЗ G VPN',
			'blocked.notChecked' => 'Не проверено',
			'blocked.opens' => 'Открывается',
			'blocked.stillBlocked' => 'Заблокирован',
			'blocked.whatHappened' => 'ЧТО ПРОИЗОШЛО',
			'blocked.countryBlocked' => ({required Object country}) => 'сайтов заблокировано: ${country}',
			'blocked.countrySub' => 'По проверкам волонтёров за последние 30 дней',
			'blocked.countryNone' => 'За последние 30 дней заблокированных сайтов не найдено.',
			'blocked.countryUnavailable' => 'Не удалось загрузить данные по стране. Проверьте подключение.',
			'blocked.confirmed' => 'ЗАБЛОКИРОВАН',
			'blocked.oftenFails' => 'ЧАСТО НЕДОСТУПЕН',
			'blocked.kinds.social' => 'Соцсети',
			'blocked.kinds.messaging' => 'Мессенджеры',
			'blocked.kinds.news' => 'Новости',
			'blocked.kinds.video' => 'Видео и музыка',
			'blocked.kinds.privacy' => 'Приватность',
			'blocked.how.dns' => 'Ложный адрес',
			'blocked.how.reset' => 'Обрыв',
			'blocked.how.timeout' => 'Нет ответа',
			'blocked.how.page' => 'Страница блокировки',
			'blocked.how.open' => 'Открыт',
			'blocked.fail.noAnswer' => 'нет ответа',
			'blocked.fail.refused' => 'отказано',
			'blocked.fail.cutOff' => ({required Object s}) => 'обрыв через ${s} с',
			'blocked.fail.wrongCert' => 'неверный сертификат',
			'blocked.steps.lookup' => 'Поиск имени',
			'blocked.steps.connect' => 'Подключение',
			'blocked.steps.handshake' => 'Защищённое соединение',
			'blocked.consent.title' => 'Перед первой проверкой',
			'blocked.consent.body' => 'Проверка открывает каждый сайт с этого телефона без VPN, как это сделал бы браузер.',
			'blocked.consent.noticeTitle' => 'Это может быть заметно',
			'blocked.consent.notice' => 'Ваш провайдер видит, что эти сайты открываются. В некоторых странах их посещение, даже ради проверки, может привлечь внимание. Проверяйте только там, где чувствуете себя в безопасности.',
			'blocked.consent.ok' => 'Понятно, проверить',
			'blocked.someBlocked' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} сайт заблокирован в сети ${network}', few: '${n} сайта заблокировано в сети ${network}', many: '${n} сайтов заблокировано в сети ${network}', other: '${n} сайта заблокировано в сети ${network}', ), 
			'blocked.tests' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ru'))(n, one: '${n} проверка', few: '${n} проверки', many: '${n} проверок', other: '${n} проверки', ), 
			_ => null,
		};
	}
}
