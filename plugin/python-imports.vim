" File: python-imports.vim
" Author: Marius Gedminas <marius@gedmin.as>
" Version: 1.5
" Last Modified: 2019-04-29
"
" Overview
" --------
" Vim script to help adding import statements in Python modules.
"
" You need to have a tags file built (:!ctags -R .).
"
" Type :ImportName [<name>] to add an import statement at the top.
" Type :ImportNameHere [<name>] to add an import statement above the current
" line.
"
" I use mappings like the following one to import the name under cursor with a
" single keystroke
"   map <buffer> <F5>    :ImportName<CR>
"   map <buffer> <C-F5>  :ImportNameHere<CR>
"
" Installation
" ------------
" Use a plugin manager like vim-plug please.
"
" Needs Vim 7.0, preferably built with Python support.
"
" Tested on Linux only.
"
" Configuration
" -------------
" In addition to the tags file (and builtin + stdlib modules), you can define
" your favourite imports in a file called ~/.vim/python-imports.cfg.  That
" file should contain Python import statements like
"    import module1, module2
"    from package.module import name1, name2
" Continuation lines are not supported.
" Parenthesized name lists are partially supported, if you use one name per
" line, i.e.
"    from package.module import (
"        name1,
"        name2,
"    )

if v:version < 700
    finish
endif

" Hardcoded names and locations
" g:pythonImports[module] = '' for module imports
" g:pythonImports[name] = 'module' for other imports
if !exists("g:pythonImports")
    let g:pythonImports = {'print': '__future__'}
endif

if has("python") || has("python3")
    let s:python = has("python3") ? "python3" : "python"
    exec s:python "import sys, vim"
    if !exists("g:pythonStdlibPath")
        exec s:python "vim.command(\"let g:pythonStdlibPath = '%s/lib/python%d.%d'\" % (getattr(sys, 'base_prefix', getattr(sys, 'real_prefix', sys.prefix)), sys.version_info[0], sys.version_info[1]))"
    endif
    if !exists("g:pythonBuiltinModules")
        let g:pythonBuiltinModules = {}
        exec s:python "for m in sys.builtin_module_names: vim.command(\"let g:pythonBuiltinModules['%s'] = ''\" % m)"
    endif
    if !exists("g:pythonExtModuleSuffix")
        exec s:python "import sysconfig"
        " grr neovim doesn't have pyxeval()
        let s:expr = "sysconfig.get_config_var('EXT_SUFFIX') or '.so'"
        let g:pythonExtModuleSuffix = has("python3") ? py3eval(s:expr) : pyeval(s:expr)
    endif
elseif !exists("g:pythonStdlibPath")
    let _py_versions = glob('/usr/lib/python?.*', 1, 1)
    if _py_versions != []
        " use latest version (assuming glob sorts the list)
        let g:pythonStdlibPath = _py_versions[-1]
    else
        " what, you don't have Python installed on this machine?
        let g:pythonStdlibPath = ""
    endif
endif

if !exists("g:pythonExtModuleSuffix")
    let g:pythonExtModuleSuffix = ".so"
endif

if !exists("g:pythonBuiltinModules")
    " based on python3.6 on linux, with all private ones removed
    let g:pythonBuiltinModules = {
          \ 'array': '',
          \ 'atexit': '',
          \ 'binascii': '',
          \ 'builtins': '',
          \ 'cmath': '',
          \ 'errno': '',
          \ 'faulthandler': '',
          \ 'fcntl': '',
          \ 'gc': '',
          \ 'grp': '',
          \ 'itertools': '',
          \ 'marshal': '',
          \ 'math': '',
          \ 'posix': '',
          \ 'pwd': '',
          \ 'pyexpat': '',
          \ 'select': '',
          \ 'spwd': '',
          \ 'sys': '',
          \ 'syslog': '',
          \ 'time': '',
          \ 'unicodedata': '',
          \ 'xxsubtype': '',
          \ 'zipimport': '',
          \ 'zlib': '',
          \ }
endif

if v:version >= 801 || v:version == 800 && has("patch-499")
    function! s:taglist(tag, filename)
        return taglist(a:tag, a:filename)
    endf
else
    function! s:taglist(tag, filename)
        return taglist(a:tag)
    endf
