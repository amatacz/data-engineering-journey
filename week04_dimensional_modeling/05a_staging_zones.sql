-- create table on staging
create table if not exists staging.taxi_zones_v1 (
	location_id smallint,
	borough text,
	zone text,
	service_zone text
);


truncate staging.taxi_zones_v1;

-- ran in terminal
\copy staging.taxi_zones_v1 from '/Users/aleksandramatacz/Desktop/taxi_zone_lookup.csv' with (format csv, header true);


-- make a copy of taxi_zones_v1
create table staging.taxi_zones_v2 as table staging.taxi_zones_v1;

select * from staging.taxi_zones_v2;

-- test changes
update staging.taxi_zones_v2
set service_zone = 'Boro Zone'
where location_id in (select location_id 
					from staging.taxi_zones_v1 
					where service_zone = 'Yellow Zone' 
					order by location_id 
					limit 3);

insert into staging.taxi_zones_v2 (location_id, borough, zone, service_zone)
values (900, 'Manhattan', 'Test Zone', 'Yellow Zone');
