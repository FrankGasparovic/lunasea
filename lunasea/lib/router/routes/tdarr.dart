import 'package:flutter/material.dart';
import 'package:lunasea/modules.dart';
import 'package:lunasea/modules/tdarr.dart';
import 'package:lunasea/router/routes.dart';
import 'package:lunasea/vendor.dart';

enum TdarrRoutes with LunaRoutesMixin {
  HOME('/tdarr'),
  REPORT('report');

  @override
  final String path;
  const TdarrRoutes(this.path);

  @override
  LunaModule get module => LunaModule.TDARR;

  @override
  bool isModuleEnabled(BuildContext context) =>
      context.read<TdarrState>().enabled;

  @override
  GoRoute get routes {
    switch (this) {
      case TdarrRoutes.HOME:
        return route(widget: const TdarrRoute());
      case TdarrRoutes.REPORT:
        return route(
          builder: (_, state) =>
              TdarrReportRoute(report: state.extra! as TdarrJobReport),
        );
    }
  }

  @override
  List<GoRoute> get subroutes =>
      this == TdarrRoutes.HOME ? [TdarrRoutes.REPORT.routes] : const [];
}
