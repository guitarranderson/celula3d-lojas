-- Célula 3D Lojas — link do Estoque: cadastrar produtos e somar peças pelo celular
-- Rodar uma vez, depois do 04.
--
-- A aba cujo nome começa com "Estoque" é o depósito. O link dela não lança
-- vendas: serve para cadastrar produto novo (com foto) e somar peças prontas.
-- Quem tem o link do Estoque só consegue mexer no Estoque.

create or replace function eh_estoque(p_nome text) returns boolean
language sql immutable as $$ select lower(trim(p_nome)) like 'estoque%' $$;

-- A página do link passa a saber se é o Estoque (e o id, para a pasta das fotos)
create or replace function loja_dados(p_token text) returns json
language plpgsql stable security definer set search_path = public as $$
declare l lojas;
begin
  select * into l from lojas where token = p_token;
  if not found then return null; end if;
  return json_build_object(
    'nome', l.nome,
    'estoque', eh_estoque(l.nome),
    'pasta', case when eh_estoque(l.nome) then l.id end,
    'itens', coalesce((select json_agg(json_build_object('id',i.id,'nome',i.nome,'codigo',i.codigo,'qtd',i.qtd,'valor',i.valor,'foto',i.foto) order by i.nome)
                       from itens i where i.loja_id = l.id), '[]'::json),
    'vendas', coalesce((select json_agg(json_build_object('nome',v.nome,'codigo',v.codigo,'qtd',v.qtd,'valor',v.valor,'criado_em',v.criado_em) order by v.criado_em desc)
                        from (select * from vendas where loja_id = l.id order by criado_em desc limit 30) v), '[]'::json)
  );
end $$;

-- Cadastra um produto novo no Estoque
create or replace function estoque_adicionar(p_token text, p_nome text, p_codigo text, p_qtd integer, p_valor numeric, p_foto text) returns json
language plpgsql volatile security definer set search_path = public as $$
declare l lojas; novo uuid;
begin
  select * into l from lojas where token = p_token;
  if not found or not eh_estoque(l.nome) then raise exception 'link_invalido'; end if;
  if length(trim(coalesce(p_nome,''))) < 1 then raise exception 'nome_obrigatorio'; end if;
  if p_qtd is null or p_qtd < 0 then raise exception 'quantidade_invalida'; end if;
  if coalesce(p_foto,'') <> '' and p_foto not like l.id::text || '/%' then raise exception 'foto_invalida'; end if;
  insert into itens (loja_id, nome, codigo, qtd, valor, foto)
  values (l.id, left(trim(p_nome),120), left(trim(coalesce(p_codigo,'')),40), p_qtd, greatest(coalesce(p_valor,0),0), coalesce(p_foto,''))
  returning id into novo;
  return json_build_object('ok', true, 'id', novo);
end $$;

-- Soma peças prontas a um produto que já está no Estoque
create or replace function estoque_somar(p_token text, p_item uuid, p_qtd integer) returns json
language plpgsql volatile security definer set search_path = public as $$
declare l lojas; n integer;
begin
  select * into l from lojas where token = p_token;
  if not found or not eh_estoque(l.nome) then raise exception 'link_invalido'; end if;
  if p_qtd is null or p_qtd < 1 then raise exception 'quantidade_invalida'; end if;
  update itens set qtd = qtd + p_qtd where id = p_item and loja_id = l.id returning qtd into n;
  if not found then raise exception 'produto_nao_encontrado'; end if;
  return json_build_object('ok', true, 'qtd', n);
end $$;

revoke all on function estoque_adicionar(text,text,text,integer,numeric,text), estoque_somar(text,uuid,integer) from public;
grant execute on function estoque_adicionar(text,text,text,integer,numeric,text), estoque_somar(text,uuid,integer) to anon, authenticated;

-- Foto enviada pelo link do Estoque: só na pasta do próprio Estoque
-- (função security definer porque quem usa o link não lê a tabela lojas)
create or replace function pasta_de_estoque(p_pasta text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from lojas where id::text = p_pasta and eh_estoque(nome));
$$;
grant execute on function pasta_de_estoque(text) to anon, authenticated;

drop policy if exists fotos_link_estoque on storage.objects;
create policy fotos_link_estoque on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'fotos' and public.pasta_de_estoque((storage.foldername(name))[1]));
