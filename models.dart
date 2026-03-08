
// ─── Detection ────────────────────────────────────────────────────────────────

class Detection {
  final double x1, y1, x2, y2;
  final int classIndex;
  final String label;
  final double confidence;

  const Detection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.classIndex,
    required this.label,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
    'classIndex': classIndex,
    'label': label,
    'confidence': confidence,
  };

  factory Detection.fromJson(Map<String, dynamic> j) => Detection(
    x1: j['x1'],
    y1: j['y1'],
    x2: j['x2'],
    y2: j['y2'],
    classIndex: j['classIndex'],
    label: j['label'],
    confidence: j['confidence'],
  );
}

// ─── ScanRecord (history entry) ───────────────────────────────────────────────

class ScanRecord {
  final String id;
  final String imagePath;
  final List<Detection> detections;
  final DateTime scannedAt;

  ScanRecord({
    required this.id,
    required this.imagePath,
    required this.detections,
    required this.scannedAt,
  });

  /// Primary label for display
  String get primaryLabel =>
      detections.isNotEmpty ? detections.first.label : 'Unknown';

  List<String> get allLabels => detections.map((d) => d.label).toList();

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'detections': detections.map((d) => d.toJson()).toList(),
    'scannedAt': scannedAt.toIso8601String(),
  };

  factory ScanRecord.fromJson(Map<String, dynamic> j) => ScanRecord(
    id: j['id'],
    imagePath: j['imagePath'],
    detections: (j['detections'] as List)
        .map((d) => Detection.fromJson(d))
        .toList(),
    scannedAt: DateTime.parse(j['scannedAt']),
  );
}

// ─── CraftIdea ────────────────────────────────────────────────────────────────

class CraftIdea {
  final String title;
  final String description;
  final List<String> steps;
  final List<String> materials;
  bool isFavourite;

  CraftIdea({
    required this.title,
    required this.description,
    required this.steps,
    required this.materials,
    this.isFavourite = false,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'steps': steps,
    'materials': materials,
    'isFavourite': isFavourite,
  };

  factory CraftIdea.fromJson(Map<String, dynamic> j) => CraftIdea(
    title: j['title'],
    description: j['description'],
    steps: List<String>.from(j['steps']),
    materials: List<String>.from(j['materials']),
    isFavourite: j['isFavourite'] ?? false,
  );
}

// ─── CraftMode ────────────────────────────────────────────────────────────────

enum CraftMode {
  currentOnly,
  currentAndPast,
  currentAndFuture,
  pastPresentFuture,
}

extension CraftModeExt on CraftMode {
  String get title {
    switch (this) {
      case CraftMode.currentOnly:
        return 'Current Object';
      case CraftMode.currentAndPast:
        return 'Current + Past Scan';
      case CraftMode.currentAndFuture:
        return 'Current + Future Item';
      case CraftMode.pastPresentFuture:
        return 'Past + Present + Future';
    }
  }

  String get subtitle {
    switch (this) {
      case CraftMode.currentOnly:
        return 'Craft using only what you just scanned';
      case CraftMode.currentAndPast:
        return 'Combine today\'s scan with a previous one';
      case CraftMode.currentAndFuture:
        return 'Plan ahead with an item you\'ll get later';
      case CraftMode.pastPresentFuture:
        return 'Use past, present and a future item together';
    }
  }

  String get emoji {
    switch (this) {
      case CraftMode.currentOnly:
        return '🎯';
      case CraftMode.currentAndPast:
        return '📦';
      case CraftMode.currentAndFuture:
        return '🔮';
      case CraftMode.pastPresentFuture:
        return '✨';
    }
  }
}
