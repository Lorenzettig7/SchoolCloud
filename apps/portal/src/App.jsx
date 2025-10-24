import React from "react";
import SchoolCloudPortal from "./SchoolCloudPortal.jsx";

function ErrorBoundary({ children }) {
  const [err, setErr] = React.useState(null);

  React.useEffect(() => {
    const onError = (e) => setErr(e.error || e.message || String(e));
    const onRej = (e) => setErr(e.reason || String(e));
    window.addEventListener("error", onError);
    window.addEventListener("unhandledrejection", onRej);
    return () => {
      window.removeEventListener("error", onError);
      window.removeEventListener("unhandledrejection", onRej);
    };
  }, []);

  if (err) {
    return (
      <pre style={{ padding: 16, color: "red", whiteSpace: "pre-wrap" }}>
        {String(err)}
      </pre>
    );
  }
  return children;
}

export default function App() {
  return (
    <ErrorBoundary>
      <SchoolCloudPortal />
    </ErrorBoundary>
  );
}
