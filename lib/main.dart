import 'dart:convert';
import 'dart:io';
import 'notifikacie.dart';
import 'package:zakazky_test/notifikacie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await NotifikacnaSluzba.inicializuj();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RezimProvider()),
      ],
      child: MaterialApp(
        title: 'Zákazky',
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.system,
        supportedLocales: const [Locale('sk'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ZakazkyApp(),
      ),
    ),
  );
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme(bool dark) {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class RezimProvider with ChangeNotifier {
  bool tichyRezim = false;
  void toggleTichy() {
    tichyRezim = !tichyRezim;
    notifyListeners();
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nastavenia')),
      body: const Center(child: Text('Tu budú tvoje nastavenia')),
    );
  }
}

class Zakazka {
  final String nazov;
  final String stav;
  final String datum;
  final String poznamka;
  final String termin;
  final bool hviezdicka;
  final bool dolezita;

  Zakazka({
    required this.nazov,
    required this.stav,
    required this.datum,
    required this.poznamka,
    required this.termin,
    required this.hviezdicka,
    required this.dolezita,
  });

  Map<String, dynamic> toJson() => {
        'nazov': nazov,
        'stav': stav,
        'datum': datum,
        'poznamka': poznamka,
        'termin': termin,
        'hviezdicka': hviezdicka,
        'dolezita': dolezita,
      };

  factory Zakazka.fromJson(Map<String, dynamic> json) => Zakazka(
        nazov: json['nazov'] ?? '',
        stav: json['stav'] ?? '',
        datum: json['datum'] ?? '',
        poznamka: json['poznamka'] ?? '',
        termin: json['termin'] ?? '',
        hviezdicka: json['hviezdicka'] ?? false,
        dolezita: json['dolezita'] ?? false,
      );
}

class ZakazkyApp extends StatefulWidget {
  const ZakazkyApp({super.key});

  @override
  State<ZakazkyApp> createState() => _ZakazkyAppState();
}

class _ZakazkyAppState extends State<ZakazkyApp> {
  final controller = TextEditingController();
  final vyhladavanieController = TextEditingController();
  final emailController = TextEditingController();

  List<Zakazka> zakazky = [];
  String vybranyStav = 'Čaká';
  String aktivnyFilter = 'Všetky';
  String vyhladavanieText = '';
  String poleTriedenia = 'termin';
  String zoradPodla = 'datum';
  bool vzostupne = true;
  bool zobrazHoruceLen = false;
  bool upozorneniaAktivne = true;

