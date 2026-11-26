-- Intimae · esquema de base de datos para el backend real (PostgreSQL / Supabase).
-- ESTADO: BORRADOR SIN EJECUTAR. No se ha probado contra ninguna base de datos. Revisar con quien vaya a operarlo.
-- La interfaz actual funciona en modo demostración (almacenamiento local del navegador, js/core.js) con la misma forma de datos.
-- Principios: datos personales mínimos; el comprador nunca ve datos del vendedor ni al revés; todo acceso por filas (RLS);
-- las contraseñas las gestiona el servicio de autenticación (no se guardan aquí). El estado de pago y de pedido
-- solo cambia desde el servidor con eventos verificados del proveedor de pagos, nunca desde el navegador.

create extension if not exists pgcrypto;

create type seller_kind   as enum ('particular', 'profesional');
create type vat_regime    as enum ('none', 'standard', 'margin');
create type seller_status as enum ('pending', 'verified', 'suspended');
create type listing_status as enum ('draft', 'pending', 'active', 'paused', 'sold', 'rejected', 'removed');
create type order_status  as enum ('paid', 'shipped', 'delivered', 'released', 'cancelled', 'incident', 'disputed', 'refunded');
create type report_status as enum ('open', 'removed', 'dismissed');

-- Perfil público/privado. id = auth.users.id
create table buyers (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null default '',
  delivery_address text not null default '',
  country char(2),
  age_verified_at timestamptz,           -- solo la fecha y el método; nunca la fecha de nacimiento
  age_verified_by text,                  -- proveedor
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table sellers (
  id uuid primary key references auth.users on delete cascade,
  alias text not null unique check (char_length(alias) between 3 and 30),
  country char(2) not null,              -- 'IC' = Canarias (fuera del territorio de IVA de la UE)
  kind seller_kind not null,
  vat regime not null default 'none',
  status seller_status not null default 'pending',
  comm_language text not null default 'es',
  about text not null default '',
  shop_name text not null default '', shop_bio text not null default '', shop_policy text not null default '',   -- tienda pública (sin datos personales)
  created_at timestamptz not null default now()
);

-- Datos fiscales (DAC7). Acceso solo para el propio vendedor y el equipo de administración.
create table seller_fiscal (
  seller_id uuid primary key references sellers on delete cascade,
  legal_name text not null,
  tax_id text not null,
  tax_country char(2) not null,
  address text not null,
  birth_date date,                       -- solo vendedores particulares (persona física)
  vat_id text,
  verified_by uuid references auth.users,
  verified_at timestamptz
);

create table listings (
  id bigserial primary key,
  ref text generated always as (lpad(id::text, 4, '0')) stored,
  seller_id uuid not null references sellers,
  type text not null check (type in ('braga','tanga','sujetador','camison','conjunto')),
  size text not null check (size in ('S','M','L','XL')),
  title text not null check (char_length(title) between 3 and 80),
  description text not null default '',
  material text not null default '',
  colour text not null default '',
  days_worn int not null check (days_worn between 0 and 60),
  price numeric(8,2) not null check (price between 5 and 500),
  images text[] not null check (array_length(images, 1) between 1 and 3),  -- rutas en almacenamiento privado
  status listing_status not null default 'pending',
  moderation_reason text,                -- exposición de motivos (art. 17 del Reglamento (UE) 2022/2065)
  moderated_by uuid references auth.users,
  moderated_at timestamptz,
  views int not null default 0,
  created_at timestamptz not null default now()
);
create index on listings (status, created_at desc);

create table orders (
  id bigserial primary key,
  no text generated always as ('IM-' || lpad(id::text, 6, '0')) stored,
  buyer_id uuid not null references buyers,
  seller_id uuid not null references sellers,
  dest_country char(2) not null,
  ship_name text not null, ship_line text not null,      -- se anonimizan al cerrar la cuenta o tras la entrega
  zone text not null,
  subtotal numeric(9,2) not null, shipping numeric(9,2) not null, vat_included numeric(9,2) not null default 0,
  total numeric(9,2) not null,
  commission_pct numeric(5,2) not null, commission numeric(9,2) not null, seller_net numeric(9,2) not null,
  status order_status not null default 'paid',
  charge_ref text, payout_ref text, refund_ref text,    -- referencias del proveedor de pagos
  carrier text, tracking text,
  created_at timestamptz not null default now(),
  shipped_at timestamptz, delivered_at timestamptz, released_at timestamptz
);
create table order_items (
  order_id bigint not null references orders on delete cascade,
  listing_id bigint not null references listings,
  unit_price numeric(8,2) not null,
  primary key (order_id, listing_id)
);
create table order_events (
  id bigserial primary key, order_id bigint not null references orders on delete cascade,
  status order_status not null, actor text not null, note text, at timestamptz not null default now()
);

create table threads (
  id bigserial primary key, listing_id bigint not null references listings,
  buyer_id uuid not null references buyers, seller_id uuid not null references sellers,
  unique (listing_id, buyer_id)
);
create table messages (
  id bigserial primary key, thread_id bigint not null references threads on delete cascade,
  from_buyer boolean not null, body text not null check (char_length(body) between 2 and 600), at timestamptz not null default now()
);

create table reviews (
  id bigserial primary key, order_id bigint not null unique references orders,
  buyer_id uuid not null references buyers, seller_id uuid not null references sellers,
  rating int not null check (rating between 1 and 5), body text not null default '' , seller_reply text, replied_at timestamptz, at timestamptz not null default now()
);
create table favourites (buyer_id uuid not null references buyers on delete cascade, listing_id bigint not null references listings on delete cascade, primary key (buyer_id, listing_id));

-- Notificaciones de contenido ilegal (art. 16 del Reglamento (UE) 2022/2065). Se admiten sin cuenta.
create table reports (
  id bigserial primary key, no text generated always as ('DN-' || lpad(id::text, 5, '0')) stored,
  listing_id bigint references listings, seller_id uuid references sellers,   -- denuncia de un anuncio o de una tienda
  reason text not null, body text not null default '', contact_email text,
  status report_status not null default 'open', statement text, resolved_by uuid references auth.users, resolved_at timestamptz,
  at timestamptz not null default now()
);

-- Incidencias de pedidos (procedimiento descrito en incidencias.html)
create table incidents (
  id bigserial primary key, no text generated always as ('IN-' || lpad(id::text, 5, '0')) stored,
  order_id bigint not null references orders, buyer_id uuid not null references buyers, seller_id uuid not null references sellers,
  reason text not null check (reason in ('no_enviado','no_recibido','distinto','danado','descripcion','fraude','pago','privacidad')),
  status text not null default 'open' check (status in ('open','disputed','resolved')),
  prev_order_status order_status not null,
  evidence text[] not null default '{}' check (array_length(evidence, 1) is null or array_length(evidence, 1) <= 2),
  decision text check (decision in ('refund','partial','reject')), refund_amount numeric(9,2), statement text,
  resolved_by uuid references auth.users, resolved_at timestamptz, opened_at timestamptz not null default now()
);
create table incident_messages (id bigserial primary key, incident_id bigint not null references incidents on delete cascade, from_role text not null check (from_role in ('buyer','seller','admin')), body text not null, at timestamptz not null default now());

create table notifications (id bigserial primary key, recipient uuid not null, recipient_role text not null, body text not null, link text, read boolean not null default false, at timestamptz not null default now());
create table follows (buyer_id uuid not null references buyers on delete cascade, seller_id uuid not null references sellers on delete cascade, primary key (buyer_id, seller_id));
create table blocks (buyer_id uuid not null references buyers on delete cascade, seller_id uuid not null references sellers on delete cascade, primary key (buyer_id, seller_id));
create table saved_searches (id bigserial primary key, buyer_id uuid not null references buyers on delete cascade, label text not null, filters jsonb not null);
create table legal_acceptances (id bigserial primary key, user_id uuid not null, document text not null, version text not null, at timestamptz not null default now());

create table settings (key text primary key, value jsonb not null);
insert into settings values ('commission', '20'), ('auto_deliver_days', '10'), ('auto_release_days', '7'), ('ship_deadline_days', '7'), ('incident_reply_days', '5');

create table audit_log (id bigserial primary key, actor text not null, action text not null, detail text, at timestamptz not null default now());

-- Rol de administración: claim 'role' = 'admin' en el JWT de las cuentas de equipo (con doble factor).
create function is_admin() returns boolean language sql stable as $$ select coalesce(auth.jwt() ->> 'role', '') = 'admin' $$;

alter table buyers enable row level security;        alter table sellers enable row level security;
alter table seller_fiscal enable row level security; alter table listings enable row level security;
alter table orders enable row level security;        alter table order_items enable row level security;
alter table order_events enable row level security;  alter table threads enable row level security;
alter table messages enable row level security;      alter table reviews enable row level security;
alter table favourites enable row level security;    alter table reports enable row level security;
alter table settings enable row level security;      alter table audit_log enable row level security;
alter table incidents enable row level security;     alter table incident_messages enable row level security;
alter table notifications enable row level security; alter table follows enable row level security;
alter table blocks enable row level security;        alter table saved_searches enable row level security;
alter table legal_acceptances enable row level security;

-- Tienda pública: solo anuncios activos de vendedores verificados y perfiles mínimos.
create policy listings_public on listings for select using (status = 'active' and exists (select 1 from sellers s where s.id = seller_id and s.status = 'verified'));
create policy listings_owner  on listings for all using (seller_id = auth.uid()) with check (seller_id = auth.uid() and status in ('pending','paused'));
create policy listings_admin  on listings for all using (is_admin());
create policy sellers_public  on sellers for select using (status = 'verified');
create policy sellers_self    on sellers for all using (id = auth.uid()) with check (id = auth.uid() and status = 'pending');
create policy sellers_admin   on sellers for all using (is_admin());
create policy fiscal_self     on seller_fiscal for all using (seller_id = auth.uid()) with check (seller_id = auth.uid());
create policy fiscal_admin    on seller_fiscal for all using (is_admin());
create policy buyers_self     on buyers for all using (id = auth.uid()) with check (id = auth.uid());
create policy orders_parties  on orders for select using (buyer_id = auth.uid() or seller_id = auth.uid() or is_admin());
create policy items_parties   on order_items for select using (exists (select 1 from orders o where o.id = order_id and (o.buyer_id = auth.uid() or o.seller_id = auth.uid() or is_admin())));
create policy events_parties  on order_events for select using (exists (select 1 from orders o where o.id = order_id and (o.buyer_id = auth.uid() or o.seller_id = auth.uid() or is_admin())));
create policy threads_parties on threads for select using (buyer_id = auth.uid() or seller_id = auth.uid());
create policy msgs_parties    on messages for select using (exists (select 1 from threads t where t.id = thread_id and (t.buyer_id = auth.uid() or t.seller_id = auth.uid())));
create policy reviews_public  on reviews for select using (true);
create policy favs_self       on favourites for all using (buyer_id = auth.uid()) with check (buyer_id = auth.uid());
create policy reports_insert  on reports for insert with check (true);
create policy reports_admin   on reports for all using (is_admin());
create policy settings_read   on settings for select using (true);
create policy settings_admin  on settings for all using (is_admin());
create policy audit_admin     on audit_log for select using (is_admin());
create policy incidents_parties on incidents for select using (buyer_id = auth.uid() or seller_id = auth.uid() or is_admin());
create policy incmsg_parties  on incident_messages for select using (exists (select 1 from incidents i where i.id = incident_id and (i.buyer_id = auth.uid() or i.seller_id = auth.uid() or is_admin())));
create policy notes_self      on notifications for all using (recipient = auth.uid());
create policy follows_self    on follows for all using (buyer_id = auth.uid()) with check (buyer_id = auth.uid());
create policy blocks_self     on blocks for all using (buyer_id = auth.uid()) with check (buyer_id = auth.uid());
create policy searches_self   on saved_searches for all using (buyer_id = auth.uid()) with check (buyer_id = auth.uid());
create policy accept_self     on legal_acceptances for select using (user_id = auth.uid() or is_admin());

-- Escrituras sensibles (crear pedido, enviar, cancelar, confirmar, liquidar, mensajes, valoraciones):
-- deben hacerse con funciones de servidor (funciones con SECURITY DEFINER o funciones de borde) que validen
-- estados y llamen al proveedor de pagos. Los pedidos nunca se insertan directamente desde el navegador.
