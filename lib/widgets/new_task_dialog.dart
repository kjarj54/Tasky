import 'package:flutter/material.dart';

class NewTaskDialog extends StatefulWidget {
  final String? initialValue;
  final String title;

  const NewTaskDialog({
    super.key, 
    this.initialValue,
    this.title = 'Nueva Tarea',
  });

  @override
  State<NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends State<NewTaskDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    if (widget.initialValue != null) {
      _validateInput(widget.initialValue!);
    }
  }

  void _validateInput(String value) {
    setState(() {
      if (value.trim().isEmpty) {
        _errorText = 'El título no puede estar vacío';
      } else if (value.trim().length < 3) {
        _errorText = 'El título debe tener al menos 3 caracteres';
      } else if (value.trim().length > 50) {
        _errorText = 'El título no puede exceder los 50 caracteres';
      } else {
        _errorText = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Tarea'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 50,
        decoration: InputDecoration(
          hintText: 'Ingrese el título de la tarea',
          errorText: _errorText,
          border: const OutlineInputBorder(),
        ),
        onChanged: _validateInput,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _errorText != null || _controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}