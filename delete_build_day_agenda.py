import sys

# Read the file
with open('lib/ui/screens/planner_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Delete _buildDayAgendaView method (lines 1356-1484, 0-indexed: 1355-1484)
new_lines = lines[:1355] + lines[1485:]

# Write back
with open('lib/ui/screens/planner_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"Deleted {len(lines) - len(new_lines)} lines")
