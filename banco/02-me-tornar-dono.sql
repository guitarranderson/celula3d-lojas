-- Rodar DEPOIS de criar o seu usuário em Authentication > Users > Add user.
-- Troque o e-mail abaixo pelo que você cadastrou.
insert into admins(user_id)
select id from auth.users where email = 'SEU-EMAIL-AQUI'
on conflict do nothing;

select u.email, 'é dono' as situacao from admins a join auth.users u on u.id = a.user_id;
