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
- První úpravy: název SHAI, uzavřený pool 15 hrdinů, omezený draft a helper pro místní instalaci. Podrobnosti v `docs/SHAI-LOCAL-SETUP.md`.

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

Místní Dota je propojena junctionem s projektovým `bots/`. Uživatel potvrdil načtení a začátek zápasu; celý zápas a střední/pozdní fáze zatím nejsou ověřené. Logika schopností jednotlivých hrdinů zatím zůstává převzatá z OHA.

## První opravy rozhodování

- Pool zůstává 15 hrdinů, tři kandidáti pro každou pozici. Další hrdiny zatím nezapínat.
- Smoke se nepoužívá automaticky před 0:00. Krátká generovaná jména mají formát `SHAI.Nova`.
- Roshan: kontrola dostatečného poškození se přepočítává při každém vyhodnocení, místo aby jednou dosažená připravenost zůstala trvale zapamatovaná.
- Iluze se nezapočítávají do seznamu pro tuto kontrolu ani do počtu core hrdinů bez volného místa.
- Bot pod 40 % zdraví neupřednostňuje Roshan mód. Jde o počáteční konzervativní hranici, kterou je potřeba vyhodnotit ve hře; samotný zákaz módu nezaručuje konkrétní pohyb k léčení.
- Naléhavost dokončení viditelného Roshana se počítá z podílu jeho zdraví 0–0,5. Dřívější rozsah 0–100 dával téměř maximální naléhavost už při 49 % zdraví.

Regresní test `tests/shai-roshan.test.lua` spouští skutečný Roshan mód se simulovaným stavem hry: ztráta DPS, nízké zdraví, okolní nepřítel, početní nevýhoda, iluze a dokončení Roshana. Běží přes Fengari, nikoli v herním Lua VM. Původní odhad DPS a mapových podmínek zůstává přibližný a tato změna nepotvrzuje, že je rozhodování o Roshanovi již kompletně správné.

Další herní ověření: celý All Pick zápas, zejména zda raněný bot přestane upřednostňovat Roshana a zda tým ruší objektiv po ztrátě poškození. Pro ladění jednotlivých hrdinů začít s Wraith Kingem, Zeusem, Axem, Lionem a Crystal Maiden. Zbývající kandidáti zachovávají variabilitu draftu. Potom cíleně řešit linku, ústup a schopnosti; neslibovat kvalitnější všech 15 hrdinů jen na základě společných oprav.

Následující audit a opravy: [SHAI-BEHAVIOR-AUDIT.md](SHAI-BEHAVIOR-AUDIT.md). Opraveny rezervace many a ústup Wraith Kinga, přerušování mimo dosah u WK/Liona a přepisování bezpečnostních limitů při pushování. Všechny regresní testy spouští `tools/Test-SHAI.ps1`; herní porovnání celých zápasů zůstává otevřené.
