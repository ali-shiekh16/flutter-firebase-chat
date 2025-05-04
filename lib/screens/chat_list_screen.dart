import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final DateFormat _timeFormat = DateFormat('h:mm a');
  final DateFormat _dateFormat = DateFormat('MM/dd/yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Your Conversations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getChatRooms(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final chatRooms = snapshot.data?.docs ?? [];

                if (chatRooms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No conversations yet',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            _showStartChatDialog(context);
                          },
                          child: const Text('Start a new chat'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: chatRooms.length,
                  itemBuilder: (context, index) {
                    final chatRoom =
                        chatRooms[index].data() as Map<String, dynamic>;
                    final participants =
                        chatRoom['participants'] as List<dynamic>;
                    final String otherUserId = participants.firstWhere(
                      (id) => id != _chatService.currentUserId,
                      orElse: () => _chatService.currentUserId,
                    );
                    final bool isUnread =
                        chatRoom['lastMessageSenderId'] !=
                            _chatService.currentUserId &&
                        (chatRoom['unreadCount'] ?? 0) > 0;

                    // Format time
                    String formattedTime = '';
                    if (chatRoom['lastMessageTime'] != null) {
                      final DateTime messageTime =
                          (chatRoom['lastMessageTime'] as Timestamp).toDate();
                      final DateTime now = DateTime.now();
                      if (now.difference(messageTime).inDays < 1 &&
                          now.day == messageTime.day) {
                        formattedTime = _timeFormat.format(messageTime);
                      } else {
                        formattedTime = _dateFormat.format(messageTime);
                      }
                    }

                    return FutureBuilder<DocumentSnapshot>(
                      future:
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(otherUserId)
                              .get(),
                      builder: (context, userSnapshot) {
                        String userName = 'Loading...';

                        if (userSnapshot.connectionState ==
                            ConnectionState.done) {
                          if (userSnapshot.hasData &&
                              userSnapshot.data!.exists) {
                            final userData =
                                userSnapshot.data!.data()
                                    as Map<String, dynamic>;
                            userName = userData['name'] ?? 'Unknown User';
                          } else {
                            userName = 'Unknown User';
                          }
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            userName,
                            style: TextStyle(
                              fontWeight:
                                  isUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            chatRoom['lastMessage'] ?? 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  isUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formattedTime),
                              if (isUnread)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${chatRoom['unreadCount'] ?? 0}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ChatScreen(
                                      userId: otherUserId,
                                      userName: userName,
                                    ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showStartChatDialog(context);
        },
        child: const Icon(Icons.chat),
      ),
    );
  }

  void _showStartChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController emailController = TextEditingController();

        return AlertDialog(
          title: const Text('Start a new chat'),
          content: TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Enter email address',
              hintText: 'example@email.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  final QuerySnapshot result =
                      await FirebaseFirestore.instance
                          .collection('users')
                          .where('email', isEqualTo: email)
                          .limit(1)
                          .get();

                  Navigator.pop(context);

                  if (result.docs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'User not found. Please check the email and try again.',
                        ),
                      ),
                    );
                  } else {
                    final userData =
                        result.docs.first.data() as Map<String, dynamic>;
                    final userId = result.docs.first.id;

                    if (userId == _chatService.currentUserId) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You cannot chat with yourself!'),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ChatScreen(
                                userId: userId,
                                userName: userData['name'] ?? 'Unknown User',
                              ),
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Start Chat'),
            ),
          ],
        );
      },
    );
  }
}
