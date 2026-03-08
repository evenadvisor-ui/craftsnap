import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanRecord> _allHistory = [];
  bool _loading = true;
  DateTime? _selectedDate;
  final ScrollController _dateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final h = await StorageService.instance.loadHistory();
    setState(() {
      _allHistory = h;
      _loading = false;
    });
  }

  // ── Unique dates in history ───────────────────

  List<DateTime> get _uniqueDates {
    final seen = <String>{};
    final dates = <DateTime>[];
    for (final r in _allHistory) {
      final key = _dateKey(r.scannedAt);
      if (seen.add(key)) {
        dates.add(
          DateTime(r.scannedAt.year, r.scannedAt.month, r.scannedAt.day),
        );
      }
    }
    return dates;
  }

  String _dateKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  // ── Filtered records ──────────────────────────

  List<ScanRecord> get _filtered {
    if (_selectedDate == null) return _allHistory;
    return _allHistory
        .where((r) => _dateKey(r.scannedAt) == _dateKey(_selectedDate!))
        .toList();
  }

  // ── Delete ────────────────────────────────────

  Future<void> _delete(String id) async {
    await StorageService.instance.deleteScan(id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scan deleted'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text(
          'This will delete all scan history permanently. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StorageService.instance.saveHistory([]);
      await _load();
    }
  }

  // ── Calendar picker ───────────────────────────

  Future<void> _pickFromCalendar() async {
    final dates = _uniqueDates;
    if (dates.isEmpty) return;
    final first = dates.last;
    final last = dates.first;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? last,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: Colors.green)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(
        () => _selectedDate = dates.any((d) => _dateKey(d) == _dateKey(picked))
            ? picked
            : null,
      );
    }
  }

  // ── Format helpers ────────────────────────────

  String _formatDateChip(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (_dateKey(dt) == _dateKey(today)) return 'Today';
    if (_dateKey(dt) == _dateKey(yesterday)) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Scan History 📦'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickFromCalendar,
            tooltip: 'Pick date',
          ),
          if (_allHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _deleteAll,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _allHistory.isEmpty
          ? _emptyState()
          : Column(
              children: [
                // ── Date chips row ──
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  child: SingleChildScrollView(
                    controller: _dateScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // "All" chip
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All'),
                            selected: _selectedDate == null,
                            selectedColor: Colors.green,
                            labelStyle: TextStyle(
                              color: _selectedDate == null
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedDate = null),
                          ),
                        ),
                        ..._uniqueDates.map(
                          (date) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_formatDateChip(date)),
                              selected:
                                  _selectedDate != null &&
                                  _dateKey(_selectedDate!) == _dateKey(date),
                              selectedColor: Colors.green,
                              labelStyle: TextStyle(
                                color:
                                    _selectedDate != null &&
                                        _dateKey(_selectedDate!) ==
                                            _dateKey(date)
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              onSelected: (_) =>
                                  setState(() => _selectedDate = date),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Record count ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${_filtered.length} scan${_filtered.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── List ──
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No scans on ${_formatDateChip(_selectedDate!)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final record = _filtered[i];
                            return Dismissible(
                              key: Key(record.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) => _delete(record.id),
                              child: _HistoryCard(
                                record: record,
                                time: _formatTime(record.scannedAt),
                                onDelete: () => _delete(record.id),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 70, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No scans yet!',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 6),
          Text(
            'Scan some objects to see them here.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final ScanRecord record;
  final String time;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.record,
    required this.time,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(borderRadius: BorderRadius.circular(10), child: _thumb()),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.allLabels.map((l) => l.toUpperCase()).join(', '),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${record.detections.length} item(s)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Delete button
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb() {
    final file = File(record.imagePath);
    if (file.existsSync()) {
      return Image.file(file, width: 60, height: 60, fit: BoxFit.cover);
    }
    return Container(
      width: 60,
      height: 60,
      color: Colors.green.shade50,
      child: const Icon(Icons.image, color: Colors.green),
    );
  }
}
