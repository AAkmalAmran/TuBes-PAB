import 'package:flutter/material.dart';
import '../../widgets/responsive_body.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  void _handleReset() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, 'Tautan pemulihan telah dikirim ke ${_emailController.text}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Kata Sandi')),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset, size: 64),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Terdaftar', border: OutlineInputBorder()),
                validator: (value) => !value!.contains('@') ? 'Email tidak valid' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _handleReset,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Kirim Tautan Reset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}