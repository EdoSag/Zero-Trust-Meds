import 'package:flutter/material.dart';

import '../logic/medicine_names.dart';
import '../model/models.dart';
import 'common.dart';

/// The medicine name, with suggestions while typing: the family's own
/// medicines first (picking one fills in its dose too), then common names
/// that work offline (see [builtInMedicines]).
class MedicineNameField extends StatefulWidget {
  const MedicineNameField({
    super.key,
    required this.controller,
    this.family = const [],
    this.fieldKey,
    this.onChanged,
    this.onSaved,
  });

  final TextEditingController controller;
  final List<Medication> family;
  final Key? fieldKey;

  /// The text changed, typed or picked from a common name.
  final VoidCallback? onChanged;

  /// One of the family's own medicines was picked.
  final ValueChanged<Medication>? onSaved;

  @override
  State<MedicineNameField> createState() => _MedicineNameFieldState();
}

class _MedicineNameFieldState extends State<MedicineNameField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return RawAutocomplete<MedicineSuggestion>(
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (o) => o.name,
      optionsBuilder: (v) => MedicineNames.suggest(v.text, widget.family),
      onSelected: (o) {
        final saved = o.saved;
        if (saved != null) {
          widget.onSaved?.call(saved);
        } else {
          widget.onChanged?.call();
        }
      },
      fieldViewBuilder: (context, controller, focus, onSubmitted) =>
          TextFormField(
            key: widget.fieldKey,
            controller: controller,
            focusNode: focus,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.medicineName),
            validator: (v) => v == null || v.trim().isEmpty ? l.required : null,
            onChanged: (_) => widget.onChanged?.call(),
            onFieldSubmitted: (_) => onSubmitted(),
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    leading: Icon(
                      o.saved != null
                          ? Icons.bookmark_outline
                          : Icons.medication,
                    ),
                    title: Text(o.name),
                    subtitle: o.saved != null
                        ? Text(
                            [
                              l.medicineFromFamilyList,
                              if (o.saved!.amount != null)
                                doseText(context, o.saved!),
                            ].join(' · '),
                          )
                        : o.also.isEmpty
                        ? null
                        : Text(o.also.take(3).join(', ')),
                    onTap: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
