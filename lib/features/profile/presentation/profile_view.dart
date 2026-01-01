import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bestie/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:bestie/features/profile/presentation/screens/recharge_coins_screen.dart';
import 'package:bestie/features/profile/presentation/screens/withdraw_diamonds_screen.dart';
import 'package:bestie/features/profile/presentation/screens/settings_screen.dart';
import 'package:bestie/features/visitor/presentation/visitor_view.dart';
import 'package:bestie/features/social/data/providers/follow_providers.dart';
import 'package:bestie/features/social/data/providers/friendship_providers.dart';
import 'package:bestie/features/social/presentation/screens/followers_following_screen.dart';
import 'package:bestie/features/moment/presentation/widgets/moment_card.dart';
import 'package:bestie/features/moment/data/providers/moment_providers.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 600, // Increased height for Check-in card
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                title: Text(
                  innerBoxIsScrolled ? 'My Profile' : '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.history_rounded, color: AppColors.textPrimary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VisitorView(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, color: AppColors.textPrimary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
                    onPressed: () {
                      Share.share('Check out my profile on Bestie! Connect with me to see my moments and adventures.');
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: profileAsync.when(
                    data: (profile) {
                      if (profile == null) {
                         return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Profile not found', style: TextStyle(color: Colors.black)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () async {
                                  final user = ref.read(authRepositoryProvider).getCurrentUser();
                                  if (user != null) {
                                    await ref.read(authRepositoryProvider).createProfile(user.id, {
                                      'name': user.userMetadata?['name'] ?? 'User',
                                      'age': user.userMetadata?['age'] ?? 18,
                                    });
                                  }
                                },
                                child: const Text('Force Create Profile'),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          // Cover Photo & Avatar Stack
                          SizedBox(
                            height: 210, // Reduced height
                            child: Stack(
                               clipBehavior: Clip.none,
                              children: [
                                // Cover Photo
                                Container(
                                  height: 150, // Reduced height
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: profile.coverPhotoUrl.isNotEmpty
                                          ? NetworkImage(profile.coverPhotoUrl)
                                          : const NetworkImage(
                                              'https://images.unsplash.com/photo-1507525428034-b723cf961d3e', // Default
                                            ),
                                      fit: BoxFit.cover,
                                    ),
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                // Profile Avatar
                                Positioned(
                                  bottom: 0,
                                  left: 20,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white, width: 4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundImage: profile.avatarUrl.isNotEmpty
                                          ? NetworkImage(profile.avatarUrl)
                                          : null,
                                      child: profile.avatarUrl.isEmpty
                                          ? Text(profile.name.isNotEmpty ? profile.name[0] : '?', style: const TextStyle(fontSize: 30))
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Info Section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                '${profile.name}, ${profile.age}',
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (profile.isVerified)
                                            const Icon(Icons.verified, color: Colors.blue, size: 20),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: profile.gender.toLowerCase() == 'female' 
                                                  ? Colors.pink.shade50 
                                                  : Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              profile.gender.toLowerCase() == 'female' 
                                                  ? Icons.female 
                                                  : Icons.male,
                                              color: profile.gender.toLowerCase() == 'female' 
                                                  ? Colors.pink
                                                  : Colors.blue.shade700,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 8), // Add spacing before button
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EditProfileScreen(
                                              initialProfile: profile,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: SvgPicture.asset(
                                        'assets/images/icons/edit-2.svg',
                                        width: 24,
                                        height: 24,
                                        colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: profile.bestieId.isNotEmpty ? profile.bestieId : profile.id));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('ID copied to clipboard')),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        'ID: ${profile.bestieId.isNotEmpty ? profile.bestieId : profile.id.substring(0, 8)}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const FaIcon(FontAwesomeIcons.copy, size: 14, color: Colors.grey),
                                    ],
                                  ),
                                ),
                                  const SizedBox(height: 12),
                                // Stats Row
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FollowersFollowingScreen(
                                              userId: profile.id,
                                              initialTabIndex: 0,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final followerCountAsync = ref.watch(followerCountProvider(profile.id));
                                          return followerCountAsync.when(
                                            data: (count) => _buildStat(count.toString(), 'Followers'),
                                            loading: () => _buildStat('...', 'Followers'),
                                            error: (_, __) => _buildStat('0', 'Followers'),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FollowersFollowingScreen(
                                              userId: profile.id,
                                              initialTabIndex: 1,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final followingCountAsync = ref.watch(followingCountProvider(profile.id));
                                          return followingCountAsync.when(
                                            data: (count) => _buildStat(count.toString(), 'Following'),
                                            loading: () => _buildStat('...', 'Following'),
                                            error: (_, __) => _buildStat('0', 'Following'),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FollowersFollowingScreen(
                                              userId: profile.id,
                                              initialTabIndex: 2,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final friendsCountAsync = ref.watch(friendsCountProvider(profile.id));
                                          return friendsCountAsync.when(
                                            data: (count) => _buildStat(count.toString(), 'Friends'),
                                            loading: () => _buildStat('...', 'Friends'),
                                            error: (_, __) => _buildStat('0', 'Friends'),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FollowersFollowingScreen(
                                              userId: profile.id,
                                              initialTabIndex: 3,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final bestiesCountAsync = ref.watch(bestiesCountProvider(profile.id));
                                          return bestiesCountAsync.when(
                                            data: (count) => _buildStat(count.toString(), 'Bestie'),
                                            loading: () => _buildStat('...', 'Bestie'),
                                            error: (_, __) => _buildStat('0', 'Bestie'),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Daily Check-in
                                _buildCheckInCard(context, ref, profile),
                                // Wallet Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const RechargeCoinsScreen(),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.orange.shade50,
                                                Colors.orange.shade100.withValues(alpha: 0.5),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.orange.shade100, width: 1.5),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.monetization_on_rounded, color: Colors.orange, size: 24),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${profile.coins}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Coins',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey.shade600,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const WithdrawDiamondsScreen(),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.blue.shade50,
                                                Colors.blue.shade100.withValues(alpha: 0.5),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.blue.shade100, width: 1.5),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.diamond_rounded, color: Colors.blue, size: 24),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${profile.diamonds}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Diamonds',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey.shade600,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Container(
                    color: Colors.white,
                    child: const TabBar(
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      tabs: [
                        Tab(text: 'About'),
                        Tab(text: 'Moments'),
                        Tab(text: 'Gallery'),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: profileAsync.when(
            data: (profile) {
              if (profile == null) {
                return const Center(child: Text('Profile not found'));
              }
              return TabBarView(
                children: [
                  _buildAboutTab(profile),
                  _buildMomentsTab(ref, profile.id),
                  const Center(child: Text('Gallery Content')), // Placeholder for gallery
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading profile content')),
          ),
        ),
      ),
    );
  }

  Widget _buildMomentsTab(WidgetRef ref, String userId) {
    final momentsAsync = ref.watch(userMomentsProvider(userId));

    return momentsAsync.when(
      data: (moments) {
        if (moments.isEmpty) {
          return const Center(
            child: Text(
              'No moments yet',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(0),
          itemCount: moments.length,
          itemBuilder: (context, index) {
            final moment = moments[index];
            return MomentCard(moment: moment);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTab(profile) {
    if (profile == null) return const SizedBox.shrink();
    
     return SingleChildScrollView(
       padding: const EdgeInsets.all(20),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           if (profile.bio.isNotEmpty) ...[
             const Text(
               'About Me',
               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             Text(
               profile.bio,
               style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
             ),
              const SizedBox(height: 24),
            ],
            
            if (profile.lookingFor.isNotEmpty) ...[
               const Text(
                'Looking For',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.pink.shade100),
                ),
                child: Text(
                  profile.lookingFor,
                  style: TextStyle(
                    fontSize: 15, 
                    color: Colors.pink.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            if (profile.interests.isNotEmpty) ...[
              const Text(
               'Interests',
               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 12),
             Wrap(
               spacing: 8,
               runSpacing: 8,
               children: profile.interests.map<Widget>((interest) {
                 return _buildInterestChip(interest);
               }).toList(),
             ),
           ],

            if (profile.occupation.isNotEmpty) ...[
             const SizedBox(height: 24),
             const Text(
               'Occupation',
               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             Text(
               profile.occupation,
               style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
             ),
           ],
             if (profile.locationName.isNotEmpty) ...[
             const SizedBox(height: 24),
             const Text(
               'Location',
               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             Text(
               profile.locationName,
               style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
             ),
           ],
         ],
       ),
     );
  }

  Widget _buildInterestChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  Widget _buildCheckInCard(BuildContext context, WidgetRef ref, dynamic profile) {
     final bool checkedIn = _isCheckedInToday(profile.lastCheckIn);
     
     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
       decoration: BoxDecoration(
         gradient: LinearGradient(
           colors: [Colors.purple.shade50, Colors.purple.shade100.withValues(alpha: 0.5)],
         ),
         borderRadius: BorderRadius.circular(16),
         border: Border.all(color: Colors.purple.shade100),
       ),
       child: Row(
         children: [
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: Colors.purple.withValues(alpha: 0.1),
               shape: BoxShape.circle,
             ),
             child: const Icon(Icons.calendar_today_rounded, color: Colors.purple, size: 20),
           ),
           const SizedBox(width: 12),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 const Text(
                   'Daily Check-in', 
                   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)
                 ),
                 Text(
                   checkedIn 
                     ? 'You have ${profile.freeMessagesCount} free messages'
                     : 'Get 5 free messages now!',
                   style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                 ),
               ],
             ),
           ),
           ElevatedButton(
             onPressed: checkedIn ? null : () async {
               try {
                  final success = await ref.read(authRepositoryProvider).dailyCheckIn(profile.id);
                  if (success) {
                    // Invalidate provider to refresh data
                    ref.refresh(userProfileProvider); 
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🎉 +5 Free Messages claimed!')),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Already checked in today!')),
                      );
                    }
                  }
               } catch (e) {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Check-in failed: $e')),
                   );
                 }
               }
             },
             style: ElevatedButton.styleFrom(
               backgroundColor: checkedIn ? Colors.grey.shade300 : AppColors.primary,
               foregroundColor: checkedIn ? Colors.grey : Colors.white,
               elevation: 0,
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
             ),
             child: Text(checkedIn ? 'Done' : 'Claim'),
           ),
         ],
       ),
     );
  }

  bool _isCheckedInToday(DateTime? lastCheckIn) {
      if (lastCheckIn == null) return false;
      final now = DateTime.now().toUtc();
      final last = lastCheckIn.toUtc();
      return last.year == now.year && 
             last.month == now.month && 
             last.day == now.day;
  }
}
