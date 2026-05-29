import os

home_screen_path = r'c:\Flutter\Projects\madbunky_pro\lib\screens\home_screen.dart'
new_code_path = r'c:\Flutter\Projects\madbunky_pro\new_subject_card.dart'

print(f"Reading {home_screen_path}")
with open(home_screen_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Line numbers are 1-based
start_line = 1299
end_line = 1875

# 0-based indices
start_idx = start_line - 1
end_idx = end_line - 1

print(f"Replacing lines {start_line} to {end_line}")
print(f"Original content length: {len(lines)}")

# Slice
# Keep before start: 0 .. start_idx-1
# lines[:start_idx] includes 0 to start_idx-1
before = lines[:start_idx]

# Keep after end: end_idx+1 .. end
# lines[end_idx+1:] includes end_idx+1 to end
# Index 1875 is Line 1876.
after = lines[end_idx+1:]

print(f"Kept {len(before)} lines before and {len(after)} lines after")

with open(new_code_path, 'r', encoding='utf-8') as f:
    new_code = f.readlines()

# Ensure newline at end of new code if missing
if new_code and not new_code[-1].endswith('\n'):
    new_code[-1] = new_code[-1] + '\n'

# Combine
final_lines = before + new_code + after

print(f"New content length: {len(final_lines)}")

with open(home_screen_path, 'w', encoding='utf-8') as f:
    f.writelines(final_lines)

print("Updated successfully")
