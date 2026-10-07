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
