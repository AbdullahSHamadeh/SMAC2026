import 'package:flutter/foundation.dart';

import 'models.dart';

class FamilyStore extends ChangeNotifier {
  final List<FamilyMember> members = [
    const FamilyMember(
        id: 'dad',
        name: 'Dad',
        relation: 'Family admin',
        activity: MemberActivity.driving,
        status: 'Driving to work',
        detail: 'ETA 8:35 AM',
        battery: 78,
        isAdmin: true,
        sharesLocation: true),
    const FamilyMember(
        id: 'mom',
        name: 'Mom',
        relation: 'Family admin',
        activity: MemberActivity.shopping,
        status: 'Grocery shopping',
        detail: 'Home in 20 min',
        battery: 92,
        isAdmin: true,
        sharesLocation: true),
    const FamilyMember(
        id: 'abdullah',
        name: 'Abdullah',
        relation: 'You',
        activity: MemberActivity.university,
        status: 'At university',
        detail: 'Arrived',
        battery: 61,
        isAdmin: false,
        sharesLocation: true),
    const FamilyMember(
        id: 'sara',
        name: 'Sara',
        relation: 'Sister',
        activity: MemberActivity.paused,
        status: 'Sharing paused',
        detail: 'Until 6:00 PM',
        battery: 84,
        isAdmin: false,
        sharesLocation: false),
  ];

  final List<ChatMessage> messages = [
    const ChatMessage(
        id: '1',
        author: 'Mom',
        body: 'I am going to the supermarket after work.',
        time: '4:05 PM'),
    const ChatMessage(
        id: '2',
        author: 'Abdullah',
        body: 'Yes, please. I can help with the bags.',
        time: '4:08 PM',
        isMine: true),
  ];

  final List<FamilyReminder> reminders = [
    const FamilyReminder(
        id: '1',
        title: 'Family dinner',
        when: 'Today · 7:00 PM',
        assignee: 'Everyone'),
    const FamilyReminder(
        id: '2',
        title: 'Help Mom with groceries',
        when: 'Today · When Mom arrives',
        assignee: 'Abdullah'),
    const FamilyReminder(
        id: '3',
        title: 'Call Grandma',
        when: 'Friday · 6:30 PM',
        assignee: 'Everyone'),
  ];

  final List<AssistantMessage> assistantMessages = [
    const AssistantMessage(
      text:
          'All active journeys look normal. Dad is driving to work, Abdullah arrived at university, and Mom is free after 2:00 PM.',
      fromUser: false,
    ),
  ];

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    messages.add(ChatMessage(
        id: DateTime.now().toIso8601String(),
        author: 'Abdullah',
        body: text.trim(),
        time: 'Now',
        isMine: true));
    notifyListeners();
  }

  void createReminder(String title,
      {String when = 'Tomorrow · 6:00 PM', String assignee = 'Everyone'}) {
    reminders.insert(
        0,
        FamilyReminder(
            id: DateTime.now().toIso8601String(),
            title: title,
            when: when,
            assignee: assignee));
    notifyListeners();
  }

  void toggleReminder(String id) {
    final index = reminders.indexWhere((item) => item.id == id);
    if (index < 0) return;
    reminders[index] =
        reminders[index].copyWith(completed: !reminders[index].completed);
    notifyListeners();
  }

  void updatePermissions(String id, {bool? isAdmin, bool? sharesLocation}) {
    final index = members.indexWhere((member) => member.id == id);
    if (index < 0) return;
    members[index] = members[index]
        .copyWith(isAdmin: isAdmin, sharesLocation: sharesLocation);
    notifyListeners();
  }

  String askAssistant(String question) {
    final prompt = question.trim();
    if (prompt.isEmpty) return '';
    assistantMessages.add(AssistantMessage(text: prompt, fromUser: true));
    final lower = prompt.toLowerCase();
    late final String answer;
    if (lower.contains('okay') || lower.contains('today')) {
      answer =
          'Everyone appears okay. Dad’s journey is progressing normally, Mom is shopping, Abdullah has arrived, and Sara chose to pause sharing.';
    } else if (lower.contains('dinner') || lower.contains('gather')) {
      answer =
          'Friday after 7:00 PM is open for everyone. I can create a family dinner, home movie night, or evening walk for the family to confirm.';
    } else if (lower.contains('help')) {
      answer =
          'Abdullah is nearby and available after class. I can send him a request to help Mom carry the groceries.';
    } else if (lower.contains('remind')) {
      answer =
          'I drafted a shared reminder. Review the time and recipients before I add it to the family plan.';
    } else {
      answer =
          'I can explain shared journey updates, suggest family time, organize tasks, and prepare reminders. I will say when the available information is uncertain.';
    }
    assistantMessages.add(AssistantMessage(text: answer, fromUser: false));
    notifyListeners();
    return answer;
  }
}
