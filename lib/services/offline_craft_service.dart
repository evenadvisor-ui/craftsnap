import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/models.dart';

/// Provides craft ideas from the bundled offline JSON asset.
/// Falls back to this when there is no internet connection.
///
/// Asset file: assets/offline_crafts.json
/// Structure:  { "plastic-bottle": [ {t, d, s, m}, ... ], ... }
class OfflineCraftService {
  OfflineCraftService._();
  static final OfflineCraftService instance = OfflineCraftService._();

  // Cache so we only parse once per app session
  Map<String, List<Map<String, dynamic>>>? _cache;
  final _rng = Random();

  /// Load and cache the JSON asset.
  Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    final raw = await rootBundle.loadString('assets/offline_crafts.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    _cache = decoded.map(
      (key, value) =>
          MapEntry(key, (value as List).cast<Map<String, dynamic>>()),
    );
  }

  /// Returns up to [count] random craft ideas for [objectLabel].
  ///
  /// [objectLabel] should match your YOLO class names exactly,
  /// e.g. "plastic-water-bottle", "cardboard", "metal-can".
  ///
  /// If the label is not found, returns crafts for any available object.
  Future<List<CraftIdea>> getCraftsForObject(
    String objectLabel, {
    int count = 5,
  }) async {
    await _ensureLoaded();
    final all = _cache!;

    List<Map<String, dynamic>> pool = [];

    // Try exact match first
    if (all.containsKey(objectLabel)) {
      pool = all[objectLabel]!;
    } else {
      // Try partial match (e.g. "bottle" matches "plastic-water-bottle")
      final lower = objectLabel.toLowerCase();
      for (final entry in all.entries) {
        if (entry.key.contains(lower) || lower.contains(entry.key)) {
          pool = entry.value;
          break;
        }
      }
    }

    // If still nothing, just grab from the first available object
    if (pool.isEmpty && all.isNotEmpty) {
      pool = all.values.first;
    }

    if (pool.isEmpty) return [];

    // Shuffle and take [count] items
    final shuffled = List<Map<String, dynamic>>.from(pool)..shuffle(_rng);
    return shuffled.take(count).map(_toIdea).toList();
  }

  /// Returns crafts for multiple objects combined (multi-object modes).
  Future<List<CraftIdea>> getCraftsForObjects(
    List<String> objectLabels, {
    int count = 5,
  }) async {
    await _ensureLoaded();
    if (objectLabels.isEmpty) return [];

    final all = _cache!;
    final pool = <Map<String, dynamic>>[];

    for (final label in objectLabels) {
      if (all.containsKey(label)) {
        pool.addAll(all[label]!);
      }
    }

    if (pool.isEmpty) {
      // Fallback: use first object only
      return getCraftsForObject(objectLabels.first, count: count);
    }

    pool.shuffle(_rng);
    return pool.take(count).map(_toIdea).toList();
  }

  /// All available object labels in the offline database.
  Future<List<String>> availableLabels() async {
    await _ensureLoaded();
    return _cache!.keys.toList()..sort();
  }

  CraftIdea _toIdea(Map<String, dynamic> e) {
    return CraftIdea(
      title: e['t'] as String,
      description: e['d'] as String,
      steps: List<String>.from(e['s'] as List),
      materials: List<String>.from(e['m'] as List),
    );
  }
}
