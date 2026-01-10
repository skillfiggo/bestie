import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/core/services/supabase_service.dart';
import 'package:bestie/features/home/data/repositories/nearby_repository.dart';
import 'package:bestie/features/home/domain/models/profile_model.dart';
import 'package:bestie/features/home/presentation/widgets/profile_card.dart';
import 'package:bestie/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:bestie/features/chat/data/repositories/chat_repository.dart';
import 'package:bestie/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:bestie/features/calling/presentation/screens/call_screen.dart';
import 'package:bestie/features/chat/data/repositories/call_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/auth/data/providers/auth_providers.dart';

class NearbyView extends ConsumerStatefulWidget {
  const NearbyView({super.key});

  @override
  ConsumerState<NearbyView> createState() => _NearbyViewState();
}

class _NearbyViewState extends ConsumerState<NearbyView> {
  final _repository = NearbyRepository(SupabaseService.client);
  List<ProfileModel> _nearbyProfiles = [];
  bool _isLoading = true;
  String? _error;
  Position? _currentPosition;
  bool _isStartingCall = false; // Prevent duplicate call requests

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          await _showLocationServiceDialog();
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            await _showPermissionDeniedDialog();
          }
           return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
            await _showPermissionDeniedForeverDialog();
        }
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      // Update location in DB
      await _repository.updateLocation(position.latitude, position.longitude);

      // Fetch nearby users
      await _fetchNearbyUsers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showLocationServiceDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Please enable location services to see users nearby.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = false;
                  _error = 'Location services are disabled.';
                });
              },
            ),
            TextButton(
              child: const Text('Settings'),
              onPressed: () {
                Geolocator.openLocationSettings();
                Navigator.of(context).pop();
                // Optionally retry after returning?
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionDeniedDialog() async {
    return showDialog(
      context: context,
       barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Denied'),
          content: const Text(
            'This feature requires location permission to find users near you.',
          ),
          actions: <Widget>[
             TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                 setState(() {
                  _isLoading = false;
                  _error = 'Location permission denied.';
                });
              },
            ),
            TextButton(
              child: const Text('Grant'),
              onPressed: () {
                Navigator.of(context).pop();
                _initLocation(); // Retry
              },
            ),
          ],
        );
      },
    );
  }

    Future<void> _showPermissionDeniedForeverDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Permanently Denied'),
          content: const Text(
            'Please enable location permissions in app settings to use this feature.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                 setState(() {
                  _isLoading = false;
                  _error = 'Location permission permanently denied.';
                });
              },
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Geolocator.openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchNearbyUsers() async {
    if (_currentPosition == null) return;

    try {
      // Get current user gender to filter by opposite
      final userProfile = await ref.read(userProfileProvider.future);
      String? targetGender;
      
      if (userProfile != null) {
        if (userProfile.gender == 'male') {
          targetGender = 'female';
        } else if (userProfile.gender == 'female') {
          targetGender = 'male';
        }
      }

      final profiles = await _repository.getNearbyProfiles(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        targetGender: targetGender,
        radiusKm: 50, // Default 50km radius
      );
      if (mounted) {
        setState(() {
          _nearbyProfiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to fetch nearby users: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStartCall({
    required String profileId,
    required bool isVideo,
  }) async {
    // Prevent duplicate calls
    if (_isStartingCall) {
      debugPrint('⚠️ Already starting a call, ignoring duplicate request');
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
      final chatRepo = ChatRepository();
      final chat = await chatRepo.createOrGetChat(profileId);
      
      // Get current user ID
      final currentUserId = SupabaseService.client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not logged in');

      // Create call session
      debugPrint('📞 Creating call session...');
      // We need to access CallRepository. Since we are not in a Riverpod consumer widget here (it's StatefulWidget),
      // we can instantiate CallRepository directly or pass ref if we convert to ConsumerStatefulWidget.
      // But NearbyView IS NOT a ConsumerWidget currently.
      // However, CallRepository takes a SupabaseClient internally.
      final callRepo = CallRepository();
      final callHistoryId = await callRepo.startCall(
        channelId: chat.id,
        callerId: currentUserId,
        receiverId: profileId,
        mediaType: isVideo ? 'video' : 'voice',
      );
      debugPrint('✅ Call session created: $callHistoryId');

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
      debugPrint('❌ Error starting call: $e');
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _initLocation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_nearbyProfiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No users found nearby.',
              style: TextStyle(color: Colors.grey),
            ),
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              Text(
                'Location: ${_currentPosition!.latitude.toStringAsFixed(2)}, ${_currentPosition!.longitude.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchNearbyUsers,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNearbyUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _nearbyProfiles.length,
        itemBuilder: (context, index) {
          final profile = _nearbyProfiles[index];
          
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
                final chatRepo = ChatRepository();
                final chat = await chatRepo.createOrGetChat(profile.id);

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
