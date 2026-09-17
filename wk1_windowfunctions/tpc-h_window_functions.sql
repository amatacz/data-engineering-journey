-- =============================================================
-- Q: Dla każdego klienta policz sumę wartości jego zamówien 
-- i porankinguj ich w obrębie narodowości trzema różnymi funkcjami na raz.
-- RANK(), DENSE_RANK(), ROW_NUMBER()
-- Output: c_custkey, c_nationkey, total_orders_value, cust_rank, cust_dense_rank, cust_row_number
-- Zidentyfikowano 2 klientów w obrębie tego samego kraju, którzy mają taki sam wynik
-- RANK() i DENSE_RANK() plasują go na tej samej pozycji, ROW_NUMBER() numeruje klientów bez względu na duplikat
-- =============================================================

with total_orders as (
select cust.c_custkey, cust.c_nationkey, SUM(o.o_totalprice) as total_orders_value,
rank() over (partition by cust.c_nationkey order by SUM(o.o_totalprice) desc) as cust_rank,
dense_rank() over(partition by cust.c_nationkey order by SUM(o.o_totalprice) desc) as cust_dense_rank,
row_number() over(partition by cust.c_nationkey order by SUM(o.o_totalprice) desc) as cust_row_number
from tpch.customer cust 
inner join tpch.orders o
on cust.c_custkey = o.o_custkey 
group by cust.c_custkey
)
select * from total_orders 
where (c_nationkey, total_orders_value) IN (
    SELECT c_nationkey, total_orders_value 
    FROM total_orders 
    GROUP BY c_nationkey, total_orders_value 
    HAVING COUNT(*) > 1
)
order by c_nationkey, total_orders_value;


-- ===========================================================
-- Dla każdego klienta weź jego zamówienia posortowane po `o_orderdate` 
-- i policz różnicę czasową (`LAG`) oraz różnicę wartości (`o_totalprice`) między kolejnymi zamówieniami tego samego klienta. 
-- Dodatkowo użyj `LEAD`, żeby dla każdego zamówienia pokazać datę *następnego* zamówienia. 
-- To pozwoli odpowiedzieć na pytanie: jak długie są przerwy między zamówieniami klienta — przydatne np. do analizy churnu.
-- ===========================================================

with orders_data as (
select 
	c.c_custkey, o.o_orderdate, o.o_totalprice,
	lag(o.o_orderdate) over(partition by c.c_custkey order by o.o_orderdate) as previous_order_date,
	lag(o.o_totalprice) over(partition by c.c_custkey order by o.o_orderdate) as previous_order_value,
	lead(o.o_orderdate) over(partition by c.c_custkey order by o.o_orderdate) as next_order_date,
	lead(o.o_totalprice) over(partition by c.c_custkey order by o.o_orderdate) as next_order_value
from tpch.customer c 
inner join tpch.orders o 
	on c.c_custkey = o.o_custkey
)
select c_custkey,
(o_orderdate - previous_order_date) as days_since_last_order,
(next_order_date - o_orderdate) as days_to_next_order,
(o_totalprice - previous_order_value) as value_diff_from_previous,
(next_order_value - o_totalprice) as value_diff_to_next
from orders_data
order by c_custkey, o_orderdate;


