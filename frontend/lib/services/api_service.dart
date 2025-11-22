import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart'; // Importez le modèle créé à l'étape 1

class ApiService {
  final String baseUrl = "http://10.0.2.2:8000"; // ou votre IP locale

  // ... vos autres fonctions (login, signup, predict) ...

  // 1. Récupérer la liste des utilisateurs
  Future<List<User>> getAllUsers(int adminId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users?admin_id=$adminId'),
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => User.fromJson(item)).toList();
    } else {
      throw Exception("Impossible de charger les utilisateurs");
    }
  }

  // 2. Supprimer un utilisateur
  Future<void> deleteUser(int adminId, int userIdToDelete) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/users/$userIdToDelete?admin_id=$adminId'),
    );

    if (response.statusCode != 200) {
      throw Exception("Erreur lors de la suppression");
    }
  }
}