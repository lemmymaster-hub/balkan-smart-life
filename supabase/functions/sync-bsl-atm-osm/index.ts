import { createClient } from "npm:@supabase/supabase-js@2.112.4";

const ENDPOINTS = [
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
  "https://lz4.overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
  "https://z.overpass-api.de/api/interpreter",
  "https://overpass-api.de/api/interpreter",
  "https://overpass.private.coffee/api/interpreter",
];

const BOXES = [
  [44.0, 15.5, 45.4, 17.7],
  [44.0, 17.7, 45.4, 19.8],
  [42.4, 15.5, 44.0, 17.7],
  [42.4, 17.7, 44.0, 19.8],
] as const;

const BANK_ALIASES: ReadonlyArray<readonly [string, readonly string[]]> = [
  ["addiko", ["addiko"]],
  ["asa_banka", ["asa banka", "asa"]],
  ["bbi", ["bbi", "bosna bank international"]],
  ["intesa", ["intesa", "intesa sanpaolo"]],
  ["kib", ["kib", "komercijalno investiciona"]],
  ["nlb", ["nlb"]],
  ["pbs", ["privredna banka sarajevo", "pbs"]],
  ["procredit", ["procredit", "pro credit"]],
  ["raiffeisen", ["raiffeisen"]],
  ["sparkasse", ["sparkasse"]],
  ["unicredit", ["unicredit", "uni credit"]],
  ["union", ["union banka", "union bank"]],
  ["ziraat", ["ziraat"]],
  ["atos", ["atos"]],
  ["bpsbl", ["postanska stedionica", "poštanska štedionica", "bps"]],
  ["mf", ["mf banka", "mf bank"]],
  ["nova", ["nova banka", "nova bank"]],
  ["nasa", ["nasa banka", "naša banka"]],
];

const REQUEST_TIMEOUT_MS = 70_000;
const MAX_RESPONSE_CHARACTERS = 10_000_000;
const MAX_SECTOR_ROWS = 5_000;
const MIN_SECTOR_ROWS = 10;
const SYNC_SECRET_PATTERN = /^[a-f0-9]{64}$/;

type OverpassElement = Record<string, unknown>;

type OverpassPayload = {
  elements?: OverpassElement[];
  remark?: unknown;
};

type OsmCandidate = {
  osm_type: string;
  osm_id: number;
  latitude: number;
  longitude: number;
  name: unknown;
  operator: unknown;
  brand: unknown;
  network: unknown;
  addr_city: unknown;
  addr_place: unknown;
  addr_street: unknown;
  addr_housenumber: unknown;
  bank_key: string | null;
  tags: Record<string, unknown>;
  imported_at: string;
  atm_confirmed: boolean;
};

function normalize(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function bankKey(tags: Record<string, unknown>): string | null {
  const haystack = normalize(
    [tags.operator, tags.brand, tags.name, tags.network].join(" "),
  );

  for (const [key, aliases] of BANK_ALIASES) {
    if (aliases.some((alias) => haystack.includes(normalize(alias)))) {
      return key;
    }
  }

  return null;
}

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const secretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  let key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

  if (secretKeys) {
    try {
      key = JSON.parse(secretKeys).default ?? key;
    } catch {
      // The legacy service-role environment variable remains the fallback.
    }
  }

  if (!url || !key) {
    throw new Error("Admin credentials unavailable");
  }

  return createClient(url, key, {
    auth: { persistSession: false },
    db: { schema: "api" },
  });
}

async function isAuthorized(
  request: Request,
  supabase: ReturnType<typeof adminClient>,
): Promise<boolean> {
  const secret = request.headers.get("x-bsl-sync-secret")?.trim() ?? "";
  if (!SYNC_SECRET_PATTERN.test(secret)) return false;

  const { data, error } = await supabase.rpc("bsl_verify_atm_sync_secret", {
    p_secret: secret,
  });

  if (error) {
    console.error("BSL ATM SYNC AUTH RPC ERROR", error.message);
    return false;
  }

  return data === true;
}

async function fetchBox(box: readonly number[]): Promise<OverpassPayload> {
  const query = `
[out:json][timeout:45];
nwr["amenity"~"^(atm|bank)$"](${box.join(",")});
out center tags;
`;
  let lastError: unknown;

  for (const endpoint of ENDPOINTS) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

    try {
      const response = await fetch(
        `${endpoint}?data=${encodeURIComponent(query)}`,
        {
          method: "GET",
          headers: {
            Accept: "application/json",
            "User-Agent": "BalkanSmartLife-ATM-Sync/3.0",
          },
          signal: controller.signal,
        },
      );

      if (!response.ok) {
        throw new Error(`${endpoint}: HTTP ${response.status}`);
      }

      const responseBody = await response.text();
      if (responseBody.length > MAX_RESPONSE_CHARACTERS) {
        throw new Error(`${endpoint}: response is unexpectedly large`);
      }

      const payload = JSON.parse(responseBody) as OverpassPayload;
      if (!Array.isArray(payload.elements)) {
        throw new Error(`${endpoint}: response has no element list`);
      }
      if (typeof payload.remark === "string" && payload.remark.trim()) {
        throw new Error(`${endpoint}: incomplete Overpass response`);
      }

      return payload;
    } catch (error) {
      lastError = error;
    } finally {
      clearTimeout(timer);
    }
  }

  throw lastError ?? new Error("No Overpass endpoint available");
}

