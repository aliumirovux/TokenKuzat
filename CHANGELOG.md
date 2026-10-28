# O'zgarishlar

## 5.6.0 — 2026-10-28

- Limit endi Claude hisobidan (claude.ai «Usage» sahifasi bilan bir xil manba): Claude Code'ning Keychain'dagi kirish kaliti bilan Anthropic'dan joriy sessiya va haftalik foiz, tiklanish vaqti va tarif (Max 5x) har daqiqada olinadi — Code tabi va Claude ilovasida ham. Kalit faqat shu kompyuterda o'qiladi va faqat api.anthropic.com ga yuboriladi; hech qayerga yozilmaydi.
- Sozlamalar → «Claude limiti — hisobdan»: yoqish/o'chirish, holat (ulangan, kalit topilmadi, muddati o'tgan, xato) va «Hozir yangilash». Ishlamasa yoki 15 daqiqadan eski bo'lsa — status line zaxira manba.
- Tarif nomi limit sarlavhasida («5 SOATLIK LIMIT · MAX (5X)»).

## 5.5.0 — 2026-10-28

- Limit Claude sahifasidagidek: «Joriy sessiya» va «Bu hafta» qatorlari — tiklanish vaqti («bugun 18:30», «Seshanba 21:00»), chiziq va «44% ishlatildi» (menyu paneli va «Bugun» sahifasi).
- Haftalik bashorat: oyna boshidan o'rtacha sur'at bilan — «Shu sur'atda juma ertalab tugaydi — 3-noyabr tiklanishidan oldin».
- Ma'lumot 10 daqiqadan eski bo'lsa — ochiq ogohlantirish (status line faqat terminaldagi Claude Code'da yangilanadi).
- Core: hisob (claude.ai) usage javobini o'qish va tarif nomi (Max 5x) — ulash keyingi bosqichda; testlar 29 ta.

## 5.4.0 — 2026-10-28

- Menyu paneli yangilandi: butun panel bir xil qattiq fonda (tagidagi oyna ko'rinmaydi).
- Jarayon kartasi: loyiha va so'rov raqami, holat («Ishlayapti» / «Ruxsat kutyapti» / «Tugadi»), so'rov matni, kichik jarayon izi (xaritadagi kabi: mahalliy ishlar yuqorida, tashqilari pastda, model o'rtada; oxirgi chiziqda paketlar, bajarilayotgan qadam to'lqin bilan), hozirgi qadam va jonli taymer, qadamlar soni, davomiylik, tokenlar va kontekst foizi. Ishlayotganda karta chegarasida yorug'lik aylanadi; bosilsa — sessiya xaritada ochiladi.
- Bugungi xulosa — uchta plitka: tokenlar, faol vaqt, sessiyalar.

## 5.3.0 — 2026-10-28

- Xarita bitta qatorda: kartalar satrga bo'linmaydi — chapdan o'ngga ulanib boradi (n8n kabi). Bo'limlar shu qatorda yonma-yon ramkalar (sarlavha o'z kartalari ustida); yig'ilgan bo'lim — qatordagi ixcham karta (mavzu, so'rovlar soni, vaqt, hajm, «Ochish»).
- Shoxlar saqlandi: mahalliy ishlar tepaga, tashqilari pastga; tanlangan so'rov zanjiri karta ostida.
- Xarita balandlikka sig'sa — vertikal markazda; ergashishda oxirgi karta o'ng tomonda.

## 5.2.0 — 2026-10-28

- Xarita yana satrma-satr (eniga), daraxt va yo'lakli grafik o'rniga. Yangi: asboblar ma'no bo'yicha shoxlanadi — mahalliy ishlar (Fayllar, Terminal, boshqa) kartaning tepasiga, tashqi ishlar (Internet, tashqi xizmatlar, agentlar) pastiga. Tepada shox bo'lgan satr uchun joy oldindan qoldiriladi; tanlangan so'rovning jarayon zanjiri avvalgidek karta ostida.
- Chiziqlar yuqoriga ham silliq egiladi; «Asboblar» yorlig'i faqat pastga shox bo'lsa.

## 5.1.0 — 2026-10-28

- Xarita — oqim grafigi (metro xaritasi kabi), eniga o'sadi: yo'laklar Siz · Model · Terminal · Fayllar · Internet · Tashqi xizmatlar · Agentlar (faqat ishlatilganlari). Har hodisa o'z yo'lagida belgi; chiziq hodisadan hodisaga silliq egri bo'lib yo'lakdan yo'lakka tepaga/pastga o'tadi va borayotgan yo'lak rangida. Javoblar — yashil, o'ylash — bo'sh doira, xatolar — qizil, bajarilayotgan qadam — to'lqin, oxirgi chiziqda paketlar yuradi.
- So'rovlar — ingichka vertikal chiziq va «#41» (bosilsa tanlanadi). Matn faqat ko'rsatkich ostida; bosish — o'ng panelda tafsilot.
- Yo'laklar oyna balandligiga moslashadi; zich/keng tugmalari; «Ergashyapti» — yangi hodisalarda oxiriga o'tadi. Uzun sessiyalarda faqat ko'rinib turgan so'rovlar chiziladi.

## 5.0.0 — 2026-10-28

- Xarita daraxt ko'rinishida: tana — so'rovlar yuqoridan pastga (jonli tana chizig'i bilan), har so'rovdan o'ngga shoxlar — u murojaat qilgan asboblar (Terminal 4×, Fayllar 1×, xatolar bilan). Tanlangan so'rovda shox — butun jarayon: xabarlar, o'ylash va qadamlar tana yonida pastga.
- Bo'limlar va qisqa javob-so'rovlar (karta ichida) saqlandi; g'ildirak bilan tik aylantirish tabiiy.
- Uzoqdan ko'rinish — faqat tana, zich; mini-xarita daraxt nisbatiga moslashadi.

## 4.9.2 — 2026-10-28

- Uzoqdan ko'rinish (50% dan kichik) endi alohida zich joylashuv: asboblar va qadamlar zanjiriga joy qoldirilmaydi, satrlar yaqinlashadi — katta bo'shliqlar yo'qoldi, butun sessiya bir ekranga sig'adi. Kartalarda raqam, 2–3 qator nom va ilingan javoblar soni («↳ +2»).
- Masshtab chegarasidan o'tganda ko'rsatkich ostidagi karta ekranda joyidan siljimaydi.
- `--snapshot-map fayl.png --zoom 0.3` — ishlab chiquvchi uchun.

## 4.9.1 — 2026-10-28

- Qisqa javob-so'rovlar endi kartaning ichida, pastki qatorlarda («↳ Bosdim · 20 s · 2 qadam»): karta shunga cho'ziladi, asboblar yana kartaning o'zidan «Asboblar» porti orqali chiqadi va karta + javoblarining asboblarini birga ko'rsatadi. Ortiqcha ulash nuqtalari yo'qoldi; javoblardan biri ishlayotgan bo'lsa — karta jonli.

## 4.9.0 — 2026-10-28

- Xarita satrma-satr: kartalar oyna kengligida teriladi, satr tugasa oqim chizig'i yumaloq burilish bilan keyingi satr boshiga o'tadi. 50 ta so'rov bir ekranga sig'adi.
- Bo'limlar: 10 daqiqadan uzun tanaffus, kontekst yangilanishi yoki yangi sessiya — yangi bo'lim. Ochiq bo'lim ramkada, tepasida «16:37–16:58 · mavzu · 6 so'rov · 21 daq · 3,4M»; yig'ilgani — bitta bosiladigan chiziq. Sukut bo'yicha oxirgi, ishlayotgan va tanlangan so'rov turgan bo'lim ochiq, qolganlari yig'ilgan.
- Qisqa javob-so'rovlar («ha», «boshla», «Bosdim», «Sinab ko'rdim»…) alohida karta emas — oldingi kartaga «↳ ha boshla · 3 daq · 28 qadam» yorlig'i bo'lib ilinadi; bosilsa, qadamlar shu ustunda ochiladi.
- Uzoqdan ko'rinish: 50% dan kichik masshtabda kartalarda faqat raqam va qisqa nom, katta harfda; bo'lim sarlavhalari ham kattalashadi.
- Mini-xarita ikki o'lchamli: bo'lim ramkalari, kartalar, yig'ilgan bo'limlar va ko'rinib turgan qism.

## 4.8.1 — 2026-10-28

- Xarita zanjiri chat uslubida: katta karta — faqat Xabar va yakuniy Javob (yashil chegara, 4 qator). Asbob qadamlari, o'ylash va «O'ylayapti…» — chiziq ustidagi yupqa yorliqlar («▣3 ✱1 4 qadam · 31 s», «🧠 Zanjir juda uzun…»). Zanjir ~2,5 baravar qisqardi; bosish — avvalgidek tafsilot.

## 4.8.0 — 2026-10-28

- Xaritadagi zanjirda Claude'ning o'ylashi va javoblari: «O'yladi» (matn boshi, taxminiy davomiylik), oraliq «Xabar» va so'rov tugagach yakuniy «Javob». Model hozir o'ylayotgan bo'lsa — oxirida jonli «O'ylayapti…» (soniyalar bilan). Kartani bosish — o'ng panelda to'liq matn (tanlab nusxa olish mumkin).
- Matnsiz (shifrlangan) o'ylashlar ko'rsatilmaydi.
- Zanjir qisqardi: ikki o'ylash/xabar orasidagi asbob qadamlari bitta «5 ta qadam» kartasiga yig'iladi — turlar bo'yicha sanoq, oxirgi qadam va jami vaqt bilan; zanjirda ko'pi bilan 12 bo'g'in, eskilari «+N oldingi»da.
- Engine: o'ylash va javob matnlari (boshi, 2000 belgigacha; sessiyada oxirgi 400 tasi) saqlanadi — faqat kompyuterda.

## 4.7.5 — 2026-10-28

- Sessiya sahifasi endi aylantirilmaydi: Xarita, Xulosa va Fayllar kanvasi oynaning qolgan balandligini to'liq egallaydi (taxminiy hisob o'rniga moslashuvchan joylashuv) — pastda bo'sh joy ham, kesilish ham yo'q. Vaqt chizig'i ochilsa, kanvas shunga qisqaradi.

## 4.7.4 — 2026-10-28

- Sessiya sahifasida uchta teng tab: Xarita, Xulosa, Fayllar. «Oqim» tabi va uning ichidagi Xarita/Xulosa almashtirgichi o'rniga — bitta qatorda; o'ngda faqat tafsilotlar panelini ochish tugmasi.

## 4.7.3 — 2026-10-28

- Oqim'dagi «Jarayon» ko'rinishi olib tashlandi (ProcessFlow) — jarayon endi xaritaning o'zida. Oqim'da ikki ko'rinish: Xarita va Xulosa.

## 4.7.2 — 2026-10-28

- «Qadamlar» tabi olib tashlandi — qadamlar endi xaritadagi jarayon zanjirida va o'ng paneldagi «Jarayon»da. Sessiya sahifasida ikki tab: Oqim (sukut bo'yicha) va Fayllar.
- Fayllar xaritasi ham oyna balandligiga moslashadi.

