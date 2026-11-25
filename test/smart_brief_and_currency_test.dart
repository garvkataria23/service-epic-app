import 'package:flutter_test/flutter_test.dart';
import 'package:service_epic/core/utils/currency_formatter.dart';
import 'package:service_epic/core/utils/smart_brief_generator.dart';
import 'package:service_epic/core/utils/validators.dart';
import 'package:service_epic/domain/models/service_category.dart';
import 'package:service_epic/domain/models/service_order.dart';
import 'package:service_epic/domain/models/service_request.dart';

void main() {
  group('CurrencyController', () {
    test('defaults to INR (₹) at 84x conversion rate', () {
      final controller = CurrencyController();
      expect(controller.isInr, isTrue);
      expect(controller.currency, AppCurrency.inr);
      expect(controller.currency.symbol, '₹');
      expect(controller.convert(100), 8400);
      expect(controller.format(100), '₹8,400');
      expect(controller.formatExact(10), '₹840.00');
    });

    test('toggles live between INR (₹) and USD (\$)', () async {
      final controller = CurrencyController();
      expect(controller.isInr, isTrue);

      await controller.toggle();
      expect(controller.isInr, isFalse);
      expect(controller.currency, AppCurrency.usd);
      expect(controller.currency.symbol, '\$');
      expect(controller.format(100), '\$100');
      expect(controller.formatExact(10.5), '\$10.50');

      await controller.toggle();
      expect(controller.isInr, isTrue);
      expect(controller.format(100), '₹8,400');
    });
  });

  group('SmartBriefGenerator', () {
    test('structures a tech/app prompt with urgent detection', () {
      final brief = SmartBriefGenerator.generate(
        'Need an urgent Flutter e-commerce app with Razorpay checkout',
      );
      expect(brief.category, ServiceCategory.techSoftware);
      expect(brief.urgency, RequestUrgency.urgent);
      expect(brief.budgetMax, greaterThan(brief.budgetMin));
      expect(brief.customAnswers, isNotEmpty);
      expect(brief.suggestedAttachments, isNotEmpty);
    });

    test('structures a home repair prompt', () {
      final brief = SmartBriefGenerator.generate(
        'AC cooling issue and kitchen plumbing check',
      );
      expect(brief.category, ServiceCategory.homeRepair);
      expect(brief.urgency, RequestUrgency.normal);
      expect(brief.description, contains('AC cooling issue'));
    });

    test('has 5 progress stages on ServiceOrder', () {
      expect(ServiceOrder.progressStages.length, 5);
      expect(ServiceOrder.progressStages.first, 'Confirmed');
      expect(ServiceOrder.progressStages.last, 'Completed');
    });

    test('Validators.fullName rejects numeric-only input like 133', () {
      expect(Validators.fullName('133'), isNotNull);
      expect(Validators.fullName('Garv Sharma'), isNull);
    });
  });
}
