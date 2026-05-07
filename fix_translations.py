import os

with open('data/translations.csv', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    line = line.strip()
    if line.startswith('mp_kicked_by_host,'):
        parts = line.split(',')
        # It currently has "mp_kicked_by_host" and "You were removed by the game host"
        # we need 22 columns total. 2 columns are there.
        # "You were removed by the game host" in Czech could be "Byl jsi odebrán hostitelem hry"
        # we can put that in for CS.
        new_line = 'mp_kicked_by_host,"You were removed by the game host","Byl(a) jste odebrán(a) ze hry"' + (',' * 19)
        new_lines.append(new_line + '\n')
    else:
        new_lines.append(line + '\n')

with open('data/translations.csv', 'w') as f:
    f.writelines(new_lines)
