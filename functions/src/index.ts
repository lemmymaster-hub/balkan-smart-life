import {randomUUID} from "node:crypto";

import {initializeApp} from "firebase-admin/app";
import {logger} from "firebase-functions";
import {
  defineBoolean,
  defineSecret,
  defineString,
} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";

import {
  RequestValidationError,
  parseClientRequest,
} from "./ai/contract";
import {NvidiaServiceError, askNvidia} from "./ai/nvidia";
import {
  AuthenticationError,
  verifyFirebaseApp,
  verifyFirebaseUser,
} from "./security/requestSecurity";
import {RateLimitError, enforceRateLimit} from "./security/rateLimit";

initializeApp();

const nvidiaApiKey = defineSecret("NVIDIA_API_KEY");
const nvidiaModel = defineString("NVIDIA_MODEL", {
  default: "qwen/qwen3-next-80b-a3b-instruct",
});
const requireAppCheck = defineBoolean("BSL_REQUIRE_APP_CHECK", {
  default: true,
});

export const bslAiAsk = onRequest(
  {
    region: "europe-west1",
    timeoutSeconds: 30,
    memory: "256MiB",
    minInstances: 0,
    maxInstances: 10,
    concurrency: 20,
    cors: true,
    secrets: [nvidiaApiKey],
  },
  async (request, response) => {
    const requestId = randomUUID();

    response.set({
      "Cache-Control": "no-store",
      "Content-Type": "application/json; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
      "X-Request-ID": requestId,
    });

    if (request.method !== "POST") {
      response.status(405).json({
        error: "method_not_allowed",
        request_id: requestId,
      });
      return;
    }

    try {
      const uid = await verifyFirebaseUser(request);
      await verifyFirebaseApp(request, requireAppCheck.value());
      await enforceRateLimit(uid);

      const input = parseClientRequest(request.body);
      const result = await askNvidia({
        apiKey: nvidiaApiKey.value(),
        model: nvidiaModel.value(),
        request: input,
        requestId,
      });

      logger.info("BSL AI request completed", {
        requestId,
        uid,
        action: result.action?.type ?? "none",
        city: result.city,
      });
      response.status(200).json(result);
    } catch (error) {
      if (error instanceof AuthenticationError) {
        response.status(error.statusCode).json({
          error: "authentication_failed",
          message: error.message,
          request_id: requestId,
        });
        return;
      }

      if (error instanceof RateLimitError) {
        response.set("Retry-After", error.retryAfterSeconds.toString());
        response.status(429).json({
          error: "rate_limited",
          message: "Previše zahtjeva. Pokušaj ponovo kasnije.",
          request_id: requestId,
        });
        return;
      }

      if (error instanceof RequestValidationError) {
        response.status(400).json({
          error: "invalid_request",
          message: error.message,
          request_id: requestId,
        });
        return;
      }

      if (error instanceof NvidiaServiceError) {
        logger.error("NVIDIA API request failed", {
          requestId,
          statusCode: error.statusCode,
          message: error.message,
        });
        response.status(502).json({
          error: "ai_provider_unavailable",
          message: "BSL AI model trenutno nije dostupan.",
          request_id: requestId,
        });
        return;
      }

      logger.error("Unexpected BSL AI failure", {requestId, error});
      response.status(500).json({
        error: "internal_error",
        message: "BSL AI servis trenutno nije dostupan.",
        request_id: requestId,
      });
    }
  },
);
