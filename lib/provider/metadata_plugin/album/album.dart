import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tonic/models/metadata/metadata.dart';
import 'package:tonic/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:tonic/provider/metadata_plugin/utils/common.dart';
import 'package:tonic/services/metadata/errors/exceptions.dart';

final metadataPluginAlbumProvider =
    FutureProvider.autoDispose.family<SpotubeFullAlbumObject, String>(
  (ref, id) async {
    ref.cacheFor();

    final metadataPlugin = await ref.watch(metadataPluginProvider.future);

    if (metadataPlugin == null) {
      throw MetadataPluginException.noDefaultMetadataPlugin();
    }

    return metadataPlugin.album.getAlbum(id);
  },
);
