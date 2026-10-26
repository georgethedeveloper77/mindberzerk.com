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
	@override late final _Translations$map$es map = _Translations$map$es._(_root);
	@override late final _Translations$stats$es stats = _Translations$stats$es._(_root);
	@override late final _Translations$recents$es recents = _Translations$recents$es._(_root);
	@override late final _Translations$presets$es presets = _Translations$presets$es._(_root);
	@override late final _Translations$shield$es shield = _Translations$shield$es._(_root);
	@override late final _Translations$checks$es checks = _Translations$checks$es._(_root);
	@override late final _Translations$toolSettings$es toolSettings = _Translations$toolSettings$es._(_root);
	@override late final _Translations$security$es security = _Translations$security$es._(_root);
	@override late final _Translations$providers$es providers = _Translations$providers$es._(_root);
	@override late final _Translations$alerts$es alerts = _Translations$alerts$es._(_root);
	@override late final _Translations$report$es report = _Translations$report$es._(_root);
	@override late final _Translations$breaches$es breaches = _Translations$breaches$es._(_root);
	@override late final _Translations$blocked$es blocked = _Translations$blocked$es._(_root);
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
	@override String get ipFailed => 'No se pudo comprobar tu IP';
	@override String get ipChecking => 'Comprobando tu IP';
	@override String get themeSystem => 'Tema: según el teléfono';
	@override String get themeLight => 'Tema: claro';
	@override String get themeDark => 'Tema: oscuro';
	@override String get free => 'Gratis';
	@override String get pickServer => 'Elige un servidor';
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
	@override String get gTab => 'G Servers';
	@override String get search => 'Buscar países';
	@override String get noMatch => 'Ningún servidor coincide.';
	@override String bestPing({required Object ms}) => 'mejor ${ms} ms';
	@override String get bestTag => 'MEJOR';
	@override String get ownHero => 'Nuestros servidores';
	@override String get ownHeroSub => 'Más rápidos, privados, cada teléfono con su clave';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} servidor',
		other: '${n} servidores',
	);
	@override String showAll({required Object n}) => 'Ver los ${n}';
	@override String get showFewer => 'Ver menos';
	@override String get fastTab => 'Rápidos';
	@override String get fastestFree => 'Gratis más rápidos';
}

// Path: pro
class _Translations$pro$es extends Translations$pro$en {
	_Translations$pro$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get owned => 'Tienes Pro';
	@override String get waitingPlay => 'Esperando a Google Play';
	@override String startTrial({required Object days}) => 'Empezar prueba gratis de ${days} días';
	@override String get restore => 'Restaurar';
	@override String save({required Object pct}) => 'AHORRA ${pct}%';
	@override String get yearly => 'Anual';
	@override String get monthly => 'Mensual';
	@override String get billedMonthly => 'facturado cada mes';
	@override String daysFree({required Object days}) => '${days} días gratis';
	@override String perMonth({required Object price}) => '${price} al mes';
	@override String get title => 'G VPN Pro';
	@override String get renewGeneric => 'Las suscripciones se renuevan automáticamente hasta que las canceles. Cancela cuando quieras en Google Play.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} días gratis, después ${price} por ${period}. Se renueva automáticamente hasta que canceles; cancela en Google Play al menos un día antes de que termine la prueba para que no te cobren.';
	@override String renew({required Object price, required Object period}) => '${price} por ${period}. Se renueva automáticamente hasta que canceles; cancela cuando quieras en Google Play.';
	@override String get year => 'año';
	@override String get month => 'mes';
	@override String get manage => 'Gestionar suscripción';
	@override late final _Translations$pro$free$es free = _Translations$pro$free$es._(_root);
	@override String get heroLine => 'Nuestros propios servidores rápidos, y cada comprobación ilimitada';
	@override String get start => 'Empezar Pro';
	@override String get compareFree => 'GRATIS';
	@override String get comparePro => 'PRO';
	@override String get rowFreeServers => 'Servidores gratis';
	@override String get rowTools => 'Velocidad, herramientas, Wi-Fi';
	@override String get rowGServers => 'G Servers, sin registros';
	@override String get rowLinks => 'Comprobación de enlaces';
	@override String linksFree({required Object n}) => '${n} al mes';
	@override String get unlimited => 'Ilimitada';
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
	@override String get mac => 'Dirección MAC';
	@override String failed({required Object error}) => 'No se pudo enviar: ${error}';
	@override String get computer => 'Ordenador';
	@override String get pick => 'Elige un dispositivo para encender';
	@override String waking({required Object name}) => 'Encendiendo ${name}';
	@override String get yours => 'TUS DISPOSITIVOS';
	@override String wakeNamed({required Object name}) => 'Encender ${name}';
	@override String get removeHint => 'Mantén pulsado un dispositivo para quitarlo';
	@override String get add => 'AÑADIR UN DISPOSITIVO';
	@override String get name => 'Nombre';
	@override String get saveWake => 'Guardar y encender';
}

// Path: speed
class _Translations$speed$es extends Translations$speed$en {
	_Translations$speed$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
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
	@override String mapping({required Object proto, required Object host}) => '${proto} hacia ${host}';
	@override String get upnpOn => 'UPnP activado';
	@override String get routerLabel => 'Router';
	@override String get internetAddress => 'Dirección de internet';
	@override String get openedBy => 'Abiertos por dispositivos';
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
	@override String get newBadge => 'NUEVO';
	@override String scanning({required Object n}) => 'Analizando ${n} de 254';
	@override String newSince({required Object n}) => '${n} nuevos desde el último análisis';
	@override String ms({required Object n}) => '${n} ms';
	@override String get cameras => 'Cámaras';
	@override String get device => 'Dispositivo';
	@override String get online => 'En línea';
	@override String get model => 'Modelo';
	@override String get announced => 'Se anuncia como';
	@override String get services => 'SERVICIOS ABIERTOS';
	@override String get checkingServices => 'Comprobando servicios';
	@override String get noServices => 'Ningún servicio común responde';
	@override String get rename => 'Renombrar';
	@override String get save => 'Guardar';
	@override late final _Translations$devices$kinds$es kinds = _Translations$devices$kinds$es._(_root);
	@override String get details => 'Detalles de la red';
	@override String get listView => 'Lista';
	@override String get meshView => 'Malla';
	@override String get offlineHeading => 'Desconectados';
	@override String seen({required Object when}) => 'Visto ${when}';
	@override String agoMinutes({required Object n}) => 'hace ${n} min';
	@override String agoHours({required Object n}) => 'hace ${n} h';
	@override String agoDays({required Object n}) => 'hace ${n} d';
	@override String get throughVpn => 'Por la VPN';
	@override String get closer => 'Más cerca = responde más rápido';
	@override String get yours => '¿Es tuyo?';
	@override String get mine => 'Mío';
	@override String get notMine => 'No es mío';
	@override String get whatIsIt => '¿Qué es?';
	@override String ourGuess({required Object kind}) => 'Creemos que es: ${kind}';
	@override String get groupPersonal => 'Teléfonos y ordenadores';
	@override String get groupHome => 'Hogar y multimedia';
	@override String get groupNetwork => 'Red y hogar inteligente';
	@override String onlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} conectado',
		other: '${n} conectados',
	);
	@override String offlineCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} desconectado',
		other: '${n} desconectados',
	);
	@override String toConfirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} por confirmar',
		other: '${n} por confirmar',
	);
}

// Path: ping
class _Translations$ping$es extends Translations$ping$en {
	_Translations$ping$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get askTitle => 'Hacer ping a un host';
	@override String get askHint => 'example.com o 192.168.1.10';
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
	@override String get internet => 'Internet';
	@override String get speed => 'Test de velocidad';
	@override String get speedDesc => 'Bajada, subida y calidad de video';
	@override String get ping => 'Ping';
	@override String get pingDesc => 'Respuesta y variación en vivo';
	@override String get status => 'Estado de servicios';
	@override String get statusDesc => '¿Una app funciona o está bloqueada aquí?';
	@override String get trace => 'Traceroute';
	@override String get traceDesc => 'Cada parada hasta un sitio';
	@override String get security => 'Esta red';
	@override String get devices => 'Dispositivos en esta red';
	@override String get devicesDesc => 'Quién está en tu Wi-Fi';
	@override String get router => 'Revisión del router';
	@override String get routerDesc => 'Puertos que abrieron tus dispositivos';
	@override String get ports => 'Puertos abiertos';
	@override String get portsDesc => 'Puertos riesgosos en un dispositivo o servidor';
	@override String get utilities => 'Utilidades';
	@override String get wifiScanner => 'Escáner de Wi-Fi';
	@override String get wifiDesc => 'Redes a tu alrededor y el canal más libre';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'Enciende un ordenador de esta red';
	@override String get passwordCheck => 'Comprobar contraseña';
	@override String get passwordCheckDesc => '¿Se ha filtrado?';
	@override String get linkCheck => 'Comprobar enlace';
	@override String get linkCheckDesc => '¿Es seguro abrirlo?';
	@override String get breaches => 'Filtraciones';
	@override String get breachesDesc => 'Qué se ha filtrado últimamente';
	@override String get blocked => 'Qué está bloqueado';
	@override String get blockedDesc => 'Sitios bloqueados en esta red';
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
	@override String get popular => 'POPULARES';
	@override String get recent => 'RECIENTES';
	@override String get clearRecent => 'Borrar recientes';
	@override String hopsCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} salto',
		other: '${n} saltos',
	);
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
	@override String summary({required Object open, required Object n}) => '${open} abiertos de ${n} comprobados';
	@override String riskyCount({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} riesgoso',
		other: '${n} riesgosos',
	);
	@override String get noneRisky => 'Nada riesgoso';
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
	@override String get permissionInfo => 'Android solo muestra las redes Wi-Fi cercanas a las apps con permiso de ubicación. G VPN lo usa únicamente para listar redes en este teléfono.';
	@override String get info => 'Muestra las redes del último análisis del teléfono. Android solo permite unos pocos análisis por minuto, así que repetir rápido puede mostrar la misma lista. El canal sugerido es el menos saturado entre 1, 6 y 11, los tres que no se solapan.';
	@override String get airMap => 'Mapa del aire';
	@override String get channels => 'Canales';
	@override String get list => 'Lista';
	@override String get secure => 'Segura';
	@override String get weakLabel => 'Débil';
	@override String get openLabel => 'Abierta';
	@override String get sizeIsWidth => 'Tamaño = ancho de canal';
	@override String get strongest => 'LA MÁS FUERTE';
	@override String get openNearby => 'ABIERTAS CERCA';
	@override String get onYourChannel => 'EN TU CANAL';
	@override String get noneNearby => 'Ninguna';
	@override String get verdictOpen => 'Cualquiera cerca puede leer lo que se envía';
	@override String get verdictWep => 'Seguridad antigua, fácil de romper';
	@override String get verdictWpa => 'Seguridad antigua';
	@override String get verdictWps => 'WPS activado: más fácil de vulnerar';
	@override String get verdictGood => 'Bien protegida';
	@override String get maker => 'Fabricante';
	@override String get address => 'Dirección física';
	@override String get privateAddress => 'Inventada por el router por privacidad';
	@override String get you => 'Tú';
	@override String onClear({required Object name}) => '${name} está en un canal libre';
	@override String move({required Object name, required Object n}) => 'Mueve ${name} al canal ${n}';
	@override String get clear => 'Libre';
	@override String get busy => 'Ocupado';
	@override String get crowded => 'Saturado';
	@override String get allBands => 'Todas las bandas';
	@override String get openOnly => 'Solo abiertas';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} red',
		other: '${n} redes',
	);
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
	@override String get included => 'Incluido';
	@override String get perkServers => 'Servidores rápidos y privados';
	@override String get perkServersSub => 'WireGuard, gestionados por nosotros, sin registros';
	@override String get perkLinks => 'Comprobación de enlaces ilimitada';
	@override String get perkLinksSub => 'Comprueba cada enlace que te envíen';
	@override String devicesOf({required Object used, required Object limit}) => 'Tus dispositivos · ${used} de ${limit}';
	@override String get eachKey => 'Cada teléfono tiene su propia clave';
	@override String get connected => 'Conectado';
	@override String get bestNow => 'LO MEJOR PARA TI AHORA';
	@override String get logsShort => 'REGISTROS';
}

