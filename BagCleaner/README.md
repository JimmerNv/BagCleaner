# BagCleaner 1.4.7 – WoW Forever

Ein eigenständiges Taschen-Aufräum-Addon mit bevorzugter ElvUI-Anbindung und optionalem Titan Panel. **Dieses Projekt unterstützt WoW Forever (Interface 16001, Client 1.60.1)**; nicht den 3.3.5a-Client.

## Installation

1. World of Warcraft vollständig beenden.
2. Das ZIP in `World of Warcraft/_forever_/Interface/AddOns/` entpacken und ältere `BagCleaner`-Dateien überschreiben.
3. Der Pfad muss `.../_forever_/Interface/AddOns/BagCleaner/BagCleaner.toc` sein.
4. Im Addonmenü unter **Taschen** BagCleaner aktivieren. WoW starten.
5. `/clean status` zeigt Version, Taschen- und Titan-/ElvUI-Erkennung an.

Die Einstellungen (`BagCleanerDB`) bleiben bei einem Update erhalten. Neue `hidden`-Einträge werden automatisch zur Datenbank hinzugefügt.

## Was BagCleaner anzeigt

Nur **graue und weiße** Gegenstände mit **positivem Händler-Verkaufswert**. Immer nach **Gesamtwert eines Stapels aufsteigend** sortiert (Anzahl × Händlerpreis pro Stück). Der billigste Stapel steht ganz oben. Automatische Bereinigung (`/clean`, `/clean 4`, `/clean all`) verwendet dieselbe Reihenfolge. Ein Klick auf „Gesamtwert aufsteigend“ aktualisiert die Liste und springt zum Anfang; die frühere Sortierung nach Einzelwert entfällt.

Aus der Liste und jeder automatischen Auswahl ausgeschlossen:

- Ruhesteine (einschließlich der IDs 6948, 110560, 140192).
- Herbeigezauberte Gegenstände: anhand der lokalisierten Tooltip-Zeile `ITEM_CONJURED`, sofern über `C_TooltipInfo` verfügbar. Zusätzlich fallen typische herbeigezauberte Items wegen fehlendem Händlerwert heraus.
- Gegenstände mit Händlerwert **0 Kupfer** oder nicht ermittelbarem Händlerwert.
- Questgegenstände und Gegenstände der Quest-Klasse.
- Von dir auf **Hide** gesetzte Item-Typen.

**Hide wirkt ausschließlich in der BagCleaner-Aufräumliste**, nicht auf die eigentlichen Inventar-Slots von Blizzard oder ElvUI. Alle Regeln sind Item-ID-basiert: Alle Stapel eines Item-Typs werden gleich behandelt.

## Standalone-Hintergrund und Sortierung

Ohne ElvUI hat das komplette BagCleaner-Fenster einen eigenen **dunklen, nahezu undurchsichtigen Hintergrund samt Rahmen**. Dieser wird mit Spiel-Texturen gezeichnet, selbst wenn der WoW-Forever-Client `SetBackdrop` nicht bereitstellt. Einstellungen, Rechtsklick-Menüs und weitere Dialoge erhalten bei fehlender Skin-Bibliothek ebenfalls einen Hintergrund.

Die **günstigsten Stapel erscheinen bei jedem Öffnen beziehungsweise nach Taschenänderungen zuerst**; eine zuvor gespeicherte Sortierung nach Stückpreis wird beim Update zurückgesetzt. Geschützte Stapel können dabei ebenfalls oben erscheinen, werden aber bei automatischen Löschungen übersprungen.

## Einzelne Stapel löschen und Hide/Protect verwalten

Jede Zeile zeigt nun **links das Item-Symbol und den Namen**, darunter die **Stapelanzahl** und daneben den **formatierten Händler-Gesamtwert**. Rechts steht ein **echter anklickbarer Button „Löschen“**, nicht mehr die verwirrenden Statuszeichen `X`, `[S]` oder `[BL]`.

- **Linksklick auf „Löschen“:** Wählt ausschließlich diesen ungeschützten Stapel zum Löschen aus. Eine gegebenenfalls aktivierte Bestätigung bleibt erforderlich.
- **Linksklick auf die Zeile:** Hat keine Schutz- oder Löschwirkung.
- **Geschützter Stapel:** Zeigt weiterhin „Löschen“, kann aber nicht gelöscht werden, solange der Schutz aktiv ist.
- **Rechtsklick auf die Zeile oder den Button:** Öffnet das Hide/Protect-Menü. Nur dort können einzelne Gegenstände geschützt werden.

**Wichtig:** Es gibt keinen Schnell-Blacklist-Linksklick mehr. BagCleaner verändert keine nativen ElvUI-/Blizzard-Inventarslots. Individuelle Schutzregeln bleiben beim Update erhalten.

## Rechtsklick-Menü in der BagCleaner-Liste

