import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_task_repository.dart';

export 'web_task_repository.dart' show BaseTaskRepository, WebTaskRepository;

final taskRepositoryProvider = Provider<BaseTaskRepository>((ref) {
  return WebTaskRepository.instance;
});
