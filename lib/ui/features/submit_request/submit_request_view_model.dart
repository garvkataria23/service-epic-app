import 'package:flutter/foundation.dart';

import '../../../data/repositories/request_repository.dart';
import '../../../domain/models/service_category.dart';
import '../../../domain/models/service_item.dart';
import '../../../domain/models/service_request.dart';

class SubmitRequestViewModel extends ChangeNotifier {
  SubmitRequestViewModel({required RequestRepository repository})
      : _repository = repository;

  final RequestRepository _repository;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<ServiceRequest?> submitNew({
    ServiceItem? linkedService,
    required String title,
    required ServiceCategory category,
    required String description,
    required double budgetMin,
    required double budgetMax,
    required RequestUrgency urgency,
    required DateTime preferredDate,
    required String location,
    required String contactEmail,
    required String contactPhone,
    required Map<String, String> customAnswers,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    final now = DateTime.now();
    final draft = ServiceRequest(
      id: '',
      serviceId: linkedService?.id,
      serviceTitle: linkedService?.title,
      title: title.trim(),
      category: category,
      description: description.trim(),
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      urgency: urgency,
      preferredDate: preferredDate,
      location: location.trim(),
      contactEmail: contactEmail.trim(),
      contactPhone: contactPhone.trim(),
      customAnswers: customAnswers,
      status: RequestStatus.open,
      createdAt: now,
      updatedAt: now,
    );

    final result = await _repository.submitRequest(draft);
    _isSubmitting = false;

    final created = result.when(
      success: (req) => req,
      failure: (err) {
        _errorMessage = err.message;
        return null;
      },
    );
    notifyListeners();
    return created;
  }

  Future<ServiceRequest?> updateExisting(
    ServiceRequest existing, {
    required String title,
    required ServiceCategory category,
    required String description,
    required double budgetMin,
    required double budgetMax,
    required RequestUrgency urgency,
    required DateTime preferredDate,
    required String location,
    required String contactEmail,
    required String contactPhone,
    required Map<String, String> customAnswers,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    final now = DateTime.now();
    final updated = existing.copyWith(
      title: title.trim(),
      category: category,
      description: description.trim(),
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      urgency: urgency,
      preferredDate: preferredDate,
      location: location.trim(),
      contactEmail: contactEmail.trim(),
      contactPhone: contactPhone.trim(),
      customAnswers: customAnswers,
      updatedAt: now,
      timeline: [
        ...existing.timeline,
        TimelineEvent(
          title: 'Requirements Updated',
          subtitle: 'Client updated scope, budget, or schedule',
          timestamp: now,
        ),
      ],
    );

    final result = await _repository.updateRequest(updated);
    _isSubmitting = false;

    final saved = result.when(
      success: (req) => req,
      failure: (err) {
        _errorMessage = err.message;
        return null;
      },
    );
    notifyListeners();
    return saved;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
