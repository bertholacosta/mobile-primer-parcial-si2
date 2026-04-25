import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../api/api_service.dart';

class EstadoIncidenteScreen extends StatefulWidget {
  final Map<String, dynamic> incidente;
  final LatLng? gpsReal;

  const EstadoIncidenteScreen({
    Key? key,
    required this.incidente,
    this.gpsReal,
  }) : super(key: key);

  @override
  _EstadoIncidenteScreenState createState() => _EstadoIncidenteScreenState();
}

class _EstadoIncidenteScreenState extends State<EstadoIncidenteScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _incidente;
  List<dynamic> _talleres = [];
  bool _isLoadingTalleres = true;
  bool _isAsignando = false;
  bool _isCancelando = false;
  late AnimationController _pulseController;

  final List<_EstadoPaso> _pasos = [
    _EstadoPaso('Reportado', Icons.report_problem_rounded, Color(0xFFE53935)),
    _EstadoPaso('Asignado', Icons.assignment_turned_in, Color(0xFFFB8C00)),
    _EstadoPaso('En Camino', Icons.local_shipping, Color(0xFF1E88E5)),
    _EstadoPaso('Resuelto', Icons.check_circle, Color(0xFF43A047)),
  ];

  @override
  void initState() {
    super.initState();
    _incidente = widget.incidente;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _cargarTalleres();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _cargarTalleres() async {
    try {
      final talleres = await ApiService.getTalleresDisponibles(
        widget.gpsReal?.latitude,
        widget.gpsReal?.longitude,
      );
      if (mounted) {
        setState(() {
          _talleres = talleres;
          _isLoadingTalleres = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTalleres = false);
      }
    }
  }

  Future<void> _asignarTaller(int tallerId) async {
    setState(() => _isAsignando = true);
    try {
      final updated = await ApiService.asignarTaller(_incidente['id'], tallerId);
      if (mounted) {
        setState(() {
          _incidente = updated;
          _isAsignando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Taller asignado exitosamente'),
            backgroundColor: Color(0xFF43A047),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAsignando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelarIncidente() async {
    setState(() => _isCancelando = true);
    try {
      await ApiService.cancelarIncidente(_incidente['id']);
      if (mounted) {
        setState(() {
          _incidente['estado'] = 'Cancelado';
          _isCancelando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitud cancelada exitosamente'),
            backgroundColor: Color(0xFF78909C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmarCancelacion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2236),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935), size: 28),
            SizedBox(width: 10),
            Text('Cancelar Solicitud',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas cancelar esta solicitud de emergencia? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Volver', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelarIncidente();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );
  }

  int _getEstadoIndex(String estado) {
    if (estado == 'Cancelado') return -1;
    for (int i = 0; i < _pasos.length; i++) {
      if (_pasos[i].nombre == estado) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final estadoActual = _incidente['estado'] ?? 'Reportado';
    final estadoIndex = _getEstadoIndex(estadoActual);
    final tallerAsignado = _incidente['taller'];
    final bool tieneTaller = tallerAsignado != null && _incidente['taller_id'] != null;
    final bool isCancelado = estadoActual == 'Cancelado';
    final bool puedeCancelar = !isCancelado && (estadoActual == 'Reportado' || estadoActual == 'Asignado');

    return Scaffold(
      backgroundColor: const Color(0xFF0F1523),
      appBar: AppBar(
        title: const Text('Estado de Solicitud',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ─── ESTADO CANCELADO ───
            if (isCancelado) _buildCanceladoBanner(),

            // ─── TIMELINE DE ESTADO ───
            if (!isCancelado) _buildTimeline(estadoIndex),

            const SizedBox(height: 8),

            // ─── TALLER ASIGNADO ───
            if (tieneTaller && !isCancelado) _buildTallerAsignado(tallerAsignado),

            // ─── LISTA DE TALLERES DISPONIBLES ───
            if (!tieneTaller && !isCancelado) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.build_circle,
                          color: Color(0xFF1E88E5), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Talleres Disponibles',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text('Selecciona uno para solicitar asistencia',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildListaTalleres(),
            ],

            // ─── BOTÓN CANCELAR SOLICITUD ───
            if (puedeCancelar) _buildCancelButton(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─── WIDGET: BANNER CANCELADO ─────────────────────────────────
  Widget _buildCanceladoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF37474F),
            const Color(0xFF263238),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF78909C).withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF78909C).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cancel_rounded,
                color: Color(0xFF90A4AE), size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'SOLICITUD CANCELADA',
            style: TextStyle(
              color: Color(0xFF90A4AE),
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Esta solicitud de emergencia ha sido cancelada por el conductor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ─── WIDGET: BOTÓN CANCELAR ───────────────────────────────────
  Widget _buildCancelButton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCancelando ? null : _confirmarCancelacion,
        icon: _isCancelando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFE53935)),
              )
            : const Icon(Icons.cancel_outlined, size: 20),
        label: Text(_isCancelando ? 'Cancelando...' : 'Cancelar Solicitud'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE53935),
          side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ─── WIDGET: TIMELINE ─────────────────────────────────────────
  Widget _buildTimeline(int estadoIndex) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2236),
            const Color(0xFF1A2236).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: _pasos[estadoIndex].color.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Status pill
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _pasos[estadoIndex]
                      .color
                      .withOpacity(0.1 + _pulseController.value * 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _pasos[estadoIndex].color.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_pasos[estadoIndex].icono,
                        color: _pasos[estadoIndex].color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _pasos[estadoIndex].nombre.toUpperCase(),
                      style: TextStyle(
                        color: _pasos[estadoIndex].color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Timeline steps
          Row(
            children: List.generate(_pasos.length, (index) {
              final isActive = index <= estadoIndex;
              final isCurrent = index == estadoIndex;
              return Expanded(
                child: Column(
                  children: [
                    // Dot + line
                    Row(
                      children: [
                        if (index > 0)
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? _pasos[index].color
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: isCurrent ? 36 : 24,
                          height: isCurrent ? 36 : 24,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _pasos[index].color
                                : Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: _pasos[index]
                                          .color
                                          .withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : [],
                          ),
                          child: Icon(
                            _pasos[index].icono,
                            size: isCurrent ? 18 : 12,
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                          ),
                        ),
                        if (index < _pasos.length - 1)
                          Expanded(
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: index < estadoIndex
                                    ? _pasos[index + 1].color
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pasos[index].nombre,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withOpacity(0.35),
                        fontSize: 10,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── WIDGET: TALLER ASIGNADO ──────────────────────────────────
  Widget _buildTallerAsignado(Map<String, dynamic> taller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF43A047).withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.check_circle, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Taller Asignado',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    SizedBox(height: 2),
                    Text('Asistencia confirmada',
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            taller['Nombre'] ?? 'Taller',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  taller['Direccion'] ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── WIDGET: LISTA DE TALLERES ────────────────────────────────
  Widget _buildListaTalleres() {
    if (_isLoadingTalleres) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
        ),
      );
    }

    if (_talleres.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2236),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: const Column(
          children: [
            Icon(Icons.search_off, color: Colors.white38, size: 48),
            SizedBox(height: 12),
            Text('No hay talleres disponibles',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
            SizedBox(height: 4),
            Text('Intenta más tarde',
                style: TextStyle(color: Colors.white30, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _talleres.length,
      itemBuilder: (context, index) {
        final taller = _talleres[index];
        final cap = taller['Cap'] ?? 0;
        final capmax = taller['Capmax'] ?? 1;
        final distancia = taller['distancia_km'];
        final porcentaje = capmax > 0 ? cap / capmax : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2236),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isAsignando
                  ? null
                  : () => _confirmarAsignacion(taller),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1E88E5).withOpacity(0.2),
                                const Color(0xFF1565C0).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.build_rounded,
                              color: Color(0xFF42A5F5), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                taller['Nombre'] ?? 'Taller',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.white38, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      taller['Direccion'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (distancia != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${distancia} km',
                              style: const TextStyle(
                                  color: Color(0xFF42A5F5),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Capacity bar
                    Row(
                      children: [
                        const Icon(Icons.people_alt_outlined,
                            color: Colors.white38, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: porcentaje.toDouble(),
                              backgroundColor: Colors.white.withOpacity(0.08),
                              valueColor: AlwaysStoppedAnimation(
                                porcentaje < 0.7
                                    ? const Color(0xFF43A047)
                                    : porcentaje < 0.9
                                        ? const Color(0xFFFB8C00)
                                        : const Color(0xFFE53935),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$cap / $capmax',
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Select button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAsignando
                            ? null
                            : () => _confirmarAsignacion(taller),
                        icon: const Icon(Icons.handshake, size: 18),
                        label: const Text('Solicitar Asistencia'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmarAsignacion(Map<String, dynamic> taller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2236),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Selección',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas solicitar asistencia al taller "${taller['Nombre']}"?',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              taller['Direccion'] ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _asignarTaller(taller['Id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class _EstadoPaso {
  final String nombre;
  final IconData icono;
  final Color color;

  const _EstadoPaso(this.nombre, this.icono, this.color);
}
