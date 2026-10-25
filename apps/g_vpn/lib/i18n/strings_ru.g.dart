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
	@override String sitesSee({required Object ip}) => 'Сайты видят ${ip}';
	@override String sitesSeeOrg({required Object ip, required Object org}) => 'Сайты видят ${ip} · ${org}';
	@override String get ipFailed => 'Не удалось проверить IP';
	@override String get ipChecking => 'Проверка IP';
	@override String get themeSystem => 'Тема: как в телефоне';
	@override String get themeLight => 'Тема: светлая';
	@override String get themeDark => 'Тема: тёмная';
	@override String get free => 'Бесплатно';
	@override String get pickServer => 'Выберите сервер';
	@override late final _Translations$home$waves$ru waves = _Translations$home$waves$ru._(_root);
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
}

// Path: pro
class _Translations$pro$ru extends Translations$pro$en {
	_Translations$pro$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get owned => 'У вас есть Pro';
	@override String get waitingPlay => 'Ожидание Google Play';
	@override String startTrial({required Object days}) => 'Начать бесплатный период на ${days} дн.';
	@override String thenYearly({required Object price}) => 'Затем ${price} в год. Отмена в любой момент в Google Play.';
	@override String thenMonthly({required Object price}) => 'Затем ${price} в месяц. Отмена в любой момент в Google Play.';
	@override String yearlyPrice({required Object price}) => '${price} в год. Отмена в любой момент в Google Play.';
	@override String monthlyPrice({required Object price}) => '${price} в месяц. Отмена в любой момент в Google Play.';
	@override String get restore => 'Восстановить';
	@override String get heroTitle => 'Быстрые серверы,\nнаши собственные';
	@override String get heroSubtitle => 'WireGuard. Без журналов активности. Без аккаунта.';
	@override String get benefitSpeed => 'Полная скорость, без ограничений волонтёрских серверов';
	@override String get benefitKey => 'Ключ создаётся на вашем телефоне и никому не передаётся';
	@override String get benefitFree => 'Всё бесплатное останется бесплатным';
	@override String save({required Object pct}) => 'ЭКОНОМИЯ ${pct}%';
	@override String get yearly => 'На год';
	@override String get monthly => 'На месяц';
	@override String get billedMonthly => 'оплата ежемесячно';
	@override String daysFree({required Object days}) => '${days} дн. бесплатно';
	@override String perMonth({required Object price}) => '${price} в месяц';
	@override String get title => 'G VPN Pro';
	@override String get heroTitleOneLine => 'Быстрые серверы, наши собственные';
	@override String get includes => 'Что входит';
	@override String get benefitLogs => 'Без журналов активности на наших серверах';
	@override String get plan => 'Выберите план';
	@override String get renewGeneric => 'Подписки продлеваются автоматически до отмены. Отмена в любой момент в Google Play.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} дн. бесплатно, затем ${price} за ${period}. Продлевается автоматически до отмены; отмените в Google Play не позднее чем за день до конца пробного периода, чтобы не было списания.';
	@override String renew({required Object price, required Object period}) => '${price} за ${period}. Продлевается автоматически до отмены; отмена в любой момент в Google Play.';
	@override String get year => 'год';
	@override String get month => 'месяц';
	@override String get manage => 'Управление подпиской';
	@override late final _Translations$pro$free$ru free = _Translations$pro$free$ru._(_root);
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
	@override String get shieldSub => 'Блокирует вредоносные и фишинговые сайты';
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
	@override String get wake => 'Включить устройство';
	@override String get mac => 'MAC-адрес';
	@override String failed({required Object error}) => 'Не удалось отправить: ${error}';
}

