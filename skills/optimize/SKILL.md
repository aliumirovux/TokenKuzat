---
name: optimize
description: Shu loyihada token sarfini kamaytiradi — Token Kuzatuv hisobotidan isrof sabablarini oladi va tuzatishlarni foydalanuvchi tasdig'i bilan qo'llaydi (model va sifat o'zgarmaydi)
disable-model-invocation: true
argument-hint: "[loyiha] [today|week]"
---

# Token sarfini kamaytirish

Foydalanuvchiga uning tilida, qisqa va aniq javob bering. Model va ish sifati o'zgarmasligi kerak — faqat behuda ketayotgan tokenlar kamaytiriladi.

## 1. Hisobotni oling

`tokenkuzat` MCP serveridagi `savings_report` asbobini chaqiring:
- `project` — `$ARGUMENTS` da loyiha nomi bo'lsa o'sha, aks holda joriy papka yo'li;
- `period` — `$ARGUMENTS` da `today` bo'lsa `today`, aks holda `week`.

Asbob topilmasa: Token Kuzatuv ilovasi o'rnatilmagan yoki MCP ulanmagan — `/tokenkuzat:install`, keyin `/mcp` da `tokenkuzat` ni qayta ulashni ayting va to'xtang.

## 2. Qisqa xulosa

3–6 qatorda: loyiha qancha sarflagan (barcha loyihalar ichida ulushi), taxminiy isrof va eng katta 2–3 sabab — har biri uchun qancha token va bir gapda nima uchun.

## 3. Tuzatishni taklif qiling

Hisobotdagi `task` matnidagi ko'rsatmalarga amal qiling. Avval `CLAUDE.md`, `.claude/settings.json`, `.mcp.json` va `~/.claude/settings.json` ni o'qing. Har `fix` turi uchun:

- `claude_rules` — `CLAUDE.md` ga qisqa «Token tejash» bo'limi (faqat topilgan sabablarga oid 3–6 qoida). Bo'lim allaqachon bo'lsa — yangilang, takrorlamang.
- `connectors` — loyiha `.mcp.json` dagi ishlatilmaydigan serverlar uchun `.claude/settings.json` da `disabledMcpjsonServers`. Foydalanuvchi darajasidagi MCP server va pluginlarni o'zingiz o'chirmang — qaysilarini `/mcp` yoki `/plugin` orqali o'chirish mumkinligini ro'yxat qilib bering.
- `new_session` — kontekst katta bo'lsa: yangi mavzuda yangi sessiya, shu mavzuda `/compact` tavsiya qiling (Token Kuzatuv'dagi «Yangi sessiyada davom ettirish» tugmasi xulosani o'zi beradi).
- `habit` — bir-ikki gaplik odat tavsiyasi, fayl o'zgarmaydi.

Har bir fayl o'zgarishini avval ko'rsating (nima qo'shiladi/o'zgaradi) va foydalanuvchi tasdiqlagandan keyingina yozing. Kod va loyiha mantiqiga tegmang.

## 4. Yakun

Kamida bitta o'zgarish qo'llangan bo'lsa, `savings_report` ni o'sha `project` va `applied: true` bilan yana bir marta chaqiring — Token Kuzatuv tuzatish sanasini yozib, keyingi kunlarda isrofni «avval → keyin» solishtiradi. Hisobotda `last_fix` bo'lsa (oldingi tuzatish), uning natijasini ham bir gapda ayting.

Nima o'zgargani va kutilgan tejashni bir-ikki gapda ayting. Natijani keyingi kunlarda Token Kuzatuv → Tejash sahifasida (loyiha isrofi kamayganini) kuzatish mumkinligini eslating.
