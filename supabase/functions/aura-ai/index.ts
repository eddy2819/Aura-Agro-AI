import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8"
import { encodeBase64 } from "https://deno.land/std@0.203.0/encoding/base64.ts"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

async function loadImage(payload: Record<string, unknown>) {
  let data = (payload.foto_base64 ?? payload.image_base64) as string | undefined
  let mimeType = (payload.image_mime_type as string | undefined) ?? "image/jpeg"

  if (!data && payload.foto_opcional) {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )
    const result = await supabase.storage
      .from("animal-photos")
      .download(String(payload.foto_opcional))
    if (result.error) {
      throw new Error(`Failed to download animal photo: ${result.error.message}`)
    }
    mimeType = result.data.type || mimeType
    data = encodeBase64(new Uint8Array(await result.data.arrayBuffer()))
  }

  if (!data) throw new Error("Animal photo is required")
  return { data, mimeType }
}

async function callGemini(
  apiKey: string,
  prompt: string,
  responseSchema: Record<string, unknown>,
  image?: { data: string; mimeType: string },
  preferLite = false,
) {
  const parts: Record<string, unknown>[] = [{ text: prompt }]
  if (image) {
    parts.push({ inlineData: { mimeType: image.mimeType, data: image.data } })
  }

  const requestBody = JSON.stringify({
    contents: [{ parts }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema,
      temperature: 0.2,
      maxOutputTokens: 3072,
      thinkingConfig: { thinkingBudget: 0 },
    },
  })
  const models = preferLite
    ? ["gemini-3.1-flash-lite", "gemini-3.5-flash", "gemini-flash-latest"]
    : ["gemini-3.5-flash", "gemini-3.1-flash-lite", "gemini-flash-latest"]
  let lastError = "Gemini unavailable"

  for (const model of models) {
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 18000)
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: requestBody,
          signal: controller.signal,
        },
      )

      if (response.ok) {
        const result = await response.json()
        const text = result.candidates?.[0]?.content?.parts?.[0]?.text
        if (!text) throw new Error("No text content returned from Gemini")
        console.log(`Gemini completed with model=${model}`)
        return JSON.parse(text)
      }

      const errorText = await response.text()
      lastError = `${model} returned ${response.status}: ${errorText}`
      const tryNextModel = [404, 429, 500, 503, 504].includes(response.status)
      console.warn(`Gemini tryNextModel=${tryNextModel} ${lastError}`)
      // 404 significa modelo retirado/no habilitado: debe probar el siguiente.
      // Los 4xx restantes indican una petición inválida y no mejorarán cambiando
      // silenciosamente de modelo.
      if (!tryNextModel) throw new Error(lastError)
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        lastError = `${model} timed out after 18 seconds`
        console.warn(lastError)
      } else {
        throw error
      }
    } finally {
      clearTimeout(timeout)
    }
  }

  throw new Error(`Gemini temporarily unavailable after retries: ${lastError}`)
}

const registrationSchema = {
  type: "OBJECT",
  properties: {
    category: { type: "STRING", nullable: true },
    breed: { type: "STRING", nullable: true },
    sex: { type: "STRING", nullable: true },
    purpose: { type: "STRING", nullable: true },
    stage: { type: "STRING", nullable: true },
    color: { type: "STRING", nullable: true },
    estimated_weight_kg: { type: "NUMBER", nullable: true },
    body_condition_estimated: { type: "NUMBER", nullable: true },
    production_liters_estimated: { type: "NUMBER", nullable: true },
    description: { type: "STRING" },
    confidence: { type: "NUMBER" },
    disclaimer: { type: "STRING" },
  },
  required: ["description", "confidence", "disclaimer"],
}

const bodyConditionSchema = {
  type: "OBJECT",
  properties: {
    body_condition_estimated: { type: "STRING" },
    observations: { type: "STRING" },
    nutritional_improvements: { type: "STRING" },
    confidence_level: { type: "STRING" },
    disclaimer: { type: "STRING" },
  },
  required: ["body_condition_estimated", "observations", "nutritional_improvements", "confidence_level", "disclaimer"],
}

const medicineLabelSchema = {
  type: "OBJECT",
  properties: {
    name: { type: "STRING", nullable: true },
    active_ingredient: { type: "STRING", nullable: true },
    type: { type: "STRING", nullable: true },
    presentation: { type: "STRING", nullable: true },
    concentration: { type: "STRING", nullable: true },
    expiration_date: { type: "STRING", nullable: true },
    batch_number: { type: "STRING", nullable: true },
    provider: { type: "STRING", nullable: true },
    withdrawal_period: { type: "STRING", nullable: true },
    indications: { type: "STRING", nullable: true },
    contraindications: { type: "STRING", nullable: true },
    confidence: { type: "NUMBER" },
  },
  required: ["confidence"],
}

