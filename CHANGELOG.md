# O'zgarishlar

## 6.59.0 — 2026-10-30

- Ilova o'zini o'zi yangilaydi: yangi versiya chiqsa, menyu panelida va Sozlamalarda «Yangilash» tugmasi chiqadi. Bosilsa, ilova DMG'ni GitHub'dan yuklaydi, relizdagi SHA-256 bilan tekshiradi, ichidagi ilova shu ilova va shu versiya ekanini va imzosi butunligini tekshiradi, keyin o'zini almashtirib qayta ochiladi. Endi DMG ochish va Applications'ga sudrash shart emas. Almashtirish muvaffaqiyatsiz bo'lsa, eski ilova joyiga qaytariladi.
- Ilova papkasiga yozish ruxsati bo'lmasa yoki ilova DMG'dan ochilgan bo'lsa, avvalgidek «Yuklab olish» chiqadi. Yangilashda xato bo'lsa, Sozlamalarda sababi va «DMG'ni yuklab olish» havolasi ko'rinadi.
- Relizlar bitta buyruq bilan chiqadi: `bash scripts/publish.sh` (testlar, DMG, teg va GitHub relizi; o'zgarishlar CHANGELOG'dan).

## 6.58.4 — 2026-10-30

- Ish yangi sessiyaga ko'chirilgandan keyin eski sessiyada davom etilsa, kontekst yana 30K o'sishi bilan qayta ko'chiriladi (avval 100K kutilardi). Keyingi xabar yana yangi sessiyaga yo'naltiriladi — katta suhbat uzoq vaqt limitni yemaydi.

## 6.58.3 — 2026-10-30

- Menyu panelidagi loyihalar ro'yxati ham vaqtinchalik papkalarni (/tmp, ilovaning papkasiz sessiyalari) ko'rsatmaydi — chap paneldagi «So'nggi» bilan bir xil.

## 6.58.2 — 2026-10-30

- «Loyihalar» sahifasida loyihaning ichki papkasi (masalan, `ytbot/design`) alohida karta bo'lib chiqmaydi: undagi sessiyalar ota loyiha kartasiga qo'shiladi. Faqat bitta git loyihasi ichida; git'siz papkalar avvalgidek alohida.

## 6.58.1 — 2026-10-30

- Loyiha kartasidagi ish nomi eskirib qolmaydi: sessiya yangisiga ko'chgach unda yangi mavzu boshlansa, eski nom o'rniga shu mavzu ko'rsatiladi.
- Loyiha nomi takrorlanmaydi («ytbot — ytbot — …» o'rniga «ytbot — …»).
- Chap paneldagi ro'yxat «So'nggi» deb nomlandi va vaqtinchalik papkalarni (/tmp, ilovaning papkasiz sessiyalari) ko'rsatmaydi.
- Avtomatik davom loyihaning ichki papkasida ham ishlaydi (masalan, `ytbot/src` da ochilgan `claude` — `ytbot` xulosasini oladi; faqat bitta git loyihasi ichida).

## 6.58.0 — 2026-10-30

- Yangi «Loyihalar» sahifasi (⌘7): har loyiha (papka) — bitta karta. Unda oxirgi ish, qachon va qayerda (Terminal yoki Claude ilovasi) ishlangani, qolgan ish, javobsiz savol va git'da saqlanmagan yoki yuborilmagan o'zgarishlar ko'rinadi. Javobingizni kutayotgan loyiha ajralib turadi. Hammasi sessiya yozuvlari va git'dan olinadi — Claude'ga token sarflanmaydi.
- «Davom ettirish» tugmasi: shu papkada yangi Terminal sessiyasi xulosa bilan ochiladi, Claude 2–3 jumlada qayerda qolganini aytib, javobingizni kutadi.
- Avtomatik davom: Terminal oynasi yopilgan yoki tashlab ketilgan bo'lsa (24 soat ichida), shu papkada ochilgan keyingi yangi `claude` oldingi sessiya xulosasini o'zi oladi va qayerda qolganini birinchi javobda aytadi. Har loyiha o'z papkasi bo'yicha — loyihalar aralashmaydi. Boshqa mavzuda boshlasangiz, Claude xulosani e'tiborsiz qoldiradi. Sozlamalar → «Yopilgan sessiyani avtomatik davom ettirish» (standart — yoqilgan).
- Menyu panelida «Chala qolgan» loyihalar (javob kutilayotgan yoki saqlanmagan ish bor) qisqa ko'rinadi.

## 6.57.0 — 2026-10-30

- Ish yangi Terminal sessiyasiga ko'chgach (kontekst to'lganda, eski sessiyada yozilgan xabar yo'naltirilganda yoki limit tugab bepul modelga o'tilganda), eski sessiyaning Terminal oynasi o'zi yopiladi: yangi sessiya ishga tushgach, eski `claude` to'xtatiladi va oynasi yopiladi. Ekran eski oynalar bilan to'lmaydi. Suhbat saqlanadi — `claude --resume` bilan qaytariladi.
- Faqat Terminal ilovasida ishlaydi: eski sessiya iTerm, VS Code yoki Claude ilovasida bo'lsa, hech narsa to'xtatilmaydi. Oynada bir nechta tab bo'lsa, faqat shu tab yopiladi. Sessiya qaysi oynada ekanini status line yozib boradi, shuning uchun u ulangan bo'lishi kerak.
- Sozlamalar → avtomatik ko'chirish: «Ko'chirilgandan keyin eski Terminal oynasini yopish» (standart — yoqilgan).

## 6.56.0 — 2026-10-30

- `ask_free_model`: bepul model javobini kutayotganda (120 soniyagacha) boshqa MCP so'rovlari endi navbatda turmaydi. Server xato matnida kalitni qaytarsa, u yashiriladi va Claude'ga tushmaydi. MCP xato matnlari inglizcha.
- Sozlamalarda ikki xil «Claude Code'ga ulash» tugmasi endi nomi bilan ajraladi: «Limitlarni ulash» (status line — haqiqiy limit foizi) va «Ruxsat xabarini ulash» (ruxsat kutish ogohlantirishi).
- 5 soatlik limit kartasida «har 5 soatda yangilanadi» o'rniga «birinchi xabardan 5 soat o'tib yangilanadi».
- «Bepul modellar» bo'limidagi eski xato yozuvi qayta urinishda yoki sozlama o'chirilganda tozalanadi.
- Terminal'da yangi sessiya ochilganda faqat meros qolgan `CLAUDE_*` o'zgaruvchilari tozalanadi; profil faylingizdagi `CLAUDE_CONFIG_DIR`, `CLAUDE_CODE_*` kabi sozlamalar saqlanib qoladi.
- Juda uzun sessiyada «kontekst ~X dan boshlanadi» va tejash hisobi endi sessiyaning haqiqiy boshidan olinadi.

## 6.55.0 — 2026-10-30

