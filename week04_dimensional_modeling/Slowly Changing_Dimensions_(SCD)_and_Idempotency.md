# 📊 SQL & Data Engineering Cheat Sheet: Slowly Changing Dimensions (SCD) & Idempotency

## 1. Idempotentność (Idempotency) - Fundament Data Engineeringu
**Idempotentność** to właściwość pipeline'u danych, która gwarantuje, że proces **zawsze wygeneruje dokładnie ten sam wynik**, niezależnie od tego:
* W jakim dniu zostanie uruchomiony.
* Ile razy zostanie uruchomiony (ponowne uruchomienie nie duplikuje danych).
* O jakiej godzinie zostanie uruchomiony.

### ⚠️ Dlaczego brak idempotentności to problem?
* **Silent failures (Ciche błędy):** Pipeline nie wyrzuca błędów, ale generuje niespójne/błędne dane.
* **Problemy z backfillingiem:** Ponowne załadowanie danych z przeszłości generuje inne wyniki niż pierwotne uruchomienie na produkcji.
* **Koszmar debugowania:** Błędy są trudne do odtworzenia, a testy jednostkowe nie odzwierciedlają zachowania na produkcji.
* **Utrata zaufania analityków:** Zespół traci zaufanie do hurtowni danych z powodu niespójności w raportach.

### ❌ Złe praktyki (Pipeline'y NIE-idempotentne)
* Używanie `INSERT INTO` bez wcześniejszego `TRUNCATE` (powoduje duplikację danych przy każdym uruchomieniu).
* Stosowanie warunków opartych tylko na jednej dacie, np. `start_date > X` bez domknięcia okna czasowego (np. brakuje `end_date < Y`). Otwiera to drogę do wczytania nieprzewidywalnej ilości danych.
* Brak sprawdzania wszystkich potrzebnych partycji (pipeline rusza, zanim wszystkie dane źródłowe są gotowe).
* Poleganie na "najnowszej partycji" (latest snapshot) lub funkcji dających obecną datę (np. sprawdzanie względem *dzisiaj* przy backfillingu przeszłych danych).
* Brak użycia mechanizmów takich jak `depends_on_past` w przypadku tabel skumulowanych (np. w Airflow).

### ✅ Dobre praktyki (Pipeline'y Idempotentne)
* Używanie poleceń `MERGE` (UPSERT) lub `INSERT OVERWRITE` zamiast zwykłego `INSERT INTO`.
* Precyzyjne definiowanie okien czasowych (`WHERE date >= start_date AND date < end_date`).
* Zapewnienie, że w przypadku tabel skumulowanych dane są ładowane w ścisłej kolejności chronologicznej.

---

## 2. Slowly Changing Dimensions (SCD)
Wymiary zmieniające się w czasie (SCD) służą do śledzenia zmian wartości atrybutów (np. zmiana kraju zamieszkania użytkownika, zmiana preferencji).

### Typy SCD:
* **Type 0:** Wymiary niezmienne. Raz zapisana wartość nigdy się nie zmienia (np. data urodzenia). Są z natury idempotentne.
* **Type 1:** **NIE UŻYWAĆ (jeśli to możliwe).** Zawsze nadpisuje starą wartość nową. Tracisz historię, a pipeline przestaje być idempotentny, ponieważ wynik zależy od tego, w którym momencie odpytasz tabelę.
* **Type 2:** **Złoty standard (Gold Standard).** Śledzi historię zmian. 
  * Wymaga kolumn: `start_date`, `end_date` (oraz często flagi np. `is_current`). 
  * Aktualny rekord ma zazwyczaj `end_date` ustawiony daleko w przyszłość (np. `9999-12-31`) lub `NULL`. 
  * Jest idempotentny – zapytanie o stan na konkretny dzień w przeszłości zawsze da ten sam wynik.
* **Type 3:** Przechowuje tylko "oryginalną" i "obecną" wartość (w osobnych kolumnach). Tracisz stany pośrednie. Tylko częściowo idempotentny. Raczej odradzany.

---

## 3. Strategie modelowania w zależności od tempa zmian
Zanim zdecydujesz się na SCD Type 2, oceń, jak często zmieniają się wymiary:

1. **Daily/Monthly Snapshots (Codzienne zrzuty):**
   * Najlepsze, jeśli wymiar zmienia się bardzo szybko (Rapidly Changing Dimensions). 
   * Zamiast tworzyć skomplikowaną logikę dat (start/end) i setki wierszy, po prostu rób zrzut całego stanu na dany dzień.
2. **SCD Type 2:**
   * Najlepsze dla wolno zmieniających się wymiarów, gdzie kompresja danych ma znaczenie i chcemy łatwo śledzić momenty zmian. Zamiast 365 wierszy z rzędu na jeden rok (jak w daily snapshot), masz np. 1-2 wiersze określające dokładne ramy czasowe obowiązywania danej wartości.
3. **Latest Snapshot Only:**
   * Zła praktyka. Patrz: *SCD Type 1*. Prowadzi do utraty historii i niemożności poprawnego backfillingu danych powiązanych z tym wymiarem.

> 💡 **Zapamiętaj:** Najważniejszą cechą dobrego pipeline'u jest jego **idempotentność**. Zachowanie na produkcji i podczas ręcznego przeładowywania danych (backfill) musi być identyczne.
