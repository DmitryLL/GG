import { Router } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import type { AuthRequest, AuthResponse, AuthError } from "@gg/shared";
import { prisma } from "./db.js";

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) throw new Error("JWT_SECRET env is required");

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function signToken(userId: string): string {
  return jwt.sign({ sub: userId }, JWT_SECRET!, { expiresIn: "30d" });
}

export function verifyToken(token: string): string | null {
  try {
    const payload = jwt.verify(token, JWT_SECRET!) as { sub?: string };
    return payload.sub ?? null;
  } catch {
    return null;
  }
}

export const authRouter = Router();

authRouter.post("/register", async (req, res) => {
  const body = req.body as Partial<AuthRequest>;
  const email = body.email?.trim().toLowerCase();
  const password = body.password;

  if (!email || !EMAIL_RE.test(email)) {
    return res.status(400).json({ error: "Invalid email" } satisfies AuthError);
  }
  if (!password || password.length < 6) {
    return res.status(400).json({ error: "Password must be 6+ chars" } satisfies AuthError);
  }

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    return res.status(409).json({ error: "Email already registered" } satisfies AuthError);
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await prisma.user.create({
    data: {
      email,
      passwordHash,
      character: { create: { name: email.split("@")[0] } },
    },
  });

  const token = signToken(user.id);
  res.json({ token, userId: user.id } satisfies AuthResponse);
});

authRouter.post("/login", async (req, res) => {
  const body = req.body as Partial<AuthRequest>;
  const email = body.email?.trim().toLowerCase();
  const password = body.password;

  if (!email || !password) {
    return res.status(400).json({ error: "Email and password required" } satisfies AuthError);
  }

  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
    return res.status(401).json({ error: "Invalid credentials" } satisfies AuthError);
  }

  const token = signToken(user.id);
  res.json({ token, userId: user.id } satisfies AuthResponse);
});
