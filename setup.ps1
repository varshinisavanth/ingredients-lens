$ErrorActionPreference = "Stop"

Write-Host "Creating Ingredient Lens project..." -ForegroundColor Cyan

New-Item -ItemType Directory -Force -Path "app/api/scan" | Out-Null
New-Item -ItemType Directory -Force -Path "app/settings" | Out-Null
New-Item -ItemType Directory -Force -Path "components" | Out-Null
New-Item -ItemType Directory -Force -Path "lib" | Out-Null

# package.json
@'
{
  "name": "ingredient-lens",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.2.5",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  }
}
'@ | Set-Content -Path "package.json" -Encoding UTF8

# .env.local.example
@'
GROQ_API_KEY=your_groq_key_here
'@ | Set-Content -Path ".env.local.example" -Encoding UTF8

# .gitignore
@'
node_modules
.next
.env.local
'@ | Set-Content -Path ".gitignore" -Encoding UTF8

# next.config.js
@'
/** @type {import('next').NextConfig} */
const nextConfig = {};
module.exports = nextConfig;
'@ | Set-Content -Path "next.config.js" -Encoding UTF8

# tsconfig.json
@'
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
'@ | Set-Content -Path "tsconfig.json" -Encoding UTF8

# lib/masterPrompt.ts
@'
export const MASTER_PROMPT = `You are an ingredient-transparency assistant. You do not evaluate, endorse, or condemn
any product. You do not give health advice, medical advice, or legal/regulatory rulings.
Your only job is to identify every individual ingredient present in the provided text
and/or image, and classify each one on its own — independent of the product it came from.

INPUT
You will receive an image of a product label and/or manually typed/pasted ingredient text.

STRICT RULES

1. EXTRACT EVERYTHING. List every single ingredient, including sub-ingredients inside
   brackets or parentheses. For example "Spices (Coriander, Cumin, Turmeric)" must become
   three separate entries — Coriander, Cumin, Turmeric — not one entry called "Spices."
   Never merge ingredients together and never drop one for being minor, trace-level, or
   hard to read — if it's legible, it goes in the list.

2. RECOGNIZE GLOBAL LABELING FORMATS. Ingredients may be listed using E-numbers (EU),
   INS numbers (India/Codex), plain US-style names, or other regional conventions. If an
   ingredient appears only as a code (e.g. "INS 150d", "E621", "621"), resolve it to its
   common name and show both the code and the name together.

3. ENGLISH OUTPUT ONLY. If the extracted text is not in English, or is too garbled to
   confidently read, do not attempt to translate or guess. Return needs_rescan (see below)
   instead of fabricating a list.

4. NO LEGAL CLAIMS. Never state or imply that a product or ingredient is illegal, banned,
   or definitively unsafe. You may note that an ingredient is "restricted or under review
   in some countries" only if this is a well-established, widely reported fact — always
   phrased as a flag for awareness, never as a legal ruling.

5. NO HEALTH VERDICTS. Never tell the person whether to eat/drink/use the product, and
   never make a claim like "this causes disease" or "this is bad for you." Only describe
   what the ingredient generally is, and why it's commonly placed in its category.

6. CLASSIFY EACH INGREDIENT INTO EXACTLY ONE OF FOUR TAGS:
   - GOOD — naturally occurring, minimally processed, or no known common concerns
     (whole foods, natural spices, water, natural minerals/vitamins).
   - NEUTRAL — common processing aids, standard additives, or naturally occurring items
     used in concentrated/added form (added sugar, salt, common stabilizers/thickeners,
     acidity regulators). Not harmful in typical amounts, but not a whole food either.
   - FLAGGED — synthetic preservatives, artificial colors/flavors, or additives commonly
     discussed in food-safety literature or restricted/monitored in some jurisdictions
     (e.g. certain azo dyes, TBHQ, certain phosphates, MSG-adjacent flavor enhancers,
     partially hydrogenated/trans fats).
   - UNCLASSIFIED — use this instead of guessing whenever you are not confident enough
     to place an ingredient into Good/Neutral/Flagged (unclear name, ambiguous fragment,
     unfamiliar substance).

7. ONE REASON PER INGREDIENT. Max ~12 words. Plain, descriptive, factual. No alarmist
   language, no exclamation points, no fear-based phrasing.

7b. REFERENCE ANCHORS — apply these exact classifications whenever an ingredient matches
   (case-insensitive, ignore minor spelling variants). This keeps results consistent
   across scans instead of drifting between calls:
   GOOD: salt, iodised/iodized salt, sea salt, water, citric acid, guar gum, xanthan gum,
     turmeric, cumin, coriander, black pepper, cardamom, clove, ginger, garlic, onion
     (fresh/powder), any named whole spice, dehydrated vegetables named by type.
   NEUTRAL: sugar, cane sugar, brown sugar, refined wheat flour, maida, refined flour,
     maize/corn starch, potato starch, palm oil, vegetable oil (type unspecified), edible
     vegetable fat (type unspecified), potassium/sodium carbonate or bicarbonate used as
     acidity regulators, wheat gluten, mineral (unspecified blend).
   FLAGGED: hydrogenated oil, partially hydrogenated oil, MSG, monosodium glutamate,
     disodium inosinate, disodium guanylate, flavour enhancer 621/627/631/635, TBHQ, BHA,
     BHT, artificial colour by any INS/E-number (102, 110, 122, 129, 150c, 150d, etc.),
     phosphate additives (e.g. pentasodium triphosphate, sodium phosphate), hydrolyzed
     vegetable/groundnut/soy protein.
   For anything not on this list, apply the general rules in 6 above.

8. IF THE INPUT IS UNCLEAR, DO NOT GUESS. If the text is cut off mid-list, too blurry or
   garbled to confidently read, or fewer than 2 ingredient names can be read with
   confidence, set needs_rescan to true with a short, specific reason describing what
   couldn't be read. Do not invent or complete the rest of the list. The app will ask the
   person to rescan the ingredients panel.

9. NO MEMORY. Treat every request as the first and only one. Do not reference or assume
   anything from a previous scan.

10. ALWAYS INCLUDE THIS DISCLAIMER, VERBATIM, IN THE disclaimer FIELD:
    "Informational only — not medical or legal advice. Always check the physical label,
    as ingredients can change between batches."

OUTPUT FORMAT
Return ONLY valid JSON. No markdown code fences, no preamble, no extra text before or
after. Match this schema exactly:

{
  "needs_rescan": boolean,
  "rescan_reason": string or null,
  "product_hint": string or null,
  "ingredients": [
    {
      "name": string,
      "code": string or null,
      "category": "GOOD" | "NEUTRAL" | "FLAGGED" | "UNCLASSIFIED",
      "reason": string
    }
  ],
  "tally": { "good": number, "neutral": number, "flagged": number, "unclassified": number },
  "disclaimer": string
}`;
'@ | Set-Content -Path "lib/masterPrompt.ts" -Encoding UTF8

