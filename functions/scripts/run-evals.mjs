import {readFile} from "node:fs/promises";

const endpoint = process.env.BSL_AI_ENDPOINT?.trim();
const firebaseIdToken = process.env.FIREBASE_ID_TOKEN?.trim();
const appCheckToken = process.env.FIREBASE_APP_CHECK_TOKEN?.trim();

if (!endpoint || !firebaseIdToken || !appCheckToken) {
  console.error(
    "Postavi BSL_AI_ENDPOINT, FIREBASE_ID_TOKEN i " +
      "FIREBASE_APP_CHECK_TOKEN prije evaluacije.",
  );
  process.exit(2);
}

const cases = JSON.parse(
  await readFile(
    new URL("../evals/bsl_ai_eval_cases.json", import.meta.url),
    "utf8",
  ),
);

let failures = 0;

for (const testCase of cases) {
  const location = testCase.hasLocation
    ? {latitude: 43.8563, longitude: 18.4131}
    : null;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Accept": "application/json",
      "Authorization": `Bearer ${firebaseIdToken}`,
      "Content-Type": "application/json",
      "X-Firebase-AppCheck": appCheckToken,
    },
    body: JSON.stringify({
      question: testCase.question,
      city: testCase.city,
      locale: "bs",
      context: {
        city: testCase.city,
        locale: "bs",
        location,
        supported_actions: [
          "open_parking",
          "open_ev_chargers",
          "open_weather",
          "open_wallet",
        ],
      },
    }),
  });

  if (!response.ok) {
    failures += 1;
    console.error(
      `FAIL ${testCase.name}: HTTP ${response.status} ${await response.text()}`,
    );
    continue;
  }

  const answer = await response.json();
  const errors = validateExpectation(answer, testCase.expected);
  if (errors.length > 0) {
    failures += 1;
    console.error(`FAIL ${testCase.name}: ${errors.join("; ")}`);
    continue;
  }

  console.log(`PASS ${testCase.name}`);
}

if (failures > 0) {
  console.error(`${failures}/${cases.length} BSL AI evaluacija nije prošlo.`);
  process.exit(1);
}

console.log(`Sve BSL AI evaluacije su prošle (${cases.length}/${cases.length}).`);

function validateExpectation(answer, expected) {
  const errors = [];
  const action = answer?.action;
  const actualType = action?.type ?? null;

  if (actualType !== expected.actionType) {
    errors.push(`akcija ${actualType}, očekivano ${expected.actionType}`);
  }
  if (expected.city && answer?.city !== expected.city) {
    errors.push(`grad ${answer?.city}, očekivano ${expected.city}`);
  }
  if (
    Object.hasOwn(expected, "query") &&
    (action?.parameters?.query ?? null) !== expected.query
  ) {
    errors.push(
      `query ${action?.parameters?.query ?? null}, očekivano ${expected.query}`,
    );
  }
  if (
    expected.queryContains &&
    !normalize(action?.parameters?.query ?? "").includes(
      normalize(expected.queryContains),
    )
  ) {
    errors.push(`query ne sadrži ${expected.queryContains}`);
  }
  if (
    Object.hasOwn(expected, "useCurrentLocation") &&
    action?.parameters?.use_current_location !== expected.useCurrentLocation
  ) {
    errors.push(
      `use_current_location ${action?.parameters?.use_current_location}`,
    );
  }

  return errors;
}

function normalize(value) {
  return value
    .toLocaleLowerCase("bs")
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .replace(/đ/g, "dj")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}
