# O'zgarishlar

## 2.2.0 — 2026-10-28

**Bildirishnomalar**
- Claude ishni tugatganda (sozlanadigan minimal davomiylik bilan), qadam uzoq tugamaganda (ruxsat kutilishi mumkin) va agent ketma-ket 3 marta xato olganda macOS bildirishnomasi.
- Bildirishnoma bosilsa — o'sha sessiya Agentlar sxemasida ochiladi; ilova ochiq bo'lsa ham banner chiqadi.
- Sozlamalarda «Bildirishnomalar» bo'limi va «Ruxsat berish…» tugmasi.
- Hodisa mantiqi `ActivityMonitor` (yadroda) — ilova ochilganda mavjud holatlar uchun xabar yuborilmaydi.

## 2.1.0 — 2026-10-28

**Jarayonni kuzatish**
- Sxemada har bir agentdan u kirgan narsalar tugun bo'lib chiqadi: Fayllar, Terminal, Internet, Tashqi xizmatlar (MCP), Agent chaqiruvlari. Har birida eng so'nggi 3 tasi va o'qish/yozish/xato belgilari.
- Hozir bajarilayotgan qadamga boradigan chiziqda nuqtalar oqadi; oxirgi 20 soniyada ishlatilgani yorqin, eskisi xira.
- Yordamchi agent tanlansa, uning resurslari 4-ustunda ochiladi.
- O'ng panel: «Jarayon» lentasi — har bir qadam, boshlangan vaqti, davomiyligi, holati (bajarilmoqda / tugadi / xato); resurs tanlansa — to'liq ro'yxat.
- Sxema oynaga avtomatik sig'diriladi; tugunlar endi pastga siljib qolmaydi.

## 2.0.0 — 2026-10-28

**Yangi**
- Katta oyna yon menyu bilan: Umumiy, Agentlar sxemasi, Sessiyalar, Tarix, Jonli lenta, Sozlamalar.
- Kunlik tarix (30 kun grafigi, jadval, CSV eksport) — diskda saqlanadi, transcript o'chsa ham qoladi.
- «Oxirgi 5 soat» ko'rsatkichi va limit: progress-bar, menyu satrida foiz, 80%/100% bildirishnomasi.
- Sozlamalar sahifasi: avto-ishga tushish, menyu satri ko'rinishi, hisoblash usuli, limit, manbalar.
- Fikrlash tokenlari alohida; sessiyaga berilgan nom («custom-title») sarlavha sifatida.
- Ilova ikonkasi; oyna ochiq paytda Dock va Cmd-Tab'da ko'rinadi, o'lchami eslab qolinadi.

**Tuzatildi**
- Yarim tunda barcha fayllar qaytadan o'qilardi — endi faqat eski yozuvlar tozalanadi.
- O'chirilgan fayllar xotirada qolib ketardi.
- Sessiya boshqa papkaga ko'chsa, loyiha nomi eski qolardi.
- Bitta javob asosiy va yordamchi faylda takrorlansa, ikki marta sanalishi mumkin edi (dedup endi global).
- UI ma'lumot o'zgarmasa ham har soniyada qayta chizilardi.
- README'dagi «faqat bugungi fayllar» degan noto'g'ri ma'lumot.

**Ichki**
- Kod `TokenKuzatCore` (yadro) va `TokenKuzat` (UI) ga bo'lindi; transcript parser alohida.
- 11 ta unit test (parser, engine, tarix, formatlash).
- Versiya `VERSION` faylida, Info.plist `Resources/` da; `build.sh` — `--test`, `--no-open`.

## 1.3
- Agentlar sxemasi (n8n uslubida), jonli lenta, Xom/Vaznli rejim.
