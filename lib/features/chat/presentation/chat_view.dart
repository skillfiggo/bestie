import 'package:flutter/material.dart';
import 'package:bestie/core/constants/app_colors.dart';
import 'package:bestie/features/home/presentation/widgets/ad_banner.dart';
import 'package:bestie/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:bestie/features/chat/domain/models/call_history_model.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestie/features/chat/data/providers/chat_providers.dart';

class ChatView extends ConsumerWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Chats',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.primary),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.cleaning_services_rounded, color: AppColors.primary),
              onPressed: () {},
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
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  tabs: [
                    Tab(text: 'Chat'),
                    Tab(text: 'Calls'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            const _ChatList(),
            _buildCallList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCallList() {
    return Consumer(
      builder: (context, ref, child) {
        final callHistoryAsync = ref.watch(callHistoryListProvider);
        
        return callHistoryAsync.when(
          data: (calls) {
            if (calls.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No call history yet', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              itemCount: calls.length,
              itemBuilder: (context, index) {
                final call = calls[index];
                IconData callIcon;
                Color iconColor;
                switch (call.callType) {
                  case CallType.incoming:
                    callIcon = Icons.call_received;
                    iconColor = AppColors.success;
                    break;
                  case CallType.outgoing:
                    callIcon = Icons.call_made;
                    iconColor = AppColors.textSecondary;
                    break;
                  case CallType.missed:
                    callIcon = Icons.call_missed;
                    iconColor = AppColors.error;
                    break;
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: call.contactImageUrl.isNotEmpty 
                            ? NetworkImage(call.contactImageUrl) 
                            : null,
                        child: call.contactImageUrl.isEmpty 
                            ? Text(call.contactName[0].toUpperCase()) 
                            : null,
                      ),
                      if (call.isOnline && call.showOnlineStatus)
                        Positioned(
                          bottom: 0,
                          right: 2,
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
                  title: Text(
                    call.contactName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(callIcon, size: 16, color: iconColor),
                      const SizedBox(width: 4),
                      Text(
                        _formatCallTime(call.timestamp),
                        style: TextStyle(
                          color: call.callType == CallType.missed ? AppColors.error : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      if (call.durationSeconds > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• ${call.formattedDuration}',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                  trailing: Icon(
                    call.mediaType == CallMediaType.video ? Icons.videocam : Icons.phone,
                    color: AppColors.primary,
                    size: 24,
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading call history: $err', 
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCallTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatListProvider);

    return chatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return const Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                 SizedBox(height: 16),
                 Text('No chats yet. Start a conversation!', style: TextStyle(color: Colors.grey)),
               ],
             ),
          );
        }
        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: chat.isOfficial ? Colors.transparent : null,
                    backgroundImage: chat.isOfficial 
                        ? const AssetImage('assets/images/official_team.png') as ImageProvider
                        : (chat.imageUrl.isNotEmpty ? NetworkImage(chat.imageUrl) : null),
                    child: (chat.imageUrl.isEmpty && !chat.isOfficial) ? Text(chat.name[0]) : null,
                  ),
                  if (chat.isOnline && chat.showOnlineStatus)
                    Positioned(
                      bottom: 0,
                      right: 2,
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
                title: Row(
                  children: [
                    Text(
                      chat.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    if (chat.isOfficial) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: Colors.blue),
                    ]
                  ],
                ),
              subtitle: Text(
                chat.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${chat.lastMessageTime.hour}:${chat.lastMessageTime.minute.toString().padLeft(2, '0')}',
                     style: TextStyle(
                       fontSize: 12, 
                       color: chat.unreadCount > 0 ? Colors.red : Colors.grey,
                       fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                     ),
                  ),
                  if (chat.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        '${chat.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(chat: chat),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}