## 4.7.1 — 2026-10-28

- Sessiya sahifasidagi qatorli vaqt chizig'i sukut bo'yicha yig'ildi: o'rnida bitta ixcham qator — Replay tugmasi va rangli vaqt ulushi («Vaqtning ● 48% — model o'ylashi · ● 40% — terminal»). «Vaqt chizig'i» tugmasi qatorlarni ochadi, tanlov eslab qolinadi. Xarita ~170 pt balandroq.

## 4.7.0 — 2026-10-28

- «Ruxsatingizni kutyapti»: Claude buyruq yoki fayl uchun ruxsat so'rab to'xtaganda macOS bildirishnomasi keladi (bosilsa — o'sha sessiya ochiladi). Sessiya sarlavhasida to'q sariq «Ruxsatingizni kutyapti» yorlig'i, xaritaning oxirgi tugunida qo'l belgisi va qaysi asbob uchunligi, «Bugun»dagi «Hozir» kartasida va menyu satrida «Ruxsat». Claude davom etishi bilan holat o'zi tozalanadi; shu paytda «qadam osilib qoldi» xabari takrorlanmaydi.
- Ulash: Sozlamalar → Bildirishnomalar → «Claude ruxsat so'raganda» → «Claude Code'ga ulash» — ~/.claude/settings.json ga Notification hook qo'shiladi (boshqa hook'lar tegilmaydi, «Uzish» bilan olib tashlanadi). Ilovaning yangi `--hook` rejimi xabarni hooks/<session>.json ga yozadi.
- Kontekst to'lishi: sarlavhada «Kontekst 62%» chizig'i (80% dan sariq, 92% dan qizil), oyna hajmi — 200K yoki sessiyada oshgan bo'lsa 1M. Ishlayotgan sessiyada 85% dan oshsa bildirishnoma: «tez orada avtomatik xulosa qilinadi». «Hozir» kartasida 80% dan oshsa ogohlantirish.
- Testlar: 26 ta (hook xabarini o'qish va kutish holati).

## 4.6.0 — 2026-10-28

- Xaritada jarayon: tanlangan (sukut bo'yicha — eng so'nggi) so'rov kartasi ostida asboblar o'rniga qadamlar zanjiri — har qadam alohida tugun (asbob belgisi, nima qilindi, vaqti, davomiyligi, yordamchi agent nomi), vaqt bo'yicha yuqoridan pastga. Bajarilayotgan qadam jonli chegara bilan, chiziq bo'ylab paketlar yuradi; xatolar qizil.
- Ko'p bo'lsa — oxirgi 14 ta, tepada «+N oldingi qadam». Kartadagi port yorlig'i: «Jarayon · N qadam».
- Ergashish rejimida xarita eng so'nggi qadamgacha o'zi tushib boradi; qadamni bosish — o'ng panelda shu asbob ro'yxati.
- Terminal belgisi qorong'i fonda ko'rinadigan rangda.

## 4.5.1 — 2026-10-28

- Xarita va Xulosa kanvasi oyna balandligiga moslashadi: sahifadagi joyidan oynaning pastigacha to'liq egallaydi, pastki qismi kesilmaydi.
- Xaritani surish chegaralandi: kartalar ekrandan butunlay chiqib ketmaydi, sig'sa — vertikal ichkarida qoladi.
- Oyna o'lchami o'zgarsa, xarita masshtabi va joylashuvi moslashadi; ergashish paytida masshtab o'z-o'zidan o'zgarmaydi.

## 4.5.0 — 2026-10-28

- Yangi «Xarita» (Oqim → Xarita, sukut bo'yicha): butun sessiya n8n uslubidagi cheksiz kanvasda — chapdan o'ngga so'rov kartalari (raqam, vaqt, matn, davomiylik, token, qadam, yordamchilar), har biridan pastga o'sha so'rovda ishlatilgan asboblar (chaqiruv va xato soni bilan).
- Kontekst tugab davom ettirilgan joy «Kontekst yangilandi» belgisi bilan ko'rsatiladi, keyingi karta «Ish davom etdi» va oldingi so'rov matni bilan. Xulosa bilan boshlangan yangi sessiya fayli oldingi sessiya davomiga avtomatik ulanadi (faqat shu aniq belgi bo'lsa).
- Boshqarish: sichqoncha bilan sudrash, g'ildirak/trackpad bilan siljitish, ⌘ yoki ⌥ + g'ildirak va chimdish bilan zoom (20–200%), «Hammasini ko'rsatish», mini-xarita, «Hozirgiga qaytish» va yangi so'rovlarga ergashish. Ekrandan tashqaridagi tugunlar chizilmaydi; uzoqlashganda asboblar yashirinadi.
- Engine: har so'rov uchun asbob turlari xulosasi barcha qadamlar bo'yicha (qisqartirilgan ro'yxatdan emas).
- Sarlavha qisqardi: uzun so'rov matni o'rniga loyiha nomi, so'rovlar soni va tanlangan so'rov raqami. Chiplar va ro'yxatlarda xulosa matni o'rniga «davom etdi».
- Ishlab chiquvchi uchun: `--snapshot-map fayl.png`.

## 4.4.0 — 2026-10-28

- Oqim → Xulosa'dagi o'ng panel qayta chizildi: kengligi 320 → 384, oqim balandligi 640, shriftlar kattaroq, bo'limlar kartalarda.
- Sarlavha: asbob plitasi, katta nom, model va holat yorlig'i.
- Tokenlar: katta jami, sessiyadagi ulush, tarkib chizig'i va har bir qism uchun izoh (keshdan o'qildi, keshga yozildi, yangi kiritish, javob/fikrlash) — qiymat va foiz bilan.
- «Nimalarga kirdi»: plitalar, chaqiruvlar soni bo'yicha saralangan, ulush chizig'i, nishonlar va xatolar soni.
- Jarayon: so'rov kartalarida ma'lumot ikki qatorda (vaqt · davomiylik / tokenlar · qadamlar · xatolar) — endi kesilmaydi; qadamlar kattaroq belgilar bilan.
- Resurs paneli ham shu uslubda.

## 4.3.0 — 2026-10-28

- Ishlayotgan kartalar chegarasi bo'ylab yorug'lik aylanib yuradi (`LiveBorder`): oq bosh, rangli so'nuvchi dum, yengil nur. Qo'llangan joylar: agent tuguni, ishlayotgan asbob doirasi, «Ishlayapti…» natija tuguni, Jarayondagi bajarilayotgan bosqich, «Bugun»dagi «Hozir» kartasi.
- «Harakatni kamaytirish» yoqilgan bo'lsa — tinch rangli chegara.
- Eski yonib-o'chuvchi (PulseStroke) chegara olib tashlandi.

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
