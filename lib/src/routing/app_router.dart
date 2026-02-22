import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../views/app_shell.dart';
import '../views/category_detail_view.dart';
import '../views/dashboard_view.dart';
import '../views/settings_view.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorDashboardKey = GlobalKey<NavigatorState>(debugLabel: 'dashboardShell');
final _shellNavigatorSettingsKey = GlobalKey<NavigatorState>(debugLabel: 'settingsShell');

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Dashboard Branch (Index 0)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorDashboardKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardView(),
                routes: [
                  GoRoute(
                    path: 'category/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return CategoryDetailView(categoryId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          
          // Settings Branch (Index 1)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsView(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
