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
5. Zahájit zápas. Automaticky generovaná botí jména mají příponu **`.SHAI`**. Vlastní ručně nastavená jména ji mohou vynechat.

Steam Workshop položka SHAI zatím není publikovaná. Náš GitHub fork sám nevytvoří novou nabídku ve Workshopu; nyní používáme Local Dev Script.

## Fokusovaný pool

Pool je v `bots/Customize/shai.lua`, nezávisle na případném starém `game/Customize/general.lua`. Ostatní hrdinové zůstávají ve zdrojích, ale jsou vyřazeni z botího draftu. Hráč si v klientu může vybrat libovolného hrdinu.

- Carry: Wraith King, Luna, Sven.
- Mid: Zeus, Dragon Knight, Sniper.
- Offlane: Axe, Tidehunter, Centaur Warrunner.
- Support: Lion, Vengeful Spirit, Witch Doctor, Crystal Maiden, Lich, Warlock.

Rozdělení je orientační; draft používá existující váhy vhodnosti pro role. Omezení lze vypnout přes `HeroPoolEnabled = false`, jednotlivé hrdiny přidat do `HeroPool`. Nedávat prázdný pool ani nezabanovat všechny jeho členy: skript záměrně nevybere zakázaného hrdinu jako fallback.

První podporovaný testovací režim je All Pick, následně Turbo. Ostatní zděděné režimy nebyly pro SHAI ověřeny. Herní logika hrdinů je zatím původní OHA; nová jména a pool neznamenají hotová vylepšení AI.

## Vývoj a ověření

Změna zdrojů → lokální test → commit → push do vývojové větve na GitHubu. Během rozehraného zápasu soubory neupravovat; změny testovat v novém lobby/zápase.

Samostatná kontrola draftu běží přes Fengari (Lua 5.3, ne herní Lua VM):

```powershell
npm.cmd install --prefix .tools/lua --no-package-lock --ignore-scripts fengari-node-cli
.\.tools\lua\node_modules\.bin\fengari.cmd -e "local ok, err = pcall(dofile, 'tests/shai-selection.test.lua'); if not ok then print(err); os.exit(1) end"
```

Kontrola ověřuje omezený pool, kompletní drafty, duplicity mezi týmy, lidského hrdinu mimo pool, malé pooly a vyčerpání přes bany. Nenahrazuje test v Dotě.
