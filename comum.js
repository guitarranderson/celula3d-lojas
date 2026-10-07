import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm";
import { SUPABASE_URL, SUPABASE_KEY } from "./config.js?v=1";

export const configurado = Boolean(SUPABASE_URL && SUPABASE_KEY);
export const sb = configurado ? createClient(SUPABASE_URL, SUPABASE_KEY) : null;

// Fotos dos produtos: guardadas no balde público "fotos" do Supabase
export const fotoURL = caminho => caminho ? `${SUPABASE_URL}/storage/v1/object/public/fotos/${caminho}` : "";

// Reduz a foto no próprio aparelho antes de enviar (lado maior 900 px, JPEG)
export function reduzirFoto(arquivo, lado = 900) {
  return new Promise((ok, erro) => {
    const url = URL.createObjectURL(arquivo), img = new Image();
    img.onload = () => {
      const k = Math.min(1, lado / Math.max(img.naturalWidth, img.naturalHeight));
      const c = document.createElement("canvas");
      c.width = Math.round(img.naturalWidth * k); c.height = Math.round(img.naturalHeight * k);
      const g = c.getContext("2d"); g.fillStyle = "#fff"; g.fillRect(0, 0, c.width, c.height); g.drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      c.toBlob(b => b ? ok(b) : erro(new Error("foto_invalida")), "image/jpeg", 0.82);
    };
    img.onerror = () => { URL.revokeObjectURL(url); erro(new Error("foto_invalida")); };
    img.src = url;
  });
}

export const brl =new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });
export const fmtQ = n => new Intl.NumberFormat("pt-BR").format(n);
export const $ = id => document.getElementById(id);
export const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
export const parseNum = v => {
  v = String(v || "").trim().replace(/\s|R\$/g, "");
  if (v.includes(",")) v = v.replace(/\./g, "").replace(",", ".");
  const n = parseFloat(v); return isFinite(n) ? n : 0;
};
export const dataHora = iso => new Date(iso).toLocaleString("pt-BR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" });

// Mensagens de erro do banco em português
const ERROS = {
  link_invalido: "Este link não vale mais. Peça um link novo para a Célula 3D.",
  estoque_insuficiente: "A loja não tem essa quantidade desse produto. Confira o número.",
  produto_nao_encontrado: "Esse produto não está mais na lista. Atualize a página.",
  quantidade_invalida: "Informe uma quantidade de pelo menos 1.",
  sem_permissao: "Sua conta não tem permissão para isso.",
  foto_invalida: "Não consegui abrir essa foto. Tente outra imagem (JPG ou PNG).",
};
export function msgErro(e) {
  const m = String(e?.message || e || "");
  for (const k in ERROS) if (m.includes(k)) return ERROS[k];
  if (/Failed to fetch|NetworkError|network/i.test(m)) return "Sem conexão com a internet. Tente de novo.";
  if (/Invalid login/i.test(m)) return "E-mail ou senha incorretos.";
  return "Não foi possível concluir. Tente de novo em instantes.";
}

// Modal próprio
export function dialog({ title, text = "", input = false, value = "", label = "", ok = "OK", danger = false, html = "" }) {
  return new Promise(res => {
    const veil = document.createElement("div");
    veil.className = "veil";
    veil.innerHTML = `<div class="dialog" role="dialog" aria-modal="true">
      <h3></h3>${text ? "<p></p>" : ""}${html}
      ${input ? `<div class="field"><label for="dlgIn"></label><input id="dlgIn" autocomplete="off" maxlength="60"></div>` : ""}
      <div class="row"><button class="ghost" type="button" data-x>Cancelar</button><button class="${danger ? "danger" : "btn"}" type="button" data-ok></button></div></div>`;
    veil.querySelector("h3").textContent = title;
    if (text) veil.querySelector("p").textContent = text;
    veil.querySelector("[data-ok]").textContent = ok;
    const inp = veil.querySelector("#dlgIn");
    if (inp) { inp.value = value; veil.querySelector("label").textContent = label; }
    document.body.appendChild(veil);
    (inp || veil.querySelector("[data-ok]")).focus();
    const done = v => { veil.remove(); document.removeEventListener("keydown", key); res(v); };
    const key = e => { if (e.key === "Escape") done(input ? null : false); if (e.key === "Enter" && inp) done(inp.value.trim()); };
    document.addEventListener("keydown", key);
    veil.querySelector("[data-ok]").onclick = () => done(input ? inp.value.trim() : true);
    veil.querySelector("[data-x]").onclick = () => done(input ? null : false);
  });
}

export async function copiar(texto) {
  try { await navigator.clipboard.writeText(texto); return true; } catch { return false; }
}
