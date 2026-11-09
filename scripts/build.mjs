#!/usr/bin/env node
// Basalt / scripts / build
// One source tree, one shipped chunk. The bundler resolves `script.Parent...`
// against a virtual instance tree, so modules are authored the same way they
// would be in Rojo. An unresolved require stops the build with a file and line
// instead of producing a chunk that fails at runtime.

import { createHash } from "node:crypto";
import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SRC_DIR = path.join(ROOT, "src");
const TESTS_DIR = path.join(ROOT, "tests");
const DIST_DIR = path.join(ROOT, "dist");
const BUILD_DIR = path.join(ROOT, ".build");

const REQUIRE_PATTERN =
	/require\s*\(\s*script((?:\s*\.\s*[A-Za-z_][A-Za-z0-9_]*)*)\s*\)/g;

async function readJson(file) {
	return JSON.parse(await readFile(file, "utf8"));
}

async function collectModules(directory, prefix) {
	const modules = new Map();

	async function walk(current, segments) {
		const entries = await readdir(current, { withFileTypes: true });

		for (const entry of entries) {
			if (entry.isDirectory()) {
				await walk(path.join(current, entry.name), [...segments, entry.name]);
				continue;
			}

			if (!entry.isFile() || !entry.name.endsWith(".luau")) {
				continue;
			}

			const name = entry.name.slice(0, -".luau".length);
			const id = [...segments, name].join(".");

			modules.set(id, {
				id,
				file: path.join(current, entry.name),
				segments: [...segments, name],
			});
		}
	}

	await walk(directory, prefix ? [prefix] : []);
	return modules;
}

function pathFromScript(module, chain) {
	const tokens = [...chain.matchAll(/[A-Za-z_][A-Za-z0-9_]*/g)].map(
		(match) => match[0],
	);
	const segments = [...module.segments];

	for (const token of tokens) {
		if (token === "Parent") {
			if (segments.length === 0) {
				throw new Error(
					`${module.id}: 'script.Parent' walks above the virtual root`,
				);
			}
			segments.pop();
			continue;
		}

		segments.push(token);
	}

	return segments.join(".");
}

function lineAt(source, index) {
	return source.slice(0, index).split("\n").length;
}

function transform(module, source, modules, deps) {
	const masked = maskComments(source);
	let output = "";
	let cursor = 0;
	let match;

	REQUIRE_PATTERN.lastIndex = 0;

	while ((match = REQUIRE_PATTERN.exec(masked)) !== null) {
		const [whole, chain] = match;
		const offset = match.index;
		let target;

		try {
			target = pathFromScript(module, chain);
		} catch (error) {
			throw new Error(
				`${module.file}:${lineAt(source, offset)}: ${error.message}`,
			);
		}

		if (!modules.has(target) && modules.has(`${target}.init`)) {
			// Rojo turns a folder with init.luau into a ModuleScript, so
			// `require(folder)` and `require(folder.init)` are the same module.
			target = `${target}.init`;
		}

		if (!modules.has(target)) {
			throw new Error(
				`${module.file}:${lineAt(source, offset)}: ${whole.trim()} resolves to '${target}', which is not a module`,
			);
		}

		if (!deps.includes(target)) {
			deps.push(target);
		}

		output += source.slice(cursor, offset);
		output += `__require(${JSON.stringify(target)})`;
		cursor = offset + whole.length;
	}

	output += source.slice(cursor);
	return output;
}

function reachableFrom(modules, entry, bodies) {
	const seen = new Set();
	const queue = [entry];

	while (queue.length > 0) {
		const id = queue.shift();

		if (seen.has(id)) {
			continue;
		}

		seen.add(id);

		for (const dependency of bodies.get(id).deps) {
			if (!seen.has(dependency)) {
				queue.push(dependency);
			}
		}
	}

	return seen;
}

function stripComments(source) {
	let output = "";
	let index = 0;

	while (index < source.length) {
		const character = source[index];

		if (character === '"' || character === "'") {
			const start = index;
			index += 1;

			while (index < source.length) {
				if (source[index] === "\\") {
					index += 2;
					continue;
				}

				if (source[index] === character) {
					index += 1;
					break;
				}

				index += 1;
			}

			output += source.slice(start, index);
			continue;
		}

		if (character === "[") {
			const level = longBracketLevel(source, index);

			if (level >= 0) {
				const closing = "]" + "=".repeat(level) + "]";
				const end = source.indexOf(closing, index + level + 2);
				const stop = end === -1 ? source.length : end + closing.length;

				output += source.slice(index, stop);
				index = stop;
				continue;
			}
		}

		if (character === "-" && source[index + 1] === "-") {
			const level = longBracketLevel(source, index + 2);

			if (level >= 0) {
				const closing = "]" + "=".repeat(level) + "]";
				const end = source.indexOf(closing, index + 2 + level + 2);
				index = end === -1 ? source.length : end + closing.length;
				continue;
			}

			while (index < source.length && source[index] !== "\n") {
				index += 1;
			}

			continue;
		}

		output += character;
		index += 1;
	}

	return output;
}

