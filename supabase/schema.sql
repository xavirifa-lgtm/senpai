-- Esquema del juego de reto diario.
-- Ejecutar entero en Supabase → SQL Editor → New query → Run.
-- Requisito previo: Authentication → Sign In / Providers → activar "Allow anonymous sign-ins".

-- ---------- tablas ----------
create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique check (char_length(join_code) between 4 and 20),
  created_at timestamptz not null default now()
);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  group_id uuid not null references public.groups(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 20),
  avatar text not null check (avatar in ('nino7','nina7','nino12','nina12','chico15','chica15','hombre46','mujer47')),
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  unique (group_id, avatar)
);

create table if not exists public.results (
  id bigint generated always as identity primary key,
  client_id uuid not null unique,              -- generado en el móvil: reintentos sin duplicar
  player_id uuid not null references public.players(id) on delete cascade,
  game text not null check (char_length(game) between 2 and 20),
  date date not null,                           -- día del reto según el móvil (Europe/Madrid)
  score numeric not null,
  official boolean not null default false,
  client_ts timestamptz,                        -- hora del móvil al terminar
  suspicious boolean not null default false,    -- marcado por el servidor, no por el cliente
  created_at timestamptz not null default now()
);

-- un solo intento oficial por jugador y día
create unique index if not exists results_one_official_per_day
  on public.results (player_id, date) where official;
create index if not exists results_date_idx on public.results (date);

-- ---------- validación en servidor ----------
create or replace function public.check_result() returns trigger
language plpgsql as $$
declare today date := (now() at time zone 'Europe/Madrid')::date;
begin
  new.suspicious := false;
  if new.date > today then
    raise exception 'Fecha futura: % (hoy es %)', new.date, today;
  end if;
  -- plazo de 48 h para subir el reto oficial jugado sin conexión
  if new.official and new.date < today - 2 then
    raise exception 'Reto del % fuera de plazo', new.date;
  end if;
  -- reloj del móvil adelantado o atrasado más de 10 minutos
  if new.client_ts is not null and abs(extract(epoch from (new.client_ts - now()))) > 600
     and new.date = today then
    new.suspicious := true;
  end if;
  return new;
end $$;

drop trigger if exists results_check on public.results;
create trigger results_check before insert on public.results
  for each row execute function public.check_result();

-- ---------- helpers ----------
create or replace function public.my_group() returns uuid
language sql stable security definer set search_path = public as $$
  select group_id from players where user_id = auth.uid()
$$;

create or replace function public.join_group(p_code text, p_name text, p_avatar text)
returns public.players
language plpgsql security definer set search_path = public as $$
declare g uuid; pl players;
begin
  if auth.uid() is null then raise exception 'Sin sesión'; end if;
  select id into g from groups where upper(join_code) = upper(trim(p_code));
  if g is null then raise exception 'Código de grupo incorrecto'; end if;
  insert into players (user_id, group_id, name, avatar)
    values (auth.uid(), g, trim(p_name), p_avatar)
    returning * into pl;
  return pl;
exception when unique_violation then
  raise exception 'Ese personaje ya está cogido en el grupo';
end $$;

-- ---------- seguridad (RLS) ----------
alter table public.groups  enable row level security;
alter table public.players enable row level security;
alter table public.results enable row level security;

drop policy if exists groups_read on public.groups;
create policy groups_read on public.groups for select to authenticated
  using (id = public.my_group());

drop policy if exists players_read on public.players;
create policy players_read on public.players for select to authenticated
  using (group_id = public.my_group());

drop policy if exists players_rename on public.players;
create policy players_rename on public.players for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and group_id = public.my_group());

drop policy if exists results_read on public.results;
create policy results_read on public.results for select to authenticated
  using (player_id in (select id from public.players where group_id = public.my_group()));

drop policy if exists results_insert on public.results;
create policy results_insert on public.results for insert to authenticated
  with check (player_id in (select id from public.players where user_id = auth.uid()));

-- sin políticas de update/delete en results: nadie puede cambiar ni borrar resultados desde la app

grant execute on function public.join_group(text, text, text) to authenticated;

-- ---------- tu grupo ----------
-- Cambia el nombre y el código antes de ejecutar. El código es lo que teclea cada sobrino.
insert into public.groups (name, join_code) values ('Familia', 'CAMBIAME')
  on conflict (join_code) do nothing;
