### Metoda: 4 pytania przed napisaniem jakiegokolwiek SQL
**Based on: Znajdź 5 najczęściej zamawianych części w segmencie klientów BUILDING (customer.c_mktsegment), z rozbiciem na rok złożenia zamówienia.**

#### 1. Jaka jest jednostka wyniku? (co to jest jeden wiersz w odpowiedzi?)
Zanim napiszesz SELECT, dokończ zdanie: *Każdy wiersz wyniku to jeden ___.*
W Twoim zadaniu: *każdy wiersz to jedna część, w danym roku, o ile jest w top 5 tego roku*. To Ci od razu mówi, że musisz grupować po (part, year) — to jest granularność, do której musisz dojść przez GROUP BY, zanim cokolwiek innego się wydarzy.
Gdybyś zadała sobie to pytanie w zadaniu z subquery, złapałabyś od razu: *moja jednostka wyniku to (część, rok), ale porównuję ją do ranked, które nie jest ani częścią, ani rokiem, ani ilością — to liczba porządkowa. Coś tu nie gra.*

#### 2. Czy jest tu agregacja, a jeśli tak — na jakim poziomie?
Zapytaj: *czy liczę coś (SUM, COUNT, AVG) i na jakiej granularności?* Tu masz dwie agregacje na dwóch różnych poziomach, i to jest właśnie źródło komplikacji:
* Poziom 1: SUM(l_quantity) per (part, year) — to Twój "surowy" wynik
* Poziom 2: ranking w obrębie roku, czyli operacja na wyniku poziomu 1, nie na surowych danych
To jest sygnał: jeśli masz agregację nałożoną na agregację, prawdopodobnie potrzebujesz CTE albo subquery jako *warstwy pośredniej* — nie da się tego zrobić w jednym płaskim GROUP BY. Window function to dokładnie narzędzie do *poziomu 2* (operacja na już zagregowanych wierszach, z podziałem na grupy).

#### 3. Czy porównanie jest do jednej wartości, czy do wartości zależnej od grupy?
To jest test, który odróżnia *łatwe subquery* od *subquery, które będzie bolało*:
Jedna globalna/skorelowana wartość (np. "więcej niż średnia w MOIM kraju") → subquery jest naturalne, bo zwraca jeden skalar per wiersz zewnętrzny.
Wartość zależna od pozycji w rankingu wewnątrz grupy (np. "top 5 W KAŻDYM roku") → to wymaga posortowania i obcięcia osobno dla każdej grupy — subquery musi to symulować (LIMIT w podzapytaniu skorelowanym, co jest niewygodne), a window function robi to natywnie (PARTITION BY).
To pytanie od razu przewiduje, że zadanie 1 (klienci vs średnia krajowa) będzie łatwe w subquery, a zadanie 3 (top 5 per rok) będzie bolało — zanim zaczniesz pisać, nie po fakcie.

#### 4. W jakiej kolejności muszą się wykonać kroki?
Rozpisz to słownie, po polsku, zanim napiszesz SQL. Dla zadania 3:
* Połącz customer→orders→lineitem→part, odfiltruj BUILDING
* Zsumuj quantity per (part, year)
* Na wyniku kroku 2 — nadaj ranking w obrębie roku
* Odfiltruj ranking ≤5
