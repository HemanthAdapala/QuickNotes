import sys

def wrap_widget(file_path, widget_name):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    start_str = f'child: {widget_name}('
    idx = content.find(start_str)
    if idx == -1:
        start_str = f': {widget_name}('
        idx = content.find(start_str)
        if idx == -1:
            print(f'Could not find {widget_name} in {file_path}')
            return
            
    # Find the matching closing bracket for widget_name(
    open_brackets = 0
    in_string = False
    string_char = ""
    end_idx = -1
    
    start_search = idx + len(start_str) - 1 # Points to the '('
    
    for i in range(start_search, len(content)):
        c = content[i]
        
        if not in_string:
            if c == '\'' or c == '\"':
                in_string = True
                string_char = c
            elif c == '(':
                open_brackets += 1
            elif c == ')':
                open_brackets -= 1
                if open_brackets == 0:
                    end_idx = i
                    break
        else:
            if c == string_char and content[i-1] != '\\':
                in_string = False
                
    if end_idx != -1:
        prefix = content[:idx]
        wrapped_content = content[idx:end_idx+1]
        suffix = content[end_idx+1:]
        
        indent = ' ' * (len(content[:idx]) - len(content[:idx].rstrip(' \n')))
        if '\n' in indent:
            indent = indent.split('\n')[-1]
            
        if 'child: ' in start_str:
            new_content = prefix + f'child: Center(\n{indent}  child: ConstrainedBox(\n{indent}    constraints: const BoxConstraints(maxWidth: 402.0),\n{indent}    ' + wrapped_content
        else:
            new_content = prefix + f': Center(\n{indent}  child: ConstrainedBox(\n{indent}    constraints: const BoxConstraints(maxWidth: 402.0),\n{indent}    child: ' + wrapped_content[2:]
            
        new_content += f',\n{indent}  ),\n{indent})' + suffix
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f'Successfully wrapped {widget_name} in {file_path}')
    else:
        print(f'Could not find closing bracket for {widget_name} in {file_path}')

wrap_widget('lib/views/screens/account/account_settings_screen.dart', 'SingleChildScrollView')
wrap_widget('lib/views/screens/account/account_profile_screen.dart', 'SingleChildScrollView')
wrap_widget('lib/views/screens/account/delete_account_screen.dart', 'SingleChildScrollView')
wrap_widget('lib/views/screens/backup_restore_screen.dart', 'SingleChildScrollView')
wrap_widget('lib/views/screens/appearance_screen.dart', 'SingleChildScrollView')
wrap_widget('lib/views/screens/export_import_screen.dart', 'SingleChildScrollView')
wrap_widget('lib/views/screens/storage_and_data_screen.dart', 'ListView')
wrap_widget('lib/views/screens/legal_document_screen.dart', 'Markdown')
