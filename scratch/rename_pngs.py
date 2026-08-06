import os

profile_dir = r'c:\Users\heman\.gemini\antigravity-ide\scratch\QuickNotes\assets\Profile Icons'
for f in os.listdir(profile_dir):
    new_name = f
    for char in f:
        if ord(char) > 127:
            if 'raul' in f or 'ra' in f:
                new_name = 'raul_transparent.png'
            elif 'rudiger' in f or 'ru' in f:
                new_name = 'rudiger_transparent.png'
    if new_name != f:
        old_path = os.path.join(profile_dir, f)
        new_path = os.path.join(profile_dir, new_name)
        if os.path.exists(new_path):
            os.remove(new_path)
        os.rename(old_path, new_path)
        print("Renamed file successfully to", new_name)
