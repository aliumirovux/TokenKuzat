# Token Kuzatuv

Mac menyu satrida turadigan ilova. Claude Code va Cowork sessiyalarida tokenlar qayerga ketayotganini, qaysi agentlar ishlayotganini va nimalarga kirayotganini jonli ko'rsatadi; kunlik tarixni saqlaydi, ish tugaganda, qadam osilib qolganda va limitga yaqinlashganda xabar beradi.

Faqat o'zingiz uchun: internetga hech narsa yubormaydi, faqat diskdagi `~/.claude/projects` fayllarini o'qiydi.

## O'rnatish

```bash
bash ~/Developer/TokenKuzat/build.sh
```

Ilova `~/Applications/Token Kuzatuv.app` ga o'rnatiladi va o'zi ochiladi. Yoki Finder'da `O'rnatish.command` ni ikki marta bosing.

| Buyruq | Nima qiladi |
|---|---|
| `bash build.sh` | yig'adi, o'rnatadi, ochadi |
| `bash build.sh --test` | avval testlarni yurgizadi |
| `bash build.sh --no-open` | o'rnatadi, lekin ochmaydi |
| `swift test` | faqat testlar |
| `swift scripts/make-icon.swift .` | ikonkani qayta chizadi |

Talab: macOS 13+, Xcode yoki Command Line Tools. `xcrun: error` chiqsa — bir marta `sudo xcodebuild -license accept`.

## Imkoniyatlar

**Menyu satri.** Tinch paytda bugungi jami; agent ishlayotganda ⚡ va tezlik (token/daqiqa). Sozlamalarda: limit foizi yoki faqat belgi. Bosilsa — ixcham panel: bugun / 5 soat / tezlik, limit, 60 daqiqalik grafik, so'nggi sessiyalar.

**Katta oyna** (yon menyu bilan):

- **Umumiy** — 4 ta asosiy ko'rsatkich (kechagi kun bilan solishtirish), limit, 60 daqiqalik grafik, bugungi token tarkibi, oxirgi 7 kun, so'nggi sessiyalar va harakatlar.
- **Agentlar sxemasi** — n8n uslubidagi jarayon oqimi: So'rov → Asosiy agent → Natija; agent ostida Model va ishlatilish tartibidagi asboblar (Fayllar, Terminal, Internet, MCP), yordamchi agentlar tarmoq bo'lib. So'rovlar orasida ‹ › bilan yuriladi, zoom bor. «Fayllar» ko'rinishida — issiqlik xaritasi: qaysi fayl qachon va necha marta o'qilgan/o'zgartirilgan. «Vaqt» ko'rinishida — vaqt chizig'i: agentlar qatorlari, qadamlar davomiyligi bo'yicha, parallel ishlar va «vaqt qayerga ketdi» (model / asboblar). O'ng panelda so'rovlar bo'yicha jarayon lentasi: har bir qadam, davomiyligi va natijasi.
- **Sessiyalar** — oxirgi 7 kun, qidiruv bilan; har bir sessiya tarkibi va agentlari.
- **Tarix** — 7/14/30 kunlik grafik, kunni bosib tarkibini ko'rish, jadval, CSV eksport.
- **Jonli lenta** — har bir asbob chaqiruvi va so'rovlaringiz; loyiha bo'yicha filtr.
- **Sozlamalar** — avto-ishga tushish, menyu satri ko'rinishi, hisoblash usuli, limit va bildirishnomalar, manbalar, tarixni tozalash.

## Bildirishnomalar

macOS bildirishnomasi quyidagi hollarda keladi (har birini Sozlamalar → Bildirishnomalar'da yoqish/o'chirish va chegarasini o'zgartirish mumkin):

| Hodisa | Sukut bo'yicha | Xabar |
|---|---|---|
| Claude ishni tugatdi | ish ≥ 1 daqiqa bo'lsa | davomiylik, qadamlar, tokenlar — «javobingizni kutyapti» |
| Qadam tugamayapti | 1,5 daqiqadan keyin | ko'pincha Claude ruxsat so'rab turgan bo'ladi |
| Ketma-ket xatolar | 3 ta xato | agent bir joyda aylanib qolgan bo'lishi mumkin |
| Limit | 80% va 100% | limit yoqilgan bo'lsa |

Bildirishnomani bosing — o'sha sessiya Agentlar sxemasida ochiladi. Ilova ochilganda mavjud holatlar uchun xabar yuborilmaydi. Birinchi marta macOS ruxsat so'raydi; ruxsat yo'q bo'lsa, Sozlamalardagi «Ruxsat berish…» tugmasi kerakli oynani ochadi, «Sinov bildirishnomasi» bilan tekshirish mumkin.

## Xom va Vaznli

- **Xom:** barcha token teng sanaladi.
- **Vaznli (taxminiy):** kiritish narxiga nisbatan — javob ×5, kesh o'qish ×0,1, kesh yozish ×1,25 (1 soatlik kesh ×2). Limitni nima ko'proq «yeyayotgani»ni shu rejim yaxshiroq ko'rsatadi. Limit har doim vaznli tokenda hisoblanadi.

## Claude'ning haqiqiy limiti

Sozlamalar → «Claude limiti (haqiqiy)» → **«Claude Code'ga ulash»**. Shundan keyin Claude Code har javobdan so'ng status line orqali 5 soatlik va haftalik limit foizini beradi (Pro/Max obunada), Token Kuzatuv esa uni ko'rsatadi, «qachon tugaydi» bashoratini qiladi va 80% / 95% da ogohlantiradi. Terminalda Claude Code'ning pastki satrida `5 soat 34% ↻16:40 · hafta 61% · $1,23` ko'rinadi.

Ulash `~/.claude/settings.json` ga `statusLine` yozadi (birinchi marta `settings.json.tokenkuzat-backup` nusxasi olinadi). Avval o'z status line'ingiz bo'lsa — u saqlanadi va uning chiqishi ko'rsatilishda davom etadi; «Uzish» uni qaytaradi.

## O'z limitim (taxminiy)

Claude obunasi limiti 5 soatlik oyna bo'yicha tiklanadi, aniq qiymati e'lon qilinmaydi. Sozlamalarda o'zingizga mos limit qo'ying (Tarix sahifasidagi odatiy sarfga qarab) — davr «Oxirgi 5 soat» yoki «Bugun». 80% va 100% da macOS bildirishnomasi keladi (har biri bir marta; 5 soatlik oynada sarf 50% dan tushgach qayta qurollanadi).

## Qanday ishlaydi

```
Sources/
  TokenKuzatCore/        UI'siz, test qilinadigan yadro
    TranscriptParser     .jsonl qatori → hodisa (usage, asbob, so'rov, sarlavha)
    Engine               fayllarni topish, faqat yangi baytlarni o'qish, yig'ish, snapshot
    HistoryStore         kunlik jami → ~/Library/Application Support/TokenKuzat/history.json
    ActivityMonitor      snapshot'lardan hodisa: tugadi, osildi, ketma-ket xato
    TokenCounts/Pricing  token turlari va narx vazni
  TokenKuzat/            SwiftUI ilova
    Store                Engine'ni fon navbatida har soniyada yurgizadi
    Alerts               bildirishnomalar (limit va sessiya hodisalari)
    UI/                  menyu paneli, oyna sahifalari, grafiklar
Tests/                   parser, engine, tarix, formatlash testlari
```

- Engine har 5 soniyada oxirgi 30 kunda o'zgargan `.jsonl` fayllarni topadi va har soniyada faqat yangi qo'shilgan qatorlarni o'qiydi.
- Bitta javob transcript'da bir necha qatorga bo'linib, har birida bir xil `usage` takrorlanadi — `message.id + requestId` bo'yicha bir marta sanaladi.
- Kun almashganda hech narsa qayta o'qilmaydi; kunlik jami har daqiqada diskka yoziladi, shuning uchun eski transcript'lar o'chsa ham tarix qoladi.
- Ma'lumot o'zgarmasa UI 3 soniyada bir yangilanadi — CPU tejaladi.

## Cheklovlar

- Faqat shu Mac'dagi Claude Code va Cowork sessiyalari ko'rinadi (terminal, desktop ilovadagi Code yoki Cowork). claude.ai chatlari va bulutdagi sessiyalar Mac diskiga yozilmaydi — ular bu yerga tushmaydi.
- Vaznli hisob taxminiy: Anthropic limitni aynan qanday hisoblashini e'lon qilmaydi.
