import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(home: ZakazkyApp()));
}

class ZakazkyApp extends StatefulWidget {
  @override
  _ZakazkyAppState createState() => _ZakazkyAppState();
}

class _ZakazkyAppState extends State<ZakazkyApp> {
  final List<Map<String, String>> zakazky = [];
  final TextEditingController controller = TextEditingController();
  String vybranyStav = 'Čaká';

  void pridajZakazku() {
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      print('Pridávam: $text ($vybranyStav)');
      setState(() {
        zakazky.add({
          'nazov': text,
          'stav': vybranyStav,
        });
      });
      controller.clear();
      vybranyStav = 'Čaká';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Zákazky so stavom')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(labelText: 'Názov zákazky'),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: pridajZakazku,
                      child: Text('Pridať'),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                DropdownButton<String>(
                  value: vybranyStav,
                  items: ['Čaká', 'V riešení', 'Hotovo']
                      .map((stav) => DropdownMenuItem(
                            value: stav,
                            child: Text(stav),
                          ))
                      .toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() {
                        vybranyStav = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Celkový počet: ${zakazky.length}'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: zakazky.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(zakazky[index]['nazov'] ?? ''),
                subtitle: Text('Stav: ${zakazky[index]['stav'] ?? ''}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
