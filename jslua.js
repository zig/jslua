#! /usr/local/bin/lua-5.1
/*
 * jslua - transform javascript like syntax into lua
 *
 * @author : Vincent Penne (ziggy at zlash.com)
 *
 */

if (arg[0]) standalone = 1;

// useful shortcut
format = string.format;

// lua namespaces
function enter_namespace(name) {
	var parent = getfenv(2);
	var namespace = { parent_globals = parent };

	var i, v;
	for (i, v in pairs(parent))
		if (i != "parent_globals")
			namespace[i] = v;
	
	parent[name] = namespace;
	namespace[name] = namespace;

	setfenv(2, namespace);
}

function exit_namespace() {
	var parent = getfenv(2);
	setfenv(2, parent.parent_globals);
}


// enter in jslua namespace
enter_namespace("jslua");


// all single symbol tokens in js
var symbols = "~!#%%%^&*()%-%+=|/%.,<>:;\"'%[%]{}%?";
var symbolset = "["..symbols.."]";
var msymbols = "<>!%&%*%-%+%=%|%/%%%^%.";
var msymbolset = "["..msymbols.."]";
var nospace = {
	["~"] = 1,
	["#"] = 1,
};


// paths
var paths = {
	"",
};

function add_path(path) {
	table.insert(paths, path);
}

var loadfile_orig = loadfile;
function loadfile(name) {
	var module, error;
	for (_, path in pairs(paths)) {
		//emiterror(format("Trying '%s'", path..name));
		module, error = loadfile_orig(path..name);
		if (module) {
			setfenv(module, getfenv(2));
			break;
		}
	}
	return module, error;
}


function _message(msg) {
	io.stderr:write(msg.."\n");
}

function message(msg) {
	if (verbose)
		_message(msg);
}

function dbgmessage(msg) {
	if (dbgmode)
		_message(msg);
}

// emit an error, optionally print information about status in source where the error occured
function emiterror(msg, source) {
	var p="";
	source = source || cursource;
	if (source)
    		p = format("%s (%d) at token '%s' : ", source.filename, source.nline || -1, source.token || "<null>");
	_message(p..msg);
	has_error = 1;
	num_error = (num_error || 0) + 1;
}


// collapse an array of strings into one string, lua-efficiently (lua sucks at string concatenations)
function colapse(t) {
	var i, n;
	while (t[2]) {
		n = #t;
		var t2 = { };
		for (i=1,n,2)
			table.insert(t2, t[i]..(t[i+1] || ""));
		t = t2;
	}
	return t[1] || "";
}

function opensource(realfn, filename) {
  
	var source = { };

	source.filename = filename;
	if (standalone) {
		if (realfn)
			source.handle = io.open(filename, "r");
		else
			source.handle = io.stdin;
		if (!source.handle) {
			emiterror(format("Can't open source '%s'", filename));
			return nil;
		}
	} else {
		source.buffer = gBuffer;
		source.bufpos = 1;
	}
  
	source.nline = 0;
	source.ntoken = 0;
	source.tokens = { };
	source.tokentypes = { };
	source.tokenlines = { };
	source.tokencomments = { };
  
	var token = basegettoken(source);
	while (token) {
		//print(token, source.tokentype);
		table.insert(source.tokens, token);
		table.insert(source.tokentypes, source.tokentype);
		table.insert(source.tokenlines, source.nline);
		source.ntoken++;
		token = basegettoken(source);
	}
	source.tokenpos = 1;
  
	return source;
  
}

function closesource(source) {
	if (standalone) {
		source.handle:close();
		source.handle = nil;
	}
	cursource = nil;
}

function getline(source) {
	if (standalone)
		source.linebuffer = source.handle:read("*l");
	else {
		if (!source.bufpos) return;
		var i = string.find(source.buffer, "\n", source.bufpos);
		source.linebuffer = string.sub(source.buffer, source.bufpos, (i || 0) - 1);
		source.bufpos = i && (i+1);
	}

	source.nline++;
	source.newline = 1;
	//dbgmessage(format("%d %s", source.nline, source.linebuffer));
}

function savepos(source) {
	return source.tokenpos;
}

function gotopos(source, pos) {
	source.tokenpos = pos-1;
	return gettoken(source);
}

function gettoken(source) {
	cursource = source;
	var pos = source.tokenpos;
	var token = source.tokens[pos];
	source.token = token;
	source.tokentype = source.tokentypes[pos];
	source.nline = source.tokenlines[pos];
	if (!token)
		return;
	source.tokenpos = pos + 1;

	//message(format("\015%d", source.nline));
	dbgmessage(token);

	if (source.tokentype == "comment") {
		if (!source.tokencomments[source.tokenpos - 1]) {
			out(string.gsub("-- "..token, "\n", outcurindent.."\n--").."\n");
			source.tokencomments[source.tokenpos - 1] = 1;
		}
		return gettoken(source);
	}

	return token;
}

