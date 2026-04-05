import 'package:flutter/material.dart';

void main() {
  runApp(const CorpoEmEvolucaoApp());
}

class CorpoEmEvolucaoApp extends StatelessWidget {
  const CorpoEmEvolucaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corpo em evolução',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFDF8F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4AADA0),
          brightness: Brightness.light,
          surface: const Color(0xFFFDF8F2),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2C2A26),
            height: 1.1,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C2A26),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C2A26),
          ),
          bodyLarge: TextStyle(
            fontSize: 15,
            color: Color(0xFF4C4945),
            height: 1.45,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF5E5A55),
            height: 1.4,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            color: Color(0xFF7A746E),
          ),
        ),
      ),
      home: const BodyDashboardPage(),
    );
  }
}

class BodyDashboardPage extends StatelessWidget {
  const BodyDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final data = BodyData.sample();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8F2),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Composição Corporal',
          style: TextStyle(
            color: Color(0xFF2C2A26),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 980;
            final horizontalPadding = constraints.maxWidth >= 1200 ? 32.0 : 18.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 24),
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
                            SizedBox(
                              width: 220,
                              child: ScoreCard(data: data),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: MetricsGrid(data: data),
                            ),
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

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Botão pronto. Depois podemos ligar na API do Claude.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Analisar agora com Claude'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: const Color(0xFF2C2A26),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
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

class HeaderSection extends StatelessWidget {
  final String monthLabel;

  const HeaderSection({
    super.key,
    required this.monthLabel,
  });

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

  const RecomposicaoBanner({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final kgToGoal = (data.goalWeight - data.weight);
    final fatToGoal = (data.fat - data.goalFat);

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
            'Meta simultânea: ganhar +${fmt(kgToGoal)} kg e reduzir −${fmt(fatToGoal)} pp de gordura. Exige ganho muscular com déficit calórico preciso.',
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

  const ScoreCard({
    super.key,
    required this.data,
  });

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

  const MetricsGrid({
    super.key,
    required this.data,
  });

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
        value: '${data.visceral.toStringAsFixed(0)}',
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
      itemBuilder: (context, index) => MetricCard(metric: metrics[index]),
    );
  }
}

class MetricCard extends StatelessWidget {
  final MetricData metric;

  const MetricCard({
    super.key,
    required this.metric,
  });

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
          StatusPill(
            label: metric.status,
            accent: metric.accent,
          ),
        ],
      ),
    );
  }
}

class GoalWeightCard extends StatelessWidget {
  final BodyData data;

  const GoalWeightCard({
    super.key,
    required this.data,
  });

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

  const GoalFatCard({
    super.key,
    required this.data,
  });

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

  const ProjectionCard({
    super.key,
    required this.data,
  });

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
            value: '${fmt(data.totalWeightDelta)} kg · ${fmt(data.weightRatePerWeek, casas: 2)} kg/semana',
          ),
          const SizedBox(height: 14),
          ProjectionLine(
            title: 'Variação gordura (${data.days} dias)',
            value: '${fmt(data.fatDelta)} pp · ${fmt(data.fatRatePerWeek, casas: 2)} pp/semana',
          ),
          const SizedBox(height: 14),
          ProjectionLine(
            title: 'Projeção meta 20% gordura',
            value: '$weeksText no ritmo atual',
          ),
          const SizedBox(height: 14),
          ProjectionLine(
            title: 'Ritmo necessário p/ 1 ano',
            value: '−${fmt(data.requiredFatRateFor1Year, casas: 2)} pp/semana de gordura',
          ),
        ],
      ),
    );
  }
}

class AnalysisCard extends StatelessWidget {
  final BodyData data;

  const AnalysisCard({
    super.key,
    required this.data,
  });

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
          const Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 18, color: Color(0xFF7A746E)),
              SizedBox(width: 6),
              Text(
                'Claude',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7A746E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Em ${data.days} dias, você perdeu ${fmt(data.totalWeightDelta.abs())} kg e reduziu gordura em ${fmt(data.fatDelta.abs())} pp. '
            'Músculo subiu +${fmt(data.muscleDelta)} kg — recomposição real acontecendo.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF4C4945),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Ritmo de gordura está lento: no ritmo atual, a meta ainda está distante. '
            'Para encurtar esse prazo, você precisa acelerar a queda de gordura sem perder massa magra.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF4C4945),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Foco: treino intenso, proteína alta e constância calórica.',
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
}

