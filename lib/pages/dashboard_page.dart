import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/body_data.dart';
import '../services/claude_service.dart';
import '../services/turso_service.dart';
import 'settings_page.dart';

class BodyDashboardPage extends StatefulWidget {
  const BodyDashboardPage({super.key});

  @override
  State<BodyDashboardPage> createState() => _BodyDashboardPageState();
}

class _BodyDashboardPageState extends State<BodyDashboardPage> {
  BodyData? _data;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _processing = false;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<TursoService?> _turso() async {
    final p = await SharedPreferences.getInstance();
    final url = p.getString('turso_url');
    final token = p.getString('turso_token');
    final key = p.getString('anthropic_api_key');
    if (url == null || url.isEmpty || token == null || token.isEmpty || key == null || key.isEmpty) {
      return null;
    }
    return TursoService(databaseUrl: url, authToken: token);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final turso = await _turso();
      if (turso == null) {
        setState(() { _configured = false; _loading = false; _data = BodyData.sample(); });
        return;
      }
      _configured = true;
      await turso.initDatabase();
      final history = await turso.getHistory(limit: 30);
      final p = await SharedPreferences.getInstance();
      if (history.isNotEmpty) {
        _data = BodyData.fromDb(
          current: history.first,
          initial: history.last,
          goalWeight: p.getDouble('goal_weight') ?? 96.0,
          goalFat: p.getDouble('goal_fat') ?? 20.0,
          minWeight: p.getDouble('min_weight') ?? 80.0,
        );
        _history = history;
      } else {
        _data = BodyData.sample();
      }
    } catch (e) {
      _data = BodyData.sample();
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadScreenshot() async {
    if (!_configured) {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
      if (saved == true) _load();
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;

    setState(() => _processing = true);
    try {
      final p = await SharedPreferences.getInstance();
      final apiKey = p.getString('anthropic_api_key')!;
      final tursoUrl = p.getString('turso_url')!;
      final tursoToken = p.getString('turso_token')!;

      final extracted = await ClaudeService(apiKey).analyzeZeppScreenshot(File(picked.path));

      if (!mounted) return;

      // Show confirmation dialog before saving
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmDialog(data: extracted),
      );

      if (confirm != true) return;

      final turso = TursoService(databaseUrl: tursoUrl, authToken: tursoToken);
      await turso.initDatabase();
      await turso.saveMeasurement(extracted);
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medição salva com sucesso!'),
            backgroundColor: Color(0xFF4AADA0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: const Color(0xFFD45F50)),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _openSettings() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data ?? BodyData.sample();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8F2),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Composição Corporal',
          style: TextStyle(color: Color(0xFF2C2A26), fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: false,
        actions: [
          if (!_configured)
            TextButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB07D3A), size: 18),
              label: const Text('Configurar', style: TextStyle(color: Color(0xFFB07D3A), fontWeight: FontWeight.w700)),
            ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF7A746E)),
            onPressed: _openSettings,
            tooltip: 'Configurações',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _processing ? null : _uploadScreenshot,
        backgroundColor: _processing ? Colors.grey : const Color(0xFF2C2A26),
        icon: _processing
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.upload_file_rounded),
        label: Text(_processing ? 'Analisando...' : 'Upload Zepp Life'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4AADA0)))
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  final hPad = constraints.maxWidth >= 1200 ? 32.0 : 18.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 100),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HeaderSection(monthLabel: data.monthLabel),
                            const SizedBox(height: 18),
                            RecomposicaoBanner(data: data),
                            const SizedBox(height: 20),
                            if (isWide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 220, child: ScoreCard(data: data)),
                                  const SizedBox(width: 16),
                                  Expanded(child: MetricsGrid(data: data)),
                                ],
                              )
                            else
                              Column(children: [
                                ScoreCard(data: data),
                                const SizedBox(height: 14),
                                MetricsGrid(data: data),
                              ]),
                            const SizedBox(height: 18),
                            ResponsiveTwoCards(
                              left: GoalWeightCard(data: data),
                              right: GoalFatCard(data: data),
                            ),
                            const SizedBox(height: 18),
                            ResponsiveTwoCards(
                              left: ProjectionCard(data: data),
                              right: AnalysisCard(data: data),
                            ),
                            if (_history.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              HistoryCard(history: _history),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ─── Confirmation dialog ──────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ConfirmDialog({required this.data});

  @override
  Widget build(BuildContext context) {
    String _v(String key, {String suffix = ''}) {
      final v = data[key];
      if (v == null) return '—';
      return '$v$suffix';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Confirmar dados', style: TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Claude extraiu os seguintes valores:', style: TextStyle(color: Color(0xFF7A746E), fontSize: 13)),
            const SizedBox(height: 14),
            _row('Peso', _v('weight', suffix: ' kg')),
            _row('Gordura', _v('fat', suffix: ' %')),
            _row('Músculo', _v('muscle', suffix: ' kg')),
            _row('Água', _v('water', suffix: ' %')),
            _row('Visceral', _v('visceral')),
            _row('Proteína', _v('protein', suffix: ' %')),
            _row('Score', _v('score')),
            _row('IMC', _v('bmi')),
            _row('Massa óssea', _v('bone_mass', suffix: ' kg')),
            _row('Basal', _v('basal', suffix: ' kcal')),
            _row('Tipo de corpo', _v('body_type')),
            _row('Data medição', _v('measured_at')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4AADA0)),
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF7A746E)))),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// ─── History card ─────────────────────────────────────────────────────────────

