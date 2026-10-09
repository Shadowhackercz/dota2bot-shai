# Analýza chování SHAI

Wisdom podle uživatele pravidelně navštěvují poblíž příslušného času. To je pozitivní herní pozorování; Tormentor zatím zůstává otevřený. Další priorita je stabilita pohybu a smysluplné rozdělení farmy, boje a obrany.

## Záznam zápasu

V `bots/Customize/shai.lua` je pro vývoj zapnuté `BehaviorTrace = true`; lze vypnout bez změny rozhodování. **Původní návod s konzolovým `con_logfile` byl chybný a není platný.** Nainstalovaný Source 2 engine obsahuje startovací parametr `-con_logfile`, nikoli tento konzolový příkaz. Parametr je doložený i [záznamem v trackeru Valve](https://github.com/ValveSoftware/Dota-2/issues/2750).

1. Ve Steam → Dota 2 → Vlastnosti → Obecné → Možnosti spuštění přidat `-con_logfile`, ostatní parametry zachovat, a Dotu znovu spustit.
2. V projektu spustit `.\tools\Check-SHAILog.ps1 -Stage Prepare`. Vypíše unikátní příkaz `echo SHAI_LOG_START_...`; ten zadat do konzole Doty. Potom spustit `.\tools\Check-SHAILog.ps1 -Stage Console`. Ověří marker v `game/dota/console.log` a odmítne starý log. Zápas nezahajovat jen na základě nastaveného parametru; zápis ještě nebyl na tomto klientu ověřen za běhu.
3. Pokud se výstup nepropíše hned, ukončit krátký kontrolní běh Doty a soubor zkontrolovat poté. Bufferování může zpozdit zápis. Pro okamžité uložení aktuálního konzolového bufferu lze zkusit `condump`, který je v místním enginu přítomný; hledat nové `condump*.txt` / `condump*.log` v adresáři hry.
4. Nejprve vytvořit **krátké kontrolní lobby**, počkat alespoň 15 sekund a spustit `.\tools\Check-SHAILog.ps1 -Stage Bots`. Výchozí kontrola vyžaduje opakovanou diagnostiku **9 různých botů** po aktuálním markeru. Pro jiný počet lidí zadat `-ExpectedBots N`. V jiném umístění logu použít `-LogPath 'absolutní cesta'`. Chybějící telemetry není důkaz čistého rozhodování. Při bufferování krátký běh normálně ukončit a kontrolu opakovat nad uloženým souborem, než se pustíme do dlouhého testu.
5. Pro dlouhý zápas připravit nový marker po archivaci krátkého testu a znovu ověřit konzoli i botí diagnostiku. **Během tohoto zápasu neměnit skripty.** K podezřelé situaci zapsat herní čas a stručný popis. Pokud kontrola při běžícím klientu nevidí nové zprávy, nedělat z toho závěr o botím módu; nejprve rozlišit bufferování/chybějící zápis.
6. Po dokončení opustit zápas a do konzole zadat připravený `echo SHAI_LOG_END_...`, který vypsal krok Prepare. Normálně ukončit Dotu, aby se dopisoval buffer, a spustit `.\tools\Check-SHAILog.ps1 -Stage Archive`. Vyžaduje start/end marker i opakované botí záznamy, vypíše první/poslední čas a největší mezeru každého bota a vytvoří jedinečnou kopii v `artifacts/logs/`. **Před tímto krokem Dotu znovu nespouštět**; nový běh může původní log přepsat. Zachovat také nejnovější `.dem` pro kombinovanou analýzu. Parametr po testování případně odebrat.

Helper je ověřen simulovanými soubory (aktuální versus starý marker, chybějící telemetry, počet botů, end marker, přesnost zálohy a reset herního času). Skutečný herní zápis dosud potvrzený není. Výpis pokrytí je třeba srovnat s délkou zápasu; start/end marker neprokazuje absenci mezer ani záznam všech interních voleb. Vývojový log obsahuje existující mode trace a vybrané důvody objektivů, ne celý rozhodovací strom.

`condump` může zachránit pouze obsah dosud otevřené konzole, nikoli zaručeně celý zápas. Po zavření klienta bez průběžného záznamu nejde chybějící historii tímto příkazem obnovit. Restartovaný klient už obsah staré konzole nemá.

`[SHAI] behavior` sleduje každých nejméně 0,25 herní sekundy aktivní mód. Vypisuje nejvýše jednou za herní sekundu změněný stav a nejméně jednou za 10 sekund při pokračujících callbacks. Obsahuje čas, tým/hráče, hrdinu, mód a jeho naléhavost, HP/manu, pozici, proper target a attack target. Čítače jsou kumulativní: `switches` změny módu zaživa, `rapid` změny do 1 sekundy od předchozí změny, `reversals` návrat A→B→A do 2 sekund od vstupu do B. Smrt/reset času přeruší řetězec. Čítače zachytí i přepnutí, která kvůli omezení výpisu nemají vlastní řádek.

Jde o vzorkování aktivního módu, nikoli všechny kandidátní priority, důvody volby, příkazy ke kouzlení či úplnou historii pohybu. Změny rychlejší než interval mohou uniknout. Cíle stejného názvu nejsou tímto záznamem rozlišeny. Samotný návrat či vysoká naléhavost neprokazují chybu. Log nevysvětluje vše, co dělá engine/pathfinding, a nenahrazuje replay. Telemetrie sama nevydává akce ani nemění priority; režie a callbacky musí být ověřeny ve hře.

## Vyhledání úseků

První opravy podle replaye přidávají `[SHAI] safety`: `reason=unsafe-farm` uvádí viditelného soupeře a poměr odhadovaného příchozího damage k aktuálním HP; `reason=cast-penalty` uvádí schopnost, účel, důvod odmítnutí a odhad dodatečné ceny Curse / damage Last Word. `known=false` znamená, že aktuální cena není známá, nikoli nulovou skutečnou cenu. Hodnoty vycházejí z posledního viditelného Silencera a platí nejvýše 15 s. Každý helper vypíše nanejvýš první blokaci za 5 s na bota; log není seznam všech odmítnutých ani povolených castů. Zprávy se vypisují jen při zapnutém `BehaviorTrace`. Odhady a skutečný výsledek porovnat s replayem.

V příštím testu sledovat zvlášť: klidnou farmu bez falešného ústupu, přiblížení výrazně silnějšího soupeře, skutečně bojujícího spojence, Zeusovo Q/W pod Curse (harass versus bezpečný last hit/kill/interrupt), jeho Jump při ústupu a Warlockův cast pod smrtícím Last Word. Cílem není univerzální zákaz kouzlení pod debuffem. Před dlouhým zápasem dokončit kontrolu skutečného logu výše.

`[SHAI] gank` popisuje společný plán: `phase=gather`, `approach`, `engage`, `declined` nebo `abort`, důvod, cíl a počet členů. Odchod nezpůsobilého člena má samostatný `[SHAI] gank-member`. Sledovat od 10. minuty: dominantní viditelný soupeř mimo věž, alespoň tři připravení boti poblíž, dostatek damage a kontrol. Porovnat BKB připravené/aktivní/nedostupné, Mantu proti Orchidu, dostupný Hex a zranění jednoho člena už během boje. Skupina má pokračovat při stále proveditelném killu; odchod člena se nesmí interpretovat jako automatický příkaz všem utéct. Cíl bez dostatečné příležitosti nemá vyvolat sebevražedný gank. `declined` se vypíše nejvýše jednou za 5 s; absence zprávy není důkaz, že se bot vůbec nezabýval bojem. Role jednotlivých ability/item callbacků a sdílení plánu přes entity pole musí ověřit klient.

```powershell
.\tools\Analyze-SHAI.ps1 -LogPath 'C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota\console.log'
```

Výpis ukáže poslední kumulativní počty a úseky s rychlými změnami. Čas je v sekundách od začátku hry. Pro kontrolu začít přibližně 10 sekund před uvedeným časem; výpis je zpožděný omezením četnosti. Pokud log končí před závěrem zápasu, nejde o celkové počty za celý zápas.

## Co hodnotit

Nové příkazy: v bezpečném kontrolním lobby nejprve vyvolat `!roshan`, potom `!stop roshan`; všechny vybrané boty mají přestat usilovat o objektiv a přijít jedna anglická odpověď. `!normal` obnoví běžné rozhodování, nikoli starou výzvu. Totéž ověřit na autonomním Tormentor scoutingu/útoku a `!stop tormentor`; `!stop objectives` blokuje oba, ne runy/Wisdom. Ověřit také doběhnutí 60 sekund, nepřátelský příkaz, smrt/respawn a pokračování sebeobrany. Diagnostic `[SHAI] objective-command` obsahuje čas, autora, příkaz a expiraci.

Rozšíření ganku má `[SHAI] gank-reinforce`: důvod, původní/nový počet a fázi. Sledovat, zda noví členové opravdu přicházejí ke stejnému cíli a zda plán nezůstává aktivní jen díky vzdálené pomoci. Během engage může přibrat jen bota do 1100; během gather/approach do 2400. Nečekat nábor přes celou mapu nebo automatické TP. Příchod posily neprodlužuje původní deadline 18 s. Tyto zprávy se vypisují při skutečně přijatém rozšíření, nikoli při každém kandidátovi.

- **0–10 min:** last hity/deny, ztracené wave při runách, spotřeba many, harass bez zbytečné smrti, návrat na linku. Zapsat CS v 10. minutě a podmínky soupeře; nelze stanovit univerzální správné CS pro všechny role.
- **10–25 min:** otočky bez změny hrozby, docházka na smysluplný fight, oddělení carry farmy od podpory, reakce na útok na věž.
- **Po vyhraném fightu:** zda přeživší využijí prostor pro věž, objektiv či bezpečnou farmu. Nevyžadovat automatický push s nízkým HP nebo proti buybacku.
- **Boj:** viditelný platný cíl, dostupnost many/cooldownu, dosah a vhodné pořadí schopností. Nečinnost hodnotit proti těmto podmínkám, ne jen podle výsledné smrti.

U podezřelé situace zapsat čas, hrdinu, co viděl, jaký měl cíl a co by byla lepší akce. Nejdříve určit vrstvu problému: chybná priorita módu, nevhodný cíl, schopnost/předmět nebo pohyb. Doloženou opakovatelnou chybu převést na scénář testu skutečného modulu; upravit příčinu a ověřit nový zápas. Úspěšné testy dokazují dané scénáře, nikoli celkovou sílu AI.

Srovnání před/po používat na stejném poolu, obtížnosti, bez ekonomických buffů, s prohozenými stranami a ve více zápasech. Vyšší počet killů sám není dostatečný důkaz lepšího rozhodování.

Poslední test se podařilo zachránit replayem i přes chybějící console log. Jeho datová analýza je v [SHAI-REPLAY-9035705167.md](SHAI-REPLAY-9035705167.md), navazující úkoly v [SHAI-TODO.md](SHAI-TODO.md). Replay není nutné přehrávat v klientu pro získání combat událostí; samotné dekódování však neobnoví chybějící Lua důvody.
