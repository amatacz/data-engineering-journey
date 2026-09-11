-- =============================================================
-- Q: Calculate each user's average session time, where a session
-- is defined as the time difference between a page_load and a
-- page_exit. Assume one session per user per day. If there are
-- multiple page_load/page_exit events the same day, use the
-- latest page_load and the earliest page_exit. Only consider
-- sessions where page_load occurs before page_exit same day.
-- Output: user_id, avg_session
-- Uzyte: ROW_NUMBER() w dwoch osobnych CTE (loads/exits) -
-- potrzebujemy dokladnie jednego rekordu na user_id+day z kazdej
-- strony (najpozniejszy load, najwczesniejszy exit), a nastepnie
-- JOIN po user_id i dniu.
-- =============================================================
WITH
    loads AS (SELECT user_id, timestamp as load_time, DATE(timestamp) as day, action, ROW_NUMBER() OVER(PARTITION BY user_id, DATE(timestamp) ORDER BY timestamp DESC) as row_number FROM facebook_web_log WHERE action = 'page_load'),
    exits AS (SELECT user_id, timestamp as exit_time, DATE(timestamp) as day, action, ROW_NUMBER() OVER(PARTITION BY user_id, DATE(timestamp) ORDER BY timestamp ASC) as row_number FROM facebook_web_log WHERE action = 'page_exit')
SELECT loads.user_id,
    AVG(exits.exit_time - loads.load_time) as avg_session
FROM loads JOIN exits ON loads.user_id = exits.user_id AND loads.day = exits.day
WHERE loads.row_number = 1 AND exits.row_number = 1 AND exits.exit_time > loads.load_time
GROUP BY loads.user_id;

-- =============================================================
-- Q: Find the second highest salary of employees.
-- Output: salary
-- Uzyte: DENSE_RANK() - jesli kilku pracownikow ma te sama
-- najwyzsza pensje, wszyscy dostaja rank 1, a "druga" pensja
-- (rank 2) to nastepna, rozna wartosc, bez przeskakiwania rang.
-- =============================================================
WITH emp_salary AS (
    SELECT salary,
        DENSE_RANK() OVER(ORDER BY salary DESC) as salary_rnk
    FROM employee
)
SELECT salary
FROM emp_salary
WHERE salary_rnk = 2;

-- =============================================================
-- Q: Find the top 5 businesses with most reviews (jedna kolumna
-- z suma recenzji na wiersz). Przy remisach biznesy dostaja
-- ta sama range, a kolejne rangi sa pomijane (np. dwa biznesy
-- na 4 miejscu -> nastepny dostaje range 6).
-- Output: name, review_count
-- Uzyte: RANK() - wlasnie ta funkcja pomija numery rang po
-- remisie, w przeciwienstwie do DENSE_RANK().
-- =============================================================
WITH ranks AS (
    SELECT
        name, review_count,
        RANK() OVER(ORDER BY review_count DESC) as review_ranks
    FROM yelp_business
)
SELECT name, review_count
FROM ranks
WHERE review_ranks <= 5
ORDER BY review_count DESC;

-- =============================================================
-- Q: Rank guests by total messages exchanged with hosts. Remisy
-- maja te sama range, a ranga nie moze pomijac numerow nawet
-- gdy wielu gosci dzieli te sama pozycje.
-- Output: ranking, id_guest, sum_n_messages
-- Uzyte: DENSE_RANK() - wymog "bez pomijania numerow" przy
-- remisach wyklucza RANK(), ktore pomija kolejne rangi.
-- =============================================================
WITH messages_counted AS (
    SELECT id_guest, SUM(n_messages) as sum_n_messages
    FROM airbnb_contacts
    GROUP BY id_guest
)
SELECT DENSE_RANK() OVER(ORDER BY sum_n_messages DESC) as ranking, *
FROM messages_counted
ORDER BY sum_n_messages DESC;

