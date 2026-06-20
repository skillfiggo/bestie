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
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';


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
    _loadCachedData();
    _initLocation();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_nearby_profiles');
      if (cachedStr != null) {
        if (mounted) {
          setState(() {
            final List<dynamic> list = json.decode(cachedStr);
            _nearbyProfiles = list.map((item) => ProfileModel.fromMap(Map<String, dynamic>.from(item))).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading cached nearby profiles: $e');
    }
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

      // Use AndroidSettings with useMSLAltitude: false to prevent geolocator
      // from starting NmeaClient, which crashes the JVM on some Android devices
      // due to a null string being passed to JNI's NewStringUTF (geolocator bug).
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          useMSLAltitude: false, // ← disables NmeaClient, preventing the crash
        ),
      );
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
        final genderLower = userProfile.gender.toLowerCase().trim();
        if (genderLower == 'male') {
          targetGender = 'female';
        } else if (genderLower == 'female') {
          targetGender = 'male';
        }
      }
      debugPrint('NearbyView query - user: ${userProfile?.name}, gender: ${userProfile?.gender}, targetGender: $targetGender');

      final profiles = await _repository.getNearbyProfiles(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        targetGender: targetGender,
        radiusKm: 50, // Default 50km radius
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('cached_nearby_profiles', json.encode(profiles.map((p) => p.toMap()).toList()));
      } catch (cacheErr) {
        debugPrint('Failed to save nearby profiles to cache: $cacheErr');
      }

      if (mounted) {
        setState(() {
          _nearbyProfiles = profiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch nearby users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_nearbyProfiles.isEmpty) {
            _error = 'Failed to fetch nearby users: $e';
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
    // Reload nearby if gender changes
    ref.listen<AsyncValue<ProfileModel?>>(userProfileProvider, (previous, next) {
      final prevGender = previous?.valueOrNull?.gender;
      final nextGender = next.valueOrNull?.gender;
      if (nextGender != null && prevGender != nextGender && !_isLoading) {
        _fetchNearbyUsers();
      }
    });
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icons/no-user-nearby.png',
                width: 240,
                height: 240,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'No Besties Nearby Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We couldn\'t find any users matching your preferences in your immediate area right now.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (_currentPosition != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Location: ${_currentPosition!.latitude.toStringAsFixed(2)}, ${_currentPosition!.longitude.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _fetchNearbyUsers,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  'Search Again',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNearbyUsers,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.58,
        ),
        itemCount: _nearbyProfiles.length,
        itemBuilder: (context, index) {
          final profile = _nearbyProfiles[index];
          
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
