with open('lib/features/dog_clicker/presentation/dog_clicker_screen.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, line in enumerate(lines):
    if "  /// 空状态引导页面" in line and "Widget _buildEmptyState() {" in lines[i+1]:
        skip = True
        
        with open('empty_state.dart', 'r') as empty_f:
            new_lines.extend(empty_f.readlines())
        continue
        
    if skip:
        if "    }" in line and i > 2940 and i < 2950:
            skip = False
        continue
        
    new_lines.append(line)

with open('lib/features/dog_clicker/presentation/dog_clicker_screen.dart', 'w') as f:
    f.writelines(new_lines)
