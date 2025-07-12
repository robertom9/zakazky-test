import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MaterialApp(
    home: ZakazkyApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class ZakazkyApp extends StatefulWidget {
  @override
  _ZakazkyAppState createState() => _ZakazkyAppState();
}

class _ZakazkyAppState extends State<ZakazkyApp> {
  List<Map<String, String>> zakazky = [];
  String aktivnyFilter = 'Všetky';
  String vybranyStav = 'Čaká';
  String vyhladavanieText = '';
  String poradie = 'žiadne';

  final controller = TextEditingController();

  List<Map<String, String>> get zakazkyFiltrovanie {
    final vyfiltrovane = zakazky.where((z) {
      final stavZhodny = aktivnyFilter == 'Všetky' || z['stav'] == aktivnyFilter;
      final textZhodny = z['nazov']?.toLowerCase().contains(vyhladavanieText.toLowerCase()) ?? false;
      return stavZhodny && textZhodny;
    }).toList();

    if (poradie == 'vzostupne') {
      vyfiltrovane.sort((a, b) => (a['termin'] ?? '').compareTo(b['termin'] ?? ''));
    } else if (poradie == 'klesajúco') {
      vyfiltrovane.sort((a, b) => (b['termin'] ?? '').compareTo(a['termin'] ?? ''));
    }

    return vyfiltrovane;
  }

  void pridajZakazku() {
    final nazov = controller.text.trim();
    if (nazov.isEmpty) return;

    setState(() {
      zakazky.add({
        'nazov': nazov,
        'stav': vybranyStav,
        'datum': DateFormat('d.M.yyyy').format(DateTime.now()),
        'poznamka': '',
        'termin': '',
        'dolezita': 'false',
      });
      controller.clear();
    });

    ulozZakazky();
  }

  void ulozZakazky() {
    // Môžeš sem pridať trvalé uloženie (napr. SharedPreferences)
  }

  String getOdpocetText(String? datumStr) {
    if (datumStr == null || datumStr.isEmpty) return '';
    final datum = DateTime.tryParse(datumStr);
    if (datum == null) return '';
    final rozdiel = datum.difference(DateTime.now()).inDays;
    if (rozdiel < 0) return 'Po termíne';
    if (rozdiel == 0) return 'Dnes!';
    return 'O $rozdiel dní';
  }

  Color getFarbaOdpocet(String? datumStr) {
    if (datumStr == null || datumStr.isEmpty) return Colors.grey;
    final datum = DateTime.tryParse(datumStr);
    if (datum == null) return Colors.grey;
    final rozdiel = datum.difference(DateTime.now()).inDays;
    if (rozdiel < 0) return Colors.red;
    if (rozdiel == 0) return Colors.orange;
    return Colors.green;
  }

  Color getFarbaPodlaStavu(String? stav) {
    switch (stav) {
      case 'Hotovo':
        return Colors.green;
      case 'V riešení':
        return Colors.orange;
      case 'Čaká':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
  void exportujZakazky() {
    final json = JsonEncoder.withIndent('  ').convert(zakazky);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export zákaziek'),
        content: SingleChildScrollView(child: SelectableText(json)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Skopírované do schránky')),
              );
            },
            child: Text('Kopírovať'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Zatvoriť'),
          ),
        ],
      ),
    );
  }

  void importujZakazky() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Import zákaziek'),
        content: TextField(
          controller: textController,
          maxLines: 10,
          decoration: InputDecoration(hintText: 'Vlož JSON sem'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              try {
                final parsed = jsonDecode(textController.text);
                if (parsed is List) {
                  final loaded = parsed.map((e) {
                    final map = Map<String, dynamic>.from(e);
                    return {
                      'nazov': map['nazov'] ?? '',
                      'stav': map['stav'] ?? 'Čaká',
                      'datum': map['datum'] ?? '',
                      'poznamka': map['poznamka'] ?? '',
                      'termin': map['termin'] ?? '',
                      'dolezita': map['dolezita']?.toString() ?? 'false',
                    };
                  }).toList();
                  setState(() => zakazky = List<Map<String, String>>.from(loaded));
                  ulozZakazky();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Import úspešný')),
                  );
                } else {
                  throw Exception();
                }
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Neplatný JSON')),
                );
              }
            },
            child: Text('Načítať'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Zrušiť'),
          ),
        ],
      ),
    );
  }

  void exportujCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Názov,Stav,Dátum');
    for (var z in zakazky) {
      final nazov = z['nazov']?.replaceAll(',', ' ') ?? '';
      final stav = z['stav'] ?? '';
      final datum = z['datum'] ?? '';
      buffer.writeln('$nazov,$stav,$datum');
    }
    final csv = buffer.toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export CSV'),
        content: SingleChildScrollView(child: SelectableText(csv)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('CSV skopírovaný')),
              );
            },
            child: Text('Kopírovať'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Zatvoriť'),
          ),
        ],
      ),
    );
  }

  void upravitZakazku(int index) {
    final zakazka = zakazky[index];
    final controllerEdit = TextEditingController(text: zakazka['nazov'] ?? '');
    final controllerPoznamka = TextEditingController(text: zakazka['poznamka'] ?? '');
    String novyStav = zakazka['stav'] ?? 'Čaká';
    DateTime? zvolenyTermin = zakazka['termin'] != null && zakazka['termin']!.isNotEmpty
        ? DateTime.tryParse(zakazka['termin']!)
        : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Upraviť zákazku'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controllerEdit,
                    decoration: InputDecoration(labelText: 'Nový názov'),
                  ),
                  DropdownButtonFormField<String>(
                    value: novyStav,
                    decoration: InputDecoration(labelText: 'Zmeniť stav'),
                    onChanged: (val) => setStateDialog(() => novyStav = val ?? 'Čaká'),
                    items: ['V riešení', 'Čaká', 'Hotovo']
                        .map((stav) => DropdownMenuItem(value: stav, child: Text(stav)))
                        .toList(),
                  ),
                  TextField(
                    controller: controllerPoznamka,
                    decoration: InputDecoration(labelText: 'Poznámka'),
                    maxLines: 3,
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          zvolenyTermin != null
                              ? 'Termín: ${DateFormat('d.M.yyyy').format(zvolenyTermin!)}'
                              : 'Bez termínu',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final vybrany = await showDatePicker(
                            context: context,
                            initialDate: zvolenyTermin ?? DateTime.now(),
                            firstDate: DateTime(2023),
                            lastDate: DateTime(2100),
                          );
                          if (vybrany != null) {
                            setStateDialog(() => zvolenyTermin = vybrany);
                          }
                        },
                        child: Text('Vybrať termín'),
                      ),
                      if (zvolenyTermin != null)
                        TextButton(
                          onPressed: () => setStateDialog(() => zvolenyTermin = null),
                          child: Text('Zmazať'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final upraveny = controllerEdit.text.trim();
                  if (upraveny.isNotEmpty) {
                    setState(() {
                      zakazky[index]['nazov'] = upraveny;
                      zakazky[index]['stav'] = novyStav;
                      zakazky[index]['poznamka'] = controllerPoznamka.text.trim();
                      zakazky[index]['termin'] = zvolenyTermin?.toIso8601String() ?? '';
                    });
                    ulozZakazky();
                  }
                  Navigator.pop(context);
                },
                child: Text('Uložiť'),
              ),
              TextButton(
                onPressed: () {
                  setState(() => zakazky.removeAt(index));
                  ulozZakazky();
                  Navigator.pop(context);
                },
                child: Text('Zmazať'),
              ),
            ],
          );
        },
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zákazky'),
        actions: [
          IconButton(
            onPressed: exportujZakazky,
            icon: Icon(Icons.cloud_upload),
            tooltip: 'Exportovať JSON',
          ),
          IconButton(
            onPressed: importujZakazky,
            icon: Icon(Icons.cloud_download),
            tooltip: 'Importovať JSON',
          ),
          IconButton(
            onPressed: exportujCSV,
            icon: Icon(Icons.table_chart),
            tooltip: 'Exportovať CSV',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                if (poradie == 'žiadne') poradie = 'vzostupne';
                else if (poradie == 'vzostupne') poradie = 'klesajúco';
                else poradie = 'žiadne';
              });
            },
            icon: Icon(
              poradie == 'vzostupne'
                  ? Icons.arrow_upward
                  : poradie == 'klesajúco'
                      ? Icons.arrow_downward
                      : Icons.sort,
            ),
            tooltip: 'Zoradiť podľa termínu',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Zadaj názov zákazky',
                        suffixIcon: DropdownButton<String>(
                          value: vybranyStav,
                          onChanged: (val) => setState(() => vybranyStav = val ?? 'Čaká'),
                          items: ['V riešení', 'Čaká', 'Hotovo']
                              .map((stav) => DropdownMenuItem(value: stav, child: Text(stav)))
                              .toList(),
                        ),
                      ),
                      onSubmitted: (_) => pridajZakazku(),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: pridajZakazku,
                    child: Text('Pridať'),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: ['Všetky', 'V riešení', 'Čaká', 'Hotovo']
                  .map((stav) => ChoiceChip(
                        label: Text(stav),
                        selected: aktivnyFilter == stav,
                        onSelected: (_) => setState(() => aktivnyFilter = stav),
                      ))
                  .toList(),
            ),
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: TextField(
                decoration: InputDecoration(labelText: 'Vyhľadávanie'),
                onChanged: (val) => setState(() => vyhladavanieText = val.trim()),
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: zakazkyFiltrovanie.length,
                itemBuilder: (_, index) {
                  final z = zakazkyFiltrovanie[index];
                  return Container(
                    constraints: BoxConstraints(minHeight: 76),
                    padding: EdgeInsets.symmetric(vertical: 4),
                    color: z['dolezita'] == 'true' ? Colors.yellow[50] : null,
                    child: ListTile(
                      isThreeLine: true,
                      title: Text(z['nazov'] ?? ''),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((z['poznamka'] ?? '').isNotEmpty)
                            Text(z['poznamka']!, style: TextStyle(color: Colors.grey[700])),
                          Text(z['datum'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          if (z['termin'] != null && z['termin']!.isNotEmpty)
                            Text(
                              getOdpocetText(z['termin']),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: getFarbaOdpocet(z['termin']),
                              ),
                            ),
                        ],
                      ),
                      leading: CircleAvatar(
                        backgroundColor: getFarbaPodlaStavu(z['stav']),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(z['stav'] ?? '', style: TextStyle(fontSize: 12)),
                          IconButton(
                            icon: Icon(
                              z['dolezita'] == 'true' ? Icons.star : Icons.star_border,
                              color: z['dolezita'] == 'true' ? Colors.amber : Colors.grey,
                            ),
                            iconSize: 20,
                            tooltip: 'Označiť ako dôležité',
                            onPressed: () {
                              setState(() {
                                final i = zakazky.indexOf(z);
                                zakazky[i]['dolezita'] =
                                    (zakazky[i]['dolezita'] == 'true') ? 'false' : 'true';
                              });
                              ulozZakazky();
                            },
                          ),
                        ],
                      ),
                      onTap: () => upravitZakazku(zakazky.indexOf(z)),
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
