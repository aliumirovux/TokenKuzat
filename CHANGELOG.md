# O'zgarishlar

## 6.17.0 — 2026-10-28

- Qadam bajarilishi (n8n'dagi node kabi): xaritada qadamni bosing — o'ng panelda uch tab. **Chiqish** — asbob nima qaytardi (xato bo'lsa — qizil), natija kontekstga qancha token qo'shgani; **Kirish** — asbobga berilgan parametrlar (o'qiladigan JSON); **Tafsilot** — asbob, nishon, boshlanish vaqti, davomiylik, agent va kontekstga qo'shilgan token. Matnni tanlab yoki «Nusxa olish» bilan olish mumkin. Ishlayotgan qadamda sukut bo'yicha Kirish ochiladi.
- Asbob ro'yxati va «Jarayon» lentasidagi qadamlar ham bosiladi — o'sha tafsilot ochiladi.
- Saqlanadi: kirish 1 200, chiqish 1 500 belgigacha, sessiyaning oxirgi 200 ta qadami uchun (xotira o'smasin); undan eskilarida faqat vaqt va holat.

## 6.16.0 — 2026-10-28

- Limitning chat va bulutga ketgan qismi: claude.ai va desktop chatlar, bulutdagi sessiyalar Mac diskiga yozilmaydi, lekin hisobdagi haqiqiy 5 soatlik foizga kiradi. Har limit o'lchovida foiz o'sishi shu oraliqdagi Mac sarfi bilan solishtiriladi: Mac ishlamagan paytdagi o'sish — chat va bulut; aralash paytda Mac ulushi o'rganilgan «1% ≈ N vaznli token» koeffitsiyenti bilan ayriladi (Mac ishlagan oraliqlardan, 75-persentil). Koeffitsiyent 3 ta o'lchovdan keyin chiqadi, ungacha aralash qism «Aniqlanmoqda».
- «Umumiy»dagi limit blokida — «Sessiya limiti qayerga ketdi»: Mac'da / Chat va bulut / Aniqlanmoqda / Kuzatuvdan oldin chizig'i va bugun chat va bulutga ketgan taxminiy vaznli token. Menyu panelida — ixcham chiziq.
- Soatlik ustunlar izohi koeffitsiyent bo'lsa faqat Mac ulushini ko'rsatadi (avval chat ham Mac soatlariga taqsimlanardi).
- MCP `usage_summary` — `chat_and_cloud` bo'limi.
- Holat `~/Library/Application Support/TokenKuzat/outside-usage.json` da (7 kun); «Tarixni tozalash» uni ham o'chiradi. Ishlashi uchun Sozlamalar → «Claude hisobidan olish» yoqilgan bo'lishi kerak.

## 6.15.0 — 2026-10-28

- Claude Code plagini: `/plugin install tokenkuzat --marketplace aliumirovux/TokenKuzat`, keyin `/tokenkuzat:install` — Claude talablarni (macOS 13+, Command Line Tools) tekshiradi, ilovani yig'ib o'rnatadi va keyingi qadamlarni tushuntiradi.
- MCP server (`TokenKuzat --mcp`, plagin bilan avtomatik ulanadi): `usage_summary` — bugungi va 5 soatlik sarf, tezlik, limitlar, ishlayotgan va ruxsat kutayotgan sessiyalar; `list_sessions` — so'nggi sessiyalar; `session_details` — so'rovlar, agentlar, katta asbob natijalari. Faqat o'qiydi, tarixga yozmaydi.

## 6.14.0 — 2026-10-28

- Yangi «Jonli» bo'limi (⌘2): bir vaqtda ishlayotgan barcha sessiyalar bitta sahifada. Chap menyudagi ishlayotganlar soni shu qatorga ko'chdi; «Sessiyalar» — ⌘3, «Tarix» — ⌘4.
- «Kartalar»: har sessiya alohida kartada — holat (ishlayapti / ruxsat kutyapti / tugadi), joriy so'rov, hozirgi ish, barcha agentlarning oxirgi 4 qadami, yordamchi agentlar, kontekst, davomiylik va tokenlar, robot. Ruxsat kutayotgani sariq va birinchi; tugaganlari 10 daqiqa qoladi. Kartani bosish — sessiya xaritasi.
- «Chiziqlar»: barcha sessiyalar umumiy vaqt o'qida (10 daq – 3 soat). Har sessiya — qator, ostida yordamchi agentlari; har qadam — davomiyligicha rangli chiziq, so'rov boshlari «#raqam» bilan, «hozir» chizig'i. Sichqoncha ustida — qadam tafsiloti, bosish — xarita.
- Zamonaviy segment tanlagich (`PillSegments`): urg'u rangidagi siljiydigan pill, belgilar bilan.

## 6.13.0 — 2026-10-28

- Xarita boshqaruvi bitta yaxlit panelda: masshtab | «Ergashyapti / Hozirgiga qaytish» | «Faqat shu so'rov». Pastda yengil fade — kartalar panel ostiga keskin kirib qolmaydi; ergashganda oxirgi qadam panel ustida to'xtaydi. «Hammasini sig'dirish» ham panel joyini hisobga oladi.
- Xaritani bo'sh joyga surib yuborib bo'lmaydi: chegara haqiqiy kontent (kartalar) bo'yicha. Baribir ekranda deyarli hech narsa qolmasa — markazda «Xarita bu yerda emas · Hozirgiga qaytish» tugmasi.
- Minixarita faqat kontentni ko'rsatadi (bo'sh joysiz), ixchamroq (160×96 gacha); ko'rinish ramkasi doim ichida.
- Sahifa sarlavhalari tepasidagi bo'sh joy qisqardi — nom chap menyudagi brend bilan bir qatorda.

## 6.12.2 — 2026-10-28

- «Faqat xarita» rejimida xarita oyna tepasigacha cho'ziladi (yuqoridagi bo'sh joy yo'q) — oyna tugmalari xarita burchagida turadi.

## 6.12.1 — 2026-10-28

- «Faqat xarita» tugmasi xaritaning yuqori o'ng burchagiga ko'chdi — faqat belgi (⤢; rejimda — ⤡, Esc). Masshtabni moslash tugmasi belgisi almashtirildi (viewfinder) — ikkisi chalkashmasin.

## 6.12.0 — 2026-10-28

- Ikkala yon panel bir uslubda. Chap menyu: tepadagi bo'sh joy olib tashlandi; nom ostida holat («2 sessiya ishlayapti» / «Tinch»); tanlangan qator urg'u rangida; ishlayotgan loyihada takroriy «hozir» yozuvi yo'q (avatar nuqtasi yetarli); limitlar «Claude limiti» sarlavhali ixcham kartada.
- Tafsilotlar paneli: xarita kartasi ichida emas — o'ngda, oyna tepasigacha cho'zilgan alohida panel (chap menyu bilan bir xil material), «Tafsilotlar» sarlavhasi va yopish tugmasi; yopiq paytda — oynaning yuqori o'ng burchagida ochish tugmasi (tablar qatoridagi kichik tugma olib tashlandi). Tor oynada — suzuvchi panel.
- Panel ichi ixchamroq: «Hozir» — bitta qator; tokenlar — bir qatorli ro'yxat, izohlar sichqoncha ustiga borganda; asbob belgilari chap menyudagidek oddiy; aylantirish chizig'i yashirin.

## 6.11.1 — 2026-10-28

- Yon menyuni ochish/yopish belgilari oyna tugmalari (qizil-sariq-yashil) bilan bir qatorda: yopiq paytda — tugmalarning o'ng yonida, sarlavha ustida osilib qolmaydi.

## 6.11.0 — 2026-10-28

- Yon menyuni ochib-yopish: menyuning yuqori o'ng burchagidagi tugma (yoki ⌃⌘S) yopadi; yopiq paytda oyna tugmalari yonida ochish tugmasi chiqadi. Holat eslab qolinadi; menyu chetidan tortib yopilsa ham.

## 6.10.0 — 2026-10-28

- Yangi yon menyu: ixcham brend qatori (ishlayotgan bo'lsa — jonli nuqta), bo'limlar yumshoq fon bilan tanlanadi (tanlanganda to'ldirilgan belgi), ⌘1/⌘2/⌘3 va ⌘, tugmalari; loyihalar — avatar burchagida jonli nuqta, o'ngda «hozir»/«5 daq»/«2 kun»; pastda ixcham 5 soatlik va haftalik limit chiziqlari (ustiga borsa — tiklanish vaqti).
- Bosh sahifa tor oynada kesilmaydi: limit kartalari va «Bugun» kataklari sig'masa ustma-ust joylashadi; kontentning eng kichik kengligi 640 → 520 (yon menyu kontent ustiga chiqmaydi).
- Sessiya sarlavhasi: raqamlar doim o'ngda, belgilar sig'masa keyingi qatorga o'tadi (keng oynada sarlavha o'rtaga surilib qolgan xato tuzatildi).

## 6.9.1 — 2026-10-28

- Xaritadan chat (yozish maydoni) olib tashlandi — xarita faqat kuzatish uchun. «Faqat xarita» va boshqa tugmalar joyida.

## 6.9.0 — 2026-10-28

- «Faqat xarita» tugmasi (xarita pastida, ⇧⌘F): yon menyu, sessiya sarlavhasi, vaqt chizig'i, tablar va tafsilotlar paneli yashiriladi — oynada faqat xarita (yozish maydoni bilan). «Chiqish» yoki Esc — oddiy ko'rinish. Tanlov eslab qolinadi; boshqa sahifaga o'tilsa yon menyu qaytadi.

## 6.8.1 — 2026-10-28

- Sessiya sahifasidagi so'rovlar qatori («Butun sessiya», «#11 · …» chiplari) olib tashlandi — so'rov xaritadagi kartani bosib tanlanadi.

## 6.8.0 — 2026-10-28

- Tor oynaga moslashuv: sessiya sarlavhasidagi belgilar (holat, kontekst, tejash, so'rov, model, vaqt) siqilib harflari ustun bo'lib qolmaydi — sig'masa keyingi qatorga o'tadi; raqamlar (davomiylik, qadam, token) joy yetmasa pastga tushadi.
- Tafsilotlar paneli: keng oynada kengligi oynaga mos (300–384 pt); kontent 1000 pt dan tor bo'lsa — xaritani siqmaydi, o'ng tomondagi tugma bilan xarita ustida suzuvchi panel bo'lib ochiladi.
- Xaritada: tor bo'lsa minixarita yashiriladi, yozish maydoni boshqaruv tugmalari ustida butun kenglikda — bir-birini yopmaydi.
- `--snapshot-header fayl.png --width N`, `--snapshot-map … --width N --chat` (ishlab chiquvchi uchun).

## 6.7.0 — 2026-10-28

- Unumdorlik (oyna ochiq): o'lchovlar bo'yicha har bir animatsiya butun oynani qayta chizdirardi. Robot — 20 kadr/s (tinch holatda 8) va GPU'da; aylanuvchi chegaralar — 20 kadr/s; xaritadagi qimirlamaydigan chiziqlar endi har kadrda qayta chizilmaydi (jonli chiziqlar alohida qatlamda); tizim ProgressView'i o'rniga yengil «ishlayapti» belgisi (10 qadam/s, faqat o'zini chizadi); boshqa joyda ochiq sessiyani tekshirish — 20 s da bir. Claude ishlayotganda: ~61% → ~50%.
- Sozlamalar → «Yengil rejim»: robot, aylanuvchi chegaralar, oqim nuqtalari va holat pulsi to'xtaydi — oyna ochiq va Claude ishlayotganda ~20%.

## 6.6.0 — 2026-10-28

- Unumdorlik: katta oyna yopilganda uning ko'rinishlari to'liq yo'q qilinadi — avval xarita, robot va oqim animatsiyalari yashirin oynada ham chizilib, protsessorni ~50% band qilardi; endi menyu satrida turganda ~0–1%. Oyna butunlay boshqa oynalar ortida yoki Dock'da bo'lsa — ko'rinish ajratib qo'yiladi (chizish to'xtaydi, holat saqlanadi).
- Jonli kartalar atrofidagi aylanuvchi chegara GPU'da (drawingGroup) va 30 kadr/s da chiziladi — konus gradient protsessorda hisoblanmaydi.
- Xotira: 30 kunlik tarix oynasidan chiqqan sessiyalar har kuni xotiradan tozalanadi — ilova haftalab ochiq tursa ham o'smaydi (kunlik yig'indilar saqlanadi).

## 6.5.0 — 2026-10-28

- Xaritada «Natijalar» shoxi: so'rovda yaratilgan yoki ko'rilgan rasm, HTML, PDF, video bo'lsa — kartaning yuqori shoxlari qatorida (Terminal, Fayllar yonida) eng so'nggisining kichik rasmi va soni. Bosilsa — oynacha: tepada shu so'rov natijalari qatori, ostida katta ko'rinish (Quick Look), «Brauzerda ochish» va «Finder». Fayl qaysi so'rovga tegishli — oxirgi marta qaysi so'rov ichida yaratilgani yoki ochilgani bo'yicha.

## 6.4.0 — 2026-10-28

- «Natijalar» tabi: sessiyada Claude yaratgan yoki ko'rgan rasm, HTML (SVG), PDF va videolar — chapda kichik rasmli ro'yxat (turi, «Yaratildi»/«Ko'rildi», vaqti, tur bo'yicha filtr), o'ngda katta ko'rinish (Quick Look: HTML sahifa sifatida, PDF varaqlab). Fayl qayta yozilsa — ko'rinish o'zi yangilanadi. «Brauzerda ochish»/«Ochish» va «Finder» tugmalari.
- Manbalar: Write/Edit/Read qilingan fayllar va terminal buyruqlarida tilga olingan to'liq yo'llar (qo'shtirnoqdagi bo'shliqli yo'llar va buyruq ichidagi `SP=/yo'l … $SP/x.png` kabi o'zgaruvchilar ham). Diskda yo'q fayllar ko'rsatilmaydi.
- Testlar: 46 ta.

## 6.3.0 — 2026-10-28

- Xaritadan chat: pastdagi maydonga yozib Enter bosing — xabar shu sessiyaga ketadi (`claude -p --resume`, avto ruxsat rejimi, sessiyadagi model oilasi). Javob, qadamlar va robot xaritada jonli paydo bo'ladi. Ish ketayotganda «To'xtatish» (Ctrl-C kabi, sessiya saqlanadi). Claude boshqa joyda ishlayotganda maydon yopiq; sessiya Claude ilovasi yoki terminalda ochiq bo'lsa — ogohlantirish (u yerda xabarlar qayta ochilgandagina ko'rinadi). ⌥Enter — yangi qator. Replay'da o'chiq.

## 6.2.0 — 2026-10-28

- Xaritada «Faqat shu so'rov» tugmasi: hozir ishlayotgan (yoki tepada tanlangan) so'rov kartasi, uning qadamlari, asboblari va robot qoladi — qolgan so'rovlar yashiriladi. Karta oyna markazida; yangi so'rov kelsa, xarita unga o'tadi. Tanlov eslab qolinadi; «Hammasini ko'rsatish» — qaytarish.

## 6.1.0 — 2026-10-28

- «Yangi sessiyada davom ettirish»: bitta tugma — xulosa saqlanadi va keyingi 2 soat ichida ochilgan yangi Claude Code sessiyasi uni avtomatik oladi (SessionStart hook, additionalContext). Hech narsa nusxalab qo'yish shart emas; zaxira uchun nusxaga ham olinadi. Xulosa bir marta beriladi; `resume`, `/compact`, boshqa loyiha papkasi va eski sessiyaning o'ziga berilmaydi. Hook xulosa yo'q paytda hech narsa ishga tushirmaydi. Sozlamalarda uzish mumkin.
- Kesh muddati endi aniqlanadi: Claude ilovasi sessiyalari 1 soatlik keshda ishlaydi (avval hamma joyda 5 daqiqa deb hisoblanardi — «kesh o'chdi» ogohlantirishi va taymer noto'g'ri edi).
- Yangi maslahat «Katta natijalar»: 5K tokendan katta har bir asbob natijasi keyingi nechta chaqiruvda qayta o'qilgani (/compact gacha) — eng qimmatlari bir xil asbob bo'yicha guruhlab ko'rsatiladi.
- Yangi maslahat «Og'ir boshlanish»: sessiya ish boshlanmasdan 80K+ kontekst bilan ochilgan bo'lsa (konnektorlar, pluginlar, skill'lar) — qancha ekanini va bu sessiyada qaysi tashqi xizmatlar ishlatilganini ko'rsatadi.
- «Katta kontekst» tejash hisobi endi sessiyaning haqiqiy boshlang'ich kontekstidan olinadi (taxminiy 40K o'rniga).
- Testlar: 42 ta.

## 6.0.0 — 2026-10-28

- Tokenni tejash (model va sifat o'zgarmaydi — Opus to'liq quvvatda): har sessiya uchun tahlil — katta kontekst (har javobda qancha tejalishi), 5 daqiqalik tanaffusdan keyin kesh qayta yozilishi, o'zgarmagan faylni takroriy o'qish, ko'p skrinshot, ketma-ket xatolar; har birida aniq maslahat va taxminiy token.
- «Davom etish xulosasi»: so'nggi vazifalar, o'zgartirilgan fayllar va oxirgi holat bitta tugma bilan nusxaga olinadi — yangi sessiyaga qo'yiladi, Claude kontekstni yo'qotmay kichik kontekst bilan davom etadi.
- Ko'rinish: sessiya sarlavhasida «Tejash» belgisi (bosilsa — to'liq ro'yxat, kesh saqlanish taymeri, nusxalash), «Bugun» sahifasida asosiy maslahat kartasi.
- Bildirishnoma: kontekst 300K+ bo'lganda yangi mavzu (10 daqiqadan uzoq tanaffusdan keyingi so'rov) boshlansa — yangi sessiya taklifi (Sozlamalarda o'chirish mumkin).
- Hisob limiti: Anthropic «so'rov juda ko'p» (429) desa — kutadi (Retry-After yoki 2→15 daqiqa), oxirgi raqamlar ko'rsatilib turadi; so'rovlar oralig'i 90 s; oxirgi javob diskda saqlanadi (faqat foizlar va vaqtlar) — ilova qayta ochilganda darhol ko'rinadi.
- 5 soatlik oyna tugab yangisi boshlanmagan paytda limit bloki yo'qolmaydi: «0% · birinchi so'rov bilan boshlanadi».
- Testlar: 33 ta.

## 5.12.0 — 2026-10-28

- Xaritada nazoratchi robot: ish ketayotganda faol so'rov kartasining chap-yuqori burchagida o'tirib, vazifaga mos harakat qiladi (Xulosa'dagi bilan bir xil holatlar). Tinch paytda zeriktirmaydi: oxirgi 5 karta bo'ylab borib-qaytib uchadi va durbin bilan «nazorat qiladi», goh-goh mudraydi. Bosilsa — sakrab, qo'l silkitib «salom!» deydi.
- Robot holatini aniqlash bitta joyda (`RobotView.action(for:)`): bajarilayotgan qadam turi, xato, yangi so'rov, javob, o'ylash, tugash, uyqu, ruxsat kutish.
- Yangi holatlar: «nazorat qilyapman» (durbin) va «salom!».

## 5.11.1 — 2026-10-28

- Robot ko'rinishi sayqallandi: gap pufagi — robotga qaragan dum, holat belgisi, matn va sakrovchi uch nuqta (davom etayotgan ishda), holat rangida yengil fon va soya. Robot: gradientli qobiq va yaltiroq, yorug' sharli antenna, ko'zlarda nur, xursandlikda qizargan yonoqlar, ko'krakda kichik ekran, kaftli qo'llar, sakrash va tebranishga mos yerdagi soya.

## 5.11.0 — 2026-10-28

- Robot xarakterli: har vazifada o'z harakati, qo'lidagi buyumi va yuz ifodasi — Terminal (noutbukda yozadi, diqqat bilan), fayl o'qish (lupa, ko'zlari qatorlar bo'ylab), fayl yozish (qalam, jilmayib), Internet (aylanuvchi globus, radio to'lqinlar), tashqi xizmat (vilka va uchqun), yordamchi agent (kichik robotga topshiradi), boshqa asbob (kalit). Agent ustida: o'ylayapti (lampochka, iyagiga qo'l), javob yozyapti (gapiradi), ruxsat kutyapti (qo'l ko'tarib «?»), xato (titraydi, «× ×», ter tomchisi), yangi vazifa (qo'l silkitib «!»), tayyor (sakraydi, yulduzchalar, «^ ^»), uxlash («z z»).
- Holat haqiqiy ishdan aniqlanadi: bajarilayotgan qadam turi va o'qish/yozish, so'nggi xato, so'rov boshlangani, ish tugagani.
- `--snapshot-robots fayl.png` — barcha holatlar bitta rasmda (ishlab chiquvchi uchun).

## 5.10.0 — 2026-10-28

- Xulosa oqimida robot-yordamchi: asbob ishlayotganda o'sha tugun ustiga uchib boradi va «ishlaydi» (qo'llar harakatda, antenna yonadi, «Terminal…»), model o'ylayotganda agent kartasi ustida ko'zlari u yoq-bu yoqqa yuradi («o'ylayapti…»), tugaganda uxlaydi («z z»). Ko'z qisish, yengil tebranish, tugundan tugunga silliq uchish; «Harakatni kamaytirish»da animatsiyasiz.
- Hisob kaliti xotirada saqlanadi — Keychain faqat birinchi marta yoki kalit muddati tugaganda o'qiladi.
- build.sh: «Apple Development» sertifikati bo'lsa — u bilan imzolaydi (yangi build'larda Keychain ruxsati qayta so'ralmaydi); `TK_SIGN_IDENTITY` bilan boshqasini tanlash mumkin.

## 5.9.0 — 2026-10-28

- «Bugun» sahifasida limit — asosiy narsa: ikki katta karta «Joriy sessiya» va «Bu hafta» — katta halqa va foiz («ishlatildi»), tiklanish vaqti, qancha qolgani; kartaning ichida ixcham ustunlar (sessiyada soatlar, haftada 7 kun bo'yicha). Katta soatlik chizma va past kontrastli yozuvlar olib tashlandi; bashorat sarlavha qatorida.

## 5.8.0 — 2026-10-28

- «Bugun» sahifasidagi limit bloki menyu paneli uslubida: chapda «Joriy sessiya» va «Bu hafta» halqalari (ikkalasi ham «ishlatildi», tiklanish vaqti va qancha qolgani), ostida bitta rangli xulosa. «53% qoldi» va «47% ishlatildi» aralashmasi yo'qoldi.
- O'ngdagi chizma aniq nomlandi: «Joriy sessiya oynasi: har soatda limitdan qancha ketdi» — har ustunda «+15%» va shu soatdagi token, hozirgi soatda «HOZIR», kelajakdagilari «hali kelmagan».

## 5.7.0 — 2026-10-28

- Menyu paneli qayta chizildi, ortiqcha va qarama-qarshi raqamlarsiz:
  - Tepada «Claude · Max (5x)» va jonli tezlik; ikki halqa — Sessiya va Hafta, ikkalasi ham «ishlatildi» (Claude sahifasidagidek), yonida tiklanish vaqti va qancha qolgani; ostida bitta rangli xulosa: «Sur'at me'yorida» yoki «Shu sur'atda juma ertalab tugaydi». Nomsiz 5 ustun va «qoldi»/«ishlatildi» aralashmasi olib tashlandi.
  - «Hozir» kartasi: holat sarlavhada («HOZIR ISHLAYAPTI» / «RUXSATINGIZNI KUTYAPTI»), joriy harakat katta harfda (Terminal + nima qilyapti + taymer), jarayon izi yo'lak nomlari bilan (Mahalliy / Model / Tashqi).
  - Bugungi xulosa — bitta ixcham qator.
  - Panel tepasidagi oq chiziq yo'qoldi.

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
