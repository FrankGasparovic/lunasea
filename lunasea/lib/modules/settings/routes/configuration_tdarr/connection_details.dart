import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/settings.dart';
import 'package:lunasea/modules/tdarr.dart';
import 'package:lunasea/router/routes/settings.dart';

class ConfigurationTdarrConnectionDetailsRoute extends StatefulWidget {
  const ConfigurationTdarrConnectionDetailsRoute({super.key});

  @override
  State<ConfigurationTdarrConnectionDetailsRoute> createState() => _State();
}

class _State extends State<ConfigurationTdarrConnectionDetailsRoute>
    with LunaScrollControllerMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) => LunaScaffold(
    scaffoldKey: _scaffoldKey,
    appBar: LunaAppBar(
      title: 'settings.ConnectionDetails'.tr(),
      scrollControllers: [scrollController],
    ),
    body: LunaBox.profiles.listenableBuilder(
      builder: (context, _) => LunaListView(
        controller: scrollController,
        children: [_host(), _apiKey(), _headers()],
      ),
    ),
    bottomNavigationBar: LunaBottomActionBar(actions: [_testButton()]),
  );

  Widget _host() => LunaBlock(
    title: 'settings.Host'.tr(),
    body: [
      TextSpan(
        text: LunaProfile.current.tdarrHost.isEmpty
            ? 'lunasea.NotSet'.tr()
            : LunaProfile.current.tdarrHost,
      ),
    ],
    trailing: const LunaIconButton.arrow(),
    onTap: () async {
      final result = await SettingsDialogs().editHost(
        context,
        prefill: LunaProfile.current.tdarrHost,
      );
      if (result.item1) {
        LunaProfile.current.tdarrHost = result.item2;
        await LunaProfile.current.save();
        if (mounted) context.read<TdarrState>().reset();
      }
    },
  );

  Widget _apiKey() => LunaBlock(
    title: 'settings.ApiKey'.tr(),
    body: [
      TextSpan(
        text: LunaProfile.current.tdarrKey.isEmpty
            ? 'lunasea.NotSet'.tr()
            : LunaUI.TEXT_OBFUSCATED_PASSWORD,
      ),
    ],
    trailing: const LunaIconButton.arrow(),
    onTap: () async {
      final result = await LunaDialogs().editText(
        context,
        'settings.ApiKey'.tr(),
        prefill: LunaProfile.current.tdarrKey,
      );
      if (result.item1) {
        LunaProfile.current.tdarrKey = result.item2;
        await LunaProfile.current.save();
        if (mounted) context.read<TdarrState>().reset();
      }
    },
  );

  Widget _headers() => LunaBlock(
    title: 'settings.CustomHeaders'.tr(),
    body: [TextSpan(text: 'settings.CustomHeadersDescription'.tr())],
    trailing: const LunaIconButton.arrow(),
    onTap: SettingsRoutes.CONFIGURATION_TDARR_CONNECTION_DETAILS_HEADERS.go,
  );

  Widget _testButton() => LunaButton.text(
    text: 'settings.TestConnection'.tr(),
    icon: LunaIcons.CONNECTION_TEST,
    onTap: () async {
      final profile = LunaProfile.current;
      if (!LunaConnectionDetails.isValidHost(profile.tdarrHost)) {
        showLunaErrorSnackBar(title: 'settings.HostRequired'.tr());
        return;
      }
      if (!LunaConnectionDetails.hasApiKey(profile.tdarrKey)) {
        showLunaErrorSnackBar(title: 'settings.ApiKeyRequired'.tr());
        return;
      }
      try {
        final status = await TdarrAPI(
          host: profile.tdarrHost,
          apiKey: profile.tdarrKey,
          headers: Map<String, dynamic>.from(profile.tdarrHeaders),
        ).getStatus();
        showLunaSuccessSnackBar(
          title: 'settings.ConnectedSuccessfully'.tr(),
          message: 'Tdarr ${status.version}',
        );
      } catch (error, stack) {
        LunaLogger().error('Tdarr connection test failed', error, stack);
        showLunaErrorSnackBar(
          title: 'settings.ConnectionTestFailed'.tr(),
          error: error,
        );
      }
    },
  );
}
