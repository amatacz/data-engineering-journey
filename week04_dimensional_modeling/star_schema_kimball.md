# 📊 SQL & Data Engineering Cheat Sheet: Data Modeling (Star Schema / Kimball)

Podejście zdenormalizowane (często nazywane **Kimball modeling** lub **Star Schema**) to jedna z najpopularniejszych metod budowy hurtowni danych. Składa się z trzech głównych komponentów: Tabel Faktów, Tabel Wymiarów oraz Data Martów.

## 1. Tabele Faktów (Fact Tables)
Tabele faktów to fundament hurtowni danych. Reprezentują konkretne działania biznesowe lub transakcje (np. złożenie zamówienia, płatność).

### 🔑 Kluczowe zasady dla Tabel Faktów:
* **Niski poziom szczegółowości (Low Granularity):** Powinny reprezentować najniższy możliwy poziom detali (tzw. *stay true to the grain*), np. pojedyncza linia na paragonie (transaction level) zamiast całego zamówienia. Daje to największą elastyczność przy późniejszych agregacjach.
* **Zawartość:** Zawierają głównie **Klucze Obce (Foreign Keys)** do tabel wymiarów oraz **Wartości Liczbowe / Metryki (Numeric Values / Aggregates)** (np. cena, ilość, kwota podatku, zniżka).
* **Czego unikać:** W tabelach faktów **nie powinno być** żadnych opisów tekstowych ani atrybutów (np. nazwy produktu, imienia klienta). Te informacje lądują w wymiarach.

## 2. Tabele Wymiarów (Dimension Tables)
Wymiary nadają kontekst liczbom znajdującym się w tabelach faktów. Opisują "kto, co, gdzie, kiedy, jak i dlaczego" transakcji.

### 🔑 Kluczowe zasady dla Tabel Wymiarów:
* **Zawartość:** Zawierają atrybuty i opisy (np. nazwa produktu, kategoria, imię i nazwisko pracownika, miasto, stan, kod pocztowy).
* **Struktura:** Są to zazwyczaj tabele szerokie (wide) i zdenormalizowane (flat/denormalized). Zamiast tworzyć osobne tabele dla `City`, `State` i `Zip`, wszystko to łączy się w jeden wymiar, np. `dim_cities` lub `dim_locations`.
* **Powiązanie:** Łączą się z tabelami faktów za pomocą unikalnych kluczy (ID).

## 3. Tworzenie Data Martów (Data Marts)
Data Mart to warstwa końcowa, z którą wchodzą w interakcję użytkownicy (np. analitycy, narzędzia BI takie jak Tableau czy PowerBI, raporty emailowe).

* Powstają poprzez proste złączenia (`JOIN`) Tabel Faktów z Tabelami Wymiarów (na podstawie ID).
* Mogą to być tabele lub widoki (views).
* Pozwalają na agregowanie, grupowanie i filtrowanie (slice and dice) danych (np. `Całkowita sprzedaż pogrupowana po nazwie produktu i mieście`).

---

## 🛠️ 3 Kroki Modelowania Danych (Star Schema)
1. **Identify a Fact (Zidentyfikuj fakt):** Znajdź główną aktywność biznesową z systemów źródłowych (np. transakcje płatnicze) i ustal jej ziarno (grain).
2. **Determine Dimensions (Określ wymiary):** Wyciągnij atrybuty opisowe (klienci, pracownicy, produkty) i utwórz z nich zdenormalizowane tabele `dim_...`.
3. **Create Marts (Utwórz marty):** Zbuduj widoki biznesowe, łącząc fakty i wymiary.

---

## 🌟 Zalety i dodatkowe koncepcje
### Dlaczego warto stosować Star Schema?
* **Powszechność:** Jest to świetnie udokumentowane, sprawdzone w czasie (time-tested) podejście.
* **Elastyczność:** Radzi sobie z bardzo skomplikowanymi scenariuszami, nawet w nowoczesnych stackach technologicznych (Modern Data Stack).
* **Klarowność:** Zapewnia przejrzystość i stabilność hurtowni danych, ułatwiając pracę analitykom.

### Koncepcje zaawansowane (Do dalszej nauki):
* **Conformed Dimensions (Wymiary współdzielone):** Tabele wymiarów (np. Data, Pracownik), które są używane przez wiele różnych tabel faktów.
* **Surrogate Keys (Klucze zastępcze):** Sztuczne klucze główne tworzone w hurtowni danych, gdy system źródłowy nie dostarcza odpowiedniego unikalnego ID.
* **Indexing:** Tworzenie indeksów (np. clustered/non-clustered) na kluczach w celu poprawy wydajności zapytań (szczególnie przy dużej liczbie złączeń).
