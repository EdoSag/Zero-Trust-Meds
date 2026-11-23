import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meds_data.dart';
import '../logic/stock.dart';
import '../model/models.dart';
import 'common.dart';

/// "About 12 tablets left · runs out around 3 Dec", or "Order more" with
/// an icon when it's time (never colour alone).
class StockLine extends StatelessWidget {
  const StockLine(this.status, this.medicine, {super.key, required this.today});
  final StockStatus status;
  final Medication medicine;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final low = status.lowOn(today);
    final scheme = Theme.of(context).colorScheme;
    final color = low ? scheme.error : null;
    final runsOut = status.runsOutOn;
    final text = [
      if (low) status.isOut ? l.stockNoneLeft : l.stockOrderMore,
      if (!status.isOut)
        l.stockLeft(stockAmount(context, status.left, medicine)),
      if (!status.isOut && runsOut != null)
        l.stockRunsOut(formatLocalDate(context, runsOut)),
    ].join(' · ');
    return Row(
      children: [
        Icon(
          low ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: low ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// "12 tablets", "80 ml", or a bare number of doses.
String stockAmount(BuildContext context, double amount, Medication m) {
  // Whole units for tablets and the like; one decimal for liquids.
  final rounded = (amount * 10).floor() / 10;
  final n = formatAmount(context, rounded);
  return m.amount != null && m.unit.trim().isNotEmpty ? '$n ${m.unit}' : n;
}

/// Asks how much of [medicine] is left and when to be reminded to order
/// more. Any caregiver may count.
Future<void> openStock(
  BuildContext context,
  WidgetRef ref,
  ChildData c,
  Medication medicine,
) async {
  final now = DateTime.now().toUtc();
  final current = c.stockOf(medicine, now);
  final saved = await showDialog<_StockAnswer>(
    context: context,
    builder: (_) => _StockDialog(medicine: medicine, current: current),
  );
  if (saved == null || !context.mounted) return;
  final actions = ref.read(medsActionsProvider);
  try {
    if (saved.stop) {
      await actions.stopCounting(c, medicine);
    } else {
      await actions.countStock(
        c,
        medicine: medicine,
        count: saved.count,
        warnDays: saved.warnDays,
      );
      if (context.mounted) showSnack(context, context.l.stockSaved);
    }
  } on Object {
    if (context.mounted) showSnack(context, context.l.saveFailedOffline);
  }
}

class _StockAnswer {
  const _StockAnswer({this.count = 0, this.warnDays = 7, this.stop = false});
  final double count;
  final int warnDays;
  final bool stop;
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.medicine, this.current});
  final Medication medicine;
  final StockStatus? current;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  late final _count = TextEditingController(
    text: widget.current == null
        ? ''
        : _plain(((widget.current!.left * 10).floor() / 10)),
  );
  late int _warn = widget.current?.stock.warnDays ?? 7;
  String? _error;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_count.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0 || v > 100000) {
      setState(() => _error = context.l.required);
      return;
    }
    Navigator.of(context).pop(_StockAnswer(count: v, warnDays: _warn));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final m = widget.medicine;
    final unit = m.amount != null && m.unit.trim().isNotEmpty ? m.unit : null;
    final warnChoices = {...MedStock.warnChoices, _warn}.toList()..sort();
    return AlertDialog(
      title: Text('${l.stockTitle}: ${m.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _count,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: l.stockHowMuch,
                helperText: unit == null ? l.stockInDoses : l.stockInUnit(unit),
                helperMaxLines: 3,
                errorText: _error,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text(l.stockWarn, style: Theme.of(context).textTheme.labelLarge),
            DropdownButton<int>(
              isExpanded: true,
              value: _warn,
              onChanged: (v) => setState(() => _warn = v ?? _warn),
              items: [
                for (final d in warnChoices)
                  DropdownMenuItem(value: d, child: Text(l.stockDaysBefore(d))),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _StockAnswer(stop: true)),
            child: Text(l.stockStop),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
