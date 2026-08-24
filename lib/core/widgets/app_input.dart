import 'package:flutter/material.dart';
import 'package:swasthyasetu_ai/core/theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final AutovalidateMode autovalidateMode;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onTap,
    this.validator,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: helperText,
            errorText: errorText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20)
                : null,
            suffixIcon: suffixIcon != null
                ? IconButton(
                    icon: suffixIcon!,
                    onPressed: onSuffixTap,
                    tooltip: 'Clear',
                  )
                : null,
            counterText: maxLength != null ? null : '',
          ),
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onTap: onTap,
          validator: validator,
          autovalidateMode: autovalidateMode,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  const AppSearchField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      autofocus: autofocus,
      decoration: InputDecoration(
        hintText: hint ?? 'Search...',
        prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant),
        suffixIcon: controller != null && controller!.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear_rounded, color: theme.colorScheme.onSurfaceVariant),
                onPressed: () {
                  controller!.clear();
                  onClear?.call();
                  onChanged?.call('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMd,
          vertical: AppTheme.spacingSm,
        ),
      ),
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted?.call(),
      style: theme.textTheme.bodyLarge,
    );
  }
}

class AppSelectField<T> extends StatelessWidget {
  final T? value;
  final String? label;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T?>? validator;
  final bool enabled;
  final IconData? prefixIcon;

  const AppSelectField({
    super.key,
    required this.value,
    required this.items,
    this.label,
    this.hint,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      ),
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      style: Theme.of(context).textTheme.bodyLarge,
      dropdownColor: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
    );
  }
}

class AppMultiSelectField<T> extends StatefulWidget {
  final List<T> selectedValues;
  final List<T> availableValues;
  final String Function(T) getLabel;
  final String? label;
  final String? hint;
  final ValueChanged<List<T>> onChanged;
  final bool enabled;
  final int? maxSelections;

  const AppMultiSelectField({
    super.key,
    required this.selectedValues,
    required this.availableValues,
    required this.getLabel,
    required this.onChanged,
    this.label,
    this.hint,
    this.enabled = true,
    this.maxSelections,
  });

  @override
  State<AppMultiSelectField<T>> createState() => _AppMultiSelectFieldState<T>();
}

class _AppMultiSelectFieldState<T> extends State<AppMultiSelectField<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppTheme.spacingXs),
        ],
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: widget.availableValues.map((value) {
            final isSelected = widget.selectedValues.contains(value);
            final isDisabled = !widget.enabled ||
                (widget.maxSelections != null &&
                 widget.selectedValues.length >= widget.maxSelections! &&
                 !isSelected);

            return FilterChip(
              label: Text(widget.getLabel(value)),
              selected: isSelected,
              onSelected: isDisabled
                  ? null
                  : (selected) {
                      final newValues = List<T>.from(widget.selectedValues);
                      if (selected) {
                        newValues.add(value);
                      } else {
                        newValues.remove(value);
                      }
                      widget.onChanged(newValues);
                    },
              selectedColor: theme.colorScheme.primaryContainer,
              checkmarkColor: theme.colorScheme.onPrimaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            );
          }).toList(),
        ),
        if (widget.hint != null && widget.selectedValues.isEmpty) ...[
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            widget.hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class AppChipInput extends StatefulWidget {
  final List<String> chips;
  final ValueChanged<List<String>> onChanged;
  final String? label;
  final String? hint;
  final String? addButtonLabel;
  final bool enabled;
  final int? maxChips;

  const AppChipInput({
    super.key,
    required this.chips,
    required this.onChanged,
    this.label,
    this.hint,
    this.addButtonLabel,
    this.enabled = true,
    this.maxChips,
  });

  @override
  State<AppChipInput> createState() => _AppChipInputState();
}

class _AppChipInputState extends State<AppChipInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addChip() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.chips.contains(text)) {
      if (widget.maxChips == null || widget.chips.length < widget.maxChips!) {
        final newChips = List<String>.from(widget.chips)..add(text);
        widget.onChanged(newChips);
        _controller.clear();
      }
    }
  }

  void _removeChip(String chip) {
    final newChips = List<String>.from(widget.chips)..remove(chip);
    widget.onChanged(newChips);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAtMax = widget.maxChips != null && widget.chips.length >= widget.maxChips!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppTheme.spacingXs),
        ],
        Wrap(
          spacing: AppTheme.spacingSm,
          runSpacing: AppTheme.spacingSm,
          children: [
            ...widget.chips.map((chip) => InputChip(
              label: Text(chip),
              onDeleted: widget.enabled ? () => _removeChip(chip) : null,
              deleteIconColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.bodyMedium,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            )),
            if (widget.enabled && !isAtMax)
              ActionChip(
                avatar: Icon(Icons.add_rounded, size: 16, color: theme.colorScheme.primary),
                label: Text(widget.addButtonLabel ?? 'Add'),
                onPressed: () {
                  _focusNode.requestFocus();
                  _showInputDialog();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
          ],
        ),
        if (widget.hint != null) ...[
          const SizedBox(height: AppTheme.spacingXs),
          Text(widget.hint!, style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
        ],
      ],
    );
  }

  void _showInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${widget.label?.toLowerCase() ?? 'item'}'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter ${widget.label?.toLowerCase() ?? 'value'}',
          ),
          onSubmitted: (_) {
            _addChip();
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _addChip();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}