// Path: speed
class _Translations$speed$ru extends Translations$speed$en {
	_Translations$speed$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get info => 'Измеряется открытой исследовательской платформой M-Lab. Тест расходует около 50–100 МБ.\n\nПубличные результаты: M-Lab публикует каждый тест, включая IP-адрес, с которого он проведён, как открытые исследовательские данные.\n\nСравнение провайдеров: после теста без VPN G VPN отправляет только три показателя скорости. Сервис сравнения определяет вашего провайдера и город по самому подключению и не хранит IP-адрес. Отключить можно переключателем внизу страницы.\n\nЧерез VPN: при включённом VPN измеряется скорость через туннель и сравнивается с последним тестом без него.\n\nПредпросмотр видео: та же картинка в разрешении, которое позволяет эта скорость, по битрейтам, которые публикуют стриминговые сервисы. Видео не загружается.';
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
	@override String routerName({required Object name}) => 'Роутер: ${name}';
	@override String externalIp({required Object ip}) => 'Интернет-адрес: ${ip}';
	@override String mapping({required Object proto, required Object host}) => '${proto} на ${host}';
	@override String get upnpOn => 'UPnP включён';
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
	@override String get nothingNew => 'С прошлого сканирования ничего нового';
	@override String get takes => 'Займёт около 30 секунд';
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
	@override String get notAnnounced => 'Не представилось. Имя можно найти в списке устройств роутера.';
	@override String get newBadge => 'НОВОЕ';
	@override String scanning({required Object n}) => 'Сканирование ${n} из 254';
	@override String get thisNetwork => 'этой сети';
	@override String newSince({required Object n}) => 'Новых с прошлого сканирования: ${n}';
	@override String showMore({required Object n}) => 'Показать ещё ${n}';
	@override String ms({required Object n}) => '${n} мс';
	@override String onNetwork({required Object network}) => 'устройств в ${network}';
}

// Path: ping
class _Translations$ping$ru extends Translations$ping$en {
	_Translations$ping$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get info => 'Сколько длится один путь до сервера и обратно; измеряется раз в секунду за последнюю минуту.\n\nДжиттер: насколько каждый ответ отличается от предыдущего. Высокий джиттер прерывает звонки.\n\nПотери: ответы, которые так и не вернулись.\n\nКак: приложения Android не могут отправлять классический пинг, поэтому каждая проба измеряет установку соединения, а это тот же один путь туда и обратно.';
	@override String get askTitle => 'Пинг узла';
	@override String get askHint => 'example.com или 192.168.1.10';
	@override String get cancel => 'Отмена';
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
	@override String get unreachable => 'Недоступен';
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
	@override String get internet => 'Интернет-подключение';
	@override String get speed => 'Тест скорости';
	@override String get speedDesc => 'Скорость загрузки и отдачи и какое качество видео она тянет.';
	@override String get ping => 'Пинг';
	@override String get pingDesc => 'Время отклика и джиттер до любого сервера или вашего роутера в реальном времени.';
	@override String get status => 'Статус сервисов';
	@override String get statusDesc => 'Доступны ли отсюда WhatsApp, YouTube или Google, или они заблокированы?';
	@override String get trace => 'Трассировка';
	@override String get traceDesc => 'Все роутеры между вами и сайтом и сколько времени занимает каждый.';
	@override String get security => 'Безопасность сети';
	@override String get devices => 'Устройства в этой сети';
	@override String get devicesDesc => 'Кто ещё в вашем Wi-Fi: телефоны, телевизоры, камеры и компьютеры.';
	@override String get router => 'Проверка роутера';
	@override String get routerDesc => 'Могут ли устройства сами открывать порты на роутере (UPnP).';
	@override String get ports => 'Открытые порты';
	@override String get portsDesc => 'Проверьте роутер или сервер на опасные открытые порты.';
	@override String get utilities => 'Утилиты';
	@override String get wifiScanner => 'Сканер Wi-Fi';
	@override String get wifiDesc => 'Ближайшие сети, их защита и наименее загруженный канал.';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'Включите компьютер или NAS в этой сети.';
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
	@override String bestChannel({required Object n}) => 'Наименее загруженный канал 2,4 ГГц: ${n}';
	@override String weak({required Object n}) => 'Открытых или слабо защищённых: ${n}';
	@override String get connectedPrefix => 'Подключено · ';
	@override String get permissionInfo => 'Android показывает ближайшие сети Wi-Fi только приложениям с доступом к геолокации. G VPN использует его лишь для списка сетей на этом телефоне.';
	@override String get info => 'Показывает сети из последнего сканирования телефона. Android разрешает лишь несколько сканирований в минуту, поэтому быстрое повторное может показать тот же список. Рекомендуемый канал: наименее загруженный из 1, 6 и 11, трёх неперекрывающихся.';
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
	@override String devicesSub({required Object n}) => 'До ${n} телефонов, у каждого свой ключ';
	@override String get footnote => 'Каждый телефон получает свой ключ, созданный на нём. G Servers не хранят журналы активности.';
	@override String get leastBusy => 'НАИМЕНЕЕ ЗАГРУЖЕН СЕЙЧАС';
	@override String busyNoLogs({required Object n}) => 'Загрузка ${n}% · без журналов';
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

// Path: home.waves
class _Translations$home$waves$ru extends Translations$home$waves$en {
	_Translations$home$waves$ru._(TranslationsRu root) : this._root = root, super.internal(root);

