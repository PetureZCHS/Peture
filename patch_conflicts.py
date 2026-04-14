import os
import re

def resolve_file(filepath, resolve_strategy='upstream'):
    if not os.path.exists(filepath): return
    with open(filepath, 'r') as f:
        content = f.read()

    # Find conflict blocks
    # <<<<<<< Updated upstream...
    # =======
    # >>>>>>> Stashed changes...
    
    # We will use regex to find the blocks and replace them.
    # Actually, let's simply search for the exact markers.
    
    pattern = re.compile(r'<<<<<<< Updated upstream.*?\n(.*?)=======\n(.*?)>>>>>>> Stashed changes.*?\n', re.DOTALL)
    
    def replacer(match):
        upstream = match.group(1)
        stashed = match.group(2)
        if resolve_strategy == 'upstream':
            return upstream
        elif resolve_strategy == 'stashed':
            return stashed
        else:
            return upstream # default

    # specialized strategy
    if 'pet_diary_compose_page.dart' in filepath:
        new_content = pattern.sub(lambda m: m.group(1), content) # upstream path is correct (../../../)
    elif 'pet_diary_result_page.dart' in filepath:
        new_content = pattern.sub(lambda m: m.group(1), content) # upstream path is correct
    elif 'pet_journal_demo_page.dart' in filepath:
        new_content = pattern.sub(lambda m: m.group(1), content) # upstream path is correct
    elif 'supabase_edge_service.dart' in filepath:
        # User wants their stashed changes? Wait. Stashed changes has "print" vs "debugPrint" and "Anon Key". 
        # Upstream has "debugPrint", anonKey constant, etc.
        # Let's see which one is more robust.
        def edge_service_replacer(match):
            up = match.group(1)
            st = match.group(2)
            if 'SupabaseConfig.anonKey' in st: # upstream has SupabaseConstants.anonKey which is better
                return up
            if 'yield DiaryDoneEvent' in up:
                return up
            if 'debugPrint' in up:
                return up
            return up
        new_content = pattern.sub(edge_service_replacer, content)
    elif 'supabase_service.dart' in filepath:
        # Upstream renamed insertDiary to insertDiary_OLD and getAllDiaries to getAllDiaries_OLD
        def supabase_service_replacer(match):
            up = match.group(1)
            return up
        new_content = pattern.sub(supabase_service_replacer, content)
    else:
        new_content = pattern.sub(lambda m: m.group(1), content)
        
    with open(filepath, 'w') as f:
        f.write(new_content)

files = [
    'lib/features/diary/presentation/pet_diary_compose_page.dart',
    'lib/features/diary/presentation/pet_diary_result_page.dart',
    'lib/features/diary/presentation/pet_diary_share_card.dart',
    'lib/features/diary/presentation/pet_journal_demo_page.dart',
    'lib/services/supabase_edge_service.dart',
    'lib/services/supabase_service.dart'
]

for file in files:
    resolve_file(file)

