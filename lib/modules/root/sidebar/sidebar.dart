import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:tonic/collections/side_bar_tiles.dart';
import 'package:tonic/models/database/database.dart';
import 'package:tonic/extensions/constrains.dart';
import 'package:tonic/extensions/context.dart';
import 'package:tonic/modules/root/sidebar/sidebar_footer.dart';

import 'package:tonic/provider/user_preferences/user_preferences_provider.dart';

class Sidebar extends HookConsumerWidget {
  final Widget child;

  const Sidebar({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final mediaQuery = MediaQuery.sizeOf(context);

    final layoutMode =
        ref.watch(userPreferencesProvider.select((s) => s.layoutMode));

    final sidebarTileList = useMemoized(
      () => getSidebarTileList(context.l10n),
      [context.l10n],
    );

    final sidebarLibraryTileList = useMemoized(
      () => getSidebarLibraryTileList(context.l10n),
      [context.l10n],
    );

    final tileList = [...sidebarTileList, ...sidebarLibraryTileList];

    final router = context.watchRouter;

    final selectedIndex = tileList.indexWhere(
      (e) => router.currentPath.startsWith(e.pathPrefix),
    );

    if (layoutMode == LayoutMode.compact ||
        (mediaQuery.smAndDown && layoutMode == LayoutMode.adaptive)) {
      return child;
    }

    final selectedKey = selectedIndex >= 0
        ? ValueKey(tileList[selectedIndex].pathPrefix)
        : null;

    final navigationButtons = [
      NavigationGroup(
        label: mediaQuery.lgAndUp
            ? DefaultTextStyle(
                style: TextStyle(
                  fontFamily: "Cookie",
                  fontSize: 30,
                  letterSpacing: 1.8,
                  color: colorScheme.foreground,
                ),
                child: const Text("Tonic"),
              )
            : const Text(""),
        children: [
          for (final tile in sidebarTileList)
            NavigationButton(
              key: ValueKey(tile.pathPrefix),
              style: router.currentPath.startsWith(tile.pathPrefix)
                  ? const ButtonStyle.secondary()
                  : null,
              label: mediaQuery.lgAndUp ? Text(tile.title) : null,
              child: Tooltip(
                tooltip: TooltipContainer(child: Text(tile.title)).call,
                child: Icon(tile.icon),
              ),
              onPressed: () {
                context.navigateTo(tile.route);
              },
            ),
        ],
      ),
      const NavigationDivider(),
      NavigationGroup(
        label: mediaQuery.lgAndUp
            ? Text(context.l10n.library)
            : const Text(""),
        children: [
          for (final tile in sidebarLibraryTileList)
            NavigationButton(
              key: ValueKey(tile.pathPrefix),
              style: router.currentPath.startsWith(tile.pathPrefix)
                  ? const ButtonStyle.secondary()
                  : null,
              label: mediaQuery.lgAndUp ? Text(tile.title) : null,
              onPressed: () {
                context.navigateTo(tile.route);
              },
              child: Tooltip(
                tooltip: TooltipContainer(child: Text(tile.title)).call,
                child: Icon(tile.icon),
              ),
            ),
        ],
      ),
    ];

    final tileKeyMap = {
      for (final t in tileList) ValueKey(t.pathPrefix): t,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Expanded(
              child: mediaQuery.lgAndUp
                  ? NavigationSidebar(
                      selectedKey: selectedKey,
                      onSelected: (key) {
                        if (key != null) {
                          final tile = tileKeyMap[key];
                          if (tile != null) {
                            context.navigateTo(tile.route);
                          }
                        }
                      },
                      children: navigationButtons,
                    )
                  : NavigationRail(
                      alignment: NavigationRailAlignment.start,
                      selectedKey: selectedKey,
                      onSelected: (key) {
                        if (key != null) {
                          final tile = tileKeyMap[key];
                          if (tile != null) {
                            context.navigateTo(tile.route);
                          }
                        }
                      },
                      children: navigationButtons,
                    ),
            ),
            const SidebarFooter(),
            if (mediaQuery.lgAndUp) const Gap(130) else const Gap(65),
          ],
        ),
        const VerticalDivider(),
        Expanded(child: child),
      ],
    );
  }
}