function candidateFromElement(
  element: OverpassElement,
  importedAt: string,
): OsmCandidate | null {
  const osmType = String(element.type ?? "");
  const osmId = Number(element.id);
  const tags = element.tags && typeof element.tags === "object"
    ? (element.tags as Record<string, unknown>)
    : {};

  let latitude: number;
  let longitude: number;
  if (osmType === "node") {
    latitude = Number(element.lat);
    longitude = Number(element.lon);
  } else {
    const center = element.center && typeof element.center === "object"
      ? (element.center as Record<string, unknown>)
      : {};
    latitude = Number(center.lat);
    longitude = Number(center.lon);
  }

  if (
    !["node", "way", "relation"].includes(osmType) ||
    !Number.isSafeInteger(osmId) ||
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude)
  ) {
    return null;
  }

  const amenity = normalize(tags.amenity);
  const atmTag = normalize(tags.atm);
  const atmConfirmed = amenity === "atm" ||
    ["yes", "true", "1"].includes(atmTag);

  return {
    osm_type: osmType,
    osm_id: osmId,
    latitude,
    longitude,
    name: tags.name ?? null,
    operator: tags.operator ?? null,
    brand: tags.brand ?? null,
    network: tags.network ?? null,
    addr_city: tags["addr:city"] ?? null,
    addr_place: tags["addr:place"] ?? null,
    addr_street: tags["addr:street"] ?? null,
    addr_housenumber: tags["addr:housenumber"] ?? null,
    bank_key: bankKey(tags),
    tags,
    imported_at: importedAt,
    atm_confirmed: atmConfirmed,
  };
}

function jsonResponse(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "POST required" }, 405);
  }

  let supabase: ReturnType<typeof adminClient>;
  let stage = "parse_request";
  try {
    supabase = adminClient();
  } catch (error) {
    console.error("BSL ATM SYNC ADMIN CONFIG ERROR", error);
    return jsonResponse({ error: "Service unavailable" }, 503);
  }

  if (!(await isAuthorized(request, supabase))) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  try {
    const body = await request.json().catch(() => ({}));
    const bodyRecord = body && typeof body === "object"
      ? (body as Record<string, unknown>)
      : {};
    const sector = Number(
      bodyRecord.sector ?? Number.NaN,
    );

    if (!Number.isInteger(sector) || sector < 0 || sector >= BOXES.length) {
      return jsonResponse({ error: "sector must be 0..3" }, 400);
    }

    const startedAt = new Date().toISOString();
    let payload: OverpassPayload;
    if (bodyRecord.payload !== undefined) {
      stage = "parse_supplied_payload";
      if (
        !bodyRecord.payload || typeof bodyRecord.payload !== "object" ||
        Array.isArray(bodyRecord.payload)
      ) {
        throw new Error("payload must be an Overpass JSON object");
      }
      payload = bodyRecord.payload as OverpassPayload;
    } else {
      stage = "fetch_overpass";
      payload = await fetchBox(BOXES[sector]);
    }

    stage = "parse_overpass";
    if (!Array.isArray(payload.elements)) {
      throw new Error("Overpass payload has no element list");
    }
    if (typeof payload.remark === "string" && payload.remark.trim()) {
      throw new Error("Overpass payload reports an incomplete result");
    }
    if (JSON.stringify(payload).length > MAX_RESPONSE_CHARACTERS) {
      throw new Error("Overpass payload is unexpectedly large");
    }

    const candidatesById = new Map<string, OsmCandidate>();

    for (const element of payload.elements) {
      const candidate = candidateFromElement(element, startedAt);
      if (!candidate) continue;
      candidatesById.set(
        `${candidate.osm_type}:${candidate.osm_id}`,
        candidate,
      );
    }

    const rows = [...candidatesById.values()];
    if (rows.length < MIN_SECTOR_ROWS || rows.length > MAX_SECTOR_ROWS) {
      throw new Error(
        `Sector ${sector} returned an unsafe row count: ${rows.length}`,
      );
    }

    stage = "upsert_candidates";
    for (let index = 0; index < rows.length; index += 250) {
      const { error } = await supabase.rpc("bsl_upsert_osm_atm_candidates", {
        p_rows: rows.slice(index, index + 250),
      });
      if (error) throw new Error(`upsert: ${error.message}`);
    }

    const seen = rows.map((row) => ({
      osm_type: row.osm_type,
      osm_id: row.osm_id,
    }));
    stage = "finalize_sector";
    const { data: deactivated, error: finalizeError } = await supabase.rpc(
      "bsl_finalize_osm_atm_sector",
      {
        p_sector: sector,
        p_started_at: startedAt,
        p_seen: seen,
      },
    );
    if (finalizeError) {
      throw new Error(`finalize: ${finalizeError.message}`);
    }

    stage = "match_official_locations";
    const { data: matched, error: matchError } = await supabase.rpc(
      "bsl_match_osm_atms",
    );
    if (matchError) throw new Error(`match: ${matchError.message}`);

    return jsonResponse({
      ok: true,
      sector,
      candidates: rows.length,
      standaloneAtms: rows.filter(
        (row) => normalize(row.tags.amenity) === "atm",
      ).length,
      bankBranches: rows.filter(
        (row) => normalize(row.tags.amenity) === "bank",
      ).length,
      confirmedAtms: rows.filter((row) => row.atm_confirmed).length,
      deactivated,
      matched,
    });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    console.error("BSL ATM SECTOR SYNC ERROR", { stage, detail });
    return jsonResponse({ error: "ATM sync failed", stage, detail }, 502);
  }
});
