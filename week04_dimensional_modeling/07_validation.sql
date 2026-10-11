select count(*) from dw.dim_location_scd2 dls; -- 270

select count(*) from dw.dim_location_scd2 dls 
	where dls.is_current = true; --267

select count(*) from dw.dim_location_scd2 dls
	where dls.is_current = false; --3

select dls.location_id from dw.dim_location_scd2 dls 
	group by dls.location_id 
	having count(dls.location_id) > 1; --4, 12, 13

select * from dw.dim_location_scd2 dls 
	where dls.location_id in (select dls2.location_id from dw.dim_location_scd2 dls2 
								group by dls2.location_id 
								having count(dls2.location_id) > 1)
	order by dls.location_id, dls.valid_from; --4, 12, 13: stara Yellow Zone 1900-01-01 → 2026-02-01, nowa Boro Zone 2026-02-01 → 9999-12-31

select * from dw.dim_location_scd2 dls 
	where dls.location_id = 900; --NIE ZMIENIONE

select * from dw.dim_location_scd2 dls 
	where dls.location_id = -1; --NIE ZMIENIONE

select max(location_key) from dw.dim_location_scd2; -- 269

select count(*)
from
	staging.yellow_trips yt 
where not (
	date(yt.tpep_pickup_datetime) >= (select min(full_date) from dw.dim_date where date_key <> -1)
	and date(yt.tpep_pickup_datetime) <= (select MAX(full_date) from dw.dim_date)
	and yt.tpep_dropoff_datetime > yt.tpep_pickup_datetime
	and yt.trip_distance > 0 AND yt.trip_distance <= 100
	and yt.fare_amount >= 0); -- oczekiwane: staging - fact = 737 247 

select * from dw.fact_trips ft 
where ft.pickup_date_key = -1;  -- brak wyników