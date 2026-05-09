import sys

with open('lib/features/dog_clicker/presentation/dog_clicker_screen.dart', 'r') as f:
    content = f.read()

start_marker = "  /// 空状态引导页面"
end_marker = "\n}"

if start_marker in content:
    start_idx = content.find(start_marker)
    # find the matching closing brace for the class
    end_idx = content.rfind(end_marker)
    
    with open('empty_state.dart', 'r') as f:
        new_code = f.read()
        
    if end_idx > start_idx:
        new_content = content[:start_idx] + new_code + "\n}\n"
        with open('lib/features/dog_clicker/presentation/dog_clicker_screen.dart', 'w') as f:
            f.write(new_content)
        print("Replaced!")
    else:
        print("Couldn't find end marker properly.")
else:
    print("Start marker not found.")
