# Tydzień 3: Optymalizacja i EXPLAIN

Dataset: `yellow_trips` (NYC Yellow Taxi, styczeń–kwiecień 2026, ~14,9 mln wierszy)

---

## Porównanie: EXPLAIN vs EXPLAIN ANALYZE vs EXPLAIN (ANALYZE, BUFFERS)

**Zapytanie testowe:**
```sql
SELECT count(*), avg(total_amount)
FROM yellow_trips
WHERE tpep_pickup_datetime >= '2026-02-10'
  AND tpep_pickup_datetime <  '2026-02-17';
```

```sql
-- 1. EXPLAIN (tylko szacunki planera)
EXPLAIN
SELECT count(*), avg(total_amount) FROM yellow_trips
WHERE tpep_pickup_datetime >= '2026-02-10' AND tpep_pickup_datetime < '2026-02-17';

-- 2. EXPLAIN ANALYZE (faktyczne wykonanie)
EXPLAIN ANALYZE
SELECT count(*), avg(total_amount) FROM yellow_trips
WHERE tpep_pickup_datetime >= '2026-02-10' AND tpep_pickup_datetime < '2026-02-17';

-- 3. EXPLAIN (ANALYZE, BUFFERS) (+ dysk/RAM)
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*), avg(total_amount) FROM yellow_trips
WHERE tpep_pickup_datetime >= '2026-02-10' AND tpep_pickup_datetime < '2026-02-17';
```

**Wnioski:**
- `EXPLAIN` — tylko `cost` i szacowane `rows`. Nie wykonuje zapytania fizycznie — bezpieczne do sprawdzenia planu bez skutków ubocznych (ważne przy zapytaniach modyfikujących dane).
- `EXPLAIN ANALYZE` — wykonuje zapytanie naprawdę (przy `INSERT`/`UPDATE`/`DELETE` warto owinąć w transakcję z `ROLLBACK`). Dodaje `actual time=...` i rzeczywiste `rows=...` — dopiero to pozwala porównać szacunek planera z rzeczywistością.
- `EXPLAIN (ANALYZE, BUFFERS)` — dodaje `Buffers: shared hit=X read=Y`. Dopiero to pokazuje, ile danych przyszło z RAM (`hit`) a ile z dysku (`read`) — kluczowe, żeby odróżnić "szybko bo w cache" od "szybko bo indeks faktycznie coś oszczędził".
- W praktyce `EXPLAIN (ANALYZE, BUFFERS)` to sensowny domyślny wybór do realnej diagnostyki wydajności.

---

## Case 1: Zakres dat — wysoka selektywność, wysoka korelacja

**Cel:** pokazać zmianę Seq Scan → Index Scan przy filtrze zakresowym.

```sql
-- QUERY
SELECT count(*), avg(total_amount)
FROM yellow_trips
WHERE tpep_pickup_datetime >= '2026-02-10'
  AND tpep_pickup_datetime <  '2026-02-17';

-- INDEX
CREATE INDEX idx_yt_pickup_datetime
ON public.yellow_trips(tpep_pickup_datetime);
```

```
-- EXPLAIN (ANALYZE, BUFFERS) PRZED indeksem
Finalize Aggregate  (cost=411681.16..411681.17 rows=1 width=16) (actual time=5086.183..5100.324 rows=1 loops=1)
  Buffers: shared hit=3088 read=312652
  ->  Gather  (cost=411680.94..411681.15 rows=2 width=40) (actual time=5084.807..5100.265 rows=3 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        ->  Partial Aggregate  (cost=410680.94..410680.95 rows=1 width=40) (actual time=5048.454..5048.459 rows=1 loops=3)
              ->  Parallel Seq Scan on yellow_trips  (cost=0.00..408944.01 rows=347385 width=8) (actual time=1354.233..4934.851 rows=289388 loops=3)
                    Filter: ((tpep_pickup_datetime >= '2026-02-10') AND (tpep_pickup_datetime < '2026-02-17'))
                    Rows Removed by Filter: 4680094
Execution Time: 5102.830 ms
```

