# SHAI: audit rozhodování a první měřitelné opravy

Datum: 7. 10. 2026. Základ porovnání: commit `ffb0297`.

## Co bylo skutečně ověřeno

Statický průchod linkováním, útokem, ústupem, farmením, pushováním a obranou; podrobnější kontrola Wraith Kinga a Liona. Testy spouštějí skutečné změněné Lua moduly s nahrazenými závislostmi herního enginu. Nejde o záznam celého zápasu ani o důkaz lepšího win rate. Uživatel zatím potvrdil načtení a začátek hry.

## Jak nyní rozhodování funguje

Engine vybírá módy podle jejich vrácené naléhavosti. Schopnosti a předměty se vyhodnocují zvlášť, takže součet jednotlivých rozumných pravidel ještě nezaručuje soudržný plán.

| Oblast | Pozorování z kódu | Důsledek / stav |
|---|---|---|
| Linka | `mode_laning_generic.lua` převážně vrací váhy podle času a úrovně. Vlastní `Think` je pouze pro vyjmenované výjimky a carry s lidskou pozicí 5. | U velké části poolu řídí základní linkování vestavěná Dota AI. Přesnost last hitů nelze doložit tímto auditem. |
| Souboje | Běžní hrdinové používají vestavěný attack mód; vlastní override je pro seznam jiných hrdinů. Schopnosti mají samostatné prioritní větve. | Hodnotit zvlášť výběr cíle/pohyb a používání schopností. Nezapínat neověřený override pro celý pool. |
| Ústup | Kombinuje zdraví, manu, počet okolních jednotek, nedávno viděné nepřátele, věže, speciální hrozby a ochranné efekty. | Opraveny konkrétní problémy reinkarnace a záporného výsledku. Rozsah 3200 pro nedávno viděné nepřátele může podporovat přehnaně opatrné ústupy, ale změna vyžaduje herní záznamy. |
| Farma | Rozlišuje role, omezuje běžné větve jungle farmy postupným capem a blokuje je v některých týmových situacích. Některé jiné větve vracejí vyšší váhy přímo. | Ověřit, zda Midas nebo jiná větev skutečně přerušuje užitečnou týmovou aktivitu; neměnit plošně bez reprodukce. |
| Push | Zohledňuje zdraví, počet živých hrdinů, okolní spojence, high ground, ekonomiku, cooldowny a lidské pingy. | Opraveno přepisování dřívějších bezpečnostních limitů ve třech větvích. |
| Obrana | Má odhad hrozeb, týmových počtů, priorit budov a vlastních pingů; navíc cache a přesuny. | Bez herního ověření není potvrzené, zda přiděluje správný počet obránců nebo mění cíl příliš často. |
| Roshan | V předchozí změně se opravila trvalá připravenost a škálování zbývajícího zdraví. | Odhad týmového DPS stále není přesná simulace dostupných účastníků, poškození a přežití. |
| Týmový plán | Některé knihovny sdílejí odhady situace; není zavedený ověřený protokol společných záměrů. | Chatové ano/ne a potvrzené sdílení stavu mezi VM zatím nejsou implementované. |

## Opravy v této změně

1. **Wraith King: šetření many.** Nenaučená reinkarnace už nezpůsobuje šetření many pro neexistující záchranu. Naučená reinkarnace blízko připravenosti ji nadále rezervuje podle skutečného mana costu.
2. **Wraith King: ústup.** Výjimka dovolující pokračovat v teamfightu nově vyžaduje existující, naučenou reinkarnaci a dost many podle jejího mana costu. Dříve testovala pevnou hodnotu 160 a cooldown nenaučené schopnosti. Platí i pro nulový mana cost. Toto zúžení neopravuje všechny situace, kdy je sebeobětování nevhodné.
3. **Wraith King a Lion: přerušování.** Větev přerušení channelingu vyžaduje cíl v dosahu. Dříve prohledávala rozšířený okolní seznam a vracela vysokou prioritu i mimo dosah, což mohlo vyvolat dohánění. Ostatní útočné větve nadále mohou zvolit přiblížení; nejde o obecný zákaz pronásledování. Wraith King testuje skutečný dosah Q; Lion dosah Hexu s již používaným bonusem Aether Lens.
4. **Push: limity.** Přechod z obrany a změna váhy při hrozbě u základny už nesmí zvýšit dříve snížený cap. Lidský attack ping je také omezen současným capem. Zdravý seskupený tým na bezpečném místě na něj dál reaguje. Vedlejší efekt: i běžná odezva na ping je nejvýše 0,82 místo dřívějších 0,9; ověřit, zda není příliš slabá.
5. **Ústup: platný rozsah.** Výsledná naléhavost je omezená na 0–1. Součet odečtů na bezpečné lince dříve mohl být záporný.

