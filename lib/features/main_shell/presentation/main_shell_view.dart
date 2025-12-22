import 'package:flutter/material.dart';
import 'package:bestie/features/home/presentation/home_view.dart';
import 'package:bestie/features/moment/presentation/moment_view.dart';
import 'package:bestie/features/chat/presentation/chat_view.dart';
import 'package:bestie/features/profile/presentation/profile_view.dart';
import 'package:bestie/core/constants/app_strings.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/calling/presentation/widgets/call_listener.dart';
import 'package:bestie/features/chat/presentation/widgets/chat_notification_listener.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends State<MainShellView> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeView(),
    MomentView(),
    ChatView(),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return ChatNotificationListener(
      child: CallListener(
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: SvgPicture.asset(
                'assets/images/icons/home-2.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
              ),
              activeIcon: SvgPicture.asset(
                'assets/images/icons/home-2 (1).svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
              ),
              label: AppStrings.navHome,
            ),
            BottomNavigationBarItem(
              icon: SvgPicture.asset(
                'assets/images/icons/camera.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
              ),
              activeIcon: SvgPicture.asset(
                'assets/images/icons/camera (1).svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
              ),
              label: AppStrings.navMoment,
            ),
            BottomNavigationBarItem(
              icon: Consumer(
                builder: (context, ref, child) {
                  final unreadCount = ref.watch(totalUnreadMessagesProvider);
                  return Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text('$unreadCount'),
                    child: SvgPicture.asset(
                      'assets/images/icons/chatbox (1).svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    ),
                  );
                },
              ),
              activeIcon: Consumer(
                builder: (context, ref, child) {
                   final unreadCount = ref.watch(totalUnreadMessagesProvider);
                   return Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text('$unreadCount'),
                    child: SvgPicture.asset(
                      'assets/images/icons/chatbox.svg',
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
                    ),
                   );
                },
              ),
              label: AppStrings.navChat,
            ),
            BottomNavigationBarItem(
              icon: SvgPicture.asset(
                'assets/images/icons/user-square.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
              ),
              activeIcon: SvgPicture.asset(
                'assets/images/icons/user-square(1).svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
              ),
              label: AppStrings.navProfile,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
