import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bestie/core/services/connectivity_service.dart';
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
import 'package:bestie/features/profile/data/providers/profile_stats_provider.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;

    if (profile != null) {
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
                    background: Column(
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
                                        ? CachedNetworkImageProvider(profile.coverPhotoUrl)
                                        : const CachedNetworkImageProvider(
                                            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
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
                                        ? CachedNetworkImageProvider(profile.avatarUrl)
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
                              // Verification Status Banner
                              if (profile.gender.toLowerCase() == 'female' && !profile.isVerified)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: profile.status == 'rejected' 
                                        ? AppColors.error.withValues(alpha: 0.1) 
                                        : AppColors.info.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: profile.status == 'rejected' 
                                          ? AppColors.error.withValues(alpha: 0.3) 
                                          : AppColors.info.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        profile.status == 'rejected' ? Icons.error_outline : Icons.info_outline,
                                        color: profile.status == 'rejected' ? AppColors.error : AppColors.info,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          profile.status == 'rejected'
                                              ? 'Your verification was rejected. Please upload a clear photo of yourself.'
                                              : 'Your verification is currently being reviewed by our team.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: profile.status == 'rejected' ? AppColors.error : AppColors.info,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (profile.status == 'rejected')
                                        TextButton(
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
                                          child: const Text(
                                            'Fix Now',
                                            style: TextStyle(
                                              color: AppColors.error,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
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
                                        if (profile.isVerified) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.verified, color: Colors.blue, size: 20),
                                        ],
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
                            // Location Row (only show if location is set)
                            if (profile.locationName.isNotEmpty) ...[
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text(
                                    profile.locationName,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                              // Stats Row — single RPC replaces 4 separate DB calls
                              Builder(builder: (context) {
                                final statsAsync = ref.watch(userProfileStatsProvider(profile.id));
                                final stats = statsAsync.valueOrNull ?? UserProfileStats.zero;
                                return Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersFollowingScreen(userId: profile.id, initialTabIndex: 0))),
                                      child: _buildStat(statsAsync.isLoading ? '...' : '${stats.followerCount}', 'Followers'),
                                    ),
                                    const SizedBox(width: 24),
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersFollowingScreen(userId: profile.id, initialTabIndex: 1))),
                                      child: _buildStat(statsAsync.isLoading ? '...' : '${stats.followingCount}', 'Following'),
                                    ),
                                    const SizedBox(width: 24),
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersFollowingScreen(userId: profile.id, initialTabIndex: 2))),
                                      child: _buildStat(statsAsync.isLoading ? '...' : '${stats.friendsCount}', 'Friends'),
                                    ),
                                    const SizedBox(width: 24),
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FollowersFollowingScreen(userId: profile.id, initialTabIndex: 3))),
                                      child: _buildStat(statsAsync.isLoading ? '...' : '${stats.bestiesCount}', 'Bestie'),
                                    ),
                                  ],
                                );
                              }),
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
            body: TabBarView(
              children: [
                _buildAboutTab(profile),
                _buildMomentsTab(ref, profile.id),
                _buildGalleryTab(profile),
              ],
            ),
          ),
        ),
      );
    }

    return profileAsync.when(
      data: (profileData) {
        return const Scaffold(
          body: Center(child: Text('Profile not found')),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) {
        final errorMsg = ConnectivityService.getNetworkErrorMessage(error);
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'My Profile',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    errorMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(userProfileProvider);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGalleryTab(ProfileModel profile) {
    if (profile.galleryUrls.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No gallery images yet',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: profile.galleryUrls.length,
      itemBuilder: (context, index) {
        final url = profile.galleryUrls[index];
        return GestureDetector(
          onTap: () => _showFullScreenImage(context, url),
          child: Hero(
            tag: url,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.error_outline, color: Colors.grey),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Hero(
                tag: imageUrl,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
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

  Widget _buildAboutTab(ProfileModel? profile) {
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
                    ref.invalidate(userProfileProvider); 
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
