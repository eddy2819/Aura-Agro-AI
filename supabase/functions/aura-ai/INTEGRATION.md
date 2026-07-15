En `index.ts`, agrega junto a los imports:

```ts
import { analyzeAnimalRegistration } from "./animal_registration_handler.ts"
```

Después de `const payload = await req.json()` y antes del bloque
`if (action === 'analyze_photo' && foto_opcional)`, agrega:

```ts
if (action === "analyze_animal_registration") {
  const animalAnalysis = await analyzeAnimalRegistration(payload, GEMINI_API_KEY)
  return new Response(JSON.stringify({ animal_analysis: animalAnalysis }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status: 200,
  })
}
```

No reemplaces el bloque `analyze_photo` ni el `else` nutricional existente.
