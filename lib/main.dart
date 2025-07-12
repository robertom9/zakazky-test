// 🔹 Dart štandardná knižnica
import 'modely/zakazka.dart';
import 'dart:convert';
import 'dart:io';

// 🔹 Flutter & UI
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// 🔹 Balíčky
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'providers/theme_provider.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'screens/vyhladavanie_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Zákazky',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: const ZakazkyApp(),
    );
  }
}

class VyhladavanieField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onClear;

  const VyhladavanieField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '🔍 Vyhľadať zákazku podľa názvu, stavu, poznámky...',
          filled: true,
          fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      ),
    );
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
  bool vzostupne = true;
  bool zobrazHoruceLen = false;
  bool tichyRezim = false;
  bool upozorneniaAktivne = true;

@override
void initState() {
  super.initState();
  nacitajZakazky();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final horuce = zakazky.where((z) => getRozdielDni(z.termin) <= 0).toList();
    if (!upozorneniaAktivne) return;

    if (!tichyRezim) {
      HapticFeedback.mediumImpact();
    }

    if (horuce.isNotEmpty) {
      HapticFeedback.mediumImpact(); // 💥 vibrovanie pri upozornení

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
    }
  });
}

  @override
  void dispose() {
    controller.dispose();
    emailController.dispose();
    super.dispose();
  }

  void pridajZakazku() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final nova = Zakazka(
      nazov: text,
      stav: vybranyStav,
      datum: DateFormat('d.M.yyyy').format(DateTime.now()),
      poznamka: '',
      hviezdicka: false,
      termin: '',
      dolezita: false,
    );

    setState(() {
      zakazky.add(nova);
      controller.clear();
    });

    ulozZakazky();
    ulozZalohuDoSuboru();
  }

