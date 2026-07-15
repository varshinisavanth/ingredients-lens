import { NextRequest, NextResponse } from "next/server";
import { MASTER_PROMPT } from "@/lib/masterPrompt";

export const runtime = "nodejs";

const MODEL = "meta-llama/llama-4-scout-17b-16e-instruct";

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
            "Informational only â€” not medical or legal advice. Always check the physical label, as ingredients can change between batches.",
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
          "Informational only â€” not medical or legal advice. Always check the physical label, as ingredients can change between batches.",
      });
    }

    return NextResponse.json(parsed);
  } catch (err) {
    console.error(err);
    return NextResponse.json({ error: "Server error" }, { status: 500 });
  }
}
