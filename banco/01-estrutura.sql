-- Célula 3D Lojas — estrutura do banco (rodar uma vez no SQL Editor do Supabase)
--
-- Quem acessa o quê:
--   * o dono entra com e-mail e senha e vê/edita tudo (tabela admins);
--   * cada loja abre um link com um código secreto (lojas.token) e só
--     consegue ver os próprios produtos e lançar vendas, pelas funções
--     loja_dados / loja_registrar_venda — nunca lê as tabelas direto.

create extension if not exists pgcrypto;

create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

create table if not exists lojas (
  id         uuid primary key default gen_random_uuid(),
  nome       text not null check (length(trim(nome)) between 1 and 60),
  token      text not null unique default encode(gen_random_bytes(12), 'hex'),
  criado_em  timestamptz not null default now()
);

create table if not exists itens (
  id         uuid primary key default gen_random_uuid(),
  loja_id    uuid not null references lojas(id) on delete cascade,
  nome       text not null check (length(trim(nome)) between 1 and 120),
  codigo     text not null default '',
  qtd        integer not null default 0 check (qtd >= 0),
  valor      numeric(12,2) not null default 0 check (valor >= 0),
  criado_em  timestamptz not null default now()
);
create index if not exists itens_loja on itens(loja_id);

create table if not exists vendas (
  id          uuid primary key default gen_random_uuid(),
  loja_id     uuid not null references lojas(id) on delete cascade,
  item_id     uuid references itens(id) on delete set null,
  nome        text not null,          -- cópia do nome/código/valor no momento da venda,
  codigo      text not null default '',-- para o histórico não mudar se o item for editado
  qtd         integer not null check (qtd > 0),
  valor       numeric(12,2) not null,
  criado_em   timestamptz not null default now()
);
create index if not exists vendas_loja on vendas(loja_id, criado_em desc);

-- ---------- segurança ----------
alter table admins enable row level security;
alter table lojas  enable row level security;
alter table itens  enable row level security;
alter table vendas enable row level security;

create or replace function eh_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from admins where user_id = auth.uid());
$$;

drop policy if exists admin_ve_admins on admins;
create policy admin_ve_admins on admins for select to authenticated using (user_id = auth.uid());

drop policy if exists admin_lojas on lojas;
create policy admin_lojas on lojas for all to authenticated using (eh_admin()) with check (eh_admin());
drop policy if exists admin_itens on itens;
create policy admin_itens on itens for all to authenticated using (eh_admin()) with check (eh_admin());
drop policy if exists admin_vendas on vendas;
create policy admin_vendas on vendas for all to authenticated using (eh_admin()) with check (eh_admin());

-- Tabelas só para o dono logado; o link da loja não lê tabela nenhuma.
revoke all on admins, lojas, itens, vendas from anon;
grant select on admins to authenticated;
grant select, insert, update, delete on lojas, itens, vendas to authenticated;

-- ---------- o que a loja pode fazer (pelo link) ----------

-- Dados da loja: nome, produtos e as últimas vendas lançadas.
create or replace function loja_dados(p_token text) returns json
language plpgsql stable security definer set search_path = public as $$
declare l lojas;
begin
  select * into l from lojas where token = p_token;
  if not found then return null; end if;
  return json_build_object(
    'nome', l.nome,
    'itens', coalesce((select json_agg(json_build_object('id',i.id,'nome',i.nome,'codigo',i.codigo,'qtd',i.qtd,'valor',i.valor) order by i.nome)
                       from itens i where i.loja_id = l.id), '[]'::json),
    'vendas', coalesce((select json_agg(json_build_object('nome',v.nome,'codigo',v.codigo,'qtd',v.qtd,'valor',v.valor,'criado_em',v.criado_em) order by v.criado_em desc)
                        from (select * from vendas where loja_id = l.id order by criado_em desc limit 30) v), '[]'::json)
  );
end $$;

-- Lança uma venda: confere o estoque da loja, baixa a quantidade e grava o registro.
create or replace function loja_registrar_venda(p_token text, p_item uuid, p_qtd integer) returns json
language plpgsql volatile security definer set search_path = public as $$
declare l lojas; i itens;
begin
  select * into l from lojas where token = p_token;
  if not found then raise exception 'link_invalido'; end if;
  if p_qtd is null or p_qtd < 1 then raise exception 'quantidade_invalida'; end if;
  select * into i from itens where id = p_item and loja_id = l.id for update;
  if not found then raise exception 'produto_nao_encontrado'; end if;
  if i.qtd < p_qtd then raise exception 'estoque_insuficiente'; end if;
  update itens set qtd = qtd - p_qtd where id = i.id;
  insert into vendas(loja_id,item_id,nome,codigo,qtd,valor) values (l.id,i.id,i.nome,i.codigo,p_qtd,i.valor);
  return json_build_object('ok', true, 'restante', i.qtd - p_qtd);
end $$;

-- Desfazer venda (só o dono): devolve a quantidade ao item, se ele ainda existir.
create or replace function admin_desfazer_venda(p_venda uuid) returns void
language plpgsql volatile security definer set search_path = public as $$
declare v vendas;
begin
  if not eh_admin() then raise exception 'sem_permissao'; end if;
  select * into v from vendas where id = p_venda;
  if not found then return; end if;
  if v.item_id is not null then update itens set qtd = qtd + v.qtd where id = v.item_id; end if;
  delete from vendas where id = p_venda;
end $$;

revoke all on function loja_dados(text), loja_registrar_venda(text,uuid,integer), admin_desfazer_venda(uuid), eh_admin() from public;
grant execute on function loja_dados(text), loja_registrar_venda(text,uuid,integer) to anon, authenticated;
grant execute on function admin_desfazer_venda(uuid), eh_admin() to authenticated;

-- Atualização ao vivo na tela do dono
do $$ begin
  begin alter publication supabase_realtime add table vendas; exception when others then null; end;
  begin alter publication supabase_realtime add table itens;  exception when others then null; end;
end $$;
