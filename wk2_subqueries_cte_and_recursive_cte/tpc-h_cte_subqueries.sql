-- ===================
-- Znajdź klientów (customer), których łączna wartość zamówień (orders.o_totalprice) 
-- jest wyższa niż średnia wartość zamówień wszystkich klientów z ich kraju (nation).
-- ===================

-- CTE ---
with total_cust_value as (
select c.c_custkey, c.c_nationkey, round(sum(o.o_totalprice), 2) as total_cust_order
	from orders o 
	join customer c 
		on o.o_custkey = c.c_custkey
	group by c.c_custkey, c.c_nationkey 
),
avg_nation_value as (
	select tv.c_nationkey, round(avg(tv.total_cust_order), 2) as avg_nation_order
	from total_cust_value tv
	group by c_nationkey 
)
select tv.c_custkey, tv.c_nationkey, tv.total_cust_order, av.avg_nation_order 
from total_cust_value tv
join avg_nation_value av
	on tv.c_nationkey = av.c_nationkey 
where tv.total_cust_order > av.avg_nation_order
order by tv.c_custkey asc;

--- SQUBQUERY ---
select c.c_custkey, c.c_nationkey, round(sum(o.o_totalprice), 2) as total_cust_order
	from orders o 
	join customer c 
		on o.o_custkey = c.c_custkey
	group by c.c_custkey, c.c_nationkey
	having round(sum(o.o_totalprice)) > 
		(select avg(customer_sum.total_price)
		from (select 
					c2.c_custkey, 
					c2.c_nationkey, 
					SUM(o2.o_totalprice) as total_price
				from customer c2
				join orders o2
					on c2.c_custkey = o2.o_custkey
				group by c2.c_custkey, c2.c_nationkey	
			) as customer_sum
		where customer_sum.c_nationkey = c.c_nationkey);


-- ===================
-- Znajdź części (part), które są dostarczane (partsupp) przez 
-- więcej niż 3 dostawców (supplier) z tego samego regionu (region).
-- ===================

select p.p_partkey,p.p_name, r.r_regionkey, r.r_name, count(distinct s.s_suppkey ) as suppliers_regions
from part p join partsupp p2 
	on p.p_partkey = p2.ps_partkey 
join supplier s 
	on p2.ps_suppkey = s.s_suppkey 
join nation n 
	on s.s_nationkey = n.n_nationkey
join region r 
	on n.n_regionkey = r.r_regionkey
group by p.p_partkey,p.p_name, r.r_regionkey, r.r_name
having count(distinct s.s_suppkey) > 3
;

-- ===================
-- Znajdź 5 najczęściej zamawianych części w segmencie 
-- klientów BUILDING (customer.c_mktsegment), 
-- z rozbiciem na rok złożenia zamówienia.
-- ===================

--- CTE ---
with building_orders as (
	select p.p_partkey,
		p.p_name, 
		c.c_mktsegment,
		extract(year from o.o_orderdate) as order_year,
		sum(l.l_quantity) as total_quantity 
	from customer c join orders o 
		on c.c_custkey = o.o_custkey 
	join lineitem l 
		on o.o_orderkey = l.l_orderkey
	join part p 
		on l.l_partkey = p.p_partkey 
	where c.c_mktsegment = 'BUILDING'
	group by p.p_partkey,
		p.p_name, 
		c.c_mktsegment,
		order_year
),
sum_ranked as (
select *,
dense_rank() over(partition by order_year order by total_quantity desc) as ranked
from building_orders
)
select * from sum_ranked 
where ranked <= 5
order by order_year desc, ranked desc;

--- SUBQUERY ---

select
    p.p_partkey,
    p.p_name,
    extract(year from o.o_orderdate) as order_year,
    sum(l.l_quantity) as total_quantity
from customer c join orders o on c.c_custkey = o.o_custkey
join lineitem l on o.o_orderkey = l.l_orderkey
join part p on l.l_partkey = p.p_partkey
where c.c_mktsegment = 'BUILDING'
group by p.p_partkey, p.p_name, extract(year from o.o_orderdate)
having sum(l.l_quantity) >= (
    select min(top5.qty) from (
        select sum(l3.l_quantity) as qty
        from customer c3 join orders o3 on c3.c_custkey = o3.o_custkey
        join lineitem l3 on o3.o_orderkey = l3.l_orderkey
        join part p3 on l3.l_partkey = p3.p_partkey
        where c3.c_mktsegment = 'BUILDING'
          and extract(year from o3.o_orderdate) = extract(year from o.o_orderdate)
        group by p3.p_partkey
        order by qty desc
        limit 5
    ) top5
);