-- BSL backend schema snapshot
-- Project: jkzjktrnqtkpdiiugfar
-- Captured: 2026-08-21 UTC
-- Data is stored in the adjacent data/*.json files.

BEGIN;
SET search_path = public, extensions;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE TABLE public.bsl_banks (
  bank_id text NOT NULL,
  legal_name text NOT NULL,
  brand_name text NOT NULL,
  jurisdiction text NOT NULL,
  hq_address text,
  hq_city text,
  phone text,
  website text,
  ceo text,
  cbbh_source_url text,
  cbbh_verified_at date,
  active boolean DEFAULT true NOT NULL,
  atm_source_url text,
  atm_source_type text,
  parser_status text,
  notes text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT bsl_banks_pkey PRIMARY KEY (bank_id)
);

CREATE TABLE public.bsl_atm_locations (
  location_id text NOT NULL,
  bank_id text NOT NULL,
  name text,
  address text NOT NULL,
  city text NOT NULL,
  postal_code text,
  municipality text,
  entity text,
  canton text,
  latitude double precision,
  longitude double precision,
  geo_source text,
  geo_confidence real DEFAULT 0 NOT NULL,
  geocode_status text DEFAULT 'pending'::text NOT NULL,
  source_url text,
  source_date date,
  last_verified_at date,
  record_status text DEFAULT 'active'::text NOT NULL,
  data_confidence text,
  geom geography(Point,4326),
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT bsl_atm_lat_chk CHECK (latitude IS NULL OR latitude >= '-90'::integer::double precision AND latitude <= 90::double precision),
  CONSTRAINT bsl_atm_locations_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES bsl_banks(bank_id),
  CONSTRAINT bsl_atm_locations_pkey PRIMARY KEY (location_id),
  CONSTRAINT bsl_atm_lon_chk CHECK (longitude IS NULL OR longitude >= '-180'::integer::double precision AND longitude <= 180::double precision)
);

CREATE TABLE public.bsl_atm_devices (
  device_id text NOT NULL,
  location_id text NOT NULL,
  source_name text,
  device_type text,
  withdrawal boolean,
  cash_deposit boolean,
  bill_payment boolean,
  contactless boolean,
  currency text DEFAULT 'BAM'::text,
  is_24h boolean,
  opening_hours text,
  accessible boolean,
  network text,
  source_url text,
  source_date date,
  last_verified_at date,
  record_status text DEFAULT 'active'::text NOT NULL,
  data_confidence text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT bsl_atm_devices_location_id_fkey FOREIGN KEY (location_id) REFERENCES bsl_atm_locations(location_id) ON DELETE CASCADE,
  CONSTRAINT bsl_atm_devices_pkey PRIMARY KEY (device_id)
);

CREATE TABLE public.bsl_atm_sources (
  source_id text NOT NULL,
  bank_id text,
  source_url text NOT NULL,
  source_type text NOT NULL,
  priority integer DEFAULT 1 NOT NULL,
  license_notes text,
  last_checked_at date,
  active boolean DEFAULT true NOT NULL,
  parser_status text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT bsl_atm_sources_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES bsl_banks(bank_id),
  CONSTRAINT bsl_atm_sources_pkey PRIMARY KEY (source_id)
);

CREATE TABLE public.bsl_osm_atm_candidates (
  osm_type text NOT NULL,
  osm_id bigint NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  name text,
  operator text,
  brand text,
  network text,
  addr_city text,
  addr_place text,
  addr_street text,
  addr_housenumber text,
  bank_key text,
  tags jsonb DEFAULT '{}'::jsonb NOT NULL,
  imported_at timestamp with time zone DEFAULT now() NOT NULL,
  matched_location_id text,
  match_confidence real,
  geom geography(Point,4326) GENERATED ALWAYS AS ((st_setsrid(st_makepoint(longitude, latitude), 4326))::geography) STORED,
  atm_confirmed boolean DEFAULT true NOT NULL,
  CONSTRAINT bsl_osm_atm_candidates_matched_location_id_fkey FOREIGN KEY (matched_location_id) REFERENCES bsl_atm_locations(location_id) ON DELETE SET NULL,
  CONSTRAINT bsl_osm_atm_candidates_pkey PRIMARY KEY (osm_type, osm_id)
);

CREATE INDEX idx_bsl_atm_locations_geom ON public.bsl_atm_locations USING gist (geom);

CREATE INDEX idx_bsl_atm_locations_bank ON public.bsl_atm_locations USING btree (bank_id);

CREATE INDEX idx_bsl_atm_locations_city ON public.bsl_atm_locations USING btree (lower(city));

CREATE INDEX idx_bsl_atm_locations_status ON public.bsl_atm_locations USING btree (record_status);

CREATE INDEX idx_bsl_atm_devices_location ON public.bsl_atm_devices USING btree (location_id);

CREATE INDEX idx_bsl_osm_atm_geom ON public.bsl_osm_atm_candidates USING gist (geom);

CREATE INDEX idx_bsl_osm_atm_bank ON public.bsl_osm_atm_candidates USING btree (bank_key);

CREATE INDEX idx_bsl_osm_atm_city ON public.bsl_osm_atm_candidates USING btree (lower(COALESCE(addr_city, addr_place, ''::text)));

CREATE INDEX idx_bsl_osm_atm_match ON public.bsl_osm_atm_candidates USING btree (matched_location_id);

CREATE OR REPLACE FUNCTION public.bsl_match_osm_atms()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_count integer := 0;
begin
  update public.bsl_atm_locations
  set latitude=null,
      longitude=null,
      geo_source=null,
      geo_confidence=0,
      geocode_status='pending'
  where geocode_status='matched_osm';

  update public.bsl_osm_atm_candidates
  set matched_location_id=null,
      match_confidence=null
  where matched_location_id is not null or match_confidence is not null;

  with possible_base as (
    select
      c.osm_type,
      c.osm_id,
      c.latitude,
      c.longitude,
      l.location_id,
      extensions.similarity(
        public.bsl_norm_text(concat_ws(' ',c.addr_street,c.addr_housenumber)),
        public.bsl_norm_text(l.address)
      ) as addr_similarity
    from public.bsl_osm_atm_candidates c
    join public.bsl_banks b on b.active and (
      b.bank_id = c.bank_key
      or (c.bank_key='addiko' and b.bank_id like 'addiko_%')
      or (c.bank_key='nlb' and b.bank_id like 'nlb_%')
      or (c.bank_key='unicredit' and b.bank_id like 'unicredit_%')
    )
    join public.bsl_atm_locations l on l.bank_id=b.bank_id
      and public.bsl_norm_text(l.city)=public.bsl_norm_text(coalesce(c.addr_city,c.addr_place,''))
    where c.bank_key is not null
      and public.bsl_norm_text(concat_ws(' ',c.addr_street,c.addr_housenumber)) <> ''
      and l.record_status in ('active','source_stale')
      and l.geocode_status not in ('manual_verified','official_coordinates')
  ), ranked as (
    select
      p.*,
      0.55 + 0.45*p.addr_similarity as score,
      row_number() over (
        partition by p.location_id
        order by p.addr_similarity desc, p.osm_type, p.osm_id
      ) as rank_for_location,
      row_number() over (
        partition by p.osm_type,p.osm_id
        order by p.addr_similarity desc, p.location_id
      ) as rank_for_candidate
    from possible_base p
  ), winners as (
    select * from ranked
    where rank_for_location=1 and rank_for_candidate=1 and score >= 0.78
  ), upd_locations as (
    update public.bsl_atm_locations l
    set latitude=w.latitude,
        longitude=w.longitude,
        geo_source='OpenStreetMap/Overpass',
        geo_confidence=w.score,
        geocode_status='matched_osm',
        last_verified_at=current_date
    from winners w
    where l.location_id=w.location_id
    returning l.location_id
  ), upd_candidates as (
    update public.bsl_osm_atm_candidates c
    set matched_location_id=w.location_id,
        match_confidence=w.score
    from winners w
    where c.osm_type=w.osm_type and c.osm_id=w.osm_id
    returning c.osm_type,c.osm_id
  )
  select count(*) into v_count from upd_candidates;
  return v_count;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.bsl_nearby_atms_map(p_lat double precision, p_lon double precision, p_radius_m integer DEFAULT 10000)
 RETURNS TABLE(location_id text, bank_id text, bank_brand text, name text, address text, city text, latitude double precision, longitude double precision, distance_m double precision, cash_deposit boolean, is_24h boolean, source text, verified boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with target as (
    select ST_SetSRID(ST_MakePoint(p_lon,p_lat),4326)::geography as g
  ), official as (
    select
      l.location_id,
      l.bank_id,
      b.brand_name as bank_brand,
      coalesce(nullif(l.name,''), b.brand_name || ' bankomat') as name,
      l.address,
      l.city,
      l.latitude,
      l.longitude,
      ST_Distance(l.geom,t.g) as distance_m,
      coalesce(bool_or(d.cash_deposit),false) as cash_deposit,
      coalesce(bool_or(d.is_24h),false) as is_24h,
      coalesce(l.geo_source,'BSL official') as source,
      (l.geocode_status in ('manual_verified','official_coordinates','matched_osm')) as verified
    from public.bsl_atm_locations l
    join public.bsl_banks b on b.bank_id=l.bank_id and b.active
    cross join target t
    left join public.bsl_atm_devices d on d.location_id=l.location_id and d.record_status='active'
    where l.geom is not null
      and l.record_status='active'
      and ST_DWithin(l.geom,t.g,greatest(1,p_radius_m))
    group by l.location_id,l.bank_id,b.brand_name,l.name,l.address,l.city,l.latitude,l.longitude,l.geom,t.g,l.geo_source,l.geocode_status
  ), osm_candidates as (
    select
      c.*,
      ST_Distance(c.geom,t.g) as distance_m
    from public.bsl_osm_atm_candidates c
    cross join target t
    where c.matched_location_id is null
      and c.atm_confirmed=true
      and ST_DWithin(c.geom,t.g,greatest(1,p_radius_m))
      and not exists (
        select 1
        from official o
        where c.bank_key is not null
          and o.bank_id = c.bank_key
          and ST_DWithin(
            c.geom,
            ST_SetSRID(ST_MakePoint(o.longitude,o.latitude),4326)::geography,
            80
          )
      )
      and not exists (
        select 1
        from public.bsl_osm_atm_candidates c2
        where c.bank_key is not null
          and c2.matched_location_id is null
          and c2.atm_confirmed=true
          and c2.bank_key = c.bank_key
          and (c2.osm_type,c2.osm_id) < (c.osm_type,c.osm_id)
          and ST_DWithin(c.geom,c2.geom,50)
      )
  ), osm_unmatched as (
    select
      'osm:' || c.osm_type || ':' || c.osm_id::text as location_id,
      coalesce(c.bank_key,'osm_other') as bank_id,
      public.bsl_osm_bank_brand(c.bank_key) as bank_brand,
      coalesce(nullif(c.name,''), public.bsl_osm_bank_brand(c.bank_key) || ' bankomat') as name,
      trim(concat_ws(' ',nullif(c.addr_street,''),nullif(c.addr_housenumber,''),nullif(c.addr_place,''))) as address,
      coalesce(nullif(c.addr_city,''),nullif(c.addr_place,''),'') as city,
      c.latitude,
      c.longitude,
      c.distance_m,
      lower(coalesce(c.tags->>'cash_in',c.tags->>'cash_deposit',c.tags->>'deposit','')) in ('yes','true','1') as cash_deposit,
      replace(lower(coalesce(c.tags->>'opening_hours','')),' ','') in ('24/7','24-7') as is_24h,
      'OpenStreetMap'::text as source,
      false as verified
    from osm_candidates c
  )
  select * from official
  union all
  select * from osm_unmatched
  order by distance_m;
$function$
;

CREATE OR REPLACE FUNCTION public.bsl_nearby_atms(p_lat double precision, p_lon double precision, p_radius_m integer DEFAULT 10000, p_bank_id text DEFAULT NULL::text, p_cash_deposit boolean DEFAULT NULL::boolean, p_only_24h boolean DEFAULT NULL::boolean)
 RETURNS TABLE(location_id text, bank_id text, bank_brand text, name text, address text, city text, latitude double precision, longitude double precision, distance_m double precision, cash_deposit boolean, is_24h boolean, geo_source text, geo_confidence real, data_confidence text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    l.location_id,
    l.bank_id,
    b.brand_name,
    l.name,
    l.address,
    l.city,
    l.latitude,
    l.longitude,
    ST_Distance(l.geom, ST_SetSRID(ST_MakePoint(p_lon,p_lat),4326)::geography) as distance_m,
    bool_or(coalesce(d.cash_deposit,false)) as cash_deposit,
    bool_or(coalesce(d.is_24h,false)) as is_24h,
    l.geo_source,
    l.geo_confidence,
    l.data_confidence
  from public.bsl_atm_locations l
  join public.bsl_banks b on b.bank_id=l.bank_id and b.active=true
  left join public.bsl_atm_devices d on d.location_id=l.location_id and d.record_status='active'
  where l.geom is not null
    and l.record_status='active'
    and (p_bank_id is null or l.bank_id=p_bank_id)
    and ST_DWithin(l.geom, ST_SetSRID(ST_MakePoint(p_lon,p_lat),4326)::geography, greatest(1,p_radius_m))
    and (p_cash_deposit is null or coalesce(d.cash_deposit,false)=p_cash_deposit)
    and (p_only_24h is null or coalesce(d.is_24h,false)=p_only_24h)
  group by l.location_id,l.bank_id,b.brand_name,l.name,l.address,l.city,l.latitude,l.longitude,l.geom,l.geo_source,l.geo_confidence,l.data_confidence
  order by distance_m;
$function$
;

CREATE OR REPLACE FUNCTION public.bsl_norm_text(p_value text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'extensions'
AS $function$
  select trim(regexp_replace(lower(extensions.unaccent(coalesce(p_value,''))), '[^a-z0-9]+', ' ', 'g'));
$function$
;

CREATE OR REPLACE FUNCTION public.bsl_osm_bank_brand(p_key text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case p_key
    when 'addiko' then 'Addiko Bank'
    when 'asa_banka' then 'ASA Banka'
    when 'bbi' then 'BBI Banka'
    when 'intesa' then 'Intesa Sanpaolo Banka'
    when 'kib' then 'KIB Banka'
    when 'nlb' then 'NLB Banka'
    when 'pbs' then 'Privredna banka Sarajevo'
    when 'procredit' then 'ProCredit Bank'
    when 'raiffeisen' then 'Raiffeisen Bank'
    when 'sparkasse' then 'Sparkasse Bank'
    when 'unicredit' then 'UniCredit Bank'
    when 'union' then 'Union Banka'
    when 'ziraat' then 'ZiraatBank BH'
    when 'atos' then 'ATOS BANK'
    when 'bpsbl' then 'Banka Poštanska štedionica'
    when 'mf' then 'MF banka'
    when 'nova' then 'Nova banka'
    when 'nasa' then 'Naša banka'
    else 'Ostali bankomati'
  end;
$function$
;

CREATE OR REPLACE FUNCTION public.bsl_refresh_atm_geom()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if new.latitude is not null and new.longitude is not null then
    new.geom := ST_SetSRID(ST_MakePoint(new.longitude,new.latitude),4326)::geography;
  else
    new.geom := null;
  end if;
  new.updated_at := now();
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.bsl_touch_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$
;

CREATE TRIGGER trg_bsl_banks_touch BEFORE UPDATE ON bsl_banks FOR EACH ROW EXECUTE FUNCTION bsl_touch_updated_at();

CREATE TRIGGER trg_bsl_atm_geom BEFORE INSERT OR UPDATE OF latitude, longitude ON bsl_atm_locations FOR EACH ROW EXECUTE FUNCTION bsl_refresh_atm_geom();

CREATE TRIGGER trg_bsl_devices_touch BEFORE UPDATE ON bsl_atm_devices FOR EACH ROW EXECUTE FUNCTION bsl_touch_updated_at();

CREATE TRIGGER trg_bsl_sources_touch BEFORE UPDATE ON bsl_atm_sources FOR EACH ROW EXECUTE FUNCTION bsl_touch_updated_at();

ALTER TABLE public.bsl_banks ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bsl_atm_locations ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bsl_atm_devices ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bsl_atm_sources ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.bsl_osm_atm_candidates ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.bsl_banks FROM anon, authenticated;
GRANT ALL ON TABLE public.bsl_banks TO service_role;

REVOKE ALL ON TABLE public.bsl_atm_locations FROM anon, authenticated;
GRANT ALL ON TABLE public.bsl_atm_locations TO service_role;

REVOKE ALL ON TABLE public.bsl_atm_devices FROM anon, authenticated;
GRANT ALL ON TABLE public.bsl_atm_devices TO service_role;

REVOKE ALL ON TABLE public.bsl_atm_sources FROM anon, authenticated;
GRANT ALL ON TABLE public.bsl_atm_sources TO service_role;

REVOKE ALL ON TABLE public.bsl_osm_atm_candidates FROM anon, authenticated;
GRANT ALL ON TABLE public.bsl_osm_atm_candidates TO service_role;

REVOKE ALL ON FUNCTION public.bsl_match_osm_atms() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bsl_match_osm_atms() TO postgres;
GRANT EXECUTE ON FUNCTION public.bsl_match_osm_atms() TO service_role;

REVOKE ALL ON FUNCTION public.bsl_nearby_atms_map(double precision,double precision,integer) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bsl_nearby_atms_map(double precision,double precision,integer) TO postgres;
GRANT EXECUTE ON FUNCTION public.bsl_nearby_atms_map(double precision,double precision,integer) TO anon;
GRANT EXECUTE ON FUNCTION public.bsl_nearby_atms_map(double precision,double precision,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bsl_nearby_atms_map(double precision,double precision,integer) TO service_role;

REVOKE ALL ON FUNCTION public.bsl_nearby_atms(double precision,double precision,integer,text,boolean,boolean) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bsl_nearby_atms(double precision,double precision,integer,text,boolean,boolean) TO postgres;
GRANT EXECUTE ON FUNCTION public.bsl_nearby_atms(double precision,double precision,integer,text,boolean,boolean) TO service_role;

REVOKE ALL ON FUNCTION public.bsl_norm_text(text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bsl_norm_text(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.bsl_norm_text(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.bsl_norm_text(text) TO anon;
GRANT EXECUTE ON FUNCTION public.bsl_norm_text(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bsl_norm_text(text) TO service_role;

REVOKE ALL ON FUNCTION public.bsl_osm_bank_brand(text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bsl_osm_bank_brand(text) TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.bsl_osm_bank_brand(text) TO postgres;
GRANT EXECUTE ON FUNCTION public.bsl_osm_bank_brand(text) TO anon;
GRANT EXECUTE ON FUNCTION public.bsl_osm_bank_brand(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bsl_osm_bank_brand(text) TO service_role;

REVOKE ALL ON FUNCTION public.bsl_refresh_atm_geom() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bsl_refresh_atm_geom() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.bsl_refresh_atm_geom() TO postgres;
GRANT EXECUTE ON FUNCTION public.bsl_refresh_atm_geom() TO anon;
GRANT EXECUTE ON FUNCTION public.bsl_refresh_atm_geom() TO authenticated;
GRANT EXECUTE ON FUNCTION public.bsl_refresh_atm_geom() TO service_role;

REVOKE ALL ON FUNCTION public.bsl_touch_updated_at() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bsl_touch_updated_at() TO PUBLIC;
GRANT EXECUTE ON FUNCTION public.bsl_touch_updated_at() TO postgres;
GRANT EXECUTE ON FUNCTION public.bsl_touch_updated_at() TO anon;
GRANT EXECUTE ON FUNCTION public.bsl_touch_updated_at() TO authenticated;
GRANT EXECUTE ON FUNCTION public.bsl_touch_updated_at() TO service_role;


COMMIT;
