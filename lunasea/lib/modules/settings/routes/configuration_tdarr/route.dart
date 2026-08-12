import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/tdarr.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationTdarrRoute extends StatefulWidget {
  const ConfigurationTdarrRoute({super.key});

  @override
  State<ConfigurationTdarrRoute> createState() =>
      _ConfigurationTdarrRouteState();
}

class _ConfigurationTdarrRouteState extends State<ConfigurationTdarrRoute>
    with LunaScrollControllerMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) => LunaScaffold(
    scaffoldKey: _scaffoldKey,
    appBar: LunaAppBar(
      title: LunaModule.TDARR.title,
      scrollControllers: [scrollController],
    ),
    body: LunaBox.profiles.listenableBuilder(
      builder: (context, _) => LunaListView(
        controller: scrollController,
        children: [
          LunaModule.TDARR.informationBanner(),
          LunaBlock(
            title: 'settings.EnableModule'.tr(args: ['Tdarr']),
            trailing: LunaSwitch(
              value: LunaProfile.current.tdarrEnabled,
              onChanged: _setEnabled,
            ),
          ),
          LunaBlock(
            title: 'settings.ConnectionDetails'.tr(),
            body: [
              TextSpan(
                text: 'settings.ConnectionDetailsDescription'.tr(
                  args: ['Tdarr'],
                ),
              ),
            ],
            trailing: const LunaIconButton.arrow(),
            onTap: SettingsRoutes.CONFIGURATION_TDARR_CONNECTION_DETAILS.go,
          ),
        ],
      ),
    ),
  );

  void _setEnabled(bool value) {
    final profile = LunaProfile.current;
    if (value && !LunaConnectionDetails.isValidHost(profile.tdarrHost)) {
      showLunaErrorSnackBar(title: 'settings.HostRequired'.tr());
      SettingsRoutes.CONFIGURATION_TDARR_CONNECTION_DETAILS.go();
      return;
    }
    if (value && !LunaConnectionDetails.hasApiKey(profile.tdarrKey)) {
      showLunaErrorSnackBar(title: 'settings.ApiKeyRequired'.tr());
      SettingsRoutes.CONFIGURATION_TDARR_CONNECTION_DETAILS.go();
      return;
    }
    profile.tdarrEnabled = value;
    profile.save();
    context.read<TdarrState>().reset();
  }
}
