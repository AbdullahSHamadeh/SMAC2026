enum MemberActivity { driving, shopping, university, home, walking, paused }

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    required this.activity,
    required this.status,
    required this.detail,
    required this.battery,
    required this.isAdmin,
    required this.sharesLocation,
  });

  final String id;
  final String name;
  final String relation;
  final MemberActivity activity;
  final String status;
  final String detail;
  final int battery;
  final bool isAdmin;
  final bool sharesLocation;

  FamilyMember copyWith({bool? isAdmin, bool? sharesLocation}) => FamilyMember(
        id: id,
        name: name,
        relation: relation,
        activity: activity,
        status: status,
        detail: detail,
        battery: battery,
        isAdmin: isAdmin ?? this.isAdmin,
        sharesLocation: sharesLocation ?? this.sharesLocation,
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.body,
    required this.time,
    this.isMine = false,
  });

  final String id;
  final String author;
  final String body;
  final String time;
  final bool isMine;
}

class FamilyReminder {
  const FamilyReminder({
    required this.id,
    required this.title,
    required this.when,
    required this.assignee,
    this.completed = false,
  });

  final String id;
  final String title;
  final String when;
  final String assignee;
  final bool completed;

  FamilyReminder copyWith({bool? completed}) => FamilyReminder(
        id: id,
        title: title,
        when: when,
        assignee: assignee,
        completed: completed ?? this.completed,
      );
}

class AssistantMessage {
  const AssistantMessage({required this.text, required this.fromUser});
  final String text;
  final bool fromUser;
}