// This could be rewritten more efficiently in C
function basegettoken(source) {
	var newline;
	
	var tokens;
	
	if (!source.linebuffer) {
		newline = 1;
		getline(source);
		if (!source.linebuffer)
			return nil;
	} else
		source.newline=nil;
	
	var i,j;
	
	// remove starting spaces
	var s = source.linebuffer;
	i = string.find(s, "%S");
	if (!i) {
		// we reached the end of the line
		source.linebuffer = nil;
		return basegettoken(source); // tail call so it's fine
	}
	j = string.find(s, "[%s"..symbols.."]", i);
	if (!j)
		j = string.len(s) + 1;
	else
		j--;
	
	source.stick = (i==1);
	source.tokentype="word";
	if (i != j) {
		var c = string.sub(s, i, i);
		if (string.find(c, symbolset)) {
			j = i;
			while (string.find(string.sub(s, j+1, j+1), msymbolset) && 
			       string.find(c, msymbolset))
				j++;
			source.tokentype=string.sub(s, i, j);
		} else if (string.find(string.sub(s, j-1, j), symbolset))
			j--;
	}
	
	token = string.sub(s, i, j);
	source.token = token;
	source.linebuffer=string.sub(s, j+1);
	
	if (token == "\"" || token == "'") {
		// string
		var t = token;
		s = source.linebuffer;
		var ok;
		while(!ok) {
			var _, k;
			_,k = string.find(s, t);
			while (k && k>1) {
				var l = k-1;
				var n = 0;
				while (l>0 && string.sub(s, l, l)=="\\") {
					l--;
					n += 0.5;
				}
				if (n > 0)
					dbgmessage(format("N = %g (%g) '%s'", n, math.floor(n), 
							  source.linebuffer));
				if (math.floor(n) == n) 
					break;
				_,k = string.find(s, t, k+1);
			}
			if (k) {
				token = token..string.sub(s, 1, k);
				source.linebuffer=string.sub(s, k+1);
				dbgmessage(format("TOKEN(%s) REST(%s), k(%d)", token, source.linebuffer, k+1));
				ok = 1;
			} else {
				token = token..string.sub(s, 1, -2);
				getline(source);
				if (!source.linebuffer)
					return nil;
				s = source.linebuffer;
			}
		}
		
		source.tokentype=t;
	}
	
	if (token == "//" || (source.newline && token == "#")) {
		// end of line commentary
		getline(source);
		//source.tokentype = "comment";
		//token = string.sub(s, j+2);
		return basegettoken(source);
	}
	if (token == "/*") {
		// block comment
		var _, k;
		_, k = string.find(s, "*/", j+2);
		token = "";
		while (!k) {
			token = token..string.sub(s, j+2).."\n";
			getline(source);
			s = source.linebuffer;
			if (!s)
				return nil;
			_, k = string.find(s, "*/");
			j = -1;
		}
		source.linebuffer = string.sub(s, k+1);
		source.tokentype = "comment";
		token = token..string.sub(s, j+2, k-1);
		//return basegettoken(source);
	}
	
	if (source.tokentype == "word" && !string.find(token, "[^0123456789%.]")) {
		source.tokentype = "number";
		var s = source.linebuffer;
		if (string.sub(s, 1, 1) == ".") {
			var i = string.find(s, "%D", 2);
			if (i) {
				source.linebuffer = string.sub(s, i);
				i--;
			} else
				source.linebuffer = nil;
			token = token..string.sub(s, 1, i);
			//message(format("FLOAT %s line %d", token, source.nline));
		}
	}
	return token;
}

var exprstack = { };

