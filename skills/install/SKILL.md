---
name: install
description: Token Kuzatuv Mac ilovasini manba koddan yig'ib ~/Applications ga o'rnatadi va ochadi; yangilash uchun ham shu
disable-model-invocation: true
allowed-tools: Bash(sw_vers *), Bash(xcode-select -p), Bash(bash "${CLAUDE_PLUGIN_ROOT}/build.sh"*), Bash(test -x *)
---

# Token Kuzatuv'ni o'rnatish

Foydalanuvchiga uning tilida (odatda o'zbekcha), qisqa va oddiy gaplar bilan javob bering. Har bosqichda nima bo'layotganini bir gapda ayting.

Plagin papkasi (manba kod shu yerda): `${CLAUDE_PLUGIN_ROOT}`

## 1. Talablarni tekshiring

1. `sw_vers -productVersion` — macOS 13 yoki undan yangi bo'lishi kerak. Eski bo'lsa: ilova bu Mac'da ishlamasligini ayting va to'xtang.
2. `xcode-select -p` — Xcode yoki Command Line Tools o'rnatilganmi. Xato qaytsa: foydalanuvchiga Terminal'da o'zi shuni yurgizishini ayting (oyna ochiladi, «Install» bosiladi, bir necha daqiqa):

   ```bash
   xcode-select --install
   ```

   O'rnatib bo'lgach `/tokenkuzat:install` ni qayta chaqirishini ayting va shu yerda to'xtang.

## 2. Yig'ib o'rnating

```bash
bash "${CLAUDE_PLUGIN_ROOT}/build.sh"
```

Birinchi marta 1–3 daqiqa oladi — buyruqni 10 daqiqalik timeout bilan yurgizing va foydalanuvchiga kutishini ayting. Skript ilovani `~/Applications/Token Kuzatuv.app` ga qo'yadi va ochadi (eski versiya bo'lsa — almashtiradi).

Xato bo'lsa:
- `xcrun: error` yoki litsenziya haqida — foydalanuvchi Terminal'da o'zi yurgizsin (parol so'raydi; siz `sudo` ishlatmang), keyin qayta urinib ko'ring:

  ```bash
  sudo xcodebuild -license accept
  ```
- Boshqa kompilyatsiya xatosi — xatoning asosiy qatorini ko'rsating va muallifga (github.com/aliumirovux/TokenKuzat) yuborishni taklif qiling.

## 3. Tekshiring

`test -x "$HOME/Applications/Token Kuzatuv.app/Contents/MacOS/TokenKuzat"` — muvaffaqiyatli bo'lsa, o'rnatildi.

## 4. Foydalanuvchiga ayting

- Menyu satrining o'ng tomonida Token Kuzatuv belgisi paydo bo'ldi; katta oyna ham ochildi. Birinchi ochilishda macOS bildirishnomalarga ruxsat so'raydi — «Allow».
- Ixtiyoriy, ilovaning **Sozlamalar** bo'limida: «Claude Code'ga ulash» — haqiqiy 5 soatlik va haftalik limit foizi; ruxsat kutish ogohlantirishlari. Ikkalasi ham `~/.claude/settings.json` ga yozadi (zaxira nusxa bilan) va «Uzish» bilan qaytariladi.
- Claude'dan to'g'ridan-to'g'ri so'rash mumkin («bugun qancha token ketdi?», «qaysi sessiya ko'p sarflayapti?», «limitim qancha qoldi?»). Buning uchun MCP asboblari ulanishi kerak: `/mcp` buyrug'ida `tokenkuzat` serverini qayta ulang yoki Claude Code'ni qayta oching.
- Yangilash: `/plugin marketplace update tokenkuzat`, keyin yana `/tokenkuzat:install`.
- Ilova internetga hech narsa yubormaydi — faqat shu Mac'dagi Claude Code fayllarini o'qiydi.
