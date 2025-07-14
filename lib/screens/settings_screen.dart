import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zakazky_test/screens/premium_screen.dart';
import 'package:zakazky_test/providers/rezim_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rezim = Provider.of<RezimProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nastavenia"),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            title: const Text('Tichý režim'),
            value: rezim.tichyRezim,
            onChanged: (val) => rezim.setTichy(val),
            secondary: const Icon(Icons.volume_off),
          ),
          SwitchListTile(
            title: const Text('Vibrácie'),
            value: rezim.vibracie,
            onChanged: (val) => rezim.setVibracie(val),
            secondary: const Icon(Icons.vibration),
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.star, color: Colors.orange),
            title: const Text("Premium funkcie"),
            subtitle: const Text("Zobraziť rozšírené možnosti appky"),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PremiumScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
