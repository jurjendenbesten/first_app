import 'package:latlong2/latlong.dart';

enum AssetStatus { unknown, closed, open }

enum WorkOrderStatus { assigned, inProgress, valvesDone, completed }

enum VisualQuality { good, moderate, poor }

extension VisualQualityX on VisualQuality {
  String get label => switch (this) {
        VisualQuality.good => 'Goed',
        VisualQuality.moderate => 'Matig',
        VisualQuality.poor => 'Slecht',
      };
}

extension AssetStatusX on AssetStatus {
  String get label => switch (this) {
        AssetStatus.unknown => 'Onbekend',
        AssetStatus.closed => 'Gesloten',
        AssetStatus.open => 'Open',
      };
}

class Pipe {
  final String id;
  final String name;
  final double diameterMm;
  final List<LatLng> points;

  const Pipe({
    required this.id,
    required this.name,
    required this.diameterMm,
    required this.points,
  });
}

class Valve {
  final String id;
  final String name;
  final LatLng position;
  final AssetStatus status;

  const Valve({
    required this.id,
    required this.name,
    required this.position,
    this.status = AssetStatus.unknown,
  });

  Valve copyWith({AssetStatus? status}) => Valve(
        id: id,
        name: name,
        position: position,
        status: status ?? this.status,
      );
}

class Hydrant {
  final String id;
  final String name;
  final LatLng position;
  final AssetStatus status;

  const Hydrant({
    required this.id,
    required this.name,
    required this.position,
    this.status = AssetStatus.unknown,
  });

  Hydrant copyWith({AssetStatus? status}) => Hydrant(
        id: id,
        name: name,
        position: position,
        status: status ?? this.status,
      );
}

class NetworkData {
  final List<Pipe> pipes;
  final List<Valve> valves;
  final List<Hydrant> hydrants;

  const NetworkData({
    required this.pipes,
    required this.valves,
    required this.hydrants,
  });
}

class ValveOperation {
  final String valveId;
  final bool success;
  final String note;
  final DateTime timestamp;
  final String technician;

  const ValveOperation({
    required this.valveId,
    required this.success,
    required this.note,
    required this.timestamp,
    required this.technician,
  });

  Map<String, dynamic> toJson() => {
        'valveId': valveId,
        'success': success,
        'note': note,
        'timestamp': timestamp.toIso8601String(),
        'technician': technician,
      };
}

class HydrantOperation {
  final String hydrantId;
  final bool success;
  final String note;
  final DateTime timestamp;
  final String technician;

  const HydrantOperation({
    required this.hydrantId,
    required this.success,
    required this.note,
    required this.timestamp,
    required this.technician,
  });

  Map<String, dynamic> toJson() => {
        'hydrantId': hydrantId,
        'success': success,
        'note': note,
        'timestamp': timestamp.toIso8601String(),
        'technician': technician,
      };
}

class QualityReport {
  final String hydrantId;
  final VisualQuality visualQuality;
  final double turbidityNtu;
  final String notes;
  final DateTime timestamp;

  const QualityReport({
    required this.hydrantId,
    required this.visualQuality,
    required this.turbidityNtu,
    required this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'hydrantId': hydrantId,
        'visualQuality': visualQuality.name,
        'turbidityNtu': turbidityNtu,
        'notes': notes,
        'timestamp': timestamp.toIso8601String(),
      };
}

class WorkOrder {
  final String id;
  final String title;
  final String description;
  final String technician;
  final WorkOrderStatus status;
  final List<Valve> valves;
  final List<Hydrant> hydrants;
  final List<ValveOperation> valveOperations;
  final List<HydrantOperation> hydrantOperations;
  final List<QualityReport> qualityReports;

  const WorkOrder({
    required this.id,
    required this.title,
    required this.description,
    required this.technician,
    required this.status,
    required this.valves,
    required this.hydrants,
    this.valveOperations = const [],
    this.hydrantOperations = const [],
    this.qualityReports = const [],
  });

  bool get allValvesOpen => valves.every((v) => v.status == AssetStatus.open);

  bool hydrantOpened(String hydrantId) => hydrantOperations
      .any((o) => o.hydrantId == hydrantId && o.success);

  bool hydrantReported(String hydrantId) =>
      qualityReports.any((r) => r.hydrantId == hydrantId);

  bool get isCompleted =>
      status == WorkOrderStatus.completed ||
      (allValvesOpen &&
          hydrants.isNotEmpty &&
          hydrants.every((h) => hydrantOpened(h.id) && hydrantReported(h.id)));

  WorkOrder copyWith({
    WorkOrderStatus? status,
    List<Valve>? valves,
    List<Hydrant>? hydrants,
    List<ValveOperation>? valveOperations,
    List<HydrantOperation>? hydrantOperations,
    List<QualityReport>? qualityReports,
  }) =>
      WorkOrder(
        id: id,
        title: title,
        description: description,
        technician: technician,
        status: status ?? this.status,
        valves: valves ?? this.valves,
        hydrants: hydrants ?? this.hydrants,
        valveOperations: valveOperations ?? this.valveOperations,
        hydrantOperations: hydrantOperations ?? this.hydrantOperations,
        qualityReports: qualityReports ?? this.qualityReports,
      );
}