```
-- EXPLAIN (ANALYZE, BUFFERS) PO indeksie
Finalize Aggregate  (cost=102879.74..102879.75 rows=1 width=16) (actual time=640.376..642.222 rows=1 loops=1)
  Buffers: shared hit=834211 read=20108 written=27
  ->  Gather  (cost=102879.51..102879.72 rows=2 width=40) (actual time=640.365..642.212 rows=3 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        ->  Partial Aggregate  (cost=101879.51..101879.52 rows=1 width=40) (actual time=610.879..610.880 rows=1 loops=3)
              ->  Parallel Index Scan using idx_yt_pickup_datetime on yellow_trips  (cost=0.43..100011.56 rows=373590 width=8) (actual time=1.559..514.237 rows=289388 loops=3)
                    Index Cond: ((tpep_pickup_datetime >= '2026-02-10') AND (tpep_pickup_datetime < '2026-02-17'))
Execution Time: 644.622 ms
```

```sql
-- rozmiar indeksu: 244 MB
SELECT pg_size_pretty(pg_relation_size('idx_yt_pickup_datetime'));

-- korelacja: 0.975251 (bardzo wysoka)
SELECT attname, correlation FROM pg_stats
WHERE tablename = 'yellow_trips' AND attname = 'tpep_pickup_datetime';
```

**Wnioski:**
- Typ węzła: Parallel Seq Scan → Parallel Index Scan.
- Execution Time: 5102,8 ms → 644,6 ms (**~8x szybciej**).
- Buffers read: 312 652 → 20 108.
- Selektywność ~6% wierszy (tydzień z 4-miesięcznego zbioru) — wystarczająco mało, żeby planer przełączył się na indeks.
- Korelacja 0,975 (dane fizycznie posortowane wg daty, bo ładowane chronologicznie) — dzięki temu Index Scan czyta strony blisko siebie, nie losowo.
- Przy wysokiej selektywności **i** wysokiej korelacji jednocześnie indeks daje maksymalny możliwy zysk.
- **Błąd po drodze:** pierwsze próby (filtr na cały miesiąc, potem na 4 miesiące) miały zbyt niską selektywność (50%+) i nie zmieniały planu — dopiero zawężenie do tygodnia (~6%) pokazało efekt. Wniosek: dobierając przykład, trzeba znać realny zakres/rozkład danych, nie zakładać z góry.

---

## Case 2: Niska selektywność — indeks ignorowany

**Cel:** pokazać, że planer świadomie NIE używa indeksu, gdy filtr obejmuje dużą część tabeli.

```sql
-- QUERY
SELECT * FROM yellow_trips yt
WHERE yt.payment_type = 0;

-- INDEX
CREATE INDEX idx_yt_payment_type ON yellow_trips(payment_type);
```

```
-- EXPLAIN (ANALYZE, BUFFERS) PRZED indeksem
Seq Scan on yellow_trips yt  (cost=0.00..502104.88 rows=3891795 width=142) (actual time=465.119..1965.155 rows=3856909 loops=1)
  Filter: (payment_type = 0)
  Rows Removed by Filter: 11051537
  Buffers: shared hit=3804 read=311936
Execution Time: 2109.641 ms
```

```
-- EXPLAIN (ANALYZE, BUFFERS) PO indeksie
Seq Scan on yellow_trips yt  (cost=0.00..502109.49 rows=3895868 width=142) (actual time=513.865..1614.563 rows=3856909 loops=1)
  Filter: (payment_type = 0)
  Rows Removed by Filter: 11051537
  Buffers: shared hit=3996 read=311744
Execution Time: 1758.363 ms
```

```sql
-- rozmiar indeksu: 99 MB
SELECT pg_size_pretty(pg_relation_size('idx_yt_payment_type'));

-- korelacja: 0.3717111 (niska)
SELECT attname, correlation FROM pg_stats
WHERE tablename = 'yellow_trips' AND attname = 'payment_type';
```

**Wnioski:**
- Typ węzła: Seq Scan → Seq Scan (**bez zmian**). Cost praktycznie identyczny (502104,88 vs 502109,49) — dowód, że planer świadomie zignorował indeks, a nie przeoczył go.
- Selektywność: ~26% wierszy (3 856 909 / 14 908 446) — **niska** selektywność (duża część tabeli pasuje do warunku).
- Przy tak dużym odsetku pasujących wierszy Seq Scan jest tańszy niż Index/Bitmap Scan, bo i tak trzeba by dotknąć prawie każdej strony tabeli.
- Różnica czasu (2109,6 ms vs 1758,4 ms) to szum/cache między uruchomieniami, **nie** realna poprawa — identyczny plan w obu przypadkach.
- **Błąd po drodze:** pierwsza próba użyła `payment_type = 4` (rzadka wartość, ~3% wierszy — czyli w rzeczywistości **wysoka** selektywność). Dało to inny wynik: Bitmap Heap Scan z `lossy` blokami — indeks pomógł, ale mniej niż w case 1, przez niską korelację (0,37) wiersze pasujące są rozrzucone po całej tabeli, więc bitmapa "gubi" precyzję przy dużej liczbie trafień i musi doczytywać całe strony (`Recheck Cond`). Wniosek: nie można zakładać "wysoka/niska selektywność" z samej nazwy kolumny czy wartości — trzeba sprawdzić rozkład (`GROUP BY` + policzenie udziału procentowego).

