import re

with open("scenes/settings_menu.tscn", "r") as f:
    lines = f.readlines()

out = []
skip = False
for line in lines:
    if skip:
        if line.strip() == "" or line.strip() == "]" or (line.strip().startswith("[") and "PlayerAnchor" not in line):
            skip = False
            out.append(line)
        continue

    # Keep ThemePlayerAnchor, remove others like PlayerAnchor_Perf
    if 'type="TextureRect"' in line and "PlayerAnchor" in line and "ThemePlayerAnchor" not in line:
        skip = True
        continue
    
    out.append(line)

with open("scenes/settings_menu.tscn", "w") as f:
    f.writelines(out)
