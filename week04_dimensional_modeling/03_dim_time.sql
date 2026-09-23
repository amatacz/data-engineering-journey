create table if not exists dw.dim_time (
    time_key smallint primary key,
    hour smallint,
    minute smallint,
    time_of_day text,
    is_rush_hour boolean
);

insert into dw.dim_time (
    time_key,
    hour,
    minute,
    time_of_day,
    is_rush_hour
)
select
    minute_of_day/60 *100 + minute_of_day%60 as time_key,
    minute_of_day/60 as hour,
    minute_of_day%60 as minute,
    case
        when minute_of_day/60 >= 0 and minute_of_day/60 <= 5 then 'night'
        when minute_of_day/60 >= 6 and minute_of_day/60 <= 11 then 'morning'
        when minute_of_day/60 >= 12 and minute_of_day/60 <= 17 then 'afternoon'
        else 'evening'
    end as time_of_day,
    minute_of_day/60 between 7 and 9 or minute_of_day/60 between 16 and 19 as is_rush_hour
from generate_series (
    0,
    1439
) as t(minute_of_day)
ON CONFLICT (time_key) 
DO update set
 	hour = EXCLUDED.hour,
	minute = EXCLUDED.minute,
	time_of_day = EXCLUDED.time_of_day,
	is_rush_hour = EXCLUDED.is_rush_hour
;