-- ======================================================
-- Dla każdego klienta policz **running total** wydatków w czasie 
-- (`SUM() OVER (PARTITION BY o_custkey ORDER BY o_orderdate ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`)
-- oraz **moving average** z 3 ostatnich zamówień 
-- (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`). 
-- Porównaj wynik dla klienta z dużą liczbą zamówień — zobacz jak running total rośnie
-- monotonicznie, a moving average wygasza skoki.
-- ======================================================

with all_orders_info as (
select
	c.c_custkey, o.o_totalprice, o.o_orderdate,
	sum(o.o_totalprice) over(partition by o.o_custkey order by o.o_orderdate, o.o_orderkey rows between unbounded preceding and current row) as running_total_orders_value,
	avg(o.o_totalprice) over(partition by o.o_custkey order by o.o_orderdate, o.o_orderkey rows between 2 preceding and current row) as moving_average_total_orders_value
from tpch.customer c 
inner join tpch.orders o 
	on c.c_custkey = o.o_custkey 
)	
select * from all_orders_info;

-- ==================================================
-- Dla każdego klienta znajdź **pierwszą** (`FIRST_VALUE`)
-- i **ostatnią** (`LAST_VALUE`) datę zamówienia. 
-- Uwaga na klasyczną pułapkę z `LAST_VALUE`: domyślna ramka okna to `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`,
-- więc bez jawnego określenia `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`, `LAST_VALUE` zwróci **bieżący** wiersz, nie faktycznie ostatni. 
-- Sprawdź to na własne oczy — policz bez i z tym doprecyzowaniem, zobacz różnicę w wynikach.
-- ==================================================

select
	o.o_custkey, o.o_orderdate,
	first_value(o.o_orderdate) over(partition by o.o_custkey order by o.o_orderdate, o.o_orderkey) as first_order_date,
	last_value(o.o_orderdate) over(partition by o.o_custkey order by o.o_orderdate, o.o_orderkey) as currently_last_order_date,
	last_value(o.o_orderdate) over(partition by o.o_custkey order by o.o_orderdate, o.o_orderkey rows between unbounded preceding and unbounded following) as actual_last_order_date
from tpch.orders o
;

-- ===================================================
-- Użyj `NTH_VALUE(o_totalprice, 2)` w oknie partycjonowanym po kliencie i posortowanym po `o_orderdate`, 
-- żeby znaleźć wartość **drugiego** zamówienia każdego klienta. 
-- Porównaj wynik z podejściem przez `ROW_NUMBER() = 2` (którego użyłaś w zadaniu #9 z DataLemur, tylko tam było "trzecie")
-- zapisz w komentarzu, kiedy `NTH_VALUE` jest wygodniejsze, a kiedy `ROW_NUMBER` + `WHERE`.
-- ODP.: NTH_VALUE jest przydatne, gdy chcemy zidentyfikowac konkretna wartość, a ROW_NUMBER przydaje się,
-- gdy interesuje nas nie tyle konkrenta wartość, co na podstawie tej pozycji chcemy odfiltrowac dane i wykonac dalsze kroki.
-- ===================================================

with second_orders as (
select o.o_custkey, o.o_totalprice,
nth_value(o.o_totalprice, 2) over(partition by o.o_custkey order by o.o_orderdate, o.o_orderkey rows between unbounded preceding and unbounded following) as second_order_value,
row_number() over(partition by o.o_custkey order by o.o_orderdate, o.o_orderkey) as numbered_orders
from tpch.orders o
)
select * from second_orders 
where numbered_orders = 2
;

-- ==================================================
-- Dla każdej części (`part`) znajdź top 3 dostawców (`supplier`) wg najniższego kosztu dostawy (`partsupp.ps_supplycost`), 
-- używając `DENSE_RANK() OVER (PARTITION BY ps_partkey ORDER BY ps_supplycost ASC)`. 
-- To łączy 3 tabele (`part`, `partsupp`, `supplier`) i wymaga wyboru między `RANK`/`DENSE_RANK` przy remisach w cenie 
-- uzasadnij wybór w komentarzu, tak jak robiłaś to wcześniej.
-- ODP.: dense_rank(), bo jesli mamy remis na pozycji drugiej, to 3ci najtanszy bedzie mial nr 3 i wciągniemy go warunkiem where <= 3;
--		w przypadku rank() 3ci najtanszy mialby pozycje 4 i nie załapałby się. Pytanie jest o top 3, a nie 3 dostawcow.
-- ==================================================


with suppliers_ranked as (
select p.p_partkey, s.s_name, p2.ps_supplycost,
dense_rank() over(partition by p.p_partkey order by p2.ps_supplycost asc, p2.ps_suppkey) as suppliers_rank
from tpch.part p 
inner join tpch.partsupp p2  
	on p.p_partkey = p2.ps_partkey 
inner join tpch.supplier s 
	on p2.ps_suppkey = s.s_suppkey 
)
select * from suppliers_ranked 
where suppliers_rank <= 3 
;
























