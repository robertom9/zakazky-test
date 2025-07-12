import 'package:flutter/material.dart';
import '../modely/zakazka.dart';

class VyhladavanieScreen extends StatefulWidget {
  final List<Zakazka> zakazky;

  const VyhladavanieScreen({super.key, required this.zakazky});

  @override
  State<VyhladavanieScreen> createState() => _VyhladavanieScreenState();
}

class _VyhladavanieScreenState extends State<VyhladavanieScreen> {
  String hladanyText = '';
  String vybranyStav = 'Všetky';
  final List<String> historia = [];

  @override
  Widget build(BuildContext context) {
    final vysledky = widget.zakazky.where((z) {
      final stavOK = vybranyStav == 'Všetky' || z.stav == vybranyStav;
      final textOK = hladanyText.isEmpty || z.nazov.toLowerCase().contains(hladanyText.toLowerCase());
      return stavOK && textOK;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Vyhľadávanie'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Zadaj názov'),
              onChanged: (val) => setState(() => hladanyText = val),
              onSubmitted: (val) {
                setState(() {
                  hladanyText = val;
                  if (val.trim().isNotEmpty && !historia.contains(val.trim())) {
                    historia.add(val.trim());
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: vybranyStav,
              isExpanded: true,
              items: ['Všetky', 'Čaká', 'V riešení', 'Hotovo'].map((stav) {
                return DropdownMenuItem<String>(
                  value: stav,
                  child: Text(stav),
                );
              }).toList(),
              onChanged: (val) => setState(() => vybranyStav = val ?? 'Všetky'),
            ),
            const SizedBox(height: 12),
            if (historia.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('História:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Wrap(
                spacing: 8,
                children: historia.reversed.map((text) {
                  return ActionChip(
                    label: Text(text),
                    onPressed: () => setState(() => hladanyText = text),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: vysledky.length,
                itemBuilder: (context, index) {
                  final z = vysledky[index];
                  return ListTile(
                    title: Text(z.nazov),
                    subtitle: Text('Stav: ${z.stav} • Termín: ${z.termin}'),
                    onTap: () {
                      Navigator.of(context).pop();
                      // upravitZakazku(widget.zakazky.indexOf(z)); // odkomentuj, ak máš túto funkciu
                    },
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
