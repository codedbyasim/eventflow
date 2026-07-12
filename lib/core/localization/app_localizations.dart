import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Supported app languages
enum AppLanguage {
  englishRomanUrdu, // "English / Roman Urdu"
  english,          // "English"
  urdu,             // "اردو"
}

/// Centralized translations for the entire app.
class AppLocalizations {
  final AppLanguage language;

  AppLocalizations(this.language);

  bool get isUrdu => language == AppLanguage.urdu;
  TextDirection get textDirection => isUrdu ? TextDirection.rtl : TextDirection.ltr;

  /// Returns translated string for the given key.
  String get(String key) {
    if (isUrdu) {
      return _urduStrings[key] ?? _englishStrings[key] ?? key;
    }
    return _englishStrings[key] ?? key;
  }

  /// Returns Urdu subtitle (for English/Roman Urdu mode) or empty string for pure Urdu mode.
  String getSubtitle(String key) {
    if (isUrdu) return ''; // In full Urdu mode, no subtitle needed
    return _urduSubtitles[key] ?? '';
  }

  /// Helper to get the correct TextStyle with proper font.
  TextStyle fontStyle({
    dynamic fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = const Color(0xFF1A1A1A),
    double? height,
    TextDecoration? decoration,
  }) {
    final double fs = (fontSize is num) ? fontSize.toDouble() : 14.0;
    if (isUrdu) {
      return GoogleFonts.notoNastaliqUrdu(
        fontSize: fs,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 2.0,
        decoration: decoration,
      );
    }
    return GoogleFonts.inter(
      fontSize: fs,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }

  /// Helper for heading/display font.
  TextStyle headingStyle({
    dynamic fontSize = 32,
    FontWeight fontWeight = FontWeight.bold,
    Color color = const Color(0xFF1A1A1A),
    double? height,
  }) {
    final double fs = (fontSize is num) ? fontSize.toDouble() : 32.0;
    if (isUrdu) {
      return GoogleFonts.notoNastaliqUrdu(
        fontSize: fs * 0.75, // Nastaliq is naturally larger
        fontWeight: fontWeight,
        color: color,
        height: height ?? 2.2,
      );
    }
    return GoogleFonts.playfairDisplay(
      fontSize: fs,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.2,
    );
  }

  // ─── ENGLISH STRINGS ────────────────────────────────────────

  static const Map<String, String> _englishStrings = {
    // Splash
    'splash_tagline': 'Plan beautiful\nmoments,\neffortlessly. ♡',
    'splash_subtitle': 'Eventflow: Your all-in-one\nevent planner.',
    'get_started': 'Get Started',
    'log_in': 'Log In',
    'sign_up': 'Sign Up',

    // Sign In
    'welcome_back': 'Welcome back',
    'create_account': 'Create an account',
    'login_subtitle': 'Log in to continue planning your perfect event.',
    'signup_subtitle': 'Sign up to start planning beautiful moments effortlessly.',
    'email_phone': 'Email or Phone',
    'email_phone_hint': 'Enter your email or phone',
    'password': 'Password',
    'password_hint': 'Enter your password',
    'forgot_password': 'Forgot password?',
    'no_account': "Don't have an account? ",
    'have_account': 'Already have an account? ',
    'skip_guest': 'Skip for now — browse as guest',
    'eventflow': 'EventFlow',
    'email_required': 'Please enter your email or phone',
    'password_required': 'Please enter your password',
    'password_min': 'Password must be at least 6 characters',

    // Event Type
    'set_up_event': 'Set up your event',
    'what_planning': 'What are you\nplanning?',
    'event_type_subtitle': "We'll tailor vendor categories and negotiation strategy to your event type.",
    'continue_btn': 'Continue →',
    'wedding': 'Wedding',
    'corporate_event': 'Corporate event',
    'birthday_anniversary': 'Birthday / Anniversary',
    'religious_gathering': 'Religious gathering',
    'college_fest': 'College / School fest',
    'sports_tournament': 'Sports tournament',

    // Event Details
    'step_2_of_4': 'Step 2 of 4',
    'when_where': 'When and where?',
    'details_subtitle': 'These details help agents check vendor availability in real time.',
    'event_date': 'Event date',
    'select_date': 'Select date',
    'city': 'City',
    'select_city': 'Select city',
    'expected_guests': 'Expected guests',
    'guests': 'guests',
    'venue_preference': 'Venue preference',
    'indoor': 'Indoor',
    'outdoor': 'Outdoor',
    'days_from_today': 'days from today',
    'islamabad': 'Islamabad',
    'islamabad_sub': 'Federal capital, strong vendor availability',
    'lahore': 'Lahore',
    'lahore_sub': 'Largest wedding market in Pakistan',
    'karachi': 'Karachi',
    'karachi_sub': 'Biggest city, most vendor categories',
    'rawalpindi': 'Rawalpindi',
    'rawalpindi_sub': 'Historic city adjacent to Islamabad, active vendors',

    // Vendor Categories
    'step_3_of_4': 'Step 3 of 4',
    'who_need': 'Who do you need?',
    'vendors_selected': 'vendors selected',
    'estimated': 'estimated PKR 200k–500k',
    'suggested': 'Suggested',
    'select_vendor_warning': 'Select at least 1 vendor category',
    'caterer': 'Caterer',
    'decorator': 'Decorator',
    'photographer': 'Photographer',
    'dj_music': 'DJ / Music',
    'tent_marquee': 'Tent / Marquee',
    'sound_system': 'Sound System',
    'flowers': 'Flowers',
    'transport': 'Transport',
    'security': 'Security',

    // Budget
    'step_4_of_4': 'Step 4 of 4',
    'total_budget': "What's your total budget?",
    'budget_subtitle': 'Enter once. Our agents will distribute and negotiate across all your vendors.',
    'suggested_split': 'Suggested split',
    'tap_to_edit': 'ℹ️ Tap to edit',
    'total': 'Total',
    'adjust_allocation': 'Adjust allocation',
    'min_budget': 'Min: PKR 20,000',
    'launch_negotiations': '🚀 Launch Negotiations',
    'agents_to_launch': 'Agents to launch',
    'total_budget_label': '💰 Total budget',
    'date_label': '📅 Date',
    'guests_label': '👥 Guests',
    'city_label': '🏙️ City',
    'not_specified': 'Not specified',
    'tbd': 'TBD',

    // Live Dashboard
    'connecting': 'Connecting...',
    'negotiating': 'Negotiating',
    'counter_offer': 'Counter-offer',
    'deal': 'Deal ✓',
    'no_deal': 'No deal ✗',
    'live': 'LIVE',
    'ai_negotiating': 'AI Negotiating',
    'negotiation_complete': 'Negotiation Complete',
    'budget_label': 'Budget',
    'locked_in': 'Locked in',
    'remaining': 'Remaining',
    'total_savings_vs_asking': 'Total savings vs asking price: ',
    'so_far': ' so far',
    'asking_price': 'Asking price',
    'current_offer': 'Current offer',
    'offer_num': 'Offer #',
    'saved_pkr': 'Saved PKR ',
    'see_best_combination': 'See Best Combination',

    // Booking Success Screen
    'your_event_in_7_days': 'Your event is in 7 days!',
    'check_booking_contacts': 'Check your EventFlow booking for vendor contacts.',
    'booking_confirmed': 'Booking Confirmed!',
    'copied': 'Copied!',
    'days_to_go': 'days to go',
    'event_today': 'Your event is today!',
    'vendor_contacts': 'Vendor Contacts',
    'download_pdf': 'Download PDF',
    'share_event_setup': 'Share Event Setup',
    'back_to_home': 'Back to Home',

    // Home screen
    'home_headline': 'Plan your perfect event with AI',
    'home_subtitle': 'Our agents negotiate the best prices across all vendors.',
    'plan_new_event': 'Plan New Event',
    'how_it_works': 'How it works',
    'feature_1_title': 'Set up your event',
    'feature_1_sub': 'Tell us what type, date, city, and budget.',
    'feature_2_title': 'AI agents negotiate',
    'feature_2_sub': 'Our agents contact vendors and negotiate in real time.',
    'feature_3_title': 'Save up to 30%',
    'feature_3_sub': 'Deals are locked in — no hidden fees.',
    'feature_4_title': 'Confirm your package',
    'feature_4_sub': 'Review the best combination and book.',
    'guest': 'Guest',

    // Customer profile & history
    'my_events': 'My Events',
    'no_events_yet': 'No events yet',
    'start_planning': 'Tap the button above to plan your first event.',
    'total_events': 'Total',
    'booked': 'Booked',
    'in_progress': 'Active',
    'total_savings_label': 'My Savings',
    'sign_out': 'Sign Out',
    'recent_events': 'Recent Events',
    'see_all': 'See all',
    'status': 'Status',
    'ai_package': 'AI-Negotiated Package',
    'view_full_package': 'View Full Package',
  };

  // ─── URDU STRINGS ───────────────────────────────────────────

  static const Map<String, String> _urduStrings = {
    // Splash
    'splash_tagline': 'خوبصورت لمحات\nکی منصوبہ بندی\nآسانی سے ♡',
    'splash_subtitle': 'ایونٹ فلو: آپ کا\nہمہ جہت ایونٹ پلانر',
    'get_started': 'شروع کریں',
    'log_in': 'لاگ ان',
    'sign_up': 'سائن اپ',

    // Sign In
    'welcome_back': 'واپسی پر خوش آمدید',
    'create_account': 'اکاؤنٹ بنائیں',
    'login_subtitle': 'اپنے ایونٹ کی منصوبہ بندی جاری رکھنے کے لیے لاگ ان کریں۔',
    'signup_subtitle': 'خوبصورت لمحات کی آسان منصوبہ بندی شروع کرنے کے لیے سائن اپ کریں۔',
    'email_phone': 'ای میل یا فون',
    'email_phone_hint': 'اپنا ای میل یا فون درج کریں',
    'password': 'پاس ورڈ',
    'password_hint': 'اپنا پاس ورڈ درج کریں',
    'forgot_password': 'پاس ورڈ بھول گئے؟',
    'no_account': 'اکاؤنٹ نہیں ہے؟ ',
    'have_account': 'پہلے سے اکاؤنٹ ہے؟ ',
    'skip_guest': 'ابھی چھوڑیں — بطور مہمان براؤز کریں',
    'eventflow': 'ایونٹ فلو',
    'email_required': 'براہ کرم اپنا ای میل یا فون درج کریں',
    'password_required': 'براہ کرم اپنا پاس ورڈ درج کریں',
    'password_min': 'پاس ورڈ کم از کم 6 حروف کا ہونا چاہیے',

    // Event Type
    'set_up_event': 'اپنا ایونٹ ترتیب دیں',
    'what_planning': 'آپ کیا\nمنصوبہ بنا رہے ہیں؟',
    'event_type_subtitle': 'ہم آپ کے ایونٹ کی قسم کے مطابق وینڈر اور سودے بازی کی حکمت عملی تیار کریں گے۔',
    'continue_btn': 'جاری رکھیں ←',
    'wedding': 'شادی',
    'corporate_event': 'کارپوریٹ ایونٹ',
    'birthday_anniversary': 'سالگرہ',
    'religious_gathering': 'مذہبی تقریب',
    'college_fest': 'کالج / سکول فیسٹ',
    'sports_tournament': 'کھیلوں کا مقابلہ',

    // Event Details
    'step_2_of_4': 'مرحلہ 2 از 4',
    'when_where': 'کب اور کہاں؟',
    'details_subtitle': 'یہ تفصیلات ایجنٹس کو وینڈر کی دستیابی فوری طور پر جانچنے میں مدد کرتی ہیں۔',
    'event_date': 'ایونٹ کی تاریخ',
    'select_date': 'تاریخ منتخب کریں',
    'city': 'شہر',
    'select_city': 'شہر منتخب کریں',
    'expected_guests': 'متوقع مہمان',
    'guests': 'مہمان',
    'venue_preference': 'مقام کی ترجیح',
    'indoor': 'اندرونی',
    'outdoor': 'بیرونی',
    'days_from_today': 'دن آج سے',
    'islamabad': 'اسلام آباد',
    'islamabad_sub': 'وفاقی دارالحکومت، وینڈرز کی بہترین دستیابی',
    'lahore': 'لاہور',
    'lahore_sub': 'پاکستان کی سب سے بڑی شادی مارکیٹ',
    'karachi': 'کراچی',
    'karachi_sub': 'سب سے بڑا شہر، سب سے زیادہ وینڈر زمرے',
    'rawalpindi': 'راولپنڈی',
    'rawalpindi_sub': 'اسلام آباد کے قریب واقع تاریخی شہر، سرگرم وینڈرز',

    // Vendor Categories
    'step_3_of_4': 'مرحلہ 3 از 4',
    'who_need': 'آپ کو کس کی ضرورت ہے؟',
    'vendors_selected': 'وینڈرز منتخب',
    'estimated': 'تخمینہ PKR 200k–500k',
    'suggested': 'تجویز کردہ',
    'select_vendor_warning': 'کم از کم 1 وینڈر زمرہ منتخب کریں',
    'caterer': 'کیٹرر',
    'decorator': 'ڈیکوریٹر',
    'photographer': 'فوٹوگرافر',
    'dj_music': 'ڈی جے / موسیقی',
    'tent_marquee': 'خیمہ / مارکی',
    'sound_system': 'ساؤنڈ سسٹم',
    'flowers': 'پھول',
    'transport': 'ٹرانسپورٹ',
    'security': 'سیکیورٹی',

    // Budget
    'step_4_of_4': 'مرحلہ 4 از 4',
    'total_budget': 'آپ کا کل بجٹ کیا ہے؟',
    'budget_subtitle': 'ایک بار درج کریں۔ ہمارے ایجنٹس آپ کے تمام وینڈرز میں تقسیم اور سودے بازی کریں گے۔',
    'suggested_split': 'تجویز کردہ تقسیم',
    'tap_to_edit': 'ℹ️ ترمیم کے لیے ٹیپ کریں',
    'total': 'کل',
    'adjust_allocation': 'تقسیم ایڈجسٹ کریں',
    'min_budget': 'کم از کم: PKR 20,000',
    'launch_negotiations': '🚀 سودے بازی شروع کریں',
    'agents_to_launch': 'شروع ہونے والے ایجنٹس',
    'total_budget_label': '💰 کل بجٹ',
    'date_label': '📅 تاریخ',
    'guests_label': '👥 مہمان',
    'city_label': '🏙️ شہر',
    'not_specified': 'نامعلوم',
    'tbd': 'طے نہیں',

    // Live Dashboard
    'connecting': 'رابطہ ہو رہا ہے...',
    'negotiating': 'بات چیت جاری',
    'counter_offer': 'جوابی پیشکش',
    'deal': 'معاہدہ ✓',
    'no_deal': 'معاہدہ نہیں ہوا ✗',
    'live': 'لائیو',
    'ai_negotiating': 'اے آئی بات چیت کر رہا ہے',
    'negotiation_complete': 'بات چیت مکمل',
    'budget_label': 'بجٹ',
    'locked_in': 'طے شدہ',
    'remaining': 'باقی',
    'total_savings_vs_asking': 'طلب کردہ قیمت کے مقابلے میں کل بچت: ',
    'so_far': ' اب تک',
    'asking_price': 'طلب کردہ قیمت',
    'current_offer': 'موجودہ پیشکش',
    'offer_num': 'پیشکش #',
    'saved_pkr': 'بچت PKR ',
    'see_best_combination': 'بہترین مجموعہ دیکھیں',

    // Booking Success Screen
    'your_event_in_7_days': 'آپ کا ایونٹ 7 دن میں ہے!',
    'check_booking_contacts': 'وینڈر رابطوں کے لیے اپنی ایونٹ فلو بکنگ چیک کریں۔',
    'booking_confirmed': 'بکنگ کی تصدیق ہو گئی!',
    'copied': 'کاپی ہو گیا!',
    'days_to_go': 'دن باقی',
    'event_today': 'آپ کا ایونٹ آج ہے!',
    'vendor_contacts': 'وینڈر کے رابطے',
    'download_pdf': 'پی ڈی ایف ڈاؤن لوڈ کریں',
    'share_event_setup': 'ایونٹ سیٹ اپ شیئر کریں',
    'back_to_home': 'ہوم پر واپس جائیں',

    // Home screen
    'home_headline': 'اے آئی کے ساتھ اپنا بہترین ایونٹ منصوبہ بنائیں',
    'home_subtitle': 'ہمارے ایجنٹ تمام وینڈروں سے بہترین قیمتیں طے کرتے ہیں۔',
    'plan_new_event': 'نیا ایونٹ منصوبہ بنائیں',
    'how_it_works': 'یہ کیسے کام کرتا ہے',
    'feature_1_title': 'اپنا ایونٹ ترتیب دیں',
    'feature_1_sub': 'قسم، تاریخ، شہر اور بجٹ بتائیں۔',
    'feature_2_title': 'اے آئی ایجنٹ بات چیت کرتے ہیں',
    'feature_2_sub': 'ہمارے ایجنٹ وینڈروں سے براہ راست بات کرتے ہیں۔',
    'feature_3_title': '30٪ تک بچت',
    'feature_3_sub': 'معاہدے طے ہو جاتے ہیں — کوئی پوشیدہ فیس نہیں۔',
    'feature_4_title': 'اپنا پیکج تصدیق کریں',
    'feature_4_sub': 'بہترین مجموعہ دیکھیں اور بک کریں۔',
    'guest': 'مہمان',

    // Customer profile & history
    'my_events': 'میرے ایونٹ',
    'no_events_yet': 'ابھی تک کوئی ایونٹ نہیں',
    'start_planning': 'اپنا پہلا ایونٹ منصوبہ بنانے کے لیے اوپر والا بٹن دبائیں۔',
    'total_events': 'کل',
    'booked': 'بک شدہ',
    'in_progress': 'جاری',
    'total_savings_label': 'میری بچت',
    'sign_out': 'سائن آؤٹ',
    'recent_events': 'حالیہ ایونٹ',
    'see_all': 'سب دیکھیں',
    'status': 'حیثیت',
    'ai_package': 'اے آئی مذاکرہ شدہ پیکج',
    'view_full_package': 'مکمل پیکج دیکھیں',
  };

  // ─── URDU SUBTITLES (for English/Roman Urdu mode) ───────────

  static const Map<String, String> _urduSubtitles = {
    'wedding': 'شادی',
    'corporate_event': 'کارپوریٹ ایونٹ',
    'birthday_anniversary': 'سالگرہ',
    'religious_gathering': 'مذہبی تقریب',
    'college_fest': 'کالج فیسٹ',
    'sports_tournament': 'کھیلوں کا مقابلہ',
  };
}
