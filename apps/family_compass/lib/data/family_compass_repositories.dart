import '../domain/chat_models.dart';
import '../domain/compass_models.dart';
import '../domain/family_models.dart';
import '../domain/plan_models.dart';

class BackendCapabilityUnavailableException implements Exception {
  const BackendCapabilityUnavailableException(this.capability);

  final String capability;

  @override
  String toString() =>
      '$capability is not available in the current FastAPI development slice.';
}

/// Mobile-facing contracts for the production data layer.
///
/// The current build uses deterministic demonstration state. Future Firebase,
/// FastAPI, and local-cache implementations must sit behind these contracts so
/// feature screens never construct permission context or provider requests.
class FamilyCompassRepositories {
  const FamilyCompassRepositories({
    required this.session,
    required this.family,
    required this.chat,
    required this.plans,
    required this.sharing,
    required this.compass,
    required this.permissions,
    required this.checkIns,
    required this.today,
    required this.journeys,
    required this.reminders,
    this.memberStatuses,
    this.devices,
    this.familyRoomCompass,
  });

  final SessionRepository session;
  final FamilyRepository family;
  final ChatRepository chat;
  final PlanRepository plans;
  final SharingRepository sharing;
  final CompassRepository compass;
  final PermissionRepository permissions;
  final CheckInRepository checkIns;
  final TodayRepository today;
  final JourneyRepository journeys;
  final ReminderRepository reminders;
  final MemberStatusRepository? memberStatuses;
  final DeviceRepository? devices;
  final FamilyRoomCompassRepository? familyRoomCompass;
}

enum RepositoryPhase { idle, loading, ready, offline, failed }

class RepositoryStatus {
  const RepositoryStatus({
    required this.phase,
    this.message,
    this.pendingWrites = 0,
    this.canRetry = false,
  });

  const RepositoryStatus.idle()
      : phase = RepositoryPhase.idle,
        message = null,
        pendingWrites = 0,
        canRetry = false;

  final RepositoryPhase phase;
  final String? message;
  final int pendingWrites;
  final bool canRetry;
}

abstract interface class SyncableRepository {
  Stream<RepositoryStatus> get status;

  Future<void> refresh();

  Future<void> retryPending();
}

abstract interface class SessionRepository implements SyncableRepository {
  Stream<AppSession?> watchSession();

  /// Verifies the configured local development identity with FastAPI.
  Future<AppSession> startDevelopmentSession();

  Future<void> requestPhoneCode(String internationalPhoneNumber);

  Future<AppSession> verifyPhoneCode({
    required String verificationId,
    required String code,
  });

  Future<void> signOut();
}

abstract interface class FamilyRepository implements SyncableRepository {
  Future<FamilySummary> createFamily(String name);

  Future<List<FamilySummary>> listFamilies();

  Stream<FamilySummary> watchFamily(String familyId);

  Stream<List<FamilyInvitation>> watchInvitations(String familyId);

  Future<FamilyInvitation> inviteByPhone({
    required String familyId,
    required String internationalPhoneNumber,
    required String idempotencyKey,
  });

  Future<void> respondToInvitation({
    required String invitationId,
    required InvitationResponse response,
  });

  Future<void> revokeInvitation(String invitationId);

  Future<void> leaveFamily(String familyId);

  Future<void> removeMember({
    required String familyId,
    required String memberId,
  });

  /// Permanently deletes the family and all family-owned records.
  ///
  /// Implementations must restrict this to the organizer and keep user
  /// accounts intact.
  Future<void> deleteFamily(String familyId);
}

abstract interface class ChatRepository implements SyncableRepository {
  Stream<List<ChatItem>> watchMessages({
    required String familyId,
    String? afterMessageId,
  });

  Future<ChatItem> getMessage({
    required String familyId,
    required String messageId,
  });

  Future<ChatItem> sendText({
    required String familyId,
    required String text,
    required String idempotencyKey,
    Set<String> mentionedMemberIds = const <String>{},
    bool queueOnly = false,
  });

