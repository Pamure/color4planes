// lib/models/friend_model.dart

enum FriendState { mutual, sentByMe, sentByThem, blocked }

class FriendModel {
  final String      userId;
  final String      displayName;
  final String      username;
  final FriendState friendState;
  final bool        online;

  const FriendModel({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.friendState,
    required this.online,
  });
}
