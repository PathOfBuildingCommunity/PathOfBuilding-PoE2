# Path of Building (PoE 2) – Trade Module Changelog

Podsumowanie zmian w module handlu dla Path of Exile 2 (wg PRD v2.0).  
Summary of Trade Module updates for Path of Exile 2.

**Słowa kluczowe / Keywords**: PoE 2, trade, Link, Travel, Hideout, getItemDisplayName, buildItemNameSearchURL, full item name, price filter, URL query, whisper, Instant Buyout.

---

## SPIS TREŚCI / TABLE OF CONTENTS

1. [IMPLEMENTED](#implemented--zrealizowano)
2. [PENDING](#pending--w-trakcie--planowane)
3. [METODOLOGIA ANALIZY](#metodologia-analizy--how-we-arrived-at-solutions)
4. [INSTRUKCJA ODTWORZENIA](#instrukcja-odtworzenia-zmian--reproduction-guide)
5. [MODIFIED FILES](#modified-files--zmodyfikowane-pliki)

**Pliki postępu / Progress files**: `Progress_DEV.txt`, `Progress_UI.txt`, `Progress_QA.txt`

---

## IMPLEMENTED / ZREALIZOWANO

### English

- **Crash fixes**: Null-safe guards in `TradeQueryRequests.lua` (listing, account, item, property.values, requirement.values, pseudoMods). `ItemsTab.lua` AddItemTooltip baseName guard. Guard for empty filter results in `UpdateControlsWithItems` (no crash when "In person online" returns 0 items).
- **Hybrid Action Button**: "Whisper" (gray) copies whisper to clipboard; "Travel"/"Hideout" (gold) for Instant Buyout opens trade page in browser. **Price displayed on both Whisper and Travel/Hideout buttons** (e.g. "o Whisper: 2 exalted", "o Hideout: 2 exalted").
- **Traffic lights**: Colored status dot (green/orange/gray) for seller Online/AFK/Offline.
- **Link button**: Opens trade search in browser. **URL includes item name + exact price filter** to narrow results.
- **Full item name for Link/Travel**: `getItemDisplayName()` returns full rare name (e.g. "Cataclysm Core Varnished Crossbow") instead of partial name from whisper. Commas replaced with spaces (trade site format).
- **Price filter in URL**: `buildItemNameSearchURL()` adds `trade_filters.filters.sale_type.option = "priced"` and `price.min/max` when amount/currency provided. Link and Travel both pass `(itemName, item.amount, item.currency)`.
- **Tooltip positioning**: Left-of-cursor default, viewport clamping (no off-screen).
- **Listing Type filter** (PRD Feature E): Query Options dropdown "Listing" – Any | Instant Buyout | In person (whisper) | In person ONLINE. Filter applied client-side via `passesListingTypeFilter()`.
- **Query Options layout**: Listing, Max Price, Max Level, Sockets, Stat to Sort By aligned left with checkboxes (Corrupted Mods, Rune Mods, Mirrored items).
- **Settings persistence**: tradeDefaults (maxPrice, checkboxes, jewelType, sockets, lastListingType).
- **Keyboard**: TAB/Shift+TAB navigation in Query Options popup.
- **Sort panel scaffold** (TRADER_SORT_BY_STATS_SPEC): Headers, state (clickSortStats, favoriteStats, sortPanelSelectedRowIdx/ItemIdx).
- **Other**: F5 restart, m_min fix, callbackQueryId (queryId, realm, league) for correct URL build.

### Polski

- **Naprawy crashy**: Zabezpieczenia nil w `TradeQueryRequests.lua` (listing, account, item, property.values, requirement.values, pseudoMods). Guard w `ItemsTab.lua` AddItemTooltip (baseName). Guard dla pustych wyników filtra w `UpdateControlsWithItems` (brak crasha gdy "In person online" zwraca 0 wyników).
- **Hybrid Action Button**: „Whisper” (szary) kopiuje whisper; „Travel”/„Hideout” (złoty) dla Instant Buyout otwiera stronę trade w przeglądarce. **Cena wyświetlana przy obu przyciskach** (np. „o Whisper: 2 exalted”, „o Hideout: 2 exalted”).
- **Traffic lights**: Kolorowa kropka (zielony/pomarańczowy/szary) dla Online/AFK/Offline.
- **Przycisk Link**: Otwiera wyszukiwanie trade w przeglądarce. **URL zawiera pełną nazwę przedmiotu + filtr dokładnej ceny** (zawęża wyniki).
- **Pełna nazwa przedmiotu dla Link/Travel**: `getItemDisplayName()` zwraca pełną nazwę rare (np. „Cataclysm Core Varnished Crossbow”) zamiast częściowej z whisper. Przecinki zamieniane na spacje (format strony trade).
- **Filtr ceny w URL**: `buildItemNameSearchURL()` dodaje `trade_filters.filters.sale_type.option = "priced"` i `price.min/max`, gdy podano amount/currency. Link i Travel przekazują `(itemName, item.amount, item.currency)`.
- **Pozycjonowanie tooltipa**: Domyślnie po lewej od kursora, clamping do viewportu.
- **Filtr Listing Type** (PRD Feature E): Dropdown „Listing” w Query Options – Any | Instant Buyout | In person (whisper) | In person ONLINE. Filtr po stronie klienta (`passesListingTypeFilter()`).
- **Layout Query Options**: Pola Listing, Max Price, Max Level, Sockets, Stat to Sort By wyrównane w lewo z checkboxami.
- **Zapis ustawień**: tradeDefaults (maxPrice, checkboxes, jewelType, sockets, lastListingType).
- **Nawigacja klawiaturą**: TAB/Shift+TAB w popup Query Options.
- **Sort panel scaffold** (TRADER_SORT_BY_STATS_SPEC): Nagłówki, stan (clickSortStats, favoriteStats, sortPanelSelectedRowIdx/ItemIdx).
- **Inne**: F5 restart, fix m_min, callbackQueryId (queryId, realm, league) dla poprawnego URL.

---

## PENDING / W TRAKCIE / PLANOWANE

### English

1. **PRD Feature A – Instant Buyout action**  
   PRD requires: copy `/hideout <characterName>` to clipboard.  
   Current: opens browser. Planned: restore `travelCommand`/`lastCharacterName` in FetchResultBlock, implement `Copy(travelCommand)` on IB click.

2. **PRD Feature A – Button label**  
   PRD: "Travel to Hideout". Current: "Travel". Planned: full label.

3. **PRD Feature A – Button enable logic**  
   PRD: "NEVER disable this button if the item is listed."  
   Current: IB button disabled when URI empty. Planned: always enabled for listed items.

4. **PRD Feature E – Online Status filter**  
   UI: Dropdown "Online Status" (Any, Online Only). API: query.status.option. Optional.

5. **Sort panel full** (TRADER_SORT_BY_STATS_SPEC §2.A–D, §6) – IMPLEMENTED  
   - Column 1: Stat pool from selected item; click to add to sort  
   - Column 2: Sort by – Shift+click to remove; icons ! (priority), * (favorite), X (remove)  
   - StatClick mode in Sort By dropdown; min/max filters (inclusive)

6. **End-to-end verification**  
   Verify all features work in full flow.

### Polski

1. **PRD Feature A – Akcja Instant Buyout**  
   PRD wymaga: kopiuj `/hideout <characterName>` do schowka.  
   Obecnie: otwiera przeglądarkę. Plan: przywrócić `travelCommand`/`lastCharacterName` w FetchResultBlock, `Copy(travelCommand)` przy IB.

2. **PRD Feature A – Etykieta przycisku**  
   PRD: „Travel to Hideout”. Obecnie: „Travel”. Plan: pełna etykieta.

3. **PRD Feature A – Logika enable przycisku**  
   PRD: przycisk nigdy nie wyłączony, gdy item wylistowany.  
   Obecnie: przycisk IB wyłączony gdy URI puste. Plan: zawsze włączony dla wylistowanych.

4. **PRD Feature E – Filtr Online Status**  
   UI: Dropdown „Online Status” (Any, Online Only). API: query.status.option. Opcjonalne.

5. **Sort panel pełny** (TRADER_SORT_BY_STATS_SPEC §2.A–D, §6)  
   - Kolumna 1: dynamiczna pula z GetResultEvaluation + displayStats; klik/Shift dodaj/usuń do clickSortStats  
   - SortFetchResults: tryb StatClick według clickSortStats (priorytet, multi-sort)  
   - Ikony !, *, X przy statystykach w kolumnie 2, EditControl „Mniejsze niż” / „Większe niż” do filtrowania

6. **Weryfikacja end-to-end**  
   Sprawdzenie pełnego przepływu wszystkich funkcji.

---

## METODOLOGIA ANALIZY / HOW WE ARRIVED AT SOLUTIONS

### Analiza strony trade (poe.trade / pathofexile.com/trade2)

1. **Problem**: Link i Travel kopiowały do wyszukiwarki tylko fragment nazwy (np. "Varnished Crossbow") zamiast pełnej (np. "Cataclysm Core Varnished Crossbow").

2. **Analiza whisper**: API trade zwraca `listing.price.currency`, `listing.price.amount`, `whisper` w stylu `"your Cataclysm Core, Sturdy Crossbow listed"`. Po przecinku była tylko część nazwy – niewystarczająca do wyszukiwania.

3. **Analiza HTML strony trade**: Użytkownik dostarczył fragment HTML z filtrem "Buyout Price" – dropdown waluty, pola min/max. Strona trade używa parametru URL `?q=` z zakodowanym JSON.

4. **Format query JSON** (odczytany z URL po wybraniu filtrów):
   - `query.term` – fraza wyszukiwania (pełna nazwa przedmiotu)
   - `query.filters.trade_filters.filters.sale_type.option = "priced"` – tylko przedmioty z ceną
   - `query.filters.trade_filters.filters.price.option` – waluta (np. `"exalted"`)
   - `query.filters.trade_filters.filters.price.min`, `price.max` – dokładna cena (min == max)

5. **Źródło pełnej nazwy**:
   - Klasa `Item` z `item_string`: `itemObj.title`, `itemObj.baseName`, `itemObj.name`
   - Dla rare: `title ~= baseName` → `title .. " " .. baseName` (bez nawiasów typu)
   - Fallback: `result.fullItemName`, potem `whisper:match("your (.+) listed")`

6. **Format nazwy dla trade**: Strona oczekuje spacji zamiast przecinków – np. `"Cataclysm Core Varnished Crossbow"`, nie `"Cataclysm Core, Sturdy Crossbow"`. Końcowy `gsub(",%s*", " ")` w `getItemDisplayName`.

### Wyszukiwanie w kodzie

- **Grep** na: `getItemDisplayName`, `buildItemNameSearchURL`, `rawLines`, `item.name`
- **Lokalizacje**: `Classes/TradeQuery.lua` ~1677 (getItemDisplayName), ~1700 (buildItemNameSearchURL), ~1765–1840 (actionButton, linkButton); `Classes/TradeQueryRequests.lua` ~326–340 (rawLines)

---

## INSTRUKCJA ODTWORZENIA ZMIAN / REPRODUCTION GUIDE

### 1. TradeQueryRequests.lua – rawLines, guard item.name

**Plik**: `Classes/TradeQueryRequests.lua` (~linia 336)

**Problem**: Przy `item.name == nil` (np. przedmioty magiczne, niektóre IB) warunek `if item.name ~= ""` mógł powodować nieoczekiwane zachowanie.

**Zmiana**:
```lua
-- BYŁO (przykład):
if item.name ~= "" then

-- JEST:
if item.name and item.name ~= "" then
    t_insert(rawLines, item.name)
end
```

**Kontekst**: `item.name` jest pusty/nil dla magic items (pełna nazwa w `typeLine`) lub niektórych IB; `typeLine == base` dla rare.

---

### 2. TradeQuery.lua – getItemDisplayName()

**Plik**: `Classes/TradeQuery.lua` (~linia 1677)

**Problem**: Link/Travel kopiowały do wyszukiwarki tylko część nazwy po przecinku (z whisper).

**Implementacja**:
```lua
local function getItemDisplayName(result)
    if not result then return "" end
    local name = ""
    local ok, itemObj = pcall(function() return new("Item", result.item_string) end)
    if ok and itemObj and itemObj.title and itemObj.baseName and itemObj.title ~= itemObj.baseName then
        name = itemObj.title .. " " .. itemObj.baseName:gsub(" %(.+%)", "")
    end
    if name == "" and result.fullItemName and result.fullItemName ~= "" then
        name = result.fullItemName
    elseif name == "" and result.whisper and result.whisper ~= "" then
        name = result.whisper:match("your (.+) listed") or ""
    end
    if name == "" and ok and itemObj then
        if itemObj.title and itemObj.baseName then
            name = itemObj.title .. " " .. itemObj.baseName:gsub(" %(.+%)", "")
        elseif itemObj.name then
            name = itemObj.name
        end
    end
    return (name or ""):gsub(",%s*", " "):gsub("^%s*(.-)%s*$", "%1")
end
```

**Priorytety**: (1) Item class gdy `title != baseName` (rare), (2) fullItemName, (3) whisper match, (4) Item fallback. Na końcu: zamiana przecinków na spacje, trim.

---

### 3. TradeQuery.lua – buildItemNameSearchURL()

**Plik**: `Classes/TradeQuery.lua` (~linia 1700)

**Cel**: URL do wyszukiwania z opcjonalnym filtrem dokładnej ceny.

**Implementacja**:
```lua
local function buildItemNameSearchURL(itemName, itemAmount, itemCurrency)
    if not itemName or itemName == "" then return nil end
    local escapedName = itemName:gsub('"', '\\"')
    local tradeFilters = ""
    if itemAmount and itemCurrency and itemCurrency ~= "" then
        tradeFilters = '"trade_filters":{"filters":{"sale_type":{"option":"priced"},"price":{"option":"' .. itemCurrency .. '","min":' .. tostring(itemAmount) .. ',"max":' .. tostring(itemAmount) .. '}}}'
    end
    local filtersBlock = tradeFilters ~= "" and tradeFilters or ""
    local query = '{"query":{"term":"' .. escapedName .. '","status":{"option":"any"},"filters":{' .. filtersBlock .. '},"stats":[{"type":"and","filters":[]}]},"sort":{"price":"asc"}}'
    local base = self.tradeQueryRequests:buildUrl(self.hostName .. "trade2/search", self.pbRealm, self.pbLeague)
    return base .. "?q=" .. urlEncode(query)
end
```

**Użycie**: Travel i Link wywołują `buildItemNameSearchURL(itemName, item.amount, item.currency)` – filtr ceny zawęża wyniki do konkretnego przedmiotu.

---

### 4. TradeQuery.lua – przycisk Travel/Hideout z ceną

**Plik**: `Classes/TradeQuery.lua` (~linia 1756–1812)

**Zmiany**:
- **Label**: Przy Whisper i Travel/Hideout wyświetlana jest cena: `"o Whisper: " .. tp.amount .. " " .. tp.currency`, `"o Hideout: " .. tp.amount .. " " .. tp.currency`.
- **Szerokość przycisku**: Funkcja `width` używa `DrawStringWidth` dla tekstu z ceną (np. `"o Hideout: 2 exalted"`).
- **Travel/Hideout click**: Zamiast `controls["uri"].buf` – budowanie URL przez `buildItemNameSearchURL(itemName, item.amount, item.currency)`. Fallback na URI gdy `nameUrl` nil.
- **Enabled dla IB**: Zawsze `true` – URL budowany z nazwy przedmiotu, nie wymaga URI.

---

### 5. TradeQuery.lua – przycisk Link z filtrem ceny

**Plik**: `Classes/TradeQuery.lua` (~linia 1827–1863)

**Zmiany**:
- **Click**: `buildItemNameSearchURL(itemName, amt, cur)` zamiast samego `controls["uri"].buf`.
- **Parametry**: `itemName = getItemDisplayName(item)`, `amt = item.amount`, `cur = item.currency`.
- **Fallback**: Gdy `nameUrl` nil → OpenURL(controls["uri"].buf).
- **Clipboard**: Copy(itemName) jako fallback do ręcznego wyszukiwania.

---

## MODIFIED FILES / ZMODYFIKOWANE PLIKI

| File | Scope |
|------|-------|
| `Classes/TradeQueryRequests.lua` | Null safety, isInstantBuyout, accountStatus, rawLines `item.name` guard |
| `Classes/TradeQuery.lua` | getItemDisplayName, buildItemNameSearchURL, Hybrid Action Button (cena), Link (cena w URL) |
| `Classes/TradeQueryGenerator.lua` | Defaults, TAB nav, m_min, Listing dropdown, inputLabelOffset |
| `Classes/Tooltip.lua` | Adaptive positioning |
| `Classes/ItemsTab.lua` | AddItemTooltip guards |
| `Modules/Main.lua` | tradeDefaults persistence |
| `Classes/CheckBoxControl.lua` | TAB handling |
| `Classes/DropDownControl.lua` | TAB handling |
| `Classes/ButtonControl.lua` | TAB handling |
| `Launch.lua` | F5 restart |

---

## PRD REFERENCE

- **Feature A**: Hybrid Action Button (Whisper vs Travel to Hideout)
- **Feature B**: Player Status Traffic Lights
- **Feature C**: Direct Session Linking (Link button)
- **Feature D**: Adaptive Tooltip Positioning
- **Feature E**: Search Query Options (Listing Type, Online Status)

---

*Last update: 2025-02-05*
