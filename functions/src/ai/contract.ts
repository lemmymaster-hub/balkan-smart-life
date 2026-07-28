import {randomUUID} from "node:crypto";

export const BSL_ACTION_TYPES = [
  "open_parking",
  "open_ev_chargers",
  "open_weather",
  "open_wallet",
] as const;

export type BslActionType = (typeof BSL_ACTION_TYPES)[number];

const BSL_CITIES = [
  "Sarajevo",
  "Banja Luka",
  "Mostar",
  "Tuzla",
  "Zenica",
  "Bihać",
  "Trebinje",
  "Pale",
  "Istočno Sarajevo",
] as const;

export interface BslLocationContext {
  latitude: number;
  longitude: number;
}

export interface BslAiClientContext {
  city: string;
  locale: string;
  location: BslLocationContext | null;
  supportedActions: BslActionType[];
}

export interface BslAiClientRequest {
  question: string;
  city: string;
  locale: string;
  context: BslAiClientContext;
}

export interface BslAiAction {
  type: BslActionType;
  label: string;
  parameters: {
    city: string;
    query?: string;
    select_nearest?: boolean;
    use_current_location?: boolean;
  };
}

export interface BslAiResponse {
  answer: string;
  city: string;
  grounded: false;
  sources: [];
  request_id: string;
  action?: BslAiAction;
}

export class RequestValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "RequestValidationError";
  }
}

export function parseClientRequest(value: unknown): BslAiClientRequest {
  if (!isRecord(value)) {
    throw new RequestValidationError("Zahtjev mora biti JSON objekt.");
  }

  const question = cleanText(value.question, 500);
  if (question.length < 2) {
    throw new RequestValidationError("Pitanje je prekratko.");
  }

  const rawContext = isRecord(value.context) ? value.context : {};
  const city =
    canonicalCity(value.city) ??
    canonicalCity(rawContext.city) ??
    (() => {
      throw new RequestValidationError("Grad nije podržan.");
    })();
  const locale = sanitizeLocale(value.locale ?? rawContext.locale);
  const location = parseLocation(rawContext.location);
  const supportedActions = parseSupportedActions(
    rawContext.supported_actions,
  );

  return {
    question,
    city,
    locale,
    context: {
      city,
      locale,
      location,
      supportedActions,
    },
  };
}

export function sanitizeModelResponse(
  value: unknown,
  request: BslAiClientRequest,
  requestId: string = randomUUID(),
): BslAiResponse {
  const raw = isRecord(value) ? value : {};
  const answer =
    cleanText(raw.answer, 700) ||
    "Razumio sam upit, ali trenutno nemam dovoljno pouzdan odgovor.";
  const city = canonicalCity(raw.city) ?? request.city;
  const action = sanitizeAction(raw.action, request, city);

  return {
    answer,
    city,
    grounded: false,
    sources: [],
    request_id: requestId,
    ...(action == null ? {} : {action}),
  };
}

export function extractJsonObject(content: string): unknown {
  const trimmed = content
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "");

  try {
    return JSON.parse(trimmed);
  } catch {
    const candidate = firstBalancedJsonObject(trimmed);
    if (candidate == null) {
      throw new Error("NVIDIA odgovor ne sadrži ispravan JSON objekt.");
    }
    return JSON.parse(candidate);
  }
}

export function refersToCurrentLocation(value: string): boolean {
  const normalized = normalize(value);
  return CURRENT_LOCATION_PHRASES.some((phrase) =>
    ` ${normalized} `.includes(` ${phrase} `),
  );
}

