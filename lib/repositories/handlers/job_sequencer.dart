import 'dart:async';

/// Represents a job with an associated index.
class Job {
  /// The index of the job.
  final int index;

  /// The function representing the job.
  final Future<void> Function() fn;

  /// Creates a job with the specified index and function.
  Job({
    required this.index,
    required this.fn,
  });
}

/// Manages the execution of jobs based on their index.
class JobSequencer {
  final Duration delay;
  final int initialIndex;

  /// The current index of the job to be executed.
  int _currentIndex;

  JobSequencer({
    this.delay = const Duration(milliseconds: 50),
    this.initialIndex = 0,
  }) : _currentIndex = initialIndex;

  /// A map to hold jobs that are waiting to be executed.
  final Map<int, Job> _pendingJobs = {};

  bool get hasPendingJobs => _pendingJobs.isNotEmpty;

  void reset() {
    _currentIndex = initialIndex;
    _pendingJobs.clear();
  }

  /// Adds a job to the manager and attempts to execute it if possible.
  void addJob(Job job) {
    // Add the job to the pending jobs map.
    _pendingJobs[job.index] = job;

    // Attempt to execute jobs starting from the current index.
    _tryExecuteJobs();
  }

  /// Attempts to execute jobs in order starting from the current index.
  Future<void> _tryExecuteJobs() async {
    // Continue executing jobs as long as there is a job with the current index.
    while (_pendingJobs.containsKey(_currentIndex)) {
      // Retrieve and remove the job from the pending jobs map.
      final job = _pendingJobs.remove(_currentIndex);

      // Execute the job function.
      await job?.fn();

      // Increment the current index after the job is executed.
      _currentIndex++;

      // Wait for the specified delay before executing the next job.
      await Future.delayed(delay);

      // Try executing the next job in the sequence.
      _tryExecuteJobs();
    }
  }
}
