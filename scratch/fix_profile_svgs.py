import os
import glob
import re
import base64

profile_dir = r'c:\Users\heman\.gemini\antigravity-ide\scratch\QuickNotes\assets\Profile Icons'
files = glob.glob(os.path.join(profile_dir, '*.svg'))
print(f"Found {len(files)} files")

converted_count = 0
for fpath in files:
    with open(fpath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Search for embedded base64 png data
    match = re.search(r'xlink:href="(data:image/[^"]+)"', content)
    if not match:
        match = re.search(r'href="(data:image/[^"]+)"', content)

    if match and '<pattern' in content:
        b64_url = match.group(1)
        new_svg_content = f'''<svg width="1200" height="1200" viewBox="0 0 1200 1200" fill="none" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <image width="1200" height="1200" href="{b64_url}" xlink:href="{b64_url}"/>
</svg>'''
        with open(fpath, 'w', encoding='utf-8') as f:
            f.write(new_svg_content)
        converted_count += 1

print(f"Successfully converted {converted_count} SVG files!")
