# Průzkum: jak vytvořit výrazně lepší boty pro Dotu 2

Stav ověřený 7. 10. 2026. Průzkum zahrnuje veřejné repozitáře, hlášení problémů, API reference a statické čtení stažených zdrojů. Neproběhly vlastní zápasy ani testy v enginu; hodnocení skutečné herní síly je proto zatím hypotéza.

## Doporučení

Vlastní odvozená verze Open Hyper AI je realistická cesta. První cíl by měl být tým, který spolehlivě hraje základní Dotu: pomáhá spoluhráčům, neosciluje mezi útokem a útěkem, správně rozděluje farmu a využívá vyhrané souboje k objektivům. Začít přibližně 10–15 hrdiny pokrývajícími všechny role a rozšiřovat až po ověření.

Za základ bych předběžně zvolil upstream OHA. Jeho existující hrdiny, nákupy, miniony a instalaci lze zachovat; největší investici zaslouží společné rozhodování. Fork `dragonghy/dota2bot` stojí za důkladné porovnání kvůli testovací infrastruktuře a jednotlivým opravám, ale jeho změny často míří na Turbo. Bez ověření nelze předpokládat, že jsou lepší i pro standardní All Pick.

Nemáme podklady pro slib určitého MMR, úrovně Immortal ani překonání dobrých lidských týmů. Máme podklady pro projekt s konkrétními a měřitelnými opravami.

## 1. Open Hyper AI: co je skutečně k dispozici

