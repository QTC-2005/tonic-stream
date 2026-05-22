import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' show ListTile;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:tonic/collections/spotube_icons.dart';
import 'package:tonic/modules/settings/section_card_with_heading.dart';
import 'package:tonic/extensions/context.dart';
import 'package:tonic/provider/user_preferences/user_preferences_provider.dart';
import 'package:tonic/utils/platform.dart';

class SettingsDownloadsSection extends HookConsumerWidget {
  const SettingsDownloadsSection({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final preferencesNotifier = ref.watch(userPreferencesProvider.notifier);
    final preferences = ref.watch(userPreferencesProvider);

    final pickDownloadLocation = useCallback(() async {
      if (kIsMobile || kIsMacOS) {
        final dirStr = await FilePicker.platform.getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        preferencesNotifier.setDownloadLocation(dirStr);
      } else {
        String? dirStr = await getDirectoryPath(
          initialDirectory: preferences.downloadLocation,
        );
        if (dirStr == null) return;
        preferencesNotifier.setDownloadLocation(dirStr);
      }
    }, [preferences.downloadLocation]);

    return SectionCardWithHeading(
      heading: context.l10n.downloads,
      children: [
        ListTile(
          leading: const Icon(SpotubeIcons.download),
          title: Text(context.l10n.download_location),
          subtitle: Text(preferences.downloadLocation),
          trailing: IconButton.secondary(
            onPressed: pickDownloadLocation,
            icon: const Icon(SpotubeIcons.folder),
          ),
          onTap: pickDownloadLocation,
        ),
      ],
    );
  }
}
