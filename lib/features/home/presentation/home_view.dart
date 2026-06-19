import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/home/presentation/widgets/profile_card.dart';
import 'package:bestie/features/home/presentation/widgets/nearby_view.dart';
import 'package:bestie/features/profile/data/repositories/profile_repository.dart';
import 'package:bestie/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:bestie/features/calling/presentation/screens/call_screen.dart';
import 'package:bestie/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bestie/features/admin/data/repositories/admin_repository.dart';
import 'package:bestie/core/services/connectivity_service.dart';
import 'package:bestie/features/after_dark/presentation/screens/after_dark_hub_screen.dart';
import 'package:bestie/features/ai_chat/presentation/hot_talk_view.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';



class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  // Filter State
  RangeValues _ageRange = const RangeValues(18, 80);
  
  // Data State
  List<ProfileModel> _recommendProfiles = [];
  List<ProfileModel> _newcomerProfiles = [];
  bool _isLoading = true;
  String? _error;
  bool _isStartingCall = false;
  
  static final Set<String> _seenBroadcasts = {};

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadAllData();
    _checkBroadcast();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recommendStr = prefs.getString('cached_recommend_profiles');
      final newcomerStr = prefs.getString('cached_newcomer_profiles');
      
      if (recommendStr != null || newcomerStr != null) {
        if (mounted) {
          setState(() {
            if (recommendStr != null) {
              final List<dynamic> list = json.decode(recommendStr);
              _recommendProfiles = list.map((item) => ProfileModel.fromMap(Map<String, dynamic>.from(item))).toList();
            }
            if (newcomerStr != null) {
              final List<dynamic> list = json.decode(newcomerStr);
              _newcomerProfiles = list.map((item) => ProfileModel.fromMap(Map<String, dynamic>.from(item))).toList();
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading cached discovery profiles: $e');
    }
  }
  
  Future<void> _checkBroadcast() async {
    // Small delay to let UI build first
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    try {
      final broadcast = await ref.read(adminRepositoryProvider).getLatestActiveBroadcast();
      if (broadcast != null && !_seenBroadcasts.contains(broadcast.id)) {
        if (mounted) {
          _seenBroadcasts.add(broadcast.id);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                   const Icon(Icons.campaign, color: AppColors.primary),
                   const SizedBox(width: 8),
                   Expanded(child: Text(broadcast.title)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (broadcast.imageUrl != null && broadcast.imageUrl!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          broadcast.imageUrl!, 
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(broadcast.message),
                    if (broadcast.linkUrl != null && broadcast.linkUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                             onPressed: () { 
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Link tapped: ${broadcast.linkUrl}')),
                                );
                             },
                             icon: const Icon(Icons.open_in_new, size: 16),
                             label: Text(broadcast.linkText?.isNotEmpty == true ? broadcast.linkText! : 'Learn More'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: AppColors.primary,
                               foregroundColor: Colors.white,
                             ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch broadcast: $e');
    }
  }

  Future<void> _loadAllData() async {
    setState(() {
      if (_recommendProfiles.isEmpty && _newcomerProfiles.isEmpty) {
        _isLoading = true;
      }
      _error = null;
    });

    try {
      // 1. Get current user's gender to filter by opposite
      ProfileModel? userProfile = ref.read(userProfileProvider).valueOrNull;
      if (userProfile == null) {
        try {
          userProfile = await ref.read(userProfileProvider.future).timeout(const Duration(seconds: 3));
        } catch (e) {
          debugPrint('Error/timeout fetching user profile: $e');
        }
      }

      String? targetGender;
      if (userProfile != null) {
        final genderLower = userProfile.gender.toLowerCase().trim();
        if (genderLower == 'male') {
          targetGender = 'female';
        } else if (genderLower == 'female') {
          targetGender = 'male';
        }
      }
      debugPrint('HomeView discovery: userProfile = ${userProfile?.name}, gender = ${userProfile?.gender}, targetGender = $targetGender');

      // Fetch both Recommended and Newcomers in parallel
      final results = await Future.wait([
        ref.read(profileRepositoryProvider).getDiscoveryProfiles(
          gender: targetGender,
          minAge: _ageRange.start.round(),
          maxAge: _ageRange.end.round(),
        ),
        ref.read(profileRepositoryProvider).getNewcomerProfiles(
          gender: targetGender,
          limit: 50,
        ),
      ]);
      
      // Compute distance client-side using Haversine formula
      double? _haversineKm(double? lat1, double? lon1, double? lat2, double? lon2) {
        if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
        const r = 6371.0; // Earth radius in km
        final dLat = (lat2 - lat1) * math.pi / 180;
        final dLon = (lon2 - lon1) * math.pi / 180;
        final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(lat1 * math.pi / 180) *
                math.cos(lat2 * math.pi / 180) *
                math.sin(dLon / 2) *
                math.sin(dLon / 2);
        return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      }

      List<ProfileModel> _withDistance(List<ProfileModel> profiles) {
        if (userProfile?.latitude == null || userProfile?.longitude == null) return profiles;
        return profiles.map((p) {
          final km = _haversineKm(
            userProfile!.latitude, userProfile.longitude,
            p.latitude, p.longitude,
          );
          return km != null ? p.copyWith(distanceKm: km) : p;
        }).toList();
      }

      // Sort: online first → recently active (away) → offline
      int _onlineRank(ProfileModel p) {
        if (p.isOnline) return 0;
        if (p.lastActiveAt != null &&
            DateTime.now().difference(p.lastActiveAt!).inMinutes < 5) return 1;
        return 2;
      }

      final recProfiles = _withDistance(results[0])..sort((a, b) => _onlineRank(a).compareTo(_onlineRank(b)));
      final newProfiles = _withDistance(results[1])..sort((a, b) => _onlineRank(a).compareTo(_onlineRank(b)));


      try {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('cached_recommend_profiles', json.encode(recProfiles.map((p) => p.toMap()).toList()));
        prefs.setString('cached_newcomer_profiles', json.encode(newProfiles.map((p) => p.toMap()).toList()));
      } catch (cacheErr) {
        debugPrint('Failed to save discovery profiles to cache: $cacheErr');
      }

      if (mounted) {
        setState(() {
          _recommendProfiles = recProfiles;
          _newcomerProfiles = newProfiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch discovery data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_recommendProfiles.isEmpty && _newcomerProfiles.isEmpty) {
            _error = ConnectivityService.getNetworkErrorMessage(e);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🌐 No internet connection. Showing cached profiles.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
      }
    }
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Profiles',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Age Range',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${_ageRange.start.round()} - ${_ageRange.end.round()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  RangeSlider(
                    values: _ageRange,
                    min: 18,
                    max: 80,
                    divisions: 62,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                    labels: RangeLabels(
                      _ageRange.start.round().toString(),
                      _ageRange.end.round().toString(),
                    ),
                    onChanged: (RangeValues values) {
                      setModalState(() {
                        _ageRange = values;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Update filters in parent
                        _loadAllData();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleStartCall({
    required String profileId,
    required bool isVideo,
  }) async {
    if (_isStartingCall) return;

    setState(() {
      _isStartingCall = true;
    });

    try {
      final micPermission = await Permission.microphone.request();
      PermissionStatus? cameraPermission;
      
      if (isVideo) {
        cameraPermission = await Permission.camera.request();
      }

      final micGranted = micPermission.isGranted;
      final cameraGranted = isVideo ? (cameraPermission?.isGranted ?? false) : true;

      if (!micGranted || !cameraGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                !micGranted
                    ? 'Microphone permission is required for calls'
                    : 'Camera permission is required for video calls',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      final chat = await ref.read(chatRepositoryProvider).createOrGetChat(profileId);
      final currentUserId = ref.read(authRepositoryProvider).getCurrentUser()?.id;
      if (currentUserId == null) throw Exception('User not logged in');
      
      final callHistoryId = await ref.read(callRepositoryProvider).startCall(
        channelId: chat.id,
        callerId: currentUserId,
        receiverId: profileId,
        mediaType: isVideo ? 'video' : 'voice',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              channelId: chat.id,
              otherUserId: profileId,
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
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingCall = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reload discovery if gender changes
    ref.listen<AsyncValue<ProfileModel?>>(userProfileProvider, (previous, next) {
      final prevGender = previous?.valueOrNull?.gender;
      final nextGender = next.valueOrNull?.gender;
      if (nextGender != null && prevGender != nextGender && !_isLoading) {
        _loadAllData();
      }
    });

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(153),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _FeatureCard(
                          label: 'Hot Talk',
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF9A56), Color(0xFFFF6B6B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          icon: Icons.local_fire_department_rounded,
                          badgeIcon: Icons.mic_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const HotTalkView()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FeatureCard(
                          label: 'After Dark',
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB8F000), Color(0xFF7EC800)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          icon: Icons.nights_stay_rounded,
                          badgeIcon: Icons.auto_awesome_rounded,
                          badgeColor: const Color(0xFFFFE066),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AfterDarkHubScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FeatureCard(
                          label: 'Voice Chats',
                          gradient: const LinearGradient(
                            colors: [Color(0xFFAB47BC), Color(0xFF7E57C2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          icon: Icons.graphic_eq,
                          badgeIcon: Icons.graphic_eq,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Voice Chats feature coming soon!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        tabs: [
                          Tab(text: 'Recommend'),
                          Tab(text: 'Newcomer'),
                          Tab(text: 'Nearby'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: SvgPicture.asset(
                        'assets/images/icons/Maggi.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn),
                      ),
                      onPressed: _showFilterModal,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Recommended Tab
            _buildProfileList(_recommendProfiles, emptyMessage: 'No recommendations found'),
            // Newcomer Tab
            _buildProfileList(_newcomerProfiles, emptyMessage: 'No newcomers yet'),
            // Nearby Tab
            const NearbyView(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList(List<ProfileModel> profiles, {String emptyMessage = 'No profiles found'}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return profiles.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                  ),
                ),
                TextButton(
                  onPressed: _showFilterModal, 
                  child: const Text('Adjust Filters')
                ),
                TextButton(
                  onPressed: _loadAllData, 
                  child: const Text('Retry')
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadAllData,
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.58,
              ),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return ProfileCard(
                  profile: profile,
                  isCompact: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: profile.id),
                      ),
                    );
                  },
                  onChatTap: () async {
                     try {
                        final chat = await ref.read(chatRepositoryProvider).createOrGetChat(profile.id);
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
                           SnackBar(content: Text('Error starting chat: $e')),
                         );
                       }
                     }
                  },
                   onVideoCallTap: () => _handleStartCall(
                     profileId: profile.id,
                     isVideo: true,
                   ),
                );
              },
            ),
          );
  }
}

/// Colorful feature card used in the top banner row (Hot Talk, After Dark, Voice Chats).
class _FeatureCard extends StatelessWidget {
  final String label;
  final LinearGradient gradient;
  final IconData icon;
  final IconData? badgeIcon;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.label,
    required this.gradient,
    required this.icon,
    this.badgeIcon,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Large faded background icon — bottom-right
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(
                icon,
                size: 70,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            // Badge icon — top-right circle
            if (badgeIcon != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    badgeIcon,
                    size: 13,
                    color: badgeColor ?? Colors.white,
                  ),
                ),
              ),
            // Content: title top-left, play button bottom-left
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title — top-left, bold, can wrap to 2 lines
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      height: 1.2,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Play circle — bottom-left
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