- Veřejný [repozitář](https://github.com/forest0xia/dota2bot-OpenHyperAI) obsahuje funkční základ v Lua, část společných modulů má zdroj v TypeScriptu a generuje se přes TypeScriptToLua. [Konfigurace](https://github.com/forest0xia/dota2bot-OpenHyperAI/blob/main/tsconfig-tstl.json) cílí na Lua 5.1. Úpravy generovaných souborů musí respektovat jejich TS zdroj, jinak je další build přepíše.
- README deklaruje podporu 127 hrdinů a patchů 7.41/7.41a. To je deklarace pokrytí, nikoli důkaz kvality jednotlivých hrdinů. V našem staženém stromu je 274 Lua souborů v `bots/`, 128 souborů `BotLib/hero_*.lua` a přibližně 168 tisíc neprázdných Lua řádků. Počet souborů není počet plně podporovaných hrdinů.
- API GitHubu při průzkumu vracelo pro `main` commit `cb814c6c8dc51ed08045d6efd9f4a48147992711`, čas `2026-04-03T00:43:36Z`. Interní `bots/FunLib/version.lua` uvádí `0.7.41 - 2026/04/02`.
- Oficiální [seznam patchů Dota 2](https://www.dota2.com/datafeed/patchnoteslist?language=english) již obsahuje 7.41f. Rozdíl mezi deklarovaným patchem botů a současnou hrou je důvod nejprve ověřit kompatibilitu; neprokazuje, že každý modul je rozbitý.
- [Licence repozitáře](https://github.com/forest0xia/dota2bot-OpenHyperAI/blob/main/LICENSE) je MIT a výslovně umožňuje úpravy i distribuci při zachování uvedeného copyrightu a licenčního oznámení. Při přebírání dalších projektů je nutné přečíst jejich vlastní licence a zachovat případná oznámení převzatých komponent.
- Autorův [návod](https://github.com/forest0xia/dota2bot-OpenHyperAI/discussions/68) vyžaduje Custom Lobby / Local Host. Pro vývoj použít vlastní kopii přes Local Dev Script, oddělenou od automaticky aktualizované instalace Workshopu.

OHA používá rozsáhlý ručně psaný systém pravidel. Název ani volitelný chatbot neznamenají, že herní rozhodování zajišťuje naučená neuronová síť.

## 2. Další relevantní projekty

| Projekt | Co nabízí | Význam pro náš projekt |
|---|---|---|
| [Open Hyper AI](https://github.com/forest0xia/dota2bot-OpenHyperAI) | Široké pokrytí hrdinů a herních činností, konfigurace, FretBots integrace | Předběžně nejpraktičtější základ pro vlastní odvozenou verzi |
| [Tinkering ABo(u)t — ryndrb](https://github.com/ryndrb/dota2bot) | Příbuzná větev Beginner AI; README při průzkumu označené 7.41f; autor aktualizuje hlavně GitHub, Workshop méně | Velmi relevantní kandidát pro porovnání aktuální kompatibility a společné logiky |
| [PhalanxBot](https://steamcommunity.com/sharedfiles/filedetails/?id=2873408973) | Agresivnější styl; autor přepisuje priority a funkce módů | Dobré srovnání rozhodnosti. Stránka uvádí Local Host a omezení přiřazení rolí na Radiant; autor v zářijovém komentáři uvádí rozbité kritické funkce vývoje od Valve. Není doložený univerzální vítěz |
| [Ranked Matchmaking AI](https://github.com/adam3q/dota2ai) | Osvědčená rodina skriptů, přes 100 deklarovaných hrdinů, vlastní ability/item/strategy logika | Další soupeř do testů a zdroj porovnání; popularita sama neprokazuje aktuální sílu |
| [BOT Experiment — FuriousPuppy](https://github.com/furiouspuppy/Dota2_Bots) | Veřejný zdroj historicky důležitého botího systému | Číst kvůli konkrétním řešením, před převzetím ověřit kompatibilitu se současnou hrou |
| [ExtremePush](https://github.com/insraq/dota2bots) | Vlastní strategické přístupy, historická inspirace dalších botů | Inspirace pro objektivy a koordinaci, ne automaticky hotová současná náhrada |
| [FretBots](https://github.com/fretmute/fretbots) | Přidává ekonomické a jiné bonusy k existujícím behaviorálním skriptům | Volitelná vrstva obtížnosti; při hodnocení kvality rozhodování vypnout bonusy a oddělit nutné kompatibilitní workaroundy |
| [dragonghy/dota2bot](https://github.com/dragonghy/dota2bot) | OHA fork, malý fokusovaný pool, testy, replay analýza, experimentální změny | Nejcennější nalezený zdroj metodiky a infrastruktury. Zvlášť ověřit Turbo podmínky a zapnutí experimentů |
| [canshuqwp/OHA](https://github.com/canshuqwp/dota2bot-OpenHyperAI) | Další fork pracující na nečinnosti a obranném chování | Prověřit jednotlivé opravy; související issue hlásí, že nečinnost ještě není úplně vyřešena |

U Sirius AI jsem v tomto průzkumu neověřil dostatečně přesvědčivý aktuální zdrojový repozitář a výsledky pro současný patch, proto jej nedoporučuji jako základ jen na základě starších doporučení.

### Důležitý nález: dokumentace forku není celá aktuální

README `dragonghy/dota2bot` a `docs/PROJECT.md` ještě popisují některé prvotní kroky jako nedokončené. Stažené zdroje ale obsahují výrazně pokročilejší infrastrukturu: replay dumper, detektory špatného chování, lokální replay fixtures, zrcadlené A/B zápasy a registr stabilních verzí až `stable-v9`. `run_batch.sh` zaznamenává zkušenosti z reálných běhů z července a září 2026.

API GitHubu vrátilo commit `6b889a903c254e62acf246c4be401114a67ff9b0`, čas `2026-09-19T03:53:43Z`. [WORKSHOP_RELEASE.md](https://github.com/dragonghy/dota2bot/blob/main/docs/WORKSHOP_RELEASE.md) uvádí publikaci soukromého Workshop balíčku 13. září 2026. Dostupnost a kvalita tohoto balíčku nebyly nezávisle ověřeny.

To znamená: není fér označit tento fork pouze za neotestovaný skeleton podle starého README. Zároveň nelze jeho interní záznamy vydávat za náš vlastní důkaz lepší hry. Část změn je záměrně vypnutá přes experimentální přepínače a mnoho změn je podmíněných Turbo režimem.

## 3. Problémy a konkrétní technické příležitosti

Veřejná hlášení popisují [opuštění soubojů #145](https://github.com/forest0xia/dota2bot-OpenHyperAI/issues/145), [nedokončování hry #159](https://github.com/forest0xia/dota2bot-OpenHyperAI/issues/159), [nečinnost #167](https://github.com/forest0xia/dota2bot-OpenHyperAI/issues/167) a [banish schopnosti zachraňující nepřítele #170](https://github.com/forest0xia/dota2bot-OpenHyperAI/issues/170). Jsou to reprodukční podněty od uživatelů, nikoli potvrzení příčiny na našem stroji.

Statické čtení upstream kódu ukázalo následující:

| Zjištění | Význam | Doporučená změna |
|---|---|---|
| `mode_attack_generic.lua` deleguje vlastní attack implementaci jen pro vybranou skupinu hrdinů | Značná část běžného útoku spoléhá na výchozí chování Valve | Logovat skutečný původ rozhodnutí; postupně sjednotit kritické útokové chování u fokusovaných hrdinů |
| `J.WeAreStronger` počítá skóre z offensive power, útoku, attack speed a zdraví; výsledek cachuje 0,5 s | Je to hrubá heuristika. V této funkci není explicitní rozbor připravených iniciací, kontrolních schopností, dostupné many nebo času příchodu spojenců | Krátkodobý odhad souboje podle dostupných schopností, effective HP, pozice a času do zapojení. Nekopírovat slepě skóre ani jen počty hrdinů |
| Retreat mód má mnoho samostatných časových, HP, budovových a hero-specific podmínek | Je třeba zjistit, která větev přebije jinak dobré rozhodnutí | Každému výsledku dát důvod a vstupní hodnoty; nastavovat priority až podle zachycených situací |
| Team-roam už obsahuje zámek cíle na 1,2 s a omezení priorit při laningu/pushi | Určitá stabilizace již existuje; návrh „přidat hysterézi“ nelze vydávat za zcela nový mechanismus | Ověřit návaznost mezi módy, rušení akcí a neplatností cíle; doplnit stabilitu celého záměru, nikoli jen konkrétního targetu |
| `J.IsStuck` kontroluje pohyb bez postupu po 5 s, s výjimkami poblíž věží a Ancientů | Nezachytí každé stání bez příkazu ani kmitání mezi dvěma místy | Watchdog pokroku s kontextem: záměr, vzdálenost, akce, target, channeling. Legitimní čekání a cast nesmí rušit |
| Globální override `GetNearbyHeroes` omezuje radius na 1600 a pro neviditelnou jednotku vrací `nil` | Chování wrapperu musí znát každý volající; může komplikovat vzdálenější koordinaci a práci s prázdnými seznamy | Audit smluv wrapperů a null hodnot, integrační testy; makro rozhodování přes vhodné týmové zdroje informací |
| Push/defend a další společné moduly mají TS zdroje | Jednorázový edit výstupního Lua se při buildu může ztratit | Jasná mapa zdroj → generovaný soubor, stabilní build a kontrola rozdílů |

Tyto nálezy jsou kandidáti pro audit a opravy. Samotné čtení kódu neprokazuje, že právě ony způsobily konkrétní chybu v zápase.

## 4. Jak by vypadali „fakt good“ skriptovaní boti

Největší smysl má hierarchické řízení:

1. **Vnímání a paměť:** viditelní nepřátelé, poslední známé pozice s časem a nejistotou, budovy, zdroje, cooldowny pozorovaných akcí. Nepřátelé mimo vision se nesmí považovat za bezpečně nepřítomné; také se nesmí tajně používat jejich skutečná skrytá poloha.
2. **Týmový plán:** push konkrétní věže, defend, Roshan, rozdělená farma nebo příprava útoku. Plán má účastníky, minimální podmínky, platnost a důvody zrušení. Ověřit možnosti sdílení stavu mezi skripty; nespoléhat na neověřenou sdílenou Lua tabulku napříč VM.
3. **Role a osobní úkol:** iniciátor čeká na návaznost, support drží dosah záchranného spellu, carry má vlastní farmu. Úkol zohledňuje skutečný čas příchodu, TP a bezpečnou cestu.
4. **Taktika:** výběr cíle, positioning, kite, pořadí disable a damage, BKB před potřebnou iniciací, šetření záchranných spellů. Banish/Eul nesmí bez dobrého důvodu negovat vlastní burst.
5. **Vykonání a dohled:** stabilní akce, kontrola target validity, ochrana channelingu, fallback při chybě nebo ztrátě cíle.

Společná pravidla zlepší více hrdinů současně. Individuální kvalitě však nelze uniknout: každý vybraný hrdina potřebuje aktuální build, skutečné komba, správné cast podmínky a testy typických situací.

Pro první sadu bych uvažoval například Wraith King, Luna, Dragon Knight, Zeus, Axe, Tidehunter, Lion, Crystal Maiden, Lich a Witch Doctor. Jde o návrh rozsahu, ne aktuální metové doporučení. Komplikované mikro hrdiny jako Meepo, Arc Warden nebo Chen bych přidal později.

## 5. Co omezuje API a co lze obejít

Bot skripty mají rozhraní pro pohyb, útoky, ability, itemy, nákupy a řadu pozorování. Při tomto průzkumu nešla přímo načíst oficiální wiki; doplňkově byla čtena [generovaná ModDota Bot API reference](https://docs.moddota.com/lua_bots/) a skutečné použití funkcí ve zdrojích. Reference sama není důkaz, že všechny funkce fungují v současném buildu.

Historická [hlášení v trackeru Valve](https://github.com/ValveSoftware/Dota2-Gameplay/issues/23152) uvádějí problémy s novějšími mechanikami, neutral items, facet selection, gate/lotus interakcemi a zděděnými módy některých hrdinů. [GetAvoidanceZones crash #9742](https://github.com/ValveSoftware/Dota2-Gameplay/issues/9742) je konkrétní starší report. Uzavření po neaktivitě není důkaz opravy; ani stáří reportu není důkaz, že chyba trvá. Všechny relevantní funkce je nutné krátce vyzkoušet v aktuálním klientu.

Praktické varianty:

- **Bot script v běžné lokální Dotě:** nejnižší náklady na instalaci a nejlepší výchozí varianta. Slušnou část behaviorálních chyb lze řešit zde.
- **Dodatečný lokální VScript:** může zajistit chybějící integraci či instrumentaci tam, kde serverové API dovolí více. Musí být jasně odděleno opravování mechaniky od přidávání gold/XP či privilegované informace.
- **Vlastní addon/custom game:** více kontroly nad prostředím a scénáři, větší náklady na zachování standardních pravidel a kompatibility. Vhodné, pokud první API experiment ukáže zásadní blokaci.

Deterministické situace přes samotné RCON nejsou automaticky vyřešené: některé konzolové cheaty potřebují kontext lidského hráče. Fork to výslovně popisuje ve [SCENARIO_TESTING.md](https://github.com/dragonghy/dota2bot/blob/main/docs/SCENARIO_TESTING.md). Nejprve ověřit scénářový driver, případně použít serverový testovací VScript. Mock testy tento problém samy neřeší.

## 6. Naučená AI, replay data a LLM

**Ruční pravidla + měření:** doporučený začátek. Rychlé nasazení, vysvětlitelné chyby, opravy lze izolovat.

**Učení menšího rozhodnutí:** pozdější rozumný experiment. Například pořadí cílů, odhad rizika souboje nebo volba objektivu. Replaye mohou dodat příklady a chybové situace. Nelze z nich automaticky získat kompletní pozorování a záměry hráče; vstupy je nutné filtrovat podle vision, aby nedocházelo k úniku skrytých informací. Výslednou malou policy lze případně převést do Lua nebo použít přes ověřenou integraci.

**Kompletní reinforcement learning 5v5:** výzkumný projekt. [OpenAI Five paper](https://arxiv.org/abs/1912.06680) popisuje dlouhé distribuované trénování ve velkém měřítku, omezení na 17 hrdinů a omezení ovládání více jednotek. Výsledek ukazuje, že mimořádná síla je možná, ale neposkytuje hotový současný Workshop bot ani přímý malý projektový recept. Reprodukce podobné úrovně na dnešní Dotě není realistický první milník.

**LLM za běhu:** pro frame-by-frame mikro jej nedoporučuji. Potřebná odezva, stabilita a množství herních stavů favorizují lokální policy či Lua. Smysl má jako pomocník při analýze logů a návrhu oprav; případné pomalé makro plánování přes LLM by bylo samostatným experimentem s fallbackem a měřením přínosu.

## 7. Jak prokázat zlepšení

Pouhé zvýšení win rate proti sobě nebo s FretBots bonusy není dostačující. Když se oběma týmům změní stejný skript, Radiant win rate především měří side/draft bias, ne absolutní zlepšení.

Navržené vrstvy ověření:

1. Lint a load/smoke testy Lua 5.1; testy legality targetů, nákupů a viditelnosti.
2. Malé skutečné herní scénáře: ally attacked, focus target, channeling, retreat z prohraného fightu, push po wipe, cesta při ztrátě cíle.
3. Zachycené stavy z replayů a lokální fixtures pro levné ověření konkrétní větve. Fixtures pomáhají s logikou, plný engine ověří účinek.
4. Candidate proti neměnnému baseline ve stejném zápase. Ověřit dispatch různých verzí na jednotlivé strany, předejít sdílení experimentálního stavu; prohodit Radiant/Dire, používat shodné drafty a sady nastavení.
5. Více nezávislých soupeřů a lidské hry; zvlášť standardní All Pick a Turbo.

Sledovat počet nečinností za minutu aktivní hry, zbytečné rušení akcí, reakci na pomoc spojenci, smrti po solo dive, farmu podle role, CS podpor místo carry, nepovedené spell interakce, proměnění vítězného fightu v objektiv, čas dokončení a CPU/FPS dopad. Definovat přesně, co je špatné chování; například stání při channelingu není idle bug.

Prvních 20–40 párovaných zápasů může odhalit výrazné regrese. Pro malé rozdíly ve vítězství bude potřeba mnohem větší vzorek a interval nejistoty. Ani například 55 výher ze 100 nepovažovat automaticky za průkazný posun nad 50 %.

## 8. Realistický postup a rozsah

Následující časy jsou orientační odhad soustředěné práce, nikoli slíbený termín:

| Fáze | Konkrétní výstup | Odhad |
|---|---|---|
| Technický pilot | Vlastní kopie OHA, zvolený mód, potvrzené načtení, logy, ověření API a 3 reprodukované chyby | Několik pracovních dní |
| První zlepšení | Opravy nečinnosti, problematického přepínání a pomoci spojenci, malé scénáře + baseline | Přibližně 1–3 týdny |
| Kvalitní tým s malým poolem | Koordinace, role, objektivy, vybrané hero komba, stabilní A/B postup | Přibližně 1–3 měsíce podle výsledků |
| Široké pokrytí a trvalá údržba | Rozšiřování hrdinů, patch kompatibilita, herní a výkonnostní regrese | Dlouhodobá práce |

Nejlepší první implementační zadání: **„OHA fork pro standardní All Pick s pool 10–15 hrdinů; nejprve odstranit nečinnost, odcházení z vyhratelných fightů a nezvládnutí push po wipe; každé rozhodnutí musí mít dohledatelný důvod a každá oprava reprodukci.“** Pokud je hlavním cílem Turbo, nejprve porovnat aktuální stabilní variantu `dragonghy/dota2bot` a zvážit ji jako základ.

## Podklady uložené při průzkumu

Lokální, ignorované výzkumné kopie jsou v `.research/oha/` a `.research/focused/`. Archivy nebyly spouštěny ani instalovány do Doty. Metadata GitHubu jsou v `.research/oha-commit.json` a `.research/focused-commit.json`, oficiální seznam patchů v `.research/patches.json`. ZIP větví `main` a metadata byla stažena samostatně; archivy nejsou git checkout a nebyla potvrzena jejich shoda s uvedenými commity objektovým hashem.

SHA-256 archivů:

- OHA: `C97C37E27A6A999A676D34844043D16095828E72E05826EA819898DD6AF20E12`
- Focused fork: `230D00E2A4DFB681D8EAB2C2C9F8DF800858AA23DED88E4A3AD1E98D346DC021`

Pro zahájení vývoje stáhnout či checkoutnout zvolený konkrétní commit a vytvořit oddělenou vývojovou větev. V tomto průzkumu nebyla měněna hra ani publikován vlastní fork.
