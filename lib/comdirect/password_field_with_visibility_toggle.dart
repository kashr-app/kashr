import 'package:flutter/material.dart';

class PasswordFieldWithVisibilityToggle extends StatefulWidget {
  final String label;
  final TextEditingController controller;

  /// Rejects what the field must not be left as.
  final FormFieldValidator<String>? validator;

  const PasswordFieldWithVisibilityToggle({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
  });

  @override
  State<PasswordFieldWithVisibilityToggle> createState() =>
      _PasswordFieldWithVisibilityToggleState();
}

class _PasswordFieldWithVisibilityToggleState
    extends State<PasswordFieldWithVisibilityToggle> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
      ),
    );
  }
}
