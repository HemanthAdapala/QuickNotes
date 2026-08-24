import os
import re
from collections import Counter

directory = r'c:\Users\heman\.gemini\antigravity-ide\scratch\QuickNotes\lib'
radii = []

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            matches = re.findall(r'BorderRadius\.circular\((.*?)\)', content)
            radii.extend(matches)

counter = Counter(radii)
for radius, count in counter.most_common():
    print(f'Radius {radius}: {count} times')
