import os

files = [
    r"test\controllers\backup_restore_controller_test.dart",
    r"test\services\backup_engine_test.dart",
    r"test\services\restore_engine_test.dart",
    r"test\views\backup_restore_screen_test.dart"
]

for file in files:
    if os.path.exists(file):
        with open(file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
        with open(file, 'w', encoding='utf-8') as f:
            for line in lines:
                if 'identityRepo: identityRepo,' not in line:
                    f.write(line)
