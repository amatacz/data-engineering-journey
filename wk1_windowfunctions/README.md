# Tydzień 1 — Funkcje okienkowe

## Kiedy ROW_NUMBER, kiedy RANK, kiedy DENSE_RANK

- **`ROW_NUMBER()`** — gdy potrzebuję gwarantowanej, unikalnej sekwencji (1, 2, 3, 4...)
  niezależnie od remisów. Przykład: "trzecia transakcja klienta" — to pytanie o pozycję
  w kolejności zdarzeń, nie o wartość z tolerancją na remisy.
- **`RANK()`** — gdy remisujące wiersze mają być traktowane identycznie, a kolejny rank
  ma przeskoczyć (1, 2, 2, 4). Przykład: "wszystkie transakcje z najnowszej daty" —
  jeśli klient ma kilka transakcji tego samego dnia, wszystkie powinny dostać rank 1.
- **`DENSE_RANK()`** — jak `RANK()`, ale bez przeskakiwania numerów (1, 2, 2, 3).
  Przykład: "top 3 *wartości*" (nie "top 3 *pozycje*") — jeśli druga i trzecia pozycja
  remisują, nadal chcę zobaczyć 3 różne wartości cenowe, nie ucinać na randze 3.

**Reguła kontrolna**: pytanie brzmi o *wartość* (ile różnych poziomów) czy o *pozycję*
(policzalne miejsce w kolejce)? Wartość → `DENSE_RANK`. Pozycja bez tolerancji na
remis → `ROW_NUMBER`. Pozycja z tolerancją na remis i przeskokiem → `RANK`.

## LAG / LEAD nie liczą różnicy same z siebie

`LAG`/`LEAD` tylko przesuwają wskaźnik do sąsiedniego wiersza — różnicę (czasową,
wartościową) zawsze liczę sama, osobnym odejmowaniem:
```sql
o_orderdate - lag(o_orderdate) over (...)  -- dni od poprzedniego
```
Uwaga na kierunek odejmowania — łatwo pomylić znak (nowsza data minus starsza = dodatnie).

## Ramki okna: pułapka na LAST_VALUE i NTH_VALUE

Domyślna ramka to `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` — rośnie wraz
z bieżącym wierszem. Dla `FIRST_VALUE` to nieszkodliwe (zawsze zaczyna od początku),
ale `LAST_VALUE` i `NTH_VALUE` bez jawnego:
```sql
ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
```
zwrócą wynik z bieżącego wiersza, nie z całej partycji. Sprawdzać zawsze przy tych
dwóch funkcjach.

## Tiebreaker w ORDER BY wewnątrz okna — kiedy jest potrzebny

Remis jest możliwy, gdy kolumna(y) w `ORDER BY` nie są gwarantowanie unikalne
w obrębie partycji. Test: "czy dwa różne rekordy mogłyby mieć tę samą wartość tej
kolumny?" — jeśli tak, potrzebny tiebreaker.

Kategorie ryzykowne: daty o niskiej precyzji, kolumny miary (cena, ilość), klucze obce.
Bezpieczne: klucz główny / unikalny indeks.

**Zasada**: tiebreaker musi różnicować wiersze *wewnątrz partycji*, nie być unikalny
w całej tabeli w ogóle. Kolumna, po której partycjonuję, nigdy nie nadaje się na
własny tiebreaker (jest stała w obrębie partycji).

## Checklista błędów, które popełniłam i mam pilnować na przyszłość

- [ ] Brak/niespójny alias kolumny z window function → referencja do nieistniejącej kolumny
- [ ] Zły wybór funkcji rankingowej dla kontekstu pytania (zobacz sekcję wyżej)
- [ ] Domyślna ramka okna przy `LAST_VALUE`/`NTH_VALUE` (RANGE zamiast ROWS)
- [ ] Brak lub niewłaściwy tiebreaker (dodanie kolumny, która nie różnicuje wewnątrz partycji)
- [ ] Zły znak/kierunek przy odejmowaniu dat lub wartości
- [ ] `LIMIT` bez `ORDER BY` na zapytaniu bez okna — niedeterministyczna kolejność wyników