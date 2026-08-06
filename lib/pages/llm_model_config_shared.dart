import 'package:flutter/material.dart';

// ============================================================================
// LabeledTextField — simple label + description + text field
// ============================================================================

class LabeledTextField extends StatelessWidget {
  final String label;
  final String? description;
  final TextEditingController controller;
  final String? hintText;
  final bool required;
  final TextInputType keyboardType;
  final int? maxLines;

  const LabeledTextField({
    super.key,
    required this.label,
    this.description,
    required this.controller,
    this.hintText,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${required ? ' *' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              description!,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
        ),
      ],
    );
  }
}

// ============================================================================
// LlmToggleSlider — slider with toggle switch
// ============================================================================

class LlmToggleSlider extends StatelessWidget {
  final String label;
  final String? description;
  final bool enabled;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onToggle;
  final double min;
  final double max;
  final int divisions;

  const LlmToggleSlider({
    super.key,
    required this.label,
    this.description,
    required this.enabled,
    required this.value,
    required this.onChanged,
    required this.onToggle,
    this.min = 0,
    this.max = 2,
    this.divisions = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  description!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (enabled)
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: value,
                      min: min,
                      max: max,
                      divisions: divisions,
                      onChanged: onChanged,
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      value.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LlmToggleTextField — text field with toggle switch
// ============================================================================

class LlmToggleTextField extends StatelessWidget {
  final String label;
  final String? description;
  final bool enabled;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;
  final String? hintText;
  final bool required;
  final TextInputType keyboardType;

  const LlmToggleTextField({
    super.key,
    required this.label,
    this.description,
    required this.enabled,
    required this.controller,
    required this.onToggle,
    this.hintText,
    this.required = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$label${required ? ' *' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Switch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (description != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  description!,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (enabled)
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: keyboardType,
              ),
          ],
        ),
      ),
    );
  }
}
