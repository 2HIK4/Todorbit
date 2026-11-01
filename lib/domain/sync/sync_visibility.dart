class SyncSequenceRange {
  SyncSequenceRange(this.first, this.last) {
    if (first < 1 || last < first) {
      throw const FormatException('Invalid visible sequence interval');
    }
  }
  final int first, last;
}

// Exact applied history, not a high-water mark. Holes represent changes which
// are missing, conflicted or otherwise have not been shown to the user.
class SyncVisibility {
  SyncVisibility(Map<String, Iterable<SyncSequenceRange>> source)
    : ranges = Map.unmodifiable({
        for (final entry in source.entries)
          entry.key: _normalize(entry.key, entry.value),
      });
  final Map<String, List<SyncSequenceRange>> ranges;

  static List<SyncSequenceRange> _normalize(
    String device,
    Iterable<SyncSequenceRange> source,
  ) {
    if (device.isEmpty || device.length > 128) {
      throw const FormatException('Invalid visible device identity');
    }
    final sorted = source.toList()..sort((a, b) => a.first.compareTo(b.first));
    final result = <SyncSequenceRange>[];
    for (final range in sorted) {
      if (result.isNotEmpty &&
          (range.first <= result.last.last ||
              range.first - result.last.last == 1)) {
        final last = result.removeLast();
        result.add(
          SyncSequenceRange(
            last.first,
            range.last > last.last ? range.last : last.last,
          ),
        );
      } else {
        result.add(range);
      }
    }
    return List.unmodifiable(result);
  }

  bool contains(String device, int sequence) =>
      sequence > 0 &&
      (ranges[device]?.any(
            (range) => range.first <= sequence && sequence <= range.last,
          ) ??
          false);

  bool covers(SyncVisibility other) => other.ranges.entries.every(
    (entry) => entry.value.every(
      (range) =>
          ranges[entry.key]?.any(
            (ours) => ours.first <= range.first && ours.last >= range.last,
          ) ??
          false,
    ),
  );

  SyncVisibility withRange(String device, int first, int last) =>
      SyncVisibility({
        ...ranges,
        device: [...?ranges[device], SyncSequenceRange(first, last)],
      });

  SyncVisibility union(SyncVisibility other) => SyncVisibility({
    for (final device in {...ranges.keys, ...other.ranges.keys})
      device: [...?ranges[device], ...?other.ranges[device]],
  });

  Map<String, Object?> toJson() => {
    for (final device in ranges.keys.toList()..sort())
      if (ranges[device]!.isNotEmpty)
        device: [
          for (final range in ranges[device]!) [range.first, range.last],
        ],
  };

  factory SyncVisibility.fromJson(Map<String, dynamic> value) {
    final result = <String, List<SyncSequenceRange>>{};
    for (final entry in value.entries) {
      if (entry.value is! List || (entry.value as List).isEmpty) {
        throw const FormatException('Invalid visible interval list');
      }
      var previous = 0;
      final ranges = <SyncSequenceRange>[];
      for (final raw in entry.value as List) {
        if (raw is! List ||
            raw.length != 2 ||
            raw[0] is! int ||
            raw[1] is! int) {
          throw const FormatException('Invalid visible sequence interval');
        }
        final range = SyncSequenceRange(raw[0] as int, raw[1] as int);
        if (previous > 0 &&
            (range.first <= previous || range.first - previous == 1)) {
          throw const FormatException(
            'Visible sequence intervals are not canonical',
          );
        }
        ranges.add(range);
        previous = range.last;
      }
      result[entry.key] = ranges;
    }
    return SyncVisibility(result);
  }
}
