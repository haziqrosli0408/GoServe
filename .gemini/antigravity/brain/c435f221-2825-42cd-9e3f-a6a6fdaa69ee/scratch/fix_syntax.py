import sys

with open('lib/screens/services/home_screen.dart', 'r') as f:
    lines = f.readlines()

# Index 500 is line 501
if len(lines) >= 502:
    lines[500] = '    ),\n'
    lines[501] = '  );\n'
    lines.insert(502, '}\n')

with open('lib/screens/services/home_screen.dart', 'w') as f:
    f.writelines(lines)
