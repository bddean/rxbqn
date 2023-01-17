// Registry of importable BQN modules.
const reg = {}; // name -> raw text or evaluated bqn obj

// TODO: Should evaluate on demand to match cbqn semantics...
const preloadBqnModule = async (name, path) => {
	const text = await (fetch('./rx.bqn').then(rsp => rsp.text()));
	reg[name]=text;
}

sysvals.import = name => {
	name = typeof name === "string" ? name : name.join('');
	if (! reg[name]) throw new Error(`Missing BQN module: ${name}`);
	// Evaluate on demand, but only once per imported module.
	if (typeof reg[name] === "string") {
		reg[name] = bqn(reg[name]);
	}
	return reg[name];
}

sysvals.show = s => (console.log(s.join?s.join(''):s),s);
