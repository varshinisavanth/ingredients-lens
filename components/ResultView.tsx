export default function ResultView({ result }: { result: any }) {
  if (!result) return null;

  if (result.needs_rescan) {
    return (
      <div
        style={{
          background: "#fff3cd",
          border: "2px solid #ffd54f",
          padding: 24,
          borderRadius: 18,
          marginTop: 25,
        }}
      >
        <h2 style={{ color: "#d97706", marginBottom: 10 }}>
          ⚠ Scan Failed
        </h2>

        <p>{result.rescan_reason}</p>
      </div>
    );
  }

  const good =
    result.ingredients?.filter((x: any) => x.category === "GOOD") || [];

  const neutral =
    result.ingredients?.filter((x: any) => x.category === "NEUTRAL") || [];

  const flagged =
    result.ingredients?.filter((x: any) => x.category === "FLAGGED") || [];

  const unknown =
    result.ingredients?.filter(
      (x: any) => x.category === "UNCLASSIFIED"
    ) || [];

  function Section(
    title: string,
    color: string,
    bg: string,
    items: any[]
  ) {
    if (!items.length) return null;

    return (
      <div style={{ marginTop: 35 }}>

        <h2
          style={{
            color,
            marginBottom: 18,
            fontSize: 24,
          }}
        >
          {title} ({items.length})
        </h2>

        {items.map((item: any, index: number) => (

          <div
            key={index}
            style={{
              background: bg,
              borderRadius: 18,
              padding: 18,
              marginBottom: 15,
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
            }}
          >
            <div>

              <div
                style={{
                  fontWeight: 700,
                  fontSize: 18,
                }}
              >
                {item.name}
              </div>

              <div
                style={{
                  color: "#666",
                  marginTop: 6,
                }}
              >
                {item.reason}
              </div>

            </div>

            <div
              style={{
                background: "white",
                padding: "8px 15px",
                borderRadius: 999,
                fontWeight: 700,
                color,
              }}
            >
              {item.category}
            </div>

          </div>

        ))}

      </div>
    );
  }

  return (
    <>

      <div
        style={{
          display: "grid",
          gridTemplateColumns:
            "repeat(auto-fit,minmax(150px,1fr))",
          gap: 18,
          marginTop: 30,
        }}
      >

        <Stat
          color="#16a34a"
          title="Good"
          value={good.length}
        />

        <Stat
          color="#ca8a04"
          title="Neutral"
          value={neutral.length}
        />

        <Stat
          color="#dc2626"
          title="Flagged"
          value={flagged.length}
        />

        <Stat
          color="#6b7280"
          title="Unknown"
          value={unknown.length}
        />

      </div>

      {Section(
        "🚩 Flagged Ingredients",
        "#dc2626",
        "#ffe5e5",
        flagged
      )}

      {Section(
        "🟡 Neutral Ingredients",
        "#ca8a04",
        "#fff8dc",
        neutral
      )}

      {Section(
        "🟢 Good Ingredients",
        "#16a34a",
        "#ebfaef",
        good
      )}

      {Section(
        "⚪ Unknown",
        "#666",
        "#f4f4f4",
        unknown
      )}

      <div
        style={{
          marginTop: 40,
          background: "#fafafa",
          padding: 20,
          borderRadius: 15,
          color: "#666",
          lineHeight: 1.6,
          fontSize: 14,
        }}
      >
        {result.disclaimer}
      </div>

    </>
  );
}

function Stat({
  color,
  title,
  value,
}: {
  color: string;
  title: string;
  value: number;
}) {
  return (
    <div
      style={{
        background: "white",
        borderRadius: 18,
        padding: 22,
        textAlign: "center",
        boxShadow:
          "0 8px 24px rgba(0,0,0,.08)",
      }}
    >
      <div
        style={{
          fontSize: 36,
          fontWeight: 800,
          color,
        }}
      >
        {value}
      </div>

      <div
        style={{
          marginTop: 8,
          color: "#666",
          fontWeight: 600,
        }}
      >
        {title}
      </div>
    </div>
  );
}