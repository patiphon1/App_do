// index.ts — Firebase Functions v2

import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import nodemailer from "nodemailer";
import * as crypto from "crypto";

admin.initializeApp();

// ---------- ENV ----------
const smtpHost = process.env.SMTP_HOST!;
const smtpPort = Number(process.env.SMTP_PORT ?? "465");
const smtpSecure = String(process.env.SMTP_SECURE ?? "true") === "true";
const smtpUser = process.env.SMTP_USER!;
const smtpPass = process.env.SMTP_PASS!;
const appName  = process.env.APP_NAME ?? "DonationSwap";

// ---------- Mailer ----------
const transporter = nodemailer.createTransport({
  host: smtpHost,
  port: smtpPort,
  secure: smtpSecure,
  auth: { user: smtpUser, pass: smtpPass },
});

// ---------- Helpers ----------
function hashCode(code: string): string {
  return crypto.createHash("sha256").update(code).digest("hex");
}
function randomOtp(len = 6): string {
  let s = "";
  for (let i = 0; i < len; i++) s += Math.floor(Math.random() * 10).toString();
  return s;
}

const OTP_TTL_SEC   = 5 * 60; // 5 นาที
const TOKEN_TTL_SEC = 5 * 60; // 5 นาที

// =====================================
// (1) ส่ง OTP ไปอีเมล — v2 onCall
// =====================================
export const sendOtp = onCall(async (request) => {
  const email = String(request.data?.email ?? "").trim().toLowerCase();
  if (!email || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "Invalid email");
  }

  const otp      = randomOtp(6);
  const otpHash  = hashCode(otp);
  const now      = admin.firestore.Timestamp.now();
  const expires  = admin.firestore.Timestamp.fromMillis(now.toMillis() + OTP_TTL_SEC * 1000);
  const db       = admin.firestore();

  const userDoc = db.collection("otp_requests").doc(email);
  await userDoc.set({ email }, { merge: true });
  await userDoc.collection("codes").add({
    otpHash,
    createdAt: now,
    expiresAt: expires,
    used: false,
  });

  await transporter.sendMail({
    from: `"${appName}" <${smtpUser}>`,
    to: email,
    subject: "Your OTP Code",
    text: `Your OTP is ${otp}. It expires in 5 minutes.`,
    html: `<p>Your OTP is <b>${otp}</b>. It expires in 5 minutes.</p>`,
  });

  return { ok: true };
});

// =====================================
// (2) ตรวจ OTP แล้วออก one-time token — v2 onCall
// =====================================
export const verifyOtp = onCall(async (request) => {
  const email = String(request.data?.email ?? "").trim().toLowerCase();
  const code  = String(request.data?.otp ?? "").trim();

  if (!email || !code) {
    throw new HttpsError("invalid-argument", "Missing email or otp");
  }

  const codeHash = hashCode(code);
  const db       = admin.firestore();

  const q = await db
    .collection("otp_requests").doc(email)
    .collection("codes")
    .where("otpHash", "==", codeHash)
    .where("used", "==", false)
    .limit(1)
    .get();

  if (q.empty) {
    throw new HttpsError("permission-denied", "Invalid code");
  }

  const doc  = q.docs[0];
  const data = doc.data();
  const now  = admin.firestore.Timestamp.now();

  if (now.toMillis() > data.expiresAt.toMillis()) {
    throw new HttpsError("deadline-exceeded", "Code expired");
  }

  await doc.ref.update({ used: true, usedAt: now });

  const token     = crypto.randomBytes(24).toString("hex");
  const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + TOKEN_TTL_SEC * 1000);

  await db.collection("password_reset_tokens").doc(token).set({
    email,
    createdAt: now,
    expiresAt,
    used: false,
  });

  return { ok: true, token };
});

// =====================================
// (3) ใช้ token เปลี่ยนรหัสใน Firebase Auth — v2 onCall
// =====================================
export const resetPassword = onCall(async (request) => {
  const email       = String(request.data?.email ?? "").trim().toLowerCase();
  const token       = String(request.data?.token ?? "");
  const newPassword = String(request.data?.newPassword ?? "");

  if (!email || !token || newPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Missing fields");
  }

  const db   = admin.firestore();
  const ref  = db.collection("password_reset_tokens").doc(token);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("permission-denied", "Invalid token");
  }

  const payload = snap.data()!;
  const now     = admin.firestore.Timestamp.now();

  if (payload.used) {
    throw new HttpsError("permission-denied", "Token used");
  }
  if (payload.email !== email) {
    throw new HttpsError("permission-denied", "Token/email mismatch");
  }
  if (now.toMillis() > payload.expiresAt.toMillis()) {
    throw new HttpsError("deadline-exceeded", "Token expired");
  }

  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { password: newPassword });
  await ref.update({ used: true, usedAt: now });

  return { ok: true };
});

// =====================================
//   AUTO-CLEANUP — v2 onSchedule / onRequest
// =====================================

// ลบโพสต์ที่หมดอายุ (posts.expiresAt <= now)
export const cleanExpiredPosts = onSchedule(
  { schedule: "every 24 hours", timeZone: "Asia/Bangkok" },
  async () => {
    const db  = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snap = await db.collection("posts").where("expiresAt", "<=", now).get();
    const refs = snap.docs.map(d => d.ref);

    while (refs.length) {
      const chunk = refs.splice(0, 400);
      const batch = db.batch();
      chunk.forEach(ref => batch.delete(ref));
      await batch.commit();
    }

    console.log(`Deleted ${snap.size} expired posts`);
  }
);