  /// Permanently removes locally queued writes for [familyId].
  ///
  /// Call this after sign-out, leave, deletion, or confirmed membership loss
  /// so private content cannot survive outside its authenticated family scope.
  Future<void> discardPending({required String familyId});
}

abstract interface class PlanRepository implements SyncableRepository {
  Future<FamilyPlan> createPlan({
    required String familyId,
    required String title,
    String? locationLabel,
    required List<String> participantIds,
    required List<CandidateTime> candidateTimes,
    required DateTime decisionDeadline,
  });

  Future<FamilyPlan> publishPlan({
    required String familyId,
    required String planId,
    required Set<String> candidateIds,
    required int expectedVersion,
  });

  Future<FamilyPlan> suggestCandidateTime({
    required String familyId,
    required String planId,
    required CandidateTime candidate,
    required int expectedVersion,
  });

  Stream<List<FamilyPlan>> watchPlans(String familyId);

  Future<FamilyPlan> saveResponse({
    required String planId,
    required String candidateId,
    required RsvpChoice choice,
    required int expectedVersion,
  });

  Future<FamilyPlan> confirmPlan({
    required String planId,
    required String candidateId,
    required int expectedVersion,
  });

  Future<FamilyPlan> addContribution({
    required String familyId,
    required String planId,
    required String text,
  });

  Future<FamilyPlan> sendNudge({
    required String familyId,
    required String planId,
  });

  Future<FamilyPlan> completePlan({
    required String familyId,
    required String planId,
  });

  Future<FamilyPlan> getPlan({
    required String familyId,
    required String planId,
  });

  Future<FamilyPlan> getPlanForReminder({
    required String familyId,
    required String reminderId,
  });
}

abstract interface class SharingRepository implements SyncableRepository {
  Stream<List<SharedStatus>> watchPermittedStatuses(String familyId);

  /// [recipientIds] is non-empty only for [SharingAudience.selectedPeople].
  /// Whole-family and only-me writes pass an empty set.
  Future<SharedStatus> shareManualStatus({
    required String familyId,
    required String text,
    required SharingAudience audience,
    required Set<String> recipientIds,
    required DateTime expiresAt,
  });

  Future<void> pauseStatus(String statusId);

  Future<void> revokeStatus(String statusId);
}

abstract interface class CompassRepository {
  /// Sends only the user's question and conversation identifier.
  ///
  /// Authentication, family membership, expiry, audience, external-provider
  /// consent, and fact minimization are enforced by the backend before a model
  /// receives any context.
  Future<CompassAnswer> ask({
    required String conversationId,
    required String question,
    CompassVisibility visibility = CompassVisibility.private,
  });
}

/// Family-visible Compass requests are deliberately separate from private
/// Compass conversations. Implementations must require an explicit @Compass
/// mention and never mix private conversation history into this stream.
abstract interface class FamilyRoomCompassRepository
    implements SyncableRepository {
  Stream<List<FamilyRoomCompassArtifact>> watchArtifacts(String familyId);

  /// Returns a suggestion artifact only. The caller must show confirmation
  /// before invoking any consequential action through another repository.
  Future<FamilyRoomCompassArtifact> ask({
    required String familyId,
    required String prompt,
    required String idempotencyKey,
    Set<String> mentionedMemberIds = const <String>{},
  });
}

enum CompassVisibility { private, familyRoom }

enum InvitationResponse { accept, decline }

abstract interface class PermissionRepository implements SyncableRepository {
  Stream<List<FamilyPermission>> watchPermissions(String familyId);

  Future<FamilyPermission> setInvitePermission({
    required String familyId,
    required String memberId,
    required bool canInvite,
  });

  Future<void> setExternalAIConsent({
    required String familyId,
    required bool allowed,
  });
}

abstract interface class CheckInRepository implements SyncableRepository {
  Future<FamilyCheckIn> request({
    required String familyId,
    required String memberId,
  });
}

abstract interface class TodayRepository implements SyncableRepository {
  Stream<TodayOverview> watchToday(String familyId);
}

