import { Link, NavLink, Route, Routes } from "react-router";
import { Button } from "@/components/ui/button";
import { Account } from "@/pages/account";

function Home() {
    return (
        <section className="max-w-2xl space-y-6 py-12 sm:py-24">
            <p className="text-sm font-medium text-muted-foreground">
                YOUR NEXT CHAPTER
            </p>
            <h1 className="text-4xl font-semibold tracking-tight sm:text-6xl">
                Room for your next idea.
            </h1>
            <p className="max-w-lg text-lg leading-relaxed text-muted-foreground">
                A clean workspace, ready to become something useful. Sign in to
                get started.
            </p>
            <Button asChild size="lg">
                <Link to="/account">Open your account</Link>
            </Button>
        </section>
    );
}

export function App() {
    return (
        <div className="min-h-screen">
            <header className="border-b bg-card">
                <nav
                    aria-label="Main"
                    className="mx-auto flex max-w-5xl items-center justify-between px-6 py-5"
                >
                    <Link to="/" className="font-semibold tracking-tight">
                        Workspace
                    </Link>
                    <NavLink
                        to="/account"
                        className="text-sm text-muted-foreground hover:text-foreground"
                    >
                        Account
                    </NavLink>
                </nav>
            </header>
            <main className="mx-auto max-w-5xl px-6 py-12">
                <Routes>
                    <Route path="/" element={<Home />} />
                    <Route path="/account" element={<Account />} />
                    <Route
                        path="*"
                        element={
                            <section className="space-y-4">
                                <h1 className="text-2xl font-semibold">
                                    Page not found
                                </h1>
                                <Button asChild variant="outline">
                                    <Link to="/">Back to home</Link>
                                </Button>
                            </section>
                        }
                    />
                </Routes>
            </main>
        </div>
    );
}
