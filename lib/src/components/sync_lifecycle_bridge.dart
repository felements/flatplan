import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/open_vault_provider.dart';

/// Pushes the open remote vault when the app goes to the background, the
/// moment Android may kill it. Local vaults have no scheduler and are
/// unaffected. Also keeps [openVaultProvider] alive for the app's lifetime.
class SyncLifecycleBridge extends ConsumerStatefulWidget {
  final Widget child;

  const SyncLifecycleBridge({super.key, required this.child});

  @override
  ConsumerState<SyncLifecycleBridge> createState() => _SyncLifecycleBridgeState();
}

class _SyncLifecycleBridgeState extends ConsumerState<SyncLifecycleBridge> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onPause: _onPause);
  }

  void _onPause() {
    final open = ref.read(openVaultProvider).value;
    open?.scheduler?.onAppPaused();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(openVaultProvider);
    return widget.child;
  }
}
