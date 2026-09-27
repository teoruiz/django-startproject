import { readFile, writeFile } from "node:fs/promises";
import openapiTS, { astToString } from "openapi-typescript";

for (const name of ["api", "auth"]) {
    const schema = new URL(`../.schema/${name}.json`, import.meta.url);
    const output = new URL(`../src/lib/${name}.d.ts`, import.meta.url);
    const source = astToString(await openapiTS(schema));
    if (process.argv.includes("--check")) {
        if ((await readFile(output, "utf8")) !== source) {
            throw new Error(
                `${name} contract is stale. Run just api-generate and commit the result.`,
            );
        }
    } else {
        await writeFile(output, source);
    }
}
