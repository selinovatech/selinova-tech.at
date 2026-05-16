# SELINOVATECH • Premium Digital Assets Marketplace

Selinovatech ist ein exklusives Atelier für digitale Architektur. Wir bieten hochwertige Templates, UI-Kits und Video-Assets für moderne Webprojekte an. Unsere Vision für 2026 verbindet Design mit Funktionalität.

## 🚀 Projekt-Features
- **Premium Assets:** Eine kuratierte Auswahl an digitalen Kunstwerken.
- **Kauf- & Mietmodell:** Flexible Optionen für den Erwerb einzigartiger digitaler Räume.
- **Modern Tech Stack:** Gebaut mit HTML5, JavaScript und Tailwind CSS.
- **Performance:** Optimierte Ladezeiten und responsives Design.

## 🛠 Entwicklung & Debugging

Dieses Projekt ist für die Entwicklung in IntelliJ IDEA oder Android Studio optimiert.

### Voraussetzungen
- [Node.js](https://nodejs.org/) (Version 18+)
- Ein moderner Webbrowser (Chrome empfohlen)

### Installation
1. Repository klonen oder herunterladen.
2. Abhängigkeiten installieren:
   ```bash
   npm install
   ```

### Debugging starten
1. Öffne das Projekt in deiner IDE.
2. Wähle die Run-Konfiguration **"Debug Website"**.
3. Klicke auf den **Debug-Button (Käfer)**.
4. Setze Breakpoints direkt im JavaScript-Teil der HTML-Dateien.

### Tailwind CSS Workflow
Das Projekt nutzt Tailwind CSS lokal. Um Änderungen am Design zu übernehmen, muss das CSS neu generiert werden:

- **Einmaliger Build:** `npm run build:css`
- **Watch-Modus (Automatisch):** Wir empfehlen, das CSS im Hintergrund beobachten zu lassen:
  ```bash
  npx tailwindcss -i ./src/input.css -o ./dist/output.css --watch
  ```

## 📁 Projektstruktur
- `src/`: Quell-CSS-Dateien.
- `dist/`: Kompilierte CSS-Dateien (Produktion).
- `previews/`: Vorschaubilder der Assets.
- `*.html`: Die Hauptseiten der Plattform.
- `package.json`: Projektkonfiguration und Skripte.

---
© 2026 SELINOVATECH – Atelier für digitale Architektur.
