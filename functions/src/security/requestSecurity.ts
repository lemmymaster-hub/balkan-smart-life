import {getAppCheck} from "firebase-admin/app-check";
import {getAuth} from "firebase-admin/auth";
import {Request} from "firebase-functions/v2/https";

export class AuthenticationError extends Error {
  constructor(
    message: string,
    readonly statusCode: 401 | 403,
  ) {
    super(message);
    this.name = "AuthenticationError";
  }
}

export async function verifyFirebaseUser(request: Request): Promise<string> {
  const authorization = request.header("authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(authorization);
  const token = match?.[1]?.trim();
  if (token == null || token.length === 0) {
    throw new AuthenticationError("Firebase prijava nedostaje.", 401);
  }

  try {
    const decoded = await getAuth().verifyIdToken(token, true);
    return decoded.uid;
  } catch {
    throw new AuthenticationError("Firebase prijava nije važeća.", 401);
  }
}

export async function verifyFirebaseApp(
  request: Request,
  required: boolean,
): Promise<void> {
  if (!required) return;

  const token = request.header("x-firebase-appcheck")?.trim();
  if (token == null || token.length === 0) {
    throw new AuthenticationError("App Check token nedostaje.", 403);
  }

  try {
    await getAppCheck().verifyToken(token);
  } catch {
    throw new AuthenticationError("App Check token nije važeći.", 403);
  }
}
