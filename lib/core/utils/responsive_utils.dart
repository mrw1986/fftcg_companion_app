// lib/core/utils/responsive_utils.dart
import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Device breakpoints
  static const double phoneSmall = 320;
  static const double phoneMedium = 375;
  static const double phoneLarge = 414;
  static const double tablet = 768;
  static const double laptop = 1024;
  static const double desktop = 1440;

  // Standard max content widths
  static const double maxContentWidthPhone = 600;
  static const double maxContentWidthTablet = 800;
  static const double maxContentWidthDesktop = 1200;

  // Grid breakpoints
  static const Map<String, double> gridBreakpoints = {
    'xs': 0,
    'sm': 600,
    'md': 960,
    'lg': 1280,
    'xl': 1920,
  };

  // Grid columns per breakpoint
  static const Map<String, int> gridColumns = {
    'xs': 4,
    'sm': 8,
    'md': 12,
    'lg': 12,
    'xl': 12,
  };

  // Standard spacing values
  static const Map<String, double> spacing = {
    'xs': 4.0,
    'sm': 8.0,
    'md': 16.0,
    'lg': 24.0,
    'xl': 32.0,
  };

  // Device type detection
  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < tablet;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tablet &&
      MediaQuery.of(context).size.width < laptop;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= laptop;

  // Layout helpers
  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  // Grid layout helpers
  static int getCardGridCrossAxisCount(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < phoneSmall) return 1;
    if (width < tablet) return 2;
    if (width < laptop) return 3;
    if (width < desktop) return 4;
    return 6;
  }

  // Spacing and padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < tablet) {
      return EdgeInsets.all(spacing['sm']!);
    } else if (width < laptop) {
      return EdgeInsets.all(spacing['md']!);
    }
    return EdgeInsets.all(spacing['lg']!);
  }

  // Font scaling
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = getScreenWidth(context);
    final scaleFactor = width < tablet
        ? 1.0
        : width < laptop
            ? 1.1
            : 1.2;
    return baseSize * scaleFactor;
  }

  // Layout builders
  static Widget buildResponsiveLayout({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= gridBreakpoints['lg']!) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= gridBreakpoints['md']!) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }

  // Content constraints
  static Widget wrapWithMaxWidth(Widget child, BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _getMaxContentWidth(context),
        ),
        child: child,
      ),
    );
  }

  static double _getMaxContentWidth(BuildContext context) {
    if (isDesktop(context)) return maxContentWidthDesktop;
    if (isTablet(context)) return maxContentWidthTablet;
    return maxContentWidthPhone;
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < tablet) {
      return const EdgeInsets.all(8.0);
    } else if (width < laptop) {
      return const EdgeInsets.all(16.0);
    }
    return const EdgeInsets.all(24.0);
  }

  static double getDialogWidth(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < tablet) return width * 0.9;
    if (width < laptop) return width * 0.7;
    return width * 0.5;
  }

  // Navigation helpers
  static bool shouldShowSideNav(BuildContext context) =>
      getScreenWidth(context) >= gridBreakpoints['md']!;

  static double getSideNavWidth(BuildContext context) {
    final width = getScreenWidth(context);
    if (width >= gridBreakpoints['xl']!) return 280;
    if (width >= gridBreakpoints['lg']!) return 240;
    return 200;
  }

  // Component-specific helpers
  static double getCardWidth(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < phoneSmall) return width * 0.9;
    if (width < tablet) return width * 0.45;
    if (width < laptop) return width * 0.3;
    return width * 0.22;
  }

  static double getCardHeight(BuildContext context) =>
      getCardWidth(context) * 1.4; // Assuming 1.4:1 aspect ratio

  static double getListItemHeight(BuildContext context) {
    if (isDesktop(context)) return 100;
    if (isTablet(context)) return 80;
    return 72;
  }
}

// Extension methods for responsive dimensions
extension ResponsiveDimensions on num {
  double w(BuildContext context) =>
      MediaQuery.of(context).size.width * (this / 100);

  double h(BuildContext context) =>
      MediaQuery.of(context).size.height * (this / 100);

  double sp(BuildContext context) =>
      ResponsiveUtils.getResponsiveFontSize(context, toDouble());
}