  @override
  void initState() {
    super.initState();
    nacitajZakazky();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final horuce = zakazky.where((z) => getRozdielDni(z.termin) <= 0).toList();
      if (!upozorneniaAktivne || horuce.isEmpty) return;

      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('⏰ Po termíne'),
            content: Text('Máš ${horuce.length} zákaziek po termíne.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    vyhladavanieController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final rezim = Provider.of<RezimProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    final zoznam = vyfiltrovaneZakazky();
    final stats = vypocitajStatistiky();
    final jeTmavyRezim = Theme.of(context).brightness == Brightness.dark;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Zákazky'),
          actions: [
            IconButton(
              icon: Icon(
                rezim.tichyRezim ? Icons.volume_off : Icons.vibration,
                color: rezim.tichyRezim ? Colors.grey : Colors.blue,
              ),
              onPressed: () => rezim.toggleTichy(),
              tooltip: 'Tichý režim',
            ),
            IconButton(
              icon: Icon(
                upozorneniaAktivne ? Icons.notifications_active : Icons.notifications_off,
                color: upozorneniaAktivne ? Colors.orange : Colors.grey,
              ),
              onPressed: () => setState(() => upozorneniaAktivne = !upozorneniaAktivne),
              tooltip: 'Upozornenia',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Pridať zákazku',
              onPressed: pridajZakazku,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'Nastavenia a akcie',
              onSelected: (value) async {
                switch (value) {
                  case 'export': exportovatZakazky(); break;
                  case 'import': importovatZakazky(); break;
                  case 'zalohuj': ulozZalohuDoSuboru(); break;
                  case 'obnov': nacitajZakazky(); break;
                  case 'email': zazalohujAVysli(); break;
                  case 'tema': themeProvider.toggleTheme(!isDark); break;
                  case 'import_csv': await importujZakazkyZCSV(); break;
                  case 'share_csv': await ulozCSVASdielaj(zakazky); break;
                  case 'export_csv':
                    final csv = exportujDoCSV(zakazky);
                    await ulozCSV(csv);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Zákazky uložené do zakazky_export.csv')),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.upload_file, color: Colors.lightBlue),
                    title: Text('Export do schránky'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.download, color: Colors.teal),
                    title: Text('Import zo schránky'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'zalohuj',
                  child: ListTile(
                    leading: Icon(Icons.save_alt, color: Colors.green),
                    title: Text('Zálohovať do súboru'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'obnov',
                  child: ListTile(
                    leading: Icon(Icons.restore, color: Colors.indigo),
                    title: Text('Obnov zo zálohy'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'email',
                  child: ListTile(
                    leading: Icon(Icons.email, color: Colors.deepOrange),
                    title: Text('Zálohuj a pošli e-mailom'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_csv',
                  child: ListTile(
                    leading: Icon(Icons.file_download, color: Colors.blueGrey),
                    title: Text('Export do CSV'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'share_csv',
                  child: ListTile(
                    leading: Icon(Icons.share, color: Colors.blue),
                    title: Text('Zdieľať zákazky (CSV)'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'import_csv',
                  child: ListTile(
                    leading: Icon(Icons.upload_file, color: Colors.purple),
                    title: Text('Importuj zákazky z CSV'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'tema',
                  child: ListTile(
                    leading: Icon(Icons.brightness_6),
                    title: Text('Prepnúť tému'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
const SizedBox(height: 12),
ElevatedButton.icon(
onPressed: () {
  final novyController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nová zákazka'),
      content: TextField(
        controller: novyController,
        decoration: const InputDecoration(
          hintText: 'Zadaj názov zákazky',
          prefixIcon: Icon(Icons.edit),
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: () {
            final text = novyController.text.trim();
            if (text.isEmpty) return;

            final nova = Zakazka(
              nazov: text,
              stav: 'Čaká', // ← automaticky nastavíme
              datum: DateFormat('d.M.yyyy').format(DateTime.now()),
              poznamka: '',
              termin: '',
              hviezdicka: false,
              dolezita: false,
            );

            setState(() => zakazky.add(nova));
            ulozZakazky();
            Navigator.pop(ctx);
          },
          child: const Text('Uložiť'),
        ),
      ],
    ),
  );
},
  icon: const Icon(Icons.add),
  label: const Text('Pridať zákazku'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Theme.of(context).colorScheme.primary,
    foregroundColor: Theme.of(context).colorScheme.onPrimary,
    elevation: 6,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
),
              const SizedBox(height: 12),
              TextField(
                controller: vyhladavanieController,
                decoration: InputDecoration(
                  hintText: '🔍 Vyhľadaj zákazku...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      vyhladavanieController.clear();
                      setState(() => vyhladavanieText = '');
                    },
                  ),
                ),
                onChanged: (val) => setState(() => vyhladavanieText = val.toLowerCase()),
              ),
const SizedBox(height: 12),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(
      children: [
        const Text(
          'Triediť podľa:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: zoradPodla,
          items: ['datum', 'nazov', 'termin'].map((kriterium) {
            return DropdownMenuItem(
              value: kriterium,
              child: Text(kriterium),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              zoradPodla = val!;
              zoradZakazky();
            });
          },
        ),
      ],
    ),
    Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up),
          color: Colors.orange,
          iconSize: 30,
          tooltip: 'Vzostupne',
          onPressed: () {
            setState(() {
              vzostupne = true;
              zoradZakazky();
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          color: Colors.orange,
          iconSize: 30,
          tooltip: 'Zostupne',
          onPressed: () {
            setState(() {
              vzostupne = false;
              zoradZakazky();
            });
          },
        ),
      ],
    ),
  ],
),
              const SizedBox(height: 12),
              Expanded(
                child: zoznam.isEmpty
                    ? const Center(child: Text('Žiadne zákazky'))
                    : ListView.builder(
                        itemCount: zoznam.length,
                        itemBuilder: (context, index) {
                          final z = zoznam[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              onTap: () => upravitZakazku(index),
                              leading: CircleAvatar(
                                backgroundColor: getFarbaPodlaStavu(z.stav),
                                child: const Icon(Icons.build, color: Colors.white),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    z.nazov,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Chip(
                                    label: Text(z.stav),
                                    backgroundColor: getFarbaPodlaStavu(z.stav),
                                    labelStyle: const TextStyle(color: Colors.white),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (z.poznamka.isNotEmpty) Text(z.poznamka),
                                  Text(
                                    z.datum,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  if (z.termin.isNotEmpty && DateTime.tryParse(z.termin) != null)
Chip(
  label: Text(zostavajuciCas(z.termin)),
  backgroundColor: z.termin.trim().isEmpty
      ? Colors.grey
      : datumJePoTermine(z.termin)
          ? Colors.redAccent
          : Colors.greenAccent,
  labelStyle: const TextStyle(color: Colors.white),
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
),

                                    Text(
                                      formatujInfoZTterminu(z.termin),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: getFarbaOdpocet(z.termin),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      z.dolezita ? Icons.star : Icons.star_border,
                                      color: z.dolezita ? Colors.orange : Colors.grey,
                                    ),
                                    tooltip: 'Označiť ako dôležité',
                                    onPressed: () {
                                      setState(() {
                                        zakazky[index] = Zakazka(
                                          nazov: z.nazov,
                                          stav: z.stav,
                                          datum: z.datum,
                                          poznamka: z.poznamka,
                                          termin: z.termin,
                                          hviezdicka: z.hviezdicka,
                                          dolezita: !z.dolezita,
                                        );
                                      });
                                      ulozZakazky();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Vymazať zákazku',
                                    onPressed: () => vymazZakazku(index),
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
      );
  }

  void pridajZakazku() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final nova = Zakazka(
      nazov: text,
      stav: vybranyStav,
      datum: DateFormat('d.M.yyyy').format(DateTime.now()),
      poznamka: '',
      termin: '',
      hviezdicka: false,
      dolezita: false,
    );

    setState(() {
      zakazky.add(nova);
      controller.clear();
    });

    ulozZakazky();
  }

bool datumJePoTermine(String termin) {
  if (termin.trim().isEmpty) return false;

  try {
    final datum = DateFormat('d.M.yyyy').parse(termin);
    return datum.isBefore(DateTime.now());
  } catch (e) {
    debugPrint('Neplatný termín: $termin');
    return false;
  }
}

void zoradZakazky() {
  setState(() {
    zakazky.sort((a, b) {
      Comparable hodnotaA;
      Comparable hodnotaB;

      switch (zoradPodla) {
        case 'nazov':
          hodnotaA = a.nazov.toLowerCase();
          hodnotaB = b.nazov.toLowerCase();
          break;
        case 'datum':
          hodnotaA = DateFormat('d.M.yyyy').parse(a.datum);
          hodnotaB = DateFormat('d.M.yyyy').parse(b.datum);
          break;
        case 'termin':
          hodnotaA = DateFormat('d.M.yyyy').parse(a.termin);
          hodnotaB = DateFormat('d.M.yyyy').parse(b.termin);
          break;
        default:
          return 0;
      }

      return vzostupne
          ? hodnotaA.compareTo(hodnotaB)
          : hodnotaB.compareTo(hodnotaA);
    });
  });
}

void upravitZakazku(int index) {
  final zakazka = zakazky[index];
  final poznamkaController = TextEditingController(text: zakazka.poznamka);
  final terminController = TextEditingController(text: zakazka.termin);
  String lokalnyStav = zakazka.stav;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Upraviť: ${zakazka.nazov}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: lokalnyStav,
              items: ['Čaká', 'V riešení', 'Hotovo']
                  .map((stav) => DropdownMenuItem(
                        value: stav,
                        child: Text(stav),
                      ))
                  .toList(),
              onChanged: (val) => lokalnyStav = val ?? zakazka.stav,
              decoration: const InputDecoration(
                labelText: 'Stav',
                prefixIcon: Icon(Icons.flag),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: poznamkaController,
              decoration: const InputDecoration(
                labelText: 'Poznámka',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final vybrany = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (vybrany != null) {
                  terminController.text =
                      DateFormat('d.M.yyyy').format(vybrany);
                }
              },
              child: IgnorePointer(
                child: TextField(
                  controller: terminController,
                  decoration: const InputDecoration(
                    labelText: 'Termín dokončenia',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: () async {
            setState(() {
              zakazky[index] = Zakazka(
                nazov: zakazka.nazov,
                stav: lokalnyStav,
                datum: zakazka.datum,
                poznamka: poznamkaController.text.trim(),
                termin: terminController.text.trim(),
                hviezdicka: zakazka.hviezdicka,
                dolezita: zakazka.dolezita,
              );
            });

            ulozZakazky();

            // 🔔 Notifikácia deň pred termínom
            try {
              final terminDT =
                  DateFormat('d.M.yyyy').parse(terminController.text.trim());

              await NotifikacnaSluzba.naplanujUpozornenie(
                index, // môžeš nahradiť zakazka.id, ak existuje
                zakazka.nazov,
                terminDT,
              );
            } catch (e) {
              debugPrint('Chyba pri plánovaní notifikácie: $e');
            }

            Navigator.pop(ctx);
          },
          child: const Text('Uložiť'),
        ),
      ],
    ),
  );
}

  void vymazZakazku(int index) {
    setState(() {
      zakazky.removeAt(index);
    });
    ulozZakazky();
  }

  Future<void> ulozZakazky() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = zakazky.map((z) => z.toJson()).toList();
    await prefs.setString('zakazky', jsonEncode(jsonData));
  }

  Future<void> nacitajZakazky() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('zakazky');
    if (jsonString != null) {
      final jsonList = jsonDecode(jsonString) as List;
      setState(() {
        zakazky = jsonList.map((z) => Zakazka.fromJson(z)).toList();
      });
    }
  }

  void exportovatZakazky() {
    final jsonData = zakazky.map((z) => z.toJson()).toList();
    final jsonText = const JsonEncoder.withIndent('  ').convert(jsonData);
    Clipboard.setData(ClipboardData(text: jsonText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📤 Exportované do schránky')),
    );
  }

  void importovatZakazky() async {
    final data = await Clipboard.getData('text/plain');
    final obsah = data?.text;
    if (obsah == null || obsah.trim().isEmpty) return;

    try {
      final jsonList = jsonDecode(obsah) as List;
      final nove = jsonList.map((z) => Zakazka.fromJson(z)).toList();
      setState(() {
        zakazky.addAll(nove);
      });
      ulozZakazky();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📥 Import úspešný!')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Chybný JSON pri importe')),
      );
    }
  }

  Future<void> ulozZalohuDoSuboru() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/zakazky_backup.json';
    final jsonData = zakazky.map((z) => z.toJson()).toList();
    final obsah = const JsonEncoder.withIndent('  ').convert(jsonData);
    final file = File(path);
    await file.writeAsString(obsah);
  }

Future<void> posliZalohuEmailom(String email) async {
  final dir = await getApplicationDocumentsDirectory();
  final subor = File('${dir.path}/zakazky_backup.json');
  if (!await subor.exists()) return;

  final username = 'tvojemail@gmail.com';
  final heslo = 'tvoje_16znakove_app_password';
  final smtpServer = gmail(username, heslo);

  final message = mailer.Message()
    ..from = mailer.Address(username, 'Zákazková appka')
    ..recipients.add(email)
    ..subject = 'Záloha zákaziek'
    ..text = 'V prílohe je JSON so zákazkami.'
    ..attachments = [mailer.FileAttachment(subor)];

  await mailer.send(message, smtpServer);
}

  Future<void> zazalohujAVysli() async {
    final potvrdene = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zadaj e-mail'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'napr. zakazky@firma.sk',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušiť')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Odoslať')),
        ],
      ),
    );

    if (potvrdene != true) return;

    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❗ Zadaj platný e-mail')),
      );
      return;
    }

    await ulozZalohuDoSuboru();
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await posliZalohuEmailom(email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Záloha odoslaná na $email')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Nepodarilo sa odoslať e-mail')),
      );
    }
  }

  Map<String, int> vypocitajStatistiky() {
    final celkom = zakazky.length;
    final hotovo = zakazky.where((z) => z.stav == 'Hotovo').length;
    final riesenie = zakazky.where((z) => z.stav == 'V riešení').length;
    final caka = zakazky.where((z) => z.stav == 'Čaká').length;
    final poTermine = zakazky.where((z) => getRozdielDni(z.termin) < 0).length;
    final do2Dni = zakazky.where((z) =>
        getRozdielDni(z.termin) <= 2 && getRozdielDni(z.termin) >= 0).length;
    final bezPoznamky = zakazky.where((z) => z.poznamka.trim().isEmpty).length;

    return {
      'Celkom': celkom,
      'Hotovo': hotovo,
      'V riešení': riesenie,
      'Čaká': caka,
      'Po termíne': poTermine,
      'Do 2 dní': do2Dni,
      'Bez poznámky': bezPoznamky,
    };
  }

  int getRozdielDni(String terminText) {
    try {
      final termin = DateTime.parse(terminText);
      return termin.difference(DateTime.now()).inDays;
    } catch (_) {
      return 9999;
    }
  }

String formatujInfoZTterminu(String terminText) {
  final dnes = DateTime.now();
  try {
    final termin = DateFormat('d.M.yyyy').parse(terminText);
    final rozdiel = termin.difference(dnes).inDays;
    if (rozdiel < 0) return 'Oneskorené (pred ${rozdiel.abs()} ${rozdiel.abs() == 1 ? 'dňom' : 'dňami'})';
    if (rozdiel == 0) return 'Termín dnes';
    return 'Termín za $rozdiel ${rozdiel == 1 ? 'deň' : 'dni'}';
  } catch (e) {
    return 'Neplatný termín';
  }
}

  Color getFarbaPodlaStavu(String stav) {
    switch (stav) {
      case 'V riešení': return Colors.orange;
      case 'Hotovo': return Colors.green;
      case 'Čaká': default: return Colors.grey;
    }
  }

Color getFarbaOdpocet(String terminText) {
  try {
    final termin = DateFormat('d.M.yyyy').parse(terminText);
    final rozdiel = termin.difference(DateTime.now()).inDays;
    if (rozdiel < 0) return Colors.redAccent;
    if (rozdiel <= 2) return Colors.orangeAccent;
    return Colors.greenAccent;
  } catch (_) {
    return Colors.grey;
  }
}

String zostavajuciCas(String termin) {
  if (termin.trim().isEmpty) return 'Bez termínu';

  try {
    final datum = DateFormat('d.M.yyyy').parse(termin);
    final rozdiel = datum.difference(DateTime.now()).inDays;

    if (rozdiel > 0) return 'Zostáva $rozdiel dní';
    if (rozdiel == 0) return 'Termín je dnes';
    return 'Po termíne (${rozdiel.abs()} dní)';
  } catch (e) {
    return 'Neplatný dátum';
  }
}

  String exportujDoCSV(List<Zakazka> zakazky) {
    final buffer = StringBuffer();
    buffer.writeln('Názov,Stav,Dátum,Poznámka,Termín,Hviezdicka,Dôležitá');
    for (final z in zakazky) {
      final riadok = [
        z.nazov,
        z.stav,
        z.datum,
        z.poznamka.replaceAll(',', '␣'),
        z.termin,
        z.hviezdicka ? 'Áno' : 'Nie',
        z.dolezita ? 'Áno' : 'Nie',
      ].join(',');
      buffer.writeln(riadok);
    }
    return buffer.toString();
  }

  Future<void> ulozCSV(String csvData) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/zakazky_export.csv');
    await file.writeAsString(csvData);
  }

  Future<void> ulozCSVASdielaj(List<Zakazka> zakazky) async {
    final csv = exportujDoCSV(zakazky);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/zakazky_export.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Tu sú moje zákazky vo formáte CSV');
  }

  Future<void> importujZakazkyZCSV() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/zakazky_export.csv');
    if (!await file.exists()) return;

    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content, eol: '\n');
    final data = rows.skip(1);

    zakazky.clear();
    for (final r in data) {
      zakazky.add(Zakazka(
        nazov: r[0] ?? '',
        stav: r[1] ?? '',
        datum: r[2] ?? '',
        poznamka: r[3] ?? '',
        termin: r[4] ?? '',
        hviezdicka: (r[5] == 'Áno'),
        dolezita: (r[6] == 'Áno'),
      ));
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zákazky boli načítané z CSV')),
    );
  }

  List<Zakazka> vyfiltrovaneZakazky() {
    var vysledok = [...zakazky];

    if (aktivnyFilter != 'Všetky') {
      vysledok = vysledok.where((z) => z.stav == aktivnyFilter).toList();
    }

    if (zobrazHoruceLen) {
      vysledok = vysledok.where((z) => getRozdielDni(z.termin) <= 0).toList();
    }

    if (vyhladavanieText.isNotEmpty) {
      vysledok = vysledok
          .where((z) =>
              z.nazov.toLowerCase().contains(vyhladavanieText) ||
              z.poznamka.toLowerCase().contains(vyhladavanieText))
          .toList();
    }

    return vysledok;
  }
}
