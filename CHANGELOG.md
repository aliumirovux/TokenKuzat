# O'zgarishlar

## 4.2.0 — 2026-10-28

- Jonli chiziqlar — ma'lumot almashinuvi: chiziq bo'ylab yorug'likli «kometa» paketlar yuradi; so'rov oldinga (asosiy rangda), javob orqaga (ochroq), ease-in-out harakat, chiziq chetlarida yumshoq kirib-chiqadi.
- Xulosa va Jarayon ko'rinishlarida bir xil (`DataFlow`); tinch chiziqlar oddiy va xira qoladi.

## 4.1.1 — 2026-10-28

- Oqim (Xulosa): «Model» va «Asboblar» yorliqlari port ustida fonli pill — chiziqlar endi ularni kesib o'tmaydi.
- Kirish animatsiyasi: sxema ochilganda yoki so'rov almashganda tugunlar birin-ketin paydo bo'ladi, chiziqlar boshidan oxirigacha chiziladi (Xulosa va Jarayon).
- Jarayon: bajarilayotgan bosqichga boradigan chiziq jonli harakatlanadi.

## 4.1.0 — 2026-10-28

**Oqim — haqiqiy jarayon**
- «Oqim» tabining asosiy ko'rinishi endi «Jarayon»: so'rov → bosqichlar (ishlangan tartibda) → natija, n8n bajarilish ko'rinishi kabi; qatorlar ilon izi bo'lib boradi.
- Ketma-ket kelgan bir xil turdagi qadamlar bitta bosqich («Terminal ×4 · sed · grep · python3»), har birida boshlanish vaqti, davomiyligi va holati (✓ / ✕ / ● jonli).
- Bosqichlar orasida model o'ylagan vaqt («💭 12 s»); bajarilayotgan bosqichga chiziq yashil.
- O'ngda — tanlangan bosqich ichidagi har bir qadam.
- Avvalgi umumiy ko'rinish «Xulosa» nomi bilan qoldi. Sessiya sahifasi aylantiriladigan bo'ldi — oqim endi siqilmaydi.

## 4.0.0 — 2026-10-28

**Yangi dizayn — «Imzo»** (real ilovalar tadqiqoti asosida: Browserbase run sahifasi, Attio/n8n oqimi, Ahead/Revolut limit ekranlari, Vercel usage; maketlar — `design/redesign-v4.html`, `design/redesign-v5.html`)
- Shisha, nur va rangli dog'li fon olib tashlandi: tinch neytral sirtlar, bitta urg'u rangi, to'q siyoh rangli qahramon blok.
- «Bugun»: limit bloki — qancha qoldi (88 pt raqam), qachon tiklanadi, bashorat, hafta va 5 soatlik oyna soatma-soat (o'tgan / hozirgi / kelajak); «Hozir» qatori (asbob plitasi, so'nggi 10 qadam izi, taymer); bento — tokenlar sparkline, faol vaqt 24 soatlik xarita, qadamlar asbob turlari bo'yicha; bugungi sessiyalar monogramma, asbob plitalari va faollik chizig'i bilan.
- Yon menyu: Bugun · Sessiyalar · Tarix + «Loyihalar» (jonli nuqta bilan) + Sozlamalar.
- Sessiya sahifasi: so'rov — sarlavha, o'ngda davomiylik / qadamlar / token; so'rov chiplari; qatorli vaqt chizig'i (Model va asbob turlari) + replay + «vaqt qayerga ketdi»; tablar — Qadamlar (ro'yxat + tafsilot), Oqim, Fayllar.
- Menyu paneli: to'q blokda qolgan limit va 5 soatlik mini-ustunlar; menyu satrida «qancha qoldi» foizi.
- Yadro: bugungi soatlik sarf, faol daqiqalar, oxirgi 6 soat daqiqama-daqiqa.

## 3.0.0 — 2026-10-28

**Yangi dizayn: shisha va yumshoq harakatlar**
- macOS 26+ da Apple Liquid Glass: kartalar, holat belgilari, menyu paneli, oqim tugunlari, o'ynatgich va boshqaruv tugmalari shishadan (eski macOS'da — material).
- Oyna foni: sekin suzadigan xira rangli dog'lar — shisha ularni sindirib ko'rsatadi (Core Animation, CPU deyarli sarflanmaydi).
- Umumiy sahifa tepasida «Hozir» kartasi: qaysi loyihada, qaysi agent, nima qilyapti, qancha vaqtdan beri, so'rov raqami, qadamlar va tokenlar; bosilsa — sxemada ochiladi. Tinch paytda — oxirgi ish.
- Claude limiti halqa ko'rsatkichlarida (5 soat / hafta), tiklanish vaqti va bashorat bilan.
- Harakatlar: sahifalar almashganda yumshoq o'tish, raqamlar aylanib almashadi, halqa va chiziqlar silliq to'ladi, kartalar hover'da ko'tariladi, oqimda yangi tugunlar kattalashib paydo bo'ladi va joylashuv o'zgarganda silliq suriladi, jonli holat nuqtasi «nafas oladi».
- Sahifa sarlavhasida bo'lim belgisi; yumaloq (rounded) shrift sarlavhalarda.

## 2.8.0 — 2026-10-28

