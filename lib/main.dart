import 'dart:convert';
import 'dart:html' as html; // Подключили нативный браузерный API
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _webAppUrl =
    'https://script.google.com/macros/s/AKfycbzckgYZ43WMDpfIx1Sl_uZ6QbMxe9C-6vuo9NBKbsMLshgHTwTdzdt-Y8WKRji-tECQ/exec';

void main() {
  runApp(const KitchenFlowApp());
}

class KitchenFlowApp extends StatelessWidget {
  const KitchenFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KitchenFlow',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFF2F4F8),
      ),
      home: const HomeScreen(),
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

  RecentEntry({
    required this.document,
    required this.recipient,
    required this.ingredient,
    required this.amount,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
    'document': document,
    'recipient': recipient,
    'ingredient': ingredient,
    'amount': amount,
    'total': total,
  };

  factory RecentEntry.fromJson(Map<String, dynamic> json) => RecentEntry(
    document: json['document'] ?? '',
    recipient: json['recipient'] ?? '',
    ingredient: json['ingredient'] ?? '',
    amount: json['amount'] ?? '',
    total: json['total'] ?? '',
  );
}

class BatchItem {
  final TextEditingController countController = TextEditingController(
    text: '1',
  );
  final TextEditingController weightController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  void dispose() {
    countController.dispose();
    weightController.dispose();
    priceController.dispose();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _totalSumController = TextEditingController();
  TextEditingController? _ingredientController;
  final TextEditingController _newIngredientController =
      TextEditingController();

  String _ingredientValue = '';
  String? _selectedDocument;
  String? _selectedRecipient;
  bool _isLoading = false;
  bool _isAddingIngredient = false;
  bool _isLoadingDirectory = true;
  bool _isOpeningSheet = false;

  // Переменные для защиты от дубликатов
  String? _lastAttemptHash;
  String? _lastTransactionId;

  final List<RecentEntry> _recentHistory = [];
  List<String> _directoryList = [];

  // --- ВОТ ЗДЕСЬ ДОБАВЛЕНО СПИСАНИЕ ПЕРСОНАЛА И ПРОЧЕЕ ---
  final List<String> _documents = [
    'Накладная базар',
    'Накладная метро',
    'Порча',
    'Списание персонала',
    'Независимое списание',
    'Перемещение в заведения',
    'Перемещение Бар-Кухня/Кухня-Бар',
    'Инвентаризация',
    'Прочее',
  ];

  final List<String> _recipients = [
    'Бар',
    'Кухня',
    'Каракёй',
    'Заготовочный цех',
    'Щегол',
    'Сойка to-go',
    'Сойка cafe',
    'Сойка Grand',
  ];

  static const Map<String, String> _enToRuMap = {
    'q': 'й',
    'w': 'ц',
    'e': 'у',
    'r': 'к',
    't': 'е',
    'y': 'н',
    'u': 'г',
    'i': 'ш',
    'o': 'щ',
    'p': 'з',
    '[': 'х',
    ']': 'ъ',
    'a': 'ф',
    's': 'ы',
    'd': 'в',
    'f': 'а',
    'g': 'п',
    'h': 'р',
    'j': 'о',
    'k': 'л',
    'l': 'д',
    ';': 'ж',
    "'": 'э',
    'z': 'я',
    'x': 'ч',
    'c': 'с',
    'v': 'м',
    'b': 'и',
    'n': 'т',
    'm': 'ь',
    ',': 'б',
    '.': 'ю',
    '`': 'ё',
  };

  @override
  void initState() {
    super.initState();
    _loadCachedDirectory();
    _fetchDirectory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _totalSumController.dispose();
    _newIngredientController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final dirRaw = prefs.getStringList('cached_directory') ?? [];
    if (dirRaw.isNotEmpty && _directoryList.isEmpty) {
      setState(() {
        _directoryList = dirRaw;
        _isLoadingDirectory = false;
      });
    }
  }

  // --- ИСПРАВЛЕНИЕ: НАТИВНОЕ ОТКРЫТИЕ ССЫЛКИ ---
  void _openCurrentMonthSheet() {
    setState(() {
      _isOpeningSheet = true;
    });

    try {
      final now = DateTime.now();
      final monthStr = now.month.toString().padLeft(2, '0');
      final fileName = 'KitchenFlow Учет 1.$monthStr.${now.year}';

      final encodedQuery = Uri.encodeComponent(fileName);
      final String searchUrl =
          'https://drive.google.com/drive/search?q=$encodedQuery';

      // _self предотвращает блокировку всплывающих окон мобильным браузером
      html.window.open(searchUrl, '_self');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Не удалось открыть таблицу текущего месяца'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningSheet = false;
        });
      }
    }
  }

  void _autoCalculateTotalIfLavash() {
    final ingName = _ingredientValue.trim().toUpperCase();
    if (ingName.contains('ЛАВАШ')) {
      final double amount =
          double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
      if (amount > 0) {
        final double calculatedTotal = amount * 15;
        _totalSumController.text = calculatedTotal.toStringAsFixed(2);
      }
    }
  }

  Future<void> _fetchDirectory() async {
    try {
      final response = await http
          .get(Uri.parse(_webAppUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> ingredients = data['ingredients'] ?? [];
        final List<dynamic> dishes = data['dishes'] ?? [];

        final Set<String> combined = {};
        for (var item in ingredients) {
          if (item != null && item.toString().isNotEmpty) {
            combined.add(item.toString().trim());
          }
        }
        for (var item in dishes) {
          if (item != null && item.toString().isNotEmpty) {
            combined.add(item.toString().trim());
          }
        }

        final list = combined.toList();
        setState(() {
          _directoryList = list;
          _isLoadingDirectory = false;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_directory', list);
      }
    } catch (_) {
      setState(() {
        _isLoadingDirectory = false;
      });
    }
  }

  String _convertEnToRu(String input) {
    final StringBuffer buffer = StringBuffer();
    final lower = input.toLowerCase();
    for (int i = 0; i < lower.length; i++) {
      final char = lower[i];
      buffer.write(_enToRuMap[char] ?? char);
    }
    return buffer.toString();
  }

  bool get _isTransfer =>
      _selectedDocument == 'Перемещение в заведения' ||
      _selectedDocument == 'Перемещение Бар-Кухня/Кухня-Бар';

  List<String> get _currentRecipients {
    if (_selectedDocument == 'Перемещение Бар-Кухня/Кухня-Бар') {
      return ['Бар', 'Кухня'];
    }
    if (_selectedDocument == 'Перемещение в заведения') {
      return _recipients
          .where((item) => item != 'Бар' && item != 'Кухня')
          .toList();
    }
    return _recipients;
  }

  String get _recipientLabel =>
      _selectedDocument == 'Перемещение Бар-Кухня/Кухня-Бар'
      ? 'Кому (Бар-Кухня/Кухня-Бар) *'
      : 'Кому (Цех/Склад) *';

  bool get _isSumRequired =>
      _selectedDocument == 'Накладная базар' ||
      _selectedDocument == 'Накладная метро' ||
      _selectedDocument == 'Прочее';

  double get _unitPrice {
    final double amount =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final double total =
        double.tryParse(_totalSumController.text.replaceAll(',', '.')) ?? 0;
    if (amount > 0 && total > 0) return total / amount;
    return 0;
  }

  void _showBatchCalculator() {
    final List<BatchItem> batches = [BatchItem()];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double totalWeight = 0;
            double totalPrice = 0;

            for (var b in batches) {
              final count =
                  double.tryParse(
                    b.countController.text.replaceAll(',', '.'),
                  ) ??
                  0;
              final weight =
                  double.tryParse(
                    b.weightController.text.replaceAll(',', '.'),
                  ) ??
                  0;
              final price =
                  double.tryParse(
                    b.priceController.text.replaceAll(',', '.'),
                  ) ??
                  0;
              totalWeight += count * weight;
              totalPrice += count * price;
            }

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🧮 Калькулятор партий / фасовок',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Text(
                      'Укажите количество упаковок, вес 1 шт и стоимость за штуку:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ...batches.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: item.countController,
                                keyboardType: TextInputType.text,
                                decoration: const InputDecoration(
                                  labelText: 'Кол-во (шт)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: item.weightController,
                                keyboardType: TextInputType.text,
                                decoration: const InputDecoration(
                                  labelText: 'Вес 1 шт (кг)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            if (_isSumRequired) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: item.priceController,
                                  keyboardType: TextInputType.text,
                                  decoration: const InputDecoration(
                                    labelText: 'Цена 1 шт (₽)',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  onChanged: (_) => setModalState(() {}),
                                ),
                              ),
                            ],
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.redAccent,
                              ),
                              onPressed: batches.length > 1
                                  ? () {
                                      setModalState(() {
                                        batches.removeAt(index);
                                      });
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () {
                        setModalState(() {
                          batches.add(BatchItem());
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить строку фасовки'),
                    ),
                    const Divider(),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Итоговый объем/вес:'),
                              Text(
                                '${totalWeight.toStringAsFixed(3).replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "")} кг/ед',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_isSumRequired) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Итоговая сумма:'),
                                Text(
                                  '${totalPrice.toStringAsFixed(2)} ₽',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          if (totalWeight > 0) {
                            _amountController.text = totalWeight
                                .toStringAsFixed(3)
                                .replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");
                          }
                          if (_isSumRequired && totalPrice > 0) {
                            _totalSumController.text = totalPrice
                                .toStringAsFixed(2);
                          }
                          _autoCalculateTotalIfLavash();
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'ПРИМЕНИТЬ В ФОРМУ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addNewIngredient() async {
    final newIngName = _newIngredientController.text.trim();
    if (newIngName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите наименование ингредиента!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAddingIngredient = true;
    });

    try {
      final payload = jsonEncode({
        'action': 'add_ingredient',
        'ingredient': newIngName,
      });
      await http
          .post(
            Uri.parse(_webAppUrl),
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: payload,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (!_directoryList.contains(newIngName)) {
        _directoryList.add(newIngName);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('cached_directory', _directoryList);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Ингредиент "$newIngName" успешно добавлен в справочник!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      _newIngredientController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ Ошибка связи. Проверьте интернет и попробуйте снова.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingIngredient = false;
        });
      }
    }
  }

  Future<void> _sendData() async {
    if (_isLoading) return;

    final ingredientText = _ingredientValue.trim();
    final amountText = _amountController.text.trim();
    final totalSumText = _totalSumController.text.trim();

    if (_selectedDocument == null ||
        (_isTransfer && _selectedRecipient == null) ||
        ingredientText.isEmpty ||
        amountText.isEmpty ||
        (_isSumRequired && totalSumText.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все обязательные поля!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Защита от дубликатов: ключ создается заново только при изменении формы
    String currentHash =
        "$_selectedDocument|$_selectedRecipient|$ingredientText|$amountText|$totalSumText";
    String txId;
    if (currentHash == _lastAttemptHash && _lastTransactionId != null) {
      txId = _lastTransactionId!;
    } else {
      txId = DateTime.now().millisecondsSinceEpoch.toString();
      _lastAttemptHash = currentHash;
      _lastTransactionId = txId;
    }

    final newEntry = RecentEntry(
      document: _selectedDocument!,
      recipient: _isTransfer ? _selectedRecipient! : '',
      ingredient: ingredientText,
      amount: amountText,
      total: _isSumRequired ? totalSumText : '',
    );

    try {
      final payload = jsonEncode({
        'document': newEntry.document,
        'recipient': newEntry.recipient,
        'ingredient': newEntry.ingredient,
        'amount': newEntry.amount,
        'unit': '',
        'total': newEntry.total,
        'transactionId': txId,
      });

      // Увеличенный таймаут до 15 секунд для медленного интернета
      final response = await http
          .post(
            Uri.parse(_webAppUrl),
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: payload,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode < 400) {
        _recentHistory.insert(0, newEntry);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Отправлено: $ingredientText ($amountText)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // Сбрасываем форму и ключи только при 100% успехе
        _amountController.clear();
        _totalSumController.clear();
        _ingredientValue = '';
        _ingredientController?.clear();
        _lastAttemptHash = null;
        _lastTransactionId = null;
      } else {
        throw Exception('Server error');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ Нет связи! Данные НЕ отправлены. Нажмите «Отправить» еще раз.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteLastEntry(RecentEntry entry) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final payload = jsonEncode({
        'action': 'delete_last',
        'document': entry.document,
        'recipient': entry.recipient,
        'ingredient': entry.ingredient,
        'amount': entry.amount,
        'total': entry.total,
      });
      await http
          .post(
            Uri.parse(_webAppUrl),
            headers: {'Content-Type': 'text/plain;charset=utf-8'},
            body: payload,
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _recentHistory.remove(entry);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Удалено: ${entry.ingredient}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Color _getChefColor(String? name) {
    if (name == null) return Colors.grey.shade300;
    switch (name) {
      case 'Алексей':
        return Colors.red;
      case 'Денис':
        return Colors.orange;
      case 'Данил':
        return Colors.green.shade800;
      case 'Газиз':
        return Colors.black;
      case 'Гена':
        return Colors.blue.shade900;
      default:
        return Colors.black87;
    }
  }

  Widget _buildScheduleMonthCard(DateTime monthDate) {
    final int daysInMonth = DateTime(
      monthDate.year,
      monthDate.month + 1,
      0,
    ).day;
    const List<String> monthNames = [
      '',
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    String monthTitle = '${monthNames[monthDate.month]} ${monthDate.year}';

    final DateTime anchor = DateTime.utc(2026, 8, 1);

    final List<Map<String, String?>> cycle = [
      {'alexei': null, 'denis': 'Денис'},
      {'alexei': null, 'denis': 'Газиз'},
      {'alexei': 'Данил', 'denis': null},
      {'alexei': 'Денис', 'denis': null},
      {'alexei': null, 'denis': 'Гена'},
      {'alexei': null, 'denis': 'Газиз'},
      {'alexei': 'Данил', 'denis': null},
      {'alexei': 'Алексей', 'denis': null},
      {'alexei': null, 'denis': 'Гена'},
      {'alexei': null, 'denis': 'Денис'},
      {'alexei': 'Алексей', 'denis': null},
      {'alexei': 'Денис', 'denis': null},
    ];

    List<Widget> rows = [];

    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: const [
            SizedBox(
              width: 40,
              child: Text(
                'Дата',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Text(
                'СМЕНА Алексея',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
            Expanded(
              child: Text(
                'СМЕНА Дениса',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    rows.add(const Divider(height: 1, thickness: 1));

    for (int i = 1; i <= daysInMonth; i++) {
      DateTime currentDay = DateTime.utc(monthDate.year, monthDate.month, i);
      int difference = currentDay.difference(anchor).inDays;
      int cycleIndex = difference % 12;
      if (cycleIndex < 0) cycleIndex += 12;

      var shift = cycle[cycleIndex];
      bool isWeekend = currentDay.weekday == 6 || currentDay.weekday == 7;

      rows.add(
        Container(
          color: i % 2 == 0 ? Colors.grey.shade50 : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  i.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isWeekend ? Colors.red.shade400 : Colors.deepOrange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  shift['alexei'] ?? '-',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: shift['alexei'] != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _getChefColor(shift['alexei']),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  shift['denis'] ?? '-',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: shift['denis'] != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _getChefColor(shift['denis']),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              monthTitle.toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ...rows,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime currentMonth = DateTime(now.year, now.month, 1);
    DateTime nextMonth = DateTime(now.year, now.month + 1, 1);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'KitchenFlow',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.deepOrange,
          elevation: 0,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'Ввод данных'),
              Tab(icon: Icon(Icons.add_box), text: 'Ингредиент'),
              Tab(icon: Icon(Icons.restaurant), text: 'Питание'),
              Tab(icon: Icon(Icons.info_outline), text: 'О программе'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedDocument,
                            decoration: const InputDecoration(
                              labelText: 'Документ *',
                              prefixIcon: Icon(Icons.description),
                              border: OutlineInputBorder(),
                            ),
                            items: _documents
                                .map(
                                  (doc) => DropdownMenuItem(
                                    value: doc,
                                    child: Text(
                                      doc,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDocument = val;
                                if (_isTransfer &&
                                    !_currentRecipients.contains(
                                      _selectedRecipient,
                                    )) {
                                  _selectedRecipient = null;
                                } else if (!_isTransfer) {
                                  _selectedRecipient = null;
                                }
                              });
                            },
                          ),
                          if (_isTransfer) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _selectedRecipient,
                              decoration: InputDecoration(
                                labelText: _recipientLabel,
                                prefixIcon: const Icon(Icons.store),
                                border: const OutlineInputBorder(),
                              ),
                              items: _currentRecipients
                                  .map(
                                    (rec) => DropdownMenuItem(
                                      value: rec,
                                      child: Text(
                                        rec,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedRecipient = val),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  final query = textEditingValue.text.trim();
                                  if (query.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  final ruQuery = _convertEnToRu(query);
                                  return _directoryList.where((String option) {
                                    final lowerOption = option.toLowerCase();
                                    return lowerOption.contains(
                                          query.toLowerCase(),
                                        ) ||
                                        lowerOption.contains(
                                          ruQuery.toLowerCase(),
                                        );
                                  });
                                },
                            onSelected: (String selection) {
                              _ingredientValue = selection;
                              _autoCalculateTotalIfLavash();
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  _ingredientController = controller;
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    onChanged: (val) {
                                      _ingredientValue = val;
                                      _autoCalculateTotalIfLavash();
                                    },
                                    decoration: InputDecoration(
                                      labelText:
                                          'Наименование (Ингредиент / Блюдо) *',
                                      prefixIcon: const Icon(
                                        Icons.restaurant_menu,
                                      ),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: _isLoadingDirectory
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: Padding(
                                                padding: EdgeInsets.all(12.0),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.text,
                                  onChanged: (_) {
                                    _autoCalculateTotalIfLavash();
                                    setState(() {});
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Количество *',
                                    prefixIcon: Icon(Icons.scale),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange.shade50,
                                    foregroundColor: Colors.deepOrange,
                                    elevation: 0,
                                    side: const BorderSide(
                                      color: Colors.deepOrange,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  onPressed: _showBatchCalculator,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calculate, size: 20),
                                      Text(
                                        'Партии',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text(
                                'Быстро: ',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Wrap(
                                    spacing: 6,
                                    children:
                                        [
                                          '+ 0,05',
                                          '+ 0,1',
                                          '+ 0,2',
                                          '+ 0,25',
                                          '+ 0,5',
                                        ].map((preset) {
                                          return ActionChip(
                                            label: Text(
                                              preset,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.deepOrange,
                                              ),
                                            ),
                                            backgroundColor:
                                                Colors.deepOrange.shade50,
                                            side: BorderSide(
                                              color: Colors.deepOrange.shade200,
                                            ),
                                            onPressed: () {
                                              final valString = preset
                                                  .replaceAll('+ ', '')
                                                  .replaceAll(',', '.');
                                              final double addValue =
                                                  double.tryParse(valString) ??
                                                  0;

                                              final String currentText =
                                                  _amountController.text
                                                      .replaceAll(',', '.');
                                              final double currentValue =
                                                  double.tryParse(
                                                    currentText,
                                                  ) ??
                                                  0;

                                              final double newValue =
                                                  currentValue + addValue;

                                              setState(() {
                                                _amountController.text =
                                                    newValue
                                                        .toStringAsFixed(3)
                                                        .replaceAll(
                                                          RegExp(
                                                            r"([.]*0)(?!.*\d)",
                                                          ),
                                                          "",
                                                        )
                                                        .replaceAll('.', ',');
                                                _autoCalculateTotalIfLavash();
                                              });
                                            },
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isSumRequired) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _totalSumController,
                              keyboardType: TextInputType.text,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Общая сумма из накладной (₽) *',
                                prefixIcon: Icon(Icons.currency_ruble),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (_unitPrice > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Себестоимость: ${_unitPrice.toStringAsFixed(2)} ₽ / ед.',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isLoading ? null : _sendData,
                              icon: const Icon(Icons.send),
                              label: Text(
                                _isLoading ? 'ОТПРАВКА...' : 'ОТПРАВИТЬ',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'История текущей сессии',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_recentHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Записи пока отсутствуют',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentHistory.length,
                      itemBuilder: (context, index) {
                        final entry = _recentHistory[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.cloud_done,
                              color: Colors.green,
                            ),
                            title: Text(
                              entry.ingredient.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${entry.document}${entry.recipient.isNotEmpty ? " -> ${entry.recipient}" : ""} | ${entry.amount} ед. ${entry.total.isNotEmpty ? "(${entry.total} ₽)" : ""}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: _isLoading
                                  ? null
                                  : () => _deleteLastEntry(entry),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.deepOrange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.table_chart,
                                color: Colors.deepOrange.shade700,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Таблица учета текущего месяца',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Здесь вы можете открыть актуальную Google Таблицу текущего месяца для проверки данных:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _isOpeningSheet
                                ? null
                                : _openCurrentMonthSheet,
                            icon: _isOpeningSheet
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.open_in_new, size: 18),
                            label: Text(
                              _isOpeningSheet
                                  ? 'ЗАГРУЗКА...'
                                  : 'ОТКРЫТЬ ТАБЛИЦУ МЕСЯЦА',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Пополнение справочника',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Новый ингредиент автоматически запишется в столбец A листа "Справочник" и сразу появится во всплывающем списке.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _newIngredientController,
                            decoration: const InputDecoration(
                              labelText: 'Наименование нового ингредиента *',
                              prefixIcon: Icon(Icons.post_add),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isAddingIngredient
                                  ? null
                                  : _addNewIngredient,
                              icon: const Icon(Icons.add_circle_outline),
                              label: Text(
                                _isAddingIngredient
                                    ? 'СОХРАНЕНИЕ...'
                                    : 'ДОБАВИТЬ В СПРАВОЧНИК',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildScheduleMonthCard(currentMonth),
                  const SizedBox(height: 16),
                  _buildScheduleMonthCard(nextMonth),
                ],
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.eco,
                          size: 64,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'KitchenFlow',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Версия 1.4.4 (Калькулятор кнопок Быстро)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Divider(height: 32, thickness: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.restaurant,
                          color: Colors.deepOrange,
                        ),
                        title: const Text('Организация'),
                        subtitle: const Text(
                          'Кафе «Розмарин»',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.person,
                          color: Colors.deepOrange,
                        ),
                        title: const Text('Автор проекта'),
                        subtitle: const Text(
                          'Рудометов А.С.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.shield, color: Colors.blue),
                        title: const Text('Режим работы'),
                        subtitle: const Text(
                          'Защита от двойных нажатий включена.',
                        ),
                      ),
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
