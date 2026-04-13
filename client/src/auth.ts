import type { AuthRequest, AuthResponse, AuthError } from "@gg/shared";

const TOKEN_KEY = "gg_token";

export function getStoredToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function storeToken(token: string): void {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken(): void {
  localStorage.removeItem(TOKEN_KEY);
}

function httpBase(): string {
  const wsUrl = (import.meta as any).env?.VITE_SERVER_WS_URL as string | undefined;
  if (wsUrl) return wsUrl.replace(/^ws/, "http");
  return `${window.location.protocol}//${window.location.host}`;
}

async function post(path: string, body: AuthRequest): Promise<AuthResponse> {
  const res = await fetch(httpBase() + path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = (await res.json()) as AuthResponse | AuthError;
  if (!res.ok) throw new Error((data as AuthError).error || "Request failed");
  return data as AuthResponse;
}

export const register = (body: AuthRequest) => post("/auth/register", body);
export const login = (body: AuthRequest) => post("/auth/login", body);

export function mountAuthUI(onAuthed: (token: string) => void): void {
  const overlay = document.getElementById("auth-overlay")!;
  const title = document.getElementById("auth-title")!;
  const email = document.getElementById("auth-email") as HTMLInputElement;
  const password = document.getElementById("auth-password") as HTMLInputElement;
  const submit = document.getElementById("auth-submit") as HTMLButtonElement;
  const toggle = document.getElementById("auth-toggle") as HTMLButtonElement;
  const error = document.getElementById("auth-error")!;

  let mode: "login" | "register" = "login";

  const render = () => {
    title.textContent = mode === "login" ? "Вход" : "Регистрация";
    submit.textContent = mode === "login" ? "Войти" : "Создать аккаунт";
    toggle.textContent = mode === "login" ? "Нет аккаунта? Регистрация" : "Уже есть аккаунт? Войти";
    error.textContent = "";
  };
  render();

  toggle.addEventListener("click", () => {
    mode = mode === "login" ? "register" : "login";
    render();
  });

  const doSubmit = async () => {
    error.textContent = "";
    submit.disabled = true;
    try {
      const fn = mode === "login" ? login : register;
      const { token } = await fn({ email: email.value, password: password.value });
      storeToken(token);
      overlay.remove();
      onAuthed(token);
    } catch (e: any) {
      error.textContent = e?.message || "Ошибка";
    } finally {
      submit.disabled = false;
    }
  };

  submit.addEventListener("click", doSubmit);
  password.addEventListener("keydown", (e) => {
    if (e.key === "Enter") doSubmit();
  });
}

export function mountLogoutButton(onLogout: () => void): void {
  const btn = document.getElementById("logout") as HTMLButtonElement;
  btn.style.display = "block";
  btn.addEventListener("click", () => {
    clearToken();
    onLogout();
  });
}
