import 'package:flutter/material.dart';

import '../services/app_preferences.dart';

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
  final _targetWeeklyMin = TextEditingController();
  final _targetWeeklyMax = TextEditingController();

  final _preferences = AppPreferences();

  bool _obscureKey = true;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final credentials = await _preferences.loadCredentials();
    final settings = await _preferences.loadSettings();
    if (!mounted) return;
    setState(() {
      _apiKey.text = credentials.anthropicApiKey;
      _tursoUrl.text = credentials.tursoUrl;
      _tursoToken.text = credentials.tursoToken;
      _goalWeight.text = settings.goalWeight.toString();
      _goalFat.text = settings.goalFat.toString();
      _minWeight.text = settings.minWeight.toString();
      _targetWeeklyMin.text = settings.targetWeeklyGainMin.toString();
      _targetWeeklyMax.text = settings.targetWeeklyGainMax.toString();
    });
  }

  Future<void> _save() async {
    final targetMin = _number(_targetWeeklyMin.text);
    final targetMax = _number(_targetWeeklyMax.text);
    if (targetMin == null ||
        targetMax == null ||
        targetMin < 0 ||
        targetMax < targetMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe ritmos válidos: o máximo deve ser maior ou igual ao mínimo.',
          ),
          backgroundColor: Color(0xFFD45F50),
        ),
      );
      return;
    }

    await _preferences.saveCredentials(
      AppCredentials(
        anthropicApiKey: _apiKey.text.trim(),
        tursoUrl: _tursoUrl.text.trim(),
        tursoToken: _tursoToken.text.trim(),
      ),
    );
    await _preferences.saveSettings(
      AppSettings(
        goalWeight: _number(_goalWeight.text) ?? 96,
        goalFat: _number(_goalFat.text) ?? 20,
        minWeight: _number(_minWeight.text) ?? 80,
        targetWeeklyGainMin: targetMin,
        targetWeeklyGainMax: targetMax,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Configurações salvas!')));
      Navigator.pop(context, true);
    }
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _apiKey.dispose();
    _tursoUrl.dispose();
    _tursoToken.dispose();
    _goalWeight.dispose();
    _goalFat.dispose();
    _minWeight.dispose();
    _targetWeeklyMin.dispose();
    _targetWeeklyMax.dispose();
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
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C2A26),
          ),
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: _field(
                  controller: _goalWeight,
                  label: 'Meta de peso (kg)',
                  hint: '96',
                  numeric: true,
                ),
              ),
              SizedBox(
                width: 180,
                child: _field(
                  controller: _goalFat,
                  label: 'Meta gordura (%)',
                  hint: '20',
                  numeric: true,
                ),
              ),
              SizedBox(
                width: 180,
                child: _field(
                  controller: _minWeight,
                  label: 'Peso mínimo (kg)',
                  hint: '80',
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _section('Ritmo alvo'),
          const Text(
            'Intervalo desejado de ganho de peso por semana.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _targetWeeklyMin,
                  label: 'Mínimo (kg/sem)',
                  hint: '0,15',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _targetWeeklyMax,
                  label: 'Máximo (kg/sem)',
                  hint: '0,30',
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '“Muito acima” significa mais de 2× o ritmo máximo configurado.',
            style: TextStyle(fontSize: 12, color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: const Color(0xFF2C2A26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
