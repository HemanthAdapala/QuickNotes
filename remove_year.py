import os

widgets_dir = r"lib\views\widgets"

for root, _, files in os.walk(widgets_dir):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if 'EEE, d MMMM yyyy' in content:
                content = content.replace('EEE, d MMMM yyyy', 'EEE, d MMMM')
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Removed year from {filepath}")
