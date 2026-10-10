# SHAI: revize všech 15 povolených hrdinů

Datum: 10. října 2026. Rozsah odpovídá `bots/Customize/shai.lua`; pool se nerozšiřoval.

**Výsledek: základní spell logika existuje u všech 15 hrdinů, ale před revizí obsahovala konkrétní chyby v dosahu, damage, prioritách a podmínkách komb. Doložené chyby uvedené níže jsou opravené. Správnou hru ve všech situacích zatím potvrdit nelze.**

Revize prošla SkillsComplement, jednotlivé Consider funkce, skill/item buildy, MinionThink a jejich vztah ke společnému ganku, obraně, ústupu, dokončení killu a cast safety. Parametry schopností byly porovnány s aktuálními Valve herodata pro všech 15 hrdinů. Komentované historické Ability bloky v souborech nejsou zdroj aktuálních parametrů.

Číselné změny čtou runtime hodnoty schopností; nejde o přepsání celého projektu na konkrétní nový patch. API data nepotvrzují skutečné indexy všech schopností v klientu, pathfinding, timing nebo to, zda hráč použije dispel. To je třeba ověřit v zápase. „Opraveno“ v tomto dokumentu znamená implementace a automatické ověření, pokud je pro danou změnu uvedené, nikoli nový herní test.

## Společné opravy

- Luna, Sven, Dragon Knight, Venge a Witch Doctor mají před běžným buffem/ulti/damage větev pro **přerušení viditelného channelu skutečně v dosahu**. Respektuje busy/invisibility, dostupnost spellu, illusion, debuff immunity, targeted protection a CastSafety. Nevybírá výlet do dosahu jako okamžitý interrupt. Sven zachovává možnost splash zásahu přes bližší jednotku.
- Pro interrupt se používá skutečný runtime cast range, nikoli `J.GetProperCastRange`, který může záměrně přidávat dosah pro přiblížení. Normální útok/kill stále může zvolit přiblížení; tato revize není globální změna všech castů na „jen stát na místě“.
- Opravené výpočty damage/radius: WK, Zeus, Sven, Sniper, Axe, Tide, Lion, Venge, CM, Lich a WD. U spellů s damage v special values nelze spoléhat na `GetAbilityDamage()`; u Svenova Hammeru je naopak základní AbilityDamage použitelný.
- Ready spell bez vhodného cíle již nezablokuje WD Death Ward ani Warlock Offering/Upheaval. Dostupná schopnost a skutečně užitečné rozhodnutí se posuzují odděleně.
- Běžné WD Death Ward a CM Freezing Field procházejí existujícím CastSurvival před vydáním. To odhadne možnost dokončit cast/začátek channelu. **Nesimuluje celý channel** a při zdravém nezasaženém botovi může pustit cast bez detailního damage rozboru. Nejde o novou univerzální ochranu všech channelů.

## Carry

### Wraith King

Kontrolováno: Blast jako opener/interrupt/finish, mana pro Reincarnation, Bone Guard, běžný život versus dočasná wraith forma, miniony a útoky. Společná wraith logika má přednost před normálním ústupem; příznivé pozorování z posledního zápasu se tímto neruší.

Opraveno: Blast používá skutečný přímý damage, DPS a trvání DoT. Kill forecast započítává cast, let projektilu a dobu DoT, takže nepředstírá okamžitý burst. Rezerva many stále vychází z připravené naučené Reincarnation a skutečného mana costu; duch ji nerezervuje.

Otevřeno: běžná Q consideration obsahuje i obecný harass jen podle přítomnosti nepřítele. Je třeba ověřit, že při silném soupeři neobchází společné bezpečné seskupení. Bone Guard/minion focus a jeho použití během push/farm nejsou ověřené pro každou kombinaci upgradu. Živý WK po reinkarnaci musí dál respektovat fontánový recovery, duch pokračovat v damage.

[Valve WK data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=42)

### Luna

Kontrolováno: Beam, Lunar Orbit, Eclipse, pasivní glaives/blessing, Scepter cast na entity a mana při farmení.

