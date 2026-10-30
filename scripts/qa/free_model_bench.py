#!/usr/bin/env python3
# Token Kuzatuv QA: ask_free_model aniqligi — fixtures/ dagi haqiqiy loglar bo'yicha savollar, javoblar kutilgan qiymatlar bilan solishtiriladi.
#   python3 -I scripts/qa/free_model_bench.py [ilova binari]
# Har chaqiruv free-model-calls.jsonl ga yoziladi — skript oxirida o'z yozuvlarini olib tashlaydi («Tejash» kartasi buzilmasin).
import json, os, subprocess, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
FX = os.path.join(HERE, "fixtures")
BIN = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Applications/Token Kuzatuv.app/Contents/MacOS/TokenKuzat")
LOG = os.path.expanduser("~/Library/Application Support/TokenKuzat/free-model-calls.jsonl")
# (id, fayl, savol, javobda bo'lishi shart bo'lgan qiymatlar)
CASES = [
    ("compile-errors", "compile.log", "Kompilyator nechta xato bergan? Har birining qator:ustun raqami va sababi.", ["3", "5:14", "3:64", "4:44"]),
    ("files-commits", "gitlog.log", "Qaysi commitlar Sources/TokenKuzat/MCPServer.swift faylini o'zgartirgan? Har birining qisqa hash va sarlavhasini sanab ber.",
     ["aa3cb35", "14c548d", "82d73b8", "a9a348a", "d11f058", "5f15829", "fb0aeae", "68b469f", "fcae6c4", "4d0b06d", "2c0f107"]),
    ("pin-version", "changelog.md", "Oynani boshqa ilovalar ustida ushlab turadigan «pin» tugmasi qaysi versiyada qo'shilgan?", ["6.64.0"]),
    ("limit-version", "changelog.md", "ask_free_model uchun fayl hajmi chegarasi qancha va u qaysi versiyada paydo bo'lgan?", ["400 KB", "6.65.0"]),
    ("section-summary", "changelog.md", "6.52.0 versiyada nimalar qo'shilgan? Qisqa ro'yxat.", ["ask_free_model", "FreeLLMAPI"]),
]

def main():
    before = open(LOG).read() if os.path.exists(LOG) else None
    p = subprocess.Popen([BIN, "--mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    def send(m): p.stdin.write(json.dumps(m) + "\n"); p.stdin.flush()
    def recv(i):
        while True:
            line = p.stdout.readline()
            if not line: return None
            try: d = json.loads(line)
            except ValueError: continue
            if d.get("id") == i: return d
    send({"jsonrpc": "2.0", "id": 0, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "qa", "version": "1"}}}); recv(0)
    send({"jsonrpc": "2.0", "method": "notifications/initialized"})
    results = []
    for n, (cid, f, q, expect) in enumerate(CASES, 1):
        t = time.time()
        send({"jsonrpc": "2.0", "id": n, "method": "tools/call", "params": {"name": "ask_free_model", "arguments": {"prompt": q + " Javobni o'zbekcha yoz.", "files": [os.path.join(FX, f)]}}})
        d = recv(n) or {}
        r = d.get("result", {})
        text = "".join(c.get("text", "") for c in r.get("content", []))
        answer = text.split("[free model:")[0]
        missing = [e for e in expect if e not in answer]
        results.append({"case": cid, "ok": not r.get("isError") and not missing, "missing": missing,
                        "flagged": "NOT in the files" in text, "error": bool(r.get("isError")), "sec": round(time.time() - t, 1),
                        "meta": text.split("[free model:")[-1][:200] if "[free model:" in text else text[:200]})
    p.terminate()
    # Sinov yozuvlari «Tejash» kartasiga tushmasin
    if before is None:
        if os.path.exists(LOG): os.remove(LOG)
    else:
        open(LOG, "w").write(before)
    ok = sum(r["ok"] for r in results)
    print(json.dumps({"passed": ok, "total": len(results), "results": results}, ensure_ascii=False, indent=1))

if __name__ == "__main__":
    main()