void upravitZakazku(int index) {
  final zakazka = zakazky[index];
  final nazovCtrl = TextEditingController(text: zakazka.nazov);
  final poznamkaCtrl = TextEditingController(text: zakazka.poznamka);
  String lokalnyStav = zakazka.stav;
  String lokalnyTermin = zakazka.termin;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Upraviť zákazku'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: nazovCtrl,
              decoration: const InputDecoration(labelText: 'Názov'),
            ),
            TextField(
              controller: poznamkaCtrl,
              decoration: const InputDecoration(labelText: 'Poznámka'),
            ),
            DropdownButton<String>(
              value: lokalnyStav,
              isExpanded: true,
              onChanged: (val) => setState(() => lokalnyStav = val ?? 'Čaká'),
              items: ['Čaká', 'V riešení', 'Hotovo']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    lokalnyTermin.isEmpty
                        ? 'Žiadny termín'
                        : '📅 ${lokalnyTermin.split('T').first}',
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final vybrany = await showDatePicker(
                      context: context,
                      initialDate: lokalnyTermin.isNotEmpty
                          ? DateTime.tryParse(lokalnyTermin) ?? DateTime.now()
                          : DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (vybrany != null) {
                      setState(() {
                        lokalnyTermin = vybrany.toIso8601String();
                      });
                    }
                  },
                  child: const Text('Zmeniť termín'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              zakazky[index] = Zakazka(
                nazov: nazovCtrl.text.trim(),
                stav: lokalnyStav,
                datum: zakazka.datum,
                poznamka: poznamkaCtrl.text.trim(),
                termin: lokalnyTermin,
                hviezdicka: zakazka.hviezdicka,
                dolezita: zakazka.dolezita,
              );
            });
            ulozZakazky();
            Navigator.pop(context);
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

  void utriedZakazky() {
    zakazky.sort((a, b) {
      var aVal = a.termin;
      var bVal = b.termin;
      return vzostupne
          ? aVal.compareTo(bVal)
          : bVal.compareTo(aVal);
    });
    setState(() {});
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

    await Share.shareXFiles([XFile(file.path)],
      text: 'Tu sú moje zákazky vo formáte CSV');
  }

  Future<void> importujZakazkyZCSV() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/zakazky_export.csv');

      if (!await file.exists()) {
        debugPrint('CSV súbor neexistuje');
        return;
      }

      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content, eol: '\n');

      // preskoč hlavičku
      final data = rows.skip(1);

      zakazky.clear();

      for (final riadok in data) {
        zakazky.add(Zakazka(
          nazov: riadok[0] ?? '',
          stav: riadok[1] ?? '',
          datum: riadok[2] ?? '',
          poznamka: riadok[3] ?? '',
          termin: riadok[4] ?? '',
          hviezdicka: (riadok[5] == 'Áno'),
          dolezita: (riadok[6] == 'Áno'),
        ));
      }

      setState(() {}); // obnov UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zákazky boli načítané z CSV')),
      );
    } catch (e) {
      debugPrint('Chyba pri importe CSV: $e');
    }
  }

  Future<void> ulozZakazky() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = zakazky.map((z) => z.toJson()).toList();
      await prefs.setString('zakazky', jsonEncode(jsonData));
    } catch (e) {
      debugPrint('Chyba pri ukladaní: $e');
    }
  }

  Future<void> nacitajZakazky() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('zakazky');
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List;
        setState(() {
          zakazky = jsonList.map((z) => Zakazka.fromJson(z)).toList();
        });
        utriedZakazky();
      }
    } catch (e) {
      debugPrint('Chyba pri načítaní zo SharedPreferences: $e');
    }
  }

  Future<void> ulozZalohuDoSuboru() async {
    final adresar = await getApplicationDocumentsDirectory();
    final cesta = '${adresar.path}/zakazky_backup.json';
    final jsonData = zakazky.map((z) => z.toJson()).toList();
    final obsah = JsonEncoder.withIndent('  ').convert(jsonData);
    final subor = File(cesta);
    await subor.writeAsString(obsah);
    print('✅ Záloha vytvorená na: $cesta');
  }

  Future<void> posliZalohuEmailom(String email) async {
    final subor = File('/home/robo/Dokumenty/zakazky_backup.json');
    if (!await subor.exists()) {
      print('❌ Súbor neexistuje.');
      return;
    }

    final username = 'tvojemail@gmail.com';
    final heslo = 'tvoje_16znakove_app_password';
    final smtpServer = gmail(username, heslo);

    final message = Message()
      ..from = Address(username, 'Zákazková appka')
      ..recipients.add(email)
      ..subject = 'Záloha zákaziek'
      ..text = 'V prílohe je JSON so zákazkami.'
      ..attachments = [FileAttachment(subor)];

    final sendReport = await send(message, smtpServer);
    print('📤 Email odoslaný: $sendReport');
  }

  Future<void> zazalohujAVysli() async {
    final potvrdene = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Zadaj e-mail'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'napr. zakazky@firma.sk',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Zrušiť'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Odoslať'),
            ),
          ],
        );
      },
    );

    if (potvrdene != true) return;

    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❗ Zadaj platný e-mail')),
      );
      return;
    }

    ulozZalohuDoSuboru();
    await Future.delayed(Duration(milliseconds: 300));

    try {
      await posliZalohuEmailom(email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Záloha odoslaná na $email')),
      );
    } catch (e) {
      debugPrint('Chyba pri odoslaní: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Nepodarilo sa odoslať e-mail')),
      );
    }
  }

  void exportovatZakazky() {
    final jsonData = zakazky.map((z) => z.toJson()).toList();
    final jsonString = JsonEncoder.withIndent('  ').convert(jsonData);
    Clipboard.setData(ClipboardData(text: jsonString));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('📤 Export hotový – skopírované do schránky')),
    );
  }

void zobrazUpozornenia() {
  final upozornenia = ziskajUpozornenia();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('🔔 Upozornenia'),
      content: upozornenia.isEmpty
          ? const Text('Žiadne blížiace sa ani oneskorené zákazky.')
          : SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: upozornenia.map((z) {
                  return ListTile(
                    leading: Icon(Icons.warning, color: farbaPodlaTerminu(z.termin)),
                    title: Text(z.nazov), 
                    subtitle: Text(
                      '${z.datum} • ${getOdpocetText(z.termin)}',
                      style: TextStyle(
                        color: getFarbaOdpocet(z.termin),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      upravitZakazku(zakazky.indexOf(z));
                    },
                  );
                }).toList(),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zatvoriť'),
        ),
      ],
    ),
  );
}

  void importovatZakazky() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
      try {
        final jsonList = jsonDecode(data.text!) as List;
        final nove = jsonList.map((z) => Zakazka.fromJson(z)).toList();
        setState(() {
          zakazky.addAll(nove);
        });
        ulozZakazky();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📥 Import úspešný!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Chybný JSON pri importe.')),
        );
      }
    }
  }

