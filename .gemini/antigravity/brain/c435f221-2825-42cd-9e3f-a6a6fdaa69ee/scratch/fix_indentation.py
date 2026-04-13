with open('lib/screens/services/home_screen.dart', 'r') as f:
    lines = f.readlines()

# Line 501 is index 500
lines[500] = '      ),\n' # Closest block
lines[501] = '    ),\n'   # Close Column
lines[502] = '  );\n'     # Close Padding
lines[503] = '}\n\n'     # Close Method (0 ind? No, should be 2)

# Wait, I'll just fix the indentation manually for 500-504
lines[500] = '        ),\n'
lines[501] = '      ],\n'
lines[502] = '    ),\n'
lines[503] = '  );\n'
lines[504] = '}\n'

with open('lib/screens/services/home_screen.dart', 'w') as f:
    f.writelines(lines)