// Path: map
class _Translations$map$es extends Translations$map$en {
	_Translations$map$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get open => 'Abrir el mapa';
	@override String get searchCountries => 'Buscar países';
	@override String get noMatch => 'Ningún país coincide';
	@override String get locate => 'Mi ubicación';
	@override String get list => 'Lista';
	@override String get map => 'Mapa';
	@override String freeServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} servidor gratis',
		other: '${n} servidores gratis',
	);
	@override late final _Translations$map$grade$es grade = _Translations$map$grade$es._(_root);
	@override String get switchTo => 'Cambiar';
	@override String freeServer({required Object n}) => 'Servidor gratis ${n}';
	@override String get best => 'MEJOR';
	@override String gServers({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} G Server',
		other: '${n} G Servers',
	);
}

// Path: stats
class _Translations$stats$es extends Translations$stats$en {
	_Translations$stats$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get thisWeek => 'Esta semana';
	@override String get time => 'Tiempo';
	@override String get data => 'Datos';
	@override String get protected => 'protegido';
	@override String get throughVpn => 'por la VPN';
	@override String get seeDetails => 'Ver detalles';
	@override String get title => 'Estadísticas';
	@override String get week => 'Semana';
	@override String get month => 'Mes';
	@override String get protectedLabel => 'PROTEGIDO';
	@override String get dataUsed => 'DATOS USADOS';
	@override String get byServer => 'POR SERVIDOR';
	@override String get onPhone => 'Solo en este teléfono';
	@override String get reset => 'Restablecer';
	@override String get resetTitle => '¿Restablecer estadísticas?';
	@override String get resetBody => 'Borra el tiempo protegido y los datos de este teléfono. No se puede deshacer.';
	@override String hm({required Object h, required Object m}) => '${h} h ${m} min';
	@override String m({required Object m}) => '${m} min';
	@override String get empty => 'Conéctate para empezar a contar.';
}

// Path: recents
class _Translations$recents$es extends Translations$recents$en {
	_Translations$recents$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Recientes';
	@override String get allServers => 'Todos los servidores';
	@override String get free => 'Servidor gratis';
	@override String get yours => 'Tu servidor';
	@override String get gserver => 'G Server';
}

// Path: presets
class _Translations$presets$es extends Translations$presets$en {
	_Translations$presets$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajustes rápidos';
	@override String get all => 'Todos';
	@override String get newPreset => 'Nuevo ajuste';
	@override String get edit => 'Editar ajuste';
	@override String get name => 'Nombre';
	@override String get namePlaceholder => 'Mi ajuste';
	@override String get server => 'SERVIDOR';
	@override String get fastestOption => 'El más rápido';
	@override String get countryOption => 'País';
	@override String get pickCountry => 'Elige un país';
	@override String get skipMyCountry => 'Evitar mi país';
	@override String get notMine => 'no mi país';
	@override String get protocol => 'PROTOCOLO';
	@override String get auto => 'Auto';
	@override String get tryNext => 'Si está bloqueado, probar el siguiente';
	@override String get shield => 'ESCUDO';
	@override String get followRules => 'Como en Reglas';
	@override String get allApps => 'Todas las apps por la VPN';
	@override String get allAppsShort => 'todas las apps';
	@override String get save => 'Guardar';
	@override String get delete => 'Eliminar';
	@override String get reset => 'Restablecer';
	@override String get none => 'Ahora no hay un servidor gratis para este ajuste.';
	@override late final _Translations$presets$names$es names = _Translations$presets$names$es._(_root);
}

// Path: shield
class _Translations$shield$es extends Translations$shield$en {
	_Translations$shield$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Escudo';
	@override String get sub => 'Funciona mientras estás conectado';
	@override String get off => 'Desactivado';
	@override String get offSub => 'El DNS del servidor';
	@override String get malware => 'Malware';
	@override String get malwareSub => 'Bloquea sitios dañinos y de phishing';
	@override String get family => 'Malware y sitios para adultos';
	@override String get familySub => 'También bloquea contenido para adultos';
	@override String get custom => 'DNS propio';
	@override String get customSub => 'Tus propios servidores DNS';
	@override String get customHint => 'Dirección IP, por ejemplo 1.1.1.1';
	@override String get invalid => 'Escribe una o dos direcciones IP.';
}

// Path: checks
class _Translations$checks$es extends Translations$checks$en {
	_Translations$checks$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Comprobaciones';
	@override String get password => 'Contraseña';
	@override String get link => 'Enlace';
	@override String get pwTitle => '¿Se filtró?';
	@override String get pwHint => 'Contraseña a comprobar';
	@override String get showPassword => 'Mostrar contraseña';
	@override String get hidePassword => 'Ocultar contraseña';
	@override String get check => 'Comprobar';
	@override String get leaked => 'Aparece en filtraciones';
	@override String seen({required Object n}) => 'Vista ${n} veces';
	@override String get leakedAdvice => 'Cámbiala en todos los sitios donde la uses, empezando por el correo y el banco.';
	@override String get notFound => 'No aparece en filtraciones conocidas';
	@override String get notFoundAdvice => 'Buena señal, no una garantía. Usa una contraseña distinta en cada cuenta.';
	@override String get failed => 'No se pudo comprobar. Inténtalo de nuevo.';
	@override String get private => 'Tu contraseña nunca sale de este teléfono';
	@override String get linkTitle => '¿Es seguro este enlace?';
	@override String get linkHint => 'Enlace a comprobar';
	@override String get paste => 'Pegar';
	@override String get danger => 'Enlace peligroso';
	@override String get dangerAdvice => 'No lo abras ni escribas ningún dato.';
	@override String get clear => 'No está en listas conocidas de malware o phishing';
	@override String get clearAdvice => 'Aun así, mira la dirección antes de iniciar sesión.';
	@override String get goesTo => 'Lleva a';
	@override String get redirects => 'Redirecciones';
	@override String get invalid => 'Eso no parece una dirección web.';
	@override String get busy => 'Demasiadas comprobaciones. Inténtalo más tarde.';
	@override String get unavailable => 'La comprobación de enlaces no está disponible ahora.';
	@override String get listed => 'Conocido por malware o phishing';
	@override String get missing => 'No hay ningún sitio en esta dirección';
	@override String get missingAdvice => 'Revisa la ortografía: las estafas usan direcciones parecidas.';
	@override String left({required Object n, required Object total}) => 'Te quedan ${n} de ${total} comprobaciones gratis este mes';
	@override String get usedUp => 'Ya usaste las comprobaciones gratis de este mes';
	@override String get usedUpSub => 'Pro tiene comprobaciones ilimitadas. Las gratis vuelven el día 1.';
	@override String get getPro => 'Obtener Pro';
}

// Path: toolSettings
class _Translations$toolSettings$es extends Translations$toolSettings$en {
	_Translations$toolSettings$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajustes de herramientas';
	@override String get askMobile => 'Preguntar antes de pruebas con datos móviles';
	@override String get askMobileSub => 'Una prueba puede usar más de 100 MB en una conexión rápida';
	@override String get mobileTitle => '¿Usar datos móviles?';
	@override String get mobileBody => 'Una prueba de velocidad puede usar más de 100 MB en una conexión rápida.';
	@override String get mobileGo => 'Probar';
	@override String get safe => 'Segura';
	@override String get unsafe => 'Insegura';
	@override String devices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} dispositivo',
		other: '${n} dispositivos',
	);
	@override String get hideMac => 'Ocultar direcciones físicas';
	@override String get hideMacSub => 'Muestra solo la parte del fabricante de las direcciones MAC';
	@override String get names => 'Mostrar nombres de routers y servidores';
	@override String get namesSub => 'Busca nombres para las direcciones en Traceroute';
	@override String get remember => 'Recordar hosts recientes';
	@override String get rememberSub => 'Para Traceroute';
	@override String get clear => 'Borrar historial de herramientas';
	@override String get clearSub => 'Olvida los hosts recientes y qué dispositivos tuvo cada red';
	@override String get clearGo => 'Borrar';
}