Opraveno: dvě porovnání síly skupin četla stejný enemy/ally seznam, takže nedetekovala převahu soupeře. Eclipse v teamfightu dříve vyžadoval kill jedním Beamem; nově může využít celou ulti proti alespoň dvěma zranitelným hrdinům. Bez naučeného Beam damage ji nezvolí. Opravená mana rezerva pro farmící Orbit odečítá skutečný cost místo násobení poměru zbývající many ještě aktuální manou. Beam interrupt předchází Orbit/Eclipse.

Otevřeno: množství creepů/illusion může absorbovat Eclipse a snížit hodnotu. Scepter verze cílí na sebe; volba vhodného spojence/místa není implementovaná. Starý nepoužívaný ConsiderMoonGlaives není aktivní combo. Potřeba herně porovnat iniciaci, dosah Eclipse a použití BKB/Mask of Madness.

[Valve Luna data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=48)

### Sven

Kontrolováno: God's Strength → Hammer → Warcry, splash stunu, kill, farm a změna attack targetu.

Opraveno: Hammer čte skutečný damage a AoE radius. Channel lze přerušit dříve než castnout God's Strength. Výběr bližšího attack targetu používal neexistující proměnnou; nyní používá zvolenou jednotku a čerstvý target tohoto callbacku, pak cache obnoví. Vzdálený channel bez bližší splash jednotky nezpůsobí tuto interrupt větev.

Otevřeno: obyčejné pořadí R → Q je vhodné pro připravený engage, méně pro krátké okno na stun; urgentní channel je nyní výjimka. Scepter cestování/alt-cast, Warcry pro spojence a reakce na disarm/BKB vyžadují cílené testy. Splash prognóza není simulace budoucí pozice všech jednotek.

[Valve Sven data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=18)

## Mid

### Zeus

Kontrolováno: Q last hit/harass, W entity/ground a talent, Jump, Nimbus, R globální kill, Lightning Hands/Static Field, rune návrat a vlastní escape.

Opraveno: W damage i jeho CastSafety klasifikace čtou runtime `damage`. R/W last-hit odhad už nedostává historických 9 % za naučené Lightning Hands; procento se čte ze skutečného Static Field. Oddělený escape dispatcher s ověřovaným směrem/přistáním zůstává aktivní.

Otevřeno: útočný Jump v ConsiderE je stále jednoduchý „cíl v shock range“. Nemá kompletní vyhodnocení výhodnosti skutečného přistání/facing jako escape dispatcher. Je třeba cíleně zkontrolovat cliff, skutečný směr skoku v klientu, landing a další krok; dosah shocku není délka skoku. Nutné dál ověřit šetření many, útěk z Rot/Dismember, bezpečný návrat z run a koordinaci s týmem. Automatické přepínání Lightning Hands podle lane equilibrium není řešené.

[Valve Zeus data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=22)

### Dragon Knight

Kontrolováno: Dragon Form → Breathe → Tail → Fireball, melee/ranged targeting, teamfight a obranný Tail.

Opraveno: Tail channel interrupt předchází transformaci a damage. Breathe Fire debuff již neblokuje Tail v hlavním teamfight výběru ani při obranném stunu. Breathe a Tail se mohou doplnit, jejich debuffy nejsou náhrada jeden druhého.

Otevřeno: normální engage stále preferuje Breathe před Tailem. Pro lov pohyblivého/escape cíle může být lepší Tail první; pro okamžitý kill Breathe první. To vyžaduje podmíněné combo podle cíle a možnosti navázat. Některé Tail větve dovolují přiblížení; TP ETA není komplexní pathfinding. Ověřit Fireball value a runtime range v Dragon Form.

[Valve DK data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=49)

### Sniper

Kontrolováno: Assassinate → Take Aim → Shrapnel → Grenade, target selection, dosah a bezpečnost Take Aim.

Opraveno: překlep `cout` blokoval multihero Shrapnel; nyní `count`. Q čte runtime cast range, nil AoE u creepů se nedereferencuje. Assassinate a společný odhad Zeusova R v jeho consideration čtou runtime special damage.