function longBracketLevel(source, index) {
	if (source[index] !== "[") {
		return -1;
	}

	let cursor = index + 1;
	let level = 0;

	while (source[cursor] === "=") {
		level += 1;
		cursor += 1;
	}

	return source[cursor] === "[" ? level : -1;
}

// Same scanner as stripComments, but comments are replaced with spaces while
// strings are preserved. Offsets stay identical, so a require found in the
// masked source can be replaced in the original without drifting.
function maskComments(source) {
	let output = "";
	let index = 0;

	while (index < source.length) {
		const character = source[index];

		if (character === '"' || character === "'") {
			const start = index;
			index += 1;

			while (index < source.length) {
				if (source[index] === "\\") {
					index += 2;
					continue;
				}

				if (source[index] === character) {
					index += 1;
					break;
				}

				index += 1;
			}

			output += source.slice(start, index);
			continue;
		}

		if (character === "[") {
			const level = longBracketLevel(source, index);

			if (level >= 0) {
				const closing = "]" + "=".repeat(level) + "]";
				const end = source.indexOf(closing, index + level + 2);
				const stop = end === -1 ? source.length : end + closing.length;

				output += source.slice(index, stop);
				index = stop;
				continue;
			}
		}

		if (character === "-" && source[index + 1] === "-") {
			const level = longBracketLevel(source, index + 2);
			let stop;

			if (level >= 0) {
				const closing = "]" + "=".repeat(level) + "]";
				const end = source.indexOf(closing, index + 2 + level + 2);
				stop = end === -1 ? source.length : end + closing.length;
			} else {
				stop = index;
				while (stop < source.length && source[stop] !== "\n") {
					stop += 1;
				}
			}

			output += source.slice(index, stop).replace(/[^\n]/g, " ");
			index = stop;
			continue;
		}

		output += character;
		index += 1;
	}

	return output;
}

function buildPrelude(mockSource) {
	const bindings = [
		"task",
		"warn",
		"typeof",
		"Color3",
		"Enum",
		"Font",
		"TweenInfo",
		"Instance",
		"game",
		"Vector2",
		"Vector3",
		"UDim",
		"UDim2",
	];

	const lines = ["local __mock = (function()"];
	lines.push(mockSource.trimEnd());
	lines.push("end)()", "");

	for (const name of bindings) {
		lines.push(`local ${name} = __mock.${name}`);
	}

	// Executor capabilities are globals in a real client. The test bundle writes
	// live shims into the global environment so the library's own probe path is
	// exercised, and Mock.disable() can still turn a capability off mid-test.
	lines.push("");
	lines.push("do");
	lines.push("\tlocal env = getfenv(0)");
	lines.push("\tenv.gethui = function()");
	lines.push('\t\tlocal fn = __mock.Env().gethui');
	lines.push('\t\tif type(fn) ~= "function" then return nil end');
	lines.push("\t\treturn fn()");
	lines.push("\tend");
	lines.push("\tenv.protect_gui = function(target)");
	lines.push('\t\tlocal fn = __mock.Env().protect_gui');
	lines.push('\t\tif type(fn) ~= "function" then return target end');
	lines.push("\t\treturn fn(target)");
	lines.push("\tend");
	lines.push("end");

	return lines.join("\n");
}

