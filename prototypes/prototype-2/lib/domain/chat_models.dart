enum ChatItemKind {
  message,
  compassDraft,
  poll,
  confirmedPlan,
  checkInRequest,
  checkInResponse,
  reminderDraft,
  reminderConfirmed,
}

class ChatItem {
  const ChatItem({
    required this.id,
    required this.kind,
    required this.authorId,
    required this.text,
    required this.sentAt,
    this.referenceId,
  });

  final String id;
  final ChatItemKind kind;
  final String authorId;
  final String text;
  final DateTime sentAt;
  final String? referenceId;
}