function sanitizeAction(
  value: unknown,
  request: BslAiClientRequest,
  fallbackCity: string,
): BslAiAction | undefined {
  if (!isRecord(value)) return undefined;

  const type = parseActionType(value.type);
  if (
    type == null ||
    !request.context.supportedActions.includes(type)
  ) {
    return undefined;
  }

  const rawParameters = isRecord(value.parameters) ? value.parameters : {};
  const city = canonicalCity(rawParameters.city) ?? fallbackCity;
  const supportsPlaceSearch =
    type === "open_parking" || type === "open_ev_chargers";
  const askedForCurrentLocation = refersToCurrentLocation(request.question);
  const requestedCurrentLocation =
    rawParameters.use_current_location === true ||
    askedForCurrentLocation;
  const useCurrentLocation =
    supportsPlaceSearch &&
    requestedCurrentLocation &&
    request.context.location != null;

  if (
    supportsPlaceSearch &&
    requestedCurrentLocation &&
    request.context.location == null
  ) {
    return undefined;
  }

  const query = useCurrentLocation
    ? undefined
    : cleanOptionalText(rawParameters.query, 160);
  const selectNearest =
    supportsPlaceSearch && rawParameters.select_nearest === true;

  return {
    type,
    label: cleanText(value.label, 80) || defaultActionLabel(type),
    parameters: {
      city,
      ...(query == null ? {} : {query}),
      ...(supportsPlaceSearch
        ? {
            select_nearest: selectNearest || useCurrentLocation,
            use_current_location: useCurrentLocation,
          }
        : {}),
    },
  };
}

function parseSupportedActions(value: unknown): BslActionType[] {
  if (!Array.isArray(value)) return [...BSL_ACTION_TYPES];

  const parsed = value
    .map(parseActionType)
    .filter((item): item is BslActionType => item != null);
  return parsed.length === 0 ? [...BSL_ACTION_TYPES] : [...new Set(parsed)];
}

function parseActionType(value: unknown): BslActionType | undefined {
  const candidate = cleanText(value, 40);
  return BSL_ACTION_TYPES.find((type) => type === candidate);
}

function parseLocation(value: unknown): BslLocationContext | null {
  if (!isRecord(value)) return null;

  const latitude = toFiniteNumber(value.latitude);
  const longitude = toFiniteNumber(value.longitude);
  if (
    latitude == null ||
    longitude == null ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    return null;
  }

  return {latitude, longitude};
}

function canonicalCity(value: unknown): string | undefined {
  const candidate = normalize(cleanText(value, 60));
  return BSL_CITIES.find((city) => normalize(city) === candidate);
}

function sanitizeLocale(value: unknown): string {
  const candidate = cleanText(value, 10).toLowerCase();
  return ["bs", "hr", "sr", "en"].includes(candidate) ? candidate : "bs";
}

function defaultActionLabel(type: BslActionType): string {
  switch (type) {
    case "open_parking":
      return "Otvori Parkiraj.ba";
    case "open_ev_chargers":
      return "Otvori EL Punjače";
    case "open_weather":
      return "Otvori vremensku prognozu";
    case "open_wallet":
      return "Otvori BSL novčanik";
  }
}

function firstBalancedJsonObject(value: string): string | undefined {
  let start = -1;
  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = 0; index < value.length; index += 1) {
    const character = value[index];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (character === "\\") {
        escaped = true;
      } else if (character === "\"") {
        inString = false;
      }
      continue;
    }

    if (character === "\"") {
      inString = true;
      continue;
    }

    if (character === "{") {
      if (depth === 0) start = index;
      depth += 1;
      continue;
    }

    if (character === "}" && depth > 0) {
      depth -= 1;
      if (depth === 0 && start >= 0) {
        return value.slice(start, index + 1);
      }
    }
  }

  return undefined;
}

function cleanOptionalText(value: unknown, maxLength: number) {
  const cleaned = cleanText(value, maxLength);
  return cleaned.length === 0 ? undefined : cleaned;
}

function cleanText(value: unknown, maxLength: number): string {
  if (typeof value !== "string") return "";
  return value.replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function toFiniteNumber(value: unknown): number | undefined {
  if (typeof value !== "number" || !Number.isFinite(value)) return undefined;
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value != null && !Array.isArray(value);
}

function normalize(value: string): string {
  return value
    .trim()
    .toLocaleLowerCase("bs")
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .replace(/đ/g, "dj")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

const CURRENT_LOCATION_PHRASES = [
  "moja lokacija",
  "moje lokacije",
  "mojoj lokaciji",
  "trenutna lokacija",
  "trenutne lokacije",
  "trenutnoj lokaciji",
  "gdje sam",
  "oko mene",
  "blizu mene",
  "u blizini mene",
];
