-- ====================
-- CTE I SUBQUERIES
-- ====================

-- ====================
-- IBM is analyzing how their employees are utilizing the Db2 database 
-- by tracking the SQL queries executed by their employees. 
-- The objective is to generate data to populate a histogram that shows
-- the number of unique queries run by employees during the third quarter 
-- of 2023 (July to September). Additionally, it should count the number of employees 
-- who did not run any queries during this period.

-- Display the number of unique queries as histogram categories, 
-- along with the count of employees who executed that number of unique queries.
-- =====================

with employee_queries as (
SELECT e.employee_id, coalesce(count(distinct q.query_id), 0) as unique_queries
from employees e
left join queries q
  on e.employee_id = q.employee_id
  and q.query_starttime >= '2023-07-01T00:00:00Z'
  and q.query_starttime < '2023-10-01T00:00:00Z'
group by e.employee_id)
select unique_queries, count(distinct employee_id) from employee_queries
group by unique_queries
order by unique_queries asc;

-- =====================
-- UnitedHealth Group (UHG) has a program called Advocate4Me, 
-- which allows policy holders (or, members) to call an advocate and receive support 
-- for their health care needs – whether that's claims and benefits support, 
-- drug coverage, pre- and post-authorisation, medical records, emergency assistance, 
-- or member portal services.
--Write a query to find how many UHG policy holders made three, or more calls, 
-- assuming each call is identified by the case_id column.
-- =====================

with callers_activity as (
    SELECT policy_holder_id, count(case_id) counted_calls FROM callers
    group by policy_holder_id
    having count(case_id) >=3
)
select count(*) from callers_activity;

-- OR

select count(*)
from (SELECT policy_holder_id, count(case_id) counted_calls FROM callers
    group by policy_holder_id
    having count(case_id) >=3) as callers_counter;


-- ===========================
-- Imagine you're an HR analyst at a tech company tasked with analyzing employee salaries.
-- Your manager is keen on understanding the pay distribution and asks you to determine
-- the second highest salary among all employees.

-- It's possible that multiple employees may share the same second highest salary. 
-- In case of duplicate, display the salary only once
-- ===========================

select max(salary) as second_highest_salary
from employee
where salary < (
  select max(salary) from employee
)

-- OR

with salary_ranking as (
  SELECT distinct salary,
  dense_rank() over(order by salary desc) salary_rank
  FROM employee
  order by salary desc
)
select salary 
from salary_ranking
where salary_rank =2;


-- =====================
-- A Microsoft Azure Supercloud customer is defined as a customer who has purchased 
-- at least one product from every product category listed in the products table.

-- Write a query that identifies the customer IDs of these Supercloud customers.
-- =====================

SELECT c.customer_id FROM customer_contracts c
join products p 
on c.product_id = p.product_id
group by c.customer_id
having count(distinct p.product_category) = (
  select count(distinct product_category) from products p2
  );


-- =====================
-- Zomato is a leading online food delivery service that connects users
--  with various restaurants and cuisines, allowing them to browse menus,
-- place orders, and get meals delivered to their doorsteps.

-- Recently, Zomato encountered an issue with their delivery system.
-- Due to an error in the delivery driver instructions, each item's order 
-- was swapped with the item in the subsequent row. As a data analyst, 
-- you're asked to correct this swapping error and return the proper pairing 
-- of order ID and item.

-- If the last item has an odd order ID, it should remain 
-- as the last item in the corrected data. For example,
--  if the last item is Order ID 7 Tandoori Chicken,
--  then it should remain as Order ID 7 in the corrected data.
-- In the results, return the correct pairs of order IDs and items.

-- =====================

with order_counts as (
  SELECT count(order_id) as total_orders
  FROM orders
)
SELECT
  CASE
    when order_id % 2 != 0 AND order_id != total_orders THEN order_id + 1
    when order_id % 2 != 0 AND order_id = total_orders THEN order_id
    else order_id - 1
  END as corrected_order_id,
  item
from orders
cross join order_counts
order by corrected_order_id asc;


-- ======================
-- Your team at JPMorgan Chase is soon launching a new credit card.
--  You are asked to estimate how many cards you'll issue in the first month.
-- Before you can answer this question, you want to first get some perspective 
-- on how well new credit card launches typically do in their first month.
-- Write a query that outputs the name of the credit card, 
-- and how many cards were issued in its launch month. 
-- The launch month is the earliest record in the monthly_cards_issued table 
--for a given card. Order the results starting from the biggest issued amount.
-- ======================

with ordered as (
select 
  *,
  row_number() over(partition by card_name order by issue_year, issue_month) as issued_months_order
from monthly_cards_issued
)
select card_name, issued_amount
from ordered
where issued_months_order = 1
order by issued_amount desc;

-- =======================
-- UnitedHealth Group (UHG) has a program called Advocate4Me, 
-- which allows policy holders (or, members) to call an advocate 
-- and receive support for their health care needs – whether that's claims and benefits support,
--  drug coverage, pre- and post-authorisation, medical records, emergency assistance,
--  or member portal services.

-- Calls to the Advocate4Me call centre are classified into various categories, 
-- but some calls cannot be neatly categorised. 
-- These uncategorised calls are labeled as “n/a”, or are left empty when 
-- the support agent does not enter anything into the call category field.

-- Write a query to calculate the percentage of calls that cannot be categorised. 
-- Round your answer to 1 decimal place. For example, 45.0, 48.5, 57.7.
-- =======================

select 
  round(
    (
      (select count(*) from callers where call_category = 'n/a' or call_category IS NULL) / 
        (select count(*) from callers)::numeric
      ) *100, 1);






-- =======================
-- Assume you're given a table containing information about Wayfair user transactions 
-- for different products. Write a query to calculate the year-on-year growth rate
-- for the total spend of each product, grouping the results by product ID.

-- The output should include the year in ascending order, product ID, 
-- current year's spend, previous year's spend and year-on-year growth percentage,
-- rounded to 2 decimal places.
-- =======================

with yearly as (
  SELECT 
  extract(year from transaction_date) as year,
  product_id,
  SUM(spend) as curr_year_spend
  FROM user_transactions
  group by product_id, year
  order by product_id
),
 curr_and_prev_year_calc as (
SELECT *,
LAG(curr_year_spend) OVER(partition by product_id order by year) as prev_year_spend
from yearly
)
select *,
round(((curr_year_spend - prev_year_spend) / prev_year_spend) * 100, 2) as yoy_rate
from curr_and_prev_year_calc
order by product_id,year;









