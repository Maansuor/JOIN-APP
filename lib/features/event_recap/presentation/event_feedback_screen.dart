import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pantalla de Feedback Post-Evento
class EventFeedbackScreen extends StatefulWidget {
  final String activityId;

  const EventFeedbackScreen({super.key, required this.activityId});

  @override
  State<EventFeedbackScreen> createState() => _EventFeedbackScreenState();
}

class _EventFeedbackScreenState extends State<EventFeedbackScreen> {
  double groupRating = 4;
  int attendanceScore = 4;
  bool wouldAttendAgain = true;
  final groupCommentController = TextEditingController();

  final List<String> suggestions = [
    'Organización',
    'Gente',
    'Naturaleza',
    'Actividad',
    'Snacks',
    'Conversaciones',
    'Ambiente',
    'Duración',
  ];

  List<String> selectedBestThings = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('¿Qué te pareció?'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu opinión nos importa',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ayuda a otros a descubrir actividades geniales',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Calificación del grupo
            const Text(
              'Califica el evento',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildRatingBar(
              value: groupRating.toInt(),
              onChanged: (value) => setState(() => groupRating = value.toDouble()),
            ),
            const SizedBox(height: 24),

            // Comentario
            const Text(
              'Cuéntanos más',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: groupCommentController,
              decoration: InputDecoration(
                hintText: '¿Qué fue lo mejor? ¿Qué se podría mejorar?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Lo mejor del evento
            const Text(
              'Lo mejor fue...',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions.map((suggestion) {
                final isSelected = selectedBestThings.contains(suggestion);
                return FilterChip(
                  label: Text(suggestion),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedBestThings.add(suggestion);
                      } else {
                        selectedBestThings.remove(suggestion);
                      }
                    });
                  },
                  backgroundColor: Colors.grey[50],
                  selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  side: BorderSide(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ¿Volverías?
            const Text(
              '¿Volverías a asistir?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => wouldAttendAgain = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: wouldAttendAgain ? Colors.green[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: wouldAttendAgain ? Colors.green[400]! : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '👍 Sí, claro',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: wouldAttendAgain ? Colors.green[700] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => wouldAttendAgain = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !wouldAttendAgain ? Colors.red[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !wouldAttendAgain ? Colors.red[400]! : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '👎 Quizás no',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !wouldAttendAgain ? Colors.red[700] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Botones de acción
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Gracias por tu feedback!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Future.delayed(const Duration(seconds: 1), () {
                    context.go('/activity/${widget.activityId}');
                  });
                },
                child: const Text('Enviar Feedback'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Saltar'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Construir barra de calificación por estrellas
  Widget _buildRatingBar({required int value, required ValueChanged<int> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () => onChanged(index + 1),
            child: Icon(
              index < value ? Icons.star : Icons.star_outline,
              size: 40,
              color: Colors.amber,
            ),
          ),
        );
      }),
    );
  }
}
