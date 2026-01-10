import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:bestie/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/calling/presentation/screens/call_screen.dart';
import 'package:bestie/features/social/data/providers/follow_providers.dart';
import 'package:bestie/features/moment/presentation/widgets/moment_card.dart';
import 'package:bestie/features/moment/data/providers/moment_providers.dart';
import 'package:bestie/features/profile/data/providers/profile_visit_providers.dart';
import 'package:bestie/features/admin/data/repositories/admin_repository.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';

import 'package:bestie/features/admin/presentation/widgets/report_dialog.dart';
import 'package:bestie/features/admin/data/repositories/reports_repository.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logVisit();
    });
  }

  Future<void> _logVisit() async {
    final currentUser = ref.read(authRepositoryProvider).getCurrentUser();
    if (currentUser != null) {
      ref.read(profileVisitRepositoryProvider).logVisit(
            visitorId: currentUser.id,
            visitedId: widget.userId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileByIdProvider(widget.userId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 520, // Increased height
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  profileAsync.when(
                    data: (profile) {
                      if (profile == null) return const SizedBox.shrink();
                      return PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                        onSelected: (value) async {
                          if (value == 'report') {
                            showReportDialog(
                              context,
                              reportedUserId: profile.id,
                              reportedUserName: profile.name,
                              reportType: 'user',
                            );
                          } else if (value == 'block') {
                            try {
                              await ref.read(reportsRepositoryProvider).blockUser(profile.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Blocked ${profile.name}')),
                                );
                                Navigator.pop(context); // Exit profile after blocking
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error blocking user: $e')),
                                );
                              }
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Report User'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'block',
                            child: Row(
                              children: [
                                Icon(Icons.block, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Block User'),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                  ),
                ],
                title: Text(
                  innerBoxIsScrolled ? 'Profile' : '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: profileAsync.when(
                    data: (profile) {
                      if (profile == null) {
                        return const Center(
                          child: Text(
                            'Profile not found',
                            style: TextStyle(color: Colors.black),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          // Cover Photo & Avatar Stack
                          SizedBox(
                            height: 210,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Cover Photo with Gradient Overlay
                                Container(
                                  height: 180, // Taller cover
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: profile.coverPhotoUrl.isNotEmpty
                                          ? NetworkImage(profile.coverPhotoUrl)
                                          : const NetworkImage(
                                              'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
                                            ),
                                      fit: BoxFit.cover,
                                    ),
                                    color: Colors.grey.shade300,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.3),
                                          Colors.transparent,
                                          Colors.transparent,
                                          Colors.white.withValues(alpha: 0.8),
                                        ],
                                      ),
                                    ),
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
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 55, // Slightly larger
                                      backgroundImage: profile.avatarUrl.isNotEmpty
                                          ? NetworkImage(profile.avatarUrl)
                                          : null,
                                      child: profile.avatarUrl.isEmpty
                                          ? Text(
                                              profile.name.isNotEmpty ? profile.name[0] : '?',
                                              style: const TextStyle(fontSize: 34),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                if (profile.isOnline && profile.showOnlineStatus)
                                  Positioned(
                                    bottom: 8,
                                    left: 100,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
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
                                            child: Text(
                                              '${profile.name}, ${profile.age}',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (profile.isVerified) ...[
                                            const SizedBox(width: 6),
                                            const Icon(Icons.verified, color: Colors.blue, size: 20),
                                          ],
                                        ],
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
                                const SizedBox(height: 16),
                              ],
                                // Stats Row with better spacing
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final followerCountAsync = ref.watch(followerCountProvider(widget.userId));
                                          return followerCountAsync.when(
                                            data: (count) => _buildStat(count.toString(), 'Followers'),
                                            loading: () => _buildStat('...', 'Followers'),
                                            error: (error, stackTrace) => _buildStat('0', 'Followers'),
                                          );
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final followingCountAsync = ref.watch(followingCountProvider(widget.userId));
                                          return followingCountAsync.when(
                                            data: (count) => _buildStat(count.toString(), 'Following'),
                                            loading: () => _buildStat('...', 'Following'),
                                            error: (error, stackTrace) => _buildStat('0', 'Following'),
                                          );
                                        },
                                      ),
                                    ),
                                    _buildStat('0', 'Friends'),
                                    const SizedBox(width: 40),
                                    _buildStat('0', 'Bestie'),
                                    const Spacer(),
                                  ],
                                ),
                                const SizedBox(height: 12), // Matching spacer in screenshot
                                // Follow/Unfollow and Bestie Buttons Row
                                if (profile.role != 'system') ...[
                                  Row(
                                    children: [
                                      // Follow/Unfollow Button
                                      Expanded(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final isFollowingAsync = ref.watch(isFollowingProvider(widget.userId));
                                            
                                            return isFollowingAsync.when(
                                              data: (isFollowing) {
                                                return GestureDetector(
                                                  onTap: () async {
                                                    try {
                                                      final repository = ref.read(followRepositoryProvider);
                                                      if (isFollowing) {
                                                        await repository.unfollowUser(widget.userId);
                                                      } else {
                                                        await repository.followUser(widget.userId);
                                                      }
                                                      ref.invalidate(isFollowingProvider(widget.userId));
                                                      ref.invalidate(followerCountProvider(widget.userId));
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Error: $e')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    decoration: BoxDecoration(
                                                      color: isFollowing ? Colors.grey.shade100 : AppColors.primary,
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: isFollowing ? Border.all(color: Colors.grey.shade300) : null,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          isFollowing ? Icons.person_remove_rounded : Icons.person_add_rounded,
                                                          color: isFollowing ? AppColors.textPrimary : Colors.white,
                                                          size: 20,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          isFollowing ? 'Unfollow' : 'Follow',
                                                          style: TextStyle(
                                                            color: isFollowing ? AppColors.textPrimary : Colors.white,
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                              loading: () => Container(
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                                child: const Center(
                                                  child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                                ),
                                              ),
                                              error: (error, stackTrace) => const SizedBox.shrink(),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Bestie Button
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.favorite_rounded, color: Colors.grey.shade400, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Bestie',
                                                style: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                // Action Buttons Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.chat_bubble_rounded,
                                        label: 'Chat',
                                        color: AppColors.primary,
                                        onPressed: () async {
                                          try {
                                            final chat = await ref
                                                .read(chatRepositoryProvider)
                                                .createOrGetChat(widget.userId);

                                            if (context.mounted) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => ChatDetailScreen(chat: chat),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error: $e')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    if (profile.role != 'system') ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _ActionButton(
                                          icon: Icons.videocam_rounded,
                                          label: 'Video',
                                          color: const Color(0xFF00c853),
                                          onPressed: () {
                                            final currentGender = ref.read(userProfileProvider).value?.gender ?? 'male';
                                            if (currentGender == 'female') {
                                              _startCall(isVideo: true);
                                            } else {
                                              _showCallCostDialog(context, isVideo: true);
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _ActionButton(
                                          icon: Icons.phone_rounded,
                                          label: 'Call',
                                          color: const Color(0xFF00c853),
                                          onPressed: () {
                                            final currentGender = ref.read(userProfileProvider).value?.gender ?? 'male';
                                            if (currentGender == 'female') {
                                              _startCall(isVideo: false);
                                            } else {
                                              _showCallCostDialog(context, isVideo: false);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
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
              if (profile == null) return const Center(child: Text('Profile not found'));
              return TabBarView(
                children: [
                  _buildAboutTab(profile),
                  _buildMomentsTab(ref, widget.userId),
                  _buildGalleryTab(profile),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => const Center(child: Text('Error loading profile content')),
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

  Widget _buildAboutTab(ProfileModel? profile) {
    if (profile == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.bio.isNotEmpty) ...[
            const Text(
              'About',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              profile.bio,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
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
          
          // Admin Controls
          Consumer(
            builder: (context, ref, _) {
              final currentUserAsync = ref.watch(userProfileProvider);
              return currentUserAsync.when(
                data: (currentUser) {
                  if (currentUser?.role != 'admin') return const SizedBox.shrink();
                  
                  return Container(
                    margin: const EdgeInsets.only(top: 32),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.admin_panel_settings, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Admin Controls',
                              style: TextStyle(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                             Expanded(
                              child: Text(
                                'Status: ${profile.status.toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                             ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final adminRepo = ref.read(adminRepositoryProvider);
                                if (profile.status == 'banned') {
                                  await adminRepo.unbanUser(profile.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('User unbanned')),
                                    );
                                  }
                                } else {
                                  await adminRepo.banUser(profile.id);
                                   if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('User banned')),
                                    );
                                  }
                                }
                                // Refresh the profile being viewed
                                ref.invalidate(userProfileByIdProvider(profile.id));
                              } catch(e) {
                                 if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                              }
                            },
                            icon: Icon(
                              profile.status == 'banned' ? Icons.restore : Icons.block,
                            ),
                            label: Text(
                              profile.status == 'banned' ? 'Unban User' : 'Ban User',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: profile.status == 'banned' ? Colors.green : Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
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
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
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

  void _showCallCostDialog(BuildContext context, {required bool isVideo}) {
    final int cost = isVideo ? 200 : 100;
    final String type = isVideo ? 'Video Call' : 'Voice Call';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: isVideo ? Colors.green.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Icon(
                                    isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                                    color: isVideo ? Colors.green : Colors.blue,
                                    size: 48,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Ready for a $type?',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.orange.shade100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.monetization_on_rounded, color: Colors.orange, size: 20),
                                      const SizedBox(width: 8),
                                      RichText(
                                        text: TextSpan(
                                          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                                          children: [
                                            TextSpan(
                                              text: '$cost Coins',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                            ),
                                            const TextSpan(text: ' / minute'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                          _startCall(isVideo: isVideo);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isVideo 
                                                ? [const Color(0xFF00c853), const Color(0xFF6CC449)]
                                                : [const Color(0xFF01579b), const Color(0xFF0277bd)],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (isVideo ? const Color(0xFF00c853) : const Color(0xFF01579b)).withValues(alpha: 0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'Call Now',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCall({required bool isVideo}) async {
    try {
      final chat = await ref.read(chatRepositoryProvider).createOrGetChat(widget.userId);
      final currentUser = ref.read(authRepositoryProvider).getCurrentUser();
      
      if (currentUser == null) return;

      // 1. Create call session via CallRepository
      // This handles creating call_history record AND sending a free invitation message
      debugPrint('📞 Creating call session from profile...');
      final callHistoryId = await ref.read(callRepositoryProvider).startCall(
        channelId: chat.id,
        callerId: currentUser.id,
        receiverId: widget.userId,
        mediaType: isVideo ? 'video' : 'voice',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              channelId: chat.id,
              otherUserId: widget.userId,
              isVideo: isVideo,
              isInitiator: true,
              callHistoryId: callHistoryId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