- Eski sessiyadan yo'naltirishda yangi sessiya Claude ilovasida ochilsa, «xabaringiz yozib qo'yildi — u yerda Enter bosing» deyiladi (Terminal'da — «yuborildi», chunki u yerda xabar o'zi ketadi).
- Kontekst oynasi (200K yoki 1M) endi taxmin qilinmaydi — Claude Code status line'idan olinadi. 1M modelda 170K da «kontekst 85% to'ldi» degan noto'g'ri ogohlantirish chiqmaydi.
- «Claude'da davom etish» faqat limit tugaganidan keyin bepul modelda ishlangan sessiyani oladi. Bunday sessiya bo'lmasa, sababi bildirishnomada aytiladi.
- «Limit tugadi» bildirishnomasi o'chiq bo'lsa ham, limit xatosi haqida xabar va bepul model taklifi chiqadi.
- Sozlamalar: tanlovda qisqartirish oynasidan past chegara bo'lmasa, `autoCompactWindow` ni oshirish yoki olib tashlash maslahat qilinadi. Limit «har 1,5 daqiqada» olinadi deb to'g'ri yozildi. Limit maydoniga 0 yoki manfiy son kiritib bo'lmaydi.
- «Yangi mavzu» bildirishnomasi va maslahat endi mavjud «Yangi sessiyada davom ettirish» tugmasini ko'rsatadi.
- Inglizcha rejimda narx «$1.23» ko'rinishida chiqadi. Yangi sessiyaga beriladigan xulosa ko'rsatmasi suhbat tilida, MCP tavsifi inglizcha.

## 6.54.0 — 2026-10-30

- Avtomatik ko'chirish endi faqat Claude javobini haqiqatan tugatganda yangi sessiya ochadi. Uzoq buyruq, uzoq o'ylash yoki javob kutilayotgan savol paytida ochilmaydi.
- Terminal'ga ko'chirishda har ochilish o'z faylini oladi va ishga tushgach uni o'chiradi: ketma-ket ikki ko'chirish bir-birining xabarini bosib ketmaydi. `claude` topilmasa, Terminal sababini yozadi.
- MCP `savings_report`: so'ralgan loyiha topilmasa, «tuzatildi» sanasi boshqa loyihaga yozilmaydi va Claude buni javobdan ko'radi.
- MCP `session_details`: noto'g'ri id yoki loyiha berilsa, boshqa sessiya o'rniga aniq xato qaytadi.
- Loyihalar tejami: «Claude'ga topshirish» endi faqat topshiriqni nusxalaydi. «Tuzatildi» sanasi «Qo'llandi deb belgilash» tugmasi bilan yoki Claude o'zgarishlarni qo'llagach MCP orqali qo'yiladi (bu qadam topshiriqqa qo'shildi).
- Haftalik limit ham tugagan bo'lsa, 5 soatlik limit tiklanganda «yana ishlashingiz mumkin» degan xabar chiqmaydi — faqat haftalik limit haqida aytiladi.

## 6.53.0 — 2026-10-30

- FreeLLMAPI Mac ilovasi yopiq bo'lsa, Token Kuzatuv uni o'zi orqa fonda ochadi: ilova ishga tushganda (kompyuter qayta yoqilgandan keyin ham), `ask_free_model` serverga ulana olmaganda (ochib, bir marta qayta uradi), ish bepul modelga ko'chayotganda va Sozlamalardagi tekshiruvda. Faqat manzil shu Mac'da bo'lsa (localhost, 127.0.0.1) va ilova o'rnatilgan bo'lsa ishlaydi; boshqa kompyuterdagi server ochilmaydi.

## 6.52.1 — 2026-10-30

- `ask_free_model` tuzatildi: o'ylaydigan bepul model (masalan, gpt-oss) javob uzunligi chegarasini o'ylashga sarflab qo'ysa, endi uning o'ylash matni javob sifatida qaytmaydi — «max_tokens ni oshiring» degan aniq xato chiqadi. Javob chegarada uzilsa, oxirida «javob to'liq emas» deb yoziladi.
- Bepul modellar manzili endi standart bo'yicha FreeLLMAPI Mac ilovasiniki — `http://127.0.0.1:31415` (server versiyasi — `http://localhost:3001`). Sozlamalardagi izoh yangilandi: Docker shart emas, kalit «Unified API key» bo'limidan olinadi, Claude Code uchun katta kontekstli va asboblarni chaqira oladigan model kerak (masalan, Gemini) — faqat Groq kaliti yetmaydi.

## 6.52.0 — 2026-10-29

