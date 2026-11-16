import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class WorkOrderStore extends ChangeNotifier {
  WorkOrderStore(this._api);

  final ApiClient _api;

  NetworkData? network;
  List<WorkOrder> orders = [];
  String? error;
  bool loading = false;
  bool submitting = false;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([_api.fetchNetwork(), _api.fetchWorkOrders()]);
      network = results[0] as NetworkData;
      orders = results[1] as List<WorkOrder>;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  WorkOrder? orderById(String id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  Future<bool> openValve(WorkOrder order, Valve valve, bool success, String note) async {
    return _submit(() async {
      final operation = ValveOperation(
        valveId: valve.id,
        success: success,
        note: note,
        timestamp: DateTime.now(),
        technician: order.technician,
      );
      await _api.submitValveOperation(order.id, operation);
      await _applyLocally(order.id, (o) {
        final valves = o.valves
            .map((v) => v.id == valve.id
                ? v.copyWith(status: success ? AssetStatus.open : v.status)
                : v)
            .toList();
        return o.copyWith(
          valves: valves,
          valveOperations: [...o.valveOperations, operation],
          status: o.status == WorkOrderStatus.assigned
              ? WorkOrderStatus.inProgress
              : o.status,
        );
      });
    });
  }

  Future<bool> openHydrant(WorkOrder order, Hydrant hydrant, bool success, String note) async {
    return _submit(() async {
      final operation = HydrantOperation(
        hydrantId: hydrant.id,
        success: success,
        note: note,
        timestamp: DateTime.now(),
        technician: order.technician,
      );
      await _api.submitHydrantOperation(order.id, operation);
      await _applyLocally(order.id, (o) {
        final hydrants = o.hydrants
            .map((h) => h.id == hydrant.id
                ? h.copyWith(status: success ? AssetStatus.open : h.status)
                : h)
            .toList();
        return o.copyWith(
          hydrants: hydrants,
          hydrantOperations: [...o.hydrantOperations, operation],
          status: o.allValvesOpen && o.status != WorkOrderStatus.completed
              ? WorkOrderStatus.valvesDone
              : o.status,
        );
      });
    });
  }

  Future<bool> reportQuality(
      WorkOrder order, Hydrant hydrant, VisualQuality quality, double turbidity, String notes) async {
    return _submit(() async {
      final report = QualityReport(
        hydrantId: hydrant.id,
        visualQuality: quality,
        turbidityNtu: turbidity,
        notes: notes,
        timestamp: DateTime.now(),
      );
      await _api.submitQualityReport(order.id, report);
      await _applyLocally(order.id, (o) {
        final updated = o.copyWith(qualityReports: [...o.qualityReports, report]);
        return updated.copyWith(
          status: updated.isCompleted ? WorkOrderStatus.completed : updated.status,
        );
      });
    });
  }

  Future<bool> _submit(Future<void> Function() action) async {
    submitting = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<void> _applyLocally(String orderId, WorkOrder Function(WorkOrder) update) async {
    orders = orders
        .map((o) => o.id == orderId ? update(o) : o)
        .toList(growable: false);
    notifyListeners();
  }
}
