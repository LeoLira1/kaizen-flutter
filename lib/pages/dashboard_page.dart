import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/kaizen_analytics.dart';
import '../models/body_data.dart';
import '../models/body_measurement.dart';
import '../services/app_preferences.dart';
import '../services/claude_service.dart';
import '../services/turso_service.dart';
import 'evolution_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

class BodyDashboardPage extends StatefulWidget {
  const BodyDashboardPage({super.key});

  @override
  State<BodyDashboardPage> createState() => _BodyDashboardPageState();
}

class _BodyDashboardPageState extends State<BodyDashboardPage> {
  BodyData? _data;
  List<BodyMeasurement> _measurements = [];
  AppSettings _settings = const AppSettings();
  final AppPreferences _preferences = AppPreferences();
  bool _loading = true;
  bool _processing = false;
  bool _configured = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<TursoService?> _turso() async {
    final credentials = await _preferences.loadCredentials();
    if (!credentials.isComplete) return null;
    return TursoService(
      databaseUrl: credentials.tursoUrl,
      authToken: credentials.tursoToken,
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _settings = await _preferences.loadSettings();
      final turso = await _turso();
      if (turso == null) {
        setState(() {
          _configured = false;
          _loading = false;
          _data = BodyData.sample();
          _measurements = [];
        });
        return;
      }
      _configured = true;
      await turso.initDatabase();
      final history = await turso.getHistory();
      if (history.isNotEmpty) {
        _data = BodyData.fromDb(
          current: history.first,
          initial: history.last,
          goalWeight: _settings.goalWeight,
          goalFat: _settings.goalFat,
          minWeight: _settings.minWeight,
        );
        _measurements = history.map(BodyMeasurement.fromDb).toList();
      } else {
        _data = BodyData.sample();
        _measurements = [];
      }
    } catch (_) {
      _data = BodyData.sample();
      _measurements = [];
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

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _processing = true);
    try {
      final credentials = await _preferences.loadCredentials();

      final extracted = await ClaudeService(credentials.anthropicApiKey)
          .analyzeZeppScreenshot(File(picked.path));

      if (!mounted) return;

      // Show confirmation dialog before saving
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmDialog(data: extracted),
      );

      if (confirm != true) return;

      final turso = TursoService(
        databaseUrl: credentials.tursoUrl,
        authToken: credentials.tursoToken,
      );
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
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: const Color(0xFFD45F50),
          ),
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
    final pages = [
      _buildDashboard(data),
      EvolutionPage(history: _measurements),
      HistoryPage(history: _measurements),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8F2),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          const [
            'Composição Corporal',
            'Evolução',
            'Histórico',
          ][_selectedIndex],
          style: const TextStyle(
            color: Color(0xFF2C2A26),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          if (!_configured)
            TextButton.icon(
              onPressed: _openSettings,
              icon: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFB07D3A),
                size: 18,
              ),
              label: const Text(
                'Configurar',
                style: TextStyle(
                  color: Color(0xFFB07D3A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF7A746E)),
            onPressed: _openSettings,
            tooltip: 'Configurações',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _processing ? null : _uploadScreenshot,
              backgroundColor: _processing
                  ? Colors.grey
                  : const Color(0xFF2C2A26),
              icon: _processing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(_processing ? 'Analisando...' : 'Upload Zepp Life'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Resumo',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_rounded),
            label: 'Evolução',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'Histórico',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4AADA0)),
            )
          : IndexedStack(index: _selectedIndex, children: pages),
    );
  }

  Widget _buildDashboard(BodyData data) {
    final weeklyTrend = KaizenAnalytics.weeklyWeightTrend(_measurements);
    final paceStatus = KaizenAnalytics.classifyPace(
      weeklyTrend?.kilogramsPerWeek,
      minimum: _settings.targetWeeklyGainMin,
      maximum: _settings.targetWeeklyGainMax,
    );
    final report = KaizenAnalytics.buildWeeklyReport(
      _measurements,
      targetMinimum: _settings.targetWeeklyGainMin,
      targetMaximum: _settings.targetWeeklyGainMax,
      goalWeight: _settings.goalWeight,
      goalFat: _settings.goalFat,
    );
    final kaizenScore = KaizenAnalytics.calculateKaizenScore(
      _measurements,
      targetMinimum: _settings.targetWeeklyGainMin,
      targetMaximum: _settings.targetWeeklyGainMax,
      goalWeight: _settings.goalWeight,
      goalFat: _settings.goalFat,
    );
    final milestones = KaizenAnalytics.calculateMilestones(
      _measurements,
      goalWeight: _settings.goalWeight,
      goalFat: _settings.goalFat,
    );
    final relevantMilestones = _mostRelevantMilestones(milestones);

    return SafeArea(
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
                    ResponsiveTwoCards(
                      left: WeeklyPaceCard(
                        trend: weeklyTrend,
                        status: paceStatus,
                        targetMinimum: _settings.targetWeeklyGainMin,
                        targetMaximum: _settings.targetWeeklyGainMax,
                      ),
                      right: KaizenScoreCard(score: kaizenScore),
                    ),
                    const SizedBox(height: 18),
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
                      Column(
                        children: [
                          ScoreCard(data: data),
                          const SizedBox(height: 14),
                          MetricsGrid(data: data),
                        ],
                      ),
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
                    const SizedBox(height: 18),
                    ResponsiveTwoCards(
                      left: RecompositionCard(data: data),
                      right: KaizenCoachCard(messages: report),
                    ),
                    const SizedBox(height: 18),
                    MilestonesCard(milestones: relevantMilestones),
                    if (_measurements.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      HistoryCard(history: _measurements),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<ProgressMilestone> _mostRelevantMilestones(
    List<ProgressMilestone> milestones,
  ) {
    final selected = <ProgressMilestone>[];
    final kinds = <MilestoneKind>{};
    for (final milestone in milestones) {
      if (kinds.add(milestone.kind)) selected.add(milestone);
      if (selected.length == 3) break;
    }
    return selected;
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
      title: const Text(
        'Confirmar dados',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Claude extraiu os seguintes valores:',
              style: TextStyle(color: Color(0xFF7A746E), fontSize: 13),
            ),
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
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4AADA0),
          ),
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

// ─── History card ─────────────────────────────────────────────────────────────

class HistoryCard extends StatelessWidget {
  final List<BodyMeasurement> history;
  const HistoryCard({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Últimas medições',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ...history.take(8).toList().asMap().entries.map((e) {
            final i = e.key;
            final measurement = e.value;
            final weight = measurement.weight;
            final next = i + 1 < history.length ? history[i + 1] : null;
            final prevWeight = next?.weight;
            final delta = (weight != null && prevWeight != null)
                ? weight - prevWeight
                : null;

            final date = measurement.date;
            final label =
                '${date.day.toString().padLeft(2, '0')} ${_month(date.month)}';

            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: Color(0xFFECE5DC)),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showMeasurementDetails(context, measurement),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7A746E),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            weight != null ? '${fmt(weight)} kg' : '—',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: i == history.length - 1
                              ? const Text(
                                  'início',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB07D3A),
                                  ),
                                )
                              : delta == null
                              ? const SizedBox()
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      delta < 0
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      size: 14,
                                      color: delta < 0
                                          ? const Color(0xFF4AADA0)
                                          : const Color(0xFFD45F50),
                                    ),
                                    Text(
                                      fmt(delta.abs(), casas: 1),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: delta < 0
                                            ? const Color(0xFF4AADA0)
                                            : const Color(0xFFD45F50),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFF9A9590),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  static const _months = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];
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
              Text(
                'Composição corporal · Zepp Life · Acompanhamento de metas',
                style: theme.textTheme.bodyLarge,
              ),
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
          child: Text(
            monthLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Color(0xFF7A746E),
            ),
          ),
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
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFF8E6928)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recomposição corporal em andamento',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4E3A18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Meta simultânea: ganhar +${fmt(kgToGoal)} kg e reduzir −${fmt(fatToGoal)} pp de gordura.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF5E4A23),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEED9AE),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Avançado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF654A12),
              ),
            ),
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
          const Text(
            'Score',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A746E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.score.toStringAsFixed(0),
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 0.95,
              color: Color(0xFF2C2A26),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '↓ ${fmt(data.totalWeightDelta.abs(), casas: 2)} kg',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4AADA0),
            ),
          ),
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
      MetricData(
        title: 'Peso',
        value: '${fmt(data.weight)} kg',
        status: data.weightStatus,
        color: const Color(0xFFE9F8F5),
        accent: const Color(0xFF4AADA0),
      ),
      MetricData(
        title: 'Gordura',
        value: '${fmt(data.fat)} %',
        status: data.fatStatus,
        color: const Color(0xFFFFECE7),
        accent: const Color(0xFFD45F50),
      ),
      MetricData(
        title: 'Músculo',
        value: '${fmt(data.muscle)} kg',
        status: data.muscleStatus,
        color: const Color(0xFFEDF8EB),
        accent: const Color(0xFF5FA04E),
      ),
      MetricData(
        title: 'Água',
        value: '${fmt(data.water)} %',
        status: data.waterStatus,
        color: const Color(0xFFFFF6E2),
        accent: const Color(0xFFB07D3A),
      ),
      MetricData(
        title: 'Visceral',
        value: data.visceral.toStringAsFixed(0),
        status: data.visceralStatus,
        color: const Color(0xFFEAF2FF),
        accent: const Color(0xFF4C7FD9),
      ),
      MetricData(
        title: 'Proteína',
        value: '${fmt(data.protein)} %',
        status: data.proteinStatus,
        color: const Color(0xFFF5EDE8),
        accent: const Color(0xFF8A5B3D),
      ),
    ];
    return GridView.builder(
      itemCount: metrics.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisExtent: 132,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5E5A55),
            ),
          ),
          const Spacer(),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: metric.accent,
              height: 1,
            ),
          ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meta de peso',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ganhar massa total',
            style: TextStyle(fontSize: 14, color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 14),
          Text(
            '+${fmt(remaining)} kg',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF4AADA0),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Mín: ${fmt(data.minWeight, casas: 0)} kg   Meta: ${fmt(data.goalWeight, casas: 0)} kg',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A746E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ProgressInfo(
            leftLabel: 'Atual',
            leftValue: '${fmt(data.weight)} kg',
            rightLabel: 'Meta',
            rightValue: '${fmt(data.goalWeight, casas: 0)} kg',
            progress: data.weightProgress,
            progressColor: const Color(0xFF4AADA0),
          ),
          const SizedBox(height: 12),
          Text(
            'Faltam +${fmt(remaining)} kg · ${(data.weightProgress * 100).toStringAsFixed(1)}% concluído',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4C4945),
            ),
          ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meta de gordura',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Reduzir % corporal',
            style: TextStyle(fontSize: 14, color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 14),
          Text(
            '−${fmt(remaining)} pp',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFFD45F50),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Meta: ${fmt(data.goalFat, casas: 0)}%   Início: ${fmt(data.initialFat)}%',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7A746E),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ProgressInfo(
            leftLabel: 'Atual',
            leftValue: '${fmt(data.fat)} %',
            rightLabel: 'Meta',
            rightValue: '${fmt(data.goalFat, casas: 0)} %',
            progress: data.fatProgress,
            progressColor: const Color(0xFFD45F50),
          ),
          const SizedBox(height: 12),
          Text(
            'Faltam −${fmt(remaining)} pp · ${(data.fatProgress * 100).toStringAsFixed(1)}% concluído',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4C4945),
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectionCard extends StatelessWidget {
  final BodyData data;
  const ProjectionCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final weeksText = data.weeksToGoal == null
        ? 'Sem projeção'
        : '≈ ${data.weeksToGoal!.round()} semanas';
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ritmo atual & projeção',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          ProjectionLine(
            title: 'Variação peso (${data.days} dias)',
            value:
                '${fmt(data.totalWeightDelta)} kg · ${fmt(data.weightRatePerWeek, casas: 2)} kg/sem',
          ),
          const SizedBox(height: 14),
          ProjectionLine(
            title: 'Variação gordura (${data.days} dias)',
            value:
                '${fmt(data.fatDelta)} pp · ${fmt(data.fatRatePerWeek, casas: 2)} pp/sem',
          ),
          const SizedBox(height: 14),
          ProjectionLine(
            title: 'Projeção meta 20% gordura',
            value: '$weeksText no ritmo atual',
          ),
          const SizedBox(height: 14),
          ProjectionLine(
            title: 'Ritmo necessário p/ 1 ano',
            value:
                '−${fmt(data.requiredFatRateFor1Year, casas: 2)} pp/sem de gordura',
          ),
        ],
      ),
    );
  }
}

