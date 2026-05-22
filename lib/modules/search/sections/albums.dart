import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:tonic/components/horizontal_playbutton_card_view/horizontal_playbutton_card_view.dart';
import 'package:tonic/extensions/context.dart';
import 'package:tonic/pages/search/search.dart';
import 'package:tonic/provider/metadata_plugin/search/all.dart';

class SearchAlbumsSection extends HookConsumerWidget {
  const SearchAlbumsSection({
    super.key,
  });

  @override
  Widget build(BuildContext context, ref) {
    final searchTerm = ref.watch(searchTermStateProvider);
    final search = ref.watch(metadataPluginSearchAllProvider(searchTerm));
    final albums = search.asData?.value.albums ?? [];

    return HorizontalPlaybuttonCardView(
      isLoadingNextPage: false,
      hasNextPage: false,
      items: albums,
      onFetchMore: () {},
      title: Text(context.l10n.albums),
    );
  }
}
