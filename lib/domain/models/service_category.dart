import 'package:flutter/material.dart';

class DynamicFieldSpec {
  const DynamicFieldSpec({
    required this.key,
    required this.label,
    required this.hint,
    this.options = const [],
    this.isRequired = false,
  });

  final String key;
  final String label;
  final String hint;
  final List<String> options;
  final bool isRequired;
}

enum ServiceCategory {
  homeRepair(
    id: 'home_repair',
    label: 'Home & Repair',
    icon: Icons.home_repair_service_rounded,
    color: Color(0xFFEA580C),
    dynamicFields: [
      DynamicFieldSpec(
        key: 'propertyType',
        label: 'Property Type',
        hint: 'Apartment, House, Office',
        options: ['Apartment', 'Independent House', 'Office / Commercial'],
        isRequired: true,
      ),
      DynamicFieldSpec(
        key: 'materialsProvided',
        label: 'Materials / Spare Parts',
        hint: 'Who will provide parts?',
        options: ['Provider brings parts', 'I already have parts', 'Not sure yet'],
      ),
    ],
  ),
  techSoftware(
    id: 'tech_software',
    label: 'Tech & Software',
    icon: Icons.code_rounded,
    color: Color(0xFF2563EB),
    dynamicFields: [
      DynamicFieldSpec(
        key: 'platform',
        label: 'Target Platform',
        hint: 'Mobile, Web, Backend, Full-Stack',
        options: ['Mobile (iOS/Android)', 'Web Application', 'Backend / API', 'Cross-Platform'],
        isRequired: true,
      ),
      DynamicFieldSpec(
        key: 'deliverableType',
        label: 'Expected Deliverable',
        hint: 'MVP, Bug Fix, Full Release',
        options: ['New MVP / Build', 'Feature Addition', 'Bug Fix & Optimization', 'Code Audit'],
      ),
    ],
  ),
  designCreative(
    id: 'design_creative',
    label: 'Design & Creative',
    icon: Icons.palette_rounded,
    color: Color(0xFF9333EA),
    dynamicFields: [
      DynamicFieldSpec(
        key: 'designStyle',
        label: 'Preferred Aesthetic',
        hint: 'Minimal, Bold, Corporate',
        options: ['Modern Minimalist', 'Bold & Vibrant', 'Corporate / Clean', 'Playful'],
      ),
      DynamicFieldSpec(
        key: 'sourceFiles',
        label: 'Source Files Needed',
        hint: 'Figma, SVG, PSD',
        options: ['Figma + Exports', 'Vector (SVG/AI)', 'Print-Ready PDF', 'Any Standard Format'],
        isRequired: true,
      ),
    ],
  ),
  cleaningCare(
    id: 'cleaning_care',
    label: 'Cleaning & Care',
    icon: Icons.cleaning_services_rounded,
    color: Color(0xFF0D9488),
    dynamicFields: [
      DynamicFieldSpec(
        key: 'areaSize',
        label: 'Space Size',
        hint: '1BHK, 3BHK, 2000 sq ft',
        options: ['Studio / 1 BHK', '2–3 BHK', '4+ BHK / Villa', 'Commercial Space'],
        isRequired: true,
      ),
      DynamicFieldSpec(
        key: 'ecoFriendly',
        label: 'Cleaning Supplies',
        hint: 'Eco-friendly / Standard',
        options: ['Eco-friendly / Pet-safe', 'Standard Industrial', 'Use my supplies'],
      ),
    ],
  ),
  eventsMedia(
    id: 'events_media',
    label: 'Events & Media',
    icon: Icons.camera_alt_rounded,
    color: Color(0xFFDB2777),
    dynamicFields: [
      DynamicFieldSpec(
        key: 'eventType',
        label: 'Event / Shoot Type',
        hint: 'Wedding, Corporate, Product',
        options: ['Corporate Event', 'Wedding / Family', 'Product / Brand Shoot', 'Social Media'],
        isRequired: true,
      ),
      DynamicFieldSpec(
        key: 'coverageHours',
        label: 'Coverage Duration',
        hint: '2 hours, Full Day',
        options: ['2 Hours', 'Half Day (4 hrs)', 'Full Day (8+ hrs)'],
      ),
    ],
  ),
  tutoringConsulting(
    id: 'tutoring_consulting',
    label: 'Tutoring & Consulting',
    icon: Icons.school_rounded,
    color: Color(0xFF4F46E5),
    dynamicFields: [
      DynamicFieldSpec(
        key: 'sessionMode',
        label: 'Session Mode',
        hint: 'Online or In-person',
        options: ['Online Video Call', 'In-Person', 'Hybrid'],
        isRequired: true,
      ),
      DynamicFieldSpec(
        key: 'experienceLevel',
        label: 'Current Level',
        hint: 'Beginner, Intermediate, Pro',
        options: ['Beginner', 'Intermediate', 'Advanced / Executive'],
      ),
    ],
  ),
  autoTransport(
    id: 'auto_transport',
    label: 'Auto & Transport',
    icon: Icons.directions_car_rounded,
    color: Color(0xFF0284C7),
    dynamicFields: [
      DynamicFieldSpec(
        key: 'vehicleOrLoad',
        label: 'Vehicle / Load Type',
        hint: 'Sedan, SUV, 1BHK Move',
        options: ['Sedan / Hatchback', 'SUV / Truck', 'Small Apartment Move', 'Full House Move'],
        isRequired: true,
      ),
    ],
  );

  const ServiceCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.dynamicFields,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<DynamicFieldSpec> dynamicFields;

  static ServiceCategory fromId(String id) {
    return ServiceCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => ServiceCategory.homeRepair,
    );
  }
}
