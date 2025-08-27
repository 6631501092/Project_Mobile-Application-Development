import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const baseUrl = 'http://localhost:3000';

void main() async {
  final loginInfo = await login();           // {userId, username} or null
  if (loginInfo == null) { print("Good bye"); return; }

  while (true) {
    print("\n========== Expense Tracking App ==========");
    print("Welcome ${loginInfo['username']}");
    print("1. All expenses");
    print("2. Today's expense");
    print("3. Search expense");
    print("4. Add new expense");
    print("5. Delete an expense");
    print("6. Exit");
    stdout.write("Choose...");

    final c = stdin.readLineSync()?.trim() ?? '';
    if (c == '6') break;

    if (c == '1') {
      await showList('/expenses?userId=${loginInfo['userId']}', "All expenses");
    } else if (c == '2') {
      await showList('/expenses/today?userId=${loginInfo['userId']}', "Today's expenses");
    } else if (c == '3') {
      stdout.write("Item to search: ");
      final q = stdin.readLineSync()?.trim() ?? '';
      if (q.isEmpty) { print("No item: (empty)"); continue; }
      await showList('/expenses/search?userId=${loginInfo['userId']}&q=${Uri.encodeQueryComponent(q)}', "Search '$q'");
    } else if (c == '4') {
      print("===== Add new item =====");
      stdout.write("Item: ");
      final item = stdin.readLineSync()?.trim() ?? '';
      stdout.write("Paid: ");
      final paid = stdin.readLineSync()?.trim() ?? '';
      if (item.isEmpty || paid.isEmpty) { print("Input incomplete"); continue; }
      await addExpense(loginInfo['userId'], item, paid);
    } else if (c == '5') {
      print("===== Delete an item =====");
      stdout.write("Item id: ");
      final id = stdin.readLineSync()?.trim() ?? '';
      if (id.isEmpty) continue;
      await deleteExpense(loginInfo['userId'], id);
    } else {
      print("Unknown choice");
    }
  }

  print("---- Bye ----");
}

// login return {userId, username} or null
Future<Map<String, dynamic>?> login() async {
  print("===== Login =====");
  stdout.write("Username: "); final u = stdin.readLineSync()?.trim() ?? '';
  stdout.write("Password: "); final p = stdin.readLineSync()?.trim() ?? '';
  try {
    final r = await http.post(Uri.parse('$baseUrl/login'), body: {'username': u, 'password': p});
    if (r.statusCode == 200) return jsonDecode(r.body);
    print(jsonDecode(r.body)['error'] ?? 'Login failed'); return null;
  } catch (e) { print("Connection error: $e"); return null; }
}

// datetime format (YYYY-MM-DD HH:mm:ss.SSS)
String fmtLocal(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    String two(n) => n.toString().padLeft(2, '0');
    String three(n) => n.toString().padLeft(3, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
           '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}.${three(dt.millisecond)}';
  } catch (_) { return iso; } 
}

// GET print list
Future<void> showList(String path, String title) async {
  try {
    final r = await http.get(Uri.parse('$baseUrl$path'));
    if (r.statusCode != 200) { print("Error: ${r.body}"); return; }
    final d = jsonDecode(r.body);
    final items = (d['items'] as List).cast<Map<String, dynamic>>();

    if (items.isEmpty) {
      if (title.startsWith("Search")) {
        final q = title.replaceAll("Search '", "").replaceAll("'", "");
        print("No item: $q");
      } else {
        print("No item found.");
      }
      return;
    }

    print("------------- $title -----------");
    for (final row in items) {
      print("${row['id']}. ${row['item']} : ${row['paid']}฿ : ${fmtLocal(row['date'])}");
    }

    if (!title.startsWith("Search")) {
      print("Total expenses = ${d['total']}฿");
    }
  } catch (e) { print("Connection error: $e"); }
}

// POST add
Future<void> addExpense(int userId, String item, String paidStr) async {
  final amount = int.tryParse(paidStr);
  if (amount == null) {
    print("Amount must be a number");
    return;
  }
  try {
    final r = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'item': item, 'amount': amount}),
    );
    if (r.statusCode == 200) {
      print("Inserted!");
    } else {
      print("Insert failed: ${r.body}");
    }
  } catch (e) {
    print("Connection error: $e");
  }
}

// DELETE
Future<void> deleteExpense(int userId, String id) async {
  try {
    final r = await http.delete(Uri.parse('$baseUrl/expenses/$id?userId=$userId'));
    if (r.statusCode == 200) {
      print("Deleted!");
    } else {
      try {
        print(jsonDecode(r.body)['error'] ?? 'Delete failed');
      } catch (_) {
        print('Delete failed');
      }
    }
  } catch (e) {
    print("Connection error: $e");
  }
}
