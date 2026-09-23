# Cheatsheet: Jak czytać EXPLAIN / EXPLAIN ANALYZE w PostgreSQL

## 1. Różnica między poleceniami

* **`EXPLAIN`** – pokazuje **szacowany plan** (nie wykonuje zapytania).
* **`EXPLAIN ANALYZE`** – **wykonuje zapytanie** i podaje rzeczywiste czasy oraz liczbę wierszy. *(Uwaga: operacje `INSERT/UPDATE/DELETE` zostaną wykonane w bazie!)*
* **`EXPLAIN (ANALYZE, BUFFERS)`** – wykonuje zapytanie i dodatkowo pokazuje użycie pamięci/dysku (rekomendowany standard).

---

## 2. Anatomia pojedynczej linii węzła

Przykładowy węzeł:
`-> Parallel Seq Scan on yellow_trips (cost=0.00..408944.01 rows=347385 width=8) (actual time=1354.233..4934.851 rows=289388 loops=3)`

### A. Szacunki optymalizatora (przed wykonaniem)
* **`cost=0.00..408944.01`**:
  * **Pierwsza liczba (`0.00`)**: Koszt startowy – ile "kosztuje" zwrócenie pierwszego wiersza.
  * **Druga liczba (`408944.01`)**: Koszt całkowity – szacowany nakład pracy do zakończenia operacji.
* **`rows=347385`**: Szacowana liczba wierszy zwracana przez ten węzeł (na 1 loop).
* **`width=8`**: Średnia szerokość wiersza w bajtach.

### B. Wyniki rzeczywiste (z `ANALYZE`)
* **`actual time=1354.233..4934.851`**:
  * **Pierwsza liczba (`1354.233` ms)**: Czas do zwrócenia pierwszego wiersza.
  * **Druga liczba (`4934.851` ms)**: Czas wykonania tego węzła dla jednego powtórzenia (`loop`).
* **`rows=289388`**: Średnia **rzeczywista** liczba wierszy zwrócona przez **jeden** wątek/węzeł.
* **`loops=3`**: Liczba powtórzeń wykonania danego węzła (np. przez pracę równoległą/spółdzielczą).

> ⚠️ **WAŻNE (Obliczanie całkowitego czasu i wierszy):**
> * **Łączny czas węzła** ≈ `actual time (druga liczba)` × `loops`.
> * **Łączna liczba wierszy** = `rows` × `loops`.

---

## 3. Statystyki BUFFERS (Pamięć vs Dysk)

`Buffers: shared hit=834211 read=20108 written=27`
*(Wszystkie wartości są w bloki po **8 KB**)*

* **`hit`**: Bloki pobrane bezpośrednio z pamięci RAM (`shared_buffers`) – **BARDZO SZYBKIE**.
* **`read`**: Bloki, których nie było w RAM-ie i musiały zostać odczytane z dysku – **WOLNE**.
* **`written`**: Bloki zmodyfikowane i zapisane na dysk z powodu braku miejsca w RAM.
* **`temp read / temp written`**: Tymczasowe dane zapisane na dysku (np. przy dużym `SORT` lub `HASHJOIN`, który nie zmieścił się w `work_mem`).

---

## 4. Kluczowe Metody Dostęp do Danych (Access Methods)

| Metoda | Opis | Kiedy dobra? |
| :--- | :--- | :--- |
| **`Seq Scan`** | Czytanie całej tabeli wiersz po wierszu z odrzucaniem niepasujących. | Małe tabele lub pobieranie >15-20% całej tabeli. |
| **`Index Scan`** | Szukanie w indeksie + pobieranie pozostałych kolumn z tabeli dla każdego trafienia. | Pobieranie niewielkiej liczby wierszy (selektywne warunki). |
| **`Index Only Scan`** | Pobieranie danych **wyłącznie z indeksu** (bez dotykania tabeli głównej). | Najszybsza opcja. Wymaga pokrycia wszystkich wybranych kolumn przez indeks. |
| **`Bitmap Index/Heap Scan`** | Najpierw zbiera pozycje z indeksu w "mapę bitową", sortuje je, a potem hurtowo czyta tabelę. | Pobieranie średniej liczby wierszy (redukuje skakanie po dysku). |

---

## 5. Metody Łączenia Tabel (Joins)

* **`Nested Loop`**: Dla każdego wiersza z tabeli A szuka dopasowania w tabeli B. 
  * *Dobry gdy:* Tabela A jest bardzo mała, a B ma indeks.
* **`Hash Join`**: Wczytuje małą tabelę do pamięci RAM (Hash Table), a potem skanuje drugą tabelę i dopasowuje.
  * *Dobry gdy:* Łączysz duże tabele bez indeksów.
* **`Merge Join`**: Sortuje obie tabele po kluczu łączenia i "scala" je w jednym przejściu.
  * *Dobry gdy:* Dane są już posortowane (np. przez indeks).

---

## 6. Praca Równoległa (Parallel Execution)

* **`Gather`**: Proces główny zbierający wyniki od procesów pomocniczych (`workers`).
* **`Workers Planned / Launched`**: Liczba planowanych vs faktycznie uruchomionych procesów roboczych.
* **`Parallel [Seq/Index] Scan`**: Skanowanie podzielone na wiele wątków.

---

## 7. Czerwone Flagi (Na co zwracać uwagę w pierwszej kolejności?)

1. **Różnica między szacowaną (`rows`) a rzeczywistą liczbą wierszy (`actual rows`)**:
   * Jeśli różnica jest 10x lub większa → statystyki bazy są nieaktualne. Uruchom `ANALYZE nazwa_tabeli;`.
2. **Duża wartość `Rows Removed by Filter`**:
   * Oznacza, że baza czyta mnóstwo danych tylko po to, by je odrzucić → **brakuje indeksu** na kolumnach z sekcji `WHERE`.
3. **Wysokie `read` w sekcji `Buffers`**:
   * Zapytanie bije po dysku zamiast po pamięci RAM.
4. **Obecność `temp read / temp written`**:
   * Operacja sortowania lub agregacji nie mieści się w pamięci (`work_mem`) i zrzuca dane na dysk.
5. **Czas `JIT` (Just-In-Time Compilation)**:
   * Jeśli `JIT timing` stanowi duży % całkowitego czasu prostego zapytania, warto rozważyć wyłączenie JIT dla tego połączenia (`SET jit = off;`).