import os
import re

directory = r'c:\Users\heman\.gemini\antigravity-ide\scratch\QuickNotes\lib'

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace Colors.black with Color(0xFF333333)
            new_content = re.sub(r'\bColors\.black\b', 'Color(0xFF333333)', content)
            
            # Replace 0xFF000000 with 0xFF333333
            new_content = new_content.replace('0xFF000000', '0xFF333333')
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f'Updated {filepath}')