Otevřeno: Assassinate má i attack složku; současný forecast započítává pouze magický bonus, takže je konzervativní. Grenade je až za damage consideration, nemá kompletní analýzu směru knockbacku/přistání. Velmi blízký silný soupeř potřebuje escape před dlouhým castem. Starší Take Aim guard má vlastní testy; nový zápas musí potvrdit bezpečný rozestup proti SF/Pudge a channel Assassinate pod tlakem.

[Valve Sniper data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=35)

## Offlane

### Axe

Kontrolováno: Call/Hunger/Cull, prahový kill, blink iniciace ve společných systémech, ochrany cíle.

Opraveno: Cull execution threshold z runtime `damage`, ne historická formule. Debuff immunity jej neblokuje; stejně Call může přerušit immune cíl. Odstraněná asymetrická Cull výjimka pro bot Anti-Mage. Hunger kill estimate používá pure damage místo magického.

Otevřeno: Hunger forecast přes celé trvání nezaručuje kill, pokud soupeř debuff odstraní/ukončí. Cull obchází některé death prevention, ale proti reflected/spell-blocked cíli zůstává konzervativní. Potřeba herně ověřit Blink → Call → focus/Cull s týmem a neztrácení rozhodnutí při pohybu mezi creep/objective a fightem.

[Valve Axe data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=2)

### Tidehunter

Kontrolováno: Ravage, Gush, Anchor Smash, aktivní Kraken Shell a Dead in the Water.

Opraveno: Smash radius nebyl `radius` (neexistující special); nyní attack range + `additional_range`, takže blízký hero/camp je skutečně dosažitelný. Aktivní Kraken při retreat nově vyžaduje blízkého viditelného fyzického pursuera a fyzický odhad alespoň jako magický+pure. Nezpomaluje vlastní útěk jen proto, že blízko běží spell-damage soupeř. Self buff nemá důvod odmítat fyzického pursuera kvůli jeho BKB.

Otevřeno: fyzický engine odhad je heuristika, ne počet attacků blokovaných v příštích čtyřech sekundách. Ravage proti jednotlivci potřebuje přesnější hodnotu kill/follow-up; nesmí zůstat osamocený initiator. Dead in the Water je leash, nenahrazuje stun na libovolný channel. Ověřit Gush se Scepterem a nedávání Smashu na cíle, na které nemá efekt.

[Valve Tide data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=29)

### Centaur

Kontrolováno: vlastní bezpečný Stomp/Stampede escape, normální Stomp → Edge, team save, Work Horse/Hitch a objektivy.

Opraveno: Double Edge Roshan/Tormentor větve vracely pozitivní desire bez cíle. Nyní vracejí konkrétní objective target, takže dispatch nemá nil entity. Stávající vlastní únik s revalidací předchází běžné spell logice.

Otevřeno: self damage Edge je posuzovaný konzervativně; není kompletní plán výměny kill za vlastní život. Team Stampede/Hitch musí zohlednit, zda spolubojovník ještě potřebuje zůstat v boji. Při unsafe TP/farm cíli musí zareagovat společný travel/farm systém; samotné spelly to nezaručí.

[Valve Centaur data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=96)

## Support

### Lion

Kontrolováno: opener Hex/Impale, offensive versus defensive Drain, farm Q, Finger a talent/Scepter targeting.

Opraveno: Finger základ a Scepter splash radius čte runtime special values místo hardcoded level damage a zastaralého radius klíče. Dosavadní engagement Hex a farm Spike zůstávají zachované.

Otevřeno: normální návaznost Impale/Hex obsahuje pevný krátký interval; nejde o přesnou dobu zbývajícího disable/status resistance. Mana Drain na creepy může zvolit přiblížení před jiným úkolem. AoE Hex/Scepter splash vyžadují test skutečné geometrie a spell protection. Ověřit příchod ze stromů: disable před zbytečným autoattackem a žádný návrat k creepům u stále aktivního enemy fightu.

