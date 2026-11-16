import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/models.dart';

/// Base URL of the Blazor / ASP.NET Core backend.
/// Override at build time with: --dart-define=API_BASE_URL=https://jouw-server
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
}

/// Contract implemented by both the REST client (production) and the
/// mock client (demo mode without a backend).
abstract class ApiClient {
  Future<NetworkData> fetchNetwork();
  Future<List<WorkOrder>> fetchWorkOrders();
  Future<void> submitValveOperation(String orderId, ValveOperation operation);
  Future<void> submitHydrantOperation(
      String orderId, HydrantOperation operation);
  Future<void> submitQualityReport(String orderId, QualityReport report);
}

ApiClient createApiClient({bool useMock = false}) =>
    useMock ? MockApiClient() : RestApiClient(ApiConfig.baseUrl);

class RestApiClient implements ApiClient {
  final String baseUrl;

  RestApiClient(this.baseUrl);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(_uri(path)).timeout(
          const Duration(seconds: 15),
        );
    if (response.statusCode != 200) {
      throw ApiException('GET $path gaf status ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final response = await http
        .post(
          _uri(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('POST $path gaf status ${response.statusCode}');
    }
  }

  @override
  Future<NetworkData> fetchNetwork() async {
    final json = await _get('/api/network');
    return NetworkData(
      pipes: (json['pipes'] as List)
          .map((p) => Pipe(
                id: p['id'] as String,
                name: p['name'] as String,
                diameterMm: (p['diameterMm'] as num).toDouble(),
                points: (p['points'] as List)
                    .map((pt) => LatLng(
                          (pt['latitude'] as num).toDouble(),
                          (pt['longitude'] as num).toDouble(),
                        ))
                    .toList(),
              ))
          .toList(),
      valves: (json['valves'] as List)
          .map((v) => Valve(
                id: v['id'] as String,
                name: v['name'] as String,
                position: LatLng(
                  (v['latitude'] as num).toDouble(),
                  (v['longitude'] as num).toDouble(),
                ),
                status: _statusFromName(v['status'] as String?),
              ))
          .toList(),
      hydrants: (json['hydrants'] as List)
          .map((h) => Hydrant(
                id: h['id'] as String,
                name: h['name'] as String,
                position: LatLng(
                  (h['latitude'] as num).toDouble(),
                  (h['longitude'] as num).toDouble(),
                ),
                status: _statusFromName(h['status'] as String?),
              ))
          .toList(),
    );
  }

  @override
  Future<List<WorkOrder>> fetchWorkOrders() async {
    final json = await _get('/api/workorders');
    return (json['workOrders'] as List)
        .map((o) => _workOrderFromJson(o as Map<String, dynamic>))
        .toList();
  }

  WorkOrder _workOrderFromJson(Map<String, dynamic> o) => WorkOrder(
        id: o['id'] as String,
        title: o['title'] as String,
        description: o['description'] as String? ?? '',
        technician: o['technician'] as String? ?? '',
        status: WorkOrderStatus
            .values[(o['status'] as int?) ?? 0],
        valves: (o['valves'] as List? ?? [])
            .map((v) => Valve(
                  id: v['id'] as String,
                  name: v['name'] as String,
                  position: LatLng(
                    (v['latitude'] as num).toDouble(),
                    (v['longitude'] as num).toDouble(),
                  ),
                  status: _statusFromName(v['status'] as String?),
                ))
            .toList(),
        hydrants: (o['hydrants'] as List? ?? [])
            .map((h) => Hydrant(
                  id: h['id'] as String,
                  name: h['name'] as String,
                  position: LatLng(
                    (h['latitude'] as num).toDouble(),
                    (h['longitude'] as num).toDouble(),
                  ),
                  status: _statusFromName(h['status'] as String?),
                ))
            .toList(),
      );

  AssetStatus _statusFromName(String? name) => AssetStatus.values
      .firstWhere((s) => s.name == name, orElse: () => AssetStatus.unknown);

  @override
  Future<void> submitValveOperation(
      String orderId, ValveOperation operation) async {
    await _post('/api/workorders/$orderId/valves/${operation.valveId}/operation',
        operation.toJson());
  }

  @override
  Future<void> submitHydrantOperation(
      String orderId, HydrantOperation operation) async {
    await _post(
        '/api/workorders/$orderId/hydrants/${operation.hydrantId}/operation',
        operation.toJson());
  }

  @override
  Future<void> submitQualityReport(
      String orderId, QualityReport report) async {
    await _post(
        '/api/workorders/$orderId/hydrants/${report.hydrantId}/quality',
        report.toJson());
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Demo client with a small fictional network so the app works
/// without a running backend.
class MockApiClient implements ApiClient {
  final NetworkData _network = const NetworkData(
    pipes: [
      Pipe(
        id: 'p1',
        name: 'Hoofdleiding A',
        diameterMm: 200,
        points: [
          LatLng(52.0905, 5.1210),
          LatLng(52.0920, 5.1280),
          LatLng(52.0945, 5.1340),
        ],
      ),
      Pipe(
        id: 'p2',
        name: 'Hoofdleiding B',
        diameterMm: 150,
        points: [
          LatLng(52.0920, 5.1280),
          LatLng(52.0890, 5.1300),
          LatLng(52.0865, 5.1325),
        ],
      ),
      Pipe(
        id: 'p3',
        name: 'Verdeelstuk C',
        diameterMm: 100,
        points: [
          LatLng(52.0945, 5.1340),
          LatLng(52.0960, 5.1390),
        ],
      ),
    ],
    valves: [
      Valve(
        id: 'v1',
        name: 'Afsluiter A1',
        position: LatLng(52.0920, 5.1280),
        status: AssetStatus.closed,
      ),
      Valve(
        id: 'v2',
        name: 'Afsluiter A2',
        position: LatLng(52.0945, 5.1340),
        status: AssetStatus.closed,
      ),
      Valve(
        id: 'v3',
        name: 'Afsluiter B1',
        position: LatLng(52.0890, 5.1300),
        status: AssetStatus.open,
      ),
    ],
    hydrants: [
      Hydrant(
        id: 'h1',
        name: 'Brandkraan 12',
        position: LatLng(52.0960, 5.1390),
      ),
      Hydrant(
        id: 'h2',
        name: 'Brandkraan 7',
        position: LatLng(52.0865, 5.1325),
      ),
    ],
  );

  List<WorkOrder> _orders = [
    WorkOrder(
      id: 'wo-2024-001',
      title: 'Doorspoeling wijk Oost',
      description:
          'Zet afsluiters A1 en A2 open en spoel daarna brandkraan 12 door. '
          'Rapporteer de waterkwaliteit en troebelheid.',
      technician: 'monteur-1',
      status: WorkOrderStatus.assigned,
      valves: [
        const Valve(
          id: 'v1',
          name: 'Afsluiter A1',
          position: LatLng(52.0920, 5.1280),
          status: AssetStatus.closed,
        ),
        const Valve(
          id: 'v2',
          name: 'Afsluiter A2',
          position: LatLng(52.0945, 5.1340),
          status: AssetStatus.closed,
        ),
      ],
      hydrants: [
        const Hydrant(
          id: 'h1',
          name: 'Brandkraan 12',
          position: LatLng(52.0960, 5.1390),
        ),
      ],
    ),
    WorkOrder(
      id: 'wo-2024-002',
      title: 'Doorspoeling wijk Zuid',
      description:
          'Zet afsluiter B1 open en spoel brandkraan 7 door. '
          'Rapporteer de waterkwaliteit en troebelheid.',
      technician: 'monteur-1',
      status: WorkOrderStatus.assigned,
      valves: [
        const Valve(
          id: 'v3',
          name: 'Afsluiter B1',
          position: LatLng(52.0890, 5.1300),
          status: AssetStatus.closed,
        ),
      ],
      hydrants: [
        const Hydrant(
          id: 'h2',
          name: 'Brandkraan 7',
          position: LatLng(52.0865, 5.1325),
        ),
      ],
    ),
  ];

  final Duration _latency = const Duration(milliseconds: 250);

  @override
  Future<NetworkData> fetchNetwork() async {
    await Future.delayed(_latency);
    return _network;
  }

  @override
  Future<List<WorkOrder>> fetchWorkOrders() async {
    await Future.delayed(_latency);
    return List.unmodifiable(_orders);
  }

  @override
  Future<void> submitValveOperation(
      String orderId, ValveOperation operation) async {
    await Future.delayed(_latency);
    _orders = _orders.map((order) {
      if (order.id != orderId) return order;
      return order.copyWith(
        status: WorkOrderStatus.inProgress,
        valves: order.valves
            .map((v) => v.id == operation.valveId
                ? v.copyWith(
                    status:
                        operation.success ? AssetStatus.open : v.status)
                : v)
            .toList(),
        valveOperations: [...order.valveOperations, operation],
      );
    }).toList();
  }

  @override
  Future<void> submitHydrantOperation(
      String orderId, HydrantOperation operation) async {
    await Future.delayed(_latency);
    _orders = _orders.map((order) {
      if (order.id != orderId) return order;
      return order.copyWith(
        status: WorkOrderStatus.valvesDone,
        hydrants: order.hydrants
            .map((h) => h.id == operation.hydrantId
                ? h.copyWith(
                    status:
                        operation.success ? AssetStatus.open : h.status)
                : h)
            .toList(),
        hydrantOperations: [...order.hydrantOperations, operation],
      );
    }).toList();
  }

  @override
  Future<void> submitQualityReport(
      String orderId, QualityReport report) async {
    await Future.delayed(_latency);
    _orders = _orders.map((order) {
      if (order.id != orderId) return order;
      return order.copyWith(
        qualityReports: [...order.qualityReports, report],
      );
    }).toList();
  }
}