class HistoryCard extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const HistoryCard({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Últimas medições', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...history.take(8).toList().asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            final weight = double.tryParse(row['weight']?.toString() ?? '');
            final next = i + 1 < history.length ? history[i + 1] : null;
            final prevWeight = next != null ? double.tryParse(next['weight']?.toString() ?? '') : null;
            final delta = (weight != null && prevWeight != null) ? weight - prevWeight : null;

            final dateStr = row['created_at']?.toString() ?? '';
            final date = DateTime.tryParse(dateStr);
            final label = date != null
                ? '${date.day.toString().padLeft(2, '0')} ${_month(date.month)}'
                : dateStr;

            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: Color(0xFFECE5DC)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF7A746E))),
                      ),
                      Expanded(
                        child: Text(
                          weight != null ? '${fmt(weight)} kg' : '—',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: i == history.length - 1
                            ? const Text('início',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB07D3A)))
                            : delta == null
                                ? const SizedBox()
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(
                                        delta < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                        size: 14,
                                        color: delta < 0 ? const Color(0xFF4AADA0) : const Color(0xFFD45F50),
                                      ),
                                      Text(
                                        fmt(delta.abs(), casas: 1),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: delta < 0 ? const Color(0xFF4AADA0) : const Color(0xFFD45F50),
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  static const _months = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
  static String _month(int m) => _months[m - 1];
}

// ─── All existing widgets (kept in this file) ─────────────────────────────────

class HeaderSection extends StatelessWidget {
  final String monthLabel;
  const HeaderSection({super.key, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Corpo em evolução', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Composição corporal · Zepp Life · Acompanhamento de metas',
                  style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7DED4)),
          ),
          child: Text(monthLabel,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Color(0xFF7A746E))),
        ),
      ],
    );
  }
}

class RecomposicaoBanner extends StatelessWidget {
  final BodyData data;
  const RecomposicaoBanner({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final kgToGoal = data.goalWeight - data.weight;
    final fatToGoal = data.fat - data.goalFat;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2D9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8D7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.bolt_rounded, color: Color(0xFF8E6928)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Recomposição corporal em andamento',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF4E3A18))),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            'Meta simultânea: ganhar +${fmt(kgToGoal)} kg e reduzir −${fmt(fatToGoal)} pp de gordura.',
            style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF5E4A23), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: const Color(0xFFEED9AE), borderRadius: BorderRadius.circular(999)),
            child: const Text('Avançado',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF654A12))),
          ),
        ],
      ),
    );
  }
}

class ScoreCard extends StatelessWidget {
  final BodyData data;
  const ScoreCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Score',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF7A746E))),
          const SizedBox(height: 12),
          Text(data.score.toStringAsFixed(0),
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, height: 0.95, color: Color(0xFF2C2A26))),
          const SizedBox(height: 10),
          Text('↓ ${fmt(data.totalWeightDelta.abs(), casas: 2)} kg',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF4AADA0))),
        ],
      ),
    );
  }
}

