import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/home/presentation/widgets/profile_card.dart';
import 'package:bestie/features/home/presentation/widgets/ad_banner.dart';
import 'package:bestie/features/visitor/presentation/visitor_view.dart';
import 'package:bestie/features/home/presentation/widgets/nearby_view.dart';
import 'package:bestie/features/profile/data/repositories/profile_repository.dart';
import 'package:bestie/features/chat/data/repositories/chat_repository.dart';
import 'package:bestie/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';
import 'package:bestie/features/calling/presentation/screens/call_screen.dart';
import 'package:bestie/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  // Filter State
  RangeValues _ageRange = const RangeValues(18, 80);
  List<ProfileModel> _profiles = [];
  bool _isLoading = true;
  String? _error;
  bool _isStartingCall = false; // Prevent duplicate call requests

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // In a real app, you might want to switch gender filter based on user preference
      // For now, let's fetch all (repository handles exclusion of self)
      final profiles = await ref.read(profileRepositoryProvider).getDiscoveryProfiles(
        minAge: _ageRange.start.round(),
        maxAge: _ageRange.end.round(),
      );

      if (mounted) {
        setState(() {
          _profiles = profiles;
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
        // Use StatefulBuilder to update the bottom sheet state independently
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
                  
                  // Age Range Label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Age Range',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
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
                  
                  // Slider
                  RangeSlider(
                    values: _ageRange,
                    min: 18,
                    max: 80,
                    divisions: 62, // One division per year
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.primary.withOpacity(0.2),
                    labels: RangeLabels(
                      _ageRange.start.round().toString(),
                      _ageRange.end.round().toString(),
                    ),
                    onChanged: (RangeValues values) {
                      setModalState(() {
                        _ageRange = values;
                      });
                      // Update parent state as well? No, wait for Apply.
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Update parent state and reload
                        setState(() {
                          // _ageRange is already updated in modal? No, local var in modal. 
                          // Wait, I used _ageRange which is parent's var. 
                          // Logic above: setModalState updates UI, but does it update parent var? 
                          // It updates _ageRange because it's captured in closure? 
                          // Yes, but setState in parent is needed to trigger rebuild of parent? 
                          // Or we just call _loadProfiles() which calls setState.
                        });
                        _loadProfiles();
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
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
  }) async {    // Prevent duplicate calls
    if (_isStartingCall) {
      print('⚠️ Already starting a call, ignoring duplicate request');
      return;
    }

    setState(() {
      _isStartingCall = true;
    });

    try {
      // Request permissions first
      final micPermission = await Permission.microphone.request();
      PermissionStatus? cameraPermission;
      
      if (isVideo) {
        cameraPermission = await Permission.camera.request();
      }

      // Check if permissions granted
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

      // Permissions granted, create chat and start call
      // Permissions granted, create chat and start call
      final chat = await ref.read(chatRepositoryProvider).createOrGetChat(profileId);
      
      // Get current user ID
      final currentUserId = ref.read(authRepositoryProvider).getCurrentUser()?.id;
      if (currentUserId == null) throw Exception('User not logged in');
      
      // Create call session
      print('📞 Creating call session...');
      final callHistoryId = await ref.read(callRepositoryProvider).startCall(
        channelId: chat.id,
        callerId: currentUserId,
        receiverId: profileId,
        mediaType: isVideo ? 'video' : 'voice',
      );
      print('✅ Call session created: $callHistoryId');

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
      print('❌ Error starting call: $e');
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
          title: const Text(
            'Discover',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
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
            preferredSize: const Size.fromHeight(130), // Banner (60+16) + TabBar (50) + spacing
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
                    Tab(
                      text: 'Recommend',
                    ),
                    Tab(
                      text: 'Newcomer',
                    ),
                    Tab(
                      text: 'Nearby',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Recommended Tab
            _buildProfileList(),
            // Newcomer Tab (Could be different query/sort in future)
            _buildProfileList(),
            // Nearby Tab
            const NearbyView(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }

    return _profiles.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No profiles found',
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
                  onPressed: _loadProfiles, 
                  child: const Text('Retry')
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadProfiles,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _profiles.length,
              itemBuilder: (context, index) {
                final profile = _profiles[index];
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
                        // Optimistic navigation or show loading?
                        // Let's show loading dialog or just wait.
                        // Ideally better to have a loading state on the button itself but ProfileCard is simple.
                        
                        // Fetch/Create chat
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
