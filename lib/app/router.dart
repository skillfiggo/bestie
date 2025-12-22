import 'package:flutter/material.dart';
import 'package:bestie/features/splash/presentation/splash_view.dart';
import 'package:bestie/features/auth/presentation/screens/auth_landing_screen.dart';
import 'package:bestie/features/auth/presentation/auth_view.dart';
import 'package:bestie/features/onboarding/presentation/onboarding_view.dart';
import 'package:bestie/features/main_shell/presentation/main_shell_view.dart';
import 'package:bestie/features/home/presentation/home_view.dart';
import 'package:bestie/features/moment/presentation/moment_view.dart';
import 'package:bestie/features/chat/presentation/chat_view.dart';
import 'package:bestie/features/profile/presentation/profile_view.dart';

class AppRouter {
  static const String splash = '/';
  static const String auth = '/auth'; // Now points to Landing
  static const String authForms = '/auth/forms'; // Points to Tabs (Login/Signup)
  static const String onboarding = '/onboarding';
  static const String mainShell = '/main';
  static const String home = '/home';
  static const String moment = '/moment';
  static const String chat = '/chat';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashView(),
        auth: (_) => const AuthLandingScreen(),
        authForms: (_) => const AuthView(),
        onboarding: (_) => const OnboardingView(),
        mainShell: (_) => const MainShellView(),
        home: (_) => const HomeView(),
        moment: (_) => const MomentView(),
        chat: (_) => const ChatView(),
        profile: (_) => const ProfileView(),
      };
}
