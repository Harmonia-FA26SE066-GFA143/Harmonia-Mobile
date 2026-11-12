import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_typography.dart';
import '../../../app/theme/app_colors.dart';
import '../data/staff_workspace_repository.dart';

class StaffWorkflowTitle extends StatelessWidget {
  const StaffWorkflowTitle({
    super.key,
    required this.title,
    required this.role,
    this.subtitle,
  });

  final String title, role;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x27FFFFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            role.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white,
              letterSpacing: .45,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (subtitle?.trim().isNotEmpty == true)
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onPrimaryContainer,
          ),
        ),
    ],
  );
}

class StaffWorkflowBar extends StatelessWidget {
  const StaffWorkflowBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 4,
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: child,
    ),
  );
}

class StaffEventSummary extends StatelessWidget {
  const StaffEventSummary({
    super.key,
    required this.event,
    required this.stateLabel,
    this.version,
  });

  final StaffEvent event;
  final String stateLabel;
  final int? version;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (stateLabel.isNotEmpty)
                Chip(
                  backgroundColor:
                      event.status == 'Published' && version == null
                      ? AppColors.statusSuccessSoft
                      : AppColors.statusWarningSoft,
                  label: Text(stateLabel),
                ),
              if (version != null)
                Chip(
                  label: Text('Phiên bản $version'),
                  backgroundColor: AppColors.surfaceContainerHigh,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(event.title, style: AppTypography.titleLarge),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Divider(),
          ),
          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${DateFormat('dd/MM/yyyy').format(event.date)} • ${event.time}',
                ),
              ),
            ],
          ),
          if (event.location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.church_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(event.location)),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
