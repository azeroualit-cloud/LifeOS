from pathlib import Path
p = Path(".github/workflows/lifeos-candidate91.yml")
s = open(p, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in s else "\n"
a = "on:" + nl + "  workflow_dispatch:" + nl
b = "on:" + nl + "  workflow_dispatch:" + nl + "  push:" + nl + "    branches: [codex/revision77]" + nl + "    paths: [docs/trigger-candidate91.txt]" + nl
if "docs/trigger-candidate91.txt" in s:
    print("gia abilitato")
else:
    assert s.count(a) == 1
    s = s.replace(a, b)
    o = "if: github.event_name == 'workflow_dispatch' && github.repository"
    assert s.count(o) == 1
    s = s.replace(o, "if: (github.event_name == 'workflow_dispatch' || github.event_name == 'push') && github.repository")
    open(p, "w", encoding="utf-8", newline="").write(s)
    print("abilitato innesco da push")
