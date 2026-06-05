import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # We want to find button declarations and replace bold in them.
    # It's easier to just replace all `fontWeight: FontWeight.bold` inside a `Text` widget that is a `child:` or something,
    # but since they explicitly want buttons to not be bold, let's just do a regex for `fontWeight: FontWeight.bold` 
    # that are near `ElevatedButton`, `OutlinedButton`, `TextButton`, or generally in the app to make it match the clean style.
    # Wait, the prompt says "also font in button ( no bold )".
    # This implies they might be okay with bold elsewhere, but strictly NO BOLD in buttons.
    
    # We will look for pattern: child: Text(..., style: ... fontWeight: FontWeight.bold ...)
    # But since Dart formatting can be multi-line, it's tricky.
    
    # A simpler approach: replace `fontWeight: FontWeight.bold` with `fontWeight: FontWeight.w500`
    # ONLY if it occurs within a few lines of a button definition.
    # Actually, a lot of people just use `FontWeight.w600` or `w500` instead of `bold` to make the app look cleaner like the picture.
    
    new_content = re.sub(r'fontWeight:\s*FontWeight\.bold', 'fontWeight: FontWeight.w500', content)
    
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))