---

## Case 3: Indeks częściowy — rzadki warunek

**Cel:** pokazać duży zysk przy minimalnym rozmiarze indeksu dzięki klauzuli WHERE.

```sql
-- QUERY
SELECT * FROM yellow_trips yt
WHERE yt.fare_amount > 200;

-- INDEX (częściowy)
CREATE INDEX idx_yt_fare_amount
ON public.yellow_trips(fare_amount)
WHERE fare_amount > 200;
```

```
-- EXPLAIN (ANALYZE, BUFFERS) PRZED indeksem
Gather  (cost=1000.00..397520.19 rows=31434 width=142) (actual time=7.129..4230.328 rows=5816 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=4092 read=311648
  ->  Parallel Seq Scan on yellow_trips yt  (cost=0.00..393376.79 rows=13098 width=142) (actual time=6.408..4202.168 rows=1939 loops=3)
        Filter: (fare_amount > '200'::double precision)
        Rows Removed by Filter: 4967543
Execution Time: 4231.490 ms
```

```
-- EXPLAIN (ANALYZE, BUFFERS) PO indeksie (częściowym)
Bitmap Heap Scan on yellow_trips yt  (cost=102.68..94130.18 rows=32075 width=142) (actual time=1.775..516.545 rows=5816 loops=1)
  Recheck Cond: (fare_amount > '200'::double precision)
  Heap Blocks: exact=5391
  Buffers: shared hit=90 read=5318
  ->  Bitmap Index Scan on idx_yt_fare_amount  (cost=0.00..94.66 rows=32075 width=0) (actual time=1.057..1.057 rows=5816 loops=1)
        Buffers: shared read=17
Execution Time: 517.172 ms
```

```sql
-- rozmiar indeksu: 144 KB
SELECT pg_size_pretty(pg_relation_size('idx_yt_fare_amount'));
```

**Wnioski:**
- Typ węzła: Parallel Seq Scan → Bitmap Heap Scan + Bitmap Index Scan.
- Execution Time: 4231,5 ms → 517,2 ms (**~8,2x szybciej**).
- Buffers read: 311 648 → ~5335 (90 hit + 5318 heap + 17 index).
- `loops=1` w wersji po indeksie (bez równoległości) — efekt niskiego szacowanego kosztu, nie przyczyna przyspieszenia.
- Selektywność: ~0,04% wierszy (5816 / 14 908 445) — ekstremalnie rzadki warunek.
- Rozmiar indeksu: **144 KB** — bo indeks częściowy przechowuje tylko wiersze spełniające `WHERE fare_amount > 200` z definicji, nie całą kolumnę.
- Plan po indeksie to Bitmap Heap Scan (z `Recheck Cond`), nie czysty Index Scan — przy tak małym oczekiwanym koszcie planer uznał bitmapę za wystarczająco tanią.
- Indeks częściowy ma sens tylko, gdy zapytania w aplikacji rzeczywiście regularnie filtrują po tym samym warunku — inaczej jest bezużyteczny dla innych zapytań na tej kolumnie.

---

## Case 4: Kolejność kolumn w indeksie złożonym

**Cel:** pokazać wpływ kolejności kolumn (równość vs zakres) na wydajność.

```sql
-- QUERY
SELECT count(*)
FROM yellow_trips
WHERE "PULocationID" = 15
  AND tpep_pickup_datetime >= '2026-02-01'
  AND tpep_pickup_datetime <  '2026-02-08';

-- INDEX A: równość, potem zakres
CREATE INDEX idx_yt_PULocationID_tpep_pickup_datetime
ON public.yellow_trips("PULocationID", tpep_pickup_datetime);

-- INDEX B: zakres, potem równość
CREATE INDEX idx_yt_pickup_PULocationID
ON yellow_trips (tpep_pickup_datetime, "PULocationID");
```

