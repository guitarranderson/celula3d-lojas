-- Célula 3D Lojas — fotos dos produtos (rodar uma vez, depois do 01 e do 02)
-- As fotos ficam no Storage do Supabase, num balde público só de leitura:
-- qualquer um com o endereço vê a foto (é o que a página da loja precisa),
-- mas só o dono envia, troca ou apaga.

alter table itens add column if not exists foto text not null default '';

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', true, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists fotos_dono_envia on storage.objects;
create policy fotos_dono_envia on storage.objects for insert to authenticated
  with check (bucket_id = 'fotos' and public.eh_admin());
drop policy if exists fotos_dono_troca on storage.objects;
create policy fotos_dono_troca on storage.objects for update to authenticated
  using (bucket_id = 'fotos' and public.eh_admin()) with check (bucket_id = 'fotos' and public.eh_admin());
drop policy if exists fotos_dono_apaga on storage.objects;
create policy fotos_dono_apaga on storage.objects for delete to authenticated
  using (bucket_id = 'fotos' and public.eh_admin());
drop policy if exists fotos_dono_le on storage.objects;
create policy fotos_dono_le on storage.objects for select to authenticated
  using (bucket_id = 'fotos' and public.eh_admin());

-- A página da loja passa a receber a foto de cada produto
create or replace function loja_dados(p_token text) returns json
language plpgsql stable security definer set search_path = public as $$
declare l lojas;
begin
  select * into l from lojas where token = p_token;
  if not found then return null; end if;
  return json_build_object(
    'nome', l.nome,
    'itens', coalesce((select json_agg(json_build_object('id',i.id,'nome',i.nome,'codigo',i.codigo,'qtd',i.qtd,'valor',i.valor,'foto',i.foto) order by i.nome)
                       from itens i where i.loja_id = l.id), '[]'::json),
    'vendas', coalesce((select json_agg(json_build_object('nome',v.nome,'codigo',v.codigo,'qtd',v.qtd,'valor',v.valor,'criado_em',v.criado_em) order by v.criado_em desc)
                        from (select * from vendas where loja_id = l.id order by criado_em desc limit 30) v), '[]'::json)
  );
end $$;
