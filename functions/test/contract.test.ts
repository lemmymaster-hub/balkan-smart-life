import {describe, expect, it} from "vitest";

import {
  extractJsonObject,
  parseClientRequest,
  sanitizeModelResponse,
} from "../src/ai/contract";
import {buildNvidiaMessages} from "../src/ai/prompt";

const requestWithLocation = parseClientRequest({
  question: "Nađi mi EL punjač blizu moje lokacije",
  city: "Sarajevo",
  locale: "bs",
  context: {
    city: "Sarajevo",
    locale: "bs",
    location: {latitude: 43.8563, longitude: 18.4131},
    supported_actions: [
      "open_parking",
      "open_ev_chargers",
      "open_weather",
      "open_wallet",
    ],
  },
});

describe("BSL AI contract", () => {
  it("prisiljava GPS semantiku i uklanja lažni geocoding query", () => {
    const response = sanitizeModelResponse(
      {
        answer: "Otvaram punjače.",
        city: "Sarajevo",
        grounded: true,
        sources: [{title: "Izmišljeni izvor"}],
        action: {
          type: "open_ev_chargers",
          parameters: {
            city: "Sarajevo",
            query: "aerodrom",
            select_nearest: false,
          },
        },
      },
      requestWithLocation,
      "request-1",
    );

    expect(response.action?.parameters.query).toBeUndefined();
    expect(response.action?.parameters.select_nearest).toBe(true);
    expect(response.action?.parameters.use_current_location).toBe(true);
    expect(response.grounded).toBe(false);
    expect(response.sources).toEqual([]);
  });

  it("odbacuje proizvoljnu ili nedozvoljenu akciju", () => {
    const response = sanitizeModelResponse(
      {
        answer: "Pokušavam otvoriti admin rutu.",
        action: {
          type: "delete_account",
          parameters: {route: "/admin"},
        },
      },
      requestWithLocation,
      "request-2",
    );

    expect(response.action).toBeUndefined();
  });

  it("ne dozvoljava GPS akciju bez GPS konteksta", () => {
    const request = parseClientRequest({
      question: "Nađi parking blizu mene",
      city: "Pale",
      context: {
        city: "Pale",
        location: null,
        supported_actions: ["open_parking"],
      },
    });
    const response = sanitizeModelResponse(
      {
        answer: "Otvaram parking.",
        action: {
          type: "open_parking",
          parameters: {
            city: "Pale",
            select_nearest: true,
            use_current_location: true,
          },
        },
      },
      request,
      "request-3",
    );

    expect(response.action).toBeUndefined();
  });

  it("čita JSON čak i kada ga model vrati u code fence bloku", () => {
    const value = extractJsonObject(
      "```json\n{\"answer\":\"U redu\",\"city\":\"Pale\"}\n```",
    );

    expect(value).toEqual({answer: "U redu", city: "Pale"});
  });

  it("ne šalje precizne GPS koordinate NVIDIA modelu", () => {
    const messages = buildNvidiaMessages(requestWithLocation);
    const userMessage = messages[1]?.content;
    expect(userMessage).toBeTypeOf("string");

    const payload = JSON.parse(userMessage!) as Record<string, unknown>;
    expect(payload.has_current_location).toBe(true);
    expect(userMessage).not.toContain("43.8563");
    expect(userMessage).not.toContain("18.4131");
  });
});
