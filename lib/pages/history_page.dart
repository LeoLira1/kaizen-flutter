import 'package:flutter/material.dart';

import '../models/body_measurement.dart';

class HistoryPage extends StatelessWidget {
  final List<BodyMeasurement> history;

  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final sorted = [...history]..sort((a, b) => b.date.compareTo(a.date));
    final entries = <Object>[];
    String? currentMonth;
    for (final measurement in sorted) {
      final month = _monthLabel(measurement.date);
      if (month != currentMonth) {
        entries.add(month);
        currentMonth = month;
      }
      entries.add(measurement);
    }

    if (entries.isEmpty) {
      return const SafeArea(
        child: Center(child: Text('Nenhuma medição salva no histórico.')),
      );
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
            itemCount: entries.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histórico',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Toque em uma medição para ver todos os dados disponíveis.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7A746E),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final entry = entries[index - 1];
              if (entry is String) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                  child: Text(
                    entry.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: Color(0xFF7A746E),
                    ),
                  ),
                );
              }
              final measurement = entry as BodyMeasurement;
              return Card(
                elevation: 0,
                color: Colors.white.withOpacity(0.92),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE7DED4)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  title: Text(
                    measurement.weight == null
                        ? 'Peso não disponível'
                        : '${_format(measurement.weight)} kg',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(_dateTimeLabel(measurement)),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF7A746E),
                  ),
                  onTap: () => showMeasurementDetails(context, measurement),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> showMeasurementDetails(
  BuildContext context,
  BodyMeasurement measurement,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFFDF8F2),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      minChildSize: 0.5,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7CEC4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Detalhes da medição',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _dateTimeLabel(measurement),
            style: const TextStyle(color: Color(0xFF7A746E)),
          ),
          const SizedBox(height: 18),
          _detail('Peso', measurement.weight, 'kg', measurement.weightStatus),
          _detail('Gordura', measurement.fat, '%', measurement.fatStatus),
          _detail('Músculo', measurement.muscle, 'kg', measurement.muscleStatus),
          _detail('Água', measurement.water, '%', measurement.waterStatus),
          _detail('Visceral', measurement.visceral, '', measurement.visceralStatus),
          _detail('Proteína', measurement.protein, '%', measurement.proteinStatus),
          _detail('Score Zepp', measurement.score, ''),
          _detail('IMC', measurement.bmi, ''),
          _detail('Massa óssea', measurement.boneMass, 'kg'),
          _detail('Metabolismo basal', measurement.basal, 'kcal'),
          _textDetail('Tipo corporal', measurement.bodyType),
          _textDetail('Data informada pelo Zepp', measurement.measuredAtLabel),
        ],
      ),
    ),
  );
}

Widget _detail(String label, double? value, String suffix, [String? status]) => _textDetail(
      label,
      value == null
          ? null
          : '${_format(value)}${suffix.isEmpty ? '' : ' $suffix'}'
              '${status == null ? '' : ' · $status'}',
    );

Widget _textDetail(String label, String? value) => Container(
  padding: const EdgeInsets.symmetric(vertical: 13),
  decoration: const BoxDecoration(
    border: Border(bottom: BorderSide(color: Color(0xFFE7DED4))),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: Color(0xFF7A746E))),
      ),
      const SizedBox(width: 16),
      Flexible(
        child: Text(
          value == null || value.isEmpty ? '—' : value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  ),
);

String _dateTimeLabel(BodyMeasurement measurement) {
  final date = measurement.date.toLocal();
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} · $hour:$minute';
}

String _monthLabel(DateTime date) {
  const months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _format(double? value) =>
    value == null ? '—' : value.toStringAsFixed(1).replaceAll('.', ',');
