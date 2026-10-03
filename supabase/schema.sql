-- BantuTemukan.id core data model
-- Prepared for the existing Supabase project: bantutemukan.id
-- This file is NOT applied automatically while the project is inactive.

create extension if not exists vector with schema extensions;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('buyer','umkm','admin')),
  full_name text,
  phone text,
  created_at timestamptz not null default now()
);

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles(id) on delete set null,
  name text not null,
  description text,
  category text,
  address text,
  city text not null default 'Surabaya',
  district text,
  service_area text,
  whatsapp text,
  verified boolean not null default false,
  active boolean not null default true,
  source text not null default 'btt',
  source_id text,
  embedding vector(768),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  description text,
  category text,
  price numeric(14,2),
  unit text,
  stock numeric(14,2),
  min_order numeric(14,2),
  delivery_available boolean not null default false,
  active boolean not null default true,
  embedding vector(768),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  description text,
  category text,
  starting_price numeric(14,2),
  unit text,
  availability text,
  service_area text,
  active boolean not null default true,
  embedding vector(768),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_requests (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid references public.profiles(id) on delete set null,
  raw_request text not null,
  category text,
  city text,
  district text,
  quantity numeric(14,2),
  budget numeric(14,2),
  needed_at timestamptz,
  status text not null default 'new'
    check (status in ('new','matching','matched','contacted','closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.customer_requests(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete cascade,
  product_id uuid references public.products(id) on delete cascade,
  service_id uuid references public.services(id) on delete cascade,
  match_score numeric(8,5),
  reason text,
  created_at timestamptz not null default now(),
  check (
    product_id is not null
    or service_id is not null
    or business_id is not null
  )
);

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  request_id uuid references public.customer_requests(id) on delete set null,
  buyer_id uuid references public.profiles(id) on delete set null,
  business_id uuid not null references public.businesses(id) on delete cascade,
  status text not null default 'new'
    check (status in ('new','contacted','accepted','rejected','closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid references public.profiles(id) on delete set null,
  business_id uuid references public.businesses(id) on delete set null,
  request_id uuid references public.customer_requests(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending','accepted','processing','ready','delivered','completed','cancelled')),
  total numeric(14,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists businesses_city_idx on public.businesses(city);
create index if not exists businesses_category_idx on public.businesses(category);
create index if not exists products_business_idx on public.products(business_id);
create index if not exists services_business_idx on public.services(business_id);
create index if not exists requests_buyer_idx on public.customer_requests(buyer_id);
create index if not exists matches_request_idx on public.matches(request_id);
create index if not exists leads_business_idx on public.leads(business_id);
create index if not exists orders_business_idx on public.orders(business_id);

alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.products enable row level security;
alter table public.services enable row level security;
alter table public.customer_requests enable row level security;
alter table public.matches enable row level security;
alter table public.leads enable row level security;
alter table public.orders enable row level security;

-- Public matching must only expose active, approved business data.
create policy "public can read active verified businesses"
on public.businesses for select to anon, authenticated
using (active = true and verified = true);

create policy "public can read active products"
on public.products for select to anon, authenticated
using (
  active = true
  and exists (
    select 1 from public.businesses b
    where b.id = business_id and b.active = true and b.verified = true
  )
);

create policy "public can read active services"
on public.services for select to anon, authenticated
using (
  active = true
  and exists (
    select 1 from public.businesses b
    where b.id = business_id and b.active = true and b.verified = true
  )
);
