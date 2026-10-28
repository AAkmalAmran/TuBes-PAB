import 'package:flutter/material.dart';
import '../widgets/responsive_body.dart';

class TemplateDashboardScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode currentThemeMode;

  const TemplateDashboardScreen({
    super.key,
    required this.onToggleTheme,
    required this.currentThemeMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FinQuest Dashboard',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: currentThemeMode == ThemeMode.dark
                ? 'Beralih ke Mode Terang'
                : 'Beralih ke Mode Gelap',
            icon: Icon(
              currentThemeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: onToggleTheme,
          ),
        ],
      ),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Hero Status Banner (Modifikasi dari Header Card Template)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    child: const Icon(Icons.shield, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pahlawan Finansial',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Level 3 · Pelindung Dana Darurat',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bagian Ringkasan Saldo (Modifikasi Card List)
            Text(
              'Ringkasan Keuangan',
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Card(
              color: colorScheme.surfaceVariant,
              child: ListTile(
                leading: Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.primary,
                  size: 32,
                ),
                title: Text(
                  'Total Tabungan',
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Progres target: 70%', style: textTheme.bodySmall),
                trailing: Text(
                  'Rp 1.500.000',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            Card(
              color: colorScheme.surfaceVariant,
              child: ListTile(
                leading: Icon(
                  Icons.shopping_bag_outlined,
                  color: colorScheme.error,
                  size: 32,
                ),
                title: Text(
                  'Batas Pengeluaran Hari Ini',
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Tersisa Rp 25.000 dari Rp 50.000', style: textTheme.bodySmall),
                trailing: Text(
                  '-Rp 25.000',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Kartu Misi Gamifikasi
            Card(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt, color: colorScheme.tertiary),
                        const SizedBox(width: 8),
                        Text(
                          'Misi Aktif: Taklukkan Monster Kopi',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tahan pengeluaran kopi kekinian selama 3 hari untuk mempertahankan HP Hero.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {},
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Klaim Misi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}