function emitBundle({ version, modules, bodies, entry, prelude, mockId, hash }) {
	const lines = [];

	lines.push(`-- Basalt ${version} | MIT`);
	lines.push(
		`-- Bundled from ${modules.size} source modules. Do not edit this file; edit src/*.luau.`,
	);
	lines.push(`-- Source sha256: ${hash.slice(0, 16)}`);
	lines.push("");

	if (prelude) {
		lines.push(prelude, "");
	}

	lines.push("local __defs = {}");
	lines.push("local __cache = {}");
	lines.push("");
	lines.push("local function __require(id)");
	lines.push("\tlocal cached = __cache[id]");
	lines.push("\tif cached ~= nil then");
	lines.push("\t\treturn cached");
	lines.push("\tend");
	lines.push("");
	lines.push("\tlocal definition = __defs[id]");
	lines.push("\tif not definition then");
	lines.push(
		'\t\terror("Basalt: missing module \'" .. tostring(id) .. "\'", 2)',
	);
	lines.push("\tend");
	lines.push("");
	lines.push("\tlocal result = definition()");
	lines.push("\t__cache[id] = result");
	lines.push("\treturn result");
	lines.push("end");
	lines.push("");

	const ordered = [...modules.keys()].sort((left, right) => {
		if (left === entry) return -1;
		if (right === entry) return 1;
		return left.localeCompare(right);
	});

	for (const id of ordered) {
		const body = bodies.get(id);

		lines.push(`__defs[${JSON.stringify(id)}] = function()`);

		if (id === mockId) {
			lines.push("\treturn __mock");
		} else {
			lines.push(body.code.trimEnd());
		}

		lines.push("end", "");
	}

	lines.push(`return __require(${JSON.stringify(entry)})`);
	lines.push("");

	return lines.join("\n");
}

async function prepare() {
	const packageJson = await readJson(path.join(ROOT, "package.json"));
	const srcModules = await collectModules(SRC_DIR, "");
	const testModules = await collectModules(TESTS_DIR, "tests");

	return { version: packageJson.version, srcModules, testModules };
}

function compile(modules, extraModules, entry, mockId) {
	const all = new Map([...modules, ...extraModules]);
	const bodies = new Map();
	const hash = createHash("sha256");

	for (const [id, module] of [...all.entries()].sort(([a], [b]) =>
		a.localeCompare(b),
	)) {
		void id;
		const source = module.source;
		const deps = [];
		const code = transform(module, source, all, deps);

		bodies.set(id, { code, deps });
		hash.update(source);
	}

	if (!all.has(entry)) {
		throw new Error(`entry module '${entry}' does not exist`);
	}

	const reachable = reachableFrom(all, entry, bodies);
	const skipped = [...all.keys()].filter((id) => !reachable.has(id));
	const emitted = new Map(
		[...reachable].map((id) => [id, all.get(id)]),
	);

	return {
		modules: emitted,
		bodies,
		skipped,
		hash: hash.digest("hex"),
	};
}

async function attachSources(modules) {
	for (const module of modules.values()) {
		module.source = await readFile(module.file, "utf8");
	}

	return modules;
}

async function main() {
	const { version, srcModules, testModules } = await prepare();

	await attachSources(srcModules);
	await attachSources(testModules);

	const mockFile = path.join(TESTS_DIR, "mock", "roblox.luau");
	const mockSource = await readFile(mockFile, "utf8");

	const srcBuild = compile(srcModules, new Map(), "init", null);
	const testBuild = compile(srcModules, testModules, "tests.init", "tests.mock.roblox");

	const library = emitBundle({
		version,
		modules: srcBuild.modules,
		bodies: srcBuild.bodies,
		entry: "init",
		prelude: null,
		mockId: null,
		hash: srcBuild.hash,
	});

	const tests = emitBundle({
		version,
		modules: testBuild.modules,
		bodies: testBuild.bodies,
		entry: "tests.init",
		prelude: buildPrelude(mockSource),
		mockId: "tests.mock.roblox",
		hash: testBuild.hash,
	});

	await mkdir(DIST_DIR, { recursive: true });
	await mkdir(BUILD_DIR, { recursive: true });

	await writeFile(path.join(DIST_DIR, "basalt.lua"), library, "utf8");
	await writeFile(path.join(DIST_DIR, "basalt.min.lua"), stripComments(library), "utf8");
	await writeFile(path.join(BUILD_DIR, "tests.luau"), tests, "utf8");

	const lines = [
		`Basalt ${version}`,
		`  dist/basalt.lua      ${srcBuild.modules.size} modules, ${library.length} bytes`,
		`  dist/basalt.min.lua  ${stripComments(library).length} bytes`,
		`  .build/tests.luau    ${testBuild.modules.size} modules`,
	];

	if (srcBuild.skipped.length > 0) {
		lines.push(`  skipped (type-only or unused): ${srcBuild.skipped.join(", ")}`);
	}

	console.log(lines.join("\n"));
}

main().catch((error) => {
	console.error(`build failed: ${error.message}`);
	process.exit(1);
});
