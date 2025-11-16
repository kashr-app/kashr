import 'package:flutter/material.dart';

class PasswordFieldWithVisibilityToggle extends StatefulWidget {
  final String label;
  final TextEditingController controller;

  const PasswordFieldWithVisibilityToggle({
    super.key,
    required this.label,
    required this.controller,
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
