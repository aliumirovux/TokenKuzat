# Token Kuzatuv

**[English](#english)** · O'zbekcha

Mac menyu satrida turadigan ilova. Claude Code va Cowork sessiyalarida tokenlar qayerga ketayotganini, qaysi agentlar ishlayotganini va nimalarga kirayotganini jonli ko'rsatadi; kunlik tarixni saqlaydi, ish tugaganda, qadam osilib qolganda va limitga yaqinlashganda xabar beradi.

Faqat o'zingiz uchun: internetga hech narsa yubormaydi, faqat diskdagi `~/.claude/projects` fayllarini o'qiydi.

Ilova ikki tilda: O'zbekcha va English — Sozlamalar → «Til / Language» (sukut bo'yicha Mac tiliga qarab).

## O'rnatish

### Tayyor ilova (DMG)

[Releases](https://github.com/aliumirovux/TokenKuzat/releases/latest) sahifasidan `TokenKuzatuv-<versiya>.dmg` ni yuklab oling, oching va **Token Kuzatuv**ni **Applications** papkasiga sudrang. Apple Silicon va Intel Mac'larda ishlaydi, macOS 13+.

Ilova hozircha Apple Developer ID bilan imzolanmagan (test rejimi), shuning uchun birinchi ochishda macOS «ochib bo'lmaydi» deydi. Bir marta shunday qiling:

1. Ilovani oching → ogohlantirishda **Done** (yoki **OK**).
2. **System Settings → Privacy & Security** → pastda «Token Kuzatuv was blocked…» yonidagi **Open Anyway** → parol.

Yoki Terminal'da: `xattr -dr com.apple.quarantine "/Applications/Token Kuzatuv.app"`.

Ilova kuniga bir marta GitHub'da yangi versiya borligini tekshiradi (faqat ochiq reliz ma'lumoti o'qiladi, hech narsa yuborilmaydi). Yangisi chiqsa, menyu panelida va Sozlamalarda «yuklab olish» havolasi paydo bo'ladi. O'chirish: Sozlamalar → «Yangi versiyani tekshirish».

### Claude Code orqali

Claude Code'da:

```
/plugin install tokenkuzat --marketplace aliumirovux/TokenKuzat
/tokenkuzat:install
```

Birinchisi plaginni qo'shadi, ikkinchisida Claude talablarni tekshiradi, ilovani yig'adi va `~/Applications/Token Kuzatuv.app` ga o'rnatib ochadi. Eski Claude Code'da (2.1.275 dan oldingi) birinchi qator o'rniga `/plugin marketplace add aliumirovux/TokenKuzat`, keyin `/plugin install tokenkuzat@tokenkuzat`.

Plagin Claude'ga MCP asboblarini ham beradi — sarfni to'g'ridan-to'g'ri so'rash mumkin: «bugun qancha token ketdi?», «qaysi sessiya ko'p sarflayapti?», «limitim qancha qoldi?» (`usage_summary`, `list_sessions`, `session_details`, `savings_report`). Asboblar ilovaning `--mcp` rejimida ishlaydi, shuning uchun avval `/tokenkuzat:install`; keyin `/mcp` da `tokenkuzat` ni qayta ulang.

Tokenni tejash bir buyruq bilan: loyihada Claude Code'ni oching va `/tokenkuzat:optimize` yozing — Claude shu loyiha bo'yicha isrof sabablarini oladi, tushuntiradi va tuzatishlarni (CLAUDE.md qoidalari, ishlatilmaydigan MCP serverlar) har birini siz tasdiqlagandan keyin qo'llaydi.

«Ofis» paneli: plagin Claude Code'da chat yonida panel ochadi. Unda shu sessiyaning agenti va yordamchi agentlari robot bo'lib ishlaydi: asbob ishlatayotgani monitorida belgi chiqadi, ruxsat kutayotgani qo'l silkitadi, bo'shi divanda dam oladi. Panel sessiya boshida o'zi ochiladi, yopilsa — `/ofis`. Terminalda rasm o'rniga ro'yxat chiqadi. Ilova o'rnatilishi shart emas.

Yangilash: `/plugin marketplace update tokenkuzat`, keyin yana `/tokenkuzat:install`.

### Qo'lda

```bash
bash build.sh
```

Loyiha papkasida yurgizing — ilova `~/Applications/Token Kuzatuv.app` ga o'rnatiladi va o'zi ochiladi. Yoki Finder'da `O'rnatish.command` ni ikki marta bosing.

| Buyruq | Nima qiladi |
|---|---|
| `bash build.sh` | yig'adi, o'rnatadi, ochadi |
| `bash build.sh --test` | avval testlarni yurgizadi |
| `bash build.sh --no-open` | o'rnatadi, lekin ochmaydi |
| `swift test` | faqat testlar |
| `swift scripts/make-icon.swift .` | ikonkani qayta chizadi |
| `bash scripts/release.sh` | tarqatish uchun universal DMG: `dist/TokenKuzatuv-<versiya>.dmg` (+ `.sha256`) |

Talab: macOS 13+, Xcode yoki Command Line Tools. `xcrun: error` chiqsa — bir marta `sudo xcodebuild -license accept`.

## Imkoniyatlar

**Menyu satri.** Tinch paytda bugungi jami; agent ishlayotganda ⚡ va tezlik (token/daqiqa). Sozlamalarda: limit foizi yoki faqat belgi. Bosilsa — ixcham panel: bugun / 5 soat / tezlik, limit, 60 daqiqalik grafik, so'nggi sessiyalar.

**Katta oyna** (yon menyu bilan; macOS 26+ da Liquid Glass dizayn):

- **Umumiy** — «Hozir» kartasi (nima bo'layotgani), Claude limiti halqalari, 4 ta asosiy ko'rsatkich (kechagi kun bilan solishtirish), limit, 60 daqiqalik grafik, bugungi token tarkibi, oxirgi 7 kun, so'nggi sessiyalar va harakatlar.
- **Agentlar sxemasi** — n8n uslubidagi jarayon oqimi: So'rov → Asosiy agent → Natija; agent ostida Model va ishlatilish tartibidagi asboblar (Fayllar, Terminal, Internet, MCP), yordamchi agentlar tarmoq bo'lib. So'rovlar orasida ‹ › bilan yuriladi, zoom bor. «Fayllar» ko'rinishida — issiqlik xaritasi: qaysi fayl qachon va necha marta o'qilgan/o'zgartirilgan. «Vaqt» ko'rinishida — vaqt chizig'i: agentlar qatorlari, qadamlar davomiyligi bo'yicha, parallel ishlar va «vaqt qayerga ketdi» (model / asboblar). «Replay» — tanlangan so'rovni boshidan qayta ijro etish (slayder, tezlik, qadamma-qadam): uchala ko'rinish o'sha paytdagi holatni ko'rsatadi. O'ng panelda so'rovlar bo'yicha jarayon lentasi: har bir qadam, davomiyligi va natijasi. Qadamni bosing — n8n'dagi node bajarilishi kabi: **Chiqish** (asbob nima qaytardi, kontekstga necha token qo'shdi), **Kirish** (asbobga berilgan parametrlar) va **Tafsilot**.
- **Ofis** — loyihalar xona, agentlar robot bo'lib ishlaydigan 3D bino: kim stolda ishlayapti, kim o'ylayapti, kim ruxsat kutib qo'l silkitayapti, kim divanda dam olyapti. Asosiy agent yordamchilarga topshiriq beradi, kuzatuvchi dron e'tibor kerak xonaga nur tushiradi. Robotni bosing — sessiya xaritasi ochiladi.
- **Sessiyalar** — oxirgi 7 kun, qidiruv bilan; har bir sessiya tarkibi va agentlari.
- **Tarix** — 7/14/30 kunlik grafik, kunni bosib tarkibini ko'rish, jadval, CSV eksport.
- **Tejash** — loyihalar sarf bo'yicha (bugun / 7 kun), har birida taxminiy isrof va sabablari: katta kontekst, og'ir boshlanish, katta natijalar, takroriy o'qish, skrinshotlar, kesh. «Claude'ga topshirish» — tayyor topshiriqni nusxalaydi, «Terminalda ochish», «Yangi sessiyada davom ettirish».
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

## Bulutdagi chatlarni xaritada ko'rish

claude.ai va desktop chatdagi ishlar bulutda bajariladi — Mac'ga o'zi tushmaydi. Chatdan Claude'ga «yozuvini Token Kuzatuv uchun ber» deng: u .jsonl faylni yuboradi. Uni Sozlamalar → Ma'lumot → **«Chat yozuvini qo'shish…»** bilan qo'shing yoki oynaga sudrab tashlang — sessiya «Claude chat» loyihasi bo'lib, Claude Code sessiyalari kabi to'liq ko'rinadi (jonli emas: yozuv olingan paytgacha).

## Chat va bulut ulushi (taxminiy)

claude.ai va desktop chatlar, bulutdagi sessiyalar Mac diskiga yozilmaydi — ularning qadamlarini ko'rib bo'lmaydi. Lekin ular ham haqiqiy limitni yeydi. Sozlamalar → «Claude hisobidan olish» yoqilgan bo'lsa, ilova limit foizi o'sishini shu Mac'dagi sarf bilan solishtiradi va «Umumiy»dagi limit blokida ko'rsatadi: **Mac'da / Chat va bulut / Aniqlanmoqda / Kuzatuvdan oldin**, hamda bugun chat va bulutga ketgan taxminiy vaznli token. Mac ulushi «1% ≈ N vaznli token» koeffitsiyenti bilan ajratiladi — u faqat Mac ishlagan oraliqlardan o'rganiladi, birinchi bir necha o'lchovgacha aralash qism «Aniqlanmoqda» bo'lib turadi.

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

- Faqat shu Mac'dagi Claude Code va Cowork sessiyalari ko'rinadi (terminal, desktop ilovadagi Code yoki Cowork). claude.ai chatlari va bulutdagi sessiyalar Mac diskiga yozilmaydi — ularning qadamlari bu yerga tushmaydi, faqat limitdagi umumiy ulushi (yuqoriga qarang).
- Vaznli hisob taxminiy: Anthropic limitni aynan qanday hisoblashini e'lon qilmaydi.

---

## English

Token Kuzatuv ("token watch" in Uzbek) is a macOS menu bar app that shows, live, where your tokens go in Claude Code and Cowork sessions: which agents are running, which tools and files they touch, how close you are to the 5-hour and weekly limits. It keeps a daily history and notifies you when a task finishes, a step gets stuck, Claude asks for permission or a limit is near.

The app speaks **English and Uzbek** — Settings → "Til / Language" (defaults to your Mac's language: English if it's English, Uzbek otherwise). It reads only local `~/.claude/projects` files and chat transcripts you add yourself; nothing is uploaded (the optional account limit check talks only to `api.anthropic.com` with Claude Code's own key; the update check reads public release info from `api.github.com`).

### Install

**Ready-made app:** download `TokenKuzatuv-<version>.dmg` from [Releases](https://github.com/aliumirovux/TokenKuzat/releases/latest), open it and drag **Token Kuzatuv** to **Applications** (Apple Silicon and Intel, macOS 13+). It isn't signed with an Apple Developer ID yet (test phase), so the first launch is blocked: open it once, then **System Settings → Privacy & Security → Open Anyway** (or `xattr -dr com.apple.quarantine "/Applications/Token Kuzatuv.app"`). The app checks GitHub once a day for a newer release (it only reads public release info) and shows a download link in the menu bar panel and Settings; turn it off in Settings → "Check for updates".

From Claude Code:

```
/plugin install tokenkuzat --marketplace aliumirovux/TokenKuzat
/tokenkuzat:install
```

The plugin also gives Claude read-only MCP tools (`usage_summary`, `list_sessions`, `session_details`, `savings_report`), so you can ask "how many tokens today?" or "how much of my limit is left?". To cut waste in a project, open Claude Code there and run `/tokenkuzat:optimize`: Claude pulls that project's waste report and proposes fixes (CLAUDE.md rules, unused MCP servers), applying each only after you approve.

The plugin also adds an "Office" pane beside the chat in Claude Code: the session's agent and its helper agents work as robots — a busy one shows its tool on the monitor, one waiting for permission waves, an idle one rests on the sofa. It opens when the session starts; reopen it with `/ofis`. In a terminal it shows a list instead of the drawing. The Mac app is not needed for it.

Or by hand, in the repo folder (requires macOS 13+ and Xcode or Command Line Tools):

```bash
bash build.sh
```

It builds, installs to `~/Applications/Token Kuzatuv.app` and opens it. `bash build.sh --test` runs the tests first; `swift test` runs only the tests.

### What's inside

- **Menu bar** — today's total, or ⚡ and tokens/min while an agent works; click for a compact panel with limits, the last hour and recent projects.
- **Today** — what's happening now, Claude limit rings, key numbers vs. yesterday, hourly chart and token breakdown.
- **Live** — every running session as a card or as parallel lanes, plus "Chat & elsewhere" (claude.ai, desktop chat, cloud work that never reaches your disk).
- **Session map** — an n8n-style flow of prompt → main agent → tools and subagents, a file heatmap, a timeline and Replay; click a step to see its input, output and tokens.
- **Sessions / History / Activity feed** — search, 7/14/30-day history with CSV export, every tool call.
- **Savings** — projects ranked by usage (today / 7 days) with estimated waste and its causes; one click copies a ready task for Claude.
- **Settings** — language, launch at login, menu bar style, raw vs. weighted counting, limits and notifications.

### Adding translations

User-visible text sits next to its translation: `tr("Bugun", "Today")` (`Sources/TokenKuzatCore/Localization.swift`). Add both strings when you add new text.

