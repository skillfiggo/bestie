import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/app/app.dart';
import 'package:bestie/core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Supabase
    await SupabaseService.initialize();
  } catch (e) {
    print('Failed to initialize Supabase: $e');
    print('The app will continue with limited functionality.');
    print('Please check your .env file and Supabase credentials.');
  }
  
  runApp(
    const ProviderScope(
      child: BestieApp(),
    ),
  );
}

