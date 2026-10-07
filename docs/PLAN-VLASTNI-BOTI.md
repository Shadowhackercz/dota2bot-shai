# Vlastní skriptovaní boti: výchozí rozhodnutí

Datum: 7. 10. 2026.

## Přijatý směr

- Základ: Open Hyper AI (`forest0xia/dota2bot-OpenHyperAI`).
- Výstup: čistý bot skript pro běžnou Dotu 2, s cílem distribuce přes Workshop.
- Priorita: kvalita rozhodování a spolupráce; náročnost nezvyšovat ekonomickými bonusy.
- Vlastní server ani externí AI služba nejsou součástí prvního cíle.
- GitHub fork: https://github.com/Shadowhackercz/dota2bot-shai. Lokální repozitář zachovává historii původního upstreamu.

## Připravený repozitář

- `upstream`: https://github.com/forest0xia/dota2bot-OpenHyperAI.git
- Výchozí commit: `cb814c6c8dc51ed08045d6efd9f4a48147992711`.
- Vývojová větev: `codex/script-foundation`.
- `origin`: https://github.com/Shadowhackercz/dota2bot-shai.git
- Zdrojové botí soubory zatím bez změn. Průzkum zůstává v `docs/PRUZKUM-DOTA2-BOTI.md`.

## Spolupráce týmu a člověka

Požadovaný směr: boti sdílejí týmový záměr a mohou požádat člověka o rozhodnutí. Příklad: „Jdeme Roshan? ano/ne“. Zamítnutí dočasně blokuje tento záměr a po vypršení platnosti se situace znovu vyhodnotí.

Před implementací ověřit v aktuální hře:

1. Životnost chat callbacku po hero selection a jeho možnou registraci během hry. OHA již používá `InstallChatCallback` v `hero_selection.lua`; existence této registrace sama nepotvrzuje trvalý runtime kanál.
2. Rozsah sdílení Lua stavu mezi boty stejného týmu. Nepředpokládat bez testu společné module globals mezi oddělenými VM.
3. Možnost bezpečně určit tým odesílatele a ignorovat příkazy protivníků. All-chat sám o sobě nepředstavuje důvěryhodný týmový příkaz.

Navržený protokol pro pozdější implementaci:

- jeden týmový návrh má ID, autora, čas vypršení a případné zamítnutí;
- stručné „ano/ne“ přijímat jen při jednoznačně čekajícím návrhu;
- jedno zamítnutí spojence může na omezenou dobu zabránit zahájení dobrovolného objektivu;
- souhlas nenahrazuje bezpečnostní podmínky: chybějící zdraví, mana či protivník mohou plán zrušit;
- bez odpovědi funguje autonomní rozhodování, bot nesmí nekonečně čekat;
- cooldown dotazů zabrání chat spamu;
- stav je omezený na konkrétní tým a resetuje se pro nový zápas;
- později jednoznačné příkazy typu `!roshan no`, `!defend mid`, `!group`.

Konkrétní syntaxe a délky časovačů jsou návrh, nikoli již implementovaná funkce.

## První implementační milník

1. Potvrdit herní mód a současný patch na testované instalaci.
2. Ověřit načtení původního OHA a připravit reprodukce tří problémů: nečinnost, nevhodný ústup z fightu, nevyužití vyhraného fightu k objektivu.
3. Přidat diagnostiku důvodů rozhodnutí a ověřit runtime chat + týmový stav.
4. Zavést malý, testovatelný týmový protokol; poté napojovat jednotlivé módy.
5. Ověřovat proti původní verzi, s prohozenými stranami a bez bonusů obtížnosti.

Tento dokument zaznamenává směr projektu. Herní logika ani integrace do instalace Doty nebyly v přípravné fázi měněny.
