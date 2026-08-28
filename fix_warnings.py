import os
import re

def remove_line_in_file(filepath, line_number):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # line_number is 1-indexed
        if 0 < line_number <= len(lines):
            del lines[line_number - 1]
            
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(lines)
    except Exception as e:
        print(f"Error processing {filepath}: {e}")

def fix_backup_restore_controller():
    # line 6, 9 unused import
    # line 315 dead null aware
    filepath = 'lib/controllers/backup_restore_controller.dart'
    remove_line_in_file(filepath, 9) # remove from bottom to top
    remove_line_in_file(filepath, 6)
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    # "The left operand can't be null, so the right operand is never executed. (dead_null_aware_expression at lib/controllers/backup_restore_controller.dart:315)"
    # I should let it be or just replace `??` if I can find it. But line numbers change if I delete lines above!
    # Let's use regex instead of absolute line numbers where possible, or just ignore line 315 for now.

def fix_imports():
    removals = [
        ('lib/controllers/backup_restore_controller.dart', "import '../services/backup/backup_validation_result.dart';"),
        ('lib/controllers/backup_restore_controller.dart', "import '../services/backup/backup_manifest.dart';"),
        ('lib/core/animations/search_route.dart', "import 'package:flutter/material.dart';"),
        ('lib/core/layout/layout_engine.dart', "import 'package:flutter/material.dart';"),
        ('lib/main.dart', "import 'package:device_preview/device_preview.dart';"),
        ('lib/models/note_summary.dart', "import 'dart:convert';"),
        ('lib/providers/notes_provider.dart', "import '../services/database_service.dart';"),
        ('lib/repositories/user_identity_repository.dart', "import '../services/session_manager.dart';"),
        ('lib/services/android_reminder_scheduler.dart', "import 'dart:convert';"),
        ('lib/services/android_reminder_scheduler.dart', "import 'package:permission_handler/permission_handler.dart';"),
        ('lib/services/backup/backup_serializer.dart', "import 'dart:convert';"),
        ('lib/services/backup/backup_validator.dart', "import 'package:flutter/foundation.dart';"),
        ('lib/services/backup/google_drive_backup_service.dart', "import 'package:path/path.dart';"),
        ('lib/services/backup/restore_engine.dart', "import '../../models/note.dart';"),
        ('lib/services/backup/restore_engine.dart', "import '../../models/task_item.dart';"),
        ('lib/services/backup/restore_engine.dart', "import '../../repositories/folders_repository.dart';"),
        ('lib/services/backup/restore_engine.dart', "import '../../repositories/notes_repository.dart';"),
        ('lib/services/backup/restore_engine.dart', "import '../../repositories/tasks_repository.dart';"),
        ('lib/services/backup/restore_engine.dart', "import '../../repositories/user_identity_repository.dart';"),
        ('lib/services/backup/restore_engine.dart', "import 'backup_manifest.dart';"),
        ('lib/services/backup/restore_engine.dart', "import 'zip_decoder.dart';"),
        ('lib/services/database_service.dart', "import '../models/user.dart';"),
        ('lib/services/database_service.dart', "import '../models/user_identity.dart';"),
        ('lib/services/export_service.dart', "import 'dart:convert';"),
        ('lib/services/notification_action_handler.dart', "import 'reminder_scheduler.dart';"),
        ('lib/views/screens/account/account_settings_screen.dart', "import '../../widgets/tactile_button.dart';"),
        ('lib/views/screens/account/account_settings_screen.dart', "import '../../widgets/app_bottom_navigation_bar.dart';"),
        ('lib/views/screens/account/backup_and_sync_screen.dart', "import '../../widgets/tactile_button.dart';"),
        ('lib/views/screens/appearance_screen.dart', "import 'package:google_fonts/google_fonts.dart';"),
        ('lib/views/screens/appearance_screen.dart', "import '../widgets/tactile_button.dart';"),
    ]
    
    for filepath, import_statement in removals:
        if os.path.exists(filepath):
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            content = content.replace(import_statement + '\n', '')
            content = content.replace(import_statement, '')
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)

def fix_other_warnings():
    # lib/main.dart: The name kReleaseMode is shown, but isn't used.
    filepath = 'lib/main.dart'
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        content = content.replace("show kReleaseMode, kIsWeb;", "show kIsWeb;")
        content = content.replace("show kIsWeb, kReleaseMode;", "show kIsWeb;")
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            
    # lib/services/backup/backup_engine.dart: unused field '_identityRepo'
    filepath = 'lib/services/backup/backup_engine.dart'
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        content = re.sub(r'final UserIdentityRepository _identityRepo;\s*', '', content)
        content = re.sub(r'this._identityRepo,\s*', '', content)
        # unused local variable sessionType
        content = re.sub(r'final sessionType = [^;]+;\s*', '', content)
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
            
    # lib/services/database_service.dart: unused catch stack
    filepath = 'lib/services/database_service.dart'
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        content = content.replace("catch (e, stackTrace) {", "catch (e) {")
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)

fix_imports()
fix_other_warnings()