U pushování se upravil TypeScript zdroj i odpovídající Lua výstup. Změna je lokální; kompletní TSTL rebuild nebyl proveden.

## Regresní ověření

`tools/Test-SHAI.ps1` spouští každý test v novém Fengari procesu (Lua 5.3; Dota používá vlastní VM).

- `shai-selection`: pool, role, úplné drafty, bany, lidský hráč, duplicity a jména.
- `shai-roshan`: změna připravenosti, zdraví, okolní hrozba, iluze a dokončení.
- `shai-combat`: skutečné moduly WK/Lion; nenaučená/bezplatná reinkarnace, cooldown, přerušení uvnitř a mimo dosah.
- `shai-tactics`: skutečný retreat/push; dostupnost reinkarnace, nezáporný ústup, raněný bot s pingem, slabé seskupení před high groundem, hrozba u základny a bezpečný ping.

Bojový test na původním kódu selhal ve třech případech (rezervace many bez naučeného R a dvě přerušení mimo dosah). Taktický test s původním push modulem selhal na ztraceném capu pro raněného bota; s původním retreat modulem selhal na dostupnosti reinkarnace. Opravené moduly procházejí. To prokazuje změnu těchto rozhodnutí, nikoli celkovou sílu botů.

## Další ověření v zápasech

Použít stejný pool, obtížnost a žádné ekonomické buffy. Porovnat více zápasů před/po, s prohozenými stranami; jeden zápas nestačí.

Zaznamenat čas, hrdinu, zdraví/manu a situaci pro: zbytečnou smrt při dohánění, ústup z vyhraného fightu, farmení během obrany, nevyužitý vyhraný fight a opakované změny cíle. U carry navíc CS v 10. minutě a u supporta dostupnost na lince. Smrt sama o sobě není chyba: hodnotit, zda dosáhla smysluplného výsledku. Teprve opakované situace použít pro změny vah, chase limitů a rozdělení týmových úkolů.

Priorita dalšího kola zůstává vyvážená: bezpečnost ústupu a pohybu, týmová aktivita, a současně schopnosti pěti hlavních testovaných hrdinů. V této změně se nezavádí chatový protokol, obecný bojový přepis ani nový farm algoritmus.

## Navazující opravy říčních run pro prvních 5–10 minut

Původní rune mód byl samostatně spuštěn v simulaci a potvrdil nulovou naléhavost u druhého říčního místa v čase 2:01, u nečinného bota, při pouhé přítomnosti lidského spoluhráče 1500 jednotek od runy a při jediném okolním nepříteli bez okolních spojenců. U prvního říčního místa přitom totožná dostupná vodní runa měla kladnou prioritu.

Opravy a počáteční taktické hranice:

