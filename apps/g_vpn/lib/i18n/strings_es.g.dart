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
class TranslationsEs extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.es,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <es>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsEs _root = this; // ignore: unused_field

	@override 
	TranslationsEs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEs(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$es common = _Translations$common$es._(_root);
	@override late final _Translations$nav$es nav = _Translations$nav$es._(_root);
	@override late final _Translations$home$es home = _Translations$home$es._(_root);
	@override late final _Translations$servers$es servers = _Translations$servers$es._(_root);
	@override late final _Translations$pro$es pro = _Translations$pro$es._(_root);
	@override late final _Translations$rules$es rules = _Translations$rules$es._(_root);
	@override late final _Translations$apps$es apps = _Translations$apps$es._(_root);
	@override late final _Translations$location$es location = _Translations$location$es._(_root);
	@override late final _Translations$addServer$es addServer = _Translations$addServer$es._(_root);
	@override late final _Translations$button$es button = _Translations$button$es._(_root);
	@override late final _Translations$wol$es wol = _Translations$wol$es._(_root);
	@override late final _Translations$speed$es speed = _Translations$speed$es._(_root);
	@override late final _Translations$router$es router = _Translations$router$es._(_root);
	@override late final _Translations$network$es network = _Translations$network$es._(_root);
	@override late final _Translations$devices$es devices = _Translations$devices$es._(_root);
	@override late final _Translations$ping$es ping = _Translations$ping$es._(_root);
	@override late final _Translations$status$es status = _Translations$status$es._(_root);
	@override late final _Translations$tools$es tools = _Translations$tools$es._(_root);
	@override late final _Translations$trace$es trace = _Translations$trace$es._(_root);
	@override late final _Translations$ports$es ports = _Translations$ports$es._(_root);
	@override late final _Translations$wifi$es wifi = _Translations$wifi$es._(_root);
	@override late final _Translations$errors$es errors = _Translations$errors$es._(_root);
	@override late final _Translations$scan$es scan = _Translations$scan$es._(_root);
	@override late final _Translations$legal$es legal = _Translations$legal$es._(_root);
	@override late final _Translations$update$es update = _Translations$update$es._(_root);
	@override late final _Translations$details$es details = _Translations$details$es._(_root);
	@override late final _Translations$share$es share = _Translations$share$es._(_root);
	@override late final _Translations$add$es add = _Translations$add$es._(_root);
	@override late final _Translations$backup$es backup = _Translations$backup$es._(_root);
	@override late final _Translations$gs$es gs = _Translations$gs$es._(_root);
}

// Path: common
class _Translations$common$es extends Translations$common$en {
	_Translations$common$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get gotIt => 'Entendido';
	@override String get about => 'Acerca de';
	@override String get connect => 'Conectar';
	@override String get connected => 'Conectado';
	@override String get retry => 'Reintentar';
	@override String get ok => 'Aceptar';
	@override String get remove => 'Quitar';
	@override String get cancel => 'Cancelar';
	@override String get continueLabel => 'Continuar';
	@override String get notNow => 'Ahora no';
	@override String get openSettings => 'Abrir ajustes';
	@override String get close => 'Cerrar';
	@override String get off => 'Desactivado';
	@override String get changesReconnect => 'Los cambios reconectan la VPN';
}

// Path: nav
class _Translations$nav$es extends Translations$nav$en {
	_Translations$nav$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get vpn => 'VPN';
	@override String get servers => 'Servidores';
	@override String get tools => 'Herramientas';
	@override String get rules => 'Reglas';
	@override String get pro => 'Pro';
}

// Path: home
class _Translations$home$es extends Translations$home$en {
	_Translations$home$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$status$es status = _Translations$home$status$es._(_root);
	@override String resumesAt({required Object time}) => 'Se reanuda a las ${time} · toca para reanudar ahora';
	@override String sitesSee({required Object ip}) => 'Los sitios ven ${ip}';
	@override String sitesSeeOrg({required Object ip, required Object org}) => 'Los sitios ven ${ip} · ${org}';
	@override String get ipFailed => 'No se pudo comprobar tu IP';
	@override String get ipChecking => 'Comprobando tu IP';
	@override String get themeSystem => 'Tema: según el teléfono';
	@override String get themeLight => 'Tema: claro';
	@override String get themeDark => 'Tema: oscuro';
	@override String get free => 'Gratis';
	@override String get pickServer => 'Elige un servidor';
	@override late final _Translations$home$waves$es waves = _Translations$home$waves$es._(_root);
	@override late final _Translations$home$network$es network = _Translations$home$network$es._(_root);
	@override late final _Translations$home$card$es card = _Translations$home$card$es._(_root);
	@override late final _Translations$home$tiles$es tiles = _Translations$home$tiles$es._(_root);
	@override late final _Translations$home$fastest$es fastest = _Translations$home$fastest$es._(_root);
	@override late final _Translations$home$ip$es ip = _Translations$home$ip$es._(_root);
}

// Path: servers
class _Translations$servers$es extends Translations$servers$en {
	_Translations$servers$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Servidores';
	@override String get aboutServers => 'Acerca de los servidores';
	@override late final _Translations$servers$tabs$es tabs = _Translations$servers$tabs$es._(_root);
	@override late final _Translations$servers$sheet$es sheet = _Translations$servers$sheet$es._(_root);
	@override late final _Translations$servers$badges$es badges = _Translations$servers$badges$es._(_root);
	@override late final _Translations$servers$filters$es filters = _Translations$servers$filters$es._(_root);
	@override String get loadFailed => 'No se pudo cargar la lista';
	@override String get noServers => 'No hay servidores ahora';
	@override String get best => 'EL MEJOR PARA TI AHORA';
	@override String get topRanked => 'El mejor valorado ahora';
	@override String get addHeading => 'AÑADIR UN SERVIDOR';
	@override String get scanQr => 'Escanear QR';
	@override String get importFile => 'Importar archivo';
	@override String get paste => 'Pegar';
	@override late final _Translations$servers$own$es own = _Translations$servers$own$es._(_root);
	@override String get configBroken => 'La configuración necesita revisión';
	@override String get connectedBadge => 'CONECTADO';
	@override String get scannedServer => 'Servidor escaneado';
	@override String get scanFailedTitle => 'No se pudo escanear';
	@override String get scanFailedBody => 'El escáner no está disponible en este teléfono.';
	@override String get importFailedTitle => 'No se pudo importar';
	@override String get importFailedBody => 'No se pudo leer ese archivo.';
	@override String get renameTitle => 'Cambiar nombre del servidor';
	@override String get nameHint => 'Nombre, por ejemplo Router de casa';
	@override String get save => 'Guardar';
	@override String get rename => 'Cambiar nombre';
	@override String get disconnect => 'Desconectar';
	@override String get more => 'Más opciones';
	@override String get justNow => 'ahora mismo';
	@override String minutesAgo({required Object n}) => 'hace ${n} min';
	@override String hoursAgo({required Object n}) => 'hace ${n} h';
	@override String daysAgo({required Object n}) => 'hace ${n} d';
	@override String get neverUsed => 'Aún sin usar';
	@override String lastUsed({required Object when}) => 'Último uso ${when}';
	@override String get disconnectFirst => 'Desconéctate primero para quitarlo';
	@override String get removeConfirm => '¿Quitar este servidor de G VPN? Sus ajustes se borran de este teléfono; el servidor no cambia.';
}

// Path: pro
class _Translations$pro$es extends Translations$pro$en {
	_Translations$pro$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get owned => 'Tienes Pro';
	@override String get waitingPlay => 'Esperando a Google Play';
	@override String startTrial({required Object days}) => 'Empezar prueba gratis de ${days} días';
	@override String thenYearly({required Object price}) => 'Después ${price} al año. Cancela cuando quieras en Google Play.';
	@override String thenMonthly({required Object price}) => 'Después ${price} al mes. Cancela cuando quieras en Google Play.';
	@override String yearlyPrice({required Object price}) => '${price} al año. Cancela cuando quieras en Google Play.';
	@override String monthlyPrice({required Object price}) => '${price} al mes. Cancela cuando quieras en Google Play.';
	@override String get restore => 'Restaurar';
	@override String get heroTitle => 'Servidores más rápidos,\ngestionados por nosotros';
	@override String get heroSubtitle => 'WireGuard. Sin registros de actividad. Sin cuenta.';
	@override String get benefitSpeed => 'Velocidad completa, sin los límites de los voluntarios';
	@override String get benefitKey => 'La clave se crea en tu teléfono y nunca se comparte';
	@override String get benefitFree => 'Todo lo gratuito sigue siendo gratis';
	@override String save({required Object pct}) => 'AHORRA ${pct}%';
	@override String get yearly => 'Anual';
	@override String get monthly => 'Mensual';
	@override String get billedMonthly => 'facturado cada mes';
	@override String daysFree({required Object days}) => '${days} días gratis';
	@override String perMonth({required Object price}) => '${price} al mes';
	@override String get title => 'G VPN Pro';
	@override String get heroTitleOneLine => 'Servidores más rápidos, gestionados por nosotros';
	@override String get includes => 'Incluye';
	@override String get benefitLogs => 'Sin registros de actividad en nuestros servidores';
	@override String get plan => 'Elige un plan';
	@override String get renewGeneric => 'Las suscripciones se renuevan automáticamente hasta que las canceles. Cancela cuando quieras en Google Play.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} días gratis, después ${price} por ${period}. Se renueva automáticamente hasta que canceles; cancela en Google Play al menos un día antes de que termine la prueba para que no te cobren.';
	@override String renew({required Object price, required Object period}) => '${price} por ${period}. Se renueva automáticamente hasta que canceles; cancela cuando quieras en Google Play.';
	@override String get year => 'año';
	@override String get month => 'mes';
	@override String get manage => 'Gestionar suscripción';
	@override late final _Translations$pro$free$es free = _Translations$pro$free$es._(_root);
}

// Path: rules
class _Translations$rules$es extends Translations$rules$en {
	_Translations$rules$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Reglas';
	@override late final _Translations$rules$info$es info = _Translations$rules$info$es._(_root);
	@override String get protection => 'Protección';
	@override String get shield => 'Escudo';
	@override String get shieldSub => 'Bloquea sitios de malware y phishing';
	@override String get privateDns => 'Escudo sin la VPN';
	@override String get privateDnsSub => 'Copia dns.quad9.net para el DNS privado';
	@override String get privateDnsCopied => 'dns.quad9.net copiado';
	@override String get privateDnsHow => 'Abre Ajustes, busca DNS privado, elige "Nombre de host del proveedor de DNS privado" y pégalo.';
	@override String get stay => 'Seguir conectado';
	@override String get alwaysOn => 'VPN siempre activa';
	@override String get alwaysOnSub => 'Android reinicia G VPN si se detiene';
	@override String get battery => 'Batería';
	@override String get batteryOk => 'Sin restricciones';
	@override String get batteryRestricted => 'Restringida: puede detenerse en segundo plano';
	@override String get autoConnect => 'Conexión automática';
	@override String get autoOff => 'Desactivada';
	@override String get autoOffSub => 'Solo cuando tocas';
	@override String get autoOpen => 'Wi-Fi públicas';
	@override String get autoOpenSub => 'Redes abiertas, WEP o con página de acceso';
	@override String get autoAny => 'Cualquier Wi-Fi';
	@override String get autoAnySub => 'Cualquier red Wi-Fi';
	@override String get apps => 'Apps';
	@override String get appsDirect => 'Apps directas';
	@override String get appsNone => 'Todas las apps usan la VPN';
	@override String appsSome({required Object n}) => '${n} apps sin VPN';
	@override String get appearance => 'Apariencia';
	@override String get themePhone => 'Teléfono';
	@override String get themeLight => 'Claro';
	@override String get themeDark => 'Oscuro';
	@override String get about => 'Acerca de';
}