// Path: security
class _Translations$security$es extends Translations$security$en {
	_Translations$security$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get tab => 'Seguridad';
	@override String get good => 'Buena';
	@override String get fair => 'Regular';
	@override String get atRisk => 'En riesgo';
	@override String get allClear => 'Nada que arreglar';
	@override String checked({required Object time}) => 'Revisada a las ${time}';
	@override String get trend => 'ÚLTIMAS DOS SEMANAS';
	@override String get checking => 'Revisando esta red';
	@override String get snoozed => 'Pospuestas';
	@override String get remindLater => 'Recordar más tarde';
	@override String get unsnooze => 'Recordar ahora';
	@override String get review => 'Revisar';
	@override String get confirmGo => 'Confirmar';
	@override String get scanGo => 'Buscar';
	@override String get look => 'Ver';
	@override String get connectGo => 'Conectar';
	@override String get checkAgain => 'Revisar de nuevo';
	@override String get wifiOpen => 'El Wi-Fi está abierto';
	@override String get wifiOpenDetail => 'Cualquiera cerca puede ver lo que se envía';
	@override String get wifiWep => 'El Wi-Fi usa WEP';
	@override String get wifiWepDetail => 'Seguridad antigua, fácil de romper';
	@override String get wifiOwe => 'El Wi-Fi usa Enhanced Open';
	@override String get wifiOweDetail => 'Cifrado, pero cualquiera puede unirse';
	@override String get wifiSecure => 'Cifrado del Wi-Fi';
	@override String get wifiUnknown => 'Seguridad del Wi-Fi desconocida';
	@override String get wifiUnknownDetail => 'Android no indicó cómo está protegido';
	@override String get wps => 'WPS está activado';
	@override String get wpsDetail => 'Desactívalo en los ajustes del router';
	@override String get upnpOff => 'El router mantiene los puertos cerrados';
	@override String get upnpOffDetail => 'UPnP está desactivado';
	@override String get upnpOn => 'El router deja que los dispositivos abran puertos';
	@override String get upnpOnDetail => 'UPnP está activado';
	@override String get portsOk => 'Ningún puerto riesgoso en el router';
	@override String get portsRisky => 'Puertos riesgosos abiertos en el router';
	@override String get scanFirst => 'Busca para ver quién está aquí';
	@override String get scanFirstDetail => 'Los dispositivos desconocidos restan puntos';
	@override String get notMineDetail => 'Revisa la lista de dispositivos del router';
	@override String get confirmDetail => 'Marca los que son tuyos';
	@override String get devicesOk => 'Todos los dispositivos son conocidos';
	@override String get devicesOkDetail => 'Confirmaste cada uno';
	@override String get camera => 'Hay una cámara en esta red';
	@override String get dnsHijack => 'Los nombres desconocidos se redirigen';
	@override String get dnsHijackDetail => 'Tu proveedor o router reescribe las consultas';
	@override String get dnsOk => 'El DNS responde con normalidad';
	@override String get dnsOkDetail => 'Sin señales de redirección';
	@override String get vpnOn => 'La VPN está activada';
	@override String get vpnOnDetail => 'El tráfico sale por el túnel';
	@override String get vpnOff => 'La VPN está desactivada';
	@override String get vpnOffDetail => 'Tu proveedor ve cada sitio';
	@override String toFix({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} cosa por arreglar',
		other: '${n} cosas por arreglar',
	);
	@override String upnpOpened({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} puerto abierto por dispositivos',
		other: '${n} puertos abiertos por dispositivos',
	);
	@override String portsChecked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} puerto revisado',
		other: '${n} puertos revisados',
	);
	@override String notMine({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} dispositivo no es tuyo',
		other: '${n} dispositivos no son tuyos',
	);
	@override String confirm({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} dispositivo por confirmar',
		other: '${n} dispositivos por confirmar',
	);
}

// Path: providers
class _Translations$providers$es extends Translations$providers$en {
	_Translations$providers$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get tab => 'Internet';
	@override String get unavailable => 'No se pudo cargar la lista de proveedores. Revisa tu conexión.';
	@override String get cached => 'Según tu última revisión sin la VPN';
	@override String get notEnough => 'Aún no hay suficientes valoraciones';
	@override String get yourRating => 'Tu valoración de este mes';
	@override String get yourSpeed => 'TU VELOCIDAD';
	@override String get runTest => 'Hacer una prueba de velocidad';
	@override String get aboutAverage => 'En la media de aquí';
	@override String aboveAverage({required Object pct}) => '${pct}% por encima de la media local';
	@override String belowAverage({required Object pct}) => '${pct}% por debajo de la media local';
	@override String get call => 'Llamar';
	@override String get website => 'Sitio web';
	@override String get outages => 'Cortes';
	@override String get rate => 'Valorar';
	@override String get changeRating => 'Cambiar valoración';
	@override String get compare => 'Comparar';
	@override String rateTitle({required Object name}) => 'Valorar ${name}';
	@override String get oncePerMonth => 'Una valoración al mes';
	@override String get tapStars => 'Toca las estrellas';
	@override String verified({required Object mbps}) => 'Verificada con tu prueba: ${mbps} Mbps';
	@override String get busy => 'Demasiadas valoraciones desde aquí. Inténtalo luego.';
	@override String get failed => 'No se pudo enviar. Inténtalo de nuevo.';
	@override String get post => 'Enviar valoración';
	@override String get nearTitle => 'Proveedores cerca de ti';
	@override String slower({required Object pct}) => 'Tu descarga está ${pct}% por debajo de la media de tu proveedor aquí';
	@override String inPlace({required Object place}) => 'Internet en casa en ${place}';
	@override String get byRating => 'Valoración';
	@override String get bySpeed => 'Velocidad';
	@override String get footnote => 'Las velocidades son medias de pruebas de G VPN';
	@override String get noneNearby => 'Aún no hay valoraciones cerca. Sé el primero.';
	@override String get you => 'Tú';
	@override String get topRated => 'Mejor valorado';
	@override String starsOf({required Object n}) => '${n} de 5';
	@override late final _Translations$providers$tags$es tags = _Translations$providers$tags$es._(_root);
	@override late final _Translations$providers$words$es words = _Translations$providers$words$es._(_root);
	@override String ratings({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} valoración',
		other: '${n} valoraciones',
	);
}

