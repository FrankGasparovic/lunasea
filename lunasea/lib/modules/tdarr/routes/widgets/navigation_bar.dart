import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';

/// Navigation metadata for the five Tdarr destinations.
class TdarrNavigationBar extends StatelessWidget {
  static const List<IconData> icons = [
    Icons.dashboard_rounded,
    Icons.dns_rounded,
    Icons.queue_play_next_rounded,
    Icons.check_circle_outline_rounded,
    Icons.error_outline_rounded,
  ];

  static List<String> get titles => [
    'tdarr.Dashboard'.tr(),
    'tdarr.Nodes'.tr(),
    'tdarr.Queue'.tr(),
    'tdarr.Completed'.tr(),
    'tdarr.Failed'.tr(),
  ];

  static List<ScrollController> scrollControllers = List.generate(
    icons.length,
    (_) => ScrollController(),
  );

  final PageController? pageController;

  const TdarrNavigationBar({super.key, required this.pageController});

  @override
  Widget build(BuildContext context) => LunaBottomNavigationBar(
    pageController: pageController,
    icons: icons,
    titles: titles,
    scrollControllers: scrollControllers,
  );
}
