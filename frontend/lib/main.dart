import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// --- CONFIG ---
// Use 10.0.2.2 for Android Emulator, or your PC IP (e.g. 192.168.x.x) for physical device
// const String BASE_URL = "http://10.0.2.2:8000";
// const String BASE_URL = "http://127.0.0.1:8000"; // Ancien (Local)
const String BASE_URL = "https://parkinson-app-6vt4.onrender.com";  // Nouveau (Internet)
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parkinson Detection',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}

// --- STATE MANAGEMENT ---
class AuthProvider extends ChangeNotifier {
  int? userId;
  String? username;
  bool isAdmin = false;

  void login(int id, String name, bool admin) {
    userId = id;
    username = name;
    isAdmin = admin;
    notifyListeners();
  }

  void logout() {
    userId = null;
    username = null;
    isAdmin = false;
    notifyListeners();
  }
}

// --- SCREENS ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLogin = true;

  Future<void> _submit() async {
    final endpoint = _isLogin ? "/login" : "/signup";
    try {
      final response = await http.post(
        Uri.parse("$BASE_URL$endpoint"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userController.text,
          "password": _passController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (_isLogin) {
          final data = jsonDecode(response.body);
          Provider.of<AuthProvider>(context, listen: false).login(
            data['user_id'],
            data['username'],
            data['is_admin'],
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          setState(() => _isLogin = true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sign up successful! Please log in.")));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Error. Is backend running? $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? "Login" : "Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(controller: _userController, decoration: const InputDecoration(labelText: "Username")),
                const SizedBox(height: 15),
                TextField(controller: _passController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(onPressed: _submit, child: Text(_isLogin ? "Log In" : "Sign Up")),
                ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? "Create account" : "Have an account?"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                auth.logout();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
              })
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Welcome, ${auth.username}!", style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 40),
            _MenuButton(icon: Icons.draw, text: "Start Spiral Test", color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DrawingScreen()))),
            const SizedBox(height: 20),
            _MenuButton(icon: Icons.history, text: "View History", color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
            if (auth.isAdmin) ...[
              const SizedBox(height: 20),
              _MenuButton(icon: Icons.admin_panel_settings, text: "Admin Stats", color: Colors.redAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()))),
            ]
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;
  const _MenuButton({required this.icon, required this.text, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white, size: 28),
      label: Text(text, style: const TextStyle(fontSize: 18, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
    );
  }
}

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});
  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  List<Offset?> points = [];
  bool _isLoading = false;

  Future<void> _uploadDrawing() async {
    if (points.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromPoints(const Offset(0, 0), const Offset(400, 400)));
      final paint = Paint()..color = Colors.black..strokeCap = StrokeCap.round..strokeWidth = 3.0;
      canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 400), Paint()..color = Colors.white);
      
      for (int i = 0; i < points.length - 1; i++) {
        if (points[i] != null && points[i + 1] != null) {
          canvas.drawLine(points[i]!, points[i + 1]!, paint);
        }
      }
      
      final picture = recorder.endRecording();
      final img = await picture.toImage(400, 400);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final auth = Provider.of<AuthProvider>(context, listen: false);
      var request = http.MultipartRequest('POST', Uri.parse("$BASE_URL/predict"));
      request.fields['user_id'] = auth.userId.toString();
      request.files.add(http.MultipartFile.fromBytes('file', pngBytes, filename: 'spiral.png'));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ResultScreen(result: data)));
      } else {
        throw Exception("Failed to upload");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Draw a Spiral"), actions: [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => points.clear()))
      ]),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      RenderBox renderBox = context.findRenderObject() as RenderBox;
                      points.add(renderBox.globalToLocal(details.globalPosition) - const Offset(20, 80));
                    });
                  },
                  onPanEnd: (details) => points.add(null),
                  child: CustomPaint(painter: SpiralPainter(points), size: Size.infinite),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(onPressed: _uploadDrawing, child: const Text("Submit Analysis")),
                  ),
          )
        ],
      ),
    );
  }
}

class SpiralPainter extends CustomPainter {
  final List<Offset?> points;
  SpiralPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Colors.black..strokeCap = StrokeCap.round..strokeWidth = 4.0;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }
  @override
  bool shouldRepaint(SpiralPainter oldDelegate) => true;
}

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    Uint8List? limeImage;
    if (result['lime_explanation'] != null) limeImage = base64Decode(result['lime_explanation']);

    final isHighRisk = result['label'] != "Healthy";

    return Scaffold(
      appBar: AppBar(title: const Text("Analysis Result")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isHighRisk ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Icon(isHighRisk ? Icons.warning : Icons.check_circle, size: 50, color: isHighRisk ? Colors.red : Colors.green),
                  const SizedBox(height: 10),
                  Text(result['label'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text("Risk Score: ${(result['score'] * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text("Visual Explanation (LIME)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            if (limeImage != null) 
              Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                child: Image.memory(limeImage, height: 300, fit: BoxFit.contain)
              )
            else 
              const Text("No explanation available"),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Back to Home"))
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<List<dynamic>> _fetchHistory(int userId) async {
    final response = await http.get(Uri.parse("$BASE_URL/history/$userId"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to load history");
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Test History")),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchHistory(auth.userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          final data = snapshot.data!;
          if (data.isEmpty) return const Center(child: Text("No history found."));

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              final score = (item['prediction_score'] as double);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: score > 0.5 ? Colors.red : Colors.green,
                    child: Icon(score > 0.5 ? Icons.priority_high : Icons.check, color: Colors.white, size: 16),
                  ),
                  title: Text(score > 0.5 ? "High Risk" : "Healthy"),
                  subtitle: Text("Date: ${item['timestamp']}"),
                  trailing: Text("${(score * 100).toStringAsFixed(1)}%"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<Map<String, dynamic>> _fetchStats() async {
    final response = await http.get(Uri.parse("$BASE_URL/admin/stats"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Failed to load stats");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          final data = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _statCard("Total Users", "${data['total_users']}", Colors.blue),
                _statCard("Total Tests Run", "${data['total_drawings']}", Colors.purple),
                _statCard("Avg Global Risk", "${(data['average_risk_score'] * 100).toStringAsFixed(1)}%", Colors.orange),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 15),
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
