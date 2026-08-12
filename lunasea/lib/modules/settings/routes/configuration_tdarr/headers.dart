import 'package:flutter/material.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/settings.dart';

class ConfigurationTdarrHeadersRoute extends StatelessWidget {
  const ConfigurationTdarrHeadersRoute({super.key});

  @override
  Widget build(BuildContext context) =>
      const SettingsHeaderRoute(module: LunaModule.TDARR);
}
