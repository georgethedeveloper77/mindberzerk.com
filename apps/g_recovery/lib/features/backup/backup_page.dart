import 'package:flutter/material.dart';

import '../../app/shell.dart';
import '../../ui/g_app_bar.dart';
import '../placeholder_panel.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GPageBody(
      children: <Widget>[
        GAppBar(title: 'Backup'),
        PlaceholderPanel(
          phase: 'Version 1.2',
          title: 'Home server backup',
          detail:
              'SMB, WebDAV, Nextcloud, SFTP, plus offload that keeps a local '
              'thumbnail. Deliberately after 1.0 so it does not gate release.',
        ),
      ],
    );
  }
}