```
-- EXPLAIN (ANALYZE, BUFFERS) z INDEKSEM A: (PULocationID, pickup_datetime)
Aggregate  (cost=13.44..13.45 rows=1 width=8) (actual time=0.036..0.036 rows=1 loops=1)
  Buffers: shared hit=28
  ->  Index Only Scan using idx_yt_pulocationid_tpep_pickup_datetime on yellow_trips  (cost=0.56..12.95 rows=195 width=0) (actual time=0.020..0.030 rows=46 loops=1)
        Index Cond: (("PULocationID" = 15) AND (tpep_pickup_datetime >= '2026-02-01') AND (tpep_pickup_datetime < '2026-02-08'))
        Heap Fetches: 0
Execution Time: 0.051 ms
```

```
-- EXPLAIN (ANALYZE, BUFFERS) z INDEKSEM B: (pickup_datetime, PULocationID)
-- (po usunięciu indeksu A, żeby wymusić użycie B)
Aggregate  (cost=24969.07..24969.08 rows=1 width=8) (actual time=75.013..75.015 rows=1 loops=1)
  Buffers: shared hit=23 read=3477
  ->  Index Only Scan using idx_yt_pickup_pulocationid on yellow_trips  (cost=0.56..24968.55 rows=211 width=0) (actual time=4.064..74.989 rows=46 loops=1)
        Index Cond: ((tpep_pickup_datetime >= '2026-02-01') AND (tpep_pickup_datetime < '2026-02-08') AND ("PULocationID" = 15))
        Heap Fetches: 0
Execution Time: 75.067 ms
```

**Porównanie:**

| | Indeks A: (PULocationID, pickup_datetime) | Indeks B: (pickup_datetime, PULocationID) |
|---|---|---|
| cost | 13,44 | 24 969,07 |
| Buffers | hit=28 | hit=23, read=3477 |
| Execution Time | 0,051 ms | 75,067 ms |
| Różnica | — | **~1470x wolniej** |

**Wnioski:**
- Oba warunki trafiły do `Index Cond` w obu wersjach (nie `Filter`), oba dały `Index Only Scan` z `Heap Fetches: 0` — różnica jest wyłącznie w efektywności zawężania przez B-tree.
- Mechanizm: B-tree jest posortowane najpierw wg pierwszej kolumny, dopiero w jej obrębie wg drugiej.
  - Indeks A (równość pierwsza): B-tree przeskakuje bezpośrednio do wąskiego fragmentu (`PULocationID = 15`), a w jego obrębie dane są już posortowane wg daty — ciągły, mały fragment do odczytu.
  - Indeks B (zakres pierwszy): B-tree zawęża tylko z grubsza po dacie; wiersze z `PULocationID = 15` są rozrzucone w całym tym tygodniowym zakresie (przeplatane z innymi lokalizacjami) — trzeba przeszukać liniowo cały wycinek.
- **Zasada:** kolumna z warunkiem równości (`=`) powinna być pierwsza w indeksie złożonym, kolumna z warunkiem zakresowym (`>=`, `<`, `BETWEEN`) — druga.
- **Błąd po drodze:** pierwsza próba porównania dała mylący wynik — stary indeks (A) nie został usunięty przed testem indeksu B, więc planer po cichu użył starego zamiast nowego (ta sama nazwa `idx_yt_pulocationid_tpep_pickup_datetime` widoczna w planie, mimo że miał testować inny indeks). Dopiero usunięcie indeksu A i wymuszenie użycia B dało prawdziwe porównanie. Wniosek: przy takich testach trzeba sprawdzać **nazwę indeksu w planie**, nie tylko typ węzła.

---

## Case 5: Funkcja na kolumnie — indeks traci możliwość seek

**Cel:** pokazać różnicę między `Index Cond` (seek) a `Filter` (scan) przy tym samym indeksie.

```sql
-- QUERY bez funkcji (baseline z indeksem z case 1)
SELECT count(*)
FROM yellow_trips
WHERE tpep_pickup_datetime >= '2026-02-01'
  AND tpep_pickup_datetime <  '2026-02-02';

-- QUERY z funkcją na kolumnie
SELECT count(*)
FROM yellow_trips
WHERE date(tpep_pickup_datetime) = '2026-02-01';
```

