# SHAI: aktuální revize a úkoly

## Potvrzený další postup z posledních dvou zápasů

Pořadí potvrzené hráčem: začít zbývajícími body ze zápasu se Silencerem. Dokončení implementace a herní ověření evidovat odděleně.

### Předposlední zápas: Silencer (9035705167)

- [x] **Delší paměť hrozby — první implementace hotová, herní ověření otevřené.** Tým sdílí snapshot viditelných soupeřů včetně vzdálené ward vision. Po ztrátě vision klesá jistota, omezeně se rozšiřuje oblast možného pohybu a opatrnost vyprší do 5,5 s; snapshot se odstraní do 10 s. Farma/retreat/volitelné farm casts používají poslední známé údaje, ne aktuální skrytou polohu/stats. Po 10. minutě se zohlední i výrazně silnější viditelný soupeř do 1100 jednotek, který právě neběží přímo na bota. Pozorování se obnovuje i během týmového plánu, paměť sama nezakládá gank ani nepřebírá společnou obranu.
- [ ] **Ověřit paměť ve hře:** vzdálená ward vision → zmizení → opatrnost blízkého farmáře; návrat bezpečné farmy po novém vzdáleném pozorování/expiraci; bez nových otoček a bez změny prvních 10 minut.
- [ ] **Roshan při přesunu.** Rozpoznat nevhodný/pohybující se cíl a omezit útoky i nebezpečné přiblížení; aktuální podmínky ověřit přes skutečné API.
- [ ] **Scan.** Ověřit Lua API a možnost číst výsledek, poté navrhnout společného správce a reakci; nedostupná funkce nesmí vyvolávat Lua chyby.
- [ ] **Tormentor.** Z logů zjistit konkrétní blokaci, doplnit dostupnost objektivu a důvody odmítnutí; potom řešit sílu týmu, sestavu a přežití reflectu.
- [ ] **Širší dorážení a kombo model.** Rozšířit dosavadní první model o další finishing spelly/itemy a relevantní dispely/lifesteal; nerozšířit útok za cenu zjevné smrti před jeho vypuštěním.

### Poslední zápas s přáteli (9036262600)

- [ ] **Rozhodování po dokončení invis.** Bezpečný fade je implementovaný, ale stání v aktivní invis / ústup / zahájení ještě nemá samostatný plán.
- [ ] **Původní chybějící lokace.** Z nové zdrojové diagnostiky přesně určit call site `got void`; neslibovat úplnou opravu jen na základě ochranného handleru.
- [ ] **Obranný waveclear a rozmístění.** Navázat na společnou obranu bezpečným čištěním vln a pozicemi podle role/cast range.
- [ ] **Pokročilejší glyph.** Navázat na již hotového společného správce: konkrétní waveclear, příchozí TP a refresh.

### Hotové implementace čekající na nový herní test

Bezpečnější farma a casts pod Curse/Last Word; ganky 3–5 botů, společná obrana, rozpočet damage/many a chain control; kontrola TP; Amulet fade; ochrana akcí před idle watchdogem; krátké lethal finish/trade a základní glyph. Zachovat fungující runy/Wisdom a začátek hry. Další zápas musí potvrdit tyto změny a zachytit případné zbývající běhové chyby.

## Navazující sada: rozpočet boje, chain control a glyph (9. října)

- [x] Gank i obrana používají konkrétní útoky a profily dostupných kouzel místo součtu engine ALL damage. Společný mana pool, čas kouzlení/přiblížení, revival rezerva WK, aktuální obrany cíle a omezený přínos golemu/Death Ward. Z item damage je zatím zahrnut Dagon; celé inventory ani všechny ability kombinace modelované nejsou.
- [x] Čekání na dopad kontrolního kouzla blokuje další kontrolu a příkazy původního castera, ostatní damage pokračuje. Při známé délce stunu/hexu lze začít další kontrolu před jeho koncem podle času dopadu. Neznámá délka se nevymýšlí; rezervace je krátká a vázaná na konkrétní cíl.
- [x] Odhad útoků, kouzel, summonů a spotřebované many se zapisuje do gank/defense trace. Log analyzer zobrazuje tyto detaily i glyph.
- [x] Glyph funguje i při třech lidech ve vlastním týmu: jeden executor, náhrada při smrti, cooldown/krátká sdílená rezervace, pouze viditelné skutečné útoky na budovu, i creep-only siege. Posuzuje odhad času do pádu a blízkou zdravou obranu, nikoli samotné procento HP.
- [ ] Ověřit tuto sadu v nové hře: společný engage, pořadí kontrol, skutečný damage/summon uptime a fortification. Odhad není plná simulace souboje; zvlášť ověřit refresh glyphu, dostupný waveclear a změny po posledním patchi.
- [ ] Dál zbývá Scan API, přesun Roshana, delší paměť viditelné mapové hrozby, plánování již aktivní invis a širší item/spell synergie. Tyto části nebyly touto sadou vyřešené.

