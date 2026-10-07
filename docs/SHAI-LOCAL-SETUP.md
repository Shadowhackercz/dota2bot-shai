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

## Když se zápas nespustí

Čekání na hledání lobby/serveru je potřeba odlišit od prodlev při výběru hrdinů. Zkontrolovat **Local Host**; samotné nastavení Local Dev Script neurčuje hostování zápasu. Zkrácení draftu neřeší hledání serveru.

Po načtení výběru hrdinů skript vypisuje do herní konzole zprávy začínající `[SHAI]`, včetně počtu povolených hrdinů a jednotlivých výběrů. Tyto zprávy a prefixy `[WARN]` / `[ERROR]` se zobrazují i bez zapnutého DebugMode. Pro záznam konzole lze před novým pokusem zadat `con_logfile "shai-console.log"`; záznam vypnout přes `con_logfile ""`. Hledat log v adresáři `game/dota` instalace Doty. Nepřítomnost zpráv sama o sobě nerozlišuje chybu hostování od chyby při načítání Lua.

První podporovaný testovací režim je All Pick, následně Turbo. Ostatní zděděné režimy nebyly pro SHAI ověřeny. Herní logika hrdinů je zatím původní OHA; nová jména a pool neznamenají hotová vylepšení AI.

SHAI nepoužívá smoke před časem 0:00. Původní OHA jej používalo automaticky v poslední minutě před začátkem bez koordinovaného plánu. Pozdější pravidla pro použití smoke zatím zůstávají zděděná.

## Vývoj a ověření

Změna zdrojů → lokální test → commit → push do vývojové větve na GitHubu. Během rozehraného zápasu soubory neupravovat; změny testovat v novém lobby/zápase.

Samostatná kontrola draftu běží přes Fengari (Lua 5.3, ne herní Lua VM):

```powershell
npm.cmd install --prefix .tools/lua --no-package-lock --ignore-scripts fengari-node-cli
.\.tools\lua\node_modules\.bin\fengari.cmd -e "local ok, err = pcall(dofile, 'tests/shai-selection.test.lua'); if not ok then print(err); os.exit(1) end"
```

Kontrola ověřuje omezený pool, kompletní drafty, role a časování výběru, duplicity mezi týmy, lidského hrdinu mimo pool, malé pooly a vyčerpání přes bany. Nenahrazuje test v Dotě.
