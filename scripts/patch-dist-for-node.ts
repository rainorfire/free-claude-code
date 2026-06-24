import { readdir, readFile, writeFile } from 'fs/promises'
import { join } from 'path'

/** Explicit Resource Management (`using` / `await using`) is not supported on Node 20. */
const AWAIT_USING_RE = /\bawait using\s+([a-zA-Z_$][\w$]*)\s*=/g
const USING_RE = /\busing\s+([a-zA-Z_$][\w$]*)\s*=/g

export async function collectJsFiles(dir: string): Promise<string[]> {
  const entries = await readdir(dir, { withFileTypes: true })
  const files: string[] = []
  for (const entry of entries) {
    const filePath = join(dir, entry.name)
    if (entry.isDirectory()) {
      files.push(...(await collectJsFiles(filePath)))
    } else if (entry.name.endsWith('.js')) {
      files.push(filePath)
    }
  }
  return files
}

export async function patchUsingDeclarations(
  jsFiles: string[],
): Promise<number> {
  let patched = 0
  for (const filePath of jsFiles) {
    const content = await readFile(filePath, 'utf-8')
    if (!/\b(await )?using\s+[a-zA-Z_$]/.test(content)) {
      continue
    }
    await writeFile(
      filePath,
      content
        .replace(AWAIT_USING_RE, 'const $1 =')
        .replace(USING_RE, 'const $1 ='),
    )
    patched++
  }
  return patched
}

export async function patchDistForNode(outdir: string): Promise<number> {
  const jsFiles = await collectJsFiles(outdir)
  return patchUsingDeclarations(jsFiles)
}
