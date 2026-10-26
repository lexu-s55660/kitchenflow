import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// НОВАЯ ССЫЛКА НА GOOGLE SCRIPT
const String _webAppUrl =
    'https://script.google.com/macros/s/AKfycbwKBLV50FffeI2MewkOliDJsg4ZrSA0vXKdnBcII5Ko5ujOlgtORckJ0A0pUeckSiBXkQ/exec';

void main() {
  runApp(const KitchenFlowApp());
}

class KitchenFlowApp extends StatelessWidget {
  const KitchenFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KitchenFlow',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey.shade900,
          foregroundColor: Colors.deepOrange,
        ),
      ),
      home: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: const HomeScreen(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RecentEntry {
  final String document;
  final String recipient;
  final String ingredient;
  final String amount;
  final String total;

  RecentEntry({required this.document, required this.recipient, required this.ingredient, required this.amount, required this.total});
  Map<String, dynamic> toJson() => {'document': document, 'recipient': recipient, 'ingredient': ingredient, 'amount': amount, 'total': total};
  factory RecentEntry.fromJson(Map<String, dynamic> json) => RecentEntry(document: json['document'] ?? '', recipient: json['recipient'] ?? '', ingredient: json['ingredient'] ?? '', amount: json['amount'] ?? '', total: json['total'] ?? '');
}

class BatchItem {
  final TextEditingController countController = TextEditingController(text: '1');
  final TextEditingController weightController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
}

// ==========================================
// ВКЛАДКА "ЗАРПЛАТА"
// ==========================================
class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});
  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  String _selectedPerson = 'alexei'; 
  bool _isLoading = false;
  bool _isSending = false;
  
  String _p1 = '0';
  String _p2 = '0';
  String _total = '0';

  final TextEditingController _dayController = TextEditingController(text: DateTime.now().day.toString());
  final TextEditingController _revController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  bool _hasTaxi = true;

  @override
  void initState() {
    super.initState();
    _fetchSalaryData();
  }

  Future<void> _fetchSalaryData() async {
    setState(() => _isLoading = true);
    try {
      final payload = jsonEncode({'action': 'get_salary_data', 'person': _selectedPerson});
      final response = await http.post(Uri.parse(_webAppUrl), headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: payload).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (data['result'] == 'success' && mounted) {
        setState(() {
          _p1 = data['p1'].toString();
          _p2 = data['p2'].toString();
          _total = data['total'].toString();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitShift() async {
    final dayText = _dayController.text.trim();
    if (dayText.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final payload = jsonEncode({
        'action': 'add_salary_shift',
        'person': _selectedPerson,
        'day': dayText,
        'revenue': _revController.text.trim(),
        'taxi': _hasTaxi ? '400' : '',
        'comment': _commentController.text.trim(),
      });
      final response = await http.post(Uri.parse(_webAppUrl), headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: payload).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      
      if (data['result'] == 'success' && mounted) {
        setState(() {
          _p1 = data['p1'].toString();
          _p2 = data['p2'].toString();
          _total = data['total'].toString();
          _revController.clear();
          _commentController.clear();
          _hasTaxi = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Смена успешно занесена в таблицу!'), backgroundColor: Colors.green));
        FocusScope.of(context).unfocus();
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Ошибка отправки.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _openTable() {
    final url = _selectedPerson == 'alexei' 
        ? 'https://docs.google.com/spreadsheets/d/1t-GWRrZ0u4u-ONqWrlCn-UqKXcSzFQSfQpf4621RB0o/edit'
        : 'https://docs.google.com/spreadsheets/d/1WbrwiagUTX2lqDQA20qm3JJNPfEnwPvQR1SLh8hVb9E/edit';
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    // Точный расчет дневщины (2000) + процент от выручки (1.8% если < 99000, иначе 1.9%)
    final double revenueVal = double.tryParse(_revController.text.replaceAll(',', '.')) ?? 0;
    const double dailyRate = 2000.0;
    final double percentRate = revenueVal < 99000 ? 0.018 : 0.019;
    final double revenueBonus = revenueVal * percentRate;
    final double totalShiftPay = dailyRate + revenueBonus;
    final String currentPercentText = revenueVal < 99000 ? '1.8%' : '1.9%';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedPerson == 'alexei' ? Colors.deepOrange : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    setState(() => _selectedPerson = 'alexei');
                    _fetchSalaryData();
                  },
                  child: const Text('АЛЕКСЕЙ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedPerson == 'denis' ? Colors.blue.shade700 : Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    setState(() => _selectedPerson = 'denis');
                    _fetchSalaryData();
                  },
                  child: const Text('ДЕНИС', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
                  : Column(
                      children: [
                        const Text('ИТОГО ЗА МЕСЯЦ', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        Text('$_total ₽', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: _selectedPerson == 'alexei' ? Colors.deepOrange : Colors.blue.shade400)),
                        const Divider(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(children: [const Text('Аванс (1-15)', style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), Text('$_p1 ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                            Column(children: [const Text('Зарплата (16-31)', style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), Text('$_p2 ₽', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                          ],
                        )
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            color: _selectedPerson == 'alexei' ? Colors.deepOrange.withOpacity(0.05) : Colors.blue.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Занести смену', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(flex: 2, child: TextField(controller: _dayController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'День (1-31)', border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3, 
                        child: TextField(
                          controller: _revController, 
                          keyboardType: TextInputType.number, 
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Выручка (₽)', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  // ИНФОРМАЦИОННАЯ СТРОКА ПОД ВЫРУЧКОЙ С РАСЧЕТОМ ДНЕВЩИНЫ И ПРОЦЕНТА
                  if (revenueVal > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Дневщина:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const Text('2000.00 ₽', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Процент ($currentPercentText):', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              Text('${revenueBonus.toStringAsFixed(2)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Итого за день:', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${totalShiftPay.toStringAsFixed(2)} ₽', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(controller: _commentController, decoration: const InputDecoration(labelText: 'Долги / Комментарий', prefixIcon: Icon(Icons.comment), border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Такси (400 ₽)'),
                    activeColor: _selectedPerson == 'alexei' ? Colors.deepOrange : Colors.blue.shade400,
                    value: _hasTaxi,
                    onChanged: (val) => setState(() => _hasTaxi = val),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPerson == 'alexei' ? Colors.deepOrange : Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isSending ? null : _submitShift,
                    child: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('ВНЕСТИ СМЕНУ В ТАБЛИЦУ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _openTable,
            icon: const Icon(Icons.open_in_new, color: Colors.grey),
            label: const Text('Открыть Google Таблицу', style: TextStyle(color: Colors.grey)),
          )
        ],
      ),
    );
  }
}

// ==========================================
// ОСНОВНОЙ ЭКРАН
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _totalSumController = TextEditingController();
  TextEditingController? _ingredientController;
  final TextEditingController _newIngredientController = TextEditingController();

  String _ingredientValue = '';
  String? _selectedDocument;
  String? _selectedRecipient;
  bool _isLoadingDirectory = true;
  bool _isAddingIngredient = false;
  bool _isOpeningSheet = false;
  bool _isDeleting = false;

  final List<RecentEntry> _cart = [];
  bool _isSendingCart = false;
  final List<RecentEntry> _recentHistory = [];
  List<RecentEntry> _archivedBatch = []; 

  List<String> _directoryList = [];

  final List<String> _documents = ['Накладная базар', 'Накладная метро', 'Порча', 'Списание персонала', 'Независимое списание', 'Перемещение в заведения', 'Перемещение Бар-Кухня/Кухня-Бар', 'Инвентаризация', 'Прочее'];
  final List<String> _recipients = ['В Бар☕', 'на Кухню🍳', 'Каракёй', 'Заготовочный цех', 'Щегол', 'Сойка to-go', 'Сойка cafe', 'Сойка Grand'];

  static const Map<String, String> _enToRuMap = {
    'q': 'й', 'w': 'ц', 'e': 'у', 'r': 'к', 't': 'е', 'y': 'н', 'u': 'г', 'i': 'ш', 'o': 'щ', 'p': 'з', '[': 'х', ']': 'ъ', 'a': 'ф', 's': 'ы', 'd': 'в', 'f': 'а', 'g': 'п', 'h': 'р', 'j': 'о', 'k': 'л', 'l': 'д', ';': 'ж', "'": 'э', 'z': 'я', 'x': 'ч', 'c': 'с', 'v': 'м', 'b': 'и', 'n': 'т', 'm': 'ь', ',': 'б', '.': 'ю', '`': 'ё',
  };

  @override
  void initState() {
    super.initState();
    _loadCachedDirectory();
    _loadArchivedBatch(); 
    _fetchDirectory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _totalSumController.dispose();
    _newIngredientController.dispose();
    super.dispose();
  }

  Future<void> _loadArchivedBatch() async {
    final prefs = await SharedPreferences.getInstance();
    final String? batchJson = prefs.getString('archived_batch');
    if (batchJson != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(batchJson);
        setState(() => _archivedBatch = decodedList.map((e) => RecentEntry.fromJson(e)).toList());
      } catch (_) {}
    }
  }

  Future<void> _loadCachedDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final dirRaw = prefs.getStringList('cached_directory') ?? [];
    if (dirRaw.isNotEmpty && _directoryList.isEmpty) {
      setState(() { _directoryList = dirRaw; _isLoadingDirectory = false; });
    }
  }

  void _openCurrentMonthSheet() {
    setState(() => _isOpeningSheet = true);
    try {
      final now = DateTime.now();
      final monthStr = now.month.toString().padLeft(2, '0');
      final fileName = 'KitchenFlow Учет 1.$monthStr.${now.year}';
      final encodedQuery = Uri.encodeComponent(fileName);
      html.window.open('https://drive.google.com/drive/search?q=$encodedQuery', '_self');
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isOpeningSheet = false);
    }
  }

  void _autoCalculateTotals() {
    final ingName = _ingredientValue.trim().toUpperCase();
    final double amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    if (amount > 0) {
      if (ingName.contains('ЛАВАШ')) _totalSumController.text = (amount * 17).toStringAsFixed(2);
      else if (ingName.contains('БАТОН')) _totalSumController.text = (amount * 70).toStringAsFixed(2);
      else if (ingName.contains('ЧИАБАТТА')) _totalSumController.text = (amount * 60).toStringAsFixed(2);
    }
  }

  Future<void> _fetchDirectory() async {
    try {
      final response = await http.get(Uri.parse(_webAppUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final Set<String> combined = {};
        for (var item in (data['ingredients'] ?? [])) { if (item != null && item.toString().isNotEmpty) combined.add(item.toString().trim()); }
        for (var item in (data['dishes'] ?? [])) { if (item != null && item.toString().isNotEmpty) combined.add(item.toString().trim()); }
        setState(() { _directoryList = combined.toList(); _isLoadingDirectory = false; });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_directory', _directoryList);
      }
    } catch (_) {
      setState(() => _isLoadingDirectory = false);
    }
  }

  String _convertEnToRu(String input) {
    final StringBuffer buffer = StringBuffer();
    final lower = input.toLowerCase();
    for (int i = 0; i < lower.length; i++) buffer.write(_enToRuMap[lower[i]] ?? lower[i]);
    return buffer.toString();
  }

  bool get _isTransfer => _selectedDocument == 'Перемещение в заведения' || _selectedDocument == 'Перемещение Бар-Кухня/Кухня-Бар';
  List<String> get _currentRecipients => _selectedDocument == 'Перемещение Бар-Кухня/Кухня-Бар' ? ['В Бар☕', 'на Кухню🍳'] : _selectedDocument == 'Перемещение в заведения' ? _recipients.where((item) => item != 'В Бар☕' && item != 'на Кухню🍳').toList() : _recipients;
  String get _recipientLabel => _selectedDocument == 'Перемещение Бар-Кухня/Кухня-Бар' ? 'Кому (Бар-Кухня/Кухня-Бар) *' : 'Кому (Цех/Склад) *';
  bool get _isSumRequired => _selectedDocument == 'Накладная базар' || _selectedDocument == 'Накладная метро' || _selectedDocument == 'Прочее';

  double get _unitPrice {
    final double amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final double total = double.tryParse(_totalSumController.text.replaceAll(',', '.')) ?? 0;
    if (amount > 0 && total > 0) return total / amount;
    return 0;
  }

  void _addToCart() {
    final ingredientText = _ingredientValue.trim();
    final amountText = _amountController.text.trim();
    final totalSumText = _totalSumController.text.trim();

    if (_selectedDocument == null || (_isTransfer && _selectedRecipient == null) || ingredientText.isEmpty || amountText.isEmpty || (_isSumRequired && totalSumText.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните все обязательные поля!'), backgroundColor: Colors.red));
      return;
    }

    final newEntry = RecentEntry(document: _selectedDocument!, recipient: _isTransfer ? _selectedRecipient! : '', ingredient: ingredientText, amount: amountText, total: _isSumRequired ? totalSumText : '');

    setState(() {
      _cart.add(newEntry);
      _amountController.clear();
      _totalSumController.clear();
      _ingredientValue = '';
      _ingredientController?.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🛒 Добавлено в корзину: ${newEntry.ingredient}'), backgroundColor: Colors.blue.shade700, duration: const Duration(seconds: 1)));
  }

  Future<void> _sendCartToServer(StateSetter setModalState) async {
    int sentCount = 0;
    List<RecentEntry> itemsToSend = List.from(_cart);
    List<RecentEntry> successfullySent = []; 

    for (var entry in itemsToSend) {
      String txId = DateTime.now().millisecondsSinceEpoch.toString() + sentCount.toString();
      try {
        final payload = jsonEncode({'document': entry.document, 'recipient': entry.recipient, 'ingredient': entry.ingredient, 'amount': entry.amount, 'unit': '', 'total': entry.total, 'transactionId': txId});
        final response = await http.post(Uri.parse(_webAppUrl), headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: payload).timeout(const Duration(seconds: 15));
        if (response.statusCode < 400) {
          setState(() { _recentHistory.insert(0, entry); _cart.remove(entry); });
          successfullySent.add(entry);
          setModalState(() {});
          sentCount++;
        } else throw Exception();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Ошибка на "${entry.ingredient}". Отправка прервана.'), backgroundColor: Colors.red));
        break; 
      }
    }

    if (successfullySent.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('archived_batch', jsonEncode(successfullySent.map((e) => e.toJson()).toList()));
      setState(() => _archivedBatch = successfullySent);
    }

    if (mounted && sentCount > 0) {
      Navigator.of(context).pop(); 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Успешно отправлено позиций: $sentCount'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
    }
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('🛒 Корзина на отправку', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
                  const Divider(),
                  if (_cart.isEmpty) const Padding(padding: EdgeInsets.all(32.0), child: Center(child: Text('Корзина пуста', style: TextStyle(color: Colors.grey))))
                  else ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        return Card(
                          elevation: 0, color: Colors.grey.shade800, margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('${index + 1}. ${item.ingredient}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${item.document} | ${item.amount} ед. ${item.total.isNotEmpty ? "(${item.total} ₽)" : ""}'),
                            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _isSendingCart ? null : () { setState(() => _cart.removeAt(index)); setModalState(() {}); }),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: (_cart.isEmpty || _isSendingCart) ? null : () async { setModalState(() => _isSendingCart = true); await _sendCartToServer(setModalState); setModalState(() => _isSendingCart = false); },
                    icon: _isSendingCart ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload),
                    label: Text(_isSendingCart ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ ВСЕ'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBatchCalculator() {
    final List<BatchItem> batches = [BatchItem()];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Theme.of(context).scaffoldBackgroundColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              double totalWeight = 0; double totalPrice = 0;
              for (var b in batches) {
                final count = double.tryParse(b.countController.text.replaceAll(',', '.')) ?? 0;
                final weight = double.tryParse(b.weightController.text.replaceAll(',', '.')) ?? 0;
                final price = double.tryParse(b.priceController.text.replaceAll(',', '.')) ?? 0;
                totalWeight += count * weight; totalPrice += count * price;
              }
              return Padding(
                padding: EdgeInsets.only(top: 20, left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('🧮 Фасовки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))]),
                      const SizedBox(height: 12),
                      ...batches.asMap().entries.map((entry) {
                        final index = entry.key; final item = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: TextField(controller: item.countController, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'Шт', border: OutlineInputBorder(), isDense: true), onChanged: (_) => setModalState(() {}))), const SizedBox(width: 6),
                              Expanded(flex: 3, child: TextField(controller: item.weightController, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'Вес (кг)', border: OutlineInputBorder(), isDense: true), onChanged: (_) => setModalState(() {}))),
                              if (_isSumRequired) ...[ const SizedBox(width: 6), Expanded(flex: 3, child: TextField(controller: item.priceController, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'Цена (₽)', border: OutlineInputBorder(), isDense: true), onChanged: (_) => setModalState(() {}))), ],
                              IconButton(icon: const Icon(Icons.remove_circle, color: Colors.redAccent), onPressed: batches.length > 1 ? () => setModalState(() => batches.removeAt(index)) : null),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(onPressed: () => setModalState(() => batches.add(BatchItem())), icon: const Icon(Icons.add), label: const Text('Добавить строку')),
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(8)),
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Итого вес:'), Text('${totalWeight.toStringAsFixed(3).replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "")} кг', style: const TextStyle(fontWeight: FontWeight.bold))]),
                          if (_isSumRequired) ...[ const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Итого сумма:'), Text('${totalPrice.toStringAsFixed(2)} ₽', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]), ],
                        ]),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () { setState(() { if (totalWeight > 0) _amountController.text = totalWeight.toStringAsFixed(3).replaceAll(RegExp(r"([.]*0)(?!.*\d)"), ""); if (_isSumRequired && totalPrice > 0) _totalSumController.text = totalPrice.toStringAsFixed(2); _autoCalculateTotals(); }); Navigator.pop(ctx); },
                        child: const Text('ПРИМЕНИТЬ', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _addNewIngredient() async {
    final newIngName = _newIngredientController.text.trim();
    if (newIngName.isEmpty) return;
    setState(() => _isAddingIngredient = true);
    try {
      final payload = jsonEncode({'action': 'add_ingredient', 'ingredient': newIngName});
      await http.post(Uri.parse(_webAppUrl), headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: payload).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (!_directoryList.contains(newIngName)) {
        _directoryList.add(newIngName);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_directory', _directoryList);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ "$newIngName" добавлен!'), backgroundColor: Colors.green));
      _newIngredientController.clear();
      FocusScope.of(context).unfocus();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isAddingIngredient = false);
    }
  }

  Future<void> _deleteLastEntry(RecentEntry entry) async {
    setState(() => _isDeleting = true);
    try {
      final payload = jsonEncode({'action': 'delete_last', 'document': entry.document, 'recipient': entry.recipient, 'ingredient': entry.ingredient, 'amount': entry.amount, 'total': entry.total});
      await http.post(Uri.parse(_webAppUrl), headers: {'Content-Type': 'text/plain;charset=utf-8'}, body: payload).timeout(const Duration(seconds: 15));
    } catch (_) {
    } finally {
      if (mounted) { setState(() { _recentHistory.remove(entry); _isDeleting = false; }); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🗑️ Удалено: ${entry.ingredient}'), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 2))); }
    }
  }

  Color _getChefColor(String? name) {
    if (name == null) return Colors.grey.shade800;
    switch (name) {
      case 'Алексей': return Colors.red;
      case 'Денис': return Colors.blue.shade300;
      case 'Данил': return Colors.green.shade400;
      case 'Газиз': return Colors.white;
      case 'Гена': return Colors.orange;
      default: return Colors.white70;
    }
  }

  Widget _buildScheduleMonthCard(DateTime monthDate) {
    final int daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    const List<String> monthNames = ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    String monthTitle = '${monthNames[monthDate.month]} ${monthDate.year}';
    final DateTime anchor = DateTime.utc(2026, 8, 1);
    final List<Map<String, String?>> cycle = [
      {'alexei': null, 'denis': 'Денис'}, {'alexei': null, 'denis': 'Газиз'}, {'alexei': 'Данил', 'denis': null}, {'alexei': 'Денис', 'denis': null},
      {'alexei': null, 'denis': 'Гена'}, {'alexei': null, 'denis': 'Газиз'}, {'alexei': 'Данил', 'denis': null}, {'alexei': 'Алексей', 'denis': null},
      {'alexei': null, 'denis': 'Гена'}, {'alexei': null, 'denis': 'Денис'}, {'alexei': 'Алексей', 'denis': null}, {'alexei': 'Денис', 'denis': null},
    ];

    List<Widget> rows = [];
    rows.add(Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Row(children: [
      const SizedBox(width: 40, child: Text('Дата', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey), textAlign: TextAlign.center)),
      const Expanded(child: Text('СМЕНА Алексея', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
      const Expanded(child: Text('СМЕНА Дениса', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
    ])));
    rows.add(const Divider(height: 1, thickness: 1));

    for (int i = 1; i <= daysInMonth; i++) {
      DateTime currentDay = DateTime.utc(monthDate.year, monthDate.month, i);
      int cycleIndex = (currentDay.difference(anchor).inDays % 12);
      if (cycleIndex < 0) cycleIndex += 12;
      var shift = cycle[cycleIndex];
      bool isWeekend = currentDay.weekday == 6 || currentDay.weekday == 7;

      rows.add(
        Container(
          color: i % 2 == 0 ? Colors.grey.shade900 : Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(children: [
            SizedBox(width: 40, child: Text(i.toString(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isWeekend ? Colors.red.shade400 : Colors.deepOrange), textAlign: TextAlign.center)),
            Expanded(child: Text(shift['alexei'] ?? '-', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: shift['alexei'] != null ? FontWeight.bold : FontWeight.normal, color: _getChefColor(shift['alexei'])))),
            Expanded(child: Text(shift['denis'] ?? '-', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: shift['denis'] != null ? FontWeight.bold : FontWeight.normal, color: _getChefColor(shift['denis'])))),
          ]),
        ),
      );
    }
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(monthTitle.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange), textAlign: TextAlign.center), const SizedBox(height: 16), ...rows])));
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime currentMonth = DateTime(now.year, now.month, 1);
    DateTime nextMonth = DateTime(now.year, now.month + 1, 1);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('KitchenFlow', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'Ввод данных'),
              Tab(icon: Icon(Icons.add_box), text: 'Ингредиент'),
              Tab(icon: Text('💸', style: TextStyle(fontSize: 24)), text: 'Зарплата'), 
              Tab(icon: Icon(Icons.restaurant), text: 'Питание'),
              Tab(icon: Icon(Icons.info_outline), text: 'О программе'),
            ],
          ),
        ),
        floatingActionButton: _cart.isNotEmpty
            ? FloatingActionButton.extended(onPressed: _showCartBottomSheet, backgroundColor: Colors.green, foregroundColor: Colors.white, icon: const Icon(Icons.shopping_cart_checkout), label: Text('Корзина (${_cart.length})', style: const TextStyle(fontWeight: FontWeight.bold)))
            : null,
        body: TabBarView(
          children: [
            // 1. ВВОД ДАННЫХ
            SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(isExpanded: true, value: _selectedDocument, decoration: const InputDecoration(labelText: 'Документ *', prefixIcon: Icon(Icons.description), border: OutlineInputBorder()), items: _documents.map((doc) => DropdownMenuItem(value: doc, child: Text(doc, overflow: TextOverflow.ellipsis))).toList(), onChanged: (val) { setState(() { _selectedDocument = val; if (_isTransfer && !_currentRecipients.contains(_selectedRecipient)) _selectedRecipient = null; else if (!_isTransfer) _selectedRecipient = null; }); }),
                          if (_isTransfer) ...[ const SizedBox(height: 12), DropdownButtonFormField<String>(isExpanded: true, value: _selectedRecipient, decoration: InputDecoration(labelText: _recipientLabel, prefixIcon: const Icon(Icons.store), border: const OutlineInputBorder()), items: _currentRecipients.map((rec) => DropdownMenuItem(value: rec, child: Text(rec, overflow: TextOverflow.ellipsis))).toList(), onChanged: (val) => setState(() => _selectedRecipient = val)) ],
                          const SizedBox(height: 12),
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              final query = textEditingValue.text.trim();
                              if (query.isEmpty) return const Iterable<String>.empty();
                              final ruQuery = _convertEnToRu(query);
                              return _directoryList.where((option) { final lowerOption = option.toLowerCase(); return lowerOption.contains(query.toLowerCase()) || lowerOption.contains(ruQuery.toLowerCase()); });
                            },
                            onSelected: (String selection) { _ingredientValue = selection; _autoCalculateTotals(); },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              _ingredientController = controller;
                              return TextField(controller: controller, focusNode: focusNode, onChanged: (val) { _ingredientValue = val; _autoCalculateTotals(); }, decoration: InputDecoration(labelText: 'Наименование (Ингредиент) *', prefixIcon: const Icon(Icons.restaurant_menu), border: const OutlineInputBorder(), suffixIcon: _isLoadingDirectory ? const SizedBox(width: 16, height: 16, child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))) : null));
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: TextField(controller: _amountController, keyboardType: TextInputType.text, onChanged: (_) { _autoCalculateTotals(); setState(() {}); }, decoration: const InputDecoration(labelText: 'Количество *', prefixIcon: Icon(Icons.scale), border: OutlineInputBorder()))),
                              const SizedBox(width: 8),
                              SizedBox(height: 56, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.withOpacity(0.2), foregroundColor: Colors.deepOrange, elevation: 0, side: const BorderSide(color: Colors.deepOrange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))), onPressed: _showBatchCalculator, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calculate, size: 20), Text('Партии', style: TextStyle(fontSize: 11))]))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Быстро: ', style: TextStyle(color: Colors.grey)),
                              Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Wrap(spacing: 6, children: ['+ 0,05', '+ 0,1', '+ 0,2', '+ 0,25', '+ 0,5'].map((preset) { return ActionChip(label: Text(preset, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)), backgroundColor: Colors.deepOrange.withOpacity(0.1), side: BorderSide(color: Colors.deepOrange.withOpacity(0.3)), onPressed: () { final valString = preset.replaceAll('+ ', '').replaceAll(',', '.'); final double addValue = double.tryParse(valString) ?? 0; final String currentText = _amountController.text.replaceAll(',', '.'); final double currentValue = double.tryParse(currentText) ?? 0; final double newValue = currentValue + addValue; setState(() { _amountController.text = newValue.toStringAsFixed(3).replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "").replaceAll('.', ','); _autoCalculateTotals(); }); }); }).toList()))),
                            ],
                          ),
                          if (_isSumRequired) ...[
                            const SizedBox(height: 12),
                            TextField(controller: _totalSumController, keyboardType: TextInputType.text, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Общая сумма (₽) *', prefixIcon: Icon(Icons.currency_ruble), border: OutlineInputBorder())),
                            if (_unitPrice > 0) ...[ const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('Себестоимость: ${_unitPrice.toStringAsFixed(2)} ₽ / ед.', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))) ],
                          ],
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _addToCart, icon: const Icon(Icons.add_shopping_cart), label: const Text('ДОБАВИТЬ В КОРЗИНУ'))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('История текущей сессии', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (_recentHistory.isEmpty) const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text('Пусто', style: TextStyle(color: Colors.grey))))
                  else ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _recentHistory.length, itemBuilder: (context, index) { final entry = _recentHistory[index]; return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: const Icon(Icons.cloud_done, color: Colors.green), title: Text(entry.ingredient.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${entry.document}${entry.recipient.isNotEmpty ? " -> ${entry.recipient}" : ""} | ${entry.amount} ед.'), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _isDeleting ? null : () => _deleteLastEntry(entry)))); }),
                ],
              ),
            ),

            // 2. ИНГРЕДИЕНТ
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(elevation: 2, color: Colors.deepOrange.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Icon(Icons.table_chart, color: Colors.deepOrange), const SizedBox(width: 8), const Text('Таблица учета месяца', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange))]), const SizedBox(height: 12), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), onPressed: _isOpeningSheet ? null : _openCurrentMonthSheet, icon: _isOpeningSheet ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.open_in_new, size: 18), label: Text(_isOpeningSheet ? 'ЗАГРУЗКА...' : 'ОТКРЫТЬ ТАБЛИЦУ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))]))),
                  const SizedBox(height: 16),
                  Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Пополнение справочника', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)), const SizedBox(height: 16), TextField(controller: _newIngredientController, decoration: const InputDecoration(labelText: 'Новый ингредиент *', prefixIcon: Icon(Icons.post_add), border: OutlineInputBorder())), const SizedBox(height: 20), SizedBox(height: 48, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: _isAddingIngredient ? null : _addNewIngredient, icon: const Icon(Icons.add_circle_outline), label: Text(_isAddingIngredient ? 'СОХРАНЕНИЕ...' : 'ДОБАВИТЬ В БАЗУ')))]))),
                  const SizedBox(height: 24),
                  const Text('Архив последней отправки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (_archivedBatch.isEmpty) Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: const Padding(padding: EdgeInsets.all(24.0), child: Center(child: Text('Сохраненных отправок пока нет', style: TextStyle(color: Colors.grey)))))
                  else Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _archivedBatch.length, separatorBuilder: (context, index) => const Divider(height: 1), itemBuilder: (context, index) { final item = _archivedBatch[index]; return ListTile(leading: const Icon(Icons.history, color: Colors.deepOrange), title: Text('${index + 1}. ${item.ingredient.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text('${item.document} | ${item.amount} ед. ${item.total.isNotEmpty ? "(${item.total} ₽)" : ""}', style: const TextStyle(fontSize: 12))); })),
                ],
              ),
            ),
            
            // 3. ЗАРПЛАТА 
            const SalaryScreen(),

            // 4. ПИТАНИЕ
            SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Column(children: [_buildScheduleMonthCard(currentMonth), const SizedBox(height: 16), _buildScheduleMonthCard(nextMonth)])),

            // 5. О ПРОГРАММЕ
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.eco, size: 64, color: Colors.green.shade400)),
                      const SizedBox(height: 16),
                      const Text('KitchenFlow', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      const SizedBox(height: 4),
                      const Text('Версия 1.8.1', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                      const Divider(height: 32, thickness: 1),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Что нового:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 8),
                            Text('1. Добавлена новая вкладка "Зарплата" для учета смен.', style: TextStyle(fontSize: 13)),
                            Text('2. Убрана интеграция QR, оставлена полностью темная тема.', style: TextStyle(fontSize: 13)),
                            Text('3. Цены (Лаваш 17, Батон 70, Чиабатта 60).', style: TextStyle(fontSize: 13)),
                            Text('4. Архив корзины перенесен на вкладку Ингредиент.', style: TextStyle(fontSize: 13)),
                            Text('5. Добавлены эмодзи в названия и получателей.', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      const Divider(height: 32, thickness: 1),
                      const ListTile(leading: Icon(Icons.restaurant, color: Colors.deepOrange), title: Text('Организация'), subtitle: Text('Кафе «Розмарин»', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}