const nutritionSchema = {
  type: "OBJECT",
  properties: {
    suggested_diet: { type: "STRING" },
    estimated_cost_per_day: { type: "NUMBER" },
    projected_savings: { type: "NUMBER" },
    projected_improvement: { type: "STRING" },
    explanation: { type: "STRING" },
    viability_score: { type: "INTEGER" },
    limiting_resource: { type: "STRING" },
    resources_table: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          resource_name: { type: "STRING" },
          daily_intake: { type: "STRING" },
          cost_contribution: { type: "STRING" },
          status: { type: "STRING" },
        },
        required: ["resource_name", "daily_intake", "cost_contribution", "status"],
      },
    },
    alerts: { type: "ARRAY", items: { type: "STRING" } },
    recommendations: {
      type: "OBJECT",
      properties: {
        today: { type: "ARRAY", items: { type: "STRING" } },
        week: { type: "ARRAY", items: { type: "STRING" } },
        monitor: { type: "ARRAY", items: { type: "STRING" } },
      },
      required: ["today", "week", "monitor"],
    },
    scenarios: {
      type: "OBJECT",
      properties: {
        optimistic: { type: "STRING" },
        conservative: { type: "STRING" },
        pessimistic: { type: "STRING" },
      },
      required: ["optimistic", "conservative", "pessimistic"],
    },
    projection_data: { type: "ARRAY", items: { type: "NUMBER" } },
  },
  required: ["suggested_diet", "estimated_cost_per_day", "projected_savings", "projected_improvement", "explanation", "viability_score", "limiting_resource", "resources_table", "alerts", "recommendations", "scenarios", "projection_data"],
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const apiKey = Deno.env.get("GEMINI_API_KEY")
    if (!apiKey) throw new Error("GEMINI_API_KEY is not configured in Supabase secrets")

    const payload = await req.json()
    const action = payload.action
    console.log(`aura-ai action=${action ?? "nutrition_plan"}`)

    if (action === "analyze_animal_registration") {
      const image = await loadImage(payload)
      const prompt = `Eres veterinario zootecnista experto en identificación visual.
Analiza solo lo visible y no inventes identidad, edad exacta, genealogía, vacunas ni enfermedades.
Valores permitidos:
category: Vaca Lechera, Toro Reproductor, Ternero, Ternera, Vaca de cria, Torete, Toro Engorde, Vaca de carne, Vaquilla, Novillo, Novilla, Burro, Caballo, Yegua, Mula.
breed: Holstein, Brahman, Jersey, Gyr, Angus, Pardo Suizo, Simental, Mestizo.
sex: Macho, Hembra. purpose: Leche, Carne, Doble propósito.
stage: Ternero, Novillo, Vaca, Toro, Gestación, Lactancia.
Peso, producción y condición corporal son aproximaciones. Usa null si la foto no permite inferir un campo. confidence debe estar entre 0 y 1.`
      const analysis = await callGemini(apiKey, prompt, registrationSchema, image)
      return new Response(JSON.stringify({ animal_analysis: analysis }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    if (action === "analyze_photo") {
      const image = await loadImage(payload)
      const prompt = `Eres veterinario y zootecnista bovino. Estima condición corporal de 1 a 5 observando costillas, cola, cadera y columna. Datos reportados: ${JSON.stringify(payload.datos_animales)}. Devuelve diagnóstico orientativo y aclara que no reemplaza examen profesional.`
      const analysis = await callGemini(apiKey, prompt, bodyConditionSchema, image)
      return new Response(JSON.stringify({ visual_analysis: analysis }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    if (action === "analyze_medicine_label") {
      const image = await loadImage(payload)
      const prompt = `Lee únicamente la información visible en la etiqueta de este producto veterinario.
No inventes datos, dosis ni recomendaciones. Usa null cuando un campo no sea legible.
Tipos permitidos: Vacuna, Antibiótico, Antiinflamatorio, Desparasitante, Vitamina, Mineral, Suplemento, Otro.
expiration_date debe ser YYYY-MM-DD cuando sea posible. confidence entre 0 y 1.
El periodo de retiro, indicaciones y contraindicaciones deben transcribirse o resumirse sólo si aparecen visibles.`
      const analysis = await callGemini(
        apiKey,
        prompt,
        medicineLabelSchema,
        image,
        true,
      )
      return new Response(JSON.stringify({ medicine_analysis: analysis }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      })
    }

    const prompt = `Eres experto en nutrición de rumiantes en Ecuador. Diseña un plan de mínimo costo.
Animales: ${JSON.stringify(payload.datos_animales)}
Recursos: ${JSON.stringify(payload.recursos_confirmados)}
Consideraciones: ${JSON.stringify(payload.consideraciones_especiales)}
Requerimientos calculados: ${JSON.stringify(payload.resultados_calculados)}
Evalúa materia seca, porcentajes de ración, costo diario por animal, ahorro semanal, mejora productiva, suficiencia de inventario, alertas, acciones para hoy/semana/monitoreo, tres escenarios y cuatro proyecciones numéricas. Responde solo JSON conforme al esquema.`
    // Nutrición parte de requerimientos ya calculados: Flash-Lite ofrece menor
    // latencia; Flash queda como respaldo inmediato si el servicio está saturado.
    const plan = await callGemini(apiKey, prompt, nutritionSchema, undefined, true)
    return new Response(JSON.stringify(plan), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (error) {
    console.error(error)
    const message = error instanceof Error ? error.message : String(error)
    const status = message.includes("temporarily unavailable") ? 503 : 400
    return new Response(JSON.stringify({ error: message }), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  }
})
