-- === CTE rekursywne === --

WITH RECURSIVE tens (n) AS (
    SELECT 10
  UNION ALL
    SELECT n+10 FROM tens WHERE n+10<= 100
)
SELECT n FROM tens;

-- ==========================
-- Klasyczny wariant edukacyjny — stwórz sobie prostą tabelę employees(id, name, manager_id) z 10-15 rekordami 
-- (ręcznie, INSERT-ami) i napisz rekurencyjne CTE zwracające pełną hierarchię 
-- z poziomem zagnieżdżenia (level) i pełną ścieżką (path) od góry do danego pracownika.
-- ==========================
drop table employees;

create table employees (
id int GENERATED ALWAYS AS identity primary key,
name varchar,
manager_id int);

insert into employees(name, manager_id)
	values 
	('Ola', null),
	('Mieszko', 1),
	('Agata', 2),
	('Kacper', 1),
	('Buffy', 2),
	('Koza', 2), 
	('Agi', 2), 
	('Gulczas', 3), 
	('Indyk', 4), 
	('Doris', 3);

select * from employees e;

with recursive hierarchy as (
	select id, name, manager_id, 1 as level, array[name] as path
		from employees
	where manager_id is null
	
	union all
	
	select e.id, e.name, e.manager_id, level+1, path || e.name
	from employees e inner join
 		hierarchy h on e.manager_id = h.id
)
select * from hierarchy
order by level;


-- ==========================
-- Wariant z wykrywaniem cykli — dodaj do tej tabeli sztuczny cykl (A→B→C→A) i napisz CTE,
-- które go wykryje i nie wpadnie w nieskończoną pętlę (WHERE NOT id = ANY(path)).

-- ==========================

drop table employees2;

create table employees2 (
id int GENERATED ALWAYS AS identity primary key,
name varchar,
manager_id int);

insert into employees2(name, manager_id)
	values 
	('Ola', null),
	('Mieszko', 1),
	('Agata', 2),
	('Kacper', 3),
	('Buffy', 2),
	('Koza', 1), 
	('Agi', 2), 
	('Gulczas', 3), 
	('Indyk', 4), 
	('Doris', 3);

with recursive cycle_hierarchy as (
	select id, name, manager_id, 1 as level, array[id] as path
		from employees2
	where manager_id is null
	
	union all
	
	select e.id, e.name, e.manager_id, level+1, h.path || e.id
	from employees2 e inner join
 		cycle_hierarchy h on e.manager_id = h.id
 	where not(e.id = any(h.path))
)
select * from cycle_hierarchy
order by level;



-- ==========================
-- Wariant na TPC-H (bardziej naciągany, ale ćwiczy składnię) 
-- wygeneruj rekurencyjnie sekwencję dat
-- (dim_date bez tabeli kalendarza) od najwcześniejszej 
-- do najpóźniejszej daty zamówienia w orders, dzień po dniu. 
-- To częsty real-world use case rekurencji 
-- generowanie serii dat.
-- ==========================

select distinct(o_orderdate) from tpch.orders order by o_orderdate limit 7;

with recursive dates as (
	select MIN(o_orderdate::date) as calendar_date
	from tpch.orders o
	
	union all
	
	select calendar_date + 1
	from dates
	where calendar_date + 1 <= (select MAX(o_orderdate::date) from tpch.orders)

)
select calendar_date from dates;


-- ==========================
-- Wygeneruj rekurencyjnie serię godzin (nie dni) pokrywającą pierwsze 7 dni 
-- od najwcześniejszej daty zamówienia w orders (czyli 168 wierszy: 7 dni × 24h).
-- ==========================

with recursive
    date_bounds as (
        select min(o_orderdate)::date as start_date
        from tpch.orders
    ),
    hours as (
        select start_date::timestamp as order_hour
        from date_bounds

        union all

        select order_hour + interval '1 hour'
        from hours
        where order_hour + interval '1 hour' <= (select start_date from date_bounds) + interval '7 days' - interval '1 hour'
    )
select * from hours
order by order_hour;


-- =============================
















