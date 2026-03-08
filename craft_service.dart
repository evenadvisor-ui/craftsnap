import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'craft_database.dart';

class CraftService {
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  // ⚠️ Your Anthropic API key — never share this file publicly
  static const _apiKey = 'YOUR_ANTHROPIC_API_KEY_HERE';

  static CraftService? _instance;
  static CraftService get instance => _instance ??= CraftService._();
  CraftService._();

  // ── Main entry point ──────────────────────────

  Future<List<CraftIdea>> getCraftIdeas({
    required List<String> currentObjects,
    List<String> pastObjects = const [],
    List<String> futureObjects = const [],
    required CraftMode mode,
  }) async {
    // Build count maps per mode — what objects are PRIMARY vs extra
    final Map<String, int> primaryCounts = {};
    final Map<String, int> allCounts = {};

    // PRIMARY = always current objects
    for (final o in currentObjects) {
      primaryCounts[o] = (primaryCounts[o] ?? 0) + 1;
      allCounts[o] = (allCounts[o] ?? 0) + 1;
    }

    // Add past/future to allCounts only (not primary)
    for (final o in [...pastObjects, ...futureObjects]) {
      allCounts[o] = (allCounts[o] ?? 0) + 1;
    }

    // Decide which counts to use for craft matching
    Map<String, int> craftCounts;
    switch (mode) {
      case CraftMode.currentOnly:
        craftCounts = primaryCounts; // ONLY current objects
        break;
      case CraftMode.currentAndPast:
        craftCounts = allCounts; // current + past
        break;
      case CraftMode.currentAndFuture:
        craftCounts = allCounts; // current + future
        break;
      case CraftMode.pastPresentFuture:
        craftCounts = allCounts; // everything
        break;
    }

    // Try AI first
    try {
      final ideas = await _fetchFromAI(
        currentObjects: currentObjects,
        pastObjects: mode == CraftMode.currentOnly ? [] : pastObjects,
        futureObjects:
            (mode == CraftMode.currentOnly || mode == CraftMode.currentAndPast)
            ? []
            : futureObjects,
        mode: mode,
        primaryObjects: primaryCounts.keys.toList(),
      );
      if (ideas.length >= 5) {
        _log('✅ AI returned ${ideas.length} ideas');
        return ideas;
      }
      // Supplement with offline if not enough
      final offline = CraftDatabase.instance.getCrafts(
        craftCounts,
        primaryKeys: primaryCounts.keys.toList(),
      );
      final merged = [...ideas, ...offline];
      final seen = <String>{};
      return merged.where((c) => seen.add(c.title)).take(20).toList();
    } catch (e) {
      _log('AI failed: $e — using offline database');
    }

    // Full offline fallback
    return CraftDatabase.instance.getCrafts(
      craftCounts,
      primaryKeys: primaryCounts.keys.toList(),
    );
  }

  void _log(String msg) => print('[CraftService] $msg');

  // ── AI fetch ──────────────────────────────────

  Future<List<CraftIdea>> _fetchFromAI({
    required List<String> currentObjects,
    required List<String> pastObjects,
    required List<String> futureObjects,
    required CraftMode mode,
    required List<String> primaryObjects,
  }) async {
    final prompt = _buildPrompt(
      currentObjects: currentObjects,
      pastObjects: pastObjects,
      futureObjects: futureObjects,
      mode: mode,
      primaryObjects: primaryObjects,
    );

    final response = await http
        .post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': _apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': 'claude-sonnet-4-20250514',
            'max_tokens': 3000,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 25));

    _log('API status: ${response.statusCode}');
    if (response.statusCode != 200)
      throw Exception('API ${response.statusCode}');

    final data = jsonDecode(response.body);
    final text = (data['content'] as List)
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();

    return _parseJson(text);
  }

  String _buildPrompt({
    required List<String> currentObjects,
    required List<String> pastObjects,
    required List<String> futureObjects,
    required CraftMode mode,
    required List<String> primaryObjects,
  }) {
    final primary = primaryObjects.join(', ');

    String modeDesc = '';
    switch (mode) {
      case CraftMode.currentOnly:
        modeDesc =
            '''The user ONLY has these recyclable objects available RIGHT NOW: $primary.
Every craft idea MUST use one or more of these as the MAIN material.
Do NOT suggest crafts that require buying other main materials.
Additional items like glue, scissors, paint are fine as extras.''';
        break;

      case CraftMode.currentAndPast:
        modeDesc =
            '''Primary objects (scanned today): $primary
Additional objects from past scans also available: ${pastObjects.join(', ')}

Suggest crafts where the PRIMARY objects ($primary) are the MAIN material.
The past objects can be used as supporting or combined materials.
At least 3 ideas should primarily feature: $primary''';
        break;

      case CraftMode.currentAndFuture:
        modeDesc =
            '''Primary objects (available now): $primary
Future objects the user PLANS to obtain: ${futureObjects.join(', ')}

Suggest crafts the user can build once they get the future items.
The primary objects ($primary) should still be the MAIN focus.
Clearly mention which future item is needed for each craft.''';
        break;

      case CraftMode.pastPresentFuture:
        modeDesc =
            '''Primary objects (scanned today): $primary
Past objects available: ${pastObjects.join(', ')}
Future objects to obtain: ${futureObjects.join(', ')}

Suggest ambitious combination crafts using all three sets.
The primary objects ($primary) must feature in every suggestion.
Clearly mention what is available now vs what needs to be obtained.''';
        break;
    }

    return '''You are a creative DIY craft expert specialising in upcycling recyclable materials.

$modeDesc

Give AT LEAST 5 creative, practical DIY craft ideas. Be specific to the exact objects listed.
Each craft must genuinely use the primary objects as main materials — not just decoration.

Respond ONLY with raw JSON array, no markdown, no extra text:
[
  {
    "title": "Specific Craft Name",
    "description": "2-3 sentences. Mention the specific objects used.",
    "steps": ["Step 1", "Step 2", "Step 3", "Step 4", "Step 5"],
    "materials": ["primary object used", "scissors", "glue", "paint"]
  }
]''';
  }

  List<CraftIdea> _parseJson(String text) {
    String clean = text
        .trim()
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '');
    final start = clean.indexOf('[');
    final end = clean.lastIndexOf(']');
    if (start != -1 && end != -1) clean = clean.substring(start, end + 1);
    final List decoded = jsonDecode(clean);
    return decoded.map((e) => CraftIdea.fromJson(e)).toList();
  }
}
