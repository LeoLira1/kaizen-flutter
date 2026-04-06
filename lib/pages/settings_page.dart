import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiKey = TextEditingController();
  final _tursoUrl = TextEditingController();
  final _tursoToken = TextEditingController();
  final _goalWeight = TextEditingController();
  final _goalFat = TextEditingController();
  final _minWeight = TextEditingController();

  bool _obscureKey = true;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _apiKey.text = p.getString('anthropic_api_key') ?? '';
    _tursoUrl.text = p.getString('turso_url') ?? '';
    _tursoToken.text = p.getString('turso_token') ?? '';
    _goalWeight.text = (p.getDouble('goal_weight') ?? 96.0).toString();
    _goalFat.text = (p.getDouble('goal_fat') ?? 20.0).toString();
    _minWeight.text = (p.getDouble('min_weight') ?? 80.0).toString();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('anthropic_api_key', _apiKey.text.trim());
    await p.setString('turso_url', _tursoUrl.text.trim());
    await p.setString('turso_token', _tursoToken.text.trim());
    await p.setDouble('goal_weight', double.tryParse(_goalWeight.text) ?? 96.0);
    await p.setDouble('goal_fat', double.tryParse(_goalFat.text) ?? 20.0);
    await p.setDouble('min_weight', double.tryParse(_minWeight.text) ?? 80.0);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas!')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _apiKey.dispose();
    _tursoUrl.dispose();
    _tursoToken.dispose();
    _goalWeight.dispose();
    _goalFat.dispose();
    _minWeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8F2),
        elevation: 0,
        title: const Text(
          'Configurações',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2C2A26)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('APIs'),
          _field(
            controller: _apiKey,
            label: 'Anthropic API Key',
            hint: 'sk-ant-...',
            obscure: _obscureKey,
            toggleObscure: () => setState(() => _obscureKey = !_obscureKey),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _tursoUrl,
            label: 'Turso Database URL',
            hint: 'https://db-name-org.turso.io',
          ),
          const SizedBox(height: 14),
          _field(
            controller: _tursoToken,
            label: 'Turso Auth Token',
            hint: 'eyJ...',
            obscure: _obscureToken,
            toggleObscure: () => setState(() => _obscureToken = !_obscureToken),
          ),
          const SizedBox(height: 28),
          _section('Metas'),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _goalWeight,
                  label: 'Meta de peso (kg)',
                  hint: '96',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _goalFat,
                  label: 'Meta gordura (%)',
                  hint: '20',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _minWeight,
                  label: 'Peso mínimo (kg)',
                  hint: '80',
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF2C2A26),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Salvar', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF7A746E),
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    VoidCallback? toggleObscure,
    bool numeric = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7DED4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7DED4)),
        ),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: toggleObscure,
              )
            : null,
      ),
    );
  }
}
