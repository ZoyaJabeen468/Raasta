import json
import re
from pathlib import Path

p = Path(r"c:\Users\SHAHZAIB LAPTOPS\OneDrive\Documents\Downloads\RAASTA_YOLOv8_M2_M5.ipynb")
nb = json.loads(p.read_text(encoding="utf-8"))
out = Path(r"E:\Android\projects\raasta_app\ml\notebook_errors.txt")
lines = [f"cells: {len(nb.get('cells', []))}"]

for i, c in enumerate(nb["cells"]):
    outs = c.get("outputs") or []
    has_error = any(o.get("output_type") == "error" for o in outs)
    stream_interesting = False
    bits = []
    for o in outs:
        if o.get("output_type") == "error":
            bits.append(
                "ERROR: "
                + str(o.get("ename", ""))
                + ": "
                + str(o.get("evalue", ""))[:1200]
            )
            for line in (o.get("traceback") or [])[-15:]:
                bits.append(re.sub(r"\x1b\[[0-9;]*m", "", line))
        if o.get("output_type") == "stream":
            text = "".join(o.get("text") or [])
            keys = [
                "Error",
                "Traceback",
                "Assertion",
                "Too few",
                "FAILED",
                "warn",
                "skip",
                "Images:",
                "Downloaded",
                "Boxes:",
                "mAP",
                "Best:",
                "loading Roboflow",
            ]
            if any(k in text for k in keys):
                stream_interesting = True
                bits.append(text[-3000:])
    if has_error or stream_interesting:
        src = "".join(c.get("source") or [])[:220].replace("\n", " | ")
        lines.append(f"\n==== CELL {i} exec={c.get('execution_count')} ====")
        lines.append("SRC: " + src)
        lines.append("---OUTPUT---")
        lines.extend(bits)

out.write_text("\n".join(lines), encoding="utf-8")
print("wrote", out)
print("error lines:", sum(1 for l in lines if l.startswith("ERROR:")))