endif

function! LoadPythonImports(...)
    if a:0 == 0
        let filename = expand('~/.vim/python-imports.cfg')
        if !filereadable(filename)
            if &verbose > 0
                echo "skipping" filename "because it does not exist or is not readable"
            endif
            return
        endif
    elseif a:0 == 1
        let filename = a:1
    else
        echoerr "too many arguments: expected one (filename)"
        return
    endif
    if &verbose > 0
        echo "python-imports.vim: loading" filename
    endif
    if !has('python') && !has('python3')
        echoer "Need Python support: I'm not implementing a config file parser in vimscript!"
        return
    endif
    exec s:python "<< END"
def parse_python_imports_cfg(filename, verbose=False):
    import re
    DOTTEDNAME = '[a-zA-Z_.][a-zA-Z_0-9.]*'
    NAME = '[a-zA-Z_][a-zA-Z_0-9]*'
    NAMES = NAME + r'(\s*,\s*' + NAME + ')*'
    for line in open(filename):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        m = re.match(r'^import\s*(' + NAMES + ')$', line)
        if m:
            names = m.group(1).split(',')
            for name in names:
                if verbose:
                    print(name.strip())
                vim.command("let g:pythonImports['%s'] = ''" % name.strip())
            continue
        m = re.match(r'^from\s*(' + DOTTEDNAME + ')\s*import\s*(' + NAMES + ')$', line)
        if m:
            modname = m.group(1)
            names = m.group(2).split(',')
            for name in names:
                if verbose:
                    print('%s from %s' % (name.strip(), modname))
                vim.command("let g:pythonImports['%s'] = '%s'" % (name.strip(), modname))
            continue

parse_python_imports_cfg(vim.eval('filename'), int(vim.eval('&verbose')))
END
endf

if has('python') || has('python3')
    call LoadPythonImports()
endif

function! IsStdlibModule(name)
" Does a:name refer to a standard library module?
    if has_key(g:pythonBuiltinModules, a:name)
        return 1
    elseif g:pythonStdlibPath == ""
        return 0
    elseif filereadable(g:pythonStdlibPath . "/" . a:name . ".py")
        return 1
    elseif filereadable(g:pythonStdlibPath . "/" . a:name . "/__init__.py")
        return 1
    elseif filereadable(g:pythonStdlibPath . "/lib-dynload/" . a:name . ".so")
        return 1
    elseif filereadable(g:pythonStdlibPath . "/lib-dynload/" . a:name . g:pythonExtModuleSuffix)
        return 1
    else
        return 0
    endif
endf

function! CurrentPythonModule()
    return pythonimports#filename2module(expand("%"))
endfunction

function! CurrentPythonPackage()
    return pythonimports#filename2package(expand("%"))
endfunction

function! FindPlaceForImport(pkg, name)
" Find the appropriate place to insert a "from pkg import name" line.

    " Go to the top (use 'normal gg' because I want to set the ' mark)
    normal! gg
    keepjumps silent! 0/^"""/;/^"""/           " Skip docstring, if it exists
    keepjumps silent! /^import\|^from.*import/ " Find the first import statement
    nohlsearch
    if a:pkg == '__future__'
        return
    endif
    " Find the first empty line after that.  NOTE: DO NOT put any comments
    " on the line that says `normal`, or you'll get 24 extra spaces here
    keepjumps normal! }
    " Try to find an existing import from the same module, and move to
    " the last one of these
    let pkg = a:pkg
    while pkg != ""
        let stmt = "from ".pkg." "      " look for an exact match first
        if search('^' . stmt, 'cnw')
            exec "keepjumps silent! /^".stmt."/;/^\\(".stmt."\\)\\@!/"
            nohlsearch
            break
        endif
        let stmt = "from ".pkg."."      " try siblings or subpackages
        if search('^' . stmt, 'cnw')
            exec "keepjumps silent! /^".stmt."/;/^\\(".stmt."\\)\\@!/"
            nohlsearch
            break
        endif
        " If not found, look for imports coming from containing packages
        if pkg =~ '[.]'
            let pkg = substitute(pkg, '[.][^.]*$', '', '')
        else
            break
        endif
    endwhile
endfunction

