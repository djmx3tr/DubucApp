class Job {
  final int id;
  final String? essence;
  final String? coupe;
  final String? dimension;
  final String? agencement;
  final String? description;
  final String? source;
  final List<Palette> palettes;

  Job({
    required this.id,
    this.essence,
    this.coupe,
    this.dimension,
    this.agencement,
    this.description,
    this.source,
    this.palettes = const [],
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final details = json['job_details'] as Map<String, dynamic>?;
    final palettesJson = json['palettes'] as List<dynamic>? ?? [];

    return Job(
      id: json['job_id'] ?? 0,
      essence: details?['essence'],
      coupe: details?['coupe'],
      dimension: details?['dimension'],
      agencement: details?['agencement'],
      description: details?['description'],
      source: json['source'],
      palettes: palettesJson.map((p) => Palette.fromJson(p)).toList(),
    );
  }

  String get displayTitle => description ?? 'Job #$id';
  
  String get displayInfo {
    final parts = <String>[];
    if (essence != null && essence!.isNotEmpty) parts.add(essence!);
    if (coupe != null && coupe!.isNotEmpty) parts.add(coupe!);
    if (dimension != null && dimension!.isNotEmpty) parts.add(dimension!);
    return parts.join(' • ');
  }
}

class Palette {
  final String id;
  int quantity;

  Palette({
    required this.id,
    required this.quantity,
  });

  factory Palette.fromJson(Map<String, dynamic> json) {
    return Palette(
      id: json['id_palette']?.toString() ?? '',
      quantity: json['qty'] ?? 0,
    );
  }
}

class CurrentJob {
  final String jobNumber;
  final String? line;
  final DateTime? timestamp;

  CurrentJob({
    required this.jobNumber,
    this.line,
    this.timestamp,
  });

  factory CurrentJob.fromJson(Map<String, dynamic> json) {
    return CurrentJob(
      jobNumber: json['job_number']?.toString() ?? '',
      line: json['line']?.toString(),
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }
}