// Path: apps
class _Translations$apps$es extends Translations$apps$en {
	_Translations$apps$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Apps directas';
	@override String get sheetSubtitle => 'Las apps elegidas se conectan sin la VPN. Todo lo demás sigue protegido.';
	@override String get whyTitle => 'Por qué excluir una app';
	@override String get whyBody => 'Los bancos y las apps de pago suelen bloquear direcciones de VPN, así que los pagos pueden fallar a través de una VPN. Algunos servicios locales solo funcionan desde tu país.';
	@override String get favouritesBody => 'Marca con estrella las apps que cambias a menudo; se quedan arriba.';
	@override String get whileConnected => 'Mientras está conectada';
	@override String get whileConnectedBody => 'Cambiar esta lista reconecta la VPN un momento.';
	@override String search({required Object n}) => 'Buscar entre ${n} apps';
	@override String get skipping => 'Sin VPN';
	@override String get skippingNone => 'Ninguna. Todas las apps pasan por la VPN.';
	@override String protectAgain({required Object app}) => 'Volver a proteger ${app}';
	@override String get banking => 'Bancos y pagos';
	@override String bankingFound({required Object n}) => '${n} encontradas que pueden bloquear VPN';
	@override String get addAll => 'Añadir todas';
	@override String get favourites => 'Favoritas';
	@override String get all => 'Todas las apps';
	@override String found({required Object n}) => '${n} encontradas';
	@override String get noMatch => 'Ninguna app coincide.';
	@override String showAll({required Object n}) => 'Mostrar las ${n}';
	@override String get skips => 'Sin VPN';
	@override String get unstar => 'Quitar de favoritas';
	@override String get star => 'Añadir a favoritas';
}

// Path: location
class _Translations$location$es extends Translations$location$en {
	_Translations$location$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Permitir ubicación para Wi-Fi';
	@override String get useHome => 'Mostrar el nombre de tu Wi-Fi en Inicio';
	@override String get useScan => 'Analizar redes y canales cercanos';
	@override String get private => 'Se queda en este teléfono. Tu ubicación nunca se recopila.';
	@override String get switchTitle => 'Activa la ubicación';
	@override String get switchBody => 'Android oculta los nombres de Wi-Fi mientras la ubicación está desactivada';
}

// Path: addServer
class _Translations$addServer$es extends Translations$addServer$en {
	_Translations$addServer$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get clipboardEmpty => 'El portapapeles está vacío.';
	@override String get title => 'Añade tu servidor';
	@override String get body => 'Pega una configuración de WireGuard de tu router, VPS o servidor en casa.';
	@override String get nameHint => 'Nombre, por ejemplo Router de casa';
	@override String get paste => 'Pegar';
	@override String get save => 'Guardar servidor';
	@override String notWireguard({required Object error}) => 'No es una configuración de WireGuard: ${error}';
}

// Path: button
class _Translations$button$es extends Translations$button$en {
	_Translations$button$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get stop => 'Detener';
	@override String get connecting => 'Conectando';
	@override String get stopping => 'Deteniendo';
	@override String get connect => 'Conectar';
	@override String get disconnect => 'Desconectar';
}

// Path: wol
class _Translations$wol$es extends Translations$wol$en {
	_Translations$wol$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get info => 'Enciende un ordenador o NAS de esta Wi-Fi si tiene Wake on LAN activado en sus ajustes. Tu teléfono debe estar en la misma red; desactiva antes la VPN.';
	@override String get badMac => 'Eso no es una dirección MAC. Tiene este aspecto: AA:BB:CC:DD:EE:FF.';
	@override String get sent => 'Señal enviada. El dispositivo debería encenderse en menos de un minuto.';
	@override String get title => 'Wake on LAN';
	@override String get wake => 'Encender dispositivo';
	@override String get mac => 'Dirección MAC';
	@override String failed({required Object error}) => 'No se pudo enviar: ${error}';
}

