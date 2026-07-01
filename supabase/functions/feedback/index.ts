// Edge Function: gera feedback de pronúncia em PT-BR a partir dos scores do
// Azure, no tom da marca. A chave da Anthropic vive como secret do Supabase
// (ANTHROPIC_API_KEY) — nunca no cliente. verify_jwt fica ligado, então só
// usuários autenticados (sessão anônima do app) conseguem chamar.
//
// Sem a secret configurada, retorna 503 e o app cai nas mensagens fixas.
import Anthropic from "npm:@anthropic-ai/sdk@0.70.0";
import { createClient } from "npm:@supabase/supabase-js@2";

// Haiku 4.5: a tarefa é mapear scores do Azure → 1-2 frases curtas seguindo
// regras rígidas de tom — instrução estruturada que o Haiku segue bem, a 1/5
// do custo do Opus. Trocável por secret FEEDBACK_MODEL sem redeploy.
const MODEL = Deno.env.get("FEEDBACK_MODEL") ?? "claude-haiku-4-5";

// Teto diário de feedbacks por usuário (defesa contra loop/abuso de um único
// usuário; o crédito pré-pago já é o teto de custo duro da org). Trocável por
// secret FEEDBACK_DAILY_LIMIT sem redeploy.
const DAILY_LIMIT = Number(Deno.env.get("FEEDBACK_DAILY_LIMIT") ?? "150");

const SYSTEM = `Você é o coach de pronúncia do 484 Method, um app que ensina \
brasileiros adultos a falar inglês. Tom adulto, direto e encorajador — nunca \
infantiliza, nunca promete fluência mágica.

Você recebe os scores do Azure Pronunciation Assessment de UMA tentativa e \
escreve o feedback em português do Brasil simples, em NO MÁXIMO 3 frases \
curtas, nesta ordem obrigatória:
1. Diagnóstico curto (o que aconteceu nessa tentativa).
2. Instrução prática (o que fazer na próxima).
3. Uma repetição sugerida (como treinar agora, ex.: falar em partes e depois \
em ritmo natural).

Regras rígidas:
- NUNCA diga só "errado". Sempre aponte o que tentar na próxima gravação.
- NUNCA diga "pronuncie a letra X" ou fale de letras como se fossem sons — \
o problema é sempre de SOM, não de ortografia.
- NUNCA invente sons, sílabas ou letras que não estejam claramente nos dados \
recebidos (word, worstSyllable). Se não houver um trecho fraco identificado, \
fale do todo, não invente um pedaço.
- NUNCA use códigos internos, fonemas técnicos ou notação (ex.: não escreva \
"o fonema X" nem chaves internas) — use só a palavra em si e, quando útil, \
uma quebra em pedaços pronunciáveis (ex.: "COMF — tuh — buhl").
- Se o erro parecer leitura pela escrita (tentativa soou como as letras em \
português), reforce sound-first: ouvir de novo antes de tentar de novo.
- Se passou bem, comemore de forma sóbria e sugira repetir para fixar.
- Fale com "você". Não use emojis. Não use aspas. Não explique os números \
brutos do Azure (accuracy/fluency/completeness/prosódia são internos, nunca \
citar esses nomes ou seus valores).
- Responda APENAS com o feedback, nada mais.`;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "feedback_unconfigured" }), {
      status: 503,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  // Teto por usuário/dia: incrementa atômico via RPC (conta por auth.uid()).
  // Acima do limite → 429, e o cliente cai na mensagem fixa. Fail-open: uma
  // falha do contador não derruba o feedback (o pré-pago é o teto de custo duro).
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const authHeader = req.headers.get("Authorization");
    if (supabaseUrl && anonKey && authHeader) {
      const supabase = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: allowed, error } = await supabase.rpc(
        "consume_feedback_quota",
        { p_limit: DAILY_LIMIT },
      );
      if (!error && allowed === false) {
        return new Response(JSON.stringify({ error: "quota_exceeded" }), {
          status: 429,
          headers: { ...cors, "Content-Type": "application/json" },
        });
      }
    }
  } catch (_e) {
    // fail-open: não bloqueia o feedback por causa do contador
  }

  try {
    const p = await req.json();
    const client = new Anthropic({ apiKey });
    const message = await client.messages.create({
      model: MODEL,
      max_tokens: 150,
      system: SYSTEM,
      messages: [
        {
          role: "user",
          content:
            `Palavra-alvo: "${p.word}". Tentativa ${p.attempt} de 2. ` +
            `Aprovada: ${p.approved ? "sim" : "não"}. ` +
            `Accuracy ${p.accuracy}, fluency ${p.fluency}, ` +
            `completeness ${p.completeness}, prosódia ${p.prosody ?? "n/d"}. ` +
            `Fonema mais fraco: ${p.minPhoneme}. ` +
            (p.worstSyllable
              ? `Trecho mais fraco: "${p.worstSyllable}". `
              : "") +
            `Escreva o feedback.`,
        },
      ],
    });
    const text = message.content
      .filter((b) => b.type === "text")
      .map((b) => (b as { text: string }).text)
      .join(" ")
      .trim();
    return new Response(JSON.stringify({ message: text }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