abstract interface class JourneyRepository implements SyncableRepository {
  /// This adapter exists for an optional, explicitly consented backend
  /// capability. The current public product intentionally has no map screen.
  Stream<List<FamilyJourney>> watchJourneys(String familyId);

  Future<FamilyJourney> createJourney({
    required String familyId,
    required String summary,
    required String status,
    DateTime? eta,
    required SharingAudience audience,
    required Set<String> recipientIds,
    required DateTime expiresAt,
  });

  Future<void> endJourney({
    required String familyId,
    required String journeyId,
    bool completed = true,
  });
}

abstract interface class ReminderRepository implements SyncableRepository {
  Stream<List<PlanReminder>> watchReminders(String familyId);

  Future<PlanReminder> createReminder({
    required String familyId,
    required String planId,
    required String label,
    required DateTime at,
  });

  Future<PlanReminder> updateReminder({
    required String familyId,
    required String reminderId,
    required DateTime at,
  });
}

abstract interface class MemberStatusRepository implements SyncableRepository {
  Stream<List<MemberStatusSummary>> watchStatuses(String familyId);

  Future<MemberStatusSummary> updateOwnStatus({
    required String familyId,
    required String summary,
    String? detail,
    required SharingAudience audience,
    required Set<String> recipientIds,
    required DateTime expiresAt,
  });

  Future<void> setStatusState({
    required String familyId,
    required String statusId,
    required SharingState state,
  });
}

abstract interface class DeviceRepository implements SyncableRepository {
  Future<List<DeviceRegistration>> listDevices();

  Future<DeviceRegistration> register({
    required String token,
    required DevicePlatform platform,
  });

  Future<void> unregister(String deviceId);
}

enum DevicePlatform { ios, android, web }

class DeviceRegistration {
  const DeviceRegistration({
    required this.id,
    required this.platform,
    required this.enabled,
    required this.createdAt,
  });

  final String id;
  final DevicePlatform platform;
  final bool enabled;
  final DateTime createdAt;
}

class MemberStatusSummary {
  const MemberStatusSummary({
    required this.id,
    required this.memberId,
    required this.summary,
    required this.updatedAt,
    required this.expiresAt,
    required this.state,
    this.detail,
  });

  final String id;
  final String memberId;
  final String summary;
  final String? detail;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final SharingState state;
}

class AppSession {
  const AppSession({
    required this.userId,
    required this.phoneNumber,
    required this.familyIds,
  });

  final String userId;
  final String phoneNumber;
  final List<String> familyIds;
}

class FamilySummary {
  const FamilySummary({
    required this.id,
    required this.name,
    required this.members,
    this.organizerId,
  });

  final String id;
  final String name;
  final List<FamilyMember> members;
  final String? organizerId;
}

class FamilyInvitation {
  const FamilyInvitation({
    required this.id,
    required this.familyId,
    required this.maskedPhoneNumber,
    required this.expiresAt,
    this.state = FamilyInvitationState.pending,
  });

  final String id;
  final String familyId;
  final String maskedPhoneNumber;
  final DateTime expiresAt;
  final FamilyInvitationState state;
}

enum FamilyInvitationState { pending, accepted, declined, revoked, expired }

class FamilyPermission {
  const FamilyPermission({
    required this.member,
    required this.canInvite,
  });

  final FamilyMember member;
  final bool canInvite;
}

class FamilyCheckIn {
  const FamilyCheckIn({
    required this.id,
    required this.familyId,
    required this.requesterId,
    required this.memberId,
    required this.state,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String requesterId;
  final String memberId;
  final String state;
  final DateTime createdAt;
}

class FamilySuggestion {
  const FamilySuggestion({
    required this.id,
    required this.title,
    required this.reason,
    required this.actionLabel,
  });

  final String id;
  final String title;
  final String reason;
  final String actionLabel;
}

class TodayOverview {
  const TodayOverview({
    required this.needsReply,
    required this.sharedUpdates,
    this.nextPlan,
    this.suggestion,
  });

  final FamilyPlan? nextPlan;
  final List<FamilyPlan> needsReply;
  final List<SharedStatus> sharedUpdates;
  final FamilySuggestion? suggestion;
}