```
-- EXPLAIN (ANALYZE, BUFFERS) — zakres dat, BEZ funkcji (Index Cond)
Aggregate  (cost=3285.48..3285.49 rows=1 width=8) (actual time=23.735..23.736 rows=1 loops=1)
  Buffers: shared hit=52746
  ->  Index Only Scan using idx_yt_pickup_datetime on yellow_trips  (cost=0.43..3020.15 rows=106130 width=0) (actual time=0.054..17.013 rows=123132 loops=1)
        Index Cond: ((tpep_pickup_datetime >= '2026-02-01') AND (tpep_pickup_datetime < '2026-02-02'))
        Heap Fetches: 0
Execution Time: 23.796 ms
```

```
-- EXPLAIN (ANALYZE, BUFFERS) — Z funkcją date() (Filter, nie Index Cond)
Finalize Aggregate  (cost=293645.67..293645.68 rows=1 width=8) (actual time=950.666..954.563 rows=1 loops=1)
  Buffers: shared hit=4855195 read=29193
  ->  Gather  (cost=293645.45..293645.66 rows=2 width=8) (actual time=950.502..954.548 rows=3 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        ->  Partial Aggregate  (cost=292645.45..292645.46 rows=1 width=8) (actual time=921.330..921.330 rows=1 loops=3)
              ->  Parallel Index Only Scan using idx_yt_pickup_datetime on yellow_trips  (cost=0.43..292567.81 rows=31059 width=0) (actual time=245.548..919.327 rows=41044 loops=3)
                    Filter: (date(tpep_pickup_datetime) = '2026-02-01'::date)
                    Rows Removed by Filter: 4928438
                    Heap Fetches: 0
Execution Time: 956.112 ms
```

**Porównanie:**

| | Bez funkcji (Index Cond) | Z funkcją date() (Filter) |
|---|---|---|
| Execution Time | 23,8 ms | 956,1 ms (**~40x wolniej**) |
| Buffers | hit=52746 | hit=4855195, read=29193 |
| Rows removed | 0 (indeks trafił precyzyjnie) | 4 928 438 (sprawdzone i odrzucone) |

**Wnioski:**
- Funkcja na indeksowanej kolumnie (`date(tpep_pickup_datetime)`) **nie zawsze eliminuje indeks całkowicie** — tu Postgres nadal użył go jako źródła danych (`Index Only Scan`, bo zapytanie nie potrzebowało innych kolumn poza datą), ale stracił możliwość *wyszukiwania* (seek) w nim.
- Warunek trafił do `Filter` zamiast `Index Cond` — każdy wpis w indeksie musiał zostać sprawdzony po kolei (`Rows Removed by Filter: 4928438` — prawie cała tabela), co jest efektywnie pełnym skanem, mimo że formalnie to nie `Seq Scan`.
- `Index Only Scan` (zamiast `Seq Scan`) wynika stąd, że zapytanie potrzebowało tylko `count(*)` — żadnej kolumny spoza indeksu. Przy `SELECT *` zamiast `count(*)` plan prawdopodobnie wyglądałby inaczej (zwykły Seq Scan na tabeli).
- **Rozwiązanie:** indeks na wyrażeniu (`CREATE INDEX ... ON yellow_trips (date(tpep_pickup_datetime))`) albo przepisanie warunku na zakres (`>= ... AND < ...`), jak w case 1.

---

## Powtarzające się motywy (ogólne wnioski z całego bloku)

1. **Sprawdzaj rozkład/parametry danych przed wyborem przykładu** — selektywność konkretnej wartości, `correlation` kolumny. Nie zakładaj z nazwy kolumny ani intuicji (błąd przy `payment_type = 4`).
2. **Sprawdzaj, który indeks faktycznie został użyty w planie** — nazwa indeksu, nie tylko typ węzła (błąd przy case 4, pierwsza próba porównania).
3. Selektywność i korelacja działają **razem** — decydują o realnym zysku z indeksu, nie sam fakt "czy indeks istnieje".
4. `Buffers` przy węzłach z `loops > 1` to suma ze wszystkich równoległych workerów, nie wartość per-proces — trzeba to uwzględniać przy porównaniach.
5. `Index Cond` vs `Filter` w planie to kluczowa różnica: pierwsze oznacza realne wyszukiwanie (seek) w indeksie, drugie — sprawdzanie warunku wpis po wpisie (efektywnie skan).