class MetricsGrid extends StatelessWidget {
  final BodyData data;
  const MetricsGrid({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      MetricData(title: 'Peso', value: '${fmt(data.weight)} kg', status: data.weightStatus,
          color: const Color(0xFFE9F8F5), accent: const Color(0xFF4AADA0)),
      MetricData(title: 'Gordura', value: '${fmt(data.fat)} %', status: data.fatStatus,
          color: const Color(0xFFFFECE7), accent: const Color(0xFFD45F50)),
      MetricData(title: 'Músculo', value: '${fmt(data.muscle)} kg', status: data.muscleStatus,
          color: const Color(0xFFEDF8EB), accent: const Color(0xFF5FA04E)),
      MetricData(title: 'Água', value: '${fmt(data.water)} %', status: data.waterStatus,
          color: const Color(0xFFFFF6E2), accent: const Color(0xFFB07D3A)),
      MetricData(title: 'Visceral', value: data.visceral.toStringAsFixed(0), status: data.visceralStatus,
          color: const Color(0xFFEAF2FF), accent: const Color(0xFF4C7FD9)),
      MetricData(title: 'Proteína', value: '${fmt(data.protein)} %', status: data.proteinStatus,
          color: const Color(0xFFF5EDE8), accent: const Color(0xFF8A5B3D)),
    ];
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240, mainAxisExtent: 132, crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemBuilder: (_, i) => MetricCard(metric: metrics[i]),
    );
  }
}

class MetricCard extends StatelessWidget {
  final MetricData metric;
  const MetricCard({super.key, required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: metric.color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF5E5A55))),
          const Spacer(),
          Text(metric.value,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: metric.accent, height: 1)),
          const SizedBox(height: 12),
          StatusPill(label: metric.status, accent: metric.accent),
        ],
      ),
    );
  }
}

class GoalWeightCard extends StatelessWidget {
  final BodyData data;
  const GoalWeightCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final remaining = data.goalWeight - data.weight;
    return DashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Meta de peso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Ganhar massa total', style: TextStyle(fontSize: 14, color: Color(0xFF7A746E))),
        const SizedBox(height: 14),
        Text('+${fmt(remaining)} kg',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF4AADA0))),
        const SizedBox(height: 12),
        Text('Mín: ${fmt(data.minWeight, casas: 0)} kg   Meta: ${fmt(data.goalWeight, casas: 0)} kg',
            style: const TextStyle(fontSize: 13, color: Color(0xFF7A746E), fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        ProgressInfo(
          leftLabel: 'Atual', leftValue: '${fmt(data.weight)} kg',
          rightLabel: 'Meta', rightValue: '${fmt(data.goalWeight, casas: 0)} kg',
          progress: data.weightProgress, progressColor: const Color(0xFF4AADA0),
        ),
        const SizedBox(height: 12),
        Text('Faltam +${fmt(remaining)} kg · ${(data.weightProgress * 100).toStringAsFixed(1)}% concluído',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4C4945))),
      ]),
    );
  }
}

class GoalFatCard extends StatelessWidget {
  final BodyData data;
  const GoalFatCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final remaining = data.fat - data.goalFat;
    return DashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Meta de gordura', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Reduzir % corporal', style: TextStyle(fontSize: 14, color: Color(0xFF7A746E))),
        const SizedBox(height: 14),
        Text('−${fmt(remaining)} pp',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFFD45F50))),
        const SizedBox(height: 12),
        Text('Meta: ${fmt(data.goalFat, casas: 0)}%   Início: ${fmt(data.initialFat)}%',
            style: const TextStyle(fontSize: 13, color: Color(0xFF7A746E), fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        ProgressInfo(
          leftLabel: 'Atual', leftValue: '${fmt(data.fat)} %',
          rightLabel: 'Meta', rightValue: '${fmt(data.goalFat, casas: 0)} %',
          progress: data.fatProgress, progressColor: const Color(0xFFD45F50),
        ),
        const SizedBox(height: 12),
        Text('Faltam −${fmt(remaining)} pp · ${(data.fatProgress * 100).toStringAsFixed(1)}% concluído',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4C4945))),
      ]),
    );
  }
}

