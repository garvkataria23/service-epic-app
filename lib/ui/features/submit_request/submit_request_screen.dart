import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/smart_brief_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/models/service_category.dart';
import '../../../domain/models/service_item.dart';
import '../../../domain/models/service_request.dart';
import '../auth/auth_view_model.dart';
import 'submit_request_view_model.dart';

class SubmitRequestScreen extends StatefulWidget {
  const SubmitRequestScreen({
    super.key,
    this.linkedService,
    this.selectedPackage,
    this.editingRequest,
    required this.onSubmitted,
  });

  final ServiceItem? linkedService;
  final ServicePackage? selectedPackage;
  final ServiceRequest? editingRequest;
  final ValueChanged<ServiceRequest> onSubmitted;

  @override
  State<SubmitRequestScreen> createState() => _SubmitRequestScreenState();
}

class _SubmitRequestScreenState extends State<SubmitRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _locationController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smartPromptController = TextEditingController();

  late ServiceCategory _category;
  late RequestUrgency _urgency;
  DateTime? _preferredDate;
  final Map<String, String> _customAnswers = {};
  final Set<String> _attachments = {};
  String? _dateError;

  static const _attachmentOptions = [
    'Site Photo',
    'Floor Plan / Blueprint',
    'UI Wireframe',
    'Specification PDF',
    'Error Screenshot',
  ];

  bool get _isEditing => widget.editingRequest != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.editingRequest;
    final srv = widget.linkedService;
    final pkg = widget.selectedPackage;
    final user = context.read<AuthViewModel>().currentUser;

    if (edit != null) {
      _category = edit.category;
      _urgency = edit.urgency;
      _preferredDate = edit.preferredDate;
      _titleController.text = edit.title;
      _descController.text = edit.description;
      _budgetMinController.text = edit.budgetMin.toStringAsFixed(0);
      _budgetMaxController.text = edit.budgetMax.toStringAsFixed(0);
      _locationController.text = edit.location;
      _emailController.text = edit.contactEmail;
      _phoneController.text = edit.contactPhone;
      _customAnswers.addAll(edit.customAnswers);
      _attachments.addAll(edit.attachmentLabels);
    } else if (srv != null) {
      _category = srv.category;
      _urgency = RequestUrgency.normal;
      _preferredDate = DateTime.now().add(const Duration(days: 2));
      _titleController.text = pkg != null
          ? '${srv.title} (${pkg.name})'
          : srv.title;
      final base = pkg?.price ?? srv.basePrice;
      _budgetMinController.text = (base * 0.9).round().toString();
      _budgetMaxController.text = (base * 1.25).round().toString();
      _locationController.text = srv.location.contains('Remote')
          ? 'Remote'
          : (user?.defaultAddress ?? '');
      _emailController.text = user?.email ?? 'garv.client@example.com';
      _phoneController.text = user?.phone ?? '+1 555-019-2834';
    } else {
      _category = ServiceCategory.homeRepair;
      _urgency = RequestUrgency.normal;
      _preferredDate = DateTime.now().add(const Duration(days: 2));
      _locationController.text = user?.defaultAddress ?? '';
      _emailController.text = user?.email ?? 'garv.client@example.com';
      _phoneController.text = user?.phone ?? '+1 555-019-2834';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _smartPromptController.dispose();
    super.dispose();
  }

  void _applySmartBrief(String raw) {
    if (raw.trim().isEmpty) return;
    final generated = SmartBriefGenerator.generate(raw);
    setState(() {
      _category = generated.category;
      _urgency = generated.urgency;
      _titleController.text = generated.title;
      _descController.text = generated.description;
      _budgetMinController.text = generated.budgetMin.toStringAsFixed(0);
      _budgetMaxController.text = generated.budgetMax.toStringAsFixed(0);
      _customAnswers
        ..clear()
        ..addAll(generated.customAnswers);
      _attachments
        ..clear()
        ..addAll(generated.suggestedAttachments);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-structured brief for ${generated.category.label}!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _preferredDate != null && !_preferredDate!.isBefore(now)
        ? _preferredDate!
        : now.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) {
      setState(() {
        _preferredDate = picked;
        _dateError = null;
      });
    }
  }

  Future<void> _handleSubmit(SubmitRequestViewModel vm) async {
    final dateErr = Validators.preferredDate(_preferredDate);
    setState(() => _dateError = dateErr);

    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || dateErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the highlighted validation errors.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Check required dynamic category fields
    for (final spec in _category.dynamicFields) {
      if (spec.isRequired &&
          (_customAnswers[spec.key]?.trim().isEmpty ?? true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select "${spec.label}" for ${_category.label}.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final minBudget = double.parse(_budgetMinController.text.trim());
    final maxBudget = double.parse(_budgetMaxController.text.trim());

    final ServiceRequest? result;
    if (_isEditing) {
      result = await vm.updateExisting(
        widget.editingRequest!,
        title: _titleController.text,
        category: _category,
        description: _descController.text,
        budgetMin: minBudget,
        budgetMax: maxBudget,
        urgency: _urgency,
        preferredDate: _preferredDate!,
        location: _locationController.text,
        contactEmail: _emailController.text,
        contactPhone: _phoneController.text,
        customAnswers: Map<String, String>.from(_customAnswers),
        attachmentLabels: _attachments.toList(),
      );
    } else {
      result = await vm.submitNew(
        linkedService: widget.linkedService,
        title: _titleController.text,
        category: _category,
        description: _descController.text,
        budgetMin: minBudget,
        budgetMax: maxBudget,
        urgency: _urgency,
        preferredDate: _preferredDate!,
        location: _locationController.text,
        contactEmail: _emailController.text,
        contactPhone: _phoneController.text,
        customAnswers: Map<String, String>.from(_customAnswers),
        attachmentLabels: _attachments.toList(),
      );
    }

    if (result != null && mounted) {
      widget.onSubmitted(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SubmitRequestViewModel>();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Request' : 'Submit Requirement'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            if (!_isEditing && widget.linkedService == null) ...[
              Card(
                color: colors.primaryContainer.withValues(alpha: 0.28),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Smart Brief Auto-Structurer',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _smartPromptController,
                              decoration: const InputDecoration(
                                hintText: 'Describe in 1 line (e.g. pipe leak urgently)',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () =>
                                _applySmartBrief(_smartPromptController.text),
                            child: const Text('Fill'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          'Kitchen pipe leak urgently',
                          'Flutter app with login',
                          'Deep clean 3BHK flat',
                        ]
                            .map(
                              (ex) => ActionChip(
                                label: Text(ex, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  _smartPromptController.text = ex;
                                  _applySmartBrief(ex);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (widget.linkedService != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(widget.linkedService!.category.icon,
                        color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Requesting quotes for:',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            widget.linkedService!.title,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (vm.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        vm.errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: vm.clearError,
                    ),
                  ],
                ),
              ),
            ],

            Text(
              '1. Service Category',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ServiceCategory.values.map((cat) {
                final selected = cat == _category;
                return ChoiceChip(
                  avatar: Icon(
                    cat.icon,
                    size: 16,
                    color: selected ? colors.onPrimaryContainer : cat.color,
                  ),
                  label: Text(cat.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _category = cat;
                      _customAnswers.clear();
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            Text(
              '2. Requirement Details',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _titleController,
              validator: Validators.title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Request Title *',
                hintText: 'e.g., Fix leaking kitchen pipe or Build Flutter MVP',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descController,
              validator: Validators.description,
              maxLines: 4,
              maxLength: 1200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Detailed Scope & Requirements *',
                hintText:
                    'Describe what needs to be done, key deliverables, constraints, or special instructions (min 20 chars)...',
                alignLabelWithHint: true,
              ),
            ),

            // Dynamic Category-Specific Fields
            if (_category.dynamicFields.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '${_category.label} Specifics',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ..._category.dynamicFields.map((spec) {
                final selectedVal = _customAnswers[spec.key];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${spec.label}${spec.isRequired ? ' *' : ''}',
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: spec.options
                            .map(
                              (opt) => ChoiceChip(
                                label: Text(opt, style: const TextStyle(fontSize: 12)),
                                selected: selectedVal == opt,
                                onSelected: (_) => setState(
                                  () => _customAnswers[spec.key] = opt,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 8),
            Text(
              'Attach Reference Photos / Docs (Optional)',
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _attachmentOptions
                  .map(
                    (label) => FilterChip(
                      avatar: Icon(
                        _attachments.contains(label)
                            ? Icons.attach_file_rounded
                            : Icons.add_photo_alternate_outlined,
                        size: 15,
                      ),
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                      selected: _attachments.contains(label),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _attachments.add(label);
                        } else {
                          _attachments.remove(label);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              '3. Budget & Timeline',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _budgetMinController,
                    keyboardType: TextInputType.number,
                    validator: (v) => Validators.budgetAmount(
                      v,
                      label: 'Min budget',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Min Budget (\$) *',
                      prefixText: '\$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _budgetMaxController,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        Validators.budgetAmount(v, label: 'Max budget') ??
                        Validators.budgetRange(
                          _budgetMinController.text,
                          v,
                        ),
                    decoration: const InputDecoration(
                      labelText: 'Max Budget (\$) *',
                      prefixText: '\$ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<RequestUrgency>(
              initialValue: _urgency,
              decoration: const InputDecoration(
                labelText: 'Urgency Level',
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              items: RequestUrgency.values
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(u.label),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _urgency = val);
              },
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Preferred Service Date *',
                  prefixIcon: const Icon(Icons.calendar_today_rounded),
                  errorText: _dateError,
                ),
                child: Text(
                  _preferredDate != null
                      ? DateFormat.yMMMEd().format(_preferredDate!)
                      : 'Select date',
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              '4. Location & Contact',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _locationController,
              validator: Validators.location,
              decoration: const InputDecoration(
                labelText: 'Service Location / Remote *',
                hintText: 'Street address, city, or "Remote"',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Contact Email *',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              validator: Validators.phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Contact Phone *',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: vm.isSubmitting ? null : () => _handleSubmit(vm),
                icon: vm.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_isEditing ? Icons.save_rounded : Icons.send_rounded),
                label: Text(
                  vm.isSubmitting
                      ? 'Submitting...'
                      : _isEditing
                          ? 'Save Changes'
                          : 'Submit Requirement & Get Quotes',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
