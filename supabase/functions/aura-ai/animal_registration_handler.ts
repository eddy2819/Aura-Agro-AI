import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8"
import { encodeBase64 } from "https://deno.land/std@0.203.0/encoding/base64.ts"

type RegistrationPayload = {
  foto_opcional?: string
  foto_base64?: string
  image_base64?: string
  image_mime_type?: string
}

export async function analyzeAnimalRegistration(
  payload: RegistrationPayload,
  geminiApiKey: string,
) {
  let base64Image = payload.foto_base64 ?? payload.image_base64
  let mimeType = payload.image_mime_type ?? "image/jpeg"

  if (!base64Image && payload.foto_opcional) {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )
    const { data, error } = await supabase.storage
      .from("animal-photos")
      .download(payload.foto_opcional)
    if (error) throw new Error(`Failed to download animal photo: ${error.message}`)

    mimeType = data.type || mimeType
    base64Image = encodeBase64(new Uint8Array(await data.arrayBuffer()))
  }

  if (!base64Image) throw new Error("Animal photo is required")

  const prompt = `
Eres un veterinario zootecnista experto en identificación visual de bovinos y
animales de finca. Analiza únicamente lo visible en la fotografía. No inventes
arete, nombre, edad exacta, genealogía, vacunas ni diagnósticos sanitarios.

Devuelve estimaciones orientativas para autocompletar un formulario. Usa
exactamente uno de los valores permitidos cuando corresponda:
- category: Vaca Lechera, Toro Reproductor, Ternero, Ternera, Vaca de cria,
  Torete, Toro Engorde, Vaca de carne, Vaquilla, Novillo, Novilla, Burro,
  Caballo, Yegua o Mula.
- breed: Holstein, Brahman, Jersey, Gyr, Angus, Pardo Suizo, Simental o Mestizo.
- sex: Macho o Hembra.
- purpose: Leche, Carne o Doble propósito.
- stage: Ternero, Novillo, Vaca, Toro, Gestación o Lactancia.

El peso, producción y condición corporal son aproximaciones visuales. Si la
foto no permite estimar algo con suficiente confianza, usa null. La descripción
debe mencionar encuadre y rasgos físicos visibles, sin afirmar enfermedades.
`

  const geminiResponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=${geminiApiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            { inlineData: { mimeType, data: base64Image } },
          ],
        }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: {
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
          },
        },
      }),
    },
  )

  if (!geminiResponse.ok) {
    throw new Error(
      `Gemini API returned error: ${geminiResponse.status} - ${await geminiResponse.text()}`,
    )
  }

  const result = await geminiResponse.json()
  const responseText = result.candidates?.[0]?.content?.parts?.[0]?.text
  if (!responseText) throw new Error("No text content returned from Gemini")

  return JSON.parse(responseText)
}
