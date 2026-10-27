#!/usr/bin/env python3
"""Adds the G VPN desklet's text to assets/i18n/<lang>.json.

    python3 tool/add_vpn_strings.py      (from apps/g_launcher)

Only adds keys a file does not have, so it is safe to run again and never
overwrites a translator's change. Languages not listed below fall back to
English, as Translations does for every missing key.
"""
import json
import pathlib

S = {
    'en': {'desklet_spec.vpn': 'VPN', 'gvpn.protected': 'Protected', 'gvpn.protectedDetail': 'Your connection is encrypted',
           'gvpn.reconnecting': 'Reconnecting', 'gvpn.networkChanged': 'network changed', 'gvpn.connecting': 'Connecting',
           'gvpn.paused': 'Paused', 'gvpn.resumesIn': 'resumes in {0} min', 'gvpn.off': 'Not protected',
           'gvpn.offDetail': 'Tap to connect', 'gvpn.getTitle': 'VPN', 'gvpn.getDetail': 'Free, from the makers of G Launcher',
           'gvpn.get': 'Get G VPN', 'gvpn.unavailableDetail': 'Tap to open G VPN', 'gvpn.open': 'Open G VPN',
           'gvpn.connect': 'Connect', 'gvpn.disconnect': 'Disconnect', 'gvpn.resume': 'Resume now'},
    'es': {'desklet_spec.vpn': 'VPN', 'gvpn.protected': 'Protegido', 'gvpn.protectedDetail': 'Tu conexión está cifrada',
           'gvpn.reconnecting': 'Reconectando', 'gvpn.networkChanged': 'cambió la red', 'gvpn.connecting': 'Conectando',
           'gvpn.paused': 'En pausa', 'gvpn.resumesIn': 'se reanuda en {0} min', 'gvpn.off': 'Sin protección',
           'gvpn.offDetail': 'Toca para conectar', 'gvpn.getTitle': 'VPN', 'gvpn.getDetail': 'Gratis, de los creadores de G Launcher',
           'gvpn.get': 'Obtener G VPN', 'gvpn.unavailableDetail': 'Toca para abrir G VPN', 'gvpn.open': 'Abrir G VPN',
           'gvpn.connect': 'Conectar', 'gvpn.disconnect': 'Desconectar', 'gvpn.resume': 'Reanudar ahora'},
    'pt': {'desklet_spec.vpn': 'VPN', 'gvpn.protected': 'Protegido', 'gvpn.protectedDetail': 'Sua conexão está criptografada',
           'gvpn.reconnecting': 'Reconectando', 'gvpn.networkChanged': 'a rede mudou', 'gvpn.connecting': 'Conectando',
           'gvpn.paused': 'Pausada', 'gvpn.resumesIn': 'volta em {0} min', 'gvpn.off': 'Sem proteção',
           'gvpn.offDetail': 'Toque para conectar', 'gvpn.getTitle': 'VPN', 'gvpn.getDetail': 'Grátis, dos criadores do G Launcher',
           'gvpn.get': 'Baixar G VPN', 'gvpn.unavailableDetail': 'Toque para abrir o G VPN', 'gvpn.open': 'Abrir G VPN',
           'gvpn.connect': 'Conectar', 'gvpn.disconnect': 'Desconectar', 'gvpn.resume': 'Retomar agora'},
    'ru': {'desklet_spec.vpn': 'VPN', 'gvpn.protected': 'Защищено', 'gvpn.protectedDetail': 'Соединение зашифровано',
           'gvpn.reconnecting': 'Переподключение', 'gvpn.networkChanged': 'сеть изменилась', 'gvpn.connecting': 'Подключение',
           'gvpn.paused': 'Пауза', 'gvpn.resumesIn': 'возобновится через {0} мин', 'gvpn.off': 'Не защищено',
           'gvpn.offDetail': 'Нажмите, чтобы подключить', 'gvpn.getTitle': 'VPN', 'gvpn.getDetail': 'Бесплатно, от создателей G Launcher',
           'gvpn.get': 'Установить G VPN', 'gvpn.unavailableDetail': 'Нажмите, чтобы открыть G VPN', 'gvpn.open': 'Открыть G VPN',
           'gvpn.connect': 'Подключить', 'gvpn.disconnect': 'Отключить', 'gvpn.resume': 'Продолжить'},
    'fa': {'desklet_spec.vpn': 'VPN', 'gvpn.protected': 'محافظت‌شده', 'gvpn.protectedDetail': 'اتصال شما رمزگذاری شده است',
           'gvpn.reconnecting': 'در حال اتصال دوباره', 'gvpn.networkChanged': 'شبکه تغییر کرد', 'gvpn.connecting': 'در حال اتصال',
           'gvpn.paused': 'متوقف موقت', 'gvpn.resumesIn': 'ادامه تا {0} دقیقه دیگر', 'gvpn.off': 'محافظت‌نشده',
           'gvpn.offDetail': 'برای اتصال ضربه بزنید', 'gvpn.getTitle': 'VPN', 'gvpn.getDetail': 'رایگان، از سازندگان G Launcher',
           'gvpn.get': 'دریافت G VPN', 'gvpn.unavailableDetail': 'برای باز کردن G VPN ضربه بزنید', 'gvpn.open': 'باز کردن G VPN',
           'gvpn.connect': 'اتصال', 'gvpn.disconnect': 'قطع اتصال', 'gvpn.resume': 'ادامه همین حالا'},
    'id': {'desklet_spec.vpn': 'VPN', 'gvpn.protected': 'Terlindungi', 'gvpn.protectedDetail': 'Koneksi Anda terenkripsi',
           'gvpn.reconnecting': 'Menyambung ulang', 'gvpn.networkChanged': 'jaringan berubah', 'gvpn.connecting': 'Menghubungkan',
           'gvpn.paused': 'Dijeda', 'gvpn.resumesIn': 'lanjut dalam {0} mnt', 'gvpn.off': 'Tidak terlindungi',
           'gvpn.offDetail': 'Ketuk untuk menghubungkan', 'gvpn.getTitle': 'VPN', 'gvpn.getDetail': 'Gratis, dari pembuat G Launcher',
           'gvpn.get': 'Dapatkan G VPN', 'gvpn.unavailableDetail': 'Ketuk untuk membuka G VPN', 'gvpn.open': 'Buka G VPN',
           'gvpn.connect': 'Hubungkan', 'gvpn.disconnect': 'Putuskan', 'gvpn.resume': 'Lanjutkan sekarang'},
    'ar': {'desklet_spec.vpn': 'VPN', 'gvpn.protected': 'محمي', 'gvpn.protectedDetail': 'اتصالك مشفّر',
           'gvpn.reconnecting': 'جارٍ إعادة الاتصال', 'gvpn.networkChanged': 'تغيّرت الشبكة', 'gvpn.connecting': 'جارٍ الاتصال',
           'gvpn.paused': 'متوقف مؤقتًا', 'gvpn.resumesIn': 'يُستأنف بعد {0} د', 'gvpn.off': 'غير محمي',
           'gvpn.offDetail': 'اضغط للاتصال', 'gvpn.getTitle': 'VPN', 'gvpn.getDetail': 'مجاني، من صانعي G Launcher',
           'gvpn.get': 'احصل على G VPN', 'gvpn.unavailableDetail': 'اضغط لفتح G VPN', 'gvpn.open': 'فتح G VPN',
           'gvpn.connect': 'اتصال', 'gvpn.disconnect': 'قطع الاتصال', 'gvpn.resume': 'استئناف الآن'},
    'tr': {'desklet_spec.vpn': 'VPN', 'gvpn.protected': 'Korunuyor', 'gvpn.protectedDetail': 'Bağlantınız şifreli',
           'gvpn.reconnecting': 'Yeniden bağlanıyor', 'gvpn.networkChanged': 'ağ değişti', 'gvpn.connecting': 'Bağlanıyor',
           'gvpn.paused': 'Duraklatıldı', 'gvpn.resumesIn': '{0} dk sonra devam eder', 'gvpn.off': 'Korunmuyor',
           'gvpn.offDetail': 'Bağlanmak için dokunun', 'gvpn.getTitle': 'VPN', 'gvpn.getDetail': 'Ücretsiz, G Launcher\'ın yapımcılarından',
           'gvpn.get': 'G VPN\'i edin', 'gvpn.unavailableDetail': 'G VPN\'i açmak için dokunun', 'gvpn.open': 'G VPN\'i aç',
           'gvpn.connect': 'Bağlan', 'gvpn.disconnect': 'Bağlantıyı kes', 'gvpn.resume': 'Şimdi devam et'},
}

root = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'i18n'
for path in sorted(root.glob('*.json')):
    code = path.stem.split('-')[0].split('_')[0]
    strings = S.get(code)
    if strings is None:
        print(f'{path.name}: no translation here, English fallback applies')
        continue
    data = json.loads(path.read_text(encoding='utf-8'))
    added = {k: v for k, v in strings.items() if k not in data}
    data.update(added)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{path.name}: {len(added)} added')
