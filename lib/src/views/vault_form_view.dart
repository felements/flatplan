import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/app_paths_provider.dart';
import '../providers/open_vault_provider.dart';
import '../providers/vaults_provider.dart';
import 'vault_kinds.dart';

/// `/settings/vaults/new` and `/settings/vaults/:id/edit`.
///
/// With one registered kind the chooser is skipped and the form opens
/// directly; the chooser appears once a second kind exists.
class VaultFormView extends ConsumerWidget {
  final String? vaultId;

  const VaultFormView({super.key, this.vaultId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = ref.watch(vaultsProvider).value;
    final existing = vaultId == null ? null : registry?.byId(vaultId!);

    if (vaultId != null && registry != null && existing == null) {
      return const Scaffold(
        body: Center(child: Text('This vault no longer exists.')),
      );
    }

    final Widget body;
    if (existing != null) {
      body = vaultKindFor(existing).buildForm(context, existing);
    } else if (vaultKinds.length == 1) {
      body = vaultKinds.single.buildForm(context, null);
    } else {
      body = _KindChooser(kinds: vaultKinds);
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Text(
              existing == null ? 'New vault' : 'Edit vault',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: body,
          ),
        ],
      ),
    );
  }
}

class _KindChooser extends StatefulWidget {
  final List<VaultKindDescriptor> kinds;

  const _KindChooser({required this.kinds});

  @override
  State<_KindChooser> createState() => _KindChooserState();
}

class _KindChooserState extends State<_KindChooser> {
  VaultKindDescriptor? _chosen;

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    if (chosen != null) return chosen.buildForm(context, null);
    // A Material ancestor of its own: without it, the ListTiles' ink
    // splashes paint on (and this assertion flags) the decorated
    // container VaultFormView wraps the chooser in.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final kind in widget.kinds)
            ListTile(
              leading: Icon(kind.icon),
              title: Text(kind.label),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () => setState(() => _chosen = kind),
            ),
        ],
      ),
    );
  }
}

/// Shown in place of a form for a remote kind this build does not know.
class UnsupportedVaultNotice extends StatelessWidget {
  const UnsupportedVaultNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'This vault type is not supported in this version. '
      'Update FlatPlan to open it.',
    );
  }
}

/// Name plus, on desktop, an optional folder. Without a folder the vault
/// lives inside the app's private area.
class LocalVaultForm extends HookConsumerWidget {
  final Vault? existing;

  /// Whether a folder can be picked here. Defaults to the desktop
  /// platforms, where `file_picker` returns a readable path.
  final bool? canPickFolder;

  const LocalVaultForm({super.key, this.existing, this.canPickFolder});

  static bool get _desktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pickFolder = canPickFolder ?? _desktop;
    final existingLocation = existing?.location is LocalVaultLocation
        ? existing!.location as LocalVaultLocation
        : null;
    final name = useTextEditingController(text: existing?.name ?? '');
    final pickedPath = useState<String?>(existingLocation?.path);
    final pickedBookmark = useState<String?>(existingLocation?.bookmark);
    final nameError = useState<String?>(null);
    final saving = useState(false);

    Future<void> choose() async {
      final picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select vault folder',
      );
      if (picked == null) return;
      if (!context.mounted) return;
      final resolver = await ref.read(vaultResolverProvider.future);
      if (!context.mounted) return;
      pickedBookmark.value = await resolver.bookmarkFor(picked);
      pickedPath.value = picked;
    }

    Future<void> save() async {
      final trimmed = name.text.trim();
      if (trimmed.isEmpty) {
        nameError.value = 'Give the vault a name.';
        return;
      }
      saving.value = true;
      try {
        final id = existing?.id ?? const Uuid().v4();
        final paths = await ref.read(appPathsProvider.future);
        final vault = Vault(
          id: id,
          name: trimmed,
          location: VaultLocation.local(
            path: pickedPath.value ?? paths.mirrorFor(id),
            bookmark: pickedBookmark.value,
          ),
          createdAt: existing?.createdAt ?? DateTime.now(),
        );
        final vaults = ref.read(vaultsProvider.notifier);
        if (existing == null) {
          await vaults.add(vault);
        } else {
          await vaults.updateVault(vault);
        }
        if (!context.mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save the vault: $e')));
      } finally {
        if (context.mounted) saving.value = false;
      }
    }

    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: name,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: nameError.value,
            ),
            onChanged: (_) => nameError.value = null,
          ),
          const SizedBox(height: 20),
          if (pickFolder) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pickedPath.value ??
                          'Stored inside the app until you choose a folder.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: pickedPath.value == null
                            ? null
                            : 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: choose,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Choose folder…'),
                ),
              ],
            ),
          ] else
            Text(
              'This vault is stored inside the app on this device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: saving.value ? null : save,
              child: Text(existing == null ? 'Create vault' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
