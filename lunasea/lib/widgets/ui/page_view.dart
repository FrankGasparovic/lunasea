import 'package:flutter/material.dart';

class LunaPageView extends StatelessWidget {
  final PageController? controller;
  final List<Widget> children;
  final ScrollPhysics physics;

  const LunaPageView({
    super.key,
    this.controller,
    required this.children,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: controller,
      children: children,
      physics: physics,
    );
  }
}
