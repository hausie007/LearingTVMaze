# Development Tools

One-off Python utility scripts used during development for data migration and scene fixups.
These are **not** required for building or running the game.

`speech/` is different: it is a maintained build pipeline, not a one-off. See
[`speech/README.md`](speech/README.md), and [`speech/SETUP.md`](speech/SETUP.md)
if you are setting up a speech provider account for the first time.

| Script | Purpose |
|---|---|
| `fix_letters_desc.py` | Update letter mode descriptions in translations CSV |
| `fix_settings.py` | Fix settings scene layout |
| `fix_settings_titles.py` | Fix settings title labels in scene |
| `remove_chaser.py` | Remove chaser from settings scene |
| `update_short_desc.py` | Update short descriptions in translations CSV |
| `update_translations.py` | Bulk update/add translation entries |
| `speech/speech_pipeline.py` | Studio Voice build pipeline — generates, processes and packs the pre-recorded speech clips |
