with open('lib/features/dog_clicker/presentation/dog_clicker_screen.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "Widget _buildConfirmationTip() {" in line:
        skip = True
    if skip:
        if "Widget _buildQuickActionButton" in line:
            skip = False # we might need it, or we delete that too
    if not skip:
        new_lines.append(line)

with open('lib/features/dog_clicker/presentation/dog_clicker_screen.dart', 'w') as f:
    f.writelines(new_lines)
