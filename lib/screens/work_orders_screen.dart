import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/work_order_store.dart';
import 'order_detail_screen.dart';

class WorkOrdersScreen extends StatelessWidget {
  const WorkOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkOrderStore>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Opdrachten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: store.refresh,
          ),
        ],
      ),
      body: store.loading && store.orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : store.error != null && store.orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Kon opdrachten niet laden: ${store.error}'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: store.refresh,
                        child: const Text('Opnieuw proberen'),
                      ),
                    ],
                  ),
                )
              : store.orders.isEmpty
                  ? const Center(child: Text('Geen openstaande opdrachten.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: store.orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final order = store.orders[index];
                        return Card(
                          child: ListTile(
                            leading: _StatusIcon(status: order.status),
                            title: Text(order.title),
                            subtitle: Text(
                              '${order.valves.length} afsluiters · '
                              '${order.hydrants.length} brandkranen\n'
                              '${order.description}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    OrderDetailScreen(orderId: order.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final WorkOrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      WorkOrderStatus.assigned => Colors.blueGrey,
      WorkOrderStatus.inProgress => Colors.orange,
      WorkOrderStatus.valvesDone => Colors.indigo,
      WorkOrderStatus.completed => Colors.green,
    };
    final icon = switch (status) {
      WorkOrderStatus.assigned => Icons.assignment_outlined,
      WorkOrderStatus.inProgress => Icons.engineering,
      WorkOrderStatus.valvesDone => Icons.water_drop,
      WorkOrderStatus.completed => Icons.check_circle,
    };
    return Icon(icon, color: color, size: 32);
  }
}
