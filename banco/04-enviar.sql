-- Célula 3D Lojas — enviar peças de uma aba para outra (ex.: do Estoque para uma loja)
-- Rodar uma vez, depois do 03.
--
-- Baixa a quantidade do item de origem e soma no item igual da loja de destino
-- (mesmo código; sem código, mesmo nome). Se a loja ainda não tem o item, ele é
-- criado com o mesmo nome, código, valor e foto. Tudo numa transação só.

create or replace function admin_enviar(p_item uuid, p_loja uuid, p_qtd integer) returns json
language plpgsql volatile security definer set search_path = public as $$
declare o itens; d itens; somado boolean;
begin
  if not eh_admin() then raise exception 'sem_permissao'; end if;
  if p_qtd is null or p_qtd < 1 then raise exception 'quantidade_invalida'; end if;
  select * into o from itens where id = p_item for update;
  if not found then raise exception 'produto_nao_encontrado'; end if;
  if o.loja_id = p_loja then raise exception 'mesma_loja'; end if;
  if not exists (select 1 from lojas where id = p_loja) then raise exception 'loja_nao_encontrada'; end if;
  if o.qtd < p_qtd then raise exception 'estoque_insuficiente'; end if;

  select * into d from itens
   where loja_id = p_loja
     and case when o.codigo <> '' then codigo = o.codigo else codigo = '' and lower(trim(nome)) = lower(trim(o.nome)) end
   order by criado_em limit 1 for update;

  somado := found;
  if somado then
    update itens set qtd = qtd + p_qtd, foto = case when foto = '' then o.foto else foto end where id = d.id;
  else
    insert into itens (loja_id, nome, codigo, qtd, valor, foto) values (p_loja, o.nome, o.codigo, p_qtd, o.valor, o.foto);
  end if;
  update itens set qtd = qtd - p_qtd where id = o.id;
  return json_build_object('ok', true, 'restante', o.qtd - p_qtd, 'somado', somado);
end $$;

revoke all on function admin_enviar(uuid, uuid, integer) from public, anon;
grant execute on function admin_enviar(uuid, uuid, integer) to authenticated;
