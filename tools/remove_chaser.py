import re

with open("scenes/settings_menu.tscn", "r") as f:
    lines = f.readlines()

out = []
skip = False
for line in lines:
    if skip:
        # Stop skipping if we hit an empty line or a new node/resource header
        if line.strip() == "" or line.strip() == "]" or (line.strip().startswith("[") and "ChaserAnchor" not in line):
            skip = False
            out.append(line)
        continue

    if 'type="TextureRect"' in line and "ChaserAnchor" in line:
        skip = True
        continue
    
    out.append(line)

with open("scenes/settings_menu.tscn", "w") as f:
    f.writelines(out)