- Odstraněno plošné vypnutí u druhého místa mezi 2. a 6. minutou a zákaz rune módu při nečinnosti.
- Bot se do počtu spojenců započítá přesně jednou; iluze nezvyšují týmovou převahu. Stav u cíle se kontroluje z viditelných jednotek a počtu nepřátel nedávno viděných podle existujícího helperu (posledních 5 sekund). Počty se berou maximem, ne součtem, aby se nezapočítávaly stejné hrozby dvakrát. Jde o konzervativní odhad, nikoli přesné sjednocení ID.
- Contest je dovolen při dostatečném počtu spojenců, zdraví alespoň 45 % a součtu odhadovaného příchozího poškození za 3 sekundy pod 80 % současného zdraví. Sílu všech spojenců ani jejich úmysl zapojit se tento odhad nezná; hranice vyžadují herní doladění.
- Pro přímý útok během contestu se porovnává vlastní poškození proti nepříteli, nikoli proti sobě. Bot vyžaduje alespoň 50 % zdraví a vlastní odhad poškození alespoň 80 % soupeřova. Odhad zahrnuje pouze aktuálně dostupné schopnosti; pod 20 % many se vlastní odhad dále konzervativně omezuje na fyzické poškození. Nepřítel musí být v okolním seznamu v dosahu přibližně vlastního útoku; nezavádí se obecné pronásledování.
- Je-li dostupná runa do 250 jednotek, bot upřednostní příkaz ke sebrání před útokem; příkaz může zahrnovat krátké přiblížení. Pokud je protivník těsně u runy (do 180) a bot dál než 900, může ji vzdát jako velmi pravděpodobně prohraný závod.
- Člověku runu přenechá po čerstvém normálním pingu do 5 sekund, nebo když je do 600 jednotek, přinejmenším podobně blízko jako bot a míří k místu / sbírá runu / stojí do 150 jednotek. Lidé se neúčastní automatického výběru nejbližšího botího sběrače; pouhé stání na midu neblokuje runy. Starší zvláštní pravidlo pro varovné pingy zůstává zachováno.
- Neznámá říční místa kontroluje v All Pick okně od 12 sekund před sudou minutou do 20 sekund po ní, první okno začíná 1:48. Známá dostupná runa není omezena tímto oknem. Vzdálenější kontrolu před spawnem provádí mid / držitel Bottle, případně bot již u místa. Jednou blízko ověřené prázdné místo znovu nekontroluje v témže cyklu, dokud se neobjeví potvrzená runa.
- Mid má při porovnávání blízkých kandidátů preferenci říčního místa odpovídající 700 jednotkám vzdálenosti. Předběžný přesun pro nepotvrzenou runu vzdálenější než 600 odloží při okamžitém last hitu v okolí. Automatický spell combo na protlačení celé wave zatím není zaveden.
- Nejbližší sběrač se vybírá pouze z botů, kteří smějí dané místo sbírat: u říční runy nedává support přednost před botím core v okolí 1200. Stejná pravidla platí pro výběr kandidáta i sběrače, aby bližší nepovolený support neblokoval mid. Samotný lidský core poblíž supportu automatický sběr nezakazuje.
- `Think` znovu čte stav a vzdálenost, odmítá neplatný cíl a kontroluje bezpečnost. Přestane usilovat o runu, která mezitím zmizela. Bottle před sebráním použije jen mimo krátké přiblížení a bez viditelných nepřátel u runy. V konzoli jsou omezené zprávy `[SHAI] rune team=...; hero=...; target=...; distance=...; status=...`.

`tests/shai-runes.test.lua` spouští skutečný rune mód: obě říční místa v časech 2:01, 4:01, 6:01 a 8:01, start z nečinnosti, přenechání spoluhráči/ping a jeho expiraci, pickup před útokem, bezpečný contest, přemíru poškození, 1v2, nedávno viděné hrozby, přípravu, okamžitý last hit, opakované scoutingy, změnu stavu, smrt a prioritu obrany/pushování. Tyto simulace potvrzují rozhodnutí skriptu; nepotvrzují přesnost enginového damage odhadu nebo provedení akcí ve hře.

Nový regresní test s původním modulem z commitu `2702db2` selhává na blokaci druhého říčního místa. Opravená verze prochází celou sadou včetně rozhodnutí při nízké maně. Wisdom část je v tomto testu záměrně izolovaná.

První podporovaný herní test je All Pick. Turbo časování a Wisdom logika nebyly touto změnou přepracovány. Test na midu: sledovat od 1:45, 3:45 a 5:45, zda bot dokončí okamžitý last hit, vybere smysluplnou stranu, nenechá dostupnou runu při vyrovnané situaci bez pokusu, a zruší nebezpečný contest. Potom sledovat návrat na linku a ztracené CS; celkový výsledek zatím není ověřen zápasem.

