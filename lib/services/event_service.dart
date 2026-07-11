import '../models/event_setup_model.dart';
import 'backend_service.dart';

/// Submits a completed event setup wizard to the backend.
///
/// FR-EVT-07: On submission, the backend creates the event record and
///            triggers the Analyzer Agent within 3 seconds.
/// NFR-SEC-02: Never calls Fireworks AI directly — all LLM calls go through backend.
class EventService {
  EventService._();
  static final EventService instance = EventService._();

  /// Submit the event and return the Firestore event document ID.
  ///
  /// The Flutter client uses the returned [eventFirestoreId] to:
  ///   1. Navigate to the LiveDashboardScreen
  ///   2. Listen to `events/{eventFirestoreId}` in real time
  ///   3. Watch `negotiations/{id}` documents for agent activity
  ///
  /// Throws [BackendException] if submission fails.
  Future<EventSubmitResult> submitEvent(
    EventSetupModel model, {
    Map<String, double>? perCategoryMax,
  }) async {
    final body = <String, dynamic>{
      'event_type': model.eventType ?? 'Other',
      'event_date': model.eventDate?.toIso8601String().split('T').first,
      'city': (model.city ?? '').toLowerCase(),
      'guest_count': model.guestCount,
      'indoor_outdoor': model.venuePreference,
      'categories': model.selectedVendors,
      'total_budget': model.totalBudget,
      'negotiation_flexibility': model.negotiationFlexibility,
    };

    if (perCategoryMax != null && perCategoryMax.isNotEmpty) {
      body['per_category_max'] = perCategoryMax.map(
        (k, v) => MapEntry(k, v.toInt()),
      );
    }

    final response = await BackendService.instance.post('/events', body: body);

    return EventSubmitResult(
      eventId: response['event_id'] as String,
      eventFirestoreId: response['firestore_id'] as String,
      status: response['status'] as String,
      message: response['message'] as String,
    );
  }
}

class EventSubmitResult {
  final String eventId;
  final String eventFirestoreId;
  final String status;
  final String message;

  const EventSubmitResult({
    required this.eventId,
    required this.eventFirestoreId,
    required this.status,
    required this.message,
  });
}
