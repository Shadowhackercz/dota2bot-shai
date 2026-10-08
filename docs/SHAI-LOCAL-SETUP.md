# SHAI: místní načtení v Dotě 2

Zdrojový projekt je v `C:\Users\L\Documents\ChatGPT\Dotabot`. GitHub uchovává commity a větve; hra čte místní `bots/`. Stažení z GitHubu není potřeba po každé úpravě.

## Instalace

`tools/Install-SHAI.ps1` vytvoří adresářový junction z `game/dota/scripts/vscripts/bots` v instalaci Doty do projektového `bots/`. Zdroj zůstává v projektu a změny se projeví při načtení dalšího zápasu. Existující `bots` helper zachová pod záložním názvem, nic nemaže. Opakované spuštění se stejným cílem nic nemění.

Výchozí instalace:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Install-SHAI.ps1
```

Pro jinou knihovnu Steam použít parametr `-DotaPath 'D:\SteamLibrary\steamapps\common\dota 2 beta'`. Zápis do Program Files může vyžadovat zvýšené oprávnění.

## První zápas

1. Spustit Dotu 2 a vytvořit **Custom Lobby**.
2. Nastavit server **Local Host**, mód **All Pick**.
3. Pro **Radiant i Dire** vybrat **Local Dev Script** a doplnit volná místa boty.
4. Pro výchozí test zvolit obtížnost **Unfair**. Nepřidávat FretBots/Buff ani jejich ekonomické bonusy.
5. Zahájit zápas. Automaticky generovaná botí jména jsou krátká, například **`SHAI.Nova`**, a neopakují se mezi týmy. Vlastní ručně nastavená jména zůstávají zachována.

Steam Workshop položka SHAI zatím není publikovaná. Náš GitHub fork sám nevytvoří novou nabídku ve Workshopu; nyní používáme Local Dev Script.

## Fokusovaný pool

Pool je v `bots/Customize/shai.lua`, nezávisle na případném starém `game/Customize/general.lua`. Ostatní hrdinové zůstávají ve zdrojích, ale jsou vyřazeni z botího draftu. Hráč si v klientu může vybrat libovolného hrdinu.

- Carry: Wraith King, Luna, Sven.
- Mid: Zeus, Dragon Knight, Sniper.
- Offlane: Axe, Tidehunter, Centaur Warrunner.
- Pozice 4: Lion, Vengeful Spirit, Witch Doctor.
- Pozice 5: Crystal Maiden, Lich, Warlock.

Draft přednostně vybírá z příslušného seznamu v `RolePools`; `HeroPool` se z nich automaticky sestaví. Omezení lze vypnout přes `HeroPoolEnabled = false`, jednotlivé hrdiny přidat do `RolePools`. Při vyčerpání role může vybrat jiného povoleného hrdinu. Nedávat prázdný pool ani nezabanovat všechny jeho členy: skript záměrně nevybere zakázaného hrdinu jako fallback.

Po spuštění botího draftu jsou jednotlivé výběry rozestoupené přibližně po sekundě, stejně pro Radiant i Dire. Zděděné čekání na lidský výběr může začátek odložit. Výchozí konfigurace vypíná trash talk i GPT odpovědi; starší externí `game/Customize/general.lua` může tato nastavení přepsat.

## Příkazy pro linky před začátkem hry

V pre-game (po výběru hrdinů, před začátkem zápasu) lze napsat do chatu:

- `!mid`: převezmeš mid, tedy pozici 2.
- `!top`: převezmeš core na horní lince. Radiant pos 3, Dire pos 1.
- `!bottom` nebo `!bot`: převezmeš core na spodní lince. Radiant pos 1, Dire pos 3.

Po prvním příkazu support zůstává na lince. Pokud stejnou linku požádá druhý hráč, převezme její supportovu roli (5 na safelane, 4 na offlane); jinému člověku se role nebere. Opakování příkazu stejným hráčem pouze potvrzuje jeho volbu, botí support zůstává na lince. Automatické vyklizení linky pro sólo hráče se neprovádí.

`!pos N` zůstává dostupné pro přímý výběr role. Samotné slovo `mid` bez vykřičníku není příkaz. Nové příkazy mění pouze vlastní tým; lze je napsat i do all chatu. Fungují v pre-game, nikoli jako rozkaz k okamžitému přemístění během rozehraného zápasu. Přidělení role i lane výstup jsou ověřené simulací, herní callback a skutečný příchod na linku je potřeba ověřit v novém zápase.

## Týmová výzva k Roshanovi

Během zápasu napiš `!roshan` nebo `!rosh`. Odpoví jeden živý bot do týmového chatu, anglicky, i když příkaz napíšeš do all chatu. Samotné `rosh` / `roshan` bez vykřičníku není příkaz. Cizí tým ani botí zprávy výzvu nespustí. Mezi odpověďmi stejného mluvčího je minimálně 8 herních sekund; po jeho smrti může odpovědět jiný bot.

Souhlas vyžaduje živého hráče s alespoň 55 % HP do 4500 jednotek od aktuálního místa Roshana a dva skutečné boty ve stejné vzdálenosti, s alespoň 55 % HP a kladným výsledkem jejich Roshanova módu. Alespoň jeden účastník musí být core na úrovni 12+ s alespoň 65 % HP. Tým nesmí být početně oslabený proti živým soupeřům, základna ohrožená, Roshan nedostupný nebo těsně před přesunem a okolí jeho místa nesmí mít známé nepřátele. Odhad fyzického poškození se počítá z této skupiny, nikoli ze vzdálených hrdinů. Ostatním lidem se účast automaticky nepředpokládá.

Při souhlasu zvolení boti dostanou na 30 herních sekund zvýšenou prioritu Roshanova módu 0,95. Během vyhodnocení dál platí jeho původní bezpečnostní kontroly a znovu se ověřují zdraví, přežití, vzdálenost a poškození účastníků i známá hrozba u cíle. Po vypršení se obnoví běžné rozhodování; jde o plán, ne bezpodmínečný příkaz ani záruku zabití. Pohyb ke skutečnému cíli stále řídí Roshanův mód enginu. Automatická obecná hláška o Roshanovi je během platné výzvy potlačená.

Typické odpovědi: `Yes, we can try Roshan. Group up - I will reassess if it becomes unsafe.`, `Not yet - we need more damage.`, `Not now - defend our base.` Důvod se zapisuje i jako `[SHAI] roshan-request`. Pokud mód některého bota ještě nemá inicializovaný evaluator, bot se nepovažuje za připraveného. Odhad poškození není simulace odrazu/útoků Roshana, healů, spellů ani plné fyzické redukce podle aktuálního patche; schopnost přežít se odhaduje HP/rolí/úrovní. Skutečnou jednu odpověď a přesun skupiny je potřeba potvrdit v novém zápase.

## Když se zápas nespustí

Čekání na hledání lobby/serveru je potřeba odlišit od prodlev při výběru hrdinů. Zkontrolovat **Local Host**; samotné nastavení Local Dev Script neurčuje hostování zápasu. Zkrácení draftu neřeší hledání serveru.

Po načtení výběru hrdinů skript vypisuje do herní konzole zprávy začínající `[SHAI]`, včetně počtu povolených hrdinů a jednotlivých výběrů. Tyto zprávy a prefixy `[WARN]` / `[ERROR]` se zobrazují i bez zapnutého DebugMode. Pro záznam konzole lze před novým pokusem zadat `con_logfile "shai-console.log"`; záznam vypnout přes `con_logfile ""`. Hledat log v adresáři `game/dota` instalace Doty. Nepřítomnost zpráv sama o sobě nerozlišuje chybu hostování od chyby při načítání Lua.

První podporovaný testovací režim je All Pick, následně Turbo. Ostatní zděděné režimy nebyly pro SHAI ověřeny. Většina herní logiky je převzatá z OHA; konkrétní opravy SHAI eviduje audit níže. Nová jména a pool neznamenají hotová vylepšení AI.

SHAI nepoužívá smoke před časem 0:00. Původní OHA jej používalo automaticky v poslední minutě před začátkem bez koordinovaného plánu. Pozdější pravidla pro použití smoke zatím zůstávají zděděná.

## Vývoj a ověření

Změna zdrojů → lokální test → commit → push do vývojové větve na GitHubu. Během rozehraného zápasu soubory neupravovat; změny testovat v novém lobby/zápase.

Samostatná kontrola draftu běží přes Fengari (Lua 5.3, ne herní Lua VM):

```powershell
npm.cmd install --prefix .tools/lua --no-package-lock --ignore-scripts fengari-node-cli
.\.tools\lua\node_modules\.bin\fengari.cmd -e "local ok, err = pcall(dofile, 'tests/shai-selection.test.lua'); if not ok then print(err); os.exit(1) end"
```

Kontrola ověřuje omezený pool, kompletní drafty, role a časování výběru, duplicity mezi týmy, lidského hrdinu mimo pool, malé pooly a vyčerpání přes bany. Nenahrazuje test v Dotě.

Všechny kontroly draftu i rozhodování nyní spouští `.\tools\Test-SHAI.ps1`. Přehled skutečně ověřených oprav a zbývajících herních testů je v [SHAI-BEHAVIOR-AUDIT.md](SHAI-BEHAVIOR-AUDIT.md).

Postup záznamu módů a hledání podezřelých rozhodnutí je v [SHAI-TESTOVANI-CHOVANI.md](SHAI-TESTOVANI-CHOVANI.md). Vývojová konfigurace nyní zapíná `BehaviorTrace`; vypíná se v `bots/Customize/shai.lua`. Log analyzuje `tools/Analyze-SHAI.ps1`.