[Valve Lion data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=26)

### Vengeful Spirit

Kontrolováno: Swap save/engage, Missile, Wave, team follow-up a illusion/minion cesta.

Opraveno: Missile skutečný interrupt předchází Swap/Wave. Wave damage z runtime `damage`, nikoli prázdný AbilityDamage. Enemy Swap i Missile dispatch respektují advanced targeted protection; spojenecký save Swap nepřebírá nepřátelský Linken guard.

Otevřeno: normální Swap stále předchází Missile. Útočný Swap potřebuje pečlivější analýzu obou výsledných pozic, skutečně připraveného týmu a navazujícího disable. Scepter pokračování/illusion a reakce po Swap nejsou nově herně potvrzené. Neoznačovat izolovaný Swap + stun bez týmu jako hotové bezpečné combo.

[Valve Venge data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=20)

### Witch Doctor

Kontrolováno: Switcheroo save, Maledict/Cask/Ward, heal toggle, channel item combo a minion routing.

Opraveno: Cask používal bounce range z Death Ward, což dávalo špatný/ nulový AoE rozsah; nyní z Cask. Damage a rychlost jsou runtime, kill nepředpokládá vymyšlený garantovaný návrat bounce. Ready, ale nepoužitelný Cask/Maledict neblokuje Ward. Jediný disabled cíl může dostat Ward i při čtyřech spojencích poblíž. CastSurvival chrání začátek channelu.

Otevřeno: běžné pořadí Maledict → Cask → Ward funguje pro vhodné okno, pro unikajícího cíle může být lepší Cask první. Urgentní channel už je výjimka. Zbývá rozpočet many pro celé combo, hodnota Maledict proti heal/lifesteal, plné trvání Ward channelu a cancel při nové hrozbě. Death Ward je v MinionThink explicitně vynechaný: společný plán tak negarantuje ruční přesměrování wardy na focus target. Glimmer během channelu je záměrná podpůrná větev.

[Valve WD data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=30)

### Crystal Maiden

Kontrolováno: Clone, Nova, Frostbite, Freezing Field, pasivní aura a příslušné upgrady.

Opraveno: cached target se bere z proper hero targetu, ne prostě z aktuálně autoattackovaného creepa. Frostbite damage = runtime DPS × duration; kill estimate přidává dobu DoT. Field není zakázaný jen kvůli více než dvěma spojencům u stejného cíle a má CastSurvival guard.

Otevřeno: Nova → Frostbite nemusí být správné proti cíli, který ihned unikne; přerušení TP má samostatnou větev. Root není univerzální interrupt. Field potřebuje ochranu před konkrétním enemy disable, vhodnou pozici a případný cancel; začáteční guard nedokazuje přežití celé ulti. Ověřit skutečný směr Clone a použití Field upgradů. Pasivní Aura se už nyní nekouzlí přes `J.CanCastAbility`; nešlo o novou chybu vyžadující opravu.

[Valve CM data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=5)

### Lich

Kontrolováno: Chain Frost, shield/Nova ally assist, Gaze interrupt/ochrana channelu, Spire a mana.

Opraveno: Nova používá skutečný primary damage + AoE. Farm/push podmínka měla špatnou prioritu `and/or`, takže samotná core role mohla obejít zbytek podmínek; nyní jsou role/ally-count uvnitř závorek. Stávající nový Gaze full-channel guard a ally shield pořadí zůstávají.

Otevřeno: aktuální aktivní innate **Death Charge** není v hero SkillsComplement implementovaná; Lich tedy nevyužívá tuto mana/XP možnost. Zbývá výběr vhodného allied creepa s ohledem na spoluhráčův last hit. Spire → Chain Frost → Gaze není samostatně optimalizované combo. Je třeba zkontrolovat bounce partnery, creep soak, Scepter cast během Gaze a shield při skutečném physical fightu.

[Valve Lich data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=31)

### Warlock

Kontrolováno: Bonds → Offering / Refresher → Offering, Shadow Word, Upheaval, golem/minion routing a rušení channelu.

