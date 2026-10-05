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