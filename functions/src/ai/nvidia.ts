import {
  BslAiClientRequest,
  BslAiResponse,
  extractJsonObject,
  sanitizeModelResponse,
} from "./contract";
import {buildNvidiaMessages} from "./prompt";

const NVIDIA_ENDPOINT =
  "https://integrate.api.nvidia.com/v1/chat/completions";

interface NvidiaChoice {
  message?: {
    content?: unknown;
  };
}

interface NvidiaCompletion {
  choices?: NvidiaChoice[];
}

export class NvidiaServiceError extends Error {
  constructor(
    message: string,
    readonly statusCode?: number,
  ) {
    super(message);
    this.name = "NvidiaServiceError";
  }
}

export async function askNvidia({
  apiKey,
  model,
  request,
  requestId,
  fetchImpl = fetch,
}: {
  apiKey: string;
  model: string;
  request: BslAiClientRequest;
  requestId: string;
  fetchImpl?: typeof fetch;
}): Promise<BslAiResponse> {
  const response = await fetchImpl(NVIDIA_ENDPOINT, {
    method: "POST",
    headers: {
      "Accept": "application/json",
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "X-Request-ID": requestId,
    },
    body: JSON.stringify({
      model,
      messages: buildNvidiaMessages(request),
      temperature: 0.1,
      top_p: 0.7,
      max_tokens: 700,
      stream: false,
    }),
    signal: AbortSignal.timeout(20_000),
  });

  if (!response.ok) {
    throw new NvidiaServiceError(
      `NVIDIA API je vratio HTTP ${response.status}.`,
      response.status,
    );
  }

  const completion = (await response.json()) as NvidiaCompletion;
  const content = completion.choices?.[0]?.message?.content;
  if (typeof content !== "string" || content.trim().length === 0) {
    throw new NvidiaServiceError("NVIDIA API nije vratio tekst odgovora.");
  }

  const decoded = extractJsonObject(content);
  return sanitizeModelResponse(decoded, request, requestId);
}
