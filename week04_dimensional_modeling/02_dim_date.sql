create table if not exists dw.dim_date (
	date_key integer primary key,
	full_date date not null unique,
	year smallint,
	quarter smallint,
	month smallint,
	month_name text,
	day_of_month smallint,
	day_of_week smallint,
	day_name text,
	iso_week smallint,
	is_weekend boolean
);

truncate table dw.dim_date;

insert into dw.dim_date(
	date_key,
	full_date,
	year,
	quarter,
	month,
	month_name,
	day_of_month,
	day_of_week,
	day_name,
	iso_week,
	is_weekend
)
select 
	to_char(d, 'YYYYMMDD')::integer as date_key,
	d::date as full_date,
	extract(year from d)::smallint as year,
	extract(quarter from d)::smallint as quarter,
	extract(month from d)::smallint as month,
	trim(to_char(d, 'Month')) as month_name,
	extract(day from d)::smallint as day_of_month,
	extract(isodow from d)::smallint as day_of_week,
	trim(to_char(d, 'Day')) as day_name,
	extract(week from d)::smallint as iso_week,
	extract(isodow from d) in (6, 7) as is_weekend
from generate_series (
	'2026-01-01'::date,
	'2026-12-31'::date,
	'1 day'::interval
) as d
ON CONFLICT (date_key) DO UPDATE;
insert into dw.dim_date (
	date_key,
	full_date,
	year,
	quarter,
	month,
	month_name,
	day_of_month,
	day_of_week,
	day_name,
	iso_week,
	is_weekend)
values(-1, '1900-01-01', null, null, null, null, null, null, null, null, null)
ON CONFLICT (date_key) 
DO UPDATE SET
	full_date = EXCLUDED.full_date,
	year = EXCLUDED.year,
	quarter = EXCLUDED.quarter,
	month = EXCLUDED.month,
	month_name = EXCLUDED.month_name,
	day_of_month = EXCLUDED.day_of_month,
	day_of_week = EXCLUDED.day_of_week,
	day_name = EXCLUDED.day_name,
	iso_week = EXCLUDED.iso_week,
	is_weekend = EXCLUDED.is_weekend
;
