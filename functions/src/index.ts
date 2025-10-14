// index.ts — Firebase Functions v2 (clean)
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated, FirestoreEvent, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import { onDocumentWritten, Change, DocumentSnapshot } from "firebase-functions/v2/firestore";
import { setGlobalOptions } from "firebase-functions/v2/options";
import * as admin from "firebase-admin";
import nodemailer from "nodemailer";
import * as crypto from "crypto";

admin.initializeApp();
setGlobalOptions({ region: "asia-southeast1" });

/** ---------- ENV ---------- */
const smtpHost = process.env.SMTP_HOST!;
const smtpPort = Number(process.env.SMTP_PORT ?? "465");
const smtpSecure = String(process.env.SMTP_SECURE ?? "true") === "true";
const smtpUser = process.env.SMTP_USER!;
const smtpPass = process.env.SMTP_PASS!;
const appName = process.env.APP_NAME ?? "DonationSwap";

/** ---------- Mailer ---------- */
const transporter = nodemailer.createTransport({
  host: smtpHost, port: smtpPort, secure: smtpSecure,
  auth: { user: smtpUser, pass: smtpPass },
});

/** ---------- Helpers ---------- */
function hashCode(code: string) { return crypto.createHash("sha256").update(code).digest("hex"); }
function randomOtp(len = 6) { return Array.from({length: len}, () => Math.floor(Math.random()*10)).join(""); }
const OTP_TTL_SEC = 5 * 60;
const TOKEN_TTL_SEC = 5 * 60;

/** (1) sendOtp */
export const sendOtp = onCall(async (req) => {
  const email = String(req.data?.email ?? "").trim().toLowerCase();
  if (!email || !email.includes("@")) throw new HttpsError("invalid-argument", "Invalid email");

  const otp = randomOtp(6);
  const otpHash = hashCode(otp);
  const now = admin.firestore.Timestamp.now();
  const expires = admin.firestore.Timestamp.fromMillis(now.toMillis() + OTP_TTL_SEC * 1000);
  const db = admin.firestore();

  const userDoc = db.collection("otp_requests").doc(email);
  await userDoc.set({ email }, { merge: true });
  await userDoc.collection("codes").add({ otpHash, createdAt: now, expiresAt: expires, used: false });

  await transporter.sendMail({
    from: `"${appName}" <${smtpUser}>`,
    to: email,
    subject: "Your OTP Code",
    text: `Your OTP is ${otp}. It expires in 5 minutes.`,
    html: `<p>Your OTP is <b>${otp}</b>. It expires in 5 minutes.</p>`,
  });

  return { ok: true };
});

/** (2) verifyOtp */
export const verifyOtp = onCall(async (req) => {
  const email = String(req.data?.email ?? "").trim().toLowerCase();
  const code = String(req.data?.otp ?? "").trim();
  if (!email || !code) throw new HttpsError("invalid-argument", "Missing email or otp");

  const db = admin.firestore();
  const codeHash = hashCode(code);
  const q = await db.collection("otp_requests").doc(email).collection("codes")
    .where("otpHash", "==", codeHash).where("used", "==", false).limit(1).get();
  if (q.empty) throw new HttpsError("permission-denied", "Invalid code");

  const doc = q.docs[0];
  const data = doc.data();
  const now = admin.firestore.Timestamp.now();
  if (now.toMillis() > data.expiresAt.toMillis()) throw new HttpsError("deadline-exceeded", "Code expired");

  await doc.ref.update({ used: true, usedAt: now });

  const token = crypto.randomBytes(24).toString("hex");
  const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + TOKEN_TTL_SEC * 1000);
  await db.collection("password_reset_tokens").doc(token).set({ email, createdAt: now, expiresAt, used: false });

  return { ok: true, token };
});

/** (3) resetPassword */
export const resetPassword = onCall(async (req) => {
  const email = String(req.data?.email ?? "").trim().toLowerCase();
  const token = String(req.data?.token ?? "");
  const newPassword = String(req.data?.newPassword ?? "");
  if (!email || !token || newPassword.length < 6) throw new HttpsError("invalid-argument", "Missing fields");

  const db = admin.firestore();
  const ref = db.collection("password_reset_tokens").doc(token);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("permission-denied", "Invalid token");

  const payload = snap.data()!;
  const now = admin.firestore.Timestamp.now();
  if (payload.used) throw new HttpsError("permission-denied", "Token already used");
  if (payload.email !== email) throw new HttpsError("permission-denied", "Token/email mismatch");
  if (now.toMillis() > payload.expiresAt.toMillis()) throw new HttpsError("deadline-exceeded", "Token expired");

  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { password: newPassword });
  await ref.update({ used: true, usedAt: now });

  return { ok: true };
});

