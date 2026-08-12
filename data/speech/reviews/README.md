# Review verdicts

One CSV per locale, written by `speech_pipeline.py review --import` and checked
in. This is the audit record: which take a named person approved, and when.

```
key,spec_hash,status,reviewer,date,notes
learning.char.ch,3f2a…,approved,Jana N.,2026-08-20,
learning.char.r_caron,9b71…,rejected,Jana N.,2026-08-20,read as a plain R
```

Approval is bound to `spec_hash`, so it applies to the exact take that was heard.
Change the text, the voice, the model or a setting and the clip becomes
unreviewed again rather than inheriting an approval it never earned.

Only approved records reach a shipped pack.
