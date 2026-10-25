import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../design/meridian.dart';
import '../i18n/strings.g.dart';
import '../vpn/tunnel_store.dart';

/// Shares one of the user's servers: a QR code another phone can scan (or
/// read from a saved image), or the settings as a .conf file. The same key
/// travels with it, so the sheet says plainly what that means.
class ShareServerSheet extends StatefulWidget {
  const ShareServerSheet({super.key, required this.tunnel});

  final SavedTunnel tunnel;

  static Future<void> show(BuildContext context, SavedTunnel tunnel) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: context.mer.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => ShareServerSheet(tunnel: tunnel),
      );

  @override
  State<ShareServerSheet> createState() => _ShareServerSheetState();
}

class _ShareServerSheetState extends State<ShareServerSheet> {
  final _qrKey = GlobalKey();
  bool _busy = false;

  /// A file name from the server's name: letters, digits and dashes.
  String get _fileStem {
    final s = widget.tunnel.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return s.isEmpty ? 'g-vpn-server' : s;
  }

  Future<void> _saveImage() async {
    setState(() => _busy = true);
    try {
      final boundary = _qrKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 4);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: '$_fileStem.png')],
        fileNameOverrides: ['$_fileStem.png'],
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendFile() => SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(utf8.encode(widget.tunnel.configText), mimeType: 'text/plain', name: '$_fileStem.conf')],
        fileNameOverrides: ['$_fileStem.conf'],
      ));

  @override
  Widget build(BuildContext context) {
    final m = context.mer;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.share.title(name: widget.tunnel.name), style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: m.text)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: m.warn.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.key_rounded, size: 20, color: m.warn),
                const SizedBox(width: 10),
                Expanded(child: Text(t.share.sameKey, style: TextStyle(fontSize: 13, height: 1.45, color: m.text))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            // What "Save image" captures: the code on white, with the name.
            child: RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: widget.tunnel.configText,
                      size: 220,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                    const SizedBox(height: 6),
                    Text(widget.tunnel.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0B0E14))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(t.share.scanHint, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.45, color: m.muted)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _saveImage,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(t.share.saveImage),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sendFile,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(t.share.send),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
