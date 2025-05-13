import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
      ),
      body: Column(
        children: [
          ListTile(
            title: const Text('Tema'),
            subtitle: const Text('Selecciona el tema de la aplicación'),
            trailing: DropdownButton<AppThemeMode>(
              value: themeProvider.appThemeMode,
              items: const [
                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text('Claro'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.dark,
                  child: Text('Oscuro'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text('Automático'),
                ),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  themeProvider.setTheme(mode);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}