class WeeklyPaceCard extends StatelessWidget {
  final WeeklyTrend? trend;
  final PaceStatus status;
  final double targetMinimum;
  final double targetMaximum;

  const WeeklyPaceCard({
    super.key,
    required this.trend,
    required this.status,
    required this.targetMinimum,
    required this.targetMaximum,
  });

  @override
  Widget build(BuildContext context) {
    final rate = trend?.kilogramsPerWeek;
    final color = switch (status) {
      PaceStatus.onTarget => const Color(0xFF4AADA0),
      PaceStatus.below => const Color(0xFFB07D3A),
      PaceStatus.above || PaceStatus.wayAbove => const Color(0xFFD45F50),
      PaceStatus.insufficient => const Color(0xFF7A746E),
    };
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ritmo desta semana',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            rate == null
                ? '—'
                : '${rate >= 0 ? '+' : ''}${fmt(rate, casas: 2)} kg/sem',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          StatusPill(label: status.label, accent: color),
          const SizedBox(height: 14),
          if (trend == null)
            const Text(
              'São necessárias medições de peso nos dois períodos consecutivos de 7 dias.',
              style: TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
            )
          else
            Text(
              'Média atual: ${fmt(trend!.currentAverage, casas: 2)} kg · '
              'anterior: ${fmt(trend!.previousAverage, casas: 2)} kg',
              style: const TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
            ),
          const SizedBox(height: 8),
          Text(
            'Alvo: ${fmt(targetMinimum, casas: 2)} a ${fmt(targetMaximum, casas: 2)} kg/sem',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class RecompositionCard extends StatelessWidget {
  final BodyData data;

  const RecompositionCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recomposição corporal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Valores derivados; os dados originais não são alterados.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 18),
          _compositionLine(
            'Massa de gordura atual',
            data.fatMass,
            const Color(0xFFD45F50),
          ),
          _compositionLine(
            'Massa livre de gordura atual',
            data.fatFreeMass,
            const Color(0xFF5FA04E),
          ),
          const Divider(height: 24, color: Color(0xFFECE5DC)),
          _compositionLine(
            'Mudança de massa de gordura',
            data.fatMassDelta,
            const Color(0xFFD45F50),
            signed: true,
          ),
          _compositionLine(
            'Mudança de massa livre de gordura',
            data.fatFreeMassDelta,
            const Color(0xFF5FA04E),
            signed: true,
          ),
        ],
      ),
    );
  }

  Widget _compositionLine(
    String label,
    double value,
    Color color, {
    bool signed = false,
  }) {
    final prefix = signed && value > 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
            ),
          ),
          Text(
            '$prefix${fmt(value, casas: 2)} kg',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class KaizenScoreCard extends StatelessWidget {
  final KaizenScoreResult? score;

  const KaizenScoreCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final result = score;
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kaizen Score',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Como é calculado',
                onPressed: () => _showFormula(context),
                icon: const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: Color(0xFF7A746E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Média simples dos componentes disponíveis.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result == null ? '—' : result.value.round().toString(),
                style: const TextStyle(
                  fontSize: 48,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2C2A26),
                ),
              ),
              if (result?.changeFromPreviousPeriod != null) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '${result!.changeFromPreviousPeriod! >= 0 ? '+' : ''}${fmt(result.changeFromPreviousPeriod!, casas: 1)} vs. período anterior',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: result.changeFromPreviousPeriod! >= 0
                          ? const Color(0xFF4AADA0)
                          : const Color(0xFFD45F50),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (result == null)
            const Text('Sem dados suficientes para calcular o score.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _scorePart('Consistência', result.breakdown.consistency),
                _scorePart('Ritmo', result.breakdown.pace),
                _scorePart('Gordura', result.breakdown.fatProgress),
                _scorePart('Músculo', result.breakdown.muscleProgress),
                _scorePart('Metas', result.breakdown.goalsProgress),
              ],
            ),
        ],
      ),
    );
  }

  void _showFormula(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fórmula do Kaizen Score'),
        content: const SingleChildScrollView(
          child: Text(
            'O score é a média simples dos componentes disponíveis (0–100):\n\n'
            '• Consistência: dias com medição nos últimos 14 dias ÷ 14.\n'
            '• Ritmo: 100 dentro do alvo; fora dele, cai proporcionalmente à distância do intervalo.\n'
            '• Gordura: 100 ao melhorar, 60 ao ficar estável (±0,1 pp) e 0 ao piorar.\n'
            '• Músculo: 100 ao melhorar, 60 ao ficar estável (±0,1 kg) e 0 ao piorar.\n'
            '• Metas: média do progresso de peso e gordura desde a primeira medição.\n\n'
            'Componentes sem dados suficientes não entram na média.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Widget _scorePart(String label, double? value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF3EEE8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$label ${value == null ? '—' : value.round()}',
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class KaizenCoachCard extends StatelessWidget {
  final List<String> messages;

  const KaizenCoachCard({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF4AADA0)),
              SizedBox(width: 8),
              Text(
                'Kaizen Coach',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Relatório semanal gerado por regras locais, sem uso de IA.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 14),
          ...messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 7,
                      color: Color(0xFF4AADA0),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MilestonesCard extends StatelessWidget {
  final List<ProgressMilestone> milestones;

  const MilestonesCard({super.key, required this.milestones});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marcos de progresso',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Calculados dinamicamente a partir do histórico.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 14),
          if (milestones.isEmpty)
            const Text('Nenhum marco disponível ainda.')
          else
            ...milestones.map(
              (milestone) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF2D9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_outlined,
                        size: 19,
                        color: Color(0xFFB07D3A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            milestone.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            milestone.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7A746E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AnalysisCard extends StatelessWidget {
  final BodyData data;
  const AnalysisCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Análise do período',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'Em ${data.days} dias: ${_change('peso', data.totalWeightDelta, 'kg')}; '
            '${_change('gordura', data.fatDelta, 'pp')}; '
            '${_change('músculo', data.muscleDelta, 'kg')}.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF4C4945),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Use esta visão de longo prazo junto das médias semanais para acompanhar a tendência.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C2A26),
            ),
          ),
        ],
      ),
    );
  }

  String _change(String metric, double value, String unit) {
    if (value.abs() < 0.005) return '$metric estável';
    final direction = value > 0 ? 'subiu' : 'caiu';
    return '$metric $direction ${fmt(value.abs(), casas: 2)} $unit';
  }
}

class ProjectionLine extends StatelessWidget {
  final String title;
  final String value;
  const ProjectionLine({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF7A746E),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF2C2A26),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class ProgressInfo extends StatelessWidget {
  final String leftLabel, leftValue, rightLabel, rightValue;
  final double progress;
  final Color progressColor;

  const ProgressInfo({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    required this.progress,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Block(
                label: leftLabel,
                value: leftValue,
                alignEnd: false,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF9A9590),
              ),
            ),
            Expanded(
              child: _Block(
                label: rightLabel,
                value: rightValue,
                alignEnd: true,
              ),
            ),
          ],
        ),
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
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final String label, value;
  final bool alignEnd;
  const _Block({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF7A746E),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            color: Color(0xFF2C2A26),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class ResponsiveTwoCards extends StatelessWidget {
  final Widget left, right;
  const ResponsiveTwoCards({
    super.key,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        }
        return Column(children: [left, const SizedBox(height: 16), right]);
      },
    );
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );
  }
}

class MetricData {
  final String title, value, status;
  final Color color, accent;
  const MetricData({
    required this.title,
    required this.value,
    required this.status,
    required this.color,
    required this.accent,
  });
}
