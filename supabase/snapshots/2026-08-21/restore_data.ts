const supabaseUrl = Deno.env.get("SUPABASE_URL")?.replace(/\/$/, "");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error(
    "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before restoring.",
  );
}

type Manifest = {
  tables: Record<string, { rows: number; files: string[] }>;
};

const manifestUrl = new URL("./data/manifest.json", import.meta.url);
const manifest = JSON.parse(
  await Deno.readTextFile(manifestUrl),
) as Manifest;

const restoreOrder = [
  { table: "bsl_banks", conflict: "bank_id" },
  { table: "bsl_atm_locations", conflict: "location_id" },
  { table: "bsl_atm_devices", conflict: "device_id" },
  { table: "bsl_atm_sources", conflict: "source_id" },
  { table: "bsl_osm_atm_candidates", conflict: "osm_type,osm_id" },
] as const;

for (const spec of restoreOrder) {
  const entry = manifest.tables[spec.table];
  if (!entry) throw new Error(`Missing manifest entry for ${spec.table}`);

  let restored = 0;
  for (const file of entry.files) {
    const fileUrl = new URL(`./data/${file}`, import.meta.url);
    const rows = JSON.parse(
      await Deno.readTextFile(fileUrl),
    ) as Record<string, unknown>[];

    for (let offset = 0; offset < rows.length; offset += 200) {
      const batch = rows.slice(offset, offset + 200);
      const endpoint = new URL(
        `/rest/v1/${spec.table}`,
        supabaseUrl,
      );
      endpoint.searchParams.set("on_conflict", spec.conflict);

      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Content-Profile": "public",
          "apikey": serviceRoleKey,
          "Authorization": `Bearer ${serviceRoleKey}`,
          "Prefer": "resolution=merge-duplicates,return=minimal",
        },
        body: JSON.stringify(batch),
      });

      if (!response.ok) {
        throw new Error(
          `${spec.table} restore failed: HTTP ${response.status} ${await response.text()}`,
        );
      }
      restored += batch.length;
    }
  }

  if (restored !== entry.rows) {
    throw new Error(
      `${spec.table}: restored ${restored}, expected ${entry.rows}`,
    );
  }

  console.log(`${spec.table}: restored ${restored} rows`);
}