// ลบ OTP codes ที่หมดอายุ (collectionGroup: otp_requests/*/codes)
export const cleanExpiredOtps = onSchedule(
  { schedule: "every 24 hours", timeZone: "Asia/Bangkok" },
  async () => {
    const db  = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const snap = await db.collectionGroup("codes").where("expiresAt", "<=", now).get();
    const refs = snap.docs.map(d => d.ref);

    while (refs.length) {
      const chunk = refs.splice(0, 400);
      const batch = db.batch();
      chunk.forEach(ref => batch.delete(ref));
      await batch.commit();
    }

    console.log(`Deleted ${snap.size} expired OTP codes`);
  }
);

// ลบ reset tokens ที่หมดอายุ หรือใช้แล้วเกิน 1 วัน
export const cleanExpiredResetTokens = onSchedule(
  { schedule: "every 24 hours", timeZone: "Asia/Bangkok" },
  async () => {
    const db  = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const expired = await db
      .collection("password_reset_tokens")
      .where("expiresAt", "<=", now)
      .get();

    const oneDayAgo = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - 24 * 60 * 60 * 1000
    );
    const usedOld = await db
      .collection("password_reset_tokens")
      .where("used", "==", true)
      .where("usedAt", "<=", oneDayAgo)
      .get();

    const refs = [...expired.docs, ...usedOld.docs].map(d => d.ref);
    while (refs.length) {
      const chunk = refs.splice(0, 400);
      const batch = db.batch();
      chunk.forEach(ref => batch.delete(ref));
      await batch.commit();
    }

    console.log(`Deleted ${expired.size + usedOld.size} reset tokens`);
  }
);

// ปุ่มลัดสำหรับ "เทสด่วน": เรียก HTTPS แล้วลบหมดตาม 3 งานด้านบนทันที
export const cleanExpiredNow = onRequest(async (_req, res) => {
  try {
    const db  = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    // posts
    {
      const snap = await db.collection("posts").where("expiresAt", "<=", now).get();
      const refs = snap.docs.map(d => d.ref);
      while (refs.length) {
        const chunk = refs.splice(0, 400);
        const batch = db.batch();
        chunk.forEach(ref => batch.delete(ref));
        await batch.commit();
      }
    }

    // otp codes
    {
      const snap = await db.collectionGroup("codes").where("expiresAt", "<=", now).get();
      const refs = snap.docs.map(d => d.ref);
      while (refs.length) {
        const chunk = refs.splice(0, 400);
        const batch = db.batch();
        chunk.forEach(ref => batch.delete(ref));
        await batch.commit();
      }
    }
    
    // reset tokens (หมดอายุ + ใช้แล้วเกิน 1 วัน)
    {
      const expired = await db.collection("password_reset_tokens")
        .where("expiresAt", "<=", now).get();
      const oneDayAgo = admin.firestore.Timestamp.fromMillis(
        now.toMillis() - 24 * 60 * 60 * 1000
      );
      const usedOld = await db.collection("password_reset_tokens")
        .where("used", "==", true).where("usedAt", "<=", oneDayAgo).get();

      const refs = [...expired.docs, ...usedOld.docs].map(d => d.ref);
      while (refs.length) {
        const chunk = refs.splice(0, 400);
        const batch = db.batch();
        chunk.forEach(ref => batch.delete(ref));
        await batch.commit();
      }
    }

    res.status(200).send("OK: cleaned");
  } catch (e) {
    console.error(e);
    res.status(500).send(String(e));
  }
});

export const serverNow = onCall(async () => {
  return { now: admin.firestore.Timestamp.now().toMillis() };
});


export const onRatingWrite = onRequest(async (_req, res) => {
  res.status(405).send("Use Firestore trigger, not HTTP.");
});

// ถ้าใช้ v2 Firestore triggers:
import { onDocumentWritten } from "firebase-functions/v2/firestore";

export const accumulateUserRatings = onDocumentWritten(
  "users/{uid}/ratings/{raterUid}",
  async (event) => {
    const db = admin.firestore();
    const uid = event.params.uid as string;

    let deltaCount = 0;
    let deltaSum = 0;

    if (!event.data?.before.exists && event.data?.after.exists) {
      // create
      const newVal = (event.data.after.data()?.value ?? 0) as number;
      deltaCount = 1;
      deltaSum = newVal;
    } else if (event.data?.before.exists && !event.data?.after.exists) {
      // delete
      const oldVal = (event.data.before.data()?.value ?? 0) as number;
      deltaCount = -1;
      deltaSum = -oldVal;
    } else if (event.data?.before.exists && event.data?.after.exists) {
      // update
      const oldVal = (event.data.before.data()?.value ?? 0) as number;
      const newVal = (event.data.after.data()?.value ?? 0) as number;
      deltaCount = 0;
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

      tx.set(
        userRef,
        {
          ratingCount: afterCount,
          ratingSum: afterSum,
          ratingAvg: afterAvg,
        },
        { merge: true }
      );
    });
  }
);