import 'dart:convert';
import 'dart:io';
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

  // Vytvoríme ThemeProvider a načítame uložený režim
  final themeProvider = ThemeProvider();
  await themeProvider.nacitajRezim();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => RezimProvider()),
      ],
      child: const ZakazkyAppWrapper(),
    ),
  );
}

class ZakazkyAppWrapper extends StatelessWidget {
  const ZakazkyAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Zákazky',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      supportedLocales: const [Locale('sk'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const ZakazkyApp(),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    ulozRezim(isDark);
  }

  void nastavZPamate(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> nacitajRezim() async {
    final prefs = await SharedPreferences.getInstance();
    final ulozeny = prefs.getBool('jeTmavyRezim') ?? false;
    nastavZPamate(ulozeny);
  }

  Future<void> ulozRezim(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('jeTmavyRezim', isDark);
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

  Zakazka copyWith({
    String? nazov,
    String? stav,
    String? datum,
    String? poznamka,
    String? termin,
    bool? hviezdicka,
    bool? dolezita,
  }) {
    return Zakazka(
      nazov: nazov ?? this.nazov,
      stav: stav ?? this.stav,
      datum: datum ?? this.datum,
      poznamka: poznamka ?? this.poznamka,
      termin: termin ?? this.termin,
      hviezdicka: hviezdicka ?? this.hviezdicka,
      dolezita: dolezita ?? this.dolezita,
    );
  }

  factory Zakazka.fromJson(Map<String, dynamic> json) {
    return Zakazka(
      nazov: json['nazov'] ?? '',
      stav: json['stav'] ?? '',
      datum: json['datum'] ?? '',
      poznamka: json['poznamka'] ?? '',
      termin: json['termin'] ?? '',
      hviezdicka: json['hviezdicka'] ?? false,
      dolezita: json['dolezita'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nazov': nazov,
      'stav': stav,
      'datum': datum,
      'poznamka': poznamka,
      'termin': termin,
      'hviezdicka': hviezdicka,
      'dolezita': dolezita,
    };
  }
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
    nacitajPreferovaneTriedenie();

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

  void nacitajPreferovaneTriedenie() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final ulozene = prefs.getString('preferovaneTriedenie');
    if (ulozene != null) {
      setState(() {
        zoradPodla = ulozene;
        zoradZakazky();
      });
    }
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

  final zoznam = vyfiltrovaneZakazky();       // filtrované zákazky
  final stats = vypocitajStatistiky();        // mapové štatistiky: Čaká, V riešení, Hotovo

  final int poTermine = zoznam.where((z) => datumJePoTermine(z.termin)).length;
  final int bliziSa = zoznam.where((z) => datumJeDo2Dni(z.termin)).length;
  final int bezTerminu = zoznam.where((z) => z.termin.trim().isEmpty).length;

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
                case 'zalohuj': await ulozZalohuDoSuboru(); break;
                case 'obnov': nacitajZakazky(); break;
                case 'email': await zazalohujAVysli(); break;
                case 'tema':
                     themeProvider.toggleTheme(!isDark);
                  break;
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
      body: buildBody(context, zoznam, stats, poTermine, bliziSa, bezTerminu),
    );
  }

Widget buildBody(
  BuildContext context,
  List<Zakazka> zoznam,
  Map<String, int> stats,
  int poTermine,
  int bliziSa,
  int bezTerminu,
) {

  return Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        ElevatedButton.icon(
          onPressed: pridajZakazku,
          icon: const Icon(Icons.add),
          label: const Text('Pridať zákazku'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.tealAccent[700]
                : Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
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
            hintText: 'Vyhľadaj zákazku...',
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

        // ✅ Tu už môžeš použiť premennú `stats`
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.entries.map((e) {
            return Chip(
              label: Text('${e.key}: ${e.value}'),
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[300],
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            );
          }).toList(),
        ),
const SizedBox(height: 12),

Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    Chip(
      label: Text('Po termíne: $poTermine'),
      backgroundColor: Colors.red.shade100,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    Chip(
      label: Text('Do 2 dní: $bliziSa'),
      backgroundColor: Colors.orange.shade100,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    Chip(
      label: Text('Bez termínu: $bezTerminu'),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[800]
          : Colors.grey[300],
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  ],
),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Triediť podľa:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: zoradPodla,
                  items: ['datum', 'nazov', 'termin'].map((kriterium) {
                    return DropdownMenuItem(
                      value: kriterium,
                      child: Text(kriterium),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    setState(() {
                      zoradPodla = val!;
                      zoradZakazky();
                    });
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setString('preferovaneTriedenie', val!);
                  },
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up),
                  onPressed: () {
                    setState(() {
                      vzostupne = true;
                      zoradZakazky();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
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
                      child: ListTile(
                        onTap: () => upravitZakazku(index),
                       leading: CircleAvatar(
                         radius: 18,
                         backgroundColor: datumJePoTermine(z.termin)
                             ? Colors.red // 🔴 Po termíne = červená guľka
                             : getFarbaPodlaStavu(z.stav),
                         child: const SizedBox.shrink(), // žiadna ikona
                       ),
                        title: Text(z.nazov),
                          subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (z.poznamka.isNotEmpty) Text(z.poznamka),

                            if (datumJePoTermine(z.termin))
                              const Text(
                                'Po termíne',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                            // 🔽 Popis stavu s farebným textom
                            Text(
                              z.stav,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: getFarbaPodlaStavu(z.stav),
                              ),
                            ),

                            Text(z.datum),
                            if (z.termin.isNotEmpty)
                               Text(formatujInfoZTterminu(z.termin)),
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
                              onPressed: () {
                                setState(() {
                                  zakazky[index] = z.copyWith(dolezita: !z.dolezita);
                                });
                                ulozZakazky();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
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
  );
}

void pridajZakazku() {
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
              stav: 'Čaká',
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
}

bool datumJePoTermine(String termin) {
  if (termin.trim().isEmpty) return false;
  try {
    final datum = DateFormat('d.M.yyyy').parse(termin);
    return datum.isBefore(DateTime.now());
  } catch (e) {
    return false;
  }
}

bool datumJeDo2Dni(String termin) {
  if (termin.trim().isEmpty) return false;
  try {
    final datum = DateFormat('d.M.yyyy').parse(termin);
    final dnes = DateTime.now();
    final rozdiel = datum.difference(dnes).inDays;
    return rozdiel >= 0 && rozdiel <= 2;
  } catch (e) {
    return false;
  }
}

void zoradZakazky() {
  zakazky.sort((a, b) {
    switch (zoradPodla) {
      case 'nazov':
        return a.nazov.compareTo(b.nazov);
      case 'termin':
        final tA = parseTermin(a.termin);
        final tB = parseTermin(b.termin);
        if (tA == null || tB == null) return 0;
        return tA.compareTo(tB);
      case 'datum':
      default:
        final dA = parseTermin(a.datum);
        final dB = parseTermin(b.datum);
        if (dA == null || dB == null) return 0;
        return dA.compareTo(dB);
    }
  });

  if (!vzostupne) {
    zakazky = zakazky.reversed.toList();
  }
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
    case 'Čaká': return Colors.blue[600]!;
    default: return Colors.grey;
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

String bezDiakritiky(String vstup) {
  const diakritika = {
    'á': 'a', 'ä': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e',
    'í': 'i', 'ĺ': 'l', 'ľ': 'l', 'ň': 'n', 'ó': 'o', 'ô': 'o',
    'ŕ': 'r', 'š': 's', 'ť': 't', 'ú': 'u', 'ý': 'y', 'ž': 'z',
    'Á': 'A', 'Ä': 'A', 'Č': 'C', 'Ď': 'D', 'É': 'E', 'Ě': 'E',
    'Í': 'I', 'Ĺ': 'L', 'Ľ': 'L', 'Ň': 'N', 'Ó': 'O', 'Ô': 'O',
    'Ŕ': 'R', 'Š': 'S', 'Ť': 'T', 'Ú': 'U', 'Ý': 'Y', 'Ž': 'Z',
  };

  return vstup.split('').map((c) => diakritika[c] ?? c).join();
}

DateTime? parseTermin(String vstup) {
  try {
    return DateFormat('dd.MM.yyyy').parseStrict(vstup);
  } catch (_) {
    try {
      return DateFormat('d.M.yyyy').parseStrict(vstup);
    } catch (_) {
      return null;
    }
  }
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
    final hladany = bezDiakritiky(vyhladavanieText.trim().toLowerCase());
    final cislo = int.tryParse(hladany);
    final dnes = DateTime.now();
    final dnesCisty = DateTime(dnes.year, dnes.month, dnes.day);

    vysledok = vysledok.where((z) {
      final nazov = bezDiakritiky(z.nazov.toLowerCase());
      final datum = bezDiakritiky(z.datum.toLowerCase());
      final termin = bezDiakritiky(z.termin.toLowerCase());
      final poznamka = bezDiakritiky((z.poznamka ?? '').toLowerCase());
      final stav = bezDiakritiky((z.stav ?? '').toLowerCase());

      int rozdiel = 9999;
      final terminDate = parseTermin(z.termin);
      if (terminDate != null) {
        final terminCisty = DateTime(terminDate.year, terminDate.month, terminDate.day);
        rozdiel = terminCisty.difference(dnesCisty).inDays;
      }

      final textMatch = nazov.contains(hladany) ||
          datum.contains(hladany) ||
          termin.contains(hladany) ||
          poznamka.contains(hladany) ||
          stav.contains(hladany);

      final cisloMatch = cislo != null && rozdiel <= cislo && rozdiel >= 0;

      return textMatch || cisloMatch;
    }).toList();
  }

  return vysledok;
}
} // ← uzatvára triedu _ZakazkyAppState
