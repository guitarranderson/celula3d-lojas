-- Manter o projeto ligado no plano gratuito do Supabase.
-- Só ler o banco todo dia não bastou: o projeto foi pausado em 12/10/2026 mesmo
-- com a tarefa diária acessando. Agora a tarefa GRAVA uma linha, duas vezes por dia.
-- Este mesmo arquivo serve para o projeto Celula3D e para o Marcenaria.

create table if not exists manter_ligado (
  id         integer primary key default 1 check (id = 1),
  vezes      bigint not null default 0,
  ultimo_em  timestamptz not null default now()
);
alter table manter_ligado enable row level security;
revoke all on manter_ligado from anon, authenticated;

create or replace function registrar_ping() returns json
language plpgsql volatile security definer set search_path = public as $$
declare r manter_ligado;
begin
  insert into manter_ligado (id, vezes, ultimo_em) values (1, 1, now())
  on conflict (id) do update set vezes = manter_ligado.vezes + 1, ultimo_em = now()
  returning * into r;
  return json_build_object('vezes', r.vezes, 'ultimo_em', r.ultimo_em);
end $$;

revoke all on function registrar_ping() from public;
grant execute on function registrar_ping() to anon, authenticated;
