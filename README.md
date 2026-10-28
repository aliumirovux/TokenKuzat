# Token Kuzatuv

Mac menyu satrida turadigan ilova. Claude Code sessiyalarida tokenlar qayerga ketayotganini, qaysi agentlar ishlayotganini va nima qilayotganini jonli ko'rsatadi; kunlik tarixni saqlaydi va limitga yaqinlashganda ogohlantiradi.

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
- **Agentlar sxemasi** — so'rov → asosiy agent → u kirgan narsalar (Fayllar, Terminal, Internet, MCP xizmatlar) va yordamchi agentlar. Hozir bajarilayotgan qadamga chiziqda nuqtalar oqadi, qalinlik — hajm. O'ng panelda jarayon lentasi: har bir qadam, davomiyligi va natijasi (xatolar qizil).
- **Sessiyalar** — oxirgi 7 kun, qidiruv bilan; har bir sessiya tarkibi va agentlari.
- **Tarix** — 7/14/30 kunlik grafik, kunni bosib tarkibini ko'rish, jadval, CSV eksport.
- **Jonli lenta** — har bir asbob chaqiruvi va so'rovlaringiz; loyiha bo'yicha filtr.
- **Sozlamalar** — avto-ishga tushish, menyu satri ko'rinishi, hisoblash usuli, limit va bildirishnomalar, manbalar, tarixni tozalash.

## Xom va Vaznli

- **Xom:** barcha token teng sanaladi.
- **Vaznli (taxminiy):** kiritish narxiga nisbatan — javob ×5, kesh o'qish ×0,1, kesh yozish ×1,25 (1 soatlik kesh ×2). Limitni nima ko'proq «yeyayotgani»ni shu rejim yaxshiroq ko'rsatadi. Limit har doim vaznli tokenda hisoblanadi.

## Limit

Claude obunasi limiti 5 soatlik oyna bo'yicha tiklanadi, aniq qiymati e'lon qilinmaydi. Sozlamalarda o'zingizga mos limit qo'ying (Tarix sahifasidagi odatiy sarfga qarab) — davr «Oxirgi 5 soat» yoki «Bugun». 80% va 100% da macOS bildirishnomasi keladi (har biri bir marta; 5 soatlik oynada sarf 50% dan tushgach qayta qurollanadi).

## Qanday ishlaydi

```
Sources/
  TokenKuzatCore/        UI'siz, test qilinadigan yadro
    TranscriptParser     .jsonl qatori → hodisa (usage, asbob, so'rov, sarlavha)
    Engine               fayllarni topish, faqat yangi baytlarni o'qish, yig'ish, snapshot
    HistoryStore         kunlik jami → ~/Library/Application Support/TokenKuzat/history.json
    TokenCounts/Pricing  token turlari va narx vazni
  TokenKuzat/            SwiftUI ilova
    Store                Engine'ni fon navbatida har soniyada yurgizadi
    Alerts               limit bildirishnomalari
    UI/                  menyu paneli, oyna sahifalari, grafiklar
Tests/                   parser, engine, tarix, formatlash testlari
```

- Engine har 5 soniyada oxirgi 30 kunda o'zgargan `.jsonl` fayllarni topadi va har soniyada faqat yangi qo'shilgan qatorlarni o'qiydi.
- Bitta javob transcript'da bir necha qatorga bo'linib, har birida bir xil `usage` takrorlanadi — `message.id + requestId` bo'yicha bir marta sanaladi.
- Kun almashganda hech narsa qayta o'qilmaydi; kunlik jami har daqiqada diskka yoziladi, shuning uchun eski transcript'lar o'chsa ham tarix qoladi.
- Ma'lumot o'zgarmasa UI 3 soniyada bir yangilanadi — CPU tejaladi.

## Cheklovlar

- Faqat shu Mac'dagi Claude Code sessiyalari ko'rinadi (desktop ilovadagi Code yoki terminal). claude.ai bulut chatlari bu yerga tushmaydi.
- Vaznli hisob taxminiy: Anthropic limitni aynan qanday hisoblashini e'lon qilmaydi.
