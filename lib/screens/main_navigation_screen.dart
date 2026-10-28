import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/responsive_body.dart';
import 'auth/login_screen.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({
    super.key,
    required this.namaPahlawan,
    required this.email,
  });

  final String namaPahlawan;
  final String email;

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
          // Tombol Beralih Mode Terang / Gelap (Tugas W6)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return IconButton(
                tooltip: isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () {
                  themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                },
              );
            },
          ),
          // Tombol Logout (Tugas W5)
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Banner Hero Profil (Menggunakan data login W5 & Aksen Template W6)
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
                          'Pahlawan $namaPahlawan',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Level 3 · Pelindung Anggaran',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Modifikasi Template: Ringkasan Saldo & Anggaran
            Text(
              'Ringkasan Keuangan (Template M3)',
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Kartu Tabungan
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
                subtitle: const Text('Target bulanan tercapai 78%'),
                trailing: Text(
                  'Rp 2.450.000',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Kartu Batas Harian
            Card(
              color: colorScheme.surfaceVariant,
              child: ListTile(
                leading: Icon(
                  Icons.shopping_bag_outlined,
                  color: colorScheme.error,
                  size: 32,
                ),
                title: Text(
                  'Sisa Anggaran Hari Ini',
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Batas harian: Rp 50.000'),
                trailing: Text(
                  'Rp 25.000',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Modifikasi Template: Kartu Misi Gamifikasi
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
                          'Misi Aktif: Lawan Monster Kopi',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tahan godaan kopi kekinian selama 3 hari untuk melindungi HP Hero.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Progres misi berhasil diperbarui!')),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Klaim Misi Hari Ini'),
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