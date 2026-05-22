import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tonic/core/source/source_aggregator.dart';

/// Singleton [SourceAggregator] used across the app.
///
/// Engines can register themselves at startup via
/// `ref.read(tonicSourceAggregatorProvider).addSource(...)`.
final tonicSourceAggregatorProvider = Provider<SourceAggregator>((ref) {
  return SourceAggregator();
});