# app/api/scan/route.ts
@'
import { NextRequest, NextResponse } from "next/server";
import { MASTER_PROMPT } from "@/lib/masterPrompt";

export const runtime = "nodejs";

const MODEL = "llama-3.2-11b-vision-preview";

function extractJson(raw: string) {
  const cleaned = raw.trim().replace(/^```json\s*/i, "").replace(/^```\s*/, "").replace(/```$/, "");
  return JSON.parse(cleaned);
}

export async function POST(req: NextRequest) {
  try {
    const { image, text } = await req.json();

    if (!image && !text) {
      return NextResponse.json({ error: "No image or text provided" }, { status: 400 });
    }

    const userContent: any[] = [];
    if (text) userContent.push({ type: "text", text });
    if (image) userContent.push({ type: "image_url", image_url: { url: image } });
    if (userContent.length === 0) userContent.push({ type: "text", text: "" });

    const groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${process.env.GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          { role: "system", content: MASTER_PROMPT },
          { role: "user", content: userContent },
        ],
        temperature: 0,
        max_tokens: 4096,
      }),
    });

    if (!groqRes.ok) {
      const errText = await groqRes.text();
      console.error("Groq API error:", errText);
      return NextResponse.json(
        {
          needs_rescan: true,
          rescan_reason: "Scan service temporarily unavailable. Please try again.",
          product_hint: null,
          ingredients: [],
          tally: { good: 0, neutral: 0, flagged: 0, unclassified: 0 },
          disclaimer:
            "Informational only — not medical or legal advice. Always check the physical label, as ingredients can change between batches.",
        },
        { status: 200 }
      );
    }

    const data = await groqRes.json();
    const rawContent = data.choices?.[0]?.message?.content ?? "";

    let parsed;
    try {
      parsed = extractJson(rawContent);
    } catch {
      return NextResponse.json({
        needs_rescan: true,
        rescan_reason: "Could not read the label clearly. Please rescan.",
        product_hint: null,
        ingredients: [],
        tally: { good: 0, neutral: 0, flagged: 0, unclassified: 0 },
        disclaimer:
          "Informational only — not medical or legal advice. Always check the physical label, as ingredients can change between batches.",
      });
    }

    return NextResponse.json(parsed);
  } catch (err) {
    console.error(err);
    return NextResponse.json({ error: "Server error" }, { status: 500 });
  }
}
'@ | Set-Content -Path "app/api/scan/route.ts" -Encoding UTF8

# components/CameraCapture.tsx
@'
"use client";
import { useRef, useState, useEffect, useCallback } from "react";

export default function CameraCapture({ onCapture }: { onCapture: (base64: string) => void }) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  const stopStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
  }, []);

  const startCamera = useCallback(async () => {
    setError(null);
    setReady(false);
    stopStream();

    if (!navigator.mediaDevices?.getUserMedia) {
      setError("Camera not supported in this browser. Use upload instead.");
      return;
    }

    try {
      const stream = await navigator.mediaDevices
        .getUserMedia({ video: { facingMode: { ideal: "environment" } }, audio: false })
        .catch(() => navigator.mediaDevices.getUserMedia({ video: true, audio: false }));

      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
        setReady(true);
      }
    } catch (err: any) {
      if (err.name === "NotAllowedError") setError("Camera permission denied. Allow camera access and reload.");
      else if (err.name === "NotFoundError") setError("No camera found on this device.");
      else setError("Could not access camera.");
    }
  }, [stopStream]);

  useEffect(() => {
    startCamera();
    return () => stopStream();
  }, [startCamera, stopStream]);

  const capture = () => {
    if (!videoRef.current || !canvasRef.current) return;
    const video = videoRef.current;
    const canvas = canvasRef.current;
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    const ctx = canvas.getContext("2d");
    ctx?.drawImage(video, 0, 0);
    onCapture(canvas.toDataURL("image/jpeg", 0.9));
    stopStream();
  };

  return (
    <div style={{ maxWidth: 480, margin: "0 auto" }}>
      {error ? (
        <div>
          <p style={{ color: "#b00020" }}>{error}</p>
          <label style={{ display: "block", padding: 12, border: "1px dashed #999", textAlign: "center", cursor: "pointer" }}>
            Tap to upload a photo instead
            <input
              type="file"
              accept="image/*"
              capture="environment"
              style={{ display: "none" }}
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (!file) return;
                const reader = new FileReader();
                reader.onload = () => onCapture(reader.result as string);
                reader.readAsDataURL(file);
              }}
            />
          </label>
          <button onClick={startCamera} style={{ marginTop: 8 }}>Retry camera</button>
        </div>
      ) : (
        <>
          <video ref={videoRef} playsInline muted style={{ width: "100%", borderRadius: 8, background: "#000" }} />
          <button disabled={!ready} onClick={capture} style={{ marginTop: 8, width: "100%", padding: 12 }}>
            {ready ? "Capture" : "Starting camera..."}
          </button>
        </>
      )}
      <canvas ref={canvasRef} style={{ display: "none" }} />
    </div>
  );
}
'@ | Set-Content -Path "components/CameraCapture.tsx" -Encoding UTF8

# components/ResultView.tsx
@'
export default function ResultView({ result }: { result: any }) {
  if (!result) return null;

  if (result.needs_rescan) {
    return (
      <div style={{ background: "#fff3cd", padding: 16, borderRadius: 8, marginTop: 16 }}>
        ⚠️ {result.rescan_reason || "Could not read the label clearly."} — please rescan.
      </div>
    );
  }

  const groups: Record<string, any[]> = { FLAGGED: [], UNCLASSIFIED: [], NEUTRAL: [], GOOD: [] };
  (result.ingredients || []).forEach((i: any) => groups[i.category]?.push(i));

  const colors: Record<string, string> = {
    FLAGGED: "#f8d7da",
    UNCLASSIFIED: "#e2e3e5",
    NEUTRAL: "#fff3cd",
    GOOD: "#d4edda",
  };

  return (
    <div style={{ marginTop: 16 }}>
      {result.product_hint && <h3>{result.product_hint}</h3>}
      <div style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        <span>✅ {result.tally?.good ?? 0}</span>
        <span>➖ {result.tally?.neutral ?? 0}</span>
        <span>🚩 {result.tally?.flagged ?? 0}</span>
        <span>❓ {result.tally?.unclassified ?? 0}</span>
      </div>

      {Object.entries(groups).map(([cat, items]) =>
        items.length ? (
          <section key={cat} style={{ marginBottom: 12 }}>
            <h4>{cat} ({items.length})</h4>
            <ul style={{ padding: 0, listStyle: "none" }}>
              {items.map((ing, idx) => (
                <li key={idx} style={{ background: colors[cat], padding: 8, borderRadius: 6, marginBottom: 6 }}>
                  <strong>{ing.name}</strong>{ing.code ? ` (${ing.code})` : ""} — {ing.reason}
                </li>
              ))}
            </ul>
          </section>
        ) : null
      )}

      <p style={{ fontSize: 12, color: "#666", marginTop: 16 }}>{result.disclaimer}</p>
    </div>
  );
}
'@ | Set-Content -Path "components/ResultView.tsx" -Encoding UTF8

# app/page.tsx
@'
"use client";
import { useState } from "react";
import CameraCapture from "@/components/CameraCapture";
import ResultView from "@/components/ResultView";

export default function Home() {
  const [mode, setMode] = useState<"camera" | "text">("camera");
  const [manualText, setManualText] = useState("");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<any>(null);

  async function scan(payload: { image?: string; text?: string }) {
    setLoading(true);
    setResult(null);
    try {
      const res = await fetch("/api/scan", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      setResult(await res.json());
    } catch {
      setResult({ needs_rescan: true, rescan_reason: "Network error. Try again." });
    } finally {
      setLoading(false);
    }
  }

  return (
    <main style={{ maxWidth: 480, margin: "0 auto", padding: 16, fontFamily: "system-ui" }}>
      <h1 style={{ fontSize: 20 }}>Ingredient Lens</h1>

      <div style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        <button onClick={() => { setMode("camera"); setResult(null); }} disabled={mode === "camera"}>Camera</button>
        <button onClick={() => { setMode("text"); setResult(null); }} disabled={mode === "text"}>Type / Paste</button>
      </div>

      {mode === "camera" && !loading && !result && (
        <CameraCapture onCapture={(image) => scan({ image })} />
      )}

      {mode === "text" && !loading && !result && (
        <div>
          <textarea
            rows={6}
            style={{ width: "100%" }}
            placeholder="Paste ingredient list here..."
            value={manualText}
            onChange={(e) => setManualText(e.target.value)}
          />
          <button onClick={() => scan({ text: manualText })} disabled={!manualText.trim()}>
            Scan
          </button>
        </div>
      )}

      {loading && <p>Scanning...</p>}

      {result && (
        <>
          <ResultView result={result} />
          <button style={{ marginTop: 16 }} onClick={() => { setResult(null); setManualText(""); }}>
            Scan another
          </button>
        </>
      )}
    </main>
  );
}
'@ | Set-Content -Path "app/page.tsx" -Encoding UTF8

# app/layout.tsx
@'
export const metadata = {
  title: "Ingredient Lens",
  description: "Scan ingredient labels for transparency",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
'@ | Set-Content -Path "app/layout.tsx" -Encoding UTF8

# app/settings/page.tsx
@'
export default function Settings() {
  return (
    <main style={{ maxWidth: 480, margin: "0 auto", padding: 16, fontFamily: "system-ui" }}>
      <h1>Settings</h1>
      <p>Ingredient Lens does not store any scans or personal data.</p>
      <p>All results are informational only — not medical or legal advice.</p>
    </main>
  );
}
'@ | Set-Content -Path "app/settings/page.tsx" -Encoding UTF8

Write-Host ""
Write-Host "Project created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. npm install"
Write-Host "2. Copy-Item .env.local.example .env.local   (then paste your Groq API key inside)"
Write-Host "3. npm run dev"
Write-Host "4. code ."