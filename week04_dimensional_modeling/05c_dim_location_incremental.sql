BEGIN;

SET local scd.effective_date TO '2026-02-01';

-- KROK 1: Zamknięcie aktualnych wersji, w których zmienił się któryś z atrybutów
UPDATE dw.dim_location_scd2 target
SET 
    valid_to = current_setting('scd.effective_date')::date,
    is_current = false
FROM staging.taxi_zones_v2 src
WHERE target.location_id = src.location_id
  AND target.is_current = true
  -- Sprawdzamy czy którykolwiek z 3 atrybutów się zmienił 
  -- (IS DISTINCT FROM obsługuje też potencjalne wartości NULL)
  AND (
         target.borough IS DISTINCT FROM src.borough
      OR target.zone IS DISTINCT FROM src.zone
      OR target.service_zone IS DISTINCT FROM src.service_zone
  );

-- KROK 2: Wstawienie całkowicie nowych location_id
INSERT INTO dw.dim_location_scd2 (
    location_id,
    borough,
    zone,
    service_zone,
    valid_from,
    valid_to,
    is_current
)
SELECT 
    src.location_id,
    src.borough,
    src.zone,
    src.service_zone,
    current_setting('scd.effective_date')::date AS valid_from,
    '9999-12-31'::date AS valid_to,
    true AS is_current
FROM staging.taxi_zones_v2 src
LEFT JOIN dw.dim_location_scd2 target 
    ON src.location_id = target.location_id 
   AND target.is_current = true
where
    -- Wstawiamy nową wersję ze zaktualizowanymi informacjami
    target.location_id IS null;
COMMIT;