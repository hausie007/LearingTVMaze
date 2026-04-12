import re

with open("scenes/settings_menu.tscn", "r") as f:
    lines = f.readlines()

out = []
in_title_label = False
for line in lines:
    if "Title\" type=\"Label\"" in line and "CenterContainer/MainVBox/Row" in line:
        in_title_label = True
        out.append(line)
        continue
    
    if in_title_label:
        if "custom_minimum_size" in line:
            line = line.replace("Vector2(380, 0)", "Vector2(480, 0)")
        elif "horizontal_alignment" in line:
            out.append(line)
            out.append(line.replace("horizontal_alignment", "vertical_alignment").replace("2", "1"))
            out.append(line.replace("horizontal_alignment = 2", "autowrap_mode = 3"))
            in_title_label = False
            continue
    
    out.append(line)

with open("scenes/settings_menu.tscn", "w") as f:
    f.writelines(out)