Podrobnosti a meze modelu: [audit navazující sady](SHAI-BEHAVIOR-AUDIT.md#navazující-rozpočet-boje-chain-control-a-glyph). Po doplnění paměti prochází 19 Lua a 2 PowerShell sady, syntax všech 312 Lua souborů. Herní ověření je otevřené.

## Nový herní test: 9036262600 (9. října)

Zachované logy a lokálně dekódovaný replay: [revize zápasu se třemi lidmi](SHAI-MATCH-9036262600.md). Původní experiment měl 219 výpisů hold-position, žádný group-ready a nevyužitou Warlockovu připravenou ulti kolem 34:40. Po revizi je hotová první opravná sada; **herní ověření nové verze je stále otevřené**.

- [x] Opravit doložený předčasný návrat idle watchdogu bez obnovení času kontroly; nečistit teleport, channel, queued akce, Amulet fade a platný krátký taktický záměr. Ověřeno testem skutečné funkce.
- [x] Sdílená sestava obrany, společný rally bod a důvody vyloučení členů; rozlišit kill budget a tlak čtyř zdravých botů na osamoceného útočníka u vlastních budov. Zraněný člen odejde samostatně. Nová rozhodnutí platí po 10. minutě, fungující začátek hry zůstává.
- [x] Zahrnout Cask/golem do dostupné kontroly; v koordinované obraně použít Warlock R i na jediného důležitého soupeře a WD Maledict / bezpečný Death Ward i při více spojencích. Čekání už neblokuje všechny původní spelly bezpečně stojících casterů. Ověřeno simulovanými scénáři.
- [x] Kontrola TP před odletem i během channelu: aktuálně viditelné nebezpečí, zdraví skuteční místní pomocníci, jejich reálné příchozí TP a pravděpodobná věž dopadu. Vzdálený či jen přítomný lidský hráč se nepočítá jako slíbená pomoc.
- [x] Bezpečný Shadow Amulet fade: jednou zastavit pohyb a blokovat spelly/itemy během fade; nečekat při potvrzené detekci, věži, neznámém spell projektilu či odhadovaném smrtícím damage. Nezaměňovat s plánováním dlouhodobého pobytu v hotové invis.
- [x] Odmítnout nil lokaci ground itemu a golem/channel guardu; přidat bezpečný handler se zdrojovým názvem do hero/item/defense/roam cest. Diagnostika nevyhodí další chybu při nestandardním typu error objektu.
- [ ] Přesně lokalizovat původní engine chybu `GetUnitToLocationDistance ... got void`. Starý log nemá stack; nové kontroly a handler ji nepovažují za zpětně prokázanou a zcela opravenou.
- [ ] Odehrát novou hru a porovnat obranu/TP/fade s logem. Ve 34:40 WD původního zápasu již nežil, scénář s jeho kombem je samostatný simulovaný test, ne tvrzení o jeho tehdejší dostupnosti.
- [x] Navázat prvním explicitním rozpočtem damage a many, délkovým plánováním chain disable a přehodnocením ganku mimo základnu. Implementační sada výše; celý Maledict/golem/Satanic a všechny itemy stále nejsou simulované a kill není garantovaný.
- [ ] Cíleně ověřit dokončování soubojů. Nízké HP Snipera kolem 27:35 je doložené, dostupnost okamžitého finishing spellu spojeneckých botů poblíž nikoli.

Původní seznam níže zůstává pro širší plán; jeho starší popis guardů Zeuse/Warlocka předchází experimentální změně, která rozšířila guardy na zbytek patnácti vybraných hrdinů. Herní test neověřil správnost každé větve všech hrdinů.

Aktualizováno 9. října 2026 po [datové analýze replaye 9035705167](SHAI-REPLAY-9035705167.md). Implementováno a ověřeno simulovanými testy: přerušení nebezpečné farmy, posouzení ceny kouzlení pod Curse/Last Word u Zeuse a Warlocka a první společný plán ganku na lokálně dominantního viditelného soupeře. **Herní ověření zůstává otevřené**, další části bodů níže jsou plán. Podrobnosti a omezení jsou v [auditu](SHAI-BEHAVIOR-AUDIT.md#první-opravy-podle-replaye-farma-a-cena-kouzlení). Pool zůstává 15 hrdinů. Zachovat fungující sběr říčních/Wisdom run a užitečné support rotace.

## P0: spolehlivý další test

- [x] Zachovat a celé dekódovat poslední replay; publikovat rozlišení evidence/nejistot.
- [x] Připravit `tools/Check-SHAILog.ps1`: unikátní start marker, kontrola opakované telemetrie, end marker, report časového pokrytí a přesná lokální záloha.
- [x] **Ověřeno v běžící Dotě:** `-con_logfile`, `log_flags Console -ConsoleOnly`, echo a opakované `[SHAI] behavior` všech sedmi botů při třech lidech. Potvrzena automatická rotace na match ID; helper vyžaduje správný aktuální LogPath.
- [x] Zápas 9036262600: ověřena diagnostika před dlouhým hraním, zachovány oba rotované logy se start/end markerem a `.dem` po ukončení klienta. Začátek, konec a všechny mezery přes 30 s porovnány s replayem; v každé takové mezeře je smrt příslušného hrdiny. To nezaručuje záznam všech rozhodnutí.
- [x] Doplnit omezenou diagnostiku `unsafe-farm` a `cast-penalty` v první opravě; zprávy `[SHAI] safety` jsou omezené na jednu za 5 sekund z každého helperu/bota.
- [x] První gankový plán loguje fáze a důvody jako `group-not-ready`, `insufficient-damage`, `insufficient-control`, `enemy-backup`, `target-unavailable`; samostatně odchod člena.
- [x] Doplnit první `[SHAI] finish` pro vybrané dorážení, počet zásahů, trade, odhad času/damage a přerušení. Odmítnuté proveditelné damage kandidáty omezovat na zprávu za 5 s; log není kompletní rozhodovací strom.
- [ ] Doplnit `objective-unavailable` a ověřit novou diagnostiku ve hře.

## P1: boj, farma a přežití

Stav implementace: bod 1 má společný guard ve farm/laning/retreat a testy skutečných módů; bod 2 má dispatch guardy patnácti vybraných hrdinů včetně Liona. Důležitá kontrola/záchrana/únik mají jinou prioritu než volitelný harass. Bod 3 má nyní týmové snapshoty s postupným úbytkem jistoty a omezenou oblastí možného pohybu; nejde o kompletní mapový plán ani odhad všech blink/teleport tras. Bod 5 má guard přežití cast pointu a prvního channelu Warlocka i týmový přínos golemu v lokální obraně; nejde o kompletní model všech situací. Tyto body neuzavírat bez nového zápasu.

1. **Přerušit nebezpečnou farmu.** Doloženo u Zeuse kolem 27:39. Zohlednit viditelnou hrozbu, nedávný přijatý damage, dosah/rychlost soupeře, sílu obou stran a pomoc v dosahu. Rozhodnout boj nebo únik; farm action nesmí přepsat tento záměr. Ověření: dominantní nepřítel v melee vzdálenosti, skutečný týmový support, i klidná linka bez falešného ústupu.
2. **Zohlednit Arcane Curse / Last Word před castem.** Zeus má 19 seslání pod Curse v prvních 10 min; Warlock v 31:57 zemřel na Last Word současně s ulti eventem. Model ceny musí rozlišit lehký harass, last hit, únik, důležitý disable/interrupt, kill a záchranu. Nezavádět univerzální zákaz kouzlení. Ověření: nepotřebné Q/W se odmítne, Lion/Shaman smysluplně zastaví soupeře, únik zůstává povolen, last hit pod bezpečnou Curse může být přijat.
3. **Paměť hrozby ze skutečné viditelnosti.** Silný soupeř na lince má ovlivnit prostor pro farmu; po zmizení uchovat poslední známou polohu s klesající jistotou a rozšiřujícím se dosahem. Sílu odhadovat z dostupných informací, ne ze skrytého inventory/polohy. Ověření: po ztrátě vision nehledá přesnou aktuální lokaci, po dostatečném čase neblokuje polovinu mapy navždy.
4. **Dorážení versus ústup při nízkém HP — první implementace, runtime otevřený.** Odstraněna hrubá výjimka `LowChanceToRun`. Společný helper pro boty do 40 % HP vybere jeden útok v dosahu, případně 2–3 při stunu trvajícím přes celou krátkou sérii (nejvýše 1,6 s) a odhadu přežití. Přímé rychlé spell dorážení pokrývá Zeus Q / Luna Lucent Beam; ostatní hero casty dál rozhoduje původní logika. Po vydání se příkaz neopakuje a běžný hero/item dispatch nepřeruší rozmach. Pokles HP sám není důvod ke zrušení; konkrétní hrozba, ochrana/heal cíle, ztráta vision/dosahu či potřebného stunu ano. Po vypuštění posledního projektilu lze ustupovat. Od 20. minuty může jeden kontrolovaný zásah přijmout riskantní trade proti soupeři s alespoň 12k net worth a 1,6násobkem vlastního, pokud bot podle odhadu přežije vypuštění zásahu; ne do Aegis/WK či pod věž. Testy prochází. Ověřit v klientu skutečné zásahy, priority native módů/itemů, stun čas a ceny trade; neprohlašovat garantovaný kill ani kompletní model kombinací/spoluhráčského dorážení.
5. **Warlockova nouzová ulti a channel.** Hlášena otočka při útěku; konkrétní mechanika otočky zatím nepotvrzena. Posoudit cast point, dopadající damage/debuff, pravděpodobnost úniku a skutečný týmový přínos. Může být správné obětovat život za užitečný stun/golem, ale ne za bezvýsledný cast. Ověřit samostatně 1v1, spojence v boji a nedostupný cíl; neodvozovat nula užitku z pouhé současné smrti.

## P2: společný záměr týmu

Navazující implementace: běžící gank může při nedostatku damage/kontroly nebo členů přibrat další způsobilé boty až do pěti. Při seskupování je limit 2400, během boje 1100 jednotek od cíle; proveditelnost se znovu ověřuje a deadline se neprodlužuje. Distantní/nepřipravená pomoc nesmí ospravedlnit pokračování slabého souboje. Opraven guard módu Tormentora na skutečný `BOT_MODE_SIDE_SHOP`. Tyto scénáře prošly testy, runtime ověření chybí.

První implementace bodu 6: `shai_team_gank.lua` od 10. minuty vybírá 3–5 připravených botů do 2400 jednotek, používá gather → approach → engage a odmítá neproveditelné plány. Zranění jednoho člena během engage samo neruší celou skupinu: přehodnotí se zbývající damage/kontrola, dva schopní členové mohou dokončit kill. Bezpečný ranged controller může ještě přispět ze sníženého HP. BKB/Manta/Linken/Lotus/Aeon se čtou pouze na viditelném cíli. Je to konzervativní první model, ne kompletní taktika všech hrdinů/itemů nebo garantovaný kill. Runtime sdílení entity polí a pořadí akcí musí potvrdit nový zápas; bod 6 zatím neuzavírat.

6. **Koordinovaný gank silného soupeře.** Požadavek uživatele, dostupnost výherního ganku v minulém zápase nepotvrzena. Vybrat účastníky podle skutečného ready disable/damage/HP/many a času příchodu; fáze gather → engage → chain disable → finish/abort. Čtyři/pět botů ani vyplýtvání všech ulti nejsou automatická záruka killu. Nedržet boty nekonečně na místě a nepřekrývat zbytečně dlouhé stuny. Ověření: včasná společná akce, rušení po ztrátě klíčového člena/cooldownu nebo příchodu dalších enemy.
7. **Společná obrana základny a bezpečný harass.** Hlášeno jednotlivé přiblížení/smrt. Preferovat bezpečný waveclear a cast range; těsnější commit až s lokálně připravenými spojenci a realistickou šancí. U imminent Ancient loss nezpůsobit pasivní nekonečné čekání. Ověření: slabý support nevychází jednotlivě do silného carry; tým umí využít skutečnou engage příležitost.
8. **Stabilita záměru.** Původní krátké zámky retreat/team-help zůstávají. Nové bezpečnostní/gankové plány musí mít expiraci, okamžité přerušení při nové hrozbě a jediný platný cíl. Další otočky nejprve identifikovat z trace logu, nikoli řešit plošným několikasekundovým ignorováním okolí.

## P3: objektivy a týmové zdroje

9. **Roshan během přesunu.** Lion dostal Roshanův hit a grab/throw kolem 30:17–30:18; špatné útoky do nenapadnutelného Roshana jsou uživatelské hlášení. Ověřit aktuální přesun, skutečnou napadnutelnost a přístupovou cestu. V této době nelovit pohybující cíl a nenechat pathfinding vést boty přímo do něj. Ověření při změnách dne/noci i na obou stranách mapy.
10. **Dočasné veto objektivů hráčem — implementováno, čeká herní ověření.** `!stop roshan`, `!stop tormentor`, `!stop objectives` blokují na 60 herních sekund; `!normal` odstraní obě blokace. Jeden anglický reply, lidský autor stejného týmu, zrušení přijatého requestu, expirace/reset a mrtví členové jsou ověřené simulacemi. Zákaz je zapojen i do autonomních módů a callbacku pro ukončení starého objektivového příkazu; zachovává hero cíl sebeobrany a probíhající cast/TP/channel. Nové lobby musí potvrdit chat, přenos pokynů a skutečné zrušení akcí včetně respawnu.
11. **Tormentor: zjistit konkrétní blokaci před laděním prahů.** V minulém exportu není damage na pojmenovaný miniboss/tormentor. Odečíst reason log v době potenciálního pokusu, skutečnou polohu/živý spawn, sílu připravené skupiny a přežití reflectu. Nesnižovat limity jen proto, aby šli ve 35. minutě za každou cenu. Dokončení: bezpečně získaný shard nebo doložený rozumný důvod odmítnutí.
12. **Scan.** Ve skriptech nenalezeno explicitní `ActionImmediate_Scan`/`GetScanCooldown`; samotný replay export neověřil všechny scan stavy. Nejdříve runtime ověřit API a výsledek, poté jeden týmový správce: rozumná kontrola fog u objektivu či při chybějících soupeřích, sdílený cooldown. Výsledek dává omezenou informaci, ne identity/přesnou polohu všech enemy. Ověření kladného/záporného výsledku i nedostupného scanu bez Lua chyby.
13. **Glyph — první společný správce implementován, runtime otevřený.** Odstraněna blokace ve smíšeném týmu. Jeden bot posoudí skutečné viditelné útoky, odhad building DPS/času do pádu a zdravou obranu do čtyř sekund cesty. Podporuje hero/creep-only siege, Ancient má přednost, cooldown se respektuje. Testy ověřují i náhradu executora a chybějící sloty. Přesný waveclear, incoming TP a patch-specific refresh plánování zatím chybí; engine dostupnost se řídí skutečným cooldownem. Herní chování stále ověřit.
14. **Runy/Wisdom zachovat a doladit.** Zeus opravdu sbíral water/power; XP cykly jsou pozitivní indicie Wisdom, uživatel chválí i pokus o steal. Doladit potřebu HP/many/Bottle, známý zájem soupeře, cenu ztracené wave a bezpečné odepření runy. Neobětovat život slabého midu jen za contest. Potvrdit skutečný capture/XP a případnou možnost zničení water rune přes dostupné API, než ji slibovat.

## Jak úkol uzavřít

Pro každou opravu uchovat konkrétní scénář před/po, očekávanou lepší volbu a důvod, test skutečného Lua modulu a následný nový zápas. Pozitivní trace ani jediný lepší K/D výsledek nejsou celkový důkaz kvality botů. Změny dělat po souvisejících blocích, aby další test rozlišil příčinu.
