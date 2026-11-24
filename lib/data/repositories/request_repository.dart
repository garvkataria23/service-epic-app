import 'package:uuid/uuid.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/models/provider_response.dart';
import '../../domain/models/service_request.dart';
import '../services/service_api_client.dart';

class RequestRepository {
  RequestRepository({required ServiceApiClient apiClient})
      : _apiClient = apiClient;

  final ServiceApiClient _apiClient;
  final _uuid = const Uuid();

  Future<Result<List<ServiceRequest>>> getRequests() async {
    try {
      final requests = await _apiClient.fetchRequests();
      return Success(requests);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Failed to fetch requests: $e', e));
    }
  }

  Future<Result<Map<String, List<ProviderResponse>>>> getAllResponsesGrouped() async {
    try {
      final responses = await _apiClient.fetchAllResponses();
      final grouped = <String, List<ProviderResponse>>{};
      for (final r in responses) {
        grouped.putIfAbsent(r.requestId, () => []).add(r);
      }
      return Success(grouped);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Failed to fetch quotes: $e', e));
    }
  }

  Future<Result<List<ProviderResponse>>> getResponsesForRequest(
    String requestId,
  ) async {
    try {
      final list = await _apiClient.fetchResponsesForRequest(requestId);
      return Success(list);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Failed to load provider responses: $e', e));
    }
  }

  Future<Result<ServiceRequest>> submitRequest(ServiceRequest draft) async {
    try {
      final created = await _apiClient.createRequest(draft);
      return Success(created);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Failed to submit request: $e', e));
    }
  }

  Future<Result<ServiceRequest>> updateRequest(ServiceRequest updated) async {
    try {
      final saved = await _apiClient.updateRequest(updated);
      return Success(saved);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Failed to update request: $e', e));
    }
  }

  Future<Result<ServiceRequest>> transitionRequestStatus(
    ServiceRequest request,
    RequestStatus newStatus, {
    required String eventTitle,
    required String eventSubtitle,
  }) async {
    final now = DateTime.now();
    final updated = request.copyWith(
      status: newStatus,
      updatedAt: now,
      timeline: [
        ...request.timeline,
        TimelineEvent(
          title: eventTitle,
          subtitle: eventSubtitle,
          timestamp: now,
        ),
      ],
    );
    return updateRequest(updated);
  }

  Future<Result<ProviderResponse>> requestFreshQuote(
    ServiceRequest request,
  ) async {
    try {
      final quote = await _apiClient.requestFreshQuote(request);
      return Success(quote);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Failed to request new quote: $e', e));
    }
  }

  Future<Result<ProviderResponse>> acceptQuote(
    ServiceRequest request,
    ProviderResponse quote,
    List<ProviderResponse> siblingQuotes,
  ) async {
    try {
      final accepted = await _apiClient.updateProviderResponse(
        quote.copyWith(status: QuoteStatus.accepted),
      );
      // Automatically decline other pending/negotiating quotes for clarity
      for (final other in siblingQuotes) {
        if (other.id != quote.id &&
            (other.status == QuoteStatus.pending ||
                other.status == QuoteStatus.negotiating)) {
          await _apiClient.updateProviderResponse(
            other.copyWith(status: QuoteStatus.declined),
          );
        }
      }
      await transitionRequestStatus(
        request,
        RequestStatus.inProgress,
        eventTitle: 'Quote Accepted',
        eventSubtitle:
            'Awarded to ${quote.providerName} for \$${quote.quotedPrice.toStringAsFixed(0)}',
      );
      return Success(accepted);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Failed to accept quote: $e', e));
    }
  }

  Future<Result<ProviderResponse>> declineQuote(ProviderResponse quote) async {
    try {
      final updated = await _apiClient.updateProviderResponse(
        quote.copyWith(status: QuoteStatus.declined),
      );
      return Success(updated);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Failed to decline quote: $e', e));
    }
  }

  Future<Result<ProviderResponse>> sendNegotiationMessage(
    ProviderResponse quote,
    String text,
  ) async {
    try {
      final now = DateTime.now();
      final clientMsg = ResponseMessage(
        id: _uuid.v4(),
        senderIsClient: true,
        senderName: 'You',
        text: text.trim(),
        timestamp: now,
      );
      final updated = await _apiClient.updateProviderResponse(
        quote.copyWith(
          status: quote.status == QuoteStatus.pending
              ? QuoteStatus.negotiating
              : quote.status,
          messages: [...quote.messages, clientMsg],
        ),
      );
      return Success(updated);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(NetworkException('Failed to send message: $e', e));
    }
  }
}
