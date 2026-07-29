import sys

# Read the file
with open('lib/ui/screens/planner_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find and delete the remaining unused methods
lines_to_delete = set()

# Find _buildJournalEntryItem (line 1356 based on analysis)
for i in range(len(lines)):
    if 'Widget _buildJournalEntryItem' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

# Find _journalMoodLabel
for i in range(len(lines)):
    if 'String _journalMoodLabel' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

# Find _buildPendingReminderCard
for i in range(len(lines)):
    if 'Widget _buildPendingReminderCard' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

# Find _buildTrackingRecordItem
for i in range(len(lines)):
    if 'Widget _buildTrackingRecordItem' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

# Find _buildContactReminderItem
for i in range(len(lines)):
    if 'Widget _buildContactReminderItem' in lines[i]:
        start = i
        for j in range(i + 1, len(lines)):
            if lines[j].strip() and not lines[j].startswith(' ') and lines[j].startswith('  Widget'):
                lines_to_delete.update(range(start, j))
                break
        break

print(f"Deleting {len(lines_to_delete)} lines")

# Filter out deleted lines
new_lines = [line for i, line in enumerate(lines) if i not in lines_to_delete]

# Write back
with open('lib/ui/screens/planner_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"Deleted {len(lines) - len(new_lines)} lines total")