/** (4) onNewMessageSendPush (เดิมของคุณ) */
export const onNewMessageSendPush = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event: FirestoreEvent<QueryDocumentSnapshot | undefined>) => {
    const db = admin.firestore();
    const chatId = event.params.chatId as string;
    const snap = event.data;
    if (!snap) return;

    type Msg =
      | { from?: string; to?: string; text?: string; type?: "text" }
      | { from?: string; to?: string; type: "image"; imageUrl?: string; storagePath?: string }
      | { from?: string; type: "system"; text?: string };

    const msg = snap.data() as Msg;
    const senderId = msg.from;
    if (!senderId) return;

    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) return;
    const users: string[] = chatDoc.get("users") || [];
    if (!Array.isArray(users) || users.length === 0) return;

    let recipients: string[] = [];
    if ((msg as any).to) {
      const to = String((msg as any).to);
      recipients = users.includes(to) ? [to] : users.filter((u) => u !== senderId);
    } else {
      recipients = users.filter((u) => u !== senderId);
    }
    if (recipients.length === 0) return;

    const senderDoc = await db.collection("users").doc(senderId).get();
    const senderName = (senderDoc.exists && (senderDoc.get("displayName") as string)) || "ข้อความใหม่";

    let body = "ส่งข้อความถึงคุณ";
    if ((msg as any).type === "image") body = "📷 ส่งรูปภาพ";
    else if ((msg as any).type === "system") body = (msg as any).text || "แจ้งเตือนระบบ";
    else body = (msg as any).text || body;
    body = body.slice(0, 80);

    const userSnaps = await Promise.all(recipients.map((uid) => db.collection("users").doc(uid).get()));
    const tokens: string[] = [];
    userSnaps.forEach((u) => {
      if (!u.exists) return;
      const map = (u.get("fcmTokens") as Record<string, boolean>) || {};
      tokens.push(...Object.keys(map));
    });
    if (tokens.length === 0) return;

    const payload = {
      notification: { title: senderName, body },
      data: { type: "chat_message", chatId, senderId, messageId: event.params.messageId as string, click_action: "FLUTTER_NOTIFICATION_CLICK" },
    };

    for (let i = 0; i < tokens.length; i += 500) {
      await admin.messaging().sendEachForMulticast({ tokens: tokens.slice(i, i + 500), ...payload });
    }

    await db.collection("chats").doc(chatId).set(
      { lastText: body.startsWith("📷") ? "📷 Photo" : (msg as any).text || body, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
  }
);

/** (5) accumulateUserRatings (เดิมของคุณ) */
export const accumulateUserRatings = onDocumentWritten(
  "users/{uid}/ratings/{raterUid}",
  async (event: FirestoreEvent<Change<DocumentSnapshot> | undefined>) => {
    const db = admin.firestore();
    const uid = event.params.uid as string;
    const change = event.data;
    if (!change) return;

    let deltaCount = 0, deltaSum = 0;
    if (!change.before.exists && change.after.exists) {
      deltaCount = 1; deltaSum = (change.after.data()?.value ?? 0) as number;
    } else if (change.before.exists && !change.after.exists) {
      deltaCount = -1; deltaSum = -(change.before.data()?.value ?? 0) as number;
    } else if (change.before.exists && change.after.exists) {
      const oldVal = (change.before.data()?.value ?? 0) as number;
      const newVal = (change.after.data()?.value ?? 0) as number;
      deltaSum = newVal - oldVal;
    }

    const userRef = db.collection("users").doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      const beforeCount = (snap.get("ratingCount") ?? 0) as number;
      const beforeSum = (snap.get("ratingSum") ?? 0) as number;
      const afterCount = Math.max(0, beforeCount + deltaCount);
      const afterSum = Math.max(0, beforeSum + deltaSum);
      const afterAvg = afterCount > 0 ? afterSum / afterCount : 0;
      tx.set(userRef, { ratingCount: afterCount, ratingSum: afterSum, ratingAvg: afterAvg }, { merge: true });
    });
  }
);

/** (6) reviewVerification — v2 onCall */
export const reviewVerification = onCall(async (req) => {
  const { uid, action, reason } = (req.data ?? {}) as { uid?: string; action?: "approve" | "reject"; reason?: string };
  const authUid = req.auth?.uid;
  if (!authUid) throw new HttpsError("unauthenticated", "Sign-in required.");

  const db = admin.firestore();
  const me = await db.doc(`users/${authUid}`).get();
  if (!me.exists || me.data()?.role !== "admin") throw new HttpsError("permission-denied", "Admins only.");
  if (!uid || !action) throw new HttpsError("invalid-argument", "Invalid uid/action.");

  const verRef = db.doc(`verifications/${uid}`);
  const userRef = db.doc(`users/${uid}`);
  const verSnap = await verRef.get();
  if (!verSnap.exists) throw new HttpsError("not-found", "Verification not found.");

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  if (action === "approve") {
    batch.update(verRef, { status: "approved", reviewedBy: authUid, reviewedAt: now, reason: null });
    batch.update(userRef, { verified: true });
    batch.set(db.collection("auditLogs").doc(), { uid, action: "approve", by: authUid, at: now, note: null });
  } else {
    batch.update(verRef, { status: "rejected", reviewedBy: authUid, reviewedAt: now, reason: reason || "" });
    batch.update(userRef, { verified: false });
    batch.set(db.collection("auditLogs").doc(), { uid, action: "reject", by: authUid, at: now, note: reason || "" });
  }

  await batch.commit();
  return { ok: true };
});
