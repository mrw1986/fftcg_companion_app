// lib/core/utils/breakpoints.dart

import 'package:flutter/material.dart';

class Breakpoints {
  // Screen width breakpoints
  static const double mobileSmall = 320;
  static const double mobileMedium = 375;
  static const double mobileLarge = 425;
  static const double tablet = 768;
  static const double laptop = 1024;
  static const double laptopLarge = 1440;
  static const double desktop = 1920;
  static const double desktop4K = 2560;

  // Content width constraints
  static const double maxContentWidthMobile = 600;
  static const double maxContentWidthTablet = 800;
  static const double maxContentWidthDesktop = 1200;

  // Grid breakpoints
  static const double gridSmall = 450;
  static const double gridMedium = 800;
  static const double gridLarge = 1100;

  // Navigation breakpoints
  static const double navigationBreakpoint = 600;
  static const double extendedNavigationBreakpoint = 1200;
}

class ResponsiveBreakpoints {
  static bool isMobileSmall(BuildContext context) =>
      MediaQuery.of(context).size.width < Breakpoints.mobileSmall;

  static bool isMobileMedium(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.mobileSmall &&
      MediaQuery.of(context).size.width < Breakpoints.mobileLarge;

  static bool isMobileLarge(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.mobileLarge &&
      MediaQuery.of(context).size.width < Breakpoints.tablet;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.tablet &&
      MediaQuery.of(context).size.width < Breakpoints.laptop;

  static bool isLaptop(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.laptop &&
      MediaQuery.of(context).size.width < Breakpoints.laptopLarge;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= Breakpoints.desktop;

  static T getValueForBreakpoint<T>({
    required BuildContext context,
    required T mobile,
    T? mobileLarge,
    T? tablet,
    T? laptop,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= Breakpoints.desktop) {
      return desktop ?? laptop ?? tablet ?? mobileLarge ?? mobile;
    }
    if (width >= Breakpoints.laptop) {
      return laptop ?? tablet ?? mobileLarge ?? mobile;
    }
    if (width >= Breakpoints.tablet) {
      return tablet ?? mobileLarge ?? mobile;
    }
    if (width >= Breakpoints.mobileLarge) {
      return mobileLarge ?? mobile;
    }
    return mobile;
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    return getValueForBreakpoint(
      context: context,
      mobile: const EdgeInsets.all(8),
      mobileLarge: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(24),
      laptop: const EdgeInsets.all(32),
      desktop: const EdgeInsets.all(48),
    );
  }

  static double getMaxContentWidth(BuildContext context) {
    return getValueForBreakpoint(
      context: context,
      mobile: Breakpoints.maxContentWidthMobile,
      tablet: Breakpoints.maxContentWidthTablet,
      desktop: Breakpoints.maxContentWidthDesktop,
    );
  }
}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.desktop) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= Breakpoints.tablet) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    BoxConstraints constraints,
    ScreenType screenType,
  ) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        ScreenType screenType;
        if (constraints.maxWidth >= Breakpoints.desktop) {
          screenType = ScreenType.desktop;
        } else if (constraints.maxWidth >= Breakpoints.tablet) {
          screenType = ScreenType.tablet;
        } else {
          screenType = ScreenType.mobile;
        }

        return builder(context, constraints, screenType);
      },
    );
  }
}

enum ScreenType { mobile, tablet, desktop }

extension ResponsiveExtensions on num {
  double w(BuildContext context) =>
      MediaQuery.of(context).size.width * (this / 100);

  double h(BuildContext context) =>
      MediaQuery.of(context).size.height * (this / 100);
}
