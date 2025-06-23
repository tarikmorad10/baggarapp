import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart'
as p; // تم إضافة 'as p' لتجنب التعارض مع Context
import 'package:intl/intl.dart';
import 'dart:ui' as ui; // لتنسيق التاريخ والأرقام

void main() => runApp(BaggarConsoApp());

// Widget الرئيسي للتطبيق
class BaggarConsoApp extends StatelessWidget {
  const BaggarConsoApp({Key? key}) : super(key: key); // إضافة key parameter
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BaggarConso ⚡',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme( // جعل const
          centerTitle: true,
          elevation: 4,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // جعل const
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // جعل const
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // جعل const
        ),
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false, // لإزالة لافتة DEBUG
    );
  }
}

// شاشة البداية للتعامل مع تهيئة قاعدة البيانات
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key); // إضافة key parameter
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Database> dbFuture;

  @override
  void initState() {
    super.initState();
    dbFuture = _initDb(); // تهيئة قاعدة البيانات عند بدء التطبيق
  }

  // دالة تهيئة قاعدة البيانات وإنشاء الجداول
  Future<Database> _initDb() async {
    // استخدام p.join بدلاً من join بسبب إضافة alias
    final dbPath = p.join(await getDatabasesPath(), 'baggarconso.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // جدول الزبناء لتخزين أسمائهم وآخر قراءة للعداد
        await db.execute('''
          CREATE TABLE IF NOT EXISTS clients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            previous_kwh REAL DEFAULT 0.0
          )
          ''');
        // جدول التاريخ لتخزين تفاصيل الحسابات لكل زبون
        await db.execute('''
          CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            new_kwh REAL NOT NULL,
            net_kwh REAL NOT NULL, -- الفرق في الاستهلاك (جديد - قديم)
            amount REAL NOT NULL, -- المبلغ المستحق
            FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
          )
          ''');
      },
      // تفعيل حذف السجلات المرتبطة عند حذف زبون
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: dbFuture,
      builder: (context, snapshot) {
        // إذا تم الاتصال بقاعدة البيانات بنجاح، اعرض MainPage
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return MainPage(database: snapshot.data!);
        } else if (snapshot.hasError) {
          // في حالة وجود خطأ في تهيئة قاعدة البيانات
          return Scaffold(
            body: Center(
              child: Text('خطأ في تحميل قاعدة البيانات: ${snapshot.error}'),
            ),
          );
        } else {
          // عرض مؤشر التحميل أثناء تهيئة قاعدة البيانات
          return const Scaffold(body: Center(child: CircularProgressIndicator())); // تم تصحيح CircularCircularProgressIndicator
        }
      },
    );
  }
}

// الشاشة الرئيسية التي تحتوي على TabBar للتنقل بين الصفحات
class MainPage extends StatelessWidget {
  final Database database;

  const MainPage({Key? key, required this.database}) : super(key: key); // إضافة key parameter
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // عدد الصفحات (الحساب والزبناء والتاريخ)
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BaggarConso ⚡'), // جعل const
          bottom: TabBar(
            labelColor: Theme.of(
              context,
            ).colorScheme.onPrimary, // لون النص للعلامة النشطة
            unselectedLabelColor: Theme.of(context).colorScheme.onPrimary
                .withOpacity(0.7), // لون النص للعلامة غير النشطة
            indicatorColor: Colors.white, // لون المؤشر تحت العلامة النشطة
            tabs: const [ // جعل const
              Tab(icon: Icon(Icons.calculate), text: 'الحساب'),
              Tab(icon: Icon(Icons.people), text: 'الزبناء'),
              Tab(icon: Icon(Icons.history), text: 'التاريخ'), // إضافة تبويب التاريخ
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ConsumptionPage(database: database), // صفحة حساب الاستهلاك
            ClientsPage(database: database), // صفحة إدارة الزبناء
            HistoryPage(database: database), // صفحة تاريخ الفواتير
          ],
        ),
      ),
    );
  }
}

// صفحة إدارة الزبناء: إضافة، عرض، حذف الزبناء
class ClientsPage extends StatefulWidget {
  final Database database;

  const ClientsPage({Key? key, required this.database}) : super(key: key); // إضافة key parameter

