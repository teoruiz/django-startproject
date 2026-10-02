import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { FormEvent } from "react";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { currentUser, signIn, signOut } from "@/lib/client";

export function Account() {
    const client = useQueryClient();
    const user = useQuery({
        queryKey: ["current-user"],
        queryFn: ({ signal }) => currentUser(signal),
        retry: false,
    });
    const login = useMutation({
        mutationFn: signIn,
        onSuccess: () =>
            client.invalidateQueries({ queryKey: ["current-user"] }),
    });
    const logout = useMutation({
        mutationFn: signOut,
        onSuccess: async () => {
            await client.cancelQueries();
            client.clear();
            client.setQueryData(["current-user"], null);
        },
    });

    function submit(event: FormEvent<HTMLFormElement>) {
        event.preventDefault();
        const values = new FormData(event.currentTarget);
        login.mutate({
            email: String(values.get("email")),
            password: String(values.get("password")),
        });
    }

    if (user.isPending) return <p role="status">Loading your account…</p>;
    if (user.isError)
        return (
            <Alert variant="destructive">
                <AlertDescription>{user.error.message}</AlertDescription>
                <Button variant="outline" onClick={() => void user.refetch()}>
                    Try again
                </Button>
            </Alert>
        );

    if (user.data)
        return (
            <Card className="mx-auto max-w-lg">
                <CardHeader>
                    <CardDescription>Your account</CardDescription>
                    <CardTitle className="text-2xl">
                        Welcome, {user.data.display_name}
                    </CardTitle>
                </CardHeader>
                <CardContent className="space-y-6">
                    <dl className="space-y-1">
                        <dt className="text-sm text-muted-foreground">
                            Email address
                        </dt>
                        <dd>{user.data.email}</dd>
                    </dl>
                    {logout.isError ? (
                        <Alert variant="destructive">
                            <AlertDescription>
                                {logout.error.message}
                            </AlertDescription>
                        </Alert>
                    ) : null}
                    <Button
                        variant="outline"
                        disabled={logout.isPending}
                        onClick={() => logout.mutate()}
                    >
                        {logout.isPending ? "Signing out…" : "Sign out"}
                    </Button>
                </CardContent>
            </Card>
        );

    return (
        <Card className="mx-auto max-w-md">
            <CardHeader>
                <CardTitle className="text-2xl">Sign in</CardTitle>
                <CardDescription>
                    Welcome back. Enter your account details to continue.
                </CardDescription>
            </CardHeader>
            <CardContent>
                <form onSubmit={submit} className="space-y-5">
                    <div className="space-y-2">
                        <Label htmlFor="email">Email</Label>
                        <Input
                            id="email"
                            name="email"
                            type="email"
                            autoComplete="username"
                            required
                        />
                    </div>
                    <div className="space-y-2">
                        <Label htmlFor="password">Password</Label>
                        <Input
                            id="password"
                            name="password"
                            type="password"
                            autoComplete="current-password"
                            required
                        />
                    </div>
                    {login.isError ? (
                        <Alert variant="destructive">
                            <AlertDescription>
                                {login.error.message}
                            </AlertDescription>
                        </Alert>
                    ) : null}
                    <Button
                        className="w-full"
                        disabled={login.isPending}
                        type="submit"
                    >
                        {login.isPending ? "Signing in…" : "Sign in"}
                    </Button>
                </form>
            </CardContent>
        </Card>
    );
}