// Path: alerts
class _Translations$alerts$es extends Translations$alerts$en {
	_Translations$alerts$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get channel => 'Alertas';
	@override String get title => 'Alertas';
	@override String get markAllRead => 'Marcar todo como leído';
	@override String get clearAll => 'Borrar todo';
	@override String get thisNetwork => 'esta red';
	@override String openWifiTitle({required Object name}) => 'Te conectaste a una Wi-Fi abierta: ${name}';
	@override String get openWifiBody => 'Cualquiera cerca puede ver lo que se envía. Activa G VPN.';
	@override String get reportTitle => 'Tu informe semanal está listo';
	@override String reportBody({required Object hours}) => '${hours} horas protegido la semana pasada';
	@override String blockedTitle({required Object name}) => '${name} está bloqueada aquí';
	@override String get blockedBody => 'Responde a través de la VPN';
	@override late final _Translations$alerts$kinds$es kinds = _Translations$alerts$kinds$es._(_root);
	@override String newDeviceTitle({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: 'Dispositivo nuevo en ${network}',
		other: '${n} dispositivos nuevos en ${network}',
	);
	@override String get settings => 'Ajustes de alertas';
	@override String get look => 'Ver';
	@override String get read => 'Leer';
	@override String get open => 'Abrir';
	@override String get check => 'Comprobar';
	@override String get today => 'HOY';
	@override String get thisWeek => 'ESTA SEMANA';
	@override String get earlier => 'ANTES';
	@override String get all => 'Todas';
	@override String get quiet => 'Todo tranquilo';
	@override String get quietSub => 'Nada te necesitó últimamente';
	@override String breachTitle({required Object name}) => 'Nueva filtración: ${name}';
	@override late final _Translations$alerts$status$es status = _Translations$alerts$status$es._(_root);
}

// Path: report
class _Translations$report$es extends Translations$report$en {
	_Translations$report$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Informe semanal';
	@override String get share => 'Compartir como imagen';
	@override String get shareText => 'Mi semana con G VPN';
	@override String get safer => 'Una semana más segura';
	@override String get moreProtected => 'Más protegido que la semana pasada';
	@override String get yourWeek => 'Tu semana';
	@override String soFar({required Object range}) => '${range}, hasta ahora';
	@override String get protected => 'Protegido';
	@override String get data => 'Datos';
	@override String get security => 'Seguridad';
	@override String get speed => 'Mejor velocidad';
	@override String get noScore => 'Sin revisar';
	@override String get noTest => 'Sin prueba';
	@override String get bestDirect => 'Prueba directa';
	@override String moreThan({required Object d}) => '${d} más que la semana pasada';
	@override String lessThan({required Object d}) => '${d} menos que la semana pasada';
	@override String get protectedTime => 'TIEMPO PROTEGIDO';
	@override String mostUsed({required Object name}) => 'Más usado: ${name}';
	@override String get quiet => 'Una semana tranquila: nada te necesitó';
	@override String newDevices({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: 'Se unió ${n} dispositivo nuevo',
		other: 'Se unieron ${n} dispositivos nuevos',
	);
	@override String openWifi({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: 'Te uniste a ${n} Wi-Fi abierta',
		other: 'Te uniste a ${n} Wi-Fi abiertas',
	);
	@override String blocked({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} app bloqueada',
		other: '${n} apps bloqueadas',
	);
	@override String breaches({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} filtración grande nueva',
		other: '${n} filtraciones grandes nuevas',
	);
}

// Path: breaches
class _Translations$breaches$es extends Translations$breaches$en {
	_Translations$breaches$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtraciones';
	@override String get info => 'Las filtraciones de datos más recientes, de la lista pública de Have I Been Pwned. No se envía nada sobre ti: la lista es la misma para todos.\n\nSi tenías cuenta en un sitio filtrado, cambia esa contraseña, y en cualquier sitio donde la repetiste.';
	@override String get unavailable => 'No se pudo cargar la lista. Revisa tu conexión.';
	@override String get biggest => 'LA MÁS GRANDE DEL MES';
	@override String get newest => 'Más recientes';
	@override String get biggestSort => 'Más grandes';
	@override String get withPasswords => 'Con contraseñas';
	@override String get passwordsMark => 'CONTRASEÑAS';
	@override String get one => 'Filtración';
	@override String get checkPassword => 'Comprobar una contraseña';
	@override String get verified => 'Verificada';
	@override String get hasPasswords => 'Con contraseñas';
	@override String get accountsLabel => 'Cuentas';
	@override String get happened => 'Ocurrió';
	@override String get published => 'Publicada';
	@override String get website => 'Sitio web';
	@override String get leaked => 'QUÉ SE FILTRÓ';
	@override String get ifUsed => 'SI LO USABAS';
	@override String get stepPassword => 'Cambia la contraseña que usabas allí';
	@override String get stepReuse => 'Cámbiala donde usaras la misma';
	@override String get stepTwoStep => 'Activa la verificación en dos pasos donde puedas';
	@override String get stepScams => 'Espera llamadas y mensajes de estafa';
	@override String accounts({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${count} cuenta',
		other: '${count} cuentas',
	);
	@override String worldwide({required Object n}) => 'Mundial · ${n}';
	@override String get noneHere => 'No hay filtraciones de aquí en la lista reciente.';
	@override String get bigMap => 'Mapa más grande';
	@override String get showInList => 'Mostrar en la lista';
	@override String get mapTitle => 'Mapa de filtraciones';
	@override String get zoomIn => 'Acercar';
	@override String get zoomOut => 'Alejar';
	@override String get wholeWorld => 'Todo el mundo';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} filtración',
		other: '${n} filtraciones',
	);
	@override String get findCountry => 'Buscar un país';
	@override String get seeAll => 'Ver todo';
	@override String get search => 'Buscar filtraciones';
}

// Path: blocked
class _Translations$blocked$es extends Translations$blocked$en {
	_Translations$blocked$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Qué está bloqueado';
	@override String get info => 'Prueba sitios conocidos desde este teléfono, sin la VPN, y muestra cuáles bloquea esta red y cómo.\n\nDirección falsa: la búsqueda de nombres de la red da una respuesta falsa.\n\nCortado: la conexión se corta al empezar.\n\nSin respuesta: no vuelve nada.\n\nPágina de bloqueo: otra cosa responde en lugar del sitio.\n\nLa prueba muestra dónde está bloqueado un sitio, no quién lo bloqueó. No se guarda ni se envía nada.';
	@override String get thisNetwork => 'Esta red';
	@override String get country => 'Tu país';
	@override String get question => '¿Qué está bloqueado aquí?';
	@override String get testingOn => 'PROBANDO EN';
	@override String get vpnOn => 'VPN ACTIVA';
	@override String get turnOff => 'Apaga G VPN para probar';
	@override String get test => 'Probar esta red';
	@override String get stop => 'Detener';
	@override String sitesToTest({required Object n}) => 'SITIOS A PROBAR · ${n}';
	@override String ofSites({required Object n}) => 'de ${n} sitios';
	@override String blockedCount({required Object n}) => '${n} BLOQUEADOS';
	@override String openCount({required Object n}) => '${n} ABIERTOS';
	@override String noneBlocked({required Object network}) => 'Nada bloqueado en ${network}';
	@override String openOf({required Object open, required Object total}) => '${open} de ${total} abiertos';
	@override String get allWork => 'TODOS FUNCIONAN CON G VPN';
	@override String get blockedHeading => 'BLOQUEADOS';
	@override String get byKind => 'POR TIPO';
	@override String get worksVpn => 'Funciona con VPN';
	@override String get failsVpn => 'Bloqueado también con VPN';
	@override String get checkVpn => 'Comprobar con G VPN';
	@override String get connect => 'Conectar G VPN';
	@override String get again => 'Probar de nuevo';
	@override String get withoutVpn => 'SIN VPN';
	@override String get throughVpn => 'CON G VPN';
	@override String get notChecked => 'Sin comprobar';
	@override String get opens => 'Abre';
	@override String get stillBlocked => 'Bloqueado';
	@override String get whatHappened => 'QUÉ PASÓ';
	@override String countryBlocked({required Object country}) => 'sitios bloqueados en ${country}';
	@override String get countrySub => 'Encontrados por pruebas de voluntarios en los últimos 30 días';
	@override String get countryNone => 'No hay sitios bloqueados reportados en los últimos 30 días.';
	@override String get countryUnavailable => 'No se pudieron cargar los resultados del país. Revisa tu conexión.';
	@override String get confirmed => 'BLOQUEADO';
	@override String get oftenFails => 'FALLA A MENUDO';
	@override late final _Translations$blocked$kinds$es kinds = _Translations$blocked$kinds$es._(_root);
	@override late final _Translations$blocked$how$es how = _Translations$blocked$how$es._(_root);
	@override late final _Translations$blocked$fail$es fail = _Translations$blocked$fail$es._(_root);
	@override late final _Translations$blocked$steps$es steps = _Translations$blocked$steps$es._(_root);
	@override late final _Translations$blocked$consent$es consent = _Translations$blocked$consent$es._(_root);
	@override String someBlocked({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} sitio bloqueado en ${network}',
		other: '${n} sitios bloqueados en ${network}',
	);
	@override String tests({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n,
		one: '${n} prueba',
		other: '${n} pruebas',
	);
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
	@override String get shield => 'El Escudo filtra las consultas mientras estás conectado: Quad9 bloquea malware y phishing, Cloudflare for Families también bloquea sitios para adultos, o usa tu propio DNS. Nunca bloquea anuncios.';
	@override String get autoConnect => 'Conexión automática: usa el servidor WireGuard que elegiste. Desconectar a mano la pausa hasta que te unas a otra red.';
	@override String get apps => 'Apps directas: las apps que no usan la VPN se conectan directamente. Los bancos suelen bloquear direcciones de VPN, así que los pagos pueden fallar a través de una VPN.';
	@override String get reconnect => 'Cambiar el Escudo o las apps reconecta la VPN un momento.';
	@override String get stay => 'Seguir conectado: algunos teléfonos detienen apps en segundo plano para ahorrar batería. La VPN siempre activa y la batería sin restricciones mantienen G VPN en marcha.';
}

// Path: devices.kinds
class _Translations$devices$kinds$es extends Translations$devices$kinds$en {
	_Translations$devices$kinds$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get phone => 'Teléfono';
	@override String get computer => 'Ordenador';
	@override String get tv => 'TV';
	@override String get speaker => 'Altavoz';
	@override String get printer => 'Impresora';
	@override String get camera => 'Cámara';
	@override String get smartHome => 'Hogar inteligente';
	@override String get router => 'Router';
	@override String get unknown => 'No anunciado';
}

// Path: map.grade
class _Translations$map$grade$es extends Translations$map$grade$en {
	_Translations$map$grade$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get fast => 'Rápido';
	@override String get good => 'Bueno';
	@override String get slow => 'Lento';
}

// Path: presets.names
class _Translations$presets$names$es extends Translations$presets$names$en {
	_Translations$presets$names$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get fastest => 'El más rápido';
	@override String get unblock => 'Desbloquear';
	@override String get streaming => 'Streaming';
	@override String get privacy => 'Máxima privacidad';
}

// Path: providers.tags
class _Translations$providers$tags$es extends Translations$providers$tags$en {
	_Translations$providers$tags$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get fast => 'Rápido';
	@override String get reliable => 'Fiable';
	@override String get support => 'Buen soporte';
	@override String get price => 'Precio justo';
	@override String get slowEvenings => 'Lento por la noche';
	@override String get drops => 'Se corta a menudo';
	@override String get poorSupport => 'Mal soporte';
	@override String get pricey => 'Caro';
}

// Path: providers.words
class _Translations$providers$words$es extends Translations$providers$words$en {
	_Translations$providers$words$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get bad => 'Malo';
	@override String get poor => 'Flojo';
	@override String get okay => 'Regular';
	@override String get good => 'Bueno';
	@override String get great => 'Excelente';
}

// Path: alerts.kinds
class _Translations$alerts$kinds$es extends Translations$alerts$kinds$en {
	_Translations$alerts$kinds$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get newDevice => 'Dispositivos nuevos en mi Wi-Fi';
	@override String get openWifi => 'Wi-Fi abierta o débil';
	@override String get blocked => 'Apps bloqueadas';
	@override String get report => 'Informe semanal';
	@override String get breach => 'Filtraciones';
}

// Path: alerts.status
class _Translations$alerts$status$es extends Translations$alerts$status$en {
	_Translations$alerts$status$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get background => 'Cada pocas horas';
	@override String checked({required Object time}) => 'Comprobado a las ${time}';
	@override String get wifi => 'Cada red a la que te unes';
	@override String get blocked => 'Cuando se revisa el estado de servicios';
	@override String get report => 'Cada lunes';
}

// Path: blocked.kinds
class _Translations$blocked$kinds$es extends Translations$blocked$kinds$en {
	_Translations$blocked$kinds$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get social => 'Redes sociales';
	@override String get messaging => 'Mensajería';
	@override String get news => 'Noticias';
	@override String get video => 'Vídeo y música';
	@override String get privacy => 'Privacidad';
}

// Path: blocked.how
class _Translations$blocked$how$es extends Translations$blocked$how$en {
	_Translations$blocked$how$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get dns => 'Dirección falsa';
	@override String get reset => 'Cortado';
	@override String get timeout => 'Sin respuesta';
	@override String get page => 'Página de bloqueo';
	@override String get open => 'Abierto';
}

// Path: blocked.fail
class _Translations$blocked$fail$es extends Translations$blocked$fail$en {
	_Translations$blocked$fail$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get noAnswer => 'sin respuesta';
	@override String get refused => 'rechazado';
	@override String cutOff({required Object s}) => 'cortado tras ${s} s';
	@override String get wrongCert => 'certificado incorrecto';
}

// Path: blocked.steps
class _Translations$blocked$steps$es extends Translations$blocked$steps$en {
	_Translations$blocked$steps$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get lookup => 'Búsqueda de nombre';
	@override String get connect => 'Conexión';
	@override String get handshake => 'Conexión segura';
}

// Path: blocked.consent
class _Translations$blocked$consent$es extends Translations$blocked$consent$en {
	_Translations$blocked$consent$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Antes de la primera prueba';
	@override String get body => 'La prueba abre cada sitio desde este teléfono, sin la VPN, como lo haría un navegador.';
	@override String get noticeTitle => 'Se puede notar';
	@override String get notice => 'Tu proveedor ve que se abren estos sitios. En algunos países visitarlos, aunque sea para probar, puede llamar la atención. Prueba solo donde te sientas seguro.';
	@override String get ok => 'Entendido, probar';
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
			'home.ipFailed' => 'No se pudo comprobar tu IP',
			'home.ipChecking' => 'Comprobando tu IP',
			'home.themeSystem' => 'Tema: según el teléfono',
			'home.themeLight' => 'Tema: claro',
			'home.themeDark' => 'Tema: oscuro',
			'home.free' => 'Gratis',
			'home.pickServer' => 'Elige un servidor',
			'home.network.title' => 'ESTA RED',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Sin conexión',
			'home.network.showName' => 'Mostrar nombre',
			'home.network.scanFailed' => 'El análisis falló. Se repetirá cuando cambie la red.',
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
			'servers.gTab' => 'G Servers',
			'servers.search' => 'Buscar países',
			'servers.noMatch' => 'Ningún servidor coincide.',
			'servers.bestPing' => ({required Object ms}) => 'mejor ${ms} ms',
			'servers.bestTag' => 'MEJOR',
			'servers.ownHero' => 'Nuestros servidores',
			'servers.ownHeroSub' => 'Más rápidos, privados, cada teléfono con su clave',
			'servers.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} servidor', other: '${n} servidores', ), 
			'servers.showAll' => ({required Object n}) => 'Ver los ${n}',
			'servers.showFewer' => 'Ver menos',
			'servers.fastTab' => 'Rápidos',
			'servers.fastestFree' => 'Gratis más rápidos',
			'pro.owned' => 'Tienes Pro',
			'pro.waitingPlay' => 'Esperando a Google Play',
			'pro.startTrial' => ({required Object days}) => 'Empezar prueba gratis de ${days} días',
			'pro.restore' => 'Restaurar',
			'pro.save' => ({required Object pct}) => 'AHORRA ${pct}%',
			'pro.yearly' => 'Anual',
			'pro.monthly' => 'Mensual',
			'pro.billedMonthly' => 'facturado cada mes',
			'pro.daysFree' => ({required Object days}) => '${days} días gratis',
			'pro.perMonth' => ({required Object price}) => '${price} al mes',
			'pro.title' => 'G VPN Pro',
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
			'pro.heroLine' => 'Nuestros propios servidores rápidos, y cada comprobación ilimitada',
			'pro.start' => 'Empezar Pro',
			'pro.compareFree' => 'GRATIS',
			'pro.comparePro' => 'PRO',
			'pro.rowFreeServers' => 'Servidores gratis',
			'pro.rowTools' => 'Velocidad, herramientas, Wi-Fi',
			'pro.rowGServers' => 'G Servers, sin registros',
			'pro.rowLinks' => 'Comprobación de enlaces',
			'pro.linksFree' => ({required Object n}) => '${n} al mes',
			'pro.unlimited' => 'Ilimitada',
			'rules.title' => 'Reglas',
			'rules.info.shield' => 'El Escudo filtra las consultas mientras estás conectado: Quad9 bloquea malware y phishing, Cloudflare for Families también bloquea sitios para adultos, o usa tu propio DNS. Nunca bloquea anuncios.',
			'rules.info.autoConnect' => 'Conexión automática: usa el servidor WireGuard que elegiste. Desconectar a mano la pausa hasta que te unas a otra red.',
			'rules.info.apps' => 'Apps directas: las apps que no usan la VPN se conectan directamente. Los bancos suelen bloquear direcciones de VPN, así que los pagos pueden fallar a través de una VPN.',
			'rules.info.reconnect' => 'Cambiar el Escudo o las apps reconecta la VPN un momento.',
			'rules.info.stay' => 'Seguir conectado: algunos teléfonos detienen apps en segundo plano para ahorrar batería. La VPN siempre activa y la batería sin restricciones mantienen G VPN en marcha.',
			'rules.protection' => 'Protección',
			'rules.shield' => 'Escudo',
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
			'wol.mac' => 'Dirección MAC',
			'wol.failed' => ({required Object error}) => 'No se pudo enviar: ${error}',
			'wol.computer' => 'Ordenador',
			'wol.pick' => 'Elige un dispositivo para encender',
			'wol.waking' => ({required Object name}) => 'Encendiendo ${name}',
			'wol.yours' => 'TUS DISPOSITIVOS',
			'wol.wakeNamed' => ({required Object name}) => 'Encender ${name}',
			'wol.removeHint' => 'Mantén pulsado un dispositivo para quitarlo',
			'wol.add' => 'AÑADIR UN DISPOSITIVO',
			'wol.name' => 'Nombre',
			'wol.saveWake' => 'Guardar y encender',
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
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} hacia ${host}',
			'router.upnpOn' => 'UPnP activado',
			'router.routerLabel' => 'Router',
			'router.internetAddress' => 'Dirección de internet',
			'router.openedBy' => 'Abiertos por dispositivos',
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
			'devices.newBadge' => 'NUEVO',
			'devices.scanning' => ({required Object n}) => 'Analizando ${n} de 254',
			'devices.newSince' => ({required Object n}) => '${n} nuevos desde el último análisis',
			'devices.ms' => ({required Object n}) => '${n} ms',
			'devices.cameras' => 'Cámaras',
			'devices.device' => 'Dispositivo',
			'devices.online' => 'En línea',
			'devices.model' => 'Modelo',
			'devices.announced' => 'Se anuncia como',
			'devices.services' => 'SERVICIOS ABIERTOS',
			'devices.checkingServices' => 'Comprobando servicios',
			'devices.noServices' => 'Ningún servicio común responde',
			'devices.rename' => 'Renombrar',
			'devices.save' => 'Guardar',
			'devices.kinds.phone' => 'Teléfono',
			'devices.kinds.computer' => 'Ordenador',
			'devices.kinds.tv' => 'TV',
			'devices.kinds.speaker' => 'Altavoz',
			'devices.kinds.printer' => 'Impresora',
			'devices.kinds.camera' => 'Cámara',
			'devices.kinds.smartHome' => 'Hogar inteligente',
			'devices.kinds.router' => 'Router',
			'devices.kinds.unknown' => 'No anunciado',
			'devices.details' => 'Detalles de la red',
			'devices.listView' => 'Lista',
			'devices.meshView' => 'Malla',
			'devices.offlineHeading' => 'Desconectados',
			'devices.seen' => ({required Object when}) => 'Visto ${when}',
			'devices.agoMinutes' => ({required Object n}) => 'hace ${n} min',
			'devices.agoHours' => ({required Object n}) => 'hace ${n} h',
			'devices.agoDays' => ({required Object n}) => 'hace ${n} d',
			'devices.throughVpn' => 'Por la VPN',
			'devices.closer' => 'Más cerca = responde más rápido',
			'devices.yours' => '¿Es tuyo?',
			'devices.mine' => 'Mío',
			'devices.notMine' => 'No es mío',
			'devices.whatIsIt' => '¿Qué es?',
			'devices.ourGuess' => ({required Object kind}) => 'Creemos que es: ${kind}',
			'devices.groupPersonal' => 'Teléfonos y ordenadores',
			'devices.groupHome' => 'Hogar y multimedia',
			'devices.groupNetwork' => 'Red y hogar inteligente',
			'devices.onlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} conectado', other: '${n} conectados', ), 
			'devices.offlineCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} desconectado', other: '${n} desconectados', ), 
			'devices.toConfirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} por confirmar', other: '${n} por confirmar', ), 
			'ping.askTitle' => 'Hacer ping a un host',
			'ping.askHint' => 'example.com o 192.168.1.10',
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
			'tools.internet' => 'Internet',
			'tools.speed' => 'Test de velocidad',
			'tools.speedDesc' => 'Bajada, subida y calidad de video',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'Respuesta y variación en vivo',
			'tools.status' => 'Estado de servicios',
			'tools.statusDesc' => '¿Una app funciona o está bloqueada aquí?',
			'tools.trace' => 'Traceroute',
			'tools.traceDesc' => 'Cada parada hasta un sitio',
			'tools.security' => 'Esta red',
			'tools.devices' => 'Dispositivos en esta red',
			'tools.devicesDesc' => 'Quién está en tu Wi-Fi',
			'tools.router' => 'Revisión del router',
			'tools.routerDesc' => 'Puertos que abrieron tus dispositivos',
			'tools.ports' => 'Puertos abiertos',
			'tools.portsDesc' => 'Puertos riesgosos en un dispositivo o servidor',
			'tools.utilities' => 'Utilidades',
			'tools.wifiScanner' => 'Escáner de Wi-Fi',
			'tools.wifiDesc' => 'Redes a tu alrededor y el canal más libre',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Enciende un ordenador de esta red',
			'tools.passwordCheck' => 'Comprobar contraseña',
			'tools.passwordCheckDesc' => '¿Se ha filtrado?',
			'tools.linkCheck' => 'Comprobar enlace',
			_ => null,
		} ?? switch (path) {
			'tools.linkCheckDesc' => '¿Es seguro abrirlo?',
			'tools.breaches' => 'Filtraciones',
			'tools.breachesDesc' => 'Qué se ha filtrado últimamente',
			'tools.blocked' => 'Qué está bloqueado',
			'tools.blockedDesc' => 'Sitios bloqueados en esta red',
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
			'trace.popular' => 'POPULARES',
			'trace.recent' => 'RECIENTES',
			'trace.clearRecent' => 'Borrar recientes',
			'trace.hopsCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} salto', other: '${n} saltos', ), 
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
			'ports.normal' => 'NORMAL',
			'ports.info' => ({required Object n}) => 'Revisa los ${n} puertos que importan en routers y dispositivos domésticos, y explica cada uno que esté abierto.\n\nRevisa solo dispositivos y servidores que sean tuyos o que administres.',
			'ports.checking' => ({required Object n}) => 'Revisando ${n} puertos',
			'ports.yourRouter' => ({required Object ip}) => 'Tu router es ${ip}',
			'ports.noneOpen' => ({required Object host}) => 'No hay puertos habituales abiertos en ${host}.',
			'ports.summary' => ({required Object open, required Object n}) => '${open} abiertos de ${n} comprobados',
			'ports.riskyCount' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} riesgoso', other: '${n} riesgosos', ), 
			'ports.noneRisky' => 'Nada riesgoso',
			'wifi.title' => 'Escáner de Wi-Fi',
			'wifi.allow' => 'Permitir análisis de Wi-Fi',
			'wifi.needsPermission' => 'Necesita permiso de ubicación.',
			'wifi.scanning' => 'Analizando',
			'wifi.again' => 'Analizar de nuevo',
			'wifi.failed' => 'El análisis falló',
			'wifi.none' => 'No se encontraron redes. Puede que la ubicación esté desactivada.',
			'wifi.hidden' => 'Red oculta',
			'wifi.nearby' => ({required Object n}) => '${n} redes cercanas',
			'wifi.permissionInfo' => 'Android solo muestra las redes Wi-Fi cercanas a las apps con permiso de ubicación. G VPN lo usa únicamente para listar redes en este teléfono.',
			'wifi.info' => 'Muestra las redes del último análisis del teléfono. Android solo permite unos pocos análisis por minuto, así que repetir rápido puede mostrar la misma lista. El canal sugerido es el menos saturado entre 1, 6 y 11, los tres que no se solapan.',
			'wifi.airMap' => 'Mapa del aire',
			'wifi.channels' => 'Canales',
			'wifi.list' => 'Lista',
			'wifi.secure' => 'Segura',
			'wifi.weakLabel' => 'Débil',
			'wifi.openLabel' => 'Abierta',
			'wifi.sizeIsWidth' => 'Tamaño = ancho de canal',
			'wifi.strongest' => 'LA MÁS FUERTE',
			'wifi.openNearby' => 'ABIERTAS CERCA',
			'wifi.onYourChannel' => 'EN TU CANAL',
			'wifi.noneNearby' => 'Ninguna',
			'wifi.verdictOpen' => 'Cualquiera cerca puede leer lo que se envía',
			'wifi.verdictWep' => 'Seguridad antigua, fácil de romper',
			'wifi.verdictWpa' => 'Seguridad antigua',
			'wifi.verdictWps' => 'WPS activado: más fácil de vulnerar',
			'wifi.verdictGood' => 'Bien protegida',
			'wifi.maker' => 'Fabricante',
			'wifi.address' => 'Dirección física',
			'wifi.privateAddress' => 'Inventada por el router por privacidad',
			'wifi.you' => 'Tú',
			'wifi.onClear' => ({required Object name}) => '${name} está en un canal libre',
			'wifi.move' => ({required Object name, required Object n}) => 'Mueve ${name} al canal ${n}',
			'wifi.clear' => 'Libre',
			'wifi.busy' => 'Ocupado',
			'wifi.crowded' => 'Saturado',
			'wifi.allBands' => 'Todas las bandas',
			'wifi.openOnly' => 'Solo abiertas',
			'wifi.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} red', other: '${n} redes', ), 
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
			'gs.included' => 'Incluido',
			'gs.perkServers' => 'Servidores rápidos y privados',
			'gs.perkServersSub' => 'WireGuard, gestionados por nosotros, sin registros',
			'gs.perkLinks' => 'Comprobación de enlaces ilimitada',
			'gs.perkLinksSub' => 'Comprueba cada enlace que te envíen',
			'gs.devicesOf' => ({required Object used, required Object limit}) => 'Tus dispositivos · ${used} de ${limit}',
			'gs.eachKey' => 'Cada teléfono tiene su propia clave',
			'gs.connected' => 'Conectado',
			'gs.bestNow' => 'LO MEJOR PARA TI AHORA',
			'gs.logsShort' => 'REGISTROS',
			'map.open' => 'Abrir el mapa',
			'map.searchCountries' => 'Buscar países',
			'map.noMatch' => 'Ningún país coincide',
			'map.locate' => 'Mi ubicación',
			'map.list' => 'Lista',
			'map.map' => 'Mapa',
			'map.freeServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} servidor gratis', other: '${n} servidores gratis', ), 
			'map.grade.fast' => 'Rápido',
			'map.grade.good' => 'Bueno',
			'map.grade.slow' => 'Lento',
			'map.switchTo' => 'Cambiar',
			'map.freeServer' => ({required Object n}) => 'Servidor gratis ${n}',
			'map.best' => 'MEJOR',
			'map.gServers' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} G Server', other: '${n} G Servers', ), 
			'stats.thisWeek' => 'Esta semana',
			'stats.time' => 'Tiempo',
			'stats.data' => 'Datos',
			'stats.protected' => 'protegido',
			'stats.throughVpn' => 'por la VPN',
			'stats.seeDetails' => 'Ver detalles',
			'stats.title' => 'Estadísticas',
			'stats.week' => 'Semana',
			'stats.month' => 'Mes',
			'stats.protectedLabel' => 'PROTEGIDO',
			'stats.dataUsed' => 'DATOS USADOS',
			'stats.byServer' => 'POR SERVIDOR',
			'stats.onPhone' => 'Solo en este teléfono',
			'stats.reset' => 'Restablecer',
			'stats.resetTitle' => '¿Restablecer estadísticas?',
			'stats.resetBody' => 'Borra el tiempo protegido y los datos de este teléfono. No se puede deshacer.',
			'stats.hm' => ({required Object h, required Object m}) => '${h} h ${m} min',
			'stats.m' => ({required Object m}) => '${m} min',
			'stats.empty' => 'Conéctate para empezar a contar.',
			'recents.title' => 'Recientes',
			'recents.allServers' => 'Todos los servidores',
			'recents.free' => 'Servidor gratis',
			'recents.yours' => 'Tu servidor',
			'recents.gserver' => 'G Server',
			'presets.title' => 'Ajustes rápidos',
			'presets.all' => 'Todos',
			'presets.newPreset' => 'Nuevo ajuste',
			'presets.edit' => 'Editar ajuste',
			'presets.name' => 'Nombre',
			'presets.namePlaceholder' => 'Mi ajuste',
			'presets.server' => 'SERVIDOR',
			'presets.fastestOption' => 'El más rápido',
			'presets.countryOption' => 'País',
			'presets.pickCountry' => 'Elige un país',
			'presets.skipMyCountry' => 'Evitar mi país',
			'presets.notMine' => 'no mi país',
			'presets.protocol' => 'PROTOCOLO',
			'presets.auto' => 'Auto',
			'presets.tryNext' => 'Si está bloqueado, probar el siguiente',
			'presets.shield' => 'ESCUDO',
			'presets.followRules' => 'Como en Reglas',
			'presets.allApps' => 'Todas las apps por la VPN',
			'presets.allAppsShort' => 'todas las apps',
			'presets.save' => 'Guardar',
			'presets.delete' => 'Eliminar',
			'presets.reset' => 'Restablecer',
			'presets.none' => 'Ahora no hay un servidor gratis para este ajuste.',
			'presets.names.fastest' => 'El más rápido',
			'presets.names.unblock' => 'Desbloquear',
			'presets.names.streaming' => 'Streaming',
			'presets.names.privacy' => 'Máxima privacidad',
			'shield.title' => 'Escudo',
			'shield.sub' => 'Funciona mientras estás conectado',
			'shield.off' => 'Desactivado',
			'shield.offSub' => 'El DNS del servidor',
			'shield.malware' => 'Malware',
			'shield.malwareSub' => 'Bloquea sitios dañinos y de phishing',
			'shield.family' => 'Malware y sitios para adultos',
			'shield.familySub' => 'También bloquea contenido para adultos',
			'shield.custom' => 'DNS propio',
			'shield.customSub' => 'Tus propios servidores DNS',
			'shield.customHint' => 'Dirección IP, por ejemplo 1.1.1.1',
			'shield.invalid' => 'Escribe una o dos direcciones IP.',
			'checks.title' => 'Comprobaciones',
			'checks.password' => 'Contraseña',
			'checks.link' => 'Enlace',
			'checks.pwTitle' => '¿Se filtró?',
			'checks.pwHint' => 'Contraseña a comprobar',
			'checks.showPassword' => 'Mostrar contraseña',
			'checks.hidePassword' => 'Ocultar contraseña',
			'checks.check' => 'Comprobar',
			'checks.leaked' => 'Aparece en filtraciones',
			'checks.seen' => ({required Object n}) => 'Vista ${n} veces',
			'checks.leakedAdvice' => 'Cámbiala en todos los sitios donde la uses, empezando por el correo y el banco.',
			'checks.notFound' => 'No aparece en filtraciones conocidas',
			'checks.notFoundAdvice' => 'Buena señal, no una garantía. Usa una contraseña distinta en cada cuenta.',
			'checks.failed' => 'No se pudo comprobar. Inténtalo de nuevo.',
			'checks.private' => 'Tu contraseña nunca sale de este teléfono',
			'checks.linkTitle' => '¿Es seguro este enlace?',
			'checks.linkHint' => 'Enlace a comprobar',
			'checks.paste' => 'Pegar',
			'checks.danger' => 'Enlace peligroso',
			'checks.dangerAdvice' => 'No lo abras ni escribas ningún dato.',
			'checks.clear' => 'No está en listas conocidas de malware o phishing',
			'checks.clearAdvice' => 'Aun así, mira la dirección antes de iniciar sesión.',
			'checks.goesTo' => 'Lleva a',
			'checks.redirects' => 'Redirecciones',
			'checks.invalid' => 'Eso no parece una dirección web.',
			'checks.busy' => 'Demasiadas comprobaciones. Inténtalo más tarde.',
			'checks.unavailable' => 'La comprobación de enlaces no está disponible ahora.',
			'checks.listed' => 'Conocido por malware o phishing',
			'checks.missing' => 'No hay ningún sitio en esta dirección',
			'checks.missingAdvice' => 'Revisa la ortografía: las estafas usan direcciones parecidas.',
			'checks.left' => ({required Object n, required Object total}) => 'Te quedan ${n} de ${total} comprobaciones gratis este mes',
			'checks.usedUp' => 'Ya usaste las comprobaciones gratis de este mes',
			'checks.usedUpSub' => 'Pro tiene comprobaciones ilimitadas. Las gratis vuelven el día 1.',
			'checks.getPro' => 'Obtener Pro',
			'toolSettings.title' => 'Ajustes de herramientas',
			'toolSettings.askMobile' => 'Preguntar antes de pruebas con datos móviles',
			'toolSettings.askMobileSub' => 'Una prueba puede usar más de 100 MB en una conexión rápida',
			'toolSettings.mobileTitle' => '¿Usar datos móviles?',
			'toolSettings.mobileBody' => 'Una prueba de velocidad puede usar más de 100 MB en una conexión rápida.',
			'toolSettings.mobileGo' => 'Probar',
			'toolSettings.safe' => 'Segura',
			'toolSettings.unsafe' => 'Insegura',
			'toolSettings.devices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} dispositivo', other: '${n} dispositivos', ), 
			'toolSettings.hideMac' => 'Ocultar direcciones físicas',
			'toolSettings.hideMacSub' => 'Muestra solo la parte del fabricante de las direcciones MAC',
			'toolSettings.names' => 'Mostrar nombres de routers y servidores',
			'toolSettings.namesSub' => 'Busca nombres para las direcciones en Traceroute',
			'toolSettings.remember' => 'Recordar hosts recientes',
			'toolSettings.rememberSub' => 'Para Traceroute',
			'toolSettings.clear' => 'Borrar historial de herramientas',
			'toolSettings.clearSub' => 'Olvida los hosts recientes y qué dispositivos tuvo cada red',
			'toolSettings.clearGo' => 'Borrar',
			'security.tab' => 'Seguridad',
			'security.good' => 'Buena',
			'security.fair' => 'Regular',
			'security.atRisk' => 'En riesgo',
			'security.allClear' => 'Nada que arreglar',
			'security.checked' => ({required Object time}) => 'Revisada a las ${time}',
			'security.trend' => 'ÚLTIMAS DOS SEMANAS',
			'security.checking' => 'Revisando esta red',
			'security.snoozed' => 'Pospuestas',
			'security.remindLater' => 'Recordar más tarde',
			'security.unsnooze' => 'Recordar ahora',
			'security.review' => 'Revisar',
			'security.confirmGo' => 'Confirmar',
			'security.scanGo' => 'Buscar',
			'security.look' => 'Ver',
			'security.connectGo' => 'Conectar',
			'security.checkAgain' => 'Revisar de nuevo',
			'security.wifiOpen' => 'El Wi-Fi está abierto',
			'security.wifiOpenDetail' => 'Cualquiera cerca puede ver lo que se envía',
			'security.wifiWep' => 'El Wi-Fi usa WEP',
			'security.wifiWepDetail' => 'Seguridad antigua, fácil de romper',
			'security.wifiOwe' => 'El Wi-Fi usa Enhanced Open',
			'security.wifiOweDetail' => 'Cifrado, pero cualquiera puede unirse',
			'security.wifiSecure' => 'Cifrado del Wi-Fi',
			'security.wifiUnknown' => 'Seguridad del Wi-Fi desconocida',
			'security.wifiUnknownDetail' => 'Android no indicó cómo está protegido',
			'security.wps' => 'WPS está activado',
			'security.wpsDetail' => 'Desactívalo en los ajustes del router',
			'security.upnpOff' => 'El router mantiene los puertos cerrados',
			'security.upnpOffDetail' => 'UPnP está desactivado',
			'security.upnpOn' => 'El router deja que los dispositivos abran puertos',
			'security.upnpOnDetail' => 'UPnP está activado',
			'security.portsOk' => 'Ningún puerto riesgoso en el router',
			'security.portsRisky' => 'Puertos riesgosos abiertos en el router',
			'security.scanFirst' => 'Busca para ver quién está aquí',
			'security.scanFirstDetail' => 'Los dispositivos desconocidos restan puntos',
			'security.notMineDetail' => 'Revisa la lista de dispositivos del router',
			'security.confirmDetail' => 'Marca los que son tuyos',
			'security.devicesOk' => 'Todos los dispositivos son conocidos',
			'security.devicesOkDetail' => 'Confirmaste cada uno',
			'security.camera' => 'Hay una cámara en esta red',
			'security.dnsHijack' => 'Los nombres desconocidos se redirigen',
			'security.dnsHijackDetail' => 'Tu proveedor o router reescribe las consultas',
			'security.dnsOk' => 'El DNS responde con normalidad',
			'security.dnsOkDetail' => 'Sin señales de redirección',
			'security.vpnOn' => 'La VPN está activada',
			'security.vpnOnDetail' => 'El tráfico sale por el túnel',
			'security.vpnOff' => 'La VPN está desactivada',
			'security.vpnOffDetail' => 'Tu proveedor ve cada sitio',
			'security.toFix' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} cosa por arreglar', other: '${n} cosas por arreglar', ), 
			'security.upnpOpened' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} puerto abierto por dispositivos', other: '${n} puertos abiertos por dispositivos', ), 
			'security.portsChecked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} puerto revisado', other: '${n} puertos revisados', ), 
			'security.notMine' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} dispositivo no es tuyo', other: '${n} dispositivos no son tuyos', ), 
			'security.confirm' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} dispositivo por confirmar', other: '${n} dispositivos por confirmar', ), 
			'providers.tab' => 'Internet',
			'providers.unavailable' => 'No se pudo cargar la lista de proveedores. Revisa tu conexión.',
			'providers.cached' => 'Según tu última revisión sin la VPN',
			'providers.notEnough' => 'Aún no hay suficientes valoraciones',
			'providers.yourRating' => 'Tu valoración de este mes',
			'providers.yourSpeed' => 'TU VELOCIDAD',
			'providers.runTest' => 'Hacer una prueba de velocidad',
			'providers.aboutAverage' => 'En la media de aquí',
			'providers.aboveAverage' => ({required Object pct}) => '${pct}% por encima de la media local',
			'providers.belowAverage' => ({required Object pct}) => '${pct}% por debajo de la media local',
			'providers.call' => 'Llamar',
			'providers.website' => 'Sitio web',
			'providers.outages' => 'Cortes',
			'providers.rate' => 'Valorar',
			'providers.changeRating' => 'Cambiar valoración',
			'providers.compare' => 'Comparar',
			'providers.rateTitle' => ({required Object name}) => 'Valorar ${name}',
			'providers.oncePerMonth' => 'Una valoración al mes',
			'providers.tapStars' => 'Toca las estrellas',
			'providers.verified' => ({required Object mbps}) => 'Verificada con tu prueba: ${mbps} Mbps',
			'providers.busy' => 'Demasiadas valoraciones desde aquí. Inténtalo luego.',
			'providers.failed' => 'No se pudo enviar. Inténtalo de nuevo.',
			'providers.post' => 'Enviar valoración',
			'providers.nearTitle' => 'Proveedores cerca de ti',
			'providers.slower' => ({required Object pct}) => 'Tu descarga está ${pct}% por debajo de la media de tu proveedor aquí',
			'providers.inPlace' => ({required Object place}) => 'Internet en casa en ${place}',
			'providers.byRating' => 'Valoración',
			'providers.bySpeed' => 'Velocidad',
			'providers.footnote' => 'Las velocidades son medias de pruebas de G VPN',
			'providers.noneNearby' => 'Aún no hay valoraciones cerca. Sé el primero.',
			'providers.you' => 'Tú',
			'providers.topRated' => 'Mejor valorado',
			'providers.starsOf' => ({required Object n}) => '${n} de 5',
			'providers.tags.fast' => 'Rápido',
			'providers.tags.reliable' => 'Fiable',
			'providers.tags.support' => 'Buen soporte',
			'providers.tags.price' => 'Precio justo',
			'providers.tags.slowEvenings' => 'Lento por la noche',
			'providers.tags.drops' => 'Se corta a menudo',
			'providers.tags.poorSupport' => 'Mal soporte',
			'providers.tags.pricey' => 'Caro',
			'providers.words.bad' => 'Malo',
			'providers.words.poor' => 'Flojo',
			'providers.words.okay' => 'Regular',
			'providers.words.good' => 'Bueno',
			'providers.words.great' => 'Excelente',
			'providers.ratings' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} valoración', other: '${n} valoraciones', ), 
			'alerts.channel' => 'Alertas',
			'alerts.title' => 'Alertas',
			'alerts.markAllRead' => 'Marcar todo como leído',
			'alerts.clearAll' => 'Borrar todo',
			'alerts.thisNetwork' => 'esta red',
			'alerts.openWifiTitle' => ({required Object name}) => 'Te conectaste a una Wi-Fi abierta: ${name}',
			'alerts.openWifiBody' => 'Cualquiera cerca puede ver lo que se envía. Activa G VPN.',
			'alerts.reportTitle' => 'Tu informe semanal está listo',
			'alerts.reportBody' => ({required Object hours}) => '${hours} horas protegido la semana pasada',
			'alerts.blockedTitle' => ({required Object name}) => '${name} está bloqueada aquí',
			'alerts.blockedBody' => 'Responde a través de la VPN',
			'alerts.kinds.newDevice' => 'Dispositivos nuevos en mi Wi-Fi',
			'alerts.kinds.openWifi' => 'Wi-Fi abierta o débil',
			'alerts.kinds.blocked' => 'Apps bloqueadas',
			'alerts.kinds.report' => 'Informe semanal',
			'alerts.kinds.breach' => 'Filtraciones',
			'alerts.newDeviceTitle' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: 'Dispositivo nuevo en ${network}', other: '${n} dispositivos nuevos en ${network}', ), 
			'alerts.settings' => 'Ajustes de alertas',
			'alerts.look' => 'Ver',
			'alerts.read' => 'Leer',
			'alerts.open' => 'Abrir',
			'alerts.check' => 'Comprobar',
			'alerts.today' => 'HOY',
			'alerts.thisWeek' => 'ESTA SEMANA',
			'alerts.earlier' => 'ANTES',
			'alerts.all' => 'Todas',
			'alerts.quiet' => 'Todo tranquilo',
			'alerts.quietSub' => 'Nada te necesitó últimamente',
			'alerts.breachTitle' => ({required Object name}) => 'Nueva filtración: ${name}',
			'alerts.status.background' => 'Cada pocas horas',
			'alerts.status.checked' => ({required Object time}) => 'Comprobado a las ${time}',
			'alerts.status.wifi' => 'Cada red a la que te unes',
			'alerts.status.blocked' => 'Cuando se revisa el estado de servicios',
			'alerts.status.report' => 'Cada lunes',
			'report.title' => 'Informe semanal',
			'report.share' => 'Compartir como imagen',
			'report.shareText' => 'Mi semana con G VPN',
			'report.safer' => 'Una semana más segura',
			'report.moreProtected' => 'Más protegido que la semana pasada',
			'report.yourWeek' => 'Tu semana',
			'report.soFar' => ({required Object range}) => '${range}, hasta ahora',
			'report.protected' => 'Protegido',
			'report.data' => 'Datos',
			'report.security' => 'Seguridad',
			'report.speed' => 'Mejor velocidad',
			'report.noScore' => 'Sin revisar',
			'report.noTest' => 'Sin prueba',
			'report.bestDirect' => 'Prueba directa',
			'report.moreThan' => ({required Object d}) => '${d} más que la semana pasada',
			'report.lessThan' => ({required Object d}) => '${d} menos que la semana pasada',
			'report.protectedTime' => 'TIEMPO PROTEGIDO',
			'report.mostUsed' => ({required Object name}) => 'Más usado: ${name}',
			'report.quiet' => 'Una semana tranquila: nada te necesitó',
			'report.newDevices' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: 'Se unió ${n} dispositivo nuevo', other: 'Se unieron ${n} dispositivos nuevos', ), 
			'report.openWifi' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: 'Te uniste a ${n} Wi-Fi abierta', other: 'Te uniste a ${n} Wi-Fi abiertas', ), 
			'report.blocked' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} app bloqueada', other: '${n} apps bloqueadas', ), 
			'report.breaches' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} filtración grande nueva', other: '${n} filtraciones grandes nuevas', ), 
			'breaches.title' => 'Filtraciones',
			'breaches.info' => 'Las filtraciones de datos más recientes, de la lista pública de Have I Been Pwned. No se envía nada sobre ti: la lista es la misma para todos.\n\nSi tenías cuenta en un sitio filtrado, cambia esa contraseña, y en cualquier sitio donde la repetiste.',
			'breaches.unavailable' => 'No se pudo cargar la lista. Revisa tu conexión.',
			'breaches.biggest' => 'LA MÁS GRANDE DEL MES',
			'breaches.newest' => 'Más recientes',
			'breaches.biggestSort' => 'Más grandes',
			'breaches.withPasswords' => 'Con contraseñas',
			'breaches.passwordsMark' => 'CONTRASEÑAS',
			'breaches.one' => 'Filtración',
			_ => null,
		} ?? switch (path) {
			'breaches.checkPassword' => 'Comprobar una contraseña',
			'breaches.verified' => 'Verificada',
			'breaches.hasPasswords' => 'Con contraseñas',
			'breaches.accountsLabel' => 'Cuentas',
			'breaches.happened' => 'Ocurrió',
			'breaches.published' => 'Publicada',
			'breaches.website' => 'Sitio web',
			'breaches.leaked' => 'QUÉ SE FILTRÓ',
			'breaches.ifUsed' => 'SI LO USABAS',
			'breaches.stepPassword' => 'Cambia la contraseña que usabas allí',
			'breaches.stepReuse' => 'Cámbiala donde usaras la misma',
			'breaches.stepTwoStep' => 'Activa la verificación en dos pasos donde puedas',
			'breaches.stepScams' => 'Espera llamadas y mensajes de estafa',
			'breaches.accounts' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${count} cuenta', other: '${count} cuentas', ), 
			'breaches.worldwide' => ({required Object n}) => 'Mundial · ${n}',
			'breaches.noneHere' => 'No hay filtraciones de aquí en la lista reciente.',
			'breaches.bigMap' => 'Mapa más grande',
			'breaches.showInList' => 'Mostrar en la lista',
			'breaches.mapTitle' => 'Mapa de filtraciones',
			'breaches.zoomIn' => 'Acercar',
			'breaches.zoomOut' => 'Alejar',
			'breaches.wholeWorld' => 'Todo el mundo',
			'breaches.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} filtración', other: '${n} filtraciones', ), 
			'breaches.findCountry' => 'Buscar un país',
			'breaches.seeAll' => 'Ver todo',
			'breaches.search' => 'Buscar filtraciones',
			'blocked.title' => 'Qué está bloqueado',
			'blocked.info' => 'Prueba sitios conocidos desde este teléfono, sin la VPN, y muestra cuáles bloquea esta red y cómo.\n\nDirección falsa: la búsqueda de nombres de la red da una respuesta falsa.\n\nCortado: la conexión se corta al empezar.\n\nSin respuesta: no vuelve nada.\n\nPágina de bloqueo: otra cosa responde en lugar del sitio.\n\nLa prueba muestra dónde está bloqueado un sitio, no quién lo bloqueó. No se guarda ni se envía nada.',
			'blocked.thisNetwork' => 'Esta red',
			'blocked.country' => 'Tu país',
			'blocked.question' => '¿Qué está bloqueado aquí?',
			'blocked.testingOn' => 'PROBANDO EN',
			'blocked.vpnOn' => 'VPN ACTIVA',
			'blocked.turnOff' => 'Apaga G VPN para probar',
			'blocked.test' => 'Probar esta red',
			'blocked.stop' => 'Detener',
			'blocked.sitesToTest' => ({required Object n}) => 'SITIOS A PROBAR · ${n}',
			'blocked.ofSites' => ({required Object n}) => 'de ${n} sitios',
			'blocked.blockedCount' => ({required Object n}) => '${n} BLOQUEADOS',
			'blocked.openCount' => ({required Object n}) => '${n} ABIERTOS',
			'blocked.noneBlocked' => ({required Object network}) => 'Nada bloqueado en ${network}',
			'blocked.openOf' => ({required Object open, required Object total}) => '${open} de ${total} abiertos',
			'blocked.allWork' => 'TODOS FUNCIONAN CON G VPN',
			'blocked.blockedHeading' => 'BLOQUEADOS',
			'blocked.byKind' => 'POR TIPO',
			'blocked.worksVpn' => 'Funciona con VPN',
			'blocked.failsVpn' => 'Bloqueado también con VPN',
			'blocked.checkVpn' => 'Comprobar con G VPN',
			'blocked.connect' => 'Conectar G VPN',
			'blocked.again' => 'Probar de nuevo',
			'blocked.withoutVpn' => 'SIN VPN',
			'blocked.throughVpn' => 'CON G VPN',
			'blocked.notChecked' => 'Sin comprobar',
			'blocked.opens' => 'Abre',
			'blocked.stillBlocked' => 'Bloqueado',
			'blocked.whatHappened' => 'QUÉ PASÓ',
			'blocked.countryBlocked' => ({required Object country}) => 'sitios bloqueados en ${country}',
			'blocked.countrySub' => 'Encontrados por pruebas de voluntarios en los últimos 30 días',
			'blocked.countryNone' => 'No hay sitios bloqueados reportados en los últimos 30 días.',
			'blocked.countryUnavailable' => 'No se pudieron cargar los resultados del país. Revisa tu conexión.',
			'blocked.confirmed' => 'BLOQUEADO',
			'blocked.oftenFails' => 'FALLA A MENUDO',
			'blocked.kinds.social' => 'Redes sociales',
			'blocked.kinds.messaging' => 'Mensajería',
			'blocked.kinds.news' => 'Noticias',
			'blocked.kinds.video' => 'Vídeo y música',
			'blocked.kinds.privacy' => 'Privacidad',
			'blocked.how.dns' => 'Dirección falsa',
			'blocked.how.reset' => 'Cortado',
			'blocked.how.timeout' => 'Sin respuesta',
			'blocked.how.page' => 'Página de bloqueo',
			'blocked.how.open' => 'Abierto',
			'blocked.fail.noAnswer' => 'sin respuesta',
			'blocked.fail.refused' => 'rechazado',
			'blocked.fail.cutOff' => ({required Object s}) => 'cortado tras ${s} s',
			'blocked.fail.wrongCert' => 'certificado incorrecto',
			'blocked.steps.lookup' => 'Búsqueda de nombre',
			'blocked.steps.connect' => 'Conexión',
			'blocked.steps.handshake' => 'Conexión segura',
			'blocked.consent.title' => 'Antes de la primera prueba',
			'blocked.consent.body' => 'La prueba abre cada sitio desde este teléfono, sin la VPN, como lo haría un navegador.',
			'blocked.consent.noticeTitle' => 'Se puede notar',
			'blocked.consent.notice' => 'Tu proveedor ve que se abren estos sitios. En algunos países visitarlos, aunque sea para probar, puede llamar la atención. Prueba solo donde te sientas seguro.',
			'blocked.consent.ok' => 'Entendido, probar',
			'blocked.someBlocked' => ({required num n, required Object network}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} sitio bloqueado en ${network}', other: '${n} sitios bloqueados en ${network}', ), 
			'blocked.tests' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('es'))(n, one: '${n} prueba', other: '${n} pruebas', ), 
			_ => null,
		};
	}
}
