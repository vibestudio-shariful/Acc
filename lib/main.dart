import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HishabKitabApp());
}

class HishabKitabApp extends StatelessWidget {
  const HishabKitabApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hishab Kitab Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, primary: Colors.teal),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const MainNavigation(),
    );
  }
}

// ================= DATABASE ENGINE =================
class DbService {
  static Database? _db;
  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'hishab_pro.db'),
      onCreate: (db, version) async {
        await db.execute("CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, type TEXT, category TEXT, date TEXT)");
        await db.execute("CREATE TABLE debts(id INTEGER PRIMARY KEY AUTOINCREMENT, person TEXT, amount REAL, type TEXT, date TEXT)");
        await db.execute("CREATE TABLE savings(id INTEGER PRIMARY KEY AUTOINCREMENT, goal_name TEXT, target REAL, current REAL)");
      },
      version: 1,
    );
    return _db!;
  }
}

// ================= NAVIGATION =================
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _curr = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const DebtScreen(),
    const AddEntryScreen(),
    const SavingsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _curr, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _curr,
        onDestinationSelected: (i) => setState(() => _curr = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_filled), label: 'হোম'),
          NavigationDestination(icon: Icon(Icons.handshake), label: 'দেনাপাওনা'),
          NavigationDestination(icon: Icon(Icons.add_circle, size: 35, color: Colors.teal), label: 'এন্ট্রি'),
          NavigationDestination(icon: Icon(Icons.savings), label: 'সঞ্চয়'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'সেটিংস'),
        ],
      ),
    );
  }
}

// ================= 1. HOME SCREEN =================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _list = [];
  double _inc = 0, _exp = 0;

  void _load() async {
    final d = await DbService.db;
    final res = await d.query('transactions', orderBy: 'id DESC');
    double i = 0, e = 0;
    for (var r in res) {
      if (r['type'] == 'income') i += (r['amount'] as num);
      else e += (r['amount'] as num);
    }
    setState(() { _list = res; _inc = i; _exp = e; });
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("হিসাব কিতাব প্রো"), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: Column(
        children: [
          _buildSummaryCard(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [Text("সাম্প্রতিক লেনদেন", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
          ),
          Expanded(child: _buildTransactionList()),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.teal, Colors.tealAccent]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text("মোট ব্যালেন্স: ৳${(_inc - _exp).toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("আয়", _inc, Colors.white),
              _statItem("ব্যয়", _exp, Colors.white70),
            ],
          )
        ],
      ),
    );
  }

  Widget _statItem(String label, double val, Color col) {
    return Column(children: [Text(label, style: TextStyle(color: col)), Text("৳$val", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))]);
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: _list.length,
      itemBuilder: (c, i) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Icon(_list[i]['type'] == 'income' ? Icons.south_west : Icons.north_east, color: _list[i]['type'] == 'income' ? Colors.green : Colors.red),
          title: Text(_list[i]['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(_list[i]['date'].toString().substring(0, 10)),
          trailing: Text("৳${_list[i]['amount']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          onTap: () => _showEditDialog(_list[i]),
          onLongPress: () => _delete(_list[i]['id']),
        ),
      ),
    );
  }

  void _delete(int id) async {
    final d = await DbService.db;
    await d.delete('transactions', where: 'id = ?', whereArgs: [id]);
    _load();
  }

  void _showEditDialog(Map<String, dynamic> item) {
    // এডিট করার জন্য ডায়ালগ লজিক এখানে আসবে
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("এডিট ফিচারটি সেটিংসে সক্রিয় করুন")));
  }
}

// ================= 2. DEBT SCREEN =================
class DebtScreen extends StatefulWidget {
  const DebtScreen({super.key});
  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("দেনাপাওনা")),
      floatingActionButton: FloatingActionButton(onPressed: (){}, child: const Icon(Icons.person_add)),
      body: const Center(child: Text("কার কাছে কত পাবেন বা দেবেন তার তালিকা")),
    );
  }
}

// ================= 3. ADD ENTRY SCREEN =================
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key});
  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  String _type = 'expense';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("নতুন এন্ট্রি")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: "বিবরণ", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _amount, decoration: const InputDecoration(labelText: "টাকার পরিমাণ", border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: RadioListTile(title: const Text("আয়"), value: 'income', groupValue: _type, onChanged: (v)=>setState(()=>_type=v!))),
                Expanded(child: RadioListTile(title: const Text("ব্যয়"), value: 'expense', groupValue: _type, onChanged: (v)=>setState(()=>_type=v!))),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.teal),
              child: const Text("সেভ করুন", style: TextStyle(color: Colors.white, fontSize: 18)),
            )
          ],
        ),
      ),
    );
  }

  void _save() async {
    if(_title.text.isEmpty || _amount.text.isEmpty) return;
    final d = await DbService.db;
    await d.insert('transactions', {
      'title': _title.text,
      'amount': double.parse(_amount.text),
      'type': _type,
      'date': DateTime.now().toIso8601String(),
      'category': 'General'
    });
    _title.clear(); _amount.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("লেনদেনটি সফলভাবে লিপিবদ্ধ হয়েছে")));
  }
}

// ================= 4. SAVINGS SCREEN =================
class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("সঞ্চয় ও লক্ষ্য")),
      body: const Center(child: Text("আপনার ভবিষ্যতের সঞ্চয়ের লক্ষ্যমাত্রা এখানে যোগ করুন")),
    );
  }
}

// ================= 5. SETTINGS SCREEN =================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("সেটিংস")),
      body: ListView(
        children: [
          const UserHeader(),
          _settingItem(Icons.language, "ভাষা", "বাংলা (Default)"),
          _settingItem(Icons.currency_exchange, "কারেন্সি সিম্বল", "BDT (৳)"),
          _settingItem(Icons.cloud_sync, "গুগল ড্রাইভ ব্যাকআপ", "শেষ ব্যাকআপ: ১২ মার্চ, ২০২৬"),
          _settingItem(Icons.lock, "অ্যাপ লক", "নিষ্ক্রিয়"),
          _settingItem(Icons.color_lens, "থিম কালার", "সবুজ (Teal)"),
          const Divider(),
          _settingItem(Icons.help_center, "সাহায্য ও সাপোর্ট", ""),
        ],
      ),
    );
  }

  Widget _settingItem(IconData icon, String title, String sub) {
    return ListTile(leading: Icon(icon), title: Text(title), subtitle: sub.isEmpty ? null : Text(sub), trailing: const Icon(Icons.chevron_right));
  }
}

class UserHeader extends StatelessWidget {
  const UserHeader({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: const Column(
        children: [
          CircleAvatar(radius: 50, backgroundColor: Colors.teal, child: Icon(Icons.person, size: 60, color: Colors.white)),
          SizedBox(height: 10),
          Text("শরিফুল ইসলাম", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text("MBA, ম্যানেজমেন্ট স্পেশালিস্ট", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
