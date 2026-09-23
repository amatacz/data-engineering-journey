-- CREATE REQUIRED SCHEMAS
create schema if not exists staging;

create schema if not exists dw;

-- CHANGE RAW DATA TABLE SCHEMA TO STAGING, ONE TIME ACTION
alter table public.yellow_trips 
	set schema staging;