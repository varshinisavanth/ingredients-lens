"use client";

import { useRef, useState, useEffect, useCallback } from "react";

export default function CameraCapture({
  onCapture,
}: {
  onCapture: (base64: string) => void;
}) {
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
      setError("Camera not supported in this browser.");
      return;
    }

    try {
      const stream = await navigator.mediaDevices
        .getUserMedia({
          video: {
            facingMode: { ideal: "environment" },
          },
          audio: false,
        })
        .catch(() =>
          navigator.mediaDevices.getUserMedia({
            video: true,
            audio: false,
          })
        );

      streamRef.current = stream;

      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
        setReady(true);
      }
    } catch (err: any) {
      if (err.name === "NotAllowedError") {
        setError("Camera permission denied.");
      } else if (err.name === "NotFoundError") {
        setError("No camera found.");
      } else {
        setError("Could not access camera.");
      }
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
    <div className="cameraWrapper">
      {error ? (
        <div className="cameraError">
          <h3>{error}</h3>

          <label className="uploadFallback">
            📷 Tap to upload a photo instead

            <input
              type="file"
              accept="image/*"
              capture="environment"
              hidden
              onChange={(e) => {
                const file = e.target.files?.[0];

                if (!file) return;

                const reader = new FileReader();

                reader.onload = () =>
                  onCapture(reader.result as string);

                reader.readAsDataURL(file);
              }}
            />
          </label>

          <button
            className="retryButton"
            onClick={startCamera}
          >
            Retry Camera
          </button>
        </div>
      ) : (
        <>
          <video
            ref={videoRef}
            playsInline
            muted
            autoPlay
            className="cameraVideo"
          />

          <button
            disabled={!ready}
            onClick={capture}
            className="scanButton"
          >
            {ready ? "📸 Capture" : "Starting Camera..."}
          </button>
        </>
      )}

      <canvas
        ref={canvasRef}
        style={{ display: "none" }}
      />
    </div>
  );
}