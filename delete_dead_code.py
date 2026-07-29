import sys

# Read the file
with open('lib/ui/screens/planner_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Delete lines 1356-2500 (0-indexed: 1355-2499)
# This removes _buildDayAgendaView through all dead helper methods
# Line 1355 is the blank line before _buildDayAgendaView
# Line 2500 is the blank line before _buildWeekView
new_lines = lines[:1355] + lines[2500:]

# Write back
with open('lib/ui/screens/planner_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"Deleted {len(lines) - len(new_lines)} lines")
