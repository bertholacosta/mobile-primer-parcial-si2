import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Nota: 10.0.2.2 es el localhost equivalente para el emulador de Android.
  // Si corres de forma nativa en Windows, usar 127.0.0.1.
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<Map<String, dynamic>> registerConductor(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/registrar-conductor'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error de registro');
    }
  }

  static Future<String?> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final token = body['access_token'];
      final role = body['role'];
      
      // Bloquear cualquier ingreso que no sea conductor
      if (role != 'Conductor') {
         throw Exception('Acceso Denegado. Solo Conductores pueden usar esta App.');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('role', role);
      return token;
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error de credenciales');
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('token');
  }

  // --- Endpoints de Vehículos ---
  static Future<List<dynamic>> getVehiculos() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.get(
      Uri.parse('$baseUrl/vehiculos/mis-vehiculos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al cargar vehículos');
    }
  }

  static Future<Map<String, dynamic>> addVehiculo(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null) throw Exception('No autenticado');

    final response = await http.post(
      Uri.parse('$baseUrl/vehiculos/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['detail'] ?? 'Error al registrar vehículo');
    }
  }
}