	final TranslationsRu _root; // ignore: unused_field

	// Translations
	@override String get encrypted => 'ЗАШИФРОВАНО';
	@override String get securing => 'ЗАЩИТА';
	@override String get exposed => 'ОТКРЫТО';
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
	@override String get connectedVia => 'ПОДКЛЮЧЕНО ЧЕРЕЗ';
	@override String get protocol => 'ПРОТОКОЛ';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, в туннеле';
	@override String get dnsServer => 'Сервер, в туннеле';
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
	@override String get shieldOn => 'Блокирует вредоносные сайты';
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
	@override String get shield => 'Щит отправляет DNS-запросы в Quad9, который отклоняет известные вредоносные и фишинговые сайты. Он не блокирует рекламу и, пока включён, заменяет DNS сервера.';
	@override String get autoConnect => 'Автоподключение: использует выбранный вами сервер WireGuard. Ручное отключение приостанавливает его до подключения к другой сети.';
	@override String get apps => 'Приложения напрямую: приложения вне VPN подключаются напрямую. Банки часто блокируют адреса VPN, поэтому платежи через VPN могут не проходить.';
	@override String get reconnect => 'Изменение щита или списка приложений ненадолго переподключает VPN.';
	@override String get stay => 'Оставаться на связи: некоторые телефоны останавливают фоновые приложения для экономии батареи. Постоянный VPN и неограниченный режим батареи сохраняют работу G VPN.';
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
			'home.sitesSee' => ({required Object ip}) => 'Сайты видят ${ip}',
			'home.sitesSeeOrg' => ({required Object ip, required Object org}) => 'Сайты видят ${ip} · ${org}',
			'home.ipFailed' => 'Не удалось проверить IP',
			'home.ipChecking' => 'Проверка IP',
			'home.themeSystem' => 'Тема: как в телефоне',
			'home.themeLight' => 'Тема: светлая',
			'home.themeDark' => 'Тема: тёмная',
			'home.free' => 'Бесплатно',
			'home.pickServer' => 'Выберите сервер',
			'home.waves.encrypted' => 'ЗАШИФРОВАНО',
			'home.waves.securing' => 'ЗАЩИТА',
			'home.waves.exposed' => 'ОТКРЫТО',
			'home.network.title' => 'ЭТА СЕТЬ',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Нет сети',
			'home.network.showName' => 'Показать имя',
			'home.network.scanFailed' => 'Проверка не удалась. Она повторится при смене сети.',
			'home.card.connectedVia' => 'ПОДКЛЮЧЕНО ЧЕРЕЗ',
			'home.card.protocol' => 'ПРОТОКОЛ',
			'home.card.dns' => 'DNS',
			'home.card.dnsQuad9' => 'Quad9, в туннеле',
			'home.card.dnsServer' => 'Сервер, в туннеле',
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
			'home.tiles.shieldOn' => 'Блокирует вредоносные сайты',
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
			'pro.owned' => 'У вас есть Pro',
			'pro.waitingPlay' => 'Ожидание Google Play',
			'pro.startTrial' => ({required Object days}) => 'Начать бесплатный период на ${days} дн.',
			'pro.thenYearly' => ({required Object price}) => 'Затем ${price} в год. Отмена в любой момент в Google Play.',
			'pro.thenMonthly' => ({required Object price}) => 'Затем ${price} в месяц. Отмена в любой момент в Google Play.',
			'pro.yearlyPrice' => ({required Object price}) => '${price} в год. Отмена в любой момент в Google Play.',
			'pro.monthlyPrice' => ({required Object price}) => '${price} в месяц. Отмена в любой момент в Google Play.',
			'pro.restore' => 'Восстановить',
			'pro.heroTitle' => 'Быстрые серверы,\nнаши собственные',
			'pro.heroSubtitle' => 'WireGuard. Без журналов активности. Без аккаунта.',
			'pro.benefitSpeed' => 'Полная скорость, без ограничений волонтёрских серверов',
			'pro.benefitKey' => 'Ключ создаётся на вашем телефоне и никому не передаётся',
			'pro.benefitFree' => 'Всё бесплатное останется бесплатным',
			'pro.save' => ({required Object pct}) => 'ЭКОНОМИЯ ${pct}%',
			'pro.yearly' => 'На год',
			'pro.monthly' => 'На месяц',
			'pro.billedMonthly' => 'оплата ежемесячно',
			'pro.daysFree' => ({required Object days}) => '${days} дн. бесплатно',
			'pro.perMonth' => ({required Object price}) => '${price} в месяц',
			'pro.title' => 'G VPN Pro',
			'pro.heroTitleOneLine' => 'Быстрые серверы, наши собственные',
			'pro.includes' => 'Что входит',
			'pro.benefitLogs' => 'Без журналов активности на наших серверах',
			'pro.plan' => 'Выберите план',
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
			'rules.title' => 'Правила',
			'rules.info.shield' => 'Щит отправляет DNS-запросы в Quad9, который отклоняет известные вредоносные и фишинговые сайты. Он не блокирует рекламу и, пока включён, заменяет DNS сервера.',
			'rules.info.autoConnect' => 'Автоподключение: использует выбранный вами сервер WireGuard. Ручное отключение приостанавливает его до подключения к другой сети.',
			'rules.info.apps' => 'Приложения напрямую: приложения вне VPN подключаются напрямую. Банки часто блокируют адреса VPN, поэтому платежи через VPN могут не проходить.',
			'rules.info.reconnect' => 'Изменение щита или списка приложений ненадолго переподключает VPN.',
			'rules.info.stay' => 'Оставаться на связи: некоторые телефоны останавливают фоновые приложения для экономии батареи. Постоянный VPN и неограниченный режим батареи сохраняют работу G VPN.',
			'rules.protection' => 'Защита',
			'rules.shield' => 'Щит',
			'rules.shieldSub' => 'Блокирует вредоносные и фишинговые сайты',
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
			'wol.wake' => 'Включить устройство',
			'wol.mac' => 'MAC-адрес',
			'wol.failed' => ({required Object error}) => 'Не удалось отправить: ${error}',
			'speed.info' => 'Измеряется открытой исследовательской платформой M-Lab. Тест расходует около 50–100 МБ.\n\nПубличные результаты: M-Lab публикует каждый тест, включая IP-адрес, с которого он проведён, как открытые исследовательские данные.\n\nСравнение провайдеров: после теста без VPN G VPN отправляет только три показателя скорости. Сервис сравнения определяет вашего провайдера и город по самому подключению и не хранит IP-адрес. Отключить можно переключателем внизу страницы.\n\nЧерез VPN: при включённом VPN измеряется скорость через туннель и сравнивается с последним тестом без него.\n\nПредпросмотр видео: та же картинка в разрешении, которое позволяет эта скорость, по битрейтам, которые публикуют стриминговые сервисы. Видео не загружается.',
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
			'router.routerName' => ({required Object name}) => 'Роутер: ${name}',
			'router.externalIp' => ({required Object ip}) => 'Интернет-адрес: ${ip}',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} на ${host}',
			'router.upnpOn' => 'UPnP включён',
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
			'devices.nothingNew' => 'С прошлого сканирования ничего нового',
			'devices.takes' => 'Займёт около 30 секунд',
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
			'devices.notAnnounced' => 'Не представилось. Имя можно найти в списке устройств роутера.',
			'devices.newBadge' => 'НОВОЕ',
			'devices.scanning' => ({required Object n}) => 'Сканирование ${n} из 254',
			'devices.thisNetwork' => 'этой сети',
			'devices.newSince' => ({required Object n}) => 'Новых с прошлого сканирования: ${n}',
			'devices.showMore' => ({required Object n}) => 'Показать ещё ${n}',
			'devices.ms' => ({required Object n}) => '${n} мс',
			'devices.onNetwork' => ({required Object network}) => 'устройств в ${network}',
			'ping.info' => 'Сколько длится один путь до сервера и обратно; измеряется раз в секунду за последнюю минуту.\n\nДжиттер: насколько каждый ответ отличается от предыдущего. Высокий джиттер прерывает звонки.\n\nПотери: ответы, которые так и не вернулись.\n\nКак: приложения Android не могут отправлять классический пинг, поэтому каждая проба измеряет установку соединения, а это тот же один путь туда и обратно.',
			'ping.askTitle' => 'Пинг узла',
			'ping.askHint' => 'example.com или 192.168.1.10',
			'ping.cancel' => 'Отмена',
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
			'status.unreachable' => 'Недоступен',
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
			'tools.internet' => 'Интернет-подключение',
			'tools.speed' => 'Тест скорости',
			'tools.speedDesc' => 'Скорость загрузки и отдачи и какое качество видео она тянет.',
			'tools.ping' => 'Пинг',
			'tools.pingDesc' => 'Время отклика и джиттер до любого сервера или вашего роутера в реальном времени.',
			'tools.status' => 'Статус сервисов',
			'tools.statusDesc' => 'Доступны ли отсюда WhatsApp, YouTube или Google, или они заблокированы?',
			'tools.trace' => 'Трассировка',
			'tools.traceDesc' => 'Все роутеры между вами и сайтом и сколько времени занимает каждый.',
			'tools.security' => 'Безопасность сети',
			'tools.devices' => 'Устройства в этой сети',
			'tools.devicesDesc' => 'Кто ещё в вашем Wi-Fi: телефоны, телевизоры, камеры и компьютеры.',
			'tools.router' => 'Проверка роутера',
			'tools.routerDesc' => 'Могут ли устройства сами открывать порты на роутере (UPnP).',
			'tools.ports' => 'Открытые порты',
			'tools.portsDesc' => 'Проверьте роутер или сервер на опасные открытые порты.',
			'tools.utilities' => 'Утилиты',
			'tools.wifiScanner' => 'Сканер Wi-Fi',
			'tools.wifiDesc' => 'Ближайшие сети, их защита и наименее загруженный канал.',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Включите компьютер или NAS в этой сети.',
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
			_ => null,
		} ?? switch (path) {
			'ports.normal' => 'НОРМА',
			'ports.info' => ({required Object n}) => 'Проверяет ${n} портов, важных для домашних роутеров и устройств, и объясняет каждый открытый.\n\nПроверяйте только устройства и серверы, которыми вы владеете или управляете.',
			'ports.checking' => ({required Object n}) => 'Проверка портов: ${n}',
			'ports.yourRouter' => ({required Object ip}) => 'Ваш роутер: ${ip}',
			'ports.noneOpen' => ({required Object host}) => 'На ${host} нет открытых распространённых портов.',
			'wifi.title' => 'Сканер Wi-Fi',
			'wifi.allow' => 'Разрешить сканирование Wi-Fi',
			'wifi.needsPermission' => 'Нужен доступ к геолокации.',
			'wifi.scanning' => 'Сканирование',
			'wifi.again' => 'Сканировать снова',
			'wifi.failed' => 'Сканирование не удалось',
			'wifi.none' => 'Сети не найдены. Возможно, геолокация выключена.',
			'wifi.hidden' => 'Скрытая сеть',
			'wifi.nearby' => ({required Object n}) => 'Сетей поблизости: ${n}',
			'wifi.bestChannel' => ({required Object n}) => 'Наименее загруженный канал 2,4 ГГц: ${n}',
			'wifi.weak' => ({required Object n}) => 'Открытых или слабо защищённых: ${n}',
			'wifi.connectedPrefix' => 'Подключено · ',
			'wifi.permissionInfo' => 'Android показывает ближайшие сети Wi-Fi только приложениям с доступом к геолокации. G VPN использует его лишь для списка сетей на этом телефоне.',
			'wifi.info' => 'Показывает сети из последнего сканирования телефона. Android разрешает лишь несколько сканирований в минуту, поэтому быстрое повторное может показать тот же список. Рекомендуемый канал: наименее загруженный из 1, 6 и 11, трёх неперекрывающихся.',
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
			'gs.devicesSub' => ({required Object n}) => 'До ${n} телефонов, у каждого свой ключ',
			'gs.footnote' => 'Каждый телефон получает свой ключ, созданный на нём. G Servers не хранят журналы активности.',
			'gs.leastBusy' => 'НАИМЕНЕЕ ЗАГРУЖЕН СЕЙЧАС',
			'gs.busyNoLogs' => ({required Object n}) => 'Загрузка ${n}% · без журналов',
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
			_ => null,
		};
	}
}