-- =============================================================
-- Q: Compare total comments per country w grudniu 2019 i styczniu
-- 2020. Dla kazdego miesiaca rangujemy kraje wg sumy komentarzy
-- (remisy = ta sama ranga, bez przeskakiwania numerow). Zwroc
-- kraje, ktorych ranga poprawila sie (mniejszy numer) ze stycznia
-- wzgledem grudnia.
-- Output: country
-- Uzyte: DENSE_RANK() w dwoch osobnych CTE (miesiac po miesiacu),
-- polaczone JOIN-em po country, aby porownac rangi miedzy okresami.
-- =============================================================
WITH comments_2019 AS (
    SELECT fb_active_users.country,
        DENSE_RANK() OVER(ORDER BY SUM(fb_comments_count.number_of_comments) DESC) as comments_rank
    FROM fb_comments_count JOIN fb_active_users
        ON fb_comments_count.user_id = fb_active_users.user_id
    WHERE date_trunc('month', fb_comments_count.created_at) = '2019-12-01'
    GROUP BY fb_active_users.country
),
comments_2020 AS (
    SELECT fb_active_users.country,
        DENSE_RANK() OVER(ORDER BY SUM(fb_comments_count.number_of_comments) DESC) as comments_rank
    FROM fb_comments_count JOIN fb_active_users
        ON fb_comments_count.user_id = fb_active_users.user_id
    WHERE date_trunc('month', fb_comments_count.created_at) = '2020-01-01'
    GROUP BY fb_active_users.country
)
SELECT comments_2020.country
FROM comments_2020 JOIN comments_2019 ON comments_2020.country = comments_2019.country
WHERE comments_2020.comments_rank < comments_2019.comments_rank;

-- =============================================================
-- Q: Find the best-selling item for each month (bez rozbicia na
-- lata) wg total_paid = unitprice * quantity. Zwroty/anulacje
-- (invoiceno zaczynajace sie od 'C') pomijamy przy liczeniu sprzedazy.
-- Output: month, description, total_paid
-- Uzyte: RANK() PARTITION BY month - wystarczy jedna, najwyzsza
-- pozycja (rank = 1) na miesiac; przy ewentualnym remisie RANK()
-- zwroci obie pozycje, co jest tu akceptowalne (brak wymogu
-- unikalnosci).
-- =============================================================
WITH completed_sales AS (
    SELECT EXTRACT(month FROM invoicedate) as month, description, SUM(quantity*unitprice) as total_paid,
        RANK() OVER(PARTITION BY EXTRACT(month FROM invoicedate) ORDER BY SUM(quantity*unitprice) DESC) as total_rank
    FROM online_retail
    WHERE invoiceno NOT LIKE ('C%')
    GROUP BY description, EXTRACT(month FROM invoicedate)
)
SELECT month, description, total_paid
FROM completed_sales
WHERE total_rank = 1;

-- =============================================================
-- Q: Find all users who were active for 3 consecutive days or more.
-- Output: user_id, date_h (grupa), counted_days
-- Uzyte: ROW_NUMBER() do klasycznej techniki "gaps and islands" -
-- odejmujac numer wiersza (posortowany po dacie) od samej daty,
-- kolejne dni aktywnosci daja te sama wartosc roznicy, co pozwala
-- je zgrupowac i policzyc dlugosc serii.
-- =============================================================
WITH distinct_days AS (
    SELECT DISTINCT user_id, record_date as date_h FROM sf_events
    ORDER BY user_id ASC, date_h ASC
),
consecutive_days AS (
    SELECT user_id, date_h - ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY date_h)::int AS date_h
    FROM distinct_days
),
counted_consecutive_days AS (
    SELECT user_id, date_h,
        COUNT(date_h) as counted_days
    FROM consecutive_days
    GROUP BY user_id, date_h
)
SELECT * FROM counted_consecutive_days
WHERE counted_days >= 3;

-- =============================================================
-- Q: Calculate the month-over-month percentage change in revenue.
-- Output: year_month (YYYY-MM), revenue_diff_pct (zaokraglone do 2
-- miejsc po przecinku), od 2. miesiaca, posortowane chronologicznie.
-- Uzyte: LAG() - potrzebujemy wartosci z poprzedniego wiersza
-- (poprzedniego miesiaca) w tym samym zapytaniu, bez self-joina.
-- =============================================================
WITH sales_by_month AS (
    SELECT TO_CHAR(created_at, 'YYYY-MM') as year_month, SUM(value) as this_month_revenue,
        LAG(SUM(value)) OVER(ORDER BY TO_CHAR(created_at, 'YYYY-MM')) as previous_month_revenue
    FROM sf_transactions
    GROUP BY year_month
)
SELECT year_month, ROUND(((this_month_revenue - previous_month_revenue)::numeric / previous_month_revenue)*100, 2) as revenue_diff_pct
FROM sales_by_month
ORDER BY year_month;

