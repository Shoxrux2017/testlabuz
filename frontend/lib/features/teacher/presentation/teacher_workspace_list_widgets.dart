import 'package:flutter/material.dart';

import '../domain/teacher_list_pagination.dart';

class TeacherWorkspaceSection extends StatelessWidget {
  const TeacherWorkspaceSection({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class TeacherListPaginationControls extends StatelessWidget {
  const TeacherListPaginationControls({
    required this.pagination,
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final TeacherListPagination pagination;
  final bool canPrevious;
  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('teacherListPagination'),
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: canPrevious ? onPrevious : null,
          child: const Text('Previous'),
        ),
        Text('Page ${pagination.page} of ${pagination.lastPage}'),
        OutlinedButton(
          onPressed: canNext ? onNext : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class TeacherListLoading extends StatelessWidget {
  const TeacherListLoading({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Semantics(
          label: label,
          liveRegion: true,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class TeacherListEmpty extends StatelessWidget {
  const TeacherListEmpty({
    required this.title,
    required this.message,
    super.key,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action case final emptyAction?) ...[
            const SizedBox(height: 16),
            emptyAction,
          ],
        ],
      ),
    );
  }
}

class TeacherEmptyPage extends StatelessWidget {
  const TeacherEmptyPage({required this.onFirstPage, super.key});

  final VoidCallback onFirstPage;

  @override
  Widget build(BuildContext context) {
    return TeacherListEmpty(
      title: 'This page is empty',
      message: 'The list changed while you were browsing.',
      action: OutlinedButton(
        onPressed: onFirstPage,
        child: const Text('Return to first page'),
      ),
    );
  }
}

class TeacherListError extends StatelessWidget {
  const TeacherListError({
    required this.title,
    required this.message,
    required this.canRetry,
    required this.isRetrying,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final bool canRetry;
  final bool isRetrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canRetry && !isRetrying ? onRetry : null,
            icon: isRetrying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(isRetrying ? 'Retrying' : 'Retry'),
          ),
        ],
      ),
    );
  }
}
