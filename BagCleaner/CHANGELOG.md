# Änderungen

## 1.4.2 – WoW Forever

- **Fix:** Eigene Löschbestätigung ersetzt die globale Blizzard-`StaticPopupDialogs`-Registrierung, die geschützte Funktionen (z. B. Gildenbank-Käufe, Inventaraktionen und Logout) durch UI-Taint beeinträchtigen konnte.
- Abbrechen bzw. Schließen des Bestätigungsfensters verwirft die vorbereitete Auswahl ohne Löschung.
- Prüfung des Gegenstands vor jeder Löschung sowie echte Nutzerklicks für jeden Stapel bleiben bestehen.
- Regressionstests zur vollständigen Entkopplung von der Blizzard-Popup-Tabelle.

## 1.4.1 – WoW Forever

- Eigenständiger dunkler, fast undurchsichtiger Hintergrund mit Rahmen für das Hauptfenster (auch ohne ElvUI oder SetBackdrop).
- Fallback-Hintergrund für Optionen und Kontextmenüs bei fehlender Skin-API.
- Anzeige und automatische Auswahl immer strikt nach **Händler-Gesamtwert je Stapel aufsteigend**.
- Alte Einzelwert-Sortiereinstellung wird migriert; der Sortierknopf aktualisiert nur noch und springt zum billigsten Eintrag.
- Bei einer neuen Inventar-Aktualisierung beginnt die Liste wieder am Anfang; bestehende Schutz- und Blacklistregeln bleiben unverändert.


## 1.4.0 – WoW Forever

- **Löschen-Button pro Gegenstand:** Statuszeichen `X`/`[S]`/`[BL]` durch eine sichtbare und tatsächlich anklickbare Schaltfläche **Löschen** bzw. **Schutz** ersetzt.
- Stapelanzahl und Gesamt-Händlerwert werden getrennt angezeigt; keine rätselhafte Zahl mehr ganz rechts.
- **Einstellbare Blacklist-Tastenkombination** unter BagCleaner-Optionen (Standard Strg+Umschalt+Linksklick). Wählbar: Alt+Umschalt, Strg+Alt, Strg, Alt, Umschalt, Aus.
- Schnellklick auf eine BagCleaner-Zeile oder deren Löschen-Button schützt den entsprechenden Item-Typ; kein automatisches Entsperren durch wiederholtes Klicken.
- Sicherheitsregel: Einzelitem-Klick darf während einer laufenden Massenlösch-Warteschlange nicht den nächsten fremden Stapel löschen.
- ElvUI-/Blizzard-Inventar-Klickhandler bleiben unberührt.
- Beibehaltung der Forever-Interfacekennung `16001` und Kategorie `Taschen`.
- Neue Mock-Tests für den Button, Preisformatierung, Schnellklick, Einstellungsmenü und Tastenkombinationen.

# Changelog

## 1.3.0 – 16.11.2026 (WoW Forever)

- Verbindlich WoW Forever: Interface 16001, Kategorie Taschen.
- Aus der Aufräumliste ausschließen: Ruhesteine, herbeigezauberte Gegenstände mit Tooltip-Marker und Gegenstände ohne positiven Händlerwert.
- Rechtsklick auf BagCleaner-Zeile zeigt kleines Menü mit **Hide**, **Protect (Blacklist)** und **Hide + Protect**.
- Hide blendet einen Item-Typ aus der BagCleaner-Liste aus und verhindert eine automatische Auswahl; Protect verhindert das Löschen bei weiterhin sichtbarer Zeile.
- Item-ID-basierte persistente `hidden`-Datenbank ergänzt, alte SavedVariables bleiben kompatibel.
- Blacklist umfasst jetzt auch graue Gegenstände, nicht nur weiße.
- Gemeinsame Verwaltung mit einzelnem Entfernen von Hide/Protect über Optionen oder `/clean rules`; `/clean blacklist` bleibt erhalten.
- Zusätzliche Forever-Mocktests für Conjured, Händlerpreis 0, Hide, Protect, kombinierte Regeln und Clean All.

## 1.2.0 – 16.11.2026

- Interface auf Forever 16001 umgestellt; `C_Container` und `C_Item` integriert.
- Addon-Kategorie Taschen, eigenständiger Minikarten-Zugriff und ElvUI-Integration.
- Auswahl mit Löschbestätigung und pro Stapel einer echten Benutzeraktion.