-- =============================================================
-- Q: Find the third transaction of every user.
-- Output: user_id, spend, transaction_date
-- Uzyte: ROW_NUMBER() zamiast RANK() - potrzebuje gwarantowanej,
-- unikalnej sekwencji nawet przy remisach na transaction_date.
-- =============================================================
WITH transaction_counter AS (
    SELECT *,
        ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY transaction_date) as transaction_queue
    FROM transactions
)
SELECT user_id, spend, transaction_date
FROM transaction_counter
WHERE transaction_queue = 3
ORDER BY user_id;

-- =============================================================
-- Q: Calculate the 3-day rolling average of tweets for each user.
-- Output: user_id, tweet_date, rolling_avg (zaokraglone do 2 miejsc)
-- Uzyte: AVG() OVER z ramka ROWS BETWEEN 2 PRECEDING AND CURRENT ROW -
-- klasyczna ruchoma srednia liczona po wierszach, a nie po zakresie dat.
-- =============================================================
SELECT
    user_id, tweet_date,
    ROUND(AVG(tweet_count) OVER(PARTITION BY user_id
        ORDER BY tweet_date ROWS
        BETWEEN 2 PRECEDING AND CURRENT ROW), 2) as rolling_avg
FROM tweets
ORDER BY user_id, tweet_date;

-- =============================================================
-- Q: Identify the top two highest-grossing products within each
-- category w 2022 roku.
-- Output: category, product, total_product_spend
-- Uzyte: DENSE_RANK() PARTITION BY category - przy remisie na
-- sumie wydatkow oba produkty powinny dostac range 1, a "top 2"
-- oznacza dwie rozne wartosci sumy, nie dwa wiersze wprost.
-- =============================================================
WITH total_product_spend_22 AS (
    SELECT category, product, SUM(spend) as total_product_spend
    FROM product_spend
    WHERE EXTRACT(year FROM transaction_date) = 2022
    GROUP BY category, product
),
total_product_spend_22_ranked AS (
    SELECT *,
        DENSE_RANK() OVER(PARTITION BY category ORDER BY total_product_spend DESC) as total_spend_rank
    FROM total_product_spend_22
)
SELECT category, product, total_product_spend
FROM total_product_spend_22_ranked
WHERE total_spend_rank <= 2;

-- =============================================================
-- Q: Identify high earners in each department - pracownicy w top 3
-- pensji w swoim dziale. Sortowanie: department_name ASC, salary DESC,
-- a przy takiej samej pensji alfabetycznie po imieniu.
-- Output: department_name, name, salary
-- Uzyte: DENSE_RANK() PARTITION BY department_id - "top 3" ma
-- oznaczac trzy rozne poziomy pensji (przy remisie wszyscy z tym
-- samym wynagrodzeniem miesza sie w tej samej randze), stad
-- DENSE_RANK(), a nie ROW_NUMBER().
-- =============================================================
WITH ranked_salary AS (
    SELECT name, salary, department_id,
        DENSE_RANK() OVER(PARTITION BY department_id ORDER BY salary DESC) AS ranking
    FROM employee
)
SELECT
    d.department_name,
    s.name,
    s.salary
FROM ranked_salary s
INNER JOIN department d
    ON s.department_id = d.department_id
WHERE s.ranking <= 3
ORDER BY d.department_name ASC, s.salary DESC, s.name ASC;