**Replay — jarayonni qayta ijro etish**
- Agentlar sxemasida «Replay» tugmasi: tanlangan so'rov (yoki butun sessiya) boshidan ijro etiladi.
- O'ynatgich: ▶/⏸ (bo'sh joy), oldingi/keyingi qadamga sakrash, vaqt slayderi (ustida — har bir qadam belgisi, xatolar qizil), tezlik 1× / 5× / 20× / 60×, «Jonli» — hozirgi holatga qaytish.
- Uchala ko'rinish — Oqim, Vaqt, Fayllar — va o'ng panel sessiyaning o'sha paytdagi holatini ko'rsatadi: qaysi agent ishlagan, qaysi asbob bajarilayotgan bo'lgan, o'sha paytgacha qancha token ketgan, qaysi fayllarga tegilgan.
- Yadroda `SessionSnap.replay(at:)` — diskka murojaatsiz, slayder tez ishlaydi; testlangan.

## 2.7.0 — 2026-10-28

**Fayllar issiqlik xaritasi**
- Agentlar sxemasida uchinchi ko'rinish — «Fayllar»: har bir fayl qator, vaqt o'qi bo'yicha katakchalar (ko'k — o'qildi, to'q sariq — o'zgartirildi, qizil — xato; to'qligi — murojaatlar soni).
- Eng ko'p o'zgartirilgan va o'qilgan fayllar tepada; o'qish/yozish soni, qaysi agentlar tekkani, papkasi.
- Eng issiq papkalar (bosilsa — filtr), «Faqat o'zgarganlar», qidiruv; o'ng tugma — Finder'da ko'rsatish / yo'lni nusxalash.
- So'rov tanlagich matni chegaradan chiqib strelkalarni yopib qo'yishi tuzatildi.

## 2.6.0 — 2026-10-28

**Vaqt chizig'i**
- Agentlar sxemasida «Oqim | Vaqt» almashtirgichi. Vaqt ko'rinishida har bir agent — qator, har bir qadam — boshlanishidan tugashigacha chiziq (asbob rangi, xato — qizil, bajarilayotgani — miltillaydi).
- Parallel qadamlar qator ichida ustma-ust qavatlarga joylanadi; ustiga olib borilsa — to'liq matn, vaqt va davomiylik.
- «Vaqt qayerga ketdi»: model o'ylashi va javob yozishi hamda har bir asbob turi — vaqti va ulushi bilan.
- «Butun sessiya» rejimida so'rov chegaralari (#N) vertikal chiziq bo'lib ko'rinadi; zoom (kenglik bo'yicha).
- Yuqori panel tor oynada ustma-ust tushmaydi.

## 2.5.0 — 2026-10-28

**Claude'ning haqiqiy limiti**
- Claude Code status line orqali rasmiy limit ma'lumoti: 5 soatlik va haftalik oyna foizi va tiklanish vaqti (Pro/Max).
- «Shu tezlikda qachon tugaydi» bashorati (oxirgi 20 daqiqadagi o'sish bo'yicha).
- Umumiy sahifa, menyu paneli va menyu satrida (Sozlamalar → «5 soatlik limit foizi») ko'rinadi.
- 80% va 95% da bildirishnoma (har bir oynada bir marta).
- Sessiya kartasida Claude Code hisoblagan taxminiy narx ($).
- Sozlamalar → «Claude limiti (haqiqiy)» → «Claude Code'ga ulash»: settings.json nusxasi olinadi, avvalgi status line saqlanib ishlashda davom etadi, «Uzish» hammasini qaytaradi.

## 2.4.0 — 2026-10-28

**Agentlar sxemasi — n8n uslubidagi jarayon oqimi**
- Asosiy chiziq chapdan o'ngga: So'rov → Asosiy agent → Natija (holat, davomiylik, tokenlar, qadamlar, o'zgargan fayllar).
- Agent ostida «Model» va «Asboblar» portlaridan uzuq chiziq bilan dumaloq tugunlar: Claude modeli va ishlatilish tartibida Fayllar, Terminal, Internet, MCP… — chaqiruvlar soni, xatolar va oxirgi nishon bilan.
- Yordamchi agentlar router chiqishlari kabi pastga tarmoqlanadi, o'z asboblari bilan, va natijaga qaytib qo'shiladi.
- So'rov tanlagich (‹ #N ›, ro'yxat, «Butun sessiya»); yangi so'rov kelsa avtomatik unga o'tadi.
- Ishlayotgan tugun yorug'lanadi, unga boradigan chiziq oqadi; zoom: − / sig'dirish / +.

## 2.3.0 — 2026-10-28

- Jarayon lentasi so'rovlar bo'yicha guruhlandi: har bir so'rov — vaqti, davomiyligi, tokenlari, qadamlari va xatolari bilan; eng yangisi ochiq, qolganlari bosib ochiladi.
- Asosiy agentda faqat javob yozilgan (asbobsiz) so'rovlar ham ko'rinadi.
- README: bildirishnomalar bo'limi, Cowork qo'llab-quvvatlanishi.
- Ishlab chiquvchi uchun: `TokenKuzat --snapshot-panel fayl.png` — menyu panelini ikki temada rasmga saqlaydi.

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
