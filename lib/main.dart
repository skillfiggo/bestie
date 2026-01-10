import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bestie/app/app.dart';
import 'package:bestie/core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('⚠️ Warning: Failed to load .env file: $e');
    debugPrint('Using defaults or waiting for manual configuration.');
  }
  
  try {
    // Initialize Supabase
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
    debugPrint('The app will continue with limited functionality.');
    debugPrint('Please check your .env file and Supabase credentials.');
  }
  
  runApp(
    const ProviderScope(
      child: BestieApp(),
    ),
  );
}

