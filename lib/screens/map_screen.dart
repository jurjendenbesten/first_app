import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/work_order_store.dart';
import 'order_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  static const _center = LatLng(52.0915, 5.1300);

  void _flyTo(LatLng target) {
    _mapController.move(target, 17);
  }

  void _showAssetSheet(BuildContext context, String title, String subtitle,
      {WorkOrder? order, VoidCallback? onOpenOrder}) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            if (order != null && onOpenOrder != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onOpenOrder();
                },
                icon: const Icon(Icons.assignment),
                label: const Text('Naar opdracht'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkOrderStore>();
    final network = store.network;

    return Scaffold(
      appBar: AppBar(title: const Text('Leidingnetwerk')),
      body: store.loading
          ? const Center(child: CircularProgressIndicator())
          : store.error != null && network == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Kon gegevens niet laden: ${store.error}'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: store.refresh,
                        child: const Text('Opnieuw proberen'),
                      ),
                    ],
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'nl.jurjen.firstapp',
                    ),
                    if (network != null)
                      PolylineLayer(
                        polylines: [
                          for (final pipe in network.pipes)
                            Polyline(
                              points: pipe.points,
                              strokeWidth: 4,
                              color: const Color(0xFF0064C8),
                            ),
                        ],
                      ),
                    if (network != null)
                      MarkerLayer(
                        markers: [
                          for (final valve in network.valves)
                            Marker(
                              point: valve.position,
                              width: 44,
                              height: 44,
                              child: _AssetMarker(
                                icon: Icons.settings_input_component,
                                color: _statusColor(valve.status),
                                label: 'A',
                                onTap: () {
                                  final order = _orderWithValve(store, valve.id);
                                  _showAssetSheet(
                                    context,
                                    valve.name,
                                    'Status: ${valve.status.label}',
                                    order: order,
                                    onOpenOrder: () => _openOrder(context, order!),
                                  );
                                },
                              ),
                            ),
                          for (final hydrant in network.hydrants)
                            Marker(
                              point: hydrant.position,
                              width: 44,
                              height: 44,
                              child: _AssetMarker(
                                icon: Icons.fire_hydrant_alt,
                                color: _statusColor(hydrant.status),
                                label: 'B',
                                onTap: () {
                                  final order =
                                      _orderWithHydrant(store, hydrant.id);
                                  _showAssetSheet(
                                    context,
                                    hydrant.name,
                                    'Status: ${hydrant.status.label}',
                                    order: order,
                                    onOpenOrder: () => _openOrder(context, order!),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
      floatingActionButton: network == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                final points = network!.pipes.expand((p) => p.points).toList();
                if (points.isNotEmpty) {
                  _flyTo(points.first);
                }
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Startpunt'),
            ),
    );
  }

  void _openOrder(BuildContext context, WorkOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(orderId: order.id),
      ),
    );
  }

  WorkOrder? _orderWithValve(WorkOrderStore store, String valveId) {
    for (final order in store.orders) {
      if (order.valves.any((v) => v.id == valveId) && !order.isCompleted) {
        return order;
      }
    }
    return null;
  }

  WorkOrder? _orderWithHydrant(WorkOrderStore store, String hydrantId) {
    for (final order in store.orders) {
      if (order.hydrants.any((h) => h.id == hydrantId) && !order.isCompleted) {
        return order;
      }
    }
    return null;
  }

  Color _statusColor(AssetStatus status) => switch (status) {
        AssetStatus.open => Colors.green,
        AssetStatus.closed => Colors.orange,
        AssetStatus.unknown => Colors.grey,
      };
}

class _AssetMarker extends StatelessWidget {
  const _AssetMarker({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(blurRadius: 4, color: Colors.black26),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          CircleAvatar(
            radius: 7,
            backgroundColor: Colors.white,
            child: Text(
              label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
