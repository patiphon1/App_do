import * as functions from "firebase-functions";
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
  auth: {user: smtpUser, pass: smtpPass},
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

// ---------- Functions ----------

// (1) ส่ง OTP ไปอีเมล
export const sendOtp = functions.https.onCall(async (request) => {
  const email = String(request.data?.email ?? "").trim().toLowerCase();
  if (!email || !email.includes("@")) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid email");
  }

  const otp      = randomOtp(6);
  const otpHash  = hashCode(otp);
  const now      = admin.firestore.Timestamp.now();
  const expires  = admin.firestore.Timestamp.fromMillis(now.toMillis() + OTP_TTL_SEC * 1000);
  const db       = admin.firestore();

  const userDoc = db.collection("otp_requests").doc(email);
  await userDoc.set({email}, {merge: true});
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

  return {ok: true};
});

// (2) ตรวจ OTP แล้วออก one-time token
export const verifyOtp = functions.https.onCall(async (request) => {
  const email = String(request.data?.email ?? "").trim().toLowerCase();
  const code  = String(request.data?.otp ?? "").trim();

  if (!email || !code) {
    throw new functions.https.HttpsError("invalid-argument", "Missing email or otp");
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
    throw new functions.https.HttpsError("permission-denied", "Invalid code");
  }

  const doc    = q.docs[0];
  const data   = doc.data();
  const now    = admin.firestore.Timestamp.now();

  if (now.toMillis() > data.expiresAt.toMillis()) {
    throw new functions.https.HttpsError("deadline-exceeded", "Code expired");
  }

  await doc.ref.update({used: true, usedAt: now});

  const token     = crypto.randomBytes(24).toString("hex");
  const expiresAt = admin.firestore.Timestamp.fromMillis(now.toMillis() + TOKEN_TTL_SEC * 1000);

  await db.collection("password_reset_tokens").doc(token).set({
    email,
    createdAt: now,
    expiresAt,
    used: false,
  });

  return {ok: true, token};
});

// (3) ใช้ token เปลี่ยนรหัสใน Firebase Auth
export const resetPassword = functions.https.onCall(async (request) => {
  const email       = String(request.data?.email ?? "").trim().toLowerCase();
  const token       = String(request.data?.token ?? "");
  const newPassword = String(request.data?.newPassword ?? "");

  if (!email || !token || newPassword.length < 6) {
    throw new functions.https.HttpsError("invalid-argument", "Missing fields");
  }

  const db  = admin.firestore();
  const ref = db.collection("password_reset_tokens").doc(token);
  const snap = await ref.get();

  if (!snap.exists) {
    throw new functions.https.HttpsError("permission-denied", "Invalid token");
  }

  const payload = snap.data()!;
  const now     = admin.firestore.Timestamp.now();

  if (payload.used) {
    throw new functions.https.HttpsError("permission-denied", "Token used");
  }
  if (payload.email !== email) {
    throw new functions.https.HttpsError("permission-denied", "Token/email mismatch");
  }
  if (now.toMillis() > payload.expiresAt.toMillis()) {
    throw new functions.https.HttpsError("deadline-exceeded", "Token expired");
  }

  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, {password: newPassword});
  await ref.update({used: true, usedAt: now});

  return {ok: true};
});