class ProjectionCard extends StatelessWidget {
  final BodyData data;
  const ProjectionCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final weeksText = data.weeksToGoal == null ? 'Sem projeção' : '≈ ${data.weeksToGoal!.round()} semanas';
    return DashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ritmo atual & projeção', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        ProjectionLine(
            title: 'Variação peso (${data.days} dias)',
            value: '${fmt(data.totalWeightDelta)} kg · ${fmt(data.weightRatePerWeek, casas: 2)} kg/sem'),
        const SizedBox(height: 14),
        ProjectionLine(
            title: 'Variação gordura (${data.days} dias)',
            value: '${fmt(data.fatDelta)} pp · ${fmt(data.fatRatePerWeek, casas: 2)} pp/sem'),
        const SizedBox(height: 14),
        ProjectionLine(title: 'Projeção meta 20% gordura', value: '$weeksText no ritmo atual'),
        const SizedBox(height: 14),
        ProjectionLine(
            title: 'Ritmo necessário p/ 1 ano',
            value: '−${fmt(data.requiredFatRateFor1Year, casas: 2)} pp/sem de gordura'),
      ]),
    );
  }
}

class AnalysisCard extends StatelessWidget {
  final BodyData data;
  const AnalysisCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Análise do período', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Row(children: [
          Icon(Icons.smart_toy_outlined, size: 18, color: Color(0xFF7A746E)),
          SizedBox(width: 6),
          Text('Claude', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF7A746E))),
        ]),
        const SizedBox(height: 14),
        Text(
          'Em ${data.days} dias, você perdeu ${fmt(data.totalWeightDelta.abs())} kg e '
          'reduziu gordura em ${fmt(data.fatDelta.abs())} pp. '
          'Músculo subiu +${fmt(data.muscleDelta)} kg — recomposição real acontecendo.',
          style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF4C4945)),
        ),
        const SizedBox(height: 14),
        const Text(
          'Foco: treino intenso, proteína alta e constância calórica.',
          style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w700, color: Color(0xFF2C2A26)),
        ),
      ]),
    );
  }
}

class ProjectionLine extends StatelessWidget {
  final String title;
  final String value;
  const ProjectionLine({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF7A746E), fontWeight: FontWeight.w700)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(fontSize: 15, color: Color(0xFF2C2A26), fontWeight: FontWeight.w700)),
    ]);
  }
}

class ProgressInfo extends StatelessWidget {
  final String leftLabel, leftValue, rightLabel, rightValue;
  final double progress;
  final Color progressColor;

  const ProgressInfo({
    super.key,
    required this.leftLabel, required this.leftValue,
    required this.rightLabel, required this.rightValue,
    required this.progress, required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _Block(label: leftLabel, value: leftValue, alignEnd: false)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF9A9590)),
        ),
        Expanded(child: _Block(label: rightLabel, value: rightValue, alignEnd: true)),
      ]),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: progress.clamp(0, 1),
          minHeight: 12,
          backgroundColor: const Color(0xFFECE5DC),
          valueColor: AlwaysStoppedAnimation(progressColor),
        ),
      ),
    ]);
  }
}

class _Block extends StatelessWidget {
  final String label, value;
  final bool alignEnd;
  const _Block({required this.label, required this.value, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF7A746E), fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, color: Color(0xFF2C2A26), fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class ResponsiveTwoCards extends StatelessWidget {
  final Widget left, right;
  const ResponsiveTwoCards({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      if (constraints.maxWidth >= 900) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: left), const SizedBox(width: 16), Expanded(child: right),
        ]);
      }
      return Column(children: [left, const SizedBox(height: 16), right]);
    });
  }
}

class DashboardCard extends StatelessWidget {
  final Widget child;
  const DashboardCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7DED4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: child,
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color accent;
  const StatusPill({super.key, required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accent)),
    );
  }
}

class MetricData {
  final String title, value, status;
  final Color color, accent;
  const MetricData({required this.title, required this.value, required this.status,
      required this.color, required this.accent});
}