// Path: speed
class _Translations$speed$es extends Translations$speed$en {
	_Translations$speed$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get info => 'Lo mide M-Lab, una plataforma abierta de investigación. Cada test usa entre 50 y 100 MB aproximadamente.\n\nResultados públicos: M-Lab publica cada test, incluida la dirección IP de origen, como datos abiertos de investigación.\n\nComparación de proveedores: tras un test sin VPN, G VPN solo envía las tres velocidades. El servicio de comparación lee tu proveedor y tu ciudad a partir de la propia conexión y no guarda ninguna dirección IP. Desactívalo con el interruptor al final de esta página.\n\nA través de la VPN: con la VPN activa, mide la velocidad por el túnel y la compara con tu último test sin ella.\n\nVista previa de vídeo: la misma imagen a la resolución que permite esta velocidad, según las tasas de bits que publican los servicios de streaming. No se descarga ningún vídeo.';
	@override String get download => 'Descarga';
	@override String get upload => 'Subida';
	@override String get finding => 'Buscando un servidor';
	@override String get throughVpn => 'A través de la VPN';
	@override String get directNoVpn => 'Directa, sin VPN';
	@override String get title => 'Test de velocidad';
	@override String get stop => 'Detener';
	@override String get start => 'Iniciar test';
	@override String get again => 'Repetir test';
	@override String get viaVpn => 'Con VPN';
	@override String get direct => 'Directa';
	@override String get mbps => 'Mbps';
	@override String get ping => 'PING';
	@override String get vsDirect => 'VS DIRECTA';
	@override String get compare => 'Comparar con proveedores cercanos';
	@override String get compareSub => 'Solo comparte velocidades, nunca tu IP';
	@override String get tierTv => 'Televisores grandes';
	@override String get tierLaptopLarge => 'Portátiles grandes';
	@override String get tierTablet => 'Tabletas y portátiles';
	@override String get tierPhone => 'Teléfonos';
	@override String get tierSmallPhone => 'Teléfonos pequeños';
	@override String get tierCalls => 'Llamadas y audio';
	@override String get messagingOnly => 'Solo mensajería';
	@override String get videoQuality => 'Calidad de vídeo';
	@override String get preview => 'VISTA PREVIA';
	@override String get history => 'Historial';
	@override String get clear => 'Borrar';
	@override String get viaVpnLower => 'con VPN';
	@override String get directLower => 'directa';
	@override String get gradeA => 'Varios streams 4K y videollamadas a la vez';
	@override String get gradeB => 'Streaming HD y videollamadas fluidas';
	@override String get gradeC => 'Un stream HD; las llamadas pueden cortarse en horas punta';
	@override String get gradeD => 'Navegar y mensajería; el vídeo va justo';
	@override String get yourCountry => 'tu país';
	@override String get median => 'Descarga mediana, últimos 30 días';
	@override String get fromUsers => 'Mbps · de tests de usuarios de G VPN';
	@override String get costLittle => 'La VPN apenas reduce la velocidad';
	@override String get costNoticeable => 'Notablemente más lenta que directa';
	@override String get costMuch => 'Mucho más lenta. Prueba otro servidor';
	@override String get ofDirect => 'de tu velocidad directa';
	@override String get none => 'ninguno';
	@override String ms({required Object n}) => '${n} ms';
	@override String previewTier({required Object tier}) => 'VISTA PREVIA · ${tier}';
	@override String streamsUpTo({required Object tier, required Object who}) => 'Streaming hasta ${tier} · ${who}';
	@override String today({required Object time}) => 'Hoy, ${time}';
	@override String tests({required Object n}) => '${n} tests';
	@override String gradeVpn({required Object label}) => '${label} a través de la VPN';
	@override String gradeIsp({required Object label, required Object isp}) => '${label} con ${isp}';
	@override String notEnough({required Object isp}) => 'Aún no hay suficientes tests de ${isp}';
	@override String get yourProvider => 'tu proveedor';
	@override String rankLine({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} en ${where}: ${rank} de ${of}';
	@override String costLine({required Object note, required Object mbps}) => '${note} · directa ${mbps} Mbps';
	@override String mbpsValue({required Object v}) => '${v} Mbps';
	@override String get gradeExcellent => 'Excelente';
	@override String get gradeVeryGood => 'Muy buena';
	@override String get gradeGood => 'Buena';
	@override String get gradeFair => 'Aceptable';
	@override String get gradeSlow => 'Lenta';
	@override String get gradeVerySlow => 'Muy lenta';
}

// Path: router
class _Translations$router$es extends Translations$router$en {
	_Translations$router$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get info => 'Pregunta a tu router, mediante UPnP, si los dispositivos pueden abrir puertos a internet por su cuenta, y muestra los que han abierto. Solo lee y no cambia nada. Si nada necesita UPnP (algunas consolas sí), es más seguro desactivarlo en los ajustes del router.';
	@override String get title => 'Revisión del router';
	@override String get asking => 'Consultando al router';
	@override String get again => 'Revisar de nuevo';
	@override String get check => 'Revisar router';
	@override String get off => 'UPnP desactivado';
	@override String get offBody => 'Los dispositivos no pueden abrir puertos por su cuenta.';
	@override String get onBody => 'Ahora mismo no hay puertos abiertos por UPnP.';
	@override String get checkEach => 'Comprueba que reconoces cada uno.';
	@override String get cgnat => 'Dirección compartida del proveedor: no es accesible desde internet.';
	@override String get noDescription => 'Sin descripción';
	@override String opened({required Object n}) => '${n} puertos abiertos por dispositivos';
	@override String routerName({required Object name}) => 'Router: ${name}';
	@override String externalIp({required Object ip}) => 'Dirección de internet: ${ip}';
	@override String mapping({required Object proto, required Object host}) => '${proto} hacia ${host}';
	@override String get upnpOn => 'UPnP activado';
}

// Path: network
class _Translations$network$es extends Translations$network$en {
	_Translations$network$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Esta red';
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Datos móviles';
	@override String get ethernet => 'Ethernet';
	@override String get offline => 'Sin conexión';
	@override String get risky => 'Red de riesgo. Conecta la VPN aquí.';
	@override String get review => 'Conviene revisarla antes de confiar.';
	@override String get covered => 'Protegida por la VPN.';
	@override String get safe => 'Esta red parece segura.';
	@override String get mobileSentence => 'Datos móviles.';
	@override String get notConnected => 'Sin conexión.';
	@override String get showName => 'Mostrar nombre';
	@override String get sitesSee => 'Los sitios ven';
	@override String get provider => 'Proveedor';
	@override String get location => 'Ubicación';
	@override String get couldNotCheck => 'No se pudo comprobar';
	@override String get checking => 'Comprobando';
	@override String get signal => 'Señal';
	@override String get linkSpeed => 'Velocidad de enlace';
	@override String get gateway => 'Puerta de enlace';
	@override String get none => 'Ninguna';
	@override String get privateDns => 'DNS privado';
	@override String get automatic => 'Automático';
	@override String get off => 'Desactivado';
	@override String get metered => 'Con límite de datos';
	@override String get yes => 'Sí';
	@override String get no => 'No';
	@override String readFailed({required Object error}) => 'No se pudo leer la red: ${error}';
}

// Path: devices
class _Translations$devices$es extends Translations$devices$en {
	_Translations$devices$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get info => 'Llama a cada dirección del rango de tu Wi-Fi y pide a los dispositivos que se identifiquen. Un dispositivo que rechaza también cuenta: el rechazo demuestra que está ahí.\n\nNombres: de lo que publican los dispositivos (Bonjour, UPnP, nombres de Windows) y de tu router.\n\nDispositivos desconocidos: Android oculta las direcciones de hardware a las apps, así que un dispositivo silencioso sin nombre no se puede identificar. Búscalos en la lista de dispositivos de tu router.\n\nNuevo: un dispositivo que no apareció en tu último análisis de esta red.';
	@override String get needWifi => 'Conéctate primero a una red Wi-Fi.';
	@override String get title => 'Dispositivos';
	@override String get again => 'Analizar de nuevo';
	@override String get looking => 'Buscando dispositivos';
	@override String get nothingNew => 'Nada nuevo desde el último análisis';
	@override String get takes => 'Tarda unos 30 segundos';
	@override String get all => 'Todos';
	@override String get phones => 'Teléfonos';
	@override String get tvs => 'Televisores';
	@override String get computers => 'Ordenadores';
	@override String get other => 'Otros';
	@override String get thisPhone => 'Este teléfono';
	@override String get router => 'Router';
	@override String get unknown => 'Dispositivo desconocido';
	@override String get address => 'Dirección';
	@override String get answersIn => 'Responde en';
	@override String get type => 'Tipo';
	@override String get notAnnounced => 'No se identificó. La lista de dispositivos de tu router puede darle nombre.';
	@override String get newBadge => 'NUEVO';
	@override String scanning({required Object n}) => 'Analizando ${n} de 254';
	@override String get thisNetwork => 'esta red';
	@override String newSince({required Object n}) => '${n} nuevos desde el último análisis';
	@override String showMore({required Object n}) => 'Mostrar ${n} más';
	@override String ms({required Object n}) => '${n} ms';
	@override String onNetwork({required Object network}) => 'dispositivos en ${network}';
}

// Path: ping
class _Translations$ping$es extends Translations$ping$en {
	_Translations$ping$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get info => 'Cuánto tarda un viaje de ida y vuelta a un servidor, medido cada segundo durante el último minuto.\n\nJitter: cuánto varía cada respuesta respecto a la anterior. Un jitter alto es lo que corta las llamadas.\n\nPérdida: respuestas que nunca volvieron.\n\nCómo: las apps de Android no pueden enviar pings clásicos, así que cada sondeo mide un saludo de conexión, que es el mismo viaje de ida y vuelta.';
	@override String get askTitle => 'Hacer ping a un host';
	@override String get askHint => 'example.com o 192.168.1.10';
	@override String get cancel => 'Cancelar';
	@override String get title => 'Ping';
	@override String get router => 'Router';
	@override String get pause => 'Pausar';
	@override String get start => 'Iniciar';
	@override String get host => 'Host';
	@override String get live => 'En vivo';
	@override String get ago => 'hace 60 s';
	@override String get min => 'MÍN';
	@override String get avg => 'MEDIA';
	@override String get jitter => 'JITTER';
	@override String get loss => 'PÉRDIDA';
	@override String get goodFor => 'Suficiente para';
	@override String get calls => 'Videollamadas';
	@override String get games => 'Juegos online';
	@override String get streaming => 'Streaming';
	@override String get great => 'Genial';
	@override String get okay => 'Aceptable';
	@override String get poor => 'Mala';
	@override String get lost => 'perdido';
	@override String get now => 'ahora';
}

// Path: status
class _Translations$status$es extends Translations$status$en {
	_Translations$status$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get info => 'Se conecta a cada servicio tres veces y muestra la respuesta más rápida.\n\nBloqueado aquí: un servicio que no responde directamente pero funciona a través de la VPN está bloqueado por tu red o tu país.\n\nHistorial: las comprobaciones de las últimas 24 horas desde este teléfono, guardadas solo en él.';
	@override String get title => 'Estado de servicios';
	@override String get checking => 'Comprobando';
	@override String get again => 'Comprobar de nuevo';
	@override String get viaVpn => 'Comprobado a través de la VPN';
	@override String get direct => 'Comprobado directamente';
	@override String get favourites => 'Favoritos';
	@override String get edit => 'Editar';
	@override String get last24 => 'Últimas 24 horas';
	@override String get ago => 'hace 24 h';
	@override String get all => 'Todos los servicios';
	@override String get pickFour => 'Elige hasta cuatro';
	@override String get outage => 'Ni con la VPN: probablemente una caída';
	@override String get blocked => 'Puede estar bloqueado en esta red';
	@override String get connect => 'Conectar';
	@override String get blockedShort => 'Bloqueado';
	@override String get unreachable => 'Inaccesible';
	@override String get now => 'ahora';
	@override String checks({required Object n}) => '${n} comprobaciones';
	@override String andMore({required Object first, required Object n}) => '${first} y ${n} más';
	@override String notReachable({required Object who}) => '${who} no responde';
}

// Path: tools
class _Translations$tools$es extends Translations$tools$en {
	_Translations$tools$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Datos móviles';
	@override String get ethernet => 'Ethernet';
	@override String get checking => 'Comprobando';
	@override String get offline => 'Sin conexión';
	@override String get title => 'Herramientas';
	@override String get networkDesc => 'Revisión de seguridad, lo que ven los sitios, señal, router y DNS.';
	@override String get internet => 'Conexión a internet';
	@override String get speed => 'Test de velocidad';
	@override String get speedDesc => 'Velocidad de descarga y subida, y la calidad de vídeo que admite.';
	@override String get ping => 'Ping';
	@override String get pingDesc => 'Tiempo de respuesta y jitter en vivo hacia cualquier servidor o tu router.';
	@override String get status => 'Estado de servicios';
	@override String get statusDesc => '¿Se puede acceder a WhatsApp, YouTube o Google desde aquí, o están bloqueados?';
	@override String get trace => 'Traceroute';
	@override String get traceDesc => 'Cada router entre tú y un sitio, y cuánto tarda cada uno.';
	@override String get security => 'Seguridad de la red';
	@override String get devices => 'Dispositivos en esta red';
	@override String get devicesDesc => 'Quién más está en tu Wi-Fi: teléfonos, televisores, cámaras y ordenadores.';
	@override String get router => 'Revisión del router';
	@override String get routerDesc => 'Si los dispositivos pueden abrir puertos en tu router por su cuenta (UPnP).';
	@override String get ports => 'Puertos abiertos';
	@override String get portsDesc => 'Revisa tu router o un servidor en busca de puertos abiertos peligrosos.';
	@override String get utilities => 'Utilidades';
	@override String get wifiScanner => 'Escáner de Wi-Fi';
	@override String get wifiDesc => 'Redes cercanas, su seguridad y el canal menos saturado.';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'Enciende un ordenador o NAS de esta red.';
}

// Path: trace
class _Translations$trace$es extends Translations$trace$en {
	_Translations$trace$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get info => 'Cada parada es un router por el que pasa tu tráfico de camino al sitio.\n\nSaltos silenciosos: muchos routers nunca responden a estos sondeos. Es normal y no es un fallo.\n\nCon la VPN activa: la ruta empieza dentro del túnel, así que tu red y tu proveedor quedan ocultos.\n\nCómo: usa la herramienta ping de Android con un límite de saltos, ya que las apps no pueden enviar estos paquetes directamente.';
	@override String get title => 'Traceroute';
	@override String get stop => 'Detener';
	@override String get trace => 'Trazar';
	@override String get again => 'Trazar de nuevo';
	@override String get destination => 'Destino';
	@override String get hops => 'SALTOS';
	@override String get answered => 'RESPONDIERON';
	@override String get total => 'TOTAL';
	@override String get thisPhone => 'Este teléfono';
	@override String get silentOne => '1 salto silencioso';
	@override String get yourRouter => 'Tu router';
	@override String ms({required Object n}) => '${n} ms';
	@override String silentMany({required Object n}) => '${n} saltos silenciosos';
	@override String hop({required Object n}) => 'Salto ${n}';
	@override String slowest({required Object ms, required Object hop}) => 'La mayor parte del retraso, ${ms} ms, se añade en el salto ${hop}: suele ser un cable largo entre países o un enlace saturado.';
}

// Path: ports
class _Translations$ports$es extends Translations$ports$en {
	_Translations$ports$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get ftpNote => 'Envía contraseñas sin cifrar.';
	@override String get sshNote => 'Acceso remoto. Bien si lo configuraste tú.';
	@override String get telnetNote => 'Acceso remoto sin cifrar; favorito de las botnets.';
	@override String get dnsNote => 'Normal en un router.';
	@override String get web => 'Web (HTTP)';
	@override String get webNote => 'Suele ser la página de administración del router.';
	@override String get webTls => 'Web (HTTPS)';
	@override String get smb => 'Compartir archivos de Windows';
	@override String get smbNote => 'Nunca debería estar expuesto a internet.';
	@override String get rtsp => 'Transmisión de cámara RTSP';
	@override String get rtspNote => 'Puede haber una cámara transmitiendo aquí.';
	@override String get upnpNote => 'Permite a los dispositivos abrir puertos del router por su cuenta.';
	@override String get rdp => 'Escritorio remoto';
	@override String get rdpNote => 'Una vía de intrusión habitual.';
	@override String get vncNote => 'Pantalla compartida, a menudo sin contraseña.';
	@override String get tr069Note => 'Gestión remota del proveedor.';
	@override String get webAlt => 'Web (alternativo)';
	@override String get webAltTls => 'Web (HTTPS alternativo)';
	@override String get title => 'Puertos abiertos';
	@override String get check => 'Revisar puertos';
	@override String get address => 'Dirección del dispositivo o servidor';
	@override String get risky => 'RIESGO';
	@override String get review => 'REVISAR';
	@override String get normal => 'NORMAL';
	@override String info({required Object n}) => 'Revisa los ${n} puertos que importan en routers y dispositivos domésticos, y explica cada uno que esté abierto.\n\nRevisa solo dispositivos y servidores que sean tuyos o que administres.';
	@override String checking({required Object n}) => 'Revisando ${n} puertos';
	@override String yourRouter({required Object ip}) => 'Tu router es ${ip}';
	@override String noneOpen({required Object host}) => 'No hay puertos habituales abiertos en ${host}.';
}

// Path: wifi
class _Translations$wifi$es extends Translations$wifi$en {
	_Translations$wifi$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Escáner de Wi-Fi';
	@override String get allow => 'Permitir análisis de Wi-Fi';
	@override String get needsPermission => 'Necesita permiso de ubicación.';
	@override String get scanning => 'Analizando';
	@override String get again => 'Analizar de nuevo';
	@override String get failed => 'El análisis falló';
	@override String get none => 'No se encontraron redes. Puede que la ubicación esté desactivada.';
	@override String get hidden => 'Red oculta';
	@override String nearby({required Object n}) => '${n} redes cercanas';
	@override String bestChannel({required Object n}) => 'Canal de 2,4 GHz menos saturado: ${n}';
	@override String weak({required Object n}) => '${n} abiertas o débiles';
	@override String get connectedPrefix => 'Conectada · ';
	@override String get permissionInfo => 'Android solo muestra las redes Wi-Fi cercanas a las apps con permiso de ubicación. G VPN lo usa únicamente para listar redes en este teléfono.';
	@override String get info => 'Muestra las redes del último análisis del teléfono. Android solo permite unos pocos análisis por minuto, así que repetir rápido puede mostrar la misma lista. El canal sugerido es el menos saturado entre 1, 6 y 11, los tres que no se solapan.';
}

// Path: errors
class _Translations$errors$es extends Translations$errors$en {
	_Translations$errors$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get notAuthorized => 'No se concedió el permiso de VPN.';
	@override String get turnedOff => 'El sistema u otra app desactivó la VPN.';
	@override String get busy => 'Ya hay una solicitud de permiso abierta.';
	@override String get cancelled => 'Conexión cancelada.';
	@override String badConfig({required Object error}) => 'La configuración de este servidor no es válida: ${error}';
	@override String get timeout => 'El servidor no respondió.';
	@override String get refused => 'El servidor rechazó la conexión.';
	@override String failed({required Object error}) => 'No se pudo conectar: ${error}';
	@override String get tryAnother => 'Los servidores gratuitos van y vienen; prueba con otro.';
	@override String get downloadFailed => 'No se pudieron descargar los ajustes de este servidor. Revisa tu conexión o elige otro servidor.';
}

// Path: scan
class _Translations$scan$es extends Translations$scan$en {
	_Translations$scan$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get mobile => 'Datos móviles';
	@override String get ping => 'PING';
	@override String get noReply => 'Sin respuesta';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, túnel';
	@override String get dnsTunnel => 'En el túnel';
	@override String get privateDns => 'DNS privado';
	@override String get dnsIsp => 'Proveedor, visible';
	@override String get network => 'RED';
	@override String get offline => 'Sin conexión';
	@override String get open => 'Abierta, sin contraseña';
	@override String get wep => 'WEP, insegura';
	@override String get owe => 'Abierta, cifrada';
	@override String get enterprise => 'Empresarial';
	@override String get unknown => 'Desconocida';
	@override String get wifi => 'WI-FI';
	@override String get signIn => 'Página de acceso';
	@override String ms({required Object n}) => '${n} ms';
	@override String covered({required Object what}) => '${what}, protegida';
}

// Path: legal
class _Translations$legal$es extends Translations$legal$en {
	_Translations$legal$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get privacy => 'Política de privacidad';
	@override String get terms => 'Condiciones de uso';
	@override String get licences => 'Licencias de código abierto';
}

// Path: update
class _Translations$update$es extends Translations$update$en {
	_Translations$update$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get ready => 'Hay una actualización lista';
	@override String get restart => 'Reiniciar';
}

// Path: details
class _Translations$details$es extends Translations$details$en {
	_Translations$details$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get share => 'Compartir';
	@override String connectedFor({required Object n}) => 'CONECTADO · ${n} MIN';
	@override String get notConnected => 'SIN CONECTAR';
	@override String get downloaded => 'DESCARGADO';
	@override String get uploaded => 'SUBIDO';
	@override String get lastUsed => 'ÚLTIMO USO';
	@override String get connection => 'Conexión';
	@override String get protocol => 'Protocolo';
	@override String get address => 'Tu dirección';
	@override String get dns => 'DNS';
	@override String get routes => 'Rutas';
	@override String get allTraffic => 'Todo el tráfico';
	@override String someRoutes({required Object n}) => '${n} redes';
	@override String get keepalive => 'Keepalive';
	@override String get serverKey => 'Clave del servidor';
	@override String get copy => 'Copiar';
	@override String get copied => 'Copiado';
	@override String get manage => 'Gestionar';
	@override String get export => 'Exportar copia de seguridad';
	@override String get exportSub => 'Todos tus servidores en un archivo';
}

// Path: share
class _Translations$share$es extends Translations$share$en {
	_Translations$share$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String title({required Object name}) => 'Compartir ${name}';
	@override String get sameKey => 'Esto comparte la clave de este teléfono. Cualquiera que la tenga puede usar tu servidor como tú, y solo un dispositivo puede estar conectado con ella a la vez.';
	@override String get scanHint => 'En el otro teléfono: G VPN, Servidores, Escanear QR. También sirve una imagen guardada.';
	@override String get saveImage => 'Guardar imagen';
	@override String get send => 'Enviar';
}

// Path: add
class _Translations$add$es extends Translations$add$en {
	_Translations$add$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Añadir un servidor';
	@override String get subtitle => 'Cualquier servidor WireGuard: un router, un VPS o un servidor en casa.';
	@override String get camera => 'Escanear con la cámara';
	@override String get cameraSub => 'QR en otra pantalla';
	@override String get image => 'Desde una imagen';
	@override String get imageSub => 'Captura o foto guardada';
	@override String get noQr => 'No hay ningún código QR en esa imagen.';
	@override String get tip => '¿Te llegó el QR por WhatsApp o Telegram? Toca Compartir en la imagen y elige G VPN.';
}

// Path: backup
class _Translations$backup$es extends Translations$backup$en {
	_Translations$backup$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String restored({required Object n}) => '${n} servidores restaurados';
	@override String get nothingNew => 'Estos servidores ya están aquí';
}

// Path: gs
class _Translations$gs$es extends Translations$gs$en {
	_Translations$gs$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'G Servers son para suscriptores de G VPN Pro.';
	@override String get off => 'G Servers están desactivados ahora.';
	@override String get network => 'No se pudo contactar con G Servers. Revisa tu conexión e inténtalo de nuevo.';
	@override String get active => 'ACTIVO';
	@override String get servers => 'G Servers';
	@override String busy({required Object n}) => '${n}% ocupado';
	@override String get offline => 'Sin conexión';
	@override String get devices => 'Tus dispositivos';
	@override String devicesSub({required Object n}) => 'Hasta ${n} teléfonos, cada uno con su clave';
	@override String get footnote => 'Cada teléfono tiene su propia clave, creada en el teléfono. G Servers no guardan registros de actividad.';
	@override String get leastBusy => 'EL MENOS OCUPADO AHORA';
	@override String busyNoLogs({required Object n}) => '${n}% ocupado · sin registros';
	@override String subtitle({required Object country}) => 'G Server · ${country} · WireGuard';
	@override String get busyLabel => 'OCUPADO';
	@override String get status => 'ESTADO';
	@override String get online => 'En línea';
	@override String get onThisServer => 'En este servidor';
	@override String get thisPhone => 'Este teléfono';
	@override String get added => 'Añadido · clave creada aquí';
	@override String get notAdded => 'Se añade al conectar';
	@override String get logs => 'Registros de actividad';
	@override String get noneKept => 'No se guardan';
	@override String get privacy => 'El servidor solo conoce este teléfono por su clave pública. No registra los sitios que visitas ni el tráfico que envías.';
	@override String get stepPro1 => 'Instala G VPN en el teléfono con la misma cuenta de Google.';
	@override String get stepPro2 => 'Abre la pestaña Pro. Pro se activa solo, o toca Restaurar.';
	@override String get step3 => 'Toca Conectar. El teléfono crea su clave y se añade a G Servers. Sin QR ni códigos.';
	@override String get stepFree1 => 'Instala G VPN en el teléfono.';
	@override String get stepFree2 => 'Abre la pestaña Pro.';
	@override String get devicesIntroPro => 'Pro va con tu cuenta de Google. Cada teléfono tiene su clave, así que nunca se desconectan entre sí.';
	@override String get devicesIntroFree => 'Cada teléfono tiene su clave, así que nunca se desconectan entre sí.';
	@override String get otherPhone => 'Otro teléfono';
	@override String lastConnected({required Object when}) => 'Última conexión ${when}';
	@override String get noDevices => 'Conéctate una vez a un G Server y tus teléfonos aparecerán aquí.';
	@override String get addTitle => 'Añadir un teléfono o reinstalar';
	@override String idle({required Object n}) => 'Un teléfono que no se conecta en ${n} días se quita de G Servers solo, así que un teléfono viejo o reinstalado nunca ocupa un hueco.';
	@override String limitNote({required Object n}) => 'Hasta ${n} teléfonos por plan.';
	@override String fullTitle({required Object n}) => 'Los ${n} huecos están en uso';
	@override String get fullBody => 'Quita un teléfono que ya no uses y este se conectará al momento.';
	@override String get busyNow => 'Demasiados teléfonos nuevos ahora mismo. Inténtalo de nuevo en un rato.';
	@override String get serverFull => 'Este servidor está lleno. Prueba otro G Server.';
	@override String get ping => 'PING';
	@override String get last24 => 'Ocupación, últimas 24 horas';
	@override String get noHistory => 'El gráfico se llena a medida que el servidor se usa durante el día.';
	@override String chartLabel({required Object max}) => 'Ocupación en las últimas 24 horas, como máximo ${max} por ciento';
	@override String get hoursAgo => 'hace 24 h';
	@override String get now => 'Ahora';
}

// Path: home.status
class _Translations$home$status$es extends Translations$home$status$en {
	_Translations$home$status$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get paused => 'En pausa';
	@override String get reconnecting => 'Reconectando';
	@override String get protected => 'Protegido';
	@override String get connecting => 'Conectando';
	@override String get stopping => 'Deteniendo';
	@override String get notProtected => 'Sin protección';
}

// Path: home.waves
class _Translations$home$waves$es extends Translations$home$waves$en {
	_Translations$home$waves$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get encrypted => 'CIFRADO';
	@override String get securing => 'PROTEGIENDO';
	@override String get exposed => 'EXPUESTO';
}

// Path: home.network
class _Translations$home$network$es extends Translations$home$network$en {
	_Translations$home$network$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'ESTA RED';
	@override String get wifi => 'Wi-Fi';
	@override String get offline => 'Sin conexión';
	@override String get showName => 'Mostrar nombre';
	@override String get scanFailed => 'El análisis falló. Se repetirá cuando cambie la red.';
}

// Path: home.card
class _Translations$home$card$es extends Translations$home$card$en {
	_Translations$home$card$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get connectedVia => 'CONECTADO MEDIANTE';
	@override String get protocol => 'PROTOCOLO';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, en el túnel';
	@override String get dnsServer => 'Servidor, en el túnel';
	@override String get downloaded => 'DESCARGADO';
	@override String get uploaded => 'SUBIDO';
	@override String get wireguard => 'WireGuard';
	@override String openvpn({required Object proto}) => 'OpenVPN ${proto}';
	@override String get selected => 'SELECCIONADO';
	@override String get browsingFrom => 'NAVEGANDO DESDE';
	@override String get disconnect => 'Desconectar';
	@override String get change => 'Cambiar';
	@override String get enabled => 'Activado';
	@override String get shield => 'ESCUDO';
}

// Path: home.tiles
class _Translations$home$tiles$es extends Translations$home$tiles$en {
	_Translations$home$tiles$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get shield => 'Escudo';
	@override String get shieldOn => 'Bloquea sitios maliciosos';
	@override String get appsDirect => 'Apps directas';
	@override String get appsAll => 'Todas las apps protegidas';
	@override String appsSkip({required Object n}) => '${n} sin VPN';
	@override String get autoConnect => 'Conexión automática';
	@override String get autoOpen => 'En Wi-Fi públicas';
	@override String get autoAny => 'En cualquier Wi-Fi';
	@override String get speed => 'Velocidad';
	@override String get speedTap => 'Toca para medir';
	@override String speedDirect({required Object mbps}) => 'Directa ${mbps} Mbps';
}

// Path: home.fastest
class _Translations$home$fastest$es extends Translations$home$fastest$en {
	_Translations$home$fastest$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Servidor gratis más rápido';
	@override String get pickedFrom => 'Elegido entre';
	@override String more({required Object n}) => '+${n}';
	@override String get finding => 'Buscando el servidor más rápido';
	@override String get failed => 'No se pudieron cargar los servidores gratis';
	@override String get how => 'Cómo se elige el servidor';
	@override String get sheetBody => 'G VPN te conecta al servidor gratis mejor clasificado en este momento, según velocidad, carga y tiempo sin reinicios. La clasificación cambia a medida que los servidores aparecen y desaparecen.';
}

// Path: home.ip
class _Translations$home$ip$es extends Translations$home$ip$en {
	_Translations$home$ip$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Lo que ven los sitios';
	@override String get real => 'Tu ubicación real';
	@override String get vpn => 'Ubicación de la VPN';
	@override String get address => 'Dirección IP';
	@override String get coordinates => 'Coordenadas';
	@override String get note => 'Estimada a partir de tu IP. Nunca se guarda.';
	@override String get hide => 'Ocultar mi ubicación';
	@override String near({required Object place}) => 'Cerca de ${place}';
}

// Path: servers.tabs
class _Translations$servers$tabs$es extends Translations$servers$tabs$en {
	_Translations$servers$tabs$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get pro => 'Pro';
	@override String get free => 'Gratis';
	@override String get yours => 'Tuyos';
}

// Path: servers.sheet
class _Translations$servers$sheet$es extends Translations$servers$sheet$en {
	_Translations$servers$sheet$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'De dónde vienen los servidores';
	@override String get subtitle => 'Tres tipos, una sola lista';
	@override String get free => 'Servidores voluntarios, revisados cada dos horas. Sus operadores guardan registros de conexión durante unas dos semanas.';
	@override String get pro => 'Gestionados por nosotros con WireGuard. Sin registros de actividad y sin cuenta.';
	@override String get yours => 'Cualquier servidor WireGuard que tengas: un router, un VPS o un servidor en casa.';
}

// Path: servers.badges
class _Translations$servers$badges$es extends Translations$servers$badges$en {
	_Translations$servers$badges$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get mostUsed => 'MÁS USADO';
	@override String get mostStable => 'MÁS ESTABLE';
	@override String get fastest => 'MÁS RÁPIDO';
}

// Path: servers.filters
class _Translations$servers$filters$es extends Translations$servers$filters$en {
	_Translations$servers$filters$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get all => 'Todos';
	@override String get fastest => 'Más rápidos';
	@override String get stable => 'Más estables';
	@override String get popular => 'Populares';
}

// Path: servers.own
class _Translations$servers$own$es extends Translations$servers$own$en {
	_Translations$servers$own$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Usa tu propio servidor';
	@override String get subtitle => 'Sirve cualquier servidor WireGuard';
	@override String get router => 'Un router';
	@override String get routerBody => 'Muchos routers traen WireGuard integrado. Exporta la configuración de cliente y escanea su código QR aquí.';
	@override String get vps => 'Un VPS';
	@override String get vpsBody => 'Cualquier servidor Linux pequeño. Instala WireGuard, crea un cliente e importa su archivo de configuración.';
	@override String get home => 'Un servidor en casa';
	@override String get homeBody => 'Accede a tu propia red desde cualquier lugar, de la misma forma.';
	@override String get noneYet => '¿Aún no tienes servidor?';
	@override String get addAnother => 'Añadir otro';
	@override String get hint => 'Móntalo en un router, un VPS o un servidor en casa';
}

// Path: pro.free
class _Translations$pro$free$es extends Translations$pro$free$en {
	_Translations$pro$free$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tu plan';
	@override String get headline => 'Todo es gratis';
	@override String get body => 'Todos los servidores y todas las herramientas, sin cuenta y sin anuncios.';
	@override String get included => 'Incluye';
	@override String get servers => 'Servidores gratuitos';
	@override String get serversSub => 'Ordenados por velocidad y estabilidad en decenas de países';
	@override String get own => 'Tus propios servidores';
	@override String get ownSub => 'Conéctate a cualquier router, VPS o servidor en casa con WireGuard';
	@override String get shield => 'Escudo';
	@override String get shieldSub => 'Bloquea sitios conocidos de malware y phishing';
	@override String get auto => 'Conexión automática y reglas de apps';
	@override String get autoSub => 'Protege las Wi-Fi públicas; deja que las apps del banco vayan directas';
	@override String get pause => 'Pausa y Ajustes rápidos';
	@override String get pauseSub => 'Pausa desde la notificación, activa desde el mosaico';
	@override String get tools => 'Todas las herramientas de red';
	@override String get toolsSub => 'Test de velocidad, ping, estado de servicios, traceroute, dispositivos y más';
	@override String get later => 'G VPN Pro añadirá servidores más rápidos gestionados por nosotros. Todo lo anterior sigue siendo gratis.';
}

// Path: rules.info
class _Translations$rules$info$es extends Translations$rules$info$en {
	_Translations$rules$info$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get shield => 'El Escudo envía las consultas DNS a Quad9, que rechaza sitios conocidos de malware y phishing. No bloquea anuncios y, mientras está activo, sustituye el DNS del servidor.';
	@override String get autoConnect => 'Conexión automática: usa el servidor WireGuard que elegiste. Desconectar a mano la pausa hasta que te unas a otra red.';
	@override String get apps => 'Apps directas: las apps que no usan la VPN se conectan directamente. Los bancos suelen bloquear direcciones de VPN, así que los pagos pueden fallar a través de una VPN.';
	@override String get reconnect => 'Cambiar el Escudo o las apps reconecta la VPN un momento.';
	@override String get stay => 'Seguir conectado: algunos teléfonos detienen apps en segundo plano para ahorrar batería. La VPN siempre activa y la batería sin restricciones mantienen G VPN en marcha.';
}

/// The flat map containing all translations for locale <es>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.gotIt' => 'Entendido',
			'common.about' => 'Acerca de',
			'common.connect' => 'Conectar',
			'common.connected' => 'Conectado',
			'common.retry' => 'Reintentar',
			'common.ok' => 'Aceptar',
			'common.remove' => 'Quitar',
			'common.cancel' => 'Cancelar',
			'common.continueLabel' => 'Continuar',
			'common.notNow' => 'Ahora no',
			'common.openSettings' => 'Abrir ajustes',
			'common.close' => 'Cerrar',
			'common.off' => 'Desactivado',
			'common.changesReconnect' => 'Los cambios reconectan la VPN',
			'nav.vpn' => 'VPN',
			'nav.servers' => 'Servidores',
			'nav.tools' => 'Herramientas',
			'nav.rules' => 'Reglas',
			'nav.pro' => 'Pro',
			'home.status.paused' => 'En pausa',
			'home.status.reconnecting' => 'Reconectando',
			'home.status.protected' => 'Protegido',
			'home.status.connecting' => 'Conectando',
			'home.status.stopping' => 'Deteniendo',
			'home.status.notProtected' => 'Sin protección',
			'home.resumesAt' => ({required Object time}) => 'Se reanuda a las ${time} · toca para reanudar ahora',
			'home.sitesSee' => ({required Object ip}) => 'Los sitios ven ${ip}',
			'home.sitesSeeOrg' => ({required Object ip, required Object org}) => 'Los sitios ven ${ip} · ${org}',
			'home.ipFailed' => 'No se pudo comprobar tu IP',
			'home.ipChecking' => 'Comprobando tu IP',
			'home.themeSystem' => 'Tema: según el teléfono',
			'home.themeLight' => 'Tema: claro',
			'home.themeDark' => 'Tema: oscuro',
			'home.free' => 'Gratis',
			'home.pickServer' => 'Elige un servidor',
			'home.waves.encrypted' => 'CIFRADO',
			'home.waves.securing' => 'PROTEGIENDO',
			'home.waves.exposed' => 'EXPUESTO',
			'home.network.title' => 'ESTA RED',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Sin conexión',
			'home.network.showName' => 'Mostrar nombre',
			'home.network.scanFailed' => 'El análisis falló. Se repetirá cuando cambie la red.',
			'home.card.connectedVia' => 'CONECTADO MEDIANTE',
			'home.card.protocol' => 'PROTOCOLO',
			'home.card.dns' => 'DNS',
			'home.card.dnsQuad9' => 'Quad9, en el túnel',
			'home.card.dnsServer' => 'Servidor, en el túnel',
			'home.card.downloaded' => 'DESCARGADO',
			'home.card.uploaded' => 'SUBIDO',
			'home.card.wireguard' => 'WireGuard',
			'home.card.openvpn' => ({required Object proto}) => 'OpenVPN ${proto}',
			'home.card.selected' => 'SELECCIONADO',
			'home.card.browsingFrom' => 'NAVEGANDO DESDE',
			'home.card.disconnect' => 'Desconectar',
			'home.card.change' => 'Cambiar',
			'home.card.enabled' => 'Activado',
			'home.card.shield' => 'ESCUDO',
			'home.tiles.shield' => 'Escudo',
			'home.tiles.shieldOn' => 'Bloquea sitios maliciosos',
			'home.tiles.appsDirect' => 'Apps directas',
			'home.tiles.appsAll' => 'Todas las apps protegidas',
			'home.tiles.appsSkip' => ({required Object n}) => '${n} sin VPN',
			'home.tiles.autoConnect' => 'Conexión automática',
			'home.tiles.autoOpen' => 'En Wi-Fi públicas',
			'home.tiles.autoAny' => 'En cualquier Wi-Fi',
			'home.tiles.speed' => 'Velocidad',
			'home.tiles.speedTap' => 'Toca para medir',
			'home.tiles.speedDirect' => ({required Object mbps}) => 'Directa ${mbps} Mbps',
			'home.fastest.title' => 'Servidor gratis más rápido',
			'home.fastest.pickedFrom' => 'Elegido entre',
			'home.fastest.more' => ({required Object n}) => '+${n}',
			'home.fastest.finding' => 'Buscando el servidor más rápido',
			'home.fastest.failed' => 'No se pudieron cargar los servidores gratis',
			'home.fastest.how' => 'Cómo se elige el servidor',
			'home.fastest.sheetBody' => 'G VPN te conecta al servidor gratis mejor clasificado en este momento, según velocidad, carga y tiempo sin reinicios. La clasificación cambia a medida que los servidores aparecen y desaparecen.',
			'home.ip.title' => 'Lo que ven los sitios',
			'home.ip.real' => 'Tu ubicación real',
			'home.ip.vpn' => 'Ubicación de la VPN',
			'home.ip.address' => 'Dirección IP',
			'home.ip.coordinates' => 'Coordenadas',
			'home.ip.note' => 'Estimada a partir de tu IP. Nunca se guarda.',
			'home.ip.hide' => 'Ocultar mi ubicación',
			'home.ip.near' => ({required Object place}) => 'Cerca de ${place}',
			'servers.title' => 'Servidores',
			'servers.aboutServers' => 'Acerca de los servidores',
			'servers.tabs.pro' => 'Pro',
			'servers.tabs.free' => 'Gratis',
			'servers.tabs.yours' => 'Tuyos',
			'servers.sheet.title' => 'De dónde vienen los servidores',
			'servers.sheet.subtitle' => 'Tres tipos, una sola lista',
			'servers.sheet.free' => 'Servidores voluntarios, revisados cada dos horas. Sus operadores guardan registros de conexión durante unas dos semanas.',
			'servers.sheet.pro' => 'Gestionados por nosotros con WireGuard. Sin registros de actividad y sin cuenta.',
			'servers.sheet.yours' => 'Cualquier servidor WireGuard que tengas: un router, un VPS o un servidor en casa.',
			'servers.badges.mostUsed' => 'MÁS USADO',
			'servers.badges.mostStable' => 'MÁS ESTABLE',
			'servers.badges.fastest' => 'MÁS RÁPIDO',
			'servers.filters.all' => 'Todos',
			'servers.filters.fastest' => 'Más rápidos',
			'servers.filters.stable' => 'Más estables',
			'servers.filters.popular' => 'Populares',
			'servers.loadFailed' => 'No se pudo cargar la lista',
			'servers.noServers' => 'No hay servidores ahora',
			'servers.best' => 'EL MEJOR PARA TI AHORA',
			'servers.topRanked' => 'El mejor valorado ahora',
			'servers.addHeading' => 'AÑADIR UN SERVIDOR',
			'servers.scanQr' => 'Escanear QR',
			'servers.importFile' => 'Importar archivo',
			'servers.paste' => 'Pegar',
			'servers.own.title' => 'Usa tu propio servidor',
			'servers.own.subtitle' => 'Sirve cualquier servidor WireGuard',
			'servers.own.router' => 'Un router',
			'servers.own.routerBody' => 'Muchos routers traen WireGuard integrado. Exporta la configuración de cliente y escanea su código QR aquí.',
			'servers.own.vps' => 'Un VPS',
			'servers.own.vpsBody' => 'Cualquier servidor Linux pequeño. Instala WireGuard, crea un cliente e importa su archivo de configuración.',
			'servers.own.home' => 'Un servidor en casa',
			'servers.own.homeBody' => 'Accede a tu propia red desde cualquier lugar, de la misma forma.',
			'servers.own.noneYet' => '¿Aún no tienes servidor?',
			'servers.own.addAnother' => 'Añadir otro',
			'servers.own.hint' => 'Móntalo en un router, un VPS o un servidor en casa',
			'servers.configBroken' => 'La configuración necesita revisión',
			'servers.connectedBadge' => 'CONECTADO',
			'servers.scannedServer' => 'Servidor escaneado',
			'servers.scanFailedTitle' => 'No se pudo escanear',
			'servers.scanFailedBody' => 'El escáner no está disponible en este teléfono.',
			'servers.importFailedTitle' => 'No se pudo importar',
			'servers.importFailedBody' => 'No se pudo leer ese archivo.',
			'servers.renameTitle' => 'Cambiar nombre del servidor',
			'servers.nameHint' => 'Nombre, por ejemplo Router de casa',
			'servers.save' => 'Guardar',
			'servers.rename' => 'Cambiar nombre',
			'servers.disconnect' => 'Desconectar',
			'servers.more' => 'Más opciones',
			'servers.justNow' => 'ahora mismo',
			'servers.minutesAgo' => ({required Object n}) => 'hace ${n} min',
			'servers.hoursAgo' => ({required Object n}) => 'hace ${n} h',
			'servers.daysAgo' => ({required Object n}) => 'hace ${n} d',
			'servers.neverUsed' => 'Aún sin usar',
			'servers.lastUsed' => ({required Object when}) => 'Último uso ${when}',
			'servers.disconnectFirst' => 'Desconéctate primero para quitarlo',
			'servers.removeConfirm' => '¿Quitar este servidor de G VPN? Sus ajustes se borran de este teléfono; el servidor no cambia.',
			'pro.owned' => 'Tienes Pro',
			'pro.waitingPlay' => 'Esperando a Google Play',
			'pro.startTrial' => ({required Object days}) => 'Empezar prueba gratis de ${days} días',
			'pro.thenYearly' => ({required Object price}) => 'Después ${price} al año. Cancela cuando quieras en Google Play.',
			'pro.thenMonthly' => ({required Object price}) => 'Después ${price} al mes. Cancela cuando quieras en Google Play.',
			'pro.yearlyPrice' => ({required Object price}) => '${price} al año. Cancela cuando quieras en Google Play.',
			'pro.monthlyPrice' => ({required Object price}) => '${price} al mes. Cancela cuando quieras en Google Play.',
			'pro.restore' => 'Restaurar',
			'pro.heroTitle' => 'Servidores más rápidos,\ngestionados por nosotros',
			'pro.heroSubtitle' => 'WireGuard. Sin registros de actividad. Sin cuenta.',
			'pro.benefitSpeed' => 'Velocidad completa, sin los límites de los voluntarios',
			'pro.benefitKey' => 'La clave se crea en tu teléfono y nunca se comparte',
			'pro.benefitFree' => 'Todo lo gratuito sigue siendo gratis',
			'pro.save' => ({required Object pct}) => 'AHORRA ${pct}%',
			'pro.yearly' => 'Anual',
			'pro.monthly' => 'Mensual',
			'pro.billedMonthly' => 'facturado cada mes',
			'pro.daysFree' => ({required Object days}) => '${days} días gratis',
			'pro.perMonth' => ({required Object price}) => '${price} al mes',
			'pro.title' => 'G VPN Pro',
			'pro.heroTitleOneLine' => 'Servidores más rápidos, gestionados por nosotros',
			'pro.includes' => 'Incluye',
			'pro.benefitLogs' => 'Sin registros de actividad en nuestros servidores',
			'pro.plan' => 'Elige un plan',
			'pro.renewGeneric' => 'Las suscripciones se renuevan automáticamente hasta que las canceles. Cancela cuando quieras en Google Play.',
			'pro.renewTrial' => ({required Object days, required Object price, required Object period}) => '${days} días gratis, después ${price} por ${period}. Se renueva automáticamente hasta que canceles; cancela en Google Play al menos un día antes de que termine la prueba para que no te cobren.',
			'pro.renew' => ({required Object price, required Object period}) => '${price} por ${period}. Se renueva automáticamente hasta que canceles; cancela cuando quieras en Google Play.',
			'pro.year' => 'año',
			'pro.month' => 'mes',
			'pro.manage' => 'Gestionar suscripción',
			'pro.free.title' => 'Tu plan',
			'pro.free.headline' => 'Todo es gratis',
			'pro.free.body' => 'Todos los servidores y todas las herramientas, sin cuenta y sin anuncios.',
			'pro.free.included' => 'Incluye',
			'pro.free.servers' => 'Servidores gratuitos',
			'pro.free.serversSub' => 'Ordenados por velocidad y estabilidad en decenas de países',
			'pro.free.own' => 'Tus propios servidores',
			'pro.free.ownSub' => 'Conéctate a cualquier router, VPS o servidor en casa con WireGuard',
			'pro.free.shield' => 'Escudo',
			'pro.free.shieldSub' => 'Bloquea sitios conocidos de malware y phishing',
			'pro.free.auto' => 'Conexión automática y reglas de apps',
			'pro.free.autoSub' => 'Protege las Wi-Fi públicas; deja que las apps del banco vayan directas',
			'pro.free.pause' => 'Pausa y Ajustes rápidos',
			'pro.free.pauseSub' => 'Pausa desde la notificación, activa desde el mosaico',
			'pro.free.tools' => 'Todas las herramientas de red',
			'pro.free.toolsSub' => 'Test de velocidad, ping, estado de servicios, traceroute, dispositivos y más',
			'pro.free.later' => 'G VPN Pro añadirá servidores más rápidos gestionados por nosotros. Todo lo anterior sigue siendo gratis.',
			'rules.title' => 'Reglas',
			'rules.info.shield' => 'El Escudo envía las consultas DNS a Quad9, que rechaza sitios conocidos de malware y phishing. No bloquea anuncios y, mientras está activo, sustituye el DNS del servidor.',
			'rules.info.autoConnect' => 'Conexión automática: usa el servidor WireGuard que elegiste. Desconectar a mano la pausa hasta que te unas a otra red.',
			'rules.info.apps' => 'Apps directas: las apps que no usan la VPN se conectan directamente. Los bancos suelen bloquear direcciones de VPN, así que los pagos pueden fallar a través de una VPN.',
			'rules.info.reconnect' => 'Cambiar el Escudo o las apps reconecta la VPN un momento.',
			'rules.info.stay' => 'Seguir conectado: algunos teléfonos detienen apps en segundo plano para ahorrar batería. La VPN siempre activa y la batería sin restricciones mantienen G VPN en marcha.',
			'rules.protection' => 'Protección',
			'rules.shield' => 'Escudo',
			'rules.shieldSub' => 'Bloquea sitios de malware y phishing',
			'rules.privateDns' => 'Escudo sin la VPN',
			'rules.privateDnsSub' => 'Copia dns.quad9.net para el DNS privado',
			'rules.privateDnsCopied' => 'dns.quad9.net copiado',
			'rules.privateDnsHow' => 'Abre Ajustes, busca DNS privado, elige "Nombre de host del proveedor de DNS privado" y pégalo.',
			'rules.stay' => 'Seguir conectado',
			'rules.alwaysOn' => 'VPN siempre activa',
			'rules.alwaysOnSub' => 'Android reinicia G VPN si se detiene',
			'rules.battery' => 'Batería',
			'rules.batteryOk' => 'Sin restricciones',
			'rules.batteryRestricted' => 'Restringida: puede detenerse en segundo plano',
			'rules.autoConnect' => 'Conexión automática',
			'rules.autoOff' => 'Desactivada',
			'rules.autoOffSub' => 'Solo cuando tocas',
			'rules.autoOpen' => 'Wi-Fi públicas',
			'rules.autoOpenSub' => 'Redes abiertas, WEP o con página de acceso',
			'rules.autoAny' => 'Cualquier Wi-Fi',
			'rules.autoAnySub' => 'Cualquier red Wi-Fi',
			'rules.apps' => 'Apps',
			'rules.appsDirect' => 'Apps directas',
			'rules.appsNone' => 'Todas las apps usan la VPN',
			'rules.appsSome' => ({required Object n}) => '${n} apps sin VPN',
			'rules.appearance' => 'Apariencia',
			'rules.themePhone' => 'Teléfono',
			'rules.themeLight' => 'Claro',
			'rules.themeDark' => 'Oscuro',
			'rules.about' => 'Acerca de',
			'apps.title' => 'Apps directas',
			'apps.sheetSubtitle' => 'Las apps elegidas se conectan sin la VPN. Todo lo demás sigue protegido.',
			'apps.whyTitle' => 'Por qué excluir una app',
			'apps.whyBody' => 'Los bancos y las apps de pago suelen bloquear direcciones de VPN, así que los pagos pueden fallar a través de una VPN. Algunos servicios locales solo funcionan desde tu país.',
			'apps.favouritesBody' => 'Marca con estrella las apps que cambias a menudo; se quedan arriba.',
			'apps.whileConnected' => 'Mientras está conectada',
			'apps.whileConnectedBody' => 'Cambiar esta lista reconecta la VPN un momento.',
			'apps.search' => ({required Object n}) => 'Buscar entre ${n} apps',
			'apps.skipping' => 'Sin VPN',
			'apps.skippingNone' => 'Ninguna. Todas las apps pasan por la VPN.',
			'apps.protectAgain' => ({required Object app}) => 'Volver a proteger ${app}',
			'apps.banking' => 'Bancos y pagos',
			'apps.bankingFound' => ({required Object n}) => '${n} encontradas que pueden bloquear VPN',
			'apps.addAll' => 'Añadir todas',
			'apps.favourites' => 'Favoritas',
			'apps.all' => 'Todas las apps',
			'apps.found' => ({required Object n}) => '${n} encontradas',
			'apps.noMatch' => 'Ninguna app coincide.',
			'apps.showAll' => ({required Object n}) => 'Mostrar las ${n}',
			'apps.skips' => 'Sin VPN',
			'apps.unstar' => 'Quitar de favoritas',
			'apps.star' => 'Añadir a favoritas',
			'location.title' => 'Permitir ubicación para Wi-Fi',
			'location.useHome' => 'Mostrar el nombre de tu Wi-Fi en Inicio',
			'location.useScan' => 'Analizar redes y canales cercanos',
			'location.private' => 'Se queda en este teléfono. Tu ubicación nunca se recopila.',
			'location.switchTitle' => 'Activa la ubicación',
			'location.switchBody' => 'Android oculta los nombres de Wi-Fi mientras la ubicación está desactivada',
			'addServer.clipboardEmpty' => 'El portapapeles está vacío.',
			'addServer.title' => 'Añade tu servidor',
			'addServer.body' => 'Pega una configuración de WireGuard de tu router, VPS o servidor en casa.',
			'addServer.nameHint' => 'Nombre, por ejemplo Router de casa',
			'addServer.paste' => 'Pegar',
			'addServer.save' => 'Guardar servidor',
			'addServer.notWireguard' => ({required Object error}) => 'No es una configuración de WireGuard: ${error}',
			'button.stop' => 'Detener',
			'button.connecting' => 'Conectando',
			'button.stopping' => 'Deteniendo',
			'button.connect' => 'Conectar',
			'button.disconnect' => 'Desconectar',
			'wol.info' => 'Enciende un ordenador o NAS de esta Wi-Fi si tiene Wake on LAN activado en sus ajustes. Tu teléfono debe estar en la misma red; desactiva antes la VPN.',
			'wol.badMac' => 'Eso no es una dirección MAC. Tiene este aspecto: AA:BB:CC:DD:EE:FF.',
			'wol.sent' => 'Señal enviada. El dispositivo debería encenderse en menos de un minuto.',
			'wol.title' => 'Wake on LAN',
			'wol.wake' => 'Encender dispositivo',
			'wol.mac' => 'Dirección MAC',
			'wol.failed' => ({required Object error}) => 'No se pudo enviar: ${error}',
			'speed.info' => 'Lo mide M-Lab, una plataforma abierta de investigación. Cada test usa entre 50 y 100 MB aproximadamente.\n\nResultados públicos: M-Lab publica cada test, incluida la dirección IP de origen, como datos abiertos de investigación.\n\nComparación de proveedores: tras un test sin VPN, G VPN solo envía las tres velocidades. El servicio de comparación lee tu proveedor y tu ciudad a partir de la propia conexión y no guarda ninguna dirección IP. Desactívalo con el interruptor al final de esta página.\n\nA través de la VPN: con la VPN activa, mide la velocidad por el túnel y la compara con tu último test sin ella.\n\nVista previa de vídeo: la misma imagen a la resolución que permite esta velocidad, según las tasas de bits que publican los servicios de streaming. No se descarga ningún vídeo.',
			'speed.download' => 'Descarga',
			'speed.upload' => 'Subida',
			'speed.finding' => 'Buscando un servidor',
			'speed.throughVpn' => 'A través de la VPN',
			'speed.directNoVpn' => 'Directa, sin VPN',
			'speed.title' => 'Test de velocidad',
			'speed.stop' => 'Detener',
			'speed.start' => 'Iniciar test',
			'speed.again' => 'Repetir test',
			'speed.viaVpn' => 'Con VPN',
			'speed.direct' => 'Directa',
			'speed.mbps' => 'Mbps',
			'speed.ping' => 'PING',
			'speed.vsDirect' => 'VS DIRECTA',
			'speed.compare' => 'Comparar con proveedores cercanos',
			'speed.compareSub' => 'Solo comparte velocidades, nunca tu IP',
			'speed.tierTv' => 'Televisores grandes',
			'speed.tierLaptopLarge' => 'Portátiles grandes',
			'speed.tierTablet' => 'Tabletas y portátiles',
			'speed.tierPhone' => 'Teléfonos',
			'speed.tierSmallPhone' => 'Teléfonos pequeños',
			'speed.tierCalls' => 'Llamadas y audio',
			'speed.messagingOnly' => 'Solo mensajería',
			'speed.videoQuality' => 'Calidad de vídeo',
			'speed.preview' => 'VISTA PREVIA',
			'speed.history' => 'Historial',
			'speed.clear' => 'Borrar',
			'speed.viaVpnLower' => 'con VPN',
			'speed.directLower' => 'directa',
			'speed.gradeA' => 'Varios streams 4K y videollamadas a la vez',
			'speed.gradeB' => 'Streaming HD y videollamadas fluidas',
			'speed.gradeC' => 'Un stream HD; las llamadas pueden cortarse en horas punta',
			'speed.gradeD' => 'Navegar y mensajería; el vídeo va justo',
			'speed.yourCountry' => 'tu país',
			'speed.median' => 'Descarga mediana, últimos 30 días',
			'speed.fromUsers' => 'Mbps · de tests de usuarios de G VPN',
			'speed.costLittle' => 'La VPN apenas reduce la velocidad',
			'speed.costNoticeable' => 'Notablemente más lenta que directa',
			'speed.costMuch' => 'Mucho más lenta. Prueba otro servidor',
			'speed.ofDirect' => 'de tu velocidad directa',
			'speed.none' => 'ninguno',
			'speed.ms' => ({required Object n}) => '${n} ms',
			'speed.previewTier' => ({required Object tier}) => 'VISTA PREVIA · ${tier}',
			'speed.streamsUpTo' => ({required Object tier, required Object who}) => 'Streaming hasta ${tier} · ${who}',
			'speed.today' => ({required Object time}) => 'Hoy, ${time}',
			'speed.tests' => ({required Object n}) => '${n} tests',
			'speed.gradeVpn' => ({required Object label}) => '${label} a través de la VPN',
			'speed.gradeIsp' => ({required Object label, required Object isp}) => '${label} con ${isp}',
			'speed.notEnough' => ({required Object isp}) => 'Aún no hay suficientes tests de ${isp}',
			'speed.yourProvider' => 'tu proveedor',
			'speed.rankLine' => ({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} en ${where}: ${rank} de ${of}',
			'speed.costLine' => ({required Object note, required Object mbps}) => '${note} · directa ${mbps} Mbps',
			'speed.mbpsValue' => ({required Object v}) => '${v} Mbps',
			'speed.gradeExcellent' => 'Excelente',
			'speed.gradeVeryGood' => 'Muy buena',
			'speed.gradeGood' => 'Buena',
			'speed.gradeFair' => 'Aceptable',
			'speed.gradeSlow' => 'Lenta',
			'speed.gradeVerySlow' => 'Muy lenta',
			'router.info' => 'Pregunta a tu router, mediante UPnP, si los dispositivos pueden abrir puertos a internet por su cuenta, y muestra los que han abierto. Solo lee y no cambia nada. Si nada necesita UPnP (algunas consolas sí), es más seguro desactivarlo en los ajustes del router.',
			'router.title' => 'Revisión del router',
			'router.asking' => 'Consultando al router',
			'router.again' => 'Revisar de nuevo',
			'router.check' => 'Revisar router',
			'router.off' => 'UPnP desactivado',
			'router.offBody' => 'Los dispositivos no pueden abrir puertos por su cuenta.',
			'router.onBody' => 'Ahora mismo no hay puertos abiertos por UPnP.',
			'router.checkEach' => 'Comprueba que reconoces cada uno.',
			'router.cgnat' => 'Dirección compartida del proveedor: no es accesible desde internet.',
			'router.noDescription' => 'Sin descripción',
			'router.opened' => ({required Object n}) => '${n} puertos abiertos por dispositivos',
			'router.routerName' => ({required Object name}) => 'Router: ${name}',
			'router.externalIp' => ({required Object ip}) => 'Dirección de internet: ${ip}',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} hacia ${host}',
			'router.upnpOn' => 'UPnP activado',
			'network.title' => 'Esta red',
			'network.wifi' => 'Wi-Fi',
			'network.mobile' => 'Datos móviles',
			'network.ethernet' => 'Ethernet',
			'network.offline' => 'Sin conexión',
			'network.risky' => 'Red de riesgo. Conecta la VPN aquí.',
			'network.review' => 'Conviene revisarla antes de confiar.',
			'network.covered' => 'Protegida por la VPN.',
			'network.safe' => 'Esta red parece segura.',
			'network.mobileSentence' => 'Datos móviles.',
			'network.notConnected' => 'Sin conexión.',
			'network.showName' => 'Mostrar nombre',
			'network.sitesSee' => 'Los sitios ven',
			'network.provider' => 'Proveedor',
			'network.location' => 'Ubicación',
			'network.couldNotCheck' => 'No se pudo comprobar',
			'network.checking' => 'Comprobando',
			'network.signal' => 'Señal',
			'network.linkSpeed' => 'Velocidad de enlace',
			'network.gateway' => 'Puerta de enlace',
			'network.none' => 'Ninguna',
			'network.privateDns' => 'DNS privado',
			'network.automatic' => 'Automático',
			'network.off' => 'Desactivado',
			'network.metered' => 'Con límite de datos',
			'network.yes' => 'Sí',
			'network.no' => 'No',
			'network.readFailed' => ({required Object error}) => 'No se pudo leer la red: ${error}',
			'devices.info' => 'Llama a cada dirección del rango de tu Wi-Fi y pide a los dispositivos que se identifiquen. Un dispositivo que rechaza también cuenta: el rechazo demuestra que está ahí.\n\nNombres: de lo que publican los dispositivos (Bonjour, UPnP, nombres de Windows) y de tu router.\n\nDispositivos desconocidos: Android oculta las direcciones de hardware a las apps, así que un dispositivo silencioso sin nombre no se puede identificar. Búscalos en la lista de dispositivos de tu router.\n\nNuevo: un dispositivo que no apareció en tu último análisis de esta red.',
			'devices.needWifi' => 'Conéctate primero a una red Wi-Fi.',
			'devices.title' => 'Dispositivos',
			'devices.again' => 'Analizar de nuevo',
			'devices.looking' => 'Buscando dispositivos',
			'devices.nothingNew' => 'Nada nuevo desde el último análisis',
			'devices.takes' => 'Tarda unos 30 segundos',
			'devices.all' => 'Todos',
			'devices.phones' => 'Teléfonos',
			'devices.tvs' => 'Televisores',
			'devices.computers' => 'Ordenadores',
			'devices.other' => 'Otros',
			'devices.thisPhone' => 'Este teléfono',
			'devices.router' => 'Router',
			'devices.unknown' => 'Dispositivo desconocido',
			'devices.address' => 'Dirección',
			'devices.answersIn' => 'Responde en',
			'devices.type' => 'Tipo',
			'devices.notAnnounced' => 'No se identificó. La lista de dispositivos de tu router puede darle nombre.',
			'devices.newBadge' => 'NUEVO',
			'devices.scanning' => ({required Object n}) => 'Analizando ${n} de 254',
			'devices.thisNetwork' => 'esta red',
			'devices.newSince' => ({required Object n}) => '${n} nuevos desde el último análisis',
			'devices.showMore' => ({required Object n}) => 'Mostrar ${n} más',
			'devices.ms' => ({required Object n}) => '${n} ms',
			'devices.onNetwork' => ({required Object network}) => 'dispositivos en ${network}',
			'ping.info' => 'Cuánto tarda un viaje de ida y vuelta a un servidor, medido cada segundo durante el último minuto.\n\nJitter: cuánto varía cada respuesta respecto a la anterior. Un jitter alto es lo que corta las llamadas.\n\nPérdida: respuestas que nunca volvieron.\n\nCómo: las apps de Android no pueden enviar pings clásicos, así que cada sondeo mide un saludo de conexión, que es el mismo viaje de ida y vuelta.',
			'ping.askTitle' => 'Hacer ping a un host',
			'ping.askHint' => 'example.com o 192.168.1.10',
			'ping.cancel' => 'Cancelar',
			'ping.title' => 'Ping',
			'ping.router' => 'Router',
			'ping.pause' => 'Pausar',
			'ping.start' => 'Iniciar',
			'ping.host' => 'Host',
			'ping.live' => 'En vivo',
			'ping.ago' => 'hace 60 s',
			'ping.min' => 'MÍN',
			'ping.avg' => 'MEDIA',
			'ping.jitter' => 'JITTER',
			'ping.loss' => 'PÉRDIDA',
			'ping.goodFor' => 'Suficiente para',
			'ping.calls' => 'Videollamadas',
			'ping.games' => 'Juegos online',
			'ping.streaming' => 'Streaming',
			'ping.great' => 'Genial',
			'ping.okay' => 'Aceptable',
			'ping.poor' => 'Mala',
			'ping.lost' => 'perdido',
			'ping.now' => 'ahora',
			'status.info' => 'Se conecta a cada servicio tres veces y muestra la respuesta más rápida.\n\nBloqueado aquí: un servicio que no responde directamente pero funciona a través de la VPN está bloqueado por tu red o tu país.\n\nHistorial: las comprobaciones de las últimas 24 horas desde este teléfono, guardadas solo en él.',
			'status.title' => 'Estado de servicios',
			'status.checking' => 'Comprobando',
			'status.again' => 'Comprobar de nuevo',
			'status.viaVpn' => 'Comprobado a través de la VPN',
			'status.direct' => 'Comprobado directamente',
			'status.favourites' => 'Favoritos',
			'status.edit' => 'Editar',
			'status.last24' => 'Últimas 24 horas',
			'status.ago' => 'hace 24 h',
			'status.all' => 'Todos los servicios',
			'status.pickFour' => 'Elige hasta cuatro',
			'status.outage' => 'Ni con la VPN: probablemente una caída',
			'status.blocked' => 'Puede estar bloqueado en esta red',
			'status.connect' => 'Conectar',
			'status.blockedShort' => 'Bloqueado',
			'status.unreachable' => 'Inaccesible',
			'status.now' => 'ahora',
			'status.checks' => ({required Object n}) => '${n} comprobaciones',
			'status.andMore' => ({required Object first, required Object n}) => '${first} y ${n} más',
			'status.notReachable' => ({required Object who}) => '${who} no responde',
			'tools.wifi' => 'Wi-Fi',
			'tools.mobile' => 'Datos móviles',
			'tools.ethernet' => 'Ethernet',
			'tools.checking' => 'Comprobando',
			'tools.offline' => 'Sin conexión',
			'tools.title' => 'Herramientas',
			'tools.networkDesc' => 'Revisión de seguridad, lo que ven los sitios, señal, router y DNS.',
			'tools.internet' => 'Conexión a internet',
			'tools.speed' => 'Test de velocidad',
			'tools.speedDesc' => 'Velocidad de descarga y subida, y la calidad de vídeo que admite.',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'Tiempo de respuesta y jitter en vivo hacia cualquier servidor o tu router.',
			'tools.status' => 'Estado de servicios',
			'tools.statusDesc' => '¿Se puede acceder a WhatsApp, YouTube o Google desde aquí, o están bloqueados?',
			'tools.trace' => 'Traceroute',
			'tools.traceDesc' => 'Cada router entre tú y un sitio, y cuánto tarda cada uno.',
			'tools.security' => 'Seguridad de la red',
			'tools.devices' => 'Dispositivos en esta red',
			'tools.devicesDesc' => 'Quién más está en tu Wi-Fi: teléfonos, televisores, cámaras y ordenadores.',
			'tools.router' => 'Revisión del router',
			'tools.routerDesc' => 'Si los dispositivos pueden abrir puertos en tu router por su cuenta (UPnP).',
			'tools.ports' => 'Puertos abiertos',
			'tools.portsDesc' => 'Revisa tu router o un servidor en busca de puertos abiertos peligrosos.',
			'tools.utilities' => 'Utilidades',
			'tools.wifiScanner' => 'Escáner de Wi-Fi',
			'tools.wifiDesc' => 'Redes cercanas, su seguridad y el canal menos saturado.',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Enciende un ordenador o NAS de esta red.',
			'trace.info' => 'Cada parada es un router por el que pasa tu tráfico de camino al sitio.\n\nSaltos silenciosos: muchos routers nunca responden a estos sondeos. Es normal y no es un fallo.\n\nCon la VPN activa: la ruta empieza dentro del túnel, así que tu red y tu proveedor quedan ocultos.\n\nCómo: usa la herramienta ping de Android con un límite de saltos, ya que las apps no pueden enviar estos paquetes directamente.',
			'trace.title' => 'Traceroute',
			'trace.stop' => 'Detener',
			'trace.trace' => 'Trazar',
			'trace.again' => 'Trazar de nuevo',
			'trace.destination' => 'Destino',
			'trace.hops' => 'SALTOS',
			'trace.answered' => 'RESPONDIERON',
			'trace.total' => 'TOTAL',
			'trace.thisPhone' => 'Este teléfono',
			'trace.silentOne' => '1 salto silencioso',
			'trace.yourRouter' => 'Tu router',
			'trace.ms' => ({required Object n}) => '${n} ms',
			'trace.silentMany' => ({required Object n}) => '${n} saltos silenciosos',
			'trace.hop' => ({required Object n}) => 'Salto ${n}',
			'trace.slowest' => ({required Object ms, required Object hop}) => 'La mayor parte del retraso, ${ms} ms, se añade en el salto ${hop}: suele ser un cable largo entre países o un enlace saturado.',
			'ports.ftpNote' => 'Envía contraseñas sin cifrar.',
			'ports.sshNote' => 'Acceso remoto. Bien si lo configuraste tú.',
			'ports.telnetNote' => 'Acceso remoto sin cifrar; favorito de las botnets.',
			'ports.dnsNote' => 'Normal en un router.',
			'ports.web' => 'Web (HTTP)',
			'ports.webNote' => 'Suele ser la página de administración del router.',
			'ports.webTls' => 'Web (HTTPS)',
			'ports.smb' => 'Compartir archivos de Windows',
			'ports.smbNote' => 'Nunca debería estar expuesto a internet.',
			'ports.rtsp' => 'Transmisión de cámara RTSP',
			'ports.rtspNote' => 'Puede haber una cámara transmitiendo aquí.',
			'ports.upnpNote' => 'Permite a los dispositivos abrir puertos del router por su cuenta.',
			'ports.rdp' => 'Escritorio remoto',
			'ports.rdpNote' => 'Una vía de intrusión habitual.',
			'ports.vncNote' => 'Pantalla compartida, a menudo sin contraseña.',
			'ports.tr069Note' => 'Gestión remota del proveedor.',
			'ports.webAlt' => 'Web (alternativo)',
			'ports.webAltTls' => 'Web (HTTPS alternativo)',
			'ports.title' => 'Puertos abiertos',
			'ports.check' => 'Revisar puertos',
			'ports.address' => 'Dirección del dispositivo o servidor',
			'ports.risky' => 'RIESGO',
			'ports.review' => 'REVISAR',
			_ => null,
		} ?? switch (path) {
			'ports.normal' => 'NORMAL',
			'ports.info' => ({required Object n}) => 'Revisa los ${n} puertos que importan en routers y dispositivos domésticos, y explica cada uno que esté abierto.\n\nRevisa solo dispositivos y servidores que sean tuyos o que administres.',
			'ports.checking' => ({required Object n}) => 'Revisando ${n} puertos',
			'ports.yourRouter' => ({required Object ip}) => 'Tu router es ${ip}',
			'ports.noneOpen' => ({required Object host}) => 'No hay puertos habituales abiertos en ${host}.',
			'wifi.title' => 'Escáner de Wi-Fi',
			'wifi.allow' => 'Permitir análisis de Wi-Fi',
			'wifi.needsPermission' => 'Necesita permiso de ubicación.',
			'wifi.scanning' => 'Analizando',
			'wifi.again' => 'Analizar de nuevo',
			'wifi.failed' => 'El análisis falló',
			'wifi.none' => 'No se encontraron redes. Puede que la ubicación esté desactivada.',
			'wifi.hidden' => 'Red oculta',
			'wifi.nearby' => ({required Object n}) => '${n} redes cercanas',
			'wifi.bestChannel' => ({required Object n}) => 'Canal de 2,4 GHz menos saturado: ${n}',
			'wifi.weak' => ({required Object n}) => '${n} abiertas o débiles',
			'wifi.connectedPrefix' => 'Conectada · ',
			'wifi.permissionInfo' => 'Android solo muestra las redes Wi-Fi cercanas a las apps con permiso de ubicación. G VPN lo usa únicamente para listar redes en este teléfono.',
			'wifi.info' => 'Muestra las redes del último análisis del teléfono. Android solo permite unos pocos análisis por minuto, así que repetir rápido puede mostrar la misma lista. El canal sugerido es el menos saturado entre 1, 6 y 11, los tres que no se solapan.',
			'errors.notAuthorized' => 'No se concedió el permiso de VPN.',
			'errors.turnedOff' => 'El sistema u otra app desactivó la VPN.',
			'errors.busy' => 'Ya hay una solicitud de permiso abierta.',
			'errors.cancelled' => 'Conexión cancelada.',
			'errors.badConfig' => ({required Object error}) => 'La configuración de este servidor no es válida: ${error}',
			'errors.timeout' => 'El servidor no respondió.',
			'errors.refused' => 'El servidor rechazó la conexión.',
			'errors.failed' => ({required Object error}) => 'No se pudo conectar: ${error}',
			'errors.tryAnother' => 'Los servidores gratuitos van y vienen; prueba con otro.',
			'errors.downloadFailed' => 'No se pudieron descargar los ajustes de este servidor. Revisa tu conexión o elige otro servidor.',
			'scan.mobile' => 'Datos móviles',
			'scan.ping' => 'PING',
			'scan.noReply' => 'Sin respuesta',
			'scan.dns' => 'DNS',
			'scan.dnsQuad9' => 'Quad9, túnel',
			'scan.dnsTunnel' => 'En el túnel',
			'scan.privateDns' => 'DNS privado',
			'scan.dnsIsp' => 'Proveedor, visible',
			'scan.network' => 'RED',
			'scan.offline' => 'Sin conexión',
			'scan.open' => 'Abierta, sin contraseña',
			'scan.wep' => 'WEP, insegura',
			'scan.owe' => 'Abierta, cifrada',
			'scan.enterprise' => 'Empresarial',
			'scan.unknown' => 'Desconocida',
			'scan.wifi' => 'WI-FI',
			'scan.signIn' => 'Página de acceso',
			'scan.ms' => ({required Object n}) => '${n} ms',
			'scan.covered' => ({required Object what}) => '${what}, protegida',
			'legal.privacy' => 'Política de privacidad',
			'legal.terms' => 'Condiciones de uso',
			'legal.licences' => 'Licencias de código abierto',
			'update.ready' => 'Hay una actualización lista',
			'update.restart' => 'Reiniciar',
			'details.share' => 'Compartir',
			'details.connectedFor' => ({required Object n}) => 'CONECTADO · ${n} MIN',
			'details.notConnected' => 'SIN CONECTAR',
			'details.downloaded' => 'DESCARGADO',
			'details.uploaded' => 'SUBIDO',
			'details.lastUsed' => 'ÚLTIMO USO',
			'details.connection' => 'Conexión',
			'details.protocol' => 'Protocolo',
			'details.address' => 'Tu dirección',
			'details.dns' => 'DNS',
			'details.routes' => 'Rutas',
			'details.allTraffic' => 'Todo el tráfico',
			'details.someRoutes' => ({required Object n}) => '${n} redes',
			'details.keepalive' => 'Keepalive',
			'details.serverKey' => 'Clave del servidor',
			'details.copy' => 'Copiar',
			'details.copied' => 'Copiado',
			'details.manage' => 'Gestionar',
			'details.export' => 'Exportar copia de seguridad',
			'details.exportSub' => 'Todos tus servidores en un archivo',
			'share.title' => ({required Object name}) => 'Compartir ${name}',
			'share.sameKey' => 'Esto comparte la clave de este teléfono. Cualquiera que la tenga puede usar tu servidor como tú, y solo un dispositivo puede estar conectado con ella a la vez.',
			'share.scanHint' => 'En el otro teléfono: G VPN, Servidores, Escanear QR. También sirve una imagen guardada.',
			'share.saveImage' => 'Guardar imagen',
			'share.send' => 'Enviar',
			'add.title' => 'Añadir un servidor',
			'add.subtitle' => 'Cualquier servidor WireGuard: un router, un VPS o un servidor en casa.',
			'add.camera' => 'Escanear con la cámara',
			'add.cameraSub' => 'QR en otra pantalla',
			'add.image' => 'Desde una imagen',
			'add.imageSub' => 'Captura o foto guardada',
			'add.noQr' => 'No hay ningún código QR en esa imagen.',
			'add.tip' => '¿Te llegó el QR por WhatsApp o Telegram? Toca Compartir en la imagen y elige G VPN.',
			'backup.restored' => ({required Object n}) => '${n} servidores restaurados',
			'backup.nothingNew' => 'Estos servidores ya están aquí',
			'gs.proRequired' => 'G Servers son para suscriptores de G VPN Pro.',
			'gs.off' => 'G Servers están desactivados ahora.',
			'gs.network' => 'No se pudo contactar con G Servers. Revisa tu conexión e inténtalo de nuevo.',
			'gs.active' => 'ACTIVO',
			'gs.servers' => 'G Servers',
			'gs.busy' => ({required Object n}) => '${n}% ocupado',
			'gs.offline' => 'Sin conexión',
			'gs.devices' => 'Tus dispositivos',
			'gs.devicesSub' => ({required Object n}) => 'Hasta ${n} teléfonos, cada uno con su clave',
			'gs.footnote' => 'Cada teléfono tiene su propia clave, creada en el teléfono. G Servers no guardan registros de actividad.',
			'gs.leastBusy' => 'EL MENOS OCUPADO AHORA',
			'gs.busyNoLogs' => ({required Object n}) => '${n}% ocupado · sin registros',
			'gs.subtitle' => ({required Object country}) => 'G Server · ${country} · WireGuard',
			'gs.busyLabel' => 'OCUPADO',
			'gs.status' => 'ESTADO',
			'gs.online' => 'En línea',
			'gs.onThisServer' => 'En este servidor',
			'gs.thisPhone' => 'Este teléfono',
			'gs.added' => 'Añadido · clave creada aquí',
			'gs.notAdded' => 'Se añade al conectar',
			'gs.logs' => 'Registros de actividad',
			'gs.noneKept' => 'No se guardan',
			'gs.privacy' => 'El servidor solo conoce este teléfono por su clave pública. No registra los sitios que visitas ni el tráfico que envías.',
			'gs.stepPro1' => 'Instala G VPN en el teléfono con la misma cuenta de Google.',
			'gs.stepPro2' => 'Abre la pestaña Pro. Pro se activa solo, o toca Restaurar.',
			'gs.step3' => 'Toca Conectar. El teléfono crea su clave y se añade a G Servers. Sin QR ni códigos.',
			'gs.stepFree1' => 'Instala G VPN en el teléfono.',
			'gs.stepFree2' => 'Abre la pestaña Pro.',
			'gs.devicesIntroPro' => 'Pro va con tu cuenta de Google. Cada teléfono tiene su clave, así que nunca se desconectan entre sí.',
			'gs.devicesIntroFree' => 'Cada teléfono tiene su clave, así que nunca se desconectan entre sí.',
			'gs.otherPhone' => 'Otro teléfono',
			'gs.lastConnected' => ({required Object when}) => 'Última conexión ${when}',
			'gs.noDevices' => 'Conéctate una vez a un G Server y tus teléfonos aparecerán aquí.',
			'gs.addTitle' => 'Añadir un teléfono o reinstalar',
			'gs.idle' => ({required Object n}) => 'Un teléfono que no se conecta en ${n} días se quita de G Servers solo, así que un teléfono viejo o reinstalado nunca ocupa un hueco.',
			'gs.limitNote' => ({required Object n}) => 'Hasta ${n} teléfonos por plan.',
			'gs.fullTitle' => ({required Object n}) => 'Los ${n} huecos están en uso',
			'gs.fullBody' => 'Quita un teléfono que ya no uses y este se conectará al momento.',
			'gs.busyNow' => 'Demasiados teléfonos nuevos ahora mismo. Inténtalo de nuevo en un rato.',
			'gs.serverFull' => 'Este servidor está lleno. Prueba otro G Server.',
			'gs.ping' => 'PING',
			'gs.last24' => 'Ocupación, últimas 24 horas',
			'gs.noHistory' => 'El gráfico se llena a medida que el servidor se usa durante el día.',
			'gs.chartLabel' => ({required Object max}) => 'Ocupación en las últimas 24 horas, como máximo ${max} por ciento',
			'gs.hoursAgo' => 'hace 24 h',
			'gs.now' => 'Ahora',
			_ => null,
		};
	}
}
