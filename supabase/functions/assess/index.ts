// Edge Function: proxy do Azure Pronunciation Assessment. A chave do Azure
// vive como secret do Supabase (AZURE_SPEECH_KEY / AZURE_SPEECH_REGION) —
// nunca no cliente, para a web pública não vazar a chave. verify_jwt fica
// ligado: só a sessão anônima do app chama.
//
// Recebe JSON { referenceText, audioBase64 } e devolve o JSON detalhado do
// Azure (mesmo formato que o cliente já parseia). Sem a secret, retorna 503.

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const key = Deno.env.get("AZURE_SPEECH_KEY");
  const region = Deno.env.get("AZURE_SPEECH_REGION") ?? "brazilsouth";
  if (!key) {
    return new Response(JSON.stringify({ error: "azure_unconfigured" }), {
      status: 503,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  try {
    const { referenceText, audioBase64 } = await req.json();
    if (!referenceText || !audioBase64) {
      return new Response(JSON.stringify({ error: "missing_params" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const audio = Uint8Array.from(atob(audioBase64), (c) => c.charCodeAt(0));
    const config = btoa(
      JSON.stringify({
        ReferenceText: referenceText,
        // "HundredMark" — "HundredPoint" causa 400 no Azure.
        GradingSystem: "HundredMark",
        Granularity: "Phoneme",
        Dimension: "Comprehensive",
        EnableProsodyAssessment: "True",
      }),
    );

    const url =
      `https://${region}.stt.speech.microsoft.com` +
      `/speech/recognition/conversation/cognitiveservices/v1` +
      `?language=en-US&format=detailed`;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15_000);
    let azureRes: Response;
    try {
      azureRes = await fetch(url, {
        method: "POST",
        headers: {
          "Ocp-Apim-Subscription-Key": key,
          "Content-Type": "audio/wav; codecs=audio/pcm; samplerate=16000",
          "Pronunciation-Assessment": config,
          "Accept": "application/json",
        },
        body: audio,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
    }

    // Passa o corpo do Azure adiante (sucesso ou erro), preservando o status.
    const text = await azureRes.text();
    return new Response(text, {
      status: azureRes.status,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
