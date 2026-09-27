import createClient from "openapi-fetch";
import type { paths } from "./api";
import type { paths as AuthPaths, components as AuthComponents } from "./auth";

export const api = createClient<paths>({ credentials: "same-origin" });
const auth = createClient<AuthPaths>({ credentials: "same-origin" });

async function csrfHeaders() {
    // Fetch a fresh masked token: Django rotates the CSRF secret after login.
    const { data, response } = await api.GET("/api/csrf");
    if (!response.ok || !data)
        throw new Error("Cannot connect. Please try again.");
    return { "X-CSRFToken": data.csrf_token };
}

export async function currentUser(signal?: AbortSignal) {
    const { data, response } = await api.GET("/api/me", { signal });
    if (response.status === 401) return null;
    if (!response.ok || !data)
        throw new Error("Cannot load your account. Please try again.");
    return data;
}

export async function signIn(body: AuthComponents["schemas"]["Login"]) {
    const { response } = await auth.POST("/api/auth/browser/v1/auth/login", {
        body,
        headers: await csrfHeaders(),
    });
    if (response.status === 400 || response.status === 401) {
        throw new Error("Unable to sign in. Check your email and password.");
    }
    if (response.status === 429)
        throw new Error("Too many attempts. Please try again later.");
    if (!response.ok)
        throw new Error("Sign-in is unavailable. Please try again.");
}

export async function signOut() {
    const { response } = await auth.DELETE(
        "/api/auth/browser/v1/auth/session",
        {
            headers: await csrfHeaders(),
        },
    );
    // allauth specifies 401 (now unauthenticated) as successful logout.
    if (response.status !== 401)
        throw new Error("Could not sign out. Please try again.");
}
