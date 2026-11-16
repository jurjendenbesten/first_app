import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/work_order_store.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<WorkOrderStore>();
    final order = store.orderById(orderId);

    if (order == null) {
      return const Scaffold(body: Center(child: Text('Opdracht niet gevonden.')));
    }

    return Scaffold(
      appBar: AppBar(title: Text(order.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(order.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          if (order.isCompleted)
            const _CompletedBanner()
          else
            _ProgressHeader(order: order),
          const SizedBox(height: 16),
          _SectionTitle('1. Afsluiters openen'),
          ...order.valves.map((valve) => _ValveTile(order: order, valve: valve)),
          const SizedBox(height: 16),
          _SectionTitle('2. Brandkranen openen en rapporteren'),
          if (!order.allValvesOpen)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Brandkranen worden beschikbaar zodra alle afsluiters open staan.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            )
          else
            ...order.hydrants.map(
                (hydrant) => _HydrantTile(order: order, hydrant: hydrant)),
          const SizedBox(height: 24),
          if (store.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Fout: ${store.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 12),
          Expanded(child: Text('Opdracht voltooid. Alles is gerapporteerd.')),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.order});

  final WorkOrder order;

  @override
  Widget build(BuildContext context) {
    final openValves = order.valves.where((v) => v.status == AssetStatus.open).length;
    final doneHydrants =
        order.hydrants.where((h) => order.hydrantOpened(h.id) && order.hydrantReported(h.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Afsluiters: $openValves/${order.valves.length} open'),
        Text('Brandkranen: $doneHydrants/${order.hydrants.length} afgerond'),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ValveTile extends StatelessWidget {
  const _ValveTile({required this.order, required this.valve});

  final WorkOrder order;
  final Valve valve;

  @override
  Widget build(BuildContext context) {
    final store = context.read<WorkOrderStore>();
    final isOpen = valve.status == AssetStatus.open;
    return Card(
      child: ListTile(
        leading: Icon(
          isOpen ? Icons.check_circle : Icons.settings_input_component,
          color: isOpen ? Colors.green : Colors.orange,
        ),
        title: Text(valve.name),
        subtitle: Text('Status: ${valve.status.label}'),
        trailing: FilledButton(
          onPressed: store.submitting
              ? null
              : () => _showValveSheet(context, store),
          child: Text(isOpen ? 'Wijzigen' : 'Open zetten'),
        ),
      ),
    );
  }

  void _showValveSheet(BuildContext context, WorkOrderStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _OperationSheet(
        title: 'Afsluiter: ${valve.name}',
        question: 'Is de afsluiter open gezet?',
        onSuccess: (note) async {
          Navigator.of(sheetContext).pop();
          await store.openValve(order, valve, true, note);
        },
        onFailure: (note) async {
          Navigator.of(sheetContext).pop();
          await store.openValve(order, valve, false, note);
        },
      ),
    );
  }
}

class _HydrantTile extends StatelessWidget {
  const _HydrantTile({required this.order, required this.hydrant});

  final WorkOrder order;
  final Hydrant hydrant;

  @override
  Widget build(BuildContext context) {
    final store = context.read<WorkOrderStore>();
    final opened = order.hydrantOpened(hydrant.id);
    final reported = order.hydrantReported(hydrant.id);

    final latestReport = order.qualityReports
        .where((r) => r.hydrantId == hydrant.id)
        .fold<QualityReport?>(null, (prev, r) => r);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  reported
                      ? Icons.check_circle
                      : opened
                          ? Icons.water_drop
                          : Icons.fire_hydrant_alt,
                  color: reported
                      ? Colors.green
                      : opened
                          ? Colors.indigo
                          : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(hydrant.name, style: Theme.of(context).textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: store.submitting
                        ? null
                        : () => _showHydrantSheet(context, store),
                    child: Text(opened ? 'Wijzigen' : 'Open zetten'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: opened && !reported && !store.submitting
                        ? () => _showQualitySheet(context, store)
                        : null,
                    child: const Text('Waterkwaliteit'),
                  ),
                ),
              ],
            ),
            if (reported && latestReport != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Laatste rapport: ${latestReport.visualQuality.label}, '
                  '${latestReport.turbidityNtu.toStringAsFixed(1)} NTU '
                  '(${DateFormat('dd-MM HH:mm').format(latestReport.timestamp)})',
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showHydrantSheet(BuildContext context, WorkOrderStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _OperationSheet(
        title: 'Brandkraan: ${hydrant.name}',
        question: 'Is de brandkraan open gezet?',
        onSuccess: (note) async {
          Navigator.of(sheetContext).pop();
          await store.openHydrant(order, hydrant, true, note);
        },
        onFailure: (note) async {
          Navigator.of(sheetContext).pop();
          await store.openHydrant(order, hydrant, false, note);
        },
      ),
    );
  }

  void _showQualitySheet(BuildContext context, WorkOrderStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _QualityReportSheet(
        hydrant: hydrant,
        onSubmit: (quality, turbidity, notes) async {
          Navigator.of(sheetContext).pop();
          await store.reportQuality(order, hydrant, quality, turbidity, notes);
        },
      ),
    );
  }
}

class _OperationSheet extends StatefulWidget {
  const _OperationSheet({
    required this.title,
    required this.question,
    required this.onSuccess,
    required this.onFailure,
  });

  final String title;
  final String question;
  final Future<void> Function(String note) onSuccess;
  final Future<void> Function(String note) onFailure;

  @override
  State<_OperationSheet> createState() => _OperationSheetState();
}

class _OperationSheetState extends State<_OperationSheet> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(widget.question),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Opmerking (optioneel)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () => widget.onSuccess(_noteController.text),
                  icon: const Icon(Icons.check),
                  label: const Text('Gelukt'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () => widget.onFailure(_noteController.text),
                  icon: const Icon(Icons.close),
                  label: const Text('Niet gelukt'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QualityReportSheet extends StatefulWidget {
  const _QualityReportSheet({required this.hydrant, required this.onSubmit});

  final Hydrant hydrant;
  final Future<void> Function(VisualQuality, double, String) onSubmit;

  @override
  State<_QualityReportSheet> createState() => _QualityReportSheetState();
}

class _QualityReportSheetState extends State<_QualityReportSheet> {
  VisualQuality _quality = VisualQuality.good;
  final _turbidityController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _turbidityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.onSubmit(
      _quality,
      double.parse(_turbidityController.text.replaceAll(',', '.')),
      _notesController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Waterkwaliteit: ${widget.hydrant.name}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Visuele beoordeling'),
            const SizedBox(height: 8),
            SegmentedButton<VisualQuality>(
              segments: const [
                ButtonSegment(
                  value: VisualQuality.good,
                  label: Text('Goed'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment(
                  value: VisualQuality.moderate,
                  label: Text('Matig'),
                  icon: Icon(Icons.remove_circle_outline),
                ),
                ButtonSegment(
                  value: VisualQuality.poor,
                  label: Text('Slecht'),
                  icon: Icon(Icons.error_outline),
                ),
              ],
              selected: {_quality},
              onSelectionChanged: (selection) =>
                  setState(() => _quality = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _turbidityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Troebelheid (NTU)',
                border: OutlineInputBorder(),
                hintText: 'bijv. 0,4',
              ),
              validator: (value) {
                final parsed =
                    double.tryParse(value?.replaceAll(',', '.') ?? '');
                if (parsed == null || parsed < 0) {
                  return 'Voer een geldig getal in';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Opmerkingen (optioneel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Rapport verzenden'),
            ),
          ],
        ),
      ),
    );
  }
}
