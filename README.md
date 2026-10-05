# Célula 3D Lojas

Controle das peças da Célula 3D deixadas para venda em lojas parceiras.

- `index.html` é o painel do dono, com login. Tem uma aba por loja, os produtos, as vendas e a impressão em PDF.
- `loja.html?t=CÓDIGO` é a página que cada loja abre no celular, sem login, para lançar as vendas.
- `config.js` guarda o endereço e a chave pública do Supabase.
- `banco/` tem os SQL do Supabase. Rode o `01` uma vez e depois o `02`, com o e-mail do dono.
- `.github/workflows/manter-ligado.yml` acessa o Supabase todo dia (Célula 3D e Marcenaria) para os projetos não pausarem.
