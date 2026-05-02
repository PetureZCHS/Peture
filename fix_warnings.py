with open('lib/features/dog_clicker/presentation/dog_clicker_screen.dart', 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if "if (soundPath == null) {" in line:
        skip = True
    if skip:
        if "return;" in line:
            pass # still skip
        elif "}" in line:
            skip = False
        continue
    new_lines.append(line)

with open('lib/features/dog_clicker/presentation/dog_clicker_screen.dart', 'w') as f:
    f.writelines(new_lines)
