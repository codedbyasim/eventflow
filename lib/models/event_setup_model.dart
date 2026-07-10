class EventSetupModel {
  String? eventType;
  List<String> preSelectedVendors;
  
  DateTime? eventDate;
  String? city;
  int guestCount;
  String? venuePreference; // 'Indoor' or 'Outdoor'

  List<String> selectedVendors;
  int totalBudget;

  EventSetupModel({
    this.eventType,
    this.preSelectedVendors = const [],
    this.eventDate,
    this.city,
    this.guestCount = 50,
    this.venuePreference = 'Indoor',
    this.selectedVendors = const [],
    this.totalBudget = 0,
  });

  EventSetupModel copyWith({
    String? eventType,
    List<String>? preSelectedVendors,
    DateTime? eventDate,
    String? city,
    int? guestCount,
    String? venuePreference,
    List<String>? selectedVendors,
    int? totalBudget,
  }) {
    return EventSetupModel(
      eventType: eventType ?? this.eventType,
      preSelectedVendors: preSelectedVendors ?? this.preSelectedVendors,
      eventDate: eventDate ?? this.eventDate,
      city: city ?? this.city,
      guestCount: guestCount ?? this.guestCount,
      venuePreference: venuePreference ?? this.venuePreference,
      selectedVendors: selectedVendors ?? this.selectedVendors,
      totalBudget: totalBudget ?? this.totalBudget,
    );
  }
}