- Bepul modellar (FreeLLMAPI — bepul tariflarni bitta manzilga yig'adigan, o'zingiz o'rnatadigan server). Sozlamalarda yangi «Bepul modellar» bo'limi: manzil va umumiy kalit kiritiladi, ilova serverni tekshiradi va nechta model borligini ko'rsatadi.
- Claude limiti tugaganda bildirishnomada «Bepul modelda davom etish» tugmasi chiqadi. Bosilsa, Terminal'da Claude Code bepul modelda ochiladi va oxirgi sessiya xulosasi birinchi xabar bo'lib beriladi. Bepul modelga katta o'zgarish, commit yoki push qilishdan oldin so'rash aytiladi. Limit tiklanganda «Claude'da davom etish» tugmasi bepul modeldagi ishni xulosa bilan Claude'ga qaytaradi; Claude avval bepul model nima o'zgartirganini tekshiradi. Claude ilovasidagi sessiyalar Claude'da qoladi.
- Claude'ga yangi MCP asbobi — `ask_free_model`: tarjima, uzun logni qisqartirish kabi mayda, mustaqil ishlarni bepul modelga beradi va Claude limitini tejaydi. Javob oxirida qaysi model javob bergani yoziladi. Asbob faqat bepul modellar sozlangan bo'lsa ko'rinadi.
- Bepul model sarfi Claude limitiga qo'shilmaydi: bugungi va 5 soatlik hisobda yo'q, sessiyada model nomi «· bepul model» belgisi bilan ko'rinadi. Bunday sessiyalar avtomatik yangi sessiyaga ko'chirilmaydi.
- Kalit faqat shu Mac'da, faqat sizga ochiq faylda saqlanadi va faqat kiritilgan manzilga yuboriladi; terminal skriptiga yozilmaydi.

## 6.51.0 — 2026-10-29

- Sozlamalarda ogohlantirish: Claude Code suhbatni ko'chirish chegarasidan oldin o'zi qisqartiradigan qilib sozlangan bo'lsa, avtomatik ko'chirish bo'limida sariq yozuv chiqadi — «Claude Code suhbatni 150K da o'zi qisqartiradi (autoCompactWindow) — bu ko'chirish chegarasidan (200K) kichik». Ilova bunday qisqartirishni bir marta to'xtatadi, lekin har doim ishonchli bo'lishi uchun chegarani pastroq tanlash tavsiya qilinadi. `~/.claude/settings.json` dagi `autoCompactWindow`, model bo'yicha `modelSettings.<model>.autoCompactWindow` va `CLAUDE_CODE_AUTO_COMPACT_WINDOW` o'qiladi, eng kichigi olinadi; «auto» qiymati aniq son bo'lmagani uchun hisobga olinmaydi.

## 6.50.0 — 2026-10-29

- Yordamchi agent ishini tugatganda bildirishnoma: «TokenKuzat: yordamchi agent tugatdi — Explore · 3 daq · 24 qadam · 120K token. Natija asosiy agentga qaytdi.» Xabar asosiy agent hali ishlayotgan paytda chiqadi (masalan, fonda ishlagan yordamchi). Butun sessiya tugasa, odatdagi «Claude tugatdi» xabari yetadi. Ma'lumot transkriptdan olinadi, shuning uchun Claude ilovasidagi sessiyalarda ham ishlaydi. «Claude tugatdi» sozlamasi bilan birga yoqiladi va o'chiriladi, qisqa ishlar (sozlamadagi chegaradan qisqa) uchun chiqmaydi.

## 6.49.0 — 2026-10-29

- «Og'ir boshlanish» maslahati endi aniq fayllarni ko'rsatadi: qaysi `CLAUDE.md` va `.claude/rules/` fayli sessiyaga yuklangani va qancha joy olgani («Ko'rsatma fayllari (10K): rules/swift.md 9K, ~/.claude/CLAUDE.md 1K»). Ma'lumot Claude Code'ning «InstructionsLoaded» hook'idan keladi: fayl sessiya boshida, ichki papkaga kirilganda yoki qoida mos kelganda yuklansa, ilova uni hajmi bilan yozib qo'yadi. Hook bildirishnoma hook'i bilan birga ulanadi, eski versiyadan yangilanganda ilova uni o'zi qo'shadi.

## 6.48.1 — 2026-10-29

- Ko'chirish eslatmasi endi Claude ilovasida ko'rinmaydi. Avval u `<!-- … -->` izohi bo'lib yozilardi, Claude ilovasi esa uni yashirmay, javob oxirida chalkash matn qilib ko'rsatardi. Endi har qatori Markdown havola ta'rifi (`[tk-handoff]: <…>`), Markdown uni chizmaydi. Eski formatdagi eslatmalar ham o'qiladi.

## 6.48.0 — 2026-10-29

- Yangi sessiya oldingi suhbatdan hech narsani yo'qotmaydi. Xulosaga sig'maydigan narsalar uchun (ancha oldin muhokama qilingan jadval, taklif yoki qaror) xulosaning boshida oldingi sessiya yozuvi (.jsonl) yo'li beriladi. Foydalanuvchi xulosada yo'q narsani eslasa, Claude faylni butunlay o'qimaydi, grep bilan kerakli joyini topadi, shuning uchun kontekst kichik qoladi. Sessiya bir necha marta ko'chirilgan bo'lsa, oldingi yozuvlar ham olib o'tiladi (4 tagacha).
- Claude'ning ko'chirish eslatmasida yangi «Ochiq takliflar» qatori: butun suhbatda muhokama qilingan, lekin hali qilinmagan takliflar va rejalar. Avval eslatma faqat hozirgi ishni yozardi va oldinroq kelishilgan rejalar yangi sessiyaga yetib bormasdi.

## 6.47.1 — 2026-10-29

- Xaritadagi qisqartirish kartasi oldindan tayyorlangan xulosada ham ishlaydi. Claude Code endi xulosani qisqartirishdan ancha oldin tayyorlab qo'yishi mumkin. Shunda xulosa qatori ertaroq vaqt bilan yoziladi va karta «Kontekst yangilandi» deb qolib ketardi. Endi xulosa so'rovi transkriptda o'zidan oldin turgan qisqartirish vaqtini oladi: karta «Avtomatik qisqartirildi» deb yozadi va Xaritada to'g'ri joyda turadi. O'sha oraliqdagi qadamlar ham oldingi so'rovga tegishli bo'lib qoladi.

## 6.47.0 — 2026-10-29

- Xaritada qisqartirish aniq ko'rinadi: Claude Code suhbatni qisqartirgan joyda karta «Avtomatik qisqartirildi» yoki «/compact bilan qisqartirildi» deb yozadi va kontekst qanchadan qanchaga tushganini ko'rsatadi («Kontekst 968K → 36K»). Bo'lim yorlig'i — «Qisqartirildi». Ma'lumot transkriptdagi «compact_boundary» qatoridan olinadi, shuning uchun Claude ilovasidagi sessiyalarda ham ishlaydi.
- Avtomatik qisqartirish va avtomatik yangi sessiya endi to'qnashmaydi. Avvallari Claude Code kontekstni ko'chirish chegarasidan oldin qisqartirib qo'ysa, ko'chirish hech qachon ishlamasdi. Endi «PreCompact» hook'i hali ko'chirilmagan katta sessiyada avtomatik qisqartirishni bir marta to'xtatadi, javob tugagach esa ish xulosa bilan yangi sessiyaga ko'chiriladi (bildirishnomada sababi yoziladi). Xavfsizlik uchun `/compact`, jim turgan sessiyani qisqartirish va ikkinchi urinish to'xtatilmaydi, ilova yopiq bo'lsa ham to'xtatilmaydi. Hook kerak bo'lganda o'zi ulanadi va avtomatik ko'chirish o'chirilsa olib tashlanadi.

## 6.46.0 — 2026-10-29

- Tejash sahifasidagi «Kesh» sababi endi transkriptdagi haqiqiy raqamlardan: tanaffus o'sha paytdagi kesh muddatidan (5 daqiqa yoki 1 soat) uzun bo'lgan va keyingi chaqiruv eski kontekstni keshdan o'qiy olmay qayta yozgan holatlar sanaladi. `/compact` isrof hisoblanmaydi, faqat qayta yozilgan eski kontekst olinadi, narxi — yozish va o'qish narxi farqi (1 soatlik kesh qimmatroq). «Bugun» / «7 kun» tanlansa, faqat shu davrdagi sovishlar. Izohda eng katta holat: «47 daq tanaffusdan keyin 330K qaytadan yozildi».
- Haftalik o'lchov: Tejash sahifasida «Kesh sovib qayta yozildi · 7 kun» kartasi — shu hafta qancha token va necha marta, oldingi 7 kun bilan farqi. Kunlik qiymatlar tarixga yoziladi, so'nggi 7 kun xotiradagi sessiyalardan to'ldiriladi.
- Claude limiti 100% ga yetsa — «limit tugadi, ertaga 01:50 da tiklanadi (3 soat 32 daq qoldi)» xabari, tiklanish paytiga esa oldindan rejalashtirilgan «limit tiklandi» xabari.
- Javob API xatosi bilan uzilsa (Claude Code «StopFailure» hook'i) — sessiya nomi bilan aniq xabar: limit (tiklanish vaqti bilan), serverlar band, hisobga qayta kirish, to'lov muammosi, juda uzun javob. Hook mavjud bildirishnoma hook'i bilan birga ulanadi; eski versiyadan yangilanganda ilova uni o'zi qo'shadi.

## 6.45.0 — 2026-10-29

- Kesh taymeri: menyu panelidagi «Hozir» kartasining pastki qatorida, Claude javob bergandan keyin promt keshi qancha vaqtdan keyin sovishi ko'rinadi («⏱ kesh 4:12»). Ogohlantirish vaqti kelganda sariq bo'ladi, sovigach «kesh sovigan» deb yozadi. Ustiga olib borilsa — sovigandan keyingi so'rov qancha kontekstni qayta yozishi va necha baravar qimmatligi chiqadi. Kesh muddati (5 daqiqa yoki 1 soat) transkriptdan olinadi, shuning uchun Claude ilovasidagi sessiyalarda ham ishlaydi.
- Kesh sovishidan oldin bildirishnoma: 5 daqiqalik keshda 1 daqiqa, 1 soatlikda 5 daqiqa oldin. Xabar oldindan rejalashtiriladi, shuning uchun ilova jim turganda ham o'z vaqtida chiqadi; yozsangiz bekor bo'ladi. Yangi sessiyaga ko'chirilgan eski sessiyalar uchun chiqmaydi. Sozlamalarda «Kesh sovishidan oldin…» bilan o'chiriladi.
- Kartaning pastki qatorida kontekst endi faqat foiz bilan ko'rsatiladi (izohi tooltipda), kesh va kontekst yozuvlari kesilmaydi.

## 6.44.0 — 2026-10-29

- Avtomatik yangi sessiya: kontekst chegaraga yaqinlashganda (chegaradan 15%, kamida 20K oldin) Claude javobining oxiriga ko'rinmaydigan ko'chirish eslatmasini yozadi — ish, nima bajarilgani, nima qolgani, kutilayotgan qaror va muhim jihatlar. Yangi sessiya xulosasi shu eslatmadan boshlanadi, sessiya nomi ham undagi «Ish:» qatoridan olinadi. Eslatma bo'lmasa, avvalgi xulosa ishlaydi. Eslatma so'raladigan sessiya bo'lmasa, hook ilovani umuman ishga tushirmaydi.
- «Eski sessiyada yozsam — yo'naltirish» o'chirilsa, faqat yo'naltirish to'xtaydi; hook avtomatik ko'chirish o'chirilganda olib tashlanadi.
- Yangi sessiyaning birinchi xabari «↪ Loyiha — ish» bilan boshlanadi, shuning uchun Claude ilovasi sessiyani shu nom bilan ataydi. Vaqtinchalik papkada ishlagan sessiya fayl yozgan git loyihasida ochiladi.
- Xulosa muhimini saqlaydi: javobning oxiri jumla chegarasida, foydalanuvchidan kutilayotgan savol alohida qatorda, oxirgi ikki so'rov to'liq. Avvalgi ko'chirish xabarlari, yalang'och havolalar va qisqa javoblar vazifalar ro'yxatiga kirmaydi; scratchpad va /tmp fayllari o'zgargan fayllar ro'yxatida chiqmaydi.

## 6.43.0 — 2026-10-29

- Claude Code plagini endi «Ofis» panelini beradi: chat yonida shu sessiyaning agenti va yordamchi agentlari robot bo'lib ishlaydi. Asbob ishlatayotgan robot monitorida belgi chiqadi (`>_` Bash, `✎` Edit, `⌕` Grep…), o'ylayotganining boshi ustida «…», ruxsat kutayotgani turib qo'l silkitadi (stol atrofi sariq, dron nur tushiradi), xatoda ko'zlari «x x» bo'ladi, bo'shi divanda qahva ichadi, 5 daqiqadan keyin uxlaydi («z z»).
- Yordamchi agent ishga tushsa, bo'sh stolga yangi rangli robot o'tiradi; asosiy agentdan unga vazifa kartasi uchib boradi, ish tugaganda «✓» kartasi qaytadi. Stollar 6 ta, bo'sh stol o'rnida gulzor.
- Panel sessiya boshida o'zi ochiladi, yopilsa — `/ofis`. Panel tepasida qisqa xulosa («2 ta robot ishlayapti»), pastida robotlar ro'yxati. Terminalda rasm o'rniga faqat ro'yxat chiqadi. Panel uchun Mac ilovasi shart emas.

## 6.42.1 — 2026-10-29

- Ilova ochilganda butun oyna bir daqiqagacha qotib qolishi tuzatildi. Avtomatik yangi sessiya xulosasi git holatini (`git log`, `git status`) o'qiydi — bu endi fonda bajariladi, oyna esa darhol javob beradi va loyihalar ro'yxati chiqadi. Sekin yoki osilib qolgan git 3 soniyadan keyin to'xtatiladi; bunday holda xulosa git qatorlarisiz yoziladi. «Yangi sessiyada davom ettirish» tugmasi ham endi oynani ushlab turmaydi.

## 6.42.0 — 2026-10-29

- Yangi «Ofis» sahifasi (⌘6): loyihalar — xona, agentlar — robot bo'lib ishlaydigan 3D bino. Har bir harakat haqiqiy holatdan keladi: asbob ishlatayotgan robot stolda yozadi (monitorda terminal, fayl, veb belgisi), o'ylayotgani qo'lini iyagiga qo'yib yuqoriga qaraydi («…»), ruxsat kutayotgani turib sizga qo'l silkitadi (sariq «!», xona chegarasi sariq), xatoda stoldan o'girilib boshini qashiydi, bo'sh robot divanda qahva ichadi, uzoq tinch turgani uxlaydi («z z»).
- Robotning yuz-ekranidagi ko'zlar holatga qarab o'zgaradi va ko'z qisadi. Holat o'zgarsa robot joydan joyga sakramaydi — turib, stolcha atrofidan aylanib, o'z stoli yoki divandagi o'z joyiga yuradi. Bo'sh robot ba'zan javon, deraza yoki gul oldiga borib keladi.
- Asosiy agent quloqchin va mikrofon taqadi: yordamchi (Explore, Plan…) ishga tushsa, unga o'girilib qo'li bilan ko'rsatadi, «→ Explore» pufakchasi chiqadi va binafsha karta uchib boradi; yordamchi tugatsa — xursand sakraydi va yashil «✓ Tayyor» kartasini qaytaradi.
- Kuzatuvchi dron (TokenKuzat'ning o'zi) yo'lak ustida aylanadi; ruxsat yoki xato bo'lsa o'sha robot ustiga uchib, nur tushiradi. Dronni bosing — e'tibor kerak xonalarni aytadi.
- Robotni bosish — sessiya xaritasi ochiladi; pastdagi xona tugmasi yoki xona yorlig'i — kamera o'sha xonaga uchadi; «Butun ofis» — qaytadi. Sudrab aylantiriladi, chimdib yoki g'ildirak bilan yaqinlashtiriladi. Deraza ortidagi yorug'lik — hozirgi vaqt: kechasi xona chiroqlari va monitorlar yonadi, hech kim ishlamasa xona qorong'i. Reduce Motion yoki yengil rejimda robotlar joyida turadi; oyna ko'rinmasa chizish to'xtaydi.

## 6.41.0 — 2026-10-29

- Token kartasi (Xarita va Xulosa): asosiy agent uchun pastda kontekst chizig'i qo'shildi — «Kontekst ▬▬▬ 168K / 200K». Oddiy holatda xira, 80% dan sariq, 92% dan qizil bo'ladi; ustiga olib borilsa foizi va nima uchun muhimligi chiqadi. Kontekst — sessiyaning hozirgi holati, eski so'rov tanlansa ham o'zgarmaydi.

## 6.40.0 — 2026-10-29

- Xarita: chap tepa burchakda ham token kartasi chiqadi — Xulosadagi bilan bir xil: «✦ Asosiy agent · shu so'rovda», raqam va yordamchilar bo'lsa ulush chizig'i. To'liq rejimda Xarita/Xulosa tablari ostida, oddiy rejimda kanvas chetidan 12 pt ichkarida turadi. So'rovsiz sessiyada karta chiqmaydi.

## 6.39.1 — 2026-10-29

- Xulosa: token kartasining joylashuvi tuzatildi. To'liq rejimda karta Xarita/Xulosa tablari bilan bir chiziqda turadi: chap cheti tablarnikiga to'g'ri keladi, ulardan 12 pt pastda joylashgan, soyasi ham tablarniki bilan bir xil. Oddiy rejimda karta kanvas chetidan 12 pt ichkarida, xuddi o'ng burchakdagi tugma kabi. Karta ixchamroq bo'ldi: raqam 38 dan 30 pt ga kichraydi, burchaklar 16 pt — endi u tablardan og'ir ko'rinmaydi.

## 6.39.0 — 2026-10-29

- Xulosa: chap tepa burchakdagi token kartasi Apple vidjetlari uslubida qayta chizildi. Endi u shisha fonda (macOS 26+ da Liquid Glass) turadi. Sarlavha bosh harflar o'rniga oddiy yozuvda va belgi bilan: «✦ Asosiy agent · shu so'rovda». Raqam kattaroq va yumaloq shriftda. Yordamchi agentlar bo'lsa, raqam ostida ulush chizig'i chiqadi va «Asosiy 5,0M · Yordamchilar 400K» deb yoziladi.

## 6.38.0 — 2026-10-29

- Xulosa: kanvasning chap tepa burchagida agent sarflagan token katta raqam bilan («SHU SO'ROVDA · ASOSIY AGENT — 1,8M token»). Yordamchi agentlar bo'lsa — ularning sarfi pastida alohida. Boshqa agent tanlansa, raqam o'sha agentniki bo'ladi. To'liq ekran rejimida raqam Xarita/Xulosa tablari ostida turadi.

## 6.37.1 — 2026-10-29

- Kontrast: yorug' mavzuda sariq, qizil va yashil holat matnlari to'qroq — oq va kulrang fonda ham o'qiladi (≥ 4,5:1). Menyu panelidagi «kontekst 92%» endi to'liq rangda (avval kulrang bilan aralashib xiralashardi).
- To'q siyoh kartalarda burchakdagi binafsha nur kuchsizroq, qorong'i mavzuda gradient to'qroq — yuqori o'ng burchakdagi xira matn va qizil foiz endi aniq o'qiladi.
- Limit 75% dan oshganda yashil «Sur'at me'yorida» chiqmaydi: o'rniga «5 soatlik limitning 93% ishlatildi — tiklanish 20:50 da» — sariq yoki qizil rangda.

## 6.37.0 — 2026-10-29

- Bitta palitra: hamma rang dizayn tizimi tokenlaridan olinadi. macOS tizim ranglari (`.purple .teal .green .red .accentColor` …) kodda qolmadi, shuning uchun Mac'dagi urg'u rangi o'zgarsa ham ilova ranglari o'zgarmaydi.
- Token turlari yangi ranglarda: asosiy bo'lak («Qayta o'qilgan kontekst») brend binafshada, qolganlari teal, orkide, orange va ko'k; rang ko'rmaydigan odam uchun ham ajraladi. Sessiyada yordamchi agentlar chiziqning oxiriga o'tdi.
- Limit hamma joyda bitta qoida bilan: 75% gacha binafsha, 75–89% sariq, 90%+ qizil (Sozlamalardagi yashil rang olib tashlandi).
- Limit chizig'i va halqalari endi butun shkalani xira ko'rsatadi — sariq va qizil zona qayerdan boshlanishi oldindan ko'rinadi; to'ldirilgan qism shkalani foizgacha ochadi.
- «Bugun» va limit kartalari: to'q siyoh fonga yumshoq diagonal gradient va burchakda binafsha nur.

## 6.36.0 — 2026-10-29

- Xulosa: agent kartasida endi shu so'rovda sarflagan tokeni ko'rsatiladi («8,3M token · Opus 5.5 · 49 qadam»). Raqam qadamlar soni bilan bir davr uchun hisoblanadi va sarlavhadagi so'rov raqami bilan mos keladi; yordamchi agentlarda ham shunday.

## 6.35.0 — 2026-10-29

- «Sessiya» endi faqat suhbat ma'nosida: 5 soatlik oyna hamma joyda «5 soatlik limit» («Joriy sessiya» → «5 soatlik limit · har 5 soatda yangilanadi», «Bu hafta» → «Haftalik limit»).
- Token turlari bitta nom bilan: Tarix, jadval va grafiklarda ham «Qayta o'qilgan kontekst», «Kontekstni eslab qolish», «Yangi kiritilgan matn», «Claude javobi va fikrlashi» («Kesh o'qish / yozish» o'rniga).
- «vaznli token» → «token (narx bo'yicha)» — hisoblash usulining yangi nomi bilan bir xil.
- Tejash: loyiha chizig'idagi ikki rang uchun izoh («isrof» · «foydali sarf»); «model va sifat o'zgarmaydi» → to'liq gap; «Tejash: ~50K/javob» → «Har javobda ~50K tejash mumkin».
- Tanish MCP asboblari odam tilida: «computer-use: app_screenshot» → «Ekranni ko'ryapti», «ccd turn: wrap_up» → «Javobni yakunlayapti», brauzer asboblari, «ToolSearch» → «Asbob qidiruvi».
- 5 soatlik limit ogohlantirishi: «Shu sur'atda 5 soatlik limit ~19:40 da tugaydi — tiklanish 20:50 da». Tiklanishdan 10 daqiqadan kam oldin tugasa — ogohlantirish chiqmaydi.

## 6.34.0 — 2026-10-29

- Tuzatildi: Sozlamalarda «Isrof…» va «Kontekst katta bo'lsa — avtomatik yangi sessiya» qatorlari ustma-ust chizilardi. Uzun izohlar bir satrga qisqardi, to'liq tushuntirish — maslahatda.
- «Yengil rejim» → «Kam animatsiya» (macOS'dagi «Light mode» — yorug' mavzu bilan adashtirilmasin).
- Hisoblash usuli: qisqa yorliqlar («Token soni» / «Narx bo'yicha»), izohdagi eski «Vaznli rejim» atamasi olib tashlandi.
- Holat bitta ot bilan: sarlavhadagi belgi, yon menyu, Jonli belgisi va menyu paneli — hammasi ishlayotgan sessiyalar sonini ko'rsatadi; agentlar soni maslahatda.
- Tarix: davr yig'ilgan tarixga moslanadi (3 kunlik tarixga 30 kunlik bo'sh grafik ochilmaydi), davr uzun bo'lsa «Tarix … dan yig'ilyapti» yozuvi.
- Bugun → HOZIR kartasidagi taymer ustida «Joriy qadam» yorlig'i.

## 6.33.1 — 2026-10-29

- Tuzatildi: sahifa almashganda eski va yangi sahifa bir lahza ustma-ust ko'rinardi. Endi eski sahifa darhol yo'qoladi, yangisi qisqa fade bilan chiqadi.

## 6.33.0 — 2026-10-29

- Sarlavhadagi «Jonli · N agent» belgisi endi bosiladi: istalgan sahifadan Jonli sahifasini ochadi.

## 6.32.1 — 2026-10-29

- Tuzatildi: inglizcha interfeysda ba'zan o'zbekcha so'zlar chiqardi (masalan «Jonli · 1 agent»). Sabab — yangi sessiya xulosasi suhbat tilida yasalayotganda git chaqiruvi run loop'ni aylantirar va interfeys shu lahzada xulosa tilida chizilardi. Endi git kutish run loop'ni aylantirmaydi, til almashishi esa faqat o'z oqimida amal qiladi.

## 6.32.0 — 2026-10-29

- Ko'chirilgan sessiya sarlavhasi endi tizim matni emas: «↪ so'nggi vazifa» (xulosadan olinadi).
- Ishlayotgan sessiyada nomi yonida «Ishlayapti» yozuvi — holat faqat rang bilan berilmaydi.
- «0 yordamchi agent» chipi va yolg'iz «Asosiy agent 100%» qatori yashirildi.
- «Xom / Vaznli» o'rniga «Token soni / Narx bo'yicha»; yangi foydalanuvchida odatiy holat — «Narx bo'yicha».
- «Eng so'nggi» saralashda sessiyalar kunlar bo'yicha guruhlangan: «Bugun», «Kecha», keyin sana.

## 6.31.0 — 2026-10-29

- «Sessiyalar» birinchi kirgan odam uchun tushunarliroq: asosiy raqam endi «5 soatlik limitning N%» (o'rganilmagan bo'lsa — narx yoki token), token soni ostida birligi bilan.
- Yig'iq kartadagi chiziq endi sessiya hajmini eng kattasiga nisbatan ko'rsatadi; tarkib faqat ochilganda.
- «Eng so'nggi / Eng qimmat» saralash.
- Tarkib oddiy so'zlar bilan, izoh qatorning o'zida («Qayta o'qilgan kontekst», «Claude javobi va fikrlashi» …).
- Ochilgan kartada bitta xulosa: limit asosan nimaga ketgani va nima qilsa tejaladi.

## 6.30.1 — 2026-10-29

- «Jonli» kartalari tartibga keltirildi: bir qatordagi kartalar endi bir xil balandlikda, pastki qatori (kontekst, vaqt, tokenlar) bir chiziqda turadi. Avval kartalar har xil balandlikda bo'lib, ostida bo'sh joylar qolardi.

## 6.30.0 — 2026-10-29

- Avtomatik yangi sessiya endi takrorlanadi: ko'chirilgandan keyin ham eski sessiyada yozishda davom etilsa va kontekst yana +100K o'ssa — sessiya qayta ko'chiriladi va eski sessiyadagi yo'naltirish qaytadan yoqiladi. Avval har sessiyada faqat bir marta ko'chirilardi, foydalanuvchi qaytib kelgach esa katta kontekst o'sishda davom etardi.

## 6.29.1 — 2026-10-29

- Tuzatildi: eski sessiyadan yo'naltirilgan xabar bilan birga Claude ilovasi qo'shadigan `<system-reminder>` matni ham yangi sessiyaga o'tib ketardi. Endi olib tashlanadi; faqat tizim matnidan iborat xabar yo'naltirilmaydi.

## 6.29.0 — 2026-10-29

- Yangi sessiya xulosasi suhbat tilida: foydalanuvchi xabarlari qaysi tilda bo'lsa (o'zbekcha / English), xulosa, birinchi xabar va eski sessiyadagi yo'naltirish sababi shu tilda — ilova tili boshqa bo'lsa ham. Aniqlab bo'lmasa — ilova tili.
- Xulosada «Git holati»: o'zgargan fayllar joylashgan repolarning oxirgi commit'i va commit qilinmagan fayllari. Oxirgi javob ish yarmida yozilgan bo'lishi mumkinligi aytiladi — yangi sessiya rejalashtirilgan qadamni bajarilgan deb hisoblamay, avval tekshiradi.

## 6.28.0 — 2026-10-29

- Eski sessiyadan yo'naltirish: avtomatik yangi sessiya ochilgandan keyin eski sessiyada yozilgan birinchi xabar to'xtatiladi (Claude Code `UserPromptSubmit` hook'i) va xulosa bilan birga yangi sessiyaga yuboriladi — u yerda Claude aynan shu so'rovni bajaradi. Sabab eski sessiyada ko'rsatiladi; xabar qayta yuborilsa — eski sessiyada qoladi. Slash-buyruqlar (`/compact` va h.k.) to'xtatilmaydi; 24 soatdan eski sessiyalar ham. Sozlamalar → «…eski sessiyada yozsam — yangi sessiyaga yo'naltirish» (sukut bo'yicha yoqilgan; o'chirilsa hook olib tashlanadi). Ilova qayta ishga tushsa ham allaqachon ko'chirilgan sessiyalar yo'naltiriladi.
- Tuzatildi: Terminalda yangi sessiya hook rejimidan ochilmasdi (asinxron ochish jarayon chiqishi bilan uzilardi) — endi `/usr/bin/open -a Terminal` tugashi kutiladi. Terminal skriptida `CLAUDE_*` o'zgaruvchilari tozalanadi, yangi sessiya o'zini bola sessiya deb hisoblamasin.

## 6.27.1 — 2026-10-29

- Tuzatildi: avtomatik yangi sessiya bir sessiya uchun ikki marta ochilishi mumkin edi — «ochildi» belgisi faqat xotirada turardi, ilova qayta ishga tushganda (masalan, yangilangandan keyin) yo'qolardi. Endi diskda saqlanadi (7 kun).

## 6.27.0 — 2026-10-29

- Tarqatish: `bash scripts/release.sh` — universal (Apple Silicon + Intel) ilova bilan DMG (`dist/TokenKuzatuv-<versiya>.dmg`, «Applications» yorlig'i, `.sha256`). `TK_SIGN_IDENTITY` (Developer ID) va `TK_NOTARY_PROFILE` berilsa — imzolanadi va notarizatsiyadan o'tadi; bo'lmasa vaqtinchalik imzo.
- Yangilanishni tekshirish: kuniga bir marta GitHub'dagi so'nggi reliz o'qiladi; yangisi bo'lsa menyu panelida va Sozlamalarda «yuklab olish» havolasi (DMG). Sozlamalar → «Yangi versiyani tekshirish» (sukut bo'yicha yoqilgan), «Hozir tekshirish».
- README: DMG'dan o'rnatish va imzolanmagan ilovani birinchi marta ochish («Open Anyway»).

## 6.26.1 — 2026-10-29

- Aniqlik: Claude ilovasi tashqi havola (`claude://code/new?q=…`) bilan kelgan xabarni xavfsizlik uchun o'zi yubormaydi — faqat yozish maydoniga qo'yadi, yangi papka uchun esa «Trust workspace» so'raydi. Bildirishnoma va Sozlamalar matni shunga moslandi: ilovada — «Enter bosing», Terminalda (`claude "<xabar>"`) — to'liq avtomatik.

## 6.26.0 — 2026-10-29

- Avtomatik yangi sessiya endi ishni o'zi davom ettiradi: xulosa yangi sessiyaning birinchi xabari bo'lib o'zi yuboriladi (Claude ilovasida — `claude://code/new?folder=…&q=…`, Terminalda — `claude "<xabar>"`). Claude tugallanmagan ishni davom ettiradi; ish tugagan yoki keyingi qadam foydalanuvchi qarori bo'lsa — holatni aytib kutadi. Xabar havolada berilgani uchun papka mos kelmasa ham yetib boradi (SessionStart hook kerak emas). Xulosa ~8000 belgi bilan cheklanadi, har so'rov — 400 belgi.

## 6.25.1 — 2026-10-29

- Tuzatildi: avtomatik yangi sessiya Claude ilovasida ochilmasdi — `claude://code/new` papkasiz faqat ilovani oldinga chiqaradi. Endi Finder'dagi «New Claude Code Session Here» bilan bir xil havola: `claude://code/new?folder=<loyiha papkasi>&source=services` — yangi sessiya o'sha papkada ochiladi va xulosa unga beriladi.

## 6.25.0 — 2026-10-29

- Avtomatik yangi sessiya (Sozlamalar → Bildirishnomalar, sukut bo'yicha yoqilgan): sessiya konteksti chegaradan (150K / **200K** / 300K / 500K) oshgan bo'lsa, Claude javobni tugatgan zahoti xulosa saqlanadi va yangi sessiya ochiladi — Claude ilovasida (`claude://code/new`) yoki Terminalda (`claude`, loyiha papkasida). Xulosani SessionStart hook yangi sessiyaga o'zi beradi. Ish o'rtasida hech qachon to'xtatilmaydi, ruxsat kutayotgan sessiyada ishlamaydi, har sessiyada bir marta; ilova ochilgandagi mavjud sessiyalar uchun emas. Bildirishnoma keladi.

## 6.24.0 — 2026-10-29

- Menyu satri paneli: bugungi isrof qatori — «Bugun isrof ~9.6M · 45%», eng ko'p isrof qilgan loyiha; bosilsa «Tejash» sahifasi ochiladi. Ma'lumot har 5 daqiqada yoziladigan kunlik yakundan olinadi (panel ochilganda qayta hisoblanmaydi); isrof bo'lmasa qator ko'rinmaydi.

## 6.23.1 — 2026-10-29

- «Tejash»: tuzatish hali bo'lmagan loyihada ustunlar yonida bugungi isrof foizi va «avval → keyin» qayerda chiqishi haqida izoh.
- Sahifa almashganda eski sahifa yangisi ostida ko'rinib turmaydi; sarlavha matni ustma-ust chiqmaydi.
- claude.ai konnektorlari (server nomi UUID) asbob ro'yxatlarida UUID o'rniga asbob nomi bilan ko'rinadi; «ishlatilgan konnektorlar» ro'yxatiga kirmaydi.
- «Jonli» kartalarida kontekst foizi («15%») ikki qatorga bo'linmaydi.

## 6.23.0 — 2026-10-29

- Tejashni o'lchash: loyihalar bo'yicha kunlik sarf va isrof diskda saqlanadi (`project-savings.json`, 120 kun) — sessiyalar 7 kundan keyin xotiradan chiqsa ham. «Tejash» sahifasida har loyihada 14 kunlik isrof ulushi ustunlari va «avval → keyin»: tuzatishdan oldingi 7 kun va keyingi kunlardagi isrof foizi (tuzatish kuni hisobga olinmaydi; birinchi natija ertasi kuni).
- Tuzatish sanasi «Claude'ga topshirish» bosilganda va `/tokenkuzat:optimize` o'zgarishlarni qo'llagach (`savings_report` → `applied: true`) yoziladi. MCP hisobotida `last_fix` — oldingi tuzatish natijasi.
- Isrof bildirishnomalari (Sozlamalar → Bildirishnomalar, sukut bo'yicha yoqilgan): ishlayotgan sessiya konteksti 200K dan oshsa — bir marta (bosilsa sessiya ochiladi); loyiha bugun sarfining 40%+ ini isrof qilsa (narx bo'yicha, kamida 2M) — kuniga bir marta (bosilsa «Tejash» ochiladi).
- Tuzatildi: boshqa sessiyadan ochilgan sessiyalarda birinchi xabar `<system-reminder>` bilan boshlangani uchun topshiriq so'rov hisoblanmasdi — sessiyada so'rov qolmay, xarita bo'sh chiqardi. Endi boshidagi tizim bloklari olib tashlanadi. So'rovsiz sessiyada xarita o'rnida tushuntirish chiqadi.
- «Tarixni tozalash» loyiha tarixini ham o'chiradi.

## 6.22.1 — 2026-10-29

- Tablar yagona uslubda: sessiya tablari (Xarita / Xulosa / Fayllar / Natijalar), davr (Bugun / 7 kun, 7 / 14 / 30 kun), Xom / Vaznli va Jonli ko'rinishlari — bitta shisha kapsula komponenti (`PillSegments`), tanlangani yorug' tabletka bilan suzib o'tadi. Ishlayotgan sessiyalar qatori ham shu tabletkani ishlatadi; yorug' temada oq tabletka va yengil soya.
- «Tejash» sahifasida loyihani ochish/yopish yumshoq: balandlik prujina bilan o'sadi, mazmun biroz kechikib paydo bo'ladi, yopilganda keyingi qator ustiga chiqmaydi.

## 6.22.0 — 2026-10-29

- Yangi «Tejash» sahifasi (⌘5): loyihalar sarf bo'yicha (bugun / 7 kun), har birida ulush chizig'i, taxminiy isrof va sabablari — katta kontekst, og'ir boshlanish (konnektorlar, pluginlar), katta asbob natijalari, kesh qayta yozilishi, skrinshotlar, takroriy o'qish, ketma-ket xatolar. Har sababda qisqa yechim. Xom / Vaznli rejimga mos.
- Isrof — faqat oldini olsa bo'ladigan qism: har chaqiruvda 150K dan ortiq qayta o'qilgan kontekst, 80K dan og'ir boshlanish, takroriy o'qish va kontekstda qolgan natijalar. Vaznli rejimda kesh o'qish arzonligi hisobga olinadi.
- «Claude'ga topshirish» — loyiha hisoboti va aniq topshiriqni nusxalaydi: Claude CLAUDE.md va sozlamalarga o'zgarish taklif qiladi va har birini tasdiqlagandan keyin qo'llaydi. «Terminalda ochish» va katta kontekstda «Yangi sessiyada davom ettirish».
- Plagin: MCP `savings_report` asbobi va `/tokenkuzat:optimize` buyrug'i — Claude joriy loyiha hisobotini o'zi olib, tuzatishni boshlaydi.
- Og'ir boshlanish maslahatida ishlatilgan konnektorlar ro'yxatidan ichki ID'lar olib tashlandi.

## 6.21.3 — 2026-10-29

- To'liq rejimda (⇧⌘F) tepada chapda Xarita / Xulosa tablari — shisha kapsulada, tanlangani yorug' tabletka bilan suzib o'tadi; o'ngda ishlayotgan sessiyalar. Endi to'liq rejimdan chiqmasdan ko'rinish almashtiriladi.

## 6.21.2 — 2026-10-29

- Ishlayotgan sessiyalar qatori — Apple Liquid Glass uslubida (macOS 26+ da haqiqiy shisha, eskisida shaffof material): bitta kapsula, dumaloq loyiha belgilari, tanlangan sessiya ichida yorug' «tabletka» va u bosilganda sessiyalar orasida suzib o'tadi; hover — yengil yoritish. «Ishlayapti» so'zi o'rnida yonib turgan yashil nuqta.
- Holat o'rnida ichki ID (UUID) chiqib qolsa — sessiya nomi ko'rsatiladi.

## 6.21.1 — 2026-10-29

- «Faqat xarita / sxema» (to'liq) rejimida ham ishlayotgan sessiyalar ko'rinadi — kanvas tepasida, o'rtada, o'z foni bilan; bosib yoki ⌘[ / ⌘] bilan almashtiriladi.
- Xulosa tabi to'liq rejimda xaritadagidek oyna chetlarigacha cho'ziladi.

## 6.21.0 — 2026-10-29

- Sessiya sahifasida, tablar qatorining o'ng tomonida — «Ishlayapti»: hozir ishlayotgan va ruxsat kutayotgan boshqa sessiyalar (boshqa loyihalar va bir loyihadagi parallel sessiyalar). Har kartochkada loyiha va asosiy agent hozir nima qilayotgani; bosing — o'sha sessiyaga o'tadi. ⌘[ / ⌘] — oldingi/keyingisi.
- Tartib sessiya boshlangan vaqti bo'yicha va o'zgarmaydi — bosish paytida kartochkalar o'rin almashmaydi. Tor oynada faqat holat matni, undan ham torda faqat belgilar, so'ng bitta menyu; 4 tadan ko'pi «+N» menyusida.

## 6.20.2 — 2026-10-29

- Sessiya → Xulosa: yuqori o'ng burchakda xaritadagidek «Faqat sxema» tugmasi (⇧⌘F, chiqish — Esc): sarlavha, tablar, yon menyu va panel yashirinadi, sxema oynaga qayta sig'diriladi.
- Xulosadagi «Oynaga sig'dirish» belgisi xaritadagidek ⛶ ga almashdi — endi to'liq ekran tugmasi bilan adashmaydi.

## 6.20.1 — 2026-10-28

- «Xulosa» sxemasi xaritadagidek boshqariladi: sichqoncha/trackpad bilan surish, pinch yoki ⌘/⌥ + aylantirish bilan kursor atrofida zoom; − / + ekran markazi atrofida, ⤢ — oynaga sig'dirib markazga qaytaradi. Surilmaguncha sxema oynaga sig'dirilib markazda turadi (yangi qadamlar qo'shilganda ham); ochilganda yuqori qismi ekrandan chiqib qolishi tuzatildi.

## 6.20.0 — 2026-10-28

- Ingliz tili: ilova endi ikki tilda — O'zbekcha va English. Sozlamalar → Umumiy → «Til / Language»: O'zbekcha / English / Tizim tili (sukut — Mac tili inglizcha bo'lsa English, aks holda o'zbekcha). Tanlov darhol qo'llanadi — oyna va menyu paneli qaytadan chiziladi.
- Tarjima qilingan: barcha sahifalar, menyu paneli va menyu satri, bildirishnomalar, robot pufaklari, bo'sh holatlar, tooltip'lar, status line, «daq oldin» kabi vaqtlar va sanalar (inglizchada «Oct 28», «Wednesday, October 28»), raqamlar (1,2K → 1.2K).
- Matnlar kod ichida juft yoziladi: `tr("Bugun", "Today")` (`TokenKuzatCore/Localization.swift`) — yangi matn qo'shish oson, alohida resurs fayli kerak emas.
- README'da inglizcha bo'lim. MCP server o'zgarmadi (u allaqachon inglizcha).

## 6.19.0 — 2026-10-28

- «Jonli» sahifada «Chat va boshqa joylar»: claude.ai / desktop chat, bulut va boshqa qurilmadagi ish vaqt bo'yicha — kartada (faol/tinch, so'nggi 30 daqiqada 5 soatlik limitdan ~%, 2 soatlik ustunlar) va «Chiziqlar»da alohida qatorda. Hisob — 6.16 dagi «limitning chat va bulutga ketgan qismi» (bitta manba): har o'sish qaydiga boshlanish vaqti qo'shildi va `OutsideUsage.segments` — so'nggi 6 soat bo'yicha bo'laklar.

## 6.18.0 — 2026-10-28

- Bulutdagi chatlar xaritada: claude.ai / desktop chatdagi ishlar Anthropic bulutida bajariladi va Mac'ga yozilmaydi, lekin ularning yozuvi Claude Code bilan bir xil (.jsonl). Sozlamalar → Ma'lumot → «Chat yozuvini qo'shish…» yoki faylni oynaga sudrab tashlash — sessiya «Claude chat» loyihasi bo'lib chiqadi: so'rovlar, qadamlar, Kirish/Chiqish, tokenlar va Replay.
- Qo'shishda fayl ixchamlanadi (rasm baytlari va uzun natijalar qisqartiriladi, tokenlar va vaqtlar to'liq qoladi) va `~/Library/Application Support/TokenKuzat/chats/` ga yoziladi; bir xil fayl qayta qo'shilsa — yangilanadi.

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
