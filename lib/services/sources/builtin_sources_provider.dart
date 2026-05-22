import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tonic/core/source/source_provider.dart';
import 'package:tonic/services/sources/bilibili/bilibili_audio_source.dart';
import 'package:tonic/services/sources/netease/netease_audio_source.dart';
import 'package:tonic/services/sources/qqmusic/qqmusic_audio_source.dart';
import 'package:tonic/services/sources/kuwo/kuwo_audio_source.dart';
import 'package:tonic/services/sources/migu/migu_audio_source.dart';

final builtinSourcesProvider = Provider<bool>((ref) {
  final aggregator = ref.read(tonicSourceAggregatorProvider);
  final names = aggregator.sources.map((s) => s.engine.name).toSet();

  if (!names.contains('Netease')) {
    aggregator.addSource(NeteaseAudioSource());
  }
  if (!names.contains('QQMusic')) {
    aggregator.addSource(QQMusicAudioSource());
  }
  if (!names.contains('Kuwo')) {
    aggregator.addSource(KuwoAudioSource());
  }
  if (!names.contains('Migu')) {
    aggregator.addSource(MiguAudioSource());
  }
  if (!names.contains('Bilibili')) {
    aggregator.addSource(BilibiliAudioSource());
  }

  return true;
});
