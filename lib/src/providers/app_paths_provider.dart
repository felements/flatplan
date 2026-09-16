import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/app_paths.dart';

part 'app_paths_provider.g.dart';

/// The app-support locations, resolved once per app run.
@Riverpod(keepAlive: true)
Future<AppPaths> appPaths(Ref ref) => AppPaths.resolve();
