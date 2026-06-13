#!/usr/bin/env python3
"""Update workflow: add Podfile modification to remove CocoaPods dependency."""

# Strategy: After flutter pub get but before flutter build:
# 1. Modify .flutter-plugins-dependencies to remove ffmpeg_kit
# 2. Delete platform's Flutter/ephemeral
# 3. Run flutter build --no-pub
#    Flutter regenerates ephemeral from .flutter-plugins-dependencies
#    Since we modified the file, ffmpeg_kit shouldn't be in the new Podfile

# SAFE python3 command - no 'for' loops (expressions only, works with semicolons)
python_script = (
    'python3 -c "import json,pathlib;'
    "f=pathlib.Path('.flutter-plugins-dependencies');"
    'd=json.loads(f.read_text());'
    "p=d.get('plugins',{}).get('macos',[]);"
    "d['plugins']['macos']=[x for x in p if 'ffmpeg_kit_flutter_min_gpl' not in x.get('name','')];"
    "p=d.get('plugins',{}).get('ios',[]);"
    "d['plugins']['ios']=[x for x in p if 'ffmpeg_kit_flutter_min_gpl' not in x.get('name','')];"
    'f.write_text(json.dumps(d,indent=2))"'
)

new_remove_steps = (
    '# Remove ffmpeg_kit from .flutter-plugins-dependencies\n'
    '# then delete ephemeral so Flutter rebuilds from modified list\n'
    + python_script + '\n'
    'rm -rf macos/Flutter/ephemeral'
)

new_remove_steps_ios = (
    '# Remove ffmpeg_kit from .flutter-plugins-dependencies\n'
    '# then delete ephemeral so Flutter rebuilds from modified list\n'
    + python_script + '\n'
    'rm -rf ios/Flutter/ephemeral'
)

for fname in ['ci.yml', 'build.yml', 'release.yml']:
    fpath = '.github/workflows/' + fname
    with open(fpath, 'rb') as f:
        raw = f.read()
    enc = 'utf-16' if raw[:2] == b'\xff\xfe' else 'utf-8'
    with open(fpath, 'r', encoding=enc) as f:
        c = f.read()
    
    # Replace macOS step content (keep name and build line)
    import re
    # Find the macOS block: from name to build line
    pattern_macos_start = r'      - name: Remove discontinued ffmpeg_kit pod from macOS\n        run: \|\n'
    m = re.search(pattern_macos_start, c)
    if m:
        start = m.end()
        # Find the build line after this
        after = c[start:]
        build_line_idx = after.find('flutter build macos --release --no-pub')
        if build_line_idx >= 0:
            old_content = after[:build_line_idx]
            new_content = '          ' + '\n          '.join(new_remove_steps.split('\n')) + '\n'
            c = c[:start] + new_content + after[build_line_idx:]
    
    # Replace iOS step content
    pattern_ios_start = r'      - name: Remove discontinued ffmpeg_kit pod from iOS\n        run: \|\n'
    m = re.search(pattern_ios_start, c)
    if m:
        start = m.end()
        after = c[start:]
        build_line_idx = after.find('flutter build ios')
        if build_line_idx >= 0:
            old_content = after[:build_line_idx]
            new_content = '          ' + '\n          '.join(new_remove_steps_ios.split('\n')) + '\n'
            c = c[:start] + new_content + after[build_line_idx:]
    
    with open(fpath, 'w', encoding=enc) as f:
        f.write(c)
    print(f'{fname}: updated')

print('Done')
