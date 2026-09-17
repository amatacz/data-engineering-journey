## README.md — Tydzień 2: CTE, rekursja, złożone zapytania

### 1. CTE vs subquery — kiedy który

**CTE wygrywa, gdy:**
- Ta sama logika/agregacja jest używana **więcej niż raz** w zapytaniu (subquery zmusza do zduplikowania całej logiki z innymi aliasami — patrz zadanie o klientach vs średnia krajowa, subquery version wymagała dwukrotnego napisania `SUM(o_totalprice)` per klient).
- Potrzebny jest **ranking z obcięciem top-N per grupa** (np. "top 5 części per rok"). Subquery musi symulować to przez skorelowane podzapytanie z `LIMIT`, co nie radzi sobie naturalnie z remisami — i tak kończy się zagnieżdżeniem window function w środku. CTE + `DENSE_RANK() OVER (PARTITION BY ...)` robi to natywnie i czytelnie.

**Subquery jest OK, gdy:**
- Porównanie jest do **jednej skorelowanej wartości** (np. "suma zamówień klienta > średnia w jego kraju") — tu skorelowane podzapytanie w `HAVING`/`WHERE` jest naturalne i zwraca dokładnie jeden skalar per wiersz zewnętrzny.

**Uwaga do zapamiętania**: skorelowane podzapytanie bywa dla optymalizatora trudniejsze niż CTE/JOIN, bo sugeruje przeliczanie wartości osobno dla każdego wiersza zewnętrznego — do zweryfikowania w tygodniu 3 przez `EXPLAIN ANALYZE`.

### 2. Metoda rozkładania zapytania na czynniki pierwsze (4 pytania)

Przed napisaniem SQL, odpowiedz sobie:
1. **Jaka jest jednostka wyniku?** ("każdy wiersz to jeden ___") — błędne dopasowanie tu ujawnia pomyłki typu porównywanie sumy do numeru rankingu.
2. **Czy jest agregacja, na jakim poziomie?** Agregacja na agregacji (np. suma per grupa, potem ranking w obrębie grupy) = sygnał, że potrzebna jest warstwa pośrednia (CTE/subquery), bo nie da się tego zrobić w jednym płaskim `GROUP BY`.
3. **Porównanie do jednej wartości czy do wartości zależnej od grupy?** Jedna globalna/skorelowana wartość → subquery jest naturalne. Wartość zależna od pozycji w rankingu wewnątrz grupy → window function.
4. **W jakiej kolejności muszą wykonać się kroki?** Rozpisać słownie, zanim napisze się SQL — jeśli krok 3 mówi "na wyniku kroku 2", to jest sygnał że potrzebna jest granica (CTE) między nimi.

### 3. CTE rekurencyjne — hierarchia (trawersowanie w dół)

- Wymaga `WITH RECURSIVE` (nie samo `WITH`).
- Dwie części połączone `UNION ALL`: **anchor member** (baza, punkt startowy) i **recursive member** (odwołuje się do samej siebie, JOIN do tabeli źródłowej).
- Kierunek JOIN-a w części rekurencyjnej dla "kto jest pode mną": `e.manager_id = h.id` (znajdź pracownika, którego managerem jest osoba już znaleziona).
- `level` = licznik (`h.level + 1`), rośnie prosto.
- `path` = tablica ID budowana przez `||` (**nie** `concat` — to dokleja do tekstu, nie do tablicy): baza `array[id]`, rekurencja `h.path || e.id`. Ważne: doklejać **`e.id`/`e.name`** (bieżący wiersz), nie `h.id`/`h.name` (poprzedni krok) — inaczej ścieżka jest przesunięta o jeden krok i nigdy nie kończy się na właścicielu wiersza.

### 4. Wykrywanie cykli

- Zabezpieczenie: `WHERE NOT (e.id = ANY(h.path))` w części rekurencyjnej, sprawdzane **przed** dodaniem nowego wiersza.
- **Kluczowa obserwacja**: trawersowanie **od korzenia w dół** (`WHERE manager_id IS NULL` + `e.manager_id = h.id`) nigdy nie natrafi na prawdziwy cykl, bo wzajemna zależność (A wymaga B, B wymaga A) nie ma punktu startowego osiągalnego od korzenia — cykl jest zawsze "odcięty" jako izolowana wysepka w grafie.
- Cykle faktycznie grożą nieskończoną pętlą przy trawersowaniu **w górę** (od konkretnej osoby do korzenia): `JOIN ancestors a ON e.id = a.manager_id` (szukam managera bieżącej osoby) — tu nic nie wymaga dotarcia do `NULL`, więc bez zabezpieczenia `path` silnik będzie pytał w kółko.
- Wniosek: kierunek JOIN-a (`e.manager_id = h.id` vs `e.id = a.manager_id`) decyduje, czy zapytanie w ogóle jest podatne na zawieszenie przez cykl.

### 5. Generowanie serii dat rekurencyjnie

- To inny wzorzec niż hierarchia — **bez JOIN-a** do tabeli źródłowej w części rekurencyjnej. Tabela źródłowa jest użyta tylko do policzenia granic (`MIN`/`MAX`), nie bierze udziału w samej pętli.
- Wzorzec: baza = jedna wartość startowa, rekurencja = poprzednia wartość + krok, z warunkiem stopu w `WHERE`.
- **Off-by-one przy warunku stopu**: sprawdzanie `calendar_date <= MAX` (bieżąca wartość) generuje jeden wiersz za dużo (bo nawet gdy `calendar_date = MAX`, warunek przepuszcza kolejny krok). Poprawnie: sprawdzać **przyszłą** wartość — `calendar_date + 1 <= MAX`. Liczba wygenerowanych punktów w przedziale domkniętym to `(MAX - MIN) + 1`, nie `MAX - MIN`.
- **Typy muszą się zgadzać między częścią bazową a rekurencyjną** — `date + interval '1 day'` cicho podnosi typ z `date` do `timestamp`, co Postgres odrzuca jako niespójność w `UNION ALL` rekurencyjnym (`ERROR 42804`). Naprawa: `date + 1` (liczba całkowita) zostaje typem `date`; albo rzutować wynik z powrotem na `::date`.

### 6. Pułapka: `timestamptz`, DST i liczenie dni

- `date_trunc('day', ts)` zeruje godzinę, ale **zwraca nadal `timestamptz`** — wartość wciąż "pamięta" swoją strefę czasową, więc odejmowanie dwóch takich wartości w okolicach zmiany czasu (DST) daje wynik zafałszowany o godziny (`2404 days 23:00:00` zamiast równych 2404 dni).
- `ts::date` rzutuje na typ **bez** komponentu czasowego i strefy w ogóle — to jedyny bezpieczny sposób liczenia różnicy w pełnych dniach kalendarzowych.
- Zasada: **do arytmetyki na dniach kalendarzowych zawsze używać `::date`, nie `date_trunc`.**