Opraveno: ready Bonds už nezablokuje Offering bez vhodného cíle. Pokud Q i R mají skutečně užitečné rozhodnutí a celé combo je zaplacené, Q může předcházet R. Refresher příprava rezervuje Q + dvě R + Refresher, takže Bonds nespotřebuje potřebnou combo manu. Pokud dřívější rozhodnutí declined Q/W/R, jejich pouhá readiness neblokuje Upheaval. Shadow Word může healnout i samotného Warlocka. Při zrušení nebezpečného channelu a vydání ústupu se callback ukončí; další spell ho ve stejném ticku nepřepíše.

Otevřeno: nouzová krátká Offering stun situace nemá univerzální prioritu před Bonds na každý single target. Heal výběr je podle HP, ne komplexní expected save/antiheal. Upheaval má jen počáteční channel odhad; golem focus a dlouhá channel stabilita potřebují herní ověření.

[Valve Warlock data](https://www.dota2.com/datafeed/herodata?language=english&hero_id=37)

## Co automatické ověření pokrývá

`tests/shai-hero-review.test.lua` načítá všech 15 skutečných hero modulů. Engine a build/helper observation jsou fixture; urgent interrupt helper a hero dispatch/Consider jsou skutečný kód. Survival/routing mají oddělené existující integrační sady; tato nová sada navíc ověřuje respektování survival veta v CM/WD dispatcheru.

44 scénářů ověřuje priority před jinak způsobilými spelly, skutečný dosah, neviditelné/illusion/immune/protected/busy cíle, poškození a DoT/regen, Eclipse proti zdravým cílům, porovnání skupin, Smash dosah, target Double Edge, Axe immunity, Finger, Shrapnel, Ward starvation, heal Warlocka, Q→R přípravu a mana pro double Offering, přerušení callbacku při ústupu, aktuální Sven target, Kraken profil a Field se čtyřmi spojenci. Negativní damage scénáře mají i pozitivní kontrolu, aby nemohly projít jen kvůli nedostupné schopnosti.

Celá `tools/Test-SHAI.ps1` obsahuje 33 Lua a dvě PowerShell sady. Syntax kontrola zahrnuje bot Lua a testy. Mock neprokazuje animaci, engine path, správný status resistance odhad ani přesný actual damage v klientu. Nejde o odehraných 44 bojů.

## Priorita dalšího ověření a implementace

1. **P1 kontrola skutečného fightu:** rozhodnutí skupiny → spell skutečně vydaný → spell skutečně zasáhl → navazující útok/disable → případné přerušení s důvodem. Nezaměňovat všechny healthy allies poblíž za skutečný follow-up. Zaměřit DK, WD, CM, Venge a normální WK Q.
2. **P1 escape a přistání:** útočný Zeus Jump a Sniper Grenade, obranný Jump přes cliff, post-Swap chování, fyzický Kraken versus spell damage. Testovat předchozí Pudge situace bez předpokladu, že bot zná neviditelný cooldown.
3. **P1 mana/nové abilities:** Lich Death Charge, rozpočet WD celého komba, CM Field a Shadow Word save; potvrdit skutečné ability names/slots/upgrades v lobby.
4. **P2 podmíněná komba:** Tail/Frostbite/Cask před damage proti unikajícímu cíli; disable návaznost podle remaining time/status resistance; Luna/Spire/Chain Frost bounce value, Ward/golem/minion focus; optimalizace v závislosti na BKB/Manta/Linken.
5. **P2 herní matrix:** postupně všichni hrdinové, ne jen náhodný draft. Raná linka, rovný fight, dominantní soupeř, obrana základny, ztráta vision, 2–5 členů týmu, nízké HP jednoho člena a dočasný duch. Soulad těchto scénářů je podmínka tvrzení „hraje správně“.

Dosavadní Wisdom, cestování, ward/deward, glyph, Roshan/Tormentor a obecné přepínání módů zůstávají v hlavním TODO; správná hero consideration sama tyto problémy neuzavírá.
