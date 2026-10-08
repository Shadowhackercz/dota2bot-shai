# Analýza chování SHAI

Wisdom podle uživatele pravidelně navštěvují poblíž příslušného času. To je pozitivní herní pozorování; Tormentor zatím zůstává otevřený. Další priorita je stabilita pohybu a smysluplné rozdělení farmy, boje a obrany.

## Záznam zápasu

V `bots/Customize/shai.lua` je pro vývoj zapnuté `BehaviorTrace = true`; lze vypnout bez změny rozhodování. Začít nový zápas. Před ním v konzoli zadat `con_logfile "shai-console.log"`, po testu `con_logfile ""`. Použít pro každý zápas jiný název souboru, aby se nemíchaly záznamy.

`[SHAI] behavior` sleduje každých nejméně 0,25 herní sekundy aktivní mód. Vypisuje nejvýše jednou za herní sekundu změněný stav a nejméně jednou za 10 sekund při pokračujících callbacks. Obsahuje čas, tým/hráče, hrdinu, mód a jeho naléhavost, HP/manu, pozici, proper target a attack target. Čítače jsou kumulativní: `switches` změny módu zaživa, `rapid` změny do 1 sekundy od předchozí změny, `reversals` návrat A→B→A do 2 sekund od vstupu do B. Smrt/reset času přeruší řetězec. Čítače zachytí i přepnutí, která kvůli omezení výpisu nemají vlastní řádek.

Jde o vzorkování aktivního módu, nikoli všechny kandidátní priority, důvody volby, příkazy ke kouzlení či úplnou historii pohybu. Změny rychlejší než interval mohou uniknout. Cíle stejného názvu nejsou tímto záznamem rozlišeny. Samotný návrat či vysoká naléhavost neprokazují chybu. Log nevysvětluje vše, co dělá engine/pathfinding, a nenahrazuje replay. Telemetrie sama nevydává akce ani nemění priority; režie a callbacky musí být ověřeny ve hře.

## Vyhledání úseků

```powershell
.\tools\Analyze-SHAI.ps1 -LogPath 'C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota\shai-console.log'
```

Výpis ukáže poslední kumulativní počty a úseky s rychlými změnami. Čas je v sekundách od začátku hry. Pro kontrolu začít přibližně 10 sekund před uvedeným časem; výpis je zpožděný omezením četnosti. Pokud log končí před závěrem zápasu, nejde o celkové počty za celý zápas.

## Co hodnotit

- **0–10 min:** last hity/deny, ztracené wave při runách, spotřeba many, harass bez zbytečné smrti, návrat na linku. Zapsat CS v 10. minutě a podmínky soupeře; nelze stanovit univerzální správné CS pro všechny role.
- **10–25 min:** otočky bez změny hrozby, docházka na smysluplný fight, oddělení carry farmy od podpory, reakce na útok na věž.
- **Po vyhraném fightu:** zda přeživší využijí prostor pro věž, objektiv či bezpečnou farmu. Nevyžadovat automatický push s nízkým HP nebo proti buybacku.
- **Boj:** viditelný platný cíl, dostupnost many/cooldownu, dosah a vhodné pořadí schopností. Nečinnost hodnotit proti těmto podmínkám, ne jen podle výsledné smrti.

U podezřelé situace zapsat čas, hrdinu, co viděl, jaký měl cíl a co by byla lepší akce. Nejdříve určit vrstvu problému: chybná priorita módu, nevhodný cíl, schopnost/předmět nebo pohyb. Doloženou opakovatelnou chybu převést na scénář testu skutečného modulu; upravit příčinu a ověřit nový zápas. Úspěšné testy dokazují dané scénáře, nikoli celkovou sílu AI.

Srovnání před/po používat na stejném poolu, obtížnosti, bez ekonomických buffů, s prohozenými stranami a ve více zápasech. Vyšší počet killů sám není dostatečný důkaz lepšího rozhodování.
