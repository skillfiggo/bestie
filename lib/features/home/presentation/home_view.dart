import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/home/presentation/widgets/profile_card.dart';
import 'package:bestie/features/home/presentation/widgets/ad_banner.dart';
import 'package:bestie/features/visitor/presentation/visitor_view.dart';
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
import 'package:bestie/features/home/presentation/widgets/search_user_delegate.dart';

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
    _loadAllData();
    _checkBroadcast();
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
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch both Recommended and Newcomers in parallel
      final results = await Future.wait([
        ref.read(profileRepositoryProvider).getDiscoveryProfiles(
          minAge: _ageRange.start.round(),
          maxAge: _ageRange.end.round(),
        ),
        ref.read(profileRepositoryProvider).getNewcomerProfiles(limit: 50),
      ]);
      
      if (mounted) {
        setState(() {
          _recommendProfiles = results[0];
          _newcomerProfiles = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.textPrimary),
              tooltip: 'Search User',
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: SearchUserDelegate(ref),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.favorite_rounded, color: AppColors.primary),
              tooltip: 'Visitors',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VisitorView()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
              onPressed: _showFilterModal,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(130),
            child: Column(
              children: [
                const AdBanner(),
                const TabBar(
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                return ProfileCard(
                  profile: profile,
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
