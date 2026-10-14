# FocusFeed

Private iPhone-App: Instagram + YouTube ohne Algorithmus-Falle.

- **Start einer Session:** Du gibst ein, was du sehen willst (z. B. `motivation, gaming`), und wie lange (1–90 Min).
- **YouTube:** nur Suchergebnisse für deine Begriffe und die Videos daraus. Keine Startseite, keine Empfehlungen, keine Shorts.
- **Instagram:** Following-Feed, Storys und DMs. Keine Reels, kein Explore, keine vorgeschlagenen Beiträge. Schon gesehene Beiträge und Beiträge älter als 7 Tage werden ausgeblendet.
- **Zeit:** Gezählt wird nur, solange die App offen ist. 1 Minute vor Ablauf kommen ein Banner und eine Vibration, danach ist die App für **4× die genutzte Zeit** gesperrt.

Gebaut wird auf GitHub Actions (kein Mac nötig), installiert per Sideload (kein App Store).

## Unterstützte Kombinationen

| Computer | Handy | Möglich? |
|---|---|---|
| Windows | iPhone | ✅ [Anleitung](#windows--iphone) |
| Mac | iPhone | ✅ [Anleitung](#mac--iphone) |
| Windows | Android | ❌ [warum](#android-windows-oder-mac) |
| Mac | Android | ❌ [warum](#android-windows-oder-mac) |

## IPA besorgen (für alle iPhone-Anleitungen)

Die App kommt als Datei `FocusFeed.ipa`.

- **Mit Zugriff auf dieses Repo:** GitHub → **Actions** → letzter grüner Lauf auf `master` → Artifact **`FocusFeed-ipa`** herunterladen → entpacken.
  Oder im Terminal: `gh run download -R Alextum207/focusfeed -n FocusFeed-ipa`
- **Ohne Zugriff** (das Repo ist privat): IPA direkt bei Alex holen.

## Windows + iPhone

**Einmalig auf dem PC:**
1. **iTunes** und **iCloud** in der **Web-Version von apple.com** installieren. Die Microsoft-Store-Versionen funktionieren mit Sideloadly nicht; sind sie installiert, vorher deinstallieren.
2. **Sideloadly** von [sideloadly.io](https://sideloadly.io) installieren.
3. USB-Kabel und eine Apple-ID (eine kostenlose reicht).

**Installieren:**
1. iPhone per USB anschließen, entsperren und bei „Diesem Computer vertrauen?“ auf **Vertrauen** tippen.
2. Sideloadly öffnen und `FocusFeed.ipa` hineinziehen.
3. Oben dein iPhone auswählen und deine **Apple-ID** eintragen.
4. **Start** drücken, Passwort bzw. Code eingeben und warten, bis „Done“ erscheint.

Danach geht es weiter mit [Auf dem iPhone freischalten](#auf-dem-iphone-freischalten).

## Mac + iPhone

### Variante A: Sideloadly (einfach)

1. **Sideloadly** für macOS von [sideloadly.io](https://sideloadly.io) installieren (ab macOS 10.12, auch Apple Silicon). iTunes oder iCloud brauchst du auf dem Mac nicht.
2. iPhone per USB anschließen, entsperren und auf **Vertrauen** tippen.
3. `FocusFeed.ipa` in Sideloadly ziehen, iPhone auswählen und Apple-ID eintragen.
4. **Start** drücken und warten, bis „Done“ erscheint.

Danach geht es weiter mit [Auf dem iPhone freischalten](#auf-dem-iphone-freischalten).

### Variante B: Direkt aus dem Quellcode mit Xcode

Dafür brauchst du keine IPA, aber Zugriff auf das Repo.

1. **Xcode** aus dem Mac App Store und [Homebrew](https://brew.sh) installieren.
2. Im Terminal:
   ```sh
   brew install xcodegen
   git clone https://github.com/Alextum207/focusfeed.git
   cd focusfeed
   xcodegen
   open FocusFeed.xcodeproj
   ```
3. In Xcode: Target **FocusFeed** → **Signing & Capabilities** → bei **Team** deine Apple-ID auswählen (über *Add an Account…*). Ist die Bundle-ID schon vergeben, ändere sie auf etwas Eigenes, z. B. `dev.deinname.focusfeed`.
4. iPhone per USB anschließen, oben als Ziel auswählen und **▶ Run** drücken.

## Auf dem iPhone freischalten

Das ist einmalig nötig, egal ob du Windows oder Mac benutzt.

1. **Entwicklermodus:** Einstellungen → Datenschutz & Sicherheit → **Entwicklermodus** → an, dann iPhone neu starten. Der Schalter erscheint erst nach dem ersten Installationsversuch.
2. **Entwickler vertrauen:** Einstellungen → Allgemein → **VPN & Geräteverwaltung** → deine Apple-ID → **Vertrauen**.
3. FocusFeed öffnen und dich einmal bei Instagram und YouTube einloggen.

### Nach 7 Tagen

Mit einer **kostenlosen Apple-ID** läuft die App nach **7 Tagen** ab. Dann installierst du dieselbe IPA noch einmal, wie oben beschrieben. Deine Logins bleiben normalerweise erhalten.
Mit einem bezahlten Apple-Developer-Account (99 $/Jahr) hält die Installation 1 Jahr.

## Android (Windows oder Mac)

**Geht nicht.** FocusFeed ist eine reine iPhone-App (Swift, UIKit, WKWebView). Eine Android-Version gibt es nicht, und eine IPA-Datei lässt sich auf Android nicht installieren. Dafür müsste die App für Android neu gebaut werden.

## Entwicklung

- Code: `Sources/`, Tests: `Tests/`, Projekt wird mit `xcodegen` aus `project.yml` erzeugt.
- Jeder Push baut und testet auf GitHub Actions (`.github/workflows/build.yml`) und erzeugt die IPA als Artifact.
- Debug: In der App auf den **schon ausgewählten Tab** tippen. Dann erscheint eine Zeile mit Pfad und Diagnosewerten.