  @override
  _ClientsPageState createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final TextEditingController nameController = TextEditingController();
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients(); // تحميل الزبناء عند بدء الشاشة
  }

  // تحميل قائمة الزبناء من قاعدة البيانات
  Future<void> _loadClients() async {
    final data = await widget.database.query('clients', orderBy: 'name ASC');
    setState(() {
      _clients = data;
    });
  }

  // إضافة زبون جديد إلى قاعدة البيانات
  Future<void> _addClient() async {
    String name = nameController.text.trim();
    if (name.isEmpty) {
      if (!mounted) return; // التحقق من mounted قبل استخدام BuildContext
      _showMessage(context, 'الرجاء إدخال اسم الزبون');
      return;
    }

    // التحقق مما إذا كان الزبون موجودًا بالفعل
    final existingClients = await widget.database.query(
      'clients',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existingClients.isNotEmpty) {
      if (!mounted) return; // التحقق من mounted قبل استخدام BuildContext
      _showMessage(context, 'الزبون بهذا الاسم موجود بالفعل');
      return;
    }

    await widget.database.insert(
      'clients',
      {
        'name': name,
        'previous_kwh': 0.0, // قراءة أولية للعداد
      },
      conflictAlgorithm:
      ConflictAlgorithm.replace, // استبدال إذا كان هناك تعارض (نادر هنا)
    );
    nameController.clear();
    await _loadClients(); // إعادة تحميل القائمة لتحديث الواجهة
    if (!mounted) return; // التحقق من mounted قبل استخدام BuildContext
    _showMessage(context, 'تمت إضافة الزبون بنجاح');
  }

  // حذف زبون من قاعدة البيانات
  Future<void> _deleteClient(int id) async {
    // تأكيد الحذف
    final bool confirmDelete = await _showConfirmationDialog(
      context,
      'تأكيد الحذف',
      'هل أنت متأكد أنك تريد حذف هذا الزبون؟ سيتم حذف جميع بيانات استهلاكه.',
    );

    if (confirmDelete) {
      await widget.database.delete('clients', where: 'id = ?', whereArgs: [id]);
      await _loadClients(); // إعادة تحميل القائمة
      if (!mounted) return; // التحقق من mounted قبل استخدام BuildContext
      _showMessage(context, 'تم حذف الزبون بنجاح');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16), // جعل const
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration( // جعل const
              labelText: 'اسم الزبون',
              hintText: 'أدخل اسم الزبون هنا',
            ),
            textDirection: ui.TextDirection.rtl, // لغة عربية
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 16), // جعل const
          ElevatedButton.icon(
            onPressed: _addClient,
            icon: const Icon(Icons.person_add), // جعل const
            label: const Text('إضافة زبون جديد'), // جعل const
          ),
          const SizedBox(height: 24), // جعل const
          const Text( // جعل const
            'قائمة الزبناء',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(), // جعل const
          Expanded(
            child: _clients.isEmpty
                ? const Center( // جعل const
              child: Text(
                'لا يوجد زبناء بعد.\nالرجاء إضافة زبون جديد.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _clients.length,
              itemBuilder: (_, index) {
                final client = _clients[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8), // جعل const
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric( // جعل const
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      client['name'],
                      style: const TextStyle( // جعل const
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textDirection: ui.TextDirection.rtl, // لغة عربية
                      textAlign: TextAlign.right,
                    ),
                    subtitle: Text(
                      'استهلاك سابق: ${client['previous_kwh'].toStringAsFixed(2)} kWh',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red), // جعل const
                      onPressed: () => _deleteClient(client['id']),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// صفحة حساب الاستهلاك: إدخال قراءات جديدة، حساب، وتوزيع الفاتورة
class ConsumptionPage extends StatefulWidget {
  final Database database;

  const ConsumptionPage({Key? key, required this.database}) : super(key: key); // إضافة key parameter

  @override
  _ConsumptionPageState createState() => _ConsumptionPageState();
}

class _ConsumptionPageState extends State<ConsumptionPage> {
  List<Map<String, dynamic>> clients = [];
  Map<int, TextEditingController> newKwhControllers =
  {}; // لربط كل زبون بـ TextField خاص به
  final TextEditingController totalPriceController = TextEditingController();

  // تم تغيير `result` من String إلى قائمة لتخزين تفاصيل فواتير الزبائن
  List<Map<String, dynamic>> calculatedBills = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadClientsAndSetupControllers(); // تحميل الزبناء وإعداد المتحكمات
  }

  // تحميل الزبناء وإعداد TextEditingController لكل منهم
  Future<void> _loadClientsAndSetupControllers() async {
    final data = await widget.database.query('clients', orderBy: 'name ASC');
    setState(() {
      clients = data;
      newKwhControllers.clear(); // مسح المتحكمات القديمة
      for (var client in clients) {
        newKwhControllers[client['id']] = TextEditingController(
          text: client['previous_kwh'].toStringAsFixed(2),
        );
      }
      calculatedBills = []; // مسح النتائج عند إعادة التحميل
    });
  }

  // دالة الحساب الرئيسية
  Future<void> calculate() async {
    setState(() {
      _isLoading = true; // بدء مؤشر التحميل
      calculatedBills = []; // مسح النتائج السابقة قبل حساب جديد
    });

    double totalPrice = double.tryParse(totalPriceController.text) ?? 0.0;
    if (totalPrice <= 0) {
      if (!mounted) return; // التحقق من mounted قبل استخدام BuildContext
      _showMessage(context, 'الرجاء إدخال ثمن الفاتورة الإجمالي');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // لجمع استهلاك كل زبون (الفرق الجديد - القديم)
    double totalConsumptionOfAllCustomers = 0.0;
    List<Map<String, dynamic>> currentBillingDetails =
    []; // لتخزين تفاصيل الحساب للدورة الحالية

    for (var client in clients) {
      int clientId = client['id'];
      String clientName = client['name'];
      double previousKwh =
          client['previous_kwh'] ??
              0.0; // إذا لم تكن هناك قراءة سابقة، اعتبرها 0

      // الحصول على القراءة الجديدة من المتحكم الخاص بهذا الزبون
      double newKwh =
          double.tryParse(newKwhControllers[clientId]?.text ?? '') ?? 0.0;

      if (newKwh < previousKwh) { // تم إضافة أقواس {}
        if (!mounted) return; // التحقق من mounted قبل استخدام BuildContext
        _showMessage(
          context,
          'قراءة العداد الجديدة للزبون ${clientName} يجب أن تكون أكبر من أو تساوي القراءة السابقة.',
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      double individualConsumption;
      // إذا كانت هذه هي القراءة الأولى للزبون (previous_kwh == 0.0)، فاستهلاكه هو القراءة الجديدة
      if (previousKwh == 0.0) {
        individualConsumption = newKwh;
      } else {
        individualConsumption = newKwh - previousKwh;
      }

      totalConsumptionOfAllCustomers += individualConsumption;

      currentBillingDetails.add({
        'client_id': clientId,
        'name': clientName,
        'previous_kwh': previousKwh,
        'new_kwh': newKwh,
        'individual_consumption': individualConsumption,
        'amount': 0.0, // سيتم حسابها لاحقًا
      });
    }

    if (totalConsumptionOfAllCustomers == 0) { // تم إضافة أقواس {}
      if (!mounted) return; // التحقق من mounted قبل استخدام BuildContext
      _showMessage(
        context,
        'مجموع الاستهلاك للزبناء صفر. لا يمكن إجراء الحساب.',
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // حساب حصة كل زبون من الفاتورة الإجمالية وتحديث قاعدة البيانات
    for (var detail in currentBillingDetails) {
      double amountDue =
          (detail['individual_consumption'] / totalConsumptionOfAllCustomers) *
              totalPrice;
      detail['amount'] = amountDue; // تحديث المبلغ المستحق في التفاصيل

      // إضافة تفاصيل الفاتورة إلى قائمة `calculatedBills` لعرضها
      calculatedBills.add({
        'name': detail['name'],
        'amount': amountDue,
      });

      // تحديث القراءة السابقة للزبون في جدول clients
      await widget.database.update(
        'clients',
        {'previous_kwh': detail['new_kwh']},
        where: 'id = ?',
        whereArgs: [detail['client_id']],
      );

      // إضافة سجل إلى جدول history
      await widget.database.insert('history', {
        'client_id': detail['client_id'],
        'date': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        'new_kwh': detail['new_kwh'],
        'net_kwh': detail['individual_consumption'],
        'amount': amountDue,
      });
    }

    setState(() {
      // تم تحديث `calculatedBills` مباشرة في الحلقة
      _isLoading = false; // إخفاء مؤشر التحميل
    });

    await _loadClientsAndSetupControllers(); // إعادة تحميل الزبناء لتحديث "القراءة السابقة" في حقول الإدخال
    if (!mounted) return; // التحقق من mounted قبل استخدام BuildContext
    _showMessage(context, 'تم حساب الفاتورة بنجاح!');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16), // جعل const
      child: Column(
        children: [
          TextField(
            controller: totalPriceController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration( // جعل const
              labelText: 'ثمن الفاتورة الإجمالي (درهم)',
              hintText: 'مثال: 500.75',
              prefixIcon: Icon(Icons.attach_money),
            ),
            textDirection: ui.TextDirection.rtl, // لغة عربية
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 20), // جعل const
          const Text( // جعل const
            'أدخل القراءة الجديدة لكل زبون',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(), // جعل const
          Expanded(
            child: clients.isEmpty
                ? const Center( // جعل const
              child: Text(
                'لا يوجد زبناء.\nالرجاء إضافة زبناء في صفحة "الزبناء".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];
                final clientId = client['id'];
                // التأكد من وجود controller لهذا العميل
                if (!newKwhControllers.containsKey(clientId)) {
                  newKwhControllers[clientId] = TextEditingController(
                    text: client['previous_kwh'].toStringAsFixed(2),
                  );
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8), // جعل const
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0), // جعل const
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client['name'],
                          style: const TextStyle( // جعل const
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textDirection:
                          ui.TextDirection.rtl, // لغة عربية
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8), // جعل const
                        Text(
                          'قراءة سابقة: ${client['previous_kwh'].toStringAsFixed(2)} kWh',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8), // جعل const
                        TextField(
                          controller: newKwhControllers[clientId],
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'القراءة الجديدة (kWh)',
                            hintText:
                            'مثال: ${client['previous_kwh'].toStringAsFixed(2)}', // تلميح بالقراءة السابقة
                          ),
                          textDirection:
                          ui.TextDirection.rtl, // لغة عربية
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20), // جعل const
          _isLoading
              ? const CircularProgressIndicator() // جعل const
              : ElevatedButton.icon(
            onPressed: calculate,
            icon: const Icon(Icons.check), // جعل const
            label: const Text('حسب الفاتورة'), // جعل const
          ),
          const SizedBox(height: 20), // جعل const
          // تم تحديث هذا الجزء لعرض النتائج في قائمة منظمة
          if (calculatedBills.isNotEmpty)
            Expanded(
              flex: 1,
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16), // جعل const
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text( // جعل const
                        'نتائج الحساب:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Divider(), // جعل const
                      Expanded(
                        child: ListView.builder(
                          itemCount: calculatedBills.length,
                          itemBuilder: (context, index) {
                            final bill = calculatedBills[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4), // جعل const
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0), // جعل const
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        bill['name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), // جعل const
                                        textDirection: ui.TextDirection.rtl,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    const SizedBox(width: 10), // جعل const
                                    Text(
                                      '${bill['amount'].toStringAsFixed(2)} درهم',
                                      style: TextStyle(fontSize: 16, color: Colors.green[700]),
                                      textDirection: ui.TextDirection.rtl, // يمكن أن يكون LTR للأرقام
                                      textAlign: TextAlign.left,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // التخلص من المتحكمات لمنع تسرب الذاكرة
    newKwhControllers.forEach((id, controller) => controller.dispose());
    totalPriceController.dispose();
    super.dispose();
  }
}

// صفحة جديدة لعرض تاريخ الفواتير لكل زبون
class HistoryPage extends StatefulWidget {
  final Database database;

  const HistoryPage({Key? key, required this.database}) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory(); // تحميل بيانات التاريخ عند بدء الشاشة
  }

  // تحميل بيانات التاريخ من قاعدة البيانات
  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    // جلب التاريخ من جدول history وربطه بأسماء الزبناء من جدول clients
    final List<Map<String, dynamic>> data = await widget.database.rawQuery('''
      SELECT 
        h.id, 
        c.name AS client_name, 
        h.date, 
        h.new_kwh, 
        h.net_kwh, 
        h.amount
      FROM history h
      JOIN clients c ON h.client_id = c.id
      ORDER BY h.date DESC
    ''');

    setState(() {
      _historyData = data;
      _isLoadingHistory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تاريخ الفواتير',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const Divider(),
          _isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _historyData.isEmpty
              ? const Center(
            child: Text(
              'لا يوجد سجلات فواتير حتى الآن.\nقم بإجراء بعض الحسابات في صفحة "الحساب".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
              : Expanded(
            child: ListView.builder(
              itemCount: _historyData.length,
              itemBuilder: (context, index) {
                final entry = _historyData[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end, // محاذاة النص لليمين
                      children: [
                        Text(
                          'الزبون: ${entry['client_name']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          textDirection: ui.TextDirection.rtl,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'التاريخ: ${entry['date']}',
                          style: const TextStyle(color: Colors.grey),
                          textDirection: ui.TextDirection.rtl,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'قراءة جديدة: ${entry['new_kwh'].toStringAsFixed(2)} kWh',
                          textDirection: ui.TextDirection.rtl,
                        ),
                        Text(
                          'الاستهلاك الصافي: ${entry['net_kwh'].toStringAsFixed(2)} kWh',
                          textDirection: ui.TextDirection.rtl,
                        ),
                        Text(
                          'المبلغ المدفوع: ${entry['amount'].toStringAsFixed(2)} درهم',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700]),
                          textDirection: ui.TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// دالة مساعدة لعرض رسالة سريعة (SnackBar)
void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.rtl,
      ),
      backgroundColor: Colors.blueAccent,
      duration: const Duration(seconds: 3), // جعل const
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

// دالة مساعدة لعرض نافذة تأكيد (AlertDialog)
Future<bool> _showConfirmationDialog(
    BuildContext context,
    String title,
    String content,
    ) async {
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Text(
          title,
          textDirection: ui.TextDirection.rtl,
          textAlign: TextAlign.right,
        ),
        content: Text(
          content,
          textDirection: ui.TextDirection.rtl,
          textAlign: TextAlign.right,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)), // جعل const
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
          ElevatedButton(
            child: const Text('تأكيد الحذف'), // جعل const
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
        ],
      );
    },
  ) ??
      false; // Return false if dialog is dismissed
}
