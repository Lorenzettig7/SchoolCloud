import { useEffect } from "react";
import { useNavigate } from "react-router-dom";

const CallbackPage = () => {
  const navigate = useNavigate();

  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const code = urlParams.get("code");

    if (!code) {
      console.error("Missing auth code in URL");
      navigate("/login");
      return;
    }

    async function fetchTokens() {
      const clientId = "4cddgb64bfu2au7ce5t9fqgtjp";
      const redirectUri = "http://localhost:3000/callback";
      const cognitoDomain = "https://schoolcloud-dev.auth.us-east-1.amazoncognito.com";

      const body = new URLSearchParams({
        grant_type: "authorization_code",
        client_id: clientId,
        code,
        redirect_uri: redirectUri,
      });

      try {
        const res = await fetch(`${cognitoDomain}/oauth2/token`, {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: body.toString(),
        });

        if (!res.ok) throw new Error("Token exchange failed");

        const tokens = await res.json();
        console.log("Tokens:", tokens);

        localStorage.setItem("id_token", tokens.id_token);
        localStorage.setItem("access_token", tokens.access_token);

        navigate("/");
      } catch (err) {
        console.error(err);
        navigate("/login");
      }
    }

    fetchTokens();
  }, [navigate]);

  return <p>Processing login...</p>;
};

export default CallbackPage;
