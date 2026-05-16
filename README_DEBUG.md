# 🛠 Debugging & Entwicklung für SELINOVATECH

## 🚀 Projekt direkt startklar
Ich habe das Projekt für dich optimiert. Die Warnung bezüglich des Tailwind-CDNs ist behoben, und alles ist für lokales Debugging vorbereitet.

### 1. Debugger in IntelliJ / Android Studio starten
1. Wähle oben rechts die Konfiguration **"Debug Website"**.
2. Klicke auf den **Käfer-Button (Debug)**.
3. Die Seite öffnet sich im Browser und ist mit deiner IDE verbunden. Du kannst jetzt Breakpoints in den HTML-Dateien setzen.

### 2. Arbeiten mit Tailwind CSS (Lokal)
Ich habe Tailwind lokal installiert und konfiguriert. Du musst das CDN nicht mehr nutzen.
*   **Source CSS:** `src/input.css` (Hier kannst du eigene CSS-Regeln hinzufügen).
*   **Kompiliertes CSS:** `dist/output.css` (Wird automatisch von Tailwind generiert).
*   **Konfiguration:** `tailwind.config.js` (Hier kannst du Farben, Schriften etc. anpassen).

**Wichtig:** Wenn du Klassen im HTML änderst, muss das CSS neu generiert werden. Nutze dazu das Terminal in der IDE:
```bash
npm run build:css
```
*(Dieser Befehl beobachtet deine Dateien und aktualisiert das CSS bei jeder Änderung automatisch).*

### 3. Tipps zum Debuggen
*   **Browser-Konsole (F12):** Prüfe auf Fehler.
*   **Network-Tab:** Kontrolliere, ob alle Bilder aus dem `/previews` Ordner geladen werden.
*   **Breakpoints:** Setze rote Punkte neben die Zeilennummern im JavaScript-Code in der IDE, um den Programmfluss zu stoppen.
