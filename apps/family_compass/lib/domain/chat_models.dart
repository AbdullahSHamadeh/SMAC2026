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

enum ChatDeliveryState { sent, waitingToSend, failed }

final RegExp _compassMentionPattern = RegExp(
  r'(^|[\s([{:،])@compass(?=$|[\s,،:؛.!?؟])',
  caseSensitive: false,
);

/// Whether [value] contains a distinct Compass mention.
///
/// A boundary is required so email addresses and handles such as
/// `@CompassBot` remain ordinary family messages.
bool containsCompassMentionText(String value) =>
    _compassMentionPattern.hasMatch(value);

RegExpMatch? firstCompassMentionMatch(String value) =>
    _compassMentionPattern.firstMatch(value);

class ChatItem {
  ChatItem({
    required this.id,
    required this.kind,
    required this.authorId,
    required this.text,
    required this.sentAt,
    this.referenceId,
    this.clientId,
    Set<String> mentionedMemberIds = const <String>{},
    this.deliveryState = ChatDeliveryState.sent,
  }) : mentionedMemberIds = Set<String>.unmodifiable(mentionedMemberIds);

  final String id;
  final ChatItemKind kind;
  final String authorId;
  final String text;
  final DateTime sentAt;
  final String? referenceId;
  final String? clientId;
  final Set<String> mentionedMemberIds;
  final ChatDeliveryState deliveryState;

  ChatItem copyWith({ChatDeliveryState? deliveryState}) => ChatItem(
        id: id,
        kind: kind,
        authorId: authorId,
        text: text,
        sentAt: sentAt,
        referenceId: referenceId,
        clientId: clientId,
        mentionedMemberIds: mentionedMemberIds,
        deliveryState: deliveryState ?? this.deliveryState,
      );
}
