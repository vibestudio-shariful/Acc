import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const MyBalanceApp());
}

class MyBalanceApp extends StatelessWidget {
  const MyBalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Balance',
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

// --- Dashboard ---
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Database _db;
  List<Map<String, dynamic>> _transactions = [];
  double _balance = 0, _income = 0, _expense = 0;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);

  @override
  void initState() {
    super.initState();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'balance.db'),
      onCreate: (db, version) => db.execute(
          "CREATE TABLE trans(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, type TEXT, date TEXT)"),
      version: 1,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _db.query('trans', orderBy: 'date DESC');
    double inc = 0, exp = 0;
    for (var item in data) {
      if (item['type'] == 'income') inc += item['amount'];
      else exp += item['amount'];
    }
    setState(() {
      _transactions = data;
      _income = inc;
      _expense = exp;
      _balance = inc - exp;
    });
  }

  Future<void> _backup() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user == null) return;
      final client = (await _googleSignIn.authenticatedClient())!;
      final driveApi = drive.DriveApi(client);
      
      final content = jsonEncode(_transactions);
      final bytes = utf8.encode(content);
      final media = drive.Media(Stream.value(bytes), bytes.length);
      final file = drive.File()..name = "MyBalance_Backup_${DateTime.now().millisecondsSinceEpoch}.json";
      
      await driveApi.files.create(file, uploadMedia: media);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ড্রাইভ ব্যাকআপ সফল!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ভুল: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("My Balance", style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _backup, icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF6366F1)))],
      ),
      body: Column(
        children: [
          _buildHeroCard(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildStatCard("আয়", _income, Colors.green, Icons.south_west)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("ব্যয়", _expense, Colors.red, Icons.north_east)),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(alignment: Alignment.centerLeft, child: Text("লেনদেনসমূহ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6366F1),
        onPressed: _showAddModal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Text("মোট ব্যালেন্স", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text("৳${_balance.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, double amt, Color col, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: col, size: 20),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Color(0xFF64748B))),
          Text("৳$amt", style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _transactions.length,
      itemBuilder: (context, i) {
        final item = _transactions[i];
        final isInc = item['type'] == 'income';
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF1F5F9))),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: (isInc ? Colors.green : Colors.red).withOpacity(0.1), child: Icon(isInc ? Icons.add : Icons.remove, color: isInc ? Colors.green : Colors.red)),
            title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(DateFormat('dd MMM, yyyy').format(DateTime.parse(item['date']))),
            trailing: Text("${isInc ? '+' : '-'} ৳${item['amount']}", style: TextStyle(color: isInc ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
            onLongPress: () => _delete(item['id']),
          ),
        );
      },
    );
  }

  void _delete(int id) async {
    await _db.delete('trans', where: 'id = ?', whereArgs: [id]);
    _loadData();
  }

  void _showAddModal() {
    String title = ""; double amount = 0; String type = "expense";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: const InputDecoration(labelText: "বিবরণ"), onChanged: (v) => title = v),
            TextField(decoration: const InputDecoration(labelText: "টাকা"), keyboardType: TextInputType.number, onChanged: (v) => amount = double.tryParse(v) ?? 0),
            DropdownButton<String>(
              value: type, isExpanded: true,
              items: const [DropdownMenuItem(value: "income", child: Text("আয়")), DropdownMenuItem(value: "expense", child: Text("ব্যয়"))],
              onChanged: (v) => setState(() => type = v!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                await _db.insert('trans', {'title': title, 'amount': amount, 'type': type, 'date': DateTime.now().toIso8601String()});
                _loadData(); Navigator.pop(context);
              },
              child: const Text("সেভ করুন", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
