import 'package:finanalyzer/backup/cubit/backup_cubit.dart';
import 'package:finanalyzer/backup/cubit/cloud_backup_cubit.dart';
import 'package:finanalyzer/backup/model/backup_repository.dart';
import 'package:finanalyzer/backup/services/archive_service.dart';
import 'package:finanalyzer/backup/services/backup_service.dart';
import 'package:finanalyzer/backup/services/encryption_service.dart';
import 'package:finanalyzer/backup/services/local_storage_service.dart';
import 'package:finanalyzer/core/module.dart';
import 'package:finanalyzer/core/secure_storage.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class BackupModule implements Module {
  late final BackupService backupService;
  late final EncryptionService encryptionService;
  late final ArchiveService archiveService;
  late final LocalStorageService localStorageService;
  late final BackupRepository backupRepository;

  @override
  late final List<SingleChildWidget> providers;

  BackupModule(Logger log) {
    // Backup services
    archiveService = ArchiveService(log);
    localStorageService = LocalStorageService(log);
    encryptionService = EncryptionService(log);
    backupRepository = BackupRepository(log, localStorageService);
    backupService = BackupService(
      log,
      dbHelper: DatabaseHelper(),
      backupRepository: backupRepository,
      archiveService: archiveService,
      localStorageService: localStorageService,
      encryptionService: encryptionService,
    );

    providers = [
      Provider.value(value: this),
      Provider.value(value: backupService),
      BlocProvider(create: (_) => BackupCubit(backupService, log)),
      BlocProvider(
        create: (_) => CloudBackupCubit(backupService, secureStorage(), log),
      ),
    ];
  }

  @override
  void dispose() {}
}
