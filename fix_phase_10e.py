import os
import re

files = [
    'lib/views/screens/account/account_settings_screen.dart',
    'lib/views/screens/account/account_profile_screen.dart',
    'lib/views/screens/account/delete_account_screen.dart',
    'lib/views/screens/backup_restore_screen.dart',
    'lib/views/screens/storage_and_data_screen.dart',
    'lib/views/screens/appearance_screen.dart',
    'lib/views/screens/export_import_screen.dart',
    'lib/views/screens/legal_document_screen.dart'
]

for file_path in files:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Replace body: SafeArea( with body: SafeArea(bottom: false,
    content = content.replace('body: SafeArea(', 'body: SafeArea(\n        bottom: false,')

    # 2. Replace child: Center( wrapping ConstrainedBox with Align(alignment: Alignment.topCenter,
    content = re.sub(
        r'child:\s*Center\(\s*child:\s*ConstrainedBox\(',
        'child: Align(\n                   alignment: Alignment.topCenter,\n                   child: ConstrainedBox(',
        content
    )

    # 3. Fix padding
    replacements = {
        'padding: const EdgeInsets.symmetric(\n                      horizontal: 24.0, vertical: 24.0),': 'padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 24.0 + MediaQuery.paddingOf(context).bottom),',
        'padding: const EdgeInsets.symmetric(\n                      horizontal: 32.0, vertical: 36.0),': 'padding: EdgeInsets.only(left: 32.0, right: 32.0, top: 36.0, bottom: 36.0 + MediaQuery.paddingOf(context).bottom),',
        'padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 80.0),': 'padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 80.0 + MediaQuery.paddingOf(context).bottom),',
        'padding: const EdgeInsets.only(\n                            left: 24.0, right: 24.0, top: 32.0, bottom: 100.0),': 'padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 100.0 + MediaQuery.paddingOf(context).bottom),',
        'padding: const EdgeInsets.symmetric(\n                      horizontal: 24.0, vertical: 8.0),': 'padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 8.0, bottom: 8.0 + MediaQuery.paddingOf(context).bottom),',
        'padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),': 'padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 32.0 + MediaQuery.paddingOf(context).bottom),'
    }

    for old, new_pad in replacements.items():
        if old in content:
            content = content.replace(old, new_pad)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Processed {file_path}")