Map<String, int> vypocitajStatistiky() {
  final celkom = zakazky.length;
  final hotovo = zakazky.where((z) => z.stav == 'Hotovo').length;
  final riesenie = zakazky.where((z) => z.stav == 'V riešení').length;
  final caka = zakazky.where((z) => z.stav == 'Čaká').length;
  final poTermine = zakazky
      .where((z) => getRozdielDni(z.termin) < 0)
      .length;
  final do2Dni = zakazky
      .where((z) => getRozdielDni(z.termin) <= 2 && getRozdielDni(z.termin) >= 0)
      .length;
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

Color getFarbaStatistiky(String typ, bool jeTmavyRezim) {
  if (jeTmavyRezim) {
    switch (typ) {
      case 'Po termíne':
        return Colors.red.shade800;
      case 'Do 2 dní':
        return Colors.orange.shade700;
      case 'Hotovo':
        return Colors.green.shade700;
      case 'Čaká':
        return Colors.yellow.shade700;
      case 'V riešení':
        return Colors.blue.shade700;
      case 'Bez poznámky':
        return Colors.grey.shade600;
      case 'Celkom':
      default:
        return Colors.blueGrey.shade700;
    }
  } else {
    switch (typ) {
      case 'Po termíne':
        return Colors.red.shade200;
      case 'Do 2 dní':
        return Colors.orange.shade200;
      case 'Hotovo':
        return Colors.green.shade200;
      case 'Čaká':
        return Colors.yellow.shade200;
      case 'V riešení':
        return Colors.blue.shade200;
      case 'Bez poznámky':
        return Colors.grey.shade300;
      case 'Celkom':
      default:
        return Colors.blueGrey.shade100;
    }
  }
}

List<Zakazka> vyfiltrovaneZakazky() {
  final text = vyhladavanieText.toLowerCase();

  final filtrovane = zakazky.where((z) {
    final splnaFilter =
        aktivnyFilter == 'Všetky' || z.stav == aktivnyFilter;

  final rozdiel = getRozdielDni(z.termin).toString();
  final splnaHladanie = vyhladavanieText.isEmpty ||
      z.nazov.toLowerCase().contains(text) ||
      z.poznamka.toLowerCase().contains(text) ||
      z.stav.toLowerCase().contains(text) ||
      z.datum.toLowerCase().contains(text) || // hľadanie podľa dátumu
      rozdiel.contains(text); // hľadanie podľa odpočtu

  final jeHoruca = getRozdielDni(z.termin) <= 2 || getRozdielDni(z.termin) < 0;

  return splnaFilter && splnaHladanie && (!zobrazHoruceLen || jeHoruca);
  }).toList();

  if (poleTriedenia == 'termin') {
    filtrovane.sort((a, b) => vzostupne
        ? a.termin.compareTo(b.termin)
        : b.termin.compareTo(a.termin));
  } else if (poleTriedenia == 'datum') {
    filtrovane.sort((a, b) => vzostupne
        ? a.datum.compareTo(b.datum)
        : b.datum.compareTo(a.datum));
  } else if (poleTriedenia == 'nazov') {
    filtrovane.sort((a, b) => vzostupne
        ? a.nazov.toLowerCase().compareTo(b.nazov.toLowerCase())
        : b.nazov.toLowerCase().compareTo(a.nazov.toLowerCase()));
  }

  return filtrovane;
}

List<Zakazka> ziskajUpozornenia() {
  final dnes = DateTime.now();

  return zakazky.where((z) {
    if (z.termin.isEmpty) return false;

    final termin = DateTime.tryParse(z.termin);
    if (termin == null) return false;

    final rozdiel = termin.difference(dnes).inDays;

    // 🔎 Zákazka sa zobrazí ako upozornenie ak:
    // - je oneskorená max 3 dni dozadu (napr. termín bol predvčerom)
    // - je termín dnes (rozdiel == 0)
    // - je termín v najbližších 1–2 dňoch (rozdiel == 1 alebo 2)
    return rozdiel >= -3 && rozdiel <= 2;
  }).toList();
}

int getRozdielDni(String terminText) {
  try {
    final termin = DateTime.parse(terminText);
    return termin.difference(DateTime.now()).inDays;
  } catch (_) {
    return 9999; // vráti vysoké číslo, aby sa nezaradil medzi vyhľadané
  }
}

  Color getFarbaPodlaStavu(String stav) {
    switch (stav) {
      case 'V riešení':
        return Colors.orange;
      case 'Hotovo':
        return Colors.green;
      case 'Čaká':
      default:
        return Colors.grey;
    }
  }

Color farbaPodlaTerminu(String terminText) {
  final dnes = DateTime.now();
  final termin = DateTime.tryParse(terminText);
  if (termin == null) return Colors.grey;

  final rozdiel = termin.difference(dnes).inDays;

  if (rozdiel < 0) return Colors.red.shade600;
  if (rozdiel == 0) return Colors.orange.shade700;
  return Colors.green.shade700;
}

  Color getFarbaOdpocet(String terminText) {
    try {
      final termin = DateTime.parse(terminText);
      final rozdiel = termin.difference(DateTime.now()).inDays;
      if (rozdiel < 0) return Colors.red;
      if (rozdiel == 0) return Colors.deepOrange;
      if (rozdiel <= 3) return Colors.amber;
      return Colors.green;
    } catch (_) {
      return Colors.transparent;
    }
  }

  String getOdpocetText(String terminText) {
    try {
      final termin = DateTime.parse(terminText);
      final rozdiel = termin.difference(DateTime.now()).inDays;
      if (rozdiel == 0) return '🔸 Dnes';
      if (rozdiel == 1) return 'Zajtra';
      if (rozdiel > 1) return 'O $rozdiel dní';
      if (rozdiel == -1) return 'Včera';
      return '${rozdiel.abs()} dní po termíne';
    } catch (_) {
      return '';
    }
  }

String formatujInfoZTterminu(String terminText) {
  final dnes = DateTime.now();
  final termin = DateTime.tryParse(terminText);
  if (termin == null) return 'Neplatný termín';

  final rozdiel = termin.difference(dnes).inDays;

  if (rozdiel < 0) return 'Oneskorené (pred ${rozdiel.abs()} ${rozdiel.abs() == 1 ? 'dňom' : 'dňami'})';
  if (rozdiel == 0) return 'Termín dnes';
  return 'Termín za $rozdiel ${rozdiel == 1 ? 'deň' : 'dni'}';
}

String exportujDoCSV(List<Zakazka> zakazky) {
  final buffer = StringBuffer();
  buffer.writeln('Názov,Stav,Dátum,Poznámka,Termín,Hviezdička,Dôležitá');

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


@override
Widget build(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context);
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
           upozorneniaAktivne ? Icons.notifications_active : Icons.notifications_off,
           color: upozorneniaAktivne ? Colors.orange : Colors.grey,
         ),
         tooltip: 'Upozornenia',
         onPressed: () => setState(() => upozorneniaAktivne = !upozorneniaAktivne),
      ),
       IconButton(
         icon: Icon(
           tichyRezim ? Icons.volume_off : Icons.vibration,
           color: tichyRezim ? Colors.grey : Colors.blue,
         ),
         tooltip: 'Tichý režim',
         onPressed: () => setState(() => tichyRezim = !tichyRezim),
       ),

      IconButton(
        icon: const Icon(Icons.notifications),
        tooltip: 'Upozornenia',
        onPressed: zobrazUpozornenia,
      ),
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: 'Vyhľadávanie',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => VyhladavanieScreen(zakazky: zakazky),
            ),
          );
        },
      ),

        PopupMenuButton<String>(
         icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
          tooltip: 'Nastavenia a akcie',
          onSelected: (value) async  {
            switch (value) {
              case 'export':
                exportovatZakazky();
                break;
              case 'import':
                importovatZakazky();
                break;
              case 'zalohuj':
                ulozZalohuDoSuboru();
                break;
              case 'obnov':
                nacitajZakazky();
                break;
              case 'email':
                zazalohujAVysli();
                break;
              case 'tema':
                themeProvider.toggleTheme(!isDark);
                break;
              case 'import_csv':
                await importujZakazkyZCSV();
                break;
              case 'share_csv':
                await ulozCSVASdielaj(zakazky);
                break;
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
              child: Row(
                children: [
                  Icon(Icons.file_download, size: 20),
                  SizedBox(width: 8),
                  Text('Export do CSV'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share_csv',
              child: ListTile(
                leading: Icon(Icons.share, color: Colors.blue),
                title: Text('Zdieľaj zákazky (CSV)'),
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
        const SizedBox(width: 8),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Zadaj názov zákazky',
                    suffixIcon: DropdownButton<String>(
                      value: vybranyStav,
                      onChanged: (val) => setState(() {
                        vybranyStav = val ?? 'Čaká';
                      }),
                      items: ['Čaká', 'V riešení', 'Hotovo']
                          .map((stav) => DropdownMenuItem(
                                value: stav,
                                child: Text(stav),
                              ))
                          .toList(),
                    ),
                  ),
                  onSubmitted: (_) => pridajZakazku(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: pridajZakazku,
                child: const Text('Pridať'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Všetky', 'Čaká', 'V riešení', 'Hotovo']
                .map(
                  (stav) => ChoiceChip(
                    label: Text(stav),
                    selected: aktivnyFilter == stav,
                    onSelected: (_) => setState(() => aktivnyFilter = stav),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                value: poleTriedenia,
                items: ['nazov', 'datum', 'termin']
                    .map((polozka) => DropdownMenuItem(
                          value: polozka,
                          child: Text(
                              'Podľa ${polozka[0].toUpperCase()}${polozka.substring(1)}'),
                        ))
                    .toList(),
                onChanged: (novy) {
                  setState(() => poleTriedenia = novy!);
                  utriedZakazky();
                },
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_upward,
                        color: vzostupne ? Colors.orange : Colors.grey),
                    tooltip: 'Zoradiť vzostupne',
                    onPressed: () {
                      setState(() => vzostupne = true);
                      utriedZakazky();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_downward,
                        color: !vzostupne ? Colors.orange : Colors.grey),
                    tooltip: 'Zoradiť zostupne',
                    onPressed: () {
                      setState(() => vzostupne = false);
                      utriedZakazky();
                    },
                  ),
                ],
              ),
            ],
          ),
const SizedBox(height: 12),
SwitchListTile(
  title: const Text('Zobraziť len horúce zákazky'),
  value: zobrazHoruceLen,
  onChanged: (val) => setState(() => zobrazHoruceLen = val),
  secondary: const Icon(Icons.local_fire_department, color: Colors.red),
),

Card(
  margin: const EdgeInsets.only(bottom: 12),
  color: Colors.grey.shade100,
  elevation: 2,
  child: Padding(
    padding: const EdgeInsets.all(8.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
Text(
  '📊 Štatistiky zákaziek',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.indigo.shade200
        : Colors.indigo.shade700,
  ),
),
        const SizedBox(height: 4),
Wrap(
  spacing: 12,
  runSpacing: 4,
  children: stats.entries.map((entry) {
    final farba = getFarbaStatistiky(entry.key, jeTmavyRezim);
    return Chip(
      label: Text('${entry.key}: ${entry.value}'),
      backgroundColor: farba,
      labelStyle: const TextStyle(fontSize: 12),                         
            );
          }).toList(),
        ),
      ],
    ),
  ),
),

const SizedBox(height: 12),
VyhladavanieField(
  controller: vyhladavanieController,
  onChanged: (val) {
    setState(() => vyhladavanieText = val.toLowerCase());
  },
  onClear: () {
    vyhladavanieController.clear();
    setState(() => vyhladavanieText = '');
  },
),

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
                            child: const Icon(Icons.build,
                                color: Colors.white),
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
    if (z.poznamka.isNotEmpty)
      Text(z.poznamka),
    Text(
      z.datum,
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    ),
    if (z.termin.isNotEmpty && DateTime.tryParse(z.termin) != null)
      Text(
        '${getRozdielDni(z.termin)}',
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
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
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
}