function! ImportName(name, here, stay)
" Add an import statement for 'name'.  If 'here' is true, adds the statement
" on the line above the cursor, if 'here' is false, adds the line to the top
" of the current file.  If 'stay' is true, keeps cursor position, otherwise
" jumps to the line containing the newly added import statement.
    execute "normal! mq"
    " If name is empty, pick up the word under cursor
    if a:name == ""
        let l:name = expand("<cword>")
    else
        let l:name = a:name
    endif
    let line_to_insert = ""

    " Look for hardcoded names
    if has_key(g:pythonImports, l:name)
        let pkg = g:pythonImports[l:name]
    elseif IsStdlibModule(l:name)
        let pkg = ''
    else
        " Let's see if we have one tag, or multiple tags (in which case we'll
        " let the user decide)
        let tag_rx = "^\\C" . l:name . "\\([.]py\\)\\=$"
        let found = s:taglist(tag_rx, expand("%"))
        if found == []
            " Give up and bail out
            echohl Error | echomsg "Tag not found:" l:name | echohl None
            return
        elseif len(found) == 1
            " Only one name found, we can skip the selection menu and the
            " whole costly procedure of opening split windows.
            let pkg = pythonimports#filename2module(found[0].filename)
        else
            " Need to remove the first two last two characters (regex) /^...$/
            let imports = map(found, {pos,val -> val.cmd[2:-3]})
            let from_regex = 'from \zs\S\{-}\S\ze import'
            let import_pkg = map(imports, {pos, val -> matchstr(val, from_regex)})
            " Handle the `import name` case
            let import_pkgs = map(import_pkg, {pos, val -> empty(val) ? imports[pos] : val})
            " Count the popularily of packages, sort, pick the first
            let a = {}
            for i in import_pkgs
              let a[i] = get(a, i, 0) + 1
            endfor
            let sorted_items = sort(items(a), {n1, n2 -> n1[1] < n2[1]})

            if empty(match(sorted_items[0][0], from_regex))
              let line_to_insert = sorted_items[0][0]
              let pkg = CurrentPythonModule()
            else
              let pkg = sorted_items[0][0]
            endif
        endif
        if fnamemodify(pkg, 't') == l:name . ".py"
            let pkg = pythonimports#package_of(pkg)
        endif
    endif

    if line_to_insert == ""
      if pkg == ""
          let line_to_insert = 'import ' . l:name
      elseif pkg == "__future__" && l:name == "print"
          let line_to_insert = 'from __future__ import print_function'
      else
          let line_to_insert = 'from ' . pkg . ' import ' . l:name
      endif
    end

    " Find the place for adding the import statement
    if !a:here
        if search('^' . line_to_insert . '$', 'bcnw')
            " import already exists
            redraw
            echomsg l:name . " is already imported"
            return
        endif
        call FindPlaceForImport(pkg, l:name)
    endif
    " Find out the indentation of the current line
    let indent = matchstr(getline("."), "^[ \t]*\\%(>>> \\)\\=")
    " Check if we're using parenthesized imports already
    let prev_line = getline(line(".")-1)
    if indent != "" && prev_line  == 'from ' . pkg . ' import ('
        let line_to_insert = l:name . ','
    elseif indent != "" && prev_line =~ '^from .* import ('
        silent! /)/+1
        nohlsearch
        if line(".") == line("$") && getline(line(".")-1) !~ ')'
            put =''
        endif
        let indent = ""
    endif
    let line_to_insert = indent . line_to_insert
    " Double check with indent / parenthesized form
    if !a:here && search('^' . line_to_insert . '$', 'cnw')
        " import already exists
        redraw
        echomsg l:name . " is already imported"
        return
    endif
    " Add the import statement
    put! =line_to_insert
    " Jump back if possible
    if a:stay
        normal! ``
    endif
    " Refresh ALE because otherwise it gets all confused for a bit
    if exists("*ALELint")
        ALEResetBuffer
        ALELint
    endif
    execute "normal! `qzz"
endf

command! -nargs=? -bang -complete=tag ImportName	call ImportName(<q-args>, 0, <q-bang> == "!")
command! -nargs=? -bang -complete=tag ImportNameHere	call ImportName(<q-args>, 1, <q-bang> == "!")
