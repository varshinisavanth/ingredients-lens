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
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      const data = await res.json();
      setResult(data);
    } catch (e) {
      setResult({
        needs_rescan: true,
        rescan_reason: "Something went wrong. Please try again.",
      });
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="container">
      <section className="hero">
        <div>
          <h1 className="title">
            Ingredient
            <br />
            Lens
          </h1>

          <p className="subtitle">
            Scan food ingredients instantly using AI.
          </p>
        </div>

        <div className="logo">
          🥗
        </div>
      </section>

      <div className="card">

        <div className="tabs">

          <button
            className={`tab ${mode === "camera" ? "active" : ""}`}
            onClick={() => {
              setMode("camera");
              setResult(null);
            }}
          >
            📷 Camera
          </button>

          <button
            className={`tab ${mode === "text" ? "active" : ""}`}
            onClick={() => {
              setMode("text");
              setResult(null);
            }}
          >
            📝 Paste Ingredients
          </button>

        </div>

        {mode === "camera" && !loading && !result && (
          <CameraCapture
            onCapture={(image) => scan({ image })}
          />
        )}

        {mode === "text" && !loading && !result && (
          <>
            <textarea
              placeholder="Paste ingredient list here..."
              value={manualText}
              onChange={(e) =>
                setManualText(e.target.value)
              }
            />

            <button
              className="scanButton"
              onClick={() => scan({ text: manualText })}
            >
              Scan Ingredients
            </button>
          </>
        )}

        {loading && (

          <div
            style={{
              textAlign: "center",
              padding: "70px 0",
            }}
          >

            <div
              style={{
                width: 70,
                height: 70,
                borderRadius: "50%",
                border: "6px solid #ddd",
                borderTop: "6px solid #31b44b",
                margin: "auto",
                animation: "spin 1s linear infinite",
              }}
            />

            <h2
              style={{
                marginTop: 25,
              }}
            >
              AI is scanning ingredients...
            </h2>

            <p
              style={{
                color: "#777",
                marginTop: 8,
              }}
            >
              This usually takes 2–5 seconds.
            </p>

          </div>
        )}

        {result && (

          <>

            {!result.needs_rescan && (

              <div className="score">

                <div>

                  <h2>
                    Ingredient Summary
                  </h2>

                  <p
                    style={{
                      marginTop: 10,
                      color: "#666",
                    }}
                  >
                    AI classified every ingredient individually.
                  </p>

                </div>

                <div className="scoreCircle">

                  {
  Math.max(
    0,
    Math.min(
      100,
      Math.round(
        (result.tally.good * 100) /
          (result.ingredients.length || 1)
      )
    )
  )
}

                </div>

              </div>

            )}

            <ResultView result={result} />

            <button
              className="scanButton"
              style={{
                marginTop: 30,
              }}
              onClick={() => {
                setResult(null);
                setManualText("");
              }}
            >
              Scan Another Product
            </button>

          </>

        )}

      </div>

      <div className="footer">

        Informational only — not medical or legal advice.

      </div>

    </main>
  );
}