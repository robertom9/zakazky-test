import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Premium funkcie"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          PremiumTile(
            icon: Icons.picture_as_pdf,
            title: "Export do PDF",
            subtitle: "Ulož zákazky v profesionálnom formáte",
          ),
          PremiumTile(
            icon: Icons.cloud_upload,
            title: "Záloha do cloudu",
            subtitle: "Synchronizácia naprieč zariadeniami",
          ),
          PremiumTile(
            icon: Icons.bar_chart,
            title: "Rozšírený dashboard",
            subtitle: "Podrobné štatistiky a trendy",
          ),
          PremiumTile(
            icon: Icons.receipt_long,
            title: "Fakturácia",
            subtitle: "Generovanie faktúr zo zákaziek",
          ),
          PremiumTile(
            icon: Icons.block,
            title: "Bez reklám",
            subtitle: "Pracuj bez rušivých prvkov",
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: null, // zatiaľ deaktivované
            child: Text("Aktivovať Premium (čoskoro)"),
          ),
        ],
      ),
    );
  }
}

class PremiumTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const PremiumTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.orange),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Chip(
          label: Text("PREMIUM"),
          backgroundColor: Colors.deepOrange,
          labelStyle: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