function processaccum(source, token, what) {
	out("= ");
	for (i = exprstack[#exprstack] - 1, source.tokenpos - 3, 1)
		out(source.tokens[i].." ");
	out(string.sub(what, 1, 1).." ");
	return token;
}

function processincr(source, token, what) {
	processaccum(source, token, what);
	out("1 ");
	return token;
}

var exprkeywords = {
	["function"] = function(source, token, what) {
		out("function ") ;
		if (token != "(") {
			// named function
			out(token);
			token = gettoken(source);
		}
		
		if (token != "(") {
			emiterror("'(' expected", source);
			return token;
		}
		
		out("(");
		token = processblock(source, "(", ")", 1);
		out(")");
		outnl();
		
		outindent(1);
		token = processstatement(source, gettoken(source), 1);
		outindent(-1);
		
		outi(); out("end"); outnl();
		
		gotopos(source, source.tokenpos - 1);
		return ";";
		//return token;
	},
	["var"] = "local",
	["||"] = "or",
	["&&"] = "and",
	["!="] = "~=",
	["!"] = "not",
	["+="] = processaccum,
	["-="] = processaccum,
	["*="] = processaccum,
	["/="] = processaccum,
	["++"] = processincr,
	["--"] = processincr,
};

function eatexpr(source, token) {
// 	if (keywords[token])
// 		return token;
	while (token && exprkeywords[token]) {
		var expr = exprkeywords[token];
		if (type(expr) == "string") {
			out(expr.." ");
			token = gettoken(source);
		} else
			token = exprkeywords[token](source, gettoken(source), token);
	}
// 	if (token && keywords[token])
// 		emiterror("unexpected reserved keyword '"..token.."'", source);
	return token;
}

// process a block enclosed by 'open' and 'close' pair
function processblock(source, open, close, n) {
	if (n < 1) {
		if (gettoken(source) != open) {
			emiterror(format("expected '%s' but got '%s'", open, source.token), source);
			return nil;
		}
		n = 1;
	}
	var token = gettoken(source);
	table.insert(exprstack, savepos(source));
	while (n>=1) {
		token = eatexpr(source, token);
		if (!token)
			return nil;
		if (token == open)
			n++;
		else if (token == close)
			n--;
     
		if (n>=1) {
			if (token != ";") {
				if (nospace[token])
					out(token);
				else
					out(token.." ");
			}
			token = gettoken(source);
		}
	}
	table.remove(exprstack);
  
	return token;
}

var expression_terminators = {
	[";"] = 1,
/*	[")"] = 1,
	[","] = 1,
	["]"] = 1,
	["}"] = 1 */
};

var openclose = {
	["("] = ")",
	["["] = "]",
	["{"] = "}",
};

// parse an expression
function processexpression(source, token) {
	table.insert(exprstack, savepos(source));
	while (token) {
		token = eatexpr(source, token);

		if (!token || expression_terminators[token]) break;
		if (nospace[token])
			out(token);
		else
			out(token.." ");


		var close = openclose[token];
		if (close) {
			processblock(source, token, close, 1);
			out(close);
		}

		token = gettoken(source);
	}
	table.remove(exprstack);
	return token;
}

function process_if(source, token, what) {
	if (token != "(") {
		emiterror("'(' expected", source);
		return token;
	}

	outi(); out(what.." ");
	token = processblock(source, "(", ")", 1);
	if (what == "if") out("then"); else out("do");
	outnl();

	outindent(1);
	token = processstatement(source, gettoken(source), 1);
	outindent(-1);

	while (what == "if" && token == "elseif") {
		token = gettoken(source);
		if (token != "(") {
			emiterror("'(' expected", source);
			return token;
		}

		outi(); out("elseif ");
		token = processblock(source, "(", ")", 1);
		out("then"); outnl();

		outindent(1);
		token = processstatement(source, gettoken(source), 1);
		outindent(-1);
	}

	if (what == "if" && token == "else") {
		outi(); out(token); outnl();

		outindent(1);
		token = processstatement(source, gettoken(source), 1);
		outindent(-1);
	}

	outi(); out("end"); outnl();
   
	return token;
}


keywords = {
	["if"] = process_if,
	["while"] = process_if,
	["for"] = process_if,
};

function processstatement(source, token, delimited) {

	if (keywords[token])
		return keywords[token](source, gettoken(source), token);

	else if (token == "{") {
		if (!delimited) {
			outi(); out("do"); outnl();
			outindent(1);
		}
		token = gettoken(source);
		while (token && token != "}")
			token = processstatement(source, token);
		if (!delimited) {
			outindent(-1);
			outi(); out("end"); outnl();
		}
		token = gettoken(source);
		
	} else {
		outi();
		token = processexpression(source, token);
		outnl();

		if (token && token != ";" && token != "}") {
			emiterror("warning ';' or '}' expected", source);
			token = gettoken(source);
		}

		if (token == ";")
			token = gettoken(source);
	}

	return token;

}


function processsource(source) {
	var token = gettoken(source);
	while (token)
		token = processstatement(source, token);
}


// modules
function loadmodule(name, ns) {
	var mname = "mod_"..name;

	var ons = getfenv();
	if (ns)
		setfenv(1, ns);

	enter_namespace(mname);
	var table = getfenv();
	var module, error = loadfile(name..".lua");
	if (module) {
		message(format("Module '%s' loaded", name));
		setfenv(module, table); // why do I need to do this ??
		module();
		add_options(table.options);
	} else {
		emiterror(format("Could not load module '%s'", name));
		message(error);
		table = nil;
	}

	exit_namespace();

	setfenv(1, ons);

	return table;
}


function jslua(f) {

	has_error = nil;
	num_error = 0;
  
	resultString = { };

	var filename = f || "stdin";
	message ("Reading from "..filename);
	var source = opensource(f, filename);
  
	if (!source)
		return "";
  
	message (format("%d lines, %d tokens", source.nline, source.ntoken));
	message ("Processing "..filename);
	processsource(source);

	closesource(source);

	if (has_error) {
		message(format("%d error(s) while compiling", num_error));
		return "";
	} else
		message(format("no error while compiling"));

	return colapse(resultString);
}

function dofile(file) {
	var source = jslua(file);
	var module, error = loadstring(source);
	source = nil; // allow source to be garbage collected
	if (module) {
		//setfenv(module, table); // why do I need to do this ??
		module();
	} else {
		emiterror(format("Could not load string"));
		message(error);
	}
}

// postprocess
postprocess = { };

function do_postprocess() {
	for (_, v in pairs(postprocess))
		v();
}

function add_postprocess(f) {
	table.insert(postprocess, f);
}




// output
outcurindent = "";
outindentstring = "   ";
outindentlevel = 0;

function out(s) {
	table.insert(resultString, s);
}
function outf(...) {
	var s = format(...);
	out(s);
}

function get_outcurindent() {
	return outcurindent;
}

function outi() {
	out(outcurindent);
}

var line = 1;
function outnl() {
	line++;
	out("\n");
}

function outindent(l) {
	outindentlevel += l;
	outcurindent = string.rep(outindentstring, outindentlevel);
}

// help
function option_list(opt) {
	for (i, v in pairs(opt))
		emiterror(i.." "..v.help);
}

function option_help() {
	print("usage : jslua [options] [filenames]");
	option_list(options);
	os.exit();
}

// option module
function option_module() {
	var name = option_getarg();

	loadmodule(name);
}

var outhandle = io.stdout;
var compileonly;

function option_output() {
	compileonly = 1;
	var fn = option_getarg();
	outhandle = io.open(fn, "w");
	if (!outhandle)
		emiterror("Failed to open '"..fn.."' for writing.");
	else
		message("Opened '"..fn.."' for writing ...");
}

options = {
	["-o"] = {
		call = option_output,
		help = "compile only, and output lua source code to specified file"
	},
	["-c"] = {
		call = function() { compileonly = 1; },
		help = "compile only, and output lua source code on stdout"
	},
	["-v"] = {
		call = function() { verbose = 1; },
		help = "turn verbose mode on"
	},
	["-d"] = {
		call = function() { dbgmode = 1; },
		help = "turn debug mode on"
	},
	["--module"] = {
		call = option_module,
		help = "<modulename> load a module"
	},
	
	["--help"] = {
		call = option_help,
		help = "display this help message"
	}
};


function add_options(table) {
	for (i, v in pairs(table)) {
		if (options[i])
			emiterror(format("Option '%s' overriden", i));
		options[i] = v;
	}
}

function option_getarg() {
	var arg = option_args[option_argind];
	option_argind++;
	return arg;
}

// exit jslua namespace
exit_namespace();


// MAIN ENTRY
if (standalone) {

	// compute installation path from executable name
	var name = arg[0];
	if (name) {
		var i = 0;
		var j;
		while (i != nil) {
			j = i;
			i = string.find(name, "[/\\]", i+1);
		}
		if (j) {
			name = string.sub(name, 0, j);
			jslua.message(format("Adding path '%s'", name));
			jslua.add_path(name);
		}
	}

	// store command line options
	jslua.option_args = arg;
	jslua.option_argind = 1;

	// parse options
	var filename = { };
	while (jslua.option_argind <= #jslua.option_args) {
		var arg = jslua.option_getarg();

		if (string.sub(arg, 1, 1) == "-") {
			var opt = jslua.options[arg];
			if (opt) {
				if (opt.call)
					opt.call();
	
				if (opt.postcall)
					jslua.add_postprocess(opt.postcall);
			} else {
				jslua.emiterror(format("Unknown option '%s'\n", arg));
				jslua.option_help();
			}
		} else
			table.insert(filename, arg);
	}

	var function doit(filename) {
		if (compileonly)
			outhandle:write(jslua.jslua(filename));
		else
			jslua.dofile(filename);
	}
	if (!next(filename))
		doit();
	else
		for (_, v in pairs(filename))
			doit(v);

	jslua.do_postprocess();

	if (jslua.has_error)
		os.exit(-1);
  
	//os.exit()
}

