import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isOnline;

  const ChatScreen({
    super.key, 
    required this.userId, 
    required this.userName,
    this.isOnline = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DateFormat _timeFormat = DateFormat('h:mm a');
  bool _isTyping = false;
  
  // We'll use this to check if the user is online
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
    
    // Stream to listen to the other user's online status
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead() async {
    await _chatService.markMessagesAsRead(widget.userId);
  }

  void _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isNotEmpty) {
      _messageController.clear();
      await _chatService.sendMessage(widget.userId, message);

      // Scroll to bottom after sending a message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 30,
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          initialData: null,
          builder: (context, snapshot) {
            bool isUserOnline = widget.isOnline;
            String lastSeen = '';
            
            if (snapshot.hasData && snapshot.data != null) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              if (userData != null) {
                isUserOnline = userData['isOnline'] ?? false;
                
                if (!isUserOnline && userData['lastSeen'] != null) {
                  final lastSeenTime = (userData['lastSeen'] as Timestamp).toDate();
                  final now = DateTime.now();
                  final difference = now.difference(lastSeenTime);
                  
                  if (difference.inMinutes < 1) {
                    lastSeen = 'last seen just now';
                  } else if (difference.inHours < 1) {
                    lastSeen = 'last seen ${difference.inMinutes}m ago';
                  } else if (difference.inDays < 1) {
                    lastSeen = 'last seen ${difference.inHours}h ago';
                  } else {
                    lastSeen = 'last seen ${difference.inDays}d ago';
                  }
                }
              }
            }
            
            return Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      radius: 20,
                      child: Text(
                        widget.userName.isNotEmpty
                            ? widget.userName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isUserOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName, 
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isUserOnline ? 'Online' : lastSeen,
                        style: TextStyle(
                          fontSize: 12,
                          color: isUserOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show options menu
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text('Clear chat history'),
                        onTap: () {
                          Navigator.pop(context);
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Clear chat history?'),
                              content: const Text('This will permanently delete all messages. This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // TODO: Implement clear chat functionality
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Chat history cleared')),
                                    );
                                  },
                                  child: Text('Clear', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.block),
                        title: const Text('Block user'),
                        onTap: () {
                          Navigator.pop(context);
                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Block ${widget.userName}?'),
                              content: Text('You will no longer receive messages from ${widget.userName}.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // TODO: Implement block functionality
                                    Navigator.pop(context);
                                    Navigator.pop(context); // Go back to chat list
                                  },
                                  child: Text('Block', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Auto-scroll to bottom on initial load and when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
                
                DateTime? previousDate;
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = MessageModel.fromFirestore(messages[index]);
                    final bool isMe = message.senderId == _chatService.currentUserId;
                    final time = message.timestamp != null ? _timeFormat.format(message.timestamp!) : '';
                    
                    // Check if we need to show date header
                    Widget? dateHeader;
                    if (message.timestamp != null) {
                      final messageDate = DateTime(
                        message.timestamp!.year,
                        message.timestamp!.month,
                        message.timestamp!.day,
                      );
                      
                      if (previousDate == null || 
                          previousDate?.day != messageDate.day || 
                          previousDate?.month != messageDate.month || 
                          previousDate?.year != messageDate.year) {
                        
                        previousDate = messageDate;
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final yesterday = DateTime(now.year, now.month, now.day - 1);
                        
                        String dateText;
                        if (messageDate == today) {
                          dateText = 'Today';
                        } else if (messageDate == yesterday) {
                          dateText = 'Yesterday';
                        } else {
                          dateText = DateFormat('MMMM d, y').format(messageDate);
                        }
                        
                        dateHeader = Container(
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  dateText,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                            ],
                          ),
                        );
                      }
                    }

                    return Column(
                      children: [
                        if (dateHeader != null) dateHeader,
                        Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.only(
                              bottom: 8,
                              left: isMe ? 80 : 0,
                              right: isMe ? 0 : 80,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMe 
                                ? Theme.of(context).colorScheme.primary 
                                : isDarkMode 
                                  ? Colors.grey[800] 
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20).copyWith(
                                bottomRight: isMe ? const Radius.circular(0) : null,
                                bottomLeft: !isMe ? const Radius.circular(0) : null,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.content,
                                  style: TextStyle(
                                    color: isMe 
                                      ? Colors.white 
                                      : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      time,
                                      style: TextStyle(
                                        color: isMe 
                                          ? Colors.white70 
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Typing indicator
          StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, snapshot) {
              final isTyping = snapshot.hasData && 
                  snapshot.data != null && 
                  (snapshot.data!.data() as Map<String, dynamic>?)?.containsKey('isTyping') == true &&
                  (snapshot.data!.data() as Map<String, dynamic>)['isTyping'] == true;
                  
              return AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: isTyping
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          '${widget.userName} is typing...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
          // Message input area
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.emoji_emotions_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      // TODO: Implement emoji picker
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onChanged: (text) {
                                // Update typing status
                                final isCurrentlyTyping = text.isNotEmpty;
                                if (isCurrentlyTyping != _isTyping) {
                                  _isTyping = isCurrentlyTyping;
                                  // TODO: If you want to implement typing indicators,
                                  // update the database here to show when the user is typing
                                }
                              },
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.attachment_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () {
                              // TODO: Implement attachment picker
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.camera_alt_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () {
                              // TODO: Implement camera
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