Rechtsklick auf eine angezeigte Zeile öffnet ein kleines Menü:

- **Hide:** Item-Typ in BagCleaner ausblenden und damit aus der automatischen Auswahl ausschließen. Keine zusätzliche Blacklist.
- **Protect (Blacklist):** Item-Typ bleibt sichtbar, kann aber nicht gelöscht werden (auch nicht durch `/clean all`). Funktioniert für graue **und** weiße Items.
- **Hide + Protect:** Beides gleichzeitig. Nach späterem Aufheben von Hide bleibt Protect weiterhin aktiv.

Zum Zurücknehmen: Über **Optionen → Hide / Protect verwalten** oder `/clean rules` die gemeinsame Verwaltung öffnen. Dort sind `H` (versteckt) und `P` (geschützt) erkennbar. **Linksklick** auf einen versteckten Eintrag entfernt Hide; **Rechtsklick** entfernt Protect. Hat ein Eintrag nur Protect, entfernt auch Linksklick den Schutz. Falls beide aktiv waren, können sie unabhängig voneinander entfernt werden. Der bisherige Befehl `/clean blacklist` öffnet ebenfalls die Verwaltung.

Weiße Gegenstände sind standardmäßig **nicht** geschützt. Der globale Schutz kann im Taschenmenü bei Bedarf eingeschaltet werden. Bereits gespeicherte `protectWhite=true`-Werte aus älteren Versionen werden bei der Aktualisierung auf 1.4.7 einmalig auf **aus** gesetzt; spätere bewusste Änderungen bleiben erhalten. Explizit geschützte Items bleiben unabhängig davon geschützt. Questgegenstände und unverkäufliche Items bleiben generell ausgeschlossen. Wenn eine Questgegenstandsprüfung nicht verfügbar ist, werden weiße Items sicherheitshalber nicht in die Löschliste aufgenommen.

## Zugriff

- Mit **ElvUI:** `Clean` am Taschenfenster und im ausklappbaren ElvUI-Taschenmenü. Links öffnet die Aufräumliste; Rechts die Optionen.
- Ohne ElvUI: Eigenständiger `Clean`-Button an der Standardtasche.
- Zusätzlich: Minikarten-Symbol (Linksklick öffnen, Rechtsklick Einstellungen).
- Titan Panel: LibDataBroker-Integration oder ältere native Titan-Registrierung, abhängig von der installierten Titan-Version.

## Chatbefehle

| Befehl | Funktion |
|---|---|
| `/clean` | Gemerkte Anzahl der günstigsten zulässigen Stapel auswählen |
| `/clean 4` | Vier Stapel auswählen |
| `/clean all` | Alle zulässigen Stapel auswählen |
| `/clean show` | Seitenleiste öffnen |
| `/clean settings` | Optionen öffnen |
| `/clean rules` oder `/clean hidden` | Hide/Protect-Verwaltung öffnen |
| `/clean blacklist` | Dieselbe Verwaltung öffnen |
| `/clean blacklist add 12345` | Item-ID schützen |
| `/clean blacklist remove 12345` | Schutz entfernen |
| `/clean auto` | Automatisches Öffnen umschalten |
| `/clean protect` | Globalen Schutz weißer Items umschalten |
| `/clean confirm` | BagCleaner-Bestätigung umschalten |
| `/clean status` | Aktuelle Integration prüfen |

## Sicherheits- und Clientgrenzen

Ein Klick auf „Platz schaffen“ bereitet die Auswahl vor. Standardmäßig erscheint eine **eigene BagCleaner-Bestätigung**, die sich in den Optionen abschalten lässt. Diese verwendet **nicht** Blizzards `StaticPopupDialogs` und vermeidet damit die Taint-Ursache, die Gildenbank-Käufe, Gegenstandsaktionen und Logout beeinträchtigen konnte. **WoW Forever verlangt beim Löschen eine echte Eingabe pro Stapel**; nach der ersten Löschung braucht jeder weitere Stapel den Button **„Jetzt löschen“**. Das gilt auch bei abgeschalteter BagCleaner-Bestätigung. Eventuelle zusätzliche Blizzard-Bestätigungen werden nicht unterdrückt.

Vor jeder Löschung prüft BagCleaner den Gegenstand im Slot erneut (Item-ID, Link, Anzahl, Händlerwert und Schutzstatus). Bei unerwarteter Änderung wird der Vorgang abgebrochen.

## Teststand

Die Lua-Syntax wurde geprüft; die sechs Testläufe für Scan, Sortierung, Questschutz, Ausblendung, Blacklist, konjurierten Tooltip, ElvUI, Titan und Löschwarteschlange liefen erfolgreich. **Kein Test direkt im WoW-Forever-Client**; daher zunächst mit einem wertlosen grauen Item ausprobieren. Andere Addons bzw. ElvUI-Forks können abweichend arbeiten.
