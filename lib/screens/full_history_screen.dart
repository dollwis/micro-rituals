import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ritual_history_list.dart';
import '../widgets/mini_audio_player.dart';

class FullHistoryScreen extends StatelessWidget {
  const FullHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Ritual History',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.getTextColor(context),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.getTextColor(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        child: const RitualHistoryList(limit: 100),
      ),
      bottomNavigationBar: const MiniAudioPlayer(),
    );
  }
}
