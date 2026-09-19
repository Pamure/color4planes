import os
import re

def scale_font(match):
    size = int(match.group(1))
    if size <= 11:
        new_size = size + 4
    elif size <= 14:
        new_size = size + 2
    else:
        new_size = size
    return f'fontSize: {new_size}'

for root, _, files in os.walk('.'):
    for f in files:
        if f.endswith('.dart'):
            path = os.path.join(root, f)
            with open(path, 'r', encoding='utf-8') as file:
                content = file.read()
            
            new_content = re.sub(r'fontSize:\s*(\d+)', scale_font, content)
            
            if new_content != content:
                with open(path, 'w', encoding='utf-8') as file:
                    file.write(new_content)
                print(f'Updated {path}')
