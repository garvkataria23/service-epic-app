import '../../domain/models/service_category.dart';
import '../../domain/models/service_request.dart';

class GeneratedBrief {
  const GeneratedBrief({
    required this.title,
    required this.description,
    required this.category,
    required this.budgetMin,
    required this.budgetMax,
    required this.urgency,
    required this.customAnswers,
    required this.suggestedAttachments,
  });

  final String title;
  final String description;
  final ServiceCategory category;
  final double budgetMin;
  final double budgetMax;
  final RequestUrgency urgency;
  final Map<String, String> customAnswers;
  final List<String> suggestedAttachments;
}

/// On-device NLP brief structurer that transforms a casual 1-line problem
/// into a structured, provider-ready requirement brief.
class SmartBriefGenerator {
  SmartBriefGenerator._();

  static GeneratedBrief generate(String rawInput) {
    final text = rawInput.trim();
    final lower = text.toLowerCase();

    final isUrgent = RegExp(
      r'\b(urgent|asap|today|emergency|immediate|leak|broken|now)\b',
    ).hasMatch(lower);
    final urgency =
        isUrgent ? RequestUrgency.urgent : RequestUrgency.normal;

    if (RegExp(r'\b(flutter|app|android|ios|mobile|web|website|api|code|bug)\b')
        .hasMatch(lower)) {
      final isWeb = lower.contains('web') || lower.contains('site');
      return GeneratedBrief(
        title: _capitalize(
          text.length > 10 ? text : 'Custom Mobile / Web App Build',
        ),
        description:
            'Looking for an experienced engineering team for: "$text".\n'
            '• Clean, scalable architecture with API & database integration\n'
            '• Responsive mobile/web UI with proper error handling & validations\n'
            '• Automated tests and deployment-ready build handover',
        category: ServiceCategory.techSoftware,
        budgetMin: isWeb ? 350 : 450,
        budgetMax: isWeb ? 950 : 1250,
        urgency: urgency,
        customAnswers: {
          'platform': isWeb ? 'Web Application' : 'Cross-Platform',
          'deliverableType': 'New MVP / Build',
        },
        suggestedAttachments: const ['UI Wireframe', 'Specification PDF'],
      );
    }

    if (RegExp(r'\b(clean|maid|sofa|carpet|sanitize|dust|bhk|deep)\b')
        .hasMatch(lower)) {
      return GeneratedBrief(
        title: _capitalize(
          text.length > 10 ? text : 'Full Home Deep Cleaning & Sanitization',
        ),
        description:
            'Need a verified, eco-friendly cleaning crew for: "$text".\n'
            '• HEPA vacuuming, bathroom/kitchen degreasing, and floor sanitization\n'
            '• Pet-safe, non-toxic supplies brought by the team\n'
            '• Post-service inspection before handover',
        category: ServiceCategory.cleaningCare,
        budgetMin: 85,
        budgetMax: 175,
        urgency: urgency,
        customAnswers: const {
          'areaSize': '2–3 BHK',
          'ecoFriendly': 'Eco-friendly / Pet-safe',
        },
        suggestedAttachments: const ['Site Photo'],
      );
    }

    if (RegExp(r'\b(logo|ui|ux|figma|design|brand|poster)\b').hasMatch(lower)) {
      return GeneratedBrief(
        title: _capitalize(
          text.length > 10 ? text : 'UI/UX Product & Brand Identity Design',
        ),
        description:
            'Seeking a senior product/brand designer for: "$text".\n'
            '• Modern minimalist visual system with reusable Figma components\n'
            '• Developer-ready handoff with SVG/PNG/Figma source files\n'
            '• At least 2 revision rounds included',
        category: ServiceCategory.designCreative,
        budgetMin: 180,
        budgetMax: 490,
        urgency: urgency,
        customAnswers: const {
          'designStyle': 'Modern Minimalist',
          'sourceFiles': 'Figma + Exports',
        },
        suggestedAttachments: const ['UI Wireframe'],
      );
    }

    if (RegExp(r'\b(photo|video|shoot|wedding|event|camera|reel)\b')
        .hasMatch(lower)) {
      return GeneratedBrief(
        title: _capitalize(
          text.length > 10 ? text : 'Event / Product Photography & Highlight Reel',
        ),
        description:
            'Looking for a commercial/event photographer for: "$text".\n'
            '• High-resolution color-graded gallery within 48–72 hours\n'
            '• Professional lighting and full digital usage rights',
        category: ServiceCategory.eventsMedia,
        budgetMin: 220,
        budgetMax: 540,
        urgency: urgency,
        customAnswers: const {
          'eventType': 'Corporate Event',
          'coverageHours': 'Half Day (4 hrs)',
        },
        suggestedAttachments: const ['Site Photo'],
      );
    }

    if (RegExp(r'\b(car|auto|wash|ceramic|move|packing|truck|relocat)\b')
        .hasMatch(lower)) {
      final isMove = lower.contains('move') || lower.contains('pack');
      return GeneratedBrief(
        title: _capitalize(
          text.length > 10
              ? text
              : (isMove
                  ? 'Insured Home / Office Packing & Moving'
                  : 'Doorstep Car Detailing & Protection'),
        ),
        description:
            'Need a reliable specialist for: "$text".\n'
            '• Punctual doorstep arrival with all required equipment/materials\n'
            '• Transparent upfront pricing with zero hidden fees',
        category: ServiceCategory.autoTransport,
        budgetMin: isMove ? 180 : 95,
        budgetMax: isMove ? 420 : 250,
        urgency: urgency,
        customAnswers: {
          'vehicleOrLoad': isMove ? 'Small Apartment Move' : 'SUV / Truck',
        },
        suggestedAttachments: const ['Site Photo'],
      );
    }

    if (RegExp(r'\b(tutor|coach|mentor|tax|account|cpa|interview|finance)\b')
        .hasMatch(lower)) {
      return GeneratedBrief(
        title: _capitalize(
          text.length > 10 ? text : '1-on-1 Expert Consulting / Coaching',
        ),
        description:
            'Looking for a verified mentor/consultant for: "$text".\n'
            '• Structured action plan & session notes\n'
            '• Flexible online video call scheduling',
        category: ServiceCategory.tutoringConsulting,
        budgetMin: 60,
        budgetMax: 220,
        urgency: urgency,
        customAnswers: const {
          'sessionMode': 'Online Video Call',
          'experienceLevel': 'Intermediate',
        },
        suggestedAttachments: const ['Specification PDF'],
      );
    }

    // Default: Home & Repair (plumbing, electrical, AC, etc.)
    return GeneratedBrief(
      title: _capitalize(
        text.length > 10 ? text : 'Home Repair & Maintenance Inspection',
      ),
      description:
          'Need a licensed technician to inspect and resolve: "$text".\n'
          '• Root-cause diagnostic & clean repair with OEM spare parts\n'
          '• Post-repair safety/pressure check and workmanship warranty',
      category: ServiceCategory.homeRepair,
      budgetMin: 75,
      budgetMax: 165,
      urgency: urgency,
      customAnswers: const {
        'propertyType': 'Apartment',
        'materialsProvided': 'Provider brings parts',
      },
      suggestedAttachments: const ['Site Photo'],
    );
  }

  static String _capitalize(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return trimmed;
    final capped = trimmed[0].toUpperCase() + trimmed.substring(1);
    return capped.length > 85 ? '${capped.substring(0, 82)}...' : capped;
  }
}
