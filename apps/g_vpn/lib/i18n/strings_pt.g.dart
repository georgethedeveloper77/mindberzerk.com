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
class TranslationsPt extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsPt({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.pt,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <pt>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsPt _root = this; // ignore: unused_field

	@override 
	TranslationsPt $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsPt(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$pt common = _Translations$common$pt._(_root);
	@override late final _Translations$nav$pt nav = _Translations$nav$pt._(_root);
	@override late final _Translations$home$pt home = _Translations$home$pt._(_root);
	@override late final _Translations$servers$pt servers = _Translations$servers$pt._(_root);
	@override late final _Translations$pro$pt pro = _Translations$pro$pt._(_root);
	@override late final _Translations$rules$pt rules = _Translations$rules$pt._(_root);
	@override late final _Translations$apps$pt apps = _Translations$apps$pt._(_root);
	@override late final _Translations$location$pt location = _Translations$location$pt._(_root);
	@override late final _Translations$addServer$pt addServer = _Translations$addServer$pt._(_root);
	@override late final _Translations$button$pt button = _Translations$button$pt._(_root);
	@override late final _Translations$wol$pt wol = _Translations$wol$pt._(_root);
	@override late final _Translations$speed$pt speed = _Translations$speed$pt._(_root);
	@override late final _Translations$router$pt router = _Translations$router$pt._(_root);
	@override late final _Translations$network$pt network = _Translations$network$pt._(_root);
	@override late final _Translations$devices$pt devices = _Translations$devices$pt._(_root);
	@override late final _Translations$ping$pt ping = _Translations$ping$pt._(_root);
	@override late final _Translations$status$pt status = _Translations$status$pt._(_root);
	@override late final _Translations$tools$pt tools = _Translations$tools$pt._(_root);
	@override late final _Translations$trace$pt trace = _Translations$trace$pt._(_root);
	@override late final _Translations$ports$pt ports = _Translations$ports$pt._(_root);
	@override late final _Translations$wifi$pt wifi = _Translations$wifi$pt._(_root);
	@override late final _Translations$errors$pt errors = _Translations$errors$pt._(_root);
	@override late final _Translations$scan$pt scan = _Translations$scan$pt._(_root);
	@override late final _Translations$legal$pt legal = _Translations$legal$pt._(_root);
	@override late final _Translations$update$pt update = _Translations$update$pt._(_root);
	@override late final _Translations$details$pt details = _Translations$details$pt._(_root);
	@override late final _Translations$share$pt share = _Translations$share$pt._(_root);
	@override late final _Translations$add$pt add = _Translations$add$pt._(_root);
	@override late final _Translations$backup$pt backup = _Translations$backup$pt._(_root);
	@override late final _Translations$gs$pt gs = _Translations$gs$pt._(_root);
}

// Path: common
class _Translations$common$pt extends Translations$common$en {
	_Translations$common$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get gotIt => 'Entendi';
	@override String get about => 'Sobre';
	@override String get connect => 'Conectar';
	@override String get connected => 'Conectado';
	@override String get retry => 'Tentar de novo';
	@override String get ok => 'OK';
	@override String get remove => 'Remover';
	@override String get cancel => 'Cancelar';
	@override String get continueLabel => 'Continuar';
	@override String get notNow => 'Agora não';
	@override String get openSettings => 'Abrir configurações';
	@override String get close => 'Fechar';
	@override String get off => 'Desligado';
	@override String get changesReconnect => 'As alterações reconectam a VPN';
}

// Path: nav
class _Translations$nav$pt extends Translations$nav$en {
	_Translations$nav$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get vpn => 'VPN';
	@override String get servers => 'Servidores';
	@override String get tools => 'Ferramentas';
	@override String get rules => 'Regras';
	@override String get pro => 'Pro';
}

// Path: home
class _Translations$home$pt extends Translations$home$en {
	_Translations$home$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override late final _Translations$home$status$pt status = _Translations$home$status$pt._(_root);
	@override String resumesAt({required Object time}) => 'Volta às ${time} · toque para retomar agora';
	@override String sitesSee({required Object ip}) => 'Os sites veem ${ip}';
	@override String sitesSeeOrg({required Object ip, required Object org}) => 'Os sites veem ${ip} · ${org}';
	@override String get ipFailed => 'Não foi possível verificar seu IP';
	@override String get ipChecking => 'Verificando seu IP';
	@override String get themeSystem => 'Tema: igual ao celular';
	@override String get themeLight => 'Tema: claro';
	@override String get themeDark => 'Tema: escuro';
	@override String get free => 'Grátis';
	@override String get pickServer => 'Escolha um servidor';
	@override late final _Translations$home$waves$pt waves = _Translations$home$waves$pt._(_root);
	@override late final _Translations$home$network$pt network = _Translations$home$network$pt._(_root);
	@override late final _Translations$home$card$pt card = _Translations$home$card$pt._(_root);
	@override late final _Translations$home$tiles$pt tiles = _Translations$home$tiles$pt._(_root);
	@override late final _Translations$home$fastest$pt fastest = _Translations$home$fastest$pt._(_root);
	@override late final _Translations$home$ip$pt ip = _Translations$home$ip$pt._(_root);
}

// Path: servers
class _Translations$servers$pt extends Translations$servers$en {
	_Translations$servers$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Servidores';
	@override String get aboutServers => 'Sobre os servidores';
	@override late final _Translations$servers$tabs$pt tabs = _Translations$servers$tabs$pt._(_root);
	@override late final _Translations$servers$sheet$pt sheet = _Translations$servers$sheet$pt._(_root);
	@override late final _Translations$servers$badges$pt badges = _Translations$servers$badges$pt._(_root);
	@override late final _Translations$servers$filters$pt filters = _Translations$servers$filters$pt._(_root);
	@override String get loadFailed => 'Não foi possível carregar a lista';
	@override String get noServers => 'Nenhum servidor agora';
	@override String get best => 'O MELHOR PARA VOCÊ AGORA';
	@override String get topRanked => 'O mais bem avaliado agora';
	@override String get addHeading => 'ADICIONAR SERVIDOR';
	@override String get scanQr => 'Ler QR';
	@override String get importFile => 'Importar arquivo';
	@override String get paste => 'Colar';
	@override late final _Translations$servers$own$pt own = _Translations$servers$own$pt._(_root);
	@override String get configBroken => 'A configuração precisa de atenção';
	@override String get connectedBadge => 'CONECTADO';
	@override String get scannedServer => 'Servidor lido';
	@override String get scanFailedTitle => 'Não foi possível ler';
	@override String get scanFailedBody => 'O leitor não está disponível neste celular.';
	@override String get importFailedTitle => 'Não foi possível importar';
	@override String get importFailedBody => 'Não foi possível ler esse arquivo.';
	@override String get renameTitle => 'Renomear servidor';
	@override String get nameHint => 'Nome, por exemplo Roteador de casa';
	@override String get save => 'Salvar';
	@override String get rename => 'Renomear';
	@override String get disconnect => 'Desconectar';
	@override String get more => 'Mais opções';
	@override String get justNow => 'agora mesmo';
	@override String minutesAgo({required Object n}) => 'há ${n} min';
	@override String hoursAgo({required Object n}) => 'há ${n} h';
	@override String daysAgo({required Object n}) => 'há ${n} d';
	@override String get neverUsed => 'Ainda não usado';
	@override String lastUsed({required Object when}) => 'Último uso ${when}';
	@override String get disconnectFirst => 'Desconecte primeiro para remover';
	@override String get removeConfirm => 'Remover este servidor do G VPN? As configurações dele são apagadas deste celular; o servidor em si não muda.';
}

// Path: pro
class _Translations$pro$pt extends Translations$pro$en {
	_Translations$pro$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get owned => 'Você tem o Pro';
	@override String get waitingPlay => 'Aguardando o Google Play';
	@override String startTrial({required Object days}) => 'Começar teste grátis de ${days} dias';
	@override String thenYearly({required Object price}) => 'Depois ${price} por ano. Cancele quando quiser no Google Play.';
	@override String thenMonthly({required Object price}) => 'Depois ${price} por mês. Cancele quando quiser no Google Play.';
	@override String yearlyPrice({required Object price}) => '${price} por ano. Cancele quando quiser no Google Play.';
	@override String monthlyPrice({required Object price}) => '${price} por mês. Cancele quando quiser no Google Play.';
	@override String get restore => 'Restaurar';
	@override String get heroTitle => 'Servidores mais rápidos,\noperados por nós';
	@override String get heroSubtitle => 'WireGuard. Sem registros de atividade. Sem conta.';
	@override String get benefitSpeed => 'Velocidade total, sem os limites dos voluntários';
	@override String get benefitKey => 'A chave é criada no seu celular e nunca é compartilhada';
	@override String get benefitFree => 'Tudo que é grátis continua grátis';
	@override String save({required Object pct}) => 'ECONOMIZE ${pct}%';
	@override String get yearly => 'Anual';
	@override String get monthly => 'Mensal';
	@override String get billedMonthly => 'cobrado mensalmente';
	@override String daysFree({required Object days}) => '${days} dias grátis';
	@override String perMonth({required Object price}) => '${price} por mês';
	@override String get title => 'G VPN Pro';
	@override String get heroTitleOneLine => 'Servidores mais rápidos, operados por nós';
	@override String get includes => 'Inclui';
	@override String get benefitLogs => 'Sem registros de atividade nos nossos servidores';
	@override String get plan => 'Escolha um plano';
	@override String get renewGeneric => 'As assinaturas renovam automaticamente até serem canceladas. Cancele quando quiser no Google Play.';
	@override String renewTrial({required Object days, required Object price, required Object period}) => '${days} dias grátis, depois ${price} por ${period}. Renova automaticamente até ser cancelada; cancele no Google Play pelo menos um dia antes do fim do teste para não ser cobrado.';
	@override String renew({required Object price, required Object period}) => '${price} por ${period}. Renova automaticamente até ser cancelada; cancele quando quiser no Google Play.';
	@override String get year => 'ano';
	@override String get month => 'mês';
	@override String get manage => 'Gerenciar assinatura';
	@override late final _Translations$pro$free$pt free = _Translations$pro$free$pt._(_root);
}

// Path: rules
class _Translations$rules$pt extends Translations$rules$en {
	_Translations$rules$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Regras';
	@override late final _Translations$rules$info$pt info = _Translations$rules$info$pt._(_root);
	@override String get protection => 'Proteção';
	@override String get shield => 'Escudo';
	@override String get shieldSub => 'Bloqueia sites de malware e phishing';
	@override String get privateDns => 'Escudo sem a VPN';
	@override String get privateDnsSub => 'Copie dns.quad9.net para o DNS privado';
	@override String get privateDnsCopied => 'dns.quad9.net copiado';
	@override String get privateDnsHow => 'Abra as Configurações, procure DNS privado, escolha "Nome do host do provedor de DNS privado" e cole.';
	@override String get stay => 'Manter conectado';
	@override String get alwaysOn => 'VPN sempre ativa';
	@override String get alwaysOnSub => 'O Android reinicia o G VPN se ele parar';
	@override String get battery => 'Bateria';
	@override String get batteryOk => 'Sem restrições';
	@override String get batteryRestricted => 'Restrita: pode parar em segundo plano';
	@override String get autoConnect => 'Conexão automática';
	@override String get autoOff => 'Desligada';
	@override String get autoOffSub => 'Só quando você tocar';
	@override String get autoOpen => 'Wi-Fi públicos';
	@override String get autoOpenSub => 'Redes abertas, WEP ou com página de login';
	@override String get autoAny => 'Qualquer Wi-Fi';
	@override String get autoAnySub => 'Qualquer rede Wi-Fi';
	@override String get apps => 'Apps';
	@override String get appsDirect => 'Apps diretos';
	@override String get appsNone => 'Todos os apps usam a VPN';
	@override String appsSome({required Object n}) => '${n} apps sem VPN';
	@override String get appearance => 'Aparência';
	@override String get themePhone => 'Celular';
	@override String get themeLight => 'Claro';
	@override String get themeDark => 'Escuro';
	@override String get about => 'Sobre';
}

// Path: apps
class _Translations$apps$pt extends Translations$apps$en {
	_Translations$apps$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Apps diretos';
	@override String get sheetSubtitle => 'Os apps escolhidos se conectam sem a VPN. O resto continua protegido.';
	@override String get whyTitle => 'Por que excluir um app';
	@override String get whyBody => 'Bancos e apps de pagamento costumam bloquear endereços de VPN, então pagamentos podem falhar pela VPN. Alguns serviços locais só funcionam a partir do seu país.';
	@override String get favouritesBody => 'Marque com estrela os apps que você muda com frequência; eles ficam no topo.';
	@override String get whileConnected => 'Enquanto conectado';
	@override String get whileConnectedBody => 'Alterar esta lista reconecta a VPN por um instante.';
	@override String search({required Object n}) => 'Buscar entre ${n} apps';
	@override String get skipping => 'Sem VPN';
	@override String get skippingNone => 'Nenhum. Todos os apps passam pela VPN.';
	@override String protectAgain({required Object app}) => 'Proteger ${app} de novo';
	@override String get banking => 'Bancos e pagamentos';
	@override String bankingFound({required Object n}) => '${n} encontrados que podem bloquear VPNs';
	@override String get addAll => 'Adicionar todos';
	@override String get favourites => 'Favoritos';
	@override String get all => 'Todos os apps';
	@override String found({required Object n}) => '${n} encontrados';
	@override String get noMatch => 'Nenhum app encontrado.';
	@override String showAll({required Object n}) => 'Mostrar todos os ${n}';
	@override String get skips => 'Sem VPN';
	@override String get unstar => 'Remover dos favoritos';
	@override String get star => 'Adicionar aos favoritos';
}

// Path: location
class _Translations$location$pt extends Translations$location$en {
	_Translations$location$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Permitir localização para o Wi-Fi';
	@override String get useHome => 'Mostrar o nome do Wi-Fi na tela inicial';
	@override String get useScan => 'Verificar redes e canais próximos';
	@override String get private => 'Fica neste celular. Sua localização nunca é coletada.';
	@override String get switchTitle => 'Ative a localização';
	@override String get switchBody => 'O Android esconde os nomes de Wi-Fi enquanto a localização está desligada';
}

// Path: addServer
class _Translations$addServer$pt extends Translations$addServer$en {
	_Translations$addServer$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get clipboardEmpty => 'A área de transferência está vazia.';
	@override String get title => 'Adicione seu servidor';
	@override String get body => 'Cole uma configuração WireGuard do seu roteador, VPS ou servidor em casa.';
	@override String get nameHint => 'Nome, por exemplo Roteador de casa';
	@override String get paste => 'Colar';
	@override String get save => 'Salvar servidor';
	@override String notWireguard({required Object error}) => 'Isto não é uma configuração WireGuard: ${error}';
}

// Path: button
class _Translations$button$pt extends Translations$button$en {
	_Translations$button$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get stop => 'Parar';
	@override String get connecting => 'Conectando';
	@override String get stopping => 'Parando';
	@override String get connect => 'Conectar';
	@override String get disconnect => 'Desconectar';
}

// Path: wol
class _Translations$wol$pt extends Translations$wol$en {
	_Translations$wol$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get info => 'Liga um computador ou NAS neste Wi-Fi, se o Wake on LAN estiver ativado nas configurações dele. Seu celular precisa estar na mesma rede; desligue a VPN antes.';
	@override String get badMac => 'Isso não é um endereço MAC. Ele tem este formato: AA:BB:CC:DD:EE:FF.';
	@override String get sent => 'Sinal enviado. O dispositivo deve ligar em até um minuto.';
	@override String get title => 'Wake on LAN';
	@override String get wake => 'Ligar dispositivo';
	@override String get mac => 'Endereço MAC';
	@override String failed({required Object error}) => 'Não foi possível enviar: ${error}';
}

// Path: speed
class _Translations$speed$pt extends Translations$speed$en {
	_Translations$speed$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get info => 'Medido pelo M-Lab, uma plataforma aberta de pesquisa. Cada teste usa cerca de 50 a 100 MB.\n\nResultados públicos: o M-Lab publica cada teste, incluindo o endereço IP de origem, como dados abertos de pesquisa.\n\nComparação de provedores: depois de um teste sem VPN, o G VPN envia só as três velocidades. O serviço de comparação identifica seu provedor e sua cidade pela própria conexão e não guarda nenhum endereço IP. Desligue com a chave no fim desta página.\n\nPela VPN: com a VPN ligada, mede a velocidade pelo túnel e compara com seu último teste sem ela.\n\nPrévia de vídeo: a mesma imagem na resolução que esta velocidade permite, segundo as taxas de bits que os serviços de streaming divulgam. Nenhum vídeo é baixado.';
	@override String get download => 'Download';
	@override String get upload => 'Upload';
	@override String get finding => 'Procurando um servidor';
	@override String get throughVpn => 'Pela VPN';
	@override String get directNoVpn => 'Direto, sem VPN';
	@override String get title => 'Teste de velocidade';
	@override String get stop => 'Parar';
	@override String get start => 'Iniciar teste';
	@override String get again => 'Testar de novo';
	@override String get viaVpn => 'Pela VPN';
	@override String get direct => 'Direto';
	@override String get mbps => 'Mbps';
	@override String get ping => 'PING';
	@override String get vsDirect => 'VS DIRETO';
	@override String get compare => 'Comparar com provedores próximos';
	@override String get compareSub => 'Compartilha só as velocidades, nunca seu IP';
	@override String get tierTv => 'TVs grandes';
	@override String get tierLaptopLarge => 'Notebooks grandes';
	@override String get tierTablet => 'Tablets e notebooks';
	@override String get tierPhone => 'Celulares';
	@override String get tierSmallPhone => 'Celulares pequenos';
	@override String get tierCalls => 'Chamadas e áudio';
	@override String get messagingOnly => 'Só mensagens';
	@override String get videoQuality => 'Qualidade de vídeo';
	@override String get preview => 'PRÉVIA';
	@override String get history => 'Histórico';
	@override String get clear => 'Limpar';
	@override String get viaVpnLower => 'pela VPN';
	@override String get directLower => 'direto';
	@override String get gradeA => 'Vários streams 4K e videochamadas ao mesmo tempo';
	@override String get gradeB => 'Streaming HD e videochamadas fluidas';
	@override String get gradeC => 'Um stream HD; chamadas podem falhar nos horários de pico';
	@override String get gradeD => 'Navegação e mensagens; vídeo trava';
	@override String get yourCountry => 'seu país';
	@override String get median => 'Download mediano, últimos 30 dias';
	@override String get fromUsers => 'Mbps · de testes de usuários do G VPN';
	@override String get costLittle => 'A VPN reduz pouco a velocidade';
	@override String get costNoticeable => 'Visivelmente mais lento que direto';
	@override String get costMuch => 'Bem mais lento. Tente outro servidor';
	@override String get ofDirect => 'da sua velocidade direta';
	@override String get none => 'nenhum';
	@override String ms({required Object n}) => '${n} ms';
	@override String previewTier({required Object tier}) => 'PRÉVIA · ${tier}';
	@override String streamsUpTo({required Object tier, required Object who}) => 'Streaming até ${tier} · ${who}';
	@override String today({required Object time}) => 'Hoje, ${time}';
	@override String tests({required Object n}) => '${n} testes';
	@override String gradeVpn({required Object label}) => '${label} pela VPN';
	@override String gradeIsp({required Object label, required Object isp}) => '${label} na ${isp}';
	@override String notEnough({required Object isp}) => 'Ainda não há testes suficientes da ${isp}';
	@override String get yourProvider => 'seu provedor';
	@override String rankLine({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} em ${where}: ${rank} de ${of}';
	@override String costLine({required Object note, required Object mbps}) => '${note} · direto ${mbps} Mbps';
	@override String mbpsValue({required Object v}) => '${v} Mbps';
	@override String get gradeExcellent => 'Excelente';
	@override String get gradeVeryGood => 'Muito boa';
	@override String get gradeGood => 'Boa';
	@override String get gradeFair => 'Razoável';
	@override String get gradeSlow => 'Lenta';
	@override String get gradeVerySlow => 'Muito lenta';
}

// Path: router
class _Translations$router$pt extends Translations$router$en {
	_Translations$router$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get info => 'Pergunta ao seu roteador, via UPnP, se os dispositivos podem abrir portas para a internet por conta própria, e lista as que já abriram. Só lê e não muda nada. Se nada precisar de UPnP (alguns videogames precisam), é mais seguro desligá-lo nas configurações do roteador.';
	@override String get title => 'Verificar roteador';
	@override String get asking => 'Consultando o roteador';
	@override String get again => 'Verificar de novo';
	@override String get check => 'Verificar roteador';
	@override String get off => 'UPnP desligado';
	@override String get offBody => 'Os dispositivos não conseguem abrir portas sozinhos.';
	@override String get onBody => 'Nenhuma porta aberta por ele agora.';
	@override String get checkEach => 'Confira se você reconhece cada uma.';
	@override String get cgnat => 'Endereço compartilhado do provedor: não é acessível pela internet.';
	@override String get noDescription => 'Sem descrição';
	@override String opened({required Object n}) => '${n} portas abertas por dispositivos';
	@override String routerName({required Object name}) => 'Roteador: ${name}';
	@override String externalIp({required Object ip}) => 'Endereço na internet: ${ip}';
	@override String mapping({required Object proto, required Object host}) => '${proto} para ${host}';
	@override String get upnpOn => 'UPnP ligado';
}

// Path: network
class _Translations$network$pt extends Translations$network$en {
	_Translations$network$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Esta rede';
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Dados móveis';
	@override String get ethernet => 'Ethernet';
	@override String get offline => 'Off-line';
	@override String get risky => 'Rede arriscada. Conecte a VPN aqui.';
	@override String get review => 'Vale conferir antes de confiar.';
	@override String get covered => 'Protegida pela VPN.';
	@override String get safe => 'Esta rede parece segura.';
	@override String get mobileSentence => 'Dados móveis.';
	@override String get notConnected => 'Sem conexão.';
	@override String get showName => 'Mostrar nome';
	@override String get sitesSee => 'Os sites veem';
	@override String get provider => 'Provedor';
	@override String get location => 'Localização';
	@override String get couldNotCheck => 'Não foi possível verificar';
	@override String get checking => 'Verificando';
	@override String get signal => 'Sinal';
	@override String get linkSpeed => 'Velocidade do link';
	@override String get gateway => 'Gateway';
	@override String get none => 'Nenhum';
	@override String get privateDns => 'DNS privado';
	@override String get automatic => 'Automático';
	@override String get off => 'Desligado';
	@override String get metered => 'Limitada';
	@override String get yes => 'Sim';
	@override String get no => 'Não';
	@override String readFailed({required Object error}) => 'Não foi possível ler a rede: ${error}';
}

// Path: devices
class _Translations$devices$pt extends Translations$devices$en {
	_Translations$devices$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get info => 'Chama cada endereço da faixa do seu Wi-Fi e pede que os dispositivos se apresentem. Um dispositivo que recusa também conta: a recusa prova que ele está lá.\n\nNomes: do que os dispositivos publicam (Bonjour, UPnP, nomes do Windows) e do seu roteador.\n\nDispositivos desconhecidos: o Android esconde os endereços de hardware dos apps, então um dispositivo silencioso sem nome não pode ser identificado. Confira a lista de dispositivos do seu roteador.\n\nNovo: um dispositivo que não apareceu na sua última verificação desta rede.';
	@override String get needWifi => 'Conecte-se primeiro a uma rede Wi-Fi.';
	@override String get title => 'Dispositivos';
	@override String get again => 'Verificar de novo';
	@override String get looking => 'Procurando dispositivos';
	@override String get nothingNew => 'Nada novo desde a última verificação';
	@override String get takes => 'Leva cerca de 30 segundos';
	@override String get all => 'Todos';
	@override String get phones => 'Celulares';
	@override String get tvs => 'TVs';
	@override String get computers => 'Computadores';
	@override String get other => 'Outros';
	@override String get thisPhone => 'Este celular';
	@override String get router => 'Roteador';
	@override String get unknown => 'Dispositivo desconhecido';
	@override String get address => 'Endereço';
	@override String get answersIn => 'Responde em';
	@override String get type => 'Tipo';
	@override String get notAnnounced => 'Não se apresentou. A lista de dispositivos do seu roteador pode dar o nome.';
	@override String get newBadge => 'NOVO';
	@override String scanning({required Object n}) => 'Verificando ${n} de 254';
	@override String get thisNetwork => 'esta rede';
	@override String newSince({required Object n}) => '${n} novos desde a última verificação';
	@override String showMore({required Object n}) => 'Mostrar mais ${n}';
	@override String ms({required Object n}) => '${n} ms';
	@override String onNetwork({required Object network}) => 'dispositivos em ${network}';
}

// Path: ping
class _Translations$ping$pt extends Translations$ping$en {
	_Translations$ping$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get info => 'Quanto tempo leva uma ida e volta até um servidor, medido a cada segundo no último minuto.\n\nJitter: quanto cada resposta varia em relação à anterior. Jitter alto é o que corta as chamadas.\n\nPerda: respostas que nunca voltaram.\n\nComo: apps Android não podem enviar ping clássico, então cada teste mede um handshake de conexão, que é a mesma ida e volta.';
	@override String get askTitle => 'Fazer ping em um host';
	@override String get askHint => 'example.com ou 192.168.1.10';
	@override String get cancel => 'Cancelar';
	@override String get title => 'Ping';
	@override String get router => 'Roteador';
	@override String get pause => 'Pausar';
	@override String get start => 'Iniciar';
	@override String get host => 'Host';
	@override String get live => 'Ao vivo';
	@override String get ago => 'há 60 s';
	@override String get min => 'MÍN';
	@override String get avg => 'MÉD';
	@override String get jitter => 'JITTER';
	@override String get loss => 'PERDA';
	@override String get goodFor => 'Bom o bastante para';
	@override String get calls => 'Videochamadas';
	@override String get games => 'Jogos online';
	@override String get streaming => 'Streaming';
	@override String get great => 'Ótimo';
	@override String get okay => 'Razoável';
	@override String get poor => 'Ruim';
	@override String get lost => 'perdido';
	@override String get now => 'agora';
}

// Path: status
class _Translations$status$pt extends Translations$status$en {
	_Translations$status$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get info => 'Conecta a cada serviço três vezes e mostra a resposta mais rápida.\n\nBloqueado aqui: um serviço que não responde diretamente, mas funciona pela VPN, está bloqueado pela sua rede ou pelo seu país.\n\nHistórico: as verificações das últimas 24 horas deste celular, guardadas só nele.';
	@override String get title => 'Status dos serviços';
	@override String get checking => 'Verificando';
	@override String get again => 'Verificar de novo';
	@override String get viaVpn => 'Verificado pela VPN';
	@override String get direct => 'Verificado diretamente';
	@override String get favourites => 'Favoritos';
	@override String get edit => 'Editar';
	@override String get last24 => 'Últimas 24 horas';
	@override String get ago => 'há 24 h';
	@override String get all => 'Todos os serviços';
	@override String get pickFour => 'Escolha até quatro';
	@override String get outage => 'Nem pela VPN: provavelmente fora do ar';
	@override String get blocked => 'Pode estar bloqueado nesta rede';
	@override String get connect => 'Conectar';
	@override String get blockedShort => 'Bloqueado';
	@override String get unreachable => 'Inacessível';
	@override String get now => 'agora';
	@override String checks({required Object n}) => '${n} verificações';
	@override String andMore({required Object first, required Object n}) => '${first} e mais ${n}';
	@override String notReachable({required Object who}) => '${who} inacessível';
}

// Path: tools
class _Translations$tools$pt extends Translations$tools$en {
	_Translations$tools$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get wifi => 'Wi-Fi';
	@override String get mobile => 'Dados móveis';
	@override String get ethernet => 'Ethernet';
	@override String get checking => 'Verificando';
	@override String get offline => 'Off-line';
	@override String get title => 'Ferramentas';
	@override String get networkDesc => 'Verificação de segurança, o que os sites veem, sinal, roteador e DNS.';
	@override String get internet => 'Conexão com a internet';
	@override String get speed => 'Teste de velocidade';
	@override String get speedDesc => 'Velocidade de download e upload, e a qualidade de vídeo que ela suporta.';
	@override String get ping => 'Ping';
	@override String get pingDesc => 'Tempo de resposta e jitter ao vivo para qualquer servidor ou seu roteador.';
	@override String get status => 'Status dos serviços';
	@override String get statusDesc => 'WhatsApp, YouTube ou Google estão acessíveis daqui, ou bloqueados?';
	@override String get trace => 'Traceroute';
	@override String get traceDesc => 'Cada roteador entre você e um site, e quanto tempo cada um leva.';
	@override String get security => 'Segurança da rede';
	@override String get devices => 'Dispositivos nesta rede';
	@override String get devicesDesc => 'Quem mais está no seu Wi-Fi: celulares, TVs, câmeras e computadores.';
	@override String get router => 'Verificar roteador';
	@override String get routerDesc => 'Se os dispositivos podem abrir portas no seu roteador sozinhos (UPnP).';
	@override String get ports => 'Portas abertas';
	@override String get portsDesc => 'Verifique seu roteador ou um servidor em busca de portas abertas perigosas.';
	@override String get utilities => 'Utilitários';
	@override String get wifiScanner => 'Scanner de Wi-Fi';
	@override String get wifiDesc => 'Redes próximas, a segurança delas e o canal menos congestionado.';
	@override String get wol => 'Wake on LAN';
	@override String get wolDesc => 'Ligue um computador ou NAS nesta rede.';
}

// Path: trace
class _Translations$trace$pt extends Translations$trace$en {
	_Translations$trace$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get info => 'Cada parada é um roteador por onde seu tráfego passa a caminho do site.\n\nSaltos silenciosos: muitos roteadores nunca respondem a esses testes. É normal e não é defeito.\n\nCom a VPN ligada: o caminho começa dentro do túnel, então sua rede e seu provedor ficam ocultos.\n\nComo: usa a ferramenta ping do próprio Android com limite de saltos, já que apps não podem enviar esses pacotes diretamente.';
	@override String get title => 'Traceroute';
	@override String get stop => 'Parar';
	@override String get trace => 'Rastrear';
	@override String get again => 'Rastrear de novo';
	@override String get destination => 'Destino';
	@override String get hops => 'SALTOS';
	@override String get answered => 'RESPONDERAM';
	@override String get total => 'TOTAL';
	@override String get thisPhone => 'Este celular';
	@override String get silentOne => '1 salto silencioso';
	@override String get yourRouter => 'Seu roteador';
	@override String ms({required Object n}) => '${n} ms';
	@override String silentMany({required Object n}) => '${n} saltos silenciosos';
	@override String hop({required Object n}) => 'Salto ${n}';
	@override String slowest({required Object ms, required Object hop}) => 'A maior parte do atraso, ${ms} ms, aparece no salto ${hop}: geralmente um cabo longo entre países ou um link congestionado.';
}

// Path: ports
class _Translations$ports$pt extends Translations$ports$en {
	_Translations$ports$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get ftpNote => 'Envia senhas sem criptografia.';
	@override String get sshNote => 'Acesso remoto. Tudo bem se foi você que configurou.';
	@override String get telnetNote => 'Acesso remoto sem criptografia; favorito das botnets.';
	@override String get dnsNote => 'Normal em um roteador.';
	@override String get web => 'Web (HTTP)';
	@override String get webNote => 'Geralmente a página de administração do roteador.';
	@override String get webTls => 'Web (HTTPS)';
	@override String get smb => 'Compartilhamento de arquivos do Windows';
	@override String get smbNote => 'Nunca deveria ficar exposto à internet.';
	@override String get rtsp => 'Transmissão de câmera RTSP';
	@override String get rtspNote => 'Pode haver uma câmera transmitindo aqui.';
	@override String get upnpNote => 'Permite que dispositivos abram portas do roteador sozinhos.';
	@override String get rdp => 'Área de Trabalho Remota';
	@override String get rdpNote => 'Uma porta de invasão comum.';
	@override String get vncNote => 'Compartilhamento de tela, muitas vezes sem senha.';
	@override String get tr069Note => 'Gerenciamento remoto pelo provedor.';
	@override String get webAlt => 'Web (alternativa)';
	@override String get webAltTls => 'Web (HTTPS alternativo)';
	@override String get title => 'Portas abertas';
	@override String get check => 'Verificar portas';
	@override String get address => 'Endereço do dispositivo ou servidor';
	@override String get risky => 'RISCO';
	@override String get review => 'REVISAR';
	@override String get normal => 'NORMAL';
	@override String info({required Object n}) => 'Verifica as ${n} portas que importam em roteadores e dispositivos domésticos e explica cada uma que estiver aberta.\n\nVerifique apenas dispositivos e servidores que sejam seus ou que você administre.';
	@override String checking({required Object n}) => 'Verificando ${n} portas';
	@override String yourRouter({required Object ip}) => 'Seu roteador é ${ip}';
	@override String noneOpen({required Object host}) => 'Nenhuma porta comum aberta em ${host}.';
}

// Path: wifi
class _Translations$wifi$pt extends Translations$wifi$en {
	_Translations$wifi$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Scanner de Wi-Fi';
	@override String get allow => 'Permitir verificação de Wi-Fi';
	@override String get needsPermission => 'Precisa da permissão de localização.';
	@override String get scanning => 'Verificando';
	@override String get again => 'Verificar de novo';
	@override String get failed => 'A verificação falhou';
	@override String get none => 'Nenhuma rede encontrada. A localização pode estar desligada.';
	@override String get hidden => 'Rede oculta';
	@override String nearby({required Object n}) => '${n} redes próximas';
	@override String bestChannel({required Object n}) => 'Canal de 2,4 GHz menos congestionado: ${n}';
	@override String weak({required Object n}) => '${n} abertas ou fracas';
	@override String get connectedPrefix => 'Conectada · ';
	@override String get permissionInfo => 'O Android só mostra as redes Wi-Fi próximas para apps com permissão de localização. O G VPN usa isso apenas para listar redes neste celular.';
	@override String get info => 'Lista as redes da última verificação do celular. O Android permite poucas verificações por minuto, então repetir rápido pode mostrar a mesma lista. O canal sugerido é o menos congestionado entre 1, 6 e 11, os três que não se sobrepõem.';
}

// Path: errors
class _Translations$errors$pt extends Translations$errors$en {
	_Translations$errors$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get notAuthorized => 'A permissão de VPN não foi concedida.';
	@override String get turnedOff => 'A VPN foi desligada pelo sistema ou por outro app.';
	@override String get busy => 'Já existe um pedido de permissão aberto.';
	@override String get cancelled => 'Conexão cancelada.';
	@override String badConfig({required Object error}) => 'A configuração deste servidor é inválida: ${error}';
	@override String get timeout => 'O servidor não respondeu.';
	@override String get refused => 'O servidor recusou a conexão.';
	@override String failed({required Object error}) => 'Não foi possível conectar: ${error}';
	@override String get tryAnother => 'Servidores grátis vêm e vão; tente outro.';
	@override String get downloadFailed => 'Não foi possível baixar as configurações deste servidor. Verifique sua conexão ou escolha outro servidor.';
}

// Path: scan
class _Translations$scan$pt extends Translations$scan$en {
	_Translations$scan$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get mobile => 'Dados móveis';
	@override String get ping => 'PING';
	@override String get noReply => 'Sem resposta';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, túnel';
	@override String get dnsTunnel => 'No túnel';
	@override String get privateDns => 'DNS privado';
	@override String get dnsIsp => 'Provedor, visível';
	@override String get network => 'REDE';
	@override String get offline => 'Off-line';
	@override String get open => 'Aberta, sem senha';
	@override String get wep => 'WEP, insegura';
	@override String get owe => 'Aberta, criptografada';
	@override String get enterprise => 'Corporativa';
	@override String get unknown => 'Desconhecida';
	@override String get wifi => 'WI-FI';
	@override String get signIn => 'Página de login';
	@override String ms({required Object n}) => '${n} ms';
	@override String covered({required Object what}) => '${what}, protegida';
}

// Path: legal
class _Translations$legal$pt extends Translations$legal$en {
	_Translations$legal$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get privacy => 'Política de privacidade';
	@override String get terms => 'Termos de uso';
	@override String get licences => 'Licenças de código aberto';
}

// Path: update
class _Translations$update$pt extends Translations$update$en {
	_Translations$update$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get ready => 'Uma atualização está pronta';
	@override String get restart => 'Reiniciar';
}

// Path: details
class _Translations$details$pt extends Translations$details$en {
	_Translations$details$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get share => 'Compartilhar';
	@override String connectedFor({required Object n}) => 'CONECTADO · ${n} MIN';
	@override String get notConnected => 'DESCONECTADO';
	@override String get downloaded => 'BAIXADO';
	@override String get uploaded => 'ENVIADO';
	@override String get lastUsed => 'ÚLTIMO USO';
	@override String get connection => 'Conexão';
	@override String get protocol => 'Protocolo';
	@override String get address => 'Seu endereço';
	@override String get dns => 'DNS';
	@override String get routes => 'Rotas';
	@override String get allTraffic => 'Todo o tráfego';
	@override String someRoutes({required Object n}) => '${n} redes';
	@override String get keepalive => 'Keepalive';
	@override String get serverKey => 'Chave do servidor';
	@override String get copy => 'Copiar';
	@override String get copied => 'Copiado';
	@override String get manage => 'Gerenciar';
	@override String get export => 'Exportar backup';
	@override String get exportSub => 'Todos os seus servidores em um arquivo';
}

// Path: share
class _Translations$share$pt extends Translations$share$en {
	_Translations$share$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String title({required Object name}) => 'Compartilhar ${name}';
	@override String get sameKey => 'Isto compartilha a chave deste celular. Quem tiver pode usar seu servidor como você, e só um aparelho pode ficar conectado com ela por vez.';
	@override String get scanHint => 'No outro celular: G VPN, Servidores, Ler QR. Uma imagem salva também funciona.';
	@override String get saveImage => 'Salvar imagem';
	@override String get send => 'Enviar';
}

// Path: add
class _Translations$add$pt extends Translations$add$en {
	_Translations$add$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Adicionar servidor';
	@override String get subtitle => 'Qualquer servidor WireGuard: roteador, VPS ou servidor em casa.';
	@override String get camera => 'Ler com a câmera';
	@override String get cameraSub => 'QR em outra tela';
	@override String get image => 'De uma imagem';
	@override String get imageSub => 'Captura de tela ou foto salva';
	@override String get noQr => 'Nenhum código QR nessa imagem.';
	@override String get tip => 'Recebeu o QR no WhatsApp ou Telegram? Toque em Compartilhar na imagem e escolha o G VPN.';
}

// Path: backup
class _Translations$backup$pt extends Translations$backup$en {
	_Translations$backup$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String restored({required Object n}) => '${n} servidores restaurados';
	@override String get nothingNew => 'Esses servidores já estão aqui';
}

// Path: gs
class _Translations$gs$pt extends Translations$gs$en {
	_Translations$gs$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get proRequired => 'Os G Servers são para assinantes do G VPN Pro.';
	@override String get off => 'Os G Servers estão desligados agora.';
	@override String get network => 'Não foi possível acessar os G Servers. Verifique sua conexão e tente de novo.';
	@override String get active => 'ATIVO';
	@override String get servers => 'G Servers';
	@override String busy({required Object n}) => '${n}% ocupado';
	@override String get offline => 'Off-line';
	@override String get devices => 'Seus aparelhos';
	@override String devicesSub({required Object n}) => 'Até ${n} celulares, cada um com sua chave';
	@override String get footnote => 'Cada celular recebe a própria chave, criada nele. Os G Servers não guardam registros de atividade.';
	@override String get leastBusy => 'O MENOS OCUPADO AGORA';
	@override String busyNoLogs({required Object n}) => '${n}% ocupado · sem registros';
	@override String subtitle({required Object country}) => 'G Server · ${country} · WireGuard';
	@override String get busyLabel => 'OCUPADO';
	@override String get status => 'STATUS';
	@override String get online => 'On-line';
	@override String get onThisServer => 'Neste servidor';
	@override String get thisPhone => 'Este celular';
	@override String get added => 'Adicionado · chave criada aqui';
	@override String get notAdded => 'Adicionado ao conectar';
	@override String get logs => 'Registros de atividade';
	@override String get noneKept => 'Nenhum guardado';
	@override String get privacy => 'O servidor só conhece este celular pela chave pública. Ele não registra os sites que você visita nem o tráfego que você envia.';
	@override String get stepPro1 => 'Instale o G VPN no celular com a mesma conta Google.';
	@override String get stepPro2 => 'Abra a aba Pro. O Pro é liberado sozinho, ou toque em Restaurar.';
	@override String get step3 => 'Toque em Conectar. O celular cria a chave e é adicionado aos G Servers. Sem QR e sem código.';
	@override String get stepFree1 => 'Instale o G VPN no celular.';
	@override String get stepFree2 => 'Abra a aba Pro.';
	@override String get devicesIntroPro => 'O Pro acompanha sua conta Google. Cada celular tem a própria chave, então um nunca derruba o outro.';
	@override String get devicesIntroFree => 'Cada celular tem a própria chave, então um nunca derruba o outro.';
	@override String get otherPhone => 'Outro celular';
	@override String lastConnected({required Object when}) => 'Última conexão ${when}';
	@override String get noDevices => 'Conecte-se a um G Server uma vez e seus celulares aparecem aqui.';
	@override String get addTitle => 'Adicionar celular ou reinstalar';
	@override String idle({required Object n}) => 'Um celular que não se conecta há ${n} dias é removido dos G Servers sozinho, então um celular antigo ou reinstalado nunca ocupa vaga.';
	@override String limitNote({required Object n}) => 'Até ${n} celulares por plano.';
	@override String fullTitle({required Object n}) => 'As ${n} vagas estão em uso';
	@override String get fullBody => 'Remova um celular que você não usa mais e este conecta na hora.';
	@override String get busyNow => 'Muitos celulares novos agora. Tente de novo daqui a pouco.';
	@override String get serverFull => 'Este servidor está cheio. Tente outro G Server.';
	@override String get ping => 'PING';
	@override String get last24 => 'Ocupação, últimas 24 horas';
	@override String get noHistory => 'O gráfico se preenche conforme o servidor é usado ao longo do dia.';
	@override String chartLabel({required Object max}) => 'Ocupação nas últimas 24 horas, no máximo ${max} por cento';
	@override String get hoursAgo => 'há 24 h';
	@override String get now => 'Agora';
}

// Path: home.status
class _Translations$home$status$pt extends Translations$home$status$en {
	_Translations$home$status$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get paused => 'Pausada';
	@override String get reconnecting => 'Reconectando';
	@override String get protected => 'Protegido';
	@override String get connecting => 'Conectando';
	@override String get stopping => 'Parando';
	@override String get notProtected => 'Sem proteção';
}

// Path: home.waves
class _Translations$home$waves$pt extends Translations$home$waves$en {
	_Translations$home$waves$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get encrypted => 'CRIPTOGRAFADO';
	@override String get securing => 'PROTEGENDO';
	@override String get exposed => 'EXPOSTO';
}

// Path: home.network
class _Translations$home$network$pt extends Translations$home$network$en {
	_Translations$home$network$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'ESTA REDE';
	@override String get wifi => 'Wi-Fi';
	@override String get offline => 'Off-line';
	@override String get showName => 'Mostrar nome';
	@override String get scanFailed => 'A verificação falhou. Ela roda de novo quando a rede mudar.';
}

// Path: home.card
class _Translations$home$card$pt extends Translations$home$card$en {
	_Translations$home$card$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get connectedVia => 'CONECTADO VIA';
	@override String get protocol => 'PROTOCOLO';
	@override String get dns => 'DNS';
	@override String get dnsQuad9 => 'Quad9, no túnel';
	@override String get dnsServer => 'Servidor, no túnel';
	@override String get downloaded => 'BAIXADO';
	@override String get uploaded => 'ENVIADO';
	@override String get wireguard => 'WireGuard';
	@override String openvpn({required Object proto}) => 'OpenVPN ${proto}';
	@override String get selected => 'SELECIONADO';
	@override String get browsingFrom => 'NAVEGANDO DE';
	@override String get disconnect => 'Desconectar';
	@override String get change => 'Trocar';
	@override String get enabled => 'Ativado';
	@override String get shield => 'ESCUDO';
}

// Path: home.tiles
class _Translations$home$tiles$pt extends Translations$home$tiles$en {
	_Translations$home$tiles$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get shield => 'Escudo';
	@override String get shieldOn => 'Bloqueia sites maliciosos';
	@override String get appsDirect => 'Apps diretos';
	@override String get appsAll => 'Todos os apps protegidos';
	@override String appsSkip({required Object n}) => '${n} sem VPN';
	@override String get autoConnect => 'Conexão automática';
	@override String get autoOpen => 'Em Wi-Fi públicos';
	@override String get autoAny => 'Em qualquer Wi-Fi';
	@override String get speed => 'Velocidade';
	@override String get speedTap => 'Toque para testar';
	@override String speedDirect({required Object mbps}) => 'Direto ${mbps} Mbps';
}

// Path: home.fastest
class _Translations$home$fastest$pt extends Translations$home$fastest$en {
	_Translations$home$fastest$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Servidor gratuito mais rápido';
	@override String get pickedFrom => 'Escolhido entre';
	@override String more({required Object n}) => '+${n}';
	@override String get finding => 'Procurando o servidor mais rápido';
	@override String get failed => 'Não foi possível carregar os servidores gratuitos';
	@override String get how => 'Como o servidor é escolhido';
	@override String get sheetBody => 'O G VPN conecta você ao servidor gratuito mais bem classificado agora, por velocidade, carga e tempo sem reiniciar. A classificação muda conforme os servidores entram e saem.';
}

// Path: home.ip
class _Translations$home$ip$pt extends Translations$home$ip$en {
	_Translations$home$ip$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'O que os sites veem';
	@override String get real => 'Sua localização real';
	@override String get vpn => 'Localização da VPN';
	@override String get address => 'Endereço IP';
	@override String get coordinates => 'Coordenadas';
	@override String get note => 'Estimada pelo seu IP. Nunca é guardada.';
	@override String get hide => 'Ocultar minha localização';
	@override String near({required Object place}) => 'Perto de ${place}';
}

// Path: servers.tabs
class _Translations$servers$tabs$pt extends Translations$servers$tabs$en {
	_Translations$servers$tabs$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get pro => 'Pro';
	@override String get free => 'Grátis';
	@override String get yours => 'Seus';
}

// Path: servers.sheet
class _Translations$servers$sheet$pt extends Translations$servers$sheet$en {
	_Translations$servers$sheet$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'De onde vêm os servidores';
	@override String get subtitle => 'Três tipos, uma lista';
	@override String get free => 'Servidores voluntários, verificados a cada duas horas. Seus operadores guardam registros de conexão por cerca de duas semanas.';
	@override String get pro => 'Operados por nós com WireGuard. Sem registros de atividade, sem conta.';
	@override String get yours => 'Qualquer servidor WireGuard seu: um roteador, um VPS ou um servidor em casa.';
}

// Path: servers.badges
class _Translations$servers$badges$pt extends Translations$servers$badges$en {
	_Translations$servers$badges$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get mostUsed => 'MAIS USADO';
	@override String get mostStable => 'MAIS ESTÁVEL';
	@override String get fastest => 'MAIS RÁPIDO';
}

// Path: servers.filters
class _Translations$servers$filters$pt extends Translations$servers$filters$en {
	_Translations$servers$filters$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get all => 'Todos';
	@override String get fastest => 'Mais rápidos';
	@override String get stable => 'Mais estáveis';
	@override String get popular => 'Populares';
}

// Path: servers.own
class _Translations$servers$own$pt extends Translations$servers$own$en {
	_Translations$servers$own$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Use seu próprio servidor';
	@override String get subtitle => 'Qualquer servidor WireGuard funciona';
	@override String get router => 'Um roteador';
	@override String get routerBody => 'Muitos roteadores têm WireGuard integrado. Exporte a configuração do cliente e leia o QR code aqui.';
	@override String get vps => 'Um VPS';
	@override String get vpsBody => 'Qualquer servidor Linux pequeno. Instale o WireGuard, crie um cliente e importe o arquivo de configuração.';
	@override String get home => 'Um servidor em casa';
	@override String get homeBody => 'Acesse sua própria rede de qualquer lugar, do mesmo jeito.';
	@override String get noneYet => 'Ainda não tem servidor?';
	@override String get addAnother => 'Adicionar outro';
	@override String get hint => 'Rode em um roteador, VPS ou servidor em casa';
}

// Path: pro.free
class _Translations$pro$free$pt extends Translations$pro$free$en {
	_Translations$pro$free$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Seu plano';
	@override String get headline => 'Tudo é grátis';
	@override String get body => 'Todos os servidores e todas as ferramentas, sem conta e sem anúncios.';
	@override String get included => 'Inclui';
	@override String get servers => 'Servidores grátis';
	@override String get serversSub => 'Classificados por velocidade e estabilidade em dezenas de países';
	@override String get own => 'Seus próprios servidores';
	@override String get ownSub => 'Conecte-se a qualquer roteador, VPS ou servidor em casa com WireGuard';
	@override String get shield => 'Escudo';
	@override String get shieldSub => 'Bloqueia sites conhecidos de malware e phishing';
	@override String get auto => 'Conexão automática e regras de apps';
	@override String get autoSub => 'Proteja Wi-Fi públicos; deixe os apps de banco irem direto';
	@override String get pause => 'Pausa e Configurações rápidas';
	@override String get pauseSub => 'Pause pela notificação, ligue pelo bloco';
	@override String get tools => 'Todas as ferramentas de rede';
	@override String get toolsSub => 'Teste de velocidade, ping, status de serviços, traceroute, dispositivos e mais';
	@override String get later => 'O G VPN Pro vai adicionar servidores mais rápidos operados por nós. Tudo acima continua grátis.';
}

// Path: rules.info
class _Translations$rules$info$pt extends Translations$rules$info$en {
	_Translations$rules$info$pt._(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get shield => 'O Escudo envia as consultas DNS ao Quad9, que recusa sites conhecidos de malware e phishing. Ele não bloqueia anúncios e, enquanto ligado, substitui o DNS do servidor.';
	@override String get autoConnect => 'Conexão automática: usa o servidor WireGuard que você escolheu. Desconectar manualmente pausa a função até você entrar em outra rede.';
	@override String get apps => 'Apps diretos: apps fora da VPN se conectam diretamente. Bancos costumam bloquear endereços de VPN, então pagamentos podem falhar pela VPN.';
	@override String get reconnect => 'Alterar o Escudo ou os apps reconecta a VPN por um instante.';
	@override String get stay => 'Manter conectado: alguns celulares encerram apps em segundo plano para economizar bateria. A VPN sempre ativa e a bateria sem restrições mantêm o G VPN funcionando.';
}

/// The flat map containing all translations for locale <pt>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsPt {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.gotIt' => 'Entendi',
			'common.about' => 'Sobre',
			'common.connect' => 'Conectar',
			'common.connected' => 'Conectado',
			'common.retry' => 'Tentar de novo',
			'common.ok' => 'OK',
			'common.remove' => 'Remover',
			'common.cancel' => 'Cancelar',
			'common.continueLabel' => 'Continuar',
			'common.notNow' => 'Agora não',
			'common.openSettings' => 'Abrir configurações',
			'common.close' => 'Fechar',
			'common.off' => 'Desligado',
			'common.changesReconnect' => 'As alterações reconectam a VPN',
			'nav.vpn' => 'VPN',
			'nav.servers' => 'Servidores',
			'nav.tools' => 'Ferramentas',
			'nav.rules' => 'Regras',
			'nav.pro' => 'Pro',
			'home.status.paused' => 'Pausada',
			'home.status.reconnecting' => 'Reconectando',
			'home.status.protected' => 'Protegido',
			'home.status.connecting' => 'Conectando',
			'home.status.stopping' => 'Parando',
			'home.status.notProtected' => 'Sem proteção',
			'home.resumesAt' => ({required Object time}) => 'Volta às ${time} · toque para retomar agora',
			'home.sitesSee' => ({required Object ip}) => 'Os sites veem ${ip}',
			'home.sitesSeeOrg' => ({required Object ip, required Object org}) => 'Os sites veem ${ip} · ${org}',
			'home.ipFailed' => 'Não foi possível verificar seu IP',
			'home.ipChecking' => 'Verificando seu IP',
			'home.themeSystem' => 'Tema: igual ao celular',
			'home.themeLight' => 'Tema: claro',
			'home.themeDark' => 'Tema: escuro',
			'home.free' => 'Grátis',
			'home.pickServer' => 'Escolha um servidor',
			'home.waves.encrypted' => 'CRIPTOGRAFADO',
			'home.waves.securing' => 'PROTEGENDO',
			'home.waves.exposed' => 'EXPOSTO',
			'home.network.title' => 'ESTA REDE',
			'home.network.wifi' => 'Wi-Fi',
			'home.network.offline' => 'Off-line',
			'home.network.showName' => 'Mostrar nome',
			'home.network.scanFailed' => 'A verificação falhou. Ela roda de novo quando a rede mudar.',
			'home.card.connectedVia' => 'CONECTADO VIA',
			'home.card.protocol' => 'PROTOCOLO',
			'home.card.dns' => 'DNS',
			'home.card.dnsQuad9' => 'Quad9, no túnel',
			'home.card.dnsServer' => 'Servidor, no túnel',
			'home.card.downloaded' => 'BAIXADO',
			'home.card.uploaded' => 'ENVIADO',
			'home.card.wireguard' => 'WireGuard',
			'home.card.openvpn' => ({required Object proto}) => 'OpenVPN ${proto}',
			'home.card.selected' => 'SELECIONADO',
			'home.card.browsingFrom' => 'NAVEGANDO DE',
			'home.card.disconnect' => 'Desconectar',
			'home.card.change' => 'Trocar',
			'home.card.enabled' => 'Ativado',
			'home.card.shield' => 'ESCUDO',
			'home.tiles.shield' => 'Escudo',
			'home.tiles.shieldOn' => 'Bloqueia sites maliciosos',
			'home.tiles.appsDirect' => 'Apps diretos',
			'home.tiles.appsAll' => 'Todos os apps protegidos',
			'home.tiles.appsSkip' => ({required Object n}) => '${n} sem VPN',
			'home.tiles.autoConnect' => 'Conexão automática',
			'home.tiles.autoOpen' => 'Em Wi-Fi públicos',
			'home.tiles.autoAny' => 'Em qualquer Wi-Fi',
			'home.tiles.speed' => 'Velocidade',
			'home.tiles.speedTap' => 'Toque para testar',
			'home.tiles.speedDirect' => ({required Object mbps}) => 'Direto ${mbps} Mbps',
			'home.fastest.title' => 'Servidor gratuito mais rápido',
			'home.fastest.pickedFrom' => 'Escolhido entre',
			'home.fastest.more' => ({required Object n}) => '+${n}',
			'home.fastest.finding' => 'Procurando o servidor mais rápido',
			'home.fastest.failed' => 'Não foi possível carregar os servidores gratuitos',
			'home.fastest.how' => 'Como o servidor é escolhido',
			'home.fastest.sheetBody' => 'O G VPN conecta você ao servidor gratuito mais bem classificado agora, por velocidade, carga e tempo sem reiniciar. A classificação muda conforme os servidores entram e saem.',
			'home.ip.title' => 'O que os sites veem',
			'home.ip.real' => 'Sua localização real',
			'home.ip.vpn' => 'Localização da VPN',
			'home.ip.address' => 'Endereço IP',
			'home.ip.coordinates' => 'Coordenadas',
			'home.ip.note' => 'Estimada pelo seu IP. Nunca é guardada.',
			'home.ip.hide' => 'Ocultar minha localização',
			'home.ip.near' => ({required Object place}) => 'Perto de ${place}',
			'servers.title' => 'Servidores',
			'servers.aboutServers' => 'Sobre os servidores',
			'servers.tabs.pro' => 'Pro',
			'servers.tabs.free' => 'Grátis',
			'servers.tabs.yours' => 'Seus',
			'servers.sheet.title' => 'De onde vêm os servidores',
			'servers.sheet.subtitle' => 'Três tipos, uma lista',
			'servers.sheet.free' => 'Servidores voluntários, verificados a cada duas horas. Seus operadores guardam registros de conexão por cerca de duas semanas.',
			'servers.sheet.pro' => 'Operados por nós com WireGuard. Sem registros de atividade, sem conta.',
			'servers.sheet.yours' => 'Qualquer servidor WireGuard seu: um roteador, um VPS ou um servidor em casa.',
			'servers.badges.mostUsed' => 'MAIS USADO',
			'servers.badges.mostStable' => 'MAIS ESTÁVEL',
			'servers.badges.fastest' => 'MAIS RÁPIDO',
			'servers.filters.all' => 'Todos',
			'servers.filters.fastest' => 'Mais rápidos',
			'servers.filters.stable' => 'Mais estáveis',
			'servers.filters.popular' => 'Populares',
			'servers.loadFailed' => 'Não foi possível carregar a lista',
			'servers.noServers' => 'Nenhum servidor agora',
			'servers.best' => 'O MELHOR PARA VOCÊ AGORA',
			'servers.topRanked' => 'O mais bem avaliado agora',
			'servers.addHeading' => 'ADICIONAR SERVIDOR',
			'servers.scanQr' => 'Ler QR',
			'servers.importFile' => 'Importar arquivo',
			'servers.paste' => 'Colar',
			'servers.own.title' => 'Use seu próprio servidor',
			'servers.own.subtitle' => 'Qualquer servidor WireGuard funciona',
			'servers.own.router' => 'Um roteador',
			'servers.own.routerBody' => 'Muitos roteadores têm WireGuard integrado. Exporte a configuração do cliente e leia o QR code aqui.',
			'servers.own.vps' => 'Um VPS',
			'servers.own.vpsBody' => 'Qualquer servidor Linux pequeno. Instale o WireGuard, crie um cliente e importe o arquivo de configuração.',
			'servers.own.home' => 'Um servidor em casa',
			'servers.own.homeBody' => 'Acesse sua própria rede de qualquer lugar, do mesmo jeito.',
			'servers.own.noneYet' => 'Ainda não tem servidor?',
			'servers.own.addAnother' => 'Adicionar outro',
			'servers.own.hint' => 'Rode em um roteador, VPS ou servidor em casa',
			'servers.configBroken' => 'A configuração precisa de atenção',
			'servers.connectedBadge' => 'CONECTADO',
			'servers.scannedServer' => 'Servidor lido',
			'servers.scanFailedTitle' => 'Não foi possível ler',
			'servers.scanFailedBody' => 'O leitor não está disponível neste celular.',
			'servers.importFailedTitle' => 'Não foi possível importar',
			'servers.importFailedBody' => 'Não foi possível ler esse arquivo.',
			'servers.renameTitle' => 'Renomear servidor',
			'servers.nameHint' => 'Nome, por exemplo Roteador de casa',
			'servers.save' => 'Salvar',
			'servers.rename' => 'Renomear',
			'servers.disconnect' => 'Desconectar',
			'servers.more' => 'Mais opções',
			'servers.justNow' => 'agora mesmo',
			'servers.minutesAgo' => ({required Object n}) => 'há ${n} min',
			'servers.hoursAgo' => ({required Object n}) => 'há ${n} h',
			'servers.daysAgo' => ({required Object n}) => 'há ${n} d',
			'servers.neverUsed' => 'Ainda não usado',
			'servers.lastUsed' => ({required Object when}) => 'Último uso ${when}',
			'servers.disconnectFirst' => 'Desconecte primeiro para remover',
			'servers.removeConfirm' => 'Remover este servidor do G VPN? As configurações dele são apagadas deste celular; o servidor em si não muda.',
			'pro.owned' => 'Você tem o Pro',
			'pro.waitingPlay' => 'Aguardando o Google Play',
			'pro.startTrial' => ({required Object days}) => 'Começar teste grátis de ${days} dias',
			'pro.thenYearly' => ({required Object price}) => 'Depois ${price} por ano. Cancele quando quiser no Google Play.',
			'pro.thenMonthly' => ({required Object price}) => 'Depois ${price} por mês. Cancele quando quiser no Google Play.',
			'pro.yearlyPrice' => ({required Object price}) => '${price} por ano. Cancele quando quiser no Google Play.',
			'pro.monthlyPrice' => ({required Object price}) => '${price} por mês. Cancele quando quiser no Google Play.',
			'pro.restore' => 'Restaurar',
			'pro.heroTitle' => 'Servidores mais rápidos,\noperados por nós',
			'pro.heroSubtitle' => 'WireGuard. Sem registros de atividade. Sem conta.',
			'pro.benefitSpeed' => 'Velocidade total, sem os limites dos voluntários',
			'pro.benefitKey' => 'A chave é criada no seu celular e nunca é compartilhada',
			'pro.benefitFree' => 'Tudo que é grátis continua grátis',
			'pro.save' => ({required Object pct}) => 'ECONOMIZE ${pct}%',
			'pro.yearly' => 'Anual',
			'pro.monthly' => 'Mensal',
			'pro.billedMonthly' => 'cobrado mensalmente',
			'pro.daysFree' => ({required Object days}) => '${days} dias grátis',
			'pro.perMonth' => ({required Object price}) => '${price} por mês',
			'pro.title' => 'G VPN Pro',
			'pro.heroTitleOneLine' => 'Servidores mais rápidos, operados por nós',
			'pro.includes' => 'Inclui',
			'pro.benefitLogs' => 'Sem registros de atividade nos nossos servidores',
			'pro.plan' => 'Escolha um plano',
			'pro.renewGeneric' => 'As assinaturas renovam automaticamente até serem canceladas. Cancele quando quiser no Google Play.',
			'pro.renewTrial' => ({required Object days, required Object price, required Object period}) => '${days} dias grátis, depois ${price} por ${period}. Renova automaticamente até ser cancelada; cancele no Google Play pelo menos um dia antes do fim do teste para não ser cobrado.',
			'pro.renew' => ({required Object price, required Object period}) => '${price} por ${period}. Renova automaticamente até ser cancelada; cancele quando quiser no Google Play.',
			'pro.year' => 'ano',
			'pro.month' => 'mês',
			'pro.manage' => 'Gerenciar assinatura',
			'pro.free.title' => 'Seu plano',
			'pro.free.headline' => 'Tudo é grátis',
			'pro.free.body' => 'Todos os servidores e todas as ferramentas, sem conta e sem anúncios.',
			'pro.free.included' => 'Inclui',
			'pro.free.servers' => 'Servidores grátis',
			'pro.free.serversSub' => 'Classificados por velocidade e estabilidade em dezenas de países',
			'pro.free.own' => 'Seus próprios servidores',
			'pro.free.ownSub' => 'Conecte-se a qualquer roteador, VPS ou servidor em casa com WireGuard',
			'pro.free.shield' => 'Escudo',
			'pro.free.shieldSub' => 'Bloqueia sites conhecidos de malware e phishing',
			'pro.free.auto' => 'Conexão automática e regras de apps',
			'pro.free.autoSub' => 'Proteja Wi-Fi públicos; deixe os apps de banco irem direto',
			'pro.free.pause' => 'Pausa e Configurações rápidas',
			'pro.free.pauseSub' => 'Pause pela notificação, ligue pelo bloco',
			'pro.free.tools' => 'Todas as ferramentas de rede',
			'pro.free.toolsSub' => 'Teste de velocidade, ping, status de serviços, traceroute, dispositivos e mais',
			'pro.free.later' => 'O G VPN Pro vai adicionar servidores mais rápidos operados por nós. Tudo acima continua grátis.',
			'rules.title' => 'Regras',
			'rules.info.shield' => 'O Escudo envia as consultas DNS ao Quad9, que recusa sites conhecidos de malware e phishing. Ele não bloqueia anúncios e, enquanto ligado, substitui o DNS do servidor.',
			'rules.info.autoConnect' => 'Conexão automática: usa o servidor WireGuard que você escolheu. Desconectar manualmente pausa a função até você entrar em outra rede.',
			'rules.info.apps' => 'Apps diretos: apps fora da VPN se conectam diretamente. Bancos costumam bloquear endereços de VPN, então pagamentos podem falhar pela VPN.',
			'rules.info.reconnect' => 'Alterar o Escudo ou os apps reconecta a VPN por um instante.',
			'rules.info.stay' => 'Manter conectado: alguns celulares encerram apps em segundo plano para economizar bateria. A VPN sempre ativa e a bateria sem restrições mantêm o G VPN funcionando.',
			'rules.protection' => 'Proteção',
			'rules.shield' => 'Escudo',
			'rules.shieldSub' => 'Bloqueia sites de malware e phishing',
			'rules.privateDns' => 'Escudo sem a VPN',
			'rules.privateDnsSub' => 'Copie dns.quad9.net para o DNS privado',
			'rules.privateDnsCopied' => 'dns.quad9.net copiado',
			'rules.privateDnsHow' => 'Abra as Configurações, procure DNS privado, escolha "Nome do host do provedor de DNS privado" e cole.',
			'rules.stay' => 'Manter conectado',
			'rules.alwaysOn' => 'VPN sempre ativa',
			'rules.alwaysOnSub' => 'O Android reinicia o G VPN se ele parar',
			'rules.battery' => 'Bateria',
			'rules.batteryOk' => 'Sem restrições',
			'rules.batteryRestricted' => 'Restrita: pode parar em segundo plano',
			'rules.autoConnect' => 'Conexão automática',
			'rules.autoOff' => 'Desligada',
			'rules.autoOffSub' => 'Só quando você tocar',
			'rules.autoOpen' => 'Wi-Fi públicos',
			'rules.autoOpenSub' => 'Redes abertas, WEP ou com página de login',
			'rules.autoAny' => 'Qualquer Wi-Fi',
			'rules.autoAnySub' => 'Qualquer rede Wi-Fi',
			'rules.apps' => 'Apps',
			'rules.appsDirect' => 'Apps diretos',
			'rules.appsNone' => 'Todos os apps usam a VPN',
			'rules.appsSome' => ({required Object n}) => '${n} apps sem VPN',
			'rules.appearance' => 'Aparência',
			'rules.themePhone' => 'Celular',
			'rules.themeLight' => 'Claro',
			'rules.themeDark' => 'Escuro',
			'rules.about' => 'Sobre',
			'apps.title' => 'Apps diretos',
			'apps.sheetSubtitle' => 'Os apps escolhidos se conectam sem a VPN. O resto continua protegido.',
			'apps.whyTitle' => 'Por que excluir um app',
			'apps.whyBody' => 'Bancos e apps de pagamento costumam bloquear endereços de VPN, então pagamentos podem falhar pela VPN. Alguns serviços locais só funcionam a partir do seu país.',
			'apps.favouritesBody' => 'Marque com estrela os apps que você muda com frequência; eles ficam no topo.',
			'apps.whileConnected' => 'Enquanto conectado',
			'apps.whileConnectedBody' => 'Alterar esta lista reconecta a VPN por um instante.',
			'apps.search' => ({required Object n}) => 'Buscar entre ${n} apps',
			'apps.skipping' => 'Sem VPN',
			'apps.skippingNone' => 'Nenhum. Todos os apps passam pela VPN.',
			'apps.protectAgain' => ({required Object app}) => 'Proteger ${app} de novo',
			'apps.banking' => 'Bancos e pagamentos',
			'apps.bankingFound' => ({required Object n}) => '${n} encontrados que podem bloquear VPNs',
			'apps.addAll' => 'Adicionar todos',
			'apps.favourites' => 'Favoritos',
			'apps.all' => 'Todos os apps',
			'apps.found' => ({required Object n}) => '${n} encontrados',
			'apps.noMatch' => 'Nenhum app encontrado.',
			'apps.showAll' => ({required Object n}) => 'Mostrar todos os ${n}',
			'apps.skips' => 'Sem VPN',
			'apps.unstar' => 'Remover dos favoritos',
			'apps.star' => 'Adicionar aos favoritos',
			'location.title' => 'Permitir localização para o Wi-Fi',
			'location.useHome' => 'Mostrar o nome do Wi-Fi na tela inicial',
			'location.useScan' => 'Verificar redes e canais próximos',
			'location.private' => 'Fica neste celular. Sua localização nunca é coletada.',
			'location.switchTitle' => 'Ative a localização',
			'location.switchBody' => 'O Android esconde os nomes de Wi-Fi enquanto a localização está desligada',
			'addServer.clipboardEmpty' => 'A área de transferência está vazia.',
			'addServer.title' => 'Adicione seu servidor',
			'addServer.body' => 'Cole uma configuração WireGuard do seu roteador, VPS ou servidor em casa.',
			'addServer.nameHint' => 'Nome, por exemplo Roteador de casa',
			'addServer.paste' => 'Colar',
			'addServer.save' => 'Salvar servidor',
			'addServer.notWireguard' => ({required Object error}) => 'Isto não é uma configuração WireGuard: ${error}',
			'button.stop' => 'Parar',
			'button.connecting' => 'Conectando',
			'button.stopping' => 'Parando',
			'button.connect' => 'Conectar',
			'button.disconnect' => 'Desconectar',
			'wol.info' => 'Liga um computador ou NAS neste Wi-Fi, se o Wake on LAN estiver ativado nas configurações dele. Seu celular precisa estar na mesma rede; desligue a VPN antes.',
			'wol.badMac' => 'Isso não é um endereço MAC. Ele tem este formato: AA:BB:CC:DD:EE:FF.',
			'wol.sent' => 'Sinal enviado. O dispositivo deve ligar em até um minuto.',
			'wol.title' => 'Wake on LAN',
			'wol.wake' => 'Ligar dispositivo',
			'wol.mac' => 'Endereço MAC',
			'wol.failed' => ({required Object error}) => 'Não foi possível enviar: ${error}',
			'speed.info' => 'Medido pelo M-Lab, uma plataforma aberta de pesquisa. Cada teste usa cerca de 50 a 100 MB.\n\nResultados públicos: o M-Lab publica cada teste, incluindo o endereço IP de origem, como dados abertos de pesquisa.\n\nComparação de provedores: depois de um teste sem VPN, o G VPN envia só as três velocidades. O serviço de comparação identifica seu provedor e sua cidade pela própria conexão e não guarda nenhum endereço IP. Desligue com a chave no fim desta página.\n\nPela VPN: com a VPN ligada, mede a velocidade pelo túnel e compara com seu último teste sem ela.\n\nPrévia de vídeo: a mesma imagem na resolução que esta velocidade permite, segundo as taxas de bits que os serviços de streaming divulgam. Nenhum vídeo é baixado.',
			'speed.download' => 'Download',
			'speed.upload' => 'Upload',
			'speed.finding' => 'Procurando um servidor',
			'speed.throughVpn' => 'Pela VPN',
			'speed.directNoVpn' => 'Direto, sem VPN',
			'speed.title' => 'Teste de velocidade',
			'speed.stop' => 'Parar',
			'speed.start' => 'Iniciar teste',
			'speed.again' => 'Testar de novo',
			'speed.viaVpn' => 'Pela VPN',
			'speed.direct' => 'Direto',
			'speed.mbps' => 'Mbps',
			'speed.ping' => 'PING',
			'speed.vsDirect' => 'VS DIRETO',
			'speed.compare' => 'Comparar com provedores próximos',
			'speed.compareSub' => 'Compartilha só as velocidades, nunca seu IP',
			'speed.tierTv' => 'TVs grandes',
			'speed.tierLaptopLarge' => 'Notebooks grandes',
			'speed.tierTablet' => 'Tablets e notebooks',
			'speed.tierPhone' => 'Celulares',
			'speed.tierSmallPhone' => 'Celulares pequenos',
			'speed.tierCalls' => 'Chamadas e áudio',
			'speed.messagingOnly' => 'Só mensagens',
			'speed.videoQuality' => 'Qualidade de vídeo',
			'speed.preview' => 'PRÉVIA',
			'speed.history' => 'Histórico',
			'speed.clear' => 'Limpar',
			'speed.viaVpnLower' => 'pela VPN',
			'speed.directLower' => 'direto',
			'speed.gradeA' => 'Vários streams 4K e videochamadas ao mesmo tempo',
			'speed.gradeB' => 'Streaming HD e videochamadas fluidas',
			'speed.gradeC' => 'Um stream HD; chamadas podem falhar nos horários de pico',
			'speed.gradeD' => 'Navegação e mensagens; vídeo trava',
			'speed.yourCountry' => 'seu país',
			'speed.median' => 'Download mediano, últimos 30 dias',
			'speed.fromUsers' => 'Mbps · de testes de usuários do G VPN',
			'speed.costLittle' => 'A VPN reduz pouco a velocidade',
			'speed.costNoticeable' => 'Visivelmente mais lento que direto',
			'speed.costMuch' => 'Bem mais lento. Tente outro servidor',
			'speed.ofDirect' => 'da sua velocidade direta',
			'speed.none' => 'nenhum',
			'speed.ms' => ({required Object n}) => '${n} ms',
			'speed.previewTier' => ({required Object tier}) => 'PRÉVIA · ${tier}',
			'speed.streamsUpTo' => ({required Object tier, required Object who}) => 'Streaming até ${tier} · ${who}',
			'speed.today' => ({required Object time}) => 'Hoje, ${time}',
			'speed.tests' => ({required Object n}) => '${n} testes',
			'speed.gradeVpn' => ({required Object label}) => '${label} pela VPN',
			'speed.gradeIsp' => ({required Object label, required Object isp}) => '${label} na ${isp}',
			'speed.notEnough' => ({required Object isp}) => 'Ainda não há testes suficientes da ${isp}',
			'speed.yourProvider' => 'seu provedor',
			'speed.rankLine' => ({required Object isp, required Object where, required Object rank, required Object of}) => '${isp} em ${where}: ${rank} de ${of}',
			'speed.costLine' => ({required Object note, required Object mbps}) => '${note} · direto ${mbps} Mbps',
			'speed.mbpsValue' => ({required Object v}) => '${v} Mbps',
			'speed.gradeExcellent' => 'Excelente',
			'speed.gradeVeryGood' => 'Muito boa',
			'speed.gradeGood' => 'Boa',
			'speed.gradeFair' => 'Razoável',
			'speed.gradeSlow' => 'Lenta',
			'speed.gradeVerySlow' => 'Muito lenta',
			'router.info' => 'Pergunta ao seu roteador, via UPnP, se os dispositivos podem abrir portas para a internet por conta própria, e lista as que já abriram. Só lê e não muda nada. Se nada precisar de UPnP (alguns videogames precisam), é mais seguro desligá-lo nas configurações do roteador.',
			'router.title' => 'Verificar roteador',
			'router.asking' => 'Consultando o roteador',
			'router.again' => 'Verificar de novo',
			'router.check' => 'Verificar roteador',
			'router.off' => 'UPnP desligado',
			'router.offBody' => 'Os dispositivos não conseguem abrir portas sozinhos.',
			'router.onBody' => 'Nenhuma porta aberta por ele agora.',
			'router.checkEach' => 'Confira se você reconhece cada uma.',
			'router.cgnat' => 'Endereço compartilhado do provedor: não é acessível pela internet.',
			'router.noDescription' => 'Sem descrição',
			'router.opened' => ({required Object n}) => '${n} portas abertas por dispositivos',
			'router.routerName' => ({required Object name}) => 'Roteador: ${name}',
			'router.externalIp' => ({required Object ip}) => 'Endereço na internet: ${ip}',
			'router.mapping' => ({required Object proto, required Object host}) => '${proto} para ${host}',
			'router.upnpOn' => 'UPnP ligado',
			'network.title' => 'Esta rede',
			'network.wifi' => 'Wi-Fi',
			'network.mobile' => 'Dados móveis',
			'network.ethernet' => 'Ethernet',
			'network.offline' => 'Off-line',
			'network.risky' => 'Rede arriscada. Conecte a VPN aqui.',
			'network.review' => 'Vale conferir antes de confiar.',
			'network.covered' => 'Protegida pela VPN.',
			'network.safe' => 'Esta rede parece segura.',
			'network.mobileSentence' => 'Dados móveis.',
			'network.notConnected' => 'Sem conexão.',
			'network.showName' => 'Mostrar nome',
			'network.sitesSee' => 'Os sites veem',
			'network.provider' => 'Provedor',
			'network.location' => 'Localização',
			'network.couldNotCheck' => 'Não foi possível verificar',
			'network.checking' => 'Verificando',
			'network.signal' => 'Sinal',
			'network.linkSpeed' => 'Velocidade do link',
			'network.gateway' => 'Gateway',
			'network.none' => 'Nenhum',
			'network.privateDns' => 'DNS privado',
			'network.automatic' => 'Automático',
			'network.off' => 'Desligado',
			'network.metered' => 'Limitada',
			'network.yes' => 'Sim',
			'network.no' => 'Não',
			'network.readFailed' => ({required Object error}) => 'Não foi possível ler a rede: ${error}',
			'devices.info' => 'Chama cada endereço da faixa do seu Wi-Fi e pede que os dispositivos se apresentem. Um dispositivo que recusa também conta: a recusa prova que ele está lá.\n\nNomes: do que os dispositivos publicam (Bonjour, UPnP, nomes do Windows) e do seu roteador.\n\nDispositivos desconhecidos: o Android esconde os endereços de hardware dos apps, então um dispositivo silencioso sem nome não pode ser identificado. Confira a lista de dispositivos do seu roteador.\n\nNovo: um dispositivo que não apareceu na sua última verificação desta rede.',
			'devices.needWifi' => 'Conecte-se primeiro a uma rede Wi-Fi.',
			'devices.title' => 'Dispositivos',
			'devices.again' => 'Verificar de novo',
			'devices.looking' => 'Procurando dispositivos',
			'devices.nothingNew' => 'Nada novo desde a última verificação',
			'devices.takes' => 'Leva cerca de 30 segundos',
			'devices.all' => 'Todos',
			'devices.phones' => 'Celulares',
			'devices.tvs' => 'TVs',
			'devices.computers' => 'Computadores',
			'devices.other' => 'Outros',
			'devices.thisPhone' => 'Este celular',
			'devices.router' => 'Roteador',
			'devices.unknown' => 'Dispositivo desconhecido',
			'devices.address' => 'Endereço',
			'devices.answersIn' => 'Responde em',
			'devices.type' => 'Tipo',
			'devices.notAnnounced' => 'Não se apresentou. A lista de dispositivos do seu roteador pode dar o nome.',
			'devices.newBadge' => 'NOVO',
			'devices.scanning' => ({required Object n}) => 'Verificando ${n} de 254',
			'devices.thisNetwork' => 'esta rede',
			'devices.newSince' => ({required Object n}) => '${n} novos desde a última verificação',
			'devices.showMore' => ({required Object n}) => 'Mostrar mais ${n}',
			'devices.ms' => ({required Object n}) => '${n} ms',
			'devices.onNetwork' => ({required Object network}) => 'dispositivos em ${network}',
			'ping.info' => 'Quanto tempo leva uma ida e volta até um servidor, medido a cada segundo no último minuto.\n\nJitter: quanto cada resposta varia em relação à anterior. Jitter alto é o que corta as chamadas.\n\nPerda: respostas que nunca voltaram.\n\nComo: apps Android não podem enviar ping clássico, então cada teste mede um handshake de conexão, que é a mesma ida e volta.',
			'ping.askTitle' => 'Fazer ping em um host',
			'ping.askHint' => 'example.com ou 192.168.1.10',
			'ping.cancel' => 'Cancelar',
			'ping.title' => 'Ping',
			'ping.router' => 'Roteador',
			'ping.pause' => 'Pausar',
			'ping.start' => 'Iniciar',
			'ping.host' => 'Host',
			'ping.live' => 'Ao vivo',
			'ping.ago' => 'há 60 s',
			'ping.min' => 'MÍN',
			'ping.avg' => 'MÉD',
			'ping.jitter' => 'JITTER',
			'ping.loss' => 'PERDA',
			'ping.goodFor' => 'Bom o bastante para',
			'ping.calls' => 'Videochamadas',
			'ping.games' => 'Jogos online',
			'ping.streaming' => 'Streaming',
			'ping.great' => 'Ótimo',
			'ping.okay' => 'Razoável',
			'ping.poor' => 'Ruim',
			'ping.lost' => 'perdido',
			'ping.now' => 'agora',
			'status.info' => 'Conecta a cada serviço três vezes e mostra a resposta mais rápida.\n\nBloqueado aqui: um serviço que não responde diretamente, mas funciona pela VPN, está bloqueado pela sua rede ou pelo seu país.\n\nHistórico: as verificações das últimas 24 horas deste celular, guardadas só nele.',
			'status.title' => 'Status dos serviços',
			'status.checking' => 'Verificando',
			'status.again' => 'Verificar de novo',
			'status.viaVpn' => 'Verificado pela VPN',
			'status.direct' => 'Verificado diretamente',
			'status.favourites' => 'Favoritos',
			'status.edit' => 'Editar',
			'status.last24' => 'Últimas 24 horas',
			'status.ago' => 'há 24 h',
			'status.all' => 'Todos os serviços',
			'status.pickFour' => 'Escolha até quatro',
			'status.outage' => 'Nem pela VPN: provavelmente fora do ar',
			'status.blocked' => 'Pode estar bloqueado nesta rede',
			'status.connect' => 'Conectar',
			'status.blockedShort' => 'Bloqueado',
			'status.unreachable' => 'Inacessível',
			'status.now' => 'agora',
			'status.checks' => ({required Object n}) => '${n} verificações',
			'status.andMore' => ({required Object first, required Object n}) => '${first} e mais ${n}',
			'status.notReachable' => ({required Object who}) => '${who} inacessível',
			'tools.wifi' => 'Wi-Fi',
			'tools.mobile' => 'Dados móveis',
			'tools.ethernet' => 'Ethernet',
			'tools.checking' => 'Verificando',
			'tools.offline' => 'Off-line',
			'tools.title' => 'Ferramentas',
			'tools.networkDesc' => 'Verificação de segurança, o que os sites veem, sinal, roteador e DNS.',
			'tools.internet' => 'Conexão com a internet',
			'tools.speed' => 'Teste de velocidade',
			'tools.speedDesc' => 'Velocidade de download e upload, e a qualidade de vídeo que ela suporta.',
			'tools.ping' => 'Ping',
			'tools.pingDesc' => 'Tempo de resposta e jitter ao vivo para qualquer servidor ou seu roteador.',
			'tools.status' => 'Status dos serviços',
			'tools.statusDesc' => 'WhatsApp, YouTube ou Google estão acessíveis daqui, ou bloqueados?',
			'tools.trace' => 'Traceroute',
			'tools.traceDesc' => 'Cada roteador entre você e um site, e quanto tempo cada um leva.',
			'tools.security' => 'Segurança da rede',
			'tools.devices' => 'Dispositivos nesta rede',
			'tools.devicesDesc' => 'Quem mais está no seu Wi-Fi: celulares, TVs, câmeras e computadores.',
			'tools.router' => 'Verificar roteador',
			'tools.routerDesc' => 'Se os dispositivos podem abrir portas no seu roteador sozinhos (UPnP).',
			'tools.ports' => 'Portas abertas',
			'tools.portsDesc' => 'Verifique seu roteador ou um servidor em busca de portas abertas perigosas.',
			'tools.utilities' => 'Utilitários',
			'tools.wifiScanner' => 'Scanner de Wi-Fi',
			'tools.wifiDesc' => 'Redes próximas, a segurança delas e o canal menos congestionado.',
			'tools.wol' => 'Wake on LAN',
			'tools.wolDesc' => 'Ligue um computador ou NAS nesta rede.',
			'trace.info' => 'Cada parada é um roteador por onde seu tráfego passa a caminho do site.\n\nSaltos silenciosos: muitos roteadores nunca respondem a esses testes. É normal e não é defeito.\n\nCom a VPN ligada: o caminho começa dentro do túnel, então sua rede e seu provedor ficam ocultos.\n\nComo: usa a ferramenta ping do próprio Android com limite de saltos, já que apps não podem enviar esses pacotes diretamente.',
			'trace.title' => 'Traceroute',
			'trace.stop' => 'Parar',
			'trace.trace' => 'Rastrear',
			'trace.again' => 'Rastrear de novo',
			'trace.destination' => 'Destino',
			'trace.hops' => 'SALTOS',
			'trace.answered' => 'RESPONDERAM',
			'trace.total' => 'TOTAL',
			'trace.thisPhone' => 'Este celular',
			'trace.silentOne' => '1 salto silencioso',
			'trace.yourRouter' => 'Seu roteador',
			'trace.ms' => ({required Object n}) => '${n} ms',
			'trace.silentMany' => ({required Object n}) => '${n} saltos silenciosos',
			'trace.hop' => ({required Object n}) => 'Salto ${n}',
			'trace.slowest' => ({required Object ms, required Object hop}) => 'A maior parte do atraso, ${ms} ms, aparece no salto ${hop}: geralmente um cabo longo entre países ou um link congestionado.',
			'ports.ftpNote' => 'Envia senhas sem criptografia.',
			'ports.sshNote' => 'Acesso remoto. Tudo bem se foi você que configurou.',
			'ports.telnetNote' => 'Acesso remoto sem criptografia; favorito das botnets.',
			'ports.dnsNote' => 'Normal em um roteador.',
			'ports.web' => 'Web (HTTP)',
			'ports.webNote' => 'Geralmente a página de administração do roteador.',
			'ports.webTls' => 'Web (HTTPS)',
			'ports.smb' => 'Compartilhamento de arquivos do Windows',
			'ports.smbNote' => 'Nunca deveria ficar exposto à internet.',
			'ports.rtsp' => 'Transmissão de câmera RTSP',
			'ports.rtspNote' => 'Pode haver uma câmera transmitindo aqui.',
			'ports.upnpNote' => 'Permite que dispositivos abram portas do roteador sozinhos.',
			'ports.rdp' => 'Área de Trabalho Remota',
			'ports.rdpNote' => 'Uma porta de invasão comum.',
			'ports.vncNote' => 'Compartilhamento de tela, muitas vezes sem senha.',
			'ports.tr069Note' => 'Gerenciamento remoto pelo provedor.',
			'ports.webAlt' => 'Web (alternativa)',
			'ports.webAltTls' => 'Web (HTTPS alternativo)',
			'ports.title' => 'Portas abertas',
			'ports.check' => 'Verificar portas',
			'ports.address' => 'Endereço do dispositivo ou servidor',
			'ports.risky' => 'RISCO',
			'ports.review' => 'REVISAR',
			_ => null,
		} ?? switch (path) {
			'ports.normal' => 'NORMAL',
			'ports.info' => ({required Object n}) => 'Verifica as ${n} portas que importam em roteadores e dispositivos domésticos e explica cada uma que estiver aberta.\n\nVerifique apenas dispositivos e servidores que sejam seus ou que você administre.',
			'ports.checking' => ({required Object n}) => 'Verificando ${n} portas',
			'ports.yourRouter' => ({required Object ip}) => 'Seu roteador é ${ip}',
			'ports.noneOpen' => ({required Object host}) => 'Nenhuma porta comum aberta em ${host}.',
			'wifi.title' => 'Scanner de Wi-Fi',
			'wifi.allow' => 'Permitir verificação de Wi-Fi',
			'wifi.needsPermission' => 'Precisa da permissão de localização.',
			'wifi.scanning' => 'Verificando',
			'wifi.again' => 'Verificar de novo',
			'wifi.failed' => 'A verificação falhou',
			'wifi.none' => 'Nenhuma rede encontrada. A localização pode estar desligada.',
			'wifi.hidden' => 'Rede oculta',
			'wifi.nearby' => ({required Object n}) => '${n} redes próximas',
			'wifi.bestChannel' => ({required Object n}) => 'Canal de 2,4 GHz menos congestionado: ${n}',
			'wifi.weak' => ({required Object n}) => '${n} abertas ou fracas',
			'wifi.connectedPrefix' => 'Conectada · ',
			'wifi.permissionInfo' => 'O Android só mostra as redes Wi-Fi próximas para apps com permissão de localização. O G VPN usa isso apenas para listar redes neste celular.',
			'wifi.info' => 'Lista as redes da última verificação do celular. O Android permite poucas verificações por minuto, então repetir rápido pode mostrar a mesma lista. O canal sugerido é o menos congestionado entre 1, 6 e 11, os três que não se sobrepõem.',
			'errors.notAuthorized' => 'A permissão de VPN não foi concedida.',
			'errors.turnedOff' => 'A VPN foi desligada pelo sistema ou por outro app.',
			'errors.busy' => 'Já existe um pedido de permissão aberto.',
			'errors.cancelled' => 'Conexão cancelada.',
			'errors.badConfig' => ({required Object error}) => 'A configuração deste servidor é inválida: ${error}',
			'errors.timeout' => 'O servidor não respondeu.',
			'errors.refused' => 'O servidor recusou a conexão.',
			'errors.failed' => ({required Object error}) => 'Não foi possível conectar: ${error}',
			'errors.tryAnother' => 'Servidores grátis vêm e vão; tente outro.',
			'errors.downloadFailed' => 'Não foi possível baixar as configurações deste servidor. Verifique sua conexão ou escolha outro servidor.',
			'scan.mobile' => 'Dados móveis',
			'scan.ping' => 'PING',
			'scan.noReply' => 'Sem resposta',
			'scan.dns' => 'DNS',
			'scan.dnsQuad9' => 'Quad9, túnel',
			'scan.dnsTunnel' => 'No túnel',
			'scan.privateDns' => 'DNS privado',
			'scan.dnsIsp' => 'Provedor, visível',
			'scan.network' => 'REDE',
			'scan.offline' => 'Off-line',
			'scan.open' => 'Aberta, sem senha',
			'scan.wep' => 'WEP, insegura',
			'scan.owe' => 'Aberta, criptografada',
			'scan.enterprise' => 'Corporativa',
			'scan.unknown' => 'Desconhecida',
			'scan.wifi' => 'WI-FI',
			'scan.signIn' => 'Página de login',
			'scan.ms' => ({required Object n}) => '${n} ms',
			'scan.covered' => ({required Object what}) => '${what}, protegida',
			'legal.privacy' => 'Política de privacidade',
			'legal.terms' => 'Termos de uso',
			'legal.licences' => 'Licenças de código aberto',
			'update.ready' => 'Uma atualização está pronta',
			'update.restart' => 'Reiniciar',
			'details.share' => 'Compartilhar',
			'details.connectedFor' => ({required Object n}) => 'CONECTADO · ${n} MIN',
			'details.notConnected' => 'DESCONECTADO',
			'details.downloaded' => 'BAIXADO',
			'details.uploaded' => 'ENVIADO',
			'details.lastUsed' => 'ÚLTIMO USO',
			'details.connection' => 'Conexão',
			'details.protocol' => 'Protocolo',
			'details.address' => 'Seu endereço',
			'details.dns' => 'DNS',
			'details.routes' => 'Rotas',
			'details.allTraffic' => 'Todo o tráfego',
			'details.someRoutes' => ({required Object n}) => '${n} redes',
			'details.keepalive' => 'Keepalive',
			'details.serverKey' => 'Chave do servidor',
			'details.copy' => 'Copiar',
			'details.copied' => 'Copiado',
			'details.manage' => 'Gerenciar',
			'details.export' => 'Exportar backup',
			'details.exportSub' => 'Todos os seus servidores em um arquivo',
			'share.title' => ({required Object name}) => 'Compartilhar ${name}',
			'share.sameKey' => 'Isto compartilha a chave deste celular. Quem tiver pode usar seu servidor como você, e só um aparelho pode ficar conectado com ela por vez.',
			'share.scanHint' => 'No outro celular: G VPN, Servidores, Ler QR. Uma imagem salva também funciona.',
			'share.saveImage' => 'Salvar imagem',
			'share.send' => 'Enviar',
			'add.title' => 'Adicionar servidor',
			'add.subtitle' => 'Qualquer servidor WireGuard: roteador, VPS ou servidor em casa.',
			'add.camera' => 'Ler com a câmera',
			'add.cameraSub' => 'QR em outra tela',
			'add.image' => 'De uma imagem',
			'add.imageSub' => 'Captura de tela ou foto salva',
			'add.noQr' => 'Nenhum código QR nessa imagem.',
			'add.tip' => 'Recebeu o QR no WhatsApp ou Telegram? Toque em Compartilhar na imagem e escolha o G VPN.',
			'backup.restored' => ({required Object n}) => '${n} servidores restaurados',
			'backup.nothingNew' => 'Esses servidores já estão aqui',
			'gs.proRequired' => 'Os G Servers são para assinantes do G VPN Pro.',
			'gs.off' => 'Os G Servers estão desligados agora.',
			'gs.network' => 'Não foi possível acessar os G Servers. Verifique sua conexão e tente de novo.',
			'gs.active' => 'ATIVO',
			'gs.servers' => 'G Servers',
			'gs.busy' => ({required Object n}) => '${n}% ocupado',
			'gs.offline' => 'Off-line',
			'gs.devices' => 'Seus aparelhos',
			'gs.devicesSub' => ({required Object n}) => 'Até ${n} celulares, cada um com sua chave',
			'gs.footnote' => 'Cada celular recebe a própria chave, criada nele. Os G Servers não guardam registros de atividade.',
			'gs.leastBusy' => 'O MENOS OCUPADO AGORA',
			'gs.busyNoLogs' => ({required Object n}) => '${n}% ocupado · sem registros',
			'gs.subtitle' => ({required Object country}) => 'G Server · ${country} · WireGuard',
			'gs.busyLabel' => 'OCUPADO',
			'gs.status' => 'STATUS',
			'gs.online' => 'On-line',
			'gs.onThisServer' => 'Neste servidor',
			'gs.thisPhone' => 'Este celular',
			'gs.added' => 'Adicionado · chave criada aqui',
			'gs.notAdded' => 'Adicionado ao conectar',
			'gs.logs' => 'Registros de atividade',
			'gs.noneKept' => 'Nenhum guardado',
			'gs.privacy' => 'O servidor só conhece este celular pela chave pública. Ele não registra os sites que você visita nem o tráfego que você envia.',
			'gs.stepPro1' => 'Instale o G VPN no celular com a mesma conta Google.',
			'gs.stepPro2' => 'Abra a aba Pro. O Pro é liberado sozinho, ou toque em Restaurar.',
			'gs.step3' => 'Toque em Conectar. O celular cria a chave e é adicionado aos G Servers. Sem QR e sem código.',
			'gs.stepFree1' => 'Instale o G VPN no celular.',
			'gs.stepFree2' => 'Abra a aba Pro.',
			'gs.devicesIntroPro' => 'O Pro acompanha sua conta Google. Cada celular tem a própria chave, então um nunca derruba o outro.',
			'gs.devicesIntroFree' => 'Cada celular tem a própria chave, então um nunca derruba o outro.',
			'gs.otherPhone' => 'Outro celular',
			'gs.lastConnected' => ({required Object when}) => 'Última conexão ${when}',
			'gs.noDevices' => 'Conecte-se a um G Server uma vez e seus celulares aparecem aqui.',
			'gs.addTitle' => 'Adicionar celular ou reinstalar',
			'gs.idle' => ({required Object n}) => 'Um celular que não se conecta há ${n} dias é removido dos G Servers sozinho, então um celular antigo ou reinstalado nunca ocupa vaga.',
			'gs.limitNote' => ({required Object n}) => 'Até ${n} celulares por plano.',
			'gs.fullTitle' => ({required Object n}) => 'As ${n} vagas estão em uso',
			'gs.fullBody' => 'Remova um celular que você não usa mais e este conecta na hora.',
			'gs.busyNow' => 'Muitos celulares novos agora. Tente de novo daqui a pouco.',
			'gs.serverFull' => 'Este servidor está cheio. Tente outro G Server.',
			'gs.ping' => 'PING',
			'gs.last24' => 'Ocupação, últimas 24 horas',
			'gs.noHistory' => 'O gráfico se preenche conforme o servidor é usado ao longo do dia.',
			'gs.chartLabel' => ({required Object max}) => 'Ocupação nas últimas 24 horas, no máximo ${max} por cento',
			'gs.hoursAgo' => 'há 24 h',
			'gs.now' => 'Agora',
			_ => null,
		};
	}
}
