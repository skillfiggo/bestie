import 'package:flutter/material.dart';
import 'package:bestie/core/widgets/cached_avatar.dart';
import 'package:bestie/core/widgets/online_status_indicator.dart';
import 'package:bestie/core/enums/online_status.dart';

/// Example usage of online status indicators
class OnlineStatusExample extends StatefulWidget {
  const OnlineStatusExample({super.key});

  @override
  State<OnlineStatusExample> createState() => _OnlineStatusExampleState();
}

class _OnlineStatusExampleState extends State<OnlineStatusExample> {
  OnlineStatus _demoStatus = OnlineStatus.online;
  
  void _cycleStatus() {
    setState(() {
      switch (_demoStatus) {
        case OnlineStatus.online:
          _demoStatus = OnlineStatus.away;
          break;
        case OnlineStatus.away:
          _demoStatus = OnlineStatus.offline;
          break;
        case OnlineStatus.offline:
          _demoStatus = OnlineStatus.online;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online Status Examples')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Indicators Only',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Column(
                  children: [
                    OnlineStatusIndicator(
                      status: OnlineStatus.online,
                      size: 16,
                    ),
                    const SizedBox(height: 8),
                    const Text('Online'),
                  ],
                ),
                const SizedBox(width: 32),
                Column(
                  children: [
                    OnlineStatusIndicator(
                      status: OnlineStatus.away,
                      size: 16,
                    ),
                    const SizedBox(height: 8),
                    const Text('Away'),
                  ],
                ),
                const SizedBox(width: 32),
                Column(
                  children: [
                    OnlineStatusIndicator(
                      status: OnlineStatus.offline,
                      size: 16,
                    ),
                    const SizedBox(height: 8),
                    const Text('Offline'),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            const Text(
              'Animated Transitions Demo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  OnlineStatusIndicator(
                    status: _demoStatus,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _demoStatus.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _cycleStatus,
                    icon: const Icon(Icons.sync),
                    label: const Text('Change Status'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Text(
              'With Last Seen Text',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StatusWithText(
              status: OnlineStatus.online,
              lastSeenText: getLastSeenText(
                isOnline: true,
                lastActiveAt: DateTime.now(),
              ),
            ),
            const SizedBox(height: 12),
            StatusWithText(
              status: OnlineStatus.away,
              lastSeenText: getLastSeenText(
                isOnline: false,
                lastActiveAt: DateTime.now().subtract(const Duration(minutes: 3)),
              ),
            ),
            const SizedBox(height: 12),
            StatusWithText(
              status: OnlineStatus.offline,
              lastSeenText: getLastSeenText(
                isOnline: false,
                lastActiveAt: DateTime.now().subtract(const Duration(hours: 2)),
              ),
            ),
            
            const SizedBox(height: 32),
            const Text(
              'Avatars with Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Column(
                  children: [
                    CachedAvatar(
                      imageUrl: '',
                      size: 60,
                      fallbackText: 'Online User',
                      onlineStatus: OnlineStatus.online,
                    ),
                    const SizedBox(height: 8),
                    const Text('Online'),
                  ],
                ),
                const SizedBox(width: 24),
                Column(
                  children: [
                    CachedAvatar(
                      imageUrl: '',
                      size: 60,
                      fallbackText: 'Away User',
                      onlineStatus: OnlineStatus.away,
                    ),
                    const SizedBox(height: 8),
                    const Text('Away'),
                  ],
                ),
                const SizedBox(width: 24),
                Column(
                  children: [
                    CachedAvatar(
                      imageUrl: '',
                      size: 60,
                      fallbackText: 'Offline User',
                      onlineStatus: OnlineStatus.offline,
                    ),
                    const SizedBox(height: 8),
                    const Text('Offline'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
