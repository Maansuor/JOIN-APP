import 'package:flutter/material.dart';

class KamilMascotWidget extends StatefulWidget {
  const KamilMascotWidget({super.key});

  @override
  State<KamilMascotWidget> createState() => _KamilMascotWidgetState();
}

class _KamilMascotWidgetState extends State<KamilMascotWidget> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  // Draggable position
  Offset? _position;
  final double _mascotSize = 70.0;
  final double _chatWidth = 320.0;
  final double _chatHeight = 400.0;

  // Chat state
  final List<Map<String, dynamic>> _messages = [
    {
      'isBot': true,
      'text': '¡Hola! Soy Kamil 🐾, tu asistente.\n¿En qué te puedo ayudar hoy?'
    },
  ];
  bool _showOptions = true;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
        // Opcional: reiniciar el chat cuando se cierra
        _resetChat();
      }
    });
  }

  void _resetChat() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.add({
            'isBot': true,
            'text': '¡Hola! Soy Kamil 🐾, tu asistente.\n¿En qué te puedo ayudar hoy?'
          });
          _showOptions = true;
          _isTyping = false;
        });
      }
    });
  }

  void _handleOptionSelected(String title, String answer) {
    setState(() {
      _showOptions = false;
      _messages.add({'isBot': false, 'text': title});
      _isTyping = true;
    });

    // Simular tiempo de escritura de Kamil
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({'isBot': true, 'text': answer});
        });
        
        // Volver a mostrar opciones después de responder
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showOptions = true;
            });
          }
        });
      }
    });
  }

  // Lógica de arrastre
  void _onPanUpdate(DragUpdateDetails details, Size layoutSize) {
    if (_isOpen) return; // No mover si está abierto
    setState(() {
      _position = Offset(
        (_position!.dx + details.delta.dx).clamp(0, layoutSize.width - _mascotSize),
        (_position!.dy + details.delta.dy).clamp(0, layoutSize.height - _mascotSize),
      );
    });
  }

  void _onPanEnd(DragEndDetails details, Size layoutSize) {
    if (_isOpen) return;
    // Snap a las esquinas izquierda o derecha
    final screenHalfX = layoutSize.width / 2;
    double targetX = _position!.dx < screenHalfX ? 16.0 : layoutSize.width - _mascotSize - 16.0;
    
    // Evitar que suba muy arriba del AppBar o baje mucho
    double targetY = _position!.dy.clamp(100.0, layoutSize.height - 180.0);

    setState(() {
      _position = Offset(targetX, targetY);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    
    // Posición inicial: Abajo a la derecha, pero "un poco más arriba"
    _position ??= Offset(screenSize.width - _mascotSize - 16, screenSize.height - 200);

    // Determinar si está en la mitad izquierda o derecha para anclar el chat
    final bool isLeft = _position!.dx < (screenSize.width / 2);

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) => _onPanUpdate(details, screenSize),
        onPanEnd: (details) => _onPanEnd(details, screenSize),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Panel de Chat (Se despliega según donde esté la mascota)
            Positioned(
              bottom: _mascotSize + 10,
              right: isLeft ? null : 0,
              left: isLeft ? 0 : null,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: isLeft ? Alignment.bottomLeft : Alignment.bottomRight,
                child: _buildChatInterface(),
              ),
            ),
            // Burbuja/Mascota flotante
            GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _mascotSize,
                height: _mascotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: _isOpen ? const Color(0xFFFD7C36) : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                    color: const Color(0xFFFD7C36).withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: _isOpen ? 4 : 1,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/mascota/kamil.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.smart_toy_rounded,
                      color: Color(0xFFFD7C36),
                      size: 38,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Container(
      width: _chatWidth,
      height: _chatHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header del Chat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFD9D2E), Color(0xFFFD7C36)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 18,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Image.asset('assets/images/mascota/kamil.png',
                        errorBuilder: (c, e, s) => const Icon(Icons.smart_toy,
                            size: 20, color: Color(0xFFFD7C36))),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kamil',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text('En línea',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: _toggleMenu,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          // Área de Mensajes
          Expanded(
            child: Container(
              color: const Color(0xFFF8F9FA),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  return _buildMessageBubble(msg['text'], msg['isBot']);
                },
              ),
            ),
          ),

          // Área de Opciones (Teclado simulado)
          if (_showOptions)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -5),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Elige una pregunta:',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildOptionChip(
                    '¿Cómo crear una actividad?',
                    '¡Es súper fácil! 😎\n\nSolo presiona el botón naranja gigante con el símbolo "+" que está en el centro de tu barra de navegación inferior.\nLuego completa los detalles de tu plan y publícalo para que otros se unan.',
                  ),
                  const SizedBox(height: 6),
                  _buildOptionChip(
                    '¿Cómo unirme a un plan?',
                    'En tu pantalla de "Inicio" verás todos los planes disponibles 🗺️.\n\nToca el que más te guste, revisa bien los detalles y envía tu solicitud. ¡El organizador decidirá si te acepta en su grupo!',
                  ),
                  const SizedBox(height: 6),
                  _buildOptionChip(
                    '¿Qué pasa con los chats?',
                    'La privacidad y la limpieza son clave 🧹.\n\nExactamente 5 horas después de que finalice la fecha designada del plan, ELIMINAREMOS toda la actividad. ¡Todos los mensajes y solicitudes desaparecerán como por arte de magia! ✨',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isBot) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: _chatWidth * 0.75),
        decoration: BoxDecoration(
          color: isBot ? Colors.white : const Color(0xFFFFF0E6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isBot ? 0 : 16),
            bottomRight: Radius.circular(isBot ? 16 : 0),
          ),
          border: isBot ? Border.all(color: Colors.grey.shade200) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isBot ? Colors.black87 : const Color(0xFFC75100),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFD7C36)),
            ),
            SizedBox(width: 8),
            Text('Kamil está escribiendo...', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip(String title, String answer) {
    return InkWell(
      onTap: () => _handleOptionSelected(title, answer),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFFD7C36).withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFD7C36).withValues(alpha: 0.05),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFFD7C36),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
