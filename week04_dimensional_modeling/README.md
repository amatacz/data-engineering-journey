## Decyzje projektowe

### 1. Proces biznesowy:
    Realizacja kursu taksówką, rejestrowana przez system taksometru i raportowana do TLC.
### 2. Grain
    `fact_trips` -> jeden wiersz = jedna podróż taksówki, jeden rekord z pliku 'TLC Yellow Taxi'. Jest to najniższy poziom, rejestrowany jako jeden rekord bez względu na liczbę pasażerów.
### 3. Surrogate key
    Surrogate key w `dim_location` identyfikuje wiersz w bazie danych, a nie sam id lokacji w tym przypadku. Nie zmienia się, ale tez nie ma odzwierciedlenia w realnym świecie. W przypadku slowly changing dimensions, lokacja może zmienić swoje atrybuty, np. `service_zone`, więc surrogate key będzie wskazywało na konkretną wersję obowiązującą w dniu kursu.
### 4. Dlaczego rodzielamy `dim_date` i `dim_time` zamiast umieścić w jednej tabeli `dim_datetime`
    Ze względu na:
        * liczebność -> daty i czas liczone co do minuty daje ponad 500 tys. wierszy na rok, tabela byłaby ogromna
        * atrybuty w tabelach są od siebie niezależne -> np. `is_weekend`, `month_name` nie zależą od `dim_time`
        * analizy wykonywane są zależnie od jednego albo drugiego wymiaru -> *ile kursów rano, każdego dnia?* albo *czy ruch jest wiekszy w weekend?*