class ProjectionLine extends StatelessWidget {
  final String title;
  final String value;

  const ProjectionLine({
    super.key,
    required this.title,
    required this.value,
  });

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
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
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
              child: _ProgressLabelBlock(
                label: leftLabel,
                value: leftValue,
                alignEnd: false,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF9A9590)),
            ),
            Expanded(
              child: _ProgressLabelBlock(
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

class _ProgressLabelBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _ProgressLabelBlock({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
  final Widget left;
  final Widget right;

  const ResponsiveTwoCards({
    super.key,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 900;

        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        }

        return Column(
          children: [
            left,
            const SizedBox(height: 16),
            right,
          ],
        );
      },
    );
  }
}

class DashboardCard extends StatelessWidget {
  final Widget child;

  const DashboardCard({
    super.key,
    required this.child,
  });

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

  const StatusPill({
    super.key,
    required this.label,
    required this.accent,
  });

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
  final String title;
  final String value;
  final String status;
  final Color color;
  final Color accent;

  const MetricData({
    required this.title,
    required this.value,
    required this.status,
    required this.color,
    required this.accent,
  });
}

class BodyData {
  final double weight;
  final double fat;
  final double muscle;
  final double water;
  final double visceral;
  final double protein;
  final double score;

  final double totalWeightDelta;
  final int days;
  final double initialFat;
  final double initialWeight;
  final double initialMuscle;

  final double goalWeight;
  final double goalFat;
  final double minWeight;

  final String waterStatus;
  final String fatStatus;
  final String muscleStatus;
  final String visceralStatus;
  final String proteinStatus;
  final String weightStatus;

  final double boneMass;
  final double bmi;
  final double basal;
  final String bodyType;
  final String monthLabel;

  const BodyData({
    required this.weight,
    required this.fat,
    required this.muscle,
    required this.water,
    required this.visceral,
    required this.protein,
    required this.score,
    required this.totalWeightDelta,
    required this.days,
    required this.initialFat,
    required this.initialWeight,
    required this.initialMuscle,
    required this.goalWeight,
    required this.goalFat,
    required this.minWeight,
    required this.waterStatus,
    required this.fatStatus,
    required this.muscleStatus,
    required this.visceralStatus,
    required this.proteinStatus,
    required this.weightStatus,
    required this.boneMass,
    required this.bmi,
    required this.basal,
    required this.bodyType,
    required this.monthLabel,
  });

  double get weightProgress {
    if (goalWeight <= minWeight) return 0;
    return ((weight - minWeight) / (goalWeight - minWeight)).clamp(0, 1);
  }

  double get fatProgress {
    final total = initialFat - goalFat;
    final done = initialFat - fat;
    if (total <= 0) return 0;
    return (done / total).clamp(0, 1);
  }

  double get fatDelta => fat - initialFat;
  double get muscleDelta => muscle - initialMuscle;

  double get weightRatePerWeek => totalWeightDelta / (days / 7);
  double get fatRatePerWeek => fatDelta / (days / 7);

  double? get weeksToGoal {
    final remaining = fat - goalFat;
    if (fatRatePerWeek >= 0) return null;
    return (remaining / fatRatePerWeek).abs();
  }

  double get requiredFatRateFor1Year {
    final remaining = fat - goalFat;
    if (remaining <= 0) return 0;
    return remaining / 52;
  }

  factory BodyData.sample() {
    return const BodyData(
      weight: 91.6,
      fat: 29.2,
      muscle: 61.5,
      water: 50.5,
      visceral: 13,
      protein: 16.6,
      score: 49,
      totalWeightDelta: -1.4,
      days: 108,
      initialFat: 30.1,
      initialWeight: 93.0,
      initialMuscle: 60.2,
      goalWeight: 96.0,
      goalFat: 20.0,
      minWeight: 80.0,
      waterStatus: 'Insuf.',
      fatStatus: 'Alta',
      muscleStatus: 'Boa',
      visceralStatus: 'Alta',
      proteinStatus: 'Normal',
      weightStatus: 'Em queda',
      boneMass: 3.31,
      bmi: 27.3,
      basal: 1752,
      bodyType: 'Grosso-conjunto',
      monthLabel: 'ABR 2026',
    );
  }
}

String fmt(double value, {int casas = 1}) {
  return value.toStringAsFixed(casas).replaceAll('.', ',');
}