## Zpětná vazba ze zápasu: Sniper proti Shadow Fiendovi

Uživatel hlásí úspěšný gank Crystal Maiden v 11:30, jinak přijatelný průběh, ale žádný pozorovaný Sniperův contest run a nevhodné Take Aim při možnosti snadného přiblížení Shadow Fienda. Občasné přepínání pohybu trvá. Bez replaye nebo logu nelze určit všechny příčiny konkrétního zápasu.

- **Priorita mid runy bez Bottle:** předchozí testy kontrolovaly kladnou naléhavost, ale nikoli překonání linkování (v úvodu 0,446). Nový test zdravého midu bez Bottle ve vzdálenosti 1200 na předchozí verzi selhal. Nově zdravý mid (alespoň 60 % HP) do 1800 jednotek vrací alespoň 0,60 pro dostupnou říční runu a 0,54 pro povolenou přípravu/kontrolu v okně spawnu. Platí až po dosavadních kontrolách bezpečnosti, nároku spojence a okamžitého last hitu. Bounty pravidla se nemění. To řeší doložený konflikt vah, nikoli záruku, že mód překoná každý bojový či obranný mód enginu.
- **Sniper Take Aim:** vyžaduje probíhající útok, alespoň 60 % HP a nepřítomnost ústupu. Nepovolí aktivaci při viditelném skutečném neomráčeném nepříteli blíž než 550, nebo při nepříteli otočeném k botovi blíž než 550 plus vzdálenost odpovídající jedné sekundě jeho současné rychlosti. Kontrolují se i ostatní okolní nepřátelé, nikoli jen zvolený cíl. Jde o počáteční prostorovou rezervu; není to přesná predikce Shadowraze, blinku ani následného pohybu. Dosavadní útok na cíl v dosahu zůstává podmínkou.
- **Ověření:** `shai-runes` nyní kontroluje prioritu bez Bottle pro dostupnou vodní runu, přípravu a bezpečný power rune contest; zároveň zachování zákazu smrtelného contestu a preference okamžitého last hitu před spawnem. `shai-combat` načítá skutečný Sniper modul a kontroluje blízkého/přibližujícího se soupeře, bezpečné použití, nízké HP, ústup, chybějící útok a dalšího blízkého nepřítele.

Všech pět sad prochází ve Fengari. Další zápas musí ověřit skutečné přepínání módů: sledovat Snipera v 1:48–2:20, 3:48–4:20 a 5:48–6:20; při vyrovnané bezpečné situaci má runě dát přednost před běžným linkováním. U Take Aim sledovat odstup a možnost dalšího přiblížení. Globální přepínání „jdu/nejdu“ není touto opravou označeno za vyřešené; pro další změnu je potřeba konkrétní čas/situace nebo záznam.

## Stabilita pohybu všech botů v mid-game

Uživatel upřesnil, že pozorované otočky během přibližně půl sekundy se týkají obecně všech botů, zejména v mid-game. Audit odhalil dva opravitelné mechanismy; bez replaye není doloženo, jak velký podíl pozorovaných otoček způsobují.

1. **Běžný ústup:** okolní počty a odhad převahy přímo mění prioritu při každém vyhodnocení; odhad síly má cache 0,5 sekundy. Samotné přepínání módu řídí engine. Nová krátká paměť v `shai_decision_stability.lua` se uplatní pouze při již aktivním retreat módu a běžném výsledném výpočtu s prioritou alespoň 0,65. Při poklesu drží předchozí prioritu nejvýše 0,9 sekundy od posledního stejně silného nebo silnějšího signálu. Vyšší hrozba se uplatní okamžitě. Jiný mód může stále vyhrát, pokud má vyšší prioritu. Speciální časované úniky, ochranné efekty, smrt, reinkarnace a další předčasné návraty z výpočtu tuto paměť obcházejí a čistí. Nezvyšuje se priorita vstupu do ústupu a neblokují se ostatní módy.
2. **Cíl při pomoci spoluhráči:** původní `SetStickyTarget` měl dvě chyby: opakovaný stejný cíl stále prodlužoval zámek, a obě větve pomoci po zavolání helperu přímo přepsaly `targetUnit` novým kandidátem. `SetTarget` a následný útok tak mohly mířit na různé jednotky. Nově používají stejný vybraný cíl s limitem 1,2 sekundy od změny. Mrtvý, neútočitelný nebo příliš vzdálený cíl (nad 1800) lze ihned vyměnit; odchod z módu paměť čistí. Změna se týká těchto dvou větví týmové pomoci, nikoli všech útoků enginu.