-- =============================================================
-- Q: Calculate the sum of odd-numbered and even-numbered
-- measurements osobno dla kazdego dnia (kolejnosc wg czasu pomiaru
-- w obrebie dnia).
-- Output: measurement_day, odd_sum, even_num
-- Uzyte: ROW_NUMBER() do ponumerowania pomiarow w ramach dnia,
-- a nastepnie CASE + SUM z warunkiem na parzystosc numeru (modulo).
-- =============================================================
WITH measurements_ordered AS (
    SELECT
        measurement_value, measurement_time,
        ROW_NUMBER() OVER(PARTITION BY DATE_TRUNC('DAY', measurement_time) ORDER BY measurement_time) as measurement_number
    FROM measurements
)
SELECT
    DATE_TRUNC('DAY', measurement_time) as measurement_day,
    SUM(
        CASE
            WHEN measurement_number % 2 <> 0
            THEN measurement_value
            ELSE 0
        END
    ) as odd_sum,
    SUM(
        CASE
            WHEN measurement_number % 2 = 0
            THEN measurement_value
            ELSE 0
        END
    ) as even_num
FROM measurements_ordered
GROUP BY measurement_day
ORDER BY measurement_day ASC;

-- =============================================================
-- Q: Find the highest and lowest open prices for each FAANG stock
-- per month-year (format 'Mon-YYYY'), wraz z okresem, w ktorym
-- wystapily.
-- Output: ticker, highest_mth, highest_open, lowest_mth, lowest_open
-- Uzyte: dwa niezalezne RANK() (osobno dla max i osobno dla min
-- open) w jednej CTE, a nastepnie dwa filtry (rank_high=1,
-- rank_low=1) polaczone JOIN-em po ticker - dzieki temu jedno
-- przejscie po danych daje oba ekstrema naraz.
-- =============================================================
WITH ranked_opens AS (
    SELECT
        TO_CHAR(date, 'Mon-YYYY') as month, ticker, open,
        RANK() OVER(PARTITION BY ticker ORDER BY open DESC) as open_rank_high,
        RANK() OVER(PARTITION BY ticker ORDER BY open ASC) as open_rank_low
    FROM stock_prices
),
highest_opens AS (
    SELECT
        month, ticker, open
    FROM ranked_opens
    WHERE open_rank_high = 1
),
lowest_opens AS (
    SELECT
        month, ticker, open
    FROM ranked_opens
    WHERE open_rank_low = 1
)
SELECT
    h.ticker,
    h.month as highest_mth,
    h.open as highest_open,
    l.month as lowest_mth,
    l.open as lowest_open
FROM highest_opens h JOIN lowest_opens l
    ON h.ticker = l.ticker
ORDER BY h.ticker;

-- =============================================================
-- Q: Find the best-selling product in each product category. Przy
-- remisie na ilosci sprzedazy decyduje wyzszy rating.
-- Output: category_name, product_name (alfabetycznie wg kategorii)
-- Uzyte: RANK() PARTITION BY category_name z dwoma kryteriami
-- sortowania (sales_quantity DESC, rating DESC) - drugie kryterium
-- rozstrzyga remisy z pierwszego, a rank=1 daje zwyciezce(ow).
-- =============================================================
WITH ranked_products AS (
    SELECT
        p.product_id, p.product_name,
        p.category_name, ps.sales_quantity, ps.rating,
        RANK() OVER(PARTITION BY p.category_name
            ORDER BY ps.sales_quantity DESC, ps.rating DESC) as ranking
    FROM products p
    JOIN product_sales ps
        ON p.product_id = ps.product_id
)
SELECT category_name, product_name
FROM ranked_products
WHERE ranking = 1
ORDER BY category_name, product_name;

-- =============================================================
-- Q: Na podstawie najnowszej daty transakcji kazdego uzytkownika,
-- zwroc uzytkownikow wraz z liczba zakupionych produktow.
-- Output: transaction_date, user_id, purchase_count (posortowane
-- chronologicznie wg daty transakcji)
-- Uzyte: RANK() PARTITION BY user_id ORDER BY transaction_date DESC -
-- wybieramy wszystkie wiersze z najnowsza data (rank=1), co pozwala
-- policzyc COUNT(product_id) dla calego, ostatniego dnia transakcji.
-- =============================================================
WITH transactions_days_ranked AS (
    SELECT user_id, product_id, transaction_date,
        RANK() OVER(PARTITION BY user_id ORDER BY transaction_date DESC) as transactions_days_rank
    FROM user_transactions
)
SELECT transaction_date, user_id, COUNT(product_id) as purchase_count
FROM transactions_days_ranked
WHERE transactions_days_rank = 1
GROUP BY user_id, transaction_date
ORDER BY transaction_date;
