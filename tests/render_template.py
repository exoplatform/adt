#!/usr/bin/env python3
"""Render a Jinja2 template of ADT like `j2` does, but strictly: a variable the template uses and the command line does not give is an error.

usage: render_template.py TEMPLATE OUTPUT NAME=value [NAME=value ...]
"""
import os
import sys
import jinja2

template, output, *pairs = sys.argv[1:]
values = dict(p.split("=", 1) for p in pairs)
# like the renderer of ADT, the templates it includes are looked up in the directory of the template
env = jinja2.Environment(loader=jinja2.FileSystemLoader(os.path.dirname(os.path.abspath(template))),
                         undefined=jinja2.StrictUndefined, keep_trailing_newline=True)
with open(template) as f:
    text = f.read()
try:
    rendered = env.from_string(text).render(**values)
except jinja2.UndefinedError as e:
    sys.exit(f"{template}: {e.message}")
with open(output, "w") as f:
    f.write(rendered)