`shai-stability` testuje časové sekvence krátkého výkyvu, trvalého uklidnění, rostoucího nebezpečí, speciálního vyloučení, odchodu z módu a resetu času. Načítá také skutečný team-roam modul a přes obě větve pomoci i `Think` ověřuje shodu vybraného a napadeného cíle, expiraci a zrušení zámku. `shai-tactics` navíc ověřuje stabilitu skutečného běžného retreat výpočtu při zmizení okolní hrozby a okamžité vyloučení evasion módu. Všech šest sad prochází ve Fengari.

Herní ověření: v mid-game sledovat, zda bot dokončí krátký ústup místo okamžitého otočení zpět, vrátí se po uklidnění a při pomoci nependluje mezi dvěma cíli. Další možné zdroje pohybu — střídání farmy/pushování/obrany, předměty, schopnosti, pathfinding a vestavěné attack chování — nebyly touto změnou sjednoceny. Při přetrvávající otočce zaznamenat čas a hrdinu; nepovažovat krátkou paměť za potvrzené vyřešení veškerého pohybu.

## Lion: kontrola cíle při zahájení útoku

Uživatel odehrál až late game a hodnotí hru i obranu týmu se Sniperem s Rapierem převážně dobře. Konkrétní problém: Lion v mid-game přišel ze stromů na mid, odhalil se bez okamžitého Hexu/stunu, hráč odešel a Lion o několik sekund později použil stun na creepy. Dostupnost jeho schopností v okamžiku příchodu není doložená; pozdější stun ji zpětně neprokazuje.

Původní pořadí bylo Mana Drain, Finger, Impale, Hex. Útočné větve se navíc řídily módem; obyčejný útok na hrdinu v jiném módu sám nespouštěl útočný Hex. Nově `ConsiderEngagementHex` před těmito větvemi nabídne připravený Hex na současný platný nepřátelský hero cíl při útočném módu nebo probíhajícím útoku. Pokud proper target není hrdina, zkouší aktuální attack target. Vyžaduje viditelnost, skutečný cast range (včetně již používaného Aether bonusu), neiluzi, vhodnost cíleného spellu a absenci existujícího disable/tauntu. Nevyžaduje, aby nepřítel mohl právě útočit — disarm nevylučuje nebezpečné kouzlení. Při ústupu nepřidává tuto útočnou větev; původní obranné větve zůstávají.

Použití projde původním guardem dostupnosti akcí, nepřerušuje existující channeling/frontu a zachovává 0,8sekundovou ochranu po příkazu Impale. AoE talent používá location cast. Nezavádí se nový chase příkaz, blink iniciace, reakční prodleva ani obecný zákaz right-clicků. Přednostní Hex může spotřebovat manu před Fingerem; jde o vědomou prioritu zachycení volného cíle při útoku. Když Hex dostupný není, pokračuje původní logika, která nemusí umět tento konkrétní gank dobře dokončit.

`shai-combat` ověřuje skutečný dispatch Liona s ostatními kandidáty nahrazenými kontrolovanými výsledky: Hex před dostupným Mana Drainem, fallback na skutečný attack target mimo útočný mód, žádný opening Hex při nedostupnosti, mimo dosah, na spojence, iluze, neviditelný/imunní/chránený/disabled cíl nebo při ústupu, location cast AoE talentu, časovou ochranu po Impale a původní action guard. Ostatní původní Consider větve nejsou těmito scénáři plně simulovány. Všech šest sad prochází ve Fengari; pořadí herních callbacků a uskutečnění Hexu před prvním right-clickem musí potvrdit zápas.
