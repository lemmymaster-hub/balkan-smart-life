import {Timestamp, getFirestore} from "firebase-admin/firestore";

const MAX_REQUESTS_PER_MINUTE = 12;
const MAX_REQUESTS_PER_DAY = 250;
const MINUTE_MS = 60_000;

export class RateLimitError extends Error {
  constructor(readonly retryAfterSeconds: number) {
    super("Previše BSL AI zahtjeva.");
    this.name = "RateLimitError";
  }
}

interface RateLimitData {
  minuteWindowStart?: number;
  minuteCount?: number;
  dayKey?: string;
  dayCount?: number;
}

export async function enforceRateLimit(
  uid: string,
  now = Date.now(),
): Promise<void> {
  const firestore = getFirestore();
  const reference = firestore.collection("bsl_ai_rate_limits").doc(uid);
  const dayKey = new Date(now).toISOString().slice(0, 10);

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = (snapshot.data() ?? {}) as RateLimitData;
    const sameMinute =
      typeof data.minuteWindowStart === "number" &&
      now - data.minuteWindowStart < MINUTE_MS;
    const minuteWindowStart = sameMinute
      ? data.minuteWindowStart!
      : now;
    const minuteCount = sameMinute ? (data.minuteCount ?? 0) + 1 : 1;
    const sameDay = data.dayKey === dayKey;
    const dayCount = sameDay ? (data.dayCount ?? 0) + 1 : 1;

    if (minuteCount > MAX_REQUESTS_PER_MINUTE) {
      const retryAfter = Math.max(
        1,
        Math.ceil(
          (minuteWindowStart + MINUTE_MS - now) / 1000,
        ),
      );
      throw new RateLimitError(retryAfter);
    }

    if (dayCount > MAX_REQUESTS_PER_DAY) {
      throw new RateLimitError(3600);
    }

    transaction.set(
      reference,
      {
        minuteWindowStart,
        minuteCount,
        dayKey,
        dayCount,
        updatedAt: Timestamp.fromMillis(now),
        expiresAt: Timestamp.fromMillis(now + 3 * 24 * 60 * 60 * 1000),
      },
      {merge: true},
    );
  });
}
