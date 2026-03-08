import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class StorageService {
  static const _historyFile = 'scan_history.json';
  static const _favouritesFile = 'favourites.json';

  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();
  StorageService._();

  // ── helpers ──────────────────────────────────

  Future<File> _getFile(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$name');
  }

  // ── Scan History ─────────────────────────────

  Future<List<ScanRecord>> loadHistory() async {
    try {
      final file = await _getFile(_historyFile);
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => ScanRecord.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<ScanRecord> records) async {
    final file = await _getFile(_historyFile);
    await file.writeAsString(
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> addScan(ScanRecord record) async {
    final history = await loadHistory();
    history.insert(0, record);
    // Keep last 50 scans
    if (history.length > 50) history.removeLast();
    await saveHistory(history);
  }

  Future<void> deleteScan(String id) async {
    final history = await loadHistory();
    history.removeWhere((r) => r.id == id);
    await saveHistory(history);
  }

  // ── Favourites ───────────────────────────────

  Future<List<CraftIdea>> loadFavourites() async {
    try {
      final file = await _getFile(_favouritesFile);
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => CraftIdea.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addFavourite(CraftIdea craft) async {
    final favs = await loadFavourites();
    // Avoid duplicates by title
    if (favs.any((f) => f.title == craft.title)) return;
    craft.isFavourite = true;
    favs.insert(0, craft);
    await _saveFavourites(favs);
  }

  Future<void> removeFavourite(String title) async {
    final favs = await loadFavourites();
    favs.removeWhere((f) => f.title == title);
    await _saveFavourites(favs);
  }

  Future<void> _saveFavourites(List<CraftIdea> favs) async {
    final file = await _getFile(_favouritesFile);
    await file.writeAsString(jsonEncode(favs.map((f) => f.toJson()).toList()));
  }

  Future<bool> isFavourite(String title) async {
    final favs = await loadFavourites();
    return favs.any((f) => f.title == title);
  }
}
