import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

class AdminUsersScreen extends StatefulWidget {
  final int adminId; // On a besoin de l'ID de l'admin connecté

  const AdminUsersScreen({Key? key, required this.adminId}) : super(key: key);

  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final ApiService api = ApiService();
  List<User> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  // Charger la liste
  void fetchUsers() async {
    try {
      final fetchedUsers = await api.getAllUsers(widget.adminId);
      setState(() {
        users = fetchedUsers;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  // Supprimer un utilisateur
  void deleteUser(int userId) async {
    try {
      await api.deleteUser(widget.adminId, userId);
      // On retire l'utilisateur de la liste locale pour mettre à jour l'écran
      setState(() {
        users.removeWhere((user) => user.id == userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Utilisateur supprimé")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur suppression: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Gestion Utilisateurs")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: Icon(Icons.person, color: user.isAdmin ? Colors.red : Colors.blue),
                    title: Text(user.username),
                    subtitle: Text(user.isAdmin ? "Administrateur" : "Utilisateur"),
                    trailing: user.id == widget.adminId 
                        ? null // On ne peut pas se supprimer soi-même
                        : IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // Confirmation avant suppression
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text("Supprimer ?"),
                                  content: Text("Voulez-vous vraiment supprimer ${user.username} et toutes ses données ?"),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Non")),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        deleteUser(user.id);
                                      },
                                      child: Text("Oui", style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                );
              },
            ),
    );
  }
}