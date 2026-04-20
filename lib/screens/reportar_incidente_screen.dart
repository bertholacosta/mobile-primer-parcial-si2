import 'package:flutter/material.dart';
import '../api/api_service.dart';

import 'package:latlong2/latlong.dart';

class ReportarIncidenteScreen extends StatefulWidget {
  final List<dynamic> vehiculosRegistrados;
  final LatLng? gpsReal;

  const ReportarIncidenteScreen({Key? key, required this.vehiculosRegistrados, this.gpsReal}) : super(key: key);

  @override
  _ReportarIncidenteScreenState createState() => _ReportarIncidenteScreenState();
}

class _ReportarIncidenteScreenState extends State<ReportarIncidenteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionController = TextEditingController();
  
  int? _vehiculoSeleccionadoId;
  bool _isLoading = false;

  // Seguimos mockeando fotos/audios hasta futuras librerias de multimedia
  final String _mockFoto = "base64_pseudo_foto_here_o_url_a_aws";
  final String _mockAudio = "base64_pseudo_audio_here";

  Future<void> _submitIncidente() async {
    if (_vehiculoSeleccionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un vehículo')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final payload = {
          "coordenadagps": widget.gpsReal != null ? "${widget.gpsReal!.latitude}, ${widget.gpsReal!.longitude}" : "-17.78111, -63.18123",
          "estado": "Reportado",
          "vehiculo_id": _vehiculoSeleccionadoId,
          "evidencia": {
            "descripcion": _descripcionController.text.trim(),
            "fotos": _mockFoto,
            "audio": _mockAudio
          }
        };

        await ApiService.reportarIncidente(payload);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergencia reportada exitosamente. La ayuda está en camino.'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.pop(context, true);
      } catch (e) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error al reportar'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              )
            ],
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay vehículos, no se puede reportar un accidente asociado a uno
    if (widget.vehiculosRegistrados.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.red[900], title: const Text('Reportar Emergencia')),
        body: const Center(child: Text("Debes registrar al menos un vehículo antes de reportar.")),
      );
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text('Reportar Emergencia', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red[900],
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.warning_rounded, color: Colors.orange, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Mantén la calma.\nNuestros mecánicos estarán contigo pronto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                
                // --- SELECCION DE VEHICULO ---
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Vehículo Afectado',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  value: _vehiculoSeleccionadoId,
                  items: widget.vehiculosRegistrados.map((v) {
                    return DropdownMenuItem<int>(
                      value: v['Id'],
                      child: Text('${v['Marca']} ${v['Modelo']} - ${v['Placa']}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _vehiculoSeleccionadoId = val;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // --- DESCRIPCION EVENTO ---
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(
                    labelText: '¿Qué sucedió? (Descripción)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: (v) => v!.isEmpty ? 'Por favor ingresa una descripción' : null,
                ),
                const SizedBox(height: 20),

                // --- SIMULACROS DE HARDWARE ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                         IconButton(
                          icon: const Icon(Icons.location_on, color: Colors.blue, size: 30),
                          onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS Capturado (Simulado)')));
                          },
                        ),
                        const Text('Gps Activo', style: TextStyle(fontSize: 12))
                      ],
                    ),
                    Column(
                      children: [
                         IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.green, size: 30),
                          onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto Capturada (Simulada)')));
                          },
                        ),
                        const Text('Añadir Foto', style: TextStyle(fontSize: 12))
                      ],
                    ),
                    Column(
                       children: [
                         IconButton(
                          icon: const Icon(Icons.mic, color: Colors.red, size: 30),
                          onPressed: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio Grabado (Simulado)')));
                          },
                        ),
                        const Text('Grabar Audio', style: TextStyle(fontSize: 12))
                       ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // --- BOTON DE SUBMIT ---
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitIncidente,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ENVIAR REPORTE (S.O.S)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        )));
  }
}
